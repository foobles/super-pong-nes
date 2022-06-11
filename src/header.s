;;; NROM-256 specific

.import __HEADER_SIZE__

PRG_PAGE_COUNT  = 2     ; 16 KiB per page
CHR_PAGE_COUNT  = 1     ; 8 KiB per page; 0 = CHR RAM
MIRRORING       = 0     ; 0 = horizontal; 1 = vertical
MAPPER_NO       = 0     ; NROM

.segment "HEADER"
    .byte "NES", $1A
    .byte PRG_PAGE_COUNT
    .byte CHR_PAGE_COUNT
    .byte ((MAPPER_NO & $0F) << 4) | MIRRORING
    .byte MAPPER_NO & $F0
    .res 8, $00


.assert __HEADER_SIZE__ = 16, lderror, "incorrect header size"