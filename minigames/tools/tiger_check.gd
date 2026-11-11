extends SceneTree
## 떡 하나 주면 안 잡아먹지 합격 기준(docs/design/tiger.md "이어 달리기 개편") — 봇이 첫 구간부터 배가 바닥날 때까지 이어 달린다.
##   godot --headless --path . --script res://tools/tiger_check.gd [-- 판 수]
## 닿는 구간 가운데값: 완벽 14~16 · 덜렁 10~14 · 서툰 6~10(사용자 11-11 목표) · 공중 시간 40% 이상(뛰게 만드는 길).
## 덜렁 봇(장애물 · 높은 것을 열에 하나 못 봄): 닿는 구간 가운데값 4~10 — 사람은 대개 여기 사이.
## 안 끝나는 판(15분 넘게)이 없어야 한다.

const DT := 1.0 / 60.0
const LIMIT := 60 * 60 * 15


func _run(seed_: int, miss: float) -> TgGame:
	var g := TgGame.new(0, seed_)
	var guard := 0
	while not g.over and guard < LIMIT:
		g.bot(0.0, miss)
		g.step(DT)
		g.events.clear()
		guard += 1
	return g


func _med(a: Array) -> float:
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2]) if not b.is_empty() else 0.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var fail := 0
	print("봇        닿은 구간(최소 / 가운데 / 최대)   거리 m(가운데)   점수(가운데)   공중%   10초당 점프   부딪힘/분   꼬치 먹은 비율   겹치기 최고")
	var res := {}
	for label in ["완벽", "덜렁(10%)", "서툰(25%)"]:
		var miss: float = {"완벽": 0.0, "덜렁(10%)": 0.1, "서툰(25%)": 0.25}[label]
		var zones := []
		var ms := []
		var scores := []
		var air := 0.0
		var tt := 0.0
		var jumps := 0
		var hits := 0
		var kk := 0
		var kk_all := 0
		var mx := 1
		for k in n:
			var g := _run(7000 + k * 13, miss)
			if not g.over:
				printerr("  안 끝남: %s 시드 %d — %d 구간 %dm" % [label, k, g.zone + 1, g.meters()])
				fail += 1
			zones.append(g.zone + 1)
			ms.append(g.meters())
			scores.append(g.score())
			air += g.air_t
			tt += g.time
			hits += g.hits
			kk += g.lanterns
			kk_all += g.lanterns_all
			mx = maxi(mx, g.best_mult)
		# 점프 수는 다시 한 판을 사건까지 세어 본다(공중 시간은 위에서)
		var g2 := TgGame.new(0, 99, [])
		var guard := 0
		while not g2.over and guard < LIMIT:
			g2.bot(0.0, miss)
			g2.step(DT)
			for e: Dictionary in g2.events:
				if e.kind == "jump":
					jumps += 1
			g2.events.clear()
			guard += 1
		var zs := zones.duplicate()
		zs.sort()
		res[label] = {zone = _med(zones), air = air / maxf(1.0, tt)}
		print("%-8s  %3d / %4.1f / %3d                  %6d          %9d     %4.0f%%     %4.1f          %4.1f        %3.0f%%            x%d" % [label, int(zs[0]), _med(zones), int(zs[zs.size() - 1]),
				int(_med(ms)), int(_med(scores)), air / maxf(1.0, tt) * 100.0, jumps / maxf(1.0, g2.time) * 10.0, hits / maxf(1.0, tt / 60.0),
				kk * 100.0 / maxf(1.0, kk_all), mx])
	# 목표(사용자 11-11 두 번째): 서툰 6~10 · 덜렁 10~14 · 완벽 14~16
	var pz := float(res["완벽"].zone)
	if pz < 14.0 or pz > 16.0:
		printerr("  완벽 봇 가운데 %.1f 구간(14~16 이어야)" % pz)
		fail += 1
	if float(res["완벽"].air) < 0.4:
		printerr("  공중 시간이 짧음: %.0f%%(40%% 이상이어야 — 뛰게 만드는 길)" % (float(res["완벽"].air) * 100.0))
		fail += 1
	var dz := float(res["덜렁(10%)"].zone)
	if dz < 10.0 or dz > 14.0:
		printerr("  덜렁 봇 가운데 %.1f 구간(10~14 이어야)" % dz)
		fail += 1
	var sz := float(res["서툰(25%)"].zone)
	if sz < 6.0 or sz > 10.0:
		printerr("  서툰 봇 가운데 %.1f 구간(6~10 이어야)" % sz)
		fail += 1
	print("TIGER CHECK OK" if fail == 0 else "TIGER CHECK FAIL %d" % fail)
	quit(0 if fail == 0 else 1)
