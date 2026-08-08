extends Node2D

## 게임 루프 · 입력 · 카메라 · 상태 기계. 그리기도 여기서 한 번에 한다.
##
## 적이 수백이라 노드를 만들지 않는다. `_draw()` 한 곳에서 카메라 변환을 걸고
## 월드를 그린 뒤, 변환을 풀고 HUD 를 그린다.

enum St { TITLE, PLAY, LEVELUP, PAUSED, OVER }

var st := St.TITLE
var g: Game
var w: World
var fx := Fx.new()

var t := 0.0
var cam := Vector2.ZERO
var cards: Array = []
var card_sel := 0
var card_anim := 0.0
var won := false
var over_t := 0.0


func _ready() -> void:
	set_process(true)
	get_window().title = "좀비디펜스"
	_new_run()
	st = St.TITLE


func _new_run() -> void:
	g = Game.new()
	fx.clear()
	w = World.new(g, fx)
	cam = w.pos - _view_size() * 0.5
	cards.clear()
	card_anim = 0.0
	over_t = 0.0
	won = false


func _view_size() -> Vector2:
	return get_viewport_rect().size

# ==================== 루프 ====================

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)          # 창을 끌거나 멈췄다 돌아왔을 때 한 프레임에 몰아 도는 걸 막는다
	t += dt

	match st:
		St.TITLE:
			pass
		St.PLAY:
			w.update(dt, _move_dir())
			fx.update(dt)
			_follow(dt)
			if g.can_level():
				_open_cards()
			elif w.dead:
				_finish(false)
			elif w.cleared:
				_finish(true)
		St.LEVELUP:
			card_anim = minf(1.0, card_anim + dt * 5.0)
			fx.update(dt * 0.25)
		St.PAUSED:
			pass
		St.OVER:
			over_t += dt
			fx.update(dt)

	queue_redraw()


func _follow(dt: float) -> void:
	var vs := _view_size()
	var want := w.pos - vs * 0.5
	# 맵 밖이 보이지 않게 잘라 준다
	want.x = clampf(want.x, 0.0, maxf(0.0, D.ARENA.x - vs.x))
	want.y = clampf(want.y, 0.0, maxf(0.0, D.ARENA.y - vs.y))
	cam = cam.lerp(want, clampf(dt * 9.0, 0.0, 1.0))


func _move_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized() if v.length_squared() > 0.01 else Vector2.ZERO

# ==================== 상태 전환 ====================

func _open_cards() -> void:
	g.level_up()
	cards = g.roll_cards(D.CARD_COUNT)
	card_sel = 0
	card_anim = 0.0
	st = St.LEVELUP
	fx.level_text(w.pos + Vector2(0, -60), "LEVEL UP!", P.GOLD_HI)
	Snd.levelup()


func _pick(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	g.apply_card(cards[i])
	Snd.ui()
	cards.clear()
	# 한 번에 여러 레벨이 오르는 경우가 있다 (보스 젬). 남아 있으면 카드를 또 띄운다.
	if g.can_level():
		_open_cards()
	else:
		st = St.PLAY


func _finish(victory: bool) -> void:
	won = victory
	st = St.OVER
	over_t = 0.0
	if victory:
		Snd.clear_()
		fx.flash(P.GOLD_HI, 0.8)
	else:
		Snd.gameover()
		fx.flash(P.CRIMSON, 0.8)

# ==================== 입력 ====================

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		_key((e as InputEventKey).keycode)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		if st == St.LEVELUP:
			_click((e as InputEventMouseButton).position)


func _key(k: int) -> void:
	if k == KEY_M:
		Snd.muted = not Snd.muted
		return

	match st:
		St.TITLE:
			if k == KEY_SPACE or k == KEY_ENTER:
				_new_run()
				st = St.PLAY
				Snd.music(true)
			elif k == KEY_ESCAPE:
				get_tree().quit()
		St.PLAY:
			if k == KEY_ESCAPE:
				st = St.PAUSED
		St.PAUSED:
			if k == KEY_ESCAPE or k == KEY_SPACE:
				st = St.PLAY
		St.LEVELUP:
			if k == KEY_1:
				_pick(0)
			elif k == KEY_2:
				_pick(1)
			elif k == KEY_3:
				_pick(2)
			elif k == KEY_LEFT or k == KEY_A:
				card_sel = maxi(0, card_sel - 1)
				Snd.ui()
			elif k == KEY_RIGHT or k == KEY_D:
				card_sel = mini(cards.size() - 1, card_sel + 1)
				Snd.ui()
			elif k == KEY_SPACE or k == KEY_ENTER:
				_pick(card_sel)
		St.OVER:
			if k == KEY_SPACE or k == KEY_ENTER:
				_new_run()
				st = St.PLAY
				Snd.music(true)
			elif k == KEY_ESCAPE:
				_new_run()
				st = St.TITLE


func _click(at: Vector2) -> void:
	var vs := _view_size()
	var n := cards.size()
	var cw := minf(268.0, (vs.x - 80.0) / maxi(1, n) - 18.0)
	var chh := minf(330.0, vs.y * 0.48)
	var total := cw * n + 18.0 * (n - 1)
	var x0 := (vs.x - total) * 0.5
	var y0 := vs.y * 0.34
	for i in n:
		var r := Rect2(x0 + i * (cw + 18.0), y0, cw, chh)
		if r.has_point(at):
			_pick(i)
			return

# ==================== 그리기 ====================

func _draw() -> void:
	var vs := _view_size()
	var off := -cam
	if w != null and w.shake > 0.0:
		off += Vector2(randf_range(-w.shake, w.shake), randf_range(-w.shake, w.shake))

	# 스프라이트가 좌우 뒤집기를 할 때 카메라 변환을 다시 곱해야 해서 넘겨 준다
	Spr.origin = off
	draw_set_transform(off, 0.0, Vector2.ONE)
	_draw_world(Rect2(cam - Vector2(60, 60), vs + Vector2(120, 120)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	fx.draw_screen(self, vs.x, vs.y)

	match st:
		St.TITLE:
			Hud.title(self, vs.x, vs.y, t)
		St.PLAY, St.LEVELUP, St.PAUSED:
			Hud.bar(self, vs.x, vs.y, g, t)
			Hud.loadout(self, vs.x, vs.y, g)
			if st == St.LEVELUP:
				Hud.cards(self, vs.x, vs.y, cards, card_sel, t, card_anim)
			elif st == St.PAUSED:
				Hud.paused(self, vs.x, vs.y)
		St.OVER:
			Hud.bar(self, vs.x, vs.y, g, t)
			Hud.result(self, vs.x, vs.y, g, won, over_t)


func _draw_world(view: Rect2) -> void:
	Art.ground(self, view)
	if w == null:
		return

	for a: Dictionary in w.areas:
		Art.area(self, a, t)

	for gm: Dictionary in w.gems:
		if view.has_point(gm["p"]):
			Art.gem(self, gm, t)

	# 먼(위쪽) 놈부터 그려야 앞뒤가 맞는다
	var order: Array = []
	for e: Dictionary in w.enemies:
		if view.has_point(e["p"]):
			order.append(e)
	order.sort_custom(func(a, b): return a["p"].y < b["p"].y)
	# 화면 안 적이 많아지면 팔다리·셀 음영을 건너뛴다. 그래야 최악의 순간에도 프레임이 버틴다.
	Art.detail = order.size() <= 70
	for e: Dictionary in order:
		Art.enemy(self, e, t)

	# 회전 사슬
	if g.weapons.has(D.W_CHAIN):
		var wid := D.W_CHAIN
		var n := g.wcount(wid)
		var rad := g.wstat(wid, "radius", 90.0) * g.range_mult()
		var orb_r := 15.0 * g.size_mult()
		var rings := 2 if g.evolved(wid) else 1
		for ring in rings:
			var rr := rad * (1.0 if ring == 0 else 0.58)
			var cnt := n if rings == 1 else int(ceil(n * 0.5))
			for i in cnt:
				var a := w.orb_ang * (1.0 if ring == 0 else -1.35) + TAU * i / maxi(1, cnt)
				Art.orb(self, w.pos + Vector2(cos(a), sin(a)) * rr, orb_r, t)

	for d: Dictionary in w.drones:
		Art.drone(self, d, t)

	Art.detail = true
	Art.hero(self, w.pos, w.aim, t, w.iframe > 0.0 and fmod(t, 0.16) < 0.08,
		_move_dir().length_squared() > 0.01)

	for b: Dictionary in w.bullets:
		Art.bullet(self, b, t)
	for b2: Dictionary in w.beams:
		Art.beam(self, b2)
	for z: Dictionary in w.zaps:
		Art.zap(self, z)

	fx.draw_world(self)
