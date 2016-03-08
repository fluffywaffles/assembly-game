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

;===============================================================================
; Includes
;===============================================================================
;-------------------------------------------------------------------------------
include \masm32\include\windows.inc ; wsprintf
include \masm32\include\user32.inc  ; wsprintf
include \masm32\include\winmm.inc   ; PlaySound
include \masm32\include\masm32.inc  ; nseed, nrandom
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
includelib \masm32\lib\user32.lib ; wsprintf
includelib \masm32\lib\winmm.lib  ; PlaySound
includelib \masm32\lib\masm32.lib ; nseed, nrandom
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;- common.inc: important global constants like DEBUG
include common.inc
;- stars.inc: AXP
include stars.inc
;- lines.inc: DrawLines, PI_*
include lines.inc
;- blit.inc: BasicBlit, RotateBlit
include blit.inc
;- game.inc: All of the custom game structs
include game.inc
;- input.inc: keyboard and mouse globals
include input.inc
;- keys.inc: virtual keycodes
include keys.inc
;- letters.inc: 3 font sizes for creating simple messages
include letters.inc
;-------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Asteroid Generation, Initialization, Shader Calculation, and Drawing
include asteroid-macros.asm
;-------------------------------------------------------------------------------

.DATA

;===============================================================================
; Game-related Constants
;===============================================================================
;-------------------------------------------------------------------------------
;; Sprites
;-------------------------------------------------------------------------------
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
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Beginning rotation offset; IMPORTANT for rotation of collider
;-------------------------------------------------------------------------------
rot_offset FXPT 0c900h ; approximately pi/2 to maximum possible accuracy
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Throttled Inputs
;-------------------------------------------------------------------------------
pause BYTE 0
next_pause FXPT 0
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Timing Data
;-------------------------------------------------------------------------------
delta_t FXPT 2000h ; AKA 1/16
total_t FXPT 0
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Ticks
;-------------------------------------------------------------------------------
Ticks DWORD 0
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Shaders (These are just examples)
;-------------------------------------------------------------------------------
;; "Base" Shader                              ; $ = current addr, no source array
BaseShader Shader { 0, 0, ShaderRepeatStop, 0ffh, 0, $, 0, 0, ShaderRepeatStop, 0 }
;; Shader source array for FadeInOut
opacities BYTE 4 DUP(0ffh), 4 DUP(0dah), 4 DUP(09h), 4 DUP(0)
;; ColorMask shader
FadeInOut Shader { 0, 2, ShaderRepeatReverse, 0ffh, LENGTHOF opacities, OFFSET opacities, ?, ?, ?, ? }
;; ColorShift shader
Rainbow Shader   { ?, ?, ?, ?, ?, ?, 36, 1, ShaderRepeatReverse, 0 }
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Fighter (Player)
;-------------------------------------------------------------------------------
Fighter AnimatedCharacter { 0, 100, 350,,, }
FighterCollider EECS205RECT { ?, ?, ?, ? }
FighterAnimation Animation { 0, 3, SIZEOF EECS205BITMAP, OFFSET fighter_000 }
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Asteroid
;-------------------------------------------------------------------------------
Asteroid AnimatedCharacter { 0, 319, 239,,, }
AsteroidCollider EECS205RECT { ?, ?, ?, ? }
AsteroidAnimation Animation { 0, 1, SIZEOF EECS205BITMAP, OFFSET asteroid_000 }
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Asteroid creation
;-------------------------------------------------------------------------------
CreateAsteroids AsteroidList
CreateAsteroids AsteroidList2
CreateAsteroids AsteroidList3
CreateAsteroids AsteroidList4

;-------------------------------------------------------------------------------
;; Strings and Words and such
;-------------------------------------------------------------------------------
wCollide DWORD l7c, l7o, l7l,
               l7l, l7i, l7d,
               l7e, l7exclamation

scoreFmtStr BYTE "SCORE! %d", 0
scoreStr    BYTE 256 DUP(0)

;-------------------------------------------------------------------------------
;; Scoring Data
;-------------------------------------------------------------------------------
score               DWORD 0
last_score_ticks    DWORD 0
score_tick_interval DWORD 10

;-------------------------------------------------------------------------------
;; Background Music
;-------------------------------------------------------------------------------
music BYTE "music.wav", 0

.CODE
;===============================================================================
;; The game begins
;===============================================================================
; Utility
cls PROC
; Clears the screen (sets all pixels to black)
;===============================================================================
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

;===============================================================================
; Timing
UpdateTime PROC USES eax
; Updates the total_t timer accumulator by adding delta_t
;===============================================================================
  mov eax, total_t
  add eax, delta_t
  mov total_t, eax
  ret
UpdateTime ENDP

;===============================================================================
; Collision Detection
CalculateCollider PROC USES eax edx character:PTR AnimatedCharacter
; Performs calculations to accurately define colliders for AnimatedCharacters
;===============================================================================
  LOCAL left:DWORD, top:DWORD, right:DWORD, bottom:DWORD
  ;; rotation locals
  LOCAL r_sqrt2:FXPT, sina:FXPT, cosa:FXPT, xcomp:FXPT, ycomp:FXPT
  LOCAL x_cos:FXPT, x_sin:FXPT, y_cos:FXPT, y_sin:FXPT, xpcos:FXPT, xpsin:FXPT, ypcos:FXPT, ypsin:FXPT

  mov esi, character

  ASSUME esi:PTR AnimatedCharacter

  invoke UnpackBitmap, [esi].anim.frame_ptr

  invoke EdgesFromCenter, [esi].pos_x, _dwWidth
  mov [esi].collider.dwLeft, eax ; left
  mov [esi].collider.dwRight, edx ; right
  mov left, eax
  mov right, edx

  invoke EdgesFromCenter, [esi].pos_y, _dwHeight
  mov [esi].collider.dwTop, eax  ; top
  mov [esi].collider.dwBottom, edx ; bottom
  mov top, eax
  mov bottom, edx

  ;; pffff rotating the collider, hah, that seemed like a good idea
  mov edx, [esi].rotation
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

  invoke AXP, eax, SQRT2, 0
  mov r_sqrt2, eax

  invoke AXP, r_sqrt2, cosa, 0
  mov xcomp, eax
  invoke AXP, r_sqrt2, sina, 0
  mov ycomp, eax

  mov eax, [esi].pos_x
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

  mov eax, [esi].pos_y
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

  invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwTop, [esi].collider.dwRight, [esi].collider.dwTop, 01ch
  invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwBottom, [esi].collider.dwRight, [esi].collider.dwBottom, 01ch
  invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwTop, [esi].collider.dwLeft, [esi].collider.dwBottom, 01ch
  invoke DrawLine, [esi].collider.dwRight, [esi].collider.dwTop, [esi].collider.dwRight, [esi].collider.dwBottom, 01ch
  ENDIF

  ret
CalculateCollider ENDP

;===============================================================================
; Update Player
UpdatePlayer PROC USES eax
; Update the struct containing the Player's data based on input
;===============================================================================
  .if k_down == 1
    .if Fighter.shader.cm_delta != 0
      mov Fighter.shader.cm_delta, 0
    .else
      mov Fighter.shader.cm_delta, 2
    .endif
    mov Fighter.shader.cm_index, 0
  .endif

  .if m_click == 1 || m_rclick == 1
    mov Fighter.anim.frame_ptr, OFFSET fighter_001
    .if Fighter.rotation > 0 && Fighter.rotation < PI
      add Fighter.pos_x, 10
    .else
      sub Fighter.pos_x, 10
    .endif
  .else
    mov Fighter.anim.frame_ptr, OFFSET fighter_000
  .endif

  .if k_right == 1
    add Fighter.rotation, 02000h
    .if Fighter.rotation > TWO_PI
      sub Fighter.rotation, TWO_PI
    .endif
  .elseif k_left == 1
    .if Fighter.rotation < 02000h
      add Fighter.rotation, TWO_PI
    .endif
    sub Fighter.rotation, 02000h
  .endif

  .if Fighter.pos_x < 22
    mov Fighter.pos_x, 22
  .elseif Fighter.pos_x > 639 - 32
    mov Fighter.pos_x, 639 - 32
  .endif

  ret
UpdatePlayer ENDP

;===============================================================================
; Update that one Asteroid
UpdateAsteroid PROC USES ebx ecx edx
; Update the fancy(er) Asteroid that rotates
;===============================================================================
  mov ebx, Asteroid.rotation
  add ebx, delta_t
  mov Asteroid.rotation, ebx

  ret
UpdateAsteroid ENDP

;===============================================================================
; Drawing to Screen
Draw PROC USES esi ecx edx character:PTR AnimatedCharacter
; Draws an AnimatedCharacter to screen
;===============================================================================
  mov esi, character
  movzx ecx, [esi].shader.colorMask
  movzx edx, [esi].shader.colorShift
  invoke RotateBlit, [esi].anim.frame_ptr, [esi].pos_x, [esi].pos_y, [esi].rotation, ecx, edx
  ret
Draw ENDP

;===============================================================================
; Pause functionality
TogglePause PROC USES eax
; Toggle whether the game is paused based on player input
;===============================================================================
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

;===============================================================================
; Draw Text to Screen
DrawCollideWarning PROC
; Draws 'COLLIDE!' to screen at position 280, 200
;===============================================================================
  invoke DrawWord, OFFSET wCollide, LENGTHOF wCollide, 280, 200, 0c0h
  ret
DrawCollideWarning ENDP

;===============================================================================
; Copy Shader
CopyShader PROC USES eax esi edi destShader:PTR Shader, sourceShader:PTR Shader
; Set an AnimatedCharacter's Shader to a predefined Shader's values
;===============================================================================
  ASSUME esi:PTR Shader
  ASSUME edi:PTR Shader

  mov esi, sourceShader
  mov edi, destShader

  FOR offset, <0, 1, 2, 3, 4, 12, 13, 14, 15>
    mov al, [esi + offset]
    mov BYTE PTR [edi + offset], al
  ENDM

  mov eax, [esi].cm_src
  mov [edi].cm_src, eax

  ret
CopyShader ENDP

;===============================================================================
; Copy Mask and Shift Shaders
CopyShaders PROC USES eax esi edi destShader:PTR Shader, maskShader:PTR Shader, shiftShader:PTR Shader
; Set an Animatedcharacter's Shader to a combination of two predefined Shaders
;===============================================================================
  ASSUME esi:PTR Shader
  ASSUME edi:PTR Shader
  mov edi, destShader

  mov esi, maskShader
  FOR offset, <0, 1, 2, 3, 4>
    mov al, [esi + offset]
    mov BYTE PTR [edi + offset], al
  ENDM

  mov eax, [esi].cm_src
  mov [edi].cm_src, eax

  mov esi, shiftShader
  FOR offset, <12, 13, 14, 15>
    mov al, [esi + offset]
    mov BYTE PTR [edi + offset], al
  ENDM

  ret
CopyShaders ENDP

;===============================================================================
; Shader Calculations
CalculateShaderColorMask PROC USES esi edi eax ecx edx character:PTR AnimatedCharacter
; Calculates the current Shader ColorMask for an AnimatedCharacter
;===============================================================================
  ASSUME esi:PTR AnimatedCharacter
  mov esi, character

  mov edi, [esi].shader.cm_src
  mov ah, [esi].shader.cm_index
  mov al, [esi].shader.cm_delta
  mov dh, [esi].shader.cm_repeat
  mov dl, [esi].shader.cm_src_len

  .if dl == 0
    ; if there are no source values, then skip
    jmp skip_calculation
  .elseif dl == 1
    ; if there's only one source value, skip the repeat logic
    jmp set_opacity
  .endif

  dec dl
  add ah, al
  cmp al, 0
  jg  end_up
  jl  end_down
  jmp set_opacity
  end_up:
    cmp ah, dl
    jl  set_opacity
    .if [esi].shader.cm_repeat == 2
      ; reverse
      neg [esi].shader.cm_delta
    .elseif [esi].shader.cm_repeat == 1
      ; stop
      mov [esi].shader.cm_delta, 0
    .else
      ; wrap back to repeat position
      mov ah, [esi].shader.cm_repeat
    .endif
    jmp set_opacity
  end_down:
    cmp ah, 0
    jne set_opacity
    .if [esi].shader.cm_repeat == 2
      ; reverse
      neg [esi].shader.cm_delta
    .elseif [esi].shader.cm_repeat == 1
      ; stop
      mov [esi].shader.cm_delta, 0
    .else
      ; wrap back to repeat position
      mov ah, [esi].shader.cm_repeat
    .endif
  set_opacity:
    mov [esi].shader.cm_index, ah
    movzx ecx, ah
    movzx ecx, BYTE PTR [edi + ecx]
    mov [esi].shader.colorMask, cl

  skip_calculation:
    ret
CalculateShaderColorMask ENDP

;===============================================================================
; Shader Calculations
CalculateShaderColorShift PROC USES eax ecx edx esi character:PTR AnimatedCharacter
; Calculates the current Shader ColorShift for an AnimatedCharacter
;===============================================================================
  mov esi, character
  mov ah, [esi].shader.colorShift
  mov al, [esi].shader.cs_delta
  mov dh, [esi].shader.cs_repeat
  mov dl, [esi].shader.cs_bound
  add ah, al
  cmp ah, dl
  je  repeat_behaviour
  jmp set_colorshift
  repeat_behaviour:
    .if dh == ShaderRepeatStop
      mov ah, 0
      mov [esi].shader.colorShift, 0
      mov [esi].shader.cs_delta, 0
    .elseif dh == ShaderRepeatReverse
      neg [esi].shader.cs_delta
      sub dl, 36
      neg dl
      mov [esi].shader.cs_bound, dl
    .else
      mov ah, dh
    .endif
  set_colorshift:
    mov [esi].shader.colorShift, ah
  ret
CalculateShaderColorShift ENDP

;===============================================================================
; Game Ticks
UpdateTicks PROC USES eax
; Updates the games 'Ticks' to keep track of frames rendered since start
;===============================================================================
  mov eax, Ticks
  inc eax
  mov Ticks, eax
  ret
UpdateTicks ENDP

;===============================================================================
; Scoring
UpdateScore PROC
; Updates the score and draws it to screen
;===============================================================================
  mov eax, Ticks
  sub eax, last_score_ticks
  .if eax > score_tick_interval
    mov eax, Ticks
    mov last_score_ticks, eax
    inc score
  .endif
  rdtsc
  push score
  push offset scoreFmtStr
  push offset scoreStr
  call wsprintf
  add esp, 12
  invoke DrawStr, OFFSET scoreStr, 300, 400, 0c3h
  ret
UpdateScore ENDP

;===============================================================================
; Library Function
GamePlay PROC USES eax ebx edx
; Called by the game library on every frame
;===============================================================================
  invoke UpdateTime
  invoke UpdateTicks

  .if pause != 0
    jmp skip_frame
  .endif

  invoke cls

  invoke UpdateScore

  invoke UnpackMouse
  invoke UnpackKeyPress

  IFDEF DEBUG

  invoke DebugLetters

  ENDIF

  invoke CalculateShaderColorMask, OFFSET Fighter
  invoke CalculateShaderColorShift, OFFSET Fighter

  invoke CalculateShaderColorMask, OFFSET Asteroid
  invoke CalculateShaderColorShift, OFFSET Asteroid

  CalculateAllAsteroidsShaders

  invoke UpdatePlayer
  invoke Draw, OFFSET Fighter
  invoke CalculateCollider, OFFSET Fighter

  invoke UpdateAsteroid
  invoke Draw, OFFSET Asteroid
  invoke CalculateCollider, OFFSET Asteroid

  DrawAllAsteroids

  invoke CheckIntersectRect, OFFSET Fighter.collider, OFFSET Asteroid.collider
  cmp eax, 1
  jne no_collision

  sub score, 50
  invoke UpdateScore

  no_collision:
  skip_frame:
    ; Check for pause at the end of the frame so that we pause on the most
    ; recently updated screen instead of 1 frame behind
    invoke TogglePause
  	ret
GamePlay ENDP

;===============================================================================
; Library Functions
GameInit PROC
; Called by the game library before the first frame
;===============================================================================
  ;; begin looping background music
  invoke PlaySound, offset music, 0, SND_FILENAME OR SND_ASYNC OR SND_LOOP

  ;; Load Player Shaders
  invoke CopyShaders, OFFSET Fighter.shader, OFFSET FadeInOut, OFFSET Rainbow
  ; disable fade for now
  mov Fighter.shader.cm_delta, 0
  ; also disable rainbow
  mov Fighter.shader.cs_delta, 0

  ; No shaders on Asteroid
  invoke CopyShader, OFFSET Asteroid.shader, OFFSET BaseShader

  ;; Have to initialize the frame_ptr manually, for some reason
  mov Fighter.anim.frame_ptr, OFFSET fighter_000
  mov Asteroid.anim.frame_ptr, OFFSET asteroid_000

  ;; Initialize all our other Asteroids
  InitializeAllAsteroids

	ret
GameInit ENDP

END
