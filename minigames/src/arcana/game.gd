class_name AcGame
extends RefCounted

## 아르카나 컬렉션 한 판 — 규칙 계산만(그리기 · 소리 · 저장 · 오토로드를 부르지 마세요 — `tools/arcana_check.gd` 가
## `--script` 로 이 파일만 읽어 봇끼리 수천 판을 돌립니다).
##
## 차례 하나 = 행동 하나(`take` · `reserve` · `buy`) → [토큰이 10 을 넘으면 버리기] → [영웅 방문] → 다음 사람.
## 버리기 · 영웅 고르기는 사람이 골라야 해서 `pending` 으로 멈춥니다(AI 는 `AcAi` 가 바로 답함).
## 누가 15점에 닿으면 그 라운드의 마지막 사람까지 돌고 끝납니다(`last_round`).
##
## **확장판이 들어올 자리**(지금은 본판만): 끝 판정은 [method _check_end] 하나, 산 뒤의 일은 [method _after_buy] 하나,
## 보너스 세기는 [method bonus] 하나, 펼친 줄은 `rows` 목록입니다. 모듈 켜기는 `mods`.

var rng := RandomNumberGenerator.new()
var n := 2                       ## 인원
var mods := {}                   ## 켜진 확장 모듈(지금은 비어 있음)
var bank := [0, 0, 0, 0, 0, 0]   ## 가운데 토큰(자원 다섯 + 별가루)
var decks := [[], [], []]        ## 단계별 더미(뒤가 맨 위)
var rows := [[], [], []]         ## 단계별 펼친 성물(빈 자리는 null)
var heroes := []                 ## 펼친 영웅(가져가면 빠짐)
var players := []                ## {tok[6], cards[], reserved[], heroes[], ai}
var cur := 0                     ## 지금 차례
var turn_no := 0                 ## 지금까지 끝난 차례 수
var round_no := 1
var last_round := false
var over := false
var winner := -1
var pending := ""                ## "" · "discard"(넘친 토큰 버리기) · "hero"(영웅 둘 이상 중 고르기)
var pend_n := 0                  ## 버려야 할 토큰 수
var pend_heroes := []            ## 고를 수 있는 영웅 자리
var events := []                  ## 화면에 띄울 일 [{p, txt}]
var last := {}                   ## 방금 한 행동(그림 쪽이 날아가는 토큰 · 반짝임에 씀)


func _init(players_n: int = 2, seed_v: int = -1, ai_mask: Array = []) -> void:
	n = clampi(players_n, 2, 4)
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	var per: int = AcD.BANK[n]
	bank = [per, per, per, per, per, AcD.GOLD_N]
	var all := AcD.deck()
	for c: Dictionary in all:
		decks[c.tier].append(c)
	for t in 3:
		_shuffle(decks[t])
		for k in AcD.ROW_N:
			rows[t].append(decks[t].pop_back() if not decks[t].is_empty() else null)
	var hs := range(AcD.HEROES.size())
	_shuffle(hs)
	for k in n + 1:
		heroes.append(AcD.HEROES[hs[k]])
	for i in n:
		players.append({tok = [0, 0, 0, 0, 0, 0], cards = [], reserved = [], heroes = [],
				ai = ai_mask[i] if i < ai_mask.size() else i != 0})


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

# ==================== 셈 ====================


## 성물 보너스(영구 할인) — 자원마다 몇.
func bonus(p: int) -> Array:
	var b := [0, 0, 0, 0, 0]
	for c: Dictionary in players[p].cards:
		b[c.col] += 1
	return b


func points(p: int) -> int:
	var s := 0
	for c: Dictionary in players[p].cards:
		s += int(c.pts)
	return s + players[p].heroes.size() * AcD.HERO_PTS


func tokens(p: int) -> int:
	var s := 0
	for v in players[p].tok:
		s += int(v)
	return s


## 이 성물을 살 때 실제로 낼 것 — [자원 다섯 + 별가루]. 못 사면 빈 배열.
func pay_for(p: int, card: Dictionary) -> Array:
	var b := bonus(p)
	var tok: Array = players[p].tok
	var pay := [0, 0, 0, 0, 0, 0]
	var gold_need := 0
	for c in AcD.N_COL:
		var need := maxi(0, int(card.cost[c]) - int(b[c]))
		var use := mini(need, int(tok[c]))
		pay[c] = use
		gold_need += need - use
	if gold_need > int(tok[AcD.GOLD]):
		return []
	pay[AcD.GOLD] = gold_need
	return pay


func can_buy(p: int, card) -> bool:
	return card != null and not pay_for(p, card).is_empty()


## 모자란 자원 수(별가루로 메우기 전) — AI 가 목표를 고를 때 쓴다.
func short(p: int, card: Dictionary) -> Array:
	var b := bonus(p)
	var tok: Array = players[p].tok
	var s := [0, 0, 0, 0, 0]
	for c in AcD.N_COL:
		s[c] = maxi(0, int(card.cost[c]) - int(b[c]) - int(tok[c]))
	return s


func hero_ok(p: int, h: Dictionary) -> bool:
	var b := bonus(p)
	for c in h.need:
		if int(b[c]) < int(h.need[c]):
			return false
	return true

# ==================== 행동 ====================


## 자원 가져오기 — 서로 다른 셋(남은 게 적으면 둘 · 하나도 됨), 또는 같은 것 둘(그 자원이 넷 이상 남았을 때).
func can_take(cols: Array) -> bool:
	if over or pending != "" or cols.is_empty() or cols.size() > 3:
		return false
	for c in cols:
		if int(c) < 0 or int(c) >= AcD.N_COL:
			return false
	if cols.size() == 2 and cols[0] == cols[1]:
		return int(bank[cols[0]]) >= AcD.TAKE2_MIN
	var seen := {}
	for c in cols:
		if seen.has(c) or int(bank[c]) <= 0:
			return false
		seen[c] = true
	# 셋보다 적게 가져가는 것은 더 가져갈 다른 자원이 없을 때만
	if cols.size() < 3:
		var avail := 0
		for c in AcD.N_COL:
			if int(bank[c]) > 0:
				avail += 1
		if cols.size() < mini(3, avail):
			return false
	return true


func take(cols: Array) -> bool:
	if not can_take(cols):
		return false
	var p: Dictionary = players[cur]
	for c in cols:
		bank[c] -= 1
		p.tok[c] += 1
	last = {kind = "take", p = cur, cols = cols.duplicate()}
	var names := []
	for c in cols:
		names.append(AcD.NAMES[c])
	_log("%s 가져옴" % " ".join(names))
	_end_action()
	return true


## 봉인(찜) — 펼친 성물(`idx` 0~3) 또는 더미 맨 위(`idx` = -1). 별가루가 남아 있으면 하나 받는다.
func can_reserve(tier: int, idx: int) -> bool:
	if over or pending != "" or players[cur].reserved.size() >= AcD.RESERVE_MAX:
		return false
	if idx < 0:
		return not decks[tier].is_empty()
	return rows[tier][idx] != null


func reserve(tier: int, idx: int) -> bool:
	if not can_reserve(tier, idx):
		return false
	var p: Dictionary = players[cur]
	var card: Dictionary
	if idx < 0:
		card = decks[tier].pop_back()
	else:
		card = rows[tier][idx]
		_refill(tier, idx)
	p.reserved.append(card)
	var got := false
	if int(bank[AcD.GOLD]) > 0:
		bank[AcD.GOLD] -= 1
		p.tok[AcD.GOLD] += 1
		got = true
	last = {kind = "reserve", p = cur, card = card, tier = tier, idx = idx, gold = got, blind = idx < 0}
	_log("%s 봉인%s" % ["더미의 성물을" if idx < 0 else AcD.josa(card.name, "을"), ", 별가루 하나" if got else ""])
	_end_action()
	return true


## 사기 — `src` 는 "row"(tier, idx) 또는 "res"(봉인한 것의 idx).
func can_buy_at(src: String, tier: int, idx: int) -> bool:
	if over or pending != "":
		return false
	return can_buy(cur, _card_at(src, tier, idx))


func _card_at(src: String, tier: int, idx: int):
	if src == "res":
		var res: Array = players[cur].reserved
		return res[idx] if idx >= 0 and idx < res.size() else null
	if tier < 0 or tier > 2 or idx < 0 or idx >= rows[tier].size():
		return null
	return rows[tier][idx]


func buy(src: String, tier: int, idx: int) -> bool:
	if not can_buy_at(src, tier, idx):
		return false
	var p: Dictionary = players[cur]
	var card: Dictionary = _card_at(src, tier, idx)
	var pay := pay_for(cur, card)
	for c in 6:
		p.tok[c] -= pay[c]
		bank[c] += pay[c]
	if src == "res":
		p.reserved.remove_at(idx)
	else:
		_refill(tier, idx)
	p.cards.append(card)
	last = {kind = "buy", p = cur, card = card, src = src, tier = card.tier, idx = idx, pay = pay}
	_log("%s 갖춤%s" % [AcD.josa(card.name, "을")," (%d점)" % card.pts if int(card.pts) > 0 else ""])
	_after_buy(card)
	_end_action()
	return true


func _refill(tier: int, idx: int) -> void:
	rows[tier][idx] = decks[tier].pop_back() if not decks[tier].is_empty() else null


## 산 뒤에 일어나는 일 — 확장(교역로 · 성채 · 동방)이 여기에 붙는다.
func _after_buy(_card: Dictionary) -> void:
	pass

# ==================== 차례 끝 ====================


func _end_action() -> void:
	var over_n := tokens(cur) - AcD.HAND_MAX
	if over_n > 0:
		pending = "discard"
		pend_n = over_n
		return
	_hero_step()


## 넘친 토큰 하나 돌려놓기(사람이 하나씩 고른다).
func discard(c: int) -> bool:
	if pending != "discard" or c < 0 or c > 5 or int(players[cur].tok[c]) <= 0:
		return false
	players[cur].tok[c] -= 1
	bank[c] += 1
	pend_n -= 1
	if pend_n <= 0:
		pending = ""
		_hero_step()
	return true


func _hero_step() -> void:
	pend_heroes = []
	for k in heroes.size():
		if hero_ok(cur, heroes[k]):
			pend_heroes.append(k)
	if pend_heroes.size() == 1:
		_take_hero(pend_heroes[0])
	elif pend_heroes.size() > 1:
		pending = "hero"
		return
	_next_turn()


## 영웅 둘 이상이 동시에 조건을 채웠을 때 하나 고르기(나머지는 다음 차례에 다시 본다).
func pick_hero(k: int) -> bool:
	if pending != "hero" or not (k in pend_heroes):
		return false
	pending = ""
	_take_hero(k)
	_next_turn()
	return true


func _take_hero(k: int) -> void:
	var h: Dictionary = heroes[k]
	last["hero_k"] = k              # 그림 쪽이 판의 어느 자리에서 날아가는지 안다(빠지기 전 자리 · 개수)
	last["hero_n"] = heroes.size()
	heroes.remove_at(k)
	players[cur].heroes.append(h)
	last["hero"] = h
	_log("%s 찾아옴 (%d점)" % [AcD.josa(h.name, "이"), AcD.HERO_PTS])


func _next_turn() -> void:
	pend_heroes = []
	turn_no += 1
	_check_end()
	if over:
		return
	cur = (cur + 1) % n
	if cur == 0:
		round_no += 1


## 끝 판정 — 누가 15점에 닿으면 그 라운드의 마지막 사람(n-1)까지 돌고 끝. 확장(도시)은 여기만 바꾼다.
func _check_end() -> void:
	if points(cur) >= AcD.WIN_PTS and not last_round:
		last_round = true
		_log("%d점에 닿았다! 이번 라운드가 마지막" % AcD.WIN_PTS)
	if last_round and cur == n - 1:
		over = true
		winner = rank()[0]


## 순위 — 점수 높은 순, 같으면 성물이 적은 쪽 → 영웅이 많은 쪽 → 토큰이 많은 쪽 → 뒷순서.
func rank() -> Array:
	var ids := range(n)
	ids.sort_custom(func(a, b):
		var pa := points(a)
		var pb := points(b)
		if pa != pb:
			return pa > pb
		var ca: int = players[a].cards.size()
		var cb: int = players[b].cards.size()
		if ca != cb:
			return ca < cb
		var ha: int = players[a].heroes.size()
		var hb: int = players[b].heroes.size()
		if ha != hb:
			return ha > hb
		var ta := tokens(a)
		var tb := tokens(b)
		if ta != tb:
			return ta > tb
		return a > b)
	return ids


## 아무 행동도 못 하는 경우(토큰이 바닥나고 살 것도 봉인할 것도 없음) — 차례를 넘긴다.
func can_act() -> bool:
	for c in AcD.N_COL:
		if int(bank[c]) > 0:
			return true
	for t in 3:
		for k in rows[t].size():
			if can_buy(cur, rows[t][k]) or can_reserve(t, k):
				return true
		if can_reserve(t, -1):
			return true
	for k in players[cur].reserved.size():
		if can_buy(cur, players[cur].reserved[k]):
			return true
	return false


func pass_turn() -> void:
	if over or pending != "":
		return
	last = {kind = "pass", p = cur}
	_log("할 수 있는 것이 없어 넘김")
	_hero_step()


func _log(s: String) -> void:
	events.append({p = cur, txt = s})
	if events.size() > 60:
		events.remove_at(0)
