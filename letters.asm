      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

PLOT PROTO x:DWORD, y:DWORD, color:DWORD

include common.inc
include letters.inc

.DATA

include letters.data

l3alpha DWORD l3a, l3b, l3c, l3d, l3e, l3f, l3g, l3h, l3i, l3j, l3k, l3l, l3m,
              l3n, l3o, l3p, l3q, l3r, l3s, l3t, l3u, l3v, l3w, l3x, l3y, l3z,
              l3exclamation

l5alpha DWORD l5a, l5b, l5c, l5d, l5e, l5f, l5g, l5h, l5i, l5j, l5k, l5l, l5m,
              l5n, l5o, l5p, l5q, l5r, l5s, l5t, l5u, l5v, l5w, l5x, l5y, l5z,
              l5exclamation

l7alpha DWORD l7a, l7b, l7c, l7d, l7e, l7f, l7g, l7h, l7i, l7j, l7k, l7l, l7m,
              l7n, l7o, l7p, l7q, l7r, l7s, l7t, l7u, l7v, l7w, l7x, l7y, l7z,
              l7exclamation, l70, l71, l72, l73, l74, l75, l76, l77, l78, l79

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

DebugLetters PROC
  invoke DrawWord, OFFSET l7alpha, LENGTHOF l7alpha, 10, 420, 0c3h
  invoke DrawWord, OFFSET l5alpha, LENGTHOF l5alpha, 10, 430, 0c3h
  invoke DrawWord, OFFSET l3alpha, LENGTHOF l3alpha, 10, 438, 0c3h
  ret
DebugLetters ENDP

END
