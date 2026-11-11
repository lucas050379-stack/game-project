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
func _move_body(b: Dictionary, w: float, h: float, vx: float, dt: float) -> bool:
	b.x = clampf(float(b.x) + vx * dt, 2.0 * BbD.T + w * 0.5, (BbD.COLS - 2) * BbD.T - w * 0.5)
	var prev := float(b.y)
	b.vy = minf(float(b.vy) + BbD.GRAVITY * dt, BbD.FALL_MAX if float(b.vy) > 0.0 else 99999.0)
	b.y = prev + float(b.vy) * dt
	var landed := false
	if float(b.vy) >= 0.0:
		var r0 := int(floor(prev / BbD.T + 0.001))
		var r1 := int(floor(float(b.y) / BbD.T))
		for r in range(r0, r1 + 1):
			if r >= 0 and r < BbD.ROWS and r * BbD.T >= prev - 0.01 and r * BbD.T <= float(b.y) and _floor_under(float(b.x), w, r):
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
	for i in players.size():
		_respawn(i)
	var sp := BbD.spawns(lv, grid)
	for n in sp.size():   # 위에서 둥실 내려와 자리 잡는다(하나씩 조금씩 늦게)
		var s: Array = sp[n]
		enemies.append({k = int(s[0]), x = (int(s[1]) + 0.5) * BbD.T, y = BbD.T * 2.0, ty = float(s[2]) * BbD.T + BbD.T, intro = BbD.INTRO_T + n * 0.15, vy = 0.0, dir = 1 if rng.randf() < 0.5 else -1,
				ground = false, angry = false, cd = rng.randf_range(1.0, 3.0), spike_t = rng.randf() * 3.0, jump_cd = rng.randf_range(0.5, 2.0),
				fx = rng.randf_range(-1.0, 1.0), fy = rng.randf_range(-1.0, 1.0)})
	if BbD.boss_level(lv):
		var b: Array = BbD.BOSS[clampi(lv / 10, 0, BbD.BOSS.size() - 1)]
		boss = {x = BbD.FIELD.x * 0.6, y = BbD.FIELD.y * 0.35, vx = -90.0, vy = 60.0, hp = int(b[1]), max = int(b[1]), cd = 2.0, trapped = false, t = 0.0}
	if rng.randf() < 0.4 and not BbD.boss_level(lv):   # 힘 하나 — 판 가운데 위쪽 발판 어딘가에
		items.append({x = rng.randf_range(6.0, 26.0) * BbD.T, y = 3.0 * BbD.T, vy = 0.0, kind = "power", v = rng.randi_range(0, BbD.POWERS.size() - 1), t = -6.0, ground = false})
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
			if lv + 1 >= BbD.LEVELS:
				state = "win"
				events.append({kind = "win"})
			else:
				_load(lv + 1)
		return
	time += dt
	_step_players(dt)
	_step_bubbles(dt)
	_step_enemies(dt)
	_step_boss(dt)
	_step_misc(dt)
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
	elif state == "clear" and state_t >= BbD.CLEAR_WAIT:
		state = "next"
		state_t = 0.0
		for it: Dictionary in items:   # 남은 물건은 다 먹은 셈
			for p: Dictionary in alive_players():
				p.score += _item_score(it)
				break
		items = []
		bubbles = bubbles.filter(func(b): return int(b.word) >= 0)
		events.append({kind = "next"})


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
		if ip.get("jump", false) and p.ground:
			p.vy = -BbD.JUMP_V
			p.ground = false
			events.append({kind = "jump", p = i})
		var prev_y := float(p.y)
		p.ground = _move_body(p, BbD.BODY.x, BbD.BODY.y, vx, dt)
		# 거품 위 — 점프 키를 누른 채 내려앉으면 통 튀어 오르고(거품 타기), 아니면 거품이 터진다
		if float(p.vy) >= 0.0 and not p.ground:
			for b: Dictionary in bubbles:
				if String(b.state) != "float":
					continue
				var top := float(b.y) - _r(b)
				if absf(float(p.x) - float(b.x)) < _r(b) * 0.9 and prev_y <= top + 4.0 and float(p.y) >= top:
					if ip.get("jump_held", false) and int(b.trap) < 0 and int(b.word) < 0:
						p.y = top
						p.vy = -BbD.JUMP_V * 0.92
						events.append({kind = "bounce", x = b.x, y = b.y})
					else:
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
				else:
					p.score += _item_score(it)
					events.append({kind = "item", p = i, v = it.v, x = it.x, y = it.y, pts = _item_score(it)})
		items = items.filter(func(it): return float(it.t) < 900.0)


func _r(b: Dictionary) -> float:
	return BbD.BUB_R * (1.35 if bool(b.big) else 1.0)


func _body_rect(p: Dictionary) -> Rect2:
	return Rect2(float(p.x) - BbD.BODY.x * 0.5, float(p.y) - BbD.BODY.y, BbD.BODY.x, BbD.BODY.y)


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
	bubbles.append({x = float(p.x) + int(p.dir) * BbD.T * 0.6, y = float(p.y) - BbD.BODY.y * 0.55, vx = int(p.dir) * BbD.SHOT_V * (1.6 if rainbow else 1.0),
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
							angry = true, cd = 1.5, spike_t = 0.0, jump_cd = 1.0, fx = rng.randf_range(-1, 1), fy = -1.0})
					b.t = 999.0
					events.append({kind = "escape", x = b.x, y = b.y})
					continue
			var top := BbD.T + _r(b) + 4.0
			var hole := float(b.x) > (BbD.HOLE[0] + 0.5) * BbD.T and float(b.x) < (BbD.HOLE[1] + 0.5) * BbD.T
			if int(b.trap) >= 0 and hole and float(b.y) <= top + 2.0:   # 갇힌 거품은 천장 구멍으로 빠져 바닥에서 다시 떠오른다(기획서)
				b.y = float(b.y) - BbD.RISE_V * dt
				if float(b.y) < -_r(b):
					b.y = BbD.FIELD.y + _r(b)
			elif int(b.word) >= 0:   # 글자 거품은 바닥에서 위로 곧게 떠오르다 위에서 흩어진다
				b.y = float(b.y) - BbD.RISE_V * 1.2 * dt
				if float(b.y) < top:
					b.y = top
			elif float(b.y) > top:
				b.y = maxf(top, float(b.y) - BbD.RISE_V * dt)
			else:   # 천장 밑 — 가운데로 모이는 물살
				var cx := BbD.FIELD.x * 0.5 + sin(float(b.t) * 0.7 + float(b.owner)) * BbD.T * 3.0
				b.x = float(b.x) + clampf(cx - float(b.x), -30.0, 30.0) * dt
			if int(b.trap) < 0 and int(b.word) < 0 and float(b.t) > BbD.BUB_LIFE:
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
			var need := _r(a) + _r(c)
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
	for a: Dictionary in group:
		a.t = 999.0
		if int(a.word) >= 0 and by >= 0:
			var p: Dictionary = players[by]
			p.letters = int(p.letters) | (1 << int(a.word))
			events.append({kind = "letter", p = by, v = a.word, x = a.x, y = a.y})
			if int(p.letters) == (1 << BbD.WORD.size()) - 1:
				p.letters = 0
				p.lives = int(p.lives) + 1
				p.score += 20000
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
		if String(row[2]) == "float":   # 해파리 — 비스듬히 떠다니며 벽 · 천장 · 바닥에 튕긴다(발판은 무시)
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
			if e.ground and not _floor_under(ahead, 2.0, int(round(float(e.y) / BbD.T))) and rng.randf() < 0.6:
				e.dir = -int(e.dir)   # 발판 끝 — 대개 돌아서고 가끔 뛰어내린다
			var wx := float(e.x)
			e.ground = _move_body(e, BbD.BODY.x, BBODY_H, int(e.dir) * spd, dt)
			if absf(float(e.x) - wx) < 0.01 and absf(spd) > 0.0:
				e.dir = -int(e.dir)
			e.jump_cd = float(e.jump_cd) - dt
			if e.ground and float(e.jump_cd) <= 0.0:   # 사람이 위층에 있으면 따라 뛴다
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
			if p.active and not p.out and float(p.inv) <= 0.0 and er.intersects(_body_rect(p).grow(-4.0)):
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
	boss.x = float(boss.x) + float(boss.vx) * sp * dt
	boss.y = float(boss.y) + float(boss.vy) * sp * dt
	if float(boss.x) < 2.0 * BbD.T + half or float(boss.x) > (BbD.COLS - 2) * BbD.T - half:
		boss.vx = -float(boss.vx)
		boss.x = clampf(float(boss.x), 2.0 * BbD.T + half, (BbD.COLS - 2) * BbD.T - half)
	if float(boss.y) < BbD.T + half or float(boss.y) > BbD.FIELD.y - BbD.T - half:
		boss.vy = -float(boss.vy)
		boss.y = clampf(float(boss.y), BbD.T + half, BbD.FIELD.y - BbD.T - half)
	boss.cd = float(boss.cd) - dt
	var targets := alive_players()
	if float(boss.cd) <= 0.0 and not targets.is_empty():   # 먹물 셋을 부채꼴로
		boss.cd = rng.randf_range(2.2, 3.4) / sp
		var p: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
		var dir := signf(float(p.x) - float(boss.x))
		for k in 3:
			inks.append({x = float(boss.x), y = float(boss.y) + (k - 1) * BbD.T * 1.2, vx = dir * BbD.INK_V * 1.1})
		events.append({kind = "ink", x = boss.x, y = boss.y})
	for i in players.size():
		var p: Dictionary = players[i]
		if p.active and not p.out and float(p.inv) <= 0.0 and _hits(_body_rect(p).grow(-4.0), Vector2(boss.x, boss.y), half * 0.85):
			_die(i)


func _step_misc(dt: float) -> void:
	# 먹물
	for k: Dictionary in inks:
		k.x = float(k.x) + float(k.vx) * dt
		for i in players.size():
			var p: Dictionary = players[i]
			if p.active and not p.out and float(p.inv) <= 0.0 and _body_rect(p).grow(-4.0).has_point(Vector2(k.x, k.y)):
				p.blind = BbD.INK_BLIND   # 먹물 — 잠깐 앞이 안 보인다(기획서)
				k.x = -9999.0
				events.append({kind = "inked", p = i, x = p.x, y = p.y})
	inks = inks.filter(func(k): return float(k.x) > 2.0 * BbD.T and float(k.x) < (BbD.COLS - 2) * BbD.T)
	# 물건 — 떨어져 발판에 앉는다
	for it: Dictionary in items:
		it.t = float(it.t) + dt
		if not it.ground:
			it.y = float(it.y) - BbD.T * 0.4   # 가운데 → 바닥 기준으로 잠깐 바꿔 떨어뜨린다
			it.ground = _move_body(it, BbD.T, BbD.T, 0.0, dt)
			it.y = float(it.y) + BbD.T * 0.4
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
				if p.active and not p.out and float(p.inv) <= 0.0 and _hits(_body_rect(p).grow(-6.0), Vector2(shark.x, shark.y), BbD.T * 1.1):
					_die(i)


func _die(i: int) -> void:
	if god:
		return
	var p: Dictionary = players[i]
	if not p.active:
		return
	p.active = false
	p.dead_t = 0.0
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
