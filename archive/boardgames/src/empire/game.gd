class_name EmGame
extends RefCounted

## 제국 연대기 한 판 — 규칙 계산만(그리기 · 소리 · 저장 · 오토로드를 부르지 마세요 — `tools/empire_check.gd` 가
## `--script` 로 이 파일만 읽어 봇끼리 수천 판을 돌립니다).
##
## 흐름: 불가사의 드래프트(`pending = "draft"`) → 1시대 → 2시대 → 3시대 → 문명 점수.
## 차례 하나 = 피라미드에서 위가 열린 카드 한 장으로 [짓기 · 버리기 · 불가사의 짓기] 중 하나.
## 사람이 골라야 하는 것(발전 토큰 · 도서관 카드 · 드래프트)은 `pending` 으로 멈추고, AI 는 `EmAi.resolve` 가 바로 답합니다.
## 군사(`mil` — 양수면 0번이 1번 쪽으로 밀고 있음)나 과학으로 즉시 끝날 수 있습니다(`win_kind`).

var rng := RandomNumberGenerator.new()
var age := 0
var slots: Array = []          ## 이번 시대 피라미드 {card, row, x, face, taken}
var players: Array = []        ## {coin, cards[], wonders[{w, built}], tokens[], sci[7], extra_pts, ai}
var mil := 0
var mil_paid := {}             ## "쪽_칸" → 이미 돈을 잃었나
var tokens_open: Array = []    ## 공개된 발전 토큰(가져가면 빠짐)
var discard: Array = []        ## 버린 카드(도서관이 다시 씀)
var wonders_built := 0
var cur := 0
var last_actor := 0
var turn_no := 0
var over := false
var winner := -1               ## -1 = 무승부(문명 점수까지 같을 때)
var win_kind := ""             ## "mil" · "sci" · "civ"
var pending := ""              ## "" · "draft" · "token" · "library" · "starter"(다음 시대 선 고르기)
var pend_p := 0                ## pending 을 풀어야 할 사람
var draft_pool: Array = []     ## 드래프트 중 펼친 불가사의
var draft_rest: Array = []     ## 두 번째 드래프트 넷
var draft_i := 0               ## 드래프트 몇 번째 고르기(0~7)
const DRAFT_ORDER := [0, 1, 1, 0, 1, 0, 0, 1]   ## 첫 선(first) 기준 — 0 이 첫 선, 1 이 그 상대
var first := 0                 ## 첫 선(무작위) — 드래프트를 먼저 고르고 1시대를 먼저 둔다
var events: Array = []         ## 화면에 띄울 일 [{p, txt}]
var last := {}                 ## 방금 한 행동(그림 쪽이 씀)


func _init(seed_v: int = -1, ai_mask: Array = [false, true], first_p: int = -1) -> void:
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	first = first_p if first_p >= 0 else rng.randi_range(0, 1)
	for i in 2:
		players.append({coin = EmD.START_COIN, cards = [], wonders = [], tokens = [], sci = [0, 0, 0, 0, 0, 0, 0],
				extra_pts = 0, ai = bool(ai_mask[i]) if i < ai_mask.size() else i != 0})
	var tk := range(EmD.TOKENS.size())
	_shuffle(tk)
	for k in 5:
		tokens_open.append(EmD.token(tk[k]))
	var ws := range(EmD.WONDERS.size())
	_shuffle(ws)
	for k in 4:
		draft_pool.append(EmD.wonder(ws[k]))
	for k in 4:
		draft_rest.append(EmD.wonder(ws[4 + k]))
	pending = "draft"
	pend_p = _draft_p(0)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func opp(p: int) -> int:
	return 1 - p


func _draft_p(i: int) -> int:
	return first if DRAFT_ORDER[i] == 0 else opp(first)

# ==================== 드래프트 ====================


func draft_pick(k: int) -> void:
	if pending != "draft" or k < 0 or k >= draft_pool.size():
		return
	var w: Dictionary = draft_pool[k]
	draft_pool.remove_at(k)
	players[pend_p].wonders.append({w = w, built = false})
	last = {kind = "draft", p = pend_p, wonder = w}
	draft_i += 1
	if draft_i == 4:
		draft_pool = draft_rest
		draft_rest = []
	if draft_i >= 8:
		pending = ""
		_setup_age(0, first)
		return
	pend_p = _draft_p(draft_i)

# ==================== 피라미드 ====================


func _setup_age(a: int, starter: int) -> void:
	age = a
	var deck := EmD.age_cards(a)
	_shuffle(deck)
	deck.resize(deck.size() - 3)
	if a == 2:
		var gs := EmD.guild_cards()
		_shuffle(gs)
		deck += gs.slice(0, 3)
		_shuffle(deck)
	slots = []
	var lay: Array = EmD.LAYOUT[a]
	var n := 0
	for r in lay.size():
		for x in lay[r][0]:
			slots.append({card = deck[n], row = r, x = int(x), face = bool(lay[r][1]), taken = false})
			n += 1
	cur = starter
	_reveal()
	if a > 0:
		for p in 2:
			for tk: Dictionary in players[p].tokens:
				if tk.eff.has("coin_age"):
					players[p].coin += int(tk.eff.coin_age)
			if a == 2:
				for c: Dictionary in players[p].cards:
					if c.eff.has("coin_age3"):
						players[p].coin += int(c.eff.coin_age3)


## 덮고 있는 카드가 없으면 집을 수 있다.
func is_open(i: int) -> bool:
	var s: Dictionary = slots[i]
	if s.taken:
		return false
	for o: Dictionary in slots:
		if not o.taken and int(o.row) == int(s.row) + 1 and absi(int(o.x) - int(s.x)) == 1:
			return false
	return true


func available() -> Array:
	var out := []
	for i in slots.size():
		if is_open(i):
			out.append(i)
	return out


## 위가 열린 카드는 앞면으로 뒤집는다.
func _reveal() -> void:
	for i in slots.size():
		if is_open(i):
			slots[i].face = true


## 이 칸을 가져가면 새로 열리는 칸들(AI 가 상대에게 무엇을 열어 주나 볼 때).
func would_open(i: int) -> Array:
	var s: Dictionary = slots[i]
	s.taken = true
	var out := []
	for j in slots.size():
		if j != i and int(slots[j].row) == int(s.row) - 1 and is_open(j):
			out.append(j)
	s.taken = false
	return out

# ==================== 셈 ====================


func count_kind(p: int, k: int) -> int:
	var n := 0
	for c: Dictionary in players[p].cards:
		if int(c.kind) == k:
			n += 1
	return n


## 고정 생산(갈색 · 회색 카드 + 토큰).
func production(p: int) -> Array:
	var out := [0, 0, 0, 0, 0]
	for c: Dictionary in players[p].cards:
		if c.eff.has("prod"):
			for r in EmD.N_RES:
				out[r] += int(c.eff.prod[r])
	for tk: Dictionary in players[p].tokens:
		if tk.eff.has("prod"):
			for r in EmD.N_RES:
				out[r] += int(tk.eff.prod[r])
	return out


## 상대 가격에 들어가는 생산 — 갈색 · 회색 카드만(노란 카드 · 불가사의 · 토큰의 생산은 안 셈).
func card_production(p: int) -> Array:
	var out := [0, 0, 0, 0, 0]
	for c: Dictionary in players[p].cards:
		if int(c.kind) <= EmD.K.GREY and c.eff.has("prod"):
			for r in EmD.N_RES:
				out[r] += int(c.eff.prod[r])
	return out


## 매 턴 고를 수 있는 자원들(노란 카드 · 불가사의).
func picks(p: int) -> Array:
	var out := []
	for c: Dictionary in players[p].cards:
		if c.eff.has("pick"):
			out.append(c.eff.pick)
	for w: Dictionary in players[p].wonders:
		if w.built and w.w.eff.has("pick"):
			out.append(w.w.eff.pick)
	return out


func _has_eff(p: int, key: String) -> int:
	var n := 0
	for c: Dictionary in players[p].cards:
		if c.eff.has(key):
			n += int(c.eff[key]) if not (c.eff[key] is bool) else 1
	for w: Dictionary in players[p].wonders:
		if w.built and w.w.eff.has(key):
			n += int(w.w.eff[key]) if not (w.w.eff[key] is bool) else 1
	for tk: Dictionary in players[p].tokens:
		if tk.eff.has(key):
			n += int(tk.eff[key]) if not (tk.eff[key] is bool) else 1
	return n


## 자원 하나를 은행에서 살 때 값.
func price(p: int, r: int) -> int:
	var v := 2 + int(card_production(opp(p))[r])
	for c: Dictionary in players[p].cards:
		if c.eff.has("fix") and c.eff.fix.has(r):
			v = mini(v, int(c.eff.fix[r]))
	var minus := _has_eff(p, "buy_minus")
	if r in EmD.RAW:
		minus += _has_eff(p, "raw_minus")
	return maxi(1, v - minus)


## 자원 비용을 내는 데 드는 돈(돈 비용 제외). waive = 비싼 것부터 면제할 자원 수.
func res_coins(p: int, cost: Array, waive: int = 0) -> int:
	var prod := production(p)
	var pk := picks(p)
	var best := 1 << 30
	var combos := 1
	for opts: Array in pk:
		combos *= opts.size()
	for m in combos:
		var have := prod.duplicate()
		var mm := m
		for opts: Array in pk:
			have[int(opts[mm % opts.size()])] += 1
			mm /= opts.size()
		var units := []
		for r in EmD.N_RES:
			for k in maxi(0, int(cost[r]) - int(have[r])):
				units.append(price(p, r))
		units.sort()
		for k in mini(waive, units.size()):
			units.pop_back()
		var s := 0
		for v in units:
			s += int(v)
		best = mini(best, s)
	return best


func has_card(p: int, name: String) -> bool:
	for c: Dictionary in players[p].cards:
		if c.name == name:
			return true
	return false


## 카드를 짓는 데 드는 돈(연계면 0).
func card_cost(p: int, c: Dictionary) -> int:
	if c.chain != "" and has_card(p, c.chain):
		return 0
	var waive := _has_eff(p, "blue_waive") if int(c.kind) == EmD.K.BLUE else 0
	return int(c.coin) + res_coins(p, c.cost, waive)


func wonder_cost(p: int, w: Dictionary) -> int:
	return res_coins(p, w.cost, _has_eff(p, "wonder_waive"))


func can_build(p: int, c: Dictionary) -> bool:
	return card_cost(p, c) <= int(players[p].coin)


## 지을 수 있는 내 불가사의 번호들(7개 제한 · 돈).
func wonder_options(p: int) -> Array:
	var out := []
	if wonders_built >= EmD.WONDER_MAX:
		return out
	for k in players[p].wonders.size():
		var w: Dictionary = players[p].wonders[k]
		if not w.built and not w.get("dead", false) and wonder_cost(p, w.w) <= int(players[p].coin):
			out.append(k)
	return out


func discard_gain(p: int) -> int:
	return EmD.DISCARD_BASE + count_kind(p, EmD.K.YELLOW) + _has_eff(p, "disc")


func sci_kinds(p: int) -> int:
	var n := 0
	for v in players[p].sci:
		if int(v) > 0:
			n += 1
	return n


## 군사 말이 p 의 상대 쪽으로 넘어간 칸 수(음수면 밀리는 중).
func mil_for(p: int) -> int:
	return mil if p == 0 else -mil

# ==================== 행동 ====================


func can_act() -> bool:
	return not over and pending == ""


## action: "build" · "discard" · "wonder"(wk = 내 불가사의 번호). 못 하면 false.
func act(i: int, action: String, wk: int = -1) -> bool:
	if not can_act() or i < 0 or i >= slots.size() or not is_open(i):
		return false
	var p := cur
	var c: Dictionary = slots[i].card
	var pl: Dictionary = players[p]
	match action:
		"build":
			var cost := card_cost(p, c)
			if cost > int(pl.coin):
				return false
			pl.coin -= cost
			slots[i].taken = true
			last = {kind = "build", p = p, card = c, slot = i, paid = cost}
			_gain_card(p, c)
		"discard":
			var gain := discard_gain(p)
			pl.coin += gain
			slots[i].taken = true
			discard.append(c)
			last = {kind = "discard", p = p, card = c, slot = i, gain = gain}
			events.append({p = p, txt = "%s 버리고 돈 %d" % [c.name, gain]})
		"wonder":
			if not wk in wonder_options(p):
				return false
			var w: Dictionary = pl.wonders[wk]
			pl.coin -= wonder_cost(p, w.w)
			slots[i].taken = true
			w.built = true
			wonders_built += 1
			last = {kind = "wonder", p = p, card = c, slot = i, wonder = w.w, wk = wk}
			events.append({p = p, txt = "%s 완성" % w.w.name})
			_gain_wonder(p, w.w)
			if wonders_built >= EmD.WONDER_MAX:
				for q in 2:
					for o: Dictionary in players[q].wonders:
						if not o.built:
							o.dead = true
		_:
			return false
	last_actor = p
	turn_no += 1
	_reveal()
	if over:
		return true
	var again: bool = action == "wonder" and bool(last.wonder.eff.get("again", false))
	_again_flag = again
	if pending != "":
		return true   # 토큰 · 도서관을 고른 뒤 _after_pending 이 차례를 넘긴다
	_next(again)
	return true


func _next(again: bool) -> void:
	if over:
		return
	if available().is_empty():
		if age >= EmD.AGE_N - 1:
			_end_civ()
			return
		# 다음 시대 선은 군사에서 밀리는 쪽이 고른다(같으면 방금 마지막 카드를 가져간 쪽)
		pending = "starter"
		pend_p = last_actor
		if mil > 0:
			pend_p = 1
		elif mil < 0:
			pend_p = 0
		return
	if not again:
		cur = opp(cur)


func _gain_card(p: int, c: Dictionary) -> void:
	var pl: Dictionary = players[p]
	pl.cards.append(c)
	var e: Dictionary = c.eff
	if e.has("coin"):
		pl.coin += int(e.coin)
	if e.has("per_brown"):
		pl.coin += count_kind(p, EmD.K.BROWN) * int(e.per_brown)
	if e.has("opp_yellow"):
		pl.coin += count_kind(opp(p), EmD.K.YELLOW) * int(e.opp_yellow)
	if e.get("guild", "") == "yellow":
		pl.coin += count_kind(p, EmD.K.YELLOW)
	if int(c.kind) == EmD.K.BLUE:
		pl.extra_pts += _has_eff(p, "blue_pts")
	if e.has("mil"):
		_military(p, int(e.mil))
	if e.has("sci") and not over:
		_science(p, int(e.sci))


func _gain_wonder(p: int, w: Dictionary) -> void:
	var pl: Dictionary = players[p]
	var e: Dictionary = w.eff
	pl.coin += _has_eff(p, "wonder_coin")
	if e.has("coin"):
		pl.coin += int(e.coin)
	if e.has("opp_coin"):
		players[opp(p)].coin = maxi(0, int(players[opp(p)].coin) - int(e.opp_coin))
	if e.has("mil"):
		_military(p, int(e.mil))
	if e.has("sci") and not over:
		_science(p, int(e.sci))
	if over:
		return
	if e.has("token") and not tokens_open.is_empty():
		pending = "token"
		pend_p = p
	elif e.get("library", false) and not library_options().is_empty():
		pending = "library"
		pend_p = p


func _military(p: int, n: int) -> void:
	mil = clampi(mil + (n if p == 0 else -n), -EmD.MIL_WIN, EmD.MIL_WIN)
	var d := mil_for(p)
	for th: Array in EmD.MIL_LOSS:
		var key := "%d_%d" % [p, int(th[0])]
		if d >= int(th[0]) and not mil_paid.has(key):
			mil_paid[key] = true
			var o := opp(p)
			if _has_eff(o, "no_mil_loss") == 0:
				players[o].coin = maxi(0, int(players[o].coin) - int(th[1]))
	if d >= EmD.MIL_WIN:
		_win(p, "mil")


func _science(p: int, s: int) -> void:
	var sc: Array = players[p].sci
	sc[s] += 1
	if sci_kinds(p) >= EmD.SCI_WIN:
		_win(p, "sci")
		return
	if int(sc[s]) == 2 and not tokens_open.is_empty():
		pending = "token"
		pend_p = p


func _win(p: int, kind: String) -> void:
	over = true
	winner = p
	win_kind = kind
	pending = ""

# ==================== pending 풀기 ====================


func pick_token(k: int) -> void:
	if pending != "token" or k < 0 or k >= tokens_open.size():
		return
	var tk: Dictionary = tokens_open[k]
	tokens_open.remove_at(k)
	var p := pend_p
	players[p].tokens.append(tk)
	pending = ""
	last = {kind = "token", p = p, token = tk}
	events.append({p = p, txt = "발전 토큰 %s" % tk.name})
	if tk.eff.has("coin"):
		players[p].coin += int(tk.eff.coin)
	if tk.eff.has("sci"):
		_science(p, int(tk.eff.sci))
	if not over and pending == "":
		_after_pending()


## 다음 시대를 누가 먼저 둘지(who) — 고르는 사람은 pend_p.
func pick_starter(who: int) -> void:
	if pending != "starter" or who < 0 or who > 1:
		return
	pending = ""
	last = {kind = "starter", p = pend_p, who = who}
	_setup_age(age + 1, who)
	events.append({p = who, txt = "%d시대 시작, 먼저 둡니다" % (age + 1)})


func library_options() -> Array:
	var out := []
	for k in discard.size():
		if int(discard[k].kind) == EmD.K.GREEN:
			out.append(k)
	return out


func pick_library(k: int) -> void:
	if pending != "library" or not k in library_options():
		return
	var c: Dictionary = discard[k]
	discard.remove_at(k)
	pending = ""
	last = {kind = "library", p = pend_p, card = c}
	events.append({p = pend_p, txt = "도서관에서 %s" % c.name})
	_gain_card(pend_p, c)
	if not over and pending == "":
		_after_pending()


## pending 이 풀린 뒤 — 그 행동의 차례 넘기기를 마저 한다.
func _after_pending() -> void:
	_next(_again_flag)


var _again_flag := false   ## act() 가 pending 으로 멈췄을 때, 그 행동에 추가 턴이 있었나

# ==================== 점수 ====================


func points(p: int) -> int:
	return int(score_parts(p).total)


func score_parts(p: int) -> Dictionary:
	var pl: Dictionary = players[p]
	var d := {blue = 0, green = 0, yellow = 0, guild = 0, wonder = 0, token = 0, mil = 0, coin = 0}
	for c: Dictionary in pl.cards:
		var pts := int(c.eff.get("pts", 0))
		match int(c.kind):
			EmD.K.BLUE:
				d.blue += pts
			EmD.K.GREEN:
				d.green += pts
			EmD.K.YELLOW:
				d.yellow += pts
				if c.eff.has("per_red_pts"):
					d.yellow += count_kind(p, EmD.K.RED) * int(c.eff.per_red_pts)
			EmD.K.PURPLE:
				d.guild += _guild_pts(p, String(c.eff.guild))
			_:
				d.yellow += pts
	d.blue += int(pl.extra_pts)
	for w: Dictionary in pl.wonders:
		if w.built:
			d.wonder += int(w.w.eff.get("pts", 0))
	for tk: Dictionary in pl.tokens:
		d.token += int(tk.eff.get("pts", 0))
		if tk.eff.has("pair_pts"):
			var pairs := 0
			for v in pl.sci:
				pairs += int(v) / 2
			d.token += pairs * int(tk.eff.pair_pts)
	d.mil = EmD.mil_points(maxi(0, mil_for(p)))
	d.coin = int(pl.coin) / 3
	var tot := 0
	for k in d:
		tot += int(d[k])
	d.total = tot
	return d


func _guild_pts(p: int, kind: String) -> int:
	match kind:
		"wonder":
			var n := 0
			for w: Dictionary in players[p].wonders:
				if w.built:
					n += 1
			return n * 2
		"yellow":
			return count_kind(p, EmD.K.YELLOW)
		"green":
			return count_kind(p, EmD.K.GREEN)
		"craft":
			return (count_kind(p, EmD.K.BROWN) + count_kind(p, EmD.K.GREY)) / 2
		"blue":
			return count_kind(p, EmD.K.BLUE)
		"red":
			return count_kind(p, EmD.K.RED)
		"coin":
			return int(players[p].coin) / 3
	return 0


func _end_civ() -> void:
	over = true
	win_kind = "civ"
	var a := points(0)
	var b := points(1)
	if a != b:
		winner = 0 if a > b else 1
	else:
		var ba := int(score_parts(0).blue)
		var bb := int(score_parts(1).blue)
		winner = -1 if ba == bb else (0 if ba > bb else 1)
