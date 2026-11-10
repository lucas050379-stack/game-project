class_name BgArt
extends RefCounted

## 버거왕 그림 — 그림 파일(`art/burger/bg_*.png`, GPT)이 있으면 그것을, 없으면 색 조각으로 그린다(뼈대가 그림 없이도 돈다).
## **버거는 재료 층을 쌓아 그린다** — 조립대의 버거도, 손님 말풍선의 주문도 같은 함수(`stack`)라 둘이 늘 똑같이 생겼다.

const INK := Color8(74, 44, 30)
const CREAM := Color8(255, 246, 226)
const RED := Color8(214, 60, 52)
const MUSTARD := Color8(250, 190, 60)
const WOOD := Color8(196, 130, 76)
const GREEN := Color8(110, 200, 90)
const HEAD := Color8(255, 250, 240)
## 분류마다: [그릴 폭(버거 폭에 대한 비), 다음 층이 올라가는 높이(그 층 그림 높이에 대한 비), 그림이 없을 때의 색]
const CAT := {
	"bun": [1.0, 0.72, Color8(240, 180, 90)], "patty": [0.98, 0.7, Color8(120, 70, 40)], "veg": [1.04, 0.5, Color8(110, 200, 90)],
	"cheese": [1.02, 0.34, Color8(250, 190, 60)], "top": [0.98, 0.6, Color8(230, 120, 90)], "sauce": [0.86, 0.5, Color8(226, 54, 44)],
}

static var _tex := {}


static func img(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://art/burger/%s.png" % name
	var tx: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[name] = tx
	return tx


## 재료 층의 그림 — 빵은 아래 · 위가 다르다(part = "bot" · "top").
static func layer_tex(id: String, part: String = "") -> Texture2D:
	id = BgD.base(id)   # 듬뿍(+) · 녹임(~) 꼬리표는 그림이 같다
	var c := BgD.cat(id)
	if c == "bun":
		return img("bg_%s_%s" % [id, part if part != "" else "top"])
	if c == "sauce":
		return img("bg_sauce")
	return img("bg_" + id)


static func layer_col(id: String) -> Color:
	return BgD.SAUCE_COL.get(BgD.base(id), Color.WHITE) if BgD.cat(id) == "sauce" else Color.WHITE


## 층 하나의 [그릴 폭, 그릴 높이, 올라가는 높이] — 버거 폭 w 기준.
static func _dims(id: String, part: String, w: float) -> Array:
	var row: Array = CAT[BgD.cat(id)]
	var dw := w * float(row[0])
	var tx := layer_tex(id, part)
	var dh := dw * tx.get_height() / tx.get_width() if tx != null else (w * 0.3 if part == "top" else w * 0.11)
	if id.ends_with("~"):   # 녹인 치즈 — 더 길게 흘러내린다
		dh *= 1.5
	var adv := dh * (0.86 if BgD.cat(id) == "bun" and part == "bot" else float(row[1]))
	if id.ends_with("+"):   # 소스 듬뿍 — 두 줄
		adv *= 1.9
	if id.ends_with("~"):
		adv /= 1.5
	return [dw, dh, adv]


## 쌓은 버거의 높이(폭 w 일 때) — 말풍선에 맞춰 줄일 때 쓴다.
static func stack_h(ids: Array, w: float) -> float:
	var h := 0.0
	for i in ids.size():
		var id := String(ids[i])
		var part := ("bot" if i == 0 else "top") if BgD.cat(id) == "bun" else ""
		var d := _dims(id, part, w)
		h += float(d[2]) if i < ids.size() - 1 else float(d[1])
	return h


## 버거를 그린다 — base 가 맨 아래 가운데, 폭 w. drop(0~1)은 맨 위 층이 떨어져 얹히는 정도(1 = 다 얹힘), 0 보다 작으면 연출 없음.
## mark 는 붉게 깜빡일 층(틀린 자리, -1 = 없음).
static func stack(ci: CanvasItem, ids: Array, base: Vector2, w: float, drop: float = -1.0, mark: int = -1, t: float = 0.0) -> void:
	var y := base.y
	for i in ids.size():
		var id := String(ids[i])
		var part := ("bot" if i == 0 else "top") if BgD.cat(id) == "bun" else ""
		var d := _dims(id, part, w)
		var dw := float(d[0])
		var dh := float(d[1])
		var off := 0.0
		var sq := 1.0
		if i == ids.size() - 1 and drop >= 0.0 and drop < 1.0:
			off = -(1.0 - G2.out_cubic(minf(drop / 0.55, 1.0))) * 70.0   # 떨어져서
			if drop > 0.55:
				sq = 1.0 - 0.22 * sin((drop - 0.55) / 0.45 * PI)        # 눌렸다 펴진다
		var r := Rect2(base.x - dw * (2.0 - sq) * 0.5, y - dh * sq + off, dw * (2.0 - sq), dh * sq)
		var tx := layer_tex(id, part)
		var col := layer_col(id)
		if BgD.cat(id) == "sauce" and i == ids.size() - 1 and drop >= 0.0 and drop < 1.0:
			# 소스는 떨어지지 않는다 — 병이 지나간 데까지만 왼쪽부터 그려진다(병은 main 이 그린다)
			r = Rect2(base.x - dw * 0.5, y - dh, dw * drop, dh)
			if tx != null:
				ci.draw_texture_rect_region(tx, r, Rect2(0, 0, tx.get_width() * drop, tx.get_height()), col)
			else:
				G2.panel(ci, r, col, INK, 2.0, 4.0)
			y -= float(d[2])
			continue
		if i == mark and fmod(t, 0.4) < 0.2:
			col = col.lerp(Color(1, 0.2, 0.2), 0.6)
		if tx != null:
			ci.draw_texture_rect(tx, r, false, col)
			if id.ends_with("+"):   # 듬뿍 — 한 줄 더, 조금 위에 엇갈려
				ci.draw_texture_rect(tx, Rect2(r.position + Vector2(r.size.x * 0.06, -r.size.y * 0.55), r.size), false, col)   # 뒤집지 않는다(폭을 음수로 주면 엉뚱한 자리에 그려진다)
			if id.ends_with("~"):   # 녹임 — 김이 오른다
				var stx := img("bg_steam")
				if stx != null:
					var q := fposmod(t * 0.7 + i * 0.3, 1.0)
					fit(ci, stx, Rect2(r.end.x - dw * 0.16, r.position.y - dw * 0.12 - q * dw * 0.1, dw * 0.2, dw * 0.2), Color(1, 1, 1, 0.9 - q * 0.5))
		else:
			var fc: Color = BgD.SAUCE_COL.get(BgD.base(id), CAT[BgD.cat(id)][2])
			G2.panel(ci, r, fc if i != mark or fmod(t, 0.4) >= 0.2 else Color(1, 0.3, 0.3), INK, 2.0, minf(r.size.y * 0.45, 12.0))
		y -= float(d[2])


## 선반 칸 · 강화 목록에 넣는 재료 그림 — 칸 r 안에 맞춘다(소스는 병).
static func icon(ci: CanvasItem, id: String, r: Rect2, mod: Color = Color.WHITE) -> void:
	var c := BgD.cat(id)
	var tx := img("bg_bottle") if c == "sauce" else layer_tex(id, "top")
	var col: Color = BgD.SAUCE_COL.get(BgD.base(id), Color.WHITE)
	if tx == null:
		G2.panel(ci, Rect2(r.get_center() - Vector2(r.size.x * 0.36, 9), Vector2(r.size.x * 0.72, 18)), (col if c == "sauce" else CAT[c][2]) * mod, INK, 2.0, 8.0)
		return
	fit(ci, tx, r, (col if c == "sauce" else Color.WHITE) * mod)


## 그림을 칸 안에 비율을 지켜 가운데로.
static func fit(ci: CanvasItem, tx: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	if tx == null:
		return
	var ts := tx.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	ci.draw_texture_rect(tx, Rect2(r.get_center() - ts * k * 0.5, ts * k), false, mod)


## 손님 — feet 가 카운터에 닿는 아래 가운데, 키 h. face 0~5(동물), mood 0 기쁨 · 1 기다림 · 2 초조 · 3 화남.
static func customer(ci: CanvasItem, face: int, mood: int, feet: Vector2, h: float, t: float) -> void:
	var tx := img("bg_cust_%d_%d" % [face, mood])
	var bob := sin(t * (9.0 if mood == 0 else 2.2)) * (10.0 if mood == 0 else 2.0)
	if mood == 3:
		feet.x += sin(t * 40.0) * 2.5
	if tx != null:
		var w := h * tx.get_width() / tx.get_height()
		ci.draw_texture_rect(tx, Rect2(feet.x - w * 0.5, feet.y - h - maxf(bob, 0.0), w, h), false)
		return
	var cols := [Color8(160, 100, 70), Color8(250, 240, 240), Color8(240, 170, 90), Color8(140, 140, 150), Color8(240, 210, 160), Color8(60, 70, 90)]
	var c := feet + Vector2(0, -h * 0.5 - maxf(bob, 0.0))
	ci.draw_circle(c, h * 0.42, INK)
	ci.draw_circle(c, h * 0.42 - 4.0, cols[face % 6])
	for s in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(s * h * 0.14, -h * 0.05), 5.0, INK)
	var my := h * 0.14
	if mood == 0:
		ci.draw_arc(c + Vector2(0, my - 6), 12.0, 0.2, PI - 0.2, 10, INK, 4.0)
	elif mood == 1:
		ci.draw_line(c + Vector2(-8, my), c + Vector2(8, my), INK, 4.0)
	else:
		ci.draw_arc(c + Vector2(0, my + 10), 12.0, PI + 0.2, TAU - 0.2, 10, RED if mood == 3 else INK, 4.0)


## 말풍선(꼬리가 왼쪽 아래).
static func bubble(ci: CanvasItem, r: Rect2) -> void:
	var tail := PackedVector2Array([Vector2(r.position.x + 4, r.end.y - 46), Vector2(r.position.x - 20, r.end.y - 20), Vector2(r.position.x + 4, r.end.y - 20)])
	ci.draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(0, -4), tail[1] + Vector2(-7, 2), tail[2] + Vector2(0, 5)]), INK)
	G2.panel(ci, r, Color.WHITE, INK, 4.0, 22.0)
	ci.draw_colored_polygon(tail, Color.WHITE)


## 둥근 판(게임 안의 칸 · 창).
static func rr(ci: CanvasItem, r: Rect2, rad: float, fill: Color, edge: Color = Color(0, 0, 0, 0), lw: float = 0.0) -> void:
	G2.panel(ci, r, fill, edge, lw, rad)


static func star(ci: CanvasItem, c: Vector2, r: float, on: bool, k: float = 1.0) -> void:
	var tx := img("bg_star")
	if tx != null:
		fit(ci, tx, Rect2(c - Vector2(r, r) * k, Vector2(r, r) * 2.0 * k), Color.WHITE if on else Color(0.25, 0.22, 0.25, 0.7))
		return
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI * 0.5 + j * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r * k * (1.0 if j % 2 == 0 else 0.45))
	ci.draw_colored_polygon(pts, MUSTARD if on else Color(0.3, 0.26, 0.3))
