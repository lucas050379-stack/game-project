class_name TgGame
extends RefCounted

## 떡 하나 주면 안 잡아먹지 규칙 — 물리 · 길 만들기 · 부딪힘 · 체력 · 호랑이 기운 · 봇. **그리기를 모른다**(ADR-0004).
## main 은 `step(dt)` 를 부르고 `events` 를 가져가 연출로 바꾼다. 길은 시드로 정해져 같은 시드면 같은 길이다.

var round_i := 0
var rng := RandomNumberGenerator.new()
var dist := 0.0            ## 달린 거리(px) = 호랑이의 세상 x
var speed := 0.0
var length := 0.0
var fox_y := 0.0           ## 바닥 위 높이(0 = 바닥)
var vy := 0.0
var jumps := 0             ## 공중에서 쓴 점프 수(2단 점프는 1까지)
var sliding := false
var slide_t := 0.0
var slide_held := false
var oil := TgD.OIL_MAX
var inv_t := 0.0           ## 무적 남은 시간(맞은 뒤 · 질주)
var slow_t := 0.0
var chase := 0.35           ## 곶감 귀신이 얼마나 가까운가(밤 라운드, 0~1) — 부딪힐 때마다 가까워지고 1 이면 물린다. 안 부딪히고 달리면 멀어진다
var embers := 0
var embers_all := 0        ## 길에 놓인 떡 수(별 조건의 분모)
var lanterns := 0
var hits := 0
var gauge := 0             ## 모은 떡 수 — need 이면 호랑이 기운 가능(질주 중에 먹은 떡은 안 센다)
var need := TgD.AWAKEN_N   ## 가득 차는 떡 수 — 빠른 라운드일수록 많다(빠르면 떡도 빨리 먹혀 판 내내 쓸 수 있었다, 사용자 지적 11-10). 판마다 두 번쯤
var cine_t := -1.0         ## 호랑이 기운 컷인 남은 시간(> 0 이면 세상이 멈춘다)
var dash_t := 0.0
var items: Array = []      ## {kind = "low" | "high" | "pit" | "ember" | "kkochi", x, y, w, h, gone}
var spawned_to := 0.0
var events: Array = []     ## 화면이 가져가는 사건 {kind, x?, y?}
var over := false
var win := false
var time := 0.0
var run_phase := 0.0       ## 다리 움직임 위상(속도에 비례)
var magnet_t := 0.0        ## 꿀단지 남은 시간
var giant_t := 0.0         ## 산삼 남은 시간
var fly_t := 0.0           ## 하늘 보너스 남은 시간(> 0 이면 날고 있다)
var fly_held := false
var fly_x0 := 0.0          ## 떡 물결이 시작하는 자리
var fly_len := 0.0
var rope_done := false
var coins := 0             ## 이번 판에 주운 엽전
var up := [0, 0, 0, 0]     ## 강화 단계(TgD.UPGRADES 순서) — 든든한 배 · 찰떡 · 큰 꿀단지 · 산군의 기운


func _init(r: int, seed_: int = -1, upgrades: Array = []) -> void:
	for i in mini(4, upgrades.size()):
		up[i] = int(upgrades[i])
	round_i = clampi(r, 0, TgD.ROUNDS.size() - 1)
	rng.seed = seed_ if seed_ >= 0 else randi()
	length = float(row()[2])
	speed = float(row()[3])
	need = int(round(TgD.AWAKEN_N * (float(row()[3]) + float(row()[4])) * 0.5 / 300.0))
	spawned_to = 700.0   # 처음 몇 백 px 는 비어 있다 — 손을 올릴 시간


func row() -> Array:
	return TgD.ROUNDS[round_i]


func boss() -> bool:
	return int(row()[1]) == 3


func busy() -> bool:
	return cine_t > 0.0


func dashing() -> bool:
	return dash_t > 0.0


func on_ground() -> bool:
	return fox_y <= _floor(fox_y) and vy <= 0.0


## 발밑 바닥의 높이 — 윗길(plank) 위에 있으면 그 높이, 아니면 땅(0). prev 는 이번 걸음 전의 높이: 위에서 내려올 때만 올라선다(밑에서는 뚫고 지나간다).
func _floor(prev: float) -> float:
	for it: Dictionary in items:
		if it.kind == "plank" and absf(dist - float(it.x)) < float(it.w) * 0.5 and prev >= float(it.y) - 0.5:
			return float(it.y)
	return 0.0


## 그 자리 땅의 높이(언덕) — **보이는 것만**이다. 규칙의 높이(fox_y · 장애물 · 떡)는 모두 그 자리 땅에서 잰 값이라 판정은 평지와 같다.
func ground_h(x: float) -> float:
	var env := clampf((x - 500.0) / 400.0, 0.0, 1.0) * clampf((length - 300.0 - x) / 400.0, 0.0, 1.0)
	var ph := round_i * 1.7
	var hill := TgD.HILL_H * maxf(0.0, sin(x / 520.0 + ph) * 0.65 + sin(x / 233.0 + ph * 2.3) * 0.35)
	# 산 — 드문드문(길의 넷에 하나쯤) 크게 솟는다. 가장 가파른 곳이 스무 도 안팎
	var mk := maxf(0.0, sin(x / 1400.0 + ph * 0.7) - 0.3) / 0.7
	return env * (hill + float(TgD.MOUNT_H[int(row()[1])]) * mk * mk)


func giant() -> bool:
	return giant_t > 0.0


func flying() -> bool:
	return fly_t > 0.0


func fox_h() -> float:
	return (TgD.SLIDE_H if sliding else TgD.FOX_H) * (TgD.GIANT_K if giant() else 1.0)


## 호랑이 몸통(세상 좌표, y 는 위로) — 부딪힘과 그리기가 같이 본다.
func fox_rect() -> Rect2:
	var w := TgD.FOX_W * (TgD.GIANT_K if giant() else 1.0)
	return Rect2(dist - w * 0.5, fox_y, w, fox_h())


func progress() -> float:
	return clampf(dist / length, 0.0, 1.0)


func stars() -> int:
	if not win:
		return 0
	var s := 1
	if embers_all == 0 or float(embers) >= float(embers_all) * 0.7:
		s += 1
	if hits == 0:
		s += 1
	return s


func score() -> int:
	return int(dist / 10.0) + embers * 10 + coins * TgD.COIN_SCORE + lanterns * TgD.SCORE_LANTERN + stars() * TgD.SCORE_STAR

# ==================== 입력 ====================


func jump() -> void:
	if busy() or over or flying():
		return
	if on_ground() or jumps < 1:
		if not on_ground():
			jumps += 1
		vy = TgD.JUMP_V
		fox_y = maxf(fox_y, 0.001)
		sliding = false
		events.append({kind = "jump", second = jumps > 0, x = dist})


## 슬라이드 키 — 누르고 있는 동안 true. 땅에서만 시작하고, 떼도 최소 시간은 유지한다.
func slide(held: bool) -> void:
	slide_held = held
	if held and not busy() and not over and on_ground() and not sliding:
		sliding = true
		slide_t = 0.0
		events.append({kind = "slide", x = dist})


func awaken() -> bool:
	if busy() or over or dashing() or flying() or gauge < need:
		return false
	gauge = 0
	cine_t = TgD.CINE_T
	events.append({kind = "awaken"})
	return true


## 컷인을 눌러서 넘긴다.
func skip_cine() -> void:
	if cine_t > 0.0:
		_start_dash()


func _start_dash() -> void:
	cine_t = -1.0
	dash_t = TgD.DASH_T + 0.5 * up[3]
	inv_t = maxf(inv_t, dash_t)
	events.append({kind = "dash"})

# ==================== 진행 ====================


func step(dt: float) -> void:
	if over:
		return
	if cine_t > 0.0:   # 컷인 — 세상이 멈춘다
		cine_t -= dt
		if cine_t <= 0.0:
			_start_dash()
		return
	time += dt
	var r := row()
	var base := lerpf(float(r[3]), float(r[4]), progress())
	if dash_t > 0.0:
		dash_t -= dt
		base *= TgD.DASH_SPEED
		if dash_t <= 0.0 and (not on_ground() or _in_arc()):
			dash_t = 0.001   # 공중이거나 점프 궤적 구간 안이면 거기를 벗어날 때까지 이어진다 — 중간에 끊기면 궤적 위의 떡을 놓친다
			inv_t = maxf(inv_t, 0.05)
		if dash_t <= 0.0:
			events.append({kind = "dash_end", x = dist})
	if slow_t > 0.0:
		slow_t -= dt
		base *= 0.6
	speed = base
	if boss():
		chase = clampf(chase - (0.3 if dashing() else 0.025) * dt, 0.15, 1.0)
	inv_t = maxf(0.0, inv_t - dt)
	magnet_t = maxf(0.0, magnet_t - dt)
	giant_t = maxf(0.0, giant_t - dt)
	dist += speed * dt
	run_phase += speed * dt / 60.0
	oil -= float(r[5]) * (1.0 - 0.06 * up[0]) * dt
	if fly_t > 0.0:   # 하늘 보너스 — 누르면 오르고 떼면 내려간다
		# 물결은 자리(x)에 놓여 있으니 끝도 자리로 잰다 — 질주로 빨라지면 오르내림도 그만큼 빨라진다
		var fk := speed / maxf(1.0, speed_at(fly_x0))
		fox_y = clampf(fox_y + (TgD.FLY_V if fly_held else -TgD.FLY_V) * fk * dt, 0.0, TgD.FLY_TOP)
		vy = 0.0
		sliding = false
		fly_t = maxf(0.0, (fly_x0 + fly_len - dist) / maxf(1.0, speed))
		if fly_t <= 0.0:
			events.append({kind = "fly_end", x = dist})
	# 점프
	elif fox_y > _floor(fox_y) or vy > 0.0:
		var prev := fox_y
		vy -= TgD.GRAVITY * dt
		fox_y += vy * dt
		var fl := _floor(prev) if vy <= 0.0 else 0.0
		if fox_y <= fl:
			fox_y = fl
			vy = 0.0
			jumps = 0
			events.append({kind = "land", x = dist})
			if slide_held:
				sliding = true
				slide_t = 0.0
	if sliding:
		slide_t += dt
		if not slide_held and slide_t >= TgD.SLIDE_MIN:
			sliding = false
	_spawn()
	_collide()
	items = items.filter(func(it): return float(it.x) + float(it.w) * 0.5 > dist - 300.0)
	if oil <= 0.0:
		oil = 0.0
		over = true
		win = false
		events.append({kind = "fail", x = dist})
	elif dist >= length:
		dist = length
		over = true
		win = true
		events.append({kind = "finish", x = dist})


## 그 자리에 닿을 때의 기본 속도(가속만 — 맞아서 느려지거나 질주하는 것은 뺀다). 떡을 점프 궤적에 놓을 때 쓴다.
func speed_at(x: float) -> float:
	return lerpf(float(row()[3]), float(row()[4]), clampf(x / length, 0.0, 1.0))


## 점프 한 번이 날아가는 거리(그 자리의 속도로).
func jump_len(x: float) -> float:
	return speed_at(x) * 2.0 * TgD.JUMP_V / TgD.GRAVITY


## 길 만들기 — 장애물 하나 + 떡. **완벽하게 달리면 떡을 전부 먹을 수 있게 놓는다**(사용자 요청 11-10):
## 넘는 장애물(바위 · 그루터기 · 함정) 위에는 꼭대기가 장애물 한가운데인 점프 궤적을 따라, 숙이는 장애물 밑에는 낮게,
## 그 사이 땅에는 착지한 뒤부터. 장애물 사이는 점프 한 번 거리보다 넓다(앞 점프가 끝나야 다음 점프를 뛸 수 있다).
func _spawn() -> void:
	var ahead := maxf(TgD.BOSS_AHEAD, speed * 1.0) if boss() else TgD.SPAWN_AHEAD
	while spawned_to < dist + ahead:
		var r := row()
		var sp := speed_at(spawned_to)
		var jl := jump_len(spawned_to)
		var roll := rng.randf()
		# 뒤 라운드일수록 어려운 것이 섞인다 — 2단 점프(높은 장애물) · 숙였다 바로 점프(묶음)
		var p_tall := clampf((round_i - 1) * 0.02, 0.0, 0.16)
		var p_combo := clampf((round_i - 2) * 0.02, 0.0, 0.16)
		# 쌍둥이(착지하자마자 또 뛴다 — 칼타이밍 좁은 착지) · 불쑥(가까이 가야 튀어나온다/떨어진다) · 길잡이 떡이 없는 장애물
		var p_twin := clampf((round_i - 2) * 0.02, 0.0, 0.14)
		var p_plank := 0.10 if round_i >= 1 else 0.0   # 윗길 · 아랫길 — 2라운드부터
		var plen := sp * 3.2
		var late := rng.randf() < clampf((round_i - 1) * 0.04, 0.0, 0.5)
		var bare := rng.randf() < clampf((round_i - 3) * 0.03, 0.0, 0.3)
		var kind := "kkochi"
		if roll < p_tall:
			kind = "tall"
		elif roll < p_tall + p_combo:
			kind = "combo"
		elif roll < p_tall + p_combo + p_twin:
			kind = "twin"
		elif roll < p_tall + p_combo + p_twin + p_plank:
			kind = "plank"
		else:
			var q := (roll - p_tall - p_combo - p_twin - p_plank) / (1.0 - p_tall - p_combo - p_twin - p_plank)
			kind = "low" if q < 0.40 else ("high" if q < 0.68 else ("pit" if q < 0.84 else ("thing" if q < 0.93 else "kkochi")))
		# 앞(도약 자리까지) · 뒤(착지까지)에 비워 둘 거리
		var pre := jl * 0.5
		var post := jl * 0.5 + 30.0
		if kind == "tall":
			pre = sp * air2_peak()
			post = sp * (air2_total() - air2_peak()) + 30.0
		elif kind == "high" or kind == "thing":
			pre = 0.0
			post = 60.0
		elif kind == "combo":
			pre = 0.0
			post = jl + 100.0
		elif kind == "twin":
			post = jl * 1.5 + 80.0
		elif kind == "plank":
			pre = 0.0
			post = plen + 60.0
		var x := spawned_to + maxf(pre + 110.0, sp * rng.randf_range(0.9, 1.6) * (1.6 - float(r[6])))
		if x + post > length - 500.0:   # 결승선 앞은 비운다
			spawned_to = length + 2000.0
			return
		if not rope_done and x > length * 0.45 and _rope(x):
			continue
		match kind:
			"low":
				items.append({kind = "low", x = x, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, gone = false, v = rng.randi_range(0, 1), late = late})
				if not bare:
					_arc(x, 5)
			"twin":   # 넘고 내려앉자마자 또 하나 — 두 번째는 떡이 길을 알려 준다
				items.append({kind = "low", x = x, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, gone = false, v = rng.randi_range(0, 1)})
				_arc(x, 5)
				var x2 := x + jl + 50.0
				items.append({kind = "low", x = x2, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, gone = false, v = rng.randi_range(0, 1)})
				_arc(x2, 5)
			"plank":   # 갈랫길 — 윗길(나무 다리, 한 번 뛰면 오른다)은 엽전과 끝의 보따리뿐이라 안전하고, 아랫길은 떡이 있지만 다리 밑에 매달린 것 둘을 숙여 지나야 한다.
				# 완벽한 길은 아랫길(떡을 다 먹는다). 다리 밑에서 뛰면 곧 윗길로 올라서므로 아래 장애물은 숙이는 것만 둔다(짧게 — 다리 밑에 들어가게)
				items.append({kind = "plank", x = x + plen * 0.5, y = TgD.PLANK_Y, w = plen, h = 22.0, gone = false, v = 0})
				var lane := rng.randi_range(0, 4)   # 2 = 윗길에만(엽전 줄), 3 = 아랫길에만(떡 줄), 나머지 = 두 길 다 — 때로는 한쪽만 줄지어 나온다(사용자 요청 11-10)
				var obs := []   # [자리, 낮은 것인가]
				for k in 2:
					var ox := x + plen * (0.3 + 0.4 * k)
					obs.append([ox, false])
					_high(ox)
					items[items.size() - 4].h = TgD.PLANK_Y - 30.0 - TgD.HIGH_Y
				for i in int((plen - 110.0) / 60.0):
					var px := x + 40.0 + i * 60.0
					if lane != 3:
						items.append({kind = "coin", x = px, y = TgD.PLANK_Y + TgD.FOX_H * 0.45, w = 0.0, h = 0.0, gone = false, v = 0})
					var clear := true   # 장애물 둘레(뛰는 궤적 · 숙이는 자리)에는 땅의 떡을 안 놓는다
					for o: Array in obs:
						if absf(px - float(o[0])) < (jl * 0.5 + 50.0 if o[1] else 90.0):
							clear = false
					if clear and lane != 2:
						_tteok(px, TgD.FOX_H * 0.45)
				if lane != 3:
					items.append({kind = "box", x = x + plen - 50.0, y = TgD.PLANK_Y + TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})
			"pit":
				items.append({kind = "pit", x = x, y = -200.0, w = TgD.PIT_W, h = 200.0, gone = false, v = 0})
				_arc(x, 5)
			"tall":   # 한 번 뛰어서는 못 넘는다 — 첫 점프 꼭대기에서 한 번 더
				items.append({kind = "tall", x = x, y = 0.0, w = TgD.TALL_W, h = TgD.TALL_H, gone = false, v = 0})
				_arc2(x, 8)
			"high":
				_high(x)
				items[items.size() - 4].late = late   # _high 는 장애물 다음에 떡 셋을 놓는다
			"combo":  # 숙여서 지나자마자 바로 뛴다
				_high(x)
				var lx := x + jl * 0.5 + 70.0
				items.append({kind = "low", x = lx, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, gone = false, v = rng.randi_range(0, 1)})
				_arc(lx, 5)
			"thing":  # 길 위의 물건 — 달리다 그냥 닿는다. 넷 가운데 하나는 보따리(뭐가 나올지 모른다)
				items.append({kind = ["honey", "sansam", "club", "box"][rng.randi_range(0, 3)], x = x, y = TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})
			_:        # 꿀떡 꼬치 — 점프 꼭대기에서 닿는다
				var top := TgD.JUMP_V * TgD.JUMP_V / (2.0 * TgD.GRAVITY)
				items.append({kind = "kkochi", x = x, y = top + TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})
		var tail := post
		if rng.randf() < float(r[7]):
			var n := rng.randi_range(3, 6)
			var coin := rng.randf() < 0.3   # 떡 줄 셋에 하나는 엽전 줄
			for i in n:
				if coin:
					items.append({kind = "coin", x = x + tail + 20.0 + i * 40.0, y = TgD.FOX_H * 0.45, w = 0.0, h = 0.0, gone = false, v = 0})
				else:
					_tteok(x + tail + 20.0 + i * 40.0, TgD.FOX_H * 0.45)
			tail += 20.0 + n * 40.0
		spawned_to = x + tail


## 숙여서 지나가는 장애물 + 그 밑의 떡 셋.
func _high(x: float) -> void:
	items.append({kind = "high", x = x, y = TgD.HIGH_Y, w = TgD.HIGH_W, h = TgD.HIGH_H, gone = false, v = rng.randi_range(0, 1)})
	for i in 3:
		_tteok(x + (i - 1) * 40.0, TgD.SLIDE_H * 0.5)


## 2단 점프(첫 점프 꼭대기에서 한 번 더) — 가장 높은 곳까지 걸리는 시간 · 땅에 닿기까지의 시간 · 그때그때의 높이.
func air2_peak() -> float:
	return 2.0 * TgD.JUMP_V / TgD.GRAVITY


func air2_total() -> float:
	var h1 := TgD.JUMP_V * TgD.JUMP_V / (2.0 * TgD.GRAVITY)
	return TgD.JUMP_V / TgD.GRAVITY + (TgD.JUMP_V + sqrt(TgD.JUMP_V * TgD.JUMP_V + 2.0 * TgD.GRAVITY * h1)) / TgD.GRAVITY


func air2_y(tt: float) -> float:
	var t1 := TgD.JUMP_V / TgD.GRAVITY
	if tt <= t1:
		return TgD.JUMP_V * tt - 0.5 * TgD.GRAVITY * tt * tt
	var u := tt - t1
	return TgD.JUMP_V * TgD.JUMP_V / (2.0 * TgD.GRAVITY) + TgD.JUMP_V * u - 0.5 * TgD.GRAVITY * u * u


## 가장 높은 곳이 x 인 2단 점프 궤적 위에 떡 n 개.
func _arc2(x: float, n: int) -> void:
	var sp := speed_at(x)
	var total := air2_total()
	for i in n:
		var tt := total * (0.1 + 0.8 * i / float(n - 1))
		_tteok(x + (tt - air2_peak()) * sp, maxf(air2_y(tt), 0.0) + TgD.FOX_H * 0.5)


## 지금 넘는 장애물의 점프 궤적 구간(도약 자리 ~ 착지 자리) 안에 있나.
## 부서진 장애물도 센다 — 질주로 부수고 그 자리에서 질주가 끝나면 궤적 위에 남은 떡을 못 먹었다(11-10).
func _in_arc() -> bool:
	for it: Dictionary in items:
		if it.kind in ["low", "pit", "kkochi", "tall"] and absf(float(it.x) - dist) < (speed_at(float(it.x)) * air2_peak() if it.kind == "tall" else jump_len(float(it.x)) * 0.5) * TgD.DASH_SPEED + 40.0:
			return true
	return false


## 동아줄 — 잡으면 하늘 보너스. 뒤로 장애물 없는 구간에 떡이 물결로 놓인다(땅에서 시작해 땅에서 끝난다 — 완벽하게 날면 다 먹는다).
func _rope(x: float) -> bool:
	var sp := speed_at(x)
	var total := TgD.FLY_PERIOD * TgD.FLY_WAVES
	var span := sp * total * 1.12   # 속도가 오르는 만큼 여유
	if x + span + 900.0 > length:
		return false
	rope_done = true
	items.append({kind = "rope", x = x, y = TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0, span = span})
	var n := int(total / 0.13)
	for i in n:
		var tt := 0.25 + (total - 0.35) * i / float(n - 1)
		var yc := TgD.FOX_H * 0.5 + TgD.FLY_AMP * (1.0 - cos(TAU * tt / TgD.FLY_PERIOD))
		_tteok(x + sp * tt, yc)
	spawned_to = x + span + jump_len(x) * 0.5
	return true


## 하늘 보너스 중 지금 자리의 떡 물결 높이(몸 한가운데) — 봇과 화면 안내가 같이 본다.
func fly_target() -> float:
	var tt := (dist + speed * 0.05 - fly_x0) / maxf(1.0, speed_at(fly_x0))
	return TgD.FOX_H * 0.5 + TgD.FLY_AMP * (1.0 - cos(TAU * tt / TgD.FLY_PERIOD))


func _tteok(x: float, y: float) -> void:
	items.append({kind = "ember", x = x, y = y, w = 0.0, h = 0.0, gone = false, v = 0})
	embers_all += 1


## 꼭대기가 x 인 점프 궤적 위에 떡 n 개(몸 한가운데 높이).
func _arc(x: float, n: int) -> void:
	var sp := speed_at(x)
	var total := 2.0 * TgD.JUMP_V / TgD.GRAVITY
	for i in n:
		var tt := total * (0.2 + 0.6 * i / float(n - 1))
		var y := TgD.JUMP_V * tt - 0.5 * TgD.GRAVITY * tt * tt
		_tteok(x + (tt - total * 0.5) * sp, y + TgD.FOX_H * 0.5)


func _collide() -> void:
	var fr := fox_rect()
	var fc := Vector2(dist, fox_y + fox_h() * 0.5)
	for it: Dictionary in items:
		if it.gone:
			continue
		match String(it.kind):
			"ember", "kkochi":
				var ember: bool = it.kind == "ember"
				var c := Vector2(it.x, it.y)
				var rad := 18.0 if ember else 28.0
				# 질주 중에는 위아래를 가리지 않고 지나치는 떡이 전부 끌려온다(2단 점프 중에 땅의 떡을 놓쳤다)
				var near := (dashing() and absf(c.x - fc.x) < TgD.DASH_PULL * 0.6) or (magnet_t > 0.0 and c.distance_to(fc) < TgD.MAGNET_R)
				if near or _circle_hits(fr, c, rad):
					it.gone = true
					if ember:
						embers += 1
						oil += TgD.OIL_EMBER * (1.0 + 0.15 * up[1])
						var was := gauge
						if not dashing():
							gauge = mini(gauge + 1, need)
						events.append({kind = "ember", x = it.x, y = it.y, full = gauge >= need and was < need})
					else:
						lanterns += 1
						oil += TgD.OIL_LANTERN
						events.append({kind = "kkochi", x = it.x, y = it.y})
					oil = minf(oil, TgD.OIL_MAX)
			"low", "high", "tall":
				var orc := Rect2(it.x - it.w * 0.5, it.y, it.w, it.h)
				if fr.intersects(orc):
					if dashing() or giant():
						it.gone = true
						events.append({kind = "smash", x = it.x, y = it.y + it.h * 0.5})
					elif inv_t <= 0.0:
						_hurt(TgD.OIL_HIT, it)
			"coin":
				if _circle_hits(fr, Vector2(it.x, it.y), 18.0) or (dashing() and absf(float(it.x) - fc.x) < TgD.DASH_PULL * 0.6) \
						or (magnet_t > 0.0 and Vector2(it.x, it.y).distance_to(fc) < TgD.MAGNET_R):
					it.gone = true
					coins += 1
					events.append({kind = "coin", x = it.x, y = it.y})
			"honey", "sansam", "club", "rope", "box":
				if _circle_hits(fr, Vector2(it.x, it.y), 30.0):
					it.gone = true
					_take(it)
			"pit":
				if on_ground() and not dashing() and not giant() and not flying() and absf(dist - it.x) < it.w * 0.5 - 12.0:
					if inv_t <= 0.0:
						_hurt(TgD.OIL_PIT, it)
					dist = it.x + it.w * 0.5 + 14.0   # 끌어올려져 구덩이 건너편으로
					events.append({kind = "pit", x = it.x})


## 길 위의 물건을 먹었다.
func _take(it: Dictionary) -> void:
	var kind := String(it.kind)
	if kind == "box":   # 보따리 — 엽전 한 줌이거나 물건 하나
		var pick := rng.randi_range(0, 3)
		if pick == 0:
			coins += 8
			events.append({kind = "item", item = "box", x = it.x, y = it.y})
			return
		kind = ["honey", "sansam", "club"][pick - 1]
	match kind:
		"honey":
			magnet_t = TgD.MAGNET_T + 1.0 * up[2]
		"sansam":
			giant_t = TgD.GIANT_T
		"rope":
			fly_x0 = float(it.x)
			fly_len = speed_at(fly_x0) * TgD.FLY_PERIOD * TgD.FLY_WAVES
			fly_t = TgD.FLY_PERIOD * TgD.FLY_WAVES
			fly_held = false
		"club":   # 화면의 장애물이 전부 떡으로 바뀌고, 화면의 떡이 전부 날아온다(놓치는 떡이 생기지 않게 한꺼번에)
			var got := []
			for o: Dictionary in items:
				if o.gone or float(o.x) < dist - 200.0 or float(o.x) > dist + 1500.0:
					continue
				if (o.kind == "low" or o.kind == "high" or o.kind == "tall") and float(o.x) < dist + 1000.0:
					o.gone = true
					embers_all += 1
				elif o.kind != "ember":
					continue
				o.gone = true
				embers += 1
				oil = minf(oil + TgD.OIL_EMBER, TgD.OIL_MAX)
				gauge = mini(gauge + 1, need)
				got.append(Vector2(o.x, float(o.y) + float(o.h) * 0.5))
			events.append({kind = "club", x = it.x, y = it.y, got = got})
			return
	events.append({kind = "item", item = kind, x = it.x, y = it.y})


func _circle_hits(r: Rect2, c: Vector2, rad: float) -> bool:
	var p := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return p.distance_to(c) <= rad


func _hurt(n: float, it: Dictionary) -> void:
	oil -= n
	hits += 1
	inv_t = TgD.HIT_INV
	slow_t = TgD.HIT_SLOW
	events.append({kind = "hit", x = it.x, y = float(it.y) + float(it.h) * 0.5})
	if boss():   # 비틀거리는 사이 귀신이 다가온다 — 따라잡히면 물린다
		chase += 0.3
		if chase >= 1.0:
			chase = 0.5
			oil -= TgD.OIL_BITE
			events.append({kind = "bite", x = dist})

# ==================== 봇 ====================


## 봇 — 넘는 장애물은 꼭대기가 한가운데에 오게 뛰고(떡이 그 궤적에 놓여 있다), 숙이는 장애물은 미리 숙이고, 게이지가 차면 호랑이 기운.
## late: 점프를 몇 초 늦게 뛰나(0 이면 완벽). miss: 장애물을 못 보고 지나칠 확률 — 느린 사람 흉내.
func bot(late: float = 0.0, miss: float = 0.0) -> void:
	if over or busy():
		return
	if flying():
		fly_held = fox_y + TgD.FOX_H * 0.5 < fly_target()
		return
	if gauge >= need and awaken():   # 질주 중에는 못 쓴다 — 그때는 아래로 내려가 계속 뛴다
		return
	var need_slide := false
	var half := TgD.JUMP_V / TgD.GRAVITY   # 꼭대기까지 걸리는 시간
	for it: Dictionary in items:
		if it.gone or it.kind == "ember" or it.kind == "coin":
			continue
		if not it.has("seen"):
			it.seen = rng.randf() >= miss   # 처음 본 순간에 "볼지" 정한다 — 매 프레임 굴리면 결국 다 본다
		if not bool(it.seen):
			continue
		var d := float(it.x) - dist
		match String(it.kind):
			"high":
				if d < speed * 0.3 + float(it.w) and d > -float(it.w) - TgD.FOX_W - 60.0:
					need_slide = true
			"low", "pit", "kkochi":
				if d > 0.0 and d <= speed * (half - late) and on_ground() and not it.has("jumped"):
					it.jumped = true
					slide(false)
					jump()
					return
			"tall":
				if d > 0.0 and d <= speed * (air2_peak() - late) and on_ground() and not it.has("jumped"):
					it.jumped = true
					slide(false)
					jump()
					return
				if it.has("jumped") and not it.has("jumped2") and not on_ground() and vy <= 0.0:
					it.jumped2 = true   # 첫 점프 꼭대기에서 한 번 더
					jump()
					return
	slide(need_slide)
