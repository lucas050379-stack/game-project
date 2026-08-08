class_name D
extends RefCounted

## 판 구성 · 심볼 · 해전 12단계 · 확률 상수.
## 수치를 건드리면 환수율이 크게 흔들린다. 반드시 sim.gd 로 다시 확인할 것.

# ==================== 판 구성 ====================

const REELS := 5
const ROWS := 3
const LINES := 9

## 9개 페이라인 — 각 릴에서 고를 행 번호
const LINE := [
	[1, 1, 1, 1, 1],
	[0, 0, 0, 0, 0],
	[2, 2, 2, 2, 2],
	[0, 1, 2, 1, 0],
	[2, 1, 0, 1, 2],
	[0, 0, 1, 2, 2],
	[2, 2, 1, 0, 0],
	[1, 0, 1, 2, 1],
	[1, 2, 1, 0, 1],
]

# ==================== 심볼 ====================

const WAKO := 0
const ARROW := 1
const SHIELD := 2
const DRUM := 3
const SWORD := 4
const FLAG := 5
const SHIP := 6
const TURTLE := 7
const WILD := 8
const SCAT := 9
const SYM_COUNT := 10

const SYM_NAME := [
	"왜구", "화살", "방패", "전고", "장검",
	"수자기", "판옥선", "거북선", "이순신", "천자총통",
]

## [3개, 4개, 5개] — 라인 배팅 배수
const PAY := [
	[2, 6, 20],
	[2, 8, 25],
	[3, 10, 30],
	[4, 14, 45],
	[6, 22, 80],
	[9, 34, 120],
	[14, 55, 200],
	[30, 120, 450],
	[60, 240, 888],
	[0, 0, 0],
]

## 심볼 주색 / 보조색
const SYM_C1 := [
	Color8(148, 158, 178), Color8(196, 164, 116), Color8(92, 178, 214),
	Color8(226, 118, 72), Color8(214, 226, 244), Color8(238, 84, 92),
	Color8(124, 206, 160), Color8(255, 196, 74), Color8(255, 236, 160),
	Color8(178, 140, 255),
]

## 총통 개수별 총배팅 배수 (라인과 무관하게 지급)
const SCATTER_PAY := [0, 0, 0, 1, 5, 25]

# ==================== 해전 ====================

const PHASES := 3
const PHASE_NAME := ["전반", "중반", "종반"]

const GRP_NAME := ["옥포해전", "한산도대첩", "명량대첩", "노량해전"]
const GRP_SUB := [
	"첫 승전의 북소리",
	"학익진, 바다를 가르다",
	"신에게는 아직 열두 척",
	"싸움이 급하니 내 죽음을",
]
const GRP_YEAR := [1592, 1592, 1597, 1598]
const GRP_COLOR := [
	Color8(96, 200, 255), Color8(74, 226, 160),
	Color8(255, 176, 56), Color8(255, 74, 92),
]

## 해전별 왜선 수를 전반·중반·종반으로 쪼갠 것 (합계 26 / 59 / 133 / 500)
const PHASE_SHIPS := [
	[8, 8, 10],
	[19, 20, 20],
	[44, 44, 45],
	[166, 167, 167],
]

## 12단계 각각까지 도달했을 때의 누적 배당 (총배팅 배수)
const CUMULATIVE := [1, 2, 3, 4, 5, 6, 9, 14, 23, 37, 60, 97]

## 다음 단계로 넘어갈 기본 확률 (11번의 판정). 해전이 바뀌는 길목(2·5·8)만 조금 낮다.
## 웬만하면 계속 이어지도록 높게 잡았다 — 평균 5~6단계를 올라간다.
const PROMOTE := [0.92, 0.90, 0.84, 0.88, 0.86, 0.78, 0.84, 0.80, 0.55, 0.60, 0.35]

const TIERS := 12


static func tier_group(tier: int) -> int:
	return tier / PHASES


static func tier_phase(tier: int) -> int:
	return tier % PHASES


static func tier_ships(tier: int) -> int:
	return PHASE_SHIPS[tier_group(tier)][tier_phase(tier)]


static func tier_total(tier: int) -> float:
	return float(CUMULATIVE[tier])


static func tier_name(tier: int) -> String:
	return GRP_NAME[tier_group(tier)]


static func tier_full(tier: int) -> String:
	return "%s %s" % [GRP_NAME[tier_group(tier)], PHASE_NAME[tier_phase(tier)]]


static func tier_color(tier: int) -> Color:
	return GRP_COLOR[tier_group(tier)]


## 이 단계를 넘으면 다른 해전으로 넘어가는가
static func is_group_edge(tier: int) -> bool:
	return tier >= 0 and tier < TIERS - 1 and tier_group(tier) != tier_group(tier + 1)


## 이 단계 시작 시점까지의 누적 처단 수
static func kills_before(tier: int) -> int:
	var k := 0
	for i in tier:
		k += tier_ships(i)
	return k

# ==================== 확률 / 경제 ====================

const START_COINS := 20000

## 라인당 배팅 단계 — 1-2-5 로 자릿수를 올려 간다. 총배팅은 여기에 x9.
## 위쪽은 크게 이겼을 때를 위한 것이라 소지금이 받쳐 줘야 열린다(BET_CAP_DIV 참고).
const BET_LEVELS := [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000,
	2000, 5000, 10000, 20000, 50000, 100000]
const DEFAULT_BET_IDX := 3

## 한 스핀 총배팅은 보유 코인의 1/BET_CAP_DIV 를 넘지 못한다.
## 한 방에 전 재산을 날리지 못하게 막는 안전장치 — 최소 10스핀은 돌아간다.
const BET_CAP_DIV := 10

## 스핀 한 번에 쌓이는 전의.
##
## 예전에는 배팅액만큼 쌓았는데, 그러면 배팅을 올릴수록 해전이 스핀 기준으로 빨리 와서
## 환수율 자체가 배팅에 따라 달라졌다(최대 배팅이 일방적으로 유리했다).
## 배팅과 무관하게 스핀 수로만 쌓는다.
const SPIRIT_PER_SPIN := 1.0
## 전의 게이지가 가득 차는 데 필요한 스핀 수 (= 해전 천장)
const SPIRIT_MAX := 110.0
## 게이지가 빈 상태의 해전 발동 확률 (게이지 아래에 그대로 표시된다)
const JACKPOT_BASE := 0.0085
## 게이지가 찰수록 더해지는 확률
const JACKPOT_GAIN := 0.060


## 전의 t(0..1) 에서의 해전 발동 확률. t >= 1 이면 확정
static func jackpot_chance(t: float) -> float:
	if t >= 1.0:
		return 1.0
	return JACKPOT_BASE + JACKPOT_GAIN * t * t


## 총통 개수와 전의에 따른 시작 단계 가중치 (12단계)
static func start_tier_weights(scatters: int, t: float) -> Array:
	var w: Array
	if scatters >= 5:
		w = [8.0, 12.0, 16.0, 18.0, 16.0, 13.0, 9.0, 5.0, 3.0, 0.0, 0.0, 0.0]
	elif scatters == 4:
		w = [30.0, 22.0, 18.0, 14.0, 9.0, 5.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	else:
		w = [70.0, 18.0, 8.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in w.size():
		w[i] *= 1.0 + t * i * 0.08
	return w


## 단계 from -> from+1 로 넘어갈 확률
static func promote_chance(from: int, scatters: int, t: float) -> float:
	if from < 0 or from >= PROMOTE.size():
		return 0.0
	var p: float = PROMOTE[from]
	p *= 1.0 + (scatters - 3) * 0.08
	p *= 1.0 + t * 0.08
	return clampf(p, 0.0, 0.96)

# ==================== 릴 스트립 ====================

const STRIP_LEN := 64
## 릴 하나에 심는 총통 개수
const SCAT_PER_STRIP := 2
## 총통끼리의 최소 간격 (창이 3칸이므로 3 이상이면 겹쳐 보이지 않는다)
const SCAT_GAP := 7

## 릴 띠 — 난수로 만들지 않고 확정된 배열을 그대로 쓴다.
##
## 처음에는 가중치 + 시드로 생성했는데, 언어마다 난수 발생기가 달라 띠가 달라지고
## 환수율이 통째로 바뀌었다(라인 26% -> 20%). 슬롯의 띠는 확률 그 자체이므로
## 아래 배열이 곧 사양이다. 손대면 sim.gd 로 환수율을 다시 확인할 것.
##
## 조건: 릴마다 총통(9)이 정확히 2개, 순환 간격 7 이상, 같은 심볼 3연속 없음.
const STRIP_DATA := [
	[3, 0, 3, 0, 4, 0, 3, 5, 3, 0, 3, 0, 0, 4, 4, 8, 0, 2, 5, 0, 0, 5, 4, 1, 6, 0, 9, 5, 4, 5, 8, 2, 2, 1, 1, 4, 3, 9, 1, 4, 0, 6, 0, 1, 5, 4, 3, 0, 5, 3, 0, 5, 2, 2, 1, 6, 5, 5, 0, 8, 8, 5, 1, 3],
	[2, 8, 2, 4, 0, 0, 7, 1, 5, 2, 2, 1, 3, 9, 0, 0, 3, 0, 7, 8, 6, 8, 5, 5, 3, 9, 4, 0, 0, 5, 3, 1, 8, 0, 4, 5, 0, 3, 4, 2, 2, 0, 2, 2, 3, 3, 8, 4, 3, 2, 3, 4, 3, 2, 0, 3, 0, 6, 1, 5, 1, 0, 6, 0],
	[4, 1, 7, 0, 2, 3, 3, 4, 3, 9, 2, 0, 4, 1, 1, 2, 0, 0, 3, 1, 3, 1, 3, 3, 2, 4, 0, 4, 7, 2, 2, 1, 2, 0, 5, 5, 4, 3, 7, 0, 0, 5, 6, 4, 1, 0, 1, 0, 3, 6, 6, 5, 3, 6, 5, 2, 3, 2, 3, 4, 2, 9, 5, 0],
	[3, 3, 1, 2, 3, 3, 9, 3, 0, 4, 2, 6, 1, 2, 2, 9, 0, 0, 2, 4, 4, 2, 1, 2, 1, 1, 6, 1, 4, 1, 0, 4, 5, 0, 2, 3, 4, 0, 1, 1, 3, 8, 4, 0, 0, 4, 0, 0, 2, 4, 4, 1, 2, 0, 0, 6, 0, 1, 4, 6, 5, 5, 4, 4],
	[9, 5, 1, 8, 5, 0, 0, 4, 4, 1, 2, 2, 1, 4, 0, 1, 3, 1, 0, 2, 3, 1, 2, 5, 6, 5, 9, 3, 0, 6, 1, 1, 3, 5, 0, 1, 0, 3, 5, 2, 0, 4, 1, 5, 2, 3, 0, 8, 6, 3, 0, 1, 3, 2, 3, 3, 2, 1, 0, 7, 3, 2, 3, 5],
]

static var strip: Array = []
## 릴별로 "3칸 창에 총통이 보이는" 정지 위치 목록
static var scat_stop: Array = []
## 릴별로 "총통이 전혀 보이지 않는" 정지 위치 목록
static var plain_stop: Array = []


static func init_strips() -> void:
	if not strip.is_empty():
		return
	strip = STRIP_DATA.duplicate(true)

	# 해전 확정 스핀에서 쓸 정지 위치 목록을 미리 갈라둔다
	scat_stop = []
	plain_stop = []
	for r in REELS:
		var hit := []
		var miss := []
		for o in STRIP_LEN:
			if _has_scatter_near(strip[r], o):
				hit.append(o)
			else:
				miss.append(o)
		scat_stop.append(hit)
		plain_stop.append(miss)
		assert(hit.size() == SCAT_PER_STRIP * ROWS,
			"릴 %d 의 총통 배치가 어긋났다 — 해전이 성립하지 않는다" % r)


## 정지 위치 at 에서 보이는 3칸 안에 총통이 있는가
static func _has_scatter_near(s: Array, at: int) -> bool:
	for k in ROWS:
		if s[(at + k) % s.size()] == SCAT:
			return true
	return false


## 가중치 배열에서 인덱스 하나를 뽑는다 (게임 진행용 — 전역 난수)
static func weighted(w: Array) -> int:
	var sum := 0.0
	for v in w:
		sum += v
	if sum <= 0.0:
		return 0
	var r := randf() * sum
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return w.size() - 1
