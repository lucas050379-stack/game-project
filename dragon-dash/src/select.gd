class_name Sel
extends RefCounted

## 시작 화면 — 드래곤 고르기 · 최고 기록 · 상점으로 가는 문.
##
## **세로 화면이라 카드를 가로로 늘어놓지 않는다.** 720 폭에 셋을 나란히 두면
## 카드 하나가 220px 이라 설명이 들어갈 자리가 없다. 세로로 쌓고,
## **고른 것만 펼쳐서** 설명을 보여 준다.
##
## **자리를 내는 함수를 하나만 두고 그리기와 터치 판정이 같이 보게 한다**
## (`card_rect`·`start_rect`·`shop_rect`). 두 곳에서 따로 계산하면
## 한쪽만 고쳤을 때 "눌리지 않는 버튼"이 되고, 화면만 봐서는 원인을 알 수 없다.

const PAD := 22.0
const ROW := 104.0
const ROW_OPEN := 186.0     ## 고른 카드는 설명만큼 키운다

var pick := 0
var t := 0.0


func step(dt: float) -> void:
	t += dt


func move(step_i: int) -> void:
	pick = posmod(pick + step_i, D.DRAGON.size())


func _top(h: float) -> float:
	return h * 0.26


func card_rect(i: int, w: float, h: float) -> Rect2:
	var y := _top(h)
	for k in i:
		y += (ROW_OPEN if k == pick else ROW) + 10.0
	return Rect2(PAD, y, w - PAD * 2.0, ROW_OPEN if i == pick else ROW)


func start_rect(w: float, h: float) -> Rect2:
	var bw := minf(w - PAD * 2.0, 460.0)
	return Rect2((w - bw) * 0.5, h - Hud.BOT - 40.0 - 152.0, bw, 76.0)


func shop_rect(w: float, h: float) -> Rect2:
	var bw := minf(w - PAD * 2.0, 460.0)
	return Rect2((w - bw) * 0.5, h - Hud.BOT - 40.0 - 62.0, bw, 62.0)


## 눌린 곳이 무엇인지 알려 준다. "" 는 아무것도 아님.
func hit(p: Vector2, w: float, h: float) -> String:
	for i in D.DRAGON.size():
		if card_rect(i, w, h).has_point(p):
			# 이미 고른 것을 다시 누르면 바로 시작한다 — 두 번 누르는 게
			# 폰에서는 "고르고 시작"의 자연스러운 흐름이다.
			if i == pick:
				return "start"
			pick = i
			return "pick"
	if start_rect(w, h).has_point(p):
		return "start"
	if shop_rect(w, h).has_point(p):
		return "shop"
	return ""


func draw(ci: CanvasItem, w: float, h: float) -> void:
	Art.sky(ci, w, h, 2)
	Art.scenery(ci, w, h, t * 60.0, 2, t)
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.07, 0.42), true)

	G2.text_mid(ci, Vector2(w * 0.5, h * 0.11), "드래곤 대시", 46.0, P.hdr(P.WHITE, 1.15))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.11 + 30.0),
			"끌어서 피하고, 최대한 멀리", 15.0, P.DIM)

	# 최고 기록과 금화 — 이 둘이 다시 하는 이유다. 제일 눈에 띄는 자리에 둔다.
	var sr := Rect2(PAD, h * 0.165, w - PAD * 2.0, 52.0)
	G2.panel(ci, sr, P.PANEL, P.a(P.GOLD, 0.4), 1.2, 10.0)
	G2.text(ci, sr.position + Vector2(18, 33), "최고", 14.0, P.DIMMER)
	G2.text(ci, sr.position + Vector2(62, 34), "%s m" % P.n(Sv.best), 22.0,
			P.hdr(P.WHITE, 1.1))
	ci.draw_circle(sr.position + Vector2(sr.size.x - 128, 26), 9.0, P.hdr(P.GOLD, 1.15))
	G2.text_right(ci, sr.position + Vector2(sr.size.x - 18, 34), P.n(Sv.gold), 22.0,
			P.hdr(P.GOLD, 1.15))

	for i in D.DRAGON.size():
		_card(ci, i, card_rect(i, w, h))

	var br := start_rect(w, h)
	G2.panel(ci, br, P.a(P.hdr(P.GOLD, 0.9), 0.22), P.hdr(P.GOLD, 1.2), 2.0, 16.0)
	G2.text_mid(ci, br.position + br.size * 0.5 + Vector2(0, 1), "시작", 26.0,
			P.hdr(P.GOLD, 1.2))

	var shr := shop_rect(w, h)
	G2.panel(ci, shr, P.PANEL, P.a(P.DIM, 0.4), 1.2, 14.0)
	G2.text_mid(ci, shr.position + shr.size * 0.5 + Vector2(0, 1), "상점", 20.0, P.WHITE)

	G2.text_mid(ci, Vector2(w * 0.5, h - Hud.BOT - 12.0),
			"화면을 끌어서 좌우로 움직입니다. 브레스는 자동입니다.", 12.0, P.DIMMER)


func _card(ci: CanvasItem, i: int, r: Rect2) -> void:
	var d: Dictionary = D.DRAGON[i]
	var c := P.dragon(int(d.col), 3)
	var on := i == pick
	G2.panel(ci, r, Color(0.06, 0.08, 0.13, 0.92) if on else Color(0.035, 0.048, 0.08, 0.86),
			P.hdr(c, 1.15) if on else P.a(P.DIMMER, 0.4), 2.0 if on else 1.0, 12.0)
	if on:
		G2.glow(ci, r.position + Vector2(64, 52), 120.0, c, 0.14)

	Art.dragon(ci, i, r.position + Vector2(64, 52 + sin(t * 1.6 + i) * 3.0), t,
			0.86 if on else 0.72)

	var x := r.position.x + 128.0
	var mw := r.size.x - 148.0
	G2.text(ci, Vector2(x, r.position.y + 38), String(d.name), 24.0,
			P.hdr(c, 1.1) if on else P.WHITE)
	G2.text(ci, Vector2(x + G2.text_w(String(d.name), 24.0) + 12.0, r.position.y + 37),
			String(d.axis), 14.0, P.hdr(P.GOLD, 1.05) if on else P.DIM)
	G2.text(ci, Vector2(x, r.position.y + 64), String(d.basic), 13.0, P.DIM)

	if not on:
		return
	# 펼친 부분. **위에서 아래로 흘려 놓는다** — 자리를 상수로 박으면 설명이
	# 2줄이 되기도 3줄이 되기도 해서 아래 것을 덮는다. `G2.wrap` 이 다음 줄이
	# 시작될 y 를 돌려주므로 이어 그리는 쪽이 그 값을 받아 쓴다.
	var y := r.position.y + 88.0
	ci.draw_line(Vector2(x, y - 6), Vector2(x + mw, y - 6), P.a(P.DIMMER, 0.35), 1.0)
	G2.text(ci, Vector2(x, y + 14), "파워업 방향", 10.0, P.DIMMER)
	y = G2.wrap(ci, Vector2(x, y + 32), String(d.grow), 12.5, P.WHITE, mw, 17.0)
	y = G2.wrap(ci, Vector2(x, y + 6), String(d.note), 12.0, P.DIMMER, mw, 16.0)
