; #########################################################################
;
;   stars.asm - Assembly file for EECS205 Assignment 1
;
;   "clearly identify your name in the comments"
;   Jordan Timmerman
;   Also the kid who sent the really long email with all the pictures
;     (just in case Russ Joseph actually reads this)
;
; #########################################################################

.586
.MODEL FLAT,STDCALL
.STACK 4096
option casemap :none  ; case sensitive


include stars.inc

.DATA

	;; If you need to, you can place global variables here

.CODE

DrawStarField proc

  ;; Draw 16 stars... ok
  ;; let's draw in from the corners
  invoke DrawStar,  10,  10
  invoke DrawStar, 630, 470
  invoke DrawStar, 630,  10
  invoke DrawStar,  10, 470
  invoke DrawStar,  60,  60
  invoke DrawStar, 580, 420
  invoke DrawStar,  60, 420
  invoke DrawStar, 580,  60
  invoke DrawStar, 110, 110
  invoke DrawStar, 530, 370
  invoke DrawStar, 530, 110
  invoke DrawStar, 110, 370
  invoke DrawStar, 160, 160
  invoke DrawStar, 480, 320
  invoke DrawStar, 160, 320
  invoke DrawStar, 480, 160
  ;; 16 stars drawn

	ret  			; Careful! Don't remove this line
DrawStarField endp


;; a * x + p
;; FXPT = SDWORD = 4 bytes
;; keep in mind there's a fixed binary point in the middle
AXP	proc a:FXPT, x:FXPT, p:FXPT

  mov eax, a   ; eax <- a
  imul x       ; { edx, eax } <- eax * x, keep bottom bits (trunc)
               ;; edx = non-fractional component
               ;; eax = fractional component
  shr eax, 16  ; trunc. frac
  shl edx, 16  ; trunc. base
  or  eax, edx ; add base and frac
  add eax, p   ; eax +=   p

	ret  			; Careful! Don't remove this line
AXP	endp



END
