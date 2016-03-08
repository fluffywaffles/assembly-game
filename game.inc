; #########################################################################
;
;   game.inc - Includes for EECS205 Assignment 4/5
;
;
; #########################################################################

;; Library Definitions
MouseInfo STRUCT
 horiz DWORD ?
 vert  DWORD ?
 buttons DWORD ?
MouseInfo ENDS

MK_CONTROL  = 0008h  ;; The CTRL key is down.
MK_LBUTTON  = 0001h  ;; The left mouse button is down.
MK_MBUTTON  = 0010h  ;; The middle mouse button is down.
MK_RBUTTON  = 0002h  ;; The right mouse button is down.
MK_SHIFT    = 0004h  ;; The SHIFT key is down.
MK_XBUTTON1 = 0020h  ;; The first X button is down.
MK_XBUTTON2 = 0040h  ;; The second X button is down.

;; Library Functions
BlackStarField	PROTO
DrawStr PROTO myStr:PTR BYTE, x:DWORD, y:DWORD, color:DWORD

;; Library Data
EXTERNDEF StarBitmap:EECS205BITMAP
EXTERNDEF MouseStatus:MouseInfo
EXTERNDEF KeyUp:DWORD
EXTERNDEF KeyDown:DWORD
EXTERNDEF KeyPress:DWORD

;; User Defined Functions
GameInit PROTO
GamePlay PROTO

;; My structs idk

Character STRUCT
  rotation FXPT ?
  pos_x    FXPT ?
  pos_y    FXPT ?
  collider_ptr DWORD ?
Character ENDS

Animation STRUCT
  current_frame BYTE ?
  frame_count   BYTE ?
  frame_size    BYTE ?
  ALIGN DWORD
  frame_ptr     DWORD ?
Animation ENDS

;; Shader repeat modes
ShaderRepeatWrap    = 0
ShaderRepeatStop    = 1
ShaderRepeatReverse = 2

Shader STRUCT
  ; Shader repeat behaviours: 1 - no repeat, 2 - reverse, o/w - wrap (value = initial value)
  ; compare index with LENGTHOF (mask array) to determine when to repeat
  cm_index   BYTE ? ; current mask index
  cm_delta   BYTE ? ; mask index change speed
  cm_repeat  BYTE ? ; mask repeat behaviour
  colorMask  BYTE ? ; current mask value
  cm_src_len BYTE ? ; length of colorMask source array
  ALIGN DWORD
  cm_src     DWORD ? ; ptr to colorMask source array
  ; compare colorShift against cs_bound to determine when to repeat
  cs_bound   BYTE ? ; shift boundary (at which to stop/repeat)
  cs_delta   BYTE ? ; shift change per frame
  cs_repeat  BYTE ? ; shift repeat behaviour
  colorShift BYTE ? ; current color shift
Shader ENDS

Acceleration STRUCT
  x FXPT ?
  y FXPT ?
  angular FXPT ?
Acceleration ENDS

Velocity STRUCT
  x FXPT ?
  y FXPT ?
  angular FXPT ?
Velocity ENDS

Position STRUCT
  x FXPT ?
  y FXPT ?
  rotation FXPT ?
Position ENDS

AnimatedCharacter STRUCT
  position Position <>
  velocity Velocity <>
  acceleration Acceleration <>
  collider EECS205RECT <>
  anim     Animation <>
  shader   Shader <>
AnimatedCharacter ENDS
