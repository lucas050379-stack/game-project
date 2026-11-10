extends SceneTree
## 붉은 별 개척단 검산 — 헤드리스로 봇끼리 수천 판(그리기 없이 RsGame · RsAi 만).
##   godot --headless --path . --script res://tools/redstar_check.gd -- [판 수] [레벨 0~2]
## 볼 것(기획서 목표치): 첫 선 승률 48~52% · 판 길이 중앙 10~12세대 · 기업별 승률 42~58% ·
## 카드별 "낸 쪽 승률" 45~58% · 점수 중 개척 등급 비중 50~65%.
## 실패하면 종료 코드 1 — 판이 안 끝나거나(2000 행동) 자원 · 생산이 하한을 넘거나 지표가 넘칠 때.


func _init() -> void:
	var games := 1000
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
	var kinds := [0, 0, 0]
	for c: Dictionary in RsD.all_cards():
		kinds[int(c.kind)] += 1
	print("[카드] %d장  건설 %d · 운영 %d · 사건 %d" % [RsD.CARDS.size(), kinds[0], kinds[1], kinds[2]])
	var first_win := 0
	var draws := 0
	var gens: Array = []
	var tr_share: Array = []
	var corp := {}        # 이름 → [판, 승]
	var card_own := {}    # 이름 → [낸 판, 낸 쪽 승]
	var t0 := Time.get_ticks_msec()
	var done := 0
	for k in games:
		var g := RsGame.new(k, [true, true])
		var steps := 0
		while not g.over and steps < 2000:
			RsAi.act(g, level)
			steps += 1
			for p in 2:
				if int(g.players[p].prod[0]) < RsD.PROD_MIN:
					printerr("판 %d: 크레딧 생산이 하한 아래" % k)
					fail += 1
				for r in RsD.N_RES:
					if int(g.players[p].res[r]) < 0:
						printerr("판 %d: 자원 음수 %s" % [k, RsD.RES_NAME[r]])
						fail += 1
		if not g.over:
			printerr("판 %d: 2000 행동 안에 안 끝남 (세대 %d, pending %s)" % [k, g.gen, g.pending])
			fail += 1
			continue
		for w in 3:
			if int(g.params[w]) > int(RsD.PARAM_MAX[w]):
				printerr("판 %d: 지표가 넘침" % k)
				fail += 1
		done += 1
		gens.append(g.gen)
		if g.winner < 0:
			draws += 1
		elif g.winner == g.first_start:
			first_win += 1
		for p in 2:
			var sp := g.score_parts(p)
			tr_share.append(float(sp.tr) / maxf(1.0, float(sp.total)))
			var cn: String = g.players[p].corp.name
			var e: Array = corp.get(cn, [0, 0])
			e[0] += 1
			if g.winner == p:
				e[1] += 1
			corp[cn] = e
			for c: Dictionary in g.players[p].played:
				var e2: Array = card_own.get(c.name, [0, 0])
				e2[0] += 1
				if g.winner == p:
					e2[1] += 1
				card_own[c.name] = e2
	var n := maxi(1, done)
	gens.sort()
	tr_share.sort()
	print("\n[%d판, 봇 레벨 %d, %d ms]" % [games, level, Time.get_ticks_msec() - t0])
	print("  첫 선 승률 %.1f%%  무승부 %.1f%%" % [100.0 * first_win / n, 100.0 * draws / n])
	print("  세대 중앙 %d (10%% %d · 90%% %d)" % [gens[gens.size() / 2], gens[gens.size() / 10], gens[gens.size() * 9 / 10]])
	print("  점수 중 개척 등급 비중 중앙 %.0f%%" % [100.0 * tr_share[tr_share.size() / 2]])
	print("\n[기업 승률]")
	for cn in corp:
		var e3: Array = corp[cn]
		print("  %s  %.0f%% (%d판)" % [cn, 100.0 * e3[1] / maxi(1, e3[0]), e3[0]])
	print("\n[카드: 낸 쪽 승률 45~58%% 밖, 30판 이상]")
	var keys := card_own.keys()
	keys.sort()
	for nm in keys:
		var e4: Array = card_own[nm]
		if int(e4[0]) < 30:
			continue
		var wr: float = 100.0 * e4[1] / e4[0]
		if wr < 45.0 or wr > 58.0:
			print("  %s  %.0f%% (%d판)" % [nm, wr, e4[0]])
	var never := []
	for c: Dictionary in RsD.all_cards():
		if int(card_own.get(c.name, [0, 0])[0]) < games / 20:
			never.append(c.name)
	print("  거의 안 쓰인 카드: %s" % ", ".join(never))
	print("\n%s" % ("REDSTAR CHECK OK" if fail == 0 else "REDSTAR CHECK FAIL %d" % fail))
	quit(0 if fail == 0 else 1)
