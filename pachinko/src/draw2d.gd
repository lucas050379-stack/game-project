class_name G2
extends RefCounted

## 그리기 헬퍼.
##
## GDI+ 판에서는 셀 셰이딩을 클리핑으로 처리했지만, 여기서는
## Geometry2D 의 폴리곤 불리언 연산으로 그림자 영역을 정확히 잘라낸다.
## 발광은 반투명 원을 겹치지 않고 HDR 색(1.0 초과)에 맡긴다.

## 빛이 오는 방향 (좌상단)
const LIGHT := -2.35

# ==================== 도형 만들기 ====================

static func ellipse(c: Vector2, rx: float, ry: float, seg: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if rx <= 0.0 or ry <= 0.0:
		return pts
	for i in seg:
		var a := TAU * i / seg
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func circle(c: Vector2, r: float, seg: int = 32) -> PackedVector2Array:
	return ellipse(c, r, r, seg)


static func round_rect(r: Rect2, rad: float, seg: int = 6) -> PackedVector2Array:
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


## 점들을 지나는 부드러운 닫힌 곡선 (Catmull-Rom)
static func blob(keys: Array, seg: int = 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := keys.size()
	if n < 3:
		return pts
	for i in n:
		var p0: Vector2 = keys[(i - 1 + n) % n]
		var p1: Vector2 = keys[i]
		var p2: Vector2 = keys[(i + 1) % n]
		var p3: Vector2 = keys[(i + 2) % n]
		for s in seg:
			var t := float(s) / seg
			pts.append(_catmull(p0, p1, p2, p3, t))
	return pts


## 구심(centripetal) Catmull-Rom.
##
## 균일 파라미터를 쓰면 점이 촘촘한 구간에서 곡선이 부풀어 자기 자신을 파고든다.
## 그렇게 만들어진 폴리곤은 draw_colored_polygon 이 삼각분할에 실패해 오류를 뱉는다.
## 마디 간격을 거리의 제곱근으로 잡으면 고리가 생기지 않는다.
static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t0 := 0.0
	var t1 := t0 + sqrt(p0.distance_to(p1))
	var t2 := t1 + sqrt(p1.distance_to(p2))
	var t3 := t2 + sqrt(p2.distance_to(p3))
	if t1 - t0 < 0.0001 or t2 - t1 < 0.0001 or t3 - t2 < 0.0001:
		return p1.lerp(p2, t)
	var tt := lerpf(t1, t2, t)
	var a1 := p0.lerp(p1, (tt - t0) / (t1 - t0))
	var a2 := p1.lerp(p2, (tt - t1) / (t2 - t1))
	var a3 := p2.lerp(p3, (tt - t2) / (t3 - t2))
	var b1 := a1.lerp(a2, (tt - t0) / (t2 - t0))
	var b2 := a2.lerp(a3, (tt - t1) / (t3 - t1))
	return b1.lerp(b2, (tt - t1) / (t2 - t1))

# ==================== 칠하기 ====================

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
	_glow_tex.width = 256
	_glow_tex.height = 256
	return _glow_tex


static func glow(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color,
		strength: float, _layers: int = 0) -> void:
	if strength <= 0.004 or rx <= 0.0 or ry <= 0.0:
		return
	ci.draw_texture_rect(_glow_texture(), Rect2(c - Vector2(rx, ry), Vector2(rx * 2.0, ry * 2.0)),
			false, P.a(col, clampf(strength, 0.0, 1.0)))


## 면적이 0 에 가까운 조각은 삼각분할이 실패해 오류를 뱉는다. 미리 걸러낸다.
static func _too_thin(poly: PackedVector2Array) -> bool:
	if poly.size() < 3:
		return true
	var a := 0.0
	var n := poly.size()
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5 < 0.75


static func fill(ci: CanvasItem, poly: PackedVector2Array, c: Color) -> void:
	if not _too_thin(poly):
		ci.draw_colored_polygon(poly, c)


static func stroke(ci: CanvasItem, poly: PackedVector2Array, c: Color, w: float) -> void:
	if poly.size() < 2 or w <= 0.0:
		return
	var loop := poly.duplicate()
	loop.append(poly[0])
	ci.draw_polyline(loop, c, w, true)


## 빛 반대쪽 절반을 어둡게 — 셀 셰이딩의 핵심
static func shade(ci: CanvasItem, poly: PackedVector2Array, c: Color, bias: float = 0.02) -> void:
	if poly.size() < 3:
		return
	var mn := poly[0]
	var mx := poly[0]
	for p in poly:
		mn = mn.min(p)
		mx = mx.max(p)
	var mid := (mn + mx) * 0.5
	var r := mn.distance_to(mx) + 8.0
	var ang := LIGHT + PI                      # 그림자 방향
	var d := Vector2(cos(ang), sin(ang))
	var pp := Vector2(-d.y, d.x)
	var o := mid + d * (r * bias)
	var half := PackedVector2Array([
		o + pp * r, o - pp * r, o - pp * r + d * r, o + pp * r + d * r,
	])
	for piece in Geometry2D.intersect_polygons(poly, half):
		fill_fan(ci, piece, c)


## 중심에서 부채꼴로 채운다.
##
## draw_colored_polygon 은 삼각분할을 하는데, 살짝 자기 자신을 파고드는 곡선이면 실패한다.
## 캐릭터·심볼 도형은 모두 중심을 둘러싼 외곽선이라 부채꼴로 채우면 결과가 같고 절대 실패하지 않는다.
static func fill_fan(ci: CanvasItem, poly: PackedVector2Array, c: Color) -> void:
	if _too_thin(poly):
		return
	var n := poly.size()
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


## 바탕 + 셀 그림자 + 외곽선을 한 번에
static func body(ci: CanvasItem, poly: PackedVector2Array, base: Color,
		shade_amt: float = 0.30, outline: float = 2.0, bias: float = 0.02) -> void:
	if _too_thin(poly):
		return
	fill_fan(ci, poly, base)
	if shade_amt > 0.0:
		shade(ci, poly, P.darken(base, shade_amt), bias)
	if outline > 0.0:
		stroke(ci, poly, P.LINE, outline)


static func fill_round(ci: CanvasItem, r: Rect2, rad: float, c: Color) -> void:
	fill(ci, round_rect(r, rad), c)


static func stroke_round(ci: CanvasItem, r: Rect2, rad: float, c: Color, w: float) -> void:
	stroke(ci, round_rect(r, rad), c, w)


## 세로 그라데이션 사각형 (띠를 여러 개 겹쳐 만든다)
static func grad_round(ci: CanvasItem, r: Rect2, rad: float, top: Color, bot: Color,
		bands: int = 14) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var poly := round_rect(r, rad)
	if poly.size() < 3:
		return
	for i in bands:
		var t0 := float(i) / bands
		var t1 := float(i + 1) / bands
		var strip := PackedVector2Array([
			Vector2(r.position.x - 4, r.position.y + r.size.y * t0),
			Vector2(r.end.x + 4, r.position.y + r.size.y * t0),
			Vector2(r.end.x + 4, r.position.y + r.size.y * t1 + 0.6),
			Vector2(r.position.x - 4, r.position.y + r.size.y * t1 + 0.6),
		])
		var c := top.lerp(bot, (t0 + t1) * 0.5)
		for piece in Geometry2D.intersect_polygons(poly, strip):
			fill(ci, piece, c)

# ==================== 글자 ====================

static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, bold: bool = true, width: float = -1.0) -> void:
	if s.is_empty():
		return
	ci.draw_string(P.font(bold), pos, s, align, width, int(size), c)


## 가운데 정렬 — pos 가 글자 중심이 된다
static func text_mid(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		bold: bool = true) -> void:
	if s.is_empty():
		return
	var f := P.font(bold)
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	ci.draw_string(f, pos - Vector2(m.x * 0.5, -m.y * 0.32), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


## 테두리를 두른 큰 글자
static func text_outline(ci: CanvasItem, pos: Vector2, s: String, size: float,
		fill_c: Color, line_c: Color, w: float, bold: bool = true) -> void:
	if s.is_empty():
		return
	var f := P.font(bold)
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	var at := pos - Vector2(m.x * 0.5, -m.y * 0.32)
	for i in 8:
		var a := TAU * i / 8.0
		ci.draw_string(f, at + Vector2(cos(a), sin(a)) * w, s,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), line_c)
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), fill_c)


static func text_width(s: String, size: float, bold: bool = true) -> float:
	return P.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x

# ==================== 이징 ====================

static func out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


static func out_quint(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u * u * u


static func in_quad(t: float) -> float:
	return t * t


static func out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


static func seg(t: float, a: float, b: float) -> float:
	if b <= a:
		return 1.0 if t >= b else 0.0
	return clampf((t - a) / (b - a), 0.0, 1.0)
