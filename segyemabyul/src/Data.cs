using System;
using System.Collections.Generic;
using System.Drawing;

namespace Segyemabyul
{
    static class Rules
    {
        public const int StartCash = 200;   // 시작 자금 (만원)
        public const int Salary = 20;       // 출발 통과 급여
        public const int StartBonus = 40;   // 출발 칸 정확히 도착
        public const int FundPay = 15;      // 사회복지기금 납부
        public const double TaxRate = 0.10; // 국세청 세율(현금 기준)
        public const int JailTurns = 3;     // 무인도 대기 턴
        public const int MonopolyMul = 2;   // 대륙 독점 통행료 배수
        public const int TakeoverMul = 2;   // 도시 인수 배수
        public const double SellRate = 0.5; // 매각 환급률

        // 9 x 9 격자의 테두리 = 32칸 (한 변에 코너 제외 7칸)
        public const int Grid = 9;
        public const int BoardSize = 32;
        public const int CellJail = 8;
        public const int CellSpace = 16;
        public const int CellFundGet = 24;

        public const int MaxLevel = 4;      // 0토지 1별장 2빌딩 3호텔 4랜드마크
        public const int HotelLevel = 3;
        public const int DoubleTollCells = 2;   // 게임 시작 시 무작위로 통행료 2배가 되는 칸 수
        public const int DoubleTollMul = 2;
    }

    enum CellType { Start, City, Spot, Chance, FundPay, FundGet, Jail, Space, Tax }

    /// <summary>도시마다 다른 랜드마크 도안. 랜드마크(5단계)를 세우면 이 모양으로 그려진다.</summary>
    enum LandmarkKind
    {
        Generic,
        Tower101,     // 타이페이 101
        Cathedral,    // 마닐라 대성당
        Volcano,      // 하와이 다이아몬드 헤드
        Merlion,      // 싱가포르 머라이언
        Pyramid,      // 카이로 피라미드
        Mosque,       // 이스탄불 모스크
        Parthenon,    // 아테네 파르테논
        Colosseum,    // 로마 콜로세움
        ArchGate,     // 마드리드 알칼라 문
        Mermaid,      // 코펜하겐 인어공주
        Dolharubang,  // 제주도 돌하르방
        CityHall,     // 스톡홀름 시청사
        ClockTower,   // 베른 시계탑
        AstroClock,   // 프라하 천문시계
        WaterVilla,   // 몰디브 수상 방갈로
        Brandenburg,  // 베를린 브란덴부르크 문
        OnionDome,    // 모스크바 성 바실리 성당
        Eiffel,       // 파리 에펠탑
        BigBen,       // 런던 빅벤
        Opera,        // 시드니 오페라하우스
        Liberty,      // 뉴욕 자유의 여신상
        TokyoTower,   // 도쿄 타워
        NamsanTower,  // 서울 남산타워
    }

    enum FlagKind
    {
        None, HStripes, VStripes, Disc, Cross, NordicCross, TriHoist,
        Canton, Stars, Taegeuk, UnionJack, HoistBar, Beach, Palm
    }

    class Flag
    {
        public FlagKind Kind;
        public Color[] C;
        public Flag(FlagKind k, params Color[] c) { Kind = k; C = c; }
    }

    class Group
    {
        public string Name;
        public Color Color;
        public Group(string n, Color c) { Name = n; Color = c; }
    }

    /// <summary>보드 한 칸. 정적 정의 + 게임 중 상태(소유자/건물)를 함께 보관.</summary>
    class Cell
    {
        public int Index;
        public CellType Type;
        public string Name;
        public string Country;
        public int Price;
        public string GroupId;
        public int[] Tolls = new int[5];       // 토지/별장/빌딩/호텔/랜드마크
        public int[] BuildCost = new int[4];   // 별장/빌딩/호텔/랜드마크
        public Flag Flag;
        public LandmarkKind Landmark = LandmarkKind.Generic;

        // 런타임 상태
        public int Owner = -1;
        public int Level;                     // 0=토지 … 4=랜드마크
        public bool DoubleToll;               // 게임 시작 시 무작위 지정되는 통행료 2배 지역
        public double Pulse;                  // 강조 애니메이션 0..1
        public double BuildPop;               // 건설 애니메이션 0..1
        public double Shake;                  // 흔들림
        public double OwnWave;                // 소유권 획득 웨이브 0..1

        public bool IsProperty { get { return Type == CellType.City || Type == CellType.Spot; } }
        public bool IsCorner { get { return Index % (Rules.Grid - 1) == 0; } }
        public bool HasLandmark { get { return Level >= Rules.MaxLevel; } }
        public Color GroupColor
        {
            get
            {
                if (Type == CellType.Spot) return Color.FromArgb(45, 212, 191);
                if (GroupId == null) return Pal.Dim;
                return Board.Groups[GroupId].Color;
            }
        }
    }

    class Card
    {
        public string Kind;
        public int Amount;
        public int To;
        public string Text;
        public Card(string kind, string text) { Kind = kind; Text = text; }
        public Card(string kind, int amount, string text) { Kind = kind; Amount = amount; Text = text; }
        public static Card Goto(int to, string text) { var c = new Card("goto", text); c.To = to; return c; }
    }

    static class Board
    {
        // 각 변마다 2도시 그룹 + 3도시 그룹 = 8그룹 20도시
        public static readonly Dictionary<string, Group> Groups = new Dictionary<string, Group>
        {
            { "g1", new Group("동아시아",         Color.FromArgb(244, 63,  94)) },  // 2
            { "g2", new Group("아시아·중동",      Color.FromArgb(249, 115, 22)) },  // 3
            { "g3", new Group("남유럽",           Color.FromArgb(234, 179, 8 )) },  // 3
            { "g4", new Group("북유럽",           Color.FromArgb(132, 204, 22)) },  // 2
            { "g5", new Group("중부유럽",         Color.FromArgb(22,  163, 74 )) }, // 2
            { "g6", new Group("유럽 대도시",      Color.FromArgb(2,   132, 199)) }, // 3
            { "g7", new Group("영미권",           Color.FromArgb(79,  70,  229)) }, // 3
            { "g8", new Group("아시아 프리미엄",  Color.FromArgb(192, 38,  211)) }, // 2
        };

        public static readonly string[] LevelNames = { "토지", "별장", "빌딩", "호텔", "랜드마크" };

        static Color RGB(int r, int g, int b) { return Color.FromArgb(r, g, b); }

        static Cell City(string name, string country, int price, string group, Flag flag)
        {
            var c = new Cell();
            c.Type = CellType.City;
            c.Name = name; c.Country = country; c.Price = price; c.GroupId = group; c.Flag = flag;
            c.Tolls = new[] { R(price * 0.12), R(price * 0.35), R(price * 0.90), R(price * 1.70), R(price * 2.90) };
            c.BuildCost = new[] { R(price * 0.50), R(price * 0.80), R(price * 1.20), R(price * 2.00) };
            return c;
        }

        static Cell Spot(string name, string country, int price, Flag flag)
        {
            var c = new Cell();
            c.Type = CellType.Spot;
            c.Name = name; c.Country = country; c.Price = price; c.Flag = flag;
            c.Tolls = new[] { 8, 8, 8, 8, 8 };   // 통행료 = 8 x 보유 관광지 수 (최대 3곳)
            return c;
        }

        static Cell Special(CellType t, string name, string sub)
        {
            var c = new Cell();
            c.Type = t; c.Name = name; c.Country = sub;
            return c;
        }

        static int R(double x) { return Math.Max(1, (int)Math.Round(x)); }

        /// <summary>새 게임용 보드 생성 (32칸, 0=출발, 반시계 진행)
        /// 한 변은 아래 두 패턴을 번갈아 사용한다.
        ///   A형: 도시 특수 도시 특수 도시 도시 도시   (앞 2도시 한 색 / 뒤 3도시 한 색)
        ///   B형: 도시 도시 도시 특수 도시 특수 도시   (앞 3도시 한 색 / 뒤 2도시 한 색)
        ///  - 변의 첫 칸·마지막 칸은 항상 도시
        ///  - 특수칸끼리, 특수칸과 모서리끼리 절대 붙지 않음 (모든 특수칸은 도시 사이)
        ///  - 색이 바뀌는 경계에는 반드시 특수칸 또는 모서리가 들어감</summary>
        public static Cell[] Create()
        {
            var list = new List<Cell>
            {
                // ---------- 하단 0~8 : A형 ----------
                Special(CellType.Start,   "출발",         "START"),
                City("타이페이", "대만",     5,  "g1", new Flag(FlagKind.Canton,      RGB(255,0,0),    RGB(0,0,150),   Color.White)),
                Special(CellType.Chance,  "황금열쇠",     "CHANCE"),
                City("마닐라",   "필리핀",   6,  "g1", new Flag(FlagKind.TriHoist,    RGB(0,56,168),   RGB(206,17,38), Color.White)),
                Spot("하와이",   "관광지",   15,     new Flag(FlagKind.Beach,       RGB(56,189,248), RGB(250,204,21))),
                City("싱가포르", "싱가포르", 8,  "g2", new Flag(FlagKind.HStripes,    RGB(237,41,57),  Color.White)),
                City("카이로",   "이집트",   9,  "g2", new Flag(FlagKind.HStripes,    RGB(206,17,38),  Color.White, RGB(20,20,20))),
                City("이스탄불", "터키",     10, "g2", new Flag(FlagKind.Disc,        RGB(227,10,23),  Color.White)),
                Special(CellType.Jail,    "무인도",       "JAIL"),

                // ---------- 좌측 9~16 : B형 ----------
                City("아테네",   "그리스",   12, "g3", new Flag(FlagKind.HStripes,    RGB(13,94,175),  Color.White)),
                City("로마",     "이탈리아", 13, "g3", new Flag(FlagKind.VStripes,    RGB(0,140,69),   Color.White, RGB(205,33,42))),
                City("마드리드", "스페인",   14, "g3", new Flag(FlagKind.HStripes,    RGB(198,11,30),  RGB(255,196,0), RGB(198,11,30))),
                Special(CellType.FundPay, "사회복지기금", "FUND"),
                City("코펜하겐", "덴마크",   15, "g4", new Flag(FlagKind.NordicCross, RGB(198,12,48),  Color.White)),
                Spot("제주도",   "관광지",   15,     new Flag(FlagKind.Palm,        RGB(34,197,94),  RGB(250,204,21))),
                City("스톡홀름", "스웨덴",   16, "g4", new Flag(FlagKind.NordicCross, RGB(0,82,147),   RGB(254,205,54))),
                Special(CellType.Space,   "우주여행",     "SPACE"),

                // ---------- 상단 17~24 : A형 ----------
                City("베른",     "스위스",   17, "g5", new Flag(FlagKind.Cross,       RGB(213,43,30),  Color.White)),
                Special(CellType.Chance,  "황금열쇠",     "CHANCE"),
                City("프라하",   "체코",     19, "g5", new Flag(FlagKind.TriHoist,    Color.White,     RGB(215,20,26), RGB(17,69,134))),
                Spot("몰디브",   "관광지",   15,     new Flag(FlagKind.Beach,       RGB(14,165,233), RGB(254,240,138))),
                City("베를린",   "독일",     20, "g6", new Flag(FlagKind.HStripes,    RGB(20,20,20),   RGB(221,0,0), RGB(255,206,0))),
                City("모스크바", "러시아",   22, "g6", new Flag(FlagKind.HStripes,    Color.White,     RGB(0,57,166), RGB(213,43,30))),
                City("파리",     "프랑스",   24, "g6", new Flag(FlagKind.VStripes,    RGB(0,85,164),   Color.White, RGB(239,65,53))),
                Special(CellType.FundGet, "기금 수령",    "BONUS"),

                // ---------- 우측 25~31 : B형 ----------
                City("런던",     "영국",     26, "g7", new Flag(FlagKind.UnionJack,   RGB(1,33,105),   Color.White, RGB(200,16,46))),
                City("시드니",   "호주",     27, "g7", new Flag(FlagKind.Stars,       RGB(0,32,91),    Color.White)),
                City("뉴욕",     "미국",     30, "g7", new Flag(FlagKind.Canton,      RGB(178,34,52),  RGB(60,59,110), Color.White)),
                Special(CellType.Tax,     "국세청",       "TAX"),
                City("도쿄",     "일본",     33, "g8", new Flag(FlagKind.Disc,        Color.White,     RGB(188,0,45))),
                Special(CellType.Chance,  "황금열쇠",     "CHANCE"),
                City("서울",     "대한민국", 38, "g8", new Flag(FlagKind.Taegeuk,     Color.White,     RGB(205,46,58), RGB(0,71,160))),
            };
            for (int i = 0; i < list.Count; i++)
            {
                list[i].Index = i;
                if (list[i].IsProperty && Landmarks.ContainsKey(list[i].Name))
                    list[i].Landmark = Landmarks[list[i].Name];
            }
            return list.ToArray();
        }

        /// <summary>도시별 랜드마크 도안. 여기 없는 도시는 기본 첨탑으로 그려진다.</summary>
        public static readonly Dictionary<string, LandmarkKind> Landmarks =
            new Dictionary<string, LandmarkKind>
        {
            { "타이페이", LandmarkKind.Tower101    },
            { "마닐라",   LandmarkKind.Cathedral   },
            { "하와이",   LandmarkKind.Volcano     },
            { "싱가포르", LandmarkKind.Merlion     },
            { "카이로",   LandmarkKind.Pyramid     },
            { "이스탄불", LandmarkKind.Mosque      },
            { "아테네",   LandmarkKind.Parthenon   },
            { "로마",     LandmarkKind.Colosseum   },
            { "마드리드", LandmarkKind.ArchGate    },
            { "코펜하겐", LandmarkKind.Mermaid     },
            { "제주도",   LandmarkKind.Dolharubang },
            { "스톡홀름", LandmarkKind.CityHall    },
            { "베른",     LandmarkKind.ClockTower  },
            { "프라하",   LandmarkKind.AstroClock  },
            { "몰디브",   LandmarkKind.WaterVilla  },
            { "베를린",   LandmarkKind.Brandenburg },
            { "모스크바", LandmarkKind.OnionDome   },
            { "파리",     LandmarkKind.Eiffel      },
            { "런던",     LandmarkKind.BigBen      },
            { "시드니",   LandmarkKind.Opera       },
            { "뉴욕",     LandmarkKind.Liberty     },
            { "도쿄",     LandmarkKind.TokyoTower  },
            { "서울",     LandmarkKind.NamsanTower },
        };

        /// <summary>랜드마크 이름 (모달·툴팁 표시용)</summary>
        public static string LandmarkName(LandmarkKind k)
        {
            switch (k)
            {
                case LandmarkKind.Tower101: return "타이베이 101";
                case LandmarkKind.Cathedral: return "마닐라 대성당";
                case LandmarkKind.Volcano: return "다이아몬드 헤드";
                case LandmarkKind.Merlion: return "머라이언";
                case LandmarkKind.Pyramid: return "피라미드";
                case LandmarkKind.Mosque: return "블루 모스크";
                case LandmarkKind.Parthenon: return "파르테논 신전";
                case LandmarkKind.Colosseum: return "콜로세움";
                case LandmarkKind.ArchGate: return "알칼라 문";
                case LandmarkKind.Mermaid: return "인어공주 동상";
                case LandmarkKind.Dolharubang: return "돌하르방";
                case LandmarkKind.CityHall: return "스톡홀름 시청사";
                case LandmarkKind.ClockTower: return "시계탑";
                case LandmarkKind.AstroClock: return "천문시계탑";
                case LandmarkKind.WaterVilla: return "수상 방갈로";
                case LandmarkKind.Brandenburg: return "브란덴부르크 문";
                case LandmarkKind.OnionDome: return "성 바실리 성당";
                case LandmarkKind.Eiffel: return "에펠탑";
                case LandmarkKind.BigBen: return "빅벤";
                case LandmarkKind.Opera: return "오페라 하우스";
                case LandmarkKind.Liberty: return "자유의 여신상";
                case LandmarkKind.TokyoTower: return "도쿄 타워";
                case LandmarkKind.NamsanTower: return "남산 서울타워";
                default: return "랜드마크";
            }
        }

        public static List<Card> CreateDeck()
        {
            var d = new List<Card>
            {
                Card.Goto(0,  "출발 칸까지 전진합니다! 도착 보너스를 받습니다."),
                new Card("jail",     "밀입국 혐의! 무인도로 추방됩니다."),
                Card.Goto(Rules.CellSpace, "우주여행 티켓 당첨! 우주여행 칸으로 이동합니다."),
                new Card("gain",  20, "복권에 당첨되어 20만원을 받습니다."),
                new Card("lose",  10, "병원 치료비로 10만원을 냅니다."),
                new Card("gain",  15, "주식 배당금 15만원을 받습니다."),
                new Card("lose",   8, "자동차 수리비로 8만원을 냅니다."),
                new Card("birthday", 5, "생일입니다! 다른 플레이어에게 5만원씩 받습니다."),
                new Card("donate",   5, "기부 행사! 다른 플레이어에게 5만원씩 지급합니다."),
                new Card("fundget",  "사회복지기금 전액을 지원받습니다."),
                new Card("escape",   "무인도 탈출권을 획득했습니다. 보관 후 사용합니다."),
                new Card("back",  3, "길을 잃어 3칸 뒤로 물러납니다."),
                Card.Goto(31, "해외 출장! 서울로 이동합니다."),
                Card.Goto(29, "항공권 특가! 도쿄로 이동합니다."),   // 29 = 도쿄
                new Card("repair", 4, "소유한 도시마다 4만원의 유지비를 냅니다."),
                new Card("rent",   3, "소유한 건물마다 3만원의 수익을 얻습니다."),
                Card.Goto(Rules.CellFundGet, "복지 캠페인! 기금 수령 칸으로 이동합니다."),
                new Card("gain",  30, "부동산 매각 차익 30만원을 받습니다."),
            };
            return d;
        }

        /// <summary>격자 테두리 좌표 (0-base row/col)</summary>
        public static void GridPos(int i, out int row, out int col)
        {
            const int N = Rules.Grid - 1;
            if (i == 0) { row = N; col = N; }
            else if (i < N) { row = N; col = N - i; }
            else if (i == N) { row = N; col = 0; }
            else if (i < N * 2) { row = N - (i - N); col = 0; }
            else if (i == N * 2) { row = 0; col = 0; }
            else if (i < N * 3) { row = 0; col = i - N * 2; }
            else if (i == N * 3) { row = 0; col = N; }
            else { row = i - N * 3; col = N; }
        }
    }

    static class Fmt
    {
        public static string M(int n) { return n.ToString("N0") + "만"; }
        public static string Won(int n) { return n.ToString("N0") + "만원"; }
        public static string Signed(int n)
        {
            return (n >= 0 ? "+" : "-") + Math.Abs(n).ToString("N0") + "만";
        }
    }
}
