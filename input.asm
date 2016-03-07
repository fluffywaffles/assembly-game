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

.DATA

;; Mouse data
m_x DWORD ?
m_y DWORD ?
m_click BYTE ?
m_rclick BYTE ?

;; Keyboard data
k_space BYTE ?
k_p     BYTE ?
k_enter BYTE ?
k_up    BYTE ?
k_left  BYTE ?
k_right BYTE ?
k_down  BYTE ?

.CODE

GetZF PROC
  lahf
  shl eax, 17  ; cut off SF
  shr eax, 31 ; trunc to just zf
  ret
GetZF ENDP

UnpackMouse PROC USES eax ebx esi
  mov esi, OFFSET MouseStatus

  mov eax, [esi]     ; mx
  mov m_x, eax

  mov eax, [esi + 4] ; my
  mov m_y, eax

  mov ebx, [esi + 8] ; buttons

  cmp ebx, MK_LBUTTON
  invoke GetZF
  mov m_click, al

  cmp ebx, MK_RBUTTON
  invoke GetZF
  mov m_rclick, al

  IFDEF DEBUG

  invoke PLOT, m_x, m_y, 01ch

  .if m_click
    invoke PLOT, 10, 16, 01ch
  .else
    invoke PLOT, 10, 16, 0c0h
  .endif

  .if m_rclick
    invoke PLOT, 12, 16, 01ch
  .else
    invoke PLOT, 12, 16, 0c0h
  .endif

  ENDIF

  ret
UnpackMouse ENDP

UnpackKeyPress PROC USES eax ebx
  mov ebx, KeyPress

  cmp ebx, VK_SPACE
  invoke GetZF
  mov k_space, al

  cmp ebx, VK_P
  invoke GetZF
  mov k_p, al

  cmp ebx, VK_UP
  invoke GetZF
  mov k_up, al

  cmp ebx, VK_W
  invoke GetZF
  or  k_up, al

  cmp ebx, VK_LEFT
  invoke GetZF
  mov k_left, al

  cmp ebx, VK_A
  invoke GetZF
  or  k_left, al

  cmp ebx, VK_RIGHT
  invoke GetZF
  mov k_right, al

  cmp ebx, VK_D
  invoke GetZF
  or  k_right, al

  cmp ebx, VK_DOWN
  invoke GetZF
  mov k_down, al

  cmp ebx, VK_S
  invoke GetZF
  or  k_down, al

  IFDEF DEBUG

  .if k_space
    invoke PLOT, 10, 22, 01ch
  .else
    invoke PLOT, 10, 22, 0c0h
  .endif

  .if k_p
    invoke PLOT, 10, 20, 01ch
  .else
    invoke PLOT, 10, 20, 0c0h
  .endif

  .if k_up
    invoke PLOT, 12, 10, 01ch
  .else
    invoke PLOT, 12, 10, 0c0h
  .endif

  .if k_left
    invoke PLOT, 10, 12, 01ch
  .else
    invoke PLOT, 10, 12, 0c0h
  .endif

  .if k_right
    invoke PLOT, 14, 12, 01ch
  .else
    invoke PLOT, 14, 12, 0c0h
  .endif

  .if k_down
    invoke PLOT, 12, 12, 01ch
  .else
    invoke PLOT, 12, 12, 0c0h
  .endif

  ENDIF

  ret
UnpackKeyPress ENDP

END
