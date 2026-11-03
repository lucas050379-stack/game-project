class_name Fx
extends RefCounted

## 이펙트 — 흰 텍스처 조각(`Tex.fx`)을 뿌리고 크기 · 회전 · 색 · 투명도를 바꾼다.
##
## **파티클은 가산 혼합 레이어 하나에서만 그린다**(main.gd 의 `fx_layer`). 일반 그림 사이에
## 섞어 그리면 혼합 방식이 바뀔 때마다 배칭이 끊긴다. 가산 혼합이라 텍스처의 검정 ·
## 투명은 그대로 사라지고 겹친 곳은 밝아진다.
##
## 상한(`D.FX_MAX`)이 차면 가장 오래된 자리를 덮어쓴다. `pop_front()` 는 배열 전체를
## 당기므로 초당 수백 번 부르면 그것만으로 프레임을 먹는다.
##
## 점수 숫자 같은 글자는 가산 혼합이면 바탕색에 묻히므로 `texts` 로 따로 두고
## 위 레이어(일반 혼합)에서 그린다.

var parts := []
var _next := 0
var texts := []
var shake := 0.0


func _init() -> void:
	parts.resize(D.FX_MAX)
	for i in D.FX_MAX:
		parts[i] = {"on": false}


func clear() -> void:
	for q in parts:
		q.on = false
	texts.clear()
	shake = 0.0


## lx > 0 이면 가로 길이를 그 값으로 고정한다(광선). 0 이면 크기대로 정사각형.
func _push(tex: String, p: Vector2, v: Vector2, life: float, s0: float, s1: float, col: Color,
		rot: float = 0.0, spin: float = 0.0, g: float = 0.0, lx: float = 0.0, delay: float = 0.0) -> void:
	var q: Dictionary = parts[_next]
	_next = (_next + 1) % D.FX_MAX
	q.on = true
	q.tex = Tex.fx(tex)
	q.p = p
	q.v = v
	q.life = life
	q.age = 0.0
	q.s0 = s0
	q.s1 = s1
	q.col = col
	q.rot = rot
	q.spin = spin
	q.g = g
	q.lx = lx
	q.delay = delay


func step(dt: float) -> void:
	for q in parts:
		if not q.on:
			continue
		if q.delay > 0.0:
			q.delay -= dt
			continue
		q.age += dt
		if q.age >= q.life:
			q.on = false
			continue
		q.v.y += q.g * dt
		q.p += q.v * dt
		q.rot += q.spin * dt
	for i in range(texts.size() - 1, -1, -1):
		var t: Dictionary = texts[i]
		t.age += dt
		if t.age >= t.life:
			texts.remove_at(i)   # 많아야 열몇 개라 괜찮다
	shake *= exp(-dt * 9.0)


func draw(ci: CanvasItem) -> void:
	for q in parts:
		if not q.on or q.delay > 0.0:
			continue
		var t: float = q.age / q.life
		var s: float = lerpf(q.s0, q.s1, G2.out_cubic(t))
		var c: Color = q.col
		c.a *= pow(1.0 - t, 1.3)
		ci.draw_set_transform(q.p, q.rot, Vector2(q.lx if q.lx > 0.0 else s, s))
		ci.draw_texture_rect(q.tex, Rect2(-0.5, -0.5, 1, 1), false, c)
	ci.draw_set_transform(Vector2.ZERO)


func draw_texts(ci: CanvasItem) -> void:
	for t in texts:
		var k: float = t.age / t.life
		var pop := G2.out_back(minf(1.0, k * 5.0))
		var p: Vector2 = t.p - Vector2(0, t.rise * G2.out_cubic(k))
		var c: Color = t.col
		c.a = 1.0 - smoothstep(0.6, 1.0, k)
		G2.text_mid(ci, p, t.s, t.size * pop, c, t.size * 0.22, P.a(P.INK, c.a))


func shake_add(v: float) -> void:
	shake = maxf(shake, v)

# ==================== 상황별 조합 ====================

## 블록 하나가 터짐. power 는 연쇄 · 콤보가 쌓일수록 커진다(1 = 기본).
func pop(p: Vector2, col: Color, cs: float, power: float = 1.0) -> void:
	var light := col.lightened(0.35)
	_push("fx_glow", p, Vector2.ZERO, 0.28, cs * 0.8, cs * 2.0 * power, light)
	_push("fx_ring", p, Vector2.ZERO, 0.3, cs * 0.4, cs * 1.5 * power, P.a(light, 0.8))
	for k in D.SHARDS:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * cs * randf_range(2.5, 6.0) * power
		_push("fx_shard", p, v, randf_range(0.4, 0.6), cs * 0.36, cs * 0.1, col,
				a + PI * 0.5, randf_range(-12, 12), cs * 16.0)
	for k in int(D.SPARKS * power):
		var a := randf() * TAU
		_push("fx_spark", p + Vector2(cos(a), sin(a)) * cs * 0.2,
				Vector2(cos(a), sin(a)) * cs * randf_range(1.5, 3.5), randf_range(0.3, 0.5),
				cs * 0.6, 0.0, Color(1, 1, 1), 0.0, randf_range(-4, 4))


## 줄 폭탄 — a 에서 b 까지 광선. 바깥은 블록 색, 심지는 흰색.
func beam(a: Vector2, b: Vector2, col: Color, cs: float) -> void:
	var mid := (a + b) * 0.5
	var ln := a.distance_to(b) + cs
	var rot := (b - a).angle()
	_push("fx_beam", mid, Vector2.ZERO, 0.4, cs * 1.3, cs * 0.2, col.lightened(0.2), rot, 0, 0, ln)
	_push("fx_beam", mid, Vector2.ZERO, 0.3, cs * 0.5, cs * 0.05, Color(1, 1, 1), rot, 0, 0, ln)
	var n := int(ln / cs)
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(1, n))
		_push("fx_spark", p, Vector2.ZERO, 0.35, cs * 1.1, 0.0, Color(1, 1, 1), 0, 3.0, 0, 0, k * 0.02)


## 범위 폭탄 — 충격파 + 폭발 + 연기.
func shock(p: Vector2, col: Color, cs: float, radius: float) -> void:
	_push("fx_ring", p, Vector2.ZERO, 0.45, cs * 0.5, radius * 2.6, Color(1, 1, 1, 0.9))
	_push("fx_burst", p, Vector2.ZERO, 0.4, cs * 1.0, radius * 2.4, col.lightened(0.3), randf() * TAU, 1.5)
	_push("fx_glow", p, Vector2.ZERO, 0.3, cs, radius * 3.0, Color(1, 0.95, 0.8))
	for k in 7:
		var a := TAU * k / 7.0 + randf() * 0.4
		_push("fx_smoke", p, Vector2(cos(a), sin(a)) * cs * 1.6, 0.9, cs * 0.9, cs * 1.8,
				P.a(col.lightened(0.5), 0.35), randf() * TAU, randf_range(-1, 1))
	shake_add(D.SHAKE_AREA)


## 무지개 — 가운데에서 그 색 블록마다 광선을 차례로 잇는다.
func links(from: Vector2, targets: Array, col: Color, cs: float) -> void:
	_push("fx_burst", from, Vector2.ZERO, 0.6, cs, cs * 4.0, Color(1, 1, 1), 0, 2.0)
	for k in targets.size():
		var to: Vector2 = targets[k]
		var d := k * 0.03
		_push("fx_beam", (from + to) * 0.5, Vector2.ZERO, 0.3, cs * 0.6, cs * 0.1, col.lightened(0.3),
				(to - from).angle(), 0, 0, from.distance_to(to), d)
		_push("fx_star", to, Vector2.ZERO, 0.4, cs * 1.2, 0.0, Color(1, 1, 1), 0, 4.0, 0, 0, d)
	shake_add(D.SHAKE_RAINBOW)


## 특수 블록이 생김 — 주변 블록 자리에서 빛 꼬리가 빨려 들어간다.
func merge(to: Vector2, froms: Array, col: Color, cs: float) -> void:
	for f in froms:
		var from: Vector2 = f
		if from.distance_to(to) < 1.0:
			continue
		var t := 0.16
		_push("fx_spark", from, (to - from) / t, t, cs * 0.9, cs * 0.5, col.lightened(0.4), 0, 6.0)
	_push("fx_star", to, Vector2.ZERO, 0.5, cs * 0.3, cs * 2.2, Color(1, 1, 1), 0, 2.5, 0, 0, 0.14)
	_push("fx_ring", to, Vector2.ZERO, 0.4, cs * 0.3, cs * 2.0, col.lightened(0.4), 0, 0, 0, 0, 0.14)


## 특수 블록이 가만히 있을 때 가끔 반짝.
func twinkle(p: Vector2, cs: float) -> void:
	var o := Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)) * cs
	_push("fx_spark", p + o, Vector2.ZERO, 0.45, cs * 0.6, 0.0, Color(1, 1, 1, 0.9), 0, 3.0)


## 색종이 — 피버 진입 · 결과 화면.
func confetti(vs: Vector2, n: int) -> void:
	for k in n:
		var p := Vector2(randf() * vs.x, -randf() * vs.y * 0.3)
		var v := Vector2(randf_range(-40, 40), randf_range(120, 300))
		var tex := "fx_star" if randf() < 0.4 else "fx_shard"
		_push(tex, p, v, randf_range(2.0, 3.2), randf_range(14, 26), randf_range(10, 20),
				P.RAINBOW[k % 6].lightened(0.2), randf() * TAU, randf_range(-6, 6), 60.0)


func text(p: Vector2, s: String, size: float, col: Color, rise: float = 70.0, life: float = 0.9) -> void:
	texts.append({"p": p, "s": s, "size": size, "col": col, "rise": rise, "life": life, "age": 0.0})


## 장애물이 깨짐 — 그 재질 색의 부스러기. big 이면 완전히 부서진 것(더 크게).
func crumbs(p: Vector2, col: Color, cs: float, big: bool = false) -> void:
	var n := 9 if big else 5
	for k in n:
		var a := randf() * TAU
		_push("fx_shard", p + Vector2(cos(a), sin(a)) * cs * 0.2,
				Vector2(cos(a), sin(a) - 0.6) * cs * randf_range(2.0, 4.5), randf_range(0.45, 0.7),
				cs * randf_range(0.25, 0.42), cs * 0.1, col, a, randf_range(-10, 10), cs * 18.0)
	_push("fx_glow", p, Vector2.ZERO, 0.25, cs * 0.6, cs * (1.8 if big else 1.2), P.a(col.lightened(0.4), 0.8))
	if big:
		_push("fx_smoke", p, Vector2(0, -cs * 0.8), 0.7, cs * 0.6, cs * 1.4, P.a(col.lightened(0.5), 0.35))


## 날개 젤리가 날아감 — 꼬리를 끌며 from → to. 도착은 `t` 초 뒤.
func fly(from: Vector2, to: Vector2, cs: float, t: float = 0.32) -> void:
	var v := (to - from) / t
	for k in 6:
		var d := k * 0.03
		_push("fx_spark", from, v, t - d * 0.5, cs * (1.0 - k * 0.12), cs * 0.3, Color(1, 1, 0.8), 0.0, 8.0, 0.0, 0.0, d)
	_push("fx_star", to, Vector2.ZERO, 0.45, cs * 0.4, cs * 2.0, Color(1, 1, 1), 0.0, 3.0, 0.0, 0.0, t)
	_push("fx_ring", to, Vector2.ZERO, 0.35, cs * 0.3, cs * 1.8, Color(1, 0.95, 0.7), 0.0, 0.0, 0.0, 0.0, t)


## 설탕막이 한 겹 벗겨짐.
func sugar(p: Vector2, cs: float) -> void:
	var c := D.SUGAR_C
	_push("fx_ring", p, Vector2.ZERO, 0.4, cs * 0.5, cs * 1.4, P.a(c.lightened(0.3), 0.9))
	for k in 3:
		var a := randf() * TAU
		_push("fx_spark", p, Vector2(cos(a), sin(a)) * cs * 1.5, 0.4, cs * 0.5, 0.0, c.lightened(0.5), 0.0, 4.0)


## 몬스터 행동 — 몬스터에서 대상 칸으로 기운이 날아간다.
func curse(from: Vector2, to: Vector2, col: Color, cs: float) -> void:
	_push("fx_beam", (from + to) * 0.5, Vector2.ZERO, 0.35, cs * 0.5, cs * 0.1, col, (to - from).angle(),
			0.0, 0.0, from.distance_to(to))
	_push("fx_burst", to, Vector2.ZERO, 0.4, cs * 0.4, cs * 1.6, col, randf() * TAU, 2.0)
