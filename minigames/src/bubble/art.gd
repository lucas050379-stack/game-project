class_name BbArt
extends RefCounted

## 물거품처럼 사라져줘 그림 — GPT 그림(`art/bubble/bb_*.png`, tools/bubble_art.py)을 얹는다. 그림이 없으면 둥근 모양으로 대신(돌기는 한다).
## 좌표는 화면 좌표. 인어 · 악당은 발밑이 기준, 거품 · 물건은 가운데가 기준.

const INK := Color8(70, 40, 40)
const HEAD := Color8(255, 252, 244)
const SEA := Color8(40, 110, 170)
const PANEL := Color8(24, 60, 100)
const GOLD := Color8(255, 214, 110)
const P_COL := [Color8(255, 140, 170), Color8(90, 210, 220)]   ## 1P 분홍 · 2P 청록

static var _cache := {}


static func img(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/bubble/%s.png" % name
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = tex
	return tex


## 고전 거품 아케이드처럼 몸이 2 × 2 칸을 꽉 채우게(사용자 11-11 "몬스터가 맵에서 차지하는 비율이 다르다") — 기준 칸(ref)의 **그림이 있는 곳**의
## 긴 변이 box 가 되는 판 높이. 같은 캐릭터의 다른 칸도 이 높이로 그려 크기가 안 출렁인다.


static func fit_h(ref: String, box: float) -> float:
	var u: Array = BbFit.USED.get(ref, [])   # 크기는 tools/bubble_art.py 가 재 둔 것(웹에서 그림을 읽어 재지 않게)
	if u.is_empty():
		return box
	return float(u[0]) * box / maxf(1.0, maxf(float(u[1]), float(u[2])))


## 그림을 발밑(foot) 기준, 키 h 로. flip 이면 좌우를 뒤집는다(그림은 오른쪽을 본다).
static func sprite(ci: CanvasItem, tex: Texture2D, foot: Vector2, h: float, flip: bool, mod: Color = Color.WHITE) -> void:
	var s := tex.get_size()
	var w := s.x * h / s.y
	ci.draw_set_transform(foot, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, mod)
	ci.draw_set_transform(Vector2.ZERO)


## 인어 — who 0 분홍 인어 · 1 청록 인어. pose: stand · run · jump · shot · hurt · win
static func mermaid(ci: CanvasItem, who: int, foot: Vector2, dir: int, pose: String, t: float, mod: Color = Color.WHITE) -> void:
	var base := "bb_mer" if who == 0 else "bb_mer2"
	var name := ""
	match pose:
		"run":
			name = "%s_a_%d" % [base, 1 + int(t * 9.0) % 2]
		"jump":
			name = base + "_a_3"
		"shot":
			name = base + "_b_0"
		"hurt":
			name = base + "_b_1"
		"win":
			name = base + "_b_2"
		"wave":
			name = base + "_b_3"
		_:
			name = base + "_a_0"
	var tex := img(name)
	var bob := sin(t * 5.0) * 1.5 if pose == "stand" else 0.0
	if tex != null:
		sprite(ci, tex, foot + Vector2(0, bob), fit_h(base + "_a_0", BbD.T * 2.4), dir < 0, mod)
	else:
		ci.draw_circle(foot + Vector2(0, -BbD.T), BbD.T * 0.9, (P_COL[who] as Color) * mod)


## 악당 — 걷기 두 칸 번갈아 · 화나면 넷째 칸.
static func enemy(ci: CanvasItem, k: int, foot: Vector2, dir: int, angry: bool, t: float) -> void:
	var f := 3 if angry else int(t * (10.0 if angry else 6.0)) % 2
	var tex := img("bb_en_%d_%d" % [k, f])
	if tex != null:
		sprite(ci, tex, foot, fit_h("bb_en_%d_0" % k, BbD.T * 2.15), dir < 0)
	else:
		ci.draw_circle(foot + Vector2(0, -BbD.T * 0.8), BbD.T * 0.8, Color8(240, 120, 90) if angry else Color8(240, 190, 90))


## 거품 하나 — 갇힌 악당(trap)이 있으면 안에 놀란 얼굴로. red(0~1)면 빨갛게 깜박인다.
static func bubble(ci: CanvasItem, c: Vector2, r: float, trap: int, red: float, t: float, word: int = -1, rainbow: bool = false) -> void:
	var wob := Vector2(1.0 + sin(t * 6.0) * 0.04, 1.0 - sin(t * 6.0) * 0.04)
	if trap >= 0:
		var tex := img("bb_en_%d_2" % trap)
		if tex != null:
			ci.draw_set_transform(c + Vector2(0, sin(t * 9.0) * 2.0), sin(t * 4.0) * 0.15, Vector2.ONE)
			var s := tex.get_size()
			var h := r * 1.5
			ci.draw_texture_rect(tex, Rect2(-s.x * h / s.y * 0.5, -h * 0.5, s.x * h / s.y, h), false)
			ci.draw_set_transform(Vector2.ZERO)
	if word >= 0:
		ci.draw_circle(c, r * 0.8, Color(BbD.WORD_COL[word], 0.85))
		G2.text_mid(ci, c + Vector2(0, 1), String(BbD.WORD[word]), r * 1.1, HEAD, 4, INK)
	var tint := Color(1, 1, 1, 0.82 if trap < 0 else 0.45)   # 갇힌 악당이 잘 보이게 거품을 옅게
	if red > 0.0 and fmod(t * (4.0 + red * 8.0), 1.0) < 0.5:
		tint = Color(1.0, 0.45, 0.45, 0.9)
	if rainbow:
		tint = Color.from_hsv(fmod(t * 1.5, 1.0), 0.5, 1.0, 0.9)
	var tex := img("bb_bubble")
	if tex != null:
		ci.draw_set_transform(c, 0.0, wob)
		ci.draw_texture_rect(tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, tint)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_circle(c, r, Color(0.7, 0.9, 1.0, 0.25 * tint.a))
		ci.draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)


static func item(ci: CanvasItem, kind: String, v: int, c: Vector2, t: float, blink: bool = false) -> void:
	if blink and fmod(t * 8.0, 1.0) < 0.4:
		return
	var tex := img(("bb_items_%d" if kind == "item" else "bb_powers_%d") % v)
	var h := BbD.T * (1.3 if kind == "item" else 1.5)
	var bob := sin(t * 4.0 + c.x) * 2.0 if kind == "power" else 0.0
	if tex != null:
		sprite(ci, tex, c + Vector2(0, h * 0.5 + bob), h, false)
	else:
		ci.draw_circle(c, h * 0.4, GOLD)


static func boss(ci: CanvasItem, k: int, c: Vector2, dir: int, hit: float, t: float) -> void:
	var tex := img("bb_boss_%d" % k)
	var sz := BbD.BOSS_SIZE * 1.15
	var mod := Color(1, 0.6, 0.6) if hit > 0.0 else Color.WHITE
	if tex != null:
		var s := tex.get_size()
		var k2 := sz / maxf(s.x, s.y)
		ci.draw_set_transform(c + Vector2(0, sin(t * 3.0) * 4.0), 0.0, Vector2(k2 * (-1.0 if dir > 0 else 1.0), k2))   # 그림은 왼쪽을 본다
		ci.draw_texture_rect(tex, Rect2(-s * 0.5, s), false, mod)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_circle(c, sz * 0.45, Color8(170, 90, 200) * mod)


static func shark(ci: CanvasItem, c: Vector2, dir: int, t: float) -> void:
	var tex := img("bb_shark")
	if tex == null:
		ci.draw_circle(c, BbD.T * 1.3, Color8(60, 80, 110))
		return
	var s := tex.get_size()
	var k := BbD.T * 3.6 / s.x
	ci.draw_set_transform(c + Vector2(0, sin(t * 2.0) * 5.0), 0.0, Vector2(k * (-1.0 if dir > 0 else 1.0), k))
	ci.draw_texture_rect(tex, Rect2(-s * 0.5, s), false, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO)


## 판의 칸 — 이어진 '#' 를 한 덩어리로 발판 그림(양 끝 둥근 막대)을 늘려 그린다. 양옆 벽은 두 칸 폭 덩어리를 줄마다 쌓는다.
static func tiles(ci: CanvasItem, grid: Array, theme: int, o: Vector2) -> void:
	var tex := img("bb_tile_%d" % theme)
	for r in grid.size():
		var row := String(grid[r])
		var c := 2
		while c < BbD.COLS - 2:   # 양옆 벽 칸은 빼고(아래에서 한 줄로)
			if row[c] != "#":
				c += 1
				continue
			var s := c
			while c < BbD.COLS - 2 and row[c] == "#":
				c += 1
			_bar(ci, tex, Rect2(o.x + s * BbD.T, o.y + r * BbD.T, (c - s) * BbD.T, BbD.T), theme)
	# 양옆 벽 — 두 칸 폭 막대 하나를 세워서(줄마다 쌓으면 투박했다, 사용자 11-11). 막대를 90도 돌려 그린다
	var h := grid.size() * BbD.T
	for x in [o.x + 2.0 * BbD.T, o.x + BbD.COLS * BbD.T]:
		ci.draw_set_transform(Vector2(x, o.y), PI * 0.5, Vector2.ONE)
		_bar(ci, tex, Rect2(0, 0, h, 2.0 * BbD.T), theme)
	ci.draw_set_transform(Vector2.ZERO)


## 먹물 얼룩 — c 가운데, 지름 d, 짙기 a.
static func ink(ci: CanvasItem, c: Vector2, d: float, a: float, rot: float = 0.0) -> void:
	var tex := img("bb_ink")
	if tex == null:
		ci.draw_circle(c, d * 0.45, Color(0.2, 0.12, 0.28, a))
		return
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-d * 0.5, -d * 0.5, d, d), false, Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO)


static func _bar(ci: CanvasItem, tex: Texture2D, r: Rect2, theme: int) -> void:
	if tex == null:
		G2.panel(ci, r, Color8(220, 170, 110), INK, 2.0, 6.0)
		return
	var s := tex.get_size()
	var cap := s.y * 0.6   # 그림의 양 끝(둥근 곳) 폭
	var ch := r.size.y / s.y   # 그림 → 칸 배율
	var cw := minf(cap * ch, r.size.x * 0.5)
	ci.draw_texture_rect_region(tex, Rect2(r.position, Vector2(cw, r.size.y)), Rect2(0, 0, cw / ch, s.y))
	ci.draw_texture_rect_region(tex, Rect2(r.end.x - cw, r.position.y, cw, r.size.y), Rect2(s.x - cw / ch, 0, cw / ch, s.y))
	var mid := r.size.x - cw * 2.0
	if mid > 0.0:   # 가운데는 그림 가운데 띠를 늘리지 않고 이어 붙인다(무늬가 안 늘어나게)
		var seg := (s.x - cap * 2.0) * ch
		var x := r.position.x + cw
		while x < r.end.x - cw - 0.5:
			var w := minf(seg, r.end.x - cw - x)
			ci.draw_texture_rect_region(tex, Rect2(x, r.position.y, w, r.size.y), Rect2(cap, 0, w / ch, s.y))
			x += w
