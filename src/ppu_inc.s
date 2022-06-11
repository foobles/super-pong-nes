ppuctrl     = $2000
ppumask     = $2001
ppustatus   = $2002
oamaddr     = $2003
oamdata     = $2004
ppuscroll   = $2005
ppuaddr     = $2006
ppudata     = $2007
oamdma      = $4014

ppu_palette_table   =   $3F00


.define PPUCTRL_NAMETABLE(n)        ((n) << 0)
        PPUCTRL_VRAM_INC_1      =   (0 << 2)
        PPUCTRL_VRAM_INC_32     =   (1 << 2)
.define PPUCTRL_SPRITE_TABLE(n)     ((n) << 3)
.define PPUCTRL_TILE_TABLE(n)       ((n) << 4)
        PPUCTRL_LARGE_SPRITES   =   (1 << 5)
        PPUCTRL_ENABLE_NMI      =   (1 << 7)


PPUMASK_GRAYSCALE           = (1 << 0)
PPUMASK_SHOW_COL0_TILES     = (1 << 1)
PPUMASK_SHOW_COL0_SPRITES   = (1 << 2)
PPUMASK_SHOW_TILES          = (1 << 3)
PPUMASK_SHOW_SPRITES        = (1 << 4)
PPUMASK_EMPH_RED            = (1 << 5)
PPUMASK_EMPH_GREEN          = (1 << 6)
PPUMASK_EMPH_BLUE           = (1 << 7)

PPUMASK_SHOW_ALL = PPUMASK_SHOW_COL0_TILES | PPUMASK_SHOW_COL0_SPRITES | PPUMASK_SHOW_TILES | PPUMASK_SHOW_SPRITES

;;; game-specific common ppuctrl flags throughout majority of execution
PPUCTRL_COMMON = PPUCTRL_ENABLE_NMI | PPUCTRL_VRAM_INC_1 | PPUCTRL_TILE_TABLE{0} | PPUCTRL_SPRITE_TABLE{1}

.define SPRITE_ATTR_PALETTE(n)          ((n) << 0)
        SPRITE_ATTR_BEHIND_TILES    =   (1 << 5)
        SPRITE_ATTR_FLIP_H          =   (1 << 6)
        SPRITE_ATTR_FLIP_V          =   (1 << 7)
