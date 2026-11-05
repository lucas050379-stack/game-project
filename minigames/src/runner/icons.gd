class_name WrIcons
extends RefCounted

## 월드 러너 — 이미지 파일 없이 코드로 그리는 것 전부: 도형 헬퍼 · 국기 · 주사위 · 건물 ·
## 도시별 랜드마크 23종 · 캐릭터 말 · 특수칸 아이콘 · 동전.
##
## 원본 세계마뷸 `Icons.cs`(GDI+) 를 옮긴 것이다. GDI+ 의 `FillEllipse(x, y, w, h)` ·
## `FillPie(x, y, w, h, 시작각, 쓸기각)` 처럼 **바깥 사각형으로 도형을 지정하는 방식**을 그대로
## 흉내 낸 헬퍼(`fe` · `fpie` · `fr` · `fp` · `ln`)를 두어 좌표를 원본에서 줄 단위로 옮길 수 있게 했다.
## 각도는 GDI+ 와 같이 도(°) 단위, +x 에서 시계 방향(y 가 아래로 크므로 Godot 와 같다).
##
## **변환은 `push` / `pop` 으로만** 겁니다. `draw_set_transform` 은 부모 변환에 곱해지는 게 아니라
## 덮어쓰므로, 화면 흔들림(`base`)을 늘 앞에 곱해 줘야 판과 말이 따로 흔들리지 않습니다.

static var base := Transform2D.IDENTITY
static var _stack: Array[Transform2D] = []
static var _cur := Transform2D.IDENTITY

# ==================== 변환 ====================


static func push(ci: CanvasItem, xf: Transform2D) -> void:
	_stack.append(_cur)
	_cur = _cur * xf
	ci.draw_set_transform_matrix(base * _cur)


static func pop(ci: CanvasItem) -> void:
	_cur = _stack.pop_back() if not _stack.is_empty() else Transform2D.IDENTITY
	ci.draw_set_transform_matrix(base * _cur)


## 화면 흔들림 같은 바탕 변환을 바꾼다. 쌓인 변환은 비운다.
static func set_base(ci: CanvasItem, xf: Transform2D) -> void:
	base = xf
	_stack.clear()
	_cur = Transform2D.IDENTITY
	ci.draw_set_transform_matrix(base)


static func xf(x: float, y: float, rot: float = 0.0, sx: float = 1.0, sy: float = 1.0) -> Transform2D:
	return Transform2D(rot, Vector2(sx, sy), 0.0, Vector2(x, y))

# ==================== 그림 ====================

static var _art := {}


## `art/runner/<이름>.png` — 없으면 null 이고 그 자리는 벡터로 그린다(폴더가 비어도 돈다).
static func art(name: String) -> Texture2D:
	if not _art.has(name):
		var path := "res://art/runner/%s.png" % name
		_art[name] = load(path) if ResourceLoader.exists(path) else null
	return _art[name]

# ==================== 색 ====================


static func a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))


static func mix(x: Color, y: Color, t: float) -> Color:
	return x.lerp(y, clampf(t, 0.0, 1.0))


static func lighten(c: Color, t: float) -> Color:
	return Color(mix(c, Color.WHITE, t), c.a)


## 회색 그림(옷 마스크 · 랜드마크)에 곱할 색 — 흰색을 섞지 않고 채도를 한 번 더 올린다(사용자 결정 11-04:
## 흰색을 섞었더니 빨강 · 초록이 옅어 보였다). 그림의 명암이 곱해져 어두워지므로 밝기는 끝까지 올린다.
static func vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.2), 1.0, c.a)


static func darken(c: Color, t: float) -> Color:
	return Color(mix(c, Color.BLACK, t), c.a)

# ==================== 도형 (GDI+ 식 좌표) ====================


static func fr(ci: CanvasItem, c: Color, x: float, y: float, w: float, h: float) -> void:
	if w > 0.0 and h > 0.0 and c.a > 0.004:
		ci.draw_rect(Rect2(x, y, w, h), c, true)


## 다각형. 넓이가 거의 없는 것은 건너뛴다.
##
## **GDI+ 는 꼬인 다각형(나비넥타이)도 칠하지만 Godot 는 삼각분할에 실패하고 조용히 안 그립니다**
## (stderr 에 `triangulation failed` 만 남깁니다). 원본 도쿄 타워 · 에펠탑 다리가 실제로 그 모양이라
## 탑 다리가 통째로 사라졌습니다. 분할이 안 되면 볼록 껍질로 칠합니다 — 다리 하나 정도는 그 차이가 안 보입니다.
static func fp(ci: CanvasItem, c: Color, pts: Array) -> void:
	if c.a <= 0.004 or pts.size() < 3:
		return
	var p := PackedVector2Array(pts)
	var area := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		area += p[i].x * q.y - q.x * p[i].y
	if absf(area) < 0.2:
		return
	if p.size() == 3:
		ci.draw_primitive(p, PackedColorArray([c, c, c]), PackedVector2Array())
		return
	if Geometry2D.triangulate_polygon(p).is_empty():
		p = Geometry2D.convex_hull(p)
		if p.size() > 1 and p[0] == p[p.size() - 1]:
			p.remove_at(p.size() - 1)
		if p.size() < 3:
			return
	ci.draw_colored_polygon(p, c)


static func ell(x: float, y: float, w: float, h: float, seg: int = 24) -> PackedVector2Array:
	var cen := Vector2(x + w * 0.5, y + h * 0.5)
	var pts := PackedVector2Array()
	for i in seg:
		var ang := TAU * i / seg
		pts.append(cen + Vector2(cos(ang) * w * 0.5, sin(ang) * h * 0.5))
	return pts


static func fe(ci: CanvasItem, c: Color, x: float, y: float, w: float, h: float) -> void:
	if w <= 0.0 or h <= 0.0 or c.a <= 0.004:
		return
	if absf(w - h) < 0.01:
		ci.draw_circle(Vector2(x + w * 0.5, y + h * 0.5), w * 0.5, c)
		return
	G2.fill_fan(ci, ell(x, y, w, h, 28), c, Vector2(x + w * 0.5, y + h * 0.5))


static func arc_pts(x: float, y: float, w: float, h: float, a0: float, sweep: float, seg: int = 16) -> PackedVector2Array:
	var cen := Vector2(x + w * 0.5, y + h * 0.5)
	var pts := PackedVector2Array()
	for i in seg + 1:
		var ang := deg_to_rad(a0 + sweep * i / seg)
		pts.append(cen + Vector2(cos(ang) * w * 0.5, sin(ang) * h * 0.5))
	return pts


static func fpie(ci: CanvasItem, c: Color, x: float, y: float, w: float, h: float, a0: float, sweep: float) -> void:
	if w <= 0.0 or h <= 0.0 or c.a <= 0.004:
		return
	var cen := Vector2(x + w * 0.5, y + h * 0.5)
	G2.fill_fan(ci, arc_pts(x, y, w, h, a0, sweep, 18), c, cen)


static func ln(ci: CanvasItem, c: Color, wid: float, x0: float, y0: float, x1: float, y1: float) -> void:
	if c.a > 0.004:
		ci.draw_line(Vector2(x0, y0), Vector2(x1, y1), c, maxf(0.7, wid), true)


static func earc(ci: CanvasItem, c: Color, wid: float, x: float, y: float, w: float, h: float, a0: float, sweep: float) -> void:
	if w > 0.0 and h > 0.0 and c.a > 0.004:
		ci.draw_polyline(arc_pts(x, y, w, h, a0, sweep, 20), c, maxf(0.7, wid), true)


static func estroke(ci: CanvasItem, c: Color, wid: float, x: float, y: float, w: float, h: float) -> void:
	if w > 0.0 and h > 0.0 and c.a > 0.004:
		ci.draw_polyline(arc_pts(x, y, w, h, 0.0, 360.0, 28), c, maxf(0.7, wid), true)


static func tri(ci: CanvasItem, c: Color, cx: float, cy: float, w: float, h: float, down: bool) -> void:
	if down:
		fp(ci, c, [Vector2(cx - w / 2, cy - h / 2), Vector2(cx + w / 2, cy - h / 2), Vector2(cx, cy + h / 2)])
	else:
		fp(ci, c, [Vector2(cx - w / 2, cy + h / 2), Vector2(cx + w / 2, cy + h / 2), Vector2(cx, cy - h / 2)])


static func star(ci: CanvasItem, c: Color, cx: float, cy: float, r: float, points: int, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var ang := rot + i * PI / points
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(Vector2(cx + cos(ang) * rr, cy + sin(ang) * rr))
	G2.fill_fan(ci, pts, c, Vector2(cx, cy))

# ==================== 둥근 판 ====================


static func rr_pts(r: Rect2, rad: float) -> PackedVector2Array:
	rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	if rad < 0.5:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var corners := [
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for co in corners:
		for i in 6:
			var ang: float = co[1] + PI * 0.5 * i / 5.0
			pts.append(co[0] + Vector2(cos(ang), sin(ang)) * rad)
	return pts


static func fill_round(ci: CanvasItem, c: Color, r: Rect2, rad: float) -> void:
	if r.size.x > 0.0 and r.size.y > 0.0 and c.a > 0.004:
		G2.fill_fan(ci, rr_pts(r, rad), c, r.get_center())


## 위에서 아래로 색이 바뀌는 둥근 판.
static func fill_round_grad(ci: CanvasItem, top: Color, bot: Color, r: Rect2, rad: float) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var pts := rr_pts(r, rad)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bot, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	# 부채꼴로 직접 채운다(가운데 색은 중간값)
	var n := pts.size()
	var all := PackedVector2Array([r.get_center()])
	all.append_array(pts)
	var ac := PackedColorArray([top.lerp(bot, 0.5)])
	ac.append_array(cols)
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([0, i + 1, (i + 1) % n + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, all, ac)


static func stroke_round(ci: CanvasItem, c: Color, w: float, r: Rect2, rad: float) -> void:
	if r.size.x > 0.0 and r.size.y > 0.0 and c.a > 0.004:
		G2.stroke(ci, rr_pts(r, rad), c, w)


## 둥근 판 둘레의 부드러운 발광 — 옅은 테를 몇 겹 두른다.
static func glow_round(ci: CanvasItem, c: Color, r: Rect2, rad: float, spread: float, strength: float) -> void:
	var layers := 4
	for i in range(layers, 0, -1):
		var e := spread * i / layers
		var al := strength * 40.0 / 255.0 * (1.0 - float(i - 1) / layers)
		stroke_round(ci, a(c, al), e / 1.6 + 1.5, r.grow(e), rad + e)


static func shadow(ci: CanvasItem, r: Rect2, rad: float, dy: float, strength: float) -> void:
	for i in range(4, 0, -1):
		fill_round(ci, Color(0, 0, 0, strength * 16.0 / 255.0),
				Rect2(r.position.x - i, r.position.y - i + dy, r.size.x + i * 2, r.size.y + i * 2), rad + i)

# ==================== 글 ====================

## Jua 글꼴에 없는 글자를 있는 것으로 바꾼다(웹에서 네모로 나온다).
const _SWAP := {" · ": ", ", "·": ",", "—": "-", "→": ">", "×": "x", "★": "*", "−": "-", "₩": "W"}


static func clean(s: String) -> String:
	for k in _SWAP:
		if s.contains(k):
			s = s.replace(k, _SWAP[k])
	return s


static func text_w(s: String, size: float) -> float:
	return P.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x


## 사각형 안에 한 줄. align: 0 왼쪽 · 1 가운데 · 2 오른쪽. 세로는 가운데.
## **폭이 넘치면 글자를 줄여** 넣는다(`min_size` 까지).
static func text(ci: CanvasItem, s: String, size: float, c: Color, r: Rect2, align: int = 1,
		min_size: float = 8.0, outline: float = 0.0, oc: Color = Color(0, 0, 0, 0.6)) -> void:
	if s.is_empty() or c.a <= 0.004:
		return
	s = clean(s)
	var f := P.font()
	var sz := size
	var w := text_w(s, sz)
	while w > r.size.x and sz > min_size:
		sz -= 1.0
		w = text_w(s, sz)
	var x := r.position.x
	if align == 1:
		x = r.position.x + (r.size.x - w) * 0.5
	elif align == 2:
		x = r.end.x - w
	var y := r.position.y + r.size.y * 0.5 + sz * 0.36
	if outline > 0.0:
		ci.draw_string_outline(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz), int(outline), oc)
	ci.draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz), c)


## 여러 줄 — 줄바꿈(\n)과 폭에 맞춘 낱말 접기. 사각형 세로 가운데에 놓는다.
static func text_wrap(ci: CanvasItem, s: String, size: float, c: Color, r: Rect2, line_h: float = 0.0) -> void:
	s = clean(s)
	if line_h <= 0.0:
		line_h = size * 1.35
	var lines: Array = []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var t := word if line.is_empty() else line + " " + word
			if not line.is_empty() and text_w(t, size) > r.size.x:
				lines.append(line)
				line = word
			else:
				line = t
		lines.append(line)
	var y := r.position.y + (r.size.y - lines.size() * line_h) * 0.5
	for ln_s: String in lines:
		text(ci, ln_s, size, c, Rect2(r.position.x, y, r.size.x, line_h), 1, size * 0.7)
		y += line_h

# ==================== 국기 ====================


static func flag(ci: CanvasItem, f: Array, r: Rect2) -> void:
	if f.is_empty():
		return
	var cols: Array = f.slice(1)
	match String(f[0]):
		"hstripes":
			_stripes(ci, cols, r, true)
		"vstripes":
			_stripes(ci, cols, r, false)
		"disc":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y)
			var d := r.size.y * 0.6
			ci.draw_circle(r.get_center(), d * 0.5, cols[1])
		"cross", "nordic":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y)
			var tw := r.size.y * 0.22
			var cx := r.position.x + (r.size.x * 0.36 if f[0] == "nordic" else r.size.x * 0.5)
			fr(ci, cols[1], cx - tw / 2, r.position.y, tw, r.size.y)
			fr(ci, cols[1], r.position.x, r.position.y + r.size.y / 2 - tw / 2, r.size.x, tw)
		"trihoist":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y / 2 + 1)
			fr(ci, cols[1], r.position.x, r.position.y + r.size.y / 2, r.size.x, r.size.y / 2)
			if cols.size() > 2:
				fp(ci, cols[2], [r.position, Vector2(r.position.x + r.size.x * 0.45, r.position.y + r.size.y / 2),
						Vector2(r.position.x, r.end.y)])
		"canton":
			for i in 7:
				fr(ci, cols[0] if i % 2 == 0 else Color.WHITE, r.position.x, r.position.y + r.size.y * i / 7.0,
						r.size.x, r.size.y / 7.0 + 0.5)
			var cr := Rect2(r.position, Vector2(r.size.x * 0.42, r.size.y * 0.55))
			fr(ci, cols[1], cr.position.x, cr.position.y, cr.size.x, cr.size.y)
			star(ci, cols[2], cr.get_center().x, cr.get_center().y, cr.size.y * 0.36, 5, -PI / 2)
		"stars":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y)
			var cr := Rect2(r.position, Vector2(r.size.x * 0.4, r.size.y * 0.5))
			var pw := maxf(1.0, r.size.y * 0.07)
			ln(ci, cols[1], pw, cr.position.x, cr.position.y, cr.end.x, cr.end.y)
			ln(ci, cols[1], pw, cr.end.x, cr.position.y, cr.position.x, cr.end.y)
			ln(ci, cols[1], pw, cr.get_center().x, cr.position.y, cr.get_center().x, cr.end.y)
			ln(ci, cols[1], pw, cr.position.x, cr.get_center().y, cr.end.x, cr.get_center().y)
			star(ci, cols[1], r.position.x + r.size.x * 0.2, r.end.y - r.size.y * 0.22, r.size.y * 0.18, 5, -PI / 2)
			star(ci, cols[1], r.position.x + r.size.x * 0.72, r.position.y + r.size.y * 0.28, r.size.y * 0.15, 5, -PI / 2)
			star(ci, cols[1], r.position.x + r.size.x * 0.85, r.position.y + r.size.y * 0.66, r.size.y * 0.12, 5, -PI / 2)
		"taegeuk":
			_taegeuk(ci, cols, r)
		"union":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y)
			var wp := maxf(1.5, r.size.y * 0.16)
			var rp := maxf(1.0, r.size.y * 0.08)
			for k in 2:
				var c: Color = cols[1] if k == 0 else cols[2]
				var w := wp if k == 0 else rp
				ln(ci, c, w, r.position.x, r.position.y, r.end.x, r.end.y)
				ln(ci, c, w, r.end.x, r.position.y, r.position.x, r.end.y)
			var tw := r.size.y * 0.3
			fr(ci, cols[1], r.get_center().x - tw / 2, r.position.y, tw, r.size.y)
			fr(ci, cols[1], r.position.x, r.get_center().y - tw / 2, r.size.x, tw)
			var t2 := tw * 0.5
			fr(ci, cols[2], r.get_center().x - t2 / 2, r.position.y, t2, r.size.y)
			fr(ci, cols[2], r.position.x, r.get_center().y - t2 / 2, r.size.x, t2)
		"beach":
			fr(ci, cols[0], r.position.x, r.position.y, r.size.x, r.size.y)
			fe(ci, Color8(253, 224, 71), r.position.x + r.size.x * 0.62, r.position.y + r.size.y * 0.12,
					r.size.y * 0.32, r.size.y * 0.32)
			fpie(ci, cols[1], r.position.x - r.size.x * 0.2, r.position.y + r.size.y * 0.45, r.size.x * 1.4,
					r.size.y * 1.2, 180, 180)
			fr(ci, Color8(14, 165, 233), r.position.x, r.position.y + r.size.y * 0.52, r.size.x, r.size.y * 0.12)
		"palm":
			fr(ci, Color8(125, 211, 252), r.position.x, r.position.y, r.size.x, r.size.y)
			fpie(ci, cols[0], r.position.x - r.size.x * 0.1, r.position.y + r.size.y * 0.55, r.size.x * 1.2,
					r.size.y, 180, 180)
			var tx := r.position.x + r.size.x * 0.42
			fr(ci, Color8(120, 72, 40), tx, r.position.y + r.size.y * 0.28, maxf(1.5, r.size.x * 0.06), r.size.y * 0.42)
			var lr := r.size.y * 0.2
			var leaf := Color8(22, 163, 74)
			fe(ci, leaf, tx - lr * 1.5, r.position.y + r.size.y * 0.16, lr * 1.8, lr * 0.9)
			fe(ci, leaf, tx + lr * 0.1, r.position.y + r.size.y * 0.14, lr * 1.8, lr * 0.9)
			fe(ci, leaf, tx - lr * 0.6, r.position.y + r.size.y * 0.06, lr * 1.6, lr * 0.8)
	# 광택 + 테두리
	fill_round_grad(ci, Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.0), r, 0.0)
	ci.draw_rect(r, Color(0, 0, 0, 0.27), false, 1.0)


static func _stripes(ci: CanvasItem, cols: Array, r: Rect2, horizontal: bool) -> void:
	var n := cols.size()
	for i in n:
		if horizontal:
			fr(ci, cols[i], r.position.x, r.position.y + r.size.y * i / n, r.size.x, r.size.y / n + 0.5)
		else:
			fr(ci, cols[i], r.position.x + r.size.x * i / n, r.position.y, r.size.x / n + 0.5, r.size.y)


## 태극 — **원과 반원을 겹쳐 칠합니다.** 호를 이어 붙인 경로로 그리면 모양이 쉽게 깨집니다.
static func _taegeuk(ci: CanvasItem, cols: Array, r: Rect2) -> void:
	fr(ci, Color.WHITE, r.position.x, r.position.y, r.size.x, r.size.y)
	var d := r.size.y * 0.52
	var cx := r.get_center().x
	var cy := r.get_center().y
	fpie(ci, cols[1], cx - d / 2, cy - d / 2, d, d, 180, 180)
	fpie(ci, cols[2], cx - d / 2, cy - d / 2, d, d, 0, 180)
	fe(ci, cols[2], cx - d / 2, cy - d / 4, d / 2, d / 2)
	fe(ci, cols[1], cx, cy - d / 4, d / 2, d / 2)
	var bw := r.size.x * 0.13
	var bh := maxf(1.2, r.size.y * 0.055)
	var ink := Color8(30, 30, 30)
	for i in 3:
		fr(ci, ink, r.position.x + r.size.x * 0.06, r.position.y + r.size.y * (0.16 + i * 0.09), bw, bh)
		fr(ci, ink, r.end.x - r.size.x * 0.06 - bw, r.position.y + r.size.y * (0.16 + i * 0.09), bw, bh)
		fr(ci, ink, r.position.x + r.size.x * 0.06, r.end.y - r.size.y * (0.22 + i * 0.09), bw, bh)
		fr(ci, ink, r.end.x - r.size.x * 0.06 - bw, r.end.y - r.size.y * (0.22 + i * 0.09), bw, bh)

# ==================== 주사위 ====================

const PIPS := [[4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]


static func dice(ci: CanvasItem, c: Vector2, size: float, value: int, rot: float = 0.0, sc: float = 1.0,
		alpha: float = 1.0) -> void:
	push(ci, xf(c.x, c.y, rot, sc, sc))
	var r := Rect2(-size / 2, -size / 2, size, size)
	var rad := size * 0.2
	fill_round(ci, Color(0, 0, 0, 0.25 * alpha), Rect2(r.position + Vector2(3, 4), r.size), rad)
	fill_round_grad(ci, a(Color.WHITE, alpha), a(Color8(214, 219, 232), alpha), r, rad)
	stroke_round(ci, a(Color8(150, 158, 180), alpha), 1.4, r, rad)
	if value >= 1 and value <= 6:
		var pr := size * 0.098
		var pad := size * 0.24
		var step := (size - pad * 2) / 2.0
		for idx: int in PIPS[value - 1]:
			var x := r.position.x + pad + step * (idx % 3)
			var y := r.position.y + pad + step * (idx / 3)
			ci.draw_circle(Vector2(x, y), pr, a(Color8(40, 44, 60), alpha))
			fe(ci, a(Color(1, 1, 1, 0.35), alpha), x - pr * 0.75, y - pr * 0.85, pr * 0.9, pr * 0.7)
	pop(ci)

# ==================== 동전 ====================


static func coin(ci: CanvasItem, x: float, y: float, size: float, alpha: float, rot: float) -> void:
	var w := maxf(size * absf(cos(rot)), size * 0.18)
	# 그림 금화 — 도는 것은 가로 폭을 줄였다 늘였다 해서 낸다(벡터와 같은 방식)
	var tx := art("runner_coin")
	if tx != null:
		ci.draw_texture_rect(tx, Rect2(x - w * 1.1, y - size * 1.1, w * 2.2, size * 2.2), false,
				Color(1, 1, 1, alpha))
		return
	var r := Rect2(x - w, y - size, w * 2, size * 2)
	G2.fill_fan(ci, ell(r.position.x, r.position.y, r.size.x, r.size.y, 20), a(Color8(240, 190, 70), alpha), r.get_center())
	fe(ci, a(Color8(255, 226, 138), alpha), r.position.x + w * 0.25, r.position.y + size * 0.15, w * 1.3, size * 1.2)
	estroke(ci, a(Color8(160, 108, 10), alpha), 1.2, r.position.x, r.position.y, r.size.x, r.size.y)

# ==================== 건물 ====================


## 칸 안의 건물. level 1 = 별장 · 2 = 빌딩 · 3 = 호텔 · 4 = 랜드마크(도시마다 다른 도안).
## (cx, base_y) 가 바닥 한가운데. pop 은 세워지는 중의 튀어 오름(0 = 다 섰음).
static func building(ci: CanvasItem, level: int, cx: float, base_y: float, w: float, h: float,
		owner: Color, pop_t: float, lm: String) -> void:
	if level <= 0:
		return
	var bounce := (1.0 - _out_bounce(pop_t)) if pop_t > 0.0 else 0.0
	var lift := bounce * h * 2.2
	var squash := 1.0 + bounce * 0.25
	push(ci, xf(cx, base_y - lift, 0.0, 1.0 / squash, squash))
	var body := lighten(owner, 0.15)
	var dark := darken(owner, 0.35)
	var roof := darken(owner, 0.15)
	fe(ci, Color(0, 0, 0, 0.22), -w * 0.6, -2.0, w * 1.2, 4.5)
	if level == 1:
		var bh := h * 0.62
		var bw := w * 0.74
		fr(ci, body, -bw / 2, -bh, bw, bh)
		fr(ci, dark, bw * 0.16, -bh, bw * 0.34, bh)
		fp(ci, roof, [Vector2(-bw * 0.62, -bh), Vector2(bw * 0.62, -bh), Vector2(0, -h * 1.02)])
		fr(ci, Color8(235, 245, 255), -bw * 0.18, -bh * 0.62, bw * 0.26, bh * 0.34)
	elif level == 2:
		var bh := h
		var bw := w * 0.66
		fr(ci, body, -bw / 2, -bh, bw, bh)
		fr(ci, dark, bw * 0.14, -bh, bw * 0.36, bh)
		fr(ci, roof, -bw * 0.58, -bh - h * 0.09, bw * 1.16, h * 0.09)
		for ry in 4:
			for rx in 2:
				fr(ci, Color8(215, 235, 255), -bw * 0.30 + rx * bw * 0.30, -bh + h * 0.13 + ry * h * 0.2,
						bw * 0.19, h * 0.12)
	elif level == 3:
		var bh := h * 1.38
		var bw := w * 0.84
		fr(ci, body, -bw / 2, -bh, bw, bh)
		fr(ci, dark, bw * 0.12, -bh, bw * 0.38, bh)
		fr(ci, WrD.GOLD, -bw * 0.6, -bh - h * 0.1, bw * 1.2, h * 0.1)
		ln(ci, WrD.GOLD, 1.4, 0, -bh - h * 0.1, 0, -bh - h * 0.34)
		ci.draw_circle(Vector2(0, -bh - h * 0.42 + 2.2), 2.2, Color8(255, 90, 90))
		for ry in 5:
			for rx in 3:
				fr(ci, Color8(225, 240, 255), -bw * 0.38 + rx * bw * 0.26, -bh + h * 0.14 + ry * h * 0.23,
						bw * 0.16, h * 0.13)
	elif lm != "":
		landmark(ci, lm, w, h, body, dark)
	else:
		_generic_landmark(ci, w, h, body, dark)
	pop(ci)


static func _out_bounce(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if t < 1.0 / d1:
		return n1 * t * t
	if t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	if t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	t -= 2.625 / d1
	return n1 * t * t + 0.984375


## 그림 랜드마크 — 그림에 받침대가 같이 그려져 있으므로 받침 · 그림자 · 금빛 무리 없이 **그림 아래 끝을
## 칸 바닥(foot)에** 맞춰 세운다. 폭 wid 는 받침대가 칸 안에 들어오는 크기. 회색 그림을 소유자 색으로 물들인다.
static func landmark_art(ci: CanvasItem, tex: Texture2D, cx: float, foot: float, wid: float, owner: Color, pop_t: float) -> void:
	var bounce := (1.0 - _out_bounce(pop_t)) if pop_t > 0.0 else 0.0
	var squash := 1.0 + bounce * 0.25
	push(ci, xf(cx, foot - bounce * wid * 0.8, 0.0, 1.0 / squash, squash))
	if not _lm_used.has(tex):
		var img := tex.get_image()
		var used0 := img.get_used_rect()
		# 회색 그림(흰 도자기로 뽑은 예전 것)인가 — 가운데 세로줄을 훑어 채도를 본다. 원래 색 그림은 베이지를 안 입힌다
		var sat := 0.0
		var cnt := 0
		var mx := used0.position.x + used0.size.x / 2
		for y in range(used0.position.y, used0.end.y, 2):
			var c := img.get_pixel(mx, y)
			if c.a > 0.5:
				sat += c.s
				cnt += 1
		_lm_used[tex] = used0
		_lm_grey[tex] = cnt == 0 or sat / cnt < 0.08
	var used: Rect2i = _lm_used[tex]
	var k := wid / used.size.x   # 내용 폭 기준 — 그림마다 여백이 달라도 받침 폭이 맞는다
	var tw := tex.get_width() * k
	var th := tex.get_height() * k
	var dx := -(used.position.x + used.size.x * 0.5) * k
	var dy := -(used.position.y + used.size.y) * k
	var rc := Rect2(dx, dy, tw, th)
	# 그림의 일부(청록으로 칠해 뽑은 지붕 · 돔 · 조각상 — _tint 마스크)에만 소유자 색, 나머지는 원래 색(사용자 결정 11-04)
	var tint := art(tex.resource_path.get_file().get_basename() + "_tint")
	if tint == null:
		ci.draw_texture_rect(tex, rc, false, vivid(owner))
	else:
		ci.draw_texture_rect(tex, rc, false, LM_BEIGE if _lm_grey[tex] else Color.WHITE)
		ci.draw_texture_rect(tint, rc, false, vivid(owner))
	pop(ci)

const LM_BEIGE := Color(1.0, 0.94, 0.82)

static var _lm_used := {}
static var _lm_grey := {}


static func _generic_landmark(ci: CanvasItem, w: float, h: float, body: Color, dark: Color) -> void:
	var bh := h * 1.02
	var bw := w * 0.62
	var baw := w
	var bah := h * 0.2
	fe(ci, a(WrD.GOLD, 0.24), -baw * 0.75, -bah * 1.2, baw * 1.5, bah * 2.4)
	fr(ci, darken(body, 0.15), -baw / 2, -bah, baw, bah)
	fr(ci, darken(body, 0.32), baw * 0.14, -bah, baw * 0.36, bah)
	fr(ci, lighten(body, 0.05), -baw * 0.4, -bah - h * 0.14, baw * 0.8, h * 0.14)
	var y0 := -bah - h * 0.14
	var top := y0 - bh
	fp(ci, body, [Vector2(-bw / 2, y0), Vector2(bw / 2, y0), Vector2(bw * 0.28, top), Vector2(-bw * 0.28, top)])
	fp(ci, dark, [Vector2(bw * 0.08, y0), Vector2(bw / 2, y0), Vector2(bw * 0.28, top), Vector2(bw * 0.05, top)])
	for i in range(1, 3):
		var yy := y0 - bh * i / 3.0
		var half := bw / 2 - (bw / 2 - bw * 0.28) * i / 3.0
		ln(ci, WrD.GOLD, maxf(1.0, h * 0.05), -half, yy, half, yy)
	fp(ci, WrD.GOLD, [Vector2(-bw * 0.30, top), Vector2(bw * 0.30, top), Vector2(0, top - h * 0.42)])
	ci.draw_circle(Vector2(0, top - h * 0.47), h * 0.09, Color8(255, 245, 200))
	ci.draw_circle(Vector2(0, top - h * 0.47), h * 0.2, a(WrD.GOLD, 0.35))

# ==================== 도시별 랜드마크 ====================
# 좌표계: (0,0) 이 바닥 한가운데, 위쪽이 -y. w = 가로 기준, h = 세로 기준.


static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y)


## 양파 돔 하나 (모스크바 · 이스탄불)
static func _onion(ci: CanvasItem, c: Color, hi: Color, cx: float, by: float, rw: float, rh: float) -> void:
	fpie(ci, c, cx - rw, by - rh * 1.15, rw * 2, rh * 1.6, 180, 180)
	fp(ci, c, [_v(cx - rw * 0.86, by - rh * 0.35), _v(cx + rw * 0.86, by - rh * 0.35), _v(cx, by + rh * 0.10)])
	fr(ci, hi, cx - rw * 0.10, by - rh * 1.62, rw * 0.20, rh * 0.42)
	ln(ci, hi, rw * 0.24, cx - rw * 0.34, by - rh * 1.45, cx + rw * 0.34, by - rh * 1.45)


## 고딕 첨탑 지붕
static func _spire(ci: CanvasItem, c: Color, cx: float, by: float, hw: float, hh: float) -> void:
	fp(ci, c, [_v(cx - hw, by), _v(cx + hw, by), _v(cx, by - hh)])


static func landmark(ci: CanvasItem, k: String, w: float, h: float, body: Color, dark: Color) -> void:
	var gold := WrD.GOLD
	var deep := WrD.GOLD_DEEP
	var stone := lighten(body, 0.30)
	var stone_d := darken(body, 0.28)
	var glass := Color8(228, 240, 255)
	var void_c := WrD.BG0
	# 발밑 금빛 무리 — 어떤 도안이든 "랜드마크"로 읽히게 하는 공통 요소
	fe(ci, a(gold, 0.27), -w * 0.85, -h * 0.26, w * 1.7, h * 0.5)
	match k:
		"tower101":
			fr(ci, stone_d, -w * 0.46, -h * 0.16, w * 0.92, h * 0.16)
			var sh := h * 0.24
			var y := -h * 0.16
			for i in 7:
				var hw := w * 0.24
				fr(ci, stone if i % 2 == 0 else body, -hw, y - sh, hw * 2, sh)
				fr(ci, dark, hw * 0.18, y - sh, hw * 0.82, sh)
				fp(ci, gold, [_v(-hw * 1.30, y - sh), _v(hw * 1.30, y - sh), _v(hw * 0.95, y - sh * 0.62), _v(-hw * 0.95, y - sh * 0.62)])
				y -= sh
			ln(ci, gold, w * 0.09, 0, y, 0, y - h * 0.55)
			ci.draw_circle(Vector2(0, y - h * 0.57), h * 0.07, Color8(255, 246, 205))
		"cathedral":
			fr(ci, stone_d, -w * 0.52, -h * 0.12, w * 1.04, h * 0.12)
			fr(ci, stone, -w * 0.26, -h * 1.02, w * 0.52, h * 0.90)
			fr(ci, dark, w * 0.06, -h * 1.02, w * 0.20, h * 0.90)
			fp(ci, deep, [_v(-w * 0.32, -h * 1.02), _v(w * 0.32, -h * 1.02), _v(0, -h * 1.34)])
			for s in [-1, 1]:
				var cx: float = s * w * 0.40
				fr(ci, stone, cx - w * 0.13, -h * 1.28, w * 0.26, h * 1.16)
				fr(ci, dark, cx + w * 0.02, -h * 1.28, w * 0.11, h * 1.16)
				_spire(ci, deep, cx, -h * 1.28, w * 0.17, h * 0.40)
				ln(ci, gold, w * 0.07, cx, -h * 1.68, cx, -h * 1.86)
				ln(ci, gold, w * 0.07, cx - w * 0.08, -h * 1.79, cx + w * 0.08, -h * 1.79)
			fe(ci, glass, -w * 0.11, -h * 0.92, w * 0.22, h * 0.22)
		"volcano":
			fp(ci, darken(body, 0.10), [_v(-w * 0.82, 0), _v(w * 0.82, 0), _v(w * 0.24, -h * 1.05), _v(-w * 0.26, -h * 1.05)])
			fp(ci, dark, [_v(w * 0.10, 0), _v(w * 0.82, 0), _v(w * 0.24, -h * 1.05), _v(w * 0.02, -h * 1.05)])
			fe(ci, darken(body, 0.45), -w * 0.26, -h * 1.14, w * 0.50, h * 0.18)
			fe(ci, Color8(255, 140, 60), -w * 0.18, -h * 1.10, w * 0.34, h * 0.11)
			ln(ci, deep, w * 0.10, -w * 0.62, 0, -w * 0.70, -h * 0.50)
			for i in range(-2, 3):
				ln(ci, Color8(52, 180, 110), w * 0.09, -w * 0.70, -h * 0.50, -w * 0.70 + i * w * 0.17,
						-h * 0.50 - h * 0.20 + absi(i) * h * 0.06)
		"merlion":
			fr(ci, stone_d, -w * 0.50, -h * 0.18, w, h * 0.18)
			fp(ci, Color8(120, 200, 255, 150), [_v(-w * 0.20, -h * 0.90), _v(-w * 0.86, -h * 0.30), _v(-w * 0.80, -h * 0.14), _v(-w * 0.12, -h * 0.78)])
			fp(ci, stone, [_v(w * 0.06, -h * 0.18), _v(w * 0.44, -h * 0.18), _v(w * 0.30, -h * 0.86), _v(0, -h * 0.92)])
			fp(ci, dark, [_v(w * 0.24, -h * 0.18), _v(w * 0.44, -h * 0.18), _v(w * 0.30, -h * 0.86)])
			fe(ci, lighten(body, 0.10), -w * 0.34, -h * 1.42, w * 0.62, h * 0.60)
			fe(ci, stone, -w * 0.26, -h * 1.34, w * 0.46, h * 0.46)
			fe(ci, WrD.INK, -w * 0.18, -h * 1.20, w * 0.07, h * 0.07)
			fe(ci, WrD.INK, -w * 0.02, -h * 1.20, w * 0.07, h * 0.07)
			fe(ci, gold, -w * 0.16, -h * 1.02, w * 0.22, h * 0.11)
		"pyramid":
			fp(ci, lighten(body, 0.34), [_v(-w * 0.78, 0), _v(w * 0.10, 0), _v(-w * 0.06, -h * 1.20)])
			fp(ci, darken(body, 0.22), [_v(w * 0.10, 0), _v(w * 0.78, 0), _v(-w * 0.06, -h * 1.20)])
			for i in range(1, 4):
				var t := i / 4.0
				ln(ci, a(deep, 0.47), w * 0.05, -w * 0.78 + w * 0.72 * t, -h * 1.20 * t, w * 0.78 - w * 0.84 * t, -h * 1.20 * t)
			fe(ci, stone, -w * 0.92, -h * 0.34, w * 0.52, h * 0.22)
			fe(ci, stone, -w * 0.98, -h * 0.52, w * 0.24, h * 0.24)
			fr(ci, gold, -w * 0.96, -h * 0.52, w * 0.20, h * 0.06)
		"mosque":
			fr(ci, stone_d, -w * 0.56, -h * 0.14, w * 1.12, h * 0.14)
			fr(ci, stone, -w * 0.40, -h * 0.66, w * 0.80, h * 0.52)
			fr(ci, dark, w * 0.10, -h * 0.66, w * 0.30, h * 0.52)
			_onion(ci, lighten(body, 0.15), gold, 0, -h * 0.66, w * 0.34, h * 0.42)
			for s in [-1, 1]:
				var cx: float = s * w * 0.62
				fr(ci, stone, cx - w * 0.07, -h * 1.18, w * 0.14, h * 1.04)
				fr(ci, gold, cx - w * 0.10, -h * 0.80, w * 0.20, h * 0.05)
				_spire(ci, deep, cx, -h * 1.18, w * 0.11, h * 0.30)
		"parthenon":
			for i in 3:
				fr(ci, stone_d if i == 0 else lighten(stone_d, 0.08 * i), -w * (0.78 - i * 0.05), -h * (0.08 + i * 0.08),
						w * (1.56 - i * 0.10), h * 0.09)
			var py := -h * 0.32
			for i in 6:
				var x := -w * 0.60 + i * w * 0.24
				fr(ci, stone, x - w * 0.055, py - h * 0.70, w * 0.11, h * 0.70)
				fr(ci, dark, x + w * 0.015, py - h * 0.70, w * 0.04, h * 0.70)
			fr(ci, lighten(body, 0.22), -w * 0.72, -h * 1.14, w * 1.44, h * 0.12)
			fp(ci, lighten(body, 0.34), [_v(-w * 0.76, -h * 1.14), _v(w * 0.76, -h * 1.14), _v(0, -h * 1.52)])
			ln(ci, gold, w * 0.06, -w * 0.72, -h * 1.14, w * 0.72, -h * 1.14)
		"colosseum":
			fr(ci, stone_d, -w * 0.72, -h * 0.12, w * 1.44, h * 0.12)
			fp(ci, stone, [_v(-w * 0.66, -h * 0.12), _v(w * 0.66, -h * 0.12), _v(w * 0.60, -h * 0.86),
					_v(w * 0.16, -h * 1.10), _v(-w * 0.34, -h * 1.10), _v(-w * 0.62, -h * 0.90)])
			fp(ci, dark, [_v(w * 0.20, -h * 0.12), _v(w * 0.66, -h * 0.12), _v(w * 0.60, -h * 0.86), _v(w * 0.20, -h * 1.06)])
			for row in 2:
				var ay := -h * (0.34 + row * 0.34)
				for i in 5:
					var x := -w * 0.50 + i * w * 0.25
					fpie(ci, darken(body, 0.52), x - w * 0.08, ay - h * 0.10, w * 0.16, h * 0.20, 180, 180)
					fr(ci, darken(body, 0.52), x - w * 0.08, ay, w * 0.16, h * 0.14)
			ln(ci, gold, w * 0.05, -w * 0.64, -h * 0.12, w * 0.64, -h * 0.12)
		"archgate":
			fr(ci, stone_d, -w * 0.76, -h * 0.10, w * 1.52, h * 0.10)
			fr(ci, stone, -w * 0.70, -h * 1.06, w * 1.40, h * 0.96)
			fr(ci, dark, w * 0.30, -h * 1.06, w * 0.40, h * 0.96)
			fpie(ci, void_c, -w * 0.24, -h * 0.94, w * 0.48, h * 0.48, 180, 180)
			fr(ci, void_c, -w * 0.24, -h * 0.70, w * 0.48, h * 0.60)
			for s in [-1, 1]:
				var cx: float = s * w * 0.48
				fpie(ci, void_c, cx - w * 0.13, -h * 0.66, w * 0.26, h * 0.26, 180, 180)
				fr(ci, void_c, cx - w * 0.13, -h * 0.53, w * 0.26, h * 0.43)
			fr(ci, lighten(body, 0.30), -w * 0.78, -h * 1.22, w * 1.56, h * 0.16)
			ln(ci, gold, w * 0.05, -w * 0.78, -h * 1.22, w * 0.78, -h * 1.22)
			for i in range(-1, 2):
				fe(ci, gold, i * w * 0.34 - w * 0.06, -h * 1.38, w * 0.12, h * 0.16)
		"mermaid":
			fe(ci, Color8(90, 170, 235, 120), -w * 0.95, -h * 0.18, w * 1.9, h * 0.28)
			fp(ci, darken(body, 0.38), [_v(-w * 0.52, -h * 0.06), _v(w * 0.52, -h * 0.06), _v(w * 0.30, -h * 0.46), _v(-w * 0.34, -h * 0.44)])
			fe(ci, stone, -w * 0.14, -h * 1.16, w * 0.30, h * 0.32)
			fp(ci, lighten(body, 0.18), [_v(-w * 0.16, -h * 0.90), _v(w * 0.18, -h * 0.90), _v(w * 0.10, -h * 0.44), _v(-w * 0.12, -h * 0.44)])
			fp(ci, lighten(body, 0.02), [_v(-w * 0.12, -h * 0.48), _v(w * 0.12, -h * 0.48), _v(w * 0.62, -h * 0.20), _v(w * 0.30, -h * 0.18)])
			fp(ci, gold, [_v(w * 0.52, -h * 0.28), _v(w * 0.78, -h * 0.46), _v(w * 0.80, -h * 0.10)])
		"dolharubang":
			var rock := mix(body, Color8(120, 118, 116), 0.5)
			fr(ci, darken(rock, 0.35), -w * 0.52, -h * 0.12, w * 1.04, h * 0.12)
			fp(ci, rock, [_v(-w * 0.44, -h * 0.12), _v(w * 0.44, -h * 0.12), _v(w * 0.34, -h * 0.92), _v(-w * 0.34, -h * 0.92)])
			fp(ci, darken(rock, 0.25), [_v(w * 0.14, -h * 0.12), _v(w * 0.44, -h * 0.12), _v(w * 0.34, -h * 0.92), _v(w * 0.12, -h * 0.92)])
			fe(ci, darken(rock, 0.14), -w * 0.42, -h * 1.22, w * 0.84, h * 0.40)
			fe(ci, darken(rock, 0.05), -w * 0.30, -h * 1.42, w * 0.60, h * 0.36)
			fe(ci, lighten(rock, 0.30), -w * 0.26, -h * 0.86, w * 0.20, h * 0.20)
			fe(ci, lighten(rock, 0.30), w * 0.06, -h * 0.86, w * 0.20, h * 0.20)
			fe(ci, WrD.INK, -w * 0.21, -h * 0.81, w * 0.10, h * 0.10)
			fe(ci, WrD.INK, w * 0.11, -h * 0.81, w * 0.10, h * 0.10)
			fe(ci, darken(rock, 0.22), -w * 0.08, -h * 0.66, w * 0.16, h * 0.18)
			ln(ci, darken(rock, 0.30), w * 0.07, -w * 0.22, -h * 0.36, w * 0.22, -h * 0.36)
		"cityhall":
			var brick := mix(body, Color8(150, 62, 48), 0.45)
			fr(ci, darken(brick, 0.30), -w * 0.62, -h * 0.14, w * 1.24, h * 0.14)
			fr(ci, brick, -w * 0.58, -h * 0.62, w * 1.16, h * 0.48)
			fr(ci, darken(brick, 0.22), w * 0.16, -h * 0.62, w * 0.42, h * 0.48)
			fr(ci, brick, -w * 0.22, -h * 1.42, w * 0.44, h * 0.80)
			fr(ci, darken(brick, 0.22), w * 0.06, -h * 1.42, w * 0.16, h * 0.80)
			for i in 3:
				fr(ci, glass, -w * 0.15, -h * (1.30 - i * 0.22), w * 0.10, h * 0.13)
			_spire(ci, lighten(brick, 0.10), 0, -h * 1.42, w * 0.26, h * 0.34)
			ln(ci, gold, w * 0.07, 0, -h * 1.76, 0, -h * 1.94)
			for i in range(-1, 2):
				fe(ci, gold, i * w * 0.12 - w * 0.05, -h * 2.04, w * 0.10, h * 0.12)
		"clocktower":
			fr(ci, stone_d, -w * 0.46, -h * 0.12, w * 0.92, h * 0.12)
			fr(ci, stone, -w * 0.36, -h * 1.24, w * 0.72, h * 1.12)
			fr(ci, dark, w * 0.12, -h * 1.24, w * 0.24, h * 1.12)
			fpie(ci, void_c, -w * 0.18, -h * 0.62, w * 0.36, h * 0.36, 180, 180)
			fr(ci, void_c, -w * 0.18, -h * 0.44, w * 0.36, h * 0.32)
			fe(ci, deep, -w * 0.28, -h * 1.14, w * 0.56, h * 0.56)
			fe(ci, Color8(252, 248, 230), -w * 0.23, -h * 1.09, w * 0.46, h * 0.46)
			ln(ci, WrD.INK, w * 0.06, 0, -h * 0.86, 0, -h * 1.02)
			ln(ci, WrD.INK, w * 0.06, 0, -h * 0.86, w * 0.14, -h * 0.86)
			fp(ci, darken(body, 0.42), [_v(-w * 0.44, -h * 1.24), _v(w * 0.44, -h * 1.24), _v(0, -h * 1.74)])
		"astroclock":
			fr(ci, stone_d, -w * 0.42, -h * 0.12, w * 0.84, h * 0.12)
			fr(ci, stone, -w * 0.32, -h * 1.30, w * 0.64, h * 1.18)
			fr(ci, dark, w * 0.10, -h * 1.30, w * 0.22, h * 1.18)
			fe(ci, Color8(30, 40, 90), -w * 0.25, -h * 1.18, w * 0.50, h * 0.50)
			fe(ci, gold, -w * 0.19, -h * 1.12, w * 0.38, h * 0.38)
			fe(ci, Color8(30, 40, 90), -w * 0.09, -h * 1.02, w * 0.18, h * 0.18)
			fe(ci, deep, -w * 0.20, -h * 0.64, w * 0.40, h * 0.40)
			ln(ci, gold, w * 0.05, -w * 0.20, -h * 0.44, w * 0.20, -h * 0.44)
			fp(ci, darken(body, 0.45), [_v(-w * 0.40, -h * 1.30), _v(w * 0.40, -h * 1.30), _v(0, -h * 1.90)])
			for s in [-1, 1]:
				_spire(ci, darken(body, 0.45), s * w * 0.34, -h * 1.30, w * 0.09, h * 0.28)
		"watervilla":
			fr(ci, Color8(80, 175, 225, 150), -w, -h * 0.10, w * 2, h * 0.30)
			for i in range(-1, 2):
				ln(ci, darken(body, 0.45), w * 0.07, i * w * 0.30, -h * 0.06, i * w * 0.30, -h * 0.46)
			fr(ci, lighten(body, 0.16), -w * 0.52, -h * 0.72, w * 1.04, h * 0.28)
			fr(ci, dark, w * 0.14, -h * 0.72, w * 0.38, h * 0.28)
			fp(ci, mix(body, Color8(196, 152, 84), 0.6), [_v(-w * 0.66, -h * 0.72), _v(w * 0.66, -h * 0.72), _v(0, -h * 1.32)])
			ln(ci, deep, w * 0.05, -w * 0.40, -h * 0.94, w * 0.40, -h * 0.94)
			fr(ci, glass, -w * 0.14, -h * 0.66, w * 0.20, h * 0.16)
			ln(ci, lighten(body, 0.30), w * 0.06, -w * 0.52, -h * 0.50, -w * 0.86, -h * 0.10)
		"brandenburg":
			fr(ci, stone_d, -w * 0.78, -h * 0.10, w * 1.56, h * 0.10)
			for i in 6:
				var x := -w * 0.62 + i * w * 0.248
				fr(ci, stone, x - w * 0.058, -h * 0.98, w * 0.116, h * 0.88)
				fr(ci, dark, x + w * 0.016, -h * 0.98, w * 0.042, h * 0.88)
			fr(ci, lighten(body, 0.26), -w * 0.76, -h * 1.16, w * 1.52, h * 0.18)
			ln(ci, gold, w * 0.05, -w * 0.76, -h * 1.16, w * 0.76, -h * 1.16)
			fr(ci, deep, -w * 0.10, -h * 1.34, w * 0.20, h * 0.18)
			for i in 3:
				var x := w * (0.06 + i * 0.16)
				fr(ci, gold, x, -h * 1.36, w * 0.10, h * 0.14)
				ln(ci, gold, w * 0.05, x + w * 0.09, -h * 1.36, x + w * 0.15, -h * 1.44)
		"oniondome":
			fr(ci, stone_d, -w * 0.64, -h * 0.14, w * 1.28, h * 0.14)
			for s in [-1, 1]:
				var cx: float = s * w * 0.46
				fr(ci, stone, cx - w * 0.17, -h * 0.72, w * 0.34, h * 0.58)
				_onion(ci, Color8(214, 86, 74) if s < 0 else Color8(74, 158, 214), gold, cx, -h * 0.72, w * 0.21, h * 0.30)
			fr(ci, stone, -w * 0.24, -h * 1.00, w * 0.48, h * 0.86)
			fr(ci, dark, w * 0.06, -h * 1.00, w * 0.18, h * 0.86)
			_onion(ci, lighten(body, 0.18), gold, 0, -h * 1.00, w * 0.30, h * 0.46)
			fr(ci, gold, -w * 0.26, -h * 1.04, w * 0.52, h * 0.06)
		"eiffel":
			var iron := mix(body, Color8(150, 116, 82), 0.45)
			var iron_d := darken(iron, 0.28)
			var top := -h * 1.90
			fp(ci, iron, [_v(-w * 0.80, 0), _v(-w * 0.46, 0), _v(-w * 0.05, top), _v(-w * 0.10, top)])
			fp(ci, iron_d, [_v(w * 0.46, 0), _v(w * 0.80, 0), _v(w * 0.10, top), _v(w * 0.05, top)])
			fp(ci, iron, [_v(-w * 0.60, 0), _v(-w * 0.40, 0), _v(-w * 0.02, top), _v(-w * 0.05, top)])
			fp(ci, iron_d, [_v(w * 0.40, 0), _v(w * 0.60, 0), _v(w * 0.05, top), _v(w * 0.02, top)])
			earc(ci, iron, maxf(1.0, w * 0.09), -w * 0.58, -h * 0.62, w * 1.16, h * 0.62, 180, 180)
			fr(ci, iron_d, -w * 0.56, -h * 0.66, w * 1.12, h * 0.10)
			fr(ci, iron_d, -w * 0.26, -h * 1.16, w * 0.52, h * 0.09)
			ln(ci, gold, w * 0.05, -w * 0.54, -h * 0.66, w * 0.54, -h * 0.66)
			ln(ci, gold, w * 0.07, 0, top, 0, top - h * 0.26)
			ci.draw_circle(Vector2(0, top - h * 0.28), h * 0.06, Color8(255, 244, 200))
		"bigben":
			fr(ci, stone_d, -w * 0.40, -h * 0.12, w * 0.80, h * 0.12)
			fr(ci, stone, -w * 0.28, -h * 1.34, w * 0.56, h * 1.22)
			fr(ci, dark, w * 0.09, -h * 1.34, w * 0.19, h * 1.22)
			for i in 4:
				fr(ci, darken(body, 0.40), -w * 0.20, -h * (0.34 + i * 0.19), w * 0.40, h * 0.11)
			fe(ci, deep, -w * 0.26, -h * 1.30, w * 0.52, h * 0.52)
			fe(ci, Color8(253, 246, 222), -w * 0.21, -h * 1.25, w * 0.42, h * 0.42)
			ln(ci, WrD.INK, w * 0.06, 0, -h * 1.04, 0, -h * 1.20)
			ln(ci, WrD.INK, w * 0.06, 0, -h * 1.04, w * 0.12, -h * 1.00)
			fr(ci, lighten(body, 0.18), -w * 0.32, -h * 1.46, w * 0.64, h * 0.12)
			_spire(ci, darken(body, 0.45), 0, -h * 1.46, w * 0.30, h * 0.52)
			for s in [-1, 1]:
				_spire(ci, darken(body, 0.45), s * w * 0.26, -h * 1.46, w * 0.08, h * 0.24)
			ln(ci, gold, w * 0.05, 0, -h * 1.98, 0, -h * 2.10)
		"opera":
			fr(ci, Color8(80, 170, 225, 140), -w, -h * 0.06, w * 2, h * 0.24)
			fr(ci, stone_d, -w * 0.86, -h * 0.20, w * 1.72, h * 0.14)
			var sx := [-0.42, -0.06, 0.30, 0.62]
			var sc := [1.00, 0.86, 0.66, 0.44]
			for i in 4:
				var sw: float = w * 0.62 * sc[i]
				var sh2: float = h * 1.20 * sc[i]
				fpie(ci, Color8(246, 248, 252) if i % 2 == 0 else Color8(224, 230, 242),
						w * sx[i] - sw * 0.5, -h * 0.20 - sh2, sw, sh2 * 2.0, 182, 96)
			ln(ci, gold, w * 0.05, -w * 0.86, -h * 0.20, w * 0.86, -h * 0.20)
		"liberty":
			var patina := mix(body, Color8(96, 186, 162), 0.55)
			fp(ci, stone_d, [_v(-w * 0.66, 0), _v(w * 0.66, 0), _v(w * 0.46, -h * 0.26), _v(-w * 0.46, -h * 0.26)])
			fr(ci, darken(body, 0.34), -w * 0.34, -h * 0.58, w * 0.68, h * 0.32)
			fp(ci, patina, [_v(-w * 0.30, -h * 0.58), _v(w * 0.30, -h * 0.58), _v(w * 0.14, -h * 1.30), _v(-w * 0.14, -h * 1.30)])
			fp(ci, darken(patina, 0.22), [_v(w * 0.06, -h * 0.58), _v(w * 0.30, -h * 0.58), _v(w * 0.14, -h * 1.30), _v(w * 0.02, -h * 1.30)])
			fe(ci, patina, -w * 0.13, -h * 1.50, w * 0.26, h * 0.26)
			for i in range(-2, 3):
				fp(ci, patina, [_v(i * w * 0.09 - w * 0.03, -h * 1.50), _v(i * w * 0.09 + w * 0.03, -h * 1.50),
						_v(i * w * 0.09, -h * 1.50 - h * 0.18)])
			ln(ci, patina, w * 0.09, w * 0.10, -h * 1.16, w * 0.44, -h * 1.62)
			fp(ci, gold, [_v(w * 0.36, -h * 1.62), _v(w * 0.52, -h * 1.62), _v(w * 0.44, -h * 1.86)])
			fe(ci, Color8(255, 240, 190), w * 0.38, -h * 1.96, w * 0.12, h * 0.14)
		"tokyotower":
			var steel := mix(body, Color8(228, 74, 52), 0.55)
			var steel_d := darken(steel, 0.26)
			var top := -h * 1.80
			fp(ci, steel, [_v(-w * 0.74, 0), _v(-w * 0.42, 0), _v(-w * 0.03, top), _v(-w * 0.07, top)])
			fp(ci, steel_d, [_v(w * 0.42, 0), _v(w * 0.74, 0), _v(w * 0.07, top), _v(w * 0.03, top)])
			for i in 5:
				var t0 := i / 5.0
				var t1 := (i + 1) / 5.0
				var y0 := -h * 1.80 * t0
				var y1 := -h * 1.80 * t1
				var x0 := w * (0.58 - 0.53 * t0)
				var x1 := w * (0.58 - 0.53 * t1)
				ln(ci, a(steel_d, 0.75), w * 0.045, -x0, y0, x1, y1)
				ln(ci, a(steel_d, 0.75), w * 0.045, x0, y0, -x1, y1)
			fr(ci, lighten(steel, 0.20), -w * 0.40, -h * 0.78, w * 0.80, h * 0.16)
			fr(ci, lighten(steel, 0.20), -w * 0.20, -h * 1.42, w * 0.40, h * 0.11)
			ln(ci, gold, w * 0.05, -w * 0.40, -h * 0.78, w * 0.40, -h * 0.78)
			ln(ci, lighten(steel, 0.30), w * 0.06, 0, top, 0, top - h * 0.30)
			ci.draw_circle(Vector2(0, top - h * 0.33), h * 0.05, Color8(255, 120, 110))
		"namsan":
			fp(ci, darken(body, 0.42), [_v(-w, -h * 0.02), _v(w, -h * 0.02), _v(w * 0.34, -h * 0.40), _v(-w * 0.36, -h * 0.40)])
			fr(ci, stone_d, -w * 0.24, -h * 0.40, w * 0.48, h * 0.14)
			fr(ci, stone, -w * 0.15, -h * 1.20, w * 0.30, h * 0.80)
			fr(ci, dark, w * 0.04, -h * 1.20, w * 0.11, h * 0.80)
			fe(ci, lighten(body, 0.26), -w * 0.46, -h * 1.34, w * 0.92, h * 0.26)
			fe(ci, dark, -w * 0.46, -h * 1.28, w * 0.92, h * 0.16)
			fe(ci, glass, -w * 0.38, -h * 1.31, w * 0.76, h * 0.13)
			fe(ci, lighten(body, 0.16), -w * 0.32, -h * 1.54, w * 0.64, h * 0.22)
			ln(ci, gold, w * 0.05, -w * 0.44, -h * 1.22, w * 0.44, -h * 1.22)
			ln(ci, lighten(body, 0.30), w * 0.07, 0, -h * 1.52, 0, -h * 2.02)
			ci.draw_circle(Vector2(0, -h * 2.07), h * 0.05, Color8(255, 246, 205))
		_:
			_generic_landmark(ci, w, h, body, dark)

# ==================== 캐릭터 말 ====================


## 태양 광선 한 겹. **안쪽 반지름과 가시 끝을 번갈아 찍어** 각진 별을 만든다 —
## 매끄러운 파형으로 둘레를 흔들면 진폭을 키워도 "울렁이는 원"이지 가시로 안 보인다.
static func _sun_rays(ci: CanvasItem, cx: float, cy: float, inner: float, spike: float, n: int,
		t: float, phase: float, c: Color, alpha: float) -> void:
	if alpha <= 0.01 or inner <= 0.0:
		return
	var pts := PackedVector2Array()
	for k in n * 2:
		var th := k * PI / n + t * 0.22 + phase
		var rad := inner
		if k % 2 == 0:
			var s := k / 2
			var v := 0.5 + 0.5 * sin(t * 2.4 + s * 2.19 + phase * 3.0)
			var v2 := 0.5 + 0.5 * sin(t * 1.33 + s * 0.81 - phase)
			rad = inner + spike * (0.30 + 0.70 * (v * 0.65 + v2 * 0.35))
		pts.append(Vector2(cx + cos(th) * rad, cy + sin(th) * rad))
	G2.fill_fan(ci, pts, a(c, minf(1.0, alpha)), Vector2(cx, cy))


## 말 하나. **둘레 표시는 태양 광선뿐**입니다 — 원반이나 원형 테두리를 같이 두면 가시와 따로
## 놀아 이질감이 생깁니다. 광선 색은 플레이어 색(흰 칸 위에서도 대비가 남게),
## 밝기는 최대치의 0.5~1.0 사이만 오르내립니다(0 까지 내리면 깜빡여 보입니다).
static func token(ci: CanvasItem, cx: float, cy: float, r: float, c: Color, squash: float, active: bool,
		emote: int, time: float, alpha: float, face: int, full: bool = false) -> void:
	var sx := 1.0 + squash * 0.45
	var sy := 1.0 - squash * 0.38
	var tex := art("runner_char_%d" % face)
	if tex != null:
		_figure(ci, tex, cx, cy, r, c, sx, sy, active, time, alpha, full)
		return
	_aura(ci, cx, cy, r, c, time, alpha)
	fe(ci, Color(0, 0, 0, 0.3 * alpha), cx - r * 0.88, cy + r * 0.62, r * 1.76, r * 0.52)

	push(ci, xf(cx, cy, 0.0, sx, sy))
	# 몸통 — 위가 밝은 둥근 공
	fill_round_grad(ci, a(lighten(c, 0.42), alpha), a(darken(c, 0.22), alpha), Rect2(-r, -r, r * 2, r * 2), r)
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, a(darken(c, 0.45), alpha), maxf(1.0, r * 0.13), true)
	fe(ci, Color(1, 1, 1, 0.43 * alpha), -r * 0.55, -r * 0.78, r * 0.6, r * 0.42)
	# 눈
	var ey := -r * 0.05
	var ex := r * 0.34
	var er := r * 0.235
	ci.draw_circle(Vector2(-ex, ey), er, a(Color.WHITE, alpha))
	ci.draw_circle(Vector2(ex, ey), er, a(Color.WHITE, alpha))
	var look := sin(time * 1.6) * er * 0.28
	var pr := er * 0.52
	var ink := a(Color8(24, 26, 40), alpha)
	if emote == 2:
		earc(ci, ink, maxf(1.0, r * 0.11), -ex - er, ey - er * 0.4, er * 2, er * 1.4, 200, 140)
		earc(ci, ink, maxf(1.0, r * 0.11), ex - er, ey - er * 0.4, er * 2, er * 1.4, 200, 140)
	else:
		var grow := 1.35 if emote == 3 else 1.0
		ci.draw_circle(Vector2(-ex + look, ey), pr * grow, ink)
		ci.draw_circle(Vector2(ex + look, ey), pr * grow, ink)
	# 입
	var mc := a(Color8(40, 30, 40), alpha)
	var mw := r * 0.42
	var my := r * 0.42
	var lw := maxf(1.0, r * 0.1)
	match emote:
		1:
			earc(ci, mc, lw, -mw / 2, my - r * 0.2, mw, r * 0.4, 20, 140)
		2:
			earc(ci, mc, lw, -mw / 2, my - r * 0.02, mw, r * 0.4, 200, 140)
		3:
			estroke(ci, mc, lw, -mw * 0.22, my - r * 0.1, mw * 0.44, r * 0.3)
		_:
			earc(ci, mc, lw, -mw / 2, my - r * 0.16, mw, r * 0.32, 25, 130)
	_headgear(ci, face, r, alpha, time)
	pop(ci)

	if active:
		_turn_mark(ci, cx, cy - r * 2.15, r, time, alpha)


static func _aura(ci: CanvasItem, cx: float, cy: float, r: float, c: Color, time: float, alpha: float) -> void:
	_sun_rays(ci, cx, cy, r, r * 0.87, 12, time, 0.0, c, alpha * (0.75 + 0.25 * sin(time * 2.1 + 1.2)) * 110.0 / 255.0)
	_sun_rays(ci, cx, cy, r, r * 0.59, 19, -time, 1.7, c, alpha * (0.75 + 0.25 * sin(time * 2.1 + 0.5)) * 150.0 / 255.0)
	_sun_rays(ci, cx, cy, r * 1.02, r * 0.32, 28, time * 1.4, 3.1, c, alpha * (0.75 + 0.25 * sin(time * 2.1)) * 195.0 / 255.0)


## 차례 표시 — 머리 위에서 통통 튀는 금빛 삼각형.
static func _turn_mark(ci: CanvasItem, cx: float, y: float, r: float, time: float, alpha: float) -> void:
	var bob := sin(time * 5.5) * r * 0.22
	tri(ci, a(WrD.GOLD, alpha), cx, y - bob, r * 0.85, r * 0.72, true)
	tri(ci, a(Color8(255, 240, 190), alpha * 0.9), cx, y - r * 0.07 - bob, r * 0.5, r * 0.42, true)


## 그림 말. full = 판 위의 전신(칸보다 커도 된다 — 사용자 결정), 아니면 패널용 얼굴 부분만.
## 얼굴 · 모자가 그림에 들어 있어 표정(emote)은 안 그린다. 오라(광선)도 안 그린다.
## 그림은 post.gd 의 sprite 모드라 캐릭터가 정사각형 높이의 0.037~0.963 을 차지한다.
static func _figure(ci: CanvasItem, tex: Texture2D, cx: float, cy: float, r: float, c: Color, sx: float, sy: float,
		active: bool, time: float, alpha: float, full: bool) -> void:
	var mod := Color(1, 1, 1, alpha)
	var name := tex.resource_path.get_file().get_basename()
	var cloth := art(name + "_cloth")
	var glow := art(name + "_glow")
	# 옷은 플레이어 색 — 흰 옷 넷이 섞이면 누가 누군지 헷갈린다(사용자 결정). 마스크가 원래 명암을 들고 있다
	var cloth_mod := a(vivid(c), alpha)
	if not full:
		var sz := float(tex.get_width())
		var dst := Rect2(cx - r * 1.2, cy - r * 1.2, r * 2.4, r * 2.4)
		var src := Rect2(sz * 0.2, sz * 0.02, sz * 0.6, sz * 0.6)
		ci.draw_texture_rect_region(tex, dst, src, mod)
		if cloth != null:
			ci.draw_texture_rect_region(cloth, dst, src, cloth_mod)
		return
	var hgt := r * 4.4
	var ground := cy + r * 1.1   # 공 모양 말의 발밑과 같은 자리 — 칸 위 자리 계산을 그대로 쓴다
	fe(ci, Color(0, 0, 0, 0.3 * alpha), cx - r * 0.9, ground - r * 0.22, r * 1.8, r * 0.44)
	push(ci, xf(cx, ground, 0.0, sx, sy))
	var rc := Rect2(-hgt / 2, -hgt * 0.965, hgt, hgt)
	if glow != null:
		# 실루엣을 번진 빛 — 캐릭터 둘레에만 은은하게. 명멸은 0.5~1.0 사이만(0 까지 내리면 깜빡여 보인다)
		var pulse := 0.75 + 0.25 * sin(time * 2.1)
		ci.draw_texture_rect(glow, rc.grow(hgt * 0.05), false, a(lighten(c, 0.3), 0.7 * pulse * alpha))
	ci.draw_texture_rect(tex, rc, false, mod)
	if cloth != null:
		ci.draw_texture_rect(cloth, rc, false, cloth_mod)
	pop(ci)
	if active:
		_turn_mark(ci, cx, ground - hgt * 0.95 * sy - r * 0.6, r, time, alpha)


## 모자 표장 — 금빛 월계관이 가운데 문양을 감싼다.
static func _cap_badge(ci: CanvasItem, cx: float, cy: float, s: float, al: float) -> void:
	fe(ci, a(Color8(24, 54, 40), al), cx - s * 0.72, cy - s * 0.72, s * 1.44, s * 1.44)
	earc(ci, a(WrD.GOLD_DEEP, al), maxf(1.0, s * 0.30), cx - s * 0.88, cy - s * 0.88, s * 1.76, s * 1.76, 292, 316)
	for i in 6:
		var ang := deg_to_rad(302 + i * 51)
		ci.draw_circle(Vector2(cx + cos(ang) * s * 0.88, cy + sin(ang) * s * 0.88), s * 0.19, a(WrD.GOLD, al))
	fe(ci, a(WrD.GOLD, al), cx - s * 0.34, cy - s * 0.42, s * 0.68, s * 0.84)
	fe(ci, a(Color8(178, 40, 44), al), cx - s * 0.17, cy - s * 0.26, s * 0.34, s * 0.46)


## 입에 문 파이프 — 연기가 천천히 피어오른다.
static func _pipe(ci: CanvasItem, r: float, al: float, time: float) -> void:
	ln(ci, a(Color8(40, 34, 44), al), maxf(1.1, r * 0.15), r * 0.14, r * 0.46, r * 0.64, r * 0.62)
	ln(ci, a(Color8(112, 66, 38), al), maxf(1.2, r * 0.17), r * 0.60, r * 0.61, r * 1.06, r * 0.70)
	fp(ci, a(Color8(112, 66, 38), al), [_v(r * 0.99, r * 0.80), _v(r * 1.38, r * 0.72), _v(r * 1.28, r * 0.20), _v(r * 1.02, r * 0.26)])
	fe(ci, a(Color8(70, 40, 24), al), r * 1.00, r * 0.14, r * 0.30, r * 0.16)
	fe(ci, a(Color8(228, 128, 52), al * 0.9), r * 1.05, r * 0.17, r * 0.20, r * 0.10)
	for i in 3:
		var ph := fmod(time * 0.5 + i * 0.34, 1.0)
		var sr := r * (0.12 + ph * 0.17)
		ci.draw_circle(Vector2(r * 1.14 + ph * r * 0.36, r * 0.12 - ph * r), sr, Color(1, 1, 1, al * 0.32 * (1.0 - ph)))


## 말마다 다른 머리 · 안경. 0 = 사람(베레모 · 월계관 표장 · 파이프), 1 = 비행모 + 고글,
## 2 = 두건 + 뿔테, 3 = 뒤로 쓴 캡 + 동그란 안경 + 경례.
static func _headgear(ci: CanvasItem, face: int, r: float, al: float, time: float) -> void:
	var line := a(Color8(40, 34, 56), al)
	var lw := maxf(0.9, r * 0.10)
	match face:
		0:
			var hat := a(Color8(198, 58, 62), al)
			fpie(ci, hat, -r * 1.16, -r * 1.30, r * 2.32, r * 1.52, 178, 184)
			fe(ci, a(Color8(150, 38, 44), al), -r * 1.04, -r * 0.72, r * 2.08, r * 0.34)
			fe(ci, hat, r * 0.30, -r * 1.34, r * 0.30, r * 0.28)
			_cap_badge(ci, -r * 0.30, -r * 0.82, r * 0.46, al)
			_pipe(ci, r, al, time)
		1:
			var cap := a(Color8(134, 96, 62), al)
			var cap_d := a(Color8(96, 66, 42), al)
			for s in [-1, 1]:
				var x: float = -r * 1.16 if s < 0 else r * 0.56
				fe(ci, cap_d, x, -r * 0.36, r * 0.60, r * 1.16)
				fe(ci, a(Color8(206, 176, 132), al), x + r * 0.13, -r * 0.10, r * 0.34, r * 0.62)
			fpie(ci, cap, -r * 1.06, -r * 1.12, r * 2.12, r * 1.86, 180, 180)
			fr(ci, cap, -r * 1.06, -r * 0.24, r * 2.12, r * 0.14)
			fe(ci, cap_d, -r * 1.06, -r * 0.34, r * 2.12, r * 0.30)
			for s in [-1, 1]:
				var x: float = -r * 0.88 if s < 0 else r * 0.14
				fe(ci, a(Color8(228, 232, 240), al), x, -r * 0.96, r * 0.74, r * 0.62)
				fe(ci, a(Color8(120, 182, 210), al), x + r * 0.09, -r * 0.89, r * 0.56, r * 0.46)
				fe(ci, a(Color.WHITE, al * 0.7), x + r * 0.16, -r * 0.84, r * 0.20, r * 0.14)
			ln(ci, cap_d, r * 0.18, -r * 0.16, -r * 0.68, r * 0.16, -r * 0.68)
		2:
			var band := a(Color8(86, 200, 206), al)
			var band_d := a(Color8(52, 156, 168), al)
			var flap := sin(time * 2.6) * r * 0.12
			fp(ci, band_d, [_v(-r * 0.72, -r * 0.44), _v(-r * 1.42, r * 0.10 + flap), _v(-r * 1.20, r * 0.44 + flap), _v(-r * 0.60, -r * 0.06)])
			fpie(ci, band, -r * 1.08, -r * 1.14, r * 2.16, r * 1.90, 180, 180)
			fr(ci, band, -r * 1.08, -r * 0.26, r * 2.16, r * 0.20)
			ln(ci, band_d, r * 0.16, -r * 1.02, -r * 0.40, r * 1.02, -r * 0.40)
			fe(ci, band_d, -r * 0.16, -r * 1.16, r * 0.34, r * 0.26)
			var rim := a(Color8(46, 40, 58), al)
			for s in [-1, 1]:
				var x: float = -r * 0.74 if s < 0 else r * 0.08
				fr(ci, a(Color8(226, 238, 250, 150), al), x, -r * 0.34, r * 0.66, r * 0.52)
				ci.draw_rect(Rect2(x, -r * 0.34, r * 0.66, r * 0.52), rim, false, lw)
			ln(ci, rim, lw, -r * 0.08, -r * 0.14, r * 0.08, -r * 0.14)
		_:
			var cap := a(Color8(214, 219, 228), al)
			var cap_d := a(Color8(166, 174, 188), al)
			fe(ci, cap_d, -r * 1.52, -r * 0.78, r * 0.90, r * 0.40)
			fpie(ci, cap, -r * 1.04, -r * 1.14, r * 2.08, r * 1.84, 180, 180)
			fr(ci, cap, -r * 1.04, -r * 0.28, r * 2.08, r * 0.16)
			ln(ci, cap_d, r * 0.14, 0, -r * 1.16, 0, -r * 0.30)
			fe(ci, cap_d, r * 0.72, -r * 0.60, r * 0.30, r * 0.26)
			var rim := a(Color8(46, 40, 58), al)
			for s in [-1, 1]:
				var x: float = -r * 0.76 if s < 0 else r * 0.10
				fe(ci, a(Color8(226, 238, 250, 140), al), x, -r * 0.36, r * 0.66, r * 0.62)
				estroke(ci, rim, lw, x, -r * 0.36, r * 0.66, r * 0.62)
			ln(ci, rim, lw, -r * 0.10, -r * 0.06, r * 0.10, -r * 0.06)
			var skin := a(Color8(246, 214, 186), al)
			fp(ci, skin, [_v(r * 0.60, -r * 0.66), _v(r * 1.34, -r * 0.30), _v(r * 1.22, -r * 0.02), _v(r * 0.56, -r * 0.34)])
			ln(ci, line, lw * 0.8, r * 0.66, -r * 0.58, r * 1.24, -r * 0.24)

# ==================== 특수칸 아이콘 ====================


## 특수칸 그림 이름(WrD.T 순서). 도시 · 관광지는 국기라 그림이 없다("").
const SPC_ART := ["runner_spc_start", "", "", "runner_spc_chance", "runner_spc_fund_pay",
		"runner_spc_fund_get", "runner_spc_jail", "runner_spc_space", "runner_spc_tax"]


static func special(ci: CanvasItem, t: int, r: Rect2, time: float) -> void:
	var cx := r.get_center().x
	var cy := r.get_center().y
	var s := minf(r.size.x, r.size.y)
	# 그림이 있으면 그림 — 칸 자리에 맞춰 앉힌다(위아래로 흔들면 칸에서 떠 보인다)
	var tx: Texture2D = art(SPC_ART[t]) if t < SPC_ART.size() and SPC_ART[t] != "" else null
	if tx != null:
		var ts := tx.get_size()
		var k := minf(r.size.x / ts.x, r.size.y / ts.y)
		ci.draw_texture_rect(tx, Rect2(Vector2(cx, cy) - ts * k * 0.5, ts * k), false)
		return
	match t:
		WrD.T.START:
			var col := Color8(34, 197, 94)
			var p := 0.5 + 0.5 * sin(time * 3.0)
			for i in 3:
				var off := i * s * 0.16 - s * 0.16 + p * s * 0.05
				tri(ci, a(col, (90 + i * 55) / 255.0), cx + off, cy, s * 0.3, s * 0.42, false)
		WrD.T.JAIL:
			fe(ci, WrD.SEA, cx - s * 0.42, cy - s * 0.05, s * 0.84, s * 0.36)
			fpie(ci, Color8(250, 204, 21), cx - s * 0.3, cy - s * 0.08, s * 0.6, s * 0.34, 180, 180)
			fr(ci, Color8(120, 72, 40), cx - s * 0.03, cy - s * 0.34, s * 0.06, s * 0.28)
			var sway := sin(time * 2.2) * s * 0.03
			var leaf := Color8(22, 163, 74)
			fe(ci, leaf, cx - s * 0.28 + sway, cy - s * 0.42, s * 0.3, s * 0.14)
			fe(ci, leaf, cx - s * 0.02 + sway, cy - s * 0.45, s * 0.3, s * 0.14)
			fe(ci, leaf, cx - s * 0.16 + sway, cy - s * 0.52, s * 0.28, s * 0.13)
		WrD.T.SPACE:
			var fl := 0.5 + 0.5 * sin(time * 14.0)
			push(ci, xf(cx, cy + sin(time * 2.0) * s * 0.03, deg_to_rad(-20.0)))
			fp(ci, Color8(255, 140, 60), [_v(-s * 0.09, s * 0.2), _v(s * 0.09, s * 0.2), _v(0, s * (0.3 + fl * 0.16))])
			fp(ci, Color8(236, 240, 250), [_v(0, -s * 0.4), _v(s * 0.14, -s * 0.02), _v(s * 0.14, s * 0.2),
					_v(-s * 0.14, s * 0.2), _v(-s * 0.14, -s * 0.02)])
			fp(ci, WrD.RED, [_v(-s * 0.14, s * 0.05), _v(-s * 0.3, s * 0.24), _v(-s * 0.14, s * 0.2)])
			fp(ci, WrD.RED, [_v(s * 0.14, s * 0.05), _v(s * 0.3, s * 0.24), _v(s * 0.14, s * 0.2)])
			ci.draw_circle(Vector2(0, -s * 0.15), s * 0.07, WrD.ACCENT)
			pop(ci)
		WrD.T.CHANCE:
			push(ci, xf(cx, cy, deg_to_rad(sin(time * 2.6) * 12.0 - 25.0)))
			ci.draw_circle(Vector2(0, -s * 0.14), s * 0.2, WrD.GOLD)
			fr(ci, WrD.GOLD, -s * 0.055, -s * 0.02, s * 0.11, s * 0.4)
			fr(ci, WrD.GOLD, -s * 0.055, s * 0.14, s * 0.22, s * 0.07)
			fr(ci, WrD.GOLD, -s * 0.055, s * 0.28, s * 0.19, s * 0.07)
			ci.draw_circle(Vector2(0, -s * 0.145), s * 0.085, WrD.BOARD_BG)
			pop(ci)
		WrD.T.FUND_PAY:
			coin(ci, cx, cy + s * 0.06, s * 0.2, 1.0, 0.0)
			tri(ci, WrD.BAD, cx, cy - s * 0.28, s * 0.26, s * 0.2, true)
		WrD.T.FUND_GET:
			coin(ci, cx - s * 0.15, cy + s * 0.14, s * 0.16, 1.0, 0.0)
			coin(ci, cx + s * 0.15, cy + s * 0.14, s * 0.16, 1.0, 0.0)
			coin(ci, cx, cy - s * 0.06, s * 0.19, 1.0, 0.0)
			var p := 0.5 + 0.5 * sin(time * 5.0)
			star(ci, Color(1, 1, 1, (120 + p * 120) / 255.0), cx + s * 0.26, cy - s * 0.26, s * 0.1, 4, time)
		WrD.T.TAX:
			var col := Color8(203, 213, 225)
			fr(ci, col, cx - s * 0.34, cy + s * 0.2, s * 0.68, s * 0.08)
			for i in 4:
				fr(ci, col, cx - s * 0.28 + i * s * 0.18, cy - s * 0.1, s * 0.07, s * 0.3)
			fp(ci, Color8(148, 163, 184), [_v(cx - s * 0.38, cy - s * 0.1), _v(cx, cy - s * 0.36), _v(cx + s * 0.38, cy - s * 0.1)])
