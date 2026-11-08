extends Node2D
## 강호일생 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기.
##
## 계산은 전부 [GhRun] · [GhLife] 에 있고 여기는 **시간을 흘리고 보여 주기만** 한다.
## 해마다 `year_t` 가 1 을 넘으면 `run.step()` 한 번 — 갈림길 앞에서는 시간이 멈춘다.
##
## 화면: 처음(TITLE) → 태어나기(BIRTH, 출생을 하나씩 뽑아 보여 줌) → 일생(LIFE) → 묘비(END) · 지난 인생(RECORDS).
## **자리 함수(`*_rect`)를 그리기와 클릭이 같이 본다** — 키만 되고 마우스가 안 되는 화면을 만들지 않으려고.
## 가로(1280×720)는 왼쪽 인물 · 가운데 연대기 · 오른쪽 동년배 세 단, 세로(720×1280)는 위아래로 쌓는다.
##
## **화면 글자에 `·` `—` `×` `→` 와 한자를 쓰지 마세요**(Jua 에 없어 웹에서 네모).

enum Scr { TITLE, BIRTH, LIFE, END, RECORDS, BOOK }

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var run: GhRun = null
var speed_i := 1
var paused := false
var auto := false
var year_t := 0.0
var choice_t := 0.0            ## 갈림길이 뜬 뒤 흐른 시간(자동 선택)
var scroll := 0.0              ## 연대기 — 맨 아래에서 위로 올린 양(0 이면 따라간다)
var seen_at := {}              ## 연대기 줄 번호 → 처음 보인 시각(나타나는 효과)
var review := false            ## 묘비에서 "연대기 보기" — 시간을 안 흘린다
var modal := ""                ## "" · "quit" · "peer"
var peer_i := -1
var birth_t := 0.0
var end_fresh := false
var rec_scroll := 0.0
var mouse := Vector2(-999, -999)
var hover := ""
var no_save := false

# 확인용 실행
var shot_path := ""
var shot_at := 0.0
var gh_auto := false
var gh_age := -1
var gh_screen := ""
var gh_seed := -1
var click_test := false
var gh_modal := ""
var moment_t := 0.0
var book_tab := 0
var book_scroll := 0.0       ## 직업 도감 스크롤(휠)
var tip_text := ""
var tip_t := 0.0
var tour := ""                 ## --gh-tour=폴더 — 창 하나로 여러 화면을 차례로 찍는다(창을 여러 번 띄우지 않으려고)
var _tour_i := 0
var _tour_t := 0.0
var _ct := 0.0
var _cs := 0

const BIRTH_STEP := 0.75       ## 출생 항목 하나가 드러나는 간격


func _ready() -> void:
	Bgm.use("gangho")
	GhSnd.init(Hub.host(self))
	GhSv.load_()
	auto = GhSv.auto_pick
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = float(a.substr(10))
		elif a == "--gh-auto":
			gh_auto = true
		elif a.begins_with("--gh-age="):
			gh_age = int(a.substr(9))
		elif a.begins_with("--gh-screen="):
			gh_screen = a.substr(12)
		elif a.begins_with("--gh-seed="):
			gh_seed = int(a.substr(10))
		elif a.begins_with("--gh-tour="):
			tour = a.substr(10)
		elif a == "--gh-click-test":
			click_test = true
			if gh_seed < 0:
				gh_seed = 3   # 일흔둘까지 사는 씨앗 — 무작위면 아기 때 죽어 묘비로 넘어가 "멈춤" 검사가 엉뚱하게 실패했다
		elif a.begins_with("--gh-modal="):
			gh_modal = a.substr(11)
	if gh_auto or gh_age >= 0 or gh_screen != "" or click_test or tour != "":
		no_save = gh_auto or gh_age >= 0 or gh_screen != "" or tour != ""
	_prepare.call_deferred()


## 확인용 실행이 바로 원하는 화면으로 가게 한다.
func _prepare() -> void:
	vs = get_viewport_rect().size
	if gh_auto:
		_new_life()
		_start_life()
		run.me.ai_plan = true
		auto = true
		speed_i = SPEEDS_N - 1
	elif gh_age >= 0:
		_new_life()
		_start_life()
		run.me.ai_plan = true
		_fast_forward(gh_age)
		modal = gh_modal
	elif gh_screen == "birth":
		_new_life()
		birth_t = 99.0
	elif gh_screen == "end":
		_new_life()
		_start_life()
		_fast_forward(200)
	elif gh_screen == "records":
		scr = Scr.RECORDS


const SPEEDS_N := 5


func _speed() -> float:
	return float(GhD.SPEEDS[speed_i])


# ==================== 흐름 ====================


func _new_life() -> void:
	var s := gh_seed if gh_seed >= 0 else int(Time.get_ticks_usec() % 2147483647) ^ randi()
	run = GhRun.new(s)
	scr = Scr.BIRTH
	birth_t = 0.0
	review = false
	modal = ""
	seen_at.clear()
	scroll = 0.0
	GhSnd.play("birth")


func _start_life() -> void:
	_tip("start", "한 해가 저절로 흐른다. 갈림길이 오면 골라 주면 되고, 위 단추로 빠르기를 바꾼다.")
	scr = Scr.LIFE
	if click_test:
		run.me.immortal = true
	year_t = 0.0
	paused = false
	choice_t = 0.0


## 갈림길은 성향대로 고르며 그 나이까지(캡처 · 확인용).
func _fast_forward(target: int) -> void:
	var guard := 0
	while not run.done() and run.me.age < target and guard < 400:
		run.step()
		while run.waiting():
			run.me.choose(run.me.auto_index())
		guard += 1
	for i in run.me.lines.size():
		seen_at[i] = -9.0
	run.me.moments.clear()
	if run.done():
		_finish()


func _finish() -> void:
	run.finish_peers()
	end_fresh = false
	if not no_save:
		end_fresh = GhSv.add(run.me)
	scr = Scr.END
	GhSnd.play("bell")


func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	t += dt
	vs = get_viewport_rect().size
	match scr:
		Scr.BIRTH:
			birth_t += dt
		Scr.LIFE:
			_life_tick(dt)
	if click_test:
		_click_test_step(dt)
	if tour != "":
		_tour_step(dt)
	if gh_auto and scr == Scr.END and t > 1.0:
		print("GANGHO AUTO OK  %s  %d세  %s" % [run.me.name, run.me.age, run.me.title()])
		get_tree().quit(0)
	if shot_path != "" and t >= shot_at and shot_at > 0.0:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()
	queue_redraw()


func _life_tick(dt: float) -> void:
	# 전환점 삽화 — 떠 있는 동안 시간이 멈춘다. 자동이면 잠깐 보여 주고 넘긴다
	if not review and run != null and modal == "" and not run.me.moments.is_empty():
		modal = "moment"
		moment_t = 0.0
		GhSnd.play("gong", 0.8)
	tip_t = maxf(0.0, tip_t - dt)
	if modal == "moment":
		moment_t += dt
		if gh_auto or (auto and moment_t > 3.5):
			_next_moment()
		return
	if review or modal != "" or run == null:
		return
	if run.done():
		_finish()
		return
	if run.waiting():
		choice_t += dt
		var wait := GhD.CHOICE_AUTO_SEC / maxf(1.0, _speed() * 0.5)
		if gh_auto:
			wait = 0.05
		if auto and choice_t >= wait:
			_choose(run.me.auto_index())
		return
	if paused:
		return
	var sec := GhD.YEAR_SEC * (GhD.CHILD_K if run.me.age < 5 else 1.0)
	var sp := _speed() * (20.0 if gh_auto else 1.0)
	year_t += dt * sp / sec
	var guard := 0
	while year_t >= 1.0 and not run.waiting() and not run.done() and guard < 20:
		year_t -= 1.0
		_step_year()
		guard += 1


func _step_year() -> void:
	var n0 := run.me.lines.size()
	run.step()
	_on_new_lines(n0)


func _on_new_lines(n0: int) -> void:
	_tips_check()
	var lines: Array = run.me.lines
	var played := false
	for i in range(n0, lines.size()):
		seen_at[i] = t
		if played:
			continue
		match String(lines[i].kind):
			"death":
				played = true   # 묘비 화면이 종을 친다
			"realm":
				GhSnd.play("gong")
				played = true
			"big":
				GhSnd.play("pluck")
				played = true
			"choice":
				GhSnd.play("pick")
				played = true
			"world":
				if String(lines[i].txt).find("정마대전이 시작") >= 0 or String(lines[i].txt).find("난리") >= 0:
					GhSnd.play("drum")
					played = true
	if run.waiting():
		choice_t = 0.0
	if scroll > 0.0:
		pass   # 위로 올려 읽는 중이면 그 자리를 지킨다


func _choose(i: int) -> void:
	if run == null or not run.waiting():
		return
	var n0 := run.me.lines.size()
	run.me.choose(i)
	_on_new_lines(n0)
	GhSnd.play("pick", 1.3)
	choice_t = 0.0


## 다음 "일" 까지 건너뛴다 — 아무 일 없는 해(한 줄 · 세상 소식뿐)는 넘긴다. 갈림길이면 멈춘다.
func _skip() -> void:
	if run == null or run.done():
		return
	var guard := 0
	while guard < 40 and not run.waiting() and not run.done():
		var n0 := run.me.lines.size()
		_step_year()
		guard += 1
		var notable := false
		for i in range(n0, run.me.lines.size()):
			if not (String(run.me.lines[i].kind) in ["flavor", "world"]):
				notable = true
		if notable:
			break
	year_t = 0.0


# ==================== 자리 ====================
# 그리기와 클릭이 같은 함수를 본다.


func wide() -> bool:
	return vs.x > vs.y


func _top_h() -> float:
	return 60.0 if wide() else 108.0


func _exit_rect() -> Rect2:
	return Rect2(12, 10, 96, 40)


## 위 막대 오른쪽 단추들 — 0 멈춤 · 1..5 배속 · 6 자동 · 7 건너뛰기
func _ctrl_rect(i: int) -> Rect2:
	var w := [76.0, 52.0, 52.0, 52.0, 52.0, 52.0, 104.0, 104.0]
	var gap := 6.0
	var total := 0.0
	for x in w:
		total += x + gap
	var x0 := vs.x - 12.0 - total + gap
	var y := 10.0
	for k in i:
		x0 += w[k] + gap
	return Rect2(x0, y, w[i], 40)


func _info_rect() -> Rect2:
	var top := _top_h() + 8.0
	if wide():
		return Rect2(12, top, 334, vs.y - top - 12)
	return Rect2(12, top, vs.x - 24, 300)


func _log_rect() -> Rect2:
	var top := _top_h() + 8.0
	if wide():
		return Rect2(356, top, vs.x - 356 - 344, vs.y - top - 12)
	var y := _info_rect().end.y + 10.0
	return Rect2(12, y, vs.x - 24, vs.y - y - 290)


func _peers_rect() -> Rect2:
	var top := _top_h() + 8.0
	if wide():
		return Rect2(vs.x - 334, top, 322, vs.y - top - 12)
	return Rect2(12, vs.y - 280, vs.x - 24, 268)


func _peer_card(i: int) -> Rect2:
	var r := _peers_rect()
	var head := 38.0
	var gap := 8.0
	if wide():
		var h := (r.size.y - head - gap * 4) / 4.0
		return Rect2(r.position.x + 8, r.position.y + head + i * (h + gap), r.size.x - 16, h)
	var w := (r.size.x - 16 - gap) / 2.0
	var h2 := (r.size.y - head - gap * 2 - 8) / 2.0
	return Rect2(r.position.x + 8 + (i % 2) * (w + gap), r.position.y + head + (i / 2) * (h2 + gap), w, h2)


func _pic_rect() -> Rect2:
	var r := _info_rect()
	if wide():
		return Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 176))
	return Rect2(r.position + Vector2(8, 8), Vector2(250, r.size.y - 16))


func _choice_box() -> Rect2:
	var lr := _log_rect()
	var w := minf(lr.size.x - 24, 640.0)
	var lines := GhArt.wrap(String(run.me.pending.title), w - 40, 24).size() if run and run.waiting() else 1
	var n: int = run.me.pending.opts.size() if run and run.waiting() else 2
	var h := 70.0 + lines * 32.0 + n * 58.0 + (14.0 if auto else 0.0)
	return Rect2(lr.position.x + (lr.size.x - w) * 0.5, lr.end.y - h - 12, w, h)


func _opt_rect(i: int) -> Rect2:
	var b := _choice_box()
	var n: int = run.me.pending.opts.size()
	var y := b.end.y - 14 - (n - i) * 58.0 - (14.0 if auto else 0.0)
	return Rect2(b.position.x + 20, y, b.size.x - 40, 48)


## 처음 화면 단추 — 0 태어나기(시작) · 3 게임 선택 · 4 음량은 다섯 게임 같은 자리(`Hub.std_rect` — 오른쪽 아래 · 왼쪽 위 · 오른쪽 위),
## 1 지난 인생 · 2 도감은 가운데 세로 줄.
func _title_btn(i: int) -> Rect2:
	match i:
		0:
			return Hub.std_rect("start", vs)
		3:
			return Hub.std_rect("hub", vs)
		4:
			return Hub.std_rect("vol", vs)
	# 오른쪽 메뉴 줄(다섯 게임 같은 구조 — 모드 · 도감 · 도감 · 순위): 1 지난 인생 · 2 인생 도감 · 5 칭호 도감 · 6 순위(명예의 전당)
	return UiKit.menu_rect(vs, {1: 0, 2: 1, 5: 2, 6: 3}.get(i, 0))


func _birth_go() -> Rect2:
	return Rect2(vs.x * 0.5 - 160, vs.y - 92, 320, 64)


func _end_btn(i: int) -> Rect2:
	var labels := 3
	var w := 230.0 if wide() else 210.0
	var gap := 16.0
	var x0 := vs.x * 0.5 - (w * labels + gap * (labels - 1)) * 0.5
	return Rect2(x0 + i * (w + gap), vs.y - 80, w, 58)


func _modal_rect() -> Rect2:
	if modal == "quit":
		return Rect2(vs.x * 0.5 - 260, vs.y * 0.5 - 110, 520, 220)
	var big := modal in ["plan", "rels"]
	var w := minf(1060.0 if big else 760.0, vs.x - 40)
	var h := minf(660.0 if big and wide() else (1200.0 if big else 600.0), vs.y - 40)
	return Rect2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - h * 0.5, w, h)


func _modal_btn(i: int) -> Rect2:
	var m := _modal_rect()
	if modal == "quit":
		return Rect2(m.position.x + 30 + i * 240, m.end.y - 76, 220, 56)
	return Rect2(m.get_center().x - 110, m.end.y - 70, 220, 54)


## 인물 판 아래 단추 — 0 할 일 · 물건, 1 인연
## 인물 판 아래 단추 — 방침 하나. 인연 단추는 오른쪽 판이 인연을 보여 주게 되면서 뺐다(사용자 요청 11-07).
func _info_btn(_i: int) -> Rect2:
	var r := _info_rect()
	if wide():
		return Rect2(r.position.x + 10, r.end.y - 52, r.size.x - 20, 42)
	var x0 := _pic_rect().end.x + 12
	return Rect2(x0, r.end.y - 50, r.end.x - x0 - 12, 40)


## 방침 창 — 탭 일곱(아래 PLAN_TABS). 자리 함수를 그리기와 클릭이 같이 본다.
var plan_tab := 0
const PLAN_TABS := ["방침", "지금 하기", "배움", "직업", "재산", "탈것", "물건"]
const JOB_LIST := ["", "laborer", "waiter", "cook", "boatman", "musician", "storyteller", "gisaeng", "teacher", "munsa",
		"strategist", "interpreter", "factor", "innkeeper", "gibang", "doctor", "herbalist", "alchemist", "smith", "mechanist",
		"painter", "diviner", "taoist", "monk", "gambler", "informant", "graverobber", "constable", "pokwae", "geumui",
		"dongchang", "officer", "escortman", "bodyguard", "patrol", "bounty", "ronin", "instructor", "poisoner", "pirate", "assassin"]
const PLAN_Y := 108.0
const PLAN_STEP := 54.0


func _plan_tab(i: int) -> Rect2:
	var m := _modal_rect()
	var n := float(PLAN_TABS.size())
	var w := minf(200.0, (m.size.x - 40 - 10 * (n - 1.0) - (220.0 if wide() else 0.0)) / n)
	return Rect2(m.position.x + 20 + i * (w + 10), m.position.y + 14, w, 44)


func _plan_col(col: int, i: int, cols: int, step: float = PLAN_STEP) -> Rect2:
	var m := _modal_rect()
	var cw := (m.size.x - 40 - (cols - 1) * 20) / cols
	return Rect2(m.position.x + 20 + col * (cw + 20), m.position.y + PLAN_Y + i * step, cw, step - 6.0)


## 줄 수에 맞춘 줄 간격 — 닫기 단추 위까지 들어가게 줄인다(40~54). "지금 하기" 는 스물두 줄이라
## 54 로 깔면 마지막 줄이 닫기 단추에 가리고 기운 글이 창 밖으로 나갔다(사용자 지적 11-07).
func _fit_step(rows: int) -> float:
	var room := _modal_btn(0).position.y - 8.0 - (_modal_rect().position.y + PLAN_Y)
	return clampf(floorf(room / maxf(1.0, float(rows))), 40.0, PLAN_STEP)


## 보이는 줄 수
func _vcount(kind: String, n: int) -> int:
	var c := 0
	for i in n:
		if _visible(kind, i):
			c += 1
	return c


## 두 단으로 깔 때 — 보이는 줄을 반씩 나누고 간격을 맞춘다
func _plan_split(kind: String, i: int, n: int) -> Rect2:
	var k := _vpos(kind, i)
	if k < 0:
		return Rect2()
	if not wide():
		return _plan_col(0, k, 1)
	var half := (_vcount(kind, n) + 1) / 2
	return _plan_col(k / half, k % half, 2, _fit_step(half))


## **정식판은 지금 할 수 있는 것만 보인다**(사용자 결정 11-07). 이미 켠 것 · 가진 것 · 배운 것 · 지금 하는 일은
## 상태 표시로 남긴다. 테스트 빌드는 전부 보이고 못 하는 줄은 흐리게 · 이유와 함께 — 조건을 손볼 때 보려고.
## 자리 함수가 "보이는 줄 중 몇 번째" 로 자리를 잡고, 안 보이는 줄은 빈 사각형(눌리지도 그려지지도 않음)을 돌려준다.
var show_all := OS.has_feature("testbuild")


func _visible(kind: String, i: int) -> bool:
	if show_all:
		return true
	var me := run.me
	match kind:
		"focus":
			return me.focus == GhD.FOCUS[i].id or me.focus_ok(GhD.FOCUS[i].id)
		"habit":
			var id: String = GhD.HABITS[i].id
			return me.habits.has(id) or me.habit_ok(id)
		"act":
			return me.act_block(GhD.ACTIONS[i].id) == ""
		"course":
			var id2: String = GhD.COURSES[i].id
			return me.course == id2 or me.quals.has(id2) or me.course_block(id2) == ""
		"job":
			return me.job == JOB_LIST[i] or me.job_block(JOB_LIST[i]) == ""
		"house":
			return me.houses.has(GhD.HOUSES[i].id) or me.house_block(GhD.HOUSES[i].id) == ""
		"inv":
			return me.holdings.has(GhD.INVEST[i].id) or (me.age >= 16 and me.gold >= 100)
		"item":
			return me.items.has(GhD.ITEMS[i].id) or me.can_buy(GhD.ITEMS[i].id)
		"ride":
			return me.rides.has(GhD.RIDES[i].id) or me.ride_block(GhD.RIDES[i].id) == ""
	return true


## i 번 줄이 보이는 줄 가운데 몇 번째인가(안 보이면 -1)
func _vpos(kind: String, i: int) -> int:
	if not _visible(kind, i):
		return -1
	var k := 0
	for j in i:
		if _visible(kind, j):
			k += 1
	return k


func _plan_focus(i: int) -> Rect2:
	var k := _vpos("focus", i)
	return Rect2() if k < 0 else _plan_col(0, k, 2 if wide() else 1)


func _plan_habit(i: int) -> Rect2:
	var k := _vpos("habit", i)
	if k < 0:
		return Rect2()
	if wide():
		return _plan_col(1, k, 2)
	var r := _plan_col(0, k, 1)
	r.position.y += GhD.FOCUS.size() * PLAN_STEP + 44
	return r


## 매년 하는 일 머리글 자리(보이는 줄이 없어도 머리글은 같은 자리)
func _habit_head() -> Vector2:
	var r := _plan_col(1, 0, 2) if wide() else _plan_col(0, 0, 1)
	if not wide():
		r.position.y += GhD.FOCUS.size() * PLAN_STEP + 44
	return Vector2(r.position.x, r.position.y - 32)


func _plan_act(i: int) -> Rect2:
	return _plan_split("act", i, GhD.ACTIONS.size())


## 배움 탭 — **갈래마다 지금 할 단계 하나만** 보인다(GhD.TRACKS · 사용자 요청 11-07: "1단계를 클리어하면 다음 단계가 보이고
## 1단계는 안 보이게"). 다 마친 갈래는 "다 배웠다" 한 줄로 남는다. 단계 수는 갈래마다 달라도 되지만 **총 배움 해수는
## 비슷하게**(지금 모두 12해 — 학업 3+3+3+3, 나머지 3+4+5) 맞춘다 — 갈래마다 단계 수가 다르면 "불공평하다" 는 말을 들었다.
## 갈래 카드는 정식판에서도 다 보인다(못 하는 단계면 흐리게 · 이유와 함께) — 어떤 길이 있는지가 보여야 고를 수 있다.


## 갈래 t 의 지금 단계 — 배우는 중이면 그것, 아니면 아직 안 마친 첫 단계. 다 마쳤으면 -1.
## 학업은 과거로 급(수재 · 거인 · 진사)을 먼저 땄으면 그 단계를 지난 것으로 센다.
func _track_stage(t: int) -> int:
	var me := run.me
	var ids: Array = GhD.TRACKS[t].ids
	for s in ids.size():
		if me.course == String(ids[s]):
			return s
	for s in ids.size():
		var done: bool = me.quals.has(String(ids[s]))
		if String(GhD.TRACKS[t].name) == "학업" and s >= 1 and me.degree >= s:
			done = true
		if not done:
			return s
	return -1


func _track_of(id: String) -> Vector2i:
	for t in GhD.TRACKS.size():
		var s: int = (GhD.TRACKS[t].ids as Array).find(id)
		if s >= 0:
			return Vector2i(t, s)
	return Vector2i(-1, -1)


## 갈래 카드 자리 — 가로면 두 단(앞 절반 · 뒤 절반), 세로면 한 단
func _track_rect(t: int) -> Rect2:
	var n := GhD.TRACKS.size()
	if wide():
		var half := (n + 1) / 2
		return _plan_col(t / half, t % half, 2)
	return _plan_col(0, t, 1, _fit_step(n))


## 배움 i 의 자리 — 그 갈래의 지금 단계일 때만 카드 자리, 아니면 빈 사각형(안 그리고 안 눌린다)
func _plan_course(i: int) -> Rect2:
	var ts := _track_of(String(GhD.COURSES[i].id))
	if ts.x < 0 or _track_stage(ts.x) != ts.y:
		return Rect2()
	return _track_rect(ts.x)


func _plan_job(i: int) -> Rect2:
	# 직업이 스물여섯이라 가로는 세 줄 · 세로는 두 줄로 깐다. 한 칸 높이를 줄여 창 안에 다 들게
	var k := _vpos("job", i)
	if k < 0:
		return Rect2()
	var cols := 4 if wide() else 2
	var rows := ceili(JOB_LIST.size() / float(cols))
	var step := minf(44.0, _fit_step(rows))
	var r := _plan_col(k / rows, k % rows, cols)
	r.position.y = _modal_rect().position.y + PLAN_Y + (k % rows) * step
	r.size.y = step - 4.0
	return r


func _plan_house(i: int) -> Rect2:
	var k := _vpos("house", i)
	return Rect2() if k < 0 else _plan_col(0, k, 2 if wide() else 1)


## 투자 — 가로면 오른쪽 단(집과 나란히), 세로면 집 아래. 한 단에 쌓으면 오른쪽 절반이 통째로 비었다
func _plan_inv(i: int) -> Rect2:
	var k := _vpos("inv", i)
	if k < 0:
		return Rect2()
	if wide():
		return _plan_col(1, k, 2)
	var r := _plan_col(0, k + GhD.HOUSES.size(), 1)
	r.position.y += 40
	return r


## 투자 머리글 자리
func _inv_head() -> Vector2:
	if wide():
		var r0 := _plan_col(1, 0, 2)
		return Vector2(r0.position.x, r0.position.y - 32)
	var r := _plan_col(0, GhD.HOUSES.size(), 1)
	return Vector2(r.position.x, r.position.y + 40 - 32)




## 줄 안의 작은 단추(팔기 · 접기)
func _sub_btn(r: Rect2) -> Rect2:
	return Rect2(r.end.x - 74, r.position.y + 7, 64, 34)


func _plan_item(i: int) -> Rect2:
	return _plan_two("item", i, GhD.ITEMS.size())


## 탈것 줄의 설명 — 배수 다음에 벌이 · 명성 · 가족을 붙인다(값에서 만들어 손으로 적은 글과 어긋나지 않게)
func _ride_desc(rd: Dictionary) -> String:
	var s := GhD.effect_text(rd.mul)
	if rd.has("inc"):
		s += ", 벌이 %d냥 안팎" % int(rd.inc)
	if rd.has("fame"):
		s += ", 명성 +%d" % int(rd.fame)
	if rd.has("fam"):
		s += ", 가족의 정 %+d" % int(rd.fam)
	return s + ". " + String(rd.desc)


func _plan_ride(i: int) -> Rect2:
	return _plan_two("ride", i, GhD.RIDES.size())


## 가로면 두 단(앞 절반 · 뒤 절반), 세로면 한 단
func _plan_two(kind: String, i: int, n: int) -> Rect2:
	return _plan_split(kind, i, n)

func _rec_back() -> Rect2:
	return Rect2(12, 10, 96, 40)


# ==================== 입력 ====================


func _unhandled_input(e: InputEvent) -> void:
	if Vol.open:
		Vol.handle(e, vs)   # 처음 화면 오른쪽 위 "음량" 창
		return
	if e is InputEventMouseMotion:
		mouse = e.position
		return
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel(-1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel(1.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			mouse = mb.position
			_click(mb.position)
		return
	var k := e as InputEventKey
	if k != null and k.pressed and not k.echo:
		_key(k.keycode)


func _wheel(d: float) -> void:
	if scr == Scr.LIFE and modal == "":
		scroll = maxf(0.0, scroll - d * 60.0)
	elif scr == Scr.BOOK and book_tab == 3:
		book_scroll = maxf(0.0, book_scroll + d * 60.0)
	elif scr == Scr.RECORDS:
		rec_scroll = maxf(0.0, rec_scroll + d * 60.0)


func _click(p: Vector2) -> void:
	match scr:
		Scr.TITLE:
			if _title_btn(0).has_point(p):
				_new_life()
			elif _title_btn(1).has_point(p):
				scr = Scr.RECORDS
				rec_scroll = 0.0
			elif _title_btn(2).has_point(p):
				scr = Scr.BOOK
				book_tab = 0
			elif _title_btn(3).has_point(p):
				Hub.leave(self)
			elif _title_btn(4).has_point(p):
				Vol.open = true
			elif _title_btn(5).has_point(p):
				scr = Scr.BOOK
				book_tab = 1   # 칭호
			elif _title_btn(6).has_point(p):
				scr = Scr.BOOK
				book_tab = 2   # 명예의 전당
		Scr.BIRTH:
			if _birth_all() and _birth_go().has_point(p):
				_start_life()
			elif _exit_rect().has_point(p):
				scr = Scr.TITLE
			else:
				birth_t = 99.0   # 아무 데나 누르면 다 드러낸다
		Scr.LIFE:
			_click_life(p)
		Scr.END:
			if _end_btn(0).has_point(p):
				_new_life()
			elif _end_btn(1).has_point(p):
				review = true
				scr = Scr.LIFE
				scroll = 0.0
			elif _end_btn(2).has_point(p):
				scr = Scr.TITLE
		Scr.RECORDS:
			if _rec_back().has_point(p):
				scr = Scr.TITLE
		Scr.BOOK:
			if _rec_back().has_point(p):
				scr = Scr.TITLE
			for i in BOOK_TABS.size():
				if _book_tab(i).has_point(p):
					book_tab = i


func _click_life(p: Vector2) -> void:
	if tip_t > 0.0 and _tip_rect().has_point(p):
		tip_t = 0.0
		return
	if modal == "moment":
		if moment_t > 0.4:
			_next_moment()
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.TITLE
			run = null
		elif _modal_btn(1).has_point(p) or not _modal_rect().has_point(p):
			modal = ""
		return
	if modal == "peer" or modal == "rels":
		if _modal_btn(0).has_point(p) or not _modal_rect().has_point(p):
			modal = ""
		return
	if modal == "plan":
		if _modal_btn(0).has_point(p) or not _modal_rect().has_point(p):
			modal = ""
			return
		for i in PLAN_TABS.size():
			if _plan_tab(i).has_point(p):
				plan_tab = i
				return
		var me := run.me
		var n0 := me.lines.size()
		match plan_tab:
			0:
				for i in GhD.FOCUS.size():
					if _plan_focus(i).has_point(p) and me.focus_ok(GhD.FOCUS[i].id):
						me.set_focus(GhD.FOCUS[i].id)
						GhSnd.play("pick")
				for i in GhD.HABITS.size():
					var id: String = GhD.HABITS[i].id
					if _plan_habit(i).has_point(p) and (me.habits.has(id) or me.habit_ok(id)):
						me.toggle_habit(id)
						GhSnd.play("pick", 1.15)
			1:
				for i in GhD.ACTIONS.size():
					var id: String = GhD.ACTIONS[i].id
					if _plan_act(i).has_point(p) and me.act_block(id) == "":
						me.act(id)
						GhSnd.play("pluck", 1.1)
			2:
				for i in GhD.COURSES.size():
					var id: String = GhD.COURSES[i].id
					if _plan_course(i).has_point(p) and me.course_block(id) == "":
						me.start_course(id)
						GhSnd.play("pick", 1.1)
			3:
				for i in JOB_LIST.size():
					if _plan_job(i).has_point(p) and me.job_block(JOB_LIST[i]) == "":
						me.set_job(JOB_LIST[i])
						GhSnd.play("pick", 1.1)
			4:
				for i in GhD.HOUSES.size():
					if _plan_house(i).has_point(p):
						me.house_click(GhD.HOUSES[i].id)
				for i in GhD.INVEST.size():
					var r := _plan_inv(i)
					var id: String = GhD.INVEST[i].id
					if _sub_btn(r).has_point(p):
						me.divest(id)
					elif r.has_point(p):
						me.invest(id, 100)
			5:
				for i in GhD.RIDES.size():
					var id: String = GhD.RIDES[i].id
					if _plan_ride(i).has_point(p) and (me.rides.has(id) or me.ride_block(id) == ""):
						me.ride_click(id)
						GhSnd.play("pluck", 1.1)
			6:
				for i in GhD.ITEMS.size():
					var id: String = GhD.ITEMS[i].id
					if _plan_item(i).has_point(p) and (me.items.has(id) or me.can_buy(id)):
						me.item_click(id)
						GhSnd.play("pluck", 1.2)
		_on_new_lines(n0)
		if run.done():
			modal = ""
		return
	if not review and run.me.alive:
		if _info_btn(0).has_point(p):
			modal = "plan"
			return
	if _exit_rect().has_point(p):
		if review:
			review = false
			scr = Scr.END
		else:
			modal = "quit"
		return
	if not review:
		for i in 8:
			if _ctrl_rect(i).has_point(p):
				_ctrl(i)
				return
		if run.waiting():
			for i in run.me.pending.opts.size():
				if _opt_rect(i).has_point(p):
					_choose(i)
					return
	for t in 2:
		if _side_tab(t).has_point(p):
			side_mode = t
			return
	if side_mode == 1:
		for i in run.peers.size():
			if _peer_card(i).has_point(p):
				peer_i = i
				modal = "peer"
				return
		return
	# 인연 — 같은 해 태어난 사람이면 그 사람의 삶을, 아니면 인연 창을 연다
	var rows := _rel_rows()
	for k in rows.size():
		if _rel_card(k).has_point(p):
			var pi := _peer_index(String(run.me.rels[rows[k]].name))
			if pi >= 0:
				peer_i = pi
				modal = "peer"
			else:
				modal = "rels"
			return
	if _rel_more().has_point(p):
		modal = "rels"


## 자동 선택 켜고 끄기 — 다음 판에도 남는다. 검사 · 캡처 실행은 저장하지 않는다(사람의 설정을 덮지 않게).
func _toggle_auto() -> void:
	auto = not auto
	choice_t = 0.0
	if not (click_test or gh_auto or tour != ""):
		GhSv.auto_pick = auto
		GhSv.save_()


func _ctrl(i: int) -> void:
	match i:
		0:
			paused = not paused
		6:
			_toggle_auto()
		7:
			_skip()
		_:
			speed_i = i - 1
			paused = false


func _key(k: Key) -> void:
	match scr:
		Scr.TITLE:
			match k:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_new_life()
				KEY_R:
					scr = Scr.RECORDS
				KEY_B:
					scr = Scr.BOOK
				KEY_ESCAPE:
					Hub.leave(self)
		Scr.BIRTH:
			match k:
				KEY_ESCAPE:
					scr = Scr.TITLE
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					if _birth_all():
						_start_life()
					else:
						birth_t = 99.0
		Scr.LIFE:
			if modal != "":
				if modal == "moment":
					if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
						_next_moment()
					return
				if k == KEY_ESCAPE:
					modal = ""
				elif modal == "quit" and (k == KEY_ENTER or k == KEY_KP_ENTER):
					modal = ""
					scr = Scr.TITLE
					run = null
				return
			match k:
				KEY_ESCAPE:
					if review:
						review = false
						scr = Scr.END
					else:
						modal = "quit"
				KEY_SPACE:
					paused = not paused
				KEY_LEFT:
					speed_i = maxi(0, speed_i - 1)
				KEY_RIGHT:
					speed_i = mini(SPEEDS_N - 1, speed_i + 1)
				KEY_A:
					_toggle_auto()
				KEY_N:
					_skip()
				KEY_P:
					if not review:
						modal = "plan"
				KEY_R:
					modal = "rels"
				KEY_1, KEY_2, KEY_3:
					if run.waiting() and k - KEY_1 < run.me.pending.opts.size():
						_choose(k - KEY_1)
		Scr.END:
			match k:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_new_life()
				KEY_ESCAPE:
					scr = Scr.TITLE
		Scr.RECORDS:
			if k == KEY_ESCAPE:
				scr = Scr.TITLE
		Scr.BOOK:
			if k == KEY_ESCAPE:
				scr = Scr.TITLE
			elif k == KEY_TAB:
				book_tab = (book_tab + 1) % BOOK_TABS.size()


# ==================== 그리기 ====================


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), GhD.BG, true)
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.BIRTH:
			_draw_birth()
		Scr.LIFE:
			_draw_life()
		Scr.END:
			_draw_end()
		Scr.RECORDS:
			_draw_records()
		Scr.BOOK:
			_draw_book()
	Vol.draw(self, vs, t)


## 단추 — 다섯 게임 같은 입체 단추(UiKit, 강호일생 한지 · 붉은 낙관 색). 켜진 것(on)은 붉은 낙관.
func _btn(r: Rect2, label: String, on: bool = false, size: float = 24.0, enabled: bool = true) -> void:
	UiKit.plain(self, r, label, GhD.RED if on else GhD.PAPER_D, "gangho", t, enabled, size)


func _bg_art(key: String, dim: float) -> void:
	var r := Rect2(Vector2.ZERO, vs)
	GhArt.picture(self, r, key, t, 7)
	draw_rect(r, Color(0, 0, 0, dim), true)


# ---------- 처음 ----------

func _draw_title() -> void:
	_bg_art("gh_title", 0.35)
	# 왼쪽 제목(다섯 게임 같은 틀)
	# 게임 이름 — 다섯 게임 같은 방식(UiKit.title). 소개 둘째 줄만 이 게임 것
	var cx := vs.x * (0.3 if wide() else 0.5)
	var below := UiKit.title(self, vs, "gangho", "강호일생", "누구로 태어날지는 고를 수 없다", t)
	GhArt.text_mid(self, Vector2(cx, below + 22), "천하 1억 2천만 명 가운데, 한 번뿐인 일생", 20.0, Color(1, 1, 1, 0.75), 5.0)
	UiKit.button(self, vs, "start", "gangho", t, "태어나기")
	# 오른쪽 메뉴 — 다섯 게임 같은 구조(모드 · 도감 · 도감 · 순위)
	var menus := [[1, "지난 인생 %d" % GhSv.lives.size(), Color8(120, 96, 70)], [2, "인생 도감", Color8(70, 110, 100)],
			[5, "칭호 도감", Color8(150, 110, 50)], [6, "순위", Color8(150, 50, 46)]]
	for m in menus:
		UiKit.menu(self, _title_btn(int(m[0])), String(m[1]), m[2], "gangho", t)
	UiKit.button(self, vs, "hub", "gangho", t)
	UiKit.button(self, vs, "vol", "gangho", t)
	if GhSv.births > 0:
		# 가로 화면은 왼쪽으로 비켜 쓴다(오른쪽 아래는 태어나기 단추)
		GhArt.text_mid(self, Vector2(vs.x * (0.3 if wide() else 0.5), vs.y - 40), "지금까지 %d번 태어났다.  모은 칭호 %d종" % [GhSv.births, GhSv.titles.size()],
				20.0, Color(1, 1, 1, 0.75), 4.0)


# ---------- 태어나기 ----------

func _birth_items() -> Array:
	var me := run.me
	var out := [
		["시대", "천하력 %d년" % me.birth_year, _era_note(me)],
		["땅", me.region_name(), "천하 사람의 %s" % _pct(me.p_reg)],
		["집안", me.house_name() if me.cls == "clan" else me.cls_name(), "이 땅 사람의 %s" % _pct(me.p_cls)],
		["가세", String(GhD.WEALTH[me.wealth].name).trim_suffix("의").trim_suffix("한") + ("" if me.wealth != 1 else "보통"), _wealth_note(me)],
		["차례", me.child_label(), _order_note(me)],
		["이름", me.name, ""],
		["타고난 것", "근골 %d  오성 %d  매력 %d  손재주 %d  수완 %d" % [me.gol, me.wis, me.cha, me.dex, me.wit], "small:"],
	]
	if me.cons != "":
		out.append(["체질", me.cons, "백 명 중 한 명도 안 되는 타고남"])
	out.append(["어울리는 길", ", ".join(me.suited_jobs(3).map(func(j): return String(GhD.JOBS[j].name))), "small:"])
	return out


func _pct(v: float) -> String:
	if v >= 0.1:
		return "%d%%" % roundi(v * 100.0)
	if v >= 0.01:
		return "%.1f%%" % (v * 100.0)
	return "%.2f%%" % (v * 100.0)


func _birth_all() -> bool:
	return birth_t >= BIRTH_STEP * (_birth_items().size() + 1)


func _draw_birth() -> void:
	_bg_art(GhArt.birth_scene(run.me.cls), 0.55)
	_btn(_exit_rect(), "처음", false, 22.0)
	var items := _birth_items()
	var w := minf(620.0, vs.x - 40)
	var row := 46.0 if wide() else 62.0
	var top := 70.0 if wide() else 150.0
	var box := Rect2(vs.x * 0.5 - w * 0.5, top, w, row * items.size() + 40)
	GhArt.paper(self, box, Color(GhD.PAPER, 0.94))
	for i in items.size():
		var it: Array = items[i]
		var y := box.position.y + 20 + i * row
		var k := clampf((birth_t - BIRTH_STEP * (i + 0.4)) / 0.35, 0.0, 1.0)
		GhArt.text(self, Vector2(box.position.x + 28, y + 8), String(it[0]), 22.0, GhD.DIM)
		if birth_t < BIRTH_STEP * (i + 0.4) and birth_t > BIRTH_STEP * i:
			# 굴러가는 중 — 아무 값이나 빠르게 바뀐다
			var fake := _fake_value(i)
			GhArt.text(self, Vector2(box.position.x + 120, y + 4), fake, 28.0, Color(GhD.INK, 0.35))
			continue
		if k <= 0.0:
			continue
		var col := Color(GhD.INK, k)
		if String(it[2]).begins_with("small"):
			GhArt.text(self, Vector2(box.position.x + 150, y + 8), String(it[1]), 21.0, col)
			var sn := String(it[2]).substr(6)
			if sn != "" and 150 + GhArt.text_w(String(it[1]), 21.0) + GhArt.text_w(sn, 18.0) + 40 < box.size.x:
				GhArt.text(self, Vector2(box.end.x - 28 - GhArt.text_w(sn, 18.0), y + 10), sn, 18.0, Color(GhD.RED, k))
			continue
		if String(it[2]) == "bar":
			var v := int(it[1])
			GhArt.bar(self, Rect2(box.position.x + 120, y + 14, w - 270, 18), v / 100.0, Color(GhD.RED, k))
			var vt := "%d / 100" % v
			GhArt.text(self, Vector2(box.end.x - 28 - GhArt.text_w(vt, 24.0), y + 4), vt, 24.0, col)
		else:
			GhArt.text(self, Vector2(box.position.x + 120, y + 2), String(it[1]), 30.0, col)
			if String(it[2]) != "":
				var nw := GhArt.text_w(String(it[2]), 20.0)
				GhArt.text(self, Vector2(box.end.x - 28 - nw, y + 10), String(it[2]), 20.0, Color(GhD.DIM, k))
	if _birth_all():
		var y2 := box.end.y + 18
		var many := roundi(GhD.POPULATION * run.me.birth_p)
		var line := "이렇게 태어나는 사람은 %s명 중 한 명꼴, 천하에 약 %s명이다." % [_num(run.me.one_in()), _man(many)]
		GhArt.text_mid(self, Vector2(vs.x * 0.5, y2 + 14), line, 24.0, GhD.PAPER, 5.0)
		var peers := "같은 해 태어난 이들:  "
		var names: Array = []
		for p: GhLife in run.peers:
			names.append("%s(%s %s)" % [p.name, p.region_name(), p.cls_name()])
		var pl := GhArt.wrap(peers + ", ".join(names), vs.x - 80, 20.0)
		for i in pl.size():
			GhArt.text_mid(self, Vector2(vs.x * 0.5, y2 + 54 + i * 28), pl[i], 20.0, Color(1, 1, 1, 0.85), 4.0)
		_btn(_birth_go(), "삶을 시작한다", false, 28.0)
	else:
		GhArt.text_mid(self, Vector2(vs.x * 0.5, vs.y - 50), "누르면 한꺼번에 드러난다", 20.0, Color(1, 1, 1, 0.6), 4.0)


func _fake_value(i: int) -> String:
	var k := int(t * 18.0)
	match i:
		0:
			return "천하력 %d년" % (GhD.YEAR_MIN + (k * 37) % (GhD.YEAR_MAX - GhD.YEAR_MIN))
		1:
			return String(GhD.REGIONS[k % GhD.REGIONS.size()].name)
		2:
			return String(GhD.CLASSES[k % GhD.CLASSES.size()].name)
		3:
			return "아들" if k % 2 == 0 else "딸"
		4:
			return String(GhD.SURNAMES[k % GhD.SURNAMES.size()]) + String(GhD.NAME_M[(k * 7) % GhD.NAME_M.size()])
	return "%d" % (k % 10 + 1)


## 큰 수를 "만" 단위로 — 2600000 → "260만"
func _man(v: int) -> String:
	if v >= 100000000:
		return "%.1f억" % (v / 100000000.0)
	if v >= 10000:
		return "%s만" % _num(roundi(v / 10000.0))
	return _num(v)


func _num(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


# ---------- 일생 ----------

func _draw_life() -> void:
	if run == null:
		return
	if GhArt.img("gh_board") != null:
		_bg_art("gh_board", 0.62)
	var me := run.me
	# 위 막대
	draw_rect(Rect2(0, 0, vs.x, _top_h()), Color(0, 0, 0, 0.35), true)
	_btn(_exit_rect(), "묘비로" if review else "나가기", false, 22.0)
	var ytxt := "천하력 %d년   %d세" % [run.year(), me.age]
	if wide():
		GhArt.text_mid(self, Vector2((_exit_rect().end.x + _ctrl_rect(0).position.x) * 0.5, 30), ytxt, 28.0, GhD.PAPER, 5.0)
	else:
		GhArt.text_mid(self, Vector2(vs.x * 0.5, 82), ytxt, 28.0, GhD.PAPER, 5.0)
	if not review:
		_btn(_ctrl_rect(0), "계속" if paused else "멈춤", paused, 20.0)
		for i in SPEEDS_N:
			var sp: float = GhD.SPEEDS[i]
			_btn(_ctrl_rect(i + 1), ("x%.1f" % sp) if sp < 1.0 else ("x%d" % int(sp)), i == speed_i and not paused, 19.0)
		_btn(_ctrl_rect(6), "자동 선택", auto, 20.0)
		_btn(_ctrl_rect(7), "건너뛰기", false, 20.0)
	_draw_info()
	_draw_log()
	_draw_side()
	if run.waiting() and not review:
		_draw_choice()
	if tip_t > 0.0 and modal == "":
		_draw_tip()
	if modal == "quit":
		_draw_quit()
	elif modal == "peer":
		_draw_peer_modal()
	elif modal == "moment":
		_draw_moment()
	elif modal == "plan":
		_draw_plan()
	elif modal == "rels":
		_draw_rels()


func _draw_info() -> void:
	var me := run.me
	var r := _info_rect()
	GhArt.paper(self, r)
	var war := run.world.has(run.year(), "war") or run.world.has(run.year(), "war_start")
	GhArt.picture(self, _pic_rect(), GhArt.scene_of(me, war), t, me.rng.seed % 1000)
	var x := r.position.x + 16
	var y := _pic_rect().end.y + 10
	var w := r.size.x - 32
	if not wide():
		x = _pic_rect().end.x + 16
		y = r.position.y + 10
		w = r.end.x - x - 14
	if me.alias != "":
		GhArt.text(self, Vector2(x, y - 4), me.alias, 17.0, GhD.RED)
		y += 14
	GhArt.text(self, Vector2(x, y), me.name, 32.0, GhD.INK)
	var sub := "%s %s의 %s" % [me.region_name(), me.house_name(), me.child_label()]
	if me.work_key() != "" and (not me.martial or me.job != "" or me.flags.has("quit")):
		sub = "%s %s, %s" % [me.region_name(), me.cls_name(), me.work_title()]
	elif me.job_name() != "":
		sub += ", " + me.job_name()
	if me.course != "":
		sub += ", " + String(GhD.course(me.course).name) + " 중"
	GhArt.text(self, Vector2(x, y + 40), sub, 18.0, GhD.DIM)
	y += 68
	var realm := me.realm_name() if me.martial else "무공 없음"
	if me.martial and me.sect_name() != "" and not me.flags.has("quit"):
		realm += "   " + me.sect_name()
	elif me.martial and me.side == "독학":
		realm += "   홀로 익힘"
	GhArt.text(self, Vector2(x, y), realm, 22.0, GhD.RED if me.realm >= 3 else GhD.INK)
	y += 30
	if not me.arts_known.is_empty():
		var al := GhArt.wrap("무공  " + ", ".join(me.arts_known), w, 16.0)
		for i in mini(al.size(), 2):
			GhArt.text(self, Vector2(x, y), al[i], 16.0, Color8(130, 60, 40))
			y += 21
	y += 4
	# 타고난 것 다섯 + 운 · 건강 — 두 줄 격자(칸 하나에 이름 · 막대 · 숫자)
	var cells := [["근골", me.gol / 100.0, me.gol], ["오성", me.wis / 100.0, me.wis], ["매력", me.cha / 100.0, me.cha],
			["손재주", me.dex / 100.0, me.dex], ["수완", me.wit / 100.0, me.wit], ["운", me.luck / 10.0, me.luck * 10],
			["건강", me.hp / 100.0, int(me.hp)]]
	var cw := (w - 12) * 0.5
	for i in cells.size():
		var c: Array = cells[i]
		var cx := x + (i % 2) * (cw + 12)
		var cy := y + (i / 2) * 24
		GhArt.text(self, Vector2(cx, cy), String(c[0]), 15.0, GhD.DIM)
		GhArt.bar(self, Rect2(cx + 46, cy + 6, cw - 80, 11), float(c[1]), GhD.JADE if c[0] == "건강" else GhD.GOLD)
		GhArt.text(self, Vector2(cx + cw - 28, cy), "%d" % int(c[2]), 15.0, GhD.INK)
	# 심성 — 가운데가 0 인 막대(격자 마지막 칸)
	var sx := x + cw + 12
	var sy := y + 3 * 24
	GhArt.text(self, Vector2(sx, sy), "심성", 15.0, GhD.DIM)
	var br := Rect2(sx + 46, sy + 6, cw - 80, 11)
	draw_rect(br, Color(0, 0, 0, 0.12), true)
	var mid := br.position.x + br.size.x * 0.5
	var gv := me.good / 100.0 * br.size.x * 0.5
	draw_rect(Rect2(minf(mid, mid + gv), br.position.y, absf(gv), br.size.y), GhD.SIDE_COL["정"] if gv >= 0 else GhD.RED, true)
	draw_line(Vector2(mid, br.position.y - 2), Vector2(mid, br.end.y + 2), GhD.INK, 1.5)
	GhArt.text(self, Vector2(sx + cw - 28, sy), "정" if me.good > 20 else ("사" if me.good < -20 else "중"), 15.0, GhD.INK)
	y += 4 * 24 + 6
	if me.cons != "":
		GhArt.text(self, Vector2(x, y), "체질  " + me.cons, 16.0, Color8(130, 60, 40))
		y += 22
	var facts: Array = []
	if me.martial:
		facts.append("내공 %d년" % int(me.neigong))
	facts.append("명성 %d" % me.fame)
	if me.infamy > 0:
		facts.append("악명 %d" % me.infamy)
	if me.gov > 0:
		facts.append("관부 신망 %d" % me.gov)
	facts.append("재물 %s냥" % _num(me.gold))
	if me.debt > 0:
		facts.append("빚 %s냥" % _num(me.debt))
	var fl0 := GhArt.wrap("   ".join(facts), w, 17.0)
	for line in fl0:
		GhArt.text(self, Vector2(x, y), line, 17.0, GhD.INK)
		y += 22
	y -= 22
	y += 28
	var fam: Array = []
	if me.flags.has("married"):
		fam.append("배우자 " + me.spouse)
	elif me.flags.has("widowed"):
		fam.append("사별")
	if me.kids > 0:
		fam.append("자식 %d" % me.kids)
	if me.martial and me.master != "" and not me.flags.has("quit"):
		fam.append("사부 " + me.master)
	if me.flags.has("enemy"):
		fam.append("원수 " + me.foe)
	if me.office > 0:
		fam.append(GhLife.OFFICE[me.office])
	var fl := GhArt.wrap("   ".join(fam), w, 18.0)
	for i in mini(fl.size(), 3):
		if y + 24 > _info_btn(0).position.y - 4:
			break
		GhArt.text(self, Vector2(x, y), fl[i], 18.0, GhD.INK)
		y += 24
	if not review and me.alive:
		_btn(_info_btn(0), "방침: " + String(GhD.focus(me.focus).name), false, 17.0)
	else:
		_btn(_info_btn(0), "방침", false, 17.0, false)


## 지금 진로가 어느 쪽으로 기울어 있나 — 꼬리표별 배수. 1 이 보통.
func _lean_lines(width: float, size: float) -> PackedStringArray:
	var parts: Array = []
	for k in ["entry", "civil", "trade", "luck", "meet", "danger", "vice"]:
		var m := run.me.mul(k)
		parts.append("%s x%.1f" % [GhD.TAGS[k], m])
	return GhArt.wrap("   ".join(parts), width, size)


func _draw_lean(m: Rect2, y: float) -> float:
	GhArt.text(self, Vector2(m.position.x + 24, y), "지금 진로의 기운 (보통이 x1.0)", 19.0, GhD.RED)
	var ll := _lean_lines(m.size.x - 48, 18.0)
	for i in ll.size():
		GhArt.text(self, Vector2(m.position.x + 24, y + 28 + i * 24), ll[i], 18.0, GhD.INK)
	return y + 28 + ll.size() * 24


## 창 안의 한 줄 — state: 0 보통 · 1 켜짐(붉음) · 2 못 함(흐림) · 3 가졌음(초록)
var _row_max := 0.0             ## 그린 줄 중 가장 아래(기운 글이 그 밑에 온다)


func _row(r: Rect2, title: String, desc: String, right: String, state: int) -> void:
	if r.size.x <= 0.0:
		return
	_row_max = maxf(_row_max, r.end.y)
	var fill := GhD.PAPER_D
	match state:
		1:
			fill = GhD.RED
		2:
			fill = Color(GhD.PAPER_D, 0.4)
		3:
			fill = Color8(200, 220, 190)
		_:
			if r.has_point(mouse):
				fill = GhD.PAPER
	G2.panel(self, r, fill, GhD.INK, 1.5, 8)
	var tc := Color(1, 1, 1) if state == 1 else Color(GhD.INK, 0.42 if state == 2 else 1.0)
	# 줄이 낮으면(_fit_step) 글자도 같이 줄인다
	var small := r.size.y < 44.0
	var ts := 18.0 if small else 20.0
	var ds := 13.0 if small else 14.0
	var rs := 16.0 if small else 17.0
	GhArt.text(self, r.position + Vector2(12, 2 if small else 3), title, ts, tc)
	# 오른쪽 글(값 · 못 하는 이유)은 **제목 줄**에 둔다 — 설명 줄 가운데에 두면 설명을 덮거나 설명 폭을 깎아
	# 문장이 중간에서 잘렸다(사용자 지적 11-07). 설명은 줄 폭을 다 쓰고, 그래도 넘치면 ".." 로 끝낸다.
	if right != "":
		var rw := GhArt.text_w(right, rs)
		var room := r.size.x - 24 - GhArt.text_w(title, ts) - 16
		if rw > room:
			right = _clip(right, room, rs)
			rw = GhArt.text_w(right, rs)
		GhArt.text(self, Vector2(r.end.x - 12 - rw, r.position.y + (3 if small else 5)), right, rs, tc)
	if desc != "":
		GhArt.text(self, r.position + Vector2(12, 22 if small else 26), _clip(desc, r.size.x - 24, ds), ds, Color(tc, 0.85))


## 폭에 안 들어가는 글은 뒤를 잘라 ".." 로 끝낸다(Jua 에 "…" 가 없다)
func _clip(s: String, w: float, size: float) -> String:
	if GhArt.text_w(s, size) <= w:
		return s
	var t := s
	while t.length() > 1 and GhArt.text_w(t + "..", size) > w:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges().trim_suffix(",").trim_suffix(".") + ".."


func _draw_plan() -> void:
	var me := run.me
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5), true)
	var m := _modal_rect()
	GhArt.paper(self, m)
	for i in PLAN_TABS.size():
		_btn(_plan_tab(i), String(PLAN_TABS[i]), plan_tab == i, 19.0)
	var money := "재물 %s냥" % _num(me.gold) + ("   빚 %s냥" % _num(me.debt) if me.debt > 0 else "") + "   신용 %s" % _num(me.credit())
	GhArt.text(self, Vector2(m.end.x - 24 - GhArt.text_w(money, 20.0), m.position.y + 24), money, 20.0,
			GhD.RED if me.debt > 0 else GhD.INK)
	var hy := m.position.y + PLAN_Y - 32
	_row_max = 0.0
	var lean_y := 0.0
	match plan_tab:
		0:
			GhArt.text(self, Vector2(_plan_focus(0).position.x, hy), "방침 (하나)", 20.0, GhD.RED)
			GhArt.text(self, _habit_head(), "매년 하는 일 (여럿, 해마다 돈이 든다)", 20.0, GhD.RED)
			for i in GhD.FOCUS.size():
				var f: Dictionary = GhD.FOCUS[i]
				var ok := me.focus_ok(f.id)
				_row(_plan_focus(i), String(f.name), String(f.desc), "", 1 if me.focus == f.id else (0 if ok else 2))
			var focus_end := _row_max
			for i in GhD.HABITS.size():
				var h: Dictionary = GhD.HABITS[i]
				var on: bool = me.habits.has(h.id)
				var ok := me.habit_ok(h.id)
				var cost := "해마다 %d냥" % me.habit_cost(h.id)
				_row(_plan_habit(i), String(h.name), String(h.desc), ("켬  " if on else "") + cost, 1 if on else (0 if ok else 2))
			if wide():
				# 가로 — 매년 하는 일이 길어 오른쪽 아래가 닫기 단추와 닿는다. 기운 글은 왼쪽 방침 밑에
				_draw_lean(Rect2(m.position, Vector2(m.size.x * 0.5, m.size.y)), maxf(focus_end, m.position.y + PLAN_Y) + 12)
				lean_y = -1.0
			else:
				lean_y = _row_max + 12
		1:
			GhArt.text(self, Vector2(m.position.x + 20, hy), "지금 하기 (각각 한 해에 한 번)", 20.0, GhD.RED)
			for i in GhD.ACTIONS.size():
				var a: Dictionary = GhD.ACTIONS[i]
				var why := me.act_block(a.id)
				var right := why if why != "" else ("%d냥" % int(a.cost) if int(a.cost) > 0 else "")
				if why == "재물 부족":
					right = "재물 부족, 빌릴 수 있다"
				var bk := me.my_biz_key()
				if a.id in ["ownbiz", "growbiz"] and why == "":
					right = "%s  %d냥" % [GhD.biz(bk).name, me.biz_cost(bk)]
				if a.id == "closebiz" and why == "":
					right = "%s %d단" % [GhD.biz(me._biggest_biz()).name, int(me.biz[me._biggest_biz()])]
				if a.id == "exam" and why == "":
					right = "%s  붙을 확률 %d%%  %d냥" % [GhD.EXAMS[me.degree].name, roundi(me.exam_chance(me.degree) * 100), int(a.cost)]
				if a.id == "loan" and why == "":
					right = "%d냥 빌릴 수 있다" % me.loan_size()
				if a.id == "repay" and why == "":
					right = "빚 %d냥" % me.debt
				_row(_plan_act(i), String(a.name), String(a.desc), right, 0 if why == "" else 2)
			lean_y = _row_max + 12
		2:
			var head := "배움 (갈래마다 한 단계씩, 마치면 다음 단계가 열린다, 한 번에 하나)"
			if me.degree > 0:
				head += "   " + String(GhD.DEGREES[me.degree])
			GhArt.text(self, Vector2(m.position.x + 20, hy), _clip(head, m.size.x - 40, 20.0), 20.0, GhD.RED)
			for t in GhD.TRACKS.size():
				var tr: Dictionary = GhD.TRACKS[t]
				var ids: Array = tr.ids
				var s := _track_stage(t)
				var rr := _track_rect(t)
				if s < 0:
					_row(rr, "%s  다 배웠다" % String(tr.name), "%d단계를 모두 마쳤다" % ids.size(), "", 3)
					continue
				var c: Dictionary = GhD.course(String(ids[s]))
				var why := me.course_block(c.id)
				var on: bool = me.course == c.id
				var right := "%d해, 해마다 %d냥" % [int(c.years), int(c.cost)]
				var st := 0
				if on:
					right = "배우는 중 %.1f / %d" % [me.course_prog, int(c.years)]
					st = 1
				elif why != "":
					right = why
					st = 2
				var nm := String(c.name).trim_suffix(" 진학").trim_suffix(" 유학")
				if tr.has("tags"):
					nm += " (%s)" % String(tr.tags[s])
				var title := "%s  %s" % [String(tr.name), nm] if ids.size() == 1 else "%s  %d/%d단계  %s" % [String(tr.name), s + 1, ids.size(), nm]
				_row(rr, title, String(c.desc), right, st)
			lean_y = _row_max + 12
		3:
			GhArt.text(self, Vector2(m.position.x + 20, hy), "직업 (조건이 맞으면 바로 바꾼다, 한 해에 한 번)", 20.0, GhD.RED)
			for i in JOB_LIST.size():
				var j: String = JOB_LIST[i]
				var why := me.job_block(j)
				var nm := (("문파의 일 (%s)" % me.sect_name()) if me.work_key().begins_with("sect:") else ("집안의 일 (%s)" % me.cls_name())) if j == "" else String(GhD.JOBS[j].name)
				var apt := me.aptitude(j)
				var inc := ("" if j == "" else "해마다 %d냥   " % int(GhD.JOBS[j].inc)) + "적성 " + ("높음" if apt >= 0.62 else ("보통" if apt >= 0.42 else "낮음"))
				var on := me.job == j
				_row(_plan_job(i), nm, inc, ("%s %d/%d단" % [me.work_title(), me.work_rank_now() + 1, me.work_max() + 1]) if on and me.work_key() != "" else ("지금 하는 일" if on else why), 1 if on else (0 if why == "" else 2))
			lean_y = -1.0
		4:
			GhArt.text(self, Vector2(m.position.x + 20, hy), "집 (땅값 x%.2f, 누르면 사고 다시 누르면 판다)" % me.land, 20.0, GhD.RED)
			for i in GhD.HOUSES.size():
				var h: Dictionary = GhD.HOUSES[i]
				var own: bool = me.houses.has(h.id)
				var why := me.house_block(h.id)
				var right := ("가졌다, 팔면 %d냥" % int(me.house_cost(h.id) * 0.8)) if own else (why if why != "" else "%d냥" % me.house_cost(h.id))
				_row(_plan_house(i), String(h.name), String(h.desc), right, 3 if own else (0 if why == "" else 2))
			GhArt.text(self, _inv_head(), "투자 (누르면 100냥 넣기)", 20.0, GhD.RED)
			for i in GhD.INVEST.size():
				var v: Dictionary = GhD.INVEST[i]
				var r := _plan_inv(i)
				var have := int(me.holdings.get(v.id, 0.0))
				_row(r, String(v.name), String(v.desc), ("%d냥   " % have) if have > 0 else "", 0 if me.gold >= 100 and me.age >= 16 else 2)
				if have > 0:
					_btn(_sub_btn(r), "팔기", false, 17.0)
			# 사업은 여기서 안 차린다 — 지금 하는 일에서 자라나므로 "지금 하기" 에 있다(사용자 요청 11-07)
			lean_y = -1.0
			var tot := "재산 %s냥  (집 · 투자 · 사업을 판 값)" % _num(me.assets_value())
			var bk := me._biggest_biz()
			if bk != "":
				tot += "   내 사업 %s %d단" % [GhD.biz(bk).name, int(me.biz[bk])]
			if me.biz_profit != 0:
				tot += "   지난해 사업 벌이 %s냥" % _num(me.biz_profit)
			GhArt.text(self, Vector2(m.position.x + 24, _modal_btn(0).position.y - 34), tot, 19.0, GhD.INK)
		5:
			GhArt.text(self, Vector2(m.position.x + 20, hy), "탈것 (누르면 사고 다시 누르면 판다, 해마다 값이 깎이고 유지비가 든다)", 20.0, GhD.RED)
			for i in GhD.RIDES.size():
				var rd: Dictionary = GhD.RIDES[i]
				var own: bool = me.rides.has(rd.id)
				var why := me.ride_block(rd.id)
				var right := ("팔면 %d냥" % me.ride_value(rd.id)) if own else (why if why != "" else "%d냥" % int(rd.cost))
				right += "  해마다 %d냥" % int(rd.keep) if why == "" or own else ""
				_row(_plan_ride(i), String(rd.name), _ride_desc(rd), right, 3 if own else (0 if why == "" else 2))
			lean_y = _row_max + 12
		6:
			GhArt.text(self, Vector2(m.position.x + 20, hy), "물건 (한쪽 길에 가까워지면 다른 길과 멀어진다, 가진 것을 누르면 버린다)", 20.0, GhD.RED)
			for i in GhD.ITEMS.size():
				var it: Dictionary = GhD.ITEMS[i]
				var own: bool = me.items.has(it.id)
				var ok := me.can_buy(it.id)
				_row(_plan_item(i), String(it.name), GhD.effect_text(it.mul) + ". " + String(it.desc),
						"가졌다" if own else "%d냥" % int(it.cost), 3 if own else (0 if ok else 2))
			lean_y = _row_max + 12
	if _row_max <= 0.0 and plan_tab != 4:
		GhArt.text_mid(self, m.get_center(), "지금 할 수 있는 것이 없다", 24.0, GhD.DIM)
		lean_y = -1.0
	# 기운 글은 닫기 단추 위에 들어갈 때만 — 줄이 많은 탭에서 창 밖으로 나갔다. 방침 탭에는 늘 있다
	if lean_y > 0.0 and lean_y + 28 + _lean_lines(m.size.x - 48, 18.0).size() * 24 <= _modal_btn(0).position.y - 4:
		_draw_lean(m, lean_y)
	_btn(_modal_btn(0), "닫기", false, 22.0)


func _draw_rels() -> void:
	var me := run.me
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5), true)
	var m := _modal_rect()
	GhArt.paper(self, m)
	GhArt.text(self, m.position + Vector2(24, 16), "인연", 26.0, GhD.INK)
	GhArt.text(self, m.position + Vector2(100, 24), "정이 깊을수록 그 사람의 성향 쪽으로 삶이 기운다", 17.0, GhD.DIM)
	var cols := 2 if wide() else 1
	var cw := (m.size.x - 48 - (cols - 1) * 16) / cols
	var rh := 50.0
	var per := int((m.size.y - 300) / rh) if wide() else int((m.size.y - 320) / rh)
	var shown := 0
	for i in me.rels.size():
		var r: Dictionary = me.rels[i]
		var col := shown / per
		var row := shown % per
		if col >= cols:
			break
		shown += 1
		var rr := Rect2(m.position.x + 24 + col * (cw + 16), m.position.y + 62 + row * rh, cw, rh - 6)
		var dead: bool = not r.alive
		G2.panel(self, rr, Color(GhD.PAPER_D, 0.5 if dead else 1.0), Color(GhD.INK, 0.4), 1.0, 6)
		var tc := Color(GhD.INK, 0.45 if dead else 1.0)
		GhArt.text(self, rr.position + Vector2(10, 2), "%s  %s" % [r.kind, r.name], 19.0, tc)
		var tr := String(GhD.trait_of(r.tt).name) + ("   (세상을 떠남)" if dead and r.kind != "헤어진 배우자" else "")
		GhArt.text(self, rr.position + Vector2(10, 24), tr, 14.0, Color(tc, 0.8))
		GhArt.text(self, Vector2(rr.end.x - 150, rr.position.y + 4), "정", 15.0, GhD.DIM)
		GhArt.bar(self, Rect2(rr.end.x - 128, rr.position.y + 9, 110, 10), float(r.bond) / 100.0, GhD.RED if not dead else GhD.DIM)
	if me.rels.is_empty():
		GhArt.text(self, m.position + Vector2(24, 70), "아직 아무도 없다.", 20.0, GhD.DIM)
	_draw_lean(m, m.position.y + 62 + per * rh + 10)
	_btn(_modal_btn(0), "닫기", false, 22.0)


## 연대기 — 아래에서 위로 쌓는다(맨 아래가 올해). 위로 올려 지난 일을 읽을 수 있다.
func _draw_log() -> void:
	var r := _log_rect()
	GhArt.paper(self, r)
	var size := 21.0 if wide() else 24.0
	var lh := size * 1.42
	var gutter := 62.0
	var tw := r.size.x - gutter - 28
	var lines: Array = run.me.lines
	# 아래에서부터 높이를 쌓으며 그린다
	var y := r.end.y - 14 + scroll
	var top := r.position.y + 10
	var i := lines.size() - 1
	while i >= 0:
		var e: Dictionary = lines[i]
		var kind := String(e.kind)
		var s := String(e.txt)
		var sz := size + (2.0 if kind in ["death", "realm"] else 0.0)
		var prefix := "천하  " if kind == "world" else ""
		var wl := GhArt.wrap(prefix + s, tw, sz)
		var h := wl.size() * lh + 6
		y -= h
		if y + h < top:
			break
		var a := clampf((t - float(seen_at.get(i, -9.0))) / 0.4, 0.0, 1.0)
		var col := _kind_col(kind)
		col.a *= a
		for j in wl.size():
			var ly := y + j * lh
			if ly >= top and ly + lh <= r.end.y - 4:
				GhArt.text(self, Vector2(r.position.x + gutter, ly), wl[j], sz, col)
		# 나이 — 그 해의 첫 줄에만
		var first := i == 0 or int(lines[i - 1].age) != int(e.age)
		if first and y >= top and y + lh <= r.end.y:
			GhArt.text(self, Vector2(r.position.x + 12, y + 2), "%d세" % int(e.age), 18.0, Color(GhD.DIM, a))
			draw_line(Vector2(r.position.x + 10, y - 2), Vector2(r.end.x - 10, y - 2), Color(GhD.INK, 0.08), 1.0)
		i -= 1
	if scroll > 0.0:
		var hint := Rect2(r.end.x - 170, r.end.y - 40, 160, 32)
		G2.panel(self, hint, Color(GhD.INK, 0.75), Color(), 0.0, 8)
		GhArt.text_mid(self, hint.get_center(), "아래로 내리면 올해", 16.0, GhD.PAPER)


func _kind_col(k: String) -> Color:
	match k:
		"world":
			return Color8(60, 110, 100)
		"big", "birth":
			return Color8(150, 90, 20)
		"realm":
			return GhD.RED
		"death":
			return GhD.RED
		"peer":
			return Color8(110, 70, 150)
		"pick":
			return Color8(40, 90, 150)
		"flavor":
			return Color(GhD.INK, 0.62)
		"choice":
			return GhD.INK
	return GhD.INK


## 오른쪽 판 — 기본은 **나와 관계있는 사람들**(사용자 요청 11-07: "같이 태어난 사람의 상태는 별로 의미 없다,
## 나랑 관계있는 사람들이 나오게"). 같은 해 태어난 이들은 머리의 "동년배" 탭으로 남겨 둔다.
var side_mode := 0              ## 0 인연 · 1 동년배
const REL_ORDER := ["배우자", "정인", "자식", "아버지", "어머니", "사부", "제자", "의형제", "친구",
		"형", "오빠", "누나", "언니", "남동생", "여동생", "숙적", "옛 정인", "헤어진 배우자"]


func _side_tab(i: int) -> Rect2:
	var r := _peers_rect()
	return Rect2(r.position.x + 8 + i * 82, r.position.y + 6, 76, 30)


## 보일 인연 — 살아 있는 사람 먼저, 그다음 가까운 사이(REL_ORDER) · 정이 깊은 순
func _rel_rows() -> Array:
	var me := run.me
	var idx: Array = range(me.rels.size())
	idx.sort_custom(func(a, b):
		var ra: Dictionary = me.rels[a]
		var rb: Dictionary = me.rels[b]
		if bool(ra.alive) != bool(rb.alive):
			return bool(ra.alive)
		var oa := REL_ORDER.find(String(ra.kind))
		var ob := REL_ORDER.find(String(rb.kind))
		oa = 99 if oa < 0 else oa
		ob = 99 if ob < 0 else ob
		if oa != ob:
			return oa < ob
		return int(ra.bond) > int(rb.bond))
	return idx.slice(0, _rel_cap())


func _rel_cap() -> int:
	var r := _peers_rect()
	if wide():
		return maxi(1, int((r.size.y - 44 - 40) / 62.0))
	return 6


func _rel_card(k: int) -> Rect2:
	var r := _peers_rect()
	if wide():
		return Rect2(r.position.x + 8, r.position.y + 44 + k * 62, r.size.x - 16, 56)
	var w := (r.size.x - 24) / 2.0
	return Rect2(r.position.x + 8 + (k % 2) * (w + 8), r.position.y + 44 + (k / 2) * 62, w, 56)


## "인연 전부 보기" — 판에 다 안 들어가는 사람들은 인연 창에서
func _rel_more() -> Rect2:
	var r := _peers_rect()
	return Rect2(r.position.x + 8, r.end.y - 38, r.size.x - 16, 32)


func _peer_index(nm: String) -> int:
	for i in run.peers.size():
		if run.peers[i].name == nm:
			return i
	return -1


func _draw_side() -> void:
	var r := _peers_rect()
	GhArt.paper(self, r, GhD.PAPER_D)
	_btn(_side_tab(0), "인연", side_mode == 0, 17.0)
	_btn(_side_tab(1), "동년배", side_mode == 1, 17.0)
	if side_mode == 1:
		_draw_peers()
		return
	var me := run.me
	var rows := _rel_rows()
	if rows.is_empty():
		GhArt.text(self, r.position + Vector2(16, 56), "아직 이어진 사람이 없다", 17.0, GhD.DIM)
	for k in rows.size():
		var rel: Dictionary = me.rels[rows[k]]
		var c := _rel_card(k)
		var dead := not bool(rel.alive)
		var fill := Color(GhD.PAPER, 0.55 if dead else 1.0)
		if c.has_point(mouse):
			fill = fill.lightened(0.15)
		G2.panel(self, c, fill, Color(GhD.INK, 0.5), 1.2, 8)
		var tc := Color(GhD.INK, 0.5 if dead else 1.0)
		var kind := String(rel.kind)
		var kc := Color8(110, 70, 150) if kind in ["배우자", "정인"] else (GhD.RED if kind == "숙적" else Color8(150, 90, 20))
		GhArt.text(self, c.position + Vector2(10, 4), kind, 15.0, Color(kc, 0.55 if dead else 1.0))
		GhArt.text(self, c.position + Vector2(14 + GhArt.text_w(kind, 15.0), 2), _clip(String(rel.name), c.size.x - 150, 19.0), 19.0, tc)
		# 정 — 막대
		GhArt.bar(self, Rect2(c.end.x - 74, c.position.y + 10, 62, 8), float(rel.bond) / 100.0, GhD.RED if not dead else GhD.DIM)
		# 둘째 줄 — 동년배면 그 사람의 지금(나이 · 경지 · 일), 아니면 성향
		var st := String(GhD.trait_of(rel.tt).name)
		var pi := _peer_index(String(rel.name))
		if pi >= 0:
			var p: GhLife = run.peers[pi]
			st = ("향년 %d세, %s" % [p.age, p.cause]) if not p.alive else ("%d세, %s" % [p.age, p.realm_name() if p.martial else _peer_doing(p)])
		elif dead:
			st = "세상을 떠남"
		GhArt.text(self, c.position + Vector2(10, 30), _clip(st, c.size.x - 20, 15.0), 15.0, Color(tc, 0.8))
	var alive_n := 0
	for rel in me.rels:
		if rel.alive:
			alive_n += 1
	_btn(_rel_more(), "인연 전부 보기 (%d명)" % alive_n, false, 16.0)


func _draw_peers() -> void:
	var r := _peers_rect()
	for i in run.peers.size():
		var p: GhLife = run.peers[i]
		var c := _peer_card(i)
		var dead := not p.alive
		var fill := Color(GhD.PAPER, 0.55 if dead else 1.0)
		if c.has_point(mouse):
			fill = fill.lightened(0.15)
		G2.panel(self, c, fill, Color(GhD.INK, 0.6), 1.5, 8)
		var sc: Color = GhD.SIDE_COL.get(p.side if p.martial else "", GhD.SIDE_COL[""])
		draw_rect(Rect2(c.position + Vector2(0, 6), Vector2(6, c.size.y - 12)), sc, true)
		var x := c.position.x + 16
		var y := c.position.y + 8
		GhArt.text(self, Vector2(x, y), p.display_name(), 22.0, Color(GhD.INK, 0.55 if dead else 1.0))
		if run.me.met.has(p.name) or run.me.spouse == p.name:
			var tag := "배우자" if run.me.spouse == p.name else "아는 사이"
			var tw := GhArt.text_w(tag, 15.0)
			G2.panel(self, Rect2(c.end.x - tw - 22, y + 2, tw + 14, 22), Color8(110, 70, 150), Color(), 0.0, 6)
			GhArt.text(self, Vector2(c.end.x - tw - 15, y + 3), tag, 15.0, Color(1, 1, 1))
		GhArt.text(self, Vector2(x, y + 30), "%s %s의 %s" % [p.region_name(), p.house_name(), p.child_label()],
				15.0, GhD.DIM)
		var st := ""
		if dead:
			st = "향년 %d세, %s" % [p.age, p.cause]
		else:
			st = "%d세, %s" % [p.age, p.realm_name() if p.martial else _peer_doing(p)]
		if c.size.y > 84:
			GhArt.text(self, Vector2(x, y + 52), st, 17.0, GhD.RED if dead else GhD.INK)
		# 가장 최근 한 줄
		if c.size.y > 112 and not p.lines.is_empty():
			var last := String(p.lines.back().txt)
			var wl := GhArt.wrap(last, c.size.x - 30, 15.0)
			GhArt.text(self, Vector2(x, y + 76), wl[0] + ("..." if wl.size() > 1 else ""), 15.0, Color(GhD.INK, 0.6))


func _peer_doing(p: GhLife) -> String:
	if p.work_key() != "" and p.work_rank_now() >= 1:
		return p.work_title()
	if p.flags.has("official"):
		return GhLife.OFFICE[p.office]
	if p.flags.has("married"):
		return "가정을 꾸림" if p.kids > 0 else "혼인함"
	return p.cls_name()


func _draw_choice() -> void:
	var b := _choice_box()
	draw_rect(Rect2(_log_rect().position, _log_rect().size), Color(0, 0, 0, 0.18), true)
	G2.panel(self, b.grow(4), Color(GhD.RED, 0.85), Color(), 0.0, 14)
	G2.panel(self, b, GhD.PAPER, GhD.INK, 2.5, 12)
	GhArt.text(self, b.position + Vector2(20, 12), "갈림길", 20.0, GhD.RED)
	var wl := GhArt.wrap(String(run.me.pending.title), b.size.x - 40, 24.0)
	for i in wl.size():
		GhArt.text(self, b.position + Vector2(20, 44 + i * 32), wl[i], 24.0, GhD.INK)
	var opts: Array = run.me.pending.opts
	for i in opts.size():
		_btn(_opt_rect(i), "%d.  %s" % [i + 1, opts[i]], false, 22.0)
	if auto:
		var wait := GhD.CHOICE_AUTO_SEC / maxf(1.0, _speed() * 0.5)
		GhArt.bar(self, Rect2(b.position.x + 20, b.end.y - 18, b.size.x - 40, 8), 1.0 - choice_t / wait, GhD.RED)
	# 혼처 상대의 초상 — 갈림길 상자 위에 액자로(상자 자리 · 단추 자리는 그대로). 그림이 없으면 안 그린다.
	var por := String(run.me.pending.ev.get("por", ""))
	if por != "" and GhArt.img(por) != null:
		var lr := _log_rect()
		var py := maxf(lr.position.y + 8.0, b.position.y - 272.0)
		var ph := b.position.y - 12.0 - py
		if ph > 80.0:
			var pr := Rect2(b.position.x + (b.size.x - ph * 0.8) * 0.5, py, ph * 0.8, ph)
			G2.panel(self, pr.grow(6), GhD.PAPER, GhD.INK, 2.0, 8)
			GhArt.portrait(self, pr, por)


func _draw_quit() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5), true)
	var m := _modal_rect()
	GhArt.paper(self, m)
	GhArt.text_mid(self, m.position + Vector2(m.size.x * 0.5, 50), "이 삶을 여기서 버리고 나갈까요?", 26.0, GhD.INK)
	GhArt.text_mid(self, m.position + Vector2(m.size.x * 0.5, 90), "기록에 남지 않습니다.", 20.0, GhD.DIM)
	_btn(_modal_btn(0), "나간다", false, 22.0)
	_btn(_modal_btn(1), "계속 산다", false, 22.0)


func _draw_peer_modal() -> void:
	if peer_i < 0 or peer_i >= run.peers.size():
		modal = ""
		return
	var p: GhLife = run.peers[peer_i]
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5), true)
	var m := _modal_rect()
	GhArt.paper(self, m)
	GhArt.text(self, m.position + Vector2(24, 18), p.name, 32.0, GhD.INK)
	GhArt.text(self, m.position + Vector2(24, 60), "%s %s의 %s,  %s" % [p.region_name(), p.cls_name(), "아들" if p.sex == "m" else "딸",
			("향년 %d세" % p.age) if not p.alive else ("%d세" % p.age)], 18.0, GhD.DIM)
	# 그 사람의 최근 일들(아래가 최근)
	var size := 19.0
	var lh := size * 1.4
	var area := Rect2(m.position.x + 24, m.position.y + 96, m.size.x - 48, m.size.y - 180)
	var y := area.end.y
	var i := p.lines.size() - 1
	while i >= 0:
		var e: Dictionary = p.lines[i]
		if String(e.kind) == "flavor":
			i -= 1
			continue
		var wl := GhArt.wrap("%d세  %s" % [int(e.age), String(e.txt)], area.size.x, size)
		y -= wl.size() * lh + 4
		if y < area.position.y:
			break
		for j in wl.size():
			GhArt.text(self, Vector2(area.position.x, y + j * lh), wl[j], size, _kind_col(String(e.kind)))
		i -= 1
	_btn(_modal_btn(0), "닫기", false, 22.0)


# ---------- 묘비 ----------

func _draw_end() -> void:
	var me := run.me
	_bg_art("gh_grave", 0.5)
	var tw := 330.0
	var tr := Rect2(vs.x * 0.5 - tw * 0.5, 40, tw, 440 if wide() else 470)
	GhArt.tomb(self, tr)
	var cx := tr.get_center().x
	var y := tr.position.y + 110
	if me.alias != "":
		GhArt.text_mid(self, Vector2(cx, y - 40), me.alias, 24.0, GhD.RED)
	GhArt.text_mid(self, Vector2(cx, y), me.name, 44.0, GhD.INK)
	GhArt.text_mid(self, Vector2(cx, y + 54), "천하력 %d년 ~ %d년" % [me.birth_year, me.birth_year + me.age], 20.0, GhD.INK)
	GhArt.text_mid(self, Vector2(cx, y + 84), "향년 %d세" % me.age, 24.0, GhD.INK)
	var tl := GhArt.wrap(me.title(), tw - 60, 26.0)
	for i in tl.size():
		GhArt.text_mid(self, Vector2(cx, y + 132 + i * 34), tl[i], 26.0, GhD.RED)
	GhArt.text_mid(self, Vector2(cx, y + 132 + tl.size() * 34 + 10), "%s %s의 %s" % [me.region_name(), me.house_name(), me.child_label()],
			18.0, Color8(60, 56, 52))
	if end_fresh:
		var badge := Rect2(tr.end.x - 40, tr.position.y + 40, 110, 36)
		G2.panel(self, badge, GhD.RED, GhD.INK, 2.0, 8)
		GhArt.text_mid(self, badge.get_center(), "새 칭호", 20.0, Color(1, 1, 1))
	# 일생 큰일 · 동년배의 마지막
	var lw := 380.0 if wide() else vs.x - 40
	var lr := Rect2(30, 60, lw, 400) if wide() else Rect2(20, tr.end.y + 16, lw, 300)
	var pr := Rect2(vs.x - 30 - lw, 60, lw, 400) if wide() else Rect2(20, lr.end.y + 12, lw, 250)
	var life: Array = me.big.duplicate()
	if life.is_empty():
		life.append("큰일 없이 조용히 살다 갔다.")
	var sum: Array = []
	if me.kids + me.kids_lost > 0:
		sum.append("자식 %d명을 두었다" % (me.kids + me.kids_lost) + ("" if me.kids_lost == 0 else " (%d명을 먼저 보냄)" % me.kids_lost))
	if me.martial:
		sum.append("경지 %s, 내공 %d년" % [me.realm_name(), int(me.neigong)])
		if not me.arts_known.is_empty():
			life.append("익힌 무공: " + ", ".join(me.arts_known))
	if me.work_key() != "" and me.work_rank_now() >= 1:
		sum.append("%s (%d단)" % [me.work_title(), me.work_rank_now() + 1])
	sum.append("재물 %s냥, 명성 %d" % [_num(me.gold), me.fame])
	if me.debt > 0:
		sum.append("빚 %s냥을 남김" % _num(me.debt))
	life.append("  ".join(sum))
	_end_list(lr, "일생", life)
	var pf: Array = []
	for p: GhLife in run.peers:
		pf.append("%s  향년 %d세, %s" % [p.display_name(), p.age, p.title()])
	_end_list(pr, "같은 해 태어난 이들의 마지막", pf)
	_btn(_end_btn(0), "다시 태어나기", false, 24.0)
	_btn(_end_btn(1), "연대기 보기", false, 22.0)
	_btn(_end_btn(2), "처음으로", false, 22.0)


func _end_list(r: Rect2, head: String, items: Array) -> void:
	var size := 18.0
	var lh := 25.0
	var rows: Array = []
	for s in items:
		for l in GhArt.wrap(String(s), r.size.x - 30, size):
			rows.append(l)
	var h := minf(r.size.y, 50.0 + rows.size() * lh)
	var box := Rect2(r.position, Vector2(r.size.x, h))
	GhArt.paper(self, box, Color(GhD.PAPER, 0.92))
	GhArt.text(self, box.position + Vector2(14, 10), head, 20.0, GhD.RED)
	for i in rows.size():
		var y := box.position.y + 42 + i * lh
		if y + lh > box.end.y:
			break
		GhArt.text(self, Vector2(box.position.x + 16, y), rows[i], size, GhD.INK)


# ---------- 지난 인생 ----------

func _draw_records() -> void:
	_bg_art("gh_title", 0.6)
	_btn(_rec_back(), "처음", false, 22.0)
	GhArt.text_mid(self, Vector2(vs.x * 0.5, 34), "지난 인생", 32.0, GhD.PAPER, 6.0)
	var r := Rect2(vs.x * 0.5 - minf(560.0, vs.x * 0.5 - 20), 72, minf(1120.0, vs.x - 40), vs.y - 90)
	GhArt.paper(self, r)
	if GhSv.lives.is_empty():
		GhArt.text_mid(self, r.get_center(), "아직 살아 본 인생이 없다.", 24.0, GhD.DIM)
		return
	GhArt.text(self, r.position + Vector2(20, 12), "%d번 태어남   모은 칭호 %d종   가장 높은 경지 %s" % [GhSv.births, GhSv.titles.size(),
			GhD.REALMS[GhSv.best_realm]], 20.0, GhD.INK)
	var row := 56.0
	var y0 := r.position.y + 50 - rec_scroll
	for i in GhSv.lives.size():
		var l: Dictionary = GhSv.lives[i]
		var y := y0 + i * row
		if y < r.position.y + 44 or y + row > r.end.y - 6:
			continue
		draw_line(Vector2(r.position.x + 14, y), Vector2(r.end.x - 14, y), Color(GhD.INK, 0.12), 1.0)
		GhArt.text(self, Vector2(r.position.x + 20, y + 6), String(l.name), 22.0, GhD.INK)
		GhArt.text(self, Vector2(r.position.x + 20, y + 32), "%s %s의 %s,  향년 %d세" % [l.region, l.cls, String(l.get("label", "아들" if l.sex == "m" else "딸")), int(l.age)],
				15.0, GhD.DIM)
		var tt := String(l.title)
		GhArt.text(self, Vector2(r.position.x + r.size.x * 0.45, y + 14), tt, 21.0, GhD.RED)
		var rr := String(GhD.REALMS[int(l.realm)])
		GhArt.text(self, Vector2(r.end.x - 20 - GhArt.text_w(rr, 18.0), y + 16), rr, 18.0, GhD.INK)


# ==================== 확인용 ====================


## `--gh-click-test` — 진짜 마우스 이벤트로 처음 → 태어나기 → 삶 시작 → 배속 → 갈림길 → 나가기 → 지난 인생 → 처음.
## 화면마다 상태가 바뀌었는지 보고, 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.35:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(_title_btn(0).get_center()), func(): return scr == Scr.BIRTH, "태어나기"],
		[func(): _press(Vector2(vs.x * 0.5, vs.y * 0.4)), func(): return _birth_all(), "출생 한꺼번에"],
		[func(): _press(_birth_go().get_center()), func(): return scr == Scr.LIFE, "삶 시작"],
		[func(): _press(_ctrl_rect(5).get_center()), func(): return speed_i == 4, "배속 x8"],
		[func(): _press(_ctrl_rect(6).get_center()), func(): return auto, "자동 켜기"],
		[func(): _press(_ctrl_rect(6).get_center()), func(): return not auto, "자동 끄기"],
		[func(): _press(_ctrl_rect(0).get_center()), func(): return paused, "멈춤"],
		[func(): _press(_ctrl_rect(0).get_center()), func(): return not paused, "계속"],
		[func(): _force_choice(), func(): return run.waiting(), "갈림길 띄우기"],
		[func(): _press(_opt_rect(0).get_center()), func(): return not run.waiting(), "갈림길 고르기"],
		[func(): _press(_rel_more().get_center()), func(): return modal == "rels", "오른쪽 인연 전부 보기"],
		[func(): _press(_modal_btn(0).get_center()), func(): return modal == "", "인연 닫기"],
		[func(): _press(_side_tab(1).get_center()), func(): return side_mode == 1, "동년배 탭"],
		[func(): _press(_peer_card(0).get_center()), func(): return modal == "peer", "동년배 보기"],
		[func(): _press(_modal_btn(0).get_center()), func(): return modal == "", "동년배 닫기"],
		[func(): _press(_side_tab(0).get_center()), func(): return side_mode == 0, "인연 탭"],
			[func(): _press(_info_btn(0).get_center()), func(): return modal == "plan", "방침 창"],
		[func(): _press(_plan_focus(1).get_center()), func(): return run.me.focus == "rest", "방침 고르기"],
		[func(): _press(_plan_tab(1).get_center()), func(): return plan_tab == 1, "지금 하기 탭"],
		[func(): _test_gold(); _press(_plan_act(4).get_center()), func(): return run.me.acted.has("doctor"), "의원 찾아가기"],
		[func(): _press(_plan_tab(2).get_center()), func(): return plan_tab == 2, "배움 탭"],
		[func(): _press_r(_plan_course(_course_i("divine"))), func(): return run.me.course == "divine" or run.me.course_block("divine") != "", "배움 시작"],
		[func(): _press(_plan_tab(3).get_center()), func(): return plan_tab == 3, "직업 탭"],
		[func(): _press_r(_plan_job(1)), func(): return true, "직업 줄 누르기"],
		[func(): _press(_plan_tab(4).get_center()), func(): return plan_tab == 4, "재산 탭"],
		[func(): _press(_plan_tab(5).get_center()), func(): return plan_tab == 5, "탈것 탭"],
		[func(): run.me.age = maxi(run.me.age, 14); run.me.gold = maxi(run.me.gold, 200); _press_r(_plan_ride(0)),
				func(): return run.me.rides.has("donkey"), "나귀 사기"],
		[func(): _press_r(_plan_ride(0)), func(): return not run.me.rides.has("donkey"), "나귀 팔기"],
		[func(): _test_gold(); _press(_plan_tab(6).get_center()), func(): return plan_tab == 6, "물건 탭"],
		[func(): _press_r(_plan_item(0)), func(): return run.me.items.has("sword"), "목검 사기"],
		[func(): _press_r(_plan_item(0)), func(): return not run.me.items.has("sword"), "목검 버리기"],
		[func(): _press(_modal_btn(0).get_center()), func(): return modal == "", "방침 창 닫기"],
	[func(): _press(_exit_rect().get_center()), func(): return modal == "quit", "나가기 창"],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "나가기"],
		[func(): _press(_title_btn(1).get_center()), func(): return scr == Scr.RECORDS, "지난 인생"],
		[func(): _press(_rec_back().get_center()), func(): return scr == Scr.TITLE, "처음으로"],
		[func(): _press(_title_btn(2).get_center()), func(): return scr == Scr.BOOK, "도감"],
		[func(): _press(_book_tab(1).get_center()), func(): return book_tab == 1, "칭호 탭"],
		[func(): _press(_book_tab(2).get_center()), func(): return book_tab == 2, "명예의 전당 탭"],
		[func(): _press(_rec_back().get_center()), func(): return scr == Scr.TITLE, "도감 닫기"],
	]
	if _cs >= steps.size() * 2:
		print("GANGHO CLICK TEST OK")
		get_tree().quit(0)
		return
	var s: Array = steps[_cs / 2]
	if _cs % 2 == 0:
		(s[0] as Callable).call()
	elif not (s[1] as Callable).call():
		printerr("GANGHO CLICK TEST FAIL: " + String(s[2]))
		get_tree().quit(1)
		return
	_cs += 1


## 안 보이는 줄(빈 사각형)은 누르지 않는다 — 그 가운데 (0, 0) 을 누르면 창 밖이라 창이 닫혀 버린다
## ("직업 탭" 검사가 그렇게 실패했다: 어린 나이라 배움 줄이 숨어 있었다).
func _press_r(r: Rect2) -> void:
	if r.has_area():
		_press(r.get_center())


func _course_i(id: String) -> int:
	for i in GhD.COURSES.size():
		if GhD.COURSES[i].id == id:
			return i
	return 0


func _press(p: Vector2) -> void:
	# 캔버스 좌표 → 창 좌표(창이 캔버스와 크기가 다를 수 있다)
	var xf := get_viewport().get_final_transform()
	var wp := xf * p
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = wp
		e.global_position = wp
		Input.parse_input_event(e)


func _force_choice() -> void:
	if not run.waiting():
		run.me._offer(GhEv.EVENTS.filter(func(ev): return ev.id == "gamble")[0])
		_on_new_lines(run.me.lines.size() - 1)


# ---------- 전환점 삽화 ----------

func _next_moment() -> void:
	if not run.me.moments.is_empty():
		run.me.moments.pop_front()
	modal = ""
	if not run.me.moments.is_empty():
		modal = "moment"
		moment_t = 0.0


## 인생의 전환점(입문 · 대성 · 기연 · 혼인 · 첫아이 · 급제 · 장문인 · 우승 · 복수 · 참전 · 주화입마) — 삽화를 크게 띄운다.
## 그림은 `art/gangho/gh_m_*.png`, 없으면 수묵 산수.
func _draw_moment() -> void:
	var mo: Dictionary = run.me.moments[0]
	var k := clampf(moment_t / 0.45, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72 * k), true)
	var w := minf(vs.x - 80, 860.0)
	var h := w * 0.5625
	var top := (vs.y - h - 150) * 0.5
	var pic := Rect2(vs.x * 0.5 - w * 0.5, top + (1.0 - k) * 30.0, w, h)
	draw_rect(pic.grow(10), Color(GhD.PAPER, k), true)
	GhArt.picture(self, pic, String(mo.key), t, int(mo.age))
	draw_rect(pic, Color(0, 0, 0, 1.0 - k), true)
	var seal := Rect2(pic.position.x - 16, pic.position.y - 20, 0, 52)
	var tw := GhArt.text_w(String(mo.title), 34.0) + 40
	seal.size.x = tw
	G2.panel(self, seal, Color(GhD.RED, k), GhD.INK, 2.0, 6)
	GhArt.text_mid(self, seal.get_center(), String(mo.title), 34.0, Color(1, 0.95, 0.9, k))
	var tl := GhArt.wrap("%d세, %s" % [int(mo.age), String(mo.txt)], w, 26.0)
	for i in tl.size():
		GhArt.text_mid(self, Vector2(vs.x * 0.5, pic.end.y + 40 + i * 36), tl[i], 26.0, Color(GhD.PAPER, k), 5.0)
	if moment_t > 0.6:
		GhArt.text_mid(self, Vector2(vs.x * 0.5, minf(vs.y - 30, pic.end.y + 40 + tl.size() * 36 + 30)), "누르면 계속", 18.0,
				Color(1, 1, 1, 0.55), 3.0)


## `--gh-tour=폴더` — 창 하나로 일생(34세) · 방침 탭 셋 · 인연 · 전환점 삽화 · 묘비를 차례로 찍는다.
func _tour_step(dt: float) -> void:
	_tour_t += dt
	if _tour_t < 0.6:
		return
	_tour_t = 0.0
	var shots := ["life", "plan0", "plan1", "plan2", "plan3", "plan4", "plan5", "plan6", "rels", "mate", "moment", "end", "book0", "book1", "book2", "book3"]
	if _tour_i > 0:
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [tour, shots[_tour_i - 1]])
	if _tour_i >= shots.size():
		print("GANGHO TOUR OK")
		get_tree().quit(0)
		return
	match String(shots[_tour_i]):
		"life":
			gh_seed = 21 if gh_seed < 0 else gh_seed
			_new_life()
			_start_life()
			run.me.ai_plan = true
			_fast_forward(34)
			paused = true
			run.me.gold = 3000
			run.me.house_click("tile")
			run.me.invest("caravan", 100)
			run.me.biz_click(run.me.my_biz_key())
			run.me.ride_click("cart")
			run.me.item_click("abacus")
			run.me.moments.clear()
			modal = ""
		"plan0", "plan1", "plan2", "plan3", "plan4", "plan5", "plan6":
			modal = "plan"
			plan_tab = int(String(shots[_tour_i]).substr(4))
		"rels":
			modal = "rels"
		"mate":
			# 혼처 초상 — 중매 갈림길 위에 상대 초상 액자가 뜨는지 본다
			modal = ""
			run.me._offer({id = "match_meet", por = "gh_mate_f_2", txt = "중매쟁이가 이웃 고을 규수를 소개했다. 밝은 사람이라 한다.",
					ch = [{l = "만나 본다", txt = ""}, {l = "사양한다", txt = ""}]})
		"moment":
			run.me._moment("gh_m_marry", "혼인", "같은 해 태어난 이와 혼례를 올렸다.")
			modal = "moment"
			moment_t = 1.0
		"end":
			modal = ""
			_fast_forward(200)
		"book0", "book1", "book2", "book3":
			if shots[_tour_i] == "book0":
				GhSv.add(run.me, false)   # 캡처용 — 파일에는 안 쓴다
			scr = Scr.BOOK
			book_tab = int(String(shots[_tour_i]).substr(4))
	_tour_i += 1


## 검사용 — 그때까지의 일생에서 재물을 잃었으면(홍수 등) 행동이 막혀 검사가 엉뚱하게 실패한다.
func _test_gold() -> void:
	run.me.gold = maxi(run.me.gold, 100)


func _wealth_note(me: GhLife) -> String:
	var tw := 0.0
	for w in GhD.WEALTH:
		tw += float(w.w)
	if me.cls in ["beggar", "temple", "tenant"]:
		return "가산 %s냥" % _num(me.estate)
	return "%s, 가산 %s냥" % [_pct(float(GhD.WEALTH[me.wealth].w) / tw), _num(me.estate)]


func _order_note(me: GhLife) -> String:
	if me.heir:
		return "가산을 이을 자리" + (", 후계 사건이 있다" if me.cls in ["clan", "sectfam"] else "")
	return "가산은 맏이에게, 대신 떠날 자유"


# ---------- 시대 · 안내 ----------

func _era_note(me: GhLife) -> String:
	var e := me.world.era(me.birth_year + 8)
	if e == "난세":
		return "난세에 태어났다 (위험 · 무공의 길이 잦다)"
	if e == "태평성대":
		return "태평성대에 태어났다 (장사 · 글의 길이 넓다)"
	return ""


## 처음 하는 사람 안내 — 한 번 본 것은 다시 안 뜬다(GhSv.tips). 시간을 멈추지 않는다. 확인용 실행에서는 안 띄운다.
func _tip(id: String, text: String) -> void:
	if no_save or click_test or tour != "" or gh_auto:
		return
	if GhSv.tip(id):
		tip_text = text
		tip_t = 8.0


func _tips_check() -> void:
	if run == null:
		return
	var a := run.me.age
	if run.waiting():
		_tip("choice", "갈림길: 고른 쪽으로 심성과 진로가 기운다. 위의 '자동' 을 켜면 성향대로 대신 고른다.")
	elif a >= 6:
		_tip("plan", "여섯 살부터 왼쪽 아래 '방침' 으로 삶을 기울일 수 있다. 방침, 매년 하는 일, 지금 하기.")
	if a >= 10:
		_tip("peers", "오른쪽은 나와 이어진 사람들이다. 정이 깊을수록 그 사람 쪽으로 삶이 기운다. 동년배 탭에서 같은 해 태어난 이들도 볼 수 있다.")
	if a >= 13:
		_tip("study", "'방침' 창의 배움 탭에서 여러 해 공부해 자격을 따고 직업을 바꿀 수 있다.")
	if a >= 16:
		_tip("money", "돈이 모자라면 '지금 하기' 에서 전장에 신용으로 빌릴 수 있다. 이자는 해마다 1할이다.")


func _tip_rect() -> Rect2:
	var lr := _log_rect()
	var tl := GhArt.wrap(tip_text, lr.size.x - 60, 20.0)
	return Rect2(lr.position.x + 10, lr.position.y + 10, lr.size.x - 20, 30 + tl.size() * 28)


func _draw_tip() -> void:
	var r := _tip_rect()
	var a := clampf(tip_t, 0.0, 1.0)
	G2.panel(self, r, Color(GhD.INK, 0.9 * a), Color(GhD.GOLD, a), 2.0, 10)
	var tl := GhArt.wrap(tip_text, r.size.x - 40, 20.0)
	for i in tl.size():
		GhArt.text(self, r.position + Vector2(20, 14 + i * 28), tl[i], 20.0, Color(GhD.PAPER, a))


# ---------- 도감 · 명예의 전당 ----------

## 출생 도감의 줄 — 세가는 다섯으로 나눈다
func _book_kinds() -> Array:
	var out: Array = []
	for c in GhD.CLASSES:
		if c.id == "clan":
			for k in GhD.CLAN_NAME:
				out.append({key = k, name = String(GhD.CLAN_NAME[k]), w = float(c.w) / 5.0})
		else:
			out.append({key = String(c.id), name = String(c.name), w = float(c.w)})
	return out


## 칭호 도감에 자물쇠로 보여 줄 특별 칭호(지역 · 집안 이름이 들어가는 칭호는 셀 수 없어서 뺀다)
const SPECIAL_TITLES := ["천하제일인", "이름 없는 절대고수", "피에 물든 마두", "주화입마에 쓰러진 무인", "비무대회의 우승자",
		"조정의 대신", "고을의 목민관", "정마대전에 스러진 무인", "원수를 갚은 복수귀", "절정에 이른 고수", "칼을 내려놓은 승려",
		"이름난 협객", "강호를 떠돈 무인", "이름 없는 삼류 무사", "이름도 다 불리지 못한 아이"]


const BOOK_TABS := ["출생 도감", "칭호", "명예의 전당", "직업"]


func _book_tab(i: int) -> Rect2:
	var w := minf(200.0, (vs.x - 150.0) / BOOK_TABS.size() - 10.0)
	return Rect2(130 + i * (w + 10), 14, w, 44)


func _draw_book() -> void:
	_bg_art("gh_title", 0.6)
	_btn(_rec_back(), "처음", false, 22.0)
	for i in BOOK_TABS.size():
		_btn(_book_tab(i), String(BOOK_TABS[i]), book_tab == i, 20.0)
	var r := Rect2(20, 72, vs.x - 40, vs.y - 90)
	GhArt.paper(self, r)
	match book_tab:
		0:
			var kinds := _book_kinds()
			var seen := kinds.filter(func(k): return GhSv.born.has(k.key)).size()
			GhArt.text(self, r.position + Vector2(20, 12), "태어나 본 집안 %d / %d" % [seen, kinds.size()], 20.0, GhD.RED)
			var cols := 3 if wide() else 2
			var cw := (r.size.x - 40 - (cols - 1) * 12) / cols
			var rows := ceili(kinds.size() / float(cols))
			var rh := minf(58.0, (r.size.y - 56) / rows)
			for i in kinds.size():
				var k: Dictionary = kinds[i]
				var cr := Rect2(r.position.x + 20 + (i / rows) * (cw + 12), r.position.y + 46 + (i % rows) * rh, cw, rh - 6)
				var e: Dictionary = GhSv.born.get(k.key, {})
				var got := not e.is_empty()
				G2.panel(self, cr, GhD.PAPER_D if got else Color(GhD.PAPER_D, 0.35), Color(GhD.INK, 0.4), 1.0, 6)
				GhArt.text(self, cr.position + Vector2(10, 2), String(k.name) if got else "? ? ?", 19.0, Color(GhD.INK, 1.0 if got else 0.45))
				var sub := "%d번, 가장 좋은 가세 %s%s" % [int(e.n), _wealth_word(int(e.best)), ", 장자로 남" if e.get("heir", false) else ""] if got \
						else "천하 사람의 %s" % _pct(float(k.w) / 100.0)
				if rh > 40:
					GhArt.text(self, cr.position + Vector2(10, 25), sub, 14.0, Color(GhD.DIM, 1.0 if got else 0.6))
		1:
			var got_sp := SPECIAL_TITLES.filter(func(s): return GhSv.titles.has(s)).size()
			GhArt.text(self, r.position + Vector2(20, 12), "모은 칭호 %d종   특별 칭호 %d / %d" % [GhSv.titles.size(), got_sp, SPECIAL_TITLES.size()], 20.0, GhD.RED)
			var y := r.position.y + 48
			var x := r.position.x + 20
			for s in SPECIAL_TITLES:
				var has := GhSv.titles.has(s)
				var txt: String = String(s) if has else "? ? ?"
				var tw := GhArt.text_w(txt, 18.0) + 26
				if x + tw > r.end.x - 20:
					x = r.position.x + 20
					y += 38
				G2.panel(self, Rect2(x, y, tw, 32), GhD.RED if has else Color(GhD.PAPER_D, 0.5), Color(GhD.INK, 0.4), 1.0, 6)
				GhArt.text(self, Vector2(x + 13, y + 4), txt, 18.0, Color(1, 1, 1) if has else Color(GhD.INK, 0.4))
				x += tw + 8
			y += 52
			GhArt.text(self, Vector2(r.position.x + 20, y), "받은 칭호 (드문 것부터)", 18.0, GhD.DIM)
			y += 28
			var ts := GhSv.titles.keys()
			ts.sort_custom(func(a, b): return int(GhSv.titles[a]) < int(GhSv.titles[b]))
			var cols2 := 3 if wide() else 2
			var cw2 := (r.size.x - 40) / cols2
			var per := int((r.end.y - y - 10) / 26.0)
			for i in ts.size():
				var col := i / maxi(1, per)
				if col >= cols2:
					break
				GhArt.text(self, Vector2(r.position.x + 20 + col * cw2, y + (i % maxi(1, per)) * 26), "%s  x%d" % [ts[i], int(GhSv.titles[ts[i]])], 17.0, GhD.INK)
		2:
			var cats := [["realm", "가장 높은 경지"], ["wealth", "가장 큰 재산"], ["age", "가장 오래 산 이"], ["fame", "가장 이름난 이"]]
			var cols3 := 4 if wide() else 2
			var cw3 := (r.size.x - 40 - (cols3 - 1) * 12) / cols3
			for ci in cats.size():
				var cx := r.position.x + 20 + (ci % cols3) * (cw3 + 12)
				var cy := r.position.y + 16 + (ci / cols3) * ((r.size.y - 20) / (4 / cols3))
				GhArt.text(self, Vector2(cx, cy), String(cats[ci][1]), 20.0, GhD.RED)
				var arr: Array = GhSv.hall.get(cats[ci][0], [])
				if arr.is_empty():
					GhArt.text(self, Vector2(cx, cy + 34), "아직 없다", 17.0, GhD.DIM)
				for j in arr.size():
					var e: Dictionary = arr[j]
					var ey := cy + 34 + j * 70
					GhArt.text(self, Vector2(cx, ey), "%d. %s  %s" % [j + 1, e.name, e.label], 18.0, GhD.INK)
					GhArt.text(self, Vector2(cx + 18, ey + 24), String(e.house), 14.0, GhD.DIM)
					GhArt.text(self, Vector2(cx + 18, ey + 42), String(e.title), 14.0, Color8(150, 90, 20))
		3:
			_draw_job_book(r)


## 직업 도감 — 직업마다 조건(GhD.job_need_text) · 벌이 · 단 · 차릴 수 있는 사업. 휠로 넘긴다.
## 조건 글은 표(JOB_NEED)에서 만들고, 화면 밖 칸은 그리지 않는다(_draw 에는 클리핑이 없다).
func _draw_job_book(r: Rect2) -> void:
	GhArt.text(self, r.position + Vector2(20, 12), "직업은 열넷부터, 한 해에 한 번 바꾼다. 관직에는 사업이 없다. (휠로 넘기기)", 18.0, GhD.RED)
	var jobs: Array = JOB_LIST.slice(1)
	var cols := 2 if wide() else 1
	var cw := (r.size.x - 40 - (cols - 1) * 14) / cols
	var rh := 74.0
	var top := r.position.y + 44
	var rows := ceili(jobs.size() / float(cols))
	book_scroll = clampf(book_scroll, 0.0, maxf(0.0, rows * rh - (r.end.y - top - 10)))
	for i in jobs.size():
		var j: String = jobs[i]
		var cr := Rect2(r.position.x + 20 + (i % cols) * (cw + 14), top + (i / cols) * rh - book_scroll, cw, rh - 8)
		if cr.position.y < top - 2 or cr.end.y > r.end.y - 4:
			continue
		G2.panel(self, cr, GhD.PAPER_D, Color(GhD.INK, 0.4), 1.0, 6)
		var info: Dictionary = GhD.JOBS[j]
		var head := "%s   해마다 %d냥" % [info.name, int(info.inc)]
		if GhD.JOB_BIZ.has(j):
			head += "   사업: " + String(GhD.JOB_BIZ[j].name)
		GhArt.text(self, cr.position + Vector2(10, 3), head, 19.0, GhD.INK)
		GhArt.text(self, cr.position + Vector2(10, 27), "조건: " + GhD.job_need_text(j), 14.0, Color8(150, 60, 40))
		if GhD.JOB_RANKS.has(j):
			GhArt.text(self, cr.position + Vector2(10, 46), "단: " + " > ".join(GhD.JOB_RANKS[j].ranks), 14.0, GhD.DIM)


func _wealth_word(i: int) -> String:
	return ["빈한", "보통", "넉넉", "부유", "거부"][clampi(i, 0, 4)]
