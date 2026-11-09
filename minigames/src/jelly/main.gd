extends Node2D

## 진입점 — 화면 · 입력 · 움직임.
##
## 규칙은 전부 [Play](판 · 미션)와 [Board](칸)에 있다. 여기서는 그것을 **한 단계씩 불러
## 사이사이에 애니메이션을 끼운다**. 부르는 순서는 `Play.play_move()` 와 같아야 한다 —
## check.bat 의 봇이 그 함수로 난이도를 재기 때문이다.
##
## 레이어는 넷이다. 이 노드(바탕 · 칸 · 설탕막) → `board_layer`(젤리 · 장애물, 판 밖을 자른다)
## → `fx_layer`(가산 혼합 이펙트) → `top_layer`(HUD · 글자 · 창).
##
## **판은 언제나 논리상 최종 상태다.** 움직임은 칸마다 붙은 그림 상태(`vis`)가 "제자리에서
## 얼마나 벗어나 있나(`off`)"로 따라간다. 판에서 조각이 옮겨 가면 `vis` 도 같이 옮긴다.

enum Scr { TITLE, MAP, GAME, GUIDE, RANK, NAME }
enum St { INTRO, IDLE, SWAP, BACK, POP, FALL, TURN, SHUF, BONUS, WIN, LOSE, OVER }

const MAP_COLS := 5

var scr := Scr.TITLE
var st := St.IDLE
var state_t := 0.0
var play: Play
var stage_n := -1          ## 스테이지 번호(0부터). -1 = 타임 어택
var vis := []
var ghosts := []           ## 터지는 중인 젤리 {at: Vector2(칸), c, sp, t, power}
var fx := Fx.new()
var board_layer: Control   ## 판 밖(위에서 떨어지는 중)을 잘라 내는 레이어
var fx_layer: Node2D
var top_layer: Node2D

var t := 0.0
var time_left := D.GAME_T
var shown := 0.0
var combo := 0
var combo_t := 0.0
var fever := 0.0
var fever_t := 0.0
var idle_t := 0.0
var hint := PackedInt32Array()
var swap_a := -1
var swap_b := -1
var swap_ok := false
var turn_pending := false  ## 이번에 플레이어가 수를 뒀다 — 다 떨어지면 몬스터 · 초콜릿 차례
var bonus_fired := false
var turn_len := 0.45
var sel := -1
var press_cell := -1
var press_pos := Vector2.ZERO
var pressing := false
var new_best := false
var result_stars := 0
var win_left := -1         ## 깼을 때 남은 이동 — 보너스가 다 써 버리기 전에 적어 둔다(기록용)
var shuf_msg := 0.0
var twinkle_t := 0.0
var shake_off := Vector2.ZERO
var map_sel := 0
var title_sel := 0
var guide_page := 0
var guide_title := "장애물 도감"
var guide_list: Array = []   ## 도감에 지금 늘어놓은 것 — 전체이거나, 게임 중이면 이 판의 것만
var guide_open := false      ## 게임 중 장애물 창(판 위에 겹쳐 뜬다)
var info_at_start := false   ## --info: 시작하자마자 장애물 창(캡처용)
var guide_from := Scr.TITLE   ## 도감을 닫으면 돌아갈 화면
var guide_fresh := false      ## 장애물 창이 "새 장애물" 안내로 자동으로 떴다
var play_t0 := 0.0            ## 이 판을 시작한 시각(t) — 기록에 걸린 시간을 적는다
var rank_tab := 0             ## 순위 화면: 0 = 타임 어택, 1 = 모험 별
var name_edit: LineEdit       ## 데스크톱 이름 입력칸(웹은 브라우저 prompt)
var force_name := false       ## --name: 이름 화면부터(캡처용)
var force_net := false        ## --net: 확인용 실행에서도 순위 서버를 쓴다(캡처용 · 기록은 -dev 로 남는다)
var wipe_armed := 0.0         ## 테스트 빌드 "기록 지우기"를 한 번 눌렀다 — 이 시간 안에 한 번 더 누르면 지운다

# 레이아웃 — 매 프레임 `_lay()` 가 창 크기에서 다시 잡는다
var vs := Vector2(720, 1280)
var cs := 90.0
var origin := Vector2.ZERO

# 명령줄 (캡처 · 자동 진행 — 확인용)
var auto := false
var shot_path := ""
var shot_at := 0.0
var input_test := false
var ui_test := false
var _it_step := 0
var game_t := D.GAME_T
var moves_override := -1   ## --moves=N: 이동 수를 바꿔 결과 화면을 빨리 본다


func _ready() -> void:
	Sv.all_open = OS.has_feature("testbuild") or OS.get_cmdline_user_args().has("--unlock")
	Sv.no_save = not OS.get_cmdline_user_args().is_empty()
	Sv.load_()
	# 소리 · 순위 노드는 허브에 붙인다 — 이 화면은 게임을 고를 때마다 새로 만들어지고 지워진다.
	Snd.init(Hub.host(self))
	Bgm.init(Hub.host(self))
	Bgm.use("jelly")
	Sv.ensure_uid()
	# _draw() 에는 클리핑이 없다. 위에서 떨어져 들어오는 젤리가 HUD 위로 그려지지 않게
	# clip_contents 를 켠 Control 안에서 그린다. 마우스는 통과시켜야 한다 —
	# 기본값(STOP)이면 판 위 클릭을 이 노드가 삼켜 _unhandled_input 까지 안 온다.
	board_layer = Control.new()
	board_layer.clip_contents = true
	board_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_layer)
	board_layer.draw.connect(_draw_board)
	fx_layer = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx_layer.material = m
	add_child(fx_layer)
	fx_layer.draw.connect(_draw_fx)
	top_layer = Node2D.new()
	add_child(top_layer)
	top_layer.draw.connect(_draw_top)

	var start := ""
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
			if start == "":
				start = "ta"
		elif a == "--play" or a == "--sp-demo":
			start = "ta"
		elif a == "--input-test":
			input_test = true
			start = "ta"
		elif a == "--ui-test":
			ui_test = true
		elif a == "--map":
			scr = Scr.MAP
		elif a == "--name":
			force_name = true
		elif a == "--net":
			force_net = true
		elif a == "--info":
			info_at_start = true
		elif a.begins_with("--good="):
			_open_specials()
			guide_page = int(a.substr(7)) - 1
		elif a.begins_with("--guide="):
			scr = Scr.GUIDE
			guide_list = Guide.entries()
			guide_page = int(a.substr(8)) - 1
		elif a.begins_with("--stage="):
			start = a.substr(8)
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--moves="):
			moves_override = int(a.substr(8))
		elif a.begins_with("--time="):
			game_t = float(a.substr(7))
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
	# 확인용 실행 · 테스트 빌드의 기록은 순위 · 난이도 통계를 더럽히므로 보내지 않는다
	var checking := auto or input_test or ui_test or shot_path != "" or moves_override > 0
	Net.init(Hub.host(self), force_net or (not Sv.all_open and not checking))
	# 처음 켰으면 이름부터 — 확인용 실행 · 바로 시작하는 인자가 있으면 건너뛴다
	if force_name or (not Sv.named and not checking and start == "" and scr == Scr.TITLE):
		scr = Scr.NAME
		if not OS.has_feature("web"):
			_ask_name.call_deferred()   # 웹은 단추를 누를 때 — 첫 화면이 뜨기도 전에 입력창부터 막아서면 어색하다
	if start == "ta":
		_start_ta()
	elif start != "":
		_start_stage(int(start) - 1)
		if info_at_start:
			_open_info()
		if auto:
			st = St.FALL
	if OS.get_cmdline_user_args().has("--sp-demo"):
		# 확인용 — 특수 젤리 다섯 종을 판에 깔아 둔다
		for k in 5:
			play.b.sp[15 + k] = D.SP_LINE_H + k
		play.b.col[18] = Board.RAINBOW_C

# ==================== 레이아웃 ====================

func _bw() -> int:
	return play.b.w if play != null else D.W


func _bh() -> int:
	return play.b.h if play != null else D.H


## 가로 화면 — 판을 가운데 높이 가득, 정보(이동 · 미션 · 점수 · 별)는 좌우 SIDE 폭 정보창으로(사용자 결정 11-04).
func wide() -> bool:
	return vs.x > vs.y


const SIDE := 300.0

func _lay() -> void:
	vs = get_viewport_rect().size
	if wide():
		cs = minf((vs.x - SIDE * 2.0) / _bw(), (vs.y - 90.0) / _bh())
		origin = Vector2((vs.x - cs * _bw()) * 0.5, (vs.y - cs * _bh()) * 0.5 + 10.0)
		return
	cs = minf((vs.x - 36.0) / _bw(), vs.y * 0.56 / _bh())
	origin = Vector2((vs.x - cs * _bw()) * 0.5, maxf(vs.y * 0.25, 240.0))


## 가로 화면 좌우 정보창. 0 왼쪽 · 1 오른쪽.
func _side_rect(k: int) -> Rect2:
	var x := 16.0 if k == 0 else vs.x - SIDE + 16.0
	return Rect2(x, 84, SIDE - 32.0, vs.y - 104)


func _board_rect() -> Rect2:
	return Rect2(origin, Vector2(_bw(), _bh()) * cs)


## 벨트 고리마다 칸 중심 좌표를 흐르는 순서대로(닫힌 고리 — 첫 점으로 돌아오지 않음).
## 칸마다 따로 그리면 칸 사이가 끊기고 꺾이는 칸에서 그림이 90° 툭 돌아서, 고리 하나를 이어진 띠로 그린다.
func _belt_loops() -> Array:
	var b := play.b
	var seen := {}
	var loops := []
	var step := [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for s in b.w * b.h:
		if b.belt[s] <= 0 or b.hole[s] or seen.has(s):
			continue
		var pts := PackedVector2Array()
		var i := s
		while not seen.has(i) and b.belt[i] > 0:
			seen[i] = true
			pts.append(origin + shake_off + (_cell_xy(i) + Vector2(0.5, 0.5)) * cs)
			var d: Vector2i = step[b.belt[i]]
			var nx := i % b.w + d.x
			var ny := i / b.w + d.y
			if nx < 0 or ny < 0 or nx >= b.w or ny >= b.h:
				break
			i = ny * b.w + nx
		if pts.size() >= 3:
			loops.append(pts)
	return loops


## 칸 좌표(실수) → 화면 중심. 흔들림이 섞여 있다 — 클릭 판정에는 `_cell_at` 을 쓴다.
func _gp(at: Vector2) -> Vector2:
	return origin + shake_off + (at + Vector2(0.5, 0.5)) * cs


func _cell_xy(i: int) -> Vector2:
	return Vector2(i % _bw(), i / _bw())


func _cell_at(p: Vector2) -> int:
	var l := (p - origin) / cs
	if l.x < 0 or l.y < 0 or l.x >= _bw() or l.y >= _bh():
		return -1
	var i := int(l.y) * _bw() + int(l.x)
	return -1 if play.b.hole[i] else i


## 결과 창 단추. 0 = 주 단추(다음 · 다시), 1 = 다시(이겼을 때만), 2 = 목록.
func _panel_btn(k: int) -> Rect2:
	var y := vs.y * 0.5 + 150
	if _rank_box():
		y = _result_rect().position.y + (450 if wide() else 710)
	var cx := _res_cx()
	match k:
		0:
			return Rect2(cx - 150, y, 300, 80)
		1:
			return Rect2(cx - 150, y + 96, 140, 64)
	# "다시"가 없으면(졌을 때 · 타임 어택) 목록이 가운데로 온다
	if st != St.WIN:
		return Rect2(cx - 70, y + 96, 140, 64)
	return Rect2(cx + 10, y + 96, 140, 64)


## 결과 창 글 · 단추의 가운데 x — 가로 화면에서 순위가 오른쪽에 붙으면 왼쪽 몫의 가운데.
func _res_cx() -> float:
	if _rank_box() and wide():
		return _result_rect().position.x + 280
	return vs.x * 0.5


## 스테이지를 깼고 순위 서버가 있으면 결과 창 안에 그 판 순위를 넣는다(창이 길어진다).
func _rank_box() -> bool:
	return st == St.WIN and not _ta() and Net.enabled


## 결과 창. 그리기와 단추 자리(_panel_btn)가 같이 본다.
func _result_rect() -> Rect2:
	if _rank_box():
		if wide():
			# 가로 화면 — 높이가 모자라서 순위를 아래가 아니라 오른쪽에 둔다
			return Rect2(vs.x * 0.5 - 520, vs.y * 0.5 - 330, 1040, 660)
		return Rect2(vs.x * 0.5 - 280, vs.y * 0.5 - 470, 560, 940)
	return Rect2(vs.x * 0.5 - 280, vs.y * 0.5 - 300 if wide() else vs.y * 0.5 - 280, 560, 640)


func _back_rect() -> Rect2:
	return Rect2(18, 18, 112, 52)


const TITLE_N := 5

## 처음 화면 단추. 0(모험 = 시작)은 다섯 게임 같은 자리(오른쪽 아래 · `Hub.std_rect`), 나머지는 세로 줄.
func _title_btn(k: int) -> Rect2:
	if k == 0:
		return Hub.std_rect("start", vs)
	# 나머지는 오른쪽 메뉴 줄 — 다섯 게임 같은 크기 · 간격(UiKit.menu_rect)
	return UiKit.menu_rect(vs, k - 1)


## 처음 화면 제목 · 젤리 줄의 가운데 x.
func _title_x() -> float:
	return vs.x * 0.3 if wide() else vs.x * 0.5


## 처음 화면 위쪽 소리 단추. 0 = 음악, 1 = 효과음.
## 테스트 빌드 처음 화면 맨 아래 — 점수 기록 지우기. 정식판에는 없다.
func _wipe_btn() -> Rect2:
	if not Sv.all_open:
		return Rect2()
	return Rect2(vs.x * 0.5 - 150, vs.y - 86, 300, 60)


## 기록 지우기 — 되돌릴 수 없으니 한 번 더 눌러야 지운다(3초 안에).
func _wipe_press() -> void:
	if wipe_armed > 0.0:
		wipe_armed = 0.0
		Sv.wipe_records()
		Snd.play("bad")
		fx.text(Vector2(vs.x * 0.5, vs.y * 0.45), "기록을 지웠어요", 50, P.WARN, 12, 1.4)
	else:
		wipe_armed = 3.0


## 0 = "음량" 단추(전체 · 효과음 · 배경음 창을 연다 — `Vol`). 1 은 예전 효과음 단추 자리로, 지금은 없다.
func _sound_btn(k: int) -> Rect2:
	return Hub.std_rect("vol", vs) if k == 0 else Rect2()


## 처음 화면 왼쪽 위 — 미니게임 고르는 화면으로(다섯 게임 같은 자리).
func _hub_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


## 순위 화면: 0 · 1 = 탭, 2 = 이름 바꾸기
func _rank_btn(k: int) -> Rect2:
	if k < 2:
		return Rect2(vs.x * 0.5 - 250 + k * 255, 170, 245, 64)
	return Rect2(vs.x * 0.5 - 130, vs.y - 120, 260, 64)


func _rank_row(k: int) -> Rect2:
	if wide():
		# 가로 화면 — 두 단, 한 단에 RANK_COL 줄
		var cw := (vs.x - 120.0) * 0.5
		return Rect2(40 + (k / RANK_COL) * (cw + 40), 252 + (k % RANK_COL) * 42, cw, 38)
	return Rect2(40, 260 + k * 42, vs.x - 80, 38)


const RANK_COL := 7


## 순위 화면에 보이는 줄 수.
func _rank_rows() -> int:
	return RANK_COL * 2 if wide() else 18


## 모험 목록 오른쪽 위의 도감 단추 — 장애물을 처음 만나는 곳이 여기라서 시작 화면 말고도 둔다.
func _guide_btn() -> Rect2:
	return Rect2(vs.x - 130, 18, 112, 52)


## 도감 한 줄의 자리. 그리기와 (나중의) 클릭이 같이 본다.
func _guide_row(k: int) -> Rect2:
	if wide():
		# 가로 화면 — 두 단으로(한 단에 일곱 줄을 다 넣으면 줄마다 설명이 안 들어간다)
		var per := ceili(Guide.PER_PAGE / 2.0)
		var hw := minf(124.0, (vs.y - 190.0 - 140.0) / per)
		var cw := (vs.x - 72.0) * 0.5
		return Rect2(24 + (k / per) * (cw + 24), 190 + (k % per) * hw, cw, hw - 8)
	var h := minf(124.0, (vs.y - 380) / Guide.PER_PAGE)
	return Rect2(24, 200 + k * h, vs.x - 48, h - 10)


## 스테이지 목록은 쪽마다 MAP_PAGE 개 — 다섯 줄 × 다섯 칸, **한 줄이 장애물 하나의 5판 블록**(StageGen.BLOCK).
## MAP_COLS 와 BLOCK 이 같아야 줄과 블록이 맞는다.
const MAP_PAGE := 25


## 쪽 제목 — 그 쪽에서 처음 나오는 장애물의 첫 이름 ~ 끝 이름
func _page_name(pg: int) -> String:
	var names := []
	for n in range(pg * MAP_PAGE, mini((pg + 1) * MAP_PAGE, Stages.count()), StageGen.BLOCK):
		var key := StageGen.intro_of(n + 1)
		if key == "":
			names.append("마무리")
		else:
			for e in Guide.ENTRIES:
				if e.key == key:
					names.append(e.name)
	if names.is_empty():
		return ""
	return names[0] if names.size() == 1 else "%s ~ %s" % [names[0], names[-1]]


func _map_page() -> int:
	return map_sel / MAP_PAGE


## n 번 스테이지 단추 자리. 지금 쪽에 없는 번호는 빈 사각형.
func _map_rect(n: int) -> Rect2:
	if n / MAP_PAGE != _map_page():
		return Rect2()
	var k := n % MAP_PAGE
	var rows := ceilf(MAP_PAGE / float(MAP_COLS))
	if wide():
		# 가로 화면 — 높이가 모자라서 칸 크기를 줄 높이에서 거꾸로 낸다(가로로 넓게 벌리면 줄끼리 겹친다)
		var rh := (vs.y - 210.0 - 150.0) / rows
		var h := rh - 10.0
		var w := h / 0.82
		var gx := w * 0.6
		var x0 := (vs.x - (w * MAP_COLS + gx * (MAP_COLS - 1))) * 0.5
		return Rect2(x0 + (k % MAP_COLS) * (w + gx), 210 + (k / MAP_COLS) * rh, w, h)
	var sz := minf(vs.x / (MAP_COLS + 1.2), 108.0)
	var gap := (vs.x - sz * MAP_COLS) / (MAP_COLS + 1)
	var row_h := minf(sz * 1.3, (vs.y - 380) / rows)
	return Rect2(gap + (k % MAP_COLS) * (sz + gap), 210 + (k / MAP_COLS) * row_h, sz, sz * 0.82)


## 쪽 넘김 단추 — 0 앞쪽, 1 뒤쪽.
func _page_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 + (-230 if k == 0 else 130), vs.y - 130, 100, 80)


func _pages() -> int:
	return int(ceil(Stages.count() / float(MAP_PAGE)))

# ==================== 칸 그림 상태 ====================

func _new_vis() -> Dictionary:
	var a := randf() * TAU
	return {"off": Vector2.ZERO, "vy": 0.0, "falling": false, "land": 0.0, "born": 0.0, "sad": 0.0,
			"hurt": 0.0, "fly": Vector2.ZERO, "phase": randf() * TAU,
			"blink": t + randf_range(D.BLINK_GAP.x, D.BLINK_GAP.y), "look": Vector2(cos(a), sin(a)) * randf()}


func _reset_vis() -> void:
	vis.resize(_bw() * _bh())
	for i in vis.size():
		vis[i] = _new_vis()


func _move_vis(from: int, to: int) -> void:
	vis[to] = vis[from]
	vis[from] = _new_vis()


func _swap_vis(a: int, c: int) -> void:
	var tmp = vis[a]
	vis[a] = vis[c]
	vis[c] = tmp

# ==================== 흐름 ====================

func _begin(stdef: Dictionary) -> void:
	play = Play.new(stdef)
	_lay()
	_reset_vis()
	# 판 위에서 줄줄이 떨어져 들어온다 — 아래 줄부터. 움직이는 조각만.
	for i in vis.size():
		if play.b.falls(i):
			vis[i].off.y = -float(_bh() + 1) - (_bh() - 1 - i / _bw()) * 0.35 - randf() * 0.3
			vis[i].falling = true
	scr = Scr.GAME
	state_t = 0.0
	shown = 0.0
	combo = 0
	combo_t = 0.0
	fever = 0.0
	fever_t = 0.0
	idle_t = 0.0
	hint = PackedInt32Array()
	sel = -1
	turn_pending = false
	bonus_fired = false
	ghosts.clear()
	fx.clear()
	new_best = false
	play_t0 = t
	win_left = -1
	Snd.play("start")


func _start_ta() -> void:
	stage_n = -1
	_begin(Stages.time_attack())
	time_left = game_t
	st = St.FALL


func _start_stage(n: int) -> void:
	stage_n = clampi(n, 0, Stages.count() - 1)
	map_sel = stage_n
	var stdef := Stages.get_stage(stage_n)
	if moves_override > 0:
		stdef = stdef.duplicate()
		stdef.moves = moves_override
	_begin(stdef)
	st = St.INTRO
	var id := int(play.stage.id)
	Sv.tries[id] = int(Sv.tries.get(id, 0)) + 1
	Net.prefetch_stage(id)   # 깼을 때 결과 창에 바로 띄우려고 미리 받는다
	# 이 판에서 처음 나오는 장애물이면 설명을 먼저 띄운다 — 시작 창 한 줄로는 뭔지 모른다.
	# 한 번 본 장애물은 다시 안 띄운다(다시 하기마다 뜨면 귀찮다).
	var fresh := Guide.in_stage(play.stage).filter(func(e): return Guide.first(e.key) == id and not Sv.seen.has(e.key))
	if not fresh.is_empty() and not auto:
		for e in fresh:
			Sv.seen[e.key] = true
		guide_list = fresh
		guide_page = 0
		guide_open = true
		guide_fresh = true
	Sv.save_()


func _leave() -> void:
	# 판 도중에 나가면 "포기"로 적는다 — 어려워서 그만둔 판을 찾는 데 쓴다. 한 수도 안 뒀으면 안 적는다.
	if scr == Scr.GAME and not _ta() and st != St.WIN and st != St.LOSE and play.swaps > 0:
		_log_stage("quit")
	scr = Scr.MAP if stage_n >= 0 else Scr.TITLE
	fx.clear()
	ghosts.clear()


func _playing() -> bool:
	return scr == Scr.GAME and st != St.INTRO and st != St.WIN and st != St.LOSE and st != St.OVER


func _ta() -> bool:
	return stage_n < 0


## 타임 어택은 터질 때마다 콤보 · 피버를 배율로 넣는다. 스테이지 모드는 연쇄 배율만(Play 안).
func _pre_step() -> void:
	if not _ta():
		play.mul = 1.0
		return
	combo += 1
	combo_t = D.COMBO_KEEP
	play.mul = (1.0 + combo * D.COMBO_STEP) * (D.FEVER_MUL if fever_t > 0.0 else 1)


func _try_swap(a: int, c: int) -> void:
	if st != St.IDLE or a < 0 or c < 0 or not play.b.adjacent(a, c):
		return
	if _ta() and time_left <= 0.0:
		return
	if not play.b.movable(a) or not play.b.movable(c):
		for k in [a, c]:
			if play.b.is_jelly(k):
				vis[k].sad = 1.0
		Snd.play("bad")
		return
	swap_a = a
	swap_b = c
	swap_ok = play.can_swap(a, c)
	st = St.SWAP
	state_t = 0.0
	sel = -1
	hint = PackedInt32Array()
	idle_t = 0.0
	Snd.play("swap")


func _after_swap() -> void:
	if not swap_ok:
		# 안 맞으면 되돌아간다 — 같은 애니메이션을 한 번 더
		st = St.BACK
		state_t = 0.0
		vis[swap_a].sad = 1.0
		vis[swap_b].sad = 1.0
		Snd.play("bad")
		return
	_pre_step()
	turn_pending = not _ta()
	# 무지개를 바꿨으면 터지기 전에 그 색 칸을 기억해 둔다(광선을 이을 자리)
	var b := play.b
	var color := -1
	var rb := -1
	if b.sp[swap_a] == D.SP_RAINBOW or b.sp[swap_b] == D.SP_RAINBOW:
		rb = swap_a if b.sp[swap_a] == D.SP_RAINBOW else swap_b
		var o := swap_b if rb == swap_a else swap_a
		color = b.col[o] if b.sp[o] != D.SP_RAINBOW else -1
	var targets := []
	if color >= 0:
		for i in b.cells_of(color):
			targets.append(_gp(_cell_xy(i)))
	# vis 는 이미 바꿔 놓았다. 판은 Play.begin 이 바꾼다 — 바뀐 뒤 무지개는 반대쪽 칸에 있다
	var r := play.begin(swap_a, swap_b)
	if rb >= 0:
		var at := swap_b if rb == swap_a else swap_a
		fx.links(_gp(_cell_xy(at)), targets, P.jelly(color) if color >= 0 and color < D.COLORS else Color(1, 1, 1), cs)
		Snd.play("rainbow")
	_show(r)


## 판이 Play 에서 한 번 터졌다 — 그 결과로 그림 · 이펙트 · 소리를 낸다.
func _show(r: Dictionary) -> void:
	var power := 1.0 + minf(play.chain - 1 + combo * 0.2, 6.0) * 0.12
	var n: int = r.cleared.size()

	# 날개가 친 칸은 날개가 도착한 뒤에 터진다
	var late := {}
	for f in r.fired:
		if int(f.sp) == D.SP_FLY:
			for k in f.hit:
				late[k] = true
	var mid := Vector2.ZERO
	for e in r.cleared:
		var at := _cell_xy(e.i)
		mid += at
		ghosts.append({"at": at, "c": e.c, "sp": e.sp, "t": -0.25 if late.has(e.i) else 0.0, "power": power})
	if n > 0:
		mid /= n
	else:
		mid = Vector2(_bw() - 1, _bh() - 1) * 0.5
	for c in r.get("painted", PackedInt32Array()):
		fx.sugar(_gp(_cell_xy(c)), cs)
	if int(r.get("gift_moves", 0)) > 0:
		fx.text(Vector2(78, origin.y - 160), "+%d" % int(r.gift_moves), 40, P.GOLD, 40, 1.0)
	if int(r.points) > 0:
		fx.text(_gp(mid), "+" + P.n(r.points), 30 + minf(n, 20) * 1.2, Color(1, 1, 1))
	if _ta() and combo >= 2:
		fx.text(_gp(Vector2((_bw() - 1) * 0.5, 0.6)), "콤보 %d" % combo, 40 + minf(combo, 15) * 1.5, P.GOLD, 30, 0.7)
	elif not _ta() and play.chain >= 2:
		fx.text(_gp(Vector2((_bw() - 1) * 0.5, 0.6)), "연쇄 %d" % play.chain, 40 + minf(play.chain, 10) * 2.0,
				P.GOLD, 30, 0.7)
	if n > 0:
		Snd.play("pop", 1.0 + minf(maxi(combo, play.chain), 14) * 0.055)

	var cb: String = r.get("combo", "")
	if cb != "":
		_combo_fx(cb, int(r.at))
	for f in r.fired:
		var p := _gp(_cell_xy(f.i))
		var c: Color = P.jelly(f.c)
		match int(f.sp):
			D.SP_LINE_H:
				var y := float(f.i / _bw())
				fx.beam(_gp(Vector2(0, y)), _gp(Vector2(_bw() - 1, y)), c, cs)
				Snd.play("line")
			D.SP_LINE_V:
				var x := float(f.i % _bw())
				fx.beam(_gp(Vector2(x, 0)), _gp(Vector2(x, _bh() - 1)), c, cs)
				Snd.play("line")
			D.SP_AREA:
				fx.shock(p, c, cs, cs * (D.AREA_R + 0.5))
				Snd.play("boom")
			D.SP_RAINBOW:
				var targets := []
				for k in f.hit:
					targets.append(_gp(_cell_xy(k)))
				fx.links(p, targets, Color(1, 1, 1), cs)
				Snd.play("rainbow")
			D.SP_FLY:
				fx.fly(p, _gp(_cell_xy(f.to)), cs)
				Snd.play("fly")

	for mk in r.made:
		var to := _gp(_cell_xy(mk.i))
		var froms := []
		for e in r.cleared:
			if e.c == mk.c or mk.sp == D.SP_RAINBOW:
				var at := _cell_xy(e.i)
				if at.distance_to(_cell_xy(mk.i)) <= 4.0:
					froms.append(_gp(at))
		vis[mk.i] = _new_vis()
		vis[mk.i].born = 1.0
		fx.merge(to, froms, P.jelly(mk.c), cs)
		Snd.play("make")

	for ev in r.events:
		var i: int = ev.i
		var p := _gp(_cell_xy(i))
		match String(ev.type):
			"box":
				fx.crumbs(p, D.COOKIE[clampi(int(ev.left), 0, 2)], cs, int(ev.left) <= 0)
				vis[i].hurt = 1.0
				Snd.play("box")
			"choco":
				fx.crumbs(p, D.CHOCO_C, cs, true)
				Snd.play("box", 0.8)
			"ice":
				fx.crumbs(p, D.ICE_C, cs, int(ev.left) <= 0)
				Snd.play("ice")
			"chain":
				fx.crumbs(p, D.CHAIN_C, cs, true)
				Snd.play("chain")
			"sugar":
				fx.sugar(p, cs)
			"capsule":
				fx.crumbs(p, D.CAPSULE_C, cs, true)
				Snd.play("ice", 0.8)
			"cloud":
				fx.crumbs(p, D.CLOUD_C, cs, true)
			"glass":
				fx.crumbs(p, Color8(220, 240, 255), cs, true)
				Snd.play("ice", 1.3)
			"decoy":
				fx.crumbs(p, Color8(110, 80, 150), cs, true)
			"web":
				fx.crumbs(p, D.WEB_C, cs, int(ev.left) <= 0)
				Snd.play("chain", 0.7)
			"plant":
				fx.shock(p, Color8(150, 210, 90), cs, cs * 1.5)
				for c in ev.cells:
					fx.curse(p, _gp(_cell_xy(c)), D.WEB_C, cs)
			"mole":
				vis[i].hurt = 1.0
				fx.text(p, "앗!", 32, P.WARN, 40, 0.6)
			"mole_dead":
				fx.shock(p, Color8(150, 105, 75), cs, cs)
				fx.text(p, "잡았다!", 36, P.GOLD, 50, 0.9)
				Snd.play("collect")
			"fire":
				fx.pop(p, D.FIRE_C, cs, 0.8)
				Snd.play("make", 0.8)
			"jar":
				vis[i].hurt = 0.6
			"jar_full":
				fx.shock(p, D.LOCK_C, cs, cs)
				fx.text(p, "가득!", 36, P.GOLD, 50, 0.9)
				Snd.play("collect")
			"lock":
				vis[i].hurt = 1.0
			"lock_open":
				fx.shock(p, D.LOCK_C, cs, cs)
				fx.text(p, "열렸다!", 36, P.GOLD, 50, 0.9)
				Snd.play("collect")
			"gift":
				fx.shock(p, D.GIFT_C, cs, cs)
				var what: String = ev.what
				var label: String = {"special": "특수 젤리!", "moves": "이동 +1", "box": "꽝!"}[what]
				fx.text(p, label, 36, P.WARN if what == "box" else P.GOLD, 60, 1.0)
				Snd.play("bad" if what == "box" else "collect")
			"charge":
				vis[i].hurt = 0.6
				fx.text(p - Vector2(0, cs * 0.45), "%d/%d" % [int(ev.n), Board.LASER_FULL], 28, Color8(255, 120, 150), 40, 0.6)
			"mon":
				vis[i].hurt = 1.0
				fx.text(p - Vector2(0, cs * 0.4), "-%d" % int(ev.dmg), 34, P.WARN, 50, 0.7)
				Snd.play("mon")
			"mon_dead":
				fx.shock(p, Color8(255, 200, 120), cs, cs * 1.2)
				fx.text(p, "쓰러뜨렸다!", 40, P.GOLD, 60, 1.0)
				Snd.play("boom", 1.3)

	if _ta() and fever_t <= 0.0:
		fever = minf(1.0, fever + n * D.FEVER_PER_BLOCK)
		if fever >= 1.0:
			fever_t = D.FEVER_T
			fx.confetti(vs, 50)
			fx.text(Vector2(vs.x * 0.5, vs.y * 0.45), "피버!", 96, P.FEVER, 40, 1.2)
			Snd.play("fever")
	st = St.POP
	state_t = 0.0
	hint = PackedInt32Array()
	idle_t = 0.0


## 특수끼리 합쳤을 때 — 각자 터지는 대신 한 번에 크게.
func _combo_fx(kind: String, at: int) -> void:
	var p := _gp(_cell_xy(at))
	var xy := _cell_xy(at)
	match kind:
		"cross":
			fx.beam(_gp(Vector2(0, xy.y)), _gp(Vector2(_bw() - 1, xy.y)), Color(1, 1, 1), cs)
			fx.beam(_gp(Vector2(xy.x, 0)), _gp(Vector2(xy.x, _bh() - 1)), Color(1, 1, 1), cs)
			Snd.play("line", 0.8)
		"bigcross":
			for d in [-1, 0, 1]:
				fx.beam(_gp(Vector2(0, xy.y + d)), _gp(Vector2(_bw() - 1, xy.y + d)), P.GOLD, cs)
				fx.beam(_gp(Vector2(xy.x + d, 0)), _gp(Vector2(xy.x + d, _bh() - 1)), P.GOLD, cs)
			fx.shock(p, P.GOLD, cs, cs * 1.5)
			Snd.play("boom")
		"big":
			fx.shock(p, Color8(255, 180, 90), cs, cs * (D.BIG_R + 0.5))
			fx.shake_add(D.SHAKE_RAINBOW)
			Snd.play("boom", 0.8)
		"rainbow2":
			fx.confetti(vs, 40)
			fx.shake_add(D.SHAKE_RAINBOW * 1.4)
			Snd.play("rainbow", 0.8)
	var names := {"cross": "십자!", "bigcross": "대십자!", "big": "대폭발!", "rainbow2": "전부!",
			"rainbow_sp": "변신!", "fly2": "날개 셋!", "fly_carry": "배달!"}
	fx.text(p, names.get(kind, ""), 44, P.GOLD, 50, 0.9)


func _do_fall() -> void:
	var b := play.b
	var f := play.fall()
	for mv in f.moves:
		var from: int = mv.from
		var to: int = mv.to
		var was: Vector2 = _cell_xy(from) + vis[from].off
		_move_vis(from, to)
		vis[to].off = was - _cell_xy(to)
		if vis[to].off.length() > 1.6:
			vis[to].off = Vector2(0, -1)   # 포탈을 지났다 — 출구 위에서 나온다
		vis[to].falling = true
	for s in f.spawns:
		var to: int = s.to
		vis[to] = _new_vis()
		vis[to].off = Vector2(0, float(b.top_row(to % _bw()) - int(s.n) - to / _bw()))
		vis[to].falling = true
	st = St.FALL
	state_t = 0.0


func _after_fall() -> void:
	var got := play.collect()
	if not got.is_empty():
		for i in got:
			var p := _gp(_cell_xy(i))
			fx.pop(p, D.FRUIT_C, cs, 1.4)
			fx.text(p, "열매!", 40, P.GOLD, 70, 1.0)
		Snd.play("collect")
		_do_fall()
		return
	if not play.b.find_groups().is_empty():
		_pre_step()
		_show(play.cascade())
		return
	_settled()


## 더 터질 것이 없다. 이겼나 · 졌나 · 아니면 몬스터 · 초콜릿 차례.
func _settled() -> void:
	if _ta():
		if not play.b.has_move():
			_shuffle()
			return
		st = St.IDLE
		if time_left <= 0.0:
			_game_over()
		return
	if bonus_fired:
		_finish(true)
		return
	if play.won():
		turn_pending = false
		if win_left < 0:
			win_left = play.moves_left
		if play.moves_left > 0:
			st = St.BONUS
			state_t = 0.0
			fx.text(Vector2(vs.x * 0.5, vs.y * 0.45), "보너스!", 90, P.GOLD, 40, 1.2)
			Snd.play("fever")
		else:
			_finish(true)
		return
	if play.lost():
		_finish(false)
		return
	if turn_pending:
		turn_pending = false
		var res := play.turn_end()
		var ev: Array = res.events
		_apply_perm(res.moves)
		for s in res.shots:
			_shot_fx(s)
		for i in res.dice:
			vis[i].born = 0.6
		for pf in res.puffs:
			fx.curse(_gp(_cell_xy(pf.i)), _gp(_cell_xy(pf.to)), D.CLOUD_C, cs)
		for e in ev:
			if e.type == "web_grow":
				fx.crumbs(_gp(_cell_xy(e.i)), D.WEB_C, cs)
				continue
			if e.type == "fire_out":
				fx.crumbs(_gp(_cell_xy(e.i)), Color8(120, 120, 130), cs)
				continue
			if e.type == "eat":
				fx.curse(_gp(_cell_xy(e.to)), _gp(_cell_xy(e.i)), Color8(255, 170, 90), cs)
				fx.text(_gp(_cell_xy(e.i)), "윽!" if e.bad else "냠!", 34, P.WARN if e.bad else P.GOLD, 50, 0.8)
				continue
			if e.type == "steal":
				var p := _gp(_cell_xy(e.i))
				fx.text(p, "이동 -1", 36, P.WARN, 60, 1.0)
				fx.curse(p, Vector2(78, origin.y - 120), Color8(160, 170, 255), cs)
				Snd.play("curse", 1.3)
				continue
			if e.type == "choco_grow":
				fx.crumbs(_gp(_cell_xy(e.i)), D.CHOCO_C, cs)
				vis[e.i].hurt = 1.0
			elif e.type == "mon_act":
				var from := _gp(_cell_xy(e.i))
				vis[e.i].hurt = 0.6
				for c in e.cells:
					fx.curse(from, _gp(_cell_xy(c)), Color8(255, 120, 120), cs)
					vis[c].hurt = 1.0
				if not e.cells.is_empty():
					Snd.play("curse")
		st = St.TURN
		state_t = 0.0
		turn_len = 0.45 if not ev.is_empty() or not res.moves.is_empty() else 0.0
		return
	_after_turn()


## 턴 끝 장치가 옮긴 조각 — 출발 칸에서 미끄러져 온다(TURN 동안 fly 를 0 으로 줄인다).
func _apply_perm(moves: Array) -> void:
	var old := vis.duplicate()
	for mv in moves:
		var from: int = mv.from
		var to: int = mv.to
		vis[to] = old[from]
		vis[to].fly = _cell_xy(from) - _cell_xy(to)
		if vis[to].fly.length() > 1.5:
			vis[to].fly = vis[to].fly.normalized()   # 고리 끝에서 반대편으로 넘어가는 것은 한 칸만
	if not moves.is_empty():
		Snd.play("swap", 0.7)


## 레이저 · 로켓 — 쏜 자리에서 광선이 꺾이는 데까지 마디마다 이어 그린다.
func _shot_fx(s: Dictionary) -> void:
	var from := _gp(_cell_xy(s.i))
	var col := Color8(255, 110, 140) if s.kind == "laser" else Color8(255, 200, 90)
	var cells: PackedInt32Array = s.cells
	var prev := from
	for k in cells.size():
		var p := _gp(_cell_xy(cells[k]))
		fx.beam(prev, p, col, cs * 0.7)
		prev = p
	Snd.play("line", 1.2 if s.kind == "laser" else 0.9)


func _after_turn() -> void:
	# 턴 끝에 쏜 레이저 · 로켓이 맞힌 칸부터 터뜨린다
	var fr := play.fire_pending()
	if not fr.is_empty():
		_pre_step()
		_show(fr)
		return
	# 먹보가 젤리를 먹어 빈 칸이 생겼다
	if play.holes_made:
		play.holes_made = false
		_do_fall()
		return
	# 장치가 옮긴 조각끼리 맞았으면 이어서 터뜨린다(이 연쇄는 몬스터 차례를 또 부르지 않는다)
	if not play.b.find_groups().is_empty():
		_pre_step()
		_show(play.cascade())
		return
	if play.won() or play.lost():
		_settled()
		return
	if not play.b.has_move():
		_shuffle()
		return
	st = St.IDLE


func _shuffle() -> void:
	var moves := play.b.shuffle()
	var old := vis.duplicate()
	for mv in moves:
		var from: int = mv.from
		var to: int = mv.to
		vis[to] = old[from]
		vis[to].fly = _cell_xy(from) - _cell_xy(to)
	shuf_msg = 1.2
	st = St.SHUF
	state_t = 0.0


func _finish(win: bool) -> void:
	sel = -1
	st = St.WIN if win else St.LOSE
	state_t = 0.0
	if win:
		result_stars = play.stars()
		var id := int(play.stage.id)
		new_best = play.score > int(Sv.scores.get(id, 0))
		Sv.record(id, result_stars, play.score)
		fx.confetti(vs, 40 + result_stars * 20)
		Snd.play("win")
	else:
		Snd.play("lose")
	_log_stage("win" if win else "lose")
	if win:
		Net.open_stage(int(play.stage.id), int(Sv.scores.get(int(play.stage.id), play.score)))


func _log_stage(r: String) -> void:
	var id := int(play.stage.id)
	Net.event({"k": "st", "s": id, "r": r, "sc": play.score, "st": result_stars if r == "win" else 0,
			"ml": win_left if r == "win" and win_left >= 0 else play.moves_left, "mv": int(play.stage.moves), "tr": int(Sv.tries.get(id, 0)),
			"sec": int(t - play_t0)})


func _game_over() -> void:
	st = St.OVER
	sel = -1
	Sv.plays += 1
	if play.score > Sv.best:
		Sv.best = play.score
		new_best = true
	Sv.save_()
	fx.confetti(vs, 70 if new_best else 30)
	Snd.play("end")
	Net.event({"k": "ta", "sc": play.score})

# ==================== 매 프레임 ====================

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)   # 탭을 오래 비웠다 돌아오면 dt 가 몇 초가 된다
	# 상황 음악(11-09): 모험은 남은 이동 5 이하, 타임 어택은 남은 15초부터 급박 변주
	Bgm.mood(scr == Scr.GAME and play != null and ((not _ta() and play.moves_left <= 5) or (_ta() and time_left <= 15.0)))
	t += dt
	_lay()
	fx.step(dt)   # 배경 음악 굽기(Bgm.step)는 허브가 프레임마다 한다
	wipe_armed = maxf(0.0, wipe_armed - dt)
	var sh := fx.shake
	shake_off = Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
	if scr == Scr.GAME:
		_step_game(dt)
	if shot_path != "" and t >= shot_at and shot_at > 0.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	if input_test:
		_input_test_step()
	if ui_test:
		_ui_test_step()
	var clip := _board_rect().grow(12)
	board_layer.position = clip.position
	board_layer.size = clip.size
	board_layer.visible = scr == Scr.GAME
	queue_redraw()
	board_layer.queue_redraw()
	fx_layer.queue_redraw()
	top_layer.queue_redraw()


func _step_game(dt: float) -> void:
	for v in vis:
		v.land = maxf(0.0, v.land - dt / D.LAND_T)
		v.born = maxf(0.0, v.born - dt * 3.0)
		v.sad = maxf(0.0, v.sad - dt * 1.6)
		v.hurt = maxf(0.0, v.hurt - dt * 3.0)
		if t > v.blink + 0.13:
			v.blink = t + randf_range(D.BLINK_GAP.x, D.BLINK_GAP.y)
			var a := randf() * TAU
			v.look = Vector2(cos(a), sin(a)) * randf()

	# 떨어지기 — 상태와 상관없이 늘 돈다(시작 창 뒤에서도 판이 채워진다).
	# 대각선으로 미끄러진 것도 있으므로 off 를 벡터째로 0 을 향해 줄인다.
	var falling := false
	for v in vis:
		if not v.falling:
			continue
		v.vy = minf(v.vy + D.FALL_G * dt, D.FALL_VMAX)
		var d: float = v.off.length()
		var step: float = v.vy * dt
		if step >= d:
			v.off = Vector2.ZERO
			v.vy = 0.0
			v.falling = false
			v.land = 1.0
		else:
			v.off -= v.off / d * step
			falling = true

	for i in range(ghosts.size() - 1, -1, -1):
		var g: Dictionary = ghosts[i]
		g.t += dt
		if g.t >= D.POP_T:
			var c: Color = P.jelly(g.c) if g.sp != D.SP_RAINBOW else Color(1, 1, 1)
			fx.pop(_gp(g.at), c, cs, g.power)
			ghosts.remove_at(i)

	state_t += dt
	match st:
		St.IDLE:
			idle_t += dt
			if idle_t > D.HINT_T and hint.is_empty():
				hint = play.b.find_move()
			if auto and idle_t > 0.35:
				var m := play.b.find_move()
				if not m.is_empty():
					_try_swap(m[0], m[1])
		St.SWAP, St.BACK:
			var k := G2.smooth(state_t / D.SWAP_T)
			var d := _cell_xy(swap_b) - _cell_xy(swap_a)
			vis[swap_a].off = d * k
			vis[swap_b].off = -d * k
			if state_t >= D.SWAP_T:
				vis[swap_a].off = Vector2.ZERO
				vis[swap_b].off = Vector2.ZERO
				_swap_vis(swap_a, swap_b)
				if st == St.SWAP:
					_after_swap()
				else:
					st = St.IDLE
		St.POP:
			# 날개가 아직 날고 있으면 기다린다
			var waiting := false
			for g in ghosts:
				if g.t < 0.0:
					waiting = true
			if state_t >= D.POP_T and not waiting:
				_do_fall()
		St.FALL:
			if not falling:
				_after_fall()
		St.TURN:
			var k := G2.smooth(state_t / maxf(0.01, turn_len))
			for v in vis:
				if v.fly != Vector2.ZERO:
					v.off = v.fly * (1.0 - k)
			if state_t >= turn_len:
				for v in vis:
					if v.fly != Vector2.ZERO:
						v.fly = Vector2.ZERO
						v.off = Vector2.ZERO
				_after_turn()
		St.SHUF:
			var k := G2.smooth(state_t / 0.45)
			for v in vis:
				v.off = v.fly * (1.0 - k)
			if k >= 1.0:
				for v in vis:
					v.fly = Vector2.ZERO
				st = St.IDLE
		St.BONUS:
			if state_t >= D.BONUS_STEP_T:
				state_t = 0.0
				var i := play.bonus_pick()
				if i >= 0:
					vis[i].born = 1.0
					fx.merge(_gp(_cell_xy(i)), [], P.jelly(play.b.col[i]), cs)
					fx.text(_gp(_cell_xy(i)), "+%d" % D.BONUS_MOVE_PTS, 28, P.GOLD, 50, 0.6)
					Snd.play("make", 1.0 + (10 - mini(play.moves_left, 10)) * 0.05)
				else:
					bonus_fired = true
					var r := play.bonus_fire()
					if r.is_empty():
						_finish(true)
					else:
						_show(r)

	if _ta() and _playing():
		var before := time_left
		time_left = maxf(0.0, time_left - dt)
		if time_left < D.WARN_T and ceilf(time_left) != ceilf(before):
			Snd.play("tick")
		if time_left <= 0.0 and st == St.IDLE:
			_game_over()
		if combo_t > 0.0:
			combo_t -= dt
			if combo_t <= 0.0:
				combo = 0
		if fever_t > 0.0:
			fever_t -= dt
			fever = maxf(0.0, fever_t / D.FEVER_T)
		else:
			fever = maxf(0.0, fever - D.FEVER_DECAY * dt)
	if _playing():
		twinkle_t -= dt
		if twinkle_t <= 0.0:
			twinkle_t = 0.18
			var i := randi() % play.b.sp.size()
			if play.b.is_jelly(i) and play.b.sp[i] != D.SP_NONE:
				fx.twinkle(_gp(_cell_xy(i)), cs)
	shown = lerpf(shown, play.score, minf(1.0, dt * 10.0))
	shuf_msg = maxf(0.0, shuf_msg - dt)

# ==================== 입력 ====================

## 클릭이 레이어에 먹히면 키보드는 멀쩡한데 마우스만 안 된다 — 화면을 봐서는 모른다.
## 진짜 이벤트를 흘려 넣고, 입력은 다음 프레임에 처리되므로 몇 프레임 뒤에 본다.
func _input_test_step() -> void:
	_it_step += 1
	if _it_step < 400 and st == St.SWAP:
		print("INPUT TEST OK — 끌기로 바꾸기가 시작됨")
		get_tree().quit(0)
		return
	if _it_step < 400 and st == St.IDLE and _it_step % 30 == 0:
		var m := play.b.find_move()
		# 창 좌표로 넣어야 한다 — 창(450×800)이 캔버스(720×1280)보다 작게 늘려져 있다
		var xf := get_viewport().get_final_transform()
		var a := xf * (_gp(_cell_xy(m[0])) - shake_off)
		var c := xf * (_gp(_cell_xy(m[1])) - shake_off)
		for e in [_mb(a, true), _mm(a.lerp(c, 0.5)), _mm(c), _mb(c, false)]:
			Input.parse_input_event(e)
		return
	if _it_step >= 400:
		print("INPUT TEST FAILED — 끌어도 안 바뀜")
		get_tree().quit(1)


## --ui-test: 처음 → 모험 → 1번 → 시작 창 → 바꾸기 → Esc 를 진짜 클릭 · 키로 지나간다.
## 화면마다 클릭이 다른 길로 새지 않는지 본다. 실패하면 종료 코드 1.
var _ui_step := 0
var _ui_wait := 0
var _ui_vol := 1.0


func _ui_test_step() -> void:
	_ui_wait += 1
	if _ui_wait < 20:
		return
	_ui_wait = 0
	var xf := get_viewport().get_final_transform()
	var ok := true
	var what := ""
	match _ui_step:
		0:
			_click_at(xf * _title_btn(0).get_center())
		1:
			ok = scr == Scr.MAP
			what = "처음 → 모험"
			_click_at(xf * _map_rect(0).get_center())
		2:
			ok = scr == Scr.GAME and st == St.INTRO and stage_n == 0
			what = "모험 → 1번 스테이지"
			if guide_open:
				# 처음 보는 장애물 안내가 떴다 — 누르면 닫히고 시작 창이 남아야 한다
				ok = ok and guide_fresh
				what = "새 장애물 안내"
				_click_at(xf * (vs * 0.5))
				_ui_step -= 1
			else:
				_click_at(xf * (vs * 0.5))
		3:
			ok = st != St.INTRO
			what = "시작 창 닫기"
		4:
			if st != St.IDLE:
				_ui_step -= 1   # 다 떨어질 때까지 기다린다
			else:
				var m := play.b.find_move()
				var a := xf * (_gp(_cell_xy(m[0])) - shake_off)
				var c := xf * (_gp(_cell_xy(m[1])) - shake_off)
				for e in [_mb(a, true), _mm(c), _mb(c, false)]:
					Input.parse_input_event(e)
		5:
			ok = st != St.IDLE or play.moves_left < int(play.stage.moves)
			what = "끌어서 바꾸기"
			_press_key(KEY_ESCAPE)
		6:
			ok = scr == Scr.MAP
			what = "Esc → 목록"
			_click_at(xf * _guide_btn().get_center())
		7:
			ok = scr == Scr.GUIDE and guide_from == Scr.MAP
			what = "목록 → 도감"
			_click_at(xf * _page_btn(1).get_center())
		8:
			ok = guide_page == 1
			what = "도감 다음 쪽"
			_press_key(KEY_ESCAPE)
		9:
			ok = scr == Scr.MAP
			what = "도감 Esc → 목록"
			_click_at(xf * _back_rect().get_center())
		10:
			ok = scr == Scr.TITLE
			what = "목록 → 처음"
			_click_at(xf * _title_btn(2).get_center())
		11:
			ok = scr == Scr.GUIDE
			what = "처음 → 도감"
			_click_at(xf * _back_rect().get_center())
		12:
			ok = scr == Scr.TITLE
			what = "도감 → 처음"
			_click_at(xf * _title_btn(3).get_center())
		13:
			ok = scr == Scr.GUIDE and guide_list == Guide.SPECIALS
			what = "처음 → 좋은 젤리 도감"
			_press_key(KEY_ESCAPE)
		14:
			ok = scr == Scr.TITLE
			what = "좋은 젤리 도감 Esc → 처음"
			_click_at(xf * _title_btn(4).get_center())
		15:
			ok = scr == Scr.RANK
			what = "처음 → 순위"
			_press_key(KEY_ESCAPE)
		16:
			ok = scr == Scr.TITLE
			what = "순위 Esc → 처음"
			_ui_vol = Sv.vol_sfx
			_click_at(xf * _sound_btn(0).get_center())
		17:
			ok = Vol.open
			what = "음량 단추 → 음량 창"
			_click_at(xf * Vol.minus_rect(vs, 1).get_center())   # 효과음 한 칸 내리기
		18:
			ok = Vol.open and absf(Sv.vol_sfx - maxf(0.0, _ui_vol - Vol.STEP)) < 0.02
			what = "음량 창 - 단추"
			Vol.set_v(1, _ui_vol)   # 되돌려 둔다
			_click_at(xf * Vol.close_rect(vs).get_center())
		19:
			ok = not Vol.open
			what = "음량 창 닫기"
		20:
			print("UI TEST OK")
			get_tree().quit(0)
			return
	if not ok:
		print("UI TEST FAILED at: ", what)
		get_tree().quit(1)
		return
	_ui_step += 1


func _press_key(k: int) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)


func _click_at(p: Vector2) -> void:
	Input.parse_input_event(_mb(p, true))
	Input.parse_input_event(_mb(p, false))


func _mb(p: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.global_position = p
	return e


func _mm(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	return e


func _unhandled_input(ev: InputEvent) -> void:
	var key := ev as InputEventKey
	if key != null:
		if name_edit != null:
			# 이름 입력 중 — Esc 로 취소, 나머지 키는 입력칸 것이다
			if key.pressed and key.keycode == KEY_ESCAPE:
				name_edit.queue_free()
				name_edit = null
			return
		if key.pressed and not key.echo:
			_key(key.keycode)
		return
	var mb := ev as InputEventMouseButton
	if Vol.open:
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			Vol.release()
		elif ev is InputEventMouseMotion:
			Vol.motion(ev.position, vs)
		if mb == null or not mb.pressed:
			return
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_click(mb.position)
		elif pressing:
			# 끌지 않고 뗐다 — 탭 두 번으로 바꾸기
			pressing = false
			var c := press_cell
			if sel >= 0 and sel != c and play.b.adjacent(sel, c):
				_try_swap(sel, c)
			elif sel == c:
				sel = -1
			else:
				sel = c
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and pressing:
		var d := mm.position - press_pos
		if d.length() > cs * 0.35:
			pressing = false
			var x := press_cell % _bw()
			var y := press_cell / _bw()
			if absf(d.x) > absf(d.y):
				x += 1 if d.x > 0 else -1
			else:
				y += 1 if d.y > 0 else -1
			if x >= 0 and x < _bw() and y >= 0 and y < _bh():
				_try_swap(press_cell, y * _bw() + x)


func _click(p: Vector2) -> void:
	if Vol.press(p, vs):   # 음량 창이 떠 있으면 그 창이 먼저 받는다
		return
	if name_edit != null:
		# 입력칸 밖을 누르면 적은 대로 정한다(입력칸 안 클릭은 GUI 가 먼저 받아 여기 안 온다)
		_set_name(name_edit.text)
		name_edit.queue_free()
		name_edit = null
		return
	match scr:
		Scr.TITLE:
			for k in TITLE_N:
				if _title_btn(k).has_point(p):
					_title_go(k)
			for k in 2:
				if _sound_btn(k).has_point(p):
					_toggle_sound(k)
			if _wipe_btn().has_point(p):
				_wipe_press()
			if _hub_btn().has_point(p):
				Hub.leave(self)
		Scr.NAME:
			if _name_btn().has_point(p):
				_ask_name()
		Scr.RANK:
			if _back_rect().has_point(p):
				scr = Scr.TITLE
				return
			for k in 2:
				if _rank_btn(k).has_point(p):
					rank_tab = k
			if _rank_btn(2).has_point(p):
				_ask_name()
		Scr.MAP:
			if _back_rect().has_point(p):
				scr = Scr.TITLE
				return
			if _guide_btn().has_point(p):
				_open_guide()
				return
			for k in 2:
				if _page_btn(k).has_point(p):
					var pg := clampi(_map_page() + (1 if k == 1 else -1), 0, _pages() - 1)
					map_sel = mini(pg * MAP_PAGE, Stages.count() - 1)
					return
			for n in Stages.count():
				if _map_rect(n).has_point(p) and n < Sv.unlocked():
					_start_stage(n)
					return
		Scr.GUIDE:
			if _back_rect().has_point(p):
				scr = guide_from
				return
			_guide_click(p)
		Scr.GAME:
			# 덮고 있는 것부터 — 장애물 창이 떠 있으면 판을 누르지 않는다
			if guide_open:
				if _back_rect().has_point(p) or not _guide_click(p):
					guide_open = false
					guide_fresh = false
				return
			if _info_btn().has_point(p):
				_open_info()
				return
			if st == St.WIN or st == St.LOSE or st == St.OVER:
				for k in 3:
					if _panel_btn(k).has_point(p) and _panel_has(k):
						_panel_go(k)
				return
			if _back_rect().has_point(p):
				_leave()
				return
			if st == St.INTRO:
				st = St.FALL
				return
			press_cell = _cell_at(p)
			press_pos = p
			pressing = press_cell >= 0
			if pressing and st == St.IDLE and play.b.col[press_cell] == Board.GEAR:
				# 톱니는 눌러서 방향만 바꾼다 — 이동을 쓰지 않는다
				play.b.gear_dir[press_cell] *= -1
				vis[press_cell].hurt = 1.0
				Snd.play("chain", 0.8)
				pressing = false


func _key(k: int) -> void:
	var enter := k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE
	if Vol.open:
		if k == KEY_ESCAPE or enter:
			Vol.close()
		return
	match scr:
		Scr.TITLE:
			if k == KEY_UP:
				title_sel = (title_sel + TITLE_N - 1) % TITLE_N
			elif k == KEY_DOWN:
				title_sel = (title_sel + 1) % TITLE_N
			elif k >= KEY_1 and k < KEY_1 + TITLE_N:
				_title_go(k - KEY_1)
			elif k == KEY_M:
				_toggle_sound(0)
			elif k == KEY_S:
				_toggle_sound(1)
			elif k == KEY_DELETE and Sv.all_open:
				_wipe_press()
			elif k == KEY_ESCAPE:
				Hub.leave(self)
			elif enter:
				_title_go(title_sel)
		Scr.NAME:
			if enter:
				_ask_name()
		Scr.RANK:
			match k:
				KEY_LEFT, KEY_RIGHT, KEY_TAB:
					rank_tab = 1 - rank_tab
				KEY_N:
					_ask_name()
				KEY_ESCAPE:
					scr = Scr.TITLE
		Scr.MAP:
			var n := Stages.count()
			match k:
				KEY_LEFT:
					map_sel = maxi(0, map_sel - 1)
				KEY_RIGHT:
					map_sel = mini(n - 1, map_sel + 1)
				KEY_UP:
					map_sel = maxi(0, map_sel - MAP_COLS)
				KEY_DOWN:
					map_sel = mini(n - 1, map_sel + MAP_COLS)
				KEY_PAGEUP:
					map_sel = maxi(0, map_sel - MAP_PAGE)
				KEY_PAGEDOWN:
					map_sel = mini(n - 1, map_sel + MAP_PAGE)
				KEY_ESCAPE:
					scr = Scr.TITLE
				KEY_G:
					_open_guide()
			if enter and map_sel < Sv.unlocked():
				_start_stage(map_sel)
		Scr.GUIDE:
			match k:
				KEY_LEFT, KEY_PAGEUP, KEY_UP:
					guide_page = maxi(0, guide_page - 1)
				KEY_RIGHT, KEY_PAGEDOWN, KEY_DOWN:
					guide_page = mini(Guide.pages(guide_list) - 1, guide_page + 1)
				KEY_ESCAPE, KEY_G:
					scr = guide_from
		Scr.GAME:
			if guide_open:
				match k:
					KEY_LEFT, KEY_PAGEUP, KEY_UP:
						guide_page = maxi(0, guide_page - 1)
					KEY_RIGHT, KEY_PAGEDOWN, KEY_DOWN:
						guide_page = mini(Guide.pages(guide_list) - 1, guide_page + 1)
					_:
						guide_open = false
						guide_fresh = false
				return
			if k == KEY_G and _info_btn().has_area():
				_open_info()
				return
			match st:
				St.INTRO:
					if enter:
						st = St.FALL
					elif k == KEY_ESCAPE:
						_leave()
				St.WIN, St.LOSE, St.OVER:
					if enter:
						_panel_go(0)
					elif k == KEY_R:
						_panel_go(1 if st == St.WIN else 0)
					elif k == KEY_ESCAPE:
						_panel_go(2)
				_:
					if k == KEY_ESCAPE:
						_leave()


func _title_go(k: int) -> void:
	if k == 0:
		scr = Scr.MAP
		map_sel = mini(Sv.unlocked(), Stages.count()) - 1
	elif k == 1:
		_start_ta()
	elif k == 2:
		_open_guide()
	elif k == 3:
		_open_specials()
	else:
		scr = Scr.RANK
		Net.open_board()   # 이름 · 최고 기록을 먼저 올리고, 그다음 순위를 받는다


## 음량 창을 연다(예전에는 0 = 음악, 1 = 효과음 켬/끔이었다 — 지금은 막대 셋이 있는 창 하나).
func _toggle_sound(_k: int) -> void:
	Vol.open = true


## 이름 바꾸기. 웹은 브라우저 입력창(prompt) — 폰 키보드 · 한글 입력이 그대로 된다.
## 데스크톱은 LineEdit 를 잠깐 띄운다(이 게임에서 유일한 GUI 노드).
func _ask_name() -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt('순위에 쓸 이름 (10자까지)', %s)" % JSON.stringify(Sv.name))
		if r is String:
			_set_name(r)
		return
	if name_edit != null:
		return
	name_edit = LineEdit.new()
	name_edit.text = Sv.name
	name_edit.max_length = 10
	name_edit.add_theme_font_override("font", P.font())
	name_edit.add_theme_font_size_override("font_size", 40)
	name_edit.position = Vector2(vs.x * 0.5 - 220, vs.y * 0.5 - 40)
	name_edit.size = Vector2(440, 80)
	add_child(name_edit)
	name_edit.grab_focus()
	name_edit.select_all()
	name_edit.text_submitted.connect(func(s: String):
		_set_name(s)
		name_edit.queue_free()
		name_edit = null)


func _set_name(s: String) -> void:
	s = s.strip_edges().left(10)
	if s == "":
		return
	var changed := s != Sv.name or not Sv.named
	Sv.name = s
	Sv.named = true   # 미리 채워 둔 이름을 그대로 확인해도 정한 것으로 본다
	Sv.save_()
	if scr == Scr.NAME:
		scr = Scr.TITLE
		Net.flush(true)
	elif changed:
		Net.open_board()


func _open_guide() -> void:
	guide_from = scr
	guide_page = 0
	guide_list = Guide.entries()
	guide_title = "장애물 도감"
	scr = Scr.GUIDE


## 좋은 젤리 도감 — 특수 젤리와 조합. 장애물 도감과 같은 화면에 목록만 바꿔 띄운다.
func _open_specials() -> void:
	guide_from = scr
	guide_page = 0
	guide_list = Guide.SPECIALS
	guide_title = "좋은 젤리 도감"
	scr = Scr.GUIDE


## 게임 중 장애물 창 — 화면을 바꾸지 않고 겹쳐 띄운다(판 상태를 그대로 둔다).
func _open_info() -> void:
	guide_list = Guide.in_stage(play.stage)
	guide_page = 0
	guide_open = true


## 오른쪽 위 "장애물" 단추. 타임 어택이거나 장애물이 없는 판엔 없다.
func _info_btn() -> Rect2:
	if play == null or _ta() or Guide.in_stage(play.stage).is_empty():
		return Rect2()
	return Rect2(vs.x - 150, 18, 132, 52)


## 도감 쪽 넘기기 — 도감 화면과 게임 중 창이 같이 쓴다.
func _guide_click(p: Vector2) -> bool:
	for k in 2:
		if _page_btn(k).has_point(p):
			guide_page = clampi(guide_page + (1 if k == 1 else -1), 0, Guide.pages(guide_list) - 1)
			return true
	return false


## 이겼을 때만 "다시"가 따로 있다(주 단추가 "다음"이라서). 졌을 때 · 타임 어택은 주 단추가 "다시".
func _panel_has(k: int) -> bool:
	return k != 1 or st == St.WIN


func _panel_go(k: int) -> void:
	match k:
		0:
			if st == St.WIN and stage_n + 1 < Stages.count():
				_start_stage(stage_n + 1)
			elif st == St.WIN:
				_leave()
			elif _ta():
				_start_ta()
			else:
				_start_stage(stage_n)
		1:
			_start_stage(stage_n)
		2:
			_leave()

# ==================== 그리기 ====================

func _draw() -> void:
	_draw_bg()
	if scr != Scr.GAME:
		return
	var b := play.b
	_draw_board_base(b)
	for i in b.w * b.h:
		if b.hole[i]:
			if b.pipe[i] > 0:
				Art.pipe(self, Rect2(origin + shake_off + _cell_xy(i) * cs, Vector2(cs, cs)), b.pipe[i])
			continue
		var at := _cell_xy(i)
		var rect := Rect2(origin + shake_off + at * cs, Vector2(cs, cs))
		Art.cell_bg(self, rect, (int(at.x) + int(at.y)) % 2 == 0)
		if b.sugar[i] > 0:
			Art.sugar(self, rect, b.sugar[i])
		if b.belt[i] > 0 and not Art.belt_tex_ok():
			Art.belt(self, rect, b.belt[i], t)
		if b.field[i]:
			Art.field(self, rect, t)
		if b.csugar[i] > 0:
			Art.csugar(self, rect, b.csugar[i] - 1)
		if b.paint[i] > 0:
			Art.paint(self, rect)
	if Art.belt_tex_ok():
		for loop in _belt_loops():
			Art.belt_loop(self, loop, cs, t)
	for x in b.w:
		if b.rise[x] > 0:
			var col := Rect2(origin + shake_off + Vector2(x * cs, 0), Vector2(cs, b.h * cs))
			Art.rise_col(self, col, t)
			Art.rise_badge(self, Vector2(col.get_center().x, col.position.y - cs * 0.3), cs, t)
	var k := 0
	for ex in b.portal:
		var en: int = b.portal[ex]
		Art.portal_mark(self, Rect2(origin + shake_off + _cell_xy(en) * cs, Vector2(cs, cs)), k, true, t)
		Art.portal_mark(self, Rect2(origin + shake_off + _cell_xy(ex) * cs, Vector2(cs, cs)), k, false, t)
		k += 1
	if _ta() and time_left < D.WARN_T and _playing():
		var pulse := 0.5 + 0.5 * sin(t * TAU * 2.0)
		G2.panel(self, _board_rect().grow(12), Color(0, 0, 0, 0), P.a(P.WARN, 0.4 + pulse * 0.5), 5.0, 26.0)


## 판 바탕 — 열린 칸 밑에 진한 반투명 판을 깔고, 판 바깥(구멍 · 끝)과 맞닿은 변에만 흰 테를 긋는다.
## 바탕이 없으면 젤리가 배경 위 허공에 떠 보인다(사용자 결정 11-04). 구멍은 비워 두어 판 모양이 드러난다.
func _draw_board_base(b: Board) -> void:
	var o := origin + shake_off
	for i in b.w * b.h:
		if not b.hole[i]:
			draw_rect(Rect2(o + _cell_xy(i) * cs, Vector2(cs, cs)), P.BOARD)
	var lw := maxf(3.0, cs * 0.06)
	for i in b.w * b.h:
		if b.hole[i]:
			continue
		var x := i % b.w
		var y := i / b.w
		var p := o + Vector2(x, y) * cs
		if y == 0 or b.hole[i - b.w]:
			draw_line(p, p + Vector2(cs, 0), P.BOARD_EDGE, lw)
		if y == b.h - 1 or b.hole[i + b.w]:
			draw_line(p + Vector2(0, cs), p + Vector2(cs, cs), P.BOARD_EDGE, lw)
		if x == 0 or b.hole[i - 1]:
			draw_line(p, p + Vector2(0, cs), P.BOARD_EDGE, lw)
		if x == b.w - 1 or b.hole[i + 1]:
			draw_line(p + Vector2(cs, 0), p + Vector2(cs, cs), P.BOARD_EDGE, lw)


func _draw_board() -> void:
	if play == null:
		return
	var ci := board_layer
	var lo := board_layer.position   # 이 레이어는 판 모서리 근처가 원점이다
	var b := play.b
	var r := cs * 0.42
	if sel >= 0:
		ci.draw_arc(_gp(_cell_xy(sel)) - lo, cs * 0.52, 0, TAU, 32, Color(1, 1, 1, 0.8 + 0.2 * sin(t * 10)), 4.0, true)
	for i in b.w * b.h:
		if b.hole[i] or b.col[i] == Board.EMPTY:
			continue
		var v: Dictionary = vis[i]
		var pos: Vector2 = _gp(_cell_xy(i) + v.off) - lo
		match b.col[i]:
			Board.BOX:
				Art.box(ci, pos, r, b.lay[i], v.hurt)
			Board.CHOCO:
				Art.choco(ci, pos, r, t + v.phase)
			Board.MON:
				var m: Dictionary = b.mons[i]
				# 대왕꾸덕이 만든 새끼는 작게 — 같은 그림이라 크기로만 원래 꾸덕이와 갈린다
				var mr := r * (0.82 if int(m.max) <= D.BOSS_MINION_HP else 1.05)
				Art.monster(ci, pos, mr, m.kind, float(m.hp) / m.max, t, v.hurt, not m.target.is_empty())
			Board.FRUIT:
				Art.fruit(ci, pos, r, t + v.phase)
			Board.GEAR:
				Art.gear(ci, pos, r, b.gear_dir[i], t, v.hurt)
			Board.WIND:
				Art.wind(ci, pos, r, t, b.wind_armed.has(i))
			Board.PUSH:
				Art.push(ci, pos, r, b.push_dir[i])
			Board.CAPSULE:
				Art.capsule(ci, pos, r, t + v.phase)
			Board.LASER:
				Art.laser(ci, pos, r, b.dev_dir[i], int(b.charge.get(i, 0)), t, v.hurt)
			Board.ROCKET:
				Art.rocket(ci, pos, r, b.dev_dir[i], int(b.dev_color.get(i, 0)), b.armed.has(i), t)
			Board.LOCK:
				Art.lock(ci, pos, r, int(b.lock_c.get(i, 0)), int(b.lock_n.get(i, 0)), v.hurt)
			Board.GIFT:
				Art.gift(ci, pos, r, t + v.phase, v.hurt)
			Board.STEAM:
				Art.steam(ci, pos, r, t, int(b.steam_cd.get(i, 0)))
			Board.DECOY:
				Art.decoy(ci, pos, r, t + v.phase)
			Board.PLANT:
				Art.plant(ci, pos, r, t + v.phase)
			Board.MOLE:
				Art.mole(ci, pos, r, int(b.mole_hp.get(i, 0)), t + v.phase, v.hurt)
			Board.FIRE:
				Art.campfire(ci, pos, r, int(b.fire_t.get(i, 0)), t + v.phase)
			Board.JAR:
				Art.jar(ci, pos, r, int(b.jar_c.get(i, 0)), int(b.jar_n.get(i, 0)), Play.JAR_N)
			_:
				_draw_jelly(i, r, lo)
				if b.ice[i] > 0:
					Art.ice(ci, pos, r, b.ice[i])
				if b.chain[i] > 0:
					Art.chain(ci, pos, r)
				if b.glass[i] > 0:
					Art.glass(ci, pos, r, t + v.phase)
				if b.dice[i] > 0:
					Art.dice_mark(ci, pos, r)
				if b.steel[i] > 0:
					Art.steel_mark(ci, pos, r)
				if b.web[i] > 0:
					Art.web(ci, pos, r, b.web[i])
	for i in b.w * b.h:
		var cell := Rect2(_gp(_cell_xy(i)) - lo - Vector2(cs, cs) * 0.5, Vector2(cs, cs))
		if b.pipe[i] > 0:
			if Tex.art("fl_pipe") == null:
				Art.pipe(ci, cell, b.pipe[i], 0.55)
		if b.field[i]:
			Art.field_top(ci, cell, t)
		if b.cloud[i] > 0:
			Art.cloud(ci, cell.get_center(), r, t + i)
	# 몬스터가 다음 턴에 노리는 칸 — 행동하기 전에 반드시 보여 준다
	for c in b.mons:
		var m: Dictionary = b.mons[c]
		for tg in m.target:
			Art.target_mark(ci, _gp(_cell_xy(tg)) - lo, r, m.kind, t)
	for g in ghosts:
		var k := clampf(g.t / D.POP_T, 0.0, 1.0)
		var s := 1.0 + 0.3 * G2.out_cubic(k)
		Art.jelly(ci, _gp(g.at) - lo, r, g.c, g.sp, Art.Face.SQUINT, Vector2.ZERO, false,
				Vector2(s, s), 0.0, k, t)


func _draw_jelly(i: int, r: float, lo: Vector2) -> void:
	var b := play.b
	var v: Dictionary = vis[i]
	var at: Vector2 = _cell_xy(i) + v.off
	var pos := _gp(at) - lo
	var face := Art.Face.IDLE
	var look: Vector2 = v.look
	var rot := 0.0
	var br := D.BREATH * sin(t * 3.2 + v.phase)
	var sq := Vector2(1.0 - br, 1.0 + br)

	if v.falling and v.vy > 0.0:
		var st_ := minf(v.vy * D.FALL_STRETCH, 0.18)
		sq *= Vector2(1.0 - st_ * 0.5, 1.0 + st_)
		face = Art.Face.WOW
	if v.land > 0.0:
		# 착지 — 가로로 퍼졌다가 두어 번 튕기며 가라앉는다
		var k: float = 1.0 - v.land
		var amt := D.LAND_SQUASH * exp(-k * 4.0) * cos(k * PI * 3.0)
		sq *= Vector2(1.0 + amt, 1.0 - amt)
	if v.born > 0.0:
		sq *= maxf(0.01, G2.out_back(1.0 - v.born))
		face = Art.Face.HAPPY
	if fever_t > 0.0 or st == St.WIN or st == St.BONUS:
		pos.y -= absf(sin(t * 9.0 + at.x * 0.7)) * cs * 0.07
		face = Art.Face.HAPPY
	if i == sel:
		pos.y -= absf(sin(t * 9.0)) * cs * 0.1
		face = Art.Face.WOW
	if hint.size() == 2 and (i == hint[0] or i == hint[1]):
		var other := hint[1] if i == hint[0] else hint[0]
		look = (_cell_xy(other) - _cell_xy(i))
		if fmod(t, 1.2) < 0.6:
			rot = sin(t * 22.0) * 0.16
	if (st == St.SWAP or st == St.BACK) and (i == swap_a or i == swap_b):
		look = (_cell_xy(swap_b if i == swap_a else swap_a) - _cell_xy(i))
	if b.ice[i] > 0 or b.chain[i] > 0 or st == St.LOSE:
		face = Art.Face.SAD
	if v.sad > 0.0:
		face = Art.Face.SAD
		rot += sin(t * 40.0) * 0.1 * v.sad
	# 찌그러짐은 바닥을 기준으로 — 가운데 기준이면 착지할 때 공중에서 눌린다
	pos.y += r * (1.0 - sq.y)
	var blink: bool = t >= v.blink and t < v.blink + 0.13
	Art.jelly(board_layer, pos, r, b.col[i], b.sp[i], face, look, blink, sq, rot, 0.0, t + v.phase)


func _draw_bg() -> void:
	var top := P.BG_TOP
	var bot := P.BG_BOT
	if fever_t > 0.0 and scr == Scr.GAME:
		top = Color.from_hsv(fposmod(t * 0.25, 1.0), 0.35, 1.0)
		bot = Color.from_hsv(fposmod(t * 0.25 + 0.4, 1.0), 0.45, 0.95)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([top, top, bot, bot]))
	var tex := Tex.art("bg")
	if tex != null:
		# 화면을 덮도록 (비율 유지, 넘치는 쪽을 자른다)
		var ts := tex.get_size()
		var k := maxf(vs.x / ts.x, vs.y / ts.y)
		var sz := ts * k
		draw_texture_rect(tex, Rect2((vs - sz) * 0.5, sz), false, Color(1, 1, 1, 0.9))
	for k in 9:
		var p := Vector2(fposmod(k * 173.0 + t * (8 + k * 3), vs.x + 200) - 100,
				fposmod(k * 311.0 - t * (14 + k * 2), vs.y + 200) - 100)
		draw_circle(p, 30 + k * 9, Color(1, 1, 1, 0.07))


func _draw_fx() -> void:
	fx.draw(fx_layer)
	if scr != Scr.GAME:
		return
	var glow := Tex.fx("fx_glow")
	if fever_t > 0.0:
		var a := 0.35 + 0.15 * sin(t * 8.0)
		for k in 4:
			var c := Vector2(vs.x * float(k % 2), vs.y * float(k / 2))
			var s := vs.x * 0.9
			fx_layer.draw_texture_rect(glow, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
					P.a(P.RAINBOW[(k + int(t * 4)) % 6], a))
	var warn := _ta() and time_left < D.WARN_T
	if not _ta() and play.moves_left <= 3:
		warn = true
	if _playing() and warn:
		var a := (0.5 + 0.5 * sin(t * TAU * 2.0)) * 0.45
		for k in 4:
			var c := Vector2(vs.x * float(k % 2), vs.y * float(k / 2))
			var s := vs.x * 0.8
			fx_layer.draw_texture_rect(glow, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false,
					P.a(P.WARN, a))


func _draw_top() -> void:
	var ci := top_layer
	match scr:
		Scr.TITLE:
			_draw_title(ci)
		Scr.MAP:
			_draw_map(ci)
		Scr.GUIDE:
			_draw_guide(ci)
		Scr.RANK:
			_draw_rank(ci)
		Scr.NAME:
			_draw_name(ci)
		Scr.GAME:
			if _ta():
				_draw_hud_ta(ci)
			else:
				_draw_hud_stage(ci)
			_btn(ci, _back_rect(), "처음" if _ta() else "목록", Color(1, 1, 1, 0.85), 26)
	fx.draw_texts(ci)
	if shuf_msg > 0.0:
		G2.text_mid(ci, Vector2(vs.x * 0.5, _board_rect().get_center().y), "섞는 중!", 64,
				Color(1, 1, 1, minf(1.0, shuf_msg * 2.0)), 14)
	if scr == Scr.GAME and guide_open:
		# 시작 창 · 결과 창은 접어 둔다 — 같이 그리면 비쳐서 둘 다 안 읽힌다
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.03, 0.2, 0.75))
		_draw_guide(ci)
	elif scr == Scr.GAME:
		match st:
			St.INTRO:
				_draw_intro(ci)
			St.WIN, St.LOSE:
				_draw_result(ci)
			St.OVER:
				_draw_over(ci)
		if _info_btn().has_area():
			_btn(ci, _info_btn(), "장애물", Color8(120, 170, 255), 26)
	Vol.draw(ci, vs, t)   # 음량 창은 맨 위


## 단추. 밝은 바탕이면 글자를 진하게, 어두운 바탕이면 흰 글자에 테두리.
## 단추 — 다섯 게임 같은 입체 단추(UiKit). 처음 화면 다음 화면들도 같은 모양이어야 한다(사용자 지적 11-08).
func _btn(ci: CanvasItem, r: Rect2, label: String, fill: Color, size: float = 40.0) -> void:
	UiKit.plain(ci, r, label, fill, "jelly", t, true, size)


func _side_panel(ci: CanvasItem, k: int) -> Rect2:
	var r := _side_rect(k)
	G2.panel(ci, r, Color(0.24, 0.14, 0.43, 0.55), Color(1, 1, 1, 0.6), 3.0, 26)
	return r


## 가로 화면 타임 어택 — 왼쪽 점수 · 최고 · 남은 시간, 오른쪽 피버 · 콤보.
func _draw_hud_ta_wide(ci: CanvasItem) -> void:
	var l := _side_panel(ci, 0)
	var cx := l.get_center().x
	G2.text_mid(ci, Vector2(cx, l.position.y + 40), "점수", 24, Color(1, 1, 1, 0.85), 6)
	G2.text_mid(ci, Vector2(cx, l.position.y + 96), P.n(int(roundf(shown))), 56, P.SCORE, 14)
	G2.text_mid(ci, Vector2(cx, l.position.y + 150), "최고 " + P.n(Sv.best), 24, Color(1, 1, 1, 0.9), 7)
	var bar := Rect2(l.position.x + 20, l.position.y + 200, l.size.x - 40, 30)
	G2.panel(ci, bar, Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.7), 2.5, 15)
	var k := time_left / game_t
	if k > 0.0:
		var fc := Color8(110, 220, 120).lerp(Color8(255, 210, 60), smoothstep(0.6, 0.3, k))
		fc = fc.lerp(P.WARN, smoothstep(0.25, 0.1, k))
		G2.panel(ci, Rect2(bar.position + Vector2(3, 3), Vector2((bar.size.x - 6) * k, bar.size.y - 6)), fc,
				Color(), 0.0, 12)
	G2.text_mid(ci, bar.get_center(), "%d" % ceili(time_left), 24, Color(1, 1, 1), 7)
	var r := _side_panel(ci, 1)
	var rx := r.get_center().x
	var fb := Rect2(r.position.x + 20, r.position.y + 60, r.size.x - 40, 30)
	G2.panel(ci, fb, Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.7), 2.5, 15)
	if fever > 0.0:
		var fcol := P.FEVER if fever_t <= 0.0 else Color.from_hsv(fposmod(t * 1.5, 1.0), 0.55, 1.0)
		G2.panel(ci, Rect2(fb.position + Vector2(3, 3), Vector2((fb.size.x - 6) * fever, fb.size.y - 6)),
				fcol, Color(), 0.0, 12)
	G2.text_mid(ci, fb.get_center(), "피버  x%d" % D.FEVER_MUL if fever_t > 0.0 else "피버", 24, Color(1, 1, 1), 7)
	if combo >= 2:
		G2.text_mid(ci, Vector2(rx, fb.end.y + 60), "콤보 %d" % combo, 40, P.GOLD, 10)


## 가로 화면 스테이지 — 왼쪽 스테이지 번호 · 이동 수 · 미션, 오른쪽 점수 · 별.
func _draw_hud_stage_wide(ci: CanvasItem) -> void:
	var l := _side_panel(ci, 0)
	var cx := l.get_center().x
	G2.text_mid(ci, Vector2(cx, l.position.y + 36), "스테이지 %d" % play.stage.id, 32, Color(1, 1, 1), 9)
	var mc := Vector2(cx, l.position.y + 130)
	var low := play.moves_left <= 5
	ci.draw_circle(mc, 54, P.INK)
	ci.draw_circle(mc, 48, P.WARN if low and fmod(t, 0.8) < 0.4 else Color8(255, 255, 255, 235))
	G2.text_mid(ci, mc + Vector2(0, -6), str(play.moves_left), 46, P.INK)
	G2.text_mid(ci, mc + Vector2(0, 30), "이동", 20, P.INK)
	G2.text_mid(ci, Vector2(cx, l.position.y + 220), "미션", 24, Color(1, 1, 1, 0.85), 6)
	var n := play.goals.size()
	var gh := minf(84.0, (l.end.y - l.position.y - 270.0) / maxf(1, n))
	for k in n:
		var g: Dictionary = play.goals[k]
		var p := Vector2(l.position.x + 70, l.position.y + 280 + k * gh)
		Art.goal_icon(ci, p, 28, g, t)
		var left := play.left(g)
		var q := Vector2(l.end.x - 70, p.y)
		if left <= 0:
			ci.draw_circle(q, 18, Color8(90, 200, 100))
			ci.draw_polyline(PackedVector2Array([q + Vector2(-9, 0), q + Vector2(-2, 7), q + Vector2(9, -7)]),
					Color(1, 1, 1), 5.0, true)
		else:
			G2.text_mid(ci, q, P.n(left), 34, Color(1, 1, 1), 8)
	var r := _side_panel(ci, 1)
	var rx := r.get_center().x
	G2.text_mid(ci, Vector2(rx, r.position.y + 40), "점수", 24, Color(1, 1, 1, 0.85), 6)
	G2.text_mid(ci, Vector2(rx, r.position.y + 96), P.n(int(roundf(shown))), 48, Color(1, 1, 1), 12)
	var marks := play.star_marks()
	var top := float(marks[1]) * 1.15
	var bar := Rect2(r.position.x + 24, r.position.y + 150, r.size.x - 48, 20)
	G2.panel(ci, bar, Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.7), 2.0, 10)
	G2.panel(ci, Rect2(bar.position, Vector2(bar.size.x * clampf(shown / top, 0, 1), bar.size.y)), P.GOLD,
			Color(), 0.0, 10)
	for k in 2:
		var mx := bar.position.x + bar.size.x * float(marks[k]) / top
		Art.star(ci, Vector2(mx, bar.end.y + 22), 15, shown >= float(marks[k]))


func _draw_hud_ta(ci: CanvasItem) -> void:
	if wide():
		_draw_hud_ta_wide(ci)
		return
	var cx := vs.x * 0.5
	var y0 := origin.y - 200
	G2.text_mid(ci, Vector2(cx, y0 + 50), P.n(int(roundf(shown))), 66, P.SCORE, 16)
	G2.text_mid(ci, Vector2(cx, y0 + 100), "최고 " + P.n(Sv.best), 26, Color(1, 1, 1, 0.9), 8)
	var bar := Rect2(40, y0 + 130, vs.x - 80, 26)
	G2.panel(ci, bar, Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.7), 2.5, 13)
	var k := time_left / game_t
	if k > 0.0:
		var fc := Color8(110, 220, 120).lerp(Color8(255, 210, 60), smoothstep(0.6, 0.3, k))
		fc = fc.lerp(P.WARN, smoothstep(0.25, 0.1, k))
		G2.panel(ci, Rect2(bar.position + Vector2(3, 3), Vector2((bar.size.x - 6) * k, bar.size.y - 6)), fc,
				Color(), 0.0, 10)
	G2.text_mid(ci, bar.get_center(), "%d" % ceili(time_left), 24, Color(1, 1, 1), 7)
	var br := _board_rect()
	var fb := Rect2(br.position.x, br.end.y + 34, br.size.x, 30)
	G2.panel(ci, fb, Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.7), 2.5, 15)
	if fever > 0.0:
		var fcol := P.FEVER if fever_t <= 0.0 else Color.from_hsv(fposmod(t * 1.5, 1.0), 0.55, 1.0)
		G2.panel(ci, Rect2(fb.position + Vector2(3, 3), Vector2((fb.size.x - 6) * fever, fb.size.y - 6)),
				fcol, Color(), 0.0, 12)
	G2.text_mid(ci, fb.get_center(), "피버  x%d" % D.FEVER_MUL if fever_t > 0.0 else "피버", 24, Color(1, 1, 1), 7)
	if combo >= 2:
		G2.text_mid(ci, Vector2(br.end.x - 60, fb.end.y + 40), "콤보 %d" % combo, 30, P.GOLD, 9)


## 스테이지 HUD — 왼쪽 이동 수, 가운데 미션, 오른쪽 점수와 별.
func _draw_hud_stage(ci: CanvasItem) -> void:
	if wide():
		_draw_hud_stage_wide(ci)
		return
	var y := origin.y - 120
	G2.text_mid(ci, Vector2(vs.x * 0.5, 44), "스테이지 %d" % play.stage.id, 34, Color(1, 1, 1), 9)
	var mc := Vector2(78, y)
	var low := play.moves_left <= 5
	ci.draw_circle(mc, 54, P.INK)
	ci.draw_circle(mc, 48, P.WARN if low and fmod(t, 0.8) < 0.4 else Color8(255, 255, 255, 235))
	G2.text_mid(ci, mc + Vector2(0, -6), str(play.moves_left), 46, P.INK)
	G2.text_mid(ci, mc + Vector2(0, 30), "이동", 20, P.INK)
	var n := play.goals.size()
	var gw := minf(120.0, (vs.x - 330) / maxf(1, n))
	for k in n:
		var g: Dictionary = play.goals[k]
		var p := Vector2(vs.x * 0.5 + (k - (n - 1) * 0.5) * gw, y - 14)
		Art.goal_icon(ci, p, 30, g, t)
		var left := play.left(g)
		if left <= 0:
			ci.draw_circle(p + Vector2(22, 26), 17, Color8(90, 200, 100))
			ci.draw_polyline(PackedVector2Array([p + Vector2(13, 26), p + Vector2(20, 33), p + Vector2(31, 19)]),
					Color(1, 1, 1), 5.0, true)
		else:
			G2.text_mid(ci, p + Vector2(0, 50), P.n(left), 30, Color(1, 1, 1), 8)
	var sx := vs.x - 150
	G2.text_mid(ci, Vector2(sx + 60, y - 30), P.n(int(roundf(shown))), 34, Color(1, 1, 1), 9)
	var marks := play.star_marks()
	var top := float(marks[1]) * 1.15
	var bar := Rect2(sx, y + 4, 120, 16)
	G2.panel(ci, bar, Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.7), 2.0, 8)
	G2.panel(ci, Rect2(bar.position, Vector2(bar.size.x * clampf(shown / top, 0, 1), bar.size.y)), P.GOLD,
			Color(), 0.0, 8)
	for k in 2:
		var mx := bar.position.x + bar.size.x * float(marks[k]) / top
		Art.star(ci, Vector2(mx, bar.end.y + 16), 12, shown >= float(marks[k]))


func _goal_text(g: Dictionary) -> String:
	match g.type:
		"score":
			return "%s점을 내세요" % P.n(g.need)
		"collect":
			return "%s 젤리 %d개 모으기" % [D.NAMES[g.color], g.need]
		"sugar":
			return "설탕막을 모두 깨세요"
		"box":
			return "쿠키 상자를 모두 부수세요"
		"choco":
			return "초콜릿을 모두 치우세요"
		"ice":
			return "얼음을 모두 깨세요"
		"chain":
			return "사슬을 모두 푸세요"
		"fruit":
			return "열매 %d개를 맨 아래로" % g.need
		"monster":
			return "몬스터를 모두 쓰러뜨리세요"
		"capsule":
			return "캡슐을 모두 깨세요"
		"lock":
			return "자물쇠를 모두 여세요"
		"web":
			return "거미줄을 모두 걷으세요"
		"mole":
			return "두더지를 모두 잡으세요"
		"fire":
			return "모닥불을 한꺼번에 모두 켜세요"
		"paint":
			return "판을 모두 칠하세요"
		"jar":
			return "색 그릇을 모두 채우세요"
		"cloud":
			return "구름을 모두 걷으세요"
	return ""


func _draw_intro(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.03, 0.2, 0.4))
	var n := play.goals.size()
	# 이 판에서 처음 나오는 장애물 — 이름을 적고 어디서 설명을 보는지 알려 준다
	var fresh := []
	for e in Guide.in_stage(play.stage):
		if Guide.first(e.key) == play.stage.id:
			fresh.append(e.name)
	# 가로 화면이면 판 순위를 창 오른쪽에 — 아래로 붙이면 창이 화면 높이를 넘는다
	var side := wide() and Net.enabled
	var h := 310.0 + n * 84.0 + (70.0 if not fresh.is_empty() else 0.0) + (196.0 if Net.enabled and not side else 0.0)
	var pw := 580.0 + (480.0 if side else 0.0)
	var pr := Rect2(vs.x * 0.5 - pw * 0.5, vs.y * 0.5 - h * 0.5, pw, h)
	var cx := pr.position.x + 290.0
	G2.panel(ci, pr, Color(1, 1, 1, 0.95), P.INK, 4.0, 36)
	G2.text_mid(ci, Vector2(cx, pr.position.y + 60), "스테이지 %d" % play.stage.id, 52, P.FEVER, 10)
	for k in n:
		var g: Dictionary = play.goals[k]
		var y := pr.position.y + 140 + k * 84
		Art.goal_icon(ci, Vector2(pr.position.x + 80, y), 30, g, t)
		G2.text_mid(ci, Vector2(pr.position.x + 330, y), _goal_text(g), 32, P.INK)
	if side:
		_draw_stage_rank(ci, Rect2(pr.position.x + 590, pr.position.y + 40, 430, 180), 3)
	elif Net.enabled:
		# 깨기 전에도 이 판 순위를 본다 — 판을 열 때 받아 둔 것(Net.prefetch_stage)
		_draw_stage_rank(ci, Rect2(pr.position.x + 40, pr.position.y + 100 + n * 84, pr.size.x - 80, 180), 3)
	if not fresh.is_empty():
		G2.text_mid(ci, Vector2(cx, pr.end.y - 212), "새 장애물: " + ", ".join(fresh), 30, P.FEVER, 0.0)
		G2.text_mid(ci, Vector2(cx, pr.end.y - 176), "설명은 오른쪽 위 [장애물] 단추", 22, P.a(P.INK, 0.7))
	G2.text_mid(ci, Vector2(cx, pr.end.y - 142), "이동 %d번" % play.moves_left, 36, P.INK)
	var marks := play.star_marks()
	Art.star(ci, Vector2(pr.position.x + 92, pr.end.y - 92), 14, true)
	G2.text_mid(ci, Vector2(cx + 10, pr.end.y - 92),
			"셋 %s점,  남은 이동 하나당 +%d" % [P.n(int(marks[1])), D.BONUS_MOVE_PTS], 26, P.INK)
	var a := 0.55 + 0.45 * sin(t * 4.0)
	G2.text_mid(ci, Vector2(cx, pr.end.y - 40), "터치해서 시작", 34, P.a(P.FEVER, a))

func _draw_result(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.03, 0.2, 0.45))
	var pr := _result_rect()
	G2.panel(ci, pr, Color(1, 1, 1, 0.94), P.INK, 4.0, 36)
	var cx := _res_cx()
	if _rank_box():
		if wide():
			_draw_stage_rank(ci, Rect2(pr.position.x + 570, pr.position.y + 60, pr.size.x - 600, 262))
		else:
			_draw_stage_rank(ci, Rect2(pr.position.x + 30, pr.position.y + 430, pr.size.x - 60, 262))
	if st == St.WIN:
		G2.text_mid(ci, Vector2(cx, pr.position.y + 66), "성공!", 66, P.FEVER, 12)
		for k in 3:
			var pop := G2.out_back(clampf((state_t - 0.3 - k * 0.25) * 3.0, 0.0, 1.0))
			var big := 1.25 if k == 1 else 1.0
			Art.star(ci, Vector2(cx + (k - 1) * 120, pr.position.y + 170 - (14 if k == 1 else 0)),
					46 * big * maxf(pop, 0.6), k < result_stars and pop > 0.0)
		G2.text_mid(ci, Vector2(cx, pr.position.y + 290), P.n(play.score), 76, P.GOLD, 14)
		if new_best:
			G2.text_mid(ci, Vector2(cx, pr.position.y + 360), "최고 기록!", 36, P.FEVER, 8)
		if result_stars < 3:
			var next := int(play.star_marks()[result_stars - 1])
			G2.text_mid(ci, Vector2(cx, pr.position.y + 400),
					"별 %d개까지 %s점, 이동을 더 남기고 깨 보세요" % [result_stars + 1, P.n(maxi(0, next - play.score))], 24, P.INK)
	else:
		G2.text_mid(ci, Vector2(cx, pr.position.y + 66), "아쉬워요", 62, P.INK)
		var n := play.goals.size()
		for k in n:
			var g: Dictionary = play.goals[k]
			var p := Vector2(cx + (k - (n - 1) * 0.5) * 140, pr.position.y + 200)
			Art.goal_icon(ci, p, 40, g, t)
			var left := play.left(g)
			G2.text_mid(ci, p + Vector2(0, 66), "남음 %s" % P.n(left) if left > 0 else "완료", 30,
					P.WARN if left > 0 else Color8(70, 170, 80))
		G2.text_mid(ci, Vector2(cx, pr.position.y + 340), "이동을 다 썼어요", 34, P.INK)
	var last := stage_n + 1 >= Stages.count()
	_btn(ci, _panel_btn(0), ("목록" if last else "다음") if st == St.WIN else "다시 하기", Color8(110, 214, 92))
	if st == St.WIN:
		_btn(ci, _panel_btn(1), "다시", Color8(255, 180, 70), 32)
	_btn(ci, _panel_btn(2), "목록", Color8(150, 150, 220), 32)


func _draw_over(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.03, 0.2, 0.45))
	var pr := Rect2(vs.x * 0.5 - 280, vs.y * 0.5 - 260, 560, 620)
	G2.panel(ci, pr, Color(1, 1, 1, 0.92), P.INK, 4.0, 36)
	var cx := vs.x * 0.5
	G2.text_mid(ci, Vector2(cx, pr.position.y + 70), "끝!", 64, P.FEVER, 12)
	G2.text_mid(ci, Vector2(cx, pr.position.y + 190), P.n(play.score), 92, P.GOLD, 16)
	if new_best:
		var s := 1.0 + 0.08 * sin(t * 8.0)
		G2.text_mid(ci, Vector2(cx, pr.position.y + 280), "최고 기록!", 46 * s, P.FEVER, 12)
	else:
		G2.text_mid(ci, Vector2(cx, pr.position.y + 280), "최고 " + P.n(Sv.best), 34, P.INK)
	_btn(ci, _panel_btn(0), "다시 하기", Color8(110, 214, 92))
	_btn(ci, _panel_btn(2), "처음", Color8(150, 150, 220), 32)


func _draw_title(ci: CanvasItem) -> void:
	# 게임 이름 — 다섯 게임 같은 방식(UiKit.title)
	var below := UiKit.title(ci, vs, "jelly", "젤리팝", "같은 젤리 셋을 이어 터뜨리세요", t)
	# 여섯 종을 한 줄로 — 무엇을 맞추는 게임인지 첫 화면에서 보인다
	var r := minf(vs.x / 16.0, 46.0)
	for k in 6:
		var p := Vector2(_title_x() + (k - 2.5) * r * 2.4, below + 130.0 if wide() else vs.y * 0.44)
		var hop := absf(sin(t * 3.4 + k * 0.7))
		var sq := Vector2(1.0 + (1.0 - hop) * 0.12, 1.0 - (1.0 - hop) * 0.12)
		Art.jelly(ci, p - Vector2(0, hop * r * 0.9), r, k, D.SP_NONE, Art.Face.HAPPY, Vector2.ZERO,
				false, sq, 0.0, 0.0, t + k)
	var labels := ["모험  %d / %d" % [mini(Sv.unlocked(), Stages.count()), Stages.count()], "타임 어택", "장애물 도감",
			"좋은 젤리 도감", "순위"]
	var fills := [Color8(110, 214, 92), Color8(255, 130, 190), Color8(120, 170, 255), Color8(255, 190, 80),
			Color8(190, 140, 255)]
	for k in TITLE_N:
		var rr := _title_btn(k)
		if k == title_sel:
			G2.panel(ci, rr.grow(8), Color(1, 1, 1, 0.35 + 0.15 * sin(t * 5.0)), Color(), 0.0, 36)
		if k == 0:
			UiKit.button(ci, vs, "start", "jelly", t, labels[0])   # 모험 = 시작(다섯 게임 같은 단추)
		else:
			UiKit.menu(ci, rr, labels[k], fills[k], "jelly", t)    # 메뉴 — 다섯 게임 같은 단추, 색만 젤리팝 것
	UiKit.record_line(ci, vs, "별 %d / %d%s" % [Sv.total_stars(), Stages.count() * 3, ("   타임 어택 최고 " + P.n(Sv.best)) if Sv.best > 0 else ""])
	UiKit.button(ci, vs, "vol", "jelly", t)
	UiKit.button(ci, vs, "hub", "jelly", t)
	if Sv.all_open:
		G2.text_mid(ci, Vector2(vs.x * 0.5, 100), "테스트 빌드: 모든 스테이지 열림", 26, P.WARN, 7)
		_btn(ci, _wipe_btn(), "한 번 더 누르면 지워요" if wipe_armed > 0.0 else "기록 지우기",
				P.WARN if wipe_armed > 0.0 else Color8(150, 150, 170), 26)


func _draw_map(ci: CanvasItem) -> void:
	G2.text_mid(ci, Vector2(vs.x * 0.5, 110), "모험", 64, Color(1, 1, 1), 14)
	_btn(ci, _back_rect(), "처음", Color(1, 1, 1, 0.85), 26)
	_btn(ci, _guide_btn(), "도감", Color8(120, 170, 255), 26)
	var open := Sv.unlocked()
	var pg := _map_page()
	G2.text_mid(ci, Vector2(vs.x * 0.5, 165), "%d ~ %d  %s" % [pg * MAP_PAGE + 1, mini((pg + 1) * MAP_PAGE, Stages.count()),
			_page_name(pg)], 30, Color(1, 1, 1), 8)
	var page_col: Array = [Color8(90, 180, 255), Color8(255, 130, 190), Color8(120, 210, 140), Color8(255, 170, 90)]
	for n in range(pg * MAP_PAGE, mini((pg + 1) * MAP_PAGE, Stages.count())):
		var r := _map_rect(n)
		var id := n + 1
		var locked := n >= open
		var fill: Color = Color8(150, 150, 170) if locked else page_col[pg % page_col.size()]
		if n == map_sel:
			G2.panel(ci, r.grow(7), Color(1, 1, 1, 0.4 + 0.2 * sin(t * 6.0)), Color(), 0.0, 24)
		G2.panel(ci, r, fill, P.INK, 3.0, 20)
		G2.text_mid(ci, r.get_center() - Vector2(0, r.size.y * 0.1), str(id), r.size.y * 0.42,
				Color(1, 1, 1, 0.6) if locked else Color(1, 1, 1), 0.0 if locked else 6.0)
		if not locked:
			var s := int(Sv.stars.get(id, 0))
			for k in 3:
				Art.star(ci, r.position + Vector2(r.size.x * (0.25 + 0.25 * k), r.size.y * 0.84), r.size.x * 0.1,
						k < s)
		# 블록 첫 판 — 여기서 처음 나오는 장애물을 귀퉁이에 작게
		if n % StageGen.BLOCK == 0 and StageGen.intro_of(id) != "":
			Guide.icon(ci, StageGen.intro_of(id), r.position + Vector2(r.size.x * 0.06, r.size.y * 0.08), r.size.x * 0.17, t)
	# 쪽 넘김 — 글꼴에 화살표가 없어서 세모를 직접 그린다
	for k in 2:
		var on := (k == 0 and pg > 0) or (k == 1 and pg < _pages() - 1)
		var br := _page_btn(k)
		G2.panel(ci, br, Color(1, 1, 1, 0.85 if on else 0.3), P.INK, 3.0, 24)
		var c := br.get_center()
		var s := 1.0 if k == 1 else -1.0
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 18, 0), c + Vector2(-s * 12, -18), c + Vector2(-s * 12, 18)]),
				P.INK if on else Color(0, 0, 0, 0.25))
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 90), "%d / %d" % [pg + 1, _pages()], 30, Color(1, 1, 1), 8)


## 장애물 도감 — 처음 만나는 순서대로, 한 쪽에 PER_PAGE 개.
func _draw_guide(ci: CanvasItem) -> void:
	var head := guide_title
	if guide_open:
		head = "새 장애물!" if guide_fresh else "이 판의 장애물"
	G2.text_mid(ci, Vector2(vs.x * 0.5, 110), head, 60, Color(1, 1, 1), 14)
	if guide_fresh:
		G2.text_mid(ci, Vector2(vs.x * 0.5, 165), "아무 곳이나 누르면 닫혀요", 26, Color(1, 1, 1, 0.9), 7)
	_btn(ci, _back_rect(), "닫기", Color(1, 1, 1, 0.85), 26)
	var list := guide_list
	var f := P.font()
	for k in Guide.PER_PAGE:
		var n := guide_page * Guide.PER_PAGE + k
		if n >= list.size():
			break
		var e: Dictionary = list[n]
		var row := _guide_row(k)
		G2.panel(ci, row, Color(1, 1, 1, 0.88), P.INK, 3.0, 22)
		var r := row.size.y * 0.3
		Guide.icon_entry(ci, e, Vector2(row.position.x + row.size.y * 0.55, row.get_center().y), r, t + n)
		var x := row.position.x + row.size.y * 1.1
		var y := row.position.y
		# 글자 자리 · 크기는 줄 높이(세로 화면 기준 114)에 비례 — 가로 화면은 두 단이라 줄이 낮다
		var sc := minf(1.0, row.size.y / 114.0)
		ci.draw_string(f, Vector2(x, y + 38 * sc), e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * sc), P.INK)
		var first := Guide.first(e.key)
		if first > 0:
			var tag := "%d번부터" % first
			ci.draw_string(f, Vector2(row.end.x - 16 - f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * sc)).x, y + 36 * sc),
					tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * sc), P.FEVER)
		for j in e.lines.size():
			ci.draw_string(f, Vector2(x, y + (62 + j * 24) * sc), e.lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * sc),
					P.a(P.INK, 0.85))
	# 쪽 넘김 — 목록과 같은 단추 자리
	var np := Guide.pages(list)
	for k in 2:
		var on := (k == 0 and guide_page > 0) or (k == 1 and guide_page < np - 1)
		var br := _page_btn(k)
		G2.panel(ci, br, Color(1, 1, 1, 0.85 if on else 0.3), P.INK, 3.0, 24)
		var c := br.get_center()
		var s := 1.0 if k == 1 else -1.0
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 18, 0), c + Vector2(-s * 12, -18), c + Vector2(-s * 12, 18)]),
				P.INK if on else Color(0, 0, 0, 0.25))
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 90), "%d / %d" % [guide_page + 1, np], 30, Color(1, 1, 1), 8)


## 순위 — 구글 시트에서 받아 온 위 30명. 내 줄은 금색.
func _draw_rank(ci: CanvasItem) -> void:
	G2.text_mid(ci, Vector2(vs.x * 0.5, 110), "순위", 64, Color(1, 1, 1), 14)
	_btn(ci, _back_rect(), "처음", Color(1, 1, 1, 0.85), 26)
	var tabs := ["타임 어택", "모험 점수"]
	for k in 2:
		_btn(ci, _rank_btn(k), tabs[k], Color8(255, 130, 190) if k == rank_tab else Color(1, 1, 1, 0.5), 30)
	var msg := ""
	if not Net.enabled:
		msg = "순위 서버가 연결되지 않은 판입니다"
	elif Net.board_state == "loading" or Net.board_state == "":
		msg = "불러오는 중..."
	elif Net.board_state == "fail":
		msg = "순위를 못 불러왔어요 (인터넷 확인)"
	if msg != "":
		G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y * 0.45), msg, 32, Color(1, 1, 1), 8)
	else:
		var b: Dictionary = Net.board.get("ta" if rank_tab == 0 else "adv", {})
		var top: Array = b.get("top", [])
		if top.is_empty():
			G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y * 0.45), "아직 기록이 없어요", 32, Color(1, 1, 1), 8)
		var f := P.font()
		for k in mini(top.size(), _rank_rows()):
			var row: Array = top[k]
			var r := _rank_row(k)
			var me := bool(row[2]) if row.size() > 2 else false
			G2.panel(ci, r, P.GOLD if me else Color(1, 1, 1, 0.85), P.INK, 2.0, 12)
			var y := r.position.y + 29
			ci.draw_string(f, Vector2(r.position.x + 14, y), "%d" % (k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, P.FEVER)
			ci.draw_string(f, Vector2(r.position.x + 74, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, P.INK)
			var v := P.n(int(row[1]))
			ci.draw_string(f, Vector2(r.end.x - 14 - f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x, y), v,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 26, P.INK)
		var mine := "내 순위 %d / %d" % [int(b.get("me", 0)), int(b.get("total", 0))] if int(b.get("me", 0)) > 0 \
				else "아직 순위에 없어요"
		G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 160), mine, 28, Color(1, 1, 1), 8)
	_btn(ci, _rank_btn(2), "이름: " + Sv.name, Color8(120, 170, 255), 26)
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y - 30), "판 결과와 이름이 개발자의 기록표로 보내져요", 20, Color(1, 1, 1, 0.8), 5)


## 그 판 순위 — 위 max_rows 줄. 내가 그 밖이면 마지막 줄 자리에 내 줄을 넣는다. 결과 창(5줄)과 시작 창(3줄)이 같이 쓴다.
func _draw_stage_rank(ci: CanvasItem, box: Rect2, max_rows: int = 5) -> void:
	G2.panel(ci, box, Color8(245, 235, 255), P.a(P.INK, 0.5), 2.0, 18)
	var f := P.font()
	var b := Net.stage_board
	var me := int(b.get("me", 0))
	var head := "이 판 순위"
	if Net.stage_state == "ok" and me > 0:
		head += "   내 순위 %d / %d" % [me, int(b.get("total", 0))]
	G2.text_mid(ci, Vector2(box.get_center().x, box.position.y + 26), head, 26, P.FEVER)
	var msg := ""
	if Net.stage_state == "loading":
		msg = "불러오는 중..."
	elif Net.stage_state != "ok":
		msg = "순위를 못 불러왔어요"
	elif (b.get("top", []) as Array).is_empty():
		msg = "아직 기록이 없어요"
	if msg != "":
		G2.text_mid(ci, box.get_center() + Vector2(0, 16), msg, 26, P.a(P.INK, 0.7))
		return
	var top: Array = b.top
	var rows := []
	for k in mini(max_rows, top.size()):
		rows.append([k + 1, top[k]])
	if me > max_rows and me <= top.size():
		rows[max_rows - 1] = [me, top[me - 1]]
	for k in rows.size():
		var r := Rect2(box.position.x + 12, box.position.y + 50 + k * 41, box.size.x - 24, 37)
		var row: Array = rows[k][1]
		var mine := bool(row[2]) if row.size() > 2 else false
		G2.panel(ci, r, P.GOLD if mine else Color(1, 1, 1), P.a(P.INK, 0.4), 1.5, 10)
		var y := r.position.y + 28
		ci.draw_string(f, Vector2(r.position.x + 12, y), str(rows[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P.FEVER)
		ci.draw_string(f, Vector2(r.position.x + 64, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P.INK)
		var v := P.n(int(row[1]))
		ci.draw_string(f, Vector2(r.end.x - 12 - f.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, y), v,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, P.INK)


## 처음 켰을 때 — 이름부터 정한다. 순위 · 결과 창에 나오는 이름이다.
func _name_btn() -> Rect2:
	return Rect2(vs.x * 0.5 - 170, vs.y * 0.62, 340, 84)


func _draw_name(ci: CanvasItem) -> void:
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y * 0.3), "어서 오세요!", 72, Color(1, 1, 1), 16)
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y * 0.3 + 90), "순위에 쓸 이름을 정해 주세요", 34, Color(1, 1, 1), 9)
	G2.text_mid(ci, Vector2(vs.x * 0.5, vs.y * 0.3 + 140), "10자까지, 나중에 순위 화면에서 바꿀 수 있어요", 24,
			Color(1, 1, 1, 0.9), 7)
	if name_edit == null:
		_btn(ci, _name_btn(), "이름 입력", Color8(110, 214, 92), 40)
	else:
		_btn(ci, _name_btn(), "확인", Color8(110, 214, 92), 40)
		G2.text_mid(ci, Vector2(vs.x * 0.5, _name_btn().end.y + 40), "입력하고 Enter", 24, Color(1, 1, 1, 0.9), 7)
