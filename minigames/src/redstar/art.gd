class_name RsArt
extends RefCounted

## 붉은 별 개척단 그림 — 전부 코드(카드 · 헥스 칸 · 타일 · 자원 · 지표 막대). 판 · 도감 · 허브 미리보기가 같이 쓴다.
## 카드 그림(`art/redstar/rs_c_<번호>.png`) · 배경(`rs_bg_*`)은 있으면 얹고 **없어도 돈다**(ADR-0005).
## 글자는 20px 아래로 쓰지 않는다. `·` `—` `×` `→` 금지(Jua).

const INK := Color8(24, 16, 14)
const PANEL := Color8(40, 26, 24)
const SAND := Color8(236, 214, 190)
const RUST := Color8(176, 74, 44)
const HEAD := Color8(244, 228, 216)     ## 제목 · 강조 글자(예전에는 다른 게임과 같은 금색이었다 — #27)
const ACCENT := Color8(240, 150, 110)   ## 고를 수 있는 것 · 지금 차례(예전에는 초록 깜빡임 — #29)


static func font() -> Font:
	return UiKit.font()


static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color, outline: float = 0.0, oc: Color = INK) -> void:
	G2.text_mid(ci, pos, s, size, c, outline, oc)


static func rr(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0) -> void:
	G2.panel(ci, r, fill, edge, lw, rad)


## 자원 아이콘 — 색 원 안에 모양(크레딧 동전 · 금속 막대 · 합금 별 · 식물 잎 · 전력 번개 · 열 불꽃).
static func res_icon(ci: CanvasItem, c: Vector2, rad: float, r: int) -> void:
	var col: Color = RsD.RES_COL[r]
	ci.draw_circle(c, rad + 1.5, INK)
	ci.draw_circle(c, rad, col)
	var w := Color(1, 1, 1, 0.85)
	var k := rad * 0.5
	match r:
		0:
			ci.draw_circle(c, k, col.darkened(0.25))
		1:
			ci.draw_rect(Rect2(c - Vector2(k, k * 0.45), Vector2(k * 2, k * 0.9)), w)
		2:
			for a in 4:
				ci.draw_line(c, c + Vector2.from_angle(a * PI / 4.0) * k, w, 2.0)
				ci.draw_line(c, c - Vector2.from_angle(a * PI / 4.0) * k, w, 2.0)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.7, 0), c + Vector2(0, k), c + Vector2(-k * 0.7, 0)]), w)
		4:
			ci.draw_polyline(PackedVector2Array([c + Vector2(k * 0.3, -k), c + Vector2(-k * 0.4, 0), c + Vector2(k * 0.4, 0), c + Vector2(-k * 0.3, k)]), w, 2.0)
		5:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.6, k * 0.6), c + Vector2(-k * 0.6, k * 0.6)]), w)


## 태그 표시 — 작은 색 상자 안에 태그 이름.
static func tag_chip(ci: CanvasItem, pos: Vector2, t: int) -> float:
	# 어두운 표지에 색 띠 하나 — 태그마다 통째로 다른 색을 칠하면 무지개 칩이 된다(#30)
	var s: String = RsD.TAG_NAME[t]
	var w := font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16
	ci.draw_rect(Rect2(pos, Vector2(w, 24)), Color8(46, 30, 30))
	ci.draw_rect(Rect2(pos, Vector2(5, 24)), RsD.TAG_COL[t].lightened(0.15))
	text(ci, pos + Vector2(w * 0.5 + 3, 12), s, 20, HEAD, 0)
	return w


## 카드(손패 · 도감 · 고르기 창). state: 0 보통 · 1 고름 · 2 낼 수 있음 · 3 흐림.
static func card(ci: CanvasItem, r: Rect2, c: Dictionary, state: int = 0, t: float = 0.0, cost_now: int = -1) -> void:
	rr(ci, Rect2(r.position + Vector2(0, 4), r.size), 10, Color(0, 0, 0, 0.35))
	var kc: Color = RsD.KIND_COL[int(c.kind)]
	var edge := INK
	var lw := 2.0
	if state == 1:
		edge = Color(1, 1, 1)
		lw = 4.0
	elif state == 2:
		edge = ACCENT
		lw = 3.5
	rr(ci, r, 10, SAND, edge, lw)
	var head := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 26))
	rr(ci, head, 8, kc)
	# 비용 — 왼쪽 위 동전
	var cost := int(c.cost) if cost_now < 0 else cost_now
	ci.draw_circle(head.position + Vector2(14, 13), 13, INK)
	ci.draw_circle(head.position + Vector2(14, 13), 11.5, RsD.RES_COL[0])
	text(ci, head.position + Vector2(14, 13), str(cost), 20, INK)
	text(ci, head.position + Vector2(head.size.x * 0.5 + 12, 13), RsD.KIND_NAME[int(c.kind)], 20, Color(1, 1, 1), 3)
	var tex := img("rs_c_%d" % int(c.id))
	var y := head.end.y + 4
	if tex != null and r.size.y >= 150:
		var pic := Rect2(r.position.x + 5, y, r.size.x - 10, (r.size.x - 10) * 2.0 / 3.0 if r.size.y > 170 else r.size.y * 0.3)
		ci.draw_texture_rect(tex, pic, false)
		y = pic.end.y + 4
	# 이름 — 넘치면 두 줄
	var nm := String(c.name)
	if font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > r.size.x - 8 and nm.contains(" "):
		var cut := nm.rfind(" ")
		text(ci, Vector2(r.get_center().x, y + 12), nm.substr(0, cut), 20, INK)
		text(ci, Vector2(r.get_center().x, y + 33), nm.substr(cut + 1), 20, INK)
		y += 46
	else:
		text(ci, Vector2(r.get_center().x, y + 14), nm, 20, INK)
		y += 30
	# 태그
	var x := r.position.x + 5
	for tg in c.tags:
		if x > r.end.x - 30:
			break
		x += tag_chip(ci, Vector2(x, y), int(tg)) + 3
	y += 28
	if not c.req.is_empty() and y < r.end.y - 22:
		text(ci, Vector2(r.get_center().x, y + 10), RsD.req_text(c.req), 20, Color8(150, 50, 30))
		y += 24
	if r.size.y > 170:
		var lines := UiBook.wrap_text(RsD.eff_text(c.eff, int(c.pts)), 20, r.size.x - 12)
		for k in lines.size():
			if y + 22 > r.end.y:
				break
			text(ci, Vector2(r.get_center().x, y + 10), String(lines[k]), 20, INK)
			y += 22
	if state == 3:
		rr(ci, r, 10, Color(0, 0, 0, 0.45))


## 헥스 꼭짓점(뾰족한 쪽이 위).
static func hex_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + k * PI / 3.0) * s)
	return pts


## 지도 칸 하나. tile = {} 또는 {kind, owner}. hl = 놓을 수 있는 자리 강조.
static func cell(ci: CanvasItem, c: Vector2, s: float, kind: int, tile: Dictionary, bonus: Dictionary, hl: bool, t: float) -> void:
	var base: Color = [Color8(178, 92, 58), Color8(120, 74, 60), Color8(150, 104, 80), Color8(110, 52, 40), Color8(140, 120, 104)][kind]
	if tile.is_empty():
		G2.fill_fan(ci, hex_pts(c, s - 1.5), base, c)
		if kind == 1:
			G2.stroke(ci, hex_pts(c, s * 0.7), Color8(110, 170, 230, 160), 2.0)
		# 보너스 — 작은 아이콘
		var n := 0
		for r in bonus:
			for k in int(bonus[r]):
				var p := c + Vector2((n - 0.5) * s * 0.42, s * 0.3)
				if str(r) == "card":
					ci.draw_rect(Rect2(p - Vector2(5, 7), Vector2(10, 14)), Color8(240, 230, 210))
				else:
					res_icon(ci, p, s * 0.16, int(r))
				n += 1
	else:
		var col := Color8(60, 120, 220)
		match String(tile.kind):
			"green":
				col = Color8(80, 160, 80)
			"city":
				col = Color8(150, 150, 165)
		G2.fill_fan(ci, hex_pts(c, s - 1.5), col, c)
		if String(tile.kind) == "city":
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.45 + k * s * 0.32, -s * 0.1 - (k % 2) * s * 0.2), Vector2(s * 0.24, s * 0.35 + (k % 2) * s * 0.2)), Color8(90, 90, 105))
		elif String(tile.kind) == "green":
			for k in 3:
				ci.draw_circle(c + Vector2((k - 1) * s * 0.3, -s * 0.05 + (k % 2) * s * 0.12), s * 0.18, Color8(50, 120, 60))
		if int(tile.owner) >= 0:
			ci.draw_circle(c + Vector2(0, s * 0.45), s * 0.17, INK)
			ci.draw_circle(c + Vector2(0, s * 0.45), s * 0.13, RsD.PLAYER_COL[int(tile.owner)])
	G2.stroke(ci, hex_pts(c, s - 1.0), Color(0, 0, 0, 0.45), 1.5)
	if hl:
		G2.stroke(ci, hex_pts(c, s - 3.0), ACCENT.lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 5.0)), 3.0)   # 지금 골라야 하는 자리만 깜빡인다


static var _tex := {}


static func img(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/redstar/%s.png" % name
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = tx
	return tx
