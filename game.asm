; #########################################################################
;
;   game.asm - Assembly file for EECS205 Assignment 4/5
;   Jordan Timmerman
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
include input.inc
include keys.inc

include letters.inc

.DATA

;; Sprites
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

;; Timing Data
delta_t FXPT 2000h ; AKA 1/16
total_t FXPT 0

;; Player data
PLAYER_X DWORD 100
PLAYER_Y DWORD 100
PLAYER_ANGLE FXPT 0

PLAYER_VX DWORD 0
PLAYER_VY DWORD 0

CURRENT_PLAYER_SPRITE DWORD ? ; PTR EECS205BITMAP

PLAYER_COLLIDER EECS205RECT <?, ?, ?, ?>

;; Animations
NukeAnimation Animation { 0, 3, SIZEOF EECS205BITMAP,, OFFSET nuke_000 }
FighterAnimation Animation { 0, 3, SIZEOF EECS205BITMAP,, OFFSET fighter_000 }

Fighter Character { , , , , , 1, }

;; other
asteroid_rotation FXPT 0
asteroid_collider EECS205RECT <?, ?, ?, ?>
space_down BYTE 0

rot_offset FXPT 0c900h ; approximately pi/2 to maximum possible accuracy

wCollide DWORD l7c, l7o, l7l,
               l7l, l7i, l7d,
               l7e, l7exclamation

opacities BYTE 4 DUP(0ffh), 4 DUP(0dah), 4 DUP(09h), 4 DUP(0)

IFDEF DEBUG

l3alpha DWORD l3a, l3b, l3c, l3d, l3e, l3f, l3g, l3h, l3i, l3j, l3k, l3l, l3m,
              l3n, l3o, l3p, l3q, l3r, l3s, l3t, l3u, l3v, l3w, l3x, l3y, l3z,
              l3exclamation

l5alpha DWORD l5a, l5b, l5c, l5d, l5e, l5f, l5g, l5h, l5i, l5j, l5k, l5l, l5m,
              l5n, l5o, l5p, l5q, l5r, l5s, l5t, l5u, l5v, l5w, l5x, l5y, l5z,
              l5exclamation

l7alpha DWORD l7a, l7b, l7c, l7d, l7e, l7f, l7g, l7h, l7i, l7j, l7k, l7l, l7m,
              l7n, l7o, l7p, l7q, l7r, l7s, l7t, l7u, l7v, l7w, l7x, l7y, l7z,
              l7exclamation

ENDIF

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

  mov eax, _dwWidth
  cmp eax, _dwHeight
  jg  dont_swap_wh
  mov eax, _dwHeight

  dont_swap_wh:

  mov ebx, 2
  cdq
  div ebx
  cmp edx, 0
  jl  continue_comp
  inc eax
  continue_comp:

  invoke AXP, eax, sqrt2, 0
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

UpdatePlayer PROC USES eax
  mov eax, m_x
  mov PLAYER_X, eax

  mov eax, m_y
  mov PLAYER_Y, eax
  ret
UpdatePlayer ENDP

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
    invoke RotateBlit, CURRENT_PLAYER_SPRITE, PLAYER_X, PLAYER_Y, PLAYER_ANGLE, (Character PTR Fighter).opacity, 0
    ret
DrawPlayer ENDP

DrawAsteroid PROC USES ebx
  mov ebx, asteroid_rotation
  add ebx, delta_t
  mov asteroid_rotation, ebx
  invoke RotateBlit, OFFSET asteroid_000, 319, 239, ebx, 255, 0
  ret
DrawAsteroid ENDP

DrawCollideWarning PROC
  invoke DrawWord, OFFSET wCollide, LENGTHOF wCollide, 280, 200, 0c0h
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

  .if pause != 0
    jmp skip_frame
  .endif

  invoke cls

  invoke UnpackMouse
  invoke UnpackKeyPress

  IFDEF DEBUG
  invoke DrawWord, OFFSET l7alpha, LENGTHOF l7alpha, 10, 420, 0c3h
  invoke DrawWord, OFFSET l5alpha, LENGTHOF l5alpha, 10, 430, 0c3h
  invoke DrawWord, OFFSET l3alpha, LENGTHOF l3alpha, 10, 438, 0c3h
  ENDIF

  mov eax, (Character PTR Fighter).fade
  mov ebx, (Character PTR Fighter).fademod
  mov edx, LENGTHOF opacities
  dec edx
  add eax, ebx
  cmp ebx, 0
  jg  end_up
  jl  end_down
  jmp set_opacity
  end_up:
    cmp eax, edx
    jl  set_opacity
    neg ebx
    mov (Character PTR Fighter).fademod, ebx
    jmp set_opacity
  end_down:
    cmp eax, 0
    jne set_opacity
    neg ebx
    mov (Character PTR Fighter).fademod, ebx
  set_opacity:
    mov (Character PTR Fighter).fade, eax
    mov eax, [ OFFSET opacities + eax ]
    mov (Character PTR Fighter).opacity, eax

  invoke UpdatePlayer
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
    invoke TogglePause
  	ret
GamePlay ENDP

GameInit PROC
  mov CURRENT_PLAYER_SPRITE, OFFSET fighter_000
	ret
GameInit ENDP

END
