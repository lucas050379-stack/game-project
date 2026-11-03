class_name WrFx
extends RefCounted

## 월드 러너 — 파티클 · 떠오르는 글자 · 날아가는 동전 · 화면 흔들림.
## 원본 세계마뷸 `Effects.cs` 를 옮겼다. 노드를 만들지 않고 [Dictionary] 배열로 든다.
##
## kind: 0 원 · 1 색종이 · 2 별 · 3 동전 · 4 먼지 · 5 퍼지는 고리 · 6 십자 반짝

const MAX_PARTS := 600

var parts: Array = []
var texts: Array = []
var coins: Array = []
var shake := 0.0
var shake_t := 0.0


func clear() -> void:
	parts.clear()
	texts.clear()
	coins.clear()
	shake = 0.0


func kick(m: float) -> void:
	shake = maxf(shake, m)


func step(dt: float) -> void:
	shake_t += dt
	shake *= pow(0.0015, dt)
	if shake < 0.05:
		shake = 0.0
	var keep: Array = []
	for p: Dictionary in parts:
		p.life -= dt
		if p.life <= 0.0:
			continue
		p.vy += p.grav * dt
		var d := pow(p.drag, dt * 60.0)
		p.vx *= d
		p.vy *= d
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.rot += p.vrot * dt
		keep.append(p)
	parts = keep
	var kt: Array = []
	for t: Dictionary in texts:
		t.life -= dt
		if t.life <= 0.0:
			continue
		t.y += t.vy * dt
		t.vy *= pow(0.25, dt)
		kt.append(t)
	texts = kt
	var kc: Array = []
	for c: Dictionary in coins:
		if c.delay > 0.0:
			c.delay -= dt
			kc.append(c)
			continue
		c.t += dt / c.dur
		if c.t >= 1.0:
			if c.done.is_valid():
				c.done.call()
			continue
		kc.append(c)
	coins = kc


func offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var ang := shake_t * 47.0
	return Vector2(sin(ang) * shake, cos(ang * 1.37) * shake * 0.7)

# ==================== 만들기 ====================


func _add(p: Dictionary) -> void:
	if parts.size() >= MAX_PARTS:
		return
	for k in ["vx", "vy", "rot", "vrot", "grav"]:
		if not p.has(k):
			p[k] = 0.0
	if not p.has("drag"):
		p.drag = 1.0
	if not p.has("max"):
		p.max = p.life
	parts.append(p)


func burst(x: float, y: float, n: int, c: Color, speed: float, size: float, kind: int) -> void:
	for i in n:
		var ang := randf() * TAU
		var s := speed * randf_range(0.35, 1.0)
		_add({"x": x, "y": y, "vx": cos(ang) * s, "vy": sin(ang) * s, "life": randf_range(0.35, 0.85), "max": 0.85,
				"size": size * randf_range(0.6, 1.4), "c": c, "kind": kind, "grav": 260.0, "drag": 0.93,
				"rot": randf() * TAU, "vrot": randf_range(-9.0, 9.0)})


func dust(x: float, y: float, c: Color) -> void:
	for i in 9:
		var ang := randf_range(PI * 0.15, PI * 0.85)
		var s := randf_range(40.0, 130.0)
		_add({"x": x + randf_range(-6, 6), "y": y, "vx": cos(ang) * -s * (1.0 if randf() < 0.5 else -1.0),
				"vy": -absf(sin(ang)) * s * 0.5, "life": randf_range(0.22, 0.42), "max": 0.42,
				"size": randf_range(3.0, 7.0), "c": c, "kind": 4, "grav": 120.0, "drag": 0.88})


func ring(x: float, y: float, c: Color, size: float, dur: float) -> void:
	_add({"x": x, "y": y, "life": dur, "size": size, "c": c, "kind": 5})


func sparkle(x: float, y: float, n: int, c: Color, spread: float) -> void:
	for i in n:
		_add({"x": x + randf_range(-spread, spread), "y": y + randf_range(-spread, spread),
				"vx": randf_range(-30, 30), "vy": randf_range(-70, -20), "life": randf_range(0.3, 0.7), "max": 0.7,
				"size": randf_range(4.0, 9.0), "c": c, "kind": 6, "grav": 40.0, "drag": 0.95,
				"rot": randf() * 3.0, "vrot": randf_range(-4, 4)})


func coin_fountain(x: float, y: float, n: int) -> void:
	for i in n:
		_add({"x": x + randf_range(-14, 14), "y": y, "vx": randf_range(-150, 150), "vy": randf_range(-380, -180),
				"life": randf_range(0.7, 1.3), "max": 1.3, "size": randf_range(7.0, 13.0), "c": WrD.GOLD, "kind": 3,
				"grav": 620.0, "drag": 0.995, "rot": randf() * 6.0, "vrot": randf_range(-12, 12)})


func coin_rain(w: float, h: float, n: int) -> void:
	for i in n:
		_add({"x": randf() * w, "y": randf_range(-h * 0.5, -10.0), "vx": randf_range(-40, 40),
				"vy": randf_range(150, 340), "life": randf_range(1.4, 2.4), "max": 2.4, "size": randf_range(8.0, 15.0),
				"c": WrD.GOLD, "kind": 3, "grav": 130.0, "vrot": randf_range(-10, 10)})


const CONFETTI := [Color8(255, 99, 132), Color8(255, 205, 86), Color8(75, 192, 192), Color8(153, 102, 255),
		Color8(96, 165, 250), Color8(74, 222, 128)]


func confetti(w: float, h: float, n: int) -> void:
	for i in n:
		_add({"x": randf() * w, "y": randf_range(-h * 0.4, 0.0), "vx": randf_range(-90, 90),
				"vy": randf_range(90, 260), "life": randf_range(2.0, 3.6), "max": 3.6, "size": randf_range(6.0, 13.0),
				"c": CONFETTI[randi() % CONFETTI.size()], "kind": 1, "grav": 60.0, "drag": 0.999,
				"rot": randf() * 6.0, "vrot": randf_range(-11, 11)})


func rocket(x: float, y: float) -> void:
	for i in 26:
		_add({"x": x + randf_range(-10, 10), "y": y + randf() * 14.0, "vx": randf_range(-70, 70),
				"vy": randf_range(60, 220), "life": randf_range(0.3, 0.8), "max": 0.8, "size": randf_range(6.0, 16.0),
				"c": Color8(255, 190, 80) if randf() < 0.5 else Color8(255, 120, 60), "kind": 0, "grav": -60.0,
				"drag": 0.9})


func trail(x: float, y: float, c: Color) -> void:
	_add({"x": x, "y": y, "vx": randf_range(-20, 20), "vy": randf_range(-20, 20), "life": 0.45, "size": 5.5,
			"c": c, "kind": 0, "drag": 0.9})


func float_text(s: String, x: float, y: float, c: Color, size: float, rise: float, life: float) -> void:
	texts.append({"s": s, "x": x, "y": y, "vy": -rise, "life": life, "max": life, "c": c, "size": size})


func fly_coin(x0: float, y0: float, x1: float, y1: float, dur: float, delay: float, done: Callable) -> void:
	coins.append({"x0": x0, "y0": y0, "x1": x1, "y1": y1, "dur": dur, "delay": delay, "t": 0.0,
			"arc": randf_range(50, 120), "done": done})

# ==================== 그리기 ====================


func draw(ci: CanvasItem) -> void:
	for p: Dictionary in parts:
		var lf: float = minf(1.0, p.life / p.max)
		var al := minf(1.0, lf * 1.6)
		var c: Color = p.c
		match int(p.kind):
			5:
				var t := 1.0 - lf
				var r: float = p.size * (0.2 + t * 1.4)
				ci.draw_arc(Vector2(p.x, p.y), r, 0.0, TAU, 40, WrIcons.a(c, 0.78 * lf), 3.5 * lf + 0.5, true)
			1:
				var w: float = p.size
				var h: float = p.size * (0.4 + 0.6 * absf(sin(p.rot * 1.7)))
				WrIcons.push(ci, WrIcons.xf(p.x, p.y, p.rot))
				ci.draw_rect(Rect2(-w / 2, -h / 2, w, h), WrIcons.a(c, al), true)
				WrIcons.pop(ci)
			2:
				WrIcons.star(ci, WrIcons.a(c, al), p.x, p.y, p.size, 5, p.rot)
			3:
				WrIcons.coin(ci, p.x, p.y, p.size, al, p.rot)
			4:
				WrIcons.fe(ci, WrIcons.a(c, al * 0.5), p.x - p.size, p.y - p.size * 0.6, p.size * 2.0, p.size * 1.2)
			6:
				var s: float = p.size * (0.4 + 0.6 * sin(lf * PI))
				WrIcons.fe(ci, WrIcons.a(c, al), p.x - s * 0.22, p.y - s, s * 0.44, s * 2.0)
				WrIcons.fe(ci, WrIcons.a(c, al), p.x - s, p.y - s * 0.22, s * 2.0, s * 0.44)
			_:
				ci.draw_circle(Vector2(p.x, p.y), p.size, WrIcons.a(c, al))
	for c: Dictionary in coins:
		if c.delay > 0.0:
			continue
		var t: float = minf(1.0, c.t)
		WrIcons.coin(ci, lerpf(c.x0, c.x1, t), lerpf(c.y0, c.y1, t) - sin(t * PI) * c.arc, 11.0, 1.0, t * 12.0)
	for t: Dictionary in texts:
		var lf: float = t.life / t.max
		var al := minf(1.0, lf * 2.2)
		var pop_k := 1.0 + 0.35 * maxf(0.0, 1.0 - (1.0 - lf) * 6.0)
		var size: float = t.size * pop_k
		var r := Rect2(t.x - 300, t.y - size, 600, size * 2)
		WrIcons.text(ci, t.s, size, WrIcons.a(t.c, al), r, 1, 8.0, size * 0.2, Color(0, 0, 0, 0.55 * al))
