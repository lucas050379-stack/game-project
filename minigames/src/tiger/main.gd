extends Node2D
## 떡 하나 주면 안 잡아먹지 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기 · 연출.
##
## 규칙은 전부 [TgGame](길 만들기 · 부딪힘 · 봇 포함)에 있고 여기는 **보여 주고 키를 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 라운드 고르기(PICK) → 달리기(PLAY) → 결과 창. 1280×720 데스크톱 전용.
## 연출은 규칙이 남긴 `g.events` 를 받아 입자 · 흔들림 · 섬광 · 컷인으로 바꿉니다(행동 → 판의 반응).
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.** 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua). 말투는 해요체.

enum Scr { TITLE, PICK, PLAY }

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: TgGame = null
var pick := 0
var parts: Array = []          ## 입자 {p(화면), v, t, life, col, r, grav}
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t}
var rings: Array = []          ## 퍼지는 고리 {p, t, dur, col}
var shake := 0.0
var cam := 0.0                 ## 화면이 위로 따라 올라간 높이(px) — 산을 오르거나 윗길에서 뛸 때
var flash := 0.0
var combo := 0                 ## 이어 먹은 떡 — 방울 음이 올라간다
var combo_t := 0.0
var goblin_k := 0.0            ## 곶감 귀신이 얼마나 가까운가(0~1, 따라감)
var modal := ""
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var mouse := Vector2(-999, -999)
var mouse_slide := false
var mouse_jump := false        ## 왼쪽 절반을 누르고 있다(하늘 보너스에서 오르기)
var show_box := false          ## 판정 상자 보기 — 테스트 빌드는 켜진 채로, H 로 켜고 끈다(`--tg-box`)
var hit_flash := 0.0           ## 맞은 뒤 판정 상자가 붉게 남는 시간
var rules := UiRules.new()     ## 규칙서 — 처음 화면의 [규칙] 단추
var keys := UiKeys.new()       ## 키 설정 창 — 처음 화면의 [키 설정] 메뉴
const KEYS := [["jump", "점프", KEY_SPACE], ["slide", "숙이기", KEY_S], ["power", "호랑이 기운", KEY_ENTER]]   ## 키 설정 창의 줄(하는 일 · 이름 · 기본 키)
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var tg_auto := false
var tg_seed := -1
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


func _ready() -> void:
	Bgm.use("tiger")
	TgSnd.init(Hub.host(self))
	TgSv.load_()
	pick = mini(TgSv.cleared(), TgD.ROUNDS.size() - 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--tg-auto":
			tg_auto = true
		elif a == "--tg-open":
			TgSv.all_open = true
		elif a == "--tg-box":
			show_box = true
		elif a == "--tg-click-test":
			click_test = true
		elif a.begins_with("--tg-seed="):
			tg_seed = int(a.substr(10))
		elif a.begins_with("--tg-rules"):   # 확인용 — 규칙서 N쪽을 바로 연다
			var pg := int(a.substr(11)) - 1 if a.length() > 11 else 0
			(func(): _open_rules(); rules.page = clampi(pg, 0, rules.pages.size() - 1)).call_deferred()
		elif a.begins_with("--tg-round="):
			pick = clampi(int(a.substr(11)) - 1, 0, TgD.ROUNDS.size() - 1)
	no_save = not OS.get_cmdline_user_args().is_empty()
	if OS.has_feature("testbuild"):
		show_box = true
	if tg_auto:
		_start.call_deferred()


func _start() -> void:
	g = TgGame.new(pick, tg_seed, TgSv.up)
	scr = Scr.PLAY
	parts = []
	pops = []
	rings = []
	shake = 0.0
	flash = 0.0
	combo = 0
	goblin_k = 0.0
	cam = 0.0
	if g.boss():
		pops.append({p = Vector2(vs.x * 0.5, 230), txt = "곶감 귀신이 쫓아와요!  부딪히면 따라잡혀요", col = Color8(255, 190, 120), t = -0.8})
	modal = ""
	end_open = false
	end_t = 0.0
	saved = false
	mouse_slide = false
	TgSnd.play("tick")


func _paused() -> bool:
	return modal != "" or Vol.open or end_open or rules.open


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	shake = maxf(0.0, shake - dt)
	if g != null:   # 작은 언덕(80)까지는 호랑이가 오르내리고, 그 위로는 화면이 따라간다. 윗길에서 뛰어도 안 잘리게 높이도 본다
		cam = lerpf(cam, maxf(0.0, g.ground_h(g.dist) - 80.0) + maxf(0.0, g.fox_y - 230.0), minf(1.0, dt * 5.0))
	hit_flash = maxf(0.0, hit_flash - dt)
	flash = maxf(0.0, flash - dt * 3.0)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	for p: Dictionary in parts:
		p.t += dt
		p.v = p.v * (1.0 - dt * 2.0) + Vector2(0, float(p.grav)) * dt
		p.p += p.v * dt
	parts = parts.filter(func(p): return p.t < p.life)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 0.9)
	for r: Dictionary in rings:
		r.t += dt
	rings = rings.filter(func(r): return r.t < r.dur)
	var hot := false
	if scr == Scr.PLAY and g != null:
		hot = not g.over and g.oil < 25.0
		if g.over:
			end_t += dt
			if not end_open and end_t > (1.4 if g.win else 1.6):
				_open_end()
		elif not _paused():
			if tg_auto:
				g.bot()
			else:
				g.slide(mouse_slide or _held("slide"))
			if not tg_auto:
				g.fly_held = mouse_jump or _held("jump")
			g.step(dt)
			_take_events()
			if g.magnet_t > 0.0 and randf() < 0.5:   # 꿀단지 — 금빛 가루가 호랑이 쪽으로
				var a2 := randf() * TAU
				parts.append({p = _fox_feet() + Vector2(0, -40) + Vector2.from_angle(a2) * 200.0, v = -Vector2.from_angle(a2) * 320.0, t = 0.0, life = 0.5,
						col = TgArt.EMBER, r = 3.0, grav = 0.0})
			if g.dashing() and randf() < 0.8:   # 질주 꼬리 불똥
				_spark(_fox_feet() + Vector2(-30, -40), TgArt.FLAME, 1, 160.0, 200.0)
			var want := 0.0
			if g.boss():
				want = g.chase
			goblin_k = lerpf(goblin_k, want, minf(1.0, dt * 2.0))
	Bgm.mood(hot)
	if click_test:
		_click_test_step(dt)
	if shot_path != "" and _shot_i < shot_at.size() and t >= float(shot_at[_shot_i]):
		var path := shot_path
		if shot_at.size() > 1:
			path = shot_path.get_basename() + "_%d.png" % _shot_i
		get_viewport().get_texture().get_image().save_png(path)
		_shot_i += 1
		if _shot_i >= shot_at.size() and not click_test:
			get_tree().quit()
	queue_redraw()


## 세상 좌표(x 거리, y 위로) → 화면.
func _scr(x: float, y: float) -> Vector2:
	return Vector2(TgD.FOX_X + (x - g.dist), _gy(x) - y)


## 그 자리 땅의 화면 y(언덕).
func _gy(x: float) -> float:
	return TgD.GROUND_Y + cam - g.ground_h(x)


func _fox_feet() -> Vector2:
	return Vector2(TgD.FOX_X, _gy(g.dist) - g.fox_y)


func _spark(at: Vector2, col: Color, n: int, speed: float, grav: float = 500.0) -> void:
	for k in n:
		var a := randf() * TAU
		parts.append({p = at, v = Vector2(cos(a), sin(a)) * speed * randf_range(0.3, 1.0), t = 0.0, life = randf_range(0.3, 0.7),
				col = col.lerp(Color(1, 1, 1), randf() * 0.4), r = randf_range(2.0, 4.5), grav = grav})


## 규칙이 남긴 일 → 입자 · 소리 · 흔들림. 행동 하나에 반응 하나씩.
func _take_events() -> void:
	for e: Dictionary in g.events:
		match String(e.kind):
			"jump":
				TgSnd.play("jump", 1.25 if e.second else 1.0)
				_spark(_fox_feet(), TgArt.PAPER, 5 if not e.second else 9, 120.0)
				if e.second:
					rings.append({p = _fox_feet() + Vector2(0, -30), t = 0.0, dur = 0.3, col = TgArt.EMBER})
			"land":
				TgSnd.play("land")
				for k in 6:   # 착지 먼지 — 양옆으로 낮게
					parts.append({p = _fox_feet(), v = Vector2((k - 2.5) * 50.0, -30.0 - randf() * 40.0), t = 0.0, life = 0.35,
							col = Color(1, 1, 1, 0.6), r = 4.0, grav = 100.0})
			"slide":
				TgSnd.play("slide")
			"ember":
				combo += 1
				combo_t = 0.6
				TgSnd.play("ember", 1.0 + minf(combo, 12) * 0.05)
				_spark(_scr(e.x, e.y), TgArt.EMBER, 5, 150.0, 0.0)
				if e.full:
					pops.append({p = _gauge_btn().get_center() + Vector2(0, -50), txt = "호랑이 기운 준비", col = TgArt.EMBER, t = 0.0})
					rings.append({p = _gauge_btn().get_center(), t = 0.0, dur = 0.5, col = TgArt.EMBER})
			"kkochi":
				TgSnd.play("lantern")
				_spark(_scr(e.x, e.y), Color8(255, 230, 150), 18, 260.0, 200.0)
				rings.append({p = _scr(e.x, e.y), t = 0.0, dur = 0.4, col = TgArt.EMBER})
				pops.append({p = _scr(e.x, e.y), txt = "+%d" % TgD.SCORE_LANTERN, col = Color8(255, 240, 170), t = 0.0})
			"bite":
				shake = 0.5
				flash = 0.8
				pops.append({p = Vector2(vs.x * 0.5, 260), txt = "곶감 귀신에게 물렸어요!  체력 -%d" % int(TgD.OIL_BITE), col = Color8(255, 150, 90), t = -0.6})
			"hit", "pit":
				if g.boss() and e.kind == "hit":
					pops.append({p = Vector2(190, _gy(g.dist) - 190), txt = "귀신이 다가와요!", col = Color8(255, 190, 120), t = 0.0})
				hit_flash = 0.6
				TgSnd.play("hit")
				shake = 0.3
				flash = 0.5
				combo = 0
				_spark(_fox_feet() + Vector2(10, -40), Color8(255, 90, 70), 14, 280.0)
				pops.append({p = _fox_feet() + Vector2(0, -110), txt = "체력 -%d" % int(TgD.OIL_HIT if e.kind == "hit" else TgD.OIL_PIT),
						col = Color8(255, 120, 100), t = 0.0})
			"smash":
				TgSnd.play("hit", 1.4)
				shake = maxf(shake, 0.12)
				_spark(_scr(e.x, e.y), TgArt.FLAME, 16, 380.0)
			"awaken":
				TgSnd.play("awaken")
			"coin":
				TgSnd.play("tick", 1.5)
				_spark(_scr(e.x, e.y), TgArt.EMBER, 4, 130.0, 0.0)
			"item":
				TgSnd.play("lantern", 0.8)
				flash = 0.35
				rings.append({p = _scr(e.x, e.y), t = 0.0, dur = 0.5, col = TgArt.EMBER})
				pops.append({p = _fox_feet() + Vector2(0, -130), txt = {honey = "꿀단지! 떡이 끌려와요", sansam = "산삼! 몸이 커져요", rope = "동아줄! 하늘로", box = "보따리! 엽전 8닢"}.get(e.item, ""), col = TgArt.EMBER, t = 0.0})
				if e.item == "rope":
					TgSnd.play("awaken", 1.4)
			"club":   # 도깨비 방망이 — 장애물이 펑 하고 떡으로, 떡이 전부 날아온다
				TgSnd.play("boom", 1.3)
				flash = 0.6
				shake = 0.2
				pops.append({p = _fox_feet() + Vector2(0, -130), txt = "도깨비 방망이! 떡 %d개" % e.got.size(), col = TgArt.EMBER, t = 0.0})
				for q: Vector2 in e.got:
					var sp := _scr(q.x, q.y)
					parts.append({p = sp, v = (_fox_feet() + Vector2(0, -40) - sp) * 2.2, t = 0.0, life = 0.45, col = Color(1, 1, 1), r = 7.0, grav = 0.0})
					_spark(sp, TgArt.EMBER, 3, 120.0, 0.0)
			"fly_end":
				TgSnd.play("land")
			"dash":
				flash = 1.0
				shake = 0.25
				rings.append({p = _fox_feet() + Vector2(0, -40), t = 0.0, dur = 0.6, col = TgArt.FLAME})
			"dash_end":
				TgSnd.play("boom")
				shake = 0.35
				for k in 2:
					rings.append({p = _fox_feet() + Vector2(0, -40), t = -k * 0.12, dur = 0.7, col = TgArt.EMBER if k == 0 else Color(1, 1, 1)})
				_spark(_fox_feet() + Vector2(0, -40), TgArt.FLAME, 30, 420.0)
			"finish":
				TgSnd.play("win")
				for k in 60:   # 결승 종이 꽃가루
					parts.append({p = Vector2(randf() * vs.x, -20.0 - randf() * 120.0), v = Vector2(randf_range(-60, 60), randf_range(80, 220)), t = 0.0,
							life = 2.4, col = [Color8(230, 70, 60), Color8(250, 200, 80), Color8(120, 180, 230), Color(1, 1, 1)][k % 4], r = 4.0, grav = 60.0})
			"fail":
				TgSnd.play("lose")
				_spark(_fox_feet() + Vector2(44, -50), Color8(180, 180, 190), 12, 90.0, -60.0)   # 힘 빠진 한숨
	g.events.clear()


func _open_end() -> void:
	end_open = true
	end_t = 0.0
	if not saved and not no_save:
		TgSv.add(g)
		TgSv.save_()
	saved = true

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


func _round_rect(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 606 + (k % 8) * 152, 96 + int(k / 8) * 190, 144, 180)   # 열여섯 = 여덟씩 두 줄(테마 둘이 한 줄)


## 가게 칸 — 라운드 고르기 화면 왼쪽 아래 네 칸.
func _shop_rect(i: int) -> Rect2:
	return Rect2(18 + i * 212, 600, 204, 100)


func _cost(i: int) -> int:
	return int(TgD.UPGRADES[i][2]) * (int(TgSv.up[i]) + 1)


func _buy(i: int) -> void:
	if int(TgSv.up[i]) >= int(TgD.UPGRADES[i][3]) or TgSv.coins < _cost(i):
		TgSnd.play("tick", 0.6)
		return
	TgSv.coins -= _cost(i)
	TgSv.up[i] = int(TgSv.up[i]) + 1
	if not no_save:
		TgSv.save_()
	TgSnd.play("lantern")


func _gauge_btn() -> Rect2:
	return Rect2(vs.x - 250, vs.y - 96, 232, 76)


func _oil_rect() -> Rect2:
	return Rect2(vs.x * 0.5 - 250, 22, 500, 26)


func _modal_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 250 + k * 260, vs.y * 0.5 + 30, 240, 64)


func _end_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 330 + k * 225, vs.y * 0.5 + 150, 210, 60)

# ==================== 입력 ====================

## 덤으로 듣는 키(방향키 · W · E …) — **키 설정에서 다른 일에 준 키는 덤에서 빠진다**(E 를 숙이기로 바꿨는데 호랑이 기운이 나갔다).
const ALT := {jump = [KEY_UP, KEY_W], slide = [KEY_DOWN, KEY_SHIFT], power = [KEY_KP_ENTER, KEY_E]}


func _key_of(action: String) -> int:
	for row: Array in KEYS:
		if String(row[0]) == action:
			return UiKeys.code("tiger", action, int(row[2]))
	return 0


func _alts(action: String) -> Array:
	var used := []
	for row: Array in KEYS:
		used.append(_key_of(String(row[0])))
	return (ALT[action] as Array).filter(func(k): return not used.has(k))


func _is(kc: int, action: String) -> bool:
	return kc == _key_of(action) or _alts(action).has(kc)


func _held(action: String) -> bool:
	if Input.is_physical_key_pressed(_key_of(action)) or Input.is_key_pressed(_key_of(action)):
		return true
	for k: int in _alts(action):
		if Input.is_physical_key_pressed(k):
			return true
	return false



func _unhandled_input(ev: InputEvent) -> void:
	if Vol.open:
		Vol.handle(ev, vs)
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if keys.key(key.keycode):
			return
		if rules.key(key.keycode):
			return
		var kc := key.keycode
		var in_play := scr == Scr.PLAY and g != null and not _paused()
		if kc == KEY_ESCAPE:
			_escape()
		elif _is(kc, "jump"):
			if in_play:
				if g.busy():
					g.skip_cine()
				else:
					g.jump()
			elif scr == Scr.TITLE and kc == KEY_SPACE:
				scr = Scr.PICK
		elif _is(kc, "power"):
			if in_play:
				if g.busy():
					g.skip_cine()
				else:
					g.awaken()
			elif scr == Scr.TITLE:
				scr = Scr.PICK
			elif scr == Scr.PICK and TgSv.unlocked(pick):
				_start()
		elif kc == KEY_H:
			show_box = not show_box
		elif kc == KEY_LEFT or kc == KEY_RIGHT:
			if scr == Scr.PICK:
				pick = clampi(pick + (1 if kc == KEY_RIGHT else -1), 0, TgD.ROUNDS.size() - 1)
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		mouse = mb.position
		if not mb.pressed:
			mouse_slide = false
			mouse_jump = false
			return
		_click(mb.position)


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.PICK:
			scr = Scr.TITLE
		Scr.PLAY:
			if end_open:
				scr = Scr.PICK
			else:
				modal = "" if modal != "" else "quit"


func _click(p: Vector2) -> void:
	if keys.click(p, vs):
		return
	if rules.click(p, vs):
		return
	if _vol_btn().has_point(p):
		Vol.open = true
		return
	match scr:
		Scr.TITLE:
			if _back_btn().has_point(p):
				Hub.leave(self)
			elif Hub.std_rect("start", vs).has_point(p):
				scr = Scr.PICK
				TgSnd.play("tick")
			elif _rules_rect().has_point(p):
				_open_rules()
			elif UiKit.menu_rect(vs, 0).has_point(p):
				keys.show("tiger", KEYS)
		Scr.PICK:
			if _back_btn().has_point(p):
				scr = Scr.TITLE
			elif Hub.std_rect("start", vs).has_point(p):
				if TgSv.unlocked(pick):
					_start()
			else:
				for i in TgD.UPGRADES.size():   # 가게 — 엽전으로 강화
					if _shop_rect(i).has_point(p):
						_buy(i)
						return
				for k in TgD.ROUNDS.size():
					if _round_rect(k).has_point(p):
						if pick == k and TgSv.unlocked(k):
							_start()
						pick = k
						TgSnd.play("tick")
		Scr.PLAY:
			_click_play(p)


func _click_play(p: Vector2) -> void:
	if end_open:
		if _end_btn(0).has_point(p):
			_start()
		elif _end_btn(1).has_point(p) and g.win and pick + 1 < TgD.ROUNDS.size():
			pick += 1
			_start()
		elif _end_btn(2).has_point(p):
			scr = Scr.PICK
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.PICK
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if Hub.std_rect("rules", vs).has_point(p):   # 판에서도 규칙을 본다(그동안 멈춘다)
		_open_rules()
		return
	if g.over:
		return
	if g.busy():
		g.skip_cine()
	elif _gauge_btn().has_point(p):
		g.awaken()
	elif p.x < vs.x * 0.5:
		mouse_jump = true
		g.jump()
	else:
		mouse_slide = true

# ==================== 그리기 ====================


func _btn(r: Rect2, label: String, fill: Color, size: float = 24.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "tiger", t, on, size)


func _draw() -> void:
	Hub.compact = scr == Scr.PLAY   # 판 화면은 아이콘 단추
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.PICK:
			_draw_pick()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _draw_title() -> void:
	var bg := TgArt.img("tg_bg_title")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
	else:
		TgArt.bg(self, vs.x, vs.y, 0, t * 60.0, t)
	var below := UiKit.title(self, vs, "tiger", "떡 하나 주면 안 잡아먹지", "해와 달이 된 오누이의 그 호랑이가 고갯길을 달려요", t)
	if bg == null:   # 표지 그림에 호랑이가 이미 있다
		TgArt.fox(self, Vector2(vs.x * 0.3, below + 190), t * 1.6, "run", false, false, t)
	if TgSv.cleared() > 0:   # 하나도 안 깼으면 "0 / 10" 을 보이지 않는다
		UiKit.record_line(self, vs, "라운드 %d / %d 완주" % [TgSv.cleared(), TgD.ROUNDS.size()])
	UiKit.key_hint(self, vs, "%s 점프, %s 숙이기, %s 호랑이 기운" % [OS.get_keycode_string(UiKeys.code("tiger", "jump", KEY_SPACE)),
			OS.get_keycode_string(UiKeys.code("tiger", "slide", KEY_S)), OS.get_keycode_string(UiKeys.code("tiger", "power", KEY_ENTER))])
	UiKit.button(self, vs, "start", "tiger", t)
	UiKit.button(self, vs, "hub", "tiger", t)
	UiKit.button(self, vs, "vol", "tiger", t)
	UiKit.menu(self, UiKit.menu_rect(vs, 0), "키 설정", Color8(60, 90, 140), "tiger", t)
	UiKit.plain(self, _rules_rect(), "규칙", UiKit.theme("tiger").hub, "tiger", t, true, 24)
	rules.draw(self, vs, t)
	keys.draw(self, vs, t)


func _draw_pick() -> void:
	TgArt.bg(self, vs.x, vs.y, int(TgD.ROUNDS[pick][1]), t * 40.0, t)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5))
	G2.text_mid(self, Vector2(vs.x * 0.5, 50), "%d. %s" % [pick + 1, String(TgD.ROUNDS[pick][0])], 30, TgArt.HEAD, 6)
	for k in TgD.ROUNDS.size():
		var r := _round_rect(k)
		var row: Array = TgD.ROUNDS[k]
		var open := TgSv.unlocked(k)
		var on := k == pick
		var tint: Color = (TgArt.GROUND[int(row[1])] as Color).darkened(0.45)
		TgArt.rr(self, r, 12, tint if open else Color8(40, 36, 40), TgArt.EMBER if on else Color(1, 1, 1, 0.18), 4.0 if on else 1.5)
		G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 36), str(k + 1), 40, TgArt.HEAD if open else Color(1, 1, 1, 0.3), 4)
		G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 80), String(row[0]) if open else "잠김", 20, Color(1, 1, 1, 0.9 if open else 0.35), 0)
		if open:
			for s in 3:
				_star(r.position + Vector2(r.size.x * 0.5 + (s - 1) * 36, 118), 13, s < int(TgSv.stars[k]))
			if int(TgSv.best[k]) > 0:
				G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 156), "%d점" % int(TgSv.best[k]), 20, Color(1, 1, 1, 0.7), 0)
	# 가게 — 엽전으로 호랑이를 강화한다(달리며 주운 엽전)
	TgArt.coin(self, Vector2(40, 572), t)
	G2.text_mid(self, Vector2(110, 572), "엽전 %d" % TgSv.coins, 24, TgArt.EMBER, 5)
	for i in TgD.UPGRADES.size():
		var sr := _shop_rect(i)
		var u: Array = TgD.UPGRADES[i]
		var lv := int(TgSv.up[i])
		var full := lv >= int(u[3])
		var can := not full and TgSv.coins >= _cost(i)
		TgArt.rr(self, sr, 12, Color8(60, 50, 44) if can else Color8(40, 36, 40), TgArt.EMBER if can else Color(1, 1, 1, 0.2), 3.0 if can else 1.5)
		G2.text_mid(self, sr.position + Vector2(sr.size.x * 0.5, 22), "%s %d" % [String(u[0]), lv], 22, TgArt.HEAD, 0)
		G2.text_mid(self, sr.position + Vector2(sr.size.x * 0.5, 50), String(u[1]), 20, Color(1, 1, 1, 0.7), 0)
		G2.text_mid(self, sr.position + Vector2(sr.size.x * 0.5, 80), "끝까지 올림" if full else "엽전 %d" % _cost(i), 20, TgArt.EMBER if can else Color(1, 1, 1, 0.45), 0)
	UiKit.button(self, vs, "start", "tiger", t, "달리기")
	UiKit.button(self, vs, "hub", "tiger", t, "뒤로")
	UiKit.button(self, vs, "vol", "tiger", t)


func _star(c: Vector2, r: float, on: bool, k: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r * k if i % 2 == 0 else r * k * 0.45))
	G2.fill_fan(self, pts, TgArt.EMBER if on else Color(1, 1, 1, 0.14), c)
	if on:
		G2.stroke(self, pts, TgArt.INK, 2.0)


func _draw_play() -> void:
	var theme := int(g.row()[1])
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 22.0
	draw_set_transform(off)
	TgArt.bg(self, vs.x, vs.y, theme, g.dist, t, cam)
	# 결승선 — 두 기둥 사이 종이 끈
	var fx := _scr(g.length, 0).x
	if fx < vs.x + 100:
		draw_rect(Rect2(fx - 6, TgD.GROUND_Y - 220, 12, 220), Color8(170, 50, 40))
		if not g.win:
			draw_line(Vector2(fx, TgD.GROUND_Y - 120), Vector2(fx + 60, TgD.GROUND_Y - 110), TgArt.PAPER, 5.0)
	# 땅 — 풀 + 흙 띠(tg_ground_N)를 16px 조각으로 잘라 **땅의 높이를 따라 기울여** 잇는다(평지 · 언덕 · 산이 한 그림으로 이어진다). 띠 밑은 흙 색으로 화면 끝까지.
	# 예전엔 배경 띠의 맨 아래를 조각마다 들어 올렸는데, 계단처럼 끊기고 배경의 물건이 같이 밀려 보였다(사용자 지적 11-10).
	var gtex := TgArt.img("tg_ground_%d" % theme)
	var soil: Color = TgD.SOIL[theme] if gtex != null else TgArt.GROUND[theme]
	const TW := 640.0    # 띠 한 장의 화면 폭 — 조각(16)의 배수라 조각이 이음매에 안 걸친다
	const SURF := 25.0   # 띠 그림에서 풀 윗선까지(화면 px)
	var th := (TW * gtex.get_size().y / gtex.get_size().x) if gtex != null else 8.0
	var wx0 := floorf((g.dist - TgD.FOX_X - 16.0) / 16.0) * 16.0
	var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	for i in int(vs.x / 16.0) + 3:
		var wx := wx0 + i * 16.0
		var xa := TgD.FOX_X + wx - g.dist
		var ya := _gy(wx) - SURF
		var yb := _gy(wx + 16.0) - SURF
		if gtex != null:
			var u0 := fposmod(wx, TW) / TW
			var u1 := u0 + 16.0 / TW
			draw_primitive(PackedVector2Array([Vector2(xa, ya), Vector2(xa + 16.5, yb), Vector2(xa + 16.5, yb + th), Vector2(xa, ya + th)]), white,
					PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), gtex)
		draw_primitive(PackedVector2Array([Vector2(xa, ya + th - 1.0), Vector2(xa + 16.5, yb + th - 1.0), Vector2(xa + 16.5, vs.y + 60.0), Vector2(xa, vs.y + 60.0)]),
				PackedColorArray([soil, soil, soil, soil]), PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
	# 장애물 · 떡
	var plank := TgArt.img("tg_plank")
	for it: Dictionary in g.items:
		if it.gone:
			continue
		if it.kind == "plank":   # 윗길 — 16px 조각으로 잘라 언덕을 따라 놓는다(양 끝은 그림의 끝, 가운데는 되풀이)
			var x0 := float(it.x) - float(it.w) * 0.5
			var ph := 46.0
			var tw := ph * 5.0
			for i in int(ceil(float(it.w) / 16.0)):
				var dd := i * 16.0
				var pp := _scr(x0 + dd, it.y)
				if pp.x < -20.0 or pp.x > vs.x + 20.0:
					continue
				if plank == null:
					draw_rect(Rect2(pp.x, pp.y, 16.5, 20.0), Color8(150, 100, 60))
					continue
				var u := 0.25 + fmod(dd - tw * 0.25, tw * 0.5) / tw
				if dd < tw * 0.25:
					u = dd / tw
				elif dd > float(it.w) - tw * 0.25:
					u = 1.0 - (float(it.w) - dd) / tw
				var ts := plank.get_size()
				draw_texture_rect_region(plank, Rect2(pp.x, pp.y - ph * 0.2, 16.5, ph), Rect2(u * ts.x, 0, 16.0 / tw * ts.x, ts.y))
			continue
		var sx := _scr(it.x, 0).x
		if sx < -120 or sx > vs.x + 120:
			continue
		match String(it.kind):
			"ember":
				TgArt.candy(self, _scr(it.x, it.y), t)
			"kkochi":
				TgArt.lollipop(self, _scr(it.x, it.y), t)
			"coin":
				TgArt.coin(self, _scr(it.x, it.y), t)
			"honey", "sansam", "club", "rope", "box":
				TgArt.item(self, String(it.kind), _scr(it.x, it.y), t)
			_:
				if bool(it.get("late", false)):
					# 불쑥 — 가까이 가야 나타난다: 낮은 것은 땅에서 솟고, 숙이는 것은 위에서 떨어진다(반응할 틈은 0.45초쯤)
					var low: bool = it.kind == "low"
					var k := clampf((g.speed * (0.84 if low else 0.6) - (float(it.x) - g.dist)) / 70.0, 0.0, 1.0)
					if k <= 0.0:
						continue
					if low:
						draw_set_transform(Vector2(sx, _gy(it.x)), 0.0, Vector2(1.0, G2.out_back(k)))
					else:
						draw_set_transform(Vector2(sx, _gy(it.x) - (1.0 - k * k) * 420.0), 0.0, Vector2.ONE)
					TgArt.obstacle(self, it, 0.0, 0.0, theme, t)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					continue
				TgArt.obstacle(self, it, sx, _gy(it.x), theme, t)
	if g.boss() or goblin_k > 0.01:
		TgArt.goblin(self, Vector2(-70 + goblin_k * 250, _gy(g.dist - 370.0 + goblin_k * 250.0)), goblin_k, t)
	var feet := _fox_feet()
	var ok := g.oil / TgD.OIL_MAX
	var state := "slide" if g.sliding else ("jump" if not g.on_ground() else "run")
	var blink := g.inv_t > 0.0 and not g.dashing() and fmod(t, 0.16) < 0.08
	if g.flying():   # 하늘 보너스 — 동아줄을 타고 난다. 흰 띠가 지금 떡 물결 높이를 가리킨다
		draw_line(feet + Vector2(0, -80), Vector2(feet.x + 40, -20), Color8(230, 190, 110), 6.0)
		state = "jump"
	# 땅에 있을 때는 비탈을 따라 몸이 기운다. 산삼을 먹었으면 발을 기준으로 크게
	var tilt := -atan((g.ground_h(g.dist + 24.0) - g.ground_h(g.dist - 24.0)) / 48.0) if g.on_ground() else 0.0
	var gk := TgD.GIANT_K if g.giant() else 1.0
	draw_set_transform(feet + off, tilt, Vector2(gk, gk))
	TgArt.fox(self, Vector2.ZERO, g.run_phase, state, g.dashing(), blink and (not g.giant() or g.giant_t < 0.8), t)
	draw_set_transform(off)
	if g.dashing():   # 속도선 — 화면을 가로지르는 흰 줄, 호랑이 뒤로 흐른다
		for j in 12:
			var ly := fposmod(j * 67.0, TgD.GROUND_Y - 80.0) + 60.0
			var lx := vs.x - fposmod(t * (1500.0 + j * 90.0) + j * 311.0, vs.x + 300.0)
			draw_line(Vector2(lx, ly), Vector2(lx + 120.0 + j * 10.0, ly), Color(1, 1, 1, 0.35), 3.0)
	if show_box:
		_draw_boxes()
	# 입자 · 고리 · 떠오르는 글
	for p: Dictionary in parts:
		var a := 1.0 - float(p.t) / float(p.life)
		draw_circle(p.p, float(p.r) * (0.5 + 0.5 * a), Color(p.col, a * (p.col as Color).a))
	for r: Dictionary in rings:
		if r.t < 0.0:
			continue
		var k := float(r.t) / float(r.dur)
		draw_arc(r.p, 20.0 + k * 260.0, 0, TAU, 48, Color(r.col, 1.0 - k), 10.0 * (1.0 - k) + 1.0)
	for p: Dictionary in pops:
		var k2 := float(p.t) / 0.9
		G2.text_mid(self, p.p + Vector2(0, -40.0 * k2), String(p.txt), 26, Color(p.col, 1.0 - k2 * k2), 5)
	draw_set_transform(Vector2.ZERO)
	# 체력이 적으면 가장자리가 어두워진다
	if ok < 0.3 and not g.over:
		var dk := (0.3 - ok) / 0.3
		for j in 6:
			var w := 40.0 * (j + 1)
			var a2 := 0.09 * dk
			draw_rect(Rect2(0, 0, w, vs.y), Color(0, 0, 0, a2))
			draw_rect(Rect2(vs.x - w, 0, w, vs.y), Color(0, 0, 0, a2))
	if g.over and not g.win:   # 배가 고파 멈췄다
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, minf(0.75, end_t * 0.8)))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.92, 0.7, flash * 0.6))
	if g.busy():
		_draw_cine()
	_draw_hud()
	if modal == "quit":
		_draw_modal("달리기를 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()
	rules.draw(self, vs, t)


## 판정 상자 — 호랑이 몸(초록, 맞으면 잠깐 빨강) · 장애물(빨강) · 구덩이(보라) · 떡과 물건(노랑 원). 보이는 그림과 닿는 자리를 맞춰 볼 때 쓴다(H).
func _draw_boxes() -> void:
	var fr := g.fox_rect()
	var fs := Rect2(_scr(fr.position.x, fr.end.y), fr.size)
	draw_rect(fs, Color(1, 0.2, 0.2, 0.35) if hit_flash > 0.0 else Color(0.2, 1, 0.3, 0.2))
	draw_rect(fs, Color(1, 0.2, 0.2) if hit_flash > 0.0 else Color(0.2, 1, 0.3), false, 2.0)
	for it: Dictionary in g.items:
		if it.gone or absf(float(it.x) - g.dist) > 1100.0:
			continue
		match String(it.kind):
			"low", "high", "tall":
				draw_rect(Rect2(_scr(float(it.x) - float(it.w) * 0.5, float(it.y) + float(it.h)), Vector2(it.w, it.h)), Color(1, 0.2, 0.2), false, 2.0)
			"pit":
				var hw := float(it.w) * 0.5 - 12.0
				draw_rect(Rect2(_scr(float(it.x) - hw, 0.0), Vector2(hw * 2.0, 14)), Color(0.8, 0.3, 1), false, 2.0)
			"ember", "coin":
				draw_arc(_scr(it.x, it.y), 18.0, 0, TAU, 16, Color(1, 0.9, 0.2), 1.5)
			_:
				draw_arc(_scr(it.x, it.y), 30.0 if it.kind != "kkochi" else 28.0, 0, TAU, 20, Color(1, 0.9, 0.2), 2.0)
	G2.text_mid(self, Vector2(vs.x * 0.5, vs.y - 24), "판정 상자 보기 (H 로 끄기)", 20, Color(1, 1, 1, 0.8), 4)


## 호랑이 기운 컷인 — 한 타임라인(0~1.2초)에 어두워짐 · 위아래 띠 · 큰 호랑이 · 붉은 기운 아홉 갈래 · 글자 · 끝에 섬광. 누르면 넘어간다.
func _draw_cine() -> void:
	var k := 1.0 - g.cine_t / TgD.CINE_T
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.01, 0.02, 0.8 * minf(k / 0.15, 1.0)))
	var bar := 70.0 * G2.out_cubic(k / 0.2)
	draw_rect(Rect2(0, 0, vs.x, bar), Color.BLACK)
	draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color.BLACK)
	var c := Vector2(vs.x * 0.5, vs.y * 0.52)
	# 뒤의 방사 섬광(그림 tg_fx_burst) — 천천히 돌며 커진다. 없으면 붉은 줄 아홉
	# 컷인 그림(tg_cine, GPT) — 화면을 꽉 채운 한 장이 왼쪽에서 밀려 들어오며 크게 잡혔다가 물러난다. 처음 절반은 떨린다. 없으면 예전 조합(섬광 + 호랑이)
	var pic := TgArt.img("tg_cine")
	if pic != null:
		var ps := pic.get_size()
		var sc := maxf(vs.x / ps.x, vs.y / ps.y) * lerpf(1.35, 1.06, G2.out_cubic(minf(k / 0.4, 1.0)))
		var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 12.0 * maxf(0.0, 1.0 - k / 0.5)
		var at := (vs - ps * sc) * 0.5 + Vector2((1.0 - G2.out_cubic(minf(k / 0.22, 1.0))) * -vs.x * 0.6, 0) + jit
		draw_texture_rect(pic, Rect2(at, ps * sc), false, Color(1, 1, 1, minf(k / 0.1, 1.0)))
		for j in 10:   # 가로로 스치는 흰 줄
			var lx := vs.x - fposmod(t * (2600.0 + j * 170.0) + j * 377.0, vs.x + 500.0)
			draw_line(Vector2(lx, 90.0 + j * 56.0), Vector2(lx + 260.0, 90.0 + j * 56.0), Color(1, 1, 1, 0.35), 3.0)
		draw_rect(Rect2(0, 0, vs.x, bar), Color.BLACK)
		draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color.BLACK)
	var burst := TgArt.img("tg_fx_burst")
	if pic != null:
		pass
	elif burst != null:
		var bk := G2.out_back(clampf((k - 0.1) / 0.3, 0.0, 1.0))
		for j in 2:
			draw_set_transform(c, t * (0.5 if j == 0 else -0.3), Vector2.ONE * bk * (1.9 if j == 0 else 1.3))
			draw_texture_rect(burst, Rect2(-256, -256, 512, 512), false, Color(1, 1, 1, 0.9 if j == 0 else 0.6))
		draw_set_transform(Vector2.ZERO)
	else:
		for j in 9:
			var open := clampf((k - 0.15 - j * 0.04) / 0.2, 0.0, 1.0)
			if open <= 0.0:
				continue
			var a := -PI * 0.5 + (j - 4) * 0.3
			draw_line(c, c + Vector2.from_angle(a) * 330.0 * G2.out_back(open), Color(TgArt.FLAME, 0.85), 26.0)
	# 포효 물결 — 호랑이 입에서 퍼지는 고리 셋
	for j in 3:
		var rk := fposmod(k * 2.2 - j * 0.33, 1.0)
		if k > 0.3:
			draw_arc(c + Vector2(40, -20), 120.0 + rk * 520.0, -0.9, 0.9, 40, Color(1, 0.95, 0.8, (1.0 - rk) * 0.8), 14.0 * (1.0 - rk) + 2.0)
	# 큰 호랑이 — 왼쪽에서 밀려 들어온다
	var slide_in := G2.out_cubic(k / 0.3)
	if pic == null:
		draw_set_transform(Vector2(lerpf(-200.0, vs.x * 0.5 - 20.0, slide_in), vs.y * 0.52 + 150.0), 0.0, Vector2(2.3, 2.3))
		TgArt.fox(self, Vector2.ZERO, t * 2.0, "jump", false, false, t)
		draw_set_transform(Vector2.ZERO)
	if k > 0.3:
		var ta := minf((k - 0.3) / 0.15, 1.0)
		UiKit._str(self, UiKit.title_font("tiger"), Vector2(vs.x * 0.5, 130), "호랑이 기운", 96, Color(TgArt.HEAD, ta), 10, Color(TgArt.FLAME.darkened(0.4), ta))
	if k > 0.88:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.95, 0.8, (k - 0.88) / 0.12))
	# 진행 띠
	draw_rect(Rect2(80, vs.y - 30, vs.x - 160, 4), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(80, vs.y - 30, (vs.x - 160) * k, 4), TgArt.EMBER)


func _draw_hud() -> void:
	# 체력 막대 — 떡 아이콘 + 막대, 20 아래면 붉게 떨린다
	var r := _oil_rect()
	var ok := g.oil / TgD.OIL_MAX
	var low := ok < 0.2
	var jit := Vector2(sin(t * 40.0) * 2.0, 0) if low and not g.over else Vector2.ZERO
	TgArt.rr(self, Rect2(r.position + jit, r.size).grow(4), 10, Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.25), 1.5)
	draw_rect(Rect2(r.position + jit, Vector2(r.size.x * ok, r.size.y)), Color8(240, 80, 60) if low else TgArt.EMBER)
	TgArt.candy(self, r.position + Vector2(-30, 13) + jit, t, true)
	# 진행 막대 — 호랑이 머리가 결승선으로
	var pr := Rect2(r.position.x, r.end.y + 16, r.size.x, 6)
	draw_rect(pr, Color(1, 1, 1, 0.25))
	draw_rect(Rect2(pr.position, Vector2(pr.size.x * g.progress(), pr.size.y)), TgArt.PAPER)
	draw_circle(Vector2(pr.position.x + pr.size.x * g.progress(), pr.get_center().y), 8, TgArt.FOX)
	draw_rect(Rect2(pr.end.x - 3, pr.position.y - 8, 6, 22), Color8(200, 60, 50))
	G2.text_mid(self, Vector2(r.end.x + 90, r.get_center().y), "떡 %d" % g.embers, 24, TgArt.HEAD, 5)
	TgArt.coin(self, Vector2(r.end.x + 60, r.get_center().y + 40), t)
	G2.text_mid(self, Vector2(r.end.x + 106, r.get_center().y + 40), str(g.coins), 22, TgArt.EMBER, 5)
	G2.text_mid(self, Vector2(r.position.x - 150, r.get_center().y + 46), "%d. %s" % [g.round_i + 1, String(g.row()[0])], 22, Color(1, 1, 1, 0.85), 4)
	# 호랑이 기운 게이지 단추 — 차면 불빛이 돈다
	var gb := _gauge_btn()
	var gk := float(g.gauge) / g.need
	var full := gk >= 1.0
	TgArt.rr(self, gb, 16, Color8(50, 44, 50), TgArt.EMBER if full else Color(1, 1, 1, 0.25), 4.0 if full else 2.0)
	draw_rect(Rect2(gb.position.x + 8, gb.end.y - 16, (gb.size.x - 16) * gk, 8), TgArt.FLAME if full else TgArt.EMBER.darkened(0.3))
	if full:
		for j in 6:
			var a := t * 3.0 + j * TAU / 6.0
			draw_circle(gb.get_center() + Vector2(cos(a) * gb.size.x * 0.46, sin(a) * gb.size.y * 0.4), 4.0, TgArt.EMBER)
	if g.dashing():
		draw_rect(Rect2(gb.position.x + 8, gb.end.y - 16, (gb.size.x - 16) * g.dash_t / TgD.DASH_T, 8), Color(1, 1, 1))
	G2.text_mid(self, gb.get_center() + Vector2(0, -8), "호랑이 기운 %s" % OS.get_keycode_string(UiKeys.code("tiger", "power", KEY_ENTER)) if full else "호랑이 기운 %d / %d" % [g.gauge, g.need], 24,
			TgArt.HEAD if full else Color(1, 1, 1, 0.6), 4)
	UiKit.button(self, vs, "hub", "tiger", t, "나가기")
	UiKit.button(self, vs, "rules", "tiger", t)
	UiKit.button(self, vs, "vol", "tiger", t)


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	TgArt.rr(self, Rect2(c.x - 300, c.y - 110, 600, 240), 22, Color8(50, 44, 50), TgArt.EMBER, 4.0)
	G2.text_mid(self, Vector2(c.x, c.y - 40), q, 30, TgArt.HEAD, 5)
	_btn(_modal_btn(0), String(labels[0]), Color8(60, 90, 140), 24)
	_btn(_modal_btn(1), String(labels[1]), UiKit.theme("tiger").start, 24)


## 결과 창 — 별이 0.35초 간격으로 하나씩 커졌다 박히고, 점수가 굴러 올라간다.
func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var r := Rect2(c.x - 360, c.y - 240, 720, 480)
	TgArt.rr(self, r, 26, Color8(50, 44, 50), TgArt.EMBER, 4.0)
	G2.text_mid(self, Vector2(c.x, r.position.y + 60), "배부르게 먹었어요" if g.win else "떡이 없으면 잡아먹지", 48, TgArt.HEAD, 8)
	# 결과 그림 — 성공은 배부른 호랑이, 실패는 "잡아먹겠다" 덤비는 호랑이. 두 칸을 번갈아 보여 움직인다(사용자 요청 11-10)
	var pic := TgArt.img(("tg_end_win_%d" if g.win else "tg_end_fail_%d") % (int(end_t * 1.6) % 2))
	if pic != null:
		var ps := pic.get_size()
		var k := 250.0 / maxf(ps.x, ps.y) * G2.out_back(clampf(end_t / 0.4, 0.0, 1.0))
		var bob := sin(end_t * 5.0) * 4.0
		draw_texture_rect(pic, Rect2(Vector2(r.position.x - 136, c.y + 40 + bob) - ps * k * 0.5, ps * k), false)
	var n := g.stars()
	for s in 3:
		var st := end_t - 0.3 - s * 0.35
		var on := s < n and st > 0.0
		var k := 1.0 + 0.8 * maxf(0.0, 1.0 - st / 0.25) if on else 1.0
		_star(Vector2(c.x + (s - 1) * 110, r.position.y + 150), 40, on, k)
	var names := ["완주", "떡 %d / %d" % [g.embers, g.embers_all], "안 부딪힘" if g.hits == 0 else "부딪힘 %d번" % g.hits]
	for s in 3:
		G2.text_mid(self, Vector2(c.x + (s - 1) * 190, r.position.y + 220), String(names[s]), 20, Color(1, 1, 1, 0.75), 0)
	var roll := clampf((end_t - 0.4) / 1.0, 0.0, 1.0)
	G2.text_mid(self, Vector2(c.x, r.position.y + 290), "%d점" % int(g.score() * G2.out_cubic(roll)), 44, TgArt.EMBER, 6)
	_btn(_end_btn(0), "다시", Color8(60, 90, 140), 24)
	_btn(_end_btn(1), "다음 라운드", UiKit.theme("tiger").start, 24, g.win and pick + 1 < TgD.ROUNDS.size())
	_btn(_end_btn(2), "라운드 목록", Color8(60, 90, 140), 24)

# ==================== 확인용 ====================


## `--tg-click-test` — 처음 → 라운드 고르기 → 달리기 → Space 점프 → Esc 창 → 그만두기 를 **진짜 마우스 · 키 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PICK, "라운드 고르기"],
		[func(): _press(_round_rect(0).get_center()), func(): return pick == 0, "첫 라운드 고르기"],
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY, "달리기 시작"],
		[func(): _key(KEY_SPACE), func(): return g != null and (g.fox_y > 0.0 or g.dist > 600.0), "점프"],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "그만둘까요 창"],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.PICK, "그만두기"],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("TG CLICK TEST OK")
		get_tree().quit(0)
		return
	if _cs % 2 == 0:
		steps[i][0].call()
		_cs += 1
		_wait = 0.0
		return
	if steps[i][1].call():
		_cs += 1
		return
	_wait += 0.3
	if _wait < 10.0:
		return
	printerr("TG CLICK TEST FAIL: %s" % steps[i][2])
	get_tree().quit(1)


func _press(p: Vector2) -> void:
	var xf := get_viewport().get_final_transform()
	var wp := xf * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = wp
		e.global_position = wp
		Input.parse_input_event(e)


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)


## 처음 화면의 [규칙] 단추 — 음량 왼쪽(아홉 게임 같은 자리).
func _rules_rect() -> Rect2:
	return Rect2(Hub.std_rect("vol", vs).position.x - 150, Hub.std_rect("vol", vs).position.y, 136, Hub.std_rect("vol", vs).size.y)


func _open_rules() -> void:
	rules.show("tiger", "떡 하나 주면 안 잡아먹지 규칙", TgRules.pages())
