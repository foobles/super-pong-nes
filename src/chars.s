.include "ppu_inc.s"

.globalzp temp 

.segment "CHARS0"
    .incbin "chr0.chr"

.segment "CHARS1"
    .incbin "chr1.chr"


.code 

;;; parameters:
;;;     temp+0/1:   address of render queue
;;;     temp+2:     length of render queue
;;;
;;; overwrites:
;;;     A, X, Y, temp+3/4/5
.export process_render_queue
.proc process_render_queue
    queue_addr      = temp+0
    queue_len       = temp+2
    indirect_addr   = temp+3
    y_temp          = temp+5

    ;;; X   = remaining length of data to write
    ;;; Y   = index into render queue
    LDY #0
    read_instruction:
        CPY queue_len
        BEQ end 

        ;;; load ppu address and length (common to every instruction before opcode)
        LDA (queue_addr),Y 
        STA ppuaddr 
        INY 
        LDA (queue_addr),Y 
        STA ppuaddr 
        INY 
        LDA (queue_addr),Y 
        TAX 
        INY 

        ;;; branch to correct instruction handler        
        LDA (queue_addr),Y      ; load instruction code
        BEQ process_immediate   ; assume RENDER_IMMEDIATE = 0
        BMI process_indirect    ; assume RENDER_INDIRECT has bit 7 set
        
        ;;; fallthrough process repeat, assume RENDER_REPEAT is neither 0 nor has bit 7 set
            INY 
            ;;; load byte to repeat
            LDA (queue_addr),Y 
            INY 
            ;;; write data into ppu
            :
                STA ppudata 
                DEX 
                BNE :- 

            JMP read_instruction

        process_immediate:
            INY 
            ;;; write data into ppu
            :
                LDA (queue_addr),Y 
                INY 
                STA ppudata 
                DEX 
                BNE :- 

            JMP read_instruction

        process_indirect:
            INY 
            ;;; set up indirect address to copy from
            LDA (queue_addr),Y 
            STA indirect_addr+0 
            INY 
            LDA (queue_addr),Y 
            STA indirect_addr+1 
            INY

            STY y_temp  ; save Y index since Y needs to be used for indirect copy

            ;;; copy data into ppu
            LDY #0
            :
                LDA (indirect_addr),Y 
                INY 
                STA ppudata
                DEX 
                BNE :- 

            LDY y_temp  ; reload Y index
            JMP read_instruction
    end: 
    RTS 
.endproc 