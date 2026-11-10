class_name AkGame
extends RefCounted

## 잿빛 요새의 용병단 시나리오 한 판 — 규칙 계산만(그리기 · 소리 · 저장 · 오토로드를 부르지 마세요 —
## `tools/ashkeep_check.gd` 가 `--script` 로 이 파일만 읽어 봇 영웅으로 수백 판을 돌립니다).
##
## 라운드: 카드 고르기(`pending = "select"`, 영웅마다 두 장 또는 긴 휴식) → 몬스터 행동 카드 공개 → 순서 숫자대로 행동 → 정리.
## 영웅 차례: 어느 카드의 위 행동을 쓸지(`"first"`) → 단계를 하나씩. 자리나 대상을 골라야 하는 단계는 `"step"` 으로 멈춘다
## (`options` 에 고를 수 있는 칸, `choose(칸)` · `skip()` 으로 푼다). 몬스터 차례는 [method advance] 한 번에 한 마리.
## 장르 규칙과 다른 점(1차): 카드를 잃어 피해를 막지 않음, 시야(LOS) 없음, 강화는 공격 +1.

var rng := RandomNumberGenerator.new()
var scen := 0
var lv := 0
var goal := "all"
var cells := {}                ## Vector2i → {room, trap, obs, door}
var revealed := {}             ## 방 글자 → true
var spawns: Array = []         ## 아직 안 나온 몬스터 [m, elite, 칸, 방]
var units: Array = []          ## {id, side "hero" · "mon", k, elite, hp, max, pos, s, ret, st {}, alive}
var heroes: Array = []         ## 영웅 자리별 {unit, hand, disc, lost, pick [a, b], rest, exh, amd, amd_disc, xp}
var mdeck := {}                ## 몬스터 종류 → {deck, disc, cur}
var mamd: Array = []
var mamd_disc: Array = []
var elems := [0, 0, 0, 0]
var infuse_q: Array = []
var round_no := 0
var order: Array = []          ## [{kind "hero" · "mon", i · m, init}]
var turn_i := 0
var mon_q: Array = []          ## 이번 몬스터 종류 차례에 남은 유닛 id
var steps: Array = []          ## 영웅 차례에 남은 단계
var hero_on := -1              ## 지금 행동 중인 영웅 자리
var hero_cards: Array = []     ## [위를 쓴 카드, 아래를 쓴 카드]
var started := false
var pending := ""              ## "" · "select" · "first" · "step"
var pend_h := 0                ## 고르는 영웅 자리
var step_now := {}             ## 고르는 중인 단계(남은 대상 수 left 포함)
var options: Array = []        ## 고를 수 있는 칸
var over := false
var win := false
var rounds_goal := 0
var waves: Array = []
var events: Array = []         ## {txt, pos?, kind} — 화면이 띄운다
var _next_id := 0


func _init(scenario: int, hero_kinds: Array, level_adj: int = 0, hero_levels: Array = [1, 1], seed_v: int = -1) -> void:
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	scen = scenario
	var row: Array = AkD.SCENARIOS[scenario]
	goal = String(row[1])
	lv = clampi(int(row[5]) + level_adj, 0, 5)
	var extra: Dictionary = row[6]
	rounds_goal = int(extra.get("rounds", 0))
	waves = extra.get("waves", []).duplicate(true)
	var mp: Array = row[2]
	for r in mp.size():
		var line: String = mp[r]
		for c in line.length():
			var ch := line[c]
			if ch == " ":
				continue
			var ax := AkD.axial(c, r)
			var room := ch.to_lower() if ch != "+" else ""
			cells[ax] = {room = room, trap = ch != ch.to_lower() and ch != "+", obs = false, door = ch == "+"}
	for o in extra.get("obstacles", []):
		var ax2 := AkD.axial(int(o[0]), int(o[1]))
		if cells.has(ax2):
			cells[ax2].obs = true
	for tr in extra.get("traps", []):
		var ax3 := AkD.axial(int(tr[0]), int(tr[1]))
		if cells.has(ax3):
			cells[ax3].trap = true
	for s in row[3]:
		var ax4 := AkD.axial(int(s[2]), int(s[3]))
		spawns.append([int(s[0]), int(s[1]) == 1, ax4, String(cells[ax4].room)])
	var starts: Array = row[4]
	for i in hero_kinds.size():
		var h: int = hero_kinds[i]
		var hl: int = hero_levels[i] if i < hero_levels.size() else 1
		var hp := int(AkD.HEROES[h][1]) + AkD.HERO_HP_BONUS + (hl - 1)
		var u := _new_unit("hero", h, false, hp, AkD.axial(int(starts[i][0]), int(starts[i][1])))
		var hand := []
		for k in AkD.CARDS[h].size():
			hand.append(AkD.card(h, k))
		# 손패 한도를 넘는 카드는 빼고 시작(1차: 소멸 카드부터 뺌 — 덱 짜기 화면은 다음 단계)
		hand.sort_custom(func(x, y): return int(not x.top_lost) > int(not y.top_lost))
		hand.resize(mini(hand.size(), int(AkD.HEROES[h][2])))
		var amd := AkD.AMD.duplicate()
		for k in mini(hl - 1, 4):
			amd.erase(-1)
		_shuffle(amd)
		heroes.append({unit = u, kind = h, hand = hand, disc = [], lost = [], pick = [], rest = false, exh = false,
				amd = amd, amd_disc = [], xp = 0})
	mamd = AkD.AMD.duplicate()
	_shuffle(mamd)
	_reveal("a")
	_start_round()


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _new_unit(side: String, k: int, elite: bool, hp: int, pos: Vector2i) -> Dictionary:
	_next_id += 1
	var u := {id = _next_id, side = side, k = k, elite = elite, hp = hp, max = hp, pos = pos, s = 0, ret = 0, st = {}, alive = true}
	units.append(u)
	return u


func _reveal(room: String) -> void:
	if revealed.has(room) or room == "":
		return
	revealed[room] = true
	for s: Array in spawns.duplicate():
		if String(s[3]) == room:
			_spawn(int(s[0]), bool(s[1]), s[2])
			spawns.erase(s)


func _spawn(m: int, elite: bool, pos: Vector2i) -> void:
	if unit_at(pos) != {}:
		for n in AkD.neighbors(pos):
			if is_floor(n) and unit_at(n) == {}:
				pos = n
				break
	var st := AkD.mon_stats(m, elite, lv)
	var u := _new_unit("mon", m, elite, int(st.hp), pos)
	if not mdeck.has(m):
		var d := AkD.ability_deck(m)
		_shuffle(d)
		mdeck[m] = {deck = d, disc = [], cur = {}}
	events.append({kind = "spawn", txt = "%s%s 등장" % [st.name, " 정예" if elite else ""], pos = pos, id = u.id})

# ==================== 칸 · 유닛 ====================


func is_floor(c: Vector2i) -> bool:
	return cells.has(c) and not cells[c].obs and (cells[c].door or revealed.has(cells[c].room))


func unit_at(c: Vector2i) -> Dictionary:
	for u: Dictionary in units:
		if u.alive and u.pos == c:
			return u
	return {}


func unit(id: int) -> Dictionary:
	for u: Dictionary in units:
		if int(u.id) == id:
			return u
	return {}


func alive_mons() -> Array:
	return units.filter(func(u): return u.alive and u.side == "mon")


func alive_heroes() -> Array:
	return units.filter(func(u): return u.alive and u.side == "hero")


func mon_stat(u: Dictionary) -> Dictionary:
	return AkD.mon_stats(int(u.k), bool(u.elite), lv)


## 이동할 수 있는 칸(사거리 n) — 적은 못 지나가고, 동료는 지나가되 멈추지 못한다. 날면 함정 · 장애물을 무시.
func reachable(u: Dictionary, n: int, fly: bool = false) -> Array:
	var dist := {u.pos: 0}
	var q := [u.pos]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if int(dist[c]) >= n:
			continue
		for nb in AkD.neighbors(c):
			if dist.has(nb) or not cells.has(nb):
				continue
			if not (cells[nb].door or revealed.has(cells[nb].room)):
				continue
			if cells[nb].obs and not fly:
				continue
			var o := unit_at(nb)
			if o != {} and o.side != u.side:
				continue
			dist[nb] = int(dist[c]) + 1
			q.append(nb)
	var out := []
	for c in dist:
		if unit_at(c) == {} or c == u.pos:
			out.append(c)
	return out


## 걸어서 가는 거리(적을 피해 돌아감). 못 가면 99.
func path_dist(u: Dictionary, to: Vector2i, fly: bool = false) -> int:
	var dist := {u.pos: 0}
	var q := [u.pos]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			return int(dist[c])
		for nb in AkD.neighbors(c):
			if dist.has(nb) or not is_floor(nb) and not (fly and cells.has(nb)):
				continue
			var o := unit_at(nb)
			if o != {} and o.side != u.side and nb != to:
				continue
			dist[nb] = int(dist[c]) + 1
			q.append(nb)
	return 99


func _move_to(u: Dictionary, c: Vector2i) -> void:
	if c == u.pos:
		return
	events.append({kind = "move", pos = c, from = u.pos})   # 화면이 말을 미끄러뜨린다(글은 없다)
	u.pos = c
	if cells.has(c) and cells[c].trap:
		cells[c].trap = false
		_damage(u, 3, {})
		events.append({kind = "trap", txt = "함정", pos = c})
	if u.side == "hero" and cells.has(c) and cells[c].door:
		for nb in AkD.neighbors(c):
			if cells.has(nb):
				_reveal(String(cells[nb].room))
		cells[c].door = false
		cells[c].room = "a" if revealed.has("a") else String(cells[c].room)
		revealed[cells[c].room] = true

# ==================== 라운드 ====================


func _start_round() -> void:
	round_no += 1
	for w: Array in waves.duplicate():
		if int(w[0]) == round_no:
			_spawn(int(w[1]), int(w[2]) == 1, AkD.axial(int(w[3]), int(w[4])))
			waves.erase(w)
	for h: Dictionary in heroes:
		h.pick = []
		h.rest = false
		if h.exh:
			continue
		if h.hand.size() < 2 and h.disc.size() < 2:
			_exhaust(h)
	if _check_end():
		return
	pending = "select"
	pend_h = _next_select(-1)
	if pend_h < 0:
		_begin_actions()


func _next_select(after: int) -> int:
	for i in range(after + 1, heroes.size()):
		if not heroes[i].exh:
			return i
	return -1


func can_long_rest(i: int) -> bool:
	return heroes[i].disc.size() >= 2


func must_rest(i: int) -> bool:
	return heroes[i].hand.size() < 2


## 카드 두 장(손패 번호, a 가 순서를 정하는 선도 카드). 같은 번호면 안 됨.
func select_cards(i: int, a: int, b: int) -> bool:
	if pending != "select" or i != pend_h:
		return false
	var h: Dictionary = heroes[i]
	if a == b or a < 0 or b < 0 or a >= h.hand.size() or b >= h.hand.size():
		return false
	h.pick = [h.hand[a], h.hand[b]]
	h.rest = false
	_after_select()
	return true


func long_rest(i: int) -> bool:
	if pending != "select" or i != pend_h or not can_long_rest(i):
		return false
	heroes[i].rest = true
	heroes[i].pick = []
	_after_select()
	return true


func _after_select() -> void:
	pend_h = _next_select(pend_h)
	if pend_h < 0:
		pending = ""
		_begin_actions()


func _begin_actions() -> void:
	order = []
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		if h.exh:
			continue
		order.append({kind = "hero", i = i, init = 99 if h.rest else int(h.pick[0].init)})
	var types := {}
	for u: Dictionary in alive_mons():
		types[int(u.k)] = true
	for m in types:
		var d: Dictionary = mdeck[m]
		if int(m) == AkD.SEAL:
			continue
		if d.deck.is_empty():
			d.deck = d.disc
			d.disc = []
			_shuffle(d.deck)
		d.cur = d.deck.pop_back()
		d.disc.append(d.cur)
		order.append({kind = "mon", m = int(m), init = int(d.cur.init)})
	order.sort_custom(func(x, y): return int(x.init) < int(y.init) or (int(x.init) == int(y.init) and x.kind == "hero" and y.kind != "hero"))
	turn_i = 0
	started = false


## 한 단계 진행(몬스터 한 마리 · 영웅 단계 하나). 고를 것이 있으면 pending 을 세우고 멈춘다.
func advance() -> void:
	if over or pending != "":
		return
	if turn_i >= order.size():
		_end_round()
		return
	var o: Dictionary = order[turn_i]
	if o.kind == "mon":
		if not started:
			started = true
			mon_q = []
			var ms := alive_mons().filter(func(u): return int(u.k) == int(o.m))
			ms.sort_custom(func(x, y): return int(x.elite) > int(y.elite))
			for u: Dictionary in ms:
				mon_q.append(u.id)
		if mon_q.is_empty():
			_next_turn()
			return
		var u2 := unit(mon_q.pop_front())
		if u2 != {} and u2.alive:
			_monster_turn(u2, mdeck[int(o.m)].cur)
		_check_end()
		return
	# 영웅
	var h: Dictionary = heroes[int(o.i)]
	var hu: Dictionary = h.unit
	if not started:
		started = true
		hero_on = int(o.i)
		if h.exh or not hu.alive:
			_next_turn()
			return
		if _turn_start(hu):
			_end_hero_turn(h)
			return
		if h.rest:
			_long_rest_do(h)
			_end_hero_turn(h)
			return
		pending = "first"
		pend_h = int(o.i)
		return
	if steps.is_empty():
		_end_hero_turn(h)
		return
	_run_step(h, steps.pop_front())
	_check_end()


## 위 행동을 어느 카드에서 쓸지 — k 0 이면 고른 카드 첫째의 위 + 둘째의 아래.
func choose_top(k: int) -> void:
	if pending != "first":
		return
	var h: Dictionary = heroes[pend_h]
	var a: Dictionary = h.pick[k]
	var b: Dictionary = h.pick[1 - k]
	hero_cards = [a, b]
	steps = []
	for s: Dictionary in a.top:
		steps.append(s.duplicate(true))
	for s: Dictionary in b.bot:
		steps.append(s.duplicate(true))
	pending = ""


func _next_turn() -> void:
	turn_i += 1
	started = false


## 차례 시작 — 출혈 피해, 기절이면 true(차례를 건너뜀).
func _turn_start(u: Dictionary) -> bool:
	if u.st.has("bleed"):
		_damage(u, 1, {})
		events.append({kind = "dot", txt = "출혈", pos = u.pos})
		if not u.alive:
			return true
	if u.st.has("stun"):
		u.st.erase("stun")
		events.append({kind = "stun", txt = "기절로 쉼", pos = u.pos})
		return true
	return false


func _end_unit_turn(u: Dictionary) -> void:
	for k in ["immob", "muddle", "inv", "strong"]:
		if u.st.has(k):
			u.st[k] = int(u.st[k]) - 1
			if int(u.st[k]) <= 0:
				u.st.erase(k)
	for e in infuse_q:
		elems[int(e)] = 2
	infuse_q = []


func _end_hero_turn(h: Dictionary) -> void:
	if not h.rest and h.pick.size() == 2 and not hero_cards.is_empty():
		var a: Dictionary = hero_cards[0]
		var b: Dictionary = hero_cards[1]
		for c: Dictionary in [a, b]:
			h.hand.erase(c)
		(h.lost if a.top_lost else h.disc).append(a)
		(h.lost if b.bot_lost else h.disc).append(b)
	hero_cards = []
	steps = []
	_end_unit_turn(h.unit)
	hero_on = -1
	_next_turn()


func _long_rest_do(h: Dictionary) -> void:
	var u: Dictionary = h.unit
	u.hp = mini(int(u.max), int(u.hp) + 2)
	# 버린 카드 중 하나를 잃고 나머지는 손으로(1차: 순서 숫자가 가장 큰 것 — 대개 강한 소멸 카드가 아닌 것을 남기려고)
	h.disc.sort_custom(func(x, y): return int(x.init) < int(y.init))
	var gone: Dictionary = h.disc.pop_back()
	h.lost.append(gone)
	h.hand += h.disc
	h.disc = []
	events.append({kind = "rest", txt = "긴 휴식, %s 잃음" % gone.name, pos = u.pos})


func _end_round() -> void:
	for i in 4:
		if int(elems[i]) > 0:
			elems[i] = int(elems[i]) - 1
	for u: Dictionary in units:
		u.s = 0
		u.ret = 0
	for h: Dictionary in heroes:
		if h.exh:
			continue
		if h.hand.size() < 2 and h.disc.size() >= 2:
			_shuffle(h.disc)
			var gone: Dictionary = h.disc.pop_back()
			h.lost.append(gone)
			h.hand += h.disc
			h.disc = []
			events.append({kind = "rest", txt = "짧은 휴식, %s 잃음" % gone.name, pos = h.unit.pos})
	if goal == "survive" and round_no >= rounds_goal:
		_finish(true)
		return
	_start_round()


func _exhaust(h: Dictionary) -> void:
	h.exh = true
	h.unit.alive = false
	events.append({kind = "exhaust", txt = "%s 쓰러짐" % AkD.HEROES[h.kind][0], pos = h.unit.pos})


func _finish(w: bool) -> void:
	over = true
	win = w
	pending = ""


func _check_end() -> bool:
	if over:
		return true
	if alive_heroes().is_empty():
		_finish(false)
		return true
	match goal:
		"all", "boss":
			if goal == "boss":
				var boss_alive := false
				var boss_seen := false
				for u: Dictionary in units:
					if u.side == "mon" and int(u.k) in AkD.BOSSES:
						boss_seen = true
						boss_alive = boss_alive or u.alive
				if boss_seen and not boss_alive:
					_finish(true)
					return true
			elif spawns.is_empty() and alive_mons().is_empty():
				_finish(true)
				return true
		"seal":
			var left := 0
			for s: Array in spawns:
				if int(s[0]) == AkD.SEAL:
					left += 1
			for u: Dictionary in alive_mons():
				if int(u.k) == AkD.SEAL:
					left += 1
			if left == 0:
				_finish(true)
				return true
	return false

# ==================== 영웅 단계 ====================


func _run_step(h: Dictionary, s: Dictionary) -> void:
	var u: Dictionary = h.unit
	if s.has("use"):
		var e := int(s.use)
		if int(elems[e]) > 0:
			elems[e] = 0
			var ub: Dictionary = s.ub
			if ub.has("a"):
				s.a = int(s.a) + int(ub.a)
			if ub.has("h"):
				s.h = int(s.h) + int(ub.h)
			if ub.has("eff"):
				s.eff = s.get("eff", []) + ub.eff
			events.append({kind = "elem", txt = "%s 소비" % AkD.ELEM_NAME[e], pos = u.pos, e = e, inf = false})
	if s.has("m"):
		if u.st.has("immob"):
			return
		_ask(h, s, reachable(u, int(s.m)))
	elif s.has("a"):
		if s.get("aoe", "") == "adj":
			for n in AkD.neighbors(u.pos):
				var t := unit_at(n)
				if t != {} and t.side == "mon":
					attack(u, t, s)
			return
		s.left = int(s.get("t", 1))
		s.hit = []
		_ask_attack(h, s)
	elif s.has("h"):
		if s.get("all", false):
			for x: Dictionary in alive_heroes():
				_heal(x, s)
		elif int(s.get("hr", 0)) == 0:
			_heal(u, s)
		else:
			_ask(h, s, _allies_in(u, int(s.hr)))
	elif s.has("s"):
		if s.has("hr"):
			_ask(h, s, _allies_in(u, int(s.hr)))
		else:
			u.s = int(u.s) + int(s.s)
	elif s.has("ret"):
		u.ret = int(u.ret) + int(s.ret)
	elif s.has("inf"):
		infuse_q.append(int(s.inf))
		events.append({kind = "elem", txt = "%s 주입" % AkD.ELEM_NAME[int(s.inf)], pos = u.pos, e = int(s.inf), inf = true})
	elif s.has("inv"):
		u.st.inv = 2
	elif s.has("strg"):
		_ask(h, s, _allies_in(u, int(s.get("hr", 0))))
	elif s.has("xp"):
		h.xp += int(s.xp)


func _allies_in(u: Dictionary, r: int) -> Array:
	var out := []
	for x: Dictionary in alive_heroes():
		if AkD.dist(u.pos, x.pos) <= r:
			out.append(x.pos)
	return out


func attack_targets(u: Dictionary, s: Dictionary) -> Array:
	var out := []
	var r := maxi(1, int(s.get("r", 0)))
	for t: Dictionary in alive_mons():
		if AkD.dist(u.pos, t.pos) <= r and not (t.id in s.get("hit", [])):
			out.append(t.pos)
	return out


func _ask_attack(h: Dictionary, s: Dictionary) -> void:
	var opts := attack_targets(h.unit, s)
	if opts.is_empty() or int(s.left) <= 0:
		return
	_ask(h, s, opts)


func _ask(h: Dictionary, s: Dictionary, opts: Array) -> void:
	if opts.is_empty():
		return
	pending = "step"
	pend_h = heroes.find(h)
	step_now = s
	options = opts


## 고르기 — 칸 c(options 안).
func choose(c: Vector2i) -> bool:
	if pending != "step" or not c in options:
		return false
	var h: Dictionary = heroes[pend_h]
	var u: Dictionary = h.unit
	var s := step_now
	pending = ""
	options = []
	if s.has("m"):
		_move_to(u, c)
	elif s.has("a"):
		var t := unit_at(c)
		attack(u, t, s)
		if s.get("aoe", "") == "blast":
			for n in AkD.neighbors(c):
				var t2 := unit_at(n)
				if t2 != {} and t2.side == "mon":
					attack(u, t2, s)
		s.hit.append(t.id)
		s.left = int(s.left) - 1
		_ask_attack(h, s)
	elif s.has("h"):
		_heal(unit_at(c), s)
	elif s.has("s"):
		var t3 := unit_at(c)
		t3.s = int(t3.s) + int(s.s)
	elif s.has("strg"):
		var t4 := unit_at(c)
		t4.st.strong = 2 if t4 == u else 1
	_check_end()
	return true


func skip() -> void:
	if pending == "step":
		pending = ""
		options = []
	elif pending == "first":
		choose_top(0)


func _heal(t: Dictionary, s: Dictionary) -> void:
	if t == {}:
		return
	if t.st.has("poison"):
		t.st.erase("poison")
		events.append({kind = "heal", txt = "독 풀림", pos = t.pos})
		if not s.get("cleanse", false):
			return
	if s.get("cleanse", false):
		for k in ["bleed", "stun", "immob", "muddle"]:
			t.st.erase(k)
	t.hp = mini(int(t.max), int(t.hp) + int(s.h))
	events.append({kind = "heal", txt = "+%d" % int(s.h), pos = t.pos})

# ==================== 공격 ====================


func _draw_amd(deck: Array, disc: Array) -> Variant:
	if deck.is_empty():
		deck.append_array(disc)
		disc.clear()
		_shuffle(deck)
	var v = deck.pop_back()
	disc.append(v)
	return v


## 공격 하나(영웅 → 몬스터 또는 몬스터 → 영웅). s: {a, eff, push, pull, flank}.
func attack(att: Dictionary, t: Dictionary, s: Dictionary) -> void:
	if t == {} or not t.alive:
		return
	var dmg := int(s.a)
	if att.st.has("strong"):
		dmg += 1
	if s.has("flank"):
		for x: Dictionary in alive_heroes():
			if x != att and AkD.dist(x.pos, t.pos) == 1:
				dmg += int(s.flank)
				break
	if t.st.has("mark"):
		dmg += 2
		t.st.erase("mark")
	var deck: Array = mamd
	var disc: Array = mamd_disc
	if att.side == "hero":
		var h := _hero_of(att)
		deck = h.amd
		disc = h.amd_disc
	var m = _draw_amd(deck, disc)
	if att.st.has("muddle"):
		var m2 = _draw_amd(deck, disc)
		m = m2 if _amd_rank(m2) < _amd_rank(m) else m
	if m is String:
		dmg = 0 if m == "x0" else dmg * 2
	else:
		dmg = maxi(0, dmg + int(m))
	if t.st.has("poison"):
		dmg += 1
	var shield := int(t.s)
	if t.side == "mon":
		shield += int(mon_stat(t).shield)
	var final_dmg := maxi(0, dmg - shield)
	events.append({kind = "hit", txt = "-%d" % final_dmg, pos = t.pos, from = att.pos, amd = str(m), crit = m is String and m == "x2", miss = m is String and m == "x0"})
	_damage(t, final_dmg, s)
	if t.alive:
		for e in s.get("eff", []):
			t.st[e] = 1
		if s.has("push"):
			_push(att, t, int(s.push))
	# 반격 — 근접에서 맞으면
	var ret := int(t.ret) + (int(mon_stat(t).ret) if t.side == "mon" else 0)
	if ret > 0 and AkD.dist(att.pos, t.pos) == 1 and att.alive:
		_damage(att, ret, {})
		events.append({kind = "hit", txt = "반격 -%d" % ret, pos = att.pos, from = t.pos})


func _amd_rank(m) -> int:
	if m is String:
		return -10 if m == "x0" else 10
	return int(m)


func _hero_of(u: Dictionary) -> Dictionary:
	for h: Dictionary in heroes:
		if h.unit == u:
			return h
	return {}


func _damage(t: Dictionary, n: int, _s: Dictionary) -> void:
	if n <= 0:
		return
	t.hp = int(t.hp) - n
	if int(t.hp) <= 0:
		t.alive = false
		if t.side == "hero":
			var h := _hero_of(t)
			if h != {}:
				h.exh = true
			events.append({kind = "exhaust", txt = "%s 쓰러짐" % AkD.HEROES[int(t.k)][0], pos = t.pos})
		else:
			events.append({kind = "kill", txt = "%s 처치" % mon_stat(t).name, pos = t.pos})


func _push(att: Dictionary, t: Dictionary, n: int) -> void:
	for k in n:
		var best: Vector2i = t.pos
		var bd := AkD.dist(att.pos, t.pos)
		for nb in AkD.neighbors(t.pos):
			if is_floor(nb) and unit_at(nb) == {} and AkD.dist(att.pos, nb) > bd:
				best = nb
				bd = AkD.dist(att.pos, nb)
		if best == t.pos:
			return
		_move_to(t, best)

# ==================== 몬스터 ====================


## 몬스터 한 마리의 차례 — 초점(가장 적게 걸어서 공격할 수 있는 영웅)으로 다가가 공격.
func _monster_turn(u: Dictionary, card: Dictionary) -> void:
	if _turn_start(u):
		_end_unit_turn(u)
		return
	var st := mon_stat(u)
	var ex: Dictionary = card.extra
	if ex.has("s"):
		u.s = int(u.s) + int(ex.s)
	if ex.has("heal"):
		var low := {}
		for o: Dictionary in alive_mons():
			if AkD.dist(o.pos, u.pos) <= 3 and int(o.hp) < int(o.max) and (low == {} or int(o.hp) < int(low.hp)):
				low = o
		if low != {}:
			low.hp = mini(int(low.max), int(low.hp) + int(ex.heal))
			events.append({kind = "heal", txt = "+%d" % int(ex.heal), pos = low.pos})
	if int(st.atk) <= 0 and int(st.move) <= 0:
		_end_unit_turn(u)
		return
	var mv := maxi(0, int(st.move) + int(card.dm))
	var atk := maxi(1, int(st.atk) + int(card.da))
	var rng_m := maxi(1, int(st.rng))
	var focus := _focus(u, bool(st.fly))
	if focus != {} and not u.st.has("immob"):
		var best: Vector2i = u.pos
		var best_score := _pos_score(u, u.pos, focus, rng_m)
		for c in reachable(u, mv, bool(st.fly)):
			var sc := _pos_score(u, c, focus, rng_m)
			if sc < best_score:
				best_score = sc
				best = c
		_move_to(u, best)
		if not u.alive:
			return
	var s := {a = atk, eff = st.eff + ex.get("eff", [])}
	if ex.get("aoe", "") == "adj":
		for n in AkD.neighbors(u.pos):
			var t := unit_at(n)
			if t != {} and t.side == "hero":
				attack(u, t, s)
	else:
		var targets := []
		if focus != {} and AkD.dist(u.pos, focus.pos) <= rng_m and focus.alive:
			targets.append(focus)
		var extra_t := int(ex.get("t", 1)) - 1
		for x: Dictionary in alive_heroes():
			if extra_t <= 0:
				break
			if x != focus and AkD.dist(u.pos, x.pos) <= rng_m and not x.st.has("inv"):
				targets.append(x)
				extra_t -= 1
		for t: Dictionary in targets:
			attack(u, t, s)
	_end_unit_turn(u)


func _focus(u: Dictionary, fly: bool) -> Dictionary:
	var best := {}
	var bd := 999
	for x: Dictionary in alive_heroes():
		if x.st.has("inv"):
			continue
		var d := path_dist(u, x.pos, fly)
		if d < bd:
			bd = d
			best = x
	return best


## 자리 점수(작을수록 좋음) — 사거리 안이면 0(원거리는 붙지 않는 쪽), 아니면 남은 걸음.
func _pos_score(u: Dictionary, c: Vector2i, focus: Dictionary, rng_m: int) -> float:
	var d := AkD.dist(c, focus.pos)
	if d <= rng_m:
		return (0.5 if rng_m > 1 and d == 1 else 0.0) + (0.3 if cells.has(c) and cells[c].trap else 0.0)
	var save: Vector2i = u.pos
	u.pos = c
	var pd := path_dist(u, focus.pos)
	u.pos = save
	return 1.0 + pd
