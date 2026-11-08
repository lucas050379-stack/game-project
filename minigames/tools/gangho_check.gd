extends SceneTree
## 강호일생 검산 — 헤드리스로 수천 명을 태어나게 해서 분포를 본다(그리기 없이 GhRun · GhLife 만).
##   godot --headless --path . --script res://tools/gangho_check.gd -- [명수] [--show]
## 볼 것: 평균 수명(50 안팎) · 다섯 살 전에 죽는 비율 · 무공을 배우는 비율 · 경지 분포 ·
##        한 인생의 갈림길 수(6~12) · 한 인생의 연대기 줄 수 · 칭호 종류 · 글자 자리가 안 채워진 줄.
## 실패하면 종료 코드 1 — 글자 자리(`{`)가 남았거나 Jua 에 없는 기호가 있거나 갈림길이 끝없이 이어질 때.

const BAD_GLYPHS := ["·", "—", "×", "→", "←", "…", "「", "」"]


func _init() -> void:
	var n := 3000
	var show := false
	for a in OS.get_cmdline_user_args():
		if a == "--show":
			show = true
		elif a.is_valid_int():
			n = int(a)
	var ages: Array = []
	var infant := 0
	var mart := 0
	var realms := {}
	var choices: Array = []
	var nlines: Array = []
	var titles := {}
	var causes := {}
	var classes := {}
	var bad := 0
	var stuck := 0
	var married := 0
	var peer_lines := 0
	var sides := {}
	var debts := 0
	var mart_passive := 0
	var gold_m: Array = []
	var gold_c: Array = []
	var jobs := {}
	var quals_n := 0
	var degs := {}
	var biz_bad := 0
	var moves := 0
	var move_from := {}
	var course_dup := 0
	var rides_n := {}
	var officials := 0
	var clan_bad := 0
	var inh := 0
	var heads := 0
	var wl := {}
	var wranks := {}
	var realms_p := {}
	var aliases: Array = []
	var worth_p: Array = []
	var worth_a: Array = []
	var poor_n := 0
	var tops := {}
	var arts_n := 0
	var moments := 0
	var sect_job := {}
	var credit_n := 0
	var credit_ex: Array = []
	var risk_seen := {}
	var ruined := 0
	for i in n:
		var run := GhRun.new(1000 + i)
		run.me.ai_plan = true
		var guard := 0
		var ch := 0
		while not run.done() and guard < 200:
			if i % 2 == 0 and run.me.alive:
				# 절반은 "적극적인 사람" — 해마다 행동 하나 · 가끔 습관을 켜고 끈다(그 경로가 실제로 돌게)
				var acts: Array = GhD.ACTIONS.filter(func(a): return run.me.act_block(a.id) == "")
				if not acts.is_empty():
					run.me.act(String(acts[(guard * 7 + i) % acts.size()].id))
				if guard % 9 == 0:
					var h: String = GhD.HABITS[(guard + i) % GhD.HABITS.size()].id
					if run.me.habits.has(h) or run.me.habit_ok(h):
						run.me.toggle_habit(h)
				debts += 1 if run.me.debt > 0 else 0
				if run.me.age >= 18 and guard % 3 == 0:
					run.me.invest(["deposit", "caravan", "mine"][guard % 3], 100)
					var bk: String = run.me.my_biz_key()
					if bk != "" and run.me.biz_block(bk) == "":
						run.me.biz_click(bk)
					for h in GhD.HOUSES:
						if run.me.house_block(h.id) == "" and not run.me.houses.has(h.id):
							run.me.house_click(h.id)
							break
					var rd: Dictionary = GhD.RIDES[(guard / 3 + i) % GhD.RIDES.size()]
					if not run.me.rides.has(rd.id) and run.me.ride_block(rd.id) == "":
						run.me.ride_click(rd.id)
				if guard % 7 == 0:
					run.me.item_click(String(GhD.ITEMS[(guard / 7 + i) % GhD.ITEMS.size()].id))
				if guard % 5 == 0:
					for j in ["laborer", "teacher", "constable", "doctor", "smith", "painter"]:
						if run.me.job_block(j) == "":
							run.me.set_job(j)
							break
				if run.me.course == "" and guard % 4 == 0:
					var cs: Array = GhD.COURSES.filter(func(c): return run.me.course_block(c.id) == "")
					if not cs.is_empty():
						run.me.start_course(String(cs[(guard + i) % cs.size()].id))
			while run.waiting():
				ch += 1
				run.me.choose(run.me.auto_index())
			run.step()
			while run.waiting():
				ch += 1
				run.me.choose(run.me.auto_index())
			guard += 1
		if guard >= 200:
			stuck += 1
		var me := run.me
		ages.append(me.age)
		if me.age < 5:
			infant += 1
		if i % 2 == 1 and me.martial:
			mart_passive += 1
		if me.age >= 40:
			var worth := me.gold + me.assets_value() - me.debt
			(worth_p if i % 2 == 1 else worth_a).append(worth)
			if int(me.flags.get("poor_years", 0)) >= 5:
				poor_n += 1
			if me.martial:
				gold_m.append(me.gold)
			else:
				gold_c.append(me.gold)
		if me.martial:
			mart += 1
			arts_n += me.arts_known.size()
			sides[me.side] = sides.get(me.side, 0) + 1
		realms[me.realm] = realms.get(me.realm, 0) + 1
		if i % 2 == 1:
			realms_p[me.realm] = realms_p.get(me.realm, 0) + 1
		if me.alias != "":
			aliases.append(me.alias)
		choices.append(ch)
		moments += me.moments.size()
		for k in me.seen:
			if String(k).begins_with("rk_"):
				risk_seen[k] = int(risk_seen.get(k, 0)) + 1
		for e in me.lines:
			if String(e.txt).find("통째로 넘어갔다") >= 0:
				ruined += 1
		if me.flags.has("career_credit"):
			credit_n += 1
			for e in me.lines:
				if credit_ex.size() < 4 and String(e.txt).find("인정받아") >= 0:
					credit_ex.append(String(e.txt))
		if me.job != "" and me.martial and me.sect_id != "" and not me.flags.has("quit") and not me.flags.has("retired"):
			sect_job[me.job] = int(sect_job.get(me.job, 0)) + 1
		if me.job != "":
			jobs[me.job] = jobs.get(me.job, 0) + 1
		quals_n += me.quals.size()
		degs[me.degree] = int(degs.get(me.degree, 0)) + 1
		if me.biz.keys().any(func(k): return k != me.work_key()):
			biz_bad += 1
		for li in me.lines.size():
			if String(me.lines[li].txt).begins_with("살던 고을을 떠나"):
				moves += 1
				var pv := String(me.lines[li - 1].txt).substr(0, 22) if li > 0 else ""
				move_from[pv] = int(move_from.get(pv, 0)) + 1
		var starts := {}
		for ln: Dictionary in me.lines:
			var tx := String(ln.txt)
			if tx.ends_with(" 시작했다."):
				starts[tx] = int(starts.get(tx, 0)) + 1
		for k in starts:
			if int(starts[k]) > 1:
				course_dup += 1
				break
		officials += 1 if me.flags.has("official") else 0
		for rk in me.rides:
			rides_n[rk] = int(rides_n.get(rk, 0)) + 1
		if me.cls == "clan" and not (GhD.CLAN_AT.get(me.birth_region, []) as Array).has(me.clan_id):
			clan_bad += 1
		if me.inherited and me.heir and me.estate > 0:
			inh += 1
		if me.flags.has("house_head"):
			heads += 1
		wl[me.wealth] = wl.get(me.wealth, 0) + 1
		if me.work_key() != "" and me.age >= 40:
			var wr := me.work_rank_now()
			if i % 2 == 1:
				wranks[wr] = wranks.get(wr, 0) + 1
			if wr >= me.work_max() and me.work_max() >= 2:
				tops[me.work_title()] = tops.get(me.work_title(), 0) + 1
		nlines.append(me.lines.size())
		titles[me.title()] = titles.get(me.title(), 0) + 1
		causes[me.cause] = causes.get(me.cause, 0) + 1
		classes[me.cls] = classes.get(me.cls, 0) + 1
		if me.flags.has("married") or me.flags.has("widowed"):
			married += 1
		for e in me.lines:
			var t: String = e.txt
			if e.kind == "peer":
				peer_lines += 1
			if t.find("{") >= 0 or t.find("}") >= 0 or BAD_GLYPHS.any(func(g): return t.find(g) >= 0):
				bad += 1
				if bad <= 8:
					printerr("BAD LINE: ", t)
		if show and i < 3:
			print("---- ", me.name, " (", me.cls_name(), ", ", me.region_name(), ") ", me.title())
			for e in me.lines:
				print("  %3d  %-6s %s" % [e.age, e.kind, e.txt])
			for p in run.peers:
				print("   동년배 ", p.name, " ", p.cls_name(), " ", p.age if not p.alive else -1)
	ages.sort()
	var sum := 0
	for a in ages:
		sum += a
	print("인생 %d번" % n)
	print("평균 수명 %.1f  중앙값 %d  다섯 살 전 사망 %.1f%%  80세 넘김 %.1f%%" % [float(sum) / n, ages[n / 2],
			100.0 * infant / n, 100.0 * ages.filter(func(a): return a >= 80).size() / n])
	print("무공을 배움 %.1f%%   혼인 %.1f%%   동년배 관련 줄 %.2f/인생" % [100.0 * mart / n, 100.0 * married / n, float(peer_lines) / n])
	var rl := ""
	for r in GhD.REALMS.size():
		rl += "%s %.2f%%  " % [GhD.REALMS[r], 100.0 * realms.get(r, 0) / n]
	print("경지  ", rl)
	print("무림인의 쪽  ", sides)
	print("가만히 사는 절반의 경지  ", realms_p)
	print("별호 %d명 (%.1f%%) 예: %s" % [aliases.size(), 100.0 * aliases.size() / n, ", ".join(aliases.slice(0, 12))])
	gold_m.sort()
	gold_c.sort()
	print("가만히 사는 절반의 무공 %.1f%%   마흔 넘어 죽을 때 재물 중앙값  무림인 %d냥 · 평민 %d냥" % [100.0 * mart_passive / (n / 2.0), gold_m[gold_m.size() / 2] if gold_m.size() > 0 else 0, gold_c[gold_c.size() / 2] if gold_c.size() > 0 else 0])
	print("가만히 사는 절반, 마흔 넘긴 이의 직업 단(0부터)  %s   꼭대기 단  %s" % [wranks, tops])
	for pair in [["가만히", worth_p], ["적극적", worth_a]]:
		var w: Array = pair[1]
		w.sort()
		if w.size() > 10:
			var q := func(f): return w[int(w.size() * f)]
			print("마흔 넘어 죽을 때 재산(%s)  10%% %d · 25%% %d · 중앙 %d · 75%% %d · 90%% %d · 맨 위 %d   빈털터리(30냥 미만) %.0f%%" % [pair[0], q.call(0.1), q.call(0.25), q.call(0.5), q.call(0.75), q.call(0.9), w.back(), 100.0 * w.filter(func(x): return x < 30).size() / w.size()])
	print("가난한 해가 다섯 해 넘은 사람 %.1f%%" % (100.0 * poor_n / n))
	print("가세 분포 %s   가산을 물려받은 장자 %.1f%%   가주가 된 세가 · 속가 장자 %d   본거지 밖 세가 %d" % [wl, 100.0 * inh / n, heads, clan_bad])
	print("배움 마친 수 %.2f/인생   전직  %s" % [float(quals_n) / n, jobs])
	print("과거 급(0 없음 1 수재 2 거인 3 진사)  %s   벼슬 %.1f%%   죽을 때 가진 탈것  %s" % [degs, officials * 100.0 / n, rides_n])
	print("무림인 한 명이 익힌 무공 %.1f개   전환점 삽화 %.2f번/인생   빚진 해(적극적인 절반) %.1f해/인생" % [float(arts_n) / maxi(1, mart), float(moments) / n, float(debts) / (n / 2.0)])
	choices.sort()
	nlines.sort()
	print("갈림길 중앙값 %d (10%% %d · 90%% %d)   연대기 줄 중앙값 %d" % [choices[n / 2], choices[n / 10], choices[n * 9 / 10], nlines[n / 2]])
	var tk := titles.keys()
	tk.sort_custom(func(a, b): return titles[a] > titles[b])
	print("칭호 %d종:" % tk.size())
	for k in tk.slice(0, 22):
		print("   %5.1f%%  %s" % [100.0 * titles[k] / n, k])
	var ck := causes.keys()
	ck.sort_custom(func(a, b): return causes[a] > causes[b])
	var cl := ""
	for k in ck.slice(0, 14):
		cl += "%s %.1f%%  " % [k, 100.0 * causes[k] / n]
	print("사인  ", cl)
	var kk := classes.keys()
	kk.sort_custom(func(a, b): return classes[a] > classes[b])
	var ks := ""
	for k in kk:
		ks += "%s %.1f%%  " % [GhD.cls(k).name, 100.0 * classes[k] / n]
	print("집안  ", ks)
	var fail := bad > 0 or stuck > 0 or clan_bad > 0 or biz_bad > 0
	print("문파에 몸담은 채 직업도 가진 인생 %s" % sect_job)
	print("이직 경력을 인정받은 인생 %d (%.1f%%)  예: %s" % [credit_n, 100.0 * credit_n / n, credit_ex])
	print("인생의 갈림길(본 인생 수) %s   무리한 확장으로 파산 %d" % [risk_seen, ruined])
	print("글자 자리 남은 줄 %d   끝나지 않은 인생 %d" % [bad, stuck])
	var mf: Array = move_from.keys()
	mf.sort_custom(func(a, b): return move_from[a] > move_from[b])
	print("고을을 옮긴 횟수 %.2f/인생   앞 줄(많은 순) %s" % [float(moves) / n, mf.slice(0, 8).map(func(k): return "%s(%d)" % [k, move_from[k]])])
	print("사업과 하는 일이 어긋난 채 죽은 인생 %d   같은 배움을 두 번 시작한 인생 %d (그만뒀다 다시 한 것 포함)" % [biz_bad, course_dup])
	print("GANGHO CHECK FAIL" if fail else "GANGHO CHECK OK")
	quit(1 if fail else 0)
