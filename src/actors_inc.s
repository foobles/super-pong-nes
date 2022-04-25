.globalzp   actor_flags, actor_ids, actor_xs, actor_ys
.globalzp   actor_updaters_lo, actor_updaters_hi, actor_renderers_lo, actor_renderers_hi
.global     actor_collisions_x, actor_collisions_y, actor_collisions_w, actor_collisions_h
.global     actor_data0, actor_data1, actor_data2, actor_data3
.globalzp   actor_next_idx

.global     actor_updater_ret, actor_renderer_ret_addr

;;; work best as powers of 2 for easily checking bit patterns
;;; if these are changed to be not powers of 2, be sure to check over
;;; logic that works with the actor arrays
MAX_ACTORS = 16

;;; actor flag format
;;; 7 6 5 4 3 2 1 0
;;; | | | | +-+-+-+- [0-3]  for use by actor
;;; | | | +--------- [4]    actor exists (can only be 0 when all other bits 0) [0=nonexistent; 1=exists]
;;; | | +----------- [5]    enable updates [0=off; 1=on]
;;; | +------------- [6]    enable rendering [0=off; 1=on]
;;; +--------------- [7]    enable collision (other entities can collide with this) [0=off; 1=on]
;;;
;;; flag[4] only allowed to be 0 when all other bits are also 0 means
;;; that if rendering, updates, or collision bits are 1, then the actor
;;; must exist. Likewise, the flag byte can be simply checked for 0 to see
;;; if the actor exists rather than needing to test the exact bit.

ACTOR_FLAG_EXISTS   = 1<<4
ACTOR_FLAG_UPDATE   = 1<<5
ACTOR_FLAG_RENDER   = 1<<6
ACTOR_FLAG_COLLIDE  = 1<<7

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
;;;     X: actor to set renderer for
;;; overwrites:
;;;     A
.macro SET_ACTOR_RENDERER renderer
    LDA #<renderer
    STA ::actor_renderers_lo,X
    LDA #>renderer
    STA ::actor_renderers_hi,X
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