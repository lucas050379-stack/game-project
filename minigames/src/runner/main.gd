extends Node2D

## 월드 러너 — 진입점. 화면 배치 · 트윈 · 턴 진행 · 입력 · 그리기.
##
## 원본 세계마뷸(C# WinForms)의 `GameForm` 은 `async/await` 로 턴을 흘렸다. GDScript 도 `await` 가
## 있어서 **흐름을 거의 줄 단위로 옮겼다** — `await tween(...)` 은 트윈이 끝날 때까지,
## `await _ask(...)` 은 단추를 누를 때까지 그 자리에서 기다린다.
##
## **게임을 도중에 버릴 때(다시 하기 · 게임 선택)는 `_reset()` 하나만 부르세요.** 기다리던 트윈 ·
## 단추 · 창을 전부 비우면 거기 매달려 있던 진행 함수가 다시 깨어나지 않고 조용히 사라집니다.
## 하나라도 남기면 옛 판의 턴이 새 판 위에서 계속 돕니다.
##
## 세로 화면(720×1280)에 맞춰 원본의 "왼쪽 판 + 오른쪽 플레이어 패널"을
## **위 판 + 아래 플레이어 카드 2×2** 로 바꿨다. 판 가운데(로고 · 기금 · 주사위 · 단추 · 기록)는 원본 그대로다.
##
## **화면 글자에 `·` `—` `×` `→` `₩` 를 쓰지 마세요**(Jua 글꼴에 없음). `WrIcons.clean` 이 바꿔 주긴 합니다.

enum Scr { SETUP, PLAY, OVER }

const FS_TINY := 19.0
const FS_SMALL := 22.0
const FS_BODY := 26.0
const FS_SUB := 30.0
const FS_TITLE := 40.0
const FS_HUGE := 56.0


## 트윈 하나. 끝나면 `done` 을 낸다 — `await tw.done` 으로 기다린다.
class Tw:
	extends RefCounted
	signal done
	var t := 0.0
	var dur := 0.0
	var ease: Callable
	var apply: Callable


## 단추 · 창의 선택을 기다리는 것.
class Waiter:
	extends RefCounted
	signal chosen(i: int)


class Modal:
	extends RefCounted
	var title := ""
	var body := ""
	var cell: WrD.Cell = null
	var chance: Array = []
	var accent := WrD.ACCENT
	var buttons: Array = []
	var t := 0.0
	var flip := 1.0
	var vertical := false
	var who: WrGame.Player = null
	var waiter := Waiter.new()


var g: WrGame
var fx := WrFx.new()
var scr := Scr.SETUP
var anims: Array = []
var buttons: Array = []     ## 판 가운데 단추. {label, sub, col, primary, enabled, hover, press, in, rect, idx, waiter}
var modal: Modal = null
var gen := 0                ## 판 번호 — `_reset` 이 올린다

var time := 0.0
var speed := 1.0
var mouse := Vector2(-999, -999)
var vs := Vector2(720, 1280)

# 판 배치 — **판은 월드 좌표(비스듬히 내려다본 마름모)에 그리고 카메라가 지금 차례인 말을 따라간다.**
# 세로 화면에 마름모 판을 통째로 넣으면 칸이 손톱만 해져서, 판을 화면보다 크게 두고 움직인다.
# 판 전체가 보여야 할 때(시작 소개 · 우주여행 칸 고르기 · 게임 끝)만 줌을 뺀다.
const HW := 64.0       ## 판 1칸 폭이 화면에서 차지하는 가로 반폭(월드)
const HH := 38.0       ## 세로 반높이 — 2:1 보다 조금 세워 칸 위 글자를 읽기 쉽게
const DEPTH := 9.0     ## 칸 블록 두께 — 납작해야 판에 붙어 있어 보인다. 두꺼우면 칸이 떠 보인다
const CELL_GAP := 0.05 ## 칸 사이 틈(판 단위)
const LM_HALF := 0.3   ## 그림 랜드마크 받침대의 반폭(판 단위) — 건물 자리가 칸 끝에서 0.36 안쪽이라 이보다 크면 칸 밖으로 나간다
const LABEL_BACK := 0.29  ## 칸 글을 앞쪽으로 비키는 양 — 건물 받침이 이름을 덮지 않게(0.2 이면 랜드마크가 도시명을 가렸다)
const SEAT_GAP := 0.5    ## 한 칸에 같이 선 말의 좌우 간격(칸 반폭 HW 대비)
## **변의 칸은 판 안쪽으로 길쭉하다**(폭 1 · 깊이 SIDE_D). 모서리 칸은 CORNER × CORNER 정사각형이고
## **변의 칸보다 깊어서 안팎으로 튀어나온다**(사용자 참고 화면 11-05 — 모서리가 판의 네 기둥으로 읽힌다).
## 정사각형 칸이면 이름과 금액을 두 줄로 넣을 자리가 없다 — 길쭉해야 글이 칸을 따라 크게 눕는다.
const CORNER := 1.85
const SIDE_D := 1.32   ## 변의 칸 깊이 — 모서리 띠 한가운데에 놓인다
const BL := CORNER * 2.0 + 7.0   ## 판 한 변의 길이(판 단위)
var cs := 86.0          ## 이펙트 크기 기준(칸 하나 크기쯤)
var view := Rect2()     ## 판이 보이는 화면 영역(위아래 플레이어 패널 사이)
var cam := Vector2(0, 9 * 44.0)
var zoom := 0.5
var zoom_full := true
# 사람이 움직이는 시야 — 끌기(시야) · 휠(배율)
const DRAG_SLOP := 12.0   ## 이만큼 안 움직이고 떼면 칸 클릭
const ZOOM_MAX := 2.2
const ZOOM_STEP := 1.12   ## 휠 한 칸의 배율
var user_zoom := 0.0      ## 휠로 고른 배율(0 = 고른 적 없음)
var free_view := false    ## 끌어서 옮긴 시야를 유지하는 중
var free_pid := -1        ## 시야를 옮길 때의 차례 — 차례가 바뀌면 풀린다
var drag_on := false
var drag_moved := false
var drag_from := Vector2.ZERO
var drag_last := Vector2.ZERO
var dice_r := Rect2()   ## 화면 좌표
var action_r := Rect2() ## 화면 좌표 — 단추 줄
var ui_fx := WrFx.new() ## 화면에 붙는 이펙트(색종이 · 동전 비 · 단추 반짝임). `fx` 는 판(월드)에 붙는다

# 주사위
var die1 := 1
var die2 := 1
var die_rot1 := 0.0
var die_rot2 := 0.0
var die_scale := 1.0
var dice_visible := false
var dice_rolling := false
var dice_rolled := false
var dice_glow := 0.0

# 배너
var banner_text := ""
var banner_sub := ""
var banner_col := WrD.ACCENT
var banner_t := 0.0

var prompt := ""

# 칸 고르기(우주여행)
var picking := false
var pick_filter: Callable
var pick_waiter: Waiter = null
var hover_cell := -1
var info_cell := -1         ## 눌러서 띄운 칸 정보(터치에는 마우스 올리기가 없다)

# 시작 화면
var setup_count := 4
var setup_ai := [false, true, true, true]
var intro_t := 0.0
var setup_btns: Array = []
var setup_open := false     ## 처음 화면 "플레이어 설정" 창이 떠 있나(인원 · 사람/AI 는 이 창 안)
var book := UiBook.new()    ## (쓰지 않음 — 도감 · 순위 메뉴를 뺐다)
var rules := UiRules.new()  ## 규칙서 — 처음 화면의 [규칙] 단추

var over_t := 0.0
var over_btns: Array = []
var quit_ask := false       ## "그만둘까요?" 창
var quit_btns: Array = []

# 확인용
var auto := false           ## --runner-auto: 네 명 다 AI, 빠르게 한 판
var auto_human := false    ## --runner-auto-human: 0번 자리는 사람(단추를 대신 누른다)
var auto_cd := 0.0
var auto_speed := 16.0      ## --runner-speed=N: 자동 주행 배속(검산 tools/runner_check.sh 는 크게 준다)
var shot_path := ""
var shot_at := 0.0
var peek := -1             ## --peek=N: N번 칸 도시 카드 창을 띄운 채로(캡처용)
var drag_test := false     ## --runner-drag-test: 끌기 · 휠 · 칸 클릭 검사
var dt_frame := 0
var dt_cam := Vector2.ZERO
var dt_world := Vector2.ZERO
var dt_cell := -1
var play_now := false      ## --runner-play: 시작 화면 없이 기본 구성(사람 1 + AI 3)으로 바로(캡처용)
var all_lm := false        ## --runner-all-lm: 모든 도시에 랜드마크, 주인은 돌아가며(캡처용 — 그림 확인)


func _ready() -> void:
	Bgm.use("runner")
	# 모래 무늬(runner_tile_sand)가 UV 1 을 넘겨 반복된다. 다른 그림은 UV 0~1 이라 영향이 없다
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for a in OS.get_cmdline_user_args():
		if a == "--runner-auto":
			auto = true
		elif a == "--runner-auto-human":
			auto = true
			auto_human = true
		elif a.begins_with("--runner-speed="):
			auto_speed = maxf(1.0, float(a.substr(15)))
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
		elif a.begins_with("--peek="):
			peek = int(a.substr(7))
		elif a.begins_with("--menu="):   # 확인용 — 처음 화면 N번 메뉴(설정 창 · 도감 · 순위)를 바로 연다
			_menu.call_deferred(int(a.substr(7)))
		elif a == "--runner-play":
			play_now = true
		elif a == "--runner-drag-test":
			play_now = true
			drag_test = true
		elif a == "--runner-all-lm":
			play_now = true
			all_lm = true
	_lay()
	_build_setup()
	if auto:
		# 사람 자리도 단추를 대신 눌러 준다(_auto_step) — 사람 쪽 창 , 칸 고르기 경로까지 돈다
		setup_ai = [false, true, true, true] if auto_human else [true, true, true, true]
		speed = auto_speed
		_begin.call_deferred()
	elif play_now:
		_begin.call_deferred()
	elif peek >= 0:
		# 캡처용 — 판을 열고 그 칸의 도시 카드 창을 띄운다(창 배치를 눈으로 보려고)
		_peek_open.call_deferred()


func _exit_tree() -> void:
	WrIcons.base = Transform2D.IDENTITY

# ==================== 배치 ====================


const PANEL_H := 132.0


## 가로 화면 — 판(마름모)이 화면 높이를 다 쓰고, 상태창은 마름모 바깥의 빈 네 모서리에 세로 화면 크기 그대로 둔다
## (사용자 결정 11-04: 상태창이 위아래 줄을 통째로 막으면 판이 작아진다).
func wide() -> bool:
	return vs.x > vs.y * 1.15


func card_w() -> float:
	return minf((vs.x - 30.0) * 0.5, 360.0)


func _lay() -> void:
	vs = get_viewport_rect().size
	if wide():

		view = Rect2(0, 10, vs.x, vs.y - 20)
		# 단추 · 주사위는 판 한가운데 빈 잔디에 — 아래 끝에 두면 출발 칸을 덮는다
		action_r = Rect2(vs.x * 0.5 - 240, vs.y * 0.5 + 4, 480, 104)
	else:
		var top := PANEL_H + 20.0
		var bottom := vs.y - PANEL_H - 24.0
		view = Rect2(0, top, vs.x, bottom - top)
		action_r = Rect2(30, bottom - 120, vs.x - 60, 104)
	dice_r = Rect2(vs.x * 0.5 - 170, action_r.position.y - 18, 340, 140) if wide() else Rect2(vs.x * 0.5 - 170, action_r.position.y - 150, 340, 140)


## 판 좌표 (u = 열 쪽, v = 행 쪽, 단위는 변의 칸 폭) → 월드. u 가 늘면 오른쪽 아래, v 가 늘면 왼쪽 아래.
## 출발(행 8 · 열 8)이 마름모 맨 아래, 무인도가 왼쪽, 우주여행이 맨 위, 기금 수령이 오른쪽 꼭짓점.
static func iso(c: float, r: float) -> Vector2:
	return Vector2((c - r) * HW, (c + r) * HH)


## 격자 번호(0~8) → 판 좌표 구간. 0 · 8 은 모서리라 CORNER 폭, 나머지는 1.
static func _span(k: int) -> Vector2:
	if k == 0:
		return Vector2(0.0, CORNER)
	if k == WrD.GRID - 1:
		return Vector2(BL - CORNER, BL)
	return Vector2(CORNER + k - 1, CORNER + k)


## 칸이 차지하는 판 좌표 사각형(x = u, y = v).
func cell_box(i: int) -> Rect2:
	var gp := WrD.grid_pos(i)
	var su := _span(gp.y)
	var sv := _span(gp.x)
	if not g.cells[i].is_corner():
		var inset := (CORNER - SIDE_D) * 0.5
		if gp.y == 0 or gp.y == WrD.GRID - 1:
			su = Vector2(su.x + inset, su.y - inset)
		else:
			sv = Vector2(sv.x + inset, sv.y - inset)
	return Rect2(su.x, sv.x, su.y - su.x, sv.y - sv.x)


func cell_center(i: int) -> Vector2:
	var b := cell_box(i).get_center()
	return iso(b.x, b.y)


## 칸 둘레의 월드 사각형 — 이펙트 자리 · 크기용(칸 모양은 마름모지만 이펙트는 이걸로 충분하다).
func cell_rect(i: int) -> Rect2:
	var c := cell_center(i)
	return Rect2(c - Vector2(cs, cs) * 0.5, Vector2(cs, cs))


## 칸 윗면(월드) — 판 좌표 사각형을 틈만큼 줄여 기울인 평행사변형. [위, 오른쪽, 아래, 왼쪽] 꼭짓점 순.
func cell_diamond(i: int) -> PackedVector2Array:
	var b := cell_box(i)
	# 모서리 칸은 다른 칸보다 5% 크게 그린다(사용자 결정) — 판 좌표 · 클릭 판정은 그대로
	b = b.grow(b.size.x * 0.025 - CELL_GAP) if g.cells[i].is_corner() else b.grow(-CELL_GAP)
	return PackedVector2Array([iso(b.position.x, b.position.y), iso(b.end.x, b.position.y), iso(b.end.x, b.end.y),
			iso(b.position.x, b.end.y)])


func world_xf() -> Transform2D:
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, view.get_center() - cam * zoom)


func to_screen(w: Vector2) -> Vector2:
	return world_xf() * w


## 화면 점 → 칸 번호(-1 = 판 밖). 그리기와 같은 `world_xf` 를 거꾸로 쓴다.
func _cell_at(p: Vector2) -> int:
	var w := world_xf().affine_inverse() * p
	var uv := Vector2((w.x / HW + w.y / HH) * 0.5, (w.y / HH - w.x / HW) * 0.5)
	for i in WrD.BOARD_SIZE:
		if cell_box(i).has_point(uv):
			return i
	return -1


## 플레이어 패널 — 화면 네 모서리. **0(사람 · 빨강)은 오른쪽 아래**(사용자 요청 11-08), 나머지는 시계 방향으로
## 1 왼쪽 아래 · 2 왼쪽 위 · 3 오른쪽 위.
func card_rect(i: int, _n: int = 4) -> Rect2:
	var w := card_w()
	match i:
		0:
			return Rect2(vs.x - w - 10, vs.y - PANEL_H - 12, w, PANEL_H)
		1:
			return Rect2(10, vs.y - PANEL_H - 12, w, PANEL_H)
		2:
			return Rect2(10, _card_top(), w, PANEL_H)
	return Rect2(vs.x - w - 10, _card_top(), w, PANEL_H)


## 위쪽 상태창 둘의 윗변 — 가로 화면은 맨 위 줄을 "나가기"(왼쪽 위) · "음량"(오른쪽 위) 단추에 내주고 그 아래로 내려온다(다른 게임과 같은 단추 자리).
func _card_top() -> float:
	return 76.0 if wide() else 10.0


## 말이 서 있는 자리(월드, 발밑). 이동 중의 포물선 포함. 한 칸에 넷이 서도 안 겹치게 앞뒤좌우로 벌린다.
## 말이 한 칸에 같이 서면 나란히 벌린다. 몸이 커서 조금 비키는 것으로는 넷 중 둘이 가려졌다. 자리는 부드럽게 옮긴다.
func _step_seats(dt: float) -> void:
	for p: WrGame.Player in g.players:
		var same: Array = g.players.filter(func(o): return o.alive and o.pos == p.pos)
		var i := same.find(p)
		var want := Vector2((i - (same.size() - 1) * 0.5) * HW * SEAT_GAP, HH * 0.14 * (i % 2)) if i >= 0 else Vector2.ZERO
		p.seat = p.seat.lerp(want, minf(1.0, dt * 10.0))


func token_point(p: WrGame.Player) -> Vector2:
	var bp: Vector2
	if p.hop_t >= 0.0:
		var a := cell_center(p.hop_from)
		var b := cell_center(p.hop_to)
		var t := p.hop_t
		bp = a.lerp(b, t) - Vector2(0, sin(t * PI) * cs * 0.7)
	else:
		bp = cell_center(p.pos)
	if p.jump_pt != Vector2.INF:
		bp = p.jump_pt
	var bob := sin(p.bob) * 2.0
	return bp + p.seat + Vector2(0, bob)


func _corner_y() -> float:
	return view.position.y + 6


## 가로 화면: 나가기 = 왼쪽 위 · 음량 = 오른쪽 위(Hub.std_rect — 다른 게임과 같은 자리), 속도는 음량 왼쪽.
func _speed_rect() -> Rect2:
	return Rect2(vs.x - 316, 18, 120, 52) if wide() else Rect2(vs.x - 134, _corner_y(), 120, 50)


func _menu_rect() -> Rect2:
	return Hub.std_rect("hub", vs) if wide() else Rect2(14, _corner_y(), 120, 50)


func _vol_play_rect() -> Rect2:
	return Hub.std_rect("vol", vs) if wide() else Rect2(vs.x - 264, _corner_y(), 120, 50)


## 판 전체가 화면에 드는 배율.
func _fit_zoom() -> float:
	var board_w := 2.0 * BL * HW + 80.0
	var board_h := 2.0 * BL * HH + DEPTH + 120.0
	return minf(view.size.x / board_w, view.size.y / board_h)


## 카메라 — 지금 차례인 말을 부드럽게 따라간다. 판 밖이 너무 많이 비치지 않게 묶는다.
## 사람이 끌어서 옮긴 시야(free_view)는 말이 움직이거나 차례가 바뀌면 풀린다. 휠로 고른 배율(user_zoom)은 판 끝까지 남는다.
func _step_camera(dt: float) -> void:
	var fit := _fit_zoom()
	var tz := 1.1   # 따라갈 때 배율 — 1 이면 칸이 크지만 앞뒤 칸이 화면 밖으로 나가 다음 칸을 못 본다
	var target := Vector2(0, BL * HH)
	if g == null or zoom_full or picking or scr == Scr.OVER or (wide() and user_zoom <= 0.0):
		tz = fit
	else:
		target = token_point(g.current()) + Vector2(0, -30)
	if g != null and scr == Scr.PLAY and not picking:
		if user_zoom > 0.0:
			tz = clampf(user_zoom, fit, ZOOM_MAX)
		if free_view and (g.current().id != free_pid or g.current().hop_t >= 0.0):
			free_view = false
		if free_view:
			target = cam
	var k := 1.0 - exp(-dt * 4.0)
	zoom = lerpf(zoom, tz, k)
	var half := view.size * 0.5 / zoom
	var lim_x := maxf(0.0, BL * HW + 60.0 - half.x)
	target.x = clampf(target.x, -lim_x, lim_x)
	var top := -60.0 + half.y
	# 아래쪽은 굴리기 단추 몫만큼 더 내려갈 수 있게 — 안 그러면 출발 칸 근처 말이 단추 뒤에 숨는다
	var bot := 2.0 * BL * HH + 80.0 + (view.end.y - action_r.position.y) / zoom - half.y
	target.y = clampf(target.y, minf(top, BL * HH), maxf(bot, BL * HH))
	cam = cam.lerp(target, k)

# ==================== 트윈 ====================


static func e_lin(t: float) -> float:
	return t


static func e_in_quad(t: float) -> float:
	return t * t


static func e_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func e_out_cubic(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u


static func e_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	var u := -2.0 * t + 2.0
	return 1.0 - u * u * u / 2.0


static func e_out_quint(t: float) -> float:
	var u := 1.0 - t
	return 1.0 - u * u * u * u * u


static func e_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	var u := t - 1.0
	return 1.0 + c3 * u * u * u + c1 * u * u


func tween(dur: float, ease: Callable, apply: Callable) -> Signal:
	var a := Tw.new()
	a.dur = dur
	a.ease = ease
	a.apply = apply
	anims.append(a)
	return a.done


func tween_ff(dur: float, ease: Callable, apply: Callable) -> void:
	tween(dur, ease, apply)


func delay(sec: float) -> Signal:
	return tween(sec, e_lin, Callable())


func _step_anims(dt: float) -> void:
	var fin: Array = []
	for a: Tw in anims.duplicate():
		a.t += dt
		var k := 1.0 if a.dur <= 0.0 else minf(1.0, a.t / a.dur)
		if a.apply.is_valid():
			a.apply.call(a.ease.call(k))
		if k >= 1.0:
			fin.append(a)
	for a: Tw in fin:
		anims.erase(a)
	for a: Tw in fin:
		a.done.emit()

# ==================== 루프 ====================


func _process(dt_real: float) -> void:
	dt_real = minf(dt_real, 0.1)
	# 상황 음악(11-09): 마지막 다섯 라운드이거나 내 현금이 바닥(50 아래)이면 급박 변주
	Bgm.mood(scr == Scr.PLAY and g != null and (g.round_n > WrD.MAX_ROUND - 5 or g.players[0].cash < 50))
	var dt := dt_real * speed
	_lay()
	time += dt_real
	intro_t += dt_real
	if scr == Scr.OVER:
		over_t += dt_real
	_step_anims(dt)
	fx.step(dt)
	if banner_t > 0.0:
		banner_t -= dt_real * minf(speed, 2.0)
	for list in [buttons, setup_btns, over_btns, quit_btns]:
		_step_btns(list, dt_real)
	if modal != null:
		_step_btns(modal.buttons, dt_real)
		modal.t = minf(1.0, modal.t + dt_real * 5.5)
	if g != null:
		for p: WrGame.Player in g.players:
			p.bob += dt_real * 3.2
			if p.emote > 0.0:
				p.emote -= dt_real
			else:
				p.emote_kind = 0
			p.shown_cash += (p.cash - p.shown_cash) * minf(1.0, dt_real * 7.0)
			if absf(p.shown_cash - p.cash) < 0.4:
				p.shown_cash = p.cash
		g.fund_shown += (g.fund - g.fund_shown) * minf(1.0, dt_real * 6.0)
		for c: WrD.Cell in g.cells:
			c.own_wave = maxf(0.0, c.own_wave - dt_real * 1.6)
			c.shake = maxf(0.0, c.shake - dt_real * 4.0)
		dice_glow = maxf(0.0, dice_glow - dt_real * 1.2)
	hover_cell = -1
	if scr == Scr.PLAY and modal == null and view.has_point(mouse) and not (drag_on and drag_moved):
		hover_cell = _cell_at(mouse)
	if g != null:
		_step_seats(dt_real)
	_step_camera(dt_real)
	ui_fx.step(dt)
	if auto:
		_auto_step(dt_real)
	if drag_test:
		_drag_test_step()
	if shot_path != "" and shot_at > 0.0 and time >= shot_at:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	queue_redraw()


func _step_btns(list: Array, dt: float) -> void:
	for b: Dictionary in list:
		var br: Rect2 = b.rect
		var hot: bool = b.enabled and br.has_point(mouse)
		b.hover += ((1.0 if hot else 0.0) - b.hover) * minf(1.0, dt * 12.0)
		b.press = maxf(0.0, b.press - dt * 4.0)
		b.inn = minf(1.0, b.inn + dt * 6.0)


## --runner-auto: 사람 쪽 단추도 대신 누른다(으뜸 단추, 없으면 첫째). 창 · 칸 고르기 경로까지 같이 돈다.
## --runner-drag-test: 진짜 마우스 이벤트로 끌기 · 휠 · 칸 클릭(입력은 다음 프레임에 처리되므로 단계마다 몇 프레임 쉰다).
func _drag_test_step() -> void:
	user_zoom = maxf(user_zoom, 1.1)   # 가로 화면 기본은 판 전체라 끌 곳이 없다 — 확대한 상태에서 잰다
	if g == null or buttons.is_empty() or modal != null or zoom_full or zoom < 1.0:
		return
	dt_frame += 1
	if dt_frame % 6 != 0:
		return
	var xf := get_viewport().get_final_transform()
	var a := view.get_center() + Vector2(0, -60)
	match dt_frame / 6:
		1:
			dt_cam = cam
			_send_btn(xf * a, true, MOUSE_BUTTON_LEFT)
		2:
			var mv := InputEventMouseMotion.new()
			mv.position = xf * (a + Vector2(160, 70))
			Input.parse_input_event(mv)
		3:
			_send_btn(xf * (a + Vector2(160, 70)), false, MOUSE_BUTTON_LEFT)
		4:
			_drag_check((cam - dt_cam).length() > 50.0 and free_view and info_cell == -1, "끌기")
			dt_world = world_xf().affine_inverse() * a
			dt_cam.x = zoom
			_send_btn(xf * a, true, MOUSE_BUTTON_WHEEL_UP)
		5:
			_drag_check(zoom > dt_cam.x and (world_xf().affine_inverse() * a).distance_to(dt_world) < 2.0, "휠")
			for i in WrD.BOARD_SIZE:
				var p := to_screen(cell_center(i))
				if view.grow(-160).has_point(p) and _cell_at(p) == i:
					dt_cell = i
					_send_btn(xf * p, true, MOUSE_BUTTON_LEFT)
					_send_btn(xf * p, false, MOUSE_BUTTON_LEFT)
					break
		6:
			_drag_check(dt_cell >= 0 and info_cell == dt_cell, "칸 클릭")
			print("DRAG TEST OK")
			get_tree().quit(0)


func _send_btn(p: Vector2, down: bool, which: int) -> void:
	var b := InputEventMouseButton.new()
	b.position = p
	b.button_index = which
	b.pressed = down
	Input.parse_input_event(b)


func _drag_check(ok: bool, what: String) -> void:
	if not ok:
		print("DRAG TEST FAIL — ", what)
		get_tree().quit(1)


func _auto_step(dt: float) -> void:
	auto_cd -= dt * speed
	if auto_cd > 0.0:
		return
	auto_cd = 0.15
	if picking and pick_waiter != null:
		var ok: Array = []
		for c: WrD.Cell in g.cells:
			if not pick_filter.is_valid() or pick_filter.call(c):
				ok.append(c.index)
		var w := pick_waiter
		picking = false
		pick_waiter = null
		w.chosen.emit(ok[randi() % ok.size()])
		return
	var list: Array = modal.buttons if modal != null else buttons
	if scr == Scr.OVER and not over_btns.is_empty():
		var win := g.winner
		# tools/runner_check.sh 가 이 줄을 읽는다 — 꼴을 바꾸면 거기도 같이
		print("RUNNER AUTO OK — %s 승리, 라운드 %d, 자리 %d" % [win.name if win != null else "없음", g.round_n,
				g.players.find(win) if win != null else -1])
		get_tree().quit(0)
		return
	for b: Dictionary in list:
		if b.enabled and b.primary:
			_press(b)
			return
	for b: Dictionary in list:
		if b.enabled:
			_press(b)
			return

# ==================== 단추 ====================


func _btn(label: String, sub: String, col: Color, primary: bool, idx: int, waiter: Waiter,
		enabled: bool = true) -> Dictionary:
	return {"label": label, "sub": sub, "col": col, "primary": primary, "enabled": enabled, "hover": 0.0,
			"press": 0.0, "inn": 0.0, "rect": Rect2(), "idx": idx, "waiter": waiter, "act": Callable()}


func _press(b: Dictionary) -> void:
	b.press = 1.0
	var r: Rect2 = b.rect
	ui_fx.sparkle(r.get_center().x, r.get_center().y, 6, b.col, 12)
	Snd.play("pop")
	var act: Callable = b.act
	if act.is_valid():
		act.call()
	elif b.waiter != null:
		(b.waiter as Waiter).chosen.emit(b.idx)


## [라벨, 아래 글, 색, 으뜸] 목록으로 판 가운데 단추를 띄우고 누를 때까지 기다린다.
func _wait_buttons(specs: Array) -> int:
	var w := Waiter.new()
	buttons = []
	for i in specs.size():
		var s: Array = specs[i]
		var b := _btn(s[0], s[1], s[2], s[3], i, w)
		b.round = s.size() > 4 and s[4]   # 다섯째 칸 = 큰 원 단추(굴리기)
		buttons.append(b)
	var r: int = await w.chosen
	buttons = []
	return r


func _ask(title: String, body: String, cell: WrD.Cell, chance: Array, accent: Color, specs: Array,
		vertical: bool = false) -> int:
	var m := Modal.new()
	m.title = title
	m.body = body
	m.cell = cell
	m.chance = chance
	m.accent = accent
	m.vertical = vertical
	if not chance.is_empty():
		m.flip = 0.0
	for i in specs.size():
		var s: Array = specs[i]
		m.buttons.append(_btn(s[0], s[1], s[2], s[3], i, m.waiter))
	modal = m
	if not chance.is_empty():
		await delay(0.15)
		await tween(0.55, e_out_cubic, func(t): m.flip = t)
		ui_fx.sparkle(vs.x / 2, vs.y / 2, 14, WrD.GOLD, 60)
	var r: int = await m.waiter.chosen
	await _close_modal(m)
	return r


func _close_modal(m: Modal) -> void:
	await tween(0.18, e_in_quad, func(t): m.t = 1.0 - t)
	if modal == m:
		modal = null


## AI 판단을 잠깐 보여 주는 카드
func _peek(c: WrD.Cell, p: WrGame.Player, decision: String, col: Color) -> void:
	var m := Modal.new()
	m.title = c.name
	m.body = decision
	m.cell = c
	m.accent = col
	m.who = p
	modal = m
	await delay(0.85)
	await _close_modal(m)


func _show_chance(card: Array, p: WrGame.Player, dur: float) -> void:
	var m := Modal.new()
	m.title = "황금열쇠"
	m.chance = card
	m.accent = WrD.GOLD
	m.flip = 0.0
	m.who = p
	modal = m
	await delay(0.12)
	await tween(0.5, e_out_cubic, func(t): m.flip = t)
	ui_fx.sparkle(vs.x / 2, vs.y / 2, 14, WrD.GOLD, 60)
	await delay(dur)
	await _close_modal(m)


func _banner(text: String, sub: String, c: Color, dur: float) -> Signal:
	banner_text = text
	banner_sub = sub
	banner_col = c
	banner_t = dur
	return delay(minf(dur, 0.55))


func _pick_cell(filter: Callable) -> int:
	picking = true
	pick_filter = filter
	pick_waiter = Waiter.new()
	var r: int = await pick_waiter.chosen
	return r

# ==================== 시작 화면 ====================


func _build_setup() -> void:
	setup_btns = []
	var start := _btn("게임 시작", "", Color8(34, 197, 94), true, 0, null)
	start.act = _begin
	setup_btns.append(start)
	var minus := _btn("-", "", WrD.PANEL_HI, false, 0, null)
	minus.act = func(): setup_count = maxi(2, setup_count - 1)
	setup_btns.append(minus)
	var plus := _btn("+", "", WrD.PANEL_HI, false, 0, null)
	plus.act = func(): setup_count = mini(4, setup_count + 1)
	setup_btns.append(plus)
	for i in 4:
		var k := i
		var b := _btn("", "", WrD.PANEL_HI, false, 0, null)
		b.act = func(): setup_ai[k] = not setup_ai[k]
		setup_btns.append(b)
	var hub := _btn("게임 선택", "", WrD.PANEL_HI, false, 0, null)
	hub.act = func(): Hub.leave(self)
	setup_btns.append(hub)
	var vol := _btn("설정", "", WrD.PANEL_HI, false, 0, null)
	vol.act = func(): Vol.open = true
	setup_btns.append(vol)
	# 9~12 처음 화면 메뉴(다섯 게임 같은 구조 — 모드 · 도감 · 도감 · 순위), 13 플레이어 설정 창의 "닫기"
	var labels := ["플레이어 설정", "도시 도감", "황금열쇠 도감", "순위"]
	for j in 4:
		var mj := j
		var mb := _btn(labels[j], "", MENU_COL[j], false, 0, null)
		mb.act = func(): _menu(mj)
		setup_btns.append(mb)
	var done := _btn("닫기", "", Color8(34, 197, 94), false, 0, null)
	done.act = func(): setup_open = false
	setup_btns.append(done)


const MENU_COL := [Color8(60, 120, 210), Color8(40, 160, 130), Color8(214, 160, 40), Color8(130, 90, 200)]
const KEY_KIND := {"goto": "이동", "jail": "무인도", "gain": "받기", "lose": "내기", "birthday": "생일", "donate": "기부",
		"fundget": "기금", "escape": "탈출권", "back": "뒤로", "repair": "유지비", "rent": "수익"}


## 처음 화면 메뉴 j — 0 플레이어 설정(창) · 1 도시 도감 · 2 황금열쇠 도감 · 3 순위.
func _menu(j: int) -> void:
	book.game = "runner"
	match j:
		0:
			setup_open = true


## 황금열쇠 도감 그림 — 금빛 열쇠.
func _key_icon(ci: CanvasItem, r: Rect2, tt: float) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.3
	var gold := WrD.GOLD
	ci.draw_arc(c + Vector2(-s * 0.7, 0), s * 0.5, 0, TAU, 24, gold, s * 0.24, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.12), Vector2(s * 1.5, s * 0.24)), gold)
	ci.draw_rect(Rect2(c + Vector2(s * 0.85, 0), Vector2(s * 0.18, s * 0.4)), gold)
	ci.draw_rect(Rect2(c + Vector2(s * 0.5, 0), Vector2(s * 0.18, s * 0.3)), gold)
	ci.draw_circle(c + Vector2(-s * 0.7, 0), s * 0.18, WrD.RED)
	ci.draw_circle(c + Vector2(-s * 0.95, -s * 0.35), s * 0.08 + sin(tt * 3.0) * s * 0.03, Color(1, 1, 1, 0.8))


## 플레이어 설정 창은 화면 가운데에 겹쳐 뜬다(처음 화면 오른쪽은 메뉴 줄).
func _setup_panel_x() -> float:
	return vs.x * 0.5


func _setup_top() -> float:
	return 170.0 if wide() else vs.y * 0.34


func _layout_setup() -> void:
	var cw := minf(600.0, vs.x - 60.0)
	if wide():
		cw = minf(560.0, vs.x * 0.5 - 60.0)
	var cx := _setup_panel_x()
	var top := _setup_top()
	var on := setup_open
	setup_btns[1].rect = Rect2(cx + cw / 2 - 150, top - 66, 60, 50) if on else Rect2()
	setup_btns[2].rect = Rect2(cx + cw / 2 - 80, top - 66, 60, 50) if on else Rect2()
	for i in 4:
		var b: Dictionary = setup_btns[3 + i]
		b.enabled = i < setup_count
		b.label = "AI" if setup_ai[i] else "사람"
		b.col = Color8(99, 102, 241) if setup_ai[i] else Color8(34, 197, 94)
		b.rect = Rect2(cx + cw / 2 - 140, top + i * 92 + 14, 120, 58) if on else Rect2()
	# 시작 · 게임 선택 · 음량 — 다섯 게임 같은 자리(오른쪽 아래 · 왼쪽 위 · 오른쪽 위, `Hub.std_rect`). 설정 창이 떠 있으면 막는다
	setup_btns[0].rect = Hub.std_rect("start", vs) if not on else Rect2()
	setup_btns[7].rect = Hub.std_rect("hub", vs) if not on else Rect2()
	setup_btns[8].rect = Hub.std_rect("vol", vs) if not on else Rect2()
	for j in 4:
		setup_btns[9 + j].rect = UiKit.menu_rect(vs, j) if not on and not book.open and not rules.open and j == 0 else Rect2()   # 메뉴는 플레이어 설정 하나(도감 둘 · 순위를 뺌, 11-10)
	setup_btns[13].rect = Rect2(cx - 90, top + 4 * 92 + 22, 180, 54) if on else Rect2()

func _reset() -> void:
	gen += 1
	anims.clear()
	buttons = []
	modal = null
	picking = false
	pick_waiter = null
	quit_ask = false
	fx.clear()
	banner_t = 0.0
	dice_visible = false
	dice_rolled = false
	prompt = ""
	info_cell = -1
	zoom_full = true
	user_zoom = 0.0
	free_view = false
	drag_on = false
	ui_fx.clear()


func _begin() -> void:
	_reset()
	var ps: Array = []
	for i in setup_count:
		ps.append(WrGame.Player.new(i, WrD.PLAYER_NAMES[i] + (" (AI)" if setup_ai[i] else ""),
				WrD.PLAYER_COLORS[i], setup_ai[i]))
	g = WrGame.new(ps)
	scr = Scr.PLAY
	if all_lm:
		var k := 0
		for c in g.cells:
			if c.type == WrD.T.CITY:
				c.owner = k % ps.size()
				c.level = WrD.MAX_LEVEL
				k += 1
	over_btns = []
	g.add_log("게임 시작. 각자 %s 으로 출발합니다." % WrD.won(WrD.START_CASH), WrD.GOLD)
	var dbl := g.double_toll_cells()
	if not dbl.is_empty():
		g.add_log("이번 게임의 통행료 2배 지역: " + ", ".join(PackedStringArray(dbl.map(func(c): return c.name))), WrD.BAD)
	_run_game()


func _to_setup() -> void:
	_reset()
	g = null
	scr = Scr.SETUP
	intro_t = 0.0
	_build_setup()

# ==================== 진행 ====================


func _run_game() -> void:
	var my := gen
	ui_fx.confetti(vs.x, vs.y, 40)
	await _banner("월드 러너", "게임 시작", WrD.GOLD, 1.4)
	await delay(0.2)
	# 통행료 2배 지역 소개
	var dbl := g.double_toll_cells()
	if not dbl.is_empty():
		await _banner("통행료 2배 지역", "  ".join(PackedStringArray(dbl.map(func(c): return c.name))), WrD.RED, 1.6)
		for c: WrD.Cell in dbl:
			var rr := cell_rect(c.index)
			c.pulse = 1.0
			tween_ff(1.0, e_out_quad, func(t): c.pulse = 1.0 - t)
			fx.ring(rr.get_center().x, rr.get_center().y, WrD.RED, rr.size.x, 0.8)
			fx.burst(rr.get_center().x, rr.get_center().y, 18, WrD.BAD, 220, 5, 2)
			fx.float_text("x2", rr.get_center().x, rr.get_center().y - rr.size.y * 0.4, WrD.BAD, 44, 26, 1.4)
		fx.kick(10)
		await delay(1.1)
	zoom_full = all_lm   # 소개가 끝나면 말을 따라 들어간다(그림 확인 캡처는 판 전체 그대로)
	while not g.over:
		if my != gen:
			return
		var p := g.current()
		if not p.alive:
			g.next_turn()
			continue
		await _take_turn(p)
		if my != gen:
			return
		if _check_over():
			break
		g.next_turn()
		await delay(0.12)
		if g.round_n > WrD.MAX_ROUND:
			g.add_log("%d라운드 종료. 총자산으로 승자를 정합니다" % WrD.MAX_ROUND, WrD.GOLD)
			var best: WrGame.Player = null
			var bv := -1
			for q: WrGame.Player in g.players:
				if q.alive and g.net_worth(q) > bv:
					bv = g.net_worth(q)
					best = q
			g.winner = best
			g.over = true
	if my == gen:
		await _game_over()


func _check_over() -> bool:
	if g.alive_players() > 1:
		return false
	for p: WrGame.Player in g.players:
		if p.alive:
			g.winner = p
	g.over = true
	return true


func _take_turn(p: WrGame.Player) -> void:
	prompt = ""
	await _banner(p.name + "의 차례", "라운드 %d" % g.round_n, p.color, 0.95)
	if p.pending_space:
		p.pending_space = false
		await _space_travel(p)
		return
	if p.jail > 0:
		var escaped: bool = await _jail_phase(p)
		if not escaped:
			return
	var doubles := 0
	while true:
		var dbl: bool = await _roll(p)
		if dbl:
			doubles += 1
			if doubles >= 3:
				g.add_log(p.name + " 3연속 더블! 무인도로 갑니다.", WrD.BAD)
				await _banner("3연속 더블!", "무인도로 추방", WrD.BAD, 1.0)
				await _send_to_jail(p)
				return
		await _move(p, die1 + die2)
		await _resolve(p)
		if not p.alive or g.over:
			return
		# 우주여행 대기 · 무인도 수감이면 더블이어도 이번 턴은 여기서 끝
		if p.pending_space or p.jail > 0:
			if dbl:
				g.add_log(p.name + " 더블이지만 " + ("우주여행 준비로" if p.pending_space else "무인도 수감으로")
						+ " 턴을 마칩니다.", WrD.DIM)
			return
		if not dbl:
			break
		await _banner("더블", "한 번 더 굴립니다", WrD.GOLD, 0.8)


func _jail_phase(p: WrGame.Player) -> bool:
	var pt := token_point(p)
	fx.float_text("무인도 %d턴" % p.jail, pt.x, pt.y - cs * 0.5, WrD.BAD, FS_SUB, 30, 1.0)
	if p.escapes > 0:
		var use := true
		if not p.ai:
			use = await _ask("무인도 탈출권", "탈출권을 써서 바로 빠져나갈까요?", null, [], p.color,
					[["사용", "탈출권 1장", WrD.GOOD, true], ["보관", "주사위로 더블 도전", WrD.PANEL_HI, false]]) == 0
		if use:
			p.escapes -= 1
			p.jail = 0
			g.add_log(p.name + " 탈출권 사용. 무인도를 벗어납니다.", WrD.GOOD)
			await _splash(p, WrD.GOOD, "탈출")
			return true
	prompt = "무인도 탈출 시도 - 더블이 나오면 바로 탈출"
	var dbl: bool = await _roll(p)
	if dbl:
		p.jail = 0
		g.add_log(p.name + " 더블 성공, 무인도 탈출", WrD.GOOD)
		await _banner("탈출 성공", "더블", WrD.GOOD, 0.9)
		await _move(p, die1 + die2)
		await _resolve(p)
		return false
	p.jail -= 1
	if p.jail <= 0:
		g.add_log(p.name + " 구조되었습니다. 무인도를 벗어납니다.", WrD.ACCENT)
		await _banner("구조됨", "무인도 탈출", WrD.ACCENT, 0.9)
		await _move(p, die1 + die2)
		await _resolve(p)
	else:
		p.emit(2, 1.0)
		g.add_log("%s 탈출 실패. %d턴 더 기다립니다." % [p.name, p.jail], WrD.DIM)
		await delay(0.55)
	return false

# ==================== 주사위 ====================


func _roll(p: WrGame.Player) -> bool:
	dice_visible = true
	if not p.ai:
		prompt = "주사위를 굴릴 차례입니다"
		await _wait_buttons([["굴리기", "Space", WrD.GOLD, true, true]])
	else:
		prompt = p.name + " 생각 중..."
		await delay(0.4)
	prompt = ""
	dice_rolling = true
	var t1 := randi_range(1, 6)
	var t2 := randi_range(1, 6)
	Snd.play("swap")
	await tween(0.62, e_lin, func(t):
		die_rot1 = t * 26.0
		die_rot2 = -t * 22.0
		die_scale = 1.0 + sin(t * PI) * 0.35
		die1 = randi_range(1, 6)
		die2 = randi_range(1, 6))
	die1 = t1
	die2 = t2
	dice_rolling = false
	dice_rolled = true
	fx.kick(6)
	ui_fx.burst(dice_r.get_center().x, dice_r.get_center().y, 14, WrD.WHITE, 260, 4, 0)
	Snd.play("box")
	await tween(0.34, e_out_back, func(t):
		die_rot1 = (1.0 - t) * 1.2
		die_rot2 = -(1.0 - t)
		die_scale = 1.0 + (1.0 - t) * 0.45)
	die_rot1 = 0.0
	die_rot2 = 0.0
	die_scale = 1.0
	var dbl := die1 == die2
	g.add_log("%s 주사위 %d + %d = %d%s" % [p.name, die1, die2, die1 + die2, "  (더블)" if dbl else ""],
			WrD.GOLD if dbl else WrD.DIM)
	if dbl:
		dice_glow = 1.0
		ui_fx.burst(dice_r.get_center().x, dice_r.get_center().y, 22, WrD.GOLD, 320, 5, 2)
		ui_fx.ring(dice_r.get_center().x, dice_r.get_center().y, WrD.GOLD, 70, 0.55)
		fx.kick(9)
		Snd.play("make")
		await delay(0.28)
	else:
		await delay(0.12)
	return dbl

# ==================== 이동 ====================


## 진행 방향으로 steps 칸. 출발 칸을 지나면 급여를 받는다.
func _move(p: WrGame.Player, steps: int, trail: bool = false, trail_col: Color = WrD.GOLD) -> void:
	for i in steps:
		var from := p.pos
		var to := (from + 1) % WrD.BOARD_SIZE
		p.hop_from = from
		p.hop_to = to
		var dur := maxf(0.085, 0.20 - steps * 0.008)
		await tween(dur, e_lin, func(t): p.hop_t = t)
		p.hop_t = -1.0
		p.pos = to
		_land(p)
		if trail:
			var tp := token_point(p)
			fx.sparkle(tp.x, tp.y, 4, trail_col, cs * 0.18)
		if to == 0 and i < steps - 1:
			await _gain(p, WrD.SALARY, "출발 통과 급여")
	await delay(0.1)


func _land(p: WrGame.Player) -> void:
	p.squash = 1.0
	tween_ff(0.22, e_out_quad, func(t): p.squash = 1.0 - t)
	var pt := token_point(p)
	fx.dust(pt.x, pt.y + cs * 0.16, Color8(220, 230, 250))
	fx.kick(1.6)
	Snd.play("tick", 1.2)


## 포물선 점프 — 강제 이송(무인도)에만 쓴다. 급여 없음.
func _jump_to(p: WrGame.Player, to: int, trail_col: Color) -> void:
	var from := p.pos
	if from == to:
		return
	var a := cell_center(from)
	var b := cell_center(to)
	# 람다는 지역 변수를 값으로 잡으므로 바뀌는 값은 배열에 담아 둔다
	var last := [a]
	await tween(0.72, e_in_out_cubic, func(t):
		var pt := a.lerp(b, t) - Vector2(0, sin(t * PI) * cs * 2.2)
		p.jump_pt = pt
		if pt.distance_to(last[0]) > 14.0:
			fx.trail(pt.x, pt.y, trail_col)
			last[0] = pt
		p.scale = 1.0 + sin(t * PI) * 0.35)
	p.jump_pt = Vector2.INF
	p.scale = 1.0
	p.pos = to
	_land(p)


func _move_back(p: WrGame.Player, steps: int) -> void:
	for i in steps:
		var from := p.pos
		var to := (from - 1 + WrD.BOARD_SIZE) % WrD.BOARD_SIZE
		p.hop_from = from
		p.hop_to = to
		await tween(0.17, e_lin, func(t): p.hop_t = t)
		p.hop_t = -1.0
		p.pos = to
		_land(p)


func _send_to_jail(p: WrGame.Player) -> void:
	p.emit(2, 1.6)
	await _jump_to(p, WrD.CELL_JAIL, WrD.BAD)
	p.jail = WrD.JAIL_TURNS
	var pt := cell_center(WrD.CELL_JAIL)
	fx.burst(pt.x, pt.y, 26, WrD.SEA, 300, 6, 0)
	fx.ring(pt.x, pt.y, WrD.SEA, cs, 0.7)
	fx.kick(12)
	Snd.play("curse")
	fx.float_text("무인도 %d턴" % WrD.JAIL_TURNS, pt.x, pt.y - cs * 0.6, WrD.BAD, FS_SUB, 34, 1.3)
	await delay(0.55)


func _splash(p: WrGame.Player, c: Color, text: String) -> void:
	var pt := token_point(p)
	fx.ring(pt.x, pt.y, c, cs * 0.8, 0.55)
	fx.burst(pt.x, pt.y, 16, c, 240, 5, 2)
	fx.float_text(text, pt.x, pt.y - cs * 0.45, c, FS_SUB, 30, 1.0)
	await delay(0.35)

# ==================== 돈 ====================


func _gain(p: WrGame.Player, amount: int, reason: String) -> void:
	if amount <= 0:
		return
	p.cash += amount
	p.emit(1, 0.9)
	var pt := token_point(p)
	fx.float_text(WrD.signed(amount), pt.x, pt.y - cs * 0.42, WrD.GOOD, FS_SUB, 34, 1.0)
	fx.coin_fountain(pt.x, pt.y, 9)
	Snd.play("collect")
	g.add_log("%s  %s  %s" % [p.name, reason, WrD.signed(amount)], WrD.GOOD)
	await delay(0.32)


## 돈을 잃는다. 모자라면 매각 → 그래도 모자라면 파산(false).
func _lose(p: WrGame.Player, amount: int, reason: String, to: WrGame.Player) -> bool:
	if amount <= 0:
		return true
	var ok: bool = await _ensure_cash(p, amount)
	if not ok:
		await _bankrupt(p, to, reason)
		return false
	p.cash -= amount
	p.emit(2, 0.9)
	var pt := token_point(p)
	fx.float_text("-" + WrD.m(amount), pt.x, pt.y - cs * 0.42, WrD.BAD, FS_SUB, 34, 1.0)
	fx.kick(5)
	Snd.play("bad")
	g.add_log("%s  %s  -%s" % [p.name, reason, WrD.m(amount)], WrD.BAD)
	if to != null:
		to.cash += amount
		to.emit(1, 0.9)
		var dst := token_point(to)   # 받는 사람의 말에게로(판 위 = 월드 좌표)
		var n := mini(9, 3 + amount / 8)
		for i in n:
			fx.fly_coin(pt.x, pt.y, dst.x, dst.y, 0.5, i * 0.055, func(): fx.sparkle(dst.x, dst.y, 4, WrD.GOLD, 10))
		fx.float_text("+" + WrD.m(amount), dst.x, dst.y - 18, WrD.GOOD, FS_SUB, 26, 1.1)
	else:
		g.fund += amount
	await delay(0.45)
	return true


func _ensure_cash(p: WrGame.Player, need: int) -> bool:
	while p.cash < need:
		var opts := g.sell_options(p)
		if opts.is_empty():
			return false
		var choice: int
		if p.ai:
			choice = WrAi.choose_sell(g, p, opts)
			await delay(0.25)
		else:
			opts.sort_custom(func(x, y): return x.amount > y.amount)
			var show := mini(5, opts.size())
			var specs: Array = []
			for i in show:
				specs.append([opts[i].label, "+%s 회수" % WrD.m(opts[i].amount), WrD.GOLD if i == 0 else WrD.PANEL_HI, i == 0])
			choice = await _ask("현금이 부족합니다", "필요 %s, 보유 %s\n매각할 자산을 고릅니다." % [WrD.won(need), WrD.won(p.cash)],
					null, [], WrD.BAD, specs, true)
		await _apply_sell(p, opts[choice])
	return true


func _apply_sell(p: WrGame.Player, o: Dictionary) -> void:
	p.cash += o.amount
	var c: WrD.Cell = o.cell
	var r := cell_rect(c.index)
	var levels := c.level
	c.owner = -1
	c.level = 0
	c.build_pop = 0.0
	c.own_wave = 0.0
	c.shake = 1.0
	g.add_log("%s  %s %s  +%s" % [p.name, c.name, "건물과 토지 매각" if levels > 0 else "토지 매각", WrD.m(o.amount)], WrD.GOLD)
	fx.burst(r.get_center().x, r.get_center().y, 24 if levels > 0 else 14, Color8(180, 180, 190), 220, 5, 1)
	fx.dust(r.get_center().x, r.position.y + r.size.y * 0.42, Color8(200, 200, 210))
	fx.float_text("+" + WrD.m(o.amount), r.get_center().x, r.get_center().y - 14, WrD.GOLD, FS_SUB, 28, 1.0)
	fx.kick(9 if levels > 0 else 6)
	Snd.play("box")
	await delay(0.5)


func _bankrupt(p: WrGame.Player, creditor: WrGame.Player, reason: String) -> void:
	g.add_log("%s 파산! (%s)" % [p.name, reason], WrD.BAD)
	var pt := token_point(p)
	fx.burst(pt.x, pt.y, 30, WrD.BAD, 260, 6, 1)
	fx.kick(16)
	Snd.play("lose")
	p.emit(3, 6.0)   # 파산 — 주저앉아 우는 그림
	await _banner(p.name + " 파산", ("자산이 %s에게 넘어갑니다" % creditor.name) if creditor != null else "자산이 은행으로 돌아갑니다",
			WrD.BAD, 1.3)
	g.bankrupt(p, creditor)
	await tween(0.6, e_out_quad, func(t): p.alpha = 1.0 - t)
	p.alpha = 0.0

# ==================== 칸 처리 ====================


func _resolve(p: WrGame.Player) -> void:
	var c: WrD.Cell = g.cells[p.pos]
	c.pulse = 1.0
	tween_ff(0.6, e_out_quad, func(t): c.pulse = 1.0 - t)
	match c.type:
		WrD.T.START:
			await _gain(p, WrD.START_BONUS, "출발 칸 정확히 도착")
			fx.coin_fountain(cell_center(0).x, cell_center(0).y, 16)
			await _start_landmark(p)
		WrD.T.CITY, WrD.T.SPOT:
			await _resolve_property(p, c)
		WrD.T.CHANCE:
			await _resolve_chance(p)
		WrD.T.FUND_PAY:
			await _banner("사회복지기금", WrD.won(WrD.FUND_PAY) + " 납부", WrD.ACCENT, 0.9)
			if not await _lose(p, WrD.FUND_PAY, "사회복지기금 납부", null):
				return
			fx.sparkle(0.0, BL * HH, 10, WrD.GOLD, 30)   # 판 가운데의 기금
		WrD.T.FUND_GET:
			if g.fund <= 0:
				g.add_log("기금이 비어 있습니다.", WrD.DIM)
				await delay(0.4)
			else:
				var amt := g.fund
				g.fund = 0
				await _banner("기금 수령", WrD.won(amt) + " 획득", WrD.GOLD, 1.1)
				ui_fx.coin_rain(vs.x, vs.y, 46)
				await _gain(p, amt, "사회복지기금 수령")
		WrD.T.TAX:
			var tax := maxi(5, int(p.cash * WrD.TAX_RATE))
			await _banner("국세청", "재산세 " + WrD.won(tax), WrD.BAD, 1.0)
			if not await _lose(p, tax, "재산세 납부", null):
				return
		WrD.T.JAIL:
			g.add_log(p.name + " 무인도에 도착", WrD.BAD)
			await _banner("무인도", "%d턴 동안 갇힙니다" % WrD.JAIL_TURNS, WrD.BAD, 1.1)
			p.jail = WrD.JAIL_TURNS
			p.emit(2, 1.4)
			await _splash(p, WrD.SEA, "갇힘")
		WrD.T.SPACE:
			p.pending_space = true
			var sp := cell_center(WrD.CELL_SPACE)
			fx.rocket(sp.x, sp.y)
			fx.ring(sp.x, sp.y, WrD.ACCENT, cs, 0.7)
			fx.kick(8)
			Snd.play("fly")
			g.add_log(p.name + " 우주여행. 다음 턴에 원하는 칸으로 갑니다.", WrD.ACCENT)
			await _banner("우주여행", "다음 턴에 원하는 칸으로", WrD.ACCENT, 1.2)


func _resolve_property(p: WrGame.Player, c: WrD.Cell) -> void:
	if c.owner < 0:
		if p.cash < c.price:
			g.add_log("%s 현금이 모자라 %s 를 못 삽니다" % [p.name, c.name], WrD.DIM)
			await delay(0.5)
			return
		var buy: bool
		if p.ai:
			buy = WrAi.want_buy(g, p, c)
			await _peek(c, p, "구매" if buy else "보류", WrD.GOOD if buy else WrD.DIM)
		else:
			buy = await _ask(c.name + " 매입", "이 도시를 살까요?", c, [], c.group_color(),
					[["구매", WrD.won(c.price), WrD.GOOD, true], ["보류", "사지 않음", WrD.PANEL_HI, false]]) == 0
		if buy:
			await _buy(p, c)
		else:
			g.add_log("%s %s 구매 보류" % [p.name, c.name], WrD.DIM)
			await delay(0.2)
		return
	if c.owner == p.id:
		if g.can_build_landmark(c):
			await _landmark_phase(p, c)
		elif g.can_build_hotel_tier(c):
			await _build_phase(p, c, WrD.HOTEL_LEVEL)
		else:
			g.add_log("%s 내 도시 %s (%s)" % [p.name, c.name, WrD.LEVEL_NAMES[c.level]], WrD.DIM)
			await delay(0.35)
		return
	# 남의 도시 → 통행료
	var owner: WrGame.Player = g.players[c.owner]
	var toll := g.toll(c)
	var mono := g.monopoly_boosted(c)
	await _banner("통행료 지불", "%s  %s%s" % [c.name, WrD.won(toll), "  (독점 2배)" if mono else ""], owner.color, 1.0)
	c.shake = 1.0
	if not await _lose(p, toll, c.name + " 통행료", owner):
		return
	# 인수 제안 — 랜드마크가 선 도시는 인수 불가(소유자가 매각하는 것만 된다)
	if not c.has_landmark():
		var price := g.takeover_price(c)
		if p.cash >= price:
			var want: bool
			if p.ai:
				want = WrAi.want_takeover(g, p, c)
			else:
				want = await _ask(c.name + " 인수", "이 도시를 %s에게서 인수할 수 있습니다.\n인수가 = 투자액 x %d" % [owner.name, WrD.TAKEOVER_MUL],
						c, [], WrD.GOLD, [["인수", WrD.won(price), WrD.GOLD, true], ["넘어가기", "", WrD.PANEL_HI, false]]) == 0
			if want:
				if not await _lose(p, price, c.name + " 인수", owner):
					return
				c.owner = p.id
				c.own_wave = 1.0
				var r := cell_rect(c.index)
				fx.ring(r.get_center().x, r.get_center().y, p.color, r.size.x, 0.6)
				fx.burst(r.get_center().x, r.get_center().y, 20, p.color, 220, 5, 2)
				g.add_log("%s %s 인수 성공" % [p.name, c.name], WrD.GOLD)
				Snd.play("win", 1.2)
				await _banner("인수 성공", c.name, p.color, 1.0)
				if g.can_build_hotel_tier(c):
					await _build_phase(p, c, WrD.HOTEL_LEVEL)
	else:
		g.add_log(c.name + " 에는 랜드마크가 서 있어 인수할 수 없습니다.", WrD.GOLD)
		await delay(0.35)


func _buy(p: WrGame.Player, c: WrD.Cell) -> void:
	p.cash -= c.price
	c.owner = p.id
	c.own_wave = 1.0
	p.emit(1, 1.0)
	var r := cell_rect(c.index)
	var cp := r.get_center()
	fx.ring(cp.x, cp.y, p.color, r.size.x * 0.9, 0.6)
	fx.burst(cp.x, cp.y, 22, p.color, 240, 5, 2)
	fx.float_text("-" + WrD.m(c.price), cp.x, cp.y - r.size.y * 0.4, WrD.BAD, FS_BODY, 30, 1.0)
	fx.kick(6)
	Snd.play("make")
	g.add_log("%s %s 매입 -%s" % [p.name, c.name, WrD.m(c.price)], p.color)
	var mono := g.has_monopoly(p.id, c.group)
	await delay(0.45)
	if mono and c.group != "":
		await _banner("대륙 독점!", WrD.GROUPS[c.group][0] + " 통행료 2배", WrD.GOLD, 1.2)
		for x: WrD.Cell in g.cells:
			if x.group == c.group:
				var rr := cell_rect(x.index)
				fx.sparkle(rr.get_center().x, rr.get_center().y, 10, WrD.GOLD, 18)
				x.own_wave = 1.0
		fx.kick(8)
		Snd.play("rainbow")
		await delay(0.3)
	if g.can_build_hotel_tier(c):
		await _build_phase(p, c, WrD.HOTEL_LEVEL)


## 이번 방문에 max_level 까지 연달아 짓는다(호텔까지는 그 자리에서 된다).
func _build_phase(p: WrGame.Player, c: WrD.Cell, max_level: int) -> void:
	if p.ai:
		var n := WrAi.want_build_count(g, p, c, max_level)
		for i in n:
			if c.level >= max_level:
				break
			await _do_build(p, c)
		return
	while c.level < max_level and g.can_build(c):
		var cost := g.next_build_cost(c)
		if p.cash < cost:
			return
		var next: String = WrD.LEVEL_NAMES[c.level + 1]
		var body := "%s 을(를) 지으면 통행료가 %s 이 됩니다." % [next, WrD.won(c.tolls[c.level + 1])]
		if c.level + 1 >= max_level:
			body += "\n랜드마크는 이 칸에 다시 오거나 출발 칸에 도착했을 때 짓습니다."
		var choice: int = await _ask("건설", body, c, [], p.color,
				[[next + " 건설", WrD.won(cost), WrD.GOOD, true], ["건설 끝", "", WrD.PANEL_HI, false]])
		if choice != 0:
			return
		await _do_build(p, c)


## 출발 칸에 정확히 도착 → 호텔이 선 내 도시 하나를 골라 랜드마크로. **목록에서 고른다** —
## 칸을 누르는 방식(우주여행)은 마우스 · 터치 전용이라, 키보드만으로도 끝까지 가야 하기 때문.
func _start_landmark(p: WrGame.Player) -> void:
	var cand: Array = []
	for c: WrD.Cell in g.cells:
		if c.owner == p.id and c.level == WrD.HOTEL_LEVEL and p.cash >= g.next_build_cost(c):
			cand.append(c)
	if cand.is_empty():
		return
	# 통행료가 가장 많이 오르는 곳부터
	cand.sort_custom(func(x, y): return (x.tolls[4] - x.tolls[3]) > (y.tolls[4] - y.tolls[3]))
	var pick: WrD.Cell = null
	if p.ai:
		for c: WrD.Cell in cand:
			if WrAi.want_landmark(g, p, c):
				pick = c
				break
		if pick == null:
			await delay(0.25)
			return
		await _banner("출발 보너스", "%s, %s 랜드마크" % [p.name, pick.name], WrD.GOLD, 1.1)
	else:
		var show := mini(4, cand.size())
		var specs: Array = []
		for i in show:
			var c: WrD.Cell = cand[i]
			specs.append([c.name + "  " + WrD.landmark_name(c.landmark),
					"건설 %s, 통행료 %s" % [WrD.m(g.next_build_cost(c)), WrD.m(c.tolls[WrD.MAX_LEVEL])],
					WrD.GOLD if i == 0 else WrD.PANEL_HI, i == 0])
		specs.append(["나중에", "", WrD.PANEL_HI, false])
		var choice: int = await _ask("출발 보너스 - 랜드마크",
				"호텔이 선 내 도시 하나를 랜드마크로 올릴 수 있습니다." + (("\n(통행료가 가장 많이 오르는 %d곳)" % show) if cand.size() > show else ""),
				null, [], WrD.GOLD, specs, true)
		if choice >= show:
			return
		pick = cand[choice]
	await _do_build(p, pick)


## 호텔이 선 도시에 다시 왔다 → 랜드마크
func _landmark_phase(p: WrGame.Player, c: WrD.Cell) -> void:
	var cost := g.next_build_cost(c)
	if p.cash < cost:
		g.add_log("%s %s 랜드마크 건설 자금 부족 (%s)" % [p.name, c.name, WrD.won(cost)], WrD.DIM)
		await delay(0.5)
		return
	var go: bool
	if p.ai:
		go = WrAi.want_landmark(g, p, c)
		if go:
			await _banner("랜드마크 건설", "%s, %s" % [p.name, c.name], WrD.GOLD, 1.0)
		else:
			await delay(0.3)
	else:
		go = await _ask(c.name + " 랜드마크", "%s 을(를) 세우면 통행료가 %s 이 됩니다." % [WrD.landmark_name(c.landmark), WrD.won(c.tolls[WrD.MAX_LEVEL])],
				c, [], WrD.GOLD, [["랜드마크 건설", WrD.won(cost), WrD.GOLD, true], ["나중에", "", WrD.PANEL_HI, false]]) == 0
	if go:
		await _do_build(p, c)


func _do_build(p: WrGame.Player, c: WrD.Cell) -> void:
	var cost := g.next_build_cost(c)
	if p.cash < cost:
		return
	p.cash -= cost
	c.level += 1
	c.build_pop = 0.001
	c.shake = 1.0
	var r := cell_rect(c.index)
	var cp := r.get_center()
	fx.float_text("-" + WrD.m(cost), cp.x, cp.y - r.size.y * 0.35, WrD.BAD, FS_SMALL, 24, 0.9)
	g.add_log("%s %s %s 건설 -%s" % [p.name, c.name, WrD.LEVEL_NAMES[c.level], WrD.m(cost)], p.color)
	var lm := c.level >= WrD.MAX_LEVEL
	tween_ff(0.85 if lm else 0.62, e_lin, func(t): c.build_pop = maxf(0.001, t))
	await delay(0.36 if lm else 0.26)
	fx.kick(18 if lm else 9)
	fx.dust(cp.x, r.position.y + r.size.y * 0.42, Color8(210, 220, 240))
	fx.burst(cp.x, r.position.y + r.size.y * 0.4, 26 if lm else 12, WrD.GOLD if lm else WrIcons.lighten(p.color, 0.3),
			260 if lm else 160, 6 if lm else 4, 2 if lm else 1)
	fx.ring(cp.x, r.position.y + r.size.y * 0.42, WrD.GOLD if lm else p.color, r.size.x * (1.1 if lm else 0.5), 0.7 if lm else 0.4)
	Snd.play("box")
	if lm:
		c.own_wave = 1.0
		fx.sparkle(cp.x, r.position.y + r.size.y * 0.35, 16, WrD.GOLD, r.size.x * 0.5)
		fx.coin_fountain(cp.x, cp.y, 10)
		Snd.play("win")
		await _banner("랜드마크 완성!", "%s  통행료 %s" % [c.name, WrD.won(g.toll(c))], WrD.GOLD, 1.4)
	await delay(0.42)
	c.build_pop = 0.0

# ==================== 황금열쇠 ====================


func _resolve_chance(p: WrGame.Player) -> void:
	var card := g.draw_card()
	Snd.play("fly")
	if p.ai:
		await _show_chance(card, p, 1.25)
	else:
		await _ask("황금열쇠", "", null, card, WrD.GOLD, [["확인", "Space", WrD.GOLD, true]])
	g.add_log("황금열쇠: " + String(card[2]), WrD.GOLD)
	await _apply_card(p, card)


func _apply_card(p: WrGame.Player, card: Array) -> void:
	var amount: int = card[1]
	match String(card[0]):
		"goto":
			# 순간이동이 아니라 진행 방향으로 간다 — 도중에 출발 칸을 지나면 급여.
			var steps := (amount - p.pos + WrD.BOARD_SIZE) % WrD.BOARD_SIZE
			if steps == 0:
				steps = WrD.BOARD_SIZE
			g.add_log("%s  %s까지 %d칸 이동" % [p.name, g.cells[amount].name, steps], WrD.GOLD)
			await _move(p, steps, true, WrD.GOLD)
			await _resolve(p)
		"jail":
			await _send_to_jail(p)
		"gain":
			await _gain(p, amount, "황금열쇠")
		"lose":
			await _lose(p, amount, "황금열쇠", null)
		"birthday":
			for q: WrGame.Player in g.players:
				if q == p or not q.alive:
					continue
				await _lose(q, amount, "생일 축하금", p)
		"donate":
			for q: WrGame.Player in g.players:
				if q == p or not q.alive:
					continue
				if not await _lose(p, amount, "기부금", q):
					return
		"fundget":
			if g.fund > 0:
				var amt := g.fund
				g.fund = 0
				ui_fx.coin_rain(vs.x, vs.y, 40)
				await _gain(p, amt, "기금 지원")
			else:
				g.add_log("기금이 비어 있습니다.", WrD.DIM)
				await delay(0.3)
		"escape":
			p.escapes += 1
			await _splash(p, WrD.GOLD, "탈출권 +1")
		"back":
			await _move_back(p, amount)
			await _resolve(p)
		"repair":
			var n := g.owned(p.id).size()
			if n == 0:
				g.add_log("가진 도시가 없습니다.", WrD.DIM)
				await delay(0.3)
			else:
				await _lose(p, n * amount, "도시 %d곳 유지비" % n, null)
		"rent":
			var n := g.count_buildings(p.id)
			if n == 0:
				g.add_log("가진 건물이 없습니다.", WrD.DIM)
				await delay(0.3)
			else:
				await _gain(p, n * amount, "건물 %d채 수익" % n)

# ==================== 우주여행 ====================


func _space_travel(p: WrGame.Player) -> void:
	var dest: int
	if p.ai:
		prompt = p.name + " 목적지 고르는 중..."
		await delay(0.7)
		dest = WrAi.choose_space(g, p)
	else:
		await _banner("우주여행", "갈 칸을 고릅니다", WrD.ACCENT, 1.0)
		prompt = "갈 칸을 고릅니다"
		var from := p.pos
		dest = await _pick_cell(func(c): return c.index != from)
	prompt = ""
	var sp := cell_center(p.pos)
	fx.rocket(sp.x, sp.y)
	fx.kick(10)
	Snd.play("fly", 0.8)
	var steps := (dest - p.pos + WrD.BOARD_SIZE) % WrD.BOARD_SIZE
	if steps == 0:
		steps = WrD.BOARD_SIZE
	g.add_log("%s 우주여행 > %s (%d칸 이동)" % [p.name, g.cells[dest].name, steps], WrD.ACCENT)
	await _move(p, steps, true, Color8(147, 197, 253))
	var dp := cell_center(dest)
	fx.burst(dp.x, dp.y, 24, Color8(147, 197, 253), 260, 5, 2)
	fx.ring(dp.x, dp.y, Color8(147, 197, 253), cs * 0.9, 0.6)
	await _resolve(p)

# ==================== 결과 ====================


func _game_over() -> void:
	scr = Scr.OVER
	over_t = 0.0
	buttons = []
	ui_fx.confetti(vs.x, vs.y, 140)
	ui_fx.coin_rain(vs.x, vs.y, 60)
	# 순위 기록 — 사람이 낀 판만, 확인용 실행(명령줄 인자)은 빼고
	if OS.get_cmdline_user_args().is_empty():
		for p: WrGame.Player in g.players:
			if not p.ai:
				WrRec.add(g.winner == p, g.net_worth(p), g.round_n)
				break
	if g.winner != null:
		g.add_log("승자: %s" % g.winner.name, WrD.GOLD)
		g.winner.emit(4, 999.0)   # 승리 — 트로피를 든 그림
	Snd.play("win")
	await delay(0.6)
	var again := _btn("다시 하기", "", Color8(34, 197, 94), true, 0, null)
	again.act = _to_setup
	var hub := _btn("게임 선택", "", WrD.PANEL_HI, false, 1, null)
	hub.act = func(): Hub.leave(self)
	over_btns = [again, hub]

# ==================== 입력 ====================


func _unhandled_input(e: InputEvent) -> void:
	if Vol.open:
		Vol.handle(e, vs)   # 시작 화면 오른쪽 위 "음량" 창
		return
	if e is InputEventMouseMotion:
		mouse = e.position
		if drag_on:
			_drag_to(e.position)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			mouse = mb.position
			if mb.pressed:
				_click(mb.position)
			else:
				_drag_end(mb.position)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel(mb.position, 1.0)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel(mb.position, -1.0)
			return
	if e is InputEventKey and e.pressed and not e.echo:
		_key(e.keycode)


## 판을 누른 채 움직이면 시야를 옮긴다. DRAG_SLOP 안에서 떼면 칸 클릭이다(_drag_end).
func _drag_to(p: Vector2) -> void:
	if modal != null or quit_ask or scr != Scr.PLAY:
		drag_on = false
		return
	if not drag_moved and p.distance_to(drag_from) < DRAG_SLOP:
		return
	drag_moved = true
	cam -= (p - drag_last) / zoom
	drag_last = p
	_hold_view()


func _drag_end(p: Vector2) -> void:
	if not drag_on:
		return
	drag_on = false
	if not drag_moved and modal == null and not quit_ask and scr == Scr.PLAY:
		_board_tap(p)


## 휠 — 마우스가 가리키는 월드 지점이 그 자리에 남게 카메라를 같이 옮긴다.
func _wheel(p: Vector2, dir: float) -> void:
	if scr != Scr.PLAY or modal != null or quit_ask or g == null:
		return
	var nz := clampf(zoom * pow(ZOOM_STEP, dir), _fit_zoom(), ZOOM_MAX)
	if is_equal_approx(nz, zoom):
		return
	cam += (p - view.get_center()) * (1.0 / zoom - 1.0 / nz)
	zoom = nz
	user_zoom = nz
	_hold_view()


func _hold_view() -> void:
	if g != null:
		free_view = true
		free_pid = g.current().id


func _active_list() -> Array:
	if quit_ask:
		return quit_btns
	match scr:
		Scr.SETUP:
			return setup_btns
		Scr.OVER:
			return over_btns
	return modal.buttons if modal != null else buttons


func _hit(list: Array, p: Vector2) -> Dictionary:
	for i in range(list.size() - 1, -1, -1):
		var b: Dictionary = list[i]
		var br: Rect2 = b.rect
		if b.enabled and br.has_point(p):
			return b
	return {}


func _click(p: Vector2) -> void:
	if scr == Scr.SETUP and rules.click(p, vs):
		return
	if scr == Scr.SETUP and book.click(p, vs):
		return
	if scr == Scr.SETUP and not setup_open and _rules_rect().has_point(p):
		_open_rules()
		return
	if quit_ask or scr == Scr.SETUP or scr == Scr.OVER:
		var b := _hit(_active_list(), p)
		if not b.is_empty():
			_press(b)
		return
	if _speed_rect().has_point(p):
		_cycle_speed()
		return
	if _menu_rect().has_point(p):
		_open_quit()
		return
	if _vol_play_rect().has_point(p):
		Vol.open = true
		return
	var b := _hit(_active_list(), p)
	if not b.is_empty():
		_press(b)
		return
	if modal != null:
		return
	# 칸 클릭은 뗄 때 정한다 — 누른 채 움직이면 시야 옮기기다(_drag_to · _drag_end)
	drag_on = true
	drag_moved = false
	drag_from = p
	drag_last = p


func _board_tap(p: Vector2) -> void:
	var i := _cell_at(p) if view.has_point(p) else -1
	if i >= 0:
		if picking:
			if pick_filter.is_valid() and not pick_filter.call(g.cells[i]):
				return
			var r := cell_rect(i)
			fx.ring(r.get_center().x, r.get_center().y, WrD.GOLD, r.size.x * 0.7, 0.5)
			picking = false
			var w := pick_waiter
			pick_waiter = null
			if w != null:
				w.chosen.emit(i)
			return
		# 터치에는 마우스 올리기가 없으므로 눌러서 정보를 띄운다
		info_cell = -1 if info_cell == i else i
		return
	info_cell = -1


func _key(k: int) -> void:
	if scr == Scr.SETUP and rules.key(k):
		return
	if scr == Scr.SETUP and book.key(k):
		return
	if scr == Scr.SETUP and setup_open and k == KEY_ESCAPE:
		setup_open = false
		return
	if k == KEY_ESCAPE:
		if quit_ask:
			quit_ask = false
		elif scr == Scr.PLAY:
			_open_quit()
		else:
			Hub.leave(self)
		return
	if k == KEY_TAB:
		_cycle_speed()
		return
	var list := _active_list()
	if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		for b: Dictionary in list:
			if b.enabled and b.primary:
				_press(b)
				return
		if not list.is_empty() and list[0].enabled:
			_press(list[0])
		return
	if k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		if idx < list.size() and list[idx].enabled:
			_press(list[idx])


func _cycle_speed() -> void:
	speed = 2.0 if speed < 1.5 else (4.0 if speed < 3.0 else 1.0)
	var r := _speed_rect()
	ui_fx.sparkle(r.get_center().x, r.get_center().y, 6, WrD.ACCENT, 10)


func _open_quit() -> void:
	quit_ask = true
	var yes := _btn("그만두기", "이 판은 사라집니다", WrD.BAD, false, 0, null)
	yes.act = _to_setup
	var no := _btn("계속하기", "", Color8(34, 197, 94), true, 1, null)
	no.act = func(): quit_ask = false
	quit_btns = [yes, no]

# ==================== 그리기 ====================


func _draw() -> void:
	Hub.compact = scr == Scr.PLAY   # 판 화면은 아이콘 단추
	WrIcons.set_base(self, Transform2D.IDENTITY)
	if scr == Scr.SETUP:
		_draw_bg()
		_layout_setup()
		_draw_setup()
		ui_fx.draw(self)
		Vol.draw(self, vs, time)
		return
	_draw_sea()
	# 판(월드) — 카메라 변환에 화면 흔들림을 앞에 곱한다
	WrIcons.set_base(self, Transform2D(0.0, fx.offset()) * world_xf())
	_draw_island()
	_draw_tiles()
	_draw_plaza()
	_draw_objects()
	fx.draw(self)
	WrIcons.set_base(self, Transform2D.IDENTITY)
	if all_lm:
		return   # 그림 확인 캡처 — 판을 가리는 상태창 · 단추 · 설명 창을 안 그린다
	_draw_hud()
	ui_fx.draw(self)
	_draw_info()
	_draw_banner()
	if modal != null:
		_draw_modal(modal)
	if scr == Scr.OVER:
		_draw_over()
	if quit_ask:
		_draw_quit()
	Vol.draw(self, vs, time)


## 시작 화면 바탕
func _draw_bg() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([WrD.BG1, WrD.BG1, WrD.BG0, WrD.BG0]))
	# 그림(runner_bg_setup)이 있으면 화면을 덮게 깔고 조금 어둡게 눌러 글 · 단추가 읽히게 한다
	var bg := WrIcons.art("runner_bg_setup")
	if bg != null:
		WrIcons.cover(self, bg, Rect2(Vector2.ZERO, vs), Color(0.62, 0.66, 0.78))
		return
	for i in 2:
		var ph := time * (0.11 + i * 0.07) + i * 2.1
		var c := Vector2(vs.x * (0.3 + 0.4 * sin(ph)), vs.y * (0.3 + 0.4 * cos(ph * 0.8)))
		var col := WrD.ACCENT if i == 0 else Color8(168, 85, 247)
		for k in 4:
			draw_circle(c, vs.y * (0.55 - k * 0.12), WrIcons.a(col, 0.025))

# ---------- 바다 · 섬 ----------

const SEA_TOP := Color8(40, 120, 190)
const SEA_BOT := Color8(18, 70, 140)


func _draw_sea() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([SEA_TOP, SEA_TOP, SEA_BOT, SEA_BOT]))
	# 바다 그림(runner_tile_sea)이 있으면 판과 같이 움직이는 무늬로 깐다 — 화면에 붙어 있으면 판이 바다 위를
	# 미끄러지는 것처럼 보인다. 칸을 번갈아 뒤집어(UV) 이음매를 숨긴다(스카이 어설트 바닥과 같은 방법).
	var st := WrIcons.art("runner_tile_sea")
	if st != null:
		var o := world_xf() * Vector2.ZERO
		var S := 256.0 * zoom
		var x0 := fposmod(o.x, S * 2.0) - S * 2.0
		var y0 := fposmod(o.y, S * 2.0) - S * 2.0
		var cols := int(ceil((vs.x - x0) / S)) + 1
		var rows := int(ceil((vs.y - y0) / S)) + 1
		var tint := Color(1, 1, 1, 0.55)
		for ry in rows:
			for cx in cols:
				var u0 := 1.0 if cx % 2 == 1 else 0.0
				var v0 := 1.0 if ry % 2 == 1 else 0.0
				var px := x0 + cx * S
				var py := y0 + ry * S
				draw_primitive(PackedVector2Array([Vector2(px, py), Vector2(px + S, py), Vector2(px + S, py + S),
						Vector2(px, py + S)]), PackedColorArray([tint, tint, tint, tint]),
						PackedVector2Array([Vector2(u0, v0), Vector2(1.0 - u0, v0), Vector2(1.0 - u0, 1.0 - v0),
						Vector2(u0, 1.0 - v0)]), st)
	# 잔물결 — 판과 같이 움직여야 판이 바다 위에 놓인 것으로 읽힌다
	var xf := world_xf()
	for k in 26:
		var wx := fposmod(k * 397.0, 2400.0) - 1200.0 + sin(time * 0.6 + k) * 20.0
		var wy := fposmod(k * 233.0, 1400.0) - 300.0
		var p := xf * Vector2(wx, wy)
		var l := 26.0 * zoom
		draw_line(p - Vector2(l, 0), p + Vector2(l, 0), Color(1, 1, 1, 0.12), 3.0 * zoom)


func _diamond(c0: float, r0: float, c1: float, r1: float) -> PackedVector2Array:
	return PackedVector2Array([iso(c0, r0), iso(c1, r0), iso(c1, r1), iso(c0, r1)])


## 판 밑 섬 — 모래 언덕 + 절벽 두께 + 풀밭. 판이 바다 위에 떠 있지 않게.
func _draw_island() -> void:
	var sand := _diamond(-1.1, -1.1, BL + 1.1, BL + 1.1)
	var cliff := 46.0
	# 절벽(앞쪽 두 면)
	var l := sand[3]
	var b := sand[2]
	var r := sand[1]
	draw_colored_polygon(PackedVector2Array([l, b, b + Vector2(0, cliff), l + Vector2(0, cliff)]), Color8(150, 110, 70))
	draw_colored_polygon(PackedVector2Array([b, r, r + Vector2(0, cliff), b + Vector2(0, cliff)]), Color8(120, 86, 56))
	# 절벽 그림(runner_tile_cliff, 옆에서 본 흙 · 바위 띠)이 있으면 두 면에 감는다 — 오른쪽 면은 조금 어둡게
	var cl := WrIcons.art("runner_tile_cliff")
	if cl != null:
		var run := BL / 3.0
		for fc: Array in [[l, b, Color(1, 1, 1)], [b, r, Color(0.78, 0.78, 0.8)]]:
			var a: Vector2 = fc[0]
			var e: Vector2 = fc[1]
			draw_polygon(PackedVector2Array([a, e, e + Vector2(0, cliff), a + Vector2(0, cliff)]), PackedColorArray([fc[2]]),
					PackedVector2Array([Vector2(0, 0), Vector2(run, 0), Vector2(run, 1), Vector2(0, 1)]), cl)
	draw_colored_polygon(sand, Color8(236, 214, 160))
	# 모래 그림(runner_tile_sand) — 마름모에 판 좌표로 UV 를 걸어 판과 같이 기울고 움직인다.
	# UV 가 1 을 넘으므로 텍스처 반복이 켜져 있어야 한다 — _ready 에서 노드 전체에 켠다(그리기 중간에
	# 켰다 끄면 소용없다: 반복 여부는 그리기 명령마다가 아니라 노드에 한 번 걸린다).
	var sd := WrIcons.art("runner_tile_sand")
	if sd != null:
		var k := 2.2   # 판 한 변에 무늬가 몇 번 반복되나의 역수 — 칸 두셋에 한 장
		var uv := PackedVector2Array([Vector2(-1.1, -1.1), Vector2(BL + 1.1, -1.1),
				Vector2(BL + 1.1, BL + 1.1), Vector2(-1.1, BL + 1.1)])
		for i in uv.size():
			uv[i] /= k
		draw_polygon(sand, PackedColorArray([Color(1, 1, 1, 0.85)]), uv, sd)
	var lawn := _diamond(-0.6, -0.6, BL + 0.6, BL + 0.6)
	draw_colored_polygon(lawn, Color8(120, 196, 110))
	# 잔디 그림(runner_tile_grass) — 모래와 같은 방식으로 판 좌표 UV(칸 셋에 한 장)
	var gr := WrIcons.art("runner_tile_grass")
	if gr != null:
		var guv := PackedVector2Array([Vector2(-0.6, -0.6), Vector2(BL + 0.6, -0.6), Vector2(BL + 0.6, BL + 0.6), Vector2(-0.6, BL + 0.6)])
		for i in guv.size():
			guv[i] /= 3.0
		draw_polygon(lawn, PackedColorArray([Color(0.74, 0.8, 0.66)]), guv, gr)   # 그림 그대로는 형광 연두라 칸 색이 묻힌다 — 눌러 깐다
	# 나무 — 판 바깥 둘레에 해시로 늘 같은 자리
	var spots := [[-0.75, 2.0], [-0.8, 6.5], [2.5, -0.75], [6.0, -0.8], [9.75, 3.0], [9.8, 7.0], [4.0, 9.8], [7.5, 9.75]]
	for s: Array in spots:
		var p := iso(s[0] * BL / 9.0, s[1] * BL / 9.0)
		_tree(p)


func _tree(p: Vector2) -> void:
	if WrIcons.stand_art(self, WrIcons.art("runner_tree"), p.x, p.y, 76.0, 84.0):
		return
	draw_rect(Rect2(p.x - 4, p.y - 24, 8, 24), Color8(120, 80, 50), true)
	draw_circle(p + Vector2(0, -38), 24, Color8(46, 150, 80))
	draw_circle(p + Vector2(-9, -46), 14, Color8(80, 190, 100))

# ---------- 칸 ----------


## 칸은 두께 있는 블록이다. 뒤에서 앞으로(열 + 행이 작은 것부터) 그려야 앞 블록이 뒤 블록을 덮는다.
func _draw_tiles() -> void:
	var order: Array = range(WrD.BOARD_SIZE)
	order.sort_custom(func(x, y):
		var a := WrD.grid_pos(x)
		var b := WrD.grid_pos(y)
		return a.x + a.y < b.x + b.y)
	for i: int in order:
		_draw_tile(g.cells[i])


func _tile_color(c: WrD.Cell) -> Color:
	if c.is_property():
		return WrIcons.mix(c.group_color(), Color.WHITE, 0.1)
	if c.is_corner():
		return Color8(255, 246, 214)
	return Color8(236, 240, 250)


func _draw_tile(c: WrD.Cell) -> void:
	var lift := 0.0
	if c.shake > 0.0:
		lift = sin(time * 40.0) * c.shake * 4.0
	if c.pulse > 0.0:
		lift -= c.pulse * 8.0
	var top := cell_diamond(c.index)
	for k in 4:
		top[k].y += lift
	var owned := c.owner >= 0
	var oc: Color = g.players[c.owner].color if owned else Color.WHITE
	var mine: bool = owned and not g.players[c.owner].ai
	var base := _tile_color(c)
	# 옆면 둘 — **땅을 가지면 옆면이 소유자 색이 된다**(칸 바깥쪽 띠 = 원본의 소유 띠).
	var side_l := WrIcons.darken(oc if owned else base, 0.18 if mine else 0.3)
	var side_r := WrIcons.darken(oc if owned else base, 0.32 if mine else 0.45)
	var d := Vector2(0, DEPTH)
	draw_colored_polygon(PackedVector2Array([top[3], top[2], top[2] + d, top[3] + d]), side_l)
	draw_colored_polygon(PackedVector2Array([top[2], top[1], top[1] + d, top[2] + d]), side_r)
	var col := base
	if owned:
		col = WrIcons.mix(base, oc, 0.22 if mine else 0.12)
	if hover_cell == c.index or info_cell == c.index:
		col = WrIcons.lighten(col, 0.25)
	draw_colored_polygon(top, col)
	# 윗면 앞쪽 가장자리 밝은 선 — 블록 두께가 읽히게
	draw_line(top[3], top[2], Color(1, 1, 1, 0.6), 2.0)
	draw_line(top[2], top[1], Color(1, 1, 1, 0.35), 2.0)
	# 테두리 — 내 땅 > AI 땅 > 빈 땅. 독점 · 랜드마크는 금빛
	var cen := c.index
	var edge := Color(0, 0, 0, 0.25)
	var ew := 1.5
	if owned:
		edge = oc
		ew = 5.0 if mine else 3.0
	if c.own_wave > 0.0:
		ew += c.own_wave * 6.0
	var loop := top.duplicate()
	loop.append(top[0])
	if mine:
		draw_polyline(loop, WrIcons.a(oc, 0.35 + 0.15 * sin(time * 2.2 + cen)), ew + 6.0, true)
	if owned:
		draw_polyline(loop, Color(0.05, 0.05, 0.1, 0.7), ew + 3.0, true)   # 어두운 밑선 — 칸과 소유자 색이 같아도 테두리가 읽힌다
	draw_polyline(loop, edge, ew, true)
	if owned and (c.has_landmark() or g.monopoly_boosted(c)):
		draw_polyline(loop, WrD.GOLD, 1.5, true)   # 독점 · 랜드마크는 소유자 색을 덮지 않고 금빛 실선만 얹는다
	if c.double_toll:
		draw_polyline(loop, WrIcons.a(WrD.RED, 0.55 + 0.35 * sin(time * 3.4 + cen)), 3.0, true)
	if picking and (not pick_filter.is_valid() or pick_filter.call(c)):
		draw_polyline(loop, WrIcons.a(WrD.GOLD, 0.6 + 0.4 * sin(time * 5.0 + cen * 0.4)), 5.0, true)
	var p := cell_center(c.index) + Vector2(0, lift)
	var uv := cell_box(c.index).get_center()
	if c.is_property():
		# 칸 위 글은 이름 · 금액 두 줄이고 **판 바닥에 눕혀** 쓴다(판과 같이 기울어진다).
		# 건물은 칸의 뒤쪽 모서리에 서므로 글은 앞쪽으로 조금 비켜 둔다.
		var tuv := uv - _back_uv(c.index) * LABEL_BACK
		WrIcons.push(self, _floor_xf(iso(tuv.x, tuv.y) + Vector2(0, lift), _is_row(c.index)))
		var gc := c.group_color()
		var oc2 := WrIcons.darken(gc, 0.45)
		# 글 폭은 칸 폭(판 1칸) 안 — 넘치면 줄인다. 넘치게 두면 옆 칸 이름과 붙어 한 단어처럼 읽힌다.
		WrIcons.text(self, c.name, 24, Color.WHITE, Rect2(-31, -30, 62, 30), 1, 10.0, 5, oc2)
		var price := WrD.m(g.toll(c)) if owned else WrD.m(c.price)
		var pc := Color.WHITE   # 금빛은 노랑 · 주황 칸에서 안 읽혔다
		if c.double_toll:
			price += " X2"
		WrIcons.text(self, price, 22, pc, Rect2(-31, 2, 62, 28), 1, 10.0, 5, oc2)
		WrIcons.pop(self)
	else:
		# 특수칸 그림은 랜드마크처럼 세운다(WrIcons.special_art) — 아래 끝을 칸 바닥에 붙여야 안 뜬다. 흔들지도 말 것.
		# 그림이 없으면 예전처럼 벡터 아이콘을 눌러서 바닥에 인쇄한다.
		var big := c.is_corner()
		var back := _back_uv(c.index)
		var buv := uv + back * 0.24
		var print_at := p + Vector2(0, -12.0) if big else iso(buv.x, buv.y) + Vector2(0, lift)
		var wd := 170.0 if big else 72.0
		var stand := _building_at(c.index)
		var stood := WrIcons.special_art(self, c.type, p.x, p.y + 30.0, 150.0, 130.0) if big \
				else WrIcons.special_art(self, c.type, stand.x, stand.y + lift + HH * LM_HALF * 2.0,
					HW * LM_HALF * (3.2 if c.type == WrD.T.CHANCE else 4.0), 62.0 if c.type == WrD.T.CHANCE else 76.0,
					c.type == WrD.T.CHANCE and _is_row(c.index))   # 황금열쇠: 조금 작게, 가로 줄(아래 · 위)에서는 칸 방향에 맞춰 뒤집는다
		if not stood:
			WrIcons.push(self, Transform2D(0.0, Vector2(1.0, HH / HW), 0.0, print_at))
			WrIcons.special(self, c.type, Rect2(-wd * 0.5, -wd * 0.5, wd, wd), time)
			WrIcons.pop(self)
		if big:
			WrIcons.text(self, c.name, 26, Color.WHITE, Rect2(p.x - 90, p.y + 30, 180, 34), 1, 12.0, 6, WrD.INK)
		else:
			var luv := uv - back * 0.34
			WrIcons.push(self, _floor_xf(iso(luv.x, luv.y) + Vector2(0, lift), _is_row(c.index)))
			WrIcons.text(self, c.name, 20, WrD.INK, Rect2(-31, -14, 62, 28), 1, 10.0)
			WrIcons.pop(self)


## 아래 변(행 8 — 하와이 줄)과 위 변(행 0 — 몰디브 줄)의 칸인가. 모서리 칸은 아니다.
func _is_row(i: int) -> bool:
	var gp := WrD.grid_pos(i)
	return (gp.x == 0 or gp.x == WrD.GRID - 1) and gp.y != 0 and gp.y != WrD.GRID - 1


## 판 바닥에 눕힌 글 좌표계. 둘 다 판의 축이라 글이 판 위에 칠해진 것처럼 기울어진다.
## - 왼쪽 · 오른쪽 변(서울 줄): 글이 오른쪽 위로 읽힌다(x = 판의 오른쪽 위 축).
## - 아래 · 위 변(하와이 · 몰디브 줄): **그것을 오른쪽으로 90도 돌린 것** — 글이 오른쪽 아래로 읽힌다.
##   두 변의 칸은 그 방향으로 길쭉하지 않아도, 이렇게 해야 칸 줄을 따라 같은 쪽으로 읽힌다(사용자 지정).
func _floor_xf(at: Vector2, row: bool) -> Transform2D:
	var up_right := Vector2(HW, -HH).normalized()
	var down_right := Vector2(HW, HH).normalized()
	if row:
		return Transform2D(down_right, -up_right, at)
	return Transform2D(up_right, down_right, at)


## 건물이 서는 쪽(판 좌표) — **칸의 뒤쪽 모서리**(화면에서 위). 앞쪽에 세우면 그 뒤의 글을 가린다.
## 아래 · 위 변은 칸의 오른쪽 위(-v), 왼쪽 · 오른쪽 변은 칸의 왼쪽 위(-u).
func _back_uv(i: int) -> Vector2:
	return Vector2(0, -1) if _is_row(i) else Vector2(-1, 0)

# ---------- 판 가운데 ----------


## 판 가운데는 비워 둔다 — 광장 · 이름 · 기금 · 라운드만.
const LOGO_W := 220.0   ## 판 가운데 "월드 러너" 글자 폭 상한(안쪽 원 폭 300 안에 테두리까지 들어가게)

func _draw_plaza() -> void:
	var c := iso(BL * 0.5, BL * 0.5)
	# 광장 그림(runner_plaza, 판과 같은 45° 로 내려다본 둥근 광장)이 있으면 타원 두 겹 대신 그것을 깐다
	var pz := WrIcons.art("runner_plaza")
	if pz != null:
		var pw := 640.0
		var ph := pw * HH / HW
		draw_texture_rect(pz, Rect2(c.x - pw * 0.5, c.y - ph * 0.5, pw, ph), false)
	else:
		WrIcons.fe(self, Color8(150, 210, 130), c.x - 300, c.y - 170, 600, 340)
		WrIcons.estroke(self, Color8(230, 220, 190), 10, c.x - 250, c.y - 142, 500, 284)
		WrIcons.estroke(self, Color8(230, 220, 190), 6, c.x - 150, c.y - 86, 300, 172)
	var f := UiKit.font()
	if dice_visible:
		_draw_center_panel(c)   # 주사위를 굴리는 동안은 로고를 빼서 겹치지 않게
		return
	var logo := "월드 러너"
	# 글자는 안쪽 원(폭 300) 안에 들어가야 한다 — 64 로 고정했더니 테두리 12 까지 더해 원 밖으로 삐져나왔다
	var size := 64.0
	var total := WrIcons.text_w(logo, size)
	if total > LOGO_W:
		size *= LOGO_W / total
		total = WrIcons.text_w(logo, size)
	var x := c.x - total / 2
	for i in logo.length():
		var ch := logo[i]
		var w := WrIcons.text_w(ch, size)
		var bob := sin(time * 2.2 + i * 0.6) * 3.0
		draw_string_outline(f, Vector2(x, c.y + 10 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), 8, Color8(70, 50, 30, 200))
		draw_string(f, Vector2(x, c.y + 10 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), WrIcons.mix(WrD.GOLD, Color8(255, 245, 210), 0.5 + 0.5 * sin(time * 2.0 + i)))
		x += w
	_draw_center_panel(c)


## 기금 판 — 판 가운데에서 유일하게 큰 숫자
func _draw_center_panel(c: Vector2) -> void:
	var pr := Rect2(c.x - 150, c.y - 128, 300, 70)
	WrIcons.fill_round(self, Color8(40, 34, 20, 230), pr, 14)
	WrIcons.stroke_round(self, WrD.GOLD, 2.5, pr, 14)
	WrIcons.text(self, "라운드 %d / %d   기금" % [g.round_n, WrD.MAX_ROUND], 17, WrIcons.a(WrD.GOLD, 0.85), Rect2(pr.position.x, pr.position.y + 4, pr.size.x, 24))
	WrIcons.text(self, WrD.won(int(roundf(g.fund_shown))), 32, WrD.WHITE, Rect2(pr.position.x, pr.position.y + 26, pr.size.x, 40))

# ---------- 서 있는 것(건물 · 깃발 · 말) ----------


## 건물과 말은 칸과 달리 **똑바로 선다**. 화면 아래에 있을수록 앞이므로 y 순으로 그린다.
func _draw_objects() -> void:
	var items: Array = []   # [y, 종류, 값]
	for c: WrD.Cell in g.cells:
		if c.owner >= 0 and c.is_property():
			items.append([_building_at(c.index).y, 0, c])
	for i in g.players.size():
		var p: WrGame.Player = g.players[i]
		if p.alpha > 0.01:
			items.append([token_point(p).y, 1, p])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it: Array in items:
		if it[1] == 0:
			_draw_building(it[2])
		else:
			_draw_token(it[2])


## 건물이 서는 자리 — 칸의 바깥쪽 끝(글은 안쪽에).
func _building_at(i: int) -> Vector2:
	# 칸의 바깥쪽 끝에서 조금 안쪽 — 판 가장자리에 걸치듯 선다
	var b := cell_box(i)
	var back := _back_uv(i)
	# 그 쪽 가장자리에서 조금 안쪽 — 칸의 길이가 쪽마다 다르니 판 좌표 크기에서 잰다
	var half := absf(back.x) * b.size.x * 0.5 + absf(back.y) * b.size.y * 0.5
	var uv := b.get_center() + back * (half - 0.36)
	return iso(uv.x, uv.y)


## 건물은 **판과 같은 각도로 기울어진 상자**다(바닥 마름모 + 옆면 둘 + 윗면). 단계마다 높이와 지붕이 다르고
## 색은 소유자 색 — 누구 땅인지가 건물 색으로 읽힌다. 랜드마크만은 금빛 받침 위에 그 도시의 도안을 세운다.
func _draw_building(c: WrD.Cell) -> void:
	var p := _building_at(c.index)
	var oc: Color = g.players[c.owner].color
	var pop := (1.0 - WrIcons._out_bounce(c.build_pop)) if c.build_pop > 0.0 else 0.0
	var grow := 1.0 - pop * 0.6
	# 건물 그림(runner_bld_*) — 랜드마크와 같은 길(원래 색 + 청록 부분만 소유자 색). 없으면 아래 벡터 상자.
	# 크기는 단계마다 키운다(별장 < 빌딩 < 호텔 < 랜드마크) — 한 칸에 서는 높이가 곧 통행료의 크기로 읽힌다.
	if c.level >= 1 and c.level <= 3:
		var bt := WrIcons.art(BLD_ART[c.level - 1])
		if bt != null:
			WrIcons.landmark_art(self, bt, p.x, p.y + HH * LM_HALF * 1.4, HW * LM_HALF * BLD_W[c.level - 1], oc, c.build_pop)
			return
	match c.level:
		0:
			# 땅만 가졌으면 깃발
			draw_line(p, p + Vector2(0, -50), Color8(80, 70, 60), 3.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(1, -50), p + Vector2(30, -42), p + Vector2(1, -34)]), oc)
		1:
			# 별장 — 낮은 상자 + 박공지붕
			var top := _iso_box(p, 0.24, 18.0 * grow, oc, true)
			var apex := p + Vector2(0, -18.0 * grow - 20.0 * grow)
			draw_colored_polygon(PackedVector2Array([top[3], top[2], apex]), WrIcons.darken(oc, 0.05))
			draw_colored_polygon(PackedVector2Array([top[2], top[1], apex]), WrIcons.darken(oc, 0.3))
			draw_colored_polygon(PackedVector2Array([top[0], top[3], apex]), WrIcons.lighten(oc, 0.2))
		2:
			_iso_box(p, 0.22, 44.0 * grow, oc, false, 3)
		3:
			var top := _iso_box(p, 0.27, 62.0 * grow, oc, false, 4)
			draw_colored_polygon(top, WrD.GOLD)   # 호텔 — 금빛 옥상
			draw_line(p + Vector2(0, -62.0 * grow), p + Vector2(0, -62.0 * grow - 18), WrD.GOLD, 2.0)
			draw_circle(p + Vector2(0, -62.0 * grow - 20), 3.0, Color8(255, 90, 90))
		_:
			# 도안이 없는 도시는 기본 첨탑 그림(runner_lm_generic)
			var tex := WrIcons.art("runner_lm_" + (c.landmark if c.landmark != "" else "generic"))
			if tex != null:
				# 그림은 받침대까지 그려져 있다 — 금빛 받침 · 그림자 없이 받침 앞 꼭짓점을 칸 바닥에 붙인다(사용자 결정:
				# 받침 위에 얹으면 떠 보인다). 받침은 건물 자리 둘레 반폭 LM_HALF 칸 마름모 안에 든다
				WrIcons.landmark_art(self, tex, p.x, p.y + HH * LM_HALF * 2.0, HW * LM_HALF * 4.0, oc, c.build_pop)
			else:
				_iso_box(p, 0.32, 10.0, WrD.GOLD, false)
				WrIcons.building(self, WrD.MAX_LEVEL, p.x, p.y - 10.0, 64.0, 44.0, oc, c.build_pop, c.landmark)


## 건물 그림 이름과 폭(LM_HALF 칸 대비) — 별장 · 빌딩 · 호텔. 랜드마크는 4.0 이다.
const BLD_ART := ["runner_bld_villa", "runner_bld_building", "runner_bld_hotel"]
const BLD_W := [2.4, 2.6, 3.0]

## 바닥 중심 p 에 판과 같은 각도의 상자를 세운다. k = 바닥 크기(칸 대비), h = 높이.
## 윗면 네 점을 돌려준다(지붕을 얹으라고). rows > 0 이면 앞 두 면에 창문 줄.
func _iso_box(p: Vector2, k: float, h: float, col: Color, plain: bool, rows: int = 0) -> PackedVector2Array:
	var hw := HW * k
	var hh := HH * k
	var n := p + Vector2(0, -hh)
	var e := p + Vector2(hw, 0)
	var s := p + Vector2(0, hh)
	var w := p + Vector2(-hw, 0)
	var up := Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([w, s, s + up, w + up]), WrIcons.darken(col, 0.08))
	draw_colored_polygon(PackedVector2Array([s, e, e + up, s + up]), WrIcons.darken(col, 0.32))
	var top := PackedVector2Array([n + up, e + up, s + up, w + up])
	draw_colored_polygon(top, WrIcons.lighten(col, 0.25))
	var line := WrIcons.darken(col, 0.5)
	draw_polyline(PackedVector2Array([w + up, w, s, e, e + up]), line, 1.5, true)
	draw_line(s, s + up, line, 1.5, true)
	if not plain and rows > 0:
		var glass := Color8(220, 236, 255, 230)
		for r in rows:
			var y := -h * (r + 0.6) / (rows + 0.4)
			for t in [0.3, 0.7]:
				var a := w.lerp(s, t) + Vector2(0, y)
				var b := s.lerp(e, t) + Vector2(0, y)
				draw_line(a + Vector2(-3, 0), a + Vector2(3, 3), glass, 4.0)
				draw_line(b + Vector2(-3, 3), b + Vector2(3, 0), glass, 4.0)
	return top


func _draw_token(p: WrGame.Player) -> void:
	var pt := token_point(p)
	var active := scr == Scr.PLAY and g.current() == p and not g.over
	# 벡터 말은 내 말을 크기로만 구분한다. 그림 말은 넷이 같은 크기 — 옷 색이 이미 갈라 준다(사용자 결정)
	var big := not p.ai and WrIcons.art("runner_char_%d" % p.face) == null
	var r := (29.0 if big else 24.0) * p.scale
	WrIcons.token(self, pt.x, pt.y - r * 1.1, r, p.color, p.squash, active, p.emote_kind, time + p.id, p.alpha, p.face, true)

# ---------- 화면에 붙는 것 ----------


func _rank_of(p: WrGame.Player) -> int:
	var k := 1
	for q: WrGame.Player in g.players:
		if q != p and (q.alive and not p.alive or (q.alive == p.alive and g.net_worth(q) > g.net_worth(p))):
			k += 1
	return k


func _draw_hud() -> void:
	for i in g.players.size():
		_draw_player_card(g.players[i], card_rect(i))
	if wide():
		UiKit.button(self, vs, "hub", "runner", time, "나가기")   # 다른 게임과 같은 자리 · 이름 · 단추(예전엔 상태창 아래 "그만하기")
		UiKit.button(self, vs, "vol", "runner", time)
	else:
		_draw_small_btn(_menu_rect(), "나가기", Color8(20, 40, 80, 200))
		_draw_small_btn(_vol_play_rect(), "설정", Color8(20, 40, 80, 200))
	_draw_small_btn(_speed_rect(), "속도 x%d" % int(speed), Color8(20, 40, 80, 200))
	if picking:
		var hr := Rect2(vs.x * 0.5 - 170, view.position.y + 8, 340, 48)
		WrIcons.fill_round(self, Color8(20, 30, 60, 220), hr, 24)
		WrIcons.stroke_round(self, WrD.GOLD, 2.0, hr, 24)
		WrIcons.text(self, "갈 칸을 고릅니다", FS_BODY, WrD.GOLD, hr)
	if dice_visible and (dice_rolling or dice_glow > 0.0 or dice_rolled and buttons.is_empty()):
		var ds := 96.0
		var dc := dice_r.get_center()
		if dice_glow > 0.0:
			WrIcons.glow_round(self, WrD.GOLD, Rect2(dc.x - ds - 20, dc.y - ds * 0.7, (ds + 20) * 2, ds * 1.4), 24, 22, dice_glow * 1.6)
		WrIcons.dice(self, dc - Vector2(ds * 0.62, 0), ds, die1, die_rot1, die_scale)
		WrIcons.dice(self, dc + Vector2(ds * 0.62, 0), ds, die2, die_rot2, die_scale)
		if not dice_rolling and die1 == die2:
			WrIcons.text(self, "더블", FS_SUB, WrD.GOLD, Rect2(dc.x - 100, dc.y + ds * 0.55, 200, 36), 1, 14.0, 5)
	# 단추 — 굴리기는 가운데 큰 원, 나머지는 한 줄
	var n := buttons.size()
	if n == 1 and buttons[0].get("round", false):
		var c := action_r.get_center()
		buttons[0].rect = Rect2(c - Vector2(86, 86), Vector2(172, 172)).grow(-6)
		_draw_round_button(buttons[0], c)
	elif n > 0:
		var gp := 12.0
		var w := (action_r.size.x - gp * (n - 1)) / n
		for i in n:
			buttons[i].rect = Rect2(action_r.position.x + i * (w + gp), action_r.position.y + 10, w, action_r.size.y - 20)
		for b: Dictionary in buttons:
			_draw_button(b)
	elif prompt != "":
		var pr := Rect2(vs.x * 0.5 - 200, action_r.get_center().y - 26, 400, 52)
		WrIcons.fill_round(self, Color8(20, 30, 60, 200), pr, 26)
		WrIcons.text(self, prompt, FS_BODY, WrD.WHITE, pr.grow(-10), 1, 14.0)


func _draw_round_button(b: Dictionary, c: Vector2) -> void:
	var r: float = 80.0 * (1.0 - b.press * 0.08) * (0.9 + 0.1 * e_out_back(b.inn))
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	draw_circle(c + Vector2(0, 8), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r + 10 + pulse * 6, WrIcons.a(WrD.GOLD, 0.25))
	draw_circle(c, r, Color8(200, 40, 60))
	draw_circle(c + Vector2(0, -6), r - 8, Color8(240, 80, 90))
	WrIcons.fe(self, Color(1, 1, 1, 0.35), c.x - r * 0.55, c.y - r * 0.8, r * 1.1, r * 0.5)
	draw_arc(c, r, 0, TAU, 48, Color8(120, 20, 40), 4.0, true)
	WrIcons.text(self, "굴리기", 38, Color.WHITE, Rect2(c.x - r, c.y - 30, r * 2, 50), 1, 20.0, 6, Color8(120, 20, 40))
	WrIcons.text(self, "Space", 16, Color(1, 1, 1, 0.7), Rect2(c.x - r, c.y + 20, r * 2, 24))


## 판 위 작은 단추(그만하기 · 속도) — 다섯 게임 같은 입체 단추(UiKit).
func _draw_small_btn(r: Rect2, label: String, col: Color) -> void:
	UiKit.plain(self, r, label, Color(col.r, col.g, col.b).lightened(0.25), "runner", time, true, FS_SMALL)


## 플레이어 패널(사용자가 보내 준 모바일 보드게임 상태창 모양 — 11-08):
##   왼쪽 큰 원형 순위 배지 · 가운데 두 줄(금색 보유 현금 + "현금" 꼬리표 / 분홍 총자산 + "총자산" 꼬리표) · 아랫줄 상태 ·
##   오른쪽 위로 튀어나온 초상 액자(이름 꼬리표 · 오른쪽 아래 동그라미 = 가진 도시 수). 어느 모서리든 같은 방향으로 그린다.
func _draw_player_card(p: WrGame.Player, r: Rect2) -> void:
	var active := g.current() == p and not g.over and scr == Scr.PLAY
	var al := 1.0 if p.alive else 0.45
	var pw := 98.0                                   # 초상 액자 폭
	var body := Rect2(r.position.x + 44, r.position.y + 30, r.size.x - 44 - pw * 0.55, r.size.y - 36)
	if active:
		WrIcons.glow_round(self, p.color, body, 12, 8 + (0.5 + 0.5 * sin(time * 3.0)) * 8, 1.2)
	# 몸통 띠 — 어두운 바탕에 플레이어 색이 살짝, 위에 밝은 선
	WrIcons.fill_round_grad(self, WrIcons.a(WrIcons.mix(Color8(34, 38, 66), p.color, 0.3 if active else 0.16), 0.95 * al),
			WrIcons.a(Color8(16, 18, 36), 0.95 * al), body, 12)
	WrIcons.stroke_round(self, WrIcons.a(WrIcons.mix(p.color, Color.WHITE, 0.3), (1.0 if active else 0.55) * al), 2.4 if active else 1.4, body, 12)
	draw_line(body.position + Vector2(14, 2), Vector2(body.end.x - 14, body.position.y + 2), WrIcons.a(Color.WHITE, 0.35 * al), 2.0)
	# 초상 액자 — 몸통 위로 튀어나온다
	var pc := Rect2(r.end.x - pw - 4, r.position.y + 4, pw, r.size.y - 12)
	WrIcons.fill_round_grad(self, WrIcons.a(WrIcons.mix(p.color, Color.WHITE, 0.5), al), WrIcons.a(WrIcons.mix(p.color, Color.BLACK, 0.2), al), pc, 12)
	WrIcons.stroke_round(self, WrIcons.a(Color8(255, 226, 150), al), 3.0, pc, 12)
	WrIcons.token(self, pc.get_center().x, pc.get_center().y + 14, 34, p.color, 0.0, false, p.emote_kind, time + p.id, al, p.face)
	# 이름 꼬리표 — 액자 왼쪽 위
	var nt := Rect2(pc.position.x - 6, pc.position.y - 2, pc.size.x * 0.78, 26)
	WrIcons.fill_round(self, WrIcons.a(Color8(20, 20, 40), 0.85 * al), nt, 8)
	WrIcons.text(self, p.name, 18, WrIcons.a(WrD.WHITE, al), nt.grow(-3), 1, 11.0)
	# 가진 도시 수 — 액자 오른쪽 아래 동그라미
	var oc := Vector2(pc.end.x - 10, pc.end.y - 10)
	draw_circle(oc, 18, WrIcons.a(Color8(36, 40, 80), al))
	draw_arc(oc, 18, 0, TAU, 24, WrIcons.a(Color8(255, 226, 150), al), 2.0, true)
	WrIcons.text(self, str(g.owned(p.id).size()), 18, WrIcons.a(WrD.WHITE, al), Rect2(oc - Vector2(16, 12), Vector2(32, 24)), 1, 10.0)
	# 순위 배지 — 왼쪽 큰 원(살아 있으면 순위, 아니면 상태)
	var bc := Vector2(r.position.x + 46, body.get_center().y + 4)
	var rad := 42.0
	var rank_c := Color8(214, 52, 52) if _rank_of(p) == 1 else Color8(170, 40, 50)
	draw_circle(bc + Vector2(0, 3), rad, Color(0, 0, 0, 0.35 * al))
	draw_circle(bc, rad, WrIcons.a(rank_c.darkened(0.25), al))
	draw_circle(bc, rad * 0.82, WrIcons.a(rank_c, al))
	draw_circle(bc + Vector2(-rad * 0.25, -rad * 0.3), rad * 0.35, Color(1, 1, 1, 0.12 * al))
	draw_arc(bc, rad, 0, TAU, 40, WrIcons.a(Color8(255, 226, 150), al), 3.0, true)
	var st := "%d위" % _rank_of(p)
	var sc := Color.WHITE
	if not p.alive:
		st = "파산"
	WrIcons.text(self, st, 30 if p.alive else 22, WrIcons.a(sc, al), Rect2(bc - Vector2(rad, 20), Vector2(rad * 2, 40)), 1, 14.0, 4)
	# 두 줄 — 보유 현금 · 총자산, 오른쪽에 꼬리표
	var tx := bc.x + rad + 8
	var tw := pc.position.x - 8 - tx
	var lw := 54.0
	var row1 := Rect2(tx, body.position.y + 4, tw - lw - 4, 32)
	var row2 := Rect2(tx, body.position.y + 38, tw - lw - 4, 28)
	WrIcons.text(self, WrD.won(int(roundf(p.shown_cash))), FS_SUB, WrIcons.a(WrD.BAD if p.cash <= 20 else WrD.GOLD, al), row1, 2, 14.0, 4)
	WrIcons.text(self, WrD.m(g.net_worth(p)), FS_SMALL + 2, WrIcons.a(Color8(255, 120, 140), al), row2, 2, 12.0, 3)
	for k in 2:
		var lr := Rect2(row1.end.x + 4, (row1 if k == 0 else row2).position.y + 4, lw, 24)
		WrIcons.fill_round(self, WrIcons.a(Color8(70, 74, 110), 0.9 * al), lr, 6)
		WrIcons.text(self, "현금" if k == 0 else "총자산", 15, WrIcons.a(Color8(230, 234, 255), al), lr, 1, 10.0)
	# 아랫줄 — 상태(무인도 · 우주여행 · 탈출권)
	var sub := ""
	var subc := WrD.DIM
	if p.alive and p.jail > 0:
		sub = "무인도 %d턴" % p.jail
		subc = WrD.SEA
	elif p.alive and p.pending_space:
		sub = "우주여행 준비"
		subc = WrD.ACCENT
	elif p.alive and p.escapes > 0:
		sub = "탈출권 %d장" % p.escapes
		subc = WrD.GOLD
	if sub != "":
		WrIcons.text(self, sub, 16, WrIcons.a(subc, al), Rect2(tx, body.end.y - 26, tw, 22), 0, 10.0)

# ---------- 단추 ----------


func _draw_button(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	if r.size.x <= 1.0:
		return
	var in_t := e_out_back(b.inn)
	var lift: float = b.hover * 3.0 - b.press * 4.0
	var sc := 0.92 + 0.08 * in_t
	var rr := Rect2(r.position.x + r.size.x * (1 - sc) / 2, r.position.y - lift + r.size.y * (1 - sc) / 2, r.size.x * sc, r.size.y * sc)
	var rad := 14.0
	var al := minf(1.0, b.inn * 1.4)
	var c: Color = b.col if b.enabled else Color8(60, 66, 88)
	if b.primary and b.enabled:
		WrIcons.glow_round(self, c, rr, rad, 7 + b.hover * 8 + sin(time * 3.0) * 2, 1.0)
	# 몸통은 다섯 게임 같은 입체 단추(UiKit) — 글(위 큰 글 · 아래 작은 글)은 이 게임이 얹는다
	if al > 0.05:
		UiKit.draw(self, rr, "menu", "", c, Color(1, 1, 1), UiKit.theme("runner"), b.hover > 0.5 and b.enabled, time)
	var has_sub := String(b.sub) != ""
	var lab_r := Rect2(rr.position.x + 6, rr.position.y + rr.size.y * 0.06, rr.size.x - 12, rr.size.y * 0.56) if has_sub else rr.grow(-6)
	WrIcons.text(self, b.label, minf(FS_SUB, rr.size.y * 0.42), WrIcons.a(Color.WHITE if b.enabled else WrD.DIM, al), lab_r, 1, 12.0)
	if has_sub:
		WrIcons.text(self, b.sub, FS_TINY, WrIcons.a(Color8(235, 240, 255), al * 0.75),
				Rect2(rr.position.x + 6, rr.position.y + rr.size.y * 0.56, rr.size.x - 12, rr.size.y * 0.34), 1, 10.0)

# ---------- 배너 ----------


func _draw_banner() -> void:
	if banner_t <= 0.0 or banner_text == "":
		return
	var t := banner_t
	var in_t := minf(1.0, (1.0 - maxf(0.0, t - 0.25)) * 4.0)
	var appear := e_out_quint(minf(1.0, in_t))
	var fade := t / 0.25 if t < 0.25 else 1.0
	var h := maxf(110.0, vs.y * 0.1)
	var w := minf(vs.x * 0.86, vs.x - (card_w() + 30.0) * 2.0) if wide() else vs.x * 0.86   # 가로 화면은 위 상태창 사이 — 판을 덮지 않게
	var x := vs.x / 2 - w / 2 + (1.0 - appear) * vs.x * 0.35
	var r := Rect2(x, 16.0 if wide() else view.position.y + view.size.y * 0.3, w, h)
	var pts := WrIcons.rr_pts(r, 16)
	var cols := PackedColorArray()
	for p in pts:
		var k := (p.x - r.position.x) / r.size.x
		cols.append(WrIcons.a(WrIcons.darken(banner_col, lerpf(0.55, 0.2, k)), fade * 0.92))
	draw_polygon(pts, cols)
	WrIcons.stroke_round(self, WrIcons.a(WrIcons.lighten(banner_col, 0.4), fade), 2.0, r, 16)
	WrIcons.glow_round(self, banner_col, r, 16, 12, fade)
	var has_sub := banner_sub != ""
	WrIcons.text(self, banner_text, FS_HUGE, WrIcons.a(Color.WHITE, fade),
			Rect2(r.position.x + 10, r.position.y + h * 0.06, r.size.x - 20, h * 0.55) if has_sub else r, 1, 20.0, 5, Color(0, 0, 0, 0.4 * fade))
	if has_sub:
		WrIcons.text(self, banner_sub, FS_SUB, WrIcons.a(Color8(240, 245, 255), fade * 0.9),
				Rect2(r.position.x + 10, r.position.y + h * 0.6, r.size.x - 20, h * 0.32), 1, 12.0)

# ---------- 창 ----------


func _modal_rect(m: Modal) -> Rect2:
	var w := minf(620.0, vs.x - 40.0)
	var h := 360.0
	if m.cell != null:
		h = 670.0
	if not m.chance.is_empty():
		h = 540.0
	if m.buttons.is_empty():
		h -= 80.0
	if m.vertical:
		h = 220.0 + m.buttons.size() * 82.0
	h = minf(h, vs.y - 40.0)
	return Rect2(vs.x / 2 - w / 2, vs.y / 2 - h / 2, w, h)


func _layout_modal_buttons(m: Modal) -> void:
	var n := m.buttons.size()
	if n == 0:
		return
	var mr := _modal_rect(m)
	if m.vertical:
		var bh := 72.0
		var gp := 10.0
		var y0 := mr.end.y - 20 - (n * bh + (n - 1) * gp)
		for i in n:
			m.buttons[i].rect = Rect2(mr.position.x + 22, y0 + i * (bh + gp), mr.size.x - 44, bh)
		return
	var gp := 12.0
	var w := (mr.size.x - 40 - gp * (n - 1)) / n
	var h := 76.0
	for i in n:
		m.buttons[i].rect = Rect2(mr.position.x + 20 + i * (w + gp), mr.end.y - h - 20, w, h)


func _draw_modal(m: Modal) -> void:
	_layout_modal_buttons(m)
	var t := e_out_back(minf(1.0, m.t))
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(6, 8, 18, int(150 * minf(1.0, m.t * 1.4))), true)
	var r := _modal_rect(m)
	var k := 0.86 + 0.14 * t
	var c := r.get_center()
	WrIcons.push(self, Transform2D(0.0, Vector2(k, k), 0.0, c - c * k))
	WrIcons.shadow(self, r, 20, 10, 1.2)
	WrIcons.fill_round_grad(self, Color8(44, 52, 92, 248), Color8(26, 32, 60, 248), r, 20)
	WrIcons.stroke_round(self, WrIcons.a(m.accent, 0.86), 2.0, r, 20)
	WrIcons.glow_round(self, m.accent, r, 20, 14, 0.9)
	var y := r.position.y + 18
	if m.title != "":
		WrIcons.text(self, m.title, FS_TITLE, WrD.WHITE, Rect2(r.position.x + 20, y, r.size.x - 40, 44))
		y += 52
	if not m.chance.is_empty():
		_draw_chance_card(m, Rect2(r.position.x + 40, y, r.size.x - 80, 280))
		y += 292
	elif m.cell != null:
		var cw := 360.0
		_draw_city_card(m.cell, Rect2(r.get_center().x - cw / 2, y, cw, 400))
		y += 412
	if m.body != "":
		WrIcons.text_wrap(self, m.body, FS_BODY, WrIcons.a(WrD.WHITE, 0.88), Rect2(r.position.x + 24, y, r.size.x - 48, 84))
	if m.who != null and m.buttons.is_empty():
		WrIcons.text(self, m.who.name + " 의 선택", FS_SMALL, WrIcons.a(m.who.color, 0.94),
				Rect2(r.position.x, r.end.y - 40, r.size.x, 28))
	WrIcons.pop(self)
	for b: Dictionary in m.buttons:
		_draw_button(b)


func _draw_city_card(c: WrD.Cell, r: Rect2) -> void:
	WrIcons.fill_round_grad(self, Color8(250, 252, 255), Color8(222, 228, 244), r, 16)
	WrIcons.paper(self, r)
	var band_h := r.size.y * 0.24
	var pts := WrIcons.rr_pts(r, 16)
	var cols := PackedColorArray()
	var gc := c.group_color()
	for i in pts.size():
		pts[i].y = minf(pts[i].y, r.position.y + band_h)
		cols.append(WrIcons.lighten(gc, 0.25).lerp(gc, (pts[i].y - r.position.y) / band_h))
	draw_polygon(pts, cols)
	WrIcons.stroke_round(self, gc, 2.4, r, 16)
	WrIcons.flag(self, c.flag, Rect2(r.position.x + 16, r.position.y + band_h * 0.2, 84, 56))
	WrIcons.text(self, c.name, FS_TITLE, Color.WHITE, Rect2(r.position.x + 112, r.position.y + 10, r.size.x - 124, 44), 0, 18.0,
			4, Color(0, 0, 0, 0.3))
	var sub: String = c.country if c.group == "" else (WrD.GROUPS[c.group][0] if c.country == c.name else c.country + ", " + WrD.GROUPS[c.group][0])
	WrIcons.text(self, sub, FS_SMALL, Color(1, 1, 1, 0.9), Rect2(r.position.x + 112, r.position.y + 56, r.size.x - 124, 24), 0, 11.0)
	var y := r.position.y + band_h + 10
	if c.double_toll:
		var chip := Rect2(r.end.x - 130, y, 116, 28)
		WrIcons.fill_round(self, Color8(238, 68, 68), chip, 14)
		WrIcons.text(self, "통행료 2배", FS_SMALL, Color.WHITE, chip)
	WrIcons.text(self, "매입가  " + WrD.won(c.price), FS_SUB, WrD.INK, Rect2(r.position.x + 18, y, r.size.x - 160, 30), 0)
	y += 40
	if c.type == WrD.T.SPOT:
		WrIcons.text(self, "관광지, 건물 건설 불가", FS_BODY, WrD.INK_SOFT, Rect2(r.position.x + 18, y, r.size.x - 36, 28), 0)
		y += 34
		WrIcons.text(self, "통행료 = %s x 보유 관광지 수" % WrD.m(c.tolls[0]), FS_BODY, WrD.INK, Rect2(r.position.x + 18, y, r.size.x - 36, 28), 0)
	else:
		for i in WrD.MAX_LEVEL + 1:
			var cur := c.owner >= 0 and c.level == i
			var lm := i == WrD.MAX_LEVEL
			var row := Rect2(r.position.x + 12, y, r.size.x - 24, 34)
			if cur:
				WrIcons.fill_round(self, WrIcons.a(WrD.GOLD if lm else gc, 0.37 if lm else 0.22), row, 8)
			var col := WrD.INK if cur else (WrD.GOLD_DEEP if lm else WrD.INK_SOFT)
			var label: String = WrD.landmark_name(c.landmark) if lm and c.landmark != "" else WrD.LEVEL_NAMES[i]
			WrIcons.text(self, label, FS_BODY, col, Rect2(row.position.x + 10, row.position.y, 150, row.size.y), 0, 12.0)
			WrIcons.text(self, WrD.m(c.tolls[i]), FS_BODY, col, Rect2(row.position.x, row.position.y, row.size.x - 112, row.size.y), 2)
			if i > 0:
				WrIcons.text(self, "건설 " + WrD.m(c.build_cost[i - 1]), FS_TINY, WrD.GOLD_DEEP if lm else WrD.INK_SOFT,
						Rect2(row.position.x, row.position.y, row.size.x - 10, row.size.y), 2)
			y += 36
	if c.owner >= 0:
		var op: WrGame.Player = g.players[c.owner]
		var orr := Rect2(r.position.x + 12, r.end.y - 46, r.size.x - 24, 34)
		WrIcons.fill_round(self, WrIcons.a(op.color, 0.24), orr, 8)
		WrIcons.text(self, "소유: %s   지금 통행료 %s" % [op.name, WrD.m(g.toll(c))], FS_SMALL, WrD.INK, orr, 1, 11.0)
	elif c.group != "":
		WrIcons.text(self, "독점하면 통행료 2배, 랜드마크는 재방문이나 출발 칸에서", FS_TINY - 1, WrD.INK_SOFT,
				Rect2(r.position.x + 8, r.end.y - 36, r.size.x - 16, 26), 1, 10.0)


func _draw_chance_card(m: Modal, r: Rect2) -> void:
	var f := m.flip
	# 0 → 0.5 : 뒷면이 납작해지고, 0.5 → 1 : 앞면이 펼쳐진다
	var sx := maxf(0.03, 1.0 - f * 2.0 if f < 0.5 else (f - 0.5) * 2.0)
	var c := r.get_center()
	WrIcons.push(self, Transform2D(0.0, Vector2(sx, 1.0), 0.0, Vector2(c.x - c.x * sx, 0.0)))
	if f < 0.5:
		WrIcons.fill_round_grad(self, Color8(214, 152, 20), Color8(150, 100, 10), r, 16)
		WrIcons.stroke_round(self, WrD.GOLD, 2.4, r, 16)
		WrIcons.special(self, WrD.T.CHANCE, Rect2(c.x - 60, c.y - 70, 120, 130), time)
		WrIcons.text(self, "황금열쇠", FS_TITLE, Color8(255, 250, 220), Rect2(r.position.x, r.end.y - 60, r.size.x, 40))
	else:
		WrIcons.fill_round_grad(self, Color8(252, 250, 240), Color8(232, 226, 206), r, 16)
		WrIcons.stroke_round(self, WrD.GOLD_DEEP, 2.4, r, 16)
		WrIcons.special(self, WrD.T.CHANCE, Rect2(c.x - 40, r.position.y + 10, 80, 84), time)
		WrIcons.text_wrap(self, String(m.chance[2]), FS_SUB, Color8(40, 36, 30), Rect2(r.position.x + 22, r.position.y + 100, r.size.x - 44, r.size.y - 120))
	WrIcons.pop(self)

# ---------- 칸 정보 ----------


func _draw_info() -> void:
	var i := hover_cell if hover_cell >= 0 else info_cell
	if i < 0 or modal != null:
		return
	var c: WrD.Cell = g.cells[i]
	if not c.is_property():
		return
	var l1 := "%s  (%s)%s" % [c.name, c.country, "   통행료 2배 지역" if c.double_toll else ""]
	var l2 := ("소유 %s, %s, 통행료 %s" % [g.players[c.owner].name, WrD.LEVEL_NAMES[c.level], WrD.won(g.toll(c))]) if c.owner >= 0 \
			else ("빈 땅, 매입가 " + WrD.won(c.price))
	var l3: String
	if c.type != WrD.T.CITY:
		l3 = "관광지 통행료 %s x 보유 수" % WrD.won(c.tolls[0])
	elif c.level < WrD.HOTEL_LEVEL:
		l3 = "다음 건설 %s %s" % [WrD.LEVEL_NAMES[c.level + 1], WrD.won(c.build_cost[c.level])]
	elif c.level == WrD.HOTEL_LEVEL:
		l3 = "다시 오면 랜드마크 " + WrD.won(c.build_cost[WrD.HOTEL_LEVEL])
	else:
		l3 = "랜드마크 완성, 인수 불가"
	var w := minf(600.0, vs.x - 16.0)
	var h := 140.0
	var sp := to_screen(cell_center(i))   # 칸은 월드에 있으니 화면 자리로 바꿔서 그 옆에 띄운다
	var x := clampf(sp.x - w / 2, 8, vs.x - w - 8)
	var y := sp.y + 50 if sp.y < view.get_center().y else sp.y - h - 50
	y = clampf(y, view.position.y, view.end.y - h)
	var r := Rect2(x, y, w, h)
	WrIcons.fill_round(self, Color8(18, 22, 44, 240), r, 12)
	WrIcons.stroke_round(self, c.group_color(), 2.0, r, 12)
	WrIcons.text(self, l1, FS_BODY, WrD.WHITE, Rect2(r.position.x + 16, r.position.y + 10, r.size.x - 32, 36), 0, 14.0)
	WrIcons.text(self, l2, FS_SMALL, WrD.DIM, Rect2(r.position.x + 16, r.position.y + 54, r.size.x - 32, 32), 0, 13.0)
	WrIcons.text(self, l3, FS_SMALL, WrIcons.a(WrD.DIM, 0.8), Rect2(r.position.x + 16, r.position.y + 94, r.size.x - 32, 32), 0, 13.0)

# ---------- 시작 · 결과 · 그만두기 ----------


func _draw_setup() -> void:
	# 게임 이름 — 다섯 게임 같은 방식(UiKit.title)
	UiKit.title(self, vs, "runner", "월드 러너", "세계 도시를 사고 지어 상대를 파산시킵니다", time)
	var rth := UiKit.theme("runner")
	# 왼쪽 — 이번 판에 나올 말들(사람 · AI)
	var humans := 0
	for i in setup_count:
		var sx := (vs.x * 0.3 if wide() else vs.x * 0.5) + (i - (setup_count - 1) * 0.5) * 110.0
		WrIcons.token(self, sx, 420.0, 34, WrD.PLAYER_COLORS[i], 0.0, false, 1, time + i, 1.0, WrGame.face_for(setup_ai, i), true)
		WrIcons.text(self, "AI" if setup_ai[i] else "나", FS_SMALL, WrD.WHITE, Rect2(sx - 50, 470, 100, 30), 1, 10.0, 4)
		if not setup_ai[i]:
			humans += 1
	# 오른쪽 메뉴 — 다섯 게임 같은 구조(모드 · 도감 · 도감 · 순위)
	if not setup_open:
		for j in 1:
			var mb: Dictionary = setup_btns[9 + j]
			var mr: Rect2 = UiKit.menu_rect(vs, j)
			var label := "플레이어 %d명 (사람 %d)" % [setup_count, humans] if j == 0 else String(mb.label)
			UiKit.menu(self, mr, label, mb.col, "runner", time)
		UiKit.button(self, vs, "start", "runner", time, "게임 시작")
		UiKit.button(self, vs, "hub", "runner", time)
		UiKit.button(self, vs, "vol", "runner", time)
		WrRec.load_()
		if WrRec.plays > 0:
			UiKit.record_line(self, vs, "%d판 %d승" % [WrRec.plays, WrRec.wins])
		UiKit.key_hint(self, vs, "Space 시작   Tab 속도   Esc 게임 선택")
		UiKit.plain(self, _rules_rect(), "규칙", UiKit.theme("runner").hub, "runner", time, true, 24)
		book.draw(self, vs, time)
		rules.draw(self, vs, time)
		return
	# 플레이어 설정 창 — 가운데에 겹쳐 뜬다
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var cw := minf(560.0, vs.x * 0.5 - 60.0) if wide() else minf(600.0, vs.x - 60.0)
	var pcx := _setup_panel_x()
	var top := _setup_top()
	var panel := Rect2(pcx - cw / 2, top - 86, cw, 4 * 92 + 190)
	WrIcons.fill_round_grad(self, Color8(40, 48, 86, 236), Color8(24, 30, 58, 236), panel, 20)
	WrIcons.stroke_round(self, Color(1, 1, 1, 0.35), 1.4, panel, 20)
	WrIcons.text(self, "플레이어 %d명" % setup_count, FS_TITLE, WrD.WHITE, Rect2(panel.position.x + 26, top - 66, 300, 50), 0)
	for i in 4:
		var on := i < setup_count
		var rr := Rect2(panel.position.x + 20, top + i * 92 + 6, cw - 40, 74)
		WrIcons.fill_round(self, WrIcons.a(WrIcons.mix(WrD.PANEL, WrD.PLAYER_COLORS[i], 0.2) if on else WrD.PANEL, 0.92 if on else 0.35), rr, 14)
		WrIcons.stroke_round(self, WrIcons.a(WrD.PLAYER_COLORS[i], 0.78 if on else 0.24), 1.4, rr, 14)
		# WrGame.assign_faces 와 같은 규칙 — 사람은 0번, AI 는 1~3번을 차례로
		WrIcons.token(self, rr.position.x + 46, rr.get_center().y + 4, 24, WrD.PLAYER_COLORS[i], 0.0, false, 1 if on else 0,
				time + i, 1.0 if on else 0.35, WrGame.face_for(setup_ai, i))
		WrIcons.text(self, WrD.PLAYER_NAMES[i], FS_SUB, WrIcons.a(WrD.WHITE, 1.0 if on else 0.43),
				Rect2(rr.position.x + 90, rr.position.y, 200, rr.size.y), 0)
		if not on:
			WrIcons.text(self, "빠짐", FS_SMALL, WrIcons.a(WrD.DIM, 0.6), Rect2(rr.position.x, rr.position.y, rr.size.x - 170, rr.size.y), 2)
	# 창 안 단추(인원 -/+ · 사람/AI · 닫기) — 다섯 게임 같은 모양(UiKit 메뉴형)
	for i in [1, 2, 3, 4, 5, 6, 13]:
		var b: Dictionary = setup_btns[i]
		var br: Rect2 = b.rect
		if br.size.x <= 1.0:
			continue
		var fc: Color = b.col if b.enabled else Color8(60, 66, 88)
		UiKit.draw(self, br, "menu", String(b.label), fc, Color(1, 1, 1) if b.enabled else WrD.DIM, rth,
				b.enabled and br.has_point(mouse), time)


func _draw_over() -> void:
	var t := minf(1.0, over_t * 1.2)
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(6, 8, 18, int(180 * t)), true)
	var cx := vs.x / 2
	var w := minf(600.0, vs.x - 40)
	var r := Rect2(cx - w / 2, vs.y * 0.18, w, 520)
	var pop_k := e_out_back(minf(1.0, over_t * 1.6))
	var k := 0.8 + 0.2 * pop_k
	WrIcons.push(self, Transform2D(0.0, Vector2(k, k), 0.0, r.get_center() - r.get_center() * k))
	WrIcons.shadow(self, r, 22, 12, 1.2)
	WrIcons.fill_round_grad(self, Color8(48, 42, 20, 250), Color8(26, 24, 44, 250), r, 22)
	WrIcons.stroke_round(self, WrD.GOLD, 2.4, r, 22)
	WrIcons.glow_round(self, WrD.GOLD, r, 22, 18, 1.0 + 0.4 * sin(time * 2.0))
	WrIcons.text(self, "게임 끝", FS_SUB, WrIcons.a(WrD.DIM, 0.9), Rect2(r.position.x, r.position.y + 18, r.size.x, 34))
	if g != null and g.winner != null:
		var ty := r.position.y + 128
		var bob := sin(time * 3.0) * 6.0
		WrIcons.token(self, cx, ty + bob, 44, g.winner.color, 0.0, false, 4, time, 1.0, g.winner.face)
		for i in 6:
			var ang := time * 1.4 + i * PI / 3.0
			WrIcons.star(self, WrIcons.a(WrD.GOLD, 0.6), cx + cos(ang) * 90, ty + sin(ang) * 54, 9, 5, ang)
		WrIcons.text(self, g.winner.name + " 승리", FS_HUGE, WrD.GOLD, Rect2(r.position.x, ty + 60, r.size.x, 60), 1, 20.0, 5)
		var list := g.players.duplicate()
		list.sort_custom(func(x, y): return g.net_worth(x) > g.net_worth(y))
		var y := ty + 136
		for i in list.size():
			var p: WrGame.Player = list[i]
			var rr := Rect2(r.position.x + 40, y, r.size.x - 80, 40)
			WrIcons.fill_round(self, WrIcons.a(p.color, 0.27 if p.alive else 0.12), rr, 8)
			WrIcons.text(self, "%d.  %s%s" % [i + 1, p.name, "" if p.alive else " (파산)"], FS_BODY,
					WrIcons.a(WrD.WHITE, 0.96 if p.alive else 0.6), Rect2(rr.position.x + 14, rr.position.y, rr.size.x - 28, rr.size.y), 0)
			WrIcons.text(self, WrD.won(g.net_worth(p)), FS_BODY, WrIcons.a(WrD.GOLD, 0.96 if p.alive else 0.55),
					Rect2(rr.position.x, rr.position.y, rr.size.x - 14, rr.size.y), 2)
			y += 46
	WrIcons.pop(self)
	for i in over_btns.size():
		over_btns[i].rect = Rect2(cx - 270 + i * 280, r.end.y + 40, 260, 84)
	for b: Dictionary in over_btns:
		_draw_button(b)


func _draw_quit() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(6, 8, 18, 170), true)
	var w := minf(560.0, vs.x - 40)
	var r := Rect2(vs.x / 2 - w / 2, vs.y * 0.36, w, 300)
	WrIcons.fill_round_grad(self, Color8(44, 52, 92), Color8(26, 32, 60), r, 20)
	WrIcons.stroke_round(self, WrD.BAD, 2.0, r, 20)
	WrIcons.text(self, "이 판을 그만둘까요?", FS_TITLE, WrD.WHITE, Rect2(r.position.x, r.position.y + 30, r.size.x, 50))
	WrIcons.text(self, "처음 화면으로 가면 지금 판은 사라집니다", FS_BODY, WrD.DIM, Rect2(r.position.x, r.position.y + 90, r.size.x, 30))
	for i in quit_btns.size():
		quit_btns[i].rect = Rect2(r.position.x + 24 + i * ((w - 60) / 2 + 12), r.end.y - 110, (w - 60) / 2, 84)
	for b: Dictionary in quit_btns:
		_draw_button(b)


func _peek_open() -> void:
	_begin()
	await delay(0.05)
	var c: WrD.Cell = g.cells[clampi(peek, 0, WrD.BOARD_SIZE - 1)]
	c.owner = 0
	c.level = 2
	_ask("건설", "호텔을 지으면 통행료가 %s 이 됩니다." % WrD.won(c.tolls[3]), c, [], g.players[0].color,
			[["호텔 건설", WrD.won(c.build_cost[2]), WrD.GOOD, true], ["건설 끝", "", WrD.PANEL_HI, false]])


## 처음 화면의 [규칙] 단추 — 음량 왼쪽(아홉 게임 같은 자리).
func _rules_rect() -> Rect2:
	return Rect2(Hub.std_rect("vol", vs).position.x - 150, Hub.std_rect("vol", vs).position.y, 136, Hub.std_rect("vol", vs).size.y)


func _open_rules() -> void:
	rules.show("runner", "월드 러너 규칙", WrRules.pages())
