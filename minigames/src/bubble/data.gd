class_name BbD
extends RefCounted

## 물거품처럼 사라져줘 표 — 판 · 크기 · 물리 · 악당 · 점수(기획서 docs/design/bubble.md). 그리기를 모른다.
## 판은 **고전 거품 아케이드의 비율**을 따른다: 4:3 한 화면, 8px 타일 32 × 26 칸(양옆 벽 두 칸, 바닥 · 천장 한 줄),
## 캐릭터 · 악당은 2 × 2 칸, 층 사이는 4 칸(점프 한 번에 위층), 바닥 · 천장 가운데 구멍으로 위아래가 이어진다.
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
const JUMP_V := 560.0
const GRAVITY := 1300.0          ## 꼭대기 높이 = 560² / 2600 = 120px(4.6칸)
const FALL_MAX := 300.0          ## 떨어지는 빠르기 끝(고전 아케이드처럼 천천히)
const BODY := Vector2(1.5 * T, 1.75 * T)   ## 판정 상자(폭, 키) — 발밑이 기준
const INV_T := 2.5               ## 다시 나왔을 때 무적

# 거품
const SHOT_V := 620.0            ## 쏜 거품이 뻗어 나가는 빠르기
const SHOT_LEN := 4.6 * T        ## 뻗어 나가는 거리
const SHOT_CD := 0.32            ## 쏘는 사이
const RISE_V := 46.0             ## 떠오르는 빠르기
const BUB_R := 0.95 * T          ## 거품 반지름
const BUB_LIFE := 13.0           ## 빈 거품이 저절로 터지기까지
const TRAP_RED := 7.0            ## 갇힌 악당 — 이때부터 거품이 빨갛게 깜박이고
const TRAP_OUT := 9.5            ## 이때 깨고 나온다(화난 채로)
const MAX_BUB := 14              ## 한 사람이 띄워 둘 수 있는 거품

# 판 시간
const HURRY_T := 35.0            ## "서둘러요!" — 악당이 모두 화난다
const SHARK_T := 45.0            ## 거품으로 못 가두는 상어 그림자가 나온다
const SHARK_V := 62.0
const CLEAR_WAIT := 2.6          ## 마지막 악당이 사라진 뒤 물건을 줍는 시간

## 악당 — [이름, 빠르기, 움직임("walk" · "float"), 처음 나오는 판]
const ENEMY := [
	["심술 복어", 72.0, "walk", 1],
	["꽃게", 96.0, "walk", 3],
	["해파리", 70.0, "float", 6],
	["문어", 78.0, "walk", 11],
	["성게", 60.0, "walk", 16],
]
const ANGRY_K := 1.6
const INK_V := 230.0             ## 문어 먹물
const INK_BLIND := 3.0           ## 먹물을 맞으면 이만큼 앞이 안 보인다(목숨은 안 잃는다 — 기획서)
const INTRO_T := 1.2             ## 판 처음 악당이 위에서 내려와 자리 잡는 시간(그동안은 닿아도 괜찮고 가둘 수 없다)
const CONTINUES := 3             ## 이어 하기 — 점수를 0 으로 하고 그 판부터 다시

## 보스 — 10판마다. [이름, 체력]
const BOSS := [["대왕 문어", 10], ["아귀", 13], ["해마 왕", 16], ["왕 꽃게", 19], ["바다 용", 24]]
const BOSS_SIZE := 5.0 * T     ## 고전 아케이드의 보스는 6 칸 안팎

## 물건 — [이름, 점수]. 한 번에 여럿을 터뜨릴수록 귀한 것이 나온다(연쇄 수 - 1 번째, 끝은 보석).
const ITEMS := [["진주", 100], ["불가사리 사탕", 300], ["미역 젤리", 700], ["푸른 보석", 2000]]
const ITEM_LIFE := 9.0
## 힘 — [이름, 설명]
const POWERS := [["큰 거품", "거품이 커져요"], ["연사", "거품을 빨리 쏴요"], ["물살 지느러미", "빨리 움직여요"], ["무지개 거품", "한 번 쏘면 화면을 가로질러 닿는 악당을 모두 가둬요"]]
const POWER_T := 15.0

## 글자 거품 — "물 거 품 처 럼". 다섯을 모으면 목숨 하나 + 큰 점수(고전 아케이드의 글자 모으기)
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
## 바닥 · 천장 · 양옆 벽은 늘 같고, 층(아래에서 21 · 17 · 13 · 9 · 5 번째 줄)은 판마다 좌우 대칭 무늬로.
static func level(lv: int) -> Array:
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
	if boss_level(lv):   # 보스 판 — 넓게 비우고 짧은 발판 몇 개만
		for r in [21, 15, 9]:
			for c in range(4, 9):
				g[r][c] = "#"
				g[r][COLS - 1 - c] = "#"
		for c in range(13, 19):
			g[18][c] = "#"
		return _rows(g)
	var style := lv % 8 if lv < 8 else rng.randi_range(0, 7)
	for i in 5:
		var r: int = [21, 17, 13, 9, 5][i]
		var half := []   # 왼쪽 절반(2~15 칸)에 놓을 칸들 — 오른쪽은 거울
		match style:
			0:   # 고전 첫 판: 가운데가 뚫린 긴 층
				half = range(2, 12)
			1:   # 양쪽 짧은 선반 + 가운데 섬
				half = range(2, 6) + range(10, 16)
			2:   # 계단 — 층마다 안쪽으로
				half = range(2 + i, 8 + i)
			3:   # 섬 셋
				half = range(4, 8) + range(12, 16)
			4:   # 층마다 번갈아(벽에 붙은 것 · 가운데)
				half = range(2, 9) if i % 2 == 0 else range(9, 16)
			5:   # 넓은 가운데 + 벽 쪽 틈
				half = range(5, 16)
			6:   # 깨진 층(칸마다 이 빠짐)
				for c in range(2, 16):
					if (c + i) % 3 != 0:
						half.append(c)
			_:   # 무작위(대칭) — 이어진 덩어리 둘 셋
				var c0 := 2
				while c0 < 15:
					var ln := rng.randi_range(2, 6)
					for c in range(c0, mini(16, c0 + ln)):
						half.append(c)
					c0 += ln + rng.randi_range(2, 4)
		# 층마다 아래로 내려갈 틈이 꼭 있게 — 벽 옆 두 칸이나 가운데 두 칸 중 하나는 비운다
		if half.has(14) and half.has(15) and half.has(2) and half.has(3):
			half.erase(14)
			half.erase(15)
		for c in half:
			g[r][c] = "#"
			g[r][COLS - 1 - c] = "#"
	return _rows(g)


static func _rows(g: Array) -> Array:
	var out := []
	for row in g:
		out.append("".join(PackedStringArray(row)))
	return out


## lv 판에 나올 악당 — [[종류, 칸 x, 칸 y], …]. 위층 발판 위에 고르게.
static func spawns(lv: int, grid: Array) -> Array:
	if boss_level(lv):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + lv * 131
	var n := mini(3 + lv / 6, 8)
	var kinds := []
	for k in ENEMY.size():
		if lv + 1 >= int(ENEMY[k][3]):
			kinds.append(k)
	var spots := []   # 발판 윗칸(빈칸 위가 '#')
	for r in range(4, 22):
		for c in range(3, COLS - 4):
			if String(grid[r])[c] == "#" and String(grid[r - 1])[c] == "." and String(grid[r - 2])[c] == ".":
				spots.append(Vector2i(c, r - 1))
	var out := []
	for i in n:
		if spots.is_empty():
			break
		var s: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		spots = spots.filter(func(p): return absi(p.x - s.x) > 3 or p.y != s.y)
		var k: int = kinds[rng.randi_range(0, kinds.size() - 1)] if rng.randf() < 0.6 else kinds[kinds.size() - 1]
		out.append([k, s.x, s.y])
	return out
