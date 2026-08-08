class_name Art
extends RefCounted

## 심볼과 캐릭터를 코드로 그린다 (애니메이션풍 셀 셰이딩).
##
## 발광이 필요하면 P.hdr() 로 색을 1.0 위로 올려라 — 엔진이 번지게 해준다.

## 회전 중처럼 세밀함이 필요 없을 때 켜면 그림자를 건너뛴다
static var fast := false


static func _body(ci: CanvasItem, poly: PackedVector2Array, c: Color,
		shade: float, outline: float, bias: float = 0.02) -> void:
	if fast:
		G2.fill_fan(ci, poly, c)
		G2.stroke(ci, poly, P.LINE, outline)
	else:
		G2.body(ci, poly, c, shade, outline, bias)


static func sym(ci: CanvasItem, id: int, c: Vector2, s: float, t: float) -> void:
	if s < 1.0:
		return
	match id:
		D.WAKO: wako(ci, c, s, t)
		D.ARROW: arrow(ci, c, s, t)
		D.SHIELD: shield(ci, c, s, t)
		D.DRUM: war_drum(ci, c, s, t)
		D.SWORD: sword(ci, c, s, t)
		D.FLAG: banner(ci, c, s, t)
		D.SHIP: panokseon(ci, c, s, t)
		D.TURTLE: turtle(ci, c, s, t)
		D.WILD: admiral(ci, c, s, t)
		D.SCAT: cannon(ci, c, s, t)

# ==================== 왜구 ====================

static func wako(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	o.y += sin(t * 2.4) * s * 0.03
	var lw: float = maxf(1.0, s * 0.055)
	var skin := Color8(234, 202, 174)

	_body(ci, G2.blob([
		o + Vector2(-0.86, 1.04) * s, o + Vector2(-0.66, 0.58) * s, o + Vector2(0, 0.44) * s,
		o + Vector2(0.66, 0.58) * s, o + Vector2(0.86, 1.04) * s,
	]), Color8(68, 72, 92), 0.30, lw)

	_body(ci, G2.ellipse(o + Vector2(0, 0.10) * s, s * 0.50, s * 0.56), skin, 0.20, lw, 0.05)

	var fl := sin(t * 3.4) * s * 0.10
	_body(ci, G2.blob([
		o + Vector2(0.42, -0.22) * s,
		o + Vector2(0.84 * s, -0.06 * s + fl),
		o + Vector2(0.92 * s, 0.14 * s + fl),
		o + Vector2(0.46, -0.02) * s,
	]), Color8(182, 40, 50), 0.26, lw * 0.8)
	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.50, -0.26) * s, Vector2(1.00, 0.20) * s), s * 0.07),
			Color8(214, 56, 62), 0.30, lw * 0.9)

	_body(ci, G2.blob([
		o + Vector2(-0.96, -0.26) * s, o + Vector2(-0.44, -0.78) * s, o + Vector2(0, -0.96) * s,
		o + Vector2(0.44, -0.78) * s, o + Vector2(0.96, -0.26) * s, o + Vector2(0, -0.40) * s,
	]), Color8(132, 104, 74), 0.30, lw, 0.0)
	ci.draw_line(o + Vector2(-0.62, -0.48) * s, o + Vector2(0.62, -0.48) * s,
			P.a(Color8(70, 54, 38), 0.5), lw * 0.7, true)

	for side in [-1.0, 1.0]:
		_body(ci, PackedVector2Array([
			o + Vector2(side * 0.38, -0.04) * s, o + Vector2(side * 0.08, 0.10) * s,
			o + Vector2(side * 0.09, 0.19) * s, o + Vector2(side * 0.40, 0.05) * s,
		]), Color8(48, 36, 34), 0.0, lw * 0.45)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var e := o + Vector2(side * 0.22, 0.26) * s
		_body(ci, G2.blob([
			e + Vector2(-0.15, 0.02) * s, e + Vector2(0, -0.08) * s,
			e + Vector2(0.15, -0.01) * s, e + Vector2(0, 0.08) * s,
		]), Color8(252, 250, 246), 0.0, lw * 0.55)
		var ir := e + Vector2(-side * 0.02, 0) * s
		ci.draw_circle(ir, s * 0.062, Color8(150, 40, 36))
		ci.draw_circle(ir, s * 0.032, Color8(28, 20, 24))

	_body(ci, G2.blob([
		o + Vector2(-0.22, 0.46) * s, o + Vector2(0, 0.42) * s,
		o + Vector2(0.22, 0.46) * s, o + Vector2(0, 0.62) * s,
	]), Color8(78, 32, 38), 0.0, lw * 0.6)
	for side in [-1.0, 1.0]:
		G2.fill_fan(ci, PackedVector2Array([
			o + Vector2(side * 0.14, 0.45) * s, o + Vector2(side * 0.05, 0.45) * s,
			o + Vector2(side * 0.095, 0.55) * s,
		]), Color8(250, 248, 244))

# ==================== 화살 ====================

static func arrow(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var ang := -PI / 4.0 + sin(t * 1.6) * 0.04
	var lw: float = maxf(1.0, s * 0.05)
	ci.draw_set_transform(o, ang, Vector2.ONE)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.88, -0.075) * s, Vector2(1.52, 0.15) * s), s * 0.07),
			Color8(178, 138, 88), 0.28, lw)
	for i in 2:
		var sd := 1.0 if i == 0 else -1.0
		_body(ci, G2.blob([
			Vector2(-0.88, 0) * s, Vector2(-0.40, sd * 0.05) * s,
			Vector2(-0.48, sd * 0.34) * s, Vector2(-0.92, sd * 0.28) * s,
		]), Color8(226, 72, 78) if i == 0 else Color8(178, 44, 54), 0.26, lw * 0.9)
	_body(ci, PackedVector2Array([
		Vector2(1.00, 0) * s, Vector2(0.46, 0.28) * s,
		Vector2(0.56, 0) * s, Vector2(0.46, -0.28) * s,
	]), Color8(228, 236, 248), 0.30, lw, -0.10)
	ci.draw_line(Vector2(0.92, -0.03) * s, Vector2(0.56, -0.13) * s,
			P.a(Color.WHITE, 0.85), lw * 0.8, true)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ==================== 방패 ====================

static func shield(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var r := s * 0.92
	var lw: float = maxf(1.0, s * 0.055)
	_body(ci, G2.circle(o, r), Color8(58, 128, 176), 0.34, lw)
	_body(ci, G2.circle(o, r * 0.80), Color8(96, 182, 220), 0.28, lw * 0.8)
	taegeuk(ci, o, r * 0.52, t * 0.55, lw * 0.9)
	for i in 8:
		var a := i * PI / 4.0 + 0.4
		_body(ci, G2.circle(o + Vector2(cos(a), sin(a)) * r * 0.90, r * 0.075, 12),
				P.GOLD, 0.30, lw * 0.5)


## 태극 — 큰 원을 반 나눈 뒤 반지름 절반짜리 원 두 개를 덧칠해 S 자 경계를 만든다
static func taegeuk(ci: CanvasItem, o: Vector2, r: float, rot: float, lw: float) -> void:
	if r < 2.0:
		return
	var red := Color8(222, 58, 66)
	var blue := Color8(40, 84, 168)
	var nrm := Vector2(cos(rot + PI * 0.5), sin(rot + PI * 0.5))
	var whole := G2.circle(o, r, 40)
	G2.fill_fan(ci, whole, blue)

	# 붉은 반쪽
	var half := PackedVector2Array()
	for i in 21:
		var a: float = rot + PI * i / 20.0
		half.append(o + Vector2(cos(a), sin(a)) * r)
	half.append(o)
	G2.fill_fan(ci, half, red)

	G2.fill_fan(ci, G2.circle(o + nrm * r * 0.5, r * 0.5, 26), blue)
	G2.fill_fan(ci, G2.circle(o - nrm * r * 0.5, r * 0.5, 26), red)
	G2.stroke(ci, whole, P.LINE, lw)

# ==================== 전고 ====================

static func war_drum(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var hit: float = maxf(0.0, sin(t * 3.1))
	var lw: float = maxf(1.0, s * 0.055)
	var w := s * 0.88 * (1.0 + hit * 0.04)
	var hh := s * 0.68

	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var top := o + Vector2(sd * 0.30 * s, -0.62 * s + hit * s * 0.12)
		var bot := o + Vector2(sd * 0.95 * s, 0.72 * s)
		ci.draw_line(top, bot, Color8(166, 128, 82), lw * 2.2, true)

	_body(ci, G2.blob([
		o + Vector2(-w, -hh * 0.55), o + Vector2(0, -hh), o + Vector2(w, -hh * 0.55),
		o + Vector2(w, hh * 0.55), o + Vector2(0, hh), o + Vector2(-w, hh * 0.55),
	]), Color8(196, 88, 54), 0.34, lw)
	_body(ci, G2.circle(o, hh * 0.96, 36), Color8(240, 220, 188), 0.20, lw, 0.06)

	var cc := [Color8(222, 58, 66), Color8(52, 100, 194), P.GOLD]
	for i in 3:
		var a := t * 0.7 + i * TAU / 3.0
		G2.fill_fan(ci, G2.circle(o + Vector2(cos(a), sin(a)) * hh * 0.30, hh * 0.30, 20), cc[i])
	G2.stroke(ci, G2.circle(o, hh * 0.96, 36), P.LINE, lw * 0.8)

	for i in 10:
		var a := i * PI / 5.0
		ci.draw_circle(o + Vector2(cos(a), sin(a)) * hh, s * 0.05, P.GOLD)

# ==================== 장검 ====================

static func sword(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var ang := -0.30 + sin(t * 1.3) * 0.05
	var lw: float = maxf(1.0, s * 0.05)
	ci.draw_set_transform(o, ang, Vector2.ONE)

	_body(ci, G2.blob([
		Vector2(0, -1.08) * s, Vector2(0.13, -0.86) * s, Vector2(0.12, 0.10) * s,
		Vector2(-0.11, 0.10) * s, Vector2(-0.09, -0.84) * s,
	], 4), Color8(232, 240, 252), 0.26, lw, -0.16)
	ci.draw_line(Vector2(-0.02, -0.92) * s, Vector2(-0.02, 0.04) * s,
			P.a(Color.WHITE, 0.9), lw * 0.7, true)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.36, 0.06) * s, Vector2(0.72, 0.17) * s), s * 0.07),
			P.GOLD, 0.34, lw)
	_body(ci, G2.round_rect(Rect2(Vector2(-0.13, 0.21) * s, Vector2(0.26, 0.64) * s), s * 0.09),
			Color8(58, 44, 66), 0.30, lw)
	for i in 4:
		ci.draw_line(Vector2(-0.13, 0.30 + i * 0.13) * s, Vector2(0.13, 0.36 + i * 0.13) * s,
				P.a(P.GOLD, 0.9), lw * 0.9, true)
	_body(ci, G2.circle(Vector2(0, 0.92) * s, s * 0.12, 16), P.GOLD, 0.32, lw * 0.8)

	var sw := sin(t * 2.2) * 0.30
	_body(ci, G2.blob([
		Vector2(0.02, 1.00) * s, Vector2((0.16 + sw), 1.20) * s,
		Vector2((0.10 + sw), 1.34) * s, Vector2(-0.04, 1.10) * s,
	]), Color8(214, 56, 62), 0.28, lw * 0.7)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ==================== 수자기 ====================

static func banner(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var lw: float = maxf(1.0, s * 0.05)
	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.66, -1.02) * s, Vector2(0.10, 2.04) * s), s * 0.05),
			Color8(148, 112, 72), 0.30, lw * 0.8)
	_body(ci, G2.circle(o + Vector2(-0.61, -1.06) * s, s * 0.12, 14), P.GOLD, 0.30, lw * 0.7)

	var n := 9
	var top := []
	var bot := []
	for i in n:
		var u := float(i) / (n - 1)
		var x := o.x - s * 0.60 + u * s * 1.40
		var wave := sin(t * 3.2 - u * 4.0) * s * 0.13 * u
		top.append(Vector2(x, o.y - s * 0.84 + wave))
		bot.append(Vector2(x, o.y + s * 0.70 + wave * 1.3))

	var cloth := PackedVector2Array()
	for p in top:
		cloth.append(p)
	for i in range(n - 1, -1, -1):
		cloth.append(bot[i])
	_body(ci, cloth, Color8(222, 58, 66), 0.30, lw, 0.10)

	var tp := PackedVector2Array(top)
	var bp := PackedVector2Array(bot)
	ci.draw_polyline(tp, P.a(P.GOLD, 0.95), lw * 0.9, true)
	ci.draw_polyline(bp, P.a(P.GOLD_DEEP, 0.9), lw * 0.9, true)

	var ty := sin(t * 3.2 - 2.4) * s * 0.09
	G2.text_mid(ci, o + Vector2(0.10 * s, -0.04 * s + ty + s * 0.30), "帥", s * 0.98, P.GOLD_HI)

# ==================== 판옥선 ====================

static func panokseon(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	o.y += sin(t * 1.9) * s * 0.05
	var lw: float = maxf(1.0, s * 0.05)
	ci.draw_set_transform(o, sin(t * 1.5) * 0.045, Vector2.ONE)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.045, -1.10) * s, Vector2(0.09, 1.26) * s), s * 0.045),
			Color8(140, 104, 66), 0.28, lw * 0.7)
	ci.draw_line(Vector2(-0.64, -0.96) * s, Vector2(0.64, -0.96) * s, Color8(120, 88, 56), lw * 1.5, true)

	var bulge := 0.10 + sin(t * 1.4) * 0.03
	_body(ci, G2.blob([
		Vector2(-0.60, -0.94) * s, Vector2(0, -(0.94 - bulge * 0.35)) * s,
		Vector2(0.60, -0.94) * s, Vector2((0.60 + bulge), -0.50) * s,
		Vector2(0.58, -0.10) * s, Vector2(0, -(0.10 - bulge * 0.30)) * s,
		Vector2(-0.58, -0.10) * s, Vector2(-(0.60 - bulge * 0.4), -0.50) * s,
	], 4), Color8(244, 236, 218), 0.22, lw, 0.06)
	for i in 2:
		var y := -(0.72 - i * 0.34) * s
		ci.draw_line(Vector2(-0.57 * s, y), Vector2(0.57 * s, y), Color8(218, 70, 74), lw * 2.2, true)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.50, 0.02) * s, Vector2(1.00, 0.28) * s), s * 0.07),
			Color8(168, 122, 78), 0.28, lw)
	_body(ci, G2.blob([
		Vector2(-0.98, 0.32) * s, Vector2(0, 0.26) * s, Vector2(0.98, 0.32) * s,
		Vector2(0.70, 0.84) * s, Vector2(0, 0.92) * s, Vector2(-0.70, 0.84) * s,
	], 4), Color8(122, 84, 52), 0.34, lw, 0.04)
	_body(ci, G2.round_rect(Rect2(Vector2(-0.96, 0.30) * s, Vector2(1.92, 0.16) * s), s * 0.07),
			Color8(160, 116, 72), 0.22, lw * 0.6)
	for i in 6:
		var x := (-0.72 + i * 0.29) * s
		_body(ci, G2.circle(Vector2(x, 0.58 * s), s * 0.085, 12),
				Color8(72, 138, 200) if i % 2 == 0 else Color8(222, 66, 72), 0.25, lw * 0.55)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ==================== 거북선 ====================

static func turtle(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	o.y += sin(t * 1.7) * s * 0.045
	var lw: float = maxf(1.0, s * 0.05)

	for i in 4:
		var x := o.x - s * 0.68 + i * s * 0.45
		var sw := sin(t * 4.2 + i * 0.7) * 0.28
		ci.draw_line(Vector2(x, o.y + s * 0.44),
				Vector2(x - cos(sw + 1.2) * s * 0.44, o.y + s * 0.90),
				Color8(126, 92, 58), s * 0.12, true)

	for i in 9:
		var a := PI + (i + 0.5) * PI / 9.0
		var p := o + Vector2(cos(a) * s * 0.72, s * 0.16 + sin(a) * s * 0.62)
		_body(ci, PackedVector2Array([
			p + Vector2(0, -0.20) * s, p + Vector2(-0.058, 0.04) * s, p + Vector2(0.058, 0.04) * s,
		]), Color8(226, 234, 246), 0.26, lw * 0.5)

	var shell := PackedVector2Array()
	for i in 25:
		var a: float = PI + PI * i / 24.0
		shell.append(o + Vector2(cos(a) * s * 0.80, s * 0.18 + sin(a) * s * 0.52))
	# 마지막 점은 첫 점과 밑변으로 자동으로 이어진다. 같은 점을 또 넣으면 변이 겹쳐 깨진다.
	_body(ci, shell, Color8(72, 142, 116), 0.32, lw)
	if not fast:
		for row in 2:
			for i in 6:
				var hx := o.x - s * 0.62 + i * s * 0.25 + (s * 0.125 if row == 1 else 0.0)
				var hy := o.y - s * 0.02 + row * s * 0.20
				_hex(ci, Vector2(hx, hy), s * 0.125, Color8(104, 186, 152), Color8(44, 96, 80), lw * 0.5)

	_body(ci, G2.blob([
		o + Vector2(-1.00, 0.18) * s, o + Vector2(0, 0.12) * s, o + Vector2(1.00, 0.18) * s,
		o + Vector2(0.74, 0.76) * s, o + Vector2(0, 0.86) * s, o + Vector2(-0.74, 0.76) * s,
	], 4), Color8(122, 84, 52), 0.34, lw, 0.04)
	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.98, 0.16) * s, Vector2(1.96, 0.16) * s), s * 0.07),
			Color8(160, 116, 72), 0.22, lw * 0.6)
	for i in 4:
		ci.draw_circle(o + Vector2(-0.54 + i * 0.36, 0.50) * s, s * 0.062, Color8(38, 26, 20))

	var hd := o + Vector2(0.92, 0.16) * s
	_body(ci, G2.blob([
		hd + Vector2(-0.34, -0.30) * s, hd + Vector2(0.16, -0.26) * s, hd + Vector2(0.48, -0.02) * s,
		hd + Vector2(0.30, 0.22) * s, hd + Vector2(-0.30, 0.24) * s,
	]), P.GOLD, 0.32, lw)
	_body(ci, PackedVector2Array([
		hd + Vector2(-0.26, -0.28) * s, hd + Vector2(-0.06, -0.62) * s, hd + Vector2(0.08, -0.24) * s,
	]), Color8(200, 146, 30), 0.25, lw * 0.7)
	ci.draw_circle(hd + Vector2(0.02, -0.10) * s, s * 0.07, Color8(214, 56, 62))
	ci.draw_circle(hd + Vector2(0.02, -0.10) * s, s * 0.032, P.LINE)
	ci.draw_line(hd + Vector2(0.18, 0.10) * s, hd + Vector2(0.44, 0.02) * s, P.LINE, lw * 0.8, true)

	for i in 3:
		var ph := fposmod(t * 0.9 + i * 0.33, 1.0)
		ci.draw_circle(hd + Vector2(0.48 * s + ph * s * 0.5, -ph * s * 0.5),
				s * (0.07 + ph * 0.12), P.a(Color8(226, 232, 242), (1.0 - ph) * 0.45))


static func _hex(ci: CanvasItem, c: Vector2, r: float, f: Color, e: Color, lw: float) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := i * PI / 3.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	G2.fill_fan(ci, pts, f)
	G2.stroke(ci, pts, e, lw)

# ==================== 이순신 ====================

static func admiral(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	o.y += sin(t * 1.8) * s * 0.025
	var lw: float = maxf(1.0, s * 0.055)
	var skin := Color8(240, 212, 184)
	var armor := Color8(86, 74, 116)

	_body(ci, G2.blob([
		o + Vector2(-1.00, 1.16) * s, o + Vector2(-0.78, 0.60) * s, o + Vector2(0, 0.46) * s,
		o + Vector2(0.78, 0.60) * s, o + Vector2(1.00, 1.16) * s,
	]), armor, 0.32, lw)
	for i in 5:
		ci.draw_circle(o + Vector2(-0.72 + i * 0.36, 0.70) * s, s * 0.065, P.GOLD)

	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.19, 0.24) * s, Vector2(0.38, 0.30) * s), s * 0.10),
			P.darken(skin, 0.18), 0.0, lw * 0.7)

	_body(ci, G2.blob([
		o + Vector2(0, -0.48) * s, o + Vector2(0.46, -0.16) * s, o + Vector2(0.40, 0.30) * s,
		o + Vector2(0, 0.64) * s, o + Vector2(-0.40, 0.30) * s, o + Vector2(-0.46, -0.16) * s,
	]), skin, 0.20, lw, 0.05)

	_body(ci, G2.blob([
		o + Vector2(-0.24, 0.42) * s, o + Vector2(0, 0.40) * s, o + Vector2(0.24, 0.42) * s,
		o + Vector2(0.15, 0.74) * s, o + Vector2(0, 0.82) * s, o + Vector2(-0.15, 0.74) * s,
	]), Color8(56, 46, 50), 0.22, lw * 0.6)

	for side in [-1.0, 1.0]:
		_body(ci, PackedVector2Array([
			o + Vector2(side * 0.40, -0.22) * s, o + Vector2(side * 0.09, -0.11) * s,
			o + Vector2(side * 0.10, -0.02) * s, o + Vector2(side * 0.41, -0.11) * s,
		]), Color8(44, 34, 40), 0.0, lw * 0.45)

	for side in [-1.0, 1.0]:
		var e := o + Vector2(side * 0.21, 0.06) * s
		_body(ci, G2.ellipse(e, s * 0.16, s * 0.13, 20), Color8(250, 250, 255), 0.0, lw * 0.55)
		ci.draw_circle(e + Vector2(0, s * 0.012), s * 0.085, Color8(96, 66, 44))
		ci.draw_circle(e + Vector2(0, s * 0.012), s * 0.042, Color8(24, 18, 32))
		ci.draw_circle(e + Vector2(-s * 0.035, -s * 0.038), s * 0.026, P.a(Color.WHITE, 0.95))

	ci.draw_line(o + Vector2(-0.11, 0.36) * s, o + Vector2(0.11, 0.36) * s,
			Color8(150, 104, 92), lw * 0.8, true)
	_body(ci, G2.blob([
		o + Vector2(-0.19, 0.30) * s, o + Vector2(0, 0.25) * s,
		o + Vector2(0.19, 0.30) * s, o + Vector2(0, 0.34) * s,
	]), Color8(56, 46, 50), 0.0, lw * 0.45)

	var helm := PackedVector2Array()
	for i in 21:
		var a: float = PI + PI * i / 20.0
		helm.append(o + Vector2(cos(a) * s * 0.64, -0.42 * s + sin(a) * s * 0.58))
	_body(ci, helm, Color8(104, 90, 138), 0.34, lw, 0.0)
	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.70, -0.50) * s, Vector2(1.40, 0.18) * s), s * 0.08),
			P.GOLD, 0.32, lw)
	_body(ci, PackedVector2Array([
		o + Vector2(0, -0.92) * s, o + Vector2(-0.17, -0.50) * s, o + Vector2(0.17, -0.50) * s,
	]), P.GOLD_HI, 0.25, lw * 0.7)

	var pl := sin(t * 2.6) * s * 0.07
	_body(ci, G2.blob([
		o + Vector2(-0.05, -0.98) * s,
		o + Vector2(0.16 * s + pl, -1.26 * s),
		o + Vector2(0.38 * s + pl * 1.6, -1.34 * s),
		o + Vector2(0.30 * s + pl * 1.6, -1.16 * s),
		o + Vector2(0.10 * s + pl, -1.10 * s),
	]), Color8(222, 58, 66), 0.28, lw * 0.7)
	_body(ci, G2.circle(o + Vector2(0, -0.98) * s, s * 0.10, 14), P.GOLD, 0.30, lw * 0.6)

# ==================== 천자총통 ====================

static func cannon(ci: CanvasItem, o: Vector2, s: float, t: float) -> void:
	var fire := fposmod(t * 0.9, 1.0)
	var lw: float = maxf(1.0, s * 0.05)
	ci.draw_set_transform(o, deg_to_rad(-14.0), Vector2.ONE)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.88, 0.28) * s, Vector2(1.76, 0.36) * s), s * 0.10),
			Color8(122, 88, 56), 0.30, lw)
	for sd in [-1.0, 1.0]:
		_body(ci, G2.circle(Vector2(sd * 0.50, 0.64) * s, s * 0.17, 16), Color8(84, 58, 38), 0.25, lw * 0.8)

	_body(ci, G2.round_rect(Rect2(Vector2(-0.94, -0.28) * s, Vector2(1.90, 0.60) * s), s * 0.18),
			Color8(206, 162, 96), 0.34, lw, 0.0)
	for i in 4:
		_body(ci, G2.round_rect(Rect2(Vector2(-0.72 + i * 0.45, -0.32) * s, Vector2(0.11, 0.68) * s), s * 0.05),
				Color8(238, 200, 128), 0.28, lw * 0.55)
	_body(ci, G2.round_rect(Rect2(Vector2(0.76, -0.35) * s, Vector2(0.22, 0.76) * s), s * 0.08),
			Color8(244, 212, 142), 0.30, lw * 0.7)
	_body(ci, G2.ellipse(Vector2(0.94, 0.02) * s, s * 0.09, s * 0.24, 16), Color8(34, 24, 20), 0.0, lw * 0.6)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 포구 불꽃 — HDR 색이라 엔진이 번지게 해준다
	var m := o + Vector2(0.96, -0.12) * s
	var f := 1.0 - fire
	ci.draw_circle(m, s * (0.17 + fire * 0.30), P.hdr(P.ORANGE, 1.2 + f * 2.4))
	ci.draw_circle(m, s * (0.09 + fire * 0.16), P.hdr(P.GOLD_HI, 1.6 + f * 2.6))

# ==================== 해전 연출용 ====================

## 이순신 전신. 두 손으로 칼을 잡고 몸을 틀어 내려친다.
##
## swing 은 -1..1.  -1..0 이 준비 동작(뒤로 젖힘), 0 에서 칼날이 목표에 닿고,
## 0..1 이 마무리 동작이다. 팔 하나만 움직이면 어색하므로 양팔·허리·머리가 같이 돈다.
static func admiral_full(ci: CanvasItem, o: Vector2, s: float, t: float, swing: float,
		trail_amt: float = 0.0) -> void:
	if s < 1.0:
		return
	var lw: float = maxf(1.2, s * 0.045)
	var armor := Color8(78, 66, 108)
	o.y += sin(t * 2.2) * s * 0.03

	# 허리 회전 — 준비에서 오른쪽으로 웅크렸다가, 올려베며 왼쪽으로 펴진다
	var lean := (0.26 * absf(minf(swing, 0.0)) - 0.30 * clampf(swing, 0.0, 1.0))
	var crouch := s * (0.06 * absf(minf(swing, 0.0)) - 0.05 * clampf(swing, 0.0, 1.0))

	# 전포 — 몸이 돌면 같이 날린다
	var cape: Array = []
	for i in 7:
		var u := i / 6.0
		cape.append(Vector2(
			o.x - s * 0.30 - u * s * (1.20 + lean * 0.9)
					+ sin(t * 3.0 - u * 3.0) * s * 0.11 * u,
			o.y - s * 0.58 + u * s * 1.72 + cos(t * 2.6 - u * 2.0) * s * 0.09 * u))
	cape.append(o + Vector2(-0.08, 0.98) * s)
	cape.append(o + Vector2(-0.18, -0.58) * s)
	_body(ci, G2.blob(cape, 5), Color8(206, 52, 62), 0.32, lw, 0.10)

	# 다리 — 앞뒤로 벌려 버틴다
	_body(ci, G2.round_rect(Rect2(o + Vector2(-0.40 - lean * 0.10, 0.54) * s,
			Vector2(0.30, 0.76) * s), s * 0.12), Color8(52, 44, 68), 0.28, lw)
	_body(ci, G2.round_rect(Rect2(o + Vector2(0.10 + lean * 0.16, 0.54) * s,
			Vector2(0.30, 0.76) * s), s * 0.12), Color8(60, 50, 76), 0.28, lw)

	# 몸통 (허리 회전 + 살짝 낮아짐)
	var bo := o + Vector2(lean * s * 0.10, crouch)
	_body(ci, G2.blob([
		bo + Vector2(-0.46, -0.10) * s, bo + Vector2(0, -0.18) * s, bo + Vector2(0.46, -0.10) * s,
		bo + Vector2(0.42, 0.68) * s, bo + Vector2(0, 0.74) * s, bo + Vector2(-0.42, 0.68) * s,
	]), armor, 0.32, lw)
	for i in 3:
		_body(ci, G2.round_rect(
				Rect2(bo + Vector2(-0.40, 0.02 + i * 0.20) * s, Vector2(0.80, 0.07) * s), s * 0.035),
				P.GOLD, 0.25, lw * 0.5)

	# ---- 두 손으로 잡은 칼 ----
	# 손잡이 궤도: 오른쪽 아래(준비) → 오른쪽(타격) → 왼쪽 위(마무리) 로 **올려벤다**.
	# 내려베면 칼끝이 화면 아래 조작대에 가려서 가장 멋있는 순간이 안 보인다.
	# 각도는 y 가 아래로 크는 좌표라 값이 줄수록 반시계(위로) 돈다.
	var ha := lerpf(1.15, -2.15, (swing + 1.0) * 0.5)
	var hr := s * (0.76 - 0.08 * absf(swing))
	var grip := bo + Vector2(cos(ha), sin(ha)) * hr + Vector2(0, -s * 0.12)
	var blade_a := ha + 0.35
	var tip := grip + Vector2(cos(blade_a), sin(blade_a)) * s * 1.45

	# 잔상 — 실제로 휘두르는 동안에만 (쉴 때 남으면 부챗살처럼 보인다).
	# 궤도가 반시계라 잔상은 각도가 큰 쪽, 즉 지나온 아래쪽에 남는다.
	var trail: float = clampf(trail_amt, 0.0, 1.0)
	if trail > 0.02:
		for k in 5:
			var back := blade_a + 0.30 * k
			ci.draw_line(grip, grip + Vector2(cos(back), sin(back)) * s * 1.45,
					P.a(P.hdr(P.GOLD_HI, 1.5), trail * 0.16 * (1.0 - k / 5.0)), s * 0.10, true)

	# 어깨 — 뒤쪽 팔 먼저
	for sd in [-1.0, 1.0]:
		var sh := bo + Vector2(sd * 0.54 + lean * 0.06, 0.0) * s
		if sd < 0.0:
			_body(ci, G2.ellipse(sh, s * 0.22, s * 0.19, 18), Color8(116, 100, 152), 0.30, lw)
			# 왼팔(받쳐 잡는 손)
			ci.draw_line(sh, grip - Vector2(cos(blade_a), sin(blade_a)) * s * 0.16,
					P.LINE, s * 0.22, true)
			ci.draw_line(sh, grip - Vector2(cos(blade_a), sin(blade_a)) * s * 0.16,
					Color8(118, 102, 158), s * 0.15, true)

	# 칼
	ci.draw_line(grip, tip, P.a(P.GOLD_HI, 0.30), s * 0.26, true)
	ci.draw_line(grip, tip, P.LINE, s * 0.13, true)
	ci.draw_line(grip, tip, P.hdr(Color8(238, 244, 254), 1.35), s * 0.085, true)
	# 코등이와 손잡이
	_body(ci, G2.circle(grip, s * 0.11, 14), P.GOLD, 0.3, lw * 0.7)
	ci.draw_line(grip, grip - Vector2(cos(blade_a), sin(blade_a)) * s * 0.26,
			Color8(58, 44, 66), s * 0.09, true)

	# 오른팔(주로 잡는 손) — 칼 위로
	var rsh := bo + Vector2(0.54 + lean * 0.06, 0.0) * s
	ci.draw_line(rsh, grip, P.LINE, s * 0.24, true)
	ci.draw_line(rsh, grip, Color8(126, 110, 164), s * 0.17, true)
	_body(ci, G2.ellipse(rsh, s * 0.22, s * 0.19, 18), Color8(116, 100, 152), 0.30, lw)

	# 머리 — 시선이 칼끝을 따라간다
	admiral(ci, bo + Vector2(lean * s * 0.08, -s * 0.66), s * 0.54, t)


## 아군 판옥선 갑판
static func deck(ci: CanvasItem, o: Vector2, w: float, t: float) -> void:
	if w < 4.0:
		return
	o.y += sin(t * 1.8) * w * 0.010
	var h := w * 0.22
	var lw: float = maxf(1.2, w * 0.010)
	_body(ci, G2.blob([
		o + Vector2(-w * 0.50, 0), o + Vector2(0, -h * 0.10), o + Vector2(w * 0.50, 0),
		o + Vector2(w * 0.36, h), o + Vector2(0, h * 1.12), o + Vector2(-w * 0.36, h),
	], 4), Color8(122, 84, 52), 0.32, lw, 0.04)
	_body(ci, G2.round_rect(Rect2(o + Vector2(-w * 0.48, -h * 0.06), Vector2(w * 0.96, h * 0.26)),
			h * 0.10), Color8(158, 116, 74), 0.24, lw * 0.7)
	for i in 9:
		var x := o.x - w * 0.40 + i * w * 0.10
		_body(ci, G2.circle(Vector2(x, o.y + h * 0.52), w * 0.034, 12),
				Color8(72, 138, 200) if i % 2 == 0 else Color8(222, 66, 72), 0.22, lw * 0.5)


## 왜구 병사. dead 0..1 이면 쓰러지는 중.
static func wako_soldier(ci: CanvasItem, o: Vector2, s: float, t: float,
		dead: float, alpha: float) -> void:
	if alpha <= 0.01 or s < 1.0:
		return
	var lw: float = maxf(1.0, s * 0.055)
	var a2 := alpha * (1.0 - dead * 0.5)
	var body_c := P.a(Color8(58, 52, 76), a2)
	var line_c := P.a(P.LINE, a2)
	ci.draw_set_transform(o + Vector2(0, dead * s * 0.5), dead * 1.47, Vector2.ONE)

	var step := sin(t * 9.0 + o.x) * s * 0.20
	ci.draw_line(Vector2(0, s * 0.20), Vector2(-s * 0.18 + step, s * 0.88), body_c, s * 0.17, true)
	ci.draw_line(Vector2(0, s * 0.20), Vector2(s * 0.18 - step, s * 0.88), body_c, s * 0.17, true)

	var torso := G2.blob([
		Vector2(-0.32, -0.28) * s, Vector2(0, -0.36) * s, Vector2(0.32, -0.28) * s,
		Vector2(0.28, 0.28) * s, Vector2(0, 0.34) * s, Vector2(-0.28, 0.28) * s,
	])
	G2.fill_fan(ci, torso, body_c)
	if not fast:
		G2.shade(ci, torso, P.a(Color8(38, 34, 52), a2))
	G2.stroke(ci, torso, line_c, lw)

	ci.draw_line(Vector2(0.24, -0.14) * s, Vector2(0.60, -0.52) * s, body_c, s * 0.14, true)
	ci.draw_line(Vector2(0.60, -0.52) * s, Vector2(1.00, -1.06) * s,
			P.a(Color8(216, 226, 244), a2), s * 0.055, true)

	var head := G2.ellipse(Vector2(0, -0.52) * s, s * 0.23, s * 0.24, 18)
	G2.fill_fan(ci, head, P.a(Color8(206, 180, 158), a2))
	G2.stroke(ci, head, line_c, lw * 0.8)
	var hat := PackedVector2Array([
		Vector2(-0.46, -0.56) * s, Vector2(0, -0.96) * s,
		Vector2(0.46, -0.56) * s, Vector2(0, -0.66) * s,
	])
	G2.fill_fan(ci, hat, P.a(Color8(198, 52, 60), a2))
	G2.stroke(ci, hat, line_c, lw * 0.8)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 왜선
static func enemy_ship(ci: CanvasItem, o: Vector2, s: float, t: float, alpha: float) -> void:
	if alpha <= 0.01 or s < 1.0:
		return
	o.y += sin(t * 1.6 + o.x * 0.01) * s * 0.06
	var lw: float = maxf(1.0, s * 0.045)
	var hull := P.a(Color8(52, 48, 70), alpha)
	var line_c := P.a(P.LINE, alpha)

	ci.draw_line(o + Vector2(0, -0.98) * s, o + Vector2(0, 0.2) * s, hull, s * 0.07, true)

	# 돛 — 특정 국기 도안이 되지 않도록 가로 보강대만 넣는다
	var sail := G2.blob([
		o + Vector2(-0.54, -0.92) * s, o + Vector2(0.54, -0.92) * s,
		o + Vector2(0.50, -0.10) * s, o + Vector2(-0.50, -0.10) * s,
	], 3)
	G2.fill_fan(ci, sail, P.a(Color8(206, 200, 194), alpha))
	if not fast:
		G2.shade(ci, sail, P.a(Color8(150, 144, 142), alpha), 0.06)
	G2.stroke(ci, sail, line_c, lw)
	for i in 3:
		var y := o.y - s * (0.74 - i * 0.24)
		ci.draw_line(Vector2(o.x - s * 0.52, y), Vector2(o.x + s * 0.52, y),
				P.a(Color8(104, 98, 104), alpha * 0.8), s * 0.05, true)

	var body_p := G2.blob([
		o + Vector2(-0.90, 0.16) * s, o + Vector2(0, 0.10) * s, o + Vector2(0.90, 0.16) * s,
		o + Vector2(0.58, 0.58) * s, o + Vector2(0, 0.64) * s, o + Vector2(-0.58, 0.58) * s,
	], 4)
	G2.fill_fan(ci, body_p, hull)
	if not fast:
		G2.shade(ci, body_p, P.a(Color8(30, 28, 44), alpha))
	G2.stroke(ci, body_p, line_c, lw)


## 칼자국 — prog 0..1 로 그어지고 사라진다
static func slash(ci: CanvasItem, c: Vector2, len: float, ang: float, prog: float, col: Color) -> void:
	if prog >= 1.0 or prog < 0.0:
		return
	var draw_t := G2.out_quint(minf(1.0, prog / 0.35))
	var fade := 1.0 - clampf((prog - 0.35) / 0.65, 0.0, 1.0)
	var d := Vector2(cos(ang), sin(ang))
	var p1 := c - d * len * 0.5
	var p2 := p1 + d * len * draw_t
	for i in range(3, 0, -1):
		ci.draw_line(p1, p2, P.a(col, fade * 0.13 * i / 3.0), len * 0.030 * i, true)
	ci.draw_line(p1, p2, P.a(P.hdr(Color.WHITE, 1.7), fade), len * 0.016, true)


static func coin(ci: CanvasItem, c: Vector2, r: float, spin: float, alpha: float) -> void:
	if r < 0.5:
		return
	var w: float = maxf(r * 0.14, r * absf(cos(spin)))
	G2.grad_round(ci, Rect2(c - Vector2(w, r), Vector2(w * 2, r * 2)), w,
			P.a(P.hdr(P.GOLD_HI, 1.35), alpha), P.a(P.GOLD_DEEP, alpha), 8)
	G2.stroke_round(ci, Rect2(c - Vector2(w, r), Vector2(w * 2, r * 2)), w,
			P.a(Color8(140, 92, 12), alpha * 0.85), maxf(0.8, r * 0.10))
