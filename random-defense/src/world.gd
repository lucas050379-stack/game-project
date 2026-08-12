class_name World
extends RefCounted

## 라운드 안에서 움직이는 것 — 몬스터 · 탄 · 불꽃 · 유닛의 이동과 사격.
##
## **몬스터는 죽을 때까지 사라지지 않는다.** 고리를 돌고 또 돈다. 그래서 한 라운드 분량을
## 그 라운드 안에 못 치우면 다음 라운드가 그 위에 얹히고, [constant D.LOSE_COUNT] 마리에서 진다.
##
## 스토리 라인의 몬스터는 **본진과 완전히 따로 논다.** 걷지 않고 제자리를 지키며,
## 유닛을 그쪽으로 옮겨야만 싸움이 시작된다.
##
## 죽은 것을 그 자리에서 배열에서 빼지 않는다 — 탄이 표적을 참조로 들고 있어서
## 도중에 줄이면 판정이 엉킨다. `dead` 표시만 남기고 프레임 끝에 정리한다.

const UNIT_SPD := 6.0
const SHOT_SPD := 30.0
const SPARK_MAX := 260

var g: Game
var loop: PackedVector3Array

var mobs: Array = []
var shots: Array = []
var sparks: Array = []
var _spark_i := 0

## 고리 구간의 길이. 위치를 "몇 번째 구간의 어디"로 들고 있어서 매 프레임 다시 안 잰다.
var _seg_len: PackedFloat32Array


func _init(game: Game) -> void:
	g = game
	loop = D.loop_points()
	_seg_len = PackedFloat32Array()
	for i in loop.size():
		_seg_len.append(loop[i].distance_to(loop[(i + 1) % loop.size()]))


# ══ 스폰 ══════════════════════════════════════════════════════

## 라운드 하나 분량을 고리에 풀어 놓는다. 보스는 [constant D.BOSS_EVERY] 라운드마다 한 마리뿐.
func spawn_round(n: int) -> void:
	var cnt := D.mob_count(n)
	var hp := D.mob_hp(n)
	for i in cnt:
		_spawn(D.mob_kind(n, g.rng), hp, false, float(i) * 0.9)
	if D.is_boss_round(n):
		_spawn(D.mob_kind(n, g.rng), hp * D.BOSS_HP_MUL, true, 0.0)


func _spawn(kind: int, hp: float, boss: bool, offset: float) -> void:
	mobs.append({
		"seg": 0, "u": offset,
		"p": loop[0],
		"kind": kind, "boss": boss,
		"hp": hp, "hpmax": hp,
		"spd": D.mob_speed(g.round_no) * float(D.MOB[kind]["spd"]) * (D.BOSS_SPD_MUL if boss else 1.0),
		"slow": 0.0, "slow_t": 0.0, "stun_t": 0.0,
		"yaw": 0.0, "walk": g.rng.randf() * TAU, "hit_t": 0.0,
		"story": false, "dead": false,
	})


## 스토리 단계 몬스터. 걷지 않고 스토리 라인에 버티고 선다.
func spawn_story(stage: int) -> void:
	for m in mobs:
		if m["story"]:
			m["dead"] = true
	var hp := D.story_hp(stage)
	var c := D.story_center()
	for i in D.STORY_COUNT:
		var a := TAU * float(i) / float(D.STORY_COUNT)
		mobs.append({
			"seg": 0, "u": 0.0,
			"p": c + Vector3(cos(a) * 3.4, 0.0, sin(a) * 4.6),
			"kind": mini(stage / 4, D.MOB.size() - 1), "boss": stage % 5 == 0,
			"hp": hp, "hpmax": hp,
			"spd": 0.0,
			"slow": 0.0, "slow_t": 0.0, "stun_t": 0.0,
			"yaw": PI, "walk": 0.0, "hit_t": 0.0,
			"story": true, "dead": false,
		})


func story_alive() -> int:
	var n := 0
	for m in mobs:
		if m["story"] and not m["dead"]:
			n += 1
	return n


func field_alive() -> int:
	var n := 0
	for m in mobs:
		if not m["story"] and not m["dead"]:
			n += 1
	return n


# ══ 한 프레임 ══════════════════════════════════════════════════

func step(dt: float) -> void:
	_step_mobs(dt)
	_step_units(dt)
	_step_shots(dt)
	_step_sparks(dt)
	_sweep()


func _step_mobs(dt: float) -> void:
	for m in mobs:
		if m["dead"]:
			continue
		m["hit_t"] = maxf(0.0, float(m["hit_t"]) - dt)
		if float(m["stun_t"]) > 0.0:
			m["stun_t"] = float(m["stun_t"]) - dt
			continue
		if float(m["slow_t"]) > 0.0:
			m["slow_t"] = float(m["slow_t"]) - dt
			if float(m["slow_t"]) <= 0.0:
				m["slow"] = 0.0
		if m["story"]:
			continue

		# 고리를 돈다. 끝 구간을 넘으면 첫 구간으로 돌아온다 — 처음도 끝도 없다.
		var sp := float(m["spd"]) * (1.0 - float(m["slow"]))
		var seg := int(m["seg"])
		var u := float(m["u"]) + sp * dt
		while u >= _seg_len[seg]:
			u -= _seg_len[seg]
			seg = (seg + 1) % loop.size()
		m["seg"] = seg
		m["u"] = u
		var a := loop[seg]
		var b := loop[(seg + 1) % loop.size()]
		var dir := (b - a).normalized()
		m["p"] = a + dir * u
		m["yaw"] = atan2(dir.x, dir.z)
		m["walk"] = float(m["walk"]) + dt * sp * 3.0


# ══ 유닛 ══════════════════════════════════════════════════════

func _step_units(dt: float) -> void:
	for un in g.units:
		var u: Dictionary = U.UNITS[int(un["ui"])]

		# 이동 명령
		if un["dst"] != null:
			var to: Vector3 = (un["dst"] as Vector3) - (un["p"] as Vector3)
			to.y = 0.0
			var d := to.length()
			if d <= UNIT_SPD * dt:
				un["p"] = un["dst"]
				un["dst"] = null
			else:
				un["p"] = (un["p"] as Vector3) + to / d * UNIT_SPD * dt
				un["yaw"] = atan2(to.x, to.z)

		un["cd"] = float(un["cd"]) - dt
		var muzzle := (un["p"] as Vector3) + Vector3(0, 1.0, 0)
		var tgt = _nearest(muzzle, D.reach(u))
		if tgt == null:
			continue
		var to2 := _body(tgt) - muzzle
		un["yaw"] = lerp_angle(float(un["yaw"]), atan2(to2.x, to2.z), minf(1.0, dt * 12.0))
		if float(un["cd"]) > 0.0:
			continue
		un["cd"] = D.cooldown(u)
		shots.append({
			"p": muzzle, "dir": to2.normalized(), "tgt": tgt,
			"ui": int(un["ui"]),
			"dmg": D.hit_damage(u),
			"splash": D.splash(u), "slow": D.slow(u), "stun": D.stun(u),
			"life": 2.0, "dead": false,
		})


## 사거리 안에서 **체력이 가장 많이 남은** 몬스터를 고른다.
## 가장 가까운 놈을 고르면 여러 유닛이 이미 죽어가는 하나에 몰려 화력이 샌다.
func _nearest(from: Vector3, r: float):
	var best = null
	var best_hp := -1.0
	var r2 := r * r
	for m in mobs:
		if m["dead"]:
			continue
		var p: Vector3 = m["p"]
		var dx := p.x - from.x
		var dz := p.z - from.z
		if dx * dx + dz * dz > r2:
			continue
		if float(m["hp"]) > best_hp:
			best_hp = float(m["hp"])
			best = m
	return best


# ══ 탄 ════════════════════════════════════════════════════════

func _step_shots(dt: float) -> void:
	for s in shots:
		if s["dead"]:
			continue
		s["life"] = float(s["life"]) - dt
		if float(s["life"]) <= 0.0:
			s["dead"] = true
			continue
		var tgt = s["tgt"]
		if tgt == null or tgt["dead"]:
			s["p"] = (s["p"] as Vector3) + (s["dir"] as Vector3) * SHOT_SPD * dt
			continue
		var tp := _body(tgt)
		var to := tp - (s["p"] as Vector3)
		var d := to.length()
		if d > 0.0001:
			s["dir"] = to / d
		if d <= SHOT_SPD * dt + 0.35:
			s["p"] = tp
			_impact(s, tgt)
		else:
			s["p"] = (s["p"] as Vector3) + (s["dir"] as Vector3) * SHOT_SPD * dt


func _impact(s: Dictionary, tgt: Dictionary) -> void:
	var u: Dictionary = U.UNITS[int(s["ui"])]
	var col := P.role(int(u["r"]))
	_damage(tgt, u, float(s["dmg"]))
	_burst(_body(tgt), col, 5, 2.0)

	var sp := float(s["splash"])
	if sp > 0.0:
		var c := _body(tgt)
		for m in mobs:
			if m["dead"] or m == tgt:
				continue
			var dp := _body(m) - c
			dp.y = 0.0
			var dd := dp.length()
			if dd <= sp:
				_damage(m, u, float(s["dmg"]) * lerpf(1.0, 0.5, dd / sp))
		_burst(c, col, 9, sp * 1.4)

	if float(s["slow"]) > 0.0:
		tgt["slow"] = maxf(float(tgt["slow"]), float(s["slow"]))
		tgt["slow_t"] = 1.6
	if float(s["stun"]) > 0.0 and not tgt["boss"]:
		tgt["stun_t"] = maxf(float(tgt["stun_t"]), float(s["stun"]))
	s["dead"] = true


func _damage(m: Dictionary, u: Dictionary, amount: float) -> void:
	if m["dead"]:
		return
	var amt := amount * D.mitigate(u, D.MOB[int(m["kind"])])
	if m["story"] and int(u["r"]) == 2:
		amt *= D.STORY_ROLE_BONUS
	if m["boss"] and D.has_tag(u, U.T_BOSS):
		amt *= 1.35
	# 끝딜 — 체력이 얼마 안 남은 놈을 즉시 정리한다
	if D.has_tag(u, U.T_LAST) and float(m["hp"]) < float(m["hpmax"]) * 0.12:
		amt = maxf(amt, float(m["hp"]))
	m["hp"] = float(m["hp"]) - amt
	m["hit_t"] = 0.12
	if float(m["hp"]) <= 0.0:
		m["dead"] = true
		# 골드는 잡아야 나온다. 스토리 라인의 적도 똑같이 준다 — 거기도 손으로 잡는 것이다.
		g.gold += D.GOLD_PER_KILL * (D.GOLD_BOSS_MUL if m["boss"] else 1)
		_burst(_body(m), P.MOB_COL[int(m["kind"])], 11 if m["boss"] else 6, 2.6)


# ══ 불꽃 ══════════════════════════════════════════════════════

func _burst(at: Vector3, col: Color, n: int, spread: float) -> void:
	for i in n:
		_push(at, Vector3(g.rng.randfn(0.0, spread), g.rng.randf() * spread * 0.9 + 0.6,
			g.rng.randfn(0.0, spread)), col, 0.42)


func _push(at: Vector3, v: Vector3, col: Color, life: float) -> void:
	var s := {"p": at, "v": v, "t": life, "life": life, "col": col}
	if sparks.size() < SPARK_MAX:
		sparks.append(s)
		return
	sparks[_spark_i] = s
	_spark_i = (_spark_i + 1) % SPARK_MAX


func _step_sparks(dt: float) -> void:
	for s in sparks:
		if float(s["t"]) <= 0.0:
			continue
		s["t"] = float(s["t"]) - dt
		s["p"] = (s["p"] as Vector3) + (s["v"] as Vector3) * dt
		s["v"] = (s["v"] as Vector3) + Vector3(0, -9.0, 0) * dt


func _sweep() -> void:
	var i := mobs.size() - 1
	while i >= 0:
		if mobs[i]["dead"]:
			mobs.remove_at(i)
		i -= 1
	i = shots.size() - 1
	while i >= 0:
		if shots[i]["dead"]:
			shots.remove_at(i)
		i -= 1


func _body(m: Dictionary) -> Vector3:
	var p: Vector3 = m["p"]
	return Vector3(p.x, (1.7 if m["boss"] else 0.75), p.z)
