// ============================================================
// BallVisual.cs — Cada bola con su contenedor, rodamiento y trazas
// ------------------------------------------------------------
// Cambios sobre la version anterior:
//
//   #3 Diseno visual: cada bola es un Canvas con clip a circunferencia
//      que contiene una elipse de fondo (gradiente radial esferico),
//      una franja para las rayadas, un circulo blanco con el numero
//      y el numero como TextBlock.
//
//   #2 Rodamiento: el contenedor entero rota visualmente con un
//      RotateTransform cuyo angulo se acumula segun el desplazamiento
//      por frame. Da la sensacion de "girar" mientras avanza.
//
//   #1 Trazas: cada bola tiene 7 segmentos de linea que dibujan su
//      ultima trayectoria. La opacidad sube con el segmento mas
//      reciente y baja con los antiguos. Cuando la bola se detiene
//      el buffer se vacia gradualmente y los segmentos desaparecen.
// ============================================================
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
        // ---- Configuracion de trazas y rodamiento ----
        private const int TRAIL_POINTS = 8;     // tamanio del buffer de posiciones
        private const double TRAIL_MIN_MOVE = 0.5;   // px: por debajo de esto no se anota traza
        private const double TRAIL_MAX_ALPHA = 0.78;  // opacidad maxima de la traza
        private const double ROLL_FACTOR = 1.65;   // grados de rotacion por px de desplazamiento

        // ---- Visuales ----
        private readonly Canvas _container;
        private readonly Ellipse _baseEllipse;
        private readonly Line[] _trailSegments;
        private readonly RotateTransform _rotation;

        // ---- Estado del visual ----
        private readonly double _radius;
        private readonly int _ballNum;
        private readonly int _ballType;

        private double _lastX = double.NaN;
        private double _lastY = double.NaN;
        private double _accumAngle;
        private bool _isVisible = true;

        // Buffer FIFO de las ultimas N posiciones (en coords del Canvas)
        private readonly Queue<Point> _trail = new Queue<Point>(TRAIL_POINTS);

        // ============================================================
        // CONSTRUCTOR
        // ============================================================
        public BallVisual(int ballNum, int ballType, double radius)
        {
            _ballNum = ballNum;
            _ballType = ballType;
            _radius = radius;

            // ---- Color base segun numero/tipo ----
            Color baseColor = GetBallBaseColor(ballNum, ballType);

            // ---- Contenedor que se posiciona en el Canvas y rota ----
            _container = new Canvas
            {
                Width = radius * 2,
                Height = radius * 2,
                Clip = new EllipseGeometry(new Point(radius, radius), radius, radius),
            };
            _rotation = new RotateTransform(0, radius, radius);
            _container.RenderTransform = _rotation;

            // ---- Elipse de fondo ----
            // Para rayadas el fondo es blanco (la franja de color va encima);
            // para lisas y la 8 el fondo es del color de la bola.
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

            // ---- Franja para las rayadas ----
            if (ballType == GameConstants.TYPE_STRIPE)
            {
                // Rectangulo del color base, centrado verticalmente.
                // El Clip del contenedor recorta los extremos a la circunferencia.
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

            // ---- Circulo blanco con el numero (todas excepto la blanca) ----
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

            // ---- Highlight especular ----
            // Lo agrego al final para que quede encima de todo. Como el
            // contenedor rota completo, este highlight tambien rota — es
            // un compromiso para mantener el codigo simple. En vista
            // top-down el efecto sigue siendo agradable.
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

            // ---- Segmentos de traza ----
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

        // ============================================================
        // INTEGRACION CON EL CANVAS
        // ============================================================

        public void AddToCanvas(Canvas canvas)
        {
            // Trazas debajo de las bolas (z-index bajo)
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

        // ============================================================
        // ACTUALIZACION POR FRAME
        // ============================================================

        public void UpdatePosition(double x, double y)
        {
            // Calcular desplazamiento desde el frame anterior.
            // El primer frame no tiene "anterior" — lo marca _lastX==NaN.
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
                // Acumular angulo de rodamiento visual
                _accumAngle += moved * ROLL_FACTOR;
                if (_accumAngle > 360) _accumAngle -= 360;
                else if (_accumAngle < -360) _accumAngle += 360;
                _rotation.Angle = _accumAngle;

                // Anotar la posicion nueva en el buffer
                _trail.Enqueue(new Point(x, y));
                while (_trail.Count > TRAIL_POINTS) _trail.Dequeue();
            }
            else
            {
                // Bola casi quieta: vaciamos el buffer 1 punto por frame
                if (_trail.Count > 0) _trail.Dequeue();
            }

            // Posicionar el contenedor (esquina superior izquierda)
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

            // Snapshot del buffer en orden cronologico (mas viejo -> mas nuevo)
            var pts = _trail.ToArray();
            int n = pts.Length;

            for (int i = 0; i < _trailSegments.Length; i++)
            {
                var seg = _trailSegments[i];

                // Necesitamos pts[i] y pts[i+1] para dibujar
                if (i + 1 >= n)
                {
                    seg.Visibility = Visibility.Collapsed;
                    continue;
                }

                seg.X1 = pts[i].X;
                seg.Y1 = pts[i].Y;
                seg.X2 = pts[i + 1].X;
                seg.Y2 = pts[i + 1].Y;

                // Opacidad creciente del mas viejo (i=0) al mas nuevo (n-2)
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

        // ============================================================
        // PINCELES Y COLORES
        // ============================================================

        // Color base de cada bola siguiendo el estandar de billar:
        //   1, 9 = amarillo; 2,10 = azul; 3,11 = rojo; 4,12 = morado;
        //   5,13 = naranja;  6,14 = verde; 7,15 = vino; 8 = negro.
        private static Color GetBallBaseColor(int ballNum, int ballType)
        {
            if (ballNum == 0) return Colors.White;
            if (ballType == GameConstants.TYPE_EIGHT) return Color.FromRgb(20, 20, 20);

            int idx = ((ballNum - 1) % 7) + 1;
            return idx switch
            {
                1 => Color.FromRgb(247, 197, 25),   // amarillo
                2 => Color.FromRgb(28, 101, 192),  // azul
                3 => Color.FromRgb(198, 40, 40),   // rojo
                4 => Color.FromRgb(106, 27, 154),  // morado
                5 => Color.FromRgb(239, 108, 0),    // naranja
                6 => Color.FromRgb(46, 125, 50),   // verde
                7 => Color.FromRgb(123, 36, 28),   // vino oscuro
                _ => Colors.Gray,
            };
        }

        // Pincel esferico: highlight arriba-izquierda, color medio,
        // sombra en el borde inferior-derecho.
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

        // Franja de las rayadas: gradiente vertical sutil para que el
        // borde superior e inferior se vean un poco mas oscuros y de
        // sensacion de cilindro envolviendo la esfera.
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

        // Circulo blanco que rodea al numero (con sombra interna leve)
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