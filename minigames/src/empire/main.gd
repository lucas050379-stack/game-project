extends Node2D
## 제국 연대기 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기.
##
## 규칙은 전부 [EmGame], 상대 수는 [EmAi] 에 있고 여기는 **보여 주고 클릭을 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 판(PLAY, 드래프트 · 토큰 · 도서관 · 결과 창이 판 위에 겹침).
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.**
## 가로 1280×720 만 짭니다(데스크톱 전용, ADR-0012): 왼쪽 단 상대(위) · 나(아래), 가운데 위 군사 트랙 · 발전 토큰 · 피라미드,
## 오른쪽 단 고른 카드 · 행동 단추 · 내 불가사의.
##
## **화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없어 웹에서 네모).

enum Scr { TITLE, PLAY }

const AI_DELAY := 1.1
const CARD := Vector2(108, 100)
const ROW_STEP := 62.0
const HALF := 56.0

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: EmGame = null
var level := 1
var sel := -1                  ## 고른 피라미드 칸
var ai_t := 0.0
var pawn_x := 0.0              ## 군사 말 그림 위치(따라감)
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t}
var fly: Array = []            ## 날아가는 카드 {card, a, b, t, face}
var toast := ""
var toast_t := 0.0
var modal := ""                ## "" · "quit"
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var mouse := Vector2(-999, -999)
var book := UiBook.new()
var view := ""                 ## "" · "city0" · "city1"(그 사람이 지은 것 전부) · "discard"(버린 카드) — 판 위에 겹침, 누르면 닫힘
var banner_t := 0.0            ## 시대 시작 큰 글자(남은 시간)
var shown_age := -1

# 확인용 실행
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var em_auto := false
var em_seed := -1
var click_test := false
var _ct := 0.0
var _cs := 0
var _wait := 0.0


func _ready() -> void:
	Bgm.use("empire")
	EmSnd.init(Hub.host(self))
	EmSv.load_()
	level = EmSv.level
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--em-auto":
			em_auto = true
		elif a == "--em-click-test":
			click_test = true
		elif a.begins_with("--em-seed="):
			em_seed = int(a.substr(10))
		elif a.begins_with("--em-level="):
			level = clampi(int(a.substr(11)), 0, 2)
		elif a.begins_with("--menu="):
			_menu.call_deferred(int(a.substr(7)))
	no_save = em_auto or shot_path != "" or not OS.get_cmdline_user_args().is_empty()
	if em_auto:
		_start.call_deferred()


func _start() -> void:
	g = EmGame.new(em_seed, [em_auto, true])
	scr = Scr.PLAY
	sel = -1
	pops = []
	fly = []
	end_open = false
	end_t = 0.0
	saved = false
	ai_t = 0.0
	pawn_x = 0.0
	toast = ("내가 먼저 불가사의를 고릅니다" if g.first == 0 else "상대가 먼저 불가사의를 고릅니다") if not em_auto else ""
	toast_t = 3.0
	view = ""
	shown_age = -1
	banner_t = 0.0
	if not no_save:
		EmSv.level = level
		EmSv.save_()
	EmSnd.play("card")


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	toast_t = maxf(0.0, toast_t - dt)
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.4)
	for f: Dictionary in fly:
		f.t += dt
	fly = fly.filter(func(f): return f.t < 0.55)
	var hot := false
	banner_t = maxf(0.0, banner_t - dt)
	if scr == Scr.PLAY and g != null and g.draft_i >= 8 and g.age != shown_age:
		shown_age = g.age
		banner_t = 1.6
		EmSnd.play("wonder", 0.8)
	if scr == Scr.PLAY and g != null:
		pawn_x = lerpf(pawn_x, float(g.mil), minf(1.0, dt * 6.0))
		hot = not g.over and (absi(g.mil) >= 6 or g.sci_kinds(0) >= 5 or g.sci_kinds(1) >= 5)
		if g.over:
			if not end_open:
				end_t += dt
				if end_t > 1.0:
					_open_end()
		elif _ai_waiting():
			ai_t += dt
			if ai_t >= (0.2 if em_auto else AI_DELAY):
				ai_t = 0.0
				var before := g.turn_no
				EmAi.act(g, level)
				if g.turn_no != before or g.pending == "":
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
		if _shot_i >= shot_at.size():
			get_tree().quit()
	queue_redraw()


## AI 가 둘 차례인가(드래프트 · pending 포함).
func _ai_waiting() -> bool:
	if g == null or g.over:
		return false
	if g.pending != "":
		return bool(g.players[g.pend_p].ai)
	return bool(g.players[g.cur].ai)


func _my_turn() -> bool:
	return g != null and not g.over and g.pending == "" and g.cur == 0 and not bool(g.players[0].ai) \
			and modal == "" and not end_open


func _human_pending() -> bool:
	return g != null and not g.over and g.pending != "" and not bool(g.players[g.pend_p].ai) and modal == ""


## 행동 하나가 끝난 뒤 — 소리 · 날아가는 카드 · 떠오르는 글.
func _after_action() -> void:
	var l := g.last
	var p: int = l.get("p", 0)
	var to := _pop_pos(p)
	match String(l.get("kind", "")):
		"build":
			EmSnd.play("build")
			var c: Dictionary = l.card
			fly.append({card = c, a = _slot_rect(int(l.slot)), b = Rect2(to - CARD * 0.3, CARD * 0.6), t = 0.0, face = true})
			if c.eff.has("mil"):
				EmSnd.play("drum")
			if c.eff.has("sci"):
				EmSnd.play("sci")
			var pts := int(c.eff.get("pts", 0))
			if pts > 0:
				pops.append({p = to, txt = "+%d점" % pts, col = Color8(140, 190, 255), t = 0.0})
		"discard":
			EmSnd.play("coin")
			pops.append({p = to, txt = "돈 +%d" % int(l.gain), col = EmArt.GOLD, t = 0.0})
		"wonder":
			EmSnd.play("wonder")
			pops.append({p = to, txt = String(l.wonder.name), col = Color8(255, 236, 190), t = 0.0})
		"draft":
			EmSnd.play("tick")
		"token", "library":
			EmSnd.play("sci")
		"starter":
			EmSnd.play("tick")
	if not g.events.is_empty():
		var e: Dictionary = g.events[-1]
		toast = "%s: %s" % [EmD.PLAYER_NAMES[int(e.p)], String(e.txt)]
		toast_t = 3.0
		g.events.clear()
	sel = -1
	if g.over:
		end_t = 0.0


func _open_end() -> void:
	end_open = true
	if not saved and not no_save and not bool(g.players[0].ai):
		EmSv.add(g, level)
	saved = true
	EmSnd.play("win" if g.winner == 0 else "lose")

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


## 왼쪽 단 — 0 나(아래) · 1 상대(위).
func _panel_rect(p: int) -> Rect2:
	var y := 84.0 if p == 1 else 402.0
	return Rect2(14, y, 276, 304)


## 떠오르는 글 자리 — 그 사람 판의 이름 줄 오른쪽(점수 숫자 · 과학 줄을 안 덮게).
func _pop_pos(p: int) -> Vector2:
	var r := _panel_rect(p)
	return Vector2(r.position.x + 176, r.position.y + 26)


## 버린 카드 보기 단추 — 피라미드 아래 가운데.
func _discard_btn() -> Rect2:
	var cx := _track_rect().get_center().x
	return Rect2(cx - 230, vs.y - 46, 200, 38)


func _track_rect() -> Rect2:
	return Rect2(304, 22, vs.x - 304 - 304, 46)


func _cell_x(v: float) -> float:
	var tr := _track_rect()
	return tr.get_center().x + v * tr.size.x / 19.0


func _token_rect(k: int) -> Rect2:
	var tr := _track_rect()
	var n := maxi(1, g.tokens_open.size()) if g != null else 5
	var w := 128.0
	var x0 := tr.get_center().x - (n * (w + 8) - 8) * 0.5
	return Rect2(x0 + k * (w + 8), 78, w, 38)


func _slot_rect(i: int) -> Rect2:
	var s: Dictionary = g.slots[i]
	var rows: int = EmD.LAYOUT[g.age].size()
	var area_top := 128.0
	var area_h := vs.y - area_top - 12.0
	var total := CARD.y + (rows - 1) * ROW_STEP
	var y0 := area_top + maxf(0.0, (area_h - total) * 0.5)
	var cx := _track_rect().get_center().x
	return Rect2(cx + int(s.x) * HALF - CARD.x * 0.5, y0 + int(s.row) * ROW_STEP, CARD.x, CARD.y)


func _right() -> Rect2:
	return Rect2(vs.x - 290, 84, 276, vs.y - 96)


func _act_btn(k: int) -> Rect2:
	var r := _right()
	return Rect2(r.position.x + 8, r.position.y + 228 + k * 62, r.size.x - 16, 54)


func _wonder_btn(k: int) -> Rect2:
	var r := _right()
	return Rect2(r.position.x + 8, r.position.y + 366 + k * 64, r.size.x - 16, 58)


## 드래프트 · 토큰 · 도서관 고르기 창의 칸.
func _pick_rect(k: int, n: int, big: Vector2 = Vector2(230, 250)) -> Rect2:
	var gap := 18.0
	var w := minf(big.x, (vs.x - 120 - (n - 1) * gap) / maxf(1.0, n))
	var x0 := vs.x * 0.5 - (n * w + (n - 1) * gap) * 0.5
	return Rect2(x0 + k * (w + gap), vs.y * 0.5 - big.y * 0.5 + 20, w, big.y)


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
			elif sel >= 0:
				sel = -1
			else:
				modal = "quit"


## 처음 화면 메뉴(다섯 게임 같은 구조 — 모드 · 도감 · 도감 · 순위). 0 난이도 · 1 카드 도감 · 2 불가사의 도감 · 3 기록.
func _menu(j: int) -> void:
	book.game = "empire"
	match j:
		0:
			level = (level + 1) % 3
			if not no_save:
				EmSv.level = level
				EmSv.save_()
		1:
			var items := [{name = "규칙", desc = "\n".join(RULES), draw = func(ci, r, tt):
					EmArt.coin(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.25, 7)}]
			for c: Dictionary in EmD.all_cards():
				var cc := c
				var age_txt := "길드" if int(c.kind) == EmD.K.PURPLE else "%d시대" % (int(c.age) + 1)
				var chain := "\n연계: %s 있으면 공짜" % c.chain if c.chain != "" else ""
				items.append({name = String(c.name), desc = "%s %s\n%s\n비용: %s%s" % [age_txt, EmD.KIND_NAME[c.kind],
						EmD.eff_text(c.eff), EmD.cost_text(int(c.coin), c.cost), chain],
						draw = func(ci, r, tt):
							var h: float = minf(r.size.y * 0.96, 110.0)
							var w: float = h * CARD.x / CARD.y
							EmArt.card(ci, Rect2(r.get_center() - Vector2(w, h) * 0.5, Vector2(w, h)), cc, true, 0, tt)})
			book.show("카드 도감", items, "grid", 5, 2)
		2:
			var items2 := []
			for k in EmD.WONDERS.size():
				var w := EmD.wonder(k)
				items2.append({name = String(w.name), desc = "%s\n%s\n비용: %s" % [String(w.note), EmD.eff_text(w.eff), EmD.cost_text(0, w.cost)],
						draw = func(ci, r, tt):
							EmArt.wonder(ci, Rect2(r.position + Vector2(8, r.size.y * 0.2), Vector2(r.size.x - 16, r.size.y * 0.6)), w, 0, tt)})
			for k in EmD.TOKENS.size():
				var tk := EmD.token(k)
				items2.append({name = String(tk.name), desc = "발전 토큰\n%s" % String(tk.desc),
						draw = func(ci, r, tt):
							EmArt.token(ci, Rect2(r.get_center() - Vector2(70, 22), Vector2(140, 44)), tk)})
			book.show("불가사의 도감", items2, "grid", 4, 2)
		3:
			var rows := []
			for k in 3:
				var key := str(k)
				var pl := int(EmSv.plays.get(key, 0))
				var w3 := int(EmSv.wins.get(key, 0))
				rows.append({main = "상대 %s" % EmD.AI_LEVEL_NAME[k],
						sub = "%d판 %d승%s" % [pl, w3, "  승률 %d%%" % roundi(100.0 * w3 / pl) if pl > 0 else ""]})
			rows.append({main = "이긴 방식", sub = "문명 %d  군사 %d  과학 %d" % [int(EmSv.by_kind.get("civ", 0)),
					int(EmSv.by_kind.get("mil", 0)), int(EmSv.by_kind.get("sci", 0))]})
			rows.append({main = "최고 문명 점수", sub = "%d점" % EmSv.best if EmSv.best > 0 else "아직 없음"})
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
					EmSnd.play("tick")
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
		view = ""
		return
	if _human_pending():
		_click_pending(p)
		return
	if g.pending == "" or g.draft_i >= 8:
		for q in 2:
			if _panel_rect(q).has_point(p):
				view = "city%d" % q
				EmSnd.play("tick")
				return
		if _discard_btn().has_point(p):
			view = "discard"
			EmSnd.play("tick")
			return
	if not _my_turn():
		return
	# 오른쪽 단 행동
	if sel >= 0:
		var c: Dictionary = g.slots[sel].card
		if _act_btn(0).has_point(p) and g.can_build(0, c):
			_do(sel, "build")
			return
		if _act_btn(1).has_point(p):
			_do(sel, "discard")
			return
		for k in g.players[0].wonders.size():
			if _wonder_btn(k).has_point(p) and k in g.wonder_options(0):
				_do(sel, "wonder", k)
				return
	# 피라미드 — 아래(가까운) 줄이 위에 그려지므로 뒤에서부터 찾는다
	for i in range(g.slots.size() - 1, -1, -1):
		if not g.slots[i].taken and _slot_rect(i).has_point(p):
			if g.is_open(i):
				sel = -1 if sel == i else i
				EmSnd.play("tick")
			return


func _do(i: int, action: String, wk: int = -1) -> void:
	if g.act(i, action, wk):
		_after_action()


func _click_pending(p: Vector2) -> void:
	match g.pending:
		"draft":
			for k in g.draft_pool.size():
				if _pick_rect(k, g.draft_pool.size()).has_point(p):
					g.draft_pick(k)
					_after_action()
					if g.pending == "" and not g.over:
						toast = "1시대 시작, 내 차례입니다"
						toast_t = 3.0
					return
		"token":
			for k in g.tokens_open.size():
				if _pick_rect(k, g.tokens_open.size(), Vector2(200, 150)).has_point(p):
					g.pick_token(k)
					_after_action()
					return
		"starter":
			for k in 2:
				if _pick_rect(k, 2, Vector2(260, 90)).has_point(p):
					g.pick_starter(k)
					_after_action()
					return
		"library":
			var opts := g.library_options()
			for j in opts.size():
				if _pick_rect(j, opts.size(), Vector2(150, 140)).has_point(p):
					g.pick_library(int(opts[j]))
					_after_action()
					return

# ==================== 그리기 ====================


func _draw() -> void:
	_draw_bg()
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _draw_bg() -> void:
	var top := Color8(48, 30, 22)
	var bot := Color8(22, 30, 40)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
			PackedColorArray([top, top, bot, bot]))


func _btn(r: Rect2, label: String, fill: Color, size: float = 26.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "empire", t, on, size)


func _draw_title() -> void:
	var lx := vs.x * 0.3
	var below := UiKit.title(self, vs, "empire", "제국 연대기", "두 제국, 세 시대, 승리의 길은 셋", t)
	var demo := [EmD.age_cards(0)[9], EmD.age_cards(1)[10], EmD.age_cards(2)[10]]
	for k in 3:
		var cr := Rect2(lx - 186 + k * 128, below + 40 + absf(k - 1.0) * 16.0 + sin(t * 1.5 + k) * 4.0, CARD.x, CARD.y)
		EmArt.card(self, cr, demo[k], true, 0, t)
	EmArt.wonder(self, Rect2(lx - 150, below + 190, 300, 70), EmD.wonder(int(t * 0.4) % EmD.WONDERS.size()), 0, t)
	var labels := ["상대: %s" % EmD.AI_LEVEL_NAME[level], "카드 도감", "불가사의 도감", "기록"]
	var fills := [Color8(196, 140, 60), Color8(80, 130, 190), Color8(150, 90, 60), Color8(110, 80, 150)]
	for j in 4:
		UiKit.menu(self, UiKit.menu_rect(vs, j), labels[j], fills[j], "empire", t)
	var key := str(level)
	UiKit.record_line(self, vs, "상대 %s: %d판 %d승" % [EmD.AI_LEVEL_NAME[level], int(EmSv.plays.get(key, 0)), int(EmSv.wins.get(key, 0))])
	UiKit.button(self, vs, "start", "empire", t)
	UiKit.button(self, vs, "hub", "empire", t)
	UiKit.button(self, vs, "vol", "empire", t)
	book.draw(self, vs, t)


const RULES := [
	"차례마다 피라미드에서 위가 열린 카드 한 장을 가져와",
	"짓거나, 버려서 돈을 받거나, 불가사의 아래에 넣어 불가사의를 짓습니다.",
	"모자란 자원은 돈으로 삽니다. 값은 2 + 상대가 그 자원을 만드는 수입니다.",
	"연계 표시의 앞 카드가 있으면 공짜로 짓습니다.",
	"불가사의는 둘이 합쳐 7개까지만 지을 수 있습니다.",
	"군사 말이 상대 수도에 닿으면 즉시 승리합니다.",
	"과학 심볼 일곱 가지 중 여섯 가지를 모으면 즉시 승리합니다.",
	"같은 과학 심볼 둘을 모으면 발전 토큰을 하나 고릅니다.",
	"3시대가 끝나면 점수가 높은 쪽이 이깁니다(돈 3당 1점).",
]


func _draw_play() -> void:
	_draw_track()
	_draw_tokens()
	for i in g.slots.size():
		var s: Dictionary = g.slots[i]
		if s.taken:
			continue
		var st := 0
		if i == sel:
			st = 1
		elif _my_turn() and g.is_open(i) and s.face and g.can_build(0, s.card):
			st = 2
		var r := _slot_rect(i)
		if r.has_point(mouse) and g.is_open(i) and _my_turn() and st != 1:
			r = Rect2(r.position - Vector2(0, 4), r.size)
		EmArt.card(self, r, s.card, bool(s.face), st, t, g.age)
		if s.face and g.is_open(i) and _my_turn():
			_price_tag(r, s.card)
	for f: Dictionary in fly:
		var k := G2.out_cubic(clampf(float(f.t) / 0.55, 0.0, 1.0))
		var a: Rect2 = f.a
		var b: Rect2 = f.b
		var rr := Rect2(a.position.lerp(b.position, k), a.size.lerp(b.size, k))
		EmArt.card(self, rr, f.card, true, 0, t)
	_draw_panel(1)
	_draw_panel(0)
	_draw_right()
	G2.text_mid(self, Vector2(_track_rect().get_center().x + 80, vs.y - 26), "%d시대" % (g.age + 1), 22, Color(1, 1, 1, 0.6), 0)
	_btn(_discard_btn(), "버린 카드 %d" % g.discard.size(), Color8(96, 80, 64), 20, true)
	for p: Dictionary in pops:
		var k2 := float(p.t) / 1.4
		var a2 := 1.0 - k2 * k2
		var pp: Vector2 = p.p + Vector2(0, -24 * k2)
		var tw := UiKit.font().get_string_size(String(p.txt), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 20
		EmArt.rr(self, Rect2(pp - Vector2(tw * 0.5, 17), Vector2(tw, 34)), 14, Color(0, 0, 0, 0.75 * a2))
		G2.text_mid(self, pp, String(p.txt), 24, Color(p.col, a2), 4)
	if banner_t > 0.0 and not g.over:
		var bk := clampf(banner_t / 0.3, 0.0, 1.0) * clampf((1.6 - banner_t) / 0.2, 0.0, 1.0)
		var br := Rect2(vs.x * 0.5 - 260, vs.y * 0.5 - 60, 520, 120)
		EmArt.rr(self, br, 24, Color(0.1, 0.07, 0.05, 0.85 * bk), Color(EmArt.GOLD, bk), 3.0)
		G2.text_mid(self, br.get_center(), "%d시대" % (g.age + 1), 64, Color(Color8(255, 226, 150), bk), 8)
	if view != "":
		_draw_view()
	if g.pending != "" and not g.over:
		_draw_pending()
	UiKit.button(self, vs, "hub", "empire", t, "나가기")
	UiKit.button(self, vs, "vol", "empire", t)
	if modal == "quit":
		_draw_modal("판을 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()


func _draw_track() -> void:
	var tr := _track_rect()
	EmArt.rr(self, tr, 10, Color8(40, 30, 24), EmArt.GOLD.darkened(0.3), 2.0)
	for v in range(-9, 10):
		var x := _cell_x(v)
		var c := Color(1, 1, 1, 0.12)
		if absi(v) >= 6:
			c = Color(1, 0.4, 0.3, 0.22)
		elif absi(v) >= 3:
			c = Color(1, 0.8, 0.3, 0.16)
		draw_rect(Rect2(x - 15, tr.position.y + 8, 30, tr.size.y - 16), c)
		# 아직 안 낸 돈 잃기 표시(그 칸 안 — 처음 넘을 때 상대가 그만큼 잃음)
		for th: Array in EmD.MIL_LOSS:
			var side := 0 if v > 0 else 1   # v>0 은 0번(나)이 밀고 들어간 쪽 — 상대가 잃음
			if absi(v) == int(th[0]) and not g.mil_paid.has("%d_%d" % [side, int(th[0])]):
				EmArt.coin(self, Vector2(x, tr.get_center().y), 12, int(th[1]))
	# 구간 점수(게임 끝에 말이 넘어간 쪽이 받음)
	for d in [[4, "2점"], [7, "5점"]]:
		for sgn in [-1, 1]:
			G2.text_mid(self, Vector2(_cell_x(int(d[0]) * sgn), tr.position.y - 2), String(d[1]), 20, Color(1, 1, 1, 0.55), 3)
	# 양쪽 수도 — 왼쪽 내 수도, 오른쪽 상대 수도
	for q in 2:
		var cp := Vector2(_cell_x(-9.7 if q == 0 else 9.7), tr.get_center().y)
		draw_circle(cp, 19, EmArt.INK)
		draw_circle(cp, 17, EmD.PLAYER_COL[q])
		G2.text_mid(self, cp, "나" if q == 0 else "적", 20, Color(1, 1, 1), 3)
	# 말 — 0번이 밀면 오른쪽(상대 수도 쪽)
	var px := _cell_x(pawn_x)
	draw_circle(Vector2(px, tr.get_center().y), 13, EmArt.INK)
	draw_circle(Vector2(px, tr.get_center().y), 11, Color8(220, 70, 60))


func _draw_tokens() -> void:
	for k in g.tokens_open.size():
		EmArt.token(self, _token_rect(k), g.tokens_open[k])


func _draw_panel(p: int) -> void:
	var r := _panel_rect(p)
	var pl: Dictionary = g.players[p]
	var active := g.cur == p and g.pending == "" and not g.over
	EmArt.rr(self, r, 14, Color(0, 0, 0, 0.35), EmD.PLAYER_COL[p] if active else Color(1, 1, 1, 0.15), 3.0 if active else 1.5)
	var x0 := r.position.x + 12
	var y := r.position.y + 24
	draw_string(UiKit.font(), Vector2(x0, y + 8), "%s  %d점" % [EmD.PLAYER_NAMES[p], g.points(p)], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, EmD.PLAYER_COL[p])
	EmArt.coin(self, Vector2(r.end.x - 40, y), 16, int(pl.coin))
	# 생산
	y += 38
	var prod := g.production(p)
	for res in EmD.N_RES:
		var cx := x0 + 12 + res * 52
		EmArt.res_chip(self, Vector2(cx, y), 10, res)
		draw_string(UiKit.font(), Vector2(cx + 14, y + 8), str(int(prod[res])), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
	var pk := g.picks(p).size()
	if pk > 0:
		draw_string(UiKit.font(), Vector2(x0, y + 30), "택1 자원 %d" % pk, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	# 과학
	y += 52
	var sc: Array = pl.sci
	var sx := x0
	for s in 7:
		if int(sc[s]) > 0:
			var lab := "%s%s" % [EmD.SCI_NAME[s], "2" if int(sc[s]) >= 2 else ""]
			var w := UiKit.font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 10
			if sx + w > r.end.x - 8:
				break
			EmArt.rr(self, Rect2(sx, y - 14, w, 26), 8, EmD.KIND_COL[EmD.K.GREEN])
			draw_string(UiKit.font(), Vector2(sx + 5, y + 7), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
			sx += w + 4
	if sx == x0:
		draw_string(UiKit.font(), Vector2(x0, y + 7), "과학 없음", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.4))
	# 카드 색별 수
	y += 36
	for k in 7:
		var cx2 := x0 + k * 37
		EmArt.rr(self, Rect2(cx2, y - 13, 32, 28), 6, EmD.KIND_COL[k])
		G2.text_mid(self, Vector2(cx2 + 16, y), str(g.count_kind(p, k)), 20, Color(1, 1, 1), 3)
	# 불가사의
	y += 26
	for k in pl.wonders.size():
		var w: Dictionary = pl.wonders[k]
		var st := 1 if w.built else (2 if w.get("dead", false) else 0)
		EmArt.wonder(self, Rect2(x0 + (k % 2) * 128, y + int(k / 2) * 46, 124, 42), w.w, st, t)
	G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 16), "눌러서 도시 보기", 20, Color(1, 1, 1, 0.45), 0)


## 피라미드에서 집을 수 있는 카드 아래 — 지금 내가 짓는 데 드는 값(연계 · 무료 · 돈 N, 모자라면 빨강).
func _price_tag(r: Rect2, c: Dictionary) -> void:
	var cost := g.card_cost(0, c)
	var lab := "연계" if (c.chain != "" and g.has_card(0, c.chain)) else ("무료" if cost == 0 else "돈 %d" % cost)
	var ok := g.can_build(0, c)
	var tr := Rect2(r.get_center().x - 36, r.end.y - 6, 72, 28)
	EmArt.rr(self, tr, 12, Color8(40, 110, 50) if ok else Color8(140, 40, 36), EmArt.INK, 2.0)
	G2.text_mid(self, tr.get_center(), lab, 20, Color(1, 1, 1), 3)


## 도시 · 버린 카드 보기(판 위에 겹침). 도시는 색마다 한 줄씩 세로로 겹쳐 쌓는다(머리 띠가 보이게).
func _draw_view() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.7))
	var panel := Rect2(40, 84, vs.x - 80, vs.y - 110)
	EmArt.rr(self, panel, 20, Color8(50, 38, 28), EmArt.GOLD, 3.0)
	if view == "discard":
		G2.text_mid(self, Vector2(vs.x * 0.5, panel.position.y + 30), "버린 카드 %d장" % g.discard.size(), 30, Color8(255, 236, 190), 5)
		var per := int((panel.size.x - 40) / (CARD.x + 8))
		for k in g.discard.size():
			var cr := Rect2(panel.position.x + 20 + (k % per) * (CARD.x + 8), panel.position.y + 64 + int(k / per) * (CARD.y + 10), CARD.x, CARD.y)
			EmArt.card(self, cr, g.discard[k], true, 0, t)
	else:
		var p := int(view.substr(4))
		var pl: Dictionary = g.players[p]
		G2.text_mid(self, Vector2(vs.x * 0.5, panel.position.y + 30), "%s의 도시  %d점, 돈 %d" % ["나" if p == 0 else "상대", g.points(p), int(pl.coin)], 30, EmD.PLAYER_COL[p], 5)
		var colw := (panel.size.x - 40) / 7.0
		for k in 7:
			var x := panel.position.x + 20 + k * colw
			G2.text_mid(self, Vector2(x + colw * 0.5, panel.position.y + 66), String(EmD.KIND_NAME[k]), 20, EmD.KIND_COL[k].lightened(0.3), 3)
			var n := 0
			for c: Dictionary in pl.cards:
				if int(c.kind) == k:
					EmArt.card(self, Rect2(x + (colw - CARD.x) * 0.5, panel.position.y + 84 + n * 34, CARD.x, CARD.y), c, true, 0, t)
					n += 1
		var y := panel.end.y - 64
		var x2 := panel.position.x + 20
		for w: Dictionary in pl.wonders:
			var st := 1 if w.built else (2 if w.get("dead", false) else 0)
			EmArt.wonder(self, Rect2(x2, y, 190, 50), w.w, st, t)
			x2 += 198
		for tk: Dictionary in pl.tokens:
			EmArt.token(self, Rect2(x2, y + 4, 130, 42), tk)
			x2 += 138
	G2.text_mid(self, Vector2(vs.x * 0.5, vs.y - 14), "아무 데나 누르면 닫힙니다", 20, Color(1, 1, 1, 0.6), 0)


func _draw_right() -> void:
	var r := _right()
	EmArt.rr(self, r, 14, Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.15), 1.5)
	var cx := r.get_center().x
	if sel < 0 or g.slots[sel].taken:
		var msg := "카드를 고르세요" if _my_turn() else ("상대 차례" if not g.over else "")
		G2.text_mid(self, Vector2(cx, r.position.y + 40), msg, 24, Color(1, 1, 1, 0.8), 4)
		if toast_t > 0.0:
			var lines := UiBook.wrap_text(toast, 20, r.size.x - 20)
			for k in lines.size():
				G2.text_mid(self, Vector2(cx, r.position.y + 90 + k * 26), String(lines[k]), 20, Color8(255, 230, 170), 3)
	else:
		var c: Dictionary = g.slots[sel].card
		EmArt.card(self, Rect2(cx - CARD.x * 0.5, r.position.y + 12, CARD.x, CARD.y), c, true, 0, t)
		var desc := EmD.eff_text(c.eff)
		if c.chain != "" and g.has_card(0, c.chain):
			desc += ", 연계로 공짜"
		var lines2 := UiBook.wrap_text(desc, 20, r.size.x - 20)
		for k in mini(lines2.size(), 4):
			G2.text_mid(self, Vector2(cx, r.position.y + 132 + k * 24), String(lines2[k]), 20, Color(1, 1, 1, 0.9), 3)
		var cost := g.card_cost(0, c)
		_btn(_act_btn(0), "짓기  돈 %d" % cost if cost > 0 else "짓기  무료", Color8(90, 170, 90), 24, g.can_build(0, c))
		_btn(_act_btn(1), "버리기  돈 +%d" % g.discard_gain(0), Color8(180, 140, 60), 24)
	# 내 불가사의 — 카드를 골랐으면 그 카드로 지을 수 있는 것이 빛난다
	var opts := g.wonder_options(0) if (sel >= 0 and _my_turn()) else []
	G2.text_mid(self, Vector2(cx, r.position.y + 352), "내 불가사의", 20, Color(1, 1, 1, 0.6), 0)
	for k in g.players[0].wonders.size():
		var w: Dictionary = g.players[0].wonders[k]
		var st := 1 if w.built else (2 if w.get("dead", false) else (3 if k in opts else 0))
		var br := _wonder_btn(k)
		EmArt.wonder(self, br, w.w, st, t)
		if k in opts:
			draw_string(UiKit.font(), Vector2(br.position.x + 8, br.end.y - 6), "돈 %d" % g.wonder_cost(0, w.w),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color8(140, 255, 140))


func _draw_pending() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var mine := not bool(g.players[g.pend_p].ai)
	var who := "내가" if mine else "상대가"
	match g.pending:
		"draft":
			G2.text_mid(self, Vector2(vs.x * 0.5, vs.y * 0.5 - 170), "%s 불가사의를 고릅니다 (%d/8)" % [who, g.draft_i + 1], 30, Color8(255, 236, 190), 6)
			for k in g.draft_pool.size():
				EmArt.wonder(self, _pick_rect(k, g.draft_pool.size()), g.draft_pool[k], 3 if mine else 0, t, true)
		"token":
			G2.text_mid(self, Vector2(vs.x * 0.5, vs.y * 0.5 - 130), "%s 발전 토큰을 고릅니다" % who, 30, Color8(255, 236, 190), 6)
			for k in g.tokens_open.size():
				var r := _pick_rect(k, g.tokens_open.size(), Vector2(200, 150))
				EmArt.token(self, Rect2(r.position, Vector2(r.size.x, 46)), g.tokens_open[k], mine, t)
				var lines := UiBook.wrap_text(String(g.tokens_open[k].desc), 20, r.size.x - 10)
				for j in lines.size():
					G2.text_mid(self, Vector2(r.get_center().x, r.position.y + 70 + j * 24), String(lines[j]), 20, Color(1, 1, 1, 0.9), 3)
		"starter":
			var why := "군사에서 밀려서" if g.mil != 0 else "마지막 카드를 가져가서"
			G2.text_mid(self, Vector2(vs.x * 0.5, vs.y * 0.5 - 90), "%s %s %d시대를 누가 먼저 둘지 정합니다" % [why, who, g.age + 2], 28, Color8(255, 236, 190), 6)
			if mine:
				for k in 2:
					_btn(_pick_rect(k, 2, Vector2(260, 90)), "내가 먼저" if k == 0 else "상대가 먼저", Color8(90, 150, 200) if k == 0 else Color8(200, 110, 90), 28)
		"library":
			G2.text_mid(self, Vector2(vs.x * 0.5, vs.y * 0.5 - 130), "%s 버린 과학 카드 하나를 공짜로 짓습니다" % who, 28, Color8(255, 236, 190), 6)
			var opts := g.library_options()
			for j in opts.size():
				var r2 := _pick_rect(j, opts.size(), Vector2(150, 140))
				EmArt.card(self, Rect2(r2.position, CARD), g.discard[int(opts[j])], true, 2 if mine else 0, t)


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	var r := Rect2(c.x - 250, c.y - 90, 500, 200)
	EmArt.rr(self, r, 22, Color8(60, 44, 32), EmArt.GOLD, 4.0)
	G2.text_mid(self, Vector2(c.x, c.y - 30), q, 26, Color(1, 1, 1), 5)
	for k in labels.size():
		_btn(_modal_btn(k), String(labels[k]), Color8(200, 90, 90) if k == 0 else Color8(120, 200, 120), 26)


func _draw_end() -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
	var c := vs * 0.5
	var w := 640.0
	var r := Rect2(c.x - w * 0.5, c.y - 300, w, 610)
	EmArt.rr(self, r, 26, Color8(60, 44, 32), EmArt.GOLD, 4.0)
	var how := {mil = "군사 승리", sci = "과학 승리", civ = "문명 승리"}
	var title := "무승부" if g.winner < 0 else ("승리!" if g.winner == 0 else "패배")
	G2.text_mid(self, Vector2(c.x, r.position.y + 50), title, 52, Color8(255, 226, 150), 10)
	G2.text_mid(self, Vector2(c.x, r.position.y + 100), String(how.get(g.win_kind, "")), 26, Color(1, 1, 1, 0.8), 0)
	var rows := [["문화", "blue"], ["과학", "green"], ["상업", "yellow"], ["길드", "guild"], ["불가사의", "wonder"],
			["발전 토큰", "token"], ["군사", "mil"], ["돈", "coin"], ["합계", "total"]]
	var a := g.score_parts(0)
	var b := g.score_parts(1)
	draw_string(UiKit.font(), Vector2(r.position.x + 330, r.position.y + 150), "나", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, EmD.PLAYER_COL[0])
	draw_string(UiKit.font(), Vector2(r.position.x + 450, r.position.y + 150), "상대", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, EmD.PLAYER_COL[1])
	for k in rows.size():
		var y := r.position.y + 186 + k * 30
		var key: String = rows[k][1]
		var col := Color(1, 1, 1, 0.9) if key != "total" else Color8(255, 226, 150)
		draw_string(UiKit.font(), Vector2(r.position.x + 70, y), String(rows[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		draw_string(UiKit.font(), Vector2(r.position.x + 330, y), str(int(a[key])), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)
		draw_string(UiKit.font(), Vector2(r.position.x + 450, y), str(int(b[key])), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)
	_btn(_end_btn(0), "다시 하기", Color8(120, 200, 120), 26)
	_btn(_end_btn(1), "처음으로", Color8(90, 120, 190), 26)

# ==================== 확인용 ====================


## `--em-click-test` — 처음 → 시작 → 드래프트(내 차례마다 첫 불가사의) → 내 차례 → 카드 고르기 → 버리기 →
## 상대 도시 보기 · 닫기 → 버린 카드 보기 · 닫기 → 나가기 를 **진짜 마우스 이벤트**로. 실패하면 종료 코드 1.
## 단계: [할 일, 됐나, 이름, 될 때까지 할 일을 되풀이하나]
func _click_test_step(dt: float) -> void:
	_ct += dt
	if _ct < 0.3:
		return
	_ct = 0.0
	var steps := [
		[func(): _press(Hub.std_rect("start", vs).get_center()), func(): return scr == Scr.PLAY, "시작", false],
		[func():
			if _human_pending() and g.pending == "draft":
				_press(_pick_rect(0, g.draft_pool.size()).get_center()),
			func(): return g.draft_i >= 8, "드래프트", true],
		[func(): pass, func(): return _my_turn() and banner_t <= 0.0, "내 차례 기다리기", false],
		[func():
			for i in g.available():
				if g.slots[i].face:
					_press(_slot_rect(i).get_center() + Vector2(0, -20))
					return,
			func(): return sel >= 0, "카드 고르기", false],
		[func(): _press(_act_btn(1).get_center()), func(): return String(g.last.get("kind", "")) == "discard" and int(g.last.p) == 0, "버리기", false],
		[func(): _press(_panel_rect(1).get_center()), func(): return view == "city1", "상대 도시 보기", false],
		[func(): _press(vs * 0.5), func(): return view == "", "도시 닫기", false],
		[func(): _press(_discard_btn().get_center()), func(): return view == "discard", "버린 카드 보기", false],
		[func(): _press(vs * 0.5), func(): return view == "", "버린 카드 닫기", false],
		[func(): _press(_back_btn().get_center()), func(): return modal == "quit", "나가기 창", false],
		[func(): _press(_modal_btn(0).get_center()), func(): return scr == Scr.TITLE, "그만두기", false],
	]
	var i := _cs / 2
	if i >= steps.size():
		print("EM CLICK TEST OK")
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
	printerr("EM CLICK TEST FAIL: %s" % steps[i][2])
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
