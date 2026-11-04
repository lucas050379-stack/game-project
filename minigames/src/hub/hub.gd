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
var hub_test := false   ## --hub-test: 세 게임을 차례로 열고 닫고 다시 연다(되돌아올 때 깨지는 것 확인)
var _ht := 0.0
var _hs := 0


## 오래 사는 노드(소리 · 네트워크)를 붙일 곳. 허브 아래에서 열렸으면 허브, 아니면 자기 자신.
static func host(n: Node) -> Node:
	var p := n.get_parent()
	return p if p is Hub else n


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
	Bgm.use("jelly")
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
	Bgm.use("jelly")   # 허브는 젤리팝 곡 — 게임은 각자 _ready 에서 자기 곡을 고른다
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


func _card(k: int) -> Rect2:
	var top := 290.0
	var gap := 26.0
	if wide():
		var w := minf(380.0, (vs.x - 80.0 - gap * 2.0) / 3.0)
		var h := minf(400.0, vs.y - top - 100.0)
		var x0 := vs.x * 0.5 - (w * 3.0 + gap * 2.0) * 0.5
		return Rect2(x0 + k * (w + gap), top, w, h)
	var h := minf(300.0, (vs.y - top - 140.0 - gap * 2.0) / 3.0)
	return Rect2(40, top + k * (h + gap), vs.x - 80, h)


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
	return Rect2(18, 18, 170, 56)

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
			KEY_UP, KEY_W:
				sel = (sel + GAMES.size() - 1) % GAMES.size()
			KEY_DOWN, KEY_S:
				sel = (sel + 1) % GAMES.size()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_open(sel)
			KEY_1, KEY_2, KEY_3:
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
	for k in 14:
		var p := Vector2(fposmod(k * 173.0 + t * (6 + k * 2), vs.x + 160) - 80,
				fposmod(k * 311.0 - t * (10 + k * 2), vs.y + 160) - 80)
		draw_circle(p, 20 + k * 7, Color(1, 1, 1, 0.04))

	_btn(_vol_btn(), "음량", Color(1, 1, 1, 0.85), 28)

	var title := "미니게임"
	var f := P.font()
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
		_draw_card(k)
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
		G2.text_mid(self, Vector2(mx, y), String(g.kind), 22, col.lightened(0.4), 5)
		G2.text_mid(self, Vector2(mx, y + 44), String(g.name), 44, Color(1, 1, 1), 9)
		G2.text_mid(self, Vector2(mx, y + 86), String(g.note), 18, Color(1, 1, 1, 0.75), 4)
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
		"runner":
			_preview_runner(c, s)


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


func _text_left(pos: Vector2, s: String, size: float, c: Color) -> void:
	var f := P.font()
	var at := pos + Vector2(0, size * 0.36)
	draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), int(size * 0.18), P.INK)
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


func _btn(r: Rect2, label: String, fill: Color, size: float) -> void:
	G2.panel(self, r, fill, P.INK, 4.0, minf(r.size.y * 0.4, 30.0))
	var light := fill.get_luminance() > 0.8
	G2.text_mid(self, r.get_center(), label, size, P.INK if light else Color(1, 1, 1),
			0.0 if light else size * 0.22)


## `--hub-test` — 젤리팝 → 스카이 어설트 → 월드 러너 → 젤리팝을 열고 닫는다. 허브에 붙여 둔
## 소리 · 순위 노드가 다시 열 때 지운 노드를 가리키면 여기서 오류가 난다(stderr 를 보세요).
func _hub_test_step(dt: float) -> void:
	_ht += dt
	if _ht < 0.8:
		return
	_ht = 0.0
	var order := [0, 1, 2, 0, 2]
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
