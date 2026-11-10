class_name AkAi
extends RefCounted

## 잿빛 요새의 용병단 — 영웅 봇(검산 · `--ak-auto` 용). 몬스터 AI 는 규칙이라 [AkGame] 안에 있다.
## 그리기 · 소리를 부르지 마세요. 사람보다 서툴다(한 수 앞만 봄) — 깨는 비율은 봇 기준으로 낮게 잡는다.


## pending 하나를 푼다(고르기 · 첫 카드 · 단계). 없으면 advance.
static func act(g: AkGame) -> void:
	match g.pending:
		"select":
			_select(g, g.pend_h)
		"first":
			_first(g)
		"step":
			_step(g)
		_:
			g.advance()


static func _select(g: AkGame, i: int) -> void:
	var h: Dictionary = g.heroes[i]
	if g.must_rest(i):
		g.long_rest(i)
		return
	var u: Dictionary = h.unit
	if int(u.hp) <= int(u.max) / 3 and g.can_long_rest(i) and h.hand.size() <= 4:
		g.long_rest(i)
		return
	var near := _enemy_dist(g, u)
	var best := [0, 1]
	var bv := -INF
	for a in h.hand.size():
		for b in h.hand.size():
			if a >= b:
				continue
			var ca: Dictionary = h.hand[a]
			var cb: Dictionary = h.hand[b]
			var v := maxf(_half(g, h, ca.top, ca.top_lost, near) + _half(g, h, cb.bot, cb.bot_lost, near),
					_half(g, h, cb.top, cb.top_lost, near) + _half(g, h, ca.bot, ca.bot_lost, near))
			v += g.rng.randf() * 0.2
			if v > bv:
				bv = v
				best = [a, b] if int(ca.init) <= int(cb.init) else [b, a]
	g.select_cards(i, best[0], best[1])


## 행동 칸 하나의 대략 값. near = 가장 가까운 적까지 거리(없으면 99).
static func _half(g: AkGame, h: Dictionary, steps: Array, lost: bool, near: int) -> float:
	var v := 0.0
	var moves := 0
	for s: Dictionary in steps:
		if s.has("m"):
			moves += int(s.m)
			v += int(s.m) * (0.6 if near > 1 else 0.15)
		elif s.has("a"):
			var reach := maxi(1, int(s.get("r", 0))) + moves
			var hit := 1.0 if near <= reach else 0.25
			v += (int(s.a) + (2 if s.has("use") and int(g.elems[int(s.use)]) > 0 else 0)) * hit * maxf(1.0, int(s.get("t", 1)) * 0.8)
			if s.get("aoe", "") != "":
				v += 1.0 * hit
			v += s.get("eff", []).size() * 0.8 * hit
		elif s.has("h"):
			var miss := 0
			for x: Dictionary in g.alive_heroes():
				miss = maxi(miss, int(x.max) - int(x.hp))
			v += minf(int(s.h), miss) * 0.9
		elif s.has("s"):
			v += int(s.s) * (0.8 if near <= 2 else 0.2)
		elif s.has("ret"):
			v += int(s.ret) * (0.7 if near <= 1 else 0.1)
		elif s.has("inf"):
			v += 0.4
		elif s.has("inv") or s.has("strg"):
			v += 0.6
	if lost:
		# 소멸 카드는 아껴 둔다 — 적이 많거나 끝물이면 쓴다
		v -= 4.0 if g.alive_mons().size() > 2 and h.hand.size() > 4 else 1.0
	return v


static func _enemy_dist(g: AkGame, u: Dictionary) -> int:
	var d := 99
	for m: Dictionary in g.alive_mons():
		d = mini(d, AkD.dist(u.pos, m.pos))
	return d


static func _first(g: AkGame) -> void:
	var h: Dictionary = g.heroes[g.pend_h]
	var near := _enemy_dist(g, h.unit)
	var a: Dictionary = h.pick[0]
	var b: Dictionary = h.pick[1]
	var v0 := _half(g, h, a.top, a.top_lost, near) + _half(g, h, b.bot, b.bot_lost, near)
	var v1 := _half(g, h, b.top, b.top_lost, near) + _half(g, h, a.bot, a.bot_lost, near)
	g.choose_top(0 if v0 >= v1 else 1)


static func _step(g: AkGame) -> void:
	var s: Dictionary = g.step_now
	var h: Dictionary = g.heroes[g.pend_h]
	var u: Dictionary = h.unit
	var best: Vector2i = g.options[0]
	var bv := INF
	if s.has("m"):
		# 다음 공격의 사거리에 맞게 가장 가까운 적에게 붙는다. 적이 안 보이면 문 쪽으로.
		var rng_a := 1
		for nx: Dictionary in g.steps:
			if nx.has("a"):
				rng_a = maxi(1, int(nx.get("r", 0)))
				break
		var goals := []
		for m: Dictionary in g.alive_mons():
			goals.append(m.pos)
		if goals.is_empty():
			rng_a = 0   # 문은 그 칸에 올라서야 열린다
			for c in g.cells:
				if g.cells[c].door:
					goals.append(c)
		for c in g.options:
			var d := 99.0
			for gpos in goals:
				var dd := AkD.dist(c, gpos)
				d = minf(d, absf(dd - rng_a) + (0.5 if rng_a > 1 and dd == 1 else 0.0))
			if g.cells.has(c) and g.cells[c].trap:
				d += 3.0
			if d < bv:
				bv = d
				best = c
	elif s.has("a"):
		for c in g.options:
			var t := g.unit_at(c)
			var v := float(t.hp) - (5.0 if int(t.hp) <= int(s.a) else 0.0)
			if v < bv:
				bv = v
				best = c
	else:
		# 회복 · 방어 · 강화 — 가장 다친 동료
		for c in g.options:
			var t2 := g.unit_at(c)
			var v2 := float(t2.hp) / float(t2.max)
			if v2 < bv:
				bv = v2
				best = c
	g.choose(best)
