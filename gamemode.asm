
xpad = 8
ypad = 12

DrawSelectionScreen MACRO x:req, y:req, color:req
  yi = 0

  xi = 0
  FORC lttr, <love game binary totally questionable>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0ffh
    xi = xi + 1
  ENDM

  yi = yi + 1

  xi = 0
  FORC lttr, <why asteroids tornado>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0dah
    xi = xi + 1
  ENDM

  invoke DrawLetter, OFFSET l7question, x + xpad*xi, y + ypad*yi, 0dah
  xi = xi + 1
  invoke DrawLetter, OFFSET l7exclamation, x + xpad*xi, y + ypad*yi, 0dah

  yi = yi + 1

  xi = 0
  FOR lttr, <dot, dot, dot, , f, u, c, k, dot>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 06dh
    xi = xi + 1
  ENDM

  yi = yi + 5

  xi = 0
  FOR lttr, <o, r, , dot, dot, dot, >
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0dah
    xi = xi + 1
  ENDM

  FOR lttr, <l, g, b, t, q, , w, a, t, question, exclamation, f, u, q>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 01ch
    xi = xi + 1
  ENDM

  yi = yi + 1

  xi = 5
  FORC lttr, <for short>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0dah
    xi = xi + 1
  ENDM

  yi = yi + 2

  xi = 0
  FORC lttr, <a game for to playing by you>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0cbh
    xi = xi + 1
  ENDM

  yi = yi + 2

  xi = 0
  FORC lttr, <was make by him that is jordan>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 06dh
    xi = xi + 1
  ENDM

  yi = yi + 2

  xi = 5
  FORC lttr, <thank for playing it>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 06dh
    xi = xi + 1
  ENDM

  yi = yi + 4

  xi = 0
  FOR lttr, <b,u,t,t,o,n, ,f,o,r, ,t,h,e, ,s,e,l,e,c,t,i,o,n, ,f,o,l,l,o,w,i,n,g,dot,dot,dot>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0ffh
    xi = xi + 1
  ENDM

  yi = yi + 2

  xi = 5
  FORC lttr, <1 basic mode>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 01ch
    xi = xi + 1
  ENDM

  yi = yi + 1

  xi = 5
  FORC lttr, <2 hard mode>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 01ch
    xi = xi + 1
  ENDM

  yi = yi + 1

  xi = 5
  FORC lttr, <3 insane mode>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 01ch
    xi = xi + 1
  ENDM

  yi = yi + 2

  xi = 10
  FOR lttr, <p,l,e,a,s,e, ,m,a,k,e, ,s,e,l,e,c,t, ,o,k,question>
    invoke DrawLetter, OFFSET @CatStr(<l7>, <lttr>), x + xpad*xi, y + ypad*yi, 0ffh
    xi = xi + 1
  ENDM
ENDM
