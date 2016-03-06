      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

PLOT PROTO x:DWORD, y:DWORD, color:DWORD

include letters.inc

.DATA

include letters.data

_dim   DWORD ?
_size  DWORD ?
_bytes DWORD ?

.CODE

UnpackLetter PROC USES eax esi l:PTR Letter
  mov esi, [l]
  mov eax, [esi]
  mov _dim, eax
  mul _dim
  mov _size, eax
  mov eax, [esi + 4]
  mov _bytes, eax
  ret
UnpackLetter ENDP

GetLetterXY PROC index:DWORD
  mov eax, index
  xor edx, edx

  eval:
    cmp eax, _dim
    jl  finish
    sub eax, _dim
    inc edx
    jmp eval
  finish:
    ret
GetLetterXY ENDP

DrawLetter PROC USES eax ebx ecx edx esi l:PTR Letter, x:DWORD, y:DWORD, color:DWORD
  invoke UnpackLetter, l

  xor ecx, ecx
  mov esi, _bytes

  eval:
    .if ecx == _size
      jmp end_for
    .endif
  for_body:
    movzx ebx, BYTE PTR [ esi + ecx ]
    invoke GetLetterXY, ecx
    .if ebx != 0ffh
      add eax, x
      add edx, y
      invoke PLOT, eax, edx, color
    .endif
    inc ecx
    jmp eval
  end_for:
    ret
DrawLetter ENDP

DrawWord PROC USES eax ecx edx esi w:PTR DWORD, len:DWORD, x:DWORD, y:DWORD, color:DWORD
  xor ecx, ecx
  mov edx, x
  mov esi, w
  eval:
    cmp ecx, len
    jge finish
    mov eax, [ esi + 4 * ecx ]
    invoke DrawLetter, eax, edx, y, color
    inc ecx
    inc edx ;; pad by 1 pixel
    add edx, _dim
    jmp eval
  finish:
    ret
DrawWord ENDP

END
