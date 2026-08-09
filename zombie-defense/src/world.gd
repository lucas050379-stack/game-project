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
## 마지막으로 움직인 방향. 겨눌 적이 하나도 없을 때의 기본 조준 방향이다.
var aim := Vector2.RIGHT
## 실제로 총을 겨누는 방향 — 가장 가까운 적 쪽. 그림(Art.hero)과 탄이 같은 값을 봐야
## 총구에서 탄이 나가는 것처럼 보인다. 적이 없으면 aim 을 그대로 쓴다.
var look := Vector2.RIGHT
var iframe := 0.0
var dead := false
## 이번 **라운드**를 버텨 냈다. main.gd 가 보고 클리어 화면으로 넘어간다.
var cleared := false

## 이번 라운드의 맵 크기. 라운드마다 맵이 바뀌므로 상수가 아니다.
var arena := Vector2.ZERO
## 아직 안 나온 보스가 나올 시각들 (라운드 시작 기준)
var _boss_at: Array = []

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
var _grid := {}
var _dps_t := 0.0
var _dps_acc := 0.0


func _init(game: Game, effects: Fx) -> void:
	g = game
	fx = effects
	begin_round()


## 라운드 시작 — 맵을 갈아 끼우고 가운데로 옮기고 남아 있던 것들을 치운다.
## 무기·레벨은 [Game] 이 들고 있으므로 여기서 손대지 않는다.
func begin_round() -> void:
	var size: Vector2 = g.map()["size"]
	arena = size
	pos = arena * 0.5
	enemies.clear()
	bullets.clear()
	gems.clear()
	areas.clear()
	drones.clear()
	beams.clear()
	zaps.clear()
	_wcd.clear()
	_spawn_acc = 0.0
	iframe = 1.2
	dead = false
	cleared = false
	shake = 0.0

	# 이 라운드에 섞어 낼 티어. 라운드 내내 고정이다.
	var mix := D.tier_mix(g.round_no)
	_tier_lo = int(mix[0])
	_tier_hi_p = float(mix[1])

	# 보스는 라운드 후반에 고르게 나온다. 1라운드는 없다.
	_boss_at.clear()
	var n := D.round_bosses(g.round_no)
	var dur := D.round_time(g.round_no)
	for i in n:
		_boss_at.append(dur * (0.55 + 0.35 * (float(i) / maxf(1.0, float(n)))))

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


## 총구가 향할 방향. 격자를 다시 만든 직후에 한 번만 계산한다 —
## 그리기 쪽과 쏘는 쪽이 각자 가장 가까운 적을 찾으면 한 프레임 어긋나 총구와 탄이 따로 논다.
func _aim_at_nearest() -> void:
	var t := _nearest(pos)
	if t < 0:
		look = aim
		return
	var d: Vector2 = enemies[t]["p"] - pos
	look = d.normalized() if d.length_squared() > 1.0 else aim


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
	if g.time >= D.round_time(g.round_no):
		cleared = true

	if move.length_squared() > 0.001:
		aim = move.normalized()
		pos += aim * g.speed() * dt
		pos.x = clampf(pos.x, 30.0, arena.x - 30.0)
		pos.y = clampf(pos.y, 30.0, arena.y - 30.0)

	if iframe > 0.0:
		iframe -= dt
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 22.0)

	# 회전 사슬이 도는 각도. 빠를수록 같은 반지름에서 더 많은 적을 훑는다.
	# 드론도 이 값을 보는데 궤도 도는 속도는 그대로여야 해서 아래에서 배수를 낮춰 맞춘다.
	orb_ang += dt * 4.4

	_rebuild_grid()
	_aim_at_nearest()
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

## 이번 라운드에 뽑을 티어. `[낮은 티어, 높은 티어 확률]` — 라운드 내내 고정이라
## 라운드가 시작할 때 한 번만 구해 둔다.
var _tier_lo := 0
var _tier_hi_p := 0.0


## 종 하나를 뽑아 이 라운드의 티어를 입힌다. **라운드가 난이도를 내는 통로는 여기뿐이다.**
func _roll_kind(w: Array) -> int:
	var species := D.weighted(w)
	var tier := _tier_lo + (1 if randf() < _tier_hi_p else 0)
	return mini(D.TIERS - 1, tier) * D.SPECIES + species


func _spawn(dt: float) -> void:
	# 보스 — 라운드 후반에 나온다
	while not _boss_at.is_empty() and g.time >= float(_boss_at[0]):
		_boss_at.remove_at(0)
		_add_enemy(D.E_BOSS, _ring_point(620.0))
		fx.flash(P.CRIMSON, 0.5)
		shake = 16.0
		Snd.boss()

	# **스폰 간격과 수는 라운드를 보지 않는다.** 모든 라운드가 같은 표로 달아오르고,
	# 라운드 차이는 `_roll_kind` 의 티어가 전부 낸다.
	var wave := D.wave_at(g.time, g.round_no)
	_spawn_acc += dt
	if _spawn_acc < float(wave["rate"]):
		return
	_spawn_acc = 0.0
	if enemies.size() >= D.ENEMY_CAP:
		return
	for i in int(wave["burst"]):
		if enemies.size() >= D.ENEMY_CAP:
			return
		_add_enemy(_roll_kind(wave["w"]), _ring_point(randf_range(760.0, 900.0)))


## 이 라운드를 얼마나 지나왔나 (0~1). 판 안의 체력 배율이 초가 아니라 이 값을 본다 —
## 라운드 길이가 2~5분으로 다르므로 초로 세면 긴 라운드가 그 사실만으로 더 어려워진다.
func _prog() -> float:
	return clampf(g.time / maxf(1.0, D.round_time(g.round_no)), 0.0, 1.0)


## 플레이어 주위 화면 밖 어딘가
func _ring_point(dist: float) -> Vector2:
	var a := randf() * TAU
	var p := pos + Vector2(cos(a), sin(a)) * dist
	p.x = clampf(p.x, 20.0, arena.x - 20.0)
	p.y = clampf(p.y, 20.0, arena.y - 20.0)
	return p


func _add_enemy(kind: int, at: Vector2) -> void:
	var row: Dictionary = D.ENEMY[kind]
	# **라운드 배율은 없다.** 표에 적힌 체력에 판 안의 시간 배율만 곱한다 — 라운드가 내는
	# 차이는 어떤 티어의 줄을 읽었느냐에 이미 들어 있다.
	# 보스만 예외다. 티어 격자 밖에 있어서 이 라운드의 티어 배율을 여기서 직접 곱한다.
	var hp: float = float(row["hp"]) * D.hp_scale(_prog())
	if kind == D.E_BOSS:
		hp *= lerpf(float(D.TIER_MUL[_tier_lo]),
			float(D.TIER_MUL[mini(D.TIERS - 1, _tier_lo + 1)]), _tier_hi_p)
	# 특수 행동은 **그림 접두어로** 정한다 — 상위 종(맹독 침 좀비 등)이 기본형의 행동을
	# 그대로 물려받게 하려는 것이다. 종류 번호로 비교하면 변종을 추가할 때마다 빠뜨린다.
	var art: String = row["art"]
	enemies.append({
		"k": kind, "p": at,
		"hp": hp, "hpmax": hp, "r": float(row["r"]),
		"spits": art == "spitter",
		"sp": float(row["spd"]) * randf_range(0.92, 1.10),
		"hit": 0.0,          # 피격 번쩍임
		"cd": randf() * 2.0, # 원거리 공격 쿨다운
		"tick": 0.0,         # 장판/사슬 재피격 간격
		"seed": randf() * 10.0,
		"face": 1.0,               # 보고 있는 쪽 (+1 오른쪽)
		"walk": randf() * TAU,     # 걷기 위상
		"boss": kind == D.E_BOSS,
		# 보스 스킬 상태 (`_boss_ai`). 보스가 아니면 쓰이지 않지만, 사전의 모양을 하나로
		# 두면 `e["cast"]` 를 읽는 곳마다 있는지 없는지 따질 필요가 없다.
		"bcd": D.BOSS_SKILL_CD * randf_range(0.5, 0.9),  # 첫 스킬은 나오자마자 쓰지 않는다
		"cast": 0.0, "cast_max": D.BOSS_CAST, "skill": "",
		"dash": 0.0, "dv": Vector2.RIGHT,
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
		if e["spits"] and dist < D.SPIT_RANGE:
			e["cd"] = float(e["cd"]) - dt
			if e["cd"] <= 0.0:
				e["cd"] = D.SPIT_CD
				bullets.append({
					"p": e["p"], "v": dir * D.SPIT_SPEED, "dmg": float(D.ENEMY[e["k"]]["dmg"]),
					"r": 7.0, "pierce": 1, "kind": "spit", "life": 3.2, "hits": [],
					# 적이 쏜 것은 `P.VENOM`(분홍) 하나로 통일한다 — 이유는 `pal.gd` 참고.
					"col": P.VENOM, "foe": true,
				})
				# 소리로도 알린다. 눈이 다른 데 가 있어도 "쐈다"는 것만은 들리게.
				Snd.spit()
			if dist < D.SPIT_RANGE * 0.6:
				dir = -dir * 0.35

		# **적을 밀어내는 수단은 이 게임에 없다.** 예전에는 포스 필드·회전 사슬이 넉백을
		# 걸었는데, 그러면 근접 적이 영영 플레이어에게 닿지 못해 판이 성립하지 않았다.
		# 그래서 여기도 속도 항 없이 곧장 플레이어 쪽으로만 걷는다.
		#
		# 보스만 예외다 — 스킬을 쓰는 동안은 멈추거나 돌진하므로 걸음을 대신 맡긴다.
		if not (e["boss"] and _boss_ai(e, dt, dist, dir)):
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


# -------------------- 보스 스킬 --------------------
#
# **보스가 걷기만 하면 큰 좀비일 뿐이다.** 체력이 높아 오래 살아 있는데 하는 일이 없으면
# 화면에 남아 있는 시간이 그대로 지루함이 된다. 거리에 따라 셋 중 하나를 쓴다:
#
#   먼 거리  → 돌진   예고한 방향으로 4배 속도로 달린다 (옆으로 피한다)
#   가까이    → 강타   발밑을 내리쳐 반경 300 충격파      (밖으로 뛴다)
#   그 사이   → 산탄   부채꼴로 분홍 탄 7발               (차단 스킬로 지워진다)
#
# **셋 다 예비 동작(`cast`) 뒤에 나간다.** 그 동안 보스는 멈춰 서고 화면에는 경고가 뜬다
# (`Art._boss_cast`). 예고 없이 즉발로 터지면 피할 방법이 없어 난이도가 아니라 불합리가 된다.

## 보스의 한 프레임. **걸음을 여기서 처리했으면 true** — 부르는 쪽은 그러면 안 걷는다.
func _boss_ai(e: Dictionary, dt: float, dist: float, dir: Vector2) -> bool:
	# 돌진 중 — 예고한 방향으로만 곧장 달린다. 방향을 계속 고쳐 잡으면 피할 수가 없다.
	if float(e["dash"]) > 0.0:
		e["dash"] = float(e["dash"]) - dt
		var np: Vector2 = e["p"] + Vector2(e["dv"]) * float(e["sp"]) * D.BOSS_DASH_MUL * dt
		np.x = clampf(np.x, 20.0, arena.x - 20.0)
		np.y = clampf(np.y, 20.0, arena.y - 20.0)
		e["p"] = np
		return true

	# 예비 동작 — 멈춰 서서 힘을 모은다. 멈추는 것 자체가 플레이어에게 주는 시간이다.
	if float(e["cast"]) > 0.0:
		e["cast"] = float(e["cast"]) - dt
		if float(e["cast"]) <= 0.0:
			_boss_cast(e)
		return true

	e["bcd"] = float(e["bcd"]) - dt
	if float(e["bcd"]) > 0.0:
		return false

	e["bcd"] = D.BOSS_SKILL_CD
	e["skill"] = "dash" if dist > D.BOSS_FAR else ("slam" if dist < D.BOSS_NEAR else "volley")
	# **방향은 스킬을 고르는 순간 정한다.** 예비 동작 동안 계속 고쳐 잡으면 화면의 경고
	# 표시가 실제로 나갈 방향과 달라져서, 경고를 보고 피한 사람이 그대로 맞는다.
	e["dv"] = dir
	e["cast"] = D.BOSS_CAST
	e["cast_max"] = D.BOSS_CAST
	Snd.boss_cast()
	return true


## 예비 동작이 끝나는 순간. 여기서 실제로 스킬이 나간다.
## **겨눈 방향은 `dv`(고를 때 정한 값)를 쓴다** — 화면의 경고와 같은 값이어야 한다.
func _boss_cast(e: Dictionary) -> void:
	var at: Vector2 = e["p"]
	var dir: Vector2 = e["dv"]
	# 접촉 피해를 기준으로 잡는다 — 티어 배율이 이미 거기 들어 있어서 라운드가 올라도
	# "몇 대 맞으면 죽나"가 접촉과 같은 비율로 따라온다.
	var base := float(D.ENEMY[int(e["k"])]["dmg"])
	match String(e["skill"]):
		"dash":
			e["dash"] = D.BOSS_DASH_TIME
			fx.ring(at, P.CRIMSON, 140.0, 0.28)
			Snd.boss_dash()
		"slam":
			fx.boom(at, P.CRIMSON, D.BOSS_SLAM_R)
			shake = maxf(shake, 15.0)
			Snd.boom()
			# **다른 적은 안 다친다.** 보스가 자기 무리를 갈아 버리면 오히려 판이 쉬워진다.
			if at.distance_to(pos) < D.BOSS_SLAM_R + D.PLAYER_R:
				_hurt(base * D.BOSS_SLAM_DMG)
		"volley":
			for i in D.BOSS_VOLLEY:
				var k := (float(i) - (D.BOSS_VOLLEY - 1) * 0.5) / maxf(1.0, D.BOSS_VOLLEY - 1)
				var d := dir.rotated(k * D.BOSS_VOLLEY_ARC)
				# 침 뱉는 좀비와 **같은 kind·같은 색**이다 — 분홍은 피한다는 규칙을 그대로
				# 잇고, 차단 스킬도 자동으로 이걸 지운다. 보스 것은 반지름만 크다.
				bullets.append({
					"p": at + d * 40.0, "v": d * D.BOSS_SHOT_SPEED,
					"dmg": base * D.BOSS_SHOT_DMG, "r": 11.0, "pierce": 1,
					"kind": "spit", "life": 4.0, "hits": [], "col": P.VENOM, "foe": true,
				})
			Snd.spit()
	e["skill"] = ""


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
	var d := dmg
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

	if String(D.ENEMY[kind]["art"]) == "bomber":
		# 폭탄 좀비는 죽으면서 터진다 — 적에게도 피해를 준다. 상위 종도 같이 터진다.
		fx.boom(p, P.ORANGE, D.BOMB_R)
		shake = maxf(shake, 7.0)
		Snd.boom()
		for j: int in _near(p, D.BOMB_R):
			if j == idx or j >= enemies.size():
				continue
			if enemies[j]["p"].distance_to(p) < D.BOMB_R:
				damage(j, D.BOMB_DMG, enemies[j]["p"], P.ORANGE)
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
			"xp": maxi(1, xp / drops) if e["boss"] else xp, "t": 0.0, "k": kind,
		})


func _sweep() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].get("dead", false):
			enemies.remove_at(i)

# ==================== 무기 ====================

func _cd(w: int) -> float:
	return float(_wcd.get(w, 0.0))


## 격자 탐색의 상한. `_near` 는 반경을 칸 수로 바꿔 정사각형을 훑으므로 **비용이 반경의
## 제곱으로 는다** — 1200 이면 29×29칸이다. 궁수의 관통 저격이 화면 끝을 봐야 해서
## 900 에서 여기까지 올렸고, 그보다 멀리 보는 스킬은 두지 않는다.
const NEAR_CAP := 1200.0


## from 에서 가장 가까운 적. `skip` 에 든 인덱스는 건너뛴다 —
## 한 번에 여러 마리를 각각 겨누는 스킬(관통 저격)이 같은 놈을 두 번 쏘지 않게 하려는 것이다.
func _nearest(from: Vector2, within: float = 1e9, skip: Dictionary = {}) -> int:
	var best := -1
	var bd := within * within
	for i: int in _near(from, minf(within, NEAR_CAP)):
		if i >= enemies.size() or enemies[i].get("dead", false) or skip.has(i):
			continue
		var d: float = from.distance_squared_to(enemies[i]["p"])
		if d < bd:
			bd = d
			best = i
	return best


## 쿨다운으로 발사하지 않는 스킬들. 각자 자기 함수에서 돈다 —
## 접촉 판정(회전 사슬)이거나, 상시 전개(강철 방벽·반사 결계)이거나, 따라다니는 것(사냥매)이다.
## **여기 빠뜨리면 `_shoot` 이 분기 없이 헛돌면서 쿨다운만 돌린다** (조용히 아무 일도 안 일어난다).
const SELF_RUN := ["chain", "guard", "ward", "hawk"]


func _fire(dt: float) -> void:
	for w: int in g.weapons.keys():
		if String(D.WEAPON[w]["kind"]) in SELF_RUN:
			continue
		var left := _cd(w) - dt
		if left > 0.0:
			_wcd[w] = left
			continue
		_wcd[w] = g.wstat(w, "cd", 1.0)
		_shoot(w)

	# 회전 사슬은 쿨다운이 아니라 접촉 판정이라 따로 돈다
	if g.weapons.has(D.W_CHAIN):
		_chain_touch(dt)
	if g.weapons.has(D.W_HAWK):
		_drones(dt)


func _shoot(w: int) -> void:
	var kind := String(D.WEAPON[w]["kind"])
	var dmg := g.wstat(w, "dmg", 10.0)
	var cnt := g.wcount(w)

	match kind:
		"whirl":
			# **무사의 고유 스킬 — 방향이 없다.** 반경 안이면 등 뒤도 똑같이 벤다.
			# 사거리가 짧은 대신 겨냥이 필요 없다는 것이 이 스킬의 전부다.
			var wr := g.wstat(w, "radius", 140.0)
			areas.append({
				"p": pos, "r": wr, "dmg": dmg, "life": 0.26, "max": 0.26,
				"kind": "whirl", "follow": true, "tick": 0.0, "dot": false,
				"ang": look.angle(), "twin": g.evolved(w),
			})
			_area_damage(pos, wr, dmg, P.GOLD_HI)
			Snd.slash()
		"quake":
			# 발밑을 내리쳐 사방으로. 회전 참격보다 훨씬 넓고 훨씬 느리다.
			var qr := g.wstat(w, "radius", 100.0)
			areas.append({
				"p": pos, "r": qr, "dmg": dmg, "life": 0.34, "max": 0.34,
				"kind": "quake", "follow": true, "tick": 0.0, "dot": false,
			})
			_area_damage(pos, qr, dmg, P.AZURE)
			shake = maxf(shake, 3.0)
			Snd.whoosh()
		"axe":
			# 던지고 **돌아온다.** 돌아오는 길에 맞은 목록을 비우므로 한 번 던지면 두 번 훑는다
			# (`_step_bullets` 의 "axe" 참고).
			var apierce := int(g.wstat(w, "pierce", 3))
			for i in cnt:
				var ad := look.rotated((float(i) - (cnt - 1) * 0.5) * 0.34)
				bullets.append({
					"p": pos, "v": ad * 640.0, "dmg": dmg, "r": 15.0,
					"pierce": apierce, "pierce0": apierce, "kind": "axe",
					"life": 1.7, "hits": [], "col": P.GOLD, "foe": false,
					"back": 0.40, "spin": randf() * TAU,
				})
			Snd.throw_()
		"fireball":
			# **마법사의 고유 스킬 — 한 방향으로 날아가 맞은 자리를 터뜨린다.**
			# `blast` 가 있으므로 `_step_bullets` 가 명중·소멸 어느 쪽이든 `_explode` 를 부른다.
			var fmuz := pos + look * (D.PLAYER_R * 1.5)
			for i in cnt:
				var fd := look.rotated((float(i) - (cnt - 1) * 0.5) * 0.17)
				bullets.append({
					"p": fmuz, "v": fd * 700.0, "dmg": dmg, "r": 11.0,
					"pierce": 1, "kind": "fireball", "life": 1.8, "hits": [],
					"col": P.ORANGE, "foe": false, "blast": g.wstat(w, "radius", 90.0),
				})
			Snd.cast()
		"snipe":
			# **궁수의 고유 스킬 — 언제나 한 마리씩.** 관통도 폭발도 없다.
			# 표적을 못 찾으면 아무것도 안 쏜다(허공에 쏘는 그림이 더 이상하다).
			_snipe(dmg, g.wstat(w, "range", 900.0), cnt)
		"arrow":
			var pierce := int(g.wstat(w, "pierce", 1))
			# `look` 은 이미 가장 가까운 적을 향한다 — 그림의 활과 같은 값이라야
			# 화살이 활에서 나가는 것처럼 보인다. 이동 방향으로만 쏘면 서 있을 때
			# 아무것도 못 해서 "공격은 자동"이라는 장르 규칙이 깨진다.
			var muz := pos + look * (D.PLAYER_R * 2.4)
			for i in cnt:
				# 연사라 화살마다 조금씩 흩어져야 한다. 정확히 겹쳐 나가면 한 발로 보인다.
				# 무사가 산탄으로 진화시켰으면 훨씬 넓게 퍼지고 사거리가 짧다.
				var wide := 0.20 if g.evolved(w) and not g.evo_alt(w).is_empty() else 0.07
				var spread := (float(i) - (cnt - 1) * 0.5) * wide + randf_range(-0.025, 0.025)
				bullets.append({
					"p": muz, "v": look.rotated(spread) * 1050.0, "dmg": dmg, "r": 5.0,
					"pierce": pierce, "kind": "arrow", "life": 0.85, "hits": [],
					"col": P.GOLD_HI, "foe": false,
				})
			fx.spark(muz, P.GOLD_HI, 2)
			Snd.bow()
		"intercept":
			# 탄을 지우는 것은 `_step_bullets` 가 반경으로 하고, 여기서는 **남는 화살로**
			# 가장 가까운 적을 쏜다. 겨눈 놈이 없으면 쏘지 않는다.
			var used := {}
			var shot := false
			for i in cnt:
				var it := _nearest(pos, 720.0, used)
				if it < 0:
					break
				used[it] = true
				shot = true
				var idir: Vector2 = (Vector2(enemies[it]["p"]) - pos).normalized()
				bullets.append({
					"p": pos + idir * (D.PLAYER_R * 1.4), "v": idir * 940.0, "dmg": dmg,
					"r": 6.0, "pierce": 1, "kind": "intercept", "life": 1.0, "hits": [],
					"col": P.JADE, "foe": false,
				})
			if shot:
				Snd.bow()
		"bolt":
			var chain := int(g.wstat(w, "chain", 0))
			# 무사가 "낙뢰 강타"로 진화시켰으면 멀리 튀지 않고 **발밑 주변**에 꽂힌다.
			var reach := 300.0 if g.evolved(w) and not g.evo_alt(w).is_empty() else 560.0
			var hit_any := false
			for i in cnt:
				var t := _random_target(reach)
				if t < 0:
					break
				hit_any = true
				_zap(pos + Vector2(0, -40), t, dmg, chain)
			if hit_any:
				Snd.zap()
		"frost":
			var wdt := g.wstat(w, "width", 14.0)
			# 궁수가 "서리 화살"로 진화시켰으면 갈라지지 않고 곧게 나간다.
			var fan := 0.06 if g.evolved(w) and not g.evo_alt(w).is_empty() else 0.30
			for i in cnt:
				var dir := look.rotated((float(i) - (cnt - 1) * 0.5) * fan)
				_beam(dir, dmg, wdt, 900.0, P.CYAN)
			Snd.laser()
		"flame":
			var r2 := g.wstat(w, "radius", 80.0)
			for i in cnt:
				var a := randf() * TAU
				var at := pos + Vector2(cos(a), sin(a)) * randf_range(40.0, 190.0)
				areas.append({
					"p": at, "r": r2, "dmg": dmg, "life": 3.4, "max": 3.4,
					"kind": "fire", "follow": false, "tick": 0.0, "dot": true,
				})
			Snd.fire()
		"homing":
			for i in cnt:
				var a2 := randf() * TAU
				# 처음에는 사방으로 흩어졌다가 목표를 잡고 꺾인다. 그 초기 속도가 180 이라
				# 한참을 느릿느릿 떠다녔다 — 360 으로 올려 바로 날아가게 한다.
				# **폭발이 없다** (`blast` 없음) — 궁수 것이라 맞은 한 마리에게만 들어간다.
				bullets.append({
					"p": pos, "v": Vector2(cos(a2), sin(a2)) * 360.0, "dmg": dmg,
					"r": 9.0, "pierce": 1, "kind": "homing", "life": 2.4, "hits": [],
					"col": P.JADE, "foe": false, "seek": 0.0,
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


## 관통 저격 — **한 발이 한 마리.** 겨눌 놈을 `cnt` 마리까지 각각 골라 그때그때 꽂는다.
##
## 투사체를 날리지 않고 그 자리에서 맞힌다. 사거리가 1,000 가까이 되는데 탄으로 만들면
## 도착할 때쯤 적이 이미 딴 데 가 있어서 "먼 거리 저격"이라는 느낌이 안 난다 —
## 화면에는 궤적만 잠깐 남는다.
func _snipe(dmg: float, rng: float, cnt: int) -> void:
	var used := {}
	var any := false
	for i in cnt:
		var t := _nearest(pos, rng, used)
		if t < 0:
			break
		used[t] = true
		any = true
		var at: Vector2 = enemies[t]["p"]
		beams.append({
			"a": pos, "b": at, "w": 5.0, "life": 0.20, "max": 0.20, "col": P.GOLD_HI,
		})
		damage(t, dmg, at, P.GOLD_HI)
	if any:
		Snd.bow()


func _beam(dir: Vector2, dmg: float, width: float, length: float,
		col: Color = P.CYAN) -> void:
	var a := pos
	var b := pos + dir * length
	beams.append({"a": a, "b": b, "w": width, "life": 0.22, "max": 0.22, "col": col})
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
	var rad := g.wstat(w, "radius", 90.0)
	var dmg := g.wstat(w, "dmg", 8.0)
	var orb_r := 15.0
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
					# 여기도 밀어내지 않는다 — 광역 스킬과 같은 이유다(파일 첫머리 주석 참고).
					e["tick"] = 0.35
					damage(j, dmg, at, P.GOLD)


## 사냥매(마법사가 진화시키면 정령). 따라다니며 스스로 쏜다 — 궤도는 회전 사슬과 같은
## 각도(`orb_ang`)를 보되 배수를 낮춰 도는 속도를 맞춘다.
func _drones(dt: float) -> void:
	var w := D.W_HAWK
	var want := g.wcount(w)
	while drones.size() < want:
		drones.append({"p": pos, "cd": randf() * 0.6})
	while drones.size() > want:
		drones.pop_back()

	var dmg := g.wstat(w, "dmg", 8.0)
	for i in drones.size():
		var d: Dictionary = drones[i]
		var a := orb_ang * 0.47 + TAU * i / maxi(1, drones.size())
		var want_at := pos + Vector2(cos(a), sin(a)) * 62.0 + Vector2(0, -18)
		d["p"] = d["p"].lerp(want_at, clampf(dt * 6.0, 0.0, 1.0))
		d["cd"] = float(d["cd"]) - dt
		if float(d["cd"]) <= 0.0:
			var t := _nearest(d["p"], 460.0)
			if t >= 0:
				d["cd"] = g.wstat(w, "cd", 0.8)
				var ep3: Vector2 = enemies[t]["p"]
				var dp3: Vector2 = d["p"]
				var dir: Vector2 = (ep3 - dp3).normalized()
				bullets.append({
					"p": d["p"], "v": dir * 620.0, "dmg": dmg, "r": 6.0,
					"pierce": 1, "kind": "pellet", "life": 1.2, "hits": [],
					"col": P.JADE, "foe": false,
				})

# ==================== 투사체 ====================

## 적 탄을 지우는 반경. **차단 스킬(`block`) 중 가장 넓은 것 하나만 본다** —
## 여러 개를 들어도 겹쳐서 더 넓어지지는 않는다(둘 다 들 이유가 없어지면 안 되므로
## 넓은 쪽이 이긴다는 규칙 하나로 끝낸다). 무기 레벨이 오르면 그대로 따라 넓어진다.
func _block_r() -> float:
	var r := 0.0
	for w: int in g.weapons.keys():
		if bool(D.WEAPON[w].get("block", false)):
			r = maxf(r, g.wstat(w, "radius", 0.0))
	return r


func _step_bullets(dt: float) -> void:
	# 매 프레임 한 번만 구한다 — 탄 200발마다 무기 목록을 훑을 이유가 없다.
	var block := _block_r()
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var kind := String(b["kind"])
		var blast := float(b.get("blast", 0.0))
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			# **터지는 것은 `blast` 를 가진 탄뿐이다.** 화염구는 허공에서 수명이 다해도
			# 터지고, 유도 화살(궁수)은 폭발이 없으므로 그냥 사라진다.
			if blast > 0.0:
				_explode(b)
			bullets.remove_at(i)
			continue

		if b.has("seek"):
			# 목표를 **좌표로** 들고 다니고 이따금씩만 다시 찾는다.
			#
			# 예전에는 적의 **인덱스**를 들고 있었는데, `_sweep()` 이 죽은 적을 배열에서
			# 빼면 뒤쪽 인덱스가 전부 밀려서 유도탄이 갑자기 엉뚱한 적으로 방향을 틀었다.
			# 그게 "버벅"거리는 것처럼 보인 원인이다. 게다가 인덱스가 어긋날 때마다
			# 반경 700 으로 `_nearest` 를 다시 돌려서(격자 19×19칸) 비싸기까지 했다.
			b["seek"] = float(b.get("seek", 0.0)) - dt
			if float(b["seek"]) <= 0.0:
				b["seek"] = 0.12
				var t := _nearest(b["p"], 520.0)
				if t >= 0:
					b["to"] = enemies[t]["p"]
			if b.has("to"):
				var want: Vector2 = (Vector2(b["to"]) - Vector2(b["p"])).normalized() * 760.0
				b["v"] = b["v"].lerp(want, clampf(dt * 6.5, 0.0, 1.0))

		if kind == "axe":
			# 던진 도끼는 돌아온다. 돌아서는 순간 **맞은 목록과 관통을 되돌려** 오는 길에
			# 한 번 더 베게 한다 — 한 번 던져 두 번 훑는 것이 이 스킬의 값어치다.
			b["back"] = float(b["back"]) - dt
			if float(b["back"]) <= 0.0:
				if not bool(b.get("turned", false)):
					b["turned"] = true
					b["hits"] = []
					b["pierce"] = int(b.get("pierce0", b["pierce"]))
				var home: Vector2 = (pos - Vector2(b["p"])).normalized() * 820.0
				b["v"] = b["v"].lerp(home, clampf(dt * 3.4, 0.0, 1.0))
				if b["p"].distance_to(pos) < 44.0:
					bullets.remove_at(i)
					continue

		b["p"] = b["p"] + b["v"] * dt

		if bool(b["foe"]):
			# **차단 스킬이 켜져 있으면 반경 안에서 지워진다.** 세 직업이 각자 다른 그림으로
			# 막지만(방패·결계·요격) 결과는 하나다 — 분홍 탄이 몸에 닿지 않는다.
			if block > 0.0 and b["p"].distance_to(pos) < block:
				fx.spark(b["p"], P.CYAN, 4)
				Snd.block()
				bullets.remove_at(i)
				continue
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
				if blast > 0.0:
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

## 장판이 피해를 다시 주는 간격. `dmg * TICK` 을 `TICK` 초마다 주므로 **초당 피해 = dmg** 다.
## 상시 전개 스킬의 수치를 읽을 때 이 관계를 기억할 것.
const AREA_TICK := 0.32


func _step_areas(dt: float) -> void:
	# **차단 스킬(강철 방벽 · 반사 결계)은 늘 켜져 있다.** 쿨다운으로 껐다 켜면 "막고 있다"는
	# 상태가 화면에서 사라져서, 분홍 탄이 지워지는 것이 스킬 덕인지 운인지 알 수 없게 된다.
	# 이미 떠 있으면 반경·피해만 갱신한다 — 레벨업이 곧바로 눈에 보여야 한다.
	for w: int in g.weapons.keys():
		var wk := String(D.WEAPON[w]["kind"])
		if wk != "guard" and wk != "ward":
			continue
		var rr := g.wstat(w, "radius", 180.0)
		var dd := g.wstat(w, "dmg", 20.0)
		var found := -1
		for ai in areas.size():
			if String(areas[ai]["kind"]) == wk:
				found = ai
				break
		if found < 0:
			areas.append({
				"p": pos, "r": rr, "dmg": dd, "life": 1e9, "max": 1e9,
				"kind": wk, "follow": true, "tick": 0.0, "dot": true,
			})
		else:
			areas[found]["r"] = rr
			areas[found]["dmg"] = dd

	for i in range(areas.size() - 1, -1, -1):
		var a: Dictionary = areas[i]
		a["life"] = float(a["life"]) - dt
		if bool(a["follow"]):
			a["p"] = pos
		# 지속 피해(`dot`)는 불장판과 상시 전개 장막뿐이다. 회전 참격·대지 분쇄는 터질 때
		# 한 번만 때리고 남는 그림이라 여기서 또 때리면 피해가 두 배가 된다.
		if bool(a.get("dot", false)):
			a["tick"] = float(a["tick"]) - dt
			if float(a["tick"]) <= 0.0:
				a["tick"] = AREA_TICK
				_area_damage(a["p"], float(a["r"]), float(a["dmg"]) * AREA_TICK, P.ORANGE)
		if float(a["life"]) <= 0.0:
			areas.remove_at(i)

# ==================== 경험치 젬 ====================

## 라운드가 끝나면 **강력한 자석이 켜진 것처럼** 필드의 젬을 전부 끌어온다.
## `main.gd` 가 `St.SWEEP` 동안 `sweep_step` 을 매 프레임 부르고, 다 들어오면 클리어 화면으로
## 넘어간다. 그동안 적은 멈추고 플레이어는 무적이다 — 클리어 직후의 보상 장면이라
## 여기서 맞아 죽으면 이상하다.
##
## 순간 흡수가 아니라 연출로 두는 이유: 라운드 보상 코인이 그 라운드에서 번 경험치에
## 비례하므로, 얼마나 쓸어 담았는지가 눈에 보여야 한다.
const SWEEP_MAX := 4.5

var sweeping := false
var swept_xp := 0
var _sweep_t := 0.0


func begin_sweep() -> void:
	sweeping = true
	swept_xp = 0
	_sweep_t = 0.0
	fx.ring(pos, P.XP, 340.0, 0.6)
	Snd.clear_()


## 한 프레임 진행. 다 끌어왔으면(또는 너무 오래 걸리면) true.
func sweep_step(dt: float) -> bool:
	_sweep_t += dt
	# 시간이 갈수록 세게 당긴다 — 멀리 있던 것도 결국 다 들어온다
	var pull := 420.0 + _sweep_t * 1100.0
	for i in range(gems.size() - 1, -1, -1):
		var gm: Dictionary = gems[i]
		var d: Vector2 = pos - gm["p"]
		var dl := d.length()
		if dl < 26.0:
			var got := int(gm["xp"])
			swept_xp += got
			g.gain_xp(got)
			fx.spark(gm["p"], D.ENEMY[int(gm.get("k", D.S_ZOMBIE))]["col"], 2)
			Snd.pick()
			gems.remove_at(i)
			continue
		gm["p"] = gm["p"] + d / maxf(dl, 0.001) * pull * dt
	return gems.is_empty() or _sweep_t >= SWEEP_MAX


## 자석이 못 따라잡은 나머지를 그 자리에서 흡수한다 (안전장치).
func absorb_gems() -> int:
	var got := 0
	for gm: Dictionary in gems:
		got += int(gm["xp"])
	gems.clear()
	sweeping = false
	if got > 0:
		g.gain_xp(got)
		Snd.pick()
	return got


func _step_gems(dt: float) -> void:
	var pr := g.pickup()

	# 상한을 넘은 만큼 가장 오래된 젬부터 흡수한다 (경험치는 그대로 준다).
	# 배열 앞쪽이 오래된 것이므로 한 번에 잘라 내고 경험치만 합산한다 —
	# 한 개씩 remove_at(0) 하면 남은 260칸을 그만큼 반복해서 앞으로 당긴다.
	var over := gems.size() - D.GEM_CAP
	if over > 0:
		var xp_sum := 0
		for i in over:
			xp_sum += int(gems[i]["xp"])
		gems = gems.slice(over)
		g.gain_xp(xp_sum)

	for i in range(gems.size() - 1, -1, -1):
		var gm: Dictionary = gems[i]
		gm["t"] = float(gm["t"]) + dt
		var d: Vector2 = pos - gm["p"]
		var dl := d.length()
		if dl < pr:
			# 끌려온다 — 가까울수록 빨라져서 확 빨려 들어가는 맛이 난다
			gm["p"] = gm["p"] + d.normalized() * (215.0 + (pr - dl) * 3.4) * dt
		else:
			# 수집 범위 밖이어도 **아주 느리게** 따라온다. 이게 0 이면 멀리서 죽인 적의 젬이
			# 맵에 그대로 남아 경험치가 안 들어온다. 반대로 세게 잡으면 화면 전체가 빨려
			# 들어오는 것처럼 보여서 수집 범위라는 개념 자체가 없어진다 — 수집은 어디까지나
			# pickup 반경 안에서 일어나야 하고, 이 값은 "언젠가는 닿는다" 정도면 된다.
			gm["p"] = gm["p"] + gm["v"] * dt + d.normalized() * clampf(11.0 + dl * 0.018, 11.0, 40.0) * dt
			gm["v"] = gm["v"] * exp(-dt * 3.4)
		if dl < 22.0:
			g.gain_xp(int(gm["xp"]))
			fx.spark(gm["p"], D.ENEMY[int(gm.get("k", D.S_ZOMBIE))]["col"], 2)
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
