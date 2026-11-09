extends Node2D
## 잿빛 요새의 용병단 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기.
##
## 규칙은 전부 [AkGame](몬스터 AI 포함), 영웅 봇은 [AkAi] 에 있고 여기는 **보여 주고 클릭을 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 야영지(CAMP — 시나리오 · 영웅 둘 고르기) → 전투(PLAY) → 결과 창.
## 전투(1280×720, 데스크톱 전용): 가운데 헥스 지도 · 왼쪽 영웅 둘 · 오른쪽 라운드 · 원소 · 몬스터 행동 카드 · 아래 안내와 단추.
## 카드 고르기는 판 위에 겹치는 창, 위 행동 고르기는 아래 두 장, 대상 · 자리 고르기는 지도에서 빛나는 칸.
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.** 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua).

enum Scr { TITLE, CAMP, PLAY }

const HEX := 31.0
const STEP_T := 0.32           ## 자동 진행(몬스터 차례 · 영웅의 고를 것 없는 단계) 간격

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: AkGame = null
var pick_scen := 0
var pick_heroes: Array = [0, 1]
var sel: Array = []            ## 카드 고르기 창에서 고른 손패 번호(첫째 = 선도)
var adv_t := 0.0
var pops: Array = []
var log_lines: Array = []
var modal := ""
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var mouse := Vector2(-999, -999)
var book := UiBook.new()
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var ak_auto := false
var ak_seed := -1
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


func _ready() -> void:
	Bgm.use("ashkeep")
	AkSnd.init(Hub.host(self))
	AkSv.load_()
	pick_scen = mini(AkSv.cleared, AkD.SCENARIOS.size() - 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--ak-auto":
			ak_auto = true
		elif a == "--ak-click-test":
			click_test = true
		elif a.begins_with("--ak-seed="):
			ak_seed = int(a.substr(10))
		elif a.begins_with("--ak-scen="):
			pick_scen = clampi(int(a.substr(10)) - 1, 0, AkD.SCENARIOS.size() - 1)
		elif a.begins_with("--menu="):
			_menu.call_deferred(int(a.substr(7)))
	no_save = not OS.get_cmdline_user_args().is_empty()
	if ak_auto:
		_start.call_deferred()


func _start() -> void:
	var lv := []
	for h in pick_heroes:
		lv.append(AkSv.level(int(h)))
	g = AkGame.new(pick_scen, pick_heroes, AkSv.diff, lv, ak_seed)
	scr = Scr.PLAY
	sel = []
	pops = []
	log_lines = []
	end_open = false
	end_t = 0.0
	saved = false
	adv_t = 0.0
	_take_events()
	AkSnd.play("card")


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.2)
	var hot := false
	if scr == Scr.PLAY and g != null:
		hot = not g.over and g.alive_heroes().any(func(u): return int(u.hp) <= 3)
		if g.over:
			if not end_open:
				end_t += dt
				if end_t > 1.0:
					_open_end()
		elif ak_auto or g.pending == "":
			adv_t += dt
			if adv_t >= (0.08 if ak_auto else STEP_T):
				adv_t = 0.0
				if ak_auto:
					AkAi.act(g)
				else:
					g.advance()
				_take_events()
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


## 규칙이 남긴 일(맞음 · 처치 · 등장 · 원소) → 떠오르는 글 · 소리 · 기록 줄.
func _take_events() -> void:
	for e: Dictionary in g.events:
		var col := Color(1, 1, 1)
		match String(e.kind):
			"hit":
				col = Color8(255, 110, 90) if not e.get("crit", false) else Color8(255, 220, 90)
				AkSnd.play("drum", 1.2)
			"kill":
				col = Color8(255, 200, 120)
				AkSnd.play("build")
			"heal":
				col = Color8(120, 240, 120)
				AkSnd.play("sci")
			"spawn":
				col = Color8(240, 160, 120)
			"elem":
				col = Color8(250, 230, 150)
			"exhaust":
				col = Color8(255, 80, 80)
				AkSnd.play("lose")
		if e.has("pos"):
			pops.append({p = _cell_pos(e.pos), txt = String(e.txt), col = col, t = 0.0})
		log_lines.append(String(e.txt))
	g.events.clear()
	while log_lines.size() > 6:
		log_lines.pop_front()


func _open_end() -> void:
	end_open = true
	if not saved and not no_save:
		AkSv.add(g, pick_heroes)
	saved = true
	AkSnd.play("win" if g.win else "lose")

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


func _map_center() -> Vector2:
	return Vector2(vs.x * 0.5, 292)


func _cell_pos(c: Vector2i) -> Vector2:
	# 지도 가운데 맞추기 — 시나리오 지도 폭의 절반만큼 왼쪽으로
	var w := 0
	if g != null:
		for row in AkD.SCENARIOS[g.scen][2]:
			w = maxi(w, String(row).length())
	var off := Vector2((w - 0.5) * HEX * sqrt(3.0) * 0.5, 3.0 * HEX * 1.5)
	return _map_center() - off + Vector2(HEX * sqrt(3.0) * (c.x + c.y * 0.5), HEX * 1.5 * c.y)


func _cell_at(p: Vector2) -> Vector2i:
	for c in g.cells:
		if _cell_pos(c).distance_to(p) < HEX * 0.86:
			return c
	return Vector2i(999, 999)


func _hero_rect(i: int) -> Rect2:
	return Rect2(14, 84 + i * 312, 290, 300)


func _side_rect() -> Rect2:
	return Rect2(vs.x - 304, 84, 290, vs.y - 96)


func _bar_rect() -> Rect2:
	return Rect2(318, 520, vs.x - 318 * 2, 186)


## 위 행동 고르기 — 아래 두 장(k).
func _first_rect(k: int) -> Rect2:
	var br := _bar_rect()
	var w := 280.0
	return Rect2(br.get_center().x - w - 8 + k * (w + 16), br.position.y + 4, w, 178)


func _skip_btn() -> Rect2:
	var br := _bar_rect()
	return Rect2(br.end.x - 200, br.end.y - 60, 190, 52)


## 카드 고르기 창.
func _hand_rect(i: int) -> Rect2:
	var per := 6
	var w := 196.0
	var h := 214.0
	var x0 := vs.x * 0.5 - (per * (w + 8) - 8) * 0.5
	return Rect2(x0 + (i % per) * (w + 8), 120 + int(i / per) * (h + 8), w, h)


func _sel_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 330 + k * 340, vs.y - 84, 320, 60)


## 야영지: 시나리오 줄 · 영웅 칸 · 출발.
func _scen_rect(k: int) -> Rect2:
	return Rect2(40, 100 + k * 56, 520, 50)


func _camp_hero(k: int) -> Rect2:
	return Rect2(600 + (k % 2) * 330, 110 + int(k / 2) * 230, 316, 216)


func _modal_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 30, 190, 60)


func _end_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 150, 190, 60)

# ==================== 입력 ====================


func _unhandled_input(ev: InputEvent) -> void:
	if Vol.open:
		Vol.handle(ev, vs)
		return
	if ev is InputEventMouseMotion:
		mouse = ev.position
		return
	var key := ev as InputEventKey
	if key != null and key.pressed and not key.echo:
		if book.key(key.keycode):
			return
		match key.keycode:
			KEY_ESCAPE:
				_escape()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if scr == Scr.TITLE:
					scr = Scr.CAMP
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		mouse = mb.position
		_click(mb.position)


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.CAMP:
			scr = Scr.TITLE
		Scr.PLAY:
			modal = "" if modal != "" else "quit"


## 처음 화면 메뉴 — 0 난이도 · 1 영웅 도감(카드) · 2 몬스터 도감 · 3 기록.
func _menu(j: int) -> void:
	book.game = "ashkeep"
	match j:
		0:
			AkSv.diff = (AkSv.diff + 2) % 3 - 1
			if not no_save:
				AkSv.save_()
		1:
			var items := [{name = "규칙", desc = "\n".join(RULES), draw = func(ci, r, tt):
					AkArt.elem(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.25, 0, 2)}]
			for h in AkD.HEROES.size():
				var row: Array = AkD.HEROES[h]
				var hh := h
				items.append({name = String(row[0]), desc = "체력 %d, 손패 %d\n%s\n레벨 %d" % [int(row[1]) + AkD.HERO_HP_BONUS, int(row[2]), String(row[4]), AkSv.level(h)],
						draw = func(ci, r, tt):
							AkArt.token(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.4, {side = "hero", k = hh, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(row[0]), row[3], tt)})
				for k in AkD.CARDS[h].size():
					var c := AkD.card(h, k)
					items.append({name = String(c.name), desc = "%s, 순서 %d\n위: %s\n아래: %s" % [String(row[0]), int(c.init), AkD.half_text(c.top, c.top_lost), AkD.half_text(c.bot, c.bot_lost)],
							draw = func(ci, r, tt):
								AkArt.card(ci, Rect2(r.get_center() - Vector2(84, 70), Vector2(168, 140)), c)})
			book.show("영웅 도감", items, "grid", 4, 2)
		2:
			var items2 := []
			for m in AkD.MONSTERS.size():
				var st := AkD.mon_stats(m, false, 0)
				var mm := m
				var extra := []
				if int(st.shield) > 0:
					extra.append("방어 %d" % int(st.shield))
				if int(st.ret) > 0:
					extra.append("반격 %d" % int(st.ret))
				if bool(st.fly):
					extra.append("날기")
				items2.append({name = String(st.name), desc = "체력 %d, 이동 %d, 공격 %d%s\n%s" % [int(st.hp), int(st.move), int(st.atk),
						", 사거리 %d" % int(st.rng) if int(st.rng) > 0 else "", ", ".join(extra)],
						draw = func(ci, r, tt):
							AkArt.token(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.4, {side = "mon", k = mm, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(st.name), st.col, tt)})
			book.show("몬스터 도감", items2, "grid", 4, 2)
		3:
			var rows := [{main = "진척", sub = "시나리오 %d / %d 깸" % [AkSv.cleared, AkD.SCENARIOS.size()]},
					{main = "판", sub = "%d판 %d승" % [AkSv.plays, AkSv.wins]}]
			for h in 4:
				rows.append({main = String(AkD.HEROES[h][0]), sub = "레벨 %d, 경험 %d" % [AkSv.level(h), int(AkSv.xp[h])]})
			book.show("기록", rows, "list")


func _click(p: Vector2) -> void:
	if book.click(p, vs):
		return
	match scr:
		Scr.TITLE:
			if _back_btn().has_point(p):
				Hub.leave(self)
				return
			if _vol_btn().has_point(p):
				Vol.open = true
				return
			for j in 4:
				if UiKit.menu_rect(vs, j).has_point(p):
					AkSnd.play("tick")
					_menu(j)
					return
			if Hub.std_rect("start", vs).has_point(p):
				scr = Scr.CAMP
				AkSnd.play("tick")
		Scr.CAMP:
			if _back_btn().has_point(p):
				scr = Scr.TITLE
				return
			for k in AkD.SCENARIOS.size():
				if _scen_rect(k).has_point(p) and k <= AkSv.cleared:
					pick_scen = k
					AkSnd.play("tick")
					return
			for k in 4:
				if _camp_hero(k).has_point(p):
					if k in pick_heroes:
						return
					pick_heroes = [pick_heroes[1], k]
					AkSnd.play("tick")
					return
			if Hub.std_rect("start", vs).has_point(p):
				_start()
		Scr.PLAY:
			_click_play(p)


func _click_play(p: Vector2) -> void:
	if end_open:
		if _end_btn(0).has_point(p):
			_start()
		elif _end_btn(1).has_point(p):
			scr = Scr.CAMP
			pick_scen = mini(AkSv.cleared, AkD.SCENARIOS.size() - 1)
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.CAMP
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if _vol_btn().has_point(p):
		Vol.open = true
		return
	if g.over or ak_auto:
		return
	match g.pending:
		"select":
			var h: Dictionary = g.heroes[g.pend_h]
			for i in h.hand.size():
				if _hand_rect(i).has_point(p) and not g.must_rest(g.pend_h):
					if i in sel:
						sel.erase(i)
					elif sel.size() < 2:
						sel.append(i)
					AkSnd.play("tick")
					return
			if _sel_btn(0).has_point(p) and sel.size() == 2:
				if g.select_cards(g.pend_h, sel[0], sel[1]):
					sel = []
					AkSnd.play("card")
			elif _sel_btn(1).has_point(p) and g.can_long_rest(g.pend_h):
				if g.long_rest(g.pend_h):
					sel = []
					AkSnd.play("card")
		"first":
			for k in 2:
				var r := _first_rect(k)
				if r.has_point(p):
					# 카드의 위쪽 절반을 누르면 그 카드의 위 행동, 아래쪽이면 그 카드의 아래 행동(= 다른 카드의 위)
					var top := p.y < r.get_center().y + 17
					g.choose_top(k if top else 1 - k)
					AkSnd.play("tick")
					return
		"step":
			if _skip_btn().has_point(p):
				g.skip()
				return
			var c := _cell_at(p)
			if c.x != 999 and g.choose(c):
				_take_events()

# ==================== 그리기 ====================


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(22, 20, 24))
	var bg := AkArt.img("ak_bg_board" if scr == Scr.PLAY else "ak_bg_title")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, 0.5 if scr == Scr.PLAY else 0.36))   # 처음 화면은 더 눌러야 글자가 읽힌다
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.CAMP:
			_draw_camp()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _btn(r: Rect2, label: String, fill: Color, size: float = 24.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "ashkeep", t, on, size)


func _draw_title() -> void:
	var lx := vs.x * 0.3
	var below := UiKit.title(self, vs, "ashkeep", "잿빛 요새의 용병단", "카드 두 장으로 싸우는 용병들의 던전", t)
	for k in 4:
		var row: Array = AkD.HEROES[k]
		AkArt.token(self, Vector2(lx - 165 + k * 110, below + 90), 52,
				{side = "hero", k = k, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(row[0]), row[3], t)
	var labels := ["난이도: %s" % ["쉬움", "보통", "어려움"][AkSv.diff + 1], "영웅 도감", "몬스터 도감", "기록"]
	for j in 4:
		UiKit.menu(self, UiKit.menu_rect(vs, j), labels[j], AkArt.STONE, "ashkeep", t)
	if AkSv.cleared > 0:   # 하나도 안 깼으면 "0 / 10" 을 보이지 않는다(#37)
		UiKit.record_line(self, vs, "시나리오 %d / %d 깸" % [AkSv.cleared, AkD.SCENARIOS.size()])
	UiKit.button(self, vs, "start", "ashkeep", t)
	UiKit.button(self, vs, "hub", "ashkeep", t)
	UiKit.button(self, vs, "vol", "ashkeep", t)
	book.draw(self, vs, t)


const RULES := [
	"라운드마다 영웅 하나에 카드 두 장. 첫째 카드의 순서 숫자가 그 영웅의 순서다.",
	"차례에는 한 장의 위 행동과 다른 한 장의 아래 행동을 쓴다.",
	"쓴 카드는 버린 더미로, 소멸 표시가 있는 행동을 쓴 카드는 잃은 더미로 간다.",
	"손패가 모자라면 쉰다. 긴 휴식은 한 라운드를 쉬고 버린 카드 하나를 잃고 체력 2를 되찾는다.",
	"손패를 다 잃거나 체력이 0이 되면 쓰러진다. 둘 다 쓰러지면 실패다.",
	"몬스터는 가장 적게 걸어서 칠 수 있는 영웅을 노린다.",
	"원소는 불어넣은 다음 차례부터 쓸 수 있고, 라운드마다 약해진다.",
	"문에 올라서면 다음 방이 열리고 몬스터가 나타난다.",
]


func _draw_camp() -> void:
	G2.text_mid(self, Vector2(300, 74), "시나리오", 28, AkArt.HEAD, 5)
	for k in AkD.SCENARIOS.size():
		var r := _scen_rect(k)
		var open := k <= AkSv.cleared
		var row: Array = AkD.SCENARIOS[k]
		var goal_txt: String = {all = "모두 처치", boss = "보스 처치", seal = "봉인석 부수기", survive = "버티기"}.get(String(row[1]), "")
		AkArt.rr(self, r, 10, Color8(60, 50, 52) if open else Color8(36, 32, 36), Color(1, 1, 1) if k == pick_scen else Color(1, 1, 1, 0.15), 3.0 if k == pick_scen else 1.5)
		var best := ""
		if AkSv.best_clear.has(str(k)):
			best = "  %d라운드에 깸" % int(AkSv.best_clear[str(k)])
		draw_string(UiKit.font(), r.position + Vector2(14, 33), "%d. %s" % [k + 1, String(row[0])] if open else "%d. 잠김" % (k + 1),
				HORIZONTAL_ALIGNMENT_LEFT, 260, 22, Color(1, 1, 1) if open else Color(1, 1, 1, 0.4))
		if open:
			draw_string(UiKit.font(), r.position + Vector2(280, 33), goal_txt + best, HORIZONTAL_ALIGNMENT_LEFT, 230, 20, Color(1, 1, 1, 0.7))
	G2.text_mid(self, Vector2(930, 74), "영웅 둘", 28, AkArt.HEAD, 5)
	for k in 4:
		var r2 := _camp_hero(k)
		var row2: Array = AkD.HEROES[k]
		var on := k in pick_heroes
		AkArt.rr(self, r2, 14, Color8(50, 44, 48), Color(1, 1, 1) if on else Color(1, 1, 1, 0.15), 3.0 if on else 1.5)
		AkArt.token(self, r2.position + Vector2(60, 70), 40, {side = "hero", k = k, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(row2[0]), row2[3], t)
		draw_string(UiKit.font(), r2.position + Vector2(118, 50), String(row2[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1))
		draw_string(UiKit.font(), r2.position + Vector2(118, 82), "레벨 %d, 경험 %d" % [AkSv.level(k), int(AkSv.xp[k])], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
		var lines := UiBook.wrap_text(String(row2[4]), 20, r2.size.x - 28)
		for j in lines.size():
			draw_string(UiKit.font(), r2.position + Vector2(14, 140 + j * 24), String(lines[j]), HORIZONTAL_ALIGNMENT_LEFT, r2.size.x - 28, 20, Color(1, 1, 1, 0.85))
	UiKit.button(self, vs, "start", "ashkeep", t, "출발")
	UiKit.button(self, vs, "hub", "ashkeep", t, "뒤로")


func _draw_play() -> void:
	_draw_map()
	for i in g.heroes.size():
		_draw_hero(i)
	_draw_side()
	_draw_bar()
	for p: Dictionary in pops:
		var k := float(p.t) / 1.2
		var a := 1.0 - k * k
		var pp: Vector2 = p.p + Vector2(0, -26 - 28 * k)
		var tw := UiKit.font().get_string_size(String(p.txt), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 16
		AkArt.rr(self, Rect2(pp - Vector2(tw * 0.5, 15), Vector2(tw, 30)), 10, Color(0, 0, 0, 0.7 * a))
		G2.text_mid(self, pp, String(p.txt), 22, Color(p.col, a), 3)
	if g.pending == "select" and not g.over and not ak_auto:
		_draw_select()
	UiKit.button(self, vs, "hub", "ashkeep", t, "나가기")
	UiKit.button(self, vs, "vol", "ashkeep", t)
	if modal == "quit":
		_draw_modal("시나리오를 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()


func _draw_map() -> void:
	var hl := []
	if g.pending == "step" and not ak_auto:
		hl = g.options
	for c in g.cells:
		var info: Dictionary = g.cells[c]
		var kind := "floor"
		if info.obs:
			kind = "obs"
		elif info.door:
			kind = "door"
		elif not g.revealed.has(info.room):
			kind = "dark"
		AkArt.cell(self, _cell_pos(c), HEX, kind, info.trap and kind != "dark", c in hl, t)
	var active_id := -1
	if g.hero_on >= 0:
		active_id = int(g.heroes[g.hero_on].unit.id)
	for u: Dictionary in g.units:
		if not u.alive:
			continue
		var name := ""
		var col := Color.WHITE
		if u.side == "hero":
			name = String(AkD.HEROES[int(u.k)][0])
			col = AkD.HEROES[int(u.k)][3]
		else:
			var st := g.mon_stat(u)
			# 말에는 마지막 낱말의 첫 글자(재바람 추종자 → 추) — 첫 글자면 재 마녀와 겹쳤다
			name = String(st.name).split(" ")[-1]
			col = st.col
		AkArt.token(self, _cell_pos(u.pos), HEX, u, name, col, t, int(u.id) == active_id)


func _draw_hero(i: int) -> void:
	var r := _hero_rect(i)
	var h: Dictionary = g.heroes[i]
	var u: Dictionary = h.unit
	var row: Array = AkD.HEROES[int(h.kind)]
	var on := g.hero_on == i or (g.pending == "select" and g.pend_h == i)
	# 반투명 둥근 판 대신 돌판 한 장 — 지금 움직이는 영웅은 왼쪽 띠(#32)
	draw_rect(r, Color(AkArt.STONE.darkened(0.45), 0.96))
	draw_rect(Rect2(r.position, Vector2(6.0 if on else 3.0, r.size.y)), row[3] if on else Color(1, 1, 1, 0.14))
	draw_string(UiKit.font(), r.position + Vector2(14, 34), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, row[3])
	if h.exh:
		G2.text_mid(self, r.get_center(), "쓰러짐", 30, Color8(240, 90, 80), 4)
		return
	var bar := Rect2(r.position + Vector2(14, 50), Vector2(r.size.x - 28, 18))
	draw_rect(bar, Color8(60, 30, 30))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(u.hp) / float(u.max), bar.size.y)), Color8(150, 60, 40))
	G2.text_mid(self, bar.get_center(), "체력 %d / %d" % [int(u.hp), int(u.max)], 20, Color(1, 1, 1), 3)
	draw_string(UiKit.font(), r.position + Vector2(14, 100), "손패 %d  버림 %d  잃음 %d" % [h.hand.size(), h.disc.size(), h.lost.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
	var sts := []
	for k in u.st:
		sts.append(String(AkD.STATUS.get(k, k)))
	if int(u.s) > 0:
		sts.append("방어 %d" % int(u.s))
	if int(u.ret) > 0:
		sts.append("반격 %d" % int(u.ret))
	draw_string(UiKit.font(), r.position + Vector2(14, 130), ", ".join(sts), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 20, Color(1, 1, 1, 0.7))
	if h.rest:
		draw_string(UiKit.font(), r.position + Vector2(14, 170), "이번 라운드: 긴 휴식", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color8(180, 200, 255))
	elif h.pick.size() == 2:
		for k in 2:
			var c: Dictionary = h.pick[k]
			draw_string(UiKit.font(), r.position + Vector2(14, 170 + k * 28), "%s %d  %s" % ["선도" if k == 0 else "둘째", int(c.init), String(c.name)], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 20, Color(1, 1, 1, 0.9))
	draw_string(UiKit.font(), r.position + Vector2(14, r.size.y - 18), "경험 +%d" % int(h.xp), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))


func _draw_side() -> void:
	var r := _side_rect()
	draw_rect(r, Color(AkArt.STONE.darkened(0.45), 0.96))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color(1, 1, 1, 0.14))
	var row: Array = AkD.SCENARIOS[g.scen]
	G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 24), String(row[0]), 24, AkArt.HEAD, 4)
	var goal_txt: String = {all = "모두 처치", boss = "보스 처치", seal = "봉인석 부수기", survive = "%d라운드 버티기" % g.rounds_goal}.get(g.goal, "")
	G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 52), "라운드 %d, %s" % [g.round_no, goal_txt], 20, Color(1, 1, 1, 0.8), 0)
	for e in 4:
		AkArt.elem(self, r.position + Vector2(40 + e * 70, 96), 26, e, int(g.elems[e]))
	# 몬스터 종류마다 — 남은 수와 이번 라운드 행동
	var y := r.position.y + 140
	var types := {}
	for u: Dictionary in g.alive_mons():
		types[int(u.k)] = int(types.get(int(u.k), 0)) + 1
	for m in types:
		if y > r.end.y - 50:
			break
		var st := AkD.mon_stats(int(m), false, g.lv)
		draw_string(UiKit.font(), Vector2(r.position.x + 14, y), "%s %d" % [String(st.name), int(types[m])], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 20, st.col.lightened(0.3))
		var d: Dictionary = g.mdeck.get(m, {})
		if d.has("cur") and not d.cur.is_empty() and g.pending != "select":
			var cur: Dictionary = d.cur
			var mv := maxi(0, int(st.move) + int(cur.dm))
			var atk := maxi(1, int(st.atk) + int(cur.da))
			var txt := "순서 %d, 이동 %d, 공격 %d" % [int(cur.init), mv, atk]
			if cur.extra.has("aoe"):
				txt += ", 이웃 전부"
			if cur.extra.has("heal"):
				txt += ", 회복"
			draw_string(UiKit.font(), Vector2(r.position.x + 14, y + 26), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 20, Color(1, 1, 1, 0.75))
			y += 60
		else:
			y += 34


func _draw_bar() -> void:
	var br := _bar_rect()
	AkArt.rr(self, br, 14, Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.12), 1.5)
	if g.over:
		return
	match g.pending:
		"first":
			G2.text_mid(self, Vector2(br.get_center().x, br.position.y - 14), "위 행동으로 쓸 쪽", 20, AkArt.HEAD, 4)
			var h: Dictionary = g.heroes[g.pend_h]
			for k in 2:
				var r := _first_rect(k)
				var hov := -1
				if r.has_point(mouse):
					hov = 0 if mouse.y < r.get_center().y + 17 else 1
				AkArt.card(self, r, h.pick[k], 0, false, hov)
		"step":
			var s: Dictionary = g.step_now
			var what := AkD.step_text(s)
			var ask := "자리" if s.has("m") else ("대상" if s.has("a") else "동료")
			G2.text_mid(self, br.get_center() + Vector2(-110, -10), "%s: %s" % [what, ask], 24, AkArt.HEAD, 4)
			_btn(_skip_btn(), "건너뛰기", AkArt.STONE, 22)
		_:
			for k in log_lines.size():
				G2.text_mid(self, Vector2(br.get_center().x, br.position.y + 24 + k * 27), String(log_lines[k]), 20, Color(1, 1, 1, 0.45 + 0.1 * k), 0)


func _draw_select() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72))
	var h: Dictionary = g.heroes[g.pend_h]
	var name: String = AkD.HEROES[int(h.kind)][0]
	var msg := "%s: 카드 두 장 (첫 장이 순서를 정한다)" % name
	if g.must_rest(g.pend_h):
		msg = "%s: 손패가 모자라다. 긴 휴식" % name
	G2.text_mid(self, Vector2(vs.x * 0.5, 96), msg, 26, AkArt.HEAD, 5)
	for i in h.hand.size():
		var k := sel.find(i)
		AkArt.card(self, _hand_rect(i), h.hand[i], k + 1 if k >= 0 else 0)
	_btn(_sel_btn(0), "확정", UiKit.theme("ashkeep").start, 26, sel.size() == 2)
	_btn(_sel_btn(1), "긴 휴식 (버린 카드 %d장)" % h.disc.size(), AkArt.STONE, 24, g.can_long_rest(g.pend_h))


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	var r := Rect2(c.x - 250, c.y - 90, 500, 200)
	AkArt.rr(self, r, 22, Color8(44, 38, 42), AkArt.EMBER, 4.0)
	G2.text_mid(self, Vector2(c.x, c.y - 30), q, 26, Color(1, 1, 1), 5)
	for k in labels.size():
		_btn(_modal_btn(k), String(labels[k]), AkArt.STONE if k == 0 else UiKit.theme("ashkeep").start, 26)


func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var r := Rect2(c.x - 300, c.y - 220, 600, 450)
	AkArt.rr(self, r, 26, Color8(44, 38, 42), AkArt.EMBER, 4.0)
	G2.text_mid(self, Vector2(c.x, r.position.y + 56), "시나리오 성공" if g.win else "시나리오 실패", 48, AkArt.HEAD, 8)
	G2.text_mid(self, Vector2(c.x, r.position.y + 106), "%d라운드" % g.round_no, 24, Color(1, 1, 1, 0.7), 0)
	for i in g.heroes.size():
		var h: Dictionary = g.heroes[i]
		var gain := int(h.xp) + (3 if g.win else 1)
		G2.text_mid(self, Vector2(c.x, r.position.y + 160 + i * 40), "%s  경험 +%d" % [AkD.HEROES[int(h.kind)][0], gain], 24, AkD.HEROES[int(h.kind)][3], 3)
	_btn(_end_btn(0), "다시 하기", UiKit.theme("ashkeep").start, 26)
	_btn(_end_btn(1), "야영지로", AkArt.STONE, 26)

# ==================== 확인용 ====================


## `--ak-click-test` — 처음 → 야영지 → 출발 → 카드 두 장 고르기(두 영웅) → 위 행동 고르기 → 단계는 건너뛰기 → 나가기 를
## **진짜 마우스 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.CAMP, "야영지", false],
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY, "출발", false],
		[func():
			if g.pending == "select":
				if sel.size() < 2:
					_press(_hand_rect(sel.size()).get_center())
				else:
					_press(_sel_btn(0).get_center()),
			func(): return g.pending != "select", "카드 고르기", true],
		[func(): pass, func(): return g.pending == "first", "첫 영웅 차례", false],
		[func(): _press(_first_rect(0).position + Vector2(140, 60)), func(): return g.pending != "first", "위 행동 고르기", false],
		[func():
			if g.pending == "step":
				_press(_skip_btn().get_center())
			elif g.pending == "first":
				_press(_first_rect(0).position + Vector2(140, 60)),
			func(): return g.pending == "select" or g.round_no >= 2, "라운드 끝까지", true],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "나가기 창", false],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.CAMP, "그만두기", false],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("AK CLICK TEST OK")
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
	if bool(steps[i][3]):
		steps[i][0].call()
	_wait += 0.3
	if _wait < 30.0:
		return
	printerr("AK CLICK TEST FAIL: %s" % steps[i][2])
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
