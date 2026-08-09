class_name Hud
extends RefCounted

## 화면 좌표계에 그리는 것들 — 상단 바, 보유 장비, 레벨업 카드, 결과 화면.

# ==================== 아이콘 ====================

## 스킬을 한눈에 구분할 작은 문양. 글자 대신 도형으로 그린다.
##
## **15종이 되면서 실루엣이 겹치기 쉬워졌다.** 직업마다 축을 나눠 뒀다 —
## 무사는 **닫힌 도형**(고리·육각·도끼), 마법사는 **덩어리와 원**(불덩이·룬), 궁수는
## **가늘고 긴 선**(화살·시위). 색까지 직업 색이라 두 겹으로 구분된다.
static func icon(ci: CanvasItem, kind: String, at: Vector2, s: float, col: Color) -> void:
	var c := P.hdr(col, 1.35)
	match kind:
		"whirl":
			# 회전 참격 — 한 바퀴 도는 초승달 + 칼끝
			ci.draw_arc(at, s * 0.86, -PI * 0.7, PI * 0.9, 22, c, s * 0.26, true)
			var tip := at + Vector2(cos(PI * 0.9), sin(PI * 0.9)) * s * 0.86
			ci.draw_circle(tip, s * 0.22, P.hdr(Color.WHITE, 1.6))
			ci.draw_line(at + Vector2(-s * 0.2, s * 0.2), at + Vector2(s * 0.55, -s * 0.55),
				P.a(c, 0.8), s * 0.16, true)
		"quake":
			# 대지 분쇄 — 퍼지는 두 겹 고리 + 균열
			ci.draw_arc(at, s * 0.92, 0.0, TAU, 26, c, s * 0.20, true)
			ci.draw_arc(at, s * 0.48, 0.0, TAU, 20, P.a(c, 0.6), s * 0.16, true)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				ci.draw_line(at + Vector2(cos(a), sin(a)) * s * 0.5,
					at + Vector2(cos(a), sin(a)) * s * 1.05, P.a(c, 0.7), s * 0.12, true)
		"guard":
			# 강철 방벽 — 육각 판
			var hex := PackedVector2Array()
			for i in 6:
				var a2 := TAU * i / 6.0 - PI * 0.5
				hex.append(at + Vector2(cos(a2), sin(a2)) * s * 0.95)
			G2.fill_fan(ci, hex, P.a(c, 0.30))
			G2.stroke(ci, hex, c, s * 0.20)
		"axe":
			# 투척 도끼 — 자루 + 양쪽 날
			ci.draw_line(at + Vector2(-s * 0.9, 0), at + Vector2(s * 0.9, 0), c, s * 0.20, true)
			for sg in [-1.0, 1.0]:
				G2.fill_fan(ci, PackedVector2Array([
					at + Vector2(s * 0.62 * sg, -s * 0.62),
					at + Vector2(s * 1.05 * sg, -s * 0.28),
					at + Vector2(s * 1.05 * sg, s * 0.28),
					at + Vector2(s * 0.62 * sg, s * 0.62),
				]), c)
		"fireball":
			# 화염구 — 덩어리 + 뒤로 끌리는 꼬리
			ci.draw_line(at + Vector2(-s, s * 0.4), at + Vector2(-s * 0.2, s * 0.06),
				P.a(c, 0.5), s * 0.40, true)
			ci.draw_circle(at + Vector2(s * 0.14, -s * 0.06), s * 0.66, c)
			ci.draw_circle(at + Vector2(s * 0.02, -s * 0.18), s * 0.28, P.hdr(P.GOLD_HI, 1.7))
		"ward":
			# 반사 결계 — 룬이 박힌 고리
			ci.draw_arc(at, s * 0.90, 0.0, TAU, 26, c, s * 0.18, true)
			for i in 6:
				var a3 := TAU * i / 6.0
				var q := at + Vector2(cos(a3), sin(a3)) * s * 0.90
				var tg := Vector2(-sin(a3), cos(a3))
				ci.draw_line(q - tg * s * 0.22, q + tg * s * 0.22, P.hdr(c, 1.3), s * 0.13, true)
		"frost":
			# 서리 창 — 곧은 창 + 서리 가지
			ci.draw_line(at + Vector2(-s * 0.95, s * 0.5), at + Vector2(s * 0.95, -s * 0.5),
				c, s * 0.20, true)
			for u in [0.25, 0.55]:
				var mid := Vector2(-s * 0.95, s * 0.5).lerp(Vector2(s * 0.95, -s * 0.5), u)
				ci.draw_line(at + mid + Vector2(-s * 0.22, -s * 0.30),
					at + mid + Vector2(s * 0.22, s * 0.30), P.a(c, 0.75), s * 0.10, true)
			ci.draw_circle(at + Vector2(s * 0.95, -s * 0.5), s * 0.20, P.hdr(Color.WHITE, 1.6))
		"snipe":
			# 관통 저격 — 긴 화살 + 조준 고리
			ci.draw_line(at + Vector2(-s, s * 0.5), at + Vector2(s * 0.7, -s * 0.35),
				c, s * 0.14, true)
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(s * 1.0, -s * 0.5), at + Vector2(s * 0.5, -s * 0.42),
				at + Vector2(s * 0.62, -s * 0.02),
			]), P.hdr(Color.WHITE, 1.5))
			ci.draw_arc(at + Vector2(s * 0.55, -s * 0.28), s * 0.5, 0.0, TAU, 18,
				P.a(c, 0.55), s * 0.08, true)
		"arrow":
			# 연사 화살 — 나란한 화살 셋
			for k in 3:
				var y := (float(k) - 1.0) * s * 0.52
				ci.draw_line(at + Vector2(-s, y), at + Vector2(s * 0.45, y), c, s * 0.12, true)
				G2.fill_fan(ci, PackedVector2Array([
					at + Vector2(s * 0.95, y), at + Vector2(s * 0.42, y - s * 0.22),
					at + Vector2(s * 0.42, y + s * 0.22),
				]), P.hdr(c, 1.2))
		"homing":
			# 유도 화살 — 휘어 들어가는 궤적
			var path := PackedVector2Array()
			for i in 12:
				var u2 := float(i) / 11.0
				path.append(at + Vector2(-s + 1.8 * s * u2, s * 0.6 - 1.4 * s * u2 * u2))
			ci.draw_polyline(path, c, s * 0.14, true)
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(s * 0.98, -s * 0.86), at + Vector2(s * 0.48, -s * 0.56),
				at + Vector2(s * 0.80, -s * 0.30),
			]), P.hdr(Color.WHITE, 1.5))
		"intercept":
			# 요격 사격 — 조준 십자 + 마주 오는 화살
			ci.draw_arc(at, s * 0.86, 0.0, TAU, 22, c, s * 0.14, true)
			ci.draw_line(at + Vector2(-s * 1.05, 0), at + Vector2(s * 1.05, 0), P.a(c, 0.8), s * 0.10)
			ci.draw_line(at + Vector2(0, -s * 1.05), at + Vector2(0, s * 1.05), P.a(c, 0.8), s * 0.10)
			ci.draw_circle(at, s * 0.22, P.hdr(Color.WHITE, 1.5))
		"hawk":
			# 사냥매 — 펼친 두 날개
			for sg2 in [-1.0, 1.0]:
				G2.fill_fan(ci, PackedVector2Array([
					at, at + Vector2(s * 1.05 * sg2, -s * 0.62),
					at + Vector2(s * 0.72 * sg2, -s * 0.06),
					at + Vector2(s * 0.30 * sg2, s * 0.34),
				]), c)
			ci.draw_circle(at + Vector2(0, s * 0.10), s * 0.22, P.hdr(Color.WHITE, 1.4))
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
		"flame":
			G2.fill_fan(ci, PackedVector2Array([
				at + Vector2(0, -s), at + Vector2(s * 0.62, s * 0.30),
				at + Vector2(0, s * 0.86), at + Vector2(-s * 0.62, s * 0.30),
			]), c)
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

	var mx := g.max_hp()
	var hf := clampf(g.hp / maxf(1.0, mx), 0.0, 1.0)
	var hb := Rect2(pad + 76, 28, 120, 15)
	G2.fill_round(ci, hb, 7.0, P.a(P.VOID0, 0.9))
	if hf > 0.001:
		G2.fill_round(ci, Rect2(hb.position, Vector2(hb.size.x * hf, hb.size.y)), 7.0,
			P.hdr(P.CRIMSON if hf < 0.35 else P.JADE, 1.25))
	G2.text(ci, Vector2(pad + 78, 63), "%d / %d" % [int(ceil(g.hp)), int(mx)],
		12.0, P.a(P.DIM, 0.95), HORIZONTAL_ALIGNMENT_LEFT, false)
	if g.revives > 0:
		G2.text(ci, Vector2(pad + 152, 63), "부활 %d" % g.revives, 12.0, P.GOLD)

	# 가운데 — 라운드와 남은 시간
	var left := g.round_left()
	var warn := left < 15.0
	G2.text_mid(ci, Vector2(w * 0.5, 34), "라운드 %d  ·  %s" % [g.round_no, String(g.map()["name"])],
		15.0, P.a(P.DIM, 0.95), false)
	G2.text_mid(ci, Vector2(w * 0.5, 66), D.mmss(left), 28.0,
		P.hdr(P.CRIMSON if warn else P.WHITE, 1.2 if warn else 1.0))

	# 우측 — 처치 수와 코인.
	# draw_string 의 정렬은 폭을 -1 로 주면 먹지 않는다. 직접 재서 왼쪽 좌표를 잡는다.
	var ks := "처치 %s" % P.n(g.kills)
	G2.text(ci, Vector2(w - pad - G2.text_w(ks, 18.0), 42), ks, 18.0, P.WHITE)
	var cs := "◈ %s" % P.n(Sv.coins)
	G2.text(ci, Vector2(w - pad - G2.text_w(cs, 17.0), 68), cs, 17.0, P.GOLD_HI)

# ==================== 미니맵 ====================

## 오른쪽 아래 구석에 맵 전체와 내 위치. 벽이 보여도 **지금 내가 어느 구석에 있는지**는
## 화면만 봐서 알 수 없어서 같이 둔다.
static func minimap(ci: CanvasItem, w: float, h: float, wd: World) -> void:
	if wd == null or wd.arena.x <= 0.0:
		return
	var box_w := 132.0
	var box := Rect2(w - box_w - 16.0, h - box_w * wd.arena.y / wd.arena.x - 16.0,
		box_w, box_w * wd.arena.y / wd.arena.x)
	G2.fill_round(ci, box, 6.0, P.a(P.VOID0, 0.72))
	G2.stroke_round(ci, box, 6.0, P.a(P.hdr(P.AZURE, 1.3), 0.75), 1.6)

	var k := box.size / wd.arena
	# 적은 점만, 8마리에 하나꼴. **전부 훑고 나머지를 버리지 말고 건너뛰며 읽는다** —
	# 800마리면 그 차이만으로 프레임당 0.7ms 다.
	for i in range(0, wd.enemies.size(), 8):
		var e: Dictionary = wd.enemies[i]
		var col: Color = P.CRIMSON if e["boss"] else P.a(P.DIM, 0.75)
		ci.draw_rect(Rect2(box.position + Vector2(e["p"]) * k - Vector2(1, 1), Vector2(2, 2)), col)
	var me := box.position + wd.pos * k
	ci.draw_circle(me, 3.4, P.hdr(P.HERO, 1.8))

# ==================== 보유 장비 ====================

static func loadout(ci: CanvasItem, w: float, h: float, g: Game) -> void:
	var s := 17.0
	var gap := 42.0
	var x := 18.0
	var y := h - 34.0

	var wkeys: Array = g.weapons.keys()
	wkeys.sort()
	for wid: int in wkeys:
		# **칸 색은 그 스킬이 어느 직업 것인가로 정한다.** 다른 직업 스킬을 다섯 칸 중
		# 몇 개나 들고 있는지가 화면에서 바로 읽혀야 진화 선택이 의미를 갖는다.
		# 진화한 것만 금색으로 덮어써 "끝난 칸"을 구분한다.
		var col: Color = P.GOLD if g.evolved(wid) else P.cls(int(D.WEAPON[wid]["cls"]))
		_slot(ci, Vector2(x, y), s, String(D.WEAPON[wid]["kind"]), col, g.weapons[wid])
		x += gap


static func _slot(ci: CanvasItem, at: Vector2, s: float, kind: String, col: Color, lv: int) -> void:
	var box := Rect2(at - Vector2(s + 3, s + 3), Vector2(s + 3, s + 3) * 2)
	G2.fill_round(ci, box, 8.0, P.a(P.PANEL, 0.9))
	G2.stroke_round(ci, box, 8.0, P.a(col, 0.85), 1.6)
	icon(ci, kind, at, s * 0.82, col)
	# 레벨 알갱이 — 진화면 금색 글자 하나로 갈음한다.
	# 진화 강화(7레벨 이상)는 알갱이 5개를 다시 그릴 자리가 없으므로 `+n` 으로 붙인다.
	if lv >= 6:
		var tag := "EVO" if lv <= 6 else "EVO+%d" % (lv - 6)
		G2.text_mid(ci, at + Vector2(0, s + 13), tag, 11.0, P.hdr(P.GOLD_HI, 1.4))
	else:
		for i in 5:
			ci.draw_circle(at + Vector2(-14.0 + i * 7.0, s + 9.0), 2.4,
				P.hdr(col, 1.4) if i < lv else P.a(P.DIMMER, 0.6))

# ==================== 레벨업 카드 ====================

## 카드 목록과 새로고침 버튼이 같은 y0/chh 를 써야 클릭 판정이 그림과 어긋나지 않는다.
static func reroll_rect(w: float, h: float) -> Rect2:
	var chh := minf(330.0, h * 0.48)
	var y0 := h * 0.34
	return Rect2(w * 0.5 - 118.0, y0 + chh + 22.0, 236.0, 44.0)


static func cards(ci: CanvasItem, w: float, h: float, list: Array, sel: int, t: float,
		anim: float, reroll_left: int) -> void:
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
		if int(card["id"]) >= 0:
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

	# 새로고침 버튼 — 카드 구성이 마음에 안 들면 다시 뽑는다. 판당 총 횟수가 정해져 있다.
	var rb := reroll_rect(w, h)
	var can_reroll := reroll_left > 0
	var rcol: Color = P.CYAN if can_reroll else P.DIMMER
	G2.fill_round(ci, rb, 10.0, P.a(P.PANEL, 0.92 if can_reroll else 0.55))
	G2.stroke_round(ci, rb, 10.0, P.a(rcol, 0.9 if can_reroll else 0.5), 1.6)
	_refresh_icon(ci, rb.position + Vector2(24.0, rb.size.y * 0.5), 10.0, rcol)
	G2.text_mid(ci, rb.get_center() + Vector2(12.0, 5.0),
		"새로고침 (R)  %d / %d" % [reroll_left, D.CARD_REROLL_MAX], 14.0, rcol, false)


## 원형 화살표 — 카드 새로고침 버튼용 아이콘
static func _refresh_icon(ci: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var a0 := -PI * 0.65
	var a1 := PI * 0.55
	ci.draw_arc(at, s, a0, a1, 16, col, s * 0.26, true)
	var tip := at + Vector2(cos(a1), sin(a1)) * s
	var tang := Vector2(-sin(a1), cos(a1))
	var norm := Vector2(cos(a1), sin(a1))
	G2.fill_fan(ci, PackedVector2Array([
		tip + tang * s * 0.46, tip - tang * s * 0.10 + norm * s * 0.40,
		tip - tang * s * 0.10 - norm * s * 0.40,
	]), col)


## 폭에 맞춰 줄을 나눠 가운데 정렬로 뿌린다.
##
## **다음 줄이 시작될 y 를 돌려준다.** 설명 글이 몇 줄이 될지는 창 폭에 따라 달라지므로,
## 뒤에 오는 것들의 자리를 상수로 박아 두면 좁은 창에서 반드시 겹친다
## (실제로 직업 선택창에서 설명이 스킬 문양을 덮었다). 이어서 그리는 쪽은 이 값을 받아 쓴다.
static func _wrap(ci: CanvasItem, s: String, at: Vector2, w: float, size: float,
		col: Color) -> float:
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
	return y + size + 6.0

# ==================== 화면 ====================

static func title(ci: CanvasItem, w: float, h: float, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.72))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.34), "좀 비 디 펜 스", 56.0,
		P.hdr(P.GOLD_HI, 1.3 + 0.15 * sin(t * 2.2)))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.34 + 44), "ZOMBIE DEFENSE", 16.0, P.a(P.VIOLET, 0.9), false)

	var lines := [
		"WASD / 방향키 로 이동  ·  공격은 자동입니다",
		"무사 · 마법사 · 궁수 — 직업마다 자기만 쓰는 고유 스킬이 있습니다",
		"레벨업마다 스킬을 하나씩 고르고, 5레벨에서 진화시키세요",
		"다른 직업 스킬도 몇몇은 내 직업에 맞는 형태로 진화합니다",
		"라운드를 버틸수록 적이 단단해집니다 — 클리어하면 코인으로 스텟을 올리세요",
	]
	var y := h * 0.55
	for s: String in lines:
		G2.text_mid(ci, Vector2(w * 0.5, y), s, 15.0, P.a(P.DIM, 0.95), false)
		y += 26.0

	y += 8.0
	G2.text_mid(ci, Vector2(w * 0.5, y), "보유 코인 ◈ %s   ·   최고 라운드 %d"
		% [P.n(Sv.coins), Sv.best_round], 15.0, P.a(P.GOLD, 0.95), false)

	var pulse := 0.6 + 0.4 * sin(t * 3.4)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.855), "Space 로 시작", 22.0, P.a(P.WHITE, pulse))

# ==================== 캐릭터 선택 ====================

## 카드 한 장의 자리. 그리기와 클릭 판정이 **같은 함수**를 봐야 어긋나지 않는다.
##
## 스킬 문양 줄과 고유 스킬 이름이 들어오면서 예전 높이(320)로는 설명 글과 겹쳤다.
## 지금은 카드 안의 요소를 **위에서 아래로 흘려** 놓고(`charsel`), 카드는 그 높이를
## 담을 만큼만 잡는다. 카드 아래로는 시작 라운드 버튼(`h * 0.885`)이 있으니 그 위에서 끝나야 한다.
static func char_rect(w: float, h: float, i: int) -> Rect2:
	var n := D.CHAR.size()
	var cw := minf(250.0, (w - 100.0) / maxi(1, n) - 20.0)
	var ch := minf(352.0, h * 0.54)
	var total := cw * n + 20.0 * (n - 1)
	return Rect2((w - total) * 0.5 + i * (cw + 20.0), h * 0.27, cw, ch)


## 시작 라운드를 바꾸는 네 칸. dir 은 바깥에서부터 -2(최저) -1(내리기) +1(올리기) +2(최고).
##
## **한 칸씩 누르는 버튼만 두면 안 된다.** 최고 라운드가 100 이면 100라운드로 가는 데
## 딸깍을 99번 해야 한다 — `⏮ ⏭` 로 양 끝까지 한 번에 간다.
static func round_btn_rect(w: float, h: float, dir: int) -> Rect2:
	var y := h * 0.885 - 17.0
	match dir:
		-2: return Rect2(w * 0.5 - 118.0, y, 38.0, 34.0)
		-1: return Rect2(w * 0.5 - 76.0, y, 38.0, 34.0)
		1:  return Rect2(w * 0.5 + 38.0, y, 38.0, 34.0)
		_:  return Rect2(w * 0.5 + 80.0, y, 38.0, 34.0)


static func charsel(ci: CanvasItem, w: float, h: float, sel: int, start_round: int,
		t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.86))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16), "직업 선택", 40.0, P.hdr(P.GOLD_HI, 1.4))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16 + 30),
		"← → 로 직업, ↑ ↓ 로 시작 라운드 (Home / End 로 양 끝), Enter 로 시작",
		14.0, P.a(P.DIM, 0.95), false)

	for i in D.CHAR.size():
		var ch: Dictionary = D.CHAR[i]
		var on := i == sel
		var r := char_rect(w, h, i)
		var col: Color = P.cls(int(ch["cls"]))
		if on:
			G2.glow(ci, r.get_center(), maxf(r.size.x, r.size.y) * 0.8, col, 0.28)
		G2.grad_round(ci, r, 16.0, P.a(P.PANEL_HI, 0.97), P.a(P.PANEL, 0.97), 8)
		G2.stroke_round(ci, r, 16.0, P.hdr(col, 1.5 if on else 0.9), 3.0 if on else 1.6)

		# **카드 안은 위에서 아래로 흘려 놓는다.** 자리를 상수로 박아 두면 설명 글이
		# 창 폭에 따라 2줄이 되기도 3줄이 되기도 해서 아래 것을 덮는다 — 실제로 그랬다.
		# `_wrap` 이 돌려주는 "다음 줄 y" 를 그대로 이어받는 것이 이 화면의 규칙이다.
		var cx := r.get_center().x

		# 직업 그림 — 실제 게임에서 쓰는 것과 같은 컷아웃을 세워 둔다
		var bob := sin(t * 2.4 + i) * 3.0 if on else 0.0
		Art.hero(ci, Vector2(cx, r.position.y + 96.0 + bob), Vector2.RIGHT, t, false, on, ch)

		var y := r.position.y + 164.0
		G2.text_mid(ci, Vector2(cx, y), String(ch["name"]), 22.0, P.WHITE)
		y += 26.0
		y = _wrap(ci, String(ch["desc"]), Vector2(cx, y), r.size.x - 34.0, 13.0,
			P.a(P.DIM, 0.95))

		# **이 직업에게 맞는 스킬 5종을 문양으로 늘어놓는다.** 직업을 고르는 것이 곧
		# 어떤 스킬을 자주 보게 되는가를 고르는 것이라, 그 5개가 화면에 없으면
		# 이름과 체력만 보고 고르는 셈이 된다. 고유 스킬(맨 앞)만 고리로 표시한다.
		var skills := D.class_skills(int(ch["cls"]))
		y += 18.0
		var sgap := minf(30.0, (r.size.x - 40.0) / maxi(1, skills.size()))
		var sx := cx - sgap * (skills.size() - 1) * 0.5
		var uw := int(ch["weapon"])
		for k in skills.size():
			var sw: int = skills[k]
			var sat := Vector2(sx + k * sgap, y)
			if sw == uw:
				ci.draw_circle(sat, 12.5, P.a(col, 0.22))
				ci.draw_arc(sat, 12.5, 0.0, TAU, 18, P.a(P.hdr(col, 1.4), 0.9), 1.6, true)
			icon(ci, String(D.WEAPON[sw]["kind"]), sat, 8.0, col)

		y += 30.0
		G2.text_mid(ci, Vector2(cx, y),
			"고유 %s  ·  이 5종 +%d%%"
			% [String(D.WEAPON[uw]["name"]), int(D.CLASS_BONUS * 100.0)],
			12.0, P.a(col, 0.95), false)

		# 체력·이동은 **한 줄**로 묶는다. 두 줄로 두면 설명이 길어졌을 때 카드 밖으로 밀린다.
		y += 24.0
		G2.text(ci, Vector2(r.position.x + 18, y), "체력", 13.0, P.a(P.DIMMER, 0.95),
			HORIZONTAL_ALIGNMENT_LEFT, false)
		var hv := "%d" % int(float(ch["hp"]) * (1.0 + Sv.bonus("hp")))
		G2.text(ci, Vector2(cx - 12.0 - G2.text_w(hv, 13.0), y), hv, 13.0, P.a(col, 0.95))
		G2.text(ci, Vector2(cx + 14.0, y), "이동", 13.0, P.a(P.DIMMER, 0.95),
			HORIZONTAL_ALIGNMENT_LEFT, false)
		var sv := "%d" % int(float(ch["spd"]))
		G2.text(ci, Vector2(r.end.x - 18 - G2.text_w(sv, 13.0), y), sv, 13.0, P.a(col, 0.95))

		G2.text_mid(ci, Vector2(cx, r.end.y - 10), "%d" % (i + 1), 14.0,
			P.hdr(col, 1.4) if on else P.a(P.DIMMER, 0.9))

	# 시작 라운드 — **도달해 본 라운드까지만** 고를 수 있다
	var can_up := start_round < Sv.best_round
	var can_dn := start_round > 1
	var glyph := { -2: "⏮", -1: "▼", 1: "▲", 2: "⏭" }
	for dir in [-2, -1, 1, 2]:
		var rb := round_btn_rect(w, h, dir)
		var on := can_up if dir > 0 else can_dn
		G2.fill_round(ci, rb, 8.0, P.a(P.PANEL, 0.92 if on else 0.5))
		G2.stroke_round(ci, rb, 8.0, P.a(P.CYAN if on else P.DIMMER, 0.85), 1.6)
		G2.text_mid(ci, rb.get_center() + Vector2(0, 6), String(glyph[dir]), 15.0,
			P.hdr(P.CYAN, 1.3) if on else P.a(P.DIMMER, 0.9))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.885 + 7), "%d" % start_round, 24.0, P.hdr(P.GOLD_HI, 1.3))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.885 - 26),
		"시작 라운드   (최고 %d)" % Sv.best_round, 13.0, P.a(P.DIM, 0.95), false)

	G2.text_mid(ci, Vector2(w * 0.5, h * 0.955), "보유 코인 ◈ %s" % P.n(Sv.coins),
		16.0, P.GOLD_HI)

# ==================== 라운드 클리어 · 코인 상점 ====================

static func shop_rect(w: float, h: float, i: int) -> Rect2:
	var n := D.SHOP.size()
	var cw := minf(190.0, (w - 90.0) / maxi(1, n) - 12.0)
	var total := cw * n + 12.0 * (n - 1)
	return Rect2((w - total) * 0.5 + i * (cw + 12.0), h * 0.46, cw, 150.0)


static func next_round_rect(w: float, h: float) -> Rect2:
	return Rect2(w * 0.5 - 140.0, h * 0.46 + 176.0, 280.0, 48.0)


static func round_clear(ci: CanvasItem, w: float, h: float, g: Game, gained: int,
		swept: int, sel: int, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.88))
	var pop := G2.out_back(clampf(t * 2.6, 0.0, 1.0))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16), "라운드 %d 클리어" % (g.round_no - 1),
		40.0 * (0.7 + 0.3 * pop), P.hdr(P.GOLD_HI, 1.4))
	if swept > 0:
		G2.text_mid(ci, Vector2(w * 0.5, h * 0.16 + 30),
			"남은 젬 회수  +%s 경험치" % P.n(swept), 15.0, P.a(P.XP, 0.95), false)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16 + 56),
		"코인 +%s   ·   보유 ◈ %s" % [P.n(gained), P.n(Sv.coins)], 18.0, P.GOLD)
	# **밸런스를 맞추려면 실제로 낸 화력을 봐야 한다.** 책상 계산은 광역기가 무리 속에서
	# 몇 마리를 때리는지 셀 수가 없어서 늘 과소평가된다. 죽었을 때만 보여 주던 값을
	# 클리어 화면에도 올린다 — 이겼을 때의 수치가 정작 필요한 쪽이다.
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16 + 82),
		"최고 초당 피해 %s   ·   처치 %s"
		% [P.n(int(g.best_dps)), P.n(g.kills)], 14.0, P.a(P.CYAN, 0.95), false)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.16 + 104),
		"다음은 %d라운드 · %s — 적이 더 단단하고 더 많이 옵니다"
		% [g.round_no, String(g.map()["name"])], 14.0, P.a(P.DIM, 0.95), false)

	G2.text_mid(ci, Vector2(w * 0.5, h * 0.46 - 16), "기본 스텟 강화 (판이 끝나도 남습니다)",
		14.0, P.a(P.DIMMER, 0.95), false)

	for i in D.SHOP.size():
		var row: Dictionary = D.SHOP[i]
		var r := shop_rect(w, h, i)
		var lv := Sv.level(i)
		var maxed := Sv.maxed(i)
		var cost := Sv.cost(i)
		var afford := not maxed and Sv.coins >= cost
		var on := i == sel
		var col: Color = P.GOLD if maxed else (P.CYAN if afford else P.DIMMER)

		G2.grad_round(ci, r, 12.0, P.a(P.PANEL_HI, 0.96), P.a(P.PANEL, 0.96), 6)
		G2.stroke_round(ci, r, 12.0, P.hdr(col, 1.4 if on else 0.85), 2.6 if on else 1.4)

		G2.text_mid(ci, Vector2(r.get_center().x, r.position.y + 30), String(row["name"]),
			16.0, P.WHITE)
		_wrap(ci, String(row["desc"]), Vector2(r.get_center().x, r.position.y + 54),
			r.size.x - 22.0, 12.0, P.a(P.DIM, 0.95))

		# 레벨 — **알갱이로 그리지 않는다.** 만렙이 100 이라 알갱이 100개는 그릴 수도,
		# 읽을 수도 없다. 숫자와 채워지는 막대로 보여 준다.
		var mx := int(row["max"])
		G2.text_mid(ci, Vector2(r.get_center().x, r.position.y + 92.0),
			"Lv. %d / %d" % [lv, mx], 14.0, P.a(col, 0.95))
		var bar := Rect2(r.position.x + 16.0, r.position.y + 100.0, r.size.x - 32.0, 5.0)
		G2.fill_round(ci, bar, 2.5, P.a(P.VOID0, 0.9))
		if lv > 0:
			G2.fill_round(ci, Rect2(bar.position,
				Vector2(bar.size.x * (float(lv) / float(maxi(1, mx))), bar.size.y)),
				2.5, P.hdr(col, 1.3))

		var label := "최대" if maxed else "◈ %s" % P.n(cost)
		G2.text_mid(ci, Vector2(r.get_center().x, r.end.y - 18), label, 16.0,
			P.hdr(col, 1.3) if afford or maxed else P.a(P.DIMMER, 0.9))
		G2.text_mid(ci, Vector2(r.position.x + 14, r.position.y + 16), "%d" % (i + 1), 12.0,
			P.a(P.DIMMER, 0.9), false)

	var nb := next_round_rect(w, h)
	var pulse := 0.7 + 0.3 * sin(t * 3.4)
	G2.fill_round(ci, nb, 10.0, P.a(P.PANEL, 0.95))
	G2.stroke_round(ci, nb, 10.0, P.a(P.hdr(P.JADE, 1.4), pulse), 2.2)
	G2.text_mid(ci, nb.get_center() + Vector2(0, 6), "다음 라운드 (Space)", 18.0,
		P.a(P.WHITE, pulse))
	G2.text_mid(ci, Vector2(w * 0.5, nb.end.y + 26),
		"숫자키 또는 클릭으로 구입  ·  Esc 로 판 끝내기", 13.0, P.a(P.DIMMER, 0.95), false)


static func result(ci: CanvasItem, w: float, h: float, g: Game, t: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.86))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.24), "작 전 실 패", 48.0, P.hdr(P.CRIMSON, 1.3))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.24 + 34),
		"%d라운드에서 쓰러졌습니다  ·  최고 %d라운드" % [g.round_no, Sv.best_round],
		16.0, P.a(P.DIM, 0.95), false)

	var rows := [
		["캐릭터", String(g.chr()["name"])],
		["처치", P.n(g.kills)],
		["누적 피해", P.n(int(g.dealt))],
		["최고 초당 피해", P.n(int(g.best_dps))],
		["도달 레벨", "Lv.%d" % g.level],
		["번 코인", "◈ %s" % P.n(g.earned)],
	]
	var y := h * 0.44
	for row: Array in rows:
		G2.text(ci, Vector2(w * 0.5 - 150, y), String(row[0]), 16.0, P.a(P.DIM, 0.95),
			HORIZONTAL_ALIGNMENT_LEFT, false)
		var rv := String(row[1])
		G2.text(ci, Vector2(w * 0.5 + 150 - G2.text_w(rv, 18.0), y), rv, 18.0,
			P.GOLD_HI if String(row[0]) == "번 코인" else P.WHITE)
		y += 30.0

	var pulse := 0.55 + 0.45 * sin(t * 3.2)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.87), "Space 로 다시  ·  Esc 로 처음 화면", 18.0,
		P.a(P.WHITE, pulse))


static func paused(ci: CanvasItem, w: float, h: float) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), P.a(P.VOID0, 0.62))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.46), "일 시 정 지", 40.0, P.WHITE)
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.46 + 40), "Esc 로 계속", 16.0, P.a(P.DIM, 0.95), false)
