.include "actors_inc.s"
.include "ppu_inc.s"
.include "input_inc.s"
.include "render_inc.s"

.globalzp   temp, game_state_data
.global     game_state_updater_ret_addr, game_state_updater

.import update_actors, render_actors


;;; nametable of play area
GS_PLAY_NAMETABLE_HI = $20

.enum
    BALL_IDX            = 0
    LEFT_PADDLE_IDX
    RIGHT_PADDLE_IDX
.endenum

BALL_START_X = (256 - 8) / 2
BALL_START_Y = (240 / 2) + 16

;;; timing information for ball blinking effect between plays
BALL_BLINK_COUNT    = 6
BALL_BLINK_INTERVAL = 30
BALL_BLINK_DELAY    = 60

player_points   = game_state_data+0   ; 2 byte BCD array
timer           = game_state_data+2
blink_count     = game_state_data+3

.code

.export begin_game_serve_ball
.proc begin_game_serve_ball
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
    LDA #GS_PLAY_NAMETABLE_HI
    STA ppuaddr
    LDA #$00
    STA ppuaddr
    JSR process_compressed

    ;;; tail call fallthrough into next routine
    .assert * = transition_game_state_serve_ball, error
.endproc

.proc transition_game_state_serve_ball
    JSR init_entities
    ;;; transition state for next frame
    LDA #BALL_BLINK_DELAY
    STA timer
    LDA #BALL_BLINK_COUNT
    STA blink_count
    ;;; set state update routine
    LDA #<game_state_serve_ball
    STA game_state_updater+0
    LDA #>game_state_serve_ball
    STA game_state_updater+1

    RTS
.endproc

.proc game_state_play
    JSR update_actors
    JSR render_actors
    JMP game_state_updater_ret_addr
.endproc


.proc game_state_serve_ball
    JSR update_actors
    JSR render_actors

    ;;; tick down timer
    DEC timer
    BNE ret

    ;;; if timer has counted down, decrement remaining blinks
    DEC blink_count
    ;;; if done blinking, begin game
    BEQ transition_state
    ;;; else, reset timer and flip ball visibility bit
    LDA #BALL_BLINK_INTERVAL
    STA timer
    LDA #ACTOR_FLAG_RENDER
    EOR actor_flags+BALL_IDX
    STA actor_flags+BALL_IDX

    ret:
    JMP game_state_updater_ret_addr


    transition_state:
    ;;; enable ball movement
    LDA #ACTOR_FLAG_UPDATE
    ORA actor_flags+BALL_IDX
    STA actor_flags+BALL_IDX
    ;;; change to playing state
    LDA #<game_state_play
    STA game_state_updater+0
    LDA #>game_state_play
    STA game_state_updater+1
    JMP game_state_updater_ret_addr
.endproc


;;; ball actor update procedure
;;;
;;; data format:
;;;     flags:  3 2 1 0
;;;             | | | +- 0: horizontal direction [0=right; 1=left]
;;;             | | +--- 1: vertical direction [0=down; 1=up]
;;;             X X
;;;
;;;     data0:  X subpixel position
;;;     data1:  Y subpixel position
;;;     data2:  vertical speed
;;;         7 6 5 4 3 2 1 0
;;;         | | | | | | +-+- [0-1]: coarse pixel speed
;;;         +-+-+-+-+-+----- [2-7]: subpixel speed
.proc update_ball
    .import check_actor_collisions

    LEFT_PAD    = 8
    RIGHT_PAD   = 8
    TOP_PAD     = 100
    BOTTOM_PAD  = 32

    X_SUB_SPEED = (1 << 8) / 3
    X_SPEED     = 1

    ball_sub_x      = actor_data0
    ball_sub_y      = actor_data1
    ball_speed_y    = actor_data2

    X_DIR_BIT           = 1 << 0
    Y_DIR_BIT           = 1 << 1
    COARSE_SPEED_MASK   = %00000011
    SUBPIXEL_SPEED_MASK = %11111100

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
        AND #< ~(X_DIR_BIT | Y_DIR_BIT)
        ;;; but if we collided with the right paddle, set X direction to left
        CPY #RIGHT_PADDLE_IDX
        BNE :+
            ORA #X_DIR_BIT
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
            ORA #Y_DIR_BIT      ; since ball on top half of paddle, move up instead
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
        AND #SUBPIXEL_SPEED_MASK
        EOR coarse_diff

        STA ball_speed_y,X

        ;;; store updated flags into actor
        LDA local_flags
        STA actor_flags,X
    end_flip:
    STA local_flags

    ;;; handle horizontal movement

    ;;; X direction flag:
    ;;;     0: move right
    ;;;     1: move left
    LSR A           ; put X direction into C, assume A contains flags
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

        ;;; if X+8 is too high, then ball is hitting the right edge
        ;;; player 1 wins the round
        CMP #256 - 8 - RIGHT_PAD
        BCC move_x_end

        LDX #0              ; index of player 1
        JMP on_player_score ; tail call

    move_x_neg:
        ;;; subtract speed from X position
        SEC
        LDA ball_sub_x,X
        SBC #X_SUB_SPEED
        STA ball_sub_x,X
        LDA actor_xs,X
        SBC #X_SPEED
        STA actor_xs,X

        ;;; if X goes too low, then ball is hitting left edge
        ;;; player 2 wins the round
        CMP #LEFT_PAD
        BCS move_x_end

        LDX #1              ; index of player 2
        JMP on_player_score ; tail call

    move_x_end:

    ;;; handle vertical movement

    coarse_y_speed      = temp+3
    subpixel_y_speed    = temp+4

    ;;; extract coarse and subpixel speeds from speed field
    ;;; (format described in function description)
    LDA ball_speed_y,X
    AND #COARSE_SPEED_MASK
    STA coarse_y_speed
    ;;; subpixel bits are zero, coarse pixel bits are equal to corresponding
    ;;; bits of the Y speed
    ;;;
    ;;; therefore, EOR will set the subpixel bits to equal the correct
    ;;; value (0 ^ X = X), and cancel out the coarse pixel bits
    ;;; to zero (Y ^ Y = 0)
    EOR ball_speed_y,X
    STA subpixel_y_speed

    ;;; Y direction flag:
    ;;;     0: move down
    ;;;     1: move up
    LDA #Y_DIR_BIT
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

        ;;; if y goes too low, flip direction bit
        CMP #TOP_PAD
        BCS move_y_end
        ;;; fallthrough to flip y direction

    flip_y_direction:
        LDA local_flags
        EOR #Y_DIR_BIT     ; flip vertical direction
        STA actor_flags,X

    move_y_end:
    JMP actor_updater_ret
.endproc

;;; ball actor render procedure
.proc render_ball
    .import push_sprite

    LDA actor_xs,X
    STA temp+0                  ; pass X position
    LDA actor_ys,X
    STA temp+1                  ; pass Y position
    LDA #SPRITE_ATTR_PALETTE{1}
    STA temp+2                  ; pass attribute parameter

    LDA #$01                    ; ball sprite
    JSR push_sprite

    JMP (actor_renderer_ret_addr)
.endproc


;;; paddle actor update procedure
;;; data format:
;;;     flags:  3 2 1 0
;;;             | | | +- 0: player [0=player 1; 1=player 2]
;;;             X X X
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
    BEQ test_move_end
        ;;; move down
        SEC
        LDA paddle_sub_y,X
        SBC #Y_SUB_SPEED
        STA paddle_sub_y,X
        LDA actor_ys,X
        SBC #Y_SPEED
        STA actor_ys,X
    test_move_end:

    JMP actor_updater_ret
.endproc

;;; paddle actor render procedure
.proc render_paddle
    .import push_sprite

    ;;; draw top of paddle
    LDA actor_xs,X
    STA temp+0      ; pass X position parameter
    LDA actor_ys,X
    STA temp+1      ; pass Y position parameter
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

    JMP (actor_renderer_ret_addr)
.endproc

;;; BCD increment of point value for player who scored.
;;; Update screen and reset ball.
;;; Jump to this routine only as a tail call from update_ball.
;;;
;;; parameters:
;;;     X: player index [0 = player 1; 1 = player 2]
;;;
;;; overwrites:
;;;     temp+0
.proc on_player_score
    high_digit = temp+0

    LDA player_points,X
    AND #$F0            ; take high digit
    STA high_digit
    EOR player_points,X ; take low digit
    CLC
    ADC #1
    CMP #$0A
    BNE :+              ; carry into high digit if equal to 10
        LDA #$10 - 1    ; -1 because C is set iff this branch is taken
    :
    ADC high_digit      ; combine high and low digits (and maybe carry)
    STA player_points,X ; save computed value

    points = temp+0
    STA points

    ;;; update tiles to show new point value
    .import render_queue, render_queue_len
    LDY render_queue_len

    DIGIT_TILE_0 = $1B

    ;;; pass address of score text on the ppu
    LDA #GS_PLAY_NAMETABLE_HI
    STA render_queue+0,Y

    ;;; calculate offset based on player who scored
    ;;; player 1 = left, player 2 = right
    TXA
    ASL A
    ASL A
    ASL A
    ASL A
    ADC #32+6  ; assume C is 0 from shifts/rotates above
    STA render_queue+1,Y

    ;;; pass length of score text (always 2 digits)
    LDA #2
    STA render_queue+2,Y
    ;;; opcode
    LDA #RENDER_IMMEDIATE
    STA render_queue+3,Y
    ;;; high digit
    LDA points
    LSR A
    LSR A
    LSR A
    LSR A
    CLC
    ADC #DIGIT_TILE_0
    STA render_queue+4,Y
    ;;; low digit
    LDA points
    AND #$0F
    ADC #DIGIT_TILE_0       ; assume previous add did not carry
    STA render_queue+5,Y

    ;;; increment length of render queue
    TYA
    CLC
    ADC #6
    STA render_queue_len

    JSR transition_game_state_serve_ball

    ;;; assumption: this routine is only called from actor at index #BALL_INDEX
    LDX #BALL_IDX
    JMP actor_updater_ret
.endproc

;;; basic initialization values for ball and paddles
;;;
;;; overwrites:
;;;     A, X
.proc init_entities
    ;;; ball and paddles occupy fixed locations in the actor array
    ;;; given by the enum at the top of the file

    ;;; create ball
    LDX #BALL_IDX
    SET_ACTOR_FLAGS %00010000
    SET_ACTOR_ID 0
    SET_ACTOR_POS {::BALL_START_X}, {::BALL_START_Y}
    SET_ACTOR_UPDATER update_ball
    SET_ACTOR_RENDERER render_ball
    FILL_ACTOR_DATA $00

    ;;; create left paddle
    INX
    SET_ACTOR_FLAGS %11110000
    SET_ACTOR_ID 1
    SET_ACTOR_POS {50}, {240/2}
    SET_ACTOR_UPDATER update_paddle
    SET_ACTOR_RENDERER render_paddle
    FILL_ACTOR_DATA $00
    SET_ACTOR_HITBOX {0}, {0}, {8}, {8*5}

    ;;; create right paddle
    INX
    SET_ACTOR_FLAGS %11110001
    SET_ACTOR_ID 1
    SET_ACTOR_POS {256-50-8}, {240/2}
    SET_ACTOR_UPDATER update_paddle
    SET_ACTOR_RENDERER render_paddle
    FILL_ACTOR_DATA $00
    SET_ACTOR_HITBOX {0}, {0}, {8}, {8*5}

    INX
    STX actor_next_idx

    RTS
.endproc