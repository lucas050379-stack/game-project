class_name BgGame
extends RefCounted

## 버거왕 규칙 — 하루 영업 한 판. 손님 · 주문 · 조립 · 굽기 · 돈. 그리기 · 입력을 모른다(화면은 `events` 를 받아 연출한다).
## 조립대의 버거(`stack`)는 아래에서 위로 쌓이는 재료 줄이고, 손님의 주문(`order`)과 **순서까지 같아야** 맞다.
## 화면이 부르는 것: `tap(id)` 재료 얹기 · `grill_take(i)` 구운 패티 집기 · `trash()` 맨 위 버리기 · `pour(type, dt)` · `pour_stop()` 음료 따르기 · `fry_tap()` 튀김기 · `dip(id)` 가루 양념 · `serve(slot)` · `step(dt)`.

var day := 0
var cfg := {}
var rng := RandomNumberGenerator.new()
var up := {}                    ## 강화 단계(BgD.UP 의 열쇠 → 단계)
var shelf: Array = []           ## 오늘 선반의 재료 id
var time_left := BgD.DAY_T
var cust: Array = []            ## 자리마다 null 또는 {kind, order, drink(음료 id 또는 ""), fries, dip, pat, max, state(wait · happy · angry), t, left, face, n}
var spawn_cd := 1.2
var stack: Array = []           ## [{id, q}] — q 는 패티의 굽기(1 = 딱 알맞음)
var side := {drink = "", fries = false, dip = ""}   ## 쟁반 — 다 따른 음료(id) · 건진 감자튀김 · 그 소스
var pour := {type = "", fill = 0.0}        ## 따르는 중인 컵
var fry = null                             ## 튀김기 — null 또는 {t}
var grill: Array = []           ## 칸마다 null 또는 {id, t, flipped, cheese(얹은 치즈 id), ct(치즈가 녹은 시간)}
var stock := {}                 ## 야채 id → 남은 양(손질하는 날만)
var chop := {}                  ## 야채 id → 써는 중인 시간
var wrapped := false            ## 다 만든 버거를 포장했나
var money := 0                  ## 오늘 번 돈(팁 포함)
var tips := 0
var served := 0
var lost := 0                   ## 화나서 간 손님
var wrong := 0                  ## 틀리게 낸 버거
var burnt := 0
var combo := 0
var events: Array = []
var over := false
var n_cust := 0
var _bot_cd := 0.0
var _bot_pour := ""
var _bot_n := -1                ## 봇이 지금 만들어 주는 손님(번호) — 다 낼 때까지 안 바꾼다(바꾸면 구워 둔 패티가 탄다)


func _init(d: int, seed_: int = -1, unlocked: Array = [], upgrades: Dictionary = {}) -> void:
	day = clampi(d, 0, BgD.DAYS - 1)
	cfg = BgD.day(day)
	rng.seed = seed_ if seed_ >= 0 else randi()
	for row: Array in BgD.UP:
		up[row[0]] = int(upgrades.get(row[0], 0))
	shelf = BgD.shelf_for(day, unlocked if not unlocked.is_empty() else BgD.starters())
	for i in slots():
		cust.append(null)
	for i in grill_n():
		grill.append(null)
	if bool(cfg.prep):
		for id: String in shelf:
			if BgD.cat(id) == "veg":
				stock[id] = BgD.PREP_N


var leaving: Array = []      ## 걸어 나가는 손님(그리기만) {face, kind, state, slot, t}


func slots() -> int:
	return int(BgD.SHOP_SLOTS[clampi(int(up.shop), 0, 3)])


func grill_n() -> int:
	return 2 + int(up.grill)


func grill_on() -> bool:
	return bool(cfg.grill)


func set_on(kind: String) -> bool:
	return bool(cfg.sets) and int(up[kind]) > 0


func good_t() -> float:
	return (BgD.GOOD_T + 1.5 * int(up.warm)) * (2.0 if int(up.helper) > 0 else 1.0)


## 한 면이 익는 시간 — 뒤집는 날은 면마다, 아니면 통째로.
func side_t() -> float:
	return BgD.FLIP_T if bool(cfg.flip) else BgD.COOK_T


## 철판 위 패티의 상태 — raw · flip(뒤집을 때) · good · burnt.
func patty_state(g: Dictionary) -> String:
	if float(g.t) < side_t():
		return "raw"
	if float(g.t) >= side_t() + good_t():
		return "burnt"
	return "flip" if bool(cfg.flip) and not bool(g.flipped) else "good"


func complete() -> bool:
	return stack.size() >= 2 and BgD.cat(String(stack[stack.size() - 1].id)) == "bun"


func stack_ids() -> Array:
	return stack.map(func(l): return l.id)

# ==================== 손이 하는 일 ====================


## 선반의 재료를 누른다. 패티는(굽는 날이면) 철판으로, 나머지는 조립대의 버거 위로.
func tap(id: String) -> bool:
	if over or not shelf.has(id):
		return false
	var c := BgD.cat(id)
	if c == "patty" and grill_on():
		for i in grill.size():
			if grill[i] == null:
				grill[i] = {id = id, t = 0.0, flipped = false, cheese = "", ct = 0.0}
				events.append({kind = "grill_on", i = i, id = id})
				return true
		events.append({kind = "nope", why = "철판이 꽉 찼어요"})
		return false
	if stock.has(id):   # 야채 — 떨어졌으면 먼저 썬다
		if chop.has(id):
			events.append({kind = "nope", why = "써는 중이에요"})
			return false
		if int(stock[id]) <= 0:
			return prep(id)
		if not _push(id, 0):
			return false
		stock[id] = int(stock[id]) - 1
		return true
	return _push(id, 0)


## 야채를 썰어 채운다(떨어지기 전에 미리 해도 된다).
func prep(id: String) -> bool:
	if over or not stock.has(id) or chop.has(id) or int(stock[id]) >= BgD.PREP_N:
		return false
	chop[id] = 0.0
	events.append({kind = "chop", id = id})
	return true


## 치즈를 철판의 패티 위에 얹어 녹인다. i < 0 이면 치즈가 없는 첫 패티에.
func melt(id: String, i: int = -1) -> bool:
	if over or not bool(cfg.melt) or not shelf.has(id) or BgD.cat(id) != "cheese":
		return false
	for k in grill.size():
		var s = grill[k]
		if (i < 0 or i == k) and s != null and String(s.cheese) == "" and patty_state(s) != "burnt" and (bool(s.flipped) or not bool(cfg.flip)):
			s.cheese = id
			s.ct = 0.0
			events.append({kind = "melt_on", i = k, id = id})
			return true
	events.append({kind = "nope", why = "철판에 뒤집은 패티가 있어야 치즈를 녹여요" if bool(cfg.flip) else "철판에 패티가 있어야 치즈를 녹여요"})
	return false


## 다 만든 버거를 포장지에 싼다.
func wrap_up() -> void:
	if over or not bool(cfg.wrap):
		return
	if not complete():
		events.append({kind = "nope", why = "다 만든 뒤에 싸요"})
		return
	if not wrapped:
		wrapped = true
		events.append({kind = "wrap"})


func _push(id: String, q: int) -> bool:
	var c := BgD.cat(id)
	if complete() or stack.size() >= BgD.STACK_MAX:
		events.append({kind = "nope", why = "다 만든 버거예요. 손님에게 내요"})
		return false
	if stack.is_empty() and c != "bun":
		events.append({kind = "nope", why = "빵부터 놓아요"})
		return false
	if c == "bun" and not stack.is_empty():
		if String(stack[0].id) != id or stack.size() < 2:
			events.append({kind = "nope", why = "아래 빵과 같은 빵으로 덮어요" if stack.size() >= 2 else "빵 사이에 재료를 넣어요"})
			return false
	if c == "sauce" and bool(cfg.sauce2) and not stack.is_empty():   # 같은 소스를 한 번 더 = 듬뿍
		var top: Dictionary = stack[stack.size() - 1]
		if String(top.id) == id:
			top.id = id + "+"
			events.append({kind = "add", id = id + "+", n = stack.size()})
			return true
		if String(top.id) == id + "+":
			events.append({kind = "nope", why = "소스가 너무 많아요"})
			return false
	stack.append({id = id, q = q})
	events.append({kind = "add", id = id, n = stack.size()})
	return true


## 철판의 패티를 집어 버거에 얹는다. 덜 익었으면 못 집고, 탔으면 버린다.
func grill_take(i: int) -> bool:
	if over or i < 0 or i >= grill.size() or grill[i] == null:
		return false
	var g: Dictionary = grill[i]
	match patty_state(g):
		"raw":
			events.append({kind = "nope", why = "아직 덜 익었어요"})
			return false
		"flip":
			g.flipped = true
			g.t = 0.0
			events.append({kind = "flip", i = i})
			return true
		"burnt":
			grill[i] = null
			burnt += 1
			money = maxi(0, money - BgD.price(String(g.id)))
			events.append({kind = "burnt", i = i})
			return true
	var perfect := float(g.t) < side_t() + good_t() * BgD.PERFECT_K
	if String(g.cheese) != "" and stack.size() + 2 > BgD.STACK_MAX:
		events.append({kind = "nope", why = "버거가 너무 높아요"})
		return false
	if not _push(String(g.id), 1 if perfect else 0):
		return false
	if String(g.cheese) != "":   # 얹은 치즈가 같이 온다 — 다 녹았으면 녹인 치즈
		_push(String(g.cheese) + ("~" if float(g.ct) >= BgD.MELT_T else ""), 0)
	grill[i] = null
	return true


## 맨 위 재료 하나를 버린다(재료값의 절반이 든다). 버거가 비었으면 곁들임을 치운다.
func trash() -> void:
	if over:
		return
	if wrapped:   # 포장부터 벗긴다
		wrapped = false
		events.append({kind = "trash", id = ""})
		return
	if stack.is_empty():
		_clear_side()
		return
	var l: Dictionary = stack.pop_back()
	money = maxi(0, money - BgD.price(String(l.id)) / 2)
	events.append({kind = "trash", id = l.id})


func _clear_side() -> void:
	side.drink = ""
	side.fries = false
	side.dip = ""
	pour.type = ""
	pour.fill = 0.0


## 음료 꼭지를 누르고 있다 — 컵이 찬다. 선(POUR_OK)을 넘겨 떼면 쟁반에 오르고, 너무 따르면 넘쳐서 버린다.
func pour_add(type: String, dt: float) -> void:
	if over or not set_on("drink"):
		return
	if String(side.drink) != "":
		if float(pour.fill) == 0.0:
			pour.fill = -1.0   # 같은 누름에 알림이 한 번만 가게
			events.append({kind = "nope", why = "음료가 이미 있어요. 컵을 눌러 비워요"})
		return
	if String(pour.type) != "" and String(pour.type) != type:
		pour.type = ""
		pour.fill = 0.0
	pour.type = type
	pour.fill = float(pour.fill) + dt / BgD.POUR_T
	if float(pour.fill) > BgD.POUR_MAX:
		pour.type = ""
		pour.fill = 0.0
		events.append({kind = "spill"})


## 꼭지에서 손을 뗐다.
func pour_stop() -> void:
	if float(pour.fill) < 0.0:
		pour.fill = 0.0
		return
	if String(pour.type) == "":
		return
	if float(pour.fill) >= BgD.POUR_OK:
		side.drink = String(pour.type)
		pour.type = ""
		pour.fill = 0.0
		events.append({kind = "side", what = "drink"})
	else:
		events.append({kind = "nope", why = "선까지 더 따라요"})


## 쟁반의 음료(또는 따르던 컵)를 비운다.
func dump_drink() -> void:
	side.drink = ""
	pour.type = ""
	pour.fill = 0.0
	events.append({kind = "trash", id = ""})


func dump_fries() -> void:
	side.fries = false
	side.dip = ""
	events.append({kind = "trash", id = ""})


## 튀김기의 상태 — raw · good · burnt.
func fry_state() -> String:
	if fry == null:
		return ""
	if float(fry.t) < BgD.FRY_T:
		return "raw"
	return "good" if float(fry.t) < BgD.FRY_T + BgD.FRY_GOOD * (2.0 if int(up.helper) > 0 else 1.0) else "burnt"


## 튀김기를 누른다 — 비었으면 바구니를 넣고, 노릇하면 건져 쟁반에 올리고, 탔으면 버린다.
func fry_tap() -> void:
	if over or not set_on("fries"):
		return
	match fry_state():
		"":
			fry = {t = 0.0}
			events.append({kind = "fry_on"})
		"raw":
			events.append({kind = "nope", why = "아직 덜 튀겨졌어요"})
		"good":
			if bool(side.fries):
				events.append({kind = "nope", why = "감자튀김이 이미 있어요"})
				return
			fry = null
			side.fries = true
			side.dip = ""
			events.append({kind = "side", what = "fries"})
		"burnt":
			fry = null
			burnt += 1
			events.append({kind = "burnt_fry"})


## 감자튀김에 가루 양념을 뿌린다(다른 통을 누르면 그 양념으로 바뀐다).
func dip(id: String) -> void:
	if over or not set_on("fries"):
		return
	if not bool(side.fries):
		events.append({kind = "nope", why = "감자튀김부터 건져요"})
		return
	side.dip = id
	events.append({kind = "side", what = "dip"})


func _matches(c: Dictionary) -> bool:
	return String(c.state) == "wait" and stack_ids() == c.order and wrapped == bool(c.wrap) and String(side.drink) == String(c.drink) and bool(side.fries) == bool(c.fries) \
			and (not bool(c.fries) or String(side.dip) == String(c.dip))


## 지금 버거가 맞는 손님의 자리(-1 = 없다).
func match_slot() -> int:
	for i in cust.size():
		if cust[i] != null and _matches(cust[i]):
			return i
	return -1


## 버거를 낸다. slot < 0 이면 맞는 손님에게(없으면 가장 급한 손님에게 — 틀린 것이 된다).
func serve(slot: int = -1) -> void:
	if over:
		return
	if not complete():
		events.append({kind = "nope", why = "위 빵까지 덮어야 낼 수 있어요"})
		return
	if slot < 0:
		slot = match_slot()
	if slot < 0:
		slot = _urgent()
	if slot < 0 or cust[slot] == null or String(cust[slot].state) != "wait":
		events.append({kind = "nope", why = "받을 손님이 없어요"})
		return
	var c: Dictionary = cust[slot]
	if _matches(c):
		var krow: Array = BgD.KIND[c.kind]
		var pay := int(round(BgD.value(c.order) * float(krow[2]) * float(BgD.SHOP_PAY[clampi(int(up.shop), 0, 3)])))
		if String(c.drink) != "":
			pay += int(BgD.SET_PAY.drink)
		if bool(c.fries):
			pay += int(BgD.SET_PAY.fries)
		if bool(c.wrap):
			pay += BgD.WRAP_PAY
		var tip := int(pay * 0.5 * clampf(float(c.pat) / float(c.max), 0.0, 1.0)) + mini(combo, 10) * 2
		if String(c.kind) == "gourmet":   # 미식가 — 패티가 전부 딱 알맞아야 큰 팁, 아니면 팁이 없다
			var all_perfect := stack.all(func(l): return BgD.cat(String(l.id)) != "patty" or int(l.q) == 1 or not grill_on())
			tip = tip * 3 if all_perfect else 0
		money += pay + tip
		tips += tip
		served += 1
		combo += 1
		c.left = int(c.left) - 1
		if int(c.left) > 0:   # 단체 — 같은 것을 더 기다린다
			c.pat = minf(float(c.max), float(c.pat) + float(c.max) * 0.5)
		else:
			c.state = "happy"
			c.t = 0.0
		events.append({kind = "serve", slot = slot, pay = pay, tip = tip, combo = combo})
	else:
		wrong += 1
		combo = 0
		c.pat = float(c.pat) - float(c.max) * BgD.WRONG_K
		events.append({kind = "wrong", slot = slot})
	stack.clear()
	wrapped = false
	_clear_side()


func _urgent() -> int:
	var best := -1
	for i in cust.size():
		if cust[i] != null and String(cust[i].state) == "wait" and (best < 0 or float(cust[i].pat) < float(cust[best].pat)):
			best = i
	return best

# ==================== 시간 ====================


func step(dt: float) -> void:
	if over:
		return
	time_left -= dt
	for g in grill:
		if g != null:
			var was := patty_state(g)
			g.t = float(g.t) + dt
			if String(g.cheese) != "":
				g.ct = float(g.ct) + dt
			var now := patty_state(g)
			if was != now:
				events.append({kind = "burning" if now == "burnt" else "cooked", id = g.id})
	for id: String in chop.keys():
		chop[id] = float(chop[id]) + dt
		if float(chop[id]) >= BgD.PREP_T:
			chop.erase(id)
			stock[id] = BgD.PREP_N
			events.append({kind = "chopped", id = id})
	if fry != null:
		var fwas := fry_state()
		fry.t = float(fry.t) + dt
		if fwas != fry_state():
			events.append({kind = "cooked" if fry_state() == "good" else "burning", id = "fries"})
	for i in cust.size():
		var c = cust[i]
		if c == null:
			continue
		if String(c.state) == "wait":
			c.pat = float(c.pat) - dt
			if float(c.pat) <= 0.0:
				c.state = "angry"
				c.t = 0.0
				lost += 1
				combo = 0
				events.append({kind = "lost", slot = i})
		elif String(c.state) == "in":   # 문에서 걸어오는 중 — 참을성이 안 준다
			c.t = float(c.t) + dt
			if float(c.t) >= BgD.WALK_IN_T:
				c.state = "wait"
		else:   # 기뻐하거나 화나서 떠난다 — 자리는 바로 비우고 걸어 나가는 모습만 따로(leaving)
			leaving.append({face = c.face, kind = c.kind, state = c.state, slot = i, t = 0.0})
			cust[i] = null
	for lv in leaving:
		lv.t = float(lv.t) + dt
	leaving = leaving.filter(func(lv): return float(lv.t) < BgD.LEAVE_T)
	if time_left <= 0.0:
		time_left = 0.0
		over = true
		events.append({kind = "close"})
		return
	spawn_cd -= dt
	if spawn_cd <= 0.0:
		var free := -1
		for i in cust.size():
			if cust[i] == null:
				free = i
				break
		if free >= 0:
			_spawn(free)
			spawn_cd = lerpf(float(cfg.gap0), float(cfg.gap1), 1.0 - time_left / BgD.DAY_T)
		else:
			spawn_cd = 0.5


func _spawn(i: int) -> void:
	var kind := "normal"
	if bool(cfg.special) and rng.randf() < 0.3:
		kind = ["kid", "gourmet", "group", "rider"][rng.randi() % 4]
	var layers := rng.randi_range(int(cfg.lay_min), int(cfg.lay_max))
	if kind == "kid":
		layers = maxi(2, int(cfg.lay_min) - 2)
	elif kind == "rider":
		layers = mini(int(cfg.lay_max) + 1, BgD.STACK_MAX - 2)
	var order := BgD.make_order(rng, shelf, layers, cfg)
	var krow: Array = BgD.KIND[kind]
	var pat := BgD.patience_of(layers) * float(cfg.patience) * float(krow[1]) * float(BgD.SHOP_PAT[clampi(int(up.shop), 0, 3)])
	if grill_on():
		pat += BgD.COOK_T
	if bool(cfg.flip):
		pat += 3.5
	if bool(cfg.prep):
		pat += 2.0
	for lid in order:
		if String(lid).ends_with("~"):
			pat += BgD.MELT_T + 2.0
	var wr := bool(cfg.wrap) and (kind == "rider" or rng.randf() < 0.3)
	if wr:
		pat += 2.5
	var drink: String = BgD.DRINK_IDS[rng.randi() % BgD.DRINK_IDS.size()] if set_on("drink") and rng.randf() < 0.45 else ""
	var fries := set_on("fries") and rng.randf() < 0.45
	var dp: String = BgD.DIP_IDS[rng.randi() % BgD.DIP_IDS.size()] if fries else ""
	if drink != "":
		pat += 4.0
	if fries:
		pat += BgD.FRY_T + 5.0
	cust[i] = {kind = kind, order = order, drink = drink, fries = fries, dip = dp, wrap = wr, pat = pat, max = pat, state = "in", t = 0.0,
			left = 3 if kind == "group" else 1, face = rng.randi() % 6, n = n_cust}
	n_cust += 1
	events.append({kind = "come", slot = i})


func goal() -> int:
	return int(cfg.goal)


## 별 — 하나: 목표 금액. 둘: 놓친 손님 0. 셋: 틀린 버거 0(탄 패티도 센다).
func stars() -> int:
	if money < goal():
		return 0
	# 11-10 밤: 너그럽게 — 실수 한 번은 별 셋, 손님 한 명 놓쳐도 별 둘(예전엔 실수 하나에 둘 · 한 명 놓치면 하나)
	if lost > 1:
		return 1
	return 2 if lost > 0 or wrong + burnt > 1 else 3

# ==================== 봇 ====================


## 봇 — 가장 급한 손님의 주문을 아래에서부터 쌓는다. pace 초마다 한 번 손을 놀리고, miss 확률로 엉뚱한 재료를 집는다.
func bot(dt: float, pace: float = 0.3, miss: float = 0.0) -> void:
	if over:
		return
	if _bot_pour != "":   # 따르는 중 — 선을 조금 넘겨서 뗀다
		pour_add(_bot_pour, dt)
		if float(pour.fill) >= 0.9 or String(pour.type) == "":
			pour_stop()
			_bot_pour = ""
		return
	_bot_cd -= dt
	if _bot_cd > 0.0:
		return
	_bot_cd = pace
	var slot := -1
	for i in cust.size():
		if cust[i] != null and int(cust[i].n) == _bot_n and String(cust[i].state) == "wait":
			slot = i
	if slot < 0:
		slot = _urgent()
	if slot < 0:
		return
	var c: Dictionary = cust[slot]
	_bot_n = int(c.n)
	var order: Array = c.order
	var ids := stack_ids()
	# 곁들임 — 남은 것이 주문과 다르면 비우고, 튀김기는 미리 넣어 둔다
	if String(side.drink) != "" and String(side.drink) != String(c.drink):
		dump_drink()
		return
	if bool(side.fries) and not bool(c.fries):
		dump_fries()
		return
	if fry_state() == "burnt" or (fry_state() == "good" and not bool(side.fries)):   # 다 튀겨진 것은 필요 없어도 건진다(두면 탄다) - 필요 없으면 위에서 버린다
		fry_tap()
		return
	if bool(c.fries) and not bool(side.fries):
		if fry == null or fry_state() == "good":
			fry_tap()
			return
	if bool(side.fries) and bool(c.fries) and String(side.dip) != String(c.dip):
		dip(String(c.dip))
		return
	# 지금 쌓은 것이 주문의 앞머리가 아니면 버린다(맨 위가 "듬뿍"의 첫 번째 짜기인 것은 괜찮다)
	var n := ids.size()
	var half := n > 0 and n <= order.size() and String(ids[n - 1]) + "+" == String(order[n - 1])
	var okp := n <= order.size()
	for k in n:
		if okp and ids[k] != order[k] and not (k == n - 1 and half):
			okp = false
	if not okp or (wrapped and not bool(c.wrap)):
		trash()
		return
	if half:
		tap(String(ids[n - 1]))
		return
	# 철판 — 탄 것은 치우고, 뒤집을 것은 뒤집고, 주문에 남은 패티를 미리 올린다
	if grill_on():
		for i in grill.size():
			if grill[i] != null and patty_state(grill[i]) in ["burnt", "flip"]:
				grill_take(i)
				return
		# 쓸 데 없는 패티(떠난 손님 것 · 다른 치즈가 얹힌 것)는 다 익었을 때 집어서 버린다 - 두면 타서 별 셋을 놓친다
		for i in grill.size():
			var s = grill[i]
			if s == null or patty_state(s) != "good":
				continue
			var useful := false
			for k in range(n, order.size()):
				if String(order[k]) == String(s.id) and (String(s.cheese) == "" or (k + 1 < order.size() and String(order[k + 1]) == String(s.cheese) + "~")):
					useful = true
			if not useful and not complete() and not stack.is_empty():
				grill_take(i)
				return
		var need := {}
		for k in range(n, order.size()):
			var id := String(order[k])
			if BgD.cat(id) == "patty":
				need[id] = int(need.get(id, 0)) + 1
		for s in grill:
			if s != null and need.has(s.id):
				need[s.id] = int(need[s.id]) - 1
		for id: String in need:
			if int(need[id]) > 0 and grill.has(null):
				tap(id)
				return
	if n == order.size():
		if bool(c.wrap) and not wrapped:
			wrap_up()
		elif String(c.drink) != "" and String(side.drink) != String(c.drink):
			_bot_pour = String(c.drink)
		elif bool(c.fries) and (not bool(side.fries) or String(side.dip) != String(c.dip)):
			pass   # 튀겨지기를 기다린다
		else:
			serve(slot)
		return
	var next := String(order[n])
	if miss > 0.0 and rng.randf() < miss:
		var other: String = shelf[rng.randi() % shelf.size()]
		if BgD.cat(other) != "patty":
			tap(other)
			return
	if BgD.cat(next) == "patty" and grill_on():
		# 다음 층이 녹인 치즈면 그 치즈를 얹어 다 녹은 패티를, 아니면 치즈 없는 패티를 집는다
		var want := BgD.base(String(order[n + 1])) if n + 1 < order.size() and String(order[n + 1]).ends_with("~") else ""
		for i in grill.size():
			var s = grill[i]
			if s == null or String(s.id) != next or String(s.cheese) != want:
				continue
			if patty_state(s) == "good" and (want == "" or float(s.ct) >= BgD.MELT_T):
				grill_take(i)
				return
		var pending := grill.any(func(q): return q != null and String(q.id) == next and String(q.cheese) == want)   # 이미 그 치즈를 얹어 녹이는 중
		if want != "" and not pending:
			for i in grill.size():
				var s = grill[i]
				if s != null and String(s.id) == next and String(s.cheese) == "" and (bool(s.flipped) or not bool(cfg.flip)):
					melt(want, i)
					return
		return   # 익기를 기다린다
	if next.ends_with("~"):   # 녹인 치즈는 패티와 같이 와야 한다 - 패티만 올라와 있으면 그 패티를 버리고 다시 굽는다
		trash()
		return
	tap(BgD.base(next))
