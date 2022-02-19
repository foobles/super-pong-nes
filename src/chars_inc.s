CHR0_BLANK          = $00
CHR0_LOGO_START     = $40
CHR0_LOGO_SHADOW_0  = $80
CHR0_LOGO_SHADOW_1  = $90
CHR0_TEXT_OUTLINE   = $81

CHR1_BALL       = $01
CHR1_PADDLE_END = $02
CHR1_PADDLE_MID = $03


;;; render queue format:
;;; [ppu addr hi] [ppu addr low] [len] [opcode] [opcode parameters...]


;;; paramters:  [data to write...]
RENDER_IMMEDIATE    = %00000000

;;; paramers:   [data addr low] [data addr hi] 
RENDER_INDIRECT     = %10000000

;;; parameters: [byte to be repeated]
RENDER_REPEAT       = %00000001