.globalzp   temp
.importzp   actor_flags, actor_ids, actor_xs, actor_ys, actor_updaters_lo, actor_updaters_hi
.import     actor_collisions_x, actor_collisions_y, actor_collisions_w, actor_collisions_h
.import     actor_data0, actor_data1, actor_data2, actor_data3
.importzp   actor_next_idx, actor_count

.import actor_updater_ret_addr


;;; parameters:
;;;     X: actor to set flags for
;;; overwrites:
;;;     A
.macro SET_ACTOR_FLAGS flags
    LDA #flags
    STA ::actor_flags,X
.endmacro

;;; parameters:
;;;     X: actor to set id for
;;; overwrites:
;;;     A
.macro SET_ACTOR_ID id
    LDA #id
    STA ::actor_ids,X
.endmacro

;;; parameters:
;;;     X: actor to set position for
;;; overwrites:
;;;     A
.macro SET_ACTOR_POS xpos, ypos
    LDA #xpos
    STA ::actor_xs,X
    .if (xpos <> ypos)
        LDA #ypos
    .endif
    STA ::actor_ys,X
.endmacro

;;; parameters:
;;;     X: actor to set updater for
;;; overwrites:
;;;     A
.macro SET_ACTOR_UPDATER updater
    LDA #<updater
    STA ::actor_updaters_lo,X
    LDA #>updater
    STA ::actor_updaters_hi,X
.endmacro

;;; parameters:
;;;     X: actor to set collision data for
;;; overwrites:
;;;     A
.macro SET_ACTOR_HITBOX x_offset, y_offset, width, height
    LDA #x_offset
    STA ::actor_collisions_x,X
    .if (x_offset <> y_offset)
        LDA #y_offset
    .endif
    STA ::actor_collisions_y,X

    LDA #width
    STA ::actor_collisions_w,X
    .if (width <> height)
        LDA #height
    .endif
    STA ::actor_collisions_h,X
.endmacro

;;; parameters:
;;;     X: actor to fill data for
;;; overwrites:
;;;     A
.macro FILL_ACTOR_DATA value
    LDA #value
    STA ::actor_data0,X
    STA ::actor_data1,X
    STA ::actor_data2,X
    STA ::actor_data3,X
.endmacro