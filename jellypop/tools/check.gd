extends SceneTree

## 판 로직 자체 검사. `check.bat` 이 헤드리스로 돌린다. 실패가 있으면 종료 코드 1.
##   check.bat           전부 (스테이지 봇은 판당 12번)
##   check.bat stages    스테이지 봇만 판당 60번
##   check.bat tune      이동 횟수 제안 — 이동 제한 없이 봇을 돌려 "깨는 데 든 이동 수" 분포를 잰다
##
## 그림을 보면 안 보이는 것들만 잰다 — 처음 판에 맞춰진 줄이 없나, 연쇄가 반드시 끝나나,
## 장애물이 정해진 대로 깨지나, 다 떨어졌는가, 스테이지가 깰 수 있는 판인가.

var fails := 0


func _init() -> void:
	if OS.get_cmdline_user_args().has("tune"):
		# check.bat tune from=61 — 그 번호부터만 잰다(새 묶음을 넣었을 때)
		var from := 1
		var to := 1 << 20
		for a in OS.get_cmdline_user_args():
			if a.begins_with("from="):
				from = int(a.substr(5))
			elif a.begins_with("to="):
				to = int(a.substr(3))
		_tune(40, from, to)
		quit(0)
		return
	var only_stages := OS.get_cmdline_user_args().has("stages")
	if not only_stages:
		_new_boards()
		_patterns()
		_obstacles()
		_combos()
		_devices()
		_devices_b()
		_devices_c()
		_devices_d()
		_random_play()
	_blocks()
	_stages(60 if only_stages else 12)
	print("\n%s" % ("ALL OK" if fails == 0 else "FAILED: %d" % fails))
	quit(1 if fails > 0 else 0)


func _ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("  FAIL ", what)


func _new_boards() -> void:
	print("[1] 새 판 1000개")
	for s in 1000:
		var b := Board.new(s)
		b.fill_new()
		_ok(b.find_groups().is_empty(), "seed %d 처음부터 맞춰진 줄" % s)
		_ok(b.has_move(), "seed %d 둘 수 없음" % s)


## 판을 글자로 깐다. 숫자 = 색, '.' = 아무도 안 맞는 색들이 번갈아,
## B = 쿠키 상자 1겹, C = 초콜릿, L = 사슬 묶인 색 0, I = 얼음 갇힌 색 0, M = 몬스터.
func _board_from(rows: Array) -> Board:
	var b := Board.new(1)
	for y in b.h:
		for x in b.w:
			var ch: String = rows[y][x]
			var i := y * b.w + x
			# 바탕은 (x + 2y) % 3 + 3 — 가로 · 세로 · 네모로 이어지지 않는다
			b.col[i] = 3 + (x + 2 * y) % 3
			match ch:
				".":
					pass
				"B":
					b.col[i] = Board.BOX
					b.lay[i] = 1
				"C":
					b.col[i] = Board.CHOCO
				"L":
					b.col[i] = 0
					b.chain[i] = 1
				"I":
					b.col[i] = 0
					b.ice[i] = 1
				"M":
					b.col[i] = Board.MON
					b.mons[i] = {"kind": "dough", "hp": 4, "max": 4, "every": 3, "cd": 3, "target": PackedInt32Array()}
				_:
					b.col[i] = int(ch)
	return b


func _patterns() -> void:
	print("[2] 특수 젤리 모양")
	var b := _board_from([".......", ".......", "0000...", ".......", ".......", ".......", "......."])
	var r := b.resolve()
	_ok(r.made.size() == 1 and r.made[0].sp == D.SP_LINE_H, "가로 4 → 가로 줄 폭탄 %s" % [r.made])

	b = _board_from(["0......", "0......", "0......", "0......", ".......", ".......", "......."])
	r = b.resolve()
	_ok(r.made.size() == 1 and r.made[0].sp == D.SP_LINE_V, "세로 4 → 세로 줄 폭탄")

	b = _board_from([".......", "00000..", ".......", ".......", ".......", ".......", "......."])
	r = b.resolve(PackedInt32Array([8]))
	_ok(r.made.size() == 1 and r.made[0].sp == D.SP_RAINBOW and r.made[0].i == 8, "5 → 무지개(바꾼 칸에)")

	b = _board_from(["0......", "0......", "000....", ".......", ".......", ".......", "......."])
	r = b.resolve()
	_ok(r.made.size() == 1 and r.made[0].sp == D.SP_AREA and r.made[0].i == 14, "L 자 → 범위 폭탄(꺾인 칸) %s" % [r.made])

	b = _board_from([".......", ".00....", ".00....", ".......", ".......", ".......", "......."])
	r = b.resolve()
	_ok(r.made.size() == 1 and r.made[0].sp == D.SP_FLY and r.cleared.size() == 4, "2×2 → 날개 %s" % [r.made])

	b = _board_from([".......", ".......", ".......", "000....", ".......", ".......", "......."])
	b.sp[21] = D.SP_LINE_H
	r = b.resolve()
	var row_clear := true
	for x in 7:
		if b.col[21 + x] != Board.EMPTY:
			row_clear = false
	_ok(row_clear and r.fired.size() == 1, "가로 줄 폭탄 발동 → 줄 전부")


func _obstacles() -> void:
	print("[3] 장애물")
	# 옆에서 터지면 상자 · 초콜릿이 깨진다
	var b := _board_from([".......", "B......", "000....", "C......", ".......", ".......", "......."])
	var r := b.resolve()
	_ok(b.col[7] == Board.EMPTY and b.col[21] == Board.EMPTY, "옆 매치로 상자 · 초콜릿 깨짐")
	_ok(r.events.size() == 2, "장애물 사건 2개 %s" % [r.events])

	# 얼음 갇힌 젤리는 매치가 안 된다
	b = _board_from([".......", ".......", "00I....", ".......", ".......", ".......", "......."])
	_ok(b.find_groups().is_empty(), "얼음 젤리는 줄에 안 낀다")
	_ok(not b.movable(16), "얼음 젤리는 못 움직인다")

	# 사슬 묶인 젤리는 매치는 되지만 터지지 않고 사슬만 풀린다
	b = _board_from([".......", ".......", "00L....", ".......", ".......", ".......", "......."])
	r = b.resolve()
	_ok(b.col[16] == 0 and b.chain[16] == 0 and b.col[14] == Board.EMPTY, "사슬 매치 → 사슬만 풀림")

	# 설탕막
	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.sugar[14] = 2
	b.resolve()
	_ok(b.sugar[14] == 1, "설탕막 한 겹")

	# 몬스터: 옆에서 3개 터지면 3, 4칸 체력이면 하나 남음 → 줄 폭탄으로 마무리
	b = _board_from([".......", "...M...", "..000..", ".......", ".......", ".......", "......."])
	r = b.resolve()
	_ok(b.mons.has(10) and b.mons[10].hp == 3, "몬스터 옆 매치 → 터진 이웃 수만큼 (%s)" % [b.mons.get(10)])
	b.col[8] = 1
	b.sp[8] = D.SP_LINE_H
	r = b.resolve(PackedInt32Array(), PackedInt32Array([8]))
	_ok(not b.mons.has(10) and b.col[10] == Board.EMPTY, "줄 폭탄 → 몬스터 쓰러짐")

	# 몬스터 차례: 한 턴 전에 노릴 칸이 정해지고, 그다음 턴에 그 칸이 상자가 된다
	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].cd = 2
	b.monster_turn()
	var tg: PackedInt32Array = b.mons[10].target
	_ok(tg.size() == 1, "꾸덕이가 노릴 칸을 미리 정함")
	b.monster_turn()
	_ok(tg.size() == 1 and b.col[tg[0]] == Board.BOX, "정한 칸이 상자가 됨")

	# 초콜릿 번짐
	b = _board_from([".......", ".......", "...C...", ".......", ".......", ".......", "......."])
	var t := b.choco_spread()
	_ok(t >= 0 and b.col[t] == Board.CHOCO and b.adjacent(t, 17), "초콜릿이 옆으로 번짐")

	# 상자 밑도 대각선으로 메워진다
	b = _board_from([".......", ".......", "...B...", ".......", ".......", ".......", "......."])
	for k in [24, 31, 38, 45]:
		b.col[k] = Board.EMPTY
	b.fall()
	var empty := 0
	for i in 49:
		if b.col[i] == Board.EMPTY:
			empty += 1
	_ok(empty == 0, "상자 밑 빈 칸이 대각선으로 메워짐 (빈 칸 %d)" % empty)


## 장치 검사용 판 — 예전 41~57번 지도를 그대로 옮겨 적었다. 스테이지는 생성기가 만들어 번호마다
## 지도가 바뀌므로, 좌표를 박아 둔 검사가 실제 스테이지를 열면 생성기를 고칠 때마다 깨진다.
func _dev(kind: String) -> Dictionary:
	var E := "........"
	var B8 := [E, E, E, E, E, E, E, E]
	var st := {"id": 900, "moves": 30, "goals": [], "colors": 5, "rows": B8}
	match kind:
		"belt":
			st.belt = [E, ".>>>>>v.", ".^....v.", ".^....v.", ".^....v.", ".^....v.", ".^<<<<<.", E]
		"portal":
			st.rows = ["....####", "....####", "....####", "....####", "####....", "####....", "####....", "####...."]
			st.portal = [E, E, E, "abcd....", "....ABCD", E, E, E]
		"gear":
			st.rows = [E, ".2....2.", "..2..2..", "...G....", "..2..2..", E, ".2.22.2.", E]
		"push":
			st.rows = [E, E, E, ">.......", E, E, E, E]
		"wind":
			st.rows = [E, E, "...W....", E, "c..c.c.c", ".cc..cc.", "cc.cc.cc", E]
		"thief":
			st.rows = [E, "...T....", E, ".2....2.", ".2....2.", E, "..2222..", E]
			st.moves = 24
		"palette":
			st.palette = [0, 1, 2, 3, 4, 6]
			st.colors = 6
	return st


## 묶음 A 장치 — 검사용 판을 열어 장치 하나씩 돌려 본다.
func _devices() -> void:
	print("[4a] 장치 (벨트 · 포탈 · 톱니 · 푸시 상자 · 바람개비 · 슬쩍이 · 색 고르기)")
	var p := Play.new(_dev("belt"), 1)          # 둘레 벨트
	var b := p.b
	var before := b.col.duplicate()
	b.perm_begin()
	b.belts_step()
	var ok := true
	for i in b.w * b.h:
		if b.belt[i] > 0 and b.col[b.belt_next(i)] != before[i]:
			ok = false
	_ok(ok and b.perm_end().size() == 20, "벨트 — 고리 20칸이 한 칸씩 돈다")

	p = Play.new(_dev("portal"), 2)        # 포탈로 나뉜 판
	b = p.b
	var ex := 4 * 8 + 4
	_ok(b.portal.has(ex) and b.feed(ex) == 3 * 8 + 0, "포탈 — 출구는 짝 입구에서 받는다")
	for i in [ex, ex + 8, ex + 16, ex + 24]:
		b.col[i] = Board.EMPTY
	var f := b.fall()
	var empt := 0
	for i in b.w * b.h:
		if not b.hole[i] and b.col[i] == Board.EMPTY:
			empt += 1
	_ok(empt == 0 and f.spawns.size() == 4, "포탈 — 아래 덩어리가 위 덩어리에서 채워진다 (%d)" % f.spawns.size())

	p = Play.new(_dev("gear"), 3)          # 톱니
	b = p.b
	var g: int = b.gear_dir.keys()[0]
	var ring := []
	for d in Board.RING:
		var i: int = (b.cy(g) + d.y) * b.w + b.cx(g) + d.x
		if b.movable(i):
			ring.append(i)
	var vals := []
	for i in ring:
		vals.append(b.col[i])
	b.gears_step()
	var rot := true
	for k in ring.size():
		if b.col[ring[(k + 1) % ring.size()]] != vals[k]:
			rot = false
	_ok(rot, "톱니 — 움직일 수 있는 둘레 조각이 한 칸씩 돈다")

	p = Play.new(_dev("push"), 4)          # 푸시 상자 (0,3) → 오른쪽
	b = p.b
	var row := []
	for x in 8:
		row.append(b.col[3 * 8 + x])
	b.push_step()
	_ok(b.col[3 * 8 + 1] == Board.PUSH and b.col[3 * 8 + 2] == row[1] and b.col[3 * 8] == row[7] 			and b.count(Board.PUSH) == 1, "푸시 상자 — 한 칸 나아가며 줄을 민다")

	p = Play.new(_dev("wind"), 5)          # 바람개비
	b = p.b
	var w: int = b.cells_of(Board.WIND)[0]
	var counts := PackedInt32Array()
	counts.resize(Board.JELLY_N)
	for i in b.w * b.h:
		if b.plain(i):
			counts[b.col[i]] += 1
	b.wind_armed[w] = true
	b.perm_begin()
	b.winds_step()
	var counts2 := PackedInt32Array()
	counts2.resize(Board.JELLY_N)
	for i in b.w * b.h:
		if b.plain(i):
			counts2[b.col[i]] += 1
	_ok(counts == counts2 and b.perm_end().size() > 0, "바람개비 — 둘레 젤리를 섞되 색 수는 그대로")

	p = Play.new(_dev("thief"), 6)         # 슬쩍이
	var m0 := p.moves_left
	for _k in 3:
		p.turn_end()
	_ok(p.moves_left == m0 - 1, "슬쩍이 — 세 턴에 이동 하나를 훔친다 (%d → %d)" % [m0, p.moves_left])
	var tc: int = p.b.mons.keys()[0]
	p.b.mons[tc].hp = 1
	# 몬스터 옆 젤리 칸 하나를 줄 폭탄으로 — 판 모양 때문에 어느 쪽이 구멍일지 모른다
	var nb := -1
	for n in p.b.n4(tc):
		if p.b.is_jelly(n):
			nb = n
	p.b.sp[nb] = D.SP_LINE_H if p.b.cy(nb) == p.b.cy(tc) else D.SP_LINE_V
	p._step(PackedInt32Array(), PackedInt32Array([nb]), {}, {})
	_ok(p.b.mons.is_empty() and p.moves_left == m0, "슬쩍이 — 쓰러뜨리면 훔친 이동을 돌려받는다")

	p = Play.new(_dev("palette"), 7)       # 복숭아가 나오는 판
	var seen := {}
	for i in p.b.w * p.b.h:
		if p.b.is_jelly(i):
			seen[p.b.col[i]] = true
	_ok(seen.has(6) and not seen.has(5), "색 고르기 — 고른 색만 나온다 %s" % [seen.keys()])


## 묶음 B — 광선(자기장 · 파이프) · 캡슐 · 레이저 · 로켓 · 얼음뿔. 손으로 깐 판에서 하나씩.
func _devices_b() -> void:
	print("[4b] 광선 · 캡슐 · 레이저 · 로켓 · 얼음뿔")
	var b := _board_from([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	b.field[3 * 7 + 5] = 1
	var r := b.ray(3 * 7 + 1, Vector2i.RIGHT)
	_ok(r == PackedInt32Array([23, 24, 25]), "자기장 — 광선이 그 앞에서 멈춘다 %s" % [r])
	b.field[3 * 7 + 5] = 0
	b.pipe[3 * 7 + 4] = 1   # ┐ — 오른쪽으로 오던 광선이 아래로
	b.hole[3 * 7 + 4] = true   # 파이프는 칸을 차지한다 — 광선은 그 칸을 치지 않고 꺾이기만 한다
	r = b.ray(3 * 7 + 1, Vector2i.RIGHT)
	_ok(r == PackedInt32Array([23, 24, 32, 39, 46]), "파이프 — 오른쪽 광선이 ┐ 에서 아래로 꺾인다 %s" % [r])

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.col[21] = Board.CAPSULE
	b.resolve()
	_ok(b.col[21] == Board.CAPSULE, "캡슐 — 옆에서 터져도 안 깨진다")
	b.col[22] = 1
	b.sp[22] = D.SP_LINE_H
	var rr := b.resolve(PackedInt32Array(), PackedInt32Array([22]))
	_ok(b.col[21] == Board.EMPTY, "캡슐 — 줄 폭탄에 깨진다")

	b = _board_from([".......", ".......", "000....", "Z......", ".......", ".......", "......."])
	b.col[21] = Board.LASER
	b.dev_dir[21] = Vector2i.RIGHT
	b.charge[21] = 2
	b.resolve()
	_ok(b.armed.has(21), "레이저 — 세 번째로 옆에서 터지면 장전된다")
	var shot := b.fire_step()
	_ok(shot.cells.size() == 6 and b.charge[21] == 0 and b.col[21] == Board.LASER, "레이저 — 턴 끝에 오른쪽 여섯 칸을 쏘고 남는다")

	b = _board_from([".......", ".......", "111....", "R......", ".......", ".......", "......."])
	b.col[21] = Board.ROCKET
	b.dev_dir[21] = Vector2i.RIGHT
	b.dev_color[21] = 0
	b.resolve()
	_ok(not b.armed.has(21), "로켓 — 다른 색이 옆에서 맞으면 그대로")
	b.col[14] = 0
	b.col[15] = 0
	b.col[16] = 0
	b.resolve()
	_ok(b.armed.has(21), "로켓 — 자기 색이 옆에서 맞으면 장전")
	shot = b.fire_step()
	_ok(b.col[21] == Board.EMPTY and shot.cells.has(21), "로켓 — 쏘면 사라지고 제 칸도 메워진다")

	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].kind = "frost"
	b.mons[10].cd = 2
	b.monster_turn()
	var tg: PackedInt32Array = b.mons[10].target
	b.monster_turn()
	_ok(tg.size() == 1 and b.ice[tg[0]] == 1, "얼음뿔 — 노린 칸을 얼린다")


## 묶음 C — 자물쇠 · 색 설탕막 · 유리 · 선물 · 구름 · 증기 · 주사위 · 그림자 · 먹보.
func _devices_c() -> void:
	print("[4c] 자물쇠 · 색 설탕막 · 유리 · 선물 · 구름 · 증기 · 주사위 · 그림자 · 먹보")
	var b := _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.col[48] = Board.LOCK
	b.lock_c[48] = 0
	b.lock_n[48] = 3
	b.resolve()
	_ok(b.col[48] == Board.EMPTY, "자물쇠 — 그 색 셋이 판 어디서든 터지면 열린다")

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.csugar[14] = 2   # 색 1 만 벗긴다
	b.csugar[15] = 1   # 색 0 이 벗긴다
	b.resolve()
	_ok(b.csugar[14] == 2 and b.csugar[15] == 0, "색 설탕막 — 그 색 젤리로만 벗겨진다")

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.glass[21] = 1
	b.sp[21] = D.SP_LINE_H
	_ok(not b.movable(21), "유리 상자 — 안의 젤리는 못 움직인다")
	b.resolve()
	_ok(b.glass[21] == 0 and b.sp[21] == D.SP_LINE_H and b.is_jelly(21), "유리 상자 — 옆에서 터지면 깨지고 안의 특수 젤리는 남는다")

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.col[21] = Board.GIFT
	var r := b.resolve()
	var opened := false
	for e in r.events:
		if e.type == "gift":
			opened = true
	_ok(opened and b.col[21] != Board.GIFT, "선물 상자 — 옆에서 터지면 열린다")

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.cloud[14] = 1
	b.cloud[21] = 1
	b.resolve()
	_ok(b.cloud[14] == 0 and b.cloud[21] == 1, "구름 — 그 칸이 터지면 걷히고 옆 칸은 그대로")

	b = _board_from([".......", ".......", ".......", "...S...", ".......", ".......", "......."])
	b.col[24] = Board.STEAM
	b.steam_cd[24] = 3
	var puffs := []
	for _k in 3:
		puffs.append_array(b.steam_step())
	_ok(puffs.size() == 1 and b.cloud[puffs[0].to] == 1, "증기 기계 — 세 턴에 구름 하나")

	b = _board_from([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	b.dice[24] = 1
	var changed := false
	for _k in 20:
		var before := b.col[24]
		b.dice_step()
		if b.col[24] != before:
			changed = true
	_ok(changed and b.dice[24] == 1, "주사위 젤리 — 턴마다 색이 바뀐다")

	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].kind = "ninja"
	b.mons[10].cd = 2
	b.monster_turn()
	var tg: PackedInt32Array = b.mons[10].target
	b.monster_turn()
	_ok(tg.size() == 1 and b.col[tg[0]] == Board.DECOY, "그림자 — 노린 젤리를 분신으로 바꾼다")

	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].kind = "glutton"
	b.mons[10].hp = 3
	b.mons[10].max = 10
	b.mons[10].cd = 2
	b.monster_turn()
	tg = b.mons[10].target
	b.monster_turn()
	_ok(b.mons[10].hp == 4 and b.col[tg[0]] == Board.EMPTY, "먹보 — 옆 젤리를 먹고 1 회복")
	b.mons[10].cd = 2
	b.monster_turn()
	tg = b.mons[10].target
	b.sp[tg[0]] = D.SP_AREA
	b.monster_turn()
	_ok(not b.mons.has(10) or b.mons[10].hp < 4, "먹보 — 특수 젤리를 먹으면 다친다")


## 묶음 D — 거미줄 · 끈끈이 식물 · 강철 · 두더지 · 모닥불 · 물감 · 색 그릇 · 솟는 줄 · 문어발 · 대왕꾸덕.
func _devices_d() -> void:
	print("[4d] 거미줄 · 식물 · 강철 · 두더지 · 모닥불 · 물감 · 그릇 · 솟는 줄 · 문어발 · 대왕꾸덕")
	# 강철 칸이 다섯 줄 가운데여도 무지개는 강철 아닌 칸에 생긴다(강철 테 안이 무지개로 바뀌어 보였다)
	var sb := _board_from([".......", ".......", "00000..", ".......", ".......", ".......", "......."])
	sb.steel[16] = 1
	sb.resolve(PackedInt32Array([16]))
	var rb := 0
	for i in sb.w * sb.h:
		if sb.sp[i] == D.SP_RAINBOW:
			rb += 1
	_ok(sb.sp[16] == D.SP_NONE and rb == 1, "강철 — 강철 칸에는 특수 젤리가 안 생긴다")
	# 물감 — 폭탄에 맞은 칸은 칠한 칸과 떨어져 있어도 전부 칠해진다
	var pb := _board_from([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	pb.paint[0] = 1
	pb.sp[3 * 7 + 3] = D.SP_LINE_H
	pb.resolve(PackedInt32Array(), PackedInt32Array([3 * 7 + 3]))
	var row_ok := true
	for x in 7:
		if pb.paint[3 * 7 + x] == 0:
			row_ok = false
	_ok(row_ok and pb.paint[1] == 0, "물감 — 폭탄에 맞은 칸은 전부 칠해진다")
	var b := _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.web[16] = 1
	b.web[30] = 2
	_ok(not b.movable(16) and b.falls(16) and not b.falls(30), "거미줄 — 한 겹은 떨어지고 두 겹은 붙든다")
	b.resolve()
	_ok(b.web[16] == 0 and b.is_jelly(16), "거미줄 — 맞추면 한 겹 풀리고 젤리는 남는다")
	b.web_broken = false
	var t := b.web_spread()
	_ok(t >= 0 and b.web[t] == 1, "거미줄 — 한 턴 동안 못 풀면 번진다")

	b = _board_from([".......", ".......", "000....", "...p...", ".......", ".......", "......."])
	b.col[24] = Board.PLANT
	b.col[17] = 0
	b.resolve()
	var webs := 0
	for i in 49:
		if b.web[i] > 0:
			webs += 1
	_ok(b.col[24] == Board.EMPTY and webs >= 5, "끈끈이 식물 — 건드리면 사라지며 둘레에 거미줄 (%d)" % webs)

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.steel[14] = 1
	b.resolve()
	_ok(b.col[14] == 0 and b.col[15] == Board.EMPTY and not b.movable(14), "강철 — 줄에 끼지만 안 터지고 안 움직인다")
	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	for k in [14, 15, 16]:
		b.steel[k] = 1
	_ok(b.find_groups().is_empty(), "강철 — 강철끼리만 이어진 줄은 맞춤이 아니다")

	b = _board_from([".......", ".......", "000....", "M......", ".......", ".......", "......."])
	b.col[21] = Board.MOLE
	b.mole_hp[21] = 3
	b.resolve()
	_ok(b.mole_hp[21] == 2 and b.mole_hit.has(21), "두더지 — 옆에서 터지면 한 대")
	b.perm_begin()
	b.mole_step()
	_ok(b.col[21] != Board.MOLE and b.count(Board.MOLE) == 1, "두더지 — 맞은 턴 끝에 도망간다")

	b = _board_from([".......", ".......", "000....", "U......", ".......", ".......", "......."])
	b.col[21] = Board.FIRE
	b.fire_t[21] = 0
	b.resolve()
	_ok(b.fire_t[21] == Board.FIRE_LIT, "모닥불 — 옆에서 터지면 켜진다")
	for _k in Board.FIRE_LIT:
		b.camp_step()
	_ok(b.fire_t[21] == 0, "모닥불 — 정해진 턴이 지나면 꺼진다")

	b = _board_from([".......", ".......", "000....", ".......", ".......", ".......", "......."])
	b.paint[21] = 1
	var r := b.resolve()
	_ok(b.paint[14] == 1 and b.paint[16] == 1 and r.painted.size() == 3, "물감 — 칠한 칸에 닿은 덩어리가 칠해진다")

	b = _board_from([".......", ".......", "000....", ".......", "J......", ".......", "J......"])
	b.col[28] = Board.JAR
	b.jar_c[28] = 0
	b.jar_n[28] = 2
	b.col[42] = Board.JAR
	b.jar_c[42] = 0
	b.jar_n[42] = 2
	b.resolve()
	_ok(b.col[28] == Board.EMPTY and b.col[42] == Board.JAR, "색 그릇 — 둘레 두 칸 안의 그 색만 센다")

	b = _board_from([".......", ".......", ".......", ".......", ".......", ".......", "......."])
	b.rise[2] = 1
	var top := b.col[2]
	var second := b.col[9]
	b.perm_begin()
	b.rise_step()
	_ok(b.col[2] == second and b.col[44] == top, "솟는 줄 — 한 칸씩 위로, 맨 위는 맨 아래로")

	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].kind = "octo"
	b.mons[10].cd = 2
	b.monster_turn()
	var tg: PackedInt32Array = b.mons[10].target
	b.monster_turn()
	_ok(tg.size() == 2 and b.web[tg[0]] == 2 and b.web[tg[1]] == 2, "문어발 — 노린 둘을 거미줄 두 겹으로")

	b = _board_from([".......", "...M...", ".......", ".......", ".......", ".......", "......."])
	b.mons[10].kind = "boss"
	b.mons[10].cd = 2
	b.monster_turn()
	tg = b.mons[10].target
	b.monster_turn()
	_ok(b.mons.size() == 2 and b.mons.has(tg[0]), "대왕꾸덕 — 새끼 꾸덕이를 불러낸다")


func _combos() -> void:
	print("[4] 특수끼리 조합")
	var st := Stages.time_attack()
	var p := Play.new(st, 3)
	var b := p.b
	# 가운데 두 칸 — 가장자리면 5×5 가 판 밖으로 잘린다(판 크기가 바뀌어도 맞게)
	var a := (b.h / 2 - 1) * b.w + b.w / 2 - 1
	var c := a + 1
	b.sp[a] = D.SP_LINE_H
	b.sp[c] = D.SP_LINE_V
	var r := p.begin(a, c)
	var cross := true
	for k in b.w:
		if b.col[(a / b.w) * b.w + k] != Board.EMPTY or b.col[k * b.w + c % b.w] != Board.EMPTY:
			cross = false
	_ok(r.combo == "cross" and cross, "줄 + 줄 → 십자 (%s)" % r.get("combo"))

	p = Play.new(st, 4)
	b = p.b
	b.sp[a] = D.SP_AREA
	b.sp[c] = D.SP_AREA
	r = p.begin(a, c)
	_ok(r.combo == "big" and r.cleared.size() >= 25, "범위 + 범위 → 5×5 (%d)" % r.cleared.size())

	p = Play.new(st, 5)
	b = p.b
	b.sp[a] = D.SP_RAINBOW
	b.col[a] = Board.RAINBOW_C
	b.sp[c] = D.SP_LINE_H
	var color := b.col[c]
	r = p.begin(a, c)
	_ok(r.combo == "rainbow_sp" and b.cells_of(color).is_empty() and r.fired.size() >= 3,
			"무지개 + 줄 → 그 색 전부 줄 폭탄으로 (%d 발동)" % r.fired.size())


## 무작위로 수를 두며 연쇄 · 낙하 · 섞기를 끝까지 돌린다(타임 어택 판).
func _random_play() -> void:
	print("[5] 무작위 플레이 200판 × 100수")
	var specials := {}
	for s in 200:
		var p := Play.new(Stages.time_attack(), 10000 + s)
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		for _move in 100:
			var all := p.b.all_moves()
			if all.is_empty():
				_ok(false, "seed %d 둘 수가 없는 판에 멈춤" % s)
				break
			var m: PackedInt32Array = all[rng.randi() % all.size()]
			var r := p.begin(m[0], m[1])
			_ok(r.cleared.size() > 0 or not r.events.is_empty(), "seed %d 유효한 수인데 아무것도 안 터짐" % s)
			for _guard in 80:
				for mk in r.made:
					specials[mk.sp] = int(specials.get(mk.sp, 0)) + 1
				p.fall()
				r = p.cascade()
				if r.is_empty():
					break
			_ok(p.b.find_groups().is_empty(), "seed %d 연쇄가 안 끝남" % s)
			_ok(p.b.count(Board.EMPTY) == 0, "seed %d 빈 칸이 남음" % s)
			if not p.b.has_move():
				p.b.shuffle()
				_ok(p.b.has_move(), "seed %d 섞은 뒤에도 못 둠" % s)
	print("  특수 생성 %s" % specials)
	for k in [D.SP_LINE_H, D.SP_LINE_V, D.SP_AREA, D.SP_RAINBOW, D.SP_FLY]:
		_ok(int(specials.get(k, 0)) > 0, "특수 젤리 %d 이 한 번도 안 생김" % k)


## 미션을 노리는 봇. 사람처럼 "저기를 깨야 한다"는 쪽을 70% 고른다 — 아무 수나 두면
## 열매 · 몬스터 판은 사람이라면 금방 깰 것도 영영 못 깨서, 이동 횟수를 잴 수가 없다.
## 특수끼리 바꾸기가 있으면 언제나 먼저 쓴다.
func _bot_pick(p: Play, all: Array, rng: RandomNumberGenerator) -> PackedInt32Array:
	for m in all:
		if p.b.is_special_swap(m[0], m[1]):
			return m
	var hot := _hot_cells(p)
	var good := []
	for m in all:
		if hot.has(m[0]) or hot.has(m[1]):
			good.append(m)
	if not good.is_empty() and rng.randf() < 0.7:
		return good[rng.randi() % good.size()]
	return all[rng.randi() % all.size()]


## 미션 쪽 칸 — 그 칸을 건드리는 수가 미션에 도움이 된다.
func _hot_cells(p: Play) -> Dictionary:
	var b := p.b
	var hot := {}
	for g in p.goals:
		if p.left(g) <= 0:
			continue
		for i in b.w * b.h:
			if b.hole[i]:
				continue
			var v := b.col[i]
			match g.type:
				"collect":
					if v == g.color:
						hot[i] = true
				"sugar":
					if b.sugar[i] > 0:
						hot[i] = true
				"chain":
					if b.chain[i] > 0:
						hot[i] = true
				"lock":
					# 자물쇠는 그 색 젤리를 어디서든 터뜨리면 된다
					if v >= 0 and v < Board.JELLY_N and b.lock_c.values().has(v):
						hot[i] = true
				"web":
					if b.web[i] > 0:
						hot[i] = true
				"paint":
					# 칠한 칸 바로 옆의 안 칠한 칸
					if b.paint[i] == 0:
						for n in b.n4(i):
							if b.paint[n] > 0:
								hot[i] = true
				"fire":
					if v == Board.FIRE and int(b.fire_t.get(i, 0)) <= 1:
						for n in b.n4(i):
							hot[n] = true
				"jar":
					# 그릇 둘레 두 칸 안의 그 색 젤리 — 그걸 옆에서 터뜨려야 찬다
					if v == Board.JAR:
						for j in b.w * b.h:
							if b.col[j] == b.jar_c.get(i, -1) and absi(b.cx(j) - b.cx(i)) + absi(b.cy(j) - b.cy(i)) <= 2:
								hot[j] = true
				"cloud":
					if b.cloud[i] > 0:
						hot[i] = true
						for n in b.n4(i):
							hot[n] = true
				"fruit":
					if v == Board.FRUIT:
						hot[i] = true
						var y := b.cy(i) + 1
						while y < b.h:
							hot[y * b.w + b.cx(i)] = true
							y += 1
				_:
					var hit: bool = (g.type == "box" and v == Board.BOX) or (g.type == "choco" and v == Board.CHOCO) \
							or (g.type == "ice" and b.ice[i] > 0) or (g.type == "monster" and v == Board.MON) \
							or (g.type == "capsule" and v == Board.CAPSULE) \
							or (g.type == "mole" and v == Board.MOLE)
					if hit:
						for n in b.n4(i):
							hot[n] = true
							for n2 in b.n4(n):
								hot[n2] = true
	return hot


## 봇 한 판. 깨면 쓴 이동 수, 못 깨면 -1. 수마다 "다 떨어졌나"를 본다.
func _bot_run(st: Dictionary, seed_: int, max_moves: int) -> Dictionary:
	var s := st.duplicate()
	s.moves = max_moves
	var p := Play.new(s, seed_)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var unsettled := 0
	while not p.won() and not p.lost():
		var all := p.b.all_moves()
		if all.is_empty():
			p.b.shuffle()
			all = p.b.all_moves()
			if all.is_empty():
				return {"used": -1, "score": p.score, "unsettled": unsettled, "stuck": true}
		var m := _bot_pick(p, all, rng)
		p.play_move(m[0], m[1])
		var f := p.b.fall()
		if not f.moves.is_empty() or not f.spawns.is_empty():
			unsettled += 1
	var used := max_moves - p.moves_left if p.won() else -1
	if p.won():
		p.finish_bonus()   # 별은 보너스까지 다 터뜨린 최종 점수로 매긴다 — 화면에서와 같게
	return {"used": used, "score": p.score, "stars": p.stars(), "unsettled": unsettled, "stuck": false}


## 5판 규칙 — 블록마다 새 장애물이 그 5판에 전부 들어 있고, 그 전에는 한 번도 안 나온다.
func _blocks() -> void:
	print("[5b] 5판마다 새 장애물")
	var all := Stages.all()
	var by_key := {}
	for e in Guide.ENTRIES:
		by_key[e.key] = e
	for b in StageGen.ORDER.size():
		var key: String = StageGen.ORDER[b]
		_ok(by_key.has(key), "도감에 %s 가 없음" % key)
		if not by_key.has(key):
			continue
		for k in StageGen.BLOCK:
			var id := b * StageGen.BLOCK + k + 1
			_ok(Guide._has(by_key[key], all[id - 1]), "스테이지 %d 에 %s 가 없음" % [id, key])
		_ok(Guide.first(key) == b * StageGen.BLOCK + 1, "%s 가 %d번보다 먼저 나옴(%d번)" % [key, b * StageGen.BLOCK + 1, Guide.first(key)])
	_ok(Stages.count() == StageGen.count(), "스테이지 수 %d" % Stages.count())


## 스테이지마다 봇이 runs 번 둔다. 한 번도 못 깬 판, 덜 떨어진 채로 수가 끝난 판이 있으면 실패.
func _stages(runs: int) -> void:
	print("[6] 스테이지 %d개 × 봇 %d판" % [Stages.count(), runs])
	print("   번호  이동  승률  남은이동  평균점수  별3(이긴 판 중)")
	for st in Stages.all():
		var w: int = String(st.rows[0]).length()
		for row in st.rows:
			_ok(String(row).length() == w, "스테이지 %d 줄 길이가 다름" % st.id)
		for row in st.get("floor", []):
			_ok(String(row).length() == w, "스테이지 %d 바닥 줄 길이가 다름" % st.id)
		_ok(st.rows.size() <= 9 and w <= 9, "스테이지 %d 판이 9×9 보다 큼" % st.id)
		# 벨트는 닫힌 고리여야 한다 — 끝이 열려 있으면 그 끝의 조각이 갈 곳이 없다
		var pb := Play.new(st, 1).b
		var indeg := {}
		for i in pb.w * pb.h:
			if pb.belt[i] > 0:
				var nx := pb.belt_next(i)
				var good: bool = nx >= 0 and nx < pb.w * pb.h and pb.belt[nx] > 0 and not pb.hole[nx] \
						and absi(pb.cx(nx) - pb.cx(i)) <= 1
				_ok(good, "스테이지 %d 벨트가 고리가 아님 (%d,%d)" % [st.id, pb.cx(i), pb.cy(i)])
				indeg[nx] = int(indeg.get(nx, 0)) + 1
		for k in indeg:
			_ok(indeg[k] == 1, "스테이지 %d 벨트 두 줄이 한 칸으로 들어옴" % st.id)
		var pt: Array = st.get("portal", [])
		var letters := {}
		for row in pt:
			for ch in String(row):
				if ch != ".":
					letters[ch] = true
		for ch in letters:
			_ok(letters.has(String(ch).to_upper()) and letters.has(String(ch).to_lower()), "스테이지 %d 포탈 %s 짝이 없음" % [st.id, ch])
		var p0 := Play.new(st, st.id)
		_ok(p0.b.find_groups().is_empty() and p0.b.has_move(), "스테이지 %d 처음 판이 이상함" % st.id)
		var wins := 0
		var left_sum := 0
		var score_sum := 0
		var three := 0
		for k in runs:
			var r := _bot_run(st, st.id * 1000 + k, int(st.moves))
			_ok(r.unsettled == 0, "스테이지 %d 수가 끝났는데 덜 떨어짐" % st.id)
			_ok(not r.stuck, "스테이지 %d 섞어도 둘 수가 없음" % st.id)
			if r.used >= 0:
				wins += 1
				left_sum += int(st.moves) - int(r.used)
				score_sum += int(r.score)
				if int(r.stars) == 3:
					three += 1
		print("   %3d  %3d  %3d%%  %6.1f  %8d  %3d%%" % [st.id, st.moves, wins * 100 / runs,
				float(left_sum) / maxi(1, wins), score_sum / maxi(1, wins), three * 100 / maxi(1, wins)])
		_ok(wins > 0, "스테이지 %d 봇이 한 번도 못 깸" % st.id)


## 스테이지마다 두 가지를 잰다.
##   1) 이동 제한 없이(150) 돌려 "깨는 데 든 이동 수" 분포 → 목표 승률 자리 값을 이동 횟수로 제안
##      (1번 65% → 마지막 35%. 봇은 사람보다 서투르므로 봇 35% 는 사람에게 할 만하다.)
##   2) 그 이동 횟수로 다시 돌려 **이긴 판의 최종 점수(보너스 포함)** 분포 → 별 문턱
##      별 둘 = 이긴 판 점수 중앙값 × STAR2_K, 별 셋 = × STAR3_K. 봇보다 잘 두면(이동을 더 남기면) 셋이 나온다.
const STAR2_K := 0.8
const STAR3_K := 1.1   ## 셋/둘 = 1.375 로 모든 판이 같다. 예전 60% 자리와 비슷한 높이다
func _tune(runs: int, from: int = 1, to: int = 1 << 20) -> void:
	print("이동 횟수 · 별 문턱 제안 (봇 %d판씩)" % runs)
	var mv_out := []
	var st_out := []
	for st in Stages.all():
		if st.id < from or st.id > to:
			continue
		var used := []
		for k in runs:
			var r := _bot_run(st, 50000 + st.id * 1000 + k, 150)
			if r.used >= 0:
				used.append(int(r.used))
		used.sort()
		# 목표 승률 — 1번 65% → 마지막 35%. (예전 80% → 45% 는 "너무 쉽다"는 말을 들었다)
		var target := lerpf(0.65, 0.35, float(st.id - 1) / maxf(1, Stages.count() - 1))
		var need := int(ceil(target * runs))
		# 12 ~ 45 로 묶는다 — 45 를 넘게 달라는 판은 숫자가 아니라 판을 고쳐야 한다
		var mv: int = clampi(used[need - 1] if used.size() >= need else 150, 10, 45)

		var scores := []
		for k in runs:
			var r := _bot_run(st, 90000 + st.id * 1000 + k, mv)
			if r.used >= 0:
				scores.append(int(r.score))
		scores.sort()
		var s2 := 0
		var s3 := 0
		if not scores.is_empty():
			# 별 둘 · 셋 = 봇 이긴 판 점수의 **중앙값 × 고정 비율**. 예전처럼 30% · 60% 자리를 따로 집으면
			# 이긴 판이 10~20개뿐이라 그 몇 개가 흩어진 모양대로 간격이 정해져서, 셋/둘이 1.01배인 판과
			# 1.77배인 판이 섞였다("별 사이 간극이 판마다 너무 다르다"). 중앙값은 튀는 점수에 덜 끌려간다.
			var med: int = scores[scores.size() / 2]
			s2 = _round50(med * STAR2_K)
			s3 = maxi(s2 + 100, _round50(med * STAR3_K))
		mv_out.append("%d: %d" % [st.id, mv])
		st_out.append("%d: [%d, %d]" % [st.id, s2, s3])
		print("  %2d  이동 %2d → %3d   깸 %2d/%d   별2 %6d  별3 %6d" % [st.id, st.moves, mv, scores.size(), runs, s2, s3])
	print("\nconst MOVES := {%s}" % ", ".join(mv_out))
	print("const STARS := {%s}" % ", ".join(st_out))


func _round50(v: int) -> int:
	return int(round(v / 50.0)) * 50
