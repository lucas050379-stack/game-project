class_name AkD
extends RefCounted

## 잿빛 요새의 용병단 — 수치 전부(영웅 · 카드 · 몬스터 · 행동 카드 · 공격 수정 · 시나리오 지도).
##
## 규칙은 카드 구동 전술 던전 장르의 규칙 그대로이고, **영웅 · 카드 · 몬스터 · 시나리오 · 수치는 새로 짠 것**입니다
## (사용자 결정 11-09 — 아르카나 · 제국 연대기 · 붉은 별과 같은 선). 기획서: `docs/design/ashkeep.md`.
## **수치를 바꾸면 `tools/ashkeep_check.gd` 부터 돌리세요**(봇 영웅으로 시나리오마다 수백 판 — 난이도별 깨는 비율).
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

## 원소 — 0 불 · 1 땅 · 2 빛 · 3 어둠. 상태 0 없음 · 1 약함 · 2 강함.
const ELEM_NAME := ["불", "땅", "빛", "어둠"]
const ELEM_COL := [Color8(240, 110, 50), Color8(150, 110, 60), Color8(250, 230, 140), Color8(110, 70, 160)]

## 상태이상(키 → 이름)
const STATUS := {poison = "독", bleed = "출혈", stun = "기절", immob = "속박", muddle = "혼란", mark = "표식", inv = "투명", strong = "강화"}

## 영웅: [이름, 체력, 손패 한도, 색, 설명]
const HEROES := [
	["방패 파수꾼", 10, 10, Color8(90, 130, 200), "방어와 반격, 땅 원소. 동료 앞을 막는다"],
	["재 마녀", 6, 9, Color8(220, 100, 60), "불과 땅 원소로 범위 공격"],
	["그림자 척후", 8, 11, Color8(110, 80, 150), "동료와 적을 사이에 두면 강해지고 투명해진다"],
	["성가 치유사", 7, 10, Color8(230, 200, 110), "치유와 강화, 빛 원소"],
]

## 행동 칸 하나 = 단계 목록. 단계 키:
##   m 이동 · a 공격(r 사거리 0 근접, t 대상 수, aoe "adj" 이웃 전부 · "blast" 대상과 그 이웃, push · pull, eff [상태], flank 포위 보너스)
##   h 치유(hr 사거리 0 자기만, all 전원, cleanse 상태 지움) · s 방어(이번 라운드, hr 있으면 동료에게) · ret 반격(이번 라운드)
##   inf 원소 주입 · use 원소 소비(ub 소비하면 붙는 보너스 {a, h, eff}) · inv 투명 · strg 강화(hr) · xp 경험치
## 카드: [이름, 순서, 위 단계, 위가 소멸인가, 아래 단계, 아래가 소멸인가]
const CARDS := [
	[
		["굳건한 벽", 12, [{s = 2}], false, [{m = 2}], false],
		["방패 밀치기", 28, [{a = 3, r = 0, push = 1}], false, [{m = 3}], false],
		["마지막 방어선", 75, [{s = 3}, {ret = 2}, {xp = 1}], true, [{h = 3, hr = 2}], false],
		["도발의 함성", 20, [{a = 2, r = 0, aoe = "adj"}], false, [{m = 2}, {s = 1}], false],
		["강철 돌진", 45, [{m = 3}, {a = 3, r = 0}], false, [{m = 2}], false],
		["땅 고르기", 34, [{a = 3, r = 0}, {inf = 1}], false, [{m = 3}], false],
		["대지의 일격", 60, [{a = 4, r = 0, use = 1, ub = {a = 2, eff = ["stun"]}}], false, [{s = 2}, {inf = 1}], false],
		["방패 벽", 15, [{s = 1}, {ret = 1}], false, [{m = 3}], false],
		["기절 망치", 52, [{a = 2, r = 0, eff = ["stun"]}], false, [{m = 2}], false],
		["버티기", 70, [{h = 4, hr = 0}], false, [{m = 4}], false],
		["반격 자세", 25, [{ret = 3}], false, [{m = 2}], false],
		["성채의 맹세", 88, [{a = 6, r = 0}, {xp = 2}], true, [{m = 3}, {s = 1}], false],
	],
	[
		["재의 비", 58, [{a = 2, r = 3, aoe = "blast"}, {inf = 0}], false, [{m = 2}], false],
		["화산 분화", 82, [{a = 4, r = 3, aoe = "blast", use = 0, ub = {a = 2}}, {xp = 2}], true, [{m = 3}, {inf = 1}], false],
		["재 장막", 20, [{a = 2, r = 3, eff = ["poison"]}], false, [{m = 2}], false],
		["불씨 화살", 30, [{a = 3, r = 4}], false, [{m = 2}, {inf = 0}], false],
		["화염 고리", 65, [{a = 2, r = 0, aoe = "adj", use = 0, ub = {a = 2}}], false, [{m = 3}], false],
		["대지 가시", 40, [{a = 2, r = 3, eff = ["immob"]}, {inf = 1}], false, [{m = 2}], false],
		["잿불 손길", 10, [{a = 3, r = 0}], false, [{m = 4}], false],
		["불기둥", 72, [{a = 5, r = 3}, {xp = 1}], true, [{h = 2, hr = 0}], false],
		["재 바람", 15, [{a = 1, r = 4, t = 2}], false, [{m = 3}, {inv = 1}], false],
		["용암 웅덩이", 50, [{a = 3, r = 3, use = 1, ub = {a = 1, eff = ["bleed"]}}], false, [{m = 2}], false],
		["연기 걸음", 8, [{a = 2, r = 2}], false, [{m = 3}], false],
		["재생의 불", 90, [{h = 3, hr = 3}], false, [{inf = 0}, {inf = 1}, {xp = 1}], true],
	],
	[
		["등 뒤의 칼", 15, [{a = 3, r = 0, flank = 2}], false, [{m = 4}], false],
		["연기 속으로", 8, [{a = 2, r = 0}], false, [{m = 3}, {inv = 1}], false],
		["급소 찌르기", 64, [{a = 6, r = 0}, {xp = 2}], true, [{m = 2}], false],
		["단검 투척", 22, [{a = 2, r = 3, t = 2}], false, [{m = 3}], false],
		["그림자 걸음", 12, [{a = 2, r = 0}, {inf = 3}], false, [{m = 5}], false],
		["독 묻은 칼", 30, [{a = 2, r = 0, eff = ["poison"]}], false, [{m = 3}], false],
		["어둠 습격", 40, [{a = 3, r = 0, use = 3, ub = {a = 2}}], false, [{m = 4}], false],
		["출혈 베기", 35, [{a = 2, r = 0, eff = ["bleed"]}], false, [{m = 3}], false],
		["표식", 18, [{a = 1, r = 3, eff = ["mark"]}], false, [{m = 4}], false],
		["회피 기동", 5, [{s = 1}], false, [{m = 5}], false],
		["연속 베기", 45, [{a = 2, r = 0, t = 2}], false, [{m = 2}], false],
		["암살", 80, [{a = 4, r = 0, flank = 4}, {xp = 2}], true, [{m = 3}, {inf = 3}], false],
	],
	[
		["치유의 노래", 40, [{h = 4, hr = 3}], false, [{m = 3}], false],
		["축복", 35, [{strg = 1, hr = 3}], false, [{m = 2}], false],
		["새벽의 찬가", 90, [{h = 3, all = true}, {xp = 2}], true, [{m = 2}, {inf = 2}], false],
		["빛의 화살", 25, [{a = 2, r = 3}, {inf = 2}], false, [{m = 3}], false],
		["눈부신 빛", 30, [{a = 1, r = 2, eff = ["muddle"]}], false, [{m = 2}, {h = 1, hr = 0}], false],
		["정화", 50, [{h = 2, hr = 3, cleanse = true}], false, [{m = 3}], false],
		["성역", 60, [{s = 2, hr = 2}], false, [{m = 2}], false],
		["빛 폭발", 70, [{a = 3, r = 0, aoe = "adj", use = 2, ub = {a = 1}}], false, [{m = 3}], false],
		["기도", 15, [{h = 2, hr = 0}, {inf = 2}], false, [{m = 3}], false],
		["지팡이 일격", 20, [{a = 3, r = 0}], false, [{m = 3}], false],
		["희망의 빛", 55, [{h = 3, hr = 3, use = 2, ub = {h = 2}}], false, [{m = 2}], false],
		["기적", 85, [{h = 6, hr = 3}, {xp = 2}], true, [{m = 4}], false],
	],
]

## 몬스터: [이름, 체력(보통), 체력(정예), 이동, 공격, 사거리, 방어, 날기, 공격 상태, 반격, 색]
const MONSTERS := [
	["재바람 추종자", 5, 8, 2, 2, 0, 0, false, [], 0, Color8(150, 120, 110)],
	["굴뚝 궁수", 4, 6, 1, 2, 3, 0, false, [], 0, Color8(120, 140, 110)],
	["용암 굴착충", 7, 11, 1, 3, 0, 1, false, [], 0, Color8(180, 80, 50)],
	["잿불 정령", 3, 5, 3, 2, 0, 0, true, [], 0, Color8(250, 150, 60)],
	["무덤 파수병", 6, 9, 1, 3, 0, 2, false, [], 1, Color8(140, 140, 160)],
	["독안개 주술사", 4, 7, 2, 1, 4, 0, false, ["poison"], 0, Color8(110, 160, 90)],
	["표범 사냥개", 5, 8, 4, 2, 0, 0, false, [], 0, Color8(200, 160, 80)],
	["불배 큰수레", 9, 14, 2, 3, 0, 1, false, [], 0, Color8(160, 90, 70)],
	["봉인석", 6, 9, 0, 0, 0, 0, false, [], 0, Color8(170, 150, 220)],
	["재의 군주", 24, 24, 2, 4, 0, 1, false, [], 0, Color8(200, 60, 40)],
	["심연의 장인", 34, 34, 2, 4, 3, 1, false, ["poison"], 0, Color8(120, 60, 160)],
]
const SEAL := 8
## 1차에는 "카드를 잃어 피해 막기" 가 없어서 그 몫만큼 영웅 체력을 더 준다(봇 대전에서 첫 방에 체력 절반이 깎였다).
const HERO_HP_BONUS := 4
const MON_HP_K := 0.8          ## 몬스터 체력 배율(봇 대전 1차 조정)
const BOSSES := [9, 10]

## 몬스터 행동 카드 — 종류마다 6장 [순서, 이동 +, 공격 +, 덧붙임 {heal 동료, t 대상 수, aoe, eff, s 방어}].
## 공통 틀에 종류별 순서 차이(`INIT_OFF`)와 덧붙임(`EXTRA`)을 얹는다.
const ABILITY := [[20, 0, 0, {}], [35, 1, -1, {}], [48, 0, 1, {}], [62, -1, 2, {}], [28, 1, 0, {}], [75, 0, 0, {s = 1}]]
const INIT_OFF := [0, 6, 14, -8, 18, 10, -12, 16, 0, 4, 2]
const EXTRA := {1: {3: {t = 2}}, 5: {5: {heal = 2}}, 9: {2: {aoe = "adj"}, 4: {aoe = "adj"}}, 10: {3: {eff = ["stun"]}, 5: {heal = 4}}}

## 공격 수정 카드: 숫자는 더하기, "x2" 치명, "x0" 실패. 영웅 · 몬스터 같은 20장으로 시작.
const AMD := [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, 2, -2, "x2", "x0"]

# ==================== 시나리오 ====================
## 지도: 줄 문자열(odd-r 오프셋 — 홀수 줄이 반 칸 오른쪽). 소문자 a · b · c = 방 바닥, '+' = 문, 대문자 A · B · C = 그 방의 함정,
## x = 장애물(어느 방이든), 빈칸 = 벽. 스폰: [몬스터, 정예(0 · 1), 열, 줄](방은 그 칸의 글자). 웨이브: [라운드, 몬스터, 정예, 열, 줄].
const MAP2 := [
	"aaaaa bbbbb",
	"aaaaa bbbbb",
	"aaaaa bbbbb",
	"aaaaa+bbbbb",
	"aaaaa bbbbb",
	"aaaaa bbbbb",
	"aaaaa bbbbb",
]
const MAP3 := [
	"aaaa bbb ccc",
	"aaaa bbb ccc",
	"aaaa bbb ccc",
	"aaaa+bbb+ccc",
	"aaaa bbb ccc",
	"aaaa bbb ccc",
	"aaaa bbb ccc",
]
const MAP1 := [
	"aaaaaaaaa",
	"aaaaaaaaa",
	"aaaaaaaaa",
	"aaaaaaaaa",
	"aaaaaaaaa",
	"aaaaaaaaa",
	"aaaaaaaaa",
]

## [이름, 목표("all" 모두 처치 · "boss" 보스 처치 · "seal" 봉인석 · "survive" N라운드 버티기), 지도, 스폰, 시작 칸, 기본 레벨, 덧붙임 {rounds, waves, traps, obstacles}]
const SCENARIOS := [
	["잿빛 관문", "all", MAP2, [[0, 0, 3, 2], [0, 0, 3, 4], [1, 0, 4, 0], [0, 1, 8, 3], [1, 0, 10, 1], [1, 0, 10, 5]], [[0, 3], [0, 4]], 0, {}],
	["무너진 막사", "all", MAP2, [[6, 0, 3, 1], [6, 0, 3, 5], [0, 0, 4, 3], [6, 1, 8, 3], [0, 0, 9, 1], [0, 0, 9, 5]], [[0, 3], [0, 2]], 0, {obstacles = [[2, 3]]}],
	["봉인의 방", "seal", MAP2, [[8, 0, 3, 3], [2, 0, 2, 1], [8, 0, 8, 1], [8, 0, 8, 5], [3, 0, 9, 3], [3, 0, 7, 3]], [[0, 3], [0, 4]], 0, {traps = [[2, 5]]}],
	["포위된 망루", "survive", MAP1, [[0, 0, 0, 0], [0, 0, 8, 6]], [[4, 3], [4, 4]], 1, {rounds = 7, waves = [[3, 6, 0, 8, 0], [3, 1, 0, 0, 6], [5, 0, 1, 0, 3], [5, 6, 1, 8, 3]]}],
	["재의 군주", "boss", MAP2, [[0, 0, 3, 2], [0, 0, 3, 4], [9, 0, 9, 3], [4, 0, 7, 2]], [[0, 3], [0, 4]], 1, {}],
	["독안개 늪", "all", MAP3, [[5, 0, 3, 2], [6, 0, 3, 4], [5, 1, 7, 3], [2, 0, 6, 1], [3, 0, 10, 2], [3, 0, 10, 4]], [[0, 3], [0, 4]], 1, {traps = [[6, 5]]}],
	["무덤길", "all", MAP2, [[4, 0, 3, 2], [4, 0, 3, 4], [4, 1, 8, 3], [1, 0, 10, 1], [1, 0, 10, 5]], [[0, 3], [0, 4]], 1, {obstacles = [[2, 1], [2, 5]]}],
	["용암 갱도", "all", MAP2, [[2, 0, 3, 2], [2, 0, 3, 4], [3, 0, 4, 0], [7, 0, 8, 3], [3, 0, 9, 1], [3, 0, 9, 5]], [[0, 3], [0, 4]], 2, {traps = [[2, 3], [7, 1], [7, 5]]}],
	["요새 안뜰", "all", MAP3, [[0, 1, 3, 2], [0, 1, 3, 4], [1, 1, 7, 1], [6, 1, 7, 5], [7, 1, 10, 3]], [[0, 3], [0, 4]], 2, {obstacles = [[6, 3]]}],
	["심연의 장인", "boss", MAP2, [[4, 0, 3, 2], [4, 0, 3, 4], [5, 0, 4, 0], [10, 0, 9, 3], [3, 0, 8, 1], [3, 0, 8, 5]], [[0, 3], [0, 4]], 2, {}],
]

## 레벨 L 몬스터 보정: 체력 + L(정예 + 2L), 공격 + L/2(내림).
static func mon_stats(m: int, elite: bool, lv: int) -> Dictionary:
	var row: Array = MONSTERS[m]
	var boss := m in BOSSES
	var hp := int(row[2] if elite else row[1]) + (lv * (2 if elite else 1) if not boss else lv * 3)
	hp = maxi(2, roundi(hp * MON_HP_K))
	return {name = String(row[0]), hp = hp, move = int(row[3]), atk = int(row[4]) + lv / 2 + (1 if elite and not boss else 0),
			rng = int(row[5]), shield = int(row[6]) + (1 if elite and int(row[6]) > 0 else 0), fly = bool(row[7]), eff = row[8],
			ret = int(row[9]), col = row[10], boss = boss}


static func ability_deck(m: int) -> Array:
	var out := []
	var ex: Dictionary = EXTRA.get(m, {})
	for k in ABILITY.size():
		var a: Array = ABILITY[k]
		var extra: Dictionary = (a[3] as Dictionary).duplicate()
		if ex.has(k):
			extra.merge(ex[k], true)
		out.append({init = clampi(int(a[0]) + int(INIT_OFF[m]), 1, 99), dm = int(a[1]), da = int(a[2]), extra = extra})
	return out


static func card(h: int, k: int) -> Dictionary:
	var row: Array = CARDS[h][k]
	return {hero = h, id = h * 100 + k, name = String(row[0]), init = int(row[1]), top = row[2], top_lost = bool(row[3]),
			bot = row[4], bot_lost = bool(row[5])}


## odd-r 오프셋(열, 줄) → 축 좌표.
static func axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)


static func neighbors(c: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		out.append(c + d)
	return out


static func dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## 단계 하나 → [큰 글, 덧붙임]. 카드는 큰 글 한 줄 + 덧붙임 작은 줄로 그리고, 글(기록 · 도감)은 step_text 로 잇는다.
static func step_parts(s: Dictionary) -> Array:
	var main := ""
	var mods := []
	if s.has("m"):
		main = "이동 %d" % int(s.m)
	elif s.has("a"):
		main = "공격 %d" % int(s.a)
		if int(s.get("r", 0)) > 0:
			mods.append("사거리 %d" % int(s.r))
		if int(s.get("t", 1)) > 1:
			mods.append("대상 %d" % int(s.t))
		if s.get("aoe", "") == "adj":
			mods.append("이웃 전부")
		elif s.get("aoe", "") == "blast":
			mods.append("대상과 이웃")
		if s.has("push"):
			mods.append("밀기 %d" % int(s.push))
		if s.has("flank"):
			mods.append("포위 +%d" % int(s.flank))
		for e in s.get("eff", []):
			mods.append(String(STATUS.get(e, e)))
	elif s.has("h"):
		main = "회복 %d" % int(s.h)
		if s.get("all", false):
			mods.append("모두")
		elif int(s.get("hr", 0)) > 0:
			mods.append("사거리 %d" % int(s.hr))
		if s.get("cleanse", false):
			mods.append("상태 지움")
	elif s.has("s"):
		main = "방어 %d" % int(s.s)
		if s.has("hr"):
			mods.append("동료")
	elif s.has("ret"):
		main = "반격 %d" % int(s.ret)
	elif s.has("inf"):
		main = "%s 주입" % ELEM_NAME[int(s.inf)]
	elif s.has("inv"):
		main = "투명"
	elif s.has("strg"):
		main = "동료 강화"
	elif s.has("xp"):
		main = "경험 %d" % int(s.xp)
	if s.has("use"):
		var ub: Dictionary = s.ub
		var bonus := []
		if ub.has("a"):
			bonus.append("+%d" % int(ub.a))
		if ub.has("h"):
			bonus.append("회복 +%d" % int(ub.h))
		for e in ub.get("eff", []):
			bonus.append(String(STATUS.get(e, e)))
		mods.append("%s 쓰면 %s" % [ELEM_NAME[int(s.use)], " ".join(bonus)])
	return [main, ", ".join(mods)]


## 단계 하나를 글 한 줄로.
static func step_text(s: Dictionary) -> String:
	var p := step_parts(s)
	return String(p[0]) if String(p[1]) == "" else "%s (%s)" % p


static func half_text(steps: Array, lost: bool) -> String:
	var parts := []
	for s: Dictionary in steps:
		parts.append(step_text(s))
	return ", ".join(parts) + (" (소멸)" if lost else "")
