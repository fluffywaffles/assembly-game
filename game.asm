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

EXTERNDEF DEBUG :DWORD
EXTERNDEF PI_INC_RECIP :FXPT
EXTERNDEF _dwWidth :DWORD
EXTERNDEF _dwHeight :DWORD

.DATA

; Sprites

include space-sprites\asm\nuke_000.asm
include space-sprites\asm\nuke_001.asm
include space-sprites\asm\nuke_002.asm

include space-sprites\asm\fighter_000.asm
include space-sprites\asm\fighter_001.asm
include space-sprites\asm\fighter_002.asm

include space-sprites\asm\asteroid_000.asm
include space-sprites\asm\asteroid_001.asm
include space-sprites\asm\asteroid_002.asm
include space-sprites\asm\asteroid_003.asm
include space-sprites\asm\asteroid_004.asm
include space-sprites\asm\asteroid_005.asm

;; Screen data
SCREEN_X_MIN DWORD 0
SCREEN_X_MAX DWORD 639
SCREEN_Y_MIN DWORD 0
SCREEN_Y_MAX DWORD 479

SCREEN_SIZE DWORD 307200

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

;; other
asteroid_rotation FXPT 50000h
asteroid_collider EECS205RECT <?, ?, ?, ?>
space_down BYTE 0

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

CalculateCollider PROC USES eax edx edi bmpPtr:PTR EECS205BITMAP, colliderPtr:PTR EECS205RECT, x:DWORD, y:DWORD
  LOCAL left:DWORD, top:DWORD, right:DWORD, bottom:DWORD

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

  IFDEF DEBUG
  invoke DrawLine, left, top, left, bottom, 03h
  invoke DrawLine, right, top, right, bottom, 03h
  invoke DrawLine, left, top, right, top, 03h
  invoke DrawLine, left, bottom, right, bottom, 03h
  ENDIF

  ret
CalculateCollider ENDP

CalculatePlayerCollider PROC
  invoke CalculateCollider, CURRENT_PLAYER_SPRITE, OFFSET PLAYER_COLLIDER, PLAYER_X, PLAYER_Y
  ret
CalculatePlayerCollider ENDP

CalculateAsteroidCollider PROC
  invoke CalculateCollider, OFFSET asteroid_000, OFFSET asteroid_collider, 319, 239
  ret
CalculateAsteroidCollider ENDP

DrawPlayer PROC USES eax
  movzx eax, m_click
  cmp eax, 1
  je  with_thrust
  mov eax, KeyPress
  test eax, VK_SPACE
  jne with_thrust
  jmp no_thrust

  with_thrust:
    invoke RotateBlit, OFFSET fighter_001, PLAYER_X, PLAYER_Y, PLAYER_ANGLE
    jmp finish

  no_thrust:
    invoke RotateBlit, OFFSET fighter_000, PLAYER_X, PLAYER_Y, PLAYER_ANGLE

  finish:
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

GamePlay PROC USES eax ebx
  invoke cls

  IFDEF DEBUG
  movzx ebx, space_down
  cmp ebx, 0
  jne yes_space_down
  invoke PLOT, 12, 10, 0c0h
  jmp continue
  yes_space_down:
    invoke PLOT, 12, 10, 01ch
  continue:
  ENDIF

  invoke UpdateTime
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
  	ret
GamePlay ENDP

GameInit PROC
  mov CURRENT_PLAYER_SPRITE, OFFSET fighter_000
	ret
GameInit ENDP

END
