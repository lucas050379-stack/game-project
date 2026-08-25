class_name Shop
extends RefCounted

## 판 밖 강화 — 금화로 사고, 죽어도 남는다.
##
## **여기 있는 것은 기본 스텟뿐이다.** 판 안에서 자라는 것(파워업 P)과 섞으면
## "이번 판에 센 것"과 "계속 세지는 것"의 구분이 사라진다.
##
## 상점 화면은 **알갱이가 아니라 숫자 + 막대**로 그린다. 만렙이 40 이라
## 칸 40개는 폰 화면에 그릴 수도 읽을 수도 없다.

const PAD := 20.0
const ROW := 96.0
const GAP := 10.0

var pick := 0
var t := 0.0
var flash := ""             ## 방금 산 항목 (잠깐 빛낸다)
var flash_t := 0.0
var deny := 0.0             ## 못 샀을 때 흔들림


func step(dt: float) -> void:
	t += dt
	flash_t = maxf(0.0, flash_t - dt * 1.6)
	deny = maxf(0.0, deny - dt * 3.0)


func move(step_i: int) -> void:
	pick = posmod(pick + step_i, D.SHOP.size())


func _top(h: float) -> float:
	return h * 0.155


func row_rect(i: int, w: float, h: float) -> Rect2:
	return Rect2(PAD, _top(h) + i * (ROW + GAP), w - PAD * 2.0, ROW)


func back_rect(w: float, h: float) -> Rect2:
	var bw := minf(w - PAD * 2.0, 460.0)
	return Rect2((w - bw) * 0.5, h - Hud.BOT - 40.0 - 62.0, bw, 62.0)


func hit(p: Vector2, w: float, h: float) -> String:
	for i in D.SHOP.size():
		if row_rect(i, w, h).has_point(p):
			pick = i
			return "buy"
	if back_rect(w, h).has_point(p):
		return "back"
	return ""


func buy() -> void:
	var id := String(D.SHOP[pick].id)
	if Sv.buy(id):
		flash = id
		flash_t = 1.0
	else:
		deny = 1.0


func draw(ci: CanvasItem, w: float, h: float) -> void:
	Art.sky(ci, w, h, 1)
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.07, 0.62), true)

	G2.text_mid(ci, Vector2(w * 0.5, h * 0.062), "상점", 32.0, P.hdr(P.WHITE, 1.12))
	G2.text_mid(ci, Vector2(w * 0.5, h * 0.062 + 24.0),
			"여기서 산 것은 죽어도 남습니다", 13.0, P.DIM)

	# 가진 금화 — 상점에서 제일 자주 보는 숫자다. 목록 바로 위에 크게 둔다.
	var gr := Rect2(PAD, h * 0.098, w - PAD * 2.0, 40.0)
	G2.panel(ci, gr, P.PANEL, P.a(P.GOLD, 0.45), 1.2, 9.0)
	ci.draw_circle(gr.position + Vector2(24, 20), 9.0, P.hdr(P.GOLD, 1.15))
	ci.draw_circle(gr.position + Vector2(24, 20), 4.5, P.GOLD_D)
	G2.text(ci, gr.position + Vector2(42, 27), "보유 금화", 13.0, P.DIMMER)
	G2.text_right(ci, gr.position + Vector2(gr.size.x - 16, 28), P.n(Sv.gold), 22.0,
			P.hdr(P.GOLD, 1.15))

	for i in D.SHOP.size():
		_row(ci, i, row_rect(i, w, h))

	var br := back_rect(w, h)
	G2.panel(ci, br, P.a(P.hdr(P.GOLD, 0.9), 0.2), P.hdr(P.GOLD, 1.15), 1.6, 14.0)
	G2.text_mid(ci, br.position + br.size * 0.5 + Vector2(0, 1), "돌아가기", 20.0,
			P.hdr(P.GOLD, 1.15))


func _row(ci: CanvasItem, i: int, r: Rect2) -> void:
	var s: Dictionary = D.SHOP[i]
	var id := String(s.id)
	var lv := Sv.level(id)
	var mx := int(s.max)
	var maxed := lv >= mx
	var cost := D.cost(id, lv)
	var afford := not maxed and Sv.gold >= cost
	var on := i == pick

	var shift := 0.0
	if on and deny > 0.0:
		shift = sin(deny * 34.0) * 6.0 * deny
	r.position.x += shift

	var lit := flash == id and flash_t > 0.0
	G2.panel(ci, r, Color(0.06, 0.08, 0.13, 0.92) if on else Color(0.035, 0.048, 0.08, 0.86),
			P.hdr(P.GOLD, 1.15) if on else P.a(P.DIMMER, 0.4), 2.0 if on else 1.0, 11.0)
	if lit:
		G2.glow(ci, r.position + r.size * 0.5, r.size.x * 0.5, P.POWER, 0.22 * flash_t)

	var x := r.position.x + 18.0
	G2.text(ci, Vector2(x, r.position.y + 30), String(s.name), 19.0,
			P.WHITE if not maxed else P.hdr(P.POWER, 1.1))
	G2.text_right(ci, Vector2(r.end.x - 18, r.position.y + 30),
			"MAX" if maxed else "Lv %d / %d" % [lv, mx], 15.0,
			P.hdr(P.POWER, 1.1) if maxed else P.DIM)

	# 막대 — 알갱이 40개는 그릴 수도 읽을 수도 없다.
	var bar := Rect2(x, r.position.y + 44, r.size.x - 36.0, 8.0)
	ci.draw_rect(bar, P.a(P.DIMMER, 0.3), true)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(lv) / float(mx), bar.size.y)),
			P.hdr(P.POWER if maxed else P.GOLD, 1.1), true)

	G2.text(ci, Vector2(x, r.position.y + 76), String(s.desc), 11.5, P.DIMMER)

	if maxed:
		return
	# 값 — 못 사면 회색이라 눌러 보기 전에 알 수 있다.
	var cr := Rect2(r.end.x - 122.0, r.position.y + 58.0, 104.0, 28.0)
	G2.panel(ci, cr, P.a(P.GOLD, 0.16) if afford else P.a(P.DIMMER, 0.12),
			P.a(P.GOLD, 0.6) if afford else P.a(P.DIMMER, 0.35), 1.0, 7.0)
	ci.draw_circle(cr.position + Vector2(16, 14), 6.0,
			P.hdr(P.GOLD, 1.1) if afford else P.DIMMER)
	G2.text_right(ci, cr.position + Vector2(cr.size.x - 10, 20), P.n(cost), 14.0,
			P.hdr(P.GOLD, 1.1) if afford else P.DIMMER)
