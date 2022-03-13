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

.proc handle_irq
    RTI
.endproc


.segment "VECTORS"
    .import handle_nmi

    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


