.linecont +
.include "ppu_inc.s"
.include "chars_inc.s"
.include "render_inc.s"
.include "input_inc.s"
.include "actors_inc.s"

.globalzp temp, frame

PADDLE_HEIGHT = 6

.zeropage
    temp:           .res 8
    frame:          .res 1

.code

.macro MAIN_LOOP
    .local main_loop
    main_loop:
        ;;; read controller input
        .import read_inputs
        .importzp joy0_state
        JSR read_inputs

        .importzp oam_stack_idx
        LDA #OAM_RESERVED_END
        STA oam_stack_idx

        .import process_actors
        JSR process_actors

        .import hide_unused_oam
        JSR hide_unused_oam

        JSR wait_nmi
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

    ;;; enable NMI and rendering
    .importzp local_ppuctrl, local_ppumask
    LDA #PPUMASK_SHOW_ALL
    STA local_ppumask

    LDA #PPUCTRL_ENABLE_NMI \
            | PPUCTRL_VRAM_INC_1 \
            | PPUCTRL_TILE_TABLE{0} \
            | PPUCTRL_SPRITE_TABLE{1} \
            | PPUCTRL_NAMETABLE{0} \
            | PPUCTRL_VRAM_INC_1
    STA local_ppuctrl


    .import process_render_queue
    .import palette_setup_render_buf, PALETTE_SETUP_RENDER_BUF_LEN:zeropage
    LDA #<palette_setup_render_buf
    STA temp+0
    LDA #>palette_setup_render_buf
    STA temp+1
    LDA #PALETTE_SETUP_RENDER_BUF_LEN
    STA temp+2
    JSR process_render_queue

    .import process_compressed
    .import title_screen_render_buf
    LDA #$20
    STA ppuaddr
    LDA #$00
    STA ppuaddr
    LDA #<title_screen_render_buf
    STA temp+0
    LDA #>title_screen_render_buf
    STA temp+1
    JSR process_compressed

    LDA local_ppumask
    STA ppumask
    LDA local_ppuctrl
    STA ppuctrl

    .import find_next_empty_actor
    LDX actor_next_idx
    LDA #%10000000
    STA actor_flags,X
    LDA #0
    STA actor_ids,X
    LDA #50
    STA actor_xs,X
    STA actor_ys,X
    LDA #3
    STA actor_data0,X
    JSR find_next_empty_actor

    MAIN_LOOP
.endproc


.proc handle_irq
    RTI
.endproc

.proc wait_nmi
    .importzp nmi_handler_done
    loop:
        BIT nmi_handler_done
        BPL loop                ; NMI handler sets bit 7 when done processing
    ASL nmi_handler_done        ; shift off bit, set to 0
    RTS
.endproc


.export update_paddle
.proc update_paddle
    x_pos = temp+0
    y_pos = temp+1
    attrs = temp+2

    TXA
    PHA
    LDA actor_xs,X
    STA x_pos
    LDA actor_ys,X
    STA y_pos

    .importzp joy0_state
    test_up:
    LDA #JOY_BUTTON_UP
    BIT joy0_state
    BEQ test_down
        DEC y_pos
        JMP end_input

    test_down:
    LDA #JOY_BUTTON_DOWN
    BIT joy0_state
    BEQ end_input
        INC y_pos

    end_input:

    LDA y_pos
    STA actor_ys,X
    LDA actor_data0,X
    TAX

    .import push_tile

    ;;; draw top of paddle
        LDA #SPRITE_ATTR_PALETTE{0}
        STA attrs                       ; pass attribute parameter
        LDA #CHR1_PADDLE_END ; pass pattern parameter
        JSR push_tile

    ;;; draw middle blocks
    draw_mid_sprite:
        ;;; add 8 to y position
        LDA y_pos
        CLC
        ADC #8
        STA y_pos

        LDA #CHR1_PADDLE_MID ; pass pattern parameter
        JSR push_tile

        DEX
        BNE draw_mid_sprite


    ;;; draw bottom of paddle
        ;;; add 8 to y position
        LDA y_pos
        CLC
        ADC #8
        STA y_pos

        LDA #SPRITE_ATTR_PALETTE{0} | SPRITE_ATTR_FLIP_V
        STA attrs                       ; pass flipped attr for bottom

        LDA #CHR1_PADDLE_END
        JSR push_tile

    PLA
    TAX
    JMP (actor_updater_ret_addr)
.endproc



.segment "VECTORS"
    .import handle_nmi

    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


