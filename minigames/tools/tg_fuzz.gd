extends SceneTree
## 떡 하나 마구잡이 검사 — 아무렇게나 누르는 손으로 세 속도 · 여러 판을 달려 멈춤 · 이상한 높이 · 물건 폭증 · 스크립트 오류를 찾는다.
##   godot --headless --path . --script res://tools/tg_fuzz.gd
func _init() -> void:
	var bad := 0
	var worst_ms := 0.0
	var worst_items := 0
	for pace in 3:
		TgGame.pace_lv = pace
		for s in 10:
			var rng := RandomNumberGenerator.new()
			rng.seed = 77 + s + pace * 100
			var g := TgGame.new([0, 3, 7, 12][s % 4], 4000 + s + pace * 50)
			var mode := s % 3   # 0 마구 누르기 · 1 봇 + 가끔 딴짓 · 2 아무것도 안 함
			var stall := 0.0
			var last := g.dist
			var heavens := 0
			var falls := 0
			var n := 0
			while n < 60 * 150:
				g.oil = 100.0
				if mode == 0:
					if rng.randf() < 0.08: g.jump()
					g.slide(rng.randf() < 0.1)
					g.fly_held = rng.randf() < 0.5
					if rng.randf() < 0.01: g.awaken()
				elif mode == 1:
					g.bot(0.03, 0.15)
					if rng.randf() < 0.01: g.jump()
				var t0 := Time.get_ticks_usec()
				g.step(1.0 / 60.0)
				worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - t0) / 1000.0)
				worst_items = maxi(worst_items, g.items.size())
				for e in g.events:
					if e.kind == "item" and e.get("item", "") == "goldrope": heavens += 1
					if e.kind == "pit": falls += 1
				g.events.clear()
				if g.dist - last < 0.01 and g.cine_t <= 0.0:
					stall += 1.0 / 60.0
				else:
					stall = 0.0
				last = g.dist
				if stall > 2.5 or is_nan(g.fox_y) or g.fox_y < -400.0 or g.fox_y > 1300.0 or g.over:
					printerr("이상: pace %d seed %d mode %d  t %.1f  dist %d  y %.0f  stall %.1f  over %s  pit_fall %s rescue %s heaven %s" % [pace, s, mode, n / 60.0, int(g.dist), g.fox_y, stall, g.over, g.pit_fall, g.rescue, g.heaven])
					bad += 1
					break
				n += 1
			print("pace %d seed %d mode %d: zone %d → %d, 하늘나라 %d, 빠짐 %d" % [pace, s, mode, [0, 3, 7, 12][s % 4], g.zone, heavens, falls])
	TgGame.pace_lv = 1
	print("가장 느린 걸음 %.1fms, 물건 최대 %d" % [worst_ms, worst_items])
	print("TG FUZZ OK" if bad == 0 else "TG FUZZ FAIL %d" % bad)
	quit(0 if bad == 0 else 1)
