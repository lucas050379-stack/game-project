class_name Hud
extends RefCounted

## 화면 위에 얹는 표시.
##
## **세로 화면이라 옆 패널이 없다.** 전부 게임 위에 겹치므로 자리를 아껴야 한다 —
## 위쪽 띠에 거리와 금화, 아래쪽에 파워만 두고 나머지는 안 그린다.
##
## 폰은 위쪽에 노치·상태바가 있고 아래쪽은 손가락이 가린다. 그래서
## **위아래 안전 여백**(`TOP`·`BOT`)을 두고 그 안에만 그린다.

const TOP := 26.0
const BOT := 22.0
const PAD := 18.0


static func play(ci: CanvasItem, w: float, h: float, wd: World) -> void:
	# ---- 위: 거리 ----
	# 거리가 이 게임의 점수다. 제일 크게, 제일 위에 둔다.
	var dist := int(wd.m)
	G2.text_mid(ci, Vector2(w * 0.5, TOP + 34.0), "%s m" % P.n(dist), 40.0,
			P.hdr(P.WHITE, 1.1))
	if Sv.best > 0:
		var rec := dist > Sv.best
		G2.text_mid(ci, Vector2(w * 0.5, TOP + 60.0),
				("최고 기록 경신!" if rec else "최고 %s m" % P.n(Sv.best)), 14.0,
				P.hdr(P.GOLD, 1.2) if rec else P.DIM)

	# ---- 왼쪽 위: 금화 ----
	var gr := Rect2(PAD, TOP, 128, 34)
	G2.panel(ci, gr, P.PANEL, P.a(P.GOLD, 0.45), 1.0, 8.0)
	ci.draw_circle(gr.position + Vector2(20, 17), 8.0, P.hdr(P.GOLD, 1.15))
	ci.draw_circle(gr.position + Vector2(20, 17), 4.0, P.GOLD_D)
	G2.text(ci, gr.position + Vector2(36, 23), P.n(wd.gold), 17.0, P.hdr(P.GOLD, 1.1))

	# ---- 오른쪽 위: 구간 ----
	var zr := Rect2(w - PAD - 118, TOP, 118, 34)
	G2.panel(ci, zr, P.PANEL, P.a(P.DIM, 0.32), 1.0, 8.0)
	G2.text_mid(ci, zr.position + zr.size * 0.5 + Vector2(0, 1),
			"%d · %s" % [wd.zone_i + 1, String(wd.zone().name)], 14.0, P.DIM)

	# ---- 아래: 파워와 보호막 ----
	var by := h - BOT - 26.0
	var bw := 26.0
	var total := D.POWER_MAX * (bw + 5.0) + bw
	var bx := (w - total) * 0.5
	for i in D.POWER_MAX + 1:
		var r := Rect2(bx + i * (bw + 5.0), by, bw, 9.0)
		ci.draw_rect(r, P.hdr(wd.col(), 1.15) if i <= wd.power else P.a(P.DIMMER, 0.35), true)
	G2.text_mid(ci, Vector2(w * 0.5, by - 8.0),
			"POWER %d / %d" % [wd.power, D.POWER_MAX], 12.0, P.DIMMER)

	if wd.shields > 0:
		for i in wd.shields:
			var c := Vector2(PAD + 18.0 + i * 26.0, by + 2.0)
			ci.draw_arc(c, 8.0, 0.0, TAU, 18, P.hdr(P.SHIELD, 1.2), 2.0, true)

	if D.test_build():
		G2.text(ci, Vector2(PAD, TOP + 56.0), "TEST BUILD", 11.0, P.hdr(P.FOE_MARK, 1.1))
		G2.text(ci, Vector2(PAD, TOP + 74.0), "적 %d · 탄 %d" % [wd.foes.size(), wd.eb.size()],
				11.0, P.DIMMER)


## 죽은 뒤 결과. **여기서 다음 행동이 바로 손에 닿아야 한다** —
## 러너 게임은 "한 번 더"가 즉시 되지 않으면 그 자리에서 그만두게 된다.
static func over(ci: CanvasItem, w: float, h: float, wd: World, rec: bool) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.06, 0.72), true)
	var mid := w * 0.5
	var y := h * 0.24

	G2.text_mid(ci, Vector2(mid, y), "추락", 34.0, P.hdr(P.FOE_MARK, 1.2))
	y += 62.0
	G2.text_mid(ci, Vector2(mid, y), "%s m" % P.n(int(wd.m)), 56.0, P.hdr(P.WHITE, 1.15))
	y += 34.0
	if rec:
		G2.text_mid(ci, Vector2(mid, y), "최고 기록!", 18.0, P.hdr(P.GOLD, 1.25))
	else:
		G2.text_mid(ci, Vector2(mid, y), "최고 %s m" % P.n(Sv.best), 15.0, P.DIM)

	y += 52.0
	var rows := [
		["번 금화", "%s" % P.n(wd.gold)],
		["처치", "%s" % P.n(wd.kills)],
		["주운 금화", "%s개" % P.n(wd.coins_taken)],
	]
	var bw := minf(w - 72.0, 420.0)
	var br := Rect2(mid - bw * 0.5, y, bw, 40.0 * rows.size() + 16.0)
	G2.panel(ci, br, P.PANEL, P.a(P.DIM, 0.3), 1.0, 12.0)
	for i in rows.size():
		var ry := br.position.y + 30.0 + i * 40.0
		G2.text(ci, Vector2(br.position.x + 20, ry), String(rows[i][0]), 15.0, P.DIM)
		G2.text_right(ci, Vector2(br.end.x - 20, ry), String(rows[i][1]), 17.0,
				P.hdr(P.GOLD, 1.1) if i == 0 else P.WHITE)

	# 버튼 두 개. 자리는 `over_rect` 하나가 내고 그리기와 터치 판정이 같이 본다.
	for i in 2:
		var r := over_rect(i, w, h)
		var on := i == 0
		G2.panel(ci, r, P.a(P.hdr(P.GOLD, 0.9), 0.22) if on else P.PANEL,
				P.hdr(P.GOLD, 1.15) if on else P.a(P.DIM, 0.4), 2.0 if on else 1.2, 14.0)
		G2.text_mid(ci, r.position + r.size * 0.5 + Vector2(0, 1),
				"한 번 더" if on else "상점 · 드래곤", 20.0 if on else 17.0,
				P.hdr(P.GOLD, 1.15) if on else P.WHITE)


## **자리를 내는 함수는 하나뿐이다** — 그리기와 터치 판정이 같은 값을 본다.
## 두 곳에서 따로 계산하면 한쪽만 고쳤을 때 조용히 어긋나고,
## "눌리지 않는 버튼"은 화면만 봐서는 원인을 알 수 없다.
static func over_rect(i: int, w: float, h: float) -> Rect2:
	var bw := minf(w - 72.0, 420.0)
	var bh := 68.0
	var y := h - Hud.BOT - 40.0 - (2 - i) * (bh + 14.0)
	return Rect2((w - bw) * 0.5, y, bw, bh)
