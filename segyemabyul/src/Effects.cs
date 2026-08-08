using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;

namespace Segyemabyul
{
    class Particle
    {
        public double X, Y, VX, VY, Life, MaxLife, Size, Rot, VRot, Grav, Drag = 1.0;
        public Color Color;
        public int Kind; // 0 원 1 조각 2 별 3 코인 4 먼지 5 링 6 십자반짝
    }

    class FloatText
    {
        public string Text;
        public double X, Y, VY, Life, MaxLife, Scale = 1;
        public Color Color;
        public Font Font;
    }

    class CoinFlight
    {
        public double X0, Y0, X1, Y1, T, Dur, Delay, Arc;
        public Color Color;
        public Action OnArrive;
        public bool Arrived;
    }

    /// <summary>파티클 / 플로팅 텍스트 / 코인 이동 / 화면 흔들림</summary>
    class Fx
    {
        public List<Particle> Parts = new List<Particle>();
        public List<FloatText> Texts = new List<FloatText>();
        public List<CoinFlight> Coins = new List<CoinFlight>();
        public double Shake;
        public double ShakeTime;

        public void Clear() { Parts.Clear(); Texts.Clear(); Coins.Clear(); Shake = 0; }

        public void Kick(double magnitude)
        {
            if (magnitude > Shake) Shake = magnitude;
        }

        public void Update(double dt)
        {
            ShakeTime += dt;
            Shake *= Math.Pow(0.0015, dt);
            if (Shake < 0.05) Shake = 0;

            for (int i = Parts.Count - 1; i >= 0; i--)
            {
                var p = Parts[i];
                p.Life -= dt;
                if (p.Life <= 0) { Parts.RemoveAt(i); continue; }
                p.VY += p.Grav * dt;
                double d = Math.Pow(p.Drag, dt * 60);
                p.VX *= d; p.VY *= d;
                p.X += p.VX * dt; p.Y += p.VY * dt;
                p.Rot += p.VRot * dt;
            }
            for (int i = Texts.Count - 1; i >= 0; i--)
            {
                var t = Texts[i];
                t.Life -= dt;
                if (t.Life <= 0) { Texts.RemoveAt(i); continue; }
                t.Y += t.VY * dt;
                t.VY *= Math.Pow(0.25, dt);
            }
            for (int i = Coins.Count - 1; i >= 0; i--)
            {
                var c = Coins[i];
                if (c.Delay > 0) { c.Delay -= dt; continue; }
                c.T += dt / c.Dur;
                if (c.T >= 1)
                {
                    if (!c.Arrived && c.OnArrive != null) c.OnArrive();
                    c.Arrived = true;
                    Coins.RemoveAt(i);
                }
            }
        }

        public PointF ShakeOffset()
        {
            if (Shake <= 0) return PointF.Empty;
            double a = ShakeTime * 47;
            return new PointF(
                (float)(Math.Sin(a) * Shake),
                (float)(Math.Cos(a * 1.37) * Shake * 0.7));
        }

        // ---------- 생성 헬퍼 ----------

        public void Burst(double x, double y, int n, Color c, double speed, double size, int kind)
        {
            for (int i = 0; i < n; i++)
            {
                double a = Rnd.Range(0, Math.PI * 2);
                double s = speed * Rnd.Range(0.35, 1.0);
                Parts.Add(new Particle
                {
                    X = x, Y = y,
                    VX = Math.Cos(a) * s, VY = Math.Sin(a) * s,
                    Life = Rnd.Range(0.35, 0.85), MaxLife = 0.85,
                    Size = size * Rnd.Range(0.6, 1.4),
                    Color = c, Kind = kind, Grav = 260, Drag = 0.93,
                    Rot = Rnd.Range(0, 6.28), VRot = Rnd.Signed(9)
                });
            }
        }

        public void Dust(double x, double y, Color c)
        {
            for (int i = 0; i < 9; i++)
            {
                double a = Rnd.Range(Math.PI * 0.15, Math.PI * 0.85);
                double s = Rnd.Range(40, 130);
                Parts.Add(new Particle
                {
                    X = x + Rnd.Signed(6), Y = y,
                    VX = Math.Cos(a) * -s * (Rnd.Chance(0.5) ? 1 : -1), VY = -Math.Abs(Math.Sin(a)) * s * 0.5,
                    Life = Rnd.Range(0.22, 0.42), MaxLife = 0.42,
                    Size = Rnd.Range(3, 7),
                    Color = c, Kind = 4, Grav = 120, Drag = 0.88
                });
            }
        }

        public void Ring(double x, double y, Color c, double size, double dur)
        {
            Parts.Add(new Particle
            {
                X = x, Y = y, Life = dur, MaxLife = dur,
                Size = size, Color = c, Kind = 5
            });
        }

        public void Sparkle(double x, double y, int n, Color c, double spread)
        {
            for (int i = 0; i < n; i++)
            {
                Parts.Add(new Particle
                {
                    X = x + Rnd.Signed(spread), Y = y + Rnd.Signed(spread),
                    VX = Rnd.Signed(30), VY = Rnd.Range(-70, -20),
                    Life = Rnd.Range(0.3, 0.7), MaxLife = 0.7,
                    Size = Rnd.Range(4, 9), Color = c, Kind = 6,
                    Grav = 40, Drag = 0.95, Rot = Rnd.Range(0, 3), VRot = Rnd.Signed(4)
                });
            }
        }

        public void CoinFountain(double x, double y, int n, Color c)
        {
            for (int i = 0; i < n; i++)
            {
                Parts.Add(new Particle
                {
                    X = x + Rnd.Signed(14), Y = y,
                    VX = Rnd.Signed(150), VY = Rnd.Range(-380, -180),
                    Life = Rnd.Range(0.7, 1.3), MaxLife = 1.3,
                    Size = Rnd.Range(7, 13), Color = c, Kind = 3,
                    Grav = 620, Drag = 0.995, Rot = Rnd.Range(0, 6), VRot = Rnd.Signed(12)
                });
            }
        }

        public void CoinRain(double w, double h, int n)
        {
            for (int i = 0; i < n; i++)
            {
                Parts.Add(new Particle
                {
                    X = Rnd.Range(0, w), Y = Rnd.Range(-h * 0.5, -10),
                    VX = Rnd.Signed(40), VY = Rnd.Range(150, 340),
                    Life = Rnd.Range(1.4, 2.4), MaxLife = 2.4,
                    Size = Rnd.Range(8, 15),
                    Color = Rnd.Chance(0.5) ? Pal.Gold : Pal.GoldDeep,
                    Kind = 3, Grav = 130, Drag = 1.0, VRot = Rnd.Signed(10)
                });
            }
        }

        public void Confetti(double w, double h, int n)
        {
            var cols = new[]
            {
                Color.FromArgb(255,99,132), Color.FromArgb(255,205,86), Color.FromArgb(75,192,192),
                Color.FromArgb(153,102,255), Color.FromArgb(96,165,250), Color.FromArgb(74,222,128)
            };
            for (int i = 0; i < n; i++)
            {
                Parts.Add(new Particle
                {
                    X = Rnd.Range(0, w), Y = Rnd.Range(-h * 0.4, 0),
                    VX = Rnd.Signed(90), VY = Rnd.Range(90, 260),
                    Life = Rnd.Range(2.0, 3.6), MaxLife = 3.6,
                    Size = Rnd.Range(6, 13), Color = cols[Rnd.Int(cols.Length)],
                    Kind = 1, Grav = 60, Drag = 0.999, Rot = Rnd.Range(0, 6), VRot = Rnd.Signed(11)
                });
            }
        }

        public void Rocket(double x, double y, Color c)
        {
            for (int i = 0; i < 26; i++)
            {
                Parts.Add(new Particle
                {
                    X = x + Rnd.Signed(10), Y = y + Rnd.Range(0, 14),
                    VX = Rnd.Signed(70), VY = Rnd.Range(60, 220),
                    Life = Rnd.Range(0.3, 0.8), MaxLife = 0.8,
                    Size = Rnd.Range(6, 16),
                    Color = Rnd.Chance(0.5) ? Color.FromArgb(255, 190, 80) : Color.FromArgb(255, 120, 60),
                    Kind = 0, Grav = -60, Drag = 0.9
                });
            }
        }

        public void Float(string text, double x, double y, Color c, Font f, double rise, double life)
        {
            Texts.Add(new FloatText
            {
                Text = text, X = x, Y = y, VY = -rise, Life = life, MaxLife = life,
                Color = c, Font = f
            });
        }

        public void FlyCoin(double x0, double y0, double x1, double y1, Color c, double dur, double delay, Action onArrive)
        {
            Coins.Add(new CoinFlight
            {
                X0 = x0, Y0 = y0, X1 = x1, Y1 = y1, Dur = dur, Delay = delay,
                Color = c, OnArrive = onArrive, Arc = Rnd.Range(50, 120)
            });
        }

        // ---------- 렌더 ----------

        public void Render(Graphics g)
        {
            foreach (var p in Parts)
            {
                double lf = p.Life / p.MaxLife;
                if (lf > 1) lf = 1;
                int a = (int)(255 * Math.Min(1, lf * 1.6));
                switch (p.Kind)
                {
                    case 5: // 확장 링
                        {
                            double t = 1 - lf;
                            float r = (float)(p.Size * (0.2 + t * 1.4));
                            using (var pen = new Pen(Draw.A(p.Color, (int)(200 * lf)), (float)(3.5 * lf + 0.5f)))
                                g.DrawEllipse(pen, (float)(p.X - r), (float)(p.Y - r), r * 2, r * 2);
                            break;
                        }
                    case 1: // 색종이 조각
                        {
                            var st = g.Save();
                            g.TranslateTransform((float)p.X, (float)p.Y);
                            g.RotateTransform((float)(p.Rot * 57.3));
                            float w = (float)p.Size, h = (float)(p.Size * (0.4 + 0.6 * Math.Abs(Math.Sin(p.Rot * 1.7))));
                            using (var b = new SolidBrush(Draw.A(p.Color, a)))
                                g.FillRectangle(b, -w / 2, -h / 2, w, h);
                            g.Restore(st);
                            break;
                        }
                    case 2: // 별
                        Draw.Star(g, Draw.A(p.Color, a), (float)p.X, (float)p.Y, (float)p.Size, 5, p.Rot);
                        break;
                    case 3: // 코인
                        DrawCoin(g, (float)p.X, (float)p.Y, (float)p.Size, a, p.Rot);
                        break;
                    case 4: // 먼지
                        using (var b = new SolidBrush(Draw.A(p.Color, (int)(a * 0.5))))
                            g.FillEllipse(b, (float)(p.X - p.Size), (float)(p.Y - p.Size * 0.6),
                                (float)(p.Size * 2), (float)(p.Size * 1.2));
                        break;
                    case 6: // 십자 반짝
                        {
                            float s = (float)(p.Size * (0.4 + 0.6 * Math.Sin(lf * Math.PI)));
                            using (var b = new SolidBrush(Draw.A(p.Color, a)))
                            {
                                g.FillEllipse(b, (float)p.X - s * 0.22f, (float)p.Y - s, s * 0.44f, s * 2);
                                g.FillEllipse(b, (float)p.X - s, (float)p.Y - s * 0.22f, s * 2, s * 0.44f);
                            }
                            break;
                        }
                    default: // 원
                        using (var b = new SolidBrush(Draw.A(p.Color, a)))
                            g.FillEllipse(b, (float)(p.X - p.Size), (float)(p.Y - p.Size),
                                (float)(p.Size * 2), (float)(p.Size * 2));
                        break;
                }
            }

            foreach (var c in Coins)
            {
                if (c.Delay > 0) continue;
                double t = Math.Min(1, c.T);
                double x = c.X0 + (c.X1 - c.X0) * t;
                double y = c.Y0 + (c.Y1 - c.Y0) * t - Math.Sin(t * Math.PI) * c.Arc;
                DrawCoin(g, (float)x, (float)y, 11f, 255, t * 12);
            }

            foreach (var t in Texts)
            {
                double lf = t.Life / t.MaxLife;
                int a = (int)(255 * Math.Min(1, lf * 2.2));
                double pop = 1 + 0.35 * Math.Max(0, 1 - (1 - lf) * 6);
                var st = g.Save();
                g.TranslateTransform((float)t.X, (float)t.Y);
                g.ScaleTransform((float)pop, (float)pop);
                Draw.Text(g, t.Text, t.Font, Draw.A(Color.Black, (int)(a * 0.45)), 1.5f, 1.5f);
                Draw.Text(g, t.Text, t.Font, Draw.A(t.Color, a), 0, 0);
                g.Restore(st);
            }
        }

        public static void DrawCoin(Graphics g, float x, float y, float size, int alpha, double rot)
        {
            float w = size * (float)Math.Abs(Math.Cos(rot));
            if (w < size * 0.18f) w = size * 0.18f;
            var r = new RectangleF(x - w, y - size, w * 2, size * 2);
            using (var b = new LinearGradientBrush(
                new RectangleF(r.X, r.Y - 1, Math.Max(1, r.Width), r.Height + 2),
                Draw.A(Color.FromArgb(255, 226, 138), alpha),
                Draw.A(Color.FromArgb(214, 152, 20), alpha), 90f))
                g.FillEllipse(b, r);
            using (var pen = new Pen(Draw.A(Color.FromArgb(160, 108, 10), alpha), 1.2f))
                g.DrawEllipse(pen, r);
            if (w > size * 0.5f)
                Draw.TextIn(g, "₩", F.Tiny, Draw.A(Color.FromArgb(140, 96, 8), alpha), r, Draw.Center);
        }
    }
}
