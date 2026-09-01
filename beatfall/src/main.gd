extends Node2D

## 진입점 — 화면 배치 · 입력 · 루프.
##
## 플레이필드는 화면 한가운데 세로 띠이고 양옆은 정보 패널이다.
## **`_draw()` 에는 클리핑이 없다** — 노트는 clip_contents 를 켠 [Control] 자식
## `field` 안에서 그린다. 안 그러면 판정선을 지나 아래로 흘러가는 노트가
## 조작대 자리까지 삐져나온다.
##
## **자식은 부모보다 나중에, 즉 위에 그려진다.** 그래서 HUD 는 `field` 다음에
## 추가한 `over` 에 그린다.

enum Mode { SELECT, PLAY, RESULT, FAIL }

var mode := Mode.SELECT
var sel := Sel.new()
var pl := Play.new()
var cond := Conductor.new()
var warp := Warp.new()
var keys := Keys.new()
var music: AudioStreamPlayer

var field: Control
var over: Control
var field_rect := Rect2()
var cur_song: Song = null
var cur_diff := {}
var new_record := false
## 이번 판에서 쓰는 배속. 판 도중에 바꿔도 노트가 순간이동하지 않게 따로 든다.
var speed := 2.0


func _ready() -> void:
	# 음악만 따로 버스를 쓴다. 효과음(있다면)은 Master 로 나가야 같이 망가지지 않는다.
	warp.setup()
	music = AudioStreamPlayer.new()
	music.bus = Warp.BUS
	add_child(music)
	cond.attach(music)
	field = Control.new()
	field.clip_contents = true
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.visible = false
	add_child(field)
	field.draw.connect(_draw_field)
	over = Control.new()
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(over)                    # field 다음에 추가해야 그 위에 그려진다
	over.draw.connect(_draw_over)
	_layout()
	get_viewport().size_changed.connect(_layout)
	# 확인용 무인 주행: `run.bat -- --autoplay [--diff=2]`
	# 곡 선택을 건너뛰고 첫 곡을 자동으로 친다. 판정·싱크·그리기를 한 번에 훑는다.
	if _flag("--autoplay"):
		Sv.autoplay = true
		sel.si = clampi(_opt_int("--song", 0), 0, sel.songs.size() - 1)
		sel.di = clampi(_opt_int("--diff", 1), 0, sel.song().chart.diffs.size() - 1)
		_start()


func _args() -> PackedStringArray:
	var a := OS.get_cmdline_args()
	a.append_array(OS.get_cmdline_user_args())
	return a


func _flag(name: String) -> bool:
	return _args().has(name)


func _opt_int(name: String, def: int) -> int:
	for a in _args():
		if a.begins_with(name + "="):
			return int(a.substr(name.length() + 1))
	return def


func _layout() -> void:
	var vs := get_viewport_rect().size
	# 필드 폭은 레인이 다 들어갈 만큼만. 남는 자리는 전부 패널이다.
	var fw := minf(vs.x - 460.0, 620.0)
	field_rect = Rect2(Vector2(floorf((vs.x - fw) * 0.5), 0.0), Vector2(maxf(fw, 300.0), vs.y))
	field.position = field_rect.position
	field.size = field_rect.size
	over.position = Vector2.ZERO
	over.size = vs


## 확인용 화면 캡처: `run.bat -- --shot=out.png [--shot-at=90]`
## 자리 배치는 눈으로 봐야 확실하다 — 겹치거나 화면 밖으로 나간 것은 코드만 봐서는
## 안 보인다. **`hdr_2d` 때문에 캡처는 실제보다 훨씬 어둡게 나온다**(선형 공간으로
## 저장된다). 밝기로 판단하지 말고 자리만 보라.
var _shot_frame := 0


func _shot_step() -> void:
	var path := ""
	for a in _args():
		if a.begins_with("--shot="):
			path = a.substr(7)
	if path.is_empty():
		return
	_shot_frame += 1
	if _shot_frame != _opt_int("--shot-at", 60):
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[shot] ", path, "  ", img.get_width(), "x", img.get_height())


func _process(delta: float) -> void:
	_shot_step()
	match mode:
		Mode.SELECT:
			sel.cal_step()
		Mode.PLAY:
			cond.tick(delta)
			pl.autoplay = Sv.autoplay
			pl.step(cond.pos, delta)
			warp.apply(pl.warp * (D.WARP_WITH_KEYS if keys.active else 1.0))
			keys.step(cond.pos)
			if pl.dead:
				_fail()
			elif cond.finished(pl.last_t):
				_finish()
	queue_redraw()
	field.queue_redraw()
	over.queue_redraw()


# ==================== 판 흐름 ====================

func _start() -> void:
	cur_song = sel.song()
	cur_diff = sel.diff()
	# 키음 모드: 저음만 남긴 **바닥층**이 계속 흐르고, 나머지는 노트 시각으로 잘려
	# 노트에 붙는다([Keys]). 바닥층이 [Conductor] 의 시계도 된다 —
	# **곡 전체를 노트에 매달면 음이 빌 때 시계가 같이 사라진다.**
	var lay := [] if (Sv.no_keysound or _flag("--nokeys")) else cur_song.layers()
	var s: AudioStream = lay[0] if lay.size() == 2 else cur_song.stream()
	if s == null:
		return                          # 곡 파일이 없다. 선택 화면에 그대로 머문다
	music.stream = s
	music.volume_db = linear_to_db(clampf(Sv.vol_music, 0.0001, 1.0))
	speed = Sv.speed
	Sv.keys = int(cur_diff.keys)
	Sv.save_cfg()
	pl = Play.new()
	pl.autoplay = Sv.autoplay
	# setup() 이 노트마다 표시를 남기므로 **그 전에** 정해야 한다.
	pl.miss_every = _opt_int("--miss", 0)
	pl.setup(cur_diff)
	keys.setup(self, lay[1] if lay.size() == 2 else null, pl.notes,
		cur_song.chart.last_time(sel.di) + 4.0, Sv.vol_music)
	pl.fire = keys.hit
	cond.song_offset = cur_song.chart.offset
	cond.start()
	mode = Mode.PLAY
	field.visible = true


func _finish() -> void:
	cond.stop()
	keys.stop()
	# 결과 화면은 원곡 소리로 돌아가야 한다. 안 되돌리면 다음 판도 망가진 채 시작한다.
	warp.reset()
	mode = Mode.RESULT
	field.visible = false
	if Sv.autoplay and _flag("--autoplay"):
		# 무인 주행 결과. **자동 연주는 전부 PERFECT 가 나와야 한다** —
		# 치는 쪽도 판정하는 쪽도 같은 [member Conductor.pos] 를 보기 때문이다.
		# 여기서 GREAT 이하가 섞이면 시계가 두 갈래로 흐르고 있다는 뜻이다.
		var r := pl.result()
		print("[autoplay] %s  %07d  %.2f%%  콤보 %d/%d  판정 %s" % [
			r.rank, r.score, r.acc * 100.0, r.combo, r.total, str(r.counts)])
	# 자동 연주는 기록으로 남기지 않는다 — 남기면 기록이 의미를 잃는다.
	new_record = false
	if not Sv.autoplay:
		new_record = Sv.submit(cur_song.id, cur_diff.name, pl.result())


func _fail() -> void:
	cond.stop()
	keys.stop()
	warp.reset()
	mode = Mode.FAIL
	field.visible = false


func _to_select() -> void:
	cond.stop()
	keys.stop()
	warp.reset()
	mode = Mode.SELECT
	field.visible = false


# ==================== 입력 ====================

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		if e.pressed and not e.echo:
			_key_down(e.keycode)
		elif not e.pressed:
			_key_up(e.keycode)
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_click(e.position)


func _key_down(k: int) -> void:
	match mode:
		Mode.SELECT:
			if sel.key(k):
				_start()
		Mode.PLAY:
			_play_key(k)
		Mode.RESULT, Mode.FAIL:
			if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_ESCAPE:
				_to_select()
			elif k == KEY_R:
				_start()


func _key_up(k: int) -> void:
	if mode != Mode.PLAY:
		return
	var km: Array = D.KEYMAP[pl.keys]
	var lane := km.find(k)
	if lane >= 0:
		pl.release(lane)


func _play_key(k: int) -> void:
	if k == KEY_ESCAPE:
		_to_select()
		return
	# 배속은 판 도중에도 바꿀 수 있다. 곡을 다시 시작하지 않고 화면만 바뀐다.
	if k == KEY_BRACKETLEFT:
		speed = clampf(speed - D.SPEED_STEP, D.SPEED_MIN, D.SPEED_MAX)
		Sv.speed = speed
		return
	if k == KEY_BRACKETRIGHT:
		speed = clampf(speed + D.SPEED_STEP, D.SPEED_MIN, D.SPEED_MAX)
		Sv.speed = speed
		return
	var km: Array = D.KEYMAP[pl.keys]
	var lane := km.find(k)
	if lane >= 0:
		pl.press(lane, cond.pos)


## 새 화면을 만들면 키 분기와 마우스 분기를 **둘 다** 채운다.
## 키만 넣으면 키로는 되기 때문에 "마우스로 못 고른다"를 눈치채기 어렵다.
func _click(at: Vector2) -> void:
	match mode:
		Mode.SELECT:
			if sel.click(get_viewport_rect().size, at):
				_start()
		Mode.RESULT, Mode.FAIL:
			_to_select()


# ==================== 그리기 ====================

func _draw() -> void:
	if mode == Mode.SELECT:
		sel.draw(self, get_viewport_rect().size)


func _draw_field() -> void:
	if mode != Mode.PLAY:
		return
	# field 는 자기 좌표계라 원점이 (0,0) 이다.
	var local := Rect2(Vector2.ZERO, field_rect.size)
	Art.draw_field(field, local, pl, cond.smooth, speed, cur_song.chart.bpm)


func _draw_over() -> void:
	var vs := get_viewport_rect().size
	match mode:
		Mode.PLAY:
			Hud.draw_play(over, vs, field_rect, pl, cur_song, cur_diff,
				cond.pos, cur_song.chart.last_time(sel.di))
		Mode.RESULT:
			Hud.draw_result(over, vs, pl, cur_song, cur_diff, new_record)
		Mode.FAIL:
			Hud.draw_result(over, vs, pl, cur_song, cur_diff, false)
			Hud.draw_fail(over, vs)
