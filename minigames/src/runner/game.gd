class_name WrGame
extends RefCounted

## 월드 러너 — 게임 상태와 순수 규칙 계산. 애니메이션 · 연출은 `main.gd` 가 맡는다.

class Player:
	var id := 0
	var name := ""
	var color := Color.WHITE
	var ai := false
	var cash := WrD.START_CASH
	var pos := 0
	var jail := 0
	var alive := true
	var escapes := 0
	var pending_space := false   ## 다음 턴에 우주여행 이동
	## 말의 생김새. 0 = 사람(베레모), 1~3 = AI 캐릭터. [method WrGame.assign_faces] 가 정한다.
	var face := 0
	# 그림 상태
	var hop_from := 0
	var hop_to := 0
	var hop_t := -1.0       ## -1 이면 이동 중 아님
	var seat := Vector2.ZERO   ## 한 칸에 같이 섰을 때 벌어진 자리(main._step_seats)
	var squash := 0.0
	var bob := 0.0
	var shown_cash := float(WrD.START_CASH)
	var alpha := 1.0
	var scale := 1.0
	var emote := 0.0
	var emote_kind := 0     ## 0 없음 1 기쁨 2 슬픔 3 놀람
	var jump_pt := Vector2.INF   ## 포물선 점프 중이면 화면 좌표(아니면 INF)

	func _init(i: int, n: String, c: Color, is_ai: bool) -> void:
		id = i
		name = n
		color = c
		ai = is_ai
		bob = randf() * TAU

	func emit(kind: int, dur: float) -> void:
		emote_kind = kind
		emote = dur


var cells: Array = []
var players: Array = []
var fund := 0
var fund_shown := 0.0
var turn := 0
var round_n := 1
var deck: Array = []
var deck_pos := 0
var logs: Array = []      ## [글, 색]
var over := false
var winner: Player = null


func _init(ps: Array) -> void:
	randomize()   # 시드를 고정하면 매 판 주사위 · 황금열쇠 · 2배 지역이 똑같이 나온다
	cells = WrD.create_board()
	players = ps
	deck = WrD.create_deck()
	deck.shuffle()
	_pick_double_toll()
	assign_faces()


## 사람은 항상 0번 얼굴, AI 는 1~3번을 차례로. **슬롯 번호로 정하지 마세요** — 시작 화면에서
## 사람/AI 를 바꾸면 내 말이 AI 얼굴이 됩니다. 시작 화면 미리보기도 같은 규칙을 씁니다.
func assign_faces() -> void:
	var k := 0
	for p: Player in players:
		if p.ai:
			p.face = 1 + k % 3
			k += 1
		else:
			p.face = 0


static func face_for(ai_flags: Array, i: int) -> int:
	if not ai_flags[i]:
		return 0
	var k := 0
	for j in i:
		if ai_flags[j]:
			k += 1
	return 1 + k % 3


func _pick_double_toll() -> void:
	var pool: Array = []
	for c: WrD.Cell in cells:
		if c.is_property():
			pool.append(c)
	for i in WrD.DOUBLE_TOLL_CELLS:
		if pool.is_empty():
			break
		var k := randi() % pool.size()
		pool[k].double_toll = true
		pool.remove_at(k)


func double_toll_cells() -> Array:
	return cells.filter(func(c): return c.double_toll)


func current() -> Player:
	return players[turn]


func add_log(text: String, c: Color = WrD.WHITE) -> void:
	logs.append([text, c])
	if logs.size() > 200:
		logs.remove_at(0)


func draw_card() -> Array:
	if deck_pos >= deck.size():
		deck.shuffle()
		deck_pos = 0
	deck_pos += 1
	return deck[deck_pos - 1]


func owned(pid: int) -> Array:
	return cells.filter(func(c): return c.owner == pid)


func count_buildings(pid: int) -> int:
	var n := 0
	for c: WrD.Cell in cells:
		if c.owner == pid:
			n += c.level
	return n


func has_monopoly(pid: int, group: String) -> bool:
	if group == "":
		return false
	for c: WrD.Cell in cells:
		if c.group == group and c.owner != pid:
			return false
	return true


func spots_owned(pid: int) -> int:
	var n := 0
	for c: WrD.Cell in cells:
		if c.type == WrD.T.SPOT and c.owner == pid:
			n += 1
	return n


## 그 칸의 지금 통행료
func toll(c: WrD.Cell) -> int:
	if c.owner < 0:
		return 0
	var t: int
	if c.type == WrD.T.SPOT:
		t = c.tolls[0] * maxi(1, spots_owned(c.owner))
	else:
		t = c.tolls[c.level]
		if has_monopoly(c.owner, c.group):
			t *= WrD.MONOPOLY_MUL
	if c.double_toll:
		t *= WrD.DOUBLE_TOLL_MUL
	return t


func monopoly_boosted(c: WrD.Cell) -> bool:
	return c.type == WrD.T.CITY and c.owner >= 0 and has_monopoly(c.owner, c.group)


## 총자산 = 현금 + 매각 가치
func net_worth(p: Player) -> int:
	var v := p.cash
	for c: WrD.Cell in cells:
		if c.owner != p.id:
			continue
		v += int(c.price * WrD.SELL_RATE)
		for i in c.level:
			v += int(c.build_cost[i] * WrD.SELL_RATE)
	return v


## 도시 총투자액(인수가 계산용)
func invested(c: WrD.Cell) -> int:
	var v := c.price
	for i in c.level:
		v += c.build_cost[i]
	return v


func takeover_price(c: WrD.Cell) -> int:
	return invested(c) * WrD.TAKEOVER_MUL


func can_build(c: WrD.Cell) -> bool:
	return c.type == WrD.T.CITY and c.level < WrD.MAX_LEVEL


## 이번 방문에 호텔까지 올릴 수 있나
func can_build_hotel_tier(c: WrD.Cell) -> bool:
	return c.type == WrD.T.CITY and c.level < WrD.HOTEL_LEVEL


## 호텔을 이미 가진 도시에 다시 왔다 → 랜드마크
func can_build_landmark(c: WrD.Cell) -> bool:
	return c.type == WrD.T.CITY and c.level == WrD.HOTEL_LEVEL


func next_build_cost(c: WrD.Cell) -> int:
	return c.build_cost[c.level] if can_build(c) else 0


func alive_players() -> int:
	var n := 0
	for p: Player in players:
		if p.alive:
			n += 1
	return n


func next_turn() -> void:
	var guard := 0
	while true:
		turn = (turn + 1) % players.size()
		if turn == 0:
			round_n += 1
		guard += 1
		if players[turn].alive or guard >= 100:
			break


## 파산 — 자산을 채권자에게(없으면 은행으로) 넘긴다.
func bankrupt(p: Player, creditor: Player) -> void:
	p.alive = false
	for c: WrD.Cell in cells:
		if c.owner != p.id:
			continue
		if creditor != null:
			c.owner = creditor.id
			c.own_wave = 1.0
		else:
			c.owner = -1
			c.level = 0
	if creditor != null and p.cash > 0:
		creditor.cash += p.cash
	p.cash = 0


## 매각 선택지 — 건물과 토지를 **한 번에** 처분한다(총투자액의 50% 회수).
## {cell, amount, toll_loss, label}
func sell_options(p: Player) -> Array:
	var out: Array = []
	for c: WrD.Cell in cells:
		if c.owner != p.id:
			continue
		out.append({
			"cell": c,
			"amount": int(invested(c) * WrD.SELL_RATE),
			"toll_loss": toll(c),
			"label": (c.name + " 매각 (" + WrD.LEVEL_NAMES[c.level] + " 포함)") if c.level > 0
					else (c.name + " 토지 매각"),
		})
	return out
