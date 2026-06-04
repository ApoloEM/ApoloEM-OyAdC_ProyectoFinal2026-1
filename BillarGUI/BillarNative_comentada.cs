// ============================================================
// BillarNative.cs — Declaraciones P/Invoke para BillarLogica.dll
// ============================================================
using System;
using System.Runtime.InteropServices;

namespace BillarGUI
{
    // ---- Estructura para pasar parametros del tiro ----
    [StructLayout(LayoutKind.Sequential)]
    public struct ShotInput
    {
        public double Angle;
        public double Power;
    }

    // ---- Estado del juego (espejo de la estructura MASM) ----
    [StructLayout(LayoutKind.Sequential)]
    public struct GameStateManaged
    {
        public int CurrentPlayer;
        public int Player1Group;
        public int Player2Group;
        public int Player1Pocketed;
        public int Player2Pocketed;
        public int GamePhase;
        public int IsFoul;
        public int FoulReason;
        public int Winner;
        public int AllStopped;
        public int FirstHitType;
        public int CuePocketed;
        public int EightPocketed;
        public int BallsPocketedThisTurn;
    }

    // ---- Constantes de fases y resultados ----
    public static class GameConstants
    {
        // Fases del juego
        public const int PHASE_BREAK = 0;
        public const int PHASE_OPEN_TABLE = 1;
        public const int PHASE_NORMAL = 2;
        public const int PHASE_SHOOTING_EIGHT = 3;
        public const int PHASE_GAME_OVER = 4;

        // Tipos de bola
        public const int TYPE_CUE = 0;
        public const int TYPE_SOLID = 1;
        public const int TYPE_STRIPE = 2;
        public const int TYPE_EIGHT = 3;

        // Resultados de EvaluateTurn
        public const int RESULT_CHANGE_TURN = 0;
        public const int RESULT_REPEAT_TURN = 1;
        public const int RESULT_FOUL = 2;
        public const int RESULT_WIN = 3;
        public const int RESULT_LOSE = 4;

        // Las dimensiones de la mesa y el radio de bola NO se duplican aqui:
        // son una sola fuente de verdad en MASM y se leen en tiempo de
        // ejecucion con GetTableMetrics() (ver LoadTableGeometry).

        // Cantidad
        public const int NUM_BALLS = 16;
        public const int VALUES_PER_BALL = 8;
    }

    // ---- Importaciones de la DLL ----
    internal static class BillarNative
    {
        private const string DLL = "BillarLogica.dll";

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void InitGame();

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void UpdatePhysics();

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void ApplyShot(ref ShotInput shot);

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void GetBallData([Out] double[] buffer);

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void GetGameState(out GameStateManaged state);

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern int AreAllBallsStopped();

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern int EvaluateTurn();

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern int PlaceCueBall(double newX, double newY);

        [DllImport("BillarLogica.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void GetTableMetrics(double[] pOut);

        [DllImport("BillarLogica.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void GetPocketData(double[] pOut);

        [DllImport("BillarLogica.dll", CallingConvention = CallingConvention.StdCall)]
        public static extern void PredictShot(double angle, double[] pOut);

        // Traduce el gesto del jugador (blanca, inicio de arrastre, puntero)
        // en parametros de tiro. pOut: [angle, power, aimDirX, aimDirY].
        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void ComputeShot(
            double cueX, double cueY,
            double dragX, double dragY,
            double ptrX, double ptrY,
            double[] pOut);
    }

}