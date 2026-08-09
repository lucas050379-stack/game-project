class_name Fx
extends RefCounted

## 파티클 · 데미지 숫자 · 고리 · 화면 섬광.
##
## 적이 많아 이펙트도 금방 불어난다. 개수 상한을 두고 **자리를 돌려 쓴다**.
##
## **`pop_front()` 으로 버리지 마세요.** 배열을 통째로 앞으로 당기는 연산이라, 상한이 꽉 찬
## 상태에서 초당 수백 번 불리면 그것만으로 프레임을 먹습니다.
## 수명이 다한 것은 `update()` 가 따로 지우므로 돌려 쓰는 순서가 정확히 오래된 순은 아니지만,
## 0.2~0.6초 사는 알갱이라 눈에는 차이가 없습니다.
##
## **데미지 숫자는 `draw_string` 이라 특히 비쌉니다.** 무기 5개를 진화시키고 적이 600마리쯤
## 되면 숫자만 100개가 떠서 그리기에 4ms 를 썼습니다(실측) — 그 상황에서는 읽을 수도 없는
## 숫자입니다. 상한을 낮추고, 자리가 차면 드물게만 띄웁니다.

## 알갱이 하나하나가 GDScript 루프 한 바퀴 + `draw_circle` 한 번이다. 420개를 두면
## 그리는 데만 2ms 가 갔다(실측). 220개면 한꺼번에 터져도 충분히 자글자글하다.
const MAX_PARTS := 220
const MAX_TEXTS := 24
## 고리는 `draw_arc` 라 한 개가 선분 28개다. 진화한 미사일 8발이 계속 터지면 금방 쌓인다.
const MAX_RINGS := 12

var parts: Array = []
var texts: Array = []
var rings: Array = []
var flash_col := P.WHITE
var flash_t := 0.0
var flash_max := 0.0

var _part_i := 0
var _text_i := 0
var _ring_i := 0


func clear() -> void:
	parts.clear()
	texts.clear()
	rings.clear()
	_part_i = 0
	_text_i = 0
	_ring_i = 0
	flash_t = 0.0


func _push_part(q: Dictionary) -> void:
	if parts.size() < MAX_PARTS:
		parts.append(q)
		return
	parts[_part_i] = q
	_part_i = (_part_i + 1) % MAX_PARTS


func _push_text(q: Dictionary) -> void:
	if texts.size() < MAX_TEXTS:
		texts.append(q)
		return
	texts[_text_i] = q
	_text_i = (_text_i + 1) % MAX_TEXTS


func spark(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(60.0, 230.0)
		_push_part({
			"p": at, "v": Vector2(cos(a), sin(a)) * sp,
			"r": randf_range(2.0, 4.6), "life": randf_range(0.22, 0.5),
			"max": 0.5, "col": col, "drag": 4.0,
		})


func boom(at: Vector2, col: Color, r: float) -> void:
	ring(at, col, r, 0.34)
	for i in 16:
		var a := randf() * TAU
		_push_part({
			"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(120.0, r * 3.4),
			"r": randf_range(3.0, 7.0), "life": randf_range(0.3, 0.62),
			"max": 0.62, "col": col, "drag": 3.0,
		})


func ring(at: Vector2, col: Color, r: float, dur: float) -> void:
	var q := {"p": at, "r": r, "life": dur, "max": dur, "col": col}
	if rings.size() < MAX_RINGS:
		rings.append(q)
		return
	rings[_ring_i] = q
	_ring_i = (_ring_i + 1) % MAX_RINGS


func dmg_text(at: Vector2, v: float, col: Color) -> void:
	# 자리가 다 차 있으면 대부분 건너뛴다 — 안 그러면 24칸을 초당 수백 번 갈아 치우며
	# 숫자가 부르르 떨기만 하고, 그리기 비용은 그대로 든다.
	if texts.size() >= MAX_TEXTS and randf() > 0.22:
		return
	_push_text({
		"p": at + Vector2(randf_range(-8.0, 8.0), -10.0),
		"s": str(int(round(v))), "life": 0.62, "max": 0.62,
		"col": col, "size": 15.0 + minf(11.0, v * 0.16),
	})


## 레벨업 같은 알림은 상한과 무관하게 반드시 보여야 한다
func level_text(at: Vector2, s: String, col: Color) -> void:
	texts.append({"p": at, "s": s, "life": 1.1, "max": 1.1, "col": col, "size": 26.0})


func flash(col: Color, strength: float) -> void:
	flash_col = col
	flash_t = strength
	flash_max = maxf(strength, 0.001)


func update(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var q: Dictionary = parts[i]
		q["life"] = float(q["life"]) - dt
		if float(q["life"]) <= 0.0:
			parts.remove_at(i)
			continue
		q["p"] = q["p"] + q["v"] * dt
		q["v"] = q["v"] * exp(-dt * float(q["drag"]))

	for i in range(texts.size() - 1, -1, -1):
		var t: Dictionary = texts[i]
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			texts.remove_at(i)
			continue
		t["p"] = t["p"] + Vector2(0, -46.0 * dt)

	for i in range(rings.size() - 1, -1, -1):
		rings[i]["life"] = float(rings[i]["life"]) - dt
		if float(rings[i]["life"]) <= 0.0:
			rings.remove_at(i)

	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - dt * 1.9)


## 월드 좌표계에서 그리는 것들
func draw_world(ci: CanvasItem) -> void:
	for r: Dictionary in rings:
		var u: float = 1.0 - float(r["life"]) / float(r["max"])
		var rr: float = float(r["r"]) * G2.out_cubic(u)
		ci.draw_arc(r["p"], rr, 0.0, TAU, 28,
			P.a(P.hdr(r["col"], 1.5), (1.0 - u) * 0.85), maxf(1.5, 5.0 * (1.0 - u)), true)

	for q: Dictionary in parts:
		var a: float = clampf(float(q["life"]) / float(q["max"]), 0.0, 1.0)
		ci.draw_circle(q["p"], float(q["r"]) * (0.4 + a * 0.6),
			P.a(P.hdr(q["col"], 1.6), a))

	for t: Dictionary in texts:
		var a2: float = clampf(float(t["life"]) / float(t["max"]), 0.0, 1.0)
		var pop: float = 1.0 + (1.0 - a2) * 0.25
		G2.text_mid(ci, t["p"], t["s"], float(t["size"]) * pop,
			P.a(P.hdr(t["col"], 1.35), minf(1.0, a2 * 1.8)))


## 화면 좌표계 (카메라 영향 없음)
func draw_screen(ci: CanvasItem, w: float, h: float) -> void:
	if flash_t > 0.0:
		ci.draw_rect(Rect2(0, 0, w, h), P.a(flash_col, clampf(flash_t, 0.0, 0.7) * 0.55))
