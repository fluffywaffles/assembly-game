; #########################################################################
;
;   lines.asm - Assembly file for EECS205 Assignment 2
;
;
; #########################################################################

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include stars.inc
include lines.inc

PUBLIC SCREEN_X_MIN
PUBLIC SCREEN_X_MAX
PUBLIC SCREEN_Y_MIN
PUBLIC SCREEN_Y_MAX

.DATA
;;  These are some useful constants (fixed point values that correspond to important angles)
PI_HALF = 102943           	    ;;  PI / 2
PI =  205887	                  ;;  PI
TWO_PI	= 411774                ;;  2 * PI
PI_INC_RECIP =  5340353        	;;  256 / PI

;; don't fall off... 0b10
NEG_CHK BYTE 2h

SCREEN_X_MIN = 0
SCREEN_X_MAX = 640
SCREEN_Y_MIN = 0
SCREEN_Y_MAX = 480

_x0 DWORD ?
_x1 DWORD ?

_y0 DWORD ?
_y1 DWORD ?

_dy DWORD ?
_dx DWORD ?
_ady DWORD ?
_adx DWORD ?
_slope FXPT ?

swap_plotxy BYTE 0
i DWORD ?
i_end DWORD ?
fixed_j DWORD ?

.CODE

ToggleNeg PROC angle:FXPT
  mov eax, angle
  cmp angle, 0
  jge finish
  neg eax
  finish:
    ret
ToggleNeg ENDP

SintabIndex PROC USES edx angle:FXPT
  invoke ToggleNeg, angle
  mov  edx, PI_INC_RECIP
  imul edx
  mov  eax, edx
  ret
SintabIndex ENDP

ReduceAngle PROC USES ebx ecx angle:FXPT
  mov eax, angle
  mov ebx, 0 ; should neg? initially: no

  ; Start reducing the angle by 2PI, then by PI, and then clamp to [0, PI/2)
  ifCanReduce2Pi:
    cmp eax, TWO_PI
    jl  ifCanReducePi
  reduce2Pi:
    sub eax, TWO_PI
    jmp ifCanReduce2Pi
  ifCanReducePi:
    cmp eax, PI
    jl  clamp
  reducePi:
    not ebx
    sub eax, PI
    jmp ifCanReducePi
  clamp:
    cmp eax, PI_HALF
    jl  finish
    ; PI - eax
    sub eax, PI
    neg eax    ; trust me
  finish:
    cmp ebx, 0 ; unless shouldNeg, return
    je  r
    flip:
      neg eax  ; else neg
    r:
      ret
ReduceAngle ENDP

FixedSin PROC USES ebx esi angle:FXPT
  invoke ReduceAngle, angle
  mov angle, eax

  invoke SintabIndex, angle
  mov ebx, eax ; ebx = index of angle in SINTAB

  mov esi, OFFSET SINTAB ; src = ptr to start of SINTAB

  mov ax, WORD PTR [ esi + 2 * ebx ] ; value at SINTAB[index]

  ; seriously trust me: the sign tells all
  cmp angle, 0
  jge finish

  neg eax ; sometimes you just flip your shit

  finish:
    ret
FixedSin ENDP

FixedCos PROC USES ebx angle:FXPT
  ; nbd just use sine
  mov ebx, angle
  add ebx, PI_HALF
  invoke FixedSin, ebx
	ret
FixedCos ENDP

CheckBounds PROC x0:DWORD, y0:DWORD, x1:DWORD, y1:DWORD
  cmp x0, SCREEN_X_MAX
  jge fail
  cmp x0, SCREEN_X_MIN
  jl  fail

  cmp x1, SCREEN_X_MAX
  jge fail
  cmp x1, SCREEN_X_MIN
  jl  fail

  cmp y0, SCREEN_Y_MAX
  jge fail
  cmp y0, SCREEN_Y_MIN
  jl  fail

  cmp y1, SCREEN_Y_MAX
  jge fail
  cmp y1, SCREEN_Y_MIN
  jl  fail

  ; if all checks pass, succeed
  mov eax, 1
  ret

  fail:
    mov eax, 0
    ret
CheckBounds ENDP

Distance PROC a:DWORD, b:DWORD
  ; basically sub
  mov eax, a
  sub eax, b
  ret
Distance ENDP

Abs PROC a:DWORD
  ; neg if negative else do nothing
  mov eax, a
  cmp eax, 0
  jge finish
  ; is there a reason to use neg instead of not?
  neg eax
  finish:
    ret
Abs ENDP

ScreenBitsIndex PROC USES edx x:DWORD, y:DWORD
  ; accumulator
  mov eax, 0
  ; # rows to skip
  mov edx, y

  while_loop:
    cmp edx, 0
    jl  after
    add eax, SCREEN_X_MAX
    sub edx, 1
    jmp while_loop
  after:
    add eax, x
    ret
ScreenBitsIndex ENDP

PLOT PROC USES eax esi ecx x:DWORD, y:DWORD, color:DWORD
  invoke ScreenBitsIndex, x, y

  mov esi, ScreenBitsPtr
  mov ecx, color

  ; move color byte into screen index eax
  mov BYTE PTR [ esi + eax ], cl
  ret
PLOT ENDP

FXPTDivide PROC USES ecx edx a:FXPT, b:FXPT
  ; so we gotta preserve 10 bits to make 640
  ; which means we can shift 6
  ; see:
  ; (16.16)<<6 / (16.16)>>6 = (32.0)<<12 = 20.12 (= (16.16)>>4, or 4 off center)
  ; 20.12<<4 = 16.16 (bring fixed point back to center)
  ; in terms of a and b:
  ; (a<<6) / (b>>6) = ((ans)>>4)
  ; ans = ((a<<6) / (b>>6))<<4
  mov  eax, a
  shl  eax, 6 ; a << 6
  mov  ecx, b
  ; this needs to be sar
  sar  ecx, 6 ; b >> 6
  ; don't forget to convert-double-quad
  cdq         ; sign extend into edx
  ; must use `idiv` because signed
  idiv ecx    ; eax <- ((a<<6) / (b>>6))
  shl  eax, 4 ; eax <- ((a<<6) / (b>>6)) << 4 = ans
  ; literally all of my errors were sign things
  ; also cdq
  ; at first i was like, 'dafuq is cdq'
  ; cdq is my new best friend
  ret
FXPTDivide ENDP

DrawLine PROC USES ebx ecx x0:DWORD, y0:DWORD, x1:DWORD, y1:DWORD, color:DWORD
  invoke CheckBounds, x0, y0, x1, y1
  ; fail fast if out of bounds
  cmp eax, 0
  jne main
  mov eax, -1
  ret

  ; this code could be improved / modularized but... eh
  main:
    ; gotta know how far to go
    distances:
      invoke Distance, x1, x0
      mov _dx, eax
      invoke Abs, eax
      mov _adx, eax
      invoke Distance, y1, y0
      mov _dy, eax
      invoke Abs, eax
      mov _ady, eax

    ; gotta know which way is up
    if_abs_dy_dx:
      mov eax, _ady
      mov ebx, _adx
      cmp eax, ebx
      ; dy is up
      jl  then_abs_dy_dx
      ; dx is up
      jmp else_abs_dy_dx

    then_abs_dy_dx:
      ; fixed_inc
      mov eax, _dy
      mov ebx, _dx
      shl eax, 16
      shl ebx, 16
      invoke FXPTDivide, eax, ebx
      mov _slope, eax ; dy / dx

      if_x0_g_x1:
        mov eax, x0
        mov ebx, x1
        cmp eax, ebx
        jg then_x0_g_x1

        ; else
        mov ecx, y0
        ; int2fxpt
        shl ecx, 16
        mov fixed_j, ecx
        mov i, eax
        mov i_end, ebx
        jmp for_if

      then_x0_g_x1:
        mov ecx, y1
        ; int2fxpt
        shl ecx, 16
        mov fixed_j, ecx
        mov i, ebx
        mov i_end, eax

      for_if:
        mov ebx, i
        mov ecx, fixed_j
        for_if_eval:
          cmp ebx, i_end
          jg  end_main
        for_if_loop:
          mov edx, ecx
          shr edx, 16  ; fxpt2int
          invoke PLOT, ebx, edx, color ; wooo plotting
          inc ebx
          add ecx, _slope
          jmp for_if_eval

    else_abs_dy_dx:
      ; if y1 == y0
      mov eax, y0
      mov ebx, y1
      cmp eax, ebx
      ; end
      ; let's try to not divide by 0 pls
      je  end_main

      ; if y1 != y0
      ; fixed_inc
      mov eax, _dx
      mov ebx, _dy
      shl eax, 16
      shl ebx, 16
      invoke FXPTDivide, eax, ebx
      mov _slope, eax ; dx / dy

      if_y0_g_y1:
        mov eax, y0
        mov ebx, y1
        cmp eax, ebx
        jg  then_y0_g_y1

        ; else
        mov ecx, x0
        ; int2fxpt
        shl ecx, 16
        mov fixed_j, ecx
        mov i, eax
        mov i_end, ebx
        jmp for_else

      then_y0_g_y1:
        mov ecx, x1
        ; int2fxpt
        shl ecx, 16
        mov fixed_j, ecx
        mov i, ebx
        mov i_end, eax

      for_else:
        mov ebx, i
        mov ecx, fixed_j
        for_else_eval:
          cmp ebx, i_end
          jg  end_main
        for_else_loop:
          mov edx, ecx
          shr edx, 16  ; fxpt2int
          invoke PLOT, edx, ebx, color
          inc ebx
          add ecx, _slope
          jmp for_else_eval

  end_main:
    mov eax, 0
    ret
DrawLine ENDP


; this was a performance brought to you by our sponsors:
;      The Intel 8086 Architecture, Headliner
;      The Microsoft Assembler (ml.exe), Crowd Favorite
;      Russ Joseph, Honorable Mention
; with special thanks to the
;      uplifting friendship of
;      Grace Alexander
;      who should get an 'A' in this class because I make fun of her a bunch
; you're welcome
; better late than never
; - Jordan


END
