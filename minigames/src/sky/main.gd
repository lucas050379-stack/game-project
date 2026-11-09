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

## 처음 화면(TITLE — 다섯 게임 같은 틀: 왼쪽 제목 · 오른쪽 최고 기록과 조작법 · 시작은 오른쪽 아래) → 기체 고르기(SELECT) → 판(PLAY).
## 예전엔 기체 고르기가 곧 첫 화면이라 다른 게임과 들어가는 방식이 달랐다(사용자 지적 11-08).
enum Mode { TITLE, SELECT, PLAY }

const TOP := 146.0      ## 위 점수 띠 높이(화면 px)
const BOT := 236.0      ## 아래 단추 띠 높이

var mode := Mode.TITLE
var book := UiBook.new()  ## 처음 화면의 도감 · 순위 창
var recorded := false     ## 이번 판 기록을 넣었나(판이 끝난 순간 한 번)
var rec_rank := -1        ## 이번 판이 최고 기록 몇 등에 들었나(-1 = 못 듦)
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
var quit_until := 0        ## 이 시각(ms)까지 그만하기를 다시 누르면 나간다

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
	for a in _args():
		if a.begins_with("--menu="):   # 확인용 — 처음 화면 N번 메뉴(도감 · 순위)를 바로 연다
			_menu.call_deferred(int(a.substr(7)))
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


## 가로 화면 — 플레이필드는 가운데 세로 띠로 화면 높이 가득, 정보 · 단추는 좌우 정보창(갈루가 원본 구조 ·
## 사용자 결정 11-04). 세로 화면이면 위 점수 띠 · 아래 단추 띠.
func wide() -> bool:
	return vs.x > vs.y


func _top() -> float:
	return 0.0 if wide() else TOP


func _bot() -> float:
	return 0.0 if wide() else BOT


func _layout() -> void:
	vs = get_viewport_rect().size
	var avail := vs.y - _top() - _bot()
	k = minf(vs.x / SaD.PLAY_W, avail / SaD.PLAY_H_MIN)
	if wide():
		k = minf((vs.x - 2.0 * SIDE_MIN) / SaD.PLAY_W, avail / SaD.PLAY_H_MIN)
	var pw := SaD.PLAY_W * k
	play = Rect2(Vector2(floorf((vs.x - pw) * 0.5), _top()), Vector2(pw, avail))
	for c: Control in [field, over]:
		c.position = play.position
		c.scale = Vector2(k, k)
		c.size = Vector2(SaD.PLAY_W, avail / k)
	if world != null:
		world.setup(avail / k)


const SIDE_MIN := 260.0   ## 가로 화면 정보창의 최소 폭 — 이보다 좁아지면 필드를 줄인다


## 아래 띠(가로 화면이면 좌우 정보창 아래)의 단추. 그리기와 터치 판정이 같은 함수를 본다.
func _skill_btn() -> Rect2:
	if wide():
		return Rect2(22, vs.y - 144, play.position.x - 44, 122)
	return Rect2(16, vs.y - BOT + 18, 210, BOT - 36)


func _bomb_btn() -> Rect2:
	if wide():
		return Rect2(play.end.x + 22, vs.y - 144, vs.x - play.end.x - 44, 122)
	return Rect2(vs.x - 226, vs.y - BOT + 18, 210, BOT - 36)


func _quit_btn() -> Rect2:
	if wide():
		return Rect2(play.position.x - 134, 20, 112, 44)   # 스킬 단추에서 먼 왼쪽 위 — 붙여 두면 터치 때 잘못 눌린다
	return Rect2(vs.x * 0.5 - 95, vs.y - 80, 190, 62)


## 판이 끝난 뒤 — 0 = 다시, 1 = 기체 선택
func _end_btn(i: int) -> Rect2:
	if wide():
		var x := play.position.x * 0.5 if i == 0 else play.end.x + (vs.x - play.end.x) * 0.5
		return Rect2(x - 130, vs.y - 144, 260, 122)
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
	recorded = false
	rec_rank = -1
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
	Bgm.mood(mode == Mode.PLAY and world != null and not world.boss.is_empty())   # 상황 음악(11-09): 보스전은 급박 변주
	t += dt
	if shot_path != "" and shot_at > 0.0 and t >= shot_at:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	if touch_test:
		_touch_test_step()
	if mode == Mode.TITLE:
		sel.step(dt)   # 처음 화면의 기체 그림도 같은 시계로 움직인다
		queue_redraw()
		return
	if mode == Mode.SELECT:
		sel.step(dt)
		queue_redraw()
		return
	# 판이 끝난 순간 한 번 — 최고 기록에 넣는다(확인용 실행은 빼고)
	if _over() and not recorded:
		recorded = true
		# 라운드 연습(중간 라운드부터 시작)은 순위에 넣지 않는다 — 1라운드부터 간 정식 출격만
		if OS.get_cmdline_user_args().is_empty() and not world.god and not sel.practice:
			rec_rank = SaRec.add(world.score, world.craft, world.round_i, world.diff, world.st == SaWorld.St.ALLCLEAR)

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
	# 음량 창(기체 고르는 화면의 오른쪽 위 "음량") — 떠 있는 동안은 창이 다 받는다. 터치는 마우스처럼 넘긴다
	if Vol.open:
		if e is InputEventScreenTouch:
			if e.pressed:
				Vol.press(e.position, vs)
			else:
				Vol.release()
		elif e is InputEventScreenDrag:
			Vol.motion(e.position, vs)
		elif not (e is InputEventMouseButton and e.device == InputEvent.DEVICE_ID_EMULATION):
			Vol.handle(e, vs)
		return
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
	if mode == Mode.TITLE:
		if book.click(p, vs):
			return
		for j in MENU.size():
			if UiKit.menu_rect(vs, j).has_point(p):
				Snd.play("pop")
				_menu(j)
				return
		if Hub.std_rect("start", vs).has_point(p):
			# 정식 출격은 1라운드부터(라운드 줄은 "라운드 연습" 에서만)
			sel.practice = false
			sel.round = 0
			mode = Mode.SELECT
			Snd.play("pop")
		elif Hub.std_rect("hub", vs).has_point(p):
			Hub.leave(self)
		elif Hub.std_rect("vol", vs).has_point(p):
			Vol.open = true
		return
	if mode == Mode.SELECT:
		match sel.hit(p, vs):
			"start":
				_start()
			"hub":
				mode = Mode.TITLE   # 기체 고르기의 왼쪽 위는 "뒤로"
			"vol":
				Vol.open = true
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
		# 판을 버리는 단추라 한 번 더 눌러야 나간다(3초 안에)
		if Time.get_ticks_msec() > quit_until:
			quit_until = Time.get_ticks_msec() + 3000
			return
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
		3:
			# 처음 화면 "출격 준비" → 기체 고르기
			_send_touch(0, Hub.std_rect("start", vs).get_center(), true)
			_send_touch(0, Hub.std_rect("start", vs).get_center(), false)
		5:
			if mode != Mode.SELECT:
				fail = "처음 화면에서 기체 고르기로 안 넘어감"
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
	if mode == Mode.TITLE:
		if book.key(code):
			return
		if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z, KEY_X]:
			sel.practice = false
			sel.round = 0
			mode = Mode.SELECT
		elif code == KEY_ESCAPE:
			Hub.leave(self)
		return
	if mode == Mode.SELECT:
		if sel.key(code):
			_start()
		elif code == KEY_ESCAPE:
			mode = Mode.TITLE
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


## 처음 화면 — 다섯 게임 같은 틀: 왼쪽 제목 · 기체 그림, 오른쪽 "최고 기록"(위 다섯) · "조작법", 오른쪽 아래 "출격 준비".
func _draw_title() -> void:
	SaSel.draw_bg(self, vs, 0.42)
	var lx := vs.x * 0.3 if wide() else vs.x * 0.5
	var col := SaP.craft(sel.craft, 3)
	# 제목
	# 게임 이름 — 다섯 게임 같은 방식(UiKit.title)
	UiKit.title(self, vs, "sky", "스카이 어설트", "기체마다 파워업이 자라는 방향이 다릅니다", t)
	# 기체 — 고른 기체가 위아래로 떠 있고 뒤로 엔진 빛
	var cp := Vector2(lx, (430.0 if wide() else 400.0) + sin(t * 1.6) * 8.0)
	SaG2.glow(self, cp + Vector2(0, 60), 120.0, col, 0.18)
	SaArt.craft(self, sel.craft, cp, t, 3.2)
	SaG2.text_mid(self, cp + Vector2(0, 150), "%s  %s" % [SaD.CRAFT[sel.craft].id, SaD.CRAFT[sel.craft].name], 26.0, SaP.hdr(col, 1.1))
	# 오른쪽 메뉴 — 다섯 게임 같은 구조(모드 · 도감 · 도감 · 순위)
	for j in MENU.size():
		UiKit.menu(self, UiKit.menu_rect(vs, j), String(MENU[j]), MENU_COL[j], "sky", t)
	SaRec.load_()
	if not SaRec.list.is_empty():
		UiKit.record_line(self, vs, "최고 기록 " + _comma(int(SaRec.list[0].score)))
	UiKit.button(self, vs, "hub", "sky", t)
	UiKit.button(self, vs, "vol", "sky", t)
	UiKit.button(self, vs, "start", "sky", t, "출격")
	book.draw(self, vs, t)


const MENU := ["라운드 연습", "기체 도감", "보스 도감", "순위"]
const MENU_COL := [Color8(60, 120, 200), Color8(40, 150, 170), Color8(170, 70, 90), Color8(120, 90, 190)]
const BOSS_ORDER := ["midboss", "battleship", "landfort", "carrier", "disc", "robot", "fortress"]
## 보스 도감 설명 — 하는 일(SaWorld._boss_act)을 사람 말로.
const BOSS_NOTE := {
	midboss = "라운드 중간에 아래에서 올라온다. 부위를 부수면 점수가 붙는다.",
	battleship = "세로로 긴 함선. 주포 셋이 차례로 불을 뿜는다.",
	landfort = "땅에 박혔다가 굴러간다. 주포 포신이 너를 겨눈다.",
	carrier = "화면 밖으로 빠져 편대를 내보낸다. 발진구를 부숴라.",
	disc = "사라졌다 나타난다. 꽃잎이 열릴 때가 빈틈.",
	robot = "비행기에서 로봇으로, 다시 구체로. 세 번 싸운다.",
	fortress = "산에 박힌 요새. 아치 아래 면에서만 맞는다.",
}


## 처음 화면 메뉴 j 를 눌렀다.
func _menu(j: int) -> void:
	book.game = "sky"
	match j:
		0:
			sel.practice = true
			mode = Mode.SELECT
		1:
			var items := [{name = "조작법", desc = "끌기, 방향키, W A S D 로 이동\nShift 정밀 이동  R 스킬(누르고 떼기)\nT 봄  Esc 그만두기",
					draw = func(ci, r, tt): _draw_keys_icon(ci, r)}]
			for i in SaD.CRAFT.size():
				var c: Dictionary = SaD.CRAFT[i]
				var k := i
				items.append({name = "%s %s" % [c.id, c.name], desc = SaG2.clean("%s. 봄: %s" % [c.axis, c.bomb]),
						draw = func(ci, r, tt): SaArt.craft(ci, k, r.get_center(), tt, minf(r.size.x, r.size.y) / 72.0)})
			book.show("기체 도감", items, "grid", 4, 2)
		2:
			var items2 := []
			for key in BOSS_ORDER:
				var nm: String = "중간 보스" if key == "midboss" else String(SaD.BOSS[key].name)
				var kk: String = key
				items2.append({name = SaG2.clean(nm), desc = String(BOSS_NOTE[key]),
						draw = func(ci, r, tt): _draw_boss_icon(ci, r, kk)})
			book.show("보스 도감", items2, "grid", 4, 2)
		3:
			var rows := []
			SaRec.load_()
			for i in SaRec.list.size():
				var e: Dictionary = SaRec.list[i]
				var craft_name: String = SaD.CRAFT[clampi(int(e.craft), 0, SaD.CRAFT.size() - 1)].name
				var how := "전부 클리어" if bool(e.get("clear", false)) else "%d라운드까지" % (int(e.round) + 1)
				rows.append({main = _comma(int(e.score)), sub = "%s  %s  %s" % [craft_name, how, SaD.DIFF[clampi(int(e.diff), 0, SaD.DIFF.size() - 1)].name],
						hl = i == rec_rank})
			book.empty_text = "아직 기록이 없습니다. 첫 출격을 해 보세요"
			book.show("순위", rows, "list")


func _draw_boss_icon(ci: CanvasItem, r: Rect2, key: String) -> void:
	var tex := SaArt.img(String(SaArt.TEX_OF.get(key, "")))
	if key == "robot":
		tex = SaArt.img("sky_gangsin_full")
	if tex == null:
		SaG2.text_mid(ci, r.get_center(), "?", 60.0, SaP.DIM)
		return
	var ts := tex.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y) * 0.92
	var sz := ts * k
	var turn: float = SaArt.TEX_TURN.get(key, 0.0)
	ci.draw_set_transform(r.get_center(), turn, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_keys_icon(ci: CanvasItem, r: Rect2) -> void:
	# 자판 네 개(W A S D) — 조작법 카드의 그림
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.22
	var keys := [["W", Vector2(0, -1)], ["A", Vector2(-1, 0)], ["S", Vector2(0, 0)], ["D", Vector2(1, 0)]]
	for kd in keys:
		var p: Vector2 = c + Vector2(kd[1]) * (s * 1.15) + Vector2(0, s * 0.5)
		var kr := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
		ci.draw_rect(kr, Color(0.1, 0.16, 0.24), true)
		SaG2.stroke_rect(ci, kr, Color8(110, 220, 255), 2.0)
		SaG2.text_mid(ci, kr.get_center(), String(kd[0]), s * 0.5, SaP.WHITE)


func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


func _draw_field() -> void:
	world.draw(field)


func _draw_over() -> void:
	if mode != Mode.PLAY:
		return
	var r := Rect2(Vector2.ZERO, field.size)
	if not wide():
		SaHud.boss_bar(over, r, world)   # 가로 화면은 오른쪽 정보창에 — 필드 위 막대가 보스를 가렸다
	SaHud.overlay(over, r, world)


func _draw() -> void:
	if mode == Mode.TITLE:
		_draw_title()
		Vol.draw(self, vs, t)
		return
	if mode == Mode.SELECT:
		sel.draw(self, vs)
		Vol.draw(self, vs, t)
		return
	draw_rect(Rect2(Vector2.ZERO, vs), SaP.VOID, true)
	SaHud.gutters(self, play, vs)
	if wide():
		SaHud.sides(self, vs, play, world)
	else:
		SaHud.top_bar(self, vs, TOP, world)
	if _over():
		_big_btn(_end_btn(0), "다시", SaP.GOLD, 1.0)
		_big_btn(_end_btn(1), "기체 선택", SaP.DIM, 1.0)
		return
	if wide():
		SaHud.buttons(self, _skill_btn(), _bomb_btn(), skill_id != -2, world)
	else:
		SaHud.controls(self, vs, BOT, _skill_btn(), _bomb_btn(), skill_id != -2, world)
	var armed := Time.get_ticks_msec() < quit_until
	_big_btn(_quit_btn(), "한 번 더" if armed else "그만하기", SaP.GOLD if armed else SaP.DIM, 1.0 if armed else 0.7)


## 단추 — 다섯 게임 같은 입체 단추(UiKit, 스카이 네온 테마). 색은 몸통에 짙게 섞는다. a < 1 이면 누를 수 없는 듯 흐리게.
func _big_btn(r: Rect2, label: String, col: Color, a: float) -> void:
	var fill := Color(col.r, col.g, col.b).darkened(0.62).lerp(Color8(14, 22, 36), 0.35)
	UiKit.plain(self, r, label, fill, "sky", t, a >= 0.99, minf(30.0, r.size.y * 0.42))
