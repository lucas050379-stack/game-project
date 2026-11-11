class_name BbD
extends RefCounted

## 물거품처럼 사라져줘 표 — 판 · 크기 · 물리 · 악당 · 점수(기획서 docs/design/bubble.md). 그리기를 모른다.
## 판은 **고전 거품 아케이드의 비율**을 따른다: 4:3 한 화면, 8px 타일 32 × 26 칸(양옆 벽 두 칸, 바닥 · 천장 한 줄),
## 캐릭터 · 악당은 2 × 2 칸, 층 사이는 5 칸(점프 한 번에 위층, 촘촘한 판만 4 칸), 바닥 · 천장 가운데 구멍으로 위아래가 이어진다.
## 우리 화면(1280×720)에는 칸 하나 26px — 판 832 × 676 을 가운데에, 양옆은 1P · 2P 글자판.

const T := 26.0                  ## 칸 하나(px)
const COLS := 32
const ROWS := 26
const FIELD := Vector2(COLS * T, ROWS * T)   ## 832 × 676
const ORIGIN := Vector2(224.0, 40.0)        ## 판의 왼쪽 위(화면)
const LEVELS := 50
const LIVES := 3
const HOLE := [13, 18]           ## 바닥 · 천장 구멍(칸, 양 끝 포함) — 떨어지면 위에서 나온다

# 물리(px · 초) — 고전 아케이드의 "한 번에 4칸 위로 · 걷기 빠르게 · 천천히 떨어짐"
const WALK := 190.0
const JUMP_V := 615.0
const GRAVITY := 1300.0          ## 꼭대기 높이 = 615² / 2600 = 145px(5.6칸) — 층 사이 5 칸(11-11, 예전 560 · 4.6칸 · 층 사이 4 칸)
const FALL_MAX := 300.0          ## 떨어지는 빠르기 끝(고전 아케이드처럼 천천히)
const BODY := Vector2(2.0 * T, 2.0 * T)    ## 몸(폭, 키) — 벽 · 천장에 닿는 상자, 발밑이 기준. 고전 아케이드처럼 2 × 2 칸(11-11, 예전 1.5 × 1.75)
const FOOT := 0.6 * T                       ## 발밑 — 이 폭 아래에 발판이 있어야 선다. 몸은 2 칸이어도 1 칸 틈 위를 걸으면 빠진다(사용자 11-11, 원작처럼)
const HIT := Vector2(1.5 * T, 1.75 * T)     ## 악당 · 먹물 · 상어에 닿는 판정 — 몸보다 작게(몸이 커져도 어려워지지 않게)
const INV_T := 2.5               ## 다시 나왔을 때 무적

# 거품
const SHOT_V := 620.0            ## 쏜 거품이 뻗어 나가는 빠르기
const SHOT_LEN := 4.6 * T        ## 뻗어 나가는 거리
const SHOT_CD := 0.2             ## 쏘는 사이 — 원작처럼 연타로 거품 벽을 쌓게(11-11 사용자 "쏘는 속도도 빠르고", 예전 0.32)
const RISE_V := 46.0             ## 떠오르는 빠르기
const BUB_R := 0.95 * T          ## 거품 반지름
const BUB_LIFE := 13.0           ## 빈 거품이 저절로 터지기까지
const TRAP_RED := 7.0            ## 갇힌 악당 — 이때부터 거품이 빨갛게 깜박이고
const TRAP_OUT := 9.5            ## 이때 깨고 나온다(화난 채로)
const BUB_PACK := 0.82           ## 뜬 거품끼리 이만큼(반지름 합의 배)까지 겹쳐 뭉친다 — 원작처럼 송이로(예전 1.0 = 안 겹침)
const POP_JUMP_T := 0.18         ## 거품을 밟아 터뜨린 뒤 이 시간 안에 점프 키를 누르면 공중에서 뛴다(원작의 밟고 터뜨리며 점프)
const MAX_BUB := 16              ## 한 사람이 띄워 둘 수 있는 거품

# 판 시간
const HURRY_T := 35.0            ## "서둘러요!" — 악당이 모두 화난다
const SHARK_T := 45.0            ## 거품으로 못 가두는 상어 그림자가 나온다
const SHARK_V := 62.0
const CLEAR_WAIT := 6.0          ## 마지막 악당이 사라진 뒤 물건을 줍는 시간(11-11 사용자 "클리어한 다음 아이템 먹을 시간" — 2.6 → 6). 다 주우면 일찍 넘어간다
const CLEAR_MIN := 1.5           ## 물건이 없어도 이만큼은 기다린다(판을 깼다는 걸 보이게)

## 악당 — [이름, 빠르기, 움직임("walk" · "float"), 처음 나오는 판]
const ENEMY := [
	["심술 복어", 72.0, "walk", 1],
	["꽃게", 96.0, "walk", 3],
	["해파리", 70.0, "float", 3],   # 3 판부터(11-11 — 걷는 악당만 작은 발판에서 왔다갔다 했다)
	["문어", 78.0, "walk", 11],
	["성게", 60.0, "walk", 16],
	# 11-11 영상 분석으로 더한 셋 — 움직임만 원작의 틀을 참고
	["날치", 92.0, "wave", 6],      # 물결치듯 위아래로 출렁이며 옆으로 난다(발판 무시, 벽에서 돌아선다)
	["소라게", 84.0, "drop", 8],    # 걷다가 사람이 아래층에 있으면 발판 끝에서 일부러 떨어져 사람 층으로 몰려온다
	["새우", 46.0, "hop", 13],      # 제자리에서 통통 높이 뛴다(컵 판에 잘 나온다)
]
## 그림이 아직 없는 악당은 있는 그림에 물을 들여 대신 — [빌릴 그림 번호, 물색]. 새 그림은 따로 뽑아 고른 뒤 넣는다.
const EN_ART := {5: [0, Color(0.55, 0.8, 1.0)], 6: [1, Color(0.8, 0.6, 1.0)], 7: [0, Color(1.0, 0.62, 0.55)]}
const ANGRY_K := 1.6
const INK_V := 230.0             ## 문어 먹물
const INK_BLIND := 3.0           ## 먹물을 맞으면 이만큼 앞이 안 보인다(목숨은 안 잃는다 — 기획서)
const INTRO_T := 1.2             ## 판 처음 악당이 위에서 내려와 자리 잡는 시간(그동안은 닿아도 괜찮고 가둘 수 없다)
const CONTINUES := 3             ## 이어 하기 — 점수를 0 으로 하고 그 판부터 다시

## 보스 — 10판마다. [이름, 체력]
const BOSS := [["대왕 문어", 10], ["아귀", 13], ["해마 왕", 16], ["왕 꽃게", 19], ["바다 용", 24]]
const BOSS_SIZE := 5.0 * T     ## 고전 아케이드의 보스는 6 칸 안팎
const BOSS_DASH_V := 430.0       ## 해마 왕 돌진 빠르기
const BOSS_DARK_T := 3.0         ## 아귀가 불을 끄는 시간

## 물건 — [이름, 점수]. 한 번에 여럿을 터뜨릴수록 귀한 것이 나온다(연쇄 수 - 1 번째, 끝은 보석).
const ITEMS := [["진주", 100], ["불가사리 사탕", 300], ["미역 젤리", 700], ["푸른 보석", 2000]]
const ITEM_LIFE := 9.0
## 힘 — [이름, 설명]
const POWERS := [["큰 거품", "거품이 커져요"], ["연사", "거품을 빨리 쏴요"], ["물살 지느러미", "빨리 움직여요"], ["무지개 거품", "한 번 쏘면 화면을 가로질러 닿는 악당을 모두 가둬요"]]
const POWER_T := 15.0

## 특수 거품(11-11 영상 분석) — 판마다 정해진 하나가 바닥에서 떠오른다(`special(lv)`). 터뜨린 사람이 보는 쪽으로:
## 번개 — 가로로 화면을 가로지르며 닿는 악당을 없앤다. 물살 — 쏟아져 발판을 따라 흐르며 악당을 쓸어 간다.
const SPECIAL := ["번개", "물살"]
const SPECIAL_GAP := 11.0
const THUNDER_V := 560.0
const WATER_V := 320.0
const WATER_T := 6.0

## 건너뛰기 조개(원작의 우산 같은 물건, 사용자 11-11 "넘어가는 판 수를 적게") — 먹으면 이 판을 깨고 SKIP_N 판을 더 건너뛴다. 보스 판은 못 넘는다.
const SKIP_N := 2
const SKIP_P := 0.07

## 비밀 방(사용자 11-11) — 10 판 묶음(1~10, 11~20 …)에서 한 번도 안 죽고 그 묶음의 5 번째 판(5 · 15 · 25 · 35 · 45 판)에 오면
## 바닥에 문이 열린다. 들어가면 악당 없는 방에서 보물을 줍고 다음 판으로.
const SECRET_AT := 4
const SECRET_T := 12.0
const SECRET_TIPS := [
	"비밀 하나: 물 · 거 · 품 · 처 · 럼 다섯 글자를 다 모으면 그 판은 바로 통과예요.",
	"비밀 하나: 판마다 거품이 모이는 자리가 달라요. 물살을 보고 쏘세요.",
	"비밀 하나: 판이 시작하고 악당이 내려오는 동안 미리 자리를 잡으세요.",
	"비밀 하나: 바닥에 거품을 쌓아 두면 내려오는 악당이 스스로 갇혀요.",
	"비밀 하나: 번개 · 물살 거품은 터뜨린 사람이 보는 쪽으로 나가요.",
]

## 글자 거품 — "물 거 품 처 럼". 다섯을 모으면 목숨 하나 + 큰 점수 + **그 판 바로 통과**(고전 아케이드의 글자 모으기, 11-11 영상 분석)
const WORD := ["물", "거", "품", "처", "럼"]
const WORD_COL := [Color8(110, 170, 255), Color8(120, 210, 140), Color8(255, 190, 70), Color8(255, 130, 130), Color8(190, 140, 255)]
const WORD_GAP := 16.0           ## 글자 거품이 바닥에서 떠오르는 사이(초)

const LINE := "물거품처럼 사라져줘!"


## 판 그림 번호(배경 · 발판) — 10판마다
static func theme(lv: int) -> int:
	return clampi(lv / 10, 0, 4)


static func boss_level(lv: int) -> bool:
	return lv % 10 == 9


## lv 판(0 부터)의 칸 — 26 줄 × 32 글자. '#' 벽 · 발판, '.' 빈칸. 같은 판은 늘 같다.
## **발판 윗면은 5 · 10 · 15 · 20 줄과 바닥(25 줄)뿐** — 고전 거품 아케이드 비율(층 사이 5 칸, 바닥까지 다섯 줄, 사람 키 2 칸).
## 11-11 사용자: "원작은 가장 아래를 발판으로 쳐도 5 줄인데 7 줄씩 들어간다 — 처음부터 말한 비율이 안 맞는다". 예전엔 층 사이 4 칸(21 · 17 · 13 · 9 · 5)에
## 2~3 칸짜리 계단 · 섬까지 섞여 줄이 일고여덟이었다. 그 전엔 "엑셀 시트처럼 똑같다"는 말도 있었으니 — 줄 높이는 지키고,
## 다양함은 **줄마다 다른 무늬**(긴 층 · 가운데 · 양쪽 선반 · 디딤판 · 섬)와 **세로 모양**(울타리 · 방 · 칸막이 · 그림 · 글자 · 컵 · 미로)으로 낸다.
## 예외: **촘촘한 판**("dense", 열에 하나쯤 — 층 사이 4 칸, 다섯 줄 + 바닥, 사다리 기둥). 원작도 40 · 42 · 82 판처럼 일부러 답답한 판을 섞는다(영상 분석 11-11).
## 좌우 대칭은 넷에 셋(원작 비율). 점프는 5.6 칸(층 하나 위로).
const LAYERS := [5, 10, 15, 20]
const LAYERS_DENSE := [5, 9, 13, 17, 21]
const KINDS := ["hall", "steps", "fence", "cages", "tower", "picture", "word", "cups", "maze", "dense"]


## lv 판의 틀 이름(고전 · hall · … · dense · boss).
static func kind(lv: int) -> String:
	if boss_level(lv):
		return "boss"
	if lv < 2:
		return "classic"
	if lv % 10 == 7:   # 8 · 18 · 28 · 38 · 48 판은 촘촘한 판
		return "dense"
	return String(KINDS[(lv * 4 + lv / 9) % (KINDS.size() - 1)])   # 나머지 아홉 틀이 고르게 돌아가며


static func layers(lv: int) -> Array:
	return LAYERS_DENSE if kind(lv) == "dense" else LAYERS


static var _levels := {}


## lv 판의 칸(만든 것을 기억해 둔다 — 판 넘어갈 때 그리기가 매 화면 부른다).
## 만든 뒤 **어디서든 바닥까지 내려갈 수 있는지** 길찾기로 보고(`down_ok`), 막혔으면 층에 4 칸 틈을 뚫는다(사용자 11-11 "아래로 아예 내려갈 수 없는 판이 있다").
static func level(lv: int) -> Array:
	if _levels.has(lv):
		return _levels[lv]
	var rows := _build(lv)
	var stamped: Array = _stamped.duplicate()
	for k in 6:
		if down_ok(rows):
			break
		rows = _open_down(rows, k >= 4)
	_levels[lv] = rows
	var bl := {}   # 그림 · 글자 칸(네모 블록으로 그린다 — 막대로 이어 그리면 모양이 안 읽혔다, 사용자 11-11)
	for v: Vector2i in stamped:
		if String(rows[v.y])[v.x] == "#":
			bl[v] = true
	_blocks[lv] = bl
	return rows


static var _blocks := {}
static var _stamped: Array = []


## lv 판의 그림 · 글자 칸 {Vector2i(열, 줄): true}.
static func blocks(lv: int) -> Dictionary:
	level(lv)
	return _blocks.get(lv, {})


## 막힌 판 열기 — 층마다 3 칸 넘는 틈이 없으면 가운데(14~17)를 뚫고 그 밑 네 줄의 벽도 걷는다. shaft 면 가운데를 위에서 아래까지 통째로.
static func _open_down(rows: Array, shaft: bool) -> Array:
	var g := []
	for r in rows:
		var a := []
		for ch in String(r):
			a.append(ch)
		g.append(a)
	for y in range(3, ROWS - 2):
		var row: Array = g[y]
		var run := 0
		var best := 0
		for c in range(2, COLS - 2):
			run = run + 1 if row[c] == "." else 0
			best = maxi(best, run)
		var floor_row := false
		for c in range(2, COLS - 2):
			if row[c] == "#" and g[y - 1][c] == ".":
				floor_row = true
		if shaft or (floor_row and best < 3):
			for r in range(y, mini(y + 5, ROWS - 1)):
				for c in range(14, 18):
					g[r][c] = "."
	return _rows(g)


## 길찾기는 반 칸 단위 — x2 는 몸 가운데 x 를 반 칸으로 센 값. 몸이 걸치는 열 [처음, 끝].
static func _span(x2: int, w: float, inset: float) -> Vector2i:
	var x := x2 * T * 0.5
	return Vector2i(int(floor((x - w * 0.5 + inset) / T)), int(floor((x + w * 0.5 - inset) / T)))


## 몸 자리(r-2, r-1 줄)가 비었나 — 걸을 때 벽에 막히는지.
static func _free(rows: Array, x2: int, r: int) -> bool:
	var sp := _span(x2, BODY.x, 0.5)
	if sp.x < 2 or sp.y >= COLS - 2 or r < 2:
		return false
	for rr in [r - 2, r - 1]:
		var s: String = rows[rr]
		for c in range(sp.x, sp.y + 1):
			if s[c] == "#":
				return false
	return true


## 발밑(0.6 칸) 아래 r 줄에 발판이 있나.
static func _foot(rows: Array, x2: int, r: int) -> bool:
	var sp := _span(x2, FOOT, 2.0)
	var s: String = rows[r]
	for c in range(maxi(sp.x, 0), mini(sp.y, COLS - 1) + 1):
		if s[c] == "#":
			return true
	return false


static func _stand(rows: Array, x2: int, r: int) -> bool:
	return r >= 2 and r < ROWS and _foot(rows, x2, r) and _free(rows, x2, r)


## (x2, r) 에서 떨어져 닿는 곳 — [x2, 줄], 바닥 구멍으로 빠지면 [-1, -1]. 떨어지는 몸은 옆 발판을 스쳐 지나간다(위로만 막히는 발판).
static func _fall(rows: Array, x2: int, r: int) -> Vector2i:
	for rr in range(r + 1, ROWS):
		if _foot(rows, x2, rr):
			return Vector2i(x2, rr)
	return Vector2i(-1, -1)


## 어디서든 바닥(25 줄)이나 바닥 구멍까지 내려갈 수 있나 — 시작 자리(왼쪽 아래)에서 갈 수 있는 모든 곳에서.
## 움직임: 걷기(벽에 막힘) · 끝에서 떨어지기 · 뛰기(5 줄 위 · 옆 4 칸까지, 뛰어오를 땐 무엇이든 지나간다).
static func down_ok(rows: Array) -> bool:
	var nodes := {}
	var order := []
	var start := Vector2i(7, ROWS - 1)   # 다시 나오는 자리 x 3.5 칸
	nodes[start] = []
	order.append(start)
	var i := 0
	while i < order.size():   # 갈 수 있는 곳과 이음
		var n: Vector2i = order[i]
		i += 1
		var nx := []
		for d in [-1, 1]:   # 걷기(반 칸씩) · 발이 틈 위에 오면 떨어지기
			var c: int = n.x + d
			if not _free(rows, c, n.y):
				continue
			if _foot(rows, c, n.y):
				nx.append(Vector2i(c, n.y))
			else:
				nx.append(_fall(rows, c, n.y))
		for k in range(1, 6):   # 뛰기(5 줄 위 · 옆 5 칸까지 — 실제 점프는 같은 높이로 약 7 칸, 넉넉히 덜 잡는다) — 꼭대기가 비어 있으면 거기서 내려앉는다
			for dc in range(-10, 11, 2):
				var c2: int = n.x + dc
				if _stand(rows, c2, n.y - k):
					nx.append(Vector2i(c2, n.y - k))
				elif _free(rows, c2, n.y - k):
					nx.append(_fall(rows, c2, n.y - k))
		nodes[n] = nx
		for m: Vector2i in nx:
			if m.x >= 0 and not nodes.has(m):
				nodes[m] = []
				order.append(m)
	var down := {}
	var changed := true
	while changed:   # 바닥까지 갈 수 있는 곳을 거꾸로 넓힌다
		changed = false
		for n: Vector2i in order:
			if down.has(n):
				continue
			if n.y == ROWS - 1:
				down[n] = true
				changed = true
				continue
			for m: Vector2i in nodes[n]:
				if m.x < 0 or down.has(m):
					down[n] = true
					changed = true
					break
	return down.size() == order.size()


## 판 만들기(막힘 검사 전).
static func _build(lv: int) -> Array:
	_stamped = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001 + lv * 7919
	var g := []
	for r in ROWS:
		var row := []
		for c in COLS:
			var wall := c < 2 or c >= COLS - 2
			var edge := (r == 0 or r == ROWS - 1) and not (c >= HOLE[0] and c <= HOLE[1])
			row.append("#" if wall or edge else ".")
		g.append(row)
	var kd := kind(lv)
	if kd == "boss":   # 보스 판 — 넓게 비우고 짧은 발판 몇 개만. 보스마다 배치가 다르다(사용자 11-11 "보스 판 다섯이 다 같다")
		var segs: Array = BOSS_FLOORS[clampi(lv / 10, 0, BOSS_FLOORS.size() - 1)]
		for sg: Array in segs:   # [줄, 시작 열, 끝 열(포함)] — 왼쪽 것만 적고 거울로
			for c in range(int(sg[1]), int(sg[2]) + 1):
				_put(g, int(sg[0]), c, true)
		return _rows(g)
	rng.randi_range(0, 3)   # kind() 와 같은 수를 한 번 뽑아 둔다(뒤 난수가 예전과 어긋나지 않게)
	var mir := rng.randf() < 0.75   # 좌우 대칭은 넷에 셋
	var lays: Array = layers(lv)
	var pats := ["long", "center", "sides", "steps", "islands"]
	match kd:
		"classic":   # 고전 첫 판 — 가운데가 뚫린 긴 층(1 판) · 양쪽 선반 + 가운데 섬(2 판)
			for y in LAYERS:
				for c in (range(2, 12) if lv == 0 else range(2, 7) + range(11, 16)):
					_put(g, y, c, true)
			return _rows(g)
		"hall", "maze":
			pats = ["long", "center", "sides"]
		"steps":
			pats = ["steps", "islands", "sides"]
		"dense":
			pats = ["long", "steps", "sides", "center"]
		"cups":
			pats = ["sides", "steps"]
	var skip := {}   # 그림 · 글자가 차지한 층(줄 → 칸 범위)
	if kd == "picture":   # 가운데 큰 그림 — 윗면이 5 줄, 그 밑 10 줄 층은 그림 자리만 비운다
		var pics := [PIC_HEART, PIC_FISH, PIC_ANCHOR, PIC_STAR]
		var pic: Array = pics[rng.randi_range(0, pics.size() - 1)]
		var pw := String(pic[0]).length() * 2   # 가로 2 배 · 세로 1.5 배로 키워 찍는다(예전 그대로는 작아 모양이 안 읽혔다, 사용자 11-11)
		var ph := int(ceil(pic.size() * 1.5))
		var px := 16 - pw / 2
		_stamp(g, pic, px, 3, 2.0, 1.5)
		for y: int in LAYERS:
			if y <= 3 + ph:
				skip[y] = Vector2i(px - 2, px + pw + 2)
		pats = ["sides", "steps", "long"]
	elif kd == "word":   # 글자 판 — 위쪽에 큰 낱말(벽돌 글자 3 × 5), 그 밑 5 줄 층은 비운다
		var w: String = WORDS[rng.randi_range(0, WORDS.size() - 1)]
		var wide := w.length() * 7 - 1   # 글자 3 × 5 를 2 배(6 × 10)로 — 예전 그대로는 글자로 안 읽혔다(사용자 11-11)
		var px2 := 16 - wide / 2
		for i in w.length():
			_stamp(g, FONT[w[i]], px2 + i * 7, 3, 2.0, 2.0)
		skip[5] = Vector2i(px2 - 2, px2 + wide + 2)
		skip[10] = skip[5]
		pats = ["long", "sides", "steps"]
	var last := ""
	for y: int in lays:
		if kd == "cups" and (y == 10 or y == 20):
			continue
		var pat := String(pats[rng.randi_range(0, pats.size() - 1)])
		if pat == last:
			pat = String(pats[(pats.find(pat) + 1) % pats.size()])
		last = pat
		_layer(g, y, pat, rng, mir, skip.get(y, Vector2i(-1, -1)))
	match kd:
		"fence":   # 울타리 — 발판 끝에 2~3 칸 높이 벽(넘어 뛸 수 있다)
			for y: int in lays:
				for c in range(3, COLS - 3):
					if g[y][c] == "#" and g[y][c - 1] == "." and rng.randf() < 0.5:
						for k in rng.randi_range(2, 3):
							_put(g, y - 1 - k, c, mir)
		"cages":   # 방 — 한 층과 그 아래 층을 잇는 옆벽(한쪽만), 방 안 키는 4 칸
			for k in rng.randi_range(2, 3):
				var y: int = LAYERS[rng.randi_range(0, 2)]
				var cx := rng.randi_range(4, COLS - 12)
				var w := rng.randi_range(6, 8)
				for c in range(cx, cx + w):
					_put(g, y, c, mir)
					_put(g, y + 5, c, mir)
				var wx := cx if rng.randf() < 0.5 else cx + w - 1
				for r in range(y, y + 3):
					_put(g, r, wx, mir)
		"tower":   # 가운데 칸막이 — 5 줄부터 17 줄까지 두 칸 벽, 바닥으로 돌아 건너간다
			for r in range(5, 18):
				_put(g, r, 15, false)
				_put(g, r, 16, false)
		"cups":   # 컵 — 10 줄에 셋, 20 줄에 둘. 바닥 8 칸 + 양옆 3 칸 벽. 악당이 컵 안에서 시작(원작 30 판 같은 틀 — 모양은 우리 것)
			for cx: int in [3, 12, 21]:
				_cup(g, cx, 10)
			for cx: int in [7, 17]:
				_cup(g, cx, 20)
		"maze":   # 미로 — 층 사이를 세로 벽으로 갈라 칸칸이 방(위로는 발판을 뚫고, 아래로는 틈으로)
			for y: int in [5, 10, 15]:
				for k in 2:
					var c := rng.randi_range(5, 13)
					for r in range(y, y + 5):
						_put(g, r, c, mir)
		"dense":   # 촘촘한 판 — 사다리 기둥 둘(거울), 기둥 사이 가로대가 층마다
			var lc := rng.randi_range(6, 9)
			for r in range(5, 22):
				_put(g, r, lc, true)
				_put(g, r, lc + 4, true)
			for y: int in lays:
				for c in range(lc, lc + 5):
					_put(g, y, c, true)
	_reach(g, lays, mir)
	for y: int in lays:   # 층이 벽에서 벽까지 꽉 막히면(방이 틈을 메울 때) 가운데에 내려갈 틈
		if not g[y].slice(2, COLS - 2).has("."):
			for c in range(14, 18):
				g[y][c] = "."
	return _rows(g)


## 그림 · 글자 찍기 — pic 줄들의 '#' 를 (x, y) 부터.
static func _stamp(g: Array, pic: Array, x: int, y: int, sx: float = 1.0, sy: float = 1.0) -> void:
	var w := int(ceil(String(pic[0]).length() * sx))
	var h := int(ceil(pic.size() * sy))
	for ty in h:
		var line: String = pic[mini(int(ty / sy), pic.size() - 1)]
		for tx in w:
			if line[mini(int(tx / sx), line.length() - 1)] == "#":
				_put(g, y + ty, x + tx, false)
				_stamped.append(Vector2i(x + tx, y + ty))


## 컵 하나 — 바닥 (cx ~ cx+7, y 줄) + 양옆 벽(y-3 ~ y-1).
static func _cup(g: Array, cx: int, y: int) -> void:
	for c in range(cx, cx + 8):
		_put(g, y, c, false)
	for r in range(y - 3, y):
		_put(g, r, cx, false)
		_put(g, r, cx + 7, false)


## 한 층(y 줄) 무늬. mir 면 왼쪽 절반만 만들고 거울로. gap 칸 범위(그림 자리)는 비운다.
static func _layer(g: Array, y: int, pat: String, rng: RandomNumberGenerator, mir: bool, gap: Vector2i) -> void:
	var hi := 16 if mir else COLS - 2
	var segs := []   # [시작, 끝(빼고)]
	match pat:
		"long":   # 벽에서 벽까지, 틈 하나둘(4~5 칸)
			var g1 := rng.randi_range(5, hi - 6)
			segs = [[2, g1], [g1 + rng.randi_range(4, 5), hi]]
			if not mir and rng.randf() < 0.5:
				segs = [[2, 9], [13, 19], [23, COLS - 2]]
		"center":
			var w := rng.randi_range(5, 10)
			for c in range(16 - w, 16 + w):
				_put_gap(g, y, c, false, gap)
			return
		"sides":
			var w2 := rng.randi_range(4, 9)
			segs = [[2, 2 + w2]]
			if not mir:
				var w3 := rng.randi_range(4, 9)
				segs.append([COLS - 2 - w3, COLS - 2])
		"steps":   # 디딤판 2~3 개(4~6 칸)
			var x := rng.randi_range(3, 6)
			while x < hi - 4:
				var w4 := rng.randi_range(4, 6)
				segs.append([x, mini(x + w4, hi)])
				x += w4 + rng.randi_range(4, 7)
		"islands":   # 3 칸짜리 섬
			var x2 := rng.randi_range(3, 5)
			while x2 < hi - 3:
				segs.append([x2, x2 + 3])
				x2 += rng.randi_range(6, 8)
	for s: Array in segs:
		for c in range(int(s[0]), int(s[1])):
			_put_gap(g, y, c, mir, gap)


static func _put_gap(g: Array, r: int, c: int, mir: bool, gap: Vector2i) -> void:
	if c >= gap.x and c < gap.y:
		return
	_put(g, r, c, mir)
	if mir and COLS - 1 - c >= gap.x and COLS - 1 - c < gap.y:
		g[r][COLS - 1 - c] = "."


## 칸 하나 놓기(판 안쪽만). mir 면 좌우 거울 자리도. 바닥 위 세 줄(22~24)의 양 끝(사람이 다시 나오는 자리)은 비워 둔다.
static func _put(g: Array, r: int, c: int, mir: bool) -> void:
	if r < 2 or r > 23 or c < 2 or c >= COLS - 2:
		return
	if r >= 22 and (c < 6 or c >= COLS - 6):
		return
	g[r][c] = "#"
	if mir:
		g[r][COLS - 1 - c] = "#"


## 어디든 올라갈 수 있게 — 층 발판 칸마다 아래 한 층 · 옆 6 칸 안에 딛을 곳이 없으면 그 아래 층에 4 칸 디딤판을 놓는다.
static func _reach(g: Array, lays: Array, mir: bool) -> void:
	var gap := int(lays[1]) - int(lays[0])
	for r: int in lays:
		for c in range(2, COLS - 2):
			if g[r][c] != "#" or g[r - 1][c] != ".":
				continue
			var ok := r + gap >= ROWS - 1
			for rr in range(r + 1, mini(r + gap + 1, ROWS)):
				for cc in range(maxi(2, c - 6), mini(COLS - 2, c + 7)):
					if g[rr][cc] == "#" and g[rr - 1][cc] == ".":
						ok = true
			if not ok:
				for cc in range(maxi(2, c - 2), mini(COLS - 2, c + 2)):
					_put(g, r + gap, cc, mir)


## 글자 판 낱말과 벽돌 글꼴(3 × 5). 우리 낱말 — 원작 판의 낱말은 쓰지 않는다.
const WORDS := ["SEA!", "POP!", "WOW!", "YAY!", "HI!", "OH!"]
const FONT := {
	"S": ["###", "#..", "###", "..#", "###"], "E": ["###", "#..", "###", "#..", "###"], "A": ["###", "#.#", "###", "#.#", "#.#"],
	"P": ["###", "#.#", "###", "#..", "#.."], "O": ["###", "#.#", "#.#", "#.#", "###"], "W": ["#.#", "#.#", "#.#", "###", "#.#"],
	"Y": ["#.#", "#.#", "###", ".#.", ".#."], "H": ["#.#", "#.#", "###", "#.#", "#.#"], "I": ["###", ".#.", ".#.", ".#.", "###"],
	"!": [".#.", ".#.", ".#.", "...", ".#."],
}


## 비밀 방 — 악당 없이 보물만. 양쪽 선반 셋과 가운데 단.
static func secret_room() -> Array:
	var g := []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append("#" if c < 2 or c >= COLS - 2 or r == ROWS - 1 or (r == 0 and (c < HOLE[0] or c > HOLE[1])) else ".")
		g.append(row)
	for y: int in [10, 15, 20]:
		for c in range(2, 9):
			_put(g, y, c, true)
	for c in range(11, 21):
		_put(g, 13, c, false)
	return _rows(g)


## 판마다 거품이 모이는 자리(px) — 원작처럼 판마다 물살이 다르다(영상 분석 11-11). 1 · 2 판과 보스 판은 천장 가운데.
static func current(lv: int) -> Vector2:
	var spots := [Vector2(16, 2), Vector2(6, 2), Vector2(26, 2), Vector2(5, 12), Vector2(27, 12), Vector2(16, 8), Vector2(10, 4), Vector2(22, 4)]
	var k := 0 if lv < 2 or boss_level(lv) else (lv * 3 + lv / 7) % spots.size()
	return spots[k] * T


## 판에 떠오르는 특수 거품 — -1 없음 · 0 번개 · 1 물살. 5 판부터 열에 넷쯤.
static func special(lv: int) -> int:
	if lv < 4 or boss_level(lv):
		return -1
	var h := (lv * 37 + 11) % 10
	return -1 if h >= 4 else h % 2


## 보스 판 발판 — 보스마다 [줄, 시작 열, 끝 열] (왼쪽만, 거울로 오른쪽도).
const BOSS_FLOORS := [
	[[20, 4, 8], [10, 4, 8], [15, 12, 15]],                               # 대왕 문어 — 양쪽 짧은 선반 + 가운데 섬
	[[20, 2, 11], [15, 6, 9], [10, 13, 15]],                              # 아귀 — 아래 긴 선반 · 가운데 높은 섬(불을 끄면 길을 기억해야)
	[[20, 3, 7], [15, 9, 12], [10, 3, 7], [5, 13, 15]],                   # 해마 왕 — 지그재그 계단(돌진을 피해 오르내린다)
	[[20, 2, 12], [15, 12, 15]],                                          # 왕 꽃게 — 넓은 바닥 마당(바위가 굴러온다)
	[[20, 4, 6], [20, 10, 12], [15, 7, 9], [10, 4, 6], [10, 10, 12], [5, 7, 9]],   # 바다 용 — 흩어진 작은 섬
]
const PIC_HEART := [".##...##.", "####.####", "#########", ".#######.", "..#####..", "...###...", "....#...."]
const PIC_FISH := ["...####....#", ".########.##", "##.#########", "###########.", ".########.##", "...####....#"]
const PIC_ANCHOR := ["....###....", "....#.#....", "....###....", ".....#.....", "..#######..", ".....#.....", "#....#....#", "##...#...##", ".#########."]
const PIC_STAR := ["....#....", "...###...", "#########", ".#######.", "..##.##..", ".##...##."]


static func _rows(g: Array) -> Array:
	var out := []
	for row in g:
		out.append("".join(PackedStringArray(row)))
	return out


## lv 판에 나올 악당 — [[종류, 칸 x, 칸 y], …].
## 걷는 악당은 **5 칸 이상 이어진 발판**(또는 바닥) 위에만 — 작은 발판에서 왔다갔다만 하는 악당이 너무 많았다(사용자 11-11).
## 떠다니는 악당(해파리)이 나오는 판부터는 열에 넷쯤이 떠다닌다. 떠다니는 악당은 빈 하늘 어디든.
static func spawns(lv: int, grid: Array) -> Array:
	if boss_level(lv):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + lv * 131
	var n := mini(3 + lv / 6, 8)
	var walkers := []
	var floaters := []
	for k in ENEMY.size():
		if lv + 1 >= int(ENEMY[k][3]):
			(floaters if String(ENEMY[k][2]) in ["float", "wave"] else walkers).append(k)
	var spots := []   # 긴 발판 윗칸(빈칸 위가 '#', 그 줄로 5 칸 이상 이어짐) — 바닥(25 줄)도
	for r in range(4, ROWS):
		var run := 0
		for c in range(2, COLS - 1):
			var top := String(grid[r])[c] == "#" and String(grid[r - 1])[c] == "." and String(grid[r - 2])[c] == "."
			if top:
				run += 1
			else:
				if run >= 5:
					for cc in range(c - run + 1, c - 1):
						if cc >= 3 and cc < COLS - 4:
							spots.append(Vector2i(cc, r - 1))
				run = 0
	var sky := []    # 떠다니는 악당 자리 — 위아래 세 칸이 빈 하늘
	for r in range(4, 20):
		for c in range(4, COLS - 4):
			if String(grid[r])[c] == "." and String(grid[r - 1])[c] == "." and String(grid[r + 1])[c] == ".":
				sky.append(Vector2i(c, r))
	var out := []
	for i in n:
		var fly := not floaters.is_empty() and (rng.randf() < 0.4 or spots.is_empty())
		if fly and not sky.is_empty():
			var s2: Vector2i = sky[rng.randi_range(0, sky.size() - 1)]
			sky = sky.filter(func(p): return absi(p.x - s2.x) > 4 or absi(p.y - s2.y) > 3)
			out.append([floaters[rng.randi_range(0, floaters.size() - 1)], s2.x, s2.y])
			continue
		if spots.is_empty() or walkers.is_empty():
			break
		var s: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		spots = spots.filter(func(p): return absi(p.x - s.x) > 4 or p.y != s.y)
		var k: int = walkers[rng.randi_range(0, walkers.size() - 1)] if rng.randf() < 0.6 else walkers[walkers.size() - 1]
		if kind(lv) == "cups" and walkers.has(7) and rng.randf() < 0.6:   # 컵 판엔 통통 새우
			k = 7
		out.append([k, s.x, s.y])
	return out
