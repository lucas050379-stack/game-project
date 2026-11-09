class_name EmArt
extends RefCounted

## 제국 연대기 그림 — 전부 코드(카드 · 불가사의 · 토큰 · 자원 칩). 판 · 도감 · 허브 미리보기가 같이 쓴다.
## 불가사의 일러스트는 나중에 AI 그림(`art/empire/em_w_<번호>.png`)을 얹을 자리만 있고, **없어도 돈다**(ADR-0005).
## 글자는 20px 아래로 쓰지 않는다. `·` `—` `×` `→` 금지(Jua).

const INK := Color8(30, 22, 18)
const PARCH := Color8(240, 226, 196)
const GOLD := Color8(232, 188, 80)
const BACK_COL := [Color8(120, 82, 46), Color8(70, 96, 140), Color8(110, 50, 70)]   ## 시대별 뒷면


static func font() -> Font:
	return UiKit.font()


static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color, outline: float = 0.0, oc: Color = INK) -> void:
	G2.text_mid(ci, pos, s, size, c, outline, oc)


static func rr(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0) -> void:
	G2.panel(ci, r, fill, edge, lw, rad)


## 자원 칩 — 동그라미(나무 · 점토 · 돌) / 네모(유리 · 양피지). 색을 못 가려도 모양으로 원자재 · 가공품이 갈린다.
static func res_chip(ci: CanvasItem, c: Vector2, rad: float, r: int) -> void:
	var col: Color = EmD.RES_COL[r]
	if r in EmD.RAW:
		ci.draw_circle(c, rad + 1.5, INK)
		ci.draw_circle(c, rad, col)
		ci.draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.35, col.lightened(0.35))
	else:
		var q := Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		ci.draw_rect(q.grow(1.5), INK)
		ci.draw_rect(q, col)
		ci.draw_rect(Rect2(q.position + Vector2(2, 2), Vector2(rad * 0.7, rad * 0.5)), col.lightened(0.4))


static func coin(ci: CanvasItem, c: Vector2, rad: float, n: int = -1) -> void:
	ci.draw_circle(c, rad + 1.5, INK)
	ci.draw_circle(c, rad, GOLD)
	ci.draw_circle(c, rad * 0.72, GOLD.lightened(0.2))
	if n >= 0:
		text(ci, c, str(n), maxf(20.0, rad * 1.5), INK)


## 비용 줄 — 돈 동전 하나(숫자) + 자원 칩을 개수만큼. 가운데 정렬.
static func cost_row(ci: CanvasItem, c: Vector2, coin_n: int, cost: Array, rad: float = 8.0) -> void:
	var items := []
	if coin_n > 0:
		items.append(-1)
	for r in EmD.N_RES:
		for k in int(cost[r]):
			items.append(r)
	if items.is_empty():
		text(ci, c, "무료", 20, Color(1, 1, 1, 0.9), 3)
		return
	var step := rad * 2.0 + 3.0
	var x0 := c.x - (items.size() - 1) * step * 0.5
	for k in items.size():
		var p := Vector2(x0 + k * step, c.y)
		if int(items[k]) < 0:
			coin(ci, p, rad + 2.0, coin_n)
		else:
			res_chip(ci, p, rad, int(items[k]))


## 카드 머리 띠에 쓰는 짧은 효과 글.
static func short_eff(c: Dictionary) -> String:
	var e: Dictionary = c.eff
	if e.has("prod"):
		var s := []
		for r in EmD.N_RES:
			if int(e.prod[r]) > 0:
				s.append("%s%d" % [EmD.RES_NAME[r], int(e.prod[r])])
		return " ".join(s)
	if e.has("pick"):
		return "자원 택1"
	if e.has("sci"):
		return String(EmD.SCI_NAME[int(e.sci)]) + ("  %d점" % int(e.pts) if e.has("pts") else "")
	if e.has("mil"):
		return "군사%d" % int(e.mil)
	if e.has("guild"):
		return "길드"
	if e.has("pts") and int(c.kind) == EmD.K.BLUE:
		return "%d점" % int(e.pts)
	if e.has("coin"):
		return "돈%d" % int(e.coin)
	if e.has("fix") or e.has("buy_minus"):
		return "교역"
	if e.has("disc"):
		return "버리기+"
	if e.has("per_brown") or e.has("opp_yellow") or e.has("per_red_pts"):
		return "돈 점수"
	return ""


## 카드 앞면 · 뒷면. state: 0 보통 · 1 고름 · 2 지을 수 있음 · 3 흐림.
static func card(ci: CanvasItem, r: Rect2, c: Dictionary, face: bool, state: int = 0, t: float = 0.0, age: int = -1) -> void:
	# 그림자
	rr(ci, Rect2(r.position + Vector2(0, 4), r.size), 10, Color(0, 0, 0, 0.35))
	if not face:
		var bc: Color = BACK_COL[clampi(age if age >= 0 else int(c.age), 0, 2)]
		rr(ci, r, 10, bc, GOLD.darkened(0.2), 2.5)
		rr(ci, r.grow(-8), 6, bc.darkened(0.2), GOLD.darkened(0.4), 1.5)
		text(ci, r.get_center(), ["I", "II", "III"][clampi(age if age >= 0 else int(c.age), 0, 2)], 30, GOLD, 4)
		return
	var kc: Color = EmD.KIND_COL[int(c.kind)]
	var edge := INK
	var lw := 2.0
	if state == 1:
		edge = Color(1, 1, 1)
		lw = 4.0
	elif state == 2:
		edge = Color8(140, 255, 140).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(t * 4.0))
		lw = 3.0
	rr(ci, r, 10, PARCH.darkened(0.04), edge, lw)
	var head := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 26))
	rr(ci, head, 8, kc)
	text(ci, head.get_center(), short_eff(c), 20, Color(1, 1, 1), 4)
	# 이름 — 넘치면 두 줄
	var nm := String(c.name)
	var f := font()
	var mid := Vector2(r.get_center().x, r.position.y + 48)
	if f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > r.size.x - 8 and nm.contains(" "):
		var cut := nm.find(" ")
		text(ci, mid, nm.substr(0, cut), 20, INK)
		text(ci, mid + Vector2(0, 21), nm.substr(cut + 1), 20, INK)
	else:
		text(ci, mid + Vector2(0, 8), nm, 20, INK)
	cost_row(ci, Vector2(r.get_center().x, r.end.y - 14), int(c.coin), c.cost, 7.0)
	if state == 3:
		rr(ci, r, 10, Color(0, 0, 0, 0.45))


## 불가사의 타일 — 가로로 긴 판. state: 0 보통 · 1 지음 · 2 못 짓게 됨 · 3 지을 수 있음(빛남).
static func wonder(ci: CanvasItem, r: Rect2, w: Dictionary, state: int = 0, t: float = 0.0, big: bool = false) -> void:
	rr(ci, Rect2(r.position + Vector2(0, 3), r.size), 10, Color(0, 0, 0, 0.35))
	var body := Color8(84, 62, 40) if state != 1 else Color8(150, 112, 50)
	var edge := GOLD if state != 3 else Color8(140, 255, 140).lerp(GOLD, 0.5 + 0.5 * sin(t * 4.0))
	rr(ci, r, 10, body, edge, 2.5 if state != 3 else 3.5)
	var tex := img("em_w_%d" % int(w.id))
	if tex != null and big:
		var pic := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.y * 0.45))
		ci.draw_texture_rect(tex, pic, false)
	var y := r.position.y + (r.size.y * 0.5 + 18 if tex != null and big else 22.0)
	var nm := String(w.name)
	# 좁은 칸에서 넘치면 첫 낱말만(알렉산드리아 도서관 → 알렉산드리아)
	if font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > r.size.x - 8 and nm.contains(" "):
		nm = nm.substr(0, nm.find(" "))
	text(ci, Vector2(r.get_center().x, y), nm, 22 if big else 20, Color8(255, 236, 190), 4)
	if big:
		var lines := UiBook.wrap_text(EmD.eff_text(w.eff), 20, r.size.x - 20)
		for k in lines.size():
			text(ci, Vector2(r.get_center().x, y + 30 + k * 24), String(lines[k]), 20, Color(1, 1, 1, 0.9))
		cost_row(ci, Vector2(r.get_center().x, r.end.y - 18), 0, w.cost, 9.0)
	elif r.size.y >= 54:
		cost_row(ci, Vector2(r.get_center().x, r.end.y - 14), 0, w.cost, 7.0)
	if state == 1:
		text(ci, r.position + Vector2(r.size.x - 18, 16), "V", 22, Color8(140, 255, 140), 4)
	elif state == 2:
		rr(ci, r, 10, Color(0, 0, 0, 0.55))
		ci.draw_line(r.position + Vector2(10, 10), r.end - Vector2(10, 10), Color8(220, 80, 70), 3.0)


## 발전 토큰 — 둥근 판.
static func token(ci: CanvasItem, r: Rect2, tk: Dictionary, hl: bool = false, t: float = 0.0) -> void:
	var edge := GOLD if not hl else Color8(140, 255, 140).lerp(GOLD, 0.5 + 0.5 * sin(t * 4.0))
	rr(ci, r, r.size.y * 0.45, Color8(40, 90, 60), edge, 2.5 if not hl else 3.5)
	text(ci, r.get_center(), String(tk.name), 20, Color(1, 1, 1), 4)


static var _tex := {}


static func img(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/empire/%s.png" % name
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = tx
	return tx
