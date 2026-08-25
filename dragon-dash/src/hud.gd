class_name Hud
extends RefCounted

## 화면 위에 얹는 표시.
##
## **세로 화면이라 옆 패널이 없다.** 전부 게임 위에 겹치므로 자리를 아껴야 한다.
## 배치는 원작을 따른다 — **왼쪽 위에 재화, 오른쪽 위에 거리(M)**, 아래에 파워와 하트.
## 가운데 위는 비워 둔다: 적이 거기서 내려오므로 글자를 놓으면 서로 가린다.
##
## 폰은 위쪽에 노치·상태바가 있고 아래쪽은 손가락이 가린다. 그래서
## **위아래 안전 여백**(`TOP`·`BOT`)을 두고 그 안에만 그린다.

const TOP := 26.0
const BOT := 22.0
const PAD := 18.0


static func play(ci: CanvasItem, w: float, h: float, wd: World) -> void:
	# ---- 왼쪽 위: 금화 · 점수 ----
	ci.draw_circle(Vector2(PAD + 11, TOP + 11), 8.0, P.hdr(P.GOLD, 1.15))
	ci.draw_circle(Vector2(PAD + 11, TOP + 11), 4.0, P.GOLD_D)
	G2.text(ci, Vector2(PAD + 26, TOP + 17), P.n(wd.gold), 17.0, P.hdr(P.GOLD, 1.12))
	ci.draw_circle(Vector2(PAD + 11, TOP + 36), 7.0, P.hdr(P.GEM, 1.15))
	G2.text(ci, Vector2(PAD + 26, TOP + 42), P.n(wd.score()), 17.0, P.hdr(P.GEM, 1.1))

	# ---- 오른쪽 위: 거리 ----
	# 원작처럼 `10934M`. 이 게임에서 제일 자주 보는 숫자다.
	G2.text_right(ci, Vector2(w - PAD, TOP + 30), "%sM" % P.n(int(wd.m)), 32.0,
			P.hdr(P.WHITE, 1.12))
	if Sv.best_m > 0:
		var rec := int(wd.m) > Sv.best_m
		G2.text_right(ci, Vector2(w - PAD, TOP + 52),
				("최고 기록!" if rec else "최고 %sM" % P.n(Sv.best_m)), 12.0,
				P.hdr(P.GOLD, 1.2) if rec else P.DIM)

	# ---- 구간 ----
	G2.text_mid(ci, Vector2(w * 0.5, TOP + 16),
			"%d · %s" % [wd.zone_i + 1, String(wd.zone().name)], 13.0, P.a(P.DIM, 0.75))

	# ---- 보스 체력 ----
	#
	# 막대 하나만 두면 큰 보스는 한 대 맞을 때마다 조금씩 줄어서 **안 움직이는 것처럼
	# 보인다.** 뒤따라오는 잔상 막대를 겹치면 맞은 만큼이 눈에 띄게 깎인다.
	if not wd.boss.is_empty() and not wd.boss.leaving:
		var b: Dictionary = wd.boss
		var bw := w - PAD * 2.0
		var top := Vector2(PAD, TOP + 74)
		var hp: float = maxf(0.0, float(b.hp) / float(b.max_hp))
		var lag: float = maxf(hp, float(b.shown) / float(b.max_hp))
		ci.draw_rect(Rect2(top, Vector2(bw, 10)), Color(0.03, 0.05, 0.08, 0.85), true)
		ci.draw_rect(Rect2(top, Vector2(bw * lag, 10)), P.a(P.WHITE, 0.5), true)
		ci.draw_rect(Rect2(top, Vector2(bw * hp, 10)),
				P.hdr(P.FOE_MARK, 1.25 if b.rage else 1.1), true)
		G2.stroke_rect(ci, Rect2(top - Vector2(1, 1), Vector2(bw + 2, 12)),
				P.a(P.WHITE, 0.35), 1.0)
		G2.text(ci, top - Vector2(0, 6), String(b.name), 13.0, P.hdr(P.FOE_MARK, 1.15))
		# 남은 시간 — 못 잡으면 날아가므로 언제까지인지 보여야 한다.
		var left: float = maxf(0.0, D.BOSS_TIMEOUT - float(b.life))
		G2.text_right(ci, top + Vector2(bw, -6), "%.0f초" % left, 13.0, P.DIM)

	# ---- 아래: 파워 · 하트 · 아이템 ----
	var by := h - BOT - 26.0
	var bw2 := 26.0
	var total := D.POWER_MAX * (bw2 + 5.0) + bw2
	var bx := (w - total) * 0.5
	for i in D.POWER_MAX + 1:
		var r := Rect2(bx + i * (bw2 + 5.0), by, bw2, 9.0)
		ci.draw_rect(r, P.hdr(wd.col(), 1.15) if i <= wd.power else P.a(P.DIMMER, 0.35), true)

	for i in wd.hearts:
		_heart(ci, Vector2(PAD + 14.0 + i * 28.0, by + 2.0), 9.0, P.hdr(P.HEART, 1.2))

	# 도는 아이템 — 남은 시간이 보여야 "언제 끝나는지" 알고 움직인다.
	var ax := w - PAD
	for b2 in D.BUFF:
		var id := String(b2.id)
		var left2: float = float(wd.buffs.get(id, 0.0))
		if left2 <= 0.0:
			continue
		ax -= 74.0
		var r2 := Rect2(ax, by - 16.0, 68.0, 24.0)
		G2.panel(ci, r2, P.a(P.BUFF, 0.18), P.hdr(P.BUFF, 1.1), 1.0, 6.0)
		G2.text_mid(ci, r2.position + r2.size * 0.5 + Vector2(0, 1),
				"%s %.0f" % [String(b2.name).substr(0, 2), left2], 11.0,
				P.hdr(P.BUFF, 1.15))

	if D.test_build():
		G2.text(ci, Vector2(PAD, TOP + 62.0),
				"TEST  적%d 탄%d  x%.1f" % [wd.foes.size(), wd.eb.size(), wd.spd_k()],
				11.0, P.hdr(P.FOE_MARK, 1.05))


static func _heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.28), r * 0.56, col)
	ci.draw_circle(c + Vector2(r * 0.42, -r * 0.28), r * 0.56, col)
	G2.fill_fan(ci, PackedVector2Array([
		c + Vector2(-r * 0.95, -r * 0.10), c + Vector2(0, r * 0.95),
		c + Vector2(r * 0.95, -r * 0.10)]), col)


## 죽은 뒤 결과. **여기서 다음 행동이 바로 손에 닿아야 한다** —
## 러너는 "한 번 더"가 즉시 되지 않으면 그 자리에서 그만두게 된다.
static func over(ci: CanvasItem, w: float, h: float, wd: World, rec: bool) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.06, 0.72), true)
	var mid := w * 0.5
	var y := h * 0.18

	G2.text_mid(ci, Vector2(mid, y), "추락", 32.0, P.hdr(P.FOE_MARK, 1.2))
	y += 58.0
	G2.text_mid(ci, Vector2(mid, y), P.n(wd.score()), 54.0, P.hdr(P.WHITE, 1.15))
	y += 26.0
	G2.text_mid(ci, Vector2(mid, y), "점수", 13.0, P.DIMMER)
	y += 26.0
	if rec:
		G2.text_mid(ci, Vector2(mid, y), "최고 기록!", 18.0, P.hdr(P.GOLD, 1.25))
	else:
		G2.text_mid(ci, Vector2(mid, y), "최고 %s" % P.n(Sv.best), 14.0, P.DIM)

	y += 44.0
	var rows := [
		["비행 거리", "%sM" % P.n(int(wd.m)), P.WHITE],
		["사냥 점수", P.n(int(wd.hunt_score)), P.WHITE],
		["최고 배율", "x%d" % int(wd.best_close), P.hdr(P.GOLD, 1.15)],
		["번 금화", P.n(wd.gold), P.hdr(P.GOLD, 1.1)],
		["처치", P.n(wd.kills), P.WHITE],
	]
	var bw := minf(w - 72.0, 420.0)
	var br := Rect2(mid - bw * 0.5, y, bw, 36.0 * rows.size() + 14.0)
	G2.panel(ci, br, P.PANEL, P.a(P.DIM, 0.3), 1.0, 12.0)
	for i in rows.size():
		var ry := br.position.y + 28.0 + i * 36.0
		G2.text(ci, Vector2(br.position.x + 20, ry), String(rows[i][0]), 14.0, P.DIM)
		G2.text_right(ci, Vector2(br.end.x - 20, ry), String(rows[i][1]), 17.0, rows[i][2])

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
	var bh := 64.0
	var y := h - Hud.BOT - 30.0 - (2 - i) * (bh + 12.0)
	return Rect2((w - bw) * 0.5, y, bw, bh)
