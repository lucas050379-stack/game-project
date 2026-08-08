extends Node2D

## 메인 화면 — 캐비닛, 릴, 패널, 스핀 흐름.
##
## 발광은 색 값을 1.0 위로 올려 엔진 블룸에 맡긴다 (P.hdr).

enum Phase { IDLE, SPINNING, PAYOUT, BATTLE, BANKRUPT }

var g := Game.new()
var L := Lay.new()
var reels: Array[Reel] = []
var phase := Phase.IDLE
var t := 0.0
var over_t := 0.0

var res: Game.SpinResult = null
var battle: Game.BattleRun = null
var scene: Battle = null
var fx := Fx.new()

# 스핀 진행
var spin_t := 0.0
var stop_at: Array[float] = []
var antic: Array[bool] = []
var antic_sounded: Array[bool] = []
var hurry := false

# 연출
var highlight := []
var win_cycle := 0
var win_cycle_t := 0.0
var pay_t := 0.0
var last_win := 0
var disp_coins := 0.0
var disp_spirit := 0.0
var disp_win := 0.0
var idle_t := 0.0
var auto := false

# UI
var toast := ""
var toast_t := 0.0
var toast_c := P.GOLD
var help_open := false
var pay_open := false
var mouse := Vector2.ZERO
var buttons: Array = []
var bar_msg_right := 0.0


## 릴 창은 따로 그린다 — _draw() 에는 클리핑이 없어서, 창 밖으로 넘치는 심볼을
## 잘라내려면 clip_contents 를 켠 Control 안에서 그려야 한다.
var reel_layer: Control


func _ready() -> void:
	randomize()
	reel_layer = Control.new()
	reel_layer.clip_contents = true
	reel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_layer.draw.connect(_draw_reels)
	add_child(reel_layer)
	for i in D.REELS:
		var r := Reel.new()
		r.scroll = randi() % D.STRIP_LEN
		reels.append(r)
	stop_at.resize(D.REELS)
	antic.resize(D.REELS)
	antic_sounded.resize(D.REELS)
	for y in D.REELS:
		highlight.append([0.0, 0.0, 0.0])
	disp_coins = g.coins
	_build_ui()
	L.compute(get_viewport_rect().size.x, get_viewport_rect().size.y)
	_layout_ui()

# ==================== 루프 ====================

func _process(dt: float) -> void:
	t += dt
	var vp := get_viewport_rect().size
	L.compute(vp.x, vp.y)
	_layout_ui()

	for r in reels:
		r.update(dt)
	fx.update(dt)

	disp_coins += (g.coins - disp_coins) * minf(1.0, dt * 8.0)
	if absf(disp_coins - g.coins) < 0.6:
		disp_coins = g.coins
	disp_spirit += (g.spirit - disp_spirit) * minf(1.0, dt * 5.0)
	disp_win += (last_win - disp_win) * minf(1.0, dt * 7.0)
	if absf(disp_win - last_win) < 0.6:
		disp_win = last_win
	if toast_t > 0.0:
		toast_t -= dt

	_update_highlight(dt)

	match phase:
		Phase.IDLE: _tick_idle(dt)
		Phase.SPINNING: _tick_spinning(dt)
		Phase.PAYOUT: _tick_payout(dt)
		Phase.BATTLE: _tick_battle(dt)
		Phase.BANKRUPT: over_t += dt

	reel_layer.position = L.win.position
	reel_layer.size = L.win.size
	# 창이 열려 있으면 릴이 그 위를 덮지 않도록 숨긴다 (자식은 부모보다 나중에 그려진다)
	reel_layer.visible = not (pay_open or help_open or phase == Phase.BANKRUPT
			or (scene != null and scene.active))
	reel_layer.queue_redraw()
	queue_redraw()


func _tick_idle(dt: float) -> void:
	idle_t += dt
	if g.coins < Game.min_bet():
		phase = Phase.BANKRUPT
		over_t = 0.0
		auto = false
		Snd.stop_music()
		Snd.bankrupt()
		return
	if g.bet_lowered:
		# 코인이 줄어 상한(보유의 1/10)을 넘게 된 경우 — 자동으로 내려간 것을 알린다
		g.bet_lowered = false
		_toast("코인이 줄어 배팅을 %d × 9 = %s 로 낮췄습니다"
				% [g.bet_per_line(), P.n(g.total_bet())], P.ORANGE)
	if not g.can_spin():
		g.max_bet()
		return
	if auto and idle_t > 0.55:
		_spin()


func _tick_spinning(dt: float) -> void:
	spin_t += dt * (4.0 if hurry else 1.0)
	for i in D.REELS:
		var rv: Reel = reels[i]
		if not rv.spinning:
			continue
		if antic[i] and spin_t > stop_at[i] - 1.15:
			rv.speed = 7.0 + 3.0 * sin(t * 5.0)
		if spin_t >= stop_at[i]:
			rv.land(res.stop[i], 0.62 if antic[i] else 0.40, 3 if antic[i] else 6)
			var hot := res.has_scatter(i)
			Snd.reel_stop(i, hot)
			if hot:
				rv.glow = 1.0
				var sc := 0
				for k in range(i + 1):
					if res.has_scatter(k):
						sc += 1
				Snd.scatter(sc)
				var cp := L.cell_center(i, 1)
				fx.burst(cp, 16, P.VIOLET, P.SEA1, 200.0, 6.0)
				fx.wave(cp, P.VIOLET, L.cell.x * 0.9, 0.6, 5.0)
				fx.shake(4.0)
			else:
				fx.shake(1.6)
		elif antic[i] and not antic_sounded[i] and spin_t > stop_at[i] - 1.15:
			antic_sounded[i] = true
			Snd.tension(i - 1)
			fx.flash(P.VIOLET, 0.14)

	for i in D.REELS:
		var rv2: Reel = reels[i]
		if not rv2.spinning:
			continue
		rv2.tick_acc += dt
		if rv2.tick_acc > 0.072:
			rv2.tick_acc = 0.0
			rv2.tick_n += 1
			var landed := 0
			for k in D.REELS:
				if not reels[k].busy():
					landed += 1
			Snd.reel_tick((i - 2) * 0.35, rv2.tick_n, float(landed) / D.REELS)

	if not _any_reel_busy():
		_begin_payout()


func _begin_payout() -> void:
	phase = Phase.PAYOUT
	pay_t = 0.0
	win_cycle = 0
	win_cycle_t = 0.0
	last_win = res.total
	disp_win = 0.0

	if res.total > 0:
		var mult := float(res.total) / maxf(1.0, res.bet)
		if mult >= 20.0:
			Snd.win_big()
			fx.flash(P.GOLD_HI, 0.45)
			fx.shake(11.0)
			fx.coin_rain(L.w, 34)
		elif mult >= 5.0:
			Snd.win_big()
			fx.shake(5.0)
		else:
			Snd.win_small()
		var to := Vector2(L.bar.position.x + 60.0, L.bar.position.y + L.bar.size.y * 0.62)
		var n: int = mini(26, 5 + int(res.total / maxf(1.0, res.bet / 2.0)))
		for i in n:
			var from := L.cell_center(randi() % D.REELS, randi() % D.ROWS)
			if res.wins.size() > 0:
				var w: Game.LineWin = res.wins[randi() % res.wins.size()]
				var rr := randi() % w.count
				from = L.cell_center(rr, D.LINE[w.line][rr])
			fx.fly_coin(from, to, i * 0.035, 11.0)
		for i in mini(4, res.wins.size()):
			var w2: Game.LineWin = res.wins[i]
			var c := L.cell_center(w2.count - 1, D.LINE[w2.line][w2.count - 1])
			fx.text(c - Vector2(0, 10), "+" + P.n(w2.pay), P.GOLD_HI, 17.0, false)
		if res.scat_pay > 0:
			fx.text(Vector2(L.win.position.x + L.win.size.x * 0.5, L.win.position.y + 30.0),
					"총통 %d개  +%s" % [res.scatters, P.n(res.scat_pay)], P.VIOLET, 21.0, true)


func _tick_payout(dt: float) -> void:
	pay_t += dt
	win_cycle_t += dt
	if win_cycle_t > 1.05 and res.wins.size() > 1:
		win_cycle_t = 0.0
		win_cycle += 1

	var wait := 1.1 if res.jackpot else ((1.0 if auto else 1.5) if res.total > 0 else (0.25 if auto else 0.5))
	if hurry:
		wait *= 0.35
	if pay_t < wait:
		return

	if res.jackpot:
		battle = g.begin_battle(res)
		scene = Battle.new()
		scene.begin(g, battle, fx, L)
		phase = Phase.BATTLE
		return
	phase = Phase.IDLE
	idle_t = 0.0
	hurry = false


func _tick_battle(dt: float) -> void:
	if scene == null:
		phase = Phase.IDLE
		return
	scene.update(dt)
	if not scene.finished:
		return

	g.end_battle(battle)
	last_win = battle.pay_at(battle.max_tier) + battle.bonus
	disp_win = 0.0
	var to := Vector2(L.bar.position.x + 60.0, L.bar.position.y + L.bar.size.y * 0.62)
	for i in 40:
		fx.fly_coin(Vector2(randf_range(L.w * 0.3, L.w * 0.7),
				randf_range(L.h * 0.3, L.h * 0.6)), to, i * 0.02, 12.0)
	fx.coin_rain(L.w, 40)
	_toast("%s 승리 — %s 획득" % [D.tier_full(battle.max_tier), P.n(last_win)], P.GOLD_HI)

	scene = null
	battle = null
	Snd.music(Snd.MAIN, false)
	phase = Phase.IDLE
	idle_t = 0.0
	hurry = false

# ==================== 스핀 ====================

func _spin() -> void:
	if phase != Phase.IDLE or help_open or pay_open:
		return
	if not g.can_spin():
		Snd.deny()
		_toast("코인이 부족합니다", P.CRIMSON)
		return

	Snd.lever()
	fx.shake(2.5)
	res = g.spin()
	last_win = 0
	disp_win = 0.0
	_clear_highlight()
	phase = Phase.SPINNING
	spin_t = 0.0
	hurry = false

	# 정지 시점 — 앞 릴에 총통이 둘 이상이면 뒤 릴을 끌며 애태운다
	var at := 0.80
	var extra := 0.0
	var cum := 0
	for i in D.REELS:
		antic[i] = false
		antic_sounded[i] = false
		if cum >= 2 and i >= 2:
			antic[i] = true
			extra += 1.15
		stop_at[i] = at + i * 0.21 + extra
		if res.has_scatter(i):
			cum += 1
		reels[i].start_spin(randf_range(21.0, 25.0) + i * 1.1)


func _bet(dir: int) -> void:
	if phase != Phase.IDLE:
		return
	if g.change_bet(dir):
		Snd.bet(dir)
		_toast("배팅 %d × 9라인 = %s" % [g.bet_per_line(), P.n(g.total_bet())], P.CYAN)
	elif dir > 0 and g.bet_idx < D.BET_LEVELS.size() - 1:
		# 더 높은 단계가 남아 있는데 막혔다면 이유는 상한뿐이다
		_toast("한 번에 보유 코인의 1/10 (%s) 까지만 걸 수 있습니다"
				% P.n(g.bet_cap()), P.ORANGE)


func _restart() -> void:
	g.reset()
	disp_coins = g.coins
	disp_spirit = 0.0
	last_win = 0
	disp_win = 0.0
	res = null
	battle = null
	_clear_highlight()
	phase = Phase.IDLE
	idle_t = 0.0
	over_t = 0.0

# ==================== 연출 보조 ====================

func _any_reel_busy() -> bool:
	for r in reels:
		if r.busy():
			return true
	return false


func _clear_highlight() -> void:
	for x in D.REELS:
		for y in D.ROWS:
			highlight[x][y] = 0.0


func _update_highlight(dt: float) -> void:
	var want := []
	for x in D.REELS:
		want.append([0.0, 0.0, 0.0])
	if res != null and not _any_reel_busy() and (phase == Phase.PAYOUT or phase == Phase.IDLE):
		if res.wins.size() > 0:
			var idx: int = win_cycle % res.wins.size()
			for i in res.wins.size():
				var wv: Game.LineWin = res.wins[i]
				var v := 1.0 if (i == idx or res.wins.size() == 1) else 0.22
				for r in wv.count:
					var row: int = D.LINE[wv.line][r]
					if v > want[r][row]:
						want[r][row] = v
		if res.scatters >= 3:
			for at in res.scatter_at:
				want[at / D.ROWS][at % D.ROWS] = 1.0

	var pulse := 0.72 + 0.28 * sin(t * 6.5)
	for x in D.REELS:
		for y in D.ROWS:
			var target: float = want[x][y] * pulse
			highlight[x][y] += (target - highlight[x][y]) * minf(1.0, dt * 12.0)


func _toast(s: String, c: Color) -> void:
	toast = s
	toast_c = c
	toast_t = 2.2

# ==================== 입력 ====================

func _build_ui() -> void:
	buttons = [
		{"id": "spin", "label": "스핀", "sub": "Space", "c": P.CRIMSON, "round": true},
		{"id": "auto", "label": "자동", "sub": "A", "c": P.SEA2, "toggle": true},
		{"id": "max", "label": "최대", "sub": "배팅", "c": P.VIOLET},
		{"id": "pay", "label": "배당표", "sub": "P", "c": P.SEA1},
		{"id": "betup", "label": "+", "sub": "", "c": P.PANEL_HI},
		{"id": "betdn", "label": "−", "sub": "", "c": P.PANEL_HI},
		{"id": "sound", "label": "♪", "sub": "", "c": P.PANEL_HI, "toggle": true, "on": true},
		{"id": "help", "label": "?", "sub": "", "c": P.PANEL_HI},
		{"id": "restart", "label": "다시 시작", "sub": "아무 키나 클릭", "c": P.JADE, "primary": true},
	]
	for b in buttons:
		b["rect"] = Rect2()
		b["hover"] = 0.0
		b["enabled"] = true
		b["hidden"] = false


func _btn(id: String) -> Dictionary:
	for b in buttons:
		if b["id"] == id:
			return b
	return {}


func _layout_ui() -> void:
	var inner := L.bar.grow(-11.0)
	var h := inner.size.y - 20.0
	var y := inner.position.y + 10.0

	var k := L.ui_k
	var gap := 8.0 * k + 2.0
	_btn("spin")["rect"] = L.dial
	var x := L.dial.position.x - gap - 4.0

	x -= 88.0 * k
	_btn("auto")["rect"] = Rect2(x, y, 88.0 * k, h)
	x -= gap + 74.0 * k
	_btn("max")["rect"] = Rect2(x, y, 74.0 * k, h)
	x -= gap + 80.0 * k
	_btn("pay")["rect"] = Rect2(x, y, 80.0 * k, h)
	x -= gap
	var sq: float = minf(54.0 * k, h * 0.52)
	x -= sq
	_btn("betup")["rect"] = Rect2(x, y, sq, h * 0.5 - 2.0)
	_btn("betdn")["rect"] = Rect2(x, y + h * 0.5 + 2.0, sq, h * 0.5 - 2.0)
	x -= gap + sq
	_btn("sound")["rect"] = Rect2(x, y, sq, h * 0.5 - 2.0)
	_btn("help")["rect"] = Rect2(x, y + h * 0.5 + 2.0, sq, h * 0.5 - 2.0)
	bar_msg_right = x - 12.0

	_btn("restart")["rect"] = Rect2(L.w * 0.5 - 145.0, L.h * 0.5 + 110.0, 290.0, 64.0)

	var modal := help_open or pay_open
	_btn("spin")["enabled"] = phase == Phase.IDLE and g.can_spin() and not modal
	for id in ["betup", "betdn", "max"]:
		_btn(id)["enabled"] = phase == Phase.IDLE and not modal
	_btn("auto")["on"] = auto
	_btn("restart")["hidden"] = phase != Phase.BANKRUPT
	for id in ["spin", "auto", "max", "pay", "betup", "betdn"]:
		_btn(id)["hidden"] = phase == Phase.BANKRUPT

	for b in buttons:
		var hot: bool = (not b["hidden"]) and b["enabled"] and _hits(b, mouse)
		b["hover"] += ((1.0 if hot else 0.0) - b["hover"]) * 0.25


func _hits(b: Dictionary, p: Vector2) -> bool:
	var r: Rect2 = b["rect"]
	if b.get("round", false):
		return p.distance_to(r.position + r.size * 0.5) <= r.size.x * 0.5
	return r.has_point(p)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		mouse = (e as InputEventMouseMotion).position
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		mouse = (e as InputEventMouseButton).position
		_click()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		_key((e as InputEventKey).keycode)


func _click() -> void:
	if help_open or pay_open:
		help_open = false
		pay_open = false
		return
	if phase == Phase.BANKRUPT:
		_restart()
		return
	if scene != null and scene.active:
		if not scene.mash_hit() and scene.can_dismiss():
			scene.dismiss()
		return
	for b in buttons:
		if b["hidden"] or not b["enabled"]:
			continue
		if _hits(b, mouse):
			_press(b["id"])
			return


func _press(id: String) -> void:
	match id:
		"spin": _spin()
		"auto":
			Snd.click()
			auto = not auto
			_toast("자동 스핀 켜짐" if auto else "자동 스핀 꺼짐", P.JADE if auto else P.DIM)
		"max":
			Snd.bet(1)
			g.max_bet()
			_toast("배팅 %d × 9 = %s" % [g.bet_per_line(), P.n(g.total_bet())], P.CYAN)
		"pay":
			pay_open = not pay_open
			help_open = false
		"betup": _bet(1)
		"betdn": _bet(-1)
		"sound":
			Snd.muted = not Snd.muted
			_btn("sound")["on"] = not Snd.muted
		"help":
			help_open = not help_open
			pay_open = false
		"restart": _restart()


func _key(k: int) -> void:
	if phase == Phase.BANKRUPT and not help_open and not pay_open:
		if k == KEY_ESCAPE:
			get_tree().quit()
		else:
			_restart()
		return
	if k == KEY_F1 or k == KEY_H:
		help_open = not help_open
		pay_open = false
		return
	if k == KEY_P:
		pay_open = not pay_open
		help_open = false
		return
	if help_open or pay_open:
		if k == KEY_ESCAPE or k == KEY_SPACE or k == KEY_ENTER:
			help_open = false
			pay_open = false
		return

	match k:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE, KEY_ENTER:
			if scene != null and scene.active:
				# 해전 중에는 연타가 곧 보너스다
				if not scene.mash_hit() and scene.can_dismiss():
					scene.dismiss()
			elif phase == Phase.SPINNING or phase == Phase.PAYOUT:
				hurry = true
			else:
				_spin()
		KEY_TAB:
			if scene != null and scene.active:
				scene.speed = 1.0 if scene.speed > 1.5 else 3.2
		KEY_RIGHT, KEY_UP:
			_bet(1)
		KEY_LEFT, KEY_DOWN:
			_bet(-1)
		KEY_M:
			Snd.muted = not Snd.muted
			_btn("sound")["on"] = not Snd.muted
			_toast("소리 꺼짐" if Snd.muted else "소리 켜짐", P.CYAN)
		KEY_A:
			auto = not auto
			_toast("자동 스핀 켜짐" if auto else "자동 스핀 꺼짐", P.JADE if auto else P.DIM)
		KEY_X:
			g.max_bet()

# ==================== 그리기 ====================

func _draw() -> void:
	if L.w <= 0.0:
		return
	var off := fx.shake_offset()
	draw_set_transform(off, 0.0, Vector2.ONE)

	if scene != null and scene.active:
		scene.draw(self, L, t)
	else:
		Screen.background(self, L, t)
		Screen.marquee(self, L, g, t)
		Screen.meter(self, L, g, battle, t)
		Screen.gauge(self, L, g, disp_spirit, t)
		Screen.board(self, L, g, res, reels, phase == Phase.SPINNING, t)
		Screen.side(self, L, g, last_win, disp_win, t)

	Screen.bar(self, L, g, disp_coins, phase, auto, bar_msg_right, t)
	fx.draw_back(self)
	fx.draw_front(self)
	Screen.cabinet(self, L, phase == Phase.SPINNING or scene != null, t)
	Screen.buttons(self, L, buttons, phase, t)
	if pay_open:
		Screen.paytable(self, L, g, t)
	if help_open:
		Screen.help(self, L)
	if phase == Phase.BANKRUPT:
		Screen.bankrupt(self, L, g, over_t, t)
		Screen.button(self, _btn("restart"), t)
	if toast_t > 0.0:
		Screen.toast(self, L, toast, toast_c, toast_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	fx.draw_flash(self, L.w, L.h)


## 릴 창 안쪽 (좌표는 창 왼쪽 위 기준)
func _draw_reels() -> void:
	if L.w <= 0.0:
		return
	Screen.reels_clipped(reel_layer, L, res, reels, highlight, win_cycle, t)
