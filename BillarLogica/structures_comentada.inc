; ============================================================
; structures.inc — Definiciones de estructuras compartidas
; Billar 8-Ball · Proyecto Final OAC 2026-1
; ============================================================

; ---- Estructura de una bola ----
Ball STRUCT
    pos_x       REAL8   0.0         ; Posicion X (pixeles)
    pos_y       REAL8   0.0         ; Posicion Y (pixeles)
    vel_x       REAL8   0.0         ; Velocidad X (pixeles/frame)
    vel_y       REAL8   0.0         ; Velocidad Y (pixeles/frame)
    radius      REAL8   14.0        ; Radio (pixeles)
    ball_num    DWORD   0           ; Numero: 0=blanca,1-7=lisas,8=ocho,9-15=rayadas
    ball_type   DWORD   0           ; Tipo: 0=blanca,1=lisa,2=rayada,3=bola8
    is_active   DWORD   1           ; 1=en mesa, 0=embocada
    was_pocketed DWORD  0           ; Flag: se emboco este turno
Ball ENDS
; Tamano total: 5*8 + 4*4 = 56 bytes

; ---- Estructura de una tronera ----
Pocket STRUCT
    center_x    REAL8   0.0
    center_y    REAL8   0.0
    pocket_rad  REAL8   22.0        ; Radio de captura
Pocket ENDS
; Tamano: 24 bytes

; ---- Parametros del tiro (recibidos desde C#) ----
ShotInput STRUCT
    angle       REAL8   0.0         ; Angulo en radianes
    power       REAL8   0.0         ; Fuerza normalizada 0.0 - 1.0
ShotInput ENDS

; ---- Estado completo del juego ----
GameState STRUCT
    current_player      DWORD   0   ; 0=J1, 1=J2
    player1_group       DWORD   -1  ; -1=sin asignar, 1=lisas, 2=rayadas
    player2_group       DWORD   -1
    player1_pocketed    DWORD   0   ; Bolas embocadas por J1
    player2_pocketed    DWORD   0
    game_phase          DWORD   0   ; 0=break,1=open,2=normal,3=shooting8,4=gameover
    is_foul             DWORD   0
    foul_reason         DWORD   0
    winner              DWORD   -1  ; -1=nadie, 0=J1, 1=J2
    all_stopped         DWORD   1
    first_hit_type      DWORD   -1  ; Tipo de primera bola golpeada por la blanca
    cue_pocketed        DWORD   0
    eight_pocketed      DWORD   0
    balls_pocketed_this_turn DWORD 0
GameState ENDS

; ---- Constantes de tamano ----
NUM_BALLS   EQU 16
NUM_POCKETS EQU 6
BALL_SIZE   EQU SIZEOF Ball         ; 56
POCKET_SIZE EQU SIZEOF Pocket       ; 24

; ---- Fases del juego ----
PHASE_BREAK         EQU 0
PHASE_OPEN_TABLE    EQU 1
PHASE_NORMAL        EQU 2
PHASE_SHOOTING_EIGHT EQU 3
PHASE_GAME_OVER     EQU 4

; ---- Tipos de bola ----
TYPE_CUE    EQU 0
TYPE_SOLID  EQU 1
TYPE_STRIPE EQU 2
TYPE_EIGHT  EQU 3

; ---- Codigos de retorno de EvaluateTurn ----
RESULT_CHANGE_TURN  EQU 0
RESULT_REPEAT_TURN  EQU 1
RESULT_FOUL         EQU 2
RESULT_WIN          EQU 3
RESULT_LOSE         EQU 4