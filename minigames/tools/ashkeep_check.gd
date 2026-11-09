extends SceneTree
## 잿빛 요새의 용병단 검산 — 헤드리스로 봇 영웅(AkAi)이 시나리오마다 판을 돌린다(그리기 없이 AkGame · AkAi 만).
##   godot --headless --path . --script res://tools/ashkeep_check.gd -- [시나리오당 판 수] [난이도 -1 · 0 · 1]
## 볼 것: 시나리오별 깨는 비율(봇 기준 목표 — 쉬움 85% · 보통 60% · 어려움 35%), 걸린 라운드, 남은 손패.
## 실패하면 종료 코드 1 — 판이 안 끝나거나(3000 진행) 체력이 최대를 넘거나 유닛이 겹칠 때.


func _init() -> void:
	var n := 100
	var diff := 0
	var nums := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int() or (a.begins_with("-") and a.substr(1).is_valid_int()):
			nums.append(int(a))
	if nums.size() >= 1:
		n = nums[0]
	if nums.size() >= 2:
		diff = clampi(nums[1], -1, 1)
	var fail := 0
	var t0 := Time.get_ticks_msec()
	print("[시나리오 %d개, 각 %d판, 난이도 %+d]" % [AkD.SCENARIOS.size(), n, diff])
	for sc in AkD.SCENARIOS.size():
		var wins := 0
		var rounds: Array = []
		var by_pair := {}
		for k in n:
			var pair := [k % 4, (k / 4 + 1 + k % 4) % 4]
			if pair[0] == pair[1]:
				pair[1] = (pair[1] + 1) % 4
			var g := AkGame.new(sc, pair, diff, [1 + sc / 3, 1 + sc / 3], sc * 1000 + k)
			var steps := 0
			while not g.over and steps < 3000:
				AkAi.act(g)
				steps += 1
				var seen := {}
				for u: Dictionary in g.units:
					if not u.alive:
						continue
					if seen.has(u.pos):
						printerr("시나리오 %d 판 %d: 유닛 겹침 %s" % [sc, k, str(u.pos)])
						fail += 1
					seen[u.pos] = true
					if int(u.hp) > int(u.max):
						printerr("시나리오 %d 판 %d: 체력이 최대를 넘음" % [sc, k])
						fail += 1
			if not g.over:
				printerr("시나리오 %d 판 %d: 안 끝남 (라운드 %d, pending %s)" % [sc, k, g.round_no, g.pending])
				fail += 1
				continue
			if g.win:
				wins += 1
				rounds.append(g.round_no)
			var key := "%s+%s" % [AkD.HEROES[pair[0]][0], AkD.HEROES[pair[1]][0]]
			var e: Array = by_pair.get(key, [0, 0])
			e[0] += 1
			if g.win:
				e[1] += 1
			by_pair[key] = e
		rounds.sort()
		var worst := ""
		var wr := 2.0
		for key2 in by_pair:
			var e2: Array = by_pair[key2]
			var r2 := float(e2[1]) / maxf(1.0, float(e2[0]))
			if r2 < wr:
				wr = r2
				worst = key2
		print("  %2d %-10s  깸 %3.0f%%  라운드 중앙 %s  가장 약한 조합 %s %.0f%%" % [sc + 1, AkD.SCENARIOS[sc][0], 100.0 * wins / n,
				str(rounds[rounds.size() / 2]) if not rounds.is_empty() else "-", worst, 100.0 * wr])
	print("[%d ms]" % (Time.get_ticks_msec() - t0))
	print("%s" % ("ASHKEEP CHECK OK" if fail == 0 else "ASHKEEP CHECK FAIL %d" % fail))
	quit(0 if fail == 0 else 1)
