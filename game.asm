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

include common.inc
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
PLAYER_VX DWORD 0
PLAYER_VY DWORD 0

;; Animations
NukeAnimation Animation { 0, 3, SIZEOF EECS205BITMAP,, OFFSET nuke_000 }

;; Shaders
FadeInOut Shader { 0, 2, 2, 0ffh, ?, ?, ?, ? }

;; Fighter (Player)
Fighter AnimatedCharacter { 0, 100, 100,,, }
FighterCollider EECS205RECT { ?, ?, ?, ? }
FighterAnimation Animation { 0, 3, SIZEOF EECS205BITMAP,, OFFSET fighter_000 }

;; other
asteroid_rotation FXPT 0
asteroid_collider EECS205RECT <?, ?, ?, ?>
space_down BYTE 0

rot_offset FXPT 0c900h ; approximately pi/2 to maximum possible accuracy

wCollide DWORD l7c, l7o, l7l,
               l7l, l7i, l7d,
               l7e, l7exclamation

opacities BYTE 4 DUP(0ffh), 4 DUP(0dah), 4 DUP(09h), 4 DUP(0)

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
  invoke CalculateCollider, Fighter.anim.frame_ptr, OFFSET Fighter.collider, Fighter.pos_x, Fighter.pos_y, Fighter.rotation
  ret
CalculatePlayerCollider ENDP

CalculateAsteroidCollider PROC
  invoke CalculateCollider, OFFSET asteroid_000, OFFSET asteroid_collider, 319, 239, asteroid_rotation
  ret
CalculateAsteroidCollider ENDP

UpdatePlayer PROC USES eax
  mov eax, m_x
  mov Fighter.pos_x, eax

  mov eax, m_y
  mov Fighter.pos_y, eax
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
      mov Fighter.anim.frame_ptr, OFFSET fighter_001
      jmp finish

    less_thrust:
      cmp ebx, 1
      jl  no_thrust

      mov Fighter.anim.frame_ptr, OFFSET fighter_002
      jmp finish

    no_thrust:
      mov Fighter.anim.frame_ptr, OFFSET fighter_000

  finish:
    movzx ecx, Fighter.shader.colorMask
    invoke RotateBlit, Fighter.anim.frame_ptr, Fighter.pos_x, Fighter.pos_y, Fighter.rotation, ecx, 0
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

  invoke DebugLetters

  ENDIF

  mov ah, Fighter.shader.cm_index
  mov al, Fighter.shader.cm_delta
  mov dh, Fighter.shader.cm_repeat
  mov dl, LENGTHOF opacities
  dec dl
  add ah, al
  cmp al, 0
  jg  end_up
  jl  end_down
  jmp set_opacity
  end_up:
    cmp ah, dl
    jl  set_opacity
    neg Fighter.shader.cm_delta
    jmp set_opacity
  end_down:
    cmp ah, 0
    jne set_opacity
    neg Fighter.shader.cm_delta
  set_opacity:
    mov Fighter.shader.cm_index, ah
    movzx ecx, ah
    movzx ecx, opacities[ecx]
    mov Fighter.shader.colorMask, cl

  invoke UpdatePlayer
  invoke DrawPlayer
  invoke CalculatePlayerCollider

  invoke DrawAsteroid
  invoke CalculateAsteroidCollider

  invoke CheckIntersectRect, OFFSET Fighter.collider, OFFSET asteroid_collider
  cmp eax, 1
  jne no_collision

  invoke DrawCollideWarning

  no_collision:
  skip_frame:
    invoke TogglePause
  	ret
GamePlay ENDP

GameInit PROC
  mov Fighter.shader.cm_index, 0
  mov Fighter.shader.cm_delta, 1
  mov Fighter.shader.cm_repeat, 0
  mov Fighter.shader.colorMask, 0ffh
	ret
GameInit ENDP

END
