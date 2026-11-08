class_name AcAi
extends RefCounted

## 아르카나 컬렉션 AI — 화면 속 상대이자 `tools/arcana_check.gd` 의 검산 봇(같은 코드).
##
## 한 차례에 하는 일: (1) 지금 살 수 있는 것 중 가치가 목표에 견줄 만하면 산다 → (2) 아니면 "가치 ÷ 걸릴 차례" 가
## 가장 큰 성물을 목표로 잡고 모자란 자원을 가져온다 → (3) 목표가 비싸고 거의 다 모았으면 봉인해 지키고 별가루를 받는다.
## 가치 = 점수 + 영웅 조건에 보탬 + 앞으로 할인(판 초반일수록 큼). `noise` 로 사람처럼 흔들린다(0 이면 늘 같은 수).
## **AI 는 규칙을 [AcGame] 의 함수로만 바꿉니다** — 직접 토큰을 옮기면 검산과 실제 판이 갈라집니다.

const BUY_K := 0.85     ## 살 수 있는 것의 가치가 목표 몫의 이만큼 넘으면 지금 산다


static func act(g: AcGame, noise: float = 0.15) -> void:
	if g.over:
		return
	match g.pending:
		"discard":
			while g.pending == "discard":
				g.discard(_least_needed(g))
			if g.pending == "hero":
				g.pick_hero(_best_hero(g))
			return
		"hero":
			g.pick_hero(_best_hero(g))
			return
	var p := g.cur
	# 후보: 펼친 것 + 봉인한 것
	var cands := []
	for t in 3:
		for k in g.rows[t].size():
			if g.rows[t][k] != null:
				cands.append({src = "row", tier = t, idx = k, card = g.rows[t][k]})
	for k in g.players[p].reserved.size():
		cands.append({src = "res", tier = -1, idx = k, card = g.players[p].reserved[k]})
	var best_buy := {}
	var best_buy_v := -1e9
	var best_tgt := {}
	var best_tgt_v := -1e9
	for c: Dictionary in cands:
		var v := value(g, p, c.card) + g.rng.randf() * noise * 3.0
		if g.can_buy(p, c.card):
			if v > best_buy_v:
				best_buy_v = v
				best_buy = c
		# 보너스를 빼고도 손 한도(10)보다 비싸면 아직 목표로 못 삼는다 — 그걸 노리다 같은 토큰만 주고받으며 맴돌았다
		if net_cost(g, p, c.card) > AcD.HAND_MAX:
			continue
		var pri := v / float(turns_to(g, p, c.card) + 1)
		if pri > best_tgt_v:
			best_tgt_v = pri
			best_tgt = c
	# 목표 자체를 지금 살 수 있으면 사고, 아니면 살 수 있는 것이 목표의 "한 차례 몫" 보다 충분히 클 때만
	if not best_tgt.is_empty() and g.can_buy(p, best_tgt.card):
		g.buy(best_tgt.src, best_tgt.tier, best_tgt.idx)
		return
	# 토큰이 거의 찼으면 살 수 있는 것을 산다(가져와 봤자 버리게 된다)
	if not best_buy.is_empty() and (best_buy_v >= best_tgt_v * BUY_K * 2.0 or g.tokens(p) >= AcD.HAND_MAX - 2):
		g.buy(best_buy.src, best_buy.tier, best_buy.idx)
		return
	if not best_tgt.is_empty():
		var card: Dictionary = best_tgt.card
		var sh := g.short(p, card)
		var miss := 0
		for v in sh:
			miss += int(v)
		# 비싼 목표를 거의 다 모았거나, 토큰이 꽉 찼으면 봉인(지키기 + 별가루)
		var full := g.tokens(p) >= AcD.HAND_MAX - 1
		if best_tgt.src == "row" and int(card.tier) >= 1 and g.can_reserve(best_tgt.tier, best_tgt.idx) \
				and miss <= 3 and (full or (int(card.pts) >= 3 and int(g.players[p].tok[AcD.GOLD]) < miss)):
			g.reserve(best_tgt.tier, best_tgt.idx)
			return
		if _take_for(g, sh, card):
			return
	if not best_buy.is_empty():
		g.buy(best_buy.src, best_buy.tier, best_buy.idx)
		return
	if _take_any(g):
		return
	# 토큰이 없다 — 봉인이라도
	for t in [2, 1, 0]:
		for k in g.rows[t].size():
			if g.can_reserve(t, k):
				g.reserve(t, k)
				return
		if g.can_reserve(t, -1):
			g.reserve(t, -1)
			return
	g.pass_turn()


## 성물 하나의 가치 — 점수가 기본, 보너스 색이 영웅 조건이나 다른 펼친 성물 비용에 보태면 더한다.
static func value(g: AcGame, p: int, card: Dictionary) -> float:
	var v := float(card.pts) * 1.6
	var b := g.bonus(p)
	var col: int = card.col
	for h: Dictionary in g.heroes:
		if h.need.has(col) and int(b[col]) < int(h.need[col]):
			v += 0.45
	# 판 초반 — 할인 자체의 값(성물이 적을수록 큼)
	var have: int = g.players[p].cards.size()
	v += maxf(0.0, 1.2 - have * 0.08)
	# 펼친 성물 중 이 색을 요구하는 것이 많을수록
	var demand := 0
	for t in 3:
		for c in g.rows[t]:
			if c != null and int(c.cost[col]) > int(b[col]):
				demand += 1
	v += demand * 0.05
	return v


## 보너스를 뺀 실제 비용(토큰으로 낼 몫).
static func net_cost(g: AcGame, p: int, card: Dictionary) -> int:
	var b := g.bonus(p)
	var s := 0
	for c in AcD.N_COL:
		s += maxi(0, int(card.cost[c]) - int(b[c]))
	return s


## 대략 몇 차례면 살 수 있나 — 모자란 자원(별가루로 메우고 남는 것) ÷ 3.
static func turns_to(g: AcGame, p: int, card: Dictionary) -> int:
	var sh := g.short(p, card)
	var miss := 0
	for v in sh:
		miss += int(v)
	miss = maxi(0, miss - int(g.players[p].tok[AcD.GOLD]))
	return int(ceil(miss / 3.0))


## 목표에 모자란 자원을 가져온다. 한 자원만 둘 이상 모자라면 같은 것 둘.
static func _take_for(g: AcGame, sh: Array, card: Dictionary) -> bool:
	var need := []
	for c in AcD.N_COL:
		if int(sh[c]) > 0 and int(g.bank[c]) > 0:
			need.append(c)
	need.sort_custom(func(a, b): return int(sh[a]) > int(sh[b]))
	if need.size() == 1 and int(sh[need[0]]) >= 2 and g.can_take([need[0], need[0]]):
		return g.take([need[0], need[0]])
	if need.is_empty():
		return false
	var pick := need.slice(0, 3)
	# 셋을 채운다 — 다음에 쓸 만한 자원부터
	var rest := []
	for c in AcD.N_COL:
		if not (c in pick) and int(g.bank[c]) > 0:
			rest.append(c)
	var b := g.bonus(g.cur)
	rest.sort_custom(func(a, c2): return _demand(g, a, b) > _demand(g, c2, b))
	while pick.size() < 3 and not rest.is_empty():
		pick.append(rest.pop_front())
	if g.can_take(pick):
		return g.take(pick)
	return false


static func _take_any(g: AcGame) -> bool:
	var pick := []
	var b := g.bonus(g.cur)
	var cols := range(AcD.N_COL)
	cols.sort_custom(func(a, c2): return _demand(g, a, b) > _demand(g, c2, b))
	for c in cols:
		if int(g.bank[c]) > 0 and pick.size() < 3:
			pick.append(c)
	if not pick.is_empty() and g.can_take(pick):
		return g.take(pick)
	return false


## 이 자원을 요구하는 펼친 성물 몫(가진 보너스로 이미 되는 것은 빼고).
static func _demand(g: AcGame, col: int, b: Array) -> float:
	var d := 0.0
	for t in 3:
		for c in g.rows[t]:
			if c != null:
				d += maxf(0.0, float(c.cost[col]) - float(b[col])) * (1.0 + float(c.pts) * 0.3)
	return d


## 버릴 때 — 가장 덜 필요한 자원(별가루는 마지막까지 남긴다).
static func _least_needed(g: AcGame) -> int:
	var tok: Array = g.players[g.cur].tok
	var b := g.bonus(g.cur)
	var best := -1
	var best_d := 1e9
	for c in AcD.N_COL:
		if int(tok[c]) > 0:
			var d := _demand(g, c, b) / float(tok[c])
			if d < best_d:
				best_d = d
				best = c
	return best if best >= 0 else AcD.GOLD


static func _best_hero(g: AcGame) -> int:
	return g.pend_heroes[0] if not g.pend_heroes.is_empty() else 0
