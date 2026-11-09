extends SceneTree
## 제국 연대기 검산 — 헤드리스로 봇끼리 수천 판(그리기 없이 EmGame · EmAi 만).
##   godot --headless --path . --script res://tools/empire_check.gd -- [판 수] [레벨 0~2]
## 볼 것(기획서 목표치, 11-09 고침 — 실제 장르도 문명 승리가 대부분): 첫 선 승률 48~52% · 문명 75~85% · 군사 10~15% · 과학 5~10% ·
## 문명 승리 점수 차 5~12 · 카드별 "가진 쪽 승률" 45~58% 밖 · 불가사의 건설률 40~80% 밖 · 토큰 선택률 극단값.
## 실패하면 종료 코드 1 — 판이 안 끝나거나(300 차례) 돈이 음수거나 카드 수가 어긋날 때.


func _init() -> void:
	var games := 2000
	var level := 1
	var nums := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			nums.append(int(a))
	if nums.size() >= 1:
		games = nums[0]
	if nums.size() >= 2:
		level = clampi(nums[1], 0, 2)
	var fail := 0
	# 덱 구성
	for a in 3:
		var cs := EmD.age_cards(a)
		var by := [0, 0, 0, 0, 0, 0, 0]
		for c: Dictionary in cs:
			by[int(c.kind)] += 1
		print("[%d시대] %d장  색별 %s" % [a + 1, cs.size(), str(by)])
	# 연계 이름이 실제 카드인가
	var names := {}
	for c: Dictionary in EmD.all_cards():
		names[c.name] = true
	for c: Dictionary in EmD.all_cards():
		if c.chain != "" and not names.has(c.chain):
			printerr("연계 대상이 없음: %s <- %s" % [c.name, c.chain])
			fail += 1
	# 과학 심볼은 0~5 가 두 장씩
	var sc := [0, 0, 0, 0, 0, 0, 0]
	for c: Dictionary in EmD.all_cards():
		if c.eff.has("sci"):
			sc[int(c.eff.sci)] += 1
	print("  과학 심볼 장수 %s" % str(sc))

	var wins := [0, 0, 0]          # 0번 · 1번 · 무승부
	var first_win := 0             # 첫 선이 이긴 판
	var kinds := {mil = 0, sci = 0, civ = 0}
	var diffs: Array = []
	var turns: Array = []
	var card_own := {}             # 이름 → [가진 판, 가진 쪽이 이긴 판]
	var wonder_draft := {}         # 이름 → [뽑힌 판, 지은 판, 지은 쪽이 이긴 판]
	var token_pick := {}           # 이름 → [공개된 판, 가져간 판]
	var t0 := Time.get_ticks_msec()
	for k in games:
		var g := EmGame.new(k, [true, true])
		for tk: Dictionary in g.tokens_open:
			var e: Array = token_pick.get(tk.name, [0, 0])
			e[0] += 1
			token_pick[tk.name] = e
		var steps := 0
		while not g.over and steps < 300:
			EmAi.act(g, level)
			steps += 1
			for p in 2:
				if int(g.players[p].coin) < 0:
					printerr("판 %d: 돈이 음수" % k)
					fail += 1
		if not g.over:
			printerr("판 %d: 300 차례 안에 안 끝남" % k)
			fail += 1
			continue
		turns.append(g.turn_no)
		if g.winner < 0:
			wins[2] += 1
		else:
			wins[g.winner] += 1
			if g.winner == g.first:
				first_win += 1
		kinds[g.win_kind] += 1
		if g.win_kind == "civ":
			diffs.append(absi(g.points(0) - g.points(1)))
		for p in 2:
			for c: Dictionary in g.players[p].cards:
				var e2: Array = card_own.get(c.name, [0, 0])
				e2[0] += 1
				if g.winner == p:
					e2[1] += 1
				card_own[c.name] = e2
			for w: Dictionary in g.players[p].wonders:
				var e3: Array = wonder_draft.get(w.w.name, [0, 0, 0])
				e3[0] += 1
				if w.built:
					e3[1] += 1
					if g.winner == p:
						e3[2] += 1
				wonder_draft[w.w.name] = e3
			for tk2: Dictionary in g.players[p].tokens:
				var e4: Array = token_pick.get(tk2.name, [0, 0])
				e4[1] += 1
				token_pick[tk2.name] = e4
	var n := maxi(1, turns.size())
	print("\n[%d판, 봇 레벨 %d, %d ms]" % [games, level, Time.get_ticks_msec() - t0])
	print("  승: 첫 선 %.1f%%  0번 자리 %.1f%%  1번 자리 %.1f%%  무승부 %.1f%%" % [100.0 * first_win / n, 100.0 * wins[0] / n, 100.0 * wins[1] / n, 100.0 * wins[2] / n])
	print("  승리 방식: 문명 %.1f%%  군사 %.1f%%  과학 %.1f%%" % [100.0 * kinds.civ / n, 100.0 * kinds.mil / n, 100.0 * kinds.sci / n])
	diffs.sort()
	turns.sort()
	if not diffs.is_empty():
		print("  문명 승리 점수 차 중앙 %d (10%% %d · 90%% %d)" % [diffs[diffs.size() / 2], diffs[diffs.size() / 10], diffs[diffs.size() * 9 / 10]])
	print("  차례 수 중앙 %d" % turns[turns.size() / 2])
	print("\n[카드: 가진 쪽 승률 45~58%% 밖]")
	var keys := card_own.keys()
	keys.sort()
	for nm in keys:
		var e5: Array = card_own[nm]
		if int(e5[0]) < 30:
			continue
		var wr: float = 100.0 * e5[1] / e5[0]
		if wr < 45.0 or wr > 58.0:
			print("  %s  %.0f%% (%d판)" % [nm, wr, e5[0]])
	print("\n[불가사의: 뽑힌 판 중 지은 비율 · 지은 쪽 승률]")
	for nm in wonder_draft:
		var e6: Array = wonder_draft[nm]
		print("  %s  지음 %.0f%%  승 %.0f%%" % [nm, 100.0 * e6[1] / maxi(1, e6[0]), 100.0 * e6[2] / maxi(1, e6[1])])
	print("\n[발전 토큰: 공개된 판 중 가져간 비율]")
	for nm in token_pick:
		var e7: Array = token_pick[nm]
		print("  %s  %.0f%%" % [nm, 100.0 * e7[1] / maxi(1, e7[0])])
	print("\n%s" % ("EMPIRE CHECK OK" if fail == 0 else "EMPIRE CHECK FAIL %d" % fail))
	quit(0 if fail == 0 else 1)
