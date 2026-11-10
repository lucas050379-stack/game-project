extends Node2D
## 버거왕 — 진입점(허브가 자식으로 연다). 화면 배치 · 입력 · 그리기 · 연출.
##
## 규칙은 전부 [BgGame](손님 · 주문 · 조립 · 굽기 · 봇)에 있고 여기는 **보여 주고 누른 것을 행동으로 바꾸기만** 합니다.
## 화면: 처음(TITLE) → 날 고르기(DAYS) ↔ 가게(SHOP) → 영업(PLAY) → 정산 창. 1280×720 데스크톱 전용.
## 판은 정면에서 본 한 화면 — 위: 카운터 너머의 손님과 주문 말풍선, 가운데: 철판 · 조립대 · 쓰레기통 · 곁들임 · 금고, 아래: 재료 선반.
## 연출은 규칙이 남긴 `g.events` 를 받아 소리 · 떠오르는 글 · 날아가는 동전으로 바꿉니다(행동 → 판의 반응).
## **자리 함수(`_*_rect`)를 그리기와 클릭이 같이 봅니다.** 화면 글자에 `·` `—` `×` `→` 를 쓰지 마세요(Jua). 말투는 해요체.

enum Scr { TITLE, DAYS, SHOP, PLAY }

const COUNTER_Y := 322.0       ## 카운터 윗선 — 손님이 여기 손을 얹는다
const BOARD := Vector2(620, 488)   ## 조립대 위 버거의 맨 아래 가운데
const STACK_W := 168.0
const KEYS := [["serve", "버거 내기", KEY_SPACE], ["trash", "맨 위 버리기", KEY_BACKSPACE], ["g1", "철판 첫째 칸", KEY_Q], ["g2", "철판 둘째 칸", KEY_W],
		["g3", "철판 셋째 칸", KEY_E], ["g4", "철판 넷째 칸", KEY_R], ["p1", "콜라 따르기", KEY_Z], ["p2", "퐌타 따르기", KEY_X],
		["p3", "사이다 따르기", KEY_C], ["p4", "오렌지주스 따르기", KEY_V], ["fry", "튀김기", KEY_T], ["wrap", "포장하기", KEY_P]]
const NUM_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
## 재료 통 — 분류 여섯. 통을 누르면(또는 그 키) 오른쪽에 그 분류의 재료가 펼쳐진다(재료가 많아 한 줄에 다 못 놓는다, 사용자 요청 11-10). [분류, 이름, 키]
const CATS := [["bun", "빵", KEY_A], ["patty", "패티", KEY_S], ["cheese", "치즈", KEY_D], ["veg", "야채", KEY_F], ["top", "토핑", KEY_G], ["sauce", "소스", KEY_H]]

var scr := Scr.TITLE
var vs := Vector2(1280, 720)
var t := 0.0
var g: BgGame = null
var pick := 0
var pops: Array = []           ## 떠오르는 글 {p, txt, col, t}
var coins: Array = []          ## 날아가는 동전 {a, b, t}
var drop_t := 9.0              ## 맨 위 층을 얹은 뒤 흐른 시간
var marks := {}                ## 자리 → {i, t} — 틀린 층이 말풍선에서 붉게 깜빡인다
var shake := 0.0
var dip_t := 9.0               ## 찍는 소스를 고른 뒤 흐른 시간(소스 컵이 쟁반으로 날아온다)
var flip_t := {}                ## 철판 칸 → 뒤집은 뒤 흐른 시간(패티가 휙 뒤집힌다)
var open_cat := "bun"           ## 지금 펼쳐진 재료 통
var pour_hold := -1             ## 마우스로 누르고 있는 음료 꼭지(-1 = 없음)
var _was_pour := false
var modal := ""
var end_open := false
var end_t := 0.0
var saved := false
var no_save := false
var rules := UiRules.new()
var keys := UiKeys.new()
var shot_path := ""
var shot_at: Array = []
var _shot_i := 0
var bg_auto := false
var bg_seed := -1
var click_test := false
var _ct := 0


func _ready() -> void:
	Bgm.use("burger")
	BgSnd.init(Hub.host(self))
	BgSv.load_()
	pick = mini(BgSv.cleared(), BgD.DAYS - 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			for s in a.substr(10).split(","):
				shot_at.append(float(s))
		elif a == "--bg-auto":
			bg_auto = true
		elif a == "--bg-open":
			BgSv.all_open = true
		elif a == "--bg-rich":   # 확인용 — 재료 · 강화를 전부 가진 채로
			BgSv.unlocked = BgD.ORDER.duplicate()
			for row: Array in BgD.UP:
				BgSv.up[row[0]] = (row[3] as Array).size()
		elif a == "--bg-shop":
			scr = Scr.SHOP
		elif a == "--bg-days":
			scr = Scr.DAYS
		elif a == "--bg-click-test":
			click_test = true
		elif a.begins_with("--bg-seed="):
			bg_seed = int(a.substr(10))
		elif a.begins_with("--bg-day="):
			pick = clampi(int(a.substr(9)) - 1, 0, BgD.DAYS - 1)
	no_save = not OS.get_cmdline_user_args().is_empty()
	if bg_auto:
		_start.call_deferred()


func _start() -> void:
	g = BgGame.new(pick, bg_seed, BgSv.unlocked, BgSv.up)
	if OS.get_cmdline_user_args().has("--bg-short"):   # 확인용 — 하루를 12초로(정산 창을 바로 보려고)
		g.time_left = 12.0
	scr = Scr.PLAY
	pops = []
	coins = []
	marks = {}
	drop_t = 9.0
	modal = ""
	end_open = false
	end_t = 0.0
	saved = false
	open_cat = "bun"
	flip_t = {}
	# 그날 처음 생기는 일을 한 줄로 알려 준다
	var news := {3: "오늘부터 패티를 구워요. 패티를 눌러 철판에 올리고 초록일 때 집어요", 5: "오늘부터 야채가 떨어지면 눌러서 썰어야 해요",
			7: "오늘부터 소스 두 줄 주문이 와요. 같은 소스를 두 번 눌러요", 9: "오늘부터 패티를 한 번 뒤집어야 해요",
			12: "음료 기계와 감자튀김기가 있으면 세트 주문이 와요", 15: "오늘부터 녹인 치즈 주문이 와요. 치즈를 오른쪽 단추로 눌러 철판의 패티에 얹어요",
			18: "오늘부터 특별 손님이 와요", 21: "오늘부터 포장 손님이 와요. 다 만든 버거를 포장지로 싸요"}
	if news.has(g.day):
		pops.append({p = Vector2(vs.x * 0.5, 250), txt = String(news[g.day]), col = Color8(255, 236, 150), t = -3.5})
	BgSnd.play("come")


func _paused() -> bool:
	return modal != "" or Vol.open or end_open or rules.open


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	vs = get_viewport_rect().size
	shake = maxf(0.0, shake - dt)
	drop_t += dt
	dip_t += dt
	for fk in flip_t.keys():
		flip_t[fk] = float(flip_t[fk]) + dt
	for p: Dictionary in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < 1.1)
	for c: Dictionary in coins:
		c.t += dt * 1.8
	coins = coins.filter(func(c): return c.t < 1.0)
	for k in marks.keys():
		marks[k].t -= dt
		if float(marks[k].t) <= 0.0:
			marks.erase(k)
	if scr == Scr.PLAY and g != null:
		if end_open:
			end_t += dt
		elif not _paused():
			if bg_auto:
				g.bot(dt, 0.3)
			else:   # 음료 — 꼭지를 누르고 있는 동안 따르고, 떼면 멈춘다
				var pt := _pour_type()
				if pt != "":
					g.pour_add(pt, dt)
					_was_pour = true
				elif _was_pour:
					g.pour_stop()
					_was_pour = false
			g.step(dt)
			_take_events()
			# 재료 통은 마우스만 올려도 열린다 — 통을 바꿀 때마다 누르던 것을 없앤다(누르는 횟수가 절반)
			var hp := get_local_mouse_position()
			for hc in CATS.size():
				if _cat_rect(hc).has_point(hp) and open_cat != String(CATS[hc][0]) and not _cat_items(String(CATS[hc][0])).is_empty():
					open_cat = String(CATS[hc][0])
					BgSnd.play("tick", 1.3)
			if g.over and not end_open:
				_open_end()
	if click_test:
		_click_test_step()
	if shot_path != "" and _shot_i < shot_at.size() and t >= float(shot_at[_shot_i]):
		var path := shot_path if shot_at.size() == 1 else shot_path.replace(".png", "_%d.png" % _shot_i)
		get_viewport().get_texture().get_image().save_png(path)
		_shot_i += 1
		if _shot_i >= shot_at.size():
			get_tree().quit()
	queue_redraw()


func _take_events() -> void:
	for e: Dictionary in g.events:
		match String(e.kind):
			"add":
				drop_t = 0.0
				var c := BgD.cat(String(e.id))
				BgSnd.play("slap" if c == "cheese" or c == "sauce" else "add", {"bun": 0.9, "patty": 0.8, "veg": 1.25, "top": 1.05}.get(c, 1.1))
			"grill_on":
				BgSnd.play("sizzle")
			"cooked":
				BgSnd.play("ding")
			"burning":
				BgSnd.play("burn")
			"burnt":
				BgSnd.play("trash", 0.7)
				_pop(_grill_rect(int(e.i)).get_center() + Vector2(0, -50), "타 버렸어요", BgArt.RED)
			"trash":
				BgSnd.play("trash")
			"flip":
				flip_t[int(e.i)] = 0.0
				BgSnd.play("sizzle", 1.5)
			"chop":
				BgSnd.play("slap", 1.5)
			"chopped":
				BgSnd.play("ding", 1.3)
			"melt_on":
				BgSnd.play("slap", 0.9)
			"wrap":
				BgSnd.play("slap", 0.7)
			"side":
				BgSnd.play("add", 1.4)
				if String(e.what) == "dip":
					dip_t = 0.0
			"spill":
				BgSnd.play("trash", 1.3)
				_pop(_side_rect("drink").get_center() + Vector2(0, -70), "넘쳤어요", BgArt.RED)
			"fry_on":
				BgSnd.play("sizzle", 1.2)
			"burnt_fry":
				BgSnd.play("trash", 0.7)
				_pop(_side_rect("fries").get_center() + Vector2(0, -80), "타 버렸어요", BgArt.RED)
			"come":
				BgSnd.play("come")
			"serve":
				open_cat = "bun"   # 다음 버거는 빵부터
				BgSnd.play("cash", 1.0 + minf(int(e.combo), 8) * 0.04)
				var cp := _cust_pos(int(e.slot)) + Vector2(0, -90)
				_pop(cp + Vector2(0, -60), "+%d" % int(e.pay), Color8(255, 236, 150))
				if int(e.tip) > 0:
					_pop(cp + Vector2(0, -26), "팁 +%d" % int(e.tip), Color8(170, 240, 150))
				for j in mini(8, 2 + int(e.pay) / 12):
					coins.append({a = cp + Vector2(randf_range(-20, 20), randf_range(-10, 10)), b = _register_rect().get_center(), t = -j * 0.07})
			"wrong":
				BgSnd.play("wrong")
				shake = 0.25
				_pop(_cust_pos(int(e.slot)) + Vector2(0, -150), "이게 아니에요", BgArt.RED)
			"lost":
				BgSnd.play("lost")
				_pop(_cust_pos(int(e.slot)) + Vector2(0, -150), "너무 늦어요", BgArt.RED)
			"nope":
				BgSnd.play("tick", 0.6)
				_pop(BOARD + Vector2(0, -150), String(e.why), BgArt.HEAD)
			"close":
				BgSnd.play("close")
	g.events.clear()


func _pop(p: Vector2, txt: String, col: Color) -> void:
	pops.append({p = p, txt = txt, col = col, t = 0.0})


## 지금 누르고 있는 음료 꼭지의 음료(없으면 "").
func _pour_type() -> String:
	if not g.set_on("drink"):
		return ""
	if pour_hold >= 0:
		return String(BgD.DRINK_IDS[pour_hold])
	for j in 4:
		if UiKeys.held("burger", String(KEYS[6 + j][0]), int(KEYS[6 + j][2])):
			return String(BgD.DRINK_IDS[j])
	return ""


func _open_end() -> void:
	end_open = true
	end_t = 0.0
	if not saved and not no_save:
		BgSv.add(g)
		BgSv.save_()
	saved = true


## 버거를 낸다 — 틀리면 그 손님 말풍선에서 처음 어긋난 층을 깜빡이게 표시해 둔다.
func _serve(slot: int = -1) -> void:
	var tgt := slot if slot >= 0 else g.match_slot()
	if tgt < 0:
		tgt = g._urgent()
	if tgt >= 0 and g.complete() and g.cust[tgt] != null:
		var order: Array = g.cust[tgt].order
		var ids := g.stack_ids()
		for i in order.size():
			if i >= ids.size() or ids[i] != order[i]:
				marks[tgt] = {i = i, t = 1.6}
				break
	g.serve(slot)

# ==================== 자리 ====================


func _back_btn() -> Rect2:
	return Hub.std_rect("hub", vs)


func _vol_btn() -> Rect2:
	return Hub.std_rect("vol", vs)


func _rules_rect() -> Rect2:
	if scr == Scr.PLAY:
		return Hub.std_rect("rules", vs)
	return Rect2(Hub.std_rect("vol", vs).position.x - 150, Hub.std_rect("vol", vs).position.y, 136, Hub.std_rect("vol", vs).size.y)


## 손님 자리의 폭 · 가운데.
func _slot_w() -> float:
	return 1180.0 / g.slots()


func _cust_pos(i: int) -> Vector2:
	return Vector2(50.0 + _slot_w() * (i + 0.5) - _slot_w() * 0.22, COUNTER_Y)


func _bubble_rect(i: int) -> Rect2:
	var cx := 50.0 + _slot_w() * (i + 0.5)
	return Rect2(cx - 6.0, 58, minf(156.0, _slot_w() * 0.44), 236)


func _cust_rect(i: int) -> Rect2:
	var p := _cust_pos(i)
	return Rect2(p.x - 80, p.y - 180, 160, 180).merge(_bubble_rect(i))


## 철판의 i 번째 칸 — 철판 그림의 굽는 판(몸통 폭의 가운데 70%, 위쪽 3분의 2) 안에 나란히.
func _grill_rect(i: int) -> Rect2:
	var b := _grill_body()
	var sw := b.size.x * 0.70 / g.grill_n()
	return Rect2(b.position.x + b.size.x * 0.15 + i * sw, b.position.y + 6, sw, 88)


func _grill_body() -> Rect2:
	return Rect2(34, 372, 100.0 * g.grill_n() + 36, 138)


func _board_rect() -> Rect2:
	return Rect2(BOARD.x - 150, BOARD.y - 40, 300, 84)


## 포장지 더미 — 조립대 왼쪽 끝.
func _wrap_rect() -> Rect2:
	return Rect2(BOARD.x - 150, BOARD.y - 74, 50, 58)


func _trash_rect() -> Rect2:
	return Rect2(796, 420, 62, 90)


## 음료 기계(그림 — 꼭지 넷이 나란한 탄산 기계) · 튀김기.
func _side_rect(kind: String) -> Rect2:
	return Rect2(864, 322, 186, 170) if kind == "drink" else Rect2(1056, 392, 92, 120)


## 음료 기계의 j 번째 칸(상표 그림 · 꼭지 · 단추가 세로로 있는 판) — 누르고 있으면 그 음료를 따른다.
func _tap_rect(j: int) -> Rect2:
	var mr := _side_rect("drink")
	return Rect2(mr.position.x + mr.size.x * (0.07 + 0.215 * j), mr.position.y + mr.size.y * 0.2, mr.size.x * 0.215, mr.size.y * 0.5)


## 가루 양념 통 다섯 — 튀김기 위쪽에 나란히.
func _dip_rect(j: int) -> Rect2:
	return Rect2(1058 + j * 42.0, 336, 40, 46)


## 쟁반 — 조립대 오른쪽 끝의 음료 · 감자튀김 자리(누르면 버린다).
func _tray_drink() -> Rect2:
	return Rect2(BOARD.x + 100, BOARD.y - 62, 44, 60)


func _tray_fries() -> Rect2:
	return Rect2(BOARD.x + 146, BOARD.y - 62, 52, 60)


func _register_rect() -> Rect2:
	return Rect2(1158, 410, 104, 100)


## 재료 통(분류) 여섯 — 선반 왼쪽에 세 개씩 두 줄.
func _cat_rect(c: int) -> Rect2:
	return Rect2(26 + (c % 3) * 122.0, 532 + int(c / 3) * 90.0, 116, 84)


## 지금 펼쳐진 통에 든 재료(오늘 선반에 있는 것만).
func _cat_items(cat: String = "") -> Array:
	if cat == "":
		cat = open_cat
	return g.shelf.filter(func(id): return BgD.cat(String(id)) == cat)


## 펼쳐진 통의 k 번째 재료 칸 — 선반 오른쪽 넓은 자리에 한 줄.
func _bin_rect(k: int) -> Rect2:
	var n := maxi(1, _cat_items().size())
	var w := minf(140.0, 850.0 / n)
	return Rect2(404 + k * w + 3, 540, w - 6, 164)


func _day_rect(k: int) -> Rect2:
	return Rect2(70 + (k % 10) * 114, 110 + int(k / 10) * 150, 106, 138)


func _shop_btn() -> Rect2:
	return Rect2(18, vs.y - 96, 300, 76)


func _ing_rect(k: int) -> Rect2:
	return Rect2(24 + (k % 6) * 134, 96 + int(k / 6) * 86, 128, 80)


func _up_rect(k: int) -> Rect2:
	return Rect2(846, 96 + k * 74, 414, 68)


func _modal_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 250 + k * 260, vs.y * 0.5 + 40, 240, 64)


func _end_btn(k: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 330 + k * 225, vs.y * 0.5 + 170, 210, 62)

# ==================== 입력 ====================


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
		_on_key(key.keycode)
		return
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_click(mb.position)
		else:
			pour_hold = -1
	elif mb != null and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and scr == Scr.PLAY and g != null and not _paused():
		# 오른쪽 단추 — 치즈는 철판의 패티 위에 얹어 녹이고, 야채는 미리 썰어 채운다
		var items := _cat_items()
		for k in items.size():
			if _bin_rect(k).has_point(mb.position):
				_alt(String(items[k]))


## 재료의 "다른 쓰임" — 치즈: 철판의 패티에 얹어 녹이기, 야채: 미리 썰기(오른쪽 단추 · Shift + 숫자).
func _alt(id: String) -> void:
	match BgD.cat(id):
		"cheese":
			g.melt(id)
		"veg":
			g.prep(id)


func _is(kc: int, row: int) -> bool:
	return kc == UiKeys.code("burger", String(KEYS[row][0]), int(KEYS[row][2]))


func _on_key(kc: int) -> void:
	if kc == KEY_ESCAPE:
		_escape()
		return
	match scr:
		Scr.TITLE:
			if kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
				scr = Scr.DAYS
		Scr.DAYS:
			if kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and BgSv.open(pick):
				_start()
			elif kc == KEY_LEFT or kc == KEY_RIGHT:
				pick = clampi(pick + (1 if kc == KEY_RIGHT else -1), 0, BgD.DAYS - 1)
			elif kc == KEY_UP or kc == KEY_DOWN:
				pick = clampi(pick + (10 if kc == KEY_DOWN else -10), 0, BgD.DAYS - 1)
		Scr.PLAY:
			if g == null or _paused():
				if end_open and kc in [KEY_ENTER, KEY_KP_ENTER]:
					scr = Scr.DAYS
				return
			if _is(kc, 0):
				_serve()
			elif _is(kc, 1):
				g.trash()
			elif _is(kc, 10):
				g.fry_tap()
			elif _is(kc, 11):
				g.wrap_up()
			else:
				for i in 4:
					if _is(kc, 2 + i):
						g.grill_take(i)
						return
				for row: Array in CATS:   # 통 고르기
					if kc == int(row[2]) and not _cat_items(String(row[0])).is_empty():
						open_cat = String(row[0])
						BgSnd.play("tick")
						return
				var k := NUM_KEYS.find(kc)
				var items := _cat_items()
				if k >= 0 and k < items.size():
					if Input.is_key_pressed(KEY_SHIFT):
						_alt(String(items[k]))
					else:
						g.tap(String(items[k]))


func _escape() -> void:
	match scr:
		Scr.TITLE:
			Hub.leave(self)
		Scr.DAYS:
			scr = Scr.TITLE
		Scr.SHOP:
			scr = Scr.DAYS
		Scr.PLAY:
			if end_open:
				scr = Scr.DAYS
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
				scr = Scr.DAYS
				BgSnd.play("tick")
			elif _rules_rect().has_point(p):
				_open_rules()
			elif UiKit.menu_rect(vs, 0).has_point(p):
				keys.show("burger", KEYS)
		Scr.DAYS:
			if _back_btn().has_point(p):
				scr = Scr.TITLE
			elif Hub.std_rect("start", vs).has_point(p):
				if BgSv.open(pick):
					_start()
			elif _shop_btn().has_point(p):
				scr = Scr.SHOP
				BgSnd.play("tick")
			else:
				for k in BgD.DAYS:
					if _day_rect(k).has_point(p):
						pick = k
						BgSnd.play("tick")
		Scr.SHOP:
			if _back_btn().has_point(p):
				scr = Scr.DAYS
				return
			for k in BgD.ORDER.size():
				if _ing_rect(k).has_point(p):
					_buy_ing(String(BgD.ORDER[k]))
					return
			for k in BgD.UP.size():
				if _up_rect(k).has_point(p):
					_buy_up(String(BgD.UP[k][0]))
					return
		Scr.PLAY:
			_click_play(p)


func _buy_ing(id: String) -> void:
	if BgSv.unlocked.has(id) or BgSv.money < BgD.unlock_cost(id):
		BgSnd.play("tick", 0.6)
		return
	BgSv.money -= BgD.unlock_cost(id)
	BgSv.unlocked.append(id)
	if not no_save:
		BgSv.save_()
	BgSnd.play("buy")


func _buy_up(key: String) -> void:
	var cost := BgSv.up_cost(key)
	if cost < 0 or BgSv.money < cost:
		BgSnd.play("tick", 0.6)
		return
	BgSv.money -= cost
	BgSv.up[key] = int(BgSv.up[key]) + 1
	if not no_save:
		BgSv.save_()
	BgSnd.play("buy")


func _click_play(p: Vector2) -> void:
	if g == null:
		return
	if end_open:
		if end_t < 1.0:
			return
		if _end_btn(0).has_point(p):      # 다음 날
			if g.stars() > 0 and g.day + 1 < BgD.DAYS:
				pick = g.day + 1
				_start()
		elif _end_btn(1).has_point(p):    # 가게
			scr = Scr.SHOP
		elif _end_btn(2).has_point(p):    # 다시
			_start()
		return
	if modal == "quit":
		if _modal_btn(0).has_point(p):
			scr = Scr.DAYS
		elif _modal_btn(1).has_point(p):
			modal = ""
		return
	if _back_btn().has_point(p):
		modal = "quit"
		return
	if _rules_rect().has_point(p):
		_open_rules()
		return
	for c in CATS.size():
		if _cat_rect(c).has_point(p):
			if not _cat_items(String(CATS[c][0])).is_empty():
				open_cat = String(CATS[c][0])
				BgSnd.play("tick")
			return
	var items := _cat_items()
	for k in items.size():
		if _bin_rect(k).has_point(p):
			g.tap(String(items[k]))
			return
	if g.grill_on():
		for i in g.grill_n():
			if _grill_rect(i).has_point(p):
				g.grill_take(i)
				return
	if bool(g.cfg.wrap) and _wrap_rect().has_point(p):
		g.wrap_up()
		return
	if _trash_rect().has_point(p):
		g.trash()
		return
	if g.set_on("drink"):
		for j in 4:
			if _tap_rect(j).has_point(p):
				pour_hold = j
				return
		if _tray_drink().has_point(p) and (String(g.side.drink) != "" or String(g.pour.type) != ""):
			g.dump_drink()
			return
	if g.set_on("fries"):
		if _side_rect("fries").has_point(p):
			g.fry_tap()
			return
		for j in BgD.DIP_IDS.size():
			if _dip_rect(j).has_point(p):
				g.dip(String(BgD.DIP_IDS[j]))
				return
		if _tray_fries().has_point(p) and bool(g.side.fries):
			g.dump_fries()
			return
	for i in g.slots():
		if g.cust[i] != null and _cust_rect(i).has_point(p):
			_serve(i)
			return
	if _board_rect().grow(30).has_point(p):
		_serve()

# ==================== 그리기 ====================


func _btn(r: Rect2, label: String, fill: Color, size: float = 24.0, on: bool = true) -> void:
	UiKit.plain(self, r, label, fill, "burger", t, on, size)


func _draw() -> void:
	Hub.compact = scr == Scr.PLAY   # 판 화면은 아이콘 단추
	match scr:
		Scr.TITLE:
			_draw_title()
		Scr.DAYS:
			_draw_days()
		Scr.SHOP:
			_draw_shop()
		Scr.PLAY:
			if g != null:
				_draw_play()
	Vol.draw(self, vs, t)


func _draw_bg(dim: float) -> void:
	var bg := BgArt.img("bg_shop_%d" % int(BgSv.up.get("decor", 0)))
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
	else:
		draw_rect(Rect2(0, 0, vs.x, COUNTER_Y), BgArt.CREAM)
		draw_rect(Rect2(0, COUNTER_Y, vs.x, 200), BgArt.WOOD)
		draw_rect(Rect2(0, COUNTER_Y + 200, vs.x, vs.y), BgArt.RED.darkened(0.2))
	if dim > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.16, 0.08, 0.05, dim))


func _draw_title() -> void:
	var bg := BgArt.img("bg_title")
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vs), false)
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.16, 0.08, 0.05, 0.45))
	else:
		_draw_bg(0.3)
	UiKit.title(self, vs, "burger", "버거왕", "주문 사진을 보고 재료를 차곡차곡 쌓아요", t)
	if BgSv.cleared() > 0:
		UiKit.record_line(self, vs, "%d일째까지 영업, 가진 돈 %d" % [BgSv.cleared(), BgSv.money])
	UiKit.key_hint(self, vs, "재료는 마우스나 숫자키, %s 버거 내기, %s 버리기" % [OS.get_keycode_string(UiKeys.code("burger", "serve", KEY_SPACE)),
			OS.get_keycode_string(UiKeys.code("burger", "trash", KEY_BACKSPACE))])
	UiKit.button(self, vs, "start", "burger", t)
	UiKit.button(self, vs, "hub", "burger", t)
	UiKit.button(self, vs, "vol", "burger", t)
	UiKit.menu(self, UiKit.menu_rect(vs, 0), "키 설정", BgArt.RED, "burger", t)
	UiKit.plain(self, _rules_rect(), "규칙", UiKit.theme("burger").hub, "burger", t, true, 24)
	rules.draw(self, vs, t)
	keys.draw(self, vs, t)


func _draw_days() -> void:
	_draw_bg(0.62)
	G2.text_mid(self, Vector2(vs.x * 0.5, 62), "%d일째" % (pick + 1), 34, BgArt.HEAD, 6)
	for k in BgD.DAYS:
		var r := _day_rect(k)
		var open := BgSv.open(k)
		BgArt.rr(self, r, 16, BgArt.CREAM if open else Color8(120, 100, 90), BgArt.MUSTARD if k == pick else BgArt.INK, 6.0 if k == pick else 3.0)
		G2.text_mid(self, r.get_center() + Vector2(0, -34), "%d" % (k + 1), 34, BgArt.INK if open else Color8(70, 56, 50))
		for j in 3:
			BgArt.star(self, Vector2(r.get_center().x + (j - 1) * 28.0, r.get_center().y + 14), 13.0, int(BgSv.stars[k]) > j)
		if int(BgSv.best[k]) > 0:
			G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 18), "%d" % int(BgSv.best[k]), 18, Color8(150, 96, 40))
	var cfg := BgD.day(pick)
	var info := "목표 %d, 재료 %d가지, 버거 높이 %d~%d" % [int(cfg.goal), mini(int(cfg.shelf_n), BgSv.unlocked.size()), int(cfg.lay_min), int(cfg.lay_max)]
	if bool(cfg.grill):
		info += ", 패티 굽기"
	if bool(cfg.special):
		info += ", 특별 손님"
	G2.text_mid(self, Vector2(vs.x * 0.5, 590), info, 24, BgArt.HEAD, 5)
	if not BgSv.open(pick):
		G2.text_mid(self, Vector2(vs.x * 0.5, 628), "앞날의 목표 금액을 채워야 열려요", 22, Color8(255, 190, 150), 5)
	_btn(_shop_btn(), "가게 꾸리기   가진 돈 %d" % BgSv.money, BgArt.MUSTARD, 24)
	UiKit.button(self, vs, "start", "burger", t, "영업 시작")
	UiKit.button(self, vs, "hub", "burger", t, "뒤로")
	UiKit.button(self, vs, "vol", "burger", t)


func _draw_shop() -> void:
	_draw_bg(0.7)
	G2.text_mid(self, Vector2(vs.x * 0.5, 50), "가게 꾸리기   가진 돈 %d" % BgSv.money, 32, BgArt.HEAD, 6)
	var mp := get_local_mouse_position()
	var tip := ""
	for k in BgD.ORDER.size():
		var id := String(BgD.ORDER[k])
		var r := _ing_rect(k)
		var have := BgSv.unlocked.has(id)
		var can := BgSv.money >= BgD.unlock_cost(id)
		BgArt.rr(self, r, 12, BgArt.CREAM if have else Color8(96, 80, 74), BgArt.MUSTARD if not have and can else BgArt.INK, 3.0)
		BgArt.icon(self, id, Rect2(r.position + Vector2(8, 4), Vector2(r.size.x - 16, 44)), Color.WHITE if have else Color(0.55, 0.55, 0.55))
		G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 16), BgD.name_of(id) if have else "%d" % BgD.unlock_cost(id), 17,
				BgArt.INK if have else (Color8(255, 226, 130) if can else Color8(200, 170, 160)))
		if r.has_point(mp):
			tip = "%s  (버거 값 +%d)" % [BgD.name_of(id), BgD.price(id)] + ("" if have else "  눌러서 %d 에 열기" % BgD.unlock_cost(id))
	for k in BgD.UP.size():
		var row: Array = BgD.UP[k]
		var r := _up_rect(k)
		var lv := int(BgSv.up[row[0]])
		var cost := BgSv.up_cost(String(row[0]))
		var can := cost >= 0 and BgSv.money >= cost
		BgArt.rr(self, r, 12, BgArt.CREAM, BgArt.MUSTARD if can else BgArt.INK, 3.0)
		G2.text_mid(self, Vector2(r.position.x + 150, r.position.y + 22), String(row[1]), 22, BgArt.INK)
		G2.text_mid(self, Vector2(r.position.x + 150, r.position.y + 48), String(row[2]), 15, Color8(130, 90, 70))
		for j in (row[3] as Array).size():
			draw_circle(Vector2(r.end.x - 110 + j * 20, r.position.y + 20), 7.0, BgArt.GREEN if j < lv else Color8(200, 186, 170))
		G2.text_mid(self, Vector2(r.end.x - 64, r.position.y + 48), "다 올렸어요" if cost < 0 else "%d" % cost, 18 if cost < 0 else 22,
				Color8(110, 150, 90) if cost < 0 else (Color8(190, 110, 20) if can else Color8(170, 150, 140)))
	if tip != "":
		G2.text_mid(self, Vector2(430, vs.y - 26), tip, 22, BgArt.HEAD, 5)
	UiKit.button(self, vs, "hub", "burger", t, "뒤로")
	UiKit.button(self, vs, "vol", "burger", t)


func _draw_play() -> void:
	var off := Vector2.ZERO
	if shake > 0.0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 16.0
	draw_set_transform(off)
	_draw_bg(0.0)
	# 손님과 주문 말풍선
	for i in g.slots():
		var c = g.cust[i]
		if c == null:
			continue
		var k := float(c.pat) / float(c.max)
		var mood := 0 if String(c.state) == "happy" else (3 if String(c.state) == "angry" else (0 if k > 0.75 else (1 if k > 0.45 else (2 if k > 0.2 else 3))))
		var p := _cust_pos(i)
		var slide := 0.0
		if String(c.state) != "wait":
			slide = float(c.t) / BgD.LEAVE_T
		var ch := 176.0 * (0.78 if String(c.kind) == "kid" else 1.0)
		draw_set_transform(off + Vector2(0, slide * slide * 220.0))
		BgArt.customer(self, int(c.face), mood, p, ch, t + i)
		draw_set_transform(off)
		if String(c.state) != "wait":
			continue
		var b := _bubble_rect(i)
		BgArt.bubble(self, b)
		var order: Array = c.order
		var sides := int(String(c.drink) != "") + int(bool(c.fries))
		var room := b.size.y - 46.0 - (40.0 if sides > 0 else 0.0)
		var w := minf(b.size.x - 30.0, 110.0)
		var h := BgArt.stack_h(order, w)
		if h > room:
			w *= room / h
		var mk: int = int(marks[i].i) if marks.has(i) else -1
		BgArt.stack(self, order, Vector2(b.get_center().x, b.position.y + 14.0 + room - (room - BgArt.stack_h(order, w)) * 0.5), w, -1.0, mk, t)
		if sides > 0:
			var sx := b.get_center().x - (sides - 1) * 22.0
			if String(c.drink) != "":
				_drink_icon(String(c.drink), Rect2(sx - 18, b.end.y - 72, 36, 42))
				sx += 44.0
			if bool(c.fries):
				_fries_icon(String(c.dip), Rect2(sx - 20, b.end.y - 72, 40, 42))
		# 참을성 막대
		var bar := Rect2(b.position.x + 14, b.end.y - 26, b.size.x - 28, 12)
		BgArt.rr(self, bar, 6, Color8(226, 214, 200), BgArt.INK, 2.0)
		BgArt.rr(self, Rect2(bar.position + Vector2(2, 2), Vector2(maxf(4.0, (bar.size.x - 4) * clampf(k, 0.0, 1.0)), 8)), 4,
				BgArt.GREEN if k > 0.45 else (BgArt.MUSTARD if k > 0.2 else BgArt.RED))
		if bool(c.wrap):   # 포장 손님 — 말풍선 오른쪽 위에 봉투
			var bagr := Rect2(b.end.x - 34, b.position.y - 12, 40, 44)
			var bag := BgArt.img("bg_bag")
			if bag != null:
				BgArt.fit(self, bag, bagr)
			else:
				BgArt.rr(self, bagr, 6, Color8(200, 150, 100), BgArt.INK, 3.0)
		var krow: Array = BgD.KIND[c.kind]
		if String(krow[0]) != "":
			var tag := String(krow[0]) + (" %d개 더" % int(c.left) if String(c.kind) == "group" else "")
			G2.text_mid(self, Vector2(p.x, p.y - ch - 12), tag, 20, Color8(255, 236, 150), 5)
	# 철판
	if g.grill_on():
		var gb := _grill_body()
		var gt := BgArt.img("bg_tool_griddle")
		if gt != null:
			draw_texture_rect(gt, gb, false)
		else:
			BgArt.rr(self, gb, 14, BgArt.RED, BgArt.INK, 4.0)
			BgArt.rr(self, gb.grow(-14), 8, Color8(70, 66, 70))
		for i in g.grill_n():
			var r := _grill_rect(i)
			var s = g.grill[i]
			if s == null:
				continue
			var st := g.patty_state(s)
			# 안 뒤집은 면은 분홍(날것), 뒤집었거나 다 익었으면 제 색, 타면 검게
			var pink: bool = st == "raw" and (not bool(g.cfg.flip) or not bool(s.flipped))
			var col := Color(1.0, 0.78, 0.78) if pink else (Color(0.28, 0.24, 0.22) if st == "burnt" else Color.WHITE)
			var pr := Rect2(r.position + Vector2(4, 22), Vector2(r.size.x - 8, 36))
			var fq := float(flip_t.get(i, 9.0)) / 0.28
			if fq < 1.0:   # 휙 뒤집힌다 — 솟았다가 세로로 접혔다 펴진다
				var sy := absf(cos(fq * PI))
				pr = Rect2(pr.position.x, pr.get_center().y - pr.size.y * sy * 0.5 - sin(fq * PI) * 26.0, pr.size.x, maxf(2.0, pr.size.y * sy))
			var ptx := BgArt.layer_tex(String(s.id))
			if ptx != null:
				if fq < 1.0:
					draw_texture_rect(ptx, pr, false, col)
				else:
					BgArt.fit(self, ptx, pr, col)
			else:
				BgArt.rr(self, Rect2(r.position + Vector2(8, 28), Vector2(r.size.x - 16, 22)), 10, BgArt.CAT.patty[2] * col, BgArt.INK, 2.0)
			if String(s.cheese) != "":   # 얹은 치즈 — 녹을수록 넓게 퍼진다
				var mk2 := clampf(float(s.ct) / BgD.MELT_T, 0.0, 1.0)
				var ctx2 := BgArt.layer_tex(String(s.cheese))
				var cr := Rect2(pr.get_center().x - pr.size.x * (0.3 + 0.2 * mk2), pr.position.y - 2.0, pr.size.x * (0.6 + 0.4 * mk2), 14.0 + 10.0 * mk2)
				if ctx2 != null:
					draw_texture_rect(ctx2, cr, false)
				else:
					BgArt.rr(self, cr, 5, BgArt.MUSTARD, BgArt.INK, 2.0)
			var steam := BgArt.img("bg_steam")
			if steam != null and st != "burnt":
				var q := fposmod(t * 0.8 + i * 0.37, 1.0)
				BgArt.fit(self, steam, Rect2(r.get_center().x - 14, r.position.y + 10 - q * 34.0, 28, 28), Color(1, 1, 1, (1.0 - q) * 0.8))
			_cook_bar(Rect2(r.position.x + 6, r.end.y - 22, r.size.x - 12, 12), float(s.t), g.side_t(), g.good_t())
			if (st == "good" or st == "flip") and fmod(t, 0.5) < 0.25:
				var waitm := st == "good" and String(s.cheese) != "" and float(s.ct) < BgD.MELT_T
				G2.text_mid(self, Vector2(r.get_center().x, r.position.y + 6), "뒤집기" if st == "flip" else ("녹는 중" if waitm else "지금"), 18,
						Color8(255, 236, 150) if st == "flip" or waitm else Color8(170, 255, 150), 5)
	# 조립대와 쌓는 버거
	var board := BgArt.img("bg_tool_board")
	if board != null:
		draw_texture_rect(board, _board_rect(), false)
	else:
		BgArt.rr(self, _board_rect(), 14, Color8(230, 180, 110), BgArt.INK, 4.0)
	if not g.stack.is_empty():
		var ids2 := g.stack_ids()
		var top_id := String(ids2[ids2.size() - 1])
		var is_sauce := BgD.cat(top_id) == "sauce"
		var dk := drop_t / (0.5 if is_sauce else 0.32)
		BgArt.stack(self, ids2, BOARD, STACK_W, dk)
		if is_sauce and dk < 1.15:
			# 소스 병 — 거꾸로 들고 버거 위를 왼쪽에서 오른쪽으로 지나가며 짠다(사용자 요청 11-10). 끝나면 위로 빠진다
			var bt := BgArt.img("bg_bottle")
			var q := clampf(dk, 0.0, 1.0)
			var sw := STACK_W * 0.86
			var tip := Vector2(BOARD.x - sw * 0.5 + sw * q, BOARD.y - BgArt.stack_h(ids2, STACK_W) - 6.0 - maxf(0.0, dk - 1.0) * 260.0)
			var scol: Color = BgD.SAUCE_COL.get(top_id, Color.WHITE)
			if q < 1.0:
				draw_line(tip, tip + Vector2(0, 14), scol, 5.0)   # 떨어지는 줄기
			if bt != null:
				draw_set_transform(off + tip + Vector2(0, -4), PI + sin(t * 30.0) * 0.06, Vector2.ONE)
				draw_texture_rect(bt, Rect2(-22, 0, 44, 44.0 * bt.get_height() / bt.get_width()), false, scol)
				draw_set_transform(off)
		if g.complete() and g.match_slot() >= 0 and fmod(t, 0.6) < 0.4:
			G2.text_mid(self, BOARD + Vector2(0, 34), "%s 로 내요" % OS.get_keycode_string(UiKeys.code("burger", "serve", KEY_SPACE)), 20, Color8(170, 255, 150), 5)
	if bool(g.cfg.wrap):
		var ws := BgArt.img("bg_wrap_stack")
		if ws != null:
			BgArt.fit(self, ws, _wrap_rect())
		else:
			BgArt.rr(self, _wrap_rect(), 6, Color.WHITE, BgArt.RED, 3.0)
		if _wrap_rect().has_point(get_local_mouse_position()):
			G2.text_mid(self, _wrap_rect().get_center() + Vector2(0, -44), "포장 %s" % OS.get_keycode_string(UiKeys.code("burger", "wrap", KEY_P)), 18, BgArt.HEAD, 5)
	if g.wrapped and not g.stack.is_empty():   # 포장지가 버거 아래쪽을 감싼다
		var sh := BgArt.stack_h(g.stack_ids(), STACK_W)
		var sl := BgArt.img("bg_wrap_sleeve")
		var wr2 := Rect2(BOARD.x - STACK_W * 0.6, BOARD.y - sh * 0.7, STACK_W * 1.2, sh * 0.7 + 8.0)
		if sl != null:
			draw_texture_rect(sl, wr2, false)
		else:
			BgArt.rr(self, wr2, 10, Color(1, 1, 1, 0.92), BgArt.RED, 3.0)
	if String(g.side.drink) != "":
		_drink_icon(String(g.side.drink), _tray_drink())
	if bool(g.side.fries):
		_fries_icon(String(g.side.dip) if dip_t >= 0.55 else "", _tray_fries())
		if dip_t < 0.55 and String(g.side.dip) != "":
			# 가루 양념 — 통을 거꾸로 들고 감자튀김 위에서 흔들어 뿌린다. 가루가 떨어진다
			var sid := String(g.side.dip)
			var top := Vector2(_tray_fries().get_center().x + sin(t * 46.0) * 7.0, _tray_fries().position.y - 26.0 + absf(sin(t * 46.0)) * 6.0)
			var scol: Color = BgD.DIPS[sid][1]
			for j in 9:
				var q3 := fposmod(dip_t * 3.2 + j * 0.111, 1.0)
				draw_circle(top + Vector2((j - 4) * 4.0 + sin(j * 2.3) * 3.0, 8.0 + q3 * 34.0), 2.2, Color(scol, 1.0 - q3))
			var stx := BgArt.img("bg_" + sid)
			if stx != null:
				draw_set_transform(off + top, PI + sin(t * 46.0) * 0.28, Vector2.ONE)
				draw_texture_rect(stx, Rect2(-17, -2, 34, 34.0 * stx.get_height() / stx.get_width()), false)
				draw_set_transform(off)
	# 쓰레기통 · 곁들임 · 금고
	var tt := BgArt.img("bg_tool_trash")
	if tt != null:
		BgArt.fit(self, tt, _trash_rect())
	else:
		BgArt.rr(self, _trash_rect(), 10, Color8(150, 156, 166), BgArt.INK, 4.0)
	_draw_drink_station()
	_draw_fry_station()
	var reg := BgArt.img("bg_tool_register")
	if reg != null:
		BgArt.fit(self, reg, _register_rect())
	else:
		BgArt.rr(self, _register_rect(), 10, BgArt.RED, BgArt.INK, 4.0)
	# 선반 — 왼쪽에 재료 통 여섯, 오른쪽에 펼쳐진 통의 재료
	var mp := get_local_mouse_position()
	var cats := BgArt.img("bg_cat_0") != null
	for c in CATS.size():
		var cid := String(CATS[c][0])
		var r := _cat_rect(c)
		var has := not _cat_items(cid).is_empty()
		var on := open_cat == cid
		var hot := has and r.has_point(mp) and not _paused()
		BgArt.rr(self, r.grow(3.0 if on else 0.0), 14, (BgArt.MUSTARD.lightened(0.55) if on else (BgArt.CREAM.lightened(0.5) if hot else BgArt.CREAM)) if has else Color8(150, 130, 120),
				BgArt.MUSTARD if on or hot else BgArt.INK, 5.0 if on else 3.0)
		var pic := Rect2(r.position + Vector2(8, 4), Vector2(r.size.x - 16, r.size.y - 30))
		if cats:
			BgArt.fit(self, BgArt.img("bg_cat_%d" % c), pic, Color.WHITE if has else Color(0.5, 0.5, 0.5, 0.7))
		elif has:
			BgArt.icon(self, String(_cat_items(cid)[0]), pic)
		G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 14), "%s (%d)" % [String(CATS[c][1]), _cat_items(cid).size()] if has else String(CATS[c][1]), 17,
				BgArt.INK if has else Color8(90, 76, 70))
		draw_circle(r.position + Vector2(13, 13), 11.0, BgArt.INK if has else Color8(110, 96, 90))
		G2.text_mid(self, r.position + Vector2(13, 13), OS.get_keycode_string(int(CATS[c][2])), 15, Color.WHITE)
	var items := _cat_items()
	for k in items.size():
		var id := String(items[k])
		var r := _bin_rect(k)
		var hot := r.has_point(mp) and not _paused()
		BgArt.rr(self, r, 14, BgArt.CREAM.lightened(0.5) if hot else BgArt.CREAM, BgArt.MUSTARD if hot else BgArt.INK, 4.0 if hot else 3.0)
		var left := int(g.stock.get(id, 1))
		var chopping := g.chop.has(id)
		BgArt.icon(self, id, Rect2(r.position + Vector2(10, 14), Vector2(r.size.x - 20, r.size.y - 60)), Color(1, 1, 1, 0.3) if left <= 0 or chopping else Color.WHITE)
		if g.stock.has(id):
			if chopping:   # 써는 중 — 칼이 오르내리고 막대가 찬다
				var kn := BgArt.img("bg_knife")
				if kn != null:
					BgArt.fit(self, kn, Rect2(r.get_center().x - 34, r.position.y + 22 + absf(sin(t * 22.0)) * 16.0, 68, 40))
				var cb := Rect2(r.position.x + 12, r.end.y - 50, r.size.x - 24, 10)
				draw_rect(cb, Color8(226, 214, 200))
				draw_rect(Rect2(cb.position, Vector2(cb.size.x * float(g.chop[id]) / BgD.PREP_T, cb.size.y)), BgArt.GREEN)
				draw_rect(cb, BgArt.INK, false, 2.0)
			elif left <= 0:
				G2.text_mid(self, r.get_center() + Vector2(0, -16), "눌러서 썰기", 17, BgArt.RED)
			else:
				for q2 in BgD.PREP_N:   # 남은 양
					draw_circle(Vector2(r.end.x - 14, r.position.y + 14 + q2 * 9.0), 3.5, BgArt.GREEN if q2 < left else Color8(210, 200, 190))
		G2.text_mid(self, Vector2(r.get_center().x, r.end.y - 20), BgD.name_of(id), 18 if r.size.x > 100 else 15, BgArt.INK)
		draw_circle(r.position + Vector2(15, 15), 12.0, BgArt.INK)
		G2.text_mid(self, r.position + Vector2(15, 15), "%d" % ((k + 1) % 10), 16, Color.WHITE)
	# 날아가는 동전 · 떠오르는 글
	var coin := BgArt.img("bg_coin")
	for c: Dictionary in coins:
		if float(c.t) < 0.0:
			continue
		var q := G2.smooth(float(c.t))
		var at: Vector2 = (c.a as Vector2).lerp(c.b, q) + Vector2(0, -sin(q * PI) * 90.0)
		if coin != null:
			BgArt.fit(self, coin, Rect2(at - Vector2(14, 14), Vector2(28, 28)))
		else:
			draw_circle(at, 10.0, BgArt.MUSTARD)
	for p: Dictionary in pops:
		var k2 := maxf(0.0, float(p.t)) / 1.1   # t 가 음수인 동안은 그대로 떠 있다(오래 보여 줄 글)
		G2.text_mid(self, p.p + Vector2(0, -36.0 * k2), String(p.txt), 26, Color(p.col, 1.0 - k2 * k2), 6)
	draw_set_transform(Vector2.ZERO)
	_draw_hud()
	if modal == "" and not end_open and not rules.open:
		_draw_order_zoom()
	if modal == "quit":
		_draw_modal("영업을 그만둘까요?", ["그만두기", "계속하기"])
	if end_open:
		_draw_end()
	rules.draw(self, vs, t)


## 주문 크게 보기 — 손님(이나 말풍선)에 마우스를 올리면 그 주문을 크게 띄우고 **재료 이름을 위에서부터** 적는다.
## 작은 말풍선에서는 마요와 타르타르, 치킨과 새우 패티처럼 비슷한 것을 가르기 어렵다.
func _draw_order_zoom() -> void:
	var mp := get_local_mouse_position()
	for i in g.slots():
		var c = g.cust[i]
		if c == null or String(c.state) != "wait" or not _cust_rect(i).has_point(mp):
			continue
		var order: Array = c.order
		var extra := int(String(c.drink) != "") + int(bool(c.fries)) + int(bool(c.wrap))
		var rows := order.size() + extra
		var ph := maxf(250.0, 64.0 + rows * 25.0)
		var b := _bubble_rect(i)
		var px := b.end.x + 10.0
		if px + 380.0 > vs.x - 10.0:
			px = _cust_rect(i).position.x - 390.0
		var panel := Rect2(clampf(px, 10.0, vs.x - 390.0), 56, 380, ph)
		BgArt.rr(self, panel, 18, Color(1, 1, 1, 0.97), BgArt.INK, 4.0)
		var w := 130.0
		var h := BgArt.stack_h(order, w)
		if h > ph - 40.0:
			w *= (ph - 40.0) / h
		BgArt.stack(self, order, Vector2(panel.position.x + 84, panel.end.y - 20.0 - (ph - 40.0 - BgArt.stack_h(order, w)) * 0.5), w)
		var y := panel.position.y + 30.0
		for k in range(order.size() - 1, -1, -1):   # 맨 위 층부터
			var id := String(order[k])
			var done := k < g.stack.size() and String(g.stack[k].id) == id
			G2.text_mid(self, Vector2(panel.position.x + 272, y), ("%d. " % (k + 1)) + BgD.name_of(id), 19, Color8(110, 160, 90) if done else BgArt.INK)
			y += 25.0
		if String(c.drink) != "":
			G2.text_mid(self, Vector2(panel.position.x + 272, y), "음료: " + String(BgD.DRINKS[c.drink][0]), 19, Color8(60, 110, 170))
			y += 25.0
		if bool(c.fries):
			G2.text_mid(self, Vector2(panel.position.x + 272, y), "감자튀김: " + String(BgD.DIPS.get(c.dip, ["가루 없이"])[0]), 19, Color8(60, 110, 170))
			y += 25.0
		if bool(c.wrap):
			G2.text_mid(self, Vector2(panel.position.x + 272, y), "포장해서", 19, Color8(190, 70, 60))
		return


## 음료 기계 — 진짜 탄산 기계처럼 칸 넷에 상표 그림 · 꼭지 · 단추가 있다(사용자 요청 11-10). 칸을 누르고 있으면 그 꼭지에서 줄기가 나와
## 밑에 놓인 컵이 찬다. 컵 옆의 막대: 흰 선을 넘겨 떼면 되고 빨간 데까지 가면 넘친다.
func _draw_drink_station() -> void:
	if not g.set_on("drink"):
		return
	var mr := _side_rect("drink")
	var mt := BgArt.img("bg_tool_machine")
	if mt != null:
		draw_texture_rect(mt, mr, false)
	else:
		BgArt.rr(self, mr, 12, BgArt.RED, BgArt.INK, 4.0)
	var mp := get_local_mouse_position()
	for j in 4:
		var id := String(BgD.DRINK_IDS[j])
		var r := _tap_rect(j)
		var cx := r.get_center().x
		var on := String(g.pour.type) == id
		var btn := Vector2(cx, mr.position.y + mr.size.y * 0.60)   # 그림의 둥근 단추 자리
		if mt == null:
			BgArt.rr(self, r.grow(-3), 8, BgArt.CREAM, BgArt.INK, 2.0)
			draw_circle(btn, 12.0, BgArt.INK)
			draw_circle(btn, 10.0, BgD.DRINKS[id][1])
		if on or (r.has_point(mp) and not _paused()):
			draw_arc(btn, 14.0, 0.0, TAU, 20, BgArt.MUSTARD if not on else Color.WHITE, 3.0, true)
		G2.text_mid(self, btn + Vector2(0, 1 if not on else 3), OS.get_keycode_string(UiKeys.code("burger", String(KEYS[6 + j][0]), int(KEYS[6 + j][2]))), 14, Color.WHITE, 4)
		if r.has_point(mp) and not _paused():
			G2.text_mid(self, Vector2(cx, mr.position.y - 12), String(BgD.DRINKS[id][0]), 20, BgArt.HEAD, 5)
		if not on:
			continue
		# 따르는 중 — 꼭지에서 컵까지 줄기, 컵이 차오른다
		var k := clampf(float(g.pour.fill), 0.0, BgD.POUR_MAX) / BgD.POUR_MAX
		var col: Color = BgD.DRINKS[id][1]
		var cup := Rect2(cx - 15, mr.position.y + mr.size.y * 0.66, 30, 38)
		var tip := Vector2(cx, mr.position.y + mr.size.y * 0.53)
		draw_line(tip, Vector2(cx + sin(t * 40.0) * 1.2, cup.position.y + 8), col, 5.0)
		var ctx := BgArt.img("bg_cup")
		if ctx != null:
			BgArt.fit(self, ctx, cup)
		else:
			BgArt.rr(self, cup, 4, Color(1, 1, 1, 0.6), BgArt.INK, 2.0)
		var inner := cup.grow_individual(-7, -6, -7, -5)
		draw_rect(Rect2(inner.position.x, inner.end.y - inner.size.y * minf(k * BgD.POUR_MAX, 1.0), inner.size.x, inner.size.y * minf(k * BgD.POUR_MAX, 1.0)), Color(col, 0.9))
		var bar := Rect2(cup.end.x + 3, cup.position.y - 14, 9, cup.size.y + 14)
		draw_rect(bar, Color8(240, 232, 220))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y * (1.0 - 1.0 / BgD.POUR_MAX))), Color(1, 0.3, 0.25))
		draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * k, bar.size.x, bar.size.y * k), col)
		draw_rect(bar, BgArt.INK, false, 2.0)
		var ly := bar.end.y - bar.size.y * BgD.POUR_OK / BgD.POUR_MAX
		draw_line(Vector2(bar.position.x - 3, ly), Vector2(bar.end.x + 3, ly), Color.WHITE, 3.0)
		draw_line(Vector2(bar.position.x - 3, ly), Vector2(bar.end.x + 3, ly), BgArt.INK, 1.0)


## 튀김기 — 바구니(덜 튀겨짐 · 노릇함 · 탐)와 굽기 막대, 위쪽에 가루 양념 통 다섯.
func _draw_fry_station() -> void:
	if not g.set_on("fries"):
		return
	var fr := _side_rect("fries")
	var ft := BgArt.img("bg_tool_fryer")
	if ft != null:
		BgArt.fit(self, ft, fr)
	else:
		BgArt.rr(self, fr, 10, BgArt.MUSTARD, BgArt.INK, 4.0)
	var st := g.fry_state()
	if st != "":
		var bt := BgArt.img("bg_fry_" + st)
		if bt != null:
			BgArt.fit(self, bt, Rect2(fr.position.x + 6, fr.position.y - 8, fr.size.x - 12, 70))
		var good := BgD.FRY_GOOD * (2.0 if int(g.up.helper) > 0 else 1.0)
		_cook_bar(Rect2(fr.position.x + 8, fr.end.y - 20, fr.size.x - 16, 12), float(g.fry.t), BgD.FRY_T, good)
		if st == "good" and fmod(t, 0.5) < 0.25:
			G2.text_mid(self, Vector2(fr.get_center().x, fr.position.y - 18), "지금", 18, Color8(170, 255, 150), 5)
	var mp := get_local_mouse_position()
	for j in BgD.DIP_IDS.size():
		var id := String(BgD.DIP_IDS[j])
		var r := _dip_rect(j)
		var on := bool(g.side.fries) and String(g.side.dip) == id
		var tx := BgArt.img("bg_" + id)
		if on or r.has_point(mp):
			BgArt.rr(self, r.grow(3), 12, Color(1, 1, 1, 0.5), BgArt.MUSTARD, 3.0)
		if tx != null:
			BgArt.fit(self, tx, r)
		else:
			draw_circle(r.get_center(), 18.0, BgArt.INK)
			draw_circle(r.get_center(), 15.0, BgD.DIPS[id][1])
		if r.has_point(mp):
			G2.text_mid(self, Vector2(r.get_center().x, r.position.y - 12), String(BgD.DIPS[id][0]), 18, BgArt.HEAD, 5)


## 굽기 · 튀기기 막대 — 회색(덜 됨) · 초록(알맞음) · 빨강(탐)에 지금 자리의 흰 바늘.
func _cook_bar(bar: Rect2, at: float, cook: float, good: float) -> void:
	var total := (cook + good) * 1.15
	var x1 := bar.size.x * cook / total
	var x2 := bar.size.x * (cook + good) / total
	draw_rect(Rect2(bar.position, Vector2(x1, bar.size.y)), Color8(190, 180, 170))
	draw_rect(Rect2(bar.position + Vector2(x1, 0), Vector2(x2 - x1, bar.size.y)), BgArt.GREEN)
	draw_rect(Rect2(bar.position + Vector2(x2, 0), Vector2(bar.size.x - x2, bar.size.y)), BgArt.RED)
	draw_rect(bar, BgArt.INK, false, 2.0)
	var nx := bar.position.x + minf(bar.size.x, bar.size.x * at / total)
	draw_rect(Rect2(nx - 3, bar.position.y - 4, 6, bar.size.y + 8), Color.WHITE)
	draw_rect(Rect2(nx - 3, bar.position.y - 4, 6, bar.size.y + 8), BgArt.INK, false, 2.0)


func _drink_icon(id: String, r: Rect2) -> void:
	var tx := BgArt.img("bg_" + id)
	if tx != null:
		BgArt.fit(self, tx, r)
	else:
		BgArt.rr(self, r.grow_individual(-6, 0, -6, 0), 6, BgD.DRINKS[id][1], BgArt.INK, 2.0)


## 감자튀김 + 오른쪽 아래에 뿌린 가루 양념의 통(없으면 감자튀김만). 뿌린 가루 색이 튀김 위에 점점이 앉는다.
func _fries_icon(dip: String, r: Rect2) -> void:
	var tx := BgArt.img("bg_fries")
	if tx != null:
		BgArt.fit(self, tx, r)
	else:
		BgArt.rr(self, r.grow_individual(-6, 0, -6, 0), 6, BgArt.MUSTARD, BgArt.INK, 2.0)
	if dip != "":
		var pc: Color = BgD.DIPS[dip][1]
		for j in 7:   # 튀김 위에 앉은 가루
			draw_circle(Vector2(r.position.x + r.size.x * (0.22 + 0.09 * j), r.position.y + r.size.y * (0.16 + 0.07 * (j * 3 % 4))), 2.0, pc)
		var dr := Rect2(r.end.x - 20, r.end.y - 26, 22, 30)
		var dt := BgArt.img("bg_" + dip)
		if dt != null:
			BgArt.fit(self, dt, dr)
		else:
			draw_circle(dr.get_center(), 10.0, BgArt.INK)
			draw_circle(dr.get_center(), 8.0, BgD.DIPS[dip][1])


func _draw_hud() -> void:
	# 위 띠 — 날 · 남은 시간 · 오늘 번 돈과 목표
	var bar := Rect2(150, 12, vs.x - 300, 36)
	BgArt.rr(self, bar, 18, Color(0.2, 0.1, 0.06, 0.82))
	G2.text_mid(self, Vector2(bar.position.x + 60, bar.get_center().y), "%d일째" % (g.day + 1), 22, BgArt.HEAD)
	var tb := Rect2(bar.position.x + 130, bar.position.y + 11, 420, 14)
	BgArt.rr(self, tb, 7, Color8(90, 60, 50))
	var k := g.time_left / BgD.DAY_T
	BgArt.rr(self, Rect2(tb.position, Vector2(maxf(8.0, tb.size.x * k), tb.size.y)), 7, BgArt.MUSTARD if k > 0.2 else BgArt.RED)
	G2.text_mid(self, Vector2(tb.end.x + 44, bar.get_center().y), "%d:%02d" % [int(g.time_left) / 60, int(g.time_left) % 60], 22, BgArt.HEAD)
	var reach := g.money >= g.goal()
	G2.text_mid(self, Vector2(bar.end.x - 170, bar.get_center().y), "번 돈 %d / 목표 %d" % [g.money, g.goal()], 22, Color8(170, 255, 150) if reach else BgArt.HEAD)
	if g.combo >= 2:
		G2.text_mid(self, Vector2(bar.end.x - 170, bar.end.y + 16), "%d번 연속" % g.combo, 20, Color8(255, 236, 150), 5)
	UiKit.button(self, vs, "hub", "burger", t, "나가기")
	UiKit.button(self, vs, "rules", "burger", t)
	UiKit.button(self, vs, "vol", "burger", t)


func _draw_modal(q: String, labels: Array) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var c := vs * 0.5
	BgArt.rr(self, Rect2(c.x - 300, c.y - 110, 600, 240), 22, BgArt.CREAM, BgArt.INK, 5.0)
	G2.text_mid(self, Vector2(c.x, c.y - 40), q, 30, BgArt.INK)
	_btn(_modal_btn(0), String(labels[0]), Color8(150, 130, 120), 24)
	_btn(_modal_btn(1), String(labels[1]), UiKit.theme("burger").start, 24)


## 정산 창 — 셔터가 내려오고, 별이 하나씩 박히고, 번 돈이 굴러 올라간다.
func _draw_end() -> void:
	var shut := G2.out_cubic(minf(end_t / 0.5, 1.0))
	draw_rect(Rect2(0, 0, vs.x, vs.y * shut), Color(0.16, 0.08, 0.05, 0.86))
	if end_t < 0.5:
		return
	var c := vs * 0.5
	var r := Rect2(c.x - 360, c.y - 250, 720, 500)
	BgArt.rr(self, r, 26, BgArt.CREAM, BgArt.INK, 5.0)
	var st := g.stars()
	G2.text_mid(self, Vector2(c.x, r.position.y + 56), "%d일째 영업 끝" % (g.day + 1), 44, BgArt.INK)
	for j in 3:
		var sk := clampf((end_t - 0.7 - j * 0.35) / 0.25, 0.0, 1.0)
		BgArt.star(self, Vector2(c.x + (j - 1) * 100.0, r.position.y + 140), 42.0, st > j and sk > 0.0, 1.0 + (1.0 - sk) * 0.8 if st > j else 1.0)
	var roll := int(g.money * clampf((end_t - 0.6) / 1.0, 0.0, 1.0))
	G2.text_mid(self, Vector2(c.x, r.position.y + 220), "번 돈 %d  (목표 %d)" % [roll, g.goal()], 32, Color8(60, 130, 60) if g.money >= g.goal() else BgArt.RED)
	G2.text_mid(self, Vector2(c.x, r.position.y + 268), "손님 %d명, 팁 %d" % [g.served, g.tips], 24, BgArt.INK)
	G2.text_mid(self, Vector2(c.x, r.position.y + 304), "놓친 손님 %d명, 틀린 버거 %d개, 태운 패티 %d장" % [g.lost, g.wrong, g.burnt], 22, Color8(130, 90, 70))
	var why := "별 하나: 목표 금액.  별 둘: 놓친 손님 없이.  별 셋: 틀린 버거와 탄 패티 없이."
	G2.text_mid(self, Vector2(c.x, r.position.y + 346), why, 18, Color8(150, 110, 90))
	if end_t >= 1.0:
		_btn(_end_btn(0), "다음 날", UiKit.theme("burger").start, 24, st > 0 and g.day + 1 < BgD.DAYS)
		_btn(_end_btn(1), "가게 꾸리기", BgArt.MUSTARD, 24)
		_btn(_end_btn(2), "다시 하기", Color8(150, 130, 120), 24)

# ==================== 확인용 ====================


## 누르기 시험 — 처음 화면에서 영업까지 눌러 들어가 버거 하나를 만들어 낸다. 실패하면 종료 코드 1.
func _click_test_step() -> void:
	_ct += 1
	var fail := ""
	match _ct:
		5:
			_press(Hub.std_rect("start", vs).get_center())
		10:
			if scr != Scr.DAYS:
				fail = "처음 화면에서 날 고르기로 안 넘어감"
			_press(_shop_btn().get_center())
		15:
			if scr != Scr.SHOP:
				fail = "가게 화면이 안 열림"
			_press(_back_btn().get_center())
		20:
			pick = 0
			_press(Hub.std_rect("start", vs).get_center())
		25:
			if scr != Scr.PLAY or g == null:
				fail = "영업이 시작되지 않음"
		30:
			g.cust[0] = {kind = "normal", order = ["bun_sesame", "pt_beef", "ch_cheddar", "bun_sesame"], drink = "", fries = false, dip = "", wrap = false, pat = 99.0, max = 99.0,
					state = "wait", t = 0.0, left = 1, face = 0, n = 0}
			_press(_bin_rect(_cat_items().find("bun_sesame")).get_center())
		32:
			_press(_cat_rect(1).get_center())   # 패티 통을 연다
		34:
			if open_cat != "patty":
				fail = "재료 통이 안 열림"
			_press(_bin_rect(_cat_items().find("pt_beef")).get_center())
		36:
			_key(KEY_D)   # 치즈 통(키)
		37:
			_key(KEY_1 + _cat_items().find("ch_cheddar"))
		38:
			_key(KEY_A)
		40:
			_press(_bin_rect(_cat_items().find("bun_sesame")).get_center())
		42:
			if g.stack.size() != 4 or not g.complete():
				fail = "버거가 안 쌓임(%d층)" % g.stack.size()
			_press(_cust_rect(0).get_center())
		46:
			if g.served != 1 or g.money <= 0:
				fail = "맞는 버거를 냈는데 돈이 안 들어옴"
		50:
			print("BG CLICK TEST OK")
			get_tree().quit()
	if fail != "":
		printerr("BG CLICK TEST FAIL: " + fail)
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


func _open_rules() -> void:
	rules.show("burger", "버거왕 규칙", BgRules.pages())
