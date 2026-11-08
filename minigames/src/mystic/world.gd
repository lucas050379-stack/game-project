class_name MsWorld
extends RefCounted

## 비술난무의 세상 — 물리 · 판정 · 적 AI · 구간 진행. **그리기 · 소리 · 오토로드를 모릅니다**
## (tools/mystic_check.gd 가 --script 로 이것만 읽어 돌립니다). 화면이 알아야 할 일은 [member ev] 에
## {fx = 이름, x, y, flip} · {snd = 이름} 으로 쌓고, main 이 프레임마다 비웁니다.
##
## 좌표: 방 하나가 화면 하나(0 ~ VIEW_W). x 는 방 안의 px, y 는 발 높이(위가 작음). 땅 · 발판은 room(MsD.ROOMS) 이 정한다.
## 적은 Dictionary 배열이고 죽어도 바로 빼지 않습니다(dead 표시 → [method _sweep]).

var stage := 0
var sec := 0                 ## 지금 구간
var wave := 0                ## 지금 구간에서 다음에 나올 웨이브 번호
var wave_t := 0.0
var go := false              ## 이 구간을 다 비웠다 — 오른쪽으로 갈 수 있다
var boss_on := false
var state := "play"          ## play · clear(스테이지 끝) · over(쓰러짐) · win(전부 끝)
var t := 0.0
var stop := 0.0              ## 히트 스톱 남은 시간
var shake := 0.0
var cam_x := 0.0             ## 늘 0 — 방 하나가 화면 하나(남겨 둔 것은 그리기 쪽이 같은 식을 쓰게)
var room: Dictionary = {}    ## 지금 방의 지형(MsD.ROOMS 한 칸)
var trans := 0.0             ## 다음 방으로 넘어가는 중(남은 초) — 화면이 어두워졌다 밝아진다
const TRANS := 0.6
var boss_wait := 0.0
var score := 0
var combo := 0
var combo_t := 0.0
var max_combo := 0
var kills := 0

var hero := {}
var enemies: Array = []
var shots: Array = []
var ev: Array = []           ## 화면에 넘길 일
var cmd := MsCmd.new()
var hold := {"L": false, "R": false, "U": false, "D": false}
var rng := RandomNumberGenerator.new()
var _mid := 0                ## 동작 번호 — 같은 동작에 같은 적이 두 번 안 맞게
var _eid := 0                ## 적 번호 — 장풍이 같은 적을 두 번 안 때리게


func _init(st: int = 0, seed_: int = -1) -> void:
	if seed_ >= 0:
		rng.seed = seed_
	else:
		rng.randomize()
	hero = {x = 40.0, y = MsD.GROUND, vx = 0.0, vy = 0.0, face = 1, st = "idle", t = 0.0, hp = MsD.HERO_HP,
			mp = 0.0, inv = 0.0, air_hits = 0, q = false, mid = 0, gr = true, plat = -1, drop = 0.0}
	start_stage(st)


func start_stage(st: int) -> void:
	stage = clampi(st, 0, MsD.STAGES.size() - 1)
	sec = 0
	boss_on = false
	state = "play"
	_enter_room(MsD.room_of(stage, 0))
	hero.hp = minf(MsD.HERO_HP, hero.hp + MsD.HERO_HP * 0.5) if st > 0 else MsD.HERO_HP


## 방 하나에 들어선다 — 화면이 따라 흐르지 않고 한 칸씩 넘어간다(사용자 결정 11-08). 주인공은 왼쪽 끝에서 시작.
func _enter_room(r: Dictionary) -> void:
	room = r
	wave = 0
	wave_t = 0.5
	go = false
	enemies.clear()
	shots.clear()
	cam_x = 0.0
	hero.x = 24.0
	hero.y = floor_at(24.0)
	hero.vx = 0.0
	hero.vy = 0.0
	hero.gr = true
	hero.plat = -1
	hero.st = "idle"
	hero.t = 0.0


func sections() -> Array:
	return MsD.STAGES[stage].sections


func on_ground(e: Dictionary) -> bool:
	return e.get("gr", false)

# ==================== 지형 ====================
# 땅은 꺾은선(언덕은 경사로), 발판은 [x0, x1, 윗면 y, 기둥]. 발판은 떨어질 때만 서고 아래에서는 뚫고 올라간다.
# 땅 · 발판 위를 걷는 것 · 떨어지는 것 · 내려서는 것을 전부 [method _phys] 하나가 맡는다 — 주인공 · 적 · 보스 공통.


## x 에서 땅의 발 높이.
func floor_at(x: float) -> float:
	var g: Array = room.ground
	if x <= float(g[0][0]):
		return float(g[0][1])
	for i in range(1, g.size()):
		var a: Array = g[i - 1]
		var b: Array = g[i]
		if x <= float(b[0]):
			var u := (x - float(a[0])) / maxf(1.0, float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), u)
	return float(g[g.size() - 1][1])


## x 에서 디딜 수 있는 가장 높은 면(발 y) — 발판은 그 윗면이 지금 발보다 아래(또는 같은 높이)일 때만.
func surface_at(x: float, feet: float) -> float:
	var s := floor_at(x)
	for p in room.plats:
		if x >= float(p[0]) and x <= float(p[1]) and feet <= float(p[2]) + 0.5 and float(p[2]) < s:
			s = float(p[2])
	return s


## 중력 · 착지 · 경사 따라 걷기 · 발판 끝에서 떨어지기. 막 내려섰으면 true.
func _phys(e: Dictionary, dt: float, g: float) -> bool:
	e.drop = maxf(0.0, float(e.get("drop", 0.0)) - dt)
	if e.get("gr", false):
		if e.vy < 0.0:
			e.gr = false
			e.plat = -1
		else:
			var pi: int = e.get("plat", -1)
			if pi >= 0:
				var p: Array = room.plats[pi]
				if e.x < float(p[0]) or e.x > float(p[1]):
					e.gr = false   # 발판 끝을 걸어 나갔다
					e.plat = -1
				else:
					e.y = float(p[2])
					e.vy = 0.0
					return false
			else:
				e.y = floor_at(e.x)   # 언덕을 따라 오르내린다
				e.vy = 0.0
				return false
	var prev: float = e.y
	e.vy += g * dt
	e.y += e.vy * dt
	if e.vy < 0.0:
		return false
	var s := floor_at(e.x)
	var land := -1
	if e.drop <= 0.0:
		for i in room.plats.size():
			var p2: Array = room.plats[i]
			if e.x >= float(p2[0]) and e.x <= float(p2[1]) and prev <= float(p2[2]) + 0.5 and e.y >= float(p2[2]) and float(p2[2]) < s:
				s = float(p2[2])
				land = i
	if e.y >= s:
		e.y = s
		e.vy = 0.0
		e.gr = true
		e.plat = land
		return true
	return false

# ==================== 입력 ====================


## 방향을 막 눌렀다(L R U D). 커맨드 버퍼에 쌓는다.
func key_dir(d: String) -> void:
	cmd.dir(d, int(hero.face))


## 공격 버튼(Z). 커맨드가 맞으면 기술, 아니면 연타 · 공중 베기.
func key_atk() -> void:
	if state != "play" or hero.st == "hurt":
		return
	var air := not on_ground(hero)
	var mv := cmd.read(air)
	if mv != "" and _can_skill(mv, 1.0):
		_start_move(mv, 1.0)
		return
	_normal_attack()


## 터치의 기술 단추 — 커맨드 없이 바로. MP 를 TOUCH_MP_K 배 쓴다.
func key_skill(mv: String) -> void:
	if state != "play" or hero.st == "hurt":
		return
	var air := not on_ground(hero)
	if mv == "stomp" and air:
		mv = "dive"
	elif mv == "dive" and not air:
		mv = "stomp"
	if _can_skill(mv, MsD.TOUCH_MP_K):
		_start_move(mv, MsD.TOUCH_MP_K)


func key_jump() -> void:
	if state != "play":
		return
	if on_ground(hero) and _free_to_act():
		if hold.D and int(hero.plat) >= 0:
			# ↓ + 점프 = 발판에서 내려서기
			hero.drop = 0.25
			hero.gr = false
			hero.plat = -1
			hero.vy = 20.0
			hero.st = "fall"
			hero.t = 0.0
			return
		hero.vy = MsD.JUMP_V
		hero.st = "jump"
		hero.t = 0.0
		hero.air_hits = 0
		ev.append({snd = "jump"})


func _free_to_act() -> bool:
	return hero.st in ["idle", "walk", "jump", "fall"] or (MsD.MOVES.has(hero.st) and hero.t >= float(MsD.MOVES[hero.st].get("next", 99.0)))


func _can_skill(mv: String, k: float) -> bool:
	var m: Dictionary = MsD.MOVES[mv]
	if hero.mp < float(m.get("mp", 0.0)) * k:
		return false
	# 연타 도중이면 판정이 끝난 뒤부터 끊고 들어갈 수 있다(캔슬)
	if MsD.MOVES.has(hero.st):
		var cur: Dictionary = MsD.MOVES[hero.st]
		if cur.has("mp"):
			return false
		if cur.has("hit") and hero.t < float(cur.hit[1]):
			return false
		return true
	return hero.st in ["idle", "walk", "jump", "fall"]


func _normal_attack() -> void:
	var air := not on_ground(hero)
	if MsD.MOVES.has(hero.st) and hero.t < float(MsD.MOVES[hero.st].get("next", 99.0)):
		hero.q = true   # 이어 치기 예약
		return
	if air:
		if hero.air_hits < MsD.AIR_HITS:
			_start_move("air", 1.0)
		return
	# 위를 누른 채 치면 — 앞에 뜬 적이 있으면 따라 뛰어올라 공중 베기(원작의 "↑ 누르면서 z 연타")
	if hold.U and _airborne_ahead():
		hero.vy = -250.0
		hero.air_hits = 0
		_start_move("air", 1.0)
		return
	var nxt := "atk1"
	if hero.st == "atk1":
		nxt = "atk2"
	elif hero.st == "atk2":
		nxt = "atk3"
	_start_move(nxt, 1.0)


func _airborne_ahead() -> bool:
	for e in enemies:
		if e.dead or e.get("boss", false):
			continue
		if e.st == "air" and absf(e.x - hero.x) < 70.0 and signf(e.x - hero.x) == float(hero.face):
			return true
	return false


func _start_move(mv: String, k: float) -> void:
	var m: Dictionary = MsD.MOVES[mv]
	hero.mp -= float(m.get("mp", 0.0)) * k
	hero.st = mv
	hero.t = 0.0
	hero.q = false
	_mid += 1
	hero.mid = _mid
	if hold.L and not hold.R:
		hero.face = -1
	elif hold.R and not hold.L:
		hero.face = 1
	if mv == "air":
		hero.air_hits += 1
	if m.has("lift"):
		hero.vy = float(m.lift)
	if m.has("hit"):
		var h: Array = m.hit
		if String(h[8]) != "":
			ev.append({fx = String(h[8]), x = hero.x, y = hero.y, flip = hero.face < 0, delay = float(h[0]) * 0.5})
	ev.append({snd = "skill" if m.has("mp") else "swing"})
	if m.has("mp"):
		ev.append({flash = mv})

# ==================== 한 걸음 ====================


func step(dt: float) -> void:
	cmd.tick(dt)
	if state != "play":
		return
	t += dt
	shake = maxf(0.0, shake - dt)
	if trans > 0.0:
		# 다음 방으로 — 반쯤 어두워졌을 때 방을 바꾼다
		var was := trans
		trans = maxf(0.0, trans - dt)
		if was > TRANS * 0.5 and trans <= TRANS * 0.5:
			_next_room()
		return
	if stop > 0.0:
		stop -= dt
		return
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			combo = 0
	_step_hero(dt)
	_hero_hits()
	for e in enemies:
		if not e.dead:
			_step_enemy(e, dt)
	_step_shots(dt)
	_separate()
	_sweep()
	_progress(dt)


func _step_hero(dt: float) -> void:
	var h := hero
	h.t += dt
	h.inv = maxf(0.0, h.inv - dt)
	var ground := on_ground(h)
	var mv: Dictionary = MsD.MOVES.get(h.st, {})
	# 이동: 서 있거나 걷거나 공중일 때만 방향으로 움직인다
	var want := 0.0
	if h.st in ["idle", "walk", "jump", "fall"]:
		if hold.L and not hold.R:
			want = -1.0
		elif hold.R and not hold.L:
			want = 1.0
		if want != 0.0:
			h.face = int(want)
		h.vx = want * MsD.HERO_SPEED
	elif h.st == "hurt":
		h.vx *= 0.9
	elif mv.has("move"):
		var k := 1.0 - clampf(h.t / float(mv.dur), 0.0, 1.0)
		h.vx = float(h.face) * float(mv.move) * k * k
	elif mv.has("dive"):
		if not ground:
			h.vy = float(mv.dive)
			h.vx = float(h.face) * 40.0
	else:
		h.vx = h.vx * 0.8 if ground else h.vx
	# 중력. 공중 베기 중에는 잠깐 덜 떨어진다(공중 콤보가 손에 붙도록)
	var g := MsD.GRAV
	if h.st == "air":
		g *= 0.45
	h.x += h.vx * dt
	h.x = clampf(h.x, 8.0, MsD.VIEW_W - 8.0)
	var diving: bool = h.st == "dive"
	if _phys(h, dt, g):
		h.air_hits = 0
		if diving:
			# 내려찍기 착지 — 그 자리에 벼락
			ev.append({fx = "fx_dive", x = h.x, y = h.y, flip = false})
			ev.append({snd = "boom"})
			shake = 0.25
			_area_hit(h.x, h.y, 40.0, 20.0, "down")
			h.st = "idle"
			h.t = 0.0
	# 동작 끝
	if not mv.is_empty() and h.t >= float(mv.dur):
		if h.q and h.st in ["atk1", "atk2"]:
			_normal_attack_chain()
		elif h.st == "dive" and not on_ground(h):
			pass   # 땅에 닿을 때까지 내리꽂기
		else:
			h.st = "idle" if on_ground(h) else "fall"
			h.t = 0.0
	elif mv.has("next") and h.q and h.t >= float(mv.next) and h.st in ["atk1", "atk2", "air"]:
		if h.st == "air":
			if not on_ground(h) and h.air_hits < MsD.AIR_HITS:
				_start_move("air", 1.0)
		else:
			_normal_attack_chain()
	if h.st == "hurt" and h.t >= 0.35:
		h.st = "idle"
		h.t = 0.0
	if h.st in ["idle", "walk"]:
		h.st = "walk" if absf(h.vx) > 1.0 else "idle"
	elif h.st == "jump" and h.vy > 0.0:
		h.st = "fall"
	elif h.st == "fall" and on_ground(h):
		h.st = "idle"
	h.mp = clampf(h.mp, 0.0, MsD.MP_MAX)
	# 방을 다 비웠으면 오른쪽 끝으로 걸어 나가 다음 방으로
	if go and h.x >= MsD.VIEW_W - 9.0 and hold.R and trans <= 0.0:
		trans = TRANS
		ev.append({snd = "door"})


func _normal_attack_chain() -> void:
	var nxt := "atk2" if hero.st == "atk1" else "atk3"
	_start_move(nxt, 1.0)

# ==================== 판정 ====================


## 주인공 동작의 판정 상자(세상 좌표) — 그리기 디버그와 판정이 같이 본다. 없으면 Rect2().
func hero_box() -> Rect2:
	var mv: Dictionary = MsD.MOVES.get(hero.st, {})
	if not mv.has("hit"):
		return Rect2()
	var h: Array = mv.hit
	if hero.t < float(h[0]) or hero.t > float(h[1]):
		return Rect2()
	var w := float(h[4])
	var x0: float = hero.x + float(h[2]) if hero.face > 0 else hero.x - float(h[2]) - w
	return Rect2(x0, hero.y + float(h[3]), w, float(h[5]))


func body(e: Dictionary) -> Rect2:
	var w: float
	var hh: float
	if e.get("boss", false):
		w = MsD.BOSS_W
		hh = MsD.BOSS_H
	else:
		var d: Dictionary = MsD.ENEMY[e.kind]
		w = float(d.w)
		hh = float(d.h)
	return Rect2(e.x - w * 0.5, e.y - hh, w, hh)


func hero_body() -> Rect2:
	return Rect2(hero.x - 6.0, hero.y - 32.0, 12.0, 32.0)


func _hero_hits() -> void:
	var box := hero_box()
	if box.size == Vector2.ZERO:
		return
	var mv: Dictionary = MsD.MOVES[hero.st]
	var h: Array = mv.hit
	var multi := float(mv.get("multi", 0.0))
	var landed := false
	for e in enemies:
		if e.dead or e.get("dying", false) or e.inv > 0.0:
			continue
		if not box.intersects(body(e)):
			continue
		if e.last_mid == hero.mid and (multi <= 0.0 or t - float(e.last_t) < multi):
			continue
		e.last_mid = hero.mid
		e.last_t = t
		_damage(e, float(h[6]), String(h[7]), hero.face)
		landed = true
	if landed:
		stop = MsD.HIT_STOP * (1.6 if hero.st in ["atk3", "dash", "stomp"] else 1.0)
		if hero.st == "air":
			hero.vy = minf(hero.vy, -70.0)   # 공중에서 맞히면 살짝 떠서 다음 칼이 닿는다
		if hero.st in ["stomp"]:
			shake = 0.3


## 넓은 범위(내리꽂기 착지 등) — 동작 판정과 별개로 한 번만.
func _area_hit(x: float, y: float, r: float, dmg: float, kind: String) -> void:
	for e in enemies:
		if e.dead or e.get("dying", false):
			continue
		if absf(e.x - x) <= r + 8.0 and absf(e.y - y) < 44.0:
			_damage(e, dmg, kind, 1 if e.x >= x else -1)


func _damage(e: Dictionary, dmg: float, kind: String, dir: int) -> void:
	var boss: bool = e.get("boss", false)
	combo += 1
	combo_t = MsD.COMBO_KEEP
	max_combo = maxi(max_combo, combo)
	var k := 1.0 + minf(combo, 40) * 0.02
	e.hp -= dmg * k
	hero.mp += MsD.MP_PER_HIT + combo * MsD.MP_COMBO
	ev.append({fx = "fx_crit" if kind in ["launch", "knock", "down"] else "fx_hit", x = e.x, y = e.y - body(e).size.y * 0.55, flip = dir < 0})
	ev.append({snd = "hit"})
	if boss:
		e.stag += dmg
		if e.stag >= MsD.BOSS_STAGGER:
			e.stag = 0.0
			e.st = "stun"
			e.t = 0.0
			e.batk = ""
		if e.hp <= 0.0:
			_kill(e)
		return
	match kind:
		"launch":
			e.st = "air"
			e.vy = MsD.LAUNCH_V
			e.vx = dir * 25.0
		"air":
			if e.st == "air":
				e.vy = MsD.AIR_V
				e.vx = dir * 12.0
				e.x = lerpf(e.x, hero.x + hero.face * 16.0, 0.4)   # 칼 앞에 붙잡아 둔다
			else:
				_stun(e, dir)
		"knock":
			e.st = "air"
			e.vy = MsD.KNOCK_V.y
			e.vx = dir * MsD.KNOCK_V.x
		"down":
			if on_ground(e):
				e.st = "down"
				e.t = 0.0
			else:
				e.st = "air"
				e.vy = 320.0
		_:
			if e.st == "air":
				e.vy = minf(e.vy, -60.0)
			else:
				_stun(e, dir)
	if e.hp <= 0.0:
		_kill(e)


func _stun(e: Dictionary, dir: int) -> void:
	e.st = "stun"
	e.t = 0.0
	e.vx = dir * 40.0


func _kill(e: Dictionary) -> void:
	var sc := 1500 if e.get("boss", false) else int(MsD.ENEMY[e.kind].score)
	score += int(sc * (1.0 + combo * 0.05))
	kills += 1
	if e.get("boss", false) or e.st != "air":
		_vanish(e)
	else:
		e.dying = true   # 공중에서 죽으면 땅에 떨어진 뒤 사라진다


func _vanish(e: Dictionary) -> void:
	e.dead = true
	ev.append({fx = "fx_poof", x = e.x, y = e.y, flip = false})
	ev.append({snd = "kill"})
	if e.get("boss", false):
		shake = 0.6

# ==================== 적 ====================


func _spawn(kind: String, side: int) -> void:
	var d: Dictionary = MsD.ENEMY[kind]
	var x := -14.0 if side < 0 else MsD.VIEW_W + 14.0
	var hover := float(d.get("fly", 0.0))
	_eid += 1
	enemies.append({id = _eid, kind = kind, x = x, y = floor_at(x) - hover, vx = 0.0, vy = 0.0, face = -side, st = "walk", t = 0.0,
			hp = float(d.hp), cd = 0.8 + rng.randf() * 0.8, dead = false, last_mid = -1, last_t = -9.0, inv = 0.0,
			hover = hover, ph = rng.randf() * TAU, boss = false, gr = hover <= 0.0, plat = -1, drop = 0.0, hop = 0.0})


func _spawn_boss() -> void:
	var b: Dictionary = MsD.BOSS[stage]
	_eid += 1
	var x := MsD.VIEW_W - 60.0
	enemies.append({id = _eid, kind = "boss", boss = true, x = x, y = floor_at(x), vx = 0.0, vy = 0.0, face = -1,
			st = "walk", t = 0.0, hp = float(b.hp), hp_max = float(b.hp), cd = 1.2, dead = false, last_mid = -1, last_t = -9.0,
			inv = 0.0, hover = 0.0, ph = 0.0, stag = 0.0, batk = "", bdir = -1, bx = 0.0, gr = true, plat = -1, drop = 0.0})
	boss_on = true
	ev.append({snd = "boss"})


## 떠다니는 적의 기준 높이 — 그 자리 땅에서 hover 만큼 위.
func _hover_y(e: Dictionary) -> float:
	return floor_at(e.x) - float(e.hover)


func _step_enemy(e: Dictionary, dt: float) -> void:
	e.t += dt
	e.inv = maxf(0.0, e.inv - dt)
	if e.get("boss", false):
		_step_boss(e, dt)
		return
	var d: Dictionary = MsD.ENEMY[e.kind]
	var flyer: bool = e.hover > 0.0
	match e.st:
		"air":
			e.x = clampf(e.x + e.vx * dt, 6.0, MsD.VIEW_W - 6.0)
			if _phys(e, dt, MsD.GRAV):
				e.vx = 0.0
				if e.get("dying", false):
					_vanish(e)
					return
				e.st = "down"
				e.t = 0.0
				ev.append({snd = "land"})
		"down":
			if e.t >= MsD.DOWN_TIME:
				e.st = "getup"
				e.t = 0.0
				e.inv = MsD.GETUP_INVULN
		"getup":
			if flyer:
				e.gr = false
				e.y = move_toward(e.y, _hover_y(e), 80.0 * dt)
			if e.t >= MsD.GETUP_INVULN and (not flyer or absf(e.y - _hover_y(e)) < 0.5):
				e.st = "walk"
				e.t = 0.0
		"stun":
			e.x = clampf(e.x + e.vx * dt, 6.0, MsD.VIEW_W - 6.0)
			e.vx *= 0.85
			if not flyer:
				_phys(e, dt, MsD.GRAV)
			if e.t >= MsD.HIT_STUN:
				e.st = "walk"
				e.t = 0.0
		"cast":
			# 예비 동작 — 방향(face)은 시작할 때 정했고 안 고친다
			if not flyer:
				_phys(e, dt, MsD.GRAV)
			if e.t >= float(d.atk[1]):
				e.st = "atk"
				e.t = 0.0
		"atk":
			if not flyer:
				_phys(e, dt, MsD.GRAV)
			var r := atk_box(e)
			if hero.inv <= 0.0 and r.intersects(hero_body()):
				_hurt_hero(float(d.atk[3]), int(e.face))
			if e.t >= float(d.atk[2]):
				e.st = "walk"
				e.t = 0.0
				e.cd = float(d.atk[4])
		_:
			e.cd -= dt
			e.hop = maxf(0.0, float(e.hop) - dt)
			var dx: float = hero.x - e.x
			var dist := absf(dx)
			e.face = 1 if dx > 0.0 else -1
			var rng_: float = float(d.atk[0])
			if dist > rng_ - 2.0:
				e.x += signf(dx) * float(d.speed) * dt
			if flyer:
				# 떠다니는 것 — 주인공 머리 높이 근처를 출렁이며 맴돈다(발판 위의 주인공에게도 닿는다)
				var want := _hover_y(e) + sin(t * 2.4 + float(e.ph)) * 6.0
				if dist < 80.0:
					want = lerpf(want, hero.y - 22.0, 0.7)
				e.y = move_toward(e.y, want, 50.0 * dt)
			else:
				# 걷는 것 — 주인공이 발판 위에 있으면 밑에서 뛰어오른다
				if on_ground(e) and e.hop <= 0.0 and hero.y < e.y - 20.0 and dist < 70.0:
					e.vy = MsD.JUMP_V * 0.95
					e.hop = 1.6 + rng.randf()
				elif on_ground(e) and e.plat >= 0 and hero.y > e.y + 20.0 and dist < 80.0 and e.hop <= 0.0:
					e.drop = 0.25   # 주인공이 아래에 있으면 발판에서 내려온다
					e.gr = false
					e.plat = -1
					e.hop = 1.0
				_phys(e, dt, MsD.GRAV)
			e.x = clampf(e.x, -20.0, MsD.VIEW_W + 20.0)
			if dist <= rng_ + 2.0 and e.cd <= 0.0 and absf((hero.y - 16.0) - (e.y - 8.0)) < 30.0 and (flyer or on_ground(e)):
				e.st = "cast"
				e.t = 0.0
				ev.append({snd = "cast"})


## 적의 공격 판정 상자 — 예비 동작 때 그리는 경고와 같은 자리.
func atk_box(e: Dictionary) -> Rect2:
	if e.get("boss", false):
		var a: Dictionary = MsD.BOSS_ATK.get(e.batk, {})
		if e.batk == "slash":
			var w := float(a.range)
			return Rect2(e.x if e.bdir > 0 else e.x - w, e.y - 50.0, w, 50.0)
		if e.batk == "slam":
			var r := float(a.r)
			return Rect2(e.bx - r, floor_at(e.bx) - 18.0, r * 2.0, 18.0)
		return Rect2()
	var d: Dictionary = MsD.ENEMY[e.kind]
	var b := body(e)
	var reach := float(d.atk[0])
	return Rect2(e.x if e.face > 0 else e.x - reach, b.position.y, reach, b.size.y)


func _hurt_hero(dmg: float, dir: int) -> void:
	hero.hp -= dmg
	hero.inv = MsD.INVULN
	hero.st = "hurt"
	hero.t = 0.0
	hero.vx = dir * 80.0
	hero.q = false
	shake = 0.2
	ev.append({snd = "hurt"})
	if hero.hp <= 0.0:
		hero.hp = 0.0
		state = "over"


func _step_boss(e: Dictionary, dt: float) -> void:
	var b: Dictionary = MsD.BOSS[stage]
	var dx: float = hero.x - e.x
	var dist := absf(dx)
	match e.st:
		"stun":
			if e.t >= 0.5:
				e.st = "walk"
				e.t = 0.0
				e.cd = 0.6
		"cast":
			var a: Dictionary = MsD.BOSS_ATK[e.batk]
			if e.t >= float(a.cast):
				e.st = "atk"
				e.t = 0.0
				if e.batk == "orb":
					shots.append({x = e.x + e.bdir * 20.0, y = e.y - 40.0, vx = e.bdir * float(a.speed), dmg = float(a.dmg), foe = true, t = 0.0, dead = false})
					ev.append({snd = "orb"})
				elif e.batk == "slam":
					ev.append({fx = "fx_stomp", x = e.bx, y = floor_at(e.bx), flip = false})
					ev.append({snd = "boom"})
					shake = 0.35
				else:
					ev.append({fx = "fx_slash2", x = e.x, y = e.y, flip = e.bdir < 0, scale = MsD.BOSS_SCALE})
					ev.append({snd = "swing"})
		"atk":
			var a2: Dictionary = MsD.BOSS_ATK[e.batk]
			var r := atk_box(e)
			if r.size != Vector2.ZERO and hero.inv <= 0.0 and r.intersects(hero_body()):
				_hurt_hero(float(a2.dmg), int(e.bdir))
			if e.t >= maxf(0.1, float(a2.act)):
				e.st = "walk"
				e.t = 0.0
				e.cd = float(a2.cd)
				e.batk = ""
		_:
			e.cd -= dt
			e.face = 1 if dx > 0.0 else -1
			if dist > 40.0:
				e.x += signf(dx) * float(b.speed) * dt
			if e.cd <= 0.0:
				# 거리로 고른다 — 가까우면 베기, 중간이면 찍기, 멀면 구
				var pick := "slash" if dist < 56.0 else ("slam" if dist < 120.0 else "orb")
				e.batk = pick
				e.bdir = e.face          # 방향은 여기서 박고 안 고친다
				e.bx = hero.x            # 찍기 자리도 지금 주인공 자리로 박는다
				e.st = "cast"
				e.t = 0.0
				ev.append({snd = "cast"})
	e.x = clampf(e.x, 12.0, MsD.VIEW_W - 12.0)
	_phys(e, dt, MsD.GRAV)


func _step_shots(dt: float) -> void:
	for s in shots:
		if s.dead:
			continue
		s.t += dt
		s.x += s.vx * dt
		if s.x < cam_x - 30.0 or s.x > cam_x + MsD.VIEW_W + 30.0 or s.t > 4.0:
			s.dead = true
			continue
		if s.foe:
			if hero.inv <= 0.0 and Rect2(s.x - 6.0, s.y - 6.0, 12.0, 12.0).intersects(hero_body()):
				_hurt_hero(float(s.dmg), 1 if s.vx > 0.0 else -1)
				s.dead = true
		else:
			for e in enemies:
				if e.dead or e.get("dying", false):
					continue
				if s.hit.has(e.id):
					continue
				if Rect2(s.x - 8.0, s.y - 8.0, 16.0, 16.0).intersects(body(e)):
					s.hit.append(e.id)
					_damage(e, float(s.dmg), String(s.kind), 1 if s.vx > 0.0 else -1)
					stop = MsD.HIT_STOP
	var i := 0
	while i < shots.size():
		if shots[i].dead:
			shots.remove_at(i)   # 탄은 한 화면에 몇 개뿐이고 격자 판정을 안 쓴다
		else:
			i += 1


## 장풍 — 동작 표의 shot 을 그 시각에 한 번 쏜다.
func _fire_wave() -> void:
	var sh: Dictionary = MsD.MOVES.wave.shot
	shots.append({x = hero.x + hero.face * 14.0, y = hero.y - 22.0, vx = hero.face * float(sh.speed), dmg = float(sh.dmg),
			kind = String(sh.kind), foe = false, t = 0.0, dead = false, hit = []})
	ev.append({snd = "orb"})


func _separate() -> void:
	# 적끼리 겹치면 살짝 민다(같은 자리에 겹쳐 서면 한 마리처럼 보인다)
	for i in enemies.size():
		var a: Dictionary = enemies[i]
		if a.dead or a.st == "air":
			continue
		for j in range(i + 1, enemies.size()):
			var b: Dictionary = enemies[j]
			if b.dead or b.st == "air":
				continue
			var d: float = b.x - a.x
			if absf(d) < 10.0 and absf(a.y - b.y) < 16.0:
				var p := (10.0 - absf(d)) * 0.5 * (1.0 if d >= 0.0 else -1.0)
				a.x -= p
				b.x += p


func _sweep() -> void:
	var i := 0
	while i < enemies.size():
		if enemies[i].dead:
			enemies.remove_at(i)   # 프레임 끝에서만 뺀다 — 판정 도중에는 dead 표시만
		else:
			i += 1


func alive() -> int:
	var n := 0
	for e in enemies:
		if not e.dead and not e.get("dying", false):
			n += 1
	return n

# ==================== 구간 진행 · 카메라 ====================


func _progress(dt: float) -> void:
	# 장풍 발사 시각
	if hero.st == "wave" and hero.t >= float(MsD.MOVES.wave.shot.at) and not hero.get("fired", false):
		hero.fired = true
		_fire_wave()
	if hero.st != "wave":
		hero.fired = false
	var secs: Array = sections()
	if boss_on:
		if boss_wait > 0.0:
			boss_wait -= dt
			if boss_wait <= 0.0:
				_spawn_boss()
			return
		if alive() == 0 and enemies.is_empty():
			if stage >= MsD.STAGES.size() - 1:
				state = "win"
			else:
				state = "clear"
			ev.append({snd = "clear"})
		return
	if go:
		return   # 오른쪽 끝으로 걸어 나가면 _step_hero 가 trans 를 건다
	var waves: Array = secs[sec]
	wave_t -= dt
	if wave < waves.size():
		if alive() <= MsD.WAVE_NEXT_AT and wave_t <= 0.0:
			var w: Array = waves[wave]
			for k in int(w[1]):
				if alive() < MsD.MAX_ON_SCREEN:
					_spawn(String(w[0]), -1 if k % 2 == 1 else 1)
			wave += 1
			wave_t = MsD.WAVE_GAP
	elif alive() == 0 and enemies.is_empty():
		go = true
		ev.append({snd = "go"})


## 다음 방 — 마지막 방 다음은 보스 방.
func _next_room() -> void:
	sec += 1
	if sec < sections().size():
		_enter_room(MsD.room_of(stage, sec))
	else:
		_enter_room(MsD.BOSS_ROOM)
		go = false
		boss_on = true
		boss_wait = 0.8


# ==================== 무인 주행(검사 · 시연) ====================

var _bot_t := 0.0


## 봇 한 걸음 — 가장 가까운 적에게 붙어 3타 · 띄우기 · 공중 연타 · 기술. 검사와 --ms-auto 가 같이 쓴다.
func bot(dt: float) -> void:
	_bot_t -= dt
	hold.L = false
	hold.R = false
	hold.U = false
	if state != "play":
		return
	var tgt: Dictionary = {}
	var best := 1e9
	for e in enemies:
		if e.dead or e.get("dying", false):
			continue
		var d := absf(float(e.x) - hero.x)
		if d < best:
			best = d
			tgt = e
	if tgt.is_empty():
		hold.R = true
		return
	var dx: float = tgt.x - hero.x
	if absf(dx) > 20.0:
		hold.R = dx > 0.0
		hold.L = dx < 0.0
	elif signf(dx) != float(hero.face) and _free_to_act():
		hero.face = 1 if dx > 0.0 else -1
	if _bot_t > 0.0:
		return
	_bot_t = 0.11
	hold.D = false
	# 높낮이가 다르면 — 위에 있으면 뛰어오르고, 아래에 있으면 발판에서 내려선다
	var dy: float = float(tgt.y) - hero.y
	if absf(dx) < 60.0 and on_ground(hero) and tgt.st != "air":
		if dy < -24.0 and tgt.hover <= 0.0:
			key_jump()
			return
		if dy > 24.0 and int(hero.plat) >= 0:
			hold.D = true
			key_jump()
			return
	if absf(dx) <= 30.0:
		var near := 0
		for e in enemies:
			if not e.dead and absf(float(e.x) - hero.x) < 60.0:
				near += 1
		if near >= 3 and hero.mp >= 35.0 and on_ground(hero):
			key_skill("stomp")
		elif tgt.st == "air" and not tgt.get("boss", false):
			hold.U = true
			key_atk()
		else:
			key_atk()
	elif absf(dx) < 120.0 and hero.mp >= 40.0 and on_ground(hero):
		key_skill("wave")
