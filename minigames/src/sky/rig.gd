class_name SaRig
extends RefCounted

## 보스 모션 뼈대 · 작은 포탑 그리기.
##
## **움직이는 조각은 공격의 예고다.** 월드가 다음 공격(`move`)과 그 공격까지의 진행도(`tell`, 0 → 1)를
## 넘겨주면, 그 공격에 묶인 조각이 미리 움직인다 — 폭탄창이 열리면 폭탄, 용머리 입이 빛나면 브레스,
## 포대가 솟으면 일제 사격. 쏜 직후(`SaArt.kick`)에는 같은 조각이 잠깐 열린 채 남아 "방금 저기서 나왔다" 를 보인다.
##
## 조각 자리 · 크기 · 그림 이름은 전부 [SaD] 의 `BOSS_RIG` · `BOSS_GUNS` 에 있다. **조각 그림이 없으면 몸체는 안 그리고
## 예고 빛만** 그린다 — 벡터 조각을 몸통 그림 위에 얹으면 "붙여 넣은 상자" 로 보였다(작은 포탑만 예외: 쏘는 적이라 보여야 한다).
## **그림을 새로 뽑으면 여기 코드가 아니라 그 표만 고친다.**

static var move := ""      ## 다음 공격(SaWorld._next_move)
static var tell := 0.0     ## 그 공격까지의 예고 진행도(0 → 1)
static var last := ""      ## 방금 쏜 공격 — kick 동안 그 조각이 열린 채 남는다


## 그 조각이 지금 얼마나 "열려" 있어야 하나(0 ~ 1). 예고 중이거나 방금 쐈으면 열린다.
static func _open(m: String) -> float:
	var a := smoothstep(0.0, 1.0, tell) if move == m else 0.0
	var b := SaArt.kick if last == m else 0.0
	return maxf(a, b)


## 보스 로컬 좌표(이미 draw_set_transform 이 걸린 상태)에서 조각을 그린다.
## `tgt` 는 플레이어 자리를 로컬로 옮긴 것. `arg` 는 보스가 넘겨주는 값(성채 성문 = 체력이 깎인 만큼).
static func parts(ci: CanvasItem, key: String, t: float, arg: float, tgt: Vector2) -> void:
	if not SaD.BOSS_RIG.has(key):
		return
	for p in SaD.BOSS_RIG[key]:
		var at: Array = SaD.BOSS[key].parts if p.at is String else p.at
		var tx := SaArt.img(String(p.tex))
		var m: String = p.get("move", "")
		match String(p.kind):
			"prop":
				for i in at.size():
					_prop(ci, tx, at[i], float(p.size), t, i)
			"doors":
				var o := _open(m)
				for i in at.size():
					_doors(ci, tx, at[i], p.size, o, t, i)
			"head":
				for c in at:
					_head(ci, tx, c, float(p.size), tgt, _open(m), t)
			"turret":
				for c in at:
					_turret(ci, tx, c, float(p.size), tgt, _open(m))
			"iris":
				for c in at:
					_iris(ci, tx, c, float(p.size), _open(m), t)
			"gate":
				for c in at:
					_gate(ci, tx, c, p.size, clampf(arg, 0.0, 1.0), t)
			"cannons":
				var r := _open(m)
				for i in at.size():
					_cannon(ci, tx, at[i], float(p.size), tgt, r, i)
			"missiles":
				for i in at.size():
					_missiles(ci, tx, at[i], float(p.size), m, i)


## 프로펠러 — 위에서 보면 흐린 원반에 날 두 개가 돈다.
static func _prop(ci: CanvasItem, tx: Texture2D, c: Vector2, r: float, t: float, i: int) -> void:
	var a := t * 28.0 + i * 1.3
	if tx != null:
		SaArt.quad(ci, tx, c, r * 2.0, a, Color(1, 1, 1, 0.85))
		return
	# 그림이 없으면 안 그린다 — 지금 몸통 그림(제트기)에는 프로펠러가 없어서 벡터 날개가 허공에서 돌았다


## 좌우로 미끄러지는 문 한 쌍. 열리면 안쪽이 빛난다(무엇이 나오는 곳인지).
static func _doors(ci: CanvasItem, tx: Texture2D, c: Vector2, size: Vector2, o: float, t: float,
		i: int) -> void:
	var hw := size.x * 0.5
	# 그림이 없으면 **열릴 때만** 그린다 — 닫힌 벡터 문을 몸통 그림 위에 늘 얹으면 "붙여 넣은 상자" 로 보였다
	if tx == null and o <= 0.02:
		return
	ci.draw_rect(Rect2(c - size * 0.5, size), Color(0.05, 0.04, 0.06, 0.9), true)
	if o > 0.02:
		SaG2.glow(ci, c, maxf(size.x, size.y) * (0.6 + 0.5 * o), SaP.HOT, 0.25 + 0.5 * o)
	var slide := hw * o
	for s in [-1.0, 1.0]:
		var dc := c + Vector2(s * (hw * 0.5 + slide), 0)
		var ds := Vector2(hw, size.y)
		if tx != null:
			SaArt.quad_box(ci, tx, dc, ds, 0.0 if s < 0.0 else PI)
		else:
			var r := Rect2(dc - ds * 0.5, ds)
			ci.draw_rect(r, SaP.IRON_D, true)
			ci.draw_rect(r, SaP.LINE, false, 1.2)
			ci.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y),
					SaP.a(SaP.HOT, 0.5), 1.4)


## 용머리 — 플레이어 쪽으로 고개를 돌리고, 브레스 직전에 입이 달아오른다.
static func _head(ci: CanvasItem, tx: Texture2D, c: Vector2, size: float, tgt: Vector2, o: float,
		t: float) -> void:
	var d := tgt - c
	var ang := clampf(wrapf(d.angle() - PI * 0.5, -PI, PI), -0.6, 0.6) + PI * 0.5
	var dir := Vector2(cos(ang), sin(ang))
	if tx != null:
		SaArt.quad(ci, tx, c, size, ang + PI * 0.5)
	var mouth := c + dir * size * 0.42
	var k := o * (0.85 + 0.15 * sin(t * 30.0))
	if k > 0.02:
		SaG2.glow(ci, mouth, size * (0.35 + 0.55 * k), SaP.VENOM, 0.25 + 0.55 * k)
		ci.draw_circle(mouth, size * 0.12 * k + 1.0, SaP.hdr(SaP.VENOM_HI, 1.1))


## 겨누는 포탑 — 쏘기 직전 포구가 빛나고, 쏘면 물러난다(SaArt._gun 이 반동을 맡는다).
static func _turret(ci: CanvasItem, tx: Texture2D, c: Vector2, size: float, tgt: Vector2,
		o: float) -> void:
	var d := tgt - c
	var ang := clampf(wrapf(d.angle() - PI * 0.5, -PI, PI), -1.3, 1.3) + PI * 0.5
	var dir := Vector2(cos(ang), sin(ang))
	# 그림이 없으면 포구 빛만 — 몸통 그림 가운데에 이미 포가 있다
	if tx != null:
		SaArt._gun(ci, tx, c, size, tgt, 1.3)
	if o > 0.02:
		SaG2.glow(ci, c + dir * size * 0.62, size * 0.3 * (0.5 + o), SaP.HOT, 0.6 * o)


## 가운데 조리개 — 열리면 레이저(분홍 = 적의 것). 닫힌 동안은 작은 불씨만.
static func _iris(ci: CanvasItem, tx: Texture2D, c: Vector2, size: float, o: float, t: float) -> void:
	var r := size * 0.5
	if tx != null:
		SaArt.quad(ci, tx, c, size * (1.0 - 0.25 * o), t * 0.6)
	# 그림이 없으면 빛만 — 벡터 날을 원반 그림 위에 얹으면 따로 논다
	var k := 0.15 + 0.85 * o
	SaG2.glow(ci, c, r * (0.5 + 1.2 * k), SaP.VENOM, 0.15 + 0.5 * k)
	ci.draw_circle(c, r * 0.28 * k + 2.0, SaP.hdr(SaP.VENOM, 1.1))
	ci.draw_circle(c, r * 0.13 * k + 1.0, SaP.VENOM_HI)


## 성문 — 체력이 깎일수록 열려 안쪽 핵이 드러난다. **열린 만큼이 "지금 때릴 곳" 이다.**
static func _gate(ci: CanvasItem, tx: Texture2D, c: Vector2, size: Vector2, o: float, t: float) -> void:
	var core := SaP.FOE_MARK
	SaG2.glow(ci, c, size.x * (0.35 + 0.6 * o), core, 0.2 + 0.5 * o + 0.08 * sin(t * 3.0))
	ci.draw_circle(c, size.y * 0.28 * o + 3.0, SaP.hdr(Color8(255, 90, 70), 1.1))
	ci.draw_circle(c, size.y * 0.13 * o + 1.5, Color8(255, 224, 210))
	if tx != null:   # 문짝 그림이 없으면 빛만 — 천성 그림에 성문이 이미 있어서 벡터 상자를 얹으면 붙여 넣은 것처럼 보인다
		_doors(ci, tx, c, size, o * 0.85, t, 0)


## 미사일 한 쌍 — 예고 동안 해치 안에서 솟아오르고(작게 → 크게), 쏘는 순간 앞(+y)으로 날아가며 사라진다.
## 미사일 그림(sky_cheolgap_missile, 탄두가 위)이 없으면 벡터. 몸통에 이미 있는 것이 아니라 새로 나오는 것이라 늘 그린다.
static func _missiles(ci: CanvasItem, tx: Texture2D, c: Vector2, size: float, m: String, i: int) -> void:
	var rise := smoothstep(0.0, 1.0, tell) if move == m else 0.0
	var fly := SaArt.kick if last == m else 0.0
	if rise <= 0.0 and fly <= 0.0:
		return
	for k in 2:
		var p := c + Vector2((k - 0.5) * size * 0.55, 0)
		var sc := 0.4 + 0.6 * maxf(rise, 1.0 if fly > 0.0 else 0.0)
		var al := 1.0
		if fly > 0.0:
			var u := 1.0 - fly                       # 0 → 1 로 날아간다
			p += Vector2(0, u * 160.0)
			al = 1.0 - u
			SaG2.glow(ci, p - Vector2(0, size * 0.6), size * 0.8, SaP.HOT, 0.55 * al)
		if tx != null:
			SaArt.quad(ci, tx, p, size * sc, PI, Color(1, 1, 1, al))
		else:
			var w := size * 0.16 * sc
			var h := size * 0.5 * sc
			ci.draw_rect(Rect2(p.x - w, p.y - h, w * 2, h * 2), Color(0.62, 0.66, 0.6, al))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-w, h), p + Vector2(w, h), p + Vector2(0, h + w * 2.4)]),
					Color(0.85, 0.25, 0.2, al))
			ci.draw_rect(Rect2(p.x - w, p.y - h, w * 2, h * 2), Color(0.1, 0.1, 0.14, al), false, 1.0)
		if rise > 0.5 and fly <= 0.0:
			SaG2.glow(ci, p - Vector2(0, size * 0.5 * sc), size * 0.35, SaP.HOT, 0.3 * rise)


## 솟아오르는 포대 —평소엔 뚜껑만 보이다가 일제 사격 직전 포신이 올라온다.
static func _cannon(ci: CanvasItem, tx: Texture2D, c: Vector2, size: float, tgt: Vector2, r: float,
		i: int) -> void:
	ci.draw_circle(c, size * 0.32, Color(0.05, 0.05, 0.07, 0.85))
	if r < 0.03:
		ci.draw_arc(c, size * 0.32, 0.0, TAU, 14, SaP.LINE, 1.2, true)
		return
	var d := tgt - c
	var ang := clampf(wrapf(d.angle() - PI * 0.5, -PI, PI), -0.8, 0.8) + PI * 0.5
	var sz := size * (0.55 + 0.45 * r)
	if tx != null:
		SaArt.quad(ci, tx, c, sz, ang + PI * 0.5, Color(1, 1, 1, clampf(r * 2.0, 0.0, 1.0)))
	else:
		SaArt.nav_turret(ci, c, sz * 0.22, ang - PI * 0.5, 2, Color8(103, 114, 138))
	SaG2.glow(ci, c + Vector2(cos(ang), sin(ang)) * sz * 0.6, sz * 0.4 * r, SaP.HOT, 0.5 * r)

# ==================== 강신 — 팔이 움직이는 몸통 ====================

## 팔 없는 몸통 그림(`sky_boss_gangsin_body`)이 있을 때만 쓴다. 없으면 false — 지금처럼 한 장짜리 로봇.
## 팔은 **실제로 쏘는 방향을 가리킨다** — 월드가 탄을 내는 각도(`arm_angle`)를 같이 본다.
## 쏘기 직전(예고)에는 팔을 뒤로 젖혔다가, 쏘면 반동으로 물러난다.
static func robot_body(ci: CanvasItem, size_box: Vector2, rot: float, m: float, t: float,
		pdead: int) -> bool:
	var body := SaArt.img("sky_boss_gangsin_body")
	if body == null or m <= 0.0:
		return false
	var arm := SaArt.img("sky_boss_gangsin_arm")
	var at: Array = SaD.BOSS.robot.parts
	var a := Color(1, 1, 1, m)
	# 팔은 몸통보다 먼저 — 어깨가 팔 뿌리를 덮어야 붙어 보인다
	for i in at.size():
		if SaArt.down(pdead, i):
			continue
		var s := -1.0 if i == 0 else 1.0
		var ang := arm_angle(s, t) - s * 0.35 * smoothstep(0.0, 1.0, tell if move == "arms" else 0.0)
		var dir := Vector2(cos(ang), sin(ang))
		var len := SaD.ARM_LEN * 1.25
		var base: Vector2 = (at[i] as Vector2) - dir * len * 0.12 * SaArt.kick
		if arm != null:
			SaArt.quad(ci, arm, base + dir * len * 0.5, len, ang + PI * 0.5, a)
		else:
			SaArt.nav_turret(ci, base, 10.0, ang - PI * 0.5, 1, Color8(150, 40, 50))
	SaArt.quad_box(ci, body, Vector2.ZERO, size_box, rot, a)
	return true


## 팔이 가리키는(= 탄이 나가는) 각도. **월드의 `_boss_fire` 가 이 함수를 그대로 쓴다.**
static func arm_angle(s: float, t: float) -> float:
	# 원래 그림 구도 — 바깥 아래(왼팔은 왼쪽 아래 · 오른팔은 오른쪽 아래)를 기준으로 좌우를 훑는다
	return PI * 0.5 - s * (0.45 + sin(t * 1.6) * 0.35)

# ==================== 작은 포탑(월드 좌표) ====================

## 보스 몸통 위 작은 포탑들. 쏘기 직전 포구가 **분홍**으로 빛난다(적의 탄 색 — "피한다").
static func guns(ci: CanvasItem, boss: Dictionary, t: float, player: Vector2) -> void:
	if boss.is_empty() or boss.guns.is_empty():
		return
	var tx := SaArt.img(String(SaD.BOSS_GUNS[boss.key].tex))
	var sc: float = boss.scale
	for i in boss.guns.size():
		var g: Dictionary = boss.guns[i]
		var gp: Vector2 = boss.pos + (g.at as Vector2) * sc
		var size := SaD.GUN_SIZE * sc
		if g.dead:
			SaArt._scorch(ci, gp, size * 0.35, t, i)
			continue
		var ang := (player - gp).angle()
		if tx != null:
			SaArt.quad(ci, tx, gp, size, ang + PI * 0.5)
		else:
			SaArt.nav_turret(ci, gp, size * 0.22, ang - PI * 0.5, 2, SaP.IRON)
		var k := clampf(1.0 - g.cd / SaD.GUN_TELL, 0.0, 1.0)
		if k > 0.0:
			var tip := gp + Vector2(cos(ang), sin(ang)) * size * 0.5
			SaG2.glow(ci, tip, size * (0.3 + 0.4 * k), SaP.VENOM, 0.25 + 0.5 * k)
