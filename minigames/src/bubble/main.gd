extends Node2D
## 물거품처럼 사라져줘 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기 · 연출.
## 규칙은 전부 [BbGame] 에 있고 여기는 **키를 행동으로 바꾸고 보여 주기만** 합니다. 화면: 처음(TITLE) → 판(PLAY) → 결과 창.
## 판은 가운데 832×676(고전 거품 아케이드의 4:3 한 화면), 양옆은 1P · 2P 글자판. 1280×720 데스크톱 전용.
## 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua). 말투는 해요체.

enum Scr { TITLE, PLAY }

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: BbGame = null
var two := false
var start_lv := 0
var parts: Array = []          ## 터짐 그림 · 물방울 {p, v, t, life, kind}
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t, size}
var says: Array = []           ## 인어 말풍선 {p(플레이어), t, txt}
var banner := {}               ## 가운데 큰 글 {txt, t, col}
var shake := 0.0
var hit := 0.0                 ## 보스가 맞아 붉게
var modal := ""
var end_open := false
var end_t := 0.0
var fresh := {}
var saved := false
var all_dir := ""             ## --bb-allshots 저장 폴더
var all_t := 0.0
var no_save := false
var held_prev := [{}, {}]      ## 지난 프레임에 눌려 있던 일(누른 순간을 가린다)
var moving := [false, false]
var rules := UiRules.new()
var keys := UiKeys.new()
## 기본 키(11-11 사용자 "양손으로" — 두 번째로 정함): 1P 왼손 A D 움직이기 · 오른손 H 점프 · J 거품.
## 2P 왼손 ← → 움직이기 · 오른손 숫자판 1 점프 · 2 거품. **위 화살표는 아무 일도 안 한다**(사용자 "위로 버튼이 아직 살아 있다").
const KEYS_P1 := [["p1_left", "1P 왼쪽", KEY_A], ["p1_right", "1P 오른쪽", KEY_D], ["p1_jump", "1P 점프", KEY_H], ["p1_shot", "1P 거품", KEY_J]]
const KEYS_P2 := [["p2_left", "2P 왼쪽", KEY_LEFT], ["p2_right", "2P 오른쪽", KEY_RIGHT], ["p2_jump", "2P 점프", KEY_KP_1], ["p2_shot", "2P 거품", KEY_KP_2]]
## 혼자 할 때 1P 가 덤으로 듣는 키(2P 자리) — 키 설정에서 1P 의 다른 일에 준 키는 빠진다
const ALT := {left = [KEY_LEFT], right = [KEY_RIGHT], jump = [KEY_KP_1], shot = [KEY_KP_2]}
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var demo := false              ## 확인용 — 봇이 1P(둘이면 2P 도)를 대신 움직인다
var god := false
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


var _back: Node2D            ## 판 배경 · 어두운 옆판 — 이 노드보다 뒤에 그린다
var _tile_nodes: Array = []  ## 발판 층 둘(0 지금 판 · 1 넘어갈 때 밑에서 올라오는 다음 판) — 판마다 색상을 돌리는 셰이더를 건다(영상 분석 #9)


func _ready() -> void:
	# 발판만 색상을 돌리려고 배경 · 발판을 뒤 노드로 뺐다(이 노드의 _draw 는 그 위에 악당 · 사람 · 글자). 그림을 색마다 굽지 않는다(사용자 11-11 "코드로 색만")
	_back = Node2D.new()
	_back.show_behind_parent = true
	add_child(_back)
	_back.draw.connect(_draw_back)
	var hue := Shader.new()
	hue.code = "shader_type canvas_item;
uniform float turn = 0.0;
void fragment() {
	vec3 k = vec3(0.57735);
	COLOR.rgb = clamp(COLOR.rgb * cos(turn) + cross(k, COLOR.rgb) * sin(turn) + k * dot(k, COLOR.rgb) * (1.0 - cos(turn)), 0.0, 1.0);
}
"
	for k in 2:
		var n := Node2D.new()
		n.show_behind_parent = true
		var m := ShaderMaterial.new()
		m.shader = hue
		n.material = m
		add_child(n)
		n.draw.connect(_draw_tiles.bind(k))
		_tile_nodes.append(n)
	Bgm.use("bubble")
	BbSnd.init(Hub.host(self))
	BbSv.load_()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a.begins_with("--bb-lv="):   # 확인용 — N 판부터
			start_lv = clampi(int(a.substr(8)) - 1, 0, BbD.LEVELS - 1)
		elif a == "--bb-two":
			two = true
		elif a == "--bb-demo":
			demo = true
		elif a == "--bb-god":
			god = true
		elif a == "--bb-blind":   # 확인용 — 시작하자마자 1P 가 먹물을 맞은 것처럼
			(func(): g.players[0].blind = 30.0).call_deferred()
		elif a == "--bb-over":   # 확인용 — 시작하자마자 목숨을 다 쓴 것처럼(결과 창 · 이어 하기)
			(func(): g.god = false; g.players[0].lives = 0; g.players[0].inv = 0.0; g._die(0)).call_deferred()
		elif a == "--bb-play":
			(func(): _start(two)).call_deferred()
		elif a == "--bb-fx":   # 확인용 — 2.6 초에 1P 앞에서 번개 · 물살 거품을 터뜨린다(그림 확인)
			get_tree().create_timer(2.6).timeout.connect(func():
				var p: Dictionary = g.players[0]
				for spk in 2:
					var b := {x = float(p.x) + BbD.T * (2.0 + spk * 3.0), y = float(p.y) - BbD.T * (1.0 + spk * 6.0), vx = 0.0, state = "float", t = 1.0, owner = -1,
							trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = -1, go = 0.0, sp = spk}
					g.bubbles.append(b)
					g._pop(b, 0))
		elif a.begins_with("--bb-allshots="):   # 확인용 — 50 판을 차례로 열어 판마다 판 부분을 찍는다(창 한 번에)
			all_dir = a.substr(14)
			god = true
			(func(): _start(false)).call_deferred()
		elif a == "--bb-secret":   # 확인용 — 2 초에 비밀 방으로
			get_tree().create_timer(2.0).timeout.connect(func(): g._enter_secret())
		elif a == "--bb-click-test":
			click_test = true
		elif a.begins_with("--bb-rules"):
			var pg := int(a.substr(11)) - 1 if a.length() > 11 else 0
			(func(): _open_rules(); rules.page = clampi(pg, 0, rules.pages.size() - 1)).call_deferred()
	no_save = not OS.get_cmdline_user_args().is_empty()


func _start(p_two: bool) -> void:
	two = p_two
	g = BbGame.new(start_lv, two)
	g.god = god
	scr = Scr.PLAY
	parts = []
	pops = []
	says = []
	banner = {}
	modal = ""
	end_open = false
	end_t = 0.0
	saved = false
	fresh = {}
	held_prev = [{}, {}]
	BbSnd.play("tick")


func _paused() -> bool:
	return modal != "" or Vol.open or end_open or rules.open or keys.open


# ==================== 입력 ====================


func _code(row: Array) -> int:
	return UiKeys.code("bubble", String(row[0]), int(row[2]))


func _down(k: int) -> bool:
	return Input.is_physical_key_pressed(k) or Input.is_key_pressed(k)


## i 번 사람이 지금 누르고 있는 일 {left, right, jump, shot}.
func _held(i: int) -> Dictionary:
	var rows: Array = KEYS_P1 if i == 0 else KEYS_P2
	var out := {}
	var used := []
	for row: Array in rows:
		used.append(_code(row))
	for row: Array in rows:
		var act := String(row[0]).substr(3)
		var on := _down(_code(row))
		if i == 0 and not two:
			for k: int in ALT[act]:
				if not used.has(k) and _down(k):
					on = true
		out[act] = on
	return out


func _read_input() -> void:
	for i in g.players.size():
		var h := _held(i)
		var prev: Dictionary = held_prev[i]
		var ip := {left = h.left, right = h.right, jump = h.jump and not prev.get("jump", false), jump_held = h.jump,
				shot = h.shot and (not prev.get("shot", false) or int(g.players[i].power) == 1)}
		held_prev[i] = h
		if demo:
			ip = g.bot_input(i)
		g.inp[i] = ip
		moving[i] = ip.left != ip.right


func _unhandled_input(ev: InputEvent) -> void:
	if Vol.open:
		Vol.handle(ev, vs)
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if keys.key(key.keycode):
			return
		if rules.key(key.keycode):
			return
		if key.keycode == KEY_ESCAPE:
			_escape()
		elif scr == Scr.TITLE and (key.keycode == KEY_SPACE or key.keycode == KEY_ENTER):
			_start(false)
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_click(mb.position)


func _escape() -> void:
	if scr == Scr.TITLE:
		Hub.leave(self)
	elif end_open:
		scr = Scr.TITLE
	else:
		modal = "" if modal != "" else "quit"


func _click(p: Vector2) -> void:
	if keys.click(p, vs):
		return
	if rules.click(p, vs):
		return
	if Hub.std_rect("vol", vs).has_point(p):
		Vol.open = true
		return
	if scr == Scr.TITLE:
		if Hub.std_rect("hub", vs).has_point(p):
			Hub.leave(self)
		elif Hub.std_rect("start", vs).has_point(p):
			_start(false)
		elif UiKit.menu_rect(vs, 0).has_point(p):
			_start(true)
		elif UiKit.menu_rect(vs, 1).has_point(p):
			keys.show("bubble", KEYS_P1)
		elif UiKit.menu_rect(vs, 2).has_point(p):
			keys.show("bubble", KEYS_P2)
		elif _rules_rect().has_point(p):
			_open_rules()
		return
	if end_open:
		if _end_btn(0).has_point(p):
			scr = Scr.TITLE
		elif _end_btn(1).has_point(p):
			_start(two)
		elif _can_continue() and _end_btn(2).has_point(p) and g.continue_():
			end_open = false
			end_t = 0.0
			saved = false
			BbSnd.play("power")
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			_finish()
			scr = Scr.TITLE
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if Hub.std_rect("hub", vs).has_point(p):
		modal = "quit"
	elif Hub.std_rect("rules", vs).has_point(p):
		_open_rules()


# ==================== 흐름 ====================


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	if all_dir != "" and g != null and scr == Scr.PLAY:
		all_t += dt
		if all_t >= 2.8:   # 악당이 내려와 자리 잡고 판 이름 띠가 사라진 뒤
			all_t = 0.0
			var img := get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(BbD.ORIGIN), Vector2i(BbD.FIELD)))
			img.save_png(all_dir.path_join("lv_%02d.png" % (g.lv + 1)))
			print("SHOT %d %s" % [g.lv + 1, BbD.kind(g.lv)])
			if g.lv + 1 >= BbD.LEVELS:
				get_tree().quit()
			else:
				g._load(g.lv + 1)
	shake = maxf(0.0, shake - dt)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0 if shake > 0.0 else Vector2.ZERO   # 흔들림(그림 함수가 변환을 되돌려서 노드 자리로)
	hit = maxf(0.0, hit - dt)
	if scr == Scr.PLAY and g != null:
		if not _paused():
			_read_input()
			g.step(dt)
			Bgm.mood_lv(0 if g.state != "play" or not g.hurry else (2 if not g.shark.is_empty() else 1))   # 서둘러요! 빨라지고, 상어가 나오면 한 번 더
			_take_events()
		if g.state == "over" or g.state == "win":
			end_t += dt
			if end_t > 1.6 and not end_open:
				_finish()
				end_open = true
				end_t = 0.0
	for p: Dictionary in parts:
		p.t += dt
		p.p += p.v * dt
		p.v *= 1.0 - dt * 3.0
	parts = parts.filter(func(p): return p.t < p.life)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.1)
	for s: Dictionary in says:
		s.t += dt
	says = says.filter(func(s): return s.t < 1.4)
	if not banner.is_empty():
		banner.t += dt
		if banner.t > 2.0:
			banner = {}
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
	for n: Node2D in [_back] + _tile_nodes:
		n.visible = scr != Scr.TITLE and g != null
		n.queue_redraw()


func _finish() -> void:
	if saved or g == null:
		return
	saved = true
	fresh = BbSv.add(g)
	if not no_save:
		BbSv.save_()


func _scr(x: float, y: float) -> Vector2:
	return BbD.ORIGIN + Vector2(x, y)


func _pop_text(at: Vector2, txt: String, col: Color, size: float = 24.0) -> void:
	pops.append({p = at, txt = txt, col = col, t = 0.0, size = size})


func _splash(at: Vector2, big: float = 1.0) -> void:
	parts.append({p = at, v = Vector2.ZERO, t = 0.0, life = 0.4, kind = "pop", k = big})


func _take_events() -> void:
	for e: Dictionary in g.events:
		var at := _scr(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
		match String(e.kind):
			"shot":
				BbSnd.play("shot", randf_range(0.95, 1.1))
			"jump":
				BbSnd.play("jump")
			"bounce":
				BbSnd.play("jump", 1.3)
			"trap":
				BbSnd.play("trap")
			"fizz", "fade":
				BbSnd.play("pop", 1.4)
				_splash(at, 0.5)
			"escape":
				BbSnd.play("hurry", 1.4)
				_pop_text(at, "탈출!", Color8(255, 120, 110), 22)
			"pop":
				_splash(at, 1.0 if int(e.chain) > 0 else 0.6)
				if int(e.chain) > 0:
					BbSnd.play("kill", 1.0 + float(e.get("pts", 1000)) / 16000.0)
					_pop_text(at + Vector2(0, -10), str(int(e.pts)), BbArt.GOLD, 24)
				else:
					BbSnd.play("pop")
			"chain":
				shake = 0.25
				_pop_text(at + Vector2(0, -50), "%d마리 한꺼번에!" % int(e.n), Color.from_hsv(fmod(t, 1.0), 0.5, 1.0), 34)
			"item":
				BbSnd.play("item", 1.0 + int(e.v) * 0.15)
				_pop_text(at, str(int(e.pts)), Color(1, 1, 1), 20)
			"power":
				BbSnd.play("power")
				_pop_text(at, String(BbD.POWERS[int(e.v)][0]), BbArt.GOLD, 26)
			"letter":
				BbSnd.play("letter")
				_pop_text(at, String(BbD.WORD[int(e.v)]), BbD.WORD_COL[int(e.v)], 34)
			"word":
				BbSnd.play("clear")
				banner = {txt = "물거품처럼!  목숨 하나 더 · 판 통과", t = 0.0, col = BbArt.GOLD}
			"skip":
				BbSnd.play("power")
				banner = {txt = "건너뛰기!  %d판 더 넘어가요" % int(e.n), t = 0.0, col = BbArt.GOLD}
			"door":
				banner = {txt = "한 번도 안 죽었어요!  바닥에 문이 열렸어요", t = 0.0, col = Color8(220, 180, 255)}
			"secret":
				BbSnd.play("clear")
				banner = {txt = "비밀 방", t = 0.0, col = Color8(220, 180, 255)}
			"special":
				BbSnd.play("power", 0.8 if int(e.v) == 1 else 1.3)
				shake = 0.2
				_pop_text(at, String(BbD.SPECIAL[int(e.v)]), BbArt.GOLD, 28)
			"inked":
				BbSnd.play("pop", 0.6)
				_pop_text(at + Vector2(0, -60), "앞이 안 보여요!", Color8(200, 170, 255), 22)
			"die":
				BbSnd.play("die")
				shake = 0.4
			"hurry":
				BbSnd.play("hurry")
				banner = {txt = "서둘러요!", t = 0.0, col = Color8(255, 120, 110)}
			"shark":
				banner = {txt = "상어가 와요!", t = 0.0, col = Color8(200, 220, 255)}
			"clear":
				BbSnd.play("clear")
			"level":
				banner = {txt = "%d판" % (int(e.lv) + 1) if not BbD.boss_level(int(e.lv)) else "%d판  보스 %s" % [int(e.lv) + 1, String(BbD.BOSS[int(e.lv) / 10][0])], t = 0.0, col = BbArt.HEAD}
			"boss_wind":
				BbSnd.play("hurry", 0.7)
			"boss_fire":
				BbSnd.play("power", 0.6)
				shake = maxf(shake, 0.15)
			"boss_slam":
				shake = 0.5
				_splash(at, 1.5)
			"boss_hit":
				BbSnd.play("boss")
				hit = 0.15
				_splash(at, 0.6)
			"boss_trap":
				BbSnd.play("trap", 0.6)
				banner = {txt = "가뒀어요!  부딪혀 터뜨려요", t = 0.0, col = BbArt.GOLD}
			"boss_pop":
				BbSnd.play("clear")
				shake = 0.6
				_splash(at, 3.0)
				says.append({p = int(e.p), t = 0.0, txt = BbD.LINE})
			"over":
				BbSnd.play("over")
			"win":
				BbSnd.play("clear")
	g.events.clear()


# ==================== 그리기 ====================


func _draw() -> void:
	Hub.compact = scr == Scr.PLAY
	if scr == Scr.TITLE:
		_draw_title()
	elif g != null:
		_draw_play()
	Vol.draw(self, vs, t)


func _draw_title() -> void:
	var bg := BbArt.img("bb_title")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vs), BbArt.SEA)
	UiKit.title(self, vs, "bubble", "물거품처럼 사라져줘", "꼬마 인어가 거품으로 바다 악당을 가둬요", t)
	if BbSv.plays > 0:
		UiKit.record_line(self, vs, "혼자 최고 %d점, %d판   둘이 최고 %d점, %d판" % [BbSv.best[0], BbSv.best_lv[0], BbSv.best[1], BbSv.best_lv[1]])
	UiKit.key_hint(self, vs, "A D 움직이기, H 점프, J 거품   둘이 하면 2P 는 ← → · 숫자판 1 점프 · 2 거품")
	UiKit.button(self, vs, "start", "bubble", t, "혼자 하기")
	UiKit.button(self, vs, "hub", "bubble", t)
	UiKit.button(self, vs, "vol", "bubble", t)
	var th := UiKit.theme("bubble")
	UiKit.menu(self, UiKit.menu_rect(vs, 0), "둘이 하기", th.start, "bubble", t)
	UiKit.menu(self, UiKit.menu_rect(vs, 1), "1P 키 설정", th.menu, "bubble", t)
	UiKit.menu(self, UiKit.menu_rect(vs, 2), "2P 키 설정", th.menu, "bubble", t)
	UiKit.plain(self, _rules_rect(), "규칙", th.hub, "bubble", t, true, 24)
	rules.draw(self, vs, t)
	keys.draw(self, vs, t)


## 판 넘어가기 — 지금 판이 위로 올라가고 다음 판이 밑에서. 올라간 거리(px).
func _scroll() -> float:
	return G2.out_cubic(clampf(g.state_t / 1.1, 0.0, 1.0)) * BbD.FIELD.y if g.state == "next" else 0.0


func _draw_back() -> void:
	if g == null:
		return
	var bg := BbArt.img("bb_bg_%d" % BbD.theme(g.lv))
	if bg != null:
		_back.draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
	else:
		_back.draw_rect(Rect2(Vector2.ZERO, vs), BbArt.SEA)
	var fr := Rect2(BbD.ORIGIN, BbD.FIELD)
	# 판 밖(양옆 글자판)은 어둡게 — 판이 한 화면 무대로 보이게
	_back.draw_rect(Rect2(0, 0, fr.position.x, vs.y), Color(BbArt.PANEL, 0.82))
	_back.draw_rect(Rect2(fr.end.x, 0, vs.x - fr.end.x, vs.y), Color(BbArt.PANEL, 0.82))
	_back.draw_rect(Rect2(fr.position.x, 0, fr.size.x, fr.position.y), Color(BbArt.PANEL, 0.82))


## 발판 층 — k 0 지금 판, 1 넘어갈 때 다음 판. 판마다 색상을 BbArt.TILE_TURN 만큼 돌린다(비밀 방은 원래 색).
func _draw_tiles(k: int) -> void:
	if g == null or (k == 1 and g.state != "next"):
		return
	var n: Node2D = _tile_nodes[k]
	var lv: int = g.lv if k == 0 else mini(g.next_lv, BbD.LEVELS - 1)
	var secret: bool = k == 0 and g.secret
	(n.material as ShaderMaterial).set_shader_parameter("turn", 0.0 if secret else deg_to_rad(BbArt.TILE_TURN[lv % 10]))
	BbArt.tiles(n, g.grid if k == 0 else BbD.level(lv), BbD.theme(lv),
			BbD.ORIGIN + Vector2(0, -_scroll() if k == 0 else BbD.FIELD.y - _scroll()), {} if secret else BbD.blocks(lv))


func _draw_play() -> void:
	var scroll := _scroll()   # 배경 · 발판은 뒤 노드(_draw_back · _draw_tiles)가 그린다
	var fr := Rect2(BbD.ORIGIN, BbD.FIELD)
	if g.state != "next":
		_draw_things()
		if g.dark > 0.0:   # 아귀가 불을 껐다 — 판이 어둡고 사람만 보인다(아귀 미끼 불빛은 위에)
			var a := minf(1.0, g.dark * 2.0) * minf(1.0, (BbD.BOSS_DARK_T - g.dark) * 4.0)
			draw_rect(Rect2(BbD.ORIGIN, BbD.FIELD), Color(0.02, 0.03, 0.08, 0.86 * a))
			if not g.boss.is_empty():
				draw_circle(_scr(g.boss.x, g.boss.y), BbD.T * 1.2, Color(1.0, 0.95, 0.5, 0.5 * a))
	for i in g.players.size():
		_draw_player(i, scroll)
	for p: Dictionary in parts:
		var tex := BbArt.img("bb_pop")
		var k := float(p.t) / float(p.life)
		var r := BbD.T * (1.0 + k * 1.2) * float(p.k)
		if tex != null:
			draw_texture_rect(tex, Rect2(p.p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 1.0 - k))
	for s: Dictionary in says:
		var pl: Dictionary = g.players[int(s.p)]
		var at := _scr(pl.x, pl.y) + Vector2(0, -BbD.T * 3.0 - minf(1.0, float(s.t) * 6.0) * 10.0)
		at.x = clampf(at.x, fr.position.x + 130, fr.end.x - 130)
		var a := minf(1.0, (1.4 - float(s.t)) * 4.0)
		G2.panel(self, Rect2(at - Vector2(120, 22), Vector2(240, 44)), Color(1, 1, 1, 0.92 * a), Color(BbArt.INK, a), 3.0, 20.0)
		G2.text_mid(self, at, String(s.txt), 22, Color(BbArt.INK, a), 0)
	for p: Dictionary in pops:
		var a := minf(1.0, (1.1 - float(p.t)) * 3.0)
		G2.text_mid(self, p.p + Vector2(0, -float(p.t) * 40.0), String(p.txt), float(p.size), Color(p.col, a), 5, Color(BbArt.INK, a))
	_draw_blind()
	_draw_hud()
	if g.state == "over" or g.state == "win":
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, minf(0.6, end_t * 0.5) if not end_open else 0.6))
	if modal == "quit":
		_draw_modal()
	if end_open:
		_draw_end()
	rules.draw(self, vs, t)


func _draw_things() -> void:
	if not g.door.is_empty():
		BbArt.door(self, _scr(g.door.x, g.door.y), t)
	for it: Dictionary in g.items:
		if float(it.t) >= 0.0:
			BbArt.item(self, String(it.kind), int(it.v), _scr(it.x, it.y), t, String(it.kind) == "item" and float(it.t) > BbD.ITEM_LIFE - 2.5)
	for e: Dictionary in g.enemies:
		BbArt.enemy(self, int(e.k), _scr(e.x, e.y), int(e.dir), bool(e.angry), t + float(e.x) * 0.01)
		if int(e.k) == 4 and g._spiky(e):   # 성게 가시 — 화난 칸(가시를 세운 그림)으로
			BbArt.enemy(self, 4, _scr(e.x, e.y), int(e.dir), true, t)
	for d: Dictionary in g.dying:   # 터져 날아가며 빙글
		var tex := BbArt.en_tex(int(d.k), 2)
		if tex != null:
			var s := tex.get_size()
			var h := BbD.T * 1.8
			draw_set_transform(_scr(d.x, d.y), float(d.t) * 12.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-s.x * h / s.y * 0.5, -h * 0.5, s.x * h / s.y, h), false, Color(BbArt.en_art(int(d.k))[1], 1.0 - float(d.t)))
			draw_set_transform(Vector2.ZERO)
	if not g.boss.is_empty():
		var bk := clampi(g.lv / 10, 0, BbD.BOSS.size() - 1)
		var bc := _scr(g.boss.x, g.boss.y)
		BbArt.boss(self, bk, bc, int(g.boss.get("face", -1)), hit, t, String(g.boss.get("anim", "idle")))
		if bool(g.boss.trapped):
			BbArt.bubble(self, bc, BbD.BOSS_SIZE * 0.7, -1, 0.0, t)
		else:   # 체력 막대
			var w := 140.0
			var r := Rect2(bc + Vector2(-w * 0.5, -BbD.BOSS_SIZE * 0.7), Vector2(w, 10))
			draw_rect(r.grow(2), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(r.position, Vector2(w * float(g.boss.hp) / float(g.boss.max), 10)), Color8(255, 110, 110))
	for b: Dictionary in g.bubbles:
		var red := 0.0
		if int(b.trap) >= 0 and float(b.trap_t) > BbD.TRAP_RED:
			red = (float(b.trap_t) - BbD.TRAP_RED) / (BbD.TRAP_OUT - BbD.TRAP_RED)
		var grow := 1.0 if String(b.state) != "shot" else lerpf(0.3, 1.0, clampf(float(b.t) / 0.12, 0.0, 1.0))   # 입에서 작게 나와 부푼다
		BbArt.bubble(self, _scr(b.x, b.y), g._r(b) * grow, int(b.trap), red, t + float(b.t), int(b.word), bool(b.rainbow), int(b.get("sp", -1)))
	for z: Dictionary in g.bolts:   # 번개 — 지그재그 빛줄기
		var c := _scr(z.x, z.y)
		var dirx := signf(float(z.vx))
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(c + Vector2(-dirx * i * 14.0, (8.0 if i % 2 == 0 else -8.0) * (1.0 + sin(t * 30.0 + i))))
		draw_polyline(pts, Color(1.0, 0.95, 0.5, 0.9), 6.0)
		draw_polyline(pts, Color(1, 1, 1), 2.0)
		BbArt.bolt_icon(self, c, BbD.T * 0.9)
	for w: Dictionary in g.waters:   # 물살 — 지나온 길을 굵은 물줄기로
		var tr: Array = w.trail
		if tr.size() >= 2:
			var pts2 := PackedVector2Array()
			for v: Vector2 in tr:
				pts2.append(_scr(v.x, v.y - BbD.T * 0.4))
			var fade := clampf((BbD.WATER_T - float(w.t)) / 1.0, 0.0, 1.0)
			draw_polyline(pts2, Color(0.3, 0.6, 1.0, 0.75 * fade), BbD.T * 1.1)
			draw_polyline(pts2, Color(0.8, 0.95, 1.0, 0.8 * fade), 4.0)
	for s: Dictionary in g.bshots:
		BbArt.boss_shot(self, int(s.k), _scr(s.x, s.y), t + float(s.t), Vector2(s.vx, s.vy))
	for k: Dictionary in g.inks:
		BbArt.ink(self, _scr(k.x, k.y), 26.0, 1.0, t * 8.0)
	if not g.shark.is_empty():
		BbArt.shark(self, _scr(g.shark.x, g.shark.y), 1 if float(g.shark.x) < float(g.players[0].x) else -1, t)


func _draw_player(i: int, scroll: float) -> void:
	var p: Dictionary = g.players[i]
	if p.out:
		return
	var foot := _scr(p.x, p.y)
	if g.state == "next":   # 판을 넘는 동안 제자리(다음 판 처음 자리)로 둥실
		var to := _scr((3.5 if i == 0 else BbD.COLS - 3.5) * BbD.T, (BbD.ROWS - 1) * BbD.T)
		foot = foot.lerp(to, clampf(g.state_t / 1.1, 0.0, 1.0))
		BbArt.bubble(self, foot + Vector2(0, -BbD.T), BbD.T * 1.5, -1, 0.0, t)
	if not p.active:
		if float(p.dead_t) < 1.2:
			BbArt.mermaid(self, i, foot + Vector2(0, -float(p.dead_t) * 60.0), int(p.dir), "hurt", t, Color(1, 1, 1, 1.0 - float(p.dead_t) / 1.2))
		return
	if float(p.inv) > 0.0 and fmod(t * 10.0, 1.0) < 0.35:
		return
	var pose := "stand"
	if g.state == "win" or (g.state == "clear" and not moving[i] and p.ground and g.items.is_empty()):   # 물건 줍는 동안은 뛰어다닌다
		pose = "win"
	elif float(p.shot_anim) > 0.0:
		pose = "shot"
	elif not p.ground:
		pose = "jump"
	elif moving[i]:
		pose = "run"
	BbArt.mermaid(self, i, foot, int(p.dir), pose, t)
	if int(p.power) >= 0:   # 힘이 있으면 발밑에 반짝
		draw_circle(foot + Vector2(sin(t * 6.0) * 14.0, -BbD.T * 2.2), 3.0, BbArt.GOLD)


## 먹물을 맞은 사람 — 그 사람 둘레(판의 절반쯤)를 먹물 얼룩이 덮는다. 끝날 때쯤 옅어진다.
func _draw_blind() -> void:
	for i in g.players.size():
		var p: Dictionary = g.players[i]
		var b := float(p.blind)
		if b <= 0.0 or not p.active:
			continue
		var a := minf(1.0, b / 0.6)
		var c := _scr(p.x, float(p.y) - BbD.T)
		for k in 5:
			var off := Vector2(cos(k * 1.3 + i) * 90.0, sin(k * 2.1 + i) * 70.0) if k > 0 else Vector2.ZERO
			BbArt.ink(self, c + off, 300.0 - k * 30.0, a * 0.95, k * 1.1)


func _draw_hud() -> void:
	var fr := Rect2(BbD.ORIGIN, BbD.FIELD)
	G2.text_mid(self, Vector2(vs.x * 0.5, 22), "%d판" % (g.lv + 1), 26, BbArt.HEAD, 5, BbArt.INK)
	for i in 2:
		var cx := fr.position.x * 0.5 if i == 0 else (fr.end.x + vs.x) * 0.5
		var col: Color = BbArt.P_COL[i]
		if i >= g.players.size():
			G2.text_mid(self, Vector2(cx, 160), "2P", 34, Color(1, 1, 1, 0.35), 4)
			G2.text_mid(self, Vector2(cx, 200), "둘이 하기에서", 20, Color(1, 1, 1, 0.35), 0)
			continue
		var p: Dictionary = g.players[i]
		G2.text_mid(self, Vector2(cx, 110), "%dP" % (i + 1), 34, col, 5, BbArt.INK)
		G2.text_mid(self, Vector2(cx, 160), str(int(p.score)), 30, BbArt.HEAD, 5, BbArt.INK)
		# 목숨 — 작은 인어 얼굴
		var tex := BbArt.img(("bb_mer" if i == 0 else "bb_mer2") + "_a_0")
		for k in mini(int(p.lives), 6):
			var at := Vector2(cx - 60 + (k % 3) * 60, 220 + (k / 3) * 52)
			if tex != null:
				BbArt.sprite(self, tex, at + Vector2(0, 22), 44, false)
		if p.out:
			G2.text_mid(self, Vector2(cx, 240), "끝", 28, Color(1, 1, 1, 0.6), 4)
		# 글자 — 물 거 품 처 럼
		for k in BbD.WORD.size():
			var on := int(p.letters) & (1 << k) != 0
			var c := Vector2(cx - 76 + k * 38, 360)
			draw_circle(c, 17, Color(BbD.WORD_COL[k], 0.95 if on else 0.18))
			G2.text_mid(self, c + Vector2(0, 1), String(BbD.WORD[k]), 22, Color(1, 1, 1, 1.0 if on else 0.35), 3 if on else 0, BbArt.INK)
		if int(p.power) >= 0:
			BbArt.item(self, "power", int(p.power), Vector2(cx, 440), t)
			G2.text_mid(self, Vector2(cx, 480), String(BbD.POWERS[int(p.power)][0]), 20, BbArt.GOLD, 4)
	if g.state == "play" and (not g.enemies.is_empty() or not g.boss.is_empty()):
		var left := -1.0
		var what := ""
		if not g.hurry and g.time > BbD.HURRY_T - 5.0:
			left = BbD.HURRY_T - g.time
			what = "서둘러요까지"
		elif g.shark.is_empty() and g.time > BbD.SHARK_T - 5.0:
			left = BbD.SHARK_T - g.time
			what = "상어까지"
		if left > 0.0:
			var pulse := 1.0 + (1.0 - fmod(left, 1.0)) * 0.15
			G2.text_mid(self, Vector2(vs.x * 0.5, 64), "%s %d" % [what, int(ceil(left))], 24 * pulse, Color8(255, 150, 140), 5, BbArt.INK)
	if g.state == "secret":   # 비밀 방 — 비밀 한 줄
		var tip := String(BbD.SECRET_TIPS[clampi(g.lv / 10, 0, BbD.SECRET_TIPS.size() - 1)])
		G2.text_mid(self, Vector2(vs.x * 0.5, 64), "비밀 방  %d" % int(ceil(BbD.SECRET_T - g.state_t)), 24, Color8(220, 180, 255), 5, BbArt.INK)
		G2.text_mid(self, Vector2(vs.x * 0.5, 100), tip, 20, BbArt.HEAD, 4, BbArt.INK)
	if g.state == "clear" and not g.items.is_empty():   # 판을 깬 뒤 물건 줍는 시간
		var left2 := BbD.CLEAR_WAIT - g.state_t
		G2.text_mid(self, Vector2(vs.x * 0.5, 64), "물건 줍기 %d" % int(ceil(left2)), 24, BbArt.GOLD, 5, BbArt.INK)
	if not banner.is_empty():
		var a := minf(1.0, float(banner.t) / 0.2) * minf(1.0, (2.0 - float(banner.t)) / 0.4)
		draw_rect(Rect2(fr.position.x, 300, fr.size.x, 80), Color(0, 0, 0, 0.35 * a))
		UiKit._str(self, UiKit.title_font("bubble"), Vector2(vs.x * 0.5, 340), String(banner.txt), 46, Color(banner.col, a), 8, Color(BbArt.INK, a))
	UiKit.button(self, vs, "hub", "bubble", t, "나가기")
	UiKit.button(self, vs, "rules", "bubble", t)
	UiKit.button(self, vs, "vol", "bubble", t)


func _modal_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 250 + k * 270, vs.y * 0.5 + 20, 230, 64)


func _end_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 340 + k * 230, vs.y * 0.5 + 140, 210, 64)


## 이어 하기 — 목숨을 다 써서 끝났고 남은 횟수가 있을 때. 점수는 0 부터, 판은 그대로.
func _can_continue() -> bool:
	return g != null and g.state == "over" and g.continues > 0


func _draw_modal() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	G2.panel(self, Rect2(c.x - 300, c.y - 110, 600, 240), BbArt.PANEL, BbArt.GOLD, 4.0, 22.0)
	G2.text_mid(self, Vector2(c.x, c.y - 40), "그만둘까요?", 30, BbArt.HEAD, 5)
	UiKit.plain(self, _modal_btn(0), "그만두기", UiKit.theme("bubble").menu, "bubble", t, true, 24)
	UiKit.plain(self, _modal_btn(1), "계속하기", UiKit.theme("bubble").start, "bubble", t, true, 24)


func _draw_end() -> void:
	var c := vs * 0.5
	var r := Rect2(c.x - 360, c.y - 240, 720, 480)
	G2.panel(self, r, BbArt.PANEL, BbArt.GOLD, 4.0, 26.0)
	var win := g.state == "win"
	G2.text_mid(self, Vector2(c.x, r.position.y + 60), "바다를 구했어요!" if win else "물거품이 됐어요", 46, BbArt.HEAD, 8, BbArt.INK)
	var pic := BbArt.img(("bb_mer_b_%d" % (2 if win else 1)))
	if pic != null:
		BbArt.sprite(self, pic, Vector2(r.position.x + 110, c.y + 60 + sin(end_t * 4.0) * 4.0), 150, false)
	G2.text_mid(self, Vector2(c.x + 40, r.position.y + 140), "%d판까지" % (g.lv + 1), 30, BbArt.HEAD, 5)
	var roll := clampf(end_t / 1.0, 0.0, 1.0)
	G2.text_mid(self, Vector2(c.x + 40, r.position.y + 210), "%d점" % int(g.total_score() * G2.out_cubic(roll)), 52, BbArt.GOLD, 7)
	if two:
		G2.text_mid(self, Vector2(c.x + 40, r.position.y + 262), "1P %d점   2P %d점" % [int(g.players[0].score), int(g.players[1].score)], 22, Color(1, 1, 1, 0.8), 0)
	var tags := []
	if fresh.get("score", false):
		tags.append("최고 점수")
	if fresh.get("lv", false):
		tags.append("가장 먼 판")
	if not tags.is_empty() and end_t > 1.0:
		G2.text_mid(self, Vector2(c.x + 40, r.position.y + 300), "새 기록!  " + ", ".join(tags), 24, Color8(255, 220, 120), 5)
	UiKit.plain(self, _end_btn(0), "처음 화면", UiKit.theme("bubble").menu, "bubble", t, true, 24)
	UiKit.plain(self, _end_btn(1), "1판부터", UiKit.theme("bubble").menu, "bubble", t, true, 24)
	if _can_continue():
		UiKit.plain(self, _end_btn(2), "이어 하기 (%d번)" % g.continues, UiKit.theme("bubble").start, "bubble", t, true, 24)


func _rules_rect() -> Rect2:
	return Rect2(Hub.std_rect("vol", vs).position.x - 150, Hub.std_rect("vol", vs).position.y, 136, Hub.std_rect("vol", vs).size.y)


func _open_rules() -> void:
	rules.show("bubble", "물거품처럼 사라져줘 규칙", BbRules.pages())

# ==================== 확인용 ====================


## `--bb-click-test` — 처음 → 혼자 하기 → 점프 · 거품 → Esc 창 → 그만두기 → 둘이 하기 → 2P 거품 → 나가기 를 **진짜 마우스 · 키 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY and not two, "혼자 하기"],
		[func(): _key(KEY_H, true), func(): return g.players[0].vy < 0.0 or not g.players[0].ground, "점프(H)"],
		[func(): _key(KEY_H, false); _key(KEY_J, true), func(): return not g.bubbles.is_empty(), "거품(J)"],
		[func(): _key(KEY_J, false); _press(Hub.std_rect("hub", vs).get_center()), func(): return modal == "quit", "그만둘까요 창"],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "그만두기"],
		[func(): _press(UiKit.menu_rect(vs, 0).get_center()), func(): return scr == Scr.PLAY and two and g.players.size() == 2, "둘이 하기"],
		[func(): _key(KEY_KP_2, true), func(): return g.bubbles.any(func(b): return int(b.owner) == 1), "2P 거품(숫자판 2)"],
		[func(): _key(KEY_KP_2, false); _key(KEY_J, true), func(): return g.bubbles.any(func(b): return int(b.owner) == 0), "1P 거품(J)"],
		[func(): _key(KEY_J, false); _key(KEY_ESCAPE, true), func(): return modal == "quit", "Esc 창"],
		[func(): _key(KEY_ESCAPE, false); _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "처음 화면"],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("BB CLICK TEST OK")
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
	printerr("BB CLICK TEST FAIL: %s" % steps[i][2])
	get_tree().quit(1)


func _press(p: Vector2) -> void:
	var wp := get_viewport().get_final_transform() * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = wp
		e.global_position = wp
		Input.parse_input_event(e)


func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
