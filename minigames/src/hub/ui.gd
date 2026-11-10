class_name UiKit
extends RefCounted

## 게임들이 같이 쓰는 화면 틀 — 처음 화면의 게임 이름 · 단추("게임 선택" 왼쪽 위 · "음량" 오른쪽 위 · "시작" 오른쪽 아래) · 글꼴.
##
## **자리 · 크기 · 동작은 모든 게임이 같고, 모양 · 글꼴 · 장식은 게임마다 다릅니다**(사용자 결정 11-09, docs/ai-look-overhaul.md —
## 예전 원칙 "모양까지 하나로" 가 "전체적으로 너무 AI 틱하다" 는 말을 들었습니다. ADR-0008 을 이 원칙으로 고쳤습니다).
##   · 자리는 `Hub.std_rect` · `menu_rect`, 마우스 반응 · 아이콘 · 글자 맞춤은 여기 한 곳.
##   · 게임마다 다른 것은 `theme()` 의 `title`(이름 처리) · `btn`(단추 몸통) · `corner`(모서리 모양) · 글꼴(`FONTS`) · `outline`(글자 테두리 세기).
##   · 숨 쉬는 빛 · 반짝임 · 이름 들썩임 같은 자동 연출은 젤리팝 · 허브에만 남겼습니다. 나머지는 마우스를 올렸을 때만 반응합니다.
## 새 게임을 만들면 `theme()` 에 한 칸, `FONTS` 에 한 줄을 넣고, 어울리는 `title` · `btn` 을 고르거나 새 갈래를 만드세요(남의 것을 그대로 쓰지 말 것).
## 글자는 게임 글꼴에 없는 기호를 `clean()` 이 바꿉니다. 아이콘은 전부 도형이라 글꼴과 상관없습니다.

## 지금 화면의 게임(허브가 게임을 열고 닫을 때 정한다). `font()` 와 `G2` 의 기본 모서리 · 글자 테두리가 이것을 본다.
static var game := "hub"


## 게임별 테마.
##   rad 모서리 반지름 · corner 모서리 모양(0 원호 · 1 부드러운 곡률 · 2 깎음 · 3 안으로 파임) · edge 테두리 · ink 글자 테두리 색
##   hub · vol · start · menu 단추 몸통 색과 *_text 글자 색 · glow 빛 색
##   title 이름 처리 · title_col [이름, 소개 줄] · btn 단추 몸통 갈래 · outline 글자 테두리 세기(G2.text_mid 가 곱한다)
static func theme(g: String) -> Dictionary:
	match g:
		"jelly":
			return {rad = 26.0, corner = 1, edge = Color8(70, 40, 90), ink = Color8(70, 40, 90),
					hub = Color8(255, 168, 92), vol = Color8(255, 250, 252), start = Color8(104, 208, 92),
					hub_text = Color(1, 1, 1), vol_text = Color8(70, 40, 90), start_text = Color(1, 1, 1),
					menu = Color8(150, 112, 206), glow = Color8(255, 240, 140),
					title = "candy", title_col = [Color8(255, 120, 180), Color(1, 1, 1)], btn = "glossy", outline = 1.0}
		"sky":
			return {rad = 10.0, corner = 2, edge = Color8(110, 220, 255), ink = Color8(6, 10, 18),
					hub = Color8(14, 22, 36), vol = Color8(14, 22, 36), start = Color8(10, 40, 60),
					hub_text = Color8(170, 220, 240), vol_text = Color8(170, 220, 240), start_text = Color8(200, 250, 255),
					menu = Color8(18, 52, 82), glow = Color8(90, 220, 255),
					title = "hud", title_col = [Color8(214, 246, 255), Color8(150, 200, 225)], btn = "hud", outline = 0.5}
		"runner":
			return {rad = 16.0, corner = 1, edge = Color8(30, 34, 70), ink = Color8(14, 18, 40),
					hub = Color8(64, 74, 132), vol = Color8(64, 74, 132), start = Color8(38, 190, 96),
					hub_text = Color(1, 1, 1), vol_text = Color(1, 1, 1), start_text = Color(1, 1, 1),
					menu = Color8(64, 98, 184), glow = Color8(140, 255, 170),
					title = "toy", title_col = [Color8(255, 214, 90), Color(1, 1, 1)], btn = "toy", outline = 1.0}
		"gangho":
			return {rad = 3.0, corner = 0, edge = Color8(40, 30, 24), ink = Color8(40, 30, 24),
					hub = Color8(226, 212, 184), vol = Color8(226, 212, 184), start = Color8(150, 36, 30),
					hub_text = Color8(40, 30, 24), vol_text = Color8(40, 30, 24), start_text = Color8(250, 238, 214),
					menu = Color8(214, 200, 172), glow = Color8(255, 190, 120),
					title = "ink", title_col = [Color8(28, 22, 18), Color8(34, 26, 22)], btn = "ink", outline = 0.4}
		"arcana":
			return {rad = 14.0, corner = 3, edge = Color8(214, 180, 110), ink = Color8(30, 18, 50),
					hub = Color8(58, 40, 100), vol = Color8(58, 40, 100), start = Color8(120, 60, 150),
					hub_text = Color8(240, 230, 250), vol_text = Color8(240, 230, 250), start_text = Color8(250, 240, 220),
					menu = Color8(58, 40, 100), glow = Color8(255, 220, 140),
					title = "gild", title_col = [Color8(240, 214, 150), Color8(226, 218, 240)], btn = "gild", outline = 0.5}
		"empire":
			return {rad = 10.0, corner = 2, edge = Color8(52, 34, 20), ink = Color8(40, 26, 16),
					hub = Color8(150, 110, 62), vol = Color8(150, 110, 62), start = Color8(150, 52, 36),
					hub_text = Color8(40, 26, 16), vol_text = Color8(40, 26, 16), start_text = Color8(255, 238, 210),
					menu = Color8(160, 122, 74), glow = Color8(255, 210, 120),
					title = "carve", title_col = [Color8(66, 40, 18), Color8(70, 46, 24)], btn = "plate", outline = 0.5}
		"redstar":
			return {rad = 4.0, corner = 0, edge = Color8(224, 110, 70), ink = Color8(30, 16, 14),
					hub = Color8(58, 30, 28), vol = Color8(58, 30, 28), start = Color8(196, 80, 50),
					hub_text = Color8(240, 220, 208), vol_text = Color8(240, 220, 208), start_text = Color8(255, 244, 236),
					menu = Color8(58, 30, 28), glow = Color8(255, 170, 120),
					title = "tech", title_col = [Color8(244, 228, 216), Color8(250, 226, 208)], btn = "tech", outline = 0.3}
		"ashkeep":
			return {rad = 3.0, corner = 2, edge = Color8(112, 104, 100), ink = Color8(14, 12, 14),
					hub = Color8(54, 50, 54), vol = Color8(54, 50, 54), start = Color8(120, 52, 30),
					hub_text = Color8(226, 220, 210), vol_text = Color8(226, 220, 210), start_text = Color8(255, 226, 196),
					menu = Color8(54, 50, 54), glow = Color8(255, 150, 80),
					title = "ember", title_col = [Color8(226, 220, 208), Color8(232, 224, 210)], btn = "iron", outline = 0.4}
		"tiger":
			return {rad = 8.0, corner = 1, edge = Color8(40, 30, 28), ink = Color8(40, 30, 28),
					hub = Color8(60, 90, 140), vol = Color8(60, 90, 140), start = Color8(206, 60, 46),
					hub_text = Color8(252, 246, 232), vol_text = Color8(252, 246, 232), start_text = Color(1, 1, 1),
					menu = Color8(60, 90, 140), glow = Color8(255, 220, 140),
					title = "lamp", title_col = [Color8(252, 246, 232), Color8(255, 250, 240)], btn = "toy", outline = 0.8}
	# 허브
	return {rad = 24.0, corner = 1, edge = Color8(70, 40, 90), ink = Color8(70, 40, 90),
			hub = Color8(255, 168, 92), vol = Color8(255, 250, 252), start = Color8(104, 208, 92),
			hub_text = Color(1, 1, 1), vol_text = Color8(70, 40, 90), start_text = Color(1, 1, 1),
			menu = Color8(150, 112, 206), glow = Color8(255, 240, 140),
			title = "candy", title_col = [Color(1, 1, 1), Color(1, 1, 1)], btn = "glossy", outline = 1.0}


## 지금 게임의 글자 테두리 세기(0~1) — `G2.text_mid` 가 곱한다. 어두운 판 위의 글자까지 전부 테두리를 두르던 것을 게임마다 줄였다.
static func outline_k() -> float:
	return float(theme(game).outline)


## 지금 게임의 기본 모서리 모양 — `G2.round_rect` 가 kind 를 안 받았을 때 쓴다.
static func corner_kind() -> int:
	return int(theme(game).corner)

# ==================== 게임 이름 ====================


## 처음 화면 왼쪽의 게임 이름 + 소개 한 줄. **자리와 크기 상한은 모든 게임이 같고 처리는 게임마다 다르다**(테마의 `title`).
## 자리: 왼쪽 단 가운데(x 0.3) · y 150. 긴 이름은 왼쪽 단 폭에 맞춰 줄어든다. 돌려주는 값: 소개 줄 아래 끝 y(게임 그림을 그 밑에).
static func title(ci: CanvasItem, vs: Vector2, g: String, name: String, sub: String, t: float) -> float:
	var th := theme(g)
	var cols: Array = th.title_col
	var style := String(th.title)
	var cx := vs.x * 0.3 if vs.x > vs.y else vs.x * 0.5
	var cy := 150.0 if vs.x > vs.y else vs.y * 0.14
	var f := title_font(g)
	var bf := font_of(g)
	var size := 88.0 * (1.3 if style == "ink" else 1.0)   # 붓글씨는 같은 크기에서 훨씬 작게 보인다
	var total := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var maxw := vs.x * 0.5 - 60.0 if vs.x > vs.y else vs.x - 60.0
	if total > maxw:
		size = floorf(size * maxw / total)
		total = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var x0 := cx - total * 0.5
	var c := Vector2(cx, cy)
	var ink: Color = th.ink
	var sub_outline := 0.0
	match style:
		"hud":
			# 얇은 테 + 아래 눈금 선 — 계기판 글자
			_str(ci, f, c, name, size, cols[0], 4, Color(ink, 0.9))
			var y := cy + size * 0.52
			ci.draw_line(Vector2(x0, y), Vector2(x0 + total, y), th.edge, 2.0)
			for k in 9:
				var tx := x0 + total * k / 8.0
				ci.draw_line(Vector2(tx, y), Vector2(tx, y + (8.0 if k % 4 == 0 else 4.0)), th.edge, 2.0)
			sub_outline = 3.0
		"toy":
			# 장난감 블록 — 굵은 테, 딱 떨어지는 아래 그림자, 글자마다 살짝 기울임(움직이지 않는다)
			var x := x0
			for k in name.length():
				var ch := name[k]
				var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
				if ch != " ":
					ci.draw_set_transform(Vector2(x + w * 0.5, cy), deg_to_rad(-3.0 if k % 2 == 0 else 3.0))
					_str(ci, f, Vector2(0, 6), ch, size, ink, 16, ink)
					_str(ci, f, Vector2.ZERO, ch, size, cols[0], 14, ink)
					ci.draw_set_transform(Vector2.ZERO, 0.0)
				x += w
			sub_outline = 6.0
		"ink":
			# 먹 글씨 — 테두리 없이 종이 위에
			_str(ci, f, c + Vector2(0, -size * 0.2), name, size, cols[0], 0, ink)   # 붓글씨는 글자가 기준선 아래로 길게 내려온다
		"gild":
			# 금박 — 어두운 얇은 테 + 한 겹의 옅은 번짐
			_str(ci, f, c, name, size, Color(cols[0], 0.0), 10, Color(Color8(255, 210, 120), 0.10))
			_str(ci, f, c, name, size, cols[0], 3, Color(ink, 0.95))
			sub_outline = 4.0
		"carve":
			# 돌에 새긴 글씨 — 아래에 밝은 선, 글자는 어둡게
			_str(ci, f, c + Vector2(0, 2.5), name, size, Color(1, 0.96, 0.84, 0.75), 0, ink)
			_str(ci, f, c, name, size, cols[0], 0, ink)
		"tech":
			# 판에 찍은 글자 — 장식 없이, 왼쪽 위에 짧은 강조 선 하나
			_str(ci, f, c, name, size, cols[0], 0, ink)
			ci.draw_rect(Rect2(x0, cy - size * 0.62, 56, 5), th.edge)
			sub_outline = 0.0
		"lamp":
			# 사탕 글씨 — 글자 뒤에 분홍 빛 한 겹, 굵은 테(떡 하나 주면 안 잡아먹지)
			_str(ci, f, c, name, size, Color(cols[0], 0.0), 22, Color(Color8(226, 70, 50), 0.2))
			_str(ci, f, c, name, size, cols[0], 10, ink)
			sub_outline = 6.0
		"ember":
			# 재 위의 글씨 — 딱 떨어지는 불씨 색 그림자
			_str(ci, f, c + Vector2(0, 5), name, size, Color8(150, 60, 28), 0, ink)
			_str(ci, f, c, name, size, cols[0], 0, ink)
		_:
			# candy — 두꺼운 테 · 그림자 · 글자가 차례로 들썩(젤리팝 · 허브만)
			var x2 := x0
			for k in name.length():
				var ch2 := name[k]
				var w2 := f.get_string_size(ch2, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
				if ch2 != " ":
					var bob := maxf(0.0, sin(t * 2.2 - k * 0.55)) * 7.0
					var p := Vector2(x2 + w2 * 0.5, cy - bob)
					_str(ci, f, p + Vector2(0, 7), ch2, size, Color(0, 0, 0, 0.32), 20, Color(0, 0, 0, 0.32))
					_str(ci, f, p, ch2, size, cols[0], 18, ink)
				x2 += w2
			sub_outline = 6.0
	_str(ci, bf, Vector2(cx, cy + 68), clean_for(sub, bf), 24, cols[1], sub_outline, ink)
	return cy + 84


## 글자 한 줄을 pos 가운데에(글꼴을 직접 준다 — `G2.text_mid` 는 지금 게임의 본문 글꼴만 쓴다).
static func _str(ci: CanvasItem, f: Font, pos: Vector2, s: String, size: float, col: Color, outline: float, oc: Color) -> void:
	if s == "":
		return
	var m := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size))
	var at := pos - Vector2(m.x * 0.5, -size * 0.36)
	if outline > 0.0:
		ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), int(outline), oc)
	if col.a > 0.0:
		ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), col)

# ==================== 단추 ====================


## 처음 화면 오른쪽 메뉴 줄의 j 번째 단추 자리 — 모든 게임 같은 크기 · 간격.
static func menu_rect(vs: Vector2, j: int) -> Rect2:
	if vs.x > vs.y:
		return Rect2(vs.x * 0.72 - 170, 200 + j * 84.0, 340, 66)
	return Rect2(vs.x * 0.5 - 170, vs.y * 0.55 + j * 84.0, 340, 66)


## 메뉴 단추(아이콘 없음) — 보조 메뉴는 게임마다 한 색(`menu`). 강조색은 "시작" 단추에만.
static func menu(ci: CanvasItem, r: Rect2, label: String, fill: Color, g: String, t: float) -> void:
	var th := theme(g)
	fill = th.get("menu", fill)
	draw(ci, r, "menu", label, fill, _text_on(fill), th, r.has_point(ci.get_local_mouse_position()), t)


## **게임 안쪽 화면의 모든 단추**도 이 모양을 쓴다. 게임마다 있는 단추 함수(`_btn` · `_big_btn` · `_draw_button`)가 이것을 부른다.
## size < 0 이면 단추 높이에 맞춘 글자 크기. enabled = false 면 어둡게 · 글자 흐리게 · 마우스 반응 없음.
static func plain(ci: CanvasItem, r: Rect2, label: String, fill: Color, g: String, t: float, enabled: bool = true,
		size: float = -1.0) -> void:
	var th := theme(g)
	var f := fill if enabled else fill.darkened(0.5).lerp(Color(0.3, 0.3, 0.35), 0.4)
	var tc := _text_on(f)
	if not enabled:
		tc = Color(tc, 0.45)
	draw(ci, r, "menu", label, f, tc, th, enabled and r.has_point(ci.get_local_mouse_position()), t, size)


static func _text_on(fill: Color) -> Color:
	return Color8(40, 28, 44) if fill.get_luminance() > 0.6 else Color(1, 1, 1)


## 처음 화면 단추 하나. kind = "hub" · "vol" · "start". label 이 비면 기본 글(게임 선택 · 음량 · 시작).
static func button(ci: CanvasItem, vs: Vector2, kind: String, g: String, t: float, label: String = "") -> void:
	var r := Hub.std_rect(kind, vs)
	var th := theme(g)
	if label == "":
		label = {"hub": "게임 선택", "vol": "음량", "start": "시작", "rules": "규칙"}[kind]
	var hot := r.has_point(ci.get_local_mouse_position())
	var ck := "hub" if kind == "rules" else kind   # 규칙 단추는 나가기와 같은 색
	if Hub.compact and kind != "start":
		# 판 화면 — 아이콘만. 마우스를 올리면 아래에 이름이 뜬다
		draw(ci, r, kind, "", th[ck], th[ck + "_text"], th, hot, t)
		if hot:
			var f := font()
			var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0
			var tx := clampf(r.get_center().x, tw * 0.5 + 6.0, vs.x - tw * 0.5 - 6.0)
			G2.panel(ci, Rect2(tx - tw * 0.5, r.end.y + 6, tw, 30), Color(0, 0, 0, 0.8), Color(), 0.0, 8)
			_str(ci, f, Vector2(tx, r.end.y + 21), label, 20, Color(1, 1, 1), 0, th.ink)
		return
	draw(ci, r, kind, label, th[ck], th[ck + "_text"], th, hot, t)


## 단추 그리기(자리를 직접 줄 때). fill = 몸통 색, tc = 글자 색. 몸통은 테마의 `btn` 갈래가 그리고, 아이콘 · 글자 맞춤은 공통.
static func draw(ci: CanvasItem, r: Rect2, kind: String, label: String, fill: Color, tc: Color, th: Dictionary,
		hot: bool, t: float, text_size: float = -1.0) -> void:
	var rad: float = minf(float(th.rad), r.size.y * 0.5)
	var primary := kind == "start"
	var style := String(th.get("btn", "glossy"))
	var text_outline := 0.0
	match style:
		"hud":
			_body_hud(ci, r, rad, fill, th, hot, primary)
		"ink":
			_body_ink(ci, r, rad, fill, th, hot, primary)
		"gild":
			_body_gild(ci, r, rad, fill, th, hot, primary)
		"plate":
			_body_plate(ci, r, rad, fill, th, hot, primary)
		"tech":
			_body_tech(ci, r, rad, fill, th, hot, primary)
		"iron":
			_body_iron(ci, r, rad, fill, th, hot, primary)
		"toy":
			r = _body_toy(ci, r, rad, fill, th, hot, primary)
			text_outline = 0.14
		_:
			r = _body_glossy(ci, r, rad, fill, th, hot, primary, t)
			text_outline = 0.16
	# 아이콘 + 글(label 이 비면 몸통만 — 러너처럼 글을 따로 얹는 단추)
	if label == "" and not (kind in ["hub", "vol", "start", "rules"]):
		return
	var size := text_size if text_size > 0.0 else r.size.y * (0.4 if primary else 0.44)
	var f := font()
	label = clean_for(label, f)
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	if tw > r.size.x - 20.0 and tw > 0.0:
		size = floorf(size * (r.size.x - 20.0) / tw)
		tw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var has_icon := kind in ["hub", "vol", "start", "rules"]
	var isz := r.size.y * (0.5 if primary else 0.46) if has_icon else 0.0
	var gap := 10.0 if has_icon and label != "" else 0.0
	var total := isz + gap + tw
	var x0 := r.get_center().x - total * 0.5
	var ic := Vector2(x0 + isz * 0.5, r.get_center().y)
	match kind:
		"hub":
			if Hub.compact:   # 판에서는 "나가기" — 왼쪽 화살표
				ci.draw_colored_polygon(PackedVector2Array([ic + Vector2(-isz * 0.5, 0), ic + Vector2(0, -isz * 0.45), ic + Vector2(0, isz * 0.45)]), tc)
				ci.draw_rect(Rect2(ic.x - 1, ic.y - isz * 0.16, isz * 0.5, isz * 0.32), tc)
			else:
				_icon_grid(ci, ic, isz, tc)
		"rules":
			_str(ci, f, ic, "?", isz * 1.3, tc, 0, th.ink)
		"vol":
			_icon_speaker(ci, ic, isz, tc, Sv.music or Sv.sfx)
		"start":
			_icon_play(ci, ic, isz, tc, fill)
	var pos := Vector2(x0 + isz + gap + tw * 0.5, r.get_center().y)
	var dark_text := tc.get_luminance() < 0.5
	if style == "plate" and dark_text:
		_str(ci, f, pos + Vector2(0, 1.5), label, size, Color(1, 0.95, 0.8, 0.5 * tc.a), 0, th.ink)   # 음각 — 아래 밝은 선
	_str(ci, f, pos, label, size, tc, 0.0 if dark_text else size * text_outline, Color(th.ink, 0.8))


## 젤리팝 · 허브 — 그림자 + 위가 밝은 그라데이션 + 광택 띠, 시작 단추는 숨 쉬는 빛과 3초마다 반짝임. 돌려주는 값: 들린 뒤의 자리.
static func _body_glossy(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool, t: float) -> Rect2:
	if hot:
		r.position.y -= 2.0
		fill = fill.lightened(0.08)
	if primary:
		var gc: Color = th.glow
		var br := 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 2.4))   # 0 까지 내리지 않는다(깜빡여 보인다)
		for k in 4:
			_rr(ci, r.grow(4.0 + k * 4.0), rad + 4.0 + k * 4.0, Color(gc, 0.10 * br * (1.0 - k * 0.22)))
	_rr(ci, Rect2(r.position + Vector2(0, 5), r.size), rad, Color(0, 0, 0, 0.32))
	var pts := G2.round_rect(r, rad, 1)
	_fan_grad(ci, pts, r, fill.lightened(0.2), fill.darkened(0.16))
	var gl := Rect2(r.position + Vector2(rad * 0.5 + 4, 3), Vector2(r.size.x - rad - 8, r.size.y * 0.38))
	_rr(ci, gl, minf(rad, gl.size.y * 0.5), Color(1, 1, 1, 0.16 if fill.get_luminance() < 0.7 else 0.4))
	if primary:
		var s := fposmod(t, 3.0) / 0.7
		if s < 1.0:
			var x := r.position.x + (r.size.x + r.size.y) * s - r.size.y
			var band := PackedVector2Array([Vector2(x, r.end.y - 3), Vector2(x + r.size.y * 0.5, r.position.y + 3),
					Vector2(x + r.size.y * 0.5 + 18, r.position.y + 3), Vector2(x + 18, r.end.y - 3)])
			var clipped := Geometry2D.intersect_polygons(band, G2.round_rect(r.grow(-2), maxf(0.0, rad - 2), 0))
			for poly: PackedVector2Array in clipped:
				var cen := Vector2.ZERO
				for p in poly:
					cen += p
				G2.fill_fan(ci, poly, Color(1, 1, 1, 0.28 * sin(s * PI)), cen / maxf(1.0, poly.size()))
	G2.stroke(ci, pts, th.edge, 3.0 if primary else 2.2)
	return r


## 월드 러너 — 장난감 블록. 아래에 딱 떨어지는 두꺼운 밑단(그림자가 아니라 블록의 옆면), 누르는 느낌으로 마우스를 올리면 내려앉는다.
static func _body_toy(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool) -> Rect2:
	var lip := 6.0 if primary else 5.0
	var pts_base := G2.round_rect(Rect2(r.position + Vector2(0, lip), r.size), rad, 1)
	G2.fill_fan(ci, pts_base, fill.darkened(0.38), r.get_center() + Vector2(0, lip))
	G2.stroke(ci, pts_base, th.edge, 3.0)
	if hot:
		r.position.y += 2.0
		fill = fill.lightened(0.06)
	var pts := G2.round_rect(r, rad, 1)
	G2.fill_fan(ci, pts, fill, r.get_center())
	G2.stroke(ci, pts, th.edge, 3.0)
	# 위쪽에 가는 밝은 선 하나(광택 띠 대신)
	ci.draw_line(r.position + Vector2(rad, 5), Vector2(r.end.x - rad, r.position.y + 5), Color(1, 1, 1, 0.3), 2.0)
	return r


## 스카이 어설트 — 계기판 단추. 깎은 모서리, 속이 비치는 어두운 몸통, 테두리와 모서리 눈금. 그림자 · 광택 없음.
static func _body_hud(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool) -> void:
	var pts := G2.round_rect(r, rad, 2)
	var edge: Color = th.edge
	G2.fill_fan(ci, pts, Color(fill.lightened(0.12) if hot else fill, 0.92), r.get_center())
	if primary:
		G2.fill_fan(ci, G2.round_rect(r.grow(-5), maxf(0.0, rad - 3), 2), Color(edge, 0.16 if not hot else 0.28), r.get_center())
	G2.stroke(ci, pts, Color(edge, 1.0 if (hot or primary) else 0.6), 2.0)
	# 왼쪽 위 · 오른쪽 아래 모서리 눈금
	ci.draw_line(r.position + Vector2(rad + 4, -4), r.position + Vector2(rad + 26, -4), Color(edge, 0.8), 2.0)
	ci.draw_line(r.end - Vector2(rad + 26, -4), r.end - Vector2(rad + 4, -4), Color(edge, 0.8), 2.0)


## 강호일생 — 종이 위의 먹선. 납작한 종이색 몸통, 바깥 굵은 선과 안쪽 가는 선. 그림자 없음.
static func _body_ink(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, _primary: bool) -> void:
	var pts := G2.round_rect(r, rad, 0)
	G2.fill_fan(ci, pts, fill.darkened(0.06) if hot else fill, r.get_center())
	G2.stroke(ci, pts, th.edge, 2.5)
	var inner := r.grow(-4.0)
	if inner.size.x > 8.0 and inner.size.y > 8.0:
		G2.stroke(ci, G2.round_rect(inner, maxf(0.0, rad - 2.0), 0), Color(th.edge, 0.35 if fill.get_luminance() > 0.5 else 0.6), 1.0)


## 아르카나 컬렉션 — 금테 액자. 모서리가 안으로 파인 판, 금색 바깥 테와 안쪽 가는 테. 그림자 · 광택 없음.
static func _body_gild(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool) -> void:
	var pts := G2.round_rect(r, rad, 3)
	G2.fill_fan(ci, pts, fill.lightened(0.1) if hot else fill, r.get_center())
	var edge: Color = th.edge
	G2.stroke(ci, pts, edge if (hot or primary) else Color(edge, 0.75), 2.0)
	var inner := r.grow(-5.0)
	if inner.size.x > 10.0 and inner.size.y > 10.0:
		G2.stroke(ci, G2.round_rect(inner, maxf(0.0, rad - 3.0), 3), Color(edge, 0.4), 1.0)


## 제국 연대기 — 청동 판. 깎은 모서리, 위가 조금 밝은 금속 면, 위에 밝은 선 · 아래 어두운 선. 글자는 음각(draw 가 처리).
static func _body_plate(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, _primary: bool) -> void:
	if hot:
		fill = fill.lightened(0.08)
	_rr(ci, Rect2(r.position + Vector2(0, 3), r.size), rad, Color(0, 0, 0, 0.3), 2)
	var pts := G2.round_rect(r, rad, 2)
	_fan_grad(ci, pts, r, fill.lightened(0.1), fill.darkened(0.12))
	G2.stroke(ci, pts, th.edge, 2.0)
	ci.draw_line(r.position + Vector2(rad, 3), Vector2(r.end.x - rad, r.position.y + 3), Color(1, 0.95, 0.8, 0.35), 1.5)
	ci.draw_line(Vector2(r.position.x + rad, r.end.y - 3), r.end - Vector2(rad, 3), Color(0, 0, 0, 0.3), 1.5)


## 붉은 별 개척단 — 설비 표지판. 납작한 몸통, 왼쪽에 강조 띠 하나. 그림자 · 광택 없음.
static func _body_tech(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool) -> void:
	var pts := G2.round_rect(r, rad, 0)
	G2.fill_fan(ci, pts, fill.lightened(0.1) if hot else fill, r.get_center())
	var edge: Color = th.edge
	if not primary:
		ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(5, r.size.y - 4)), Color(edge, 1.0 if hot else 0.75))
	G2.stroke(ci, pts, Color(edge, 0.9 if hot else 0.4), 1.5)


## 잿빛 요새의 용병단 — 쇠판. 깎은 모서리의 어두운 판, 위에 밝은 선, 강조와 마우스 올림에 아래 불씨 선.
static func _body_iron(ci: CanvasItem, r: Rect2, rad: float, fill: Color, th: Dictionary, hot: bool, primary: bool) -> void:
	var pts := G2.round_rect(r, rad + 5.0, 2)
	G2.fill_fan(ci, pts, fill.lightened(0.08) if hot else fill, r.get_center())
	G2.stroke(ci, pts, th.edge, 2.0)
	ci.draw_line(r.position + Vector2(10, 4), Vector2(r.end.x - 10, r.position.y + 4), Color(1, 1, 1, 0.12), 1.5)
	if hot or primary:
		ci.draw_rect(Rect2(r.position.x + 10, r.end.y - 6, r.size.x - 20, 3), th.glow if hot else Color(th.glow, 0.6))


static func _rr(ci: CanvasItem, r: Rect2, rad: float, c: Color, kind: int = 1) -> void:
	G2.fill_fan(ci, G2.round_rect(r, minf(rad, minf(r.size.x, r.size.y) * 0.5), kind), c, r.get_center())


## 가운데에서 부채꼴로 채우되 꼭짓점마다 위아래 그라데이션 색(가운데는 중간색).
static func _fan_grad(ci: CanvasItem, poly: PackedVector2Array, r: Rect2, top: Color, bot: Color) -> void:
	var n := poly.size()
	if n < 3:
		return
	var pts := PackedVector2Array([r.get_center()])
	var cols := PackedColorArray([top.lerp(bot, 0.5)])
	for p in poly:
		pts.append(p)
		cols.append(top.lerp(bot, clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)))
	var idx := PackedInt32Array()
	for i in n:
		idx.append_array([0, i + 1, (i + 1) % n + 1])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)

# ==================== 아이콘(도형) ====================


## 게임 선택 — 둥근 네모 넷(게임 목록).
static func _icon_grid(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var q := s * 0.42
	var gap := s * 0.12
	for i in 4:
		var p := c + Vector2((i % 2) * (q + gap) - (q + gap * 0.5), (i / 2) * (q + gap) - (q + gap * 0.5))
		ci.draw_colored_polygon(G2.round_rect(Rect2(p, Vector2(q, q)), q * 0.28, 0), col)


## 음량 — 스피커 + 소리 물결 둘(꺼져 있으면 물결 대신 빗금).
static func _icon_speaker(ci: CanvasItem, c: Vector2, s: float, col: Color, on: bool) -> void:
	var h := s * 0.5
	var body := PackedVector2Array([c + Vector2(-h, -h * 0.38), c + Vector2(-h * 0.45, -h * 0.38), c + Vector2(h * 0.1, -h),
			c + Vector2(h * 0.1, h), c + Vector2(-h * 0.45, h * 0.38), c + Vector2(-h, h * 0.38)])
	ci.draw_colored_polygon(body, col)
	if on:
		for k in 2:
			ci.draw_arc(c + Vector2(h * 0.1, 0), h * (0.45 + k * 0.4), -0.85, 0.85, 12, col, maxf(2.0, s * 0.09), true)
	else:
		ci.draw_line(c + Vector2(h * 0.35, -h * 0.4), c + Vector2(h * 0.95, h * 0.4), col, maxf(2.0, s * 0.09))
		ci.draw_line(c + Vector2(h * 0.95, -h * 0.4), c + Vector2(h * 0.35, h * 0.4), col, maxf(2.0, s * 0.09))


## 시작 — 동그라미 안의 재생 삼각형(삼각형은 몸통 색으로 파낸다).
static func _icon_play(ci: CanvasItem, c: Vector2, s: float, col: Color, fill: Color) -> void:
	var r := s * 0.5
	ci.draw_circle(c, r, col)
	var tri := PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.48), c + Vector2(r * 0.52, 0), c + Vector2(-r * 0.32, r * 0.48)])
	ci.draw_colored_polygon(tri, fill.darkened(0.05))

# ==================== 글꼴 · 글자 ====================

## 글꼴은 게임마다 두 벌 — 이름(타이틀)과 본문. 브라우저에는 한글 글꼴이 없어 파일을 싣는다(`font/`).
## 파일은 `tools/font_subset.py` 가 필요한 글자만 남겨 만든 것(`mg_*.ttf`)이다. 빈 칸은 Jua.
## **타이틀 글꼴에는 게임 이름과 큰 제목 낱말만 들어 있다** — 없는 글자는 본문 글꼴 → Jua 순서로 메운다(얼룩져 보이니 그 스크립트의 TITLE_TEXT 에 넣을 것).
const FONTS := {
	"sky": ["mg_sky_title", "mg_sky_body"],
	"runner": ["mg_runner_title", ""],
	"gangho": ["mg_gangho_title", "mg_serif_body"],
	"arcana": ["mg_arcana_title", "mg_batang_body"],
	"empire": ["mg_empire_title", "mg_serif_body"],
	"redstar": ["mg_redstar_title", "mg_redstar_body"],
	"ashkeep": ["mg_ashkeep_title", "mg_batang_body"],
}
## 본문 글꼴의 글자 사이 조정(px) — Jua 보다 넓은 글꼴은 조금 좁혀 예전 자리에 들어가게.
const SPACING := {"mg_batang_body": -1, "mg_serif_body": -1}

static var _files := {}     ## 파일 이름 → Font
static var _jua: Font


static func jua() -> Font:
	if _jua == null:
		_jua = load("res://font/Jua-Regular.ttf")
	return _jua


static func _file(name: String, fallback: Font) -> Font:
	if name == "":
		return jua()
	if _files.has(name):
		return _files[name]
	var path := "res://font/%s.ttf" % name
	var out: Font = jua()
	if ResourceLoader.exists(path):
		var ff: FontFile = load(path)
		var fb: Array[Font] = []
		if fallback != jua():
			fb.append(fallback)
		fb.append(jua())
		ff.fallbacks = fb
		out = ff
		if SPACING.has(name):
			var fv := FontVariation.new()
			fv.base_font = ff
			fv.spacing_glyph = int(SPACING[name])
			out = fv
	_files[name] = out
	return out


## 지금 게임의 본문 글꼴.
static func font() -> Font:
	return font_of(game)


static func font_of(g: String) -> Font:
	var row: Array = FONTS.get(g, ["", ""])
	return _file(String(row[1]), jua())


## 게임 이름 · 큰 제목용 글꼴.
static func title_font(g: String = "") -> Font:
	if g == "":
		g = game
	var row: Array = FONTS.get(g, ["", ""])
	return _file(String(row[0]), font_of(g))


## 글꼴에 없는 기호를 있는 글자로 바꾼다(웹에서만 네모로 나오고 데스크톱은 시스템 글꼴이 메워 줘서 안 보인다).
## **그 글꼴에 있는 기호는 그대로 둔다** — 명조 · 고딕 계열에는 `·` `—` `×` `→` 가 있어서 그 게임에서는 쓸 수 있다(Jua 에는 없다).
const GLYPH_SWAP := {" · ": ", ", "·": ",", " — ": " - ", "—": "-", "→": ">", "←": "<", "↑": "^", "↓": "v",
		"▸": ">", "…": "...", "「": "'", "」": "'", "×": "x", "★": "*", "−": "-", "₩": "W", "÷": "/"}


static func clean(s: String) -> String:
	return clean_for(s, font())


static func clean_for(s: String, f: Font) -> String:
	for k in GLYPH_SWAP:
		if s.contains(k) and not f.has_char(String(k).strip_edges().unicode_at(0)):
			s = s.replace(k, GLYPH_SWAP[k])
	return s


## 처음 화면의 "내 기록 한 줄" — 모든 게임 같은 자리(오른쪽 메뉴 바로 아래) · 같은 크기. 색은 그 게임의 소개 줄 색.
static func record_line(ci: CanvasItem, vs: Vector2, text: String) -> void:
	if text == "":
		return
	var r := menu_rect(vs, 3)
	var th := theme(game)
	var col: Color = th.title_col[1]
	var dark := col.get_luminance() < 0.5
	_str(ci, font(), Vector2(r.get_center().x, r.end.y + 34), clean(text), 24, col, 0.0 if dark else 6.0 * float(th.outline), Color(0, 0, 0, 0.6))


## 처음 화면 왼쪽 아래의 키보드 안내 — 데스크톱 웹이 대상이라 읽혀야 한다(docs/adr/0012).
static func key_hint(ci: CanvasItem, vs: Vector2, text: String) -> void:
	var th := theme(game)
	var col: Color = th.title_col[1]
	var dark := col.get_luminance() < 0.5
	_str(ci, font(), Vector2(vs.x * 0.3, vs.y - 34), clean(text), 22, Color(col, 0.88), 0.0 if dark else 5.0 * float(th.outline), Color(0, 0, 0, 0.6))
