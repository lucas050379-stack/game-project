using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Segyemabyul
{
    class Anim
    {
        public double T, Dur;
        public Func<double, double> Ease;
        public Action<double> Apply;
        public TaskCompletionSource<bool> Tcs;
    }

    class UiButton
    {
        public RectangleF Rect;
        public string Label, Sub;
        public Color Color;
        public bool Enabled = true;
        public bool Primary;
        public double Hover, Press, In;
        public Action OnClick;
        public char Hotkey;
    }

    class ButtonSpec
    {
        public string Label, Sub;
        public Color Color;
        public bool Enabled = true;
        public bool Primary;
        public ButtonSpec(string label) { Label = label; Color = Pal.PanelHi; }
        public ButtonSpec(string label, string sub, Color c, bool primary)
        { Label = label; Sub = sub; Color = c; Primary = primary; }
    }

    class Modal
    {
        public string Title, Body;
        public Cell CardCell;
        public Card Chance;
        public Color Accent = Pal.Accent;
        public List<UiButton> Buttons = new List<UiButton>();
        public double T, Flip = 1;
        public bool Closing;
        public bool Vertical;     // 버튼을 세로로 배치 (긴 라벨용)
        public TaskCompletionSource<int> Tcs;
        public Player Who;
    }

    enum Screen { Setup, Play, Over }

    partial class GameForm : Form
    {
        Game G;
        Fx fx = new Fx();
        Lay L = new Lay();
        Screen screen = Screen.Setup;

        readonly List<Anim> anims = new List<Anim>();
        readonly List<Anim> done = new List<Anim>();
        List<UiButton> buttons = new List<UiButton>();
        Modal modal;

        double Time;
        double Speed = 1;
        Stopwatch clock = new Stopwatch();
        Timer timer;
        Point mouse;

        // 주사위
        int die1 = 1, die2 = 1;
        double dieRot1, dieRot2, dieScale = 1;
        bool diceVisible, diceRolling, diceRolled;
        double diceGlow;

        // 배너
        string bannerText, bannerSub;
        Color bannerColor = Pal.Accent;
        double bannerT;

        // 안내 문구
        string prompt = "";

        // 칸 선택 모드
        bool picking;
        Func<Cell, bool> pickFilter;
        TaskCompletionSource<int> pickTcs;
        int hoverCell = -1;

        // 셋업 화면 상태
        int setupCount = 4;
        bool[] setupAI = { false, true, true, true };
        double introT;

        // 결과 화면
        double overT;

        public GameForm()
        {
            Text = "세계마뷸 - World Marble";
            ClientSize = new Size(1380, 880);
            MinimumSize = new Size(1120, 760);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Pal.Bg0;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            KeyPreview = true;

            F.Init();
            BuildSetupUi();

            clock.Start();
            timer = new Timer();
            timer.Interval = 15;
            timer.Tick += OnTick;
            timer.Start();

            MouseMove += delegate (object s, MouseEventArgs e) { mouse = e.Location; };
            MouseDown += OnMouseDown;
            KeyDown += OnKeyDown;
        }

        // ==================== 루프 ====================

        double lastMs;
        void OnTick(object sender, EventArgs e)
        {
            double now = clock.Elapsed.TotalSeconds;
            double dt = now - lastMs;
            lastMs = now;
            if (dt > 0.1) dt = 0.1;
            Update(dt);
            Invalidate();
        }

        void Update(double dtReal)
        {
            double dt = dtReal * Speed;
            L.Compute(ClientSize.Width, ClientSize.Height, G != null ? G.Players.Count : 4);
            Time += dtReal;
            introT += dtReal;
            if (screen == Screen.Over) overT += dtReal;

            // 트윈 진행
            done.Clear();
            for (int i = 0; i < anims.Count; i++)
            {
                var a = anims[i];
                a.T += dt;
                double t = a.Dur <= 0 ? 1 : Math.Min(1, a.T / a.Dur);
                if (a.Apply != null) a.Apply(a.Ease(t));
                if (t >= 1) done.Add(a);
            }
            for (int i = 0; i < done.Count; i++) anims.Remove(done[i]);
            for (int i = 0; i < done.Count; i++)
                if (done[i].Tcs != null) done[i].Tcs.TrySetResult(true);

            fx.Update(dt);

            if (bannerT > 0) bannerT -= dtReal;

            // 버튼 호버/등장
            UpdateButtons(buttons, dtReal);
            if (modal != null)
            {
                UpdateButtons(modal.Buttons, dtReal);
                modal.T = Math.Min(1, modal.T + dtReal * 5.5);
            }

            if (G != null)
            {
                foreach (var p in G.Players)
                {
                    p.Bob += dtReal * 3.2;
                    if (p.Emote > 0) p.Emote -= dtReal;
                    else p.EmoteKind = 0;
                    p.DisplayCash += (p.Cash - p.DisplayCash) * Math.Min(1, dtReal * 7);
                    if (Math.Abs(p.DisplayCash - p.Cash) < 0.4) p.DisplayCash = p.Cash;
                }
                G.FundDisplay += (G.Fund - G.FundDisplay) * Math.Min(1, dtReal * 6);
                foreach (var c in G.Cells)
                {
                    if (c.OwnWave > 0) c.OwnWave = Math.Max(0, c.OwnWave - dtReal * 1.6);
                    if (c.Shake > 0) c.Shake = Math.Max(0, c.Shake - dtReal * 4);
                }
                if (diceGlow > 0) diceGlow = Math.Max(0, diceGlow - dtReal * 1.2);
            }

            // 커서
            bool overBtn = HitButton(buttons) != null ||
                           (modal != null && HitButton(modal.Buttons) != null);
            if (picking && hoverCell >= 0) overBtn = true;
            Cursor = overBtn ? Cursors.Hand : Cursors.Default;

            hoverCell = -1;
            if (screen == Screen.Play && modal == null)
            {
                for (int i = 0; i < Rules.BoardSize; i++)
                    if (L.CellRect(i).Contains(mouse)) { hoverCell = i; break; }
            }
        }

        void UpdateButtons(List<UiButton> list, double dt)
        {
            foreach (var b in list)
            {
                bool hot = b.Enabled && b.Rect.Contains(mouse);
                b.Hover += ((hot ? 1 : 0) - b.Hover) * Math.Min(1, dt * 12);
                b.Press = Math.Max(0, b.Press - dt * 4);
                b.In = Math.Min(1, b.In + dt * 6);
            }
        }

        // ==================== 애니메이션 프리미티브 ====================

        Task Tween(double dur, Func<double, double> ease, Action<double> apply)
        {
            var a = new Anim
            {
                Dur = dur, Ease = ease, Apply = apply,
                Tcs = new TaskCompletionSource<bool>()
            };
            anims.Add(a);
            return a.Tcs.Task;
        }

        void TweenFF(double dur, Func<double, double> ease, Action<double> apply)
        {
            anims.Add(new Anim { Dur = dur, Ease = ease, Apply = apply });
        }

        Task Delay(double sec)
        {
            return Tween(sec, Ease.Linear, null);
        }

        // ==================== 입력 ====================

        UiButton HitButton(List<UiButton> list)
        {
            for (int i = list.Count - 1; i >= 0; i--)
                if (list[i].Enabled && list[i].Rect.Contains(mouse)) return list[i];
            return null;
        }

        void OnMouseDown(object sender, MouseEventArgs e)
        {
            mouse = e.Location;
            if (screen != Screen.Setup && speedBtnRect.Contains(mouse))
            {
                CycleSpeed();
                fx.Sparkle(speedBtnRect.X + speedBtnRect.Width / 2, speedBtnRect.Y + speedBtnRect.Height / 2, 6, Pal.Accent, 10);
                return;
            }
            var list = modal != null ? modal.Buttons : buttons;
            var b = HitButton(list);
            if (b != null)
            {
                b.Press = 1;
                fx.Sparkle(b.Rect.X + b.Rect.Width / 2, b.Rect.Y + b.Rect.Height / 2, 6, b.Color, 12);
                if (b.OnClick != null) b.OnClick();
                return;
            }
            if (picking && modal == null)
            {
                for (int i = 0; i < Rules.BoardSize; i++)
                {
                    if (!L.CellRect(i).Contains(mouse)) continue;
                    if (pickFilter != null && !pickFilter(G.Cells[i])) return;
                    var r = L.CellRect(i);
                    fx.Ring(r.X + r.Width / 2, r.Y + r.Height / 2, Pal.Gold, r.Width * 0.7, 0.5);
                    picking = false;
                    var t = pickTcs; pickTcs = null;
                    if (t != null) t.TrySetResult(i);
                    return;
                }
            }
        }

        void OnKeyDown(object sender, KeyEventArgs e)
        {
            var list = modal != null ? modal.Buttons : buttons;
            if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter)
            {
                foreach (var b in list)
                    if (b.Enabled && b.Primary) { b.Press = 1; if (b.OnClick != null) b.OnClick(); return; }
                if (list.Count > 0 && list[0].Enabled)
                { list[0].Press = 1; if (list[0].OnClick != null) list[0].OnClick(); }
                return;
            }
            if (e.KeyCode >= Keys.D1 && e.KeyCode <= Keys.D9)
            {
                int idx = e.KeyCode - Keys.D1;
                if (idx < list.Count && list[idx].Enabled)
                { list[idx].Press = 1; if (list[idx].OnClick != null) list[idx].OnClick(); }
                return;
            }
            if (e.KeyCode == Keys.Tab) { CycleSpeed(); e.SuppressKeyPress = true; }
            if (e.KeyCode == Keys.Escape && screen == Screen.Play)
            {
                if (MessageBox.Show("게임을 종료하고 처음으로 돌아갈까요?", "세계마뷸",
                    MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes)
                    Application.Restart();
            }
        }

        void CycleSpeed()
        {
            if (Speed < 1.5) Speed = 2;
            else if (Speed < 3) Speed = 4;
            else Speed = 1;
        }

        // ==================== 셋업 화면 ====================

        void BuildSetupUi()
        {
            buttons = new List<UiButton>();
            // 실제 위치는 Render 에서 배치 후 사용 (Lay 기준)
            var start = new UiButton { Label = "게임 시작", Primary = true, Color = Color.FromArgb(34, 197, 94) };
            start.OnClick = delegate { BeginGame(); };
            buttons.Add(start);

            var minus = new UiButton { Label = "−", Color = Pal.PanelHi };
            minus.OnClick = delegate { if (setupCount > 2) setupCount--; };
            buttons.Add(minus);

            var plus = new UiButton { Label = "+", Color = Pal.PanelHi };
            plus.OnClick = delegate { if (setupCount < 4) setupCount++; };
            buttons.Add(plus);

            for (int i = 0; i < 4; i++)
            {
                int idx = i;
                var t = new UiButton { Label = "", Color = Pal.PanelHi };
                t.OnClick = delegate { setupAI[idx] = !setupAI[idx]; };
                buttons.Add(t);
            }
        }

        static readonly Color[] PlayerColors =
        {
            Color.FromArgb(239, 68, 68),
            Color.FromArgb(59, 130, 246),
            Color.FromArgb(34, 197, 94),
            Color.FromArgb(234, 179, 8)
        };
        static readonly string[] PlayerNames = { "빨강", "파랑", "초록", "노랑" };

        void BeginGame()
        {
            var ps = new List<Player>();
            for (int i = 0; i < setupCount; i++)
            {
                string nm = PlayerNames[i] + (setupAI[i] ? " (AI)" : "");
                ps.Add(new Player(i, nm, PlayerColors[i], setupAI[i]));
            }
            G = new Game(ps);
            screen = Screen.Play;
            buttons = new List<UiButton>();
            fx.Clear();
            G.AddLog("게임 시작! 각자 " + Fmt.Won(Rules.StartCash) + "으로 출발합니다.", Pal.Gold);
            var dbl = G.DoubleTollCells();
            if (dbl.Count > 0)
            {
                string names = "";
                for (int i = 0; i < dbl.Count; i++) names += (i > 0 ? ", " : "") + dbl[i].Name;
                G.AddLog("이번 게임의 통행료 2배 지역: " + names, Color.FromArgb(248, 113, 113));
            }
            RunGame();
        }

        // ==================== 메인 진행 ====================

        async void RunGame()
        {
            try { await RunGameLoop(); }
            catch (Exception ex)
            {
                modal = null;
                picking = false;
                buttons = new List<UiButton>();
                if (G != null) G.AddLog("오류: " + ex.Message, Pal.Bad);
                MessageBox.Show("게임 진행 중 오류가 발생했습니다.\n\n" + ex.Message,
                    "세계마뷸", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                RestartToSetup();
            }
        }

        async Task RunGameLoop()
        {
            fx.Confetti(ClientSize.Width, ClientSize.Height, 40);
            await Banner("세계마뷸", "게임 시작!", Pal.Gold, 1.4);
            await Delay(0.2);

            // 통행료 2배 지역 소개 연출
            var dblCells = G.DoubleTollCells();
            if (dblCells.Count > 0)
            {
                string names = "";
                for (int i = 0; i < dblCells.Count; i++) names += (i > 0 ? "  ·  " : "") + dblCells[i].Name;
                await Banner("통행료 2배 지역", names, Color.FromArgb(239, 68, 68), 1.6);
                foreach (var c in dblCells)
                {
                    var rr = L.CellRect(c.Index);
                    var cp = new PointF(rr.X + rr.Width / 2, rr.Y + rr.Height / 2);
                    c.Pulse = 1;
                    TweenFF(1.0, Ease.OutQuad, delegate (double t) { c.Pulse = 1 - t; });
                    fx.Ring(cp.X, cp.Y, Color.FromArgb(239, 68, 68), rr.Width, 0.8);
                    fx.Burst(cp.X, cp.Y, 18, Color.FromArgb(248, 113, 113), 220, 5, 2);
                    fx.Float("x2", cp.X, cp.Y - rr.Height * 0.4f, Color.FromArgb(248, 113, 113), F.Huge, 26, 1.4);
                }
                fx.Kick(10);
                await Delay(1.1);
            }

            while (!G.Over)
            {
                var p = G.Current;
                if (!p.Alive) { G.NextTurn(); continue; }

                await TakeTurn(p);

                if (CheckOver()) break;
                G.NextTurn();
                await Delay(0.12);

                if (G.Round > 40)
                {
                    G.AddLog("40라운드 종료! 최고 자산 승리 판정", Pal.Gold);
                    Player best = null; int bv = -1;
                    foreach (var q in G.Players)
                        if (q.Alive && G.NetWorth(q) > bv) { bv = G.NetWorth(q); best = q; }
                    G.Winner = best; G.Over = true;
                }
            }
            await ShowGameOver();
        }

        bool CheckOver()
        {
            if (G.AlivePlayers() > 1) return false;
            foreach (var p in G.Players) if (p.Alive) G.Winner = p;
            G.Over = true;
            return true;
        }

        async Task TakeTurn(Player p)
        {
            prompt = "";
            await Banner(p.Name + "의 차례", "라운드 " + G.Round, p.Color, 0.95);

            if (p.PendingSpace)
            {
                p.PendingSpace = false;
                await DoSpaceTravel(p);
                return;
            }

            if (p.JailTurns > 0)
            {
                bool escaped = await JailPhase(p);
                if (!escaped) return;
            }

            int doubles = 0;
            while (true)
            {
                bool dbl = await RollDice(p);
                if (dbl)
                {
                    doubles++;
                    if (doubles >= 3)
                    {
                        G.AddLog(p.Name + " 3연속 더블! 무인도로 갑니다.", Pal.Bad);
                        await Banner("3연속 더블!", "무인도로 추방", Pal.Bad, 1.0);
                        await SendToJail(p);
                        return;
                    }
                }

                await MoveSteps(p, die1 + die2);
                await ResolveCell(p);

                if (!p.Alive || G.Over) return;

                // 우주여행 대기 / 무인도 수감이 되면 더블이어도 이번 턴은 여기서 끝
                if (p.PendingSpace || p.JailTurns > 0)
                {
                    if (dbl)
                        G.AddLog(p.Name + " 더블이지만 "
                            + (p.PendingSpace ? "우주여행 준비로" : "무인도 수감으로")
                            + " 턴을 마칩니다.", Pal.Dim);
                    return;
                }

                if (!dbl) break;

                await Banner("더블!", "한 번 더 굴립니다", Pal.Gold, 0.8);
            }
        }

        async Task<bool> JailPhase(Player p)
        {
            var pt = L.TokenPoint(G, p);
            fx.Float("무인도 " + p.JailTurns + "턴", pt.X, pt.Y - L.CellSize * 0.5, Pal.Bad, F.SubB, 30, 1.0);

            if (p.EscapeCards > 0)
            {
                bool use = p.IsAI ? Ai.WantUseEscapeCard(G, p)
                                  : await Ask("무인도 탈출권", "탈출권을 사용해 즉시 탈출할까요?", null, null,
                                        p.Color, new ButtonSpec("사용한다", "탈출권 1장 소모", Pal.Good, true),
                                        new ButtonSpec("아낀다", "주사위로 더블 도전", Pal.PanelHi, false)) == 0;
                if (use)
                {
                    p.EscapeCards--;
                    p.JailTurns = 0;
                    G.AddLog(p.Name + " 탈출권 사용! 무인도를 벗어납니다.", Pal.Good);
                    await Splash(p, Pal.Good, "탈출!");
                    return true;
                }
            }

            prompt = "무인도 탈출 시도 — 더블이 나오면 즉시 탈출!";
            bool dbl = await RollDice(p);
            if (dbl)
            {
                p.JailTurns = 0;
                G.AddLog(p.Name + " 더블 성공! 무인도 탈출!", Pal.Good);
                await Banner("탈출 성공!", "더블!", Pal.Good, 0.9);
                await MoveSteps(p, die1 + die2);
                await ResolveCell(p);
                return false;
            }

            p.JailTurns--;
            if (p.JailTurns <= 0)
            {
                G.AddLog(p.Name + " 구조되었습니다. 무인도를 벗어납니다.", Pal.Accent);
                await Banner("구조됨", "무인도 탈출", Pal.Accent, 0.9);
                await MoveSteps(p, die1 + die2);
                await ResolveCell(p);
            }
            else
            {
                p.Emit(2, 1.0);
                G.AddLog(p.Name + " 탈출 실패. " + p.JailTurns + "턴 더 대기.", Pal.Dim);
                await Delay(0.55);
            }
            return false;
        }

        // ==================== 주사위 ====================

        async Task<bool> RollDice(Player p)
        {
            diceVisible = true;
            if (!p.IsAI)
            {
                prompt = "주사위를 굴려주세요";
                await WaitButtons(new ButtonSpec("주사위 굴리기", "Space", Pal.Gold, true));
            }
            else
            {
                prompt = p.Name + " 생각 중...";
                await Delay(0.4);
            }

            prompt = "";
            diceRolling = true;
            int target1 = Rnd.Int(1, 7), target2 = Rnd.Int(1, 7);

            var dr = L.DiceRect;
            double spin = 0;
            await Tween(0.62, Ease.Linear, delegate (double t)
            {
                spin = t;
                dieRot1 = t * 26; dieRot2 = -t * 22;
                dieScale = 1 + Math.Sin(t * Math.PI) * 0.35;
                if ((int)(t * 40) != (int)(spin * 40)) { }
                die1 = Rnd.Int(1, 7); die2 = Rnd.Int(1, 7);
            });

            die1 = target1; die2 = target2;
            diceRolling = false;
            diceRolled = true;
            fx.Kick(6);
            fx.Burst(dr.X + dr.Width / 2, dr.Y + dr.Height / 2, 14, Pal.White, 260, 4, 0);
            await Tween(0.34, Ease.OutBack, delegate (double t)
            {
                dieRot1 = (1 - t) * 1.2; dieRot2 = -(1 - t) * 1.0;
                dieScale = 1 + (1 - t) * 0.45;
            });
            dieRot1 = dieRot2 = 0; dieScale = 1;

            bool dbl = die1 == die2;
            G.AddLog(p.Name + " 주사위 " + die1 + " + " + die2 + " = " + (die1 + die2) + (dbl ? "  (더블!)" : ""),
                dbl ? Pal.Gold : Pal.Dim);

            if (dbl)
            {
                diceGlow = 1;
                fx.Burst(dr.X + dr.Width / 2, dr.Y + dr.Height / 2, 22, Pal.Gold, 320, 5, 2);
                fx.Ring(dr.X + dr.Width / 2, dr.Y + dr.Height / 2, Pal.Gold, 70, 0.55);
                fx.Kick(9);
                await Delay(0.28);
            }
            else await Delay(0.12);

            return dbl;
        }

        // ==================== 이동 ====================

        /// <summary>진행 방향으로 steps 칸 이동. 출발 칸을 지나가면 급여를 받는다.</summary>
        async Task MoveSteps(Player p, int steps) { await MoveSteps(p, steps, false, Color.Empty); }

        async Task MoveSteps(Player p, int steps, bool trail, Color trailColor)
        {
            for (int i = 0; i < steps; i++)
            {
                int from = p.Pos, to = (from + 1) % Rules.BoardSize;
                p.HopFrom = from; p.HopTo = to;
                double dur = Math.Max(0.085, 0.20 - steps * 0.008);
                await Tween(dur, Ease.Linear, delegate (double t) { p.HopT = t; });
                p.HopT = -1;
                p.Pos = to;
                Land(p);

                if (trail)
                {
                    var tp = L.TokenPoint(G, p);
                    fx.Sparkle(tp.X, tp.Y, 4, trailColor, L.CellSize * 0.18);
                }

                if (to == 0 && i < steps - 1)
                {
                    await Gain(p, Rules.Salary, "출발 통과 급여");
                }
            }
            await Delay(0.1);
        }

        void Land(Player p)
        {
            p.Squash = 1;
            TweenFF(0.22, Ease.OutQuad, delegate (double t) { p.Squash = 1 - t; });
            var pt = L.TokenPoint(G, p);
            fx.Dust(pt.X, pt.Y + L.CellSize * 0.16, Color.FromArgb(220, 230, 250));
            fx.Kick(1.6);
        }

        /// <summary>순간이동(포물선 점프). 강제 이송(무인도)에만 사용하며 급여는 없다.</summary>
        async Task JumpTo(Player p, int to, Color trail)
        {
            int from = p.Pos;
            if (from == to) return;
            p.HopFrom = from; p.HopTo = to;
            p.Scale = 1;

            var a = L.CellCenter(from);
            var b = L.CellCenter(to);
            double lastX = a.X, lastY = a.Y;
            await Tween(0.72, Ease.InOutCubic, delegate (double t)
            {
                p.HopT = t;
                double x = a.X + (b.X - a.X) * t;
                double y = a.Y + (b.Y - a.Y) * t - Math.Sin(t * Math.PI) * L.BoardSize * 0.22;
                if (Math.Abs(x - lastX) + Math.Abs(y - lastY) > 14)
                {
                    fx.Parts.Add(new Particle
                    {
                        X = x, Y = y, VX = Rnd.Signed(20), VY = Rnd.Signed(20),
                        Life = 0.45, MaxLife = 0.45, Size = 5.5, Color = trail, Kind = 0, Drag = 0.9
                    });
                    lastX = x; lastY = y;
                }
                p.Scale = 1 + Math.Sin(t * Math.PI) * 0.35;
            });
            p.HopT = -1; p.Scale = 1;
            p.Pos = to;
            Land(p);
        }

        async Task MoveBack(Player p, int steps)
        {
            for (int i = 0; i < steps; i++)
            {
                int from = p.Pos, to = (from - 1 + Rules.BoardSize) % Rules.BoardSize;
                p.HopFrom = from; p.HopTo = to;
                await Tween(0.17, Ease.Linear, delegate (double t) { p.HopT = t; });
                p.HopT = -1; p.Pos = to;
                Land(p);
            }
        }

        async Task SendToJail(Player p)
        {
            p.Emit(2, 1.6);
            await JumpTo(p, Rules.CellJail, Pal.Bad);
            p.JailTurns = Rules.JailTurns;
            var pt = L.CellCenter(Rules.CellJail);
            fx.Burst(pt.X, pt.Y, 26, Color.FromArgb(56, 189, 248), 300, 6, 0);
            fx.Ring(pt.X, pt.Y, Color.FromArgb(56, 189, 248), L.CellSize, 0.7);
            fx.Kick(12);
            fx.Float("무인도 " + Rules.JailTurns + "턴!", pt.X, pt.Y - L.CellSize * 0.6, Pal.Bad, F.SubB, 34, 1.3);
            await Delay(0.55);
        }

        async Task Splash(Player p, Color c, string text)
        {
            var pt = L.TokenPoint(G, p);
            fx.Ring(pt.X, pt.Y, c, L.CellSize * 0.8, 0.55);
            fx.Burst(pt.X, pt.Y, 16, c, 240, 5, 2);
            fx.Float(text, pt.X, pt.Y - L.CellSize * 0.45, c, F.SubB, 30, 1.0);
            await Delay(0.35);
        }

        // ==================== 돈 ====================

        async Task Gain(Player p, int amount, string reason)
        {
            if (amount <= 0) return;
            p.Cash += amount;
            p.Emit(1, 0.9);
            var pt = L.TokenPoint(G, p);
            fx.Float(Fmt.Signed(amount), pt.X, pt.Y - L.CellSize * 0.42, Pal.Good, F.SubB, 34, 1.0);
            fx.CoinFountain(pt.X, pt.Y, 9, Pal.Gold);
            G.AddLog(p.Name + "  " + reason + "  " + Fmt.Signed(amount), Pal.Good);
            await Delay(0.32);
        }

        /// <summary>돈을 잃음. 부족하면 매각 -> 파산. false 면 파산.</summary>
        async Task<bool> Lose(Player p, int amount, string reason, Player to)
        {
            if (amount <= 0) return true;
            if (!await EnsureCash(p, amount, to))
            {
                await DoBankrupt(p, to, reason);
                return false;
            }
            p.Cash -= amount;
            p.Emit(2, 0.9);
            var pt = L.TokenPoint(G, p);
            fx.Float("-" + Fmt.M(amount), pt.X, pt.Y - L.CellSize * 0.42, Pal.Bad, F.SubB, 34, 1.0);
            fx.Kick(5);
            G.AddLog(p.Name + "  " + reason + "  -" + Fmt.M(amount), Pal.Bad);

            if (to != null)
            {
                to.Cash += amount;
                to.Emit(1, 0.9);
                var dst = L.PlayerCardRect(to.Id, G.Players.Count);
                var dp = new PointF(dst.X + dst.Width * 0.5f, dst.Y + dst.Height * 0.5f);
                int n = Math.Min(9, 3 + amount / 8);
                for (int i = 0; i < n; i++)
                {
                    fx.FlyCoin(pt.X, pt.Y, dp.X, dp.Y, Pal.Gold, 0.5, i * 0.055,
                        delegate { fx.Sparkle(dp.X, dp.Y, 4, Pal.Gold, 10); });
                }
                fx.Float("+" + Fmt.M(amount), dp.X, dp.Y - 18, Pal.Good, F.SubB, 26, 1.1);
            }
            else
            {
                G.Fund += amount;
            }
            await Delay(0.45);
            return true;
        }

        /// <summary>매각은 건물과 토지를 한 번에 처분한다 (총 투자액의 50% 회수)</summary>
        List<SellOption> SellOptions(Player p)
        {
            var l = new List<SellOption>();
            foreach (var c in G.Cells)
            {
                if (c.Owner != p.Id) continue;
                l.Add(new SellOption
                {
                    Cell = c, IsLand = true,
                    Amount = (int)(G.InvestedValue(c) * Rules.SellRate),
                    TollLoss = G.Toll(c),
                    Label = c.Level > 0
                        ? c.Name + " 매각 (" + Board.LevelNames[c.Level] + " 포함)"
                        : c.Name + " 토지 매각"
                });
            }
            return l;
        }

        async Task<bool> EnsureCash(Player p, int need, Player creditor)
        {
            while (p.Cash < need)
            {
                var opts = SellOptions(p);
                if (opts.Count == 0) return false;

                int choice;
                if (p.IsAI)
                {
                    choice = Ai.ChooseSellOption(G, p, opts);
                    await Delay(0.25);
                }
                else
                {
                    var specs = new List<ButtonSpec>();
                    int show = Math.Min(5, opts.Count);
                    // 회수액 큰 순으로 정렬해 상위 항목 제시
                    opts.Sort(delegate (SellOption a, SellOption b) { return b.Amount.CompareTo(a.Amount); });
                    for (int i = 0; i < show; i++)
                        specs.Add(new ButtonSpec(opts[i].Label, "+" + Fmt.M(opts[i].Amount) + " 회수",
                            i == 0 ? Pal.Gold : Pal.PanelHi, i == 0));
                    choice = await AskList("현금이 부족합니다",
                        "필요 " + Fmt.Won(need) + "  ·  보유 " + Fmt.Won(p.Cash) + "\n매각할 자산을 선택하세요.",
                        Pal.Bad, specs.ToArray());
                }

                var o = opts[choice];
                await ApplySell(p, o);
            }
            return true;
        }

        async Task ApplySell(Player p, SellOption o)
        {
            p.Cash += o.Amount;
            var c = o.Cell;
            var r = L.CellRect(c.Index);
            var cp = new PointF(r.X + r.Width / 2, r.Y + r.Height / 2);
            int levels = c.Level;

            c.Owner = -1;
            c.Level = 0;
            c.BuildPop = 0;
            c.OwnWave = 0;
            c.Shake = 1;

            G.AddLog(p.Name + "  " + c.Name + (levels > 0 ? " 건물·토지 매각" : " 토지 매각")
                + "  +" + Fmt.M(o.Amount), Pal.Gold);

            // 건물이 있었으면 철거 먼지를 더 크게
            fx.Burst(cp.X, cp.Y, levels > 0 ? 24 : 14, Color.FromArgb(180, 180, 190), 220, 5, 1);
            fx.Dust(cp.X, r.Y + r.Height * 0.42f, Color.FromArgb(200, 200, 210));
            fx.Float("+" + Fmt.M(o.Amount), cp.X, cp.Y - 14, Pal.Gold, F.SubB, 28, 1.0);
            fx.Kick(levels > 0 ? 9 : 6);
            await Delay(0.5);
        }

        async Task DoBankrupt(Player p, Player creditor, string reason)
        {
            G.AddLog(p.Name + " 파산! (" + reason + ")", Pal.Bad);
            var pt = L.TokenPoint(G, p);
            fx.Burst(pt.X, pt.Y, 30, Pal.Bad, 260, 6, 1);
            fx.Kick(16);
            await Banner(p.Name + " 파산", creditor != null ? "자산이 " + creditor.Name + "에게 이전됩니다" : "자산이 회수됩니다", Pal.Bad, 1.3);
            G.Bankrupt(p, creditor);
            await Tween(0.6, Ease.OutQuad, delegate (double t) { p.Alpha = 1 - t; });
            p.Alpha = 0;
        }

        // ==================== 칸 처리 ====================

        async Task ResolveCell(Player p)
        {
            var c = G.Cells[p.Pos];
            c.Pulse = 1;
            TweenFF(0.6, Ease.OutQuad, delegate (double t) { c.Pulse = 1 - t; });

            switch (c.Type)
            {
                case CellType.Start:
                    await Gain(p, Rules.StartBonus, "출발 칸 정확히 도착!");
                    fx.CoinFountain(L.CellCenter(0).X, L.CellCenter(0).Y, 16, Pal.Gold);
                    await StartLandmarkPhase(p);
                    break;

                case CellType.City:
                case CellType.Spot:
                    await ResolveProperty(p, c);
                    break;

                case CellType.Chance:
                    await ResolveChance(p);
                    break;

                case CellType.FundPay:
                    {
                        int amt = Math.Min(Rules.FundPay, p.Cash);
                        await Banner("사회복지기금", Fmt.Won(Rules.FundPay) + " 납부", Pal.Accent, 0.9);
                        if (!await Lose(p, Rules.FundPay, "사회복지기금 납부", null)) return;
                        var fp = L.FundRect;
                        fx.Sparkle(fp.X + fp.Width / 2, fp.Y + fp.Height / 2, 10, Pal.Gold, 16);
                        break;
                    }

                case CellType.FundGet:
                    {
                        if (G.Fund <= 0)
                        {
                            G.AddLog("기금이 비어 있습니다.", Pal.Dim);
                            await Delay(0.4);
                        }
                        else
                        {
                            int amt = G.Fund; G.Fund = 0;
                            await Banner("기금 수령!", Fmt.Won(amt) + " 획득", Pal.Gold, 1.1);
                            fx.CoinRain(ClientSize.Width, ClientSize.Height, 46);
                            await Gain(p, amt, "사회복지기금 수령");
                        }
                        break;
                    }

                case CellType.Tax:
                    {
                        int tax = Math.Max(5, (int)(p.Cash * Rules.TaxRate));
                        await Banner("국세청", "재산세 " + Fmt.Won(tax), Pal.Bad, 1.0);
                        if (!await Lose(p, tax, "재산세 납부", null)) return;
                        break;
                    }

                case CellType.Jail:
                    G.AddLog(p.Name + " 무인도에 도착!", Pal.Bad);
                    await Banner("무인도!", Rules.JailTurns + "턴 동안 갇힙니다", Pal.Bad, 1.1);
                    p.JailTurns = Rules.JailTurns;
                    p.Emit(2, 1.4);
                    await Splash(p, Color.FromArgb(56, 189, 248), "갇힘!");
                    break;

                case CellType.Space:
                    {
                        p.PendingSpace = true;
                        var sp = L.CellCenter(Rules.CellSpace);
                        fx.Rocket(sp.X, sp.Y, Pal.White);
                        fx.Ring(sp.X, sp.Y, Pal.Accent, L.CellSize, 0.7);
                        fx.Kick(8);
                        G.AddLog(p.Name + " 우주여행! 다음 턴에 원하는 칸으로 이동합니다.", Pal.Accent);
                        await Banner("우주여행 🚀", "다음 턴에 원하는 칸으로!", Pal.Accent, 1.2);
                        break;
                    }
            }
        }

        async Task ResolveProperty(Player p, Cell c)
        {
            if (c.Owner < 0)
            {
                if (p.Cash < c.Price)
                {
                    G.AddLog(p.Name + " 현금 부족으로 " + c.Name + " 구매 불가", Pal.Dim);
                    await Delay(0.5);
                    return;
                }
                bool buy;
                if (p.IsAI)
                {
                    buy = Ai.WantBuy(G, p, c);
                    await PeekCard(c, p, buy ? "구매!" : "보류", buy ? Pal.Good : Pal.Dim);
                }
                else
                {
                    buy = await Ask(c.Name + " 매입", "이 도시를 구매하시겠습니까?", c, null, c.GroupColor,
                        new ButtonSpec("구매", Fmt.Won(c.Price), Pal.Good, true),
                        new ButtonSpec("보류", "구매하지 않음", Pal.PanelHi, false)) == 0;
                }
                if (buy) await BuyProperty(p, c);
                else { G.AddLog(p.Name + " " + c.Name + " 구매 보류", Pal.Dim); await Delay(0.2); }
                return;
            }

            if (c.Owner == p.Id)
            {
                if (G.CanBuildLandmark(c)) await LandmarkPhase(p, c);
                else if (G.CanBuildHotelTier(c)) await BuildPhase(p, c, Rules.HotelLevel);
                else
                {
                    G.AddLog(p.Name + " 내 도시 " + c.Name + " (" + Board.LevelNames[c.Level] + ")", Pal.Dim);
                    await Delay(0.35);
                }
                return;
            }

            // 남의 도시 -> 통행료
            var owner = G.Players[c.Owner];
            int toll = G.Toll(c);
            bool mono = G.IsMonopolyBoosted(c);
            await Banner("통행료 지불", c.Name + "  " + Fmt.Won(toll) + (mono ? "  (독점 2배!)" : ""), owner.Color, 1.0);
            c.Shake = 1;
            if (!await Lose(p, toll, c.Name + " 통행료", owner)) return;

            // 인수 제안 (랜드마크가 세워진 도시는 인수 불가 — 소유자만 매각 가능)
            if (!c.HasLandmark)
            {
                int price = G.TakeoverPrice(c);
                if (p.Cash >= price)
                {
                    bool want;
                    if (p.IsAI) want = Ai.WantTakeover(G, p, c);
                    else want = await Ask(c.Name + " 인수", "이 도시를 " + owner.Name + "에게서 인수할 수 있습니다.\n인수가 = 투자액 x " + Rules.TakeoverMul,
                        c, null, Pal.Gold,
                        new ButtonSpec("인수한다", Fmt.Won(price), Pal.Gold, true),
                        new ButtonSpec("그만둔다", "", Pal.PanelHi, false)) == 0;
                    if (want)
                    {
                        if (!await Lose(p, price, c.Name + " 인수", owner)) return;
                        c.Owner = p.Id;
                        c.OwnWave = 1;
                        var r = L.CellRect(c.Index);
                        fx.Ring(r.X + r.Width / 2, r.Y + r.Height / 2, p.Color, r.Width, 0.6);
                        fx.Burst(r.X + r.Width / 2, r.Y + r.Height / 2, 20, p.Color, 220, 5, 2);
                        G.AddLog(p.Name + " " + c.Name + " 인수 성공!", Pal.Gold);
                        await Banner("인수 성공!", c.Name, p.Color, 1.0);
                        if (G.CanBuildHotelTier(c)) await BuildPhase(p, c, Rules.HotelLevel);
                    }
                }
            }
            else
            {
                G.AddLog(c.Name + " 는 랜드마크가 세워져 인수할 수 없습니다.", Pal.Gold);
                await Delay(0.35);
            }
        }

        async Task BuyProperty(Player p, Cell c)
        {
            p.Cash -= c.Price;
            c.Owner = p.Id;
            c.OwnWave = 1;
            p.Emit(1, 1.0);
            var r = L.CellRect(c.Index);
            var cp = new PointF(r.X + r.Width / 2, r.Y + r.Height / 2);
            fx.Ring(cp.X, cp.Y, p.Color, r.Width * 0.9, 0.6);
            fx.Burst(cp.X, cp.Y, 22, p.Color, 240, 5, 2);
            fx.Float("-" + Fmt.M(c.Price), cp.X, cp.Y - r.Height * 0.4f, Pal.Bad, F.SubB, 30, 1.0);
            fx.Kick(6);
            G.AddLog(p.Name + " " + c.Name + " 매입! -" + Fmt.M(c.Price), p.Color);
            bool mono = G.HasMonopoly(p.Id, c.GroupId);
            await Delay(0.45);
            if (mono && c.GroupId != null)
            {
                await Banner("대륙 독점!", Board.Groups[c.GroupId].Name + " 통행료 2배", Pal.Gold, 1.2);
                foreach (var x in G.Cells)
                    if (x.GroupId == c.GroupId)
                    {
                        var rr = L.CellRect(x.Index);
                        fx.Sparkle(rr.X + rr.Width / 2, rr.Y + rr.Height / 2, 10, Pal.Gold, 18);
                        x.OwnWave = 1;
                    }
                fx.Kick(8);
                await Delay(0.3);
            }
            if (G.CanBuildHotelTier(c)) await BuildPhase(p, c, Rules.HotelLevel);
        }

        /// <summary>이번 방문에 maxLevel 까지 연속으로 건설 (호텔까지는 즉시 가능)</summary>
        async Task BuildPhase(Player p, Cell c, int maxLevel)
        {
            if (p.IsAI)
            {
                int n = Ai.WantBuildCount(G, p, c, maxLevel);
                for (int i = 0; i < n; i++)
                {
                    if (c.Level >= maxLevel) break;
                    await DoBuild(p, c);
                }
                return;
            }

            while (c.Level < maxLevel && G.CanBuild(c))
            {
                int cost = G.NextBuildCost(c);
                if (p.Cash < cost) return;
                string next = Board.LevelNames[c.Level + 1];
                bool last = c.Level + 1 >= maxLevel;
                string body = next + "을 건설하면 통행료가 " + Fmt.Won(c.Tolls[c.Level + 1]) + "으로 오릅니다.";
                if (last) body += "\n랜드마크는 이 칸에 다시 도착하거나 출발 칸에 도착했을 때 건설합니다.";
                int choice = await Ask(c.Name + " 건설", body, c, null, p.Color,
                    new ButtonSpec(next + " 건설", Fmt.Won(cost), Pal.Good, true),
                    new ButtonSpec("건설 종료", "", Pal.PanelHi, false));
                if (choice != 0) return;
                await DoBuild(p, c);
            }
        }

        /// <summary>
        /// 출발 칸에 정확히 도착 → 호텔이 선 내 도시 중 하나를 골라 랜드마크로 올린다.
        /// 그 도시에 다시 도착할 때까지 기다리지 않아도 되는 유일한 경로다.
        /// </summary>
        async Task StartLandmarkPhase(Player p)
        {
            var cand = new List<Cell>();
            foreach (var c in G.Cells)
                if (c.Owner == p.Id && c.Level == Rules.HotelLevel && p.Cash >= G.NextBuildCost(c))
                    cand.Add(c);
            if (cand.Count == 0) return;

            // 통행료가 가장 많이 오르는 곳부터
            cand.Sort(delegate (Cell x, Cell y)
            {
                return (y.Tolls[Rules.MaxLevel] - y.Tolls[Rules.HotelLevel])
                     - (x.Tolls[Rules.MaxLevel] - x.Tolls[Rules.HotelLevel]);
            });

            Cell pick = null;
            if (p.IsAI)
            {
                foreach (var c in cand)
                    if (Ai.WantLandmark(G, p, c)) { pick = c; break; }
                if (pick == null) { await Delay(0.25); return; }
                await Banner("출발 보너스", p.Name + "  ·  " + pick.Name + " 랜드마크", Pal.Gold, 1.1);
            }
            else
            {
                // 매각 화면과 같은 목록 방식 — 마우스 없이 숫자키로도 고를 수 있다
                int show = Math.Min(4, cand.Count);
                var specs = new List<ButtonSpec>();
                for (int i = 0; i < show; i++)
                    specs.Add(new ButtonSpec(
                        cand[i].Name + "  " + Board.LandmarkName(cand[i].Landmark),
                        "건설 " + Fmt.M(G.NextBuildCost(cand[i]))
                            + "  ·  통행료 " + Fmt.M(cand[i].Tolls[Rules.MaxLevel]),
                        i == 0 ? Pal.Gold : Pal.PanelHi, i == 0));
                specs.Add(new ButtonSpec("나중에", "", Pal.PanelHi, false));

                int choice = await AskList("출발 보너스 — 랜드마크",
                    "호텔이 세워진 내 도시 하나를 랜드마크로 올릴 수 있습니다."
                        + (cand.Count > show ? "\n(통행료가 가장 많이 오르는 " + show + "곳)" : ""),
                    Pal.Gold, specs.ToArray());
                if (choice >= show) return;
                pick = cand[choice];
            }

            await DoBuild(p, pick);
        }

        /// <summary>호텔 보유 도시에 다시 도착 → 랜드마크 건설</summary>
        async Task LandmarkPhase(Player p, Cell c)
        {
            int cost = G.NextBuildCost(c);
            if (p.Cash < cost)
            {
                G.AddLog(p.Name + " " + c.Name + " 랜드마크 건설 자금 부족 (" + Fmt.Won(cost) + ")", Pal.Dim);
                await Delay(0.5);
                return;
            }

            bool go;
            if (p.IsAI)
            {
                go = Ai.WantLandmark(G, p, c);
                if (go) await Banner("랜드마크 건설", p.Name + "  ·  " + c.Name, Pal.Gold, 1.0);
                else await Delay(0.3);
            }
            else
            {
                go = await Ask(c.Name + " 랜드마크",
                    Board.LandmarkName(c.Landmark) + "을 세우면 통행료가 "
                        + Fmt.Won(c.Tolls[Rules.MaxLevel]) + "이 됩니다.",
                    c, null, Pal.Gold,
                    new ButtonSpec("랜드마크 건설", Fmt.Won(cost), Pal.Gold, true),
                    new ButtonSpec("나중에", "", Pal.PanelHi, false)) == 0;
            }
            if (!go) return;
            await DoBuild(p, c);
        }

        async Task DoBuild(Player p, Cell c)
        {
            int cost = G.NextBuildCost(c);
            if (p.Cash < cost) return;
            p.Cash -= cost;
            c.Level++;
            c.BuildPop = 0.001;
            c.Shake = 1;
            var r = L.CellRect(c.Index);
            var cp = new PointF(r.X + r.Width / 2, r.Y + r.Height / 2);
            fx.Float("-" + Fmt.M(cost), cp.X, cp.Y - r.Height * 0.35f, Pal.Bad, F.Small, 24, 0.9);
            G.AddLog(p.Name + " " + c.Name + " " + Board.LevelNames[c.Level] + " 건설! -" + Fmt.M(cost), p.Color);
            bool landmark = c.Level >= Rules.MaxLevel;
            TweenFF(landmark ? 0.85 : 0.62, Ease.Linear, delegate (double t) { c.BuildPop = Math.Max(0.001, t); });
            await Delay(landmark ? 0.36 : 0.26);
            fx.Kick(landmark ? 18 : 9);
            fx.Dust(cp.X, r.Y + r.Height * 0.42f, Color.FromArgb(210, 220, 240));
            fx.Burst(cp.X, r.Y + r.Height * 0.4f, landmark ? 26 : 12,
                landmark ? Pal.Gold : Draw.Lighten(p.Color, 0.3), landmark ? 260 : 160, landmark ? 6 : 4, landmark ? 2 : 1);
            fx.Ring(cp.X, r.Y + r.Height * 0.42f, landmark ? Pal.Gold : p.Color, r.Width * (landmark ? 1.1 : 0.5), landmark ? 0.7 : 0.4);
            if (landmark)
            {
                c.OwnWave = 1;
                fx.Sparkle(cp.X, r.Y + r.Height * 0.35f, 16, Pal.Gold, r.Width * 0.5f);
                fx.CoinFountain(cp.X, cp.Y, 10, Pal.Gold);
                await Banner("랜드마크 완성!", c.Name + "  통행료 " + Fmt.Won(G.Toll(c)), Pal.Gold, 1.4);
            }
            await Delay(0.42);
            c.BuildPop = 0;
        }

        // ==================== 황금열쇠 ====================

        async Task ResolveChance(Player p)
        {
            var card = G.Draw();
            if (p.IsAI)
            {
                await ShowChance(card, p, 1.25);
            }
            else
            {
                await Ask("황금열쇠", null, null, card, Pal.Gold, new ButtonSpec("확인", "Space", Pal.Gold, true));
            }
            G.AddLog("황금열쇠: " + card.Text, Pal.Gold);
            await ApplyCard(p, card);
        }

        async Task ApplyCard(Player p, Card card)
        {
            switch (card.Kind)
            {
                case "goto":
                    {
                        // 순간이동이 아니라 진행 방향으로 이동한다.
                        // 도중에 출발 칸을 지나면 MoveSteps 가 급여를 지급한다.
                        int steps = (card.To - p.Pos + Rules.BoardSize) % Rules.BoardSize;
                        if (steps == 0) steps = Rules.BoardSize;
                        G.AddLog(p.Name + "  " + G.Cells[card.To].Name + "까지 " + steps + "칸 이동", Pal.Gold);
                        await MoveSteps(p, steps, true, Pal.Gold);
                        await ResolveCell(p);
                        break;
                    }
                case "jail":
                    await SendToJail(p);
                    break;
                case "gain":
                    await Gain(p, card.Amount, "황금열쇠");
                    break;
                case "lose":
                    await Lose(p, card.Amount, "황금열쇠", null);
                    break;
                case "birthday":
                    foreach (var q in G.Players)
                    {
                        if (q == p || !q.Alive) continue;
                        if (!await Lose(q, card.Amount, "생일 축하금", p)) continue;
                    }
                    break;
                case "donate":
                    foreach (var q in G.Players)
                    {
                        if (q == p || !q.Alive) continue;
                        if (!await Lose(p, card.Amount, "기부금", q)) return;
                    }
                    break;
                case "fundget":
                    if (G.Fund > 0)
                    {
                        int amt = G.Fund; G.Fund = 0;
                        fx.CoinRain(ClientSize.Width, ClientSize.Height, 40);
                        await Gain(p, amt, "기금 지원");
                    }
                    else { G.AddLog("기금이 비어 있습니다.", Pal.Dim); await Delay(0.3); }
                    break;
                case "escape":
                    p.EscapeCards++;
                    await Splash(p, Pal.Gold, "탈출권 +1");
                    break;
                case "back":
                    await MoveBack(p, card.Amount);
                    await ResolveCell(p);
                    break;
                case "repair":
                    {
                        int n = G.Owned(p.Id).Count;
                        if (n == 0) { G.AddLog("소유 도시가 없습니다.", Pal.Dim); await Delay(0.3); break; }
                        await Lose(p, n * card.Amount, "도시 " + n + "곳 유지비", null);
                        break;
                    }
                case "rent":
                    {
                        int n = G.CountBuildings(p.Id);
                        if (n == 0) { G.AddLog("소유 건물이 없습니다.", Pal.Dim); await Delay(0.3); break; }
                        await Gain(p, n * card.Amount, "건물 " + n + "채 수익");
                        break;
                    }
            }
        }

        // ==================== 우주여행 ====================

        async Task DoSpaceTravel(Player p)
        {
            int dest;
            if (p.IsAI)
            {
                prompt = p.Name + " 목적지 선택 중...";
                await Delay(0.7);
                dest = Ai.ChooseSpaceDestination(G, p);
            }
            else
            {
                await Banner("우주여행", "이동할 칸을 클릭하세요", Pal.Accent, 1.0);
                prompt = "이동할 칸을 클릭하세요";
                dest = await PickCell(delegate (Cell c) { return c.Index != p.Pos; });
            }
            prompt = "";
            var sp = L.CellCenter(p.Pos);
            fx.Rocket(sp.X, sp.Y, Pal.White);
            fx.Kick(10);

            // 순간이동이 아니라 진행 방향으로 한 칸씩 이동한다.
            // 도중에 출발 칸을 지나면 MoveSteps 가 급여를 지급한다.
            int steps = (dest - p.Pos + Rules.BoardSize) % Rules.BoardSize;
            if (steps == 0) steps = Rules.BoardSize;
            G.AddLog(p.Name + " 우주여행 -> " + G.Cells[dest].Name + " (" + steps + "칸 이동)", Pal.Accent);
            await MoveSteps(p, steps, true, Color.FromArgb(147, 197, 253));

            var dp = L.CellCenter(dest);
            fx.Burst(dp.X, dp.Y, 24, Color.FromArgb(147, 197, 253), 260, 5, 2);
            fx.Ring(dp.X, dp.Y, Color.FromArgb(147, 197, 253), L.CellSize * 0.9, 0.6);
            await ResolveCell(p);
        }

        Task<int> PickCell(Func<Cell, bool> filter)
        {
            picking = true;
            pickFilter = filter;
            pickTcs = new TaskCompletionSource<int>();
            return pickTcs.Task;
        }

        // ==================== 결과 ====================

        async Task ShowGameOver()
        {
            screen = Screen.Over;
            overT = 0;
            buttons = new List<UiButton>();
            fx.Confetti(ClientSize.Width, ClientSize.Height, 140);
            fx.CoinRain(ClientSize.Width, ClientSize.Height, 60);
            if (G.Winner != null)
            {
                G.AddLog("승자: " + G.Winner.Name + "!", Pal.Gold);
                G.Winner.Emit(1, 999);
            }
            await Delay(0.6);
            var again = new UiButton { Label = "다시 하기", Primary = true, Color = Color.FromArgb(34, 197, 94) };
            again.OnClick = delegate { RestartToSetup(); };
            var quit = new UiButton { Label = "종료", Color = Pal.PanelHi };
            quit.OnClick = delegate { Close(); };
            buttons.Add(again);
            buttons.Add(quit);
        }

        void RestartToSetup()
        {
            anims.Clear();
            fx.Clear();
            modal = null;
            picking = false;
            G = null;
            screen = Screen.Setup;
            introT = 0;
            BuildSetupUi();
        }

        // ==================== 모달 / 버튼 대기 ====================

        Task WaitButtons(params ButtonSpec[] specs)
        {
            var tcs = new TaskCompletionSource<int>();
            buttons = new List<UiButton>();
            for (int i = 0; i < specs.Length; i++)
            {
                int idx = i;
                var s = specs[i];
                var b = new UiButton
                {
                    Label = s.Label, Sub = s.Sub, Color = s.Color,
                    Enabled = s.Enabled, Primary = s.Primary
                };
                b.OnClick = delegate
                {
                    buttons = new List<UiButton>();
                    tcs.TrySetResult(idx);
                };
                buttons.Add(b);
            }
            return tcs.Task;
        }

        Task<int> Ask(string title, string body, Cell card, Card chance, Color accent, params ButtonSpec[] specs)
        {
            return AskCore(title, body, card, chance, accent, false, specs);
        }

        /// <summary>라벨이 긴 선택지용: 버튼을 세로로 배치</summary>
        Task<int> AskList(string title, string body, Color accent, params ButtonSpec[] specs)
        {
            return AskCore(title, body, null, null, accent, true, specs);
        }

        async Task<int> AskCore(string title, string body, Cell card, Card chance, Color accent,
                                bool vertical, ButtonSpec[] specs)
        {
            var m = new Modal
            {
                Title = title, Body = body, CardCell = card, Chance = chance,
                Accent = accent, Vertical = vertical, Tcs = new TaskCompletionSource<int>()
            };
            if (chance != null) m.Flip = 0;
            for (int i = 0; i < specs.Length; i++)
            {
                int idx = i;
                var s = specs[i];
                var b = new UiButton
                {
                    Label = s.Label, Sub = s.Sub, Color = s.Color,
                    Enabled = s.Enabled, Primary = s.Primary
                };
                b.OnClick = delegate { m.Tcs.TrySetResult(idx); };
                m.Buttons.Add(b);
            }
            modal = m;
            if (chance != null)
            {
                await Delay(0.15);
                await Tween(0.55, Ease.OutCubic, delegate (double t) { m.Flip = t; });
                fx.Sparkle(ClientSize.Width / 2, ClientSize.Height / 2, 14, Pal.Gold, 60);
            }
            int r = await m.Tcs.Task;
            await CloseModal(m);
            return r;
        }

        async Task CloseModal(Modal m)
        {
            m.Closing = true;
            await Tween(0.18, Ease.InQuad, delegate (double t) { m.T = 1 - t; });
            if (modal == m) modal = null;
        }

        /// <summary>AI 판단을 잠깐 보여주는 카드 팝업</summary>
        async Task PeekCard(Cell c, Player p, string decision, Color col)
        {
            var m = new Modal
            {
                Title = c.Name, Body = decision, CardCell = c, Accent = col, Who = p,
                Tcs = new TaskCompletionSource<int>()
            };
            modal = m;
            await Delay(0.85);
            await CloseModal(m);
        }

        async Task ShowChance(Card card, Player p, double dur)
        {
            var m = new Modal
            {
                Title = "황금열쇠", Chance = card, Accent = Pal.Gold, Flip = 0, Who = p,
                Tcs = new TaskCompletionSource<int>()
            };
            modal = m;
            await Delay(0.12);
            await Tween(0.5, Ease.OutCubic, delegate (double t) { m.Flip = t; });
            fx.Sparkle(ClientSize.Width / 2, ClientSize.Height / 2, 14, Pal.Gold, 60);
            await Delay(dur);
            await CloseModal(m);
        }

        Task Banner(string text, string sub, Color c, double dur)
        {
            bannerText = text; bannerSub = sub; bannerColor = c; bannerT = dur;
            return Delay(Math.Min(dur, 0.55));
        }
    }
}
