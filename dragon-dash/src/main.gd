extends Node2D

## 진입점 — 화면 전환 · 입력 · 루프.
##
## **세로 화면 전체가 플레이필드다.** 잘라낼 것이 없으므로 클리핑용 자식 [Control] 없이
## 이 노드의 `_draw()` 한 곳에서 다 그린다. 화면 흔들림은 `draw_set_transform` 으로
## 월드에만 걸고, HUD 를 그리기 전에 **반드시 되돌린다** — 안 되돌리면 버튼이 밀려서
## 그린 자리와 누른 자리가 어긋난다.
##
## 터치는 `emulate_mouse_from_touch`(기본 켜짐) 덕에 마우스 이벤트로 들어온다.
## 그래서 조작 코드는 하나뿐이고, PC 에서 마우스로 끌면 폰에서와 똑같이 동작한다.

enum Mode { SELECT, PLAY, SHOP }

var mode := Mode.SELECT
var sel := Sel.new()
var shop := Shop.new()
var world: World

# ---- 끌기 ----
## **상대 드래그다.** 화면 아무 데나 잡고 끈 만큼 드래곤이 움직인다.
## 손가락 위치로 절대 이동시키면 드래곤이 손가락 밑에 깔려 안 보이고,
## 화면 끝을 잡으면 몸이 화면 밖으로 나가려 한다.
var dragging := false
var press_x := 0.0
var anchor_x := 0.0

var finished := false
var rec := false


func _ready() -> void:
	Sv.load_()
	sel.pick = Sv.dragon
	get_viewport().size_changed.connect(queue_redraw)
	if _flag("--autoplay"):
		_start()
		world.auto = true
		var sk := _num("--skip=", 0.0)
		if sk > 0.0:
			world.skip_to(sk)


func _vs() -> Vector2:
	return get_viewport_rect().size


# ==================== 명령줄 (soak 검산용) ====================

func _args() -> PackedStringArray:
	var a := OS.get_cmdline_args()
	a.append_array(OS.get_cmdline_user_args())
	return a


func _flag(name: String) -> bool:
	return _args().has(name)


func _num(prefix: String, dflt: float) -> float:
	for a in _args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return dflt


# ==================== 흐름 ====================

func _start() -> void:
	var vs := _vs()
	world = World.new(sel.pick)
	world.setup(vs.x, vs.y)
	finished = false
	rec = false
	dragging = false
	mode = Mode.PLAY
	Sv.dragon = sel.pick


## 죽었을 때 **한 번만** 정산한다. 매 프레임 부르면 금화가 계속 더해진다.
func _finish() -> void:
	if finished:
		return
	finished = true
	rec = Sv.finish_run(int(world.m), world.gold)
	if world.auto:
		# **뿌린 체력 대비 넣은 피해(clear)가 핵심 지표다.** 낮으면 화력이 모자란 게
		# 아니라 브레스가 안 맞는 것이고, 그때 dmg 를 올리면 엉뚱한 데를 만지는 셈이다.
		var secs := maxf(0.001, world.m / D.SCROLL * D.PX_PER_M)
		print("[soak] %5dm  kill=%3d/%3d  clear=%4.1f%%  dps=%5.1f  power=%d  gold=%d"
				% [int(world.m), world.kills, world.spawned,
					100.0 * world.dmg_dealt / maxf(1.0, world.hp_spawned),
					world.dmg_dealt / secs, world.power, world.gold])


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	match mode:
		Mode.SELECT:
			sel.step(dt)
		Mode.SHOP:
			shop.step(dt)
		Mode.PLAY:
			_step_play(dt)
	queue_redraw()


func _step_play(dt: float) -> void:
	var vs := _vs()
	world.setup(vs.x, vs.y)

	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir += 1.0

	# 끌고 있는 동안에만 목표 x 를 준다. 손을 떼면 그 자리에 선다.
	var target := -1.0
	if world.st == World.St.PLAY:
		var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var mx := get_viewport().get_mouse_position().x
		if held:
			if not dragging:
				dragging = true
				press_x = mx
				anchor_x = world.pos.x
			target = anchor_x + (mx - press_x)
		else:
			dragging = false

	world.step(dt, dir, target)

	if world.st == World.St.OVER:
		_finish()
		# 무인 주행은 알아서 다시 시작해 표본을 쌓는다.
		if world.auto and world.over_t > 0.6:
			_start()
			world.auto = true


func _to_select() -> void:
	mode = Mode.SELECT
	dragging = false


# ==================== 입력 ====================

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_tap(e.position)
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var code: int = e.keycode
	match mode:
		Mode.SELECT:
			match code:
				KEY_UP, KEY_W: sel.move(-1)
				KEY_DOWN, KEY_S: sel.move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z: _start()
				KEY_TAB: mode = Mode.SHOP
				KEY_ESCAPE: get_tree().quit()
		Mode.SHOP:
			match code:
				KEY_UP, KEY_W: shop.move(-1)
				KEY_DOWN, KEY_S: shop.move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_RIGHT: shop.buy()
				KEY_ESCAPE, KEY_TAB: _to_select()
		Mode.PLAY:
			var over := world.st == World.St.OVER
			match code:
				KEY_R:
					if over:
						_start()
				KEY_ENTER, KEY_KP_ENTER:
					if over:
						_to_select()
				KEY_ESCAPE:
					if over:
						_to_select()
					else:
						_to_select()
				KEY_J:
					# **테스트 빌드 전용** — 뒤쪽 난이도를 볼 때마다 5분씩 달리지 않으려고.
					if not over and D.test_build():
						world.skip_to(world.m + 1000.0)
				KEY_K:
					if D.test_build():
						Sv.wipe()


## **새 화면을 만들면 키와 터치 분기를 둘 다 채운다.**
## 키만 넣으면 PC 에서는 되기 때문에 "폰에서 못 누른다"를 눈치채기 어렵다.
func _tap(p: Vector2) -> void:
	var vs := _vs()
	match mode:
		Mode.SELECT:
			match sel.hit(p, vs.x, vs.y):
				"start": _start()
				"shop": mode = Mode.SHOP
		Mode.SHOP:
			match shop.hit(p, vs.x, vs.y):
				"buy": shop.buy()
				"back": _to_select()
		Mode.PLAY:
			if world.st != World.St.OVER:
				return
			# 결과 화면의 버튼. 자리는 `Hud.over_rect` 하나가 낸다.
			for i in 2:
				if Hud.over_rect(i, vs.x, vs.y).has_point(p):
					if i == 0:
						_start()
					else:
						_to_select()
					return


# ==================== 그리기 ====================

func _draw() -> void:
	var vs := _vs()
	match mode:
		Mode.SELECT:
			sel.draw(self, vs.x, vs.y)
			return
		Mode.SHOP:
			shop.draw(self, vs.x, vs.y)
			return

	# 흔들림은 월드에만. HUD 까지 흔들면 글자가 읽히지 않는다.
	var sh := world.shake
	if sh > 0.0:
		draw_set_transform(Vector2(randf() - 0.5, randf() - 0.5) * 12.0 * sh)
	world.draw(self)
	draw_set_transform(Vector2.ZERO)   # 반드시 되돌린다

	if world.st == World.St.OVER:
		Hud.over(self, vs.x, vs.y, world, rec)
	else:
		Hud.play(self, vs.x, vs.y, world)
