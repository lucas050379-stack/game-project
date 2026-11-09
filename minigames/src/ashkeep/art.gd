class_name AkArt
extends RefCounted

## 잿빛 요새의 용병단 그림 — 전부 코드(헥스 칸 · 유닛 말 · 카드 · 원소). 판 · 도감 · 허브 미리보기가 같이 쓴다.
## 영웅 · 몬스터 초상(`art/ashkeep/ak_h_<번호>.png` · `ak_m_<번호>.png`) · 배경(`ak_bg_*`)은 있으면 얹고 **없어도 돈다**(ADR-0005).
## 글자는 20px 아래로 쓰지 않는다. `·` `—` `×` `→` 금지(Jua).

const INK := Color8(16, 14, 18)
const STONE := Color8(78, 74, 80)
const ASH := Color8(196, 188, 176)
const EMBER := Color8(230, 120, 60)
const HEAD := Color8(226, 220, 208)     ## 제목 · 강조 글자(예전에는 다른 게임과 같은 금색 — #27)


static func font() -> Font:
	return UiKit.font()


static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color, outline: float = 0.0, oc: Color = INK) -> void:
	G2.text_mid(ci, pos, s, size, c, outline, oc)


static func rr(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0) -> void:
	G2.panel(ci, r, fill, edge, lw, rad)


static func hex_pts(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + k * PI / 3.0) * s)
	return pts


## 바닥 칸. kind: "floor" · "dark"(아직 안 열린 방) · "door" · "obs". trap · hl(고를 수 있음).
static func cell(ci: CanvasItem, c: Vector2, s: float, kind: String, trap: bool, hl: bool, t: float) -> void:
	var col := Color8(92, 86, 84)
	match kind:
		"dark":
			col = Color8(34, 30, 34)
		"door":
			col = Color8(120, 84, 50)
		"obs":
			col = Color8(52, 48, 52)
	# 돌바닥 — 칸마다 밝기가 조금 다르고 아래쪽이 어둡다(같은 회색 육각형이 줄지어 있었다, #23)
	var jit := fmod(absf(c.x * 12.9898 + c.y * 78.233), 1.0)
	col = col.lightened(jit * 0.1) if jit > 0.4 else col.darkened((0.4 - jit) * 0.2)
	G2.fill_fan(ci, hex_pts(c, s - 1.5), col, c)
	if kind == "floor":
		var hp := hex_pts(c, s - 1.5)
		ci.draw_colored_polygon(PackedVector2Array([hp[0], hp[1], hp[2], c]), Color(0, 0, 0, 0.12))
		ci.draw_line(c + Vector2(-s * 0.5, s * (jit - 0.5) * 0.6), c + Vector2(s * (jit - 0.2) * 0.5, s * 0.1), Color(0, 0, 0, 0.14), 1.5)
	if kind == "obs":
		ci.draw_circle(c, s * 0.45, Color8(70, 64, 66))
		ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.18, Color8(90, 84, 86))
	elif kind == "door":
		ci.draw_rect(Rect2(c - Vector2(s * 0.3, s * 0.45), Vector2(s * 0.6, s * 0.9)), Color8(80, 54, 30))
		ci.draw_circle(c + Vector2(s * 0.15, 0), s * 0.06, Color8(230, 200, 120))
	if trap and kind != "dark":
		for k in 4:
			var a := k * TAU / 4.0 + PI / 4.0
			ci.draw_line(c, c + Vector2.from_angle(a) * s * 0.4, Color8(200, 70, 50), 3.0)
	G2.stroke(ci, hex_pts(c, s - 1.0), Color(0, 0, 0, 0.5), 1.5)
	if hl:
		G2.stroke(ci, hex_pts(c, s - 3.0), EMBER.lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 5.0)), 3.0)   # 지금 골라야 하는 칸만 깜빡인다


## 유닛 말 — 둥근 판에 이름 첫 글자, 아래 체력 막대, 정예는 금테, 보스는 크게.
static func token(ci: CanvasItem, c: Vector2, s: float, u: Dictionary, name: String, col: Color, t: float, active: bool = false) -> void:
	var boss: bool = u.side == "mon" and int(u.k) in AkD.BOSSES
	var r := s * (0.78 if boss else 0.62)
	var tex := AkArt.img(("ak_h_%d" if u.side == "hero" else "ak_m_%d") % int(u.k))
	ci.draw_circle(c + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.4))
	ci.draw_circle(c, r + 2.5, Color8(232, 190, 90) if bool(u.elite) or boss else INK)
	if tex != null:
		ci.draw_circle(c, r, col.darkened(0.3))
		ci.draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
	else:
		ci.draw_circle(c, r, col)
		text(ci, c, name.substr(0, 1), 22, Color(1, 1, 1), 3)
	if active:
		ci.draw_arc(c, r + 6, 0, TAU, 32, HEAD, 3.0)
	# 체력 막대
	var w := s * 1.3
	var bar := Rect2(c + Vector2(-w * 0.5, r + 3), Vector2(w, 7))
	ci.draw_rect(bar.grow(1), INK)
	ci.draw_rect(bar, Color8(60, 30, 30))
	ci.draw_rect(Rect2(bar.position, Vector2(w * clampf(float(u.hp) / float(u.max), 0.0, 1.0), 7)), Color8(200, 60, 46) if u.side == "mon" else HEAD)
	# 상태 점
	var n := 0
	for k in u.st:
		var dc := Color8(120, 200, 90)
		match String(k):
			"bleed":
				dc = Color8(220, 40, 40)
			"stun":
				dc = Color8(250, 230, 90)
			"immob":
				dc = Color8(150, 110, 60)
			"muddle":
				dc = Color8(200, 120, 220)
			"mark":
				dc = Color8(250, 250, 250)
			"inv":
				dc = Color8(120, 120, 200)
			"strong":
				dc = Color8(250, 160, 60)
		ci.draw_circle(c + Vector2(-r + n * 9, -r - 2), 4.5, dc)
		n += 1
	if int(u.s) > 0:
		ci.draw_circle(c + Vector2(r - 2, -r + 4), 9, Color8(120, 150, 200))
		text(ci, c + Vector2(r - 2, -r + 4), str(int(u.s)), 20, Color(1, 1, 1), 2)


static func elem(ci: CanvasItem, c: Vector2, rad: float, e: int, state: int) -> void:
	var col: Color = AkD.ELEM_COL[e]
	var a: float = [0.18, 0.55, 1.0][state]
	ci.draw_circle(c, rad + 2, INK)
	ci.draw_circle(c, rad, Color(col, a))
	text(ci, c, AkD.ELEM_NAME[e], 20, Color(1, 1, 1, 0.4 + 0.6 * a), 2)


## 영웅 카드(고르기 창 · 도감). sel: 0 · 1(선도) · 2(둘째). 위 · 아래 칸이 갈려 있다.
static func card(ci: CanvasItem, r: Rect2, c: Dictionary, sel: int = 0, dim: bool = false, half_hl: int = -1) -> void:
	var hc: Color = AkD.HEROES[int(c.hero)][3]
	rr(ci, Rect2(r.position + Vector2(0, 4), r.size), 10, Color(0, 0, 0, 0.4))
	rr(ci, r, 10, Color8(40, 36, 40), Color(1, 1, 1) if sel > 0 else hc, 4.0 if sel > 0 else 2.0)
	var head := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 30))
	rr(ci, head, 8, hc.darkened(0.25))
	text(ci, head.position + Vector2(22, 15), str(int(c.init)), 22, HEAD, 3)
	text(ci, head.position + Vector2(head.size.x * 0.5 + 12, 15), String(c.name), 20, Color(1, 1, 1), 3)
	var mid := r.position.y + 34 + (r.size.y - 34) * 0.5
	for k in 2:
		var half := Rect2(r.position.x + 6, (r.position.y + 38) if k == 0 else mid + 2, r.size.x - 12, (r.size.y - 44) * 0.5)
		if half_hl == k:
			rr(ci, half, 6, Color8(110, 60, 36))
		var steps: Array = c.top if k == 0 else c.bot
		var lost: bool = c.top_lost if k == 0 else c.bot_lost
		var lines := UiBook.wrap_text(AkD.half_text(steps, lost), 20, half.size.x - 8)
		for j in mini(lines.size(), int(half.size.y / 22)):
			text(ci, Vector2(half.get_center().x, half.position.y + 12 + j * 22), String(lines[j]), 20, Color(1, 1, 1, 0.92) if k == 0 else Color8(220, 220, 200))
	ci.draw_line(Vector2(r.position.x + 10, mid), Vector2(r.end.x - 10, mid), Color(1, 1, 1, 0.25), 2.0)
	if sel > 0:
		ci.draw_circle(r.position + Vector2(r.size.x - 16, 16), 13, Color(1, 1, 1))
		text(ci, r.position + Vector2(r.size.x - 16, 16), "1" if sel == 1 else "2", 20, INK)
	if dim:
		rr(ci, r, 10, Color(0, 0, 0, 0.5))


static var _tex := {}


static func img(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/ashkeep/%s.png" % name
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = tx
	return tx
