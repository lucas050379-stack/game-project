class_name D
extends RefCounted

## 규칙 수치는 **전부 이 파일**에 있다. 유닛 명단과 조합법만 [U] 에 따로 있다(자동 생성).
##
## ## 이 게임이 굴러가는 방식
##
## 맵에는 **처음도 끝도 없다.** 몬스터는 고리 모양 길을 끝없이 돌고, 안 죽으면 계속 쌓인다.
## **살아 있는 몬스터가 [constant LOSE_COUNT] 마리가 되면 진다.** 코어도 목숨도 없다 —
## 밀리고 있다는 사실이 화면에 깔린 몬스터 수로 그대로 보인다.
##
## 유닛은 타워가 아니라 **움직이는 유닛**이다. 드래그로 여러 기를 골라 옮길 수 있고,
## 그래서 "어디에 놓을까"가 한 번의 결정이 아니라 계속 이어지는 결정이 된다.
##
## ## 경제
##
## 위습을 시작에 [constant WISP_START] 개, 라운드마다 [constant WISP_PER_ROUND] 개 받는다.
## 위습 하나로 **유닛을 뽑거나 나무 도박을 하거나** 둘 중 하나만 할 수 있다.
## 목재는 다시 **랜덤 도박**에 쓰여 랜덤전용·특수함 유닛이 나온다.
##
## 조합은 3중첩이 아니라 **지정 조합법**이다 — 서로 다른 유닛 2~4종을 정해진 대로 모아야 한다.

# ══ 화면 상태 ══════════════════════════════════════════════════
enum St { TITLE, PLAY, OVER, WIN }

# ══ 난이도 ════════════════════════════════════════════════════
## **쉬움은 규칙을 바꾸지 않는다.** 적도 보상도 라운드도 그대로고, 조합의 번거로움만 던다 —
## 최하위 재료가 다 모여 있으면 중간 단계를 건너뛰고 바로 만들 수 있고, 전체 조합표가
## 종류별로 몇 개가 드는지를 함께 보여 준다.
##
## 난이도를 적 체력으로 만들지 않은 이유는, 이 게임에서 실제로 어려운 것이 전투가 아니라
## **조합 트리를 머리에 담는 일**이기 때문이다. 247개짜리 트리를 외우게 하는 것이
## 난이도가 되어서는 안 된다.
enum Mode { EASY, NORMAL }
const MODE_NAME := ["쉬움", "보통"]
const MODE_TAG := ["조합이 쉽습니다", "원래 규칙 그대로"]
const MODE_DESC := [
	"재료가 모자라면 그 재료를 만들어서라도 이어 붙입니다. 중간에 무엇이 있든, 최하위까지 내려가든 됩니다. 전체 조합표가 최하위 유닛이 종류별로 몇 개 드는지 같이 보여 줍니다.",
	"조합법에 적힌 재료를 그대로 갖춰야 합니다. 전체 조합표는 바로 위 재료만 보여 줍니다.",
]

# ══ 맵 ════════════════════════════════════════════════════════
## 본진(고리 트랙이 있는 넓은 판)과 스토리 라인(옆에 붙은 좁은 판) 둘로 나뉜다.
## **판을 넓게 잡지 마라.** 화면에 판 전체가 늘 들어와야 하는데(카메라가 고정이다),
## 넓힌 만큼 유닛과 몬스터가 작아져서 무엇이 무엇인지 안 읽힌다. 44×30 이었을 때
## 몬스터가 10픽셀짜리 점이었다.
const ARENA := Vector2(34.0, 24.0)
const STORY_X := 40.0                       ## 스토리 라인 왼쪽 끝
const STORY := Vector2(13.0, 17.0)          ## 스토리 라인 크기
const STORY_Z := 3.5                        ## 스토리 라인 위쪽 끝

## 몬스터가 도는 고리. **닫혀 있다** — 마지막 점 다음은 첫 점이다.
const LOOP := [[6.0, 6.0], [28.0, 6.0], [28.0, 18.0], [6.0, 18.0]]

## 살아 있는 몬스터가 이만큼이면 패배.
const LOSE_COUNT := 100

# ══ 라운드 ════════════════════════════════════════════════════
const MAX_ROUND := 40
const ROUND_TIME := 30.0
## 보스는 이 주기마다 **딱 한 마리** 나온다.
const BOSS_EVERY := 10
const BOSS_HP_MUL := 26.0
const BOSS_SPD_MUL := 0.55

# ══ 위습과 목재 ════════════════════════════════════════════════
const WISP_START := 10
const WISP_PER_ROUND := 4

## 골드는 **몬스터를 잡으면 나온다.** 위습·목재와 달리 라운드 보상이 아니라 손으로 벌어들이는
## 자원이라, 잘 잡을수록 위습이 조금 더 붙는다. 위습 지급률을 직접 올리는 것보다
## 이쪽이 나은 이유는 **밀리고 있을 때는 골드도 안 들어오기** 때문이다 — 격차가 벌어지는
## 판에서 보상까지 얹어 주면 되돌릴 수 없는 상태가 오래 이어진다.
const GOLD_PER_KILL := 12
const GOLD_BOSS_MUL := 20
## 골드로 위습 한 개를 사는 값
const WISP_PRICE := 400

## 나무 도박 — 위습 하나를 넣고 목재를 얻는다. 꽝(0)이 있어서 도박이다.
const LUMBER_ODDS := [
	{"n": 0, "w": 0.28},
	{"n": 1, "w": 0.44},
	{"n": 2, "w": 0.20},
	{"n": 3, "w": 0.08},
]
## 랜덤 도박 — 목재를 이만큼 넣으면 랜덤전용·특수함 유닛이 하나 나온다.
const LUMBER_COST := 3

## 랜덤 도박 성공률. **실패해도 빈손은 아니다** — [constant TOKEN_NAME] 이 남는다.
const LUMBER_HIT := 0.5

## 압살롬 도박 — 목재를 걸고 확률로 압살롬을 뽑는다.
##
## **압살롬은 다른 길이 없다.** 조합법이 `좀비` 3기를 요구하는데 좀비는 안흔함이라
## 스토리 보상(1·2·4단계)으로만 나오고, 그 좁은 뽑기에서 같은 유닛을 셋이나 모으는 것은
## 사실상 불가능하다. 그래서 목재를 거는 전용 도박을 따로 둔다.
const ABSALOM_NAME := "압살롬"
const ABSALOM_COST := 1
const ABSALOM_CHANCE := 0.33

const TOKEN_NAME := "행운의 토큰"
const KUMA_NAME := "초월쿠마"

## 조합법이 재료로 요구하는 `목재` 유닛. **이건 유닛이 아니라 자원이다** —
## 조합 판정에서 [member Game.lumber] 로 이어 준다. 안 이어 주면 목재 하나가
## 조합법 **95개**를 막는다(실측).
const LUMBER_UNIT_NAME := "목재"

static var _named := {}


## 이름으로 유닛의 자리를 찾는다. 없으면 -1. 한 번 찾고 캐시한다.
static func named(n: String) -> int:
	if not _named.has(n):
		var found := -1
		for k in U.UNITS.size():
			if String(U.UNITS[k]["n"]) == n:
				found = k
				break
		_named[n] = found
	return int(_named[n])


static func absalom() -> int:
	return named(ABSALOM_NAME)


## 조합법에 쓰이는 `목재` 의 **id** (자리가 아니다). 없으면 -1.
static func lumber_id() -> int:
	var k := named(LUMBER_UNIT_NAME)
	return int(U.UNITS[k]["i"]) if k >= 0 else -1


## `랜덤전용유닛 1기` 는 특정 유닛이 아니라 **"랜덤전용 등급 아무거나 하나"** 를 뜻하는 표식이다.
## (나루토 선인모드 · 메구밍 처럼 랜덤 도박에서만 나오는 것들)
const WILD_NAME := "랜덤전용유닛 1기"
const WILD_GRADE := "랜덤전용"

static var _wild_id := -2
static var _wild_ids := {}


static func wild_id() -> int:
	if _wild_id == -2:
		var k := named(WILD_NAME)
		_wild_id = int(U.UNITS[k]["i"]) if k >= 0 else -1
	return _wild_id


## `id` 가 그 표식을 채울 수 있는 유닛인가
static func is_wild(id: int) -> bool:
	if _wild_ids.is_empty():
		for k in U.UNITS.size():
			if U.GRADE[int(U.UNITS[k]["g"])] == WILD_GRADE:
				_wild_ids[int(U.UNITS[k]["i"])] = true
	return _wild_ids.has(id)

## 스토리 보상 종류
enum Rw { UNCOMMON, SPECIAL, RARE, CHOICE }
## [enum Rw] 가 뽑는 등급. `CHOICE` 는 등급이 아니라 고르는 보상이라 비어 있다.
const RW_GRADE := ["안흔함", "특별함", "희귀함", ""]

# ══ 스토리 진행맵 ══════════════════════════════════════════════
## 1~14단계. 유닛을 스토리 라인으로 **직접 옮겨** 그 단계의 몬스터를 잡으면 넘어간다.
## 본진 방어가 그만큼 얇아지므로 "언제 보낼지"가 이 게임의 두 번째 결정이다.
const STORY_STAGES := 14
## 10단계는 보상이 다르다 — 희귀함 레일리 · 해적선 · 목재 중에서 고른다.
const STORY_CHOICE_STAGE := 10
const STORY_CHOICE := ["희귀함 레일리", "해적선", "초월쿠마", "목재 5"]

## 단계별 보상 등급. **희귀함은 8·9단계뿐이고 10단계는 고르는 보상**이다 —
## 희귀함을 자주 주면 스토리 한 번으로 본진 화력이 해결돼 라운드를 버티는 의미가 사라진다.
## 나머지는 안흔함과 특별함을 섞는다.
const STORY_REWARD := [
	Rw.UNCOMMON, Rw.UNCOMMON, Rw.SPECIAL, Rw.UNCOMMON, Rw.SPECIAL,
	Rw.SPECIAL, Rw.SPECIAL, Rw.RARE, Rw.RARE, Rw.CHOICE,
	Rw.SPECIAL, Rw.SPECIAL, Rw.SPECIAL, Rw.SPECIAL,
]

## 단계를 깰 때마다 함께 주는 **흔함 선택 위습** 수.
##
## 무작위 뽑기로만 흔함을 모으면 마지막 한 종이 끝내 안 나와서 트리가 통째로 막힌다.
## 고를 수 있는 흔함이 조금씩 들어와야 "이 조합법을 노린다"가 계획이 된다.
const STORY_PICK := 1
## 단계 k 의 몬스터 수와 체력 배수
const STORY_HP := 30.0
const STORY_HP_POW := 1.62
const STORY_COUNT := 3

# ══ 유닛 성능 ══════════════════════════════════════════════════
## [U] 의 `c`(최하위 재료 몇 개로 만들어지는가)가 곧 세기다.
## 지수를 1보다 크게 둔 것이 **합성의 이득**이다 — 재료 넷을 그대로 두는 것보다
## 합쳐서 하나로 만드는 쪽이 세다. 1.0 으로 내리면 조합할 이유가 사라진다.
const BASE_DPS := 9.0
const DPS_POW := 1.06

const BASE_RANGE := 7.0
const BASE_CD := 1.0

## 몬스터의 방어. 유닛의 역할(물뎀·마뎀)에 따라 깎이는 정도가 다르다 —
## **이것이 역할이 존재하는 유일한 이유다.** 없으면 이름만 다른 유닛이 된다.
const ARMOR_CUT := 0.42
## 스토리 라인에서 `스토리` 역할 유닛이 받는 보너스
const STORY_ROLE_BONUS := 1.6

# ══ 몬스터 ════════════════════════════════════════════════════
const MOB_HP := 26.0
const MOB_HP_POW := 1.09
const MOB_SPD := 2.6
const MOB_COUNT := 6
const MOB_COUNT_PER_ROUND := 0.5

## 몬스터 종 4가지. `armor` 가 큰 놈은 물뎀이, `mres` 가 큰 놈은 마뎀이 잘 안 든다.
const MOB_NAME := ["해적", "돌격병", "중갑병", "요괴"]
const MOB := [
	{"spd": 1.00, "hp": 1.00, "armor": 0.0, "mres": 0.0},
	{"spd": 1.45, "hp": 0.65, "armor": 0.0, "mres": 0.3},
	{"spd": 0.75, "hp": 1.85, "armor": 0.5, "mres": 0.0},
	{"spd": 1.15, "hp": 0.95, "armor": 0.3, "mres": 0.3},
]
const MOB_FROM := [1, 4, 8, 14]

## **판 전체의 세기 손잡이는 이것 하나다.** `sim.bat` 으로 재고 여기만 돌린다.
const HP_RAMP := 1.05
## 라운드 n 까지 정상적으로 굴렸을 때 기대되는 초당 피해를 계산할 때,
## 받은 위습이 실제로 한 덩어리로 뭉치는 비율. 1.0 이면 전부 하나로 합쳐진다는 뜻이라 비현실적이다.
const MERGE_EFF := 0.55


# ══ 맵 계산 ════════════════════════════════════════════════════

static func world_size() -> Vector2:
	return Vector2(STORY_X + STORY.x, maxf(ARENA.y, STORY_Z + STORY.y))


static func world_center() -> Vector3:
	var s := world_size()
	return Vector3(s.x * 0.5, 0.0, s.y * 0.5)


## 고리 위의 점들. **닫힌 고리라 마지막 다음이 첫 점이다.**
static func loop_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in LOOP:
		out.push_back(Vector3(p[0], 0.0, p[1]))
	return out


static func in_arena(p: Vector3) -> bool:
	return p.x >= 0.0 and p.x <= ARENA.x and p.z >= 0.0 and p.z <= ARENA.y


static func in_story(p: Vector3) -> bool:
	return p.x >= STORY_X and p.x <= STORY_X + STORY.x \
		and p.z >= STORY_Z and p.z <= STORY_Z + STORY.y


static func walkable(p: Vector3) -> bool:
	return in_arena(p) or in_story(p)


static func story_center() -> Vector3:
	return Vector3(STORY_X + STORY.x * 0.5, 0.0, STORY_Z + STORY.y * 0.5)


# ══ 유닛 ══════════════════════════════════════════════════════

static func unit(i: int) -> Dictionary:
	return U.UNITS[i]


## id 로 [U].UNITS 의 자리를 찾는다. id 는 띄엄띄엄해서 배열 색인이 아니다.
static var _by_id: Dictionary


static func index_of(id: int) -> int:
	if _by_id.is_empty():
		for k in U.UNITS.size():
			_by_id[int(U.UNITS[k]["i"])] = k
	return int(_by_id.get(id, -1))


static func has_tag(u: Dictionary, bit: int) -> bool:
	return (int(u["t"]) & bit) != 0


static func dps(u: Dictionary) -> float:
	return BASE_DPS * pow(float(u["c"]), DPS_POW)


static func cooldown(u: Dictionary) -> float:
	var cd := BASE_CD
	if has_tag(u, U.T_SPEEDB):
		cd *= 0.72
	if has_tag(u, U.T_SINGLE):
		cd *= 1.35
	return cd


static func reach(u: Dictionary) -> float:
	var r := BASE_RANGE
	if has_tag(u, U.T_SINGLE):
		r += 2.4
	if has_tag(u, U.T_LAST):
		r += 1.2
	if has_tag(u, U.T_SPLASH):
		r -= 0.6
	return r


## 한 방에 들어가는 피해
static func hit_damage(u: Dictionary) -> float:
	return dps(u) * cooldown(u)


static func splash(u: Dictionary) -> float:
	if has_tag(u, U.T_SPLASH) or has_tag(u, U.T_RANGENLPD) \
			or has_tag(u, U.T_RANGETLPD) or has_tag(u, U.T_RANGELLPD):
		return 2.8
	return 0.0


static func slow(u: Dictionary) -> float:
	return 0.35 if has_tag(u, U.T_SLOW) else 0.0


static func stun(u: Dictionary) -> float:
	if has_tag(u, U.T_STUN):
		return 0.45
	if has_tag(u, U.T_SSTUN):
		return 0.22
	return 0.0


## 역할과 몬스터 방어로 실제 피해를 낸다. 방무뎀(`armorbreak`)은 이걸 통째로 무시한다.
static func mitigate(u: Dictionary, mob: Dictionary) -> float:
	if has_tag(u, U.T_ARMORBREAK):
		return 1.0
	var role := int(u["r"])
	var res := float(mob["armor"]) if role == 0 else float(mob["mres"])
	return 1.0 - res * ARMOR_CUT


# ══ 뽑기 ══════════════════════════════════════════════════════

## 등급 이름으로 그 등급 유닛들의 자리를 모은다. 한 번 만들고 캐시한다.
static var _by_grade: Dictionary


static func grade_pool(grade_name: String) -> Array:
	if _by_grade.is_empty():
		for k in U.UNITS.size():
			var g: String = U.GRADE[int(U.UNITS[k]["g"])]
			if not _by_grade.has(g):
				_by_grade[g] = []
			_by_grade[g].append(k)
	return _by_grade.get(grade_name, [])


## 일반 위습 — 가장 아래 등급에서 하나
static func draw_normal(rng: RandomNumberGenerator) -> int:
	var pool := grade_pool("흔함")
	return pool[rng.randi_range(0, pool.size() - 1)]


## 등급 이름으로 하나 뽑는다. 스토리 보상 위습이 쓴다.
static func draw_grade(grade_name: String, rng: RandomNumberGenerator) -> int:
	var pool := grade_pool(grade_name)
	if pool.is_empty():
		return draw_normal(rng)
	return pool[rng.randi_range(0, pool.size() - 1)]


## 스토리 단계 `stage`(1부터) 를 깼을 때의 보상 종류
static func story_reward(stage: int) -> int:
	var i := clampi(stage - 1, 0, STORY_REWARD.size() - 1)
	return int(STORY_REWARD[i])


## 조합법을 가진 유닛을 등급별로 모은다. 전체 조합표가 이걸 쪽 단위로 보여 준다.
static var _recipes: Dictionary


static func recipes_of_grade(gi: int) -> Array:
	if _recipes.is_empty():
		for k in U.UNITS.size():
			if (U.UNITS[k]["m"] as Array).is_empty():
				continue
			var g := int(U.UNITS[k]["g"])
			if not _recipes.has(g):
				_recipes[g] = []
			_recipes[g].append(k)
	return _recipes.get(gi, [])


## 조합법이 하나라도 있는 등급들 (전체 조합표에서 넘겨 볼 수 있는 등급)
static func recipe_grades() -> Array:
	var out := []
	for gi in U.GRADE.size():
		if not recipes_of_grade(gi).is_empty():
			out.append(gi)
	return out


## 목재 도박 — 랜덤전용이나 특수함
static func draw_lumber(rng: RandomNumberGenerator) -> int:
	var pool: Array = grade_pool("랜덤전용").duplicate()
	pool.append_array(grade_pool("특수함"))
	return pool[rng.randi_range(0, pool.size() - 1)]


static func roll_lumber(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for o in LUMBER_ODDS:
		total += float(o["w"])
	var r := rng.randf() * total
	for o in LUMBER_ODDS:
		r -= float(o["w"])
		if r <= 0.0:
			return int(o["n"])
	return 0


# ══ 라운드 편성 ════════════════════════════════════════════════

## 라운드 n 까지 받은 위습을 다 쓰고 잘 조합했을 때의 초당 피해
static func power(n: int) -> float:
	var c := float(WISP_START + WISP_PER_ROUND * maxi(n, 1))
	return BASE_DPS * pow(c, DPS_POW) * MERGE_EFF


static func mob_count(n: int) -> int:
	return int(MOB_COUNT + MOB_COUNT_PER_ROUND * float(n))


## 라운드 n 에 나오는 몬스터 한 마리의 체력.
## 라운드가 지나도 안 죽은 놈이 남으므로, **한 라운드 분량을 그 라운드 안에 못 치우면
## 다음 라운드가 그 위에 얹힌다.** 그게 이 게임의 압박이다.
static func mob_hp(n: int) -> float:
	var pool := power(n) * ROUND_TIME * HP_RAMP
	return pool / float(maxi(mob_count(n), 1))


static func mob_speed(n: int) -> float:
	return MOB_SPD


static func is_boss_round(n: int) -> bool:
	return n % BOSS_EVERY == 0


static func mob_kind(n: int, rng: RandomNumberGenerator) -> int:
	var pool := []
	for i in MOB.size():
		if n >= MOB_FROM[i]:
			pool.append(i)
	return pool[rng.randi_range(0, pool.size() - 1)]


static func story_hp(stage: int) -> float:
	return STORY_HP * pow(STORY_HP_POW, float(stage))
