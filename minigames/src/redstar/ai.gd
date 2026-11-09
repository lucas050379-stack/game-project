class_name RsAi
extends RefCounted

## 붉은 별 개척단 상대 — 규칙은 [RsGame] 의 함수로만 바꿉니다(그리기 · 소리를 부르지 마세요 — 검산이 이 파일을 씁니다).
## 가치 단위는 크레딧. 남은 세대 수(`gens_left`)가 많을수록 생산이, 적을수록 점수가 비싸다.
## 레벨: 0 쉬움(무작위 섞음) · 1 보통 · 2 어려움(상대 목표 · 후원을 먼저 막고, 끝물에 생산을 덜 삼).

const PROD_K := [1.0, 1.6, 2.2, 1.6, 1.0, 0.8]   ## 생산 1이 세대마다 주는 크레딧 값
const RES_K := [1.0, 1.8, 2.6, 2.2, 0.8, 0.8]    ## 지금 가진 자원 1의 값
const PT_V := 4.0                                ## 점수 1


## 크레딧 1의 값 — 남은 돈은 점수가 안 되므로 많이 쌓일수록, 끝이 가까울수록 싸진다(안 그러면 봇이 190 까지 쌓아 두고 패스했다).
static func money_k(g: RsGame, p: int) -> float:
	var m := float(g.players[p].res[0])
	var k := 1.0 if m < 25.0 else maxf(0.35, 25.0 / m)
	return k * (0.7 if gens_left(g) <= 1 else 1.0)


static func gens_left(g: RsGame) -> int:
	return clampi(ceili(g.steps_left() / 2.6), 1, RsD.MAX_GEN - g.gen + 1)


static func act(g: RsGame, level: int = 1) -> void:
	if g.over:
		return
	if g.pending != "":
		resolve(g, level)
		return
	var p := g.cur
	var best := {}
	var bv := 0.0   # 0 보다 좋은 것이 없으면 패스
	for o: Dictionary in options(g, p, level):
		var v := float(o.v) + (g.rng.randf_range(-3.0, 3.0) if level == 0 else 0.0)
		if v > bv:
			bv = v
			best = o
	match String(best.get("kind", "pass")):
		"card":
			g.play_card(int(best.k))
		"std":
			g.standard(int(best.k), int(best.get("sell", -1)))
		"green":
			g.convert_green()
		"heat":
			g.convert_heat()
		"act":
			g.card_act(int(best.k))
		"milestone":
			g.claim(int(best.k))
		"award":
			g.fund(int(best.k))
		_:
			g.pass_turn()
	if g.pending != "" and bool(g.players[g.pend_p].ai):
		resolve(g, level)


static func options(g: RsGame, p: int, level: int) -> Array:
	var out := []
	var pl: Dictionary = g.players[p]
	for k in pl.hand.size():
		var c: Dictionary = pl.hand[k]
		if g.can_play(p, c):
			out.append({kind = "card", k = k, v = card_value(g, p, c) - g.card_cost(p, c) * 0.9 * money_k(g, p)})
	for k in range(1, RsD.STD.size()):
		if g.can_std(p, k):
			out.append({kind = "std", k = k, v = eff_value(g, p, RsD.STD[k][2]) - g.std_cost(k) * money_k(g, p)})
	if g.can_green(p):
		out.append({kind = "green", v = eff_value(g, p, {tile = "green"}) + 1.0})
	if g.can_heat(p):
		out.append({kind = "heat", v = eff_value(g, p, {temp = 1}) + 1.0})
	for j in pl.played.size():
		if g.can_card_act(p, j):
			out.append({kind = "act", k = j, v = act_value(g, p, pl.played[j]) + 0.5})
	for m in 3:
		if g.milestone_ok(p, m):
			out.append({kind = "milestone", k = m, v = 5.0 * PT_V - RsD.MILESTONE_COST})
	for a in 3:
		if g.award_ok(p, a):
			var kind: String = RsD.AWARDS[a][2]
			var lead := g._award_metric(p, kind) - g._award_metric(g.opp(p), kind)
			var gl := gens_left(g)
			if lead > 0 and gl <= (4 if level >= 2 else 3):
				out.append({kind = "award", k = a, v = 3.0 * PT_V - g.award_cost()})
	# 손이 가득 차고 돈이 없으면 쓸모없는 카드 팔기
	if pl.hand.size() > 6 and int(pl.res[0]) < 5:
		var worst := 0
		var wv := INF
		for k2 in pl.hand.size():
			var v2 := card_value(g, p, pl.hand[k2]) - g.card_cost(p, pl.hand[k2])
			if v2 < wv:
				wv = v2
				worst = k2
		out.append({kind = "std", k = 0, sell = worst, v = 0.5})
	return out


static func eff_value(g: RsGame, p: int, e: Dictionary) -> float:
	var gl := gens_left(g)
	var v := 0.0
	if e.has("prod"):
		for r in e.prod:
			v += PROD_K[int(r)] * int(e.prod[r]) * maxf(0.0, gl - 0.5)
	if e.has("gain"):
		for r in e.gain:
			v += RES_K[int(r)] * int(e.gain[r])
	var step := gl + PT_V   # 지표 1단계 = 개척 등급 1(남은 세대 수입 + 점수)
	if e.has("temp"):
		v += step * mini(int(e.temp), int(RsD.PARAM_MAX[0]) - int(g.params[0]))
	if e.has("oxy"):
		v += step * mini(int(e.oxy), int(RsD.PARAM_MAX[1]) - int(g.params[1]))
	if e.has("ocean"):
		v += (step + 2.0) * mini(int(e.ocean), int(RsD.PARAM_MAX[2]) - int(g.params[2]))
	if e.has("tr"):
		v += step * int(e.tr)
	if e.has("tile"):
		if e.tile == "green":
			v += PT_V + 2.0 + (step if int(g.params[1]) < int(RsD.PARAM_MAX[1]) else 0.0)
		else:
			v += 3.0 + 1.5 * minf(gl, 4.0)
	if e.has("draw"):
		v += 3.0 * int(e.draw)
	if e.has("opp"):
		for r in e.opp:
			v += RES_K[int(r)] * 0.5 * mini(int(e.opp[r]), int(g.players[g.opp(p)].res[int(r)]))
	if e.has("disc"):
		for k in e.disc:
			v += float(e.disc[k]) * (gl * (1.2 if str(k) == "all" else 0.6))
	if e.has("on_tag"):
		v += float(e.on_tag[2]) * RES_K[int(e.on_tag[1])] * gl * 0.5
	if e.has("act"):
		v += _act_eff(g, p, e.act, e.get("acc_pts", 0)) * gl * 0.7
	return v


static func card_value(g: RsGame, p: int, c: Dictionary) -> float:
	var v := eff_value(g, p, c.eff) + int(c.pts) * PT_V
	if c.eff.has("acc_pts"):
		v += 0.0
	return v


## 운영 카드 행동 한 번의 값.
static func _act_eff(g: RsGame, p: int, a: Dictionary, acc_pts: int) -> float:
	var v := 0.0
	if a.has("pay"):
		for r in a.pay:
			v -= RES_K[int(r)] * int(a.pay[r])
	if a.has("get"):
		for r in a["get"]:
			v += RES_K[int(r)] * int(a["get"][r])
	var step := gens_left(g) + PT_V
	if a.has("temp") and int(g.params[0]) < int(RsD.PARAM_MAX[0]):
		v += step
	if a.has("oxy") and int(g.params[1]) < int(RsD.PARAM_MAX[1]):
		v += step
	if a.has("draw"):
		v += 3.0 * int(a.draw)
	if a.has("acc") and acc_pts > 0:
		v += PT_V / acc_pts
	return v


static func act_value(g: RsGame, p: int, c: Dictionary) -> float:
	return _act_eff(g, p, c.eff.act, int(c.eff.get("acc_pts", 0)))

# ==================== pending ====================


static func resolve(g: RsGame, level: int = 1) -> void:
	var p := g.pend_p
	match g.pending:
		"corp":
			var k := g.rng.randi_range(0, 1) if level == 0 else _best_corp(g, p)
			var start := int(RsD.CORPS[g.corp_offer[p][k]][1])
			g.choose_corp(k, _pick_buy(g, p, start - 12))
		"research":
			g.buy_research(_pick_buy(g, p, int(g.players[p].res[0]) - 6))
		"place":
			var q: Dictionary = g.place_q[0]
			g.place(g.best_cell(p, String(q.kind)))


static func _best_corp(g: RsGame, p: int) -> int:
	var a: int = g.corp_offer[p][0]
	var b: int = g.corp_offer[p][1]
	return 0 if int(RsD.CORPS[a][1]) >= int(RsD.CORPS[b][1]) - 2 else 1


## 살 카드 — 값이 비용 + 구매비보다 넉넉한 것부터, 돈 budget 안에서.
static func _pick_buy(g: RsGame, p: int, budget: int) -> Array:
	var cand := []
	for k in g.offer[p].size():
		var c: Dictionary = g.offer[p][k]
		var v := card_value(g, p, c) - (int(c.cost) + RsD.CARD_BUY) * money_k(g, p)
		if v > 0.0:
			cand.append([v, k])
	cand.sort_custom(func(x, y): return x[0] > y[0])
	var out := []
	for e in cand:
		if (out.size() + 1) * RsD.CARD_BUY <= maxi(0, budget):
			out.append(int(e[1]))
	return out
