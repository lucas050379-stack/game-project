class_name Hub
extends Node2D

## 미니게임 고르는 화면 — 이 앱의 진입점(main.tscn).
##
## **허브는 앱이 꺼질 때까지 살아 있고, 게임은 그 자식으로 열고 닫는다.** 장면을 통째로
## 바꾸면(change_scene) 젤리팝 효과음 · 배경 음악 · 순위 요청이 붙어 있던 노드가 같이 지워져서,
## 다시 열 때 static 이 지운 노드를 가리킨다. 그래서 오래 사는 것(소리 · 네트워크)은
## [method host] 로 허브에 붙이고, 게임 화면만 갈아 끼운다.
##
## 게임 쪽에서 돌아올 때는 [method leave] 하나만 부른다. 허브 없이 단독으로 돌린 경우
## (검사 스크립트 등)에는 그냥 끝낸다.
##
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요** — Jua 글꼴에 없어서 웹에서 네모로 나옵니다.

const GAMES := [
	{"id": "jelly", "name": "젤리팝", "kind": "3매치 퍼즐",
		"note": "모험 200판과 60초 타임 어택", "col": Color8(255, 120, 180),
		"script": "res://src/jelly/main.gd"},
	{"id": "sky", "name": "스카이 어설트", "kind": "세로 슈팅",
		"note": "기체 7종, 라운드 6개, 보스 부위 파괴", "col": Color8(90, 170, 255),
		"script": "res://src/sky/main.gd"},
	{"id": "runner", "name": "월드 러너", "kind": "주사위 보드게임",
		"note": "세계 도시를 사고 지어 상대를 파산시키기", "col": Color8(120, 210, 120),
		"script": "res://src/runner/main.gd"},
	{"id": "gangho", "name": "강호일생", "kind": "무협 인생",
		"note": "누구로 태어날지는 고를 수 없다", "col": Color8(214, 150, 90),
		"script": "res://src/gangho/main.gd"},
	{"id": "arcana", "name": "아르카나 컬렉션", "kind": "카드 보드게임",
		"note": "자원을 모아 성물을 갖추고 영웅을 부르기", "col": Color8(170, 120, 230),
		"script": "res://src/arcana/main.gd"},
	{"id": "neon", "name": "네온 서바이버", "kind": "생존 액션",
		"note": "움직이면 알아서 싸운다, 레벨업마다 셋 중 하나", "col": Color8(80, 230, 255),
		"script": "res://src/neon/main.gd"},
]

## 젤리팝이 받는 확인용 인자 — 이게 있으면 허브를 건너뛰고 바로 젤리팝을 연다
## (run.bat -- --auto 같은 예전 사용법이 그대로 돈다).
const JELLY_ARGS := ["--auto", "--play", "--sp-demo", "--input-test", "--ui-test", "--map", "--name",
		"--info", "--net", "--unlock"]
const JELLY_PREFIX := ["--stage=", "--guide=", "--good=", "--moves=", "--time="]
const SKY_ARGS := ["--autoplay"]

var cur: Node = null        ## 지금 열려 있는 게임 화면(없으면 허브)
var cur_id := ""
var sel := 0
var t := 0.0
var vs := Vector2(720, 1280)
var shot_path := ""
var shot_at := 0.0
var hub_test := false   ## --hub-test: 게임을 차례로 열고 닫고 다시 연다(되돌아올 때 깨지는 것 확인)
var _ht := 0.0
var _hs := 0


## 오래 사는 노드(소리 · 네트워크)를 붙일 곳. 허브 아래에서 열렸으면 허브, 아니면 자기 자신.
static func host(n: Node) -> Node:
	var p := n.get_parent()
	return p if p is Hub else n


## **처음 화면 단추 자리는 다섯 게임이 같습니다**(사용자 요청 11-08 — "게임 선택 · 음량 · 시작 버튼이 게임마다 위치가 다르다").
##   "hub" 게임 선택 = 왼쪽 위 · "vol" 음량 = 오른쪽 위(허브 화면도 같은 자리) · "start" 시작 = 오른쪽 아래(큰 단추).
## 새 게임도 여기 자리를 쓰세요. 음량 창은 `Vol.open = true` 로 열고, 떠 있는 동안 입력은 `Vol.handle` 에 넘기고 `Vol.draw` 로 그립니다.
static func std_rect(kind: String, vs: Vector2) -> Rect2:
	match kind:
		"hub":
			return Rect2(18, 18, 170, 52)
		"vol":
			return Rect2(vs.x - 188, 18, 170, 52)
		"start":
			return Rect2(vs.x - 398, vs.y - 118, 380, 96)
	return Rect2()


## 게임에서 "게임 선택"으로 돌아간다.
static func leave(n: Node) -> void:
	var p := n.get_parent()
	if p is Hub:
		(p as Hub).close.call_deferred()
	else:
		n.get_tree().quit()


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit_canvas)
	_fit_canvas()
	Sv.load_()
	Snd.init(self)
	Bgm.init(self)
	# 테스트 빌드 · 확인용 실행(명령줄 인자가 하나라도 있으면)에서는 **전체 음량을 끄고** 돌린다 — 저장된 값은 그대로.
	Vol.test_mute = OS.has_feature("testbuild") or not OS.get_cmdline_user_args().is_empty()
	Bgm.use("hub")
	Vol.apply()
	var open := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--game="):
			open = a.substr(7)
		elif a.begins_with("--hub-shot="):
			shot_path = a.substr(11)
		elif a.begins_with("--hub-shot-at="):
			shot_at = float(a.substr(14))
		elif a == "--hub-test":
			hub_test = true
		elif a == "--vol":
			Vol.open = true   # 캡처용 — 음량 창을 연 채로
		elif open == "" and (a in JELLY_ARGS or JELLY_PREFIX.any(func(p): return a.begins_with(p))):
			open = "jelly"
		elif open == "" and a in SKY_ARGS:
			open = "sky"
	if open != "":
		for k in GAMES.size():
			if GAMES[k].id == open:
				_open.call_deferred(k)


func _open(k: int) -> void:
	if cur != null:
		return
	var g: Dictionary = GAMES[k]
	if not ResourceLoader.exists(g.script):
		return
	sel = k
	Snd.play("start")
	var node: Node2D = load(g.script).new()
	node.name = String(g.id)
	cur = node
	cur_id = g.id
	add_child(node)
	queue_redraw()


func close() -> void:
	if cur == null:
		return
	cur.queue_free()
	cur = null
	cur_id = ""
	# 게임이 바꿔 둔 화면 설정을 되돌린다(스카이 어설트의 발광 등).
	get_viewport().use_hdr_2d = false
	Bgm.use("hub")   # 허브는 허브 곡(11-09 — 젤리팝과 다르게) — 게임은 각자 _ready 에서 자기 곡을 고른다
	queue_redraw()


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	Bgm.step(cur == null)   # 허브 화면일 때만 다른 게임 곡을 미리 굽는다
	if cur == null:
		vs = get_viewport_rect().size
		queue_redraw()
	if hub_test:
		_hub_test_step(dt)
	if shot_path != "" and t >= shot_at and shot_at > 0.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

# ==================== 자리 ====================
# 그리기와 클릭이 같은 함수를 본다.


## 가로 화면이면 카드 셋을 나란히 — 세로 카드(위 그림 · 아래 글). 세로 화면이면 위아래로 쌓은 가로 카드.
func wide() -> bool:
	return vs.x > vs.y


## **게임은 계속 늘어납니다**(사용자 11-09) — 한 쪽에 PER_PAGE 장, 넘치면 좌우 화살표로 쪽을 넘깁니다(게임 수에 안 묶임).
const PER_PAGE := 5


func _page() -> int:
	return sel / PER_PAGE


func _pages() -> int:
	return ceili(GAMES.size() / float(PER_PAGE))


## 지금 쪽에 없는 카드는 빈 사각형(눌리지 않음).
func _card(k: int) -> Rect2:
	if k / PER_PAGE != _page():
		return Rect2()
	var i := k % PER_PAGE
	var top := 290.0
	var gap := 26.0
	var n := float(mini(PER_PAGE, GAMES.size()))
	var margin := 140.0 if _pages() > 1 else 80.0   # 쪽이 여럿이면 양옆에 화살표 자리
	if wide():
		var w := minf(380.0, (vs.x - margin - gap * (n - 1.0)) / n)
		var h := minf(400.0, vs.y - top - 100.0)
		var x0 := vs.x * 0.5 - (w * n + gap * (n - 1.0)) * 0.5
		return Rect2(x0 + i * (w + gap), top, w, h)
	var h := minf(300.0, (vs.y - top - 140.0 - gap * (n - 1.0)) / n)
	return Rect2(40, top + i * (h + gap), vs.x - 80, h)


## 쪽 넘기기 화살표 — d = -1 왼쪽 · +1 오른쪽. 쪽이 하나면 빈 사각형.
func _arrow(d: int) -> Rect2:
	if _pages() <= 1:
		return Rect2()
	var c0 := _card(_page() * PER_PAGE)
	var y := c0.get_center().y - 44.0
	return Rect2(16.0, y, 46, 88) if d < 0 else Rect2(vs.x - 62.0, y, 46, 88)


func _turn(d: int) -> void:
	var p := posmod(_page() + d, _pages())
	sel = mini(p * PER_PAGE, GAMES.size() - 1)
	queue_redraw()


## 기준 캔버스를 창 방향에 맞춘다 — 가로면 1280×720, 세로면 720×1280. 짧은 변이 언제나 720 이라 글자 크기가
## 같게 보인다. 고정 1280×720 에 expand 만 두면 세로 폰에서 캔버스가 1280×2275 로 잡혀 전부 작아진다.
func _fit_canvas() -> void:
	var w := get_tree().root
	var s := w.size
	var want := Vector2i(1280, 720) if s.x >= s.y else Vector2i(720, 1280)
	if w.content_scale_size != want:
		w.content_scale_size = want


## 위 왼쪽 "음량" 단추 — 전체 · 효과음 · 배경음 창을 연다.
func _vol_btn() -> Rect2:
	return std_rect("vol", vs)

# ==================== 입력 ====================


func _unhandled_input(ev: InputEvent) -> void:
	if cur != null:
		return
	# 음량 창이 떠 있으면 그 창이 먼저 받는다
	if Vol.open:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				Vol.press(ev.position, vs)
			else:
				Vol.release()
		elif ev is InputEventMouseMotion:
			Vol.motion(ev.position, vs)
		elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			Vol.close()
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_UP, KEY_W, KEY_LEFT, KEY_A:
				sel = (sel + GAMES.size() - 1) % GAMES.size()
			KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
				sel = (sel + 1) % GAMES.size()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_open(sel)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				if key.keycode - KEY_1 < GAMES.size():
					_open(key.keycode - KEY_1)
			KEY_M:
				Vol.open = true
			KEY_ESCAPE:
				if not OS.has_feature("web"):
					get_tree().quit()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _vol_btn().has_point(mb.position):
			Vol.open = true
			return
		for d in [-1, 1]:
			if _arrow(d).has_point(mb.position):
				_turn(d)
				return
		for k in GAMES.size():
			if _card(k).has_point(mb.position):
				_open(k)
				return


# ==================== 그리기 ====================


func _draw() -> void:
	if cur != null:
		return
	var top := Color8(40, 30, 80)
	var bot := Color8(20, 60, 110)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([top, top, bot, bot]))
	# 배경 그림(hub_bg — art/jelly 에 있다) — 화면을 덮게 깔고 어둡게 눌러 카드가 떠 보이게
	var bg := Tex.art("hub_bg")
	if bg != null:
		var ts := bg.get_size()
		var k := maxf(vs.x / ts.x, vs.y / ts.y)
		draw_texture_rect_region(bg, Rect2(Vector2.ZERO, vs), Rect2((ts - vs / k) * 0.5, vs / k), Color(0.55, 0.55, 0.65))
	for k in 14:
		var p := Vector2(fposmod(k * 173.0 + t * (6 + k * 2), vs.x + 160) - 80,
				fposmod(k * 311.0 - t * (10 + k * 2), vs.y + 160) - 80)
		draw_circle(p, 20 + k * 7, Color(1, 1, 1, 0.04))

	UiKit.button(self, vs, "vol", "hub", t)

	var title := "미니게임"
	var f := UiKit.font()
	var size := 104.0
	var total := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	var x := vs.x * 0.5 - total * 0.5
	for k in title.length():
		var ch := title[k]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		var bob := absf(sin(t * 2.6 + k * 0.8)) * 14.0
		var c: Color = GAMES[k % GAMES.size()].col
		G2.text_mid(self, Vector2(x + w * 0.5, 165 - bob), ch, size, c.lightened(0.25), 22)
		x += w
	G2.text_mid(self, Vector2(vs.x * 0.5, 240), "하고 싶은 게임을 고르세요", 30, Color(1, 1, 1, 0.9), 7)

	for k in GAMES.size():
		if k / PER_PAGE == _page():
			_draw_card(k)
	if _pages() > 1:
		for d in [-1, 1]:
			var ar := _arrow(d)
			G2.panel(self, ar, Color(1, 1, 1, 0.16 if ar.has_point(get_local_mouse_position()) else 0.1), Color(1, 1, 1, 0.5), 2.0, 14)
			var c := ar.get_center()
			var tri := PackedVector2Array([c + Vector2(10 * d, 0), c + Vector2(-8 * d, -16), c + Vector2(-8 * d, 16)])
			draw_colored_polygon(tri, Color(1, 1, 1, 0.9))
		G2.text_mid(self, Vector2(vs.x * 0.5, vs.y - 60), "%d / %d 쪽   (좌우 화살표 또는 키)" % [_page() + 1, _pages()], 24, Color(1, 1, 1, 0.85), 5)
	else:
		G2.text_mid(self, Vector2(vs.x * 0.5, vs.y - 60), "언제든 각 게임의 처음 화면에서 돌아올 수 있어요",
				22, Color(1, 1, 1, 0.6), 0)
	Vol.draw(self, vs, t)


func _draw_card(k: int) -> void:
	var g: Dictionary = GAMES[k]
	var r := _card(k)
	var col: Color = g.col
	if k == sel:
		G2.panel(self, r.grow(8), Color(1, 1, 1, 0.3 + 0.15 * sin(t * 5.0)), Color(), 0.0, 34)
	G2.panel(self, r, col.darkened(0.55), P.INK, 4.0, 30)
	if wide():
		# 세로 카드 — 위 그림, 아래 글 셋(종류 · 이름 · 설명)을 가운데 맞춤
		var ps := minf(r.size.x - 60.0, r.size.y - 150.0)
		var pic2 := Rect2(r.position.x + (r.size.x - ps) * 0.5, r.position.y + 20, ps, ps)
		G2.panel(self, pic2, col.darkened(0.25), Color(1, 1, 1, 0.5), 3.0, 22)
		_preview(String(g.id), pic2)
		var mx := r.get_center().x
		var y := pic2.end.y + 26
		var tw := r.size.x - 24.0
		G2.text_mid(self, Vector2(mx, y), String(g.kind), 22, col.lightened(0.4), 5)
		# 카드가 다섯 장이 되면 폭이 220 남짓이라 긴 이름은 폭에 맞춰 줄이고, 설명은 두 줄로 접는다
		var ns := _fit(String(g.name), 44.0, tw)
		G2.text_mid(self, Vector2(mx, y + 44), String(g.name), ns, Color(1, 1, 1), ns * 0.2)
		var lines := _wrap2(String(g.note), 18.0, tw)
		for j in lines.size():
			G2.text_mid(self, Vector2(mx, y + 80 + j * 22 - (lines.size() - 1) * 4), lines[j], 18, Color(1, 1, 1, 0.75), 4)
		return
	G2.panel(self, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * 0.42)),
			Color(1, 1, 1, 0.07), Color(), 0.0, 24)
	# 왼쪽 그림 칸
	var pic := Rect2(r.position + Vector2(18, 18), Vector2(r.size.y - 36, r.size.y - 36))
	G2.panel(self, pic, col.darkened(0.25), Color(1, 1, 1, 0.5), 3.0, 22)
	_preview(String(g.id), pic)
	var tx := pic.end.x + 26
	var cy := r.position.y + r.size.y * 0.5
	_text_left(Vector2(tx, cy - r.size.y * 0.2), String(g.kind), 26, col.lightened(0.4))
	_text_left(Vector2(tx, cy + 6), String(g.name), 54, Color(1, 1, 1))
	_text_left(Vector2(tx, cy + r.size.y * 0.24), String(g.note), 22, Color(1, 1, 1, 0.75))


## 카드 왼쪽의 움직이는 그림. 게임마다 자기 그림 함수를 빌려 쓴다.
func _preview(id: String, pic: Rect2) -> void:
	var c := pic.get_center()
	var s := pic.size.x
	match id:
		"jelly":
			for k in 3:
				var hop := absf(sin(t * 3.4 + k * 0.9))
				var p := c + Vector2((k - 1) * s * 0.3, s * 0.12 - hop * s * 0.12)
				Art.jelly(self, p, s * 0.15, k * 2, D.SP_NONE, Art.Face.HAPPY, Vector2.ZERO,
						false, Vector2.ONE, 0.0, 0.0, t + k)
		"sky":
			_preview_sky(c, s)
		"neon":
			_preview_neon(c, s)
		"runner":
			_preview_runner(c, s)
		"gangho":
			_preview_gangho(pic)
		"arcana":
			_preview_arcana(c, s)


## 네온 서바이버 — 가운데 기체(육각) 둘레를 도는 칼날, 몰려오는 네온 도형. 그림 없이 도형만(리소스 0).
func _preview_neon(c: Vector2, s: float) -> void:
	draw_circle(c, s * 0.46, Color8(8, 10, 24))
	for k in 6:   # 격자 원
		draw_arc(c, s * (0.12 + k * 0.07), 0, TAU, 32, Color(0.3, 0.9, 1.0, 0.07), 1.0, true)
	for k in 9:   # 몰려오는 적
		var a := TAU * k / 9.0 + t * 0.25
		var d := s * (0.42 - fposmod(t * 0.08 + k * 0.11, 0.24))
		var p := c + Vector2(cos(a), sin(a)) * d
		var col: Color = [Color(1.0, 0.3, 0.6), Color(1.0, 0.8, 0.2), Color(0.5, 1.0, 0.4)][k % 3]
		var tri := PackedVector2Array([p + Vector2(cos(a + PI), sin(a + PI)) * s * 0.035,
				p + Vector2(cos(a + 2.4), sin(a + 2.4)) * s * 0.03, p + Vector2(cos(a - 2.4), sin(a - 2.4)) * s * 0.03])
		draw_colored_polygon(tri, Color(col, 0.9))
	for k in 3:   # 도는 칼날
		var a := t * 3.0 + TAU * k / 3.0
		draw_line(c + Vector2(cos(a), sin(a)) * s * 0.1, c + Vector2(cos(a), sin(a)) * s * 0.2, Color(0.4, 1.0, 1.0, 0.9), 4.0, true)
	var hexa := PackedVector2Array()
	for k in 6:
		hexa.append(c + Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0)) * s * 0.06)
	draw_colored_polygon(hexa, Color(0.35, 0.95, 1.0))
	draw_circle(c, s * 0.1, Color(0.3, 0.9, 1.0, 0.15))


func _preview_sky(c: Vector2, s: float) -> void:
	var card := SaArt.img("sky_card")
	if card != null:
		# 세로 그림의 가운데 정사각형만 — 칸 모서리가 둥글어서 조금 안쪽에 앉힌다
		var ts := card.get_size()
		var m := minf(ts.x, ts.y)
		var src := Rect2((ts.x - m) * 0.5, (ts.y - m) * 0.35, m, m)
		var inner := s - 12.0
		draw_texture_rect_region(card, Rect2(c - Vector2(inner, inner) * 0.5,
				Vector2(inner, inner)), src)
	var p := c + Vector2(sin(t * 1.6) * s * 0.18, s * 0.14)
	for k in 4:
		var y := fposmod(t * 160.0 + k * s * 0.1, s * 0.4)
		draw_line(p + Vector2(-6, -24 - y), p + Vector2(-6, -36 - y), Color(1, 1, 0.6, 0.8), 3.0)
		draw_line(p + Vector2(6, -24 - y), p + Vector2(6, -36 - y), Color(1, 1, 0.6, 0.8), 3.0)
	SaArt.craft(self, 0, p, t, s / 80.0)


func _preview_runner(c: Vector2, s: float) -> void:
	# 월드 러너의 그림 함수는 흔들림 변환(base)을 static 으로 들고 있다 — 남아 있던 값을 먼저 비운다.
	WrIcons.set_base(self, Transform2D.IDENTITY)
	# 키 아트(runner_card)가 있으면 바탕에 — 스카이 어설트 카드와 같은 방식(세로 그림의 가운데 정사각형)
	var card := WrIcons.art("runner_card")
	if card != null:
		var ts := card.get_size()
		var m := minf(ts.x, ts.y)
		var inner := s - 12.0
		draw_texture_rect_region(card, Rect2(c - Vector2(inner, inner) * 0.5, Vector2(inner, inner)),
				Rect2((ts.x - m) * 0.5, (ts.y - m) * 0.35, m, m))
	var a := int(t * 1.2) % 6 + 1
	var b := int(t * 1.2 + 3) % 6 + 1
	WrIcons.dice(self, c + Vector2(-s * 0.2, -s * 0.12), s * 0.32, a, sin(t * 2.0) * 0.2)
	WrIcons.dice(self, c + Vector2(s * 0.2, -s * 0.12), s * 0.32, b, -sin(t * 2.0) * 0.2)
	WrIcons.token(self, c.x, c.y + s * 0.26, s * 0.11, WrD.PLAYER_COLORS[0], 0.0, false, 1, t, 1.0, 0)


## 강호일생 — 표지 그림(gh_card)이 있으면 그것, 없으면 수묵 산수. 가운데에 붉은 낙관처럼 제목 한 자.
func _preview_gangho(pic: Rect2) -> void:
	var inner := pic.grow(-6)
	var card := GhArt.img("gh_card")
	if card != null:
		var ts := card.get_size()
		var m := minf(ts.x, ts.y)
		draw_texture_rect_region(card, inner, Rect2((ts.x - m) * 0.5, (ts.y - m) * 0.35, m, m))
		return
	GhArt.ink_landscape(self, inner, t, 3, "gh_card")
	var seal := Rect2(inner.get_center() - Vector2(34, 34), Vector2(68, 68))
	G2.panel(self, seal, GhD.RED, Color(), 0.0, 8)
	G2.text_mid(self, seal.get_center(), "강호", 26.0, Color(1, 0.94, 0.88), 0.0)


## 글자 크기 — 폭 w 안에 들어가게 줄인다(늘리지는 않음).
func _fit(s: String, size: float, w: float) -> float:
	var m := UiKit.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	return size if m <= w else floorf(size * w / m)


## 폭 w 를 넘으면 띄어쓰기에서 두 줄로 접는다(가운데에 가까운 띄어쓰기).
func _wrap2(s: String, size: float, w: float) -> Array:
	var f := UiKit.font()
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x <= w:
		return [s]
	var best := -1
	for i in s.length():
		if s[i] == " " and (best < 0 or absi(i - s.length() / 2) < absi(best - s.length() / 2)):
			best = i
	if best < 0:
		return [s]
	return [s.substr(0, best), s.substr(best + 1)]


## 아르카나 컬렉션 — 표지 그림(ac_card)이 있으면 그것, 없으면 성물 카드 한 장과 둘레를 도는 자원 다섯.
func _preview_arcana(c: Vector2, s: float) -> void:
	var card := AcArt.img("ac_card")
	if card != null:
		var ts := card.get_size()
		var m := minf(ts.x, ts.y)
		var inner := s - 12.0
		draw_texture_rect_region(card, Rect2(c - Vector2(inner, inner) * 0.5, Vector2(inner, inner)),
				Rect2((ts.x - m) * 0.5, (ts.y - m) * 0.35, m, m))
		return
	var cw := s * 0.38
	var col := int(t * 0.5) % AcD.N_COL
	var demo := {id = 0, tier = 2, col = col, pts = 4, cost = [0, 3, 0, 6, 3], glyph = "chalice",
			name = "%s의 성배" % AcD.COL_WORD[col], art = "ac_r_%d_chalice" % col}
	AcArt.card(self, Rect2(c - Vector2(cw, cw * 1.42) * 0.5, Vector2(cw, cw * 1.42)), demo, 0, t)
	for k in AcD.N_COL + 1:
		var a := t * 0.8 + TAU * k / 6.0
		AcArt.token(self, c + Vector2(cos(a) * s * 0.36, sin(a) * s * 0.3), s * 0.075, k)


func _text_left(pos: Vector2, s: String, size: float, c: Color) -> void:
	var f := UiKit.font()
	var at := pos + Vector2(0, size * 0.36)
	draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), int(size * 0.18), P.INK)
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


func _btn(r: Rect2, label: String, fill: Color, size: float) -> void:
	G2.panel(self, r, fill, P.INK, 4.0, minf(r.size.y * 0.4, 30.0))
	var light := fill.get_luminance() > 0.8
	G2.text_mid(self, r.get_center(), label, size, P.INK if light else Color(1, 1, 1),
			0.0 if light else size * 0.22)


## `--hub-test` — 젤리팝, 스카이 어설트, 월드 러너, 강호일생, 아르카나 컬렉션, 젤리팝, 아르카나 컬렉션을 차례로 열고 닫는다. 허브에 붙여 둔
## 소리 · 순위 노드가 다시 열 때 지운 노드를 가리키면 여기서 오류가 난다(stderr 를 보세요).
func _hub_test_step(dt: float) -> void:
	_ht += dt
	if _ht < 0.8:
		return
	_ht = 0.0
	var order := [0, 1, 2, 3, 4, 5, 0, 5]
	if _hs >= order.size() * 2:
		print("HUB TEST OK")
		get_tree().quit(0)
		return
	if _hs % 2 == 0:
		_open(order[_hs / 2])
		if cur == null:
			printerr("HUB TEST FAIL: 게임이 안 열림 " + str(order[_hs / 2]))
			get_tree().quit(1)
	else:
		Hub.leave(cur)
	_hs += 1
