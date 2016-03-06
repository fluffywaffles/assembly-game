; #########################################################################
;
;   blit.asm - Assembly file for EECS205 Assignment 3
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

;; import stuff from lines.asm
PLOT PROTO :DWORD, :DWORD, :DWORD
Abs PROTO :DWORD

PUBLIC EdgesFromCenter
PUBLIC _dwWidth
PUBLIC _dwHeight

.DATA

  ;; for to unpack bitmap
  _dwWidth      DWORD ?
  _dwHeight     DWORD ?
  _bTransparent BYTE  ?
  _lpBytes      DWORD ?

  ;; for to unpack rect
  _rl DWORD ?
  _rt DWORD ?
  _rr DWORD ?
  _rb DWORD ?

.CODE

UnpackBitmap PROC USES eax esi bmpPtr:PTR EECS205BITMAP
  mov esi, bmpPtr

  mov eax, [esi]
  mov _dwWidth, eax

  mov eax, [esi + 4]
  mov _dwHeight, eax

  mov al, BYTE PTR [esi + 8]
  mov _bTransparent, al

  mov eax, [esi + 12]
  mov _lpBytes, eax

  ret
UnpackBitmap ENDP

EdgesFromCenter PROC USES ebx centerpoint:DWORD, len:DWORD
  mov eax, centerpoint
  mov edx, eax

  mov ebx, len
  shr ebx, 1   ; len/2

  sub eax, ebx ; start - len/2
  add edx, ebx ; start + len/2

  mov ebx, len
  test ebx, 1
  jz finish
  inc edx

  finish:
    ret
EdgesFromCenter ENDP

BitmapSize PROC USES edx
  mov  eax, _dwWidth
  imul _dwHeight
  ret ; trunc
BitmapSize ENDP

PlotBitmap PROC USES eax esi x:DWORD, y:DWORD, index:DWORD
  mov esi, _lpBytes ; bitmap ptr
  add esi, index    ; current pixel
  mov al, BYTE PTR [esi] ; color at index
  cmp al, _bTransparent  ; check if transparent
  je  skip_plot          ; don't plot if transparent
  invoke PLOT, x, y, eax
  skip_plot:
    ret
PlotBitmap ENDP

BasicBlit PROC USES eax ebx ecx edx ptrBitmap:PTR EECS205BITMAP, xcenter:DWORD, ycenter:DWORD
  LOCAL startX:DWORD, endX:DWORD, startY:DWORD, bpsize:DWORD

  invoke UnpackBitmap, ptrBitmap

  invoke EdgesFromCenter, xcenter, _dwWidth
  mov startX, eax
  mov endX, edx

  invoke EdgesFromCenter, ycenter, _dwHeight
  mov startY, eax

  invoke BitmapSize
  mov bpsize, eax

  mov ebx, startY ; y = startY
  mov ecx, 0 ; bitmap index = 0

  inf:
    for_loop:
      mov eax, startX ; x = startX
      eval:
        cmp eax, endX ; if x >= endX
        jge exit_for_loop
      body:
        invoke PlotBitmap, eax, ebx, ecx ; x, y, bitmap index offset
        inc eax ; x++
        inc ecx ; bitmap index ++
        jmp eval
    exit_for_loop:

    inc ebx         ; y++
    cmp ecx, bpsize ; if index == size then
    jge break       ; break
    jmp inf

  break:
  	ret
BasicBlit ENDP

int2fxpt PROC num:DWORD
  mov eax, num
  shl eax, 16
  ret
int2fxpt ENDP

fxpt2int PROC num:FXPT
  mov eax, num
  sar eax, 16
  ret
fxpt2int ENDP

FixedMultiply PROC USES edx a:FXPT, b:FXPT
  mov eax, a
  imul b       ; { edx, eax } <- a * b
  shl edx, 16  ; truncate int
  shr eax, 16  ; truncate frac
  or  eax, edx ; combine
  ret
FixedMultiply ENDP

HalfComp PROC USES ebx comp:FXPT, dim:DWORD
  invoke int2fxpt, dim ; convert dim to fixedpoint
  mov ebx, eax
  mov eax, comp
  sar eax, 1 ; divide by 2
  invoke FixedMultiply, eax, ebx ; comp * dim
  ret
HalfComp ENDP

CalcSrcDims PROC USES ebx dstX:DWORD, dstY:DWORD, cosa:FXPT, sina:FXPT
  LOCAL srcX:FXPT, srcY:FXPT

  invoke int2fxpt, dstX
  mov ebx, eax

  invoke FixedMultiply, ebx, cosa
  mov srcX, eax ; srcX = dstX*cosa

  invoke FixedMultiply, ebx, sina
  neg eax
  mov srcY, eax ; srcY = -dstX*sina

  invoke int2fxpt, dstY
  mov ebx, eax

  invoke FixedMultiply, ebx, sina
  add srcX, eax ; srcX = dstX*cosa + dstY*sina

  invoke FixedMultiply, ebx, cosa
  add srcY, eax ; srcY = -dstX*sina + dstY*cosa

  invoke fxpt2int, srcY
  mov edx, eax          ; edx = int(srcY)
  invoke fxpt2int, srcX ; eax = int(srcX)

  ret
CalcSrcDims ENDP

Within PROC USES esi centerpoint:DWORD, lbound:DWORD, hbound:DWORD
  mov eax, 0
  mov esi, centerpoint

  cmp esi, lbound
  jl  false

  cmp esi, hbound
  jge false

  inc eax
  false:
    ret
Within ENDP

CalcDrawCoord PROC centerpoint:DWORD, destpoint:DWORD, shift:DWORD
  mov eax, centerpoint
  add eax, destpoint
  sub eax, shift
  ret
CalcDrawCoord ENDP

PixelIndexAt PROC x:DWORD, y:DWORD
  mov eax, y
  mul _dwWidth
  add eax, x
  ret ; pixel index = y * dwWidth + x
PixelIndexAt ENDP

RotateBlit PROC lpBmp:PTR EECS205BITMAP, xcenter:DWORD, ycenter:DWORD, angle:FXPT
  LOCAL cosa:FXPT, sina:FXPT
  LOCAL shiftX:FXPT, shiftY:FXPT
  LOCAL dstWidth:DWORD, dstHeight:DWORD
  LOCAL srcX:DWORD, srcY:DWORD, drawX:DWORD, drawY:DWORD

  cmp angle, 0
  jne continue

  invoke BasicBlit, lpBmp, xcenter, ycenter
  ret

  continue:

  ; Unpack bitmap
  ;---------------------------------------
  invoke UnpackBitmap, lpBmp

  ; Calculate sin, cos
  ;---------------------------------------
  invoke FixedSin, angle
  mov sina, eax

  invoke FixedCos, angle
  mov cosa, eax

  ; Calculate shifts
  ;---------------------------------------
  invoke HalfComp, cosa, _dwWidth
  mov shiftX, eax
  invoke HalfComp, sina, _dwHeight
  sub shiftX, eax
  invoke fxpt2int, shiftX
  mov shiftX, eax

  invoke HalfComp, cosa, _dwHeight
  mov shiftY, eax
  invoke HalfComp, sina, _dwWidth
  add shiftY, eax
  invoke fxpt2int, shiftY
  mov shiftY, eax

  ; Calculate destination width and height
  ;---------------------------------------
  mov eax, _dwWidth
  add eax, _dwHeight
  mov dstWidth, eax
  mov dstHeight, eax

  ; Begin draw loop
  ;---------------------------------------
  mov ebx, dstWidth
  neg ebx

  for_x:
    for_x_eval:
      cmp ebx, dstWidth
      jge break_for_x
    for_x_body:

      for_y:
        mov ecx, dstHeight
        neg ecx
        dec ecx
        for_y_eval:
          cmp ecx, dstHeight
          jge break_for_y
        for_y_body:
          inc ecx ; inc here to avoid inf. loop when out of bounds

          invoke CalcSrcDims, ebx, ecx, cosa, sina
          mov srcX, eax
          mov srcY, edx

          invoke Within, srcX, 0, _dwWidth
          cmp eax, 1
          jne for_y_eval

          invoke Within, srcY, 0, _dwHeight
          cmp eax, 1
          jne for_y_eval

          invoke CalcDrawCoord, xcenter, ebx, shiftX
          mov drawX, eax
          invoke CalcDrawCoord, ycenter, ecx, shiftY
          mov drawY, eax

          invoke Within, drawX, 0, 639
          cmp eax, 1
          jne for_y_eval

          IFDEF DEBUG
          invoke PLOT, drawX, 15, 0c0h
          ENDIF

          invoke Within, drawY, 0, 479
          cmp eax, 1
          jne for_y_eval

          IFDEF DEBUG
          invoke PLOT, 15, drawY, 0c0h
          ENDIF

          ;;; now draw the pixel
          invoke PixelIndexAt, srcX, srcY
          invoke PlotBitmap, drawX, drawY, eax

          jmp for_y_eval
      break_for_y:

      inc ebx
      jmp for_x_eval
  break_for_x:

	ret
RotateBlit ENDP

AbsDistance PROC a:DWORD, b:DWORD
  mov eax, b
  sub eax, a
  invoke Abs, eax
  ret
AbsDistance ENDP

UnpackRect PROC USES esi r:PTR EECS205RECT
  mov esi, r

  mov eax, [esi]
  mov _rl, eax

  mov eax, [esi + 4]
  mov _rt, eax

  mov eax, [esi + 8]
  mov _rr, eax

  mov eax, [esi + 12]
  mov _rb, eax

  invoke AbsDistance, _rt, _rb
  mov edx, eax
  invoke AbsDistance, _rr, _rl
  ret
UnpackRect ENDP

CheckIntersectRect PROC USES ebx ecx one:PTR EECS205RECT, two:PTR EECS205RECT
  LOCAL lone:DWORD, tone:DWORD, rone:DWORD, bone:DWORD
  LOCAL width1:DWORD, width2:DWORD, height1:DWORD, height2:DWORD
  LOCAL totalw:DWORD, totalh:DWORD

  invoke UnpackRect, one

  mov width1, eax
  mov height1, edx

  mov eax, _rl
  mov lone, eax
  mov eax, _rt
  mov tone, eax
  mov eax, _rr
  mov rone, eax
  mov eax, _rb
  mov bone, eax

  invoke UnpackRect, two
  mov width2, eax
  mov height2, edx

  mov eax, width1
  add eax, width2
  mov totalw, eax

  mov eax, height1
  add eax, height2
  mov totalh, eax

  invoke AbsDistance, _rl, lone
  mov ebx, eax
  invoke AbsDistance, _rr, rone
  add ebx, eax

  invoke AbsDistance, _rb, bone
  mov ecx, eax
  invoke AbsDistance, _rt, tone
  add ecx, eax

  xor eax, eax

  cmp ebx, totalw
  jg  no_hit

  cmp ecx, totalh
  jg  no_hit

  inc eax

  no_hit:
  	ret
CheckIntersectRect ENDP

END
