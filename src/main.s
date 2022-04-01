.linecont +
.include "ppu_inc.s"
.include "chars_inc.s"
.include "render_inc.s"
.include "input_inc.s"
.include "actors_inc.s"

.globalzp   temp, frame

.export     game_state_updater, game_state_updater_ret_addr

.zeropage
    temp:           .res 8
    frame:          .res 1

    left_paddle_idx:    .res 1
    right_paddle_idx:   .res 1

.bss
    game_state_updater:
        .align 2
        .res 2


.code

.macro WAIT_NMI
    .importzp nmi_handler_done
    :
        BIT nmi_handler_done
        BPL :-                  ; NMI handler sets bit 7 when done processing
    ASL nmi_handler_done        ; shift off bit, set to 0
.endmacro

.macro MAIN_LOOP
    .local main_loop
    main_loop:
        ;;; read controller input
        .import read_inputs
        JSR read_inputs

        .importzp oam_stack_idx
        LDA #OAM_RESERVED_END
        STA oam_stack_idx

        JMP (game_state_updater)
        ::game_state_updater_ret_addr:

        .import hide_unused_oam
        JSR hide_unused_oam

        WAIT_NMI
        INC frame
        JMP main_loop
.endmacro

.proc handle_reset
    SEI             ; disable IRQs
    CLD             ; disable binary-encoded-decimal mode

    LDX #$FF
    TXS             ; reset stack pointer

    INX             ; X = #$00
    STX ppuctrl     ; disable NMIs
    STX ppumask     ; disable rendering

    BIT ppustatus   ; clear VBL bit

    ;;; wait for PPU to warm up
    frame0: BIT ppustatus
            BPL frame0

    ;;; zero out ram between 2 frame wait
    TXA     ; A = #0
    clear_ram:
        STA $00, X
        STA $0100, X
        STA $0200, X
        STA $0300, X
        STA $0400, X
        STA $0500, X
        STA $0600, X
        STA $0700, X
        INX
        BNE clear_ram

    ;;; wait for next frame
    frame1: BIT ppustatus
            BPL frame1

    ;;; buffer enable nmi, initialize starting game state
    .importzp local_ppuctrl, local_ppumask
    LDA #PPUCTRL_ENABLE_NMI \
            | PPUCTRL_VRAM_INC_1 \
            | PPUCTRL_TILE_TABLE{0} \
            | PPUCTRL_SPRITE_TABLE{1} \
            | PPUCTRL_NAMETABLE{0}
    STA local_ppuctrl

    ;;; buffer enable rendering
    LDA #PPUMASK_SHOW_ALL
    STA local_ppumask

    ;;; set initial gamestate
    JSR transition_game_state_basic

    ;;; process buffered PPU updates
    LDA local_ppumask
    STA ppumask
    LDA local_ppuctrl
    STA ppuctrl

    MAIN_LOOP
.endproc

.proc transition_game_state_basic
    ;;; run palette setup as render queue
    .import process_render_queue
    .import palette_setup_render_buf, PALETTE_SETUP_RENDER_BUF_LEN:zeropage
    LDA #<palette_setup_render_buf
    STA temp+0
    LDA #>palette_setup_render_buf
    STA temp+1
    LDA #PALETTE_SETUP_RENDER_BUF_LEN
    STA temp+2
    JSR process_render_queue

    ;;; write title screen to nametable 0 (at $2000)
    .import process_compressed
    .import title_screen_render_buf
    LDA #<title_screen_render_buf
    STA temp+0
    LDA #>title_screen_render_buf
    STA temp+1
    LDA #$20
    STA ppuaddr
    LDA #$00
    STA ppuaddr
    JSR process_compressed

    ;;; create entities

    .import find_next_empty_actor

    ;;; create ball
    LDX actor_next_idx
    SET_ACTOR_FLAGS %10000000
    SET_ACTOR_ID 0
    SET_ACTOR_POS {256/2}, {240/2}
    SET_ACTOR_UPDATER update_ball
    FILL_ACTOR_DATA $00

    JSR find_next_empty_actor

    ;;; create paddle
    LDX actor_next_idx
    SET_ACTOR_FLAGS %11000000
    SET_ACTOR_ID 1
    SET_ACTOR_POS {50}, {240/2}
    SET_ACTOR_UPDATER update_paddle
    FILL_ACTOR_DATA $00
    SET_ACTOR_HITBOX {0}, {0}, {8}, {8*5}
    STX left_paddle_idx
    JSR find_next_empty_actor

    ;;; create paddle
    LDX actor_next_idx
    SET_ACTOR_FLAGS %11000001
    SET_ACTOR_ID 1
    SET_ACTOR_POS {256-50-8}, {240/2}
    SET_ACTOR_UPDATER update_paddle
    FILL_ACTOR_DATA $00
    SET_ACTOR_HITBOX {0}, {0}, {8}, {8*5}
    STX right_paddle_idx
    JSR find_next_empty_actor


    ;;; set state update routine
    LDA #<game_state_basic
    STA game_state_updater+0
    LDA #>game_state_basic
    STA game_state_updater+1
    RTS
.endproc

.proc game_state_basic
    .import process_actors
    JSR process_actors
    JMP game_state_updater_ret_addr
.endproc


.import push_sprite

;;; ball update procedure to put in actor array
;;;
;;; data format:
;;;     X subpixel position
;;;     Y subpixel position
;;;     vertical speed
;;;         76543210
;;;         ||||||++- coarse pixel speed
;;;         ++++++--- subpixel speed
.proc update_ball
    .import check_actor_collisions

    LEFT_PAD    = 8
    RIGHT_PAD   = 8
    TOP_PAD     = 100
    BOTTOM_PAD  = 32

    X_SUB_SPEED = (1 << 8) / 3
    X_SPEED     = 1

    Y_SUB_SPEED = (1 << 8) / 2
    Y_SPEED     = 2

    ball_sub_x      = actor_data0
    ball_sub_y      = actor_data1
    ball_speed_y    = actor_data2

    local_flags = temp+2

    ;;; check collisions
    CLC
    LDA actor_xs,X
    STA temp+0      ; left side of hitbox
    ADC #8
    STA temp+2      ; right side of hitbox
    LDA actor_ys,X
    STA temp+1      ; top side of hitbox
    ADC #8
    STA temp+3      ; bottom side of hitbox
    JSR check_actor_collisions

    subpixel_diff   = temp+0
    coarse_diff     = temp+1

    LDA actor_flags,X
    BCC end_flip        ; do not flip direction if no collision
        ;;; bounce off paddle

        ;;; set X direction to right, Y direction to down
        AND #< ~((1<<0) | (1<<1))
        ;;; but if we collided with the right paddle, set X direction to left
        CPY right_paddle_idx
        BNE :+
            ORA #(1<<0)
        :
        STA local_flags

        ;;; perform 16 bit subtraction of vertical positions
        SEC
        LDA ball_sub_y,X
        SBC actor_data1,Y   ; subpixel position of paddle
        STA subpixel_diff
        LDA actor_ys,X
        SBC a:actor_ys,Y
        SEC
        SBC #(8*5/2 - 4)    ; then adjust for center of paddle and center of ball
        STA coarse_diff
        ;;; take absolute value of difference
        BPL :+
            EOR #$FF            ; negate high byte
            STA coarse_diff
            LDA subpixel_diff
            EOR #$FF            ; negate low byte
            CLC
            ADC #1              ; add one to low byte
            STA subpixel_diff
            LDA local_flags
            ORA #(1<<1)         ; since ball on top half of paddle, move up instead
            STA local_flags
            BCC :+              ; carry into high byte from addition earlier
            INC coarse_diff
        :

        ;;; since coarse_diff will be at maximum 5 bits large,
        ;;; shift it right 3 bits and rotate into subpixel_diff (divide by 8)
        ;;; then set the low 2 bits to the remaining 2 bits in coarse_diff
        ;;;
        ;;; effectively, this calculates a 6-bit subpixel velocity and a 2-bit
        ;;; coarse pixel velocity
        LDA subpixel_diff
        LSR coarse_diff
        ROR A
        LSR coarse_diff
        ROR A
        LSR coarse_diff
        ROR A
        EOR coarse_diff
        AND #%11111100
        EOR coarse_diff

        STA ball_speed_y,X

        ;;; store updated flags into actor
        LDA local_flags
        STA actor_flags,X
    end_flip:
    STA local_flags

    ;;; handle horizontal movement

    ;;; flag bit 0:
    ;;;     0: move right
    ;;;     1: move left
    ;;;
    ;;; C should be set by previous
    ;;; section

    LSR A           ; put X direction into C
    BCS move_x_neg
    move_x_pos:
        ;;; add speed to X position
        CLC
        LDA ball_sub_x,X
        ADC #X_SUB_SPEED
        STA ball_sub_x,X
        LDA actor_xs,X
        ADC #X_SPEED
        STA actor_xs,X
        STA temp+0      ; write x position parameter for push_sprite routine

        ;;; if X+8 is too high, flip direction bit
        CMP #256 - 8 - RIGHT_PAD
        BCC :+
            ;;; flag bit 0 known to be 0 here, so INC sets it to 1
            INC actor_flags,X
        :

        JMP move_x_end
    move_x_neg:
        ;;; subtract speed from X position
        SEC
        LDA ball_sub_x,X
        SBC #X_SUB_SPEED
        STA ball_sub_x,X
        LDA actor_xs,X
        SBC #X_SPEED
        STA actor_xs,X
        STA temp+0      ; write x position parameter for push_sprite routine

        ;;; if X goes too low, flip direction bit
        CMP #LEFT_PAD
        BCS :+
            ;;; flag 0 known to be 1 here, so DEC sets it to 0
            DEC actor_flags,X
        :
    move_x_end:

    ;;; handle vertical movement

    coarse_y_speed      = temp+3
    subpixel_y_speed    = temp+4

    ;;; extract coarse and subpixel speeds from speed field
    ;;; (format described in function description)
    LDA ball_speed_y,X
    AND #%00000011
    STA coarse_y_speed
    LDA ball_speed_y,X
    AND #%11111100
    STA subpixel_y_speed

    ;;; flag bit 1:
    ;;;     0: move down
    ;;;     1: move up
    LDA #%00000010
    BIT local_flags
    BNE move_y_neg
    move_y_pos:
        ;;; add speed to Y position
        CLC
        LDA ball_sub_y,X
        ADC subpixel_y_speed
        STA ball_sub_y,X
        LDA actor_ys,X
        ADC coarse_y_speed
        STA actor_ys,X
        STA temp+1      ; write y position parameter for push_sprite routine

        ;;; if y+8 is too high, flip direction bit
        CMP #240 - 8 - BOTTOM_PAD
        BCS flip_y_direction
        BCC move_y_end

    move_y_neg:
        ;;; subtract speed from Y position
        SEC
        LDA ball_sub_y,X
        SBC subpixel_y_speed
        STA ball_sub_y,X
        LDA actor_ys,X
        SBC coarse_y_speed
        STA actor_ys,X
        STA temp+1      ; write y position parameter for push_sprite routine

        ;;; if y goes too low, flip direction bit
        CMP #TOP_PAD
        BCS move_y_end
        ;;; fallthrough to flip y direction

    flip_y_direction:
        LDA local_flags
        EOR #%00000010  ; flip vertical direction
        STA actor_flags,X

    move_y_end:

    LDA #SPRITE_ATTR_PALETTE{1}
    STA temp+2                  ; pass attribute parameter to push_sprite routine

    LDA #$01    ; ball sprite
    JSR push_sprite

    JMP (actor_updater_ret_addr)
.endproc

;;; paddle update procedure to put in actor array
;;; data format:
;;;     flags: 76543210
;;;            |||||||+- player [0=player 1; 1=player 2]
;;;            XXXXXXX
;;;
;;;     data0:  X subpixel position
;;;     data1:  Y subpixel position
.proc update_paddle
    .importzp joy0_state, joy1_state

    Y_SUB_SPEED = $100 * 2/3
    Y_SPEED     = 1

    button_state    = temp+0
    paddle_sub_y    = actor_data1

    LDA actor_flags,X
    AND #(1 << 0)             ; mask player flag
    TAY
    LDA a:joy0_state,Y  ; load joy0_state or joy1_state
    STA button_state

    test_move_down:
    AND #JOY_BUTTON_DOWN
    BEQ test_move_up
        ;;; move down
        CLC
        LDA paddle_sub_y,X
        ADC #Y_SUB_SPEED
        STA paddle_sub_y,X
        LDA actor_ys,X
        ADC #Y_SPEED
        STA actor_ys,X
        JMP test_move_end

    test_move_up:
    LDA button_state
    AND #JOY_BUTTON_UP
    BEQ test_move_none
        ;;; move down
        SEC
        LDA paddle_sub_y,X
        SBC #Y_SUB_SPEED
        STA paddle_sub_y,X
        LDA actor_ys,X
        SBC #Y_SPEED
        STA actor_ys,X

    test_move_none:
        LDA actor_ys,X
    test_move_end:

    ;;; begin drawing sprite

    ;;; draw top of paddle
    STA temp+1      ; pass Y position parameter
    LDA actor_xs,X
    STA temp+0      ; pass X position parameter
    LDA #SPRITE_ATTR_PALETTE{0}
    STA temp+2      ; pass attribute parameter
    LDA #2          ; top of paddle sprite
    JSR push_sprite

    STX temp+3      ; store actor index

    ;;; loop drawing rest of sprite
    LDX #4          ; set X to loop index variable
    CLC
    loop:
        LDA temp+1  ; load Y position
        ADC #8      ; move down 8
        STA temp+1

        DEX         ; if we are on the last iteration exit the loop and skip rendering middle segment
        BEQ loop_end

        LDA #3      ; middle paddle sprite
        JSR push_sprite
        JMP loop
    loop_end:

    LDA #SPRITE_ATTR_PALETTE{0} | SPRITE_ATTR_FLIP_V
    STA temp+2                                      ; draw paddle end upside down
    LDA #2                                          ; draw paddle end
    JSR push_sprite

    LDX temp+3      ; restore actor index

    JMP (actor_updater_ret_addr)
.endproc

.proc handle_irq
    RTI
.endproc


.segment "VECTORS"
    .import handle_nmi

    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


