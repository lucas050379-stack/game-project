extends Node2D

## 비술난무 — 진입점. 화면 상태(타이틀 → 플레이 → 결과) · 입력 · 그리기.
##
## 세상은 논리 426×240 이고, 정수배(가로 화면 3배)로 키워 그린다. 320×180 · 4배로 시작했는데 주인공과 적이 화면을 꽉 채워 싸울 자리가 없었다. 픽셀이 뭉개지지 않게 이 노드만
## TEXTURE_FILTER_NEAREST 이고(프로젝트 기본은 선형) 카메라 · 몸 위치는 정수 픽셀로 반올림한다.
## 그림은 전부 pixelfx 로 구운 시트(MsAnim). 계산은 MsWorld 가 하고, 여기는 그 ev 를 받아 이펙트 · 소리로 바꾼다.
##
## 입력은 셋이 같은 길을 지난다 — 키보드 방향 · 터치 십자키 → MsWorld.key_dir → MsCmd.
## 터치는 멀티터치를 직접 받고 흉내 낸 마우스(DEVICE_ID_EMULATION)는 거른다(스카이 어설트와 같은 방식).
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

const RIG_S := 1.0           ## 컷아웃 캐릭터 배율(관절 px → 세상 px). 판정 상자(MsWorld.hero_body)와 같이 맞출 것
var world: MsWorld
var mode := "title"          ## title · play · result
var vs := Vector2(1280, 720)
var k := 4.0                 ## 논리 → 화면 배율
var view := Rect2()          ## 세상이 그려지는 화면 자리
var t := 0.0
var fxs: Array = []          ## {name, x, y, flip, t, scale}
var banner := ""
var banner_t := 0.0
var clear_t := 0.0
var touch_seen := false      ## 터치를 한 번이라도 쓰면 화면 조작판을 그린다
var quit_until := 0
var best := 0
var auto := false
var shot_path := ""
var shot_times: Array = []
var shot_count := 0
var _flash := ""             ## 방금 쓴 기술 이름(화면 위에 잠깐)
var _flash_t := 0.0

# 터치 상태
var pad_id := -9             ## 십자키를 누르고 있는 손가락
var touch_btn := {}          ## 손가락 → 단추 이름
var pad_dir := {"L": false, "R": false, "U": false, "D": false}
var key_dir := {"L": false, "R": false, "U": false, "D": false}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Bgm.use("sky")
	_load_best()
	get_viewport().size_changed.connect(_layout)
	_layout()
	for a in OS.get_cmdline_user_args():
		if a == "--ms-auto":
			auto = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_times = Array(a.substr(10).split(",")).map(func(x): return float(x))
	if auto:
		var st := 0
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--ms-stage="):
				st = clampi(int(a.substr(11)) - 1, 0, MsD.STAGES.size() - 1)
		_start(st)


func _layout() -> void:
	vs = get_viewport_rect().size
	if wide():
		k = maxf(1.0, floorf(minf(vs.x / MsD.VIEW_W, vs.y / MsD.VIEW_H)))
		view = Rect2((vs.x - MsD.VIEW_W * k) * 0.5, (vs.y - MsD.VIEW_H * k) * 0.5, MsD.VIEW_W * k, MsD.VIEW_H * k)
	else:
		k = vs.x / MsD.VIEW_W
		view = Rect2(0, 130, vs.x, MsD.VIEW_H * k)
	queue_redraw()


func wide() -> bool:
	return vs.x > vs.y


func _start(st: int) -> void:
	world = MsWorld.new(st)
	fxs.clear()
	mode = "play"
	_banner(String(MsD.STAGES[st].name), 2.0)


func _banner(s: String, d: float) -> void:
	banner = s
	banner_t = d

# ==================== 루프 ====================


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	banner_t = maxf(0.0, banner_t - dt)
	_flash_t = maxf(0.0, _flash_t - dt)
	if mode == "play":
		if auto:
			world.bot(dt)
		else:
			for d in ["L", "R", "U", "D"]:
				world.hold[d] = key_dir[d] or pad_dir[d]
		world.step(dt)
		_drain()
		for f in fxs:
			f.t += dt
		if world.state == "clear":
			clear_t += dt
			if clear_t > 2.4:
				clear_t = 0.0
				var hp: float = world.hero.hp
				var sc := world.score
				var mc := world.max_combo
				var kl := world.kills
				world.start_stage(world.stage + 1)
				world.hero.hp = minf(MsD.HERO_HP, hp + MsD.HERO_HP * 0.4)
				world.score = sc
				world.max_combo = mc
				world.kills = kl
				fxs.clear()
				_banner(String(MsD.STAGES[world.stage].name), 2.0)
		elif world.state in ["over", "win"]:
			clear_t += dt
			if clear_t > 1.6:
				clear_t = 0.0
				_finish()
	# 캡처 — --shot-at=8,14,20 처럼 여러 시각을 주면 out_1.png, out_2.png … 로 한 번 실행에 몰아 찍는다
	if shot_path != "" and not shot_times.is_empty() and t >= float(shot_times[0]):
		var n := shot_count + 1
		var path := shot_path if shot_times.size() == 1 and n == 1 else shot_path.get_basename() + "_%d.png" % n
		get_viewport().get_texture().get_image().save_png(path)
		shot_times.remove_at(0)
		shot_count = n
		if shot_times.is_empty():
			get_tree().quit()
	queue_redraw()


func _drain() -> void:
	for e in world.ev:
		if e.has("fx"):
			fxs.append({name = e.fx, x = e.x, y = e.y, flip = e.flip, t = -float(e.get("delay", 0.0)), scale = float(e.get("scale", 1.0))})
		elif e.has("flash"):
			_flash = String(MsD.SKILL_NAME.get(e.flash, ""))
			_flash_t = 1.0
		elif e.has("snd"):
			if e.snd == "go":
				_banner("GO", 1.6)
			elif e.snd == "clear":
				_banner("스테이지 클리어" if world.state == "clear" else "모든 스테이지 돌파", 2.4)
			elif e.snd == "boss":
				_banner(String(MsD.BOSS[world.stage].name), 2.0)
	world.ev.clear()
	# 끝난 이펙트를 뺀다(화면에 많아야 열 몇 개)
	var i := 0
	while i < fxs.size():
		var f: Dictionary = fxs[i]
		var s: Variant = MsAnim.sheet(f.name)
		if s == null or (f.t >= 0.0 and MsAnim.frame_at(s, f.t) < 0):
			fxs.remove_at(i)
		else:
			i += 1


func _finish() -> void:
	if world.score > best:
		best = world.score
		_save_best()
	mode = "result"


func _load_best() -> void:
	var c := ConfigFile.new()
	if c.load("user://mystic.cfg") == OK:
		best = int(c.get_value("best", "score", 0))


func _save_best() -> void:
	if auto:
		return   # 확인용 실행은 기록을 안 남긴다
	var c := ConfigFile.new()
	c.set_value("best", "score", best)
	c.save("user://mystic.cfg")

# ==================== 입력 ====================

const KEY_DIR := {KEY_LEFT: "L", KEY_RIGHT: "R", KEY_UP: "U", KEY_DOWN: "D"}


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		_key(e)
		return
	if e is InputEventScreenTouch:
		touch_seen = true
		if e.pressed:
			_touch_down(e.index, e.position)
		else:
			_touch_up(e.index)
		return
	if e is InputEventScreenDrag:
		if e.index == pad_id:
			_pad_to(e.position)
		return
	if e is InputEventMouseButton:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_touch_down(-1, e.position)
			else:
				_touch_up(-1)
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and pad_id == -1:
		_pad_to(e.position)


func _key(e: InputEventKey) -> void:
	var kc := e.keycode
	if KEY_DIR.has(kc):
		var d: String = KEY_DIR[kc]
		if e.pressed and not e.echo and not key_dir[d] and mode == "play":
			world.key_dir(d)
		key_dir[d] = e.pressed
		return
	if not e.pressed or e.echo:
		return
	match kc:
		KEY_Z, KEY_J:
			if mode == "play":
				world.key_atk()
			elif mode == "title":
				_start(0)
			elif mode == "result":
				mode = "title"
		KEY_X, KEY_C, KEY_K:
			if mode == "play":
				world.key_jump()
		KEY_ENTER, KEY_SPACE:
			if mode == "title":
				_start(0)
			elif mode == "result":
				mode = "title"
		KEY_ESCAPE:
			_back()


func _back() -> void:
	if mode == "play":
		if Time.get_ticks_msec() < quit_until:
			mode = "title"
		else:
			quit_until = Time.get_ticks_msec() + 1500
			_banner("한 번 더 누르면 그만둡니다", 1.5)
	else:
		Hub.leave(self)


func _touch_down(id: int, p: Vector2) -> void:
	if mode != "play":
		if _back_rect().has_point(p):
			_back()
		elif mode == "title":
			_start(0)
		else:
			mode = "title"
		return
	if _back_rect().has_point(p):
		_back()
		return
	if touch_seen or id == -1:
		if p.distance_to(pad_center()) <= pad_radius() * 1.25:
			pad_id = id
			_pad_to(p)
			return
		for b in buttons():
			if p.distance_to(b.c) <= float(b.r) * 1.15:
				touch_btn[id] = b.id
				_press_button(String(b.id))
				return


func _touch_up(id: int) -> void:
	if id == pad_id:
		pad_id = -9
		for d in pad_dir:
			pad_dir[d] = false
	touch_btn.erase(id)


func _pad_to(p: Vector2) -> void:
	var v := p - pad_center()
	var nd := {"L": false, "R": false, "U": false, "D": false}
	if v.length() > pad_radius() * 0.22:
		var n := v.normalized()
		nd.L = n.x < -0.42
		nd.R = n.x > 0.42
		nd.U = n.y < -0.42
		nd.D = n.y > 0.42
	for d in nd:
		if nd[d] and not pad_dir[d] and mode == "play":
			world.key_dir(d)
		pad_dir[d] = nd[d]


func _press_button(id: String) -> void:
	match id:
		"atk":
			world.key_atk()
		"jump":
			world.key_jump()
		_:
			world.key_skill(id)

# ==================== 자리 ====================
# 그리기와 터치 판정이 같은 함수를 본다.


func pad_center() -> Vector2:
	if wide():
		return Vector2(170, vs.y - 170)
	return Vector2(190, view.end.y + (vs.y - view.end.y) * 0.62)


func pad_radius() -> float:
	return 120.0 if wide() else 150.0


## 조작 단추 — 공격 · 점프 · 기술 다섯(바로 쓰기, MP 1.25배).
func buttons() -> Array:
	var out: Array = []
	var base: Vector2
	var r := 74.0
	if wide():
		base = Vector2(vs.x - 150, vs.y - 150)
	else:
		base = Vector2(vs.x - 160, view.end.y + (vs.y - view.end.y) * 0.66)
		r = 86.0
	out.append({id = "atk", c = base, r = r, label = "Z"})
	out.append({id = "jump", c = base + Vector2(-r * 2.1, r * 0.55), r = r * 0.78, label = "X"})
	var sr := r * 0.5
	for i in MsD.SKILL_ORDER.size():
		var a := deg_to_rad(-170.0 + i * 38.0)
		var c := base + Vector2(cos(a), sin(a)) * r * 2.25
		if not wide():
			c = Vector2(vs.x * 0.5 + (i - 2) * sr * 2.6, view.end.y + 70.0)
		out.append({id = MsD.SKILL_ORDER[i], c = c, r = sr, label = String(MsD.SKILL_NAME[MsD.SKILL_ORDER[i]]).substr(0, 2)})
	return out


func _back_rect() -> Rect2:
	return Rect2(18, 18, 120, 52)

# ==================== 그리기 ====================


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(10, 8, 16))
	if mode == "play" or (mode == "result" and world != null):
		_draw_world()
		_draw_hud()
		if mode == "play" and (touch_seen or not wide()):
			_draw_touch()
	if mode == "title":
		_draw_title()
	elif mode == "result":
		_draw_result()
	_btn(_back_rect(), "나가기" if mode != "play" else "그만")


## 세상 좌표 → 화면 좌표(정수 픽셀로 반올림한 뒤 배율).
func _sp(x: float, y: float, sh: Vector2 = Vector2.ZERO) -> Vector2:
	return view.position + (Vector2(roundf(x - world.cam_x), roundf(y)) + sh) * k


func _draw_world() -> void:
	var sh := Vector2.ZERO
	if world.shake > 0.0:
		sh = Vector2(randi_range(-2, 2), randi_range(-1, 1))
	_draw_bg(sh)
	# 땅에 그리는 경고(보스 찍기 원) — 몸보다 먼저
	for e in world.enemies:
		if e.get("boss", false) and e.st == "cast" and e.batk == "slam":
			var r: float = MsD.BOSS_ATK.slam.r
			var c := _sp(e.bx, MsD.GROUND, sh)
			var p := 0.5 + 0.5 * sin(t * 18.0)
			_ellipse(c, Vector2(r, 6.0) * k, Color(1, 0.2, 0.3, 0.25 + 0.25 * p))
			_ellipse(c, Vector2(r * clampf(e.t / float(MsD.BOSS_ATK.slam.cast), 0.0, 1.0), 6.0) * k, Color(1, 0.3, 0.35, 0.5))
	for e in world.enemies:
		_draw_enemy(e, sh)
	_draw_hero(sh)
	for s in world.shots:
		_draw_shot(s, sh)
	for f in fxs:
		if f.t < 0.0:
			continue
		var sht: Variant = MsAnim.sheet(f.name)
		if sht == null:
			continue
		var i := MsAnim.frame_at(sht, f.t)
		if i < 0:
			continue
		MsAnim.blit(self, sht.tex, sht.frames[i], sht.pivot, _sp(f.x, f.y, sh), f.flip, k * float(f.scale))
	# 위에 얹는 경고(적의 "!" · 보스 베기 띠 · 구 모으기)
	for e in world.enemies:
		_draw_tell(e, sh)
	# 세로 화면이면 세상 밖(위아래)을 덮는다 — _draw 에는 클리핑이 없다
	if not wide():
		draw_rect(Rect2(0, 0, vs.x, view.position.y), Color8(10, 8, 16))
		draw_rect(Rect2(0, view.end.y, vs.x, vs.y - view.end.y), Color8(16, 14, 24))
	else:
		draw_rect(Rect2(0, 0, view.position.x, vs.y), Color8(10, 8, 16))
		draw_rect(Rect2(view.end.x, 0, vs.x - view.end.x, vs.y), Color8(10, 8, 16))


func _draw_bg(sh: Vector2) -> void:
	var st: Dictionary = MsD.STAGES[world.stage]
	var sky: Array = st.sky
	# 하늘 — 띠로 끊어 칠한다(도트 그림처럼 단계가 보이게)
	var bands := 7
	var bh := ceilf(MsD.GROUND / bands)
	for i in bands:
		var u := float(i) / (bands - 1)
		var c: Color = (sky[0] as Color).lerp(sky[1], minf(1.0, u * 2.0)) if u < 0.5 else (sky[1] as Color).lerp(sky[2], (u - 0.5) * 2.0)
		draw_rect(Rect2(view.position + Vector2(0, i * bh * k), Vector2(view.size.x, bh * k)), c)
	# 먼 산 · 가까운 언덕 — 방마다 조금씩 다른 자리(방 번호로 밀어 둔다)
	var roll := world.sec * 137.0 + world.stage * 61.0
	_hills(roll * 0.6, 92.0, 38.0, (st.hill as Color).lightened(0.12), 0.05, 1.7, sh)
	if world.stage == 0:
		_trees(roll, sh, st.hill)
	_hills(roll, 62.0, 22.0, st.hill, 0.09, 4.1, sh)
	_draw_terrain(sh, st)


## 숲 — 굵은 줄기와 둥근 잎 덩어리(첫 스테이지). 자리는 방 번호로 정해 같은 방은 언제나 같은 숲.
func _trees(roll: float, sh: Vector2, col: Color) -> void:
	var trunk := col.lightened(0.05)
	var leaf := col.lerp(Color8(40, 70, 64), 0.5)
	for i in 5:
		var x := fposmod(i * 97.0 + roll * 0.8, MsD.VIEW_W + 60.0) - 30.0
		var top := 40.0 + fposmod(i * 37.0, 30.0)
		var w := 10.0 + fposmod(i * 13.0, 8.0)
		draw_rect(Rect2(_sp(x - w * 0.5, top, sh), Vector2(w, MsD.GROUND - top) * k), trunk)
		draw_rect(Rect2(_sp(x - w * 0.5, top, sh), Vector2(2, MsD.GROUND - top) * k), trunk.lightened(0.12))
		for j in 4:
			var c := Vector2(x + (j - 1.5) * 16.0, top - 4.0 + fposmod(j * 11.0 + i, 10.0))
			draw_circle(_sp(c.x, c.y, sh), (16.0 + fposmod(j * 7.0, 8.0)) * k, leaf)


## 땅(꺾은선 아래를 채움) · 풀 · 돌 발판 · 기둥. 자리는 world.room 하나를 판정과 같이 본다.
func _draw_terrain(sh: Vector2, st: Dictionary) -> void:
	var g: Color = st.ground
	var room: Dictionary = world.room
	var pts := PackedVector2Array()
	for p in room.ground:
		pts.append(_sp(float(p[0]), float(p[1]), sh))
	pts.append(_sp(MsD.VIEW_W + 4, MsD.VIEW_H + 4, sh))
	pts.append(_sp(-4, MsD.VIEW_H + 4, sh))
	# 기둥 — 땅보다 먼저(땅 위로 솟는다)
	for p in room.plats:
		if p[3]:
			var cx := (float(p[0]) + float(p[1])) * 0.5
			var bot := world.floor_at(cx)
			_stone(Rect2(cx - 12.0, float(p[2]) + 8.0, 24.0, bot - float(p[2]) - 8.0), st, sh, 6.0)
	draw_colored_polygon(pts, g.darkened(0.15))
	# 흙 속 돌무늬 — 땅 꺾은선을 따라 몇 줄
	for i in range(0, MsD.VIEW_W, 14):
		var y := world.floor_at(i + 7.0)
		for r in 3:
			var yy := y + 8.0 + r * 9.0 + fposmod(i * 7.0, 4.0)
			draw_rect(Rect2(_sp(i + 2.0 + fposmod(r * 5.0, 6.0), yy, sh), Vector2(8, 2) * k), g.darkened(0.35))
	# 풀 — 꺾은선 위에 두 줄
	for i in range(room.ground.size() - 1):
		var a: Array = room.ground[i]
		var b: Array = room.ground[i + 1]
		var A := _sp(float(a[0]), float(a[1]), sh)
		var B := _sp(float(b[0]), float(b[1]), sh)
		draw_line(A, B, Color8(96, 168, 80), 4.0 * k)
		draw_line(A + Vector2(0, -1.5 * k), B + Vector2(0, -1.5 * k), Color8(150, 214, 110), 1.2 * k)
	# 돌 발판
	for p in room.plats:
		_stone(Rect2(float(p[0]), float(p[2]), float(p[1]) - float(p[0]), 10.0), st, sh, 10.0)
		draw_rect(Rect2(_sp(float(p[0]), float(p[2]) - 1.0, sh), Vector2(float(p[1]) - float(p[0]), 2.5) * k), Color8(110, 180, 88))


## 돌 벽돌 — 줄마다 엇갈린다. r 은 세상 좌표.
func _stone(r: Rect2, st: Dictionary, sh: Vector2, brick_h: float) -> void:
	var base := Color8(118, 128, 112).lerp(st.ground, 0.25)
	draw_rect(Rect2(_sp(r.position.x, r.position.y, sh), r.size * k), base.darkened(0.45))
	var rows := int(ceilf(r.size.y / brick_h))
	for j in rows:
		var y := r.position.y + j * brick_h
		var hh := minf(brick_h, r.end.y - y)
		var off := 0.0 if j % 2 == 0 else 8.0
		var x := r.position.x - off
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + 16.0, r.end.x)
			if x1 - x0 > 1.0:
				draw_rect(Rect2(_sp(x0 + 0.5, y + 0.5, sh), Vector2(x1 - x0 - 1.0, hh - 1.0) * k), base)
				draw_rect(Rect2(_sp(x0 + 0.5, y + 0.5, sh), Vector2(x1 - x0 - 1.0, 1.0) * k), base.lightened(0.25))
			x += 16.0


func _hills(scroll: float, base_h: float, amp: float, col: Color, freq: float, seed_: float, sh: Vector2) -> void:
	var pts := PackedVector2Array()
	var step := 4.0
	var n := int(MsD.VIEW_W / step) + 2
	for i in n:
		var x := i * step
		var wx := x + scroll
		var h := base_h + sin(wx * freq + seed_) * amp * 0.6 + sin(wx * freq * 2.3 + seed_ * 2.0) * amp * 0.4
		h = roundf(h)
		pts.append(view.position + Vector2(x - fposmod(scroll, step), MsD.GROUND - h + sh.y) * k)
	pts.append(view.position + Vector2(MsD.VIEW_W + step, MsD.GROUND + sh.y) * k)
	pts.append(view.position + Vector2(-step, MsD.GROUND + sh.y) * k)
	draw_colored_polygon(pts, col)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _hero_sheet() -> Variant:
	return MsAnim.sheet("ms_hero")


func _draw_hero(sh: Vector2) -> void:
	var h := world.hero
	if h.inv > 0.0 and h.st != "hurt" and int(t * 20.0) % 2 == 0:
		return   # 무적 깜빡임
	var p := _sp(h.x, h.y, sh)
	var a := String(h.st)
	var at: float = h.t
	if a in ["idle", "walk"]:
		at = world.t
	# AI 부위 그림이 있으면 컷아웃(MsRig), 없으면 pixelfx 로 구운 시트
	if MsRig.tex("hero", "torso") != null and MsRig.draw(self, "hero", a, at, p, k * RIG_S, h.face < 0):
		return
	var s: Variant = _hero_sheet()
	if s == null:
		draw_rect(Rect2(p - Vector2(6, 32) * k, Vector2(12, 32) * k), Color(0.8, 0.8, 0.9))
		return
	MsAnim.blit(self, s.tex, MsAnim.hero_region(s, a, at), s.pivot, p, h.face < 0, k)


func _draw_enemy(e: Dictionary, sh: Vector2) -> void:
	var boss: bool = e.get("boss", false)
	var p := _sp(e.x, e.y, sh)
	var col := Color(1, 1, 1)
	if e.st == "stun" and e.t < 0.08:
		col = Color(2.2, 2.2, 2.2)
	elif e.st == "cast":
		col = Color(1.0, 0.6 + 0.4 * absf(sin(t * 20.0)), 0.6 + 0.4 * absf(sin(t * 20.0)))
	if e.st == "getup" and int(t * 20.0) % 2 == 0:
		col.a = 0.4
	var rot := 0.0
	if e.st == "air":
		rot = clampf(-e.vy / 500.0, -0.6, 0.9) * -float(e.face)
	elif e.st == "down":
		rot = -1.45 * float(e.face)
	if boss or e.kind == "soldier":
		var s: Variant = MsAnim.sheet("ms_foe")   # 병사 · 보스는 칼 든 기사 시트(주인공 복제로 안 보이게)
		var tint: Color = MsD.BOSS[world.stage].tint if boss else MsD.ENEMY.soldier.tint
		var sc := MsD.BOSS_SCALE if boss else 1.0
		if s == null:
			var b := world.body(e)
			draw_rect(Rect2(_sp(b.position.x, b.position.y, sh), b.size * k), tint)
			return
		var a := "walk"
		var at: float = world.t + float(e.ph)
		match e.st:
			"cast":
				a = {"slam": "stomp", "orb": "wave"}.get(e.get("batk", ""), "atk1")
				at = 0.0
			"atk":
				a = {"slam": "stomp", "orb": "wave"}.get(e.get("batk", ""), "atk1")
				at = 0.1 + e.t
			"stun", "air", "down":
				a = "hurt"
				at = 0.0
			"getup":
				a = "idle"
		MsAnim.blit(self, s.tex, MsAnim.hero_region(s, a, at), s.pivot, p, e.face < 0, k * sc, tint * col, rot)
		return
	var sh2: Variant = MsAnim.sheet(MsD.ENEMY[e.kind].art)
	if sh2 == null:
		var b2 := world.body(e)
		draw_rect(Rect2(_sp(b2.position.x, b2.position.y, sh), b2.size * k), Color(0.5, 0.9, 0.5))
		return
	var tt: float = world.t + float(e.ph)
	if e.st in ["stun", "down", "air"]:
		tt = float(e.ph)   # 맞는 동안은 움직임을 멈춘다
	var fi := MsAnim.frame_at(sh2, tt)
	var yoff := 0.0
	if e.kind == "bat":
		yoff = -float(MsD.ENEMY.bat.h) * 0.5
	MsAnim.blit(self, sh2.tex, sh2.frames[maxi(fi, 0)], sh2.pivot, p + Vector2(0, yoff * k), e.face < 0, k, col, rot)


func _draw_shot(s: Dictionary, sh: Vector2) -> void:
	var p := _sp(s.x, s.y, sh)
	if s.foe:
		# 적이 쏜 것은 분홍 + 검은 테두리(저장소 공통 약속)
		draw_circle(p, 7.0 * k * 0.5 + 2.0, Color(0.05, 0.02, 0.06))
		draw_circle(p, 6.0 * k * 0.5, Color8(255, 90, 190))
		draw_circle(p, 2.5 * k * 0.5, Color8(255, 210, 240))
		return
	var o: Variant = MsAnim.sheet("fx_orb")
	if o == null:
		draw_circle(p, 6.0 * k, Color(0.6, 0.8, 1.0))
		return
	var i := MsAnim.frame_at(o, s.t)
	MsAnim.blit(self, o.tex, o.frames[i], o.pivot - Vector2(0, 52), p, s.vx < 0.0, k)   # 구슬 가운데가 탄 자리에 오게(시트 피벗은 구슬 아래 땅)


func _draw_tell(e: Dictionary, sh: Vector2) -> void:
	if e.st != "cast":
		return
	var b := world.body(e)
	if e.get("boss", false):
		var a: Dictionary = MsD.BOSS_ATK[e.batk]
		var u := clampf(e.t / float(a.cast), 0.0, 1.0)
		if e.batk == "slash":
			# 앞 띠 — 방향은 bdir 에 박혀 있다
			var r := world.atk_box({boss = true, batk = "slash", bdir = e.bdir, x = e.x, y = e.y})
			draw_rect(Rect2(_sp(r.position.x, r.position.y, sh), r.size * k), Color(1, 0.25, 0.3, 0.12 + 0.2 * u))
			draw_rect(Rect2(_sp(r.position.x, r.position.y, sh), r.size * k), Color(1, 0.3, 0.35, 0.8), false, 2.0)
		elif e.batk == "orb":
			var hp := _sp(e.x + e.bdir * 20.0, e.y - 40.0, sh)
			draw_circle(hp, (4.0 + 8.0 * u) * k * 0.5, Color(1, 0.4, 0.8, 0.5))
			draw_circle(hp, (2.0 + 4.0 * u) * k * 0.5, Color8(255, 210, 240))
		return
	# 잡몹 — 머리 위 느낌표
	var top := _sp(e.x, b.position.y - 6.0, sh)
	var blink := int(t * 14.0) % 2 == 0
	var c := Color(1, 0.25, 0.3) if blink else Color(1, 0.9, 0.4)
	draw_rect(Rect2(top + Vector2(-1, -6) * k, Vector2(2, 4) * k), c)
	draw_rect(Rect2(top + Vector2(-1, -1) * k, Vector2(2, 1.5) * k), c)

# ==================== HUD ====================


func _text(p: Vector2, s: String, size: int, col: Color, center := false) -> void:
	var f := P.font()
	var x := p.x
	if center:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 6), Color(0.04, 0.03, 0.07))
	draw_string(f, Vector2(x, p.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _bar(r: Rect2, v: float, col: Color, segs: int) -> void:
	draw_rect(r.grow(3), Color(0.04, 0.03, 0.07))
	draw_rect(r, Color(0.16, 0.14, 0.22))
	var w := floorf(r.size.x * clampf(v, 0.0, 1.0) / 4.0) * 4.0   # 4px 단위로 끊는다
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y * 0.3)), col.lightened(0.35))
	for i in range(1, segs):
		var x := r.position.x + r.size.x * i / segs
		draw_rect(Rect2(x - 1, r.position.y, 2, r.size.y), Color(0.04, 0.03, 0.07, 0.8))


func _draw_hud() -> void:
	var h := world.hero
	var x0 := 160.0
	var y0 := 22.0 if wide() else view.position.y - 100.0
	_text(Vector2(x0, y0 + 28), "HP", 24, Color(1, 0.6, 0.6))
	_bar(Rect2(x0 + 46, y0 + 8, 300, 22), h.hp / MsD.HERO_HP, Color8(230, 70, 80), 12)
	_text(Vector2(x0, y0 + 64), "MP", 24, Color(0.6, 0.8, 1))
	_bar(Rect2(x0 + 46, y0 + 44, 300, 18), h.mp / MsD.MP_MAX, Color8(80, 150, 255), 20)
	# 기술마다 쓸 수 있으면 밝게 — MP 막대 아래 다섯 칸
	for i in MsD.SKILL_ORDER.size():
		var id: String = MsD.SKILL_ORDER[i]
		var cost: float = MsD.MOVES[id].mp
		var on: bool = h.mp >= cost
		var r := Rect2(x0 + 46 + i * 62, y0 + 70, 56, 6)
		draw_rect(r, Color8(120, 200, 255) if on else Color(0.25, 0.25, 0.35))
	var sw := P.font().get_string_size("%d" % world.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_text(Vector2(vs.x - 40 - sw, y0 + 34), "%d" % world.score, 32, Color(1, 0.95, 0.7))
	if world.combo >= 2:
		var cs := 44 + mini(world.combo, 30)
		var a := clampf(world.combo_t / MsD.COMBO_KEEP * 2.0, 0.0, 1.0)
		_text(Vector2(vs.x - 200, view.position.y + view.size.y * 0.42), "%d" % world.combo, cs, Color(1, 0.85, 0.3, a), true)
		_text(Vector2(vs.x - 200, view.position.y + view.size.y * 0.42 + 34), "HITS", 26, Color(1, 1, 1, a), true)
	if _flash_t > 0.0:
		_text(Vector2(view.get_center().x, view.position.y + 90), _flash, 40, Color(0.7, 0.9, 1, minf(1.0, _flash_t * 2.0)), true)
	# 보스 체력
	for e in world.enemies:
		if e.get("boss", false):
			var r := Rect2(view.get_center().x - 300, view.end.y - 46, 600, 18)
			_text(Vector2(r.position.x, r.position.y - 8), String(MsD.BOSS[world.stage].name), 24, Color(1, 0.8, 0.8))
			_bar(r, e.hp / float(e.hp_max), Color8(220, 60, 90), 10)
	if world.go and not world.boss_on:
		var bl := 0.5 + 0.5 * sin(t * 8.0)
		var c := Vector2(view.end.x - 90, view.get_center().y)
		_text(c + Vector2(-50, -36), "GO", 40, Color(1, 0.95, 0.5, bl), true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -24), c + Vector2(20, 0), c + Vector2(-20, 24)]), Color(1, 0.95, 0.5, bl))
	# 다음 방으로 넘어가는 중 — 어두워졌다 밝아진다(반쯤에서 방이 바뀐다)
	if world.trans > 0.0:
		var u := world.trans / MsWorld.TRANS
		draw_rect(view, Color(0, 0, 0, 1.0 - absf(u * 2.0 - 1.0)))
	if banner_t > 0.0:
		var a2 := minf(1.0, banner_t * 2.0)
		_text(Vector2(view.get_center().x, view.position.y + view.size.y * 0.32), banner, 56, Color(1, 1, 1, a2), true)


func _draw_touch() -> void:
	var pc := pad_center()
	var pr := pad_radius()
	draw_circle(pc, pr, Color(1, 1, 1, 0.08))
	draw_arc(pc, pr, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 3.0)
	for d in [["U", Vector2(0, -1)], ["D", Vector2(0, 1)], ["L", Vector2(-1, 0)], ["R", Vector2(1, 0)]]:
		var on: bool = pad_dir[d[0]]
		var v: Vector2 = d[1]
		var c: Vector2 = pc + v * pr * 0.62
		var n := v.orthogonal()
		draw_colored_polygon(PackedVector2Array([c + v * 22, c - v * 12 + n * 22, c - v * 12 - n * 22]), Color(1, 1, 1, 0.7 if on else 0.35))
	for b in buttons():
		var held: bool = touch_btn.values().has(b.id)
		var col := Color(1, 1, 1, 0.16 if not held else 0.35)
		if MsD.MOVES.has(b.id):
			var cost: float = MsD.MOVES[b.id].mp * MsD.TOUCH_MP_K
			col = Color(0.5, 0.75, 1.0, 0.35 if world.hero.mp >= cost else 0.1)
		draw_circle(b.c, b.r, col)
		draw_arc(b.c, b.r, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
		_text(b.c + Vector2(0, float(b.r) * 0.3), String(b.label), int(float(b.r) * 0.62), Color(1, 1, 1, 0.9), true)


func _btn(r: Rect2, s: String) -> void:
	draw_rect(r, Color(0.1, 0.08, 0.16, 0.85))
	draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
	_text(Vector2(r.get_center().x, r.get_center().y + 10), s, 26, Color(1, 1, 1), true)


func _draw_title() -> void:
	var c := Vector2(vs.x * 0.5, vs.y * 0.5)
	# 주인공 대기 동작을 크게
	var s: Variant = _hero_sheet()
	if s != null:
		MsAnim.blit(self, s.tex, MsAnim.hero_region(s, "idle", t), s.pivot, c + Vector2(-vs.x * 0.25, 120), false, 6.0)
	var tx := c.x + (vs.x * 0.08 if wide() else 0.0)
	var ty := c.y - (200 if wide() else 360)
	_text(Vector2(tx, ty), "비술난무", 88, Color(1, 0.9, 0.55), true)
	_text(Vector2(tx, ty + 48), "때려서 기를 모으고, 띄워서 베어라", 28, Color(0.85, 0.85, 1), true)
	var y := ty + 110
	var lines := ["이동  좌우 방향키      점프  X", "공격  Z (세 번째는 띄우기)", "공중의 적에게  위 + Z 연타"]
	for l in lines:
		_text(Vector2(tx, y), l, 26, Color(1, 1, 1, 0.9), true)
		y += 38
	y += 14
	for id in MsD.SKILL_ORDER:
		_text(Vector2(tx, y), "%s   %s   MP %d" % [MsD.SKILL_NAME[id], MsD.SKILL_KEYS[id], int(MsD.MOVES[id].mp)], 24, Color(0.7, 0.85, 1), true)
		y += 34
	if best > 0:
		_text(Vector2(tx, y + 20), "최고 점수 %d" % best, 26, Color(1, 0.9, 0.6), true)
	var bl := 0.5 + 0.5 * sin(t * 4.0)
	_text(Vector2(tx, vs.y - 60), "Z 또는 화면을 눌러 시작", 32, Color(1, 1, 1, 0.4 + 0.6 * bl), true)


func _draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var won := world.state == "win"
	_text(c + Vector2(0, -150), "모든 스테이지 돌파" if won else "쓰러졌다", 64, Color(1, 0.9, 0.5) if won else Color(1, 0.5, 0.5), true)
	_text(c + Vector2(0, -60), "점수  %d" % world.score, 40, Color(1, 1, 1), true)
	_text(c + Vector2(0, -10), "최고 콤보  %d" % world.max_combo, 32, Color(1, 0.85, 0.4), true)
	_text(c + Vector2(0, 34), "쓰러뜨린 적  %d" % world.kills, 32, Color(1, 1, 1), true)
	_text(c + Vector2(0, 90), "최고 점수  %d" % best, 28, Color(0.8, 0.85, 1), true)
	_text(c + Vector2(0, 170), "Z 또는 화면을 눌러 처음으로", 28, Color(1, 1, 1, 0.8), true)
