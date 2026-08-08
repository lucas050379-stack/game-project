class_name Hud
extends RefCounted

## 화면 좌표계에 그리는 것들 — 상단 바, 보유 장비, 레벨업 카드, 결과 화면.

# ==================== 아이콘 ====================

## 무기/보조 장비를 한눈에 구분할 작은 문양. 글자 대신 도형으로 그린다.
static func icon(ci: CanvasItem, kind: String, at: Vector2, s: float, col: Color) -> void:
	var c := P.hdr(col, 1.35)
	match kind:
		"kunai":
			var pts := PackedVector2Array()
			for i in 4:
				var a := PI * 0.5 * i
				pts.append(at + Vector2(cos(a), sin(a)) * s)
				pts.append(at + Vector2(cos(a + PI * 0.25), sin(a + PI * 0.25)) * s * 0.34)
			G2.fill_fan(ci, pts, c)
		"bolt":
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(s * 0.22, -s), at + Vector2(-s * 0.42, s * 0.10),
				at + Vector2(-s * 0.02, s * 0.10), at + Vector2(-s * 0.22, s),
				at + Vector2(s * 0.46, -s * 0.14), at + Vector2(s * 0.06, -s * 0.14),
			]), c)
		"chain":
			ci.draw_arc(at, s * 0.86, 0.0, TAU, 22, c, 2.4, true)
			ci.draw_circle(at + Vector2(s * 0.86, 0), s * 0.30, c)
			ci.draw_circle(at - Vector2(s * 0.86, 0), s * 0.30, c)
		"field":
			ci.draw_arc(at, s * 0.92, 0.0, TAU, 26, c, 2.6, true)
			ci.draw_arc(at, s * 0.52, 0.0, TAU, 20, P.a(c, 0.6), 2.0, true)
		"laser":
			ci.draw_line(at + Vector2(-s, s * 0.5), at + Vector2(s, -s * 0.5), c, 4.0, true)
			ci.draw_circle(at + Vector2(s, -s * 0.5), s * 0.26, P.hdr(Color.WHITE, 1.6))
		"drone":
			ci.draw_circle(at, s * 0.52, c)
			ci.draw_line(at + Vector2(-s, -s * 0.5), at + Vector2(-s * 0.4, -s * 0.5), c, 2.2)
			ci.draw_line(at + Vector2(s * 0.4, -s * 0.5), at + Vector2(s, -s * 0.5), c, 2.2)
		"molotov":
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(0, -s), at + Vector2(s * 0.62, s * 0.30),
				at + Vector2(0, s * 0.86), at + Vector2(-s * 0.62, s * 0.30),
			]), c)
		"missile":
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(0, -s), at + Vector2(s * 0.40, s * 0.24),
				at + Vector2(0, s * 0.02), at + Vector2(-s * 0.40, s * 0.24),
			]), c)
			ci.draw_line(at + Vector2(0, s * 0.20), at + Vector2(0, s), P.a(P.ORANGE, 0.8), 3.0, true)
		"cube":
			G2.fill_round(ci, Rect2(at - Vector2(s, s) * 0.72, Vector2(s, s) * 1.44), s * 0.24, c)
		"boost":
			for i in 3:
				ci.draw_line(at + Vector2(-s, -s * 0.5 + i * s * 0.5),
					at + Vector2(s * 0.6, -s * 0.5 + i * s * 0.5), c, 2.6, true)
		"magnet":
			ci.draw_arc(at + Vector2(0, s * 0.3), s * 0.78, PI, TAU, 18, c, 4.0, true)
			ci.draw_line(at + Vector2(-s * 0.78, s * 0.3), at + Vector2(-s * 0.78, s * 0.86), P.CRIMSON, 4.0)
			ci.draw_line(at + Vector2(s * 0.78, s * 0.3), at + Vector2(s * 0.78, s * 0.86), P.WHITE, 4.0)
		"vest":
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(-s * 0.8, -s * 0.7), at + Vector2(s * 0.8, -s * 0.7),
				at + Vector2(s * 0.6, s * 0.4), at + Vector2(0, s), at + Vector2(-s * 0.6, s * 0.4),
			]), c)
		"core":
			ci.draw_arc(at, s * 0.85, -PI * 0.5, PI * 1.1, 20, c, 3.0, true)
			ci.draw_line(at, at + Vector2(0, -s * 0.62), c, 2.6)
		"kit":
			G2.fill_round(ci, Rect2(at - Vector2(s, s * 0.78), Vector2(s * 2, s * 1.56)), s * 0.24, c)
			ci.draw_line(at + Vector2(-s * 0.44, 0), at + Vector2(s * 0.44, 0), P.CRIMSON, 3.4)
			ci.draw_line(at + Vector2(0, -s * 0.44), at + Vector2(0, s * 0.44), P.CRIMSON, 3.4)
		"mag":
			G2.fill_round(ci, Rect2(at - Vector2(s * 0.5, s), Vector2(s, s * 2)), s * 0.2, c)
			for i in 3:
				ci.draw_line(at + Vector2(-s * 0.5, -s * 0.5 + i * s * 0.5),
					at + Vector2(s * 0.5, -s * 0.5 + i * s * 0.5), P.a(P.LINE, 0.7), 2.0)
		"scope":
			ci.draw_arc(at, s * 0.8, 0.0, TAU, 22, c, 2.4, true)
			ci.draw_line(at + Vector2(-s, 0), at + Vector2(s, 0), c, 1.8)
			ci.draw_line(at + Vector2(0, -s), at + Vector2(0, s), c, 1.8)
		_:
			ci.draw_circle(at, s * 0.7, c)

# ==================== 상단 바 ====================

static func bar(ci: CanvasItem, w: float, h: float, g: Game, t: float) -> void:
	# 경험치 — 화면 맨 위를 가로지른다
	var xf := clampf(float(g.xp) / maxf(1.0, float(g.xp_next)), 0.0, 1.0)
	ci.draw_rect(Rect2(0, 0, w, 12), P.a(P.VOID0, 0.85))
	ci.draw_rect(Rect2(0, 0, w * xf, 12), P.hdr(P.JADE, 1.35))
	ci.draw_rect(Rect2(0, 11, w, 1.4), P.a(P.WHITE, 0.20))

	# 좌측 — 레벨과 체력
	var pad := 14.0
	G2.fill_round(ci, Rect2(pad, 20, 208, 54), 10.0, P.a(P.PANEL, 0.88))
	G2.text(ci, Vector2(pad + 12, 44), "Lv.%d" % g.level, 21.0, P.GOLD_HI)

	var hf := clampf(g.hp / maxf(1.0, g.max_hp()), 0.0, 1.0)
	var hb := Rect2(pad + 76, 28, 120, 15)
	G2.fill_round(ci, hb, 7.0, P.a(P.VOID0, 0.9))
	if hf > 0.001:
		G2.fill_round(ci, Rect2(hb.position, Vector2(hb.size.x * hf, hb.size.y)), 7.0,
			P.hdr(P.CRIMSON if hf < 0.35 else P.JADE, 1.25))
	G2.text(ci, Vector2(pad + 78, 63), "%d / %d" % [int(ceil(g.hp)), int(g.max_hp())],
		12.0, P.a(P.DIM, 0.95), HORIZONTAL_ALIGNMENT_LEFT, false)
	if g.revives > 0:
		G2.text(ci, Vector2(pad + 152, 63), "부활 %d" % g.revives, 12.0, P.GOLD)

	# 가운데 — 남은 시간
	var left := maxf(0.0, D.STAGE_TIME - g.time)
	var warn := left < 60.0
	G2.text_mid(ci, Vector2(w * 0.5, 44), D.mmss(left), 30.0,
		P.hdr(P.CRIMSON if warn else P.WHITE, 1.2 if warn else 1.0))

	# 우측 — 처치 수.
	# draw_string 의 정렬은 폭을 -1 로 주면 먹지 않는다. 직접 재서 왼쪽 좌표를 잡는다.
	var ks := "처치 %s" % P.n(g.kills)
	G2.text(ci, Vector2(w - pad - G2.text_w(ks, 18.0), 42), ks, 18.0, P.WHITE)

# ==================== 보유 장비 ====================

static func loadout(ci: CanvasItem, w: float, h: float, g: Game) -> void:
	var s := 17.0
	var gap := 42.0
	var x := 18.0
	var y := h - 34.0

	var wkeys: Array = g.weapons.keys()
	wkeys.sort()
	for wid: int in wkeys:
		_slot(ci, Vector2(x, y), s, String(D.WEAPON[wid]["kind"]),
			P.GOLD if g.evolved(wid) else P.CRIMSON, g.weapons[wid])
		x += gap

	x += 14.0
	var skeys: Array = g.supports.keys()
	skeys.sort()
	for sid: int in skeys:
		_slot(ci, Vector2(x, y), s, String(D.SUPPORT[sid]["kind"]), P.CYAN, g.supports[sid])
		x += gap


static func _slot(ci: CanvasItem, at: Vector2, s: float, kind: String, col: Color, lv: int) -> void:
	var box := Rect2(at - Vector2(s + 3, s + 3), Vector2(s + 3, s + 3) * 2)
	G2.fill_round(ci, box, 8.0, P.a(P.PANEL, 0.9))
	G2.stroke_round(ci, box, 8.0, P.a(col, 0.85), 1.6)
	icon(ci, kind, at, s * 0.82, col)
	# 레벨 알갱이 — 진화면 금색 하나로 갈음한다
	if lv >= 6:
		G2.text_mid(ci, at + Vector2(0, s + 13), "EVO", 11.0, P.hdr(P.GOLD_HI, 1.4))
	else:
		for i in 5:
			ci.draw_circle(at + Vector2(-14.0 + i * 7.0, s + 9.0), 2.4,
				P.hdr(col, 1.4) if i < lv else P.a(P.DIMMER, 0.6))

# ==================== 레벨업 카드 ====================

static func cards(ci: CanvasItem, w: float, h: float, list: Array, sel: int, t: float,
		anim: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.80 * anim))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.20), "LEVEL UP", 40.0, P.hdr(P.GOLD_HI, 1.5))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.20 + 32), "하나를 고르세요   ( 1 · 2 · 3 또는 ← → + Enter )",
		14.0, P.a(P.DIM, 0.95), false)

	var n := list.size()
	var cw := minf(268.0, (w - 80.0) / maxi(1, n) - 18.0)
	var chh := minf(330.0, h * 0.48)
	var total := cw * n + 18.0 * (n - 1)
	var x0 := (w - total) * 0.5
	var y0 := h * 0.34

	for i in n:
		var card: Dictionary = list[i]
		var on := i == sel
		var pop := 1.0 + (0.05 if on else 0.0) + (1.0 - anim) * 0.12
		var cx := x0 + i * (cw + 18.0) + cw * 0.5
		var r := Rect2(cx - cw * 0.5 * pop, y0 - (chh * (pop - 1.0)) * 0.5, cw * pop, chh * pop)
		var col: Color = card["col"]

		if on:
			G2.glow(ci, r.get_center(), maxf(r.size.x, r.size.y) * 0.85, col, 0.30)
		G2.grad_round(ci, r, 16.0, P.a(P.PANEL_HI, 0.97), P.a(P.PANEL, 0.97), 8)
		G2.stroke_round(ci, r, 16.0, P.hdr(col, 1.5 if on else 0.9), 3.0 if on else 1.6)

		var kind := ""
		if String(card["type"]) == "support":
			kind = String(D.SUPPORT[int(card["id"])]["kind"])
		elif int(card["id"]) >= 0:
			kind = String(D.WEAPON[int(card["id"])]["kind"])
		var icy := r.position.y + 62.0
		if not kind.is_empty():
			G2.glow(ci, Vector2(cx, icy), 46.0, col, 0.22)
			icon(ci, kind, Vector2(cx, icy), 26.0, col)

		G2.text_mid(ci, Vector2(cx, r.position.y + 132), String(card["sub"]), 13.0, P.a(col, 0.95))
		G2.text_mid(ci, Vector2(cx, r.position.y + 164), String(card["title"]), 21.0, P.WHITE)
		_wrap(ci, String(card["desc"]), Vector2(cx, r.position.y + 202), cw - 34.0, 13.0,
			P.a(P.DIM, 0.95))

		G2.text_mid(ci, Vector2(cx, r.end.y - 18), "%d" % (i + 1), 15.0,
			P.hdr(col, 1.4) if on else P.a(P.DIMMER, 0.9))


## 폭에 맞춰 줄을 나눠 가운데 정렬로 뿌린다
static func _wrap(ci: CanvasItem, s: String, at: Vector2, w: float, size: float, col: Color) -> void:
	var words := s.split(" ")
	var line := ""
	var y := at.y
	for word: String in words:
		var probe := word if line.is_empty() else line + " " + word
		if G2.text_w(probe, size, false) > w and not line.is_empty():
			G2.text_mid(ci, Vector2(at.x, y), line, size, col, false)
			y += size + 6.0
			line = word
		else:
			line = probe
	if not line.is_empty():
		G2.text_mid(ci, Vector2(at.x, y), line, size, col, false)

# ==================== 화면 ====================

static func title(ci: CanvasItem, w: float, h: float, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.72))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.34), "좀 비 디 펜 스", 56.0,
		P.hdr(P.GOLD_HI, 1.3 + 0.15 * sin(t * 2.2)))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.34 + 44), "ZOMBIE DEFENSE", 16.0, P.a(P.VIOLET, 0.9), false)

	var lines := [
		"WASD / 방향키 로 이동  ·  공격은 자동입니다",
		"적을 잡아 경험치를 모으고, 레벨업마다 무기를 하나씩 고르세요",
		"무기를 5레벨까지 올리고 짝이 되는 장비를 3레벨로 맞추면 진화합니다",
		"15분을 버티면 승리 — 2분마다 보스가 옵니다",
	]
	var y := h * 0.55
	for s: String in lines:
		G2.text_mid(ci, Vector2(w * 0.5, y), s, 15.0, P.a(P.DIM, 0.95), false)
		y += 26.0

	var pulse := 0.6 + 0.4 * sin(t * 3.4)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.855), "Space 로 시작", 22.0, P.a(P.WHITE, pulse))


static func result(ci: CanvasItem, w: float, h: float, g: Game, won: bool, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.86))
	var col: Color = P.GOLD_HI if won else P.CRIMSON
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.27), "작 전 성 공" if won else "작 전 실 패", 48.0,
		P.hdr(col, 1.3))

	var rows := [
		["버틴 시간", D.mmss(g.time)],
		["처치", P.n(g.kills)],
		["누적 피해", P.n(int(g.dealt))],
		["최고 초당 피해", P.n(int(g.best_dps))],
		["도달 레벨", "Lv.%d" % g.level],
	]
	var y := h * 0.42
	for row: Array in rows:
		G2.text(ci, Vector2(w * 0.5 - 150, y), String(row[0]), 16.0, P.a(P.DIM, 0.95),
			HORIZONTAL_ALIGNMENT_LEFT, false)
		var rv := String(row[1])
		G2.text(ci, Vector2(w * 0.5 + 150 - G2.text_w(rv, 18.0), y), rv, 18.0, P.WHITE)
		y += 32.0

	var pulse := 0.55 + 0.45 * sin(t * 3.2)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.85), "Space 로 다시  ·  Esc 로 처음 화면", 18.0,
		P.a(P.WHITE, pulse))


static func paused(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.62))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.46), "일 시 정 지", 40.0, P.WHITE)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.46 + 40), "Esc 로 계속", 16.0, P.a(P.DIM, 0.95), false)
