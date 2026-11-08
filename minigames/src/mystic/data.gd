class_name MsD
extends RefCounted

## 비술난무 — 수치는 전부 여기. 세상은 논리 해상도 426×240, 1 = 화면 픽셀 한 칸(가로 화면에서 3배로 키워 그린다).
## 계산 쪽(MsWorld · MsCmd)이 이 파일만 보므로 그리기 · 소리 · 오토로드를 부르지 마세요 — 헤드리스 검사가 이걸 읽습니다.

const VIEW_W := 426
const VIEW_H := 240
const GROUND := 206.0          ## 땅 높이(발 y)
const GRAV := 900.0

# ---------- 주인공 ----------
const HERO_HP := 120.0
const HERO_SPEED := 74.0
const JUMP_V := -300.0
const MP_MAX := 100.0
const MP_PER_HIT := 3.0        ## 때릴 때마다 — 콤보가 길면 더 찬다(MP_COMBO)
const MP_COMBO := 0.25         ## 콤보 1 당 한 대에 더 붙는 MP
const COMBO_KEEP := 1.3        ## 마지막 타격 뒤 이 초가 지나면 콤보가 끊긴다
const HIT_STOP := 0.06         ## 맞힐 때 세상이 멈칫하는 시간(무거운 타격은 hit_stop 을 따로)
const INVULN := 0.8            ## 맞은 뒤 무적
const AIR_HITS := 6            ## 한 번 뜬 동안 공중 베기 횟수 상한(무한 띄우기 방지)
const TOUCH_MP_K := 1.25       ## 터치의 기술 단추로 쓰면 MP 를 이만큼 더 쓴다(커맨드로 쓰는 쪽에 보상)

## 동작 하나 = 길이 · 공격 판정. hit 는 [시작, 끝, 앞으로 x, 위로 y(발 기준 음수), 폭, 높이, 피해, 종류, fx].
## 종류: "hit" 경직 · "launch" 띄우기 · "air" 공중에 붙잡기 · "knock" 날려 보내기 · "down" 바로 넘어뜨림.
## 판정은 애니메이션 프레임이 아니라 시간으로 잰다 — 그림을 다시 구워도 손맛이 안 바뀐다.
const MOVES := {
	"atk1": {dur = 0.26, next = 0.14, hit = [0.06, 0.13, 6, -34, 30, 30, 9.0, "hit", ""]},   # 맨손 — 궤적 없이 맞은 자리 불꽃만
	"atk2": {dur = 0.26, next = 0.14, hit = [0.06, 0.13, 6, -40, 30, 36, 10.0, "hit", ""]},
	"atk3": {dur = 0.38, next = 0.30, hit = [0.08, 0.16, 4, -46, 30, 46, 12.0, "launch", "fx_launch"]},
	"air": {dur = 0.24, next = 0.12, hit = [0.04, 0.12, 2, -40, 32, 40, 8.0, "air", ""]},
	"dash": {dur = 0.46, mp = 20.0, hit = [0.10, 0.30, 0, -36, 40, 32, 22.0, "knock", ""], move = 260.0},
	"rise": {dur = 0.50, mp = 25.0, hit = [0.08, 0.36, -12, -64, 40, 66, 7.0, "launch", "fx_rise"], multi = 0.08, lift = -330.0},
	"wave": {dur = 0.44, mp = 20.0, shot = {at = 0.12, speed = 170.0, dmg = 26.0, kind = "knock", fx = "fx_orb"}},
	"stomp": {dur = 0.52, mp = 35.0, hit = [0.12, 0.24, -60, -24, 120, 26, 28.0, "launch", "fx_stomp"]},
	"dive": {dur = 0.40, mp = 25.0, hit = [0.06, 0.40, -6, -30, 30, 34, 24.0, "down", "fx_dive"], dive = 420.0},
}
## 커맨드 — 방향은 바라보는 쪽 기준(F 앞 · B 뒤 · U 위 · D 아래). 긴 것부터 맞춰 본다.
const CMDS := [
	{seq = "FBF", move = "dash"},
	{seq = "UU", move = "rise"},
	{seq = "DF", move = "wave"},
	{seq = "DD", move = "stomp", ground = true},
	{seq = "DD", move = "dive", air = true},
]
const CMD_WINDOW := 0.45       ## 커맨드 입력 사이 최대 간격 합(첫 방향 ~ 공격 버튼)
const SKILL_ORDER := ["dash", "rise", "wave", "stomp", "dive"]
const SKILL_NAME := {"dash": "돌진 베기", "rise": "승천 회오리", "wave": "파동 장풍", "stomp": "땅 찍기", "dive": "낙뢰 내리꽂기"}
const SKILL_KEYS := {"dash": "앞 뒤 앞 Z", "rise": "위 위 Z", "wave": "아래 앞 Z", "stomp": "아래 아래 Z", "dive": "공중 아래 아래 Z"}

# ---------- 적 ----------
## art 는 시트 이름("hero" 면 주인공 시트를 색만 바꿔 씀). fly 는 공중에 떠다님.
## atk = [사거리, 예비 동작 초, 판정 지속, 피해, 쿨다운]. 예비 동작 없이 나가는 공격은 두지 않습니다.
const ENEMY := {
	"soldier": {hp = 46.0, speed = 38.0, w = 12, h = 34, art = "hero", tint = Color(1.0, 0.55, 0.5), atk = [26, 0.45, 0.12, 9.0, 1.2], score = 100},
	"slime": {hp = 30.0, speed = 30.0, w = 16, h = 14, art = "en_slime", atk = [18, 0.40, 0.15, 7.0, 1.4], score = 60},
	"bat": {hp = 22.0, speed = 54.0, w = 14, h = 10, art = "en_bat", fly = 46.0, atk = [16, 0.35, 0.12, 6.0, 1.3], score = 70},
	"ghost": {hp = 40.0, speed = 28.0, w = 14, h = 20, art = "en_ghost", fly = 30.0, atk = [22, 0.50, 0.20, 10.0, 1.6], score = 120},
	"skull": {hp = 34.0, speed = 46.0, w = 14, h = 14, art = "en_skull", fly = 52.0, atk = [20, 0.40, 0.14, 9.0, 1.3], score = 110},
}
const HIT_STUN := 0.32
const DOWN_TIME := 0.7
const GETUP_INVULN := 0.4
const LAUNCH_V := -280.0
const AIR_V := -110.0          ## 공중 베기에 맞으면 다시 이만큼 튀어 오른다(붙잡기)
const KNOCK_V := Vector2(170, -150)

# ---------- 보스 ----------
## 큰 병사. 공격 셋 — 경고 모양이 서로 달라야 한다(앞 띠 · 땅 원 · 날아오는 구).
## 방향은 예비 동작을 시작할 때 정하고 안 고친다.
const BOSS := [
	{name = "칼날의 수문장", hp = 380.0, tint = Color(0.6, 0.75, 1.0), speed = 34.0},
	{name = "검은 숲의 망령기사", hp = 480.0, tint = Color(0.6, 1.0, 0.6), speed = 38.0},
	{name = "성의 마검왕", hp = 600.0, tint = Color(1.0, 0.45, 0.45), speed = 42.0},
]
const BOSS_SCALE := 1.6
const BOSS_W := 20
const BOSS_H := 56
## [이름, 예비 동작, 지속, 피해, 쿨다운]
const BOSS_ATK := {
	"slash": {cast = 0.7, act = 0.18, dmg = 16.0, cd = 1.2, range = 52.0},
	"slam": {cast = 0.9, act = 0.25, dmg = 20.0, cd = 1.8, r = 40.0},
	"orb": {cast = 0.8, act = 0.0, dmg = 14.0, cd = 1.6, speed = 120.0},
}
const BOSS_STAGGER := 60.0     ## 이만큼 맞으면 휘청(띄우기는 안 됨 — 보스는 공중에 안 뜬다)

# ---------- 스테이지 ----------
## 스테이지 = 구간 셋. 구간 = 적 웨이브 목록(차례로 나옴) [[종류, 수], ...]. 마지막 구간 끝에 보스.
## 한 구간의 폭은 화면 하나(VIEW_W). 다 쓰러뜨리면 다음 구간으로 넘어갈 수 있다.
const STAGES := [
	{name = "황혼의 숲", sky = [Color8(52, 38, 78), Color8(150, 76, 96), Color8(236, 150, 98)], hill = Color8(40, 30, 56), ground = Color8(48, 64, 52),
		sections = [[["soldier", 2], ["slime", 3]], [["slime", 2], ["soldier", 2], ["bat", 2]], [["soldier", 3], ["bat", 3]]]},
	{name = "달빛 동굴", sky = [Color8(14, 18, 36), Color8(28, 40, 70), Color8(52, 76, 110)], hill = Color8(22, 26, 46), ground = Color8(46, 48, 66),
		sections = [[["bat", 3], ["slime", 3]], [["ghost", 2], ["soldier", 3]], [["ghost", 3], ["bat", 3], ["slime", 2]]]},
	{name = "마검의 성", sky = [Color8(20, 8, 20), Color8(70, 18, 34), Color8(150, 40, 40)], hill = Color8(36, 16, 30), ground = Color8(60, 44, 50),
		sections = [[["soldier", 3], ["skull", 2]], [["skull", 3], ["ghost", 2], ["soldier", 2]], [["soldier", 4], ["skull", 3], ["ghost", 2]]]},
]
## 방 모양 — 한 화면이 방 하나(화면이 따라 흐르지 않고 한 칸씩 넘어간다, 사용자 결정 11-08).
## ground = 땅 꺾은선 [[x, 발 y], ...](0 ~ VIEW_W 를 덮어야 함, 언덕은 경사로), plats = 돌 발판 [x0, x1, 윗면 y, 기둥].
## **발판 높이는 바로 밑 땅에서 점프 한 번(JUMP_V 로 약 50px) 안**이어야 합니다 — 넘으면 못 올라가는 장식이 됩니다.
## 발판은 아래에서 뚫고 올라가고, 떨어질 때만 섭니다. ↓ + 점프로 내려옵니다.
const ROOMS := [
	{ground = [[0, 206], [426, 206]], plats = [[150, 276, 166, true]]},
	{ground = [[0, 190], [64, 190], [96, 206], [330, 206], [362, 190], [426, 190]], plats = [[140, 286, 164, true]]},
	{ground = [[0, 206], [150, 206], [210, 184], [426, 184]], plats = [[44, 120, 168, true], [290, 380, 144, false]]},
	{ground = [[0, 180], [80, 180], [128, 206], [298, 206], [346, 180], [426, 180]], plats = [[176, 250, 168, true]]},
	{ground = [[0, 196], [120, 206], [300, 206], [426, 190]], plats = [[30, 100, 156, false], [180, 246, 168, true], [326, 400, 150, false]]},
]
const BOSS_ROOM := {ground = [[0, 206], [426, 206]], plats = [[36, 112, 168, true], [314, 390, 168, true]]}


static func room_of(stage: int, sec: int) -> Dictionary:
	return ROOMS[(stage * 2 + sec) % ROOMS.size()]


const WAVE_GAP := 1.2          ## 앞 웨이브가 몇 마리 이하로 줄면 다음이 온다
const WAVE_NEXT_AT := 1        ## 남은 적이 이 수 이하면 다음 웨이브
const MAX_ON_SCREEN := 7
