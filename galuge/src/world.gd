class_name World
extends RefCounted

## 한 판의 상태와 규칙.
##
## 적·탄·이펙트는 노드를 만들지 않고 [Dictionary] 배열로 들고 [method draw] 한 곳에서 그린다.
## 수백 개를 노드로 만들면 생성·해제 비용만으로 프레임이 무너진다.

enum St { PLAY, DEAD, CLEAR, OVER, ALLCLEAR }

var st := St.PLAY
var t := 0.0
var scroll := 0.0
var w := D.PLAY_W
var h := 640.0

# ---------- 아군 ----------
var craft := 0
var pos := Vector2.ZERO
var lives := D.LIVES
var bombs := D.BOMBS
var power := 0
var invuln := 0.0
var respawn := 0.0
var fire_cd := 0.0
var wave_cd := 0.0
var focus := false

# ---------- 판 ----------
var round_i := 0
var diff := 0
var prog := 0.0          ## 라운드 진행도 0~1
var wave_i := 0
var power_i := 0     ## D.POWER_AT 에서 어디까지 지났나
var power_due := 0   ## 아직 안 떨어뜨린 P 개수
var mid_done := false
var boss_done := false
var score := 0
var next_extend := D.EXTEND_AT

# ---------- 배열 ----------
var pb: Array[Dictionary] = []      ## 아군 탄
var opts: Array[Dictionary] = []    ## 옵션기(편대). 슈팅스타만 쓴다.
var eb: Array[Dictionary] = []      ## 적 탄
var foes: Array[Dictionary] = []
var items: Array[Dictionary] = []
var booms: Array[Dictionary] = []
var boss: Dictionary = {}
var bomb: Dictionary = {}

var clear_t := 0.0
var shake := 0.0
## 무인 주행 전용. 가만히 서 있으면 죽어서 보스까지 못 가므로 soak 테스트에서만 켠다.
var god := false
var rng := RandomNumberGenerator.new()


func _init(craft_idx: int = 0, round_idx: int = 0, diff_idx: int = 0) -> void:
	rng.randomize()
	craft = craft_idx
	round_i = round_idx
	diff = clampi(diff_idx, 0, D.DIFF.size() - 1)
	pos = Vector2(w * 0.5, h - 110.0)


func setup(play_h: float) -> void:
	h = play_h
	pos = Vector2(w * 0.5, h - 110.0)


## soak 테스트용. 웨이브 표를 건너뛰고 진행도를 앞으로 감는다.
func skip_to(p: float) -> void:
	if p <= 0.0:
		return
	_wind_to(p)
	mid_done = prog >= D.MIDBOSS_AT


## 진행도를 앞으로 감고, 그 사이의 웨이브와 P 를 **지나간 것으로 친다.**
## 감기만 하고 표 색인을 안 밀면 다음 프레임에 밀린 웨이브가 한꺼번에 쏟아진다.
func _wind_to(p: float) -> void:
	prog = p
	var wv: Array = D.WAVE[round_i]
	while wave_i < wv.size() and wv[wave_i].at <= prog:
		wave_i += 1
	while power_i < D.POWER_AT.size() and D.POWER_AT[power_i] <= prog:
		power_i += 1


## **테스트 빌드 전용** — 라운드 보스 직전까지 감는다. soak 의 `--prog` 을 손으로 하는 것으로,
## 보스를 만질 때마다 40~50초를 기다리지 않으려고 둔다. 키는 `D.test_build()` 일 때만
## 걸리므로(`main.gd`) 배포판에는 이 통로가 아예 없다.
##
## **화면에 남은 잡졸과 적 탄을 치운다** — 안 치우면 보스가 무리 위로 내려앉고,
## 지나가지도 않은 웨이브의 탄에 맞아 죽는다.
##
## **파워는 만렙으로 둔다.** 진행도 0.92 면 P 아홉 개가 이미 다 나온 뒤라 제대로 논 판과
## 같은 상태이고, 보스의 설계 초(`secs`)도 만렙 화력 기준으로 잡혀 있다. 맨몸으로 두면
## 손으로 재는 초가 표와 안 맞아서 무엇이 기준인지 알 수 없게 된다.
func skip_to_boss() -> bool:
	if st != St.PLAY or boss_done or not boss.is_empty():
		return false
	_wind_to(D.BOSS_AT)
	mid_done = true       # 중간보스는 지나간 것으로 친다
	power_due = 0
	power = D.POWER_MAX
	foes.clear()
	eb.clear()
	items.clear()
	return true


## 다음 라운드로 넘어간다. **점수 · 잔기 · 봄 · 파워는 그대로 가져간다** —
## 라운드마다 맨몸으로 되돌리면 뒤로 갈수록 클리어가 아니라 벌이 된다.
func advance() -> bool:
	if round_i + 1 >= D.ROUND.size():
		return false
	round_i += 1
	prog = 0.0
	wave_i = 0
	power_i = 0
	power_due = 0
	mid_done = false
	boss_done = false
	clear_t = 0.0
	foes.clear()
	eb.clear()
	pb.clear()
	items.clear()
	booms.clear()
	boss = {}
	bomb = {}
	opts.clear()
	st = St.PLAY
	invuln = D.INVULN
	pos = Vector2(w * 0.5, h - 110.0)
	if god:
		print("[round] %s" % D.ROUND[round_i].name)
	return true


func dm() -> Dictionary:
	return D.DIFF[diff]


func land() -> String:
	return D.ROUND[round_i].land


func craft_col() -> Color:
	return P.craft(craft, 3)

# ==================== 진행 ====================

func step(dt: float, dir: Vector2, want_focus: bool, want_bomb: bool) -> void:
	t += dt
	scroll += D.SCROLL * dt
	shake = maxf(0.0, shake - dt * 3.0)
	focus = want_focus

	if st == St.PLAY or st == St.DEAD:
		_step_round(dt)
	elif st == St.CLEAR:
		clear_t += dt
	_step_player(dt, dir, want_bomb)
	_step_bomb(dt)
	_step_bullets(dt)
	_step_foes(dt)
	_step_boss(dt)
	_step_items(dt)
	_collide()
	_sweep()

	for b in booms:
		b.p += dt * 2.3
	booms = _keep(booms, func(b): return b.p < 1.0)


func _step_round(dt: float) -> void:
	var rd: Dictionary = D.ROUND[round_i]
	if boss.is_empty():
		prog = minf(1.0, prog + dt / rd.time)
	var wv: Array = D.WAVE[round_i]
	while wave_i < wv.size() and wv[wave_i].at <= prog:
		_spawn_wave(wv[wave_i])
		wave_i += 1
	while power_i < D.POWER_AT.size() and D.POWER_AT[power_i] <= prog:
		power_i += 1
		power_due += 1
	if not mid_done and prog >= D.MIDBOSS_AT and boss.is_empty():
		mid_done = true
		_spawn_boss("midboss", true)
	if not boss_done and prog >= D.BOSS_AT and boss.is_empty():
		boss_done = true
		_spawn_boss(rd.boss, false)
	if boss_done and boss.is_empty() and st == St.PLAY:
		st = St.CLEAR


# ==================== 아군 ====================


func _step_player(dt: float, dir: Vector2, want_bomb: bool) -> void:
	if st == St.OVER or st == St.CLEAR:
		return
	if st == St.DEAD:
		respawn -= dt
		if respawn <= 0.0:
			if lives <= 0:
				st = St.OVER
			else:
				st = St.PLAY
				pos = Vector2(w * 0.5, h - 90.0)
				invuln = D.INVULN
				power = maxi(0, power - 1)
				bombs = D.BOMBS
		return

	invuln = maxf(0.0, invuln - dt)
	var sp: float = D.CRAFT[craft].speed * (D.FOCUS_MUL if focus else 1.0)
	pos += dir * sp * dt
	pos.x = clampf(pos.x, 12.0, w - 12.0)
	pos.y = clampf(pos.y, 26.0, h - 22.0)
	_step_opts(dt)

	if want_bomb:
		fire_bomb()

	fire_cd -= dt
	if fire_cd <= 0.0:
		fire_cd = _shoot()
	# 파동은 본 사격과 **주기가 다르다.** 같이 쏘면 고리가 화면을 덮어
	# 적도 적 탄도 안 보인다 — 느리고 무거운 한 방이라야 파동이다.
	if craft == 5:
		wave_cd -= dt
		if wave_cd <= 0.0:
			wave_cd = _fire_waves()


## 기체마다 파워업이 자라는 **방향**이 다르다. 세기가 아니라 방향이 이 기체를 고르는 이유다.
func _shoot() -> float:
	match craft:
		0: return _sh_hayabusa()
		1: return _sh_lightning()
		2: return _sh_corsair()
		3: return _sh_spitfire()
		4: return _sh_shooting()
	return _sh_shinden()


## 관통 · 집중 — 가운데로 모이면서 굵어지고, 끝에는 적을 뚫는 빔이 된다.
func _sh_hayabusa() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	match power:
		0:
			_bul(Vector2(pos.x - 7.0, y), Vector2(0, -470), "shot", c)
			_bul(Vector2(pos.x + 7.0, y), Vector2(0, -470), "shot", c)
			return 0.105
		1:
			_beam(Vector2(pos.x, y - 6.0), 5.0, false, 2)
			_bul(Vector2(pos.x - 9.0, y), Vector2(0, -470), "shot", c)
			_bul(Vector2(pos.x + 9.0, y), Vector2(0, -470), "shot", c)
			return 0.1
		2:
			_beam(Vector2(pos.x, y - 6.0), 9.0, true, 3)
			_bul(Vector2(pos.x - 11.0, y), Vector2(34, -480), "shot", c)
			_bul(Vector2(pos.x + 11.0, y), Vector2(-34, -480), "shot", c)
			return 0.095
	_beam(Vector2(pos.x, y - 8.0), 15.0, true, 3)
	_bul(Vector2(pos.x - 13.0, y), Vector2(58, -490), "shot", c)
	_bul(Vector2(pos.x + 13.0, y), Vector2(-58, -490), "shot", c)
	_bul(Vector2(pos.x - 21.0, y + 6.0), Vector2(96, -470), "shot", c)
	_bul(Vector2(pos.x + 21.0, y + 6.0), Vector2(-96, -470), "shot", c)
	return 0.09


## 확산 — 옆으로 벌어진다. 만렙은 폭을 P2 그대로 둔 채 발수만 늘려 촘촘해진다.
## **폭을 먼저 정하고 발수로 나눈다.** 각도 간격을 레벨마다 키우면 만렙에서 그냥 벌어진다.
func _sh_lightning() -> float:
	var c := craft_col()
	var y := pos.y - 12.0
	if power == 0:
		_bul(Vector2(pos.x - 11.0, y), Vector2(0, -450), "shot", c)
		_bul(Vector2(pos.x + 11.0, y), Vector2(0, -450), "shot", c)
		return 0.12
	var n: int = [2, 4, 6, 10][power]
	var half: float = [0.0, 0.22, 0.72, 0.72][power]
	var sp: float = half * 2.0 / (n - 1)
	for i in n:
		_fan(Vector2(pos.x, y), (i - (n - 1) * 0.5) * sp, 440.0,
				"spread" if i % 2 != 0 else "shot", c)
	return 0.10


## 화력 · 관통 — 한 줄기가 계속 두꺼워진다. 연사는 느리지만 보스에 붙으면 제일 빠르다.
func _sh_corsair() -> float:
	var c := craft_col()
	var y := pos.y - 18.0
	var wd: float = [7.0, 11.0, 16.0, 23.0][power]
	var bdmg: int = [2, 3, 5, 5][power]
	_beam(Vector2(pos.x, y), wd, power >= 2, bdmg)
	if power >= 1:
		_fan(Vector2(pos.x - 14.0, pos.y - 4.0), -0.18, 400.0, "spread", c)
		_fan(Vector2(pos.x + 14.0, pos.y - 4.0), 0.18, 400.0, "spread", c)
	if power >= 3:
		_fan(Vector2(pos.x - 19.0, pos.y + 2.0), -0.42, 380.0, "spread", c)
		_fan(Vector2(pos.x + 19.0, pos.y + 2.0), 0.42, 380.0, "spread", c)
	var cd: float = [0.17, 0.155, 0.14, 0.125][power]
	return cd


## 유도 — 알아서 쫓아가는 탄이 는다. 겨냥을 안 해도 맞아서 피하는 데 집중할 수 있다.
func _sh_spitfire() -> float:
	var c := craft_col()
	var y := pos.y - 14.0
	_bul(Vector2(pos.x - 8.0, y), Vector2(0, -460), "shot", c)
	_bul(Vector2(pos.x + 8.0, y), Vector2(0, -460), "shot", c)
	if power >= 3:
		_bul(Vector2(pos.x - 16.0, y + 4.0), Vector2(0, -460), "shot", c)
		_bul(Vector2(pos.x + 16.0, y + 4.0), Vector2(0, -460), "shot", c)
	var n: int = [1, 2, 4, 6][power]
	for i in n:
		var a := (i - (n - 1) * 0.5) * 0.5 + (0.12 if i % 2 != 0 else -0.12)
		var b := _fan(Vector2(pos.x, pos.y - 4.0), a, 300.0, "homing", c)
		b.k = "h"
	return 0.135


## 편대 — 같이 쏘는 옵션기가 는다. 화면에 내 편이 늘어나는 유일한 기체.
func _sh_shooting() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	_bul(Vector2(pos.x - 6.0, y), Vector2(0, -480), "shot", c)
	_bul(Vector2(pos.x + 6.0, y), Vector2(0, -480), "shot", c)
	if power >= 3:
		_bul(Vector2(pos.x - 15.0, y + 5.0), Vector2(0, -470), "shot", c)
		_bul(Vector2(pos.x + 15.0, y + 5.0), Vector2(0, -470), "shot", c)
	for i in opts.size():
		var o: Dictionary = opts[i]
		var side := 1.0 if i % 2 != 0 else -1.0
		if power >= 3:
			_fan(o.pos + Vector2(0, -8), side * -0.16, 460.0, "spread", c)
		else:
			_bul(o.pos + Vector2(0, -8), Vector2(0, -460), "spread", c)
	return 0.098


## 파동 — 앞으로 나가며 커지는 고리. 멀리 있는 적일수록 넓게 훑는다.
func _sh_shinden() -> float:
	var c := craft_col()
	var y := pos.y - 16.0
	_bul(Vector2(pos.x - 7.0, y), Vector2(0, -470), "shot", c)
	_bul(Vector2(pos.x + 7.0, y), Vector2(0, -470), "shot", c)
	if power >= 2:
		_bul(Vector2(pos.x - 16.0, y + 5.0), Vector2(0, -450), "shot", c)
		_bul(Vector2(pos.x + 16.0, y + 5.0), Vector2(0, -450), "shot", c)
	var cd: float = [0.15, 0.14, 0.132, 0.125][power]
	return cd


## 파동 — 앞으로 나가며 커지는 고리. 멀리 있는 적일수록 넓게 훑는다.
func _fire_waves() -> float:
	var c := craft_col()
	var n: int = [1, 1, 2, 3][power]
	var w0: float = [16.0, 20.0, 24.0, 28.0][power]
	var gw: float = [46.0, 54.0, 62.0, 70.0][power]
	for i in n:
		var b := _bul(Vector2(pos.x + (i - (n - 1) * 0.5) * 34.0, pos.y - 12.0),
				Vector2(0, -290), "wave", c)
		b.k = "w"
		b.wd = w0
		b.grow = gw
		b.dmg = 2
		b.pierce = true
	var cd: float = [0.62, 0.58, 0.55, 0.5][power]
	return cd


func _bul(p: Vector2, v: Vector2, st_: String, col: Color) -> Dictionary:
	var b := {pos = p, vel = v, st = st_, col = col, wd = 0.0, grow = 0.0, pierce = false,
		k = "s", rehit = 0.0, dmg = 1, dead = false}
	pb.append(b)
	return b


func _fan(p: Vector2, ang: float, spd: float, st_: String, col: Color) -> Dictionary:
	return _bul(p, Vector2(sin(ang), -cos(ang)) * spd, st_, col)


func _beam(p: Vector2, wd: float, pierce: bool, dmg: int) -> void:
	var b := _bul(p, Vector2(0, -520), "beam", craft_col())
	b.wd = wd
	b.pierce = pierce
	b.dmg = dmg


## 옵션기(편대) 는 레벨이 오르면 대수가 는다.
const OPTPOS := [[], [Vector2(-24, 20)], [Vector2(-24, 20), Vector2(24, 20)],
	[Vector2(-26, 16), Vector2(26, 16), Vector2(-40, 40), Vector2(40, 40)]]


func _step_opts(dt: float) -> void:
	if craft != 4:
		opts.clear()
		return
	var want: Array = OPTPOS[power]
	while opts.size() < want.size():
		opts.append({pos = pos})
	while opts.size() > want.size():
		opts.pop_back()
	for i in want.size():
		var tgt: Vector2 = pos + want[i] + Vector2(sin(t * 2.0 + i) * 4.0, 0.0)
		opts[i].pos = opts[i].pos.lerp(tgt, minf(1.0, dt * 7.0))


func _nearest_foe(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := 1e18
	for f in foes:
		if f.dead:
			continue
		var d: float = from.distance_squared_to(f.pos)
		if d < bd:
			bd = d
			best = f.pos
	if not boss.is_empty() and boss.y_in and bd > 90000.0:
		return boss.pos
	return best


func fire_bomb() -> void:
	if not bomb.is_empty() or bombs <= 0 or st != St.PLAY:
		return
	bombs -= 1
	bomb = {p = 0.0, dur = D.CRAFT[craft].bomb_dur, org = pos}
	shake = 1.0


func _step_bomb(dt: float) -> void:
	if bomb.is_empty():
		return
	bomb.p += dt / bomb.dur
	# **봄은 화면을 실제로 지운다.** 조금씩 갉는 정도면 위급할 때 눌러도 못 살아남아서
	# 있으나 마나가 된다. 잡졸은 한 번에 쓸고, 보스에게도 한 입 분량이 들어간다.
	if bomb.p < D.BOMB_CLEAR:
		eb.clear()
		for f in foes:
			if not f.dead:
				_hurt(f, D.BOMB_DPS * dt)
		if not boss.is_empty() and boss.y_in and not boss.morphing:
			boss.hp -= D.BOMB_BOSS_DPS * dt
	if bomb.p >= 1.0:
		bomb = {}

# ==================== 적 ====================

func _spawn_wave(spec: Dictionary) -> void:
	var n: int = spec.n
	var gap: float = spec.gap
	var kind: String = spec.k
	match spec.kind:
		"line":
			for i in n:
				var off: float = (i - (n - 1) * 0.5) * gap
				_add_foe(kind, Vector2(w * 0.5 + off, -30.0 - absf(off) * 0.5), i * 0.7)
		"pair":
			for i in n:
				var x: float = w * (i + 1.0) / (n + 1.0)
				_add_foe(kind, Vector2(x, -70.0 - i * gap * 0.3), i)
		"dive":
			for i in n:
				var x: float = 44.0 + i * (w - 88.0) / maxf(1.0, n - 1.0)
				_add_foe(kind, Vector2(x, -40.0 - i * 40.0), i)
		"arc":
			# 옆에서 들어와 화면을 **가로로 가로지른다.** 다른 적은 전부 위에서 내려오므로
			# 이것만 세로 회피로는 안 풀린다.
			for i in n:
				var side := 1.0 if i % 2 == 0 else -1.0
				var f := _add_foe(kind, Vector2(w * 0.5 - side * (w * 0.5 + 34.0),
						54.0 + i * gap * 0.42), i * 0.7)
				f.dirx = side
		"spot":
			# 지형에 붙어 흘러오는 것들 — 자리를 흩어 놓아야 한 줄로 안 보인다
			for i in n:
				var x: float = clampf(w * (i + 1.0) / (n + 1.0)
							+ rng.randf_range(-0.22, 0.22) * gap, 26.0, w - 26.0)
				_add_foe(kind, Vector2(x, -46.0 - i * gap * 0.55), i)


func _add_foe(kind: String, p: Vector2, ph: float) -> Dictionary:
	var e: Dictionary = D.ENEMY[kind]
	var tier: float = D.ROUND[round_i].tier
	var hold: float = h * 0.26 + fposmod(ph, 3.0) * 20.0
	var f := {kind = kind, art = e.art, pos = p, hp = e.hp * dm().hp * tier,
		r = e.r, ph = ph, sz = e.sz, move = e.move, aim = PI * 0.5, dirx = 0.0, hold = hold,
		cd = e.fire * (0.6 + ph * 0.25), spd = e.speed, dead = false}
	foes.append(f)
	return f


func _step_foes(dt: float) -> void:
	for f in foes:
		if f.dead:
			continue
		# **나는 방식은 종류 번호가 아니라 move 로 가른다.**
		match f.move:
			"wave":
				f.pos.y += f.spd * dt
				f.pos.x += sin(t * 1.7 + f.ph) * 52.0 * dt
			"swoop":
				f.pos.y += f.spd * dt
				f.pos.x += sin(t * 3.0 + f.ph) * 30.0 * dt
			"ground":
				# 지형과 같은 속도로 흘러간다. 스스로 못 움직이는 대신 **포신이 겨눈다.**
				f.pos.y += D.SCROLL * dt
				f.aim = (pos - f.pos).angle()
			"arc":
				f.pos.x += f.dirx * f.spd * dt
				f.pos.y += (f.spd * 0.26 + sin(t * 1.4 + f.ph) * 42.0) * dt
			"hover":
				# 내려와 자리를 잡고 버틴다 — 지나가 주지 않으니 쳐내야 한다
				if f.pos.y < f.hold:
					f.pos.y += f.spd * dt
				else:
					f.pos.x += sin(t * 0.8 + f.ph) * 64.0 * dt
			_:
				f.pos.y += f.spd * dt
		var reach: float = 0.82 if f.move == "ground" else 0.62
		if f.cd > 0.0 and bomb.is_empty():
			f.cd -= dt
			if f.cd <= 0.0 and f.pos.y > 10.0 and f.pos.y < h * reach:
				f.cd = D.ENEMY[f.kind].fire
				if f.art == "gunship":
					# 고리 탄 — 붙어 있으면 빠져나갈 곳이 없다
					_ring_shot(f.pos, 8, t * 0.6 + f.ph, 96.0, f.sz)
				else:
					var n := 3 if f.art == "bomber" else 1
					_aim_shot(f.pos, n, 0.28, f.sz)
		if f.pos.y > h + 60.0 or (f.move == "arc" and (f.pos.x < -70.0 or f.pos.x > w + 70.0)):
			f.dead = true


func _eb(from: Vector2, ang: float, spd: float, sz: int) -> void:
	var k: float = D.EB[sz].spd * dm().spd
	eb.append({pos = from, vel = Vector2(cos(ang), sin(ang)) * spd * k, sz = sz})


func _aim_shot(from: Vector2, n: int, spread: float, sz: int = 1) -> void:
	var cnt := maxi(1, int(round(n * dm().dense)))
	var a := (pos - from).angle()
	for i in cnt:
		_eb(from, a + (i - (cnt - 1) * 0.5) * spread, D.E_BULLET_SPD, sz)


func _ring_shot(from: Vector2, n: int, rot: float, spd: float, sz: int = 1) -> void:
	var cnt := maxi(3, int(round(n * dm().dense)))
	for i in cnt:
		_eb(from, i * TAU / cnt + rot, spd, sz)

# ==================== 보스 ====================

func _spawn_boss(key: String, mid: bool) -> void:
	var sc := 1.0
	var r: Vector2 = D.MIDBOSS.r
	var hp: float = D.MIDBOSS.hp
	var nm := "초중폭격기"
	if not mid:
		var b: Dictionary = D.BOSS[key]
		sc = b.scale
		r = b.r * sc
		hp = b.hp
		nm = b.name
	hp *= dm().hp
	boss = {key = key, mid = mid, scale = sc, r = r, name = nm,
		pos = Vector2(w * 0.5, -r.y * 1.3), hp = hp, max = hp,
		hover = 30.0 + r.y, cd = 1.4, sw = 0, y_in = false, rage = false, born = t,
		t0 = t, shown = hp, morph = 0.0, morphing = false, pdead = 0}


## 보스마다 다른 탄막. **얼굴만 바꾸면 다 같은 보스다** — 피하는 방법이 달라야 한다.
## 보스마다 다르게 움직인다. **여섯이 같은 궤적으로 흔들리면 얼굴만 바꾼 것과 같다.**
## 돌아온 값은 화면 한가운데(hover) 기준 오프셋이다.
## 부위 하나의 자리. **그리기와 판정이 같은 함수를 본다** — 도는 방출구처럼 자리가
## 시간에 따라 바뀌는 것은 여기서 한 번만 계산하고 [Art] 에도 같은 규칙을 적어 둔다.
func _part_pos(i: int) -> Vector2:
	var b: Dictionary = D.BOSS[boss.key]
	if boss.key == "disc":
		var a: float = (t - boss.t0) * 0.55 + i * TAU / 6.0
		return boss.pos + Vector2(sin(a), -cos(a)) * boss.r.x * 0.85
	var off: Vector2 = b.parts[i]
	return boss.pos + off * boss.scale


## 체력이 깎이면 부위가 하나씩 떨어져 나간다. **부순 만큼 탄막이 실제로 줄어든다** —
## 그림만 사라지면 부순 보람이 없고, 어디부터 칠지를 고를 이유도 없어진다.
func _step_parts() -> void:
	var pn: int = D.BOSS[boss.key].parts.size()
	var frac: float = boss.hp / boss.max
	var want := 0
	for i in pn:
		if frac <= 1.0 - float(i + 1) / (pn + 1):
			want = i + 1
	while boss.pdead < want:
		var pp := _part_pos(boss.pdead)
		for k in 6:
			booms.append({pos = pp + Vector2(rng.randf_range(-16.0, 16.0),
				rng.randf_range(-16.0, 16.0)), p = -rng.randf() * 0.35,
				s = 22.0 + rng.randf() * 16.0})
		boss.pdead += 1
		shake = maxf(shake, 0.7)
		_award(D.PART_SCORE)


func _boss_move(age: float, span: float) -> Vector2:
	if boss.mid:
		return Vector2(sin(age * 0.5) * span, 0)
	match boss.key:
		"battleship":
			return Vector2(sin(age * 0.5) * span, 0)
		"landfort":
			# 무거운 놈이라 양끝에서 **머문다** — 밀고 들어갈 틈이 생긴다
			# 궤도를 부순 만큼 못 움직이고, 둘 다 부수면 아예 선다
			var k: float = (2.0 - boss.pdead) * 0.5
			return Vector2(clampf(sin(age * 0.5) * 1.9, -1.0, 1.0) * span * k, 0)
		"carrier":
			return Vector2(sin(age * 0.32) * span, sin(age * 0.8) * 11.0)
		"disc":
			# 원을 그리며 돈다 — 좌우만 보고 있으면 위아래로 파고든다
			return Vector2(sin(age * 0.7) * span, cos(age * 0.7) * 30.0)
		"robot":
			if boss.morph < 0.5:
				return Vector2(sin(age * 1.05) * span, sin(age * 2.1) * 14.0)
			return Vector2(sin(age * 0.38) * span * 0.8, 0)
		_:
			# 최종 요새는 거의 안 움직인다. 피할 곳은 좌우 끝뿐.
			return Vector2(sin(age * 0.22) * span * 0.42, sin(age * 0.6) * 8.0)


func _boss_fire(add: int) -> void:
	var live: int = 0 if boss.mid else D.BOSS[boss.key].parts.size() - boss.pdead
	var muzzle: Vector2 = boss.pos + Vector2(0, boss.r.y * 0.5)
	var wide: Vector2 = boss.pos + Vector2(boss.r.x * 0.7 * signf(sin(boss.sw * 1.7)), 0)
	if boss.mid:
		match boss.sw % 3:
			0: _ring_shot(muzzle, 12 + add * 2, boss.sw * 0.2, 118.0)
			1: _aim_shot(muzzle, 5 + add, 0.16)
			_: _aim_shot(wide, 3 + add, 0.13)
		return
	match boss.key:
		"battleship":
			# 주포 셋이 번갈아 — 넓게 조준하고, 셋째 발은 고리로 도망갈 곳을 지운다.
			match boss.sw % 3:
				0: _ring_shot(muzzle, 16 + add * 2, boss.sw * 0.2, 118.0)
				1: _aim_shot(muzzle, maxi(1, (7 + add) * live / 3), 0.16)
				_:
					_aim_shot(wide, maxi(1, (5 + add) * live / 3), 0.13)
					if boss.rage:
							_ring_shot(boss.pos, 10, -boss.sw * 0.3, 92.0)
		"landfort":
			# 무거운 놈이라 느리게, 대신 **벽처럼** 온다. 틈으로 빠져나가는 싸움.
			if boss.sw % 3 == 0:
				var gap := rng.randi_range(1, 7)
				for i in 9:
					if absi(i - gap) <= (0 if boss.rage else 1):
							continue
					_eb(Vector2(w * (i + 0.5) / 9.0, boss.pos.y), PI * 0.5, 132.0, 2)
			else:
				_aim_shot(muzzle, 5 + add, 0.2)
				_aim_shot(boss.pos + Vector2(-boss.r.x * 0.6, 20), 3, 0.26)
				_aim_shot(boss.pos + Vector2(boss.r.x * 0.6, 20), 3, 0.26)
		"carrier":
			# 발진구에서 잡졸기가 계속 나온다. 본체만 때리면 끝이 안 난다.
			if boss.sw % 2 == 0:
				for i in mini(live, 3 if boss.rage else 2):
					var bx: float = boss.pos.x + (i - 1) * 58.0
					_add_foe("grunt", Vector2(clampf(bx, 20.0, w - 20.0), boss.pos.y + 30.0), i)
			else:
				_aim_shot(muzzle, 5 + add, 0.15)
				_ring_shot(boss.pos, 8 + add, boss.sw * 0.4, 88.0)
		"disc":
			# 방출구 여섯이 고리를 따라 돈다 — **안전한 자리가 계속 옮겨 간다.**
			var spin: float = (t - boss.t0) * 0.55
			for i in range(boss.pdead, 6):
				var a: float = spin + i * TAU / 6.0
				var em: Vector2 = boss.pos + Vector2(sin(a), -cos(a)) * boss.r.x * 0.85
				var dir: Vector2 = (em - boss.pos).normalized()
				for k in (3 if boss.rage else 2):
					var aa: float = dir.angle() + (k - 0.5) * 0.16
					_eb(em, aa, 124.0, 0)
			if boss.sw % 3 == 0:
				_aim_shot(boss.pos, 5 + add, 0.14)
		"robot":
			if boss.morph < 0.5:
				# 비행 형태 — 앞으로 몰아친다
				_aim_shot(muzzle, 7 + add, 0.13)
				if boss.sw % 3 == 0:
					_ring_shot(boss.pos, 14 + add, boss.sw * 0.25, 104.0)
			else:
				# 로봇 형태 — **양팔이 좌우로 훑는다.** 가운데가 아니라 옆이 위험하다.
				for ai in range(boss.pdead, 2):
					var s := -1.0 if ai == 0 else 1.0
					var hand: Vector2 = boss.pos + Vector2(s * boss.r.x * 0.75, boss.r.y * 0.45)
					var base: float = PI * 0.5 + s * sin(t * 1.6) * 0.5
					for k in 4 + add:
							var aa: float = base + (k - (3 + add) * 0.5) * 0.17
							_eb(hand, aa, 146.0, 0)
				if boss.sw % 4 == 0:
					_aim_shot(muzzle, 5 + add, 0.18)
		_:
			# 최종 요새 — 포탑 다섯이 동시에. 피할 곳이 좌우 끝밖에 없다.
			match boss.sw % 3:
				0:
					_ring_shot(boss.pos, 20 + add * 2, boss.sw * 0.18, 108.0)
					_ring_shot(boss.pos, 14 + add, -boss.sw * 0.24, 76.0)
				1:
					for q in [-0.62, -0.3, 0.0, 0.3, 0.62].slice(0, maxi(1, live + 1)):
							_aim_shot(boss.pos + Vector2(q * boss.r.x * 1.5, boss.r.y * 0.4), 2 + add, 0.2)
				_:
					_aim_shot(muzzle, 9 + add, 0.11)
					if boss.rage:
							_ring_shot(muzzle, 12, boss.sw * 0.5, 132.0)


func _step_boss(dt: float) -> void:
	if boss.is_empty():
		return
	if boss.pos.y < boss.hover:
		boss.pos.y += 46.0 * dt
	else:
		if not boss.y_in:
			boss.y_in = true
			boss.t0 = t
		# **좌우 흔들림은 들어온 시점부터 센다.** 전역 시간을 그대로 sin 에 넣으면
		# 보스가 내려앉는 순간 사인값이 아무 데나 있어서 옆으로 순간이동한다.
		# 폭도 1.6초에 걸쳐 벌려야 자리를 잡고 흔들리기 시작하는 것으로 읽힌다.
		var age: float = t - boss.t0
		var span := maxf(0.0, w * 0.5 - boss.r.x - 10.0)
		boss.pos = Vector2(w * 0.5, boss.hover) + _boss_move(age, span) * minf(1.0, age / 1.6)
		if bomb.is_empty():
			boss.cd -= dt
	# 체력 막대가 **한 칸씩 깎이는 게 보이게** 뒤따라오는 잔상 값.
	boss.shown = maxf(boss.hp, boss.shown - maxf(boss.max * 0.12,
			(boss.shown - boss.hp) * 2.6) * dt)
	# **끝까지 같은 속도로 때리면 지루하다.** 절반을 깎으면 2페이즈로 넘어가
	# 발사 간격이 줄고 탄이 는다 — 마지막 구간이 제일 위험해야 한다.
	boss.rage = boss.hp <= boss.max * 0.5
	if not boss.mid:
		_step_parts()
		match boss.key:
			"robot":
				# 절반에서 인간형으로 펴진다. **변신 중에는 무적이고 공격도 안 한다** —
				# 그 몇 초가 회피 자세를 다시 잡는 시간이다.
				boss.morph = move_toward(boss.morph, 1.0 if boss.rage else 0.0, dt * 0.5)
				boss.morphing = boss.morph > 0.02 and boss.morph < 0.98
			"fortress":
				# 깎일수록 가운데 차폐가 열린다
				boss.morph = clampf((1.0 - boss.hp / boss.max) / 0.6, 0.0, 1.0)
	if boss.morphing:
		return
	if boss.cd <= 0.0:
		var base: float = 0.85 if boss.mid else 0.95
		boss.cd = D.BOSS_RAGE_CD if boss.rage else base
		boss.sw += 1
		var add: int = D.BOSS_RAGE_ADD if boss.rage else 0
		_boss_fire(add)
	if boss.hp <= 0.0:
		for i in 18:
			booms.append({pos = boss.pos + Vector2(rng.randf_range(-1.0, 1.0) * boss.r.x * 1.6,
				rng.randf_range(-1.0, 1.0) * boss.r.y * 1.2),
				p = -rng.randf() * 0.5, s = 30.0 + rng.randf() * 26.0})
		if god:
			# soak 테스트용 실측. "보스 체력은 초로 정한다" 가 지켜지는지 여기서 확인한다.
			print("[boss] %s  %.1f초  (설계 %.0f초)" % [boss.name, t - boss.born,
					D.MIDBOSS.secs if boss.mid else D.BOSS[boss.key].secs])
		items.append({pos = boss.pos, kind = "power"})
		_award(D.MIDBOSS.score if boss.mid else D.BOSS[boss.key].score)
		shake = 1.0
		boss = {}

# ==================== 탄 · 아이템 ====================

func _step_bullets(dt: float) -> void:
	for b in pb:
		if b.rehit > 0.0:
			b.rehit -= dt
		if b.k == "w":
			# 상한이 없으면 고리가 화면을 덮어 절대 안 빗나간다.
			b.wd = minf(b.wd + b.grow * dt, 92.0)
		elif b.k == "h":
			var tg := _nearest_foe(b.pos)
			if tg.x < 1e17:
				var cur: float = b.vel.angle()
				cur += clampf(wrapf((tg - b.pos).angle() - cur, -PI, PI), -3.6 * dt, 3.6 * dt)
				b.vel = Vector2(cos(cur), sin(cur)) * 350.0
		b.pos += b.vel * dt
	pb = _keep(pb, func(b): return not b.dead and b.pos.y > -30.0 and b.pos.x > -50.0 and b.pos.x < w + 50.0)
	for b in eb:
		b.pos += b.vel * dt
	eb = _keep(eb, func(b): return b.pos.y < h + 24.0 and b.pos.y > -60.0 and b.pos.x > -40.0 and b.pos.x < w + 40.0)
	if eb.size() > 260:
		eb = _tail(eb, 260)


func _step_items(dt: float) -> void:
	for it in items:
		var d: Vector2 = pos - it.pos
		if d.length() < D.ITEM_MAGNET and st == St.PLAY:
			it.pos += d.normalized() * 190.0 * dt
		else:
			it.pos.y += D.ITEM_FALL * dt
	var keep: Array[Dictionary] = []
	for it in items:
		if st == St.PLAY and pos.distance_to(it.pos) < 15.0:
			if it.kind == "bomb":
				if bombs >= D.BOMBS_MAX:
					_award(D.BOMB_FULL_SCORE)
				else:
					bombs += 1
					_award(800)
			elif power >= D.POWER_MAX:
				_award(D.POWER_FULL_SCORE)
			else:
				power += 1
				_award(500)
			continue
		if it.pos.y < h + 30.0:
			keep.append(it)
	items = keep

# ==================== 판정 ====================

func _collide() -> void:
	for b in pb:
		if b.dead:
			continue
		if b.pierce and b.rehit > 0.0:
			continue
		var br := 5.0
		if b.st == "beam":
			br = 6.0 + b.wd * 0.5
		elif b.st == "wave":
			br = b.wd * 0.5
		for f in foes:
			if f.dead:
				continue
			if absf(b.pos.x - f.pos.x) < f.r + br and absf(b.pos.y - f.pos.y) < f.r + br:
				if b.pierce:
					b.rehit = D.REHIT
				else:
					b.dead = true
				booms.append({pos = b.pos, p = 0.0, s = 9.0})
				_hurt(f, b.dmg)
				break
		if b.dead or boss.is_empty() or not boss.y_in:
			continue
		if boss.morphing:
			continue
		if absf(b.pos.x - boss.pos.x) < boss.r.x + br and absf(b.pos.y - boss.pos.y) < boss.r.y + br:
			if b.pierce:
				b.rehit = D.REHIT
			else:
				b.dead = true
			boss.hp -= b.dmg
			booms.append({pos = b.pos, p = 0.0, s = 10.0})
			_award(40)

	if st != St.PLAY or invuln > 0.0:
		return
	var hit: float = D.CRAFT[craft].hit
	for b in eb:
		if b.pos.distance_to(pos) < hit + D.EB[b.sz].r:
			_die()
			return
	for f in foes:
		if not f.dead and f.pos.distance_to(pos) < hit + f.r * 0.62:
			_die()
			return
	if not boss.is_empty() and boss.y_in:
		if absf(pos.x - boss.pos.x) < boss.r.x * 0.8 and absf(pos.y - boss.pos.y) < boss.r.y * 0.8:
			_die()


func _hurt(f: Dictionary, dmg: float) -> void:
	f.hp -= dmg
	if f.hp > 0:
		return
	f.dead = true
	booms.append({pos = f.pos, p = 0.0, s = 34.0 if f.art == "bomber" else 20.0})
	_award(D.ENEMY[f.kind].score)
	# **한 마리는 많아야 아이템 하나를 떨군다.** 종류마다 따로 뽑으면 드물게 둘이 겹쳐서
	# 화면에서 무엇을 주웠는지 읽을 수가 없다.
	# **한 마리는 많아야 아이템 하나를 떨군다.** 종류마다 따로 뽑으면 드물게 둘이 겹쳐서
	# 화면에서 무엇을 주웠는지 읽을 수가 없다. P 가 먼저고, 없을 때만 봄을 굴린다.
	if power_due > 0:
		power_due -= 1
		items.append({pos = f.pos, kind = "power"})
	elif rng.randf() < D.BOMB_CHANCE:
		items.append({pos = f.pos, kind = "bomb"})


func _die() -> void:
	if god:
		invuln = 1.0
		return
	st = St.DEAD
	respawn = 1.4
	lives -= 1
	shake = 1.0
	for i in 10:
		booms.append({pos = pos + Vector2(rng.randf_range(-18.0, 18.0),
			rng.randf_range(-18.0, 18.0)), p = -rng.randf() * 0.3, s = 26.0})
	eb.clear()
	bomb = {}


func _award(n: int) -> void:
	score += n
	if score >= next_extend:
		next_extend += D.EXTEND_AT
		lives += 1


## 조건에 맞는 것만 남긴다. Array.filter 는 타입 없는 Array 를 돌려주므로
## Array[Dictionary] 에 그대로 담을 수 없다.
func _keep(src: Array[Dictionary], ok: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in src:
		if ok.call(it):
			out.append(it)
	return out


func _tail(src: Array[Dictionary], n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(maxi(0, src.size() - n), src.size()):
		out.append(src[i])
	return out


func _sweep() -> void:
	foes = _keep(foes, func(f): return not f.dead)

# ==================== 그리기 ====================

func draw(ci: CanvasItem) -> void:
	Art.terrain(ci, land(), w, h, scroll, t)
	for it in items:
		if it.kind == "bomb":
			Art.item_bomb(ci, it.pos, t)
		else:
			Art.item_power(ci, it.pos, t)
	for f in foes:
		if f.dead:
			continue
		if f.move == "ground":
			Art.ground_unit(ci, f.art, f.pos, f.aim, t, D.ROUND[round_i].base)
		else:
			Art.enemy(ci, f.art, f.pos, t + f.ph)
	if not boss.is_empty():
		Art.draw_shape(ci, boss.key, boss.pos, t, boss.scale, boss.morph, boss.pdead)
	if st == St.PLAY or st == St.CLEAR:
		# 무적 동안은 깜빡인다. 0 까지 내리면 사라진 것처럼 보이니 반만 지운다.
		var vis := invuln <= 0.0 or fmod(invuln * 12.0, 1.0) > 0.4
		if vis:
			G2.glow(ci, pos + Vector2(0, 20), 16.0, craft_col(),
					0.3 + 0.12 * sin(t * 22.0))
			Art.craft(ci, craft, pos, t)
			for o in opts:
				Art.craft(ci, craft, o.pos, t, 0.56)
		# 판정점. 그림보다 훨씬 작은 실제 피격 범위 — 없으면 억울하게 죽는다.
		var hit: float = D.CRAFT[craft].hit
		if focus:
			G2.glow(ci, pos, 14.0, Color(1, 1, 1), 0.5)
			ci.draw_arc(pos, hit + 3.0, 0.0, TAU, 16, P.a(P.WHITE, 0.7), 1.2, true)
		ci.draw_circle(pos, hit * 0.7, Color(1, 1, 1))
	for b in pb:
		Art.bullet_ally(ci, b)
	for b in eb:
		Art.bullet_foe(ci, b.pos, t, b.sz, b.vel)
	for b in booms:
		if b.p >= 0.0:
			Art.boom(ci, b.pos, b.p, b.s)
	if not bomb.is_empty():
		Art.bomb(ci, craft, bomb.p, bomb.org, w, h)
