class_name MB
extends RefCounted

## 로우폴리 메시 빌더. **그림 파일 없이 코드로 형태를 만드는 곳**이다.
##
## 상자·사다리꼴 기둥·각뿔·다각기둥 넷이면 로우폴리 도안은 거의 다 나온다.
## 이 넷을 쌓아 유닛 6종 × 등급 5단계와 적 5종을 전부 만든다.
##
## ## 지켜야 할 것
##
## - **면의 정점은 바깥에서 봤을 때 반시계 방향(CCW)으로 넣는다.** 그래야
##   `(b-a) × (c-a)` 가 바깥을 향하고, 법선이 곧 바깥면이 된다. 순서를 섞으면
##   그 면만 조명이 뒤집혀 까맣게 나오는데, 원인이 눈에 안 띈다.
## - **정점 색은 "색"이 아니라 "명암"이다.** 회색조로만 넣는다 —
##   실제 색은 `MultiMesh` 의 인스턴스 색이 곱해서 낸다. 그래서 메시 하나로
##   원소 6종을 다 그릴 수 있고, 드로우콜도 종류 수만큼만 생긴다.
## - 법선은 면마다 따로 넣어 **평면 셰이딩**이 된다. 이게 로우폴리의 각진 인상을 만든다.
##   정점을 공유해 부드럽게 만들려 하지 마라 — 형태가 물러진다.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()

## 앞으로 넣는 면에 곱해질 색.
##
## `MultiMesh` 로 그리는 것(유닛·적·탄)은 인스턴스 색이 색을 내므로 **흰색으로 두고**
## 명암만 회색조로 넣는다. 반대로 바닥처럼 인스턴스 색이 없는 것은 여기에 실제 색을
## 넣어야 한다 — 안 그러면 온통 회색으로 나온다.
var tint := Color.WHITE

## 정점 색으로 쓸 명암. 1.0 이 정면광, 그 아래가 그늘.
const TOP := 1.0
const SIDE := 0.74
const BOT := 0.45


static func sh(k: float) -> Color:
	return Color(k, k, k, 1.0)


func _sh(k: float) -> Color:
	return Color(tint.r * k, tint.g * k, tint.b * k, 1.0)


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var nm := (b - a).cross(c - a)
	if nm.length_squared() < 1e-12:
		return  # 찌부러진 삼각형 — 법선이 안 나오므로 버린다
	nm = nm.normalized()
	_v.push_back(a)
	_v.push_back(b)
	_v.push_back(c)
	for i in 3:
		_n.push_back(nm)
		_c.push_back(col)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


## 축에 나란한 상자. `c` 는 중심, `s` 는 전체 크기.
func box(c: Vector3, s: Vector3, k: float = 1.0) -> void:
	frustum(c - Vector3(0, s.y * 0.5, 0), Vector2(s.x, s.z), Vector2(s.x, s.z), s.y, k)


## 사다리꼴 기둥. 로우폴리의 주력 —
## 아래위 크기를 다르게 주면 그것만으로 몸통·다리·포탑이 다 나온다.
##
## `base` 는 **밑면 중심**, `bot`·`top` 은 밑면·윗면의 전체 가로세로(x, z), `h` 는 높이.
func frustum(base: Vector3, bot: Vector2, top: Vector2, h: float, k: float = 1.0,
		top_k: float = -1.0) -> void:
	var tk := (k * TOP) if top_k < 0.0 else top_k
	var sk := k * SIDE
	var bk := k * BOT
	var y0 := base.y
	var y1 := base.y + h
	var bx := bot.x * 0.5
	var bz := bot.y * 0.5
	var tx := top.x * 0.5
	var tz := top.y * 0.5
	var cx := base.x
	var cz := base.z

	var b00 := Vector3(cx - bx, y0, cz - bz)
	var b10 := Vector3(cx + bx, y0, cz - bz)
	var b11 := Vector3(cx + bx, y0, cz + bz)
	var b01 := Vector3(cx - bx, y0, cz + bz)
	var t00 := Vector3(cx - tx, y1, cz - tz)
	var t10 := Vector3(cx + tx, y1, cz - tz)
	var t11 := Vector3(cx + tx, y1, cz + tz)
	var t01 := Vector3(cx - tx, y1, cz + tz)

	# 옆면 넷 — 전부 바깥에서 봤을 때 CCW
	quad(b01, b11, t11, t01, _sh(sk))          # +Z
	quad(b10, b00, t00, t10, _sh(sk * 0.92))   # -Z
	quad(b11, b10, t10, t11, _sh(sk * 0.86))   # +X
	quad(b00, b01, t01, t00, _sh(sk * 0.98))   # -X
	if tx > 0.0001 and tz > 0.0001:
		quad(t01, t11, t10, t00, _sh(tk))      # 윗면
	quad(b00, b10, b11, b01, _sh(bk))          # 밑면


## 사각뿔. 끝이 한 점으로 모인다 — 뿔·창끝·지붕.
func pyramid(base: Vector3, size: Vector2, h: float, k: float = 1.0) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var y0 := base.y
	var apex := Vector3(base.x, y0 + h, base.z)
	var b00 := Vector3(base.x - hx, y0, base.z - hz)
	var b10 := Vector3(base.x + hx, y0, base.z - hz)
	var b11 := Vector3(base.x + hx, y0, base.z + hz)
	var b01 := Vector3(base.x - hx, y0, base.z + hz)
	tri(b01, b11, apex, _sh(k * TOP))
	tri(b10, b00, apex, _sh(k * SIDE * 0.9))
	tri(b11, b10, apex, _sh(k * SIDE))
	tri(b00, b01, apex, _sh(k * SIDE * 0.8))
	quad(b00, b10, b11, b01, _sh(k * BOT))


## n 각기둥. `sides` 가 6~8 이면 로우폴리에서 원처럼 읽히고 삼각형은 얼마 안 든다.
func ngon(base: Vector3, r_bot: float, r_top: float, h: float, sides: int = 8,
		k: float = 1.0, phase: float = 0.0) -> void:
	var y0 := base.y
	var y1 := base.y + h
	var cen_t := Vector3(base.x, y1, base.z)
	var cen_b := Vector3(base.x, y0, base.z)
	for i in sides:
		var a0 := phase + TAU * float(i) / float(sides)
		var a1 := phase + TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p0 := cen_b + d0 * r_bot
		var p1 := cen_b + d1 * r_bot
		var q0 := cen_t + d0 * r_top
		var q1 := cen_t + d1 * r_top
		# 옆면 — 바깥에서 봤을 때 CCW 가 되도록 아래 → 아래 → 위 → 위
		var side_k := k * SIDE * (0.86 + 0.14 * (0.5 + 0.5 * cos(a0)))
		if r_bot > 0.0001 or r_top > 0.0001:
			quad(p0, p1, q1, q0, _sh(side_k))
		if r_top > 0.0001:
			tri(cen_t, q0, q1, _sh(k * TOP))
		if r_bot > 0.0001:
			tri(cen_b, p1, p0, _sh(k * BOT))


## 팔면체. 탄·보석처럼 "떠 있는 알갱이" 전용.
func octa(c: Vector3, r: float, h: float, k: float = 1.0) -> void:
	var up := c + Vector3(0, h, 0)
	var dn := c - Vector3(0, h, 0)
	var p := [
		c + Vector3(r, 0, 0), c + Vector3(0, 0, r),
		c + Vector3(-r, 0, 0), c + Vector3(0, 0, -r),
	]
	for i in 4:
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		tri(a, b, up, _sh(k * (0.86 + 0.14 * float(i % 2))))
		tri(b, a, dn, _sh(k * SIDE * 0.8))


func empty() -> bool:
	return _v.is_empty()


## 쌓아 둔 삼각형을 실제 메시로 굽는다. 한 번 부르면 이 빌더는 비워진다.
func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	var m := mesh if mesh != null else ArrayMesh.new()
	if _v.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, material())
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_c = PackedColorArray()
	return m


static var _mat: StandardMaterial3D


## 모든 메시가 **같은 재질 하나**를 쓴다.
##
## `vertex_color_use_as_albedo` 가 켜져 있어 [정점 명암] × [MultiMesh 인스턴스 색] 이
## 그대로 알베도가 된다. 재질을 종류마다 따로 만들면 그만큼 배칭이 끊기니 늘리지 마라.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		# 안팎을 다 그린다. 면 방향을 한 군데라도 뒤집어 넣으면 구멍이 보이는데,
		# 로우폴리라 삼각형이 얼마 안 되므로 그 위험을 사는 편이 싸다.
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 0.82
		_mat.metallic = 0.0
		_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return _mat
