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

;;; parameters:
;;;     inline double-byte: new game state address
;;;     C flag:
;;;         0 = return from CALLING function via RTS
;;;         1 = return to game_state_updater_ret_addr
;;;
;;; overwrites:
;;;     A, Y, temp+0.1
;;;
;;; note:
;;;     You must call this routine via a JSR instruction immediately followed by the 2-byte paramter
;;;     inlined at the callsite, e.g.,
;;;
;;;         JSR set_gamestate_updater
;;;         .addr new_game_state
;;;
;;;     This method either returns from the routine which invoked it via RTS (if C = 0),
;;;     or it will return directly to game_state_updater_ret_addr (if C = 1).
;;;     Therefore, this routine only works as a tail-call.
.export set_game_state_updater
.proc set_game_state_updater
    code_addr = temp+0

    ;;; fetch pushed return address from JSR
    PLA
    STA code_addr+0
    PLA
    STA code_addr+1

    ;;; code_addr is on byte before data
    ;;; so load address offset by 1
    LDY #1
    LDA (code_addr),Y
    STA game_state_updater+0
    INY
    LDA (code_addr),Y
    STA game_state_updater+1

    ;;; if C = 0, return with RTS
    ;;; if C = 1, return to gamestate updater return address
    BCS game_state_updater_ret_addr
    RTS
.endproc


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

    .importzp local_ppuctrl, local_ppumask

    ;;; buffer enable rendering
    LDA #PPUMASK_SHOW_ALL
    STA local_ppumask

    ;;; set initial gamestate
    .import begin_game_titlescreen
    JSR begin_game_titlescreen

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


