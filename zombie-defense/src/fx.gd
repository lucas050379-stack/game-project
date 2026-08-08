class_name Fx
extends RefCounted

## 파티클 · 데미지 숫자 · 고리 · 화면 섬광.
##
## 적이 많아 이펙트도 금방 불어난다. 개수 상한을 두고 오래된 것부터 버린다.

const MAX_PARTS := 420
const MAX_TEXTS := 90

var parts: Array = []
var texts: Array = []
var rings: Array = []
var flash_col := P.WHITE
var flash_t := 0.0
var flash_max := 0.0


func clear() -> void:
	parts.clear()
	texts.clear()
	rings.clear()
	flash_t = 0.0


func spark(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		if parts.size() >= MAX_PARTS:
			parts.pop_front()
		var a := randf() * TAU
		var sp := randf_range(60.0, 230.0)
		parts.append({
			"p": at, "v": Vector2(cos(a), sin(a)) * sp,
			"r": randf_range(2.0, 4.6), "life": randf_range(0.22, 0.5),
			"max": 0.5, "col": col, "drag": 4.0,
		})


func boom(at: Vector2, col: Color, r: float) -> void:
	ring(at, col, r, 0.34)
	for i in 16:
		if parts.size() >= MAX_PARTS:
			parts.pop_front()
		var a := randf() * TAU
		parts.append({
			"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(120.0, r * 3.4),
			"r": randf_range(3.0, 7.0), "life": randf_range(0.3, 0.62),
			"max": 0.62, "col": col, "drag": 3.0,
		})


func ring(at: Vector2, col: Color, r: float, dur: float) -> void:
	rings.append({"p": at, "r": r, "life": dur, "max": dur, "col": col})


func dmg_text(at: Vector2, v: float, col: Color) -> void:
	if texts.size() >= MAX_TEXTS:
		texts.pop_front()
	texts.append({
		"p": at + Vector2(randf_range(-8.0, 8.0), -10.0),
		"s": str(int(round(v))), "life": 0.62, "max": 0.62,
		"col": col, "size": 15.0 + minf(11.0, v * 0.16),
	})


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
