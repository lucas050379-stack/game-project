extends SceneTree

## 헤드리스 검산기. 창을 띄우지 않고 40라운드를 끝까지 돌려 본다.
##
## ## 무엇을 재는가
##
## 이 게임은 코어가 없다. **몬스터가 쌓이는 속도**가 곧 난이도이므로,
## 라운드마다 "살아 남은 몬스터가 몇 마리인지"를 본다. 이 값이 완만하게 오르다
## [constant D.LOSE_COUNT] 근처에서 끝나면 잘 맞은 것이고, 초반부터 붙으면 너무 어렵고,
## 끝까지 한 자리면 너무 쉽다.
##
## 흉내 내는 것은 **잘 두는 사람**이다 — 위습을 남기지 않고 유닛을 뽑고, 조합할 수 있으면
## 전부 조합하고, 유닛을 고리 길에 고르게 깔아 사거리를 낭비하지 않는다.
## 스토리 라인은 흉내 내지 않는다(유닛을 빼는 선택이라 본진 화력만 재는 쪽이 보수적이다).
##
## ```
## sim.bat
## ```

const DT := 1.0 / 30.0


func _init() -> void:
	var g := Game.new()
	var w := World.new(g)
	for i in 4:
		g.draw_unit()

	print("라운드 | 유닛 | 최고등급 | 초당피해 | 남은 몬스터 | 신규체력")
	print("-------+------+----------+----------+-------------+---------")

	var lost := 0
	while g.round_no <= D.MAX_ROUND:
		_spend(g)
		_craft_all(g)
		_arrange(g)

		var n := g.round_no
		w.spawn_round(n)
		var sec := 0.0
		while sec < D.ROUND_TIME:
			w.step(DT)
			sec += DT
			if w.field_alive() >= D.LOSE_COUNT:
				break

		var alive := w.field_alive()
		print("%6d | %4d | %8s | %8s | %11d | %8s" % [
			n, g.units.size(), _top_grade(g), P.n(int(_dps(g))), alive,
			P.n(int(D.mob_hp(n)))])

		if alive >= D.LOSE_COUNT:
			lost = n
			break
		g.next_round()

	print("")
	if lost > 0:
		print("→ %d 라운드에서 몬스터 %d마리에 파묻혔다. HP_RAMP(%.2f) 를 낮추면 쉬워진다."
			% [lost, D.LOSE_COUNT, D.HP_RAMP])
	else:
		print("→ %d 라운드 완주. 남은 몬스터 %d / %d."
			% [D.MAX_ROUND, w.field_alive(), D.LOSE_COUNT])
		print("   끝까지 한 자리였다면 HP_RAMP 를 올려 조여야 한다.")
	quit()


# ══ 잘 두는 사람 흉내 ═══════════════════════════════════════════

## 위습을 남기지 않는다. 나무 도박은 기대값이 목재 1.08 개라 랜덤 도박 한 번에 3개가
## 드는데, 여기서는 **유닛 뽑기에 전부 쓰는 쪽**만 재 본다 — 조합 트리를 타는 정공법이다.
func _spend(g: Game) -> void:
	# 몬스터를 잡아 번 골드는 곧바로 위습으로 바꾼다
	while g.buy_wisp():
		pass
	while g.wisp > 0:
		g.draw_unit()
	while not g.reward_wisps.is_empty():
		g.use_reward()


func _craft_all(g: Game) -> void:
	for i in 200:
		var list := g.craftable()
		if list.is_empty():
			return
		g.craft(list[0])


## 유닛을 고리 길을 따라 고르게 깐다. 안쪽과 바깥쪽을 번갈아 놓아
## 길 양쪽에서 때리게 한다 — 한쪽에만 몰면 반대편 사거리가 통째로 놀게 된다.
func _arrange(g: Game) -> void:
	var pts := D.loop_points()
	var segs := []
	var total := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var l := a.distance_to(b)
		segs.append({"a": a, "d": (b - a) / maxf(l, 0.001), "l": l})
		total += l

	var n := g.units.size()
	for i in n:
		var want := total * float(i) / float(maxi(n, 1))
		var acc := 0.0
		for s in segs:
			if want <= acc + float(s["l"]):
				var dir: Vector3 = s["d"]
				var side := Vector3(-dir.z, 0.0, dir.x) * (2.4 if (i % 2) == 0 else -2.4)
				var p: Vector3 = (s["a"] as Vector3) + dir * (want - acc) + side
				p.x = clampf(p.x, 1.5, D.ARENA.x - 1.5)
				p.z = clampf(p.z, 1.5, D.ARENA.y - 1.5)
				g.units[i]["p"] = p
				break
			acc += float(s["l"])


func _dps(g: Game) -> float:
	var s := 0.0
	for un in g.units:
		s += D.dps(U.UNITS[int(un["ui"])])
	return s


func _top_grade(g: Game) -> String:
	var best := 0
	for un in g.units:
		best = maxi(best, int(U.UNITS[int(un["ui"])]["g"]))
	return U.GRADE[best]
