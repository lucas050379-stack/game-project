extends SceneTree
## 아르카나 컬렉션 검산 — 헤드리스로 봇끼리 수천 판(그리기 없이 AcGame · AcAi 만).
##   godot --headless --path . --script res://tools/arcana_check.gd -- [판 수]
## 볼 것: 인원별 판 길이(라운드) · 선 플레이어 승률 · 이긴 점수 · 영웅 방문 · 성물 단계별로 산 수 · 덱 구성.
## 실패하면 종료 코드 1 — 판이 안 끝나거나(200 라운드) 토큰 수가 어긋나거나(만들어지거나 사라짐) 규칙 위반일 때.


func _init() -> void:
	var games := 1000
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			games = int(a)
	var fail := 0
	# 덱 구성 — 단계 × 점수, 비용 합 범위
	var deck := AcD.deck()
	var by := {}
	for c: Dictionary in deck:
		var key := "%d단계 %d점" % [int(c.tier) + 1, int(c.pts)]
		by[key] = int(by.get(key, 0)) + 1
	print("[덱] %d장  %s" % [deck.size(), str(by)])
	if deck.size() != 90:
		printerr("덱이 90장이 아님")
		fail += 1
	# 성물마다 물건이 달라야 한다 — 같은 색 안에서 겹치면 안 되고, 한 물건은 두 번까지(사용자 요청 11-08)
	var seen := {}
	var used := {}
	for c: Dictionary in deck:
		var key2 := "%d_%s" % [c.col, c.glyph]
		if seen.has(key2):
			printerr("같은 색에 같은 물건: %s" % c.name)
			fail += 1
		seen[key2] = true
		used[c.glyph] = int(used.get(c.glyph, 0)) + 1
		if not AcArt.GLYPH_PARTS.has(c.glyph):
			printerr("그림이 없는 물건: %s" % c.glyph)
			fail += 1
	for gk in used:
		if int(used[gk]) > 2:
			printerr("물건이 세 번 넘게 나옴: %s" % gk)
			fail += 1
	print("  물건 %d종, 카드 이름 예: %s / %s / %s" % [used.size(), deck[0].name, deck[45].name, deck[89].name])
	for t in 3:
		var lo := 99
		var hi := 0
		for c: Dictionary in deck:
			if int(c.tier) == t:
				var s := 0
				for v in c.cost:
					s += int(v)
				lo = mini(lo, s)
				hi = maxi(hi, s)
				if int(c.cost[c.col]) > 0 and t == 0:
					printerr("1단계 성물이 자기 색을 요구함: %s" % c.name)
					fail += 1
		print("  %d단계 비용 합 %d~%d" % [t + 1, lo, hi])
	for np in [2, 3, 4]:
		var rounds: Array = []
		var first := 0
		var seat_win := [0, 0, 0, 0]
		var win_pts: Array = []
		var heroes := 0
		var tiers := [0, 0, 0]
		var reserves := 0
		var passes := 0
		var stuck := 0
		for gi in games:
			var g := AcGame.new(np, gi * 7919 + np, [true, true, true, true])
			var total0 := _total(g)
			var guard := 0
			while not g.over and guard < np * 200:
				AcAi.act(g)
				guard += 1
				if g.last.get("kind", "") == "reserve":
					reserves += 1
				elif g.last.get("kind", "") == "pass":
					passes += 1
				if _total(g) != total0:
					printerr("토큰 수가 바뀜 (%d명 %d판)" % [np, gi])
					fail += 1
					break
				for i in np:
					if g.tokens(i) > AcD.HAND_MAX and not (i == g.cur and g.pending == "discard"):
						printerr("토큰 10개 초과 (%d명 %d판)" % [np, gi])
						fail += 1
			if not g.over:
				stuck += 1
				continue
			rounds.append(g.round_no)
			seat_win[g.winner] += 1
			if g.winner == 0:
				first += 1
			win_pts.append(g.points(g.winner))
			for i in np:
				heroes += g.players[i].heroes.size()
				for c: Dictionary in g.players[i].cards:
					tiers[c.tier] += 1
		if stuck > 0:
			printerr("%d명: 안 끝난 판 %d" % [np, stuck])
			fail += 1
		var done := maxi(1, rounds.size())
		rounds.sort()
		win_pts.sort()
		var seats := []
		for i in np:
			seats.append("%d%%" % roundi(100.0 * seat_win[i] / done))
		print("[%d명] 라운드 중앙 %d (%d~%d)  자리별 승률 %s  이긴 점수 중앙 %d  영웅 %.1f/판  성물 단계별 %.1f/%.1f/%.1f  봉인 %.1f  넘김 %.2f" % [
				np, rounds[rounds.size() / 2], rounds[0], rounds[-1], " ".join(seats), win_pts[win_pts.size() / 2],
				float(heroes) / done, float(tiers[0]) / done, float(tiers[1]) / done, float(tiers[2]) / done,
				float(reserves) / done, float(passes) / done])
	print("ARCANA CHECK %s" % ("OK" if fail == 0 else "FAIL %d" % fail))
	quit(1 if fail > 0 else 0)


static func _total(g: AcGame) -> int:
	var s := 0
	for v in g.bank:
		s += int(v)
	for p: Dictionary in g.players:
		for v in p.tok:
			s += int(v)
	return s
