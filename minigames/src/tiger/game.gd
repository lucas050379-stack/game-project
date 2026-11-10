class_name TgGame
extends RefCounted

## 떡 하나 주면 안 잡아먹지 규칙 — 물리 · 길 만들기 · 부딪힘 · 체력 · 호랑이 기운 · 봇. **그리기를 모른다**(ADR-0004).
## main 은 `step(dt)` 를 부르고 `events` 를 가져가 연출로 바꾼다. 길은 시드로 정해져 같은 시드면 같은 길이다.
##
## **이어 달리기**(11-10, 기획서 "이어 달리기 개편"): 구간(TgD.ZONES)을 한 번에 이어 달리고 배가 0 이면 끝난다. 결승선이 없다.
## 구간 경계는 거리로 정해진다(`zone_at`). 길을 만드는 자리(`spawned_to`)는 호랑이보다 앞이라 늘 그 자리의 구간 값을 쓴다.

var zone0 := 0             ## 출발 구간(확인용 --tg-round 로만 바뀐다)
var zone := 0              ## 지금 구간(0 부터, 16 을 넘으면 13~16 을 되풀이 — `zone_row`)
var rng := RandomNumberGenerator.new()
var dist := 0.0            ## 달린 거리(px) = 호랑이의 세상 x
var speed := 0.0
var fox_y := 0.0           ## 바닥 위 높이(0 = 바닥)
var vy := 0.0
var jumps := 0             ## 공중에서 쓴 점프 수(2단 점프는 1까지)
var sliding := false
var slide_t := 0.0
var slide_held := false
var oil := TgD.OIL_MAX
var inv_t := 0.0           ## 무적 남은 시간(맞은 뒤 · 질주)
var slow_t := 0.0
var chase := 0.35          ## 곶감 귀신이 얼마나 가까운가(밤 구간, 0~1) — 부딪힐 때마다 가까워지고 1 이면 물린다
var embers := 0
var embers_all := 0        ## 길에 놓인 떡 수
var lanterns := 0          ## 먹은 꿀떡 꼬치
var lanterns_all := 0
var bigs := 0              ## 먹은 무지개떡
var hits := 0
var pts := 0               ## 먹은 것의 점수(겹치기 배수가 붙은 채로 쌓인다) — 점수 = 거리 / 10 + pts
var mult := 1              ## 지금 겹치기 배수(호랑이 기운 · 산삼 · 꿀단지 중 켜진 수, 하나 이하면 1)
var best_mult := 1
var gauge := 0             ## 모은 떡 수 — need 이면 호랑이 기운 가능(질주 중에 먹은 떡은 안 센다)
var need := TgD.AWAKEN_N
var cine_t := -1.0         ## 호랑이 기운 컷인 남은 시간(> 0 이면 세상이 멈춘다)
var dash_t := 0.0
var items: Array = []      ## {kind, x, y, w, h, gone, v, ...} — 아래 `_spawn` 설명
var spawned_to := 0.0
var events: Array = []     ## 화면이 가져가는 사건 {kind, x?, y?}
var over := false
var time := 0.0
var air_t := 0.0           ## 공중에 있던 시간(검산 — 뛰게 만드는 길인지)
var run_phase := 0.0       ## 다리 움직임 위상(속도에 비례)
var magnet_t := 0.0        ## 꿀단지 남은 시간
var giant_t := 0.0         ## 산삼 남은 시간
var fly_t := 0.0           ## 하늘 보너스 남은 시간(> 0 이면 날고 있다)
var fly_held := false
var fly_x0 := 0.0          ## 떡 물결이 시작하는 자리
var fly_len := 0.0
var rope_zones := {}       ## 동아줄을 이미 놓은 구간
var kkochi_next := 0.0     ## 다음 꼬치를 놓을 자리
var voids: Array = []      ## 허공 구간 [시작 x, 끝 x] — 그 사이는 땅이 없다(화면이 낭떠러지로 그린다) · 언덕을 평평하게 편다
var coins := 0             ## 이번 판에 주운 엽전
var up := [0, 0, 0, 0]     ## 강화 단계(TgD.UPGRADES 순서) — 든든한 배 · 찰떡 꼬치 · 큰 꿀단지 · 산군의 기운
static var force := ""     ## 확인용(--tg-force=moving 등) — 그 장애물 · 지형만 나온다(캡처 · 손으로 시험)
var _bot_double := false
var _bot_delay_x := 0.0      ## 봇 — 천장 아래 낭떠러지: 이 자리를 지나면 2단 점프   ## 봇 — 이번 점프 꼭대기에서 한 번 더 뛸까(높은 떡 · 장승)


func _init(start_zone: int = 0, seed_: int = -1, upgrades: Array = []) -> void:
	for i in mini(4, upgrades.size()):
		up[i] = int(upgrades[i])
	zone0 = maxi(0, start_zone)
	zone = zone0
	rng.seed = seed_ if seed_ >= 0 else randi()
	speed = float(row()[3])
	_set_need()
	spawned_to = 700.0   # 처음 몇 백 px 는 비어 있다 — 손을 올릴 시간
	kkochi_next = speed * TgD.KKOCHI_GAP


# ==================== 구간 ====================


## 구간 z 의 값 [이름, 테마, 길이, 속도, 배 소모/초, 밀도, 떡 모양 확률]. 16 구간 뒤로는 13~16 을 되풀이하며 빨라지고 배가 더 빨리 꺼진다.
static func zone_row(z: int) -> Array:
	var n := TgD.ZONES.size()
	if z < n:
		return TgD.ZONES[z]
	var base: Array = TgD.ZONES[n - 4 + (z - n) % 4]
	var extra := z - n + 1
	var r := base.duplicate()
	r[3] = minf(float(base[3]) + TgD.LOOP_SPEED * extra, TgD.SPEED_MAX)
	r[4] = float(base[4]) + TgD.LOOP_DRAIN * extra
	return r


## 거리 x 가 몇 번째 구간인가 · 그 구간이 시작하는 거리.
func zone_at(x: float) -> int:
	var z := zone0
	var x0 := 0.0
	while x >= x0 + float(zone_row(z)[2]):
		x0 += float(zone_row(z)[2])
		z += 1
	return z


func zone_start(z: int) -> float:
	var x0 := 0.0
	for k in range(zone0, z):
		x0 += float(zone_row(k)[2])
	return x0


func row() -> Array:
	return zone_row(zone)


func _set_need() -> void:
	# 가득 차는 떡 수는 구간 속도에 비례(빠르면 떡도 빨리 먹힌다). 떡이 예전보다 훨씬 많이 깔려 기준을 올렸다
	need = int(round(TgD.AWAKEN_N * 1.8 * float(row()[3]) / 300.0))


## 지금 구간 안에서 얼마나 왔나(0~1).
func progress() -> float:
	return clampf((dist - zone_start(zone)) / float(row()[2]), 0.0, 1.0)


func boss() -> bool:
	return int(row()[1]) == 3


func busy() -> bool:
	return cine_t > 0.0


func dashing() -> bool:
	return dash_t > 0.0


func on_ground() -> bool:
	return fox_y <= _floor(fox_y) and vy <= 0.0


## 발밑 바닥의 높이 — 발판(plank) 위에 있으면 그 높이, 아니면 땅(0). prev 는 이번 걸음 전의 높이: 위에서 내려올 때만 올라선다(밑에서는 뚫고 지나간다).
func _floor(prev: float) -> float:
	var best := 0.0
	for it: Dictionary in items:
		# 오르내리는 발판은 이번 걸음에 올라온 만큼 넉넉히 — 안 그러면 내려오던 호랑이가 올라오는 발판을 뚫고 떨어진다
		var tol := 6.0 if it.has("base") else 0.5
		if it.kind == "plank" and not it.has("falling") and absf(dist - float(it.x)) < float(it.w) * 0.5 and prev >= float(it.y) - tol:
			best = maxf(best, float(it.y))
	return best


## 그 자리 땅의 높이(언덕) — **보이는 것만**이다. 규칙의 높이(fox_y · 장애물 · 떡)는 모두 그 자리 땅에서 잰 값이라 판정은 평지와 같다.
func ground_h(x: float) -> float:
	for v: Array in voids:
		if x > float(v[0]) and x < float(v[1]):   # 허공 위 — 양쪽 벼랑 끝 높이를 곧게 잇는다(발판이 보이지 않는 언덕을 따라 오르내리지 않게)
			return lerpf(_ground_raw(float(v[0])), _ground_raw(float(v[1])), (x - float(v[0])) / (float(v[1]) - float(v[0])))
	return _ground_raw(x)


## 언덕 · 산 그대로의 땅 높이(허공을 모른다).
func _ground_raw(x: float) -> float:
	var env := clampf((x - 500.0) / 400.0, 0.0, 1.0)
	var z := zone_at(x)
	var ph := z * 1.7
	var hill := TgD.HILL_H * maxf(0.0, sin(x / 520.0 + ph) * 0.65 + sin(x / 233.0 + ph * 2.3) * 0.35)
	# 산 — 드문드문(길의 넷에 하나쯤) 크게 솟는다. 가장 가파른 곳이 스무 도 안팎
	var mk := maxf(0.0, sin(x / 1400.0 + ph * 0.7) - 0.3) / 0.7
	return env * (hill + float(TgD.MOUNT_H[int(zone_row(z)[1])]) * mk * mk)


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


func score() -> int:
	return int(dist / 10.0) + pts


## 지금 몇 m 왔나(화면 · 기록) — 100px 를 1m 로.
func meters() -> int:
	return int(dist / 100.0)

# ==================== 입력 ====================


func jump() -> void:
	if busy() or over or flying():
		return
	if on_ground() or jumps < 1:
		if not on_ground():
			jumps += 1
		vy = TgD.JUMP_V
		fox_y = maxf(fox_y, _floor(fox_y) + 0.001)
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
	var z := zone_at(dist)
	if z != zone:   # 구간이 바뀌었다 — 이름이 뜨고 배경이 바뀐다
		zone = z
		_set_need()
		gauge = mini(gauge, need)
		events.append({kind = "zone", zone = z})
	var r := row()
	var base := float(r[3])
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
	_update_mult()
	dist += speed * dt
	run_phase += speed * dt / 60.0
	oil -= float(r[4]) * (1.0 - 0.06 * up[0]) * dt
	if fly_t > 0.0:   # 하늘 보너스 — 누르면 오르고 떼면 내려간다
		# 물결은 자리(x)에 놓여 있으니 끝도 자리로 잰다 — 질주로 빨라지면 오르내림도 그만큼 빨라진다
		var fk := speed / maxf(1.0, speed_at(fly_x0))
		fox_y = clampf(fox_y + (TgD.FLY_V if fly_held else -TgD.FLY_V) * fk * dt, 0.0, TgD.FLY_TOP)
		vy = 0.0
		sliding = false
		fly_t = maxf(0.0, (fly_x0 + fly_len - dist) / maxf(1.0, speed))
		if fly_t <= 0.0:
			events.append({kind = "fly_end", x = dist})
	# 점프 · 발판에서 떨어지기
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
	if not on_ground() or fox_y > 1.0:
		air_t += dt
	if sliding:
		slide_t += dt
		if not slide_held and slide_t >= TgD.SLIDE_MIN:
			sliding = false
	_move_planks()
	_move_flyers()
	_spawn()
	_collide()
	items = items.filter(func(it): return float(it.x) + float(it.w) * 0.5 > dist - 300.0 or (it.kind == "flyer" and float(it.meet) > dist - 300.0))
	voids = voids.filter(func(v): return float(v[1]) > dist - 600.0)
	if oil <= 0.0:
		oil = 0.0
		over = true
		events.append({kind = "fail", x = dist})


## 겹치기 — 호랑이 기운 · 산삼 · 꿀단지 중 켜진 수가 둘 이상이면 그 수만큼 배.
func _update_mult() -> void:
	var n := int(dashing()) + int(giant()) + int(magnet_t > 0.0)
	var m := maxi(1, n)
	if m > mult:
		events.append({kind = "mult", n = m})
	mult = m
	best_mult = maxi(best_mult, m)


## 날아오는 곶감 — 만나는 자리(meet)는 정해져 있고, 호랑이가 거기 닿기까지 남은 시간만큼 앞에 있다. 속도가 바뀌어도 늘 그 자리에서 만난다.
func _move_flyers() -> void:
	for it: Dictionary in items:
		if it.kind == "flyer" and not it.gone:
			var sp := maxf(1.0, speed_at(float(it.meet)))
			it.x = float(it.meet) + TgD.FLYER_V * (float(it.meet) - dist) / sp


## 그 자리에 닿을 때의 구간 속도(맞아서 느려지거나 질주하는 것은 뺀다). 떡을 점프 궤적에 놓을 때 쓴다.
func speed_at(x: float) -> float:
	return float(zone_row(zone_at(x))[3])


## 점프 한 번이 날아가는 거리(그 자리의 속도로).
func jump_len(x: float) -> float:
	return speed_at(x) * 2.0 * TgD.JUMP_V / TgD.GRAVITY

# ==================== 길 만들기 ====================


## 길 만들기 — **패턴 조각**을 이어 붙인다(11-10 — 쿠키런 영상과 비교: 장애물이 화면에 2~3개, 간격은 점프 한 번 남짓, 짜인 패턴이 이어진다.
## 예전 "장애물 하나 · 빈 땅 · 떡 모양" 무작위는 화면당 1.0~1.3개 · 간격 점프 세 번 거리라 손이 한가했다).
## 조각(`CHUNKS`)은 점프 한 번 거리(J = 그 자리 속도 × 체공)를 단위로 짠다 — 속도가 달라도 리듬이 같다.
## **떡 줄은 유령 호랑이가 조각을 완벽하게 달려 본 궤적을 따라 깐다**(`_trail`) — 떡이 곧 지나갈 길이다(영상의 젤리 줄).
## 조각 사이: 짧은 숨(0.5J) · 일정 거리마다 꼬치(높은 곳) · 구간마다 한 번쯤 동아줄. 확인용 `force` 는 조각 이름.
func _spawn() -> void:
	var ahead := maxf(TgD.BOSS_AHEAD, speed * 1.0) if boss() else TgD.SPAWN_AHEAD
	ahead += TgD.FLYER_V * 2.5   # 날아오는 곶감은 만나는 자리보다 앞에서 나타난다
	while spawned_to < dist + ahead:
		var z := zone_at(spawned_to)
		var r := zone_row(z)
		var sp := speed_at(spawned_to)
		var jl := jump_len(spawned_to)
		var x := spawned_to + jl * 0.5
		if not rope_zones.has(z) and x > zone_start(z) + float(r[2]) * 0.45:
			rope_zones[z] = true
			if rng.randf() < 0.6 and force == "":
				_rope(x)
				continue
		var name := force if CHUNKS.has(force) else _pick_chunk(z)
		var end := _chunk(name, x, z, sp, jl)
		# 꼬치 — 일정 거리마다 반드시 하나, 높은 곳에(뛰어야 산다). 조각 뒤 빈 땅에
		if end >= kkochi_next:
			var kx := end + jl * 0.6
			_kkochi(kx, TgD.H_TOP if z >= 2 and rng.randf() < 0.5 else TgD.H_JUMP + 20.0)
			kkochi_next = kx + sp * TgD.KKOCHI_GAP
			end = kx + jl * 0.6
		spawned_to = end


## 조각 목록 — 이름: [가장 이른 구간(0 부터), 무게, 길이(J), 놓을 것들]. 놓을 것: [종류, 자리(J)].
## 종류: rock(바위 · 그루터기) · spike(가시) · pit(구덩이) · branch(숙이는 가지 · 곶감 줄) · pestle(내려오는 절굿공이) · tall(장승, 2단)
##   · fl / fh(날아오는 곶감 낮게 · 높게) · ceil(천장 바위 — 2단 점프를 일찍 하면 박는다) · lowceil(낮은 천장 — 2단 점프 금지, 작게 통통)
## 특수 조각(놓을 것 없이 따로 짓는다): steps(발판 계단) · moving(오르내리는 발판) · ledge(높은 발판) · rest(쉬는 화면 — 큰 떡 그림).
## 간격 기준: 넘는 것 사이 1.15J 면 "내려앉자마자 또"(통통), 숙이기 다음 넘기는 0.85J.
const CHUNKS := {
	"rest": [0, 1.0, 0.0, []],
	"rock3": [0, 1.0, 2.4, [["rock", 0.0], ["rock", 1.2], ["rock", 2.4]]],
	"rock_branch": [0, 1.0, 2.1, [["rock", 0.0], ["branch", 1.05], ["rock", 2.1]]],
	"pit2": [0, 0.8, 1.25, [["pit", 0.0], ["pit", 1.25]]],
	"chasm1": [1, 0.9, 0.75, [["chasm1", 0.0]]],
	"chasm1_rock": [2, 0.8, 2.0, [["chasm1", 0.0], ["rock", 2.0]]],
	"chasm2": [3, 0.9, 1.3, [["chasm2", 0.0]]],
	"chasm3": [6, 0.9, 1.45, [["chasm3", 0.0]]],
	"chasm_mix": [9, 0.8, 3.2, [["chasm1", 0.0], ["chasm2", 1.9]]],
	"branch2": [0, 0.7, 1.3, [["branch", 0.0], ["branch", 0.45], ["rock", 1.3]]],
	"steps": [1, 0.8, 0.0, []],
	"spikes": [2, 1.0, 4.6, [["spike", 0.0], ["spike", 1.15], ["spike", 2.3], ["spike", 3.45], ["spike", 4.6]]],
	"rock_pit_rock": [2, 1.0, 2.4, [["rock", 0.0], ["pit", 1.2], ["rock", 2.4]]],
	"flyer": [2, 0.9, 1.3, [["fl", 0.0], ["fl", 1.3]]],
	"flyer_mix": [3, 0.9, 1.2, [["fh", 0.0], ["fl", 1.2]]],
	"pestle": [3, 0.8, 0.9, [["pestle", 0.0], ["rock", 0.9]]],
	"tall_rock": [3, 0.9, 1.7, [["tall", 0.0], ["rock", 1.7]]],
	"moving": [3, 0.6, 0.0, []],
	"spike_branch": [5, 1.0, 3.2, [["spike", 0.0], ["spike", 1.15], ["branch", 2.05], ["spike", 3.2]]],
	"combo_fast": [5, 1.0, 2.55, [["branch", 0.0], ["rock", 0.85], ["branch", 1.7], ["rock", 2.55]]],
	"tall_pit": [5, 0.9, 1.75, [["tall", 0.0], ["pit", 1.75]]],
	"ledge": [5, 0.6, 0.0, []],
	"rhythm": [7, 0.9, 3.24, [["tall", 0.0], ["ceil", 0.81], ["tall", 1.62], ["ceil", 2.43], ["tall", 3.24]]],
	"pit_branch": [7, 0.9, 2.0, [["pit", 0.0], ["branch", 1.0], ["pit", 2.0]]],
	"flyer_wave": [8, 0.9, 2.3, [["fl", 0.0], ["fh", 1.15], ["fl", 2.3]]],
	"low_ceiling": [9, 0.8, 3.45, [["lowceil", 0.0], ["spike", 0.0], ["lowceil", 1.15], ["spike", 1.15], ["lowceil", 2.3], ["spike", 2.3], ["lowceil", 3.45], ["spike", 3.45]]],
	"twin_tall": [9, 0.8, 1.75, [["tall", 0.0], ["tall", 1.75]]],
	"gauntlet": [11, 0.8, 4.0, [["rock", 0.0], ["pit", 1.15], ["branch", 2.15], ["fl", 3.0], ["spike", 4.0]]],
	"pestle_pit": [11, 0.8, 2.0, [["pestle", 0.0], ["pit", 1.0], ["pestle", 2.0]]],
	"falling_rocks": [3, 0.9, 2.3, [["rock_fall", 0.0], ["rock_fall", 1.15], ["rock_fall", 2.3]]],   # 위에서 떨어져 박히는 바위 셋
	"duck_run": [4, 0.9, 1.65, [["branch", 0.0], ["pestle", 0.55], ["branch", 1.1], ["pestle", 1.65]]],   # 숙인 채로 연달아
	"crumble": [4, 0.7, 0.0, []],   # 꺼지는 발판
	"terrain": [1, 1.6, 0.0, []],   # 땅 덩어리가 칸칸이 오르내리는 지형(자주)
	"ceil_rocks": [6, 0.9, 3.45, [["lowceil", 0.0], ["rock", 0.0], ["lowceil", 1.15], ["rock", 1.15], ["lowceil", 2.3], ["rock", 2.3], ["lowceil", 3.45], ["rock", 3.45]]],
	"ceil_mix": [8, 0.9, 3.0, [["branch", 0.0], ["rock", 0.85], ["ceil", 1.45], ["tall", 2.25], ["branch", 3.0]]],
}


## 이번 조각 고르기 — 그 구간에 나올 수 있는 것 중 무게대로. 깊을수록 쉬는 조각이 줄고, 열린 지 오래된 조각일수록 무게가 붙는다.
func _pick_chunk(z: int) -> String:
	var names := []
	var ws := []
	var sum := 0.0
	for n: String in CHUNKS:
		var c: Array = CHUNKS[n]
		if z < int(c[0]):
			continue
		var w := float(c[1])
		if n == "rest":
			w = lerpf(0.9, 0.35, clampf(z / 12.0, 0.0, 1.0))
		else:
			w *= 1.0 + 0.08 * maxi(0, z - int(c[0]))
		names.append(n)
		ws.append(w)
		sum += w
	var roll := rng.randf() * sum
	for i in names.size():
		roll -= float(ws[i])
		if roll <= 0.0:
			return String(names[i])
	return String(names[names.size() - 1])


## 조각 하나를 x 부터 놓는다. 돌려주는 값: 조각이 끝나는 자리(다음 조각은 여기 뒤로).
func _chunk(name: String, x: float, z: int, sp: float, jl: float) -> float:
	var c: Array = CHUNKS[name]
	match name:
		"rest":   # 쉬는 화면 — 장애물 없이 큰 떡 그림 하나 · 둘
			var e := x
			for k in rng.randi_range(1, 2):
				e += _shape(e, z) + 60.0
			return e
		"steps":
			var ys: Array = [[0, 1, 2, 1], [0, 1, 0], [0, 1, 2], [0, 0, 1, 2]][rng.randi_range(0, 3)]
			_steps(x, ys, sp * 0.95, sp * 0.22, z)
			return x + ys.size() * sp * (0.95 + 0.22) + jl * 0.4
		"terrain":
			var x0t := x + jl * 1.0
			return _terrain(x0t, sp, jl, z) + jl * 0.4
		"crumble":
			var x0c := x + jl * 1.3
			_crumble(x0c, sp, jl)
			return x0c + 5 * jl + jl * 0.4
		"moving", "ledge":
			var x0 := x + jl * 1.3   # 첫 발판 한가운데를 겨냥해 뛸 빈 땅 — 앞 조각을 넘고 내려앉은 뒤에도 남게
			_void(x0, sp, name == "moving")
			return x0 + _void_span(sp, name == "moving") + jl * 0.4
	# 장승(2단 점프)으로 시작하면 앞 조각과 사이를 더 둔다 — 장승은 점프 한 번 거리 앞에서 뛰어야 하는데
	# 앞 조각의 마지막 장애물을 넘고 내려앉은 자리가 그보다 가까웠다(유령은 조각만 따로 달려 이걸 못 잡았다)
	if not (c[3] as Array).is_empty() and String(c[3][0][0]) in ["tall", "chasm2", "chasm3"]:
		x += jl * 1.0
	elif not (c[3] as Array).is_empty() and String(c[3][0][0]) == "chasm1":
		x += jl * 0.5
	var i0 := items.size()
	var late_p := 0.0   # 예전 "불쑥"은 등장 연출(enter)로 바뀌었다
	var enter_p := clampf(0.15 + z * 0.05, 0.0, 0.7)   # 등장 연출이 붙을 확률 — 깊을수록 자주
	for el: Array in c[3]:
		var ex := x + float(el[1]) * jl
		var n_before := items.size()
		match String(el[0]):
			"rock_fall":
				_low(ex, TgD.LOW_W, TgD.LOW_H, rng.randi_range(0, 1), false)
				items[items.size() - 1].enter = "fall"
			"rock":
				_low(ex, TgD.LOW_W, TgD.LOW_H, rng.randi_range(0, 1), rng.randf() < late_p)
			"spike":
				_low(ex, TgD.SPIKE_W, TgD.SPIKE_H, 2, false)
			"pit":
				items.append({kind = "pit", x = ex, y = -200.0, w = TgD.PIT_W, h = 200.0, gone = false, v = 0})
			"branch":
				_high(ex, TgD.HIGH_W, TgD.HIGH_H, rng.randi_range(0, 1), rng.randf() < late_p, false)
			"pestle":
				_high(ex, TgD.PESTLE_W, TgD.PESTLE_H, 2, true, false)
			"tall":
				items.append({kind = "tall", x = ex, y = 0.0, w = TgD.TALL_W, h = TgD.TALL_H, gone = false, v = 0})
			"fl", "fh":
				var low_f: bool = el[0] == "fl"
				var d2 := TgD.FLYER_R * 2.0
				items.append({kind = "flyer", x = ex, meet = ex, y = TgD.FLYER_LOW if low_f else TgD.FLYER_HIGH, w = d2, h = d2, gone = false, v = 0 if low_f else 1})
			"ceil":
				items.append({kind = "high", x = ex, y = TgD.CEIL_Y, w = sp * 0.24, h = 400.0, gone = false, v = 3, late = false, sv = rng.randi_range(0, 2)})
			"lowceil":
				items.append({kind = "high", x = ex, y = TgD.LOWCEIL_Y, w = jl * 0.6, h = 400.0, gone = false, v = 3, late = false, sv = rng.randi_range(0, 2)})
			"chasm1", "chasm2", "chasm3":   # 낭떠러지(발판 없이 땅이 끊긴다) — ex 가 벼랑 끝
				var kind_i := int(String(el[0]).substr(5)) - 1
				var cw: float = TgD.CHASM_W[kind_i] * jl
				var delay_x := 0.0
				if kind_i == 2:   # 천장 — 앞쪽 위
					items.append({kind = "high", x = ex + jl * 0.325, y = TgD.LOWCEIL_Y, w = jl * 0.45, h = 400.0, gone = false, v = 3, late = false})
					delay_x = ex + jl * 0.55 + TgD.FOX_W * 0.5   # 천장 끝을 지나자마자 — 더 늦으면 내려앉아 빠진다
				voids.append([ex, ex + cw])
				items.append({kind = "pit", x = ex + cw * 0.5, y = -200.0, w = cw, h = 200.0, gone = false, v = 8, dbl = kind_i > 0, delay_x = delay_x})
		# 등장 연출 — 바위는 솟거나 굴러 들어오거나 떨어지고, 가지 · 절굿공이는 내려오거나 흔들려 들어오고, 가시는 튀어나오고, 천장은 흔들리다 내려온다
		if items.size() > n_before and not items[n_before].has("enter") and rng.randf() < enter_p:
			var it2: Dictionary = items[n_before]
			match String(it2.kind):
				"low":
					it2.enter = ["pop"] [0] if int(it2.v) == 2 else ["rise", "roll", "fall"][rng.randi_range(0, 2)]
				"high":
					it2.enter = "shake" if int(it2.v) == 3 else ["drop", "swing"][rng.randi_range(0, 1)]
	var end := x + float(c[2]) * jl
	_trail(items.slice(i0), x - jl * 0.7, end + jl * 0.6)
	return end + jl * 0.5


## 떡 줄 — 유령 호랑이(같은 규칙의 새 TgGame)가 이 조각만 놓인 길을 완벽 봇으로 달려 본 궤적을 따라 44px 마다 떡.
## 몸 한가운데 높이라 그 길로 가면 다 먹고, 장애물 판정 안에는 놓이지 않는다. 유령이 부딪히면(드문 일) 장애물 위 점프 궤적으로 대신한다.
## 조각 한가운데쯤 떡 하나를 물건(꿀단지 · 산삼 · 방망이 · 보따리)으로 바꾸기도 한다.
func _trail(chunk_items: Array, x0: float, x1: float) -> void:
	var gh := TgGame.new(zone0, 1)
	gh.items = []
	for it: Dictionary in chunk_items:
		gh.items.append(it.duplicate())
	gh.spawned_to = 1e12
	gh.kkochi_next = 1e12
	gh.oil = 1e9
	gh.dist = x0
	gh.zone = gh.zone_at(x0)
	gh.speed = speed_at(x0)
	gh.voids = voids.duplicate()
	var pts := []
	var last := -1e9
	var guard := 0
	while gh.dist < x1 and guard < 60 * 20:
		gh.bot()
		gh.step(1.0 / 60.0)
		gh.events.clear()
		guard += 1
		if gh.dist - last >= 44.0 and gh.dist > x0 + 30.0:
			last = gh.dist
			pts.append(Vector2(gh.dist, gh.fox_y + gh.fox_h() * 0.5))
	if gh.hits > 0:   # 유령도 못 지나간 조각 — 예전처럼 넘는 것 위 궤적만
		for it: Dictionary in chunk_items:
			if it.kind in ["low", "pit"] or (it.kind == "flyer" and int(it.v) == 0):
				_arc(float(it.get("meet", it.x)), 5)
			elif it.kind == "tall":
				_arc2(float(it.x), 8)
		return
	var thing := rng.randf() < 0.18
	# 무지개떡 — 궤적이 가장 높은 곳(장애물을 넘는 점프 꼭대기). 잘 넘을수록 먹는다. 조각 셋에 둘꼴
	var top_i := -1
	if rng.randf() < 0.65:
		var top_y := TgD.FOX_H
		for i in pts.size():
			if (pts[i] as Vector2).y > top_y + 20.0:
				top_y = (pts[i] as Vector2).y
				top_i = i
	for i in pts.size():
		var p: Vector2 = pts[i]
		if i == top_i:
			items.append({kind = "big", x = p.x, y = p.y, w = 0.0, h = 0.0, gone = false, v = 0})
			continue
		if thing and i == pts.size() / 2:
			items.append({kind = ["honey", "sansam", "club", "box"][rng.randi_range(0, 3)], x = p.x, y = p.y, w = 0.0, h = 0.0, gone = false, v = 0})
		else:
			_tteok(p.x, p.y)


func _low(x: float, w: float, h: float, v: int, late: bool) -> void:
	items.append({kind = "low", x = x, y = 0.0, w = w, h = h, gone = false, v = v, late = late})


## 숙여서 지나가는 장애물 + 그 밑의 떡 셋. v: 0 소나무 가지 · 1 곶감 줄 · 2 절굿공이(천장에서).
func _high(x: float, w: float, h: float, v: int, late: bool, tteok: bool = true) -> void:
	items.append({kind = "high", x = x, y = TgD.HIGH_Y, w = w, h = h, gone = false, v = v, late = late})
	if tteok:
		for i in 3:
			_tteok(x + (i - 1) * 40.0, TgD.SLIDE_H * 0.5)


func _kkochi(x: float, y: float) -> void:
	items.append({kind = "kkochi", x = x, y = y, w = 0.0, h = 0.0, gone = false, v = 0})
	lanterns_all += 1


## 발판 계단 — 높이가 다른 발판이 짧은 틈을 두고 이어진다(ys 는 TgD.STEP_YS 의 칸 번호). 위에는 엽전 · 떡, 가장 높은 칸 끝에 보따리.
## 아래 땅: 앞 구간은 떡 줄(아랫길도 길이다), 가시밭이 나오는 구간부터는 가시 — 위로 가는 것이 낫다. 발판 사이는 뛰어서 건넌다.
func _steps(x: float, ys: Array, l: float, gap: float, z: int) -> void:
	var top := 0
	for k in ys.size():
		top = maxi(top, int(ys[k]))
	for k in ys.size():
		var x0 := x + k * (l + gap)
		var py: float = TgD.STEP_YS[int(ys[k])]
		items.append({kind = "plank", x = x0 + l * 0.5, y = py, w = l, h = 22.0, gone = false, v = 0})
		for i in int((l - 80.0) / 50.0):
			var px := x0 + 50.0 + i * 50.0
			if int(ys[k]) == top:
				items.append({kind = "coin", x = px, y = py + TgD.FOX_H * 0.45, w = 0.0, h = 0.0, gone = false, v = 0})
			else:
				_tteok(px, py + TgD.FOX_H * 0.45)
		if int(ys[k]) == top and k == ys.size() - 1 or (int(ys[k]) == top and k + 1 < ys.size() and int(ys[k + 1]) < top):
			items.append({kind = "box", x = x0 + l - 40.0, y = py + TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})
	# 아래 땅
	var span := ys.size() * (l + gap) - gap
	if z >= 4:
		var n := int((span - 200.0) / 160.0)
		for i in n:
			_low(x + 150.0 + i * 160.0, TgD.SPIKE_W, TgD.SPIKE_H, 2, false)
	else:
		for i in int(span / 80.0):
			if i % 3 != 2:
				_tteok(x + 60.0 + i * 80.0, TgD.H_GROUND)


## 허공 구간 — 땅이 끊긴 낭떠러지 위에 발판. moving: **짧은** 오르내리는 발판 넷(한 번 뛰면 오르고, 올라타면 실려 간다 — 이웃끼리 반대로) ·
## 아니면 높은 발판 셋(TgD.LEDGE_Y — 2단 점프로만 오른다). 떨어지면 구덩이(배가 줄고 건너편으로 끌어올려진다). 맨 끝 발판에 보따리.
## (11-10 사용자 "너무 넓다" — 발판 하나가 속도의 0.8배(400px 남짓)였다. 오르내리는 발판은 0.38배로 짧게, 넷으로)
func _void_dims(sp: float, moving: bool) -> Array:
	# 발판은 캐릭터(58)보다 조금 큰 정도(사용자가 보낸 그림) — 길이는 고정, 틈은 속도에 맞춰 한 번 뛰면 다음 한가운데에 닿게
	# 가운데에서 가운데까지 = 같은 높이로 한 번 뛰어 날아가는 거리(점프 체공 × 속도) — 발판 한가운데서 뛰면 다음 한가운데에 내려앉는다.
	# 더 가까우면 어디서 뛰어도 지나쳤다(체공 0.77초 × 490 = 377 인데 간격이 326)
	var c2c := sp * 2.0 * TgD.JUMP_V / TgD.GRAVITY
	return [4, TgD.MOVE_W, c2c - TgD.MOVE_W] if moving else [3, TgD.LEDGE_W, c2c - TgD.LEDGE_W]   # [발판 수, 길이, 틈]


func _void_span(sp: float, moving: bool) -> float:
	var d := _void_dims(sp, moving)
	return int(d[0]) * float(d[1]) + (int(d[0]) - 1) * float(d[2])


func _void(x: float, sp: float, moving: bool) -> void:
	var d := _void_dims(sp, moving)
	var n := int(d[0])
	var l := float(d[1])
	var gap := float(d[2])
	var span := _void_span(sp, moving)
	voids.append([x - 40.0, x + span + 40.0])
	items.append({kind = "pit", x = x + span * 0.5, y = -200.0, w = span + 80.0, h = 200.0, gone = false, v = 9})
	for k in n:
		var cx := x + k * (l + gap) + l * 0.5
		var base := TgD.MOVE_Y if moving else TgD.LEDGE_Y
		var pl := {kind = "plank", x = cx, y = base, w = l, h = 22.0, gone = false, v = 1 if moving else 0}
		if moving:
			pl.base = base
			pl.ph = PI * k   # 이웃끼리 반대로 — 하나가 오를 때 옆은 내려간다
			pl.y = base + TgD.MOVE_AMP * sin(TAU * time / TgD.MOVE_PER + float(pl.ph))
		items.append(pl)
		# 발판 사이 허공에 떡 — 건너뛰는 궤적에
		if k < n - 1:
			for i in 3:
				_tteok(cx + l * 0.5 + gap * (0.2 + 0.3 * i), base + TgD.FOX_H * 0.5 + 70.0)
		var top := base + (TgD.MOVE_AMP if moving else 0.0)
		if k == n - 1:
			items.append({kind = "box", x = cx, y = top + TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})
		else:
			for i in (1 if moving else 3):
				items.append({kind = "coin", x = cx + (i - (0 if moving else 1)) * 50.0, y = top + TgD.FOX_H * 0.45, w = 0.0, h = 0.0, gone = false, v = 0})


## 땅 덩어리 지형 — 낭떠러지 위에 풀 윗면 + 흙 몸통 덩어리가 BLOCK_YS 높이를 오가며 이어진다(틈은 0.3J). 오를 때는 뛰고, 내려갈 때는 틈을 건넌다.
## 덩어리 위에는 떡 줄, 틈 위에는 건너는 궤적의 떡. 뒤 구간일수록 덩어리가 짧고 많다. 돌려주는 값: 끝 자리.
func _terrain(x: float, sp: float, jl: float, z: int) -> float:
	var n := rng.randi_range(3, 4) + (1 if z >= 6 else 0)
	var gap := jl * 0.3
	var e := x
	var lv := rng.randi_range(0, 1)
	var x_start := x
	for k in n:
		var bw := jl * rng.randf_range(1.0, 1.8) * (1.0 if z < 6 else 0.8)
		var py: float = TgD.BLOCK_YS[lv]
		items.append({kind = "plank", x = e + bw * 0.5, y = py, w = bw, h = 22.0, gone = false, v = 5})
		for i in int((bw - 60.0) / 44.0):
			_tteok(e + 40.0 + i * 44.0, py + TgD.FOX_H * 0.45)
		e += bw
		if k < n - 1:
			# 다음 높이 — 한 칸씩 오르내린다(같은 높이도)
			var nl := clampi(lv + [-1, 0, 1, 1][rng.randi_range(0, 3)], 0, TgD.BLOCK_YS.size() - 1)
			for i in 2:
				_tteok(e + gap * (0.3 + 0.4 * i), maxf(py, float(TgD.BLOCK_YS[nl])) + TgD.FOX_H * 0.5 + 60.0)
			lv = nl
			e += gap
	voids.append([x_start - 30.0, e + 30.0])
	items.append({kind = "pit", x = (x_start + e) * 0.5, y = -200.0, w = e - x_start + 60.0, h = 200.0, gone = false, v = 9})
	return e


## 꺼지는 발판 — 낭떠러지 위 짧은 발판 다섯(가운데에서 가운데까지 J). 올라서면 CRUMBLE_T 동안 흔들리다 떨어진다 — 서둘러 다음으로.
func _crumble(x: float, sp: float, jl: float) -> void:
	var span := 5 * jl - (jl - TgD.MOVE_W)
	voids.append([x - 40.0, x + span + 40.0])
	items.append({kind = "pit", x = x + span * 0.5, y = -200.0, w = span + 80.0, h = 200.0, gone = false, v = 9})
	for k in 5:
		var cx := x + k * jl + TgD.MOVE_W * 0.5
		items.append({kind = "plank", x = cx, y = TgD.CRUMBLE_Y, w = TgD.MOVE_W, h = 22.0, gone = false, v = 2, crumble = true})
		if k < 4:
			for i in 3:
				_tteok(cx + TgD.MOVE_W * 0.5 + (jl - TgD.MOVE_W) * (0.2 + 0.3 * i), TgD.CRUMBLE_Y + TgD.FOX_H * 0.5 + 70.0)
		else:
			items.append({kind = "box", x = cx, y = TgD.CRUMBLE_Y + TgD.FOX_H * 0.5, w = 0.0, h = 0.0, gone = false, v = 0})


## 오르내리는 발판 — 올라탄 호랑이는 같이 실려 간다. 꺼지는 발판은 올라선 뒤 흔들리다 떨어진다.
func _move_planks() -> void:
	for it: Dictionary in items:
		if it.kind == "plank" and it.has("crumble"):
			var on := vy <= 0.0 and absf(fox_y - float(it.y)) < 1.5 and absf(dist - float(it.x)) < float(it.w) * 0.5
			if on and not it.has("crumble_t"):
				it.crumble_t = 0.0
				events.append({kind = "crumble", x = it.x, y = it.y})
			if it.has("crumble_t"):
				it.crumble_t = float(it.crumble_t) + 1.0 / 60.0
				if float(it.crumble_t) > TgD.CRUMBLE_T:
					it.falling = true
					it.fall_v = float(it.get("fall_v", 0.0)) + TgD.GRAVITY / 60.0
					it.y = float(it.y) - float(it.fall_v) / 60.0
			continue
		if it.kind != "plank" or not it.has("base"):
			continue
		var old := float(it.y)
		var ny := float(it.base) + TgD.MOVE_AMP * sin(TAU * time / TgD.MOVE_PER + float(it.ph))
		var riding := vy <= 0.0 and absf(fox_y - old) < 1.5 and absf(dist - float(it.x)) < float(it.w) * 0.5 and not flying()
		it.y = ny
		if riding:
			fox_y = ny


## 떡 모양 — 장애물 뒤 빈 땅에. 돌려주는 값: 차지한 길이. 대부분 점프 · 2단 점프 높이라 **뛰어야 먹는다**.
## 줄(점프 높이) · 높은 줄(2단 점프) · 아치 · 물결 · 기둥 · 하트 · 마름모 · 땅 줄(일부만). 엽전 줄은 높은 곳에.
func _shape(x: float, z: int) -> float:
	var roll := rng.randf()
	var kinds := [["arch", 0.08], ["row", 0.06], ["top", 0.06 if z >= 1 else 0.0], ["wave", 0.06],
			["heart", 0.03], ["diamond", 0.03], ["heart_ring", 0.1], ["arrow", 0.08], ["word", 0.1], ["picture", 0.4]]
	var sum := 0.0
	for k: Array in kinds:
		sum += float(k[1])
	roll *= sum
	var kind := "ground"
	for k: Array in kinds:
		roll -= float(k[1])
		if roll <= 0.0:
			kind = String(k[0])
			break
	match kind:
		"arch":   # 빈 땅의 점프 궤적 — 그냥 뛰면 다 먹는다
			var jl := jump_len(x)
			_arc(x + jl * 0.5, 7)
			return jl
		"row":
			var n := rng.randi_range(5, 6)
			for i in n:
				_tteok(x + i * 40.0, TgD.H_JUMP)
			return n * 40.0
		"top":   # 2단 점프 높이 — 셋에 하나는 엽전 줄
			var n2 := rng.randi_range(5, 6)
			var coin := rng.randf() < 0.35
			for i in n2:
				if coin:
					items.append({kind = "coin", x = x + i * 40.0, y = TgD.H_TOP, w = 0.0, h = 0.0, gone = false, v = 0})
				else:
					_tteok(x + i * 40.0, TgD.H_TOP)
			return n2 * 40.0
		"wave":
			for i in 10:
				_tteok(x + i * 40.0, lerpf(TgD.H_GROUND, TgD.H_JUMP, 0.5 - 0.5 * cos(i / 9.0 * TAU)))
			return 400.0
		"column":   # 땅에서 2단 점프 높이까지 쌓은 기둥 둘
			for c in 2:
				for j in 8:
					_tteok(x + c * 40.0, TgD.H_GROUND + j * 48.0)
			return 80.0
		"heart", "diamond":
			var pat: Array = HEART if kind == "heart" else DIAMOND
			for j in pat.size():
				var line: String = pat[j]
				for i in line.length():
					if line[i] == "#":
						if j == 2 and i == 2:   # 한가운데는 무지개떡
							items.append({kind = "big", x = x + i * 34.0, y = TgD.H_JUMP + 60.0 - j * 34.0, w = 0.0, h = 0.0, gone = false, v = 0})
						else:
							_tteok(x + i * 34.0, TgD.H_JUMP + 60.0 - j * 34.0)
			return String(pat[0]).length() * 34.0
		"picture":   # 그림 — 자동차 · 호랑이 얼굴 · 집 · 해 · 달 · 물고기 …(`PICTURES`)
			var keys := PICTURES.keys()
			return _bitmap(x, PICTURES[keys[rng.randi_range(0, keys.size() - 1)]], TgD.H_GROUND, 32.0)
		"heart_ring":   # 떡 하트 테두리 + 한가운데 큰 엽전(쿠키런 영상 — 사용자가 보낸 그림)
			return _bitmap(x, HEART_RING, TgD.H_GROUND + 20.0)
		"arrow":   # 엽전 몸통 + 떡 화살촉
			return _bitmap(x, ARROW, TgD.H_GROUND + 50.0)
		"word":   # 떡 글자 — 위에 엽전 줄
			var w: String = WORDS[rng.randi_range(0, WORDS.size() - 1)]
			var e := x
			for ch in w:
				var g: Array = LETTERS[ch]
				_bitmap(e, g, TgD.H_GROUND)
				e += (String(g[0]).length() + 1) * 34.0
			var span := e - x - 34.0
			for i in int(span / 50.0) + 1:
				items.append({kind = "coin", x = x + i * 50.0, y = TgD.H_GROUND + 7 * 34.0 + 30.0, w = 0.0, h = 0.0, gone = false, v = 0})
			return span
		_:
			var n3 := rng.randi_range(4, 6)
			for i in n3:
				_tteok(x + i * 40.0, TgD.H_GROUND)
			return n3 * 40.0


## 점 그림으로 놓기(위 줄부터, 맨 아랫줄이 base 높이). # 떡 · c 엽전 · B 무지개떡 · C 큰 엽전. 돌려주는 값: 폭.
func _bitmap(x: float, rows: Array, base: float, cell: float = 34.0) -> float:
	var n := rows.size()
	var tint: int = [1, 2, 3][rng.randi_range(0, 2)]   # 분홍 · 쑥 · 노랑 중 한 색 — 흰 떡 덩어리로는 그림이 안 읽혔다
	for j in n:
		var line: String = rows[j]
		for i in line.length():
			var px := x + i * cell
			var py := base + (n - 1 - j) * cell
			match line[i]:
				"#":
					_tteok(px, py, tint)
				"c":
					items.append({kind = "coin", x = px, y = py, w = 0.0, h = 0.0, gone = false, v = 0})
				"B":
					items.append({kind = "big", x = px, y = py, w = 0.0, h = 0.0, gone = false, v = 0, sz = TgD.BIG_PIC})
				"C":
					items.append({kind = "bigcoin", x = px, y = py, w = 0.0, h = 0.0, gone = false, v = 0})
	return String(rows[0]).length() * cell


## 떡 · 엽전 그림(위 줄부터, 맨 아랫줄이 땅 높이). # 떡 · c 엽전 · B 무지개떡 · C 큰 엽전 — 쉬는 조각에 나온다.
## (11-10 사용자 "일자로 2열 떡만 보니 참신함이 없다 · 차 모양도 만들고 다양하게" — 쿠키런은 자동차 · 하트 · 글자를 젤리와 코인으로 그린다)
const PICTURES := {
	"car": ["....######....", "...#......#...", "..#...B....#..", "##############", "##############", "#############c", "..C.......C...", ".............."],
	"tiger": ["##.......##", "#.#######.#", ".#.......#.", ".#.c...c.#.", ".#...B...#.", ".#..###..#.", "..#.....#..", "...#####..."],
	"star": [".....#.....", "....###....", "###########", ".#########.", "..#######..", ".####.####.", ".##.....##.", "#.........#"],
	"moon": ["..####...c", ".###......", "###......c", "###.......", "###.......", ".###......", "..####..c."],
	"house": ["....#####....", "..#########..", "#############", ".#.........#.", ".#.cc..cc..#.", ".#.cc..cc..#.", ".#....##...#.", ".###########."],
	"fish": ["...#####.....#", ".#########..##", "###c#######.##", "#############.", "#############.", ".#########..##", "...#####.....#"],
	"butterfly": ["##...##", "###.###", "#######", "..#B#..", "#######", "###.###", "##...##"],
	"umbrella": ["...#####...", ".#########.", "###########", ".....c.....", ".....c.....", ".....c.....", "...c.c.....", "....c......"],
	"sun": ["..#..c..#..", "...#####...", "c.#######.c", "..##.B.##..", "..#######..", "c.#######.c", "...#####...", "..#..c..#.."],
	"note": ["....####", "....#..#", "....#..#", "....#..#", "....#..#", "..###.##", ".####.##", "..##...."],
	"smile": ["..#####..", ".#.....#.", "#..c.c..#", "#.......#", "#.#...#.#", "#..###..#", ".#.....#.", "..#####.."],
	"crown": ["#...#...#", "##.###.##", "#########", "#c#c#c#c#", "#########"],
	"up": ["...#...", "..###..", ".#####.", "#######", "..ccc..", "..ccc..", "..ccc.."],
	"mountain": ["......#......", ".....###.....", "....##B##....", "...#######...", "..##.###.##..", ".#####.#####.", "#############"],
	"snowman": ["...###...", "..#c.c#..", "..#####..", "...###...", ".#######.", "#..#c#..#", "#..#c#..#", ".#######."],
	"gotgam": ["c...c...c...c", "c...c...c...c", "#...#...#...#", "#...#...#...#", "c...c...c...c", "#...#...#...#", "#...#...#...#"],
}


const HEART_RING := ["..##.##..", ".#..#..#.", "#.......#", "#...C...#", ".#.....#.", "..#...#..", "...#.#...", "....#...."]
const ARROW := ["....##...", "....###..", "cccccc###", "....###..", "....##..."]
const WORDS := ["GO", "LOVE", "WOW", "UP"]
const LETTERS := {
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"V": ["#...#", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
}


## 떡으로 그리는 모양(위 줄부터). 바닥 줄이 점프 높이 근처에 온다.
const HEART := [".#.#.", "#####", "#####", ".###.", "..#.."]
const DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]


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
		if it.kind in ["low", "pit", "tall"] and absf(float(it.x) - dist) < (speed_at(float(it.x)) * air2_peak() if it.kind == "tall" else jump_len(float(it.x)) * 0.5) * TgD.DASH_SPEED + 40.0:
			return true
	return false


## 동아줄 — 잡으면 하늘 보너스. 뒤로 장애물 없는 구간에 떡이 물결로 놓인다(땅에서 시작해 땅에서 끝난다 — 완벽하게 날면 다 먹는다).
func _rope(x: float) -> bool:
	var sp := speed_at(x)
	var total := TgD.FLY_PERIOD * TgD.FLY_WAVES
	var span := sp * total * 1.12   # 질주로 빨라져도 여유
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


## tint: 떡 색(TgArt.TTEOK 의 번호, -1 이면 흰 떡) — 그림 모양은 한 색으로 물들여야 윤곽이 읽힌다.
func _tteok(x: float, y: float, tint: int = -1) -> void:
	items.append({kind = "ember", x = x, y = y, w = 0.0, h = 0.0, gone = false, v = tint})
	embers_all += 1


## 꼭대기가 x 인 점프 궤적 위에 떡 n 개(몸 한가운데 높이).
func _arc(x: float, n: int) -> void:
	var sp := speed_at(x)
	var total := 2.0 * TgD.JUMP_V / TgD.GRAVITY
	for i in n:
		var tt := total * (0.2 + 0.6 * i / float(n - 1))
		var y := TgD.JUMP_V * tt - 0.5 * TgD.GRAVITY * tt * tt
		_tteok(x + (tt - total * 0.5) * sp, y + TgD.FOX_H * 0.5)

# ==================== 부딪힘 ====================


func _collide() -> void:
	var fr := fox_rect()
	var fc := Vector2(dist, fox_y + fox_h() * 0.5)
	for it: Dictionary in items:
		if it.gone:
			continue
		match String(it.kind):
			"big":   # 무지개떡 — 크고(반지름 BIG_R) 점수가 열 배
				var cb := Vector2(it.x, it.y)
				var nb := (dashing() and absf(cb.x - fc.x) < TgD.DASH_PULL * 0.6) or (magnet_t > 0.0 and cb.distance_to(fc) < TgD.MAGNET_R)
				if nb or _circle_hits(fr, cb, TgD.BIG_R * float(it.get("sz", 1.0))):
					it.gone = true
					bigs += 1
					pts += TgD.BIG_SCORE * mult
					oil = minf(oil + TgD.OIL_EMBER * 3.0, TgD.OIL_MAX)
					var was2 := gauge
					if not dashing():
						gauge = mini(gauge + TgD.BIG_GAUGE, need)
					events.append({kind = "big", x = it.x, y = it.y, m = mult, full = gauge >= need and was2 < need})
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
						pts += 10 * mult
						oil += TgD.OIL_EMBER
						var was := gauge
						if not dashing():
							gauge = mini(gauge + 1, need)
						events.append({kind = "ember", x = it.x, y = it.y, full = gauge >= need and was < need})
					else:
						lanterns += 1
						pts += TgD.SCORE_LANTERN * mult
						oil += TgD.OIL_LANTERN * (1.0 + 0.1 * up[1])
						events.append({kind = "kkochi", x = it.x, y = it.y, m = mult})
					oil = minf(oil, TgD.OIL_MAX)
			"low", "high", "tall", "flyer":
				var orc := Rect2(it.x - it.w * 0.5, it.y, it.w, it.h)
				if fr.intersects(orc):
					if dashing() or giant():
						it.gone = true
						events.append({kind = "smash", x = it.x, y = it.y + it.h * 0.5})
					elif inv_t <= 0.0:
						_hurt(TgD.OIL_HIT, it)
			"bigcoin":   # 큰 엽전 — 엽전 열 닢
				if _circle_hits(fr, Vector2(it.x, it.y), 30.0) or (dashing() and absf(float(it.x) - fc.x) < TgD.DASH_PULL * 0.6) \
						or (magnet_t > 0.0 and Vector2(it.x, it.y).distance_to(fc) < TgD.MAGNET_R):
					it.gone = true
					coins += 10
					pts += TgD.COIN_SCORE * 10 * mult
					events.append({kind = "bigcoin", x = it.x, y = it.y})
			"coin":
				if _circle_hits(fr, Vector2(it.x, it.y), 18.0) or (dashing() and absf(float(it.x) - fc.x) < TgD.DASH_PULL * 0.6) \
						or (magnet_t > 0.0 and Vector2(it.x, it.y).distance_to(fc) < TgD.MAGNET_R):
					it.gone = true
					coins += 1
					pts += TgD.COIN_SCORE * mult
					events.append({kind = "coin", x = it.x, y = it.y})
			"honey", "sansam", "club", "rope", "box":
				if _circle_hits(fr, Vector2(it.x, it.y), 30.0):
					it.gone = true
					_take(it)
			"pit":
				if on_ground() and fox_y < 1.0 and not dashing() and not giant() and not flying() and absf(dist - it.x) < it.w * 0.5 - 12.0:
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
			pts += TgD.COIN_SCORE * 8 * mult
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
				if o.kind in ["low", "high", "tall", "flyer"] and float(o.x) < dist + 1000.0:
					o.gone = true
					embers_all += 1
				elif o.kind != "ember":
					continue
				o.gone = true
				embers += 1
				pts += 10 * mult
				oil = minf(oil + TgD.OIL_EMBER, TgD.OIL_MAX)
				gauge = mini(gauge + 1, need)
				got.append(Vector2(o.x, float(o.y) + minf(float(o.h), 120.0) * 0.5))
			events.append({kind = "club", x = it.x, y = it.y, got = got})
			return
	_update_mult()
	events.append({kind = "item", item = kind, x = it.x, y = it.y})


func _circle_hits(r: Rect2, c: Vector2, rad: float) -> bool:
	var p := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return p.distance_to(c) <= rad


func _hurt(n: float, it: Dictionary) -> void:
	oil -= n
	hits += 1
	inv_t = TgD.HIT_INV
	slow_t = TgD.HIT_SLOW
	events.append({kind = "hit", x = it.x, y = float(it.y) + minf(float(it.h), 120.0) * 0.5})
	if boss():   # 비틀거리는 사이 귀신이 다가온다 — 따라잡히면 물린다
		chase += 0.3
		if chase >= 1.0:
			chase = 0.5
			oil -= TgD.OIL_BITE
			events.append({kind = "bite", x = dist})

# ==================== 봇 ====================


## 봇 — 넘는 장애물은 꼭대기가 한가운데에 오게 뛰고(떡이 그 궤적에 놓여 있다), 숙이는 장애물은 미리 숙이고, 게이지가 차면 호랑이 기운.
## 높은 떡 · 꼬치 · 엽전 · 물건은 뛰어서(높으면 2단 점프로) 먹고, 발판 계단은 오르내린다.
## late: 점프를 몇 초 늦게 뛰나(0 이면 완벽). miss: 장애물 · 높은 것을 못 보고 지나칠 확률 — 사람 흉내.
func bot(late: float = 0.0, miss: float = 0.0) -> void:
	if over or busy():
		return
	if flying():
		fly_held = fox_y + TgD.FOX_H * 0.5 < fly_target()
		return
	if gauge >= need and awaken():   # 질주 중에는 못 쓴다 — 그때는 아래로 내려가 계속 뛴다
		return
	if _bot_delay_x > 0.0 and not on_ground() and jumps == 0 and dist >= _bot_delay_x:   # 천장을 지난 뒤 내려오며 한 번 더
		_bot_delay_x = 0.0
		jump()
		return
	if on_ground() and _bot_delay_x > 0.0 and fox_y < 1.0 and vy <= 0.0:
		_bot_delay_x = 0.0
	if _bot_double and not on_ground() and vy <= 0.0 and jumps == 0:   # 첫 점프 꼭대기에서 한 번 더
		_bot_double = false
		jump()
		return
	var need_slide := false
	var half := TgD.JUMP_V / TgD.GRAVITY   # 꼭대기까지 걸리는 시간
	var fl := _floor(fox_y)
	for it: Dictionary in items:
		if it.gone or it.kind == "ember":
			continue
		if not it.has("seen"):
			it.seen = rng.randf() >= miss   # 처음 본 순간에 "볼지" 정한다 — 매 프레임 굴리면 결국 다 본다
		if not bool(it.seen):
			continue
		var d := float(it.x) - dist
		match String(it.kind):
			"high":   # 천장(리듬 구간의 매달린 것)은 서 있어도 안 닿는다 — 숙이지 않는다
				if fl < 1.0 and float(it.y) < TgD.FOX_H and d < speed * 0.3 + float(it.w) and d > -float(it.w) - TgD.FOX_W - 60.0:
					need_slide = true
			"flyer":
				var dm := float(it.meet) - dist
				if int(it.v) == 1:
					if fl < 1.0 and dm < speed * 0.3 + float(it.w) and dm > -float(it.w) - TgD.FOX_W - 60.0:
						need_slide = true
				elif dm > 0.0 and dm <= speed * (half - late) and on_ground() and not it.has("jumped"):
					it.jumped = true
					_bot_jump(false)
					return
			"pit" when int(it.v) == 8:   # 낭떠러지 — 벼랑 끝 바로 앞에서 뛴다. 넓으면 2단(천장이 있으면 천장을 지난 뒤에)
				var e0 := float(it.x) - float(it.w) * 0.5 - dist
				if e0 > 0.0 and e0 <= speed * (0.12 - late) + 10.0 and on_ground() and fl < 1.0 and not it.has("jumped"):
					it.jumped = true
					_bot_jump(bool(it.dbl) and float(it.delay_x) <= 0.0)
					_bot_delay_x = float(it.delay_x)
					return
			"pit" when int(it.v) == 9:
				pass   # 허공 구간 — 발판 규칙이 맡는다
			"low", "pit":
				if d > 0.0 and d <= speed * (half - late) and on_ground() and fl < 1.0 and not it.has("jumped"):
					it.jumped = true
					_bot_jump(false)
					return
			"tall":
				if d > 0.0 and d <= speed * (air2_peak() - late) and on_ground() and not it.has("jumped"):
					it.jumped = true
					_bot_jump(false)
					_bot_double = true
					return
			"plank":   # 발판 — 다음 발판 **한가운데**에 내려앉게 뛴다(발판이 캐릭터보다 조금 큰 정도라 겨냥해야 한다)
				var x1 := float(it.x) + float(it.w) * 0.5
				var standing := on_ground() and absf(float(it.y) - fl) < 1.0 and dist < x1 and dist > float(it.x) - float(it.w) * 0.5
				var from_ground := on_ground() and fl < 1.0 and float(it.x) - float(it.w) * 0.5 > dist and not it.has("jumped")
				if standing or from_ground:
					var nx: Dictionary = it if from_ground else _next_plank(x1)
					if nx.is_empty():
						if standing and dist > x1 - 30.0:   # 마지막 발판 — 끝에서 뛰어 건너편 땅으로
							_bot_jump(false)
							return
					else:
						var dbl := false
						var tl := 0.0
						var dy := 0.0
						for _i in 2:   # 움직이는 발판은 내려앉을 때의 높이로(두 번 고쳐 잡는다)
							dy = _plank_y_at(nx, time + tl) - fl
							dbl = dy > TgD.JUMP_V * TgD.JUMP_V / (2.0 * TgD.GRAVITY) - 20.0
							tl = _land_time2(dy) if dbl else _fall_time(dy)
						if (dist >= float(nx.x) - speed * (tl - late) and float(nx.x) > dist) or (standing and dist > x1 - 15.0):
							if from_ground:
								it.jumped = true
							_bot_jump(dbl)
							return
			"kkochi", "coin", "bigcoin", "big", "honey", "sansam", "club", "box":
				var y := float(it.y)
				if y > fl + TgD.FOX_H + 10.0 and on_ground():   # 서서는 안 닿는다 — 꼭대기에서 닿게 뛴다
					var dbl := y - fl > 300.0
					var tt := air2_peak() if dbl else half
					if d > 0.0 and d <= speed * (tt - late) and not it.has("jumped") and _bot_clear(d + speed * 0.4):
						it.jumped = true
						_bot_jump(dbl)
						return
	# 높은 떡 — 떡 하나하나가 아니라 "앞에 높은 떡이 있다"로만(떡마다 뛰면 바닥에 못 붙는다).
	# 앞에 장애물이 있으면 뛰지 않는다 — 장애물 위 궤적의 떡을 보고 일찍 뛰어 정작 장승 · 가지 앞에서 공중이었다
	if on_ground() and not need_slide and _bot_clear(speed * 1.6):
		for it: Dictionary in items:
			if it.gone or it.kind != "ember":
				continue
			var y2 := float(it.y)
			var d2 := float(it.x) - dist
			if y2 > fl + TgD.FOX_H + 10.0 and d2 > speed * 0.15 and d2 <= speed * (half - late) * 0.85:
				if not it.has("seen"):
					it.seen = rng.randf() >= miss
				if bool(it.seen):
					_bot_jump(y2 - fl > 300.0)
					return
				break
	slide(need_slide)


## 봇 — x 다음에 시작하는 가장 가까운 발판(없으면 빈 사전). 틈이 점프 한 번보다 넓으면 이어진 것으로 안 본다.
func _next_plank(x: float) -> Dictionary:
	var best := {}
	var bx := 1e12
	for it: Dictionary in items:
		if it.kind != "plank" or it.gone or it.has("falling"):
			continue
		var x0 := float(it.x) - float(it.w) * 0.5
		if x0 > x - 1.0 and x0 < bx and x0 - x < speed * 0.9:
			bx = x0
			best = it
	return best


## 발판의 시각 tt 때 높이(오르내리는 발판은 미리 계산, 아니면 그대로).
func _plank_y_at(it: Dictionary, tt: float) -> float:
	if it.has("base"):
		return float(it.base) + TgD.MOVE_AMP * sin(TAU * tt / TgD.MOVE_PER + float(it.ph))
	return float(it.y)


## 봇 — 2단 점프(첫 꼭대기에서 한 번 더)로 dy 위에 내려앉기까지 걸리는 시간.
func _land_time2(dy: float) -> float:
	var h1 := TgD.JUMP_V * TgD.JUMP_V / (2.0 * TgD.GRAVITY)
	return TgD.JUMP_V / TgD.GRAVITY + _fall_time(dy - h1)


## 봇 — 한 번 뛰어 dy 위(음수면 아래)에 내려앉기까지 걸리는 시간(내려오는 쪽 근).
func _fall_time(dy: float) -> float:
	var a := 0.5 * TgD.GRAVITY
	var disc := TgD.JUMP_V * TgD.JUMP_V - 4.0 * a * maxf(dy, -2000.0)
	if disc < 0.0:
		return TgD.JUMP_V / TgD.GRAVITY
	return (TgD.JUMP_V + sqrt(disc)) / TgD.GRAVITY


## 봇 — 지금부터 span 앞까지 장애물(넘을 것 · 숙일 것)이 없나.
func _bot_clear(span: float) -> bool:
	for it: Dictionary in items:
		if it.gone or not (it.kind in ["low", "high", "tall", "pit", "flyer"]):
			continue
		# 가운데가 아니라 앞뒤 가장자리로 — 폭 1500 짜리 허공 구간은 가운데가 멀어 입구가 코앞인데도 비었다고 봤다
		var c := (float(it.meet) if it.kind == "flyer" else float(it.x)) - dist
		var hw := float(it.w) * 0.5
		if c + hw > -TgD.FOX_W and c - hw < span:
			return false
	return true


func _bot_jump(double: bool) -> void:
	slide(false)
	jump()
	_bot_double = double
