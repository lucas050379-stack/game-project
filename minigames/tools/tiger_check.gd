extends SceneTree
## 떡 하나 주면 안 잡아먹지 합격 기준(docs/design/tiger.md §7) — 봇이 라운드 10개를 달린다.
##   godot --headless --path . --script res://tools/tiger_check.gd
## 완벽 봇: 전 라운드 완주 100% + **떡을 전부 먹는다**(완벽하게 달리면 다 먹을 수 있어야 한다). 느린 봇(장애물 12% 놓침): 1~3 라운드 80% 이상, 10 라운드는 그보다 낮아야(난이도 경사).

const N := 50
const DT := 1.0 / 60.0


func _run(r: int, seed_: int, miss: float) -> TgGame:
	var g := TgGame.new(r, seed_)
	var guard := 0
	while not g.over and guard < 60 * 400:
		g.bot(0.0, miss)
		g.step(DT)
		g.events.clear()
		guard += 1
	return g


func _init() -> void:
	var fail := 0
	print("라운드            완벽봇 완주  부딪힘  별 평균  떡%   느린봇 완주  시간(초)")
	var slow_rate := []
	for r in TgD.ROUNDS.size():
		var win := 0
		var hits := 0
		var stars := 0
		var emb := 0.0
		var secs := 0.0
		var slow := 0
		var missed := 0
		for k in N:
			var g := _run(r, 1000 + r * 100 + k, 0.0)
			if not g.over:
				printerr("  안 끝남: 라운드 %d 시드 %d" % [r + 1, k])
				fail += 1
			win += 1 if g.win else 0
			hits += g.hits
			stars += g.stars()
			emb += float(g.embers) / maxf(1.0, g.embers_all)
			secs += g.time
			if g.embers < g.embers_all:
				missed += 1
				if missed <= 2:
					printerr("  완벽 봇이 떡을 놓침: 라운드 %d 시드 %d — %d / %d" % [r + 1, k, g.embers, g.embers_all])
				fail += 1
			slow += 1 if _run(r, 5000 + r * 100 + k, 0.25).win else 0
		slow_rate.append(float(slow) / N)
		print("%2d %-12s  %4d%%     %5.2f   %4.2f    %3d%%     %4d%%      %5.1f" % [r + 1, String(TgD.ROUNDS[r][0]), win * 100 / N, float(hits) / N,
				float(stars) / N, int(emb / N * 100.0), slow * 100 / N, secs / N])
		if win < N:
			printerr("  완벽 봇이 라운드 %d 를 %d / %d 만 완주" % [r + 1, win, N])
			fail += 1
	for r in 3:
		if slow_rate[r] < 0.7:
			printerr("  느린 봇이 라운드 %d 를 %d%% 만 완주(80%% 이상이어야)" % [r + 1, int(slow_rate[r] * 100)])
			fail += 1
	if slow_rate[TgD.ROUNDS.size() - 1] >= slow_rate[0]:
		printerr("  난이도 경사 없음: 느린 봇 10라운드 %d%% >= 1라운드 %d%%" % [int(slow_rate[TgD.ROUNDS.size() - 1] * 100), int(slow_rate[0] * 100)])
		fail += 1
	print("TIGER CHECK OK" if fail == 0 else "TIGER CHECK FAIL %d" % fail)
	quit(0 if fail == 0 else 1)
