.include "render_inc.s"

.segment "CHARS0"
    .incbin "chr0.chr"

.segment "CHARS1"
    .incbin "chr1.chr"




.rodata 

.export palette_setup_render_buf, PALETTE_SETUP_RENDER_BUF_LEN:zeropage
palette_setup_render_buf:
.scope palette_setup_render_buf
    .byte $3F, 01       ; render to palette table
    .byte (end - data)  ; length
    .byte RENDER_IMMEDIATE
    data:
        ;;; tile 0
        .byte $25, $35, $16     ; pink, highlight, shadow

        ;;; tile 1
        .res 1
        .res 3
        
        ;;; tile 2
        .res 1
        .res 3
        
        ;;; tile 3
        .res 1
        .res 3

        ;;; background 
        .byte $0F               ; black
        
        ;;; sprite 0
        .byte $21, $20, $11     ; blue, highlight, shadow

        ;;; sprite 1
        .res 1 
        .byte $24, $34, $15     ; pink, highlight, shadow
    end: 
.endscope

PALETTE_SETUP_RENDER_BUF_LEN = <(palette_setup_render_buf::end - palette_setup_render_buf)



.export title_screen_render_buf
title_screen_render_buf:
.scope title_screen_render_buf
    NT_WIDTH = 32
    H_OFFSET = 6

    ;;; rle
    .byte NT_WIDTH * 3 + H_OFFSET   ; fill top 3 rows, and indent into next line
    .byte $00                       ; fill with empty


    ;;; draw SUPER
        .byte 8         ; len
        .byte $88, $89, $8A, $8B, $8C, $8D, $8E, $8F
        .byte NT_WIDTH - 8  ; go to next line
        .byte $00

        .byte 8         ; len
        .byte $90, $91, $92, $93, $94, $95, $96, $97
        .byte NT_WIDTH - 8 ; go to next line
        .byte $00

    ;;; draw PONG
        ;;; row 0
        .byte 16        
        .byte $40,$42,$43,$44, $45,$46,$47,$48, $40,$49,$4A,$41, $45,$46,$42,$4D
        .byte NT_WIDTH - 16 ; go to next line
        .byte $00

        ;;; row 1
        .byte 16        
        .byte $50,$52,$53,$54, $55,$56,$57,$58, $50,$59,$5A,$51, $55,$70,$71,$72
        .byte NT_WIDTH - 16 ; go to next line
        .byte $00

        ;;; row 2 (dropdown begins here, hence 17 bytes)
        .byte 17        
        .byte $50,$62,$63,$64, $65,$66,$67,$68, $50,$69,$6A,$51, $4B,$5B,$6B,$7B,$5D
        .byte NT_WIDTH - 17 ; go to next line
        .byte $00

        ;;; row 3
        .byte 17        
        .byte $60,$61,$73,$74, $75,$76,$77,$78, $60,$79,$7A,$61, $4C,$5C,$6C,$7C,$6D

    ;;; fill rest of screen with black
    ;;; 30 - 3 (header) - 2 ("SUPER") - 4 ("PONG") = 21 remaining rows = 672 bytes 
    ;;; then add remaining bytes in this line = NT_WIDTH - H_OFFSET - 17  
    ;;; total bytes remaining: 687 - H_OFFSET

    .byte 255, $00              ; 432 - H_OFFSET remaining
    .byte 0
    .byte 255, $00              ; 177 - H_OFFSET remaining 
    .byte 0
    .byte (177 - H_OFFSET), $00 ; 0 remaining
    .byte 0 
    
    ;;; attr table
    .byte $40, $00      ; palette zero
    .byte 0 

    .byte 0             ; end
    end: 
.endscope