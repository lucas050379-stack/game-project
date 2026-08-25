class_name World
extends RefCounted

## 한 판의 상태와 규칙.
##
## 적·탄·금화는 노드를 만들지 않고 [Dictionary] 배열로 들고 [method draw] 한 곳에서 그린다.
## 수백 개를 노드로 만들면 생성·해제 비용만으로 폰에서 프레임이 무너진다.
##
## **적을 죽일 때 배열에서 바로 빼지 않는다** — `dead` 표시만 남기고 프레임 끝의
## `_sweep()` 이 정리한다. 판정 루프 도중에 `remove_at` 하면 뒤쪽 색인이 밀려
## 엉뚱한 것을 때린다.

enum St { PLAY, OVER }

var st := St.PLAY
var t := 0.0

# ---- 화면 ----
var w := D.REF_W
var h := D.REF_H

# ---- 진행 ----
var m := 0.0                 ## 달린 거리(m). 이 게임의 점수다.
var scroll := 0.0            ## 배경이 흘러간 픽셀
var zone_i := 0
var wave_i := 0
var banner := 0.0            ## 구간 배너 남은 시간
var next_power := D.POWER_FIRST

# ---- 드래곤 ----
var dragon := 0
var pos := Vector2.ZERO
var power := 0
var shields := 0
var invuln := 0.0
var fire_cd := 0.0
var tilt := 0.0              ## 기울기(-1~1). 그림에만 쓴다.

# ---- 벌이 ----
var gold := 0
var kills := 0
var coins_taken := 0
## soak 계측용 — 뿌린 체력 대비 실제로 넣은 피해. 화력이 모자란 것인지
## 그냥 안 맞는 것인지를 가른다(추측하면 반드시 엉뚱한 수치를 만진다).
var hp_spawned := 0.0
var dmg_dealt := 0.0
var spawned := 0

# ---- 배열 ----
var pb: Array[Dictionary] = []      ## 아군 브레스
var foes: Array[Dictionary] = []
var eb: Array[Dictionary] = []      ## 적 탄
var items: Array[Dictionary] = []   ## 금화 · P
var booms: Array[Dictionary] = []
var pops: Array[Dictionary] = []    ## 떠오르는 +금액

## 알갱이는 **자리를 돌려 쓴다.** `pop_front()` 는 배열을 통째로 앞으로 당기는
## 연산이라 상한이 꽉 찬 채로 초당 수백 번 불리면 그것만으로 프레임을 먹는다.
const SPARK_MAX := 96
var sparks: Array[Dictionary] = []
var spark_i := 0

var shake := 0.0
var over_t := 0.0
## 무인 주행 전용. 가만히 있으면 금방 죽어서 soak 검산이 안 되므로 테스트에서만 켠다.
var auto := false
var rng := RandomNumberGenerator.new()


func _init(dragon_idx: int = 0) -> void:
	dragon = clampi(dragon_idx, 0, D.DRAGON.size() - 1)
	shields = D.shields()
	invuln = D.START_INVULN
	rng.randomize()
	sparks.resize(SPARK_MAX)
	for i in SPARK_MAX:
		sparks[i] = {life = 0.0, pos = Vector2.ZERO, vel = Vector2.ZERO, col = P.WHITE}


func setup(vw: float, vh: float) -> void:
	w = vw
	h = vh
	if pos == Vector2.ZERO:
		pos = Vector2(w * 0.5, h * D.HERO_Y)
	else:
		pos.y = h * D.HERO_Y
		pos.x = clampf(pos.x, _margin(), w - _margin())


func _margin() -> float:
	return 34.0


func dm() -> Dictionary:
	return D.DRAGON[dragon]


func col() -> Color:
	return P.dragon(int(dm().col), 3)


## 테스트 빌드 전용 — 먼 거리부터 시작한다. 뒤쪽 난이도를 볼 때마다 5분씩
## 달리지 않으려고 둔다. **파워는 만렙으로 둔다** — 그 거리를 실제로 달려왔다면
## P 가 이미 다 나온 뒤이고, 맨몸으로 두면 재는 값이 표와 안 맞는다.
func skip_to(dist_m: float) -> void:
	m = maxf(0.0, dist_m)
	scroll = m * D.PX_PER_M
	power = D.POWER_MAX
	zone_i = int(m / D.ZONE_M) % D.ZONE.size()
	wave_i = _wave_index_for(fposmod(m, D.ZONE_M) / D.ZONE_M)
	next_power = (floorf((m - D.POWER_FIRST) / D.POWER_EVERY) + 1.0) * D.POWER_EVERY \
			+ D.POWER_FIRST


## 진행도를 감았을 때 **지나간 웨이브를 지나간 것으로 친다.**
## 색인을 안 밀면 다음 프레임에 밀린 웨이브가 한꺼번에 쏟아진다.
func _wave_index_for(prog: float) -> int:
	var table: Array = D.ZONE[zone_i].table
	var i := 0
	while i < table.size() and float(table[i].at) <= prog:
		i += 1
	return i

# ==================== 진행 ====================

## `dir` 은 키보드/패드(-1~1), `target_x` 는 손가락이 끌고 있는 x(음수면 안 쓴다).
func step(dt: float, dir: float, target_x: float) -> void:
	t += dt
	shake = maxf(0.0, shake - dt * 3.4)
	if st == St.OVER:
		over_t += dt
		_step_fx(dt)
		return

	# 거리와 배경은 한 값에서 나온다 — 둘을 따로 세면 반드시 어긋난다.
	scroll += D.SCROLL * dt
	var prev_m := m
	m = scroll / D.PX_PER_M
	banner = maxf(0.0, banner - dt)

	_step_zone(prev_m)
	_step_player(dt, dir, target_x)
	_step_breath(dt)
	_step_foes(dt)
	_step_foe_bullets(dt)
	_step_items(dt)
	_step_fx(dt)
	_sweep()


func zone() -> Dictionary:
	return D.ZONE[zone_i % D.ZONE.size()]


func _step_zone(prev_m: float) -> void:
	var zi := int(m / D.ZONE_M) % D.ZONE.size()
	if zi != zone_i:
		zone_i = zi
		wave_i = 0
		banner = 2.2
	var prog := fposmod(m, D.ZONE_M) / D.ZONE_M
	var table: Array = zone().table
	while wave_i < table.size() and prog >= float(table[wave_i].at):
		_spawn(table[wave_i])
		wave_i += 1

	# P 는 난수가 아니라 거리로 나온다 — 판마다 화력 곡선이 같아야 한다.
	if m >= next_power:
		next_power += D.POWER_EVERY
		_add_item("power", rng.randf_range(_margin() + 40.0, w - _margin() - 40.0), -40.0)

# ==================== 스폰 ====================

func _spawn(spec: Dictionary) -> void:
	var kind := String(spec.kind)
	var n := int(spec.n)
	var gap := float(spec.gap)
	match kind:
		"line":
			_row(String(spec.k), n, gap, -60.0)
		"vee":
			var half := (n - 1) * 0.5
			for i in n:
				var off := i - half
				_foe(String(spec.k), w * 0.5 + off * gap, -60.0 - absf(off) * 52.0)
		"stream":
			# y 를 벌려 두면 그대로 시간차가 된다. 타이머를 따로 둘 필요가 없다.
			var sx := rng.randf_range(_margin() + 50.0, w - _margin() - 50.0)
			for i in n:
				_foe(String(spec.k), sx, -60.0 - i * gap)
		"wall":
			_wall()
		"gate":
			# 관문 — 구간 끝의 밀집 편대. 두 줄로 어긋나게 세운다.
			for i in n:
				var x := _margin() + 30.0 + (w - _margin() * 2.0 - 60.0) * i / maxf(1.0, n - 1.0)
				_foe(String(spec.k), x, -60.0 - (i % 2) * gap)
		"coins":
			_row_items(n, gap, 0.0)
		"arc":
			var half2 := (n - 1) * 0.5
			for i in n:
				var o := i - half2
				_add_item("coin", w * 0.5 + o * gap, -40.0 - (half2 * half2 - o * o) * 9.0)
		"snake":
			var amp := (w - _margin() * 2.0) * 0.34
			for i in n:
				_add_item("coin", w * 0.5 + sin(i * 0.62) * amp, -40.0 - i * gap)


func _row(k: String, n: int, gap: float, y: float) -> void:
	var half := (n - 1) * 0.5
	for i in n:
		_foe(k, w * 0.5 + (i - half) * gap, y)


func _row_items(n: int, gap: float, y: float) -> void:
	var half := (n - 1) * 0.5
	for i in n:
		_add_item("coin", w * 0.5 + (i - half) * gap, y - 40.0)


## 바위 벽 — 화면을 가로로 채우고 **통로 한 칸만 비운다.**
## 통로 폭은 드래곤이 여유 있게 지나갈 만큼 둔다. 좁히면 난이도가 아니라 운이 된다.
func _wall() -> void:
	var span := w - _margin() * 2.0
	var slots := 5
	var open := rng.randi_range(0, slots - 1)
	var cw := span / slots
	for i in slots:
		if i == open:
			continue
		_foe("rock", _margin() + cw * (i + 0.5), -70.0)


func _foe(k: String, x: float, y: float) -> void:
	if not D.ENEMY.has(k):
		return
	var d: Dictionary = D.ENEMY[k]
	var base_hp := float(d.hp)
	foes.append({
		art = String(d.art),
		pos = Vector2(clampf(x, 18.0, w - 18.0), y),
		x0 = clampf(x, 18.0, w - 18.0),
		r = float(d.r),
		speed = float(d.speed),
		move = String(d.move),
		gold = int(d.gold),
		fire = float(d.fire),
		fire_t = float(d.fire) * rng.randf_range(0.4, 1.0),
		cast = 0.0,
		dv = Vector2.DOWN,
		# hp 0 은 부술 수 없다는 뜻이다. 체력 배율을 곱해도 0 이라 자연히 유지된다.
		hp = base_hp * D.hp_at(m),
		max_hp = base_hp * D.hp_at(m),
		solid = base_hp <= 0.0,
		ph = rng.randf() * TAU,
		flash = 0.0,
		hits = {},
		dead = false,
	})
	if base_hp > 0.0:
		spawned += 1
		hp_spawned += base_hp * D.hp_at(m)


func _add_item(kind: String, x: float, y: float) -> void:
	items.append({
		kind = kind,
		pos = Vector2(clampf(x, 24.0, w - 24.0), y),
		ph = rng.randf() * TAU,
		dead = false,
	})

# ==================== 드래곤 ====================

func _step_player(dt: float, dir: float, target_x: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	var spd := float(dm().speed) * D.speed_mul()

	if auto:
		target_x = _safe_x()
	if target_x >= 0.0:
		# 손가락이 끌고 있을 때. **드래그는 즉각적이어야 한다** — 속도 상한만 두고
		# 이징을 걸지 않는다. 부드럽게 따라가게 하면 피하려던 순간에 안 피해진다.
		var dx := clampf(target_x - pos.x, -spd * 2.4 * dt, spd * 2.4 * dt)
		pos.x += dx
		tilt = lerpf(tilt, clampf(dx / maxf(0.001, spd * dt), -1.0, 1.0), dt * 12.0)
	else:
		pos.x += dir * spd * dt
		tilt = lerpf(tilt, dir, dt * 10.0)
	pos.x = clampf(pos.x, _margin(), w - _margin())
	pos.y = h * D.HERO_Y

	fire_cd -= dt
	if fire_cd <= 0.0:
		fire_cd = _shoot()


## 드래곤마다 브레스가 **자라는 방향**이 다르다. 세기는 `D.POWER_DPS` 로 셋이 같다 —
## 다른 것은 그 화력을 굵게 뭉치느냐, 넓게 펴느냐, 앞을 뚫느냐다.
func _shoot() -> float:
	var p := clampi(power, 0, D.POWER_MAX)
	var k: float = D.POWER_DPS[p]
	var dmg := D.BASE_DMG * k * D.dmg_mul()
	var cd := D.BASE_CD / D.rate_mul()
	var c := col()
	match dragon:
		0:  # 화룡 — 집중. 한 줄기가 계속 두꺼워진다.
			_bullet(pos + Vector2(0, -34), Vector2(0, -980.0), "flame", c,
					dmg, 12.0 + p * 4.0, false)
			return cd
		1:  # 뇌룡 — 확산. 폭을 먼저 정하고 발수로 나눈다.
			#     각도 간격을 레벨마다 키우면 만렙에서 그냥 벌어지기만 한다.
			var n: int = [2, 2, 3, 4, 5, 6][p]
			var span := 0.10 if p < 2 else 0.34
			for i in n:
				var f := 0.0 if n == 1 else (float(i) / float(n - 1) - 0.5)
				var a := -PI * 0.5 + f * span
				_bullet(pos + Vector2(f * 22.0, -30), Vector2(cos(a), sin(a)) * 1020.0,
						"bolt", c, dmg / n, 7.0 + p * 1.2, false)
			return cd
		_:  # 빙룡 — 관통. 느린 대신 한 방이 굵고 줄지어 오는 것을 꿴다.
			_bullet(pos + Vector2(0, -36), Vector2(0, -900.0), "spear", c,
					dmg * 1.35, 10.0 + p * 3.0, true)
			return cd * 1.35


func _bullet(p: Vector2, v: Vector2, style: String, c: Color, dmg: float, wd: float,
		pierce: bool) -> void:
	pb.append({pos = p, vel = v, st = style, col = c, dmg = dmg, w = wd,
		pierce = pierce, hits = {}, dead = false})


func _step_breath(dt: float) -> void:
	for b in pb:
		b.pos += b.vel * dt
		if b.pos.y < -80.0 or b.pos.x < -60.0 or b.pos.x > w + 60.0:
			b.dead = true
			continue
		for fi in foes.size():
			var e: Dictionary = foes[fi]
			if e.dead:
				continue
			var rr: float = float(e.r) + float(b.w)
			if b.pos.distance_squared_to(e.pos) > rr * rr:
				continue
			if e.solid:
				# 바위는 못 부순다. 브레스만 사라진다 — 튕기는 표시를 내야
				# "왜 안 죽지"가 아니라 "저건 못 부수는구나"로 읽힌다.
				if not b.pierce:
					b.dead = true
					_spark_burst(b.pos, 3, P.STONE, 120.0)
				break
			if b.pierce:
				# **관통은 같은 표적을 REHIT 간격으로만 때린다.**
				# 없으면 겹쳐 있는 동안 매 프레임 들어가 초당 60번이 된다.
				var last: float = float(b.hits.get(fi, -99.0))
				if t - last < D.REHIT:
					continue
				b.hits[fi] = t
			_hurt(e, float(b.dmg))
			_spark_burst(b.pos, 2, b.col, 160.0)
			if not b.pierce:
				b.dead = true
				break


func _hurt(e: Dictionary, dmg: float) -> void:
	dmg_dealt += minf(dmg, maxf(0.0, float(e.hp)))
	e.hp -= dmg
	e.flash = 0.35
	if e.hp <= 0.0 and not e.dead:
		e.dead = true
		kills += 1
		var g := int(round(float(e.gold) * D.greed_mul()))
		gold += g
		booms.append({pos = e.pos, p = 0.0, size = float(e.r) * 1.5, col = P.FLAME})
		if g > 0:
			pops.append({pos = e.pos, p = 0.0, amount = g})
		_spark_burst(e.pos, 7, P.FLAME, 260.0)

# ==================== 적 ====================

func _step_foes(dt: float) -> void:
	for e in foes:
		if e.dead:
			continue
		e.flash = maxf(0.0, float(e.flash) - dt * 3.0)
		e.pos.y += float(e.speed) * dt
		match String(e.move):
			"wave":
				e.pos.x = float(e.x0) + sin(t * 1.9 + float(e.ph)) * 46.0
			"sway":
				e.pos.x = float(e.x0) + sin(t * 1.2 + float(e.ph)) * 96.0
			"drift":
				e.pos.x = float(e.x0) + sin(t * 0.7 + float(e.ph)) * 26.0
			_:
				pass
		e.pos.x = clampf(e.pos.x, 16.0, w - 16.0)

		if float(e.fire) > 0.0:
			_step_foe_fire(e, dt)

		if e.pos.y > h + 90.0:
			e.dead = true
			continue
		_touch(e)


## **예비 동작 없이 나가는 탄을 만들지 마라.** 즉발이면 피할 방법이 없어서
## 난이도가 아니라 불합리가 된다. 그리고 **방향은 예비 동작이 시작될 때 박아 두고
## 그 뒤로 안 고친다** — 겨냥을 계속 고쳐 잡으면 경고를 보고 피한 사람이 그대로 맞는다.
const CAST := 0.45


func _step_foe_fire(e: Dictionary, dt: float) -> void:
	# 화면 위쪽에 있는 동안은 안 쏜다. 보이지도 않는 데서 날아오면 억울하다.
	if e.pos.y < 40.0:
		return
	if float(e.cast) > 0.0:
		e.cast = maxf(0.0, float(e.cast) - dt / CAST)
		if float(e.cast) <= 0.0:
			eb.append({pos = Vector2(e.pos), vel = Vector2(e.dv) * D.E_BULLET_SPD,
				dead = false})
		return
	e.fire_t = float(e.fire_t) - dt
	if float(e.fire_t) <= 0.0:
		e.fire_t = float(e.fire) * rng.randf_range(0.85, 1.25)
		e.cast = 1.0
		e.dv = (pos - e.pos).normalized()


func _touch(e: Dictionary) -> void:
	if invuln > 0.0:
		return
	var rr: float = float(e.r) + float(dm().hit)
	if pos.distance_squared_to(e.pos) < rr * rr:
		_hit()


func _step_foe_bullets(dt: float) -> void:
	for b in eb:
		b.pos += b.vel * dt
		if b.pos.y > h + 40.0 or b.pos.y < -40.0 or b.pos.x < -40.0 or b.pos.x > w + 40.0:
			b.dead = true
			continue
		if invuln > 0.0:
			continue
		var rr: float = D.E_BULLET_R + float(dm().hit)
		if pos.distance_squared_to(b.pos) < rr * rr:
			b.dead = true
			_hit()


## 부딪혔다. 보호막이 있으면 한 겹이 깨지고, 없으면 그 자리에서 끝난다.
func _hit() -> void:
	if shields > 0:
		shields -= 1
		invuln = D.INVULN
		shake = 1.0
		booms.append({pos = pos, p = 0.0, size = 54.0, col = P.SHIELD})
		_spark_burst(pos, 16, P.SHIELD, 340.0)
		# 깨진 순간 몸에 붙어 있던 탄까지 같이 지운다 — 안 그러면 무적이 끝나기 전에
		# 같은 탄에 또 맞아서 두 겹이 한 번에 날아간다.
		for b in eb:
			if b.pos.distance_to(pos) < 170.0:
				b.dead = true
		return
	st = St.OVER
	over_t = 0.0
	shake = 1.0
	booms.append({pos = pos, p = 0.0, size = 86.0, col = P.FLAME})
	_spark_burst(pos, 26, P.FLAME, 420.0)

# ==================== 금화 · P ====================

func _step_items(dt: float) -> void:
	var mag := D.magnet()
	var take: float = D.ITEM_R + float(dm().hit) + 16.0
	for it in items:
		var kind := String(it.kind)
		# 금화만 끌려온다. P 는 확정으로 나오는 것이라 굳이 안 끌어와도 된다.
		var d: Vector2 = pos - it.pos
		if kind == "coin" and d.length() < mag:
			it.pos += d.normalized() * D.MAGNET_SPD * dt
		else:
			it.pos.y += D.SCROLL * dt
		if it.pos.y > h + 60.0:
			it.dead = true
			continue
		if d.length_squared() < take * take:
			it.dead = true
			if kind == "coin":
				coins_taken += 1
				var g := int(round(float(D.COIN_GOLD) * D.greed_mul()))
				gold += g
				pops.append({pos = it.pos, p = 0.0, amount = g})
			else:
				if power < D.POWER_MAX:
					power += 1
					_spark_burst(it.pos, 14, P.POWER, 300.0)
				else:
					var g2 := int(round(float(D.POWER_FULL_GOLD) * D.greed_mul()))
					gold += g2
					pops.append({pos = it.pos, p = 0.0, amount = g2})

# ==================== 이펙트 ====================

func _spark_burst(p: Vector2, n: int, c: Color, spd: float) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var s := sparks[spark_i]
		s.life = 1.0
		s.pos = p
		s.vel = Vector2(cos(a), sin(a)) * spd * rng.randf_range(0.4, 1.0)
		s.col = c
		spark_i = (spark_i + 1) % SPARK_MAX


func _step_fx(dt: float) -> void:
	for b in booms:
		b.p += dt * 2.6
	booms = booms.filter(func(b): return float(b.p) < 1.0)
	for q in pops:
		q.p += dt * 1.35
	pops = pops.filter(func(q): return float(q.p) < 1.0)
	for s in sparks:
		if float(s.life) <= 0.0:
			continue
		s.life = float(s.life) - dt * 2.6
		s.pos += Vector2(s.vel) * dt
		s.vel = Vector2(s.vel) * (1.0 - dt * 3.0)


## 죽은 것을 프레임 끝에 한 번만 걷어낸다.
func _sweep() -> void:
	if pb.any(func(b): return b.dead):
		pb = pb.filter(func(b): return not b.dead)
	if foes.any(func(e): return e.dead):
		foes = foes.filter(func(e): return not e.dead)
	if eb.any(func(b): return b.dead):
		eb = eb.filter(func(b): return not b.dead)
	if items.any(func(i): return i.dead):
		items = items.filter(func(i): return not i.dead)

# ==================== 무인 주행 (soak) ====================

## 제일 나은 x 를 고른다.
##
## **가까운 것은 피하고 먼 것은 겨눈다.** 회피만 시키면 무인 주행이 늘 빈 줄로
## 도망쳐서 브레스가 허공으로만 나가고, 그러면 **화력이 진행을 막는지를 잴 수가 없다** —
## 실제로 처음엔 6분 동안 3마리만 잡고 5470m 를 갔다. 사람은 앞에 있는 것을 녹이면서
## 나아가므로, 겨냥 보상이 있어야 soak 이 사람과 같은 것을 잰다.
const AIM_NEAR := 380.0     ## 이보다 가까우면 피한다
const AIM_FAR := 950.0      ## 이 사이에 있으면 겨눈다


func _safe_x() -> float:
	var best_x := pos.x
	var best := -1e9
	var slots := 15
	for i in slots:
		var x := _margin() + (w - _margin() * 2.0) * i / float(slots - 1)
		var score := -absf(x - pos.x) * 0.25
		for e in foes:
			if e.dead:
				continue
			var dy: float = pos.y - float(e.pos.y)
			if dy < -40.0 or dy > AIM_FAR:
				continue
			var dx: float = absf(x - float(e.pos.x))
			var need: float = float(e.r) + 44.0
			if dy < AIM_NEAR:
				# 코앞 — 무조건 비킨다. 바위는 못 부수니 더 크게 피한다.
				if dx < need:
					var w8: float = 1.0 - dx / need
					score -= (AIM_NEAR + 120.0 - dy) * w8 * (3.2 if e.solid else 1.6)
			elif not e.solid:
				# 멀리 — 줄을 맞춰 두면 브레스가 알아서 녹인다.
				if dx < need * 0.9:
					score += 34.0 * (1.0 - dx / (need * 0.9))
		for b in eb:
			var dy2: float = pos.y - float(b.pos.y)
			if dy2 < -20.0 or dy2 > 460.0:
				continue
			if absf(x - float(b.pos.x)) < 46.0:
				score -= (520.0 - dy2) * 1.3
		for it in items:
			if float(it.pos.y) > pos.y:
				continue
			var idx: float = absf(x - float(it.pos.x))
			# P 는 화력이라 사람이면 반드시 주우러 간다. 금화보다 훨씬 세게 끌린다.
			if String(it.kind) == "power":
				if idx < 90.0:
					score += 180.0 * (1.0 - idx / 90.0)
			elif idx < 44.0:
				score += 22.0
		if score > best:
			best = score
			best_x = x
	return best_x

# ==================== 그리기 ====================

func draw(ci: CanvasItem) -> void:
	Art.sky(ci, w, h, int(zone().sky))
	Art.scenery(ci, w, h, scroll, zone_i, t)

	for it in items:
		if String(it.kind) == "coin":
			Art.coin(ci, it.pos, t, float(it.ph))
		else:
			Art.item_power(ci, it.pos, t)

	for e in foes:
		Art.enemy(ci, e, t)

	for b in pb:
		Art.breath(ci, b)

	# 적 탄은 **적보다 위에** 그린다. 밑에 깔면 몸에 겹친 탄이 안 보여서 억울하게 죽는다.
	for b in eb:
		Art.foe_bullet(ci, b.pos, t)

	if st == St.PLAY:
		var blink := invuln <= 0.0 or fmod(t, 0.18) < 0.11
		if blink:
			Art.dragon(ci, dragon, pos, t, 1.0, tilt)
			Art.hitpoint(ci, pos, float(dm().hit), col(), t)
		if shields > 0:
			Art.shield_ring(ci, pos, 30.0, shields, t)

	for s in sparks:
		if float(s.life) > 0.0:
			Art.spark(ci, s.pos, s.vel, float(s.life), s.col)
	for b in booms:
		Art.boom(ci, b.pos, float(b.p), float(b.size), b.col)
	for q in pops:
		Art.gold_pop(ci, q.pos, float(q.p), int(q.amount))

	if banner > 0.0:
		Art.zone_banner(ci, w, h, h * 0.34, String(zone().name), zone_i,
				minf(1.0, banner / 0.45))
