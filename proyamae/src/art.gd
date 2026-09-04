extends Node
# 푸야매 — 그리기. 오토로드(`Art`)입니다.
#
# **노드를 만들지 마세요.** 카드는 전부 `_draw()` 한 곳에서 그립니다.
# 도감에는 수천 장이 깔리므로 카드 한 장의 그리기 호출 수가 곧 프레임입니다.
# 둥근 것은 `draw_circle` 로 그립니다 — 다각형 채우기는 호출마다 그리기 명령이
# 따로 생겨 배칭이 끊깁니다.

var font: Font = ThemeDB.fallback_font
var fsize := ThemeDB.fallback_font_size

func _ready() -> void:
	font = ThemeDB.fallback_font

# ── 글자 ───────────────────────────────────────────────────────────────────

func txt(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	ci.draw_string(font, pos, s, align, width, size, col)

func txt_w(s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# ── 상자 ───────────────────────────────────────────────────────────────────

func panel(ci: CanvasItem, r: Rect2, fill: Color, edge: Color = P.LINE, w: float = 1.0) -> void:
	ci.draw_rect(r, fill, true)
	if w > 0.0:
		ci.draw_rect(r, edge, false, w)

# ── 카드 ───────────────────────────────────────────────────────────────────
# 첨부한 푸야매 카드와 같은 차례입니다:
#   구단명 · 등급 → 그림 → 이름과 시즌 → 6스텟 막대 → COST 와 별
#
# 카드 비율은 세로로 깁니다. 가로 폭만 주면 높이가 따라옵니다.
# 세로 예산: 여백 + 머리글 + 그림 + 이름 + 6스텟 + COST = 약 1.51w.
# **비율을 줄이면 COST 별이 정신력 막대를 덮습니다**(실제로 그랬습니다).
# 스텟을 늘리거나 글자를 키웠으면 여기도 같이 키우세요.
const CARD_RATIO := 1.56

func card_size(w: float) -> Vector2:
	return Vector2(w, w * CARD_RATIO)

# 카드 안 사진 자리. **그리기와 클릭 판정이 같이 봅니다** — 자리를 두 곳에서
# 따로 계산하면 한쪽만 고쳤을 때 조용히 어긋납니다.
func card_photo_rect(at: Vector2, w: float) -> Rect2:
	var pad := w * 0.05
	var hs := int(w * 0.082)
	return Rect2(at.x + pad, at.y + pad + hs * 1.5, w - pad * 2.0, w * 0.44)

# `color_add` 는 지금 켜 둔 팀컬러가 더해 주는 값이고, `show_up` 이 켜지면
# 스텟 옆에 **(+N)** 을 적습니다. 카드의 `up`(유학·블록·구종)과 합쳐서 보여 주되,
# **99 에서 잘린 몫은 빼고 실제로 오른 만큼만** 적습니다 — 안 그러면 옆에 적힌
# 숫자와 안 맞아서 보너스가 거짓말이 됩니다.
func card(ci: CanvasItem, at: Vector2, w: float, c: Dictionary, sel: bool = false,
		color_add: int = 0, show_up: bool = false) -> void:
	if c.is_empty():
		return
	var sz := card_size(w)
	var r := Rect2(at, sz)
	var gc: Color = P.grade(str(c.get("grade", "NORMAL")))
	var tc: Color = P.team(str(c.get("team", "")))

	# 바탕 — 구단 색을 아주 어둡게 깔아 소속이 한눈에 읽히게 합니다.
	ci.draw_rect(r, P.PANEL, true)
	ci.draw_rect(Rect2(at, Vector2(sz.x, sz.y * 0.52)), tc.darkened(0.55), true)

	# 위에서 아래로 흘려 놓습니다. 자리를 상수로 박아 두면 글자 크기를 조금만
	# 바꿔도 아래 것이 덮입니다.
	var pad := w * 0.05
	var y := at.y + pad

	# 머리글 — 구단명과 등급
	var hs := int(w * 0.082)
	txt(ci, Vector2(at.x + pad, y + hs), str(c.get("team", "")), hs, P.a(P.TEXT, 0.92))
	# **NORMAL 은 아무 표기도 하지 않습니다.** 대부분이 NORMAL 이라 붙여 봐야
	# 정보가 아니라 소음이고, EX 가 눈에 안 띕니다.
	var gtext := str(c.get("grade", ""))
	if D.show_grade(gtext):
		var gw := txt_w(gtext, hs)
		var gr := Rect2(at.x + sz.x - pad - gw - pad * 0.7, y + hs * 0.12, gw + pad * 1.4, hs * 1.2)
		ci.draw_rect(gr, P.hdr(gc, 1.15), true)
		txt(ci, Vector2(gr.position.x + pad * 0.7, y + hs), gtext, hs, Color(0.06, 0.06, 0.09))
	y += hs * 1.5

	# 그림 자리 — 실제 사진이 있으면 사진을, 없으면 벡터로 그립니다.
	var pic := card_photo_rect(at, w)
	if not _photo(ci, pic, c):
		_figure(ci, pic, str(c.get("kind", "hitter")), tc)
	y += pic.size.y + w * 0.05

	# 이름과 시즌 — 시즌 표기가 카드의 정체성입니다(`03'`).
	var ns := int(w * 0.105)
	var pos_s := str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", ""))))
	txt(ci, Vector2(at.x + pad, y + ns), "%s %s" % [pos_s, str(c.get("name", ""))], ns, P.TEXT)
	var tag := DB.year_tag(c)
	txt(ci, Vector2(at.x + sz.x - pad - txt_w(tag, ns), y + ns), tag, ns, P.hdr(gc, 1.2))
	y += ns * 1.25
	ci.draw_line(Vector2(at.x + pad, y), Vector2(at.x + sz.x - pad, y), P.LINE, 1.0)
	y += w * 0.035

	# 6스텟
	var keys: Array = D.stats_of(str(c.get("kind", "hitter")))
	var st: Dictionary = c.get("st", {})
	var rowh := w * 0.088
	var ss := int(w * 0.070)
	var lw := w * 0.235
	var numw := w * 0.13
	var ups: Dictionary = c.get("up", {})
	for k in keys:
		var base := int(st.get(k, 50))
		var v := clampi(base + color_add, 1, D.STAT_MAX)
		var add := int(ups.get(k, 0)) + (v - base)
		txt(ci, Vector2(at.x + pad, y + ss), str(D.ST_NAME.get(k, k)), ss, P.TEXT_DIM)
		var bx := at.x + pad + lw
		var bw := sz.x - pad * 2.0 - lw - numw
		var bh := rowh * 0.40
		var by := y + ss * 0.5 - bh * 0.5
		ci.draw_rect(Rect2(bx, by, bw, bh), P.BAR_BG, true)
		# 막대는 **천장(130) 기준**입니다 — 99 로 나누면 보너스 받은 카드의 막대가
		# 칸 밖으로 삐져나갑니다.
		# **키운 몫은 막대에서도 다른 색입니다.** 타고난 값까지는 원래 색, 그 위로
		# 늘어난 구간은 `P.UP`(자홍) — 글자의 `(+N)` 과 같은 색이라 짝이 읽힙니다.
		var base_v := maxi(v - add, 0) if show_up else v
		ci.draw_rect(Rect2(bx, by, bw * (float(base_v) / float(D.STAT_MAX)), bh),
			P.bar(base_v), true)
		if show_up and add > 0:
			var x0 := bx + bw * (float(base_v) / float(D.STAT_MAX))
			var x1 := bx + bw * (float(v) / float(D.STAT_MAX))
			ci.draw_rect(Rect2(x0, by, maxf(x1 - x0, 1.0), bh), P.UP, true)
		# 숫자는 `105 (+13)` 꼴 — 첨부한 원작 카드와 같은 표기입니다.
		var num := str(v)
		var up_tag := "(+%d)" % add if (show_up and add > 0) else ""
		var ts := int(ss * 0.78)
		var tagw := (txt_w(up_tag, ts) + 4.0) if up_tag != "" else 0.0
		txt(ci, Vector2(at.x + sz.x - pad - tagw - txt_w(num, ss), y + ss), num, ss, P.TEXT)
		if up_tag != "":
			txt(ci, Vector2(at.x + sz.x - pad - txt_w(up_tag, ts), y + ss), up_tag, ts, P.UP)
		y += rowh

	# COST — 별의 개수가 곧 COST 입니다. 카드 **아래에 붙여** 놓습니다.
	var cost := int(c.get("cost", 1))
	var cy := at.y + sz.y - pad
	txt(ci, Vector2(at.x + pad, cy), "COST", ss, P.TEXT_FAINT)
	var srad := w * 0.024
	_stars(ci, Vector2(at.x + pad + txt_w("COST ", ss), cy - ss * 0.35), srad, cost)
	txt(ci, Vector2(at.x + sz.x - pad - txt_w(str(cost), ss), cy), str(cost), ss, P.hdr(gc, 1.2))

	# 테두리 — 등급이 높을수록 굵습니다. 색만으로는 도감에서 안 갈립니다.
	var bwid := 1.0 + D.grade_rank(str(c.get("grade", "NORMAL"))) * 1.8
	ci.draw_rect(r, P.hdr(gc, 1.25 if sel else 1.0), false, bwid + (1.5 if sel else 0.0))
	# 고코스트 표시 — 작은 카드와 **같은 규칙**이라야 목록에서 큰 화면으로 넘어갈 때
	# 눈이 헷갈리지 않습니다.
	if int(c.get("cost", 1)) >= D.COST_HIGH:
		ci.draw_rect(r.grow(-3.0), P.a(_cost_edge(int(c.get("cost", 1))), 0.95), false, 2.5)

# ── 작은 카드 ──────────────────────────────────────────────────────────────
# 첨부한 오더창의 그 칸입니다 — 사진 · `87' 한영준` · `3루수 ★8` 만 보여 줍니다.
# **목록에는 스텟 막대를 그리지 마세요.** 여섯 줄이 수백 장 깔리면 어느 카드가
# 센지 오히려 안 읽히고, 그리기 호출도 카드당 스무 번씩 듭니다.
# 자세한 것은 눌렀을 때 큰 화면(`Art.card`)에서 봅니다.
const MINI_RATIO := 1.32

func small_size(w: float) -> Vector2:
	return Vector2(w, w * MINI_RATIO)

func small_card(ci: CanvasItem, at: Vector2, w: float, c: Dictionary, sel: bool = false,
		h: float = -1.0, dim: bool = false) -> void:
	# `dim` = 안 가진 카드. **사진까지 회색으로** 깔아야 한눈에 갈립니다 —
	# 테두리만 흐리게 하면 수백 장이 깔린 도감에서 전혀 안 보입니다.
	if c.is_empty():
		return
	var sz := small_size(w)
	if h > 0.0:
		sz.y = h   # 오더 칸처럼 높이가 정해진 자리에서는 그 높이를 그대로 씁니다.
	var r := Rect2(at, sz)
	var gc: Color = P.grade(str(c.get("grade", "NORMAL")))
	var tc: Color = P.team(str(c.get("team", "")))

	# **아래에서부터 자리를 잡습니다.** 사진 높이를 비율로 박아 두면 칸 높이가
	# 조금만 달라져도 이름줄이 아래 띠에 깔립니다(실제로 그랬습니다).
	var bs2 := int(w * 0.135)
	var barh := bs2 + 6.0
	var ns := int(w * 0.155)
	var namerow := ns + 5.0

	ci.draw_rect(r, P.PANEL, true)
	var pic := Rect2(at.x + 2.0, at.y + 2.0, sz.x - 4.0, maxf(sz.y - 4.0 - barh - namerow, 8.0))
	ci.draw_rect(pic, tc.darkened(0.55), true)
	if not _photo(ci, pic, c):
		_figure(ci, pic, str(c.get("kind", "hitter")), tc)

	# EX 만 오른쪽 위에 작은 표를 답니다.
	if D.show_grade(str(c.get("grade", ""))):
		var bs := int(w * 0.15)
		var bw := txt_w("EX", bs) + 6.0
		ci.draw_rect(Rect2(at.x + sz.x - bw - 2.0, at.y + 2.0, bw, bs + 3.0), P.hdr(gc, 1.15), true)
		txt(ci, Vector2(at.x + sz.x - bw + 1.0, at.y + bs + 3.0), "EX", bs, Color(0.06, 0.06, 0.09))

	var y := pic.position.y + pic.size.y + ns + 1.0
	txt(ci, Vector2(at.x + 4.0, y), "%s %s" % [DB.year_tag(c), str(c.get("name", ""))], ns, P.TEXT)

	# 아래 줄 — 포지션과 COST.
	var by := at.y + sz.y - 5.0
	ci.draw_rect(Rect2(at.x + 1.0, by - bs2 - 3.0, sz.x - 2.0, bs2 + 6.0), tc.darkened(0.35), true)
	txt(ci, Vector2(at.x + 4.0, by), str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", "")))), bs2, P.TEXT)
	var cost := str(int(c.get("cost", 1)))
	txt(ci, Vector2(at.x + sz.x - 5.0 - txt_w(cost, bs2), by), cost, bs2, P.hdr(P.BAR_HIGH, 1.2))
	ci.draw_circle(Vector2(at.x + sz.x - 9.0 - txt_w(cost, bs2), by - bs2 * 0.35), w * 0.028, P.hdr(P.BAR_HIGH, 1.3))

	var bwid := 1.0 + D.grade_rank(str(c.get("grade", "NORMAL"))) * 1.6
	ci.draw_rect(r, P.hdr(gc, 1.3) if sel else P.a(gc, 0.7), false, bwid + (1.5 if sel else 0.0))
	# **고코스트 카드는 테두리를 한 겹 더 두릅니다.** 7코부터 스텟이 눈에 띄게
	# 뛰므로, 목록에서 그 경계가 바로 읽혀야 합니다.
	if int(c.get("cost", 1)) >= D.COST_HIGH:
		ci.draw_rect(r.grow(-2.0), P.a(_cost_edge(int(c.get("cost", 1))), 0.95), false, 2.0)
	if dim:
		# 다 그린 위에 어두운 막을 한 겹 덮습니다. 카드마다 색을 따로 만들면
		# 그리기 호출이 배로 늘고, 도감은 화면에 수백 장이 깔립니다.
		ci.draw_rect(r, P.a(Color(0.04, 0.05, 0.08), 0.72), true)
		ci.draw_rect(r, P.a(P.LINE, 0.75), false, 1.0)

# 고코스트 테두리 색. **등급 색(EX)과 겹치면 안 됩니다** — 등급은 노란 띠라,
# 여기는 위로 갈수록 뜨거워지는 쪽으로 나눕니다.
func _cost_edge(cost: int) -> Color:
	if cost >= 10:
		return P.hdr(P.BAR_TOP, 1.35)
	if cost >= 9:
		return P.hdr(P.BAR_HIGH, 1.25)
	if cost >= 8:
		return P.hdr(P.BAR_MID, 1.2)
	return P.a(P.BAR_MID, 0.85)

func _stars(ci: CanvasItem, at: Vector2, rad: float, n: int) -> void:
	# 별 열 개를 다각형으로 그리면 카드 한 장에 그리기 명령이 열 개 더 붙습니다.
	# 작은 원으로 대신합니다 — 이 크기에서는 어차피 점으로 보입니다.
	for i in range(10):
		var c := P.hdr(P.BAR_HIGH, 1.3) if i < n else P.a(P.LINE, 0.8)
		ci.draw_circle(at + Vector2(rad * 2.2 * i + rad, 0.0), rad, c)

# ── 선수 그림 ──────────────────────────────────────────────────────────────
# 사진이 없으므로 벡터로 그립니다. 타자와 투수의 **실루엣이 달라야** 합니다 —
# 도감을 넘길 때 색만 다르면 다 한 덩어리로 보입니다.

func _photo(ci: CanvasItem, r: Rect2, c: Dictionary) -> bool:
	# KBO 선수 사진은 94×118 세로 사진입니다. **가로로 늘리지 마세요** —
	# 자리에 맞춰 늘리면 얼굴이 다 뭉개집니다. 높이에 맞춰 비율을 지키고
	# 가운데에 놓습니다.
	var t = Spr.tex(c)
	if t == null:
		return false
	var ts: Vector2 = t.get_size()
	if ts.y <= 0.0:
		return false
	var h := r.size.y
	var w := h * ts.x / ts.y
	if w > r.size.x:
		w = r.size.x
		h = w * ts.y / ts.x
	ci.draw_texture_rect(t, Rect2(r.position.x + (r.size.x - w) * 0.5,
		r.position.y + (r.size.y - h) * 0.5, w, h), false)
	return true

func _figure(ci: CanvasItem, r: Rect2, kind: String, tc: Color) -> void:
	var cx := r.position.x + r.size.x * 0.5
	var by := r.position.y + r.size.y            # 발치
	var h := r.size.y
	var body := P.hdr(tc, 1.35)
	var dark := tc.darkened(0.35)
	var head_r := h * 0.135

	if kind == "pitcher":
		# 투수 — 다리를 들고 팔을 뒤로 뺀 자세. 세로로 곧게 섭니다.
		var hip := Vector2(cx, by - h * 0.40)
		var sh := Vector2(cx, by - h * 0.66)
		ci.draw_line(hip, sh, body, h * 0.115)
		ci.draw_line(hip, Vector2(cx - h * 0.16, by), dark, h * 0.075)      # 디딤발
		ci.draw_line(hip, Vector2(cx + h * 0.20, by - h * 0.30), dark, h * 0.075)  # 든 다리
		ci.draw_line(sh, Vector2(cx - h * 0.26, by - h * 0.80), body, h * 0.065)   # 던지는 팔
		ci.draw_line(sh, Vector2(cx + h * 0.20, by - h * 0.56), body, h * 0.060)   # 글러브 팔
		ci.draw_circle(Vector2(cx - h * 0.30, by - h * 0.86), h * 0.055, P.hdr(P.TEXT, 1.1))
		ci.draw_circle(Vector2(cx, by - h * 0.66 - head_r * 1.05), head_r, P.hdr(tc, 1.5))
	else:
		# 타자 — 배트를 세워 든 자세. 어깨가 열려 있어 투수와 확실히 갈립니다.
		var hip := Vector2(cx - h * 0.03, by - h * 0.40)
		var sh := Vector2(cx - h * 0.03, by - h * 0.66)
		ci.draw_line(hip, sh, body, h * 0.115)
		ci.draw_line(hip, Vector2(cx - h * 0.22, by), dark, h * 0.075)
		ci.draw_line(hip, Vector2(cx + h * 0.19, by), dark, h * 0.075)
		var grip := Vector2(cx + h * 0.16, by - h * 0.62)
		ci.draw_line(sh, grip, body, h * 0.060)
		ci.draw_line(sh + Vector2(0.0, h * 0.03), grip, body, h * 0.055)
		ci.draw_line(grip, grip + Vector2(h * 0.16, -h * 0.44), P.hdr(P.BAR_HIGH, 1.15), h * 0.048)
		ci.draw_circle(Vector2(cx - h * 0.03, by - h * 0.66 - head_r * 1.05), head_r, P.hdr(tc, 1.5))

# ── 오더 칸 ────────────────────────────────────────────────────────────────
# 첨부한 오더 입력창의 칸 하나에 해당합니다. 비어 있으면 점선 자리만 보입니다.

func slot(ci: CanvasItem, r: Rect2, c: Dictionary, label: String, sel: bool) -> void:
	# 칸 이름(1번 · 선발1)이 위에 붙는 것만 빼면 작은 카드와 같습니다.
	var lh := r.size.y * 0.16
	var ls := int(lh * 0.82)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, lh)), P.PANEL_HI if sel else P.PANEL, true)
	txt(ci, r.position + Vector2(4, lh * 0.82), label, ls, P.hdr(P.BAR_MID, 1.2) if sel else P.TEXT_FAINT)

	var inner := Rect2(r.position.x, r.position.y + lh, r.size.x, r.size.y - lh)
	if c.is_empty():
		ci.draw_rect(inner, P.PANEL, true)
		ci.draw_rect(inner, P.hdr(P.BAR_MID, 1.2) if sel else P.LINE, false, 2.0 if sel else 1.0)
		var e := "선수입력"
		txt(ci, Vector2(inner.position.x + inner.size.x * 0.5 - txt_w(e, ls) * 0.5,
			inner.position.y + inner.size.y * 0.55), e, ls, P.TEXT_FAINT)
		return
	small_card(ci, inner.position, inner.size.x, c, sel, inner.size.y)

# ── 목록용 한 줄 ───────────────────────────────────────────────────────────

func row(ci: CanvasItem, r: Rect2, c: Dictionary, sel: bool) -> void:
	var gc: Color = P.grade(str(c.get("grade", "NORMAL")))
	ci.draw_rect(r, P.PANEL_HI if sel else P.PANEL, true)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.012, r.size.y)), P.hdr(gc, 1.2), true)
	var s := int(r.size.y * 0.44)
	var y := r.position.y + r.size.y * 0.66
	var x := r.position.x + r.size.x * 0.035
	txt(ci, Vector2(x, y), DB.year_tag(c), s, P.TEXT_FAINT)
	txt(ci, Vector2(x + r.size.x * 0.09, y), str(c.get("name", "")), s, P.TEXT)
	txt(ci, Vector2(x + r.size.x * 0.34, y), str(c.get("team", "")), s, P.TEXT_DIM)
	txt(ci, Vector2(x + r.size.x * 0.48, y), str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", "")))), s, P.TEXT_DIM)
	if D.show_grade(str(c.get("grade", ""))):
		txt(ci, Vector2(x + r.size.x * 0.60, y), str(c.get("grade", "")), s, P.hdr(gc, 1.1))
	# **JSON 에서 읽은 수는 float 입니다.** 그대로 쓰면 `10.0` 으로 나오고
	# 옆 칸과 겹칩니다.
	var ov := str(int(c.get("ov", 0)))
	var cost := str(int(c.get("cost", 1)))
	txt(ci, Vector2(r.position.x + r.size.x * 0.88 - txt_w(ov, s), y), ov, s, P.TEXT)
	txt(ci, Vector2(r.position.x + r.size.x * 0.98 - txt_w(cost, s), y), cost, s, P.hdr(P.BAR_HIGH, 1.1))

# ── 카드 뒷면 ──────────────────────────────────────────────────────────────
# 첨부한 푸야매 카드의 오른쪽 면입니다 — 투수는 구종 방사도, 타자는 수비 위치,
# 그리고 둘 다 4×4 스킬블록 판을 답니다.

# 스킬블록 조각의 색. 판에 조각이 여럿 놓이므로 **조각마다 색이 달라야**
# 어디까지가 한 조각인지 읽힙니다. 원작처럼 주황 계열 안에서만 나눕니다.
const BLOCK_COLS := [
	Color8(232, 138, 46), Color8(214, 96, 40), Color8(240, 176, 66),
	Color8(198, 118, 62), Color8(246, 152, 92),
]

func cell_rect(r: Rect2, i: int) -> Rect2:
	# 판의 칸 하나. **그리기와 드래그 놓기 판정이 같이 봅니다.**
	var g := minf(r.size.x, r.size.y) / float(Gr.GRID)
	@warning_ignore("integer_division")
	var row := i / Gr.GRID
	return Rect2(r.position.x + (i % Gr.GRID) * g, r.position.y + row * g, g, g)

func cell_at(r: Rect2, p: Vector2) -> int:
	for i in range(Gr.CELLS):
		if cell_rect(r, i).has_point(p):
			return i
	return -1

func _block_cell(ci: CanvasItem, box: Rect2, col: Color) -> void:
	ci.draw_rect(box, col, true)
	# 야구공 실밥 두 줄 — 원작 블록이 공 무늬입니다.
	var m := box.get_center()
	var rr := box.size.x * 0.30
	ci.draw_arc(m + Vector2(-rr * 1.1, 0), rr * 1.5, -0.7, 0.7, 10, P.a(Color(1, 1, 1), 0.55), 1.5)
	ci.draw_arc(m + Vector2(rr * 1.1, 0), rr * 1.5, PI - 0.7, PI + 0.7, 10, P.a(Color(1, 1, 1), 0.55), 1.5)
	ci.draw_rect(box, P.a(Color(0, 0, 0), 0.35), false, 1.0)

func blocks(ci: CanvasItem, r: Rect2, c: Dictionary, ghost_uid: int = -1,
		ghost_at: int = -1, ghost_ok: bool = false) -> void:
	# 4×4 판. 잠긴 칸은 어둡게, 열린 빈 칸은 테두리만, 놓인 칸은 블록 색으로.
	# `ghost_*` 는 끌고 있는 블록의 미리보기입니다 — **놓기 전에 되는지 보여야**
	# 안 되는 자리에 떨어뜨리고 나서 실패 글을 읽는 일이 없습니다.
	var open: Array = Gr.open_cells(c)
	var bd := Gr.board(c)
	var cell: Dictionary = bd["cell"]
	var uids: Array = bd["uids"]
	for i in range(Gr.CELLS):
		var box := cell_rect(r, i).grow(-maxf(cell_rect(r, i).size.x * 0.06, 1.0))
		if cell.has(i):
			_block_cell(ci, box, BLOCK_COLS[maxi(uids.find(int(cell[i])), 0) % BLOCK_COLS.size()])
		elif open.has(i):
			ci.draw_rect(box, P.PANEL_HI, true)
			ci.draw_rect(box, P.LINE, false, 1.0)
		else:
			ci.draw_rect(box, P.a(P.PANEL, 0.6), true)
			ci.draw_rect(box, P.a(P.LINE, 0.4), false, 1.0)
	if ghost_uid < 0 or ghost_at < 0:
		return
	var gb := Gr.block(ghost_uid)
	if gb.is_empty():
		return
	var col := P.hdr(P.BAR_HIGH, 1.2) if ghost_ok else P.WARN
	for k in Gr.cells_of(gb, ghost_at):
		var box2 := cell_rect(r, int(k)).grow(-2.0)
		ci.draw_rect(box2, P.a(col, 0.35), true)
		ci.draw_rect(box2, col, false, 2.0)

func block_icon(ci: CanvasItem, at: Vector2, cell: float, b: Dictionary, col: Color) -> void:
	# 목록에 붙는 작은 블록 그림. **모양을 먼저 보고** 고르게 됩니다.
	if b.is_empty():
		return
	for p in Gr.shape_cells(str(b.get("shape", "ㅁ")), int(b.get("rot", 0))):
		ci.draw_rect(Rect2(at.x + int(p[0]) * cell, at.y + int(p[1]) * cell,
			cell - 1.0, cell - 1.0), col, true)

func block_icon_size(b: Dictionary, cell: float) -> Vector2:
	var mx := 1
	var my := 1
	for p in Gr.shape_cells(str(b.get("shape", "ㅁ")), int(b.get("rot", 0))):
		mx = maxi(mx, int(p[0]) + 1)
		my = maxi(my, int(p[1]) + 1)
	return Vector2(mx * cell, my * cell)


func pitch_chart(ci: CanvasItem, r: Rect2, c: Dictionary, extra: int = 0) -> void:
	# 가운데 공에서 구종이 뻗어 나가는 방사도(첨부 이미지의 그 그림).
	# `extra` 는 팀컬러 몫 — 팀에 붙는 것이라 카드에는 안 얹혀 있습니다.
	var ps := Gr.pitches_of(c, extra)
	if ps.is_empty():
		return
	var m := r.get_center()
	var rad := minf(r.size.x, r.size.y) * 0.34
	for i in range(ps.size()):
		var p: Dictionary = ps[i]
		var a := -PI * 0.5 + TAU * float(i) / float(ps.size())
		var dir := Vector2(cos(a), sin(a))
		var gd := int(p["grade"])
		var col := P.bar(40 + gd * 15)
		ci.draw_line(m + dir * rad * 0.42, m + dir * rad * 0.92, P.a(col, 0.8), 2.0)
		# 화살촉
		var tip := m + dir * rad
		ci.draw_colored_polygon(PackedVector2Array([tip,
			tip - dir.rotated(0.42) * rad * 0.20, tip - dir.rotated(-0.42) * rad * 0.20]), col)
		# 이름표는 화살촉 바깥에. 오른쪽 절반은 왼쪽 정렬, 왼쪽 절반은 오른쪽 정렬.
		var lab := "%s %s" % [str(p["name"]), Gr.pitch_grade_name(gd)]
		var lw := txt_w(lab, 13)
		var lp := m + dir * (rad + 12.0)
		if dir.x < -0.15:
			lp.x -= lw
		elif absf(dir.x) <= 0.15:
			lp.x -= lw * 0.5
		txt(ci, Vector2(lp.x, lp.y + 5.0), lab, 13, col)
	# 가운데 공
	ci.draw_circle(m, rad * 0.30, Color8(238, 238, 244))
	ci.draw_arc(m + Vector2(-rad * 0.34, 0), rad * 0.46, -0.75, 0.75, 12, Color8(190, 60, 60), 2.0)
	ci.draw_arc(m + Vector2(rad * 0.34, 0), rad * 0.46, PI - 0.75, PI + 0.75, 12, Color8(190, 60, 60), 2.0)

# 수비 위치 — **다이아몬드 기준**의 자리입니다. 홈에서 내야 한 변(`inf`)을 1로
# 보고 [오른쪽, 외야쪽] 으로 잽니다.
#
# **패널 비율(0~1)로 잡지 마세요.** 판이 가로로 넓어지면 다이아몬드는 가운데
# 작게 그려지는데 자리 표시만 비율대로 퍼져서 **그림 밖으로 나갑니다**
# (실제로 1루수가 잔디 밖에 찍혔습니다).
const FIELD_AT := {
	"포수": Vector2(0.0, -0.22), "1루수": Vector2(0.62, 0.60), "2루수": Vector2(0.34, 0.98),
	"3루수": Vector2(-0.62, 0.60), "유격수": Vector2(-0.34, 0.98),
	"좌익수": Vector2(-1.02, 1.52), "중견수": Vector2(0.0, 1.80), "우익수": Vector2(1.02, 1.52),
	"지명타자": Vector2(-0.95, -0.30), "외야수": Vector2(0.0, 1.70),
}

func field_chart(ci: CanvasItem, r: Rect2, c: Dictionary) -> void:
	# 야구장 그림 위에 그 카드의 주 포지션을 찍습니다.
	var home := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.90)
	var inf := minf(r.size.y * 0.42, r.size.x * 0.26)
	var far := inf * 2.05
	# 외야 잔디 부채꼴
	var fan := PackedVector2Array([home])
	for i in range(13):
		var a := -PI * 0.75 + (PI * 0.5) * float(i) / 12.0
		fan.append(home + Vector2(cos(a), sin(a)) * far)
	ci.draw_colored_polygon(fan, Color8(38, 68, 46))
	# 내야 흙
	var dia := PackedVector2Array([home, home + Vector2(-inf * 0.72, -inf * 0.72),
		home + Vector2(0, -inf * 1.44), home + Vector2(inf * 0.72, -inf * 0.72)])
	ci.draw_colored_polygon(dia, Color8(104, 74, 50))
	ci.draw_polyline(PackedVector2Array([dia[0], dia[1], dia[2], dia[3], dia[0]]),
		P.a(Color(1, 1, 1), 0.55), 1.5)
	var pos := str(c.get("pos", ""))
	var at: Vector2 = FIELD_AT.get(pos, Vector2(0.0, 0.9))
	# y 는 화면에서 아래로 크므로 **외야쪽(+)이 곧 -y** 입니다.
	var p := home + Vector2(at.x * inf, -at.y * inf)
	ci.draw_circle(p, 10.0, P.hdr(P.BAR_HIGH, 1.25))
	ci.draw_arc(p, 10.0, 0, TAU, 20, Color(0, 0, 0, 0.5), 1.5)
	var nm := str(D.POS_SHORT.get(pos, pos))
	txt(ci, Vector2(p.x - txt_w(nm, 13) * 0.5, p.y + 25.0), nm, 13, P.TEXT)
