extends Node2D
## 붉은 별 개척단 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기.
##
## 규칙은 전부 [RsGame], 상대 수는 [RsAi] 에 있고 여기는 **보여 주고 클릭을 행동으로 바꾸기만** 합니다.
## 가로 1280×720 만 짭니다(데스크톱 전용, ADR-0012): 위 지표 막대 · 가운데 헥스 지도 · 아래 행동 단추와 손패 · 왼쪽 나 · 오른쪽 상대.
## 겹쳐 뜨는 창(`view`): 카드 자세히 · 기본 사업 · 운영 행동 · 목표와 후원 · 도시 보기. 고르는 단계(`pending`): 기업 · 연구 · 타일 놓기.
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.** 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua).

enum Scr { TITLE, PLAY }

const AI_DELAY := 0.9
const HEX := 30.0
const HAND := Vector2(104, 160)
const PER_HAND := 5

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: RsGame = null
var level := 1
var view := ""                 ## "" · "card" · "std" · "acts" · "goals" · "city0" · "city1"
var sel_card := -1             ## 자세히 보는 손패 번호
var picks: Array = []          ## 기업 · 연구 창에서 고른 카드 번호
var pick_corp := -1
var hand_page := 0
var ai_t := 0.0
var pops: Array = []
var toast := ""
var toast_t := 0.0
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
var rs_auto := false
var rs_seed := -1
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


func _ready() -> void:
	Bgm.use("redstar")
	RsSnd.init(Hub.host(self))
	RsSv.load_()
	level = RsSv.level
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--rs-auto":
			rs_auto = true
		elif a == "--rs-click-test":
			click_test = true
		elif a.begins_with("--rs-seed="):
			rs_seed = int(a.substr(10))
		elif a.begins_with("--rs-level="):
			level = clampi(int(a.substr(11)), 0, 2)
		elif a.begins_with("--menu="):
			_menu.call_deferred(int(a.substr(7)))
	no_save = not OS.get_cmdline_user_args().is_empty()
	if rs_auto:
		_start.call_deferred()


func _start() -> void:
	g = RsGame.new(rs_seed, [rs_auto, true])
	scr = Scr.PLAY
	view = ""
	picks = []
	pick_corp = -1
	pops = []
	end_open = false
	end_t = 0.0
	saved = false
	ai_t = 0.0
	hand_page = 0
	toast = "기업을 고르고 처음 카드를 사세요" if not rs_auto else ""
	toast_t = 4.0
	if not no_save:
		RsSv.level = level
		RsSv.save_()
	RsSnd.play("card")


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	toast_t = maxf(0.0, toast_t - dt)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.4)
	var hot := false
	if scr == Scr.PLAY and g != null:
		hot = not g.over and g.steps_left() <= 4
		if g.over:
			if not end_open:
				end_t += dt
				if end_t > 1.0:
					_open_end()
		elif _ai_waiting():
			ai_t += dt
			if ai_t >= (0.15 if rs_auto else AI_DELAY):
				ai_t = 0.0
				RsAi.act(g, level)
				_after_action()
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


func _ai_waiting() -> bool:
	if g == null or g.over:
		return false
	if g.pending != "":
		return bool(g.players[g.pend_p].ai)
	return bool(g.players[g.cur].ai)


func _my_turn() -> bool:
	return g != null and g.can_act(0) and not bool(g.players[0].ai) and modal == "" and not end_open


func _human_pending() -> bool:
	return g != null and not g.over and g.pending != "" and not bool(g.players[g.pend_p].ai) and modal == ""


func _after_action() -> void:
	var l := g.last
	var p: int = l.get("p", 0)
	var at := Vector2(370 if p == 0 else vs.x - 370, 140)   # 지도 옆 빈자리 — 판의 점수 글자를 가리지 않게
	match String(l.get("kind", "")):
		"card":
			RsSnd.play("build")
			pops.append({p = at, txt = String(l.card.name), col = Color8(255, 236, 190), t = 0.0})
		"std", "heat", "act":
			RsSnd.play("sci")
		"place", "green":
			RsSnd.play("drum")
		"milestone", "award":
			RsSnd.play("wonder")
		"research", "corp":
			RsSnd.play("card")
	if not g.events.is_empty():
		var e: Dictionary = g.events[-1]
		toast = "%s: %s" % [RsD.PLAYER_NAMES[int(e.p)], String(e.txt)]
		toast_t = 3.0
		g.events.clear()
	if g.over:
		end_t = 0.0
	if hand_page * PER_HAND >= g.players[0].hand.size():
		hand_page = 0


func _open_end() -> void:
	end_open = true
	if not saved and not no_save and not bool(g.players[0].ai):
		RsSv.add(g, level)
	saved = true
	RsSnd.play("win" if g.winner == 0 else "lose")

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


## 0 나(왼쪽) · 1 상대(오른쪽).
func _panel_rect(p: int) -> Rect2:
	return Rect2(14 if p == 0 else vs.x - 290, 84, 276, vs.y - 96)


func _param_rect(k: int) -> Rect2:
	var w := (vs.x - 608 - 24) / 3.0
	return Rect2(304 + k * (w + 12), 18, w, 52)


func _map_center() -> Vector2:
	return Vector2(vs.x * 0.5, 288)


func _cell_pos(c: Vector2i) -> Vector2:
	return _map_center() + Vector2(HEX * sqrt(3.0) * (c.x + c.y * 0.5), HEX * 1.5 * c.y)


func _cell_at(p: Vector2) -> Vector2i:
	for c in RsD.cells():
		if _cell_pos(c).distance_to(p) < HEX * 0.86:
			return c
	return Vector2i(99, 99)


const ACTS := ["기본 사업", "식물로 녹지", "열로 온도", "운영 행동", "목표와 후원", "패스"]


func _act_btn(k: int) -> Rect2:
	var w := (vs.x - 608 - 5 * 6) / 6.0
	return Rect2(304 + k * (w + 6), 474, w, 44)


func _hand_rect(i: int) -> Rect2:
	var n := mini(PER_HAND, g.players[0].hand.size() - hand_page * PER_HAND)
	var gap := 8.0
	var x0 := vs.x * 0.5 - (n * (HAND.x + gap) - gap) * 0.5
	return Rect2(x0 + i * (HAND.x + gap), 530, HAND.x, HAND.y)


func _page_btn(d: int) -> Rect2:
	return Rect2(312 if d < 0 else vs.x - 312 - 40, 580, 40, 60)


## 겹쳐 뜨는 창의 판.
func _view_panel() -> Rect2:
	return Rect2(vs.x * 0.5 - 380, 90, 760, vs.y - 120)


func _view_row(k: int) -> Rect2:
	var vp := _view_panel()
	return Rect2(vp.position.x + 24, vp.position.y + 70 + k * 62, vp.size.x - 48, 54)


func _detail_btn(k: int) -> Rect2:
	var vp := _view_panel()
	return Rect2(vp.position.x + 360 + k * 0, vp.position.y + 120 + k * 70, 340, 58)


## 기업 · 연구 창: 기업 두 칸, 카드 칸, 확정 단추.
func _corp_rect(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 370 + k * 380, 96, 360, 96)


func _offer_rect(i: int, n: int) -> Rect2:
	var per := mini(n, 8)
	var w := 132.0
	var gap := 10.0
	var x0 := vs.x * 0.5 - (per * (w + gap) - gap) * 0.5
	var top := 210.0 if g.pending == "corp" else 170.0
	return Rect2(x0 + (i % per) * (w + gap), top + int(i / per) * 214, w, 204)


func _confirm_btn() -> Rect2:
	return Rect2(vs.x * 0.5 - 170, vs.y - 92, 340, 64)


func _modal_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 30, 190, 60)


func _end_btn(k: int) -> Rect2:
	var c := vs * 0.5
	return Rect2(c.x - 200 + k * 210, c.y + 230, 190, 60)

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
					_start()
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		mouse = mb.position
		_click(mb.position)


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.PLAY:
			if view != "":
				view = ""
			elif modal != "":
				modal = ""
			else:
				modal = "quit"


## 처음 화면 메뉴 — 0 상대 난이도 · 1 카드 도감 · 2 기업 도감(목표 · 후원 포함) · 3 기록.
func _menu(j: int) -> void:
	book.game = "redstar"
	match j:
		0:
			level = (level + 1) % 3
			if not no_save:
				RsSv.level = level
				RsSv.save_()
		1:
			var items := [{name = "규칙", desc = "\n".join(RULES), draw = func(ci, r, tt):
					RsArt.res_icon(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.25, 5)}]
			for c: Dictionary in RsD.all_cards():
				var cc := c
				var tags := []
				for x in c.tags:
					tags.append(RsD.TAG_NAME[int(x)])
				var req := "\n조건: %s" % RsD.req_text(c.req) if not c.req.is_empty() else ""
				items.append({name = String(c.name), desc = "%s, 크레딧 %d, %s%s\n%s" % [RsD.KIND_NAME[c.kind], int(c.cost),
						" ".join(tags), req, RsD.eff_text(c.eff, int(c.pts))],
						draw = func(ci, r, tt):
							var h: float = minf(r.size.y * 0.96, 150.0)
							var w: float = h * HAND.x / HAND.y
							RsArt.card(ci, Rect2(r.get_center() - Vector2(w, h) * 0.5, Vector2(w, h)), cc, 0, tt)})
			book.show("카드 도감", items, "grid", 5, 2)
		2:
			var items2 := []
			for k in RsD.CORPS.size():
				var row: Array = RsD.CORPS[k]
				var col := Color.from_hsv(k / 6.0, 0.5, 0.75)
				items2.append({name = String(row[0]), desc = "기업, 크레딧 %d\n%s" % [int(row[1]), String(row[5])],
						draw = func(ci, r, tt):
							RsArt.rr(ci, r.grow(-10), 12, col, RsArt.INK, 2.0)})
			for k in 3:
				var m: Array = RsD.MILESTONES[k]
				items2.append({name = String(m[0]), desc = "목표: %s\n먼저 채운 쪽이 크레딧 %d 내고 선점, 5점" % [String(m[1]), RsD.MILESTONE_COST],
						draw = func(ci, r, tt): RsArt.res_icon(ci, r.get_center(), 30, 0)})
			for k in 3:
				var a: Array = RsD.AWARDS[k]
				items2.append({name = String(a[0]), desc = "후원: %s\n게임 끝 1위 5점, 2위 2점" % String(a[1]),
						draw = func(ci, r, tt): RsArt.res_icon(ci, r.get_center(), 30, 2)})
			book.show("기업 도감", items2, "grid", 4, 2)
		3:
			var rows := []
			for k in 3:
				var key := str(k)
				var pl := int(RsSv.plays.get(key, 0))
				var w3 := int(RsSv.wins.get(key, 0))
				rows.append({main = "상대 %s" % RsD.AI_LEVEL_NAME[k],
						sub = "%d판 %d승%s" % [pl, w3, "  승률 %d%%" % roundi(100.0 * w3 / pl) if pl > 0 else ""]})
			rows.append({main = "최고 점수", sub = "%d점" % RsSv.best if RsSv.best > 0 else "아직 없음"})
			rows.append({main = "가장 빠른 개조", sub = "%d세대" % RsSv.fastest if RsSv.fastest > 0 else "아직 없음"})
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
					RsSnd.play("tick")
					_menu(j)
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
			scr = Scr.TITLE
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			modal = ""
			scr = Scr.TITLE
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if _vol_btn().has_point(p):
		Vol.open = true
		return
	if view != "":
		_click_view(p)
		return
	if _human_pending():
		_click_pending(p)
		return
	for q in 2:
		if _panel_rect(q).has_point(p):
			view = "city%d" % q
			RsSnd.play("tick")
			return
	for i in mini(PER_HAND, g.players[0].hand.size() - hand_page * PER_HAND):
		if _hand_rect(i).has_point(p):
			sel_card = hand_page * PER_HAND + i
			view = "card"
			RsSnd.play("tick")
			return
	for d in [-1, 1]:
		if _page_btn(d).has_point(p) and g.players[0].hand.size() > PER_HAND:
			var pages := ceili(g.players[0].hand.size() / float(PER_HAND))
			hand_page = posmod(hand_page + d, pages)
			return
	if not _my_turn():
		return
	for k in ACTS.size():
		if _act_btn(k).has_point(p) and _act_enabled(k):
			match k:
				0:
					view = "std"
				1:
					_do(func(): return g.convert_green())
				2:
					_do(func(): return g.convert_heat())
				3:
					view = "acts"
				4:
					view = "goals"
				5:
					_do(func(): return g.pass_turn())
			RsSnd.play("tick")
			return


func _act_enabled(k: int) -> bool:
	match k:
		1:
			return g.can_green(0)
		2:
			return g.can_heat(0)
	return true


func _do(f: Callable) -> void:
	if f.call():
		view = ""
		_after_action()


func _click_view(p: Vector2) -> void:
	match view:
		"card":
			if _my_turn() and sel_card >= 0 and sel_card < g.players[0].hand.size():
				if _detail_btn(0).has_point(p):
					var k := sel_card
					_do(func(): return g.play_card(k))
					return
				if _detail_btn(1).has_point(p):
					var k2 := sel_card
					_do(func(): return g.standard(0, k2))
					return
		"std":
			for k in range(1, RsD.STD.size()):
				if _view_row(k - 1).has_point(p):
					if _my_turn() and g.can_std(0, k):
						var kk := k
						_do(func(): return g.standard(kk))
					return
		"acts":
			var rows := _act_rows()
			for i in rows.size():
				if _view_row(i).has_point(p):
					var j: int = rows[i]
					if _my_turn() and g.can_card_act(0, j):
						_do(func(): return g.card_act(j))
					return
		"goals":
			for m in 3:
				if _view_row(m).has_point(p):
					if _my_turn() and g.milestone_ok(0, m):
						var mm := m
						_do(func(): return g.claim(mm))
					return
			for a in 3:
				if _view_row(a + 4).has_point(p):
					if _my_turn() and g.award_ok(0, a):
						var aa := a
						_do(func(): return g.fund(aa))
					return
	view = ""


## 운영 행동 창의 줄 — 내가 낸 카드 중 행동이 있는 것(played 번호).
func _act_rows() -> Array:
	var out := []
	for j in g.players[0].played.size():
		if g.players[0].played[j].eff.has("act"):
			out.append(j)
	return out


func _click_pending(p: Vector2) -> void:
	match g.pending:
		"corp", "research":
			if g.pending == "corp":
				for k in 2:
					if _corp_rect(k).has_point(p):
						pick_corp = k
						RsSnd.play("tick")
						return
			var n: int = g.offer[0].size()
			for i in n:
				if _offer_rect(i, n).has_point(p):
					if i in picks:
						picks.erase(i)
					elif (picks.size() + 1) * RsD.CARD_BUY <= _budget():
						picks.append(i)
					RsSnd.play("tick")
					return
			if _confirm_btn().has_point(p):
				var ok := false
				if g.pending == "corp":
					ok = pick_corp >= 0 and g.choose_corp(pick_corp, picks)
				else:
					ok = g.buy_research(picks)
				if ok:
					picks = []
					pick_corp = -1
					_after_action()
		"place":
			var c := _cell_at(p)
			if c.x != 99 and g.place(c):
				_after_action()


func _budget() -> int:
	if g.pending == "corp":
		return int(RsD.CORPS[g.corp_offer[0][pick_corp]][1]) if pick_corp >= 0 else 0
	return int(g.players[0].res[0])

# ==================== 그리기 ====================


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color8(28, 16, 18))
	var bg := RsArt.img("rs_bg_board" if scr == Scr.PLAY else "rs_bg_title")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false, Color(1, 1, 1, 0.55))
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _btn(r: Rect2, label: String, fill: Color, size: float = 24.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "redstar", t, on, size)


func _draw_title() -> void:
	var lx := vs.x * 0.3
	var below := UiKit.title(self, vs, "redstar", "붉은 별 개척단", "붉은 행성을 사람이 사는 땅으로", t)
	# 왼쪽 그림 — 작은 지도 조각 + 카드 두 장
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
		var kind := RsD.cell_kind(c)
		var tile := {}
		if c == Vector2i(0, 0):
			tile = {kind = "ocean", owner = -1}
		elif c == Vector2i(1, 0):
			tile = {kind = "green", owner = 0}
		elif c == Vector2i(0, 1):
			tile = {kind = "city", owner = 1}
		RsArt.cell(self, Vector2(lx - 90, below + 110) + Vector2(36 * sqrt(3.0) * (c.x + c.y * 0.5), 36 * 1.5 * c.y), 36, kind, tile, {}, false, t)
	RsArt.card(self, Rect2(lx + 20, below + 50 + sin(t * 1.4) * 4.0, HAND.x, HAND.y), RsD.card(36), 0, t)
	RsArt.card(self, Rect2(lx + 136, below + 64 + sin(t * 1.4 + 1.0) * 4.0, HAND.x, HAND.y), RsD.card(60), 0, t)
	var labels := ["상대: %s" % RsD.AI_LEVEL_NAME[level], "카드 도감", "기업 도감", "기록"]
	var fills := [Color8(196, 110, 60), Color8(80, 130, 190), Color8(150, 90, 60), Color8(110, 80, 150)]
	for j in 4:
		UiKit.menu(self, UiKit.menu_rect(vs, j), labels[j], fills[j], "redstar", t)
	var key := str(level)
	UiKit.record_line(self, vs, "상대 %s: %d판 %d승" % [RsD.AI_LEVEL_NAME[level], int(RsSv.plays.get(key, 0)), int(RsSv.wins.get(key, 0))])
	UiKit.button(self, vs, "start", "redstar", t)
	UiKit.button(self, vs, "hub", "redstar", t)
	UiKit.button(self, vs, "vol", "redstar", t)
	book.draw(self, vs, t)


const RULES := [
	"세 지표(온도, 대기, 바다)를 끝까지 올리면 그 세대가 끝나고 게임이 끝납니다.",
	"지표를 한 단계 올린 사람은 개척 등급이 1 오릅니다. 개척 등급은 점수이자 세대마다 받는 크레딧입니다.",
	"세대마다 카드 4장을 보고 장당 크레딧 3에 삽니다.",
	"차례마다 행동 하나: 카드 내기, 기본 사업, 식물로 녹지, 열로 온도, 운영 행동, 목표 선점, 후원 개설, 패스.",
	"건물 카드에는 금속을, 우주 카드에는 합금을 크레딧 대신 쓸 수 있습니다.",
	"녹지는 대기를 올리고 1점, 도시는 둘레 녹지마다 1점입니다.",
	"둘 다 패스하면 생산: 전력은 열이 되고, 크레딧은 개척 등급 + 생산만큼 들어옵니다.",
]


func _draw_play() -> void:
	_draw_params()
	_draw_map()
	_draw_panel(0)
	_draw_panel(1)
	_draw_actions()
	_draw_hand()
	for p: Dictionary in pops:
		var k2 := float(p.t) / 1.4
		var a2 := 1.0 - k2 * k2
		var pp: Vector2 = p.p + Vector2(0, -24 * k2)
		var tw := UiKit.font().get_string_size(String(p.txt), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 20
		RsArt.rr(self, Rect2(pp - Vector2(tw * 0.5, 16), Vector2(tw, 32)), 12, Color(0, 0, 0, 0.75 * a2))
		G2.text_mid(self, pp, String(p.txt), 22, Color(p.col, a2), 3)
	if view != "":
		_draw_view()
	if _human_pending() and g.pending in ["corp", "research"]:
		_draw_offer()
	if g.pending == "place" and not g.over:
		var mine := not bool(g.players[g.pend_p].ai)
		var q: Dictionary = g.place_q[0]
		var nm: String = {ocean = "바다", green = "녹지", city = "도시"}.get(String(q.kind), "")
		G2.text_mid(self, Vector2(vs.x * 0.5, 104), ("%s를 놓을 자리를 고르세요" % nm) if mine else "상대가 %s를 놓습니다" % nm, 24, Color8(255, 236, 190), 5)
	UiKit.button(self, vs, "hub", "redstar", t, "나가기")
	UiKit.button(self, vs, "vol", "redstar", t)
	if modal == "quit":
		_draw_modal("판을 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()


func _draw_params() -> void:
	for k in 3:
		var r := _param_rect(k)
		RsArt.rr(self, r, 10, Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.15), 1.5)
		var mx: int = RsD.PARAM_MAX[k]
		var v: int = g.params[k]
		draw_string(UiKit.font(), r.position + Vector2(10, 22), "%s %d/%d" % [RsD.PARAM_NAME[k], v, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
		var sw := (r.size.x - 20) / mx
		for s in mx:
			var seg := Rect2(r.position.x + 10 + s * sw, r.position.y + 30, sw - 3, 14)
			draw_rect(seg, RsD.PARAM_COL[k] if s < v else Color(1, 1, 1, 0.12))
	G2.text_mid(self, Vector2(vs.x * 0.5, 84), "%d세대" % g.gen, 20, Color(1, 1, 1, 0.6), 0)


func _draw_map() -> void:
	var legal := []
	if g.pending == "place" and not bool(g.players[g.pend_p].ai):
		legal = g.legal_cells(g.pend_p, String(g.place_q[0].kind))
	for c in RsD.cells():
		var tile: Dictionary = g.tiles.get(c, {})
		RsArt.cell(self, _cell_pos(c), HEX, RsD.cell_kind(c), tile, RsD.cell_bonus(c), c in legal, t)


func _draw_panel(p: int) -> void:
	var r := _panel_rect(p)
	var pl: Dictionary = g.players[p]
	var active := g.cur == p and g.pending == "" and not g.over and not bool(pl.passed)
	RsArt.rr(self, r, 14, Color(0, 0, 0, 0.45), RsD.PLAYER_COL[p] if active else Color(1, 1, 1, 0.15), 3.0 if active else 1.5)
	var x0 := r.position.x + 12
	var y := r.position.y + 28
	draw_string(UiKit.font(), Vector2(x0, y + 8), "%s  %d점" % [RsD.PLAYER_NAMES[p], g.points(p)], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RsD.PLAYER_COL[p])
	if bool(pl.passed):
		draw_string(UiKit.font(), Vector2(r.end.x - 70, y + 8), "패스", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))
	y += 30
	draw_string(UiKit.font(), Vector2(x0, y + 8), String(pl.corp.get("name", "기업 고르는 중")), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 20, Color(1, 1, 1, 0.8))
	y += 30
	draw_string(UiKit.font(), Vector2(x0, y + 8), "개척 등급 %d" % int(pl.tr), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color8(255, 220, 140))
	y += 38
	draw_string(UiKit.font(), Vector2(x0 + 150, y), "보유", HORIZONTAL_ALIGNMENT_CENTER, 50, 20, Color(1, 1, 1, 0.55))
	draw_string(UiKit.font(), Vector2(x0 + 205, y), "생산", HORIZONTAL_ALIGNMENT_CENTER, 50, 20, Color(1, 1, 1, 0.55))
	y += 14
	for res in RsD.N_RES:
		var ry := y + res * 40
		RsArt.res_icon(self, Vector2(x0 + 14, ry + 14), 13, res)
		draw_string(UiKit.font(), Vector2(x0 + 34, ry + 22), RsD.RES_NAME[res], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.9))
		draw_string(UiKit.font(), Vector2(x0 + 150, ry + 22), str(int(pl.res[res])), HORIZONTAL_ALIGNMENT_CENTER, 50, 22, Color(1, 1, 1))
		var pv := int(pl.prod[res])
		draw_string(UiKit.font(), Vector2(x0 + 205, ry + 22), ("+%d" % pv) if pv >= 0 else str(pv), HORIZONTAL_ALIGNMENT_CENTER, 50, 22,
				Color8(140, 230, 140) if pv > 0 else (Color8(240, 120, 110) if pv < 0 else Color(1, 1, 1, 0.5)))
	y += 6 * 40 + 8
	# 태그 수
	var tx := x0
	var ty := y
	for tg in RsD.N_TAG:
		var n := g.count_tag(p, tg)
		if n == 0:
			continue
		var lab := "%s %d" % [RsD.TAG_NAME[tg], n]
		var w := UiKit.font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 10
		if tx + w > r.end.x - 8:
			tx = x0
			ty += 30
		var col: Color = RsD.TAG_COL[tg]
		RsArt.rr(self, Rect2(tx, ty, w, 26), 6, col, RsArt.INK, 1.5)
		G2.text_mid(self, Vector2(tx + w * 0.5, ty + 13), lab, 20, Color(1, 1, 1) if col.v < 0.7 else RsArt.INK, 0)
		tx += w + 4
	G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 44), "손패 %d장, 낸 카드 %d장" % [pl.hand.size(), pl.played.size()], 20, Color(1, 1, 1, 0.6), 0)
	G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 18), "눌러서 도시 보기", 20, Color(1, 1, 1, 0.45), 0)


func _draw_actions() -> void:
	var fills := [Color8(150, 90, 60), Color8(80, 150, 80), Color8(210, 100, 60), Color8(70, 120, 190), Color8(170, 140, 60), Color8(110, 100, 120)]
	for k in ACTS.size():
		var label: String = ACTS[k]
		if k == 1:
			label = "식물 %d로 녹지" % g.green_cost(0)
		elif k == 2:
			label = "열 %d로 온도" % g.heat_cost(0)
		_btn(_act_btn(k), label, fills[k], 20, _my_turn() and _act_enabled(k))
	if toast_t > 0.0 and view == "":
		G2.text_mid(self, Vector2(vs.x * 0.5, 462), toast, 20, Color8(255, 230, 170), 4)
	elif not _my_turn() and not g.over and g.pending == "":
		G2.text_mid(self, Vector2(vs.x * 0.5, 462), "상대 차례", 20, Color(1, 1, 1, 0.6), 3)


func _draw_hand() -> void:
	var hand: Array = g.players[0].hand
	var n := mini(PER_HAND, hand.size() - hand_page * PER_HAND)
	for i in n:
		var c: Dictionary = hand[hand_page * PER_HAND + i]
		var ok := _my_turn() and g.can_play(0, c)
		var r := _hand_rect(i)
		if r.has_point(mouse):
			r = Rect2(r.position - Vector2(0, 6), r.size)
		RsArt.card(self, r, c, 2 if ok else 0, t, g.card_cost(0, c))
	if hand.size() > PER_HAND:
		for d in [-1, 1]:
			_btn(_page_btn(d), "<" if d < 0 else ">", Color8(90, 80, 100), 26)
	if hand.is_empty():
		G2.text_mid(self, Vector2(vs.x * 0.5, 610), "손패가 없습니다", 22, Color(1, 1, 1, 0.5), 0)


func _draw_view() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var vp := _view_panel()
	RsArt.rr(self, vp, 20, RsArt.PANEL, RsArt.RUST, 3.0)
	var title := ""
	match view:
		"card":
			title = "카드"
			if sel_card >= 0 and sel_card < g.players[0].hand.size():
				var c: Dictionary = g.players[0].hand[sel_card]
				RsArt.card(self, Rect2(vp.position + Vector2(30, 70), Vector2(300, 440)), c, 0, t, g.card_cost(0, c))
				var can := _my_turn() and g.can_play(0, c)
				_btn(_detail_btn(0), "내기  크레딧 %d" % g.card_cost(0, c), Color8(80, 160, 80), 24, can)
				_btn(_detail_btn(1), "팔기  크레딧 +1", Color8(170, 130, 60), 24, _my_turn())
				if not g.req_ok(c):
					G2.text_mid(self, _detail_btn(1).get_center() + Vector2(0, 80), "조건이 아직 안 맞습니다", 20, Color8(240, 140, 120), 3)
				elif not can and _my_turn():
					G2.text_mid(self, _detail_btn(1).get_center() + Vector2(0, 80), "돈이 모자랍니다", 20, Color8(240, 140, 120), 3)
		"std":
			title = "기본 사업"
			for k in range(1, RsD.STD.size()):
				var row: Array = RsD.STD[k]
				_row(_view_row(k - 1), String(row[0]), "크레딧 %d, %s" % [int(row[1]), RsD.eff_text(row[2])], _my_turn() and g.can_std(0, k))
		"acts":
			title = "운영 행동"
			var rows := _act_rows()
			if rows.is_empty():
				G2.text_mid(self, vp.get_center(), "행동이 있는 운영 카드가 없습니다", 22, Color(1, 1, 1, 0.6), 0)
			for i in rows.size():
				var c2: Dictionary = g.players[0].played[rows[i]]
				var used: bool = g.players[0].used.has(c2.id)
				_row(_view_row(i), String(c2.name) + ("  (이번 세대 씀)" if used else ""), RsD.eff_text({act = c2.eff.act}), _my_turn() and g.can_card_act(0, rows[i]))
		"goals":
			title = "목표와 후원"
			for m in 3:
				var row2: Array = RsD.MILESTONES[m]
				var who := int(g.milestones[m])
				var st := "선점: %s" % RsD.PLAYER_NAMES[who] if who >= 0 else "크레딧 %d, 5점" % RsD.MILESTONE_COST
				_row(_view_row(m), "목표 %s" % row2[0], "%s, %s" % [String(row2[1]), st], _my_turn() and g.milestone_ok(0, m))
			for a in 3:
				var row3: Array = RsD.AWARDS[a]
				var who2 := int(g.awards[a])
				var st2 := "개설: %s" % RsD.PLAYER_NAMES[who2] if who2 >= 0 else "크레딧 %d" % g.award_cost()
				var kind: String = row3[2]
				_row(_view_row(a + 4), "후원 %s" % row3[0], "%s (나 %d, 상대 %d), %s" % [String(row3[1]), g._award_metric(0, kind), g._award_metric(1, kind), st2], _my_turn() and g.award_ok(0, a))
		_:
			var p := int(view.substr(4))
			title = "%s의 도시  %s" % ["나" if p == 0 else "상대", String(g.players[p].corp.get("name", ""))]
			var played: Array = g.players[p].played
			var per := 6
			var cw := (vp.size.x - 48 - (per - 1) * 8) / per
			for i in played.size():
				var cr := Rect2(vp.position.x + 24 + (i % per) * (cw + 8), vp.position.y + 64 + int(i / per) * 86, cw, 150)
				RsArt.card(self, cr, played[i], 0, t)
			if played.is_empty():
				G2.text_mid(self, vp.get_center(), "아직 낸 카드가 없습니다", 22, Color(1, 1, 1, 0.6), 0)
	G2.text_mid(self, Vector2(vp.get_center().x, vp.position.y + 32), title, 28, Color8(255, 236, 190), 5)
	G2.text_mid(self, Vector2(vp.get_center().x, vp.end.y - 16), "빈 곳을 누르면 닫힙니다", 20, Color(1, 1, 1, 0.5), 0)


func _row(r: Rect2, name: String, desc: String, on: bool) -> void:
	RsArt.rr(self, r, 10, Color8(70, 46, 40) if on else Color8(50, 36, 34), Color8(140, 255, 140) if on else Color(1, 1, 1, 0.12), 2.0)
	draw_string(UiKit.font(), r.position + Vector2(14, 34), name, HORIZONTAL_ALIGNMENT_LEFT, 220, 22, Color(1, 1, 1) if on else Color(1, 1, 1, 0.55))
	draw_string(UiKit.font(), r.position + Vector2(240, 34), desc, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 250, 20, Color(1, 1, 1, 0.8) if on else Color(1, 1, 1, 0.45))


func _draw_offer() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.7))
	var corp := g.pending == "corp"
	var spend := picks.size() * RsD.CARD_BUY
	if corp:
		G2.text_mid(self, Vector2(vs.x * 0.5, 72), "기업 하나를 고르고, 살 카드를 고르세요 (장당 크레딧 3)", 26, Color8(255, 236, 190), 5)
		for k in 2:
			var row: Array = RsD.CORPS[g.corp_offer[0][k]]
			var r := _corp_rect(k)
			RsArt.rr(self, r, 14, Color8(70, 40, 36), Color(1, 1, 1) if pick_corp == k else RsArt.RUST, 4.0 if pick_corp == k else 2.0)
			G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 26), "%s  크레딧 %d" % [String(row[0]), int(row[1])], 24, Color8(255, 236, 190), 4)
			G2.text_mid(self, r.position + Vector2(r.size.x * 0.5, 62), String(row[5]), 20, Color(1, 1, 1, 0.9), 3)
	else:
		G2.text_mid(self, Vector2(vs.x * 0.5, 120), "%d세대 연구: 살 카드를 고르세요 (장당 크레딧 3, 가진 크레딧 %d)" % [g.gen, int(g.players[0].res[0])], 26, Color8(255, 236, 190), 5)
	var n: int = g.offer[0].size()
	for i in n:
		RsArt.card(self, _offer_rect(i, n), g.offer[0][i], 1 if i in picks else 0, t)
	var label := "확정  카드 %d장, 크레딧 %d" % [picks.size(), spend]
	_btn(_confirm_btn(), label, Color8(80, 160, 80), 24, not corp or pick_corp >= 0)


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	var r := Rect2(c.x - 250, c.y - 90, 500, 200)
	RsArt.rr(self, r, 22, RsArt.PANEL, RsArt.RUST, 4.0)
	G2.text_mid(self, Vector2(c.x, c.y - 30), q, 26, Color(1, 1, 1), 5)
	for k in labels.size():
		_btn(_modal_btn(k), String(labels[k]), Color8(200, 90, 90) if k == 0 else Color8(120, 200, 120), 26)


func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var w := 640.0
	var r := Rect2(c.x - w * 0.5, c.y - 300, w, 610)
	RsArt.rr(self, r, 26, RsArt.PANEL, RsArt.RUST, 4.0)
	var title := "무승부" if g.winner < 0 else ("승리" if g.winner == 0 else "패배")
	G2.text_mid(self, Vector2(c.x, r.position.y + 50), title, 52, Color8(255, 226, 150), 10)
	G2.text_mid(self, Vector2(c.x, r.position.y + 100), "%d세대, 지표 %s" % [g.gen, "완성" if g.maxed() else "미완성"], 24, Color(1, 1, 1, 0.8), 0)
	var rows := [["개척 등급", "tr"], ["녹지", "green"], ["도시 둘레", "city"], ["카드", "cards"], ["목표", "milestone"], ["후원", "award"], ["합계", "total"]]
	var a := g.score_parts(0)
	var b := g.score_parts(1)
	draw_string(UiKit.font(), Vector2(r.position.x + 330, r.position.y + 150), "나", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, RsD.PLAYER_COL[0])
	draw_string(UiKit.font(), Vector2(r.position.x + 450, r.position.y + 150), "상대", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, RsD.PLAYER_COL[1])
	for k in rows.size():
		var y := r.position.y + 190 + k * 34
		var key: String = rows[k][1]
		var col := Color(1, 1, 1, 0.9) if key != "total" else Color8(255, 226, 150)
		draw_string(UiKit.font(), Vector2(r.position.x + 70, y), String(rows[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		draw_string(UiKit.font(), Vector2(r.position.x + 330, y), str(int(a[key])), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)
		draw_string(UiKit.font(), Vector2(r.position.x + 450, y), str(int(b[key])), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)
	_btn(_end_btn(0), "다시 하기", Color8(120, 200, 120), 26)
	_btn(_end_btn(1), "처음으로", Color8(90, 120, 190), 26)

# ==================== 확인용 ====================


## `--rs-click-test` — 처음 → 시작 → 기업 고르기 · 확정 → 내 차례 → 기본 사업 창 · 닫기 → 내 도시 보기 · 닫기 → 패스 → 나가기 를
## **진짜 마우스 이벤트**로. 실패하면 종료 코드 1.
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY, "시작", false],
		[func():
			if _human_pending() and g.pending == "corp":
				_press(_corp_rect(0).get_center()),
			func(): return pick_corp == 0 or (g.pending == "corp" and g.pend_p != 0), "기업 고르기", true],
		[func():
			if _human_pending() and g.pending == "corp":
				_press(_confirm_btn().get_center()),
			func(): return g.players[0].corp.has("name"), "기업 확정", true],
		[func(): pass, func(): return _my_turn(), "내 차례 기다리기", false],
		[func(): _press(_act_btn(0).get_center()), func(): return view == "std", "기본 사업 창", false],
		[func(): _press(Vector2(20, vs.y - 20)), func(): return view == "", "창 닫기", false],
		[func(): _press(_panel_rect(0).get_center()), func(): return view == "city0", "내 도시 보기", false],
		[func(): _press(Vector2(20, vs.y - 20)), func(): return view == "", "도시 닫기", false],
		[func(): _press(_act_btn(5).get_center()), func(): return bool(g.players[0].passed) or g.gen > 1, "패스", false],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "나가기 창", false],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "그만두기", false],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("RS CLICK TEST OK")
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
	if _wait < 20.0:
		return
	printerr("RS CLICK TEST FAIL: %s" % steps[i][2])
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
