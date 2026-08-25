class_name Art
extends RefCounted

## 드래곤 · 적 · 탄 · 아이템 · 배경을 전부 코드로 그린다. 그림 파일은 하나도 없다.
##
## **조각(폴리곤)은 한 번 만들어 캐시하고 그릴 때는 변환만 건다.** 폰에서 돌 것이라
## 매 프레임 폴리곤을 새로 만들면 그것만으로 프레임을 먹는다.
##
## 둥근 것은 반드시 [method CanvasItem.draw_circle] 로 그린다 —
## `G2.fill_fan` 은 호출마다 그리기 명령이 따로 생겨 배칭이 끊긴다.
## fill_fan 은 원으로 못 만드는 실루엣에만 쓴다.

static var _cache := {}


static func _shape(key: String) -> Dictionary:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]

# ==================== 조각 만들기 ====================

## 드래곤은 **위에서 내려다본 모습**이다. y 가 음수면 화면 위쪽(나아가는 쪽).
static func _build(key: String) -> Dictionary:
	match key:
		"dragon":
			return {
				# 몸통 — 머리에서 꼬리까지 한 덩어리
				body = G2.poly([
					[0, -40], [7, -32], [6, -24], [11, -10], [12, 4],
					[8, 18], [4, 30], [3, 44], [0, 52],
					[-3, 44], [-4, 30], [-8, 18], [-12, 4], [-11, -10],
					[-6, -24], [-7, -32]]),
				# 배 — 몸통 위에 밝게 한 겹
				belly = G2.poly([
					[0, -28], [4, -18], [5, 0], [3, 16], [0, 26],
					[-3, 16], [-5, 0], [-4, -18]]),
				# 날개 한 짝 (오른쪽). 왼쪽은 mirror 로 만든다.
				wing = G2.poly([
					[8, -10], [26, -24], [44, -18], [52, -2], [44, 8], [26, 12], [11, 8]]),
				# 날개 안쪽 무늬
				vane = G2.poly([
					[13, -6], [28, -16], [40, -11], [44, -1], [37, 4], [21, 6]]),
				# 뿔 두 개
				horn = G2.poly([[4, -34], [10, -46], [7, -32]]),
			}
		"imp":
			return {
				body = G2.poly([
					[0, -14], [9, -8], [11, 4], [6, 14], [0, 17],
					[-6, 14], [-11, 4], [-9, -8]]),
				wing = G2.poly([[8, -6], [22, -14], [27, -2], [20, 8], [9, 7]]),
				horn = G2.poly([[5, -12], [9, -22], [4, -11]]),
			}
		"wisp":
			return {
				# 아래로 뾰족한 물방울 — 빠르게 떨어지는 것이 실루엣으로 읽혀야 한다
				body = G2.poly([
					[0, 16], [7, 2], [8, -6], [4, -13], [0, -15],
					[-4, -13], [-8, -6], [-7, 2]]),
			}
		"golem":
			return {
				# 각진 바위 덩어리. 곡선이 없어야 "단단하다"가 읽힌다
				body = G2.poly([
					[0, -26], [16, -20], [24, -6], [22, 10], [12, 24],
					[0, 27], [-12, 24], [-22, 10], [-24, -6], [-16, -20]]),
				plate = G2.poly([
					[0, -16], [11, -11], [14, 2], [8, 13], [0, 15],
					[-8, 13], [-14, 2], [-11, -11]]),
				arm = G2.poly([[20, -8], [33, -4], [35, 8], [24, 12], [19, 4]]),
			}
		"wyvern":
			return {
				body = G2.poly([
					[0, -20], [7, -12], [9, 0], [6, 12], [2, 22], [0, 26],
					[-2, 22], [-6, 12], [-9, 0], [-7, -12]]),
				wing = G2.poly([[7, -8], [26, -20], [38, -8], [32, 6], [16, 11], [8, 7]]),
				horn = G2.poly([[4, -18], [9, -28], [3, -16]]),
			}
		"orb":
			return {
				# 마름모 껍질 — 원은 draw_circle 로 따로 그리고 이건 바깥 테두리
				shell = G2.poly([
					[0, -24], [12, -12], [17, 0], [12, 12], [0, 24],
					[-12, 12], [-17, 0], [-12, -12]]),
			}
		"rock":
			return {
				body = G2.poly([
					[0, -30], [18, -24], [30, -8], [28, 12], [15, 27],
					[-2, 30], [-17, 24], [-29, 9], [-28, -10], [-16, -25]]),
				face = G2.poly([
					[-4, -18], [11, -13], [17, 2], [8, 16], [-7, 15], [-15, 1]]),
			}
	return {}


static func _draw_part(ci: CanvasItem, pts: PackedVector2Array, tf: Transform2D,
		fill: Color, lw: float = 1.6) -> void:
	if pts.is_empty():
		return
	G2.body(ci, G2.xf(pts, tf), fill, lw)

# ==================== 드래곤 ====================

## `flap` 은 날갯짓 위상, `tilt` 는 좌우로 기우는 정도(-1~1).
static func dragon(ci: CanvasItem, idx: int, pos: Vector2, t: float, sc: float = 1.0,
		tilt: float = 0.0, alpha: float = 1.0) -> void:
	var s := _shape("dragon")
	var ci_col := int(D.DRAGON[clampi(idx, 0, D.DRAGON.size() - 1)].col)
	var base := P.a(P.dragon(ci_col, 0), alpha)
	var dark := P.a(P.dragon(ci_col, 1), alpha)
	var horn := P.a(P.dragon(ci_col, 2), alpha)

	# 날갯짓 — 폭이 줄었다 늘었다 한다. 위아래로 흔들면 위에서 본 그림이 안 된다.
	var flap := 0.72 + 0.28 * sin(t * 11.0)
	var tf := Transform2D(0.0, Vector2.ONE * sc, 0.0, pos)
	var wtf := Transform2D(0.0, Vector2(sc * flap, sc), 0.0, pos)

	# 뒤쪽 날개(그늘) -> 몸통 -> 앞쪽 날개 순서로 겹쳐야 몸이 날개 사이에 든다
	var wing: PackedVector2Array = s.wing
	var vane: PackedVector2Array = s.vane
	_draw_part(ci, wing, wtf, dark)
	_draw_part(ci, G2.mirror(wing), wtf, dark)

	# 기울기는 몸통에만 준다 — 날개까지 같이 돌리면 위에서 본 느낌이 깨진다
	var btf := Transform2D(tilt * 0.16, Vector2.ONE * sc, 0.0, pos)
	_draw_part(ci, s.body, btf, base)
	_draw_part(ci, s.belly, btf, P.a(P.BELLY, alpha * 0.92), 0.0)
	_draw_part(ci, s.horn, btf, horn, 1.2)
	_draw_part(ci, G2.mirror(s.horn), btf, horn, 1.2)

	_draw_part(ci, vane, wtf, P.a(horn, alpha * 0.5), 1.0)
	_draw_part(ci, G2.mirror(vane), wtf, P.a(horn, alpha * 0.5), 1.0)

	# 눈 — 얼굴이 있어야 어느 쪽이 앞인지 바로 읽힌다
	var eye := P.a(P.EYE, alpha)
	ci.draw_circle(pos + btf.basis_xform(Vector2(3.6, -28.0) * 1.0), 1.9 * sc, eye)
	ci.draw_circle(pos + btf.basis_xform(Vector2(-3.6, -28.0) * 1.0), 1.9 * sc, eye)


## 판정점. 저속이 없는 게임이라 **항상 보인다** — 즉사인데 어디가 몸인지 모르면
## 죽었을 때 납득이 안 된다.
static func hitpoint(ci: CanvasItem, pos: Vector2, r: float, col: Color, t: float) -> void:
	G2.glow(ci, pos, r * 3.4, col, 0.34)
	ci.draw_circle(pos, r + 1.6, P.a(P.LINE, 0.75))
	ci.draw_circle(pos, r, P.hdr(P.WHITE, 1.25))


static func shield_ring(ci: CanvasItem, pos: Vector2, r: float, n: int, t: float) -> void:
	for i in n:
		var rr := r + i * 7.0
		var puls := 0.62 + 0.24 * sin(t * 3.4 - i * 0.8)
		ci.draw_arc(pos, rr, 0.0, TAU, 30, P.a(P.hdr(P.SHIELD, 1.2), puls), 2.0, true)
	if n > 0:
		G2.glow(ci, pos, r + n * 7.0 + 16.0, P.SHIELD, 0.16)

# ==================== 적 ====================

static func enemy(ci: CanvasItem, e: Dictionary, t: float) -> void:
	var art := String(e.art)
	var pos: Vector2 = e.pos
	var flash: float = e.get("flash", 0.0)
	match art:
		"imp": _imp(ci, pos, t, e)
		"wisp": _wisp(ci, pos, t, e)
		"golem": _golem(ci, pos, t, e)
		"wyvern": _wyvern(ci, pos, t, e)
		"orb": _orb(ci, pos, t, e)
		"rock": _rock(ci, pos, t, e)
	if flash > 0.0:
		# 맞았다는 표시. 실루엣 위에 흰 겹을 얹는 게 제일 싸고 확실하다.
		G2.glow(ci, pos, float(e.r) * 1.8, P.WHITE, clampf(flash, 0.0, 0.55))


static func _imp(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("imp")
	var flap := 0.66 + 0.34 * sin(t * 13.0 + float(e.get("ph", 0.0)))
	var wtf := Transform2D(0.0, Vector2(flap, 1.0), 0.0, pos)
	var tf := Transform2D(0.0, Vector2.ONE, 0.0, pos)
	_draw_part(ci, s.wing, wtf, P.FOE_D)
	_draw_part(ci, G2.mirror(s.wing), wtf, P.FOE_D)
	_draw_part(ci, s.body, tf, P.FOE)
	_draw_part(ci, s.horn, tf, P.FOE_HORN, 1.0)
	_draw_part(ci, G2.mirror(s.horn), tf, P.FOE_HORN, 1.0)
	ci.draw_circle(pos + Vector2(3.2, -4.0), 1.7, P.hdr(P.FOE_MARK, 1.2))
	ci.draw_circle(pos + Vector2(-3.2, -4.0), 1.7, P.hdr(P.FOE_MARK, 1.2))


static func _wisp(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("wisp")
	var tf := Transform2D(0.0, Vector2.ONE, 0.0, pos)
	# 꼬리 잔상 — 빠른 것이라 지나온 자리가 남아야 속도가 읽힌다
	for i in range(3, 0, -1):
		G2.glow(ci, pos - Vector2(0, i * 13.0), 15.0 - i * 2.0, P.hdr(P.VENOM, 1.1),
				0.13 * (4 - i))
	_draw_part(ci, s.body, tf, P.hdr(Color8(196, 112, 210), 1.05), 1.4)
	ci.draw_circle(pos + Vector2(0, -5.0), 3.4, P.hdr(P.WHITE, 1.3))


static func _golem(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("golem")
	var sway := sin(t * 3.0 + float(e.get("ph", 0.0))) * 0.06
	var tf := Transform2D(sway, Vector2.ONE, 0.0, pos)
	_draw_part(ci, s.arm, tf, P.FOE_D)
	_draw_part(ci, G2.mirror(s.arm), tf, P.FOE_D)
	_draw_part(ci, s.body, tf, P.STONE, 2.0)
	_draw_part(ci, s.plate, tf, P.STONE_D, 1.2)
	# 눈 — 골렘은 앞을 막는 벽이라 "노려보고 있다"가 읽혀야 한다
	var g := P.hdr(P.FOE_MARK, 1.35)
	G2.glow(ci, pos + Vector2(0, -6.0), 16.0, P.FOE_MARK, 0.3)
	ci.draw_circle(pos + Vector2(6.5, -6.0), 2.8, g)
	ci.draw_circle(pos + Vector2(-6.5, -6.0), 2.8, g)


static func _wyvern(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("wyvern")
	var flap := 0.62 + 0.38 * sin(t * 9.0 + float(e.get("ph", 0.0)))
	var wtf := Transform2D(0.0, Vector2(flap, 1.0), 0.0, pos)
	var tf := Transform2D(0.0, Vector2.ONE, 0.0, pos)
	_draw_part(ci, s.wing, wtf, P.FOE_D)
	_draw_part(ci, G2.mirror(s.wing), wtf, P.FOE_D)
	_draw_part(ci, s.body, tf, Color8(146, 116, 82))
	_draw_part(ci, s.horn, tf, P.FOE_HORN, 1.0)
	_draw_part(ci, G2.mirror(s.horn), tf, P.FOE_HORN, 1.0)
	# 쏘기 직전이면 입에 빛이 모인다 — 예비 동작이 없으면 피할 방법이 없다
	var cast: float = e.get("cast", 0.0)
	if cast > 0.0:
		G2.glow(ci, pos + Vector2(0, -18.0), 8.0 + 10.0 * cast, P.VENOM, 0.4 + 0.4 * cast)
	ci.draw_circle(pos + Vector2(3.0, -12.0), 1.8, P.hdr(P.FOE_MARK, 1.2))
	ci.draw_circle(pos + Vector2(-3.0, -12.0), 1.8, P.hdr(P.FOE_MARK, 1.2))


static func _orb(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("orb")
	var spin := t * 1.1 + float(e.get("ph", 0.0))
	_draw_part(ci, s.shell, Transform2D(spin, Vector2.ONE, 0.0, pos), Color8(78, 70, 106), 1.8)
	var cast: float = e.get("cast", 0.0)
	G2.glow(ci, pos, 22.0 + 12.0 * cast, P.VENOM, 0.22 + 0.4 * cast)
	ci.draw_circle(pos, 8.0, P.hdr(P.VENOM, 1.15))
	ci.draw_circle(pos, 4.0, P.hdr(P.VENOM_HI, 1.2))


## **바위는 부술 수 없다.** 그래서 발광을 하나도 안 준다 — 화면에서 빛나는 것은
## 전부 "때릴 수 있는 것" 아니면 "주울 것"이고, 바위만 빛이 없어서 눈에 바로 갈린다.
static func _rock(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("rock")
	var tf := Transform2D(float(e.get("ph", 0.0)), Vector2.ONE, 0.0, pos)
	_draw_part(ci, s.body, tf, P.STONE_D, 2.2)
	_draw_part(ci, s.face, tf, P.STONE, 1.2)

# ==================== 탄 ====================

## 아군 브레스. `st` 로 모양이 갈린다 — 굵은 줄기 · 번개 · 얼음창.
static func breath(ci: CanvasItem, b: Dictionary) -> void:
	var pos: Vector2 = b.pos
	var col: Color = b.col
	var w: float = b.w
	match String(b.st):
		"flame":
			G2.glow(ci, pos, w * 3.0, col, 0.4)
			ci.draw_circle(pos, w, P.hdr(col, 1.3))
			ci.draw_circle(pos, w * 0.5, P.hdr(P.WHITE, 1.2))
		"bolt":
			# 번개는 선이라야 한다. 원으로 그리면 불덩이와 구분이 안 된다.
			var v: Vector2 = Vector2(b.vel).normalized() * (w * 3.2)
			G2.glow(ci, pos, w * 2.6, col, 0.32)
			ci.draw_line(pos - v, pos + v, P.hdr(col, 1.35), w * 0.9, true)
			ci.draw_line(pos - v * 0.5, pos + v * 0.5, P.hdr(P.WHITE, 1.2), w * 0.4, true)
		"spear":
			var d: Vector2 = Vector2(b.vel).normalized()
			var n := Vector2(-d.y, d.x)
			var len: float = w * 5.0
			var tip := pos + d * len
			var tail := pos - d * len
			G2.glow(ci, pos, w * 2.8, col, 0.3)
			G2.body(ci, PackedVector2Array([
				tip, pos + n * w, tail + n * w * 0.4, tail - n * w * 0.4, pos - n * w]),
				P.hdr(col, 1.25), 1.0, P.a(P.WHITE, 0.5))


## **적이 쏜 것은 분홍 하나로 통일한다.** 브레스(기체색)에도 금화(금색)에도 안 쓰는
## 색이라야 "분홍은 피한다"가 굳는다. 색만으로는 부족해서 검은 테두리와 맥동 고리로
## 형태까지 다르게 한다 — 배경이 밝은 협곡에서 색만으로는 안 읽힌다.
static func foe_bullet(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var r := D.E_BULLET_R
	G2.glow(ci, pos, r * 2.6, P.VENOM, 0.34)
	ci.draw_circle(pos, r + 1.8, P.a(P.LINE, 0.8))
	ci.draw_circle(pos, r, P.hdr(P.VENOM, 1.2))
	ci.draw_circle(pos, r * 0.44, P.hdr(P.VENOM_HI, 1.25))
	ci.draw_arc(pos, r + 4.0 + sin(t * 8.0) * 1.6, 0.0, TAU, 16,
			P.a(P.VENOM_HI, 0.4), 1.2, true)

# ==================== 아이템 ====================

## **아이템은 실루엣으로 갈린다** — 금화는 동그라미, P 는 육각, 보호막은 방패.
## 색만 다르면 금화가 수십 개 깔린 구간에서 통째로 묻힌다.
static func coin(ci: CanvasItem, pos: Vector2, t: float, ph: float) -> void:
	# 도는 것처럼 보이게 가로 폭만 줄인다. 그리기 호출은 원 두 번뿐.
	var k := absf(cos(t * 3.2 + ph))
	var rx := maxf(2.0, D.ITEM_R * 0.62 * k)
	G2.glow(ci, pos, D.ITEM_R * 1.7, P.GOLD, 0.22)
	G2.body(ci, G2.ellipse_pts(pos, rx, D.ITEM_R * 0.62, 14), P.hdr(P.GOLD, 1.15), 1.4)
	if k > 0.45:
		G2.body(ci, G2.ellipse_pts(pos, rx * 0.5, D.ITEM_R * 0.31, 12), P.GOLD_D, 0.0)


static func item_power(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var r := D.ITEM_R
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + t * 1.4
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	G2.glow(ci, pos, r * 2.2, P.POWER, 0.34)
	G2.body(ci, pts, P.hdr(P.POWER, 1.15), 1.8)
	G2.text_mid(ci, pos, "P", 17.0, P.LINE)

# ==================== 이펙트 ====================

static func boom(ci: CanvasItem, pos: Vector2, p: float, size: float, col: Color) -> void:
	var e := G2.out_cubic(clampf(p, 0.0, 1.0))
	var r := size * (0.35 + e * 1.05)
	var fade := 1.0 - e
	G2.glow(ci, pos, r * 2.0, col, 0.5 * fade)
	ci.draw_arc(pos, r, 0.0, TAU, 22, P.a(P.hdr(col, 1.3), fade * 0.9), 3.0 * fade + 0.6, true)
	if e < 0.55:
		ci.draw_circle(pos, r * 0.5 * (1.0 - e / 0.55), P.a(P.hdr(P.WHITE, 1.2), fade))


## 튀는 알갱이. 한 번에 수십 개가 뜨므로 **선 하나**로만 그린다.
static func spark(ci: CanvasItem, pos: Vector2, vel: Vector2, life: float, col: Color) -> void:
	var a := clampf(life, 0.0, 1.0)
	ci.draw_line(pos, pos - vel * 0.035, P.a(P.hdr(col, 1.2), a), 2.0, true)


static func gold_pop(ci: CanvasItem, pos: Vector2, p: float, amount: int) -> void:
	var a := 1.0 - G2.smooth(p)
	G2.text_mid(ci, pos - Vector2(0, p * 38.0), "+%d" % amount, 15.0,
			P.a(P.hdr(P.GOLD, 1.2), a))

# ==================== 배경 ====================

## 하늘 — 위아래 두 색 사이를 몇 칸으로 나눠 칠한다.
##
## **칸을 너무 잘게 나누지 마라.** 폰에서는 draw_rect 하나하나가 비용이고,
## 12칸이면 그라데이션으로 충분히 보인다.
static func sky(ci: CanvasItem, w: float, h: float, zone: int) -> void:
	var pair: Array = P.SKY[zone % P.SKY.size()]
	var top: Color = pair[0]
	var bot: Color = pair[1]
	var n := 12
	for i in n:
		var f := float(i) / float(n - 1)
		ci.draw_rect(Rect2(0, h * i / n - 1.0, w, h / n + 2.0), top.lerp(bot, f), true)


static func _hash(x: int) -> float:
	var v := (x * 374761393 + 668265263) & 0x7fffffff
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xffff) / 65535.0


## 흘러가는 배경 무늬. **판정과 무관한 층**이라 거리에 따라 속도를 달리 줘도
## 난이도 통로가 되지 않는다 — 빨라지는 느낌은 여기서만 낸다.
static func scenery(ci: CanvasItem, w: float, h: float, scroll: float, zone: int,
		t: float) -> void:
	var z := zone % 3
	if z == 2:
		_stars(ci, w, h, scroll, t)
	else:
		_ground(ci, w, h, scroll, z)


static func _stars(ci: CanvasItem, w: float, h: float, scroll: float, t: float) -> void:
	# 별은 층을 셋으로 나눠 다른 속도로 흘린다. 한 층이면 평평해 보인다.
	for layer in 3:
		var spd := 0.22 + layer * 0.34
		var n := 26
		var span := h + 80.0
		for i in n:
			var sx := _hash(i * 7 + layer * 131) * w
			var base := _hash(i * 13 + layer * 977) * span
			var sy := fposmod(base + scroll * spd, span) - 40.0
			var r := 0.9 + layer * 0.7
			var tw := 0.5 + 0.5 * sin(t * 2.4 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy), r, P.a(P.hdr(P.WHITE, 1.1), 0.28 + 0.42 * tw))


## 초원·협곡 — 좌우 가장자리에 지형 덩어리를 흘려 "벽 사이를 난다"를 만든다.
## 가운데는 비워 둔다. 여기에 무늬를 깔면 적과 탄이 묻힌다.
static func _ground(ci: CanvasItem, w: float, h: float, scroll: float, z: int) -> void:
	var col: Color = P.GROUND[z]
	var dk: Color = P.GROUND_D[z]
	var span := h + 260.0
	var edge := w * 0.13
	for side in 2:
		for i in 9:
			var seed := i * 31 + side * 613 + z * 97
			var yy := fposmod(_hash(seed) * span + scroll * 0.55, span) - 130.0
			var ww := edge * (0.55 + _hash(seed + 5) * 0.9)
			var hh := 90.0 + _hash(seed + 9) * 130.0
			var cx := (0.0 - ww * 0.25) if side == 0 else (w + ww * 0.25)
			var pts := PackedVector2Array()
			for k in 7:
				var a := PI * k / 6.0 + (0.0 if side == 0 else PI)
				var rr := 1.0 + _hash(seed + k * 17) * 0.35
				pts.append(Vector2(cx + cos(a) * ww * rr, yy + sin(a) * hh * rr))
			G2.fill_fan(ci, pts, dk if (i % 2 == 0) else col)
	# 안개 — 위쪽으로 갈수록 하늘에 녹아든다. 적이 나타나는 자리를 부드럽게 만든다.
	ci.draw_rect(Rect2(0, 0, w, h * 0.16), P.a(P.SKY[z][0], 0.5), true)


## 구간이 바뀔 때 화면을 가로지르는 띠. **어디서 바뀌었는지 몰라도 되면 구간이
## 있을 이유가 없다** — 배경만 슬쩍 바뀌면 눈치채지 못한다.
static func zone_banner(ci: CanvasItem, w: float, h: float, y: float, name: String,
		idx: int, fade: float) -> void:
	if fade <= 0.0:
		return
	var a := clampf(fade, 0.0, 1.0)
	ci.draw_rect(Rect2(0, y - 34, w, 68), P.a(P.LINE, 0.45 * a), true)
	ci.draw_line(Vector2(0, y - 34), Vector2(w, y - 34), P.a(P.hdr(P.GOLD, 1.2), a), 2.0)
	ci.draw_line(Vector2(0, y + 34), Vector2(w, y + 34), P.a(P.hdr(P.GOLD, 1.2), a), 2.0)
	G2.text_mid(ci, Vector2(w * 0.5, y - 6), name, 26.0, P.a(P.hdr(P.WHITE, 1.15), a))
	G2.text_mid(ci, Vector2(w * 0.5, y + 20), "%d구간" % (idx + 1), 13.0,
			P.a(P.hdr(P.GOLD, 1.1), a))
