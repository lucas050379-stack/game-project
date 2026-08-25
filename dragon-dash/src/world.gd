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
var m := 0.0                 ## 달린 거리(m)
var scroll := 0.0            ## 배경이 흘러간 픽셀 (보스 중에도 계속 흐른다)
var zone_i := 0
var wave_i := 0
var banner := 0.0
var next_power := D.POWER_FIRST
var boss_zone := -1          ## 이 구간의 보스를 이미 냈나

# ---- 점수 ----
## **점수 = 비행 거리 + 사냥 점수.** 거리만 세면 "안 쏘고 피하기만 하는" 것이
## 최적해가 된다 — 실제로 첫 판이 그랬다(처치 3마리로 5470m).
var dist_score := 0.0
var hunt_score := 0.0
var best_close := 1.0        ## 이 판에서 낸 최고 근접 배율 (결과 화면에 보여 준다)

# ---- 드래곤 ----
var dragon := 0
var pos := Vector2.ZERO
var power := 0
var hearts := 0
var invuln := 0.0
var fire_cd := 0.0
var tilt := 0.0

## 판 안에서만 도는 시간제 아이템. id -> 남은 시간.
var buffs := {}

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
var items: Array[Dictionary] = []   ## 금화 · P · 시간제 아이템
var booms: Array[Dictionary] = []
var pops: Array[Dictionary] = []    ## 떠오르는 숫자
var boss: Dictionary = {}

## 알갱이는 **자리를 돌려 쓴다.** `pop_front()` 는 배열을 통째로 앞으로 당기는
## 연산이라 상한이 꽉 찬 채로 초당 수백 번 불리면 그것만으로 프레임을 먹는다.
const SPARK_MAX := 128
var sparks: Array[Dictionary] = []
var spark_i := 0

var shake := 0.0
var over_t := 0.0
var auto := false
var rng := RandomNumberGenerator.new()


func _init(dragon_idx: int = 0) -> void:
	dragon = clampi(dragon_idx, 0, D.DRAGON.size() - 1)
	hearts = D.hearts()
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


func score() -> int:
	return int(dist_score + hunt_score)


func has(id: String) -> bool:
	return float(buffs.get(id, 0.0)) > 0.0


## 스크롤 배율. 거리에 따라 빨라지고, 하이퍼 플라이트 동안 더 빨라진다.
func spd_k() -> float:
	var k := D.scroll_at(m) / D.SCROLL
	if has("hyper"):
		k *= D.HYPER_SPEED
	return k


## 테스트 빌드 전용 — 먼 거리부터 시작한다. **파워는 만렙으로 둔다**:
## 그 거리를 실제로 달려왔다면 P 가 이미 다 나온 뒤라 그래야 표와 맞는다.
func skip_to(dist_m: float) -> void:
	m = maxf(0.0, dist_m)
	scroll = m * D.PX_PER_M
	power = D.POWER_MAX
	zone_i = int(m / D.ZONE_M) % D.ZONE.size()
	wave_i = _wave_index_for(fposmod(m, D.ZONE_M) / D.ZONE_M)
	next_power = m + D.POWER_EVERY


func _wave_index_for(prog: float) -> int:
	var table: Array = D.ZONE[zone_i].table
	var i := 0
	while i < table.size() and float(table[i].at) <= prog:
		i += 1
	return i

# ==================== 진행 ====================

func step(dt: float, dir: float, target_x: float) -> void:
	t += dt
	shake = maxf(0.0, shake - dt * 3.4)
	if st == St.OVER:
		over_t += dt
		_step_fx(dt)
		return

	for id in buffs.keys():
		buffs[id] = maxf(0.0, float(buffs[id]) - dt)

	# 배경은 언제나 흐른다. 거리는 **보스와 싸우는 동안 멈춘다** —
	# 보스에게 자기 무대를 주기 위해서다. 안 멈추면 보스가 다음 구간까지
	# 따라 들어와 웨이브 표와 겹친다.
	var k := spd_k()
	scroll += D.SCROLL * k * dt
	if boss.is_empty():
		m += D.SCROLL * k * dt / D.PX_PER_M
		dist_score += D.SCROLL * k * dt / D.PX_PER_M * D.SCORE_PER_M \
				* (2.0 if has("double") else 1.0)
	banner = maxf(0.0, banner - dt)

	_step_zone()
	_step_player(dt, dir, target_x)
	_step_breath(dt)
	_step_foes(dt)
	_step_boss(dt)
	_step_foe_bullets(dt)
	_step_items(dt)
	_step_fx(dt)
	_sweep()


func zone() -> Dictionary:
	return D.ZONE[zone_i % D.ZONE.size()]


func _step_zone() -> void:
	# 보스가 있는 동안은 웨이브를 멈춘다. 무대를 나눠 쓰면 둘 다 안 읽힌다.
	if not boss.is_empty():
		return

	var zi := int(m / D.ZONE_M) % D.ZONE.size()
	if zi != zone_i:
		zone_i = zi
		wave_i = 0
		boss_zone = -1
		banner = 2.2
	var prog := fposmod(m, D.ZONE_M) / D.ZONE_M
	var table: Array = zone().table
	while wave_i < table.size() and prog >= float(table[wave_i].at):
		_spawn(table[wave_i])
		wave_i += 1

	var zone_no := int(m / D.ZONE_M)
	if prog >= D.BOSS_AT and boss_zone != zone_no:
		boss_zone = zone_no
		_spawn_boss()

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
			var half := (n - 1) * 0.5
			for i in n:
				_foe(String(spec.k), w * 0.5 + (i - half) * gap, -60.0)
		"vee":
			var vhalf := (n - 1) * 0.5
			for i in n:
				var off := i - vhalf
				_foe(String(spec.k), w * 0.5 + off * gap, -60.0 - absf(off) * 52.0)
		"stream":
			# y 를 벌려 두면 그대로 시간차가 된다. 타이머를 따로 둘 필요가 없다.
			var sx := rng.randf_range(_margin() + 50.0, w - _margin() - 50.0)
			for i in n:
				_foe(String(spec.k), sx, -60.0 - i * gap)
		"coins":
			var chalf := (n - 1) * 0.5
			for i in n:
				_add_item("coin", w * 0.5 + (i - chalf) * gap, -40.0)
		"arc":
			var ahalf := (n - 1) * 0.5
			for i in n:
				var o := i - ahalf
				_add_item("coin", w * 0.5 + o * gap, -40.0 - (ahalf * ahalf - o * o) * 9.0)
		"snake":
			var amp := (w - _margin() * 2.0) * 0.34
			for i in n:
				_add_item("coin", w * 0.5 + sin(i * 0.62) * amp, -40.0 - i * gap)
		"item":
			var b: Dictionary = D.BUFF[rng.randi_range(0, D.BUFF.size() - 1)]
			_add_item(String(b.id), rng.randf_range(_margin() + 50.0, w - _margin() - 50.0),
					-50.0)


func _foe(k: String, x: float, y: float) -> void:
	if not D.ENEMY.has(k):
		return
	var d: Dictionary = D.ENEMY[k]
	var base_hp := float(d.hp)
	var hp := base_hp * D.hp_at(m)
	spawned += 1
	hp_spawned += hp
	foes.append({
		art = String(d.art),
		pos = Vector2(clampf(x, 18.0, w - 18.0), y),
		x0 = clampf(x, 18.0, w - 18.0),
		r = float(d.r),
		speed = float(d.speed),
		move = String(d.move),
		gold = int(d.gold),
		score = int(d.score),
		fire = float(d.fire),
		fire_t = float(d.fire) * rng.randf_range(0.4, 1.0),
		cast = 0.0,
		dv = Vector2.DOWN,
		hp = hp,
		max_hp = hp,
		ph = rng.randf() * TAU,
		flash = 0.0,
		hits = {},
		dead = false,
	})


func _add_item(kind: String, x: float, y: float) -> void:
	items.append({
		kind = kind,
		pos = Vector2(clampf(x, 24.0, w - 24.0), y),
		vel = Vector2.ZERO,
		ph = rng.randf() * TAU,
		dead = false,
	})


func _spawn_boss() -> void:
	var b: Dictionary = D.BOSS[zone_i % D.BOSS.size()]
	var hp := float(b.hp) * D.hp_at(m)
	boss = {
		art = String(b.art),
		name = String(b.name),
		pos = Vector2(w * 0.5, -140.0),
		r = Vector2(b.r),
		hp = hp,
		max_hp = hp,
		shown = hp,
		gold = int(b.gold),
		score = int(b.score),
		t = 0.0,
		life = 0.0,
		cast = 0.0,
		pattern = 0,
		dv = Vector2.DOWN,
		rage = false,
		flash = 0.0,
		leaving = false,
		hits = {},
	}
	banner = 1.6

# ==================== 드래곤 ====================

func _step_player(dt: float, dir: float, target_x: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	var spd := float(dm().speed) * D.speed_mul()

	if auto:
		target_x = _safe_x()
	if target_x >= 0.0:
		# **드래그는 1:1 에 가까워야 한다.** 속도 상한을 낮게 두면 급하게 그은
		# 손가락을 몸이 못 따라와서 "피하려던 순간에 안 피해지는" 게임이 된다.
		var dx := clampf(target_x - pos.x, -spd * 6.0 * dt, spd * 6.0 * dt)
		pos.x += dx
		tilt = lerpf(tilt, clampf(dx / maxf(0.001, spd * dt), -1.0, 1.0), dt * 12.0)
	else:
		pos.x += dir * spd * dt
		tilt = lerpf(tilt, dir, dt * 10.0)
	pos.x = clampf(pos.x, _margin(), w - _margin())
	pos.y = h * D.HERO_Y

	# 하이퍼 플라이트 — 무적으로 돌진하며 스치는 것을 전부 태운다.
	if has("hyper"):
		for e in foes:
			if e.dead:
				continue
			var rr: float = float(e.r) + 46.0
			if pos.distance_squared_to(e.pos) < rr * rr:
				_hurt(e, D.HYPER_DMG)
		for b in eb:
			if b.pos.distance_to(pos) < 120.0:
				b.dead = true

	fire_cd -= dt
	if fire_cd <= 0.0:
		fire_cd = _shoot()


## 드래곤마다 브레스가 **자라는 방향**이 다르다. 세기는 `D.POWER_DPS` 로 셋이 같다.
func _shoot() -> float:
	var p := clampi(power, 0, D.POWER_MAX)
	var k: float = D.POWER_DPS[p]
	var dmg := D.BASE_DMG * k * D.dmg_mul()
	var cd := D.BASE_CD / D.rate_mul()
	var c := col()
	# 듀얼샷 — 두 줄기로 나간다. 한 줄기당 피해는 그대로라 실제로 두 배다.
	var lanes := [0.0]
	if has("dual"):
		lanes = [-26.0, 26.0]

	match dragon:
		0:  # 화룡 — 집중. 한 줄기가 계속 두꺼워진다.
			for lx in lanes:
				_bullet(pos + Vector2(lx, -34), Vector2(0, -1020.0), "flame", c,
						dmg, 38.0 + p * 13.0, false)
			return cd
		1:  # 뇌룡 — 확산. 폭을 먼저 정하고 발수로 나눈다.
			#     각도 간격을 레벨마다 키우면 만렙에서 그냥 벌어지기만 한다.
			var n: int = [3, 4, 5, 6, 7, 8][p]
			var span := 0.16 if p < 2 else 0.40
			for lx in lanes:
				for i in n:
					var f := 0.0 if n == 1 else (float(i) / float(n - 1) - 0.5)
					var a := -PI * 0.5 + f * span
					_bullet(pos + Vector2(lx + f * 26.0, -30),
							Vector2(cos(a), sin(a)) * 1080.0,
							"bolt", c, dmg / n, 13.0 + p * 2.4, false)
			return cd
		_:  # 빙룡 — 관통. 느린 대신 한 방이 굵고 줄지어 오는 것을 꿴다.
			for lx in lanes:
				_bullet(pos + Vector2(lx, -36), Vector2(0, -940.0), "spear", c,
						dmg * 1.35, 26.0 + p * 7.0, true)
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
		# 보스 먼저 — 화면을 가로막고 있으므로 잡졸보다 앞에 있다.
		if not boss.is_empty() and not boss.leaving:
			var br: Vector2 = boss.r
			var d: Vector2 = b.pos - Vector2(boss.pos)
			if absf(d.x) < br.x + float(b.w) and absf(d.y) < br.y + float(b.w):
				if b.pierce:
					var lastb: float = float(b.hits.get(-1, -99.0))
					if t - lastb >= D.REHIT:
						b.hits[-1] = t
						_hurt_boss(float(b.dmg))
						_spark_burst(b.pos, 2, b.col, 180.0)
				else:
					_hurt_boss(float(b.dmg))
					_spark_burst(b.pos, 3, b.col, 200.0)
					b.dead = true
					continue
		for fi in foes.size():
			var e: Dictionary = foes[fi]
			if e.dead:
				continue
			var rr: float = float(e.r) + float(b.w)
			if b.pos.distance_squared_to(e.pos) > rr * rr:
				continue
			if b.pierce:
				# **관통은 같은 표적을 REHIT 간격으로만 때린다.**
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
	if e.dead:
		return
	dmg_dealt += minf(dmg, maxf(0.0, float(e.hp)))
	e.hp -= dmg
	e.flash = 0.35
	if e.hp > 0.0:
		return
	e.dead = true
	kills += 1

	# **근접 처치 보너스 — 드래곤 위 어느 띠에서 죽였느냐로 정해진다.**
	# 반지름이 아니라 **세로 거리**다. 화면에 그어진 가로선이 곧 이 경계이므로
	# 둘이 같은 값(`D.CLOSE_BAND`)을 봐야 보이는 것과 들어오는 점수가 맞는다.
	var mul := D.close_mul((pos.y - float(e.pos.y)) / maxf(1.0, h))
	best_close = maxf(best_close, mul)
	var sc := float(e.score) * mul * (2.0 if has("double") else 1.0)
	hunt_score += sc
	var g := int(round(float(e.gold) * D.greed_mul()))
	gold += g

	booms.append({pos = e.pos, p = 0.0, size = float(e.r) * 1.5, col = P.FLAME})
	_spark_burst(e.pos, 7, P.FLAME, 260.0)
	# 배율이 붙었을 때만 숫자를 띄운다 — 잡졸마다 뜨면 화면이 숫자로 덮인다.
	if mul >= 2.0:
		pops.append({pos = e.pos, p = 0.0, text = "x%d  %d" % [int(mul), int(sc)],
			col = P.hdr(P.GOLD, 1.25) if mul >= 12.0 else P.hdr(P.WHITE, 1.1)})

	match String(e.art):
		"flame":
			_flame_boom(e.pos)
		"chest":
			_chest_burst(e.pos)


## 불꽃 몬스터 — **죽으면 터져서 주변 적을 같이 없앤다.**
## 조금 깎는 정도면 그냥 체력 많은 잡졸이라, 실제로 지울 만큼 세게 준다.
func _flame_boom(p: Vector2) -> void:
	shake = maxf(shake, 0.7)
	booms.append({pos = p, p = 0.0, size = D.FLAME_BOOM_R, col = P.hdr(P.FLAME, 1.2)})
	_spark_burst(p, 22, P.FLAME, 460.0)
	var r2 := D.FLAME_BOOM_R * D.FLAME_BOOM_R
	for o in foes:
		if o.dead:
			continue
		if p.distance_squared_to(o.pos) < r2:
			_hurt(o, D.FLAME_BOOM_DMG)
	for b in eb:
		if p.distance_to(b.pos) < D.FLAME_BOOM_R:
			b.dead = true


func _chest_burst(p: Vector2) -> void:
	shake = maxf(shake, 0.35)
	for i in D.CHEST_COINS:
		var a := TAU * i / float(D.CHEST_COINS) + rng.randf() * 0.4
		items.append({
			kind = "coin",
			pos = p,
			vel = Vector2(cos(a), sin(a)) * rng.randf_range(180.0, 340.0),
			ph = rng.randf() * TAU,
			dead = false,
		})

# ==================== 적 ====================

func _step_foes(dt: float) -> void:
	var k := spd_k()
	for e in foes:
		if e.dead:
			continue
		e.flash = maxf(0.0, float(e.flash) - dt * 3.0)
		e.pos.y += float(e.speed) * k * dt
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
## 난이도가 아니라 불합리가 된다. **방향은 예비 동작이 시작될 때 박아 두고 안 고친다** —
## 겨냥을 계속 고쳐 잡으면 경고를 보고 피한 사람이 그대로 맞는다.
const CAST := 0.45


func _step_foe_fire(e: Dictionary, dt: float) -> void:
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
	if invuln > 0.0 or has("hyper"):
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
		if invuln > 0.0 or has("hyper"):
			continue
		var rr: float = D.E_BULLET_R + float(dm().hit)
		if pos.distance_squared_to(b.pos) < rr * rr:
			b.dead = true
			_hit()


## 부딪혔다. 하트가 있으면 한 칸 깎이고, 없으면 그 자리에서 끝난다.
func _hit() -> void:
	if hearts > 0:
		hearts -= 1
		invuln = D.INVULN
		shake = 1.0
		booms.append({pos = pos, p = 0.0, size = 54.0, col = P.HEART})
		_spark_burst(pos, 16, P.HEART, 340.0)
		# 몸에 붙어 있던 탄까지 같이 지운다 — 안 그러면 무적이 끝나기 전에
		# 같은 탄에 또 맞아서 두 칸이 한 번에 날아간다.
		for b in eb:
			if b.pos.distance_to(pos) < 170.0:
				b.dead = true
		return
	st = St.OVER
	over_t = 0.0
	shake = 1.0
	booms.append({pos = pos, p = 0.0, size = 96.0, col = P.FLAME})
	_spark_burst(pos, 28, P.FLAME, 420.0)

# ==================== 보스 ====================

func _step_boss(dt: float) -> void:
	if boss.is_empty():
		return
	boss.t = float(boss.t) + dt
	boss.flash = maxf(0.0, float(boss.flash) - dt * 3.0)
	boss.shown = lerpf(float(boss.shown), maxf(0.0, float(boss.hp)), dt * 3.0)

	if boss.leaving:
		boss.pos.y -= 340.0 * dt
		if boss.pos.y < -260.0:
			boss = {}
			# 놓친 웨이브를 지나간 것으로 친다 — 안 밀면 한꺼번에 쏟아진다.
			wave_i = _wave_index_for(fposmod(m, D.ZONE_M) / D.ZONE_M)
		return

	var top := h * 0.20
	if boss.pos.y < top:
		boss.pos.y = minf(top, float(boss.pos.y) + 220.0 * dt)
		return

	boss.life = float(boss.life) + dt
	boss.pos.x = w * 0.5 + sin(float(boss.life) * 0.8) * (w * 0.28)
	if not boss.rage and float(boss.hp) <= float(boss.max_hp) * D.BOSS_RAGE:
		boss.rage = true
		shake = maxf(shake, 0.6)

	# 못 잡으면 날아간다. 반드시 잡아야 넘어가게 하면 화력이 모자란 순간
	# 그 자리에서 게임이 멈춘다 — 러너에서는 그게 제일 나쁘다.
	if float(boss.life) > D.BOSS_TIMEOUT:
		boss.leaving = true
		return

	_boss_fire(dt)
	# 몸통 박치기 판정
	if invuln <= 0.0 and not has("hyper"):
		var br: Vector2 = boss.r
		var d: Vector2 = pos - Vector2(boss.pos)
		if absf(d.x) < br.x + float(dm().hit) and absf(d.y) < br.y + float(dm().hit):
			_hit()


func _boss_fire(dt: float) -> void:
	if float(boss.cast) > 0.0:
		boss.cast = maxf(0.0, float(boss.cast) - dt / D.BOSS_CAST)
		if float(boss.cast) <= 0.0:
			_boss_shoot()
		return
	var gap := (1.35 if boss.rage else 2.1)
	if fmod(float(boss.life), gap) < dt:
		boss.pattern = (int(boss.pattern) + 1) % 3
		boss.cast = 1.0
		boss.dv = (pos - Vector2(boss.pos)).normalized()


## 세 패턴. **경고 모양이 서로 달라야** "뭔가 온다"에서 "어디로 피한다"가 된다.
func _boss_shoot() -> void:
	var o: Vector2 = boss.pos
	var extra := 2 if boss.rage else 0
	match int(boss.pattern):
		0:  # 부채꼴 — 겨눈 방향으로 퍼진다
			var n := 5 + extra
			var base: Vector2 = boss.dv
			for i in n:
				var a := base.angle() + (float(i) / float(n - 1) - 0.5) * 0.9
				eb.append({pos = o, vel = Vector2(cos(a), sin(a)) * D.E_BULLET_SPD,
					dead = false})
		1:  # 고리 — 사방으로. 옆으로 빠져야 한다
			var n2 := 12 + extra * 2
			for i in n2:
				var a2 := TAU * i / n2 + float(boss.life) * 0.3
				eb.append({pos = o, vel = Vector2(cos(a2), sin(a2)) * D.E_BULLET_SPD * 0.8,
					dead = false})
		_:  # 세 줄기 — 곧게 떨어진다
			for i in 3 + extra:
				var x := _margin() + (w - _margin() * 2.0) * i / float(2 + extra)
				eb.append({pos = Vector2(x, o.y), vel = Vector2(0, D.E_BULLET_SPD * 1.15),
					dead = false})


func _hurt_boss(dmg: float) -> void:
	if boss.is_empty() or boss.leaving:
		return
	dmg_dealt += minf(dmg, maxf(0.0, float(boss.hp)))
	boss.hp = float(boss.hp) - dmg
	boss.flash = 0.3
	if float(boss.hp) > 0.0:
		return
	# **빨리 잡을수록 점수가 크다**(원작도 그렇다).
	var fast: float = 1.0 + (D.BOSS_FAST_BONUS - 1.0) \
			* clampf(1.0 - float(boss.life) / D.BOSS_TIMEOUT, 0.0, 1.0)
	var sc := float(boss.score) * fast * (2.0 if has("double") else 1.0)
	hunt_score += sc
	gold += int(round(float(boss.gold) * D.greed_mul()))
	kills += 1
	shake = 1.0
	booms.append({pos = boss.pos, p = 0.0, size = 200.0, col = P.hdr(P.FLAME, 1.2)})
	_spark_burst(boss.pos, 40, P.FLAME, 520.0)
	pops.append({pos = boss.pos, p = 0.0, text = "격파  %d" % int(sc),
		col = P.hdr(P.GOLD, 1.25)})
	_chest_burst(boss.pos)
	boss = {}
	wave_i = _wave_index_for(fposmod(m, D.ZONE_M) / D.ZONE_M)

# ==================== 금화 · 아이템 ====================

func _step_items(dt: float) -> void:
	var mag := D.magnet()
	if has("magnet"):
		mag = maxf(w, h) * 2.0        # 자석 — 화면의 금화가 전부 끌려온다
	var take: float = D.ITEM_R + float(dm().hit) + 18.0
	var k := spd_k()
	for it in items:
		var kind := String(it.kind)
		var d := pos - Vector2(it.pos)
		# 상자에서 튄 금화는 잠깐 자기 속도로 흩어졌다가 잦아든다.
		var v: Vector2 = it.vel
		if v.length_squared() > 1.0:
			it.pos += v * dt
			it.vel = v * (1.0 - dt * 2.4)
		if kind == "coin" and d.length() < mag:
			it.pos += d.normalized() * D.MAGNET_SPD * dt
		else:
			it.pos.y += D.SCROLL * k * dt
		if it.pos.y > h + 60.0:
			it.dead = true
			continue
		if d.length_squared() >= take * take:
			continue
		it.dead = true
		match kind:
			"coin":
				coins_taken += 1
				gold += int(round(float(D.COIN_GOLD) * D.greed_mul()))
				hunt_score += D.COIN_SCORE * (2.0 if has("double") else 1.0)
			"power":
				if power < D.POWER_MAX:
					power += 1
					_spark_burst(it.pos, 14, P.POWER, 300.0)
					pops.append({pos = it.pos, p = 0.0, text = "POWER %d" % power,
						col = P.hdr(P.POWER, 1.2)})
				else:
					gold += int(round(float(D.POWER_FULL_GOLD) * D.greed_mul()))
			_:
				var b := D.buff(kind)
				if not b.is_empty():
					buffs[kind] = float(b.dur)
					_spark_burst(it.pos, 16, P.BUFF, 320.0)
					pops.append({pos = it.pos, p = 0.0, text = String(b.name),
						col = P.hdr(P.BUFF, 1.2)})

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
		q.p += dt * 1.15
	pops = pops.filter(func(q): return float(q.p) < 1.0)
	for s in sparks:
		if float(s.life) <= 0.0:
			continue
		s.life = float(s.life) - dt * 2.6
		s.pos += Vector2(s.vel) * dt
		s.vel = Vector2(s.vel) * (1.0 - dt * 3.0)


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

## 제일 나은 x 를 고른다. **가까운 것은 피하고 먼 것은 겨눈다.**
##
## 회피만 시키면 늘 빈 줄로 도망쳐서 브레스가 허공으로만 나가고, 그러면
## 화력이 진행을 막는지를 잴 수가 없다 — 실제로 처음엔 6분 동안 3마리만
## 잡고 5470m 를 갔다.
##
## **봇은 근접 처치 보너스를 노리지 않는다.** 사람은 점수를 위해 일부러 파고들지만
## 봇은 안전한 쪽만 고른다 — 그래서 봇 점수는 사람 점수와 비교하면 안 된다.
const AIM_NEAR := 380.0
const AIM_FAR := 950.0


func _safe_x() -> float:
	var best_x := pos.x
	var best := -1e9
	var slots := 15
	for i in slots:
		var x := _margin() + (w - _margin() * 2.0) * i / float(slots - 1)
		var score_ := -absf(x - pos.x) * 0.25
		for e in foes:
			if e.dead:
				continue
			var dy: float = pos.y - float(e.pos.y)
			if dy < -40.0 or dy > AIM_FAR:
				continue
			var dx: float = absf(x - float(e.pos.x))
			var need: float = float(e.r) + 44.0
			if dy < AIM_NEAR:
				if dx < need:
					score_ -= (AIM_NEAR + 120.0 - dy) * (1.0 - dx / need) * 2.0
			elif dx < need * 0.9:
				score_ += 34.0 * (1.0 - dx / (need * 0.9))
		for b in eb:
			var dy2: float = pos.y - float(b.pos.y)
			if dy2 < -20.0 or dy2 > 460.0:
				continue
			if absf(x - float(b.pos.x)) < 46.0:
				score_ -= (520.0 - dy2) * 1.3
		if not boss.is_empty() and not boss.leaving:
			# 보스 밑에 붙어야 브레스가 들어간다.
			score_ += 90.0 * (1.0 - clampf(absf(x - float(boss.pos.x)) / 200.0, 0.0, 1.0))
		for it in items:
			if float(it.pos.y) > pos.y:
				continue
			var idx: float = absf(x - float(it.pos.x))
			# P 와 아이템은 사람이면 반드시 주우러 간다.
			if String(it.kind) != "coin":
				if idx < 100.0:
					score_ += 180.0 * (1.0 - idx / 100.0)
			elif idx < 44.0:
				score_ += 22.0
		if score_ > best:
			best = score_
			best_x = x
	return best_x

# ==================== 그리기 ====================

func draw(ci: CanvasItem) -> void:
	Art.sky(ci, w, h, int(zone().sky))
	Art.scenery(ci, w, h, scroll, zone_i, t)

	for it in items:
		match String(it.kind):
			"coin": Art.coin(ci, it.pos, t, float(it.ph))
			"power": Art.item_power(ci, it.pos, t)
			_: Art.item_buff(ci, it.pos, t, String(it.kind))

	for e in foes:
		Art.enemy(ci, e, t)

	if not boss.is_empty():
		Art.boss(ci, boss, t)

	for b in pb:
		Art.breath(ci, b)

	# 적 탄은 **적보다 위에** 그린다. 밑에 깔면 몸에 겹친 탄이 안 보여 억울하게 죽는다.
	for b in eb:
		Art.foe_bullet(ci, b.pos, t)

	if st == St.PLAY:
		var blink := invuln <= 0.0 or fmod(t, 0.18) < 0.11
		if has("hyper"):
			Art.hyper_trail(ci, pos, t, col())
		if blink:
			Art.dragon(ci, dragon, pos, t, 1.0, tilt)
			Art.hitpoint(ci, pos, float(dm().hit), col(), t)
		if hearts > 0:
			Art.heart_ring(ci, pos, 30.0, hearts, t)
		# **근접 보너스 고리** — 이 안에서 죽이면 배율이 크다.
		# 안 보여 주면 "왜 어떤 건 40배고 어떤 건 1배인지" 알 수가 없다.
		Art.close_bands(ci, w, h, pos, t)

	for s in sparks:
		if float(s.life) > 0.0:
			Art.spark(ci, s.pos, s.vel, float(s.life), s.col)
	for b in booms:
		Art.boom(ci, b.pos, float(b.p), float(b.size), b.col)
	for q in pops:
		Art.pop(ci, q.pos, float(q.p), String(q.text), q.col)

	if banner > 0.0 and boss.is_empty():
		Art.zone_banner(ci, w, h, h * 0.34, String(zone().name), zone_i,
				minf(1.0, banner / 0.45))
