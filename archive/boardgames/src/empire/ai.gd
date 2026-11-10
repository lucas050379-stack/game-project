class_name EmAi
extends RefCounted

## 제국 연대기 상대 — 규칙은 [EmGame] 의 함수로만 바꿉니다(그리기 · 소리를 부르지 마세요 — 검산이 이 파일을 씁니다).
##
## 가치는 기획서의 가치 환산표(돈 1 단위)를 따릅니다. 레벨: 0 쉬움(아무거나 · 가끔 실수) · 1 보통(가치 − 비용이 가장 큰 것,
## 상대 즉시 승리는 막음) · 2 어려움(보통 + 내가 가져가면 상대에게 열리는 카드의 값을 뺌).

const PROD_V := [4.0, 3.0, 1.0]    ## 자원 1개 영구 생산의 값(시대별)
const MIL_V := [3.5, 4.0, 5.5]     ## 군사 1칸
const SCI_V := [4.0, 4.5, 5.0]     ## 새 과학 심볼 하나
const PTS_V := 1.5                 ## 점수 1
const AGAIN_V := [5.0, 5.0, 4.0]
const WIN_V := 1000.0


## 차례 하나 — pending 이 있으면 그것부터 푼다.
static func act(g: EmGame, level: int = 1) -> void:
	if g.over:
		return
	if g.pending != "":
		resolve(g, level)
		return
	var best := {}
	var best_v := -INF
	for i in g.available():
		for o: Dictionary in options(g, i, level):
			var v := float(o.v)
			if level == 0:
				v += g.rng.randf_range(0.0, 6.0)
			if v > best_v:
				best_v = v
				best = o
	if best.is_empty():
		return
	g.act(int(best.slot), String(best.action), int(best.get("wk", -1)))
	if g.pending != "" and bool(g.players[g.pend_p].ai):
		resolve(g, level)


## 한 칸으로 할 수 있는 것들과 그 값.
static func options(g: EmGame, i: int, level: int) -> Array:
	var p := g.cur
	var c: Dictionary = g.slots[i].card
	var out := []
	var deny := 0.0
	if level >= 1:
		deny = _deny(g, c)
	var reveal := 0.0
	if level >= 2:
		reveal = _reveal_cost(g, i)
	out.append({slot = i, action = "discard", v = float(g.discard_gain(p)) * 0.9 + deny - reveal})
	if g.can_build(p, c):
		out.append({slot = i, action = "build", v = card_value(g, p, c) - g.card_cost(p, c) + deny - reveal})
	for wk in g.wonder_options(p):
		var w: Dictionary = g.players[p].wonders[wk].w
		out.append({slot = i, action = "wonder", wk = wk, v = wonder_value(g, p, w) - g.wonder_cost(p, w) + deny * 1.0 - reveal + 1.0})
	return out


## 상대가 이 카드를 가져가면 생길 일 — 즉시 승리면 크게, 아니면 상대 가치의 일부.
static func _deny(g: EmGame, c: Dictionary) -> float:
	var o := g.opp(g.cur)
	if not g.can_build(o, c):
		return 0.0
	var v := card_value(g, o, c)
	if v >= WIN_V * 0.5:
		return WIN_V * 0.8
	return maxf(0.0, v - g.card_cost(o, c)) * 0.25


## 가져가면 열리는 카드 중 상대에게 가장 좋은 것의 값(앞면만 — 뒷면은 평균값).
static func _reveal_cost(g: EmGame, i: int) -> float:
	var o := g.opp(g.cur)
	var worst := 0.0
	for j in g.would_open(i):
		var s: Dictionary = g.slots[j]
		var v := 2.0
		if s.face and g.can_build(o, s.card):
			v = card_value(g, o, s.card) - g.card_cost(o, s.card)
		worst = maxf(worst, v)
	return worst * 0.5


static func card_value(g: EmGame, p: int, c: Dictionary) -> float:
	var a := g.age
	var e: Dictionary = c.eff
	var v := 0.0
	if e.has("prod"):
		var need := _demand(g, p)
		for r in EmD.N_RES:
			var n := int(e.prod[r])
			if n > 0:
				var have := int(g.production(p)[r])
				v += PROD_V[a] * n * (1.2 if r in EmD.MAN else 1.0) * (0.4 if have >= need[r] else 1.0)
	if e.has("pick"):
		v += PROD_V[a] * 0.8
	v += float(e.get("pts", 0)) * PTS_V
	if int(c.kind) == EmD.K.BLUE:
		v += float(g._has_eff(p, "blue_pts")) * PTS_V
	if e.has("mil"):
		var n2 := int(e.mil)
		var d := g.mil_for(p)
		if d + n2 >= EmD.MIL_WIN:
			return WIN_V
		var k: float = MIL_V[a]
		if d <= -5:
			k *= 2.0   # 밀리고 있으면 막는 값이 크다
		elif d >= 5:
			k *= 1.5   # 수도가 가까우면 밀어붙인다
		v += k * n2
	if e.has("sci"):
		var s := int(e.sci)
		var have2 := int(g.players[p].sci[s])
		if have2 == 0:
			if g.sci_kinds(p) + 1 >= EmD.SCI_WIN:
				return WIN_V
			v += SCI_V[a] + (2.0 if g.sci_kinds(p) >= 4 else 0.0)
		elif have2 == 1:
			v += 1.0 + (4.0 if not g.tokens_open.is_empty() else 0.0)
		else:
			v += 0.5
	v += float(e.get("coin", 0))
	if e.has("per_brown"):
		v += g.count_kind(p, EmD.K.BROWN) * int(e.per_brown)
	if e.has("opp_yellow"):
		v += g.count_kind(g.opp(p), EmD.K.YELLOW) * int(e.opp_yellow)
	if e.has("fix"):
		v += 2.5 * (2 - a)
	if e.has("disc"):
		v += 1.0
	if e.has("coin_age3"):
		v += float(e.coin_age3) if a < 2 else 0.0
	if e.has("buy_minus"):
		v += 1.5 * (3 - a)
	if e.has("per_red_pts"):
		v += g.count_kind(p, EmD.K.RED) * PTS_V
	if e.has("guild"):
		v += _guild_guess(g, p, String(e.guild)) * PTS_V
	if int(c.kind) <= EmD.K.GREY:
		v += 0.0
	if _is_chain_start(c) and a < 2:
		v += 1.5
	return v


## 앞으로 짓고 싶은 카드 비용을 대충 — 지금 시대 남은 앞면 카드의 자원 합(최대).
static func _demand(g: EmGame, p: int) -> Array:
	var need := [1, 1, 1, 1, 1]
	for w: Dictionary in g.players[p].wonders:
		if not w.built:
			for r in EmD.N_RES:
				need[r] = maxi(need[r], int(w.w.cost[r]))
	return need


static func _is_chain_start(c: Dictionary) -> bool:
	for row in EmD.AGE2 + EmD.AGE3:
		if String(row[5]) == String(c.name):
			return true
	return false


static func _guild_guess(g: EmGame, p: int, kind: String) -> float:
	return float(g._guild_pts(p, kind)) + 1.0


static func wonder_value(g: EmGame, p: int, w: Dictionary) -> float:
	var a := g.age
	var e: Dictionary = w.eff
	var v := float(e.get("pts", 0)) * PTS_V + float(e.get("coin", 0)) + float(e.get("opp_coin", 0)) * 0.8
	v += float(g._has_eff(p, "wonder_coin"))
	if e.has("mil"):
		if g.mil_for(p) + int(e.mil) >= EmD.MIL_WIN:
			return WIN_V
		v += MIL_V[a] * int(e.mil)
	if e.has("sci"):
		var s := int(e.sci)
		if int(g.players[p].sci[s]) == 0:
			if g.sci_kinds(p) + 1 >= EmD.SCI_WIN:
				return WIN_V
			v += SCI_V[a]
	if e.get("again", false):
		v += AGAIN_V[a]
	if e.has("raw_minus"):
		v += 2.0 * (3 - a)
	if e.has("blue_waive"):
		v += 2.0 * (3 - a)
	if e.has("pick"):
		v += PROD_V[a]
	if e.get("token", false) and not g.tokens_open.is_empty():
		v += 6.0
	if e.get("library", false) and not g.library_options().is_empty():
		v += 6.0
	return v

# ==================== pending ====================


static func resolve(g: EmGame, level: int = 1) -> void:
	match g.pending:
		"draft":
			var bi := 0
			var bv := -INF
			for k in g.draft_pool.size():
				var v := draft_value(g.draft_pool[k]) + (g.rng.randf_range(0, 4) if level == 0 else 0.0)
				if v > bv:
					bv = v
					bi = k
			g.draft_pick(bi)
		"token":
			var bi2 := 0
			var bv2 := -INF
			for k in g.tokens_open.size():
				var v2 := token_value(g, g.pend_p, g.tokens_open[k])
				if v2 > bv2:
					bv2 = v2
					bi2 = k
			g.pick_token(bi2)
		"starter":
			g.pick_starter(g.pend_p)   # 고르는 쪽은 밀리는 쪽 — 먼저 두어 따라잡는다
		"library":
			var opts := g.library_options()
			var bi3: int = opts[0]
			var bv3 := -INF
			for k in opts:
				var v3 := card_value(g, g.pend_p, g.discard[k])
				if v3 > bv3:
					bv3 = v3
					bi3 = k
			g.pick_library(bi3)


static func draft_value(w: Dictionary) -> float:
	var e: Dictionary = w.eff
	var v := float(e.get("pts", 0)) * PTS_V + float(e.get("coin", 0)) + float(e.get("opp_coin", 0)) * 0.8
	v += float(e.get("mil", 0)) * 3.5
	if e.get("again", false):
		v += 5.0
	if e.has("sci"):
		v += 4.5
	if e.get("token", false) or e.get("library", false):
		v += 5.0
	if e.has("raw_minus") or e.has("blue_waive") or e.has("pick"):
		v += 4.0
	var cost := 0
	for r in w.cost:
		cost += int(r)
	return v - cost * 0.5


static func token_value(g: EmGame, p: int, tk: Dictionary) -> float:
	var e: Dictionary = tk.eff
	var a := g.age
	if e.has("sci"):
		if g.sci_kinds(p) + 1 >= EmD.SCI_WIN:
			return WIN_V
		return SCI_V[a] + 1.0
	var v := float(e.get("coin", 0)) + float(e.get("pts", 0)) * PTS_V
	v += float(e.get("coin_age", 0)) * (2 - a)
	v += float(e.get("disc", 0)) * 1.5
	if e.has("wonder_waive"):
		v += 3.0
	if e.has("no_mil_loss"):
		v += 1.0 if g.mil_for(p) < 0 else 0.0
	if e.has("pair_pts"):
		var pairs := 0
		for s in g.players[p].sci:
			pairs += int(s) / 2
		v += (pairs + 1) * 2.0 * PTS_V
	if e.has("blue_pts"):
		v += (3 - a) * 2.0
	if e.has("wonder_coin"):
		var left := 0
		for w: Dictionary in g.players[p].wonders:
			if not w.built and not w.get("dead", false):
				left += 1
		v += left * 3.0 * 0.7
	if e.has("prod"):
		v += PROD_V[a]
	if e.has("raw_minus"):
		v += 2.0 * (3 - a)
	return v
