class_name D
extends RefCounted

## 수치는 전부 여기 모은다. 드래곤 · 적 · 구간 · 웨이브 · 상점이 한 파일에 있다.

# ==================== 화면 ====================

## **세로 화면 전체가 플레이필드다.** 폰 게임이라 옆 패널이 없다 — HUD 는 위에 얹는다.
## 기준 해상도는 720×1280 이고, 실제 폭·높이는 뷰포트에서 받아 쓴다(기기마다 비율이 다르다).
const REF_W := 720.0
const REF_H := 1280.0

## 드래곤이 서 있는 높이(화면 높이 대비). 아래쪽에 엄지손가락 자리를 남긴다.
const HERO_Y := 0.76

# ==================== 빌드 ====================

## **테스트 빌드에서만 켜지는 것**(먼 거리부터 시작, 저장 지우기 등).
## PC 내보내기의 "Windows Desktop Test" 프리셋이 `testmode` 기능 태그를 박아 넣고,
## 소스 실행(`run.bat`)은 디버그 빌드라 자동으로 켜진다. **배포 APK 에는 안 나온다.**
static func test_build() -> bool:
	return OS.has_feature("testmode") or OS.is_debug_build()

# ==================== 진행 ====================

## **스크롤 속도는 고정이다. 거리는 곧 시간이다.**
##
## 뒤로 갈수록 빨라지게 하고 싶어지지만, 그러면 같은 웨이브 표가 거리에 따라 다른
## 밀도가 되어 **난이도 통로가 둘이 된다**(아래 "난이도는 한 줄의 식" 참고).
## 빨라지는 느낌은 배경 잔무늬 층으로 낸다 — 실제 판정은 안 건드린다.
const SCROLL := 340.0
const PX_PER_M := 10.0        ## 화면 10px = 1m -> 초당 34m

## 구간 하나의 길이. 배경과 웨이브 표가 여기서 바뀌고, 끝에 관문이 온다.
const ZONE_M := 1000.0

# ==================== 난이도는 한 줄의 식이다 ====================
#
#   거리 m 는, 모든 강화를 lv 단계까지 올린 화력이면 도달한다
#
# `hp_at(m)` 이 **난이도의 전부**다. 적 체력에만 걸리고, 스폰 표·속도·탄 수는
# 거리를 보지 않는다. 상점 화력 `power(lv)` 와 이 곡선이 한 쌍으로 움직인다.
#
# **여기에 두 번째 통로를 만들지 마라.** 거리에 따라 스폰을 늘리거나 스크롤을
# 빠르게 하면 그 순간부터 검산이 불가능해지고, 수치를 아무리 다듬어도 못 맞춘다.
# 갈루가와 좀비디펜스에서 같은 실수를 이미 두 번 했다.

## 적 체력이 두 배가 되는 거리.
const HP_DOUBLE := 2000.0

## **맨몸(0강)으로 도달하는 거리.** 등식의 기준점이다 —
## 여기가 헐거우면 모든 강화 단계가 똑같이 헐거워진다.
const BASE_REACH := 2000.0


## 거리 m 에서의 적 체력 배율.
static func hp_at(m: float) -> float:
	return pow(2.0, maxf(0.0, m) / HP_DOUBLE)


## 모든 상점 항목이 lv 단계일 때의 초당 피해 배율.
static func power(lv: int) -> float:
	return (1.0 + DMG_PER * lv) * (1.0 + RATE_PER * lv)


## lv 단계에서 벽을 만나는 거리(m). README 와 soak 검산이 보는 값이다.
static func reach(lv: int) -> float:
	return BASE_REACH + HP_DOUBLE * (log(power(lv)) / log(2.0))

# ==================== 드래곤 ====================

const POWER_MAX := 5

## **파워 단계별 초당 피해 배율. 세 마리가 이 곡선을 똑같이 따른다.**
##
## 드래곤이 다른 건 세기가 아니라 **브레스가 자라는 방향**이다 — 같은 화력을
## 굵게 뭉치느냐, 넓게 펴느냐, 앞을 뚫느냐. 한 마리만 세면 고를 이유가 사라진다.
const POWER_DPS := [1.0, 1.36, 1.74, 2.20, 2.62, 3.00]

## 브레스 기본값. 실제 발사는 [World] 의 드래곤별 함수가 이 값을 나눠 쓴다.
const BASE_DMG := 16.0
const BASE_CD := 0.17

## **관통 브레스가 같은 적을 다시 때리기까지의 간격.**
## 없으면 겹쳐 있는 동안 매 프레임 피해가 들어가 초당 60번이 된다.
## 관통은 "여러 마리를 뚫는 것"이지 "한 마리를 60배로 때리는 것"이 아니다.
const REHIT := 0.12

const DRAGON := [
	{id = "fire", name = "화룡", axis = "집중",
		speed = 430.0, hit = 7.0, col = 0,
		basic = "앞으로 굵은 불줄기 하나",
		grow = "줄기가 계속 두꺼워집니다. 한 마리를 빨리 녹여서 앞을 막는 골렘과 관문에 강합니다.",
		note = "정면이 제일 강한 대신 옆에서 들어오는 것을 놓치기 쉽습니다."},
	{id = "storm", name = "뇌룡", axis = "확산",
		speed = 470.0, hit = 6.0, col = 1,
		basic = "좌우로 갈라지는 번개 2줄기",
		grow = "부채처럼 벌어집니다. 만렙은 폭을 그대로 둔 채 촘촘해져 화면을 넓게 씁니다.",
		note = "제일 빠릅니다. 넓게 훑는 대신 한 점에 모이는 화력이 약합니다."},
	{id = "frost", name = "빙룡", axis = "관통",
		speed = 400.0, hit = 7.5, col = 2,
		basic = "적을 뚫는 얼음창 하나",
		grow = "창이 길고 굵어집니다. 세로로 줄지어 내려오는 무리를 한 번에 꿰뚫습니다.",
		note = "느리지만 판정점이 커도 될 만큼 앞을 확실히 비웁니다."},
]

## 부딪히면 그 자리에서 끝난다. 보호막이 있으면 한 겹 대신 깎인다.
const INVULN := 1.6          ## 보호막이 깨진 뒤 무적 시간
const START_INVULN := 1.2

# ==================== 적 ====================

## **특수 행동은 종류 번호가 아니라 `art` 로 가른다** — 번호로 비교해 두면
## 종류를 늘릴 때 반드시 한 군데를 빠뜨린다.
##
## `speed` 는 **화면 아래로 내려오는 절대 속도**다. 지형과 같이 흘러가는 것은
## 반드시 `SCROLL` 을 그대로 써야 한다 — 갈루가에서 지형 74 · 유닛 58 로 적어
## 초당 16px 씩 미끄러진 적이 있다. 숫자가 둘이면 반드시 어긋난다.
##
## `hp = 0` 은 **부술 수 없다는 뜻**이다(바위). 피하는 것 말고 방법이 없다.
const ENEMY := {
	imp = {art = "imp", hp = 12.0, speed = 400.0, gold = 2, fire = 0.0, r = 17.0,
		move = "wave"},
	wisp = {art = "wisp", hp = 8.0, speed = 620.0, gold = 2, fire = 0.0, r = 14.0,
		move = "dive"},
	golem = {art = "golem", hp = 64.0, speed = 362.0, gold = 8, fire = 0.0, r = 30.0,
		move = "straight"},
	wyvern = {art = "wyvern", hp = 26.0, speed = 396.0, gold = 5, fire = 1.7, r = 22.0,
		move = "sway"},
	orb = {art = "orb", hp = 34.0, speed = 346.0, gold = 6, fire = 1.25, r = 19.0,
		move = "drift"},
	rock = {art = "rock", hp = 0.0, speed = SCROLL, gold = 0, fire = 0.0, r = 34.0,
		move = "terrain"},
}

const E_BULLET_SPD := 300.0
const E_BULLET_R := 9.0

# ==================== 구간과 웨이브 ====================

## `at` 은 구간 안의 진행도(0~1). 구간은 `ZONE_M` 마다 돌아가며 반복되고,
## **반복될수록 어려워지는 것은 오직 `hp_at(m)` 때문이다** — 표 자체는 그대로다.
##
## kind:
##   line   가로 한 줄 (gap = x 간격)
##   vee    V자 편대 (가운데가 앞)
##   stream 세로로 줄줄이 (gap = y 간격 -> 시간차가 된다)
##   wall   바위 벽 — 통로 한 칸만 비운다
##   coins  금화 가로줄 · snake 금화 지그재그 · arc 금화 호
##   gate   관문 — 구간 끝의 밀집 편대

## **표는 구간 안에서 달아오른다 — 그리고 구간마다 똑같이 되풀이된다.**
##
## 이게 "난이도 통로는 하나"를 지키면서 밀도를 쓰는 방법이다. `at` 은 구간 안의
## 진행도라 **거리를 보지 않는다** — 1구간의 절정과 30구간의 절정은 물량이 똑같고,
## 다른 것은 `hp_at(m)` 이 정하는 체력뿐이다.
##
## **앞을 헐겁게 둔 채 뒤를 안 채우면 아무것도 안 쏘고 피하기만 해도 뚫린다** —
## 실제로 그랬다(6분 무인 주행에서 처치 3마리로 5470m). 화력이 진행을 막으려면
## 구간 끝이 "길을 뚫지 않으면 못 지나가는" 밀도여야 한다.
##
## 1구간 · 초원 — 기본형. 잡졸과 금화가 많고 바위가 가끔.
const Z1 := [
	# 앞 — 숨 돌리기
	{at = 0.02, kind = "coins", k = "", n = 6, gap = 54.0},
	{at = 0.06, kind = "line", k = "imp", n = 3, gap = 120.0},
	{at = 0.11, kind = "snake", k = "", n = 10, gap = 62.0},
	{at = 0.16, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.21, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.26, kind = "coins", k = "", n = 7, gap = 50.0},
	{at = 0.30, kind = "stream", k = "imp", n = 4, gap = 130.0},
	{at = 0.34, kind = "line", k = "golem", n = 1, gap = 0.0},
	# 중간
	{at = 0.38, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.42, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.46, kind = "line", k = "wyvern", n = 2, gap = 190.0},
	{at = 0.50, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.54, kind = "stream", k = "imp", n = 5, gap = 110.0},
	{at = 0.58, kind = "line", k = "imp", n = 5, gap = 104.0},
	{at = 0.62, kind = "snake", k = "", n = 12, gap = 58.0},
	{at = 0.65, kind = "line", k = "golem", n = 2, gap = 220.0},
	# 절정 — 여기부터는 뚫지 않으면 못 지나간다
	{at = 0.69, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.72, kind = "line", k = "imp", n = 6, gap = 96.0},
	{at = 0.75, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.78, kind = "stream", k = "imp", n = 6, gap = 92.0},
	{at = 0.81, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.84, kind = "line", k = "golem", n = 2, gap = 220.0},
	{at = 0.86, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.89, kind = "coins", k = "", n = 8, gap = 48.0},
	{at = 0.91, kind = "gate", k = "imp", n = 9, gap = 76.0},
	{at = 0.94, kind = "line", k = "imp", n = 7, gap = 88.0},
	{at = 0.97, kind = "line", k = "wyvern", n = 3, gap = 150.0},
]

## 2구간 · 협곡 — **바위가 주인공.** 통로를 찾아 들어가는 구간이라
## 부술 수 있는 적은 적게 두고, 대신 골렘이 통로를 막는다.
const Z2 := [
	{at = 0.02, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.07, kind = "coins", k = "", n = 6, gap = 54.0},
	{at = 0.12, kind = "line", k = "golem", n = 2, gap = 220.0},
	{at = 0.17, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.22, kind = "stream", k = "imp", n = 4, gap = 126.0},
	{at = 0.27, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.32, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.36, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.40, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.44, kind = "line", k = "golem", n = 2, gap = 220.0},
	{at = 0.48, kind = "snake", k = "", n = 11, gap = 60.0},
	{at = 0.52, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.55, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.59, kind = "line", k = "orb", n = 2, gap = 200.0},
	{at = 0.62, kind = "line", k = "golem", n = 3, gap = 170.0},
	# 절정 — 벽과 골렘이 겹친다. 골렘을 녹여야 통로가 열린다.
	{at = 0.66, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.69, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.72, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.75, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.78, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.81, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.84, kind = "stream", k = "imp", n = 6, gap = 92.0},
	{at = 0.87, kind = "wall", k = "rock", n = 1, gap = 0.0},
	{at = 0.89, kind = "coins", k = "", n = 8, gap = 48.0},
	{at = 0.92, kind = "gate", k = "golem", n = 4, gap = 150.0},
	{at = 0.95, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.97, kind = "vee", k = "imp", n = 7, gap = 84.0},
]

## 3구간 · 밤하늘 — **빠른 것과 쏘는 것.** 도깨비불이 위에서 곧장 떨어지고
## 마법구가 자리를 잡고 탄을 뿌린다. 바위는 없다 — 하늘이라 그럴 자리가 없다.
const Z3 := [
	{at = 0.02, kind = "line", k = "orb", n = 2, gap = 200.0},
	{at = 0.07, kind = "stream", k = "wisp", n = 5, gap = 96.0},
	{at = 0.12, kind = "coins", k = "", n = 7, gap = 50.0},
	{at = 0.16, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.21, kind = "stream", k = "wisp", n = 6, gap = 88.0},
	{at = 0.26, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.30, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.34, kind = "snake", k = "", n = 12, gap = 58.0},
	{at = 0.38, kind = "stream", k = "wisp", n = 6, gap = 88.0},
	{at = 0.42, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.46, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.50, kind = "stream", k = "wisp", n = 7, gap = 80.0},
	{at = 0.54, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.58, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.62, kind = "stream", k = "wisp", n = 7, gap = 80.0},
	{at = 0.65, kind = "line", k = "wyvern", n = 4, gap = 128.0},
	# 절정
	{at = 0.69, kind = "stream", k = "wisp", n = 8, gap = 74.0},
	{at = 0.72, kind = "line", k = "orb", n = 4, gap = 130.0},
	{at = 0.75, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.78, kind = "stream", k = "wisp", n = 8, gap = 74.0},
	{at = 0.81, kind = "line", k = "wyvern", n = 4, gap = 128.0},
	{at = 0.84, kind = "line", k = "orb", n = 4, gap = 130.0},
	{at = 0.86, kind = "stream", k = "wisp", n = 8, gap = 74.0},
	{at = 0.89, kind = "coins", k = "", n = 8, gap = 48.0},
	{at = 0.91, kind = "gate", k = "wisp", n = 10, gap = 62.0},
	{at = 0.94, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.97, kind = "line", k = "wyvern", n = 4, gap = 128.0},
]

const ZONE := [
	{name = "초원", table = Z1, sky = 0},
	{name = "협곡", table = Z2, sky = 1},
	{name = "밤하늘", table = Z3, sky = 2},
]

# ==================== 아이템 ====================

## **P 는 난수로 떨구지 않는다 — 거리마다 딱 하나씩 나온다.**
##
## 확률로 두면 운 좋은 판은 앞에서 만렙이 되고 운 나쁜 판은 끝까지 맨몸이라,
## 같은 거리가 판마다 다른 게임이 된다. 첫 하나를 일찍 둬서 초반에 화력을 갖추게 한다.
const POWER_FIRST := 120.0
const POWER_EVERY := 260.0
const POWER_FULL_GOLD := 40      ## 이미 만렙이면 금화로 바꿔 준다

const COIN_GOLD := 3
const ITEM_R := 18.0
const MAGNET_BASE := 96.0        ## 금화가 끌려오기 시작하는 거리
const MAGNET_SPD := 620.0

# ==================== 상점 (판 밖 강화) ====================
#
# **판 안 성장과 섞지 마라.**
#   판 안 = 파워업 P (그 판에서만, 죽으면 사라짐)
#   판 밖 = 여기 (금화로 사고, 영원히 남음)
# 둘을 한 곳에 두면 "이번 판에 센 것"과 "계속 세지는 것"의 구분이 사라진다.

const DMG_PER := 0.25            ## 공격력 레벨당
const RATE_PER := 0.055          ## 연사 레벨당

const SHOP := [
	{id = "dmg", name = "브레스 위력", max = 40, base = 30, mul = 1.075,
		desc = "브레스 한 방의 피해가 레벨당 25% 오릅니다."},
	{id = "rate", name = "브레스 연사", max = 40, base = 34, mul = 1.075,
		desc = "브레스 간격이 레벨당 5.5% 짧아집니다."},
	{id = "speed", name = "비행 속도", max = 30, base = 26, mul = 1.07,
		desc = "좌우로 움직이는 속도가 레벨당 1.2% 빨라집니다."},
	{id = "magnet", name = "금화 흡수", max = 30, base = 22, mul = 1.07,
		desc = "금화가 끌려오는 거리가 레벨당 5% 넓어집니다."},
	{id = "greed", name = "금화 가치", max = 30, base = 40, mul = 1.075,
		desc = "주운 금화와 처치 보상이 레벨당 4% 많아집니다."},
	## **즉사 게임에 「한 번 봐줌」이 필요하다.** 다만 세 겹이 상한이다 —
	## 더 주면 부딪히는 것이 실수가 아니라 자원 소모가 되어 긴장이 통째로 빠진다.
	{id = "shield", name = "비늘 보호막", max = 3, base = 1500, mul = 3.2,
		desc = "판을 시작할 때 보호막을 한 겹 두르고 시작합니다. 부딪히면 한 겹이 깨집니다."},
]


static func shop(id: String) -> Dictionary:
	for s in SHOP:
		if String(s.id) == id:
			return s
	return {}


static func cost(id: String, lv: int) -> int:
	var s := shop(id)
	if s.is_empty() or lv >= int(s.max):
		return 0
	return int(round(float(s.base) * pow(float(s.mul), lv)))


# ---- 강화가 실제로 내는 배율. 호출부에 곱하기를 흩뿌리지 말고 여기만 본다. ----

static func dmg_mul() -> float:
	return 1.0 + DMG_PER * Sv.level("dmg")


static func rate_mul() -> float:
	return 1.0 + RATE_PER * Sv.level("rate")


static func speed_mul() -> float:
	return 1.0 + 0.012 * Sv.level("speed")


static func magnet() -> float:
	return MAGNET_BASE * (1.0 + 0.05 * Sv.level("magnet"))


static func greed_mul() -> float:
	return 1.0 + 0.04 * Sv.level("greed")


static func shields() -> int:
	return Sv.level("shield")
