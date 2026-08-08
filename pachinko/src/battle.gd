class_name Battle
extends RefCounted

## 해전 컷신 — 이순신이 화면 한가운데 서고, 왜구가 수평선에서 정면으로 몰려온다.
##
## 적 위치는 화면 좌표가 아니라 깊이 Z(1 = 수평선, 0 = 코앞)와 좌우 치우침 Lx 로 잡는다.
## 그릴 때는 먼 것부터(Z 내림차순) 정렬해야 앞뒤가 맞는다.

enum St { INTRO, RUSH, FIGHT, CLEAR, PROMOTE, VERDICT, RESULT, DONE }

var active := false
var finished := false
var speed := 1.0

var _g: Game
var run: Game.BattleRun
var _fx: Fx
var _st := St.INTRO
var _t := 0.0
var _dur := 0.0
var _time := 0.0

var _foes: Array = []
var _slashes: Array = []
var _spawn_acc := 0.0
var _slash_acc := 0.0
var _cannon_acc := 0.0
## 올려베기 한 번 — 감기(-1) → 중간(0) → 마무리(+1).
##
## 쉴 때는 마무리 자세(칼을 위로 든 상태)로 돌아간다. 감긴 자세로 쉬면 칼끝이
## 화면 아래 조작대에 파묻힌다. 그래서 한 번의 베기는 두 토막이다 —
## 앞의 SWING_WIND 동안 지금 자세에서 아래로 감고, 나머지 동안 위로 쓸어 올린다.
const SWING_DUR := 0.20
## 감는 데 쓰는 비율
const SWING_WIND := 0.34
## 쉴 때 돌아갈 자세. 마무리(+1)는 왼쪽 위라 그대로 멈추면 칼이 머리를 가린다.
## 조금 되돌려 오른쪽 어깨 위에 비스듬히 걸친 자세로 쉰다.
const REST_SWING := 0.30
## 이 깊이 안까지 들어온 적이 있으면 리듬을 기다리지 않고 즉시 벤다.
## 타이머만 믿으면 적이 옆을 지나갈 때까지 칼이 안 나간다.
const STRIKE_Z := 0.46
var _swing := 0.0
var _swing_p := 0.0
var _swing_from := 0.0
var _swing_live := false
var _impacted := false
var _slash_n := 0

## 광클 보너스
## 연타에는 상한이 없다. 게이지 한 바퀴가 이만큼이고, 다 돌면 색이 밝아지며 다시 찬다.
const MASH_LAP := 100
var mash := 0
var mash_pop := 0.0

var kill_shown := 0
var _kill_from := 0
var _kill_to := 0
var pay_shown := 0.0
var _pay_from := 0.0
var _pay_to := 0.0
var _combo := 0
var _combo_t := 0.0

var _promote_ok := false
var _promote_charge := 0.0
var _drum_acc := 0.0
var _edge := false
var _new_group := false

var _banner_t := 0.0
var _banner_big := ""
var _banner_sub := ""
var _banner_c := P.GOLD

var sw := 1460.0
var sh := 920.0
var bar_y := 780.0


func horizon() -> float:
	return sh * 0.40

# ==================== 시작 ====================

func begin(game: Game, r: Game.BattleRun, fx: Fx, L: Lay) -> void:
	_g = game
	run = r
	_fx = fx
	if L != null and L.w > 0.0:
		sw = L.w
		sh = L.h
		bar_y = L.bar.position.y
	active = true
	finished = false
	speed = 1.0
	_foes.clear()
	_slashes.clear()
	kill_shown = run.kills
	_kill_from = run.kills
	_kill_to = run.kills
	pay_shown = run.payout
	_pay_from = run.payout
	_pay_to = run.payout
	_slash_n = 0
	_combo = 0
	_enter_intro()


func _enter_intro() -> void:
	_st = St.INTRO
	var first := run.tier == run.start_tier
	_new_group = first or run.tier == 0 or D.tier_group(run.tier - 1) != D.tier_group(run.tier)
	_t = 0.0
	_dur = 2.3 if first else (1.5 if _new_group else 0.75)
	_banner_big = D.tier_name(run.tier) if _new_group else D.PHASE_NAME[D.tier_phase(run.tier)]
	if _new_group:
		_banner_sub = "%d  ·  %s" % [D.GRP_YEAR[D.tier_group(run.tier)],
				D.GRP_SUB[D.tier_group(run.tier)]]
	else:
		_banner_sub = "%s  ·  왜선 %d척" % [D.tier_full(run.tier), D.tier_ships(run.tier)]
	_banner_c = D.tier_color(run.tier)
	_banner_t = 0.0
	Snd.music(Snd.BATTLE, first)
	Snd.duck(0.55)
	if _new_group:
		Snd.horn()
		_fx.flash(P.mix(Color.WHITE, _banner_c, 0.55), 0.52)
		_fx.shake(9.0)
	else:
		Snd.drum(0.0, 1.1)
		_fx.shake(5.0)


func _enter_rush() -> void:
	_st = St.RUSH
	_t = 0.0
	_dur = 1.15
	_foes.clear()
	for i in _on_screen():
		_spawn(true)
	Snd.drum(0.0, 1.0)


func _enter_fight() -> void:
	_st = St.FIGHT
	_t = 0.0
	_dur = 1.7 + pow(D.tier_ships(run.tier), 0.42) * 0.30
	_kill_from = run.kills
	_kill_to = run.kills + D.tier_ships(run.tier)
	_pay_from = run.payout
	_pay_to = run.pay_at(run.tier)
	Snd.duck(0.75)


func _enter_clear() -> void:
	_st = St.CLEAR
	_t = 0.0
	_dur = 0.85
	run.kills = _kill_to
	run.payout = int(round(_pay_to))
	kill_shown = _kill_to
	pay_shown = _pay_to
	_banner_big = "%s 돌파" % D.PHASE_NAME[D.tier_phase(run.tier)]
	_banner_sub = "왜선 %d척 격침" % D.tier_ships(run.tier)
	_banner_c = P.GOLD_HI
	_banner_t = 0.0
	Snd.fanfare(mini(3, D.tier_group(run.tier)))
	_fx.flash(P.GOLD_HI, 0.30)
	_fx.shake(10.0)
	_fx.coin_rain(sw, 18)


func _enter_promote() -> void:
	if run.tier >= D.TIERS - 1:
		_enter_result()
		return
	_st = St.PROMOTE
	_t = 0.0
	_edge = D.is_group_edge(run.tier)
	_dur = 2.0 if _edge else 1.15
	_promote_charge = 0.0
	_drum_acc = 0.0
	_promote_ok = _g.roll_promotion(run)
	Snd.duck(0.35 if _edge else 0.55)


func _enter_verdict() -> void:
	_st = St.VERDICT
	_t = 0.0
	_dur = (1.5 if _edge else 0.8) if _promote_ok else 1.0
	if _promote_ok:
		var nx := run.tier + 1
		Snd.level_up(D.tier_group(nx))
		_fx.flash(P.GOLD_HI, 0.62 if _edge else 0.36)
		_fx.shake(20.0 if _edge else 10.0)
		_fx.wave(Vector2(sw * 0.5, sh * 0.42), P.GOLD, sw * 0.6, 1.1, 12.0)
		_banner_big = "다 음 전 장" if _edge else "진 격"
		_banner_sub = D.tier_full(nx)
		_banner_c = D.tier_color(nx)
	else:
		Snd.near()
		_banner_big = "전 열 정 비"
		_banner_sub = "해전을 마칩니다"
		_banner_c = P.DIM
	_banner_t = 0.0


func _enter_result() -> void:
	_st = St.RESULT
	_t = 0.0
	_dur = 3.6
	run.kills = _kill_to
	run.payout = run.pay_at(run.max_tier) + run.bonus
	kill_shown = run.kills
	pay_shown = run.payout
	Snd.music(Snd.VICTORY, true)
	Snd.duck(1.0)
	Snd.fanfare(3)
	_fx.flash(P.GOLD_HI, 0.48)
	_fx.coin_rain(sw, 90)

# ==================== 진행 ====================

func update(dt_real: float) -> void:
	if not active:
		return
	var dt := dt_real * speed
	_time += dt
	_t += dt

	for i in range(_foes.size() - 1, -1, -1):
		var f: Dictionary = _foes[i]
		if f["dead"] > 0.0:
			f["dead"] = minf(1.4, f["dead"] + dt * 2.8)
			f["alpha"] = maxf(0.0, 1.0 - (f["dead"] - 0.4) * 1.7)
			if f["alpha"] <= 0.01:
				_foes.remove_at(i)
			continue
		f["z"] -= f["sp"] * dt
		f["lx"] += signf(f["lx"]) * dt * 0.10 * (1.0 - f["z"])
		if f["z"] <= 0.24:
			f["dead"] = 0.01
			_combo += 1
			_combo_t = 1.1

	for i in range(_slashes.size() - 1, -1, -1):
		_slashes[i]["p"] += dt * 2.6
		if _slashes[i]["p"] >= 1.0:
			_slashes.remove_at(i)

	match _st:
		St.INTRO: _tick_intro(dt)
		St.RUSH: _tick_rush(dt)
		St.FIGHT: _tick_fight(dt)
		St.CLEAR: _tick_clear(dt)
		St.PROMOTE: _tick_promote(dt)
		St.VERDICT: _tick_verdict(dt)
		St.RESULT: _tick_result(dt)

	_banner_t += dt_real
	if _combo_t > 0.0:
		_combo_t -= dt
	else:
		_combo = 0

	if mash_pop > 0.0:
		mash_pop = maxf(0.0, mash_pop - dt * 4.0)

	if _swing_live:
		var prev := _swing
		_swing_p += dt / SWING_DUR
		if _swing_p >= 1.0:
			_swing_p = 1.0
			_swing_live = false
		if _swing_p < SWING_WIND:
			# 감기 — 지금 자세가 어디든 거기서 아래로 말아 내린다
			_swing = lerpf(_swing_from, -1.0, G2.in_quad(_swing_p / SWING_WIND))
		else:
			_swing = lerpf(-1.0, 1.0,
					G2.out_quint((_swing_p - SWING_WIND) / (1.0 - SWING_WIND)))
		# 칼날이 호의 한가운데를 지나는 순간이 곧 베는 순간이다.
		# 고정된 시점 대신 이렇게 잡아야 이징을 바꿔도 싱크가 안 깨진다.
		if not _impacted and ((prev < 0.0 and _swing >= 0.0) or not _swing_live):
			_impacted = true
			_impact()
	else:
		_swing = move_toward(_swing, REST_SWING, dt * 2.4)


func _tick_intro(_dt: float) -> void:
	if _t >= _dur * 0.45 and _foes.is_empty():
		for i in 4:
			_spawn(true)
	if _t >= _dur:
		_enter_rush()


func _tick_rush(dt: float) -> void:
	_cannon_acc += dt
	if _cannon_acc > 0.30:
		_cannon_acc = 0.0
		Snd.cannon(randf_range(-0.7, 0.7))
		var p := Vector2(randf_range(sw * 0.16, sw * 0.84), randf_range(horizon() + 30.0, sh * 0.70))
		_fx.burst(p, 14, P.ORANGE, P.CRIMSON_DEEP, 240.0, 7.0)
		_fx.wave(p, P.ORANGE, 130.0, 0.5, 5.0)
		_fx.shake(5.0)
	if _t >= _dur:
		_enter_fight()


func _tick_fight(dt: float) -> void:
	var u := clampf(_t / _dur, 0.0, 1.0)
	var curve := u * u * (3.0 - 2.0 * u)          # 후반으로 갈수록 몰아친다
	var k := _kill_from + int(round((_kill_to - _kill_from) * curve))
	if k != kill_shown:
		if k > kill_shown + 2:
			Snd.kill(_combo)
		kill_shown = k
	pay_shown = _pay_from + (_pay_to - _pay_from) * curve

	# 코앞까지 온 놈이 있으면 리듬을 무시하고 바로 휘두른다
	var urgent := false
	for f: Dictionary in _foes:
		if f["dead"] <= 0.0 and f["z"] <= STRIKE_Z:
			urgent = true
			break
	_slash_acc += dt
	if (urgent and not _swing_live) or _slash_acc >= 0.22 - 0.10 * u:
		_slash_acc = 0.0
		_do_slash()

	_spawn_acc += dt
	if _spawn_acc > 0.12:
		_spawn_acc = 0.0
		if _alive() < _on_screen():
			_spawn(false)

	_cannon_acc += dt
	if _cannon_acc > 0.9 - u * 0.4:
		_cannon_acc = 0.0
		var p := Vector2(randf_range(sw * 0.14, sw * 0.86), randf_range(horizon() + 20.0, sh * 0.72))
		Snd.boom(randf_range(-0.6, 0.6), 0.8)
		_fx.burst(p, 20, P.GOLD_HI, P.CRIMSON_DEEP, 300.0, 9.0)
		_fx.burst(p, 8, Color8(120, 120, 130), Color8(60, 60, 70), 90.0, 16.0, Fx.Kind.SMOKE)
		_fx.wave(p, P.ORANGE, 180.0, 0.6, 6.0)
		_fx.shake(7.0)

	if _t >= _dur:
		_enter_clear()


## 휘두르기 시작 — 칼바람만 먼저 난다. 실제로 베는 건 _impact() 다.
func _do_slash() -> void:
	_slash_n += 1
	_swing_p = 0.0
	_swing_from = _swing
	_swing_live = true
	_impacted = false
	Snd.swoosh(_slash_n)


## 칼날이 목표에 닿는 순간
func _impact() -> void:
	Snd.slash(_slash_n)

	# 가장 가까이 온 놈부터 벤다
	var alive: Array = []
	for f: Dictionary in _foes:
		if f["dead"] <= 0.0:
			alive.append(f)
	alive.sort_custom(func(a, b): return a["z"] < b["z"])
	# 사정권(STRIKE_Z) 안에 든 놈은 무조건 베고, 그 뒤로 한두 놈을 덤으로 벤다.
	# 개수만 세면 코앞의 적을 남겨 둔 채 뒷놈을 베는 일이 생긴다.
	var extra := 1 + randi() % 3
	var hit := 0
	for f: Dictionary in alive:
		if f["z"] > STRIKE_Z:
			if extra <= 0:
				break
			extra -= 1
		f["dead"] = 0.01
		hit += 1
		_combo += 1
		_combo_t = 1.1
		var sp := _project(f)
		_fx.burst(sp["p"] - Vector2(0, sp["s"] * 0.4), 10, P.CRIMSON, P.CRIMSON_DEEP, 190.0, 5.0)
		if f["ship"]:
			Snd.boom(clampf((sp["p"].x - sw * 0.5) / (sw * 0.5), -1.0, 1.0), 0.7)
			_fx.burst(sp["p"], 18, P.ORANGE, P.CRIMSON_DEEP, 260.0, 9.0, Fx.Kind.DEBRIS)
			_fx.wave(sp["p"], P.ORANGE, 150.0, 0.55, 6.0)
			_fx.shake(6.0)
	if hit > 0:
		Snd.kill(_combo)
		_fx.shake(3.5)
		if _combo % 10 == 0:
			_fx.text(Vector2(randf_range(sw * 0.30, sw * 0.70),
					randf_range(horizon(), sh * 0.62)), "%d 연참!" % _combo, P.GOLD_HI, 26.0, true)

	if _slashes.size() < 4:
		_slashes.append({
			"c": Vector2(randf_range(sw * 0.16, sw * 0.84),
					randf_range(horizon() + 40.0, sh * 0.76)),
			"a": randf_range(-0.95, 0.95), "p": 0.0,
		})


## 해전 중 버튼을 연타하면 보너스가 쌓인다. 받아들였으면 true.
func mash_hit() -> bool:
	# 결과 화면만 빼고 언제든 받는다 — 판정 중에도 계속 두드리게
	if _st == St.RESULT or _st == St.DONE:
		return false
	mash += 1
	mash_pop = 1.0
	run.bonus = int(round(mash * run.bet * 0.04))
	Snd.mash(mash)
	_fx.shake(1.6)
	var p := Vector2(sw * 0.5 + randf_range(-60.0, 60.0), bar_y - 150.0)
	_fx.burst(p, 3, P.GOLD_HI, P.ORANGE, 150.0, 4.0)
	if mash % 20 == 0:
		_fx.text(Vector2(sw * 0.5, bar_y - 200.0), "연타 %d!" % mash, P.ORANGE, 22.0, true)
	return true


func _tick_clear(_dt: float) -> void:
	for f: Dictionary in _foes:
		if f["dead"] <= 0.0:
			f["dead"] = 0.01
	if _t >= _dur:
		_enter_promote()


func _tick_promote(dt: float) -> void:
	_promote_charge = clampf(_t / (_dur * 0.86), 0.0, 1.0)
	_drum_acc += dt
	if _drum_acc >= 0.34 - _promote_charge * 0.26:
		_drum_acc = 0.0
		Snd.drum(0.0, 0.6 + _promote_charge * 0.8)
		_fx.shake(2.0 + _promote_charge * 5.0)
	if _t >= _dur:
		_enter_verdict()


func _tick_verdict(_dt: float) -> void:
	if _t < _dur:
		return
	if _promote_ok:
		run.tier += 1
		if run.tier > run.max_tier:
			run.max_tier = run.tier
		_enter_intro()
	else:
		_enter_result()


func _tick_result(_dt: float) -> void:
	if _t >= _dur:
		dismiss()


func can_dismiss() -> bool:
	return _st == St.RESULT and _t > 1.0


func dismiss() -> void:
	_st = St.DONE
	active = false
	finished = true
	Snd.duck(1.0)

# ==================== 적 ====================

func _on_screen() -> int:
	return mini(26, 11 + run.tier)


func _alive() -> int:
	var n := 0
	for f: Dictionary in _foes:
		if f["dead"] <= 0.0:
			n += 1
	return n


func _spawn(spread: bool) -> void:
	var lx := randf_range(-1.0, 1.0)
	# 가운데(장군 정면)는 비켜 놓아야 시야가 가리지 않는다
	if absf(lx) < 0.30:
		lx = signf(lx if lx != 0.0 else 1.0) * randf_range(0.30, 0.62)
	var ship := randf() < 0.34
	_foes.append({
		"lx": lx, "z": randf_range(0.34, 1.0) if spread else randf_range(0.92, 1.0),
		"sp": randf_range(0.13, 0.20) if ship else randf_range(0.20, 0.32),
		"dead": 0.0, "alpha": 1.0, "ship": ship, "seed": randf() * 100.0,
	})


## 깊이에서 화면 좌표와 크기를 계산한다.
## z 를 0..1 로 묶지 않으면 pow(음수) 가 NaN 을 내고 변환 행렬이 깨진다.
func _project(f: Dictionary) -> Dictionary:
	var z := clampf(f["z"], 0.0, 1.0)
	var near := 1.0 - z
	var spread := 0.17 + 0.83 * (near * near)
	var k := 0.30 + 1.25 * (near * near)
	return {
		"p": Vector2(sw * 0.5 + f["lx"] * spread * sw * 0.62,
				horizon() + 8.0 + pow(near, 1.55) * (sh - horizon() - sh * 0.10)),
		"s": (sh * 0.085 if f["ship"] else sh * 0.070) * k,
	}

# ==================== 그리기 ====================

func draw(ci: CanvasItem, L: Lay, t: float) -> void:
	var tier_u := float(D.tier_group(run.tier)) / 3.0

	# 하늘 — 단계가 오를수록 붉어진다
	G2.grad_round(ci, Rect2(0, 0, L.w, L.h), 0.0,
			P.mix(Color8(10, 14, 36), Color8(72, 12, 22), tier_u),
			P.mix(Color8(22, 44, 88), Color8(150, 44, 30), tier_u), 16)

	# 수평선에 번지는 노을. 붉은 원반 + 방사선은 특정 군기 도안이 되므로 쓰지 않는다.
	var hz := horizon()
	var warm := P.mix(P.ORANGE, P.CRIMSON, tier_u)
	var sun_p := 0.5 + 0.5 * sin(t * 1.6)
	G2.glow(ci, Vector2(L.w * 0.64, hz - 6.0), L.w * 0.42, L.h * 0.20, warm,
			0.34 + 0.10 * sun_p + tier_u * 0.16)
	G2.glow(ci, Vector2(L.w * 0.22, hz + 8.0), L.w * 0.24, L.h * 0.12, warm, 0.16 + tier_u * 0.10)

	# 바다
	for layer in 5:
		var base_y := hz + 26.0 + layer * (L.h - hz) * 0.19
		var pts := PackedVector2Array()
		var x := -40.0
		while x <= L.w + 60.0:
			pts.append(Vector2(x, base_y + sin(x * 0.013 + t * (0.9 + layer * 0.55) + layer)
					* (7.0 + layer * 5.0)))
			x += 30.0
		pts.append(Vector2(L.w + 60.0, L.h + 40.0))
		pts.append(Vector2(-40.0, L.h + 40.0))
		G2.fill(ci, pts, P.a(P.mix(P.SEA1, Color8(120, 30, 34), tier_u * 0.6), 0.42))

	# 적 — 먼 것부터
	var order := _foes.duplicate()
	order.sort_custom(func(a, b): return a["z"] > b["z"])
	for f: Dictionary in order:
		var sp := _project(f)
		var haze := clampf(1.0 - f["z"] * 0.70, 0.0, 1.0)
		var a: float = f["alpha"] * (0.50 + 0.50 * haze)
		if f["ship"]:
			Art.enemy_ship(ci, sp["p"], sp["s"], t + f["seed"], a)
		else:
			Art.wako_soldier(ci, sp["p"], sp["s"], t + f["seed"], minf(1.0, f["dead"]), a)

	# 이순신 — 화면 한가운데
	var intro := G2.out_back(clampf(_t / 0.7, 0.0, 1.0)) if _st == St.INTRO else 1.0
	var asz := L.h * 0.118 * intro
	var ay := bar_y - 14.0 - asz * 1.30
	if asz > 1.0:
		Art.deck(ci, Vector2(L.w * 0.5, ay + asz * 1.28), asz * 3.6, t)
		# 잔상은 칼이 호의 한가운데를 지날 때 가장 짙다
		var tr := clampf(1.0 - absf(_swing) * 1.5, 0.0, 1.0) if _swing_live else 0.0
		G2.glow(ci, Vector2(L.w * 0.5, ay - asz * 0.4), asz * 1.9, asz * 1.9, P.GOLD,
				0.18 + tr * 0.34)
		Art.admiral_full(ci, Vector2(L.w * 0.5, ay), asz, t, _swing, tr)

	for s: Dictionary in _slashes:
		Art.slash(ci, s["c"], L.w * 0.15, s["a"], s["p"], P.GOLD_HI)

	_draw_hud(ci, L, t)

	match _st:
		St.INTRO, St.CLEAR: _draw_banner(ci, L, t, 1.0)
		St.PROMOTE: _draw_promote(ci, L, t)
		St.VERDICT: _draw_banner(ci, L, t, 1.35 if _promote_ok else 0.9)
		St.RESULT: _draw_result(ci, L, t)

	if _st != St.RESULT and _st != St.DONE:
		_draw_mash(ci, L, t)


## 연타 보너스 — 누르는 만큼 차오르고 금액이 붙는다
func _draw_mash(ci: CanvasItem, L: Lay, t: float) -> void:
	var w := L.w * 0.30
	var r := Rect2(L.w * 0.5 - w * 0.5, bar_y - 78.0, w, 46.0)
	# 상한이 없으므로 게이지는 한 바퀴씩 돈다. 바퀴가 늘수록 밝아진다.
	var lap := mash / MASH_LAP
	var u := float(mash % MASH_LAP) / MASH_LAP
	var heat: float = minf(1.6, lap * 0.28)
	var pulse := 0.7 + 0.3 * sin(t * 9.0) if lap > 0 else 1.0

	G2.fill_round(ci, r, 10.0, P.a(Color8(6, 8, 20), 0.72))
	if u > 0.01:
		G2.grad_round(ci, Rect2(r.position, Vector2(r.size.x * u, r.size.y)), 10.0,
				P.hdr(P.GOLD_HI, 1.5 + heat), P.hdr(P.ORANGE, 1.2 + heat), 6)
	G2.stroke_round(ci, r, 10.0,
			P.hdr(P.GOLD if lap == 0 else P.GOLD_HI, (1.0 + mash_pop * 1.4 + heat) * pulse), 2.0)

	var lab := "버튼을 연타하라!" if mash == 0 else "연타 %d회" % mash
	G2.text_mid(ci, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 15.0), lab,
			12.0 + mash_pop * 3.0, P.a(P.WHITE, 0.9))
	G2.text_mid(ci, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 36.0),
			"+%s" % P.n(run.bonus), 19.0 + mash_pop * 6.0, P.hdr(P.GOLD_HI, 1.4))


func _draw_hud(ci: CanvasItem, L: Lay, t: float) -> void:
	var w: float = minf(940.0, L.w - 80.0)
	var r := Rect2((L.w - w) * 0.5, L.frame * 2.0 + 12.0, w, 118.0)
	G2.fill_round(ci, r, 14.0, P.a(Color8(6, 8, 20), 0.67))
	G2.stroke_round(ci, r, 14.0, P.hdr(D.tier_color(run.tier), 1.3), 2.0)

	var tw := (w - 40.0) / 4.0
	for gi in 4:
		var tr := Rect2(r.position.x + 20.0 + gi * tw, r.position.y + 8.0, tw - 10.0, 24.0)
		var gc: Color = D.GRP_COLOR[gi]
		var any := run.max_tier >= gi * D.PHASES
		G2.fill_round(ci, tr, 6.0, P.a(gc if any else P.PANEL, 0.30 if any else 0.55))
		G2.stroke_round(ci, tr, 6.0, P.a(gc, 0.8 if any else 0.25), 1.2)
		G2.text_mid(ci, Vector2(tr.position.x + tr.size.x * 0.31, tr.position.y + 12.0),
				D.GRP_NAME[gi], 11.0, P.WHITE if any else P.a(P.DIMMER, 0.85))
		for p in D.PHASES:
			var tier := gi * D.PHASES + p
			var done := run.max_tier >= tier
			var now := run.tier == tier
			ci.draw_circle(Vector2(tr.position.x + tr.size.x * 0.68 + p * 9.0,
					tr.position.y + 12.0), 3.6 if now else 2.8,
					P.hdr(gc, 1.6) if done else P.a(P.DIMMER, 0.3))

	var kp := 1.0 + (0.10 * maxf(0.0, sin(_time * 22.0)) if _st == St.FIGHT else 0.0)
	G2.text(ci, Vector2(r.position.x + 26.0, r.position.y + 56.0), "처단", 13.0,
			P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	G2.text(ci, Vector2(r.position.x + 90.0, r.position.y + 92.0), P.n(kill_shown), 40.0 * kp,
			P.hdr(Color.WHITE, 1.4), HORIZONTAL_ALIGNMENT_LEFT)
	G2.text(ci, Vector2(r.position.x + 210.0, r.position.y + 86.0), "척", 15.0,
			P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)

	G2.text(ci, Vector2(r.end.x - 240.0, r.position.y + 56.0), "배당", 13.0,
			P.a(P.DIM, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	var pp := 1.0 + (0.08 * maxf(0.0, sin(_time * 19.0)) if _st == St.FIGHT else 0.0)
	var amt := P.n(pay_shown)
	G2.text(ci, Vector2(r.end.x - 26.0 - G2.text_width(amt, 42.0 * pp), r.position.y + 94.0),
			amt, 42.0 * pp, P.hdr(P.GOLD_HI, 1.6), HORIZONTAL_ALIGNMENT_LEFT)

	if _combo >= 5 and _combo_t > 0.0:
		G2.text_mid(ci, Vector2(L.w * 0.5, r.end.y + 24.0), "%d 연참" % _combo, 20.0,
				P.a(P.hdr(P.ORANGE, 1.4), clampf(_combo_t * 2.0, 0.0, 1.0)))


func _draw_banner(ci: CanvasItem, L: Lay, t: float, scale: float) -> void:
	var a := clampf(_banner_t * 3.0, 0.0, 1.0) * (1.0 - clampf((_banner_t - 1.5) / 0.6, 0.0, 1.0))
	if a <= 0.01:
		return
	var cy := L.h * 0.46
	var pop := G2.out_back(clampf(_banner_t * 2.2, 0.0, 1.0))
	ci.draw_rect(Rect2(0, cy - 74.0, L.w, 148.0), P.a(Color8(4, 6, 16), a * 0.62))
	G2.glow(ci, Vector2(L.w * 0.5, cy), L.w * 0.26, 90.0, _banner_c, a * 0.42)
	for sy in [cy - 74.0, cy + 74.0]:
		ci.draw_line(Vector2(0, sy), Vector2(L.w, sy), P.a(P.hdr(_banner_c, 1.5), a), 3.0)
	G2.text_outline(ci, Vector2(L.w * 0.5, cy - 14.0), _banner_big,
			62.0 * scale * (0.6 + 0.4 * pop),
			P.a(P.hdr(Color.WHITE, 1.3), a), P.a(P.darken(_banner_c, 0.55), a), 3.2)
	G2.text_mid(ci, Vector2(L.w * 0.5, cy + 46.0), _banner_sub, 19.0 * scale,
			P.a(P.hdr(_banner_c, 1.2), a))


func _draw_promote(ci: CanvasItem, L: Lay, _t: float) -> void:
	var c := Vector2(L.w * 0.5, L.h * 0.31)
	ci.draw_rect(Rect2(0, 0, L.w, L.h), P.a(Color8(4, 6, 16), 0.6))
	G2.text_mid(ci, c - Vector2(0, 132.0), "진 격 판 정" if not _edge else "다 음 전 장 ?",
			24.0, P.WHITE)

	var rad := 86.0
	G2.stroke(ci, G2.circle(c, rad, 48), P.a(P.DIMMER, 0.5), 8.0)
	var col := P.mix(P.CRIMSON, P.GOLD_HI, _promote_charge)
	var arc := PackedVector2Array()
	for i in 49:
		var a := -PI * 0.5 + TAU * _promote_charge * i / 48.0
		arc.append(c + Vector2(cos(a), sin(a)) * rad)
	if arc.size() >= 2:
		ci.draw_polyline(arc, P.hdr(col, 1.6), 9.0, true)
	G2.glow(ci, c, rad * 1.9, rad * 1.9, col, 0.28 + _promote_charge * 0.45)

	var beat := 1.0 + 0.12 * sin(_time * (8.0 + _promote_charge * 22.0))
	G2.text_mid(ci, c, "?", 46.0 * beat, P.hdr(P.GOLD_HI, 1.5))

	var nx := mini(D.TIERS - 1, run.tier + 1)
	G2.text_mid(ci, c + Vector2(0, 128.0),
			"%s   ·   %s" % [D.tier_full(nx), P.n(D.tier_total(nx) * run.bet)], 16.0,
			P.a(D.tier_color(nx), 0.5 + 0.5 * _promote_charge))
	G2.text_mid(ci, c + Vector2(0, 156.0), "진격 확률 %d%%"
			% int(D.promote_chance(run.tier, run.scatters, run.spirit_t) * 100.0),
			13.0, P.a(P.DIM, 0.8))


func _draw_result(ci: CanvasItem, L: Lay, t: float) -> void:
	var a := clampf(_t * 2.0, 0.0, 1.0)
	ci.draw_rect(Rect2(0, 0, L.w, L.h), P.a(Color8(4, 6, 18), a * 0.72))
	var c := Vector2(L.w * 0.5, L.h * 0.42)
	G2.glow(ci, c, L.w * 0.34, L.h * 0.30, P.GOLD, a * 0.40)
	for i in 3:
		var rr := L.h * (0.22 + i * 0.09) + sin(t * 1.1 + i) * 8.0
		G2.stroke(ci, G2.circle(c, rr, 64), P.a(P.hdr(P.GOLD, 1.4), a * (0.20 - i * 0.05)), 2.5 - i * 0.6)

	var pop := G2.out_back(clampf(_t * 1.8, 0.0, 1.0))
	G2.text_mid(ci, c - Vector2(0, 118.0), "%s 대승" % D.tier_full(run.max_tier), 30.0,
			P.a(P.WHITE, a))
	G2.text_outline(ci, c - Vector2(0, 20.0), P.n(run.payout), 96.0 * (0.5 + 0.5 * pop),
			P.a(P.hdr(P.GOLD_HI, 1.7), a), P.a(P.GOLD_DEEP, a), 4.0)
	G2.text_mid(ci, c + Vector2(0, 62.0), "왜선 %s척 격침   ·   총배팅 %d배"
			% [P.n(run.kills), int(D.tier_total(run.max_tier))], 19.0, P.a(P.GOLD, a))
	if run.bonus > 0:
		G2.text_mid(ci, c + Vector2(0, 92.0), "연타 보너스 %d회   +%s" % [mash, P.n(run.bonus)],
				17.0, P.a(P.hdr(P.ORANGE, 1.3), a))
	if _t > 1.2:
		G2.text_mid(ci, Vector2(c.x, bar_y - 40.0), "Space — 계속", 15.0,
				P.a(P.DIM, clampf((_t - 1.2) * 2.0, 0.0, 1.0) * (0.5 + 0.5 * sin(_time * 4.0))))
