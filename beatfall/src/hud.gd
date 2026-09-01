class_name Hud
extends RefCounted

## 플레이 중 화면 정보 · 결과 화면.
##
## **플레이필드 위·아래는 비워 둔다.** 노트가 거기서 내려오고 거기서 판정된다.
## 점수·체력·콤보는 전부 필드 **양옆**에 둔다. 가운데에 뭘 올리면 정확히
## 제일 봐야 하는 순간에 노트를 가린다.

const PAD := 22.0


static func draw_play(ci: CanvasItem, vs: Vector2, field: Rect2, pl: Play,
		song: Song, diff: Dictionary, now: float, total_t: float) -> void:
	var fr := Art.field_rect(field, pl.keys)
	var lw := fr.position.x                     ## 왼쪽 여백 폭
	var rx := fr.end.x
	var rw := vs.x - rx
	# ---------- 왼쪽: 곡 정보 · 진행도 ----------
	G2.text(ci, Vector2(PAD, 40.0), song.title(), 20, P.WHITE)
	G2.text(ci, Vector2(PAD, 62.0), "%s  ·  %s Lv.%d" % [song.artist(), diff.name, diff.level],
		13, P.DIM)
	_progress(ci, Rect2(PAD, 82.0, maxf(lw - PAD * 2.0, 60.0), 5.0), now, total_t)
	# ---------- 왼쪽 아래: 체력 ----------
	_hp(ci, Rect2(PAD, vs.y - 150.0, maxf(lw - PAD * 2.0, 60.0), 10.0), pl.hp)
	# ---------- 오른쪽: 점수 · 정확도 · 판정 수 ----------
	var x := rx + PAD
	G2.text(ci, Vector2(x, 44.0), "%07d" % pl.score(), 26, P.hdr(P.WHITE, 1.1))
	G2.text(ci, Vector2(x, 70.0), "%.2f%%" % (pl.acc() * 100.0), 15, P.DIM)
	var y := 108.0
	for j in 5:
		G2.text(ci, Vector2(x, y), D.J_NAME[j], 12, P.a(P.judge_col(j), 0.85))
		G2.text(ci, Vector2(x + 78.0, y), str(pl.counts[j]), 12, P.DIM)
		y += 18.0
	G2.text(ci, Vector2(x, vs.y - 150.0), "MAX %d" % pl.max_combo, 12, P.DIMMER)
	G2.text(ci, Vector2(x, vs.y - 132.0), "x%.1f" % Sv.speed, 12, P.DIMMER)
	# ---------- 필드 안: 콤보와 판정 ----------
	_combo(ci, fr, pl)


static func _progress(ci: CanvasItem, r: Rect2, now: float, total: float) -> void:
	ci.draw_rect(r, P.PANEL_EDGE)
	var k := clampf(now / maxf(total, 1.0), 0.0, 1.0)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), P.hdr(P.NOTE_A, 1.1))


static func _hp(ci: CanvasItem, r: Rect2, hp: float) -> void:
	G2.text(ci, Vector2(r.position.x, r.position.y - 8.0), "HP", 12, P.DIMMER)
	ci.draw_rect(r, P.PANEL_EDGE)
	var k := clampf(hp / D.HP_MAX, 0.0, 1.0)
	# 25% 아래에서 색이 갈린다. 숫자를 읽을 여유가 없는 화면이라 색으로만 알린다.
	var c := P.HP_OK if k > 0.25 else P.HP_LOW
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), P.hdr(c, 1.15))


## 콤보는 판정선보다 **위**, 노트가 오는 길 한가운데다. 뱀서처럼 옆으로 빼면
## 콤보가 끊긴 걸 눈치채지 못한다 — 시선이 이미 여기 고정돼 있다.
static func _combo(ci: CanvasItem, fr: Rect2, pl: Play) -> void:
	var cx := fr.position.x + fr.size.x * 0.5
	var cy := fr.end.y - D.HIT_Y - 210.0
	if pl.combo >= 3:
		G2.text_c(ci, Vector2(cx, cy), str(pl.combo), 40, P.hdr(P.COMBO, 1.15))
	if pl.pop_t <= 0.0 or pl.pop_j < 0:
		return
	var k := pl.pop_t / 0.55
	var col := P.a(P.judge_col(pl.pop_j), minf(1.0, k * 2.2))
	G2.text_c(ci, Vector2(cx, cy + 46.0), D.J_NAME[pl.pop_j], 22, P.hdr(col, 1.15))
	# 빠름/느림 표시. 이게 없으면 안 맞는 이유를 알 수가 없어서 실력이 안 는다.
	if pl.pop_j != D.MISS and absf(pl.pop_err) > D.WINDOW[0]:
		var s := "LATE" if pl.pop_err > 0.0 else "FAST"
		G2.text_c(ci, Vector2(cx, cy + 70.0), s, 13, P.a(P.DIM, minf(1.0, k * 2.2)))


# ==================== 결과 ====================

static func draw_result(ci: CanvasItem, vs: Vector2, pl: Play, song: Song,
		diff: Dictionary, best_new: bool) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), P.VOID)
	var cx := vs.x * 0.5
	G2.text_c(ci, Vector2(cx, 74.0), song.title(), 26, P.WHITE)
	G2.text_c(ci, Vector2(cx, 104.0), "%s Lv.%d" % [diff.name, diff.level], 14, P.DIM)
	var r := pl.result()
	G2.text_c(ci, Vector2(cx, 186.0), r.rank, 76,
		P.hdr(P.J_PERFECT if r.full else P.WHITE, 1.2))
	G2.text_c(ci, Vector2(cx, 254.0), "%07d" % r.score, 40, P.hdr(P.WHITE, 1.1))
	G2.text_c(ci, Vector2(cx, 288.0), "%.2f%%" % (r.acc * 100.0), 17, P.DIM)
	if r.full:
		G2.text_c(ci, Vector2(cx, 316.0), "FULL COMBO", 16, P.hdr(P.J_PERFECT, 1.2))
	if best_new:
		G2.text_c(ci, Vector2(cx, 340.0), "NEW RECORD", 14, P.hdr(P.J_GREAT, 1.15))
	var y := 384.0
	for j in 5:
		G2.text(ci, Vector2(cx - 130.0, y), D.J_NAME[j], 15, P.judge_col(j))
		G2.text(ci, Vector2(cx + 70.0, y), str(r.counts[j]), 15, P.WHITE)
		y += 24.0
	G2.text(ci, Vector2(cx - 130.0, y + 6.0), "MAX COMBO", 15, P.DIM)
	G2.text(ci, Vector2(cx + 70.0, y + 6.0), str(r.combo), 15, P.WHITE)
	G2.text_c(ci, Vector2(cx, vs.y - 44.0), "Enter — 곡 목록으로   ·   R — 다시", 14, P.DIMMER)


# ==================== 실패 ====================

static func draw_fail(ci: CanvasItem, vs: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), P.a(P.VOID, 0.82))
	G2.text_c(ci, Vector2(vs.x * 0.5, vs.y * 0.45), "FAILED", 56, P.hdr(P.J_MISS, 1.2))
	G2.text_c(ci, Vector2(vs.x * 0.5, vs.y * 0.45 + 44.0),
		"Enter — 곡 목록으로   ·   R — 다시", 14, P.DIMMER)
