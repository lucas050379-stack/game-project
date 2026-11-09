class_name RsGame
extends RefCounted

## 붉은 별 개척단 한 판 — 규칙 계산만(그리기 · 소리 · 저장 · 오토로드를 부르지 마세요 — `tools/redstar_check.gd` 가
## `--script` 로 이 파일만 읽어 봇끼리 수천 판을 돌립니다).
##
## 흐름: 기업 고르기 + 첫 카드 사기(`pending = "corp"`) → 세대 반복 [연구(`"research"`) → 행동(번갈아 한 번에 하나, 둘 다 패스하면 끝)
## → 생산] → 세 지표가 다 차거나 14세대면 끝. 타일을 놓아야 하면 `"place"` 로 멈춥니다(AI 는 `best_cell` 로 바로 놓음).
## 장르 규칙과 다른 점: 한 차례에 행동 **하나**(장르는 1~2) — 1대1 에서 화면 흐름을 단순하게.

var rng := RandomNumberGenerator.new()
var gen := 1
var params := [0, 0, 0]          ## 온도 · 대기 · 바다
var tiles := {}                  ## Vector2i → {kind: "ocean" · "green" · "city", owner}
var players: Array = []
var deck: Array = []
var discard: Array = []
var cur := 0
var first_start := 0           ## 1세대 선(검산이 선 승률을 볼 때)
var first := 0                   ## 이번 세대 선
var over := false
var winner := -1
var turn_no := 0
var pending := ""                ## "" · "corp" · "research" · "place"
var pend_p := 0
var offer: Array = [[], []]      ## 연구 · 시작에서 보여 준 카드(사람마다)
var corp_offer: Array = [[], []]
var place_q: Array = []          ## 놓아야 할 타일 [{p, kind}] — 앞에서부터
var milestones := [-1, -1, -1]   ## 선점한 사람
var awards := [-1, -1, -1]       ## 개설한 사람
var events: Array = []
var last := {}


func _init(seed_v: int = -1, ai_mask: Array = [false, true]) -> void:
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	for i in 2:
		players.append({corp = {}, res = [0, 0, 0, 0, 0, 0], prod = [0, 0, 0, 0, 0, 0], tr = RsD.START_TR, hand = [],
				played = [], acc = {}, used = {}, passed = false, ai = bool(ai_mask[i]) if i < ai_mask.size() else i != 0,
				ms = 0, aw = 0})
	deck = RsD.all_cards()
	_shuffle(deck)
	var cs := range(RsD.CORPS.size())
	_shuffle(cs)
	for i in 2:
		corp_offer[i] = [cs[i * 2], cs[i * 2 + 1]]
		offer[i] = _draw_n(RsD.START_HAND)
	first = rng.randi_range(0, 1)
	first_start = first
	pending = "corp"
	pend_p = first


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func opp(p: int) -> int:
	return 1 - p


func _draw_n(n: int) -> Array:
	var out := []
	for k in n:
		if deck.is_empty():
			deck = discard
			discard = []
			_shuffle(deck)
		if deck.is_empty():
			break
		out.append(deck.pop_back())
	return out

# ==================== 시작 · 연구 ====================


## 시작: 기업 하나(corp_offer 안의 번호 k)와 살 카드(offer 안의 번호들).
func choose_corp(k: int, buy: Array) -> bool:
	if pending != "corp" or k < 0 or k > 1:
		return false
	var p := pend_p
	var ci: int = corp_offer[p][k]
	var row: Array = RsD.CORPS[ci]
	var pl: Dictionary = players[p]
	var start := int(row[1])
	if buy.size() * RsD.CARD_BUY > start:
		return false
	pl.corp = {id = ci, name = String(row[0]), ab = String(row[4]), desc = String(row[5])}
	pl.res[0] = start - buy.size() * RsD.CARD_BUY
	for r in row[2]:
		pl.prod[int(r)] += int(row[2][r])
	for r in row[3]:
		pl.res[int(r)] += int(row[3][r])
	_take_offer(p, buy)
	if pl.corp.ab == "sci_draw":
		pl.hand += _draw_n(2)
	last = {kind = "corp", p = p}
	events.append({p = p, txt = "%s 선택" % pl.corp.name})
	if p == first:
		pend_p = opp(first)
	else:
		pending = ""
		cur = first
	return true


func _take_offer(p: int, buy: Array) -> void:
	var keep := []
	for k in offer[p].size():
		if k in buy:
			keep.append(offer[p][k])
		else:
			discard.append(offer[p][k])
	players[p].hand += keep
	offer[p] = []


## 연구 — 보여 준 4장 중 살 것.
func buy_research(buy: Array) -> bool:
	if pending != "research":
		return false
	var p := pend_p
	if buy.size() * RsD.CARD_BUY > int(players[p].res[0]):
		return false
	players[p].res[0] -= buy.size() * RsD.CARD_BUY
	_take_offer(p, buy)
	last = {kind = "research", p = p, n = buy.size()}
	if p == first:
		pend_p = opp(first)
	else:
		pending = ""
		cur = first
	return true

# ==================== 셈 ====================


func count_tag(p: int, t: int) -> int:
	var n := 0
	for c: Dictionary in players[p].played:
		if int(c.kind) == 2:
			if t == 7:
				n += 1
			continue
		for x in c.tags:
			if int(x) == t:
				n += 1
	return n


func metal_val(p: int) -> int:
	return 3 if players[p].corp.get("ab", "") == "metal3" else RsD.METAL_VAL


func green_cost(p: int) -> int:
	return 6 if players[p].corp.get("ab", "") == "green6" else RsD.GREEN_COST


func heat_cost(p: int) -> int:
	return 6 if players[p].corp.get("ab", "") == "heat6" else RsD.HEAT_COST


func card_cost(p: int, c: Dictionary) -> int:
	var v := int(c.cost)
	for pc: Dictionary in players[p].played:
		if pc.eff.has("disc"):
			for k in pc.eff.disc:
				if str(k) == "all" or int(k) in c.tags:
					v -= int(pc.eff.disc[k])
	return maxi(0, v)


## 이 카드에 쓸 수 있는 돈 전부(크레딧 + 금속 · 합금 환산).
func buying_power(p: int, c: Dictionary) -> int:
	var pl: Dictionary = players[p]
	var v := int(pl.res[0])
	if 0 in c.tags:
		v += int(pl.res[1]) * metal_val(p)
	if 1 in c.tags:
		v += int(pl.res[2]) * RsD.ALLOY_VAL
	return v


func req_ok(c: Dictionary) -> bool:
	var q: Dictionary = c.req
	if q.has("tmin") and int(params[0]) < int(q.tmin):
		return false
	if q.has("tmax") and int(params[0]) > int(q.tmax):
		return false
	if q.has("omin") and int(params[1]) < int(q.omin):
		return false
	if q.has("omax") and int(params[1]) > int(q.omax):
		return false
	if q.has("wmin") and int(params[2]) < int(q.wmin):
		return false
	return true


func _prod_ok(p: int, e: Dictionary) -> bool:
	if not e.has("prod"):
		return true
	for r in e.prod:
		var v := int(players[p].prod[int(r)]) + int(e.prod[r])
		if v < (RsD.PROD_MIN if int(r) == 0 else 0):
			return false
	return true


func can_play(p: int, c: Dictionary) -> bool:
	if not req_ok(c) or not _prod_ok(p, c.eff):
		return false
	if c.eff.get("tile", "") == "city" and legal_cells(p, "city").is_empty():
		return false
	if c.eff.get("tile", "") == "green" and legal_cells(p, "green").is_empty():
		return false
	return buying_power(p, c) >= card_cost(p, c)


func maxed() -> bool:
	for k in 3:
		if int(params[k]) < int(RsD.PARAM_MAX[k]):
			return false
	return true


## 남은 지표 단계 수.
func steps_left() -> int:
	var n := 0
	for k in 3:
		n += int(RsD.PARAM_MAX[k]) - int(params[k])
	return n

# ==================== 지도 ====================


func legal_cells(p: int, kind: String) -> Array:
	var out := []
	var free := []
	for c in RsD.cells():
		if tiles.has(c):
			continue
		var k := RsD.cell_kind(c)
		match kind:
			"ocean":
				if k == 1:
					out.append(c)
			"city":
				if k == 1:
					continue
				var ok := true
				for n in RsD.neighbors(c):
					if tiles.has(n) and tiles[n].kind == "city":
						ok = false
				if ok:
					out.append(c)
			"green":
				if k == 1:
					continue
				free.append(c)
				for n in RsD.neighbors(c):
					if tiles.has(n) and int(tiles[n].owner) == p:
						out.append(c)
						break
	if kind == "green" and out.is_empty():
		return free
	return out


## 이 자리에 놓으면 얻는 것의 대략 값(AI · 자동 놓기용).
func cell_value(p: int, c: Vector2i, kind: String) -> float:
	var v := 0.0
	var b := RsD.cell_bonus(c)
	for r in b:
		v += 3.0 if str(r) == "card" else (2.0 if int(r) == 1 else 1.5) * int(b[r])
	for n in RsD.neighbors(c):
		if tiles.has(n):
			var t: Dictionary = tiles[n]
			if t.kind == "ocean":
				v += 2.0
			if kind == "green" and t.kind == "city" and int(t.owner) == p:
				v += 4.0
			if kind == "green" and t.kind == "city" and int(t.owner) != p:
				v -= 2.0
			if kind == "city" and t.kind == "green":
				v += 4.0
		elif kind == "city" and RsD.cell_kind(n) != 1:
			v += 1.0   # 앞으로 녹지가 둘러쌀 자리
	return v


func best_cell(p: int, kind: String) -> Vector2i:
	var best := Vector2i(99, 99)
	var bv := -INF
	for c in legal_cells(p, kind):
		var v := cell_value(p, c, kind) + rng.randf() * 0.1
		if v > bv:
			bv = v
			best = c
	return best


## 타일 하나 놓기(자리는 legal_cells 안이어야 한다).
func place(c: Vector2i) -> bool:
	if pending != "place" or place_q.is_empty():
		return false
	var q: Dictionary = place_q[0]
	var p: int = q.p
	if not c in legal_cells(p, q.kind):
		return false
	place_q.pop_front()
	_put(p, c, String(q.kind))
	pending = ""
	_after_effects()
	return true


func _put(p: int, c: Vector2i, kind: String) -> void:
	tiles[c] = {kind = kind, owner = p if kind != "ocean" else -1, by = p}
	var pl: Dictionary = players[p]
	var b := RsD.cell_bonus(c)
	for r in b:
		if str(r) == "card":
			pl.hand += _draw_n(int(b[r]))
		else:
			pl.res[int(r)] += int(b[r])
	for n in RsD.neighbors(c):
		if tiles.has(n) and tiles[n].kind == "ocean" and n != c:
			pl.res[0] += 2
	match kind:
		"green":
			_raise(p, 1, 1)
		"city":
			if pl.corp.get("ab", "") == "city_prod":
				pl.prod[0] += 1
	last = {kind = "place", p = p, cell = c, tile = kind}

# ==================== 행동 ====================


func can_act(p: int) -> bool:
	return not over and pending == "" and cur == p and not bool(players[p].passed)


func _raise(p: int, which: int, n: int) -> void:
	for k in n:
		if int(params[which]) >= int(RsD.PARAM_MAX[which]):
			return
		if which == 2:
			# 바다는 타일을 놓아야 오른다 — 자리가 없으면 안 오름
			if legal_cells(p, "ocean").is_empty():
				return
			place_q.append({p = p, kind = "ocean"})
		params[which] += 1
		players[p].tr += 1


func _apply(p: int, e: Dictionary) -> void:
	var pl: Dictionary = players[p]
	if e.has("prod"):
		for r in e.prod:
			pl.prod[int(r)] += int(e.prod[r])
	if e.has("gain"):
		for r in e.gain:
			pl.res[int(r)] += int(e.gain[r])
	if e.has("temp"):
		_raise(p, 0, int(e.temp))
	if e.has("oxy"):
		_raise(p, 1, int(e.oxy))
	if e.has("ocean"):
		_raise(p, 2, int(e.ocean))
	if e.has("tr"):
		pl.tr += int(e.tr)
	if e.has("tile"):
		place_q.append({p = p, kind = String(e.tile)})
	if e.has("draw"):
		pl.hand += _draw_n(int(e.draw))
	if e.has("opp"):
		var o: Dictionary = players[opp(p)]
		for r in e.opp:
			o.res[int(r)] = maxi(0, int(o.res[int(r)]) - int(e.opp[r]))


## 손패 k 번째 카드 내기. 금속 · 합금은 쓸 수 있는 만큼 먼저 쓴다.
func play_card(k: int) -> bool:
	var p := cur
	if not can_act(p) or k < 0 or k >= players[p].hand.size():
		return false
	var c: Dictionary = players[p].hand[k]
	if not can_play(p, c):
		return false
	var pl: Dictionary = players[p]
	var cost := card_cost(p, c)
	if 1 in c.tags:
		var use := mini(int(pl.res[2]), cost / RsD.ALLOY_VAL)
		if use * RsD.ALLOY_VAL < cost and int(pl.res[0]) < cost - use * RsD.ALLOY_VAL and use < int(pl.res[2]):
			use += 1
		pl.res[2] -= use
		cost = maxi(0, cost - use * RsD.ALLOY_VAL)
	if 0 in c.tags:
		var mv := metal_val(p)
		var use2 := mini(int(pl.res[1]), cost / mv)
		if use2 * mv < cost and int(pl.res[0]) < cost - use2 * mv and use2 < int(pl.res[1]):
			use2 += 1
		pl.res[1] -= use2
		cost = maxi(0, cost - use2 * mv)
	pl.res[0] -= cost
	pl.hand.remove_at(k)
	pl.played.append(c)
	_apply(p, c.eff)
	# 태그가 부르는 효과(이 카드까지 포함)
	for pc: Dictionary in pl.played:
		if pc.eff.has("on_tag"):
			var ot: Array = pc.eff.on_tag
			for x in c.tags:
				if int(x) == int(ot[0]):
					pl.res[int(ot[1])] += int(ot[2])
	var ab := String(pl.corp.get("ab", ""))
	for x in c.tags:
		if ab == "space2" and int(x) == 1:
			pl.res[0] += 2
		if ab == "sci_draw" and int(x) == 2:
			pl.hand += _draw_n(1)
	last = {kind = "card", p = p, card = c}
	events.append({p = p, txt = c.name})
	_after_effects()
	return true


## 기본 사업 k(0 카드 팔기 — sell = 팔 손패 번호).
func std_cost(k: int) -> int:
	return int(RsD.STD[k][1])


func can_std(p: int, k: int) -> bool:
	if not can_act(p):
		return false
	var e: Dictionary = RsD.STD[k][2]
	if k == 0:
		return not players[p].hand.is_empty()
	if int(players[p].res[0]) < std_cost(k):
		return false
	if e.has("temp") and int(params[0]) >= int(RsD.PARAM_MAX[0]):
		return false
	if e.has("oxy") and int(params[1]) >= int(RsD.PARAM_MAX[1]):
		return false
	if e.has("ocean") and (int(params[2]) >= int(RsD.PARAM_MAX[2]) or legal_cells(p, "ocean").is_empty()):
		return false
	if e.has("tile") and legal_cells(p, String(e.tile)).is_empty():
		return false
	return true


func standard(k: int, sell: int = -1) -> bool:
	var p := cur
	if not can_std(p, k):
		return false
	var pl: Dictionary = players[p]
	if k == 0:
		if sell < 0 or sell >= pl.hand.size():
			return false
		discard.append(pl.hand[sell])
		pl.hand.remove_at(sell)
		pl.res[0] += 1
	else:
		pl.res[0] -= std_cost(k)
		_apply(p, RsD.STD[k][2])
	last = {kind = "std", p = p, k = k}
	events.append({p = p, txt = String(RsD.STD[k][0])})
	_after_effects()
	return true


func can_green(p: int) -> bool:
	return can_act(p) and int(players[p].res[3]) >= green_cost(p) and not legal_cells(p, "green").is_empty()


func convert_green() -> bool:
	var p := cur
	if not can_green(p):
		return false
	players[p].res[3] -= green_cost(p)
	place_q.append({p = p, kind = "green"})
	last = {kind = "green", p = p}
	events.append({p = p, txt = "식물로 녹지"})
	_after_effects()
	return true


func can_heat(p: int) -> bool:
	return can_act(p) and int(players[p].res[5]) >= heat_cost(p) and int(params[0]) < int(RsD.PARAM_MAX[0])


func convert_heat() -> bool:
	var p := cur
	if not can_heat(p):
		return false
	players[p].res[5] -= heat_cost(p)
	_raise(p, 0, 1)
	last = {kind = "heat", p = p}
	events.append({p = p, txt = "열로 온도"})
	_after_effects()
	return true


## 내 운영 카드의 행동(played 안 번호).
func can_card_act(p: int, j: int) -> bool:
	if not can_act(p) or j < 0 or j >= players[p].played.size():
		return false
	var c: Dictionary = players[p].played[j]
	if not c.eff.has("act") or players[p].used.has(c.id):
		return false
	var a: Dictionary = c.eff.act
	if a.has("pay"):
		for r in a.pay:
			if int(players[p].res[int(r)]) < int(a.pay[r]):
				return false
	if a.has("temp") and int(params[0]) >= int(RsD.PARAM_MAX[0]):
		return false
	if a.has("oxy") and int(params[1]) >= int(RsD.PARAM_MAX[1]):
		return false
	return true


func card_act(j: int) -> bool:
	var p := cur
	if not can_card_act(p, j):
		return false
	var pl: Dictionary = players[p]
	var c: Dictionary = pl.played[j]
	var a: Dictionary = c.eff.act
	pl.used[c.id] = true
	if a.has("pay"):
		for r in a.pay:
			pl.res[int(r)] -= int(a.pay[r])
	if a.has("get"):
		for r in a["get"]:
			pl.res[int(r)] += int(a["get"][r])
	if a.has("temp"):
		_raise(p, 0, 1)
	if a.has("oxy"):
		_raise(p, 1, 1)
	if a.has("draw"):
		pl.hand += _draw_n(int(a.draw))
	if a.has("acc"):
		pl.acc[c.id] = int(pl.acc.get(c.id, 0)) + int(a.acc)
	last = {kind = "act", p = p, card = c}
	events.append({p = p, txt = "%s 행동" % c.name})
	_after_effects()
	return true


func milestone_ok(p: int, m: int) -> bool:
	if not can_act(p) or int(milestones[m]) >= 0 or int(players[p].ms) >= 2 or int(players[p].res[0]) < RsD.MILESTONE_COST:
		return false
	var row: Array = RsD.MILESTONES[m]
	match String(row[2]):
		"tr":
			return int(players[p].tr) >= int(row[3])
		"green":
			return count_tiles(p, "green") >= int(row[3])
		"tag0":
			return count_tag(p, 0) >= int(row[3])
	return false


func claim(m: int) -> bool:
	var p := cur
	if not milestone_ok(p, m):
		return false
	players[p].res[0] -= RsD.MILESTONE_COST
	players[p].ms += 1
	milestones[m] = p
	last = {kind = "milestone", p = p, m = m}
	events.append({p = p, txt = "목표 %s 선점" % RsD.MILESTONES[m][0]})
	_after_effects()
	return true


func award_cost() -> int:
	var n := 0
	for a in awards:
		if int(a) >= 0:
			n += 1
	return int(RsD.AWARD_COST[mini(n, 1)])


func award_ok(p: int, a: int) -> bool:
	return can_act(p) and int(awards[a]) < 0 and int(players[p].aw) < 2 and int(players[p].res[0]) >= award_cost()


func fund(a: int) -> bool:
	var p := cur
	if not award_ok(p, a):
		return false
	players[p].res[0] -= award_cost()
	players[p].aw += 1
	awards[a] = p
	last = {kind = "award", p = p, a = a}
	events.append({p = p, txt = "후원 %s 개설" % RsD.AWARDS[a][0]})
	_after_effects()
	return true


func pass_turn() -> bool:
	var p := cur
	if not can_act(p):
		return false
	players[p].passed = true
	last = {kind = "pass", p = p}
	events.append({p = p, txt = "패스"})
	_end_turn()
	return true


## 효과 뒤 — 놓을 타일이 남았으면 멈추고, 없으면 차례를 넘긴다.
func _after_effects() -> void:
	if not place_q.is_empty():
		var q: Dictionary = place_q[0]
		if legal_cells(int(q.p), String(q.kind)).is_empty():
			place_q.pop_front()
			_after_effects()
			return
		pending = "place"
		pend_p = int(q.p)
		return
	_end_turn()


func _end_turn() -> void:
	turn_no += 1
	var o := opp(cur)
	if not bool(players[o].passed):
		cur = o
	elif bool(players[cur].passed):
		_production()


func _production() -> void:
	for pl: Dictionary in players:
		pl.res[5] += int(pl.res[4])
		pl.res[4] = 0
		pl.res[0] += int(pl.tr) + int(pl.prod[0])
		for r in range(1, RsD.N_RES):
			pl.res[r] += int(pl.prod[r])
		pl.used = {}
		pl.passed = false
	if maxed() or gen >= RsD.MAX_GEN:
		_end_game()
		return
	gen += 1
	first = opp(first)
	events.append({p = first, txt = "%d세대 시작" % gen})
	for i in 2:
		offer[i] = _draw_n(RsD.RESEARCH_N)
	pending = "research"
	pend_p = first

# ==================== 점수 ====================


func count_tiles(p: int, kind: String = "") -> int:
	var n := 0
	for c in tiles:
		var t: Dictionary = tiles[c]
		if int(t.owner) == p and (kind == "" or t.kind == kind):
			n += 1
	return n


func _award_metric(p: int, kind: String) -> int:
	match kind:
		"tiles":
			return count_tiles(p)
		"tag2":
			return count_tag(p, 2)
		"heat":
			return int(players[p].res[5])
	return 0


func score_parts(p: int) -> Dictionary:
	var pl: Dictionary = players[p]
	var d := {tr = int(pl.tr), green = count_tiles(p, "green"), city = 0, cards = 0, milestone = 0, award = 0}
	for c in tiles:
		var t: Dictionary = tiles[c]
		if t.kind == "city" and int(t.owner) == p:
			for n in RsD.neighbors(c):
				if tiles.has(n) and tiles[n].kind == "green":
					d.city += 1
	for c: Dictionary in pl.played:
		d.cards += int(c.pts)
		if c.eff.has("acc_pts"):
			d.cards += int(pl.acc.get(c.id, 0)) / int(c.eff.acc_pts)
	for m in 3:
		if int(milestones[m]) == p:
			d.milestone += 5
	for a in 3:
		if int(awards[a]) >= 0:
			var kind: String = RsD.AWARDS[a][2]
			var mine := _award_metric(p, kind)
			var theirs := _award_metric(opp(p), kind)
			d.award += 5 if mine >= theirs else 2
	var tot := 0
	for k in d:
		tot += int(d[k])
	d.total = tot
	return d


func points(p: int) -> int:
	return int(score_parts(p).total)


func _end_game() -> void:
	over = true
	pending = ""
	var a := points(0)
	var b := points(1)
	if a != b:
		winner = 0 if a > b else 1
	else:
		winner = -1 if int(players[0].res[0]) == int(players[1].res[0]) else (0 if int(players[0].res[0]) > int(players[1].res[0]) else 1)
