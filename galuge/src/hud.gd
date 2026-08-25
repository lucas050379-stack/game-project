class_name Hud
extends RefCounted

## 좌우 패널과 화면 위 표시.
##
## 플레이필드가 가운데 세로로 서 있으므로 점수·파워·봄은 전부 옆 패널로 나간다.
## 화면 위에 겹쳐 놓으면 탄을 가려서, 가려진 자리에서 죽는다.

const PAD := 22.0


static func panels(ci: CanvasItem, play: Rect2, vs: Vector2, w: World) -> void:
	# 패널 바탕 무늬 — 가로줄. 플레이필드와 확실히 다른 결로 두어 눈이 안 헷갈리게.
	for side in 2:
		var x0 := 0.0 if side == 0 else play.end.x
		var x1 := play.position.x if side == 0 else vs.x
		var y := 8.0
		while y < vs.y:
			ci.draw_line(Vector2(x0, y), Vector2(maxf(x0, x1 - 8.0), y),
					P.a(P.DIM, 0.05), 1.0)
			y += 9.0
	ci.draw_line(Vector2(play.position.x - 0.5, 0), Vector2(play.position.x - 0.5, vs.y),
			P.a(P.DIM, 0.22), 1.0)
	ci.draw_line(Vector2(play.end.x + 0.5, 0), Vector2(play.end.x + 0.5, vs.y),
			P.a(P.DIM, 0.22), 1.0)

	var lx := PAD
	var rx := play.end.x + PAD
	var col := w.craft_col()

	# ---- 왼쪽: 점수 · 라운드 ----
	if D.test_build():
		G2.text_right(ci, Vector2(play.position.x - PAD, 20), "TEST BUILD", 11.0,
				P.hdr(P.FOE_MARK, 1.1))
	G2.text(ci, Vector2(lx, 42), "1P", 15.0, P.hdr(P.GOLD, 1.1))
	G2.text(ci, Vector2(lx, 70), P.n(w.score), 26.0, P.WHITE)
	G2.text(ci, Vector2(lx, 110), D.ROUND[w.round_i].name, 13.0, P.DIM)
	G2.text_right(ci, Vector2(play.position.x - PAD, 110), D.DIFF[w.diff].name, 13.0,
			P.hdr(P.GOLD, 1.0))

	var bar := Rect2(lx, 124, play.position.x - PAD * 2.0, 5.0)
	ci.draw_rect(bar, P.a(P.DIMMER, 0.35), true)
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * w.prog, bar.size.y)),
			P.hdr(P.GOLD, 1.05), true)
	G2.text(ci, Vector2(lx, 152), "진행 %d%%" % int(w.prog * 100.0), 12.0, P.DIMMER)

	G2.text(ci, Vector2(lx, 210), "기체", 12.0, P.DIMMER)
	G2.text(ci, Vector2(lx, 236), D.CRAFT[w.craft].name, 18.0, P.hdr(col, 1.05))
	G2.text(ci, Vector2(lx, 258), D.CRAFT[w.craft].axis, 12.0, P.DIM)
	Art.craft(ci, w.craft, Vector2(lx + 46, 330), w.t, 1.5)

	G2.text(ci, Vector2(lx, 424), "조작", 12.0, P.DIMMER)
	var keys := ["방향키 · WASD  이동", "Shift  저속 · 판정점", "X · Space  봄",
		"R  다시", "Enter  기체 선택"]
	for i in keys.size():
		G2.text(ci, Vector2(lx, 448 + i * 20), keys[i], 12.0, P.DIMMER)
	# 테스트 빌드에만 있는 키는 배지와 같은 색으로 둔다 — 배포판에 없는 것임이 바로 읽히게.
	if D.test_build():
		G2.text(ci, Vector2(lx, 448 + keys.size() * 20), "B  보스로 건너뛰기", 12.0,
				P.hdr(P.FOE_MARK, 1.05))

	# ---- 오른쪽: 파워 · 봄 · 잔기 ----
	G2.text(ci, Vector2(rx, 42), "POWER", 12.0, P.hdr(P.GOLD, 1.1))
	for i in D.POWER_MAX + 1:
		var r := Rect2(rx + i * 26.0, 54, 20, 12)
		ci.draw_rect(r, P.hdr(col, 1.15) if i <= w.power else P.a(P.DIMMER, 0.3), true)
	G2.text(ci, Vector2(rx, 92), "P %d / %d" % [w.power, D.POWER_MAX], 12.0, P.DIM)

	G2.text(ci, Vector2(rx, 140), "BOMB", 12.0, P.hdr(P.GOLD, 1.1))
	for i in D.BOMBS:
		var c := Vector2(rx + 10 + i * 26, 158)
		if i < w.bombs:
			G2.glow(ci, c, 14.0, col, 0.35)
			ci.draw_arc(c, 7.0, 0.0, TAU, 18, P.hdr(col, 1.2), 2.0, true)
		else:
			ci.draw_arc(c, 7.0, 0.0, TAU, 18, P.a(P.DIMMER, 0.4), 1.4, true)
	G2.text(ci, Vector2(rx, 190), D.CRAFT[w.craft].bomb, 12.0, P.DIM)

	G2.text(ci, Vector2(rx, 240), "LIVES", 12.0, P.hdr(P.GOLD, 1.1))
	for i in maxi(0, w.lives):
		Art.craft(ci, w.craft, Vector2(rx + 14 + i * 30, 274), w.t, 0.5)


static func boss_bar(ci: CanvasItem, play: Rect2, w: World) -> void:
	# ---- 보스 체력 ----
	#
	# 막대 하나만 두면 4,800 짜리 보스는 한 대 맞을 때마다 0.02% 씩 줄어서 **안 움직이는
	# 것처럼 보인다.** 뒤따라오는 잔상 막대를 겹쳐 두면 맞은 만큼이 눈에 띄게 깎이고,
	# 숫자를 같이 적어 두면 남은 양이 정확히 읽힌다.
	if not w.boss.is_empty() and w.boss.y_in:
		var bw := play.size.x - 44.0
		var top := play.position + Vector2(22, 46)
		var hp: float = maxf(0.0, w.boss.hp / w.boss.max)
		var lag: float = maxf(hp, w.boss.shown / w.boss.max)
		var bcol := P.hdr(Color8(224, 163, 60) if w.boss.mid else Color8(216, 90, 80), 1.1)
		var fill := P.hdr(Color8(192, 138, 58) if w.boss.mid else P.FOE_MARK, 1.15)
		ci.draw_rect(Rect2(top, Vector2(bw, 9)), Color(0.03, 0.05, 0.08, 0.85), true)
		ci.draw_rect(Rect2(top, Vector2(bw * lag, 9)), P.a(P.WHITE, 0.55), true)
		ci.draw_rect(Rect2(top, Vector2(bw * hp, 9)), fill, true)
		if w.boss.rage:
			# 2페이즈에 들어간 건 화면에서 바로 알아야 한다.
			ci.draw_rect(Rect2(top, Vector2(bw * hp, 9)),
					P.a(P.WHITE, 0.12 + 0.12 * sin(w.t * 9.0)), true)
		ci.draw_rect(Rect2(top - Vector2(1, 1), Vector2(bw + 2, 11)), P.a(P.WHITE, 0.35), false, 1.0)
		for i in 3:
			var qx := top.x + bw * (i + 1) * 0.25
			ci.draw_line(Vector2(qx, top.y), Vector2(qx, top.y + 9), P.a(P.VOID, 0.5), 1.0)
		G2.text(ci, top - Vector2(0, 8),
				("중간보스  " if w.boss.mid else "") + w.boss.name, 12.0, bcol)
		G2.text_right(ci, Vector2(top.x + bw, top.y - 8),
				"%s / %s" % [P.n(int(ceil(maxf(0.0, w.boss.hp)))), P.n(int(w.boss.max))],
				12.0, P.WHITE)


static func overlay(ci: CanvasItem, play: Rect2, w: World) -> void:
	var mid := play.position + play.size * 0.5
	match w.st:
		World.St.CLEAR:
			_banner(ci, play, mid, "라운드 클리어", "다음 라운드로…", P.hdr(P.GOLD, 1.2))
		World.St.ALLCLEAR:
			_banner(ci, play, mid, "ALL CLEAR", "R  다시    Enter  기체 선택", P.hdr(P.POWER, 1.2))
		World.St.OVER:
			_banner(ci, play, mid, "GAME OVER", "R  다시    Enter  기체 선택", P.hdr(P.FOE_MARK, 1.2))


static func _banner(ci: CanvasItem, play: Rect2, mid: Vector2, big: String, small: String,
		col: Color) -> void:
	ci.draw_rect(Rect2(play.position.x, mid.y - 62, play.size.x, 124),
			Color(0.02, 0.03, 0.06, 0.72), true)
	ci.draw_line(Vector2(play.position.x, mid.y - 62), Vector2(play.end.x, mid.y - 62),
			P.a(col, 0.7), 1.5)
	ci.draw_line(Vector2(play.position.x, mid.y + 62), Vector2(play.end.x, mid.y + 62),
			P.a(col, 0.7), 1.5)
	G2.text_mid(ci, mid - Vector2(0, 12), big, 30.0, col)
	G2.text_mid(ci, mid + Vector2(0, 28), small, 14.0, P.DIM)
