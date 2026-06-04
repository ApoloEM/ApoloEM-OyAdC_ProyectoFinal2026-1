; ============================================================
; BillarLogica.asm — Motor completo del Billar 8-Ball
; MASM x86 (32 bits) · FPU x87
; Proyecto Final OAC 2025-2 · UABC FIM
; ============================================================
.686                            ; Pentium Pro+ (32 bits + FPU)
.model flat, stdcall            ; Modelo plano, convencion stdcall
option casemap:none             ; Sensible a mayusculas

INCLUDE structures.inc

; ============================================================
;                     SECCION DE DATOS
; ============================================================
.data

; ---- Arreglo de 16 bolas ----
PUBLIC balls
balls Ball NUM_BALLS DUP(<>)

; ---- Arreglo de 6 troneras ----
pockets Pocket NUM_POCKETS DUP(<>)

; ---- Estado del juego ----
PUBLIC gameState
gameState GameState <>

; ---- Posiciones iniciales X (16 bolas) ----
; Bola 0 = blanca en cabecera
; Bolas 1-15 = rack triangular en el pie de la mesa
init_pos_x REAL8 250.0          ; 0: blanca
           REAL8 625.0          ; 1: apex (bola 1)
           REAL8 649.5          ; 2: fila 1
           REAL8 649.5          ; 3: fila 1
           REAL8 674.0          ; 4: fila 2
           REAL8 674.0          ; 5: fila 2 (bola 8, centro)
           REAL8 674.0          ; 6: fila 2
           REAL8 698.5          ; 7: fila 3
           REAL8 698.5          ; 8: fila 3
           REAL8 698.5          ; 9: fila 3
           REAL8 698.5          ; 10: fila 3
           REAL8 723.0          ; 11: fila 4 (esquina)
           REAL8 723.0          ; 12: fila 4
           REAL8 723.0          ; 13: fila 4
           REAL8 723.0          ; 14: fila 4
           REAL8 723.0          ; 15: fila 4 (esquina)

; ---- Posiciones iniciales Y (16 bolas) ----
init_pos_y REAL8 250.0          ; 0: blanca
           REAL8 250.0          ; 1: apex
           REAL8 236.0          ; 2: fila 1
           REAL8 264.0          ; 3: fila 1
           REAL8 222.0          ; 4: fila 2
           REAL8 250.0          ; 5: fila 2 (centro)
           REAL8 278.0          ; 6: fila 2
           REAL8 208.0          ; 7: fila 3
           REAL8 236.0          ; 8: fila 3
           REAL8 264.0          ; 9: fila 3
           REAL8 292.0          ; 10: fila 3
           REAL8 194.0          ; 11: fila 4
           REAL8 222.0          ; 12: fila 4
           REAL8 250.0          ; 13: fila 4
           REAL8 278.0          ; 14: fila 4
           REAL8 306.0          ; 15: fila 4

; ---- Numeros de bola en orden del arreglo ----
init_ball_num  DWORD  0, 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 7, 15, 14, 6, 13

; ---- Tipos de bola: 0=blanca, 1=lisa, 2=rayada, 3=ocho ----
init_ball_type DWORD  0, 1, 2, 1, 2, 3, 1, 2, 1, 2, 1, 1, 2, 2, 1, 2

; ---- Posiciones de las 6 troneras ----
pocket_x REAL8 54.0, 450.0, 846.0, 54.0, 450.0, 846.0
pocket_y REAL8 54.0,  46.0,  54.0, 446.0, 454.0, 446.0

; ---- Constantes de la mesa ----
TABLE_LEFT   REAL8  50.0
TABLE_TOP    REAL8  50.0
TABLE_RIGHT  REAL8 850.0
TABLE_BOTTOM REAL8 450.0

; ---- Constantes de fisica ----
FRICTION_COEFF  REAL8  0.985
MIN_VELOCITY    REAL8  0.01
MAX_SHOT_SPEED  REAL8  18.0
MULT_SHOT       REAL8  1.05

; ---- Arrastre (px) que equivale al 100% de fuerza en ComputeShot ----
POWER_FULL_DRAG REAL8  200.0
RESTITUTION     REAL8  0.95
BALL_RADIUS     REAL8  14.0
POCKET_RADIUS   REAL8  22.0

; ---- Constantes auxiliares FPU ----
FP_ZERO   REAL8  0.0
FP_ONE    REAL8  1.0
FP_TWO    REAL8  2.0
FP_HALF   REAL8  0.5
FP_NEGONE REAL8 -1.0

; ---- Diametro al cuadrado para colision bola-bola ----
; (2 * 14)^2 = 28^2 = 784
MIN_DIST_SQ REAL8 784.0
BALL_DIAM   REAL8 28.0

; ---- Pocket radius squared: 22^2 = 484 ----
POCKET_RAD_SQ REAL8 484.0

; ---- Distancia minima (al cuadrado) del centro de la blanca a una
;      tronera para que la colocacion ball-in-hand sea valida.
;      (POCKET_RADIUS + BALL_RADIUS)^2 = (22 + 14)^2 = 36^2 = 1296 ----
POCKET_CLEAR_SQ REAL8 1296.0

; ---- Constante para inicializar t_min en PredictShot ----
PRED_LARGE REAL8 1.0e10

; ============================================================
;              SECCION DE DATOS NO INICIALIZADOS
; ============================================================
.data?
; Variables temporales para calculos de colision
temp_dx     REAL8 ?
temp_dy     REAL8 ?
temp_dist   REAL8 ?
temp_dist_sq REAL8 ?
temp_nx     REAL8 ?
temp_ny     REAL8 ?
temp_dvn    REAL8 ?
temp_overlap REAL8 ?
temp_cos    REAL8 ?
temp_sin    REAL8 ?
temp_val    REAL8 ?
temp_dword  DWORD ?
; ---- Temporales para ComputeShot ----
cs_dx       REAL8 ?
cs_dy       REAL8 ?
; ---- Variables temporales para PredictShot ----
pred_dx       REAL8 ?
pred_dy       REAL8 ?
pred_cx       REAL8 ?
pred_cy       REAL8 ?
pred_vx       REAL8 ?
pred_vy       REAL8 ?
pred_t_proj   REAL8 ?
pred_t_min    REAL8 ?
pred_t_hit    REAL8 ?
pred_d2       REAL8 ?
pred_impact_x REAL8 ?
pred_impact_y REAL8 ?
pred_nx       REAL8 ?
pred_ny       REAL8 ?
pred_vdotn    REAL8 ?
pred_hit_idx  DWORD ?

; ============================================================
;                    SECCION DE CODIGO
; ============================================================
.code

; ============================================================
; DllMain — Punto de entrada de la DLL
; ============================================================
DllMain PROC hInstDLL:DWORD, fdwReason:DWORD, lpvReserved:DWORD
    MOV EAX, 1                  ; Retornar TRUE (exito)
    RET
DllMain ENDP

; ============================================================
; InitGame — Inicializa bolas, troneras y estado del juego
; ============================================================
InitGame PROC STDCALL
    PUSHAD                      ; Preservar todos los registros

    ; ---- Inicializar las 16 bolas ----
    LEA EDI, balls              ; EDI = destino (arreglo de bolas)
    LEA ESI, init_pos_x         ; ESI = posiciones X iniciales
    LEA EBX, init_pos_y         ; EBX = posiciones Y iniciales
    LEA ECX, init_ball_num      ; ECX = numeros de bola
    LEA EDX, init_ball_type     ; EDX = tipos de bola

    XOR EAX, EAX               ; EAX = indice = 0
init_ball_loop:
    CMP EAX, NUM_BALLS
    JGE init_balls_done

    ; Copiar pos_x (8 bytes)
    PUSH EAX
    SHL EAX, 3                  ; EAX * 8 = offset en arreglo REAL8
    FLD REAL8 PTR [ESI + EAX]   ; Cargar pos_x inicial
    FSTP [EDI].Ball.pos_x       ; Guardar en bola

    ; Copiar pos_y
    FLD REAL8 PTR [EBX + EAX]
    FSTP [EDI].Ball.pos_y
    POP EAX

    ; Velocidad = 0
    FLDZ
    FST [EDI].Ball.vel_x
    FSTP [EDI].Ball.vel_y

    ; Radio
    FLD BALL_RADIUS
    FSTP [EDI].Ball.radius

    ; Copiar ball_num (DWORD, offset = indice * 4)
    PUSH EAX
    SHL EAX, 2                  ; EAX * 4 = offset en arreglo DWORD
    MOV ESI, [ECX + EAX]        ; Leer ball_num
    MOV [EDI].Ball.ball_num, ESI
    MOV ESI, [EDX + EAX]        ; Leer ball_type
    MOV [EDI].Ball.ball_type, ESI
    POP EAX

    ; Flags
    MOV [EDI].Ball.is_active, 1
    MOV [EDI].Ball.was_pocketed, 0

    ; Restaurar ESI a init_pos_x (lo usamos como temp arriba)
    LEA ESI, init_pos_x

    ; Avanzar al siguiente Ball en el arreglo
    ADD EDI, BALL_SIZE
    INC EAX
    JMP init_ball_loop

init_balls_done:

    ; ---- Inicializar las 6 troneras ----
    LEA EDI, pockets
    LEA ESI, pocket_x
    LEA EBX, pocket_y
    XOR EAX, EAX
init_pocket_loop:
    CMP EAX, NUM_POCKETS
    JGE init_pockets_done

    PUSH EAX
    SHL EAX, 3                  ; offset * 8
    FLD REAL8 PTR [ESI + EAX]
    FSTP [EDI].Pocket.center_x
    FLD REAL8 PTR [EBX + EAX]
    FSTP [EDI].Pocket.center_y
    FLD POCKET_RADIUS
    FSTP [EDI].Pocket.pocket_rad
    POP EAX

    ADD EDI, POCKET_SIZE
    INC EAX
    JMP init_pocket_loop

init_pockets_done:

    ; ---- Resetear GameState ----
    LEA EDI, gameState
    MOV (GameState PTR [EDI]).current_player, 0
    MOV (GameState PTR [EDI]).player1_group, -1
    MOV (GameState PTR [EDI]).player2_group, -1
    MOV (GameState PTR [EDI]).player1_pocketed, 0
    MOV (GameState PTR [EDI]).player2_pocketed, 0
    MOV (GameState PTR [EDI]).game_phase, PHASE_BREAK
    MOV (GameState PTR [EDI]).is_foul, 0
    MOV (GameState PTR [EDI]).foul_reason, 0
    MOV (GameState PTR [EDI]).winner, -1
    MOV (GameState PTR [EDI]).all_stopped, 1
    MOV (GameState PTR [EDI]).first_hit_type, -1
    MOV (GameState PTR [EDI]).cue_pocketed, 0
    MOV (GameState PTR [EDI]).eight_pocketed, 0
    MOV (GameState PTR [EDI]).balls_pocketed_this_turn, 0

    ; Limpiar stack FPU por seguridad
    FINIT

    POPAD
    RET
InitGame ENDP

; ============================================================
; ApplyShot — Aplica un tiro a la bola blanca
; Recibe: puntero a ShotInput (angle, power)
; ============================================================
ApplyShot PROC STDCALL, pShot:PTR ShotInput
    PUSHAD
    MOV ESI, pShot

    ; Calcular sin y cos del angulo
    FLD [ESI].ShotInput.angle   ; ST(0) = angle
    FSINCOS                     ; ST(0) = cos(angle), ST(1) = sin(angle)
    FSTP temp_cos               ; temp_cos = cos(angle)
    FSTP temp_sin               ; temp_sin = sin(angle)

    ; vel_x = cos(angle) * power * MAX_SHOT_SPEED
    FLD [ESI].ShotInput.power
    FMUL MULT_SHOT            ; aplicar multiplicador global del 5%
    FMUL MAX_SHOT_SPEED       ; ST(0) = power * MULT * MAX_SPEED
    FLD ST(0)                 ; Duplicar: ST(0) = ST(1) = power * MULT * MAX_SPEED
    FMUL temp_cos             ; ST(0) = power * MULT * MAX_SPEED * cos
    LEA EDI, balls            ; EDI -> bola 0 (blanca)
    FSTP [EDI].Ball.vel_x     ; Guardar vel_x

    ; vel_y = sin(angle) * power * MAX_SHOT_SPEED
    FMUL temp_sin             ; ST(0) = power * MULT * MAX_SPEED * sin
    FSTP [EDI].Ball.vel_y     ; Guardar vel_y

    ; Resetear flags del turno
    MOV gameState.all_stopped, 0
    MOV gameState.is_foul, 0
    MOV gameState.foul_reason, 0
    MOV gameState.first_hit_type, -1
    MOV gameState.cue_pocketed, 0
    MOV gameState.eight_pocketed, 0
    MOV gameState.balls_pocketed_this_turn, 0

    ; Resetear was_pocketed de todas las bolas
    LEA EDI, balls
    XOR ECX, ECX
reset_pocketed_loop:
    CMP ECX, NUM_BALLS
    JGE reset_pocketed_done
    MOV [EDI].Ball.was_pocketed, 0
    ADD EDI, BALL_SIZE
    INC ECX
    JMP reset_pocketed_loop
reset_pocketed_done:

    POPAD
    RET
ApplyShot ENDP

; ============================================================
; UpdatePhysics — Un paso de simulacion (llamar ~60 fps)
; ============================================================
UpdatePhysics PROC STDCALL
    PUSHAD
    FINIT

    ; ---- 1. Actualizar posiciones y aplicar friccion ----
    LEA ESI, balls
    XOR ECX, ECX                ; ECX = indice de bola
update_pos_loop:
    CMP ECX, NUM_BALLS
    JGE update_pos_done

    ; Solo bolas activas
    CMP [ESI].Ball.is_active, 0
    JE update_pos_next

    ; pos_x += vel_x
    FLD [ESI].Ball.vel_x
    FADD [ESI].Ball.pos_x
    FSTP [ESI].Ball.pos_x

    ; pos_y += vel_y
    FLD [ESI].Ball.vel_y
    FADD [ESI].Ball.pos_y
    FSTP [ESI].Ball.pos_y

    ; vel_x *= FRICTION_COEFF
    FLD [ESI].Ball.vel_x
    FMUL FRICTION_COEFF
    FSTP [ESI].Ball.vel_x

    ; vel_y *= FRICTION_COEFF
    FLD [ESI].Ball.vel_y
    FMUL FRICTION_COEFF
    FSTP [ESI].Ball.vel_y

    ; Si |vel_x| < MIN_VELOCITY -> vel_x = 0
    FLD [ESI].Ball.vel_x
    FABS
    FCOMP MIN_VELOCITY          ; Compara |vel_x| con MIN_VEL, pop
    FNSTSW AX
    SAHF
    JA vel_x_ok                 ; |vel_x| > MIN_VEL, no tocar
    FLDZ
    FSTP [ESI].Ball.vel_x       ; vel_x = 0
vel_x_ok:

    ; Si |vel_y| < MIN_VELOCITY -> vel_y = 0
    FLD [ESI].Ball.vel_y
    FABS
    FCOMP MIN_VELOCITY
    FNSTSW AX
    SAHF
    JA vel_y_ok
    FLDZ
    FSTP [ESI].Ball.vel_y
vel_y_ok:

update_pos_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP update_pos_loop
update_pos_done:

    ; ---- 2. Colisiones bola-bola ----
    CALL CheckBallCollisions

    ; ---- 3. Colisiones bola-banda ----
    CALL CheckWallCollisions

    ; ---- 4. Colisiones bola-tronera ----
    CALL CheckPocketCollisions

    ; ---- 5. Verificar si todas las bolas estan detenidas ----
    CALL CheckAllStopped

    POPAD
    RET
UpdatePhysics ENDP

; ============================================================
; CheckBallCollisions — Doble loop sobre pares (i, j)
; VERSION CORREGIDA: usa FMUL con memoria en vez de FMUL ST,ST
; ============================================================
CheckBallCollisions PROC NEAR
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI

    XOR ECX, ECX                ; ECX = i
cbc_outer:
    CMP ECX, NUM_BALLS - 1
    JGE cbc_outer_done

    MOV EAX, ECX
    IMUL EAX, BALL_SIZE
    LEA ESI, [balls + EAX]      ; ESI -> balls[i]

    CMP [ESI].Ball.is_active, 0
    JE cbc_outer_next

    MOV EDX, ECX
    INC EDX                     ; j = i + 1
cbc_inner:
    CMP EDX, NUM_BALLS
    JGE cbc_outer_next

    MOV EAX, EDX
    IMUL EAX, BALL_SIZE
    LEA EDI, [balls + EAX]      ; EDI -> balls[j]

    CMP [EDI].Ball.is_active, 0
    JE cbc_inner_next

    ; ---- Calcular dx, dy, dist^2 ----
    ; dx = j.pos_x - i.pos_x
    FLD [EDI].Ball.pos_x
    FSUB [ESI].Ball.pos_x
    FSTP temp_dx                ; guardar dx, stack: []

    ; dy = j.pos_y - i.pos_y
    FLD [EDI].Ball.pos_y
    FSUB [ESI].Ball.pos_y
    FSTP temp_dy                ; guardar dy

    ; dist_sq = dx*dx + dy*dy
    FLD temp_dx
    FMUL temp_dx                ; dx^2 (usando memoria, mas seguro)
    FLD temp_dy
    FMUL temp_dy                ; dy^2, stack: [dy^2, dx^2]
    FADDP ST(1), ST(0)          ; [dx^2 + dy^2]
    FSTP temp_dist_sq           ; []

    ; Comparar con (2*radius)^2 = 784
    FLD temp_dist_sq
    FCOMP MIN_DIST_SQ
    FNSTSW AX
    SAHF
    JA cbc_inner_next           ; dist^2 > 784, no colision

    ; ---- HAY COLISION ----
    ; El registro de la primera bola golpeada por la blanca se hace en
    ; ResolveBallCollision, SOLO en impactos reales (bolas acercandose).
    ; Asi una bola en reposo pegada a la blanca no marca un falso contacto.

    ; Resolver colision
    PUSH ECX
    PUSH EDX
    CALL ResolveBallCollision
    POP EDX
    POP ECX

    ; Recalcular punteros (por seguridad)
    MOV EAX, ECX
    IMUL EAX, BALL_SIZE
    LEA ESI, [balls + EAX]
    MOV EAX, EDX
    IMUL EAX, BALL_SIZE
    LEA EDI, [balls + EAX]

cbc_inner_next:
    INC EDX
    JMP cbc_inner

cbc_outer_next:
    INC ECX
    JMP cbc_outer

cbc_outer_done:
    POP EDI
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    RET
CheckBallCollisions ENDP

; ============================================================
; ResolveBallCollision — Colision elastica (masas iguales)
; Entrada: ESI -> ball_i, EDI -> ball_j
; Requiere: temp_dx, temp_dy, temp_dist_sq ya calculados
; VERSION CORREGIDA: stack FPU balanceado en todas las rutas
; ============================================================
ResolveBallCollision PROC NEAR
    PUSH EBX

    ; ---- 1. Calcular distancia: dist = sqrt(dist_sq) ----
    FLD temp_dist_sq            ; stack: [dist_sq]
    FSQRT                       ; stack: [dist]
    FSTP temp_dist              ; stack: []  (FSTP pop)

    ; Guardia: si dist ~ 0, no resolver (evita divisiones)
    FLD temp_dist               ; stack: [dist]
    FCOMP FP_ZERO               ; compara y pop, stack: []
    FNSTSW AX
    SAHF
    JBE resolve_done            ; dist <= 0, salir con stack limpio

    ; ---- 2. Normalizar: nx = dx/dist, ny = dy/dist ----
    FLD temp_dx                 ; [dx]
    FDIV temp_dist              ; [dx/dist]
    FSTP temp_nx                ; [] -- nx guardado

    FLD temp_dy                 ; [dy]
    FDIV temp_dist              ; [dy/dist]
    FSTP temp_ny                ; [] -- ny guardado

    ; ---- 3. Producto punto: dvn = (v_i - v_j) . n ----
    ;    = (vi.x - vj.x) * nx + (vi.y - vj.y) * ny
    FLD [ESI].Ball.vel_x        ; [vi.x]
    FSUB [EDI].Ball.vel_x       ; [dvx]
    FMUL temp_nx                ; [dvx*nx]
    FSTP temp_val               ; [] -- dvx*nx guardado

    FLD [ESI].Ball.vel_y        ; [vi.y]
    FSUB [EDI].Ball.vel_y       ; [dvy]
    FMUL temp_ny                ; [dvy*ny]
    FADD temp_val               ; [dvx*nx + dvy*ny] = [dvn]
    FSTP temp_dvn               ; []

    ; ---- 4. Si dvn <= 0: bolas separandose, saltar a overlap ----
    FLD temp_dvn                ; [dvn]
    FCOMP FP_ZERO               ; compara y pop, stack: []
    FNSTSW AX
    SAHF
    JBE do_overlap_only         ; dvn <= 0, skip velocity update

    ; ---- Registrar primera bola golpeada por la blanca (impacto real) ----
    ; Solo se llega aqui con dvn > 0 (las bolas se estaban acercando).
    ; ball_i (ESI) es la blanca si su numero es 0; la golpeada es ball_j (EDI).
    CMP [ESI].Ball.ball_num, 0
    JNE rbc_skip_firsthit
    CMP gameState.first_hit_type, -1
    JNE rbc_skip_firsthit
    MOV EAX, [EDI].Ball.ball_type
    MOV gameState.first_hit_type, EAX
rbc_skip_firsthit:

    ; ---- 5. Actualizar velocidades (intercambio elastico) ----
    ; dvn*nx primero
    FLD temp_dvn
    FMUL temp_nx
    FSTP temp_val               ; temp_val = dvn*nx

    ; i.vel_x -= dvn*nx
    FLD [ESI].Ball.vel_x
    FSUB temp_val
    FSTP [ESI].Ball.vel_x

    ; j.vel_x += dvn*nx
    FLD [EDI].Ball.vel_x
    FADD temp_val
    FSTP [EDI].Ball.vel_x

    ; dvn*ny
    FLD temp_dvn
    FMUL temp_ny
    FSTP temp_val               ; temp_val = dvn*ny

    ; i.vel_y -= dvn*ny
    FLD [ESI].Ball.vel_y
    FSUB temp_val
    FSTP [ESI].Ball.vel_y

    ; j.vel_y += dvn*ny
    FLD [EDI].Ball.vel_y
    FADD temp_val
    FSTP [EDI].Ball.vel_y

do_overlap_only:
    ; ---- 6. Separar bolas superpuestas ----
    ; overlap = (2*radius) - dist = 28 - dist
    FLD BALL_DIAM               ; [28]
    FSUB temp_dist              ; [overlap]
    FSTP temp_overlap           ; []

    ; Si overlap <= 0, no hay superposicion
    FLD temp_overlap            ; [overlap]
    FCOMP FP_ZERO               ; compara y pop, stack: []
    FNSTSW AX
    SAHF
    JBE resolve_done            ; stack ya esta limpio

    ; push_x = (overlap/2) * nx
    FLD temp_overlap
    FMUL FP_HALF
    FMUL temp_nx
    FSTP temp_val               ; temp_val = push_x

    ; i.pos_x -= push_x
    FLD [ESI].Ball.pos_x
    FSUB temp_val
    FSTP [ESI].Ball.pos_x

    ; j.pos_x += push_x
    FLD [EDI].Ball.pos_x
    FADD temp_val
    FSTP [EDI].Ball.pos_x

    ; push_y = (overlap/2) * ny
    FLD temp_overlap
    FMUL FP_HALF
    FMUL temp_ny
    FSTP temp_val               ; temp_val = push_y

    ; i.pos_y -= push_y
    FLD [ESI].Ball.pos_y
    FSUB temp_val
    FSTP [ESI].Ball.pos_y

    ; j.pos_y += push_y
    FLD [EDI].Ball.pos_y
    FADD temp_val
    FSTP [EDI].Ball.pos_y

resolve_done:
    POP EBX
    RET
ResolveBallCollision ENDP

; ============================================================
; CheckWallCollisions — Reflexion en las 4 bandas
; ============================================================
CheckWallCollisions PROC NEAR
    PUSH ECX
    PUSH ESI

    LEA ESI, balls
    XOR ECX, ECX
wall_loop:
    CMP ECX, NUM_BALLS
    JGE wall_done

    CMP [ESI].Ball.is_active, 0
    JE wall_next

    ; ---- Banda izquierda: pos_x - radius < TABLE_LEFT ----
    FLD [ESI].Ball.pos_x
    FSUB [ESI].Ball.radius      ; ST(0) = borde izq de la bola
    FCOMP TABLE_LEFT
    FNSTSW AX
    SAHF
    JA check_right              ; borde > TABLE_LEFT, no penetra

    ; Reflexion vel_x
    FLD [ESI].Ball.vel_x
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_x

    ; Correccion de posicion
    FLD TABLE_LEFT
    FADD [ESI].Ball.radius
    FSTP [ESI].Ball.pos_x
    JMP check_top               ; Saltar check_right

check_right:
    ; ---- Banda derecha: pos_x + radius > TABLE_RIGHT ----
    FLD [ESI].Ball.pos_x
    FADD [ESI].Ball.radius
    FCOMP TABLE_RIGHT
    FNSTSW AX
    SAHF
    JB check_top                ; borde < TABLE_RIGHT, no penetra
    JE check_top                ; borde == TABLE_RIGHT, ok

    FLD [ESI].Ball.vel_x
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_x

    FLD TABLE_RIGHT
    FSUB [ESI].Ball.radius
    FSTP [ESI].Ball.pos_x

check_top:
    ; ---- Banda superior: pos_y - radius < TABLE_TOP ----
    FLD [ESI].Ball.pos_y
    FSUB [ESI].Ball.radius
    FCOMP TABLE_TOP
    FNSTSW AX
    SAHF
    JA check_bottom

    FLD [ESI].Ball.vel_y
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_y

    FLD TABLE_TOP
    FADD [ESI].Ball.radius
    FSTP [ESI].Ball.pos_y
    JMP wall_next

check_bottom:
    ; ---- Banda inferior: pos_y + radius > TABLE_BOTTOM ----
    FLD [ESI].Ball.pos_y
    FADD [ESI].Ball.radius
    FCOMP TABLE_BOTTOM
    FNSTSW AX
    SAHF
    JB wall_next
    JE wall_next

    FLD [ESI].Ball.vel_y
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_y

    FLD TABLE_BOTTOM
    FSUB [ESI].Ball.radius
    FSTP [ESI].Ball.pos_y

wall_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP wall_loop

wall_done:
    POP ESI
    POP ECX
    RET
CheckWallCollisions ENDP

; ============================================================
; CheckPocketCollisions — Verificar embocado en troneras
; VERSION CORREGIDA: usa FMUL memoria + FINIT preventivo
; ============================================================
CheckPocketCollisions PROC NEAR
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI

    LEA ESI, balls
    XOR ECX, ECX
cpc_ball_loop:
    CMP ECX, NUM_BALLS
    JGE cpc_done

    CMP [ESI].Ball.is_active, 0
    JE cpc_ball_next

    ; Iterar sobre las 6 troneras
    LEA EDI, pockets
    XOR EDX, EDX
cpc_check_loop:
    CMP EDX, NUM_POCKETS
    JGE cpc_ball_next

    ; dx = ball.pos_x - pocket.center_x
    FLD [ESI].Ball.pos_x
    FSUB [EDI].Pocket.center_x
    FSTP temp_dx

    ; dy = ball.pos_y - pocket.center_y
    FLD [ESI].Ball.pos_y
    FSUB [EDI].Pocket.center_y
    FSTP temp_dy

    ; dist_sq = dx^2 + dy^2
    FLD temp_dx
    FMUL temp_dx
    FLD temp_dy
    FMUL temp_dy
    FADDP ST(1), ST(0)
    FCOMP POCKET_RAD_SQ         ; comparar con radio^2, pop
    FNSTSW AX
    SAHF
    JA cpc_check_next           ; dist_sq > 484, no emboco

    ; ---- BOLA EMBOCADA ----
    INC gameState.balls_pocketed_this_turn

    ; Verificar si es la blanca
    CMP [ESI].Ball.ball_num, 0
    JNE cpc_not_cue
    MOV gameState.cue_pocketed, 1
    MOV [ESI].Ball.is_active, 0      ; retirar la blanca de la mesa (scratch)
    MOV [ESI].Ball.was_pocketed, 1   ; sin esto se recontaria cada frame
    FLDZ
    FST [ESI].Ball.vel_x
    FSTP [ESI].Ball.vel_y
    JMP cpc_ball_next

cpc_not_cue:
    ; Verificar si es la bola 8
    CMP [ESI].Ball.ball_num, 8
    JNE cpc_not_eight
    MOV gameState.eight_pocketed, 1

cpc_not_eight:
    MOV [ESI].Ball.is_active, 0
    MOV [ESI].Ball.was_pocketed, 1
    FLDZ
    FST [ESI].Ball.vel_x
    FSTP [ESI].Ball.vel_y
    JMP cpc_ball_next

cpc_check_next:
    ADD EDI, POCKET_SIZE
    INC EDX
    JMP cpc_check_loop

cpc_ball_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP cpc_ball_loop

cpc_done:
    POP EDI
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    RET
CheckPocketCollisions ENDP

; ============================================================
; CheckAllStopped — Verifica si todas las bolas estan quietas
; ============================================================
CheckAllStopped PROC NEAR
    PUSH ECX
    PUSH ESI

    LEA ESI, balls
    XOR ECX, ECX
stopped_loop:
    CMP ECX, NUM_BALLS
    JGE all_are_stopped

    CMP [ESI].Ball.is_active, 0
    JE stopped_next

    ; Verificar vel_x != 0
    FLD [ESI].Ball.vel_x
    FTST
    FNSTSW AX
    FSTP ST(0)                  ; Pop
    SAHF
    JNE not_all_stopped         ; vel_x != 0

    ; Verificar vel_y != 0
    FLD [ESI].Ball.vel_y
    FTST
    FNSTSW AX
    FSTP ST(0)
    SAHF
    JNE not_all_stopped

stopped_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP stopped_loop

all_are_stopped:
    MOV gameState.all_stopped, 1
    JMP stopped_end

not_all_stopped:
    MOV gameState.all_stopped, 0

stopped_end:
    POP ESI
    POP ECX
    RET
CheckAllStopped ENDP

; ============================================================
; AreAllBallsStopped — Retorna 1 si todas quietas, 0 si no
; ============================================================
AreAllBallsStopped PROC STDCALL
    MOV EAX, gameState.all_stopped
    RET
AreAllBallsStopped ENDP

; ============================================================
; GetBallData — Copia datos de las 16 bolas a buffer plano
; Buffer: 16 bolas * 8 valores REAL8 = 128 doubles
; Formato por bola: pos_x, pos_y, vel_x, vel_y,
;                   radius, ball_num, ball_type, is_active
; ============================================================
GetBallData PROC STDCALL, pOutArray:PTR REAL8
    PUSHAD
    MOV EDI, pOutArray          ; EDI = buffer de salida
    LEA ESI, balls              ; ESI = arreglo de bolas
    XOR ECX, ECX

get_ball_loop:
    CMP ECX, NUM_BALLS
    JGE get_ball_done

    ; Copiar 5 REAL8 directamente (pos_x, pos_y, vel_x, vel_y, radius)
    ; Cada REAL8 = 8 bytes, copiamos 40 bytes
    PUSH ECX
    MOV ECX, 10                 ; 40 bytes / 4 = 10 DWORDs
    PUSH ESI
    PUSH EDI
    REP MOVSD                   ; Copia 40 bytes de ESI a EDI
    POP EDI
    ADD EDI, 40                 ; Avanzar destino 40 bytes
    POP ESI

    ; Convertir ball_num (DWORD) a REAL8
    FILD DWORD PTR [ESI + 40]   ; ball_num esta en offset 40
    FSTP REAL8 PTR [EDI]
    ADD EDI, 8

    ; Convertir ball_type (DWORD) a REAL8
    FILD DWORD PTR [ESI + 44]   ; ball_type en offset 44
    FSTP REAL8 PTR [EDI]
    ADD EDI, 8

    ; Convertir is_active (DWORD) a REAL8
    FILD DWORD PTR [ESI + 48]   ; is_active en offset 48
    FSTP REAL8 PTR [EDI]
    ADD EDI, 8

    POP ECX
    ADD ESI, BALL_SIZE
    INC ECX
    JMP get_ball_loop

get_ball_done:
    POPAD
    RET
GetBallData ENDP

; ============================================================
; GetGameState — Copia GameState al buffer de C#
; ============================================================
GetGameState PROC STDCALL, pOutState:PTR GameState
    PUSHAD
    MOV EDI, pOutState
    LEA ESI, gameState
    MOV ECX, SIZEOF GameState
    SHR ECX, 2                  ; Dividir entre 4 (copiar DWORDs)
    REP MOVSD
    POPAD
    RET
GetGameState ENDP

; ============================================================
; CONSULTA DE GEOMETRIA DEL TABLERO
; ------------------------------------------------------------
; Expone las dimensiones que la fisica esta usando, para que
; la interfaz dibuje el fieltro y las troneras en las mismas
; coordenadas exactas. Elimina la doble definicion.
; ============================================================

GetTableMetrics PROC STDCALL, pOut:PTR REAL8
    ; Escribe 7 valores REAL8 (56 bytes) al buffer:
    ;   pOut[0] = playArea_left   (X minima del fieltro jugable)
    ;   pOut[1] = playArea_top    (Y minima del fieltro jugable)
    ;   pOut[2] = playArea_right  (X maxima del fieltro jugable)
    ;   pOut[3] = playArea_bottom (Y maxima del fieltro jugable)
    ;   pOut[4] = ball_radius     (radio comun de las bolas)
    ;   pOut[5] = pocket_radius   (radio de captura de tronera)
    ;   pOut[6] = num_pockets     (siempre 6.0)
    ;
    ; Convencion: las posiciones (pos_x, pos_y) de las bolas son
    ; el CENTRO de la bola. Una bola toca el cojin izquierdo cuando
    ; su centro llega a (playArea_left + ball_radius). El fieltro
    ; visible se dibuja desde playArea_left hasta playArea_right.
    
    PUSH EDI
    MOV EDI, pOut                       ; EDI = puntero al buffer destino
    
    FLD TABLE_LEFT                      ; ST: tableLeft
    FSTP REAL8 PTR [EDI + 0]            ; pOut[0] = tableLeft
    
    FLD TABLE_TOP                       ; ST: tableTop
    FSTP REAL8 PTR [EDI + 8]            ; pOut[1] = tableTop
    
    FLD TABLE_RIGHT                     ; ST: tableRight
    FSTP REAL8 PTR [EDI + 16]           ; pOut[2] = tableRight
    
    FLD TABLE_BOTTOM                    ; ST: tableBottom
    FSTP REAL8 PTR [EDI + 24]           ; pOut[3] = tableBottom
    
    ; Radio comun de las bolas — se lee del primer registro del
    ; arreglo balls[] (todas comparten radio). Si en tu codigo
    ; tienes una constante BALL_RADIUS REAL8, usa esa en su lugar.
    LEA ESI, balls
    FLD REAL8 PTR [ESI].Ball.radius     ; ST: ballRadius
    FSTP REAL8 PTR [EDI + 32]           ; pOut[4] = ballRadius
    
    ; Radio de captura de tronera (igual para las 6)
    LEA ESI, pockets
    FLD REAL8 PTR [ESI].Pocket.pocket_rad   ; ST: pocketRadius
    FSTP REAL8 PTR [EDI + 40]               ; pOut[5] = pocketRadius
    
    ; NUM_POCKETS como REAL8 (convertir DWORD -> REAL8 via FILD)
    PUSH NUM_POCKETS                    ; pone 6 en la pila
    FILD DWORD PTR [ESP]                ; ST: 6.0
    ADD ESP, 4
    FSTP REAL8 PTR [EDI + 48]           ; pOut[6] = 6.0
    
    POP EDI
    RET
GetTableMetrics ENDP

; ------------------------------------------------------------

GetPocketData PROC STDCALL, pOut:PTR REAL8
    ; Escribe 6 pares (x, y) = 12 valores REAL8 (96 bytes).
    ; Formato: [px0, py0, px1, py1, ..., px5, py5]
    ;
    ; Permite que la GUI dibuje cada tronera en el mismo punto
    ; donde la fisica la considera ubicada — evita que una bola
    ; "entre" visualmente a una tronera y rebote.
    
    PUSH ESI
    PUSH EDI
    PUSH ECX
    
    LEA ESI, pockets                    ; ESI = arreglo origen
    MOV EDI, pOut                       ; EDI = buffer destino
    MOV ECX, NUM_POCKETS                ; ECX = contador (6)
    
copia_tronera:
    FLD REAL8 PTR [ESI].Pocket.center_x ; ST: cx
    FSTP REAL8 PTR [EDI]                ; destino[0] = cx
    FLD REAL8 PTR [ESI].Pocket.center_y ; ST: cy
    FSTP REAL8 PTR [EDI + 8]            ; destino[1] = cy
    
    ADD ESI, SIZEOF Pocket              ; siguiente tronera origen
    ADD EDI, 16                         ; siguiente par destino
    LOOP copia_tronera                  ; ECX-- ; jnz
    
    POP ECX
    POP EDI
    POP ESI
    RET
GetPocketData ENDP

; ============================================================
; PredictShot — Calcula la prediccion de trayectoria del tiro
; ------------------------------------------------------------
; Esta funcion NO modifica el estado del juego. Es matematica
; pura: lanza un rayo desde la blanca en la direccion dada y
; determina contra QUE objeto va a chocar primero (otra bola
; o un cojin) y, si fue bola, hacia donde va cada una de las
; dos despues del impacto (colision elastica, masas iguales).
;
; Llamada 60 veces por segundo mientras el jugador apunta.
;
; Parametros:
;   angle  REAL8       : Angulo del tiro en radianes
;   pOut   PTR REAL8   : Buffer de 8 doubles (64 bytes) para salida
;
; Salida (pOut[0..7]):
;   [0] tipo: -1 sin prediccion (blanca embocada),
;              0 = el rayo termina contra cojin,
;              1 = el rayo termina golpeando otra bola
;   [1] impact_x : centro de la blanca en el momento del impacto
;   [2] impact_y
;   [3] ball_id  : indice (1..15) de la bola golpeada, o -1 si cojin
;   [4] white_post_dx : direccion unitaria post-impacto de la blanca
;   [5] white_post_dy
;   [6] target_post_dx: direccion unitaria post-impacto de la bola
;                       golpeada (cero si fue cojin)
;   [7] target_post_dy
; ============================================================
PredictShot PROC STDCALL, angle:REAL8, pOut:PTR REAL8
    PUSHAD
    FINIT                              ; FPU stack limpia

    ; ---------- 1. Validar que la blanca este en mesa ----------
    LEA ESI, balls                     ; ESI -> balls[0] (blanca)
    CMP [ESI].Ball.is_active, 0
    JNE pred_white_active

    ; Blanca embocada: tipo = -1 y todo en cero
    MOV EDI, pOut
    FLD FP_NEGONE
    FSTP REAL8 PTR [EDI + 0]
    FLDZ
    FST  REAL8 PTR [EDI + 8]
    FST  REAL8 PTR [EDI + 16]
    FST  REAL8 PTR [EDI + 24]
    FST  REAL8 PTR [EDI + 32]
    FST  REAL8 PTR [EDI + 40]
    FST  REAL8 PTR [EDI + 48]
    FSTP REAL8 PTR [EDI + 56]
    POPAD
    RET

pred_white_active:
    ; ---------- 2. Cachear posicion blanca y direccion ----------
    FLD [ESI].Ball.pos_x
    FSTP pred_cx
    FLD [ESI].Ball.pos_y
    FSTP pred_cy

    FLD angle                          ; ST: angle
    FSINCOS                            ; ST: cos, sin
    FSTP pred_dx                       ; pred_dx = cos
    FSTP pred_dy                       ; pred_dy = sin

    ; t_min iniciado en valor enorme; quien gane se queda
    FLD PRED_LARGE
    FSTP pred_t_min
    MOV pred_hit_idx, -1               ; -1 = nada todavia (o cojin al final)

    ; ---------- 3. Ray vs cada bola activa j (1..15) ----------
    LEA ESI, balls
    ADD ESI, BALL_SIZE                 ; saltar la blanca (j=0)
    MOV ECX, 1

pred_loop_balls:
    CMP ECX, NUM_BALLS
    JGE pred_balls_done

    CMP [ESI].Ball.is_active, 0
    JE  pred_next_ball

    ; v = bj.pos - cue.pos
    FLD [ESI].Ball.pos_x
    FSUB pred_cx
    FSTP pred_vx

    FLD [ESI].Ball.pos_y
    FSUB pred_cy
    FSTP pred_vy

    ; t_proj = v . dir = vx*dx + vy*dy
    FLD pred_vx
    FMUL pred_dx
    FLD pred_vy
    FMUL pred_dy
    FADDP ST(1), ST(0)
    FSTP pred_t_proj

    ; Si t_proj <= 0, la bola esta atras del rayo: descartar
    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_next_ball

    ; Si t_proj >= t_min ya conocido, no puede ganar: descartar
    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_next_ball

    ; |v|^2 = vx^2 + vy^2
    FLD pred_vx
    FMUL pred_vx
    FLD pred_vy
    FMUL pred_vy
    FADDP ST(1), ST(0)                 ; ST: |v|^2

    ; d^2 = |v|^2 - t_proj^2  (distancia perpendicular cuadrada)
    FLD pred_t_proj
    FMUL pred_t_proj
    FSUBP ST(1), ST(0)                 ; ST: |v|^2 - t_proj^2
    FSTP pred_d2

    ; Si d^2 > (2r)^2 el rayo no toca esta bola: descartar
    FLD pred_d2
    FCOMP MIN_DIST_SQ                  ; (2r)^2 = 784
    FNSTSW AX
    SAHF
    JA  pred_next_ball

    ; t_hit = t_proj - sqrt((2r)^2 - d^2)
    FLD MIN_DIST_SQ
    FSUB pred_d2
    FSQRT                              ; ST: sqrt((2r)^2 - d^2)
    FSUBR pred_t_proj                  ; ST: t_proj - sqrt(...)
    FSTP pred_t_hit

    ; Si t_hit <= 0, las bolas estaban casi superpuestas: descartar
    FLD pred_t_hit
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_next_ball

    ; Si t_hit < t_min, esta bola es la nueva mejor candidata
    FLD pred_t_hit
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_next_ball

    FLD pred_t_hit
    FSTP pred_t_min
    MOV pred_hit_idx, ECX

pred_next_ball:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP pred_loop_balls

pred_balls_done:

    ; ---------- 4. Ray vs los 4 cojines ----------
    ; Para cada cojin: si la direccion apunta hacia el, calcular
    ; t = (linea_cojin - centro_actual) / direccion
    ; Si ese t es positivo y menor al t_min actual, gana el cojin.
    ; Cuando un cojin gana, hit_idx queda en -1 (significa "pared").

    ; ---- Cojin izquierdo: t = (TABLE_LEFT + r - cx) / dx, valido si dx < 0 ----
    FLD pred_dx
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JAE pred_skip_left                 ; dx >= 0, no va al izquierdo

    FLD TABLE_LEFT
    FADD BALL_RADIUS
    FSUB pred_cx
    FDIV pred_dx
    FSTP pred_t_proj                   ; reuso de pred_t_proj como t_wall

    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_left

    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_skip_left

    FLD pred_t_proj
    FSTP pred_t_min
    MOV pred_hit_idx, -1

pred_skip_left:
    ; ---- Cojin derecho: t = (TABLE_RIGHT - r - cx) / dx, valido si dx > 0 ----
    FLD pred_dx
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_right

    FLD TABLE_RIGHT
    FSUB BALL_RADIUS
    FSUB pred_cx
    FDIV pred_dx
    FSTP pred_t_proj

    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_right

    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_skip_right

    FLD pred_t_proj
    FSTP pred_t_min
    MOV pred_hit_idx, -1

pred_skip_right:
    ; ---- Cojin superior: t = (TABLE_TOP + r - cy) / dy, valido si dy < 0 ----
    FLD pred_dy
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JAE pred_skip_top

    FLD TABLE_TOP
    FADD BALL_RADIUS
    FSUB pred_cy
    FDIV pred_dy
    FSTP pred_t_proj

    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_top

    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_skip_top

    FLD pred_t_proj
    FSTP pred_t_min
    MOV pred_hit_idx, -1

pred_skip_top:
    ; ---- Cojin inferior: t = (TABLE_BOTTOM - r - cy) / dy, valido si dy > 0 ----
    FLD pred_dy
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_bottom

    FLD TABLE_BOTTOM
    FSUB BALL_RADIUS
    FSUB pred_cy
    FDIV pred_dy
    FSTP pred_t_proj

    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_skip_bottom

    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_skip_bottom

    FLD pred_t_proj
    FSTP pred_t_min
    MOV pred_hit_idx, -1

pred_skip_bottom:

    ; ---------- 5. Punto de impacto ----------
    ; impact = cue + dir * t_min
    FLD pred_dx
    FMUL pred_t_min
    FADD pred_cx
    FSTP pred_impact_x

    FLD pred_dy
    FMUL pred_t_min
    FADD pred_cy
    FSTP pred_impact_y

    ; ---------- 6. Escribir salida ----------
    MOV EDI, pOut

    CMP pred_hit_idx, -1
    JE  pred_wall_out                  ; hit_idx == -1 ⇒ cojin

    ; ===== CASO BOLA =====
    ; pOut[0] = 1.0  (tipo = bola)
    FLD FP_ONE
    FSTP REAL8 PTR [EDI + 0]

    ; pOut[1,2] = impact_x, impact_y
    FLD pred_impact_x
    FSTP REAL8 PTR [EDI + 8]
    FLD pred_impact_y
    FSTP REAL8 PTR [EDI + 16]

    ; pOut[3] = hit_idx convertido a REAL8
    FILD DWORD PTR pred_hit_idx
    FSTP REAL8 PTR [EDI + 24]

    ; ---- Calcular n = unit(target_center - impact_point) ----
    ; En el momento del impacto los centros estan a distancia 2r,
    ; entonces (target - impact) tiene magnitud 2r y se normaliza
    ; dividiendo por BALL_DIAM.
    MOV EAX, pred_hit_idx
    IMUL EAX, BALL_SIZE
    LEA ESI, balls
    ADD ESI, EAX                       ; ESI -> bola golpeada

    FLD [ESI].Ball.pos_x
    FSUB pred_impact_x
    FDIV BALL_DIAM
    FSTP pred_nx

    FLD [ESI].Ball.pos_y
    FSUB pred_impact_y
    FDIV BALL_DIAM
    FSTP pred_ny

    ; v . n = dx*nx + dy*ny  (proyeccion del rayo sobre la normal)
    FLD pred_dx
    FMUL pred_nx
    FLD pred_dy
    FMUL pred_ny
    FADDP ST(1), ST(0)
    FSTP pred_vdotn

    ; pOut[6,7] = target_post = n  (la bola objetivo sale por la normal)
    FLD pred_nx
    FSTP REAL8 PTR [EDI + 48]
    FLD pred_ny
    FSTP REAL8 PTR [EDI + 56]

    ; ---- white_post_raw = v - (v.n) * n ----
    ; Componente tangencial de v: por donde sale la blanca tras el choque
    FLD pred_vdotn
    FMUL pred_nx
    FSUBR pred_dx                      ; ST: dx - vdotn*nx
    FSTP pred_vx                       ; reuso pred_vx como white_post_raw_x

    FLD pred_vdotn
    FMUL pred_ny
    FSUBR pred_dy                      ; ST: dy - vdotn*ny
    FSTP pred_vy                       ; reuso pred_vy como white_post_raw_y

    ; Magnitud = sqrt(wpx^2 + wpy^2)
    FLD pred_vx
    FMUL pred_vx
    FLD pred_vy
    FMUL pred_vy
    FADDP ST(1), ST(0)
    FSQRT                              ; ST: |wp|

    ; Si |wp| < epsilon, golpe casi de frente: blanca se detiene
    FLD ST(0)                          ; duplicar |wp| para comparar
    FCOMP MIN_VELOCITY
    FNSTSW AX
    SAHF
    JA  pred_wp_normalize

    ; Caso degenerado: white_post = (0, 0)
    FSTP ST(0)                         ; descartar |wp| del stack
    FLDZ
    FST  REAL8 PTR [EDI + 32]
    FSTP REAL8 PTR [EDI + 40]
    JMP pred_done

pred_wp_normalize:
    ; ST(0) = |wp|. Dividir wpx, wpy entre |wp| para obtener unitario.
    FLD pred_vx
    FDIV ST(0), ST(1)                  ; wpx / |wp|
    FSTP REAL8 PTR [EDI + 32]

    FLD pred_vy
    FDIV ST(0), ST(1)                  ; wpy / |wp|
    FSTP REAL8 PTR [EDI + 40]

    FSTP ST(0)                         ; descartar |wp| residual
    JMP pred_done

    ; ===== CASO COJIN =====
pred_wall_out:
    FLDZ
    FSTP REAL8 PTR [EDI + 0]           ; tipo = 0

    FLD pred_impact_x
    FSTP REAL8 PTR [EDI + 8]
    FLD pred_impact_y
    FSTP REAL8 PTR [EDI + 16]

    FLD FP_NEGONE
    FSTP REAL8 PTR [EDI + 24]          ; ball_id = -1

    FLDZ
    FST  REAL8 PTR [EDI + 32]
    FST  REAL8 PTR [EDI + 40]
    FST  REAL8 PTR [EDI + 48]
    FSTP REAL8 PTR [EDI + 56]

pred_done:
    POPAD
    RET
PredictShot ENDP

; ============================================================
; EvaluateTurn — Evalua reglas del 8-ball tras fin de tiro
; Retorna en EAX: codigo de resultado (0-4)
; ============================================================
EvaluateTurn PROC STDCALL
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI

    ; ---- Verificar si se emboco la bola 8 ----
    CMP gameState.eight_pocketed, 1
    JNE no_eight_pocketed

    ; La bola 8 fue embocada — determinar si es victoria o derrota
    ; Contar cuantas bolas del grupo del jugador actual quedan
    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE player2_group_check
    MOV EBX, gameState.player1_group
    JMP check_group_count
player2_group_check:
    MOV EBX, gameState.player2_group

check_group_count:
    ; Si grupos no asignados (-1), embocar la 8 es derrota automatica
    CMP EBX, -1
    JE eight_lose

    ; Contar bolas restantes del grupo
    XOR EDX, EDX                ; EDX = contador de bolas restantes
    LEA ESI, balls
    XOR ECX, ECX
count_remaining:
    CMP ECX, NUM_BALLS
    JGE count_done
    CMP [ESI].Ball.is_active, 1
    JNE count_next
    CMP [ESI].Ball.ball_type, EBX  ; Tipo == grupo del jugador?
    JNE count_next
    INC EDX                     ; Encontramos una bola que aun esta en mesa
count_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP count_remaining
count_done:

    ; Si quedan bolas del grupo, embocar la 8 es derrota
    CMP EDX, 0
    JG eight_lose

    ; Si NO quedan bolas y NO hubo foul -> VICTORIA
    CMP gameState.cue_pocketed, 1
    JE eight_lose               ; Si tambien emboco la blanca -> pierde
    CMP gameState.is_foul, 1
    JE eight_lose               ; Si hubo otro foul -> pierde

    ; VICTORIA
    MOV gameState.game_phase, PHASE_GAME_OVER
    MOV EAX, gameState.current_player
    MOV gameState.winner, EAX
    MOV EAX, RESULT_WIN
    JMP evaluate_done

eight_lose:
    ; DERROTA — el oponente gana
    MOV gameState.game_phase, PHASE_GAME_OVER
    MOV EAX, gameState.current_player
    XOR EAX, 1                  ; Oponente = 1 - current
    MOV gameState.winner, EAX
    MOV EAX, RESULT_LOSE
    JMP evaluate_done

no_eight_pocketed:

    ; ---- Verificar FOULS ----
    ; Foul 1: bola blanca embocada (scratch)
    CMP gameState.cue_pocketed, 1
    JNE no_cue_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 1
    JMP process_foul
no_cue_foul:

    ; Foul 2: la blanca no golpeo ninguna bola
    CMP gameState.first_hit_type, -1
    JNE no_miss_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 2
    JMP process_foul
no_miss_foul:

    ; Foul 3 / Foul 4: primera bola golpeada incorrecta.
    ; La regla es POR JUGADOR (no global): depende de si al jugador
    ; ACTUAL aun le quedaban bolas de su grupo al INICIAR este tiro.
    ;   - Si le quedaban  -> su primera bola debe ser de su grupo;
    ;                        pegar a la 8 (u otra) antes = foul (3).
    ;   - Si ya no tenia (ya estaba en la 8) -> su primera bola debe
    ;                        ser la 8; no hacerlo = foul (4).
    ; (solo aplica si los grupos ya estan asignados)
    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE get_p2_group
    MOV EBX, gameState.player1_group
    JMP check_wrong_group
get_p2_group:
    MOV EBX, gameState.player2_group
check_wrong_group:
    CMP EBX, -1
    JE no_wrong_group_foul      ; Grupos no asignados, mesa abierta

    ; Contar las bolas del grupo que seguian en mesa al INICIO del tiro.
    ; "En mesa al iniciar" = activa ahora (is_active==1) O embocada en
    ; este mismo turno (was_pocketed==1). Asi, embocar tu ultima bola
    ; buena en este tiro no te exige (erroneamente) haber pegado a la 8.
    XOR EDX, EDX                ; EDX = bolas del grupo al iniciar el tiro
    LEA ESI, balls
    XOR ECX, ECX
fc_count_before:
    CMP ECX, NUM_BALLS
    JGE fc_count_done
    CMP [ESI].Ball.ball_type, EBX
    JNE fc_count_next
    CMP [ESI].Ball.is_active, 1
    JE fc_count_inc
    CMP [ESI].Ball.was_pocketed, 1
    JNE fc_count_next
fc_count_inc:
    INC EDX
fc_count_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP fc_count_before
fc_count_done:

    CMP EDX, 0
    JG must_hit_own_group       ; aun tenia bolas propias -> debe pegar su grupo

    ; Ya estaba en la 8: la primera bola debe ser la 8
    CMP gameState.first_hit_type, TYPE_EIGHT
    JE no_wrong_group_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 4
    JMP process_foul

must_hit_own_group:
    ; La primera bola debe ser del grupo del jugador
    MOV EAX, gameState.first_hit_type
    CMP EAX, EBX               ; first_hit_type == grupo_jugador?
    JE no_wrong_group_foul
    ; Pegar a la 8 (o al grupo del oponente) antes que al tuyo = foul.
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 3
    JMP process_foul
no_wrong_group_foul:

    ; ---- Sin foul: evaluar resultado del turno ----

    ; Si estamos en BREAK o OPEN_TABLE y se emboco alguna bola -> asignar grupo
    CMP gameState.game_phase, PHASE_BREAK
    JE try_assign_groups
    CMP gameState.game_phase, PHASE_OPEN_TABLE
    JE try_assign_groups
    JMP check_repeat_turn

try_assign_groups:
    ; Transicion de BREAK -> OPEN_TABLE
    CMP gameState.game_phase, PHASE_BREAK
    JNE already_open
    MOV gameState.game_phase, PHASE_OPEN_TABLE
already_open:

    ; Si se emboco alguna bola (que no sea blanca ni 8) -> asignar grupo
    CMP gameState.balls_pocketed_this_turn, 0
    JE check_repeat_turn        ; No se emboco nada -> cambio de turno

    ; Buscar la primera bola embocada este turno para determinar grupo
    LEA ESI, balls
    MOV ECX, 1                  ; Empezar desde bola 1 (saltar blanca)
find_pocketed:
    CMP ECX, NUM_BALLS
    JGE check_repeat_turn

    ; Calcular offset manualmente: EAX = &balls[ECX]
    MOV EAX, ECX
    IMUL EAX, BALL_SIZE
    LEA EAX, [ESI + EAX]

    CMP (Ball PTR [EAX]).was_pocketed, 1
    JNE find_next

    ; Verificar que no sea la bola 8
    CMP (Ball PTR [EAX]).ball_type, TYPE_EIGHT
    JE find_next

    ; Asignar grupo: jugador actual -> tipo de esta bola
    MOV EDX, (Ball PTR [EAX]).ball_type
    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE assign_p2
    MOV gameState.player1_group, EDX
    ; Oponente recibe el grupo contrario
    CMP EDX, TYPE_SOLID
    JNE assign_p1_stripe
    MOV gameState.player2_group, TYPE_STRIPE
    JMP groups_assigned
assign_p1_stripe:
    MOV gameState.player2_group, TYPE_SOLID
    JMP groups_assigned
assign_p2:
    MOV gameState.player2_group, EDX
    CMP EDX, TYPE_SOLID
    JNE assign_p2_stripe
    MOV gameState.player1_group, TYPE_STRIPE
    JMP groups_assigned
assign_p2_stripe:
    MOV gameState.player1_group, TYPE_SOLID

groups_assigned:
    MOV gameState.game_phase, PHASE_NORMAL
    JMP check_repeat_turn

find_next:
    INC ECX
    JMP find_pocketed

check_repeat_turn:
    ; La fase NORMAL vs SHOOTING_EIGHT se ajusta al final del turno,
    ; ya POR JUGADOR, en SetPhaseForCurrentPlayer. Aqui solo se decide
    ; si el jugador repite turno o lo cede.

no_phase_change:
    ; Si se emboco al menos una bola propia sin foul -> repite turno
    CMP gameState.balls_pocketed_this_turn, 0
    JE change_turn              ; No emboco nada -> cambio de turno

    ; Verificar si alguna bola embocada es del grupo del jugador
    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE get_p2_grp3
    MOV EBX, gameState.player1_group
    JMP search_own_pocketed
get_p2_grp3:
    MOV EBX, gameState.player2_group
search_own_pocketed:
    CMP EBX, -1
    JE repeat_any               ; Mesa abierta: cualquier bola embocada cuenta

    LEA ESI, balls
    XOR ECX, ECX
find_own_pocketed:
    CMP ECX, NUM_BALLS
    JGE change_turn             ; No encontro ninguna propia -> cambio
    CMP [ESI].Ball.was_pocketed, 1
    JNE find_own_next
    CMP [ESI].Ball.ball_type, EBX
    JE found_own_pocketed       ; Emboco una propia!
find_own_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP find_own_pocketed

found_own_pocketed:
    ; Actualizar contador del jugador
    CALL UpdatePlayerPocketed
    MOV EAX, RESULT_REPEAT_TURN
    JMP evaluate_done

repeat_any:
    ; Mesa abierta: emboco algo -> repite
    MOV EAX, RESULT_REPEAT_TURN
    JMP evaluate_done

change_turn:
    ; Actualizar contador y cambiar turno
    CALL UpdatePlayerPocketed
    MOV EAX, gameState.current_player
    XOR EAX, 1                  ; Cambiar: 0->1 o 1->0
    MOV gameState.current_player, EAX
    MOV EAX, RESULT_CHANGE_TURN
    JMP evaluate_done

process_foul:
    ; Actualizar contadores
    CALL UpdatePlayerPocketed
    ; Cambiar turno
    MOV EAX, gameState.current_player
    XOR EAX, 1
    MOV gameState.current_player, EAX
    MOV EAX, RESULT_FOUL
    JMP evaluate_done

evaluate_done:
    ; Ajustar la fase para el jugador que tiene el turno AHORA (por
    ; jugador, no global). No modifica EAX ni el estado si la partida
    ; ya termino o si los grupos aun no se asignan.
    CALL SetPhaseForCurrentPlayer
    POP EDI
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    RET
EvaluateTurn ENDP

; ============================================================
; SetPhaseForCurrentPlayer — Ajusta game_phase (NORMAL vs
; SHOOTING_EIGHT) segun el grupo del jugador que tiene el turno.
; Es POR JUGADOR: cada quien pasa a la 8 solo cuando limpio SU grupo,
; de modo que el rival siga obligado a jugar sus bolas.
; - No modifica EAX (preserva el codigo de resultado del turno).
; - No toca nada si la partida termino (GAME_OVER) ni si los grupos
;   aun no estan asignados (deja BREAK / OPEN_TABLE).
; ============================================================
SetPhaseForCurrentPlayer PROC NEAR
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI

    CMP gameState.game_phase, PHASE_GAME_OVER
    JE sp_done                  ; Partida terminada: no tocar

    ; Grupo del jugador con el turno actual
    MOV EBX, gameState.current_player
    CMP EBX, 0
    JNE sp_use_p2
    MOV EBX, gameState.player1_group
    JMP sp_have_group
sp_use_p2:
    MOV EBX, gameState.player2_group
sp_have_group:
    CMP EBX, -1
    JE sp_done                  ; Mesa abierta: dejar BREAK/OPEN_TABLE

    ; Contar bolas activas del grupo del jugador actual
    XOR EDX, EDX
    LEA ESI, balls
    XOR ECX, ECX
sp_count_loop:
    CMP ECX, NUM_BALLS
    JGE sp_count_done
    CMP [ESI].Ball.is_active, 1
    JNE sp_count_next
    CMP [ESI].Ball.ball_type, EBX
    JNE sp_count_next
    INC EDX
sp_count_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP sp_count_loop
sp_count_done:

    CMP EDX, 0
    JG sp_set_normal            ; aun le quedan bolas de su grupo
    MOV gameState.game_phase, PHASE_SHOOTING_EIGHT
    JMP sp_done
sp_set_normal:
    MOV gameState.game_phase, PHASE_NORMAL

sp_done:
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    RET
SetPhaseForCurrentPlayer ENDP

; ============================================================
; UpdatePlayerPocketed — Cuenta bolas embocadas por cada jugador
; (procedimiento auxiliar interno)
; ============================================================
UpdatePlayerPocketed PROC NEAR
    PUSH ECX
    PUSH ESI
    PUSH EAX

    ; Contar bolas embocadas (is_active == 0 y ball_type != 0 y != 3)
    XOR EAX, EAX               ; P1 solids pocketed
    XOR EDX, EDX               ; P2 count (reutilizamos)

    ; Contar lisas embocadas
    MOV ECX, 0
    MOV EAX, 0                 ; solids pocketed
    MOV EDX, 0                 ; stripes pocketed
    LEA ESI, balls
count_p_loop:
    CMP ECX, NUM_BALLS
    JGE count_p_done
    CMP [ESI].Ball.is_active, 0 ; Solo embocadas
    JNE count_p_next
    CMP [ESI].Ball.ball_type, TYPE_SOLID
    JNE check_stripe_count
    INC EAX                     ; +1 lisa embocada
    JMP count_p_next
check_stripe_count:
    CMP [ESI].Ball.ball_type, TYPE_STRIPE
    JNE count_p_next
    INC EDX                     ; +1 rayada embocada
count_p_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP count_p_loop
count_p_done:

    ; Asignar a jugadores segun su grupo
    ; Si J1 tiene lisas: p1_pocketed = solids_count, p2_pocketed = stripes_count
    CMP gameState.player1_group, TYPE_SOLID
    JNE check_p1_stripe
    MOV gameState.player1_pocketed, EAX
    MOV gameState.player2_pocketed, EDX
    JMP update_p_done
check_p1_stripe:
    CMP gameState.player1_group, TYPE_STRIPE
    JNE update_p_unassigned
    MOV gameState.player1_pocketed, EDX
    MOV gameState.player2_pocketed, EAX
    JMP update_p_done
update_p_unassigned:
    ; Grupos no asignados: total combinado
    ADD EAX, EDX
    MOV gameState.player1_pocketed, EAX
    MOV gameState.player2_pocketed, 0
update_p_done:
    POP EAX
    POP ESI
    POP ECX
    RET
UpdatePlayerPocketed ENDP

; ============================================================
; PlaceCueBall — Reposiciona la bola blanca (ball-in-hand).
; Valida que el centro deseado quede DENTRO del area jugable (sin
; penetrar los cojines), LEJOS de las troneras y SIN superponerse
; a otra bola activa. Asi no se puede dejar la blanca en una tronera
; ni en el marco de la mesa.
; Recibe: new_x, new_y (centro deseado de la blanca, coords fisicas)
; Retorna en EAX: 1=exito (colocada), 0=posicion invalida
; ============================================================
PlaceCueBall PROC STDCALL, new_x:REAL8, new_y:REAL8
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI
    FINIT                        ; FPU limpia (defensivo)

    ; ---- 1. Dentro del area jugable (centro a >= radio del cojin) ----
    ; X >= TABLE_LEFT + BALL_RADIUS
    FLD new_x
    FSUB TABLE_LEFT
    FSUB BALL_RADIUS             ; new_x - (TABLE_LEFT + r)
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JB place_invalid            ; < 0 -> penetra el cojin izquierdo

    ; X <= TABLE_RIGHT - BALL_RADIUS
    FLD new_x
    FSUB TABLE_RIGHT
    FADD BALL_RADIUS            ; new_x - (TABLE_RIGHT - r)
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JA place_invalid           ; > 0 -> penetra el cojin derecho

    ; Y >= TABLE_TOP + BALL_RADIUS
    FLD new_y
    FSUB TABLE_TOP
    FSUB BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JB place_invalid           ; < 0 -> penetra el cojin superior

    ; Y <= TABLE_BOTTOM - BALL_RADIUS
    FLD new_y
    FSUB TABLE_BOTTOM
    FADD BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JA place_invalid           ; > 0 -> penetra el cojin inferior

    ; ---- 2. Lejos de cualquier tronera ----
    LEA EDI, pockets
    XOR EDX, EDX
place_pocket_loop:
    CMP EDX, NUM_POCKETS
    JGE place_pockets_ok

    FLD new_x
    FSUB [EDI].Pocket.center_x
    FMUL ST(0), ST(0)          ; dx^2
    FLD new_y
    FSUB [EDI].Pocket.center_y
    FMUL ST(0), ST(0)          ; dy^2
    FADDP ST(1), ST(0)         ; dist^2 hacia la tronera
    FCOMP POCKET_CLEAR_SQ
    FNSTSW AX
    SAHF
    JB place_invalid           ; dist^2 < (r_tronera+r_bola)^2 -> sobre tronera

    ADD EDI, POCKET_SIZE
    INC EDX
    JMP place_pocket_loop
place_pockets_ok:

    ; ---- 3. Sin superponerse a otra bola activa ----
    LEA ESI, balls
    ADD ESI, BALL_SIZE           ; Empezar desde bola 1 (saltar blanca)
    MOV ECX, 1

place_check_loop:
    CMP ECX, NUM_BALLS
    JGE place_ok

    CMP [ESI].Ball.is_active, 0
    JE place_check_next

    ; Calcular distancia^2 entre (new_x, new_y) y esta bola
    FLD new_x
    FSUB [ESI].Ball.pos_x
    FMUL ST(0), ST(0)           ; dx^2

    FLD new_y
    FSUB [ESI].Ball.pos_y
    FMUL ST(0), ST(0)           ; dy^2

    FADDP ST(1), ST(0)          ; dist^2
    FCOMP MIN_DIST_SQ           ; Comparar con (2*radius)^2
    FNSTSW AX
    SAHF
    JA place_check_next         ; dist^2 > min_dist^2, ok
    JMP place_invalid           ; Superposicion con otra bola

place_check_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP place_check_loop

place_ok:
    ; Posicion valida, mover la blanca y reactivarla
    LEA ESI, balls              ; balls[0] = blanca
    FLD new_x
    FSTP [ESI].Ball.pos_x
    FLD new_y
    FSTP [ESI].Ball.pos_y
    FLDZ
    FST [ESI].Ball.vel_x
    FSTP [ESI].Ball.vel_y
    MOV [ESI].Ball.is_active, 1
    MOV EAX, 1
    JMP place_done

place_invalid:
    MOV EAX, 0

place_done:
    POP EDI
    POP ESI
    POP EDX
    POP ECX
    RET
PlaceCueBall ENDP

; ============================================================
; ComputeShot — Traduce el gesto del jugador en parametros de tiro.
; TODA la matematica del tiro (angulo, fuerza, direccion) vive aqui;
; el host solo entrega coordenadas crudas y dibuja con la salida.
;
; Parametros:
;   cueX, cueY   : centro de la bola blanca (px de pantalla)
;   dragX, dragY : punto donde se inicio el arrastre de fuerza
;   ptrX, ptrY   : posicion actual del puntero
;   pOut         : buffer de 4 REAL8 (32 bytes) de salida
;
; Salida (pOut[0..3]):
;   [0] angle   : atan2(ptrY-cueY, ptrX-cueX), radianes
;   [1] power   : min(dist(ptr,drag) / POWER_FULL_DRAG, 1.0), en [0,1]
;   [2] aimDirX : direccion unitaria blanca->puntero (0 si |aim| <= 1px)
;   [3] aimDirY
;
; El angulo y las distancias son invariantes a la traslacion
; pantalla<->fisica (esa conversion es solo un desplazamiento), por
; eso el host puede pasar coordenadas de pantalla sin convertir.
; ============================================================
ComputeShot PROC STDCALL, cueX:REAL8, cueY:REAL8, dragX:REAL8, dragY:REAL8, ptrX:REAL8, ptrY:REAL8, pOut:PTR REAL8
    PUSH EDI
    FINIT                              ; FPU limpia (defensivo)
    MOV EDI, pOut

    ; ---------- 1. angle = atan2(ptrY-cueY, ptrX-cueX) ----------
    FLD ptrY
    FSUB cueY                          ; ST: aimdy
    FLD ptrX
    FSUB cueX                          ; ST: aimdx, aimdy
    FPATAN                             ; ST: atan2(aimdy, aimdx)
    FSTP REAL8 PTR [EDI + 0]           ; pOut[0] = angle

    ; ---------- 2. Direccion unitaria blanca -> puntero ----------
    FLD ptrX
    FSUB cueX
    FSTP cs_dx                         ; cs_dx = aimdx
    FLD ptrY
    FSUB cueY
    FSTP cs_dy                         ; cs_dy = aimdy

    ; aimdist = sqrt(aimdx^2 + aimdy^2)
    FLD cs_dx
    FMUL cs_dx
    FLD cs_dy
    FMUL cs_dy
    FADDP ST(1), ST(0)                 ; ST: aimdx^2 + aimdy^2
    FSQRT                              ; ST: aimdist

    ; Si aimdist <= 1 px, puntero casi sobre la blanca: dir = (0,0)
    FLD ST(0)                          ; ST: aimdist, aimdist
    FCOMP FP_ONE                       ; compara aimdist con 1.0, pop
    FNSTSW AX
    SAHF
    JA cs_dir_ok                       ; aimdist > 1 -> normalizar

    FSTP ST(0)                         ; descartar aimdist
    FLDZ
    FST  REAL8 PTR [EDI + 16]          ; pOut[2] = 0
    FSTP REAL8 PTR [EDI + 24]          ; pOut[3] = 0
    JMP cs_power

cs_dir_ok:
    ; ST: aimdist  (divisor comun)
    FLD cs_dx
    FDIV ST(0), ST(1)                  ; aimdx / aimdist
    FSTP REAL8 PTR [EDI + 16]          ; pOut[2] = aimDirX
    FLD cs_dy
    FDIV ST(0), ST(1)                  ; aimdy / aimdist
    FSTP REAL8 PTR [EDI + 24]          ; pOut[3] = aimDirY
    FSTP ST(0)                         ; descartar aimdist

cs_power:
    ; ---------- 3. power = min(dist(ptr,drag)/POWER_FULL_DRAG, 1) ----------
    FLD ptrX
    FSUB dragX
    FSTP cs_dx                         ; cs_dx = pdx
    FLD ptrY
    FSUB dragY
    FSTP cs_dy                         ; cs_dy = pdy

    FLD cs_dx
    FMUL cs_dx
    FLD cs_dy
    FMUL cs_dy
    FADDP ST(1), ST(0)                 ; ST: pdx^2 + pdy^2
    FSQRT                              ; ST: dragdist
    FDIV POWER_FULL_DRAG               ; ST: ratio (siempre >= 0)

    ; clamp superior a 1.0 (el inferior es 0 por construccion)
    FLD ST(0)                          ; ST: ratio, ratio
    FCOMP FP_ONE                       ; compara ratio con 1.0, pop
    FNSTSW AX
    SAHF
    JBE cs_power_store                 ; ratio <= 1 -> dejar
    FSTP ST(0)                         ; descartar ratio > 1
    FLD FP_ONE                         ; power = 1.0
cs_power_store:
    FSTP REAL8 PTR [EDI + 8]           ; pOut[1] = power

    POP EDI
    RET
ComputeShot ENDP

; ============================================================
END DllMain