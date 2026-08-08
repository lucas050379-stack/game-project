class_name G2
extends RefCounted

## 그리기 헬퍼.
##
## 이 게임은 적이 수백 마리 도는 장르라 도형은 되도록 싸게 그린다.
## draw_circle / draw_line 처럼 엔진이 배칭해 주는 원시 도형을 우선 쓰고,
## 복잡한 실루엣이 필요할 때만 fill_fan 으로 삼각형을 직접 넘긴다.

# ==================== 도형 만들기 ====================

static func circle_pts(c: Vector2, r: float, seg: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if r <= 0.0:
		return pts
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func round_rect(r: Rect2, rad: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return pts
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	if rad <= 0.5:
		pts.append(r.position)
		pts.append(Vector2(r.end.x, r.position.y))
		pts.append(r.end)
		pts.append(Vector2(r.position.x, r.end.y))
		return pts
	var corners := [
		Vector2(r.end.x - rad, r.position.y + rad),
		Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.position.y + rad),
	]
	for ci in 4:
		var base := -PI * 0.5 + ci * PI * 0.5
		for i in seg + 1:
			var a: float = base + PI * 0.5 * i / seg
			pts.append(corners[ci] + Vector2(cos(a), sin(a)) * rad)
	return pts


## 뾰족한 별/톱니. 안쪽 반지름과 끝을 번갈아 찍어 각을 세운다.
static func star_pts(c: Vector2, inner: float, outer: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n * 2:
		var a := k * PI / n + rot
		var rr: float = outer if k % 2 == 0 else inner
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts

# ==================== 칠하기 ====================

## 중심에서 부채꼴로 채운다.
##
## draw_colored_polygon 은 삼각분할을 하는데, 살짝 자기 자신을 파고드는 곡선이면
## 조용히 실패하고 stderr 에만 오류를 뱉는다. 중심을 둘러싼 외곽선은 부채꼴로 채우면
## 결과가 같고 절대 실패하지 않는다.
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


static func fill_round(ci: CanvasItem, r: Rect2, rad: float, c: Color) -> void:
	fill_fan(ci, round_rect(r, rad), c)


static func stroke_round(ci: CanvasItem, r: Rect2, rad: float, c: Color, w: float) -> void:
	stroke(ci, round_rect(r, rad), c, w)


## 세로 그라데이션 사각형 (띠를 겹쳐 만든다)
static func grad_round(ci: CanvasItem, r: Rect2, rad: float, top: Color, bot: Color,
		bands: int = 10) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	for i in bands:
		var t0 := float(i) / bands
		var t1 := float(i + 1) / bands
		var band := Rect2(r.position.x, r.position.y + r.size.y * t0,
			r.size.x, r.size.y * (t1 - t0) + 0.8)
		var rr: float = rad if (i == 0 or i == bands - 1) else 0.0
		fill_round(ci, band, rr, top.lerp(bot, (t0 + t1) * 0.5))

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
		align: int = HORIZONTAL_ALIGNMENT_LEFT, bold: bool = true) -> void:
	if s.is_empty():
		return
	ci.draw_string(P.font(bold), pos, s, align, -1, int(size), c)


## pos 가 글자 중심이 된다
static func text_mid(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		bold: bool = true) -> void:
	if s.is_empty():
		return
	var f := P.font(bold)
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	ci.draw_string(f, pos - Vector2(m.x * 0.5, -m.y * 0.32), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


static func text_w(s: String, size: float, bold: bool = true) -> float:
	return P.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x

# ==================== 이징 ====================

static func out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


static func out_back(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


static func in_quad(t: float) -> float:
	return t * t
