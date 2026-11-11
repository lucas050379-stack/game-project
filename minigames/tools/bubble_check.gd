extends SceneTree
## 물거품처럼 사라져줘 판 검사 — 50판 모두:
##   1) 칸 표가 26 줄 × 32 칸, 양옆 벽 · 바닥 구멍이 있고, 층마다 내려갈 틈이 있다.
##   2) 보스 판이 아니면 악당이 1 마리 이상 나온다.
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
		for r in [21, 17, 13, 9, 5]:
			if not String(gr[r]).substr(2, 28).contains("."):
				printerr("판 %d: %d 줄이 막혔다" % [lv + 1, r])
				bad += 1
		if not BbD.boss_level(lv) and BbD.spawns(lv, gr).is_empty():
			printerr("판 %d: 악당 없음" % (lv + 1))
			bad += 1
	bad += _rules()
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
