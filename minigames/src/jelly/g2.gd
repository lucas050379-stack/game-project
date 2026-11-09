class_name G2
extends RefCounted

## 그리기 헬퍼.

## 중심에서 부채꼴로 채운다.
##
## draw_colored_polygon 은 삼각분할에 실패하면 조용히 도형을 안 그린다. 중심에서
## 보이는 외곽선(별 · 하트 · 물방울)은 부채꼴로 채우면 절대 실패하지 않는다.
static func fill_fan(ci: CanvasItem, poly: PackedVector2Array, c: Color,
		cen: Vector2 = Vector2.ZERO) -> void:
	var n := poly.size()
	if n < 3:
		return
	var pts := PackedVector2Array()
	pts.resize(n + 1)
	pts[0] = cen
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


static func scaled(p: PackedVector2Array, k: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = p[i] * k + off
	return out


static func ellipse_pts(c: Vector2, rx: float, ry: float, seg: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in seg:
		var ang := TAU * i / seg
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


## 모서리가 둥근 판.
static func round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
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


static func panel(ci: CanvasItem, r: Rect2, fill: Color, edge: Color = Color(0, 0, 0, 0),
		lw: float = 0.0, rad: float = 18.0) -> void:
	var pts := round_rect(r, rad)
	fill_fan(ci, pts, fill, r.get_center())
	if lw > 0.0:
		stroke(ci, pts, edge, lw)

# ==================== 글자 ====================

## pos 가 글자 중심. 테두리를 두르면 밝은 바탕 위에서도 읽힌다.
static func text_mid(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color,
		outline: float = 0.0, oc: Color = P.INK) -> void:
	if s.is_empty() or size < 1.0:
		return
	s = UiKit.clean(s)
	var f := P.font()
	if OS.is_debug_build():
		_check_glyphs(f, s)
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	var at := pos - Vector2(m.x * 0.5, -size * 0.36)
	if outline > 0.0:
		ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), int(outline), oc)
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)

## **Jua 에 없는 글자(· — × → 등)는 브라우저에서만 네모로 나온다** — 데스크톱은 시스템 글꼴이
## 메워 줘서 안 보인다. 실제로 두 번 그렇게 나갔다. 디버그 실행에서 한 번씩 stderr 에 알린다.
static var _bad_glyph := {}


static func _check_glyphs(f: Font, s: String) -> void:
	for k in s.length():
		var c := s.unicode_at(k)
		if c > 0x7f and not _bad_glyph.has(c) and not f.has_char(c):
			_bad_glyph[c] = true
			push_error("글꼴에 없는 글자 \"%s\" (U+%04X) — 웹에서 네모로 나온다: %s" % [s[k], c, s])

# ==================== 이징 ====================

static func out_cubic(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


static func out_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + t * t * (2.7 * t + 1.7)


static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
