class_name Art
extends RefCounted

## 젤리 그리기 — 몸통 + 얼굴 + 특수 블록 표시.
##
## **몸통은 `art/block_<n>.png` 가 있으면 그림, 없으면 벡터.** 얼굴은 언제나 코드가
## 그린다 — 그래야 깜빡임 · 시선 · 표정이 여섯 종 모두 같은 규칙으로 움직인다.
## AI 로 뽑는 몸통은 그래서 **얼굴이 없어야** 한다(art/README.md).

enum Face { IDLE, WOW, HAPPY, SAD, SQUINT }

# ==================== 얼굴 아틀라스 ====================
## 11-10 — 웹에서 판이 느렸다: 젤리 64개의 얼굴(눈 · 동공 · 하이라이트 · 볼 · 입 · 흰 테)을 매 프레임 도형 700여 개로 그려
## 젤리 층만 프레임당 7ms. 그래서 **(색 8 × 표정 · 눈동자 방향 29)을 한 번 그림 한 장에 굽고** 젤리마다 그 칸을 한 번 찍는다.
## 눈동자 방향(`look`)은 9가지(가운데 + 8방향, `_look_idx`)로 나눈다 — 이동 폭이 2px 남짓이라 나눠도 티가 안 난다.
## 다른 젤리를 쳐다볼 때(길이 1 — 힌트 · 바꾸기)와 깜빡일 때는 예전처럼 도형으로 그린다(`_face`).
## 아틀라스가 아직 없으면(처음 한 프레임 · 확인용 화면) 도형으로 그린다. 얼굴 모양을 고치면 `_face` 하나만 고치면 된다.
const FACE_R := 48.0            ## 구울 때의 젤리 반지름
const FACE_CELL := 128          ## 칸 한 변(px) — 얼굴이 반지름의 1.3배 안에 들어간다
const FACE_LOOK_K := 0.65       ## 8방향 눈동자의 길이(무작위 시선 0~1 의 가운데쯤)
static var _face_vp: SubViewport = null
static var _face_tex: Texture2D = null
static var _face_cols := []     ## [표정, 눈동자 방향] — 아틀라스의 열


static func _face_combos() -> Array:
	if _face_cols.is_empty():
		for f in [Face.IDLE, Face.WOW, Face.SAD]:   # 동공이 있는 표정은 방향마다
			for li in 9:
				_face_cols.append([f, li])
		_face_cols.append([Face.HAPPY, 0])
		_face_cols.append([Face.SQUINT, 0])
	return _face_cols


static func _look_vec(li: int) -> Vector2:
	return Vector2.ZERO if li == 0 else Vector2.from_angle(TAU * (li - 1) / 8.0) * FACE_LOOK_K


static func _look_idx(look: Vector2) -> int:
	if look.length() < 0.25:
		return 0
	return 1 + int(round(fposmod(look.angle(), TAU) / (TAU / 8.0))) % 8


## 판을 그리는 노드가 켜질 때 한 번(`host` 는 허브처럼 오래 사는 노드). 이미 있으면 그대로 쓴다.
static func bake_faces(host: Node) -> void:
	if _face_vp != null and is_instance_valid(_face_vp):
		return
	var cols := _face_combos()
	var vp := SubViewport.new()
	vp.size = Vector2i(FACE_CELL * cols.size(), FACE_CELL * 8)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	n.draw.connect(func() -> void:
		for ck in 8:   # 0~6 = 젤리 색(얼굴 자리가 종마다 다르다), 7 = 무지개(얼굴이 가운데)
			for j in cols.size():
				var fo: Vector2 = Vector2.ZERO if ck == 7 else D.FACE_AT[ck] * FACE_R
				n.draw_set_transform(Vector2((j + 0.5) * FACE_CELL, (ck + 0.5) * FACE_CELL))
				_face(n, FACE_R, fo, int(cols[j][0]), _look_vec(int(cols[j][1])), false)
		n.draw_set_transform(Vector2.ZERO))
	vp.add_child(n)
	host.add_child(vp)
	# 투명 바탕에 반투명(흰 테 · 볼)을 그리면 색이 검정과 섞여 저장된다(premultiplied) — 그대로 쓰면 흰 테가 회색으로 탁했다.
	# 그래서 한 번 더: 둘째 그림판에 섞지 않고(blend_disabled) 색을 알파로 나눠 옮겨 적는다.
	var vp2 := SubViewport.new()
	vp2.size = vp.size
	vp2.transparent_bg = true
	vp2.disable_3d = true
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var spr := Sprite2D.new()
	spr.centered = false
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = c.a > 0.0001 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	spr.material = mat
	vp2.add_child(spr)
	host.add_child(vp2)
	_face_vp = vp2
	_face_tex = null
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp) or not is_instance_valid(vp2):
		return
	spr.texture = vp.get_texture()
	vp2.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp2):
		_face_tex = vp2.get_texture()


## 구운 얼굴을 쓸 수 있으면 그 칸(아틀라스 안의 영역), 아니면 빈 Rect2.
static func _face_cell(ck: int, face: int, look: Vector2, blink: bool) -> Rect2:
	if blink or _face_tex == null or not is_instance_valid(_face_vp) or look.length() > 1.001:
		return Rect2()
	var j := 0   # `_face_combos` 의 순서: IDLE 0~8 · WOW 9~17 · SAD 18~26 · HAPPY 27 · SQUINT 28
	match face:
		Face.IDLE:
			j = _look_idx(look)
		Face.WOW:
			j = 9 + _look_idx(look)
		Face.SAD:
			j = 18 + _look_idx(look)
		Face.HAPPY:
			j = 27
		Face.SQUINT:
			j = 28
		_:
			return Rect2()
	return Rect2(j * FACE_CELL, ck * FACE_CELL, FACE_CELL, FACE_CELL)

## 종마다 실루엣이 다르다. 색만 다르면 색약인 사람이 못 가르고, 빠른 판에서 덩어리로 보인다.
static var _shapes := []


static func shape(c: int) -> PackedVector2Array:
	if _shapes.is_empty():
		for k in 7:
			_shapes.append(_make_shape(k))
	return _shapes[clampi(c, 0, 6)]


## 반지름 1 근처의 외곽선. 전부 원점에서 보이는 모양이라 부채꼴 채우기가 안전하다.
static func _make_shape(k: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var t := TAU * i / n
		var p := Vector2.ZERO
		match k:
			0:  # 동그라미
				p = Vector2(cos(t), sin(t)) * 0.92
			1:  # 둥근 네모 (초타원)
				var rr := pow(pow(absf(cos(t)), 4.0) + pow(absf(sin(t)), 4.0), -0.25)
				p = Vector2(cos(t), sin(t)) * rr * 0.84
			2:  # 별 — 뿔 끝과 골을 번갈아 찍어야 "울렁이는 원"이 아니라 별로 보인다
				var a := t - PI * 0.5
				var s := pow(0.5 + 0.5 * cos(5.0 * (t + PI * 0.5)), 1.4)
				p = Vector2(cos(a), sin(a)) * (0.52 + 0.48 * s)
			3:  # 물방울 — 위가 뾰족
				p = Vector2(sin(t) * sin(t * 0.5) * 1.12, -cos(t) * 0.98 + 0.04)
			4:  # 세모 — 꼭짓점은 원으로 깎아 둥글게
				var seg := fposmod(t + PI * 0.5, TAU / 3.0) - PI / 3.0
				var rr := minf(0.96, 0.52 / cos(seg))
				p = Vector2(cos(t), sin(t)) * rr + Vector2(0, 0.14)
			5:  # 하트
				p = Vector2(16.0 * pow(sin(t), 3.0),
						-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) / 17.0
				p.y += 0.08
			6:  # 다이아몬드 — 꼭짓점을 살짝 둥글린 마름모
				var rr := pow(pow(absf(cos(t)), 1.4) + pow(absf(sin(t)), 1.4), -1.0 / 1.4)
				p = Vector2(cos(t) * 0.95, sin(t) * 1.02) * rr
		pts.append(p)
	return pts


## 젤리 하나. 좌표계는 `draw_set_transform` 으로 젤리 가운데에 맞추고 끝나면 되돌린다.
##   sq    가로 · 세로 배율 (찌그러짐)
##   flash 0..1 하얗게 번쩍 (터지기 직전)
static func jelly(ci: CanvasItem, pos: Vector2, r: float, c: int, sp: int, face: int,
		look: Vector2, blink: bool, sq: Vector2, rot: float, flash: float, t: float) -> void:
	ci.draw_set_transform(pos, rot, sq)
	if sp != D.SP_NONE:
		# 특수 블록은 뒤에서 빛이 맥동한다 — 폰 화면에서 줄무늬만으로는 안 띈다
		var g := r * (2.7 + 0.25 * sin(t * 5.0))
		ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(-g * 0.5, -g * 0.5, g, g), false,
				Color(1, 1, 0.85, 0.75))
	if sp == D.SP_FLY:
		_wings(ci, r, t)
	elif sp == D.SP_AREA:
		_wrapper(ci, r, t, P.jelly(c))
	var rainbow := sp == D.SP_RAINBOW
	var tex := Tex.art("block_rainbow" if rainbow else "block_%d" % c)
	var poly := shape(0 if rainbow else c)
	var body := P.jelly(c)
	if tex != null:
		var s := r * 2.2
		ci.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
	elif rainbow:
		_rainbow_body(ci, r, t)
	else:
		G2.fill_fan(ci, G2.scaled(poly, r + r * 0.12), body.darkened(0.5))
		G2.fill_fan(ci, G2.scaled(poly, r), body)
		G2.fill_fan(ci, G2.scaled(poly, r * 0.68, Vector2(-0.06, -0.12) * r), body.lightened(0.22))
		ci.draw_circle(Vector2(-0.34, -0.42) * r, r * 0.15, Color(1, 1, 1, 0.85))
		ci.draw_circle(Vector2(-0.1, -0.56) * r, r * 0.06, Color(1, 1, 1, 0.75))

	match sp:
		D.SP_LINE_H, D.SP_LINE_V:
			_stripes(ci, r, sp == D.SP_LINE_H, t)
		D.SP_AREA:
			var sz := r * (0.7 + 0.15 * sin(t * 13.0))
			ci.draw_texture_rect(Tex.fx("fx_spark"), Rect2(Vector2(0.5, -0.95) * r - Vector2(sz, sz) * 0.5,
					Vector2(sz, sz)), false, Color(1, 0.9, 0.5))

	var cell := _face_cell(7 if rainbow else clampi(c, 0, 6), face, look, blink)
	if cell.has_area():   # 구운 얼굴(얼굴 아틀라스 — 맨 위 설명)
		var half := FACE_CELL * 0.5 * r / FACE_R
		ci.draw_texture_rect_region(_face_tex, Rect2(-half, -half, half * 2.0, half * 2.0), cell)
	else:
		var fo: Vector2 = Vector2.ZERO if rainbow else D.FACE_AT[clampi(c, 0, 6)] * r
		_face(ci, r, fo, face, look, blink)

	if flash > 0.0:
		if tex == null and not rainbow:
			G2.fill_fan(ci, G2.scaled(poly, r * 1.05), Color(1, 1, 1, flash * 0.85))
		else:
			var g := r * 2.6
			ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(-g * 0.5, -g * 0.5, g, g), false,
					Color(1, 1, 1, flash))
	ci.draw_set_transform(Vector2.ZERO)


static func _rainbow_body(ci: CanvasItem, r: float, t: float) -> void:
	ci.draw_circle(Vector2.ZERO, r * 1.04, P.LINE)
	var spin := t * 1.6
	for k in 6:
		var a0 := spin + TAU * k / 6.0
		var wedge := PackedVector2Array([Vector2.ZERO])
		for s in 5:
			var a := a0 + TAU / 6.0 * s / 4.0
			wedge.append(Vector2(cos(a), sin(a)) * r * 0.92)
		G2.fill_fan(ci, wedge, P.RAINBOW[k], Vector2.ZERO)
	ci.draw_circle(Vector2.ZERO, r * 0.55, Color(1, 1, 1, 0.55))
	ci.draw_circle(Vector2(-0.34, -0.42) * r, r * 0.15, Color(1, 1, 1, 0.9))


## 줄 폭탄 — 나가는 방향으로 흰 줄 두 개 + 양 끝 화살촉.
static func _stripes(ci: CanvasItem, r: float, horiz: bool, t: float) -> void:
	var a := 0.82 + 0.15 * sin(t * 7.0)
	var white := Color(1, 1, 1, a)
	for k in [-0.26, 0.26]:
		var o: float = k * r
		if horiz:
			ci.draw_line(Vector2(-0.8 * r, o), Vector2(0.8 * r, o), white, r * 0.17)
		else:
			ci.draw_line(Vector2(o, -0.8 * r), Vector2(o, 0.8 * r), white, r * 0.17)
	for s in [-1.0, 1.0]:
		var tip := Vector2(s * 1.22 * r, 0) if horiz else Vector2(0, s * 1.22 * r)
		var side := Vector2(0, 0.22 * r) if horiz else Vector2(0.22 * r, 0)
		var back := tip - tip.normalized() * 0.28 * r
		ci.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), white)


## 선으로만 그리는 표정(^^ · > < · 감은 눈 · 입)은 밑에 흰 테를 먼저 깐다(`HALO`). 진한 선만 두면
## 어두운 몸통(포도)에서 표정이 통째로 사라졌다 — 피버 때 다 HAPPY 로 바뀌어 거기서 드러났다.
const HALO := Color(1, 1, 1, 0.85)

static func _face(ci: CanvasItem, r: float, fo: Vector2, face: int, look: Vector2, blink: bool) -> void:
	var lw := r * 0.075
	var er := r * 0.16
	for s in [-1.0, 1.0]:
		var e: Vector2 = fo + Vector2(s * 0.3 * r, -0.08 * r)
		match face:
			Face.SQUINT:
				# > <  — 눈을 질끈 감은 얼굴
				var sq_pts := PackedVector2Array([
					e + Vector2(-s * er, -er), e + Vector2(s * er * 0.6, 0), e + Vector2(-s * er, er)])
				ci.draw_polyline(sq_pts, HALO, lw * 2.2, true)
				ci.draw_polyline(sq_pts, P.INK, lw, true)
			Face.HAPPY:
				ci.draw_arc(e + Vector2(0, er * 0.4), er * 0.85, PI * 1.15, PI * 1.85, 8, HALO, lw * 2.2, true)
				ci.draw_arc(e + Vector2(0, er * 0.4), er * 0.85, PI * 1.15, PI * 1.85, 8, P.INK, lw, true)
			_:
				if blink:
					ci.draw_line(e - Vector2(er, 0), e + Vector2(er, 0), HALO, lw * 2.2, true)
					ci.draw_line(e - Vector2(er, 0), e + Vector2(er, 0), P.INK, lw, true)
				else:
					var big := 1.3 if face == Face.WOW else 1.0
					ci.draw_circle(e, er * big, Color(1, 1, 1))
					var pupil := e + look * er * 0.38
					ci.draw_circle(pupil, er * 0.62 * big, P.INK)
					ci.draw_circle(pupil + Vector2(-0.25, -0.3) * er, er * 0.2, Color(1, 1, 1))
		ci.draw_circle(fo + Vector2(s * 0.52 * r, 0.12 * r), r * 0.09, Color(1, 0.45, 0.6, 0.45))

	var m := fo + Vector2(0, 0.2 * r)
	match face:
		Face.WOW:
			ci.draw_circle(m + Vector2(0, 0.03 * r), r * 0.08, P.INK)
		Face.SAD:
			ci.draw_arc(m + Vector2(0, 0.12 * r), r * 0.12, PI * 1.2, PI * 1.8, 10, HALO, lw * 2.0, true)
			ci.draw_arc(m + Vector2(0, 0.12 * r), r * 0.12, PI * 1.2, PI * 1.8, 10, P.INK, lw * 0.85, true)
		Face.HAPPY, Face.SQUINT:
			var mouth := PackedVector2Array()
			for k in 9:
				var a := PI * k / 8.0
				mouth.append(m + Vector2(cos(a) * 0.15 * r, sin(a) * 0.15 * r - 0.02 * r))
			G2.fill_fan(ci, mouth, HALO, m + Vector2(0, 0.05 * r))   # 테 — 아래 줄이 같은 점을 조금 줄여 덮는다
			for k in mouth.size():
				mouth[k] = m + (mouth[k] - m) * 0.82
			G2.fill_fan(ci, mouth, P.INK, m + Vector2(0, 0.05 * r))
			ci.draw_circle(m + Vector2(0, 0.08 * r), r * 0.05, Color(1, 0.5, 0.6))
		_:
			ci.draw_arc(m - Vector2(0, 0.06 * r), r * 0.13, PI * 0.22, PI * 0.78, 10, HALO, lw * 2.0, true)
			ci.draw_arc(m - Vector2(0, 0.06 * r), r * 0.13, PI * 0.22, PI * 0.78, 10, P.INK, lw * 0.85, true)


## 날개 젤리 — 몸통 뒤로 흰 날개 둘이 퍼덕인다.
## 범위 폭탄 — 사탕 포장지처럼 양옆에 주름진 매듭. 얇은 고리 하나뿐이던 시절에는 줄 폭탄 · 보통 젤리와
## 잘 안 갈렸다("눈에 안 띈다"). 줄 폭탄(화살촉) · 날개 젤리(깃털)와 실루엣이 겹치지 않는 모양을 골랐다.
static func _wrapper(ci: CanvasItem, r: float, t: float, body: Color) -> void:
	var wig := 0.08 * sin(t * 7.0)
	var fill := body.lightened(0.35)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		pts.append(Vector2(s * 0.7, -0.16) * r)
		for k in 5:
			# 바깥 가장자리를 톱니처럼 — 주름 잡힌 포장지
			var y := lerpf(-0.62, 0.62, k / 4.0)
			var x: float = 1.3 + (0.0 if k % 2 == 0 else -0.13) + wig * s * (1.0 if k % 2 == 0 else 0.5)
			pts.append(Vector2(s * x, y) * r)
		pts.append(Vector2(s * 0.7, 0.16) * r)
		var cen := Vector2(s * 1.08, 0) * r
		G2.fill_fan(ci, G2.scaled(pts, 1.0), fill, cen)
		G2.stroke(ci, pts, P.LINE, r * 0.08)
		for y in [-0.3, 0.0, 0.3]:
			ci.draw_line(Vector2(s * 0.82, y * 0.3) * r, Vector2(s * 1.2, y) * r, body.darkened(0.05), r * 0.05, true)


static func _wings(ci: CanvasItem, r: float, t: float) -> void:
	var flap := 0.55 + 0.45 * absf(sin(t * 11.0))
	for s in [-1.0, 1.0]:
		var cen := Vector2(s * 0.95 * r, -0.25 * r)
		var pts := PackedVector2Array()
		for k in 14:
			var a := TAU * k / 14.0
			pts.append(Vector2(cos(a) * 0.48, sin(a) * 0.26 * flap).rotated(-s * 0.5) * r + cen)
		G2.fill_fan(ci, pts, Color(1, 1, 1, 0.95), cen)
		G2.stroke(ci, pts, P.LINE, r * 0.06)

# ==================== 칸 · 장애물 ====================

## 칸 바탕. 구멍 칸은 안 그린다 — 그래서 판 모양이 보인다.
static func cell_bg(ci: CanvasItem, rect: Rect2, alt: bool) -> void:
	var ct := Tex.art("fl_cell")
	if ct != null:
		ci.draw_texture_rect(ct, rect.grow(-2), false, Color(1, 1, 1) if alt else Color(0.9, 0.88, 0.96))
		return
	G2.panel(ci, rect.grow(-2), P.CELL_A if alt else P.CELL_B, Color(), 0.0, rect.size.x * 0.18)


## 설탕막 — 겹이 많을수록 진하다. 줄을 겹 수만큼 그어 색이 비슷해도 몇 겹인지 읽힌다.
static func sugar(ci: CanvasItem, rect: Rect2, layers: int) -> void:
	var c := D.SUGAR_C
	var r := rect.grow(-3)
	if not _tile(ci, "fl_sugar", rect, 0.0, Color(1, 1, 1, 0.45 + 0.18 * layers)):
		G2.panel(ci, r, P.a(c, 0.25 + 0.2 * layers), P.a(c.lightened(0.5), 0.9), 2.0, r.size.x * 0.18)
	for k in layers:
		var y := r.position.y + r.size.y * (0.82 - 0.12 * k)
		ci.draw_line(Vector2(r.position.x + r.size.x * 0.2, y), Vector2(r.end.x - r.size.x * 0.2, y),
				Color(1, 1, 1, 0.6), maxf(2.0, r.size.x * 0.05))


static func box(ci: CanvasItem, pos: Vector2, r: float, layers: int, hurt: float) -> void:
	var c: Color = D.COOKIE[clampi(layers - 1, 0, 2)]
	pos += Vector2(sin(hurt * 40.0), 0) * hurt * r * 0.12
	var rect := Rect2(pos - Vector2(r, r) * 1.05, Vector2(r, r) * 2.1)
	var tex := Tex.art("ob_box")
	if tex != null:
		# 그림은 한 장 — 겹 수는 진하기와 아래 알갱이 수로 읽힌다(겹마다 따로 뽑으면 다른 상자가 된다)
		var k: float = [1.0, 0.82, 0.66][clampi(layers - 1, 0, 2)]
		ci.draw_texture_rect(tex, rect.grow(r * 0.08), false, Color(k, k * 0.95, k * 0.9))
		_pips(ci, pos + Vector2(0, r * 0.98), r, layers)
		if hurt > 0.0:
			ci.draw_texture_rect(tex, rect.grow(r * 0.08), false, Color(1, 1, 1, hurt * 0.6))
		return
	G2.panel(ci, rect, c, c.darkened(0.5), r * 0.1, r * 0.35)
	G2.panel(ci, rect.grow(-r * 0.22), c.lightened(0.12), Color(), 0.0, r * 0.25)
	# 초코칩 — 겹마다 둘씩 늘어난다(색이 비슷해도 개수로 읽힌다)
	var chips := [Vector2(-0.4, -0.35), Vector2(0.35, 0.3), Vector2(0.38, -0.4), Vector2(-0.3, 0.42),
			Vector2(0.0, 0.0), Vector2(-0.55, 0.05)]
	for k in mini(chips.size(), layers * 2):
		ci.draw_circle(pos + chips[k] * r, r * 0.11, D.CHOCO_C)
	if layers >= 3:
		var top := PackedVector2Array()
		for k in 9:
			top.append(pos + Vector2(lerpf(-0.95, 0.95, k / 8.0), -0.62 + (0.12 if k % 2 == 1 else 0.0)) * r)
		ci.draw_polyline(top, Color(1, 1, 1, 0.9), r * 0.16, true)
	if hurt > 0.0:
		G2.panel(ci, rect, Color(1, 1, 1, hurt * 0.5), Color(), 0.0, r * 0.35)


static func choco(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var tex := Tex.art("ob_choco")
	if tex != null:
		# 녹아내리는 느낌 — 바닥을 기준으로 아주 조금 늘었다 줄었다
		var sq := 1.0 + 0.03 * sin(t * 1.5)
		var sz := Vector2(r * 2.2 / sq, r * 2.2 * sq)
		ci.draw_texture_rect(tex, Rect2(pos + Vector2(-sz.x * 0.5, r * 1.1 - sz.y), sz), false)
		return
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		var rr := r * (1.0 + 0.06 * sin(a * 5.0 + t * 1.5))
		pts.append(pos + Vector2(cos(a), sin(a) * 0.92) * rr)
	G2.fill_fan(ci, pts, D.CHOCO_C.darkened(0.35), pos)
	G2.fill_fan(ci, G2.scaled(pts, 0.86, pos * 0.14), D.CHOCO_C, pos)
	ci.draw_circle(pos + Vector2(-0.35, -0.38) * r, r * 0.16, Color(1, 0.85, 0.75, 0.55))
	for s in [-0.4, 0.1, 0.5]:
		ci.draw_line(pos + Vector2(s, 0.55) * r, pos + Vector2(s, 0.85 + 0.1 * sin(t * 2.0 + s * 9.0)) * r,
				D.CHOCO_C.lightened(0.15), r * 0.16, true)


## 칸을 꽉 채우는 바닥 무늬(post.gd 의 tile) — 칸 크기 그대로, 돌리고 반투명하게 깐다. 그림이 없으면 false.
static func _tile(ci: CanvasItem, name: String, rect: Rect2, rot: float = 0.0, mod: Color = Color(1, 1, 1)) -> bool:
	var tex := Tex.art(name)
	if tex == null:
		return false
	var r := rect.grow(-2)
	ci.draw_set_transform(r.get_center(), rot)
	ci.draw_texture_rect(tex, Rect2(-r.size * 0.5, r.size), false, mod)
	ci.draw_set_transform(Vector2.ZERO)
	return true


## AI 그림 한 장을 가운데에 그린다. 그림이 없으면 false — 부른 쪽이 예전 벡터로 그린다.
## 상태(숫자 · 색 · 방향 · 충전)는 그림에 넣지 않고 부른 쪽이 위에 얹는다 — 상태마다 따로 뽑으면 매번 다른 물건이 나온다.
static func _tex(ci: CanvasItem, name: String, pos: Vector2, size: float, rot: float = 0.0,
		mod: Color = Color(1, 1, 1)) -> bool:
	var tex := Tex.art(name)
	if tex == null:
		return false
	ci.draw_set_transform(pos, rot)
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, -size * 0.5, size, size), false, mod)
	ci.draw_set_transform(Vector2.ZERO)
	return true


## 겹 수 알갱이 — 그림 한 장을 겹마다 쓰는 장애물이 몇 겹 남았는지 읽히게 아래에 점을 찍는다.
static func _pips(ci: CanvasItem, at: Vector2, r: float, n: int) -> void:
	for k in n:
		var p := at + Vector2((k - (n - 1) * 0.5) * r * 0.36, 0)
		ci.draw_circle(p, r * 0.15, P.LINE)
		ci.draw_circle(p, r * 0.1, Color(1, 1, 1))


## 사슬 — 젤리 위에 대각선 두 줄로 쇠사슬을 건다. 정면 고리(타원)와 옆 고리(납작한 막대)를
## 번갈아 엮어야 사슬로 읽힌다 — 같은 고리를 늘어놓으면 점선이나 구슬로 보였다.
static func chain(ci: CanvasItem, pos: Vector2, r: float) -> void:
	var steel := Color8(196, 204, 222)
	for d in [Vector2(1, 1), Vector2(1, -1)]:
		var dir: Vector2 = d.normalized()
		var ang := dir.angle()
		for k in 7:
			var p: Vector2 = pos + dir * r * lerpf(-1.08, 1.08, k / 6.0)
			if k % 2 == 1:
				# 옆을 보는 고리 — 사슬 방향으로 누운 짧은 막대
				ci.draw_line(p - dir * r * 0.17, p + dir * r * 0.17, P.LINE, r * 0.2, true)
				ci.draw_line(p - dir * r * 0.15, p + dir * r * 0.15, steel.darkened(0.15), r * 0.11, true)
			else:
				# 정면 고리 — 사슬 방향으로 긴 타원
				ci.draw_set_transform(p, ang, Vector2(1.0, 0.62))
				ci.draw_arc(Vector2.ZERO, r * 0.21, 0, TAU, 18, P.LINE, r * 0.15, true)
				ci.draw_arc(Vector2.ZERO, r * 0.21, 0, TAU, 18, steel, r * 0.08, true)
				ci.draw_arc(Vector2.ZERO, r * 0.21, PI * 1.05, PI * 1.55, 6, Color(1, 1, 1, 0.95), r * 0.045, true)
				ci.draw_set_transform(Vector2.ZERO)


## 얼음 — 젤리를 덮는 반투명 상자. 두 겹이면 거의 안 보인다.
static func ice(ci: CanvasItem, pos: Vector2, r: float, layers: int) -> void:
	var rect := Rect2(pos - Vector2(r, r) * 1.05, Vector2(r, r) * 2.1)
	var tex := Tex.art("ov_ice")
	if tex != null:
		# 가운데가 뚫린 얼음 테 — 젤리 색이 보여야 맞출 수 있다. 두 겹이면 안을 한 겹 더 흐리게 덮는다
		G2.panel(ci, rect.grow(-r * 0.2), P.a(D.ICE_C, 0.25 if layers == 1 else 0.6), Color(), 0.0, r * 0.3)
		ci.draw_texture_rect(tex, rect.grow(r * 0.06), false)
		_pips(ci, pos + Vector2(0, r * 0.98), r, layers)
		return
	G2.panel(ci, rect, P.a(D.ICE_C, 0.42 if layers == 1 else 0.78), Color(1, 1, 1, 0.95), r * 0.08, r * 0.3)
	ci.draw_line(pos + Vector2(-0.7, -0.45) * r, pos + Vector2(-0.35, -0.8) * r, Color(1, 1, 1, 0.9), r * 0.1)
	ci.draw_line(pos + Vector2(-0.7, -0.1) * r, pos + Vector2(0.0, -0.8) * r, Color(1, 1, 1, 0.6), r * 0.07)
	if layers >= 2:
		ci.draw_line(pos + Vector2(0.3, 0.75) * r, pos + Vector2(0.75, 0.3) * r, Color(1, 1, 1, 0.8), r * 0.08)


## 열매 — 버찌 두 알. 맨 아래까지 내려보내면 거둔다.
static func fruit(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var sway := sin(t * 2.5) * 0.08
	if _tex(ci, "ob_fruit", pos, r * 2.4, sway):
		return
	var top := pos + Vector2(0.15, -0.85) * r
	for s in [-1.0, 1.0]:
		var c: Vector2 = pos + Vector2(s * 0.38 + sway, 0.25) * r
		ci.draw_line(c - Vector2(0, r * 0.3), top, Color8(70, 130, 50), r * 0.09, true)
		ci.draw_circle(c, r * 0.44, P.LINE)
		ci.draw_circle(c, r * 0.38, D.FRUIT_C)
		ci.draw_circle(c + Vector2(-0.13, -0.14) * r, r * 0.11, Color(1, 1, 1, 0.8))
	var lc := top + Vector2(r * 0.22, -r * 0.05)
	G2.fill_fan(ci, G2.ellipse_pts(lc, r * 0.3, r * 0.13, 12), Color8(110, 200, 80), lc)


## 몬스터. angry = 다음 턴에 행동한다(노리는 칸도 `target_mark` 로 따로 표시된다).
## 젤리와 같은 셀 셰이딩 — 외곽선 → 빛 반대쪽 그림자 → 밝은 몸통 → 하이라이트. 소품에도 외곽선을 두른다.
## 단색 몸통에 얼굴만 얹던 시절에는 광택이 도는 젤리 옆에서 납작한 스티커처럼 보였다.
## 얼굴은 코드가 그린다 — 경고(angry) · 맞을 때(hurt) 표정이 바뀌어야 해서, 눈이 박힌 AI 몸통은 못 쓴다.
const MON_BODY := {"dough": Color8(240, 210, 160), "knot": Color8(222, 130, 205), "thief": Color8(130, 140, 205),
		"frost": Color8(165, 218, 255), "ninja": Color8(110, 85, 150), "glutton": Color8(255, 168, 85),
		"octo": Color8(240, 125, 160), "boss": Color8(232, 195, 140)}


static func monster(ci: CanvasItem, pos: Vector2, r: float, kind: String, hp: float, t: float,
		hurt: float, angry: bool) -> void:
	pos += Vector2(sin(hurt * 50.0), 0) * hurt * r * 0.15
	var breath := 0.03 * sin(t * 3.0)
	var body: Color = MON_BODY.get(kind, Color8(200, 200, 200))
	if angry:
		body = body.lerp(Color8(255, 110, 110), 0.25 + 0.2 * sin(t * 8.0))
	var s := r * (1.12 if kind == "boss" else 1.0)
	if _mon_tex(ci, "mon_" + kind, kind, pos, r, s, t, breath, hurt, angry):
		_mon_hp(ci, pos, r, hp, angry)
		return
	var u := _mon_shape(kind)
	ci.draw_set_transform(pos, 0.0, Vector2(1.0 - breath, 1.0 + breath))

	# 몸 뒤에 오는 것 — 문어 다리 · 닌자 띠 끝자락
	if kind == "octo":
		for k in 5:
			var x := -0.62 + 0.31 * k
			var leg := PackedVector2Array()
			for j in 6:
				var q := j / 5.0
				leg.append(Vector2(x * (1.0 + q * 0.35) + sin(t * 4.0 + k + q * 3.0) * 0.12 * q, 0.45 + q * 0.62) * s)
			ci.draw_polyline(leg, P.LINE, s * 0.26, true)
			ci.draw_polyline(leg, body.darkened(0.12), s * 0.16, true)
	elif kind == "ninja":
		for k in 2:
			var tail := PackedVector2Array([Vector2(0.78, -0.42) * s,
					Vector2(1.12, -0.3 + k * 0.22 + sin(t * 6.0 + k) * 0.08) * s,
					Vector2(1.32, -0.18 + k * 0.32 + sin(t * 6.0 + k + 1.0) * 0.1) * s])
			ci.draw_polyline(tail, P.LINE, s * 0.2, true)
			ci.draw_polyline(tail, Color8(230, 70, 90), s * 0.11, true)

	# 몸통
	G2.fill_fan(ci, G2.scaled(u, s * 1.1), P.LINE)
	G2.fill_fan(ci, G2.scaled(u, s), body.darkened(0.24))
	G2.fill_fan(ci, G2.scaled(u, s * 0.88, Vector2(-0.07, -0.09) * s), body)
	G2.fill_fan(ci, G2.scaled(u, s * 0.5, Vector2(-0.26, -0.34) * s), body.lightened(0.16))
	ci.draw_circle(Vector2(-0.46, -0.52) * s, s * 0.12, Color(1, 1, 1, 0.85))
	ci.draw_circle(Vector2(-0.24, -0.66) * s, s * 0.05, Color(1, 1, 1, 0.7))

	# 몸에 붙은 것
	match kind:
		"dough":
			for p in [Vector2(0.48, 0.3), Vector2(-0.55, 0.22), Vector2(0.2, 0.55)]:
				ci.draw_circle(p * s, s * 0.07, body.darkened(0.3))
		"knot":
			# 몸을 감은 리본 두 줄 + 위의 매듭
			for y in [-0.05, 0.38]:
				ci.draw_arc(Vector2(0, y - 1.0) * s, s * 1.12, PI * 0.33, PI * 0.67, 14, P.LINE, s * 0.2, true)
				ci.draw_arc(Vector2(0, y - 1.0) * s, s * 1.12, PI * 0.33, PI * 0.67, 14, Color8(255, 90, 120), s * 0.11, true)
			for d in [-1.0, 1.0]:
				var bow := PackedVector2Array([Vector2(0, -0.95), Vector2(d * 0.42, -1.25), Vector2(d * 0.45, -0.82)])
				G2.fill_fan(ci, G2.scaled(bow, s * 1.15, Vector2(0, 0.12) * s), P.LINE, Vector2(d * 0.3, -1.0) * s)
				G2.fill_fan(ci, G2.scaled(bow, s), Color8(255, 90, 120), Vector2(d * 0.28, -1.0) * s)
			ci.draw_circle(Vector2(0, -0.95) * s, s * 0.12, P.LINE)
			ci.draw_circle(Vector2(0, -0.95) * s, s * 0.08, Color8(255, 120, 145))
		"thief":
			# 등에 멘 보따리와 눈가리개(눈 구멍은 아래 눈이 덮는다)
			ci.draw_circle(Vector2(0.78, -0.72) * s, s * 0.36, P.LINE)
			ci.draw_circle(Vector2(0.78, -0.72) * s, s * 0.3, Color8(235, 205, 125))
			ci.draw_line(Vector2(0.62, -0.98) * s, Vector2(0.9, -0.98) * s, P.LINE, s * 0.08, true)
			ci.draw_line(Vector2(-0.95, -0.15) * s, Vector2(0.95, -0.15) * s, P.LINE, s * 0.44, true)
			ci.draw_line(Vector2(-0.92, -0.15) * s, Vector2(0.92, -0.15) * s, Color8(60, 55, 85), s * 0.34, true)
		"frost":
			for d in [-1.0, 1.0]:
				var horn := PackedVector2Array([Vector2(d * 0.28, -0.72), Vector2(d * 0.82, -1.3), Vector2(d * 0.62, -0.62)])
				G2.fill_fan(ci, G2.scaled(horn, s), P.LINE, Vector2(d * 0.55, -0.85) * s)
				G2.fill_fan(ci, G2.scaled(horn, s * 0.86, Vector2(d * 0.08, -0.1) * s), Color8(235, 250, 255),
						Vector2(d * 0.55, -0.9) * s)
			for p in [Vector2(0.55, 0.35), Vector2(-0.6, 0.1)]:
				ci.draw_circle(p * s, s * 0.06, Color(1, 1, 1, 0.8))
		"ninja":
			ci.draw_line(Vector2(-0.98, -0.45) * s, Vector2(0.98, -0.45) * s, P.LINE, s * 0.32, true)
			ci.draw_line(Vector2(-0.95, -0.45) * s, Vector2(0.95, -0.45) * s, Color8(230, 70, 90), s * 0.22, true)
			ci.draw_circle(Vector2(0.0, -0.45) * s, s * 0.11, Color8(220, 225, 240))
		"boss":
			var crown := PackedVector2Array([Vector2(-0.55, -0.72), Vector2(-0.6, -1.22), Vector2(-0.27, -0.95),
					Vector2(0, -1.35), Vector2(0.27, -0.95), Vector2(0.6, -1.22), Vector2(0.55, -0.72)])
			G2.fill_fan(ci, G2.scaled(crown, s), P.GOLD, Vector2(0, -0.85) * s)
			G2.stroke(ci, G2.scaled(crown, s), P.LINE, s * 0.08)
			ci.draw_circle(Vector2(0, -0.92) * s, s * 0.1, Color8(255, 80, 120))
			ci.draw_circle(Vector2(-0.03, -0.95) * s, s * 0.035, Color(1, 1, 1, 0.9))

	_mon_face(ci, s, kind, angry, hurt)
	ci.draw_set_transform(Vector2.ZERO)

	_mon_hp(ci, pos, r, hp, angry)
	if hurt > 0.0:
		ci.draw_set_transform(pos)
		G2.fill_fan(ci, G2.scaled(u, s), Color(1, 1, 1, hurt * 0.6))
		ci.draw_set_transform(Vector2.ZERO)


static func _mon_hp(ci: CanvasItem, pos: Vector2, r: float, hp: float, angry: bool) -> void:
	var bar := Rect2(pos + Vector2(-0.8, 0.84) * r, Vector2(1.6 * r, r * 0.2))
	G2.panel(ci, bar.grow(r * 0.04), P.LINE, Color(), 0.0, r * 0.12)
	G2.panel(ci, Rect2(bar.position, Vector2(bar.size.x * clampf(hp, 0.0, 1.0), bar.size.y)),
			Color8(255, 90, 90).lerp(Color8(120, 230, 110), hp), Color(), 0.0, r * 0.1)
	if angry:
		G2.text_mid(ci, pos + Vector2(0.75, -0.85) * r, "!", r * 0.9, P.WARN, r * 0.15)


## AI 몸통 그림에서 얼굴을 얹을 자리(칸 반지름 r 기준 오프셋, 얼굴 크기 배율). 그림마다 머리 위치가 다르다.
## 그림을 다시 뽑으면 여기를 같이 맞추세요 — 어긋나면 눈이 이마나 배에 붙는다.
const MON_FACE := {"dough": [Vector2(0, 0.0), 1.0], "knot": [Vector2(0, 0.34), 0.9], "thief": [Vector2(0, -0.08), 0.9],
		"frost": [Vector2(0, 0.1), 1.0], "ninja": [Vector2(0, -0.2), 0.9], "glutton": [Vector2(0, 0.0), 1.0],
		"octo": [Vector2(0, -0.42), 0.8], "boss": [Vector2(0, 0.12), 1.0], "mole": [Vector2(0, -0.2), 0.7]}


## 몬스터 몸통 = AI 그림(얼굴은 post.gd 의 noface 가 지웠다) + 코드 얼굴. 그림이 없으면 false.
## 행동 직전(angry)은 몸을 붉게 깜빡이고, 맞으면(hurt) 하얗게 번쩍인다 — 표정과 같이 두 겹으로 알린다.
static func _mon_tex(ci: CanvasItem, name: String, kind: String, pos: Vector2, r: float, s: float, t: float,
		breath: float, hurt: float, angry: bool) -> bool:
	var tex := Tex.art(name)
	if tex == null:
		return false
	var size := s * 2.5
	var mod := Color(1, 1, 1)
	if angry:
		var k := 0.25 + 0.2 * sin(t * 8.0)
		mod = Color(1, 1.0 - k, 1.0 - k)
	ci.draw_set_transform(pos + Vector2(0, size * 0.5), 0.0, Vector2(1.0 - breath, 1.0 + breath))
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, -size, size, size), false, mod)
	if hurt > 0.0:
		var g := size * 1.1
		ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(-g * 0.5, -size * 0.5 - g * 0.5, g, g), false, Color(1, 1, 1, hurt * 0.7))
	var fa: Array = MON_FACE.get(kind, [Vector2.ZERO, 1.0])
	ci.draw_set_transform(pos + (fa[0] as Vector2) * r, 0.0, Vector2(1.0 - breath, 1.0 + breath))
	_mon_face(ci, s * float(fa[1]), kind, angry, hurt)
	ci.draw_set_transform(Vector2.ZERO)
	return true


## 몬스터 몸통 윤곽(반지름 1 기준). 종마다 실루엣이 달라야 색이 비슷해도 갈린다.
static func _mon_shape(kind: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		var p := Vector2(cos(a), sin(a))
		match kind:
			"dough", "boss":
				p *= 1.0 + 0.06 * sin(a * 5.0 + 1.0)   # 울퉁불퉁한 반죽
			"glutton":
				p *= Vector2(1.12, 0.92)                # 옆으로 퍼진 몸
			"frost":
				p *= Vector2(0.94, 1.0)
		if p.y > 0.62:
			p.y = 0.62 + (p.y - 0.62) * 0.35           # 바닥은 평평하게 — 칸에 앉아 있다
		pts.append(p)
	return pts


## 몬스터 얼굴 — 흰자 · 눈동자 · 반짝임 · 눈썹 · 입. 맞으면 질끈, 행동 직전이면 눈썹이 선다.
static func _mon_face(ci: CanvasItem, s: float, kind: String, angry: bool, hurt: float) -> void:
	var ey := -0.08 if kind == "ninja" else -0.12
	for d in [-1.0, 1.0]:
		var e := Vector2(d * 0.33, ey) * s
		if hurt > 0.3:
			ci.draw_polyline(PackedVector2Array([e + Vector2(-0.14, -0.08) * s, e + Vector2(0.1 * d, 0) * s,
					e + Vector2(-0.14, 0.08) * s]), P.LINE, s * 0.08, true)
			continue
		ci.draw_circle(e, s * 0.2, P.LINE)
		ci.draw_circle(e, s * 0.16, Color(1, 1, 1))
		ci.draw_circle(e + Vector2(-d * 0.03, 0.03) * s, s * 0.09, P.INK)
		ci.draw_circle(e + Vector2(-d * 0.03 - 0.03, -0.01) * s, s * 0.035, Color(1, 1, 1))
		var tilt := 0.16 if angry else 0.06
		ci.draw_line(e + Vector2(-d * 0.2, -0.26 - tilt) * s, e + Vector2(d * 0.17, -0.2) * s, P.LINE, s * 0.08, true)
	if kind == "glutton":
		ci.draw_circle(Vector2(0, 0.32) * s, s * 0.34, P.LINE)
		ci.draw_circle(Vector2(0, 0.32) * s, s * 0.28, Color8(120, 30, 60))
		ci.draw_circle(Vector2(0, 0.44) * s, s * 0.15, Color8(255, 110, 130))
		for d in [-1.0, 1.0]:
			ci.draw_rect(Rect2(Vector2(d * 0.13 - 0.06, 0.06) * s, Vector2(0.12, 0.1) * s), Color(1, 1, 1))
		return
	var mouth := PackedVector2Array()
	for k in 7:
		mouth.append(Vector2(lerpf(-0.26, 0.26, k / 6.0), 0.3 + (0.07 if k % 2 == 1 else 0.0)) * s)
	ci.draw_polyline(mouth, P.LINE, s * 0.08, true)


## 몬스터가 다음 턴에 노리는 칸 — 붉은 테두리가 맥동하고 무엇을 할지 작게 그린다.
static func target_mark(ci: CanvasItem, pos: Vector2, r: float, kind: String, t: float) -> void:
	var a := 0.55 + 0.4 * sin(t * 9.0)
	var rect := Rect2(pos - Vector2(r, r) * 1.08, Vector2(r, r) * 2.16)
	G2.panel(ci, rect, Color(1, 0.2, 0.25, 0.12 * a), Color(1, 0.25, 0.3, a), r * 0.12, r * 0.3)
	var ic := pos + Vector2(0.62, -0.62) * r
	if kind == "thief":
		G2.text_mid(ci, ic, "-1", r * 0.6, P.WARN, r * 0.12)
	elif kind == "frost":
		G2.panel(ci, Rect2(ic - Vector2(r, r) * 0.26, Vector2(r, r) * 0.52), D.ICE_C, P.LINE, 2.0, r * 0.12)
	elif kind == "ninja":
		ci.draw_circle(ic, r * 0.22, Color(0.3, 0.2, 0.4))
	elif kind == "glutton":
		ci.draw_circle(ic, r * 0.22, P.INK)
		ci.draw_circle(ic + Vector2(0, r * 0.06), r * 0.1, Color8(255, 110, 120))
	elif kind == "dough":
		G2.panel(ci, Rect2(ic - Vector2(r, r) * 0.26, Vector2(r, r) * 0.52), D.COOKIE[0], P.LINE, 2.0, r * 0.1)
	else:
		ci.draw_arc(ic, r * 0.2, 0, TAU, 10, P.LINE, r * 0.14, true)
		ci.draw_arc(ic, r * 0.2, 0, TAU, 10, D.CHAIN_C, r * 0.07, true)


static func star(ci: CanvasItem, pos: Vector2, r: float, on: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + TAU * k / 10.0
		pts.append(pos + Vector2(cos(a), sin(a)) * r * (1.0 if k % 2 == 0 else 0.45))
	G2.fill_fan(ci, pts, P.GOLD if on else Color(0, 0, 0, 0.25), pos)
	G2.stroke(ci, pts, P.LINE if on else Color(1, 1, 1, 0.5), maxf(2.0, r * 0.1))


## 미션 아이콘 — 판 위 그림을 작게.
static func goal_icon(ci: CanvasItem, pos: Vector2, r: float, g: Dictionary, t: float) -> void:
	match g.type:
		"collect":
			jelly(ci, pos, r * 0.8, g.color, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)
		"sugar":
			sugar(ci, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2), 2)
		"box":
			box(ci, pos, r * 0.8, 2, 0.0)
		"choco":
			choco(ci, pos, r * 0.8, t)
		"ice":
			jelly(ci, pos, r * 0.7, 4, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)
			ice(ci, pos, r * 0.8, 1)
		"chain":
			jelly(ci, pos, r * 0.7, 0, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)
			chain(ci, pos, r * 0.7)
		"fruit":
			fruit(ci, pos, r * 0.9, t)
		"monster":
			monster(ci, pos, r * 0.8, g.get("kind", "dough"), 1.0, t, 0.0, false)
		"capsule":
			capsule(ci, pos, r * 0.8, t)
		"lock":
			lock(ci, pos, r * 0.8, 0, 8, 0.0)
		"web":
			jelly(ci, pos, r * 0.7, 2, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t)
			web(ci, pos, r * 0.8, 2)
		"mole":
			mole(ci, pos, r * 0.8, 3, t, 0.0)
		"fire":
			campfire(ci, pos, r * 0.8, 2, t)
		"paint":
			paint(ci, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2))
		"jar":
			jar(ci, pos, r * 0.8, 0, 3, 6)
		"cloud":
			cloud(ci, pos, r * 0.8, t)
		_:
			star(ci, pos, r * 0.9, true)

# ==================== 장치 (묶음 A) ====================

## 벨트 — 바닥에 갈매기 무늬. 흐르는 방향으로 무늬가 움직여 "움직인다"가 읽힌다.
static func belt_tex_ok() -> bool:
	return Tex.art("fl_belt") != null


## 벨트 고리 하나를 이어진 띠로 — 칸 중심을 이은 닫힌 고리를 둥글게 깎고(Chaikin 두 번), 띠를 따라
## AI 그림의 결(가로 골)을 휘어 붙인다. 골은 흐르는 방향으로 움직이고, 양옆 레일과 금색 화살표는 코드.
## 그림의 위아래 레일은 잘라 내고 쓴다(띠의 레일은 길이 방향이라 그림의 가로 레일과 맞지 않는다).
const BELT_V := Vector2(0.06, 0.06 + 0.1172 * 7)   ## 그림에서 골 일곱 개 높이 — 이음매 없이 되풀이되는 구간
static func belt_loop(ci: CanvasItem, cells: PackedVector2Array, cs: float, t: float) -> void:
	var tex := Tex.art("fl_belt")
	# 꺾이는 칸은 반지름 반 칸짜리 원호로 돈다 — 반지름이 띠 폭의 반보다 작으면 안쪽 레일이 접혀 가시가 생긴다
	var pts := PackedVector2Array()
	var m := cells.size()
	for i in m:
		var p := cells[i]
		var din := (p - cells[(i - 1 + m) % m]).normalized()
		var dout := (cells[(i + 1) % m] - p).normalized()
		if din.dot(dout) > 0.99:
			pts.append(p)
			continue
		var h := cs * 0.5
		var c := p - din * h + dout * h
		var v0 := -dout * h
		var v1 := din * h
		var a0 := v0.angle()
		var da := wrapf(v1.angle() - a0, -PI, PI)
		for j in 7:
			pts.append(c + Vector2.from_angle(a0 + da * j / 6.0) * h)
	var n := pts.size()
	var cum := PackedFloat32Array([0.0])
	for i in n:
		cum.append(cum[i] + pts[i].distance_to(pts[(i + 1) % n]))
	var total := cum[n]
	var hw := cs * 0.43
	var period := cs * 0.75
	var flow := t * cs * 0.45   # 턴마다 한 칸 가는 장치라 느리게 — 흐름만 보이면 된다
	# 자를 위치: 일정 간격 + 무늬가 되풀이되는 경계(경계를 넘는 삼각형은 uv 가 거꾸로 감긴다)
	var cuts := []
	var stp := cs * 0.08
	var k := 0.0
	while k < total:
		cuts.append(k)
		k += stp
	var off := fposmod(-flow, period)
	k = off
	while k < total:
		cuts.append(k)
		k += period
	cuts.append(total)
	cuts.sort()
	var at := func(sv: float) -> Array:
		var j := cum.bsearch(sv, true) - 1
		j = clampi(j, 0, n - 1)
		var a := pts[j]
		var b := pts[(j + 1) % n]
		var seg := maxf(0.001, cum[j + 1] - cum[j])
		var tg := (b - a) / seg
		return [a + tg * (sv - cum[j]), Vector2(-tg.y, tg.x)]
	var idx := PackedInt32Array()
	var vp := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var outer_l := PackedVector2Array()
	var outer_r := PackedVector2Array()
	for c in range(cuts.size() - 1):
		var s0: float = cuts[c]
		var s1: float = cuts[c + 1]
		if s1 - s0 < 0.01:
			continue
		var p0: Array = at.call(s0)
		var p1: Array = at.call(s1 - 0.001)
		var v0 := fposmod(s0 + flow, period) / period
		if v0 > 0.999:
			v0 = 0.0
		var v1 := v0 + (s1 - s0) / period
		var vv0 := lerpf(BELT_V.x, BELT_V.y, v0)
		var vv1 := lerpf(BELT_V.x, BELT_V.y, minf(v1, 1.0))
		var base := vp.size()
		vp.append_array([p0[0] + p0[1] * hw, p0[0] - p0[1] * hw, p1[0] - p1[1] * hw, p1[0] + p1[1] * hw])
		uv.append_array([Vector2(0.03, vv0), Vector2(0.97, vv0), Vector2(0.97, vv1), Vector2(0.03, vv1)])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		outer_l.append(p0[0] + p0[1] * hw)
		outer_r.append(p0[0] - p0[1] * hw)
	col.resize(vp.size())
	col.fill(Color(0.95, 0.93, 1.0))
	# 띠 바닥(외곽선) → 무늬 → 양옆 레일
	var mid := PackedVector2Array(pts)
	mid.append(pts[0])
	ci.draw_polyline(mid, P.LINE, hw * 2.0 + cs * 0.08, true)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, vp, col, uv,
			PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
	for side in [outer_l, outer_r]:
		var rail: PackedVector2Array = side.duplicate()
		rail.append(side[0])
		ci.draw_polyline(rail, P.LINE, cs * 0.09, true)
		ci.draw_polyline(rail, Color8(205, 210, 228), cs * 0.05, true)
	# 금색 화살표 — 한 칸에 하나, 흐르는 방향으로
	var s := fposmod(flow * 1.0, cs)
	while s < total:
		var p: Array = at.call(s)
		var tg := Vector2(p[1].y, -p[1].x)
		var tip: Vector2 = p[0] + tg * cs * 0.12
		var chev := PackedVector2Array([tip - tg * cs * 0.16 + p[1] * cs * 0.2, tip, tip - tg * cs * 0.16 - p[1] * cs * 0.2])
		ci.draw_polyline(chev, P.a(P.LINE, 0.6), cs * 0.1, true)
		ci.draw_polyline(chev, Color(1, 0.85, 0.35, 0.95), cs * 0.06, true)
		s += cs


static func belt(ci: CanvasItem, rect: Rect2, dir: int, t: float) -> void:
	var d: Vector2 = [Vector2.ZERO, Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][dir]
	# 그림의 줄무늬는 가로 — 위아래로 흐르는 벨트다. 흐르는 방향(d)으로 돌린다
	if not _tile(ci, "fl_belt", rect, d.angle() - PI * 0.5, Color(0.92, 0.9, 1.0, 0.85)):
		G2.panel(ci, rect.grow(-3), Color8(90, 100, 130, 150), Color(), 0.0, rect.size.x * 0.12)
	var side := Vector2(-d.y, d.x)
	var c := rect.get_center()
	var s := rect.size.x
	for k in 2:
		var o := fposmod(t * 0.6 + k * 0.5, 1.0) - 0.5
		var tip := c + d * s * (o * 0.8 + 0.12)
		var chev := PackedVector2Array([tip - d * s * 0.16 + side * s * 0.2, tip, tip - d * s * 0.16 - side * s * 0.2])
		ci.draw_polyline(chev, P.a(P.LINE, 0.55), s * 0.1, true)
		ci.draw_polyline(chev, Color(1, 0.85, 0.35, 0.9), s * 0.06, true)


## 포탈 — 입구는 칸 아래쪽, 출구는 칸 위쪽에 같은 색 고리. 짝마다 색이 다르다.
static func portal_mark(ci: CanvasItem, rect: Rect2, k: int, entry: bool, t: float) -> void:
	var c: Color = P.RAINBOW[(k * 2 + 4) % 6]
	var y := rect.end.y - rect.size.y * 0.08 if entry else rect.position.y + rect.size.y * 0.08
	var p := Vector2(rect.get_center().x, y)
	var tex := Tex.art("fl_portal")
	if tex != null:
		# 입구는 빨려 들어가는 쪽, 출구는 뿜어 나오는 쪽으로 돈다
		var w := rect.size.x * 0.95
		# 돌린 뒤 세로로 눌러 바닥에 누운 고리로 — 순서가 바뀌면 찌그러진 채로 돈다
		ci.draw_set_transform_matrix(Transform2D(fposmod(t * (2.0 if entry else -2.0), TAU), Vector2.ONE, 0.0, Vector2.ZERO)
				.scaled(Vector2(1.0, 0.32)).translated(p))
		ci.draw_texture_rect(tex, Rect2(-w * 0.5, -w * 0.5, w, w), false, c.lightened(0.2))
		ci.draw_texture_rect(tex, Rect2(-w * 0.4, -w * 0.4, w * 0.8, w * 0.8), false, Color(1, 1, 1, 0.6))
		ci.draw_set_transform(Vector2.ZERO)
		return
	var rx := rect.size.x * 0.4
	var pts := G2.ellipse_pts(p, rx, rx * 0.22, 20)
	G2.stroke(ci, pts, P.a(c, 0.9), rect.size.x * 0.07)
	var a := fposmod(t * (2.0 if entry else -2.0), TAU)
	ci.draw_circle(p + Vector2(cos(a) * rx, sin(a) * rx * 0.22), rect.size.x * 0.05, Color(1, 1, 1, 0.9))


## 톱니 — 이빨 여덟 개가 방향대로 천천히 돈다. 가운데 화살표가 지금 방향.
static func gear(ci: CanvasItem, pos: Vector2, r: float, dir: int, t: float, hurt: float) -> void:
	var rot := t * 0.8 * dir + hurt * dir
	if _tex(ci, "ob_gear", pos, r * 2.15, rot):
		_gear_arrow(ci, pos, r, dir)
		return
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0 + rot
		var tooth := 1.0 if (k / 2) % 2 == 0 else 0.78
		pts.append(pos + Vector2(cos(a), sin(a)) * r * tooth)
	G2.fill_fan(ci, pts, Color8(110, 120, 140), pos)
	G2.stroke(ci, pts, P.LINE, r * 0.08)
	ci.draw_circle(pos, r * 0.5, Color8(170, 180, 200))
	_gear_arrow(ci, pos, r, dir)


## 톱니가 도는 방향 — 눌러서 바꾸는 장치라 지금 방향이 늘 보여야 한다.
static func _gear_arrow(ci: CanvasItem, pos: Vector2, r: float, dir: int) -> void:
	var a0 := -PI * 0.5
	var a1 := a0 + PI * 1.2 * dir
	ci.draw_arc(pos, r * 0.3, minf(a0, a1), maxf(a0, a1), 14, P.INK, r * 0.1, true)
	var tip := pos + Vector2(cos(a1), sin(a1)) * r * 0.3
	var tg := Vector2(-sin(a1), cos(a1)) * dir
	ci.draw_colored_polygon(PackedVector2Array([tip + tg * r * 0.18, tip + (tip - pos).normalized() * r * 0.12,
			tip - (tip - pos).normalized() * r * 0.12]), P.INK)


## 바람개비 — 네 날개. 건드려지면(armed) 빨리 돈다.
static func wind(ci: CanvasItem, pos: Vector2, r: float, t: float, armed: bool) -> void:
	var rot := t * (9.0 if armed else 1.2)
	if _tex(ci, "ob_wind", pos, r * 2.3, rot):
		return
	for k in 4:
		var a := rot + PI * 0.5 * k
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var blade := PackedVector2Array([pos, pos + d * r * 0.98, pos + d * r * 0.55 + n * r * 0.5])
		G2.fill_fan(ci, G2.scaled(blade, 1.0), P.LINE, pos + d * r * 0.45 + n * r * 0.15)
		G2.fill_fan(ci, blade, P.RAINBOW[k + 1], pos + d * r * 0.4 + n * r * 0.12)
		# 접힌 면 — 바깥 끝 쪽 삼각형을 진하게 해서 종이가 접힌 것처럼
		var fold := PackedVector2Array([pos + d * r * 0.3, pos + d * r * 0.98, pos + d * r * 0.55 + n * r * 0.5])
		G2.fill_fan(ci, fold, P.RAINBOW[k + 1].darkened(0.22), pos + d * r * 0.62 + n * r * 0.18)
		G2.stroke(ci, blade, P.LINE, r * 0.07)
	ci.draw_circle(pos, r * 0.18, P.LINE)
	ci.draw_circle(pos, r * 0.13, Color8(255, 220, 110))
	ci.draw_circle(pos - Vector2(r, r) * 0.04, r * 0.04, Color(1, 1, 1))


## 푸시 상자 — 쇠 상자에 나아갈 방향 화살표.
static func push(ci: CanvasItem, pos: Vector2, r: float, d: Vector2i) -> void:
	var rect := Rect2(pos - Vector2(r, r), Vector2(r, r) * 2)
	if not _tex(ci, "ob_push", pos, r * 2.45):
		G2.panel(ci, rect, Color8(150, 160, 175), P.LINE, r * 0.1, r * 0.2)
		for k in [-1, 1]:
			ci.draw_circle(pos + Vector2(k * 0.7, -0.7) * r, r * 0.08, P.LINE)
			ci.draw_circle(pos + Vector2(k * 0.7, 0.7) * r, r * 0.08, P.LINE)
	var v := Vector2(d)
	# 나아갈 방향 — 그림 위에 얹으므로 외곽선을 먼저
	var n0 := Vector2(-v.y, v.x)
	ci.draw_colored_polygon(PackedVector2Array([pos + v * r * 0.7, pos - v * r * 0.15 + n0 * r * 0.55,
			pos - v * r * 0.15 - n0 * r * 0.55]), P.LINE)
	ci.draw_line(pos - v * r * 0.62, pos - v * r * 0.05, P.LINE, r * 0.36)
	var n := Vector2(-v.y, v.x)
	ci.draw_colored_polygon(PackedVector2Array([pos + v * r * 0.6, pos - v * r * 0.1 + n * r * 0.45,
			pos - v * r * 0.1 - n * r * 0.45]), Color8(255, 210, 80))
	ci.draw_line(pos - v * r * 0.55, pos - v * r * 0.05, Color8(255, 210, 80), r * 0.25)

# ==================== 장치 (묶음 B) ====================

## 자기장 — 바닥에 푸른 막과 지그재그. 광선이 여기서 멈춘다.
static func field(ci: CanvasItem, rect: Rect2, t: float) -> void:
	var r := rect.grow(-2)
	if _tile(ci, "fl_field", rect, 0.0, Color(1, 1, 1, 0.7 + 0.1 * sin(t * 4.0))):
		return
	G2.panel(ci, r, P.a(D.FIELD_C, 0.28 + 0.08 * sin(t * 4.0)), P.a(D.FIELD_C, 0.9), 2.0, r.size.x * 0.15)
	for k in 2:
		var x0 := r.position.x + r.size.x * (0.3 + 0.4 * k)
		var pts := PackedVector2Array()
		for j in 6:
			pts.append(Vector2(x0 + (r.size.x * 0.08 if j % 2 == 0 else -r.size.x * 0.08), r.position.y + r.size.y * (0.12 + 0.15 * j)))
		ci.draw_polyline(pts, Color(1, 1, 1, 0.5), maxf(2.0, r.size.x * 0.04), true)


## 파이프 꺾임 — 두 입을 잇는 굵은 관. 광선이 이 모양대로 꺾인다.
static func pipe(ci: CanvasItem, rect: Rect2, kind: int, a: float = 1.0) -> void:
	# 그림은 왼쪽-아래를 잇는 꺾임(┐ = kind 1). 나머지는 돌려서 — ┌ -90° · ┘ +90° · └ 180°
	if a >= 1.0 and _tex(ci, "fl_pipe", rect.get_center(), rect.size.x * 1.0, [0.0, 0.0, -PI * 0.5, PI * 0.5, PI][kind]):
		return
	var c := rect.get_center()
	var sides: Array = Board.PIPE_SIDES[kind]
	for d in sides:
		var e: Vector2 = c + Vector2(d) * rect.size.x * 0.5
		ci.draw_line(c, e, P.a(P.LINE, a), rect.size.x * 0.34, true)
	for d in sides:
		var e: Vector2 = c + Vector2(d) * rect.size.x * 0.5
		ci.draw_line(c, e, P.a(D.PIPE_C, a), rect.size.x * 0.24, true)
	ci.draw_circle(c, rect.size.x * 0.17, P.a(P.LINE, a))
	ci.draw_circle(c, rect.size.x * 0.12, P.a(D.PIPE_C, a))


## 젤리 위에 한 번 더 — 바닥에만 그리면 젤리에 가려서 광선이 어디서 멈추고 꺾이는지 안 보인다.
static func field_top(ci: CanvasItem, rect: Rect2, t: float) -> void:
	var r := rect.grow(-2)
	G2.panel(ci, r, P.a(D.FIELD_C, 0.12), P.a(D.FIELD_C, 0.7 + 0.2 * sin(t * 4.0)), 3.0, r.size.x * 0.15)


## 캡슐 — 알약. 옆에서 터져도 끄떡없고 특수 효과에만 깨진다.
static func capsule(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var a := sin(t * 1.5) * 0.25
	if _tex(ci, "ob_capsule", pos, r * 2.4, a + 0.5):
		return
	var d := Vector2(cos(a), sin(a)) * r * 0.45
	ci.draw_line(pos - d, pos + d, P.LINE, r * 1.15, true)
	ci.draw_line(pos - d, pos, D.CAPSULE_C, r * 0.95, true)
	ci.draw_line(pos, pos + d, Color8(255, 255, 255), r * 0.95, true)
	ci.draw_circle(pos - d, r * 0.48, D.CAPSULE_C)
	ci.draw_circle(pos + d, r * 0.48, Color8(255, 255, 255))
	ci.draw_circle(pos - d * 1.1 + Vector2(-0.1, -0.2) * r, r * 0.12, Color(1, 1, 1, 0.8))


## 레이저 포대 — 몸통 + 쏘는 쪽 포신 + 충전 칸 셋.
static func laser(ci: CanvasItem, pos: Vector2, r: float, d: Vector2i, n: int, t: float, hurt: float) -> void:
	var v := Vector2(d)
	# 그림은 오른쪽을 본다 — 쏘는 방향으로 돌린다
	if not _tex(ci, "ob_laser", pos, r * 2.6, v.angle()):
		ci.draw_line(pos, pos + v * r * 1.0, P.LINE, r * 0.5, true)
		ci.draw_line(pos, pos + v * r * 0.95, Color8(200, 205, 220), r * 0.36, true)
		ci.draw_circle(pos, r * 0.78, P.LINE)
		ci.draw_circle(pos, r * 0.7, Color8(90, 95, 120))
	var n2 := Vector2(-v.y, v.x)
	for k in Board.LASER_FULL:
		var on := k < n
		var p := pos - v * r * 0.25 + n2 * r * (k - 1) * 0.32
		ci.draw_circle(p, r * 0.15, P.LINE)
		ci.draw_circle(p, r * 0.11, Color8(255, 90, 120) if on else Color8(60, 60, 80))
	if n >= Board.LASER_FULL:
		ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(pos + v * r - Vector2(r, r) * 0.6, Vector2(r, r) * 1.2),
				false, Color(1, 0.4, 0.5, 0.6 + 0.3 * sin(t * 12.0)))
	if hurt > 0.0:
		ci.draw_circle(pos, r * 0.7, Color(1, 1, 1, hurt * 0.5))


## 드릴 로켓 — 자기 색 띠. 그 색이 옆에서 맞으면 쏘는 쪽으로 날아간다.
static func rocket(ci: CanvasItem, pos: Vector2, r: float, d: Vector2i, c: int, armed: bool, t: float) -> void:
	var v := Vector2(d)
	var n := Vector2(-v.y, v.x)
	if armed:
		pos += Vector2(sin(t * 50.0), cos(t * 47.0)) * r * 0.05
		ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(pos - v * r * 0.9 - Vector2(r, r) * 0.45, Vector2(r, r) * 0.9),
				false, Color(1, 0.6, 0.2, 0.8))
	# 그림은 위를 본다 — 날아갈 방향으로 돌리고, 반응하는 색은 몸통 가운데 동그라미로 얹는다
	if _tex(ci, "ob_rocket", pos, r * 2.5, v.angle() + PI * 0.5):
		ci.draw_circle(pos, r * 0.3, P.LINE)
		ci.draw_circle(pos, r * 0.23, P.jelly(c))
		ci.draw_circle(pos - Vector2(r, r) * 0.07, r * 0.07, Color(1, 1, 1, 0.85))
		return
	var tip := pos + v * r * 1.0
	var back := pos - v * r * 0.62
	# 지느러미 — 몸통 색이 아니라 그 로켓의 색이라 무슨 색에 반응하는지 두 군데서 읽힌다
	for s in [-1.0, 1.0]:
		var fin := PackedVector2Array([back + n * s * r * 0.3, back + n * s * r * 0.8 - v * r * 0.3,
				back + v * r * 0.35 + n * s * r * 0.35])
		G2.fill_fan(ci, fin, P.LINE, back + n * s * r * 0.45)
		G2.fill_fan(ci, G2.scaled(fin, 0.8, (back + n * s * r * 0.45) * 0.2), P.jelly(c), back + n * s * r * 0.45)
	var body := PackedVector2Array([pos + v * r * 0.35 + n * r * 0.42, back + n * r * 0.42,
			back - n * r * 0.42, pos + v * r * 0.35 - n * r * 0.42])
	G2.fill_fan(ci, body, Color8(232, 232, 242), pos)
	G2.fill_fan(ci, PackedVector2Array([pos + v * r * 0.35 + n * r * 0.42, back + n * r * 0.42,
			back + n * r * 0.1, pos + v * r * 0.35 + n * r * 0.1]), Color8(200, 200, 218), pos + n * r * 0.26)
	G2.stroke(ci, body, P.LINE, r * 0.08)
	# 드릴 코 — 결이 있는 원뿔
	var cone := PackedVector2Array([tip, pos + v * r * 0.35 + n * r * 0.42, pos + v * r * 0.35 - n * r * 0.42])
	G2.fill_fan(ci, cone, Color8(255, 205, 90), pos + v * r * 0.55)
	G2.stroke(ci, cone, P.LINE, r * 0.08)
	for k in 3:
		var q := 0.45 + k * 0.17 + fposmod(t * (2.0 if armed else 0.4), 0.17)
		var w := 0.42 * (1.0 - (q - 0.35) / 0.65)
		ci.draw_line(pos + v * r * q + n * r * w, pos + v * r * (q + 0.08) - n * r * w, Color8(200, 140, 40), r * 0.05, true)
	ci.draw_line(pos + n * r * 0.42, pos - n * r * 0.42, P.LINE, r * 0.34)
	ci.draw_line(pos + n * r * 0.38, pos - n * r * 0.38, P.jelly(c), r * 0.24)
	ci.draw_circle(pos - v * r * 0.25, r * 0.13, P.LINE)
	ci.draw_circle(pos - v * r * 0.25, r * 0.09, Color8(150, 210, 255))


## 색 설탕막 — 그 색 젤리로만 벗겨진다. 바닥을 그 색으로 칠하고 귀퉁이에 같은 색 작은 젤리를 찍어
## "무슨 색으로 깨야 하나"가 칸 위 젤리에 가려도 읽히게 한다.
static func csugar(ci: CanvasItem, rect: Rect2, c: int) -> void:
	var col := P.jelly(c)
	var r := rect.grow(-3)
	# 색설탕 무늬(fl_csugar)를 그 젤리 색으로 물들여 깐다 — 무슨 색 설탕막인지가 게임 정보다
	var st := Tex.art("fl_csugar")
	if st != null:
		ci.draw_texture_rect(st, r, false, col.lightened(0.25))
	else:
		G2.panel(ci, r, P.a(col, 0.45), P.a(col.lightened(0.45), 0.95), 3.0, r.size.x * 0.18)
	for k in 2:
		var y := r.position.y + r.size.y * (0.82 - 0.12 * k)
		ci.draw_line(Vector2(r.position.x + r.size.x * 0.2, y), Vector2(r.end.x - r.size.x * 0.2, y),
				Color(1, 1, 1, 0.6), maxf(2.0, r.size.x * 0.05))
	var s := r.size.x * 0.16
	jelly(ci, r.position + Vector2(s * 1.1, s * 1.1), s, c, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE,
			0.0, 0.0, 0.0)


## 구름 — 칸을 덮는다. 밑에 무엇이 있는지 안 보인다.
static func cloud(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	if _tex(ci, "ov_cloud", pos + Vector2(sin(t * 1.3), 0) * r * 0.04, r * 2.4):
		return
	var puffs := [Vector2(-0.45, 0.15), Vector2(0.0, -0.15), Vector2(0.45, 0.12), Vector2(-0.15, 0.4), Vector2(0.25, 0.42)]
	for k in puffs.size():
		var p: Vector2 = pos + puffs[k] * r + Vector2(sin(t * 1.3 + k), 0) * r * 0.04
		ci.draw_circle(p, r * 0.52, Color8(180, 190, 215, 235))
	for k in puffs.size():
		var p: Vector2 = pos + puffs[k] * r + Vector2(sin(t * 1.3 + k), 0) * r * 0.04
		ci.draw_circle(p - Vector2(0, r * 0.04), r * 0.46, D.CLOUD_C)


## 유리 상자 — 젤리 위에 반짝이는 상자. 깨지면 안의 젤리가 그대로 나온다.
static func glass(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var rect := Rect2(pos - Vector2(r, r) * 1.05, Vector2(r, r) * 2.1)
	G2.panel(ci, rect, Color(0.85, 0.95, 1.0, 0.2), P.LINE, r * 0.14, r * 0.2)
	G2.panel(ci, rect.grow(-r * 0.1), Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), r * 0.06, r * 0.14)
	# 왼쪽 위 모서리의 굵은 반사 — 유리로 읽히게 하는 건 결국 이 빛 한 줄이다
	ci.draw_polyline(PackedVector2Array([rect.position + Vector2(0.2, 0.75) * r, rect.position + Vector2(0.2, 0.2) * r,
			rect.position + Vector2(0.75, 0.2) * r]), Color(1, 1, 1, 0.95), r * 0.1, true)
	var k := fposmod(t * 0.4, 1.6) - 0.3
	ci.draw_line(rect.position + Vector2(rect.size.x * k, 0), rect.position + Vector2(rect.size.x * (k - 0.3), rect.size.y),
			Color(1, 1, 1, 0.4), r * 0.14)
	for d in [Vector2(0.62, -0.62), Vector2(-0.55, 0.6)]:
		var sp: Vector2 = pos + d * r
		var s := r * (0.1 + 0.03 * sin(t * 4.0 + d.x * 5.0))
		ci.draw_line(sp - Vector2(s, 0), sp + Vector2(s, 0), Color(1, 1, 1, 0.9), r * 0.04, true)
		ci.draw_line(sp - Vector2(0, s), sp + Vector2(0, s), Color(1, 1, 1, 0.9), r * 0.04, true)


## 주사위 젤리 — 귀퉁이에 주사위 눈. 턴마다 색이 바뀐다는 표시.
static func dice_mark(ci: CanvasItem, pos: Vector2, r: float) -> void:
	var c := pos + Vector2(0.6, -0.6) * r
	if _tex(ci, "ov_dice", c, r * 0.8):
		return
	var box := Rect2(c - Vector2(r, r) * 0.32, Vector2(r, r) * 0.64)
	G2.panel(ci, box.grow(r * 0.05), P.LINE, Color(), 0.0, r * 0.14)
	G2.panel(ci, box, Color8(225, 225, 235), Color(), 0.0, r * 0.12)
	G2.panel(ci, Rect2(box.position, box.size * Vector2(1, 0.82)), Color(1, 1, 1), Color(), 0.0, r * 0.12)
	for d in [Vector2(-0.15, -0.15), Vector2(0.15, 0.15), Vector2(0, 0), Vector2(0.15, -0.15), Vector2(-0.15, 0.15)]:
		ci.draw_circle(c + d * r - Vector2(0, r * 0.03), r * 0.055, P.INK)


## 숫자 자물쇠 — 맹꽁이 자물쇠에 그 색 젤리와 남은 수.
static func lock(ci: CanvasItem, pos: Vector2, r: float, c: int, n: int, hurt: float) -> void:
	pos += Vector2(sin(hurt * 40.0), 0) * hurt * r * 0.1
	if _tex(ci, "ob_lock", pos, r * 2.45):
		# 금색 동그라미 자리에 그 색 젤리, 오른쪽 아래에 남은 수
		jelly(ci, pos + Vector2(0, 0.28) * r, r * 0.34, c, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, 0.0)
		G2.text_mid(ci, pos + Vector2(0.62, 0.7) * r, str(n), r * 0.8, Color(1, 1, 1), r * 0.2)
		return
	ci.draw_arc(pos - Vector2(0, r * 0.35), r * 0.45, PI, TAU, 16, P.LINE, r * 0.26, true)
	ci.draw_arc(pos - Vector2(0, r * 0.35), r * 0.45, PI, TAU, 16, Color8(200, 205, 215), r * 0.15, true)
	var body := Rect2(pos + Vector2(-0.8, -0.35) * r, Vector2(1.6, 1.3) * r)
	G2.panel(ci, body, D.LOCK_C, P.LINE, r * 0.1, r * 0.25)
	jelly(ci, pos + Vector2(-0.35, 0.3) * r, r * 0.32, c, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, 0.0)
	G2.text_mid(ci, pos + Vector2(0.3, 0.32) * r, str(n), r * 0.7, Color(1, 1, 1), r * 0.14)


## 선물 상자 — 리본 두른 상자. 열면 무엇이 나올지 모른다.
static func gift(ci: CanvasItem, pos: Vector2, r: float, t: float, hurt: float) -> void:
	pos.y += sin(t * 3.0) * r * 0.04
	pos += Vector2(sin(hurt * 40.0), 0) * hurt * r * 0.1
	if _tex(ci, "ob_gift", pos, r * 2.45):
		return
	var body := Rect2(pos + Vector2(-0.85, -0.45) * r, Vector2(1.7, 1.35) * r)
	G2.panel(ci, body, D.GIFT_C, P.LINE, r * 0.1, r * 0.12)
	ci.draw_rect(Rect2(pos + Vector2(-0.95, -0.6) * r, Vector2(1.9, 0.38) * r), D.GIFT_C.lightened(0.2))
	ci.draw_rect(Rect2(pos + Vector2(-0.95, -0.6) * r, Vector2(1.9, 0.38) * r), P.LINE, false, r * 0.08)
	ci.draw_line(pos + Vector2(0, -0.6) * r, pos + Vector2(0, 0.9) * r, D.LOCK_C, r * 0.26)
	for s in [-1.0, 1.0]:
		ci.draw_circle(pos + Vector2(s * 0.22, -0.78) * r, r * 0.2, D.LOCK_C)
	G2.text_mid(ci, pos + Vector2(0, 0.25) * r, "?", r * 0.8, Color(1, 1, 1), r * 0.12)


## 증기 기계 — 굴뚝 달린 통과 남은 턴. 뿜기 직전엔 김이 새어 나온다.
static func steam(ci: CanvasItem, pos: Vector2, r: float, t: float, cd: int) -> void:
	var body := Rect2(pos + Vector2(-0.8, -0.4) * r, Vector2(1.6, 1.3) * r)
	if not _tex(ci, "ob_steam", pos, r * 2.6):
		G2.panel(ci, body, Color8(150, 140, 170), P.LINE, r * 0.1, r * 0.3)
		ci.draw_rect(Rect2(pos + Vector2(0.15, -0.95) * r, Vector2(0.4, 0.6) * r), Color8(120, 110, 140))
		ci.draw_rect(Rect2(pos + Vector2(0.15, -0.95) * r, Vector2(0.4, 0.6) * r), P.LINE, false, r * 0.08)
	ci.draw_circle(pos + Vector2(-0.3, 0.2) * r, r * 0.3, P.LINE)
	ci.draw_circle(pos + Vector2(-0.3, 0.2) * r, r * 0.25, Color8(255, 220, 120))
	G2.text_mid(ci, pos + Vector2(-0.3, 0.22) * r, str(cd), r * 0.4, P.INK)
	if cd <= 1:
		for k in 3:
			var p := pos + Vector2(0.35 + sin(t * 3.0 + k) * 0.1, -1.05 - k * 0.22 - fposmod(t, 0.5)) * r
			ci.draw_circle(p, r * (0.12 + k * 0.04), Color(1, 1, 1, 0.6))


## 분신 — 그림자가 만든 가짜. 어둡게 비친 모양이라 진짜 젤리가 아니라는 게 읽힌다.
static func decoy(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	# 그림자가 만든 분신 — 그림자 그림을 반투명 보랏빛으로, 좌우로 일렁이게. 한 대 맞으면 사라진다는 게
	# "흐릿한 것" 으로 읽힌다
	var tex := Tex.art("mon_ninja")
	if tex != null:
		var a := 0.5 + 0.15 * sin(t * 4.0)
		var s := r * 2.2
		for k in 2:
			var off := Vector2(sin(t * 3.0 + k * PI) * r * 0.08, 0)
			ci.draw_texture_rect(tex, Rect2(pos + off - Vector2(s * 0.5, s * 0.55), Vector2(s, s)), false,
					Color(0.75, 0.6, 1.0, a * (1.0 if k == 0 else 0.45)))
		for d in [-1.0, 1.0]:
			var e: Vector2 = pos + Vector2(d * 0.3, -0.12) * r
			ci.draw_circle(e, r * 0.11, Color(1, 0.9, 0.45, 0.9))
		return
	var a := 0.55 + 0.15 * sin(t * 4.0)
	ci.draw_circle(pos, r * 0.92, Color(0.25, 0.15, 0.35, a))
	ci.draw_circle(pos, r * 0.75, Color(0.4, 0.3, 0.55, a))
	for s in [-1.0, 1.0]:
		ci.draw_circle(pos + Vector2(s * 0.3, -0.1) * r, r * 0.1, Color(1, 0.9, 0.4, 0.9))

# ==================== 장치 (묶음 D) ====================

## 거미줄 — 바퀴살과 고리. 두 겹이면 진하고 고리가 하나 더.
static func web(ci: CanvasItem, pos: Vector2, r: float, layers: int) -> void:
	# 흰 줄만 그리면 밝은 젤리(레몬 · 소다) 위에서 안 보인다 — 진한 그림자 선을 먼저 깐다
	var a := 0.75 if layers == 1 else 1.0
	var c := Color(D.WEB_C.r, D.WEB_C.g, D.WEB_C.b, a)
	var sh := P.a(P.LINE, 0.45 * a)
	var w := maxf(1.5, r * 0.05)
	var n := 8
	var spokes := []
	for k in n:
		var ang := TAU * k / n + 0.2
		spokes.append(Vector2(cos(ang), sin(ang)))
	for s_ in spokes:
		ci.draw_line(pos, pos + s_ * r * 1.1, sh, w * 2.4, true)
		ci.draw_line(pos, pos + s_ * r * 1.1, c, w, true)
	# 그물 고리 — 바퀴살 사이를 안쪽으로 살짝 처지게 잇는다(둥근 원이면 과녁처럼 보인다)
	var rings := [0.34, 0.64, 0.94] if layers == 1 else [0.26, 0.48, 0.7, 0.92]
	for rr in rings:
		var pts := PackedVector2Array()
		for k in n + 1:
			var p0: Vector2 = spokes[k % n] * r * rr
			var p1: Vector2 = spokes[(k + 1) % n] * r * rr
			pts.append(pos + p0)
			if k < n:
				pts.append(pos + (p0 + p1) * 0.5 * 0.88)
		ci.draw_polyline(pts, sh, w * 2.2, true)
		ci.draw_polyline(pts, c, w, true)
	# 이슬 — 교차점 몇 곳에 반짝이는 점
	for k in [1, 4, 6]:
		var q: Vector2 = pos + spokes[k] * r * rings[1]
		ci.draw_circle(q, r * 0.07, sh)
		ci.draw_circle(q, r * 0.05, Color(1, 1, 1, a))


## 강철 젤리 — 젤리 둘레에 쇠테와 리벳. 움직이지 않는다는 것이 읽힌다.
static func steel_mark(ci: CanvasItem, pos: Vector2, r: float) -> void:
	ci.draw_arc(pos, r * 0.98, 0, TAU, 28, P.LINE, r * 0.26, true)
	ci.draw_arc(pos, r * 0.98, 0, TAU, 28, D.STEEL_C.darkened(0.15), r * 0.17, true)
	ci.draw_arc(pos, r * 0.98, PI * 1.05, PI * 1.7, 12, D.STEEL_C.lightened(0.35), r * 0.08, true)
	for k in 4:
		var ang := PI * 0.25 + PI * 0.5 * k
		var p := pos + Vector2(cos(ang), sin(ang)) * r * 0.98
		ci.draw_circle(p, r * 0.12, P.LINE)
		ci.draw_circle(p, r * 0.085, Color8(205, 212, 225))
		ci.draw_circle(p - Vector2(r, r) * 0.025, r * 0.03, Color(1, 1, 1))


## 물감 — 칠한 칸 바닥.
static func paint(ci: CanvasItem, rect: Rect2) -> void:
	if _tile(ci, "fl_paint", rect, 0.0, Color(1, 1, 1, 0.85)):
		return
	G2.panel(ci, rect.grow(-2), P.a(D.PAINT_C, 0.55), P.a(D.PAINT_C.lightened(0.4), 0.9), 2.0, rect.size.x * 0.18)


## 솟는 줄 — 세로줄 바닥에 위쪽 화살표 무늬.
## 솟는 줄 — 그 세로줄 **전체**를 금색 띠로 칠하고, 띠 양 가장자리에 위로 흐르는 화살표를 그린다.
## 칸마다 바닥에 흐린 꺾쇠만 그리던 시절에는 젤리에 다 가려서 어느 줄이 도는지 안 보였다.
## col = 그 줄이 차지하는 판 위 사각형(맨 위 칸 ~ 맨 아래 칸).
static func rise_col(ci: CanvasItem, col: Rect2, t: float) -> void:
	var s := col.size.x
	G2.panel(ci, col.grow(-s * 0.03), Color(1, 0.82, 0.3, 0.3), Color(1, 0.85, 0.35, 0.85), s * 0.05, s * 0.2)
	var gold := Color(1, 0.93, 0.55, 0.95)
	var n := int(col.size.y / (s * 0.5))
	for side in [0.1, 0.9]:
		for k in n:
			# 위로 흘러간다 — 판이 턴마다 위로 한 칸 도는 방향 그대로
			var y := col.end.y - fposmod(k * s * 0.5 + t * s * 0.6, col.size.y)
			var x: float = col.position.x + s * side
			ci.draw_polyline(PackedVector2Array([Vector2(x - s * 0.07, y + s * 0.06), Vector2(x, y - s * 0.03),
					Vector2(x + s * 0.07, y + s * 0.06)]), gold, s * 0.035, true)


## 솟는 줄 표지 — 판 위쪽 바깥에 뜨는 ▲ 동그라미. 판 안 띠가 젤리에 가려도 이건 안 가린다.
static func rise_badge(ci: CanvasItem, at: Vector2, s: float, t: float) -> void:
	at.y -= absf(sin(t * 3.0)) * s * 0.08
	ci.draw_circle(at, s * 0.27, P.LINE)
	ci.draw_circle(at, s * 0.22, Color8(255, 205, 80))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -0.14) * s, at + Vector2(0.12, 0.08) * s,
			at + Vector2(-0.12, 0.08) * s]), P.LINE)


## 끈끈이 식물 — 초록 봉오리. 건드리면 터지며 거미줄을 뿌린다.
static func plant(ci: CanvasItem, pos: Vector2, r: float, t: float) -> void:
	var sway := sin(t * 2.0) * 0.1
	if _tex(ci, "ob_plant", pos, r * 2.5, sway * 0.6):
		return
	ci.draw_line(pos + Vector2(0, r * 0.9), pos + Vector2(sway * r, 0), Color8(70, 140, 60), r * 0.16, true)
	for s in [-1.0, 1.0]:
		var lc := pos + Vector2(s * 0.45, 0.55) * r
		G2.fill_fan(ci, G2.ellipse_pts(lc, r * 0.35, r * 0.15, 12), Color8(110, 190, 90), lc)
	var head := pos + Vector2(sway * r, -0.15 * r)
	ci.draw_circle(head, r * 0.6, P.LINE)
	ci.draw_circle(head, r * 0.53, Color8(150, 210, 90))
	for d in [Vector2(-0.25, -0.2), Vector2(0.2, 0.05), Vector2(-0.05, 0.25)]:
		ci.draw_circle(head + d * r, r * 0.09, Color8(230, 240, 120))


## 두더지 — 갈색 얼굴과 분홍 코, 남은 체력 점.
static func mole(ci: CanvasItem, pos: Vector2, r: float, hp: int, t: float, hurt: float) -> void:
	pos += Vector2(sin(hurt * 40.0), 0) * hurt * r * 0.12
	if _mon_tex(ci, "mon_mole", "mole", pos, r, r, t, 0.02 * sin(t * 2.0), hurt, false):
		for k in Board.MOLE_HP:
			var p := pos + Vector2((k - 1) * 0.32, 0.98) * r
			ci.draw_circle(p, r * 0.12, P.LINE)
			ci.draw_circle(p, r * 0.08, P.WARN if k < hp else Color8(90, 80, 100))
		return
	var bob := absf(sin(t * 2.0)) * -r * 0.06
	# 흙더미 — 판 위로 고개만 내민 모양이라 "옮겨 다닌다"가 읽힌다
	var dirt := pos + Vector2(0, 0.62) * r
	G2.fill_fan(ci, G2.ellipse_pts(dirt, r * 1.0, r * 0.36, 20), P.LINE, dirt)
	G2.fill_fan(ci, G2.ellipse_pts(dirt, r * 0.92, r * 0.29, 20), Color8(120, 82, 55), dirt)
	G2.fill_fan(ci, G2.ellipse_pts(dirt - Vector2(0, r * 0.06), r * 0.7, r * 0.16, 16), Color8(150, 105, 70), dirt)
	var c := pos + Vector2(0, -0.08 * r + bob)
	ci.draw_circle(c, r * 0.8, P.LINE)
	ci.draw_circle(c, r * 0.72, Color8(125, 85, 62))
	ci.draw_circle(c + Vector2(-0.06, -0.07) * r, r * 0.62, Color8(158, 112, 80))
	ci.draw_circle(c + Vector2(-0.3, -0.38) * r, r * 0.11, Color(1, 1, 1, 0.75))
	ci.draw_circle(c + Vector2(0, 0.24) * r, r * 0.34, Color8(222, 186, 150))
	for s in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(s * 0.28, -0.12) * r
		if hurt > 0.3:
			ci.draw_line(e - Vector2(0.1, 0) * r, e + Vector2(0.1, 0) * r, P.LINE, r * 0.08, true)
		else:
			ci.draw_circle(e, r * 0.12, P.LINE)
			ci.draw_circle(e + Vector2(-0.03, -0.03) * r, r * 0.04, Color(1, 1, 1))
		ci.draw_circle(c + Vector2(s * 0.45, 0.12) * r, r * 0.09, Color8(255, 140, 150, 160))
	ci.draw_circle(c + Vector2(0, 0.12) * r, r * 0.13, P.LINE)
	ci.draw_circle(c + Vector2(0, 0.11) * r, r * 0.09, Color8(255, 130, 150))
	# 흙 위에 걸친 앞발
	for s in [-1.0, 1.0]:
		var paw: Vector2 = pos + Vector2(s * 0.42, 0.5) * r
		ci.draw_circle(paw, r * 0.17, P.LINE)
		ci.draw_circle(paw, r * 0.12, Color8(230, 180, 160))
	for k in Board.MOLE_HP:
		var p := pos + Vector2((k - 1) * 0.32, 0.98) * r
		ci.draw_circle(p, r * 0.12, P.LINE)
		ci.draw_circle(p, r * 0.08, P.WARN if k < hp else Color8(90, 80, 100))


## 모닥불 — 장작과 불꽃. 남은 켜짐 턴만큼 불이 크고, 꺼지면 연기만.
static func campfire(ci: CanvasItem, pos: Vector2, r: float, lit: int, t: float) -> void:
	if Tex.art("ob_fire") != null:
		if lit > 0:
			var g := r * 3.0 * (1.0 + 0.05 * sin(t * 17.0))
			ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(pos - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 0.6, 0.2, 0.5))
			_tex(ci, "ob_fire_lit", pos, r * 2.45 * (1.0 + 0.03 * sin(t * 17.0)))
			var bp := pos + Vector2(0.72, -0.72) * r
			ci.draw_circle(bp, r * 0.27, P.LINE)
			ci.draw_circle(bp, r * 0.22, Color8(255, 150, 60))
			G2.text_mid(ci, bp, str(lit), r * 0.38, Color(1, 1, 1))
		else:
			_tex(ci, "ob_fire", pos, r * 2.45)
		return
	# 둥글게 놓인 돌
	for k in 7:
		var a := PI * (0.05 + 0.9 * k / 6.0)
		var p := pos + Vector2(cos(a) * 0.82, 0.55 + sin(a) * 0.28) * r
		ci.draw_circle(p, r * 0.2, P.LINE)
		ci.draw_circle(p, r * 0.15, Color8(150, 150, 165))
		ci.draw_circle(p - Vector2(0.05, 0.05) * r, r * 0.06, Color8(200, 200, 215))
	# 엇갈린 장작
	for s in [-1.0, 1.0]:
		var a := pos + Vector2(-0.7 * s, 0.68) * r
		var b := pos + Vector2(0.7 * s, 0.3) * r
		ci.draw_line(a, b, P.LINE, r * 0.3, true)
		ci.draw_line(a, b, Color8(130, 82, 50), r * 0.2, true)
		ci.draw_line(a - Vector2(0, r * 0.04), b - Vector2(0, r * 0.04), Color8(175, 115, 70), r * 0.06, true)
		ci.draw_circle(b, r * 0.1, Color8(220, 175, 120))
	if lit > 0:
		var k := 0.55 + 0.18 * lit
		var flick := 1.0 + 0.08 * sin(t * 17.0)
		ci.draw_texture_rect(Tex.fx("fx_glow"), Rect2(pos - Vector2(r, r * 1.2) * k * 1.4, Vector2(r, r * 1.2) * k * 2.8),
				false, Color(1, 0.6, 0.2, 0.55))
		var outer := PackedVector2Array([pos + Vector2(-0.48, 0.45) * r * k, pos + Vector2(-0.2, -0.5) * r * k,
				pos + Vector2(0, -1.15 * flick) * r * k, pos + Vector2(0.22, -0.45) * r * k, pos + Vector2(0.48, 0.45) * r * k])
		G2.fill_fan(ci, G2.scaled(outer, 1.12, pos * -0.12 + Vector2(0, 0.05) * r), P.LINE, pos + Vector2(0, 0.1) * r * k)
		G2.fill_fan(ci, outer, D.FIRE_C, pos + Vector2(0, 0.1) * r * k)
		var inner := PackedVector2Array([pos + Vector2(-0.24, 0.42) * r * k, pos + Vector2(0, -0.6 * flick) * r * k,
				pos + Vector2(0.24, 0.42) * r * k])
		G2.fill_fan(ci, inner, Color8(255, 235, 130), pos + Vector2(0, 0.2) * r * k)
		var bp := pos + Vector2(0.68, -0.68) * r
		ci.draw_circle(bp, r * 0.26, P.LINE)
		ci.draw_circle(bp, r * 0.21, Color8(255, 150, 60))
		G2.text_mid(ci, bp, str(lit), r * 0.36, Color(1, 1, 1))
	else:
		for k in 3:
			var p := pos + Vector2(sin(t * 2.0 + k) * 0.15, -0.1 - k * 0.3 - fposmod(t * 0.5, 0.3)) * r
			ci.draw_circle(p, r * (0.15 + k * 0.05), Color(0.6, 0.6, 0.68, 0.55))


## 색 그릇 — 유리 단지에 그 색 젤리가 찬 만큼 보인다.
static func jar(ci: CanvasItem, pos: Vector2, r: float, c: int, left: int, full: int) -> void:
	var body := Rect2(pos + Vector2(-0.7, -0.6) * r, Vector2(1.4, 1.55) * r)
	var k := 1.0 - float(left) / maxf(1, full)
	if Tex.art("ob_jar") != null:
		# 단지 몸통 안을 그 색으로 아래부터 채운다 — 얼마나 찼는지가 미션 진행이다
		var inner := Rect2(pos + Vector2(-0.6, -0.3) * r, Vector2(1.2, 1.1) * r)
		_tex(ci, "ob_jar", pos, r * 2.75)
		if k > 0.0:
			G2.panel(ci, Rect2(inner.position + Vector2(0, inner.size.y * (1.0 - k)), Vector2(inner.size.x, inner.size.y * k)),
					P.a(P.jelly(c), 0.7), Color(), 0.0, r * 0.3)
		jelly(ci, pos + Vector2(0, 0.15) * r, r * 0.3, c, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, 0.0)
		G2.text_mid(ci, pos + Vector2(0.62, 0.72) * r, str(left), r * 0.8, Color(1, 1, 1), r * 0.2)
		return
	var fill := Rect2(body.position + Vector2(0, body.size.y * (1.0 - k)), Vector2(body.size.x, body.size.y * k))
	G2.panel(ci, body, Color(1, 1, 1, 0.3), Color(), 0.0, r * 0.25)
	if k > 0.0:
		G2.panel(ci, fill, P.a(P.jelly(c), 0.85), Color(), 0.0, r * 0.2)
	G2.panel(ci, body, Color(0, 0, 0, 0), P.LINE, r * 0.1, r * 0.25)
	ci.draw_rect(Rect2(pos + Vector2(-0.55, -0.85) * r, Vector2(1.1, 0.28) * r), P.jelly(c).darkened(0.2))
	jelly(ci, pos + Vector2(0, 0.15) * r, r * 0.3, c, D.SP_NONE, Face.IDLE, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, 0.0)
	G2.text_mid(ci, pos + Vector2(0.55, 0.75) * r, str(left), r * 0.5, Color(1, 1, 1), r * 0.12)
