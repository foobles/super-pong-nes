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


    ;;; immediate   draw SUPER top row
    .byte 8         ; len
    .byte $89, $8A, $8B, $8C, $8D, $8E, $8F, $91

    .byte NT_WIDTH - 8  ; go to next line
    .byte $00

    ;;; immediate   draw SUPER bottom row
    .byte 8         ; len
    .byte $99, $9A, $9B, $9C, $9D, $9E, $9F, $92

    .byte NT_WIDTH - 8 ; go to next line
    .byte $00

    ;;; draw PONG
        ;;; row 0
        .byte 16        
        .byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
        .byte NT_WIDTH - 16 ; go to next line
        .byte $00

        ;;; row 1
        .byte 16        
        .byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
        .byte NT_WIDTH - 16 ; go to next line
        .byte $00

        ;;; row 2 (dropdown begins here, hence 17 bytes)
        .byte 17        
        .byte $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6E,$6F,$80
        .byte NT_WIDTH - 17 ; go to next line
        .byte $00

        ;;; row 3
        .byte 17        
        .byte $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F,$90

    .byte 0             ; end
    end: 
.endscope