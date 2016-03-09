;-------------------------------------------------------------------------------
;; Numbered Lists for to MACROify some Astermeroids
;-------------------------------------------------------------------------------
N25  TEXTEQU < 1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25>
N50  TEXTEQU <26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50>
N75  TEXTEQU <51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75>
N100 TEXTEQU <76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100>
N125 TEXTEQU <101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125>
N150 TEXTEQU <126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150>
N175 TEXTEQU <151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175>
N200 TEXTEQU <176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200>

;-------------------------------------------------------------------------------
;; AsteroidLists compiled from them numbers up above there
;-------------------------------------------------------------------------------
AsteroidList  TEXTEQU @CatStr(<!<>, %N25, <,>, %N50, <!>>)
AsteroidList2 TEXTEQU @CatStr(<!<>, %N75, <,>, %N100, <!>>)
AsteroidList3 TEXTEQU @CatStr(<!<>, %N125, <,>, %N150, <!>>)
AsteroidList4 TEXTEQU @CatStr(<!<>, %N175, <,>, %N200, <!>>)

;-------------------------------------------------------------------------------
;; AsteroidList creation MACRO for to make them Astermeroids
;-------------------------------------------------------------------------------
CreateAsteroids MACRO list
  %FOR aid, list
    Asteroid&aid AnimatedCharacter {\
      { 20 + &aid, 20 + &aid, &aid * 4096 }, ; position
      { 0, 0, 0 }, ; velocity
      { 0, 0, 0 }, ; acceleration
      ,            ; collider
      { 0, 1, SIZEOF EECS205BITMAP, OFFSET asteroid_000 }\ ; animation
    }
  ENDM
ENDM

InitializeAsteroidShaders MACRO lst
  %FOR aid, lst
    IF aid LT 30
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_005
    ELSEIF aid LT 60
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_004
    ELSEIF aid LT 90
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_001
    ELSEIF aid LT 95
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_003
    ELSEIF aid LT 100
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_000
    ELSE
      mov Asteroid&aid.anim.frame_ptr, OFFSET asteroid_002
    ENDIF
    invoke CopyShader, OFFSET Asteroid&aid.shader, OFFSET BaseShader

    invoke Randomize, OFFSET Asteroid&aid
  ENDM
ENDM

CalculateAsteroidsShaders MACRO lst
  %FOR aid, lst
    invoke CalculateShaderColorMask, OFFSET Asteroid&aid
    invoke CalculateShaderColorShift, OFFSET Asteroid&aid
  ENDM
ENDM

DrawAsteroids MACRO lst
  %FOR aid, lst
    invoke Draw, OFFSET Asteroid&aid
  ENDM
ENDM

UpdateAsteroids MACRO lst
  %FOR aid, lst
    invoke Update, OFFSET Asteroid&aid
  ENDM
ENDM

CalculateAsteroidsColliders MACRO lst
  %FOR aid, lst
    invoke CalculateCollider, OFFSET Asteroid&aid
  ENDM
ENDM

CheckIntersectAsteroids MACRO lst
  %FOR aid, lst
    invoke CheckIntersectRect, OFFSET Fighter.collider, OFFSET Asteroid&aid&.collider
    or ebx, eax
  ENDM
ENDM

CountAsteroidsVisible MACRO lst
  %FOR aid, lst
    invoke fxpt2int, Asteroid&aid.position.y
    mov edx, eax
    invoke fxpt2int, Asteroid&aid.position.x

    .if eax > SCREEN_X_MIN && eax < SCREEN_X_MAX
      .if edx > SCREEN_Y_MIN && edx < SCREEN_Y_MAX
        inc ecx
      .endif
    .endif
  ENDM
ENDM

AsteroidsCopyShaders MACRO lst, s1, s2
  %FOR aid, lst
    invoke CopyShaders, OFFSET Asteroid&aid.shader, OFFSET s1, OFFSET s2
  ENDM
ENDM

AllAsteroidsCopyShaders MACRO s1, s2
  AsteroidsCopyShaders AsteroidList, s1, s2
  AsteroidsCopyShaders AsteroidList2, s1, s2
  AsteroidsCopyShaders AsteroidList3, s1, s2
  AsteroidsCopyShaders AsteroidList4, s1, s2
ENDM

InvokeOnAsteroids MACRO fn
  %FOR aid, lst
    invoke fn, Asteroid&aid
  ENDM
ENDM

RandomizeAsteroids MACRO lst
  InvokeOnAsteroids Randomize
ENDM

AllAsteroids MACRO m
  m AsteroidList
  m AsteroidList2
  m AsteroidList3
  m AsteroidList4
ENDM

InitializeAllAsteroids MACRO
  AllAsteroids InitializeAsteroidShaders
ENDM

CalculateAllAsteroidsShaders MACRO
  AllAsteroids CalculateAsteroidsShaders
ENDM

DrawAllAsteroids MACRO
  AllAsteroids DrawAsteroids
ENDM

UpdateAllAsteroids MACRO
  AllAsteroids UpdateAsteroids
ENDM

CalculateAllAsteroidsColliders MACRO
  AllAsteroids CalculateAsteroidsColliders
ENDM

CheckIntersectAllAsteroids MACRO
  AllAsteroids CheckIntersectAsteroids
ENDM

RandomizeAllAsteroids MACRO
  AllAsteroids RandomizeAsteroids
ENDM

CountAllAsteroidsVisible MACRO
  xor ecx, ecx
  AllAsteroids CountAsteroidsVisible
ENDM
