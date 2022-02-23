.linecont +
.include "ppu_inc.s"
.include "chars_inc.s"
.include "render_inc.s"
.include "input_inc.s"

.globalzp temp 

PADDLE_HEIGHT = 4

.zeropage
    temp:           .res 16
    frame:          .res 1

    ;;; obj data
    paddle0_y:      .res 1
    paddle0_sub_y:  .res 1
    paddle1_y:      .res 1
    paddle1_sub_y:  .res 1




.code 

.macro MAIN_LOOP 
    .local main_loop
    main_loop:
        ;;; read controller input
        .import read_inputs
        .importzp joy0_state
        JSR read_inputs

        ;;; if up button is pressed, move paddle up by 1.33 px
        LDA #JOY_BUTTON_UP
        BIT joy0_state
        BEQ :+ 
            SEC 
            LDA paddle0_sub_y
            SBC #%01010101
            STA paddle0_sub_y

            LDA paddle0_y
            SBC #1
            STA paddle0_y
        :

        ;;; if down button is pressed, move paddle down by 1.33 px
        LDA #JOY_BUTTON_DOWN
        BIT joy0_state
        BEQ :+
            CLC 
            LDA paddle0_sub_y 
            ADC #%01010101
            STA paddle0_sub_y

            LDA paddle0_y
            ADC #1
            STA paddle0_y
        :

        .importzp oam_stack_idx 
        LDA #OAM_RESERVED_END
        STA oam_stack_idx

        LDA #50
        STA temp+0
        LDA paddle0_y
        STA temp+1
        LDX #5
        JSR draw_paddle

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
    STA ppumask

    LDA #PPUCTRL_ENABLE_NMI \
            | PPUCTRL_VRAM_INC_1 \
            | PPUCTRL_TILE_TABLE{0} \
            | PPUCTRL_SPRITE_TABLE{1} \
            | PPUCTRL_NAMETABLE{0} \
            | PPUCTRL_VRAM_INC_1
    STA local_ppuctrl
    STA ppuctrl


    .import process_render_queue
    .import palette_setup_render_buf, PALETTE_SETUP_RENDER_BUF_LEN:zeropage
    LDA #<palette_setup_render_buf
    STA temp+0
    LDA #>palette_setup_render_buf
    STA temp+1
    LDA #PALETTE_SETUP_RENDER_BUF_LEN
    STA temp+2
    JSR process_render_queue

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


.proc draw_paddle
    .import push_tile 
    x_pos = temp+0
    y_pos = temp+1
    attrs = temp+2

    ;;; draw top of paddle
        ;;; assume X and Y already placed in temp 
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

        LDA #SPRITE_ATTR_PALETTE{0} \
                | SPRITE_ATTR_FLIP_V    
        STA attrs                       ; pass flipped attr for bottom
        
        LDA #CHR1_PADDLE_END
        JSR push_tile

    RTS
.endproc

.segment "VECTORS"
    .import handle_nmi

    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


    