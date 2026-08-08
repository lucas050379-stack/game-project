class_name Screen
extends RefCounted

## 화면 각 부분을 그린다. 상태를 갖지 않고 인자로 받은 값만 쓴다.
##
## 발광은 색을 1.0 위로 올려 엔진 블룸에 맡긴다 (P.hdr) — 원을 여러 겹 겹치지 말 것.

# ==================== 배경 ====================

static func background(ci: CanvasItem, L: Lay, t: float) -> void:
	G2.grad_round(ci, Rect2(0, 0, L.w, L.h), 0.0, P.VOID0, P.SEA0, 18)
	# 달빛
	G2.glow(ci, Vector2(L.w * 0.80, L.h * 0.16), 280.0, 200.0, Color8(120, 150, 210), 0.26)
	for layer in 4:
		var base_y := L.h * (0.42 + layer * 0.155)
		var amp := 8.0 + layer * 7.0
		var pts := PackedVector2Array()
		var x := -40.0
		while x <= L.w + 60.0:
			var ph := x * 0.011 + t * (12.0 + layer * 16.0) * 0.045 + layer
			pts.append(Vector2(x, base_y + sin(ph) * amp + sin(ph * 2.3 + 1.0) * amp * 0.4))
			x += 26.0
		pts.append(Vector2(L.w + 60.0, L.h + 40.0))
		pts.append(Vector2(-40.0, L.h + 40.0))
		G2.fill(ci, pts, P.a(P.mix(P.SEA0, P.SEA2, 0.10 + layer * 0.16), 0.5))

# ==================== 캐비닛 ====================

## 기계 바깥 윤곽 — 화면을 가로지르는 커다란 네온 원.
## 원 바깥(네 모서리)은 어둡게 덮어 기계 앞면이 둥글게 보이도록 한다.
static func cabinet(ci: CanvasItem, L: Lay, hot: bool, t: float) -> void:
	var c := L.oval_c
	var r := L.oval_r
	var ell := G2.ellipse(c, r.x, r.y, 128)

	# --- 원 바깥을 어둡게 (사분면마다 타원을 빼낸다) ---
	var quads := [
		Rect2(0, 0, c.x, c.y), Rect2(c.x, 0, L.w - c.x, c.y),
		Rect2(0, c.y, c.x, L.h - c.y), Rect2(c.x, c.y, L.w - c.x, L.h - c.y),
	]
	for q: Rect2 in quads:
		var qp := PackedVector2Array([
			q.position, Vector2(q.end.x, q.position.y), q.end, Vector2(q.position.x, q.end.y)])
		for piece in Geometry2D.clip_polygons(qp, ell):
			G2.fill(ci, piece, Color8(6, 5, 14))

	# --- 네온 관 여러 겹 ---
	var hue := fposmod(t * (90.0 if hot else 26.0), 360.0)
	var neon := P.hsv(hue, 0.85, 1.0)
	var neon2 := P.hsv(fposmod(hue + 150.0, 360.0), 0.85, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * (7.0 if hot else 2.4))
	var boost := (1.9 if hot else 1.0) * (0.75 + 0.45 * pulse)

	G2.stroke(ci, ell, Color8(16, 12, 26), 34.0)                       # 관 케이싱
	G2.stroke(ci, ell, P.a(neon, 0.35), 26.0)                          # 번짐
	G2.stroke(ci, ell, P.hdr(neon, 1.5 * boost), 11.0)                 # 관
	G2.stroke(ci, ell, P.hdr(Color(1, 1, 1), 1.7 * boost), 3.4)        # 심지

	var inner := G2.ellipse(c, r.x - 30.0, r.y - 30.0, 128)
	G2.stroke(ci, inner, P.hdr(neon2, 1.1 * boost), 5.0)
	var outer := G2.ellipse(c, r.x + 26.0, r.y + 26.0, 128)
	G2.stroke(ci, outer, P.hdr(neon2, 0.8 * boost), 3.0)

	# --- 원을 도는 전구 ---
	var n := 120
	for i in n:
		var a := TAU * i / n
		var p := c + Vector2(cos(a) * (r.x + 26.0), sin(a) * (r.y + 26.0))
		if p.x < -60.0 or p.x > L.w + 60.0:
			continue
		var wave := 0.5 + 0.5 * sin(a * 6.0 - t * (10.0 if hot else 3.4))
		var lit: float = 0.15 + 0.85 * pow(wave, 3.0)
		var col := P.hsv(fposmod(a * 57.3 * 2.0 + t * 240.0, 360.0), 0.9, 1.0) if hot \
				else P.mix(P.CYAN, P.GOLD_HI, wave)
		ci.draw_circle(p, 3.4, P.hdr(col, 0.3 + lit * 3.0))

	# --- 팡팡 터지는 네온 ---
	_bursts(ci, L, c, r, hot, t)


## 원 위에서 주기적으로 터지는 빛. 상태 없이 시간만으로 만든다.
static func _bursts(ci: CanvasItem, L: Lay, c: Vector2, r: Vector2, hot: bool, t: float) -> void:
	var slots := 7 if hot else 4
	var period := 0.9 if hot else 1.7
	for i in slots:
		var phase := fposmod(t / period + i * 0.618, 1.0)
		var cycle := floori(t / period + i * 0.618)
		# 터질 자리는 주기마다 바뀐다
		var a := fposmod(sin(float(cycle) * 12.9898 + i * 78.233) * 43758.5453, 1.0) * TAU
		var p := c + Vector2(cos(a) * (r.x + 26.0), sin(a) * (r.y + 26.0))
		if p.x < -40.0 or p.x > L.w + 40.0 or p.y < -40.0 or p.y > L.h + 40.0:
			continue
		var fade := 1.0 - phase
		var col := P.hsv(fposmod(cycle * 47.0 + t * 60.0, 360.0), 0.8, 1.0)

		# 퍼지는 고리
		var rad := 12.0 + phase * (150.0 if hot else 105.0)
		G2.stroke(ci, G2.circle(p, rad, 28), P.a(P.hdr(col, 1.9), fade * fade), 4.0 * fade + 0.6)
		# 중심 섬광
		ci.draw_circle(p, (16.0 + 10.0 * fade) * fade, P.a(P.hdr(col, 2.8), fade))
		# 뻗는 빛살
		for k in 6:
			var ra := a + TAU * k / 6.0 + phase * 0.5
			var len := (26.0 + phase * 90.0) * fade
			ci.draw_line(p, p + Vector2(cos(ra), sin(ra)) * len,
					P.a(P.hdr(col, 1.8), fade * fade), 3.0 * fade + 0.5, true)

# ==================== 상단 간판 ====================

static func marquee(ci: CanvasItem, L: Lay, g: Game, t: float) -> void:
	var r := L.marquee
	G2.grad_round(ci, r, 16.0, Color8(34, 16, 44), Color8(10, 8, 24), 10)
	G2.stroke_round(ci, r, 16.0, P.hdr(P.GOLD, 1.5), 2.6)

	for i in 30:
		var u := float(i) / 30.0
		var p := Lay.perimeter_at(r.grow(-9.0), u)
		var lit := 0.5 + 0.5 * sin(t * 5.0 + i * 0.9)
		ci.draw_circle(p, 2.4, P.hdr(Color8(255, 246, 214), 0.5 + lit * 2.2))

	G2.text(ci, Vector2(r.position.x + 34.0, r.position.y + 26.0), "P A C H I N K O",
			13.0, P.a(P.CYAN, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	var title_size: float = minf(38.0, r.size.y * 0.36)
	G2.text(ci, Vector2(r.position.x + 34.0, r.position.y + r.size.y * 0.62),
			"불멸의 이순신", title_size, P.hdr(P.GOLD_HI, 1.45), HORIZONTAL_ALIGNMENT_LEFT)
	G2.text(ci, Vector2(r.position.x + 36.0, r.end.y - 14.0), "S E A   B A T T L E   S L O T",
			12.0, P.a(P.VIOLET, 0.85), HORIZONTAL_ALIGNMENT_LEFT)

	var top := int(round(D.tier_total(D.TIERS - 1) * g.total_bet()))
	G2.text(ci, Vector2(r.end.x - 34.0, r.position.y + 24.0), "MAX 배당",
			12.0, P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, true, 300.0)
	var pulse := 0.5 + 0.5 * sin(t * 3.2)
	var amt := P.n(top)
	var asz: float = minf(46.0, r.size.y * 0.44)
	G2.text(ci, Vector2(r.end.x - 34.0 - G2.text_width(amt, asz), r.position.y + r.size.y * 0.70),
			amt, asz, P.hdr(P.mix(P.GOLD_HI, Color.WHITE, pulse * 0.4), 1.35 + pulse * 0.4),
			HORIZONTAL_ALIGNMENT_LEFT)

# ==================== 해전 램프 ====================

static func meter(ci: CanvasItem, L: Lay, g: Game, battle: Game.BattleRun, t: float) -> void:
	for i in 4:
		var r: Rect2 = L.tile[i]
		var c: Color = D.GRP_COLOR[i]
		var first := i * D.PHASES
		var last := first + D.PHASES - 1
		var active := battle != null and battle.tier >= first and battle.tier <= last
		var reached := battle != null and battle.max_tier >= first
		var pulse := 0.5 + 0.5 * sin(t * 2.2 + i * 0.7)
		var rad := r.size.y * 0.5

		G2.grad_round(ci, r, rad,
				P.mix(Color8(26, 22, 44), c, 0.22 + (0.30 if reached else 0.0)),
				P.mix(Color8(10, 9, 22), c, 0.06), 8)
		var glow := (1.0 if active else 0.30) * (0.55 + 0.45 * pulse)
		G2.stroke_round(ci, r, rad, P.hdr(c, 0.6 + glow * 1.4), 2.6 if active else 1.5)

		var lx := r.position.x + rad * 0.8
		ci.draw_circle(Vector2(lx, r.position.y + rad), rad * 0.34,
				P.hdr(c, 1.4 if reached else 0.45))
		G2.text_mid(ci, Vector2(lx, r.position.y + rad), str(i + 1), 12.0, P.INK)

		G2.text(ci, Vector2(r.position.x + rad * 1.5, r.position.y + rad + 5.0),
				D.GRP_NAME[i], 13.0,
				P.WHITE if reached else P.mix(P.DIM, c, 0.45), HORIZONTAL_ALIGNMENT_LEFT)

		for p in D.PHASES:
			var tier := first + p
			var done := battle != null and battle.max_tier >= tier
			var now := battle != null and battle.tier == tier
			var px := r.position.x + r.size.x * 0.44 + p * 10.0
			ci.draw_circle(Vector2(px, r.position.y + rad), 3.6 if now else 2.7,
					P.hdr(c, 1.6 if done else 0.3) if done else P.a(P.DIMMER, 0.35))

		var amt := P.n(D.tier_total(last) * g.total_bet())
		var fs: float = minf(19.0, r.size.y * 0.44)
		G2.text(ci, Vector2(r.end.x - 12.0 - G2.text_width(amt, fs), r.position.y + rad + 7.0),
				amt, fs, P.hdr(P.GOLD_HI, 1.2) if reached else P.mix(P.GOLD, P.DIMMER, 0.40),
				HORIZONTAL_ALIGNMENT_LEFT)

# ==================== 좌측 패널 ====================

static func panel(ci: CanvasItem, r: Rect2, trim: Color, glow: float) -> void:
	G2.grad_round(ci, r, 14.0, Color8(58, 30, 44), Color8(26, 14, 26), 8)
	G2.stroke_round(ci, r.grow(-3.0), 12.0, Color8(228, 232, 244), 2.2)
	var inner := r.grow(-7.0)
	G2.grad_round(ci, inner, 10.0, P.PANEL, P.VOID1, 8)
	G2.stroke_round(ci, inner, 10.0, P.hdr(trim, 0.8 + glow * 1.6), 1.6)


static func gauge(ci: CanvasItem, L: Lay, g: Game, disp_spirit: float, t: float) -> void:
	var r := L.gauge
	var frac: float = minf(1.0, disp_spirit / D.SPIRIT_MAX)
	var full := frac >= 0.999
	var c := P.GOLD_HI if full else P.mix(P.CRIMSON, P.GOLD, frac)
	var pulse := 0.5 + 0.5 * sin(t * (8.0 if full else 2.4))
	panel(ci, r, P.GOLD, (0.55 + 0.45 * pulse) if full else 0.25)

	var cp := L.chara
	G2.grad_round(ci, cp, 10.0, Color8(24, 20, 52), Color8(8, 8, 22), 8)
	G2.glow(ci, cp.position + cp.size * Vector2(0.5, 0.46), cp.size.x * 0.70, cp.size.y * 0.52,
			P.mix(P.VIOLET, c, frac), 0.40 + frac * 0.40)
	Art.admiral(ci, cp.position + cp.size * Vector2(0.5, 0.46),
			minf(cp.size.x * 0.44, cp.size.y * 0.34), t)
	G2.stroke_round(ci, cp, 10.0, P.a(P.GOLD, 0.8), 1.8)
	var np := Rect2(cp.position.x + 8.0, cp.end.y - 26.0, cp.size.x - 16.0, 20.0)
	G2.fill_round(ci, np, 6.0, P.a(Color8(10, 8, 22), 0.85))
	G2.stroke_round(ci, np, 6.0, P.a(P.GOLD, 0.6), 1.0)
	G2.text_mid(ci, np.position + np.size * 0.5, "李 舜 臣", 13.0, P.GOLD_HI)

	var gb := L.gauge_bar
	G2.text_mid(ci, Vector2(gb.position.x + gb.size.x * 0.5, gb.position.y + 10.0),
			"전 의 게 이 지", 11.0, P.a(P.DIM, 0.9))

	var bar := Rect2(gb.position.x + gb.size.x * 0.26, gb.position.y + 20.0,
			gb.size.x * 0.48, gb.size.y - 76.0)
	G2.fill_round(ci, bar, 8.0, Color8(8, 10, 24))
	for i in range(1, 12):
		var y := bar.end.y - bar.size.y * i / 12.0
		ci.draw_line(Vector2(bar.position.x + 4.0, y), Vector2(bar.end.x - 4.0, y),
				P.a(P.DIMMER, 0.30 if i % 3 == 0 else 0.14), 1.0)
	var fh := bar.size.y * frac
	if fh > 2.0:
		var fill := Rect2(bar.position.x, bar.end.y - fh, bar.size.x, fh)
		G2.grad_round(ci, fill, 8.0, P.hdr(P.lighten(c, 0.35), 1.5), P.hdr(c, 1.1), 8)
		for i in 5:
			var ph := fposmod(t * 0.55 + i * 0.2, 1.0)
			var y := fill.end.y - ph * fill.size.y
			if y >= fill.position.y:
				ci.draw_line(Vector2(fill.position.x + 3.0, y), Vector2(fill.end.x - 3.0, y),
						P.a(Color.WHITE, (1.0 - ph) * 0.34), 2.0)
	G2.stroke_round(ci, bar, 8.0, P.a(P.FRAME, 0.9), 1.6)

	for i in 5:
		var y := bar.end.y - bar.size.y * i / 4.0
		var on := frac >= i / 4.0 - 0.001
		for sx in [bar.position.x - 8.0, bar.end.x + 8.0]:
			ci.draw_circle(Vector2(sx, y), 3.2 if on else 2.2,
					P.hdr(c, 1.6) if on else P.a(P.DIMMER, 0.35))

	var pct := "확 정" if full else "%d%%" % int(frac * 100.0)
	G2.text_mid(ci, Vector2(gb.position.x + gb.size.x * 0.5, bar.end.y + 22.0), pct,
			19.0 if full else 21.0, P.hdr(P.GOLD_HI, 1.4) if full else P.WHITE)
	# 게이지가 스핀 수로 차므로 천장까지 몇 번 남았는지 그대로 붙여 준다.
	# 패널 아래가 좁아 줄을 늘리면 잘린다 — 한 줄에 담을 것.
	var sub := "다음 스핀 해전!" if full else "해전 %.1f%%  ·  %d스핀 내" % [
			g.jackpot_chance() * 100.0, g.spins_to_full()]
	G2.text_mid(ci, Vector2(gb.position.x + gb.size.x * 0.5, bar.end.y + 44.0), sub,
			11.0 if full else 10.0, P.hdr(P.CRIMSON, 1.3) if full else P.a(P.CYAN, 0.9))

# ==================== 릴 판 ====================

## 릴 판의 바깥쪽 — 슈라우드와 테두리. 릴 자체는 reels_clipped() 가 그린다.
static func board(ci: CanvasItem, L: Lay, _g: Game, res: Game.SpinResult, reels: Array,
		hot: bool, t: float) -> void:
	shroud(ci, L, hot, t)
	G2.stroke_round(ci, L.win.grow(5.0), 10.0, P.hdr(P.GOLD, 1.2), 2.5)

	var still := true
	for r in reels:
		if r.busy():
			still = false
	if res != null and still:
		_line_tabs(ci, L, res, t)


## 창 안쪽 — 좌표계 원점이 창의 왼쪽 위다 (clip_contents 를 켠 Control 안에서 그린다)
static func reels_clipped(ci: CanvasItem, L: Lay, res: Game.SpinResult, reels: Array,
		highlight: Array, win_cycle: int, t: float) -> void:
	var still := true
	for r in reels:
		if r.busy():
			still = false

	for i in D.REELS:
		_reel(ci, L, i, reels[i], highlight, still, t)

	for i in range(1, D.REELS):
		var x := i * L.cell.x
		ci.draw_line(Vector2(x, 0.0), Vector2(x, L.win.size.y), P.a(Color.BLACK, 0.55), 3.0)

	if res != null and still:
		_paylines(ci, L, res, win_cycle, t)


## 릴 창 둘레 — 큰 원은 캐비닛 쪽이 맡으므로 여기서는 모서리 문양과 창틀만 그린다.
static func shroud(ci: CanvasItem, L: Lay, hot: bool, t: float) -> void:
	var m := L.mid
	_corner(ci, L, m.position, Vector2(1, 1), t)
	_corner(ci, L, Vector2(m.end.x, m.position.y), Vector2(-1, 1), t)
	_corner(ci, L, Vector2(m.position.x, m.end.y), Vector2(1, -1), t)
	_corner(ci, L, m.end, Vector2(-1, -1), t)

	G2.grad_round(ci, L.win.grow(14.0), 22.0, Color8(14, 18, 40), Color8(6, 8, 22), 10)
	var col := P.hsv(fposmod(t * 90.0, 360.0), 0.85, 1.0) if hot else P.GOLD
	G2.stroke_round(ci, L.win.grow(11.0), 20.0, P.hdr(col, 1.0), 3.0)


static func _corner(ci: CanvasItem, L: Lay, o: Vector2, s: Vector2, t: float) -> void:
	var u: float = minf(L.mid.size.x, L.mid.size.y) * 0.44
	var band := [P.CRIMSON, P.GOLD, P.JADE, P.SEA2, P.VIOLET]
	for i in 7:
		var rr := u * (0.16 + i * 0.115)
		var pts := PackedVector2Array()
		for j in 13:
			var a: float = PI * 0.5 * j / 12.0
			pts.append(o + Vector2(cos(a) * rr * s.x, sin(a) * rr * s.y))
		ci.draw_polyline(pts, P.a(band[i % band.size()], maxf(0.05, 0.34 - i * 0.035)),
				u * 0.055, true)

	for i in 3:
		var k := u * (0.50 + i * 0.20)
		var pts := PackedVector2Array()
		for j in 11:
			var a: float = PI * 0.5 * j / 10.0
			var wob := sin(a * 7.0 + t * 0.7 + i * 1.3) * u * 0.045
			pts.append(o + Vector2(cos(a) * (k + wob) * s.x, sin(a) * (k + wob) * s.y))
		ci.draw_polyline(pts, P.a(P.mix(P.CYAN, P.GOLD_HI, i * 0.4), 0.26 - i * 0.05),
				2.6 - i * 0.5, true)

	var f := o + Vector2(u * 0.115 * s.x, u * 0.115 * s.y)
	for ring in 2:
		var petals := 8 if ring == 0 else 6
		var pr := u * (0.115 if ring == 0 else 0.062)
		var ps := u * (0.052 if ring == 0 else 0.038)
		for i in petals:
			var a := TAU * i / petals + t * 0.12 * (1.0 if ring == 0 else -1.0)
			ci.draw_circle(f + Vector2(cos(a), sin(a)) * pr, ps,
					P.a(P.GOLD if ring == 0 else P.GOLD_HI, 0.42 if ring == 0 else 0.55))
	ci.draw_circle(f, u * 0.048, P.a(P.CRIMSON, 0.60))
	ci.draw_circle(f, u * 0.022, P.a(P.GOLD_HI, 0.75))


static func _reel(ci: CanvasItem, L: Lay, r: int, rv: Reel, highlight: Array,
		still: bool, t: float) -> void:
	var base_idx := int(floor(rv.scroll))
	var frac := rv.scroll - base_idx
	var bounce := sin(rv.bounce * TAU * 1.2) * rv.bounce * L.cell.y * 0.045
	Art.fast = rv.blur > 0.25

	for k in range(-1, D.ROWS + 1):
		var idx := posmod(-base_idx + k, D.STRIP_LEN)
		var sym: int = D.strip[r][idx]
		var y := (k + frac) * L.cell.y + bounce
		if y > L.win.size.y + 4.0 or y + L.cell.y < -4.0:
			continue
		var cell := Rect2(r * L.cell.x, y, L.cell.x, L.cell.y)
		var hl := 0.0
		if still and k >= 0 and k < D.ROWS:
			hl = highlight[r][k]
		_cell(ci, cell, sym, r, hl, rv, still, t)

	Art.fast = false


static func _cell(ci: CanvasItem, cell: Rect2, sym: int, reel: int, hl: float,
		rv: Reel, still: bool, t: float) -> void:
	var c1: Color = D.SYM_C1[sym]
	var inner := cell.grow(-3.0)
	G2.grad_round(ci, inner, 8.0,
			P.mix(Color8(20, 26, 52), c1, 0.22), P.mix(Color8(11, 15, 34), c1, 0.10), 6)
	if hl > 0.01:
		G2.fill_round(ci, inner, 8.0, P.a(c1, hl * 0.22))
		G2.stroke_round(ci, inner, 8.0, P.hdr(P.GOLD_HI, 0.8 + hl * 1.8), 2.5)
	else:
		G2.stroke_round(ci, inner, 8.0, P.a(Color.BLACK, 0.35), 1.0)

	var mid := cell.position + cell.size * 0.5
	var size: float = minf(cell.size.x, cell.size.y) * 0.34
	if sym == D.SCAT:
		var gp := 0.55 + 0.45 * sin(t * 4.0 + reel)
		G2.glow(ci, mid, size * 1.7, size * 1.7, P.VIOLET, 0.30 + gp * 0.30, 5)
	elif sym == D.WILD:
		var gp2 := 0.55 + 0.45 * sin(t * 3.0 + reel * 0.6)
		G2.glow(ci, mid, size * 1.7, size * 1.7, P.GOLD, 0.24 + gp2 * 0.24, 5)

	if rv.blur > 0.02:
		for i in range(1, 3):
			var dy := rv.blur * cell.size.y * 0.16 * i
			ci.draw_circle(mid - Vector2(0, dy), size * 0.75, P.a(c1, 0.12 / i))
	var sc := 1.0 + hl * 0.14
	if sc != 1.0:
		ci.draw_set_transform(mid, 0.0, Vector2(sc, sc))
		Art.sym(ci, sym, Vector2.ZERO, size, t + reel * 0.4)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		Art.sym(ci, sym, mid, size, t + reel * 0.4)

	if still and sym == D.SCAT:
		G2.text_mid(ci, Vector2(mid.x, cell.end.y - 12.0), "총통",
				maxf(9.0, cell.size.x * 0.075), P.a(P.VIOLET, 0.9))


static func _paylines(ci: CanvasItem, L: Lay, res: Game.SpinResult, win_cycle: int, t: float) -> void:
	for i in res.wins.size():
		var w: Game.LineWin = res.wins[i]
		var focus := (win_cycle % maxi(1, res.wins.size())) == i
		var a := 1.0 if focus else (0.10 if res.wins.size() > 1 else 1.0)
		var path := PackedVector2Array()
		for r in w.count:
			path.append(L.cell_center(r, D.LINE[w.line][r]) - L.win.position)
		var pulse := 0.65 + 0.35 * sin(t * 6.0 + i)
		ci.draw_polyline(path, P.a(D.SYM_C1[w.sym], a * 0.35 * pulse), 11.0, true)
		ci.draw_polyline(path, P.a(P.hdr(P.GOLD_HI, 1.4), a * pulse), 3.2, true)
		for p in path:
			ci.draw_circle(p, 4.0, P.a(Color.WHITE, a * pulse))


static func _line_tabs(ci: CanvasItem, L: Lay, res: Game.SpinResult, _t: float) -> void:
	var y := L.win.end.y + 10.0
	var step: float = minf(30.0, L.win.size.x / 12.0)
	var x0 := L.win.position.x + L.win.size.x * 0.5 - step * 4.0
	for i in D.LINES:
		var on := false
		for w in res.wins:
			if w.line == i:
				on = true
		var p := Vector2(x0 + i * step, y)
		ci.draw_circle(p, 9.0, P.hdr(P.GOLD, 1.3) if on else P.a(P.PANEL, 0.9))
		G2.text_mid(ci, p, str(i + 1), 11.0, P.INK if on else P.a(P.DIMMER, 0.8))

# ==================== 우측 패널 ====================

static func side(ci: CanvasItem, L: Lay, g: Game, last_win: int, disp_win: float, t: float) -> void:
	var r := L.side
	var won := last_win > 0
	panel(ci, r, P.GOLD if won else P.CYAN, 0.45 if won else 0.18)
	var x := r.position.x + 12.0
	var w := r.size.x - 24.0

	var wr := Rect2(x, r.position.y + 14.0, w, 74.0)
	_lcd(ci, wr, P.GOLD if won else P.DIMMER)
	G2.text_mid(ci, Vector2(wr.position.x + wr.size.x * 0.5, wr.position.y + 16.0),
			"획   득", 11.0, P.a(P.DIM, 0.9))
	var wp := 1.0 + (0.07 * sin(t * 7.0) if won else 0.0)
	G2.text_mid(ci, Vector2(wr.position.x + wr.size.x * 0.5, wr.position.y + 50.0),
			P.n(disp_win) if won else "- - -", minf(28.0, w * 0.20) * wp,
			P.hdr(P.GOLD_HI, 1.3) if won else P.a(P.DIMMER, 0.8))

	var top := wr.end.y + 14.0
	G2.text_mid(ci, Vector2(x + w * 0.5, top + 6.0), "해 전 기 록", 11.0, P.a(P.DIM, 0.9))
	top += 20.0
	var row_h: float = maxf(30.0, (r.end.y - 112.0 - top) / 4.0)
	for i in 4:
		var cnt := g.group_reached(i)
		var any := cnt > 0
		var c: Color = D.GRP_COLOR[i]
		var box := Rect2(x, top + i * row_h, w, row_h - 6.0)
		G2.fill_round(ci, box, 6.0, P.a(c, 0.20 if any else 0.06))
		G2.stroke_round(ci, box, 6.0, P.a(c, 0.7 if any else 0.22), 1.3)
		ci.draw_circle(Vector2(box.position.x + 12.0, box.position.y + box.size.y * 0.5), 4.0,
				P.hdr(c, 1.4) if any else P.a(c, 0.3))
		G2.text(ci, Vector2(box.position.x + 22.0, box.position.y + box.size.y * 0.5 + 4.0),
				D.GRP_NAME[i], 11.0, P.WHITE if any else P.a(P.DIMMER, 0.85),
				HORIZONTAL_ALIGNMENT_LEFT)
		var cs := str(cnt)
		G2.text(ci, Vector2(box.end.x - 12.0 - G2.text_width(cs, 14.0),
				box.position.y + box.size.y * 0.5 + 5.0), cs, 14.0,
				c if any else P.a(P.DIMMER, 0.7), HORIZONTAL_ALIGNMENT_LEFT)

	var sy := r.end.y - 96.0
	ci.draw_line(Vector2(x, sy - 8.0), Vector2(r.end.x - 12.0, sy - 8.0), P.a(P.GOLD_DEEP, 0.45), 1.0)
	var keys := ["스핀", "해전", "최고 배당"]
	var vals := [P.n(g.spins), str(g.battle_total), P.n(g.best)]
	for i in 3:
		var y := sy + i * 28.0
		G2.text(ci, Vector2(x, y + 14.0), keys[i], 11.0, P.a(P.DIMMER, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		G2.text(ci, Vector2(r.end.x - 12.0 - G2.text_width(vals[i], 13.0), y + 14.0),
				vals[i], 13.0, P.WHITE, HORIZONTAL_ALIGNMENT_LEFT)


static func _lcd(ci: CanvasItem, r: Rect2, trim: Color) -> void:
	G2.grad_round(ci, r, 8.0, Color8(6, 10, 20), Color8(12, 18, 32), 6)
	G2.stroke_round(ci, r, 8.0, P.a(trim, 0.75), 1.6)
	var y := r.position.y + 2.0
	while y < r.end.y:
		ci.draw_line(Vector2(r.position.x + 2.0, y), Vector2(r.end.x - 2.0, y),
				P.a(Color.BLACK, 0.16), 1.0)
		y += 3.0

# ==================== 하단 조작대 ====================

static func bar(ci: CanvasItem, L: Lay, g: Game, disp_coins: float, phase: int,
		auto: bool, msg_right: float, t: float) -> void:
	var r := L.bar
	G2.grad_round(ci, r, 16.0, Color8(228, 232, 244), Color8(150, 154, 172), 8)
	G2.grad_round(ci, r.grow(-5.0), 13.0, Color8(196, 40, 50), Color8(118, 18, 30), 8)
	var inner := r.grow(-11.0)
	G2.grad_round(ci, inner, 10.0, Color8(26, 22, 42), Color8(12, 12, 26), 8)

	var h := inner.size.y - 20.0
	var y := inner.position.y + 10.0
	var k := L.ui_k

	var coin_r := Rect2(inner.position.x + 12.0, y, 236.0 * k, h)
	_lcd(ci, coin_r, P.GOLD)
	G2.text(ci, Vector2(coin_r.position.x + 10.0, coin_r.position.y + 20.0), "보유 코인",
			11.0, P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	Art.coin(ci, Vector2(coin_r.position.x + 22.0, coin_r.position.y + coin_r.size.y * 0.66),
			12.0 * k, t * 2.2, 1.0)
	G2.text(ci, Vector2(coin_r.position.x + 40.0 * k, coin_r.position.y + coin_r.size.y * 0.76),
			P.n(disp_coins), minf(27.0 * k, coin_r.size.y * 0.38), P.hdr(P.GOLD_HI, 1.2),
			HORIZONTAL_ALIGNMENT_LEFT)

	var bet_r := Rect2(coin_r.end.x + 10.0, y, 226.0 * k, h)
	_lcd(ci, bet_r, P.CYAN)
	G2.text(ci, Vector2(bet_r.position.x + 10.0, bet_r.position.y + 20.0),
			"배팅", 10.0, P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	# 보유 코인의 1/10 — 여기까지만 올라간다. 라벨과 겹치지 않게 오른쪽 끝에 붙인다.
	var cap := "상한 " + P.n(g.bet_cap())
	G2.text(ci, Vector2(bet_r.end.x - 10.0 - G2.text_width(cap, 10.0), bet_r.position.y + 20.0),
			cap, 10.0, P.a(P.ORANGE, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	var per := "%d × 9" % g.bet_per_line()
	var tot := "= " + P.n(g.total_bet())
	var bsz: float = minf(23.0 * k, bet_r.size.y * 0.34)
	var tsz: float = minf(18.0 * k, bet_r.size.y * 0.26)
	# 배팅이 커지면 글자가 상자를 넘는다 — 들어갈 때까지 같이 줄인다
	var avail := bet_r.size.x - 30.0
	var need := G2.text_width(per, bsz) + G2.text_width(tot, tsz)
	if need > avail and avail > 0.0:
		bsz *= avail / need
		tsz *= avail / need
	var by := bet_r.position.y + bet_r.size.y * 0.72
	G2.text(ci, Vector2(bet_r.position.x + 12.0, by), per, bsz, P.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	G2.text(ci, Vector2(bet_r.end.x - 12.0 - G2.text_width(tot, tsz), by),
			tot, tsz, P.CYAN, HORIZONTAL_ALIGNMENT_LEFT)

	var mw := msg_right - (bet_r.end.x + 12.0)
	if mw > 120.0:
		var msg_r := Rect2(bet_r.end.x + 12.0, y, mw, h)
		_lcd(ci, msg_r, P.VIOLET)
		var s1 := ""
		var s2 := ""
		if phase == 4:
			s1 = "GAME OVER"
			s2 = "아무 키나 눌러 다시 시작"
		elif phase == 1:
			s1 = "회전 중"
			s2 = "Space — 빨리 감기"
		elif auto:
			s1 = "자동 스핀"
			s2 = "A — 끄기"
		else:
			s1 = "핸들을 돌려라"
			s2 = "Space 또는 오른쪽 다이얼"
		var bl := 0.6 + 0.4 * sin(t * 3.0)
		G2.text_mid(ci, Vector2(msg_r.position.x + msg_r.size.x * 0.5, msg_r.position.y + 34.0),
				s1, minf(21.0, msg_r.size.y * 0.30), P.a(P.VIOLET, 0.75 + 0.25 * bl))
		G2.text_mid(ci, Vector2(msg_r.position.x + msg_r.size.x * 0.5, msg_r.position.y + 56.0),
				s2, 11.0, P.a(P.DIM, 0.9))

# ==================== 버튼 ====================

static func buttons(ci: CanvasItem, _L: Lay, list: Array, _phase: int, t: float) -> void:
	for b in list:
		if b["id"] == "restart":
			continue
		button(ci, b, t)


static func button(ci: CanvasItem, b: Dictionary, t: float) -> void:
	if b["hidden"]:
		return
	var r: Rect2 = b["rect"]
	if r.size.x <= 0.0:
		return
	if b.get("round", false):
		_dial(ci, b, t)
		return

	var c: Color = b["c"]
	var on: bool = b["enabled"]
	if not on:
		c = P.mix(c, P.VOID1, 0.68)
	var hov: float = b["hover"]
	G2.grad_round(ci, r, 12.0, P.lighten(c, 0.18 + hov * 0.16), P.darken(c, 0.30), 8)
	G2.stroke_round(ci, r, 12.0, P.a(P.lighten(c, 0.45), 0.9 if on else 0.35), 1.6)
	if b.get("toggle", false) and b.get("on", false):
		G2.stroke_round(ci, r.grow(-3.0), 10.0, P.hdr(P.GOLD_HI, 1.2), 2.4)

	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var ink := P.INK if lum > 0.62 else P.WHITE
	if not on:
		ink = P.a(P.DIM, 0.6)
	var sub: String = b["sub"]
	var ly := r.position.y + (r.size.y * 0.5 if sub.is_empty() else r.size.y * 0.38)
	G2.text_mid(ci, Vector2(r.position.x + r.size.x * 0.5, ly), b["label"],
			minf(r.size.y * (0.34 if sub.is_empty() else 0.30), 21.0), ink)
	if not sub.is_empty():
		G2.text_mid(ci, Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.76),
				sub, 11.0, P.a(ink, 0.75))


static func _dial(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var d: Rect2 = b["rect"]
	var c := d.position + d.size * 0.5
	var rad := d.size.x * 0.5
	var on: bool = b["enabled"]
	var pulse := 0.5 + 0.5 * sin(t * 3.4)
	var ring := P.CRIMSON if on else P.mix(P.CRIMSON, P.VOID1, 0.6)

	G2.grad_round(ci, d, rad, Color8(236, 238, 248), Color8(120, 124, 142), 10)
	G2.stroke(ci, G2.circle(c, rad - 1.0, 40), P.a(Color.BLACK, 0.35), 2.0)

	for i in 24:
		var a := i * PI / 12.0 + t * 0.12
		var lit: float = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(a * 3.0 - t * 2.0), 3.0)
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.84, 3.0,
				P.hdr(ring, 0.4 + lit * 2.0) if on else P.a(P.DIMMER, 0.3))

	var r3 := rad * 0.66
	G2.grad_round(ci, Rect2(c - Vector2(r3, r3), Vector2(r3 * 2, r3 * 2)), r3,
			P.lighten(ring, 0.30 + b["hover"] * 0.2), P.darken(ring, 0.42), 10)
	G2.stroke(ci, G2.circle(c, r3 - 1.0, 36), P.a(Color.WHITE, 0.35), 1.6)

	for i in 3:
		var a := TAU * i / 3.0 + t * (6.0 if false else 0.6)
		var p := c + Vector2(cos(a), sin(a)) * r3 * 0.52
		G2.fill_round(ci, Rect2(p - Vector2(4, 4), Vector2(8, 8)), 4.0,
				P.a(Color8(250, 250, 255), 0.9 if on else 0.35))

	G2.text_mid(ci, c - Vector2(0, rad * 0.06), "스핀", minf(20.0, rad * 0.34),
			P.hdr(Color.WHITE, 1.2) if on else P.a(P.DIM, 0.6))
	G2.text_mid(ci, c + Vector2(0, rad * 0.34), "Space", 10.0, P.a(Color.WHITE, 0.7 if on else 0.3))

# ==================== 알림 / 창 ====================

static func toast(ci: CanvasItem, L: Lay, s: String, c: Color, tt: float) -> void:
	var a: float = minf(1.0, tt * 2.5)
	var y := L.bar.position.y - 34.0
	var w := G2.text_width(s, 14.0) + 36.0
	var r := Rect2(L.w * 0.5 - w * 0.5, y - 17.0, w, 34.0)
	G2.fill_round(ci, r, 10.0, P.a(Color8(12, 14, 30), a * 0.92))
	G2.stroke_round(ci, r, 10.0, P.a(c, a * 0.8), 1.5)
	G2.text_mid(ci, Vector2(L.w * 0.5, y), s, 14.0, P.a(c, a))


static func bankrupt(ci: CanvasItem, L: Lay, g: Game, over_t: float, t: float) -> void:
	var a: float = minf(1.0, over_t * 1.4)
	ci.draw_rect(Rect2(0, 0, L.w, L.h), P.a(Color8(6, 8, 20), a * 0.88))
	var c := Vector2(L.w * 0.5, L.h * 0.5)
	G2.text_outline(ci, c - Vector2(0, 178.0), "코인이 바닥났다", 52.0,
			P.a(P.WHITE, a), P.a(P.CRIMSON_DEEP, a), 3.0)
	G2.text_mid(ci, c - Vector2(0, 124.0), "그러나 아직 열두 척이 남았다.", 17.0, P.a(P.GOLD, a))

	var keys := ["총 스핀", "총 배팅", "총 획득", "최고 배당", "해전"]
	var vals := [P.n(g.spins), P.n(g.wagered), P.n(g.won), P.n(g.best), "%d회" % g.battle_total]
	for i in keys.size():
		var y := c.y - 76.0 + i * 26.0
		G2.text(ci, Vector2(c.x - 20.0 - G2.text_width(keys[i], 14.0), y), keys[i], 14.0,
				P.a(P.DIM, a), HORIZONTAL_ALIGNMENT_LEFT, false)
		G2.text(ci, Vector2(c.x + 10.0, y), vals[i], 15.0, P.a(P.WHITE, a), HORIZONTAL_ALIGNMENT_LEFT)

	G2.text_mid(ci, c + Vector2(0, 84.0),
			"코인 %s 으로 처음부터 다시 시작합니다" % P.n(D.START_COINS), 14.0, P.a(P.DIM, a))
	G2.text_mid(ci, c + Vector2(0, 190.0), "아무 곳이나 클릭하거나 아무 키나 눌러도 됩니다",
			13.0, P.a(P.DIMMER, a * (0.6 + 0.4 * sin(t * 3.0))))


static func paytable(ci: CanvasItem, L: Lay, g: Game, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, L.w, L.h), P.a(Color8(5, 7, 18), 0.91))
	var w: float = minf(1000.0, L.w - 70.0)
	var h: float = minf(622.0, L.h - 60.0)
	var r := Rect2((L.w - w) * 0.5, (L.h - h) * 0.5, w, h)
	G2.grad_round(ci, r, 16.0, P.PANEL, P.VOID1, 10)
	G2.stroke_round(ci, r, 16.0, P.hdr(P.GOLD, 1.2), 2.0)

	var bet := g.bet_per_line()
	G2.text_mid(ci, Vector2(r.position.x + w * 0.5, r.position.y + 40.0), "배 당 표", 22.0, P.GOLD_HI)
	G2.text_mid(ci, Vector2(r.position.x + w * 0.5, r.position.y + 66.0),
			"라인 배팅 %d 기준 · 왼쪽 릴부터 이어져야 인정됩니다" % bet, 12.0, P.a(P.DIM, 0.9))

	var top := r.position.y + 90.0
	var col_w := (w - 60.0) * 0.5
	var row_h := 54.0
	for k in 9:
		var i := 8 - k
		var col := 0 if k < 5 else 1
		var row := k if k < 5 else k - 5
		var x := r.position.x + 30.0 + col * col_w
		var y := top + row * row_h
		var box := Rect2(x, y, col_w - 20.0, row_h - 8.0)
		G2.fill_round(ci, box, 8.0, P.a(D.SYM_C1[i], 0.10))
		G2.stroke_round(ci, box, 8.0, P.a(D.SYM_C1[i], 0.35), 1.2)
		Art.sym(ci, i, Vector2(x + 28.0, y + (row_h - 8.0) * 0.5), 18.0, t + i * 0.7)
		var wild := i == D.WILD
		G2.text(ci, Vector2(x + 62.0, y + (24.0 if wild else (row_h - 8.0) * 0.5 + 5.0)),
				D.SYM_NAME[i], 14.0, P.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		if wild:
			G2.text(ci, Vector2(x + 62.0, y + 40.0), "모든 심볼 대신", 10.0,
					P.a(P.GOLD, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		var txt := "%s   /   %s   /   %s" % [P.n(D.PAY[i][0] * bet), P.n(D.PAY[i][1] * bet),
				P.n(D.PAY[i][2] * bet)]
		G2.text(ci, Vector2(box.end.x - 12.0 - G2.text_width(txt, 14.0),
				y + (row_h - 8.0) * 0.5 + 5.0), txt, 14.0, P.GOLD_HI, HORIZONTAL_ALIGNMENT_LEFT)

	var by := top + 5 * row_h + 6.0
	var sr := Rect2(r.position.x + 30.0, by, w - 60.0, 66.0)
	G2.fill_round(ci, sr, 10.0, P.a(P.VIOLET, 0.14))
	G2.stroke_round(ci, sr, 10.0, P.a(P.VIOLET, 0.55), 1.5)
	Art.sym(ci, D.SCAT, Vector2(sr.position.x + 34.0, sr.position.y + 33.0), 22.0, t)
	G2.text(ci, Vector2(sr.position.x + 66.0, sr.position.y + 24.0),
			"천자총통 — 위치와 상관없이 개수로 지급", 14.0, P.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var tb := g.total_bet()
	G2.text(ci, Vector2(sr.position.x + 66.0, sr.position.y + 48.0),
			"3개 %s  ·  4개 %s  ·  5개 %s      3개 이상이면 해전 시작"
			% [P.n(D.SCATTER_PAY[3] * tb), P.n(D.SCATTER_PAY[4] * tb), P.n(D.SCATTER_PAY[5] * tb)],
			12.0, P.a(P.VIOLET, 0.95), HORIZONTAL_ALIGNMENT_LEFT)

	var hy := sr.end.y + 12.0
	G2.text(ci, Vector2(r.position.x + 30.0, hy + 14.0),
			"해전 4개 × 전반·중반·종반 = 12단계   —   총배팅 %s 기준" % P.n(tb),
			14.0, P.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	var tw2 := (w - 60.0 - 24.0) / 4.0
	for i in 4:
		var first := i * D.PHASES
		var tr := Rect2(r.position.x + 30.0 + i * (tw2 + 8.0), hy + 24.0, tw2, 78.0)
		G2.fill_round(ci, tr, 8.0, P.a(D.GRP_COLOR[i], 0.16))
		G2.stroke_round(ci, tr, 8.0, P.a(D.GRP_COLOR[i], 0.6), 1.4)
		G2.text_mid(ci, Vector2(tr.position.x + tr.size.x * 0.5, tr.position.y + 18.0),
				D.GRP_NAME[i], 13.0, P.WHITE)
		for p in D.PHASES:
			var pd := first + p
			G2.text(ci, Vector2(tr.position.x + 8.0, tr.position.y + 36.0 + p * 17.0),
					D.PHASE_NAME[p], 10.0, P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
			var amt := P.n(D.tier_total(pd) * tb)
			G2.text(ci, Vector2(tr.end.x - 8.0 - G2.text_width(amt, 10.0),
					tr.position.y + 36.0 + p * 17.0), amt, 10.0,
					P.GOLD_HI if p == D.PHASES - 1 else P.a(P.GOLD, 0.85),
					HORIZONTAL_ALIGNMENT_LEFT)
		var ships: int = D.PHASE_SHIPS[i][0] + D.PHASE_SHIPS[i][1] + D.PHASE_SHIPS[i][2]
		G2.text_mid(ci, Vector2(tr.position.x + tr.size.x * 0.5, tr.end.y - 11.0),
				"왜선 %d척" % ships, 10.0, P.a(P.DIMMER, 0.85))

	G2.text_mid(ci, Vector2(r.position.x + w * 0.5, r.end.y - 18.0),
			"아무 곳이나 누르면 닫힙니다", 12.0, P.a(P.DIMMER, 0.85))


static func help(ci: CanvasItem, L: Lay) -> void:
	ci.draw_rect(Rect2(0, 0, L.w, L.h), P.a(Color8(6, 8, 20), 0.89))
	var w: float = minf(900.0, L.w - 80.0)
	var h: float = minf(600.0, L.h - 80.0)
	var r := Rect2((L.w - w) * 0.5, (L.h - h) * 0.5, w, h)
	G2.grad_round(ci, r, 16.0, P.PANEL, P.VOID1, 10)
	G2.stroke_round(ci, r, 16.0, P.hdr(P.GOLD, 1.2), 2.0)
	G2.text_mid(ci, Vector2(r.position.x + w * 0.5, r.position.y + 42.0),
			"불멸의 이순신 — 유격 규칙", 22.0, P.GOLD_HI)

	var lines: Array[String] = [
		"◆  5릴 3행 · 9페이라인. 왼쪽 릴부터 이어진 같은 심볼 3개 이상이면 당첨입니다.",
		"◆  이순신은 와일드 — 천자총통을 뺀 모든 심볼을 대신합니다. 5개면 라인당 888배.",
		"◆  천자총통이 3개 이상 뜨면 해전이 시작됩니다. 위치는 상관없습니다.",
		"",
		"◆  전의 게이지 — 스핀할 때마다 왼쪽 게이지가 한 칸씩 찹니다.",
		"     찰수록 해전 발동 확률이 오르고, 가득 차면 다음 스핀에 반드시 터집니다.",
		"     배팅액은 게이지에 영향을 주지 않습니다 — 크게 건다고 해전이 빨리 오지는 않습니다.",
		"",
		"◆  해전은 4개, 각각 전반·중반·종반으로 나뉘어 모두 12단계입니다.",
		"     같은 해전 안에서는 78~92% 로 이어지고, 다음 해전으로 넘어가는 길목만 35~84% 입니다.",
		"     노량 종반까지 가면 총배팅의 97배. 해전 중에 버튼을 연타하면 보너스가 더 붙습니다.",
		"",
		"◆  배팅은 1-2-5 로 계속 올라가지만, 한 스핀에 거는 돈은",
		"     보유 코인의 1/10 을 넘을 수 없습니다. 크게 이겨야 위 단계가 열립니다.",
		"",
		"조작",
		"     Space / Enter      스핀",
		"     ← →  또는  ↑ ↓     배팅 조절",
		"     A / X              자동 스핀 / 최대 배팅",
		"     P                  배당표",
		"     H  또는  F1        이 도움말",
		"     Esc                종료",
	]
	var y := r.position.y + 80.0
	for s: String in lines:
		var head: bool = s.begins_with("◆") or s == "조작"
		var c := P.GOLD if head else (P.a(P.DIM, 0.95) if s.begins_with("     ") else P.WHITE)
		G2.text(ci, Vector2(r.position.x + 40.0, y), s, 14.0, c, HORIZONTAL_ALIGNMENT_LEFT, head)
		y += 10.0 if s.is_empty() else 24.0
