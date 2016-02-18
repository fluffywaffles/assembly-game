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

;; import stuff from lines.asm
PLOT PROTO :DWORD, :DWORD, :DWORD

EXTERNDEF SCREEN_X_MIN:DWORD
EXTERNDEF SCREEN_X_MAX:DWORD
EXTERNDEF SCREEN_Y_MIN:DWORD
EXTERNDEF SCREEN_Y_MAX:DWORD

.DATA

  ;; for to unpack bitmap
  _dwWidth      DWORD ?
  _dwHeight     DWORD ?
  _bTransparent BYTE  ?
  _lpBytes      DWORD ?

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
    je  break       ; break
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

HalfComp PROC USES ebx edx comp:FXPT, dim:DWORD
  mov ebx, comp
  sar ebx, 1 ; comp / 2

  invoke int2fxpt, dim
  imul ebx

  mov eax, edx
  ret
HalfComp ENDP

CalcSrcDims PROC USES ebx dstX:DWORD, dstY:DWORD, cosa:FXPT, sina:FXPT
  LOCAL srcX:DWORD, srcY:DWORD

  invoke int2fxpt, dstX
  mov ebx, eax

  mov eax, ebx
  imul cosa
  mov srcX, edx ; srcX = dstX*cosa

  mov eax, ebx
  imul sina
  neg edx
  mov srcY, edx ; srcY = -dstX*sina

  invoke int2fxpt, dstY
  mov ebx, eax

  mov eax, ebx
  imul sina
  add srcX, edx ; srcX = dstX*cosa + dstY*sina

  mov eax, dstY
  imul cosa
  add srcY, edx ; srcY = -dstX*sina + dstY*cosa

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

RotateBlit PROC lpBmp:PTR EECS205BITMAP, xcenter:DWORD, ycenter:DWORD, angle:FXPT
  LOCAL cosa:FXPT, sina:FXPT
  LOCAL shiftX:DWORD, shiftY:DWORD
  LOCAL dstWidth:DWORD, dstHeight:DWORD
  LOCAL dstX:DWORD, dstY:DWORD, srcX:DWORD, srcY:DWORD, drawX:DWORD, drawY:DWORD

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

  invoke HalfComp, cosa, _dwHeight
  mov shiftY, eax
  invoke HalfComp, sina, _dwWidth
  add shiftY, eax

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
        sub ecx, 1
        for_y_eval:
          cmp ecx, dstHeight
          jge break_for_y
        for_y_body:
          invoke CalcSrcDims, dstX, dstY, cosa, sina
          mov dstX, eax
          mov dstY, edx

          inc ecx ; inc here to avoid inf. loop when out of bounds

          invoke Within, srcX, 0, _dwWidth
          cmp eax, 1
          jne for_y_eval

          invoke Within, srcY, 0, _dwHeight
          cmp eax, 1
          jne for_y_eval

          ;invoke CalcDrawCoord, xcenter, dstX, shiftX
          ;mov drawX, eax
          ;invoke CalcDrawCoord, ycenter, dstY, shiftY
          ;mov drawY, eax

          ;invoke Within, drawX, 0, 639
          ;cmp eax, 1
          ;jne for_y_eval

          ;invoke Within, drawY, 0, 479
          ;cmp eax, 1
          ;jne for_y_eval

          ;;; now draw the pixel
          ;invoke PixelIndexAt, drawX, drawY
          ;invoke PlotBitmap, drawX, drawY, eax

          jmp for_y_eval
      break_for_y:

      inc ebx
      jmp for_x_eval
  break_for_x:

  ;; TODO

	ret
RotateBlit ENDP

CheckIntersectRect PROC one:PTR EECS205RECT, two:PTR EECS205RECT

	ret
CheckIntersectRect ENDP

END
