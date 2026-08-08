using System;
using System.Drawing;
using System.Drawing.Drawing2D;

namespace Segyemabyul
{
    /// <summary>이미지 파일 없이 코드로 그리는 아이콘/국기/주사위/건물/캐릭터</summary>
    static class Icons
    {
        // ================= 국기 =================
        public static void DrawFlag(Graphics g, Flag f, RectangleF r)
        {
            if (f == null) return;
            var st = g.Save();
            using (var clip = Draw.RoundRect(r, Math.Min(3f, r.Height * 0.2f)))
            {
                g.SetClip(clip);
                switch (f.Kind)
                {
                    case FlagKind.HStripes: Stripes(g, f.C, r, true); break;
                    case FlagKind.VStripes: Stripes(g, f.C, r, false); break;
                    case FlagKind.Disc: Disc(g, f, r); break;
                    case FlagKind.Cross: Cross(g, f, r, false); break;
                    case FlagKind.NordicCross: Cross(g, f, r, true); break;
                    case FlagKind.TriHoist: TriHoist(g, f, r); break;
                    case FlagKind.Canton: Canton(g, f, r); break;
                    case FlagKind.Stars: Stars(g, f, r); break;
                    case FlagKind.Taegeuk: Taegeuk(g, f, r); break;
                    case FlagKind.UnionJack: UnionJack(g, f, r); break;
                    case FlagKind.HoistBar: HoistBar(g, f, r); break;
                    case FlagKind.Beach: Beach(g, f, r); break;
                    case FlagKind.Palm: PalmFlag(g, f, r); break;
                }
                // 광택
                using (var b = new LinearGradientBrush(
                    new RectangleF(r.X, r.Y - 1, r.Width, r.Height + 2),
                    Color.FromArgb(60, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                    g.FillRectangle(b, r);
            }
            g.Restore(st);
            Draw.StrokeRound(g, Color.FromArgb(70, 0, 0, 0), 1f, r, Math.Min(3f, r.Height * 0.2f));
        }

        static void Fill(Graphics g, Color c, RectangleF r)
        {
            using (var b = new SolidBrush(c)) g.FillRectangle(b, r);
        }

        static void Stripes(Graphics g, Color[] c, RectangleF r, bool horizontal)
        {
            int n = c.Length;
            for (int i = 0; i < n; i++)
            {
                RectangleF s = horizontal
                    ? new RectangleF(r.X, r.Y + r.Height * i / n, r.Width, r.Height / n + 1)
                    : new RectangleF(r.X + r.Width * i / n, r.Y, r.Width / n + 1, r.Height);
                Fill(g, c[i], s);
            }
        }

        static void Disc(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, f.C[0], r);
            float d = r.Height * 0.6f;
            using (var b = new SolidBrush(f.C[1]))
                g.FillEllipse(b, r.X + r.Width / 2 - d / 2, r.Y + r.Height / 2 - d / 2, d, d);
        }

        static void Cross(Graphics g, Flag f, RectangleF r, bool nordic)
        {
            Fill(g, f.C[0], r);
            float tw = r.Height * 0.22f;
            float cx = nordic ? r.X + r.Width * 0.36f : r.X + r.Width / 2;
            Fill(g, f.C[1], new RectangleF(cx - tw / 2, r.Y, tw, r.Height));
            Fill(g, f.C[1], new RectangleF(r.X, r.Y + r.Height / 2 - tw / 2, r.Width, tw));
        }

        static void TriHoist(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, f.C[0], new RectangleF(r.X, r.Y, r.Width, r.Height / 2 + 1));
            Fill(g, f.C[1], new RectangleF(r.X, r.Y + r.Height / 2, r.Width, r.Height / 2 + 1));
            if (f.C.Length > 2)
            {
                var pts = new[]
                {
                    new PointF(r.X, r.Y), new PointF(r.X + r.Width * 0.45f, r.Y + r.Height / 2),
                    new PointF(r.X, r.Bottom)
                };
                using (var b = new SolidBrush(f.C[2])) g.FillPolygon(b, pts);
            }
        }

        static void Canton(Graphics g, Flag f, RectangleF r)
        {
            // 줄무늬 바탕 + 좌상단 캔톤
            int n = 7;
            for (int i = 0; i < n; i++)
                Fill(g, i % 2 == 0 ? f.C[0] : Color.White,
                    new RectangleF(r.X, r.Y + r.Height * i / n, r.Width, r.Height / n + 1));
            var cr = new RectangleF(r.X, r.Y, r.Width * 0.42f, r.Height * 0.55f);
            Fill(g, f.C[1], cr);
            Draw.Star(g, f.C[2], cr.X + cr.Width / 2, cr.Y + cr.Height / 2, cr.Height * 0.36f, 5, -Math.PI / 2);
        }

        static void Stars(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, f.C[0], r);
            var cr = new RectangleF(r.X, r.Y, r.Width * 0.4f, r.Height * 0.5f);
            using (var pen = new Pen(f.C[1], Math.Max(1f, r.Height * 0.07f)))
            {
                g.DrawLine(pen, cr.X, cr.Y, cr.Right, cr.Bottom);
                g.DrawLine(pen, cr.Right, cr.Y, cr.X, cr.Bottom);
                g.DrawLine(pen, cr.X + cr.Width / 2, cr.Y, cr.X + cr.Width / 2, cr.Bottom);
                g.DrawLine(pen, cr.X, cr.Y + cr.Height / 2, cr.Right, cr.Y + cr.Height / 2);
            }
            Draw.Star(g, f.C[1], r.X + r.Width * 0.2f, r.Bottom - r.Height * 0.22f, r.Height * 0.18f, 5, -Math.PI / 2);
            Draw.Star(g, f.C[1], r.X + r.Width * 0.72f, r.Y + r.Height * 0.28f, r.Height * 0.15f, 5, -Math.PI / 2);
            Draw.Star(g, f.C[1], r.X + r.Width * 0.85f, r.Y + r.Height * 0.66f, r.Height * 0.12f, 5, -Math.PI / 2);
        }

        static void Taegeuk(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, Color.White, r);
            float d = r.Height * 0.52f;
            float cx = r.X + r.Width / 2, cy = r.Y + r.Height / 2;
            using (var b = new SolidBrush(f.C[1])) g.FillPie(b, cx - d / 2, cy - d / 2, d, d, 180, 180);
            using (var b = new SolidBrush(f.C[2])) g.FillPie(b, cx - d / 2, cy - d / 2, d, d, 0, 180);
            using (var b = new SolidBrush(f.C[2]))
                g.FillEllipse(b, cx - d / 2, cy - d / 4, d / 2, d / 2);
            using (var b = new SolidBrush(f.C[1]))
                g.FillEllipse(b, cx, cy - d / 4, d / 2, d / 2);
            // 사괘 (간략화)
            using (var b = new SolidBrush(Color.FromArgb(30, 30, 30)))
            {
                float bw = r.Width * 0.13f, bh = Math.Max(1.2f, r.Height * 0.055f);
                for (int i = 0; i < 3; i++)
                {
                    g.FillRectangle(b, r.X + r.Width * 0.06f, r.Y + r.Height * (0.16f + i * 0.09f), bw, bh);
                    g.FillRectangle(b, r.Right - r.Width * 0.06f - bw, r.Y + r.Height * (0.16f + i * 0.09f), bw, bh);
                    g.FillRectangle(b, r.X + r.Width * 0.06f, r.Bottom - r.Height * (0.22f + i * 0.09f), bw, bh);
                    g.FillRectangle(b, r.Right - r.Width * 0.06f - bw, r.Bottom - r.Height * (0.22f + i * 0.09f), bw, bh);
                }
            }
        }

        static void UnionJack(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, f.C[0], r);
            using (var wp = new Pen(f.C[1], Math.Max(1.5f, r.Height * 0.16f)))
            using (var rp = new Pen(f.C[2], Math.Max(1f, r.Height * 0.08f)))
            {
                g.DrawLine(wp, r.X, r.Y, r.Right, r.Bottom);
                g.DrawLine(wp, r.Right, r.Y, r.X, r.Bottom);
                g.DrawLine(rp, r.X, r.Y, r.Right, r.Bottom);
                g.DrawLine(rp, r.Right, r.Y, r.X, r.Bottom);
            }
            float tw = r.Height * 0.3f;
            Fill(g, f.C[1], new RectangleF(r.X + r.Width / 2 - tw / 2, r.Y, tw, r.Height));
            Fill(g, f.C[1], new RectangleF(r.X, r.Y + r.Height / 2 - tw / 2, r.Width, tw));
            float tw2 = tw * 0.5f;
            Fill(g, f.C[2], new RectangleF(r.X + r.Width / 2 - tw2 / 2, r.Y, tw2, r.Height));
            Fill(g, f.C[2], new RectangleF(r.X, r.Y + r.Height / 2 - tw2 / 2, r.Width, tw2));
        }

        /// <summary>좌측 세로 띠 + 가로 3줄 (UAE·쿠웨이트 형태)</summary>
        static void HoistBar(Graphics g, Flag f, RectangleF r)
        {
            float barW = r.Width * 0.3f;
            var body = new RectangleF(r.X + barW, r.Y, r.Width - barW, r.Height);
            for (int i = 0; i < 3; i++)
                Fill(g, f.C[i], new RectangleF(body.X, body.Y + body.Height * i / 3f, body.Width, body.Height / 3f + 1));
            Fill(g, f.C.Length > 3 ? f.C[3] : f.C[0], new RectangleF(r.X, r.Y, barW, r.Height));
        }

        static void Beach(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, f.C[0], r);
            using (var b = new SolidBrush(Color.FromArgb(253, 224, 71)))
                g.FillEllipse(b, r.X + r.Width * 0.62f, r.Y + r.Height * 0.12f, r.Height * 0.32f, r.Height * 0.32f);
            using (var b = new SolidBrush(f.C[1]))
                g.FillPie(b, r.X - r.Width * 0.2f, r.Y + r.Height * 0.45f, r.Width * 1.4f, r.Height * 1.2f, 180, 180);
            using (var b = new SolidBrush(Color.FromArgb(14, 165, 233)))
                g.FillRectangle(b, r.X, r.Y + r.Height * 0.52f, r.Width, r.Height * 0.12f);
        }

        static void PalmFlag(Graphics g, Flag f, RectangleF r)
        {
            Fill(g, Color.FromArgb(125, 211, 252), r);
            using (var b = new SolidBrush(f.C[0]))
                g.FillPie(b, r.X - r.Width * 0.1f, r.Y + r.Height * 0.55f, r.Width * 1.2f, r.Height, 180, 180);
            float tx = r.X + r.Width * 0.42f;
            using (var b = new SolidBrush(Color.FromArgb(120, 72, 40)))
                g.FillRectangle(b, tx, r.Y + r.Height * 0.28f, Math.Max(1.5f, r.Width * 0.06f), r.Height * 0.42f);
            using (var b = new SolidBrush(Color.FromArgb(22, 163, 74)))
            {
                float lr = r.Height * 0.2f;
                g.FillEllipse(b, tx - lr * 1.5f, r.Y + r.Height * 0.16f, lr * 1.8f, lr * 0.9f);
                g.FillEllipse(b, tx + lr * 0.1f, r.Y + r.Height * 0.14f, lr * 1.8f, lr * 0.9f);
                g.FillEllipse(b, tx - lr * 0.6f, r.Y + r.Height * 0.06f, lr * 1.6f, lr * 0.8f);
            }
        }

        // ================= 주사위 =================
        static readonly int[][] Pips =
        {
            new[]{4},
            new[]{0,8},
            new[]{0,4,8},
            new[]{0,2,6,8},
            new[]{0,2,4,6,8},
            new[]{0,2,3,5,6,8}
        };

        public static void DrawDie(Graphics g, float cx, float cy, float size, int value, double rot, double scale, int alpha)
        {
            var st = g.Save();
            g.TranslateTransform(cx, cy);
            g.RotateTransform((float)(rot * 57.2958));
            g.ScaleTransform((float)scale, (float)scale);

            var r = new RectangleF(-size / 2, -size / 2, size, size);
            float rad = size * 0.2f;
            Draw.FillRound(g, Draw.A(Color.FromArgb(0, 0, 0), (int)(alpha * 0.25)),
                new RectangleF(r.X + 3, r.Y + 4, r.Width, r.Height), rad);
            Draw.FillRoundGrad(g, Draw.A(Color.White, alpha), Draw.A(Color.FromArgb(214, 219, 232), alpha), r, rad);
            Draw.StrokeRound(g, Draw.A(Color.FromArgb(150, 158, 180), alpha), 1.4f, r, rad);

            if (value >= 1 && value <= 6)
            {
                float pr = size * 0.098f;
                float pad = size * 0.24f;
                float step = (size - pad * 2) / 2f;
                foreach (int idx in Pips[value - 1])
                {
                    int px = idx % 3, py = idx / 3;
                    float x = r.X + pad + step * px;
                    float y = r.Y + pad + step * py;
                    using (var b = new SolidBrush(Draw.A(Color.FromArgb(40, 44, 60), alpha)))
                        g.FillEllipse(b, x - pr, y - pr, pr * 2, pr * 2);
                    using (var b = new SolidBrush(Draw.A(Color.FromArgb(90, 255, 255, 255), alpha)))
                        g.FillEllipse(b, x - pr * 0.75f, y - pr * 0.85f, pr * 0.9f, pr * 0.7f);
                }
            }
            g.Restore(st);
        }

        // ================= 건물 =================
        /// <summary>칸 안에 건물을 그린다. level 1=별장 2=빌딩 3=호텔</summary>
        public static void DrawBuilding(Graphics g, int level, float cx, float baseY, float w, float h,
                                        Color owner, double pop)
        {
            DrawBuilding(g, level, cx, baseY, w, h, owner, pop, LandmarkKind.Generic);
        }

        public static void DrawBuilding(Graphics g, int level, float cx, float baseY, float w, float h,
                                        Color owner, double pop, LandmarkKind lm)
        {
            if (level <= 0) return;
            double bounce = pop > 0 ? (1 - Ease.OutBounce(pop)) : 0;
            float lift = (float)(bounce * h * 2.2);
            float squash = (float)(1 + bounce * 0.25);

            var st = g.Save();
            g.TranslateTransform(cx, baseY - lift);
            g.ScaleTransform(1f / squash, squash);

            Color body = Draw.Lighten(owner, 0.15);
            Color dark = Draw.Darken(owner, 0.35);
            Color roof = Draw.Darken(owner, 0.15);

            // 바닥 그림자
            using (var b = new SolidBrush(Color.FromArgb(55, 0, 0, 0)))
                g.FillEllipse(b, -w * 0.6f, -2f, w * 1.2f, 4.5f);

            if (level == 1)
            {
                float bh = h * 0.62f, bw = w * 0.74f;
                using (var br = new SolidBrush(body)) g.FillRectangle(br, -bw / 2, -bh, bw, bh);
                using (var br = new SolidBrush(dark)) g.FillRectangle(br, bw * 0.16f, -bh, bw * 0.34f, bh);
                var roofPts = new[]
                {
                    new PointF(-bw*0.62f, -bh), new PointF(bw*0.62f, -bh), new PointF(0, -h*1.02f)
                };
                using (var br = new SolidBrush(roof)) g.FillPolygon(br, roofPts);
                using (var br = new SolidBrush(Color.FromArgb(235, 245, 255)))
                    g.FillRectangle(br, -bw * 0.18f, -bh * 0.62f, bw * 0.26f, bh * 0.34f);
            }
            else if (level == 2)
            {
                float bh = h * 1.0f, bw = w * 0.66f;
                using (var br = new SolidBrush(body)) g.FillRectangle(br, -bw / 2, -bh, bw, bh);
                using (var br = new SolidBrush(dark)) g.FillRectangle(br, bw * 0.14f, -bh, bw * 0.36f, bh);
                using (var br = new SolidBrush(roof)) g.FillRectangle(br, -bw * 0.58f, -bh - h * 0.09f, bw * 1.16f, h * 0.09f);
                using (var br = new SolidBrush(Color.FromArgb(215, 235, 255)))
                {
                    for (int ry = 0; ry < 4; ry++)
                        for (int rx = 0; rx < 2; rx++)
                            g.FillRectangle(br, -bw * 0.30f + rx * bw * 0.30f, -bh + h * 0.13f + ry * h * 0.2f,
                                bw * 0.19f, h * 0.12f);
                }
            }
            else if (level == 3)
            {
                float bh = h * 1.38f, bw = w * 0.84f;
                using (var br = new SolidBrush(body)) g.FillRectangle(br, -bw / 2, -bh, bw, bh);
                using (var br = new SolidBrush(dark)) g.FillRectangle(br, bw * 0.12f, -bh, bw * 0.38f, bh);
                using (var br = new SolidBrush(Pal.Gold)) g.FillRectangle(br, -bw * 0.6f, -bh - h * 0.1f, bw * 1.2f, h * 0.1f);
                using (var pen = new Pen(Pal.Gold, 1.4f)) g.DrawLine(pen, 0, -bh - h * 0.1f, 0, -bh - h * 0.34f);
                using (var br = new SolidBrush(Color.FromArgb(255, 90, 90)))
                    g.FillEllipse(br, -2.2f, -bh - h * 0.42f, 4.4f, 4.4f);
                using (var br = new SolidBrush(Color.FromArgb(225, 240, 255)))
                {
                    for (int ry = 0; ry < 5; ry++)
                        for (int rx = 0; rx < 3; rx++)
                            g.FillRectangle(br, -bw * 0.38f + rx * bw * 0.26f, -bh + h * 0.14f + ry * h * 0.23f,
                                bw * 0.16f, h * 0.13f);
                }
            }
            else if (lm != LandmarkKind.Generic)
            {
                DrawLandmark(g, lm, w, h, body, dark);
            }
            else
            {
                // 랜드마크: 계단식 기단 + 첨탑 + 금빛 발광
                float bh = h * 1.02f;            // 본체 높이
                float bw = w * 0.62f;
                float baseW = w * 1.0f, baseH = h * 0.2f;

                using (var br = new SolidBrush(Draw.A(Pal.Gold, 60)))
                    g.FillEllipse(br, -baseW * 0.75f, -baseH * 1.2f, baseW * 1.5f, baseH * 2.4f);

                // 기단 2단
                using (var br = new SolidBrush(Draw.Darken(body, 0.15)))
                    g.FillRectangle(br, -baseW / 2, -baseH, baseW, baseH);
                using (var br = new SolidBrush(Draw.Darken(body, 0.32)))
                    g.FillRectangle(br, baseW * 0.14f, -baseH, baseW * 0.36f, baseH);
                using (var br = new SolidBrush(Draw.Lighten(body, 0.05)))
                    g.FillRectangle(br, -baseW * 0.4f, -baseH - h * 0.14f, baseW * 0.8f, h * 0.14f);

                // 본체(위로 좁아지는 탑)
                float top = -baseH - h * 0.14f - bh;
                var tower = new[]
                {
                    new PointF(-bw / 2, -baseH - h * 0.14f),
                    new PointF(bw / 2,  -baseH - h * 0.14f),
                    new PointF(bw * 0.28f, top),
                    new PointF(-bw * 0.28f, top)
                };
                using (var br = new SolidBrush(body)) g.FillPolygon(br, tower);
                using (var br = new SolidBrush(dark))
                    g.FillPolygon(br, new[]
                    {
                        new PointF(bw * 0.08f, -baseH - h * 0.14f), new PointF(bw / 2, -baseH - h * 0.14f),
                        new PointF(bw * 0.28f, top), new PointF(bw * 0.05f, top)
                    });

                // 금빛 띠
                using (var pen = new Pen(Pal.Gold, Math.Max(1f, h * 0.05f)))
                {
                    for (int i = 1; i <= 2; i++)
                    {
                        float yy = -baseH - h * 0.14f - bh * i / 3f;
                        float half = bw / 2 - (bw / 2 - bw * 0.28f) * i / 3f;
                        g.DrawLine(pen, -half, yy, half, yy);
                    }
                }

                // 첨탑
                using (var br = new SolidBrush(Pal.Gold))
                    g.FillPolygon(br, new[]
                    {
                        new PointF(-bw * 0.30f, top), new PointF(bw * 0.30f, top),
                        new PointF(0, top - h * 0.42f)
                    });
                // 빛나는 구
                using (var br = new SolidBrush(Color.FromArgb(255, 255, 245, 200)))
                    g.FillEllipse(br, -h * 0.09f, top - h * 0.56f, h * 0.18f, h * 0.18f);
                using (var br = new SolidBrush(Draw.A(Pal.Gold, 90)))
                    g.FillEllipse(br, -h * 0.2f, top - h * 0.67f, h * 0.4f, h * 0.4f);
            }
            g.Restore(st);
        }

        // ================= 도시별 랜드마크 =================
        // 좌표계: (0,0)이 바닥 한가운데, 위쪽이 -y. w=가로 기준, h=세로 기준.

        static void FR(Graphics g, Color c, float x, float y, float w, float h)
        {
            if (w <= 0 || h <= 0) return;
            using (var b = new SolidBrush(c)) g.FillRectangle(b, x, y, w, h);
        }

        static void FP(Graphics g, Color c, params PointF[] p)
        {
            using (var b = new SolidBrush(c)) g.FillPolygon(b, p);
        }

        static void FE(Graphics g, Color c, float x, float y, float w, float h)
        {
            if (w <= 0 || h <= 0) return;
            using (var b = new SolidBrush(c)) g.FillEllipse(b, x, y, w, h);
        }

        static void FPie(Graphics g, Color c, float x, float y, float w, float h, float a0, float sweep)
        {
            if (w <= 0 || h <= 0) return;
            using (var b = new SolidBrush(c)) g.FillPie(b, x, y, w, h, a0, sweep);
        }

        static void LN(Graphics g, Color c, float wid, float x0, float y0, float x1, float y1)
        {
            using (var p = new Pen(c, Math.Max(0.7f, wid))) g.DrawLine(p, x0, y0, x1, y1);
        }

        static PointF P(float x, float y) { return new PointF(x, y); }

        /// <summary>양파 돔 하나 (모스크바·이스탄불에서 재사용)</summary>
        static void OnionDomeShape(Graphics g, Color c, Color hi, float cx, float baseY, float rw, float rh)
        {
            FPie(g, c, cx - rw, baseY - rh * 1.15f, rw * 2, rh * 1.6f, 180, 180);
            FP(g, c, P(cx - rw * 0.86f, baseY - rh * 0.35f), P(cx + rw * 0.86f, baseY - rh * 0.35f),
                     P(cx, baseY + rh * 0.10f));
            FR(g, hi, cx - rw * 0.10f, baseY - rh * 1.62f, rw * 0.20f, rh * 0.42f);
            LN(g, hi, rw * 0.24f, cx - rw * 0.34f, baseY - rh * 1.45f, cx + rw * 0.34f, baseY - rh * 1.45f);
        }

        /// <summary>고딕 첨탑 지붕</summary>
        static void Spire(Graphics g, Color c, float cx, float baseY, float halfW, float hh)
        {
            FP(g, c, P(cx - halfW, baseY), P(cx + halfW, baseY), P(cx, baseY - hh));
        }

        static void DrawLandmark(Graphics g, LandmarkKind k, float w, float h, Color body, Color dark)
        {
            Color gold = Pal.Gold;
            Color deep = Pal.GoldDeep;
            Color stone = Draw.Lighten(body, 0.30);
            Color stoneD = Draw.Darken(body, 0.28);
            Color glass = Color.FromArgb(228, 240, 255);

            // 발밑 금빛 무리 — 어떤 도안이든 "랜드마크"로 읽히게 하는 공통 요소
            FE(g, Draw.A(gold, 70), -w * 0.85f, -h * 0.26f, w * 1.7f, h * 0.5f);

            switch (k)
            {
                case LandmarkKind.Tower101:
                    {
                        FR(g, stoneD, -w * 0.46f, -h * 0.16f, w * 0.92f, h * 0.16f);
                        float sh = h * 0.24f, y = -h * 0.16f;
                        for (int i = 0; i < 7; i++)
                        {
                            float hw = w * 0.24f;
                            FR(g, i % 2 == 0 ? stone : body, -hw, y - sh, hw * 2, sh);
                            FR(g, dark, hw * 0.18f, y - sh, hw * 0.82f, sh);
                            FP(g, gold, P(-hw * 1.30f, y - sh), P(hw * 1.30f, y - sh),
                                        P(hw * 0.95f, y - sh * 0.62f), P(-hw * 0.95f, y - sh * 0.62f));
                            y -= sh;
                        }
                        LN(g, gold, w * 0.09f, 0, y, 0, y - h * 0.55f);
                        FE(g, Color.FromArgb(255, 255, 246, 205), -h * 0.07f, y - h * 0.64f, h * 0.14f, h * 0.14f);
                        break;
                    }

                case LandmarkKind.Cathedral:
                    {
                        FR(g, stoneD, -w * 0.52f, -h * 0.12f, w * 1.04f, h * 0.12f);
                        FR(g, stone, -w * 0.26f, -h * 1.02f, w * 0.52f, h * 0.90f);
                        FR(g, dark, w * 0.06f, -h * 1.02f, w * 0.20f, h * 0.90f);
                        FP(g, deep, P(-w * 0.32f, -h * 1.02f), P(w * 0.32f, -h * 1.02f), P(0, -h * 1.34f));
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float cx = s * w * 0.40f;
                            FR(g, stone, cx - w * 0.13f, -h * 1.28f, w * 0.26f, h * 1.16f);
                            FR(g, dark, cx + w * 0.02f, -h * 1.28f, w * 0.11f, h * 1.16f);
                            Spire(g, deep, cx, -h * 1.28f, w * 0.17f, h * 0.40f);
                            LN(g, gold, w * 0.07f, cx, -h * 1.68f, cx, -h * 1.86f);
                            LN(g, gold, w * 0.07f, cx - w * 0.08f, -h * 1.79f, cx + w * 0.08f, -h * 1.79f);
                        }
                        FE(g, glass, -w * 0.11f, -h * 0.92f, w * 0.22f, h * 0.22f);
                        break;
                    }

                case LandmarkKind.Volcano:
                    {
                        FP(g, Draw.Darken(body, 0.10), P(-w * 0.82f, 0), P(w * 0.82f, 0),
                                                       P(w * 0.24f, -h * 1.05f), P(-w * 0.26f, -h * 1.05f));
                        FP(g, dark, P(w * 0.10f, 0), P(w * 0.82f, 0), P(w * 0.24f, -h * 1.05f), P(w * 0.02f, -h * 1.05f));
                        FE(g, Draw.Darken(body, 0.45), -w * 0.26f, -h * 1.14f, w * 0.50f, h * 0.18f);
                        FE(g, Color.FromArgb(255, 140, 60), -w * 0.18f, -h * 1.10f, w * 0.34f, h * 0.11f);
                        // 앞쪽 야자수
                        LN(g, deep, w * 0.10f, -w * 0.62f, 0, -w * 0.70f, -h * 0.50f);
                        for (int i = -2; i <= 2; i++)
                            LN(g, Color.FromArgb(52, 180, 110), w * 0.09f,
                                -w * 0.70f, -h * 0.50f, -w * 0.70f + i * w * 0.17f, -h * 0.50f - h * 0.20f + Math.Abs(i) * h * 0.06f);
                        break;
                    }

                case LandmarkKind.Merlion:
                    {
                        FR(g, stoneD, -w * 0.50f, -h * 0.18f, w * 1.00f, h * 0.18f);
                        // 물기둥
                        FP(g, Color.FromArgb(150, 120, 200, 255), P(-w * 0.20f, -h * 0.90f),
                            P(-w * 0.86f, -h * 0.30f), P(-w * 0.80f, -h * 0.14f), P(-w * 0.12f, -h * 0.78f));
                        // 몸통(비늘 꼬리)
                        FP(g, stone, P(w * 0.06f, -h * 0.18f), P(w * 0.44f, -h * 0.18f),
                                     P(w * 0.30f, -h * 0.86f), P(0, -h * 0.92f));
                        FP(g, dark, P(w * 0.24f, -h * 0.18f), P(w * 0.44f, -h * 0.18f), P(w * 0.30f, -h * 0.86f));
                        // 사자 머리 + 갈기
                        FE(g, Draw.Lighten(body, 0.10), -w * 0.34f, -h * 1.42f, w * 0.62f, h * 0.60f);
                        FE(g, stone, -w * 0.26f, -h * 1.34f, w * 0.46f, h * 0.46f);
                        FE(g, Pal.Ink, -w * 0.18f, -h * 1.20f, w * 0.07f, h * 0.07f);
                        FE(g, Pal.Ink, -w * 0.02f, -h * 1.20f, w * 0.07f, h * 0.07f);
                        FE(g, gold, -w * 0.16f, -h * 1.02f, w * 0.22f, h * 0.11f);
                        break;
                    }

                case LandmarkKind.Pyramid:
                    {
                        FP(g, Draw.Lighten(body, 0.34), P(-w * 0.78f, 0), P(w * 0.10f, 0), P(-w * 0.06f, -h * 1.20f));
                        FP(g, Draw.Darken(body, 0.22), P(w * 0.10f, 0), P(w * 0.78f, 0), P(-w * 0.06f, -h * 1.20f));
                        for (int i = 1; i <= 3; i++)
                        {
                            float t = i / 4f;
                            LN(g, Draw.A(deep, 120), w * 0.05f,
                                -w * 0.78f + (w * 0.72f) * t, -h * 1.20f * t + h * 0.0f,
                                 w * 0.78f - (w * 0.84f) * t, -h * 1.20f * t);
                        }
                        // 앞쪽 스핑크스
                        FE(g, stone, -w * 0.92f, -h * 0.34f, w * 0.52f, h * 0.22f);
                        FE(g, stone, -w * 0.98f, -h * 0.52f, w * 0.24f, h * 0.24f);
                        FR(g, gold, -w * 0.96f, -h * 0.52f, w * 0.20f, h * 0.06f);
                        break;
                    }

                case LandmarkKind.Mosque:
                    {
                        FR(g, stoneD, -w * 0.56f, -h * 0.14f, w * 1.12f, h * 0.14f);
                        FR(g, stone, -w * 0.40f, -h * 0.66f, w * 0.80f, h * 0.52f);
                        FR(g, dark, w * 0.10f, -h * 0.66f, w * 0.30f, h * 0.52f);
                        OnionDomeShape(g, Draw.Lighten(body, 0.15), gold, 0, -h * 0.66f, w * 0.34f, h * 0.42f);
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float cx = s * w * 0.62f;
                            FR(g, stone, cx - w * 0.07f, -h * 1.18f, w * 0.14f, h * 1.04f);
                            FR(g, gold, cx - w * 0.10f, -h * 0.80f, w * 0.20f, h * 0.05f);
                            Spire(g, deep, cx, -h * 1.18f, w * 0.11f, h * 0.30f);
                        }
                        break;
                    }

                case LandmarkKind.Parthenon:
                    {
                        for (int i = 0; i < 3; i++)
                            FR(g, i == 0 ? stoneD : Draw.Lighten(stoneD, 0.08f * i),
                                -w * (0.78f - i * 0.05f), -h * (0.08f + i * 0.08f), w * (1.56f - i * 0.10f), h * 0.09f);
                        float py = -h * 0.32f;
                        for (int i = 0; i < 6; i++)
                        {
                            float x = -w * 0.60f + i * w * 0.24f;
                            FR(g, stone, x - w * 0.055f, py - h * 0.70f, w * 0.11f, h * 0.70f);
                            FR(g, dark, x + w * 0.015f, py - h * 0.70f, w * 0.04f, h * 0.70f);
                        }
                        FR(g, Draw.Lighten(body, 0.22), -w * 0.72f, -h * 1.14f, w * 1.44f, h * 0.12f);
                        FP(g, Draw.Lighten(body, 0.34), P(-w * 0.76f, -h * 1.14f), P(w * 0.76f, -h * 1.14f), P(0, -h * 1.52f));
                        LN(g, gold, w * 0.06f, -w * 0.72f, -h * 1.14f, w * 0.72f, -h * 1.14f);
                        break;
                    }

                case LandmarkKind.Colosseum:
                    {
                        FR(g, stoneD, -w * 0.72f, -h * 0.12f, w * 1.44f, h * 0.12f);
                        // 위로 갈수록 한쪽이 무너진 타원형 외벽
                        FP(g, stone, P(-w * 0.66f, -h * 0.12f), P(w * 0.66f, -h * 0.12f),
                                     P(w * 0.60f, -h * 0.86f), P(w * 0.16f, -h * 1.10f),
                                     P(-w * 0.34f, -h * 1.10f), P(-w * 0.62f, -h * 0.90f));
                        FP(g, dark, P(w * 0.20f, -h * 0.12f), P(w * 0.66f, -h * 0.12f),
                                    P(w * 0.60f, -h * 0.86f), P(w * 0.20f, -h * 1.06f));
                        for (int row = 0; row < 2; row++)
                        {
                            float ay = -h * (0.34f + row * 0.34f);
                            for (int i = 0; i < 5; i++)
                            {
                                float x = -w * 0.50f + i * w * 0.25f;
                                FPie(g, Draw.Darken(body, 0.52), x - w * 0.08f, ay - h * 0.10f, w * 0.16f, h * 0.20f, 180, 180);
                                FR(g, Draw.Darken(body, 0.52), x - w * 0.08f, ay, w * 0.16f, h * 0.14f);
                            }
                        }
                        LN(g, gold, w * 0.05f, -w * 0.64f, -h * 0.12f, w * 0.64f, -h * 0.12f);
                        break;
                    }

                case LandmarkKind.ArchGate:
                    {
                        FR(g, stoneD, -w * 0.76f, -h * 0.10f, w * 1.52f, h * 0.10f);
                        FR(g, stone, -w * 0.70f, -h * 1.06f, w * 1.40f, h * 0.96f);
                        FR(g, dark, w * 0.30f, -h * 1.06f, w * 0.40f, h * 0.96f);
                        // 중앙 큰 아치 + 좌우 작은 아치
                        FPie(g, Pal.Bg0, -w * 0.24f, -h * 0.94f, w * 0.48f, h * 0.48f, 180, 180);
                        FR(g, Pal.Bg0, -w * 0.24f, -h * 0.70f, w * 0.48f, h * 0.60f);
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float cx = s * w * 0.48f;
                            FPie(g, Pal.Bg0, cx - w * 0.13f, -h * 0.66f, w * 0.26f, h * 0.26f, 180, 180);
                            FR(g, Pal.Bg0, cx - w * 0.13f, -h * 0.53f, w * 0.26f, h * 0.43f);
                        }
                        FR(g, Draw.Lighten(body, 0.30), -w * 0.78f, -h * 1.22f, w * 1.56f, h * 0.16f);
                        LN(g, gold, w * 0.05f, -w * 0.78f, -h * 1.22f, w * 0.78f, -h * 1.22f);
                        for (int i = -1; i <= 1; i++)
                            FE(g, gold, i * w * 0.34f - w * 0.06f, -h * 1.38f, w * 0.12f, h * 0.16f);
                        break;
                    }

                case LandmarkKind.Mermaid:
                    {
                        // 바닷물
                        FE(g, Color.FromArgb(120, 90, 170, 235), -w * 0.95f, -h * 0.18f, w * 1.9f, h * 0.28f);
                        // 바위
                        FP(g, Draw.Darken(body, 0.38), P(-w * 0.52f, -h * 0.06f), P(w * 0.52f, -h * 0.06f),
                                                       P(w * 0.30f, -h * 0.46f), P(-w * 0.34f, -h * 0.44f));
                        // 앉은 인어
                        FE(g, stone, -w * 0.14f, -h * 1.16f, w * 0.30f, h * 0.32f);       // 머리
                        FP(g, Draw.Lighten(body, 0.18), P(-w * 0.16f, -h * 0.90f), P(w * 0.18f, -h * 0.90f),
                                                        P(w * 0.10f, -h * 0.44f), P(-w * 0.12f, -h * 0.44f));  // 상체
                        FP(g, Draw.Lighten(body, 0.02), P(-w * 0.12f, -h * 0.48f), P(w * 0.12f, -h * 0.48f),
                                                        P(w * 0.62f, -h * 0.20f), P(w * 0.30f, -h * 0.18f));   // 꼬리
                        FP(g, gold, P(w * 0.52f, -h * 0.28f), P(w * 0.78f, -h * 0.46f), P(w * 0.80f, -h * 0.10f));
                        break;
                    }

                case LandmarkKind.Dolharubang:
                    {
                        Color rock = Draw.Mix(body, Color.FromArgb(120, 118, 116), 0.5);
                        FR(g, Draw.Darken(rock, 0.35), -w * 0.52f, -h * 0.12f, w * 1.04f, h * 0.12f);
                        // 몸통
                        FP(g, rock, P(-w * 0.44f, -h * 0.12f), P(w * 0.44f, -h * 0.12f),
                                    P(w * 0.34f, -h * 0.92f), P(-w * 0.34f, -h * 0.92f));
                        FP(g, Draw.Darken(rock, 0.25), P(w * 0.14f, -h * 0.12f), P(w * 0.44f, -h * 0.12f),
                                                       P(w * 0.34f, -h * 0.92f), P(w * 0.12f, -h * 0.92f));
                        // 벙거지 모자
                        FE(g, Draw.Darken(rock, 0.14), -w * 0.42f, -h * 1.22f, w * 0.84f, h * 0.40f);
                        FE(g, Draw.Darken(rock, 0.05), -w * 0.30f, -h * 1.42f, w * 0.60f, h * 0.36f);
                        // 왕방울 눈 · 코
                        FE(g, Draw.Lighten(rock, 0.30), -w * 0.26f, -h * 0.86f, w * 0.20f, h * 0.20f);
                        FE(g, Draw.Lighten(rock, 0.30), w * 0.06f, -h * 0.86f, w * 0.20f, h * 0.20f);
                        FE(g, Pal.Ink, -w * 0.21f, -h * 0.81f, w * 0.10f, h * 0.10f);
                        FE(g, Pal.Ink, w * 0.11f, -h * 0.81f, w * 0.10f, h * 0.10f);
                        FE(g, Draw.Darken(rock, 0.22), -w * 0.08f, -h * 0.66f, w * 0.16f, h * 0.18f);
                        // 배 위에 얹은 두 손
                        LN(g, Draw.Darken(rock, 0.30), w * 0.07f, -w * 0.22f, -h * 0.36f, w * 0.22f, -h * 0.36f);
                        break;
                    }

                case LandmarkKind.CityHall:
                    {
                        Color brick = Draw.Mix(body, Color.FromArgb(150, 62, 48), 0.45);
                        FR(g, Draw.Darken(brick, 0.30), -w * 0.62f, -h * 0.14f, w * 1.24f, h * 0.14f);
                        FR(g, brick, -w * 0.58f, -h * 0.62f, w * 1.16f, h * 0.48f);
                        FR(g, Draw.Darken(brick, 0.22), w * 0.16f, -h * 0.62f, w * 0.42f, h * 0.48f);
                        FR(g, brick, -w * 0.22f, -h * 1.42f, w * 0.44f, h * 0.80f);
                        FR(g, Draw.Darken(brick, 0.22), w * 0.06f, -h * 1.42f, w * 0.16f, h * 0.80f);
                        for (int i = 0; i < 3; i++)
                            FR(g, glass, -w * 0.15f, -h * (1.30f - i * 0.22f), w * 0.10f, h * 0.13f);
                        Spire(g, Draw.Lighten(brick, 0.10), 0, -h * 1.42f, w * 0.26f, h * 0.34f);
                        // 세 왕관
                        LN(g, gold, w * 0.07f, 0, -h * 1.76f, 0, -h * 1.94f);
                        for (int i = -1; i <= 1; i++)
                            FE(g, gold, i * w * 0.12f - w * 0.05f, -h * 2.04f, w * 0.10f, h * 0.12f);
                        break;
                    }

                case LandmarkKind.ClockTower:
                    {
                        FR(g, stoneD, -w * 0.46f, -h * 0.12f, w * 0.92f, h * 0.12f);
                        FR(g, stone, -w * 0.36f, -h * 1.24f, w * 0.72f, h * 1.12f);
                        FR(g, dark, w * 0.12f, -h * 1.24f, w * 0.24f, h * 1.12f);
                        // 아치 통로
                        FPie(g, Pal.Bg0, -w * 0.18f, -h * 0.62f, w * 0.36f, h * 0.36f, 180, 180);
                        FR(g, Pal.Bg0, -w * 0.18f, -h * 0.44f, w * 0.36f, h * 0.32f);
                        // 시계
                        FE(g, deep, -w * 0.28f, -h * 1.14f, w * 0.56f, h * 0.56f);
                        FE(g, Color.FromArgb(252, 248, 230), -w * 0.23f, -h * 1.09f, w * 0.46f, h * 0.46f);
                        LN(g, Pal.Ink, w * 0.06f, 0, -h * 0.86f, 0, -h * 1.02f);
                        LN(g, Pal.Ink, w * 0.06f, 0, -h * 0.86f, w * 0.14f, -h * 0.86f);
                        FP(g, Draw.Darken(body, 0.42), P(-w * 0.44f, -h * 1.24f), P(w * 0.44f, -h * 1.24f), P(0, -h * 1.74f));
                        break;
                    }

                case LandmarkKind.AstroClock:
                    {
                        FR(g, stoneD, -w * 0.42f, -h * 0.12f, w * 0.84f, h * 0.12f);
                        FR(g, stone, -w * 0.32f, -h * 1.30f, w * 0.64f, h * 1.18f);
                        FR(g, dark, w * 0.10f, -h * 1.30f, w * 0.22f, h * 1.18f);
                        // 위아래 두 개의 원판 (천문시계 + 달력판)
                        FE(g, Color.FromArgb(30, 40, 90), -w * 0.25f, -h * 1.18f, w * 0.50f, h * 0.50f);
                        FE(g, gold, -w * 0.19f, -h * 1.12f, w * 0.38f, h * 0.38f);
                        FE(g, Color.FromArgb(30, 40, 90), -w * 0.09f, -h * 1.02f, w * 0.18f, h * 0.18f);
                        FE(g, deep, -w * 0.20f, -h * 0.64f, w * 0.40f, h * 0.40f);
                        LN(g, gold, w * 0.05f, -w * 0.20f, -h * 0.44f, w * 0.20f, -h * 0.44f);
                        // 뾰족한 고딕 지붕 + 작은 첨탑 4개
                        FP(g, Draw.Darken(body, 0.45), P(-w * 0.40f, -h * 1.30f), P(w * 0.40f, -h * 1.30f), P(0, -h * 1.90f));
                        for (int s = -1; s <= 1; s += 2)
                            Spire(g, Draw.Darken(body, 0.45), s * w * 0.34f, -h * 1.30f, w * 0.09f, h * 0.28f);
                        break;
                    }

                case LandmarkKind.WaterVilla:
                    {
                        FR(g, Color.FromArgb(150, 80, 175, 225), -w, -h * 0.10f, w * 2, h * 0.30f);
                        for (int i = -1; i <= 1; i++)
                            LN(g, Draw.Darken(body, 0.45), w * 0.07f,
                                i * w * 0.30f, -h * 0.06f, i * w * 0.30f, -h * 0.46f);
                        FR(g, Draw.Lighten(body, 0.16), -w * 0.52f, -h * 0.72f, w * 1.04f, h * 0.28f);
                        FR(g, dark, w * 0.14f, -h * 0.72f, w * 0.38f, h * 0.28f);
                        // 초가 지붕
                        FP(g, Draw.Mix(body, Color.FromArgb(196, 152, 84), 0.6),
                            P(-w * 0.66f, -h * 0.72f), P(w * 0.66f, -h * 0.72f), P(0, -h * 1.32f));
                        LN(g, deep, w * 0.05f, -w * 0.40f, -h * 0.94f, w * 0.40f, -h * 0.94f);
                        FR(g, glass, -w * 0.14f, -h * 0.66f, w * 0.20f, h * 0.16f);
                        // 물가 계단
                        LN(g, Draw.Lighten(body, 0.30), w * 0.06f, -w * 0.52f, -h * 0.50f, -w * 0.86f, -h * 0.10f);
                        break;
                    }

                case LandmarkKind.Brandenburg:
                    {
                        FR(g, stoneD, -w * 0.78f, -h * 0.10f, w * 1.56f, h * 0.10f);
                        for (int i = 0; i < 6; i++)
                        {
                            float x = -w * 0.62f + i * w * 0.248f;
                            FR(g, stone, x - w * 0.058f, -h * 0.98f, w * 0.116f, h * 0.88f);
                            FR(g, dark, x + w * 0.016f, -h * 0.98f, w * 0.042f, h * 0.88f);
                        }
                        FR(g, Draw.Lighten(body, 0.26), -w * 0.76f, -h * 1.16f, w * 1.52f, h * 0.18f);
                        LN(g, gold, w * 0.05f, -w * 0.76f, -h * 1.16f, w * 0.76f, -h * 1.16f);
                        // 쿼드리가 — 마차와 말
                        FR(g, deep, -w * 0.10f, -h * 1.34f, w * 0.20f, h * 0.18f);
                        for (int i = 0; i < 3; i++)
                        {
                            float x = w * (0.06f + i * 0.16f);
                            FR(g, gold, x, -h * 1.36f, w * 0.10f, h * 0.14f);
                            LN(g, gold, w * 0.05f, x + w * 0.09f, -h * 1.36f, x + w * 0.15f, -h * 1.44f);
                        }
                        break;
                    }

                case LandmarkKind.OnionDome:
                    {
                        FR(g, stoneD, -w * 0.64f, -h * 0.14f, w * 1.28f, h * 0.14f);
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float cx = s * w * 0.46f;
                            FR(g, stone, cx - w * 0.17f, -h * 0.72f, w * 0.34f, h * 0.58f);
                            OnionDomeShape(g, s < 0 ? Color.FromArgb(214, 86, 74) : Color.FromArgb(74, 158, 214),
                                gold, cx, -h * 0.72f, w * 0.21f, h * 0.30f);
                        }
                        FR(g, stone, -w * 0.24f, -h * 1.00f, w * 0.48f, h * 0.86f);
                        FR(g, dark, w * 0.06f, -h * 1.00f, w * 0.18f, h * 0.86f);
                        OnionDomeShape(g, Draw.Lighten(body, 0.18), gold, 0, -h * 1.00f, w * 0.30f, h * 0.46f);
                        FR(g, gold, -w * 0.26f, -h * 1.04f, w * 0.52f, h * 0.06f);
                        break;
                    }

                case LandmarkKind.Eiffel:
                    {
                        Color iron = Draw.Mix(body, Color.FromArgb(150, 116, 82), 0.45);
                        Color ironD = Draw.Darken(iron, 0.28);
                        float top = -h * 1.90f;
                        // 네 다리 (좌우 대칭 사다리꼴)
                        FP(g, iron, P(-w * 0.80f, 0), P(-w * 0.46f, 0), P(-w * 0.10f, top), P(-w * 0.05f, top));
                        FP(g, ironD, P(w * 0.46f, 0), P(w * 0.80f, 0), P(w * 0.05f, top), P(w * 0.10f, top));
                        FP(g, iron, P(-w * 0.60f, 0), P(-w * 0.40f, 0), P(-w * 0.05f, top), P(-w * 0.02f, top));
                        FP(g, ironD, P(w * 0.40f, 0), P(w * 0.60f, 0), P(w * 0.02f, top), P(w * 0.05f, top));
                        // 아래 아치
                        using (var pen = new Pen(iron, Math.Max(1f, w * 0.09f)))
                            g.DrawArc(pen, -w * 0.58f, -h * 0.62f, w * 1.16f, h * 0.62f, 180, 180);
                        // 전망대 2층
                        FR(g, ironD, -w * 0.56f, -h * 0.66f, w * 1.12f, h * 0.10f);
                        FR(g, ironD, -w * 0.26f, -h * 1.16f, w * 0.52f, h * 0.09f);
                        LN(g, gold, w * 0.05f, -w * 0.54f, -h * 0.66f, w * 0.54f, -h * 0.66f);
                        // 첨탑
                        LN(g, gold, w * 0.07f, 0, top, 0, top - h * 0.26f);
                        FE(g, Color.FromArgb(255, 255, 244, 200), -h * 0.06f, top - h * 0.34f, h * 0.12f, h * 0.12f);
                        break;
                    }

                case LandmarkKind.BigBen:
                    {
                        FR(g, stoneD, -w * 0.40f, -h * 0.12f, w * 0.80f, h * 0.12f);
                        FR(g, stone, -w * 0.28f, -h * 1.34f, w * 0.56f, h * 1.22f);
                        FR(g, dark, w * 0.09f, -h * 1.34f, w * 0.19f, h * 1.22f);
                        for (int i = 0; i < 4; i++)
                            FR(g, Draw.Darken(body, 0.40), -w * 0.20f, -h * (0.34f + i * 0.19f), w * 0.40f, h * 0.11f);
                        // 시계면
                        FE(g, deep, -w * 0.26f, -h * 1.30f, w * 0.52f, h * 0.52f);
                        FE(g, Color.FromArgb(253, 246, 222), -w * 0.21f, -h * 1.25f, w * 0.42f, h * 0.42f);
                        LN(g, Pal.Ink, w * 0.06f, 0, -h * 1.04f, 0, -h * 1.20f);
                        LN(g, Pal.Ink, w * 0.06f, 0, -h * 1.04f, w * 0.12f, -h * 1.00f);
                        // 고딕 첨탑
                        FR(g, Draw.Lighten(body, 0.18), -w * 0.32f, -h * 1.46f, w * 0.64f, h * 0.12f);
                        Spire(g, Draw.Darken(body, 0.45), 0, -h * 1.46f, w * 0.30f, h * 0.52f);
                        for (int s = -1; s <= 1; s += 2)
                            Spire(g, Draw.Darken(body, 0.45), s * w * 0.26f, -h * 1.46f, w * 0.08f, h * 0.24f);
                        LN(g, gold, w * 0.05f, 0, -h * 1.98f, 0, -h * 2.10f);
                        break;
                    }

                case LandmarkKind.Opera:
                    {
                        FR(g, Color.FromArgb(140, 80, 170, 225), -w, -h * 0.06f, w * 2, h * 0.24f);
                        FR(g, stoneD, -w * 0.86f, -h * 0.20f, w * 1.72f, h * 0.14f);
                        // 조개 껍질 — 뒤에서 앞으로 겹쳐 그린다
                        float[] sx = { -0.42f, -0.06f, 0.30f, 0.62f };
                        float[] sc = { 1.00f, 0.86f, 0.66f, 0.44f };
                        for (int i = 0; i < 4; i++)
                        {
                            float sw = w * 0.62f * sc[i], sh2 = h * 1.20f * sc[i];
                            FPie(g, i % 2 == 0 ? Color.FromArgb(246, 248, 252) : Color.FromArgb(224, 230, 242),
                                w * sx[i] - sw * 0.5f, -h * 0.20f - sh2, sw, sh2 * 2f, 182, 96);
                        }
                        LN(g, gold, w * 0.05f, -w * 0.86f, -h * 0.20f, w * 0.86f, -h * 0.20f);
                        break;
                    }

                case LandmarkKind.Liberty:
                    {
                        Color patina = Draw.Mix(body, Color.FromArgb(96, 186, 162), 0.55);
                        // 별 모양 기단
                        FP(g, stoneD, P(-w * 0.66f, 0), P(w * 0.66f, 0), P(w * 0.46f, -h * 0.26f), P(-w * 0.46f, -h * 0.26f));
                        FR(g, Draw.Darken(body, 0.34), -w * 0.34f, -h * 0.58f, w * 0.68f, h * 0.32f);
                        // 로브
                        FP(g, patina, P(-w * 0.30f, -h * 0.58f), P(w * 0.30f, -h * 0.58f),
                                      P(w * 0.14f, -h * 1.30f), P(-w * 0.14f, -h * 1.30f));
                        FP(g, Draw.Darken(patina, 0.22), P(w * 0.06f, -h * 0.58f), P(w * 0.30f, -h * 0.58f),
                                                         P(w * 0.14f, -h * 1.30f), P(w * 0.02f, -h * 1.30f));
                        // 머리 + 왕관
                        FE(g, patina, -w * 0.13f, -h * 1.50f, w * 0.26f, h * 0.26f);
                        for (int i = -2; i <= 2; i++)
                            FP(g, patina, P(i * w * 0.09f - w * 0.03f, -h * 1.50f),
                                          P(i * w * 0.09f + w * 0.03f, -h * 1.50f),
                                          P(i * w * 0.09f, -h * 1.50f - h * 0.18f));
                        // 치켜든 횃불
                        LN(g, patina, w * 0.09f, w * 0.10f, -h * 1.16f, w * 0.44f, -h * 1.62f);
                        FP(g, gold, P(w * 0.36f, -h * 1.62f), P(w * 0.52f, -h * 1.62f), P(w * 0.44f, -h * 1.86f));
                        FE(g, Color.FromArgb(255, 255, 240, 190), w * 0.38f, -h * 1.96f, w * 0.12f, h * 0.14f);
                        break;
                    }

                case LandmarkKind.TokyoTower:
                    {
                        Color steel = Draw.Mix(body, Color.FromArgb(228, 74, 52), 0.55);
                        Color steelD = Draw.Darken(steel, 0.26);
                        float top = -h * 1.80f;
                        FP(g, steel, P(-w * 0.74f, 0), P(-w * 0.42f, 0), P(-w * 0.07f, top), P(-w * 0.03f, top));
                        FP(g, steelD, P(w * 0.42f, 0), P(w * 0.74f, 0), P(w * 0.03f, top), P(w * 0.07f, top));
                        // 격자 트러스
                        for (int i = 0; i < 5; i++)
                        {
                            float t0 = i / 5f, t1 = (i + 1) / 5f;
                            float y0 = -h * 1.80f * t0, y1 = -h * 1.80f * t1;
                            float x0 = w * (0.58f - 0.53f * t0), x1 = w * (0.58f - 0.53f * t1);
                            LN(g, Draw.A(steelD, 190), w * 0.045f, -x0, y0, x1, y1);
                            LN(g, Draw.A(steelD, 190), w * 0.045f, x0, y0, -x1, y1);
                        }
                        // 전망대 2개
                        FR(g, Draw.Lighten(steel, 0.20), -w * 0.40f, -h * 0.78f, w * 0.80f, h * 0.16f);
                        FR(g, Draw.Lighten(steel, 0.20), -w * 0.20f, -h * 1.42f, w * 0.40f, h * 0.11f);
                        LN(g, gold, w * 0.05f, -w * 0.40f, -h * 0.78f, w * 0.40f, -h * 0.78f);
                        // 안테나
                        LN(g, Draw.Lighten(steel, 0.30), w * 0.06f, 0, top, 0, top - h * 0.30f);
                        FE(g, Color.FromArgb(255, 255, 120, 110), -h * 0.05f, top - h * 0.38f, h * 0.10f, h * 0.10f);
                        break;
                    }

                case LandmarkKind.NamsanTower:
                    {
                        // 남산
                        FP(g, Draw.Darken(body, 0.42), P(-w, -h * 0.02f), P(w, -h * 0.02f),
                                                       P(w * 0.34f, -h * 0.40f), P(-w * 0.36f, -h * 0.40f));
                        FR(g, stoneD, -w * 0.24f, -h * 0.40f, w * 0.48f, h * 0.14f);
                        // 기둥
                        FR(g, stone, -w * 0.15f, -h * 1.20f, w * 0.30f, h * 0.80f);
                        FR(g, dark, w * 0.04f, -h * 1.20f, w * 0.11f, h * 0.80f);
                        // 원반 전망대 (2단)
                        FE(g, Draw.Lighten(body, 0.26), -w * 0.46f, -h * 1.34f, w * 0.92f, h * 0.26f);
                        FE(g, dark, -w * 0.46f, -h * 1.28f, w * 0.92f, h * 0.16f);
                        FE(g, glass, -w * 0.38f, -h * 1.31f, w * 0.76f, h * 0.13f);
                        FE(g, Draw.Lighten(body, 0.16), -w * 0.32f, -h * 1.54f, w * 0.64f, h * 0.22f);
                        LN(g, gold, w * 0.05f, -w * 0.44f, -h * 1.22f, w * 0.44f, -h * 1.22f);
                        // 안테나
                        LN(g, Draw.Lighten(body, 0.30), w * 0.07f, 0, -h * 1.52f, 0, -h * 2.02f);
                        FE(g, Color.FromArgb(255, 255, 246, 205), -h * 0.05f, -h * 2.12f, h * 0.10f, h * 0.10f);
                        break;
                    }
            }
        }

        // ================= 캐릭터 말 =================

        /// <summary>
        /// 태양 광선 한 겹. 안쪽 반지름과 가시 끝을 번갈아 찍어 <b>뾰족한</b> 별 모양을 만든다.
        ///
        /// 매끄러운 파형으로 둘레를 흔들면 아무리 진폭을 키워도 울렁이는 원으로 보인다.
        /// 태양처럼 보이려면 뿌리와 끝이 각을 이뤄야 하고, 가시마다 길이가 따로 늘었다 줄어야 한다.
        /// </summary>
        static void SunRays(Graphics g, float cx, float cy, float innerR, float spikeR,
                            int n, double t, double phase, Color c, int alpha)
        {
            if (alpha <= 2 || innerR <= 0) return;
            var pts = new PointF[n * 2];
            for (int k = 0; k < n * 2; k++)
            {
                double th = k * Math.PI / n + t * 0.22 + phase;
                float rad = innerR;
                if (k % 2 == 0)
                {
                    int s = k / 2;
                    // 가시마다 위상이 달라 따로 뻗었다 오므라든다
                    double v = 0.5 + 0.5 * Math.Sin(t * 2.4 + s * 2.19 + phase * 3.0);
                    double v2 = 0.5 + 0.5 * Math.Sin(t * 1.33 + s * 0.81 - phase);
                    rad = innerR + spikeR * (float)(0.30 + 0.70 * (v * 0.65 + v2 * 0.35));
                }
                pts[k] = new PointF(cx + (float)Math.Cos(th) * rad, cy + (float)Math.Sin(th) * rad);
            }
            using (var b = new SolidBrush(Draw.A(c, Math.Min(255, alpha))))
                g.FillPolygon(b, pts);
        }

        public static void DrawToken(Graphics g, float cx, float cy, float r, Color c, double squash,
                                     bool active, int emote, double time, double alpha)
        {
            DrawToken(g, cx, cy, r, c, squash, active, emote, time, alpha, 0);
        }

        public static void DrawToken(Graphics g, float cx, float cy, float r, Color c, double squash,
                                     bool active, int emote, double time, double alpha, int face)
        {
            float sx = (float)(1 + squash * 0.45), sy = (float)(1 - squash * 0.38);
            int a = (int)(255 * alpha);

            // 숨쉬듯 밝아졌다 사그라드는 흰빛. 말마다 time 이 조금씩 달라서 따로 논다.
            // 0 까지 꺼지면 깜빡이는 것처럼 보이므로 가장 밝을 때의 0.5 아래로는 안 내려간다.
            double glow = 0.75 + 0.25 * Math.Sin(time * 2.1);

            // 말 뒤의 태양 광선. 원반이나 테두리 같은 둥근 요소는 두지 않는다 —
            // 가시와 따로 놀아서 이질감이 생긴다. 대신 가시를 진하게 뽑아 그 몫까지 맡긴다.
            // 색은 말과 같아서 캐릭터에서 뻗어 나온 불꽃처럼 보이고, 흰 칸 위에서도 대비가 남는다.
            SunRays(g, cx, cy, r * 1.00f, r * 0.87f, 12, time, 0.0,
                c, (int)(alpha * (0.75 + 0.25 * Math.Sin(time * 2.1 + 1.2)) * 110));
            SunRays(g, cx, cy, r * 1.00f, r * 0.59f, 19, -time, 1.7,
                c, (int)(alpha * (0.75 + 0.25 * Math.Sin(time * 2.1 + 0.5)) * 150));
            SunRays(g, cx, cy, r * 1.02f, r * 0.32f, 28, time * 1.4, 3.1,
                c, (int)(alpha * glow * 195));

            using (var b = new SolidBrush(Draw.A(Color.Black, (int)(75 * alpha))))
                g.FillEllipse(b, cx - r * 0.88f, cy + r * 0.62f, r * 1.76f, r * 0.52f);

            var st = g.Save();
            g.TranslateTransform(cx, cy);
            g.ScaleTransform(sx, sy);

            // 몸통
            var body = new RectangleF(-r, -r, r * 2, r * 2);
            using (var br = new LinearGradientBrush(
                new RectangleF(body.X, body.Y - 1, body.Width, body.Height + 2),
                Draw.A(Draw.Lighten(c, 0.42), a), Draw.A(Draw.Darken(c, 0.22), a), 90f))
                g.FillEllipse(br, body);
            using (var pen = new Pen(Draw.A(Draw.Darken(c, 0.45), a), Math.Max(1f, r * 0.13f)))
                g.DrawEllipse(pen, body);

            // 하이라이트
            using (var br = new SolidBrush(Draw.A(Color.White, (int)(110 * alpha))))
                g.FillEllipse(br, -r * 0.55f, -r * 0.78f, r * 0.6f, r * 0.42f);

            // 눈
            float ey = -r * 0.05f, ex = r * 0.34f, er = r * 0.235f;
            using (var br = new SolidBrush(Draw.A(Color.White, a)))
            {
                g.FillEllipse(br, -ex - er, ey - er, er * 2, er * 2);
                g.FillEllipse(br, ex - er, ey - er, er * 2, er * 2);
            }
            double look = Math.Sin(time * 1.6) * er * 0.28;
            float pr = er * 0.52f;
            using (var br = new SolidBrush(Draw.A(Color.FromArgb(24, 26, 40), a)))
            {
                if (emote == 2) // 슬픔: 감은 눈
                {
                    using (var pen = new Pen(Draw.A(Color.FromArgb(24, 26, 40), a), Math.Max(1f, r * 0.11f)))
                    {
                        g.DrawArc(pen, -ex - er, ey - er * 0.4f, er * 2, er * 1.4f, 200, 140);
                        g.DrawArc(pen, ex - er, ey - er * 0.4f, er * 2, er * 1.4f, 200, 140);
                    }
                }
                else
                {
                    float grow = emote == 3 ? 1.35f : 1f;
                    g.FillEllipse(br, (float)(-ex + look) - pr * grow, ey - pr * grow, pr * 2 * grow, pr * 2 * grow);
                    g.FillEllipse(br, (float)(ex + look) - pr * grow, ey - pr * grow, pr * 2 * grow, pr * 2 * grow);
                }
            }

            // 입
            using (var pen = new Pen(Draw.A(Color.FromArgb(40, 30, 40), a), Math.Max(1f, r * 0.1f)))
            {
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                float mw = r * 0.42f, my = r * 0.42f;
                if (emote == 1) g.DrawArc(pen, -mw / 2, my - r * 0.2f, mw, r * 0.4f, 20, 140);
                else if (emote == 2) g.DrawArc(pen, -mw / 2, my - r * 0.02f, mw, r * 0.4f, 200, 140);
                else if (emote == 3) g.DrawEllipse(pen, -mw * 0.22f, my - r * 0.1f, mw * 0.44f, r * 0.3f);
                else g.DrawArc(pen, -mw / 2, my - r * 0.16f, mw, r * 0.32f, 25, 130);
            }

            DrawHeadgear(g, face, r, a, time);
            g.Restore(st);

            if (active)
            {
                double bob = Math.Sin(time * 5.5) * r * 0.22;
                Draw.Triangle(g, Draw.A(Pal.Gold, a), cx, (float)(cy - r * 2.15 - bob), r * 0.85f, r * 0.72f, true);
                Draw.Triangle(g, Draw.A(Color.FromArgb(255, 240, 190), (int)(a * 0.9)),
                    cx, (float)(cy - r * 2.22 - bob), r * 0.5f, r * 0.42f, true);
            }
        }

        /// <summary>
        /// 모자 표장 — 금빛 월계관이 가운데 문양을 감싼 형태.
        /// 말이 작게 그려지므로 잎을 하나씩 세기보다 "금빛 고리 + 잎 돌기"로 읽히게 한다.
        /// </summary>
        static void CapBadge(Graphics g, float cx, float cy, float s, int a)
        {
            Color gold = Draw.A(Pal.Gold, a);
            Color goldD = Draw.A(Pal.GoldDeep, a);
            Color field = Draw.A(Color.FromArgb(24, 54, 40), a);

            FE(g, field, cx - s * 0.72f, cy - s * 0.72f, s * 1.44f, s * 1.44f);
            // 위가 트인 월계 가지
            using (var pen = new Pen(goldD, Math.Max(1.0f, s * 0.30f)))
                g.DrawArc(pen, cx - s * 0.88f, cy - s * 0.88f, s * 1.76f, s * 1.76f, 292, 316);
            // 잎 돌기
            for (int i = 0; i < 6; i++)
            {
                double ang = (302 + i * 51) * Math.PI / 180.0;
                float lx = cx + (float)Math.Cos(ang) * s * 0.88f;
                float ly = cy + (float)Math.Sin(ang) * s * 0.88f;
                FE(g, gold, lx - s * 0.19f, ly - s * 0.19f, s * 0.38f, s * 0.38f);
            }
            // 가운데 문양
            FE(g, gold, cx - s * 0.34f, cy - s * 0.42f, s * 0.68f, s * 0.84f);
            FE(g, Draw.A(Color.FromArgb(178, 40, 44), a), cx - s * 0.17f, cy - s * 0.26f, s * 0.34f, s * 0.46f);
        }

        /// <summary>입에 문 파이프 담배 — 연기가 천천히 피어오른다.</summary>
        static void Pipe(Graphics g, float r, int a, double time)
        {
            Color wood = Draw.A(Color.FromArgb(112, 66, 38), a);
            Color woodD = Draw.A(Color.FromArgb(70, 40, 24), a);
            Color bit = Draw.A(Color.FromArgb(40, 34, 44), a);

            using (var pen = new Pen(bit, Math.Max(1.1f, r * 0.15f)))
            {
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                g.DrawLine(pen, r * 0.14f, r * 0.46f, r * 0.64f, r * 0.62f);   // 물부리
            }
            using (var pen = new Pen(wood, Math.Max(1.2f, r * 0.17f)))
            {
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                g.DrawLine(pen, r * 0.60f, r * 0.61f, r * 1.06f, r * 0.70f);   // 대
            }
            // 대통
            FP(g, wood, P(r * 0.99f, r * 0.80f), P(r * 1.38f, r * 0.72f),
                        P(r * 1.28f, r * 0.20f), P(r * 1.02f, r * 0.26f));
            FE(g, woodD, r * 1.00f, r * 0.14f, r * 0.30f, r * 0.16f);
            FE(g, Draw.A(Color.FromArgb(228, 128, 52), (int)(a * 0.9)),
                r * 1.05f, r * 0.17f, r * 0.20f, r * 0.10f);                   // 불씨

            // 연기
            for (int i = 0; i < 3; i++)
            {
                double ph = ((time * 0.5) + i * 0.34) % 1.0;
                float sx = r * 1.14f + (float)(ph * r * 0.36);
                float sy = r * 0.12f - (float)(ph * r * 1.00);
                float sr = r * (0.12f + (float)ph * 0.17f);
                FE(g, Draw.A(Color.White, (int)(a * 0.32 * (1 - ph))), sx - sr, sy - sr, sr * 2, sr * 2);
            }
        }

        /// <summary>
        /// 말마다 다른 머리·안경. 얼굴 원(반지름 r, 원점 중앙) 위에 덧그린다.
        /// 0 = 사람(탐험가 베레모+머플러), 1 = 비행모+고글, 2 = 두건+뿔테, 3 = 뒤집어쓴 캡+동그란 안경.
        /// </summary>
        static void DrawHeadgear(Graphics g, int face, float r, int a, double time)
        {
            Color line = Draw.A(Color.FromArgb(40, 34, 56), a);
            float lw = Math.Max(0.9f, r * 0.10f);

            switch (face)
            {
                case 0:   // ---- 내 말 : 베레모 · 월계관 표장 · 파이프 ----
                    {
                        Color hat = Draw.A(Color.FromArgb(198, 58, 62), a);
                        Color hatD = Draw.A(Color.FromArgb(150, 38, 44), a);

                        // 오른쪽으로 기운 베레모
                        FPie(g, hat, -r * 1.16f, -r * 1.30f, r * 2.32f, r * 1.52f, 178, 184);
                        FE(g, hatD, -r * 1.04f, -r * 0.72f, r * 2.08f, r * 0.34f);
                        FE(g, hat, r * 0.30f, -r * 1.34f, r * 0.30f, r * 0.28f);   // 꼭지
                        CapBadge(g, -r * 0.30f, -r * 0.82f, r * 0.46f, a);
                        Pipe(g, r, a, time);
                        break;
                    }

                case 1:   // ---- AI 1 : 조종사 (가죽 비행모 + 이마 고글) ----
                    {
                        Color cap = Draw.A(Color.FromArgb(134, 96, 62), a);
                        Color capD = Draw.A(Color.FromArgb(96, 66, 42), a);
                        Color lens = Draw.A(Color.FromArgb(120, 182, 210), a);

                        // 양옆 귀덮개
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float x = s < 0 ? -r * 1.16f : r * 0.56f;
                            FE(g, capD, x, -r * 0.36f, r * 0.60f, r * 1.16f);
                            FE(g, Draw.A(Color.FromArgb(206, 176, 132), a),
                                x + r * 0.13f, -r * 0.10f, r * 0.34f, r * 0.62f);
                        }
                        // 모자 본체
                        FPie(g, cap, -r * 1.06f, -r * 1.12f, r * 2.12f, r * 1.86f, 180, 180);
                        FR(g, cap, -r * 1.06f, -r * 0.24f, r * 2.12f, r * 0.14f);
                        FE(g, capD, -r * 1.06f, -r * 0.34f, r * 2.12f, r * 0.30f);
                        // 이마에 올린 고글
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float x = s < 0 ? -r * 0.88f : r * 0.14f;
                            FE(g, Draw.A(Color.FromArgb(228, 232, 240), a), x, -r * 0.96f, r * 0.74f, r * 0.62f);
                            FE(g, lens, x + r * 0.09f, -r * 0.89f, r * 0.56f, r * 0.46f);
                            FE(g, Draw.A(Color.White, (int)(a * 0.7)), x + r * 0.16f, -r * 0.84f, r * 0.20f, r * 0.14f);
                        }
                        LN(g, capD, r * 0.18f, -r * 0.16f, -r * 0.68f, r * 0.16f, -r * 0.68f);
                        break;
                    }

                case 2:   // ---- AI 2 : 청록 두건 + 뿔테 안경 ----
                    {
                        Color band = Draw.A(Color.FromArgb(86, 200, 206), a);
                        Color bandD = Draw.A(Color.FromArgb(52, 156, 168), a);
                        double flap = Math.Sin(time * 2.6) * r * 0.12;

                        // 뒤로 흘러내린 두건 자락
                        FP(g, bandD, P(-r * 0.72f, -r * 0.44f), P(-r * 1.42f, (float)(r * 0.10 + flap)),
                                     P(-r * 1.20f, (float)(r * 0.44 + flap)), P(-r * 0.60f, -r * 0.06f));
                        // 머리를 덮은 두건
                        FPie(g, band, -r * 1.08f, -r * 1.14f, r * 2.16f, r * 1.90f, 180, 180);
                        FR(g, band, -r * 1.08f, -r * 0.26f, r * 2.16f, r * 0.20f);
                        LN(g, bandD, r * 0.16f, -r * 1.02f, -r * 0.40f, r * 1.02f, -r * 0.40f);
                        FE(g, bandD, -r * 0.16f, -r * 1.16f, r * 0.34f, r * 0.26f);  // 매듭

                        // 네모 뿔테 안경
                        Color rim = Draw.A(Color.FromArgb(46, 40, 58), a);
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float x = s < 0 ? -r * 0.74f : r * 0.08f;
                            FR(g, Draw.A(Color.FromArgb(150, 226, 238, 250), a), x, -r * 0.34f, r * 0.66f, r * 0.52f);
                            using (var pen = new Pen(rim, lw))
                                g.DrawRectangle(pen, x, -r * 0.34f, r * 0.66f, r * 0.52f);
                        }
                        LN(g, rim, lw, -r * 0.08f, -r * 0.14f, r * 0.08f, -r * 0.14f);
                        break;
                    }

                default:  // ---- AI 3 : 뒤로 쓴 캡 + 동그란 안경 + 경례 ----
                    {
                        Color cap = Draw.A(Color.FromArgb(214, 219, 228), a);
                        Color capD = Draw.A(Color.FromArgb(166, 174, 188), a);

                        // 뒤로 향한 챙
                        FE(g, capD, -r * 1.52f, -r * 0.78f, r * 0.90f, r * 0.40f);
                        FPie(g, cap, -r * 1.04f, -r * 1.14f, r * 2.08f, r * 1.84f, 180, 180);
                        FR(g, cap, -r * 1.04f, -r * 0.28f, r * 2.08f, r * 0.16f);
                        LN(g, capD, r * 0.14f, 0, -r * 1.16f, 0, -r * 0.30f);
                        FE(g, capD, r * 0.72f, -r * 0.60f, r * 0.30f, r * 0.26f);   // 앞쪽 조절 버클

                        // 동그란 안경
                        Color rim = Draw.A(Color.FromArgb(46, 40, 58), a);
                        for (int s = -1; s <= 1; s += 2)
                        {
                            float x = s < 0 ? -r * 0.76f : r * 0.10f;
                            FE(g, Draw.A(Color.FromArgb(140, 226, 238, 250), a), x, -r * 0.36f, r * 0.66f, r * 0.62f);
                            using (var pen = new Pen(rim, lw))
                                g.DrawEllipse(pen, x, -r * 0.36f, r * 0.66f, r * 0.62f);
                        }
                        LN(g, rim, lw, -r * 0.10f, -r * 0.06f, r * 0.10f, -r * 0.06f);

                        // 경례하는 손
                        Color skin = Draw.A(Color.FromArgb(246, 214, 186), a);
                        FP(g, skin, P(r * 0.60f, -r * 0.66f), P(r * 1.34f, -r * 0.30f),
                                    P(r * 1.22f, -r * 0.02f), P(r * 0.56f, -r * 0.34f));
                        LN(g, line, lw * 0.8f, r * 0.66f, -r * 0.58f, r * 1.24f, -r * 0.24f);
                        break;
                    }
            }
        }

        // ================= 특수칸 아이콘 =================
        public static void DrawSpecial(Graphics g, CellType t, RectangleF r, double time)
        {
            float cx = r.X + r.Width / 2, cy = r.Y + r.Height / 2;
            float s = Math.Min(r.Width, r.Height);
            switch (t)
            {
                case CellType.Start:
                    {
                        var col = Color.FromArgb(34, 197, 94);
                        double p = 0.5 + 0.5 * Math.Sin(time * 3);
                        for (int i = 0; i < 3; i++)
                        {
                            float off = (float)(i * s * 0.16 - s * 0.16 + p * s * 0.05);
                            Draw.Triangle(g, Draw.A(col, 90 + i * 55), cx + off, cy, s * 0.3f, s * 0.42f, false);
                        }
                        break;
                    }
                case CellType.Jail:
                    {
                        using (var b = new SolidBrush(Color.FromArgb(56, 189, 248)))
                            g.FillEllipse(b, cx - s * 0.42f, cy - s * 0.05f, s * 0.84f, s * 0.36f);
                        using (var b = new SolidBrush(Color.FromArgb(250, 204, 21)))
                            g.FillPie(b, cx - s * 0.3f, cy - s * 0.08f, s * 0.6f, s * 0.34f, 180, 180);
                        using (var b = new SolidBrush(Color.FromArgb(120, 72, 40)))
                            g.FillRectangle(b, cx - s * 0.03f, cy - s * 0.34f, s * 0.06f, s * 0.28f);
                        using (var b = new SolidBrush(Color.FromArgb(22, 163, 74)))
                        {
                            double sway = Math.Sin(time * 2.2) * s * 0.03;
                            g.FillEllipse(b, cx - s * 0.28f + (float)sway, cy - s * 0.42f, s * 0.3f, s * 0.14f);
                            g.FillEllipse(b, cx - s * 0.02f + (float)sway, cy - s * 0.45f, s * 0.3f, s * 0.14f);
                            g.FillEllipse(b, cx - s * 0.16f + (float)sway, cy - s * 0.52f, s * 0.28f, s * 0.13f);
                        }
                        break;
                    }
                case CellType.Space:
                    {
                        double fl = 0.5 + 0.5 * Math.Sin(time * 14);
                        var st = g.Save();
                        g.TranslateTransform(cx, cy + (float)(Math.Sin(time * 2) * s * 0.03));
                        g.RotateTransform(-20);
                        using (var b = new SolidBrush(Color.FromArgb(255, 140, 60)))
                        {
                            var pts = new[] { new PointF(-s * 0.09f, s * 0.2f), new PointF(s * 0.09f, s * 0.2f),
                                              new PointF(0, (float)(s * (0.3 + fl * 0.16))) };
                            g.FillPolygon(b, pts);
                        }
                        using (var b = new SolidBrush(Color.FromArgb(236, 240, 250)))
                        {
                            var pts = new[]
                            {
                                new PointF(0, -s*0.4f), new PointF(s*0.14f, -s*0.02f),
                                new PointF(s*0.14f, s*0.2f), new PointF(-s*0.14f, s*0.2f),
                                new PointF(-s*0.14f, -s*0.02f)
                            };
                            g.FillPolygon(b, pts);
                        }
                        using (var b = new SolidBrush(Color.FromArgb(239, 68, 68)))
                        {
                            g.FillPolygon(b, new[] { new PointF(-s * 0.14f, s * 0.05f), new PointF(-s * 0.3f, s * 0.24f), new PointF(-s * 0.14f, s * 0.2f) });
                            g.FillPolygon(b, new[] { new PointF(s * 0.14f, s * 0.05f), new PointF(s * 0.3f, s * 0.24f), new PointF(s * 0.14f, s * 0.2f) });
                        }
                        using (var b = new SolidBrush(Color.FromArgb(96, 165, 250)))
                            g.FillEllipse(b, -s * 0.07f, -s * 0.22f, s * 0.14f, s * 0.14f);
                        g.Restore(st);
                        break;
                    }
                case CellType.Chance:
                    {
                        double sp = Math.Sin(time * 2.6) * 12;
                        var st = g.Save();
                        g.TranslateTransform(cx, cy);
                        g.RotateTransform((float)sp - 25);
                        using (var b = new SolidBrush(Pal.Gold))
                        {
                            g.FillEllipse(b, -s * 0.2f, -s * 0.34f, s * 0.4f, s * 0.4f);
                            g.FillRectangle(b, -s * 0.055f, -s * 0.02f, s * 0.11f, s * 0.4f);
                            g.FillRectangle(b, -s * 0.055f, s * 0.14f, s * 0.22f, s * 0.07f);
                            g.FillRectangle(b, -s * 0.055f, s * 0.28f, s * 0.19f, s * 0.07f);
                        }
                        using (var b = new SolidBrush(Pal.BoardBg))
                            g.FillEllipse(b, -s * 0.085f, -s * 0.23f, s * 0.17f, s * 0.17f);
                        g.Restore(st);
                        break;
                    }
                case CellType.FundPay:
                    {
                        Fx.DrawCoin(g, cx, cy + s * 0.06f, s * 0.2f, 255, 0);
                        Draw.Triangle(g, Color.FromArgb(248, 113, 113), cx, cy - s * 0.28f, s * 0.26f, s * 0.2f, true);
                        break;
                    }
                case CellType.FundGet:
                    {
                        Fx.DrawCoin(g, cx - s * 0.15f, cy + s * 0.14f, s * 0.16f, 255, 0);
                        Fx.DrawCoin(g, cx + s * 0.15f, cy + s * 0.14f, s * 0.16f, 255, 0);
                        Fx.DrawCoin(g, cx, cy - s * 0.06f, s * 0.19f, 255, 0);
                        double p = 0.5 + 0.5 * Math.Sin(time * 5);
                        Draw.Star(g, Draw.A(Color.White, (int)(120 + p * 120)), cx + s * 0.26f, cy - s * 0.26f, s * 0.1f, 4, time);
                        break;
                    }
                case CellType.Tax:
                    {
                        var col = Color.FromArgb(203, 213, 225);
                        using (var b = new SolidBrush(col))
                        {
                            g.FillRectangle(b, cx - s * 0.34f, cy + s * 0.2f, s * 0.68f, s * 0.08f);
                            for (int i = 0; i < 4; i++)
                                g.FillRectangle(b, cx - s * 0.28f + i * s * 0.18f, cy - s * 0.1f, s * 0.07f, s * 0.3f);
                        }
                        using (var b = new SolidBrush(Color.FromArgb(148, 163, 184)))
                            g.FillPolygon(b, new[]
                            {
                                new PointF(cx - s*0.38f, cy - s*0.1f), new PointF(cx, cy - s*0.36f),
                                new PointF(cx + s*0.38f, cy - s*0.1f)
                            });
                        break;
                    }
            }
        }
    }
}
