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
; Asteroid Generation, Initialization, Shader Calculation, and Drawing
include asteroid-macros.asm
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; GameMode macros
include gamemode.asm
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
delta_t FXPT 02000h ; AKA 1/16
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
BaseShader Shader { 0, 0, ShaderRepeatStop, 0ffh, 0, $, 0, 0, 0, ShaderRepeatStop, 0 }
;; Shader source array for FadeInOut
opacities BYTE 4 DUP(0ffh), 4 DUP(0dah), 4 DUP(09h), 4 DUP(0)
;; ColorMask shader
FadeInOut Shader { 0, 2, ShaderRepeatReverse, 0ffh, LENGTHOF opacities, OFFSET opacities, ?, ?, ?, ?, ? }
;; ColorShift shader
Rainbow Shader   { ?, ?, ?, ?, ?, ?, 0, 36, 1, ShaderRepeatReverse, 0 }
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Fighter (Player)
;-------------------------------------------------------------------------------
Fighter AnimatedCharacter {\
  <0640000h, 015e0000h, 0>, ; position
  <0, 0, 0>,     ; velocity
  <0, 0, 0>,     ; acceleration
  ,              ; collider
  <0, 3, SIZEOF EECS205BITMAP, OFFSET fighter_000>\ ; animation
}

max_velocity FXPT 0500000h
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
;; Asteroid
;-------------------------------------------------------------------------------
ASTEROID_INITIAL_X = 013f0000h
ASTEROID_INITIAL_Y = 0ef0000h
ASTEROID_INITIAL_VA = 08000h
ASTEROID_INITIAL_AY = 010000h

Asteroid AnimatedCharacter {\
  <013f0000h, 0ef0000h, 0>,  ; position
  <0, 0, 08000h>, ; velocity
  <0, 010000h, 0>, ; acceleration
  ,               ; collider
  <0, 1, SIZEOF EECS205BITMAP, OFFSET asteroid_000>\ ; animation
}
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

wGameOver DWORD l7g, l7a, l7m, l7e, l7, l7o, l7v, l7e, l7r, l7exclamation

scoreFmtStr BYTE "SCORE! %d", 0
scoreStr    BYTE 256 DUP(0)

asteroidFmtStr BYTE "ASTEROIDS REMAINING: %d", 0
asteroidStr    BYTE 256 DUP(0)

;-------------------------------------------------------------------------------
;; Scoring Data
;-------------------------------------------------------------------------------
score               DWORD 0
asteroid_minimum    DWORD 10

;-------------------------------------------------------------------------------
;; Background Music
;-------------------------------------------------------------------------------
music BYTE "music.wav", 0

;-------------------------------------------------------------------------------
;; Game Mode
;-------------------------------------------------------------------------------
;; GameModes
GMSelect = 0
GMBasic  = 1
GMHard   = 2
GMInsane = 3
GMOver   = 4

;; Current Mode
GameMode BYTE GMSelect

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
  LOCAL x:DWORD, y:DWORD
  ;; rotation locals
  LOCAL r_sqrt2:FXPT, sina:FXPT, cosa:FXPT, xcomp:FXPT, ycomp:FXPT
  LOCAL x_cos:FXPT, x_sin:FXPT, y_cos:FXPT, y_sin:FXPT, xpcos:FXPT, xpsin:FXPT, ypcos:FXPT, ypsin:FXPT

  mov esi, character

  ASSUME esi:PTR AnimatedCharacter

  invoke UnpackBitmap, [esi].anim.frame_ptr

  invoke fxpt2int, [esi].position.x
  mov x, eax
  invoke fxpt2int, [esi].position.y
  mov y, eax

  invoke EdgesFromCenter, x, _dwWidth
  mov [esi].collider.dwLeft, eax ; left
  mov [esi].collider.dwRight, edx ; right
  mov left, eax
  mov right, edx

  invoke EdgesFromCenter, y, _dwHeight
  mov [esi].collider.dwTop, eax  ; top
  mov [esi].collider.dwBottom, edx ; bottom
  mov top, eax
  mov bottom, edx

  ;; pffff rotating the collider, hah, that seemed like a good idea
  mov edx, [esi].position.angular
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

  .if bottom < SCREEN_Y_MAX && top > SCREEN_Y_MIN ; this is an interesting bug
    invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwTop, [esi].collider.dwRight, [esi].collider.dwTop, 01ch
    invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwBottom, [esi].collider.dwRight, [esi].collider.dwBottom, 01ch
    invoke DrawLine, [esi].collider.dwLeft, [esi].collider.dwTop, [esi].collider.dwLeft, [esi].collider.dwBottom, 01ch
    invoke DrawLine, [esi].collider.dwRight, [esi].collider.dwTop, [esi].collider.dwRight, [esi].collider.dwBottom, 01ch
  .endif
  ENDIF

  ret
CalculateCollider ENDP

;===============================================================================
; Update Player
UpdatePlayer PROC USES eax
; Update the struct containing the Player's data based on input
;===============================================================================
  .if m_click == 1 || m_rclick == 1
    mov Fighter.anim.frame_ptr, OFFSET fighter_001
    .if Fighter.position.angular > 0 && Fighter.position.angular < PI
      add Fighter.acceleration.x, 050000h
    .else
      sub Fighter.acceleration.x, 050000h
    .endif
  .else
    mov Fighter.anim.frame_ptr, OFFSET fighter_000
    mov Fighter.acceleration.x, 0
  .endif

  .if Fighter.acceleration.x > 010100000h ; 10
    mov Fighter.acceleration.x, 010100000h
  .elseif Fighter.acceleration.x < -1 * 010100000h ; -10
    mov Fighter.acceleration.x, -1 * 010100000h
  .endif

  .if k_right == 1
    add Fighter.position.angular, 02000h
    .if Fighter.position.angular > TWO_PI
      sub Fighter.position.angular, TWO_PI
    .endif
  .elseif k_left == 1
    .if Fighter.position.angular < 02000h
      add Fighter.position.angular, TWO_PI
    .endif
    sub Fighter.position.angular, 02000h
  .endif

  ret
UpdatePlayer ENDP

;===============================================================================
; Update Physics
Update PROC USES eax esi character:PTR AnimatedCharacter
; Update the fancy(er) Asteroid that rotates
;===============================================================================
  ASSUME esi:PTR AnimatedCharacter
  mov esi, character

  invoke AXP, [esi].acceleration.x, delta_t, [esi].velocity.x
  mov [esi].velocity.x, eax

  invoke AXP, [esi].acceleration.y, delta_t, [esi].velocity.y
  mov [esi].velocity.y, eax

  invoke AXP, [esi].velocity.x, delta_t, [esi].position.x
  mov [esi].position.x, eax

  invoke AXP, [esi].velocity.y, delta_t, [esi].position.y
  mov [esi].position.y, eax

  invoke AXP, [esi].velocity.angular, delta_t, [esi].position.angular
  mov [esi].position.angular, eax

  ret
Update ENDP

;===============================================================================
; Drawing to Screen
Draw PROC USES esi ebx ecx edx character:PTR AnimatedCharacter
; Draws an AnimatedCharacter to screen
;===============================================================================
  mov esi, character
  movzx ecx, [esi].shader.colorMask
  movzx edx, [esi].shader.colorShift
  invoke fxpt2int, [esi].position.y
  mov ebx, eax
  invoke fxpt2int, [esi].position.x
  ; eax = fxpt2int position.x
  invoke RotateBlit, [esi].anim.frame_ptr, eax, ebx, [esi].position.angular, ecx, edx
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
  mov bh, [esi].shader.cs_repeat
  mov dh, [esi].shader.cs_bound_hi
  mov dl, [esi].shader.cs_bound_lo
  add ah, al

  .if ah < dh && ah > dl
    ; inside bounds
    jmp set_colorshift
  .endif

  repeat_behaviour:
    .if bh == ShaderRepeatStop
      mov ah, 0 ; reset
      mov [esi].shader.cs_delta, 0 ; stop
    .elseif bh == ShaderRepeatReverse
      neg [esi].shader.cs_delta ; reverse
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
  add score, 2
  rdtsc
  push score
  push offset scoreFmtStr
  push offset scoreStr
  call wsprintf
  add esp, 12
  invoke DrawStr, OFFSET scoreStr, 260, 400, 0c3h
  ret
UpdateScore ENDP

;===============================================================================
; Remaining Asteroids
DrawAsteroidRemainingCount PROC USES ecx count:DWORD
; Draws the number of asteroids still remaining to be dodged
;===============================================================================
  rdtsc
  push count
  push offset asteroidFmtStr
  push offset asteroidStr
  call wsprintf
  add esp, 12
  invoke DrawStr, OFFSET asteroidStr, 20, 400, 01ch
  ret
DrawAsteroidRemainingCount ENDP

Randomize PROC USES eax character:PTR AnimatedCharacter
  mov esi, character

  invoke nrandom, SCREEN_X_MAX
  invoke int2fxpt, eax
  mov [esi].position.x, eax

  invoke nrandom, 50
  add eax, 100
  invoke int2fxpt, eax
  mov [esi].position.y, eax

  invoke nrandom, TWO_PI
  mov [esi].position.angular, eax

  invoke nrandom, 01000h
  mov [esi].velocity.angular, eax

  invoke nrandom, 010000h
  sub eax, 08000h
  mov [esi].acceleration.x, eax

  invoke nrandom, 010000h
  sub eax, 08000h
  mov [esi].acceleration.y, eax

  ;invoke nrandom, 040000h
  ;sub eax, 020000h
  mov [esi].velocity.x, 0

  ;invoke nrandom, 040000h
  ;sub eax, 020000h
  mov [esi].velocity.y, 0

  invoke nrandom, 2
  .if eax == 0
    neg [esi].velocity.angular
  .endif

  ret
Randomize ENDP

;===============================================================================
; Game State
Setup PROC
; Sets up the game state to be played in GameMode mode
;===============================================================================
  mov Asteroid.position.x, ASTEROID_INITIAL_X
  mov Asteroid.position.y, ASTEROID_INITIAL_Y
  mov Asteroid.velocity.angular, ASTEROID_INITIAL_VA
  mov Asteroid.velocity.y, 0
  mov Asteroid.acceleration.y, ASTEROID_INITIAL_AY
  invoke CopyShader, OFFSET Asteroid.shader, OFFSET BaseShader

  mov Fighter.shader.cs_delta, 0

  InitializeAllAsteroids

  .if GameMode == GMBasic
    mov asteroid_minimum, 15
    mov delta_t, 01555h
    %FOR aid, AsteroidList2
      IF aid GT 95
        mov Asteroid&aid.acceleration.x, 0
        mov Asteroid&aid.acceleration.y, 0
      ENDIF
    ENDM
  .else
    mov asteroid_minimum, 10
    mov delta_t, 02000h
  .endif

  .if GameMode == GMInsane
    invoke CopyShaders, OFFSET Asteroid.shader, OFFSET FadeInOut, OFFSET Rainbow
    AllAsteroidsCopyShaders FadeInOut, Rainbow
    mov al, Rainbow.cs_delta
    mov Fighter.shader.cs_delta, al
  .endif
  ret
Setup ENDP

;===============================================================================
; Game State
GameOver PROC
; Called when the game ends, returns you to the selection screen
;===============================================================================
  X = 280
  Y = 200

  FOR off, <0, 1, 2, 3>
    invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X + off, Y + 8 + off, 03h
  ENDM

  FOR off, <3, 2, 1, 0>
    invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X + off, Y + 4 + off, 0c0h
  ENDM

  FOR off, <0, 1, 2, 3>
    invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X + off, Y + off, 01ch
  ENDM

  invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X - 1, Y - 3, 0ffh
  invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X, Y - 2, 0h
  invoke DrawWord, OFFSET wGameOver, LENGTHOF wGameOver, X + 1, Y - 2, 0h

  x = 230
  y = 300
  xi = 0
  FORC lttr, <press space to restart>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + 8*xi, y, 0ffh
    xi = xi + 1
  ENDM

  ret
GameOver ENDP

;===============================================================================
; Library Function
GamePlay PROC USES eax ebx edx
; Called by the game library on every frame
;===============================================================================
  invoke UpdateTime
  invoke UpdateTicks

  invoke UnpackMouse
  invoke UnpackKeyPress

  .if GameMode == GMOver
    .if k_space == 1
      mov GameMode, GMSelect
    .endif
    jmp skip_frame
  .endif

  .if pause
    jmp skip_frame
  .endif

  invoke cls

  IFDEF DEBUG
    invoke UnpackMouse
    invoke UnpackKeyPress
  ENDIF

  .if GameMode == GMSelect
    DrawSelectionScreen 150, 65, 0ffh
    .if k_one == 1
      mov GameMode, GMBasic
    .elseif k_two == 1
      mov GameMode, GMHard
    .elseif k_three == 1
      mov GameMode, GMInsane
    .endif
    invoke Setup
    jmp skip_frame
  .endif

  invoke UpdateScore

  IFDEF DEBUG

  invoke DebugLetters

  ENDIF

  invoke CalculateShaderColorMask, OFFSET Fighter
  invoke CalculateShaderColorShift, OFFSET Fighter

  invoke CalculateShaderColorMask, OFFSET Asteroid
  invoke CalculateShaderColorShift, OFFSET Asteroid

  CalculateAllAsteroidsShaders

  invoke UpdatePlayer
  invoke Update, OFFSET Fighter

  mov eax, max_velocity
  mov ebx, eax
  neg ebx
  .if Fighter.velocity.x > eax
    mov Fighter.velocity.x, eax
  .elseif Fighter.velocity.x < ebx
    mov Fighter.velocity.x, ebx
  .endif

  invoke int2fxpt, 639 - 42
  mov ebx, eax
  invoke int2fxpt, 32

  .if Fighter.position.x < eax
    mov Fighter.position.x, eax
    mov Fighter.velocity.x, 0
    mov Fighter.acceleration.x, 0
  .elseif Fighter.position.x > ebx
    mov Fighter.position.x, ebx
    mov Fighter.velocity.x, 0
    mov Fighter.acceleration.x, 0
  .endif

  invoke Draw, OFFSET Fighter
  invoke CalculateCollider, OFFSET Fighter

  invoke Update, OFFSET Asteroid
  invoke Draw, OFFSET Asteroid
  invoke CalculateCollider, OFFSET Asteroid

  UpdateAllAsteroids
  DrawAllAsteroids
  CalculateAllAsteroidsColliders

  invoke CheckIntersectRect, OFFSET Fighter.collider, OFFSET Asteroid.collider

  mov ebx, eax

  CheckIntersectAllAsteroids

  cmp ebx, 1
  jne after_collision
  sub score, 20

  after_collision:

  invoke UpdateScore

  CountAllAsteroidsVisible

  .if Asteroid.position.x < SCREEN_X_MAX && Asteroid.position.x > SCREEN_X_MIN
    .if Asteroid.position.y < SCREEN_Y_MAX && Asteroid.position.y > SCREEN_Y_MIN
      inc ecx
    .endif
  .endif

  invoke DrawAsteroidRemainingCount, ecx

  .if ecx <= asteroid_minimum
    invoke GameOver
    mov GameMode, GMOver
  .endif

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

  ;; seed RNG
  rdtsc
  invoke nseed, eax

  ;; Load Player Shaders
  invoke CopyShaders, OFFSET Fighter.shader, OFFSET FadeInOut, OFFSET Rainbow
  ; disable fade for now
  mov Fighter.shader.cm_delta, 0
  ; also disable rainbow
  mov Fighter.shader.cs_delta, 0

  ; No shaders on Asteroid
  invoke CopyShader, OFFSET Asteroid.shader, OFFSET BaseShader

  ;; Initialize all our other Asteroids
  InitializeAllAsteroids

	ret
GameInit ENDP

END
