.include "input_inc.s"

.zeropage
    .exportzp joy0_state, joy1_state
    joy0_state: .res 1
    joy1_state: .res 1


.code

.export read_inputs
.proc read_inputs
    LDA #1
    STA joy0        ; begin strobe
    STA joy1_state  ; set up loop
    LSR A           ; A <- 0
    STA joy0        ; end strobe

    read_buttons:
        ;;; read button into joy0_state
        LDA joy0        ; load button state
        LSR A           ; shift button state into C 
        ROL joy0_state  ; rotate C into joy0 state

        ;;; read button into joy1_state
        LDA joy1        
        LSR A          
        ROL joy1_state

        ;;; joy1_state was initialized with %00000001 
        ;;; when C is 1 after ROL, that means 8 iterations have passed
        ;;; there are 8 buttons, so this means the loop should end
        BCC read_buttons

    RTS
.endproc