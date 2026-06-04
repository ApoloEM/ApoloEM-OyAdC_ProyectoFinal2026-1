Ball STRUCT
    pos_x       REAL8   0.0
    pos_y       REAL8   0.0
    vel_x       REAL8   0.0
    vel_y       REAL8   0.0
    radius      REAL8   14.0
    ball_num    DWORD   0
    ball_type   DWORD   0
    is_active   DWORD   1
    was_pocketed DWORD  0
Ball ENDS

Pocket STRUCT
    center_x    REAL8   0.0
    center_y    REAL8   0.0
    pocket_rad  REAL8   22.0
Pocket ENDS

ShotInput STRUCT
    angle       REAL8   0.0
    power       REAL8   0.0
ShotInput ENDS

GameState STRUCT
    current_player      DWORD   0
    player1_group       DWORD   -1
    player2_group       DWORD   -1
    player1_pocketed    DWORD   0
    player2_pocketed    DWORD   0
    game_phase          DWORD   0
    is_foul             DWORD   0
    foul_reason         DWORD   0
    winner              DWORD   -1
    all_stopped         DWORD   1
    first_hit_type      DWORD   -1
    cue_pocketed        DWORD   0
    eight_pocketed      DWORD   0
    balls_pocketed_this_turn DWORD 0
GameState ENDS

NUM_BALLS   EQU 16
NUM_POCKETS EQU 6
BALL_SIZE   EQU SIZEOF Ball
POCKET_SIZE EQU SIZEOF Pocket

PHASE_BREAK         EQU 0
PHASE_OPEN_TABLE    EQU 1
PHASE_NORMAL        EQU 2
PHASE_SHOOTING_EIGHT EQU 3
PHASE_GAME_OVER     EQU 4

TYPE_CUE    EQU 0
TYPE_SOLID  EQU 1
TYPE_STRIPE EQU 2
TYPE_EIGHT  EQU 3

RESULT_CHANGE_TURN  EQU 0
RESULT_REPEAT_TURN  EQU 1
RESULT_FOUL         EQU 2
RESULT_WIN          EQU 3
RESULT_LOSE         EQU 4
