class_name Art
extends RefCounted

## 드래곤 · 적 · 보스 · 탄 · 아이템 · 배경을 전부 코드로 그린다. 그림 파일은 하나도 없다.
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
				body = G2.poly([
					[0, -40], [7, -32], [6, -24], [11, -10], [12, 4],
					[8, 18], [4, 30], [3, 44], [0, 52],
					[-3, 44], [-4, 30], [-8, 18], [-12, 4], [-11, -10],
					[-6, -24], [-7, -32]]),
				belly = G2.poly([
					[0, -28], [4, -18], [5, 0], [3, 16], [0, 26],
					[-3, 16], [-5, 0], [-4, -18]]),
				wing = G2.poly([
					[8, -10], [26, -24], [44, -18], [52, -2], [44, 8], [26, 12], [11, 8]]),
				vane = G2.poly([
					[13, -6], [28, -16], [40, -11], [44, -1], [37, 4], [21, 6]]),
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
				body = G2.poly([
					[0, 16], [7, 2], [8, -6], [4, -13], [0, -15],
					[-4, -13], [-8, -6], [-7, 2]]),
			}
		"golem":
			return {
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
				shell = G2.poly([
					[0, -24], [12, -12], [17, 0], [12, 12], [0, 24],
					[-12, 12], [-17, 0], [-12, -12]]),
			}
		"meteor":
			return {
				body = G2.poly([
					[0, -30], [18, -24], [30, -8], [28, 12], [15, 27],
					[-2, 30], [-17, 24], [-29, 9], [-28, -10], [-16, -25]]),
				face = G2.poly([
					[-4, -18], [11, -13], [17, 2], [8, 16], [-7, 15], [-15, 1]]),
			}
		"flame":
			return {
				body = G2.poly([
					[0, -22], [10, -12], [13, 2], [8, 15], [0, 20],
					[-8, 15], [-13, 2], [-10, -12]]),
			}
		"chest":
			return {
				box = G2.poly([[-22, -6], [22, -6], [22, 18], [-22, 18]]),
				lid = G2.poly([[-24, -18], [24, -18], [22, -4], [-22, -4]]),
			}
		"boss_king":
			return {
				body = G2.poly([
					[0, -70], [40, -56], [66, -22], [72, 18], [50, 54],
					[16, 70], [-16, 70], [-50, 54], [-72, 18], [-66, -22], [-40, -56]]),
				jaw = G2.poly([[-40, 24], [40, 24], [30, 54], [-30, 54]]),
				horn = G2.poly([[26, -56], [52, -96], [44, -48]]),
			}
		"boss_warden":
			return {
				body = G2.poly([
					[0, -62], [46, -46], [82, -10], [86, 22], [56, 52],
					[0, 62], [-56, 52], [-86, 22], [-82, -10], [-46, -46]]),
				jaw = G2.poly([[-52, 16], [52, 16], [38, 50], [-38, 50]]),
				horn = G2.poly([[40, -44], [78, -78], [62, -34]]),
			}
		_:
			return {
				body = G2.poly([
					[0, -72], [34, -60], [58, -32], [68, 0], [58, 32],
					[34, 60], [0, 72], [-34, 60], [-58, 32], [-68, 0],
					[-58, -32], [-34, -60]]),
				jaw = G2.poly([[-30, 30], [30, 30], [22, 58], [-22, 58]]),
				horn = G2.poly([[30, -50], [62, -84], [50, -40]]),
			}


static func _draw_part(ci: CanvasItem, pts: PackedVector2Array, tf: Transform2D,
		fill: Color, lw: float = 1.6) -> void:
	if pts.is_empty():
		return
	G2.body(ci, G2.xf(pts, tf), fill, lw)

# ==================== 드래곤 ====================

static func dragon(ci: CanvasItem, idx: int, pos: Vector2, t: float, sc: float = 1.0,
		tilt: float = 0.0, alpha: float = 1.0) -> void:
	var s := _shape("dragon")
	var ci_col := int(D.DRAGON[clampi(idx, 0, D.DRAGON.size() - 1)].col)
	var base := P.a(P.dragon(ci_col, 0), alpha)
	var dark := P.a(P.dragon(ci_col, 1), alpha)
	var horn := P.a(P.dragon(ci_col, 2), alpha)

	# 날갯짓 — 폭이 줄었다 늘었다 한다. 위아래로 흔들면 위에서 본 그림이 안 된다.
	var flap := 0.72 + 0.28 * sin(t * 11.0)
	var wtf := Transform2D(0.0, Vector2(sc * flap, sc), 0.0, pos)
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

	var eye := P.a(P.EYE, alpha)
	ci.draw_circle(pos + btf.basis_xform(Vector2(3.6, -28.0)), 1.9 * sc, eye)
	ci.draw_circle(pos + btf.basis_xform(Vector2(-3.6, -28.0)), 1.9 * sc, eye)


## 판정점. 즉사 게임인데 어디가 몸인지 모르면 죽었을 때 납득이 안 된다.
static func hitpoint(ci: CanvasItem, pos: Vector2, r: float, col: Color, t: float) -> void:
	G2.glow(ci, pos, r * 3.4, col, 0.34)
	ci.draw_circle(pos, r + 1.6, P.a(P.LINE, 0.75))
	ci.draw_circle(pos, r, P.hdr(P.WHITE, 1.25))


static func heart_ring(ci: CanvasItem, pos: Vector2, r: float, n: int, t: float) -> void:
	for i in n:
		var rr := r + i * 7.0
		var puls := 0.62 + 0.24 * sin(t * 3.4 - i * 0.8)
		ci.draw_arc(pos, rr, 0.0, TAU, 30, P.a(P.hdr(P.HEART, 1.2), puls), 2.0, true)
	if n > 0:
		G2.glow(ci, pos, r + n * 7.0 + 16.0, P.HEART, 0.16)


## 하이퍼 플라이트 — 무적 돌진. 뒤로 길게 빛이 끌린다.
static func hyper_trail(ci: CanvasItem, pos: Vector2, t: float, col: Color) -> void:
	for i in range(6, 0, -1):
		G2.glow(ci, pos + Vector2(0, i * 26.0), 54.0 - i * 3.0, P.hdr(col, 1.2),
				0.10 * (7 - i))
	G2.glow(ci, pos, 96.0, P.hdr(P.WHITE, 1.15), 0.30 + 0.12 * sin(t * 18.0))


## **근접 보너스 띠.** 원작처럼 드래곤 위로 가로선을 긋고 칸마다 배율을 적는다.
##
## 안 보여 주면 "왜 어떤 건 20배고 어떤 건 1배인지" 알 수가 없어서, 이 게임에서
## 제일 큰 점수 차이가 통째로 운처럼 느껴진다. **선 위치는 `D.CLOSE_BAND` 하나에서
## 나온다** — 그려지는 곳과 점수가 계산되는 곳이 같은 값을 봐야 한다.
static func close_bands(ci: CanvasItem, w: float, h: float, pos: Vector2,
		t: float) -> void:
	for b in D.CLOSE_BAND:
		var y: float = pos.y - float(b.top) * h
		if y < 0.0:
			continue
		var mul: float = float(b.mul)
		# 배율이 클수록 진하게. 다 같은 굵기면 어느 칸이 좋은 칸인지 안 읽힌다.
		var k: float = clampf(mul / 20.0, 0.16, 1.0)
		var c := P.a(P.hdr(P.FOE_MARK, 1.15), 0.16 + 0.34 * k)
		ci.draw_line(Vector2(0, y), Vector2(w, y), c, 1.0 + 2.0 * k)
		G2.text_right(ci, Vector2(w - 12.0, y + 20.0), "%dX" % int(mul),
				12.0 + 7.0 * k, P.a(P.hdr(P.FOE_MARK, 1.2), 0.45 + 0.45 * k))

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
		"meteor": _meteor(ci, pos, t, e)
		"flame": _flame(ci, pos, t, e)
		"chest": _chest(ci, pos, t, e)
	if flash > 0.0:
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


## 운석 — **어둡고 빛이 없다.** 원작에서도 시커먼 덩어리로 떨어진다.
## 화면에서 빛나는 것은 대체로 "주울 것"이라, 어두운 것 하나가 섞이면 눈에 바로 갈린다.
static func _meteor(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("meteor")
	var tf := Transform2D(float(e.get("ph", 0.0)) + t * 0.6, Vector2.ONE, 0.0, pos)
	# 떨어지는 것이라 위쪽에 마찰 불꽃이 인다 — 속도가 실루엣만으로도 읽힌다.
	G2.glow(ci, pos - Vector2(0, 26.0), 34.0, P.FLAME, 0.26)
	_draw_part(ci, s.body, tf, P.STONE_D, 2.4)
	_draw_part(ci, s.face, tf, Color8(58, 60, 68), 1.2)


## 불꽃 몬스터 — **죽으면 터진다.** 그래서 혼자만 이글거린다.
## 잡졸과 색이 같으면 "이걸 먼저 노린다"는 판단이 안 생긴다.
static func _flame(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("flame")
	var puls := 0.8 + 0.2 * sin(t * 9.0 + float(e.get("ph", 0.0)))
	G2.glow(ci, pos, 40.0 * puls, P.FLAME, 0.42)
	_draw_part(ci, s.body, Transform2D(0.0, Vector2.ONE * puls, 0.0, pos),
			P.hdr(P.FLAME, 1.25), 1.6)
	ci.draw_circle(pos, 6.0, P.hdr(P.WHITE, 1.3))


static func _chest(ci: CanvasItem, pos: Vector2, t: float, e: Dictionary) -> void:
	var s := _shape("chest")
	var tf := Transform2D(sin(t * 2.0) * 0.05, Vector2.ONE, 0.0, pos)
	G2.glow(ci, pos, 44.0, P.GOLD, 0.3)
	_draw_part(ci, s.box, tf, Color8(122, 82, 46), 2.0)
	_draw_part(ci, s.lid, tf, Color8(158, 110, 62), 2.0)
	ci.draw_circle(pos + Vector2(0, -2.0), 5.0, P.hdr(P.GOLD, 1.2))

# ==================== 보스 ====================

static func boss(ci: CanvasItem, b: Dictionary, t: float) -> void:
	var pos: Vector2 = b.pos
	var s := _shape("boss_" + String(b.art))
	var rage: bool = b.rage
	var base := Color8(96, 88, 108) if not rage else Color8(128, 72, 78)
	var dark := Color8(64, 58, 76) if not rage else Color8(92, 48, 54)
	var tf := Transform2D(sin(t * 1.4) * 0.05, Vector2.ONE, 0.0, pos)

	G2.glow(ci, pos, 190.0, P.FOE_MARK, 0.16 + (0.12 if rage else 0.0))
	_draw_part(ci, s.horn, tf, dark, 2.0)
	_draw_part(ci, G2.mirror(s.horn), tf, dark, 2.0)
	_draw_part(ci, s.body, tf, base, 2.6)
	_draw_part(ci, s.jaw, tf, dark, 2.0)

	var eye := P.hdr(P.FOE_MARK, 1.5 if rage else 1.25)
	ci.draw_circle(pos + Vector2(24, -12), 9.0, eye)
	ci.draw_circle(pos + Vector2(-24, -12), 9.0, eye)

	# **예비 동작 경고.** 세 패턴의 모양이 서로 달라야 "뭔가 온다"에서
	# "어디로 피한다"가 된다. 그리기 등급을 낮춰도 이건 항상 그린다.
	var cast: float = b.cast
	if cast > 0.0:
		_boss_warn(ci, b, 1.0 - cast, t)
	if float(b.flash) > 0.0:
		G2.glow(ci, pos, 150.0, P.WHITE, clampf(float(b.flash), 0.0, 0.5))


static func _boss_warn(ci: CanvasItem, b: Dictionary, p: float, t: float) -> void:
	var o: Vector2 = b.pos
	var c := P.a(P.hdr(P.VENOM, 1.25), 0.35 + 0.45 * p)
	match int(b.pattern):
		0:  # 부채꼴 — 겨눈 쪽으로 퍼진다
			var base: float = Vector2(b.dv).angle()
			for i in 5:
				var a := base + (float(i) / 4.0 - 0.5) * 0.9
				ci.draw_line(o, o + Vector2(cos(a), sin(a)) * (260.0 * p), c, 2.4, true)
		1:  # 고리 — 사방. 옆으로 빠져야 한다
			ci.draw_arc(o, 40.0 + 180.0 * p, 0.0, TAU, 34, c, 3.0, true)
		_:  # 세 줄기 — 곧게 떨어진다
			for i in 3:
				var x := o.x + (i - 1) * 180.0
				ci.draw_line(Vector2(x, o.y), Vector2(x, o.y + 900.0 * p), c, 3.4, true)

# ==================== 탄 ====================

## 아군 브레스. `st` 로 모양이 갈린다.
##
## **화룡의 불줄기는 알갱이가 아니라 기둥이다.** 원작 화면에서 화염이 화면 폭의
## 1/4쯤 되는 굵기로 위까지 이어져 있다 — 동그라미를 띄엄띄엄 그리면 아무리
## 피해가 세도 "쏘는 맛"이 안 난다.
static func breath(ci: CanvasItem, b: Dictionary) -> void:
	var pos: Vector2 = b.pos
	var col: Color = b.col
	var w: float = b.w
	match String(b.st):
		"flame":
			G2.glow(ci, pos, w * 2.2, col, 0.42)
			# 세로로 길쭉한 덩어리 — 이어 붙으면 하나의 기둥으로 보인다.
			ci.draw_circle(pos, w, P.hdr(col, 1.3))
			ci.draw_circle(pos - Vector2(0, w * 0.75), w * 0.92, P.hdr(col, 1.3))
			ci.draw_circle(pos, w * 0.48, P.hdr(P.WHITE, 1.25))
		"bolt":
			var v: Vector2 = Vector2(b.vel).normalized() * (w * 2.6)
			G2.glow(ci, pos, w * 2.2, col, 0.34)
			ci.draw_line(pos - v, pos + v, P.hdr(col, 1.35), w * 0.85, true)
			ci.draw_line(pos - v * 0.5, pos + v * 0.5, P.hdr(P.WHITE, 1.2), w * 0.38, true)
		"spear":
			var d: Vector2 = Vector2(b.vel).normalized()
			var n := Vector2(-d.y, d.x)
			var ln: float = w * 3.4
			G2.glow(ci, pos, w * 2.2, col, 0.32)
			G2.body(ci, PackedVector2Array([
				pos + d * ln, pos + n * w, pos - d * ln + n * w * 0.4,
				pos - d * ln - n * w * 0.4, pos - n * w]),
				P.hdr(col, 1.25), 1.2, P.a(P.WHITE, 0.5))


## **적이 쏜 것은 분홍 하나로 통일한다.** 브레스(드래곤 색)에도 금화(금색)에도
## 안 쓰는 색이라야 "분홍은 피한다"가 굳는다. 색만으로는 부족해서 검은 테두리와
## 맥동 고리로 형태까지 다르게 한다.
static func foe_bullet(ci: CanvasItem, pos: Vector2, t: float) -> void:
	var r := D.E_BULLET_R
	G2.glow(ci, pos, r * 2.6, P.VENOM, 0.34)
	ci.draw_circle(pos, r + 1.8, P.a(P.LINE, 0.8))
	ci.draw_circle(pos, r, P.hdr(P.VENOM, 1.2))
	ci.draw_circle(pos, r * 0.44, P.hdr(P.VENOM_HI, 1.25))
	ci.draw_arc(pos, r + 4.0 + sin(t * 8.0) * 1.6, 0.0, TAU, 16,
			P.a(P.VENOM_HI, 0.4), 1.2, true)

# ==================== 아이템 ====================

## **아이템은 실루엣으로 갈린다** — 금화는 동그라미, P 는 육각, 시간제는 마름모.
## 색만 다르면 금화가 수십 개 깔린 구간에서 통째로 묻힌다.
static func coin(ci: CanvasItem, pos: Vector2, t: float, ph: float) -> void:
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


## 시간제 아이템 넷. **글자 하나로 갈라 둔다** — 넷을 색만 다른 마름모로 두면
## 무엇을 주웠는지 화면에서 못 읽는다.
static func item_buff(ci: CanvasItem, pos: Vector2, t: float, kind: String) -> void:
	var r := D.ITEM_R * 1.15
	var pts := PackedVector2Array([
		pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)])
	G2.glow(ci, pos, r * 2.4, P.BUFF, 0.38 + 0.1 * sin(t * 6.0))
	G2.body(ci, pts, P.hdr(P.BUFF, 1.18), 1.8)
	var mark := "?"
	match kind:
		"dual": mark = "II"
		"magnet": mark = "M"
		"hyper": mark = "H"
		"double": mark = "x2"
	G2.text_mid(ci, pos, mark, 14.0, P.LINE)

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


## 떠오르는 글자(배율 · 점수 · 아이템 이름).
## `draw_string` 은 비싸므로 **배율이 붙었을 때만** 띄운다([World] 가 거른다).
static func pop(ci: CanvasItem, pos: Vector2, p: float, text: String, col: Color) -> void:
	var a := 1.0 - G2.smooth(p)
	G2.text_mid(ci, pos - Vector2(0, p * 46.0), text, 17.0, P.a(col, a))

# ==================== 배경 ====================

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


static func scenery(ci: CanvasItem, w: float, h: float, scroll: float, zone: int,
		t: float) -> void:
	var z := zone % 3
	if z == 2:
		_stars(ci, w, h, scroll, t)
	else:
		_ground(ci, w, h, scroll, z)


static func _stars(ci: CanvasItem, w: float, h: float, scroll: float, t: float) -> void:
	for layer in 3:
		var spd := 0.22 + layer * 0.34
		var span := h + 80.0
		for i in 26:
			var sx := _hash(i * 7 + layer * 131) * w
			var base := _hash(i * 13 + layer * 977) * span
			var sy := fposmod(base + scroll * spd, span) - 40.0
			var r := 0.9 + layer * 0.7
			var tw := 0.5 + 0.5 * sin(t * 2.4 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy), r, P.a(P.hdr(P.WHITE, 1.1), 0.28 + 0.42 * tw))


## **지형은 화면 전체에 깔린다.**
##
## 처음에는 좌우 가장자리에만 덩어리를 흘렸는데, 그러면 가운데가 텅 빈 하늘이라
## 속도감이 전혀 안 났다 — 원작은 사막이면 야자수와 바위, 협곡이면 죽은 나무와
## 갈라진 땅이 **화면 가득** 흘러간다. 다만 무늬는 **어둡고 낮은 대비**로 둔다.
## 밝게 그리면 적과 탄이 묻힌다.
static func _ground(ci: CanvasItem, w: float, h: float, scroll: float, z: int) -> void:
	var col: Color = P.GROUND[z]
	var dk: Color = P.GROUND_D[z]
	var span := h + 300.0

	# 1) 큰 지형 덩어리 — 좌우 가장자리에서 안쪽으로 파고든다
	for side in 2:
		for i in 7:
			var seed := i * 31 + side * 613 + z * 97
			var yy := fposmod(_hash(seed) * span + scroll * 0.5, span) - 150.0
			var ww := w * (0.16 + _hash(seed + 5) * 0.14)
			var hh := 110.0 + _hash(seed + 9) * 150.0
			var cx := -ww * 0.2 if side == 0 else w + ww * 0.2
			var pts := PackedVector2Array()
			for k in 7:
				var a := PI * k / 6.0 + (0.0 if side == 0 else PI)
				var rr := 1.0 + _hash(seed + k * 17) * 0.3
				pts.append(Vector2(cx + cos(a) * ww * rr, yy + sin(a) * hh * rr))
			G2.fill_fan(ci, pts, dk if (i % 2 == 0) else col)

	# 2) 잔물체 — 야자수(초원) · 죽은 나무(협곡). 화면 전체에 흩는다.
	for i in 16:
		var sd := i * 71 + z * 311
		var x := _hash(sd) * w
		var yy2 := fposmod(_hash(sd + 3) * span + scroll * 0.62, span) - 150.0
		var sc := 0.7 + _hash(sd + 8) * 0.6
		if z == 0:
			_palm(ci, Vector2(x, yy2), sc)
		else:
			_dead_tree(ci, Vector2(x, yy2), sc)

	# 3) 작은 바위 — 바닥에 결을 준다
	for i in 14:
		var sd2 := i * 53 + z * 907 + 11
		var x2 := _hash(sd2) * w
		var y2 := fposmod(_hash(sd2 + 4) * span + scroll * 0.55, span) - 150.0
		var r2 := 6.0 + _hash(sd2 + 6) * 12.0
		ci.draw_circle(Vector2(x2, y2), r2, P.a(dk, 0.75))

	# 위쪽은 하늘에 녹인다 — 적이 나타나는 자리를 부드럽게.
	ci.draw_rect(Rect2(0, 0, w, h * 0.14), P.a(P.SKY[z][0], 0.5), true)


static func _palm(ci: CanvasItem, c: Vector2, sc: float) -> void:
	var trunk := P.a(Color8(84, 62, 38), 0.85)
	var leaf := P.a(Color8(46, 92, 48), 0.85)
	ci.draw_line(c, c + Vector2(3, -30) * sc, trunk, 4.0 * sc, true)
	for i in 5:
		var a := PI + PI * i / 4.0
		ci.draw_line(c + Vector2(3, -30) * sc,
				c + Vector2(3, -30) * sc + Vector2(cos(a), sin(a) * 0.7) * 20.0 * sc,
				leaf, 3.4 * sc, true)


static func _dead_tree(ci: CanvasItem, c: Vector2, sc: float) -> void:
	var bark := P.a(Color8(58, 44, 34), 0.85)
	var top := c + Vector2(0, -34) * sc
	ci.draw_line(c, top, bark, 4.0 * sc, true)
	ci.draw_line(top, top + Vector2(-14, -12) * sc, bark, 2.6 * sc, true)
	ci.draw_line(top, top + Vector2(13, -14) * sc, bark, 2.6 * sc, true)
	ci.draw_line(c + Vector2(0, -18) * sc, c + Vector2(-16, -24) * sc, bark, 2.2 * sc, true)


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
