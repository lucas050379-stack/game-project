class_name StageGen
extends RefCounted

## 스테이지 생성기 — 판 번호를 씨앗으로 지도를 만든다(같은 번호는 언제나 같은 지도).
##
## **5판마다 새 장애물 하나**(`ORDER`), 그 5판에는 반드시 그 장애물이 들어간다. 블록 첫 판은 그것만,
## 뒤로 갈수록 앞에서 나온 장애물을 1~2종 섞는다. 39종 × 5 = 195판, 196~200 은 섞기만 하는 마무리.
## 손으로 짠 120판일 때는 같은 장애물 판끼리 지도가 거의 같아서(포탈 4판이 전부 같은 모양)
## "재미없다"는 말을 들었다 — 그래서 판 모양 · 장치 배치를 판마다 굴린다.
##
## 새 장애물을 넣으면: `ORDER` 에 한 줄 + `_place()` 에 case 하나 + `_goal_of()` 에 미션.
## 지켜야 할 것(판 로직이 요구):
## - 줄 하나를 고정된 것으로 막지 않는다(`_row_ok`) — 그 밑이 영영 안 채워진다.
## - 고정된 것은 열린 이웃이 둘 이상인 칸에만(`_room`) — 구멍에 갇히면 옆에서 못 친다.
## - 바닥 미션(설탕막 · 색 설탕막 · 거미줄 · 구름)은 젤리 칸에만 — 강철 · 고정물 밑이면 영영 못 깬다.
## - 벨트는 닫힌 고리, 포탈은 입구(아래가 구멍) · 출구(위가 구멍) 짝, 솟는 줄 · 벨트 칸에는 고정물 없음.

const ORDER := ["sugar", "box", "chain", "ice", "fruit", "choco", "dough", "knot", "belt", "portal",
		"gear", "wind", "push", "thief", "capsule", "field", "pipe", "laser", "rocket", "frost",
		"lock", "csugar", "glass", "gift", "cloud", "steam", "dice", "ninja", "glutton", "web",
		"plant", "steel", "mole", "rise", "campfire", "paint", "jar", "octo", "boss"]
const BLOCK := 5
const FINALE := 5
const MON_CH := {"dough": "D", "knot": "K", "thief": "T", "frost": "F", "ninja": "N", "glutton": "E",
		"octo": "H", "boss": "Y"}
## 판 구조를 통째로 쓰는 장치 — 한 판에 하나만(서로 지도를 다르게 요구한다)
const STRUCT := ["belt", "portal", "pipe", "rise", "paint"]
const FIXED := "123cDKTFNEHYGgW><^vOZRXPSpMUJ"

var rng := RandomNumberGenerator.new()
var w := 8
var h := 8
var g := []          ## g[y][x] 지도 글자
var ly := {}         ## 층 이름 → 2차원 글자
var rise := []
var goals := []
var palette: Array = [0, 1, 2, 3, 4]
var busy := {}       ## 구조 장치가 쓰는 칸 — 고정물 · 바닥을 올리지 않는다


static func count() -> int:
	return ORDER.size() * BLOCK + FINALE


static func build_all() -> Array:
	var L := []
	for n in count():
		L.append(StageGen.new().make(n + 1))
	return L


## 그 판의 새 장애물(블록 첫 판이면) — 마무리 판은 "".
static func intro_of(id: int) -> String:
	var b := (id - 1) / BLOCK
	return ORDER[b] if b < ORDER.size() else ""


var sid := 0
var sk := 0
var light := false

## 가볍게 만들 판 — 튜닝에서 이동 상한(45수)에 걸린 판(봇이 45수로도 목표 승률에 못 미침).
## 주인공 장애물 수를 블록 앞쪽 수준으로 낮추고 섞는 장애물을 하나 덜어낸다. 다른 판 지도는 안 바뀐다
## (판마다 씨앗이 따로라서). tune 을 다시 돌려 여전히 45 에 붙은 판이 있으면 여기에 더한다.
const LIGHTEN := [21, 24, 25, 27, 39, 54, 58, 59, 70, 74, 99, 100, 108, 109, 126, 129, 150, 152, 153, 180,
		191, 192, 193, 194, 195]


func make(id: int) -> Dictionary:
	rng.seed = id * 7919 + 13
	sid = id
	sk = (id - 1) % BLOCK
	light = LIGHTEN.has(id)
	var b := (id - 1) / BLOCK
	var k := (id - 1) % BLOCK
	var mains := []
	var extras := []
	if b < ORDER.size():
		mains = [ORDER[b]]
		var prev := ORDER.slice(0, b)
		var n_ex: int = [0, 1, 1, 2, 2][k]
		if ORDER[b] == "boss":
			# 체력 24 짜리에 무거운 미션을 더 얹으면 봇 40판 중 1판(192번) — 가벼운 것 하나만
			n_ex = mini(n_ex, 1)
			prev = ["sugar", "box", "chain", "ice", "choco"]
		if light:
			n_ex = maxi(0, n_ex - 1)
		extras = _pick_extras(prev, n_ex, mains)
	else:
		mains = _pick_extras(ORDER, 3 + (k % 2), [])
	var all := mains + extras
	if rng.randf() < 0.25 and b >= 4:
		palette = [[0, 1, 2, 3, 6], [0, 1, 2, 4, 6], [0, 1, 3, 4, 5]][rng.randi() % 3]

	# 판 크기 — 구조 장치가 있으면 그쪽이 정한다
	var size := 8
	if all.has("paint"):
		size = 7
	elif all.has("portal"):
		size = 9
	elif all.has("boss") or k == 4 or b >= ORDER.size():
		size = 9
	elif k == 0 and rng.randf() < 0.3:
		size = 7
	w = size
	h = size
	_blank()
	var structural := ""
	for o in all:
		if STRUCT.has(o):
			structural = o
	if structural == "":
		_mask()
	elif structural == "pipe" or structural == "paint":
		_mask(true)
	# 구조 장치 먼저(칸을 예약), 그다음 나머지
	if structural != "":
		_place(structural, k, structural in mains)
	for o in all:
		if o != structural:
			_place(o, k, o in mains)
	for o in mains:
		if goals.size() < 2:   # 마무리 판은 주인공이 3~4개라 여기도 막는다
			_goal_of(o, k, true)
	for o in extras:
		if goals.size() < 2:   # 셋이면 마무리 판(200번)이 봇 40판 중 4판 — 미션은 둘까지
			_goal_of(o, k, false)
	if goals.is_empty():
		goals.append(_collect())
	var st := {"rows": _rows(g), "moves": 22 + 3 * k, "goals": goals, "colors": palette.size()}
	if palette != [0, 1, 2, 3, 4]:
		st.palette = palette
	for name in ly:
		if _used(ly[name]):
			st[name] = _rows(ly[name])
	if not rise.is_empty():
		st.rise = rise
	return st


# ==================== 뼈대 ====================

func _blank() -> void:
	g = _grid(".")
	ly = {}
	for name in ["floor", "belt", "portal", "dir", "field", "pipe", "csugar", "cloud", "web", "paint"]:
		ly[name] = _grid(".")


func _grid(c: String) -> Array:
	var a := []
	for _y in h:
		var r := []
		r.resize(w)
		r.fill(c)
		a.append(r)
	return a


func _rows(a: Array) -> Array:
	var out := []
	for r in a:
		out.append("".join(r))
	return out


func _used(a: Array) -> bool:
	for r in a:
		for c in r:
			if c != ".":
				return true
	return false


## 판 모양 틀. corners_only 면 귀퉁이만 깎는 틀(구조 장치 판).
func _mask(corners_only: bool = false) -> void:
	var shapes: Array = {7: Stages.SHAPES7, 8: Stages.SHAPES8, 9: Stages.SHAPES9}[w]
	if corners_only:
		shapes = [shapes[0]]   # 팔각 — 모서리만
	# 네모 판도 섞어 둔다 — 전부 깎으면 그것도 단조롭다
	if rng.randf() < 0.2:
		return
	var m: Array = shapes[rng.randi() % shapes.size()]
	var flip := rng.randf() < 0.5
	for y in h:
		for x in w:
			var mx := w - 1 - x if flip else x
			if String(m[y])[mx] == "#":
				g[y][x] = "#"


func _in(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func _open(x: int, y: int) -> bool:
	return _in(x, y) and g[y][x] == "." and not busy.has(Vector2i(x, y))


## 열린 이웃 수 — 고정물은 둘 이상이어야 옆에서 맞출 수 있다
func _room(x: int, y: int) -> bool:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(x, y) + d
		# 얼음 · 유리 · 강철 · 사슬은 젤리라도 못 움직인다 — 열린 이웃으로 세면 톱니가 얼음 사이에 끼었다(54번)
		if _in(p.x, p.y) and ".fd".contains(g[p.y][p.x]):
			n += 1
	return n >= 2


func _open_n(x: int, y: int) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(x, y) + d
		if _in(p.x, p.y) and ".fd".contains(g[p.y][p.x]):
			n += 1
	return n


## 줄에 고정물이 너무 많으면 안 된다 — 한 줄이 통째로 막히면 그 밑이 안 채워진다
func _row_ok(y: int) -> bool:
	var fixed := 0
	var open := 0
	for x in w:
		if g[y][x] == "#":
			continue
		open += 1
		if FIXED.contains(g[y][x]):
			fixed += 1
	return fixed + 1 <= open - 2


## 칸 n 개 고르기. sym 이면 좌우 대칭으로 짝을 지어 넣는다(지도가 단정해 보인다).
## fixed 면 _room · _row_ok 를 지키고, rows 로 세로 범위를 좁힌다.
func _cells(n: int, fixed: bool, sym: bool = true, y0: int = 0, y1: int = 99, filt: Callable = Callable()) -> Array:
	var cand := []
	for y in range(maxi(0, y0), mini(h, y1 + 1)):
		for x in w:
			if _open(x, y) and (not filt.is_valid() or filt.call(x, y)):
				cand.append(Vector2i(x, y))
	_shuffle(cand)
	var out := []
	var taken := {}
	for c in cand:
		if out.size() >= n:
			break
		if taken.has(c):
			continue
		var pair := [c]
		var m := Vector2i(w - 1 - c.x, c.y)
		if fixed:
			g[c.y][c.x] = "@"   # 짝을 검사할 때 이쪽을 이미 놓인 것으로 본다(톱니 둘이 나란히 붙던 것)
		if sym and m != c and _open(m.x, m.y) and out.size() + 2 <= n and not taken.has(m) 				and (not filt.is_valid() or filt.call(m.x, m.y)):
			pair.append(m)
		if fixed:
			g[c.y][c.x] = "."
		var ok := true
		if fixed:
			for p in pair:
				if not _room(p.x, p.y) or not _row_ok(p.y):
					ok = false
		if not ok:
			continue
		for p in pair:
			taken[p] = true
			out.append(p)
			if fixed:
				g[p.y][p.x] = "@"   # 임시 — 다음 칸의 _room · _row_ok 가 이걸 고정물로 센다
	for p in out:
		if g[p.y][p.x] == "@":
			g[p.y][p.x] = "."
	return out


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## 고정물 바로 옆이 아닌 칸 — 얼음 · 사슬 · 유리 · 강철은 못 움직이는 젤리라, 고정물 옆에 깔면 그 고정물이
## 갇힌다(54번: 톱니 둘이 얼음 사이에 끼어 섞어도 둘 수가 없었다)
func _free(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(x, y) + d
		if _in(p.x, p.y) and FIXED.contains(g[p.y][p.x]):
			return false
	return true


func _put(cells: Array, ch: String) -> void:
	for c in cells:
		g[c.y][c.x] = ch


func _lay(name: String, cells: Array, ch: String) -> void:
	for c in cells:
		ly[name][c.y][c.x] = ch


## 바닥(설탕막 등)을 깔 덩어리 — 가운데 둘레의 직사각형 + 흩뿌린 칸. 젤리 칸에만.
func _patch(area: int) -> Array:
	var out := []
	var rw := clampi(int(sqrt(area)) + rng.randi_range(-1, 1), 2, w - 2)
	var rh := clampi(int(ceil(area / float(rw))), 2, h - 2)
	var x0 := rng.randi_range(0, w - rw)
	var y0 := rng.randi_range(1, h - rh)
	if rng.randf() < 0.5:
		x0 = (w - rw) / 2   # 대칭 덩어리
	for y in range(y0, y0 + rh):
		for x in range(x0, x0 + rw):
			if _open(x, y):
				out.append(Vector2i(x, y))
	return out


func _color() -> int:
	return palette[rng.randi() % palette.size()]


func _collect() -> Dictionary:
	var open := 0
	for y in h:
		for x in w:
			if g[y][x] != "#":
				open += 1
	return {"type": "collect", "n": int(open * rng.randf_range(0.45, 0.7)), "color": _color()}


func _has_goal(t: String) -> bool:
	for q in goals:
		if q.type == t:
			return true
	return false


# ==================== 장애물 배치 ====================

func _place(o: String, k: int, main: bool) -> void:
	var lv := k if main else 0   # 주인공일 때만 블록 뒤로 갈수록 늘린다
	if light:
		lv = maxi(0, lv - 2)
	match o:
		"sugar":
			var p := _patch(8 + 4 * lv)
			var two := lv >= 2
			for c in p:
				ly.floor[c.y][c.x] = "2" if two and rng.randf() < 0.4 else "1"
		"box":
			var cells := _cells(4 + 2 * lv, true)
			for c in cells:
				g[c.y][c.x] = str(rng.randi_range(1, mini(3, 1 + lv / 2 + (1 if rng.randf() < 0.3 else 0))))
		"chain":
			_put(_cells(4 + 2 * lv, false, true, 0, 99, _free), "l")
		"ice":
			for c in _cells(4 + 2 * lv, false, true, 0, 99, _free):
				g[c.y][c.x] = "I" if lv >= 3 and rng.randf() < 0.4 else "i"
		"fruit":
			_put(_cells(2 if lv < 3 else 3, false, false, 0, 1), "f")
		"choco":
			_put(_cells(3 + lv, true, true, h / 2, h - 1), "c")
		"dough", "knot", "thief", "frost", "ninja", "glutton", "octo", "boss":
			# 둘은 약한 몬스터만 — 문어발 둘(체력 14씩)에 거미줄까지 붙은 판(189번)은 봇 40판 중 3판
			var n := 2 if lv >= 4 and ["dough", "knot", "thief", "frost"].has(o) else 1
			if o == "boss":
				# 대왕꾸덕은 판 한가운데 — 가장자리에 붙으면 옆에서 칠 칸이 줄어 봇 0/40 이 나왔다(195번)
				var c := Vector2i(w / 2, h / 2)
				g[c.y][c.x] = "Y"
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if g[c.y + dy][c.x + dx] == "#":
							g[c.y + dy][c.x + dx] = "."   # 가운데 구멍 틀이면 구멍에 둘러싸였다(195번)
			else:
				_put(_cells(n, true, n == 2, 1, h - 3), MON_CH[o])
		"belt":
			_belts()
		"portal":
			_portals()
		"gear":
			# 톱니는 둘레를 돌리는 장치 — 열린 이웃 셋 이상, 서로 붙이지 않는다(54번: 좁은 통로에 둘이 나란히 끼어 막혔다)
			_put(_cells(1 + lv / 2, true, true, 2, h - 3, func(x, y): return x > 0 and x < w - 1 and _open_n(x, y) >= 3 					and not "Gg@".contains(g[y][x - 1]) and not "Gg@".contains(g[y][x + 1])), "G" if rng.randf() < 0.5 else "g")
		"wind":
			_put(_cells(1 + lv / 3, true, true, 1, h - 2), "W")
		"push":
			var cs := _cells(1 + lv / 3, true, false, 1, h - 2, func(x, y): return x == 0 or x == w - 1)
			if cs.is_empty():
				cs = _cells(1, true, false, 1, h - 2)   # 틀이 가장자리를 깎았으면 아무 데나 — 가운데 쪽을 본다
			for c in cs:
				g[c.y][c.x] = ">" if c.x < w / 2 else "<"
		"capsule":
			_put(_cells(2 + lv / 2, true), "O")   # 특수로만 깨진다 — 여섯이면 너무 무겁다(73번)
		"field":
			_fields()
		"pipe":
			_pipes()
		"laser", "rocket":
			var ch := "Z" if o == "laser" else "R"
			var cs := _cells(2, true, false, 0, h - 1, func(x, y): return x == 0 or x == w - 1 or y == h - 1)
			if cs.is_empty():
				cs = _cells(2, true, false)
			for c in cs:
				g[c.y][c.x] = ch
				if c.y >= h - 2 and c.x > 0 and c.x < w - 1:
					ly.dir[c.y][c.x] = "^"
				else:
					ly.dir[c.y][c.x] = ">" if c.x < w / 2 else "<"
		"lock":
			_put(_cells(mini(5, 2 + lv / 2 + 1), true), "X")
		"csugar":
			for c in _patch(6 + 2 * lv):
				ly.csugar[c.y][c.x] = str(_color())
		"glass":
			for c in _cells(2 + lv, false, true, 0, 99, _free):
				g[c.y][c.x] = "q" if rng.randf() < 0.6 else "Q"
		"gift":
			_put(_cells(3 + lv, true), "P")
		"cloud":
			_lay("cloud", _patch(8 + 4 * lv), "o")
		"steam":
			_put(_cells(1 + lv / 3, true, true, 1, h - 2), "S")
		"dice":
			_put(_cells(4 + 2 * lv, false), "d")
		"web":
			for c in _patch(6 + 3 * lv):
				ly.web[c.y][c.x] = "2" if lv >= 2 and rng.randf() < 0.35 else "1"
		"plant":
			_put(_cells(2 + lv / 2, true), "p")
		"steel":
			# 강철은 바닥 미션 칸 위에 두면 그 칸을 영영 못 깬다(104번에서 겪었다)
			for c in _cells(3 + lv, false, true, 0, 99, func(x, y): return _free(x, y) and ly.floor[y][x] == "." and ly.csugar[y][x] == "." \
					and ly.web[y][x] == "." and ly.cloud[y][x] == "."):
				g[c.y][c.x] = "s"
		"mole":
			_put(_cells(2 + lv / 3, true, true, 1, h - 2), "M")
		"rise":
			_rises()
		"campfire":
			_put(_cells(2 + 2 * (lv / 3), true, true), "U")   # 전부 한꺼번에 켜야 한다 — 여섯은 거의 못 깬다(175번)
		"paint":
			_lay("paint", _cells(2 + (lv + 1) / 2, false), "p")
		"jar":
			_put(_cells(2 + lv / 3, true, true, 1, h - 2), "J")


## 벨트 — 직사각형 고리 1~2개. 모양 · 자리 · 방향을 굴린다.
func _belts() -> void:
	var kinds := [[1, 1, w - 2, h - 2], [0, 0, w - 1, h - 1], [1, 1, 3, 3], [2, 1, w - 3, 3], [1, 2, 2, h - 3]]
	var r: Array = kinds[rng.randi() % kinds.size()]
	_belt_ring(r[0], r[1], r[2], r[3], rng.randf() < 0.5)
	if r[2] - r[0] <= 2 or r[3] - r[1] <= 2:
		# 작은 고리면 반대편에 하나 더(거울)
		_belt_ring(w - 1 - r[2], h - 1 - r[3], w - 1 - r[0], h - 1 - r[1], rng.randf() < 0.5)


func _belt_ring(x0: int, y0: int, x1: int, y1: int, cw: bool) -> void:
	var path := []
	for x in range(x0, x1):
		path.append(Vector2i(x, y0))
	for y in range(y0, y1):
		path.append(Vector2i(x1, y))
	for x in range(x1, x0, -1):
		path.append(Vector2i(x, y1))
	for y in range(y1, y0, -1):
		path.append(Vector2i(x0, y))
	if not cw:
		path.reverse()
	for i in path.size():
		if busy.has(path[i]):
			return
	for i in path.size():
		var a: Vector2i = path[i]
		var b: Vector2i = path[(i + 1) % path.size()]
		var d := b - a
		g[a.y][a.x] = "."
		ly.belt[a.y][a.x] = {Vector2i.RIGHT: ">", Vector2i.LEFT: "<", Vector2i.UP: "^", Vector2i.DOWN: "v"}[d]
		busy[a] = true


## 포탈 — 다섯 형태(사용자 요청). 포탈 블록에서는 판마다 순서대로, 다른 블록에서 섞일 때는 아무거나.
##   0 두 구역 — 왼쪽 맨 아래 4칸 입구 → 오른쪽 맨 위 4칸 출구
##   1 Z 자 4구역 — 왼쪽 위 → 오른쪽 위 → 왼쪽 아래 → 오른쪽 아래
##   2 거꾸로 — 가로로 나란한 입구 넷, 바로 밑 출구는 반대 순서
##   3 사선 — 오른쪽 아래 "\" 사선 입구 넷 → 왼쪽 위 "\" 사선 출구 넷(아래에서 위로)
##   4 위로 — 판 중간 구멍 밑 "주머니" 를 옆 줄 맨 아래 젤리가 포탈을 타고 올라와 채운다
## 입구는 아래가 구멍(또는 판 끝), 출구는 위가 구멍(또는 판 끝)이어야 한다 — 아니면 그 칸이 두 군데서 받는다.
## 판은 9×9 (make 가 정한다).
const PORTAL_KINDS := 5
func _portals() -> void:
	var kind := sk if intro_of(sid) == "portal" else rng.randi() % PORTAL_KINDS
	# 두 구역 · Z 자는 방향이 곧 형태다(왼쪽 아래 → 오른쪽 위, Z 순서) — 뒤집지 않는다
	var flip := rng.randf() < 0.5 and kind != 0 and kind != 1 and kind != 3
	var li := 0
	match kind:
		0:
			var mid := w / 2
			for y in h:
				g[y][_fx(mid, flip)] = "#"
			for i in 4:
				_portal_pair(_fx(i, flip), h - 1, _fx(w - 4 + i, flip), 0, _letter(li))
				li += 1
		1:
			var c := w / 2
			for i in w:
				g[c][i] = "#"
				g[i][c] = "#"
			var q := c   # 구역 한 변
			for i in q:
				_portal_pair(_fx(i, flip), c - 1, _fx(c + 1 + i, flip), 0, _letter(li))          # 왼위 → 오위
				_portal_pair(_fx(c + 1 + i, flip), c - 1, _fx(i, flip), c + 1, _letter(li + 1))  # 오위 → 왼아래
				_portal_pair(_fx(i, flip), h - 1, _fx(c + 1 + i, flip), c + 1, _letter(li + 2))  # 왼아래 → 오아래
				li += 3
		2:
			var r := rng.randi_range(2, h - 4)
			var x0 := (w - 4) / 2
			for i in 4:
				g[r + 1][x0 + i] = "#"
			for i in 4:
				_portal_pair(x0 + i, r, x0 + 3 - i, r + 2, _letter(li))
				li += 1
		3:
			# 오른쪽 아래 "\" 사선 입구 넷 → 왼쪽 위 "\" 사선 출구 넷(사용자가 정한 대로 — 왼쪽이 위, 오른쪽이 아래).
			# 젤리가 아래에서 위로 올라간다. 입구 밑 · 출구 위가 구멍. 입구가 선 줄은 통째로 비워 둔다
			# ("위로" 형태처럼 공급 줄이 막히면 조각이 대각선으로 새어 돈다).
			for i in 4:
				var ex := w - 4 + i
				var ey := h - 5 + i
				var ox := i
				var oy := i
				g[ey + 1][ex] = "#"
				if oy > 0:
					g[oy - 1][ox] = "#"
				_portal_pair(ex, ey, ox, oy, _letter(li))
				for y in ey:
					busy[Vector2i(ex, y)] = true
				li += 1
		4:
			var hy := h / 2 - 1
			for px in range(1, w, 2):
				var pocket := _fx(px, flip)
				var feeder := _fx(px - 1, flip)
				g[hy][pocket] = "#"
				_portal_pair(feeder, h - 1, pocket, hy + 1, _letter(li))
				# 공급 줄은 통째로 비워 둔다 — 막히면 조각이 대각선으로 새어 출구 · 입구 사이를 돌았다(50번)
				for y in h:
					busy[Vector2i(feeder, y)] = true
				li += 1


func _letter(i: int) -> String:
	return "abcdefghijklmnop"[i]


func _fx(x: int, flip: bool) -> int:
	return w - 1 - x if flip else x


func _portal_pair(ex: int, ey: int, ox: int, oy: int, l: String) -> void:
	ly.portal[ey][ex] = l
	ly.portal[oy][ox] = l.to_upper()
	g[ey][ex] = "."
	g[oy][ox] = "."
	busy[Vector2i(ex, ey)] = true
	busy[Vector2i(ox, oy)] = true


## 자기장 — 세로 띠 · 가로 띠 · 바둑 점 중 하나
func _fields() -> void:
	var kind := rng.randi() % 3
	var cells := []
	match kind:
		0:
			var x := w / 2 - (1 if rng.randf() < 0.5 else 0)
			for y in range(1, h - 1):
				cells.append(Vector2i(x, y))
		1:
			var y := h / 2
			for x in w:
				if x < w / 2 - 1 or x > w / 2:
					cells.append(Vector2i(x, y))
		2:
			for y in range(1, h - 1, 2):
				for x in range(1 + (y / 2) % 2, w - 1, 3):
					cells.append(Vector2i(x, y))
	for c in cells:
		if g[c.y][c.x] != "#":
			ly.field[c.y][c.x] = "m"


## 파이프 — 칸을 차지한다. 판 네 귀퉁이 또는 안쪽 직사각형의 네 귀퉁이(광선이 그 둘레를 돈다)
func _pipes() -> void:
	var inset := 0 if rng.randf() < 0.5 else rng.randi_range(1, 2)
	var x0 := inset
	var y0 := inset
	var x1 := w - 1 - inset
	var y1 := h - 1 - inset
	var corners := {Vector2i(x0, y0): "F", Vector2i(x1, y0): "7", Vector2i(x0, y1): "L", Vector2i(x1, y1): "J"}
	if rng.randf() < 0.35:
		# 위 두 귀퉁이만 — 광선이 위에서 U 턴
		corners.erase(Vector2i(x0, y1))
		corners.erase(Vector2i(x1, y1))
	for c in corners:
		g[c.y][c.x] = "."
		ly.pipe[c.y][c.x] = corners[c]
		busy[c] = true


## 솟는 줄 — 1~3개 세로줄, 그 줄은 통째로 젤리만
func _rises() -> void:
	var cols := []
	for x in range(1, w - 1):
		cols.append(x)
	_shuffle(cols)
	var n := rng.randi_range(1, 3)
	for x in cols:
		if rise.size() >= n:
			break
		if rise.has(x - 1) or rise.has(x + 1):
			continue
		rise.append(x)
		for y in h:
			g[y][x] = "."
			busy[Vector2i(x, y)] = true
	rise.sort()


# ==================== 미션 ====================

func _goal_of(o: String, k: int, main: bool) -> void:
	var t := ""
	match o:
		"sugar", "csugar":
			t = "sugar"
		"box", "chain", "ice", "choco", "capsule", "lock", "cloud", "web", "mole", "paint", "jar":
			t = o
		"fruit":
			if not _has_goal("fruit"):
				var n := 0
				for r in g:
					for c in r:
						if c == "f":
							n += 1
				if n > 0:
					goals.append({"type": "fruit", "n": n, "color": -1})
			return
		"campfire":
			t = "fire"
		"steam":
			t = "cloud"
		"plant":
			t = "web"
		"dough", "knot", "thief", "frost", "ninja", "glutton", "octo", "boss":
			t = "monster"
		_:
			# 미션이 없는 장치(벨트 · 포탈 · 톱니 · 바람개비 · 레이저 …) — 주인공이면 모으기
			if main and not _has_goal("collect"):
				goals.append(_collect())
			return
	# 바닥 미션은 그 바닥이 실제로 깔렸을 때만(대상이 0 이면 판이 시작하자마자 끝난다)
	if t == "cloud" and not _used(ly.cloud):
		_lay("cloud", _patch(8), "o")
	if t == "web" and not _used(ly.web):
		for c in _patch(6):
			ly.web[c.y][c.x] = "1"
	if not _present(t):
		return
	if not _has_goal(t):
		goals.append({"type": t, "n": 0, "color": -1})


## 섞을 장애물 n 개 — 구조 장치는 한 판에 하나, 몬스터는 둘까지.
func _pick_extras(pool: Array, n: int, mains: Array) -> Array:
	var cand := pool.duplicate()
	_shuffle(cand)
	var out := []
	var has_struct := false
	var mons := 0
	for o in mains:
		if STRUCT.has(o):
			has_struct = true
		if MON_CH.has(o):
			mons += 1
	for o in cand:
		if out.size() >= n:
			break
		if mains.has(o):
			continue
		if STRUCT.has(o):
			if has_struct:
				continue
			has_struct = true
		if MON_CH.has(o):
			if mons >= 2 or o == "boss" or mains.has("boss"):
				continue
			mons += 1
		out.append(o)
	return out


## 그 미션의 대상이 판에 실제로 있나 — 0 이면 판이 시작하자마자 이긴다.
func _present(t: String) -> bool:
	var chars := {"box": "123", "chain": "l", "ice": "iI", "choco": "c", "capsule": "O", "lock": "X", "mole": "M",
			"jar": "J", "fire": "U", "monster": "DKTFNEHY"}
	if chars.has(t):
		for r in g:
			for c in r:
				if String(chars[t]).contains(c):
					return true
		return false
	match t:
		"sugar":
			return _used(ly.floor) or _used(ly.csugar)
		"cloud":
			return _used(ly.cloud)
		"web":
			return _used(ly.web)
		"paint":
			return _used(ly.paint)
	return true
