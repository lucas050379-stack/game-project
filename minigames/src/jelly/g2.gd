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


## 모서리를 다듬은 판. kind: 0 원호 · 1 부드러운 곡률(초타원 — 직선에서 곡선으로 넘어가는 자리가 안 꺾여 보인다) · 2 깎음 · 3 안으로 파임.
## kind 를 안 주면 지금 게임의 기본 모양(`UiKit.corner_kind`) — 예전에는 모든 게임의 모든 상자가 같은 4분의 1 원이었다(docs/ai-look-overhaul.md #4).
## **가운데에서 부채꼴로 채울 수 있는 모양만 돌려준다**(`fill_fan`) — 파임은 반지름을 짧은 변의 0.3배로 묶어 가운데에서 다 보이게 한다.
static func round_rect(r: Rect2, rad: float, kind: int = -1) -> PackedVector2Array:
	if kind < 0:
		kind = UiKit.corner_kind()
	var half := minf(r.size.x, r.size.y) * 0.5
	rad = minf(rad, half)
	var pts := PackedVector2Array()
	if rad < 0.5:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	# 모서리 넷 — 안쪽 기준점과 시작 각(왼쪽 위부터 시계 방향)
	var corners := [
		[Vector2(r.position.x, r.position.y), Vector2(1, 1), PI],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 1), PI * 1.5],
		[Vector2(r.end.x, r.end.y), Vector2(-1, -1), 0.0],
		[Vector2(r.position.x, r.end.y), Vector2(1, -1), PI * 0.5],
	]
	match kind:
		2:
			var cut := minf(rad * 0.8, half * 0.7)
			for co in corners:
				var c: Vector2 = co[0]
				var d: Vector2 = co[1]
				var a := c + Vector2(0, d.y * cut)
				var b := c + Vector2(d.x * cut, 0)
				# 시계 방향 순서: 왼쪽 위 · 오른쪽 아래는 세로 → 가로, 나머지는 가로 → 세로
				if d.x * d.y > 0:
					pts.append(a)
					pts.append(b)
				else:
					pts.append(b)
					pts.append(a)
		3:
			var nr := minf(rad * 0.8, half * 0.6)
			var seg := clampi(int(nr * 0.5), 3, 8)
			for co in corners:
				var c2: Vector2 = co[0]
				# 모서리 꼭짓점을 중심으로 한 원호를 안쪽으로(각도는 원호의 반대 방향으로 돈다)
				var a0: float = float(co[2]) - PI * 0.5
				for i in seg + 1:
					var ang := a0 - PI * 0.5 * i / seg
					pts.append(c2 + Vector2(cos(ang), sin(ang)) * nr)
		1:
			var big := minf(rad * 1.6, half)
			var seg2 := clampi(int(big * 0.45), 5, 12)
			for co in corners:
				var d2: Vector2 = co[1]
				var cen: Vector2 = co[0] + d2 * big
				for i in seg2 + 1:
					var ang2: float = float(co[2]) + PI * 0.5 * i / seg2
					var cs := cos(ang2)
					var sn := sin(ang2)
					pts.append(cen + Vector2(signf(cs) * pow(absf(cs), 0.5), signf(sn) * pow(absf(sn), 0.5)) * big)
		_:
			var seg3 := clampi(int(rad * 0.6), 4, 12)
			for co in corners:
				var d3: Vector2 = co[1]
				var cen2: Vector2 = co[0] + d3 * rad
				for i in seg3 + 1:
					var ang3: float = float(co[2]) + PI * 0.5 * i / seg3
					pts.append(cen2 + Vector2(cos(ang3), sin(ang3)) * rad)
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
	# 글자 테두리는 게임마다 세기가 다르다 — 어두운 판 위 글자까지 전부 두르던 것을 줄였다(#7). 2px 아래로 내려가면 아예 뺀다.
	outline *= UiKit.outline_k()
	if outline < 2.0:
		outline = 0.0
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
		if c > 0x7f and not _bad_glyph.has(c) and not f.has_char(c) and not UiKit.jua().has_char(c):
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
