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
        .byte $3c, $36, $00     ; light blue, peach, grey

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



.export playfield_render_buf
playfield_render_buf:
.incbin "playfield.map"


.export titlescreen_render_buf
titlescreen_render_buf:
.incbin "titlescreen.map"