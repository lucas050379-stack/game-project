class_name Sel
extends RefCounted

## 기체 · 난이도 · (테스트 빌드에서만) 라운드 선택 화면.
##
## **카드 안은 위에서 아래로 흘려 놓는다.** 자리를 상수로 박아 두면 설명 글이 창 폭에 따라
## 2줄이 되기도 3줄이 되기도 해서 아래 것을 덮는다. `G2.wrap` 이 다음 줄이 시작될 y 를
## 돌려주므로 이어 그리는 쪽은 그 값을 받아 쓴다.
##
## 줄이 셋이 되면서 조작을 **↑↓ 줄 이동 · ←→ 고르기** 로 정리했다. 축마다 다른 키를
## 배정하면(예: 라운드만 PageUp) 화면을 봐도 무슨 키인지 알 수가 없다.

const ROW_CRAFT := 0
const ROW_DIFF := 1
const ROW_ROUND := 2

var craft := 0
var diff := 0
var round := 0
var row := 0
var t := 0.0


func step(dt: float) -> void:
	t += dt


func rows() -> int:
	return 3 if D.test_build() else 2


func _move(step_i: int) -> void:
	match row:
		ROW_CRAFT:
			craft = posmod(craft + step_i, D.CRAFT.size())
		ROW_DIFF:
			diff = clampi(diff + step_i, 0, D.DIFF.size() - 1)
		ROW_ROUND:
			round = clampi(round + step_i, 0, D.ROUND.size() - 1)


func key(code: int) -> bool:
	match code:
		KEY_LEFT, KEY_A: _move(-1)
		KEY_RIGHT, KEY_D: _move(1)
		KEY_UP, KEY_W: row = maxi(0, row - 1)
		KEY_DOWN, KEY_S: row = mini(rows() - 1, row + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_X:
			return true
	return false


## 자리를 내는 함수는 하나뿐이다 — **그리기와 클릭 판정이 같은 값을 본다.**
## 두 곳에서 따로 계산하면 한쪽만 고쳤을 때 조용히 어긋난다.
func card_rect(i: int, vs: Vector2) -> Rect2:
	var n := D.CRAFT.size()
	var gap := 12.0
	var margin := 40.0
	var cw := (vs.x - margin * 2.0 - gap * (n - 1)) / n
	var bottom := vs.y - (230.0 if rows() > 2 else 176.0)
	return Rect2(margin + i * (cw + gap), 110.0, cw, bottom - 110.0)


func diff_rect(i: int, vs: Vector2) -> Rect2:
	var bw := 210.0
	var n := D.DIFF.size()
	var total := bw * n + 12.0 * (n - 1)
	var y := vs.y - (218.0 if rows() > 2 else 150.0)
	return Rect2((vs.x - total) * 0.5 + i * (bw + 12.0), y, bw, 58.0)


func round_rect(i: int, vs: Vector2) -> Rect2:
	var bw := 108.0
	var n := D.ROUND.size()
	var total := bw * n + 10.0 * (n - 1)
	return Rect2((vs.x - total) * 0.5 + i * (bw + 10.0), vs.y - 146.0, bw, 50.0)


func hit(p: Vector2, vs: Vector2) -> void:
	for i in D.CRAFT.size():
		if card_rect(i, vs).has_point(p):
			craft = i
			row = ROW_CRAFT
			return
	for i in D.DIFF.size():
		if diff_rect(i, vs).has_point(p):
			diff = i
			row = ROW_DIFF
			return
	if rows() > 2:
		for i in D.ROUND.size():
			if round_rect(i, vs).has_point(p):
				round = i
				row = ROW_ROUND
				return


func draw(ci: CanvasItem, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), P.VOID, true)
	var y := 8.0
	while y < vs.y:
		ci.draw_line(Vector2(0, y), Vector2(vs.x, y), P.a(P.DIM, 0.04), 1.0)
		y += 9.0

	G2.text(ci, Vector2(40, 54), "갈루가", 30.0, P.WHITE)
	G2.text(ci, Vector2(150, 54), "기체 선택", 16.0, P.hdr(P.GOLD, 1.1))
	if rows() > 2:
		var badge := Rect2(vs.x - 152, 32, 112, 26)
		ci.draw_rect(badge, P.a(P.FOE_MARK, 0.18), true)
		G2.stroke_rect(ci, badge, P.hdr(P.FOE_MARK, 1.1), 1.0)
		G2.text_mid(ci, badge.position + badge.size * 0.5, "TEST BUILD", 12.0,
				P.hdr(P.FOE_MARK, 1.15))
	else:
		G2.text_right(ci, Vector2(vs.x - 40, 54),
				"고르는 기체마다 파워업이 자라는 방향이 다릅니다", 13.0, P.DIM)

	for i in D.CRAFT.size():
		_card(ci, i, card_rect(i, vs))
	for i in D.DIFF.size():
		_box(ci, diff_rect(i, vs), D.DIFF[i].name, D.DIFF[i].note, i == diff,
				row == ROW_DIFF, 16.0)
	if rows() > 2:
		for i in D.ROUND.size():
			var rd: Dictionary = D.ROUND[i]
			_box(ci, round_rect(i, vs), "%d라운드" % (i + 1),
					String(rd.name).split(" · ")[1], i == round, row == ROW_ROUND, 14.0)

	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 58),
			"↑ ↓  줄 이동    ← →  고르기    Enter · Z  시작", 14.0, P.DIM)
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 34),
			"이동은 방향키 · WASD. 사격과 미사일은 자동입니다.    R 눌러 채우고 떼면 서브기체 스킬 (채우는 동안 미사일은 멈춥니다)    T 봄    Shift 저속 · 판정점",
			12.0, P.DIMMER)


func _card(ci: CanvasItem, i: int, r: Rect2) -> void:
	var c: Dictionary = D.CRAFT[i]
	var col := P.craft(i, 3)
	var on := i == craft
	var lit := on and row == ROW_CRAFT
	ci.draw_rect(r, Color(0.055, 0.075, 0.115, 1.0) if on else Color(0.032, 0.045, 0.07, 1.0), true)
	if on:
		G2.glow(ci, r.position + Vector2(r.size.x * 0.5, 92.0), r.size.x * 0.8, col,
				0.16 if lit else 0.08)
	G2.stroke_rect(ci, r, P.hdr(col, 1.1) if on else P.a(P.DIMMER, 0.35),
			2.0 if lit else (1.4 if on else 1.0))

	Art.craft(ci, i, r.position + Vector2(r.size.x * 0.5, 92.0 + sin(t * 1.5 + i) * 3.0),
			t, 2.0 if on else 1.7)

	var x := r.position.x + 14.0
	var mw := r.size.x - 28.0
	var y := r.position.y + 160.0
	G2.text(ci, Vector2(x, y), c.id, 11.0, P.a(col, 0.9))
	G2.text(ci, Vector2(x + 40, y), c.name, 17.0, P.hdr(col, 1.05) if on else P.WHITE)
	y += 24.0
	G2.text(ci, Vector2(x, y), c.axis, 12.0, P.hdr(P.GOLD, 1.0) if on else P.DIM)
	y += 26.0
	ci.draw_line(Vector2(x, y - 8), Vector2(x + mw, y - 8), P.a(P.DIMMER, 0.3), 1.0)

	G2.text(ci, Vector2(x, y + 6), "기본탄", 10.0, P.DIMMER)
	y = G2.wrap(ci, Vector2(x, y + 24), c.basic, 12.0, P.WHITE if on else P.DIM, mw, 17.0)
	G2.text(ci, Vector2(x, y + 12), "파워업 방향", 10.0, P.DIMMER)
	y = G2.wrap(ci, Vector2(x, y + 30), c.grow, 12.0, P.DIM, mw, 17.0)
	# **봄은 카드 바닥에 붙인다.** 위에서 흘려 내려오게 두면 설명이 한 줄 더 길어지는
	# 기체에서 카드 **밖으로** 떨어진다 — 하야부사가 실제로 그랬다. 마지막 한 줄은
	# 바닥 기준으로 잡아야 어떤 글이 와도 안에 남는다.
	var by := r.end.y - 40.0
	G2.text(ci, Vector2(x, by), "봄", 10.0, P.DIMMER)
	G2.text(ci, Vector2(x, by + 20), c.bomb, 13.0, P.hdr(col, 1.0) if on else P.DIM)


## 난이도 · 라운드처럼 작은 칸. **고른 것과 지금 손이 가 있는 줄을 따로 보여 준다** —
## 둘을 한 색으로 묶으면 화살표를 눌러도 무엇이 바뀔지 모른다.
func _box(ci: CanvasItem, r: Rect2, title: String, note: String, on: bool, lit: bool,
		size: float) -> void:
	var col := P.hdr(P.GOLD, 1.1) if on else P.DIMMER
	ci.draw_rect(r, Color(0.06, 0.05, 0.03, 1.0) if on else Color(0.032, 0.04, 0.06, 1.0), true)
	G2.stroke_rect(ci, r, col, 2.0 if (on and lit) else 1.0)
	if on and lit:
		G2.text_mid(ci, r.position + Vector2(-14, r.size.y * 0.5), "▸", 14.0, col)
	G2.text_mid(ci, r.position + Vector2(r.size.x * 0.5, 22), title, size,
			col if on else P.DIM)
	G2.text_mid(ci, r.position + Vector2(r.size.x * 0.5, r.size.y - 14), note, 11.0, P.DIMMER)
