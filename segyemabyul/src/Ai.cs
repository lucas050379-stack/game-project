using System;
using System.Collections.Generic;

namespace Segyemabyul
{
    /// <summary>AI 판단 로직 (휴리스틱)</summary>
    static class Ai
    {
        const int Reserve = 35;   // 남겨두려는 최소 현금

        public static bool WantBuy(Game g, Player p, Cell c)
        {
            if (p.Cash < c.Price) return false;
            int after = p.Cash - c.Price;

            // 같은 대륙을 이미 가지고 있으면 적극적으로
            int sameGroup = 0, groupTotal = 0;
            if (c.GroupId != null)
            {
                foreach (var x in g.Cells)
                {
                    if (x.GroupId != c.GroupId) continue;
                    groupTotal++;
                    if (x.Owner == p.Id) sameGroup++;
                }
            }
            int need = Reserve;
            if (sameGroup > 0) need = 18;
            if (groupTotal > 0 && sameGroup == groupTotal - 1) need = 0;   // 독점 완성
            if (c.Type == CellType.Spot && g.SpotsOwned(p.Id) > 0) need = 10;

            // 후반에는 더 공격적으로
            if (g.Round > 6) need = Math.Max(0, need - 12);
            return after >= need;
        }

        /// <summary>도착한 도시에 몇 단계까지 올릴지 (maxLevel 이하)</summary>
        public static int WantBuildCount(Game g, Player p, Cell c, int maxLevel)
        {
            int levels = 0;
            int cash = p.Cash;
            int lvl = c.Level;
            bool mono = g.HasMonopoly(p.Id, c.GroupId);
            int keep = mono ? 30 : 55;
            if (g.Round > 7) keep -= 15;

            while (lvl < maxLevel && lvl < c.BuildCost.Length)
            {
                int cost = c.BuildCost[lvl];
                if (cash - cost < keep) break;
                // 호텔은 여유 자금이 충분할 때만
                if (lvl == 2 && cash - cost < (mono ? 45 : 85)) break;
                // 저가 도시에 호텔까지 올리는 건 비효율
                if (lvl == 2 && c.Price < 14 && !mono) break;
                cash -= cost; lvl++; levels++;
            }
            return levels;
        }

        /// <summary>호텔 보유 도시에 다시 도착했을 때 랜드마크를 세울지</summary>
        public static bool WantLandmark(Game g, Player p, Cell c)
        {
            int cost = c.BuildCost[Rules.HotelLevel];
            if (p.Cash < cost) return false;
            int keep = g.HasMonopoly(p.Id, c.GroupId) ? 45 : 75;
            if (g.Round > 10) keep -= 25;
            return p.Cash - cost >= keep;
        }

        public static bool WantTakeover(Game g, Player p, Cell c)
        {
            int price = g.TakeoverPrice(c);
            if (p.Cash < price) return false;
            if (p.Cash - price < 60) return false;
            bool valuable = c.Price >= 18 || g.IsMonopolyBoosted(c) || c.Level >= 2;
            return valuable;
        }

        public static int ChooseSpaceDestination(Game g, Player p)
        {
            int best = 0;
            double bestScore = double.NegativeInfinity;
            for (int i = 0; i < g.Cells.Length; i++)
            {
                var c = g.Cells[i];
                if (i == p.Pos) continue;          // 제자리는 선택 불가
                double s;
                switch (c.Type)
                {
                    case CellType.City:
                    case CellType.Spot:
                        if (c.Owner < 0)
                            s = p.Cash >= c.Price ? c.Price * 1.4 : -5;
                        else if (c.Owner == p.Id)
                            s = g.CanBuild(c) && p.Cash >= g.NextBuildCost(c) ? c.Price * 0.6 : 2;
                        else
                            s = -g.Toll(c) * 1.5;
                        break;
                    case CellType.Jail: s = -500; break;
                    case CellType.Tax: s = -p.Cash * Rules.TaxRate; break;
                    case CellType.FundPay: s = -Rules.FundPay; break;
                    case CellType.FundGet: s = g.Fund; break;
                    case CellType.Start: s = Rules.StartBonus; break;
                    case CellType.Chance: s = 6; break;
                    default: s = 0; break;
                }
                // 진행 방향으로 이동하므로 출발 칸을 지나가면 급여를 받는다
                int steps = (i - p.Pos + Rules.BoardSize) % Rules.BoardSize;
                if (i != 0 && p.Pos + steps >= Rules.BoardSize) s += Rules.Salary;
                if (s > bestScore) { bestScore = s; best = i; }
            }
            return best;
        }

        /// <summary>현금 확보용 매각 선택 (건물+토지가 한 번에 넘어가므로 통행료 손실을 크게 본다)</summary>
        public static int ChooseSellOption(Game g, Player p, List<SellOption> opts)
        {
            int best = 0;
            double bestScore = double.NegativeInfinity;
            for (int i = 0; i < opts.Count; i++)
            {
                var o = opts[i];
                // 회수액은 크고, 잃는 통행료는 작은 쪽을 선호
                double score = o.Amount * 1.0 - o.TollLoss * 3.5;
                if (o.Cell.HasLandmark) score -= 60;          // 랜드마크는 최후에
                if (o.Cell.DoubleToll) score -= 25;           // 2배 지역도 최후에
                if (g.HasMonopoly(p.Id, o.Cell.GroupId)) score -= 30;  // 독점 깨지 않기
                if (score > bestScore) { bestScore = score; best = i; }
            }
            return best;
        }

        public static bool WantUseEscapeCard(Game g, Player p)
        {
            return true;
        }
    }

    class SellOption
    {
        public Cell Cell;
        public bool IsLand;     // true = 도시 자체 매각
        public int Amount;      // 회수 금액
        public int TollLoss;    // 잃게 되는 통행료
        public string Label;
    }
}
