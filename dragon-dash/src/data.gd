class_name D
extends RefCounted

## 수치는 전부 여기 모은다. 드래곤 · 적 · 보스 · 구간 · 웨이브 · 아이템 · 상점.

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

## **스크롤은 갈수록 빨라진다.**
##
## 처음엔 고정이었다. "난이도 통로는 하나여야 검산할 수 있다"는 이 저장소의 규율을
## 그대로 가져왔기 때문인데, **러너에서는 그게 장르를 깎아먹는다** — 원작도
## "더 멀리 갈수록 비행 속도가 빨라지고 적들이 강해진다" 가 한 줄 소개다.
## 고정해 두면 10분을 달려도 첫 1분과 같은 속도라 "몰린다"가 아예 안 생긴다.
## 그래서 **일부러 통로를 늘렸다.** 대신 난이도는 증명이 아니라 직접 플레이로 잡는다.
const SCROLL := 330.0
const SCROLL_MAX := 1.9          ## 끝에서 이 배까지 빨라진다
const SCROLL_RAMP := 9000.0      ## 이 거리마다 +1배
const PX_PER_M := 10.0           ## 화면 10px = 1m


static func scroll_at(m: float) -> float:
	return SCROLL * minf(SCROLL_MAX, 1.0 + maxf(0.0, m) / SCROLL_RAMP)


## 구간 하나의 길이. 배경과 웨이브 표가 여기서 바뀌고, 끝에 보스가 나온다.
const ZONE_M := 1000.0

# ==================== 난이도 ====================
#
# 난이도를 올리는 통로가 **셋**이다 — 적 체력 · 스크롤 속도 · 구간 안의 밀도.
# 다른 게임(좀비디펜스 · 갈루가)은 통로를 하나로 묶어 등식으로 검산하지만,
# **여기서는 일부러 그러지 않는다.** 러너는 여러 축이 한꺼번에 조여드는 것이
# 곧 재미다. 대신 대가를 치른다: **수치를 증명할 수 없다.**
# `soak.bat` 은 "크게 망가지지 않았나"만 보고, 난이도는 직접 플레이해서 잡는다.

## 적 체력이 두 배가 되는 거리. 스크롤도 같이 빨라지므로 넉넉하게 잡는다.
const HP_DOUBLE := 2600.0


static func hp_at(m: float) -> float:
	return pow(2.0, maxf(0.0, m) / HP_DOUBLE)


## 모든 상점 항목이 lv 단계일 때의 초당 피해 배율. 상점 값을 만졌는지 보는 눈금이다.
static func power(lv: int) -> float:
	return (1.0 + DMG_PER * lv) * (1.0 + RATE_PER * lv)

# ==================== 점수 ====================
#
# **점수 = 비행 거리 + 사냥 점수.** 거리만 세면 "안 쏘고 피하기만 하는" 것이
# 최적해가 된다 — 실제로 첫 판이 그랬다(처치 3마리로 5470m).

const SCORE_PER_M := 1.0

## **근접 처치 보너스 — 이 게임의 심장이다.**
##
## 가까이 붙어서 죽일수록 사냥 점수가 크게 오른다. 이게 없으면 "멀리서 안전하게
## 쏘기"가 언제나 정답이라 화면 아래에 붙어만 있게 된다. 원작이 즉사인데도
## 사람들이 적에게 파고드는 이유가 이것 하나다.
##
## **연속 곡선이 아니라 띠(band)다. 그리고 반지름이 아니라 세로 거리로 나뉜다.**
## 원작 화면에는 드래곤 위로 가로선이 그어져 있고 칸마다 2X · 3X · 5X · 20X 가
## 적혀 있다 — 배율이 **눈에 보이는 칸**이라야 "저기까지 끌어들여서 잡는다"는
## 판단이 생긴다. 부드러운 곡선으로 두면 왜 이번엔 7배고 저번엔 12배인지 알 수 없다.
##
## `top` 은 드래곤 위쪽으로 **화면 높이의 몇 배만큼**인지다. 위로 갈수록 배율이 낮다.
const CLOSE_BAND := [
	{mul = 20.0, top = 0.10},
	{mul = 5.0, top = 0.22},
	{mul = 3.0, top = 0.34},
	{mul = 2.0, top = 0.48},
]


## 드래곤보다 `dy` 만큼 위에서 죽였을 때의 배율. `dy` 는 화면 높이로 나눈 값이다.
static func close_mul(dy_frac: float) -> float:
	if dy_frac < 0.0:
		return 1.0        # 드래곤보다 아래(지나간 것)는 보너스 없음
	for b in CLOSE_BAND:
		if dy_frac <= float(b.top):
			return float(b.mul)
	return 1.0

# ==================== 드래곤 ====================

const POWER_MAX := 5

## **파워 단계별 초당 피해 배율. 세 마리가 이 곡선을 똑같이 따른다.**
##
## 드래곤이 다른 건 세기가 아니라 **브레스가 자라는 방향**이다 — 같은 화력을
## 굵게 뭉치느냐, 넓게 펴느냐, 앞을 뚫느냐. 한 마리만 세면 고를 이유가 사라진다.
const POWER_DPS := [1.0, 1.36, 1.74, 2.20, 2.62, 3.00]

## **브레스는 알갱이가 아니라 줄기다.**
##
## 처음엔 `BASE_DMG 4 · BASE_CD 0.17 · 폭 6` 이었는데, 화면을 덮는 폭이 23px(720 중)
## 뿐이라 **뿌린 적 체력의 20~25% 밖에 못 죽였다.** 눈앞의 것이 거의 다 살아서
## 지나가는 게임은 이 장르가 아니다 — 원작은 앞을 갈아버리며 나아간다.
## 목표는 `soak` 의 `clear` **80% 이상**이다.
const BASE_DMG := 13.0
const BASE_CD := 0.085

## **관통 브레스가 같은 적을 다시 때리기까지의 간격.**
## 없으면 겹쳐 있는 동안 매 프레임 피해가 들어가 초당 60번이 된다.
const REHIT := 0.10

const DRAGON := [
	{id = "fire", name = "화룡", axis = "집중",
		speed = 430.0, hit = 7.0, col = 0,
		basic = "앞으로 굵은 불줄기 하나",
		grow = "줄기가 계속 두꺼워집니다. 한 마리를 빨리 녹여서 보스와 운석에 강합니다.",
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

## 부딪히면 하트가 한 칸 깎이고, 하트가 없으면 그 자리에서 끝난다.
const INVULN := 1.5              ## 하트가 깎인 뒤 무적 시간
const START_INVULN := 1.2

# ==================== 적 ====================

## **특수 행동은 종류 번호가 아니라 `art` 로 가른다** — 번호로 비교해 두면
## 종류를 늘릴 때 반드시 한 군데를 빠뜨린다.
##
## `speed` 는 화면 아래로 내려오는 절대 속도다. 스크롤이 빨라지면 [World] 가
## `scroll_at(m)` 배율을 같이 곱한다 — 속도를 두 군데 적으면 반드시 어긋난다.
##
## **부술 수 없는 것은 하나도 없다.** 한때 바위를 못 부수게 두고 통로 한 칸만
## 비우는 벽으로 썼는데, 그 순간 게임이 "쏴서 길을 연다"가 아니라 "안 맞는 칸을
## 고른다"가 됐다 — 장르가 통째로 바뀐다.
const ENEMY := {
	imp = {art = "imp", hp = 11.0, speed = 400.0, gold = 2, score = 10, fire = 0.0,
		r = 17.0, move = "wave"},
	wisp = {art = "wisp", hp = 8.0, speed = 620.0, gold = 2, score = 12, fire = 0.0,
		r = 14.0, move = "dive"},
	golem = {art = "golem", hp = 58.0, speed = 362.0, gold = 9, score = 40, fire = 0.0,
		r = 30.0, move = "straight"},
	wyvern = {art = "wyvern", hp = 24.0, speed = 396.0, gold = 5, score = 24, fire = 1.7,
		r = 22.0, move = "sway"},
	orb = {art = "orb", hp = 32.0, speed = 346.0, gold = 6, score = 30, fire = 1.25,
		r = 19.0, move = "drift"},
	## 운석 — 원작의 "일정 구간마다 날아오는 운석". 제일 단단하고 빠르다.
	## 벽이 아니라 **날아오는 것**이라 피하든 녹이든 둘 다 된다.
	meteor = {art = "meteor", hp = 92.0, speed = 470.0, gold = 14, score = 60, fire = 0.0,
		r = 32.0, move = "fall"},
	## 불꽃 몬스터 — **죽으면 터져서 주변 적을 같이 없앤다.**
	## 화면이 꽉 찼을 때 이걸 먼저 노리는 것이 이 게임의 작은 수 읽기다.
	flame = {art = "flame", hp = 20.0, speed = 380.0, gold = 6, score = 35, fire = 0.0,
		r = 20.0, move = "wave"},
	## 보물 상자 — 부수면 금화가 쏟아진다. 체력이 높아 화력이 곧 벌이가 된다.
	chest = {art = "chest", hp = 70.0, speed = 340.0, gold = 0, score = 50, fire = 0.0,
		r = 24.0, move = "terrain"},
}

## 불꽃 몬스터가 터질 때의 반경과 피해. **주변 적을 실제로 지워야** 의미가 있다 —
## 조금 깎는 정도면 그냥 체력 많은 잡졸이다.
const FLAME_BOOM_R := 210.0
const FLAME_BOOM_DMG := 400.0

## 보물 상자가 쏟아내는 금화 개수
const CHEST_COINS := 14

const E_BULLET_SPD := 300.0
const E_BULLET_R := 9.0

# ==================== 보스 ====================

## **구간 끝마다 보스가 나온다**(원작도 "일정 간격마다 보스"다).
## 러너가 끝없이 흐르기만 하면 리듬이 없다 — "여기까지 왔다"를 찍어 주는 것이 보스다.
##
## `hp` 는 기준값이고 실제로는 `hp_at(m)` 이 곱해진다. `secs` 는 **목표 시간**이라
## 패턴이나 화력을 만졌으면 soak 이 찍는 초를 보고 `hp` 를 다시 맞춘다.
##
## **못 잡으면 날아가 버린다**(`BOSS_TIMEOUT`). 반드시 잡아야 넘어가게 하면
## 화력이 모자란 순간 그 자리에서 게임이 멈춘다 — 러너에서는 그게 제일 나쁘다.
## 대신 **빨리 잡을수록 점수가 크다**(원작도 그렇다).
const BOSS_AT := 0.93
const BOSS_TIMEOUT := 20.0
const BOSS_RAGE := 0.5            ## 이 아래로 깎이면 2페이즈 (발사가 빨라진다)
const BOSS_CAST := 0.55           ## 예비 동작. 즉발 공격은 만들지 않는다.
const BOSS_FAST_BONUS := 3.0      ## 즉시 처치 시 점수 배율 (시간이 갈수록 1배로)

const BOSS := [
	{art = "king", name = "바위 골렘 왕", hp = 820.0, secs = 8.0, gold = 150,
		score = 1500, r = Vector2(84.0, 72.0)},
	{art = "warden", name = "협곡의 파수꾼", hp = 980.0, secs = 9.0, gold = 190,
		score = 2000, r = Vector2(96.0, 66.0)},
	{art = "eye", name = "폭풍의 마안", hp = 1140.0, secs = 10.0, gold = 240,
		score = 2600, r = Vector2(78.0, 78.0)},
]

# ==================== 구간과 웨이브 ====================

## `at` 은 구간 안의 진행도(0~1). 구간은 `ZONE_M` 마다 돌아가며 반복된다.
##
## kind:
##   line   가로 한 줄 (gap = x 간격)
##   vee    V자 편대 (가운데가 앞)
##   stream 세로로 줄줄이 (gap = y 간격 -> 시간차가 된다)
##   coins  금화 가로줄 · snake 금화 지그재그 · arc 금화 호
##   item   인게임 아이템 하나 (듀얼샷 · 자석 · 하이퍼 · 더블스코어 중 하나)
##
## **`wall`(통로 한 칸만 남기는 바위 벽)은 없앴다.** 그게 있으면 쏘는 게임이 아니라
## 피하는 게임이 된다. 운석은 벽이 아니라 날아오는 것이라 녹여도 되고 피해도 된다.

## 1구간 · 초원 — 기본형. 잡졸과 금화가 많다.
const Z1 := [
	{at = 0.02, kind = "coins", k = "", n = 6, gap = 54.0},
	{at = 0.05, kind = "line", k = "imp", n = 4, gap = 110.0},
	{at = 0.09, kind = "snake", k = "", n = 10, gap = 62.0},
	{at = 0.12, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.16, kind = "line", k = "flame", n = 1, gap = 0.0},
	{at = 0.19, kind = "stream", k = "imp", n = 5, gap = 116.0},
	{at = 0.23, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.26, kind = "line", k = "golem", n = 2, gap = 210.0},
	{at = 0.30, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.34, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.37, kind = "line", k = "meteor", n = 2, gap = 200.0},
	{at = 0.41, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.44, kind = "stream", k = "imp", n = 6, gap = 100.0},
	{at = 0.48, kind = "line", k = "chest", n = 1, gap = 0.0},
	{at = 0.51, kind = "line", k = "imp", n = 6, gap = 96.0},
	{at = 0.54, kind = "snake", k = "", n = 12, gap = 58.0},
	{at = 0.57, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.60, kind = "line", k = "flame", n = 2, gap = 220.0},
	{at = 0.63, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.66, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.69, kind = "stream", k = "imp", n = 7, gap = 88.0},
	{at = 0.72, kind = "line", k = "meteor", n = 3, gap = 165.0},
	{at = 0.75, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.78, kind = "vee", k = "imp", n = 9, gap = 70.0},
	{at = 0.81, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.84, kind = "stream", k = "imp", n = 8, gap = 80.0},
	{at = 0.87, kind = "coins", k = "", n = 8, gap = 48.0},
	{at = 0.90, kind = "line", k = "imp", n = 8, gap = 78.0},
]

## 2구간 · 협곡 — **운석과 골렘이 주인공.** 단단한 것이 줄줄이 오므로
## 화력이 모자라면 앞이 막힌다. 부술 수는 있다.
const Z2 := [
	{at = 0.02, kind = "line", k = "meteor", n = 2, gap = 200.0},
	{at = 0.06, kind = "coins", k = "", n = 6, gap = 54.0},
	{at = 0.09, kind = "line", k = "golem", n = 2, gap = 210.0},
	{at = 0.13, kind = "stream", k = "imp", n = 5, gap = 116.0},
	{at = 0.16, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.19, kind = "line", k = "meteor", n = 3, gap = 165.0},
	{at = 0.23, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.26, kind = "line", k = "flame", n = 1, gap = 0.0},
	{at = 0.30, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.33, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.36, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.40, kind = "line", k = "meteor", n = 3, gap = 165.0},
	{at = 0.43, kind = "line", k = "chest", n = 1, gap = 0.0},
	{at = 0.46, kind = "stream", k = "imp", n = 6, gap = 100.0},
	{at = 0.49, kind = "snake", k = "", n = 11, gap = 60.0},
	{at = 0.52, kind = "line", k = "golem", n = 3, gap = 170.0},
	{at = 0.55, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.58, kind = "line", k = "flame", n = 2, gap = 220.0},
	{at = 0.61, kind = "line", k = "meteor", n = 4, gap = 140.0},
	{at = 0.64, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.67, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.70, kind = "line", k = "golem", n = 4, gap = 140.0},
	{at = 0.73, kind = "stream", k = "imp", n = 7, gap = 88.0},
	{at = 0.76, kind = "line", k = "meteor", n = 4, gap = 140.0},
	{at = 0.79, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.82, kind = "vee", k = "imp", n = 9, gap = 70.0},
	{at = 0.85, kind = "line", k = "golem", n = 4, gap = 140.0},
	{at = 0.88, kind = "coins", k = "", n = 8, gap = 48.0},
]

## 3구간 · 밤하늘 — **빠른 것과 쏘는 것.** 도깨비불이 위에서 곧장 떨어지고
## 마법구가 자리를 잡고 탄을 뿌린다. 운석은 없다 — 하늘이라 그럴 자리가 없다.
const Z3 := [
	{at = 0.02, kind = "line", k = "orb", n = 2, gap = 200.0},
	{at = 0.06, kind = "stream", k = "wisp", n = 6, gap = 88.0},
	{at = 0.09, kind = "coins", k = "", n = 7, gap = 50.0},
	{at = 0.12, kind = "line", k = "wyvern", n = 3, gap = 150.0},
	{at = 0.16, kind = "stream", k = "wisp", n = 7, gap = 80.0},
	{at = 0.19, kind = "line", k = "flame", n = 1, gap = 0.0},
	{at = 0.22, kind = "vee", k = "imp", n = 5, gap = 96.0},
	{at = 0.25, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.28, kind = "line", k = "orb", n = 3, gap = 160.0},
	{at = 0.31, kind = "snake", k = "", n = 12, gap = 58.0},
	{at = 0.34, kind = "stream", k = "wisp", n = 7, gap = 80.0},
	{at = 0.37, kind = "line", k = "wyvern", n = 4, gap = 128.0},
	{at = 0.40, kind = "line", k = "chest", n = 1, gap = 0.0},
	{at = 0.43, kind = "arc", k = "", n = 9, gap = 46.0},
	{at = 0.46, kind = "stream", k = "wisp", n = 8, gap = 74.0},
	{at = 0.49, kind = "line", k = "orb", n = 4, gap = 130.0},
	{at = 0.52, kind = "line", k = "flame", n = 2, gap = 220.0},
	{at = 0.55, kind = "vee", k = "imp", n = 7, gap = 84.0},
	{at = 0.58, kind = "stream", k = "wisp", n = 8, gap = 74.0},
	{at = 0.61, kind = "item", k = "", n = 1, gap = 0.0},
	{at = 0.64, kind = "line", k = "wyvern", n = 4, gap = 128.0},
	{at = 0.67, kind = "line", k = "orb", n = 4, gap = 130.0},
	{at = 0.70, kind = "stream", k = "wisp", n = 9, gap = 68.0},
	{at = 0.73, kind = "vee", k = "imp", n = 9, gap = 70.0},
	{at = 0.76, kind = "stream", k = "wisp", n = 9, gap = 68.0},
	{at = 0.79, kind = "line", k = "wyvern", n = 5, gap = 112.0},
	{at = 0.82, kind = "line", k = "orb", n = 4, gap = 130.0},
	{at = 0.85, kind = "coins", k = "", n = 8, gap = 48.0},
	{at = 0.88, kind = "stream", k = "wisp", n = 10, gap = 64.0},
]

const ZONE := [
	{name = "초원", table = Z1, sky = 0},
	{name = "협곡", table = Z2, sky = 1},
	{name = "밤하늘", table = Z3, sky = 2},
]

# ==================== 아이템 ====================

## **파워업 P 는 난수로 떨구지 않는다 — 거리마다 딱 하나씩 나온다.**
## 확률로 두면 운 좋은 판은 앞에서 만렙이 되고 운 나쁜 판은 끝까지 맨몸이라,
## 같은 거리가 판마다 다른 게임이 된다.
const POWER_FIRST := 110.0
const POWER_EVERY := 240.0
const POWER_FULL_GOLD := 40      ## 이미 만렙이면 금화로 바꿔 준다

const COIN_GOLD := 3
const COIN_SCORE := 2
const ITEM_R := 18.0
const MAGNET_BASE := 110.0       ## 금화가 끌려오기 시작하는 거리
const MAGNET_SPD := 660.0

## **판 안에서만 도는 아이템 넷**(원작의 듀얼샷 · 자석 · 하이퍼 플라이트 · 더블 스코어).
##
## 넷 다 **시간제**다. 영구히 붙는 것을 여기 두면 판 밖 강화(상점)와 구분이 사라진다.
## 웨이브 표의 `item` 자리에서 하나가 무작위로 나온다 — 어느 것이 나올지가
## 판마다 달라야 같은 구간이 매번 다르게 흘러간다.
const BUFF := [
	{id = "dual", name = "듀얼샷", dur = 9.0,
		desc = "브레스가 두 줄기로 나갑니다"},
	{id = "magnet", name = "자석", dur = 8.0,
		desc = "화면의 금화가 전부 끌려옵니다"},
	{id = "hyper", name = "하이퍼 플라이트", dur = 4.5,
		desc = "무적으로 돌진합니다. 스치는 적이 전부 터집니다"},
	{id = "double", name = "더블 스코어", dur = 12.0,
		desc = "점수가 두 배로 들어옵니다"},
]

const HYPER_SPEED := 2.6         ## 하이퍼 플라이트 동안의 스크롤 배율
const HYPER_DMG := 900.0         ## 스치는 적에게 주는 피해


static func buff(id: String) -> Dictionary:
	for b in BUFF:
		if String(b.id) == id:
			return b
	return {}

# ==================== 상점 (판 밖 강화) ====================
#
# **판 안 성장과 섞지 마라.**
#   판 안 = 파워업 P + 시간제 아이템 4종 (그 판에서만, 죽으면 사라짐)
#   판 밖 = 여기 (금화로 사고, 영원히 남음)

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
	## 원작의 하트. **셋이 상한이다** — 더 주면 부딪히는 것이 실수가 아니라
	## 자원 소모가 되어 긴장이 통째로 빠진다.
	{id = "heart", name = "하트", max = 3, base = 1500, mul = 3.2,
		desc = "부딪혀도 하트가 한 칸 깎일 뿐 죽지 않습니다. 하트가 없으면 즉사합니다."},
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


static func hearts() -> int:
	return Sv.level("heart")
