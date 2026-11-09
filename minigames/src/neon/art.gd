class_name NvArt
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

static func _shadow(ci: CanvasItem, at: Vector2, rx: float, ry: float, alpha: float) -> void:
	ci.draw_circle(at, (rx + ry) * 0.5, NvP.a(Color.BLACK, alpha))


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
	var col := NvP.a(grid_col, 0.55)
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
			_grid(ci, r, step, NvP.a(grid_col, 0.40))
			var cross := NvP.a(accent, 0.22)
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
	var hot := NvP.a(NvP.hdr(accent, pulse), 0.95)
	var soft := NvP.a(accent, 0.35)
	var corners := PackedVector2Array([
		arena.position, Vector2(arena.end.x, arena.position.y),
		arena.end, Vector2(arena.position.x, arena.end.y)])
	NvG2.stroke(ci, corners, hot, 7.0)

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

## 주인공 기체 — 네온 실루엣(재정비 8-2). 직업마다 모양: 무사 = 칼날 셋이 도는 육각 · 마법사 = 고리가 도는 원 핵 · 궁수 = 겨눈 쪽 화살촉.
## 2차에 Cloudflare 그림 + sprite-gen(cutout · breathe)이 들어오면 그림이 있을 때만 그것을 쓴다(ADR-0005).
static func hero(ci: CanvasItem, p: Vector2, aim: Vector2, t: float, blink: bool,
		moving: bool, ch: Dictionary = {}) -> void:
	var r := NvD.PLAYER_R
	var tint: Color = ch.get("tint", NvP.HERO)
	var cls := int(ch.get("cls", NvD.C_WARRIOR))
	var flash := 1.9 if blink else 1.0
	var glow := Color(tint.r * 1.8 * flash, tint.g * 1.8 * flash, tint.b * 1.8 * flash, 1.0)
	var body := Color(tint.darkened(0.78), 0.95)
	var pulse := 1.0 + (0.05 * sin(t * 12.0) if moving else 0.02 * sin(t * 3.0))
	var lw := maxf(2.0, r * 0.12)
	NvG2.glow(ci, p, r * 2.6, tint, 0.18)
	var a := aim.angle()
	var pts := PackedVector2Array()
	match cls:
		NvD.C_MAGE:
			ci.draw_circle(p, r * 0.62 * pulse, body)
			ci.draw_arc(p, r * 0.62 * pulse, 0, TAU, 28, glow, lw, true)
			ci.draw_arc(p, r * 0.95, t * 2.0, t * 2.0 + PI * 1.3, 20, Color(glow, 0.8), lw * 0.7, true)
			ci.draw_circle(p, r * 0.24, glow)
		NvD.C_ARCHER:
			for k in [Vector2(1.0, 0.0), Vector2(-0.7, 0.62), Vector2(-0.35, 0.0), Vector2(-0.7, -0.62)]:
				pts.append(p + (k as Vector2).rotated(a) * r * pulse)
		_:
			for i in 6:
				var ang := t * 0.6 + TAU * i / 6.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * r * 0.7 * pulse)
			for i in 3:
				var bl := t * 3.0 + TAU * i / 3.0
				ci.draw_line(p + Vector2(cos(bl), sin(bl)) * r * 0.8, p + Vector2(cos(bl), sin(bl)) * r * 1.25, glow, lw, true)
	if pts.size() > 0:
		ci.draw_colored_polygon(pts, body)
		pts.append(pts[0])
		ci.draw_polyline(pts, glow, lw, true)
		ci.draw_circle(p, r * 0.18, glow)
	# 겨누는 쪽 표시
	ci.draw_line(p + aim * r * 1.05, p + aim * r * 1.45, Color(glow, 0.9), lw * 0.8, true)


# ==================== 적 ====================

## 적 — 네온 글리치 도형 하나(재정비 8-2). 종마다 모양 · 티어마다 색(NvD.ENEMY 의 col). 그리기 등급(tier)과 무관하게
## 마리당 도형 한 번이라 수백 마리도 가볍다. 보스의 예비 동작은 언제나 먼저 바닥에 깐다(피할 수 있어야 하는 정보).
static func enemy(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var kind: int = e["k"]
	var r: float = e["r"]
	var hit: float = e["hit"]
	var flash := 1.0 + minf(1.0, hit) * 1.6
	var row: Dictionary = NvD.ENEMY[kind]
	var art: String = row["art"]
	if float(e.get("cast", 0.0)) > 0.0:
		_boss_cast(ci, e, t)
	var pos: Vector2 = e["p"]
	var spin := float(e.get("seed", 0.0)) * 6.0 + t * (1.6 if art == "runner" else 0.5)
	glitch(ci, pos, r, art, row["col"], t, spin, flash)
	_hpbar(ci, e, pos, r, art)


static func _boss_cast(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var c: Vector2 = e["p"]
	var mx: float = maxf(0.001, float(e.get("cast_max", 0.6)))
	var u: float = clampf(1.0 - float(e["cast"]) / mx, 0.0, 1.0)
	var hot := NvP.a(NvP.hdr(NvP.CRIMSON, 1.6), 0.30 + 0.45 * u)
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
			NvG2.fill_fan(ci, PackedVector2Array([
				c + n * hw, c + d * reach + n * hw, c + d * reach - n * hw, c - n * hw,
			]), NvP.a(NvP.hdr(NvP.CRIMSON, 1.3), 0.16 + 0.16 * blink))
			ci.draw_line(c, c + d * reach, NvP.a(NvP.hdr(NvP.CRIMSON, 1.8), 0.7 * blink), 3.0, true)
		"slam":
			ci.draw_circle(c, NvD.BOSS_SLAM_R * u, NvP.a(NvP.hdr(NvP.CRIMSON, 1.1), 0.13))
			ci.draw_arc(c, NvD.BOSS_SLAM_R, 0.0, TAU, 44, hot, 3.0 + 3.0 * u, true)
			ci.draw_arc(c, NvD.BOSS_SLAM_R * u, 0.0, TAU, 40,
				NvP.a(NvP.hdr(NvP.GOLD_HI, 1.6), 0.8 * blink), 3.0, true)
		"volley":
			var dv := (Vector2(e.get("dv", Vector2.RIGHT)))
			if dv.length_squared() < 0.01:
				dv = Vector2(float(e.get("face", 1.0)), 0)
			var half := NvD.BOSS_VOLLEY_ARC * 0.5
			var pts := PackedVector2Array([c])
			for i in 9:
				var k := -half + NvD.BOSS_VOLLEY_ARC * float(i) / 8.0
				pts.append(c + dv.rotated(k) * (420.0 * u))
			NvG2.fill_fan(ci, pts, NvP.a(NvP.hdr(NvP.VENOM, 1.2), 0.12 + 0.14 * blink))
			for i in NvD.BOSS_VOLLEY:
				var k2 := (float(i) - (NvD.BOSS_VOLLEY - 1) * 0.5) / maxf(1.0, NvD.BOSS_VOLLEY - 1)
				ci.draw_line(c, c + dv.rotated(k2 * NvD.BOSS_VOLLEY_ARC) * (420.0 * u),
					NvP.a(NvP.hdr(NvP.VENOM, 1.6), 0.45 * blink), 2.0, true)


## 체력 띠는 오래 버티는 놈에게만 붙인다 — 그림 접두어로 고르므로 상위 종도 같이 붙는다.
static func _hpbar(ci: CanvasItem, e: Dictionary, c: Vector2, r: float, art: String) -> void:
	if art != "boss" and art != "fat":
		return
	var f: float = clampf(float(e["hp"]) / maxf(1.0, float(e["hpmax"])), 0.0, 1.0)
	var w := r * 1.9
	var bar := Rect2(c.x - w * 0.5, c.y - r * 1.62, w, 5.0)
	ci.draw_rect(bar, NvP.a(Color.BLACK, 0.6))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)),
		NvP.hdr(NvP.CRIMSON if art == "boss" else NvP.ORANGE, 1.3))


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
			ci.draw_line(p - d0 * r * 5.0, p + d0 * r * 1.2, NvP.a(col, 0.32), r * 0.8, true)
			ci.draw_line(p - d0 * r * 3.0, p + d0 * r * 0.6, NvP.hdr(col, 1.7), r * 0.42, true)
			NvG2.fill_fan(ci, PackedVector2Array([
				p + d0 * r * 1.7, p + n0 * r * 0.62 - d0 * r * 0.2,
				p - n0 * r * 0.62 - d0 * r * 0.2,
			]), NvP.hdr(Color.WHITE, 1.5))
			# 오늬 — 뒤쪽 깃
			ci.draw_line(p - d0 * r * 2.4 + n0 * r * 0.5, p - d0 * r * 3.2 - n0 * r * 0.5,
				NvP.a(NvP.hdr(col, 1.3), 0.7), r * 0.3, true)
		"homing":
			# 유도 화살 — 자국이 길고 촉이 옥색이다. 폭발하지 않으므로 화염구와 헷갈리면 안 된다.
			var dh: Vector2 = b["v"].normalized()
			var nh := dh.orthogonal()
			ci.draw_line(p - dh * r * 3.4, p - dh * r * 0.4,
				NvP.a(NvP.hdr(col, 1.5), 0.45), r * 0.9, true)
			ci.draw_line(p - dh * r * 1.6, p + dh * r * 0.8, NvP.hdr(col, 1.6), r * 0.5, true)
			NvG2.fill_fan(ci, PackedVector2Array([
				p + dh * r * 1.6, p + nh * r * 0.58, p - nh * r * 0.58,
			]), NvP.hdr(Color.WHITE, 1.6))
		"fireball":
			# 불덩이 — 맞으면 터진다. **둥글고 크게** 그려서 화살류와 실루엣이 안 겹치게 한다.
			var pulse0 := 0.85 + 0.15 * sin(t * 18.0)
			var df: Vector2 = b["v"].normalized()
			ci.draw_line(p - df * r * 3.2, p - df * r * 0.4, NvP.a(NvP.hdr(NvP.ORANGE, 1.4), 0.42),
				r * 1.3, true)
			ci.draw_circle(p, r * 1.15 * pulse0, NvP.a(NvP.hdr(NvP.CRIMSON, 1.2), 0.55))
			ci.draw_circle(p, r * 0.80 * pulse0, NvP.hdr(NvP.ORANGE, 1.7))
			ci.draw_circle(p - df * r * 0.14, r * 0.40, NvP.hdr(NvP.GOLD_HI, 2.0))
		"axe":
			# 던진 도끼 — 실제로 돈다. 돌아오는 길에도 같은 그림이라 "되돌아온다"가 읽힌다.
			var sp := float(b.get("spin", 0.0)) + t * 17.0
			var ax := Vector2(cos(sp), sin(sp))
			var ay := ax.orthogonal()
			ci.draw_line(p - ax * r * 0.9, p + ax * r * 0.9, Color8(96, 74, 52), r * 0.26, true)
			for s: float in [-1.0, 1.0]:
				# 날 — 자루 양 끝에 붙은 부채꼴
				var base := p + ax * (r * 0.72 * s)
				NvG2.fill_fan(ci, PackedVector2Array([
					base - ay * r * 0.62, base + ax * (r * 0.52 * s) - ay * r * 0.30,
					base + ax * (r * 0.52 * s) + ay * r * 0.30, base + ay * r * 0.62,
				]), NvP.hdr(col, 1.25))
			ci.draw_circle(p, r * 0.22, NvP.LINE)
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
			ci.draw_line(p - d2 * r * 3.6, p - d2 * r * 0.5, NvP.a(col, 0.26), r * 1.5, true)
			ci.draw_arc(p, r * (1.9 + 0.5 * pulse), 0.0, TAU, 16,
				NvP.a(NvP.hdr(col, 1.6), 0.30 + 0.35 * pulse), 2.6, true)
			ci.draw_circle(p, r * 1.34, NvP.a(NvP.LINE, 0.92))
			ci.draw_circle(p, r * 1.06, NvP.hdr(col, 1.55))
			ci.draw_circle(p + d2 * r * 0.22, r * 0.42, NvP.hdr(Color.WHITE, 1.8))
		_:
			# 드론 탄 — 캡슐형
			var d3: Vector2 = b["v"].normalized()
			ci.draw_line(p - d3 * r * 1.4, p + d3 * r * 0.8, NvP.a(col, 0.30), r * 2.2, true)
			ci.draw_line(p - d3 * r * 1.0, p + d3 * r * 0.7, NvP.hdr(col, 1.7), r * 1.1, true)


## 경험치 젬 — **그리기 호출 딱 한 번.**
##
## 젬은 화면에 수십에서 백 개 넘게 깔린다. 예전에는 `NvG2.glow`(텍스처 한 장) + `gem.png`
## (텍스처 한 장)로 마리당 두 번씩 그렸는데, 젬만으로 프레임을 갉아먹었다.
## 지금은 `draw_circle` 하나다 —
##  - `draw_circle` 은 배칭이 되므로 개수가 늘어도 그리기 명령이 안 쪼개진다
##    (`fill_fan` 은 호출마다 명령이 따로 생겨서 안 된다)
##  - 발광은 색을 1.0 위로 올려(`NvP.hdr`) 엔진 블룸에 맡긴다. 후광을 따로 그릴 필요가 없다
##
## **여기에 겹을 더하지 마세요.** 하이라이트 한 점만 얹어도 그리기 호출이 두 배가 된다.
## 어떤 적이 떨궜는지는 색과 크기로만 구분한다 — 같은 초록 알갱이만 굴러다니면
## 뭘 주워야 이득인지 화면만 보고는 알 수 없다.
static func gem(ci: CanvasItem, gm: Dictionary, t: float) -> void:
	var kind: int = int(gm.get("k", NvD.S_ZOMBIE))
	var col: Color = NvD.ENEMY[kind]["col"] if kind >= 0 and kind < NvD.ENEMY.size() else NvP.XP
	var xpv: int = int(gm.get("xp", 1))
	var s := 3.6 + sqrt(maxf(1.0, float(xpv))) * 1.7 + sin(t * 6.0 + float(gm["t"]) * 4.0) * 0.7
	ci.draw_circle(gm["p"], s, NvP.hdr(col, 2.2))


## 바닥에 떨어진 아이템. **셋이 실루엣으로 갈려야 한다** — 젬은 단색 동그라미 한 겹,
## 자석은 말굽, 구급 상자는 네모다. 색만 다르면 젬이 수백 개 깔린 판 후반에 통째로 묻힌다.
## 한 라운드에 한두 개뿐이라 그리기 비용은 신경 쓸 필요가 없다.
static func item(ci: CanvasItem, it: Dictionary, t: float) -> void:
	var r := NvD.ITEM_R
	var age := float(it.get("t", 0.0))
	var c: Vector2 = Vector2(it["p"]) + Vector2(0, -absf(sin(t * 3.0 + age)) * 4.0)
	_shadow(ci, Vector2(it["p"]) + Vector2(0, r * 0.72), r * 0.60, r * 0.24, 0.30)
	match String(it.get("kind", "magnet")):
		"heal": _item_heal(ci, c, r, t, age)
		"chest": _item_chest(ci, c, r, t, age)
		_: _item_magnet(ci, c, r, t, age)


## 보물상자 — **진화가 이 안에 있다.** 화면에서 제일 눈에 띄어야 하므로 크게 그리고
## 금빛으로 세게 빛낸다. 보스를 잡은 자리에 남으므로 시체·이펙트에 묻히기 쉽다.
static func _item_chest(ci: CanvasItem, c: Vector2, r: float, t: float, age: float) -> void:
	var s := r * 1.45
	var puls := 0.75 + 0.25 * sin(t * 3.6 + age)
	NvG2.glow(ci, c, s * 3.4, NvP.GOLD_HI, 0.34 * puls)
	# 위로 솟는 빛기둥 — 멀리서도 "저기 뭔가 있다"가 읽힌다
	ci.draw_line(c, c + Vector2(0, -s * 3.2), NvP.a(NvP.hdr(NvP.GOLD_HI, 1.6), 0.20 * puls),
		s * 0.5, true)
	# 상자 몸통 + 뚜껑
	var body := Rect2(c - Vector2(s * 0.78, s * 0.10), Vector2(s * 1.56, s * 0.78))
	NvG2.fill_round(ci, body, s * 0.12, Color8(126, 82, 44))
	NvG2.stroke_round(ci, body, s * 0.12, NvP.LINE, maxf(1.4, s * 0.10))
	ci.draw_arc(c + Vector2(0, -s * 0.08), s * 0.78, PI, TAU, 18,
		Color8(158, 106, 56), s * 0.44, true)
	# 금테와 자물쇠
	ci.draw_line(c + Vector2(-s * 0.80, -s * 0.06), c + Vector2(s * 0.80, -s * 0.06),
		NvP.hdr(NvP.GOLD, 1.5), s * 0.16, true)
	ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.20, NvP.hdr(NvP.GOLD_HI, 1.8 * puls))


## 바닥의 동전 — **그리기 호출 두 번**으로 끝낸다. 젬만큼은 아니어도 여럿 깔린다.
static func coin(ci: CanvasItem, c: Dictionary, t: float) -> void:
	var p: Vector2 = c["p"]
	# 옆으로 도는 것처럼 폭만 줄였다 편다
	var w := absf(cos(t * 4.0 + float(c["t"]) * 3.0))
	var s := 7.0 + minf(4.0, float(c["n"]) * 0.5)
	ci.draw_circle(p, s, NvP.hdr(NvP.GOLD, 1.5))
	ci.draw_circle(p - Vector2(0, s * 0.18), s * 0.52 * (0.25 + 0.75 * w),
		NvP.hdr(NvP.GOLD_HI, 2.0))


## 파괴 가능한 통. 맵을 훑고 다닐 이유를 만드는 장치라 **바닥 무늬와 확실히 달라야** 한다.
static func prop(ci: CanvasItem, pr: Dictionary, t: float) -> void:
	# 맵의 통 — 네온 상자(재정비 8-2). 맞으면 하얗게, 반쯤 부서지면 금 표시.
	var p: Vector2 = pr["p"]
	var r := NvD.PROP_R
	var hit: float = float(pr["hit"])
	var col := Color8(255, 190, 80).lerp(Color.WHITE, minf(1.0, hit))
	var glow := Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 1.0)
	var box := Rect2(p - Vector2(r * 0.7, r * 0.7), Vector2(r * 1.4, r * 1.4))
	NvG2.fill_round(ci, box, r * 0.2, Color(0.08, 0.05, 0.02, 0.9))
	NvG2.stroke_round(ci, box, r * 0.2, glow, maxf(1.6, r * 0.12))
	ci.draw_line(box.position + Vector2(r * 0.25, r * 0.25), box.end - Vector2(r * 0.25, r * 0.25), Color(glow, 0.6), maxf(1.2, r * 0.08), true)
	if float(pr["hp"]) < NvD.PROP_HP * 0.5:
		ci.draw_line(p + Vector2(-r * 0.3, r * 0.3), p + Vector2(r * 0.3, -r * 0.3), Color(1, 1, 1, 0.8), r * 0.08, true)


## 구급 상자 — **네모**다. 회복은 이 게임에서 이미 옥색(체력 띠 · 구급 상자 카드)이라
## 같은 색을 쓴다. 흰 상자에 옥색 십자라 어두운 바닥 어디서나 떠 보인다.
static func _item_heal(ci: CanvasItem, c: Vector2, r: float, t: float, age: float) -> void:
	NvG2.glow(ci, c, r * 3.2, NvP.JADE, 0.26 + 0.12 * sin(t * 5.0 + age))
	var box := Rect2(c - Vector2(r * 0.74, r * 0.62), Vector2(r * 1.48, r * 1.24))
	NvG2.fill_round(ci, box, r * 0.26, NvP.hdr(Color8(228, 240, 252), 1.05))
	NvG2.stroke_round(ci, box, r * 0.26, NvP.LINE, maxf(1.4, r * 0.14))
	# **십자는 1.35 배까지만 올린다.** 1.7 을 먹이면 초록·파랑이 둘 다 1.0 을 넘어 잘려서
	# 옥색이 아니라 청록으로 보인다 — 회복은 옥색이라는 이 게임의 색 규칙이 거기서 깨진다.
	# 밝기는 위의 발광(`NvG2.glow`)이 이미 낸다.
	var arm := r * 0.30
	var cross := NvP.hdr(NvP.JADE, 1.35)
	ci.draw_line(c - Vector2(r * 0.46, 0), c + Vector2(r * 0.46, 0), cross, arm, true)
	ci.draw_line(c - Vector2(0, r * 0.38), c + Vector2(0, r * 0.38), cross, arm, true)


static func _item_magnet(ci: CanvasItem, c: Vector2, r: float, t: float, age: float) -> void:
	var steel := NvP.hdr(Color8(206, 218, 240), 1.15)
	NvG2.glow(ci, c, r * 3.2, NvP.CYAN, 0.26 + 0.12 * sin(t * 5.4 + age))
	# 말굽 — 위쪽 반원 + 아래로 뻗은 두 다리. y 가 아래로 크므로 PI~TAU 가 윗반원이다.
	var arm := r * 0.60
	ci.draw_arc(c, arm, PI, TAU, 20, steel, r * 0.40, true)
	for s: float in [-1.0, 1.0]:
		var top := c + Vector2(arm * s, 0)
		ci.draw_line(top, top + Vector2(0, r * 0.44), steel, r * 0.40, true)
		# 극 — 왼쪽 빨강, 오른쪽 파랑
		ci.draw_line(top + Vector2(0, r * 0.40), top + Vector2(0, r * 0.86),
			NvP.hdr(NvP.CRIMSON if s < 0.0 else NvP.AZURE, 1.6), r * 0.40, true)
	# 극 사이에서 튀는 자력
	var spark := 0.5 + 0.5 * sin(t * 9.0 + age * 2.0)
	ci.draw_line(c + Vector2(-arm, r * 0.86), c + Vector2(arm, r * 0.86),
		NvP.a(NvP.hdr(NvP.CYAN, 1.9), 0.25 + 0.45 * spark), r * 0.14, true)


## 자석이 켜져 있는 동안 주인공을 두르는 고리. **켜져 있다는 것이 화면에 남아야 한다** —
## 젬이 날아오는 것만으로는 무엇 때문인지, 언제 끝나는지 알 수 없다.
## `f` 는 남은 비율(1 → 0)이라 고리가 좁아지며 끝을 알린다.
static func magnet_aura(ci: CanvasItem, p: Vector2, f: float, t: float) -> void:
	var k := clampf(f, 0.0, 1.0)
	NvG2.glow(ci, p, 150.0 * (0.6 + 0.4 * k), NvP.CYAN, 0.16 * k)
	for i in 2:
		# 안쪽으로 빨려 들어가는 고리 두 겹 — 방향이 곧 "끌어당긴다"는 신호다
		var u := fmod(t * 1.6 + float(i) * 0.5, 1.0)
		ci.draw_arc(p, 40.0 + (1.0 - u) * 260.0, 0.0, TAU, 34,
			NvP.a(NvP.hdr(NvP.CYAN, 1.5), 0.55 * u * k), 2.6, true)


static func drone(ci: CanvasItem, d: Dictionary, t: float) -> void:
	var p: Vector2 = d["p"]
	var w := 10.0
	var dtex := NvSpr.get_tex("drone")
	if dtex != null:
		NvSpr.blit(ci, dtex, p, w * 3.4, 1.0)
		return
	var spin := t * 26.0
	# 프로펠러 먼저 (뒤로)
	for s in [-1.0, 1.0]:
		var at := p + Vector2(s * w * 1.25, -w * 0.42)
		ci.draw_line(at - Vector2(cos(spin), sin(spin) * 0.35) * w * 0.75,
			at + Vector2(cos(spin), sin(spin) * 0.35) * w * 0.75, NvP.a(NvP.WHITE, 0.55), 2.0, true)
		ci.draw_circle(at, w * 0.22, NvP.LINE)
	# 동체
	var body := PackedVector2Array([
		p + Vector2(-w * 0.9, -w * 0.34), p + Vector2(w * 0.9, -w * 0.34),
		p + Vector2(w * 0.6, w * 0.55), p + Vector2(-w * 0.6, w * 0.55),
	])
	NvG2.fill_fan(ci, body, Color8(38, 92, 74))
	NvG2.fill_fan(ci, PackedVector2Array([
		p + Vector2(-w * 0.72, -w * 0.24), p + Vector2(w * 0.34, -w * 0.24),
		p + Vector2(w * 0.20, w * 0.14), p + Vector2(-w * 0.50, w * 0.14),
	]), NvP.JADE)
	NvG2.stroke(ci, body, NvP.LINE, 1.8)
	ci.draw_circle(p + Vector2(0, w * 0.10), w * 0.22, NvP.hdr(NvP.CYAN, 1.8))


## 회전 사슬의 쇳덩이. 마법사가 "부유 룬 고리"로 진화시켰으면 쇳덩이가 아니라 **룬**이다 —
## 같은 궤도를 도는데 그림까지 같으면 진화한 것이 화면에서 안 보인다.
static func orb(ci: CanvasItem, at: Vector2, r: float, t: float, rune: bool = false) -> void:
	if rune:
		NvG2.glow(ci, at, r * 3.2, NvP.VIOLET, 0.30)
		ci.draw_circle(at, r * 0.86, NvP.a(NvP.hdr(NvP.VIOLET, 1.4), 0.55))
		ci.draw_arc(at, r * 0.86, 0.0, TAU, 14, NvP.hdr(NvP.VIOLET, 1.9), maxf(1.4, r * 0.14), true)
		# 룬 문양 — 가운데를 가로지르는 빗금 두 개
		var a := t * 2.2
		var d := Vector2(cos(a), sin(a)) * r * 0.52
		ci.draw_line(at - d, at + d, NvP.hdr(Color.WHITE, 1.9), maxf(1.2, r * 0.12), true)
		ci.draw_line(at - d.orthogonal() * 0.6, at + d.orthogonal() * 0.6,
			NvP.a(NvP.hdr(Color.WHITE, 1.6), 0.7), maxf(1.0, r * 0.09), true)
		return
	NvG2.glow(ci, at, r * 2.8, NvP.GOLD, 0.28)
	# 각진 쇳덩이 — 매끈한 구슬보다 사슬 끝에 달린 추처럼 보인다
	var pts := NvG2.star_pts(at, r * 0.72, r, 6, t * 3.2)
	NvG2.fill_fan(ci, pts, NvP.hdr(NvP.GOLD, 1.15))
	NvG2.stroke(ci, pts, NvP.LINE, maxf(1.2, r * 0.16))
	ci.draw_circle(at + Vector2(-r * 0.26, -r * 0.30), r * 0.24, NvP.a(Color.WHITE, 0.7))

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
			var sweep := NvG2.out_cubic(u0)
			var a0: float = float(a.get("ang", 0.0))
			var rings := 2 if bool(a.get("twin", false)) else 1
			for k in rings:
				var rr := r * (1.0 if k == 0 else 0.62)
				var dirn := 1.0 if k == 0 else -1.0
				ci.draw_arc(p, rr, a0, a0 + dirn * TAU * sweep, 30,
					NvP.a(NvP.hdr(NvP.GOLD_HI, 1.8), (1.0 - u0) * 0.9), 9.0 * (1.0 - u0) + 2.0, true)
				# 칼끝 — 지금 베고 있는 자리
				var tip := p + Vector2(cos(a0 + dirn * TAU * sweep),
					sin(a0 + dirn * TAU * sweep)) * rr
				ci.draw_circle(tip, (5.0 * (1.0 - u0) + 1.5), NvP.hdr(Color.WHITE, 1.8))
		"quake":
			# 대지 분쇄 — 퍼지는 고리 + 바깥으로 뻗는 균열
			var u: float = 1.0 - float(a["life"]) / float(a["max"])
			var rr2 := r * NvG2.out_cubic(u)
			ci.draw_arc(p, rr2, 0.0, TAU, 40,
				NvP.a(NvP.hdr(NvP.AZURE, 1.7), (1.0 - u) * 0.9), 8.0 * (1.0 - u) + 1.5, true)
			for i in 8:
				var ang2 := TAU * i / 8.0 + float(a["max"]) * 3.0
				var dirv := Vector2(cos(ang2), sin(ang2))
				ci.draw_line(p + dirv * rr2 * 0.55, p + dirv * rr2,
					NvP.a(NvP.hdr(NvP.CYAN, 1.4), (1.0 - u) * 0.55), 3.0, true)
		"guard":
			# 강철 방벽 — 육각 판. **인공물처럼** 보여야 마법 결계와 안 헷갈린다.
			var pulse := 0.72 + 0.28 * sin(t * 3.4)
			NvG2.glow(ci, p, r * 1.05, NvP.AZURE, 0.14 * pulse)
			var hex := PackedVector2Array()
			for i in 6:
				var ang := TAU * i / 6.0 + t * 0.5
				hex.append(p + Vector2(cos(ang), sin(ang)) * r)
			NvG2.stroke(ci, hex, NvP.a(NvP.hdr(NvP.AZURE, 1.5), 0.62 * pulse), 5.5)
			ci.draw_arc(p, r * 0.94, 0.0, TAU, 40, NvP.a(NvP.hdr(NvP.CYAN, 1.3), 0.28 * pulse), 2.0, true)
			# 판을 잇는 리벳 — 금속이라는 표시
			for i in 6:
				var ang3 := TAU * i / 6.0 + t * 0.5
				ci.draw_circle(p + Vector2(cos(ang3), sin(ang3)) * r, 3.4,
					NvP.a(NvP.hdr(NvP.CYAN, 1.6), 0.8 * pulse))
		"ward":
			# 반사 결계 — 도는 룬 고리 둘. 강철 방벽과 달리 **둥글고 흐른다**.
			var pw := 0.70 + 0.30 * sin(t * 2.6)
			NvG2.glow(ci, p, r * 1.05, NvP.VIOLET, 0.15 * pw)
			ci.draw_arc(p, r, 0.0, TAU, 44, NvP.a(NvP.hdr(NvP.VIOLET, 1.5), 0.55 * pw), 4.0, true)
			ci.draw_arc(p, r * 0.88, 0.0, TAU, 40, NvP.a(NvP.hdr(NvP.CYAN, 1.2), 0.26 * pw), 1.8, true)
			for i in 9:
				var ang4 := TAU * i / 9.0 + t * 0.9
				var at2 := p + Vector2(cos(ang4), sin(ang4)) * r
				# 룬 — 짧은 빗금 두 개
				var tang := Vector2(-sin(ang4), cos(ang4))
				ci.draw_line(at2 - tang * 7.0, at2 + tang * 7.0,
					NvP.a(NvP.hdr(NvP.VIOLET, 1.7), 0.85 * pw), 3.0, true)
		"fire":
			var f: float = clampf(float(a["life"]) / float(a["max"]), 0.0, 1.0)
			NvG2.glow(ci, p, r * 1.15, NvP.ORANGE, 0.30 * f)
			# 불꽃 혀 — 길이가 제각각 흔들린다
			for i in 9:
				var ang := TAU * i / 9.0 + float(a["max"])
				var h := r * (0.55 + 0.45 * absf(sin(t * 4.0 + i * 1.7)))
				var base := p + Vector2(cos(ang), sin(ang)) * r * 0.62
				NvG2.fill_fan(ci, PackedVector2Array([
					base + Vector2(cos(ang + 1.4), sin(ang + 1.4)) * r * 0.24,
					base + Vector2(cos(ang), sin(ang)) * h * 0.55,
					base + Vector2(cos(ang - 1.4), sin(ang - 1.4)) * r * 0.24,
				]), NvP.a(NvP.hdr(NvP.ORANGE, 1.5), 0.40 * f))
			ci.draw_circle(p, r * 0.44, NvP.a(NvP.hdr(NvP.GOLD, 1.3), 0.30 * f))


## 광선 자국. 서리 창(옥빛)과 관통 저격(금빛)이 같은 배열을 쓰므로 **색은 줄에 담겨 온다** —
## 여기서 고정하면 저격이 냉기처럼 보인다.
static func beam(ci: CanvasItem, b: Dictionary) -> void:
	var f: float = clampf(float(b["life"]) / float(b["max"]), 0.0, 1.0)
	var w: float = float(b["w"])
	var c: Color = b.get("col", NvP.CYAN)
	ci.draw_line(b["a"], b["b"], NvP.a(NvP.hdr(c, 1.2), 0.28 * f), w * 2.1, true)
	ci.draw_line(b["a"], b["b"], NvP.a(NvP.hdr(c, 1.8), 0.75 * f), w, true)
	ci.draw_line(b["a"], b["b"], NvP.a(NvP.hdr(Color.WHITE, 1.9), f), w * 0.35, true)


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
	ci.draw_polyline(line, NvP.a(NvP.hdr(NvP.VIOLET, 1.3), 0.35 * f), 9.0, true)
	ci.draw_polyline(line, NvP.a(NvP.hdr(Color.WHITE, 1.9), f), 3.0, true)


# ==================== 네온 글리치 (재정비 8-2, docs/design/neon.md) ====================

## 적 모양 — 종마다 도형이 다르다(색을 못 가려도 모양으로 읽힘): 기본 원 · 질주 삼각 · 비대 육각 · 폭탄 마름모(맥동) · 침 별 · 보스 겹 팔각.
const GLITCH_SIDES := {"zombie": 0, "runner": 3, "fat": 6, "bomber": 4, "spitter": 5, "boss": 8}


## 네온 도형 하나 — 어두운 속 + 밝은 테(색 1.0 넘게 올려 발광) + 안쪽 작은 핵. face = 진행 방향(라디안).
static func glitch(ci: CanvasItem, c: Vector2, r: float, art: String, col: Color, t: float, face: float = 0.0,
		flash: float = 1.0) -> void:
	var n: int = GLITCH_SIDES.get(art, 0)
	var glow := Color(col.r * 1.7 * flash, col.g * 1.7 * flash, col.b * 1.7 * flash, 1.0)
	var rr := r
	if art == "bomber":
		rr = r * (1.0 + 0.08 * sin(t * 9.0 + c.x * 0.01))
	if n == 0:
		ci.draw_circle(c, rr, Color(col.darkened(0.75), 0.9))
		ci.draw_arc(c, rr, 0, TAU, 24, glow, maxf(2.0, r * 0.14), true)
	else:
		var pts := PackedVector2Array()
		var star := art == "spitter"
		var k := n * (2 if star else 1)
		for i in k:
			var a := face + TAU * i / k
			var d := rr * (0.5 if star and i % 2 == 1 else 1.0)
			pts.append(c + Vector2(cos(a), sin(a)) * d)
		ci.draw_colored_polygon(pts, Color(col.darkened(0.75), 0.9))
		pts.append(pts[0])
		ci.draw_polyline(pts, glow, maxf(2.0, r * 0.14), true)
		if art == "boss":
			var inner := PackedVector2Array()
			for i in n + 1:
				var a2 := -face * 0.7 + TAU * i / n
				inner.append(c + Vector2(cos(a2), sin(a2)) * rr * 0.62)
			ci.draw_polyline(inner, glow, maxf(1.5, r * 0.08), true)
	ci.draw_circle(c, rr * 0.22, glow)
