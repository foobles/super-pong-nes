.import set_game_state_updater

;;; A convenience macro to invoke set_game_state_updater.
;;; See that routine's documentation for more information.
.macro SET_GAME_STATE_RET updater_addr
    JSR ::set_game_state_updater
    .addr (updater_addr)
.endmacro


.macro SET_GAME_STATE_RET_SUB updater_addr
    CLC
    SET_GAME_STATE_RET {updater_addr}
.endmacro


.macro SET_GAME_STATE_RET_GS updater_addr
    SEC
    SET_GAME_STATE_RET {updater_addr}
.endmacro