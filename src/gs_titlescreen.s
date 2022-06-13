.include "ppu_inc.s"
.include "render_inc.s"
.include "gamestate_inc.s"

.globalzp   temp, game_state_data
.global     game_state_updater_ret_addr, game_state_updater

GS_TITLESCREEN_NAMETABLE_IDX    = 0
GS_TITLESCREEN_NAMETABLE_HI     = $20 + GS_TITLESCREEN_NAMETABLE_IDX*$04

SCROLL_SPEED = 2

.code

.export begin_game_titlescreen
.proc begin_game_titlescreen
    .importzp local_ppuctrl
    LDA #PPUCTRL_COMMON | PPUCTRL_NAMETABLE{0}
    STA local_ppuctrl

    ;;; run palette setup as render queue
    .import process_render_queue
    .import palette_setup_render_buf, PALETTE_SETUP_RENDER_BUF_LEN:zeropage
    LDA #<palette_setup_render_buf
    STA temp+0
    LDA #>palette_setup_render_buf
    STA temp+1
    LDA #PALETTE_SETUP_RENDER_BUF_LEN
    STA temp+2
    JSR process_render_queue

    ;;; write titlescreen nametable
    .import process_compressed
    .import titlescreen_render_buf
    LDA #<titlescreen_render_buf
    STA temp+0
    LDA #>titlescreen_render_buf
    STA temp+1
    LDA #GS_TITLESCREEN_NAMETABLE_HI
    STA ppuaddr
    LDA #$00
    STA ppuaddr
    JSR process_compressed

    SET_GAME_STATE_RET_SUB {game_state_titlescreen}
.endproc

.proc game_state_titlescreen
    .import begin_game_serve_ball
    .importzp local_ppuscroll_y
    LDA local_ppuscroll_y
    CLC
    ADC #SCROLL_SPEED
    CMP #240
    BCC :+
        JSR begin_game_serve_ball
        JMP game_state_updater_ret_addr
    :
    STA local_ppuscroll_y

    JMP game_state_updater_ret_addr
.endproc