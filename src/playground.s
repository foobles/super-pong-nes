.linecont +
.include "ppu_inc.s"
.include "chars_inc.s"
.include "input_inc.s"

.globalzp temp 

PADDLE_HEIGHT = 4

.zeropage
    temp:           .res 16
    frame:          .res 1
    local_ppuctrl:  .res 1
    local_ppumask:  .res 1

    nmi_handler_done:   .res 1

    oam_stack_idx:      .res 1
    OAM_RESERVED = 1
    OAM_RESERVED_END = 4 * OAM_RESERVED

    ;;; obj data
    paddle0_y:      .res 1
    paddle0_sub_y:  .res 1
    paddle1_y:      .res 1
    paddle1_sub_y:  .res 1


.bss
    local_oam:    
        .align $100
        .res $100

    render_queue: .res $80
    render_queue_len: .res 1

.code 
.proc handle_nmi
    ;;; clear latch
    BIT ppustatus

    ;;; update sprites
    LDA #>local_oam
    STA oamdma

    ;;; process render queue
    .import process_render_queue
    LDA #<render_queue
    STA temp+0 
    LDA #>render_queue
    STA temp+1
    LDA render_queue_len
    STA temp+2
    JSR process_render_queue
    
    ;;; update ppuctrl
    BIT ppustatus
    LDA local_ppuctrl
    STA ppuctrl

    ;;; update scroll position
    LDA #0          
    STA ppuscroll   ; x scroll
    STA ppuscroll   ; y scroll
    STA render_queue_len        ; reset queue length for next frame

    ;;; set bit 7 of nmi_handler_done
    LDA #(1 << 7)
    STA nmi_handler_done

    RTI
.endproc


;;; assume w = 0, vram inc = 1
.macro INIT_GAME_PALETTES
    LDA #>ppu_palette_table
    STA ppuaddr
    LDA #<ppu_palette_table
    STA ppuaddr

    LDA #$0F    ; background color black
    STA ppudata
    LDA #$25    ; pink
    STA ppudata
    LDA #$35    ; highlight
    STA ppudata
    LDA #$16    ; shadow
    STA ppudata

    ;;; sprite palette
    LDA #$3F
    STA ppuaddr 
    LDA #$11
    STA ppuaddr
    
    LDA #$20    ; white 
    STA ppudata
    LDA #$21    ; light blue 
    STA ppudata 
    LDA #$02    ; dark blue
    STA ppudata
.endmacro

.macro MAIN_LOOP 
    .local main_loop
    main_loop:
        ;;; read controller input
        .import read_inputs
        .importzp joy0_state
        JSR read_inputs

        LDA #$3F 
        STA render_queue+0
        LDA #$00
        STA render_queue+1 
        LDA #1
        STA render_queue+2 
        LDA #RENDER_IMMEDIATE
        STA render_queue+3
        LDA frame 
        STA render_queue+4
        LDA #5
        STA render_queue_len

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

        LDA #OAM_RESERVED_END
        STA oam_stack_idx

        LDA #50
        STA temp+0
        LDA paddle0_y
        STA temp+1
        LDX #5
        JSR draw_paddle
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

    INIT_GAME_PALETTES

    JSR init_title_screen

    ;;; enable NMI and rendering
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

    MAIN_LOOP
.endproc


.proc handle_irq
    RTI
.endproc

.proc wait_nmi
    loop:
        BIT nmi_handler_done
        BPL loop                ; NMI handler sets bit 7 when done processing
    ASL nmi_handler_done        ; shift off bit, set to 0
    RTS 
.endproc


;;; parameters:
;;;     A:          pattern
;;;     temp+0:  X position
;;;     temp+1:  Y position
;;;     temp+2:  attributes
;;; overwrites:
;;;     A, Y
.proc push_tile
    Y_OFFSET = 0
    P_OFFSET = 1
    A_OFFSET = 2
    X_OFFSET = 3

    x_pos = temp+0
    y_pos = temp+1
    attrs = temp+2

    LDY oam_stack_idx

    STA local_oam+P_OFFSET,Y    ; store pattern
    
    LDA x_pos
    STA local_oam+X_OFFSET,Y    ; store X position 

    LDA y_pos
    STA local_oam+Y_OFFSET,Y    ; store Y position 

    LDA attrs 
    STA local_oam+A_OFFSET,Y    ; store attributes

    ;;; move index to next sprite
    TYA 
    CLC 
    ADC #4 
    STA oam_stack_idx
    RTS 
.endproc 

.proc draw_paddle
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



.proc hide_unused_oam
    LDA #$FF 
    LDX oam_stack_idx
    loop:
        STA local_oam,X   ; store #$FF into current sprite Y position

        ;;; go to next sprite index
        .repeat 4 
            INX 
        .endrepeat
    
        BNE loop

    RTS
.endproc


;;; only use when rendering is off, vram inc is 1
;;; overwrites temp+0
.proc init_title_screen
    LOGO_START_X = 5
    LOGO_START_Y = 6

    CLC 

    ;;; load nametable 0 address
    LDA #$20
    STA ppuaddr
    LDA #$00
    STA ppuaddr

    ;;; clear first rows
    LDA #CHR0_BLANK
    LDX #(32 * LOGO_START_Y)
    :
        STA ppudata
        DEX 
        BNE :- 

    
    ;;; draw logo 
    LDA #CHR0_LOGO_START
    STA temp+0              
    LDA #CHR0_BLANK
    LDX #4
    render_logo_line:
        LDY #LOGO_START_X
        :
            STA ppudata
            DEY 
            BNE :- 

        LDA temp+0
        LDY #16
        :
            STA ppudata
            ADC #1 
            DEY 
            BNE :-
        STA temp+0

        LDA #CHR0_BLANK
        LDY #(32 - (LOGO_START_X + 16))
        :
            STA ppudata
            DEY 
            BNE :- 

        DEX 
        BNE render_logo_line


    

    RTS 
.endproc 

.segment "VECTORS"
    .addr handle_nmi
    .addr handle_reset
    .addr handle_irq


    