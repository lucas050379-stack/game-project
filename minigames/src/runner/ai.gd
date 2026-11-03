class_name WrAi
extends RefCounted

## 월드 러너 — AI 판단(어림 규칙). 원본 세계마뷸 `Ai.cs` 와 같은 값이다.

const RESERVE := 35   ## 남겨 두려는 최소 현금


static func want_buy(g: WrGame, p: WrGame.Player, c: WrD.Cell) -> bool:
	if p.cash < c.price:
		return false
	var after := p.cash - c.price
	# 같은 대륙을 이미 갖고 있으면 적극적으로
	var same := 0
	var total := 0
	if c.group != "":
		for x: WrD.Cell in g.cells:
			if x.group != c.group:
				continue
			total += 1
			if x.owner == p.id:
				same += 1
	var need := RESERVE
	if same > 0:
		need = 18
	if total > 0 and same == total - 1:
		need = 0   # 독점 완성
	if c.type == WrD.T.SPOT and g.spots_owned(p.id) > 0:
		need = 10
	# 후반에는 더 공격적으로
	if g.round_n > 6:
		need = maxi(0, need - 12)
	return after >= need


## 도착한 도시에 몇 단계까지 올릴지 (max_level 이하)
static func want_build_count(g: WrGame, p: WrGame.Player, c: WrD.Cell, max_level: int) -> int:
	var levels := 0
	var cash := p.cash
	var lvl := c.level
	var mono := g.has_monopoly(p.id, c.group)
	var keep := 30 if mono else 55
	if g.round_n > 7:
		keep -= 15
	while lvl < max_level and lvl < c.build_cost.size():
		var cost: int = c.build_cost[lvl]
		if cash - cost < keep:
			break
		# 호텔은 여유 자금이 넉넉할 때만
		if lvl == 2 and cash - cost < (45 if mono else 85):
			break
		# 싼 도시에 호텔까지 올리는 건 비효율
		if lvl == 2 and c.price < 14 and not mono:
			break
		cash -= cost
		lvl += 1
		levels += 1
	return levels


## 호텔이 선 도시에 다시 왔을 때 랜드마크를 세울지
static func want_landmark(g: WrGame, p: WrGame.Player, c: WrD.Cell) -> bool:
	var cost: int = c.build_cost[WrD.HOTEL_LEVEL]
	if p.cash < cost:
		return false
	var keep := 45 if g.has_monopoly(p.id, c.group) else 75
	if g.round_n > 10:
		keep -= 25
	return p.cash - cost >= keep


static func want_takeover(g: WrGame, p: WrGame.Player, c: WrD.Cell) -> bool:
	var price := g.takeover_price(c)
	if p.cash < price or p.cash - price < 60:
		return false
	return c.price >= 18 or g.monopoly_boosted(c) or c.level >= 2


static func choose_space(g: WrGame, p: WrGame.Player) -> int:
	var best := 0
	var best_s := -INF
	for i in g.cells.size():
		if i == p.pos:
			continue   # 제자리는 못 고른다
		var c: WrD.Cell = g.cells[i]
		var s := 0.0
		match c.type:
			WrD.T.CITY, WrD.T.SPOT:
				if c.owner < 0:
					s = c.price * 1.4 if p.cash >= c.price else -5.0
				elif c.owner == p.id:
					s = c.price * 0.6 if g.can_build(c) and p.cash >= g.next_build_cost(c) else 2.0
				else:
					s = -g.toll(c) * 1.5
			WrD.T.JAIL:
				s = -500.0
			WrD.T.TAX:
				s = -p.cash * WrD.TAX_RATE
			WrD.T.FUND_PAY:
				s = -WrD.FUND_PAY
			WrD.T.FUND_GET:
				s = g.fund
			WrD.T.START:
				s = WrD.START_BONUS
			WrD.T.CHANCE:
				s = 6.0
		# 진행 방향으로 가므로 출발 칸을 지나면 급여를 받는다
		var steps := (i - p.pos + WrD.BOARD_SIZE) % WrD.BOARD_SIZE
		if i != 0 and p.pos + steps >= WrD.BOARD_SIZE:
			s += WrD.SALARY
		if s > best_s:
			best_s = s
			best = i
	return best


## 현금 마련용 매각 — 건물과 토지가 한 번에 넘어가므로 잃는 통행료를 크게 본다.
static func choose_sell(g: WrGame, p: WrGame.Player, opts: Array) -> int:
	var best := 0
	var best_s := -INF
	for i in opts.size():
		var o: Dictionary = opts[i]
		var c: WrD.Cell = o.cell
		var s: float = o.amount - o.toll_loss * 3.5
		if c.has_landmark():
			s -= 60.0   # 랜드마크는 마지막에
		if c.double_toll:
			s -= 25.0
		if g.has_monopoly(p.id, c.group):
			s -= 30.0   # 독점은 깨지 않는다
		if s > best_s:
			best_s = s
			best = i
	return best
