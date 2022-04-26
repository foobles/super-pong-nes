.linecont +
.include "ppu_inc.s"
.include "render_inc.s"

.globalzp   temp, frame, game_state_data
.global     game_state_updater, game_state_updater_ret_addr

.zeropage
    temp:           .res 8
    frame:          .res 1

    game_state_data:    .res 8

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
    .import begin_game_serve_ball
    JSR begin_game_serve_ball

    ;;; process buffered PPU updates
    LDA local_ppumask
    STA ppumask
    LDA local_ppuctrl
    STA ppuctrl

    MAIN_LOOP
.endproc


.proc handle_irq
    RTI
.endproc


.segment "VECTORS"
    .import handle_nmi

    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


