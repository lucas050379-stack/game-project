class_name D
extends RefCounted

## 수치는 전부 여기 모은다. 기체 · 적 · 웨이브 · 라운드 · 난이도가 한 파일에 있다.

# ==================== 화면 ====================

## 세로 플레이필드 폭. 가로 창 한가운데에 이 폭으로 두고 양옆은 패널이다.
## 세로 슈팅은 가로가 좁아야 탄을 피하는 맛이 산다 — 넓히면 그냥 걸어서 피해진다.
const PLAY_W := 384.0
const PANEL_MIN := 150.0

# ==================== 빌드 ====================

## **테스트 빌드에서만 켜지는 것**(라운드 선택 등).
##
## `export_presets.cfg` 의 "Windows Desktop Test" 프리셋이 `testmode` 기능 태그를
## exe 안에 박아 넣는다. 소스에서 바로 실행할 때(`run.bat`)는 디버그 빌드라 자동으로 켜진다.
## **일반 빌드에는 이 화면이 아예 안 나온다** — 테스트 편의를 배포판에 흘리지 않으려는 것.
static func test_build() -> bool:
	return OS.has_feature("testmode") or OS.is_debug_build()

# ==================== 난이도 ====================

## **곱하기 셋뿐이다 — 적 체력 · 적 탄 속도 · 적 탄 수.**
## 모든 라운드·모든 적에 똑같이 걸리므로 아래 "보스는 초로 정한다" 규칙을 건드리지 않는다.
## 라운드마다 다른 값을 주고 싶어지면 여기를 쓰지, 표를 두 개로 늘리지 않는다.
const DIFF := [
	{name = "보통", note = "처음이라면 여기", hp = 1.0, spd = 1.0, dense = 1.0},
	{name = "어려움", note = "탄이 빨라지고 촘촘해집니다", hp = 1.25, spd = 1.15, dense = 1.35},
	{name = "지옥", note = "탄막을 읽어야 넘어갑니다", hp = 1.6, spd = 1.3, dense = 1.8},
]

# ==================== 아군기 ====================

const POWER_MAX := 3
const LIVES := 3
const BOMBS := 2
const INVULN := 2.2
const FOCUS_MUL := 0.45

## **관통 탄이 같은 표적을 다시 때리기까지의 간격.**
##
## 이게 없으면 관통 빔이 보스에 겹쳐 있는 동안 **매 프레임** 피해가 들어간다
## (dmg 3 이면 초당 180). 실제로 보스가 2초 만에 녹았다. 관통은 "여러 마리를 뚫는 것"이지
## "한 마리를 60배로 때리는 것"이 아니다.
const REHIT := 0.12

## **만렙 기체가 보스에 붙어서 내는 초당 피해(실측).** 첫 체력을 잡을 때 쓰는 눈금이다.
##
## 다만 **보스가 클수록 실효 화력이 오른다** — 몸이 크면 관통 빔이 안에 오래 머물러
## 재타격을 더 받고, 퍼지는 탄도 더 많이 걸린다. 실제로 중간보스는 67, 두 배 큰
## 함선은 120 이 나왔다. 그래서 체력은 이 값으로 **곱해서 정하지 않고**, 아래 표에
## 직접 적고 `secs` 를 목표로 두어 soak 테스트가 검산하게 한다.
const REF_DPS := 62.0

## 기체 여섯. axis 가 파워업이 자라는 방향이고, 그게 곧 이 기체를 고르는 이유다.
const CRAFT := [
	{id = "P-01", name = "하야부사", axis = "관통 · 집중", speed = 250.0, hit = 3.0,
		basic = "앞으로 곧게 2발", bomb = "융단폭격", bomb_dur = 1.5,
		grow = "가운데로 모이면서 굵어지고, 끝에는 적을 뚫는 빔 한 줄기."},
	{id = "P-02", name = "라이트닝", axis = "확산", speed = 232.0, hit = 3.0,
		basic = "좌우 붐에서 평행하게 2발", bomb = "핵폭탄", bomb_dur = 1.7,
		grow = "옆으로 벌어집니다. 만렙은 폭을 그대로 둔 채 10발로 촘촘해집니다."},
	{id = "P-03", name = "커세어", axis = "화력 · 관통", speed = 218.0, hit = 3.2,
		basic = "굵은 한 줄기", bomb = "화염 방사", bomb_dur = 1.9,
		grow = "한 줄기가 계속 두꺼워집니다. 연사는 느리지만 보스에 붙으면 제일 빠릅니다."},
	{id = "P-04", name = "스핏파이어", axis = "유도", speed = 262.0, hit = 3.0,
		basic = "곧은 2발 + 유도탄 1", bomb = "낙뢰", bomb_dur = 1.6,
		grow = "유도탄이 1 → 6발. 겨냥을 안 해도 맞아서 피하는 데 집중할 수 있습니다."},
	{id = "P-05", name = "슈팅스타", axis = "편대", speed = 244.0, hit = 3.0,
		basic = "곧은 2발 + 옵션기 1대", bomb = "편대 돌격", bomb_dur = 1.5,
		grow = "옵션기가 1 → 4대. 화면에 내 편이 늘어나는 유일한 기체."},
	{id = "P-06", name = "신덴", axis = "파동", speed = 236.0, hit = 3.2,
		basic = "곧은 2발 + 파동 고리 1", bomb = "함포 사격", bomb_dur = 1.8,
		grow = "고리가 나아갈수록 커집니다. 멀리 있는 적일수록 넓게 훑습니다."},
]

# ==================== 적 ====================

## **특수 행동은 종류 번호가 아니라 art 로 가른다** — 번호로 비교해 두면 강화판을 늘릴 때
## 반드시 한 군데를 빠뜨린다.
## `move` 가 나는 방식이다. `ground` 는 지형에 붙어 함께 흘러가는 유닛 —
## 스스로 움직이지 않는 대신 단단하고, 지나가기 전에 처리해야 한다.
const ENEMY := {
	grunt = {art = "grunt", hp = 4, speed = 104.0, score = 120, fire = 1.5, r = 13.0,
		move = "wave", sz = 0},
	bomber = {art = "bomber", hp = 26, speed = 52.0, score = 800, fire = 1.0, r = 22.0,
		move = "straight", sz = 1},
	inter = {art = "inter", hp = 6, speed = 240.0, score = 200, fire = 2.4, r = 12.0,
		move = "swoop", sz = 0},
	turret = {art = "turret", hp = 12, speed = 0.0, score = 300, fire = 1.5, r = 14.0,
		move = "ground", sz = 1},
	tank = {art = "tank", hp = 26, speed = 0.0, score = 700, fire = 1.4, r = 19.0,
		move = "ground", sz = 2},
	tower = {art = "tower", hp = 16, speed = 0.0, score = 500, fire = 2.0, r = 15.0,
		move = "ground", sz = 2},
	## 호위기 — 전진익. 옆에서 크게 휘어 들어와 **가로로 가로지른다.**
	escort = {art = "escort", hp = 8, speed = 148.0, score = 260, fire = 1.7, r = 13.0,
		move = "arc", sz = 0},
	## 중무장기 — 내려와 **자리를 잡고 버틴다.** 고리 탄을 뿌려서 붙으면 위험하다.
	gunship = {art = "gunship", hp = 34, speed = 74.0, score = 950, fire = 1.7, r = 24.0,
		move = "hover", sz = 1},
}

## **지형이 흘러가는 속도. 땅에 붙은 것은 반드시 이 값으로 움직인다.**
##
## 지형과 거치 유닛의 속도를 따로 적어 두면 반드시 어긋난다 — 실제로 지형 74 · 유닛 58 이라
## 초당 16px 씩 미끄러져서 "포탑이 배경 위를 떠다니는" 느낌이 났다. 숫자는 하나여야 한다.
## 물결·구름 같은 잔무늬만 이 값에 배수를 곱해 다른 층으로 흘린다.
const SCROLL := 74.0

## **적 탄 세 종류. 크기가 다르면 속도도 달라야 한다** — 굵고 느린 것은 자리를 막고,
## 가늘고 빠른 것은 반응을 시험한다. 같은 속도로 크기만 바꾸면 큰 탄이 그냥 불합리해진다.
const EB := [
	{r = 3.2, spd = 1.32},
	{r = 4.8, spd = 1.00},
	{r = 7.6, spd = 0.66},
]
const E_BULLET_SPD := 170.0

# ==================== 웨이브 ====================

## **라운드마다 표가 따로다.** 예전에는 표 하나를 여섯 라운드가 나눠 써서 "라운드가 바꾸는
## 것은 tier 하나"라는 검산이 쉬웠는데, 그러다 보니 여섯 판이 똑같이 흘러갔다.
## 지금은 라운드마다 성격을 준다 — 해상은 무난하게, 상륙과 사막은 거치 유닛 위주,
## 상공은 **비행기만** 여러 종류, 도시는 빠른 요격기, 최종은 전부.
##
## 대신 **난이도가 저절로 맞지 않는다.** 표를 고쳤으면 soak 으로 보스 초를 다시 재고,
## 아래 `load` 주석에 적힌 대략의 물량을 비슷하게 유지하라. 라운드 사이가 크게 벌어지면
## 그건 난이도 곡선이 아니라 그냥 어떤 라운드가 망가진 것이다.
##
## at 은 라운드 진행도(0~1). 0.46 에 중간보스, 0.92 에 라운드 보스가 들어온다.
const MIDBOSS_AT := 0.46
const BOSS_AT := 0.92

## 1라운드 · 해상 — 기본형. 잡졸과 폭격기, 배에 얹힌 포탑 조금.
const W1 := [
	{at = 0.00, kind = "line", k = "grunt", n = 5, gap = 46.0},
	{at = 0.05, kind = "line", k = "grunt", n = 6, gap = 44.0},
	{at = 0.09, kind = "spot", k = "turret", n = 2, gap = 140.0},
	{at = 0.13, kind = "dive", k = "inter", n = 3, gap = 96.0},
	{at = 0.18, kind = "line", k = "grunt", n = 7, gap = 40.0},
	{at = 0.23, kind = "pair", k = "bomber", n = 2, gap = 150.0},
	{at = 0.28, kind = "spot", k = "turret", n = 3, gap = 110.0},
	{at = 0.33, kind = "line", k = "grunt", n = 7, gap = 40.0},
	{at = 0.38, kind = "dive", k = "inter", n = 4, gap = 84.0},
	{at = 0.43, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.58, kind = "pair", k = "bomber", n = 3, gap = 118.0},
	{at = 0.63, kind = "spot", k = "tank", n = 2, gap = 130.0},
	{at = 0.68, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.73, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.78, kind = "spot", k = "turret", n = 3, gap = 110.0},
	{at = 0.83, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.88, kind = "pair", k = "bomber", n = 3, gap = 118.0},
]

## 2라운드 · 상륙 — 거치 유닛이 주인공. 전차와 미사일탑이 줄줄이 올라온다.
const W2 := [
	{at = 0.00, kind = "spot", k = "turret", n = 3, gap = 104.0},
	{at = 0.05, kind = "line", k = "grunt", n = 6, gap = 44.0},
	{at = 0.10, kind = "spot", k = "tank", n = 2, gap = 130.0},
	{at = 0.15, kind = "spot", k = "tower", n = 2, gap = 150.0},
	{at = 0.20, kind = "line", k = "grunt", n = 7, gap = 40.0},
	{at = 0.25, kind = "spot", k = "tank", n = 3, gap = 108.0},
	{at = 0.30, kind = "pair", k = "bomber", n = 2, gap = 150.0},
	{at = 0.35, kind = "spot", k = "turret", n = 4, gap = 84.0},
	{at = 0.40, kind = "spot", k = "tower", n = 3, gap = 112.0},
	{at = 0.58, kind = "spot", k = "tank", n = 3, gap = 108.0},
	{at = 0.63, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.68, kind = "spot", k = "tower", n = 3, gap = 112.0},
	{at = 0.72, kind = "dive", k = "inter", n = 4, gap = 84.0},
	{at = 0.77, kind = "spot", k = "tank", n = 4, gap = 88.0},
	{at = 0.82, kind = "spot", k = "turret", n = 4, gap = 84.0},
	{at = 0.87, kind = "pair", k = "bomber", n = 3, gap = 118.0},
]

## 3라운드 · 상공 — **거치 유닛이 없다. 대신 비행기가 다섯 종류 전부 나온다.**
## 구름 위라서 땅에 붙은 것이 있을 수가 없다 — 그 자리를 기체 종류로 메운다.
const W3 := [
	{at = 0.00, kind = "line", k = "grunt", n = 6, gap = 44.0},
	{at = 0.04, kind = "arc", k = "escort", n = 4, gap = 70.0},
	{at = 0.09, kind = "dive", k = "inter", n = 4, gap = 84.0},
	{at = 0.13, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.17, kind = "pair", k = "gunship", n = 1, gap = 0.0},
	{at = 0.22, kind = "arc", k = "escort", n = 5, gap = 62.0},
	{at = 0.26, kind = "pair", k = "bomber", n = 2, gap = 150.0},
	{at = 0.31, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.35, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.40, kind = "pair", k = "gunship", n = 2, gap = 150.0},
	{at = 0.57, kind = "arc", k = "escort", n = 6, gap = 56.0},
	{at = 0.61, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.65, kind = "pair", k = "gunship", n = 2, gap = 150.0},
	{at = 0.70, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.74, kind = "arc", k = "escort", n = 6, gap = 56.0},
	{at = 0.79, kind = "pair", k = "bomber", n = 3, gap = 118.0},
	{at = 0.84, kind = "dive", k = "inter", n = 6, gap = 62.0},
	{at = 0.88, kind = "pair", k = "gunship", n = 2, gap = 150.0},
]

## 4라운드 · 사막 — 지평선이 넓다. 거치 유닛이 많고 호위기가 섞인다.
const W4 := [
	{at = 0.00, kind = "spot", k = "turret", n = 3, gap = 104.0},
	{at = 0.05, kind = "arc", k = "escort", n = 4, gap = 70.0},
	{at = 0.10, kind = "spot", k = "tower", n = 3, gap = 112.0},
	{at = 0.15, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.20, kind = "spot", k = "tank", n = 3, gap = 108.0},
	{at = 0.25, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.30, kind = "spot", k = "turret", n = 4, gap = 84.0},
	{at = 0.35, kind = "arc", k = "escort", n = 5, gap = 62.0},
	{at = 0.40, kind = "spot", k = "tower", n = 4, gap = 90.0},
	{at = 0.57, kind = "spot", k = "tank", n = 4, gap = 88.0},
	{at = 0.62, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.66, kind = "pair", k = "gunship", n = 2, gap = 150.0},
	{at = 0.71, kind = "spot", k = "turret", n = 5, gap = 70.0},
	{at = 0.76, kind = "arc", k = "escort", n = 6, gap = 56.0},
	{at = 0.81, kind = "spot", k = "tower", n = 4, gap = 90.0},
	{at = 0.86, kind = "spot", k = "tank", n = 4, gap = 88.0},
]

## 5라운드 · 요격 — 빠른 것 위주. 요격기가 끊이지 않고 들어온다.
const W5 := [
	{at = 0.00, kind = "dive", k = "inter", n = 4, gap = 84.0},
	{at = 0.04, kind = "line", k = "grunt", n = 7, gap = 40.0},
	{at = 0.08, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.13, kind = "spot", k = "turret", n = 3, gap = 104.0},
	{at = 0.17, kind = "arc", k = "escort", n = 5, gap = 62.0},
	{at = 0.22, kind = "dive", k = "inter", n = 6, gap = 62.0},
	{at = 0.27, kind = "spot", k = "tower", n = 3, gap = 112.0},
	{at = 0.31, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.36, kind = "dive", k = "inter", n = 6, gap = 62.0},
	{at = 0.41, kind = "pair", k = "gunship", n = 2, gap = 150.0},
	{at = 0.57, kind = "dive", k = "inter", n = 6, gap = 62.0},
	{at = 0.61, kind = "spot", k = "tank", n = 3, gap = 108.0},
	{at = 0.66, kind = "arc", k = "escort", n = 6, gap = 56.0},
	{at = 0.70, kind = "dive", k = "inter", n = 7, gap = 54.0},
	{at = 0.75, kind = "line", k = "grunt", n = 10, gap = 34.0},
	{at = 0.80, kind = "spot", k = "turret", n = 5, gap = 70.0},
	{at = 0.85, kind = "dive", k = "inter", n = 7, gap = 54.0},
	{at = 0.89, kind = "pair", k = "gunship", n = 2, gap = 150.0},
]

## 6라운드 · 최종 — 전부 나온다. 쉬는 구간이 거의 없다.
const W6 := [
	{at = 0.00, kind = "line", k = "grunt", n = 8, gap = 38.0},
	{at = 0.04, kind = "spot", k = "turret", n = 4, gap = 84.0},
	{at = 0.08, kind = "dive", k = "inter", n = 5, gap = 72.0},
	{at = 0.12, kind = "arc", k = "escort", n = 5, gap = 62.0},
	{at = 0.16, kind = "spot", k = "tank", n = 3, gap = 108.0},
	{at = 0.20, kind = "pair", k = "gunship", n = 2, gap = 150.0},
	{at = 0.25, kind = "line", k = "grunt", n = 9, gap = 36.0},
	{at = 0.29, kind = "spot", k = "tower", n = 4, gap = 90.0},
	{at = 0.33, kind = "dive", k = "inter", n = 6, gap = 62.0},
	{at = 0.37, kind = "arc", k = "escort", n = 6, gap = 56.0},
	{at = 0.41, kind = "pair", k = "bomber", n = 3, gap = 118.0},
	{at = 0.56, kind = "spot", k = "tank", n = 4, gap = 88.0},
	{at = 0.60, kind = "dive", k = "inter", n = 7, gap = 54.0},
	{at = 0.64, kind = "pair", k = "gunship", n = 3, gap = 118.0},
	{at = 0.68, kind = "line", k = "grunt", n = 10, gap = 34.0},
	{at = 0.72, kind = "spot", k = "turret", n = 5, gap = 70.0},
	{at = 0.76, kind = "arc", k = "escort", n = 7, gap = 50.0},
	{at = 0.80, kind = "spot", k = "tower", n = 5, gap = 76.0},
	{at = 0.84, kind = "dive", k = "inter", n = 7, gap = 54.0},
	{at = 0.88, kind = "pair", k = "gunship", n = 3, gap = 118.0},
]

const WAVE := [W1, W2, W3, W4, W5, W6]

# ==================== 라운드 ====================

## **라운드가 바꾸는 것은 `tier` 하나뿐입니다.** 잡졸 체력과 적 탄 수에만 걸리고,
## 보스 체력은 보스마다 따로 적습니다(보스는 크기에 따라 실효 화력이 달라서
## 배율로 내면 길이가 제멋대로가 됩니다).
##
## **여기에 두 번째 통로를 만들지 마세요** — 스폰 간격이나 웨이브 수를 라운드마다
## 또 바꾸면 그때부터는 난이도를 검산할 수 없습니다.
const ROUND := [
	{time = 110.0, boss = "battleship", name = "1라운드 · 해상", tier = 1.00, land = "sea", base = "sea"},
	{time = 115.0, boss = "landfort", name = "2라운드 · 상륙", tier = 1.16, land = "shore", base = "land"},
	{time = 120.0, boss = "carrier", name = "3라운드 · 상공", tier = 1.32, land = "cloud", base = "air"},
	{time = 125.0, boss = "disc", name = "4라운드 · 사막", tier = 1.48, land = "desert", base = "land"},
	{time = 130.0, boss = "robot", name = "5라운드 · 요격", tier = 1.66, land = "city", base = "land"},
	{time = 140.0, boss = "fortress", name = "6라운드 · 최종", tier = 1.86, land = "steel", base = "land"},
]

## **보스는 체력이 아니라 「몇 초 버티는가」로 정한다.**
##
## `hp` 가 실제 값이고 `secs` 는 **목표**다. 발사 패턴이나 판정 상자를 만졌으면
## soak 테스트를 돌려 찍히는 초가 `secs` 근처인지 보고 `hp` 를 다시 맞춘다.
## 눈대중으로 체력만 넣으면 패턴을 손볼 때마다 보스 길이가 조용히 무너진다.
##
##     godot --headless --path . --fixed-fps 60 --quit-after 12000 -- --autoplay
##
## 마지막 실측: 중간보스 14.7초 · 함선 34.2초(체력 4092) → 40초에 맞춰 4800 으로 올림.
const MIDBOSS := {hp = 810.0, secs = 12.0, score = 5000, r = Vector2(48.0, 42.0)}

## 보스 여섯. `r` 은 판정 상자 반지름(배율 적용 전)이고 **그림 크기와 맞춰야** 합니다 —
## 상자가 그림보다 좁으면 탄이 옆으로 다 새서 설계보다 훨씬 오래 걸립니다.
const BOSS := {
	battleship = {hp = 3900.0, secs = 30.0, score = 20000, scale = 0.66,
		r = Vector2(38.0, 150.0), name = "초거대 함선 「해룡」", pname = "주포",
		parts = [Vector2(0, 96), Vector2(0, 42), Vector2(0, 12)]},
	landfort = {hp = 3825.0, secs = 33.0, score = 26000, scale = 0.72,
		r = Vector2(100.0, 95.0), name = "육상 요새 「철갑」", pname = "궤도",
		parts = [Vector2(-84, 6), Vector2(84, 6)]},
	carrier = {hp = 3490.0, secs = 35.0, score = 32000, scale = 0.62,
		r = Vector2(142.0, 92.0), name = "공중 항모 「운룡」", pname = "발진구",
		parts = [Vector2(-84, 76), Vector2(-18, 76), Vector2(48, 76), Vector2(114, 76)]},
	disc = {hp = 4150.0, secs = 35.0, score = 38000, scale = 0.66,
		r = Vector2(122.0, 122.0), name = "시제 원반기 「환월」", pname = "방출구",
		parts = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]},
	robot = {hp = 3740.0, secs = 36.0, score = 44000, scale = 0.68,
		r = Vector2(92.0, 120.0), name = "변신 로봇 「강신」", pname = "팔",
		parts = [Vector2(-70, 40), Vector2(70, 40)]},
	fortress = {hp = 5630.0, secs = 46.0, score = 60000, scale = 0.62,
		r = Vector2(150.0, 118.0), name = "최종 요새 「천성」", pname = "발전기",
		parts = [Vector2(-124, -46), Vector2(124, -46), Vector2(-96, 64), Vector2(96, 64)]},
}

## 보스가 절반 이하로 깎이면 2페이즈 — 발사 간격이 이만큼 줄고 탄이 는다.
## 보스는 **끝까지 같은 속도로 때리면 지루하다**. 마지막 20초가 제일 위험해야 한다.
const BOSS_RAGE_CD := 0.55
const BOSS_RAGE_ADD := 4


# ==================== 아이템 ====================

## **P 는 난수로 떨구지 않는다 — 진행 구간마다 딱 하나씩 나온다.**
##
## 확률로 두면 운 좋은 판은 앞에서 만렙이 되고 운 나쁜 판은 끝까지 맨몸이라,
## 같은 라운드가 판마다 다른 게임이 된다. 여기 적힌 진행도를 지나면 **다음에 죽는 적이**
## 하나를 떨어뜨린다. 자리는 여전히 싸움에 따라 달라지고 개수만 못 박히는 셈이다.
##
## 앞 셋은 촘촘히 둬서 초반에 화력을 갖추게 하고(초반이 맨몸이면 그냥 힘들기만 하다),
## 나머지는 넓게 흩어 **죽은 뒤 회복용**으로 쓴다.
const POWER_AT := [0.03, 0.09, 0.16, 0.28, 0.40, 0.55, 0.68, 0.80, 0.90]
const POWER_FULL_SCORE := 1000   ## 이미 만렙이면 점수로 바꿔 준다

## **봄은 난수로 나옵니다 — P 와 반대입니다.**
## P 는 화력이라 판마다 같아야 하지만, 봄은 "운 좋게 하나 더 생긴 여유"라서
## 어쩌다 나오는 편이 낫습니다. 확정으로 주면 위급할 때 아끼는 긴장이 사라집니다.
## **봄은 화면을 실제로 지워야 한다.** 조금씩 갉는 정도면 위급할 때 눌러도 살아남지 못해서
## 있으나 마나가 된다. 잡졸은 한 번에 쓸고, 보스에게도 한 입 분량이 들어간다.
const BOMB_DPS := 260.0        ## 잡졸에게 초당
const BOMB_BOSS_DPS := 380.0   ## 보스에게 초당
const BOMB_CLEAR := 0.75       ## 이 비율까지는 적 탄이 계속 지워진다
const BOMB_CHANCE := 0.014
const BOMBS_MAX := 4
const BOMB_FULL_SCORE := 2000
const ITEM_FALL := 62.0
const ITEM_MAGNET := 46.0

# ==================== 점수 ====================

## 부위를 부수면 주는 점수. **부순 것이 화면에 남는 보상**이라 값이 커도 된다.
const PART_SCORE := 2500

const EXTEND_AT := 200000
