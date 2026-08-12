extends SceneTree

## 조합 판정 검사. 창을 띄우지 않고 [Game] 만 만들어 돌린다.
##
## 이 로직은 **눈으로 확인하기 어렵다** — 화면에서는 "왜 조합이 안 되지"로만 보이고,
## 어느 단계에서 막혔는지가 안 드러난다. 실제로 쉬움 난이도를 두 번 잘못 만들었다.
## (① 조합법 그대로만 → 최하위 재료를 들고도 안 됨, ② 조합법 또는 끝까지 펼친 재료만 →
##  **절반쯤 합쳐 둔 판**이 오히려 안 됨.)
##
## ```
## test.bat
## ```

var _pass := 0
var _fail := 0


func _init() -> void:
	print("조합 판정 검사")
	print("──────────────────────────────────────────")
	_t_direct()
	_t_mixed()
	_t_normal_blocks_mixed()
	_t_prefers_direct()
	_t_deep()
	_t_absalom()
	_t_lumber_material()
	_t_random_gamble()
	_t_gold()
	_t_kuma()
	_t_wild()
	print("──────────────────────────────────────────")
	print("통과 %d · 실패 %d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _ok(name: String, cond: bool, note: String = "") -> void:
	if cond:
		_pass += 1
		print("  OK   %s" % name)
	else:
		_fail += 1
		print("  FAIL %s%s" % [name, ("  — " + note) if note != "" else ""])


# ══ 표에서 시험할 조합을 찾는다 ══════════════════════════════════

## 재료 중 **하나가 다시 조합품**인 유닛을 찾는다. 그게 중간 상태를 만들 수 있는 조합이다.
func _find_nested() -> Array:
	for k in U.UNITS.size():
		var mats: Array = U.UNITS[k]["m"]
		if mats.size() < 2:
			continue
		for mm in mats:
			var sub := D.index_of(int(mm[0]))
			if sub >= 0 and not (U.UNITS[sub]["m"] as Array).is_empty():
				return [k, sub]
	return []


func _give(g: Game, id: int, n: int) -> void:
	var ui := D.index_of(id)
	for i in n:
		g.add_unit(ui, Vector3.ZERO)


## `ui` 의 재료를 그대로 채워 준다. `skip` 은 빼고 준다.
func _give_mats(g: Game, ui: int, skip: int = -1) -> void:
	for mm in (U.UNITS[ui]["m"] as Array):
		if int(mm[0]) == skip:
			continue
		_give(g, int(mm[0]), int(mm[1]))


# ══ 검사 ══════════════════════════════════════════════════════

## 조합법 그대로 채우면 어느 난이도에서든 된다
func _t_direct() -> void:
	for mode in [D.Mode.NORMAL, D.Mode.EASY]:
		var g := Game.new()
		g.mode = mode
		var pair := _find_nested()
		var target: int = pair[0]
		_give_mats(g, target)
		var way := g.craft_way(target)
		_ok("조합법 그대로 (%s)" % D.MODE_NAME[mode], way == 1, "way=%d" % way)
		var made := g.craft(target)
		_ok("  만들어짐 (%s)" % D.MODE_NAME[mode],
			made >= 0 and int(g.units[made]["ui"]) == target)


## **이번에 고친 것** — 중간 재료 하나가 없고 그 재료의 재료가 있을 때.
func _t_mixed() -> void:
	var pair := _find_nested()
	var target: int = pair[0]
	var sub: int = pair[1]
	var sub_id := int(U.UNITS[sub]["i"])

	var g := Game.new()
	g.mode = D.Mode.EASY
	_give_mats(g, target, sub_id)   # 윗 재료에서 sub 만 빼고
	_give_mats(g, sub)              # 대신 sub 의 재료를 준다
	var before := g.units.size()

	var way := g.craft_way(target)
	_ok("섞인 상태 — 쉬움에서 조합 가능", way == 2, "way=%d" % way)

	var made := g.craft(target)
	_ok("  만들어짐", made >= 0 and int(g.units[made]["ui"]) == target)
	# 준 재료를 전부 먹고 결과 하나만 남아야 한다
	_ok("  재료를 전부 먹음", g.units.size() == 1,
		"준 것 %d, 남은 것 %d" % [before, g.units.size()])


## 보통에서는 같은 상태가 막혀야 한다 (쉬움만의 이득이어야 하므로)
func _t_normal_blocks_mixed() -> void:
	var pair := _find_nested()
	var target: int = pair[0]
	var sub_id := int(U.UNITS[pair[1]]["i"])
	var g := Game.new()
	g.mode = D.Mode.NORMAL
	_give_mats(g, target, sub_id)
	_give_mats(g, pair[1])
	_ok("섞인 상태 — 보통에서는 막힘", g.craft_way(target) == 0)


## 중간 유닛을 이미 만들어 뒀으면 그걸 쓰고, 최하위 재료를 또 먹지 않는다
func _t_prefers_direct() -> void:
	var pair := _find_nested()
	var target: int = pair[0]
	var sub: int = pair[1]
	var g := Game.new()
	g.mode = D.Mode.EASY
	_give_mats(g, target)      # 조합법 그대로 (sub 포함)
	_give_mats(g, sub)         # 여분으로 sub 의 재료까지
	var spare := 0
	for mm in (U.UNITS[sub]["m"] as Array):
		spare += int(mm[1])

	_ok("조합법이 갖춰지면 그쪽을 먼저 씀", g.craft_way(target) == 1)
	g.craft(target)
	# 결과 1 + 안 먹은 여분
	_ok("  여분을 건드리지 않음", g.units.size() == 1 + spare,
		"남은 것 %d, 기대 %d" % [g.units.size(), 1 + spare])


## 두 단계 아래까지 이어지는지 (재귀가 한 겹에서 멈추지 않는지)
func _t_deep() -> void:
	# 재료의 재료가 또 조합품인 유닛을 찾는다
	var target := -1
	var mid := -1
	for k in U.UNITS.size():
		for mm in (U.UNITS[k]["m"] as Array):
			var s1 := D.index_of(int(mm[0]))
			if s1 < 0:
				continue
			for m2 in (U.UNITS[s1]["m"] as Array):
				var s2 := D.index_of(int(m2[0]))
				if s2 >= 0 and not (U.UNITS[s2]["m"] as Array).is_empty():
					target = k
					mid = s1
					break
			if target >= 0:
				break
		if target >= 0:
			break
	if target < 0:
		_ok("두 단계 아래까지 이어짐", true, "그런 조합이 없어 건너뜀")
		return

	var g := Game.new()
	g.mode = D.Mode.EASY
	# 맨 위 재료는 최하위까지 펼쳐서 준다
	for mm in (U.UNITS[target]["l"] as Array):
		_give(g, int(mm[0]), int(mm[1]))
	var way := g.craft_way(target)
	_ok("최하위 재료만으로도 이어짐 (%s)" % U.UNITS[target]["n"], way == 2, "way=%d" % way)
	_ok("  만들어짐", g.craft(target) >= 0)


## 압살롬 도박 — 목재를 먹고 확률로 나온다. 꽝이어도 목재는 사라져야 한다.
func _t_absalom() -> void:
	_ok("압살롬이 표에 있음", D.absalom() >= 0)

	var g := Game.new()
	g.lumber = 0
	_ok("목재가 없으면 못 한다", g.gamble_absalom() == -1)

	# 꽝일 때도 목재를 먹는지
	g.lumber = D.ABSALOM_COST
	var r := g.gamble_absalom()
	_ok("한 번 하면 목재가 준다", g.lumber == 0, "남은 목재 %d" % g.lumber)
	_ok("  결과는 성공이거나 꽝", r >= 0 or r == -2)

	# 확률 — 판을 매번 비워 `free_spot` 이 느려지지 않게 한다
	var n := 3000
	var hit := 0
	for i in n:
		g.lumber = D.ABSALOM_COST
		if g.gamble_absalom() >= 0:
			hit += 1
		g.units.clear()
	var rate := float(hit) / float(n)
	_ok("확률이 %d%% 언저리" % int(D.ABSALOM_CHANCE * 100.0),
		absf(rate - D.ABSALOM_CHANCE) < 0.04, "실측 %.1f%%" % (rate * 100.0))


## 조합법이 요구하는 `목재` 는 유닛이 아니라 자원에서 나간다
func _t_lumber_material() -> void:
	var wid := D.lumber_id()
	_ok("조합법의 목재를 찾음", wid >= 0)
	if wid < 0:
		return

	var target := -1
	for k in U.UNITS.size():
		for mm in (U.UNITS[k]["m"] as Array):
			if int(mm[0]) == wid:
				target = k
				break
		if target >= 0:
			break
	_ok("목재를 쓰는 조합법이 있음", target >= 0)
	if target < 0:
		return

	var g := Game.new()
	var want := 0
	for mm in (U.UNITS[target]["m"] as Array):
		if int(mm[0]) == wid:
			want = int(mm[1])
		else:
			_give(g, int(mm[0]), int(mm[1]))
	_ok("목재가 없으면 안 됨 (%s)" % U.UNITS[target]["n"], g.craft_way(target) == 0)
	g.lumber = want
	_ok("  목재가 있으면 됨", g.craft_way(target) == 1)
	_ok("  만들어짐", g.craft(target) >= 0)
	_ok("  목재를 먹음", g.lumber == 0, "남은 목재 %d" % g.lumber)


## 랜덤 도박 — 실패하면 행운의 토큰이 남는다
func _t_random_gamble() -> void:
	var tok := D.named(D.TOKEN_NAME)
	_ok("행운의 토큰이 표에 있음", tok >= 0)
	if tok < 0:
		return
	var g := Game.new()
	g.lumber = 0
	_ok("목재가 없으면 못 한다", g.gamble_unit() == -1)

	var n := 2000
	var hit := 0
	var miss := 0
	for i in n:
		g.lumber = D.LUMBER_COST
		var r := g.gamble_unit()
		if r == tok:
			miss += 1
		elif r >= 0:
			hit += 1
		g.units.clear()
	_ok("성공과 꽝이 모두 나옴", hit > 0 and miss > 0, "성공 %d · 꽝 %d" % [hit, miss])
	var rate := float(hit) / float(n)
	_ok("성공률이 %d%% 언저리" % int(D.LUMBER_HIT * 100.0),
		absf(rate - D.LUMBER_HIT) < 0.05, "실측 %.1f%%" % (rate * 100.0))


## 골드로 위습을 산다
func _t_gold() -> void:
	var g := Game.new()
	g.gold = D.WISP_PRICE - 1
	_ok("골드가 모자라면 못 산다", not g.buy_wisp())
	g.gold = D.WISP_PRICE
	var w0 := g.wisp
	_ok("골드로 위습을 산다", g.buy_wisp() and g.wisp == w0 + 1 and g.gold == 0)


## 10단계 보상으로 초월쿠마를 고를 수 있다 (다른 통로가 없다)
func _t_kuma() -> void:
	var k := D.named(D.KUMA_NAME)
	_ok("초월쿠마가 표에 있음", k >= 0)
	var idx: int = D.STORY_CHOICE.find(D.KUMA_NAME)
	_ok("10단계 보상에 들어 있음", idx >= 0)
	if idx < 0 or k < 0:
		return
	var g := Game.new()
	g.wisp_choice = 1
	var got := g.use_choice(idx)
	_ok("  고르면 나온다", got == D.KUMA_NAME and g.units.size() == 1, got)


## `랜덤전용유닛 1기` 는 랜덤전용 등급이면 무엇으로든 채워진다
func _t_wild() -> void:
	var wid := D.wild_id()
	_ok("랜덤전용 표식을 찾음", wid >= 0)
	if wid < 0:
		return

	var pool := D.grade_pool(D.WILD_GRADE)
	_ok("랜덤전용 유닛이 있음", pool.size() > 0, "%d종" % pool.size())

	# 그 표식을 재료로 쓰는 조합법
	var target := -1
	for k in U.UNITS.size():
		for mm in (U.UNITS[k]["m"] as Array):
			if int(mm[0]) == wid:
				target = k
				break
		if target >= 0:
			break
	_ok("표식을 쓰는 조합법이 있음", target >= 0)
	if target < 0 or pool.is_empty():
		return

	# 표식 말고 다른 재료만 채워 두면 아직 안 된다
	var g := Game.new()
	var want := 0
	for mm in (U.UNITS[target]["m"] as Array):
		if int(mm[0]) == wid:
			want = int(mm[1])
		else:
			_give(g, int(mm[0]), int(mm[1]))
	_ok("랜덤전용이 없으면 안 됨 (%s)" % U.UNITS[target]["n"], g.craft_way(target) == 0)

	# **아무 랜덤전용 유닛**을 주면 된다 (여기서는 마지막 종으로)
	var sub: int = pool[pool.size() - 1]
	for i in want:
		g.add_unit(sub, Vector3.ZERO)
	_ok("  %s 로 채워짐" % U.UNITS[sub]["n"], g.craft_way(target) == 1)
	_ok("  만들어짐", g.craft(target) >= 0)
	_ok("  그 유닛을 먹음", g.units.size() == 1,
		"남은 유닛 %d" % g.units.size())
