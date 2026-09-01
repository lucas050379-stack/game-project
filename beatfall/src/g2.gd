class_name G2
extends RefCounted

## 그리기 헬퍼.
##
## 노트가 화면에 수십~수백 개 깔리므로 도형은 되도록 싸게 그린다.
## 엔진이 배칭해 주는 draw_rect / draw_line / draw_circle 을 우선 쓰고,
## 실루엣이 꼭 필요할 때만 fill_fan 으로 넘긴다.

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


## 세로 그라데이션. 반투명을 겹치지 않고 한 번의 삼각형 배열로 낸다.
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([top, top, bot, bot])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## 모서리를 깎은 사각형. 노트 한 장이 이걸로 그려지므로 정점 수를 최소로 둔다.
static func chamfer(r: Rect2, k: float) -> PackedVector2Array:
	var c := minf(k, minf(r.size.x, r.size.y) * 0.5)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
		Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1),
		Vector2(x0, y1 - c), Vector2(x0, y0 + c)])


static func stroke(ci: CanvasItem, poly: PackedVector2Array, c: Color, w: float) -> void:
	if poly.size() < 2 or w <= 0.0:
		return
	var loop := poly.duplicate()
	loop.append(poly[0])
	ci.draw_polyline(loop, c, w, true)


## 부드러운 빛. 반투명 원을 겹치면 층 경계가 띠로 보이므로 방사형 그라데이션을 늘려 쓴다.
static var _glow_tex: Texture2D = null


static func glow(ci: CanvasItem, at: Vector2, rad: float, c: Color) -> void:
	if _glow_tex == null:
		_glow_tex = _make_glow()
	ci.draw_texture_rect(_glow_tex, Rect2(at - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, c)


static func _make_glow() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.30), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


static func text(ci: CanvasItem, at: Vector2, s: String, size: int, c: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := ThemeDB.fallback_font
	ci.draw_string(f, at, s, align, width, size, c)


static func text_w(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x


## 가운데 정렬 글자. draw_string 의 y 는 baseline 이라 세로 가운데를 맞추려면 보정이 필요하다.
static func text_c(ci: CanvasItem, at: Vector2, s: String, size: int, c: Color) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	ci.draw_string(f, at + Vector2(-w * 0.5, size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)
