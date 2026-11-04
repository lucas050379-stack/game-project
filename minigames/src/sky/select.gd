class_name SaSel
extends RefCounted

## 기체 · 난이도 · (테스트 빌드에서만) 라운드 선택 화면 — 세로 화면판.
##
## 갈루가는 가로 창에 기체 카드 일곱 장을 나란히 깔았다. 세로 화면에서는 일곱 장이 한 줄에
## 들어가면 설명을 읽을 수가 없어서 **고른 기체 하나를 크게(설명 카드) + 일곱 대를 작은 칸 한 줄**로
## 나눴다. 칸을 누르면 고르고, 아래 "출격" 을 누르면 시작한다.
##
## **카드 안은 위에서 아래로 흘려 놓는다.** `SaG2.wrap` 이 다음 줄이 시작될 y 를 돌려준다.
## **마지막 줄(봄)만은 카드 바닥 기준** — 위에서 흘리면 글이 긴 기체에서 카드 밖으로 떨어진다.
##
## 자리 함수(`*_rect`)는 그리기와 클릭이 같이 본다.

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
	return 3 if SaD.test_build() else 2


func _move(step_i: int) -> void:
	match row:
		ROW_CRAFT:
			craft = posmod(craft + step_i, SaD.CRAFT.size())
		ROW_DIFF:
			diff = clampi(diff + step_i, 0, SaD.DIFF.size() - 1)
		ROW_ROUND:
			round = clampi(round + step_i, 0, SaD.ROUND.size() - 1)


func key(code: int) -> bool:
	match code:
		KEY_LEFT, KEY_A: _move(-1)
		KEY_RIGHT, KEY_D: _move(1)
		KEY_UP, KEY_W: row = maxi(0, row - 1)
		KEY_DOWN, KEY_S: row = mini(rows() - 1, row + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_X:
			return true
	return false

# ==================== 자리 ====================


func hub_rect(_vs: Vector2) -> Rect2:
	return Rect2(18, 18, 170, 52)


func start_rect(vs: Vector2) -> Rect2:
	if _wide(vs):
		return Rect2(_rx(vs) + _rw(vs) * 0.5 - 180, round_rect(0, vs).end.y + 30 if rows() > 2 else diff_rect(0, vs).end.y + 30,
				360, 92)
	return Rect2(vs.x * 0.5 - 180, vs.y - 150, 360, 92)


## 가로 화면 — 왼쪽은 고른 기체 설명 카드(높이 가득), 오른쪽은 위에서부터 기체 · 난이도 · 라운드 · 출격(사용자 결정 11-04).
func _wide(vs: Vector2) -> bool:
	return vs.x > vs.y


func _rx(vs: Vector2) -> float:
	return 24.0 + vs.x * 0.42 + 24.0


func _rw(vs: Vector2) -> float:
	return vs.x - _rx(vs) - 24.0


func round_rect(i: int, vs: Vector2) -> Rect2:
	var n := SaD.ROUND.size()
	var gap := 8.0
	if _wide(vs):
		var bw2 := (_rw(vs) - gap * (n - 1)) / n
		return Rect2(_rx(vs) + i * (bw2 + gap), diff_rect(0, vs).end.y + 20, bw2, 76)
	var bw := (vs.x - 48.0 - gap * (n - 1)) / n
	return Rect2(24 + i * (bw + gap), start_rect(vs).position.y - 100, bw, 76)


func diff_rect(i: int, vs: Vector2) -> Rect2:
	var n := SaD.DIFF.size()
	var gap := 10.0
	if _wide(vs):
		var bw2 := (_rw(vs) - gap * (n - 1)) / n
		return Rect2(_rx(vs) + i * (bw2 + gap), tile_rect(0, vs).end.y + 24, bw2, 88)
	var bw := (vs.x - 48.0 - gap * (n - 1)) / n
	var y := (round_rect(0, vs).position.y if rows() > 2 else start_rect(vs).position.y) - 108
	return Rect2(24 + i * (bw + gap), y, bw, 88)


func tile_rect(i: int, vs: Vector2) -> Rect2:
	var n := SaD.CRAFT.size()
	var gap := 8.0
	if _wide(vs):
		var bw2 := (_rw(vs) - gap * (n - 1)) / n
		return Rect2(_rx(vs) + i * (bw2 + gap), 170, bw2, bw2 * 1.2)
	var bw := (vs.x - 48.0 - gap * (n - 1)) / n
	return Rect2(24 + i * (bw + gap), diff_rect(0, vs).position.y - bw * 1.2 - 24, bw, bw * 1.2)


func card_rect(vs: Vector2) -> Rect2:
	var top := 162.0
	if _wide(vs):
		return Rect2(24, top, vs.x * 0.42, vs.y - top - 60)
	return Rect2(24, top, vs.x - 48, tile_rect(0, vs).position.y - 24 - top)


## 눌린 자리가 무엇이었나. "start" · "hub" · ""(고르기만 했거나 아무것도 아님).
func hit(p: Vector2, vs: Vector2) -> String:
	if hub_rect(vs).has_point(p):
		return "hub"
	if start_rect(vs).has_point(p):
		return "start"
	for i in SaD.CRAFT.size():
		if tile_rect(i, vs).has_point(p):
			craft = i
			row = ROW_CRAFT
			return ""
	for i in SaD.DIFF.size():
		if diff_rect(i, vs).has_point(p):
			diff = i
			row = ROW_DIFF
			return ""
	if rows() > 2:
		for i in SaD.ROUND.size():
			if round_rect(i, vs).has_point(p):
				round = i
				row = ROW_ROUND
				return ""
	return ""

# ==================== 그리기 ====================


func draw(ci: CanvasItem, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), SaP.VOID, true)
	var y := 8.0
	while y < vs.y:
		ci.draw_line(Vector2(0, y), Vector2(vs.x, y), SaP.a(SaP.DIM, 0.04), 1.0)
		y += 9.0

	var hb := hub_rect(vs)
	ci.draw_rect(hb, Color(0.05, 0.07, 0.11, 1.0), true)
	ci.draw_rect(hb, SaP.a(SaP.DIM, 0.6), false, 1.5)
	SaG2.text_mid(ci, hb.get_center(), "게임 선택", 26.0, SaP.DIM)
	if rows() > 2:
		var badge := Rect2(vs.x - 160, 30, 136, 30)
		ci.draw_rect(badge, SaP.a(SaP.FOE_MARK, 0.18), true)
		SaG2.stroke_rect(ci, badge, SaP.hdr(SaP.FOE_MARK, 1.1), 1.0)
		SaG2.text_mid(ci, badge.get_center(), "TEST BUILD", 20.0, SaP.hdr(SaP.FOE_MARK, 1.15))

	SaG2.text_mid(ci, Vector2(vs.x * 0.5, 84), "스카이 어설트", 56.0, SaP.WHITE)
	SaG2.text_mid(ci, Vector2(vs.x * 0.5, 138), "기체마다 파워업이 자라는 방향이 다릅니다", 22.0, SaP.DIM)

	_card(ci, card_rect(vs))
	for i in SaD.CRAFT.size():
		_tile(ci, i, tile_rect(i, vs))
	for i in SaD.DIFF.size():
		_box(ci, diff_rect(i, vs), SaD.DIFF[i].name, SaD.DIFF[i].note, i == diff,
				row == ROW_DIFF, 28.0)
	if rows() > 2:
		for i in SaD.ROUND.size():
			var rd: Dictionary = SaD.ROUND[i]
			_box(ci, round_rect(i, vs), "%d라운드" % (i + 1),
					String(rd.name).split(" · ")[1], i == round, row == ROW_ROUND, 22.0)

	var sr := start_rect(vs)
	var col := SaP.craft(craft, 3)
	SaG2.glow(ci, sr.get_center(), sr.size.x * 0.6, col, 0.12 + 0.05 * sin(t * 4.0))
	ci.draw_rect(sr, Color(0.07, 0.09, 0.14, 1.0), true)
	ci.draw_rect(sr, SaP.hdr(col, 1.15), false, 3.0)
	SaG2.text_mid(ci, sr.get_center(), "출격", 52.0, SaP.hdr(col, 1.1))
	SaG2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 30),
			"끌어서 이동, 사격은 자동. 스킬은 누르고 있다 떼기", 22.0, SaP.DIMMER)


## 고른 기체의 설명 카드.
func _card(ci: CanvasItem, r: Rect2) -> void:
	var c: Dictionary = SaD.CRAFT[craft]
	var col := SaP.craft(craft, 3)
	ci.draw_rect(r, Color(0.05, 0.07, 0.11, 1.0), true)
	# 가로 화면은 카드가 낮아서 그림 · 글 시작 자리를 높이에 비례해 올린다(세로 화면 카드는 그대로)
	var ay := minf(120.0, r.size.y * 0.19)
	var asc := minf(3.2, r.size.y / 210.0)
	SaG2.glow(ci, r.position + Vector2(r.size.x * 0.5, ay), r.size.x * 0.5, col, 0.12)
	SaG2.stroke_rect(ci, r, SaP.hdr(col, 1.1), 2.0)
	SaArt.craft(ci, craft, r.position + Vector2(r.size.x * 0.5, ay + sin(t * 1.5) * 5.0), t, asc)

	var x := r.position.x + 26.0
	var mw := r.size.x - 52.0
	var y := r.position.y + minf(250.0, r.size.y * 0.34)
	SaG2.text(ci, Vector2(x, y), c.id, 22.0, SaP.a(col, 0.9))
	SaG2.text(ci, Vector2(x + 80, y), c.name, 38.0, SaP.hdr(col, 1.05))
	SaG2.text_right(ci, Vector2(r.end.x - 26, y), c.axis, 24.0, SaP.hdr(SaP.GOLD, 1.0))
	y += 22.0
	ci.draw_line(Vector2(x, y), Vector2(x + mw, y), SaP.a(SaP.DIMMER, 0.4), 1.0)
	y += 34.0
	SaG2.text(ci, Vector2(x, y), "기본탄", 22.0, SaP.DIMMER)
	y = SaG2.wrap(ci, Vector2(x, y + 28), c.basic, 25.0, SaP.WHITE, mw, 34.0)
	SaG2.text(ci, Vector2(x, y + 8), "파워업 방향", 22.0, SaP.DIMMER)
	y = SaG2.wrap(ci, Vector2(x, y + 36), c.grow, 25.0, SaP.DIM, mw, 34.0)
	SaG2.text(ci, Vector2(x, y + 8), "스킬  " + String(c.skill), 22.0, SaP.DIMMER)
	SaG2.wrap(ci, Vector2(x, y + 36), c.skill_note, 25.0, SaP.DIM, mw, 34.0)
	# 봄은 카드 바닥 기준 — 위 글이 길어도 카드 안에 남는다.
	var by := r.end.y - 24.0
	SaG2.text(ci, Vector2(x, by), "봄", 22.0, SaP.DIMMER)
	SaG2.text(ci, Vector2(x + 44, by), c.bomb, 28.0, SaP.hdr(col, 1.0))


## 기체 한 대짜리 작은 칸.
func _tile(ci: CanvasItem, i: int, r: Rect2) -> void:
	var col := SaP.craft(i, 3)
	var on := i == craft
	ci.draw_rect(r, Color(0.06, 0.08, 0.13, 1.0) if on else Color(0.03, 0.045, 0.07, 1.0), true)
	if on:
		SaG2.glow(ci, r.get_center(), r.size.x * 0.8, col, 0.18 if row == ROW_CRAFT else 0.1)
	SaG2.stroke_rect(ci, r, SaP.hdr(col, 1.1) if on else SaP.a(SaP.DIMMER, 0.35),
			2.5 if on and row == ROW_CRAFT else (1.6 if on else 1.0))
	SaArt.craft(ci, i, r.get_center() - Vector2(0, r.size.y * 0.1), t, r.size.x / 58.0)
	SaG2.text_mid(ci, Vector2(r.get_center().x, r.end.y - 14), SaD.CRAFT[i].id, 18.0,
			SaP.a(col, 0.95) if on else SaP.DIMMER)


## 난이도 · 라운드처럼 작은 칸. **고른 것과 지금 손이 가 있는 줄을 따로 보여 준다.**
func _box(ci: CanvasItem, r: Rect2, title: String, note: String, on: bool, lit: bool,
		size: float) -> void:
	var col := SaP.hdr(SaP.GOLD, 1.1) if on else SaP.DIMMER
	ci.draw_rect(r, Color(0.06, 0.05, 0.03, 1.0) if on else Color(0.032, 0.04, 0.06, 1.0), true)
	SaG2.stroke_rect(ci, r, col, 2.5 if (on and lit) else 1.0)
	SaG2.text_mid(ci, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.36), title, size,
			col if on else SaP.DIM)
	SaG2.text_mid(ci, r.position + Vector2(r.size.x * 0.5, r.size.y - 18), note, 19.0, SaP.DIMMER)
