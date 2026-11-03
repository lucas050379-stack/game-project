class_name WrD
extends RefCounted

## 월드 러너 — 규칙 상수 · 보드 32칸 · 대륙 · 랜드마크 · 황금열쇠 카드 · 팔레트.
##
## 세계마뷸(C# WinForms, `segyemabyul/`)을 GDScript 로 다시 쓴 것이다. 규칙과 수치는 원본과
## 같다 — 한쪽을 고치면 다른 쪽도 같이 고칠지 정하세요(원본은 따로 남겨 둔 독립 게임입니다).
## 금액 단위는 **만원**이다.

# ==================== 규칙 ====================

const START_CASH := 200     ## 시작 자금
const SALARY := 20          ## 출발 통과 급여
const START_BONUS := 40     ## 출발 칸 정확히 도착
const FUND_PAY := 15        ## 사회복지기금 납부
const TAX_RATE := 0.10      ## 국세청 세율(현금 기준)
const JAIL_TURNS := 3       ## 무인도 대기 턴
const MONOPOLY_MUL := 2     ## 대륙 독점 통행료 배수
const TAKEOVER_MUL := 2     ## 도시 인수 배수
const SELL_RATE := 0.5      ## 매각 환급률
const MAX_ROUND := 40       ## 이 라운드가 지나면 총자산으로 승부

## 9 × 9 격자의 테두리 = 32칸 (한 변에 모서리 빼고 7칸)
const GRID := 9
const BOARD_SIZE := 32
const CELL_JAIL := 8
const CELL_SPACE := 16
const CELL_FUND_GET := 24

const MAX_LEVEL := 4        ## 0토지 1별장 2빌딩 3호텔 4랜드마크
const HOTEL_LEVEL := 3
const DOUBLE_TOLL_CELLS := 2   ## 게임 시작 때 무작위로 통행료 2배가 되는 칸 수
const DOUBLE_TOLL_MUL := 2

enum T { START, CITY, SPOT, CHANCE, FUND_PAY, FUND_GET, JAIL, SPACE, TAX }

const LEVEL_NAMES := ["토지", "별장", "빌딩", "호텔", "랜드마크"]

# ==================== 팔레트 ====================

const BG0 := Color8(16, 20, 38)
const BG1 := Color8(30, 38, 70)
const BOARD_BG := Color8(22, 28, 52)
const PANEL := Color8(34, 42, 74)
const PANEL_HI := Color8(46, 56, 96)
const CELL_BG := Color8(242, 244, 250)
const CELL_BG2 := Color8(222, 227, 240)
const INK := Color8(28, 32, 48)
const INK_SOFT := Color8(96, 104, 128)
const WHITE := Color8(248, 250, 255)
const DIM := Color8(150, 160, 190)
const GOLD := Color8(255, 202, 64)
const GOLD_DEEP := Color8(214, 152, 20)
const GOOD := Color8(74, 222, 128)
const BAD := Color8(248, 113, 113)
const ACCENT := Color8(96, 165, 250)
const SEA := Color8(56, 189, 248)
const RED := Color8(239, 68, 68)
const SPOT_COL := Color8(45, 212, 191)

const PLAYER_COLORS := [Color8(239, 68, 68), Color8(59, 130, 246), Color8(34, 197, 94), Color8(234, 179, 8)]
const PLAYER_NAMES := ["빨강", "파랑", "초록", "노랑"]

# ==================== 대륙 ====================

## 한 변마다 2도시 그룹 + 3도시 그룹 = 8그룹 20도시
const GROUPS := {
	"g1": ["동아시아", Color8(244, 63, 94)],
	"g2": ["아시아 중동", Color8(249, 115, 22)],
	"g3": ["남유럽", Color8(234, 179, 8)],
	"g4": ["북유럽", Color8(132, 204, 22)],
	"g5": ["중부유럽", Color8(22, 163, 74)],
	"g6": ["유럽 대도시", Color8(2, 132, 199)],
	"g7": ["영미권", Color8(79, 70, 229)],
	"g8": ["아시아 프리미엄", Color8(192, 38, 211)],
}

# ==================== 랜드마크 ====================

## 도시마다 다른 랜드마크 도안. **새 도시를 넣으면 세 곳**을 같이 고칩니다 —
## 여기 한 줄, `LANDMARK_NAMES` 한 줄, `WrIcons.landmark` 의 match 한 갈래.
## 빠뜨리면 조용히 기본 첨탑으로 그려집니다.
const LANDMARKS := {
	"타이페이": "tower101", "마닐라": "cathedral", "하와이": "volcano", "싱가포르": "merlion",
	"카이로": "pyramid", "이스탄불": "mosque", "아테네": "parthenon", "로마": "colosseum",
	"마드리드": "archgate", "코펜하겐": "mermaid", "제주도": "dolharubang", "스톡홀름": "cityhall",
	"베른": "clocktower", "프라하": "astroclock", "몰디브": "watervilla", "베를린": "brandenburg",
	"모스크바": "oniondome", "파리": "eiffel", "런던": "bigben", "시드니": "opera",
	"뉴욕": "liberty", "도쿄": "tokyotower", "서울": "namsan",
}

const LANDMARK_NAMES := {
	"tower101": "타이베이 101", "cathedral": "마닐라 대성당", "volcano": "다이아몬드 헤드",
	"merlion": "머라이언", "pyramid": "피라미드", "mosque": "블루 모스크",
	"parthenon": "파르테논 신전", "colosseum": "콜로세움", "archgate": "알칼라 문",
	"mermaid": "인어공주 동상", "dolharubang": "돌하르방", "cityhall": "스톡홀름 시청사",
	"clocktower": "시계탑", "astroclock": "천문시계탑", "watervilla": "수상 방갈로",
	"brandenburg": "브란덴부르크 문", "oniondome": "성 바실리 성당", "eiffel": "에펠탑",
	"bigben": "빅벤", "opera": "오페라 하우스", "liberty": "자유의 여신상",
	"tokyotower": "도쿄 타워", "namsan": "남산 서울타워",
}


static func landmark_name(kind: String) -> String:
	return LANDMARK_NAMES.get(kind, "랜드마크")

# ==================== 칸 ====================

## 보드 한 칸 — 정의 + 게임 중 상태(소유자 · 건물)를 같이 들고 있다.
class Cell:
	var index := 0
	var type := T.START
	var name := ""
	var country := ""
	var price := 0
	var group := ""
	var tolls := [0, 0, 0, 0, 0]       ## 토지/별장/빌딩/호텔/랜드마크
	var build_cost := [0, 0, 0, 0]     ## 별장/빌딩/호텔/랜드마크
	var flag := []                     ## [종류, 색, 색, ...]
	var landmark := ""                 ## "" = 기본 첨탑
	# 게임 중 상태
	var owner := -1
	var level := 0
	var double_toll := false
	# 그림 상태
	var pulse := 0.0
	var build_pop := 0.0
	var shake := 0.0
	var own_wave := 0.0

	func is_property() -> bool:
		return type == T.CITY or type == T.SPOT

	func is_corner() -> bool:
		return index % (GRID - 1) == 0

	func has_landmark() -> bool:
		return level >= MAX_LEVEL

	func group_color() -> Color:
		if type == T.SPOT:
			return SPOT_COL
		if group == "":
			return DIM
		return GROUPS[group][1]


static func _r(x: float) -> int:
	return maxi(1, int(roundf(x)))


static func _city(name: String, country: String, price: int, group: String, flag: Array) -> Cell:
	var c := Cell.new()
	c.type = T.CITY
	c.name = name
	c.country = country
	c.price = price
	c.group = group
	c.flag = flag
	c.tolls = [_r(price * 0.12), _r(price * 0.35), _r(price * 0.90), _r(price * 1.70), _r(price * 2.90)]
	c.build_cost = [_r(price * 0.50), _r(price * 0.80), _r(price * 1.20), _r(price * 2.00)]
	return c


static func _spot(name: String, price: int, flag: Array) -> Cell:
	var c := Cell.new()
	c.type = T.SPOT
	c.name = name
	c.country = "관광지"
	c.price = price
	c.flag = flag
	c.tolls = [8, 8, 8, 8, 8]   # 통행료 = 8 × 보유 관광지 수 (최대 3곳)
	return c


static func _special(t: int, name: String) -> Cell:
	var c := Cell.new()
	c.type = t
	c.name = name
	return c


static func _c(r: int, g: int, b: int) -> Color:
	return Color8(r, g, b)


## 새 게임용 보드 (32칸, 0 = 출발, 반시계 방향으로 돈다).
##
## 한 변은 두 패턴을 번갈아 쓴다.
##   A형: 도시 특수 도시 특수 도시 도시 도시   (앞 2도시 한 색 / 뒤 3도시 한 색)
##   B형: 도시 도시 도시 특수 도시 특수 도시   (앞 3도시 한 색 / 뒤 2도시 한 색)
## 변의 첫 칸 · 마지막 칸은 항상 도시, 특수칸끼리 · 특수칸과 모서리는 절대 붙지 않고,
## 색이 바뀌는 경계에는 반드시 특수칸이나 모서리가 들어간다.
static func create_board() -> Array:
	var W := Color.WHITE
	var list: Array = [
		# ---------- 아래 0~8 : A형 ----------
		_special(T.START, "출발"),
		_city("타이페이", "대만", 5, "g1", ["canton", _c(255, 0, 0), _c(0, 0, 150), W]),
		_special(T.CHANCE, "황금열쇠"),
		_city("마닐라", "필리핀", 6, "g1", ["trihoist", _c(0, 56, 168), _c(206, 17, 38), W]),
		_spot("하와이", 15, ["beach", _c(56, 189, 248), _c(250, 204, 21)]),
		_city("싱가포르", "싱가포르", 8, "g2", ["hstripes", _c(237, 41, 57), W]),
		_city("카이로", "이집트", 9, "g2", ["hstripes", _c(206, 17, 38), W, _c(20, 20, 20)]),
		_city("이스탄불", "터키", 10, "g2", ["disc", _c(227, 10, 23), W]),
		_special(T.JAIL, "무인도"),
		# ---------- 왼쪽 9~16 : B형 ----------
		_city("아테네", "그리스", 12, "g3", ["hstripes", _c(13, 94, 175), W]),
		_city("로마", "이탈리아", 13, "g3", ["vstripes", _c(0, 140, 69), W, _c(205, 33, 42)]),
		_city("마드리드", "스페인", 14, "g3", ["hstripes", _c(198, 11, 30), _c(255, 196, 0), _c(198, 11, 30)]),
		_special(T.FUND_PAY, "사회복지기금"),
		_city("코펜하겐", "덴마크", 15, "g4", ["nordic", _c(198, 12, 48), W]),
		_spot("제주도", 15, ["palm", _c(34, 197, 94), _c(250, 204, 21)]),
		_city("스톡홀름", "스웨덴", 16, "g4", ["nordic", _c(0, 82, 147), _c(254, 205, 54)]),
		_special(T.SPACE, "우주여행"),
		# ---------- 위 17~24 : A형 ----------
		_city("베른", "스위스", 17, "g5", ["cross", _c(213, 43, 30), W]),
		_special(T.CHANCE, "황금열쇠"),
		_city("프라하", "체코", 19, "g5", ["trihoist", W, _c(215, 20, 26), _c(17, 69, 134)]),
		_spot("몰디브", 15, ["beach", _c(14, 165, 233), _c(254, 240, 138)]),
		_city("베를린", "독일", 20, "g6", ["hstripes", _c(20, 20, 20), _c(221, 0, 0), _c(255, 206, 0)]),
		_city("모스크바", "러시아", 22, "g6", ["hstripes", W, _c(0, 57, 166), _c(213, 43, 30)]),
		_city("파리", "프랑스", 24, "g6", ["vstripes", _c(0, 85, 164), W, _c(239, 65, 53)]),
		_special(T.FUND_GET, "기금 수령"),
		# ---------- 오른쪽 25~31 : B형 ----------
		_city("런던", "영국", 26, "g7", ["union", _c(1, 33, 105), W, _c(200, 16, 46)]),
		_city("시드니", "호주", 27, "g7", ["stars", _c(0, 32, 91), W]),
		_city("뉴욕", "미국", 30, "g7", ["canton", _c(178, 34, 52), _c(60, 59, 110), W]),
		_special(T.TAX, "국세청"),
		_city("도쿄", "일본", 33, "g8", ["disc", W, _c(188, 0, 45)]),
		_special(T.CHANCE, "황금열쇠"),
		_city("서울", "대한민국", 38, "g8", ["taegeuk", W, _c(205, 46, 58), _c(0, 71, 160)]),
	]
	for i in list.size():
		var c: Cell = list[i]
		c.index = i
		if c.is_property() and LANDMARKS.has(c.name):
			c.landmark = LANDMARKS[c.name]
	return list

# ==================== 황금열쇠 ====================

## [종류, 금액 또는 목적지, 글]
static func create_deck() -> Array:
	return [
		["goto", 0, "출발 칸까지 전진합니다! 도착 보너스를 받습니다."],
		["jail", 0, "밀입국 혐의! 무인도로 추방됩니다."],
		["goto", CELL_SPACE, "우주여행 티켓 당첨! 우주여행 칸으로 이동합니다."],
		["gain", 20, "복권에 당첨되어 20만원을 받습니다."],
		["lose", 10, "병원 치료비로 10만원을 냅니다."],
		["gain", 15, "주식 배당금 15만원을 받습니다."],
		["lose", 8, "자동차 수리비로 8만원을 냅니다."],
		["birthday", 5, "생일입니다! 다른 플레이어에게 5만원씩 받습니다."],
		["donate", 5, "기부 행사! 다른 플레이어에게 5만원씩 지급합니다."],
		["fundget", 0, "사회복지기금 전액을 지원받습니다."],
		["escape", 0, "무인도 탈출권을 얻었습니다. 보관했다가 씁니다."],
		["back", 3, "길을 잃어 3칸 뒤로 물러납니다."],
		["goto", 31, "해외 출장! 서울로 이동합니다."],
		["goto", 29, "항공권 특가! 도쿄로 이동합니다."],
		["repair", 4, "소유한 도시마다 4만원의 유지비를 냅니다."],
		["rent", 3, "소유한 건물마다 3만원의 수익을 얻습니다."],
		["goto", CELL_FUND_GET, "복지 캠페인! 기금 수령 칸으로 이동합니다."],
		["gain", 30, "부동산 매각 차익 30만원을 받습니다."],
	]

# ==================== 격자 ====================

## 칸 번호 → 격자 테두리 좌표 (row, col). 0 = 오른쪽 아래, 반시계로 돈다.
static func grid_pos(i: int) -> Vector2i:
	var n := GRID - 1
	if i == 0:
		return Vector2i(n, n)
	if i < n:
		return Vector2i(n, n - i)
	if i == n:
		return Vector2i(n, 0)
	if i < n * 2:
		return Vector2i(n - (i - n), 0)
	if i == n * 2:
		return Vector2i(0, 0)
	if i < n * 3:
		return Vector2i(0, i - n * 2)
	if i == n * 3:
		return Vector2i(0, n)
	return Vector2i(i - n * 3, n)

# ==================== 글 ====================


static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


static func m(n: int) -> String:
	return num(n) + "만"


static func won(n: int) -> String:
	return num(n) + "만원"


static func signed(n: int) -> String:
	return ("+" if n >= 0 else "-") + num(absi(n)) + "만"
