class_name Mdl
extends RefCounted

## 로우폴리 도안. [MB] 로 상자와 기둥을 쌓아 메시를 굽고, 한 번 구운 것은 캐시에 둔다.
##
## ## 좌표 약속
##
## - **+Z 가 앞이다.** 유닛도 몬스터도 +Z 를 본다. `rotate_y(yaw)` 하나로 해결된다.
## - **원점은 발밑이다.** 메시는 y=0 에서 위로 자란다.
## - **색은 넣지 않는다.** 명암만 회색조로 새기고 실제 색은 `MultiMesh` 인스턴스 색이 낸다.
##   바닥([method ground])만 예외다.
##
## ## 왜 도안이 몇 개뿐인가
##
## 유닛이 310종이라 하나씩 그릴 수 없다. 그래서 **모양은 역할 3종이 정하고, 등급은
## 크기와 색이 정한다.** 5성 유닛과 1성 유닛은 같은 실루엣이되 크고 색이 다르다.

static var _cache := {}


## `_get` 은 [Object] 가 이미 쓰는 이름이라 부모 서명과 안 맞는다는 파스 오류가 난다.
static func _cached(key: String, fn: Callable) -> ArrayMesh:
	if not _cache.has(key):
		_cache[key] = fn.call()
	return _cache[key]


# ══ 바닥 ══════════════════════════════════════════════════════

## 판 전체를 메시 하나로 굽는다. 본진 + 고리 트랙 + 스토리 라인.
## **여기만 실제 색을 쓴다** — 인스턴스 색이 없는 통짜 메시라서.
static func ground() -> ArrayMesh:
	return _cached("ground", func() -> ArrayMesh:
		var mb := MB.new()
		_slab(mb, Vector3.ZERO, D.ARENA, P.GROUND, P.GROUND2)
		_slab(mb, Vector3(D.STORY_X, 0.0, D.STORY_Z), D.STORY, P.STORY, P.STORY2)
		_track(mb)
		_rim(mb, Vector3.ZERO, D.ARENA, P.GROUND2)
		_rim(mb, Vector3(D.STORY_X, 0.0, D.STORY_Z), D.STORY, P.STORY_EDGE)
		return mb.commit())


## 2×2 칸 체커로 깐 판. 격자가 없으면 유닛이 얼마나 움직였는지 눈으로 못 잰다.
static func _slab(mb: MB, at: Vector3, size: Vector2, c0: Color, c1: Color) -> void:
	var t := 2.0
	var nx := int(ceil(size.x / t))
	var nz := int(ceil(size.y / t))
	for z in nz:
		for x in nx:
			var w := minf(t, size.x - float(x) * t)
			var d := minf(t, size.y - float(z) * t)
			if w <= 0.01 or d <= 0.01:
				continue
			mb.tint = c0 if ((x + z) % 2) == 0 else c1
			var cx := at.x + float(x) * t + w * 0.5
			var cz := at.z + float(z) * t + d * 0.5
			mb.frustum(Vector3(cx, -0.6, cz), Vector2(w, d),
				Vector2(w * 0.985, d * 0.985), 0.6, 0.4, 1.0)


## 몬스터가 도는 고리. 바닥보다 한 겹 위에 띠로 얹고 모서리를 원으로 메운다.
static func _track(mb: MB) -> void:
	mb.tint = P.TRACK
	var pts := D.loop_points()
	var w := 2.6
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := b - a
		var len_ := d.length()
		if len_ < 0.01:
			continue
		var dir := d / len_
		var mid := a + dir * (len_ * 0.5)
		var sz := Vector2(len_, w) if absf(dir.x) > 0.5 else Vector2(w, len_)
		mb.frustum(Vector3(mid.x, 0.0, mid.z), sz, sz, 0.06, 0.9, 1.0)
		mb.ngon(Vector3(a.x, 0.0, a.z), w * 0.5, w * 0.5, 0.06, 8, 0.9)

	# 진행 방향 꺾쇠 — 고리가 어느 쪽으로 도는지 알려 준다
	mb.tint = P.TRACK_EDGE
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var d := b - a
		var len_ := d.length()
		var dir := d / maxf(len_, 0.001)
		var side := Vector3(-dir.z, 0.0, dir.x)
		var k := 2.0
		while k < len_ - 1.0:
			var c := a + dir * k
			for s: float in [-1.0, 1.0]:
				var tip := c + dir * 0.42
				var tail := c - dir * 0.34 + side * (0.5 * s)
				var back := c - dir * 0.06 + side * (0.5 * s)
				mb.tri(Vector3(tip.x, 0.075, tip.z), Vector3(tail.x, 0.075, tail.z),
					Vector3(back.x, 0.075, back.z), P.TRACK_EDGE)
			k += 3.0


static func _rim(mb: MB, at: Vector3, size: Vector2, col: Color) -> void:
	mb.tint = col
	var th := 0.4
	var h := 0.8
	var cx := at.x + size.x * 0.5
	var cz := at.z + size.y * 0.5
	mb.frustum(Vector3(cx, -0.6, at.z - th * 0.5), Vector2(size.x + th * 2.0, th),
		Vector2(size.x + th * 2.0, th), h, 0.85)
	mb.frustum(Vector3(cx, -0.6, at.z + size.y + th * 0.5), Vector2(size.x + th * 2.0, th),
		Vector2(size.x + th * 2.0, th), h, 0.85)
	mb.frustum(Vector3(at.x - th * 0.5, -0.6, cz), Vector2(th, size.y),
		Vector2(th, size.y), h, 0.85)
	mb.frustum(Vector3(at.x + size.x + th * 0.5, -0.6, cz), Vector2(th, size.y),
		Vector2(th, size.y), h, 0.85)


# ══ 유닛 ══════════════════════════════════════════════════════

## 역할별 몸통. 원점은 발밑, +Z 가 앞.
static func unit_body(role: int) -> ArrayMesh:
	var r := clampi(role, 0, 2)
	return _cached("unit%d" % r, func() -> ArrayMesh:
		var mb := MB.new()
		match r:
			0:
				# 물뎀 — 넓은 어깨에 앞으로 뻗은 칼. 무겁게 보여야 한다.
				mb.frustum(Vector3(0, 0.52, 0), Vector2(0.60, 0.42),
					Vector2(0.66, 0.46), 0.52, 1.0)
				mb.frustum(Vector3(0, 1.04, -0.02), Vector2(0.80, 0.44),
					Vector2(0.66, 0.36), 0.16, 0.85)
				mb.ngon(Vector3(0, 1.20, 0.02), 0.22, 0.19, 0.26, 6, 1.1)
				mb.frustum(Vector3(0.38, 0.72, 0.30), Vector2(0.11, 0.86),
					Vector2(0.07, 0.86), 0.10, 1.25)
				mb.pyramid(Vector3(0.38, 0.72, 0.76), Vector2(0.10, 0.10), 0.30, 1.35)
			1:
				# 마뎀 — 아래가 벌어진 로브. 다리가 거의 안 보이고 구슬이 떠 있다.
				mb.frustum(Vector3(0, 0.0, 0), Vector2(0.72, 0.62),
					Vector2(0.40, 0.34), 1.02, 0.9)
				mb.ngon(Vector3(0, 1.02, 0.02), 0.21, 0.17, 0.26, 6, 1.1)
				mb.pyramid(Vector3(0, 1.24, 0.0), Vector2(0.30, 0.30), 0.36, 0.8)
				mb.octa(Vector3(0.32, 1.06, 0.24), 0.14, 0.18, 1.4)
			_:
				# 스토리 — 날렵한 몸에 등 깃발. 본진에서 빼내 보낼 유닛이라 눈에 띄어야 한다.
				mb.frustum(Vector3(0, 0.50, 0), Vector2(0.44, 0.36),
					Vector2(0.48, 0.38), 0.56, 1.0)
				mb.ngon(Vector3(0, 1.06, 0.02), 0.20, 0.17, 0.26, 6, 1.1)
				mb.frustum(Vector3(0, 0.66, -0.26), Vector2(0.10, 0.10),
					Vector2(0.08, 0.08), 1.10, 0.8)
				mb.frustum(Vector3(0.02, 1.44, -0.26), Vector2(0.46, 0.06),
					Vector2(0.30, 0.05), 0.34, 1.3)
		return mb.commit())


## 다리 하나. **원점이 고관절**이고 아래로 자란다 — 원점을 중심으로 돌리면 걸음이 된다.
static func leg() -> ArrayMesh:
	return _cached("leg", func() -> ArrayMesh:
		var mb := MB.new()
		mb.frustum(Vector3(0, -0.50, 0), Vector2(0.18, 0.18), Vector2(0.22, 0.22), 0.50, 0.8)
		mb.frustum(Vector3(0, -0.59, 0.02), Vector2(0.26, 0.32), Vector2(0.20, 0.24), 0.11, 0.95)
		return mb.commit())


# ══ 몬스터 ════════════════════════════════════════════════════

static func mob_body(kind: int) -> ArrayMesh:
	var k := clampi(kind, 0, D.MOB.size() - 1)
	return _cached("mob%d" % k, func() -> ArrayMesh:
		var mb := MB.new()
		match k:
			0:
				# 해적 — 기준이 되는 실루엣
				mb.frustum(Vector3(0, 0.50, 0), Vector2(0.58, 0.42),
					Vector2(0.50, 0.36), 0.54, 1.0)
				mb.ngon(Vector3(0, 1.04, 0.02), 0.24, 0.20, 0.28, 6, 1.1)
				mb.frustum(Vector3(0, 1.30, 0.0), Vector2(0.44, 0.34),
					Vector2(0.40, 0.30), 0.07, 0.7)
			1:
				# 돌격병 — 앞으로 기운 몸에 뿔. 빠르다는 게 형태로 보인다.
				mb.frustum(Vector3(0, 0.36, -0.10), Vector2(0.42, 0.68),
					Vector2(0.34, 0.50), 0.38, 1.0)
				mb.pyramid(Vector3(0, 0.66, 0.12), Vector2(0.32, 0.46), 0.32, 1.05)
				mb.pyramid(Vector3(0, 0.60, 0.30), Vector2(0.18, 0.18), 0.44, 1.3)
			2:
				# 중갑병 — 넓고 낮게. 앞에 방패판.
				mb.frustum(Vector3(0, 0.28, 0), Vector2(0.96, 0.74),
					Vector2(0.86, 0.64), 0.58, 0.95)
				mb.frustum(Vector3(0, 0.86, -0.04), Vector2(0.58, 0.46),
					Vector2(0.44, 0.36), 0.24, 1.1)
				mb.frustum(Vector3(0, 0.16, 0.38), Vector2(1.00, 0.16),
					Vector2(0.90, 0.13), 0.86, 1.2)
			_:
				# 요괴 — 떠 있는 결정과 늘어진 촉수. 다리가 없다.
				mb.octa(Vector3(0, 1.00, 0), 0.38, 0.50, 1.15)
				mb.ngon(Vector3(0, 1.24, 0), 0.15, 0.10, 0.24, 6, 0.8)
				for i in 3:
					var ang := TAU * float(i) / 3.0 + 0.4
					mb.frustum(Vector3(cos(ang) * 0.19, 0.28, sin(ang) * 0.19),
						Vector2(0.10, 0.10), Vector2(0.15, 0.15), 0.32, 0.7)
		return mb.commit())


# ══ 탄 · 표시 ══════════════════════════════════════════════════

static func shot() -> ArrayMesh:
	return _cached("shot", func() -> ArrayMesh:
		var mb := MB.new()
		mb.octa(Vector3.ZERO, 0.14, 0.28, 1.0)
		return mb.commit())


## 고른 유닛 발밑에 깔리는 고리. 워크래프트식으로 여러 기를 고르므로
## **몇 기가 골렸는지 화면에서 바로 세어져야** 한다.
static func ring() -> ArrayMesh:
	return _cached("ring", func() -> ArrayMesh:
		var mb := MB.new()
		var seg := 16
		var r0 := 0.52
		var r1 := 0.64
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var y := 0.09
			var p0 := Vector3(cos(a0) * r0, y, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, y, sin(a1) * r0)
			var q0 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
			var q1 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
			mb.quad(p0, p1, q1, q0, MB.sh(1.3))
		return mb.commit())
