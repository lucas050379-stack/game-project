extends SceneTree
## 물거품처럼 사라져줘 판 검사 — 50판 모두:
##   1) 칸 표가 26 줄 × 32 칸, 양옆 벽 · 바닥 구멍이 있고, 층마다 내려갈 틈이 있다.
##   2) 보스 판이 아니면 악당이 1 마리 이상 나온다.
##   2-1) 판마다 물건을 여기저기 떨어뜨려 — 모두 사람이 설 수 있는 자리(발판 위 몸 높이가 빈 곳)에 앉는다(11-11 "발판 사이에 끼여 못 먹는다").
##   2-2) 11-11 영상 분석으로 더한 규칙 — 글자 완성 판 통과 · 건너뛰기 조개 · 비밀 방 · 번개 · 물살 · 새 악당 셋 · 판 틀 · 대칭 비율.
##   3) 무적 봇 둘이 90초 안에 판을 깨는지(못 깨면 cheat_clear 로 다음 판) — 깬 판 수 · 걸린 시간을 찍는다. 오류 없이 50판 끝까지 간다.
##   godot --headless --path . --script res://tools/bubble_check.gd

const DT := 1.0 / 60.0


func _init() -> void:
	var bad := 0
	for lv in BbD.LEVELS:
		var gr := BbD.level(lv)
		if gr.size() != BbD.ROWS or gr.any(func(r): return String(r).length() != BbD.COLS):
			printerr("판 %d: 크기" % (lv + 1))
			bad += 1
		if String(gr[BbD.ROWS - 1])[15] != "." or String(gr[10])[0] != "#":
			printerr("판 %d: 구멍 · 벽" % (lv + 1))
			bad += 1
		for r in BbD.LAYERS:
			if not String(gr[r]).substr(2, 28).contains("."):
				printerr("판 %d: %d 줄이 막혔다" % [lv + 1, r])
				bad += 1
		if not BbD.boss_level(lv) and BbD.spawns(lv, gr).is_empty():
			printerr("판 %d: 악당 없음" % (lv + 1))
			bad += 1
	bad += _rules()
	bad += _items()
	bad += _new_rules()
	var g := BbGame.new(0, true, 7)
	g.god = true
	var cleared := 0
	var times := []
	var lv0 := -1
	var t0 := 0.0
	var total := 0.0
	while g.state != "win" and total < 60.0 * 60.0:
		if g.lv != lv0:
			lv0 = g.lv
			t0 = total
		for i in 2:
			g.inp[i] = g.bot_input(i)
		g.step(DT)
		total += DT
		for e: Dictionary in g.events:
			if String(e.kind) == "clear":
				cleared += 1
				times.append(snappedf(total - t0, 0.1))
		g.events.clear()
		if g.state == "play" and total - t0 > 90.0:
			times.append(-1)
			g.cheat_clear()
	times.sort()
	var ok := times.filter(func(x): return x >= 0)
	print("bubble: 판 %d 개 검사 오류 %d · 봇이 못 깬 판 %d · 걸린 시간 가운데 %.1f초 · 끝까지 %s" % [BbD.LEVELS, bad, times.size() - ok.size(),
			ok[ok.size() / 2] if not ok.is_empty() else -1.0, g.state])
	quit(1 if bad > 0 or g.state != "win" else 0)


## 규칙 몇 가지 — 이어 하기 · 먹물(목숨 안 잃고 앞이 안 보임) · 판 처음 악당 내려오기 · 갇힌 거품이 천장 구멍으로 빠져 바닥에서.
func _rules() -> int:
	var bad := 0
	var g := BbGame.new(0, false, 3)
	if g.enemies.is_empty() or float(g.enemies[0].y) > BbD.T * 2.5:
		printerr("판 처음 악당이 위에 있지 않다")
		bad += 1
	for k in 120:
		g.step(1.0 / 60.0)
	if g.enemies.any(func(e): return float(e.get("intro", 0.0)) > 0.0 and float(e.y) <= BbD.T * 2.0 and float(e.ty) > BbD.T * 3.0):
		printerr("악당이 내려오지 않았다")
		bad += 1
	var p: Dictionary = g.players[0]
	p.inv = 0.0
	g.inks = [{x = float(p.x), y = float(p.y) - BbD.T, vx = 0.0}]
	g.step(1.0 / 60.0)
	if not p.active or float(p.blind) <= 0.0:
		printerr("먹물: 목숨을 잃거나 안 가려졌다")
		bad += 1
	g.bubbles = [{x = BbD.FIELD.x * 0.5, y = BbD.T * 2.2, vx = 0.0, state = "float", t = 1.0, owner = 0, trap = 0, trap_t = 0.0, angry = false, big = false, rainbow = false, word = -1, go = 0.0}]
	var wrapped := false
	for k in 300:
		g.step(1.0 / 60.0)
		if not g.bubbles.is_empty() and float(g.bubbles[0].y) > BbD.FIELD.y * 0.8:
			wrapped = true
	if not wrapped:
		printerr("갇힌 거품이 천장 구멍으로 빠지지 않았다")
		bad += 1
	g.players[0].lives = 0
	g.players[0].inv = 0.0
	g.players[0].blind = 0.0
	g._die(0)
	for k in 200:
		g.step(1.0 / 60.0)
	if g.state != "over" or not g.continue_() or g.state != "play" or int(g.players[0].lives) != BbD.LIVES or g.continues != BbD.CONTINUES - 1:
		printerr("이어 하기")
		bad += 1
	return bad


## 물건이 사람이 못 들어가는 틈에 끼거나 구멍으로 끝없이 빠지지 않는다.
func _items() -> int:
	var bad := 0
	var g := BbGame.new(0, false, 5)
	for lv in BbD.LEVELS:
		g.grid = BbD.level(lv)
		g.items = []
		for c in range(3, BbD.COLS - 3):
			for r in [3, 9, 15, 21]:
				g.items.append({x = (c + 0.5) * BbD.T, y = r * BbD.T, vy = 0.0, kind = "item", v = 0, t = 0.0, ground = false})
		for k in 240:
			g._step_misc(1.0 / 60.0)
		var stuck := g.items.filter(func(it): return not _item_ok(g, it))
		if not stuck.is_empty():
			printerr("판 %d: 물건 %d 개가 못 먹는 자리 (첫째 %.0f, %.0f)" % [lv + 1, stuck.size(), stuck[0].x / BbD.T, stuck[0].y / BbD.T])
			bad += 1
	return bad


## 물건이 땅에 앉았고, 그 자리에 사람이 설 수 있고, 거기 선 사람 몸에 닿는다.
func _item_ok(g: BbGame, it: Dictionary) -> bool:
	var foot := -1.0   # 물건 밑 가장 가까운 발판 윗면 — 물건 좌표가 아니라 칸에서 찾는다(그래야 물건이 발판 속에 앉는 잘못도 잡힌다)
	for r in range(int(floor(float(it.y) / BbD.T)), BbD.ROWS):
		if g._floor_under(float(it.x), BbD.T, r):
			foot = r * BbD.T
			break
	if foot < 0.0 or float(it.y) > foot:
		return false
	var body := Rect2(float(it.x) - BbD.BODY.x * 0.5, foot - BbD.BODY.y, BbD.BODY.x, BbD.BODY.y)
	return bool(it.ground) and g._stand_ok(float(it.x), foot) and body.grow(6.0).has_point(Vector2(it.x, it.y))


func _run(g: BbGame, sec: float) -> void:
	for k in int(sec * 60.0):
		g.step(1.0 / 60.0)


func _new_rules() -> int:
	var bad := 0
	# 글자 다섯 — 그 판 바로 통과
	var g := BbGame.new(2, false, 11)
	g.god = true
	_run(g, 2.5)
	var p: Dictionary = g.players[0]
	p.letters = (1 << BbD.WORD.size()) - 1 - 1
	var b := {x = float(p.x), y = float(p.y) - BbD.T * 3.0, vx = 0.0, state = "float", t = 1.0, owner = -1, trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = 0, go = 0.0}
	g.bubbles.append(b)
	g._pop(b, 0)
	_run(g, 0.2)
	if not g.enemies.is_empty() or g.state != "clear":
		printerr("글자 완성: 판이 통과되지 않았다 (악당 %d, %s)" % [g.enemies.size(), g.state])
		bad += 1
	# 건너뛰기 조개 — 3 판에서 먹으면 6 판으로
	g = BbGame.new(2, false, 12)
	g.god = true
	_run(g, 2.5)
	p = g.players[0]
	g.items.append({x = float(p.x), y = float(p.y) - BbD.T * 0.65, vy = 0.0, kind = "skip", v = 0, t = 0.0, ground = true})
	_run(g, 0.2)
	if g.next_lv != 2 + 1 + BbD.SKIP_N:
		printerr("건너뛰기: next_lv %d" % g.next_lv)
		bad += 1
	_run(g, BbD.CLEAR_WAIT + 2.0)
	if g.lv != 2 + 1 + BbD.SKIP_N:
		printerr("건너뛰기: 간 판 %d" % (g.lv + 1))
		bad += 1
	# 건너뛰기는 보스 판을 못 넘는다 — 8 판(lv 7)에서 먹으면 10 판(lv 9)
	g = BbGame.new(7, false, 13)
	g.god = true
	_run(g, 2.5)
	p = g.players[0]
	g.items.append({x = float(p.x), y = float(p.y) - BbD.T * 0.65, vy = 0.0, kind = "skip", v = 0, t = 0.0, ground = true})
	_run(g, 0.2)
	if g.next_lv != 9:
		printerr("건너뛰기: 보스 판을 넘었다 (next_lv %d)" % g.next_lv)
		bad += 1
	# 비밀 방 — 안 죽고 5 판에 오면 문, 들어가면 비밀 방, 끝나면 6 판
	g = BbGame.new(4, false, 14)
	g.god = true
	if g.door.is_empty():
		printerr("비밀 방: 5 판에 문이 없다")
		bad += 1
	else:
		p = g.players[0]
		p.x = float(g.door.x)
		p.y = float(g.door.y)
		_run(g, 0.1)
		if g.state != "secret" or not g.enemies.is_empty():
			printerr("비밀 방: 들어가지 못했다 (%s)" % g.state)
			bad += 1
		_run(g, BbD.SECRET_T + 2.0)
		if g.lv != 5 or g.state != "play":
			printerr("비밀 방: 나와서 간 판 %d (%s)" % [g.lv + 1, g.state])
			bad += 1
	g = BbGame.new(4, false, 15)
	g.deaths_block = 1
	g._load(4)
	if not g.door.is_empty():
		printerr("비밀 방: 죽었는데 문이 열렸다")
		bad += 1
	# 번개 · 물살 — 악당을 없앤다
	for spk in 2:
		g = BbGame.new(5, false, 16 + spk)
		g.god = true
		_run(g, 2.5)
		p = g.players[0]
		var n0 := g.enemies.size()
		var e: Dictionary = g.enemies[0]
		p.x = float(e.x) - BbD.T * 4.0
		p.dir = 1
		var sb := {x = float(e.x) - BbD.T * 3.0, y = float(e.y) - BbD.T, vx = 0.0, state = "float", t = 1.0, owner = -1, trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = -1, go = 0.0, sp = spk}
		if spk == 1:
			sb.y = float(e.y) - BbD.T * 3.0
		g.bubbles.append(sb)
		g._pop(sb, 0)
		var killed := false
		for k in 180:
			g.step(1.0 / 60.0)
			if g.enemies.size() < n0 or g.dying.size() > 0:
				killed = true
				break
		if not killed:
			printerr("%s: 악당을 못 없앴다" % BbD.SPECIAL[spk])
			bad += 1
	# 새 악당 셋 — 30 초 동안 판 밖으로 안 나간다
	g = BbGame.new(14, false, 18)
	g.god = true
	_run(g, 2.0)
	g.enemies = []
	for k in [5, 6, 7]:
		g.enemies.append({k = k, x = 16.0 * BbD.T, y = 10.0 * BbD.T, vy = 0.0, dir = 1, ground = false, angry = false, cd = 1.0, spike_t = 0.0, jump_cd = 0.5,
				fx = 0.5, fy = 0.5, base = 10.0 * BbD.T, ph = 0.0})
	var hopped := false
	for k in 1800:
		g.step(1.0 / 60.0)
		for e: Dictionary in g.enemies:
			if float(e.x) < 0.0 or float(e.x) > BbD.FIELD.x or float(e.y) < -BbD.T * 3.0 or float(e.y) > BbD.FIELD.y + BbD.T * 3.0:
				printerr("새 악당 %d 이 판 밖 (%.0f, %.0f)" % [int(e.k), e.x, e.y])
				bad += 1
				e.k = -9
			if int(e.k) == 7 and float(e.vy) < -100.0:
				hopped = true
		g.enemies = g.enemies.filter(func(e): return int(e.k) >= 0)
	if not hopped:
		printerr("새우가 안 뛴다")
		bad += 1
	# 어디서든 바닥까지 내려갈 수 있다(사용자 11-11 "아래로 아예 내려갈 수 없는 판")
	for lv in BbD.LEVELS:
		if not BbD.down_ok(BbD.level(lv)):
			printerr("판 %d: 바닥까지 못 내려가는 곳이 있다" % (lv + 1))
			bad += 1
	# 벽 — 걸어서는 못 지나가고 뛰어오르면 지나간다(원작 규칙)
	g = BbGame.new(0, false, 19)
	g.god = true
	_run(g, 2.0)
	g.enemies = []
	var rows := []
	for r in BbD.ROWS:
		var row := ""
		for c in BbD.COLS:
			var wall := c < 2 or c >= BbD.COLS - 2 or (r == BbD.ROWS - 1 and (c < BbD.HOLE[0] or c > BbD.HOLE[1])) or (c == 9 and r >= 22 and r <= 24)
			row += "#" if wall else "."
		rows.append(row)
	g.grid = rows
	p = g.players[0]
	p.x = 5.0 * BbD.T
	p.y = (BbD.ROWS - 1) * BbD.T
	for k in 60:
		g.inp = [{left = false, right = true, jump = false, jump_held = false, shot = false}]
		g.step(1.0 / 60.0)
	if float(p.x) > 9.0 * BbD.T - BbD.BODY.x * 0.5 + 1.0:
		printerr("벽: 걸어서 지나갔다 (x %.1f 칸)" % (float(p.x) / BbD.T))
		bad += 1
	for k in 90:
		g.inp = [{left = false, right = true, jump = k == 0, jump_held = true, shot = false}]
		g.step(1.0 / 60.0)
	if float(p.x) < 10.0 * BbD.T + BbD.BODY.x * 0.5:
		printerr("벽: 뛰어서도 못 지나갔다 (x %.1f 칸)" % (float(p.x) / BbD.T))
		bad += 1
	# 몸은 2 칸이어도 1 칸 틈 위를 걸으면 빠진다(사용자 11-11, 원작처럼 발밑만 본다)
	rows = []
	for r in BbD.ROWS:
		var row2 := ""
		for c in BbD.COLS:
			var wall2 := c < 2 or c >= BbD.COLS - 2 or (r == BbD.ROWS - 1 and (c < BbD.HOLE[0] or c > BbD.HOLE[1])) or (r == 20 and c != 12)
			row2 += "#" if wall2 else "."
		rows.append(row2)
	g.grid = rows
	p.x = 6.0 * BbD.T
	p.y = 20.0 * BbD.T
	p.vy = 0.0
	for k in 120:
		g.inp = [{left = false, right = true, jump = false, jump_held = false, shot = false}]
		g.step(1.0 / 60.0)
		if float(p.y) > 21.0 * BbD.T:
			break
	if float(p.y) <= 21.0 * BbD.T:
		printerr("1 칸 틈: 걸어서 안 빠졌다 (x %.1f 칸, y %.1f 줄)" % [float(p.x) / BbD.T, float(p.y) / BbD.T])
		bad += 1
	# 거품을 밟아 터뜨린 순간 점프(사용자 11-11) — 빈 판 공중의 거품 위로 떨어져 터뜨리고, 바로 점프 키
	rows = []
	for r in BbD.ROWS:
		var row3 := ""
		for c in BbD.COLS:
			row3 += "#" if c < 2 or c >= BbD.COLS - 2 or (r == BbD.ROWS - 1 and (c < BbD.HOLE[0] or c > BbD.HOLE[1])) else "."
		rows.append(row3)
	g.grid = rows
	g.bubbles = [{x = 8.0 * BbD.T, y = 16.0 * BbD.T, vx = 0.0, state = "float", t = 1.0, owner = 0, trap = -1, trap_t = 0.0, angry = false, big = false, rainbow = false, word = -1, go = 0.0}]
	g.cur = Vector2(8.0 * BbD.T, 16.0 * BbD.T)
	p.x = 8.0 * BbD.T
	p.y = 12.0 * BbD.T
	p.vy = 0.0
	p.ground = false
	var popped_at := -1
	var jumped := false
	for k in 120:
		g.inp = [{left = false, right = false, jump = popped_at >= 0 and k == popped_at + 3, jump_held = false, shot = false}]
		g.step(1.0 / 60.0)
		if popped_at < 0 and g.bubbles.is_empty():
			popped_at = k
		if popped_at >= 0 and k > popped_at + 3 and float(p.vy) < -200.0:
			jumped = true
			break
	if popped_at < 0 or not jumped:
		printerr("밟아 터뜨리며 점프: 터짐 %d, 점프 %s" % [popped_at, jumped])
		bad += 1
	# 판 틀 · 촘촘한 판 · 대칭 비율
	var kinds := {}
	var sym := 0
	var normal := 0
	for lv in BbD.LEVELS:
		var kd := BbD.kind(lv)
		kinds[kd] = int(kinds.get(kd, 0)) + 1
		if kd == "boss" or kd == "classic":
			continue
		normal += 1
		var gr := BbD.level(lv)
		var same := 0
		for r in BbD.ROWS:
			if String(gr[r]) == String(gr[r]).reverse():
				same += 1
		if same == BbD.ROWS:
			sym += 1
	print("판 틀: ", kinds, " · 좌우 대칭 %d / %d" % [sym, normal])
	for kd: String in BbD.KINDS:
		if not kinds.has(kd):
			printerr("판 틀 %s 이 한 번도 안 나온다" % kd)
			bad += 1
	return bad
