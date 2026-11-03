extends Node2D

## 스카이 어설트 — 진입점. 화면 배치 · 입력 · 루프.
##
## 갈루가(가로 1280×720 창, 가운데 세로 플레이필드 + 좌우 패널)를 **세로 화면**으로 옮긴 것이다.
##
## **월드는 그대로 논리 폭 384 이고, 화면에는 배율 `k` 로 키워 그린다.** 탄 속도 · 판정 · 보스
## 체력 · 서브기체 자리가 전부 이 폭 기준으로 맞춰져 있어서, 폭 자체를 720 으로 늘리면 "넓어서
## 걸어서 피해지는" 다른 게임이 된다. 논리 높이는 화면 비율에 따라 640 이상으로 정해진다
## (`SaD.PLAY_H_MIN`) — 갈루가도 창 높이를 그대로 썼으니 높이가 변하는 것은 원래 허용된 축이다.
##
## 레이어: 이 노드(바탕 · 위 점수 띠 · 아래 단추) → `field`(월드, clip) → `over`(보스 막대 · 배너).
## **`_draw()` 에는 클리핑이 없다** — 월드는 clip_contents 를 켠 [Control] 안에서 그린다.
## 자식은 부모보다 나중에(위에) 그려지므로 플레이필드 위에 얹을 것은 `over` 에 그린다.
##
## 조작은 **끌기(이동) · 스킬 단추(누르고 있다 떼기) · 봄 단추** 셋이다. 사격은 자동이라 그것뿐이다.
## 스킬을 누르고 있는 채로 다른 손가락으로 끌어야 하므로 **멀티터치를 직접 받는다**
## (젤리팝이 쓰는 터치→마우스 흉내는 첫 손가락 하나만 넘겨준다). 흉내 낸 마우스 이벤트는
## `device == DEVICE_ID_EMULATION` 으로 걸러 두 번 처리하지 않는다.

enum Mode { SELECT, PLAY }

const TOP := 146.0      ## 위 점수 띠 높이(화면 px)
const BOT := 236.0      ## 아래 단추 띠 높이

var mode := Mode.SELECT
var sel := SaSel.new()
var world: SaWorld
var field: Control
var over: Control
var k := 1.0            ## 논리 → 화면 배율
var play := Rect2()     ## 플레이필드의 화면 자리
var vs := Vector2(720, 1280)
var t := 0.0

# 입력 상태
var drag_id := -2       ## 끌고 있는 손가락(-1 = 마우스, -2 = 없음)
var skill_id := -2      ## 스킬 단추를 누르고 있는 손가락
var drag_acc := Vector2.ZERO
var bomb_tap := false
var last_pos := Vector2.ZERO

# 확인용 인자
var shot_path := ""
var shot_at := 0.0
var touch_test := false
var _tt := 0          ## --touch-test 진행 프레임
var _tt_pos := Vector2.ZERO


func _ready() -> void:
	Bgm.use("sky")
	# 발광 — 색 값을 1.0 넘게 올려 번지게 하는 방식(갈루가 원본 그대로). 화면 설정이라
	# 허브가 게임을 닫을 때 되돌린다(`Hub.close`).
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.05
	env.glow_bloom = 0.14
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

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

	for a in _args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
	if _args().has("--touch-test"):
		touch_test = true
	# 무인 주행용. 선택 화면을 건너뛴다.
	if _autoplay():
		sel.craft = _arg_int("--craft=", 0, SaD.CRAFT.size() - 1)
		sel.diff = _arg_int("--diff=", 0, SaD.DIFF.size() - 1)
		sel.round = _arg_int("--round=", 1, SaD.ROUND.size()) - 1
		_start()
		var p := 0.0
		for a in _args():
			if a.begins_with("--prog="):
				p = clampf(float(a.substr(7)), 0.0, 0.99)
		world.skip_to(p)


func _exit_tree() -> void:
	get_viewport().use_hdr_2d = false


func _args() -> PackedStringArray:
	var a := OS.get_cmdline_args()
	a.append_array(OS.get_cmdline_user_args())
	return a


func _autoplay() -> bool:
	return _args().has("--autoplay")


func _arg_int(prefix: String, lo: int, hi: int) -> int:
	for a in _args():
		if a.begins_with(prefix):
			return clampi(int(a.substr(prefix.length())), lo, hi)
	return lo

# ==================== 배치 ====================


func _layout() -> void:
	vs = get_viewport_rect().size
	var avail := vs.y - TOP - BOT
	k = minf(vs.x / SaD.PLAY_W, avail / SaD.PLAY_H_MIN)
	var pw := SaD.PLAY_W * k
	play = Rect2(Vector2(floorf((vs.x - pw) * 0.5), TOP), Vector2(pw, avail))
	for c: Control in [field, over]:
		c.position = play.position
		c.scale = Vector2(k, k)
		c.size = Vector2(SaD.PLAY_W, avail / k)
	if world != null:
		world.setup(avail / k)


## 아래 띠의 단추. 그리기와 터치 판정이 같은 함수를 본다.
func _skill_btn() -> Rect2:
	return Rect2(16, vs.y - BOT + 18, 210, BOT - 36)


func _bomb_btn() -> Rect2:
	return Rect2(vs.x - 226, vs.y - BOT + 18, 210, BOT - 36)


func _quit_btn() -> Rect2:
	return Rect2(vs.x * 0.5 - 95, vs.y - 80, 190, 62)


## 판이 끝난 뒤 — 0 = 다시, 1 = 기체 선택
func _end_btn(i: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 300 + i * 310, vs.y - BOT + 30, 290, BOT - 60)


func _over() -> bool:
	return world != null and (world.st == SaWorld.St.OVER or world.st == SaWorld.St.ALLCLEAR)


func _start() -> void:
	world = SaWorld.new(sel.craft, sel.round, sel.diff)
	world.setup(field.size.y)
	world.god = _autoplay()
	if world.god:
		world.power = SaD.POWER_MAX   # REF_DPS 는 만렙 기준이라 실측도 만렙으로 잰다
	mode = Mode.PLAY
	field.visible = true
	over.visible = true
	drag_id = -2
	skill_id = -2
	Snd.play("start")


func _to_select() -> void:
	mode = Mode.SELECT
	field.visible = false
	# 보스 띠 · GAME OVER 를 그리는 위층도 숨긴다 — 안 숨기면 마지막 프레임이 선택 화면 위에 남는다
	over.visible = false
	drag_id = -2
	skill_id = -2

# ==================== 루프 ====================


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	if shot_path != "" and shot_at > 0.0 and t >= shot_at:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	if touch_test:
		_touch_test_step()
	if mode == Mode.SELECT:
		sel.step(dt)
		queue_redraw()
		return

	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if world.god:
		# 무인 주행은 표적을 좌우로 따라만 간다(화력 상한을 재는 셈).
		var tgt := Vector2(world.w * 0.5, world.h - 100.0)
		if not world.boss.is_empty() and world.boss.y_in:
			tgt = Vector2(world.boss.pos.x, world.boss.pos.y + world.boss.r.y + 56.0)
		elif not world.foes.is_empty():
			tgt.x = world.foes[0].pos.x
		var dv := tgt - world.pos
		dir = Vector2(signf(dv.x) if absf(dv.x) > 4.0 else 0.0,
				signf(dv.y) if absf(dv.y) > 6.0 else 0.0)
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
	var bomb := Input.is_physical_key_pressed(KEY_T) or bomb_tap
	bomb_tap = false
	# 손으로 하는 판단은 이것 하나 — 누르고 있으면 서브기체가 멈추고 스킬이 찬다.
	var skl := Input.is_physical_key_pressed(KEY_R) or skill_id != -2
	if world.god:
		skl = fmod(world.t, 6.0) < SaD.CHARGE_T + 0.05
	world.drag += drag_acc / k
	drag_acc = Vector2.ZERO

	world.step(dt, dir, focus, bomb, skl)
	if world.st == SaWorld.St.CLEAR and world.clear_t > 2.6:
		if not world.advance():
			world.st = SaWorld.St.ALLCLEAR

	var sh: float = world.shake
	var off := Vector2(randf() - 0.5, randf() - 0.5) * 9.0 * sh if sh > 0.0 else Vector2.ZERO
	field.position = play.position + off
	field.queue_redraw()
	over.queue_redraw()
	queue_redraw()

# ==================== 입력 ====================


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_touch(e.index, e.position, e.pressed)
		return
	if e is InputEventScreenDrag:
		if e.index == drag_id:
			drag_acc += e.relative
		return
	if e is InputEventMouseButton:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return   # 터치를 흉내 낸 것 — 위에서 이미 받았다
		if e.button_index == MOUSE_BUTTON_LEFT:
			_touch(-1, e.position, e.pressed)
		return
	if e is InputEventMouseMotion:
		if e.device != InputEvent.DEVICE_ID_EMULATION and drag_id == -1:
			drag_acc += e.relative
		return
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	_key(e.keycode)


## 손가락(-1 = 마우스) 하나가 눌리거나 떨어졌다.
func _touch(id: int, p: Vector2, down: bool) -> void:
	if not down:
		if id == drag_id:
			drag_id = -2
		if id == skill_id:
			skill_id = -2   # 떼는 순간 스킬이 나간다(world 가 누름 → 뗌을 본다)
		return
	if mode == Mode.SELECT:
		match sel.hit(p, vs):
			"start":
				_start()
			"hub":
				Hub.leave(self)
		return
	if _over():
		if _end_btn(0).has_point(p):
			_start()
		elif _end_btn(1).has_point(p):
			_to_select()
		return
	if _skill_btn().has_point(p):
		skill_id = id
		return
	if _bomb_btn().has_point(p):
		bomb_tap = true
		return
	if _quit_btn().has_point(p):
		_to_select()
		return
	# 그 밖 어디든 — 끌어서 움직인다(상대 이동). 기체를 손가락으로 가리지 않게 절대 위치로 안 옮긴다.
	drag_id = id
	last_pos = p


## `--touch-test` — 진짜 터치 이벤트로 출격 → 끌기 → (끄는 채로) 스킬 누르고 떼기 → 봄 → 그만하기.
## **입력은 다음 프레임에 처리되므로** 한 단계 넣고 몇 프레임 뒤에 상태를 본다.
## 실패하면 종료 코드 1. 멀티터치(끌면서 스킬)를 사람이 PC 에서 확인할 길이 없어 둔다.
func _touch_test_step() -> void:
	_tt += 1
	var fail := ""
	match _tt:
		5:
			_send_touch(0, sel.start_rect(vs).get_center(), true)
			_send_touch(0, sel.start_rect(vs).get_center(), false)
		10:
			if mode != Mode.PLAY:
				fail = "출격 단추가 안 눌림"
			else:
				_tt_pos = world.pos
				_send_touch(1, play.get_center(), true)
		12:
			var d := InputEventScreenDrag.new()
			d.index = 1
			var xf := get_viewport().get_final_transform()
			d.position = xf * (play.get_center() + Vector2(60, 0))
			d.relative = xf.basis_xform(Vector2(60, 0))
			Input.parse_input_event(d)
		16:
			if world.pos.x <= _tt_pos.x + 10.0:
				fail = "끌어도 기체가 안 움직임 (%s → %s)" % [_tt_pos, world.pos]
			_send_touch(2, _skill_btn().get_center(), true)   # 끄는 손가락은 그대로 둔 채
		40:
			if world.charge <= 0.0:
				fail = "스킬 단추를 누르고 있어도 안 참"
			elif drag_id != 1:
				fail = "스킬을 누르자 끌던 손가락을 놓침"
			_send_touch(2, _skill_btn().get_center(), false)
			_send_touch(1, play.get_center(), false)
		44:
			if skill_id != -2 or drag_id != -2:
				fail = "손가락을 뗐는데 눌린 채로 남음"
			_tt_pos = Vector2(world.bombs, 0)
			_send_touch(3, _bomb_btn().get_center(), true)
			_send_touch(3, _bomb_btn().get_center(), false)
		48:
			if world.bombs >= int(_tt_pos.x):
				fail = "봄 단추를 눌러도 봄이 안 나감"
			_send_touch(4, _quit_btn().get_center(), true)
			_send_touch(4, _quit_btn().get_center(), false)
		52:
			if mode != Mode.SELECT:
				fail = "그만하기가 안 눌림"
			else:
				print("TOUCH TEST OK")
				get_tree().quit(0)
	if fail != "":
		printerr("TOUCH TEST FAIL: " + fail)
		get_tree().quit(1)


## 넣는 이벤트는 **창 좌표**다 — 창(450×800)이 캔버스(720×1280)보다 작게 늘려져 있다.
func _send_touch(i: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = get_viewport().get_final_transform() * p
	e.pressed = down
	Input.parse_input_event(e)


func _key(code: int) -> void:
	if mode == Mode.SELECT:
		if sel.key(code):
			_start()
		elif code == KEY_ESCAPE:
			Hub.leave(self)
		return
	match code:
		KEY_R:
			# 판이 도는 동안 R 은 스킬(`_process` 가 눌림 상태를 본다). 끝난 뒤에만 "다시".
			if _over():
				_start()
		KEY_B:
			# **테스트 빌드 전용.** 보스까지 기다리지 않고 바로 붙는다.
			if not _over() and SaD.test_build():
				world.skip_to_boss()
		KEY_ENTER, KEY_KP_ENTER:
			if _over():
				_to_select()
		KEY_ESCAPE:
			_to_select()

# ==================== 그리기 ====================


func _draw_field() -> void:
	world.draw(field)


func _draw_over() -> void:
	if mode != Mode.PLAY:
		return
	var r := Rect2(Vector2.ZERO, field.size)
	SaHud.boss_bar(over, r, world)
	SaHud.overlay(over, r, world)


func _draw() -> void:
	if mode == Mode.SELECT:
		sel.draw(self, vs)
		return
	draw_rect(Rect2(Vector2.ZERO, vs), SaP.VOID, true)
	SaHud.gutters(self, play, vs)
	SaHud.top_bar(self, vs, TOP, world)
	if _over():
		_big_btn(_end_btn(0), "다시", SaP.GOLD, 1.0)
		_big_btn(_end_btn(1), "기체 선택", SaP.DIM, 1.0)
		return
	SaHud.controls(self, vs, BOT, _skill_btn(), _bomb_btn(), skill_id != -2, world)
	_big_btn(_quit_btn(), "그만하기", SaP.DIMMER, 0.7)


func _big_btn(r: Rect2, label: String, col: Color, a: float) -> void:
	draw_rect(r, Color(0.05, 0.07, 0.11, 0.95 * a), true)
	draw_rect(r, SaP.a(col, 0.9 * a), false, 2.0)
	SaG2.text_mid(self, r.get_center(), label, minf(34.0, r.size.y * 0.45), SaP.a(col, a))
