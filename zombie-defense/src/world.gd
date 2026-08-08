class_name World
extends RefCounted

## 실시간 시뮬레이션 — 적·투사체·젬·장판과 무기 발사.
##
## 적이 수백 마리라 노드를 쓰지 않고 **사전(Dictionary) 배열**로 들고 돈다.
## 충돌은 매 프레임 다시 만드는 **격자(_grid)** 로 좁힌다. 전수 비교(O(탄×적))로는
## 300마리 × 200발에서 프레임이 무너진다.

const CELL := 84.0

var g: Game
var fx: Fx

var pos := Vector2.ZERO
## 마지막으로 움직인 방향. 조준이 필요한 무기가 이걸 본다.
var aim := Vector2.RIGHT
var iframe := 0.0
var dead := false
var cleared := false

var enemies: Array = []
var bullets: Array = []
var gems: Array = []
var areas: Array = []
var drones: Array = []
var beams: Array = []
var zaps: Array = []

var orb_ang := 0.0
var shake := 0.0

var _wcd := {}
var _spawn_acc := 0.0
var _boss_idx := 0
var _grid := {}
var _dps_t := 0.0
var _dps_acc := 0.0


func _init(game: Game, effects: Fx) -> void:
	g = game
	fx = effects
	pos = D.ARENA * 0.5

# ==================== 격자 ====================

func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _rebuild_grid() -> void:
	_grid.clear()
	for i in enemies.size():
		if enemies[i].get("dead", false):
			continue
		var k := _key(enemies[i]["p"])
		if _grid.has(k):
			_grid[k].append(i)
		else:
			_grid[k] = [i]


## 점 p 반경 r 안에 있을 법한 적 인덱스 (격자 단위라 살짝 넉넉하게 나온다)
func _near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var span := int(ceil(r / CELL))
	var k := _key(p)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var kk := Vector2i(k.x + dx, k.y + dy)
			if _grid.has(kk):
				out.append_array(_grid[kk])
	return out

# ==================== 진행 ====================

func update(dt: float, move: Vector2) -> void:
	if dead or cleared:
		return
	g.time += dt
	if g.time >= D.STAGE_TIME:
		cleared = true

	if move.length_squared() > 0.001:
		aim = move.normalized()
		pos += aim * g.speed() * dt
		pos.x = clampf(pos.x, 30.0, D.ARENA.x - 30.0)
		pos.y = clampf(pos.y, 30.0, D.ARENA.y - 30.0)

	if iframe > 0.0:
		iframe -= dt
	if g.regen() > 0.0:
		g.heal(g.regen() * dt)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 22.0)

	orb_ang += dt * 2.6

	_rebuild_grid()
	_spawn(dt)
	_step_enemies(dt)
	_fire(dt)
	_step_bullets(dt)
	_step_areas(dt)
	_step_gems(dt)
	_step_trails(dt)
	_sweep()

	_dps_t += dt
	if _dps_t >= 1.0:
		g.best_dps = maxf(g.best_dps, _dps_acc / _dps_t)
		_dps_t = 0.0
		_dps_acc = 0.0

# ==================== 스폰 ====================

func _spawn(dt: float) -> void:
	# 보스
	if _boss_idx < D.BOSS_AT.size() and g.time >= D.BOSS_AT[_boss_idx]:
		_boss_idx += 1
		_add_enemy(D.E_BOSS, _ring_point(620.0))
		fx.flash(P.CRIMSON, 0.5)
		shake = 16.0
		Snd.boss()

	var wave := D.wave_at(g.time)
	_spawn_acc += dt
	var rate: float = wave["rate"]
	if _spawn_acc < rate:
		return
	_spawn_acc = 0.0
	if enemies.size() >= D.ENEMY_CAP:
		return
	var burst: int = wave["burst"]
	for i in burst:
		if enemies.size() >= D.ENEMY_CAP:
			return
		_add_enemy(D.weighted(wave["w"]), _ring_point(randf_range(760.0, 900.0)))


## 플레이어 주위 화면 밖 어딘가
func _ring_point(dist: float) -> Vector2:
	var a := randf() * TAU
	var p := pos + Vector2(cos(a), sin(a)) * dist
	p.x = clampf(p.x, 20.0, D.ARENA.x - 20.0)
	p.y = clampf(p.y, 20.0, D.ARENA.y - 20.0)
	return p


func _add_enemy(kind: int, at: Vector2) -> void:
	var row: Dictionary = D.ENEMY[kind]
	var hp: float = row["hp"] * D.hp_scale(g.time)
	enemies.append({
		"k": kind, "p": at, "v": Vector2.ZERO,
		"hp": hp, "hpmax": hp, "r": float(row["r"]),
		"sp": float(row["spd"]) * randf_range(0.92, 1.10),
		"hit": 0.0,          # 피격 번쩍임
		"cd": randf() * 2.0, # 원거리 공격 쿨다운
		"tick": 0.0,         # 장판/사슬 재피격 간격
		"seed": randf() * 10.0,
		"face": 1.0,               # 보고 있는 쪽 (+1 오른쪽)
		"walk": randf() * TAU,     # 걷기 위상
		"boss": kind == D.E_BOSS,
	})

# ==================== 적 ====================

func _step_enemies(dt: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Dictionary = enemies[i]
		if e.get("dead", false):
			continue
		if e["hit"] > 0.0:
			e["hit"] = maxf(0.0, e["hit"] - dt * 5.0)
		if e["tick"] > 0.0:
			e["tick"] = maxf(0.0, e["tick"] - dt)

		var to: Vector2 = pos - e["p"]
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)

		# 그림에 쓸 방향과 걷기 위상. 빠른 놈일수록 다리를 빨리 움직인다.
		if absf(dir.x) > 0.15:
			e["face"] = 1.0 if dir.x > 0.0 else -1.0
		e["walk"] = float(e["walk"]) + dt * (2.4 + float(e["sp"]) * 0.055)

		# 침 뱉는 좀비는 사거리 안에서 멈춰 쏜다
		if e["k"] == D.E_SPITTER and dist < D.SPIT_RANGE:
			e["cd"] = float(e["cd"]) - dt
			if e["cd"] <= 0.0:
				e["cd"] = D.SPIT_CD
				bullets.append({
					"p": e["p"], "v": dir * D.SPIT_SPEED, "dmg": float(D.ENEMY[D.E_SPITTER]["dmg"]),
					"r": 7.0, "pierce": 1, "kind": "spit", "life": 3.2, "hits": [],
					"col": P.JADE, "foe": true,
				})
			if dist < D.SPIT_RANGE * 0.6:
				dir = -dir * 0.35

		# 넉백이 남아 있으면 그쪽이 우선
		var v: Vector2 = e["v"]
		if v.length_squared() > 4.0:
			e["p"] = e["p"] + v * dt
			e["v"] = v * exp(-dt * 6.0)
		else:
			e["p"] = e["p"] + dir * float(e["sp"]) * dt

		# 겹침 완화 — 같은 칸에 있는 놈끼리만 밀어낸다 (전수 비교는 너무 비싸다)
		var k := _key(e["p"])
		if _grid.has(k):
			for j: int in _grid[k]:
				if j == i or j >= enemies.size():
					continue
				var o: Dictionary = enemies[j]
				var d: Vector2 = e["p"] - o["p"]
				var need: float = float(e["r"]) + float(o["r"]) * 0.85
				var dl := d.length()
				if dl > 0.001 and dl < need:
					e["p"] = e["p"] + d / dl * (need - dl) * 0.5

		# 플레이어 접촉
		if dist < float(e["r"]) + D.PLAYER_R:
			_hurt(float(D.ENEMY[e["k"]]["dmg"]))


func _hurt(dmg: float) -> void:
	if iframe > 0.0 or dead:
		return
	iframe = D.IFRAME
	g.hp -= dmg
	fx.flash(P.CRIMSON, 0.28)
	shake = 9.0
	Snd.hurt()
	if g.hp <= 0.0:
		if g.revives > 0:
			g.revives -= 1
			g.hp = g.max_hp()
			iframe = 2.2
			_nuke(360.0)
			fx.flash(P.GOLD_HI, 0.7)
			Snd.revive()
		else:
			dead = true


## 주변을 싹 쓸어버린다 (부활 연출)
func _nuke(r: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i]["p"].distance_to(pos) < r and not enemies[i]["boss"]:
			_die(i)
	fx.ring(pos, P.GOLD_HI, r, 0.5)
	shake = 20.0


## 적에게 피해를 준다.
##
## **죽어도 배열에서 바로 빼지 않고 `dead` 표시만 남긴다.** 충돌 판정은 매 프레임 만든
## 격자(_grid)에 담긴 인덱스로 돌기 때문에, 중간에 remove_at 을 하면 뒤쪽 인덱스가 전부
## 한 칸씩 밀려 엉뚱한 적을 때리거나 범위를 벗어난다. 정리는 프레임 끝의 _sweep() 이 한다.
func damage(idx: int, dmg: float, at: Vector2, col: Color) -> void:
	if idx < 0 or idx >= enemies.size():
		return
	var e: Dictionary = enemies[idx]
	if e.get("dead", false):
		return
	var d := dmg * g.dmg_mult()
	e["hp"] = float(e["hp"]) - d
	e["hit"] = 1.0
	g.dealt += d
	_dps_acc += d
	fx.dmg_text(at, d, col)
	fx.spark(at, col, 3)
	if float(e["hp"]) <= 0.0:
		_die(idx)


func _die(idx: int) -> void:
	var e: Dictionary = enemies[idx]
	if e.get("dead", false):
		return
	e["dead"] = true
	var kind: int = e["k"]
	var p: Vector2 = e["p"]
	g.kills += 1

	if kind == D.E_BOMBER:
		# 폭탄 좀비는 죽으면서 터진다 — 적에게도 피해를 준다
		fx.boom(p, P.ORANGE, D.BOMB_R)
		shake = maxf(shake, 7.0)
		Snd.boom()
		for j: int in _near(p, D.BOMB_R):
			if j == idx or j >= enemies.size():
				continue
			if enemies[j]["p"].distance_to(p) < D.BOMB_R:
				damage(j, D.BOMB_DMG / maxf(0.01, g.dmg_mult()), enemies[j]["p"], P.ORANGE)
		if p.distance_to(pos) < D.BOMB_R:
			_hurt(D.BOMB_DMG)
	elif e["boss"]:
		fx.boom(p, P.GOLD_HI, 210.0)
		fx.flash(P.GOLD_HI, 0.45)
		shake = 22.0
		Snd.boss_die()
	else:
		fx.spark(p, D.ENEMY[kind]["col"], 7)
		Snd.kill()

	var xp: int = D.ENEMY[kind]["xp"]
	var drops: int = 10 if e["boss"] else 1
	for i in drops:
		var a := randf() * TAU
		gems.append({
			"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(40.0, 120.0),
			"xp": maxi(1, xp / drops) if e["boss"] else xp, "t": 0.0,
		})


func _sweep() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].get("dead", false):
			enemies.remove_at(i)

# ==================== 무기 ====================

func _cd(w: int) -> float:
	return float(_wcd.get(w, 0.0))


func _nearest(from: Vector2, within: float = 1e9) -> int:
	var best := -1
	var bd := within * within
	for i: int in _near(from, minf(within, 900.0)):
		if i >= enemies.size() or enemies[i].get("dead", false):
			continue
		var d: float = from.distance_squared_to(enemies[i]["p"])
		if d < bd:
			bd = d
			best = i
	return best


func _fire(dt: float) -> void:
	for w: int in g.weapons.keys():
		var left := _cd(w) - dt
		if left > 0.0:
			_wcd[w] = left
			continue
		_wcd[w] = g.wstat(w, "cd", 1.0) * g.cd_mult()
		_shoot(w)

	# 회전 사슬은 쿨다운이 아니라 접촉 판정이라 따로 돈다
	if g.weapons.has(D.W_CHAIN):
		_chain_touch(dt)
	if g.weapons.has(D.W_DRONE):
		_drones(dt)


func _shoot(w: int) -> void:
	var kind := String(D.WEAPON[w]["kind"])
	var dmg := g.wstat(w, "dmg", 10.0)
	var cnt := g.wcount(w) + g.extra_shots()
	var sz := g.size_mult()
	var rng := g.range_mult()

	match kind:
		"kunai":
			var pierce := int(g.wstat(w, "pierce", 1))
			# 가장 가까운 적을 향해 던진다. 이동 방향으로만 나가면 "자동 공격"이라는
			# 장르 규칙과 어긋나서, 서 있을 때 아무것도 못 하는 느낌이 든다.
			var tgt := _nearest(pos)
			var base := aim
			if tgt >= 0:
				var tp: Vector2 = enemies[tgt]["p"]
				base = (tp - pos).normalized()
			for i in cnt:
				var spread := (float(i) - (cnt - 1) * 0.5) * 0.16
				var dir := base.rotated(spread)
				bullets.append({
					"p": pos, "v": dir * 560.0, "dmg": dmg, "r": 11.0 * sz,
					"pierce": pierce, "kind": "kunai", "life": 1.5 * rng, "hits": [],
					"col": P.CYAN, "foe": false, "spin": randf() * TAU,
				})
			Snd.throw_()
		"bolt":
			var chain := int(g.wstat(w, "chain", 0))
			var hit_any := false
			for i in cnt:
				var t := _random_target(560.0 * rng)
				if t < 0:
					break
				hit_any = true
				_zap(pos + Vector2(0, -40), t, dmg, chain)
			if hit_any:
				Snd.zap()
		"field":
			var r := g.wstat(w, "radius", 100.0) * rng
			var knock := g.wstat(w, "knock", 150.0)
			areas.append({
				"p": pos, "r": r, "dmg": dmg, "life": 0.32, "max": 0.32,
				"kind": "field", "knock": knock, "follow": true, "tick": 0.0,
			})
			for i: int in _near(pos, r):
				if i >= enemies.size() or enemies[i].get("dead", false):
					continue
				var e: Dictionary = enemies[i]
				var d: Vector2 = e["p"] - pos
				if d.length() < r + float(e["r"]):
					e["v"] = e["v"] + d.normalized() * knock
			_area_damage(pos, r, dmg, P.AZURE)
			Snd.whoosh()
		"laser":
			var wdt := g.wstat(w, "width", 14.0) * sz
			for i in cnt:
				var t := _nearest(pos)
				var dir := aim
				if t >= 0:
					var tp2: Vector2 = enemies[t]["p"]
					dir = (tp2 - pos).normalized()
				dir = dir.rotated((float(i) - (cnt - 1) * 0.5) * 0.30)
				_beam(dir, dmg, wdt, 900.0 * rng)
			Snd.laser()
		"molotov":
			var r2 := g.wstat(w, "radius", 80.0) * rng
			for i in cnt:
				var a := randf() * TAU
				var at := pos + Vector2(cos(a), sin(a)) * randf_range(40.0, 190.0)
				areas.append({
					"p": at, "r": r2, "dmg": dmg, "life": 3.4, "max": 3.4,
					"kind": "fire", "knock": 0.0, "follow": false, "tick": 0.0,
				})
			Snd.fire()
		"missile":
			for i in cnt:
				var a2 := randf() * TAU
				bullets.append({
					"p": pos, "v": Vector2(cos(a2), sin(a2)) * 180.0, "dmg": dmg,
					"r": 9.0 * sz, "pierce": 1, "kind": "missile", "life": 3.0, "hits": [],
					"col": P.ORANGE, "foe": false, "home": -1,
					"blast": g.wstat(w, "radius", 60.0) * rng,
				})
			Snd.launch()


func _random_target(within: float) -> int:
	var cand: Array = []
	for i: int in _near(pos, within):
		if i < enemies.size() and not enemies[i].get("dead", false) \
				and pos.distance_to(enemies[i]["p"]) < within:
			cand.append(i)
	if cand.is_empty():
		return -1
	return cand[randi() % cand.size()]


func _zap(from: Vector2, target: int, dmg: float, chain: int) -> void:
	var pts := PackedVector2Array([from])
	var cur := target
	var used := {}
	for step in chain + 1:
		if cur < 0 or cur >= enemies.size():
			break
		var at: Vector2 = enemies[cur]["p"]
		pts.append(at)
		used[cur] = true
		damage(cur, dmg, at, P.VIOLET)
		# 연쇄 — 아직 안 맞은 가장 가까운 놈으로
		var nxt := -1
		var bd := 240.0 * 240.0
		for j: int in _near(at, 240.0):
			if j >= enemies.size() or used.has(j):
				continue
			var d: float = at.distance_squared_to(enemies[j]["p"])
			if d < bd:
				bd = d
				nxt = j
		cur = nxt
	if pts.size() > 1:
		zaps.append({"pts": pts, "life": 0.22, "max": 0.22})


func _beam(dir: Vector2, dmg: float, width: float, length: float) -> void:
	var a := pos
	var b := pos + dir * length
	beams.append({"a": a, "b": b, "w": width, "life": 0.22, "max": 0.22})
	# 선분에서 width 안에 든 적을 모두 때린다
	var steps := int(length / CELL) + 2
	var seen := {}
	for s in steps:
		var at := a + dir * (CELL * s)
		for i: int in _near(at, width + 40.0):
			if i >= enemies.size() or seen.has(i) or enemies[i].get("dead", false):
				continue
			var e: Dictionary = enemies[i]
			var rel: Vector2 = e["p"] - a
			var t := clampf(rel.dot(dir), 0.0, length)
			if (a + dir * t).distance_to(e["p"]) < width + float(e["r"]):
				seen[i] = true
	for i: int in seen.keys():
		if i < enemies.size() and not enemies[i].get("dead", false):
			damage(i, dmg, enemies[i]["p"], P.CYAN)


func _area_damage(at: Vector2, r: float, dmg: float, col: Color) -> void:
	for i: int in _near(at, r):
		if i >= enemies.size() or enemies[i].get("dead", false):
			continue
		if at.distance_to(enemies[i]["p"]) < r + float(enemies[i]["r"]):
			damage(i, dmg, enemies[i]["p"], col)


func _chain_touch(dt: float) -> void:
	var w := D.W_CHAIN
	var n := g.wcount(w)
	var rad := g.wstat(w, "radius", 90.0) * g.range_mult()
	var dmg := g.wstat(w, "dmg", 8.0)
	var orb_r := 15.0 * g.size_mult()
	var rings := 2 if g.evolved(w) else 1
	for ring in rings:
		var rr := rad * (1.0 if ring == 0 else 0.58)
		var cnt := n if rings == 1 else int(ceil(n * 0.5))
		for i in cnt:
			var a := orb_ang * (1.0 if ring == 0 else -1.35) + TAU * i / maxi(1, cnt)
			var at := pos + Vector2(cos(a), sin(a)) * rr
			for j: int in _near(at, orb_r + 30.0):
				if j >= enemies.size() or enemies[j].get("dead", false):
					continue
				var e: Dictionary = enemies[j]
				if float(e["tick"]) > 0.0:
					continue
				if at.distance_to(e["p"]) < orb_r + float(e["r"]):
					e["tick"] = 0.35
					e["v"] = e["v"] + (e["p"] - pos).normalized() * 90.0
					damage(j, dmg, at, P.GOLD)


func _drones(dt: float) -> void:
	var w := D.W_DRONE
	var want := g.wcount(w)
	while drones.size() < want:
		drones.append({"p": pos, "cd": randf() * 0.6})
	while drones.size() > want:
		drones.pop_back()

	var dmg := g.wstat(w, "dmg", 8.0)
	for i in drones.size():
		var d: Dictionary = drones[i]
		var a := orb_ang * 0.8 + TAU * i / maxi(1, drones.size())
		var want_at := pos + Vector2(cos(a), sin(a)) * 62.0 + Vector2(0, -18)
		d["p"] = d["p"].lerp(want_at, clampf(dt * 6.0, 0.0, 1.0))
		d["cd"] = float(d["cd"]) - dt
		if float(d["cd"]) <= 0.0:
			var t := _nearest(d["p"], 460.0 * g.range_mult())
			if t >= 0:
				d["cd"] = g.wstat(w, "cd", 0.8) * g.cd_mult()
				var ep3: Vector2 = enemies[t]["p"]
				var dp3: Vector2 = d["p"]
				var dir: Vector2 = (ep3 - dp3).normalized()
				bullets.append({
					"p": d["p"], "v": dir * 620.0, "dmg": dmg, "r": 6.0 * g.size_mult(),
					"pierce": 1, "kind": "pellet", "life": 1.2, "hits": [],
					"col": P.JADE, "foe": false,
				})

# ==================== 투사체 ====================

func _step_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			if String(b["kind"]) == "missile":
				_explode(b)
			bullets.remove_at(i)
			continue

		if String(b["kind"]) == "missile":
			var t: int = int(b.get("home", -1))
			if t < 0 or t >= enemies.size():
				t = _nearest(b["p"], 700.0)
				b["home"] = t
			if t >= 0 and t < enemies.size():
				var hp2: Vector2 = enemies[t]["p"]
				var bp: Vector2 = b["p"]
				var want: Vector2 = (hp2 - bp).normalized() * 430.0
				b["v"] = b["v"].lerp(want, clampf(dt * 3.4, 0.0, 1.0))

		b["p"] = b["p"] + b["v"] * dt

		if bool(b["foe"]):
			if b["p"].distance_to(pos) < float(b["r"]) + D.PLAYER_R:
				_hurt(float(b["dmg"]))
				bullets.remove_at(i)
			continue

		var hits: Array = b["hits"]
		var done := false
		for j: int in _near(b["p"], float(b["r"]) + 40.0):
			if j >= enemies.size() or hits.has(j) or enemies[j].get("dead", false):
				continue
			if b["p"].distance_to(enemies[j]["p"]) < float(b["r"]) + float(enemies[j]["r"]):
				if String(b["kind"]) == "missile":
					_explode(b)
					done = true
					break
				hits.append(j)
				damage(j, float(b["dmg"]), b["p"], b["col"])
				b["pierce"] = int(b["pierce"]) - 1
				if int(b["pierce"]) <= 0:
					done = true
					break
		if done:
			bullets.remove_at(i)


func _explode(b: Dictionary) -> void:
	var r := float(b.get("blast", 60.0))
	fx.boom(b["p"], P.ORANGE, r)
	Snd.boom()
	shake = maxf(shake, 4.0)
	_area_damage(b["p"], r, float(b["dmg"]), P.ORANGE)

# ==================== 장판 ====================

func _step_areas(dt: float) -> void:
	# 절대 방벽(포스 필드 진화)은 늘 켜져 있다
	if g.evolved(D.W_FIELD):
		var has := false
		for a: Dictionary in areas:
			if String(a["kind"]) == "aegis":
				has = true
				break
		if not has:
			areas.append({
				"p": pos, "r": g.wstat(D.W_FIELD, "radius", 200.0) * g.range_mult(),
				"dmg": g.wstat(D.W_FIELD, "dmg", 30.0), "life": 1e9, "max": 1e9,
				"kind": "aegis", "knock": 80.0, "follow": true, "tick": 0.0,
			})

	for i in range(areas.size() - 1, -1, -1):
		var a: Dictionary = areas[i]
		a["life"] = float(a["life"]) - dt
		if bool(a["follow"]):
			a["p"] = pos
		if String(a["kind"]) != "field":
			a["tick"] = float(a["tick"]) - dt
			if float(a["tick"]) <= 0.0:
				a["tick"] = 0.32
				_area_damage(a["p"], float(a["r"]), float(a["dmg"]) * 0.32, P.ORANGE)
				if float(a["knock"]) > 0.0:
					for j: int in _near(a["p"], float(a["r"])):
						if j >= enemies.size() or enemies[j].get("dead", false):
							continue
						var e: Dictionary = enemies[j]
						var d: Vector2 = e["p"] - a["p"]
						if d.length() < float(a["r"]):
							e["v"] = e["v"] + d.normalized() * float(a["knock"])
		if float(a["life"]) <= 0.0:
			areas.remove_at(i)

# ==================== 경험치 젬 ====================

func _step_gems(dt: float) -> void:
	var pr := g.pickup()
	for i in range(gems.size() - 1, -1, -1):
		var gm: Dictionary = gems[i]
		gm["t"] = float(gm["t"]) + dt
		var d: Vector2 = pos - gm["p"]
		var dl := d.length()
		if dl < pr:
			# 끌려온다 — 가까울수록 빨라져서 확 빨려 들어가는 맛이 난다
			gm["p"] = gm["p"] + d.normalized() * (300.0 + (pr - dl) * 6.0) * dt
		else:
			# 수집 범위 밖이어도 따라온다. 이게 없으면 멀리서 죽인 적의 젬이 맵에 그대로 남아
			# 경험치가 안 들어온다. 멀수록 빨리 와야 원거리 무기를 써도 레벨이 오른다.
			gm["p"] = gm["p"] + gm["v"] * dt + d.normalized() * clampf(70.0 + dl * 0.30, 70.0, 320.0) * dt
			gm["v"] = gm["v"] * exp(-dt * 3.4)
		if dl < 22.0:
			g.gain_xp(int(gm["xp"]))
			fx.spark(gm["p"], P.XP, 2)
			Snd.pick()
			gems.remove_at(i)


func _step_trails(dt: float) -> void:
	for i in range(beams.size() - 1, -1, -1):
		beams[i]["life"] = float(beams[i]["life"]) - dt
		if float(beams[i]["life"]) <= 0.0:
			beams.remove_at(i)
	for i in range(zaps.size() - 1, -1, -1):
		zaps[i]["life"] = float(zaps[i]["life"]) - dt
		if float(zaps[i]["life"]) <= 0.0:
			zaps.remove_at(i)
