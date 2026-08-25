class_name G2
extends RefCounted

## 그리기 헬퍼.
##
## 폰에서 돌 것이므로 도형은 되도록 싸게 그린다. 엔진이 배칭해 주는 draw_circle /
## draw_line 을 우선 쓰고, 실루엣이 꼭 필요할 때만 fill_fan 으로 넘긴다.

# ==================== 칠하기 ====================

## 중심에서 부채꼴로 채운다.
##
## draw_colored_polygon 은 삼각분할에 실패하면 조용히 도형을 안 그리고 stderr 에만
## 오류를 뱉는다. 중심을 둘러싼 외곽선은 부채꼴로 채우면 결과가 같고 절대 실패하지 않는다.
static func fill_fan(ci: CanvasItem, poly: PackedVector2Array, c: Color) -> void:
	var n := poly.size()
	if n < 3:
		return
	var pts := PackedVector2Array()
	pts.resize(n + 1)
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	pts[0] = cen / n
	for i in n:
		pts[i + 1] = poly[i]
	var idx := PackedInt32Array()
	idx.resize(n * 3)
	for i in n:
		idx[i * 3] = 0
		idx[i * 3 + 1] = i + 1
		idx[i * 3 + 2] = (i + 1) % n + 1
	var cols := PackedColorArray()
	cols.resize(n + 1)
	cols.fill(c)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


static func stroke(ci: CanvasItem, poly: PackedVector2Array, c: Color, w: float) -> void:
	if poly.size() < 2 or w <= 0.0:
		return
	var loop := poly.duplicate()
	loop.append(poly[0])
	ci.draw_polyline(loop, c, w, true)


## 바탕 · 외곽선 한 번에. 실루엣이 있는 조각은 거의 다 이걸 쓴다.
static func body(ci: CanvasItem, poly: PackedVector2Array, fill: Color, lw: float = 1.6,
		line: Color = P.LINE) -> void:
	fill_fan(ci, poly, fill)
	if lw > 0.0:
		stroke(ci, poly, line, lw)

# ==================== 도형 만들기 ====================

static func poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = Vector2(pts[i][0], pts[i][1])
	return out


## 좌우 뒤집기. 날개처럼 대칭인 조각을 한 번만 적어 두고 쓴다.
static func mirror(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = Vector2(-p[i].x, p[i].y)
	return out


static func xf(p: PackedVector2Array, tf: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = tf * p[i]
	return out


static func ellipse_pts(c: Vector2, rx: float, ry: float, seg: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if rx <= 0.0 or ry <= 0.0:
		return pts
	for i in seg:
		var ang := TAU * i / seg
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

# ==================== 빛 ====================

## 가장자리가 부드럽게 사라지는 빛.
##
## 반투명 원을 여러 겹 겹치면 층 경계가 띠로 보인다. 방사형 그라데이션 텍스처를
## 한 번 만들어 늘려 그리는 쪽이 매끄럽고 싸다.
static var _glow_tex: GradientTexture2D


static func _glow_texture() -> GradientTexture2D:
	if _glow_tex != null:
		return _glow_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = grad
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128
	return _glow_tex


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, strength: float) -> void:
	if strength <= 0.004 or r <= 0.0:
		return
	ci.draw_texture_rect(_glow_texture(), Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)),
			false, P.a(col, clampf(strength, 0.0, 1.0)))

# ==================== 글자 ====================

static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		bold: bool = true) -> void:
	if s.is_empty():
		return
	ci.draw_string(P.font(bold), pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


static func text_w(s: String, size: float, bold: bool = true) -> float:
	return P.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x


## pos 가 글자 중심이 된다
static func text_mid(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		bold: bool = true) -> void:
	if s.is_empty():
		return
	var f := P.font(bold)
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	ci.draw_string(f, pos - Vector2(m.x * 0.5, -m.y * 0.32), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


static func text_right(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		bold: bool = true) -> void:
	if s.is_empty():
		return
	ci.draw_string(P.font(bold), pos - Vector2(text_w(s, size, bold), 0), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


## 폭에 맞춰 줄을 접는다. **다음 줄이 시작될 y** 를 돌려주므로 이어 그리는 쪽이 받아 쓴다.
## 자리를 상수로 박아 두면 글이 2줄이 되기도 3줄이 되기도 해서 아래 것을 덮는다.
static func wrap(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		max_w: float, line_h: float, bold: bool = false) -> float:
	var y := pos.y
	var line := ""
	for word in s.split(" ", false):
		var test := word if line.is_empty() else line + " " + word
		if not line.is_empty() and text_w(test, size, bold) > max_w:
			text(ci, Vector2(pos.x, y), line, size, c, bold)
			y += line_h
			line = word
		else:
			line = test
	if not line.is_empty():
		text(ci, Vector2(pos.x, y), line, size, c, bold)
		y += line_h
	return y


static func stroke_rect(ci: CanvasItem, r: Rect2, c: Color, w: float) -> void:
	ci.draw_rect(r, c, false, w)


## 모서리가 둥근 판. 화면 위에 얹는 것은 전부 이걸 쓴다 — 각진 사각형이 겹치면
## 폰 화면에서 UI 가 게임 위에 얹힌 게 아니라 게임의 일부처럼 보인다.
static func panel(ci: CanvasItem, r: Rect2, fill: Color, edge: Color, lw: float = 1.0,
		rad: float = 10.0) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.position.x + rad, r.position.y + rad), PI, PI * 1.5],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5, TAU],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0, PI * 0.5],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5, PI],
	]
	for co in corners:
		var c: Vector2 = co[0]
		var a0: float = co[1]
		var a1: float = co[2]
		for i in 5:
			var ang: float = a0 + (a1 - a0) * i / 4.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	fill_fan(ci, pts, fill)
	if lw > 0.0:
		stroke(ci, pts, edge, lw)

# ==================== 이징 ====================

static func out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
