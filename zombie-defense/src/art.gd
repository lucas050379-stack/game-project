class_name Art
extends RefCounted

## 캐릭터·적·투사체 그림. 전부 코드로 그린다 (리소스 0개).
##
## 원만 겹쳐 놓으면 아무리 색을 달리해도 실루엣이 같아서 다 똑같아 보인다.
## 그래서 종류마다 **몸통 형태 · 팔다리 길이 · 기울기**를 다르게 잡고 걷기 위상을 준다.
##
## 대신 그리기 비용이 오르므로 두 가지 장치를 둔다.
##  1) `tier` — 프레임이 떨어지면 단계적으로 간단하게 그린다 (main.gd 의 `_pick_tier` 가 정한다)
##  2) 그림자·셀 음영은 도형을 한 번 더 그리는 방식이라 교차 연산(intersect_polygons)을 쓰지 않는다

## 빛이 오는 방향 (좌상단). 셀 음영은 이 반대쪽에 남는다.
const LIGHT := Vector2(-0.42, -0.52)

## 적 그리기 등급 — `set_tier` 로만 바꾼다.
##  0 = 전부 (팔다리를 관절에서 돌리고 그림자·눈·발광까지)
##  1 = **몸통과 머리 그림만** (팔다리·그림자 없음). 여전히 그 좀비로 보인다.
##  2 = 덩어리 두 개. 부위 그림이 하나도 없을 때의 최후 수단이다.
##
## **1단계를 건너뛰고 바로 원으로 내려가지 마세요.** 예전에는 0 아니면 2뿐이었고 그 경계가
## "화면 안 70마리"로 고정돼 있어서, 적이 몰리는 후반 라운드에서 프레임이 멀쩡한데도
## 좀비가 전부 동그라미로 보였습니다.
static var tier := 0
## `tier == 0` 과 같다. 캐릭터 함수들이 잔장식을 켤지 볼 때 쓴다.
static var detail := true


static func set_tier(n: int) -> void:
	tier = clampi(n, 0, 2)
	detail = tier == 0


## 몸통 그림을 통째로 놓을 때 쓰는 크기와 머리 위치 (r 배수). **그림 접두어로 찾는다.**
## **각 캐릭터 함수의 `_cutout_body` 인자와 같아야 한다** — 다르면 1단계에서 몸이 튄다.
const BODY := {
	"zombie":  { "torso": 1.5, "head": 0.9, "hx": 0.16, "hy": -0.72 },
	"runner":  { "torso": 1.3, "head": 0.8, "hx": 0.30, "hy": -0.76 },
	"fat":     { "torso": 1.7, "head": 0.8, "hx": 0.08, "hy": -0.68 },
	"bomber":  { "torso": 1.5, "head": 0.8, "hx": 0.10, "hy": -0.70 },
	"spitter": { "torso": 1.3, "head": 0.9, "hx": 0.22, "hy": -0.92 },
	"boss":    { "torso": 2.0, "head": 1.0, "hx": 0.06, "hy": -0.86 },
}

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
## 발밑 그림자. **`draw_circle` 한 번으로 끝낸다.**
##
## 예전에는 12각형을 만들어 `G2.fill_fan` 으로 칠했다 — 마리당 배열을 새로 할당하고
## 그리기 배칭까지 끊는다. 적이 300마리 깔리면 그림자만으로 프레임을 갉아먹는다.
## 타원이 아니라 원이 되지만 화면에서 20~50px 짜리 발밑이라 구분되지 않는다.
static func _shadow(ci: CanvasItem, at: Vector2, rx: float, ry: float, alpha: float) -> void:
	ci.draw_circle(at, (rx + ry) * 0.5, P.a(Color.BLACK, alpha))


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


## 부위별 컷아웃(`<base>_torso.png` 등)으로 캐릭터를 그린다. 몸통 그림이 없으면 그 자리에서
## false 를 돌려주고, 호출한 쪽이 지금까지의 벡터 그림으로 넘어가게 한다.
##
## 팔다리는 [Art] 의 벡터 그림이 쓰는 것과 **같은 관절 좌표**(pivot·tip)를 그대로 받아
## `Spr.limb_tex` 로 회전시켜 그린다 — 그래서 실루엣·비례가 벡터 버전과 어긋나지 않는다.
## 순서는 벡터 그림과 동일하게 다리(뒤→앞) → 몸통 → 팔(뒤→앞) → 머리.
##
## leg_b/leg_f/arm_b/arm_f 는 [pivot, tip] 2칸 배열이거나, 그 부위가 없으면 빈 배열.
##
## **몸통 그림(`_torso`)에 팔이 같이 그려져 있으면 안 된다** — 여기서 팔 조각을 따로
## 얹으므로 팔이 두 벌 겹쳐 보인다. 이미지 AI 가 "torso only" 를 자주 무시하므로,
## 받은 그림에 팔이 붙어 있으면 `art/source/dearm.ps1` 로 지우고 쓴다.
##
## **관절 좌표는 벡터 그림 것을 그대로 쓰면 안 된다.** 벡터 몸통은 폭이 `r` 안팎으로 좁은데
## 그림 몸통은 훨씬 넓어서(비대 좀비 1.8r, 보스 1.9r), 같은 좌표를 넘기면 팔다리가 어깨·엉덩이가
## 아니라 **배 한가운데에서 자란 것처럼** 보인다. 캐릭터마다 `_cutout_body` 호출 바로 위에서
## 그림 폭에 맞춘 어깨(`shb`/`shf`)와 엉덩이 간격을 따로 잡는다.
static func _cutout_body(ci: CanvasItem, base: String, face: float, flash: float,
		torso_at: Vector2, torso_h: float, head_at: Vector2, head_h: float,
		leg_b: Array, leg_f: Array, arm_b: Array, arm_f: Array) -> bool:
	var torso_tex := Spr.get_tex(base + "_torso")
	if torso_tex == null:
		return false
	if leg_b.size() == 2:
		Spr.limb_tex(ci, Spr.get_tex(base + "_leg_b"), leg_b[0], leg_b[1], face, flash)
	if leg_f.size() == 2:
		Spr.limb_tex(ci, Spr.get_tex(base + "_leg_f"), leg_f[0], leg_f[1], face, flash)
	Spr.blit(ci, torso_tex, torso_at, torso_h, face, flash)
	if arm_b.size() == 2:
		Spr.limb_tex(ci, Spr.get_tex(base + "_arm_b"), arm_b[0], arm_b[1], face, flash)
	if arm_f.size() == 2:
		Spr.limb_tex(ci, Spr.get_tex(base + "_arm_f"), arm_f[0], arm_f[1], face, flash)
	var head_tex := Spr.get_tex(base + "_head")
	if head_tex != null:
		Spr.blit(ci, head_tex, head_at, head_h, face, flash)
	return true

# ==================== 바닥 ====================

## 맵 바닥과 경계벽. `m` 은 [D].MAP 의 한 줄이다.
##
## **맵 밖은 맵 안과 다른 색으로 칠하고 무늬를 안 그린다.** 예전에는 화면 전체를 같은
## 바닥색으로 칠하고 격자도 화면 전체에 깔아서, 맵 끝에 서 있어도 그게 끝인지 알 수 없었다.
## 색이 갈리고 무늬가 끊기는 것만으로 경계가 읽히고, 그 위에 벽을 얹어 확실히 못 박는다.
static func ground(ci: CanvasItem, view: Rect2, m: Dictionary, t: float) -> void:
	var size: Vector2 = m["size"]
	var void_col: Color = m["void"]
	var ground_col: Color = m["ground"]
	var accent: Color = m["accent"]
	var arena := Rect2(Vector2.ZERO, size)
	ci.draw_rect(view, void_col)

	var inner := view.intersection(arena)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	ci.draw_rect(inner, ground_col)
	_pattern(ci, inner, m)
	_wall(ci, arena, view, accent, t)


## 맵마다 다른 바닥 무늬. 색만 바꾸면 세 맵이 같은 곳으로 보인다.
static func _pattern(ci: CanvasItem, r: Rect2, m: Dictionary) -> void:
	var step := float(m["step"])
	var grid_col: Color = m["grid"]
	var accent: Color = m["accent"]
	var col := P.a(grid_col, 0.55)
	match String(m["style"]):
		"dune":
			# 가로로 흐르는 모래 결 — 세로선이 없어 탁 트여 보인다
			var y := floorf(r.position.y / step) * step
			while y < r.end.y:
				var x := r.position.x
				var prev := Vector2(x, y + sin(x * 0.008) * 9.0)
				while x < r.end.x:
					x += 60.0
					var cur := Vector2(minf(x, r.end.x), y + sin(x * 0.008) * 9.0)
					ci.draw_line(prev, cur, col, 1.6)
					prev = cur
				y += step
		"lab":
			# 촘촘한 격자 + 교차점 십자 표식
			_grid(ci, r, step, P.a(grid_col, 0.40))
			var cross := P.a(accent, 0.22)
			var gx := ceilf(r.position.x / (step * 4.0)) * step * 4.0
			while gx < r.end.x:
				var gy := ceilf(r.position.y / (step * 4.0)) * step * 4.0
				while gy < r.end.y:
					ci.draw_line(Vector2(gx - 7, gy), Vector2(gx + 7, gy), cross, 1.6)
					ci.draw_line(Vector2(gx, gy - 7), Vector2(gx, gy + 7), cross, 1.6)
					gy += step * 4.0
				gx += step * 4.0
		_:
			_grid(ci, r, step, col)


static func _grid(ci: CanvasItem, r: Rect2, step: float, col: Color) -> void:
	var x := ceilf(r.position.x / step) * step
	while x < r.end.x:
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), col, 1.0)
		x += step
	var y := ceilf(r.position.y / step) * step
	while y < r.end.y:
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col, 1.0)
		y += step


## 경계벽 — 굵은 발광선 + 안쪽 보조선 + 빗금 + 모서리 꺾쇠.
## 빗금과 꺾쇠까지 있어야 "화면 밖으로 이어지는 바닥"이 아니라 "막힌 벽"으로 읽힌다.
## 화면에 걸치는 구간만 그린다 — 맵이 4400px 이라 전체를 훑으면 프레임이 아깝다.
static func _wall(ci: CanvasItem, arena: Rect2, view: Rect2, accent: Color, t: float) -> void:
	var pulse := 1.25 + 0.25 * sin(t * 2.2)
	var hot := P.a(P.hdr(accent, pulse), 0.95)
	var soft := P.a(accent, 0.35)
	var corners := PackedVector2Array([
		arena.position, Vector2(arena.end.x, arena.position.y),
		arena.end, Vector2(arena.position.x, arena.end.y)])
	G2.stroke(ci, corners, hot, 7.0)

	# 안쪽 보조선 + 빗금
	var inset := 18.0
	var x0 := maxf(arena.position.x, view.position.x)
	var x1 := minf(arena.end.x, view.end.x)
	var y0 := maxf(arena.position.y, view.position.y)
	var y1 := minf(arena.end.y, view.end.y)
	if x1 > x0:
		for edge_y: float in [arena.position.y + inset, arena.end.y - inset]:
			if edge_y < view.position.y - 20.0 or edge_y > view.end.y + 20.0:
				continue
			ci.draw_line(Vector2(x0, edge_y), Vector2(x1, edge_y), soft, 2.0)
			var s := arena.position.y + inset == edge_y
			var hx := ceilf(x0 / 56.0) * 56.0
			while hx < x1:
				var dy := (inset - 4.0) if s else -(inset - 4.0)
				ci.draw_line(Vector2(hx, edge_y), Vector2(hx + 16.0, edge_y - dy), soft, 1.6)
				hx += 56.0
	if y1 > y0:
		for edge_x: float in [arena.position.x + inset, arena.end.x - inset]:
			if edge_x < view.position.x - 20.0 or edge_x > view.end.x + 20.0:
				continue
			ci.draw_line(Vector2(edge_x, y0), Vector2(edge_x, y1), soft, 2.0)
			var s2 := arena.position.x + inset == edge_x
			var hy := ceilf(y0 / 56.0) * 56.0
			while hy < y1:
				var dx := (inset - 4.0) if s2 else -(inset - 4.0)
				ci.draw_line(Vector2(edge_x, hy), Vector2(edge_x - dx, hy + 16.0), soft, 1.6)
				hy += 56.0

	# 모서리 꺾쇠 — 어느 구석인지 한눈에 잡힌다
	var leg := 110.0
	for c: Vector2 in corners:
		if not view.grow(leg + 20.0).has_point(c):
			continue
		var sx := 1.0 if absf(c.x - arena.position.x) < 1.0 else -1.0
		var sy := 1.0 if absf(c.y - arena.position.y) < 1.0 else -1.0
		ci.draw_line(c, c + Vector2(sx * leg, 0), hot, 11.0)
		ci.draw_line(c, c + Vector2(0, sy * leg), hot, 11.0)

# ==================== 플레이어 ====================

## ch 는 [D].CHAR 의 한 줄. 캐릭터마다 그림이 따로 없으면 `hero` 그림을 `tint` 색으로
## 물들여 구분한다 — 그림 6장을 그 접두어로 넣는 순간 자동으로 그쪽을 쓴다(`Spr.char_base`).
static func hero(ci: CanvasItem, p: Vector2, aim: Vector2, t: float, blink: bool,
		moving: bool, ch: Dictionary = {}) -> void:
	var r := D.PLAYER_R
	var line := P.LINE
	var lw := maxf(1.4, r * 0.14)
	var face: float = 1.0 if aim.x >= 0.0 else -1.0
	var walk := sin(t * 11.0) * (1.0 if moving else 0.18)
	var bob := absf(sin(t * 11.0)) * (2.2 if moving else 0.6)
	var c := p + Vector2(0, -bob)
	var base := Spr.char_base(String(ch.get("art", "hero")))
	var tint: Color = ch.get("tint", Color.WHITE)

	_shadow(ci, p + Vector2(0, r * 1.02), r * 0.72, r * 0.30, 0.36)
	G2.glow(ci, c, r * 2.8, P.mix(P.HERO, tint, 0.5), 0.18)

	var flash := 1.9 if blink else 1.0
	var hip := c + Vector2(0, r * 0.42)
	var grip := c + aim * (r * 0.42) + Vector2(0, r * 0.02)
	var muzzle := c + aim * (r * 2.05)
	var sh := aim.orthogonal() * r * 0.44
	var head := c + Vector2(face * r * 0.06, -r * 0.62)

	# art/hero_torso.png 등 부위 그림이 있으면 관절에서 회전시켜 그린다 (컷아웃).
	# 팔다리를 정지 프레임으로 갈아 끼우지 않고 매 프레임 실제로 돌리므로 걸음이 매끄럽다.
	#
	# 컷아웃 전용 관절 — 벡터 좌표를 그대로 넘겼더니 **팔다리가 아예 안 보였다.**
	# 벡터 몸통은 폭 1.4r · 높이 1.0r 인데 그림 몸통은 1.7r × 1.7r 이라, 손잡이(0.42r)도
	# 다리 끝(0.62r)도 전부 몸통 그림 안에 파묻혔던 것이다. 그림 몸통 밖으로 나오도록
	# 어깨를 벌리고(±0.40r) 총 손잡이를 앞으로(0.78r), 다리를 아래로(1.00r) 밀어낸다.
	var cgrip := c + aim * (r * 0.78) + Vector2(0, r * 0.04)
	var cmuzzle := c + aim * (r * 2.40)
	var chip_b := hip + Vector2(-r * 0.20, 0)
	var chip_f := hip + Vector2(r * 0.20, 0)
	var csh_b := c + Vector2(-face * r * 0.42, -r * 0.28)
	var csh_f := c + Vector2(face * r * 0.34, -r * 0.24)
	# 그리기 전에 색을 걸고 **끝나면 반드시 흰색으로 되돌린다** — 안 그러면 다음 프레임에
	# 그리는 적까지 이 색으로 물든다.
	Spr.tint = tint
	var used := _cutout_body(ci, base, face, flash, c, r * 1.7, head, r * 1.0,
			[chip_b, chip_b + Vector2(walk * r * 0.44 + face * r * 0.08, r * 1.00)],
			[chip_f, chip_f + Vector2(-walk * r * 0.44 + face * r * 0.08, r * 1.00)],
			[csh_b, cgrip],
			[csh_f, cgrip + aim * (r * 0.55)])
	Spr.tint = Color.WHITE
	if used:
		# 손에 든 것은 조준 방향에 맞춰 그리는 별도 소품이라 부위 그림에 넣지 않고
		# 항상 위에 겹쳐 그린다 — **직업마다 다르다**(칼 · 지팡이 · 활).
		_prop(ci, int(ch.get("cls", D.C_WARRIOR)), cgrip, aim, r, t)
		return

	# 그림이 하나도 없을 때의 벡터 그림도 캐릭터 색을 따라간다
	var navy := Color8(46, 62, 104) * tint
	var navy_d := Color8(28, 38, 68) * tint
	var skin := P.WHITE if blink else Color8(232, 206, 180)

	# 다리 — 걸을 때 앞뒤로 흔든다
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

	# 손에 든 것 — 직업마다 다르다
	_prop(ci, int(ch.get("cls", D.C_WARRIOR)), grip, aim, r, t)
	# 양팔
	_limb(ci, c + sh * 0.9 + Vector2(0, -r * 0.06), grip, r * 0.20, navy, line)
	_limb(ci, c - sh * 0.9 + Vector2(0, -r * 0.06), grip - aim * r * 0.34, r * 0.20, navy_d, line)

	# 머리
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

## 손에 든 것. **직업이 화면에서 바로 읽혀야 한다** — 색만 다른 같은 병사 셋이면
## 캐릭터를 고른 것이 아니라 색을 고른 것이 된다. 셋 다 조준 방향(`aim`)을 겨눈다.
##
## 그림은 조준 방향으로 뻗는 선 몇 개다. 화면에 하나뿐이라 `fill_fan` 을 써도 되지만
## 여기서도 굳이 `draw_line`·`draw_circle` 위주로 둔다 — 배칭이 끊길 이유가 없다.
static func _prop(ci: CanvasItem, cls: int, grip: Vector2, aim: Vector2, r: float,
		t: float) -> void:
	var n := aim.orthogonal()
	match cls:
		D.C_MAGE:
			# 지팡이 — 끝에 떠 있는 마력 구슬이 맥동한다
			var tip := grip + aim * (r * 1.95)
			ci.draw_line(grip - aim * r * 0.45, tip, Color8(96, 72, 52), r * 0.20, true)
			var pulse := 0.85 + 0.15 * sin(t * 4.4)
			G2.glow(ci, tip, r * 0.9 * pulse, P.VIOLET, 0.5)
			ci.draw_circle(tip, r * 0.26 * pulse, P.hdr(P.VIOLET, 1.9))
			ci.draw_circle(tip, r * 0.13, P.hdr(Color.WHITE, 2.0))
		D.C_ARCHER:
			# 활 — 조준 방향에 **직각**으로 선 활대 + 당겨진 시위
			var mid := grip + aim * (r * 0.55)
			var a1 := mid + n * (r * 0.95)
			var a2 := mid - n * (r * 0.95)
			var bow := PackedVector2Array()
			for i in 9:
				var u := float(i) / 8.0
				# 활대는 앞으로 휜다 — 직선으로 그리면 막대기로 보인다
				bow.append(a2.lerp(a1, u) + aim * (r * 0.42 * sin(u * PI)))
			ci.draw_polyline(bow, Color8(122, 88, 56), r * 0.17, true)
			ci.draw_line(a1, grip - aim * r * 0.25, P.a(P.WHITE, 0.75), r * 0.06, true)
			ci.draw_line(a2, grip - aim * r * 0.25, P.a(P.WHITE, 0.75), r * 0.06, true)
			ci.draw_circle(mid + aim * r * 0.42, r * 0.10, P.hdr(P.JADE, 1.7))
		_:
			# 칼 — 자루 · 날밑 · 곧은 날. 무사는 붙어서 싸우므로 날이 길다.
			var tip2 := grip + aim * (r * 2.25)
			ci.draw_line(grip - aim * r * 0.55, grip, Color8(72, 56, 44), r * 0.24, true)
			ci.draw_line(grip + n * r * 0.34, grip - n * r * 0.34, Color8(150, 122, 62),
				r * 0.16, true)
			ci.draw_line(grip + aim * r * 0.10, tip2, P.LINE, r * 0.30, true)
			ci.draw_line(grip + aim * r * 0.10, tip2, Color8(198, 212, 236), r * 0.17, true)
			ci.draw_line(grip + aim * r * 0.10, tip2 - aim * r * 0.20,
				P.a(P.hdr(Color.WHITE, 1.5), 0.6), r * 0.05, true)

# ==================== 적 ====================

## `e` 는 [World].enemies 의 한 줄. 그림은 [D].ENEMY 의 `art`(그림 접두어)와 `tint`(입힐 색)로
## 정해진다 — **같은 그림을 색만 바꿔 상위 종을 만든다.** 자세한 건 [D].ENEMY 주석 참고.
static func enemy(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var kind: int = e["k"]
	var r: float = e["r"]
	var face: float = e["face"]
	var hit: float = e["hit"]
	var flash := 1.0 + minf(1.0, hit) * 1.6
	var row: Dictionary = D.ENEMY[kind]
	var art: String = row["art"]

	# **보스의 예비 동작은 그리기 등급과 무관하게 항상 그린다.** 피할 수 있어야 하는 것은
	# 프레임이 떨어졌다고 안 보여도 되는 정보가 아니다. 적 그림보다 **먼저** 그려 바닥에 깔린다.
	if float(e.get("cast", 0.0)) > 0.0:
		_boss_cast(ci, e, t)

	# 프레임이 떨어지면 단계적으로 간단하게 (main.gd 의 `_pick_tier` 참고).
	# 1단계는 몸통·머리 그림만 — 팔다리를 관절에서 돌리는 값이 제일 비싸고, 그걸 빼도
	# 무엇이 다가오는지는 그대로 읽힌다. 그림이 없을 때만 덩어리 두 개로 내려간다.
	#
	# **판정을 준비 코드보다 먼저 한다.** 색 보간·걷기 위상·셀 선 굵기 계산은 0단계에서만
	# 쓰는데, 마리당 몇 µs 라도 700마리면 밀리초 단위가 된다(실측).
	if tier >= 1:
		var pos: Vector2 = e["p"]
		Spr.tint = row["tint"]
		var drawn := tier < 2 and _simple(ci, art, pos, r, face, flash)
		Spr.tint = Color.WHITE
		if not drawn:
			_mini(ci, pos, r, art, row["col"], row["dark"])
		_hpbar(ci, e, pos, r, art)    # 보스 체력 띠는 등급을 낮춰도 남긴다 — 필요한 정보다
		return
	var seed: float = e["seed"]
	var walk: float = e["walk"]

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

	_shadow(ci, e["p"] + Vector2(0, r * 0.98), r * 0.62, r * 0.26, 0.30)

	# 그림 접두어로 분기한다 — 상위 종은 기본형과 같은 그림·실루엣을 쓰고 색만 다르다.
	Spr.tint = row["tint"]
	match art:
		"runner": _runner(ci, c, r, face, sw, col, dark, line, lw, t, seed, flash)
		"fat": _fat(ci, c, r, face, sw, col, dark, line, lw, flash)
		"bomber": _bomber(ci, c, r, face, sw, col, dark, line, lw, t, seed, flash)
		"spitter": _spitter(ci, c, r, face, sw, col, dark, line, lw, t, seed, flash)
		"boss": _boss(ci, c, r, face, sw, col, dark, line, lw, t, seed, flash)
		_: _zombie(ci, c, r, face, sw, col, dark, line, lw, flash)
	Spr.tint = Color.WHITE

	_hpbar(ci, e, c, r, art)


## 보스가 스킬을 준비하는 동안의 경고 표시.
##
## **세 스킬이 서로 다른 모양이어야 한다.** 같은 붉은 고리로 다 표시하면 "뭔가 온다"까지만
## 알 뿐 어디로 피해야 하는지를 모른다 — 그러면 예비 동작을 두는 의미가 없다.
##
##   돌진   플레이어 쪽으로 뻗는 **띠**   → 띠 밖으로 옆걸음
##   강타   발밑에서 차오르는 **원**      → 원 밖으로 달리기
##   산탄   앞으로 벌어지는 **부채꼴**    → 뒤로 빠지거나 막기
##
## 차오르는 정도(`u`)로 남은 시간을 보여 준다. 다 차면 그 순간 나간다.
static func _boss_cast(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var c: Vector2 = e["p"]
	var mx: float = maxf(0.001, float(e.get("cast_max", 0.6)))
	var u: float = clampf(1.0 - float(e["cast"]) / mx, 0.0, 1.0)
	var hot := P.a(P.hdr(P.CRIMSON, 1.6), 0.30 + 0.45 * u)
	var blink := 0.55 + 0.45 * sin(t * 26.0)
	match String(e.get("skill", "")):
		"dash":
			var d: Vector2 = Vector2(e.get("dv", Vector2.RIGHT))
			# 아직 방향이 안 정해졌으면(예비 동작 중) 지금 보고 있는 쪽으로 그린다
			var face: float = float(e.get("face", 1.0))
			if d.length_squared() < 0.01:
				d = Vector2(face, 0)
			var n := d.orthogonal()
			var reach := 520.0 * u
			var hw := 34.0
			G2.fill_fan(ci, PackedVector2Array([
				c + n * hw, c + d * reach + n * hw, c + d * reach - n * hw, c - n * hw,
			]), P.a(P.hdr(P.CRIMSON, 1.3), 0.16 + 0.16 * blink))
			ci.draw_line(c, c + d * reach, P.a(P.hdr(P.CRIMSON, 1.8), 0.7 * blink), 3.0, true)
		"slam":
			ci.draw_circle(c, D.BOSS_SLAM_R * u, P.a(P.hdr(P.CRIMSON, 1.1), 0.13))
			ci.draw_arc(c, D.BOSS_SLAM_R, 0.0, TAU, 44, hot, 3.0 + 3.0 * u, true)
			ci.draw_arc(c, D.BOSS_SLAM_R * u, 0.0, TAU, 40,
				P.a(P.hdr(P.GOLD_HI, 1.6), 0.8 * blink), 3.0, true)
		"volley":
			var dv := (Vector2(e.get("dv", Vector2.RIGHT)))
			if dv.length_squared() < 0.01:
				dv = Vector2(float(e.get("face", 1.0)), 0)
			var half := D.BOSS_VOLLEY_ARC * 0.5
			var pts := PackedVector2Array([c])
			for i in 9:
				var k := -half + D.BOSS_VOLLEY_ARC * float(i) / 8.0
				pts.append(c + dv.rotated(k) * (420.0 * u))
			G2.fill_fan(ci, pts, P.a(P.hdr(P.VENOM, 1.2), 0.12 + 0.14 * blink))
			for i in D.BOSS_VOLLEY:
				var k2 := (float(i) - (D.BOSS_VOLLEY - 1) * 0.5) / maxf(1.0, D.BOSS_VOLLEY - 1)
				ci.draw_line(c, c + dv.rotated(k2 * D.BOSS_VOLLEY_ARC) * (420.0 * u),
					P.a(P.hdr(P.VENOM, 1.6), 0.45 * blink), 2.0, true)


## 체력 띠는 오래 버티는 놈에게만 붙인다 — 그림 접두어로 고르므로 상위 종도 같이 붙는다.
static func _hpbar(ci: CanvasItem, e: Dictionary, c: Vector2, r: float, art: String) -> void:
	if art != "boss" and art != "fat":
		return
	var f: float = clampf(float(e["hp"]) / maxf(1.0, float(e["hpmax"])), 0.0, 1.0)
	var w := r * 1.9
	var bar := Rect2(c.x - w * 0.5, c.y - r * 1.62, w, 5.0)
	ci.draw_rect(bar, P.a(Color.BLACK, 0.6))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)),
		P.hdr(P.CRIMSON if art == "boss" else P.ORANGE, 1.3))


## 1단계 — 몸통과 머리 그림만 놓는다. 그리기 호출이 마리당 2번뿐이라 팔다리를 돌리는
## 0단계보다 훨씬 싸다. 몸통 그림이 없으면 false 를 돌려주고 호출한 쪽이 덩어리로 내려간다.
static func _simple(ci: CanvasItem, art: String, c: Vector2, r: float, face: float,
		flash: float) -> bool:
	var torso := Spr.get_tex(art + "_torso")
	if torso == null:
		return false
	var b: Dictionary = BODY.get(art, BODY["zombie"])
	Spr.blit(ci, torso, c, r * float(b["torso"]), face, flash)
	Spr.blit(ci, Spr.get_tex(art + "_head"),
		c + Vector2(face * r * float(b["hx"]), r * float(b["hy"])),
		r * float(b["head"]), face, flash)
	return true


## 2단계 — 덩어리 두 개. 부위 그림이 하나도 없을 때만 여기까지 내려온다.
static func _mini(ci: CanvasItem, c: Vector2, r: float, art: String,
		col: Color, dark: Color) -> void:
	var wide: float = 1.05 if art == "fat" else (0.74 if art == "runner" else 0.86)
	ci.draw_circle(c + Vector2(0, r * 0.10), r * wide * 0.72, dark)
	ci.draw_circle(c + Vector2(0, -r * 0.62), r * 0.40, col)


## 표준 좀비 — 등이 굽고 팔을 앞으로 늘어뜨렸다
static func _zombie(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, flash: float) -> void:
	var hip := c + Vector2(0, r * 0.40)
	var head := c + Vector2(face * r * 0.16, -r * 0.72)
	var sy := c + Vector2(0, -r * 0.24)
	var reach := Vector2(face * r * 0.98, r * 0.10)
	# 걷기 스윙은 face 를 곱해야 방향이 맞다 — 안 곱하면 왼쪽으로 갈 때나 오른쪽으로 갈 때나
	# 다리가 화면 기준 같은 쪽으로 흔들려서 걷는 방향과 다리 움직임이 안 맞아 보인다.
	var leg_sw := face * sw * r * 0.36

	# 팔은 zombie_arm_b/arm_f.png 를 아래 벡터 그림과 **같은 관절 좌표**로 돌려 그린다.
	# 다리 길이는 벡터판(0.60r)보다 훨씬 길게(0.95r) 준다 — 몸통 그림이 꽉 찬 실루엣이라
	# 벡터의 가는 다리 길이로는 몸통 아래로 거의 안 나와서 다리가 안 보이는 것처럼 보였다.
	if _cutout_body(ci, "zombie", face, flash, c, r * 1.5, head, r * 0.9,
			[hip, hip + Vector2(leg_sw, r * 0.95)],
			[hip, hip + Vector2(-leg_sw, r * 0.95)],
			[sy, sy + reach + Vector2(0, sw * r * 0.14)],
			[sy, sy + reach * 0.86 + Vector2(0, -sw * r * 0.14 - r * 0.10)]):
		return

	_limb(ci, hip, hip + Vector2(leg_sw, r * 0.60), r * 0.20, dark, line)
	_limb(ci, hip, hip + Vector2(-leg_sw, r * 0.60), r * 0.20, col, line)

	_shaded(ci, _torso(c, [
		Vector2(0.46, -0.44), Vector2(0.58, -0.06), Vector2(0.50, 0.30), Vector2(0.0, 0.44),
	], r, r), col, dark, line, lw)

	# 앞으로 뻗은 두 팔 — 좀비다움의 핵심
	if detail:
		_limb(ci, sy, sy + reach + Vector2(0, sw * r * 0.14), r * 0.17, dark, line)
		_limb(ci, sy, sy + reach * 0.86 + Vector2(0, -sw * r * 0.14 - r * 0.10), r * 0.17, col, line)

	# 머리 — 진행 방향으로 갸웃
	_ball(ci, head, r * 0.38, col, dark)
	_eyes(ci, head, r * 0.34, face, line, 0.0)
	# 벌어진 턱
	ci.draw_line(head + Vector2(face * r * 0.06, r * 0.20),
		head + Vector2(face * r * 0.30, r * 0.24), line, r * 0.10, true)


## 질주 좀비 — 앞으로 크게 기울고 보폭이 넓다
static func _runner(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float,
		flash: float) -> void:
	var lean := face * r * 0.30
	var hip := c + Vector2(-lean * 0.4, r * 0.36)
	var torso_at := c + Vector2(lean * 0.3, 0)
	var sy := c + Vector2(lean * 0.3, -r * 0.28)
	var head := c + Vector2(lean, -r * 0.76)
	# face 를 곱해야 왼쪽/오른쪽으로 뛸 때 다리 스윙 방향이 진행 방향과 맞는다.
	var leg_sw := face * sw * r * 0.72

	# 컷아웃 전용 관절 — 그림 몸통 폭(0.62r)에 맞춰 어깨/엉덩이를 벌린다.
	# 다리 길이는 벡터판(0.62r)보다 길게(0.90r). 팔은 앞뒤로 엇갈려 흔든다.
	var csy := torso_at + Vector2(0, -r * 0.34)
	var shb := csy + Vector2(-face * r * 0.25, 0)
	var shf := csy + Vector2(face * r * 0.25, 0)
	var used := _cutout_body(ci, "runner", face, flash, torso_at, r * 1.3, head, r * 0.8,
		[hip + Vector2(-r * 0.14, 0), hip + Vector2(-r * 0.14 + leg_sw, r * 0.90)],
		[hip + Vector2(r * 0.14, 0), hip + Vector2(r * 0.14 - leg_sw, r * 0.90)],
		[shb, shb + Vector2(-face * r * 0.55, r * 0.62 - sw * r * 0.22)],
		[shf, shf + Vector2(face * r * 0.55, r * 0.62 + sw * r * 0.22)])

	if not used:
		_limb(ci, hip, hip + Vector2(leg_sw, r * 0.62), r * 0.17, dark, line)
		_limb(ci, hip, hip + Vector2(-leg_sw, r * 0.62), r * 0.17, col, line)

		_shaded(ci, _torso(torso_at, [
			Vector2(0.40, -0.50), Vector2(0.46, -0.10), Vector2(0.34, 0.30), Vector2(0.0, 0.40),
		], r, r), col, dark, line, lw)

		if detail:
			# 팔을 뒤로 젖혀 달리는 자세
			_limb(ci, sy, sy + Vector2(-face * r * 0.86, -sw * r * 0.30), r * 0.15, dark, line)
			_limb(ci, sy, sy + Vector2(face * r * 0.56, sw * r * 0.30), r * 0.15, col, line)

		_ball(ci, head, r * 0.34, col, dark)

	# 붉게 번뜩이는 눈 — 정적 그림으로는 못 담는 효과라 컷아웃이든 벡터든 항상 겹쳐 그린다.
	var glow := 1.2 + 0.5 * sin(t * 8.0 + seed)
	ci.draw_circle(head + Vector2(face * r * 0.14, -r * 0.04), r * 0.11, P.hdr(P.CRIMSON, glow))
	ci.draw_circle(head + Vector2(-face * r * 0.10, -r * 0.04), r * 0.09, P.hdr(P.CRIMSON, glow))


## 비대 좀비 — 배가 크고 다리가 짧다
static func _fat(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, flash: float) -> void:
	var hip := c + Vector2(0, r * 0.46)
	var sy := c + Vector2(0, -r * 0.32)
	var head := c + Vector2(face * r * 0.08, -r * 0.68)
	# face 를 곱해야 다리 흔들림 방향이 진행 방향과 맞는다.
	var leg_wob := face * sw * r * 0.14

	# 컷아웃 전용 관절 — 그림 몸통이 1.76r 로 아주 넓어서 어깨/엉덩이를 크게 벌려야 한다.
	# 벡터 좌표(어깨가 배 한가운데)를 그대로 쓰면 팔이 젖가슴 사이에서 나온 것처럼 보였다.
	# 비대 좀비는 다리 길이가 벡터판에서 0.40r 밖에 안 됐는데, 몸통 그림이 배가 커서 아래로
	# 훨씬 많이 내려온다 — 다리가 몸통 그림에 완전히 가려 안 보이던 게 이 캐릭터였다.
	# 컷아웃에서는 0.95r 로 크게 늘린다.
	var csy := c + Vector2(0, -r * 0.40)
	var shb := csy + Vector2(-face * r * 0.60, 0)
	var shf := csy + Vector2(face * r * 0.60, 0)
	var used := _cutout_body(ci, "fat", face, flash, c, r * 1.7, head, r * 0.8,
		[hip + Vector2(-r * 0.42, 0), hip + Vector2(-r * 0.42 + leg_wob, r * 0.95)],
		[hip + Vector2(r * 0.42, 0), hip + Vector2(r * 0.42 - leg_wob, r * 0.95)],
		[shb, shb + Vector2(-face * r * 0.12, r * 0.92 + sw * r * 0.08)],
		[shf, shf + Vector2(face * r * 0.45, r * 0.82 - sw * r * 0.08)])

	if not used:
		_limb(ci, hip + Vector2(-r * 0.26, 0), hip + Vector2(-r * 0.30 + leg_wob, r * 0.40),
			r * 0.26, dark, line)
		_limb(ci, hip + Vector2(r * 0.26, 0), hip + Vector2(r * 0.30 - leg_wob, r * 0.40),
			r * 0.26, col, line)

		_shaded(ci, _torso(c, [
			Vector2(0.40, -0.56), Vector2(0.86, -0.10), Vector2(0.84, 0.28), Vector2(0.0, 0.50),
		], r, r), col, dark, line, lw)
		# 배 갈라진 자국
		if detail:
			ci.draw_line(c + Vector2(-r * 0.30, r * 0.02), c + Vector2(r * 0.26, r * 0.16),
				P.a(P.CRIMSON_DEEP, 0.8), r * 0.09, true)

		if detail:
			_limb(ci, sy, sy + Vector2(face * r * 0.96, r * 0.30 + sw * r * 0.10), r * 0.22, dark, line)
			_limb(ci, sy, sy + Vector2(-face * r * 0.72, r * 0.34 - sw * r * 0.10), r * 0.22, col, line)

		_ball(ci, head, r * 0.28, col, dark)
		_eyes(ci, head, r * 0.24, face, line, 0.0)


## 폭탄 좀비 — 배에 코어가 빛나고 점점 부푼다
static func _bomber(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float,
		flash: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 6.0 + seed)
	var puff := 1.0 + pulse * 0.10

	var hip := c + Vector2(0, r * 0.42)
	var sy := c + Vector2(0, -r * 0.26)
	var head := c + Vector2(face * r * 0.10, -r * 0.70)
	# face 를 곱해야 다리 스윙 방향이 진행 방향과 맞는다.
	var leg_sw := face * sw * r * 0.26

	# 컷아웃 전용 관절 — 그림 몸통 폭(1.44r)에 맞춰 어깨/엉덩이를 벌린다.
	# 다리 길이는 벡터판(0.52r)보다 길게(0.95r).
	var csy := c + Vector2(0, -r * 0.36)
	var shb := csy + Vector2(-face * r * 0.50, 0)
	var shf := csy + Vector2(face * r * 0.50, 0)
	var used := _cutout_body(ci, "bomber", face, flash, c, r * 1.5 * puff, head, r * 0.8,
		[hip + Vector2(-r * 0.28, 0), hip + Vector2(-r * 0.28 + leg_sw, r * 0.95)],
		[hip + Vector2(r * 0.28, 0), hip + Vector2(r * 0.28 - leg_sw, r * 0.95)],
		[shb, shb + Vector2(-face * r * 0.10, r * 0.86 + sw * r * 0.08)],
		[shf, shf + Vector2(face * r * 0.40, r * 0.80 - sw * r * 0.08)])

	if not used:
		_limb(ci, hip, hip + Vector2(leg_sw, r * 0.52), r * 0.19, dark, line)
		_limb(ci, hip, hip + Vector2(-leg_sw, r * 0.52), r * 0.19, col, line)

		_shaded(ci, _torso(c, [
			Vector2(0.38, -0.46), Vector2(0.66, 0.00), Vector2(0.56, 0.30), Vector2(0.0, 0.44),
		], r * puff, r), col, dark, line, lw)

		if detail:
			_limb(ci, sy, sy + Vector2(face * r * 0.70, r * 0.16), r * 0.15, dark, line)
			_limb(ci, sy, sy + Vector2(-face * r * 0.52, r * 0.20), r * 0.15, col, line)

		_ball(ci, head, r * 0.30, col, dark)
		_eyes(ci, head, r * 0.24, face, line, 0.0)

	# 코어 — 부풀며 빛나는 효과라 정적 그림에 못 담는다. 컷아웃 배 위에도 그대로 겹쳐 그린다.
	G2.glow(ci, c + Vector2(0, r * 0.02), r * (1.1 + pulse * 0.4), P.ORANGE, 0.22 + pulse * 0.24)
	ci.draw_circle(c + Vector2(0, r * 0.02), r * 0.26, P.hdr(P.ORANGE, 1.2 + pulse * 0.8))
	ci.draw_circle(c + Vector2(0, r * 0.02), r * 0.13, P.hdr(P.GOLD_HI, 1.6 + pulse))


## 침 뱉는 좀비 — 목이 길고 입이 부풀어 있다
static func _spitter(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float,
		flash: float) -> void:
	var hip := c + Vector2(0, r * 0.40)
	var sy := c + Vector2(0, -r * 0.24)
	var head := c + Vector2(face * r * 0.22, -r * 0.92)
	# face 를 곱해야 다리 스윙 방향이 진행 방향과 맞는다.
	var leg_sw := face * sw * r * 0.30

	# 컷아웃 전용 관절 — 그림 몸통 폭(0.83r)에 맞춰 어깨/엉덩이를 벌린다.
	# 다리 길이는 벡터판(0.60r)보다 길게(0.85r). 두 팔 모두 앞으로 뻗는다.
	var csy := c + Vector2(0, -r * 0.34)
	var shb := csy + Vector2(-face * r * 0.30, 0)
	var shf := csy + Vector2(face * r * 0.30, 0)
	var used := _cutout_body(ci, "spitter", face, flash, c, r * 1.3, head, r * 0.9,
		[hip + Vector2(-r * 0.16, 0), hip + Vector2(-r * 0.16 + leg_sw, r * 0.85)],
		[hip + Vector2(r * 0.16, 0), hip + Vector2(r * 0.16 - leg_sw, r * 0.85)],
		[shb, shb + Vector2(face * r * 0.52, r * 0.66 + sw * r * 0.10)],
		[shf, shf + Vector2(face * r * 0.66, r * 0.56 - sw * r * 0.10)])

	if used:
		# 목 — 걷기 위상과 무관한 고정 연결부라 부위로 안 나누고 항상 이 선으로 잇는다.
		_limb(ci, c + Vector2(0, -r * 0.34), head, r * 0.20, dark, line)
	else:
		_limb(ci, hip, hip + Vector2(leg_sw, r * 0.60), r * 0.18, dark, line)
		_limb(ci, hip, hip + Vector2(-leg_sw, r * 0.60), r * 0.18, col, line)

		_shaded(ci, _torso(c, [
			Vector2(0.34, -0.40), Vector2(0.48, 0.00), Vector2(0.42, 0.30), Vector2(0.0, 0.42),
		], r, r), col, dark, line, lw)

		# 목
		_limb(ci, c + Vector2(0, -r * 0.34), head, r * 0.20, dark, line)

		if detail:
			_limb(ci, sy, sy + Vector2(face * r * 0.60, r * 0.32), r * 0.14, dark, line)
			_limb(ci, sy, sy + Vector2(-face * r * 0.60, r * 0.32), r * 0.14, col, line)

		_ball(ci, head, r * 0.34, col, dark)
		_eyes(ci, head, r * 0.28, face, line, 0.0)

	# 부푼 목주머니 — 맥동 효과라 정적 그림에 못 담는다. 항상 겹쳐 그린다.
	var sac := 0.5 + 0.5 * sin(t * 3.4 + seed)
	ci.draw_circle(head + Vector2(face * r * 0.22, r * 0.16), r * (0.16 + sac * 0.10),
		P.a(P.hdr(P.JADE, 1.3), 0.9))


## 보스 변이체 — 거대하고 비대칭, 한쪽 팔이 크다
static func _boss(ci: CanvasItem, c: Vector2, r: float, face: float, sw: float,
		col: Color, dark: Color, line: Color, lw: float, t: float, seed: float,
		flash: float) -> void:
	# 은은한 붉은 아지랑이 — 맥동 효과라 정적 그림에 못 담는다. 항상 맨 먼저(가장 뒤에) 그린다.
	G2.glow(ci, c, r * 2.2, P.CRIMSON, 0.30 + 0.10 * sin(t * 3.0 + seed))

	var hip := c + Vector2(0, r * 0.34)
	var sy := c + Vector2(0, -r * 0.44)
	var head := c + Vector2(face * r * 0.06, -r * 0.86)
	# face 를 곱해야 다리 스윙 방향이 진행 방향과 맞는다.
	var leg_sw := face * sw * r * 0.20

	# 컷아웃 전용 관절 — 그림 몸통이 1.86r 로 아주 넓다. 벡터 좌표(엉덩이 간격 0.24r)를
	# 그대로 쓰면 다리 두 개가 갈비뼈 한가운데에 뼈다귀처럼 붙어 보였다.
	# **앞쪽 팔(arm_f)을 훨씬 길게 뻗어** 벡터판의 비대칭 실루엣을 살린다 — 길이에 맞춰
	# 그림도 같이 굵어지므로 별도의 큰 팔 그림 없이 한쪽만 우람해진다.
	# 보스는 몸통을 r*2.0 으로 크게 그리는데 다리 길이는 벡터판 그대로 0.66r 이라 몸통 아래로
	# 거의 안 나왔다 — fat 과 같은 증상. 컷아웃에서는 1.25r 로 크게 늘린다.
	var csy := c + Vector2(0, -r * 0.56)
	var shb := csy + Vector2(-face * r * 0.68, 0)
	var shf := csy + Vector2(face * r * 0.68, 0)
	var used := _cutout_body(ci, "boss", face, flash, c, r * 2.0, head, r * 1.0,
		[hip + Vector2(-r * 0.45, 0), hip + Vector2(-r * 0.45 + leg_sw, r * 1.25)],
		[hip + Vector2(r * 0.45, 0), hip + Vector2(r * 0.45 - leg_sw, r * 1.25)],
		[shb, shb + Vector2(face * r * 0.42, r * 0.80 + sw * r * 0.12)],
		[shf, shf + Vector2(face * r * 1.15, r * 0.70 - sw * r * 0.12)])

	if used:
		return

	_limb(ci, hip + Vector2(-r * 0.24, 0), hip + Vector2(-r * 0.34 + leg_sw, r * 0.66),
		r * 0.30, dark, line)
	_limb(ci, hip + Vector2(r * 0.24, 0), hip + Vector2(r * 0.34 - leg_sw, r * 0.66),
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
	_limb(ci, sy, sy + Vector2(face * r * 1.30, r * 0.42 + sw * r * 0.16), r * 0.34, dark, line)
	ci.draw_circle(sy + Vector2(face * r * 1.30, r * 0.42 + sw * r * 0.16), r * 0.26, dark)
	if detail:
		_limb(ci, sy, sy + Vector2(-face * r * 0.80, r * 0.50 - sw * r * 0.16), r * 0.20, col, line)

	# 머리 + 뿔
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
		"arrow", "intercept":
			# 화살 — 진행 방향으로 늘어난 자국 + 화살대 + 화살촉. 점으로 그리면
			# 초속 1000px 에서 프레임 사이를 건너뛰어 아예 안 보인다.
			var d0: Vector2 = b["v"].normalized()
			var n0 := d0.orthogonal()
			ci.draw_line(p - d0 * r * 5.0, p + d0 * r * 1.2, P.a(col, 0.32), r * 0.8, true)
			ci.draw_line(p - d0 * r * 3.0, p + d0 * r * 0.6, P.hdr(col, 1.7), r * 0.42, true)
			G2.fill_fan(ci, PackedVector2Array([
				p + d0 * r * 1.7, p + n0 * r * 0.62 - d0 * r * 0.2,
				p - n0 * r * 0.62 - d0 * r * 0.2,
			]), P.hdr(Color.WHITE, 1.5))
			# 오늬 — 뒤쪽 깃
			ci.draw_line(p - d0 * r * 2.4 + n0 * r * 0.5, p - d0 * r * 3.2 - n0 * r * 0.5,
				P.a(P.hdr(col, 1.3), 0.7), r * 0.3, true)
		"homing":
			# 유도 화살 — 자국이 길고 촉이 옥색이다. 폭발하지 않으므로 화염구와 헷갈리면 안 된다.
			var dh: Vector2 = b["v"].normalized()
			var nh := dh.orthogonal()
			ci.draw_line(p - dh * r * 3.4, p - dh * r * 0.4,
				P.a(P.hdr(col, 1.5), 0.45), r * 0.9, true)
			ci.draw_line(p - dh * r * 1.6, p + dh * r * 0.8, P.hdr(col, 1.6), r * 0.5, true)
			G2.fill_fan(ci, PackedVector2Array([
				p + dh * r * 1.6, p + nh * r * 0.58, p - nh * r * 0.58,
			]), P.hdr(Color.WHITE, 1.6))
		"fireball":
			# 불덩이 — 맞으면 터진다. **둥글고 크게** 그려서 화살류와 실루엣이 안 겹치게 한다.
			var pulse0 := 0.85 + 0.15 * sin(t * 18.0)
			var df: Vector2 = b["v"].normalized()
			ci.draw_line(p - df * r * 3.2, p - df * r * 0.4, P.a(P.hdr(P.ORANGE, 1.4), 0.42),
				r * 1.3, true)
			ci.draw_circle(p, r * 1.15 * pulse0, P.a(P.hdr(P.CRIMSON, 1.2), 0.55))
			ci.draw_circle(p, r * 0.80 * pulse0, P.hdr(P.ORANGE, 1.7))
			ci.draw_circle(p - df * r * 0.14, r * 0.40, P.hdr(P.GOLD_HI, 2.0))
		"axe":
			# 던진 도끼 — 실제로 돈다. 돌아오는 길에도 같은 그림이라 "되돌아온다"가 읽힌다.
			var sp := float(b.get("spin", 0.0)) + t * 17.0
			var ax := Vector2(cos(sp), sin(sp))
			var ay := ax.orthogonal()
			ci.draw_line(p - ax * r * 0.9, p + ax * r * 0.9, Color8(96, 74, 52), r * 0.26, true)
			for s: float in [-1.0, 1.0]:
				# 날 — 자루 양 끝에 붙은 부채꼴
				var base := p + ax * (r * 0.72 * s)
				G2.fill_fan(ci, PackedVector2Array([
					base - ay * r * 0.62, base + ax * (r * 0.52 * s) - ay * r * 0.30,
					base + ax * (r * 0.52 * s) + ay * r * 0.30, base + ay * r * 0.62,
				]), P.hdr(col, 1.25))
			ci.draw_circle(p, r * 0.22, P.LINE)
		"spit":
			# **적이 쏜 탄은 아군 탄 사이에서 한눈에 잡혀야 한다.** 예전에는 붉은 방울
			# 하나(`fill_fan` + 흰 점)였는데, 화면에는 이미 붉은 티어 적·피격 알갱이·
			# 데미지 숫자가 깔려 있어서 통째로 묻혔다. 색을 바꾸는 것만으로는 부족하다 —
			# **형태와 움직임**을 다른 어떤 탄과도 다르게 준다:
			#  ① 검은 테두리 — 밝은 사막 바닥에서도 윤곽이 남는다
			#  ② 맥동하는 경고 고리 — 크기가 변하는 탄은 이것뿐이라 눈이 먼저 잡는다
			#  ③ 뒤로 늘어지는 자국 — 어디서 날아오는지 읽힌다
			# 그리기는 `draw_circle` 위주다(`fill_fan` 은 배칭을 끊는다). 화면에 도는
			# 침은 많아야 수십 개라 마리당 5번은 예산 안이다.
			var d2: Vector2 = b["v"].normalized()
			var pulse := 0.65 + 0.35 * sin(t * 12.0 + float(b["life"]) * 7.0)
			ci.draw_line(p - d2 * r * 3.6, p - d2 * r * 0.5, P.a(col, 0.26), r * 1.5, true)
			ci.draw_arc(p, r * (1.9 + 0.5 * pulse), 0.0, TAU, 16,
				P.a(P.hdr(col, 1.6), 0.30 + 0.35 * pulse), 2.6, true)
			ci.draw_circle(p, r * 1.34, P.a(P.LINE, 0.92))
			ci.draw_circle(p, r * 1.06, P.hdr(col, 1.55))
			ci.draw_circle(p + d2 * r * 0.22, r * 0.42, P.hdr(Color.WHITE, 1.8))
		_:
			# 드론 탄 — 캡슐형
			var d3: Vector2 = b["v"].normalized()
			ci.draw_line(p - d3 * r * 1.4, p + d3 * r * 0.8, P.a(col, 0.30), r * 2.2, true)
			ci.draw_line(p - d3 * r * 1.0, p + d3 * r * 0.7, P.hdr(col, 1.7), r * 1.1, true)


## 경험치 젬 — **그리기 호출 딱 한 번.**
##
## 젬은 화면에 수십에서 백 개 넘게 깔린다. 예전에는 `G2.glow`(텍스처 한 장) + `gem.png`
## (텍스처 한 장)로 마리당 두 번씩 그렸는데, 젬만으로 프레임을 갉아먹었다.
## 지금은 `draw_circle` 하나다 —
##  - `draw_circle` 은 배칭이 되므로 개수가 늘어도 그리기 명령이 안 쪼개진다
##    (`fill_fan` 은 호출마다 명령이 따로 생겨서 안 된다)
##  - 발광은 색을 1.0 위로 올려(`P.hdr`) 엔진 블룸에 맡긴다. 후광을 따로 그릴 필요가 없다
##
## **여기에 겹을 더하지 마세요.** 하이라이트 한 점만 얹어도 그리기 호출이 두 배가 된다.
## 어떤 적이 떨궜는지는 색과 크기로만 구분한다 — 같은 초록 알갱이만 굴러다니면
## 뭘 주워야 이득인지 화면만 보고는 알 수 없다.
static func gem(ci: CanvasItem, gm: Dictionary, t: float) -> void:
	var kind: int = int(gm.get("k", D.S_ZOMBIE))
	var col: Color = D.ENEMY[kind]["col"] if kind >= 0 and kind < D.ENEMY.size() else P.XP
	var xpv: int = int(gm.get("xp", 1))
	var s := 3.6 + sqrt(maxf(1.0, float(xpv))) * 1.7 + sin(t * 6.0 + float(gm["t"]) * 4.0) * 0.7
	ci.draw_circle(gm["p"], s, P.hdr(col, 2.2))


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


## 회전 사슬의 쇳덩이. 마법사가 "부유 룬 고리"로 진화시켰으면 쇳덩이가 아니라 **룬**이다 —
## 같은 궤도를 도는데 그림까지 같으면 진화한 것이 화면에서 안 보인다.
static func orb(ci: CanvasItem, at: Vector2, r: float, t: float, rune: bool = false) -> void:
	if rune:
		G2.glow(ci, at, r * 3.2, P.VIOLET, 0.30)
		ci.draw_circle(at, r * 0.86, P.a(P.hdr(P.VIOLET, 1.4), 0.55))
		ci.draw_arc(at, r * 0.86, 0.0, TAU, 14, P.hdr(P.VIOLET, 1.9), maxf(1.4, r * 0.14), true)
		# 룬 문양 — 가운데를 가로지르는 빗금 두 개
		var a := t * 2.2
		var d := Vector2(cos(a), sin(a)) * r * 0.52
		ci.draw_line(at - d, at + d, P.hdr(Color.WHITE, 1.9), maxf(1.2, r * 0.12), true)
		ci.draw_line(at - d.orthogonal() * 0.6, at + d.orthogonal() * 0.6,
			P.a(P.hdr(Color.WHITE, 1.6), 0.7), maxf(1.0, r * 0.09), true)
		return
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
		"whirl":
			# 회전 참격 — **호가 한 바퀴 돌아 닫히는** 그림. 원으로 그리면 대지 분쇄와
			# 구별이 안 되므로, 칼끝이 지나간 자리를 초승달로 남긴다.
			var u0: float = 1.0 - float(a["life"]) / float(a["max"])
			var sweep := G2.out_cubic(u0)
			var a0: float = float(a.get("ang", 0.0))
			var rings := 2 if bool(a.get("twin", false)) else 1
			for k in rings:
				var rr := r * (1.0 if k == 0 else 0.62)
				var dirn := 1.0 if k == 0 else -1.0
				ci.draw_arc(p, rr, a0, a0 + dirn * TAU * sweep, 30,
					P.a(P.hdr(P.GOLD_HI, 1.8), (1.0 - u0) * 0.9), 9.0 * (1.0 - u0) + 2.0, true)
				# 칼끝 — 지금 베고 있는 자리
				var tip := p + Vector2(cos(a0 + dirn * TAU * sweep),
					sin(a0 + dirn * TAU * sweep)) * rr
				ci.draw_circle(tip, (5.0 * (1.0 - u0) + 1.5), P.hdr(Color.WHITE, 1.8))
		"quake":
			# 대지 분쇄 — 퍼지는 고리 + 바깥으로 뻗는 균열
			var u: float = 1.0 - float(a["life"]) / float(a["max"])
			var rr2 := r * G2.out_cubic(u)
			ci.draw_arc(p, rr2, 0.0, TAU, 40,
				P.a(P.hdr(P.AZURE, 1.7), (1.0 - u) * 0.9), 8.0 * (1.0 - u) + 1.5, true)
			for i in 8:
				var ang2 := TAU * i / 8.0 + float(a["max"]) * 3.0
				var dirv := Vector2(cos(ang2), sin(ang2))
				ci.draw_line(p + dirv * rr2 * 0.55, p + dirv * rr2,
					P.a(P.hdr(P.CYAN, 1.4), (1.0 - u) * 0.55), 3.0, true)
		"guard":
			# 강철 방벽 — 육각 판. **인공물처럼** 보여야 마법 결계와 안 헷갈린다.
			var pulse := 0.72 + 0.28 * sin(t * 3.4)
			G2.glow(ci, p, r * 1.05, P.AZURE, 0.14 * pulse)
			var hex := PackedVector2Array()
			for i in 6:
				var ang := TAU * i / 6.0 + t * 0.5
				hex.append(p + Vector2(cos(ang), sin(ang)) * r)
			G2.stroke(ci, hex, P.a(P.hdr(P.AZURE, 1.5), 0.62 * pulse), 5.5)
			ci.draw_arc(p, r * 0.94, 0.0, TAU, 40, P.a(P.hdr(P.CYAN, 1.3), 0.28 * pulse), 2.0, true)
			# 판을 잇는 리벳 — 금속이라는 표시
			for i in 6:
				var ang3 := TAU * i / 6.0 + t * 0.5
				ci.draw_circle(p + Vector2(cos(ang3), sin(ang3)) * r, 3.4,
					P.a(P.hdr(P.CYAN, 1.6), 0.8 * pulse))
		"ward":
			# 반사 결계 — 도는 룬 고리 둘. 강철 방벽과 달리 **둥글고 흐른다**.
			var pw := 0.70 + 0.30 * sin(t * 2.6)
			G2.glow(ci, p, r * 1.05, P.VIOLET, 0.15 * pw)
			ci.draw_arc(p, r, 0.0, TAU, 44, P.a(P.hdr(P.VIOLET, 1.5), 0.55 * pw), 4.0, true)
			ci.draw_arc(p, r * 0.88, 0.0, TAU, 40, P.a(P.hdr(P.CYAN, 1.2), 0.26 * pw), 1.8, true)
			for i in 9:
				var ang4 := TAU * i / 9.0 + t * 0.9
				var at2 := p + Vector2(cos(ang4), sin(ang4)) * r
				# 룬 — 짧은 빗금 두 개
				var tang := Vector2(-sin(ang4), cos(ang4))
				ci.draw_line(at2 - tang * 7.0, at2 + tang * 7.0,
					P.a(P.hdr(P.VIOLET, 1.7), 0.85 * pw), 3.0, true)
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


## 광선 자국. 서리 창(옥빛)과 관통 저격(금빛)이 같은 배열을 쓰므로 **색은 줄에 담겨 온다** —
## 여기서 고정하면 저격이 냉기처럼 보인다.
static func beam(ci: CanvasItem, b: Dictionary) -> void:
	var f: float = clampf(float(b["life"]) / float(b["max"]), 0.0, 1.0)
	var w: float = float(b["w"])
	var c: Color = b.get("col", P.CYAN)
	ci.draw_line(b["a"], b["b"], P.a(P.hdr(c, 1.2), 0.28 * f), w * 2.1, true)
	ci.draw_line(b["a"], b["b"], P.a(P.hdr(c, 1.8), 0.75 * f), w, true)
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
