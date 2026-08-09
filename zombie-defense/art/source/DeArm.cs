using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

// 몸통 PNG 에 인쇄된 양팔을 지운다.
//
// 셀 셰이딩 그림은 짙은 외곽선이 모든 면을 둘러싼다. 그 외곽선(+ 살/옷 색 경계 + 손으로
// 그은 경계선)을 벽으로 삼아 밝은 픽셀을 영역으로 나누면 팔 안쪽과 몸통 안쪽이 갈라진다.
// 영역마다 무게중심이 **경계 곡선의 바깥쪽**인지 보고 통째로 지운다 — 세로선으로 뭉텅
// 자르는 게 아니라 원래 외곽선을 따라 잘리므로 자른 자리에 원래 테두리가 그대로 남는다.
//
// 사용법:
//   DeArm <src> <dst> <dark> <왼쪽경계> <오른쪽경계> [살릴씨앗점]
//   경계     = "x,y;x,y;x,y" 폴리라인 (위->아래). 없으면 "-"
//   살릴씨앗점 = "x,y;x,y" — 바깥쪽이지만 몸통인 부분 구제용. 없으면 "-"
class DeArm
{
    static int W, H;
    static int[] px;
    static int[] reg;   // -1 배경, -2 벽(외곽선/손으로 그은 선), >=0 영역 번호

    static bool Opaque(int i) { return ((px[i] >> 24) & 0xFF) > 40; }

    static int Lum(int i)
    {
        int r = (px[i] >> 16) & 0xFF, g = (px[i] >> 8) & 0xFF, b = px[i] & 0xFF;
        return (r * 30 + g * 59 + b * 11) / 100;
    }

    static List<Point> ParseLine(string s)
    {
        if (s == null || s.Length == 0 || s == "-") return null;
        var list = new List<Point>();
        foreach (var t in s.Split(';'))
        { var q = t.Split(','); list.Add(new Point(int.Parse(q[0]), int.Parse(q[1]))); }
        return list;
    }

    // 폴리라인이 세로 y 에서 갖는 x. 위/아래로 벗어나면 양 끝 값을 그대로 쓴다.
    static double LineX(List<Point> line, double y)
    {
        if (line == null) return double.NaN;
        if (y <= line[0].Y) return line[0].X;
        for (int k = 0; k + 1 < line.Count; k++)
        {
            Point a = line[k], b = line[k + 1];
            if (y >= a.Y && y <= b.Y)
            {
                if (b.Y == a.Y) return b.X;
                return a.X + (b.X - a.X) * (y - a.Y) / (double)(b.Y - a.Y);
            }
        }
        return line[line.Count - 1].X;
    }

    static void Main(string[] a)
    {
        string src = a[0], dst = a[1];
        int dark = int.Parse(a[2]);
        var wallL = ParseLine(a[3]);
        var wallR = ParseLine(a[4]);
        var keepSeeds = ParseLine(a.Length > 5 ? a[5] : "-");

        Bitmap bm = new Bitmap(Image.FromFile(src));
        W = bm.Width; H = bm.Height;
        px = new int[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
                px[y * W + x] = bm.GetPixel(x, y).ToArgb();

        reg = new int[W * H];
        for (int i = 0; i < W * H; i++)
            reg[i] = !Opaque(i) ? -1 : (Lum(i) < dark ? -2 : 0);

        // 살(밝은 초록/청록/보라)과 옷(붉은 계열)의 경계도 벽으로 친다 — 좀비 조끼 옆구리처럼
        // 외곽선 없이 팔과 몸통이 맞닿는 자리가 있다.
        var cloth = new bool[W * H];
        for (int i = 0; i < W * H; i++)
        {
            int r = (px[i] >> 16) & 0xFF, g = (px[i] >> 8) & 0xFF;
            cloth[i] = r > g + 4;
        }

        // 손으로 그은 경계선을 벽으로 찍는다 (3px 두께라야 4방향 연결을 확실히 끊는다)
        foreach (var line in new[] { wallL, wallR })
        {
            if (line == null) continue;
            for (int k = 0; k + 1 < line.Count; k++)
            {
                Point p0 = line[k], p1 = line[k + 1];
                int steps = Math.Max(Math.Abs(p1.X - p0.X), Math.Abs(p1.Y - p0.Y)) * 4 + 1;
                for (int s = 0; s <= steps; s++)
                {
                    int wx = p0.X + (p1.X - p0.X) * s / steps;
                    int wy = p0.Y + (p1.Y - p0.Y) * s / steps;
                    for (int ox = -1; ox <= 1; ox++)
                        for (int oy = -1; oy <= 1; oy++)
                        {
                            int nx = wx + ox, ny = wy + oy;
                            if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                            if (reg[ny * W + nx] == 0) reg[ny * W + nx] = -2;
                        }
                }
            }
        }

        int nreg = 0;
        var sumx = new List<double>(); var sumy = new List<double>(); var cnt = new List<int>();
        var stack = new Stack<int>();
        int[] dx = { 1, -1, 0, 0 }, dy = { 0, 0, 1, -1 };
        for (int s = 0; s < W * H; s++)
        {
            if (reg[s] != 0) continue;
            int id = ++nreg; sumx.Add(0); sumy.Add(0); cnt.Add(0);
            reg[s] = id; stack.Push(s);
            while (stack.Count > 0)
            {
                int p = stack.Pop();
                sumx[id - 1] += p % W; sumy[id - 1] += p / W; cnt[id - 1]++;
                for (int k = 0; k < 4; k++)
                {
                    int nx = p % W + dx[k], ny = p / W + dy[k];
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    int q = ny * W + nx;
                    if (reg[q] != 0 || cloth[q] != cloth[p]) continue;
                    reg[q] = id; stack.Push(q);
                }
            }
        }

        // 영역 판정 — 무게중심이 경계 곡선 바깥이면 팔로 보고 지운다
        var kill = new bool[nreg + 1];
        int biggest = 1;
        for (int i = 1; i <= nreg; i++) if (cnt[i - 1] > cnt[biggest - 1]) biggest = i;
        for (int i = 1; i <= nreg; i++)
        {
            double cx = sumx[i - 1] / cnt[i - 1], cy = sumy[i - 1] / cnt[i - 1];
            double lx = LineX(wallL, cy), rx = LineX(wallR, cy);
            bool outside = (!double.IsNaN(lx) && cx < lx) || (!double.IsNaN(rx) && cx > rx);
            kill[i] = outside && i != biggest;
        }
        if (keepSeeds != null)
            foreach (var p in keepSeeds)
            { int id = reg[p.Y * W + p.X]; if (id > 0) kill[id] = false; }

        var del = new bool[W * H];
        for (int i = 0; i < W * H; i++)
            if (reg[i] > 0 && kill[reg[i]]) del[i] = true;

        // 벽(외곽선) 픽셀은 살아남은 영역에 닿아 있을 때만 남긴다 —
        // 몸통 테두리는 유지되고 팔 테두리만 같이 사라진다.
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (reg[i] != -2) continue;
                bool touchKept = false;
                for (int ox = -2; ox <= 2 && !touchKept; ox++)
                    for (int oy = -2; oy <= 2 && !touchKept; oy++)
                    {
                        int nx = x + ox, ny = y + oy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        int q = ny * W + nx;
                        if (reg[q] > 0 && !kill[reg[q]]) touchKept = true;
                    }
                if (!touchKept) del[i] = true;
            }

        // 팔을 지우고 나면 팔 외곽선 조각이 몸통과 떨어진 채 둥둥 남는다. 전부 턴다.
        {
            var reach = new bool[W * H];
            for (int s = 0; s < W * H; s++)
            {
                if (reg[s] != biggest || del[s] || reach[s]) continue;
                reach[s] = true; stack.Push(s);
                while (stack.Count > 0)
                {
                    int p = stack.Pop();
                    for (int ox = -1; ox <= 1; ox++)
                        for (int oy = -1; oy <= 1; oy++)
                        {
                            int nx = p % W + ox, ny = p / W + oy;
                            if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                            int q = ny * W + nx;
                            if (reach[q] || del[q] || !Opaque(q)) continue;
                            reach[q] = true; stack.Push(q);
                        }
                }
            }
            for (int i = 0; i < W * H; i++) if (Opaque(i) && !reach[i]) del[i] = true;
        }

        // 잘린 자리는 외곽선이 없어 살이 그대로 드러난다. 원래 그림의 외곽선 색을 뽑아
        // 새로 생긴 가장자리에 2px 두께로 둘러 준다 — 안 그러면 셀 셰이딩 화풍이 깨진다.
        long orr = 0, ogg = 0, obb = 0; int ocnt = 0;
        for (int i = 0; i < W * H; i++)
            if (Opaque(i) && Lum(i) < dark)
            { orr += (px[i] >> 16) & 0xFF; ogg += (px[i] >> 8) & 0xFF; obb += px[i] & 0xFF; ocnt++; }
        Color outline = ocnt > 0
            ? Color.FromArgb(255, (int)(orr / ocnt), (int)(ogg / ocnt), (int)(obb / ocnt))
            : Color.FromArgb(255, 24, 26, 40);

        var stroke = new bool[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (!Opaque(i) || del[i]) continue;
                bool nearCut = false;
                for (int ox = -2; ox <= 2 && !nearCut; ox++)
                    for (int oy = -2; oy <= 2 && !nearCut; oy++)
                    {
                        if (ox * ox + oy * oy > 5) continue;
                        int nx = x + ox, ny = y + oy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        if (del[ny * W + nx]) nearCut = true;
                    }
                if (nearCut) stroke[i] = true;
            }

        int gone = 0;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (del[i]) { bm.SetPixel(x, y, Color.FromArgb(0, 0, 0, 0)); gone++; }
                else if (stroke[i]) bm.SetPixel(x, y, outline);
            }

        // 팔을 지우면 그 자리가 빈 여백으로 남는다. 그대로 두면 Spr.blit 이 **캔버스** 기준으로
        // 가운데를 잡고 높이로 크기를 맞추므로, 몸이 화면에서 한쪽으로 밀리고 실제보다 작게
        // 그려진다(좀비 10px, 폭탄 15px 씩 오른쪽으로 밀려 있었다). 내용 경계로 잘라 낸다.
        int bx0 = W, by0 = H, bx1 = -1, by1 = -1;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
                if (bm.GetPixel(x, y).A > 40)
                {
                    if (x < bx0) bx0 = x;
                    if (x > bx1) bx1 = x;
                    if (y < by0) by0 = y;
                    if (y > by1) by1 = y;
                }
        Bitmap outbm = bm;
        if (bx1 >= bx0 && by1 >= by0 && (bx0 > 0 || by0 > 0 || bx1 < W - 1 || by1 < H - 1))
            outbm = bm.Clone(new Rectangle(bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1), bm.PixelFormat);

        outbm.Save(dst, ImageFormat.Png);
        Console.WriteLine("{0,-20} {1}x{2} -> {3}x{4}  regions={5} removed={6}px",
            System.IO.Path.GetFileName(src), W, H, outbm.Width, outbm.Height, nreg, gone);
    }
}
