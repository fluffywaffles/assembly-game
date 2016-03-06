; #########################################################################
;
;   game.asm - Assembly file for EECS205 Assignment 4/5
;
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include stars.inc
include lines.inc
include blit.inc
include game.inc
include keys.inc

PLOT PROTO :DWORD, :DWORD, :DWORD
int2fxpt PROTO :DWORD
UnpackBitmap PROTO bmp:PTR EECS205BITMAP
EdgesFromCenter PROTO centerpoint:DWORD, len:DWORD
FXPTDivide PROTO :FXPT, :FXPT

EXTERNDEF PI_INC_RECIP :FXPT
EXTERNDEF PI_HALF :FXPT
EXTERNDEF _dwWidth :DWORD
EXTERNDEF _dwHeight :DWORD

.DATA

; Sprites

include space-sprites\asm\nuke_000.asm
include space-sprites\asm\nuke_001.asm
include space-sprites\asm\nuke_002.asm

include space-sprites\asm\fighter_000.asm
include space-sprites\asm\fighter_002.asm
include space-sprites\asm\fighter_001.asm

include space-sprites\asm\asteroid_000.asm
include space-sprites\asm\asteroid_001.asm
include space-sprites\asm\asteroid_002.asm
include space-sprites\asm\asteroid_003.asm
include space-sprites\asm\asteroid_004.asm
include space-sprites\asm\asteroid_005.asm

;; constant
sqrt2 FXPT 00016a0ah ; approx. 1.41421508789

pause BYTE 0
next_pause FXPT 0

;; Mouse data
m_x DWORD ?
m_y DWORD ?
m_click BYTE ?
m_rclick BYTE ?

;; Timing Data
delta_t DWORD 2000h ; AKA 1/16
total_t DWORD 0

;; Player data
PLAYER_X DWORD 100
PLAYER_Y DWORD 100
PLAYER_ANGLE FXPT 0

PLAYER_VX DWORD 0
PLAYER_VY DWORD 0

CURRENT_PLAYER_SPRITE DWORD ? ; PTR EECS205BITMAP

PLAYER_COLLIDER EECS205RECT <?, ?, ?, ?>

;; Animations
NukeAnimation Animation { 0, 3, SIZEOF EECS205BITMAP, OFFSET nuke_000 }
FighterAnimation Animation { 0, 3, SIZEOF EECS205BITMAP, OFFSET fighter_000 }

;; other
asteroid_rotation FXPT 0
asteroid_collider EECS205RECT <?, ?, ?, ?>
space_down BYTE 0

rot_offset FXPT 0c900h

.CODE

cls PROC
  mov esi, ScreenBitsPtr
  mov edx, SCREEN_SIZE
  xor eax, eax

  while_loop:
    cmp eax, edx
    jge finish

    mov BYTE PTR [ esi + eax ], 00h
    inc eax

    jmp while_loop

  finish:
    ret
cls ENDP

UpdateTime PROC USES eax
  mov eax, total_t
  add eax, delta_t
  mov total_t, eax
  ret
UpdateTime ENDP

GetZF PROC USES eax
  lahf
  shl eax, 1  ; cut off SF
  shr eax, 22 ; trunc to just zf
  ret
GetZF ENDP

UnpackMouse PROC
  mov esi, OFFSET MouseStatus

  mov eax, [esi]     ; mx
  mov m_x, eax

  mov eax, [esi + 4] ; my
  mov m_y, eax

  mov eax, [esi + 8] ; buttons

  test eax, MK_LBUTTON
  invoke GetZF
  mov m_click, al

  test eax, MK_RBUTTON
  invoke GetZF
  mov m_rclick, al

  IFDEF DEBUG
  invoke PLOT, m_x, m_y, 01ch

  movzx ebx, m_click
  cmp ebx, 1
  jne no_click
  invoke PLOT, 10, 10, 01ch
  jmp click_next
  no_click:
    invoke PLOT, 10, 10, 0c0h
  click_next:

  ENDIF

  ret
UnpackMouse ENDP

CalculateCollider PROC USES eax edx edi bmpPtr:PTR EECS205BITMAP, colliderPtr:PTR EECS205RECT, x:DWORD, y:DWORD, rotation:FXPT
  LOCAL left:DWORD, top:DWORD, right:DWORD, bottom:DWORD
  LOCAL r_sqrt2:FXPT, sina:FXPT, cosa:FXPT, xcomp:FXPT, ycomp:FXPT
  LOCAL x_cos:FXPT, x_sin:FXPT, y_cos:FXPT, y_sin:FXPT, xpcos:FXPT, xpsin:FXPT, ypcos:FXPT, ypsin:FXPT

  invoke UnpackBitmap, bmpPtr
  mov edi, colliderPtr

  invoke EdgesFromCenter, x, _dwWidth
  mov [edi], eax     ; left
  mov [edi + 8], edx ; right
  mov left, eax
  mov right, edx

  invoke EdgesFromCenter, y, _dwHeight
  mov [edi + 4], eax  ; top
  mov [edi + 12], edx ; bottom
  mov top, eax
  mov bottom, edx

  mov edx, rotation
  add edx, rot_offset
  neg edx
  invoke FixedSin, edx
  mov sina, eax
  invoke FixedCos, edx
  mov cosa, eax

  invoke FXPTDivide, _dwWidth, 20000h
  invoke AXP, eax, sqrt2, eax
  mov r_sqrt2, eax

  invoke AXP, r_sqrt2, cosa, 0
  mov xcomp, eax
  invoke AXP, r_sqrt2, sina, 0
  mov ycomp, eax

  mov eax, x
  sub eax, xcomp
  mov x_cos, eax
  add eax, xcomp
  add eax, xcomp
  mov xpcos, eax
  sub eax, xcomp
  sub eax, ycomp
  mov x_sin, eax
  add eax, ycomp
  add eax, ycomp
  mov xpsin, eax

  mov eax, y
  sub eax, xcomp
  mov y_cos, eax
  add eax, xcomp
  add eax, xcomp
  mov ypcos, eax
  sub eax, xcomp
  sub eax, ycomp
  mov y_sin, eax
  add eax, ycomp
  add eax, ycomp
  mov ypsin, eax

  IFDEF DEBUG
  invoke DrawLine, x_sin, y_cos, xpcos, y_sin, 03h
  invoke DrawLine, x_sin, y_cos, x_cos, ypsin, 03h
  invoke DrawLine, xpsin, ypcos, xpcos, y_sin, 03h
  invoke DrawLine, xpsin, ypcos, x_cos, ypsin, 03h
  ENDIF

  ret
CalculateCollider ENDP

CalculatePlayerCollider PROC
  invoke CalculateCollider, CURRENT_PLAYER_SPRITE, OFFSET PLAYER_COLLIDER, PLAYER_X, PLAYER_Y, PLAYER_ANGLE
  ret
CalculatePlayerCollider ENDP

CalculateAsteroidCollider PROC
  invoke CalculateCollider, OFFSET asteroid_000, OFFSET asteroid_collider, 319, 239, asteroid_rotation
  ret
CalculateAsteroidCollider ENDP

DrawPlayer PROC USES eax
  xor ebx, ebx

  click:
    movzx eax, m_click
    cmp eax, 1
    jne  space
    inc ebx

  space:
    mov eax, KeyPress
    cmp eax, VK_SPACE
    jne draw
    inc ebx

  draw:
    cmp ebx, 2
    jl  less_thrust

    lotsa_thrust:
      mov CURRENT_PLAYER_SPRITE, OFFSET fighter_001
      jmp finish

    less_thrust:
      cmp ebx, 1
      jl  no_thrust

      mov CURRENT_PLAYER_SPRITE, OFFSET fighter_002
      jmp finish

    no_thrust:
      mov CURRENT_PLAYER_SPRITE, OFFSET fighter_000

  finish:
    invoke RotateBlit, CURRENT_PLAYER_SPRITE, PLAYER_X, PLAYER_Y, PLAYER_ANGLE
    ret
DrawPlayer ENDP

DrawAsteroid PROC USES ebx
  mov ebx, asteroid_rotation
  add ebx, delta_t
  mov asteroid_rotation, ebx
  invoke RotateBlit, OFFSET asteroid_000, 319, 239, ebx
  ret
DrawAsteroid ENDP

DrawCollideWarning PROC
  invoke PLOT, 281, 200, 0c0h ;; c
  invoke PLOT, 280, 201, 0c0h
  invoke PLOT, 281, 202, 0c0h
  invoke PLOT, 284, 201, 0c0h ;; o
  invoke PLOT, 285, 200, 0c0h
  invoke PLOT, 285, 202, 0c0h
  invoke PLOT, 286, 201, 0c0h
  invoke PLOT, 288, 200, 0c0h ;; l
  invoke PLOT, 288, 201, 0c0h
  invoke PLOT, 288, 202, 0c0h
  invoke PLOT, 289, 202, 0c0h
  invoke PLOT, 290, 202, 0c0h
  invoke PLOT, 292, 200, 0c0h ;; l
  invoke PLOT, 292, 201, 0c0h
  invoke PLOT, 292, 202, 0c0h
  invoke PLOT, 293, 202, 0c0h
  invoke PLOT, 294, 202, 0c0h
  invoke PLOT, 296, 200, 0c0h ;; i
  invoke PLOT, 296, 202, 0c0h
  invoke PLOT, 297, 200, 0c0h
  invoke PLOT, 297, 201, 0c0h
  invoke PLOT, 297, 202, 0c0h
  invoke PLOT, 298, 200, 0c0h
  invoke PLOT, 298, 202, 0c0h
  invoke PLOT, 300, 200, 0c0h ;; d
  invoke PLOT, 300, 201, 0c0h
  invoke PLOT, 300, 202, 0c0h
  invoke PLOT, 301, 200, 0c0h
  invoke PLOT, 301, 202, 0c0h
  invoke PLOT, 302, 201, 0c0h
  invoke PLOT, 304, 201, 0c0h ;; e
  invoke PLOT, 305, 200, 0c0h
  invoke PLOT, 305, 201, 0c0h
  invoke PLOT, 305, 202, 0c0h
  invoke PLOT, 306, 200, 0c0h
  invoke PLOT, 306, 202, 0c0h
  invoke PLOT, 309, 200, 0c0h ;; !
  invoke PLOT, 309, 201, 0c0h
  invoke PLOT, 309, 203, 0c0h
  ret
DrawCollideWarning ENDP

TogglePause PROC USES eax
  mov eax, total_t
  cmp eax, next_pause
  jl  _end
  mov eax, KeyPress
  cmp eax, VK_P
  je  toggle
  jmp _end
  toggle:
    not pause
    mov eax, total_t
    add eax, delta_t
    add eax, delta_t
    add eax, delta_t
    mov next_pause, eax
  _end:
    ret
TogglePause ENDP

GamePlay PROC USES eax ebx
  invoke UpdateTime

  invoke TogglePause
  cmp pause, 0
  jne skip_frame

  invoke cls

  IFDEF DEBUG
  mov eax, KeyPress
  cmp eax, VK_SPACE
  je yes_space_down
  invoke PLOT, 12, 10, 0c0h
  jmp continue
  yes_space_down:
    invoke PLOT, 12, 10, 01ch
  continue:
  cmp eax, VK_P
  je yes_p_down
  invoke PLOT, 14, 10, 0c0h
  jmp continue_p
  yes_p_down:
    invoke PLOT, 14, 10, 01ch
  continue_p:
  ENDIF

  invoke UnpackMouse

  mov eax, m_x
  mov PLAYER_X, eax

  mov eax, m_y
  mov PLAYER_Y, eax

  invoke DrawPlayer
  invoke CalculatePlayerCollider

  invoke DrawAsteroid
  invoke CalculateAsteroidCollider

  invoke CheckIntersectRect, OFFSET PLAYER_COLLIDER, OFFSET asteroid_collider
  cmp eax, 1
  jne no_collision

  invoke DrawCollideWarning

  no_collision:
  skip_frame:
  	ret
GamePlay ENDP

GameInit PROC
  mov CURRENT_PLAYER_SPRITE, OFFSET fighter_000
	ret
GameInit ENDP

END
