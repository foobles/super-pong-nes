OAM_RESERVED = 1
OAM_RESERVED_END = 4 * OAM_RESERVED

;;; render queue format:
;;; [ppu addr hi] [ppu addr low] [len] [opcode] [opcode parameters...]


;;; paramters:  [data to write...]
RENDER_IMMEDIATE    = %00000000

;;; paramers:   [data addr low] [data addr hi]
RENDER_INDIRECT     = %10000000

;;; parameters: [byte to be repeated]
RENDER_REPEAT       = %00000001