class_name Art
extends RefCounted

## 스프라이트. 전부 코드로 그린다 — 이미지 파일 0장.
##
## 조각(폴리곤 + 그늘 + 외곽선)은 **로컬 좌표에서 한 번만** 만들어 캐시한다.
## 그늘을 매 프레임 [Geometry2D] 로 깎으면 그것만으로 프레임을 먹는다.
## 그릴 때는 draw_set_transform 으로 자리·각도·배율만 건다.

static var _cache := {}

## 프로펠러 원반의 세로 납작 비율.
##
## 진짜 위에서 내려다보면 프로펠러는 정면이 아니라 **옆면**이 보인다.
## 정원으로 그리면 코에 바퀴를 붙인 것처럼 보인다.
const PROP_K := 0.30


static func _part(pts, col: Color, lw: float) -> Dictionary:
	var p: PackedVector2Array = pts if pts is PackedVector2Array else G2.poly(pts)
	p = _flip(p)
	return {fill = p, col = col, lw = lw, shade = G2.shade_of(p)}


static func _pair(out: Array, pts, col: Color, lw: float) -> void:
	var p := G2.poly(pts)
	out.append(_part(p, col, lw))
	out.append(_part(G2.mirror(p), col, lw))


## 수직 미익 — 위에서 보면 얇은 널빤지
static func _fin(out: Array, x: float, y0: float, y1: float, w: float, col: Color) -> void:
	out.append(_part([[x - w, y0], [x + w, y0 + 0.6], [x + w * 0.8, y1], [x - w * 0.8, y1]],
			col, 0.9))


static func shape(key: String) -> Dictionary:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func draw_parts(ci: CanvasItem, parts: Array) -> void:
	for pt in parts:
		G2.fill_fan(ci, pt.fill, pt.col)
		for s in pt.shade:
			G2.fill_fan(ci, s, P.SHADE)
		G2.stroke(ci, pt.fill, P.LINE, pt.lw)

# ==================== 부품 ====================

static func canopy(ci: CanvasItem, c: Vector2, rx: float, ry: float) -> void:
	var e := G2.ellipse_pts(c, rx, ry, 14)
	G2.fill_fan(ci, e, P.GLASS)
	G2.stroke(ci, e, P.LINE, 1.0)
	G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(-rx * 0.32, -ry * 0.18),
			rx * 0.42, ry * 0.46, 10), P.GLASS_HI)


static func prop(ci: CanvasItem, c: Vector2, r: float, t: float, sp: float) -> void:
	var a := t * sp
	var k := PROP_K
	G2.fill_fan(ci, G2.ellipse_pts(c, r, r * k, 18), P.a(P.PROP, 0.13))
	for i in 2:
		var b := a + i * PI
		var tip := Vector2(cos(b) * r, sin(b) * r * k)
		var half := tip.length() * 0.5
		if half < 0.6:
			continue
		var dir := tip.normalized()
		var nrm := Vector2(-dir.y, dir.x) * maxf(0.85, r * 0.085)
		var mid := c + tip * 0.5
		G2.fill_fan(ci, PackedVector2Array([
			mid - dir * half + nrm, mid + dir * half + nrm,
			mid + dir * half - nrm, mid - dir * half - nrm]), Color(0.09, 0.13, 0.19, 0.9))
	# 원반 가장자리가 제일 촘촘해 보이는 자리. 여기가 밝아야 "돌고 있다"가 산다.
	for s in [-1.0, 1.0]:
		G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(s * r * 0.86, 0),
				r * 0.16, r * k * 0.9, 8), P.a(P.PROP_TIP, 0.38))
	G2.fill_fan(ci, G2.ellipse_pts(c, maxf(1.3, r * 0.13),
			maxf(1.1, r * 0.13 * (k + 0.55)), 8), Color8(70, 88, 108))


## 제트 노즐 불꽃. 프로펠러기에는 쓰지 않는다 — 도는 프로펠러가 이미 엔진 표시이고,
## 동체 옆에 불꽃을 달면 배기가 아니라 "몸에 불이 붙은 것"으로 보인다.
static func jet_flame(ci: CanvasItem, c: Vector2, len: float, wid: float, t: float,
		seed: float, col: Color) -> void:
	var k := 0.8 + 0.2 * sin(t * 34.0 + seed * 2.1) + 0.07 * sin(t * 73.0 + seed)
	var l := len * k
	G2.glow(ci, c + Vector2(0, l * 0.45), maxf(wid * 2.8, l * 0.8), col, 0.42)
	G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(0, l * 0.44), wid * 0.95, l * 0.54, 14),
			P.a(col, 0.8))
	G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(0, l * 0.31), wid * 0.58, l * 0.38, 12),
			P.hdr(col, 1.25))
	G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(0, l * 0.20), wid * 0.30, l * 0.25, 10),
			Color(1, 1, 0.92))


static func nav_turret(ci: CanvasItem, c: Vector2, r: float, ang: float, n: int,
		col: Color) -> void:
	# **자리를 직접 계산한다.** draw_set_transform 을 여기서 다시 부르면 바깥에서 걸어 둔
	# 배율·위치를 통째로 덮어써서, 축소된 보스의 포탑만 원래 크기로 튀어나온다.
	var tf := Transform2D(ang, c)
	var base := G2.circle_pts(c, r * 1.18, 14)
	G2.fill_fan(ci, base, P.NAVY_D)
	G2.stroke(ci, base, P.LINE, 1.2)
	for i in n:
		var bx := (i - (n - 1) * 0.5) * r * 0.66
		var bar := _xf(G2.poly([[bx - r * 0.21, 0], [bx + r * 0.21, 0],
				[bx + r * 0.17, r * 2.6], [bx - r * 0.17, r * 2.6]]), tf)
		G2.fill_fan(ci, bar, P.IRON)
		G2.stroke(ci, bar, P.LINE, 1.0)
	var house := _xf(G2.poly([[-r, -r * 0.95], [r, -r * 0.95], [r * 0.84, r * 0.8],
			[-r * 0.84, r * 0.8]]), tf)
	G2.fill_fan(ci, house, col)
	G2.stroke(ci, house, P.LINE, 1.25)
	G2.fill_fan(ci, _xf(G2.circle_pts(Vector2(0, -r * 0.3), r * 0.28, 8), tf), P.FOE_MARK)

# ==================== 조각 만들기 ====================

## 적기는 아래(+y)를 보고 난다. 도형은 아군과 같은 자세(코가 -y)로 적어 두고
## 이 깃발로 y 를 뒤집는다. **회전으로 뒤집으면 그늘이 반대쪽에서 든다** —
## 그늘은 로컬 x>0 을 깎아 만들기 때문이다.
static var _fy := false


static func _v(x: float, y: float) -> Vector2:
	return Vector2(x, -y if _fy else y)


static func _flip(p: PackedVector2Array) -> PackedVector2Array:
	if not _fy:
		return p
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = Vector2(p[i].x, -p[i].y)
	return out


static func _build(key: String) -> Dictionary:
	_fy = false
	var s := {parts = [], canopies = [], props = [], flames = [], turrets = [], glows = [],
			smokes = []}
	match key:
		"craft0":
			var b := P.craft(0, 0)
			var d := P.craft(0, 1)
			var l := P.craft(0, 2)
			var tr := P.craft(0, 3)
			_pair(s.parts, [[3.2, -7], [16.5, -2.2], [20, 1.2], [19.4, 4.6], [3.4, 7.6]], b, 1.15)
			_pair(s.parts, [[2.3, 11.5], [8.8, 13.6], [9.2, 16.2], [2.1, 17.4]], d, 1.0)
			s.parts.append(_part([[0, -23], [3.4, -14], [4.2, -2], [3.0, 10], [1.6, 18], [0, 20],
					[-1.6, 18], [-3.0, 10], [-4.2, -2], [-3.4, -14]], b, 1.2))
			s.parts.append(_part([[0, -19], [1.7, -11], [2.1, 2], [1.4, 13], [0, 16],
					[-1.4, 13], [-2.1, 2], [-1.7, -11]], l, 0.85))
			_fin(s.parts, 0, 9, 19, 1.5, d)
			_pair(s.parts, [[1.4, -6], [3.9, -4.4], [3.6, 1.6], [1.4, 2.2]], tr, 0.8)
			s.canopies.append([Vector2(0, -5.2), 2.4, 5.2])
			s.props.append([Vector2(0, -21), 13.0, 17.0])

		"craft1":
			var b1 := P.craft(1, 0)
			var d1 := P.craft(1, 1)
			s.parts.append(_part([[-21, -1.5], [-13, -4.5], [13, -4.5], [21, -1.5], [21, 2.6],
					[13, 6.8], [-13, 6.8], [-21, 2.6]], b1, 1.15))
			_pair(s.parts, [[7.2, -16], [8.4, -20.4], [10.5, -21.6], [12.6, -20.4], [13.8, -16],
					[13.5, 9], [12.6, 17], [8.4, 17], [7.5, 9]], d1, 1.1)
			s.parts.append(_part([[-12, 12.8], [12, 12.8], [12, 17], [-12, 17]], b1, 1.05))
			s.parts.append(_part([[0, -15], [3.2, -9], [3.4, 2], [2.0, 8], [0, 10.5], [-2.0, 8],
					[-3.4, 2], [-3.2, -9]], b1, 1.2))
			s.parts.append(_part([[0, -12], [1.5, -7], [1.7, 1], [1.1, 6], [0, 8.4], [-1.1, 6],
					[-1.7, 1], [-1.5, -7]], P.craft(1, 2), 0.85))
			_pair(s.parts, [[8.6, -2], [13.2, -2], [13.2, 3.4], [8.6, 3.4]], P.craft(1, 3), 0.8)
			s.canopies.append([Vector2(0, -6.2), 2.2, 4.6])
			s.props.append([Vector2(10.5, -20.4), 9.0, 19.0])
			s.props.append([Vector2(-10.5, -20.4), 9.0, 19.0])

		"craft2":
			var b2 := P.craft(2, 0)
			var d2 := P.craft(2, 1)
			_pair(s.parts, [[3.6, -7], [9.6, 1.6], [18, -2.6], [21.6, -1], [21.4, 2.6],
					[10, 7.6], [3.8, 7.6]], b2, 1.15)
			_pair(s.parts, [[2.5, 10.8], [9.8, 13], [10.2, 15.6], [2.3, 16.8]], d2, 1.0)
			s.parts.append(_part([[0, -24], [3.6, -15], [4.4, -3], [3.2, 9], [1.8, 17], [0, 20],
					[-1.8, 17], [-3.2, 9], [-4.4, -3], [-3.6, -15]], b2, 1.2))
			s.parts.append(_part([[0, -20], [1.8, -12], [2.2, 1], [1.5, 12], [0, 16], [-1.5, 12],
					[-2.2, 1], [-1.8, -12]], P.craft(2, 2), 0.85))
			_fin(s.parts, 0, 8, 19.5, 1.6, d2)
			_pair(s.parts, [[6.4, -1.2], [10.4, -3.6], [10.8, -0.6], [6.8, 1.8]], P.craft(2, 3), 0.8)
			s.canopies.append([Vector2(0, -6), 2.5, 5.4])
			s.props.append([Vector2(0, -22), 15.0, 15.0])

		"craft3":
			var b3 := P.craft(3, 0)
			var d3 := P.craft(3, 1)
			_pair(s.parts, [[3.2, -6.6], [9, -5.8], [15, -3.8], [19.4, -0.8], [20.4, 1.6],
					[18, 4.6], [12, 6.8], [3.4, 7.6]], b3, 1.15)
			_pair(s.parts, [[2.3, 11], [6.6, 10.4], [9.4, 12.4], [9.6, 14.6], [6.4, 16.4],
					[2.1, 16.8]], d3, 1.0)
			s.parts.append(_part([[0, -22], [3.2, -14], [4.0, -2], [3.0, 9], [1.6, 17], [0, 19.5],
					[-1.6, 17], [-3.0, 9], [-4.0, -2], [-3.2, -14]], b3, 1.2))
			s.parts.append(_part([[0, -18], [1.6, -11], [2.0, 1], [1.4, 12], [0, 15], [-1.4, 12],
					[-2.0, 1], [-1.6, -11]], P.craft(3, 2), 0.85))
			_fin(s.parts, 0, 9, 18.5, 1.5, d3)
			_pair(s.parts, [[6, -3.6], [12, -2], [12.2, 0.6], [6.2, -0.8]], P.craft(3, 3), 0.8)
			s.canopies.append([Vector2(0, -5), 2.4, 5.0])
			s.props.append([Vector2(0, -20), 12.5, 18.0])

		"craft4":
			var b4 := P.craft(4, 0)
			var d4 := P.craft(4, 1)
			_pair(s.parts, [[3.2, -3.4], [18.2, -2.2], [19.4, -1.6], [19.4, 5.2], [18.2, 5.8],
					[3.4, 7.4]], b4, 1.15)
			_pair(s.parts, [[19.0, -4.2], [22.2, -3.2], [22.6, 1.4], [21.4, 6.6], [19.2, 7.2],
					[18.4, 1.6]], d4, 1.0)
			_pair(s.parts, [[2.4, 12.4], [10.2, 12.0], [10.6, 16.2], [2.2, 16.8]], d4, 1.0)
			s.parts.append(_part([[0, -25], [3.0, -19], [4.3, -7], [4.3, 5], [3.4, 15], [2.8, 20],
					[0, 21], [-2.8, 20], [-3.4, 15], [-4.3, 5], [-4.3, -7], [-3.0, -19]], b4, 1.2))
			s.parts.append(_part([[0, -19], [1.7, -13], [2.2, -3], [2.2, 6], [1.6, 15], [0, 18],
					[-1.6, 15], [-2.2, 6], [-2.2, -3], [-1.7, -13]], P.craft(4, 2), 0.85))
			_fin(s.parts, 0, 10, 21.5, 1.7, d4)
			_pair(s.parts, [[8, -2], [16, -1.4], [16, 1.6], [8, 1]], P.craft(4, 3), 0.8)
			s.parts.append(_part(G2.ellipse_pts(Vector2(0, -22.2), 2.7, 2.1, 12),
					Color8(27, 38, 52), 0.9))
			s.canopies.append([Vector2(0, -10), 2.4, 5.4])
			s.flames.append([Vector2(0, 21), 16.0, 4.4, 3.0, P.FLAME_O])

		"craft5":
			var b5 := P.craft(5, 0)
			var d5 := P.craft(5, 1)
			_pair(s.parts, [[4.6, -8], [10.2, -2], [19.4, 9], [23.2, 17.6], [16.8, 19.4],
					[10.6, 12.6], [5.6, 8]], b5, 1.25)
			_pair(s.parts, [[19.4, 9.4], [24.2, 15.6], [22.6, 20.6], [18.2, 16.6]], d5, 1.0)
			_pair(s.parts, [[2.9, -15], [5.4, -14], [7.6, -27.5], [5.2, -29.5], [3.4, -20]], d5, 1.0)
			_pair(s.parts, [[4.8, 0], [9.8, 3.2], [10.2, 15], [8.8, 22], [5.0, 22]], d5, 1.15)
			s.parts.append(_part([[0, -29], [3.0, -17], [4.8, -3], [5.4, 10], [4.4, 20], [0, 23],
					[-4.4, 20], [-5.4, 10], [-4.8, -3], [-3.0, -17]], b5, 1.35))
			s.parts.append(_part([[0, -25], [1.9, -14], [2.5, 4], [1.7, 16], [0, 19], [-1.7, 16],
					[-2.5, 4], [-1.9, -14]], P.craft(5, 2), 0.9))
			_pair(s.parts, [[6.2, 4], [9.2, 5.4], [9.2, 12], [6.2, 11]], P.craft(5, 3), 0.8)
			s.canopies.append([Vector2(0, -10), 2.4, 5.2])
			s.flames.append([Vector2(-7.3, 21), 16.0, 4.2, 7.0, P.FLAME_G])
			s.flames.append([Vector2(7.3, 21), 16.0, 4.2, 11.0, P.FLAME_G])

		"craft6":
			# 붉은 제트기. 삼각날개 + 쌍수직미익이라 앞의 여섯과 실루엣이 안 겹친다.
			# **프로펠러기와 달리 배기 불꽃이 있고 프로펠러가 없다**(제트기 규칙).
			var b6 := P.craft(6, 0)
			var d6 := P.craft(6, 1)
			# 삼각날개 — 뒤로 크게 젖혀진 한 장
			_pair(s.parts, [[3.6, -4], [22.0, 14.0], [24.6, 21.0], [16.0, 21.0],
					[4.6, 10.0]], b6, 1.3)
			_pair(s.parts, [[16.6, 15.0], [23.4, 20.0], [22.0, 22.6], [15.0, 19.0]], d6, 1.0)
			# 쌍수직미익 — 바깥으로 벌어져 선다
			_pair(s.parts, [[4.2, 12.0], [9.6, 8.0], [12.6, 20.0], [6.6, 22.0]], d6, 1.05)
			# 카나드 — 코 옆의 작은 날개
			_pair(s.parts, [[2.8, -16.0], [8.6, -11.0], [9.4, -7.6], [3.4, -9.0]], d6, 0.95)
			# 동체
			s.parts.append(_part([[0, -30], [2.8, -20], [4.6, -6], [5.2, 12], [4.2, 22],
					[0, 24], [-4.2, 22], [-5.2, 12], [-4.6, -6], [-2.8, -20]], b6, 1.35))
			s.parts.append(_part([[0, -26], [1.8, -15], [2.4, 6], [1.6, 18], [0, 21],
					[-1.6, 18], [-2.4, 6], [-1.8, -15]], P.craft(6, 2), 0.9))
			# 날개 밑 미사일 — 이 기체의 축이 무엇인지 그림으로 알린다
			_pair(s.parts, [[10.4, 4.0], [12.8, 5.0], [12.8, 15.0], [10.4, 14.0]],
					P.craft(6, 3), 0.8)
			s.canopies.append([Vector2(0, -12), 2.5, 5.6])
			s.flames.append([Vector2(-2.9, 22), 15.0, 4.0, 5.0, P.FLAME_G])
			s.flames.append([Vector2(2.9, 22), 15.0, 4.0, 9.0, P.FLAME_G])

		"grunt":
			_fy = true
			_pair(s.parts, [[2.6, -5], [11.6, -2.2], [14, 0], [13.4, 3], [2.8, 5.6]], P.OLIVE, 1.0)
			_pair(s.parts, [[1.9, 8], [6.4, 9.8], [6.7, 11.8], [1.7, 12.6]], P.OLIVE_D, 0.9)
			s.parts.append(_part([[0, -16], [2.8, -9], [3.4, 0], [2.4, 9], [0, 13],
					[-2.4, 9], [-3.4, 0], [-2.8, -9]], P.OLIVE, 1.1))
			_fin(s.parts, 0, 5, 12.6, 1.2, P.OLIVE_D)
			s.canopies.append([_v(0, -4), 2.0, 3.6])
			s.props.append([_v(0, -14), 9.0, 21.0])

		"bomber":
			_fy = true
			s.parts.append(_part([[-24, -2.4], [-6, -8.4], [6, -8.4], [24, -2.4], [24, 2.6],
					[6, 8.2], [-6, 8.2], [-24, 2.6]], P.RUST, 1.2))
			_pair(s.parts, [[9, -13], [15, -13], [15.6, 2], [14, 8.4], [10, 8.4], [8.4, 2]],
					P.RUST_D, 1.05)
			s.parts.append(_part([[-12.5, 16.6], [12.5, 16.6], [12.5, 21], [-12.5, 21]],
					P.RUST, 1.1))
			s.parts.append(_part([[0, -24], [4.2, -16], [5.2, -2], [4.4, 12], [2.4, 21], [0, 24],
					[-2.4, 21], [-4.4, 12], [-5.2, -2], [-4.2, -16]], P.RUST, 1.25))
			_fin(s.parts, 10.6, 15.5, 22, 1.5, P.RUST_D)
			_fin(s.parts, -10.6, 15.5, 22, 1.5, P.RUST_D)
			_pair(s.parts, [[17, -1.6], [23, -1.6], [23, 2], [17, 2]], P.FOE_MARK, 0.8)
			s.canopies.append([_v(0, -17.5), 3.0, 4.2])
			s.canopies.append([_v(0, -2), 2.6, 4.0])
			s.props.append([_v(12, -14), 8.4, 18.0])
			s.props.append([_v(-12, -14), 8.4, 18.0])

		"inter":
			_fy = true
			s.parts.append(_part([[0, -15], [13.4, 7], [9, 10.4], [0, 7], [-9, 10.4], [-13.4, 7]],
					P.IRON, 1.15))
			s.parts.append(_part([[0, -17.5], [2.6, -6], [2.9, 6], [0, 10.5], [-2.9, 6],
					[-2.6, -6]], P.IRON_D, 1.1))
			_pair(s.parts, [[3, -1], [9, 4.6], [7.4, 6.4], [2.9, 2.4]], P.FOE_MARK, 0.8)
			_fin(s.parts, 0, -2, 9.5, 1.5, P.IRON_D)
			s.canopies.append([_v(0, -7.5), 1.9, 3.6])
			s.glows.append([_v(0, 12), 8.0])
		"escort":
			_fy = true
			# 호위기 — **전진익.** 날개 끝이 뿌리보다 앞에 있어 잡졸기와 한눈에 갈린다.
			_pair(s.parts, [[2.6, -4], [12.4, -8.5], [14.6, -6.5], [13.4, -2.4],
					[2.8, 4.6]], P.IRON, 1.0)
			_pair(s.parts, [[1.8, 7], [6.2, 8.6], [6.6, 10.8], [1.6, 11.6]], P.IRON_D, 0.9)
			s.parts.append(_part([[0, -15], [2.6, -8], [3.2, 0], [2.2, 8], [0, 12],
					[-2.2, 8], [-3.2, 0], [-2.6, -8]], P.IRON, 1.1))
			_fin(s.parts, 0, 4, 11.6, 1.2, P.IRON_D)
			_pair(s.parts, [[3.4, -3], [8.2, -5], [8.4, -3], [3.6, -1]], P.FOE_MARK, 0.8)
			s.canopies.append([_v(0, -4), 2.0, 3.4])
			s.props.append([_v(0, -13), 9.5, 20.0])

		"gunship":
			_fy = true
			# 중무장기 — 옆구리 무장 포드와 쌍수직미익. 폭격기보다 넓적하고 낮다.
			s.parts.append(_part([[-26, -3.4], [-8, -9.4], [8, -9.4], [26, -3.4], [26, 3.4],
					[8, 9.6], [-8, 9.6], [-26, 3.4]], P.RUST, 1.25))
			_pair(s.parts, [[15.5, -9], [24.5, -9], [25.5, 5], [23, 10], [16.5, 10],
					[14.5, 5]], P.RUST_D, 1.1)
			s.parts.append(_part([[-11, 15.5], [11, 15.5], [11, 19.5], [-11, 19.5]],
					P.RUST, 1.05))
			s.parts.append(_part([[0, -22], [4.6, -14], [5.8, 0], [4.8, 11], [2.6, 18],
					[0, 21], [-2.6, 18], [-4.8, 11], [-5.8, 0], [-4.6, -14]], P.RUST, 1.25))
			_fin(s.parts, 9.4, 14.5, 20.5, 1.4, P.RUST_D)
			_fin(s.parts, -9.4, 14.5, 20.5, 1.4, P.RUST_D)
			_pair(s.parts, [[17, 0], [24, 0], [24, 3.4], [17, 3.4]], P.FOE_MARK, 0.8)
			s.canopies.append([_v(0, -15), 2.8, 4.0])
			s.props.append([_v(11, -10), 9.0, 17.0])
			s.props.append([_v(-11, -10), 9.0, 17.0])

		"midboss":
			_fy = true
			s.parts.append(_part([[-55, -7], [-17, -21], [17, -21], [55, -7], [55, 4.5],
					[17, 17], [-17, 17], [-55, 4.5]], P.NAVY, 1.5))
			_pair(s.parts, [[43, -10.5], [53, -6.5], [53, 3.7], [43, 7.6]], P.HULL_R, 1.0)
			for nx in [18.0, 34.0]:
				_pair(s.parts, [[nx - 5.2, -31], [nx + 5.2, -31], [nx + 5.8, -6],
						[nx + 3.6, 7], [nx - 3.6, 7], [nx - 5.8, -6]], P.NAVY_D, 1.2)
			s.parts.append(_part([[-27, 37], [27, 37], [27, 46], [-27, 46]], P.NAVY, 1.3))
			s.parts.append(_part([[0, -58], [8.4, -44], [10.4, -10], [9.2, 20], [5.4, 44], [0, 53],
					[-5.4, 44], [-9.2, 20], [-10.4, -10], [-8.4, -44]], P.NAVY, 1.5))
			_fin(s.parts, 22, 35, 50, 2.4, P.NAVY_D)
			_fin(s.parts, -22, 35, 50, 2.4, P.NAVY_D)
			s.canopies.append([_v(0, -46), 4.6, 6.4])
			for q in [[0.0, -26.0, 0.0], [13.5, 8.0, 1.2], [-13.5, 8.0, 2.4], [0.0, 32.0, 3.6]]:
				s.turrets.append([_v(q[0], q[1]), 6.4, 1, q[2], P.IRON])
			for nx in [18.0, -18.0, 34.0, -34.0]:
				s.props.append([_v(nx, -32.5), 11.5, 13.0])

		"landfort":
			s.parts.append(_part([[-72, -64], [72, -64], [88, -20], [88, 44], [66, 78],
					[-66, 78], [-88, 44], [-88, -20]], Color8(93, 102, 84), 1.7))
			s.parts.append(_part([[-58, -52], [58, -52], [70, -16], [70, 36], [54, 62],
					[-54, 62], [-70, 36], [-70, -16]], Color8(110, 120, 98), 1.4))
			_pair(s.parts, [[46, -44], [64, -30], [64, -4], [46, -10]], Color8(78, 86, 70), 1.1)
			s.turrets.append([Vector2(-46, 30), 11.0, 2, 0.0, Color8(102, 112, 90)])
			s.turrets.append([Vector2(46, 30), 11.0, 2, 1.6, Color8(102, 112, 90)])

		"carrier":
			s.parts.append(_part([[-132, -72], [132, -72], [146, -40], [146, 58], [126, 86],
					[-126, 86], [-146, 58], [-146, -40]], P.DECK, 1.8))
			s.parts.append(_part([[62, -64], [104, -64], [104, -16], [62, -16]], P.NAVY_D, 1.4))
			s.parts.append(_part([[70, -58], [96, -58], [96, -30], [70, -30]], P.IRON, 1.1))
			s.parts.append(_part([[80, -64], [86, -64], [85, -92], [81, -92]], P.NAVY_D, 1.0))
			for nx in [-70.0, 0.0, 70.0]:
				s.parts.append(_part([[nx-16, -94], [nx+16, -94], [nx+19, -72], [nx-19, -72]],
						P.NAVY_D, 1.2))
				s.props.append([Vector2(nx, -96), 22.0, 11.0])
			s.smokes.append([Vector2(112, -48), 1.1])
			s.parts.append(_part([[105, -55], [119, -55], [118, -41], [106, -41]], P.NAVY_D, 1.1))
			s.turrets.append([Vector2(-108, 40), 10.0, 2, 0.0, P.NAVY])
			s.turrets.append([Vector2(108, 40), 10.0, 2, 2.0, P.NAVY])
			s.turrets.append([Vector2(-108, -46), 10.0, 2, 4.0, P.NAVY])

		"fortress":
			s.parts.append(_part([[-152, -92], [-98, -120], [98, -120], [152, -92], [152, 42],
					[106, 106], [-106, 106], [-152, 42]], Color8(77, 86, 101), 1.9))
			s.parts.append(_part([[-120, -74], [120, -74], [120, 24], [82, 82], [-82, 82],
					[-120, 24]], Color8(92, 103, 119), 1.5))
			for q in [[-124.0, -46.0], [124.0, -46.0], [-96.0, 64.0], [96.0, 64.0]]:
				s.parts.append(_part([[q[0]-19, q[1]-24], [q[0]+19, q[1]-24],
						[q[0]+15, q[1]+24], [q[0]-15, q[1]+24]], Color8(63, 72, 87), 1.4))
			for q in [[-70.0, -96.0, 0.0], [0.0, -104.0, 1.0], [70.0, -96.0, 2.0],
					[-52.0, 92.0, 3.0], [52.0, 92.0, 4.0]]:
				s.turrets.append([Vector2(q[0], q[1]), 12.0, 2, q[2], Color8(89, 99, 122)])
			s.parts.append(_part([[-58, -40], [58, -40], [58, 40], [-58, 40]], Color8(57, 66, 79), 1.6))

		"battleship":
			s.parts.append(_part([[0, 168], [22, 132], [36, 54], [38, -72], [30, -142], [0, -160],
					[-30, -142], [-38, -72], [-36, 54], [-22, 132]], P.NAVY, 1.8))
			s.parts.append(_part([[0, 150], [24, 116], [28, 40], [28, -118], [0, -140],
					[-28, -118], [-28, 40], [-24, 116]], P.DECK, 1.2))
			s.parts.append(_part([[-19, -96], [19, -96], [16, -30], [-16, -30]], P.NAVY_D, 1.3))
			s.parts.append(_part([[-13, -88], [13, -88], [11, -52], [-11, -52]], P.IRON, 1.1))
			s.parts.append(_part([[-2.4, -96], [2.4, -96], [2, -124], [-2, -124]], P.NAVY_D, 1.0))
			s.parts.append(_part([[-9, -118], [9, -118], [9, -114], [-9, -114]], P.NAVY_D, 0.9))
			for sy in [-38.0, -12.0]:
				s.parts.append(_part([[-5, sy - 7], [5, sy - 7], [4.2, sy + 7], [-4.2, sy + 7]],
						P.NAVY_D, 1.1))
				s.smokes.append([Vector2(0, sy - 8), sy * 0.06])
			s.parts.append(_part([[-11, 142], [11, 142], [7, 158], [-7, 158]], P.HULL_R, 1.1))
			s.turrets.append([Vector2(0, 96), 15.0, 3, 0.0, P.NAVY])
			s.turrets.append([Vector2(0, 42), 15.0, 3, 1.0, P.NAVY])
			s.turrets.append([Vector2(0, 12), 12.0, 2, 2.0, P.NAVY])
	_fy = false
	return s

# ==================== 그리기 ====================

static func _xf(p: PackedVector2Array, tf: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(p.size())
	for i in p.size():
		out[i] = tf * p[i]
	return out


static func draw_shape(ci: CanvasItem, key: String, pos: Vector2, t: float,
		sc: float = 1.0, arg: float = 0.0, pdead: int = 0) -> void:
	var s := shape(key)
	ci.draw_set_transform(pos, 0.0, Vector2(sc, sc))
	extra_under(ci, key, t, pdead)
	draw_parts(ci, s.parts)
	extra(ci, key, t, arg, pdead)
	for i in s.turrets.size():
		# 함선은 주포가 곧 부위다 — 부서진 것은 그리지 않고 그을음만 남긴다
		var q: Array = s.turrets[i]
		if key == "battleship" and i < pdead:
			G2.fill_fan(ci, G2.circle_pts(q[0], q[1] * 1.15, 12), Color8(24, 26, 32))
			G2.glow(ci, q[0], q[1] * 2.2, Color8(90, 50, 30), 0.22)
			continue
		nav_turret(ci, q[0], q[1], sin(t * 0.7 + q[3]) * 0.7, q[2], q[4])
	for q in s.smokes:
		_smoke(ci, q[0], t, q[1])
	for q in s.canopies:
		canopy(ci, q[0], q[1], q[2])
	for q in s.glows:
		G2.glow(ci, q[0], q[1], P.FLAME_O, 0.5 + 0.2 * sin(t * 26.0))
	for q in s.props:
		prop(ci, q[0], q[1], t, q[2])
	for q in s.flames:
		jet_flame(ci, q[0], q[1], q[2], t, q[3], q[4])
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _smoke(ci: CanvasItem, c: Vector2, t: float, seed: float) -> void:
	for i in 5:
		var q := fposmod(t * 0.34 + i * 0.2 + seed, 1.0)
		G2.glow(ci, c + Vector2(sin(q * 4.0 + seed) * 11.0, -q * 54.0),
				(7.0 + q * 17.0) * 1.7, Color8(150, 162, 176), 0.2 * (1.0 - q))


static func craft(ci: CanvasItem, idx: int, pos: Vector2, t: float, sc: float = 1.0) -> void:
	draw_shape(ci, "craft%d" % idx, pos, t, sc)


static func enemy(ci: CanvasItem, art: String, pos: Vector2, t: float) -> void:
	draw_shape(ci, art, pos, t, 1.0)

# ==================== 탄 ====================

## 아군 탄. **판정은 `st`, 생김새는 `vfx`** — 둘을 나눠야 모양을 손볼 때 밸런스가 안 흔들린다.
##
## 여섯 기체가 서로 다른 형태를 가져야 화면에서 무엇을 타고 있는지 읽힌다.
## 색만 다르면 탄이 수십 개 깔린 순간 전부 같은 알갱이로 보인다.
static func bullet_ally(ci: CanvasItem, b: Dictionary) -> void:
	var col: Color = b.col
	match b.st:
		"wave":
			_v_moon(ci, b, col)
		"homing":
			G2.glow(ci, b.pos, 10.0, col, 0.5)
			var dir: Vector2 = b.vel.normalized()
			ci.draw_line(b.pos - dir * 5.4, b.pos + dir * 5.4, Color(1, 1, 1), 3.2, true)
		"beam":
			if b.vfx == "cannon":
				_v_cannon(ci, b, col)
			else:
				_v_lance(ci, b, col)
		"missile":
			# 유도탄과 달리 **꼬리를 길게 남긴다.** 버튼으로 낸 것이 화면에서 따로 읽혀야
			# 눌렀는지 안 눌렀는지를 알 수 있다.
			#
			# **`fill_fan` 을 쓰지 않는다.** 스핏파이어 만렙은 미사일이 화면에 마흔 발까지
			# 깔리는데, `fill_fan`(= `canvas_item_add_triangle_array`)은 호출마다 그리기
			# 명령이 따로 생겨 **배칭이 그만큼 끊긴다.** 몸통도 굵은 선 한 줄로 낸다.
			#
			# 지금 이 그림을 쓰는 것은 스킬 「미사일 폭우」 뿐이다. `vfx` 분기는 미사일 층이
			# 있던 시절의 흔적이라 기본값만 탄다.
			var dir: Vector2 = b.vel.normalized()
			var ln := 7.0
			var wd := 3.4
			var tail := 20.0
			match b.vfx:
				"lance":
					ln = 12.0
					wd = 2.6
					tail = 26.0
				"heavy":
					ln = 6.0
					wd = 6.0
					tail = 14.0
				"split":
					ln = 6.0
					wd = 3.0
					tail = 15.0
				"ring":
					ln = 6.5
					wd = 4.2
					tail = 17.0
			ci.draw_line(b.pos - dir * 4.0, b.pos - dir * tail, P.a(col, 0.30), wd * 1.2, true)
			ci.draw_line(b.pos - dir * 4.0, b.pos - dir * (tail * 0.55),
					P.a(P.HOT, 0.55), wd * 0.7, true)
			G2.glow(ci, b.pos, 7.0 + wd * 0.5, col, 0.38)
			ci.draw_line(b.pos - dir * 4.4, b.pos + dir * ln, Color(1, 1, 1), wd, true)
			if b.vfx == "ring":
				# 터지면 고리가 나온다는 것을 미리 알린다.
				ci.draw_arc(b.pos, 6.5, 0.0, TAU, 12, P.a(P.hdr(col, 1.3), 0.55), 1.4, true)
		"spark":
			# 스킬 탄 — 가늘고 길게. 본 사격과 겹쳐 보이면 스킬을 쓴 티가 안 난다.
			var dir2: Vector2 = b.vel.normalized()
			G2.glow(ci, b.pos, 13.0, col, 0.55)
			ci.draw_line(b.pos - dir2 * 13.0, b.pos + dir2 * 7.0, P.a(P.hdr(col, 1.3), 0.8),
					3.6, true)
			ci.draw_line(b.pos - dir2 * 8.0, b.pos + dir2 * 5.0, Color(1, 1, 1, 0.95), 1.5, true)
		_:
			_v_shot(ci, b, col, b.st == "spread")


## 작은 탄 여섯 종. **둥근 것은 `draw_circle`, 곧은 것은 `draw_line`** 으로 그린다 —
## 화면에 수십 개가 깔리므로 `fill_fan` 은 호출마다 그리기 명령이 생겨 배칭이 끊긴다.
## `sub` 는 서브기체가 쏜 것. 본체 탄보다 한 치수 작게 그려 누가 쏜 것인지 읽히게 한다.
static func _v_shot(ci: CanvasItem, b: Dictionary, col: Color, sub: bool = false) -> void:
	var p: Vector2 = b.pos
	var d: Vector2 = b.vel.normalized() if b.vel != Vector2.ZERO else Vector2.UP
	var n := Vector2(-d.y, d.x)
	var k := 0.74 if sub else 1.0
	var hi := P.hdr(col, 1.3)
	match b.vfx:
		"laser":
			# 가늘고 긴 광선. 흰 심이 들어 있어 굵기가 아니라 길이로 읽힌다.
			G2.glow(ci, p, 8.0 * k, col, 0.34)
			ci.draw_line(p - d * 8.0 * k, p + d * 8.0 * k, P.a(hi, 0.62), 3.4 * k, true)
			ci.draw_line(p - d * 6.0 * k, p + d * 7.0 * k, Color(1, 1, 1), 1.5 * k, true)
		"bolt":
			# 지그재그 번개 조각. 곧은 선뿐인 화면에서 혼자 꺾여 있어 눈에 갈린다.
			G2.glow(ci, p, 8.0 * k, col, 0.4)
			var a := p - d * 7.0 * k
			var m := p + n * 2.8 * k
			var z := p + d * 7.0 * k
			ci.draw_line(a, m, P.a(hi, 0.85), 2.4 * k, true)
			ci.draw_line(m, z, Color(1, 1, 1, 0.95), 2.0 * k, true)
		"cannon":
			# 플라즈마 덩어리. 굵고 짧아서 "무겁다" 가 읽힌다.
			G2.glow(ci, p, 11.0 * k, P.HOT, 0.45)
			ci.draw_circle(p, 3.6 * k, P.hdr(col, 1.15))
			ci.draw_circle(p, 1.8 * k, Color(1, 1, 1))
		"dart":
			# 날개 달린 다트. 유도가 축인 기체라 앞이 뾰족한 것이 맞다.
			# **날개는 선 한 줄로 낸다** — 이 기체는 화면에 탄이 제일 많이 깔려서
			# (본 사격 6발 × 짧은 주기 = 예순 발 넘게) 마리당 한 겹이 그대로 배가 된다.
			G2.glow(ci, p, 8.5 * k, col, 0.4)
			ci.draw_line(p - d * 5.0 * k, p + d * 7.0 * k, P.a(hi, 0.9), 2.4 * k, true)
			ci.draw_line(p - (d * 4.0 + n * 3.0) * k, p - (d * 4.0 - n * 3.0) * k,
					P.a(col, 0.7), 1.5 * k, true)
		"star":
			# 네 갈래 반짝임. 편대라 화면에 제일 많이 깔리므로 알갱이가 아니라 무늬로 둔다.
			G2.glow(ci, p, 9.0 * k, col, 0.42)
			ci.draw_line(p - d * 7.0 * k, p + d * 7.0 * k, Color(1, 1, 1, 0.95), 1.7 * k, true)
			ci.draw_line(p - n * 4.2 * k, p + n * 4.2 * k, P.a(hi, 0.8), 1.7 * k, true)
		"needle":
			# 가늘고 긴 기관포탄. 미사일이 굵으니 본 사격은 반대로 가늘어야 둘이 갈린다.
			G2.glow(ci, p, 7.0 * k, col, 0.36)
			ci.draw_line(p - d * 9.0 * k, p + d * 9.0 * k, P.a(hi, 0.75), 2.2 * k, true)
			ci.draw_line(p - d * 6.0 * k, p + d * 8.0 * k, Color(1, 1, 1), 1.1 * k, true)
		"moon":
			# 작은 반달. 큰 파동 고리와 결이 같아 한 기체의 것으로 묶여 보인다.
			var ang := d.angle()
			G2.glow(ci, p, 8.0 * k, col, 0.38)
			ci.draw_arc(p, 4.4 * k, ang - 1.15, ang + 1.15, 12, P.a(hi, 0.9), 2.8 * k, true)
			ci.draw_arc(p, 4.4 * k, ang - 0.7, ang + 0.7, 8, Color(1, 1, 1, 0.9), 1.4 * k, true)
		_:
			G2.glow(ci, p, 9.0 * k, col, 0.45)
			ci.draw_circle(p, 2.6 * k, Color(1, 1, 1))


## 관통 빔 — **레이저.** 흰 심 + 바깥 광채. 하야부사와 「관통 창」이 쓴다.
static func _v_lance(ci: CanvasItem, b: Dictionary, col: Color) -> void:
	var p: Vector2 = b.pos
	var w: float = b.wd
	G2.glow(ci, p, w * 2.3, col, 0.42)
	ci.draw_line(p + Vector2(0, -19.0), p + Vector2(0, 19.0),
			P.a(P.hdr(col, 1.15), 0.62), w, true)
	ci.draw_line(p + Vector2(0, -15.0), p + Vector2(0, 15.0), Color(1, 1, 1),
			maxf(1.5, w * 0.34), true)


## **에너지포** — 커세어의 굵은 기둥. 기둥을 타고 흐르는 고리 두 개가 "쏟아지는 중"을 낸다.
## 그냥 굵은 막대로 두면 폭이 7 → 23px 로 자라도 세진 것이 안 읽힌다.
static func _v_cannon(ci: CanvasItem, b: Dictionary, col: Color) -> void:
	var p: Vector2 = b.pos
	var w: float = b.wd
	G2.glow(ci, p, w * 2.6, P.HOT, 0.5)
	ci.draw_line(p + Vector2(0, -21.0), p + Vector2(0, 21.0),
			P.a(P.hdr(col, 1.1), 0.5), w, true)
	ci.draw_line(p + Vector2(0, -18.0), p + Vector2(0, 18.0),
			P.a(P.hdr(P.HOT, 1.15), 0.72), w * 0.58, true)
	ci.draw_line(p + Vector2(0, -15.0), p + Vector2(0, 15.0), Color(1, 1, 1),
			maxf(1.6, w * 0.24), true)
	# 위상은 탄의 y 로 낸다 — 시간을 넘겨받지 않아도 기둥마다 어긋나서 흐르는 것으로 보인다.
	var ph: float = fposmod(p.y * 0.06, 1.0)
	for i in 2:
		var yy: float = p.y - 18.0 + fposmod(ph + i * 0.5, 1.0) * 36.0
		ci.draw_arc(Vector2(p.x, yy), w * 0.62, 0.0, TAU, 14, Color(1, 1, 1, 0.42), 1.6, true)


## **반달 파동** — 신덴. 나아가는 쪽 호만 굵게 그리고 옆으로 갈수록 얇아진다.
##
## 예전에는 원 두 겹이라 "고리"였지 파동으로 안 보였다. 다만 판정은 여전히 `wd` 크기의
## 상자이므로 **옅은 온 고리를 한 겹 남겨** 어디까지 닿는지는 읽히게 둔다 — 안 그러면
## 반달 바깥에서 맞고도 왜 맞았는지 알 수 없다.
static func _v_moon(ci: CanvasItem, b: Dictionary, col: Color) -> void:
	var p: Vector2 = b.pos
	var r: float = maxf(3.0, b.wd * 0.5)
	var d: Vector2 = b.vel.normalized() if b.vel != Vector2.ZERO else Vector2.UP
	var a0 := d.angle()
	var hi := P.hdr(col, 1.2)
	# **호의 분할 수가 그대로 그리기 비용이다.** 파동은 화면에 열두 개까지 겹치는데
	# 호 하나가 26분할이면 마디마다 사각형이 하나씩 생긴다 — 신덴이 6라운드 최대 물량에서
	# GPU 14.1ms/프레임이던 원인이 여기였다. 반달은 굽이가 완만해서 절반이면 충분하다.
	G2.glow(ci, p, r * 0.9, col, 0.15)
	ci.draw_arc(p, r, 0.0, TAU, 16, P.a(col, 0.22), 1.2, true)          # 닿는 범위
	ci.draw_arc(p, r, a0 - 1.40, a0 + 1.40, 16, P.a(hi, 0.85), 3.6, true)
	ci.draw_arc(p, r, a0 - 1.00, a0 + 1.00, 11, Color(1, 1, 1, 0.8), 1.8, true)
	ci.draw_arc(p, r * 0.82, a0 - 0.62, a0 + 0.62, 8, P.a(hi, 0.45), 2.2, true)


## **전기 기둥**(라이트닝). 기체에서 화면 위까지 곧게 선다.
##
## `off` 는 마디별 좌우 흔들림이고 좌표는 여기서 만든다 — 기체가 움직이면 기둥이
## **통째로 따라와야** 하므로, 좌표를 들고 있으면 매 프레임 밀어 줘야 한다.
##
## 층이 넷이다. 넓은 후광 → 반투명 기둥 → 색 지그재그 → 흰 심.
## **흰 심이 없으면 그냥 번진 띠**로 보이고, 후광이 없으면 종잇장처럼 얇아 보인다.
## 후광은 마디마다 걸지 않고 몇 개 건너 하나만 건다 — 다 걸면 큰 사각형이 열네 장
## 겹쳐서 화면이 통째로 밝아진다.
static func bolt_beam(ci: CanvasItem, off: PackedFloat32Array, root: Vector2,
		top: float, wdt: float, opts: Array, col: Color, t: float) -> void:
	var n := off.size()
	if n < 2 or root.y - top < 6.0:
		return
	var pts := PackedVector2Array()
	pts.resize(n)
	# **짧은 기둥은 거의 곧게.** 흔들림 폭을 길이와 무관하게 두면, 보스에 바짝 붙어
	# 기둥이 한 뼘일 때 심이 구슬 밖으로 삐져나와 흰 가시처럼 보인다.
	var jag: float = clampf((root.y - top) / 260.0, 0.12, 1.0)
	for i in n:
		var y: float = lerpf(root.y, top, float(i) / float(n - 1))
		pts[i] = Vector2(root.x + off[i] * jag, y)
	# **`0—0` 을 한 덩어리로 그린다.** 구슬 — 가는 줄기 — 구슬.
	#
	# 원과 선을 겹쳐 그리는 방식으로는 이음매를 못 없앤다. 겹 비율을 맞춰도 **절대 폭이
	# 다르니** 어느 쪽을 위에 그리든 단이 생긴다 — 줄기를 위에 두면 구슬 심이 가려져
	# 도넛이 되고, 구슬을 위에 두면 금색 고리가 줄기를 가로질러 자르고, 심만 따로 위에
	# 얹으면 열쇠구멍이 된다. 셋 다 같은 원인의 다른 증상이라 순서로는 못 넘는다.
	#
	# 그래서 **겹마다 윤곽선 하나를 폴리곤으로 채운다.** 반지름이 구슬 → 줄기 → 구슬로
	# 이어지는 한 곡선이라 이음매가 존재할 수 없다.
	var pulse := 0.92 + 0.08 * sin(t * 21.0)
	var span: float = root.y - top
	var shaft: float = wdt * 0.15
	var r0: float = wdt * 0.34 * pulse
	for i in n:
		if i % 4 == 0:
			G2.glow(ci, pts[i], shaft * 4.5, col, 0.13)
	# 윤곽을 뜰 높이. 구슬 근처는 촘촘히(둥글게 보이려면), 줄기는 성기게.
	# **구슬 중심을 안쪽으로 옮기고 폴리곤을 끝 바깥까지 늘린다.** 중심이 뿌리에 딱
	# 걸려 있으면 위쪽 절반만 그려져서 **반원**으로 보인다. 뿌리 구슬은 총구보다 조금
	# 아래까지, 끝 구슬은 막은 자리보다 조금 위까지 나가야 온전한 공이 된다.
	var c0: float = r0 * 0.40
	var d0: float = c0 - r0
	var ds := PackedFloat32Array()
	var d := d0
	var far: float = r0 * 1.3
	while d < span:
		ds.append(d)
		d += 2.5 if (d - d0 < far) else 24.0
	ds.append(span)
	# **끝 구체는 몸통보다 먼저 그린다.** 나중에 그리면 몸통 위로 올라와 앞에 붙은 것처럼
	# 보인다 — 먼저 그려야 줄기가 그 위를 지나가면서 구체가 뒤에 있는 것으로 읽힌다.
	if top > 0.0:
		_orb(ci, pts[n - 1], wdt * 0.42 * pulse, col)
	var cols: Array = [P.hdr(col, 1.12), P.hdr(P.GOLD, 1.15), Color(1, 0.99, 0.94)]
	for lay in 3:
		var k: float = LAYER_K[lay]
		var poly := PackedVector2Array()
		for i in ds.size():
			poly.append(Vector2(root.x - _prof(ds[i], c0, r0, shaft) * k,
					root.y - ds[i]))
		for i in range(ds.size() - 1, -1, -1):
			poly.append(Vector2(root.x + _prof(ds[i], c0, r0, shaft) * k,
					root.y - ds[i]))
		ci.draw_colored_polygon(poly, cols[lay])
	# **지그재그는 몸통이 아니라 얹는 심이다.** 채워진 몸통을 꺾으면 윤곽이 스스로
	# 교차해 삼각분할이 깨진다(그러면 조용히 아무것도 안 그려진다).
	ci.draw_polyline(pts, Color(1, 0.99, 0.94, 0.85), maxf(1.4, shaft * 0.5), true)
	# 서브기체가 뿌리로 보내는 기운. **서브기체 수만큼 줄기가 는다** —
	# 대수가 화면에서 읽히는 자리가 여기다(라이트닝 서브기체는 안 쏘므로).
	for o in opts:
		feed(ci, o.pos, root, col, t)


## 기둥의 `d`(뿌리에서의 거리)에서의 반지름. 줄기 굵기에 **양 끝 구슬을 더한다** —
## `shaft + (R - shaft) × 원의 세로 단면` 이라 구슬이 줄기로 매끄럽게 이어진다.
##
## `c0` 는 뿌리 구슬 **중심**이다. 중심을 뿌리에 딱 두면 절반이 잘려 반원으로 보이므로
## 안쪽으로 조금 들여놓고, 폴리곤을 뿌리 바깥까지 뽑아 온전한 공이 되게 한다.
##
## **끝 구슬은 여기 없다** — 줄기가 거기서 끝나 원이 가로지를 일이 없으므로 원 하나로
## 캡을 씌운다(`_orb`). 이음매가 문제였던 것은 **줄기가 원을 통과하는** 뿌리 쪽이다.
##
## 구슬 크기를 비율이 아니라 **px** 로 재는 것이 중요하다. 비율로 재면 기둥이 길수록
## 구슬이 같이 늘어나서 공이 아니라 방추가 된다.
static func _prof(d: float, c0: float, r0: float, shaft: float) -> float:
	if r0 <= shaft:
		return shaft
	var a: float = (d - c0) / r0
	if absf(a) >= 1.0:
		return shaft
	return shaft + (r0 - shaft) * sqrt(1.0 - a * a)


## 구슬과 줄기가 쓰는 **같은** 세 겹 비율. 바깥(기체색) · 금색 · 흰 심.
const LAYER_K := [1.0, 0.62, 0.30]

## 기둥 양 끝의 둥근 구슬. 바깥에서 안으로 기체색 → 금색 → 흰 심 세 겹.
## **줄기보다 먼저** 그린다 — 줄기 심이 구슬을 통과해 이어지게 하려는 것이다.
static func _orb(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	G2.glow(ci, c, r * 1.7, col, 0.30)
	for lay in 3:
		ci.draw_circle(c, r * LAYER_K[lay],
				[P.hdr(col, 1.12), P.hdr(P.GOLD, 1.18), Color(1, 0.99, 0.94)][lay])


## **기둥을 감는 꼬인 밧줄**(라이트닝). 굵은 두 가닥이 서로 감긴다.
##
## 두 가닥은 반 바퀴 어긋난 사인 곡선이라 주기마다 교차한다 —
## `xA = 축 + R·sin(θ)`, `xB = 축 - R·sin(θ)`.
##
## **핵심은 앞뒤다.** 두 가닥을 그냥 겹쳐 그리면 감긴 게 아니라 물결 두 개로 보인다.
## `cos(θ)` 를 깊이로 써서 **뒤에 있는 토막을 먼저, 앞에 있는 토막을 나중에** 그리면
## 교차점마다 앞뒤가 바뀌어 실제로 꼬인 것으로 읽힌다.
##
## 토막은 `draw_multiline` 로 **한 번에** 그린다 — 하나씩 그리면 백 번을 넘는다.
static func coil(ci: CanvasItem, axis: float, y0: float, top: float, col: Color,
		t: float) -> void:
	var span := y0 - top
	if span < 20.0:
		return
	var turns: float = span / D.COIL_PITCH
	var steps := int(turns * D.COIL_SEG)
	if steps < 3:
		return
	var back := PackedVector2Array()
	var front := PackedVector2Array()
	var pa := Vector2.ZERO
	var pb := Vector2.ZERO
	for i in steps + 1:
		var u: float = float(i) / float(D.COIL_SEG)
		# **시간 항은 위상만 돌린다** — 높이는 안 건드리므로 올라가는 게 아니라
		# 제자리에서 빙글빙글 도는 것으로 보인다.
		var th: float = u * TAU + t * D.COIL_W
		var y: float = y0 - u * D.COIL_PITCH
		var dx: float = D.COIL_R * sin(th)
		var depth: float = cos(th)          # + 면 A 가 앞
		var ca := Vector2(axis + dx, y)
		var cb := Vector2(axis - dx, y)
		if i > 0:
			if depth >= 0.0:
				front.append(pa); front.append(ca)
				back.append(pb); back.append(cb)
			else:
				back.append(pa); back.append(ca)
				front.append(pb); front.append(cb)
		pa = ca
		pb = cb
	if back.size() > 1:
		ci.draw_multiline(back, P.a(col, 0.5), D.COIL_WIDE * 0.72)
	if front.size() > 1:
		ci.draw_multiline(front, P.a(P.hdr(col, 1.25), 0.95), D.COIL_WIDE)
		ci.draw_multiline(front, P.a(P.hdr(P.GOLD, 1.2), 0.85), D.COIL_WIDE * 0.38)


## 서브기체에서 기둥 뿌리로 흐르는 기운. **보조기체가 쏘는 게 아니라 보태는 것**이라
## 화면에서도 "흘려보내는" 그림이라야 읽힌다.
static func feed(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, t: float) -> void:
	var k := 0.55 + 0.45 * sin(t * 12.0 + from.x * 0.09)
	ci.draw_line(from, to, P.a(P.hdr(col, 1.2), 0.30 + 0.25 * k), 2.4, true)
	# 흘러가는 알갱이 하나 — 방향이 보여야 "보내는 중" 이 읽힌다.
	G2.glow(ci, from.lerp(to, fposmod(t * 1.6 + from.x * 0.01, 1.0)), 9.0, col, 0.5)


## 총구 섬광. `k` 는 1 에서 0 으로 빠르게 준다.
##
## **기체마다 모양이 다르다** — 탄 모양과 같은 결이라야 "저 기체가 저걸 쏜다"로 묶여 보인다.
## 굵은 기체(커세어)는 반원 불꽃, 가는 기체(하야부사)는 세로 섬광, 나머지는 짧은 갈래.
static func muzzle(ci: CanvasItem, idx: int, pos: Vector2, opts: Array, k: float,
		col: Color) -> void:
	var f: float = k * k
	var hi := P.hdr(col, 1.4)
	var mz := pos + Vector2(0, -18.0)
	match idx:
		2:
			G2.glow(ci, mz, 26.0 * f, P.HOT, 0.6 * f)
			ci.draw_arc(mz, 9.0 + 7.0 * f, PI, TAU, 14, P.a(P.hdr(P.HOT, 1.2), f), 3.4, true)
		0:
			G2.glow(ci, mz, 18.0 * f, col, 0.55 * f)
			ci.draw_line(mz, mz + Vector2(0, -16.0 * f), P.a(Color(1, 1, 1), f), 3.0, true)
		_:
			G2.glow(ci, mz, 16.0 * f, col, 0.5 * f)
			for i in 3:
				var a := -PI * 0.5 + (i - 1.0) * 0.42
				ci.draw_line(mz, mz + Vector2(cos(a), sin(a)) * 13.0 * f, P.a(hi, f),
						2.2, true)
	# 서브기체도 같이 번쩍여야 편대가 한 몸으로 보인다. 여기는 한 겹만 — 대수가 늘면
	# 그만큼 호출이 곱해진다.
	for o in opts:
		G2.glow(ci, o.pos + Vector2(0, -9.0), 10.0 * f, col, 0.45 * f)


## 스킬을 채우는 동안 기체 둘레에 도는 고리. **다 차면 형태가 바뀐다** — 밝기만 올리면
## 탄이 깔린 화면에서 찼는지 안 찼는지가 안 읽힌다.
static func charge_ring(ci: CanvasItem, pos: Vector2, opts: Array, k: float,
		col: Color, t: float) -> void:
	var r := 34.0 - 12.0 * k
	G2.glow(ci, pos, r * 1.5, col, 0.10 + 0.22 * k)
	ci.draw_arc(pos, r, -PI * 0.5, -PI * 0.5 + TAU * k, 34, P.hdr(col, 1.25), 2.2, true)
	# 서브기체가 같이 빨려 들어오는 것처럼 — 스킬을 내는 주체가 서브기체임을 알린다.
	for o in opts:
		ci.draw_line(o.pos, o.pos.lerp(pos, 0.35 * k), P.a(P.hdr(col, 1.2), 0.35 + 0.4 * k),
				1.6, true)
	if k >= 1.0:
		var pk := 0.75 + 0.25 * sin(t * 14.0)
		for i in 6:
			var a := i * TAU / 6.0 - t * 2.4
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(pos + d * (r + 5.0), pos + d * (r + 11.0 * pk),
					P.a(Color(1, 1, 1), 0.85), 2.0, true)


## 스킬이 나가는 동안의 섬광. 기체마다 모양이 달라야 무엇을 썼는지 읽힌다.
static func skill_burst(ci: CanvasItem, idx: int, pos: Vector2, opts: Array, p: float,
		col: Color, t: float) -> void:
	var fade: float = 1.0 - p
	var src: Array = []
	for o in opts:
		src.append(o.pos)
	if src.is_empty():
		src.append(pos + Vector2(0, -12))
	match idx:
		1:
			# 전격망 — 서브기체 사이를 잇는 지그재그
			var pts := PackedVector2Array()
			for j in 9:
				pts.append(Vector2(pos.x + (j - 4.0) * 15.0,
						pos.y - 20.0 + (6.0 if j % 2 == 0 else -6.0)))
			for j in pts.size() - 1:
				ci.draw_line(pts[j], pts[j + 1], P.a(P.hdr(col, 1.4), fade * 0.9), 2.2, true)
		2:
			# 집속 화염 — 서브기체에서 본체로 모이는 줄기
			for s in src:
				ci.draw_line(s, pos + Vector2(0, -14), P.a(P.hdr(P.HOT, 1.3), fade * 0.8),
						3.0 + 2.0 * fade, true)
			G2.glow(ci, pos + Vector2(0, -20), 34.0 * (0.6 + fade), P.HOT, fade * 0.6)
		5:
			# 공명 파동 — 서브기체마다 퍼지는 얇은 고리
			for s in src:
				ci.draw_arc(s, 12.0 + 40.0 * p, 0.0, TAU, 26, P.a(P.hdr(col, 1.3),
						fade * 0.7), 2.0, true)
		_:
			for s in src:
				G2.glow(ci, s + Vector2(0, -10), 22.0, col, fade * 0.55)
				ci.draw_line(s + Vector2(0, -6), s + Vector2(0, -26 - 14.0 * fade),
						P.a(Color(1, 1, 1), fade * 0.8), 2.4, true)


## 적 탄은 색만으로는 부족하다. 검은 테두리 + 맥동하는 경고 고리로 **형태**까지 다르게 한다.
##
## 크기 셋은 **모양도 다르다** — 작은 것은 꼬리를 단 화살, 굵은 것은 고리 두 겹.
## 크기만 바꾸면 화면이 붐빌 때 어느 쪽이 빠른지 못 읽는다.
static func bullet_foe(ci: CanvasItem, pos: Vector2, t: float, sz: int = 1,
		vel: Vector2 = Vector2.ZERO) -> void:
	var k := 0.8 + 0.2 * sin(t * 14.0 + pos.x * 0.3)
	var r: float = D.EB[sz].r
	if sz == 0 and vel != Vector2.ZERO:
		var back := -vel.normalized() * 9.0
		ci.draw_line(pos, pos + back, P.a(P.VENOM, 0.35), 2.4, true)
	ci.draw_circle(pos, r + 1.7, Color(0.03, 0.02, 0.05, 0.9))
	G2.glow(ci, pos, r * 2.5 * k, P.VENOM, 0.5)
	ci.draw_circle(pos, r, P.hdr(P.VENOM, 1.2))
	ci.draw_circle(pos, r * 0.42, P.VENOM_HI)
	if sz >= 1:
		ci.draw_arc(pos, r + 2.6 + 1.8 * k, 0.0, TAU, 18, P.a(P.VENOM, 0.45), 1.0, true)
	if sz == 2:
		ci.draw_arc(pos, r + 7.0 + 2.6 * k, 0.0, TAU, 22, P.a(P.VENOM, 0.28), 1.4, true)
		for i in 4:
			var a := i * TAU / 4.0 + t * 1.6
			ci.draw_line(pos + Vector2(cos(a), sin(a)) * r * 0.5,
					pos + Vector2(cos(a), sin(a)) * (r + 3.0), P.a(P.VENOM_HI, 0.5), 1.4, true)

# ==================== 이펙트 ====================

## 폭발과 **피격 불꽃은 달라야 한다.** 맞히는 것은 초당 수십 번이고 죽는 것은 가끔인데,
## 둘이 같은 주황 불덩이면 화면이 늘 폭발 중이라 정작 뭘 죽였는지가 안 읽힌다.
##
## 피격 쪽은 **때린 탄의 색**으로 튀는 잔불이고 그리기 호출도 세 번뿐이다 —
## 여기가 제일 자주 불리므로 한 겹만 늘려도 비용이 그대로 배가 된다.
static func boom(ci: CanvasItem, pos: Vector2, p: float, size: float,
		kind: String = "kill", col: Color = P.GOLD) -> void:
	var f := 1.0 - p
	if kind == "hit":
		var rr := size * (0.30 + p * 0.85)
		G2.glow(ci, pos, rr * 1.2, col, 0.42 * f)
		ci.draw_arc(pos, rr, 0.0, TAU, 12, P.a(P.hdr(col, 1.35), f * 0.9), 1.8 * f, true)
		ci.draw_circle(pos, 1.6 * f + 0.4, Color(1, 1, 1, f))
		return
	var r := size * (0.22 + p * 1.05)
	G2.glow(ci, pos, r * 1.35, P.HOT, 0.55 * f)
	ci.draw_arc(pos, r, 0.0, TAU, 20, P.a(P.GOLD, f), 2.6 * f, true)
	for i in 7:
		var a := i * TAU / 7.0 + size
		var d := r * (0.55 + 0.75 * p)
		ci.draw_circle(pos + Vector2(cos(a), sin(a)) * d, 2.4 * f + 0.5,
				P.a(Color8(255, 219, 147), f * 0.9))


static func item_power(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var k := absf(sin(t * 2.2))
	G2.glow(ci, pos, 15.0, P.POWER, 0.32 + 0.22 * k)
	var box := G2.poly([[-8, -8], [8, -8], [8, 8], [-8, 8]])
	var moved := _xf(box, Transform2D(0.0, pos))
	G2.fill_fan(ci, moved, Color8(47, 110, 87))
	G2.stroke(ci, moved, P.LINE, 1.2)
	G2.text_mid(ci, pos, "P", 13.0, P.hdr(Color8(196, 255, 226), 1.2))


## 봄 아이템. **P 는 네모, 봄은 고리** — 색만 다르면 화면이 붐빌 때 통째로 묻힌다.
static func item_bomb(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var k := absf(sin(t * 2.6))
	G2.glow(ci, pos, 17.0, P.GOLD, 0.34 + 0.24 * k)
	ci.draw_circle(pos, 9.0, Color8(58, 44, 20))
	ci.draw_arc(pos, 9.0, 0.0, TAU, 20, P.LINE, 1.6, true)
	ci.draw_arc(pos, 6.2, 0.0, TAU, 20, P.hdr(P.GOLD, 1.2), 2.4, true)
	ci.draw_circle(pos, 2.2, Color(1, 1, 1))
	G2.text_mid(ci, pos + Vector2(0, 0.5), "B", 10.0, P.hdr(P.GOLD, 1.1))


## 융단폭격 — 아래에서 위로 폭발이 줄줄이 올라간다. 즉발은 아니지만 세로줄을 통째로 민다.
static func bomb_carpet(ci: CanvasItem, p: float, org: Vector2, w: float) -> void:
	var n := 13
	for i in n:
		var lp := (p - i * 0.055) / 0.34
		var hx := fposmod(sin(i * 127.1) * 43758.5453, 1.0)
		var x := org.x + (hx - 0.5) * w * 0.58
		var y := org.y - 26.0 - i * ((org.y + 30.0) / n)
		if lp > 0.0 and lp < 1.0:
			boom(ci, Vector2(x, y), lp, 30.0 + hx * 16.0)
		elif lp <= 0.0 and lp > -0.5:
			var fy := y + (-lp) * 90.0
			var bombo := _xf(G2.poly([[0, -7], [2.4, -2], [2.4, 5], [0, 8], [-2.4, 5], [-2.4, -2]]),
					Transform2D(0.0, Vector2(x, fy)))
			G2.fill_fan(ci, bombo, Color8(138, 147, 158))
			G2.stroke(ci, bombo, P.LINE, 0.9)

# ==================== 배경 ====================

## 바다. 세로 그라데이션은 띠를 겹쳐 만든다 — 반투명을 겹치면 경계가 보인다.
static func sea(ci: CanvasItem, rect: Rect2, scroll: float) -> void:
	var bands := 14
	for i in bands:
		var t0 := float(i) / bands
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * t0,
				rect.size.x, rect.size.y / bands + 1.0),
				P.SEA_TOP.lerp(P.SEA_BOT, t0), true)
	var h := rect.size.y
	for i in 34:
		var y := fposmod(i * 31.0 + scroll, h + 60.0) - 30.0
		var x := fposmod(i * 137.0, rect.size.x - 50.0) + 12.0
		var len := 14.0 + fposmod(i * 53.0, 26.0)
		ci.draw_line(rect.position + Vector2(x, y), rect.position + Vector2(x + len, y),
				P.a(P.FOAM, 0.13), 1.4, true)


static func island(ci: CanvasItem, c: Vector2, r: float, ph: float) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var a := i * TAU / 11.0
		var rr := r * (0.74 + 0.26 * sin(a * 3.0 + ph))
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.82))
	G2.fill_fan(ci, pts, P.ISLE)
	G2.stroke(ci, pts, P.LINE, 1.4)

# ==================== 봄 6종 ====================

static func _h(i: float) -> float:
	return fposmod(sin(i * 127.1) * 43758.5453, 1.0)


static func bomb(ci: CanvasItem, idx: int, p: float, org: Vector2, w: float, h: float) -> void:
	match idx:
		0: bomb_carpet(ci, p, org, w)
		1: bomb_nuke(ci, p, org, w, h)
		2: bomb_napalm(ci, p, org)
		3: bomb_storm(ci, p, w, h)
		4: bomb_squadron(ci, p, org, 4)
		_: bomb_barrage(ci, p, w, h)


## 핵폭탄 — 섬광 · 충격파 · 버섯구름. 유일하게 화면 끝까지 닿는다.
static func bomb_nuke(ci: CanvasItem, p: float, org: Vector2, w: float, h: float) -> void:
	if p < 0.16:
		ci.draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.97, 0.89, (1.0 - p / 0.16) * 0.9), true)
	var big := sqrt(w * w + h * h)
	var c := Vector2(org.x, org.y - 40.0)
	var f := 1.0 - p
	G2.glow(ci, c, big * 0.5 * minf(1.0, p * 2.4), Color8(255, 217, 138), 0.42 * f)
	ci.draw_arc(c, p * big * 1.05, 0.0, TAU, 44, P.a(Color8(255, 233, 184), f * 0.9),
			12.0 * f + 1.0, true)
	ci.draw_arc(c, p * big * 0.71, 0.0, TAU, 36, P.a(Color8(255, 233, 184), f * 0.5),
			4.0 * f + 1.0, true)
	var top := c.y - minf(1.0, p * 1.7) * (org.y * 0.72)
	for i in 9:
		G2.glow(ci, Vector2(c.x + sin(i * 1.7 + p * 3.0) * 9.0, c.y - i * ((c.y - top) / 9.0)),
				22.0 + i * 1.4, P.HOT, 0.3 * f)
	G2.glow(ci, Vector2(c.x, top), 34.0 + p * 70.0, Color8(255, 196, 107), 0.5 * f)
	G2.glow(ci, Vector2(c.x, top), 20.0 + p * 40.0, Color8(255, 243, 210), 0.45 * f)


## 화염 방사 — 전방 원뿔로 뿜고 잠시 남는다. 즉발이 아니라 지속형.
static func bomb_napalm(ci: CanvasItem, p: float, org: Vector2) -> void:
	var ln := minf(1.0, p * 2.3) * (org.y + 40.0)
	var f := 1.0 if p <= 0.62 else 1.0 - (p - 0.62) / 0.38
	var tw := tan(0.42) * ln
	G2.fill_fan(ci, PackedVector2Array([org + Vector2(-6, 0), org + Vector2(6, 0),
			org + Vector2(tw, -ln), org + Vector2(-tw, -ln)]), Color(1.0, 0.62, 0.24, 0.30 * f))
	for i in 26:
		var q := _h(i)
		var d := fposmod(q + p * 0.9, 1.0) * ln
		var sx := org.x + (_h(i + 31) - 0.5) * 2.0 * tan(0.42) * d
		var rr := 5.0 + q * 11.0 + d * 0.045
		var at := Vector2(sx, org.y - d)
		G2.glow(ci, at, rr * 1.9, P.HOT if i % 3 != 0 else Color8(255, 233, 168), 0.34 * f)
		ci.draw_circle(at, rr * 0.5, P.hdr(Color8(255, 193, 99), 1.15))


## 낙뢰 — 갈라지며 내리꽂힌다. 범위는 넓지만 떨어질 자리를 못 고른다.
static func bomb_storm(ci: CanvasItem, p: float, w: float, h: float) -> void:
	for i in 5:
		var lp := (p - i * 0.1) / 0.42
		if lp <= 0.0 or lp >= 1.0:
			continue
		var f := 1.0 - lp
		var tx := w * (0.14 + _h(i) * 0.72)
		var ty := h * (0.30 + _h(i + 5) * 0.45)
		var pts := PackedVector2Array([Vector2(tx, -10.0)])
		var x := tx
		var y := 0.0
		while y < ty:
			y += 16.0 + _h(i * 13.0 + y) * 14.0
			x += (_h(i * 7.0 + y) - 0.5) * 34.0
			pts.append(Vector2(x, minf(y, ty)))
		ci.draw_polyline(pts, P.a(Color8(143, 212, 240), f * 0.3), 8.0, true)
		ci.draw_polyline(pts, P.a(P.hdr(Color8(207, 230, 255), 1.2), f), 3.4, true)
		var last := pts[pts.size() - 1]
		G2.glow(ci, last, 46.0, Color8(159, 221, 245), 0.55 * f)
		boom(ci, last, minf(1.0, lp * 1.6), 26.0)


## 편대 돌격 — 옵션기들이 앞으로 쏟아져 나가며 지나간 자리를 폭파한다.
static func bomb_squadron(ci: CanvasItem, p: float, org: Vector2, idx: int) -> void:
	for i in 6:
		var lp := (p - i * 0.045) / 0.8
		if lp <= 0.0:
			continue
		var x := org.x + (i - 2.5) * 30.0 + sin(lp * 4.0 + i) * 12.0
		var y := org.y + 20.0 - lp * (org.y + 90.0)
		if lp < 1.0:
			G2.glow(ci, Vector2(x, y + 14.0), 15.0, P.craft(idx, 3), 0.45)
			craft(ci, idx, Vector2(x, y), p * 40.0, 0.62)
		var bp := (p - i * 0.045 - 0.18) / 0.3
		if bp > 0.0 and bp < 1.0:
			boom(ci, Vector2(x + (_h(i) - 0.5) * 24.0, org.y - lp * org.y * 0.8), bp, 26.0)


## 함포 사격 — 표적 고리가 먼저 뜨고 나중에 착탄한다. 늦게 터지는 대신 한 발이 제일 크다.
static func bomb_barrage(ci: CanvasItem, p: float, w: float, h: float) -> void:
	for i in 8:
		var lp := (p - i * 0.05) / 0.72
		if lp <= 0.0 or lp >= 1.0:
			continue
		var at := Vector2(w * (0.12 + _h(i) * 0.76), h * (0.16 + _h(i + 17) * 0.5))
		if lp < 0.5:
			var q := lp / 0.5
			var rr := 52.0 * (1.0 - q) + 12.0
			ci.draw_arc(at, rr, 0.0, TAU, 28, P.a(Color8(232, 123, 107), 0.35 + 0.45 * q),
					1.8, true)
			var shell := _xf(G2.poly([[0, -10], [3.4, -3], [3.4, 7], [0, 11], [-3.4, 7],
					[-3.4, -3]]), Transform2D(0.0, Vector2(at.x, at.y - (1.0 - q) * 150.0)))
			G2.fill_fan(ci, shell, Color8(126, 136, 148))
			G2.stroke(ci, shell, P.LINE, 1.0)
		else:
			var q2 := (lp - 0.5) / 0.5
			G2.glow(ci, at, 54.0 * (1.0 - q2 * 0.3), P.HOT, 0.6 * (1.0 - q2))
			boom(ci, at, q2, 52.0)
			ci.draw_arc(at, 20.0 + q2 * 62.0, 0.0, TAU, 32,
					P.a(Color8(232, 123, 107), (1.0 - q2) * 0.5), 2.4, true)

# ==================== 보스의 움직이는 부분 ====================

## 캐시해 둔 조각을 변환을 걸어 그린다. 도는 고리처럼 **모양은 고정인데 각도만 바뀌는**
## 것에 쓴다 — 매 프레임 그늘을 다시 깎지 않아도 된다.
static func _part_tf(ci: CanvasItem, pt: Dictionary, tf: Transform2D) -> void:
	var f := _xf(pt.fill, tf)
	G2.fill_fan(ci, f, pt.col)
	for s in pt.shade:
		G2.fill_fan(ci, _xf(s, tf), P.SHADE)
	G2.stroke(ci, f, P.LINE, pt.lw)


## 그 자리에서 바로 셀 셰이딩. 변신 로봇처럼 **모양 자체가 매 프레임 바뀌는** 것에만 쓴다.
static func cel_now(ci: CanvasItem, pts, col: Color, lw: float) -> void:
	var p: PackedVector2Array = pts if pts is PackedVector2Array else G2.poly(pts)
	G2.fill_fan(ci, p, col)
	for s in G2.shade_of(p):
		G2.fill_fan(ci, s, P.SHADE)
	G2.stroke(ci, p, P.LINE, lw)


static func tread(ci: CanvasItem, c: Vector2, w: float, h: float, t: float) -> void:
	var box := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(box, Color8(47, 56, 68), true)
	var step := 14.0
	var off := fposmod(t * 42.0, step)
	var y := box.position.y + off
	while y < box.end.y:
		ci.draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y),
				P.a(Color8(158, 174, 190), 0.32), 3.2)
		y += step
	G2.stroke(ci, G2.poly([[box.position.x, box.position.y], [box.end.x, box.position.y],
			[box.end.x, box.end.y], [box.position.x, box.end.y]]), P.LINE, 1.5)
	for q in [box.position.y + 3.0, box.end.y - 3.0]:
		cel_now(ci, [[box.position.x - 2, q - 4], [box.end.x + 2, q - 4],
				[box.end.x + 2, q + 4], [box.position.x - 2, q + 4]], P.NAVY_D, 1.0)


## 보스 몸통 **뒤에** 깔리는 것
static func extra_under(ci: CanvasItem, key: String, t: float, pdead: int = 0) -> void:
	if key == "landfort":
		for i in 2:
			var cx := -84.0 if i == 0 else 84.0
			if i < pdead:
				# 부서진 궤도 — 주저앉아 납작해진다
				cel_now(ci, [[cx - 17, -74], [cx + 17, -74], [cx + 14, 82], [cx - 14, 82]],
						Color8(34, 30, 26), 1.4)
				G2.glow(ci, Vector2(cx, 6), 46.0, Color8(120, 60, 30), 0.2)
				continue
			tread(ci, Vector2(cx, 6), 34.0, 168.0, t)


## 보스 몸통 **위에** 얹히는 것. arg 는 보스가 넘겨주는 값(변신 진행도 등).
static func extra(ci: CanvasItem, key: String, t: float, arg: float, pdead: int = 0) -> void:
	match key:
		"landfort":
			var ma := sin(t * 0.42) * 0.35
			var tf := Transform2D(ma, Vector2(0, -6))
			_xf_cel(ci, [[-26, -26], [26, -26], [22, 26], [-22, 26]], tf, Color8(121, 131, 107), 1.5)
			_xf_cel(ci, [[-8, 10], [8, 10], [7, 104], [-7, 104]], tf, P.IRON, 1.4)
			_xf_cel(ci, [[-11, 96], [11, 96], [10, 112], [-10, 112]], tf, P.NAVY_D, 1.3)
			ci.draw_circle(tf * Vector2.ZERO, 9.0, P.FOE_MARK)
			G2.glow(ci, tf * Vector2(0, 112), 26.0, P.HOT, 0.28 + 0.18 * sin(t * 3.0))
		"carrier":
			ci.draw_line(Vector2(-120, 8), Vector2(120, 8), P.a(P.WHITE, 0.26), 3.0)
			for i in 8:
				var x := -112.0 + i * 30.0
				ci.draw_line(Vector2(x, 8), Vector2(x + 16, 8), P.a(P.VOID, 0.6), 3.4)
			for q in [-34.0, 50.0]:
				ci.draw_line(Vector2(-120, q), Vector2(120, q), P.a(P.WHITE, 0.14), 2.0)
			for i in 4:
				var bx := -84.0 + i * 66.0
				ci.draw_rect(Rect2(bx - 20, 62, 40, 18), Color(0, 0, 0, 0.24), true)
				if i < pdead:
					# 막힌 발진구 — 여기서는 더 안 나온다
					cel_now(ci, [[bx - 21, 60], [bx + 21, 60], [bx + 18, 82], [bx - 18, 82]],
							Color8(28, 26, 30), 1.2)
					continue
				G2.glow(ci, Vector2(bx, 76), 22.0, P.HOT, 0.18 + 0.14 * sin(t * 2.4 + i))
		"disc":
			_disc(ci, t, pdead)
		"robot":
			_robot(ci, t, arg, pdead)
		"fortress":
			_fortress(ci, t, arg, pdead)


static func _xf_cel(ci: CanvasItem, pts, tf: Transform2D, col: Color, lw: float) -> void:
	cel_now(ci, _xf(G2.poly(pts), tf), col, lw)


## 시제 원반기 — 두 겹 고리가 서로 반대로 돈다. 빔 방출구가 고리를 따라 움직여서
## 안전한 자리가 계속 바뀐다.
static func _disc(ci: CanvasItem, t: float, pdead: int = 0) -> void:
	var a1 := t * 0.55
	var a2 := -t * 0.85
	G2.glow(ci, Vector2.ZERO, 150.0, Color8(111, 168, 216), 0.16 + 0.06 * sin(t * 1.4))
	var outer := PackedVector2Array()
	for i in 24:
		var th := i * TAU / 24.0
		var rr := 118.0 + (0.0 if i % 2 else 9.0)
		outer.append(Vector2(cos(th), sin(th)) * rr)
	var tf1 := Transform2D(a1, Vector2.ZERO)
	cel_now(ci, _xf(outer, tf1), Color8(90, 101, 119), 1.8)
	for i in 6:
		var tf := Transform2D(a1 + i * TAU / 6.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, 104))
		var em: Vector2 = tf * Vector2(0, 8)
		if i < pdead:
			_xf_cel(ci, [[-13, -16], [13, -16], [10, 18], [-10, 18]], tf, Color8(34, 36, 42), 1.2)
			G2.glow(ci, em, 18.0, Color8(120, 60, 40), 0.18)
			continue
		_xf_cel(ci, [[-13, -16], [13, -16], [10, 18], [-10, 18]], tf, Color8(69, 79, 94), 1.2)
		G2.glow(ci, em, 22.0, Color8(122, 223, 240), 0.3 + 0.2 * sin(t * 4.0 + i))
		ci.draw_circle(em, 6.4, P.hdr(Color8(122, 223, 240), 1.2))
	var mid := PackedVector2Array()
	for i in 16:
		var th := i * TAU / 16.0
		var rr := 78.0 + (0.0 if i % 2 else -7.0)
		mid.append(Vector2(cos(th), sin(th)) * rr)
	cel_now(ci, _xf(mid, Transform2D(a2, Vector2.ZERO)), Color8(105, 116, 138), 1.5)
	var open := 0.5 + 0.5 * sin(t * 0.8)
	cel_now(ci, G2.circle_pts(Vector2.ZERO, 44.0, 20), Color8(60, 70, 88), 1.6)
	G2.glow(ci, Vector2.ZERO, 60.0 * open + 16.0, P.VENOM, 0.5 * open + 0.12)
	ci.draw_circle(Vector2.ZERO, 26.0 * open + 6.0, P.hdr(P.VENOM, 1.1))
	ci.draw_circle(Vector2.ZERO, 13.0 * open + 3.0, P.VENOM_HI)
	for i in 4:
		var tf := Transform2D(i * TAU / 4.0 + PI * 0.25, Vector2.ZERO)
		_xf_cel(ci, [[-15, -46], [15, -46], [11, -(20.0 + open * 22.0)],
				[-11, -(20.0 + open * 22.0)]], tf, Color8(82, 92, 110), 1.3)


## 변신 로봇 — 비행 형태(m=0)에서 인간형(m=1)으로 관절이 실제로 펴진다.
## 정지 그림 두 장을 바꿔 끼우는 게 아니라 각도와 길이를 보간한다.
static func _robot(ci: CanvasItem, t: float, m: float, pdead: int = 0) -> void:
	m = clampf(m, 0.0, 1.0)
	var leg := lerpf(8.0, 76.0, m)
	for s in [-1.0, 1.0]:
		var tf := Transform2D(s * lerpf(0.62, 0.05, m),
				Vector2(s * lerpf(16.0, 28.0, m), lerpf(28.0, 44.0, m)))
		_xf_cel(ci, [[-14, 0], [14, 0], [12, leg], [-12, leg]], tf, Color8(76, 86, 104), 1.4)
		_xf_cel(ci, [[-16, leg - 8], [16, leg - 8], [19, leg + 15], [-19, leg + 15]], tf,
				Color8(58, 67, 84), 1.3)
	if m < 0.7:
		cel_now(ci, [[0, 84], [19, 44], [-19, 44]], Color8(109, 120, 144), 1.4)
		G2.glow(ci, Vector2(0, 70), 26.0, P.craft(0, 3), 0.3)
	var tw := lerpf(25.0, 45.0, m)
	cel_now(ci, [[-tw, -48], [tw, -48], [tw * 0.94, 46], [-tw * 0.94, 46]], Color8(91, 101, 122), 1.8)
	cel_now(ci, [[-tw * 0.62, -32], [tw * 0.62, -32], [tw * 0.52, 22], [-tw * 0.52, 22]],
			Color8(110, 121, 145), 1.3)
	G2.glow(ci, Vector2(0, -6), 34.0 * (0.5 + m * 0.5), P.FOE_MARK, 0.35 + 0.2 * sin(t * 3.0))
	ci.draw_circle(Vector2(0, -6), 13.0, P.hdr(P.FOE_MARK, 1.15))
	ci.draw_circle(Vector2(0, -6), 6.0, Color8(255, 217, 207))
	for ai in 2:
		var s := -1.0 if ai == 0 else 1.0
		var sh := Transform2D(0.0, Vector2(s * lerpf(32.0, 52.0, m), -28.0))
		_xf_cel(ci, [[-17, -18], [17, -18], [14, 14], [-14, 14]], sh,
				Color8(46, 40, 42) if ai < pdead else Color8(74, 84, 104), 1.4)
		if ai < pdead:
			# 뜯겨 나간 팔 — 어깨만 남아 불꽃이 인다
			G2.glow(ci, sh * Vector2(0, 8), 30.0, Color8(200, 90, 50), 0.26 + 0.12 * sin(t * 9.0))
			continue
		var arm := sh * Transform2D(s * lerpf(-2.35, -0.20, m), Vector2.ZERO)
		var upper := lerpf(104.0, 54.0, m)
		_xf_cel(ci, [[-12, -10], [12, -10], [10, upper], [-10, upper]], arm,
				Color8(83, 93, 114), 1.4)
		var fore := arm * Transform2D(s * lerpf(0.0, 0.2, m), Vector2(0, upper))
		var lower := lerpf(58.0, 42.0, m)
		var tip := lerpf(3.5, 13.0, m)
		_xf_cel(ci, [[-11, 0], [11, 0], [tip, lower], [-tip, lower]], fore, Color8(70, 79, 98), 1.3)
		if m > 0.45:
			cel_now(ci, G2.circle_pts(fore * Vector2(0, lower + 7.0 * m), 14.0 * m, 12),
					Color8(57, 66, 79), 1.2)
	var head := Transform2D(0.0, Vector2(0, lerpf(-26.0, -70.0, m))).scaled(
			Vector2(lerpf(0.34, 1.0, m), lerpf(0.34, 1.0, m)))
	_xf_cel(ci, [[-16, -15], [16, -15], [13, 17], [-13, 17]], head, Color8(96, 107, 129), 1.3)
	_xf_cel(ci, [[-11, -6], [11, -6], [9, 5], [-9, 5]], head, Color8(35, 44, 57), 1.0)
	G2.glow(ci, head * Vector2.ZERO, 22.0, P.FOE_MARK, 0.45 + 0.25 * sin(t * 5.0))
	_xf_cel(ci, [[-9, -3], [9, -3], [8, 2], [-8, 2]], head, Color8(255, 106, 85), 0.7)
	_xf_cel(ci, [[-4, -15], [4, -15], [2, -26], [-2, -26]], head, Color8(96, 107, 129), 1.0)


## 최종 요새 — 발전기 넷이 살아 있는 동안은 가운데 차폐가 닫혀 있다.
static func _fortress(ci: CanvasItem, t: float, open: float, pdead: int = 0) -> void:
	open = clampf(open, 0.0, 1.0)
	for i in 4:
		var q: Vector2 = [Vector2(-124, -46), Vector2(124, -46), Vector2(-96, 64), Vector2(96, 64)][i]
		var alive := i >= pdead
		var k := 0.6 + 0.4 * sin(t * 2.6 + i * 1.7)
		var col := Color8(99, 231, 200) if alive else Color8(70, 78, 92)
		G2.glow(ci, q, 34.0, col, (0.38 if alive else 0.1) * k)
		ci.draw_circle(q, 9.0, P.hdr(col, 1.2) if alive else col)
		ci.draw_circle(q, 4.0, Color8(223, 255, 246) if alive else col)
	G2.glow(ci, Vector2.ZERO, 74.0 * open + 14.0, P.FOE_MARK, 0.55 * open + 0.1)
	ci.draw_circle(Vector2.ZERO, 30.0 * open + 5.0, P.hdr(Color8(255, 90, 70), 1.1))
	ci.draw_circle(Vector2.ZERO, 15.0 * open + 2.0, Color8(255, 224, 210))
	for s in [-1.0, 1.0]:
		var tf := Transform2D(0.0, Vector2(s * open * 46.0, 0))
		_xf_cel(ci, [[s * 2, -42], [s * 46, -42], [s * 46, 42], [s * 2, 42]], tf,
				Color8(103, 114, 138), 1.5)

# ==================== 지형 ====================
#
# **타일로 짠다.** 그라데이션 위에 선 몇 개를 흘리면 구조가 없어서 어디를 봐도 같아 보인다.
# 땅을 값 잡음으로 **덩어리지게** 만들고, 종류가 바뀌는 경계에만 빛과 그늘을 넣으면
# 블록에 두께가 생기고 해안선이 생긴다. 격자 전체에 테두리를 두르면 그냥 모눈종이가 된다.

## **타일은 촘촘해야 지형으로 보인다.** 32px 로 두면 384 폭에 12칸뿐이라
## 그냥 큰 사각형이 깔린 것처럼 보인다. 12px 면 32칸이라 해안선이 선으로 읽힌다.
## 이 값을 바꾸면 아래 `scale` 도 같은 비율로 바꿔야 덩어리 크기가 유지된다.
const TILE := 12.0

## 라운드마다 타일 네 종. cut 이 값 잡음을 나누는 문턱.
## **배경은 조용해야 한다.** 탄이 흰색·옥색이라 바닥이 밝으면 통째로 묻힌다.
## 그래서 네 종류가 다 어둡고, 서로의 차이도 크지 않다 — 구조만 읽히면 충분하다.
## `scale` 이 작을수록 덩어리가 커진다. 0.3 근처면 자잘해져서 섬이 아니라 잡음으로 보인다.
const LAND := {
	sea = {seed = 11, scale = 0.058, cut = [0.60, 0.705, 0.775],
		col = [Color8(9, 20, 35), Color8(14, 32, 52), Color8(62, 58, 40), Color8(34, 50, 31)]},
	shore = {seed = 23, scale = 0.064, cut = [0.38, 0.58, 0.745],
		col = [Color8(48, 43, 30), Color8(60, 54, 37), Color8(43, 46, 30), Color8(40, 38, 36)]},
	city = {seed = 37, scale = 0.071, cut = [0.40, 0.58, 0.735],
		col = [Color8(15, 16, 24), Color8(20, 22, 32), Color8(23, 32, 28), Color8(31, 34, 47)]},
	steel = {seed = 53, scale = 0.062, cut = [0.40, 0.60, 0.78],
		col = [Color8(23, 25, 31), Color8(30, 33, 40), Color8(37, 41, 50), Color8(48, 41, 30)]},
	desert = {seed = 67, scale = 0.082, cut = [0.40, 0.60, 0.775],
		col = [Color8(45, 40, 28), Color8(56, 50, 34), Color8(49, 48, 31), Color8(40, 37, 33)]},
}

static var _rows := {}


static func _hash2(x: int, y: int, sd: int) -> float:
	var n := x * 374761393 + y * 668265263 + sd * 1274126177
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


## 값 잡음. 타일마다 난수를 뽑으면 소금후추가 되어 덩어리가 안 생긴다 —
## 성긴 격자점에 해시를 뿌리고 사이를 부드럽게 이어야 땅처럼 보인다.
static func _noise(fx: float, fy: float, sd: int) -> float:
	var x0 := floori(fx)
	var y0 := floori(fy)
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := lerpf(_hash2(x0, y0, sd), _hash2(x0 + 1, y0, sd), tx)
	var b := lerpf(_hash2(x0, y0 + 1, sd), _hash2(x0 + 1, y0 + 1, sd), tx)
	return lerpf(a, b, ty)


## 한 줄(절대 행 번호)의 타일 종류. 스크롤이 느려 대부분 다시 쓰이므로 캐시한다.
static func _row(kind: String, gy: int, cols: int) -> PackedByteArray:
	var key := "%s|%d|%d" % [kind, gy, cols]
	if _rows.has(key):
		return _rows[key]
	var L: Dictionary = LAND[kind]
	var out := PackedByteArray()
	out.resize(cols)
	for cx in cols:
		var v := _noise(cx * L.scale, gy * L.scale, L.seed)
		v = v * 0.82 + _noise(cx * L.scale * 2.8, gy * L.scale * 2.8, L.seed + 7) * 0.18
		var ti := 0
		for c in L.cut:
			if v > c:
				ti += 1
		out[cx] = ti
	if _rows.size() > 2400:
		_rows.clear()
	_rows[key] = out
	return out


static func terrain(ci: CanvasItem, kind: String, w: float, h: float, scroll: float,
		t: float) -> void:
	if kind == "cloud":
		_sky(ci, w, h, scroll, t)
		return
	if kind == "desert":
		_desert(ci, w, h, scroll, t)
		return

	var L: Dictionary = LAND[kind]
	var cols := int(ceil(w / TILE)) + 1
	var row0 := floori(-scroll / TILE)
	var nrows := int(ceil(h / TILE)) + 2
	# **같은 종류가 이어지는 구간은 한 번에 그린다.** 타일 하나씩 그리면 한 프레임에
	# 이천 번을 호출하게 되고, 이 게임에서 프레임을 먹는 건 GDScript→엔진 호출 횟수다.
	var prev := _row(kind, row0 - 1, cols)
	for ry in nrows:
		var gy := row0 + ry
		var py := gy * TILE + scroll
		var cur := _row(kind, gy, cols)
		var cx := 0
		while cx < cols:
			var ti := cur[cx]
			var run := 1
			while cx + run < cols and cur[cx + run] == ti:
				run += 1
			var px := cx * TILE
			var col: Color = L.col[ti]
			ci.draw_rect(Rect2(px, py, TILE * run + 1.0, TILE + 1.0), col, true)
			# **경계에만** 빛과 그늘 — 여기서 두께가 생긴다
			var e := 0
			while e < run:
				var up := prev[cx + e]
				if up != ti:
					var wlen := 1
					while e + wlen < run and prev[cx + e + wlen] == up:
						wlen += 1
					ci.draw_rect(Rect2(px + e * TILE, py, TILE * wlen + 1.0, 1.6),
							col.lightened(0.36) if up < ti else col.darkened(0.48), true)
					e += wlen
				else:
					e += 1
			if cx > 0:
				ci.draw_rect(Rect2(px, py, 1.6, TILE + 1.0),
						col.lightened(0.22) if cur[cx - 1] < ti else col.darkened(0.35), true)
			cx += run
		prev = cur
	_detail(ci, kind, w, h, scroll, t, cols, row0, nrows)


## 지형마다 얹히는 것 — 파도 마루, 길, 건물 지붕, 판 이음매.
## 타일만으로는 "무엇이 있는 곳"인지가 안 읽힌다.
##
## **타일이 촘촘해지면 잔무늬 확률도 같이 낮춰야 한다.** 타일당 하나씩 찍으면
## 화면에 수백 개가 깔려서 지형이 아니라 노이즈가 된다.
static func _detail(ci: CanvasItem, kind: String, w: float, h: float, scroll: float,
		t: float, cols: int, row0: int, nrows: int) -> void:
	match kind:
		"sea":
			# 물 타일 위에만 잔물결. 육지 위에 물결이 뜨면 바로 가짜로 보인다.
			for ry in nrows:
				var gy := row0 + ry
				var cur := _row(kind, gy, cols)
				for cx in cols:
					if cur[cx] > 1 or _hash2(cx, gy, 5) < 0.962:
						continue
					var px := cx * TILE
					var py := gy * TILE + scroll + TILE * 0.5
					ci.draw_line(Vector2(px, py), Vector2(px + 13.0, py),
							P.a(P.FOAM, 0.20), 1.4, true)
		"shore":
			# 세로로 난 길 — 이어져 있어야 길로 읽힌다
			var rx := w * 0.5 + sin(scroll * 0.0016) * w * 0.22
			ci.draw_rect(Rect2(rx - 26, 0, 52, h), Color8(52, 48, 41), true)
			ci.draw_rect(Rect2(rx - 27, 0, 2, h), Color8(88, 82, 68), true)
			ci.draw_rect(Rect2(rx + 25, 0, 2, h), Color8(34, 31, 26), true)
			var dy := fposmod(scroll, 44.0)
			while dy < h:
				ci.draw_rect(Rect2(rx - 1.5, dy, 3, 18), P.a(Color8(190, 178, 132), 0.45), true)
				dy += 44.0
		"desert":
			# 사구 능선 — 길게 누운 호가 있어야 모래로 읽힌다
			for i in 14:
				var y := fposmod(i * 82.0 + scroll * 0.9, h + 200.0) - 100.0
				ci.draw_arc(Vector2(fposmod(i * 197.0, w + 120.0) - 60.0, y + 46.0), 96.0,
						PI * 1.14, PI * 1.86, 20, P.a(Color8(146, 128, 88), 0.13), 2.6, true)
			for ry in nrows:
				var gy := row0 + ry
				var cur := _row(kind, gy, cols)
				for cx in cols:
					if cur[cx] != 3 or _hash2(cx, gy, 43) < 0.86:
						continue
					var px := cx * TILE + 6.0
					var py := gy * TILE + scroll + 6.0
					cel_now(ci, [[px - 7, py + 4], [px - 4, py - 5], [px + 4, py - 6],
							[px + 7, py + 4]], Color8(58, 53, 45), 1.0)
		"city":
			for ry in nrows:
				var gy := row0 + ry
				var cur := _row(kind, gy, cols)
				var above := _row(kind, gy - 1, cols)
				for cx in cols:
					if cur[cx] != 3:
						continue
					var px := cx * TILE
					var py := gy * TILE + scroll
					if above[cx] != 3:
						# 덩어리의 북쪽 면만 밝게 — 이것만으로 건물에 높이가 생긴다
						ci.draw_rect(Rect2(px, py - 3.0, TILE + 1.0, 4.0),
								Color8(78, 86, 112), true)
					if _hash2(cx, gy, 13) > 0.80:
						ci.draw_rect(Rect2(px + 3.0, py + 4.0, 5, 4),
								P.a(P.GOLD, 0.22 + 0.5 * _hash2(cx, gy, 17)), true)
		_:
			# 강철 — 넉 줄마다 판 이음매, 드문드문 리벳, 그리고 흐르는 도관
			for ry in nrows:
				var gy := row0 + ry
				if gy % 4 == 0:
					var py := gy * TILE + scroll
					ci.draw_line(Vector2(0, py), Vector2(w, py),
							P.a(Color8(14, 16, 21), 0.55), 1.6)
				for cx in cols:
					if _hash2(cx, gy, 29) < 0.965:
						continue
					ci.draw_circle(Vector2(cx * TILE + 4.0, gy * TILE + scroll + 4.0), 1.2,
							P.a(Color8(150, 158, 178), 0.35))
			for i in 3:
				var lx := w * (i + 0.5) / 3.0 - 3.0
				ci.draw_rect(Rect2(lx, 0, 6, h), Color8(52, 40, 24), true)
				var gy2 := fposmod(scroll * 1.9 + i * 220.0, h + 220.0) - 110.0
				G2.glow(ci, Vector2(lx + 3.0, gy2), 34.0, Color8(255, 140, 70), 0.22)
				ci.draw_rect(Rect2(lx, gy2 - 22, 6, 44), P.a(Color8(255, 150, 80), 0.55), true)


## 구름 위 — 두 층으로 흘려 깊이를 낸다. 아래층은 크고 느리고 어둡다.
static func _sky(ci: CanvasItem, w: float, h: float, scroll: float, t: float) -> void:
	_band(ci, w, h, Color8(38, 62, 102), Color8(14, 26, 44))
	for layer in 2:
		var k := 1.0 if layer == 0 else 1.9
		var rr := 74.0 if layer == 0 else 44.0
		var col := Color8(52, 74, 112) if layer == 0 else Color8(120, 146, 184)
		for i in 9:
			var gy := fposmod(i * 118.0 + scroll * k * 0.55 + layer * 61.0, h + 320.0) - 160.0
			var gx := fposmod(i * 173.0 + layer * 89.0, w + 120.0) - 60.0
			for b in 5:
				var a := b * TAU / 5.0 + i
				var c := Vector2(gx + cos(a) * rr * 0.62, gy + sin(a) * rr * 0.34)
				ci.draw_circle(c, rr * (0.52 + 0.18 * sin(a * 2.0 + i)), col)
			# 위쪽 가장자리만 밝게 — 구름에 부피가 생긴다
			ci.draw_circle(Vector2(gx, gy - rr * 0.24), rr * 0.5, col.lightened(0.22))


static func _band(ci: CanvasItem, w: float, h: float, top: Color, bot: Color) -> void:
	var bands := 14
	for i in bands:
		var q := float(i) / bands
		ci.draw_rect(Rect2(0, h * q, w, h / bands + 1.0), top.lerp(bot, q), true)


## 지형 위에 얹힌 큰 것. 라운드마다 종류가 다르다.
static func scenery(ci: CanvasItem, kind: String, c: Vector2, r: float, ph: float) -> void:
	match kind:
		"cloud":
			for i in 5:
				var a := i * TAU / 5.0 + ph
				G2.glow(ci, c + Vector2(cos(a), sin(a) * 0.6) * r * 0.5, r * 1.1,
						Color8(176, 200, 226), 0.13)
			return
		"strato":
			return
	var pts := PackedVector2Array()
	var n := 11
	var col := P.ISLE
	match kind:
		"shore": col = Color8(96, 86, 60)
		"city": col = Color8(34, 38, 56); n = 4
		"steel": col = Color8(52, 58, 72); n = 4
	for i in n:
		var a := i * TAU / n + (PI * 0.25 if n == 4 else 0.0)
		var rr := r * (0.74 + 0.26 * sin(a * 3.0 + ph)) if n > 4 else r
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.82))
	G2.fill_fan(ci, pts, col)
	G2.stroke(ci, pts, P.LINE, 1.4)
	if kind == "city":
		# 불 켜진 창
		for i in 9:
			var wx := c.x - r * 0.42 + (i % 3) * r * 0.34
			var wy := c.y - r * 0.4 + floorf(i / 3.0) * r * 0.34
			ci.draw_rect(Rect2(wx, wy, r * 0.14, r * 0.18),
					P.a(P.GOLD, 0.30 + 0.45 * fposmod(i * 7.0 + ph, 1.0)), true)
	elif kind == "steel":
		ci.draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.18, r, r * 0.36),
				P.a(Color8(255, 140, 70), 0.35), true)

# ==================== 지상 유닛 ====================

## 스스로 날지 않고 지형에 붙어 흘러가는 것들. **포신이 실제로 플레이어를 겨눈다** —
## 겨누는 게 보여야 "지나가기 전에 처리할지 피할지"를 고를 수 있다.
## 거치 유닛이 **무엇 위에 얹혀 있는가.** 전차가 성층권에 떠 있으면 바로 가짜로 보인다 —
## 그렇다고 그 웨이브를 통째로 빼면 하늘 라운드 둘만 조용해져서 난이도 검산이 깨진다.
## 그래서 **받침만 지형에 맞게 바꾼다** — 바다는 부선, 하늘은 부유 포대.
static func _mount(ci: CanvasItem, c: Vector2, base: String, t: float) -> void:
	match base:
		"land":
			# **접지 그림자.** 속도가 맞아도 그림자가 없으면 배경 위에 떠 보인다.
			# 빛은 셀 셰이딩과 같은 왼쪽 위에서 오므로 그림자는 오른쪽 아래로 눕는다.
			G2.fill_fan(ci, G2.ellipse_pts(c + Vector2(6.0, 7.0), 21.0, 13.0, 14),
					Color(0.02, 0.015, 0.01, 0.34))
		"sea":
			# 배. 아래로 흘러가므로 **뱃머리가 +y**, 물살은 뒤(-y)로 남는다.
			for i in 3:
				var q := fposmod(t * 0.7 + i * 0.33, 1.0)
				ci.draw_arc(c + Vector2(0, -24.0 - q * 22.0), 15.0 + q * 16.0,
						PI * 1.18, PI * 1.82, 14, P.a(P.FOAM, 0.26 * (1.0 - q)), 2.0, true)
			cel_now(ci, [[c.x - 13, c.y - 22], [c.x + 13, c.y - 22], [c.x + 15, c.y + 6],
					[c.x + 9, c.y + 22], [c.x, c.y + 28], [c.x - 9, c.y + 22],
					[c.x - 15, c.y + 6]], Color8(56, 60, 68), 1.5)
			cel_now(ci, [[c.x - 9, c.y - 18], [c.x + 9, c.y - 18], [c.x + 10, c.y + 4],
					[c.x - 10, c.y + 4]], Color8(72, 78, 88), 1.1)
			cel_now(ci, [[c.x - 5, c.y - 16], [c.x + 5, c.y - 16], [c.x + 4, c.y - 6],
					[c.x - 4, c.y - 6]], Color8(96, 104, 116), 1.0)
			ci.draw_line(Vector2(c.x, c.y - 22), Vector2(c.x, c.y - 34),
					P.a(Color8(120, 128, 142), 0.8), 1.6, true)
			ci.draw_line(Vector2(c.x - 15, c.y + 4), Vector2(c.x + 15, c.y + 4),
					P.a(P.FOAM, 0.22), 1.4, true)
		"air":
			cel_now(ci, G2.circle_pts(c, 20.0, 12), Color8(50, 55, 66), 1.4)
			cel_now(ci, G2.circle_pts(c, 13.0, 10), Color8(64, 70, 84), 1.1)
			for i in 4:
				var a := i * TAU / 4.0 + PI * 0.25
				var q := c + Vector2(cos(a), sin(a)) * 19.0
				G2.glow(ci, q, 13.0, Color8(120, 200, 255), 0.30 + 0.16 * sin(t * 7.0 + i))
				ci.draw_circle(q, 3.4, P.hdr(Color8(150, 215, 255), 1.15))


static func ground_unit(ci: CanvasItem, art: String, c: Vector2, aim: float, t: float,
		base: String = "land") -> void:
	_mount(ci, c, base, t)
	match art:
		"turret":
			var oct := PackedVector2Array()
			for i in 8:
				var th := i * TAU / 8.0 + PI / 8.0
				oct.append(c + Vector2(cos(th), sin(th)) * 13.5)
			cel_now(ci, oct, P.IRON_D, 1.2)
			var tf := Transform2D(aim - PI * 0.5, c)
			_xf_cel(ci, [[-3.6, -2], [3.6, -2], [3.0, 19], [-3.0, 19]], tf, P.IRON, 1.05)
			_xf_cel(ci, [[-4.6, 19], [4.6, 19], [4.2, 22.5], [-4.2, 22.5]], tf, P.IRON_D, 1.0)
			cel_now(ci, G2.circle_pts(c, 8.4, 14), P.IRON, 1.2)
			ci.draw_circle(c, 3.4, P.hdr(P.FOE_MARK, 1.1))
		"tank":
			for s in [-1.0, 1.0]:
				var bx: float = c.x + s * 14.0
				if base == "air":
					# 하늘에는 궤도가 없다. 같은 실루엣에 부양 포드를 단다.
					cel_now(ci, [[bx - 5.0, c.y - 13], [bx + 5.0, c.y - 13],
							[bx + 6.0, c.y + 13], [bx - 6.0, c.y + 13]], Color8(62, 68, 82), 1.2)
					G2.glow(ci, Vector2(bx, c.y + 12), 12.0, Color8(120, 200, 255), 0.28)
					continue
				ci.draw_rect(Rect2(bx - 5.5, c.y - 17, 11, 34), Color8(44, 50, 40), true)
				for k in 6:
					var yy := c.y - 17.0 + fposmod(k * 6.0 + t * 26.0, 34.0)
					ci.draw_line(Vector2(bx - 5.5, yy), Vector2(bx + 5.5, yy),
							P.a(Color8(150, 160, 130), 0.3), 2.0)
				G2.stroke(ci, G2.poly([[bx - 5.5, c.y - 17], [bx + 5.5, c.y - 17],
						[bx + 5.5, c.y + 17], [bx - 5.5, c.y + 17]]), P.LINE, 1.2)
			cel_now(ci, [[c.x - 12, c.y - 15], [c.x + 12, c.y - 15], [c.x + 14, c.y + 12],
					[c.x - 14, c.y + 12]], Color8(104, 114, 88), 1.4)
			var tf2 := Transform2D(aim - PI * 0.5, c)
			_xf_cel(ci, [[-8, -8], [8, -8], [7, 8], [-7, 8]], tf2, Color8(122, 132, 102), 1.3)
			_xf_cel(ci, [[-2.6, 6], [2.6, 6], [2.2, 26], [-2.2, 26]], tf2, P.IRON, 1.1)
			ci.draw_circle(c, 3.0, P.hdr(P.FOE_MARK, 1.1))
		_:
			# 미사일탑 — 세로로 길어 실루엣이 전차와 안 겹친다
			cel_now(ci, [[c.x - 15, c.y + 6], [c.x + 15, c.y + 6], [c.x + 12, c.y + 17],
					[c.x - 12, c.y + 17]], P.IRON_D, 1.3)
			cel_now(ci, [[c.x - 7, c.y - 14], [c.x + 7, c.y - 14], [c.x + 9, c.y + 8],
					[c.x - 9, c.y + 8]], Color8(96, 106, 122), 1.3)
			var tf3 := Transform2D((aim - PI * 0.5) * 0.45, c + Vector2(0, -14))
			_xf_cel(ci, [[-11, -6], [11, -6], [9, 7], [-9, 7]], tf3, Color8(120, 130, 148), 1.2)
			for s in [-1.0, 1.0]:
				_xf_cel(ci, [[s * 3.0, -6], [s * 8.0, -6], [s * 6.5, -15], [s * 4.5, -15]],
						tf3, P.FOE_MARK, 1.0)
			G2.glow(ci, c + Vector2(0, -14), 16.0, P.FOE_MARK, 0.2 + 0.16 * sin(t * 3.4))

# ==================== 사막 ====================
#
# **표면 무늬가 없으면 색면이지 지형이 아니다.** 모래는 지그재그 물결로 전체를 덮고,
# 돌 포장은 벽돌 줄눈으로 덮는다. 타일마다 무늬를 그리면 프레임당 천 번을 호출하게 되므로
# **작은 무늬 텍스처를 만들어 한 번에 깐다**(draw_texture_rect 의 tile=true).
#
# 그 위에 지물(피라미드 · 야자수 · 기둥 · 바위)을 성긴 격자에 해시로 놓는다.
# 무늬만 있고 지물이 없으면 여전히 "어디를 봐도 같은 곳"이 된다.

const CELL := 128.0
static var _tex := {}


static func _pattern(key: String) -> ImageTexture:
	if _tex.has(key):
		return _tex[key]
	var size := 24 if key == "ripple" else 12
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wht := Color(1, 1, 1, 1)
	match key:
		"ripple":
			# 모래 물결 — 지그재그 두 줄이 엇갈려 눕는다
			for x in 24:
				var d := absi(((x + 6) % 12) - 6)
				img.set_pixel(x, 4 + d, wht)
				img.set_pixel(x, 16 + d, wht)
		_:
			# 돌 줄눈. **타일 크기(12)의 약수여야** 어느 칸에서 깔아도 줄이 맞는다.
			for x in 12:
				img.set_pixel(x, 0, wht)
			for y in 12:
				img.set_pixel(0, y, wht)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static func _desert(ci: CanvasItem, w: float, h: float, scroll: float, t: float) -> void:
	var off := fposmod(scroll, 24.0)
	var full := Rect2(0, off - 24.0, w, h + 24.0)
	var cols := int(ceil(w / TILE)) + 1
	var row0 := floori(-scroll / TILE)
	var nrows := int(ceil(h / TILE)) + 2

	# 1) 모래 바탕과 그늘진 모래를 먼저 깔고
	ci.draw_rect(Rect2(0, 0, w, h), Color8(124, 97, 55), true)
	for ry in nrows:
		var gy := row0 + ry
		var py := gy * TILE + scroll
		var cur := _row("desert", gy, cols)
		var cx := 0
		while cx < cols:
			var ti := cur[cx]
			var run := 1
			while cx + run < cols and cur[cx + run] == ti:
				run += 1
			if ti == 1:
				ci.draw_rect(Rect2(cx * TILE, py, TILE * run + 1.0, TILE + 1.0),
						Color8(104, 80, 45), true)
			cx += run
	# 2) **물결은 모래 전체에 한 번에** — 그늘진 데만 판판하면 얼룩으로 보인다
	ci.draw_texture_rect(_pattern("ripple"), full, true, Color(1, 1, 1, 0.17))

	# 3) 그 위에 돌 포장과 바위
	for ry in nrows:
		var gy := row0 + ry
		var py := gy * TILE + scroll
		var cur := _row("desert", gy, cols)
		var above := _row("desert", gy - 1, cols)
		var cx := 0
		while cx < cols:
			var ti := cur[cx]
			var run := 1
			while cx + run < cols and cur[cx + run] == ti:
				run += 1
			if ti > 1:
				var col := Color8(146, 126, 90) if ti == 2 else Color8(112, 96, 68)
				var box := Rect2(cx * TILE, py, TILE * run + 1.0, TILE + 1.0)
				ci.draw_rect(box, col, true)
				if ti == 2:
					# **줄눈은 포장 구간에만.** 한 덩어리로 덮으면 모래 위까지 격자가 깔린다.
					ci.draw_texture_rect(_pattern("brick"), box, true, Color(0, 0, 0, 0.20))
				if above[cx] != ti:
					ci.draw_rect(Rect2(cx * TILE, py, TILE * run + 1.0, 1.6),
							col.lightened(0.30), true)
			cx += run
	_props(ci, w, h, scroll, t)


## 지물 — 성긴 격자에 해시로 놓는다. 같은 자리에는 늘 같은 것이 있어야 한다.
static func _props(ci: CanvasItem, w: float, h: float, scroll: float, t: float) -> void:
	var r0 := floori((-scroll - CELL) / CELL)
	var rn := int(ceil(h / CELL)) + 2
	var ccols := int(ceil(w / CELL)) + 1
	for ry in rn:
		var gy := r0 + ry
		for cx in ccols:
			var pick := _hash2(cx, gy, 71)
			if pick < 0.42:
				continue
			var c := Vector2(cx * CELL + _hash2(cx, gy, 73) * (CELL - 40.0) + 20.0,
					gy * CELL + scroll + _hash2(cx, gy, 79) * (CELL - 40.0) + 20.0)
			if c.y < -110.0 or c.y > h + 110.0:
				continue
			if pick > 0.965:
				_pyramid(ci, c)
			elif pick > 0.86:
				_ruin(ci, c)
			elif pick > 0.66:
				_palm(ci, c, _hash2(cx, gy, 83))
			else:
				_rocks(ci, c, _hash2(cx, gy, 89))


## 피라미드 — 계단식 단과 어두운 입구. 사막에서 제일 큰 지물이다.
static func _pyramid(ci: CanvasItem, c: Vector2) -> void:
	var wd := 78.0
	for i in 7:
		var k := 1.0 - i / 7.0
		var y := c.y + 40.0 - i * 11.0
		var hw := wd * k
		ci.draw_rect(Rect2(c.x - hw, y - 11.0, hw * 2.0, 11.5), Color8(150, 106, 58), true)
		ci.draw_rect(Rect2(c.x - hw, y - 11.0, hw * 2.0, 2.0), Color8(178, 132, 76), true)
		ci.draw_rect(Rect2(c.x - hw, y - 1.5, hw * 2.0, 1.5), Color8(104, 70, 36), true)
	ci.draw_rect(Rect2(c.x - 10.0, c.y + 26.0, 20.0, 16.0), Color8(38, 26, 18), true)
	ci.draw_rect(Rect2(c.x - 3.0, c.y - 44.0, 6.0, 84.0), P.a(Color8(196, 150, 92), 0.25), true)


static func _ruin(ci: CanvasItem, c: Vector2) -> void:
	for i in 3:
		var x := c.x + (i - 1) * 17.0
		var hgt := 20.0 + _hash2(int(x), int(c.y), 97) * 12.0
		ci.draw_rect(Rect2(x - 6.0, c.y - hgt * 0.5, 12.0, hgt), Color8(132, 116, 84), true)
		ci.draw_rect(Rect2(x - 8.0, c.y - hgt * 0.5 - 4.0, 16.0, 5.0), Color8(158, 140, 102), true)
		ci.draw_rect(Rect2(x - 8.0, c.y + hgt * 0.5 - 1.0, 16.0, 4.0), Color8(96, 82, 58), true)


static func _palm(ci: CanvasItem, c: Vector2, k: float) -> void:
	var n := 2 if k > 0.55 else 1
	for i in n:
		var p := c + Vector2((i - (n - 1) * 0.5) * 26.0, (i % 2) * 12.0)
		ci.draw_rect(Rect2(p.x - 2.5, p.y - 4.0, 5.0, 14.0), Color8(96, 70, 40), true)
		for b in 6:
			var a := b * TAU / 6.0 + k * 2.0
			var tip := p + Vector2(cos(a) * 15.0, sin(a) * 9.0 - 6.0)
			G2.fill_fan(ci, PackedVector2Array([p + Vector2(-3, -6), p + Vector2(3, -6),
					tip + Vector2(0, 3), tip]), Color8(58, 104, 52))
		ci.draw_circle(p + Vector2(0, -6), 4.0, Color8(76, 128, 62))


static func _rocks(ci: CanvasItem, c: Vector2, k: float) -> void:
	var n := 2 + int(k * 3.0)
	for i in n:
		var q := c + Vector2((_hash2(i, int(c.y), 101) - 0.5) * 44.0,
				(_hash2(i, int(c.x), 103) - 0.5) * 30.0)
		var rr := 4.0 + _hash2(i, int(c.x + c.y), 107) * 5.0
		G2.fill_fan(ci, PackedVector2Array([q + Vector2(-rr, rr * 0.4),
				q + Vector2(-rr * 0.5, -rr), q + Vector2(rr * 0.6, -rr * 0.8),
				q + Vector2(rr, rr * 0.5)]), Color8(120, 100, 70))
		ci.draw_rect(Rect2(q.x - rr, q.y + rr * 0.2, rr * 2.0, 2.0),
				P.a(Color8(70, 58, 40), 0.5), true)
