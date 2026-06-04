using System;
using System.Runtime.InteropServices;

namespace BillarGUI
{

    [StructLayout(LayoutKind.Sequential)]
    public struct ShotInput
    {
        public double Angle;
        public double Power;
    }

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

    public static class GameConstants
    {

        public const int PHASE_BREAK = 0;
        public const int PHASE_OPEN_TABLE = 1;
        public const int PHASE_NORMAL = 2;
        public const int PHASE_SHOOTING_EIGHT = 3;
        public const int PHASE_GAME_OVER = 4;

        public const int TYPE_CUE = 0;
        public const int TYPE_SOLID = 1;
        public const int TYPE_STRIPE = 2;
        public const int TYPE_EIGHT = 3;

        public const int RESULT_CHANGE_TURN = 0;
        public const int RESULT_REPEAT_TURN = 1;
        public const int RESULT_FOUL = 2;
        public const int RESULT_WIN = 3;
        public const int RESULT_LOSE = 4;

        public const int NUM_BALLS = 16;
        public const int VALUES_PER_BALL = 8;
    }

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

        [DllImport(DLL, CallingConvention = CallingConvention.StdCall)]
        public static extern void ComputeShot(
            double cueX, double cueY,
            double dragX, double dragY,
            double ptrX, double ptrY,
            double[] pOut);
    }

}
