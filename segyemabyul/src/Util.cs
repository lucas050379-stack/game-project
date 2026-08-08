using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;

namespace Segyemabyul
{
    /// <summary>이징 함수 모음. 모든 함수는 0..1 -> 0..1</summary>
    static class Ease
    {
        public static double Linear(double t) { return t; }
        public static double InQuad(double t) { return t * t; }
        public static double OutQuad(double t) { return 1 - (1 - t) * (1 - t); }
        public static double InOutQuad(double t) { return t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2; }
        public static double InCubic(double t) { return t * t * t; }
        public static double OutCubic(double t) { double u = 1 - t; return 1 - u * u * u; }
        public static double InOutCubic(double t)
        {
            if (t < 0.5) return 4 * t * t * t;
            double u = -2 * t + 2;
            return 1 - u * u * u / 2;
        }
        public static double OutQuint(double t) { double u = 1 - t; return 1 - u * u * u * u * u; }
        public static double OutBack(double t)
        {
            const double c1 = 1.70158, c3 = c1 + 1;
            double u = t - 1;
            return 1 + c3 * u * u * u + c1 * u * u;
        }
        public static double InBack(double t)
        {
            const double c1 = 1.70158, c3 = c1 + 1;
            return c3 * t * t * t - c1 * t * t;
        }
        public static double OutBounce(double t)
        {
            const double n1 = 7.5625, d1 = 2.75;
            if (t < 1 / d1) return n1 * t * t;
            if (t < 2 / d1) { t -= 1.5 / d1; return n1 * t * t + 0.75; }
            if (t < 2.5 / d1) { t -= 2.25 / d1; return n1 * t * t + 0.9375; }
            t -= 2.625 / d1; return n1 * t * t + 0.984375;
        }
        public static double OutElastic(double t)
        {
            if (t <= 0) return 0;
            if (t >= 1) return 1;
            const double c4 = 2 * Math.PI / 3;
            return Math.Pow(2, -10 * t) * Math.Sin((t * 10 - 0.75) * c4) + 1;
        }
        /// <summary>0 -> 1 -> 0 형태의 펄스</summary>
        public static double Pulse(double t) { return Math.Sin(t * Math.PI); }
    }

    static class Rnd
    {
        // 고정 시드를 쓰면 매 판 주사위·카드·통행료 2배 지역이 똑같이 나온다.
        // TickCount 는 빠르게 다시 켰을 때 겹치므로 Guid 로 뽑는다.
        static readonly Random R = new Random(Guid.NewGuid().GetHashCode());
        public static double D() { return R.NextDouble(); }
        public static double Range(double a, double b) { return a + (b - a) * R.NextDouble(); }
        public static int Int(int maxExclusive) { return R.Next(maxExclusive); }
        public static int Int(int a, int bExclusive) { return R.Next(a, bExclusive); }
        public static bool Chance(double p) { return R.NextDouble() < p; }
        public static double Signed(double m) { return Range(-m, m); }
        public static void Shuffle<T>(IList<T> list)
        {
            for (int i = list.Count - 1; i > 0; i--)
            {
                int j = R.Next(i + 1);
                T t = list[i]; list[i] = list[j]; list[j] = t;
            }
        }
    }

    /// <summary>폰트 캐시. 한글은 맑은 고딕(Windows 기본 탑재)</summary>
    static class F
    {
        const string Face = "Malgun Gothic";
        public static Font Tiny, Small, Body, BodyB, Sub, SubB, Title, Huge, Mega, Mono;
        public static FontFamily Fam;

        /// <summary>임의 크기 폰트 생성 (한글 지원 폰트 기준)</summary>
        public static Font At(float size, FontStyle style)
        {
            if (Fam == null) return Make(size, style);
            return new Font(Fam, Math.Max(4f, size), style, GraphicsUnit.Point);
        }

        public static void Init()
        {
            try { Fam = new FontFamily(Face); }
            catch { Fam = FontFamily.GenericSansSerif; }
            Tiny = Make(8.0f, FontStyle.Regular);
            Small = Make(9.0f, FontStyle.Bold);
            Body = Make(10.5f, FontStyle.Regular);
            BodyB = Make(10.5f, FontStyle.Bold);
            Sub = Make(13f, FontStyle.Regular);
            SubB = Make(13f, FontStyle.Bold);
            Title = Make(19f, FontStyle.Bold);
            Huge = Make(30f, FontStyle.Bold);
            Mega = Make(52f, FontStyle.Bold);
            Mono = new Font("Consolas", 9.5f, FontStyle.Regular);
        }

        static Font Make(float size, FontStyle style)
        {
            try { return new Font(Face, size, style, GraphicsUnit.Point); }
            catch { return new Font(FontFamily.GenericSansSerif, size, style, GraphicsUnit.Point); }
        }
    }

    /// <summary>색상 팔레트</summary>
    static class Pal
    {
        public static readonly Color Bg0 = Color.FromArgb(16, 20, 38);
        public static readonly Color Bg1 = Color.FromArgb(30, 38, 70);
        public static readonly Color BoardBg = Color.FromArgb(22, 28, 52);
        public static readonly Color Panel = Color.FromArgb(34, 42, 74);
        public static readonly Color PanelHi = Color.FromArgb(46, 56, 96);
        public static readonly Color CellBg = Color.FromArgb(242, 244, 250);
        public static readonly Color CellBg2 = Color.FromArgb(222, 227, 240);
        public static readonly Color Ink = Color.FromArgb(28, 32, 48);
        public static readonly Color InkSoft = Color.FromArgb(96, 104, 128);
        public static readonly Color White = Color.FromArgb(248, 250, 255);
        public static readonly Color Dim = Color.FromArgb(150, 160, 190);
        public static readonly Color Gold = Color.FromArgb(255, 202, 64);
        public static readonly Color GoldDeep = Color.FromArgb(214, 152, 20);
        public static readonly Color Good = Color.FromArgb(74, 222, 128);
        public static readonly Color Bad = Color.FromArgb(248, 113, 113);
        public static readonly Color Accent = Color.FromArgb(96, 165, 250);
    }

    static class Draw
    {
        public static readonly StringFormat Center = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
            FormatFlags = StringFormatFlags.NoWrap,
            Trimming = StringTrimming.None
        };
        public static readonly StringFormat CenterWrap = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center
        };
        public static readonly StringFormat Left = new StringFormat
        {
            Alignment = StringAlignment.Near,
            LineAlignment = StringAlignment.Center,
            FormatFlags = StringFormatFlags.NoWrap
        };
        public static readonly StringFormat Right = new StringFormat
        {
            Alignment = StringAlignment.Far,
            LineAlignment = StringAlignment.Center,
            FormatFlags = StringFormatFlags.NoWrap
        };

        public static Color A(Color c, int alpha)
        {
            if (alpha < 0) alpha = 0; if (alpha > 255) alpha = 255;
            return Color.FromArgb(alpha, c);
        }
        public static Color A(Color c, double alpha01)
        {
            return A(c, (int)Math.Round(alpha01 * 255));
        }
        public static Color Mix(Color a, Color b, double t)
        {
            if (t < 0) t = 0; if (t > 1) t = 1;
            return Color.FromArgb(
                (int)(a.A + (b.A - a.A) * t),
                (int)(a.R + (b.R - a.R) * t),
                (int)(a.G + (b.G - a.G) * t),
                (int)(a.B + (b.B - a.B) * t));
        }
        public static Color Lighten(Color c, double t) { return Mix(c, Color.White, t); }
        public static Color Darken(Color c, double t) { return Mix(c, Color.Black, t); }

        public static GraphicsPath RoundRect(RectangleF r, float rad)
        {
            var p = new GraphicsPath();
            if (rad <= 0.1f) { p.AddRectangle(r); return p; }
            float d = rad * 2;
            if (d > r.Width) d = r.Width;
            if (d > r.Height) d = r.Height;
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static void FillRound(Graphics g, Color c, RectangleF r, float rad)
        {
            if (r.Width <= 0 || r.Height <= 0) return;
            using (var p = RoundRect(r, rad))
            using (var b = new SolidBrush(c))
                g.FillPath(b, p);
        }

        public static void FillRoundGrad(Graphics g, Color top, Color bottom, RectangleF r, float rad)
        {
            if (r.Width <= 0 || r.Height <= 0) return;
            using (var p = RoundRect(r, rad))
            using (var b = new LinearGradientBrush(
                new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2), top, bottom, 90f))
                g.FillPath(b, p);
        }

        public static void StrokeRound(Graphics g, Color c, float w, RectangleF r, float rad)
        {
            if (r.Width <= 0 || r.Height <= 0) return;
            using (var p = RoundRect(r, rad))
            using (var pen = new Pen(c, w))
            {
                pen.LineJoin = LineJoin.Round;
                g.DrawPath(pen, p);
            }
        }

        /// <summary>둥근 사각형 주변 부드러운 발광</summary>
        public static void GlowRound(Graphics g, Color c, RectangleF r, float rad, float spread, double strength)
        {
            int layers = 5;
            for (int i = layers; i >= 1; i--)
            {
                float e = spread * i / layers;
                var rr = RectangleF.Inflate(r, e, e);
                int a = (int)(strength * 40 * (1.0 - (double)(i - 1) / layers));
                StrokeRound(g, A(c, a), e / 1.6f + 1.5f, rr, rad + e);
            }
        }

        public static void Shadow(Graphics g, RectangleF r, float rad, float dy, double strength)
        {
            for (int i = 4; i >= 1; i--)
            {
                var rr = new RectangleF(r.X - i, r.Y - i + dy, r.Width + i * 2, r.Height + i * 2);
                FillRound(g, A(Color.Black, (int)(strength * 16)), rr, rad + i);
            }
        }

        public static void Text(Graphics g, string s, Font f, Color c, float cx, float cy)
        {
            if (string.IsNullOrEmpty(s)) return;
            using (var b = new SolidBrush(c))
                g.DrawString(s, f, b, new RectangleF(cx - 600, cy - 40, 1200, 80), Center);
        }

        public static void TextIn(Graphics g, string s, Font f, Color c, RectangleF r, StringFormat fmt)
        {
            if (string.IsNullOrEmpty(s)) return;
            using (var b = new SolidBrush(c))
                g.DrawString(s, f, b, r, fmt);
        }

        public static void TextShadow(Graphics g, string s, Font f, Color c, float cx, float cy, int sa)
        {
            Text(g, s, f, A(Color.Black, sa), cx + 2, cy + 2);
            Text(g, s, f, c, cx, cy);
        }

        public static SizeF Measure(Graphics g, string s, Font f)
        {
            return g.MeasureString(s, f, 2000, Center);
        }

        public static void Star(Graphics g, Color c, float cx, float cy, float r, int points, double rot)
        {
            var pts = new PointF[points * 2];
            for (int i = 0; i < points * 2; i++)
            {
                double a = rot + i * Math.PI / points;
                float rr = (i % 2 == 0) ? r : r * 0.45f;
                pts[i] = new PointF(cx + (float)(Math.Cos(a) * rr), cy + (float)(Math.Sin(a) * rr));
            }
            using (var b = new SolidBrush(c)) g.FillPolygon(b, pts);
        }

        public static void Triangle(Graphics g, Color c, float cx, float cy, float w, float h, bool down)
        {
            PointF[] pts = down
                ? new[] { new PointF(cx - w / 2, cy - h / 2), new PointF(cx + w / 2, cy - h / 2), new PointF(cx, cy + h / 2) }
                : new[] { new PointF(cx - w / 2, cy + h / 2), new PointF(cx + w / 2, cy + h / 2), new PointF(cx, cy - h / 2) };
            using (var b = new SolidBrush(c)) g.FillPolygon(b, pts);
        }

        public static void SetQuality(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBilinear;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        }
    }
}
