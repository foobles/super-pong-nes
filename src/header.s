;;; NROM-256 specific

.import __HEADER_SIZE__

prg_page_count  = 2     ; 16 KiB per page 
chr_page_count  = 1     ; 8 KiB per page; 0 = CHR RAM
mirroring       = 1     ; 0 = horizontal; 1 = vertical
mapper_no       = 0     ; NROM

.segment "HEADER"
    .byte "NES", $1A
    .byte prg_page_count
    .byte chr_page_count
    .byte ((mapper_no & $0F) << 4) | mirroring
    .byte mapper_no & $F0
    .res 8, $00


.assert __HEADER_SIZE__ = 16, lderror, "incorrect header size"