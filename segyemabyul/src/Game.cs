using System;
using System.Collections.Generic;
using System.Drawing;

namespace Segyemabyul
{
    class Player
    {
        public int Id;
        public string Name;
        public Color Color;
        public bool IsAI;
        public int Cash;
        public int Pos;
        public int JailTurns;
        public bool Alive = true;
        public int EscapeCards;
        public bool PendingSpace;   // 다음 턴에 우주여행 이동
        public int Laps;

        // ---- 애니메이션 상태 ----
        public int HopFrom, HopTo;
        public double HopT = -1;    // -1 이면 이동 중 아님
        public double Squash;       // 착지 스쿼시 0..1
        public double Bob;          // 대기 중 상하 진동 위상
        public double DisplayCash;  // 카운트업용 표시 금액
        public double Alpha = 1;    // 파산 페이드
        public double Scale = 1;
        public double Emote;        // 감정 표현 타이머
        public int EmoteKind;       // 0 없음 1 기쁨 2 슬픔 3 놀람

        /// <summary>말의 생김새. 0 = 사람(탐험가), 1~3 = AI 캐릭터. Game 생성 시 배정된다.</summary>
        public int Face;

        public Player(int id, string name, Color color, bool isAI)
        {
            Id = id; Name = name; Color = color; IsAI = isAI;
            Cash = Rules.StartCash;
            DisplayCash = Rules.StartCash;
            Bob = Rnd.Range(0, 6.28);
        }

        public void Emit(int kind, double dur)
        {
            EmoteKind = kind; Emote = dur;
        }
    }

    class LogLine
    {
        public string Text;
        public Color Color;
        public double Age;
        public LogLine(string t, Color c) { Text = t; Color = c; }
    }

    /// <summary>게임 상태와 순수 규칙 계산. 애니메이션/연출은 GameForm 이 담당.</summary>
    class Game
    {
        public Cell[] Cells;
        public List<Player> Players = new List<Player>();
        public int Fund;
        public double FundDisplay;
        public int TurnIdx;
        public int Round = 1;
        public List<Card> Deck;
        public int DeckPos;
        public List<LogLine> Log = new List<LogLine>();
        public bool Over;
        public Player Winner;

        public Game(List<Player> players)
        {
            Cells = Board.Create();
            Players = players;
            Deck = Board.CreateDeck();
            Rnd.Shuffle(Deck);
            PickDoubleTollCells();
            AssignFaces();
        }

        /// <summary>
        /// 사람은 항상 0번(탐험가) 얼굴, AI 는 1~3번을 순서대로 나눠 가진다.
        /// 슬롯 번호로 정하면 셋업에서 사람/AI 를 바꿨을 때 내 말이 AI 얼굴이 되어 버린다.
        /// </summary>
        void AssignFaces()
        {
            int ai = 0;
            foreach (var p in Players)
                p.Face = p.IsAI ? 1 + (ai++ % 3) : 0;
        }

        /// <summary>게임 시작 시 무작위 칸 2곳을 통행료 2배 지역으로 지정</summary>
        void PickDoubleTollCells()
        {
            var pool = new List<Cell>();
            foreach (var c in Cells) if (c.IsProperty) pool.Add(c);
            for (int i = 0; i < Rules.DoubleTollCells && pool.Count > 0; i++)
            {
                int k = Rnd.Int(pool.Count);
                pool[k].DoubleToll = true;
                pool.RemoveAt(k);
            }
        }

        public List<Cell> DoubleTollCells()
        {
            var l = new List<Cell>();
            foreach (var c in Cells) if (c.DoubleToll) l.Add(c);
            return l;
        }

        public Player Current { get { return Players[TurnIdx]; } }

        public void AddLog(string text) { AddLog(text, Pal.White); }
        public void AddLog(string text, Color c)
        {
            Log.Add(new LogLine(text, c));
            if (Log.Count > 200) Log.RemoveAt(0);
        }

        public Card Draw()
        {
            if (DeckPos >= Deck.Count) { Rnd.Shuffle(Deck); DeckPos = 0; }
            return Deck[DeckPos++];
        }

        public List<Cell> Owned(int playerId)
        {
            var l = new List<Cell>();
            foreach (var c in Cells) if (c.Owner == playerId) l.Add(c);
            return l;
        }

        public int CountBuildings(int playerId)
        {
            int n = 0;
            foreach (var c in Cells) if (c.Owner == playerId) n += c.Level;
            return n;
        }

        public bool HasMonopoly(int playerId, string groupId)
        {
            if (groupId == null) return false;
            foreach (var c in Cells)
                if (c.GroupId == groupId && c.Owner != playerId) return false;
            return true;
        }

        public int SpotsOwned(int playerId)
        {
            int n = 0;
            foreach (var c in Cells) if (c.Type == CellType.Spot && c.Owner == playerId) n++;
            return n;
        }

        /// <summary>해당 칸의 현재 통행료</summary>
        public int Toll(Cell c)
        {
            if (c.Owner < 0) return 0;
            int t;
            if (c.Type == CellType.Spot)
            {
                t = c.Tolls[0] * Math.Max(1, SpotsOwned(c.Owner));
            }
            else
            {
                t = c.Tolls[c.Level];
                if (HasMonopoly(c.Owner, c.GroupId)) t *= Rules.MonopolyMul;
            }
            if (c.DoubleToll) t *= Rules.DoubleTollMul;
            return t;
        }

        public bool IsMonopolyBoosted(Cell c)
        {
            return c.Type == CellType.City && c.Owner >= 0 && HasMonopoly(c.Owner, c.GroupId);
        }

        /// <summary>총 자산(현금 + 매각 가치)</summary>
        public int NetWorth(Player p)
        {
            int v = p.Cash;
            foreach (var c in Cells)
            {
                if (c.Owner != p.Id) continue;
                v += (int)(c.Price * Rules.SellRate);
                for (int i = 0; i < c.Level; i++) v += (int)(c.BuildCost[i] * Rules.SellRate);
            }
            return v;
        }

        /// <summary>도시 총 투자액(인수가 계산용)</summary>
        public int InvestedValue(Cell c)
        {
            int v = c.Price;
            for (int i = 0; i < c.Level; i++) v += c.BuildCost[i];
            return v;
        }

        public int TakeoverPrice(Cell c) { return InvestedValue(c) * Rules.TakeoverMul; }

        /// <summary>건물을 한 단계 더 올릴 수 있는가 (랜드마크 포함)</summary>
        public bool CanBuild(Cell c)
        {
            return c.Type == CellType.City && c.Level < Rules.MaxLevel;
        }

        /// <summary>이번 방문에 호텔까지 올릴 수 있는가</summary>
        public bool CanBuildHotelTier(Cell c)
        {
            return c.Type == CellType.City && c.Level < Rules.HotelLevel;
        }

        /// <summary>호텔을 이미 보유 → 다시 도착하면 랜드마크 건설 가능</summary>
        public bool CanBuildLandmark(Cell c)
        {
            return c.Type == CellType.City && c.Level == Rules.HotelLevel;
        }

        public int NextBuildCost(Cell c)
        {
            if (!CanBuild(c)) return 0;
            return c.BuildCost[c.Level];
        }

        public int SellValueOfLevel(Cell c)
        {
            if (c.Level <= 0) return 0;
            return (int)(c.BuildCost[c.Level - 1] * Rules.SellRate);
        }

        public int SellValueOfLand(Cell c)
        {
            return (int)(c.Price * Rules.SellRate);
        }

        public int AlivePlayers()
        {
            int n = 0;
            foreach (var p in Players) if (p.Alive) n++;
            return n;
        }

        public void NextTurn()
        {
            int guard = 0;
            do
            {
                TurnIdx = (TurnIdx + 1) % Players.Count;
                if (TurnIdx == 0) Round++;
                guard++;
            } while (!Players[TurnIdx].Alive && guard < 100);
        }

        /// <summary>파산 처리: 자산을 채권자(또는 은행)로 이전</summary>
        public void Bankrupt(Player p, Player creditor)
        {
            p.Alive = false;
            foreach (var c in Cells)
            {
                if (c.Owner != p.Id) continue;
                if (creditor != null)
                {
                    c.Owner = creditor.Id;
                    c.OwnWave = 1;
                }
                else
                {
                    c.Owner = -1;
                    c.Level = 0;
                }
            }
            if (creditor != null && p.Cash > 0)
            {
                creditor.Cash += p.Cash;
            }
            p.Cash = 0;
        }
    }
}
