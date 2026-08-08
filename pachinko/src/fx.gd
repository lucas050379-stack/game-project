class_name Fx
extends RefCounted

## 파티클 · 떠오르는 글자 · 고리 · 금화 · 화면 흔들림 · 섬광.
##
## 발광은 HDR 색으로 낸다 — 엔진 블룸이 알아서 번지게 해준다.

enum Kind { DOT, SPARK, DEBRIS, SMOKE, COIN }

var _parts: Array = []
var _texts: Array = []
var _rings: Array = []
var _coins: Array = []

var shake_mag := 0.0
var shake_t := 0.0
var flash_a := 0.0
var flash_c := Color.WHITE
var _time := 0.0


func clear() -> void:
	_parts.clear()
	_texts.clear()
	_rings.clear()
	_coins.clear()
	shake_mag = 0.0
	flash_a = 0.0

# ==================== 생성 ====================

func burst(p: Vector2, n: int, c1: Color, c2: Color, speed: float, size: float,
		kind: int = Kind.SPARK) -> void:
	for i in n:
		var a := randf() * TAU
		var v := speed * randf_range(0.35, 1.15)
		_parts.append({
			"k": kind, "p": p, "v": Vector2(cos(a), sin(a)) * v,
			"g": -30.0 if kind == Kind.SMOKE else 620.0,
			"drag": 0.94 if kind == Kind.SMOKE else 0.985,
			"life": randf_range(0.45, 1.15), "max": 1.0,
			"size": size * randf_range(0.6, 1.4),
			"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"c1": c1, "c2": c2,
		})
		_parts[-1]["max"] = _parts[-1]["life"]


func coin_rain(w: float, n: int) -> void:
	for i in n:
		_parts.append({
			"k": Kind.COIN, "p": Vector2(randf() * w, randf_range(-260.0, -20.0)),
			"v": Vector2(randf_range(-50.0, 50.0), randf_range(160.0, 380.0)),
			"g": 340.0, "drag": 1.0,
			"life": randf_range(2.2, 3.4), "max": 3.4,
			"size": randf_range(9.0, 17.0), "rot": 0.0, "spin": randf_range(6.0, 14.0),
			"c1": P.GOLD_HI, "c2": P.GOLD_DEEP,
		})
		_parts[-1]["max"] = _parts[-1]["life"]


func text(p: Vector2, s: String, c: Color, size: float, big: bool) -> void:
	_texts.append({
		"s": s, "p": p, "vy": -34.0 if big else -62.0,
		"life": 1.5 if big else 1.0, "max": 1.5 if big else 1.0,
		"size": size, "c": c, "big": big,
	})


func wave(p: Vector2, c: Color, max_r: float, life: float, w: float) -> void:
	_rings.append({"p": p, "r": 0.0, "max_r": max_r, "life": life, "life0": life, "w": w, "c": c})


func flash(c: Color, a: float) -> void:
	flash_c = c
	flash_a = maxf(flash_a, a)


func shake(m: float) -> void:
	shake_mag = maxf(shake_mag, m)
	shake_t = 0.0


func fly_coin(from: Vector2, to: Vector2, delay: float, size: float) -> void:
	_coins.append({
		"a": from, "b": to,
		"c": Vector2((from.x + to.x) * 0.5 + randf_range(-180.0, 180.0),
				minf(from.y, to.y) - randf_range(90.0, 260.0)),
		"t": -delay, "dur": randf_range(0.55, 0.85),
		"spin": randf_range(8.0, 16.0), "size": size,
	})

# ==================== 갱신 ====================

func update(dt: float) -> void:
	_time += dt
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["life"] -= dt
		if p["life"] <= 0.0:
			_parts.remove_at(i)
			continue
		p["v"].y += p["g"] * dt
		p["v"] *= pow(p["drag"], dt * 60.0)
		p["p"] += p["v"] * dt
		p["rot"] += p["spin"] * dt

	for i in range(_texts.size() - 1, -1, -1):
		var q: Dictionary = _texts[i]
		q["life"] -= dt
		if q["life"] <= 0.0:
			_texts.remove_at(i)
			continue
		q["p"].y += q["vy"] * dt
		q["vy"] *= pow(0.955, dt * 60.0)

	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		r["life"] -= dt
		if r["life"] <= 0.0:
			_rings.remove_at(i)
			continue
		r["r"] = r["max_r"] * G2.out_quint(1.0 - r["life"] / r["life0"])

	for i in range(_coins.size() - 1, -1, -1):
		_coins[i]["t"] += dt
		if _coins[i]["t"] >= _coins[i]["dur"]:
			_coins.remove_at(i)

	if shake_mag > 0.0:
		shake_t += dt
		shake_mag = maxf(0.0, shake_mag - dt * (14.0 + shake_mag * 4.0))
	if flash_a > 0.0:
		flash_a = maxf(0.0, flash_a - dt * 3.6)


func shake_offset() -> Vector2:
	if shake_mag <= 0.02:
		return Vector2.ZERO
	var f := shake_t * 46.0
	return Vector2(sin(f) * shake_mag, cos(f * 1.37) * shake_mag * 0.8)

# ==================== 그리기 ====================

func draw_back(ci: CanvasItem) -> void:
	for r: Dictionary in _rings:
		var a: float = r["life"] / r["life0"]
		G2.stroke(ci, G2.circle(r["p"], r["r"], 40),
				P.a(P.hdr(r["c"], 1.5), a * 0.9), r["w"] * a + 1.0)


func draw_front(ci: CanvasItem) -> void:
	for p: Dictionary in _parts:
		var u: float = p["life"] / p["max"]
		var c: Color = (p["c2"] as Color).lerp(p["c1"], u)
		var s: float = p["size"] * ((2.0 - u) if p["k"] == Kind.SMOKE else u)
		match p["k"]:
			Kind.SPARK:
				var tail: Vector2 = p["p"] - p["v"] * 0.022
				ci.draw_line(tail, p["p"], P.a(P.hdr(c, 1.6), u), s * 0.9, true)
			Kind.DEBRIS:
				ci.draw_set_transform(p["p"], p["rot"], Vector2.ONE)
				G2.fill_round(ci, Rect2(-s * 0.7, -s * 0.45, s * 1.4, s * 0.9), s * 0.2, P.a(c, u))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Kind.SMOKE:
				ci.draw_circle(p["p"], s, P.a(c, u * 0.30))
			Kind.COIN:
				Art.coin(ci, p["p"], s, p["rot"], minf(1.0, u * 4.0))
			_:
				ci.draw_circle(p["p"], s * 0.6, P.a(P.hdr(c, 1.4), u))

	for c: Dictionary in _coins:
		if c["t"] < 0.0:
			continue
		var u: float = clampf(c["t"] / c["dur"], 0.0, 1.0)
		var iu := 1.0 - u
		var p: Vector2 = iu * iu * (c["a"] as Vector2) + 2.0 * iu * u * (c["c"] as Vector2) \
				+ u * u * (c["b"] as Vector2)
		Art.coin(ci, p, c["size"], c["t"] * c["spin"], 1.0 - u * u * 0.3)

	for q: Dictionary in _texts:
		var u: float = q["life"] / q["max"]
		var a: float = minf(1.0, u * 3.2)
		if q["big"]:
			var pop := 1.0 + 0.30 * sin(minf(1.0, (1.0 - u) * 4.0) * PI)
			G2.text_outline(ci, q["p"], q["s"], q["size"] * pop,
					P.a(P.hdr(q["c"], 1.3), a), P.a(P.darken(q["c"], 0.72), a), q["size"] * 0.10)
		else:
			G2.text_mid(ci, q["p"], q["s"], q["size"], P.a(P.hdr(q["c"], 1.2), a))


func draw_flash(ci: CanvasItem, w: float, h: float) -> void:
	if flash_a <= 0.004:
		return
	ci.draw_rect(Rect2(0, 0, w, h), P.a(flash_c, flash_a))
