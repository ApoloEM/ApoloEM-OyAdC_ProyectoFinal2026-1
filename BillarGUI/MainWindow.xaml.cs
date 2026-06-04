using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace BillarGUI
{
    public partial class MainWindow : Window
    {
        private enum AppState
        {
            Aiming, Charging, Simulating, BallInHand, GameOver
        }

        private AppState _appState = AppState.Aiming;
        private bool _gameStarted;

        private int _lastSeenPlayer = -1;
        private int _lastSeenP1Group = -2;
        private int _lastSeenP2Group = -2;
        private int _lastSeenPhase = -1;

        private string _player1Name = "Jugador 1";
        private string _player2Name = "Jugador 2";

        private BallVisual[] _ballVisuals = null!;
        private double[] _ballDataBuffer = null!;
        private GameStateManaged _gameState;

        private Line _cueStick = null!;
        private Line _preLine = null!;
        private Ellipse _ghostBall = null!;
        private Line _whitePostLine = null!;
        private Line _targetPostLine = null!;
        private Ellipse[] _pocketVisuals = null!;
        private readonly double[] _predBuf = new double[8];
        private readonly double[] _shotBuf = new double[4];
        private const double POST_LINE_LENGTH = 90.0;

        private double _aimAngle;
        private double _shotPower;
        private Point _mousePos;
        private Point _chargeStartPos;

        private double _tableLeft, _tableTop, _tableRight, _tableBottom;
        private double _ballRadius, _pocketRadius;
        private readonly double[] _pocketCoords = new double[12];

        private const double FRAME_MARGIN = 22;

        private Storyboard _toastAnim = null!;

        public MainWindow()
        {
            InitializeComponent();

            _toastAnim = (Storyboard)FindResource("ToastAnimation");
            _ballDataBuffer = new double[GameConstants.NUM_BALLS * GameConstants.VALUES_PER_BALL];

            try
            {
                BillarNative.InitGame();
                LoadTableGeometry();
                SetupTableVisuals();
            }
            catch (DllNotFoundException)
            {
                MessageBox.Show(
                    "No se encontro BillarLogica.dll.\n\nAsegurate de que la DLL este " +
                    "en la misma carpeta que el ejecutable.\nCompila primero el proyecto " +
                    "BillarLogica.",
                    "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            CreateBalls();
            CreateAimingVisuals();
            ReadBallPositions();
            UpdateUI();

            CompositionTarget.Rendering += OnGameFrame;
        }

        private void LoadTableGeometry()
        {
            var metrics = new double[7];
            BillarNative.GetTableMetrics(metrics);
            _tableLeft = metrics[0];
            _tableTop = metrics[1];
            _tableRight = metrics[2];
            _tableBottom = metrics[3];
            _ballRadius = metrics[4];
            _pocketRadius = metrics[5];

            BillarNative.GetPocketData(_pocketCoords);
        }

        private double PhysicsToCanvasX(double physX) => physX - _tableLeft + FRAME_MARGIN;
        private double PhysicsToCanvasY(double physY) => physY - _tableTop + FRAME_MARGIN;
        private double CanvasToPhysicsX(double canvasX) => canvasX + _tableLeft - FRAME_MARGIN;
        private double CanvasToPhysicsY(double canvasY) => canvasY + _tableTop - FRAME_MARGIN;

        private void SetupTableVisuals()
        {
            double feltWidth = _tableRight - _tableLeft;
            double feltHeight = _tableBottom - _tableTop;

            GameCanvas.Width = feltWidth + 2 * FRAME_MARGIN;
            GameCanvas.Height = feltHeight + 2 * FRAME_MARGIN;

            Canvas.SetLeft(FieltroRect, FRAME_MARGIN);
            Canvas.SetTop(FieltroRect, FRAME_MARGIN);
            FieltroRect.Width = feltWidth;
            FieltroRect.Height = feltHeight;

            CreateDiamonds();
            CreatePockets();
        }

        private void CreateDiamonds()
        {
            DiamondLayer.Children.Clear();

            const double diamondHalf = 3.5;
            double cw = GameCanvas.Width;
            double ch = GameCanvas.Height;
            double midTop = FRAME_MARGIN / 2.0;
            double midBottom = ch - FRAME_MARGIN / 2.0;
            double midLeft = FRAME_MARGIN / 2.0;
            double midRight = cw - FRAME_MARGIN / 2.0;

            double leftPx = PhysicsToCanvasX(_pocketCoords[0]);
            double midPx = PhysicsToCanvasX(_pocketCoords[2]);
            double rightPx = PhysicsToCanvasX(_pocketCoords[4]);
            double topPy = PhysicsToCanvasY(_pocketCoords[1]);
            double botPy = PhysicsToCanvasY(_pocketCoords[7]);

            AddDiamondRow(leftPx, midPx, midTop, diamondHalf);
            AddDiamondRow(midPx, rightPx, midTop, diamondHalf);
            AddDiamondRow(leftPx, midPx, midBottom, diamondHalf);
            AddDiamondRow(midPx, rightPx, midBottom, diamondHalf);

            double midY = (topPy + botPy) / 2.0;
            AddDiamond(midLeft, midY, diamondHalf);
            AddDiamond(midRight, midY, diamondHalf);
        }

        private void AddDiamondRow(double x1, double x2, double y, double half)
        {
            for (int i = 1; i <= 3; i++)
            {
                double t = i / 4.0;
                double x = x1 + (x2 - x1) * t;
                AddDiamond(x, y, half);
            }
        }

        private void AddDiamond(double cx, double cy, double half)
        {
            var diamond = new Polygon
            {
                Points = new PointCollection
                {
                    new Point(cx,         cy - half),
                    new Point(cx + half,  cy),
                    new Point(cx,         cy + half),
                    new Point(cx - half,  cy),
                },
                Fill = new SolidColorBrush(Color.FromArgb(220, 212, 166, 66)),
                IsHitTestVisible = false,
            };
            DiamondLayer.Children.Add(diamond);
        }

        private void CreatePockets()
        {
            _pocketVisuals = new Ellipse[6];
            PocketLayer.Children.Clear();

            for (int i = 0; i < 6; i++)
            {
                double pxPhys = _pocketCoords[i * 2];
                double pyPhys = _pocketCoords[i * 2 + 1];

                var pocket = new Ellipse
                {
                    Width = _pocketRadius * 2,
                    Height = _pocketRadius * 2,
                    Fill = Brushes.Black,
                };
                Canvas.SetLeft(pocket, PhysicsToCanvasX(pxPhys) - _pocketRadius);
                Canvas.SetTop(pocket, PhysicsToCanvasY(pyPhys) - _pocketRadius);
                Panel.SetZIndex(pocket, 1);
                PocketLayer.Children.Add(pocket);
                _pocketVisuals[i] = pocket;
            }
        }

        private void CreateBalls()
        {
            BillarNative.GetBallData(_ballDataBuffer);
            _ballVisuals = new BallVisual[GameConstants.NUM_BALLS];

            for (int i = 0; i < GameConstants.NUM_BALLS; i++)
            {
                int offset = i * GameConstants.VALUES_PER_BALL;
                int ballNum = (int)_ballDataBuffer[offset + 5];
                int ballType = (int)_ballDataBuffer[offset + 6];

                var bv = new BallVisual(ballNum, ballType, _ballRadius);
                bv.AddToCanvas(GameCanvas);
                _ballVisuals[i] = bv;
            }
        }

        private void CreateAimingVisuals()
        {
            _preLine = new Line
            {
                Stroke = new SolidColorBrush(Color.FromArgb(180, 255, 255, 255)),
                StrokeThickness = 2,
                StrokeDashArray = new DoubleCollection { 6, 4 },
                Visibility = Visibility.Collapsed,
            };
            Panel.SetZIndex(_preLine, 5);
            GameCanvas.Children.Add(_preLine);

            _ghostBall = new Ellipse
            {
                Width = _ballRadius * 2,
                Height = _ballRadius * 2,
                Stroke = new SolidColorBrush(Color.FromArgb(200, 255, 255, 255)),
                StrokeThickness = 1.5,
                Fill = Brushes.Transparent,
                Visibility = Visibility.Collapsed,
            };
            Panel.SetZIndex(_ghostBall, 6);
            GameCanvas.Children.Add(_ghostBall);

            _whitePostLine = new Line
            {
                Stroke = new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)),
                StrokeThickness = 2,
                Visibility = Visibility.Collapsed,
            };
            Panel.SetZIndex(_whitePostLine, 7);
            GameCanvas.Children.Add(_whitePostLine);

            _targetPostLine = new Line
            {
                Stroke = new SolidColorBrush(Color.FromArgb(220, 241, 196, 15)),
                StrokeThickness = 2,
                Visibility = Visibility.Collapsed,
            };
            Panel.SetZIndex(_targetPostLine, 7);
            GameCanvas.Children.Add(_targetPostLine);

            _cueStick = new Line
            {
                Stroke = new LinearGradientBrush(
                    Color.FromRgb(180, 140, 80),
                    Color.FromRgb(100, 60, 20),
                    new Point(0, 0), new Point(1, 0)),
                StrokeThickness = 5,
                StrokeStartLineCap = PenLineCap.Round,
                StrokeEndLineCap = PenLineCap.Flat,
                Visibility = Visibility.Collapsed,
            };
            Panel.SetZIndex(_cueStick, 20);
            GameCanvas.Children.Add(_cueStick);
        }

        private void HidePrediction()
        {
            _preLine.Visibility = Visibility.Collapsed;
            _ghostBall.Visibility = Visibility.Collapsed;
            _whitePostLine.Visibility = Visibility.Collapsed;
            _targetPostLine.Visibility = Visibility.Collapsed;
        }

        private void OnGameFrame(object? sender, EventArgs e)
        {
            if (MenuOverlay.Visibility == Visibility.Visible)
                return;

            if (_appState == AppState.Simulating)
            {
                BillarNative.UpdatePhysics();
                ReadBallPositions();

                if (BillarNative.AreAllBallsStopped() == 1)
                {
                    OnSimulationEnd();
                }
            }
            else if (_appState == AppState.Aiming || _appState == AppState.Charging)
            {
                UpdateCueVisual();
            }
        }

        private void ReadBallPositions()
        {
            BillarNative.GetBallData(_ballDataBuffer);

            for (int i = 0; i < GameConstants.NUM_BALLS; i++)
            {
                int offset = i * GameConstants.VALUES_PER_BALL;
                double px = _ballDataBuffer[offset + 0];
                double py = _ballDataBuffer[offset + 1];
                double isActive = _ballDataBuffer[offset + 7];

                _ballVisuals[i].UpdatePosition(PhysicsToCanvasX(px), PhysicsToCanvasY(py));
                _ballVisuals[i].SetVisible(isActive > 0.5);
            }
        }

        private void GameCanvas_MouseMove(object sender, MouseEventArgs e)
        {
            _mousePos = e.GetPosition(GameCanvas);

            if (_appState == AppState.BallInHand)
            {

                _ballVisuals[0].SetVisible(true);
                _ballVisuals[0].UpdatePosition(_mousePos.X, _mousePos.Y);
                return;
            }

            if (_appState == AppState.Charging)
            {

                double cuePx = PhysicsToCanvasX(_ballDataBuffer[0]);
                double cuePy = PhysicsToCanvasY(_ballDataBuffer[1]);
                BillarNative.ComputeShot(cuePx, cuePy,
                    _chargeStartPos.X, _chargeStartPos.Y,
                    _mousePos.X, _mousePos.Y, _shotBuf);
                _shotPower = _shotBuf[1];
                UpdatePowerBar(_shotPower);
            }
        }

        private void GameCanvas_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
        {
            _mousePos = e.GetPosition(GameCanvas);

            if (_appState == AppState.BallInHand)
            {
                double mx = CanvasToPhysicsX(_mousePos.X);
                double my = CanvasToPhysicsY(_mousePos.Y);

                int result = BillarNative.PlaceCueBall(mx, my);
                if (result == 1)
                {
                    _appState = AppState.Aiming;
                    ReadBallPositions();
                    MessageText.Text = "Bola colocada. Apunta y tira.";
                }
                else
                {
                    MessageText.Text = "Posicion invalida: coloca la blanca sobre el pano, " +
                                       "sin troneras ni otras bolas.";
                }
                return;
            }

            if (_appState == AppState.Aiming)
            {
                double cuePx = PhysicsToCanvasX(_ballDataBuffer[0]);
                double cuePy = PhysicsToCanvasY(_ballDataBuffer[1]);

                _chargeStartPos = _mousePos;
                _shotPower = 0;
                _appState = AppState.Charging;

                BillarNative.ComputeShot(cuePx, cuePy,
                    _chargeStartPos.X, _chargeStartPos.Y,
                    _mousePos.X, _mousePos.Y, _shotBuf);
                _aimAngle = _shotBuf[0];
                UpdatePowerBar(0);
            }
        }

        private void GameCanvas_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
        {
            if (_appState == AppState.Charging && _shotPower > 0.02)
            {
                var shot = new ShotInput
                {
                    Angle = _aimAngle,
                    Power = _shotPower
                };
                BillarNative.ApplyShot(ref shot);

                _appState = AppState.Simulating;
                _gameStarted = true;
                _cueStick.Visibility = Visibility.Collapsed;
                HidePrediction();
                UpdatePowerBar(0);
                MessageText.Text = "Bolas en movimiento...";
            }
            else if (_appState == AppState.Charging)
            {
                _appState = AppState.Aiming;
                UpdatePowerBar(0);
            }
        }

        private void GameCanvas_MouseRightButtonDown(object sender, MouseButtonEventArgs e)
        {
            if (_appState == AppState.Charging)
            {
                _appState = AppState.Aiming;
                _shotPower = 0;
                UpdatePowerBar(0);
            }
        }

        private void UpdateCueVisual()
        {
            double cuePx = PhysicsToCanvasX(_ballDataBuffer[0]);
            double cuePy = PhysicsToCanvasY(_ballDataBuffer[1]);

            if (_appState != AppState.Aiming && _appState != AppState.Charging)
            {
                _cueStick.Visibility = Visibility.Collapsed;
                HidePrediction();
                return;
            }

            BillarNative.ComputeShot(cuePx, cuePy,
                _chargeStartPos.X, _chargeStartPos.Y,
                _mousePos.X, _mousePos.Y, _shotBuf);
            double nx = _shotBuf[2];
            double ny = _shotBuf[3];
            if (nx == 0 && ny == 0) return;

            _aimAngle = _shotBuf[0];

            BillarNative.PredictShot(_aimAngle, _predBuf);
            int type = (int)Math.Round(_predBuf[0]);

            if (type < 0)
            {
                HidePrediction();
            }
            else
            {
                double impactPx = PhysicsToCanvasX(_predBuf[1]);
                double impactPy = PhysicsToCanvasY(_predBuf[2]);

                _preLine.X1 = cuePx;
                _preLine.Y1 = cuePy;
                _preLine.X2 = impactPx;
                _preLine.Y2 = impactPy;
                _preLine.Visibility = Visibility.Visible;

                if (type == 1)
                {
                    Canvas.SetLeft(_ghostBall, impactPx - _ballRadius);
                    Canvas.SetTop(_ghostBall, impactPy - _ballRadius);
                    _ghostBall.Visibility = Visibility.Visible;

                    double wdx = _predBuf[4];
                    double wdy = _predBuf[5];
                    _whitePostLine.X1 = impactPx;
                    _whitePostLine.Y1 = impactPy;
                    _whitePostLine.X2 = impactPx + wdx * POST_LINE_LENGTH;
                    _whitePostLine.Y2 = impactPy + wdy * POST_LINE_LENGTH;
                    _whitePostLine.Visibility = Visibility.Visible;

                    int hitIdx = (int)Math.Round(_predBuf[3]);
                    if (hitIdx >= 1 && hitIdx < GameConstants.NUM_BALLS)
                    {
                        int offset = hitIdx * GameConstants.VALUES_PER_BALL;
                        double tx = PhysicsToCanvasX(_ballDataBuffer[offset + 0]);
                        double ty = PhysicsToCanvasY(_ballDataBuffer[offset + 1]);
                        double tdx = _predBuf[6];
                        double tdy = _predBuf[7];
                        _targetPostLine.X1 = tx;
                        _targetPostLine.Y1 = ty;
                        _targetPostLine.X2 = tx + tdx * POST_LINE_LENGTH;
                        _targetPostLine.Y2 = ty + tdy * POST_LINE_LENGTH;
                        _targetPostLine.Visibility = Visibility.Visible;
                    }
                    else
                    {
                        _targetPostLine.Visibility = Visibility.Collapsed;
                    }
                }
                else
                {
                    _ghostBall.Visibility = Visibility.Collapsed;
                    _whitePostLine.Visibility = Visibility.Collapsed;
                    _targetPostLine.Visibility = Visibility.Collapsed;
                }
            }

            double cueOffset = 20 + (_shotPower * 60);
            double cueLength = 180;
            _cueStick.X1 = cuePx - nx * cueOffset;
            _cueStick.Y1 = cuePy - ny * cueOffset;
            _cueStick.X2 = cuePx - nx * (cueOffset + cueLength);
            _cueStick.Y2 = cuePy - ny * (cueOffset + cueLength);
            _cueStick.Visibility = Visibility.Visible;
        }

        private void UpdatePowerBar(double power)
        {
            int percent = (int)Math.Round(power * 100);
            PowerPercentText.Text = percent + "%";

            if (percent >= 80)
                PowerPercentText.Foreground = new SolidColorBrush(Color.FromRgb(231, 76, 60));
            else if (percent >= 50)
                PowerPercentText.Foreground = new SolidColorBrush(Color.FromRgb(241, 196, 15));
            else if (percent > 0)
                PowerPercentText.Foreground = new SolidColorBrush(Color.FromRgb(46, 204, 113));
            else
                PowerPercentText.Foreground = new SolidColorBrush(Color.FromRgb(189, 195, 199));

            double maxHeight = PowerBarContainer.ActualHeight;
            if (maxHeight > 0)
                PowerBarFill.Height = maxHeight * power;
            else
                PowerBarFill.Height = 120 * power;
        }

        private void OnSimulationEnd()
        {
            int prevPlayer = _lastSeenPlayer;
            int prevP1Group = _lastSeenP1Group;
            int prevPhase = _lastSeenPhase;

            int result = BillarNative.EvaluateTurn();
            BillarNative.GetGameState(out _gameState);

            switch (result)
            {
                case GameConstants.RESULT_CHANGE_TURN:
                    _appState = AppState.Aiming;
                    MessageText.Text = $"Cambio de turno. Tira {GetActiveName()}.";
                    break;

                case GameConstants.RESULT_REPEAT_TURN:
                    _appState = AppState.Aiming;
                    MessageText.Text = $"Bola embocada. {GetActiveName()} tira de nuevo.";
                    break;

                case GameConstants.RESULT_FOUL:
                    _appState = AppState.BallInHand;
                    string foulMsg = _gameState.FoulReason switch
                    {
                        1 => "Scratch (bola blanca embocada)",
                        2 => "La blanca no golpeo ninguna bola",
                        3 => "No golpeaste primero una bola de tu grupo",
                        4 => "No golpeaste la bola 8 primero",
                        _ => "Foul"
                    };
                    MessageText.Text = $"FOUL: {foulMsg}. {GetActiveName()} coloca la blanca.";
                    ShowToast("FOUL", foulMsg);
                    break;

                case GameConstants.RESULT_WIN:
                    _appState = AppState.GameOver;
                    MessageText.Text = $"¡VICTORIA! {GetWinnerName()} gana la partida!";
                    ShowToast("¡VICTORIA!", $"{GetWinnerName()} gana la partida");
                    break;

                case GameConstants.RESULT_LOSE:
                    _appState = AppState.GameOver;
                    MessageText.Text = $"FIN DE LA PARTIDA. Gana {GetWinnerName()}.";
                    ShowToast("FIN DE LA PARTIDA", $"Gana {GetWinnerName()}");
                    break;
            }

            UpdateUI();

            if (prevP1Group < 0 && _gameState.Player1Group >= 0 &&
                _gameState.Player1Group != GameConstants.TYPE_EIGHT)
            {
                string g1 = _gameState.Player1Group == GameConstants.TYPE_SOLID ? "LISAS" : "RAYADAS";
                string g2 = _gameState.Player2Group == GameConstants.TYPE_SOLID ? "LISAS" : "RAYADAS";
                ShowToast("GRUPOS ASIGNADOS",
                    $"{_player1Name}: {g1}   ·   {_player2Name}: {g2}");
            }
            else if (result == GameConstants.RESULT_CHANGE_TURN && prevPlayer != _gameState.CurrentPlayer)
            {
                ShowToast($"TURNO DE {GetActiveName().ToUpper()}", "");
            }
            else if (prevPhase != GameConstants.PHASE_SHOOTING_EIGHT &&
                     _gameState.GamePhase == GameConstants.PHASE_SHOOTING_EIGHT)
            {
                ShowToast("¡A POR LA 8!", $"{GetActiveName()} debe embocar la bola 8");
            }

            _lastSeenPlayer = _gameState.CurrentPlayer;
            _lastSeenP1Group = _gameState.Player1Group;
            _lastSeenP2Group = _gameState.Player2Group;
            _lastSeenPhase = _gameState.GamePhase;
        }

        private string GetActiveName() =>
            _gameState.CurrentPlayer == 0 ? _player1Name : _player2Name;

        private string GetWinnerName() =>
            _gameState.Winner == 0 ? _player1Name :
            _gameState.Winner == 1 ? _player2Name : "?";

        private void UpdateUI()
        {
            BillarNative.GetGameState(out _gameState);

            Player1Score.Text = $"{_gameState.Player1Pocketed}/7";
            Player2Score.Text = $"{_gameState.Player2Pocketed}/7";

            UpdateGroupIndicator(_gameState.Player1Group, P1GroupBall);
            UpdateGroupIndicator(_gameState.Player2Group, P2GroupBall);

            HighlightActivePlayer(_gameState.CurrentPlayer);

            string phase = _gameState.GamePhase switch
            {
                GameConstants.PHASE_BREAK => "QUIEBRE",
                GameConstants.PHASE_OPEN_TABLE => "MESA ABIERTA",
                GameConstants.PHASE_NORMAL => "EN JUEGO",
                GameConstants.PHASE_SHOOTING_EIGHT => "BOLA 8",
                GameConstants.PHASE_GAME_OVER => "FIN",
                _ => ""
            };

            string p1Group = _gameState.Player1Group switch
            {
                GameConstants.TYPE_SOLID => "Lisas",
                GameConstants.TYPE_STRIPE => "Rayadas",
                _ => ""
            };
            string p2Group = _gameState.Player2Group switch
            {
                GameConstants.TYPE_SOLID => "Lisas",
                GameConstants.TYPE_STRIPE => "Rayadas",
                _ => ""
            };

            P1Status.Text = (_gameState.CurrentPlayer == 0)
                ? (string.IsNullOrEmpty(p1Group) ? phase : $"{p1Group} · {phase}")
                : p1Group;
            P2Status.Text = (_gameState.CurrentPlayer == 1)
                ? (string.IsNullOrEmpty(p2Group) ? phase : $"{p2Group} · {phase}")
                : p2Group;
        }

        private void UpdateGroupIndicator(int group, Ellipse ball)
        {
            if (group < 0 || group == GameConstants.TYPE_EIGHT)
            {
                ball.Visibility = Visibility.Collapsed;
                return;
            }

            ball.Visibility = Visibility.Visible;

            Color baseColor = group == GameConstants.TYPE_SOLID
                ? Color.FromRgb(247, 197, 25)
                : Color.FromRgb(28, 101, 192);

            if (group == GameConstants.TYPE_SOLID)
            {
                var brush = new RadialGradientBrush
                {
                    GradientOrigin = new Point(0.32, 0.30),
                    Center = new Point(0.32, 0.30),
                    RadiusX = 0.85,
                    RadiusY = 0.85,
                };
                brush.GradientStops.Add(new GradientStop(Colors.White, 0));
                brush.GradientStops.Add(new GradientStop(baseColor, 0.55));
                brush.GradientStops.Add(new GradientStop(Color.FromRgb(80, 65, 10), 1));
                ball.Fill = brush;
            }
            else
            {

                var stripe = new LinearGradientBrush
                {
                    StartPoint = new Point(0, 0),
                    EndPoint = new Point(0, 1),
                };
                stripe.GradientStops.Add(new GradientStop(Colors.White, 0.0));
                stripe.GradientStops.Add(new GradientStop(Colors.White, 0.40));
                stripe.GradientStops.Add(new GradientStop(baseColor, 0.42));
                stripe.GradientStops.Add(new GradientStop(baseColor, 0.58));
                stripe.GradientStops.Add(new GradientStop(Colors.White, 0.60));
                stripe.GradientStops.Add(new GradientStop(Colors.White, 1.0));
                ball.Fill = stripe;
            }
        }

        private void HighlightActivePlayer(int activePlayer)
        {
            var activeBorder = new SolidColorBrush(Color.FromRgb(46, 204, 113));
            var inactiveBorder = new SolidColorBrush(Color.FromRgb(93, 58, 26));

            var activeArrowBg = new SolidColorBrush(Color.FromRgb(31, 79, 42));
            var activeArrowFg = new SolidColorBrush(Color.FromRgb(46, 204, 113));
            var activeArrowBorder = new SolidColorBrush(Color.FromRgb(46, 204, 113));

            var inactiveArrowBg = new SolidColorBrush(Color.FromRgb(93, 58, 26));
            var inactiveArrowFg = new SolidColorBrush(Color.FromRgb(139, 120, 85));
            var inactiveArrowBorder = new SolidColorBrush(Color.FromRgb(139, 90, 43));

            P1Border.BorderBrush = (activePlayer == 0) ? activeBorder : inactiveBorder;
            P2Border.BorderBrush = (activePlayer == 1) ? activeBorder : inactiveBorder;

            TurnLeftBox.Background = (activePlayer == 0) ? activeArrowBg : inactiveArrowBg;
            TurnLeftBox.BorderBrush = (activePlayer == 0) ? activeArrowBorder : inactiveArrowBorder;
            TurnLeftArrow.Foreground = (activePlayer == 0) ? activeArrowFg : inactiveArrowFg;

            TurnRightBox.Background = (activePlayer == 1) ? activeArrowBg : inactiveArrowBg;
            TurnRightBox.BorderBrush = (activePlayer == 1) ? activeArrowBorder : inactiveArrowBorder;
            TurnRightArrow.Foreground = (activePlayer == 1) ? activeArrowFg : inactiveArrowFg;

            CenterBallGlow.Opacity = (_gameState.GamePhase == GameConstants.PHASE_GAME_OVER) ? 0 : 0.5;
        }

        private void ShowToast(string title, string subtitle)
        {
            ToastTitle.Text = title;
            ToastSubtitle.Text = subtitle;
            ToastSubtitle.Visibility = string.IsNullOrEmpty(subtitle)
                ? Visibility.Collapsed
                : Visibility.Visible;

            _toastAnim.Stop(this);
            _toastAnim.Begin(this, true);
        }

        private void RestartButton_Click(object sender, RoutedEventArgs e) => DoRestart();

        private void DoRestart()
        {
            foreach (var bv in _ballVisuals)
                bv.RemoveFromCanvas(GameCanvas);

            BillarNative.InitGame();
            CreateBalls();
            ReadBallPositions();

            _appState = AppState.Aiming;
            _shotPower = 0;
            _gameStarted = false;
            _lastSeenPlayer = -1;
            _lastSeenP1Group = -2;
            _lastSeenP2Group = -2;
            _lastSeenPhase = -1;

            UpdatePowerBar(0);
            HidePrediction();
            MessageText.Text = $"Nueva partida. {_player1Name} realiza el quiebre.";
            UpdateUI();

            ShowToast("NUEVA PARTIDA", $"{_player1Name} realiza el quiebre");
        }

        private void MenuButton_Click(object sender, RoutedEventArgs e) => ShowMenu();

        private void RefreshMenuButtons()
        {
            if (_gameStarted)
            {
                BtnStart.Content = "▶   REGRESAR A LA PARTIDA";
                BtnRestartFromMenu.Visibility = Visibility.Visible;
                NamesPanel.Visibility = Visibility.Collapsed;
            }
            else
            {
                BtnStart.Content = "▶   INICIAR PARTIDA";
                BtnRestartFromMenu.Visibility = Visibility.Collapsed;
                NamesPanel.Visibility = Visibility.Visible;
                P1NameInput.Text = _player1Name;
                P2NameInput.Text = _player2Name;
            }
        }

        private void CommitPlayerNames()
        {
            string n1 = (P1NameInput.Text ?? "").Trim();
            string n2 = (P2NameInput.Text ?? "").Trim();
            _player1Name = string.IsNullOrEmpty(n1) ? "Jugador 1" : n1;
            _player2Name = string.IsNullOrEmpty(n2) ? "Jugador 2" : n2;

            Player1Label.Text = _player1Name.ToUpper();
            Player2Label.Text = _player2Name.ToUpper();
        }

        private void BtnStart_Click(object sender, RoutedEventArgs e)
        {
            if (!_gameStarted)
            {
                CommitPlayerNames();
                MessageText.Text = $"{_player1Name} realiza el quiebre.";
            }
            MenuOverlay.Visibility = Visibility.Collapsed;
        }

        private void BtnRestartFromMenu_Click(object sender, RoutedEventArgs e)
        {
            DoRestart();
            MenuOverlay.Visibility = Visibility.Collapsed;
        }

        private void BtnCredits_Click(object sender, RoutedEventArgs e)
        {
            MenuMainBorder.Visibility = Visibility.Collapsed;
            CreditsPanel.Visibility = Visibility.Visible;
            HowToPanel.Visibility = Visibility.Collapsed;
        }

        private void BtnHowTo_Click(object sender, RoutedEventArgs e)
        {
            MenuMainBorder.Visibility = Visibility.Collapsed;
            CreditsPanel.Visibility = Visibility.Collapsed;
            HowToPanel.Visibility = Visibility.Visible;
        }

        private void BtnBackToMenu_Click(object sender, RoutedEventArgs e)
        {
            MenuMainBorder.Visibility = Visibility.Visible;
            CreditsPanel.Visibility = Visibility.Collapsed;
            HowToPanel.Visibility = Visibility.Collapsed;
        }

        private void BtnExit_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }

        private void ShowMenu()
        {
            MenuMainBorder.Visibility = Visibility.Visible;
            CreditsPanel.Visibility = Visibility.Collapsed;
            HowToPanel.Visibility = Visibility.Collapsed;
            RefreshMenuButtons();
            MenuOverlay.Visibility = Visibility.Visible;
        }
    }
}
