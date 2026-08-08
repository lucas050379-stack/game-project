using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace Segyemabyul
{
    class Lay
    {
        public int W, H;
        public float BoardX, BoardY, BoardSize, CellSize;
        public RectangleF Side, Center, LogoRect, FundRect, TurnRect, DiceRect, ActionRect, LogRect;
        public int PlayerCount = 4;

        public void Compute(int w, int h, int playerCount)
        {
            W = w; H = h; PlayerCount = Math.Max(2, playerCount);
            const float pad = 14f;
            float sideW = Math.Max(268f, Math.Min(330f, w * 0.245f));
            float availW = w - sideW - pad * 3;
            float availH = h - pad * 2;
            BoardSize = Math.Max(360f, Math.Min(availW, availH));
            BoardX = pad + (availW - BoardSize) / 2f;
            BoardY = pad + (availH - BoardSize) / 2f;
            CellSize = BoardSize / Rules.Grid;
            Side = new RectangleF(w - pad - sideW, pad, sideW, h - pad * 2);

            float g2 = CellSize * 0.16f;
            Center = new RectangleF(BoardX + CellSize + g2, BoardY + CellSize + g2,
                BoardSize - CellSize * 2 - g2 * 2, BoardSize - CellSize * 2 - g2 * 2);

            float y = Center.Y + Center.Height * 0.02f;
            LogoRect = new RectangleF(Center.X, y, Center.Width, Center.Height * 0.13f);
            y += LogoRect.Height;
            FundRect = new RectangleF(Center.X + Center.Width * 0.18f, y + 2, Center.Width * 0.64f, Center.Height * 0.085f);
            y += FundRect.Height + 8;
            DiceRect = new RectangleF(Center.X, y, Center.Width, Center.Height * 0.235f);
            y += DiceRect.Height;
            TurnRect = new RectangleF(Center.X, y, Center.Width, Center.Height * 0.075f);
            y += TurnRect.Height;
            ActionRect = new RectangleF(Center.X + Center.Width * 0.06f, y, Center.Width * 0.88f, Center.Height * 0.135f);
            y += ActionRect.Height + 6;
            LogRect = new RectangleF(Center.X + Center.Width * 0.03f, y, Center.Width * 0.94f,
                Math.Max(40f, Center.Bottom - y - Center.Height * 0.02f));
        }

        public RectangleF CellRect(int i)
        {
            int row, col;
            Board.GridPos(i, out row, out col);
            return new RectangleF(BoardX + col * CellSize + 1f, BoardY + row * CellSize + 1f,
                CellSize - 2f, CellSize - 2f);
        }

        public PointF CellCenter(int i)
        {
            var r = CellRect(i);
            return new PointF(r.X + r.Width / 2, r.Y + r.Height / 2);
        }

        public RectangleF PlayerCardRect(int i, int count)
        {
            float top = Side.Y + 46f;
            float bottom = Side.Bottom - 58f;
            float gap = 8f;
            float hh = (bottom - top - gap * (count - 1)) / count;
            hh = Math.Min(hh, 132f);
            return new RectangleF(Side.X, top + i * (hh + gap), Side.Width, hh);
        }

        /// <summary>말이 그려질 위치(점프 애니메이션 포함)</summary>
        public PointF TokenPoint(Game g, Player p)
        {
            int slot = p.Id;
            float off = CellSize * 0.16f;
            // 내 말이 크므로 조금 더 벌려 다른 말과 겹치는 면적을 줄인다
            float spread = p.IsAI ? 1.02f : 1.24f;
            float dx = (slot % 2 == 0 ? -off : off) * 0.92f * spread;
            float dy = (slot < 2 ? -off * 0.5f : off * 0.5f) * spread;

            PointF baseP;
            if (p.HopT >= 0)
            {
                var a = CellCenter(p.HopFrom);
                var b = CellCenter(p.HopTo);
                double t = p.HopT;
                float x = (float)(a.X + (b.X - a.X) * t);
                float y = (float)(a.Y + (b.Y - a.Y) * t - Math.Sin(t * Math.PI) * CellSize * 0.62);
                baseP = new PointF(x, y);
            }
            else
            {
                baseP = CellCenter(p.Pos);
            }
            float bob = (float)(Math.Sin(p.Bob) * CellSize * 0.02);
            return new PointF(baseP.X + dx, baseP.Y + dy + CellSize * 0.17f + bob);
        }
    }

    partial class GameForm
    {
        // ---- 칸 크기에 맞춰 만들어지는 폰트 (창 크기 변경 시에만 재생성) ----
        float cellFontFor = -1;
        Font fCellSub, fCellPrice, fCornerSub, fCellChip;
        Font[] fCellName = new Font[Rules.BoardSize];
        readonly List<Font> ownedFonts = new List<Font>();

        void EnsureCellFonts()
        {
            if (Math.Abs(L.CellSize - cellFontFor) < 0.4f) return;
            cellFontFor = L.CellSize;

            foreach (var f in ownedFonts) f.Dispose();
            ownedFonts.Clear();

            float s = L.CellSize;
            fCellSub = F.At(Math.Max(5.2f, s * 0.098f), FontStyle.Regular);
            fCellPrice = F.At(Math.Max(6.0f, s * 0.122f), FontStyle.Bold);
            fCornerSub = F.At(Math.Max(5.2f, s * 0.100f), FontStyle.Regular);
            fCellChip = F.At(Math.Max(4.8f, s * 0.082f), FontStyle.Bold);
            ownedFonts.Add(fCellSub); ownedFonts.Add(fCellPrice);
            ownedFonts.Add(fCornerSub); ownedFonts.Add(fCellChip);

            // 이름 길이에 따라 자동으로 작아지는 폰트 사다리
            var ladder = new List<Font>();
            float[] mul = { 0.150f, 0.134f, 0.120f, 0.108f, 0.097f };
            for (int i = 0; i < mul.Length; i++)
            {
                var f = F.At(Math.Max(5.4f, s * mul[i]), FontStyle.Bold);
                ladder.Add(f); ownedFonts.Add(f);
            }

            float innerW = L.CellSize - 7f;
            using (var g = CreateGraphics())
            {
                var cells = Board.Create();
                for (int i = 0; i < cells.Length && i < fCellName.Length; i++)
                {
                    float w = cells[i].IsCorner ? innerW + 4f : innerW;
                    fCellName[i] = ladder[ladder.Count - 1];
                    for (int k = 0; k < ladder.Count; k++)
                    {
                        if (g.MeasureString(cells[i].Name, ladder[k], 3000, Draw.Center).Width <= w)
                        { fCellName[i] = ladder[k]; break; }
                    }
                }
            }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;
            Draw.SetQuality(g);
            L.Compute(ClientSize.Width, ClientSize.Height, G != null ? G.Players.Count : 4);
            EnsureCellFonts();
            LayoutButtons();

            DrawBackground(g);

            if (screen == Screen.Setup)
            {
                DrawSetup(g);
                fx.Render(g);
                return;
            }

            var shake = fx.ShakeOffset();
            var st = g.Save();
            g.TranslateTransform(shake.X, shake.Y);

            DrawBoard(g);
            DrawSidebar(g);
            DrawCenter(g);
            fx.Render(g);
            g.Restore(st);

            DrawHoverInfo(g);
            DrawBannerLayer(g);
            if (modal != null) DrawModal(g, modal);
            if (screen == Screen.Over) DrawGameOver(g);
        }

        // ==================== 배경 ====================
        void DrawBackground(Graphics g)
        {
            var r = new Rectangle(0, 0, ClientSize.Width, ClientSize.Height);
            using (var b = new LinearGradientBrush(r, Pal.Bg1, Pal.Bg0, 60f))
                g.FillRectangle(b, r);

            // 은은하게 움직이는 광원
            for (int i = 0; i < 2; i++)
            {
                double ph = Time * (0.11 + i * 0.07) + i * 2.1;
                float cx = (float)(ClientSize.Width * (0.3 + 0.4 * Math.Sin(ph)));
                float cy = (float)(ClientSize.Height * (0.3 + 0.4 * Math.Cos(ph * 0.8)));
                float rad = ClientSize.Height * 0.55f;
                using (var path = new GraphicsPath())
                {
                    path.AddEllipse(cx - rad, cy - rad, rad * 2, rad * 2);
                    using (var pb = new PathGradientBrush(path))
                    {
                        pb.CenterColor = Color.FromArgb(26, i == 0 ? Pal.Accent : Color.FromArgb(168, 85, 247));
                        pb.SurroundColors = new[] { Color.FromArgb(0, 0, 0, 0) };
                        g.FillPath(pb, path);
                    }
                }
            }
        }

        // ==================== 보드 ====================
        void DrawBoard(Graphics g)
        {
            var br = new RectangleF(L.BoardX - 8, L.BoardY - 8, L.BoardSize + 16, L.BoardSize + 16);
            Draw.Shadow(g, br, 18, 8, 1.0);
            Draw.FillRoundGrad(g, Color.FromArgb(38, 46, 82), Color.FromArgb(24, 30, 56), br, 18);
            Draw.StrokeRound(g, Color.FromArgb(70, 255, 255, 255), 1.2f, br, 18);

            var inner = new RectangleF(L.BoardX + L.CellSize - 4, L.BoardY + L.CellSize - 4,
                L.BoardSize - L.CellSize * 2 + 8, L.BoardSize - L.CellSize * 2 + 8);
            Draw.FillRoundGrad(g, Color.FromArgb(30, 38, 68), Color.FromArgb(20, 26, 48), inner, 12);

            for (int i = 0; i < Rules.BoardSize; i++) DrawCell(g, G.Cells[i]);
            for (int i = 0; i < G.Players.Count; i++)
            {
                var p = G.Players[i];
                if (p.Alpha <= 0.01) continue;
                var pt = L.TokenPoint(G, p);
                bool active = screen == Screen.Play && G.Current == p && !G.Over;
                bool mine = !p.IsAI;
                Icons.DrawToken(g, pt.X, pt.Y, L.CellSize * (mine ? 0.215f : 0.186f), p.Color, p.Squash,
                    active, p.EmoteKind, Time + i, p.Alpha, p.Face);
            }
        }

        void DrawCell(Graphics g, Cell c)
        {
            var r = L.CellRect(c.Index);
            if (c.Shake > 0)
            {
                float m = (float)(c.Shake * 3.4);
                r.Offset((float)(Math.Sin(Time * 60) * m), (float)(Math.Cos(Time * 71) * m));
            }
            float rad = L.CellSize * 0.11f;
            bool owned = c.Owner >= 0;
            Color oc = owned ? G.Players[c.Owner].Color : Color.Empty;
            // 내 땅은 AI 땅보다 한 단계 더 세게 — 한눈에 내 판이 어디까지 왔는지 보이게
            bool mine = owned && !G.Players[c.Owner].IsAI;

            // 선택 모드 하이라이트
            bool selectable = picking && (pickFilter == null || pickFilter(c));
            bool hovered = hoverCell == c.Index;

            if (owned)
            {
                double w = c.OwnWave;
                bool gold = c.HasLandmark || G.IsMonopolyBoosted(c);
                if (w > 0)
                    Draw.GlowRound(g, gold ? Pal.Gold : oc, r, rad, (float)(6 + w * 18), 1.3 * w + 0.4);
                else if (gold)
                    Draw.GlowRound(g, Pal.Gold, r, rad, c.HasLandmark ? 8f : 6f,
                        (c.HasLandmark ? 0.8 : 0.55) + 0.25 * Math.Sin(Time * 2.5 + c.Index));
                else if (mine)
                    Draw.GlowRound(g, oc, r, rad, 9f, 0.72 + 0.22 * Math.Sin(Time * 2.2 + c.Index));
                else
                    Draw.GlowRound(g, oc, r, rad, 5.5f, 0.62);
            }
            if (c.DoubleToll)
                Draw.GlowRound(g, Color.FromArgb(239, 68, 68), r, rad, 6f,
                    0.7 + 0.35 * Math.Sin(Time * 3.4 + c.Index));
            if (c.Pulse > 0) Draw.GlowRound(g, Pal.White, r, rad, (float)(10 * c.Pulse + 3), c.Pulse);
            if (selectable)
            {
                double pl = 0.5 + 0.5 * Math.Sin(Time * 5 + c.Index * 0.4);
                Draw.GlowRound(g, Pal.Gold, r, rad, (float)(6 + pl * 8), 0.8);
            }

            Color top = Pal.CellBg, bot = Pal.CellBg2;
            if (owned)
            {
                double tint = mine ? 0.34 : 0.24;
                top = Draw.Mix(Pal.CellBg, oc, tint * 0.75);
                bot = Draw.Mix(Pal.CellBg2, oc, tint * 1.6);
            }
            if (hovered) { top = Draw.Lighten(top, 0.25); bot = Draw.Lighten(bot, 0.2); }
            Draw.FillRoundGrad(g, top, bot, r, rad);

            if (c.IsCorner)
            {
                DrawCornerCell(g, c, r, rad);
            }
            else if (c.IsProperty)
            {
                DrawPropertyCell(g, c, r, rad);
            }
            else
            {
                Icons.DrawSpecial(g, c.Type, new RectangleF(r.X, r.Y + r.Height * 0.06f, r.Width, r.Height * 0.58f), Time);
                Draw.TextIn(g, c.Name, fCellName[c.Index], Pal.Ink,
                    new RectangleF(r.X, r.Bottom - r.Height * 0.33f, r.Width, r.Height * 0.17f), Draw.Center);
                string ssub = null;
                if (c.Type == CellType.FundPay) ssub = Fmt.M(Rules.FundPay);
                else if (c.Type == CellType.Tax) ssub = "현금 10%";
                if (ssub != null)
                    Draw.TextIn(g, ssub, fCellSub, Pal.InkSoft,
                        new RectangleF(r.X, r.Bottom - r.Height * 0.16f, r.Width, r.Height * 0.13f), Draw.Center);
            }

            Draw.StrokeRound(g, owned ? Draw.A(oc, 245) : Color.FromArgb(120, 60, 70, 100),
                owned ? (mine ? 4.0f : 3.0f) : 1.1f, r, rad);
            if (owned) DrawClaimBar(g, c, r, oc, mine);
        }

        /// <summary>
        /// 칸 바로 안쪽(판 여백)에 소유자 색 띠를 깐다.
        ///
        /// 색만 옅게 입히면 칸이 많아질수록 묻힌다. 띠는 옆 칸과 이어져 보여서
        /// 누가 어디를 얼마나 먹었는지 한눈에 들어온다.
        /// 칸 안이 아니라 <b>바깥</b>에 그리는 이유는 국기·이름·통행료를 가리지 않기 위해서다.
        /// </summary>
        void DrawClaimBar(Graphics g, Cell c, RectangleF r, Color oc, bool mine)
        {
            int row, col;
            Board.GridPos(c.Index, out row, out col);
            const int N = Rules.Grid - 1;

            float t = r.Width * (mine ? 0.085f : 0.065f);   // 띠 두께
            float gap = r.Width * 0.018f;                    // 칸과의 간격
            float m = r.Width * 0.06f;                       // 양끝 여백
            RectangleF bar;
            if (row == N) bar = new RectangleF(r.X + m, r.Y - gap - t, r.Width - m * 2, t);
            else if (row == 0) bar = new RectangleF(r.X + m, r.Bottom + gap, r.Width - m * 2, t);
            else if (col == 0) bar = new RectangleF(r.Right + gap, r.Y + m, t, r.Height - m * 2);
            else bar = new RectangleF(r.X - gap - t, r.Y + m, t, r.Height - m * 2);

            float br = Math.Min(bar.Width, bar.Height) * 0.5f;
            Draw.GlowRound(g, oc, bar, br, mine ? 7f : 4f, mine ? 0.95 : 0.6);
            Draw.FillRound(g, Draw.Lighten(oc, mine ? 0.28 : 0.06), bar, br);
        }

        void DrawPropertyCell(Graphics g, Cell c, RectangleF r, float rad)
        {
            float bandH = r.Height * 0.34f;
            var band = new RectangleF(r.X, r.Y, r.Width, bandH);
            var st = g.Save();
            using (var clip = Draw.RoundRect(r, rad))
            {
                g.SetClip(clip);
                using (var b = new LinearGradientBrush(
                    new RectangleF(band.X, band.Y - 1, band.Width, band.Height + 2),
                    Draw.Lighten(c.GroupColor, 0.22), c.GroupColor, 90f))
                    g.FillRectangle(b, band);
            }
            g.Restore(st);

            // 국기
            float fw = r.Width * 0.32f, fh = fw * 0.66f;
            var fr = new RectangleF(r.X + r.Width * 0.07f, band.Y + (bandH - fh) / 2, fw, fh);
            Icons.DrawFlag(g, c.Flag, fr);

            // 건물
            if (c.Level > 0)
            {
                Color oc = c.Owner >= 0 ? G.Players[c.Owner].Color : Pal.Dim;
                Icons.DrawBuilding(g, c.Level, r.X + r.Width * 0.68f, band.Bottom - 1.5f,
                    r.Width * 0.30f, bandH * 0.60f, oc, c.BuildPop, c.Landmark);
            }
            else if (c.Owner >= 0)
            {
                var oc = G.Players[c.Owner].Color;
                using (var b = new SolidBrush(oc))
                    g.FillEllipse(b, r.X + r.Width * 0.72f, band.Y + bandH * 0.3f, bandH * 0.34f, bandH * 0.34f);
                using (var pen = new Pen(Color.FromArgb(200, 255, 255, 255), 1.2f))
                    g.DrawEllipse(pen, r.X + r.Width * 0.72f, band.Y + bandH * 0.3f, bandH * 0.34f, bandH * 0.34f);
            }

            // 이름 / 국가
            var nameR = new RectangleF(r.X + 2, band.Bottom + r.Height * 0.02f, r.Width - 4, r.Height * 0.26f);
            Draw.TextIn(g, c.Name, fCellName[c.Index], Pal.Ink, nameR, Draw.Center);
            var subR = new RectangleF(r.X + 2, nameR.Bottom - r.Height * 0.03f, r.Width - 4, r.Height * 0.16f);
            if (c.DoubleToll)
            {
                var chip = new RectangleF(r.X + r.Width * 0.06f, subR.Y + subR.Height * 0.06f,
                    r.Width * 0.88f, subR.Height * 0.92f);
                Draw.FillRound(g, Color.FromArgb(238, 68, 68), chip, chip.Height / 2);
                Draw.TextIn(g, "통행료 2배", fCellChip, Color.White, chip, Draw.Center);
            }
            else
            {
                Draw.TextIn(g, c.Country, fCellSub, Pal.InkSoft, subR, Draw.Center);
            }

            // 가격 / 통행료
            var priceR = new RectangleF(r.X + 2, r.Bottom - r.Height * 0.24f, r.Width - 4, r.Height * 0.2f);
            if (c.Owner >= 0)
            {
                int toll = G.Toll(c);
                bool hot = G.IsMonopolyBoosted(c) || c.HasLandmark;
                Draw.FillRound(g, Draw.A(hot ? Pal.GoldDeep : Color.FromArgb(60, 66, 88), 235),
                    new RectangleF(priceR.X + priceR.Width * 0.10f, priceR.Y, priceR.Width * 0.80f, priceR.Height), 4f);
                Draw.TextIn(g, Fmt.M(toll), fCellPrice, hot ? Color.White : Pal.White, priceR, Draw.Center);
            }
            else
            {
                Draw.TextIn(g, Fmt.M(c.Price), fCellPrice, Pal.InkSoft, priceR, Draw.Center);
            }
        }

        void DrawCornerCell(Graphics g, Cell c, RectangleF r, float rad)
        {
            var iconR = new RectangleF(r.X, r.Y + r.Height * 0.04f, r.Width, r.Height * 0.62f);
            Icons.DrawSpecial(g, c.Type, iconR, Time);
            Draw.FillRound(g, Draw.A(Pal.Ink, 30),
                new RectangleF(r.X + r.Width * 0.06f, r.Bottom - r.Height * 0.325f, r.Width * 0.88f, r.Height * 0.18f), 5f);
            Draw.TextIn(g, c.Name, fCellName[c.Index], Pal.Ink,
                new RectangleF(r.X, r.Bottom - r.Height * 0.325f, r.Width, r.Height * 0.18f), Draw.Center);
            string sub = null;
            if (c.Type == CellType.Start) sub = "+" + Fmt.M(Rules.Salary);
            else if (c.Type == CellType.Jail) sub = Rules.JailTurns + "턴 정지";
            else if (c.Type == CellType.Space) sub = "원하는 칸";
            else if (c.Type == CellType.FundGet) sub = "기금 전액";
            if (sub != null)
                Draw.TextIn(g, sub, fCornerSub, Pal.InkSoft,
                    new RectangleF(r.X, r.Bottom - r.Height * 0.145f, r.Width, r.Height * 0.125f), Draw.Center);
        }

        // ==================== 중앙 패널 ====================
        void DrawCenter(Graphics g)
        {
            // 로고
            var lr = L.LogoRect;
            string logo = "세계마뷸";
            float cx = lr.X + lr.Width / 2;
            float baseY = lr.Y + lr.Height * 0.5f;
            using (var f = new Font(F.Huge.FontFamily, Math.Max(16f, L.CellSize * 0.34f), FontStyle.Bold))
            {
                float total = 0;
                var widths = new float[logo.Length];
                for (int i = 0; i < logo.Length; i++)
                {
                    widths[i] = g.MeasureString(logo[i].ToString(), f, 200, Draw.Center).Width * 0.78f;
                    total += widths[i];
                }
                float x = cx - total / 2;
                for (int i = 0; i < logo.Length; i++)
                {
                    float bob = (float)(Math.Sin(Time * 2.2 + i * 0.6) * lr.Height * 0.08);
                    var col = Draw.Mix(Pal.Gold, Color.FromArgb(255, 240, 200), 0.5 + 0.5 * Math.Sin(Time * 2 + i));
                    Draw.Text(g, logo[i].ToString(), f, Draw.A(Color.Black, 90), x + widths[i] / 2 + 2, baseY + bob + 3);
                    Draw.Text(g, logo[i].ToString(), f, col, x + widths[i] / 2, baseY + bob);
                    x += widths[i];
                }
            }
            Draw.TextIn(g, "BLUE  MARBLE", F.Tiny, Draw.A(Pal.Dim, 200),
                new RectangleF(lr.X, lr.Bottom - lr.Height * 0.16f, lr.Width, lr.Height * 0.2f), Draw.Center);

            // 사회복지기금
            var fr = L.FundRect;
            double fp = 0.5 + 0.5 * Math.Sin(Time * 2.4);
            Draw.FillRoundGrad(g, Color.FromArgb(56, 48, 24), Color.FromArgb(38, 32, 16), fr, fr.Height / 2);
            Draw.StrokeRound(g, Draw.A(Pal.Gold, (int)(110 + fp * 90)), 1.4f, fr, fr.Height / 2);
            Fx.DrawCoin(g, fr.X + fr.Height * 0.62f, fr.Y + fr.Height / 2, fr.Height * 0.3f, 255, 0);
            Draw.TextIn(g, "사회복지기금", F.Small, Draw.A(Pal.Gold, 210),
                new RectangleF(fr.X + fr.Height * 1.05f, fr.Y, fr.Width * 0.5f, fr.Height), Draw.Left);
            Draw.TextIn(g, Fmt.Won((int)Math.Round(G.FundDisplay)), F.SubB, Pal.Gold,
                new RectangleF(fr.X, fr.Y, fr.Width - fr.Height * 0.6f, fr.Height), Draw.Right);

            // 주사위
            var dr = L.DiceRect;
            if (diceVisible)
            {
                float ds = Math.Min(dr.Height * 0.62f, L.CellSize * 1.25f);
                float gap = ds * 0.34f;
                float dcx = dr.X + dr.Width / 2;
                float dcy = dr.Y + dr.Height * 0.46f;
                if (diceGlow > 0)
                {
                    var gr = new RectangleF(dcx - ds - gap, dcy - ds * 0.8f, (ds + gap) * 2, ds * 1.6f);
                    Draw.GlowRound(g, Pal.Gold, gr, 20, 22f, diceGlow * 1.6);
                }
                Icons.DrawDie(g, dcx - ds / 2 - gap / 2, dcy, ds, die1, dieRot1, dieScale, 255);
                Icons.DrawDie(g, dcx + ds / 2 + gap / 2, dcy, ds, die2, dieRot2, dieScale, 255);
                if (!diceRolling && diceRolled)
                {
                    string tot = "합계  " + (die1 + die2) + (die1 == die2 ? "   더블!" : "");
                    Draw.TextIn(g, tot, F.SubB, die1 == die2 ? Pal.Gold : Pal.Dim,
                        new RectangleF(dr.X, dr.Bottom - dr.Height * 0.2f, dr.Width, dr.Height * 0.2f), Draw.Center);
                }
            }

            // 턴 안내
            var tr = L.TurnRect;
            var cur = G.Current;
            if (screen == Screen.Play && cur != null)
            {
                string txt = prompt.Length > 0 ? prompt : cur.Name + " 진행 중";
                Draw.TextIn(g, txt, F.Body, Draw.A(Pal.White, 225), tr, Draw.Center);
            }

            // 액션 버튼
            DrawButtons(g, buttons);

            // 로그
            DrawLog(g, L.LogRect);
        }

        void DrawLog(Graphics g, RectangleF r)
        {
            Draw.FillRound(g, Color.FromArgb(120, 12, 16, 32), r, 10f);
            Draw.StrokeRound(g, Color.FromArgb(40, 255, 255, 255), 1f, r, 10f);
            float lineH = 17f;
            int max = (int)((r.Height - 12) / lineH);
            if (max < 1) return;
            int start = Math.Max(0, G.Log.Count - max);
            float y = r.Y + 6;
            for (int i = start; i < G.Log.Count; i++)
            {
                var ln = G.Log[i];
                int age = G.Log.Count - i;
                int alpha = Math.Max(70, 255 - (age - 1) * 22);
                Draw.TextIn(g, ln.Text, F.Body, Draw.A(ln.Color, alpha),
                    new RectangleF(r.X + 10, y, r.Width - 20, lineH), Draw.Left);
                y += lineH;
            }
        }

        // ==================== 사이드바 ====================
        void DrawSidebar(Graphics g)
        {
            var s = L.Side;
            var hdr = new RectangleF(s.X, s.Y, s.Width, 36);
            Draw.TextIn(g, "라운드 " + G.Round, F.SubB, Pal.White,
                new RectangleF(hdr.X + 4, hdr.Y, hdr.Width * 0.5f, hdr.Height), Draw.Left);
            var spBtn = new RectangleF(s.Right - 92, hdr.Y + 4, 92, 28);
            bool spHot = spBtn.Contains(mouse);
            Draw.FillRound(g, spHot ? Pal.PanelHi : Pal.Panel, spBtn, 8f);
            Draw.StrokeRound(g, Draw.A(Pal.Accent, spHot ? 220 : 120), 1.2f, spBtn, 8f);
            Draw.TextIn(g, "속도 x" + (Speed < 1.5 ? "1" : Speed < 3 ? "2" : "4"), F.Small, Pal.White, spBtn, Draw.Center);
            speedBtnRect = spBtn;

            for (int i = 0; i < G.Players.Count; i++)
                DrawPlayerCard(g, G.Players[i], L.PlayerCardRect(i, G.Players.Count));

            var hint = new RectangleF(s.X, s.Bottom - 52, s.Width, 52);
            Draw.TextIn(g, "Space 확인/굴리기   1~4 선택   Tab 속도   Esc 처음으로",
                F.Tiny, Draw.A(Pal.Dim, 190), hint, Draw.CenterWrap);
        }

        RectangleF speedBtnRect;

        void DrawPlayerCard(Graphics g, Player p, RectangleF r)
        {
            bool active = G.Current == p && !G.Over && screen == Screen.Play;
            double al = p.Alive ? 1 : 0.42;

            if (active)
            {
                double pl = 0.5 + 0.5 * Math.Sin(Time * 3);
                Draw.GlowRound(g, p.Color, r, 12f, (float)(8 + pl * 8), 1.1);
            }
            Draw.FillRoundGrad(g, Draw.A(Draw.Mix(Pal.Panel, p.Color, active ? 0.22 : 0.08), (int)(240 * al)),
                Draw.A(Draw.Mix(Color.FromArgb(24, 30, 56), p.Color, 0.05), (int)(240 * al)), r, 12f);
            Draw.StrokeRound(g, Draw.A(p.Color, (int)((active ? 235 : 120) * al)), active ? 2.2f : 1.2f, r, 12f);

            float pad = 10f;
            float tokR = Math.Min(20f, r.Height * 0.19f);
            Icons.DrawToken(g, r.X + pad + tokR, r.Y + pad + tokR, tokR, p.Color, 0, false,
                p.EmoteKind, Time + p.Id, al, p.Face);

            var nameR = new RectangleF(r.X + pad + tokR * 2 + 8, r.Y + pad - 2, r.Width - pad * 2 - tokR * 2 - 8, 20);
            Draw.TextIn(g, p.Name, F.SubB, Draw.A(Pal.White, (int)(255 * al)), nameR, Draw.Left);

            if (!p.Alive)
                Draw.TextIn(g, "파산", F.Small, Draw.A(Pal.Bad, 220), nameR, Draw.Right);
            else if (p.JailTurns > 0)
                Draw.TextIn(g, "무인도 " + p.JailTurns, F.Small, Draw.A(Color.FromArgb(56, 189, 248), 230), nameR, Draw.Right);
            else if (p.PendingSpace)
                Draw.TextIn(g, "우주여행", F.Small, Draw.A(Pal.Accent, 230), nameR, Draw.Right);
            else if (p.EscapeCards > 0)
                Draw.TextIn(g, "탈출권 " + p.EscapeCards, F.Small, Draw.A(Pal.Gold, 230), nameR, Draw.Right);

            // 현금
            var cashR = new RectangleF(r.X + pad + tokR * 2 + 8, r.Y + pad + 16, r.Width - pad * 2 - tokR * 2 - 8, 26);
            Draw.TextIn(g, Fmt.Won((int)Math.Round(p.DisplayCash)), F.Title,
                Draw.A(p.Cash <= 20 ? Pal.Bad : Pal.White, (int)(255 * al)), cashR, Draw.Left);

            // 자산 요약
            var owned = G.Owned(p.Id);
            int bld = G.CountBuildings(p.Id);
            var sumR = new RectangleF(r.X + pad, r.Y + r.Height - 42, r.Width - pad * 2, 18);
            Draw.TextIn(g, "도시 " + owned.Count + "   건물 " + bld + "   총자산 " + Fmt.M(G.NetWorth(p)),
                F.Small, Draw.A(Pal.Dim, (int)(230 * al)), sumR, Draw.Left);

            // 소유 도시 색 점
            float dx = r.X + pad, dy = r.Y + r.Height - 18;
            float dotW = Math.Min(13f, (r.Width - pad * 2) / Math.Max(1, owned.Count));
            foreach (var c in owned)
            {
                Draw.FillRound(g, Draw.A(c.GroupColor, (int)(235 * al)),
                    new RectangleF(dx, dy, dotW - 2.5f, 10), 2.5f);
                if (c.Level > 0)
                    Draw.TextIn(g, c.Level.ToString(), F.Tiny, Color.FromArgb(20, 20, 30),
                        new RectangleF(dx, dy - 1, dotW - 2.5f, 11), Draw.Center);
                dx += dotW;
                if (dx > r.Right - pad - dotW) break;
            }
        }

        // ==================== 버튼 ====================
        void LayoutButtons()
        {
            if (screen == Screen.Setup) { LayoutSetupButtons(); return; }
            if (modal != null) LayoutModalButtons(modal);
            if (screen == Screen.Over)
            {
                float bw = 190, bh = 52, gap = 16;
                float total = buttons.Count * bw + (buttons.Count - 1) * gap;
                float x = ClientSize.Width / 2f - total / 2;
                float y = ClientSize.Height * 0.72f;
                foreach (var b in buttons) { b.Rect = new RectangleF(x, y, bw, bh); x += bw + gap; }
                return;
            }
            // 플레이 중: 중앙 액션 영역
            var r = L.ActionRect;
            int n = buttons.Count;
            if (n == 0) return;
            float gp = 10f;
            float w = (r.Width - gp * (n - 1)) / n;
            float h = Math.Min(r.Height * 0.86f, 62f);
            float yy = r.Y + (r.Height - h) / 2;
            for (int i = 0; i < n; i++)
                buttons[i].Rect = new RectangleF(r.X + i * (w + gp), yy, w, h);
        }

        void LayoutModalButtons(Modal m)
        {
            int mn = m.Buttons.Count;
            if (mn == 0) return;
            var mr = ModalRect(m);
            if (m.Vertical)
            {
                float bh = 50f, gp2 = 8f;
                float total = mn * bh + (mn - 1) * gp2;
                float y0 = mr.Bottom - 16 - total;
                for (int i = 0; i < mn; i++)
                    m.Buttons[i].Rect = new RectangleF(mr.X + 18, y0 + i * (bh + gp2), mr.Width - 36, bh);
                return;
            }
            float gp = 10f;
            float mw = (mr.Width - 32 - gp * (mn - 1)) / mn;
            float mh = 54f;
            float my = mr.Bottom - mh - 16;
            for (int i = 0; i < mn; i++)
                m.Buttons[i].Rect = new RectangleF(mr.X + 16 + i * (mw + gp), my, mw, mh);
        }

        void DrawButtons(Graphics g, List<UiButton> list)
        {
            foreach (var b in list) DrawButton(g, b);
        }

        void DrawButton(Graphics g, UiButton b)
        {
            var r = b.Rect;
            if (r.Width <= 1) return;
            double inT = Ease.OutBack(b.In);
            float lift = (float)(b.Hover * 3 - b.Press * 4);
            var rr = new RectangleF(r.X, r.Y - lift, r.Width, r.Height);
            float sc = (float)(0.92 + 0.08 * inT);
            rr = new RectangleF(rr.X + rr.Width * (1 - sc) / 2, rr.Y + rr.Height * (1 - sc) / 2,
                rr.Width * sc, rr.Height * sc);
            float rad = 12f;
            int alpha = (int)(255 * Math.Min(1, b.In * 1.4)) ;

            Color c = b.Enabled ? b.Color : Color.FromArgb(60, 66, 88);
            if (b.Primary && b.Enabled)
                Draw.GlowRound(g, c, rr, rad, (float)(7 + b.Hover * 8 + Math.Sin(Time * 3) * 2), 1.0);

            Draw.FillRound(g, Draw.A(Color.Black, (int)(70 * (1 - b.Press))), new RectangleF(rr.X, rr.Y + 4, rr.Width, rr.Height), rad);
            Draw.FillRoundGrad(g,
                Draw.A(Draw.Lighten(c, 0.22 + b.Hover * 0.16), alpha),
                Draw.A(Draw.Darken(c, 0.16), alpha), rr, rad);
            Draw.StrokeRound(g, Draw.A(Draw.Lighten(c, 0.55), (int)(alpha * 0.8)), 1.3f, rr, rad);

            bool hasSub = !string.IsNullOrEmpty(b.Sub);
            var labelR = hasSub
                ? new RectangleF(rr.X, rr.Y + rr.Height * 0.08f, rr.Width, rr.Height * 0.56f)
                : rr;
            var lf = FitFont(g, b.Label, rr.Width - 14f, LabelLadder);
            Draw.TextIn(g, b.Label, lf, Draw.A(b.Enabled ? Color.White : Pal.Dim, alpha), labelR, Draw.Center);
            if (hasSub)
            {
                var sf = FitFont(g, b.Sub, rr.Width - 12f, SubLadder);
                Draw.TextIn(g, b.Sub, sf, Draw.A(Color.FromArgb(235, 240, 255), (int)(alpha * 0.75)),
                    new RectangleF(rr.X, rr.Y + rr.Height * 0.55f, rr.Width, rr.Height * 0.34f), Draw.Center);
            }
        }

        Font[] labelLadder, subLadder;
        Font[] LabelLadder
        {
            get
            {
                if (labelLadder == null) labelLadder = new[] { F.SubB, F.BodyB, F.Small, F.Tiny };
                return labelLadder;
            }
        }
        Font[] SubLadder
        {
            get
            {
                if (subLadder == null) subLadder = new[] { F.Small, F.Tiny };
                return subLadder;
            }
        }

        /// <summary>주어진 너비에 들어가는 가장 큰 폰트를 고른다.</summary>
        static Font FitFont(Graphics g, string s, float maxW, Font[] ladder)
        {
            if (string.IsNullOrEmpty(s) || maxW <= 0) return ladder[0];
            for (int i = 0; i < ladder.Length; i++)
                if (g.MeasureString(s, ladder[i], 3000, Draw.Center).Width <= maxW) return ladder[i];
            return ladder[ladder.Length - 1];
        }

        // ==================== 배너 ====================
        void DrawBannerLayer(Graphics g)
        {
            if (bannerT <= 0 || string.IsNullOrEmpty(bannerText)) return;
            double t = bannerT;
            double inT = Math.Min(1, (1 - Math.Max(0, t - 0.25)) * 4);
            double appear = Ease.OutQuint(Math.Min(1, inT));
            double fade = t < 0.25 ? t / 0.25 : 1;

            float h = Math.Max(70f, ClientSize.Height * 0.11f);
            float y = ClientSize.Height * 0.30f;
            float w = ClientSize.Width * 0.62f;
            float x = (float)(ClientSize.Width / 2f - w / 2 + (1 - appear) * ClientSize.Width * 0.35);

            var r = new RectangleF(x, y, w, h);
            int a = (int)(fade * 255);

            using (var b = new LinearGradientBrush(
                new RectangleF(r.X, r.Y, r.Width, r.Height),
                Draw.A(Draw.Darken(bannerColor, 0.55), (int)(a * 0.92)),
                Draw.A(Draw.Darken(bannerColor, 0.2), (int)(a * 0.92)), 0f))
            using (var p = Draw.RoundRect(r, 14))
                g.FillPath(b, p);
            Draw.StrokeRound(g, Draw.A(Draw.Lighten(bannerColor, 0.4), a), 2f, r, 14);
            Draw.GlowRound(g, bannerColor, r, 14, 12f, fade);

            bool hasSub = !string.IsNullOrEmpty(bannerSub);
            Draw.TextIn(g, bannerText, F.Huge, Draw.A(Color.White, a),
                hasSub ? new RectangleF(r.X, r.Y + h * 0.06f, r.Width, r.Height * 0.55f) : r, Draw.Center);
            if (hasSub)
                Draw.TextIn(g, bannerSub, F.Sub, Draw.A(Color.FromArgb(240, 245, 255), (int)(a * 0.9)),
                    new RectangleF(r.X, r.Y + h * 0.58f, r.Width, r.Height * 0.34f), Draw.Center);
        }

        // ==================== 모달 ====================
        RectangleF ModalRect(Modal m)
        {
            float w = Math.Max(380f, Math.Min(470f, ClientSize.Width * 0.42f));
            float h = 250f;
            if (m.CardCell != null) h = 524f;
            if (m.Chance != null) h = 400f;
            if (m.Buttons.Count == 0) h -= 62f;
            if (m.Vertical) h = 124f + m.Buttons.Count * 58f;
            h = Math.Min(h, ClientSize.Height - 40f);
            return new RectangleF(ClientSize.Width / 2f - w / 2, ClientSize.Height / 2f - h / 2, w, h);
        }

        void DrawModal(Graphics g, Modal m)
        {
            double t = Ease.OutBack(Math.Min(1, m.T));
            int veil = (int)(150 * Math.Min(1, m.T * 1.4));
            using (var b = new SolidBrush(Color.FromArgb(veil, 6, 8, 18)))
                g.FillRectangle(b, 0, 0, ClientSize.Width, ClientSize.Height);

            var r = ModalRect(m);
            var st = g.Save();
            g.TranslateTransform(r.X + r.Width / 2, r.Y + r.Height / 2);
            g.ScaleTransform((float)(0.86 + 0.14 * t), (float)(0.86 + 0.14 * t));
            g.TranslateTransform(-(r.X + r.Width / 2), -(r.Y + r.Height / 2));

            Draw.Shadow(g, r, 18, 10, 1.2);
            Draw.FillRoundGrad(g, Color.FromArgb(248, 44, 52, 92), Color.FromArgb(248, 26, 32, 60), r, 18);
            Draw.StrokeRound(g, Draw.A(m.Accent, 220), 2f, r, 18);
            Draw.GlowRound(g, m.Accent, r, 18, 14f, 0.9);

            float y = r.Y + 16;
            if (!string.IsNullOrEmpty(m.Title))
            {
                Draw.TextIn(g, m.Title, F.Title, Pal.White, new RectangleF(r.X, y, r.Width, 32), Draw.Center);
                y += 36;
            }

            if (m.Chance != null)
            {
                DrawChanceCard(g, m, new RectangleF(r.X + 30, y, r.Width - 60, 210));
                y += 220;
            }
            else if (m.CardCell != null)
            {
                DrawCityCard(g, m.CardCell, new RectangleF(r.X + r.Width / 2 - 134, y, 268, 326));
                y += 334;
            }

            if (!string.IsNullOrEmpty(m.Body))
            {
                Draw.TextIn(g, m.Body, F.Body, Draw.A(Pal.White, 225),
                    new RectangleF(r.X + 20, y, r.Width - 40, 52), Draw.CenterWrap);
            }

            if (m.Who != null && m.Buttons.Count == 0)
            {
                Draw.TextIn(g, m.Who.Name + " 의 선택", F.Small, Draw.A(m.Who.Color, 240),
                    new RectangleF(r.X, r.Bottom - 30, r.Width, 22), Draw.Center);
            }

            g.Restore(st);
            DrawButtons(g, m.Buttons);
        }

        void DrawCityCard(Graphics g, Cell c, RectangleF r)
        {
            Draw.FillRoundGrad(g, Color.FromArgb(250, 252, 255), Color.FromArgb(222, 228, 244), r, 14);
            Draw.StrokeRound(g, Draw.A(c.GroupColor, 255), 2.2f, r, 14);

            var band = new RectangleF(r.X, r.Y, r.Width, r.Height * 0.3f);
            var st = g.Save();
            using (var clip = Draw.RoundRect(r, 14)) { g.SetClip(clip); }
            using (var b = new LinearGradientBrush(
                new RectangleF(band.X, band.Y - 1, band.Width, band.Height + 2),
                Draw.Lighten(c.GroupColor, 0.25), c.GroupColor, 90f))
                g.FillRectangle(b, band);
            g.Restore(st);

            Icons.DrawFlag(g, c.Flag, new RectangleF(r.X + 14, band.Y + band.Height * 0.22f, 62, 41));
            Draw.TextIn(g, c.Name, F.Title, Color.White,
                new RectangleF(r.X + 86, band.Y + 8, r.Width - 96, 30), Draw.Left);
            Draw.TextIn(g, c.Country + (c.GroupId != null ? "  ·  " + Board.Groups[c.GroupId].Name : ""),
                F.Small, Draw.A(Color.White, 220), new RectangleF(r.X + 86, band.Y + 36, r.Width - 96, 20), Draw.Left);
            if (c.DoubleToll)
            {
                var chip = new RectangleF(r.Right - 96, band.Bottom + 6, 84, 20);
                Draw.FillRound(g, Color.FromArgb(238, 68, 68), chip, 10);
                Draw.TextIn(g, "통행료 2배", F.Small, Color.White, chip, Draw.Center);
            }

            float y = band.Bottom + 10;
            Draw.TextIn(g, "매입가  " + Fmt.Won(c.Price), F.SubB, Pal.Ink,
                new RectangleF(r.X + 16, y, r.Width - 32, 24), Draw.Left);
            y += 28;

            if (c.Type == CellType.Spot)
            {
                Draw.TextIn(g, "관광지  ·  건물 건설 불가", F.Small, Pal.InkSoft,
                    new RectangleF(r.X + 16, y, r.Width - 32, 20), Draw.Left);
                y += 24;
                Draw.TextIn(g, "통행료 = " + Fmt.M(c.Tolls[0]) + " x 보유 관광지 수", F.Body, Pal.Ink,
                    new RectangleF(r.X + 16, y, r.Width - 32, 22), Draw.Left);
                y += 26;
            }
            else
            {
                for (int i = 0; i <= Rules.MaxLevel; i++)
                {
                    bool cur = c.Owner >= 0 && c.Level == i;
                    bool lm = i == Rules.MaxLevel;
                    var rowR = new RectangleF(r.X + 12, y, r.Width - 24, 22);
                    if (cur) Draw.FillRound(g, Draw.A(lm ? Pal.Gold : c.GroupColor, lm ? 95 : 55), rowR, 6);
                    var col = cur ? Pal.Ink : (lm ? Pal.GoldDeep : Pal.InkSoft);
                    // 랜드마크 줄에는 그 도시의 실제 랜드마크 이름을 보여준다
                    string label = lm && c.Landmark != LandmarkKind.Generic
                        ? Board.LandmarkName(c.Landmark) : Board.LevelNames[i];
                    Draw.TextIn(g, label, cur || lm ? F.BodyB : F.Body, col,
                        new RectangleF(rowR.X + 8, rowR.Y, 116, rowR.Height), Draw.Left);
                    Draw.TextIn(g, Fmt.M(c.Tolls[i]), cur || lm ? F.BodyB : F.Body, col,
                        new RectangleF(rowR.X, rowR.Y, rowR.Width - 76, rowR.Height), Draw.Right);
                    if (i > 0)
                        Draw.TextIn(g, "건설 " + Fmt.M(c.BuildCost[i - 1]), F.Tiny,
                            lm ? Pal.GoldDeep : Pal.InkSoft,
                            new RectangleF(rowR.X, rowR.Y, rowR.Width - 8, rowR.Height), Draw.Right);
                    y += 23;
                }
            }

            if (c.Owner >= 0)
            {
                var op = G.Players[c.Owner];
                var or = new RectangleF(r.X + 12, r.Bottom - 34, r.Width - 24, 24);
                Draw.FillRound(g, Draw.A(op.Color, 60), or, 8);
                Draw.TextIn(g, "소유: " + op.Name + "   현재 통행료 " + Fmt.M(G.Toll(c)), F.Small, Pal.Ink, or, Draw.Center);
            }
            else if (c.GroupId != null)
            {
                Draw.TextIn(g, "독점 시 통행료 2배 · 랜드마크는 재방문 또는 출발 칸에서 건설", F.Tiny, Pal.InkSoft,
                    new RectangleF(r.X + 6, r.Bottom - 26, r.Width - 12, 20), Draw.Center);
            }
        }

        void DrawChanceCard(Graphics g, Modal m, RectangleF r)
        {
            double f = m.Flip;
            // 0 -> 0.5 : 뒷면이 납작해짐, 0.5 -> 1 : 앞면이 펼쳐짐
            double sx = f < 0.5 ? 1 - f * 2 : (f - 0.5) * 2;

            var st = g.Save();
            g.TranslateTransform(r.X + r.Width / 2, r.Y + r.Height / 2);
            g.ScaleTransform((float)Math.Max(0.03, sx), 1f);
            g.TranslateTransform(-(r.X + r.Width / 2), -(r.Y + r.Height / 2));

            if (f < 0.5)
            {
                // 카드 뒷면
                Draw.FillRoundGrad(g, Color.FromArgb(214, 152, 20), Color.FromArgb(150, 100, 10), r, 14);
                Draw.StrokeRound(g, Pal.Gold, 2.4f, r, 14);
                Icons.DrawSpecial(g, CellType.Chance,
                    new RectangleF(r.X + r.Width / 2 - 45, r.Y + r.Height / 2 - 50, 90, 100), Time);
                Draw.TextIn(g, "황금열쇠", F.Title, Color.FromArgb(255, 250, 220),
                    new RectangleF(r.X, r.Bottom - 46, r.Width, 30), Draw.Center);
            }
            else
            {
                Draw.FillRoundGrad(g, Color.FromArgb(252, 250, 240), Color.FromArgb(232, 226, 206), r, 14);
                Draw.StrokeRound(g, Pal.GoldDeep, 2.4f, r, 14);
                Icons.DrawSpecial(g, CellType.Chance,
                    new RectangleF(r.X + r.Width / 2 - 30, r.Y + 8, 60, 62), Time);
                Draw.TextIn(g, m.Chance.Text, F.SubB, Color.FromArgb(40, 36, 30),
                    new RectangleF(r.X + 18, r.Y + 76, r.Width - 36, r.Height - 96), Draw.CenterWrap);
            }
            g.Restore(st);
        }

        // ==================== 칸 정보 툴팁 ====================
        void DrawHoverInfo(Graphics g)
        {
            if (hoverCell < 0 || G == null) return;
            var c = G.Cells[hoverCell];
            if (!c.IsProperty) return;

            string l1 = c.Name + "  (" + c.Country + ")" + (c.DoubleToll ? "   ★ 통행료 2배 지역" : "");
            string l2 = c.Owner >= 0
                ? "소유 " + G.Players[c.Owner].Name + "  ·  " + Board.LevelNames[c.Level] + "  ·  통행료 " + Fmt.Won(G.Toll(c))
                : "미소유  ·  매입가 " + Fmt.Won(c.Price);
            string l3;
            if (c.Type != CellType.City)
                l3 = "관광지 통행료 " + Fmt.Won(c.Tolls[0]) + " x 보유수";
            else if (c.Level < Rules.HotelLevel)
                l3 = "다음 건설 " + Board.LevelNames[c.Level + 1] + " " + Fmt.Won(c.BuildCost[c.Level]);
            else if (c.Level == Rules.HotelLevel)
                l3 = "재방문 시 랜드마크 " + Fmt.Won(c.BuildCost[Rules.HotelLevel]);
            else
                l3 = "랜드마크 완성 · 인수 불가";

            float w = 268, h = 76;
            float x = Math.Min(mouse.X + 16, ClientSize.Width - w - 8);
            float y = Math.Min(mouse.Y + 14, ClientSize.Height - h - 8);
            var r = new RectangleF(x, y, w, h);
            Draw.FillRound(g, Color.FromArgb(238, 18, 22, 44), r, 10);
            Draw.StrokeRound(g, Draw.A(c.GroupColor, 230), 1.6f, r, 10);
            Draw.TextIn(g, l1, F.BodyB, Pal.White, new RectangleF(r.X + 10, r.Y + 6, r.Width - 20, 20), Draw.Left);
            Draw.TextIn(g, l2, F.Small, Draw.A(Pal.Dim, 235), new RectangleF(r.X + 10, r.Y + 28, r.Width - 20, 18), Draw.Left);
            Draw.TextIn(g, l3, F.Small, Draw.A(Pal.Dim, 200), new RectangleF(r.X + 10, r.Y + 48, r.Width - 20, 18), Draw.Left);
        }

        // ==================== 셋업 화면 ====================
        void LayoutSetupButtons()
        {
            float cw = Math.Min(560f, ClientSize.Width * 0.62f);
            float cx = ClientSize.Width / 2f;
            float top = ClientSize.Height * 0.30f;
            float rowH = 54f;

            // [1] minus, [2] plus
            buttons[1].Rect = new RectangleF(cx + cw / 2 - 108, top - 46, 44, 34);
            buttons[2].Rect = new RectangleF(cx + cw / 2 - 56, top - 46, 44, 34);

            for (int i = 0; i < 4; i++)
            {
                var b = buttons[3 + i];
                b.Enabled = i < setupCount;
                b.Label = setupAI[i] ? "AI" : "사람";
                b.Color = setupAI[i] ? Color.FromArgb(99, 102, 241) : Color.FromArgb(34, 197, 94);
                b.Rect = new RectangleF(cx + cw / 2 - 108, top + i * (rowH + 8) + 8, 96, 38);
            }
            buttons[0].Rect = new RectangleF(cx - 130, top + 4 * (rowH + 8) + 26, 260, 62);
        }

        void DrawSetup(Graphics g)
        {
            float cx = ClientSize.Width / 2f;
            double t = Math.Min(1, introT * 0.8);

            // 타이틀
            string logo = "세계마뷸";
            using (var f = new Font(F.Mega.FontFamily, 58f, FontStyle.Bold))
            {
                float total = 0;
                var ws = new float[logo.Length];
                for (int i = 0; i < logo.Length; i++)
                { ws[i] = g.MeasureString(logo[i].ToString(), f, 300, Draw.Center).Width * 0.8f; total += ws[i]; }
                float x = cx - total / 2;
                for (int i = 0; i < logo.Length; i++)
                {
                    double d = Math.Max(0, Math.Min(1, (introT - i * 0.12) * 3));
                    double pop = Ease.OutBack(d);
                    float yy = (float)(ClientSize.Height * 0.15 + (1 - pop) * -60);
                    float bob = (float)(Math.Sin(Time * 2 + i * 0.7) * 6);
                    var col = Draw.Mix(Pal.Gold, Color.FromArgb(255, 245, 210), 0.5 + 0.5 * Math.Sin(Time * 2 + i));
                    var st = g.Save();
                    g.TranslateTransform(x + ws[i] / 2, yy + bob);
                    g.ScaleTransform((float)pop, (float)pop);
                    Draw.Text(g, logo[i].ToString(), f, Draw.A(Color.Black, (int)(120 * d)), 3, 4);
                    Draw.Text(g, logo[i].ToString(), f, Draw.A(col, (int)(255 * d)), 0, 0);
                    g.Restore(st);
                    x += ws[i];
                }
            }
            Draw.Text(g, "B L U E   M A R B L E", F.Sub, Draw.A(Pal.Dim, (int)(220 * t)),
                cx, ClientSize.Height * 0.15f + 62);

            // 패널
            float cw = Math.Min(560f, ClientSize.Width * 0.62f);
            float top = ClientSize.Height * 0.30f;
            var panel = new RectangleF(cx - cw / 2, top - 62, cw, 4 * 62 + 130);
            Draw.FillRoundGrad(g, Color.FromArgb(236, 40, 48, 86), Color.FromArgb(236, 24, 30, 58), panel, 18);
            Draw.StrokeRound(g, Color.FromArgb(90, 255, 255, 255), 1.4f, panel, 18);

            Draw.TextIn(g, "플레이어 " + setupCount + "명", F.SubB, Pal.White,
                new RectangleF(panel.X + 22, top - 46, 200, 34), Draw.Left);

            for (int i = 0; i < 4; i++)
            {
                bool on = i < setupCount;
                var rr = new RectangleF(panel.X + 18, top + i * 62 + 4, cw - 36, 50);
                Draw.FillRound(g, Draw.A(on ? Draw.Mix(Pal.Panel, PlayerColors[i], 0.2) : Pal.Panel, on ? 235 : 90), rr, 12);
                Draw.StrokeRound(g, Draw.A(PlayerColors[i], on ? 200 : 60), 1.4f, rr, 12);
                // Game.AssignFaces 와 같은 규칙 — 사람은 0번, AI 는 1~3번을 순서대로
                int aiOrd = 0;
                for (int k = 0; k < i; k++) if (setupAI[k]) aiOrd++;
                Icons.DrawToken(g, rr.X + 30, rr.Y + rr.Height / 2, 17, PlayerColors[i], 0, false, on ? 1 : 0,
                    Time + i, on ? 1 : 0.35, setupAI[i] ? 1 + aiOrd % 3 : 0);
                Draw.TextIn(g, PlayerNames[i], F.SubB, Draw.A(Pal.White, on ? 255 : 110),
                    new RectangleF(rr.X + 58, rr.Y, 160, rr.Height), Draw.Left);
                if (!on)
                    Draw.TextIn(g, "미참가", F.Small, Draw.A(Pal.Dim, 150),
                        new RectangleF(rr.X, rr.Y, rr.Width - 130, rr.Height), Draw.Right);
            }

            DrawButtons(g, buttons);

            Draw.Text(g, "무설치 단일 실행 파일  ·  Space 시작   Tab 속도 조절",
                F.Small, Draw.A(Pal.Dim, 170), cx, ClientSize.Height - 34);
        }

        // ==================== 결과 화면 ====================
        void DrawGameOver(Graphics g)
        {
            double t = Math.Min(1, overT * 1.2);
            using (var b = new SolidBrush(Color.FromArgb((int)(180 * t), 6, 8, 18)))
                g.FillRectangle(b, 0, 0, ClientSize.Width, ClientSize.Height);

            float cx = ClientSize.Width / 2f;
            float w = Math.Min(520f, ClientSize.Width * 0.5f);
            float h = 330f;
            var r = new RectangleF(cx - w / 2, ClientSize.Height * 0.22f, w, h);
            double pop = Ease.OutBack(Math.Min(1, overT * 1.6));
            var st = g.Save();
            g.TranslateTransform(r.X + r.Width / 2, r.Y + r.Height / 2);
            g.ScaleTransform((float)(0.8 + 0.2 * pop), (float)(0.8 + 0.2 * pop));
            g.TranslateTransform(-(r.X + r.Width / 2), -(r.Y + r.Height / 2));

            Draw.Shadow(g, r, 20, 12, 1.2);
            Draw.FillRoundGrad(g, Color.FromArgb(250, 48, 42, 20), Color.FromArgb(250, 26, 24, 44), r, 20);
            Draw.StrokeRound(g, Pal.Gold, 2.4f, r, 20);
            Draw.GlowRound(g, Pal.Gold, r, 20, 18f, 1.0 + 0.4 * Math.Sin(Time * 2));

            Draw.TextIn(g, "게임 종료", F.Sub, Draw.A(Pal.Dim, 230),
                new RectangleF(r.X, r.Y + 14, r.Width, 26), Draw.Center);

            if (G != null && G.Winner != null)
            {
                float ty = r.Y + 96;
                double bob = Math.Sin(Time * 3) * 6;
                Icons.DrawToken(g, cx, (float)(ty + bob), 34, G.Winner.Color, 0, false, 1, Time, 1, G.Winner.Face);
                for (int i = 0; i < 6; i++)
                {
                    double a = Time * 1.4 + i * Math.PI / 3;
                    Draw.Star(g, Draw.A(Pal.Gold, 150), cx + (float)(Math.Cos(a) * 66),
                        (float)(ty + Math.Sin(a) * 40), 7f, 5, a);
                }
                Draw.TextIn(g, G.Winner.Name + " 승리!", F.Huge, Pal.Gold,
                    new RectangleF(r.X, ty + 44, r.Width, 44), Draw.Center);

                // 순위
                var list = new List<Player>(G.Players);
                list.Sort(delegate (Player a, Player b) { return G.NetWorth(b).CompareTo(G.NetWorth(a)); });
                float y = ty + 96;
                for (int i = 0; i < list.Count; i++)
                {
                    var p = list[i];
                    var rr = new RectangleF(r.X + 40, y, r.Width - 80, 26);
                    Draw.FillRound(g, Draw.A(p.Color, p.Alive ? 70 : 30), rr, 7);
                    Draw.TextIn(g, (i + 1) + ".  " + p.Name + (p.Alive ? "" : " (파산)"), F.Body,
                        Draw.A(Pal.White, p.Alive ? 245 : 150),
                        new RectangleF(rr.X + 10, rr.Y, rr.Width - 20, rr.Height), Draw.Left);
                    Draw.TextIn(g, Fmt.Won(G.NetWorth(p)), F.BodyB, Draw.A(Pal.Gold, p.Alive ? 245 : 140),
                        new RectangleF(rr.X, rr.Y, rr.Width - 10, rr.Height), Draw.Right);
                    y += 29;
                }
            }
            g.Restore(st);
            DrawButtons(g, buttons);
        }
    }
}
