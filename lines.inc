; #########################################################################
;
;   lines.inc - Includes for EECS205 Assignment 2
;
;
; #########################################################################

externdef SINTAB:WORD
externdef ScreenBitsPtr:DWORD

FixedSin proto angle:FXPT
FixedCos proto angle:FXPT
DrawLine proto x0:DWORD, y0:DWORD, x1:DWORD, y1:DWORD, color:DWORD

PLOT PROTO x:DWORD, y:DWORD, color:DWORD
Abs  PROTO x:DWORD

;;  These are some useful constants (fixed point values that correspond to important angles)
PI_HALF = 102943           	    ;;  PI / 2
PI =  205887	                  ;;  PI
TWO_PI	= 411774                ;;  2 * PI
PI_INC_RECIP =  5340353        	;;  256 / PI
