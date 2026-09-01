class_name Art
extends RefCounted

## 플레이 화면 그리기.
##
## **노트는 그리기 호출 두 번(몸통 + 윗면 하이라이트)으로 끝낸다.** 빠른 구간에는
## 화면에 60~80장이 동시에 깔린다. 장당 한 겹만 늘어도 비용이 그만큼 곱해진다.
## 발광은 겹쳐 그리지 말고 색을 1.0 위로 올려([method P.hdr]) 엔진 블룸에 맡긴다.
##
## 판정선은 **항상 그린다.** 프레임이 떨어져도 판정선이 안 보이면 게임 자체가
## 성립하지 않는다 — 이건 성능과 바꿀 수 있는 정보가 아니다.


## 레인 하나의 x 범위.
static func lane_rect(field: Rect2, lane: int, keys: int) -> Rect2:
	var w: float = D.LANE_W[keys]
	var x0 := field.position.x + (field.size.x - w * keys) * 0.5 + w * lane
	return Rect2(Vector2(x0, field.position.y), Vector2(w, field.size.y))


static func field_rect(field: Rect2, keys: int) -> Rect2:
	var w: float = D.LANE_W[keys] * keys
	return Rect2(Vector2(field.position.x + (field.size.x - w) * 0.5, field.position.y),
		Vector2(w, field.size.y))


static func hit_y(field: Rect2) -> float:
	return field.end.y - D.HIT_Y


## 노트의 화면 y. 시간이 클수록 위에 있다.
static func note_y(field: Rect2, dt: float, speed: float) -> float:
	var travel := hit_y(field) - field.position.y
	return hit_y(field) - dt / (D.SCROLL_SEC / speed) * travel


static func draw_field(ci: CanvasItem, field: Rect2, pl: Play, now: float,
		speed: float, bpm: float) -> void:
	var keys := pl.keys
	var fr := field_rect(field, keys)
	var hy := hit_y(field)
	# --- 바탕 ---
	ci.draw_rect(field, P.VOID)
	G2.vgrad(ci, fr, P.BG_TOP, P.BG_BOT)
	# --- 눌린 레인 ---
	for i in keys:
		if pl.lane_lit[i] <= 0.0:
			continue
		var lr := lane_rect(field, i, keys)
		G2.vgrad(ci, Rect2(lr.position + Vector2(0, lr.size.y * 0.45),
			Vector2(lr.size.x, lr.size.y * 0.55)),
			P.a(P.LANE_LIT, 0.0), P.a(P.LANE_LIT, pl.lane_lit[i] * 0.75))
	# --- 박자 격자 ---
	if bpm > 1.0:
		_beats(ci, field, keys, now, speed, bpm)
	# --- 레인 구분선 ---
	for i in keys + 1:
		var x: float = fr.position.x + float(D.LANE_W[keys]) * i
		ci.draw_line(Vector2(x, fr.position.y), Vector2(x, fr.end.y), P.LANE_EDGE, 1.0)
	_notes(ci, field, pl, now, speed)
	_hit_line(ci, fr, hy, pl)
	_warp(ci, fr, pl.warp)


## 음이탈 표시. 소리가 무너지는 것이 본 신호지만, **처음 치는 사람은 소리가
## 왜 이상해졌는지 모른다** — 화면이 같이 흐려져야 "내가 틀려서 그렇구나"가 읽힌다.
## 위에서 내려오는 붉은 기운이라 판정선의 타격 섬광과 헷갈리지 않는다.
static func _warp(ci: CanvasItem, fr: Rect2, w: float) -> void:
	if w <= 0.02:
		return
	G2.vgrad(ci, Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.55)),
		P.a(P.J_MISS, 0.30 * w), P.a(P.J_MISS, 0.0))


## 마디·박 선. 노트가 어디쯤 떨어질지 눈이 미리 잡게 해 준다.
static func _beats(ci: CanvasItem, field: Rect2, keys: int, now: float, speed: float, bpm: float) -> void:
	var fr := field_rect(field, keys)
	var b := 60.0 / bpm
	var ahead := D.SCROLL_SEC / speed * D.DRAW_AHEAD
	var i := int(ceil(now / b))
	var t := i * b
	while t < now + ahead:
		var y := note_y(field, t - now, speed)
		if y >= field.position.y:
			var strong := (i % 4) == 0
			ci.draw_line(Vector2(fr.position.x, y), Vector2(fr.end.x, y),
				P.a(P.BEAT, 1.0 if strong else 0.45), 1.0)
		i += 1
		t = i * b


static func _notes(ci: CanvasItem, field: Rect2, pl: Play, now: float, speed: float) -> void:
	var keys := pl.keys
	var lw: float = D.LANE_W[keys]
	var ahead := D.SCROLL_SEC / speed * D.DRAW_AHEAD
	var pad := lw * 0.09
	# 레인마다 커서부터 앞으로만 훑는다 — 전체 배열을 매 프레임 도는 것은
	# 3분 채보(노트 2천 개)에서 그냥 낭비다.
	for lane in keys:
		var arr: Array = pl.lane_of[lane]
		var lx := lane_rect(field, lane, keys).position.x
		# 커서는 이미 지나간 노트를 가리키지 않으므로 조금 뒤에서 시작한다.
		var i: int = maxi(0, pl.lane_idx[lane] - 2)
		while i < arr.size():
			var n: Dictionary = pl.notes[arr[i]]
			var dt: float = n.t - now
			if dt > ahead:
				break
			i += 1
			if n.st == Play.DONE:
				continue
			if dt < -D.DRAW_BEHIND and n.st != Play.HOLDING:
				continue
			var body := P.note_col(lane, keys)
			var hi := P.note_hi(lane, keys)
			if n.st == Play.MISSED:
				body = P.HOLD_DIM
				hi = P.HOLD_DIM
			var y := note_y(field, dt, speed)
			if n.dur > 0.0:
				_hold(ci, field, n, lane, lx, lw, pad, now, speed, body, hi)
			else:
				_tap(ci, lx + pad, y, lw - pad * 2.0, body, hi)


static func _tap(ci: CanvasItem, x: float, y: float, w: float, body: Color, hi: Color) -> void:
	var h := D.NOTE_H
	ci.draw_rect(Rect2(x, y - h * 0.5, w, h), body)
	# 윗면 하이라이트 — 이거 하나로 노트가 "판"이 아니라 "덩어리"로 읽힌다.
	ci.draw_rect(Rect2(x, y - h * 0.5, w, h * 0.26), P.hdr(hi, 1.25))


static func _hold(ci: CanvasItem, field: Rect2, n: Dictionary, lane: int, lx: float,
		lw: float, pad: float, now: float, speed: float, body: Color, hi: Color) -> void:
	var hy := hit_y(field)
	var y_head := note_y(field, n.t - now, speed)
	var y_tail := note_y(field, n.t + n.dur - now, speed)
	# 누르고 있는 동안 머리는 판정선에 붙어 있는다 — 안 그러면 이미 잡은 노트가
	# 화면 아래로 흘러가서 얼마나 남았는지 안 보인다.
	if n.st == Play.HOLDING:
		y_head = minf(y_head, hy)
	var top := minf(y_head, y_tail)
	var bot := maxf(y_head, y_tail)
	var wob := lw * 0.30
	ci.draw_rect(Rect2(lx + wob, top, lw - wob * 2.0, bot - top),
		P.a(body, 0.34 if n.st != Play.HOLDING else 0.60))
	_tap(ci, lx + pad, y_tail, lw - pad * 2.0, body, hi)
	if y_head <= hy + 2.0:
		_tap(ci, lx + pad, y_head, lw - pad * 2.0, body, hi)


static func _hit_line(ci: CanvasItem, fr: Rect2, hy: float, pl: Play) -> void:
	var keys := pl.keys
	var lw: float = D.LANE_W[keys]
	# 레인별 타격 섬광 — 판정선 위로 짧게 번진다.
	for i in keys:
		if pl.flash[i] <= 0.0:
			continue
		var x := fr.position.x + lw * i
		var k := pl.flash[i]
		G2.vgrad(ci, Rect2(x, hy - 130.0 * k, lw, 130.0 * k),
			P.a(P.note_col(i, keys), 0.0), P.a(P.note_hi(i, keys), 0.42 * k))
	ci.draw_rect(Rect2(fr.position.x, hy - 2.0, fr.size.x, 4.0), P.hdr(P.WHITE, 1.25))
	ci.draw_rect(Rect2(fr.position.x, hy + 2.0, fr.size.x, 26.0), P.a(P.LANE_EDGE, 0.55))
	# 키 표시
	var km: Array = D.KEYMAP[keys]
	for i in keys:
		var x := fr.position.x + lw * (i + 0.5)
		var lit := pl.lane_held[i] == 1
		G2.text_c(ci, Vector2(x, hy + 15.0), OS.get_keycode_string(km[i]), 13,
			P.hdr(P.WHITE, 1.2) if lit else P.DIMMER)
