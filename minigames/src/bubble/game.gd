class_name BbGame
extends RefCounted

## 물거품처럼 사라져줘 — 규칙만(그리기 · 입력 장치를 모른다). 좌표는 판의 왼쪽 위가 (0, 0), 아래가 +y(px).
## 인어 · 악당의 y 는 **발밑**. 거품 · 물건의 y 는 가운데.
## 화면은 `events` 를 받아 소리 · 입자 · 글로 바꾼다. 입력은 `inp[i]` 에 매 프레임 넣는다({left, right, jump, jump_held, shot}).

var lv := 0
var grid: Array = []
var rng := RandomNumberGenerator.new()
var players: Array = []      ## {x, y, vy, dir, ground, lives, score, inv, dead_t, cd, letters, power, power_t, active, out, shot_anim, hurt}
var enemies: Array = []      ## {k, x, y, vy, dir, ground, angry, cd, spike_t, jump_cd}
var dying: Array = []        ## 사라지는 악당(그리기만) {k, x, y, vx, vy, t}
var bubbles: Array = []      ## {x, y, vx, state("shot" · "float"), t, owner, trap(-1 · 악당 종류), trap_t, angry, big, rainbow, word(-1 · 글자)}
var items: Array = []        ## {x, y, vy, kind("item" · "power"), v, t, ground}
var inks: Array = []         ## 먹물 {x, y, vx}
var boss := {}               ## {x, y(가운데), vx, vy, hp, max, cd, trapped, t}
var shark := {}              ## {x, y(가운데)}
var inp: Array = [{}, {}]
var events: Array = []
var time := 0.0              ## 이 판에서 지난 시간
var state := "play"          ## play · clear · next · over · win
var state_t := 0.0
var hurry := false
var word_t := 0.0
var two := false
var god := false             ## 확인용 — 죽지 않는다
var continues := BbD.CONTINUES
var next_lv := 1             ## 판을 깨면 갈 판(건너뛰기 조개 · 비밀 방이 바꾼다)
var cur := Vector2.ZERO      ## 이 판에서 거품이 모이는 자리(판마다 다른 물살)
var sp_t := 0.0              ## 특수 거품이 떠오르기까지
var bolts: Array = []        ## 번개 {x, y, vx, owner, hit_boss}
var waters: Array = []       ## 물살 머리 {x, y(발밑), vy, dir, t, owner, flips, trail, hit_boss}
var door := {}               ## 비밀 방 문 {x, y(발밑)}
var deaths_block := 0        ## 이 10 판 묶음에서 죽은 수 — 0 이면 묶음 5 번째 판에 문이 열린다
var secret := false          ## 비밀 방 안
var bshots: Array = []       ## 보스 탄환 {x, y, vx, vy, k(0 먹물 · 1 빛 구슬 · 2 물 고리 · 3 바위 · 4 진주 불덩이), t}
var dark := 0.0              ## 아귀의 불 끄기 — 남은 시간(판이 어두워진다)


func _init(start_lv: int = 0, two_players: bool = false, seed_: int = -1) -> void:
	rng.seed = seed_ if seed_ >= 0 else randi()
	two = two_players
	for i in (2 if two else 1):
		players.append({x = 0.0, y = 0.0, vy = 0.0, dir = 1 if i == 0 else -1, ground = false, lives = BbD.LIVES, score = 0, inv = 0.0,
				dead_t = 0.0, cd = 0.0, letters = 0, power = -1, power_t = 0.0, active = true, out = false, shot_anim = 0.0, hurt = 0.0, blind = 0.0})
	_load(start_lv)


# ==================== 칸 ====================


func solid(c: int, r: int) -> bool:
	if c < 0 or c >= BbD.COLS:
		return true
	if r < 0 or r >= BbD.ROWS:
		return false
	return String(grid[r])[c] == "#"


func _cell(x: float) -> int:
	return int(floor(x / BbD.T))


## 발밑(x 를 가운데로 폭 w)이 r 줄 발판 위에 닿나.
func _floor_under(x: float, w: float, r: int) -> bool:
	for c in range(_cell(x - w * 0.5 + 2.0), _cell(x + w * 0.5 - 2.0) + 1):
		if solid(c, r):
			return true
	return false


## 몸(발밑 x, y · 폭 w)을 떨어뜨린다 — 위로는 발판을 뚫고, 내려오면 발판 위에 선다. 양옆 벽은 막는다. 밑 구멍으로 빠지면 위에서 나온다.
## 돌려주는 값: 땅에 섰나.
func _move_body(b: Dictionary, w: float, h: float, vx: float, dt: float, foot: float = -1.0) -> bool:
	var fw := foot if foot > 0.0 else w   # 발판에 서는 폭(사람 · 악당은 발밑만 — 1 칸 틈에도 빠진다)
	var x0 := float(b.x)
	var nx := clampf(x0 + vx * dt, 2.0 * BbD.T + w * 0.5, (BbD.COLS - 2) * BbD.T - w * 0.5)
	if nx != x0 and float(b.vy) >= 0.0:   # 걷거나 떨어질 땐 벽에 막히고, 뛰어오를 때만 지나간다(원작 규칙 — 사용자 11-11)
		nx = _wall_clip(x0, nx, float(b.y), w, h)
	b.x = nx
	var prev := float(b.y)
	b.vy = minf(float(b.vy) + BbD.GRAVITY * dt, BbD.FALL_MAX if float(b.vy) > 0.0 else 99999.0)
	b.y = prev + float(b.vy) * dt
	var landed := false
	if float(b.vy) >= 0.0:
		var r0 := int(floor(prev / BbD.T + 0.001))
		var r1 := int(floor(float(b.y) / BbD.T))
		for r in range(r0, r1 + 1):
			if r >= 0 and r < BbD.ROWS and r * BbD.T >= prev - 0.01 and r * BbD.T <= float(b.y) and _floor_under(float(b.x), fw, r):
				b.y = r * BbD.T
				b.vy = 0.0
				landed = true
				break
	else:   # 머리가 천장(맨 윗줄)에 닿으면 멈춘다 — 구멍 자리만 빼고
		var head := float(b.y) - h
		if head < BbD.T and _floor_under(float(b.x), w, 0) and prev - h >= BbD.T - 0.01:
			b.y = BbD.T + h
			b.vy = 0.0
	if float(b.y) > BbD.FIELD.y + h:   # 바닥 구멍으로 빠졌다 — 위에서 다시
		b.y -= BbD.FIELD.y + h
	return landed


## 옆으로 x0 → nx 갈 때 몸(발밑 y, 폭 w, 키 h)이 새로 들어가는 열에 벽이 있으면 그 앞에서 멈춘다.
## 이미 벽 속에 있으면(뛰어올라 발판을 지나는 중이던 몸) 막지 않는다 — 빠져나올 수 있게.
func _wall_clip(x0: float, nx: float, y: float, w: float, h: float) -> float:
	var r0 := int(floor((y - h + 2.0) / BbD.T))
	var r1 := int(floor((y - 2.0) / BbD.T))
	for c in range(_cell(x0 - w * 0.5 + 0.5), _cell(x0 + w * 0.5 - 0.5) + 1):
		for r in range(r0, r1 + 1):
			if solid(c, r):
				return nx
	if nx > x0:
		var c_old := _cell(x0 + w * 0.5 - 0.5)
		for c in range(c_old + 1, _cell(nx + w * 0.5 - 0.5) + 1):
			for r in range(r0, r1 + 1):
				if solid(c, r):
					return minf(nx, c * BbD.T - w * 0.5)
	else:
		var c_old2 := _cell(x0 - w * 0.5 + 0.5)
		for c in range(c_old2 - 1, _cell(nx - w * 0.5 + 0.5) - 1, -1):
			for r in range(r0, r1 + 1):
				if solid(c, r):
					return maxf(nx, (c + 1) * BbD.T + w * 0.5)
	return nx


# ==================== 판 ====================


func _load(l: int) -> void:
	lv = clampi(l, 0, BbD.LEVELS - 1)
	grid = BbD.level(lv)
	enemies = []
	dying = []
	bubbles = []
	items = []
	inks = []
	shark = {}
	boss = {}
	time = 0.0
	word_t = 0.0
	hurry = false
	state = "play"
	state_t = 0.0
	next_lv = lv + 1
	cur = BbD.current(lv)
	sp_t = 0.0
	bolts = []
	waters = []
	bshots = []
	dark = 0.0
	door = {}
	secret = false
	if lv % 10 == 0:
		deaths_block = 0
	for i in players.size():
		_respawn(i)
	var sp := BbD.spawns(lv, grid)
	for n in sp.size():   # 위에서 둥실 내려와 자리 잡는다(하나씩 조금씩 늦게)
		var s: Array = sp[n]
		enemies.append({k = int(s[0]), x = (int(s[1]) + 0.5) * BbD.T, y = BbD.T * 2.0, ty = float(s[2]) * BbD.T + BbD.T, intro = BbD.INTRO_T + n * 0.15, vy = 0.0, dir = 1 if rng.randf() < 0.5 else -1,
				ground = false, angry = false, cd = rng.randf_range(1.0, 3.0), spike_t = rng.randf() * 3.0, jump_cd = rng.randf_range(0.5, 2.0),
				fx = rng.randf_range(-1.0, 1.0), fy = rng.randf_range(-1.0, 1.0), base = float(s[2]) * BbD.T + BbD.T, ph = rng.randf() * TAU})
	if BbD.boss_level(lv):
		var b: Array = BbD.BOSS[clampi(lv / 10, 0, BbD.BOSS.size() - 1)]
		boss = {x = BbD.FIELD.x * 0.6, y = BbD.FIELD.y * 0.35, vx = -90.0, vy = 60.0, hp = int(b[1]), max = int(b[1]), cd = 2.0, trapped = false, t = 0.0,
				anim = "idle", anim_t = 0.0, n = 0, pat = 0, face = -1, dash = 0.0}
	if rng.randf() < 0.4 and not BbD.boss_level(lv):   # 힘 하나 — 판 가운데 위쪽 발판 어딘가에
		items.append({x = rng.randf_range(6.0, 26.0) * BbD.T, y = 3.0 * BbD.T, vy = 0.0, kind = "power", v = rng.randi_range(0, BbD.POWERS.size() - 1), t = -6.0, ground = false})
	if rng.randf() < BbD.SKIP_P and not BbD.boss_level(lv) and not BbD.boss_level(lv + 1):   # 건너뛰기 조개 — 드물게, 10 초 뒤
		items.append({x = rng.randf_range(6.0, 26.0) * BbD.T, y = 3.0 * BbD.T, vy = 0.0, kind = "skip", v = 0, t = -10.0, ground = false})
	if lv % 10 == BbD.SECRET_AT and deaths_block == 0:   # 비밀 방 문 — 이 묶음에서 한 번도 안 죽었다
		door = {x = 9.0 * BbD.T, y = (BbD.ROWS - 1) * BbD.T}
		events.append({kind = "door"})
	events.append({kind = "level", lv = lv})


func _respawn(i: int) -> void:
	var p: Dictionary = players[i]
	if p.out:
		return
	p.x = (3.5 if i == 0 else BbD.COLS - 3.5) * BbD.T
	p.y = (BbD.ROWS - 1) * BbD.T
	p.vy = 0.0
	p.dir = 1 if i == 0 else -1
	p.inv = BbD.INV_T
	p.blind = 0.0
	p.dead_t = 0.0
	p.active = true


func alive_players() -> Array:
	return players.filter(func(p): return p.active and not p.out)


# ==================== 한 걸음 ====================


func step(dt: float) -> void:
	if state == "over" or state == "win":
		return
	state_t += dt
	if state == "next":   # 다음 판으로 내려가는 중
		if state_t >= 1.1:
			if next_lv >= BbD.LEVELS:
				state = "win"
				events.append({kind = "win"})
			else:
				_load(next_lv)
		return
	time += dt
	_step_players(dt)
	_step_bubbles(dt)
	_step_enemies(dt)
	_step_boss(dt)
	_step_bshots(dt)
	_step_misc(dt)
	_step_specials(dt)
	if not door.is_empty() and (state == "play" or state == "clear"):   # 비밀 방 문에 들어간다
		var dr := Rect2(float(door.x) - BbD.T * 0.6, float(door.y) - BbD.T * 2.0, BbD.T * 1.2, BbD.T * 2.0)
		for p: Dictionary in alive_players():
			if _body_rect(p).intersects(dr):
				_enter_secret()
				return
	if state == "play":
		if not hurry and time >= BbD.HURRY_T and (not enemies.is_empty() or not boss.is_empty()):
			hurry = true
			for e: Dictionary in enemies:
				e.angry = true
			events.append({kind = "hurry"})
		if shark.is_empty() and time >= BbD.SHARK_T and (not enemies.is_empty() or not boss.is_empty()):
			shark = {x = BbD.FIELD.x * 0.5, y = -BbD.T * 2.0}
			events.append({kind = "shark"})
		var trapped := bubbles.any(func(b): return int(b.trap) >= 0)
		if enemies.is_empty() and boss.is_empty() and not trapped:
			state = "clear"
			state_t = 0.0
			shark = {}
			events.append({kind = "clear"})
	elif state == "clear" and (state_t >= BbD.CLEAR_WAIT or (state_t >= BbD.CLEAR_MIN and items.is_empty())):
		state = "next"
		state_t = 0.0
		for it: Dictionary in items:   # 남은 물건은 다 먹은 셈
			for p: Dictionary in alive_players():
				p.score += _item_score(it)
				break
		items = []
		bubbles = bubbles.filter(func(b): return int(b.word) >= 0)
		events.append({kind = "next"})
	elif state == "secret" and (state_t >= BbD.SECRET_T or (state_t >= 3.0 and items.is_empty())):
		state = "next"
		state_t = 0.0
		items = []
		bubbles = []
		events.append({kind = "next"})


## 비밀 방으로 — 악당 없는 방, 보물이 쏟아진다. 나오면 다음 판.
func _enter_secret() -> void:
	secret = true
	door = {}
	state = "secret"
	state_t = 0.0
	grid = BbD.secret_room()
	enemies = []
	dying = []
	bubbles = []
	inks = []
	bolts = []
	waters = []
	shark = {}
	boss = {}
	items = []
	for k in 18:
		items.append({x = rng.randf_range(4.0, BbD.COLS - 4.0) * BbD.T, y = rng.randf_range(2.0, 6.0) * BbD.T, vy = 0.0, kind = "item",
				v = 3 if k % 3 == 0 else 2, t = -k * 0.15, ground = false})
	for i in players.size():
		_respawn(i)
	next_lv = lv + 1
	events.append({kind = "secret", lv = lv})


## 악당 하나를 없앤다(번개 · 물살 · 글자 완성 · 건너뛰기) — 날아가며 물건을 떨어뜨리고, by 가 점수를 받는다.
func _kill(e: Dictionary, by: int, n: int = 2) -> void:
	e.dead = true
	dying.append({k = int(e.k), x = float(e.x), y = float(e.y) - BbD.T, vx = rng.randf_range(-220, 220), vy = -380.0, t = 0.0, n = n})
	if by >= 0:
		players[by].score += 1000
	events.append({kind = "pop", x = e.x, y = float(e.y) - BbD.T, chain = 1, pts = 1000, k = e.k})


## 판의 악당 · 갇힌 거품을 모두 없앤다(글자 완성 · 건너뛰기 조개). 보스 판이면 보스에 큰 타격.
func _clear_all(by: int) -> void:
	for e: Dictionary in enemies:
		_kill(e, by, 3)
	enemies = []
	for b: Dictionary in bubbles:
		if int(b.trap) >= 0:
			b.t = 999.0
			dying.append({k = int(b.trap), x = float(b.x), y = float(b.y), vx = rng.randf_range(-220, 220), vy = -380.0, t = 0.0, n = 3})
	bubbles = bubbles.filter(func(b): return float(b.t) < 900.0)
	if not boss.is_empty() and not bool(boss.trapped):
		boss.hp = int(boss.hp) - 6
		_boss_hurt()
		events.append({kind = "boss_hit", x = boss.x, y = boss.y, hp = boss.hp})
		if int(boss.hp) <= 0:
			boss.trapped = true
			boss.t = 0.0
			events.append({kind = "boss_trap", x = boss.x, y = boss.y})


## 번개 · 물살 · 특수 거품 떠오르기.
func _step_specials(dt: float) -> void:
	var spk := BbD.special(lv)
	if state == "play" and spk >= 0 and not secret:
		sp_t += dt
		if sp_t >= BbD.SPECIAL_GAP:
			sp_t = 0.0
			bubbles.append({x = rng.randf_range(4.0, BbD.COLS - 4.0) * BbD.T, y = BbD.FIELD.y - BbD.T, vx = 0.0, state = "float", t = 0.0, owner = -1,
					trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = -1, go = 0.0, sp = spk})
	for z: Dictionary in bolts:   # 번개 — 가로로
		z.x = float(z.x) + float(z.vx) * dt
		for e: Dictionary in enemies:
			if float(e.get("intro", 0.0)) <= 0.0 and absf(float(e.x) - float(z.x)) < BbD.T * 1.2 and absf(float(e.y) - BbD.T - float(z.y)) < BbD.T * 1.4:
				_kill(e, int(z.owner))
		if not boss.is_empty() and not bool(boss.trapped) and not bool(z.hit_boss) and Vector2(boss.x, boss.y).distance_to(Vector2(z.x, z.y)) < BbD.BOSS_SIZE * 0.5:
			z.hit_boss = true
			boss.hp = int(boss.hp) - 2
			_boss_hurt()
			events.append({kind = "boss_hit", x = z.x, y = z.y, hp = boss.hp})
			if int(boss.hp) <= 0:
				boss.trapped = true
				boss.t = 0.0
				events.append({kind = "boss_trap", x = boss.x, y = boss.y})
	bolts = bolts.filter(func(z): return float(z.x) > BbD.T and float(z.x) < BbD.FIELD.x - BbD.T)
	for w: Dictionary in waters:   # 물살 — 떨어지다 발판에 닿으면 그 위를 흘러가고, 벽에서 한 번 돌아선다
		w.t = float(w.t) + dt
		var before := float(w.y)
		var wx := float(w.x)
		var on := _move_body(w, BbD.T * 0.8, BbD.T * 0.8, int(w.dir) * BbD.WATER_V, dt)
		if float(w.y) < before - BbD.FIELD.y * 0.5:   # 바닥 구멍으로 빠졌다
			w.t = 999.0
		elif on and absf(float(w.x) - wx) < 0.5:
			w.flips = int(w.flips) + 1
			w.dir = -int(w.dir)
			if int(w.flips) > 1:
				w.t = 999.0
		w.trail.append(Vector2(w.x, w.y))
		if w.trail.size() > 26:
			w.trail.pop_front()
		for e: Dictionary in enemies:
			if float(e.get("intro", 0.0)) <= 0.0 and absf(float(e.x) - float(w.x)) < BbD.T * 1.3 and absf(float(e.y) - float(w.y)) < BbD.T * 1.8:
				_kill(e, int(w.owner))
		if not boss.is_empty() and not bool(boss.trapped) and not bool(w.hit_boss) and Vector2(boss.x, boss.y).distance_to(Vector2(w.x, w.y)) < BbD.BOSS_SIZE * 0.6:
			w.hit_boss = true
			boss.hp = int(boss.hp) - 3
			_boss_hurt()
			events.append({kind = "boss_hit", x = w.x, y = w.y, hp = boss.hp})
			if int(boss.hp) <= 0:
				boss.trapped = true
				boss.t = 0.0
				events.append({kind = "boss_trap", x = boss.x, y = boss.y})
	waters = waters.filter(func(w): return float(w.t) < BbD.WATER_T)
	enemies = enemies.filter(func(e): return not e.get("dead", false))


func _step_players(dt: float) -> void:
	for i in players.size():
		var p: Dictionary = players[i]
		if p.out:
			continue
		var ip: Dictionary = inp[i] if i < inp.size() else {}
		if not p.active:
			p.dead_t = float(p.dead_t) + dt
			if float(p.dead_t) > 1.6:
				if int(p.lives) > 0:
					_respawn(i)
				else:
					p.out = true
					events.append({kind = "out", p = i})
					if alive_players().is_empty() and players.all(func(q): return q.out):
						state = "over"
						events.append({kind = "over"})
			continue
		p.inv = maxf(0.0, float(p.inv) - dt)
		p.blind = maxf(0.0, float(p.blind) - dt)
		p.cd = maxf(0.0, float(p.cd) - dt)
		p.shot_anim = maxf(0.0, float(p.shot_anim) - dt)
		p.power_t = maxf(0.0, float(p.power_t) - dt)
		if float(p.power_t) <= 0.0 and int(p.power) != 3:
			p.power = -1
		var spd := BbD.WALK * (1.35 if int(p.power) == 2 else 1.0)
		var vx := 0.0
		if ip.get("left", false):
			vx -= spd
			p.dir = -1
		if ip.get("right", false):
			vx += spd
			p.dir = 1
		p.pop_jump = maxf(0.0, float(p.get("pop_jump", 0.0)) - dt)
		if ip.get("jump", false) and (p.ground or float(p.pop_jump) > 0.0):   # 땅에서, 또는 거품을 밟아 터뜨린 바로 그 순간
			p.vy = -BbD.JUMP_V
			p.ground = false
			p.pop_jump = 0.0
			events.append({kind = "jump", p = i})
		var prev_y := float(p.y)
		p.ground = _move_body(p, BbD.BODY.x, BbD.BODY.y, vx, dt, BbD.FOOT)
		# 거품 위 — 점프 키를 누른 채 내려앉으면 통 튀어 오르고(거품 타기), 아니면 거품이 터진다
		if float(p.vy) >= 0.0 and not p.ground:
			for b: Dictionary in bubbles:
				if String(b.state) != "float":
					continue
				var top := float(b.y) - _r(b)
				if absf(float(p.x) - float(b.x)) < _r(b) * 0.9 and prev_y <= top + 4.0 and float(p.y) >= top:
					if ip.get("jump_held", false) and int(b.trap) < 0 and int(b.word) < 0 and int(b.get("sp", -1)) < 0:
						p.y = top
						p.vy = -BbD.JUMP_V * 0.92
						events.append({kind = "bounce", x = b.x, y = b.y})
					else:   # 밟아 터뜨린다 — 그 순간 점프 키를 누르면 뛴다(뭉친 거품 꼭대기에서 터뜨리며 점프, 사용자 11-11)
						p.pop_jump = BbD.POP_JUMP_T
						_pop(b, i)
					break
		# 쏘기
		if ip.get("shot", false) and float(p.cd) <= 0.0:
			_shoot(i)
		# 거품에 닿으면 터뜨린다(옆 · 아래에서)
		var body := _body_rect(p)
		for b: Dictionary in bubbles:
			if String(b.state) == "float" and float(b.t) > 0.25 and _hits(body, Vector2(b.x, b.y), _r(b) * 0.8):
				_pop(b, i)
				break
		# 물건
		for it: Dictionary in items:
			if float(it.t) >= 0.0 and body.grow(6.0).has_point(Vector2(it.x, it.y)):
				it.t = 999.0
				if String(it.kind) == "power":
					p.power = int(it.v)
					p.power_t = BbD.POWER_T
					events.append({kind = "power", p = i, v = it.v, x = it.x, y = it.y})
				elif String(it.kind) == "skip":   # 건너뛰기 조개 — 이 판을 깨고 SKIP_N 판을 더 넘는다(다음 보스 판까지만)
					var boss_lv := (lv / 10) * 10 + 9
					next_lv = mini(lv + 1 + BbD.SKIP_N, boss_lv)
					_clear_all(i)
					events.append({kind = "skip", p = i, n = next_lv - lv - 1, x = it.x, y = it.y})
				else:
					p.score += _item_score(it)
					events.append({kind = "item", p = i, v = it.v, x = it.x, y = it.y, pts = _item_score(it)})
		items = items.filter(func(it): return float(it.t) < 900.0)


func _r(b: Dictionary) -> float:
	return BbD.BUB_R * (1.35 if bool(b.big) else 1.0)


func _body_rect(p: Dictionary) -> Rect2:
	return Rect2(float(p.x) - BbD.BODY.x * 0.5, float(p.y) - BbD.BODY.y, BbD.BODY.x, BbD.BODY.y)


## 악당 · 먹물 · 상어 · 보스에 닿는 판정 — 몸보다 작다.
func _hit_rect(p: Dictionary) -> Rect2:
	return Rect2(float(p.x) - BbD.HIT.x * 0.5, float(p.y) - BbD.HIT.y, BbD.HIT.x, BbD.HIT.y)


func _hits(r: Rect2, c: Vector2, rad: float) -> bool:
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_to(c) <= rad


func _shoot(i: int) -> void:
	var p: Dictionary = players[i]
	var mine := bubbles.filter(func(b): return int(b.owner) == i and int(b.word) < 0).size()
	if mine >= BbD.MAX_BUB:
		return
	p.cd = BbD.SHOT_CD * (0.5 if int(p.power) == 1 else 1.0)
	p.shot_anim = 0.25
	var rainbow := int(p.power) == 3
	if rainbow:
		p.power = -1
	# 입에서 나온다(11-11 사용자) — 그림 3 칸 때의 입 높이 · 얼굴 앞. 그림을 3.4 칸으로 키울 때(11-11 밤) 같이 올렸더니(1.73 칸)
	# 같은 층 악당 위로 지나가 봇이 판을 깨는 시간이 14.4 → 19.6초로 늘어 그대로 둠 — 화면에선 0.2 칸(5px) 차이라 거의 안 보인다.
	# 처음엔 작게 나와 부풀며 뻗는다(main 이 t 로 키운다)
	bubbles.append({x = float(p.x) + int(p.dir) * BbD.T * 0.7, y = float(p.y) - BbD.T * 1.53, vx = int(p.dir) * BbD.SHOT_V * (1.6 if rainbow else 1.0),
			state = "shot", t = 0.0, owner = i, trap = -1, trap_t = 0.0, angry = false, big = int(p.power) == 0, rainbow = rainbow, word = -1, go = 0.0})
	events.append({kind = "shot", p = i})


func _step_bubbles(dt: float) -> void:
	for b: Dictionary in bubbles:
		b.t = float(b.t) + dt
		if String(b.state) == "shot":
			var nx := float(b.x) + float(b.vx) * dt
			b.go = float(b.go) + absf(float(b.vx)) * dt
			var lim_l := 2.0 * BbD.T + _r(b)
			var lim_r := (BbD.COLS - 2) * BbD.T - _r(b)
			b.x = clampf(nx, lim_l, lim_r)
			# 쏜 거품이 악당에 닿으면 가둔다(무지개 거품은 닿는 것을 모두 가두며 계속 간다)
			for e: Dictionary in enemies:
				if float(e.get("intro", 0.0)) <= 0.0 and Vector2(b.x, b.y).distance_to(Vector2(e.x, float(e.y) - BbD.T * 0.9)) < _r(b) + BbD.T * 0.75:
					if int(e.k) == 4 and _spiky(e):   # 성게가 가시를 세웠을 때는 거품이 터진다
						b.t = 999.0
						events.append({kind = "fizz", x = b.x, y = b.y})
						break
					if bool(b.rainbow):
						_trap_new(e, int(b.owner))
						continue
					b.trap = int(e.k)
					b.angry = false
					b.trap_t = 0.0
					b.state = "float"
					e.dead = true
					events.append({kind = "trap", x = b.x, y = b.y, k = e.k})
					break
			enemies = enemies.filter(func(e): return not e.get("dead", false))
			if not boss.is_empty() and not bool(boss.trapped) and Vector2(b.x, b.y).distance_to(Vector2(boss.x, boss.y)) < _r(b) + BbD.BOSS_SIZE * 0.45:
				boss.hp = int(boss.hp) - (3 if bool(b.rainbow) else 1)
				b.t = 999.0
				_boss_hurt()
				events.append({kind = "boss_hit", x = b.x, y = b.y, hp = boss.hp})
				if int(boss.hp) <= 0:
					boss.trapped = true
					boss.t = 0.0
					events.append({kind = "boss_trap", x = boss.x, y = boss.y})
			if float(b.go) >= BbD.SHOT_LEN * (4.0 if bool(b.rainbow) else 1.0) or nx != float(b.x):
				if bool(b.rainbow):
					b.t = 999.0
				else:
					b.state = "float"
		elif String(b.state) == "float":
			if int(b.trap) >= 0:
				b.trap_t = float(b.trap_t) + dt
				if float(b.trap_t) >= BbD.TRAP_OUT:   # 깨고 나온다 — 화난 채로
					enemies.append({k = int(b.trap), x = float(b.x), y = float(b.y) + BbD.T * 0.9, vy = -200.0, dir = 1 if rng.randf() < 0.5 else -1, ground = false,
							angry = true, cd = 1.5, spike_t = 0.0, jump_cd = 1.0, fx = rng.randf_range(-1, 1), fy = -1.0, base = float(b.y) + BbD.T * 0.9, ph = 0.0})
					b.t = 999.0
					events.append({kind = "escape", x = b.x, y = b.y})
					continue
			var top := BbD.T + _r(b) + 4.0
			var ty := maxf(top, cur.y)   # 이 판 물살이 모이는 높이(판마다 다르다 — 11-11 영상 분석)
			var hole := float(b.x) > (BbD.HOLE[0] + 0.5) * BbD.T and float(b.x) < (BbD.HOLE[1] + 0.5) * BbD.T
			if int(b.trap) >= 0 and hole and float(b.y) <= top + 2.0:   # 갇힌 거품은 천장 구멍으로 빠져 바닥에서 다시 떠오른다(기획서)
				b.y = float(b.y) - BbD.RISE_V * dt
				if float(b.y) < -_r(b):
					b.y = BbD.FIELD.y + _r(b)
			elif int(b.word) >= 0 or int(b.get("sp", -1)) >= 0:   # 글자 · 특수 거품은 바닥에서 위로 곧게 떠오르다 위에서 흩어진다
				b.y = float(b.y) - BbD.RISE_V * 1.2 * dt
				if float(b.y) < top:
					b.y = top
			elif absf(float(b.y) - ty) > 2.0:   # 물살 높이까지 떠오르거나(가라앉거나)
				b.y = float(b.y) + clampf(ty - float(b.y), -BbD.RISE_V * dt, BbD.RISE_V * dt)
			else:   # 물살 높이 — 모이는 자리로 흘러간다
				var cx := cur.x + sin(float(b.t) * 0.7 + float(b.owner)) * BbD.T * 1.2   # 모이는 자리 둘레로 좁게(예전 ±3 칸 — 흩어져 보였다)
				b.x = float(b.x) + clampf(cx - float(b.x), -60.0, 60.0) * dt
			if int(b.trap) < 0 and int(b.word) < 0 and float(b.t) > BbD.BUB_LIFE * (1.6 if int(b.get("sp", -1)) >= 0 else 1.0):
				b.t = 999.0
				events.append({kind = "fade", x = b.x, y = b.y})
	# 서로 밀어낸다(겹치지 않게)
	for i in bubbles.size():
		var a: Dictionary = bubbles[i]
		if String(a.state) != "float":
			continue
		for j in range(i + 1, bubbles.size()):
			var c: Dictionary = bubbles[j]
			if String(c.state) != "float":
				continue
			var d := Vector2(c.x, c.y) - Vector2(a.x, a.y)
			var need := (_r(a) + _r(c)) * BbD.BUB_PACK
			var l := d.length()
			if l < need and l > 0.01:
				var push := d / l * (need - l) * 0.5
				a.x = float(a.x) - push.x
				a.y = float(a.y) - push.y
				c.x = float(c.x) + push.x
				c.y = float(c.y) + push.y
		a.x = clampf(float(a.x), 2.0 * BbD.T + _r(a), (BbD.COLS - 2) * BbD.T - _r(a))
	bubbles = bubbles.filter(func(b): return float(b.t) < 900.0)
	# 글자 거품 — 이따금 바닥에서 떠오른다
	word_t += dt
	if state == "play" and word_t >= BbD.WORD_GAP:
		word_t = 0.0
		var need := []
		for k in BbD.WORD.size():
			var any := false
			for p: Dictionary in players:
				if int(p.letters) & (1 << k):
					any = true
			if not any or rng.randf() < 0.3:
				need.append(k)
		if not need.is_empty():
			bubbles.append({x = rng.randf_range(4.0, BbD.COLS - 4.0) * BbD.T, y = BbD.FIELD.y - BbD.T, vx = 0.0, state = "float", t = 0.0, owner = -1,
					trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = need[rng.randi_range(0, need.size() - 1)], go = 0.0})


## 무지개 거품이 닿은 악당 — 그 자리에 새 거품을 만들어 가둔다.
func _trap_new(e: Dictionary, owner: int) -> void:
	e.dead = true
	bubbles.append({x = float(e.x), y = float(e.y) - BbD.T * 0.9, vx = 0.0, state = "float", t = 0.3, owner = owner, trap = int(e.k), trap_t = 0.0,
			angry = false, big = false, rainbow = false, word = -1, go = 0.0})
	events.append({kind = "trap", x = e.x, y = float(e.y) - BbD.T, k = e.k})


## 거품 터뜨리기 — 닿아 있는 거품까지 줄줄이(연쇄). 갇힌 악당이 여럿이면 점수가 곱으로, 물건이 귀해진다.
func _pop(b: Dictionary, by: int) -> void:
	var group := [b]
	var k := 0
	while k < group.size():
		var a: Dictionary = group[k]
		for c: Dictionary in bubbles:
			if String(c.state) == "float" and not group.has(c) and Vector2(a.x, a.y).distance_to(Vector2(c.x, c.y)) < (_r(a) + _r(c)) * 1.08:
				group.append(c)
		k += 1
	var n := 0
	var word_done := false
	for a: Dictionary in group:
		a.t = 999.0
		if int(a.get("sp", -1)) >= 0 and by >= 0:   # 특수 거품 — 터뜨린 사람이 보는 쪽으로
			var d := int(players[by].dir)
			if int(a.sp) == 0:
				bolts.append({x = float(a.x), y = float(a.y), vx = d * BbD.THUNDER_V, owner = by, hit_boss = false})
			else:
				waters.append({x = float(a.x), y = float(a.y), vy = 0.0, dir = d, t = 0.0, owner = by, flips = 0, trail = [], hit_boss = false})
			events.append({kind = "special", v = a.sp, x = a.x, y = a.y})
		if int(a.word) >= 0 and by >= 0:
			var p: Dictionary = players[by]
			p.letters = int(p.letters) | (1 << int(a.word))
			events.append({kind = "letter", p = by, v = a.word, x = a.x, y = a.y})
			if int(p.letters) == (1 << BbD.WORD.size()) - 1:
				p.letters = 0
				p.lives = int(p.lives) + 1
				p.score += 20000
				word_done = true
				events.append({kind = "word", p = by})
		if int(a.trap) >= 0:
			n += 1
	var i := 0
	for a: Dictionary in group:
		if int(a.trap) < 0:
			events.append({kind = "pop", x = a.x, y = a.y, chain = 0})
			continue
		i += 1
		var pts := 1000 * int(pow(2, i - 1))
		if by >= 0:
			players[by].score += pts
		dying.append({k = int(a.trap), x = float(a.x), y = float(a.y), vx = rng.randf_range(-220, 220), vy = -380.0, t = 0.0, n = n})
		events.append({kind = "pop", x = a.x, y = a.y, chain = n, pts = pts, k = a.trap})
	if n >= 2:
		events.append({kind = "chain", n = n, x = b.x, y = b.y})
	bubbles = bubbles.filter(func(c): return float(c.t) < 900.0)
	if word_done and state == "play":   # 글자 다섯 — 그 판 바로 통과(원작처럼, 11-11 영상 분석)
		_clear_all(by)


func _spiky(e: Dictionary) -> bool:
	return int(e.k) == 4 and fmod(float(e.spike_t), 3.0) > 1.8


func _step_enemies(dt: float) -> void:
	var targets := alive_players()
	for e: Dictionary in enemies:
		var row: Array = BbD.ENEMY[int(e.k)]
		if float(e.get("intro", 0.0)) > 0.0:   # 판 처음 — 위에서 내려오는 중(움직이지도 닿지도 않는다)
			e.intro = float(e.intro) - dt
			e.y = lerpf(float(e.ty), BbD.T * 2.0, clampf(float(e.intro) / BbD.INTRO_T, 0.0, 1.0) ** 2)
			continue
		var spd := float(row[1]) * (BbD.ANGRY_K if bool(e.angry) else 1.0) * (1.0 + lv * 0.006)
		e.spike_t = float(e.spike_t) + dt
		var mv := String(row[2])
		if mv == "wave":   # 날치 — 옆으로 날며 물결치듯 위아래로(발판 무시, 벽에서 돌아선다)
			e.ph = float(e.get("ph", 0.0)) + dt * 2.4
			e.x = float(e.x) + int(e.dir) * spd * dt
			e.y = clampf(float(e.get("base", e.y)) + sin(float(e.ph)) * BbD.T * 1.6, 3.0 * BbD.T, (BbD.ROWS - 1) * BbD.T)
			if float(e.x) < 2.5 * BbD.T or float(e.x) > (BbD.COLS - 2.5) * BbD.T:
				e.dir = -int(e.dir)
				e.x = clampf(float(e.x), 2.5 * BbD.T, (BbD.COLS - 2.5) * BbD.T)
		elif mv == "float":   # 해파리 — 비스듬히 떠다니며 벽 · 천장 · 바닥에 튕긴다(발판은 무시)
			var v := Vector2(float(e.fx), float(e.fy)).normalized() * spd
			e.x = float(e.x) + v.x * dt
			e.y = float(e.y) + v.y * dt
			if float(e.x) < 2.5 * BbD.T or float(e.x) > (BbD.COLS - 2.5) * BbD.T:
				e.fx = -float(e.fx)
				e.x = clampf(float(e.x), 2.5 * BbD.T, (BbD.COLS - 2.5) * BbD.T)
			if float(e.y) < 3.0 * BbD.T or float(e.y) > (BbD.ROWS - 1) * BbD.T:
				e.fy = -float(e.fy)
				e.y = clampf(float(e.y), 3.0 * BbD.T, (BbD.ROWS - 1) * BbD.T)
			e.dir = 1 if float(e.fx) > 0.0 else -1
		else:
			var ahead := float(e.x) + int(e.dir) * BbD.T * 0.9
			var below := targets.any(func(p): return float(p.y) > float(e.y) + BbD.T)
			if mv == "drop" and e.ground and below and float(e.jump_cd) <= 0.0:   # 소라게 — 아래층 사람 쪽으로 돈다
				var low: Dictionary = targets[0]
				for p: Dictionary in targets:
					if float(p.y) > float(low.y):
						low = p
				e.dir = 1 if float(low.x) > float(e.x) else -1
			var turn := 1.0 if mv == "hop" else (0.0 if mv == "drop" and below else 0.6)
			if e.ground and not _floor_under(ahead, 2.0, int(round(float(e.y) / BbD.T))) and rng.randf() < turn:
				e.dir = -int(e.dir)   # 발판 끝 — 대개 돌아서고 가끔 뛰어내린다(새우는 늘 돌아서고, 소라게는 사람이 아래에 있으면 떨어진다)
			var wx := float(e.x)
			e.ground = _move_body(e, BbD.BODY.x, BBODY_H, int(e.dir) * spd, dt, BbD.FOOT)
			if absf(float(e.x) - wx) < 0.01 and absf(spd) > 0.0:
				e.dir = -int(e.dir)
			e.jump_cd = float(e.jump_cd) - dt
			if mv == "hop" and e.ground and float(e.jump_cd) <= 0.0:   # 새우 — 제자리 통통
				e.jump_cd = rng.randf_range(0.5, 1.1)
				e.vy = -BbD.JUMP_V * 0.8
				e.ground = false
			elif mv == "drop" and e.ground and float(e.jump_cd) <= 0.0:
				e.jump_cd = rng.randf_range(0.8, 1.6)
			elif e.ground and float(e.jump_cd) <= 0.0:   # 사람이 위층에 있으면 따라 뛴다
				e.jump_cd = rng.randf_range(1.2, 2.6)
				for p: Dictionary in targets:
					if float(p.y) < float(e.y) - BbD.T * 1.5 and absf(float(p.x) - float(e.x)) < BbD.T * 6.0 and rng.randf() < 0.7:
						e.vy = -BbD.JUMP_V
						e.ground = false
						break
			if int(e.k) == 3:   # 문어 — 같은 층의 사람을 보면 먹물
				e.cd = float(e.cd) - dt
				if float(e.cd) <= 0.0 and e.ground:
					for p: Dictionary in targets:
						if absf(float(p.y) - float(e.y)) < BbD.T and signf(float(p.x) - float(e.x)) == float(e.dir) and absf(float(p.x) - float(e.x)) < BbD.T * 10.0:
							inks.append({x = float(e.x), y = float(e.y) - BbD.T * 0.8, vx = int(e.dir) * BbD.INK_V})
							e.cd = rng.randf_range(2.5, 4.0)
							events.append({kind = "ink", x = e.x, y = e.y})
							break
		# 사람에 닿으면
		var er := Rect2(float(e.x) - BbD.T * 0.8, float(e.y) - BbD.T * 1.7, BbD.T * 1.6, BbD.T * 1.7)
		for i in players.size():
			var p: Dictionary = players[i]
			if p.active and not p.out and float(p.inv) <= 0.0 and er.intersects(_hit_rect(p).grow(-4.0)):
				_die(i)
	for d: Dictionary in dying:
		d.t = float(d.t) + dt
		d.vy = float(d.vy) + BbD.GRAVITY * dt
		d.x = clampf(float(d.x) + float(d.vx) * dt, 2.5 * BbD.T, (BbD.COLS - 2.5) * BbD.T)
		d.y = float(d.y) + float(d.vy) * dt
		if float(d.t) > 0.9 and not d.has("dropped"):   # 떨어진 자리에 물건
			d.dropped = true
			var v := clampi(int(d.n) - 1, 0, BbD.ITEMS.size() - 1)
			items.append({x = clampf(float(d.x), 3.0 * BbD.T, (BbD.COLS - 3) * BbD.T), y = clampf(float(d.y), 2.0 * BbD.T, BbD.FIELD.y - BbD.T * 2.0), vy = 0.0,
					kind = "item", v = v, t = 0.0, ground = false})
	dying = dying.filter(func(d): return float(d.t) < 1.0)


const BBODY_H := 1.6 * 26.0


func _step_boss(dt: float) -> void:
	if boss.is_empty():
		return
	boss.t = float(boss.t) + dt
	var half := BbD.BOSS_SIZE * 0.5
	if bool(boss.trapped):   # 커다란 거품에 갇혀 천천히 떠오른다 — 닿으면 끝
		boss.y = maxf(BbD.T * 3.0 + half, float(boss.y) - 30.0 * dt)
		for i in players.size():
			var p: Dictionary = players[i]
			if p.active and not p.out and _hits(_body_rect(p), Vector2(boss.x, boss.y), half * 1.1):
				p.score += 50000
				for k in 10:
					items.append({x = float(boss.x) + rng.randf_range(-120, 120), y = float(boss.y), vy = rng.randf_range(-300, -100), kind = "item",
							v = rng.randi_range(1, 3), t = 0.0, ground = false})
				events.append({kind = "boss_pop", x = boss.x, y = boss.y, p = i})
				boss = {}
				return
		return
	var sp := 1.0 + (1.0 - float(boss.hp) / float(boss.max)) * 0.8
	var slow := 0.25 if String(boss.anim) == "wind" else 1.0   # 공격 준비 땐 거의 멈춘다(보고 피할 틈)
	if float(boss.dash) > 0.0:   # 해마 왕 돌진
		boss.dash = float(boss.dash) - dt
		boss.x = float(boss.x) + int(boss.face) * BbD.BOSS_DASH_V * dt
	else:
		boss.x = float(boss.x) + float(boss.vx) * sp * slow * dt
		boss.y = float(boss.y) + float(boss.vy) * sp * slow * dt
	if float(boss.x) < 2.0 * BbD.T + half or float(boss.x) > (BbD.COLS - 2) * BbD.T - half:
		boss.vx = -float(boss.vx)
		boss.dash = 0.0
		boss.x = clampf(float(boss.x), 2.0 * BbD.T + half, (BbD.COLS - 2) * BbD.T - half)
	if float(boss.y) < BbD.T + half or float(boss.y) > BbD.FIELD.y - BbD.T - half:
		boss.vy = -float(boss.vy)
		boss.y = clampf(float(boss.y), BbD.T + half, BbD.FIELD.y - BbD.T - half)
	# 공격 — 대기 → 준비(0.7 초, 몸짓으로 알린다) → 공격(0.45 초) → 대기. 맞으면 움찔(준비가 끊긴다).
	# 보스마다 공격 둘, 체력이 반 밑이면 둘을 번갈아(사용자 11-11 "보스의 공격 패턴과 모션이 없다")
	var targets := alive_players()
	boss.anim_t = float(boss.anim_t) + dt
	match String(boss.anim):
		"idle":
			boss.cd = float(boss.cd) - dt
			boss.face = 1 if float(boss.vx) > 0.0 else -1
			if float(boss.cd) <= 0.0 and not targets.is_empty():
				var p: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
				boss.tx = float(p.x)
				boss.ty = float(p.y) - BbD.T
				boss.face = 1 if float(p.x) > float(boss.x) else -1
				boss.pat = 1 if float(boss.hp) <= float(boss.max) * 0.5 and int(boss.n) % 2 == 1 else 0
				boss.n = int(boss.n) + 1
				boss.anim = "wind"
				boss.anim_t = 0.0
				events.append({kind = "boss_wind", x = boss.x, y = boss.y})
		"wind":
			if float(boss.anim_t) >= 0.7:
				_boss_fire()
				boss.anim = "atk"
				boss.anim_t = 0.0
		"atk":
			if float(boss.anim_t) >= 0.45 and float(boss.dash) <= 0.0:
				boss.anim = "idle"
				boss.anim_t = 0.0
				boss.cd = rng.randf_range(1.8, 2.8) / sp
		"hurt":
			if float(boss.anim_t) >= 0.35:
				boss.anim = "idle"
				boss.anim_t = 0.0
				boss.cd = maxf(float(boss.cd), 0.8)
	for i in players.size():
		var p: Dictionary = players[i]
		if p.active and not p.out and float(p.inv) <= 0.0 and _hits(_hit_rect(p).grow(-4.0), Vector2(boss.x, boss.y), half * 0.85):
			_die(i)


## 보스가 맞았다 — 움찔(공격 준비가 끊긴다).
func _boss_hurt() -> void:
	if boss.is_empty():
		return
	boss.anim = "hurt"
	boss.anim_t = 0.0
	boss.dash = 0.0


## 보스 공격 — 보스(lv / 10)마다 둘(pat 0 · 1). 겨냥은 준비할 때 본 사람 자리(boss.tx, ty).
func _boss_fire() -> void:
	var k := clampi(lv / 10, 0, BbD.BOSS.size() - 1)
	var at := Vector2(boss.x, boss.y)
	var aim := (Vector2(float(boss.tx), float(boss.ty)) - at).normalized()
	var pat := int(boss.pat)
	match k:
		0:   # 대왕 문어 — 먹물 셋 부채꼴(맞으면 앞이 안 보임) · 먹물 공 여덟 방향
			if pat == 0:
				for d in [-1, 0, 1]:
					inks.append({x = at.x, y = at.y + d * BbD.T * 1.2, vx = int(boss.face) * BbD.INK_V * 1.1})
			else:
				for i in 8:
					_bshot(0, at, Vector2.from_angle(TAU * i / 8.0) * 190.0)
		1:   # 아귀 — 따라오는 빛 구슬 · 불 끄기(판이 어두워진다)
			if pat == 0:
				_bshot(1, at + aim * BbD.T * 2.0, aim * 120.0)
			else:
				dark = BbD.BOSS_DARK_T
				_bshot(1, at + aim * BbD.T * 2.0, aim * 120.0)
		2:   # 해마 왕 — 물 고리 셋 부채꼴 · 돌진
			if pat == 0:
				for d in [-0.3, 0.0, 0.3]:
					_bshot(2, at + aim * BbD.T * 2.0, aim.rotated(d) * 230.0)
			else:
				boss.dash = 0.9
		3:   # 왕 꽃게 — 바위 던지기(포물선) · 내려찍기(천장에서 바위 셋)
			if pat == 0:
				var dx := float(boss.tx) - at.x
				_bshot(3, at + Vector2(int(boss.face) * BbD.T * 2.0, -BbD.T), Vector2(clampf(dx * 0.9, -330.0, 330.0), -420.0))
			else:
				for d in [-3, 0, 3]:
					_bshot(3, Vector2(clampf(float(boss.tx) + d * BbD.T, 3.0 * BbD.T, (BbD.COLS - 3) * BbD.T), BbD.T * 1.5), Vector2(0, 60.0))
				events.append({kind = "boss_slam", x = at.x, y = at.y})
		4:   # 바다 용 — 진주 불덩이 셋 겨냥 · 여덟 방향
			if pat == 0:
				for d in [-0.25, 0.0, 0.25]:
					_bshot(4, at + aim * BbD.T * 2.0, aim.rotated(d) * 260.0)
			else:
				for i in 8:
					_bshot(4, at, Vector2.from_angle(TAU * i / 8.0 + 0.2) * 200.0)
	events.append({kind = "boss_fire", k = k, pat = pat, x = at.x, y = at.y})


func _bshot(k: int, at: Vector2, v: Vector2) -> void:
	bshots.append({x = at.x, y = at.y, vx = v.x, vy = v.y, k = k, t = 0.0})


## 보스 탄환 움직이기 · 맞히기. 먹물 공은 앞을 가리고, 나머지는 목숨을 잃는다.
func _step_bshots(dt: float) -> void:
	dark = maxf(0.0, dark - dt)
	var targets := alive_players()
	for s: Dictionary in bshots:
		s.t = float(s.t) + dt
		if int(s.k) == 1 and not targets.is_empty():   # 빛 구슬 — 가까운 사람 쪽으로 천천히 꺾인다
			var best: Dictionary = targets[0]
			for p: Dictionary in targets:
				if Vector2(p.x, p.y).distance_to(Vector2(s.x, s.y)) < Vector2(best.x, best.y).distance_to(Vector2(s.x, s.y)):
					best = p
			var want := (Vector2(best.x, float(best.y) - BbD.T) - Vector2(s.x, s.y)).normalized() * 125.0
			var v := Vector2(s.vx, s.vy).lerp(want, clampf(dt * 1.2, 0.0, 1.0))
			s.vx = v.x
			s.vy = v.y
		if int(s.k) == 3:   # 바위 — 떨어진다
			s.vy = float(s.vy) + BbD.GRAVITY * 0.7 * dt
		s.x = float(s.x) + float(s.vx) * dt
		s.y = float(s.y) + float(s.vy) * dt
		for i in players.size():
			var p: Dictionary = players[i]
			if p.active and not p.out and float(p.inv) <= 0.0 and _hits(_hit_rect(p).grow(-4.0), Vector2(s.x, s.y), BbD.T * 0.55):
				s.t = 999.0
				if int(s.k) == 0:
					p.blind = BbD.INK_BLIND
					events.append({kind = "inked", p = i, x = p.x, y = p.y})
				else:
					_die(i)
	var life := 6.0
	bshots = bshots.filter(func(s): return float(s.t) < life and float(s.x) > -BbD.T and float(s.x) < BbD.FIELD.x + BbD.T and float(s.y) > -BbD.T * 2.0 and float(s.y) < BbD.FIELD.y + BbD.T)


func _step_misc(dt: float) -> void:
	# 먹물
	for k: Dictionary in inks:
		k.x = float(k.x) + float(k.vx) * dt
		for i in players.size():
			var p: Dictionary = players[i]
			if p.active and not p.out and float(p.inv) <= 0.0 and _hit_rect(p).grow(-4.0).has_point(Vector2(k.x, k.y)):
				p.blind = BbD.INK_BLIND   # 먹물 — 잠깐 앞이 안 보인다(기획서)
				k.x = -9999.0
				events.append({kind = "inked", p = i, x = p.x, y = p.y})
	inks = inks.filter(func(k): return float(k.x) > 2.0 * BbD.T and float(k.x) < (BbD.COLS - 2) * BbD.T)
	# 물건 — 떨어져 발판에 앉는다
	for it: Dictionary in items:
		it.t = float(it.t) + dt
		if not it.ground:
			it.y = float(it.y) + BbD.T * 0.65   # 가운데 → 발밑 기준으로 잠깐 바꿔 떨어뜨린다(그림 높이 1.3 칸의 절반). 11-11 까지 - 0.4 라 물건이 발판 속 0.4 칸에 앉아 선 사람 몸에 안 닿았다
			var before := float(it.y)
			it.ground = _move_body(it, BbD.T, BbD.T, 0.0, dt)
			if float(it.y) < before - BbD.FIELD.y * 0.5:
				# 바닥 구멍으로 빠졌다 — 사람처럼 위에서 다시 나오게 두면 구멍 열에 발판이 없을 때 끝없이 빠지기만 했다(사용자 11-11).
				# 구멍 바로 옆 바닥에 내려놓는다
				var left := float(it.x) < (BbD.HOLE[0] + BbD.HOLE[1] + 1) * 0.5 * BbD.T
				it.x = ((BbD.HOLE[0] - 1) if left else (BbD.HOLE[1] + 1)) * BbD.T + BbD.T * 0.5
				it.y = (BbD.ROWS - 1) * BbD.T
				it.vy = 0.0
				it.ground = true
			if it.ground:
				_item_fit(it)
			it.y = float(it.y) - BbD.T * 0.65
		if String(it.kind) == "item" and float(it.t) > BbD.ITEM_LIFE:
			it.t = 999.0
	items = items.filter(func(it): return float(it.t) < 900.0)
	# 상어 그림자 — 가장 가까운 사람에게, 벽 · 발판을 무시하고
	if not shark.is_empty():
		var targets := alive_players()
		if not targets.is_empty():
			var best: Dictionary = targets[0]
			for p: Dictionary in targets:
				if Vector2(p.x, p.y).distance_to(Vector2(shark.x, shark.y)) < Vector2(best.x, best.y).distance_to(Vector2(shark.x, shark.y)):
					best = p
			var to := Vector2(best.x, float(best.y) - BbD.T) - Vector2(shark.x, shark.y)
			var v := to.normalized() * BbD.SHARK_V * (1.0 + minf(2.0, (time - BbD.SHARK_T) / 30.0))
			shark.x = float(shark.x) + v.x * dt
			shark.y = float(shark.y) + v.y * dt
			for i in players.size():
				var p: Dictionary = players[i]
				if p.active and not p.out and float(p.inv) <= 0.0 and _hits(_hit_rect(p).grow(-6.0), Vector2(shark.x, shark.y), BbD.T * 1.1):
					_die(i)


## 내려앉은 물건(발밑 기준 it.y)이 사람이 들어갈 수 있는 자리인가 — 사람 몸(1.5 × 1.75 칸)이 그 위에 설 수 있어야 먹는다.
## 아니면(발판 밑 한두 칸 틈 · 벽 사이 틈) 사람이 설 수 있는 가장 가까운 발판 위로 옮긴다(사용자 11-11 "발판 사이에 끼여서 못 먹는다").
func _item_fit(it: Dictionary) -> void:
	if _stand_ok(float(it.x), float(it.y)):
		return
	var best := Vector2(-1, -1)
	var bd := 1e9
	for r in range(3, BbD.ROWS):
		for c in range(2, BbD.COLS - 3):
			var x := (c + 1) * BbD.T
			var foot := r * BbD.T
			if not _floor_under(x, BbD.FOOT, r) or not _stand_ok(x, foot):
				continue
			var d := Vector2(x, foot).distance_squared_to(Vector2(float(it.x), float(it.y)))
			if d < bd:
				bd = d
				best = Vector2(x, foot)
	if best.x >= 0.0:
		it.x = best.x
		it.y = best.y


## 발밑(x, foot)에 사람 몸이 들어가나 — 발판 위 두 줄이 몸 폭만큼 비어 있다.
func _stand_ok(x: float, foot: float) -> bool:
	var r := int(round(foot / BbD.T))
	for c in range(_cell(x - BbD.BODY.x * 0.5 + 2.0), _cell(x + BbD.BODY.x * 0.5 - 2.0) + 1):
		for rr in range(r - 2, r):
			if solid(c, rr):
				return false
	return true


func _die(i: int) -> void:
	if god:
		return
	var p: Dictionary = players[i]
	if not p.active:
		return
	p.active = false
	p.dead_t = 0.0
	deaths_block += 1
	p.lives = int(p.lives) - 1
	p.power = -1
	events.append({kind = "die", p = i, x = p.x, y = p.y})


## 이어 하기 — 다 끝난 뒤 점수 · 목숨 · 글자를 처음으로 하고 그 판부터 다시(남은 횟수 하나를 쓴다).
func continue_() -> bool:
	if state != "over" or continues <= 0:
		return false
	continues -= 1
	for p: Dictionary in players:
		p.out = false
		p.active = true
		p.lives = BbD.LIVES
		p.score = 0
		p.letters = 0
		p.power = -1
	_load(lv)
	return true


func _item_score(it: Dictionary) -> int:
	if String(it.kind) != "item":
		return 0
	return int(BbD.ITEMS[clampi(int(it.v), 0, BbD.ITEMS.size() - 1)][1])


func total_score() -> int:
	var s := 0
	for p: Dictionary in players:
		s += int(p.score)
	return s


## 확인용 봇 — 갇힌 거품이 있으면 그리로 가 터뜨리고, 아니면 가까운 악당에게 가서 같은 층이면 쏜다. inp 한 칸을 돌려준다.
func bot_input(i: int) -> Dictionary:
	var p: Dictionary = players[i]
	var out := {left = false, right = false, jump = false, jump_held = false, shot = false}
	if not p.active or p.out:
		return out
	var tx := -1.0
	var ty := 0.0
	for b: Dictionary in bubbles:
		if int(b.trap) >= 0 or int(b.word) >= 0:
			tx = float(b.x)
			ty = float(b.y)
			break
	var shoot_ok := false
	if tx < 0.0:
		var best := 1e9
		for e: Dictionary in enemies:
			var d := absf(float(e.x) - float(p.x)) + absf(float(e.y) - float(p.y)) * 2.0
			if d < best:
				best = d
				tx = float(e.x)
				ty = float(e.y)
		if not boss.is_empty():
			tx = float(boss.x)
			ty = float(boss.y)
			shoot_ok = absf(ty - float(p.y)) < BbD.BOSS_SIZE * 0.6
		elif tx >= 0.0:
			shoot_ok = absf(ty - float(p.y)) < BbD.T * 0.8 and absf(tx - float(p.x)) < BbD.SHOT_LEN + BbD.T * 2.0
	if tx < 0.0:
		return out
	var dx := tx - float(p.x)
	if shoot_ok:   # 바라보는 쪽이 맞으면 쏘고, 아니면 돌아선다
		if signf(dx) == float(p.dir) or absf(dx) < 4.0:
			out.shot = rng.randf() < 0.5
		else:
			out.left = dx < 0.0
			out.right = dx > 0.0
		if absf(dx) < BbD.T * 2.0:   # 너무 가까우면 물러선다
			out.left = dx > 0.0
			out.right = dx < 0.0
	elif absf(dx) > BbD.T * 0.4:
		out.left = dx < 0.0
		out.right = dx > 0.0
	if ty < float(p.y) - BbD.T * 2.0 and rng.randf() < 0.08:
		out.jump = true
		out.jump_held = true
	return out


## 확인용 — 이 판의 악당을 모두 거품에 가둬 바로 터뜨린 것처럼(판 넘김 · 연출 검사).
func cheat_clear() -> void:
	for e: Dictionary in enemies:
		dying.append({k = int(e.k), x = float(e.x), y = float(e.y) - BbD.T, vx = 0.0, vy = -300.0, t = 0.0, n = 1})
	enemies = []
	boss = {}
	bubbles = bubbles.filter(func(b): return int(b.trap) < 0)
