.include "ppu_inc.s"

.globalzp temp 

.zeropage 
    .exportzp local_ppuctrl, local_ppumask, nmi_handler_done, oam_stack_idx
    local_ppuctrl:  .res 1
    local_ppumask:  .res 1

    ;;; not done:   %0000000
    ;;; done:       %1000000
    nmi_handler_done:   .res 1

    oam_stack_idx:      .res 1

.bss
    local_oam:    
        .align $100
        .res $100

    
    .export render_queue, render_queue_len
    render_queue:       .res $80
    render_queue_len:   .res 1


.code 

;;; do not call manually
;;; overwrites A, X, Y, all temp
.export handle_nmi
.proc handle_nmi
    ;;; clear latch
    BIT ppustatus

    ;;; update sprites
    LDA #>local_oam
    STA oamdma

    ;;; process render queue
    LDA #<render_queue
    STA temp+0 
    LDA #>render_queue
    STA temp+1
    LDA render_queue_len
    STA temp+2
    JSR process_render_queue
    
    ;;; update ppuctrl
    LDA local_ppuctrl
    STA ppuctrl

    ;;; update scroll position
    LDA #0          
    STA ppuscroll           ; x scroll
    STA ppuscroll           ; y scroll
    STA render_queue_len    ; reset queue length for next frame

    ;;; set bit 7 of nmi_handler_done
    LDA #(1 << 7)
    STA nmi_handler_done

    RTI
.endproc



;;; parameters:
;;;     A:          pattern
;;;     temp+0:  X position
;;;     temp+1:  Y position
;;;     temp+2:  attributes
;;; overwrites:
;;;     A, Y
.export push_tile
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

;;; overwrites:
;;;     A, X
.export hide_unused_oam
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