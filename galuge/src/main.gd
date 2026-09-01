extends Node2D

## 진입점 — 화면 배치 · 입력 · 루프.
##
## 세로 슈팅이지만 창은 가로다. 플레이필드를 화면 한가운데에 세로로 두고 양옆은 패널로 채운다.
## **`_draw()` 에는 클리핑이 없다** — 플레이필드는 clip_contents 를 켠 [Control] 자식
## `field` 안에서 그린다.
##
## **자식은 부모보다 나중에, 즉 위에 그려진다.** 그래서 이 노드의 `_draw()` 에 그린 것은
## 플레이필드 안쪽에서 통째로 가려진다 — 보스 체력 막대와 게임오버 배너가 실제로
## 안 보였다. 플레이필드 위에 얹을 것은 `field` **다음에** 추가한 `over` 에 그린다.

enum Mode { SELECT, PLAY }

var mode := Mode.SELECT
var sel := Sel.new()
var world: World
var field: Control
var over: Control
var play := Rect2()


func _ready() -> void:
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.visible = false
	add_child(field)
	field.draw.connect(_draw_field)
	over = Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)          # field 다음에 추가해야 그 위에 그려진다
	over.draw.connect(_draw_over)
	_layout()
	get_viewport().size_changed.connect(_layout)
	# 무인 주행용. README 의 soak 테스트가 이 깃발로 선택 화면을 건너뛴다.
	if _autoplay():
		sel.craft = _autocraft()
		sel.diff = _autodiff()
		sel.round = _autoround()
		_start()
		world.skip_to(_autoprog())


func _layout() -> void:
	var vs := get_viewport_rect().size
	var pw := minf(D.PLAY_W, maxf(240.0, vs.x - D.PANEL_MIN * 2.0))
	play = Rect2(Vector2(floorf((vs.x - pw) * 0.5), 0.0), Vector2(pw, vs.y))
	field.position = play.position
	field.size = play.size
	over.position = Vector2.ZERO
	over.size = vs
	if world != null:
		world.w = pw
		world.setup(play.size.y)


func _start() -> void:
	world = World.new(sel.craft, sel.round, sel.diff)
	world.w = play.size.x
	world.setup(play.size.y)
	world.god = _autoplay()
	if world.god:
		world.power = D.POWER_MAX   # REF_DPS 는 만렙 기준이라 실측도 만렙으로 잰다
	mode = Mode.PLAY
	field.visible = true


func _autoplay() -> bool:
	return _args().has("--autoplay")


func _args() -> PackedStringArray:
	var a := OS.get_cmdline_args()
	a.append_array(OS.get_cmdline_user_args())
	return a


## soak 테스트에서 기체를 골라 돌린다: `-- --autoplay --craft=3`
func _autocraft() -> int:
	for a in _args():
		if a.begins_with("--craft="):
			return clampi(int(a.substr(8)), 0, D.CRAFT.size() - 1)
	return 0


## soak 테스트를 라운드 중간부터 시작한다: `-- --autoplay --prog=0.44`
## 보스를 만질 때 50초씩 기다리지 않으려고 둔다.
func _autoprog() -> float:
	for a in _args():
		if a.begins_with("--prog="):
			return clampf(float(a.substr(7)), 0.0, 0.99)
	return 0.0


## soak 테스트를 특정 라운드부터: `-- --autoplay --round=4`
func _autoround() -> int:
	for a in _args():
		if a.begins_with("--round="):
			return clampi(int(a.substr(8)) - 1, 0, D.ROUND.size() - 1)
	return 0


## soak 테스트 난이도: `-- --autoplay --diff=2`
func _autodiff() -> int:
	for a in _args():
		if a.begins_with("--diff="):
			return clampi(int(a.substr(7)), 0, D.DIFF.size() - 1)
	return 0


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if mode == Mode.SELECT:
		sel.step(dt)
		queue_redraw()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if world.god:
		# soak 테스트는 표적을 좌우로 따라만 간다. 회피는 안 하지만 탄은 거의 다 맞으므로
		# **화력 상한**을 재는 셈이 된다 — REF_DPS 는 이 값으로 잡는다.
		var tgt := Vector2(world.w * 0.5, world.h - 100.0)
		if not world.boss.is_empty() and world.boss.y_in:
			# 사람은 보스 밑으로 파고들어 쏜다. 멀리서 쏘면 탄이 도착할 때 보스가 이미 옆에 없다.
			tgt = Vector2(world.boss.pos.x, world.boss.pos.y + world.boss.r.y + 56.0)
		elif not world.foes.is_empty():
			tgt.x = world.foes[0].pos.x
		var dv := tgt - world.pos
		dir = Vector2(signf(dv.x) if absf(dv.x) > 4.0 else 0.0,
				signf(dv.y) if absf(dv.y) > 6.0 else 0.0)
	# 방향키/게임패드에 WASD 를 겹쳐 둔다. 입력 맵을 손으로 쓰지 않아도 되게.
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var focus := Input.is_physical_key_pressed(KEY_SHIFT)
	var bomb := Input.is_physical_key_pressed(KEY_T)
	# 손으로 하는 것은 이것 하나다 — 누르고 있으면 미사일이 멈추고 스킬이 찬다.
	# 미사일 자체는 자동이라 키가 없다.
	var skl := Input.is_physical_key_pressed(KEY_R)
	if world.god:
		# 봇도 스킬을 쓴다 — 안 쓰면 soak 이 재는 초가 실제 화력과 달라진다.
		# 주기마다 한 번 끝까지 채워 내보내고, 나머지 시간은 미사일에 맡긴다.
		skl = fmod(world.t, 6.0) < D.CHARGE_T + 0.05

	world.step(dt, dir, focus, bomb, skl)
	# 라운드를 깨면 잠깐 보여 주고 다음 라운드로. 마지막이면 올 클리어.
	if world.st == World.St.CLEAR and world.clear_t > 2.6:
		if not world.advance():
			world.st = World.St.ALLCLEAR

	var sh: float = world.shake
	field.position = play.position + (Vector2(randf() - 0.5, randf() - 0.5) * 9.0 * sh
			if sh > 0.0 else Vector2.ZERO)
	field.queue_redraw()
	over.queue_redraw()
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and mode == Mode.SELECT:
		sel.hit(e.position, get_viewport_rect().size)
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if mode == Mode.SELECT:
		if sel.key(e.keycode):
			_start()
		elif e.keycode == KEY_ESCAPE:
			get_tree().quit()
		return
	var over := world.st == World.St.OVER or world.st == World.St.ALLCLEAR
	match e.keycode:
		KEY_R:
			# 판이 도는 동안 R 은 서브기체 스킬을 채운다(`_process` 가 눌림 상태를 본다).
			# 여기는 **끝난 뒤에만** 걸리므로 둘이 겹치지 않는다.
			if over:
				_start()
		KEY_B:
			# **테스트 빌드 전용.** 보스가 나올 때까지 40~50초를 기다리지 않고 바로 붙는다.
			# 일반 빌드에서는 이 분기 자체가 안 걸리므로 B 는 아무 키도 아니다.
			if not over and D.test_build():
				world.skip_to_boss()
		KEY_ENTER, KEY_KP_ENTER:
			if over:
				_to_select()
		KEY_ESCAPE:
			if over:
				_to_select()
			else:
				get_tree().quit()


func _to_select() -> void:
	mode = Mode.SELECT
	field.visible = false


func _draw_field() -> void:
	world.draw(field)


## 플레이필드 **위에** 얹히는 것 — 보스 체력 막대와 배너.
func _draw_over() -> void:
	if mode != Mode.PLAY:
		return
	Hud.boss_bar(over, play, world)
	Hud.overlay(over, play, world)


func _draw() -> void:
	var vs := get_viewport_rect().size
	if mode == Mode.SELECT:
		sel.draw(self, vs)
		return
	draw_rect(Rect2(Vector2.ZERO, vs), P.VOID, true)
	Hud.panels(self, play, vs, world)
