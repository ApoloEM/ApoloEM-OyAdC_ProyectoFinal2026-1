using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;

namespace BillarGUI
{
    public class BallVisual
    {

        private const int TRAIL_POINTS = 8;
        private const double TRAIL_MIN_MOVE = 0.5;
        private const double TRAIL_MAX_ALPHA = 0.78;
        private const double ROLL_FACTOR = 1.65;

        private readonly Canvas _container;
        private readonly Ellipse _baseEllipse;
        private readonly Line[] _trailSegments;
        private readonly RotateTransform _rotation;

        private readonly double _radius;
        private readonly int _ballNum;
        private readonly int _ballType;

        private double _lastX = double.NaN;
        private double _lastY = double.NaN;
        private double _accumAngle;
        private bool _isVisible = true;

        private readonly Queue<Point> _trail = new Queue<Point>(TRAIL_POINTS);

        public BallVisual(int ballNum, int ballType, double radius)
        {
            _ballNum = ballNum;
            _ballType = ballType;
            _radius = radius;

            Color baseColor = GetBallBaseColor(ballNum, ballType);

            _container = new Canvas
            {
                Width = radius * 2,
                Height = radius * 2,
                Clip = new EllipseGeometry(new Point(radius, radius), radius, radius),
            };
            _rotation = new RotateTransform(0, radius, radius);
            _container.RenderTransform = _rotation;

            Color fondoColor = (ballType == GameConstants.TYPE_STRIPE) ? Colors.White : baseColor;

            _baseEllipse = new Ellipse
            {
                Width = radius * 2,
                Height = radius * 2,
                Fill = MakeSphericalBrush(fondoColor),
            };
            Canvas.SetLeft(_baseEllipse, 0);
            Canvas.SetTop(_baseEllipse, 0);
            _container.Children.Add(_baseEllipse);

            if (ballType == GameConstants.TYPE_STRIPE)
            {

                double stripeH = radius * 1.05;
                var stripe = new Rectangle
                {
                    Width = radius * 2,
                    Height = stripeH,
                    Fill = MakeStripeBrush(baseColor),
                };
                Canvas.SetLeft(stripe, 0);
                Canvas.SetTop(stripe, radius - stripeH / 2);
                _container.Children.Add(stripe);
            }

            if (ballNum != 0)
            {
                double circleD = radius * 0.95;
                var numberCircle = new Ellipse
                {
                    Width = circleD,
                    Height = circleD,
                    Fill = MakeNumberCircleBrush(),
                };
                Canvas.SetLeft(numberCircle, radius - circleD / 2);
                Canvas.SetTop(numberCircle, radius - circleD / 2);
                _container.Children.Add(numberCircle);

                var numberText = new TextBlock
                {
                    Text = ballNum.ToString(),
                    FontSize = radius * 0.70,
                    FontWeight = FontWeights.Bold,
                    FontFamily = new FontFamily("Segoe UI"),
                    Foreground = Brushes.Black,
                    TextAlignment = TextAlignment.Center,
                    Width = radius * 2,
                };
                Canvas.SetLeft(numberText, 0);
                Canvas.SetTop(numberText, radius - radius * 0.55);
                _container.Children.Add(numberText);
            }

            double hiD = radius * 0.55;
            var hilite = new Ellipse
            {
                Width = hiD,
                Height = hiD,
                Fill = new RadialGradientBrush
                {
                    GradientStops =
                    {
                        new GradientStop(Color.FromArgb(180, 255, 255, 255), 0),
                        new GradientStop(Color.FromArgb(0,   255, 255, 255), 1),
                    },
                },
                IsHitTestVisible = false,
            };
            Canvas.SetLeft(hilite, radius * 0.18);
            Canvas.SetTop(hilite, radius * 0.15);
            _container.Children.Add(hilite);

            _trailSegments = new Line[TRAIL_POINTS - 1];
            Color trailColor = (ballNum == 0) ? Colors.White : baseColor;
            for (int i = 0; i < _trailSegments.Length; i++)
            {
                _trailSegments[i] = new Line
                {
                    Stroke = new SolidColorBrush(trailColor),
                    StrokeThickness = radius * 1.3,
                    StrokeStartLineCap = PenLineCap.Round,
                    StrokeEndLineCap = PenLineCap.Round,
                    Opacity = 0,
                    Visibility = Visibility.Collapsed,
                    IsHitTestVisible = false,
                };
            }
        }

        public void AddToCanvas(Canvas canvas)
        {

            foreach (var seg in _trailSegments)
            {
                canvas.Children.Add(seg);
                Panel.SetZIndex(seg, 5);
            }
            canvas.Children.Add(_container);
            Panel.SetZIndex(_container, 10);
        }

        public void RemoveFromCanvas(Canvas canvas)
        {
            foreach (var seg in _trailSegments)
                canvas.Children.Remove(seg);
            canvas.Children.Remove(_container);
        }

        public void UpdatePosition(double x, double y)
        {

            double dx = 0, dy = 0;
            if (!double.IsNaN(_lastX))
            {
                dx = x - _lastX;
                dy = y - _lastY;
            }
            _lastX = x;
            _lastY = y;

            double moved = Math.Sqrt(dx * dx + dy * dy);

            if (moved > TRAIL_MIN_MOVE)
            {

                _accumAngle += moved * ROLL_FACTOR;
                if (_accumAngle > 360) _accumAngle -= 360;
                else if (_accumAngle < -360) _accumAngle += 360;
                _rotation.Angle = _accumAngle;

                _trail.Enqueue(new Point(x, y));
                while (_trail.Count > TRAIL_POINTS) _trail.Dequeue();
            }
            else
            {

                if (_trail.Count > 0) _trail.Dequeue();
            }

            Canvas.SetLeft(_container, x - _radius);
            Canvas.SetTop(_container, y - _radius);

            UpdateTrailVisuals();
        }

        private void UpdateTrailVisuals()
        {
            if (!_isVisible || _trail.Count < 2)
            {
                foreach (var seg in _trailSegments)
                    seg.Visibility = Visibility.Collapsed;
                return;
            }

            var pts = _trail.ToArray();
            int n = pts.Length;

            for (int i = 0; i < _trailSegments.Length; i++)
            {
                var seg = _trailSegments[i];

                if (i + 1 >= n)
                {
                    seg.Visibility = Visibility.Collapsed;
                    continue;
                }

                seg.X1 = pts[i].X;
                seg.Y1 = pts[i].Y;
                seg.X2 = pts[i + 1].X;
                seg.Y2 = pts[i + 1].Y;

                seg.Opacity = ((double)(i + 1) / (n - 1)) * TRAIL_MAX_ALPHA;
                seg.Visibility = Visibility.Visible;
            }
        }

        public void SetVisible(bool visible)
        {
            _isVisible = visible;
            _container.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
            if (!visible)
            {
                _trail.Clear();
                foreach (var seg in _trailSegments)
                    seg.Visibility = Visibility.Collapsed;
            }
        }

        private static Color GetBallBaseColor(int ballNum, int ballType)
        {
            if (ballNum == 0) return Colors.White;
            if (ballType == GameConstants.TYPE_EIGHT) return Color.FromRgb(20, 20, 20);

            int idx = ((ballNum - 1) % 7) + 1;
            return idx switch
            {
                1 => Color.FromRgb(247, 197, 25),
                2 => Color.FromRgb(28, 101, 192),
                3 => Color.FromRgb(198, 40, 40),
                4 => Color.FromRgb(106, 27, 154),
                5 => Color.FromRgb(239, 108, 0),
                6 => Color.FromRgb(46, 125, 50),
                7 => Color.FromRgb(123, 36, 28),
                _ => Colors.Gray,
            };
        }

        private static RadialGradientBrush MakeSphericalBrush(Color baseColor)
        {
            var hi = LightenColor(baseColor, 0.38);
            var mid = baseColor;
            var sh = DarkenColor(baseColor, 0.34);

            var brush = new RadialGradientBrush
            {
                GradientOrigin = new Point(0.26, 0.26),
                Center = new Point(0.30, 0.30),
                RadiusX = 0.94,
                RadiusY = 0.94,
            };
            brush.GradientStops.Add(new GradientStop(hi, 0.0));
            brush.GradientStops.Add(new GradientStop(mid, 0.62));
            brush.GradientStops.Add(new GradientStop(sh, 1.0));
            return brush;
        }

        private static LinearGradientBrush MakeStripeBrush(Color baseColor)
        {
            var hi = LightenColor(baseColor, 0.20);
            var mid = baseColor;
            var sh = DarkenColor(baseColor, 0.30);

            var brush = new LinearGradientBrush
            {
                StartPoint = new Point(0, 0),
                EndPoint = new Point(0, 1),
            };
            brush.GradientStops.Add(new GradientStop(sh, 0.0));
            brush.GradientStops.Add(new GradientStop(hi, 0.15));
            brush.GradientStops.Add(new GradientStop(mid, 0.5));
            brush.GradientStops.Add(new GradientStop(hi, 0.85));
            brush.GradientStops.Add(new GradientStop(sh, 1.0));
            return brush;
        }

        private static RadialGradientBrush MakeNumberCircleBrush()
        {
            var brush = new RadialGradientBrush
            {
                GradientOrigin = new Point(0.4, 0.35),
                Center = new Point(0.4, 0.35),
                RadiusX = 0.7,
                RadiusY = 0.7,
            };
            brush.GradientStops.Add(new GradientStop(Colors.White, 0.0));
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(245, 245, 245), 0.7));
            brush.GradientStops.Add(new GradientStop(Color.FromRgb(220, 220, 220), 1.0));
            return brush;
        }

        private static Color LightenColor(Color c, double t)
        {
            byte r = (byte)Math.Min(255, c.R + (255 - c.R) * t);
            byte g = (byte)Math.Min(255, c.G + (255 - c.G) * t);
            byte b = (byte)Math.Min(255, c.B + (255 - c.B) * t);
            return Color.FromRgb(r, g, b);
        }

        private static Color DarkenColor(Color c, double t)
        {
            byte r = (byte)(c.R * (1 - t));
            byte g = (byte)(c.G * (1 - t));
            byte b = (byte)(c.B * (1 - t));
            return Color.FromRgb(r, g, b);
        }
    }
}
