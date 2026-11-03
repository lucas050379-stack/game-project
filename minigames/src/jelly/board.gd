class_name Board
extends RefCounted

## 판 로직만 — 그리기 · 시간 · 입력 · 점수를 모른다. `tools/check.gd` 가 헤드리스로 돌린다.
##
## 칸 번호는 `y * w + x`, y = 0 이 맨 위. 칸 하나에 겹이 여럿 있다:
##   hole   판이 아닌 칸 (아무것도 없고, 떨어지는 것은 그 칸을 건너 지나간다)
##   sugar  바닥 설탕막 겹(0~3) — 그 위에서 젤리가 터질 때마다 한 겹
##   col    칸을 차지한 것: 젤리 0..colors-1 · 무지개 RAINBOW_C · 열매 · 쿠키 상자 · 초콜릿 · 몬스터
##   lay    쿠키 상자 겹(1~3)
##   chain  젤리를 묶은 사슬 — 움직이지 못한다. 맞추거나 맞으면 사슬만 풀린다
##   ice    젤리를 가둔 얼음 겹(0~2) — 매치도 안 되고 움직이지도 못한다
##   belt   바닥 벨트 방향(0 없음 · 1 위 · 2 오른쪽 · 3 아래 · 4 왼쪽) — 턴 끝에 조각을 한 칸 옮긴다
##   portal 출구 → 입구. 입구 칸의 조각이 떨어질 때 출구 칸 위로 나온다
##   field  자기장 — 줄 폭탄 광선이 그 칸 앞에서 멈춘다
##   pipe   파이프 꺾임(1 ┐ · 2 ┌ · 3 ┘ · 4 └) — 칸을 차지한다(hole 로 막아 젤리가 안 들어옴). 광선만 거기서 방향을 튼다
##   csugar 색 설탕막(색 + 1) — 그 색 젤리가 그 위에서 터지거나 특수 효과에 맞아야 벗겨진다
##   cloud  구름 — 칸을 가린다. 그 칸이 터지거나 특수 효과에 맞으면 걷힌다(밑의 것은 그대로 움직이고 맞춰진다)
##   glass  유리 상자 — 젤리(대개 특수)를 가둔다. 깨지면 안의 것이 그대로 풀려난다
##   dice   주사위 젤리 — 턴 끝마다 색이 바뀐다
##   web    거미줄(1~2겹) — 1겹은 바꾸기만 막고(떨어지기는 함), 2겹은 그 자리에 붙든다.
##          맞추거나 옆에서 터지거나 맞으면 한 겹씩 풀린다. 한 턴 동안 하나도 못 풀면 옆으로 번진다
##   steel  강철 젤리 — 그 색으로 줄에 끼지만 움직이지도 터지지도 않는다
##   paint  물감 — 칠한 칸에 닿은 맞춘 덩어리는 전부 칠해지고, 폭탄 · 무지개에 맞은 칸은 어디든 칠해진다
##   rise   솟는 줄 — 그 세로줄은 턴 끝마다 한 칸씩 위로 돈다(맨 위 조각이 맨 아래로)
##
## 장치(톱니 · 바람개비 · 푸시 상자)는 칸을 차지하고 부서지지 않는다.
##
## **움직이는 것(젤리 · 열매)과 고정된 것(상자 · 초콜릿 · 몬스터 · 묶이거나 언 젤리)을
## `movable()` 하나로 가른다.** 떨어지기 · 바꾸기 · 섞기가 전부 이걸 본다.

const EMPTY := -1
## 무지개의 색 값. 젤리 색(0..colors-1)과 겹치면 안 된다 — 젤리가 7종이 되면서 6 에서 옮겼다.
const RAINBOW_C := 9
const FRUIT := 10
const BOX := 11
const CHOCO := 12
const MON := 13
const JELLY_N := 7   ## 젤리 색 가짓수(D.JELLY 크기). 판에 실제로 나오는 색은 palette
const GEAR := 14
const WIND := 15
const PUSH := 16
const CAPSULE := 17   ## 특수 효과로만 깨진다
const LASER := 18     ## 옆에서 세 번 터지면 턴 끝에 dev_dir 쪽으로 광선
const ROCKET := 19    ## 자기 색(dev_color)이 옆에서 맞으면 턴 끝에 dev_dir 쪽으로 날아간다
const LOCK := 20      ## 숫자 자물쇠 — lock_c 색 젤리가 판 어디서든 lock_n 개 터지면 풀린다
const GIFT := 21      ## 선물 상자 — 한 번 맞으면 열린다(특수 젤리 · 이동 +1 · 꽝)
const STEAM := 22     ## 증기 기계 — 몇 턴마다 옆 칸에 구름을 뿜는다. 부서지지 않는다
const DECOY := 23     ## 그림자가 만든 분신 — 한 번 맞으면 사라진다
const PLANT := 24     ## 끈끈이 식물 — 건드리면 사라지며 둘레 여덟 칸 젤리에 거미줄 한 겹
const MOLE := 25      ## 두더지 — 체력 MOLE_HP. 맞은 턴 끝에 다른 자리로 도망간다
const FIRE := 26      ## 모닥불 — 옆에서 터지면 FIRE_LIT 턴 동안 켜진다. 미션은 "전부 동시에"
const JAR := 27       ## 색 그릇 — 옆에서 jar_c 색이 jar_n 개 터지면 차서 사라진다

var w := D.W
var h := D.H
var colors := D.COLORS
## 이 판에 나오는 젤리 색. 보통은 0..colors-1 이고, 스테이지가 골라 줄 수 있다(복숭아가 나오는 판).
var palette := PackedInt32Array()
var col := PackedInt32Array()
var sp := PackedInt32Array()
var lay := PackedInt32Array()
var sugar := PackedInt32Array()
var chain := PackedInt32Array()
var ice := PackedInt32Array()
var hole := PackedByteArray()
var belt := PackedInt32Array()
var portal := {}       ## 출구 칸 → 입구 칸
var portal_in := {}    ## 입구 칸 → 출구 칸
var gear_dir := {}     ## 톱니 칸 → 1 시계 / -1 반시계
var push_dir := {}     ## 푸시 상자 칸 → Vector2i 방향
var wind_armed := {}   ## 이번 턴에 건드려진 바람개비
var field := PackedInt32Array()
var pipe := PackedInt32Array()
var dev_dir := {}      ## 레이저 · 로켓 칸 → Vector2i
var dev_color := {}    ## 로켓 칸 → 색
var charge := {}       ## 레이저 칸 → 0..LASER_FULL
var armed := {}        ## 이번 턴 끝에 쏠 레이저 · 로켓
const LASER_FULL := 3
var csugar := PackedInt32Array()
var cloud := PackedInt32Array()
var glass := PackedInt32Array()
var dice := PackedInt32Array()
var lock_c := {}       ## 자물쇠 칸 → 색
var lock_n := {}       ## 자물쇠 칸 → 남은 수
var steam_cd := {}     ## 증기 기계 칸 → 다음 뿜기까지 턴
const STEAM_EVERY := 3
## 선물 상자를 연 결과 중 Play 가 받아야 하는 것(이동 +1) — Play 가 읽고 비운다
var gift_moves := 0
var web := PackedInt32Array()
var steel := PackedInt32Array()
var paint := PackedInt32Array()
var rise := PackedInt32Array()     ## 세로줄마다 1 이면 솟는 줄
var web_broken := false            ## 이번 턴에 거미줄을 한 겹이라도 풀었나
var mole_hp := {}
var mole_hit := {}                 ## 이번 턴에 맞은 두더지(한 턴에 한 대만)
var fire_t := {}                   ## 모닥불 → 남은 켜짐 턴(0 = 꺼짐)
var jar_c := {}
var jar_n := {}
const MOLE_HP := 3
const FIRE_LIT := 2
## 칸 → {kind, hp, max, every, cd, target: PackedInt32Array}. 몬스터는 움직이지 않는다.
var mons := {}
## 날아가는 젤리가 다른 특수 젤리 효과를 싣고 가는 경우 (칸 → 실을 특수 종류)
var fly_carry := {}
## 위에서 새로 채울 때 내보낼 열매 수. Play 가 미션에서 계산해 넣는다.
var spawn_fruit := 0
var rng := RandomNumberGenerator.new()


func _init(seed_: int = -1, w_: int = D.W, h_: int = D.H, colors_: int = D.COLORS) -> void:
	w = w_
	h = h_
	colors = colors_
	for k in colors:
		palette.append(k)
	var n := w * h
	col.resize(n)
	col.fill(EMPTY)
	# Packed 배열은 값 타입이라 배열에 담아 돌리면 사본만 바뀐다 — 하나씩 직접 쓴다
	sp.resize(n)
	sp.fill(D.SP_NONE)
	lay.resize(n)
	lay.fill(0)
	sugar.resize(n)
	sugar.fill(0)
	chain.resize(n)
	chain.fill(0)
	ice.resize(n)
	ice.fill(0)
	hole.resize(n)
	hole.fill(0)
	belt.resize(n)
	belt.fill(0)
	field.resize(n)
	field.fill(0)
	for a in ["csugar", "cloud", "glass", "dice", "web", "steel", "paint"]:
		var arr: PackedInt32Array = get(a)
		arr.resize(n)
		arr.fill(0)
		set(a, arr)
	pipe.resize(n)
	pipe.fill(0)
	rise.resize(w)
	rise.fill(0)
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()


func cx(i: int) -> int:
	return i % w


func cy(i: int) -> int:
	return i / w


func adjacent(a: int, b: int) -> bool:
	return absi(cx(a) - cx(b)) + absi(cy(a) - cy(b)) == 1


## 상하좌우 이웃 (구멍 제외).
func n4(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := cx(i)
	var y := cy(i)
	if x > 0 and not hole[i - 1]:
		out.append(i - 1)
	if x < w - 1 and not hole[i + 1]:
		out.append(i + 1)
	if y > 0 and not hole[i - w]:
		out.append(i - w)
	if y < h - 1 and not hole[i + w]:
		out.append(i + w)
	return out


func is_jelly(i: int) -> bool:
	return col[i] >= 0 and col[i] <= RAINBOW_C


func _matchable(i: int) -> bool:
	return col[i] >= 0 and col[i] < JELLY_N and ice[i] == 0 and glass[i] == 0 and not hole[i]


func _same(a: int, b: int) -> bool:
	return _matchable(a) and _matchable(b) and col[a] == col[b]


## 바꿀 수 있는가.
func movable(i: int) -> bool:
	return falls(i) and chain[i] == 0 and web[i] == 0


## 떨어질 수 있는가. **사슬 젤리는 바꿀 수는 없어도 떨어진다** — 사슬까지 그 자리에 박아 두면
## 매듭이가 한 줄을 묶는 순간 그 밑이 통째로 비어 버린다(봇 검사에서 실제로 그랬다).
func falls(i: int) -> bool:
	return not hole[i] and (is_jelly(i) or col[i] == FRUIT) and ice[i] == 0 and glass[i] == 0 and web[i] < 2 \
			and steel[i] == 0


## 아무것도 안 걸린 보통 젤리 — 몬스터 · 초콜릿이 먹을 수 있는 것, 섞을 수 있는 것.
func plain(i: int) -> bool:
	return col[i] >= 0 and col[i] < JELLY_N and sp[i] == D.SP_NONE and chain[i] == 0 and ice[i] == 0 and glass[i] == 0 \
			and web[i] == 0 and steel[i] == 0 \
			and not hole[i]


func count(v: int) -> int:
	var n := 0
	for i in w * h:
		if col[i] == v:
			n += 1
	return n

# ==================== 새 판 ====================

## 빈 칸(EMPTY)을 맞춰진 줄 없이 젤리로 채운다. 스테이지가 깔아 둔 장애물은 그대로 둔다.
func fill_new() -> void:
	var slots := PackedInt32Array()
	for i in w * h:
		if not hole[i] and col[i] == EMPTY:
			slots.append(i)
	for _try in 300:
		for i in slots:
			col[i] = EMPTY
			sp[i] = D.SP_NONE
		for i in slots:
			col[i] = _pick_no_match(i)
		if find_groups().is_empty() and has_move():
			return


## 왼쪽 위부터 채우므로 왼쪽 둘 · 위쪽 둘 · 왼쪽 위 네모만 보면 된다.
func _pick_no_match(i: int) -> int:
	var x := cx(i)
	var y := cy(i)
	var bad: Array[int] = []
	if x >= 2 and col[i - 1] == col[i - 2]:
		bad.append(col[i - 1])
	if y >= 2 and col[i - w] == col[i - 2 * w]:
		bad.append(col[i - w])
	if x >= 1 and y >= 1 and col[i - 1] == col[i - w] and col[i - 1] == col[i - w - 1]:
		bad.append(col[i - 1])
	var c := rand_color()
	for _k in 20:
		if not bad.has(c):
			break
		c = rand_color()
	return c

# ==================== 맞춤 찾기 ====================

## 3개 이상 이어진 줄. {cells: PackedInt32Array, horiz: bool}
func find_runs() -> Array:
	var runs := []
	for y in h:
		var x := 0
		while x < w:
			var s := x
			while x + 1 < w and _same(y * w + s, y * w + x + 1):
				x += 1
			if x - s >= 2:
				var cells := PackedInt32Array()
				for k in range(s, x + 1):
					cells.append(y * w + k)
				runs.append({"cells": cells, "horiz": true})
			x += 1
	for x in w:
		var y := 0
		while y < h:
			var s := y
			while y + 1 < h and _same(s * w + x, (y + 1) * w + x):
				y += 1
			if y - s >= 2:
				var cells := PackedInt32Array()
				for k in range(s, y + 1):
					cells.append(k * w + x)
				runs.append({"cells": cells, "horiz": false})
			y += 1
	return runs


## 2×2 네모. 날아가는 젤리를 만든다.
func find_squares() -> Array:
	var out := []
	for y in h - 1:
		for x in w - 1:
			var a := y * w + x
			if _same(a, a + 1) and _same(a, a + w) and _same(a, a + w + 1):
				out.append(PackedInt32Array([a, a + 1, a + w, a + w + 1]))
	return out


## 칸을 나눠 가진 줄 · 네모를 한 덩어리로 묶는다(L · T 자, 네모에 붙은 줄).
## {set: {칸: true}, runs: [...], square: bool}
func find_groups() -> Array:
	var shapes := find_runs()
	for s in find_squares():
		shapes.append({"cells": s, "sq": true})
	if shapes.is_empty():
		return []
	var parent := {}
	for s in shapes:
		var r0 := _root(parent, s.cells[0])
		for c in s.cells:
			var rc := _root(parent, c)
			if rc != r0:
				parent[rc] = r0
	var by_root := {}
	for s in shapes:
		var r := _root(parent, s.cells[0])
		if not by_root.has(r):
			by_root[r] = {"set": {}, "runs": [], "square": false}
		var g: Dictionary = by_root[r]
		if s.has("sq"):
			g.square = true
		else:
			g.runs.append(s)
		for c in s.cells:
			g.set[c] = true
	# 강철 젤리만으로 된 덩어리는 맞춤이 아니다 — 터질 것이 없어서 연쇄가 영원히 끝나지 않는다
	return by_root.values().filter(func(g):
		for c in g.set:
			if steel[c] == 0:
				return true
		return false)


func _root(parent: Dictionary, c: int) -> int:
	while parent.get(c, c) != c:
		c = parent[c]
	return c


## 덩어리가 만드는 특수 젤리와 그 자리. 바꾼 칸(`prefer`)이 덩어리 안이면 거기에 생긴다.
## 순서: 5 일자 → 무지개, 가로+세로 → 범위, 4 → 줄, 네모 → 날개.
func _special_for(g: Dictionary, prefer: PackedInt32Array) -> Dictionary:
	var longest: Dictionary = {}
	var has_h := false
	var has_v := false
	for r in g.runs:
		if longest.is_empty() or r.cells.size() > longest.cells.size():
			longest = r
		if r.horiz:
			has_h = true
		else:
			has_v = true
	var n: int = 0 if longest.is_empty() else longest.cells.size()
	var kind := D.SP_NONE
	if n >= 5:
		kind = D.SP_RAINBOW
	elif has_h and has_v:
		kind = D.SP_AREA
	elif n == 4:
		kind = D.SP_LINE_H if longest.horiz else D.SP_LINE_V
	elif g.square:
		kind = D.SP_FLY
	if kind == D.SP_NONE:
		return {}
	var at := -1
	for p in prefer:
		if g.set.has(p):
			at = p
	if at < 0 and kind == D.SP_AREA:
		# 가로 · 세로 줄이 만나는 칸
		var seen := {}
		for r in g.runs:
			for c in r.cells:
				if seen.has(c) and seen[c] != r.horiz:
					at = c
				seen[c] = r.horiz
	if at < 0 and not longest.is_empty():
		at = longest.cells[longest.cells.size() / 2]
	if at < 0:
		at = g.set.keys().min()
	# 강철 젤리 칸에는 특수 젤리를 만들지 않는다 — 강철은 안 터지고 그 자리에 남으므로, 거기 특수가 생기면
	# 강철 테 안의 젤리가 무지개 등으로 바뀌어 보였다(사용자 제보). 덩어리 안의 강철 아닌 칸으로 옮긴다
	if at >= 0 and steel[at] > 0:
		var best := -1
		var bd := 1 << 30
		for c in g.set:
			if steel[c] == 0:
				var dd := absi(cx(c) - cx(at)) + absi(cy(c) - cy(at))
				if dd < bd:
					bd = dd
					best = c
		if best < 0:
			return {}
		at = best
	return {"i": at, "sp": kind, "c": RAINBOW_C if kind == D.SP_RAINBOW else col[at]}

# ==================== 터뜨리기 ====================

## 한 번의 터짐을 계산하고 판에 적용한다.
##
## `prefer` = 방금 바꾼 두 칸(특수 젤리가 생길 자리). `forced` = 맞춤과 상관없이 칠 칸
## (특수끼리 바꾸기 · 보너스). `fired_pre` = 이미 발동한 것으로 칠 칸(조합으로 효과를 대신 낸 것).
##
## 맞춰서 터진 칸과 특수 젤리에 맞은 칸은 다르게 다룬다:
##   맞춤 — 그 칸의 사슬이 풀리거나 젤리가 터지고, **옆 칸**의 상자 · 초콜릿 · 얼음 · 몬스터가 한 번 맞는다
##   맞음 — 그 칸 자체가 맞는다(상자 한 겹 · 얼음 한 겹 · 사슬 · 몬스터 BLAST_DMG)
##
## 돌려주는 것 — 그리기 쪽이 이펙트를 고르는 데 쓴다:
##   cleared: [{i, c, sp}]     터진 젤리 (터지기 전 색과 종류)
##   fired:   [{i, sp, c, hit, to?}]  발동한 특수 젤리 · 그것이 친 칸 · 날개의 도착 칸
##   made:    [{i, sp, c}]     새로 생긴 특수 젤리
##   events:  [{type, i, ...}] 장애물 · 몬스터 (box ice chain sugar choco mon mon_dead)
##   groups:  맞춰진 덩어리 수
func resolve(prefer: PackedInt32Array = PackedInt32Array(), forced: PackedInt32Array = PackedInt32Array(),
		fired_pre: Dictionary = {}) -> Dictionary:
	var groups := find_groups()
	var kill := {}
	var made := []
	for g in groups:
		for c in g.set:
			kill[c] = true
		var s := _special_for(g, prefer)
		if not s.is_empty():
			made.append(s)
	var hit := {}
	for c in forced:
		if not hole[c]:
			hit[c] = true
	var painted := _paint_groups(groups)

	# 터지는 칸 · 맞은 칸에 특수 젤리가 있으면 발동 — 그것이 친 칸이 또 특수면 이어서 발동
	var fired := []
	var done := fired_pre.duplicate()
	var queue: Array = kill.keys()
	queue.append_array(hit.keys())
	var qi := 0
	while qi < queue.size():
		var c: int = queue[qi]
		qi += 1
		if sp[c] == D.SP_NONE or done.has(c) or not is_jelly(c):
			continue
		done[c] = true
		var tg := _blast(c, hit)
		var e := {"i": c, "sp": sp[c], "c": col[c], "hit": tg}
		if sp[c] == D.SP_FLY:
			e.to = tg[0] if tg.size() > 0 else c
		fired.append(e)
		for k in tg:
			if not hit.has(k):
				hit[k] = true
				queue.append(k)

	# 폭탄 · 무지개에 맞은 칸은 전부 칠한다(칠한 칸과 이어졌는지 안 본다 — "헷갈리니 전부" 로 정함).
	# 예전엔 맞춘 덩어리만 칠해서 판 전체를 칠하는 미션에 폭탄이 아무 도움이 안 됐다
	if paint.has(1):   # 물감 판에서만 — 배열은 어느 판이든 판 크기만큼 잡혀 있다
		for c in hit:
			if not hole[c] and paint[c] == 0:
				paint[c] = 1
				painted.append(c)
	var cleared := []
	var events := []
	var adj := {}
	var adjc := {}   ## 이웃 칸 → 옆에서 터진 색들 (로켓이 자기 색을 알아본다)
	for c in kill:
		for n in n4(c):
			if not kill.has(n) and not hit.has(n):
				adj[n] = int(adj.get(n, 0)) + 1
				if not adjc.has(n):
					adjc[n] = {}
				adjc[n][col[c]] = true
	for c in kill:
		if not hit.has(c):
			_damage(c, false, cleared, events)
	for c in hit:
		_damage(c, true, cleared, events)
	for n in adj:
		_touch(n, adj[n], events, adjc.get(n, {}))
	if not jar_c.is_empty():
		_fill_jars(cleared, events)
	if not lock_c.is_empty():
		var per := {}
		for e in cleared:
			per[e.c] = int(per.get(e.c, 0)) + 1
		for lk in lock_c.keys():
			var got := int(per.get(lock_c[lk], 0))
			if got > 0 and col[lk] == LOCK:
				lock_n[lk] = maxi(0, int(lock_n[lk]) - got)
				ev_lock(lk, events)
	for m in made:
		col[m.i] = m.c
		sp[m.i] = m.sp
		chain[m.i] = 0
	return {"cleared": cleared, "fired": fired, "made": made, "events": events, "groups": groups.size(),
			"painted": painted}


## 맞춰서 터진 칸(blast = false) 또는 특수 젤리에 맞은 칸(blast = true).
func _damage(c: int, blast: bool, cleared: Array, ev: Array) -> void:
	if hole[c]:
		return
	if cloud[c] > 0:
		cloud[c] = 0
		ev.append({"type": "cloud", "i": c})
	match col[c]:
		LOCK, STEAM:
			return
		PLANT:
			_burst_plant(c, ev)
			return
		MOLE:
			_hit_mole(c, ev)
			return
		FIRE:
			fire_t[c] = FIRE_LIT
			ev.append({"type": "fire", "i": c})
			return
		JAR:
			return
		GIFT:
			_open_gift(c, ev)
			return
		DECOY:
			col[c] = EMPTY
			ev.append({"type": "decoy", "i": c})
			return
		MON:
			_hurt_mon(c, D.BLAST_DMG, ev)
			return
		BOX:
			lay[c] -= 1
			ev.append({"type": "box", "i": c, "left": lay[c]})
			if lay[c] <= 0:
				col[c] = EMPTY
			return
		CHOCO:
			col[c] = EMPTY
			ev.append({"type": "choco", "i": c})
			return
		WIND:
			wind_armed[c] = true
			return
		CAPSULE:
			if blast:
				col[c] = EMPTY
				ev.append({"type": "capsule", "i": c})
			return
		LASER:
			charge[c] = LASER_FULL
			armed[c] = true
			ev.append({"type": "charge", "i": c, "n": LASER_FULL})
			return
		ROCKET:
			armed[c] = true
			return
		FRUIT, EMPTY, GEAR, PUSH:
			return
	if glass[c] > 0:
		glass[c] = 0
		ev.append({"type": "glass", "i": c})
		return
	if steel[c] > 0:
		return
	if web[c] > 0:
		web[c] -= 1
		web_broken = true
		ev.append({"type": "web", "i": c, "left": web[c]})
		return
	if ice[c] > 0:
		ice[c] -= 1
		ev.append({"type": "ice", "i": c, "left": ice[c]})
		return
	if chain[c] > 0:
		chain[c] = 0
		ev.append({"type": "chain", "i": c})
		return
	if sugar[c] > 0:
		sugar[c] -= 1
		ev.append({"type": "sugar", "i": c, "left": sugar[c]})
	if csugar[c] > 0 and (blast or col[c] == csugar[c] - 1):
		csugar[c] = 0
		ev.append({"type": "sugar", "i": c, "left": 0})
	cleared.append({"i": c, "c": col[c], "sp": sp[c]})
	dice[c] = 0
	col[c] = EMPTY
	sp[c] = D.SP_NONE


## 옆에서 젤리가 k 개 터졌다. 사슬은 옆 칸으로는 안 풀린다 — 그 젤리를 직접 맞춰야 한다.
## 구름은 옆에서 터진 것으로는 안 걷힌다 — 그러면 매치 한 번에 둘레가 다 걷혀서 미션이 되지 않았다.
func _touch(c: int, k: int, ev: Array, colors_: Dictionary = {}) -> void:
	match col[c]:
		GIFT:
			_open_gift(c, ev)
		DECOY:
			col[c] = EMPTY
			ev.append({"type": "decoy", "i": c})
		PLANT:
			_burst_plant(c, ev)
		MOLE:
			_hit_mole(c, ev)
		FIRE:
			fire_t[c] = FIRE_LIT
			ev.append({"type": "fire", "i": c})
		JAR:
			pass   # 그릇은 resolve 끝에서 둘레 두 칸을 따로 센다(_fill_jars)
		LASER:
			charge[c] = mini(LASER_FULL, int(charge.get(c, 0)) + 1)
			ev.append({"type": "charge", "i": c, "n": charge[c]})
			if charge[c] >= LASER_FULL:
				armed[c] = true
		ROCKET:
			if colors_.has(dev_color.get(c, -1)):
				armed[c] = true
		MON:
			_hurt_mon(c, k * D.ADJ_DMG, ev)
		BOX:
			lay[c] -= 1
			ev.append({"type": "box", "i": c, "left": lay[c]})
			if lay[c] <= 0:
				col[c] = EMPTY
		CHOCO:
			col[c] = EMPTY
			ev.append({"type": "choco", "i": c})
		WIND:
			wind_armed[c] = true
		_:
			if is_jelly(c) and glass[c] > 0:
				glass[c] = 0
				ev.append({"type": "glass", "i": c})
			elif is_jelly(c) and web[c] > 0:
				# 옆에서 터져도 한 겹 — 그 젤리를 직접 맞춰야만 풀리게 했더니 번지는 속도를 못 따라갔다
				web[c] -= 1
				web_broken = true
				ev.append({"type": "web", "i": c, "left": web[c]})
			elif is_jelly(c) and ice[c] > 0:
				ice[c] -= 1
				ev.append({"type": "ice", "i": c, "left": ice[c]})


## 덩어리 안이나 바로 옆에 칠한 칸이 있으면 덩어리 칸을 전부 칠한다. 돌려주는 것: 새로 칠한 칸.
func _paint_groups(groups: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for g in groups:
		var touch := false
		for c in g.set:
			if paint[c] > 0:
				touch = true
				break
			for n in n4(c):
				if paint[n] > 0:
					touch = true
					break
			if touch:
				break
		if touch:
			for c in g.set:
				if paint[c] == 0:
					paint[c] = 1
					out.append(c)
	return out


## 색 그릇 — 둘레 두 칸(체비쇼프) 안에서 터진 그 색 젤리만큼 찬다. 바로 옆으로만 세면
## 그 색이 그릇에 붙어서 터지는 일이 드물어 봇이 40판 중 1판을 깼다.
func _fill_jars(cleared: Array, ev: Array) -> void:
	for j in jar_c.keys():
		if col[j] != JAR:
			continue
		var got := 0
		for e in cleared:
			if e.c == jar_c[j] and maxi(absi(cx(e.i) - cx(j)), absi(cy(e.i) - cy(j))) <= 2:
				got += 1
		if got == 0:
			continue
		jar_n[j] = maxi(0, int(jar_n[j]) - got)
		if jar_n[j] <= 0:
			col[j] = EMPTY
			jar_c.erase(j)
			jar_n.erase(j)
			ev.append({"type": "jar_full", "i": j})
		else:
			ev.append({"type": "jar", "i": j, "left": jar_n[j]})


## 끈끈이 식물 — 사라지며 둘레 여덟 칸 젤리에 거미줄 한 겹.
func _burst_plant(c: int, ev: Array) -> void:
	col[c] = EMPTY
	var got := PackedInt32Array()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx(c) + dx
			var y := cy(c) + dy
			if (dx != 0 or dy != 0) and x >= 0 and y >= 0 and x < w and y < h:
				var j := y * w + x
				if is_jelly(j) and steel[j] == 0 and web[j] == 0:
					web[j] = 1
					got.append(j)
	ev.append({"type": "plant", "i": c, "cells": got})


## 두더지 — 한 턴에 한 대만 맞는다. 맞은 두더지는 턴 끝에 도망간다(mole_step).
func _hit_mole(c: int, ev: Array) -> void:
	if mole_hit.has(c):
		return
	mole_hit[c] = true
	mole_hp[c] = int(mole_hp[c]) - 1
	if mole_hp[c] <= 0:
		col[c] = EMPTY
		mole_hp.erase(c)
		mole_hit.erase(c)
		ev.append({"type": "mole_dead", "i": c})
	else:
		ev.append({"type": "mole", "i": c, "left": mole_hp[c]})


func ev_lock(lk: int, ev: Array) -> void:
	if int(lock_n[lk]) <= 0:
		col[lk] = EMPTY
		lock_c.erase(lk)
		lock_n.erase(lk)
		ev.append({"type": "lock_open", "i": lk})
	else:
		ev.append({"type": "lock", "i": lk, "left": lock_n[lk]})


## 선물 상자 — 절반은 특수 젤리, 30% 는 이동 +1, 20% 는 꽝(쿠키 상자 한 겹).
func _open_gift(c: int, ev: Array) -> void:
	var roll := rng.randf()
	if roll < 0.5:
		col[c] = rand_color()
		sp[c] = [D.SP_LINE_H, D.SP_LINE_V, D.SP_AREA, D.SP_FLY][rng.randi() % 4]
		ev.append({"type": "gift", "i": c, "what": "special"})
	elif roll < 0.8:
		col[c] = EMPTY
		gift_moves += 1
		ev.append({"type": "gift", "i": c, "what": "moves"})
	else:
		col[c] = BOX
		lay[c] = 1
		ev.append({"type": "gift", "i": c, "what": "box"})


func _hurt_mon(c: int, dmg: int, ev: Array) -> void:
	var m: Dictionary = mons[c]
	m.hp -= dmg
	ev.append({"type": "mon", "i": c, "dmg": dmg})
	if m.hp <= 0:
		mons.erase(c)
		col[c] = EMPTY
		# 도둑을 쓰러뜨리면 훔쳐 간 이동을 돌려받는다(Play 가 받아서 더한다)
		ev.append({"type": "mon_dead", "i": c, "kind": m.kind, "stolen": int(m.get("stolen", 0))})


## 특수 젤리 하나가 치는 칸. `taken` 은 이번 터짐에서 이미 맞은 칸 — 날개가 같은 곳을 또 노리지 않게.
func _blast(i: int, taken: Dictionary) -> PackedInt32Array:
	match sp[i]:
		D.SP_RAINBOW:
			# 바꾸기가 아니라 다른 폭발에 휘말렸을 때 — 판에 제일 많은 색을 지운다
			return cells_of(most_color())
		D.SP_FLY:
			var t := fly_target(i, taken)
			var out := PackedInt32Array([t])
			if fly_carry.has(i):
				out.append_array(shape(t, fly_carry[i]))
				fly_carry.erase(i)
			return out
	return shape(i, sp[i])


## 특수 효과가 닿는 칸. AREA 는 반지름 r.
func shape(i: int, kind: int, r: int = D.AREA_R) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := cx(i)
	var y := cy(i)
	match kind:
		D.SP_LINE_H:
			out.append(i)
			out.append_array(ray(i, Vector2i.RIGHT))
			out.append_array(ray(i, Vector2i.LEFT))
		D.SP_LINE_V:
			out.append(i)
			out.append_array(ray(i, Vector2i.DOWN))
			out.append_array(ray(i, Vector2i.UP))
		D.SP_AREA:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if x + dx >= 0 and x + dx < w and y + dy >= 0 and y + dy < h:
						out.append((y + dy) * w + x + dx)
		_:
			out.append(i)
	return _no_holes(out)


## 광선 — i 에서 d 쪽으로. 구멍은 건너 지나가고, 자기장 앞에서 멈추고, 파이프에서 꺾인다.
## i 자신은 넣지 않는다.
func ray(i: int, d: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := cx(i)
	var y := cy(i)
	var seen := {}
	for _guard in w * h * 2:
		x += d.x
		y += d.y
		if x < 0 or y < 0 or x >= w or y >= h:
			break
		var c := y * w + x
		# 파이프는 칸을 차지한다(그 칸엔 젤리가 없다) — 광선은 거기서 꺾이기만 하고 그 칸을 치지 않는다.
		# 구멍 검사보다 먼저 봐야 한다: 파이프 칸도 hole 이라 아래 continue 에 걸려 그냥 지나가 버린다
		if pipe[c] > 0:
			var pk := c * 8 + (d.x + 1) * 3 + (d.y + 1)
			if seen.has(pk):
				break
			seen[pk] = true
			d = pipe_turn(pipe[c], d)
			if d == Vector2i.ZERO:
				break
			continue
		if hole[c]:
			continue
		if field[c]:
			break
		var key := c * 8 + (d.x + 1) * 3 + (d.y + 1)
		if seen.has(key):
			break
		seen[key] = true
		out.append(c)
	return out


const PIPE_SIDES := [[], [Vector2i.LEFT, Vector2i.DOWN], [Vector2i.RIGHT, Vector2i.DOWN],
		[Vector2i.LEFT, Vector2i.UP], [Vector2i.RIGHT, Vector2i.UP]]


## 파이프 꺾임 — 들어온 쪽(-d)이 파이프의 한쪽 입이면 다른 입으로 나간다. 아니면 막힌다(ZERO).
func pipe_turn(kind: int, d: Vector2i) -> Vector2i:
	var sides: Array = PIPE_SIDES[kind]
	if -d == sides[0]:
		return sides[1]
	if -d == sides[1]:
		return sides[0]
	return Vector2i.ZERO


func _no_holes(cells: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in cells:
		if not hole[c]:
			out.append(c)
	return out


## 날개가 노릴 칸 — 몬스터 > 상자 · 초콜릿 · 캡슐 > 묶이거나 언 젤리 > 설탕막 위 젤리 > 아무 젤리.
## 캡슐은 특수 효과로만 깨지므로 날개가 노려 주지 않으면 거의 못 깬다(봇 승률 0~3% 였다).
func fly_target(from: int, taken: Dictionary) -> int:
	var tiers := [[], [], [], [], []]
	for i in w * h:
		if hole[i] or i == from or taken.has(i):
			continue
		var v := col[i]
		if v == MON:
			tiers[0].append(i)
		elif v == BOX or v == CHOCO or v == CAPSULE or v == GIFT or v == DECOY or v == PLANT or v == MOLE:
			tiers[1].append(i)
		elif is_jelly(i) and (ice[i] > 0 or chain[i] > 0):
			tiers[2].append(i)
		elif is_jelly(i) and sugar[i] > 0:
			tiers[3].append(i)
		elif is_jelly(i):
			tiers[4].append(i)
	for t in tiers:
		if not t.is_empty():
			return t[rng.randi() % t.size()]
	return from


func cells_of(c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w * h:
		if col[i] == c and not hole[i]:
			out.append(i)
	return out


func most_color() -> int:
	var n := PackedInt32Array()
	n.resize(JELLY_N)
	for i in w * h:
		if _matchable(i):
			n[col[i]] += 1
	var best := 0
	for c in JELLY_N:
		if n[c] > n[best]:
			best = c
	return best

# ==================== 바꾸기 ====================

func swap(a: int, b: int) -> void:
	var t := col[a]
	col[a] = col[b]
	col[b] = t
	t = sp[a]
	sp[a] = sp[b]
	sp[b] = t


## 맞춤 없이도 바로 터지는 바꾸기인가 — 무지개 + 젤리, 특수 + 특수.
func is_special_swap(a: int, b: int) -> bool:
	if not is_jelly(a) or not is_jelly(b):
		return false
	return sp[a] == D.SP_RAINBOW or sp[b] == D.SP_RAINBOW or (sp[a] != D.SP_NONE and sp[b] != D.SP_NONE)


func is_swap_valid(a: int, b: int) -> bool:
	if not adjacent(a, b) or not movable(a) or not movable(b):
		return false
	if col[a] == FRUIT and col[b] == FRUIT:
		return false
	if is_special_swap(a, b):
		return true
	swap(a, b)
	var ok := _match_at(a) or _match_at(b)
	swap(a, b)
	return ok


func _match_at(i: int) -> bool:
	if not _matchable(i):
		return false
	var x := cx(i)
	var y := cy(i)
	var n := 1
	var k := x - 1
	while k >= 0 and _same(i, y * w + k):
		n += 1
		k -= 1
	k = x + 1
	while k < w and _same(i, y * w + k):
		n += 1
		k += 1
	if n >= 3:
		return true
	n = 1
	k = y - 1
	while k >= 0 and _same(i, k * w + x):
		n += 1
		k -= 1
	k = y + 1
	while k < h and _same(i, k * w + x):
		n += 1
		k += 1
	if n >= 3:
		return true
	# 네모 넷 중 하나에 들어 있나
	for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var tx: int = x + d.x
		var ty: int = y + d.y
		if tx < 0 or ty < 0 or tx >= w - 1 or ty >= h - 1:
			continue
		var a := ty * w + tx
		if _same(a, a + 1) and _same(a, a + w) and _same(a, a + w + 1):
			return true
	return false


## 둘 수 있는 수 전부 [[a, b], ...].
func all_moves() -> Array:
	var out := []
	for i in w * h:
		if cx(i) + 1 < w and is_swap_valid(i, i + 1):
			out.append(PackedInt32Array([i, i + 1]))
		if cy(i) + 1 < h and is_swap_valid(i, i + w):
			out.append(PackedInt32Array([i, i + w]))
	return out


## 둘 수 있는 수 하나 [a, b]. 없으면 빈 배열.
func find_move() -> PackedInt32Array:
	for i in w * h:
		if cx(i) + 1 < w and is_swap_valid(i, i + 1):
			return PackedInt32Array([i, i + 1])
		if cy(i) + 1 < h and is_swap_valid(i, i + w):
			return PackedInt32Array([i, i + w])
	return PackedInt32Array()


func has_move() -> bool:
	return not find_move().is_empty()

# ==================== 떨어뜨리기 ====================

## 칸 i 로 떨어져 들어올 조각이 오는 칸. -2 = 하늘(새로 만든다), -1 = 막힘.
## 포탈 출구는 짝인 입구에서 받고, 포탈 입구 바로 밑 칸은 받지 못한다(입구의 조각은 포탈로 간다).
func feed(i: int) -> int:
	if portal.has(i):
		return portal[i]
	if cy(i) == 0:
		return -2
	var up := i - w
	if portal_in.has(up):
		return -1
	return up


## 빈 칸을 메운다. 위에서 곧장 못 오면(상자 · 몬스터 밑) **대각선 옆에서 미끄러져 들어온다** —
## 안 그러면 고정된 것 밑의 칸이 영원히 빈다. 구멍은 건너뛰어 지나가고, 포탈은 `feed` 를 따라간다.
##
## moves: [{from, to}] — 한 조각이 여러 번 옮겨 갈 수 있다(순서대로 따라가면 된다).
## spawns: [{to, n}] — 그 세로줄에서 n 번째로 새로 들어온 것. 판 위 n 칸에서 출발한다.
func fall() -> Dictionary:
	var moves := []
	var spawns := []
	var spawned := PackedInt32Array()
	spawned.resize(w)
	spawned.fill(0)
	for _guard in w * h * 4:
		var changed := false
		for x in w:
			for y in range(h - 1, -1, -1):
				var i := y * w + x
				if hole[i] or col[i] != EMPTY:
					continue
				var j := feed(i)
				var src := -1
				var hops := 0
				while j >= 0 and hops < w * h:
					hops += 1
					if hole[j] or col[j] == EMPTY:
						j = feed(j)
						continue
					if falls(j):
						src = j
					else:
						j = -1
					break
				if src >= 0:
					_move(src, i)
					moves.append({"from": src, "to": i})
					changed = true
				elif j == -2:
					col[i] = _spawn_piece()
					sp[i] = D.SP_NONE
					spawned[x] += 1
					spawns.append({"to": i, "n": spawned[x]})
					changed = true
		if changed:
			continue
		# 곧장 못 채운 칸 — 대각선 위에서 하나 미끄러뜨리고 다시 세로부터
		var slid := false
		for y in range(h - 1, 0, -1):
			for x in w:
				var i := y * w + x
				if hole[i] or col[i] != EMPTY:
					continue
				for dx in [-1, 1]:
					var xx: int = x + dx
					if xx < 0 or xx >= w:
						continue
					var j := (y - 1) * w + xx
					# 포탈 출구에서도 미끄러져 나가면 안 된다 — 출구 → 옆 줄 → 입구 → 출구로 같은 조각이 끝없이 돌았다
					# (아래에서 위로 올려 보내는 포탈, 공급 줄이 상자로 막혔을 때)
					if falls(j) and not portal_in.has(j) and not portal.has(j):
						_move(j, i)
						moves.append({"from": j, "to": i})
						slid = true
						break
				if slid:
					break
			if slid:
				break
		if not slid:
			break
	return {"moves": moves, "spawns": spawns}


func _move(from: int, to: int) -> void:
	col[to] = col[from]
	sp[to] = sp[from]
	chain[to] = chain[from]
	dice[to] = dice[from]
	web[to] = web[from]
	col[from] = EMPTY
	sp[from] = D.SP_NONE
	chain[from] = 0
	dice[from] = 0
	web[from] = 0


func _spawn_piece() -> int:
	if spawn_fruit > 0 and count(FRUIT) < D.FRUIT_MAX_ON and rng.randf() < D.FRUIT_CHANCE:
		spawn_fruit -= 1
		return FRUIT
	return rand_color()


## 판 자신의 난수로 섞는다. Array.shuffle() 은 엔진 전역 난수라 씨앗이 안 먹어서,
## 봇 측정이 돌릴 때마다 조금씩 달라졌다.
func _shuffled(a: Array) -> Array:
	var out := a.duplicate()
	for k in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = out[k]
		out[k] = out[j]
		out[j] = tmp
	return out


func rand_color() -> int:
	return palette[rng.randi() % palette.size()]


## 세로줄마다 맨 위 판 칸의 y. 새로 들어오는 것이 거기 위에서 출발한다.
func top_row(x: int) -> int:
	for y in h:
		if not hole[y * w + x]:
			return y
	return 0


## 맨 아래 칸 — 그 밑으로 판 칸이 없고, 포탈 입구도 아닌 칸. 열매는 여기 닿으면 거둔다.
func is_bottom(i: int) -> bool:
	if hole[i] or portal_in.has(i):
		return false
	var y := cy(i) + 1
	while y < h:
		if not hole[y * w + cx(i)]:
			return false
		y += 1
	return true


func collect_fruits() -> PackedInt32Array:
	var got := PackedInt32Array()
	for i in w * h:
		if col[i] == FRUIT and is_bottom(i):
			col[i] = EMPTY
			got.append(i)
	return got

# ==================== 턴 끝 ====================

## 턴 끝 장치(벨트 · 톱니 · 푸시 상자 · 바람개비)는 조각을 **한꺼번에 자리 바꿈**한다.
## 여러 장치가 차례로 움직여도 그림 쪽은 "처음 어디 있던 조각이 지금 어디 있나" 하나만 알면
## 되므로, `_orig` 에 출발 칸을 따라 적어 두었다가 `perm_end()` 가 [{from, to}] 로 돌려준다.
var _orig := PackedInt32Array()


func perm_begin() -> void:
	_orig.resize(w * h)
	for i in w * h:
		_orig[i] = i


func perm_end() -> Array:
	var out := []
	for i in w * h:
		if _orig[i] != i:
			out.append({"from": _orig[i], "to": i})
	return out


## [[from, to], ...] 를 동시에 옮긴다. 조각에 붙은 것(색 · 특수 · 사슬 · 얼음 · 상자 겹 ·
## 몬스터 · 장치 방향)은 따라가고, 바닥에 붙은 것(설탕막 · 벨트 · 포탈 · 구멍)은 남는다.
func _permute(pairs: Array) -> void:
	if pairs.is_empty():
		return
	if _orig.size() != w * h:
		perm_begin()
	var c0 := col.duplicate()
	var s0 := sp.duplicate()
	var ch0 := chain.duplicate()
	var i0 := ice.duplicate()
	var l0 := lay.duplicate()
	var o0 := _orig.duplicate()
	var g0 := glass.duplicate()
	var d0 := dice.duplicate()
	var dicts := [mons, gear_dir, push_dir, dev_dir, dev_color, charge, lock_c, lock_n, steam_cd, mole_hp, fire_t,
			jar_c, jar_n]
	var wb0 := web.duplicate()
	var st0 := steel.duplicate()
	var moved := []
	for d in dicts:
		var m := {}
		for p in pairs:
			if d.has(p[0]):
				m[p[1]] = d[p[0]]
		for p in pairs:
			d.erase(p[0])
		moved.append(m)
	for p in pairs:
		var a: int = p[0]
		var b: int = p[1]
		col[b] = c0[a]
		sp[b] = s0[a]
		chain[b] = ch0[a]
		ice[b] = i0[a]
		lay[b] = l0[a]
		glass[b] = g0[a]
		dice[b] = d0[a]
		web[b] = wb0[a]
		steel[b] = st0[a]
		_orig[b] = o0[a]
	for k in dicts.size():
		dicts[k].merge(moved[k], true)


## 벨트 — 벨트 칸의 조각이 화살표 방향으로 한 칸씩. 벨트는 반드시 고리여야 한다(검사가 본다).
func belts_step() -> bool:
	var pairs := []
	for i in w * h:
		if belt[i] > 0 and not hole[i]:
			pairs.append([i, belt_next(i)])
	_permute(pairs)
	return not pairs.is_empty()


func belt_next(i: int) -> int:
	match belt[i]:
		1:
			return i - w
		2:
			return i + 1
		3:
			return i + w
		4:
			return i - 1
	return i


const RING := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]


## 톱니 — 둘레 여덟 칸 중 **움직일 수 있는 조각만** 골라 그 순서대로 한 칸씩 돌린다.
## 고정된 것은 제자리에 두고 건너뛴다. 방향은 플레이어가 톱니를 눌러 바꾼다(이동 안 씀).
func gears_step() -> bool:
	var any := false
	for g in gear_dir.keys():
		var ring := []
		for d in RING:
			var x: int = cx(g) + d.x
			var y: int = cy(g) + d.y
			if x >= 0 and y >= 0 and x < w and y < h and movable(y * w + x):
				ring.append(y * w + x)
		if ring.size() < 2:
			continue
		var pairs := []
		var dir: int = gear_dir[g]
		for k in ring.size():
			pairs.append([ring[k], ring[(k + dir + ring.size()) % ring.size()]])
		_permute(pairs)
		any = true
	return any


## 푸시 상자 — 앞으로 한 칸 나아가며 앞줄을 밀어낸다. 줄 끝에서 밀려난 조각은 상자가 있던
## 자리로 돌아온다(빈 칸이 안 생긴다). 막혀서 못 가면 돌아선다.
func push_step() -> bool:
	var any := false
	for c in push_dir.keys():
		if not push_dir.has(c):
			continue
		var d: Vector2i = push_dir[c]
		var path := _push_path(c, d)
		if path.is_empty():
			d = -d
			push_dir[c] = d
			path = _push_path(c, d)
			if path.is_empty():
				continue
		var pairs := [[c, path[0]]]
		for k in path.size() - 1:
			pairs.append([path[k], path[k + 1]])
		pairs.append([path[path.size() - 1], c])
		_permute(pairs)
		any = true
	return any


func _push_path(c: int, d: Vector2i) -> Array:
	var path := []
	var x := cx(c) + d.x
	var y := cy(c) + d.y
	while x >= 0 and y >= 0 and x < w and y < h and movable(y * w + x):
		path.append(y * w + x)
		x += d.x
		y += d.y
	return path


## 바람개비 — 이번 턴에 옆에서 터지거나 맞았으면 둘레 2칸 안의 보통 젤리를 뒤섞는다.
func winds_step() -> bool:
	var any := false
	for c in wind_armed.keys():
		var cells := []
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var x := cx(c) + dx
				var y := cy(c) + dy
				if x >= 0 and y >= 0 and x < w and y < h and plain(y * w + x):
					cells.append(y * w + x)
		var to := _shuffled(cells)
		var pairs := []
		for k in cells.size():
			if cells[k] != to[k]:
				pairs.append([cells[k], to[k]])
		_permute(pairs)
		any = any or not pairs.is_empty()
	wind_armed.clear()
	return any


## 장전된 레이저 · 로켓을 쏜다. 레이저는 남아서 다시 차고, 로켓은 날아가 사라진다.
## 돌려주는 것: {cells: 맞은 칸 전부, shots: [{i, kind, cells}]} — 맞은 칸은 Play 가 터뜨린다.
func fire_step() -> Dictionary:
	var cells := PackedInt32Array()
	var shots := []
	for c in armed.keys():
		if col[c] != LASER and col[c] != ROCKET:
			continue
		var line := ray(c, dev_dir.get(c, Vector2i.RIGHT))
		shots.append({"i": c, "kind": "laser" if col[c] == LASER else "rocket", "cells": line})
		cells.append_array(line)
		if col[c] == LASER:
			charge[c] = 0
		else:
			# 로켓은 날아가 사라진다 — 그 칸도 맞은 칸에 넣어야 비운 자리가 떨어지기로 메워진다
			col[c] = EMPTY
			dev_dir.erase(c)
			dev_color.erase(c)
			cells.append(c)
	armed.clear()
	return {"cells": cells, "shots": shots}


## 솟는 줄 — 그 세로줄의 움직일 수 있는 조각을 한 칸씩 위로(맨 위는 맨 아래로).
func rise_step() -> void:
	for x in w:
		if rise[x] == 0:
			continue
		var cells := []
		for y in h:
			var i := y * w + x
			if movable(i):
				cells.append(i)
		if cells.size() < 2:
			continue
		var pairs := []
		for k in cells.size():
			pairs.append([cells[k], cells[(k - 1 + cells.size()) % cells.size()]])
		_permute(pairs)


## 맞은 두더지는 아무 보통 젤리와 자리를 바꿔 도망간다.
func mole_step() -> void:
	for c in mole_hit.keys():
		if col[c] != MOLE:
			continue
		var opts := []
		for i in w * h:
			if plain(i) and absi(cx(i) - cx(c)) + absi(cy(i) - cy(c)) >= 3:
				opts.append(i)
		if not opts.is_empty():
			var t: int = opts[rng.randi() % opts.size()]
			_permute([[c, t], [t, c]])
	mole_hit.clear()


## 모닥불 — 켜진 것은 한 턴씩 줄어든다. 돌려주는 것: 이번에 꺼진 칸.
## (레이저 발사가 fire_step 이라 이름을 따로 둔다)
func camp_step() -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in fire_t.keys():
		if int(fire_t[c]) > 0:
			fire_t[c] = int(fire_t[c]) - 1
			if fire_t[c] == 0:
				out.append(c)
	return out


## 거미줄 — 이번 턴에 한 겹도 못 풀었으면 거미줄 하나가 옆 보통 젤리로 번진다.
func web_spread() -> int:
	if web_broken:
		web_broken = false
		return -1
	var opts := []
	for i in w * h:
		if web[i] > 0:
			for n in n4(i):
				if plain(n):
					opts.append(n)
	if opts.is_empty():
		return -1
	var t: int = opts[rng.randi() % opts.size()]
	web[t] = 1
	return t


## 주사위 젤리 — 색을 새로 굴린다. 돌려주는 것: 바뀐 칸.
func dice_step() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in w * h:
		if dice[i] > 0 and is_jelly(i) and sp[i] == D.SP_NONE:
			col[i] = rand_color()
			out.append(i)
	return out


## 증기 기계 — STEAM_EVERY 턴마다 구름 없는 옆 칸 하나에 구름을 뿜는다. 돌려주는 것: [{i, to}]
func steam_step() -> Array:
	var out := []
	for c in steam_cd.keys():
		steam_cd[c] = int(steam_cd[c]) - 1
		if steam_cd[c] > 0:
			continue
		steam_cd[c] = STEAM_EVERY
		var opts := []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := cx(c) + dx
				var y := cy(c) + dy
				if (dx != 0 or dy != 0) and x >= 0 and y >= 0 and x < w and y < h:
					var j := y * w + x
					if not hole[j] and cloud[j] == 0 and col[j] != STEAM:
						opts.append(j)
		if not opts.is_empty():
			var t: int = opts[rng.randi() % opts.size()]
			cloud[t] = 1
			out.append({"i": c, "to": t})
	return out


## 이번 턴에 초콜릿을 하나도 못 부쉈으면 하나가 옆 젤리로 번진다.
func choco_spread() -> int:
	var opts := []
	for i in w * h:
		if col[i] == CHOCO:
			for n in n4(i):
				if plain(n):
					opts.append(n)
	if opts.is_empty():
		return -1
	var t: int = opts[rng.randi() % opts.size()]
	col[t] = CHOCO
	sp[t] = D.SP_NONE
	return t


## 몬스터 차례. 행동 한 턴 전에 노릴 칸을 정하고(`target`) 다음 턴에 그 칸에 한다.
## 그 사이에 칸이 바뀌어 대상이 아니게 되면 그 칸은 건너뛴다 — 그게 막는 방법이다.
## 돌려주는 것: [{type: "mon_act", i, kind, cells}] · 도둑은 {type: "steal", i}
func monster_turn() -> Array:
	var ev := []
	for c in mons.keys():
		var m: Dictionary = mons[c]
		m.cd -= 1
		if m.cd <= 0:
			var did := PackedInt32Array()
			for t in m.target:
				if m.kind == "dough" and plain(t):
					col[t] = BOX
					lay[t] = 1
					did.append(t)
				elif m.kind == "knot" and is_jelly(t) and chain[t] == 0 and ice[t] == 0:
					chain[t] = 1
					did.append(t)
				elif m.kind == "frost" and plain(t):
					ice[t] = 1
					did.append(t)
				elif m.kind == "ninja" and plain(t):
					col[t] = DECOY
					did.append(t)
				elif m.kind == "octo" and is_jelly(t) and steel[t] == 0 and web[t] < 2:
					web[t] = 2
					did.append(t)
				elif m.kind == "boss" and plain(t):
					col[t] = MON
					var sp_: Dictionary = D.MON["dough"]
					mons[t] = {"kind": "dough", "hp": D.BOSS_MINION_HP, "max": D.BOSS_MINION_HP, "every": sp_.every,
							"cd": sp_.every, "target": PackedInt32Array()}
					did.append(t)
				elif m.kind == "glutton" and is_jelly(t) and glass[t] == 0:
					# 특수 젤리를 먹으면 탈이 난다 — 그게 먹보를 잡는 길이다
					var bad := sp[t] != D.SP_NONE
					col[t] = EMPTY
					sp[t] = D.SP_NONE
					chain[t] = 0
					did.append(t)
					if bad:
						_hurt_mon(c, D.GLUTTON_SICK, ev)
						if not mons.has(c):
							break
					else:
						m.hp = mini(m.max, m.hp + 1)
					ev.append({"type": "eat", "i": c, "to": t, "bad": bad})
			if m.kind == "thief":
				m.stolen = int(m.get("stolen", 0)) + 1
				ev.append({"type": "steal", "i": c})
			ev.append({"type": "mon_act", "i": c, "kind": m.kind, "cells": did})
			if not mons.has(c):
				continue
			m.cd = m.every
			m.target = PackedInt32Array()
		elif m.cd == 1:
			m.target = _mon_pick(c, m.kind)
	return ev


func _mon_pick(c: int, kind: String) -> PackedInt32Array:
	var x := cx(c)
	var y := cy(c)
	var out := PackedInt32Array()
	match kind:
		"dough", "frost":
			var opts := []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if (dx != 0 or dy != 0) and xx >= 0 and yy >= 0 and xx < w and yy < h and plain(yy * w + xx):
						opts.append(yy * w + xx)
			if not opts.is_empty():
				out.append(opts[rng.randi() % opts.size()])
		"knot":
			var opts := []
			for xx in w:
				var i := y * w + xx
				if is_jelly(i) and chain[i] == 0 and ice[i] == 0:
					opts.append(i)
			opts.sort_custom(func(a, b): return absi(a - c) < absi(b - c))
			for k in mini(D.KNOT_MAX, opts.size()):
				out.append(opts[k])
		"thief":
			out.append(c)   # 노리는 것은 칸이 아니라 이동 수 — 자기 자리에 경고를 띄운다
		"octo":
			var opts := []
			for i in w * h:
				if is_jelly(i) and steel[i] == 0 and web[i] < 2 and absi(cx(i) - x) <= 2 and absi(cy(i) - y) <= 2:
					opts.append(i)
			for k in mini(2, opts.size()):
				var j: int = rng.randi() % opts.size()
				out.append(opts[j])
				opts.remove_at(j)
		"boss":
			var opts := []
			for i in w * h:
				if plain(i) and absi(cx(i) - x) + absi(cy(i) - y) <= 3:
					opts.append(i)
			if not opts.is_empty():
				out.append(opts[rng.randi() % opts.size()])
		"ninja":
			var opts := []
			for i in w * h:
				if plain(i):
					opts.append(i)
			if not opts.is_empty():
				out.append(opts[rng.randi() % opts.size()])
		"glutton":
			# 옆 젤리 중 하나 — 특수 젤리도 먹는다(그래서 일부러 옆에 특수를 놓을 수 있다)
			var opts := []
			for n in n4(c):
				if is_jelly(n) and glass[n] == 0:
					opts.append(n)
			if not opts.is_empty():
				out.append(opts[rng.randi() % opts.size()])
	return out

# ==================== 섞기 ====================

## 둘 수가 없을 때. 보통 젤리만 섞는다 — 특수 · 묶인 · 언 젤리와 장애물은 제자리.
## 돌려주는 것은 [{from, to}] — 그리기 쪽이 젤리를 날려 보낸다.
func shuffle() -> Array:
	var slots := PackedInt32Array()
	for i in w * h:
		if plain(i):
			slots.append(i)
	var orig := col.duplicate()
	for _try in 300:
		var order := _shuffled(Array(slots))
		for k in slots.size():
			col[slots[k]] = orig[order[k]]
		if find_groups().is_empty() and has_move():
			var out := []
			for k in slots.size():
				out.append({"from": order[k], "to": slots[k]})
			return out
	# 색 구성 자체가 막혔다 — 색을 새로 뽑는다
	for _try in 300:
		for i in slots:
			col[i] = rand_color()
		if find_groups().is_empty() and has_move():
			return []
	# 그래도 못 둔다(구멍 · 고정된 것이 많아 맞출 자리가 없다) — 움직일 이웃이 있는 젤리 하나를
	# 무지개로 바꾼다. 무지개는 맞춤 없이 바꿀 수 있으므로 이것으로 반드시 둘 수 있다.
	# 안 그러면 그 자리에서 판이 멈춘다(120번에서 실제로 그랬다).
	for i in slots:
		for n in n4(i):
			if movable(n) and col[n] != FRUIT:
				col[i] = RAINBOW_C
				sp[i] = D.SP_RAINBOW
				return []
	return []
