class_name Game
extends RefCounted

## 게임 상태와 규칙 계산. 그리기와는 완전히 분리되어 있어 헤드리스로 돌려볼 수 있다.


class LineWin:
	var line := 0      ## 페이라인 번호
	var sym := 0       ## 성립한 심볼
	var count := 0     ## 왼쪽부터 이어진 개수
	var pay := 0


class SpinResult:
	var stop: Array[int] = []            ## 릴별 정지 위치(띠 인덱스)
	var grid: Array = []                 ## grid[reel][row]
	var wins: Array[LineWin] = []
	var scatter_at: Array[int] = []      ## reel * ROWS + row
	var scatters := 0
	var line_pay := 0
	var scat_pay := 0
	var total := 0
	var bet := 0
	var jackpot := false                 ## 해전 발동
	var forced := false                  ## 전의 게이지가 끌어낸 스핀
	var start_tier := 0
	var spirit_t := 0.0                  ## 스핀 시점의 전의

	## 릴 r 에 총통이 있는가 (연출용)
	func has_scatter(r: int) -> bool:
		for y in D.ROWS:
			if grid[r][y] == D.SCAT:
				return true
		return false


class BattleRun:
	var tier := 0                        ## 현재 단계
	var start_tier := 0
	var max_tier := 0
	var scatters := 0
	var spirit_t := 0.0
	var bet := 0
	var kills := 0                       ## 누적 처단 수
	var payout := 0                      ## 확정된 누적 배당
	var bonus := 0                       ## 연타 보너스

	## 이 단계를 마쳤을 때의 누적 배당
	func pay_at(t: int) -> int:
		return int(round(D.tier_total(t) * bet))

	func pay_before(t: int) -> int:
		return 0 if t <= 0 else pay_at(t - 1)


var coins := D.START_COINS
var bet_idx := D.DEFAULT_BET_IDX
## 상한에 걸려 배팅이 자동으로 내려갔다 — 화면이 읽고 지운다
var bet_lowered := false
var spirit := 0.0

var spins := 0
var wagered := 0
var won := 0
var best := 0
## 도달한 최종 단계별 횟수 (12단계)
var battles: Array[int] = []
var battle_total := 0

var last: SpinResult = null


func _init() -> void:
	D.init_strips()
	battles.resize(D.TIERS)
	battles.fill(0)


func bet_per_line() -> int:
	return D.BET_LEVELS[bet_idx]


func total_bet() -> int:
	return bet_per_line() * D.LINES


func spirit_t() -> float:
	return minf(1.0, spirit / D.SPIRIT_MAX)


func jackpot_chance() -> float:
	return D.jackpot_chance(spirit_t())


## 게이지가 가득 차기까지 남은 스핀 수 (= 해전 천장까지)
func spins_to_full() -> int:
	return maxi(0, ceili((D.SPIRIT_MAX - spirit) / D.SPIRIT_PER_SPIN))


func can_spin() -> bool:
	return coins >= total_bet()


static func min_bet() -> int:
	return D.BET_LEVELS[0] * D.LINES


## 지금 걸 수 있는 총배팅 상한 — 보유 코인의 1/10.
## 첫 단계(9)는 이 값을 넘더라도 항상 허용한다. 아니면 코인이 적을 때 아무것도 못 건다.
func bet_cap() -> int:
	return coins / D.BET_CAP_DIV


## 상한을 넘지 않는 가장 높은 단계
func _cap_idx() -> int:
	var b := 0
	var cap := bet_cap()
	for i in D.BET_LEVELS.size():
		if D.BET_LEVELS[i] * D.LINES <= cap:
			b = i
	return b


## 코인이 줄어 상한을 넘게 되면 배팅을 내린다. 올리지는 않는다.
## 화면에 알려 줘야 하므로 `bet_lowered` 를 세워 둔다 — main.gd 가 읽고 지운다.
func clamp_bet() -> bool:
	var b := _cap_idx()
	if b >= bet_idx:
		return false
	bet_idx = b
	bet_lowered = true
	return true


## 해전(그룹) 하나에 도달한 횟수 — 그 해전 안 어느 단계든 포함
func group_reached(group: int) -> int:
	var n := 0
	for i in battles.size():
		if D.tier_group(i) >= group:
			n += battles[i]
	return n


func reset() -> void:
	coins = D.START_COINS
	bet_idx = D.DEFAULT_BET_IDX
	bet_lowered = false
	spirit = 0.0
	spins = 0
	wagered = 0
	won = 0
	best = 0
	battles.fill(0)
	battle_total = 0
	last = null


## 배팅 단계를 옮긴다. 올릴 때는 보유 코인의 1/10 까지만.
func change_bet(dir: int) -> bool:
	var n := bet_idx + dir
	if n < 0 or n >= D.BET_LEVELS.size():
		return false
	if dir > 0 and D.BET_LEVELS[n] * D.LINES > bet_cap():
		return false
	bet_idx = n
	return true


func max_bet() -> void:
	bet_idx = _cap_idx()

# ==================== 스핀 ====================

func spin() -> SpinResult:
	var r := SpinResult.new()
	r.bet = total_bet()
	coins -= r.bet
	spins += 1
	wagered += r.bet

	# 스핀할 때마다 전의가 쌓이고, 그만큼 해전 확률이 오른다.
	# 배팅액은 여기에 관여하지 않는다 — 크게 건다고 해전이 빨리 오지는 않는다.
	spirit += D.SPIRIT_PER_SPIN
	r.spirit_t = spirit_t()
	r.forced = randf() < D.jackpot_chance(r.spirit_t)

	r.stop.resize(D.REELS)
	if r.forced:
		_forced_stops(r.stop, r.spirit_t)
	else:
		for i in D.REELS:
			r.stop[i] = randi() % D.STRIP_LEN

	r.grid = []
	for i in D.REELS:
		var col := []
		col.resize(D.ROWS)
		for y in D.ROWS:
			col[y] = D.strip[i][(r.stop[i] + y) % D.STRIP_LEN]
		r.grid.append(col)

	_evaluate(r)

	if r.scatters >= 3:
		r.jackpot = true
		r.start_tier = D.weighted(D.start_tier_weights(r.scatters, r.spirit_t))
		spirit = 0.0   # 해전이 시작되면 전의는 처음부터 다시 쌓인다
	else:
		# 해전이 붙으면 배당이 아직 안 들어왔으니 그게 끝난 뒤에 맞춘다
		clamp_bet()

	last = r
	return r


## 해전이 확정된 스핀 — 총통이 3개 이상 보이도록 정지 위치를 고른다
func _forced_stops(stop: Array[int], t: float) -> void:
	var w := [66.0, 26.0 * (1.0 + t * 0.8), 8.0 * (1.0 + t * 2.2)]
	var want: int = 3 + D.weighted(w)
	want = mini(want, D.REELS)

	var reels: Array[int] = []
	for i in D.REELS:
		reels.append(i)
	reels.shuffle()
	var hit := []
	hit.resize(D.REELS)
	hit.fill(false)
	for i in want:
		hit[reels[i]] = true

	for i in D.REELS:
		var pool: Array = D.scat_stop[i] if hit[i] else D.plain_stop[i]
		stop[i] = pool[randi() % pool.size()] if pool.size() > 0 else randi() % D.STRIP_LEN

# ==================== 판정 ====================

func _evaluate(r: SpinResult) -> void:
	# 총통(스캐터) — 위치와 무관하게 개수로 지급
	for i in D.REELS:
		for y in D.ROWS:
			if r.grid[i][y] == D.SCAT:
				r.scatters += 1
				r.scatter_at.append(i * D.ROWS + y)
	if r.scatters >= 3 and r.scatters < D.SCATTER_PAY.size():
		r.scat_pay = D.SCATTER_PAY[r.scatters] * r.bet

	# 페이라인 — 왼쪽부터 이어진 것만 인정
	var line := []
	line.resize(D.REELS)
	for li in D.LINES:
		for i in D.REELS:
			line[i] = r.grid[i][D.LINE[li][i]]
		var w := _eval_line(line)
		if w == null:
			continue
		w.line = li
		w.pay = D.PAY[w.sym][w.count - 3] * bet_per_line()
		if w.pay <= 0:
			continue
		r.wins.append(w)
		r.line_pay += w.pay

	r.total = r.line_pay + r.scat_pay
	coins += r.total
	won += r.total
	if r.total > best:
		best = r.total


## 한 줄을 판정한다. 와일드(이순신)는 총통을 제외한 모든 심볼을 대신한다.
static func _eval_line(line: Array) -> LineWin:
	# 후보 A: 이순신 자체로 이어진 줄
	var wild_run := 0
	while wild_run < line.size() and line[wild_run] == D.WILD:
		wild_run += 1
	var best_pay := -1
	var out: LineWin = null
	if wild_run >= 3:
		out = LineWin.new()
		out.sym = D.WILD
		out.count = wild_run
		best_pay = D.PAY[D.WILD][wild_run - 3]

	# 후보 B: 앞쪽 와일드를 건너뛴 첫 실제 심볼
	var idx := 0
	while idx < line.size() and line[idx] == D.WILD:
		idx += 1
	if idx < line.size() and line[idx] != D.SCAT:
		var sym: int = line[idx]
		var run := 0
		while run < line.size() and (line[run] == sym or line[run] == D.WILD):
			run += 1
		if run >= 3:
			var pay: int = D.PAY[sym][run - 3]
			if pay > best_pay:
				out = LineWin.new()
				out.sym = sym
				out.count = run
	return out

# ==================== 해전 ====================

func begin_battle(r: SpinResult) -> BattleRun:
	var b := BattleRun.new()
	b.tier = r.start_tier
	b.start_tier = r.start_tier
	b.max_tier = r.start_tier
	b.scatters = r.scatters
	b.spirit_t = r.spirit_t
	b.bet = r.bet
	b.kills = D.kills_before(r.start_tier)
	b.payout = b.pay_before(r.start_tier)
	return b


## 현 단계를 마친 뒤 다음 단계로 갈지 판정한다
func roll_promotion(b: BattleRun) -> bool:
	if b.tier >= D.TIERS - 1:
		return false
	return randf() < D.promote_chance(b.tier, b.scatters, b.spirit_t)


## 해전 종료 — 배당을 지급한다
func end_battle(b: BattleRun) -> void:
	var pay := b.pay_at(b.max_tier) + b.bonus
	coins += pay
	won += pay
	if pay > best:
		best = pay
	battle_total += 1
	if b.max_tier >= 0 and b.max_tier < battles.size():
		battles[b.max_tier] += 1
	clamp_bet()
