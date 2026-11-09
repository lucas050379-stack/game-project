class_name UiKit
extends RefCounted

## 다섯 게임이 같이 쓰는 처음 화면 단추 — "게임 선택"(왼쪽 위) · "음량"(오른쪽 위) · "시작"(오른쪽 아래).
## 자리는 `Hub.std_rect`, 그리기는 여기 하나입니다(사용자 요청 11-08 — 자리를 맞춘 뒤 "디자이너처럼 단추를 다듬어 달라").
##
## 디자인 원칙
##   · **모양으로 읽힌다** — 단추마다 아이콘(게임 선택 = 네모 넷, 음량 = 스피커와 물결, 시작 = 재생 삼각형)을 글자 앞에 둔다.
##   · **떠 있다** — 아래 그림자 · 위가 밝은 그라데이션 · 위쪽 광택 띠 · 또렷한 테두리. 마우스를 올리면 밝아지며 2px 들린다.
##   · **시작이 주인공** — 크고, 테두리 빛이 천천히 숨 쉬고(0.6~1.0 — 0 까지 내리면 깜빡여 보인다), 3초마다 반짝임이 한 번 지나간다.
##   · **화풍은 게임 것** — 모양 · 아이콘 · 자리는 같게, 색과 모서리는 게임 테마(`theme()`)를 따른다.
## 글자는 Jua 라 `·` `—` `×` `→` 를 쓰지 마세요. 아이콘은 전부 도형이라 글꼴과 상관없다.


## 게임별 테마. 키: hub · vol · start 각각의 몸통 색, 글자 색, 테두리 색, 모서리, 빛 색.
static func theme(game: String) -> Dictionary:
	match game:
		"jelly":
			return {rad = 26.0, edge = Color8(70, 40, 90), ink = Color8(70, 40, 90),
					hub = Color8(255, 168, 92), vol = Color8(255, 250, 252), start = Color8(104, 208, 92),
					hub_text = Color(1, 1, 1), vol_text = Color8(70, 40, 90), start_text = Color(1, 1, 1),
					menu = Color8(150, 112, 206), glow = Color8(255, 240, 140)}
		"sky":
			return {rad = 4.0, edge = Color8(110, 220, 255), ink = Color8(6, 10, 18),
					hub = Color8(14, 22, 36), vol = Color8(14, 22, 36), start = Color8(10, 40, 60),
					hub_text = Color8(170, 220, 240), vol_text = Color8(170, 220, 240), start_text = Color8(200, 250, 255),
					menu = Color8(26, 78, 120), glow = Color8(90, 220, 255)}
		"runner":
			return {rad = 18.0, edge = Color8(255, 255, 255, 150), ink = Color8(14, 18, 40),
					hub = Color8(64, 74, 132), vol = Color8(64, 74, 132), start = Color8(38, 190, 96),
					hub_text = Color(1, 1, 1), vol_text = Color(1, 1, 1), start_text = Color(1, 1, 1),
					menu = Color8(64, 98, 184), glow = Color8(140, 255, 170)}
		"gangho":
			return {rad = 6.0, edge = Color8(40, 30, 24), ink = Color8(40, 30, 24),
					hub = Color8(226, 212, 184), vol = Color8(226, 212, 184), start = Color8(168, 40, 36),
					hub_text = Color8(40, 30, 24), vol_text = Color8(40, 30, 24), start_text = Color8(250, 238, 214),
					menu = Color8(104, 86, 66), glow = Color8(255, 190, 120)}
		"neon":
			return {rad = 10.0, edge = Color8(90, 230, 255), ink = Color8(6, 10, 24),
					hub = Color8(14, 22, 44), vol = Color8(14, 22, 44), start = Color8(200, 40, 140),
					hub_text = Color8(170, 240, 255), vol_text = Color8(170, 240, 255), start_text = Color(1, 1, 1),
					menu = Color8(24, 56, 104), glow = Color8(90, 230, 255)}
		"arcana":
			return {rad = 20.0, edge = Color8(255, 220, 140), ink = Color8(40, 24, 64),
					hub = Color8(92, 66, 150), vol = Color8(92, 66, 150), start = Color8(214, 160, 60),
					hub_text = Color(1, 1, 1), vol_text = Color(1, 1, 1), start_text = Color8(50, 28, 70),
					menu = Color8(92, 66, 150), glow = Color8(255, 220, 140)}
	# 허브
	return {rad = 24.0, edge = Color8(70, 40, 90), ink = Color8(70, 40, 90),
			hub = Color8(255, 168, 92), vol = Color8(255, 250, 252), start = Color8(104, 208, 92),
			hub_text = Color(1, 1, 1), vol_text = Color8(70, 40, 90), start_text = Color(1, 1, 1),
			menu = Color8(150, 112, 206), glow = Color8(255, 240, 140)}


## 게임 이름 색(글자 · 소개 줄). 게임마다 색만 다르고 나머지(자리 · 크기 · 테두리 · 그림자 · 움직임)는 같다.
const TITLE_COL := {
	"jelly": [Color8(255, 120, 180), Color(1, 1, 1)],
	"sky": [Color8(200, 245, 255), Color8(150, 200, 225)],
	"runner": [Color8(255, 214, 90), Color(1, 1, 1)],
	"gangho": [Color8(240, 228, 200), Color8(240, 234, 220)],
	"arcana": [Color8(255, 226, 150), Color(1, 1, 1)],
	"neon": [Color8(120, 240, 255), Color8(210, 245, 255)],
}


## 처음 화면 왼쪽의 게임 이름 + 소개 한 줄 — **다섯 게임이 같은 방식**(사용자 요청 11-08 — "게임 이름 같은 것의 성격이 제각각").
## 자리: 가로 = 왼쪽 단 가운데(x 0.3) · y 150, 세로 = 가운데 위. 글자 88 · 두꺼운 테두리 · 아래 그림자 · 글자가 차례로 살짝 들썩.
## 돌려주는 값: 소개 줄 아래 끝 y(게임 그림을 그 밑에 놓으라고).
static func title(ci: CanvasItem, vs: Vector2, game: String, name: String, sub: String, t: float) -> float:
	var th := theme(game)
	var cols: Array = TITLE_COL.get(game, [Color(1, 1, 1), Color(1, 1, 1)])
	var cx := vs.x * 0.3 if vs.x > vs.y else vs.x * 0.5
	var cy := 150.0 if vs.x > vs.y else vs.y * 0.14
	var size := 88.0
	var f := UiKit.font()
	var total := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	# 긴 이름(아르카나 컬렉션)은 왼쪽 단 폭에 맞춰 줄인다 — 오른쪽 메뉴 줄을 넘지 않게
	var maxw := vs.x * 0.5 - 60.0 if vs.x > vs.y else vs.x - 60.0
	if total > maxw:
		size = floorf(size * maxw / total)
		total = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var x := cx - total * 0.5
	for k in name.length():
		var ch := name[k]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		if ch != " ":
			var bob := maxf(0.0, sin(t * 2.2 - k * 0.55)) * 7.0
			var p := Vector2(x + w * 0.5, cy - bob)
			G2.text_mid(ci, p + Vector2(0, 7), ch, size, Color(0, 0, 0, 0.32), 20, Color(0, 0, 0, 0.32))
			G2.text_mid(ci, p, ch, size, cols[0], 18, th.ink)
		x += w
	G2.text_mid(ci, Vector2(cx, cy + 68), sub, 24, cols[1], 6, th.ink)
	return cy + 84


## 처음 화면 오른쪽 메뉴 줄의 j 번째 단추 자리 — 다섯 게임 같은 크기 · 간격.
static func menu_rect(vs: Vector2, j: int) -> Rect2:
	if vs.x > vs.y:
		return Rect2(vs.x * 0.72 - 170, 200 + j * 84.0, 340, 66)
	return Rect2(vs.x * 0.5 - 170, vs.y * 0.55 + j * 84.0, 340, 66)


## 메뉴 단추(아이콘 없음) — 몸통 색만 주면 글자 색은 밝기로 정한다.
static func menu(ci: CanvasItem, r: Rect2, label: String, fill: Color, game: String, t: float) -> void:
	var th := theme(game)
	# 보조 메뉴는 게임마다 한 색(`menu`) — 강조색은 "시작" 단추에만(docs/adr/0008, 11-09). fill 은 테마에 menu 가 없을 때만 쓴다.
	fill = th.get("menu", fill)
	var tc := Color8(50, 30, 60) if fill.get_luminance() > 0.72 else Color(1, 1, 1)
	draw(ci, r, "menu", label, fill, tc, th, r.has_point(ci.get_local_mouse_position()), t)


## **게임 안쪽 화면의 모든 단추**도 이 모양을 쓴다(사용자 지적 11-08 — "첫 화면까지는 입체적인데 그다음부터 단색이라 통일성이 없다").
## 게임마다 있는 단추 함수(젤리팝 · 강호일생 · 아르카나 `_btn`, 스카이 `_big_btn`, 러너 `_draw_button`)가 이것을 부른다.
## size < 0 이면 단추 높이에 맞춘 글자 크기. enabled = false 면 어둡게 · 글자 흐리게 · 마우스 반응 없음.
static func plain(ci: CanvasItem, r: Rect2, label: String, fill: Color, game: String, t: float, enabled: bool = true,
		size: float = -1.0) -> void:
	var th := theme(game)
	var f := fill if enabled else fill.darkened(0.5).lerp(Color(0.3, 0.3, 0.35), 0.4)
	var tc := Color8(50, 30, 60) if f.get_luminance() > 0.72 else Color(1, 1, 1)
	if not enabled:
		tc = Color(tc, 0.45)
	draw(ci, r, "menu", label, f, tc, th, enabled and r.has_point(ci.get_local_mouse_position()), t, size)


## 처음 화면 단추 하나. kind = "hub" · "vol" · "start". label 이 비면 기본 글(게임 선택 · 음량 · 시작).
static func button(ci: CanvasItem, vs: Vector2, kind: String, game: String, t: float, label: String = "") -> void:
	var r := Hub.std_rect(kind, vs)
	var th := theme(game)
	if label == "":
		label = {"hub": "게임 선택", "vol": "음량", "start": "시작"}[kind]
	var hot := r.has_point(ci.get_local_mouse_position())
	draw(ci, r, kind, label, th[kind], th[kind + "_text"], th, hot, t)


## 단추 그리기(자리를 직접 줄 때). fill = 몸통 색, tc = 글자 색.
static func draw(ci: CanvasItem, r: Rect2, kind: String, label: String, fill: Color, tc: Color, th: Dictionary,
		hot: bool, t: float, text_size: float = -1.0) -> void:
	var rad: float = minf(float(th.rad), r.size.y * 0.5)
	var primary := kind == "start"
	if hot:
		r.position.y -= 2.0
		fill = fill.lightened(0.08)
	# 빛 테두리(시작만) — 천천히 숨 쉰다
	if primary:
		var gc: Color = th.glow
		var br := 0.6 + 0.4 * (0.5 + 0.5 * sin(t * 2.4))
		for k in 4:
			var g := r.grow(4.0 + k * 4.0)
			_rr(ci, g, rad + 4.0 + k * 4.0, Color(gc, 0.10 * br * (1.0 - k * 0.22)))
	# 그림자
	_rr(ci, Rect2(r.position + Vector2(0, 5), r.size), rad, Color(0, 0, 0, 0.32))
	# 몸통 — 위가 밝은 그라데이션(부채꼴로 채운다 — draw_polygon 은 모서리 반지름이 높이의 절반이면 꼭짓점이 겹쳐 삼각분할에 실패했다)
	var pts := G2.round_rect(r, rad)
	_fan_grad(ci, pts, r, fill.lightened(0.2), fill.darkened(0.16))
	# 위쪽 광택 띠
	var gl := Rect2(r.position + Vector2(rad * 0.5 + 4, 3), Vector2(r.size.x - rad - 8, r.size.y * 0.38))
	_rr(ci, gl, minf(rad, gl.size.y * 0.5), Color(1, 1, 1, 0.16 if fill.get_luminance() < 0.7 else 0.4))
	# 반짝임(시작만) — 3초마다 한 번 비스듬히 지나간다
	if primary:
		var s := fposmod(t, 3.0) / 0.7
		if s < 1.0:
			var x := r.position.x + (r.size.x + r.size.y) * s - r.size.y
			var band := PackedVector2Array([Vector2(x, r.end.y - 3), Vector2(x + r.size.y * 0.5, r.position.y + 3),
					Vector2(x + r.size.y * 0.5 + 18, r.position.y + 3), Vector2(x + 18, r.end.y - 3)])
			var clipped := Geometry2D.intersect_polygons(band, G2.round_rect(r.grow(-2), maxf(0.0, rad - 2)))
			for poly: PackedVector2Array in clipped:
				var cen := Vector2.ZERO
				for p in poly:
					cen += p
				G2.fill_fan(ci, poly, Color(1, 1, 1, 0.28 * sin(s * PI)), cen / maxf(1.0, poly.size()))
	# 테두리
	G2.stroke(ci, pts, th.edge, 3.0 if primary else 2.2)
	# 아이콘 + 글(label 이 비면 몸통만 — 러너처럼 글을 따로 얹는 단추)
	if label == "" and not (kind in ["hub", "vol", "start"]):
		return
	var size := text_size if text_size > 0.0 else r.size.y * (0.4 if primary else 0.44)
	var f := UiKit.font()
	var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	# 단추 폭을 넘는 글은 줄인다
	if tw > r.size.x - 20.0 and tw > 0.0:
		size = floorf(size * (r.size.x - 20.0) / tw)
		tw = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	# 아이콘은 hub · vol · start 만. 그 밖("menu" 등 보조 메뉴)은 글만 가운데
	var has_icon := kind in ["hub", "vol", "start"]
	var isz := r.size.y * (0.5 if primary else 0.46) if has_icon else 0.0
	var gap := 10.0 if has_icon else 0.0
	var total := isz + gap + tw
	var x0 := r.get_center().x - total * 0.5
	var ic := Vector2(x0 + isz * 0.5, r.get_center().y)
	match kind:
		"hub":
			_icon_grid(ci, ic, isz, tc)
		"vol":
			_icon_speaker(ci, ic, isz, tc, Sv.music or Sv.sfx)
		"start":
			_icon_play(ci, ic, isz, tc, fill)
	var dark_text := tc.get_luminance() < 0.5
	G2.text_mid(ci, Vector2(x0 + isz + gap + tw * 0.5, r.get_center().y), label, size, tc,
			0.0 if dark_text else size * 0.16, Color(th.ink, 0.8))


static func _rr(ci: CanvasItem, r: Rect2, rad: float, c: Color) -> void:
	G2.fill_fan(ci, G2.round_rect(r, minf(rad, minf(r.size.x, r.size.y) * 0.5)), c, r.get_center())


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
		ci.draw_colored_polygon(G2.round_rect(Rect2(p, Vector2(q, q)), q * 0.28), col)


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


# ==================== 글꼴 · 글자 (다섯 게임 공통 — docs/adr/0007) ====================

## 앱 전체에 글꼴은 Jua 한 벌이다. 브라우저에는 한글 시스템 글꼴이 없어 파일을 싣는다.
static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://font/Jua-Regular.ttf")
	return _font


## Jua 에 없는 기호를 있는 글자로 바꾼다(웹에서만 네모로 나오고 데스크톱은 시스템 글꼴이 메워 줘서 안 보인다).
## 게임마다 따로 두던 표(스카이 SaG2 · 러너 WrIcons)를 합쳤다. 앞의 것이 먼저 바뀐다(" · " 가 "·" 보다 먼저).
const GLYPH_SWAP := {" · ": ", ", "·": ",", " — ": " - ", "—": "-", "→": ">", "←": "<", "↑": "^", "↓": "v",
		"▸": ">", "…": "...", "「": "'", "」": "'", "×": "x", "★": "*", "−": "-", "₩": "W", "÷": "/"}


static func clean(s: String) -> String:
	for k in GLYPH_SWAP:
		if s.contains(k):
			s = s.replace(k, GLYPH_SWAP[k])
	return s


## 처음 화면의 "내 기록 한 줄" — 다섯 게임 같은 자리(오른쪽 메뉴 바로 아래) · 같은 크기(docs/adr/0008, 11-09).
static func record_line(ci: CanvasItem, vs: Vector2, text: String) -> void:
	if text == "":
		return
	var r := menu_rect(vs, 3)
	G2.text_mid(ci, Vector2(r.get_center().x, r.end.y + 34), text, 24, Color(1, 1, 1, 0.92), 6, Color(0, 0, 0, 0.6))


## 처음 화면 왼쪽 아래의 키보드 안내 — 데스크톱 웹이 대상이라 읽혀야 한다(docs/adr/0012).
static func key_hint(ci: CanvasItem, vs: Vector2, text: String) -> void:
	G2.text_mid(ci, Vector2(vs.x * 0.3, vs.y - 34), text, 22, Color(1, 1, 1, 0.88), 5, Color(0, 0, 0, 0.6))
