class_name Art
extends RefCounted

## 캐릭터·적·투사체 그림. 전부 코드로 그린다 (리소스 0개).
##
## 원만 겹쳐 놓으면 아무리 색을 달리해도 실루엣이 같아서 다 똑같아 보인다.
## 그래서 종류마다 **몸통 형태 · 팔다리 길이 · 기울기**를 다르게 잡고 걷기 위상을 준다.
##
## 대신 그리기 비용이 오르므로 두 가지 장치를 둔다.
##  1) `detail` — 화면 안 적이 많아지면 팔다리·셀 그림자를 건너뛴다 (main.gd 가 매 프레임 정한다)
##  2) 그림자·셀 음영은 도형을 한 번 더 그리는 방식이라 교차 연산(intersect_polygons)을 쓰지 않는다

## 빛이 오는 방향 (좌상단). 셀 음영은 이 반대쪽에 남는다.
const LIGHT := Vector2(-0.42, -0.52)

## 적이 많으면 꺼진다
static var detail := true

# ==================== 공통 헬퍼 ====================

## 셀 셰이딩 덩어리 — 어두운 바탕 위에 밝은 면을 살짝 올리고 외곽선을 두른다.
## Geometry2D 교차보다 훨씬 싸고, 결과도 이 화면 크기에서는 구분이 안 된다.
static func _shaded(ci: CanvasItem, pts: PackedVector2Array, col: Color, dark: Color,
		line: Color, lw: float) -> void:
	if pts.size() < 3:
		return
	G2.fill_fan(ci, pts, dark)
	if detail:
		var cen := Vector2.ZERO
		var mn := pts[0]
		var mx := pts[0]
		for p in pts:
			cen += p
			mn = mn.min(p)
			mx = mx.max(p)
		cen /= pts.size()
		# 밝은 면을 도형 크기에 비례해 밀어야 작은 적에서도 음영이 보인다.
		# 고정 픽셀로 밀면 큰 놈은 티가 안 나고 작은 놈은 밖으로 삐져나온다.
		var off := LIGHT * (mn.distance_to(mx) * 0.16)
		var lit := PackedVector2Array()
		lit.resize(pts.size())
		for i in pts.size():
			lit[i] = cen + (pts[i] - cen) * 0.76 + off
		G2.fill_fan(ci, lit, col)
	if lw > 0.0:
		G2.stroke(ci, pts, line, lw)


## 둥근 덩어리 — 어두운 원 위에 밝은 원을 빛 쪽으로 밀어 올린다.
##
## 같은 그림을 fill_fan 으로 그리면 호출마다 삼각형 배열이 따로 만들어져 배칭이 끊긴다.
## draw_circle 은 엔진이 묶어 그리므로 수백 개를 뿌려도 싸다. 실측으로 이 차이가 결정적이었다.
static func _ball(ci: CanvasItem, at: Vector2, r: float, col: Color, dark: Color) -> void:
	ci.draw_circle(at, r, dark)
	ci.draw_circle(at + LIGHT * r * 0.34, r * 0.74, col)


## 발밑 그림자 — 원이 아니라 납작한 타원이라야 바닥에 붙어 보인다
static func _shadow(ci: CanvasItem, at: Vector2, rx: float, ry: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	G2.fill_fan(ci, pts, P.a(Color.BLACK, alpha))


## 팔·다리 — 외곽선을 깐 뒤 안쪽을 채운 굵은 선
static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, line: Color) -> void:
	ci.draw_line(a, b, line, w + 2.6, true)
	ci.draw_line(a, b, col, w, true)


## 좌우 대칭 몸통 폴리곤을 만든다. prof = [(가로 반폭, 세로), ...] 를 위에서 아래로.
static func _torso(o: Vector2, prof: Array, sx: float, sy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in prof.size():
		var p: Vector2 = prof[i]
		pts.append(o + Vector2(p.x * sx, p.y * sy))
	for i in range(prof.size() - 1, -1, -1):
		var p2: Vector2 = prof[i]
		pts.append(o + Vector2(-p2.x * sx, p2.y * sy))
	return pts

# ==================== 바닥 ====================

static func ground(ci: CanvasItem, view: Rect2) -> void:
	ci.draw_rect(view, P.GROUND)
	var step := 120.0
	var x0 := floorf(view.position.x / step) * step
	var y0 := floorf(view.position.y / step) * step
	var col := P.a(P.GRID, 0.55)
	var x := x0
	while x < view.end.x:
		ci.draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), col, 1.0)
		x += step
	var y := y0
	while y < view.end.y:
		ci.draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), col, 1.0)
		y += step

	var b := Rect2(Vector2.ZERO, D.ARENA)
	G2.stroke(ci, PackedVector2Array([
		b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]),
		P.a(P.hdr(P.AZURE, 1.4), 0.55), 4.0)

# ==================== 플레이어 ====================

static func hero(ci: CanvasItem, p: Vector2, aim: Vector2, t: float, blink: bool,
		moving: bool) -> void:
	var r := D.PLAYER_R
	var line := P.LINE
	var lw := maxf(1.4, r * 0.14)
	var face: float = 1.0 if aim.x >= 0.0 else -1.0
	var walk := sin(t * 11.0) * (1.0 if moving else 0.18)
	var bob := absf(sin(t * 11.0)) * (2.2 if moving else 0.6)
	var c := p + Vector2(0, -bob)

	_shadow(ci, p + Vector2(0, r * 1.02), r * 0.72, r * 0.30, 0.36)
	G2.glow(ci, c, r * 2.8, P.HERO, 0.18)

	# art/hero.png 가 있으면 그걸 쓴다
	var htex := Spr.get_tex("hero")
	if htex != null:
		Spr.blit(ci, htex, c, r * 3.8, face, 1.9 if blink else 1.0)
		# 총구 방향만 표시해 준다 — 그림은 좌우 두 방향뿐이라 조준을 못 담는다
		ci.draw_circle(c + aim * (r * 1.5), r * 0.16, P.hdr(P.GOLD_HI, 1.7))
		return

	var navy := Color8(46, 62, 104)
	var navy_d := Color8(28, 38, 68)
	var skin := P.WHITE if blink else Color8(232, 206, 180)

	# 다리 — 걸을 때 앞뒤로 흔든다
	var hip := c + Vector2(0, r * 0.42)
	_limb(ci, hip, hip + Vector2(walk * r * 0.42 + face * r * 0.10, r * 0.62), r * 0.24, navy_d, line)
	_limb(ci, hip, hip + Vector2(-walk * r * 0.42 + face * r * 0.10, r * 0.62), r * 0.24, navy, line)

	# 몸통 — 어깨가 넓고 허리가 좁은 사다리꼴
	_shaded(ci, _torso(c, [
		Vector2(0.62, -0.30), Vector2(0.70, 0.02), Vector2(0.52, 0.46), Vector2(0.0, 0.54),
	], r, r), navy, navy_d, line, lw)
	# 가슴 장비 벨트
	if detail:
		ci.draw_line(c + Vector2(-r * 0.50, r * 0.02), c + Vector2(r * 0.50, r * 0.14),
			P.a(P.CYAN, 0.75), r * 0.13, true)

	# 총 — 양손으로 조준 방향을 겨눈다
	var grip := c + aim * (r * 0.42) + Vector2(0, r * 0.02)
	var muzzle := c + aim * (r * 2.05)
	ci.draw_line(grip, muzzle, line, r * 0.44, true)
	ci.draw_line(grip, muzzle, Color8(120, 134, 164), r * 0.26, true)
	ci.draw_line(grip - aim * r * 0.30, grip + aim * r * 0.15, Color8(72, 80, 104), r * 0.40, true)
	ci.draw_circle(muzzle, r * 0.16, P.hdr(P.GOLD_HI, 1.7))
	# 양팔
	var sh := aim.orthogonal() * r * 0.44
	_limb(ci, c + sh * 0.9 + Vector2(0, -r * 0.06), grip, r * 0.20, navy, line)
	_limb(ci, c - sh * 0.9 + Vector2(0, -r * 0.06), grip - aim * r * 0.34, r * 0.20, navy_d, line)

	# 머리
	var head := c + Vector2(face * r * 0.06, -r * 0.62)
	_ball(ci, head, r * 0.44, skin, Color8(150, 126, 106))
	# 헬멧 — 위 절반 + 앞으로 튀어나온 챙
	var helm := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		helm.append(head + Vector2(cos(a), sin(a)) * r * 0.54)
	helm.append(head + Vector2(face * r * 0.72, -r * 0.06))
	helm.append(head + Vector2(-face * r * 0.54, -r * 0.10))
	_shaded(ci, helm, P.HERO, P.HERO_DEEP, line, lw * 0.8)
	# 바이저
	ci.draw_line(head + Vector2(-r * 0.40, -r * 0.02), head + Vector2(r * 0.40, -r * 0.02),
		P.hdr(P.CYAN, 1.8), r * 0.20, true)

# ==================== 적 ====================

static func enemy(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var kind: int = e["k"]
	var row: Dictionary = D.ENEMY[kind]
	var r: float = e["r"]
	var seed: float = e["seed"]
	var face: float = e["face"]
	var walk: float = e["walk"]
	var hit: float = e["hit"]

	var col: Color = row["col"]
	var dark: Color = row["dark"]
	if hit > 0.0:
		var k := minf(1.0, hit)
		col = col.lerp(Color.WHITE, k)
		dark = dark.lerp(Color.WHITE, k * 0.7)
	var line := P.LINE
	var lw: float = maxf(1.2, r * 0.11)

	var sw := sin(walk)              # 걷기 위상
	var bob := absf(sw) * r * 0.10
	var c: Vector2 = e["p"] + Vector2(0, -bob)

	# art/ 에 그림이 있으면 그걸 쓴다 (없으면 아래 벡터로 넘어간다)
	var tex := Spr.enemy_tex(kind, walk)
	if tex != null:
		_shadow(ci, e["p"] + Vector2(0, r * 0.98), r * 0.62, r * 0.26, 0.30)
		Spr.blit(ci, tex, c, r * 3.5, face, 1.0 + minf(1.0, hit) * 1.6)
		_hpbar(ci, e, c, r, kind)
		return

	# 화면이 적으로 뒤덮이면 실루엣만 남긴다.
	# 팔다리·외곽선·눈까지 다 그리면 200마리에서 23fps 까지 떨어진다(실측).
	# 이 상황에서는 어차피 개체를 구분해 볼 수 없으므로 덩어리 두 개면 충분하다.
	if not detail:
		_mini(ci, c, r, kind, col, dark)
		return

	_shadow(ci, e["p"] + Vector2(0, r * 0.98), r * 0.62, r * 0.26, 0.30)

	match kind:
		D.E_RUNNER: _runner(ci, c, r, face, sw, col, dark, line, lw, t, seed)
		D.E_FAT: _fat(ci, c, r, face, sw, col, dark, line, lw)
		D.E_BOMBER: _bomber(ci, c, r, face, sw, col, dark, line, lw, t, seed)
		D.E_SPITTER: _spitter(ci, c, r, face, sw, col, dark, line, lw, t, seed)
		D.E_BOSS: _boss(ci, c, r, face, sw, col, dark, line, lw, t, seed)
		_: _zombie(ci, c, r, face, sw, col, dark, line, lw)

	_hpbar(ci, e, c, r, kind)


static func _hpbar(ci: CanvasItem, e: Dictionary, c: Vector2, r: float, kind: int) -> void:
	if kind != D.E_BOSS and kind != D.E_FAT:
		return
	var f: float = clampf(float(e["hp"]) / maxf(1.0, float(e["hpmax"])), 0.0, 1.0)
	var w := r * 1.9
	var bar := Rect2(c.x - w * 0.5, c.y - r * 1.62, w, 5.0)
	ci.draw_rect(bar, P.a(Color.BLACK, 0.6))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)),
		P.hdr(P.CRIMSON if kind == D.E_BOSS else P.ORANGE, 1.3))


## 밀집 시의 간이 그림 — 몸통과 머리 두 덩이뿐 (그리기 호출 2번)
static func _mini(ci: CanvasItem, c: Vector2, r: float, kind: int,
		col: Color, dark: Color) -> void:
	var wide: float = 1.05 if kind == D.E_FAT else (0.74 if kind == D.E_RUNNER else 0.86)
	ci.draw_circle(c + Vector2(0, r * 0.10), r * wide * 0.72, dark)
	ci.draw_circle(c + Vector2(0, -r * 0.62), r * 0.40, col)


## 표준 좀비 — 등이 굽고 팔을 앞으로 늘어뜨렸다
static func _zombie(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float) -> void:
	var hip := c + Vector2(0, r * 0.40)
	_limb(ci, hip, hip + Vector2(sw * r * 0.36, r * 0.60), r * 0.20, dark, line)
	_limb(ci, hip, hip + Vector2(-sw * r * 0.36, r * 0.60), r * 0.20, col, line)

	_shaded(ci, _torso(c, [
		Vector2(0.46, -0.44), Vector2(0.58, -0.06), Vector2(0.50, 0.30), Vector2(0.0, 0.44),
	], r, r), col, dark, line, lw)

	# 앞으로 뻗은 두 팔 — 좀비다움의 핵심
	if detail:
		var sy := c + Vector2(0, -r * 0.24)
		var reach := Vector2(face * r * 0.98, r * 0.10)
		_limb(ci, sy, sy + reach + Vector2(0, sw * r * 0.14), r * 0.17, dark, line)
		_limb(ci, sy, sy + reach * 0.86 + Vector2(0, -sw * r * 0.14 - r * 0.10), r * 0.17, col, line)

	# 머리 — 진행 방향으로 갸웃
	var head := c + Vector2(face * r * 0.16, -r * 0.72)
	_ball(ci, head, r * 0.38, col, dark)
	_eyes(ci, head, r * 0.34, face, line, 0.0)
	# 벌어진 턱
	ci.draw_line(head + Vector2(face * r * 0.06, r * 0.20),
		head + Vector2(face * r * 0.30, r * 0.24), line, r * 0.10, true)


## 질주 좀비 — 앞으로 크게 기울고 보폭이 넓다
static func _runner(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float) -> void:
	var lean := face * r * 0.30
	var hip := c + Vector2(-lean * 0.4, r * 0.36)
	_limb(ci, hip, hip + Vector2(sw * r * 0.72, r * 0.62), r * 0.17, dark, line)
	_limb(ci, hip, hip + Vector2(-sw * r * 0.72, r * 0.62), r * 0.17, col, line)

	_shaded(ci, _torso(c + Vector2(lean * 0.3, 0), [
		Vector2(0.40, -0.50), Vector2(0.46, -0.10), Vector2(0.34, 0.30), Vector2(0.0, 0.40),
	], r, r), col, dark, line, lw)

	if detail:
		var sy := c + Vector2(lean * 0.3, -r * 0.28)
		# 팔을 뒤로 젖혀 달리는 자세
		_limb(ci, sy, sy + Vector2(-face * r * 0.86, -sw * r * 0.30), r * 0.15, dark, line)
		_limb(ci, sy, sy + Vector2(face * r * 0.56, sw * r * 0.30), r * 0.15, col, line)

	var head := c + Vector2(lean, -r * 0.76)
	_ball(ci, head, r * 0.34, col, dark)
	# 붉게 번뜩이는 눈
	var glow := 1.2 + 0.5 * sin(t * 8.0 + seed)
	ci.draw_circle(head + Vector2(face * r * 0.14, -r * 0.04), r * 0.11, P.hdr(P.CRIMSON, glow))
	ci.draw_circle(head + Vector2(-face * r * 0.10, -r * 0.04), r * 0.09, P.hdr(P.CRIMSON, glow))


## 비대 좀비 — 배가 크고 다리가 짧다
static func _fat(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float) -> void:
	var hip := c + Vector2(0, r * 0.46)
	_limb(ci, hip + Vector2(-r * 0.26, 0), hip + Vector2(-r * 0.30 + sw * r * 0.14, r * 0.40),
		r * 0.26, dark, line)
	_limb(ci, hip + Vector2(r * 0.26, 0), hip + Vector2(r * 0.30 - sw * r * 0.14, r * 0.40),
		r * 0.26, col, line)

	_shaded(ci, _torso(c, [
		Vector2(0.40, -0.56), Vector2(0.86, -0.10), Vector2(0.84, 0.28), Vector2(0.0, 0.50),
	], r, r), col, dark, line, lw)
	# 배 갈라진 자국
	if detail:
		ci.draw_line(c + Vector2(-r * 0.30, r * 0.02), c + Vector2(r * 0.26, r * 0.16),
			P.a(P.CRIMSON_DEEP, 0.8), r * 0.09, true)

	if detail:
		var sy := c + Vector2(0, -r * 0.32)
		_limb(ci, sy, sy + Vector2(face * r * 0.96, r * 0.30 + sw * r * 0.10), r * 0.22, dark, line)
		_limb(ci, sy, sy + Vector2(-face * r * 0.72, r * 0.34 - sw * r * 0.10), r * 0.22, col, line)

	var head := c + Vector2(face * r * 0.08, -r * 0.68)
	_ball(ci, head, r * 0.28, col, dark)
	_eyes(ci, head, r * 0.24, face, line, 0.0)


## 폭탄 좀비 — 배에 코어가 빛나고 점점 부푼다
static func _bomber(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 6.0 + seed)
	var puff := 1.0 + pulse * 0.10

	var hip := c + Vector2(0, r * 0.42)
	_limb(ci, hip, hip + Vector2(sw * r * 0.26, r * 0.52), r * 0.19, dark, line)
	_limb(ci, hip, hip + Vector2(-sw * r * 0.26, r * 0.52), r * 0.19, col, line)

	_shaded(ci, _torso(c, [
		Vector2(0.38, -0.46), Vector2(0.66, 0.00), Vector2(0.56, 0.30), Vector2(0.0, 0.44),
	], r * puff, r), col, dark, line, lw)

	# 코어
	G2.glow(ci, c + Vector2(0, r * 0.02), r * (1.1 + pulse * 0.4), P.ORANGE, 0.22 + pulse * 0.24)
	ci.draw_circle(c + Vector2(0, r * 0.02), r * 0.26, P.hdr(P.ORANGE, 1.2 + pulse * 0.8))
	ci.draw_circle(c + Vector2(0, r * 0.02), r * 0.13, P.hdr(P.GOLD_HI, 1.6 + pulse))

	if detail:
		var sy := c + Vector2(0, -r * 0.26)
		_limb(ci, sy, sy + Vector2(face * r * 0.70, r * 0.16), r * 0.15, dark, line)
		_limb(ci, sy, sy + Vector2(-face * r * 0.52, r * 0.20), r * 0.15, col, line)

	var head := c + Vector2(face * r * 0.10, -r * 0.70)
	_ball(ci, head, r * 0.30, col, dark)
	_eyes(ci, head, r * 0.24, face, line, 0.0)


## 침 뱉는 좀비 — 목이 길고 입이 부풀어 있다
static func _spitter(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float) -> void:
	var hip := c + Vector2(0, r * 0.40)
	_limb(ci, hip, hip + Vector2(sw * r * 0.30, r * 0.60), r * 0.18, dark, line)
	_limb(ci, hip, hip + Vector2(-sw * r * 0.30, r * 0.60), r * 0.18, col, line)

	_shaded(ci, _torso(c, [
		Vector2(0.34, -0.40), Vector2(0.48, 0.00), Vector2(0.42, 0.30), Vector2(0.0, 0.42),
	], r, r), col, dark, line, lw)

	# 목
	var head := c + Vector2(face * r * 0.22, -r * 0.92)
	_limb(ci, c + Vector2(0, -r * 0.34), head, r * 0.20, dark, line)

	if detail:
		var sy := c + Vector2(0, -r * 0.24)
		_limb(ci, sy, sy + Vector2(face * r * 0.60, r * 0.32), r * 0.14, dark, line)
		_limb(ci, sy, sy + Vector2(-face * r * 0.60, r * 0.32), r * 0.14, col, line)

	_ball(ci, head, r * 0.34, col, dark)
	# 부푼 목주머니
	var sac := 0.5 + 0.5 * sin(t * 3.4 + seed)
	ci.draw_circle(head + Vector2(face * r * 0.22, r * 0.16), r * (0.16 + sac * 0.10),
		P.a(P.hdr(P.JADE, 1.3), 0.9))
	_eyes(ci, head, r * 0.28, face, line, 0.0)


## 보스 변이체 — 거대하고 비대칭, 한쪽 팔이 크다
static func _boss(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float) -> void:
	G2.glow(ci, c, r * 2.2, P.CRIMSON, 0.30 + 0.10 * sin(t * 3.0 + seed))

	var hip := c + Vector2(0, r * 0.34)
	_limb(ci, hip + Vector2(-r * 0.24, 0), hip + Vector2(-r * 0.34 + sw * r * 0.20, r * 0.66),
		r * 0.30, dark, line)
	_limb(ci, hip + Vector2(r * 0.24, 0), hip + Vector2(r * 0.34 - sw * r * 0.20, r * 0.66),
		r * 0.30, col, line)

	# 몸통 — 어깨가 크게 솟았다
	_shaded(ci, _torso(c, [
		Vector2(0.30, -0.72), Vector2(0.82, -0.44), Vector2(0.74, 0.04), Vector2(0.52, 0.34),
		Vector2(0.0, 0.44),
	], r, r), col, dark, line, lw)

	# 갈비뼈
	if detail:
		for i in 3:
			var y := c.y - r * 0.28 + i * r * 0.18
			ci.draw_line(Vector2(c.x - r * 0.42, y), Vector2(c.x + r * 0.42, y),
				P.a(Color8(228, 214, 226), 0.55), r * 0.06, true)

	# 비대칭 팔 — 오른쪽이 훨씬 굵고 길다
	var sy := c + Vector2(0, -r * 0.44)
	_limb(ci, sy, sy + Vector2(face * r * 1.30, r * 0.42 + sw * r * 0.16), r * 0.34, dark, line)
	ci.draw_circle(sy + Vector2(face * r * 1.30, r * 0.42 + sw * r * 0.16), r * 0.26, dark)
	if detail:
		_limb(ci, sy, sy + Vector2(-face * r * 0.80, r * 0.50 - sw * r * 0.16), r * 0.20, col, line)

	# 머리 + 뿔
	var head := c + Vector2(face * r * 0.06, -r * 0.86)
	_ball(ci, head, r * 0.34, col, dark)
	for s in [-1.0, 1.0]:
		G2.fill_fan(ci, PackedVector2Array([
			head + Vector2(s * r * 0.10, -r * 0.24),
			head + Vector2(s * r * 0.30, -r * 0.16),
			head + Vector2(s * r * 0.44, -r * 0.72),
		]), Color8(238, 228, 236))
	ci.draw_circle(head + Vector2(-r * 0.14, -r * 0.02), r * 0.10, P.hdr(P.GOLD_HI, 1.8))
	ci.draw_circle(head + Vector2(r * 0.14, -r * 0.02), r * 0.10, P.hdr(P.GOLD_HI, 1.8))


static func _eyes(ci: CanvasItem, head: Vector2, s: float, face: float, line: Color,
		lift: float) -> void:
	ci.draw_circle(head + Vector2(face * s * 0.42, -s * 0.10 + lift), s * 0.24, Color8(238, 240, 246))
	ci.draw_circle(head + Vector2(-face * s * 0.16, -s * 0.10 + lift), s * 0.22, Color8(238, 240, 246))
	ci.draw_circle(head + Vector2(face * s * 0.46, -s * 0.08 + lift), s * 0.12, line)
	ci.draw_circle(head + Vector2(-face * s * 0.12, -s * 0.08 + lift), s * 0.11, line)

# ==================== 투사체 · 수집품 ====================

static func bullet(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var kind := String(b["kind"])
	var col: Color = b["col"]
	var r: float = b["r"]
	var p: Vector2 = b["p"]
	match kind:
		"kunai":
			# 회전하는 사각 표창 — 날 네 개에 가운데 구멍
			var a: float = t * 18.0 + float(b.get("spin", 0.0))
			var pts := G2.star_pts(p, r * 0.34, r * 1.15, 4, a)
			G2.fill_fan(ci, pts, P.hdr(col, 1.5))
			G2.stroke(ci, pts, P.a(P.LINE, 0.85), maxf(1.0, r * 0.14))
			ci.draw_circle(p, r * 0.22, P.a(P.LINE, 0.9))
		"missile":
			var d: Vector2 = b["v"].normalized()
			var n := d.orthogonal()
			ci.draw_line(p - d * r * 2.6, p - d * r * 0.6,
				P.a(P.hdr(P.ORANGE, 1.7), 0.55), r * 1.2, true)
			# 몸통 + 꼬리 날개
			G2.fill_fan(ci, PackedVector2Array([
				p + d * r * 1.5, p + n * r * 0.52 - d * r * 0.4,
				p - d * r * 1.1 + n * r * 0.44, p - d * r * 1.1 - n * r * 0.44,
				p - n * r * 0.52 - d * r * 0.4,
			]), Color8(214, 224, 240))
			G2.fill_fan(ci, PackedVector2Array([
				p - d * r * 0.8 + n * r * 0.44, p - d * r * 1.5 + n * r * 1.0,
				p - d * r * 1.4 + n * r * 0.30,
			]), P.hdr(P.ORANGE, 1.2))
			G2.fill_fan(ci, PackedVector2Array([
				p - d * r * 0.8 - n * r * 0.44, p - d * r * 1.5 - n * r * 1.0,
				p - d * r * 1.4 - n * r * 0.30,
			]), P.hdr(P.ORANGE, 1.2))
		"spit":
			# 끈적한 방울 — 뒤로 꼬리가 늘어진다
			var d2: Vector2 = b["v"].normalized()
			G2.fill_fan(ci, PackedVector2Array([
				p + d2 * r * 1.1, p + d2.orthogonal() * r * 0.85,
				p - d2 * r * 2.0, p - d2.orthogonal() * r * 0.85,
			]), P.hdr(col, 1.25))
			ci.draw_circle(p + d2 * r * 0.2, r * 0.42, P.a(Color.WHITE, 0.8))
		_:
			# 드론 탄 — 캡슐형
			var d3: Vector2 = b["v"].normalized()
			ci.draw_line(p - d3 * r * 1.4, p + d3 * r * 0.8, P.a(col, 0.30), r * 2.2, true)
			ci.draw_line(p - d3 * r * 1.0, p + d3 * r * 0.7, P.hdr(col, 1.7), r * 1.1, true)


static func gem(ci: CanvasItem, gm: Dictionary, t: float) -> void:
	var s := 6.2 + sin(t * 6.0 + float(gm["t"]) * 4.0) * 0.8
	var p: Vector2 = gm["p"]
	G2.glow(ci, p, s * 3.4, P.XP, 0.30)
	var gtex := Spr.get_tex("gem")
	if gtex != null:
		Spr.blit(ci, gtex, p, s * 3.4, 1.0)
		return
	# 육각 결정 — 위아래로 뾰족하고 허리가 넓다
	var body := PackedVector2Array([
		p + Vector2(0, -s * 1.7), p + Vector2(s * 0.86, -s * 0.5),
		p + Vector2(s * 0.62, s * 0.9), p + Vector2(0, s * 1.5),
		p + Vector2(-s * 0.62, s * 0.9), p + Vector2(-s * 0.86, -s * 0.5),
	])
	# 젬은 화면에 수십 개가 깔린다. 회수가 밀리면 100개도 넘는데
	# 도형을 여러 겹 쌓으면 그것만으로 프레임이 반토막 난다(실측). 덩어리 하나 + 반짝임 하나로 끝낸다.
	G2.fill_fan(ci, body, P.hdr(P.XP, 1.35))
	ci.draw_circle(p + Vector2(-s * 0.28, -s * 0.30), s * 0.34, P.hdr(Color8(210, 255, 218), 1.6))


static func drone(ci: CanvasItem, d: Dictionary, t: float) -> void:
	var p: Vector2 = d["p"]
	var w := 10.0
	var dtex := Spr.get_tex("drone")
	if dtex != null:
		Spr.blit(ci, dtex, p, w * 3.4, 1.0)
		return
	var spin := t * 26.0
	# 프로펠러 먼저 (뒤로)
	for s in [-1.0, 1.0]:
		var at := p + Vector2(s * w * 1.25, -w * 0.42)
		ci.draw_line(at - Vector2(cos(spin), sin(spin) * 0.35) * w * 0.75,
			at + Vector2(cos(spin), sin(spin) * 0.35) * w * 0.75, P.a(P.WHITE, 0.55), 2.0, true)
		ci.draw_circle(at, w * 0.22, P.LINE)
	# 동체
	var body := PackedVector2Array([
		p + Vector2(-w * 0.9, -w * 0.34), p + Vector2(w * 0.9, -w * 0.34),
		p + Vector2(w * 0.6, w * 0.55), p + Vector2(-w * 0.6, w * 0.55),
	])
	G2.fill_fan(ci, body, Color8(38, 92, 74))
	G2.fill_fan(ci, PackedVector2Array([
		p + Vector2(-w * 0.72, -w * 0.24), p + Vector2(w * 0.34, -w * 0.24),
		p + Vector2(w * 0.20, w * 0.14), p + Vector2(-w * 0.50, w * 0.14),
	]), P.JADE)
	G2.stroke(ci, body, P.LINE, 1.8)
	ci.draw_circle(p + Vector2(0, w * 0.10), w * 0.22, P.hdr(P.CYAN, 1.8))


static func orb(ci: CanvasItem, at: Vector2, r: float, t: float) -> void:
	G2.glow(ci, at, r * 2.8, P.GOLD, 0.28)
	# 각진 쇳덩이 — 매끈한 구슬보다 사슬 끝에 달린 추처럼 보인다
	var pts := G2.star_pts(at, r * 0.72, r, 6, t * 3.2)
	G2.fill_fan(ci, pts, P.hdr(P.GOLD, 1.15))
	G2.stroke(ci, pts, P.LINE, maxf(1.2, r * 0.16))
	ci.draw_circle(at + Vector2(-r * 0.26, -r * 0.30), r * 0.24, P.a(Color.WHITE, 0.7))

# ==================== 장판 · 광선 ====================

static func area(ci: CanvasItem, a: Dictionary, t: float) -> void:
	var kind := String(a["kind"])
	var r: float = a["r"]
	var p: Vector2 = a["p"]
	match kind:
		"field":
			var u: float = 1.0 - float(a["life"]) / float(a["max"])
			ci.draw_arc(p, r * G2.out_cubic(u), 0.0, TAU, 40,
				P.a(P.hdr(P.AZURE, 1.7), (1.0 - u) * 0.9), 7.0 * (1.0 - u) + 1.5, true)
		"aegis":
			var pulse := 0.72 + 0.28 * sin(t * 3.4)
			G2.glow(ci, p, r * 1.05, P.AZURE, 0.16 * pulse)
			# 육각 방벽 — 원보다 인공물처럼 보인다
			var hex := PackedVector2Array()
			for i in 6:
				var ang := TAU * i / 6.0 + t * 0.5
				hex.append(p + Vector2(cos(ang), sin(ang)) * r)
			G2.stroke(ci, hex, P.a(P.hdr(P.AZURE, 1.5), 0.60 * pulse), 5.0)
			ci.draw_arc(p, r * 0.94, 0.0, TAU, 40, P.a(P.hdr(P.CYAN, 1.3), 0.30 * pulse), 2.0, true)
		"fire":
			var f: float = clampf(float(a["life"]) / float(a["max"]), 0.0, 1.0)
			G2.glow(ci, p, r * 1.15, P.ORANGE, 0.30 * f)
			# 불꽃 혀 — 길이가 제각각 흔들린다
			for i in 9:
				var ang := TAU * i / 9.0 + float(a["max"])
				var h := r * (0.55 + 0.45 * absf(sin(t * 4.0 + i * 1.7)))
				var base := p + Vector2(cos(ang), sin(ang)) * r * 0.62
				G2.fill_fan(ci, PackedVector2Array([
					base + Vector2(cos(ang + 1.4), sin(ang + 1.4)) * r * 0.24,
					base + Vector2(cos(ang), sin(ang)) * h * 0.55,
					base + Vector2(cos(ang - 1.4), sin(ang - 1.4)) * r * 0.24,
				]), P.a(P.hdr(P.ORANGE, 1.5), 0.40 * f))
			ci.draw_circle(p, r * 0.44, P.a(P.hdr(P.GOLD, 1.3), 0.30 * f))


static func beam(ci: CanvasItem, b: Dictionary) -> void:
	var f: float = clampf(float(b["life"]) / float(b["max"]), 0.0, 1.0)
	var w: float = float(b["w"])
	ci.draw_line(b["a"], b["b"], P.a(P.hdr(P.CYAN, 1.2), 0.28 * f), w * 2.1, true)
	ci.draw_line(b["a"], b["b"], P.a(P.hdr(P.CYAN, 1.8), 0.75 * f), w, true)
	ci.draw_line(b["a"], b["b"], P.a(P.hdr(Color.WHITE, 1.9), f), w * 0.35, true)


static func zap(ci: CanvasItem, z: Dictionary) -> void:
	var f: float = clampf(float(z["life"]) / float(z["max"]), 0.0, 1.0)
	var pts: PackedVector2Array = z["pts"]
	if pts.size() < 2:
		return
	var line := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := (b - a).orthogonal().normalized()
		line.append(a)
		for s in range(1, 4):
			var u := float(s) / 4.0
			line.append(a.lerp(b, u) + n * randf_range(-9.0, 9.0))
	line.append(pts[pts.size() - 1])
	ci.draw_polyline(line, P.a(P.hdr(P.VIOLET, 1.3), 0.35 * f), 9.0, true)
	ci.draw_polyline(line, P.a(P.hdr(Color.WHITE, 1.9), f), 3.0, true)
