extends SceneTree
## 비술난무 검산 — 창 없이 계산 쪽(MsWorld · MsCmd · MsD)만 돌린다.
##   godot --headless --path . --script res://tools/mystic_check.gd -- [판 수]
## [1] 커맨드 판독 — 다섯 기술이 다 읽히고 서로 오인되지 않는가, 창(CMD_WINDOW)을 넘기면 안 읽히는가.
## [2] 봇 주행 — 봇이 세 스테이지를 끝까지 가는가. 끝나지 않는 구간(적이 안 나오거나 안 죽는 상태)이 없는가.
## 실패하면 종료 코드 1.

var fails := 0


func _init() -> void:
	var runs := 6
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
	_cmd_test()
	_bot_test(runs)
	print("MYSTIC CHECK %s" % ("OK" if fails == 0 else "FAIL %d" % fails))
	quit(1 if fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  실패: ", what)


func _seq(c: MsCmd, keys: String, facing: int, gap: float = 0.05) -> void:
	for ch in keys:
		c.dir(ch, facing)
		c.tick(gap)


func _cmd_test() -> void:
	print("[1] 커맨드 판독")
	var cases := [
		["RLR", 1, false, "dash"], ["LRL", -1, false, "dash"], ["UU", 1, false, "rise"],
		["DR", 1, false, "wave"], ["DL", -1, false, "wave"], ["DD", 1, false, "stomp"], ["DD", 1, true, "dive"],
		["R", 1, false, ""], ["RL", 1, false, ""], ["U", 1, false, ""], ["DL", 1, false, ""], ["LRL", 1, false, ""],
	]
	for cs in cases:
		var c := MsCmd.new()
		_seq(c, cs[0], cs[1])
		var got := c.read(cs[2])
		_ok(got == cs[3], "%s(향 %d, 공중 %s) → %s, 기대 %s" % [cs[0], cs[1], cs[2], got, cs[3]])
	# 너무 느리게 넣으면 안 읽힌다
	var slow := MsCmd.new()
	_seq(slow, "DR", 1, 0.3)
	slow.tick(0.2)
	_ok(slow.read(false) == "", "느린 아래 앞 이 장풍으로 읽힘")
	# 판독한 뒤에는 버퍼가 비어 같은 커맨드가 두 번 안 나간다
	var twice := MsCmd.new()
	_seq(twice, "UU", 1)
	twice.read(false)
	_ok(twice.read(false) == "", "같은 커맨드가 두 번 나감")
	print("    %d 경우 확인" % (cases.size() + 2))


func _bot_test(runs: int) -> void:
	print("[2] 봇 주행 %d판" % runs)
	var dt := 1.0 / 60.0
	var cleared := 0
	var deaths := 0
	var times: Array = []
	var combos: Array = []
	var skills := {}
	for r in runs:
		var w := MsWorld.new(0, 7000 + r)
		var total := 0.0
		var stuck := false
		for st in MsD.STAGES.size():
			if st > 0:
				w.start_stage(st)
			var tt := 0.0
			while w.state == "play" and tt < 360.0:
				w.bot(dt)
				w.step(dt)
				for e in w.ev:
					if e.has("flash"):
						skills[e.flash] = skills.get(e.flash, 0) + 1
				w.ev.clear()
				tt += dt
			total += tt
			if w.state == "over":
				deaths += 1
				print("    %d판: 스테이지 %d 구간 %d 에서 쓰러짐(%.0f초)" % [r + 1, st + 1, w.sec + 1, tt])
				break
			if tt >= 360.0:
				stuck = true
				print("    %d판: 스테이지 %d 구간 %d 에서 6분 넘게 안 끝남 · 남은 적 %d · 웨이브 %d · go %s" % [r + 1, st + 1, w.sec + 1, w.alive(), w.wave, w.go])
				break
		_ok(not stuck, "%d판 끝나지 않는 구간" % (r + 1))
		if w.state == "win":
			cleared += 1
			times.append(total)
		combos.append(w.max_combo)
	print("    끝까지 %d / %d · 쓰러짐 %d · 걸린 시간 %s초 · 최고 콤보 %s" % [cleared, runs, deaths, str(times.map(func(x): return int(x))), str(combos)])
	print("    봇이 쓴 기술 %s" % str(skills))
