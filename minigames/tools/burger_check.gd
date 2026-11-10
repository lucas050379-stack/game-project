extends SceneTree
## 버거 한 판 합격 기준(docs/design/burger.md §11) — 봇이 서른 날을 돈다.
##   godot --headless --path . --script res://tools/burger_check.gd
## 꼼꼼한 봇(0.3초마다 손, 실수 없음): 날마다 별 셋. 느린 봇(0.7초마다 손, 열에 하나 실수): 별 평균이 날이 갈수록 내려간다.
## 재료 · 강화는 그날쯤 갖췄을 만큼(날이 갈수록 는다)으로 준다. 맨 끝 열 "권장 목표" = 꼼꼼한 봇이 번 돈의 절반 — `BgD.GOALS` 를 맞출 때 본다.

const N := 12
const DT := 1.0 / 30.0


## d 째 날쯤 갖췄을 살림 — 재료는 싼 것부터 날마다 하나쯤, 강화는 값 순서로.
func _have(d: int) -> Array:
	var ids: Array = BgD.ORDER.duplicate()
	ids.sort_custom(func(a, b): return BgD.unlock_cost(a) < BgD.unlock_cost(b))
	return ids.slice(0, mini(ids.size(), 6 + d))


func _ups(d: int) -> Dictionary:
	return {grill = mini(2, d / 8), warm = mini(3, d / 6), helper = 1 if d >= 20 else 0, drink = 1 if d >= 12 else 0, fries = 1 if d >= 14 else 0,
			seat = 1 if d >= 24 else 0, decor = mini(2, d / 10), cashier = 1 if d >= 16 else 0}


func _run(d: int, seed_: int, pace: float, miss: float) -> BgGame:
	var g := BgGame.new(d, seed_, _have(d), _ups(d))
	var guard := 0
	while not g.over and guard < 30 * 400:
		g.bot(DT, pace, miss)
		g.step(DT)
		g.events.clear()
		guard += 1
	return g


func _init() -> void:
	var fail := 0
	print("날   꼼꼼 별  번 돈  손님  놓침  틀림   느린 별  번 돈   목표   권장 목표")
	var slow_avg := []
	for d in BgD.DAYS:
		var st := 0.0
		var mon := 0.0
		var srv := 0.0
		var lost := 0
		var wrong := 0
		var sst := 0.0
		var smon := 0.0
		for k in N:
			var g := _run(d, 1000 + d * 100 + k, 0.3, 0.0)
			st += g.stars()
			mon += g.money
			srv += g.served
			lost += g.lost
			wrong += g.wrong + g.burnt
			var s := _run(d, 5000 + d * 100 + k, 0.7, 0.1)
			sst += s.stars()
			smon += s.money
		slow_avg.append(sst / N)
		print("%2d    %4.2f   %5d  %4.1f  %4d  %4d     %4.2f   %5d   %5d   %5d" % [d + 1, st / N, int(mon / N), srv / N, lost, wrong, sst / N, int(smon / N),
				int(BgD.GOALS[d]), int(mon / N * 0.5 / 10.0) * 10])
		if st / N < 2.9:
			printerr("  꼼꼼한 봇이 %d일째에 별 %.2f (셋이어야)" % [d + 1, st / N])
			fail += 1
	var head := 0.0
	var tail := 0.0
	for d in 5:
		head += float(slow_avg[d])
		tail += float(slow_avg[BgD.DAYS - 1 - d])
	if tail >= head:
		printerr("  난이도 경사 없음: 느린 봇 끝 닷새 %.2f >= 첫 닷새 %.2f" % [tail / 5.0, head / 5.0])
		fail += 1
	print("BURGER CHECK OK" if fail == 0 else "BURGER CHECK FAIL %d" % fail)
	quit(0 if fail == 0 else 1)
