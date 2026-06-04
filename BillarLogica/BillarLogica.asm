.686
.model flat, stdcall
option casemap:none

INCLUDE structures.inc

.data

PUBLIC balls
balls Ball NUM_BALLS DUP(<>)

pockets Pocket NUM_POCKETS DUP(<>)

PUBLIC gameState
gameState GameState <>

init_pos_x REAL8 250.0
           REAL8 625.0
           REAL8 649.5
           REAL8 649.5
           REAL8 674.0
           REAL8 674.0
           REAL8 674.0
           REAL8 698.5
           REAL8 698.5
           REAL8 698.5
           REAL8 698.5
           REAL8 723.0
           REAL8 723.0
           REAL8 723.0
           REAL8 723.0
           REAL8 723.0

init_pos_y REAL8 250.0
           REAL8 250.0
           REAL8 236.0
           REAL8 264.0
           REAL8 222.0
           REAL8 250.0
           REAL8 278.0
           REAL8 208.0
           REAL8 236.0
           REAL8 264.0
           REAL8 292.0
           REAL8 194.0
           REAL8 222.0
           REAL8 250.0
           REAL8 278.0
           REAL8 306.0

init_ball_num  DWORD  0, 1, 9, 2, 10, 8, 3, 11, 4, 12, 5, 7, 15, 14, 6, 13

init_ball_type DWORD  0, 1, 2, 1, 2, 3, 1, 2, 1, 2, 1, 1, 2, 2, 1, 2

pocket_x REAL8 54.0, 450.0, 846.0, 54.0, 450.0, 846.0
pocket_y REAL8 54.0,  46.0,  54.0, 446.0, 454.0, 446.0

TABLE_LEFT   REAL8  50.0
TABLE_TOP    REAL8  50.0
TABLE_RIGHT  REAL8 850.0
TABLE_BOTTOM REAL8 450.0

FRICTION_COEFF  REAL8  0.985
MIN_VELOCITY    REAL8  0.01
MAX_SHOT_SPEED  REAL8  18.0
MULT_SHOT       REAL8  1.05

POWER_FULL_DRAG REAL8  200.0
RESTITUTION     REAL8  0.95
BALL_RADIUS     REAL8  14.0
POCKET_RADIUS   REAL8  22.0

FP_ZERO   REAL8  0.0
FP_ONE    REAL8  1.0
FP_TWO    REAL8  2.0
FP_HALF   REAL8  0.5
FP_NEGONE REAL8 -1.0

MIN_DIST_SQ REAL8 784.0
BALL_DIAM   REAL8 28.0

POCKET_RAD_SQ REAL8 484.0

POCKET_CLEAR_SQ REAL8 1296.0

PRED_LARGE REAL8 1.0e10

.data?

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

cs_dx       REAL8 ?
cs_dy       REAL8 ?

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

.code

DllMain PROC hInstDLL:DWORD, fdwReason:DWORD, lpvReserved:DWORD
    MOV EAX, 1
    RET
DllMain ENDP

InitGame PROC STDCALL
    PUSHAD

    LEA EDI, balls
    LEA ESI, init_pos_x
    LEA EBX, init_pos_y
    LEA ECX, init_ball_num
    LEA EDX, init_ball_type

    XOR EAX, EAX
init_ball_loop:
    CMP EAX, NUM_BALLS
    JGE init_balls_done

    PUSH EAX
    SHL EAX, 3
    FLD REAL8 PTR [ESI + EAX]
    FSTP [EDI].Ball.pos_x

    FLD REAL8 PTR [EBX + EAX]
    FSTP [EDI].Ball.pos_y
    POP EAX

    FLDZ
    FST [EDI].Ball.vel_x
    FSTP [EDI].Ball.vel_y

    FLD BALL_RADIUS
    FSTP [EDI].Ball.radius

    PUSH EAX
    SHL EAX, 2
    MOV ESI, [ECX + EAX]
    MOV [EDI].Ball.ball_num, ESI
    MOV ESI, [EDX + EAX]
    MOV [EDI].Ball.ball_type, ESI
    POP EAX

    MOV [EDI].Ball.is_active, 1
    MOV [EDI].Ball.was_pocketed, 0

    LEA ESI, init_pos_x

    ADD EDI, BALL_SIZE
    INC EAX
    JMP init_ball_loop

init_balls_done:

    LEA EDI, pockets
    LEA ESI, pocket_x
    LEA EBX, pocket_y
    XOR EAX, EAX
init_pocket_loop:
    CMP EAX, NUM_POCKETS
    JGE init_pockets_done

    PUSH EAX
    SHL EAX, 3
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

    FINIT

    POPAD
    RET
InitGame ENDP

ApplyShot PROC STDCALL, pShot:PTR ShotInput
    PUSHAD
    MOV ESI, pShot

    FLD [ESI].ShotInput.angle
    FSINCOS
    FSTP temp_cos
    FSTP temp_sin

    FLD [ESI].ShotInput.power
    FMUL MULT_SHOT
    FMUL MAX_SHOT_SPEED
    FLD ST(0)
    FMUL temp_cos
    LEA EDI, balls
    FSTP [EDI].Ball.vel_x

    FMUL temp_sin
    FSTP [EDI].Ball.vel_y

    MOV gameState.all_stopped, 0
    MOV gameState.is_foul, 0
    MOV gameState.foul_reason, 0
    MOV gameState.first_hit_type, -1
    MOV gameState.cue_pocketed, 0
    MOV gameState.eight_pocketed, 0
    MOV gameState.balls_pocketed_this_turn, 0

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

UpdatePhysics PROC STDCALL
    PUSHAD
    FINIT

    LEA ESI, balls
    XOR ECX, ECX
update_pos_loop:
    CMP ECX, NUM_BALLS
    JGE update_pos_done

    CMP [ESI].Ball.is_active, 0
    JE update_pos_next

    FLD [ESI].Ball.vel_x
    FADD [ESI].Ball.pos_x
    FSTP [ESI].Ball.pos_x

    FLD [ESI].Ball.vel_y
    FADD [ESI].Ball.pos_y
    FSTP [ESI].Ball.pos_y

    FLD [ESI].Ball.vel_x
    FMUL FRICTION_COEFF
    FSTP [ESI].Ball.vel_x

    FLD [ESI].Ball.vel_y
    FMUL FRICTION_COEFF
    FSTP [ESI].Ball.vel_y

    FLD [ESI].Ball.vel_x
    FABS
    FCOMP MIN_VELOCITY
    FNSTSW AX
    SAHF
    JA vel_x_ok
    FLDZ
    FSTP [ESI].Ball.vel_x
vel_x_ok:

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

    CALL CheckBallCollisions

    CALL CheckWallCollisions

    CALL CheckPocketCollisions

    CALL CheckAllStopped

    POPAD
    RET
UpdatePhysics ENDP

CheckBallCollisions PROC NEAR
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI

    XOR ECX, ECX
cbc_outer:
    CMP ECX, NUM_BALLS - 1
    JGE cbc_outer_done

    MOV EAX, ECX
    IMUL EAX, BALL_SIZE
    LEA ESI, [balls + EAX]

    CMP [ESI].Ball.is_active, 0
    JE cbc_outer_next

    MOV EDX, ECX
    INC EDX
cbc_inner:
    CMP EDX, NUM_BALLS
    JGE cbc_outer_next

    MOV EAX, EDX
    IMUL EAX, BALL_SIZE
    LEA EDI, [balls + EAX]

    CMP [EDI].Ball.is_active, 0
    JE cbc_inner_next

    FLD [EDI].Ball.pos_x
    FSUB [ESI].Ball.pos_x
    FSTP temp_dx

    FLD [EDI].Ball.pos_y
    FSUB [ESI].Ball.pos_y
    FSTP temp_dy

    FLD temp_dx
    FMUL temp_dx
    FLD temp_dy
    FMUL temp_dy
    FADDP ST(1), ST(0)
    FSTP temp_dist_sq

    FLD temp_dist_sq
    FCOMP MIN_DIST_SQ
    FNSTSW AX
    SAHF
    JA cbc_inner_next

    PUSH ECX
    PUSH EDX
    CALL ResolveBallCollision
    POP EDX
    POP ECX

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

ResolveBallCollision PROC NEAR
    PUSH EBX

    FLD temp_dist_sq
    FSQRT
    FSTP temp_dist

    FLD temp_dist
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE resolve_done

    FLD temp_dx
    FDIV temp_dist
    FSTP temp_nx

    FLD temp_dy
    FDIV temp_dist
    FSTP temp_ny

    FLD [ESI].Ball.vel_x
    FSUB [EDI].Ball.vel_x
    FMUL temp_nx
    FSTP temp_val

    FLD [ESI].Ball.vel_y
    FSUB [EDI].Ball.vel_y
    FMUL temp_ny
    FADD temp_val
    FSTP temp_dvn

    FLD temp_dvn
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE do_overlap_only

    CMP [ESI].Ball.ball_num, 0
    JNE rbc_skip_firsthit
    CMP gameState.first_hit_type, -1
    JNE rbc_skip_firsthit
    MOV EAX, [EDI].Ball.ball_type
    MOV gameState.first_hit_type, EAX
rbc_skip_firsthit:

    FLD temp_dvn
    FMUL temp_nx
    FSTP temp_val

    FLD [ESI].Ball.vel_x
    FSUB temp_val
    FSTP [ESI].Ball.vel_x

    FLD [EDI].Ball.vel_x
    FADD temp_val
    FSTP [EDI].Ball.vel_x

    FLD temp_dvn
    FMUL temp_ny
    FSTP temp_val

    FLD [ESI].Ball.vel_y
    FSUB temp_val
    FSTP [ESI].Ball.vel_y

    FLD [EDI].Ball.vel_y
    FADD temp_val
    FSTP [EDI].Ball.vel_y

do_overlap_only:

    FLD BALL_DIAM
    FSUB temp_dist
    FSTP temp_overlap

    FLD temp_overlap
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE resolve_done

    FLD temp_overlap
    FMUL FP_HALF
    FMUL temp_nx
    FSTP temp_val

    FLD [ESI].Ball.pos_x
    FSUB temp_val
    FSTP [ESI].Ball.pos_x

    FLD [EDI].Ball.pos_x
    FADD temp_val
    FSTP [EDI].Ball.pos_x

    FLD temp_overlap
    FMUL FP_HALF
    FMUL temp_ny
    FSTP temp_val

    FLD [ESI].Ball.pos_y
    FSUB temp_val
    FSTP [ESI].Ball.pos_y

    FLD [EDI].Ball.pos_y
    FADD temp_val
    FSTP [EDI].Ball.pos_y

resolve_done:
    POP EBX
    RET
ResolveBallCollision ENDP

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

    FLD [ESI].Ball.pos_x
    FSUB [ESI].Ball.radius
    FCOMP TABLE_LEFT
    FNSTSW AX
    SAHF
    JA check_right

    FLD [ESI].Ball.vel_x
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_x

    FLD TABLE_LEFT
    FADD [ESI].Ball.radius
    FSTP [ESI].Ball.pos_x
    JMP check_top

check_right:

    FLD [ESI].Ball.pos_x
    FADD [ESI].Ball.radius
    FCOMP TABLE_RIGHT
    FNSTSW AX
    SAHF
    JB check_top
    JE check_top

    FLD [ESI].Ball.vel_x
    FCHS
    FMUL RESTITUTION
    FSTP [ESI].Ball.vel_x

    FLD TABLE_RIGHT
    FSUB [ESI].Ball.radius
    FSTP [ESI].Ball.pos_x

check_top:

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

    LEA EDI, pockets
    XOR EDX, EDX
cpc_check_loop:
    CMP EDX, NUM_POCKETS
    JGE cpc_ball_next

    FLD [ESI].Ball.pos_x
    FSUB [EDI].Pocket.center_x
    FSTP temp_dx

    FLD [ESI].Ball.pos_y
    FSUB [EDI].Pocket.center_y
    FSTP temp_dy

    FLD temp_dx
    FMUL temp_dx
    FLD temp_dy
    FMUL temp_dy
    FADDP ST(1), ST(0)
    FCOMP POCKET_RAD_SQ
    FNSTSW AX
    SAHF
    JA cpc_check_next

    INC gameState.balls_pocketed_this_turn

    CMP [ESI].Ball.ball_num, 0
    JNE cpc_not_cue
    MOV gameState.cue_pocketed, 1
    MOV [ESI].Ball.is_active, 0
    MOV [ESI].Ball.was_pocketed, 1
    FLDZ
    FST [ESI].Ball.vel_x
    FSTP [ESI].Ball.vel_y
    JMP cpc_ball_next

cpc_not_cue:

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

    FLD [ESI].Ball.vel_x
    FTST
    FNSTSW AX
    FSTP ST(0)
    SAHF
    JNE not_all_stopped

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

AreAllBallsStopped PROC STDCALL
    MOV EAX, gameState.all_stopped
    RET
AreAllBallsStopped ENDP

GetBallData PROC STDCALL, pOutArray:PTR REAL8
    PUSHAD
    MOV EDI, pOutArray
    LEA ESI, balls
    XOR ECX, ECX

get_ball_loop:
    CMP ECX, NUM_BALLS
    JGE get_ball_done

    PUSH ECX
    MOV ECX, 10
    PUSH ESI
    PUSH EDI
    REP MOVSD
    POP EDI
    ADD EDI, 40
    POP ESI

    FILD DWORD PTR [ESI + 40]
    FSTP REAL8 PTR [EDI]
    ADD EDI, 8

    FILD DWORD PTR [ESI + 44]
    FSTP REAL8 PTR [EDI]
    ADD EDI, 8

    FILD DWORD PTR [ESI + 48]
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

GetGameState PROC STDCALL, pOutState:PTR GameState
    PUSHAD
    MOV EDI, pOutState
    LEA ESI, gameState
    MOV ECX, SIZEOF GameState
    SHR ECX, 2
    REP MOVSD
    POPAD
    RET
GetGameState ENDP

GetTableMetrics PROC STDCALL, pOut:PTR REAL8

    PUSH EDI
    MOV EDI, pOut

    FLD TABLE_LEFT
    FSTP REAL8 PTR [EDI + 0]

    FLD TABLE_TOP
    FSTP REAL8 PTR [EDI + 8]

    FLD TABLE_RIGHT
    FSTP REAL8 PTR [EDI + 16]

    FLD TABLE_BOTTOM
    FSTP REAL8 PTR [EDI + 24]

    LEA ESI, balls
    FLD REAL8 PTR [ESI].Ball.radius
    FSTP REAL8 PTR [EDI + 32]

    LEA ESI, pockets
    FLD REAL8 PTR [ESI].Pocket.pocket_rad
    FSTP REAL8 PTR [EDI + 40]

    PUSH NUM_POCKETS
    FILD DWORD PTR [ESP]
    ADD ESP, 4
    FSTP REAL8 PTR [EDI + 48]

    POP EDI
    RET
GetTableMetrics ENDP

GetPocketData PROC STDCALL, pOut:PTR REAL8

    PUSH ESI
    PUSH EDI
    PUSH ECX

    LEA ESI, pockets
    MOV EDI, pOut
    MOV ECX, NUM_POCKETS

copia_tronera:
    FLD REAL8 PTR [ESI].Pocket.center_x
    FSTP REAL8 PTR [EDI]
    FLD REAL8 PTR [ESI].Pocket.center_y
    FSTP REAL8 PTR [EDI + 8]

    ADD ESI, SIZEOF Pocket
    ADD EDI, 16
    LOOP copia_tronera

    POP ECX
    POP EDI
    POP ESI
    RET
GetPocketData ENDP

PredictShot PROC STDCALL, angle:REAL8, pOut:PTR REAL8
    PUSHAD
    FINIT

    LEA ESI, balls
    CMP [ESI].Ball.is_active, 0
    JNE pred_white_active

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

    FLD [ESI].Ball.pos_x
    FSTP pred_cx
    FLD [ESI].Ball.pos_y
    FSTP pred_cy

    FLD angle
    FSINCOS
    FSTP pred_dx
    FSTP pred_dy

    FLD PRED_LARGE
    FSTP pred_t_min
    MOV pred_hit_idx, -1

    LEA ESI, balls
    ADD ESI, BALL_SIZE
    MOV ECX, 1

pred_loop_balls:
    CMP ECX, NUM_BALLS
    JGE pred_balls_done

    CMP [ESI].Ball.is_active, 0
    JE  pred_next_ball

    FLD [ESI].Ball.pos_x
    FSUB pred_cx
    FSTP pred_vx

    FLD [ESI].Ball.pos_y
    FSUB pred_cy
    FSTP pred_vy

    FLD pred_vx
    FMUL pred_dx
    FLD pred_vy
    FMUL pred_dy
    FADDP ST(1), ST(0)
    FSTP pred_t_proj

    FLD pred_t_proj
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_next_ball

    FLD pred_t_proj
    FCOMP pred_t_min
    FNSTSW AX
    SAHF
    JAE pred_next_ball

    FLD pred_vx
    FMUL pred_vx
    FLD pred_vy
    FMUL pred_vy
    FADDP ST(1), ST(0)

    FLD pred_t_proj
    FMUL pred_t_proj
    FSUBP ST(1), ST(0)
    FSTP pred_d2

    FLD pred_d2
    FCOMP MIN_DIST_SQ
    FNSTSW AX
    SAHF
    JA  pred_next_ball

    FLD MIN_DIST_SQ
    FSUB pred_d2
    FSQRT
    FSUBR pred_t_proj
    FSTP pred_t_hit

    FLD pred_t_hit
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JBE pred_next_ball

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

    FLD pred_dx
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JAE pred_skip_left

    FLD TABLE_LEFT
    FADD BALL_RADIUS
    FSUB pred_cx
    FDIV pred_dx
    FSTP pred_t_proj

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

    FLD pred_dx
    FMUL pred_t_min
    FADD pred_cx
    FSTP pred_impact_x

    FLD pred_dy
    FMUL pred_t_min
    FADD pred_cy
    FSTP pred_impact_y

    MOV EDI, pOut

    CMP pred_hit_idx, -1
    JE  pred_wall_out

    FLD FP_ONE
    FSTP REAL8 PTR [EDI + 0]

    FLD pred_impact_x
    FSTP REAL8 PTR [EDI + 8]
    FLD pred_impact_y
    FSTP REAL8 PTR [EDI + 16]

    FILD DWORD PTR pred_hit_idx
    FSTP REAL8 PTR [EDI + 24]

    MOV EAX, pred_hit_idx
    IMUL EAX, BALL_SIZE
    LEA ESI, balls
    ADD ESI, EAX

    FLD [ESI].Ball.pos_x
    FSUB pred_impact_x
    FDIV BALL_DIAM
    FSTP pred_nx

    FLD [ESI].Ball.pos_y
    FSUB pred_impact_y
    FDIV BALL_DIAM
    FSTP pred_ny

    FLD pred_dx
    FMUL pred_nx
    FLD pred_dy
    FMUL pred_ny
    FADDP ST(1), ST(0)
    FSTP pred_vdotn

    FLD pred_nx
    FSTP REAL8 PTR [EDI + 48]
    FLD pred_ny
    FSTP REAL8 PTR [EDI + 56]

    FLD pred_vdotn
    FMUL pred_nx
    FSUBR pred_dx
    FSTP pred_vx

    FLD pred_vdotn
    FMUL pred_ny
    FSUBR pred_dy
    FSTP pred_vy

    FLD pred_vx
    FMUL pred_vx
    FLD pred_vy
    FMUL pred_vy
    FADDP ST(1), ST(0)
    FSQRT

    FLD ST(0)
    FCOMP MIN_VELOCITY
    FNSTSW AX
    SAHF
    JA  pred_wp_normalize

    FSTP ST(0)
    FLDZ
    FST  REAL8 PTR [EDI + 32]
    FSTP REAL8 PTR [EDI + 40]
    JMP pred_done

pred_wp_normalize:

    FLD pred_vx
    FDIV ST(0), ST(1)
    FSTP REAL8 PTR [EDI + 32]

    FLD pred_vy
    FDIV ST(0), ST(1)
    FSTP REAL8 PTR [EDI + 40]

    FSTP ST(0)
    JMP pred_done

pred_wall_out:
    FLDZ
    FSTP REAL8 PTR [EDI + 0]

    FLD pred_impact_x
    FSTP REAL8 PTR [EDI + 8]
    FLD pred_impact_y
    FSTP REAL8 PTR [EDI + 16]

    FLD FP_NEGONE
    FSTP REAL8 PTR [EDI + 24]

    FLDZ
    FST  REAL8 PTR [EDI + 32]
    FST  REAL8 PTR [EDI + 40]
    FST  REAL8 PTR [EDI + 48]
    FSTP REAL8 PTR [EDI + 56]

pred_done:
    POPAD
    RET
PredictShot ENDP

EvaluateTurn PROC STDCALL
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI

    CMP gameState.eight_pocketed, 1
    JNE no_eight_pocketed

    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE player2_group_check
    MOV EBX, gameState.player1_group
    JMP check_group_count
player2_group_check:
    MOV EBX, gameState.player2_group

check_group_count:

    CMP EBX, -1
    JE eight_lose

    XOR EDX, EDX
    LEA ESI, balls
    XOR ECX, ECX
count_remaining:
    CMP ECX, NUM_BALLS
    JGE count_done
    CMP [ESI].Ball.is_active, 1
    JNE count_next
    CMP [ESI].Ball.ball_type, EBX
    JNE count_next
    INC EDX
count_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP count_remaining
count_done:

    CMP EDX, 0
    JG eight_lose

    CMP gameState.cue_pocketed, 1
    JE eight_lose
    CMP gameState.is_foul, 1
    JE eight_lose

    MOV gameState.game_phase, PHASE_GAME_OVER
    MOV EAX, gameState.current_player
    MOV gameState.winner, EAX
    MOV EAX, RESULT_WIN
    JMP evaluate_done

eight_lose:

    MOV gameState.game_phase, PHASE_GAME_OVER
    MOV EAX, gameState.current_player
    XOR EAX, 1
    MOV gameState.winner, EAX
    MOV EAX, RESULT_LOSE
    JMP evaluate_done

no_eight_pocketed:

    CMP gameState.cue_pocketed, 1
    JNE no_cue_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 1
    JMP process_foul
no_cue_foul:

    CMP gameState.first_hit_type, -1
    JNE no_miss_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 2
    JMP process_foul
no_miss_foul:

    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE get_p2_group
    MOV EBX, gameState.player1_group
    JMP check_wrong_group
get_p2_group:
    MOV EBX, gameState.player2_group
check_wrong_group:
    CMP EBX, -1
    JE no_wrong_group_foul

    XOR EDX, EDX
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
    JG must_hit_own_group

    CMP gameState.first_hit_type, TYPE_EIGHT
    JE no_wrong_group_foul
    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 4
    JMP process_foul

must_hit_own_group:

    MOV EAX, gameState.first_hit_type
    CMP EAX, EBX
    JE no_wrong_group_foul

    MOV gameState.is_foul, 1
    MOV gameState.foul_reason, 3
    JMP process_foul
no_wrong_group_foul:

    CMP gameState.game_phase, PHASE_BREAK
    JE try_assign_groups
    CMP gameState.game_phase, PHASE_OPEN_TABLE
    JE try_assign_groups
    JMP check_repeat_turn

try_assign_groups:

    CMP gameState.game_phase, PHASE_BREAK
    JNE already_open
    MOV gameState.game_phase, PHASE_OPEN_TABLE
already_open:

    CMP gameState.balls_pocketed_this_turn, 0
    JE check_repeat_turn

    LEA ESI, balls
    MOV ECX, 1
find_pocketed:
    CMP ECX, NUM_BALLS
    JGE check_repeat_turn

    MOV EAX, ECX
    IMUL EAX, BALL_SIZE
    LEA EAX, [ESI + EAX]

    CMP (Ball PTR [EAX]).was_pocketed, 1
    JNE find_next

    CMP (Ball PTR [EAX]).ball_type, TYPE_EIGHT
    JE find_next

    MOV EDX, (Ball PTR [EAX]).ball_type
    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE assign_p2
    MOV gameState.player1_group, EDX

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

no_phase_change:

    CMP gameState.balls_pocketed_this_turn, 0
    JE change_turn

    MOV EAX, gameState.current_player
    CMP EAX, 0
    JNE get_p2_grp3
    MOV EBX, gameState.player1_group
    JMP search_own_pocketed
get_p2_grp3:
    MOV EBX, gameState.player2_group
search_own_pocketed:
    CMP EBX, -1
    JE repeat_any

    LEA ESI, balls
    XOR ECX, ECX
find_own_pocketed:
    CMP ECX, NUM_BALLS
    JGE change_turn
    CMP [ESI].Ball.was_pocketed, 1
    JNE find_own_next
    CMP [ESI].Ball.ball_type, EBX
    JE found_own_pocketed
find_own_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP find_own_pocketed

found_own_pocketed:

    CALL UpdatePlayerPocketed
    MOV EAX, RESULT_REPEAT_TURN
    JMP evaluate_done

repeat_any:

    MOV EAX, RESULT_REPEAT_TURN
    JMP evaluate_done

change_turn:

    CALL UpdatePlayerPocketed
    MOV EAX, gameState.current_player
    XOR EAX, 1
    MOV gameState.current_player, EAX
    MOV EAX, RESULT_CHANGE_TURN
    JMP evaluate_done

process_foul:

    CALL UpdatePlayerPocketed

    MOV EAX, gameState.current_player
    XOR EAX, 1
    MOV gameState.current_player, EAX
    MOV EAX, RESULT_FOUL
    JMP evaluate_done

evaluate_done:

    CALL SetPhaseForCurrentPlayer
    POP EDI
    POP ESI
    POP EDX
    POP ECX
    POP EBX
    RET
EvaluateTurn ENDP

SetPhaseForCurrentPlayer PROC NEAR
    PUSH EBX
    PUSH ECX
    PUSH EDX
    PUSH ESI

    CMP gameState.game_phase, PHASE_GAME_OVER
    JE sp_done

    MOV EBX, gameState.current_player
    CMP EBX, 0
    JNE sp_use_p2
    MOV EBX, gameState.player1_group
    JMP sp_have_group
sp_use_p2:
    MOV EBX, gameState.player2_group
sp_have_group:
    CMP EBX, -1
    JE sp_done

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
    JG sp_set_normal
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

UpdatePlayerPocketed PROC NEAR
    PUSH ECX
    PUSH ESI
    PUSH EAX

    XOR EAX, EAX
    XOR EDX, EDX

    MOV ECX, 0
    MOV EAX, 0
    MOV EDX, 0
    LEA ESI, balls
count_p_loop:
    CMP ECX, NUM_BALLS
    JGE count_p_done
    CMP [ESI].Ball.is_active, 0
    JNE count_p_next
    CMP [ESI].Ball.ball_type, TYPE_SOLID
    JNE check_stripe_count
    INC EAX
    JMP count_p_next
check_stripe_count:
    CMP [ESI].Ball.ball_type, TYPE_STRIPE
    JNE count_p_next
    INC EDX
count_p_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP count_p_loop
count_p_done:

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

    ADD EAX, EDX
    MOV gameState.player1_pocketed, EAX
    MOV gameState.player2_pocketed, 0
update_p_done:
    POP EAX
    POP ESI
    POP ECX
    RET
UpdatePlayerPocketed ENDP

PlaceCueBall PROC STDCALL, new_x:REAL8, new_y:REAL8
    PUSH ECX
    PUSH EDX
    PUSH ESI
    PUSH EDI
    FINIT

    FLD new_x
    FSUB TABLE_LEFT
    FSUB BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JB place_invalid

    FLD new_x
    FSUB TABLE_RIGHT
    FADD BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JA place_invalid

    FLD new_y
    FSUB TABLE_TOP
    FSUB BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JB place_invalid

    FLD new_y
    FSUB TABLE_BOTTOM
    FADD BALL_RADIUS
    FCOMP FP_ZERO
    FNSTSW AX
    SAHF
    JA place_invalid

    LEA EDI, pockets
    XOR EDX, EDX
place_pocket_loop:
    CMP EDX, NUM_POCKETS
    JGE place_pockets_ok

    FLD new_x
    FSUB [EDI].Pocket.center_x
    FMUL ST(0), ST(0)
    FLD new_y
    FSUB [EDI].Pocket.center_y
    FMUL ST(0), ST(0)
    FADDP ST(1), ST(0)
    FCOMP POCKET_CLEAR_SQ
    FNSTSW AX
    SAHF
    JB place_invalid

    ADD EDI, POCKET_SIZE
    INC EDX
    JMP place_pocket_loop
place_pockets_ok:

    LEA ESI, balls
    ADD ESI, BALL_SIZE
    MOV ECX, 1

place_check_loop:
    CMP ECX, NUM_BALLS
    JGE place_ok

    CMP [ESI].Ball.is_active, 0
    JE place_check_next

    FLD new_x
    FSUB [ESI].Ball.pos_x
    FMUL ST(0), ST(0)

    FLD new_y
    FSUB [ESI].Ball.pos_y
    FMUL ST(0), ST(0)

    FADDP ST(1), ST(0)
    FCOMP MIN_DIST_SQ
    FNSTSW AX
    SAHF
    JA place_check_next
    JMP place_invalid

place_check_next:
    ADD ESI, BALL_SIZE
    INC ECX
    JMP place_check_loop

place_ok:

    LEA ESI, balls
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

ComputeShot PROC STDCALL, cueX:REAL8, cueY:REAL8, dragX:REAL8, dragY:REAL8, ptrX:REAL8, ptrY:REAL8, pOut:PTR REAL8
    PUSH EDI
    FINIT
    MOV EDI, pOut

    FLD ptrY
    FSUB cueY
    FLD ptrX
    FSUB cueX
    FPATAN
    FSTP REAL8 PTR [EDI + 0]

    FLD ptrX
    FSUB cueX
    FSTP cs_dx
    FLD ptrY
    FSUB cueY
    FSTP cs_dy

    FLD cs_dx
    FMUL cs_dx
    FLD cs_dy
    FMUL cs_dy
    FADDP ST(1), ST(0)
    FSQRT

    FLD ST(0)
    FCOMP FP_ONE
    FNSTSW AX
    SAHF
    JA cs_dir_ok

    FSTP ST(0)
    FLDZ
    FST  REAL8 PTR [EDI + 16]
    FSTP REAL8 PTR [EDI + 24]
    JMP cs_power

cs_dir_ok:

    FLD cs_dx
    FDIV ST(0), ST(1)
    FSTP REAL8 PTR [EDI + 16]
    FLD cs_dy
    FDIV ST(0), ST(1)
    FSTP REAL8 PTR [EDI + 24]
    FSTP ST(0)

cs_power:

    FLD ptrX
    FSUB dragX
    FSTP cs_dx
    FLD ptrY
    FSUB dragY
    FSTP cs_dy

    FLD cs_dx
    FMUL cs_dx
    FLD cs_dy
    FMUL cs_dy
    FADDP ST(1), ST(0)
    FSQRT
    FDIV POWER_FULL_DRAG

    FLD ST(0)
    FCOMP FP_ONE
    FNSTSW AX
    SAHF
    JBE cs_power_store
    FSTP ST(0)
    FLD FP_ONE
cs_power_store:
    FSTP REAL8 PTR [EDI + 8]

    POP EDI
    RET
ComputeShot ENDP

END DllMain
