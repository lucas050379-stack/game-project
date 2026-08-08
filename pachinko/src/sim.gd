extends SceneTree

## 헤드리스 확률/환수율 시뮬레이션.
##
##   godot --headless --path <프로젝트> --script res://src/sim.gd
##
## C# 버전과 같은 수치가 나오는지 확인하는 용도. 확률·배당을 건드리면 반드시 돌릴 것.

const N := 500000


func _init() -> void:
	D.init_strips()
	for r in D.REELS:
		print("reel %d: scatStop=%d" % [r, D.scat_stop[r].size()])

	var g := Game.new()
	var wagered := 0
	var line_pay := 0
	var scat_pay := 0
	var jack_pay := 0
	var jackpots := 0
	var forced_jack := 0
	var natural_jack := 0
	var bad_forced := 0
	var tier_end: Array[int] = []
	tier_end.resize(D.TIERS)
	tier_end.fill(0)
	var line_hits: Array[int] = []
	line_hits.resize(6)
	line_hits.fill(0)
	var since := 0
	var gap_sum := 0
	var gaps := 0

	for i in N:
		g.coins = 100000000   # 파산을 배제하고 순수 확률만 본다
		var res := g.spin()
		wagered += res.bet
		line_pay += res.line_pay
		scat_pay += res.scat_pay
		since += 1
		if res.wins.size() < line_hits.size():
			line_hits[res.wins.size()] += 1
		if res.forced and res.scatters < 3:
			bad_forced += 1

		if res.jackpot:
			jackpots += 1
			if res.forced:
				forced_jack += 1
			else:
				natural_jack += 1
			gap_sum += since
			gaps += 1
			since = 0

			var b := g.begin_battle(res)
			while b.tier < D.TIERS - 1 and g.roll_promotion(b):
				b.tier += 1
				if b.tier > b.max_tier:
					b.max_tier = b.tier
			tier_end[b.max_tier] += 1
			jack_pay += b.pay_at(b.max_tier)
			g.end_battle(b)

	var w := float(wagered)
	print("")
	print("spins        %d   bet/spin %d" % [N, g.total_bet()])
	print("wagered      %d" % wagered)
	print("line  RTP    %.2f%%" % (line_pay / w * 100.0))
	print("scat  RTP    %.2f%%" % (scat_pay / w * 100.0))
	print("battle RTP   %.2f%%" % (jack_pay / w * 100.0))
	print("TOTAL RTP    %.2f%%" % ((line_pay + scat_pay + jack_pay) / w * 100.0))
	print("")
	print("jackpots     %d  (forced %d / natural %d)" % [jackpots, forced_jack, natural_jack])
	print("avg gap      %.1f spins" % (float(gap_sum) / maxi(1, gaps)))
	print("badForced    %d" % bad_forced)
	print("final stage (12):")
	for i in D.TIERS:
		print("   %-16s x%4d   %.2f%%" % [
			D.tier_full(i), D.CUMULATIVE[i], tier_end[i] * 100.0 / maxi(1, jackpots)])
	var s := "line hits/spin "
	for i in line_hits.size():
		s += "%d:%.1f%%  " % [i, line_hits[i] * 100.0 / N]
	print(s)

	# 실제 소지금으로 굴려 파산까지 얼마나 버티는지
	var busted := 0
	var surv := 0
	for run in 400:
		var h := Game.new()
		var n := 0
		while h.can_spin() and n < 4000:
			var res := h.spin()
			n += 1
			if res.jackpot:
				var b := h.begin_battle(res)
				while b.tier < D.TIERS - 1 and h.roll_promotion(b):
					b.tier += 1
					if b.tier > b.max_tier:
						b.max_tier = b.tier
				h.end_battle(b)
		if not h.can_spin():
			busted += 1
		surv += n
	print("")
	print("session: busted %.1f%% of 400 runs, avg %d spins (cap 4000)" % [busted / 4.0, surv / 400])

	quit()
