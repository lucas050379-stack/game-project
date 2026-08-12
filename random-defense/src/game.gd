class_name Game
extends RefCounted

## 라운드 사이에도 남는 것 — 위습 · 목재 · 판에 나온 유닛 · 스토리 진행도.
##
## 몬스터와 탄은 [World] 가 들고 있다.

var rng := RandomNumberGenerator.new()

## 난이도. 조합 방식만 바꾼다 ([enum D.Mode] 참고).
var mode := D.Mode.NORMAL

var round_no := 1
var wisp := D.WISP_START
var lumber := 0
## 몬스터를 잡으면 쌓인다. 위습을 사는 데 쓴다.
var gold := 0

## 스토리 보상으로 받은 위습. 단계마다 뽑는 등급이 달라서 **등급 이름을 줄 세워** 들고 있다.
## 개수만 세면 8단계에서 받은 희귀함 위습과 3단계의 안흔함 위습이 구별되지 않는다.
var reward_wisps: Array = []
## 10단계 보상처럼 **고르는** 위습. 쓰면 선택창이 뜬다.
var wisp_choice := 0
## 흔함을 **직접 골라** 받는 위습. 조합법이 요구하는 마지막 한 종을 메우는 데 쓴다.
var wisp_pick := 0

## 판에 나와 있는 유닛. `{ui, p, cd, yaw, sel, dst}`
##  - `ui` 는 [U].UNITS 의 자리(색인)다. id 가 아니다 — id 는 띄엄띄엄해서 색인이 못 된다.
##  - `dst` 는 이동 명령의 목적지. 없으면 제자리다.
var units: Array = []

## 지금 도전 중인 스토리 단계 (1 부터). [constant D.STORY_STAGES] 를 넘으면 다 깬 것이다.
var story_stage := 1
var story_cleared := 0

var lost := false

## 판의 유닛 구성이 바뀔 때마다 오른다. 진화 목록은 **재귀로 조합 가능 여부를 재기 때문에**
## 매 프레임 다시 만들면 비싸다 — 부르는 쪽이 이 값으로 바뀌었는지만 보고 다시 만든다.
var rev := 0


func _init() -> void:
	rng.randomize()


# ══ 유닛 ══════════════════════════════════════════════════════

func add_unit(ui: int, p: Vector3) -> Dictionary:
	var u := {"ui": ui, "p": p, "cd": rng.randf() * 0.6, "yaw": 0.0, "sel": false, "dst": null}
	units.append(u)
	rev += 1
	return u


## 본진 안의 빈 자리 하나. 고리 길 위에는 안 놓는다 — 몬스터와 겹쳐 보인다.
func free_spot() -> Vector3:
	for i in 60:
		var p := Vector3(rng.randf_range(3.0, D.ARENA.x - 3.0), 0.0,
			rng.randf_range(3.0, D.ARENA.y - 3.0))
		if _too_close(p, 2.0):
			continue
		return p
	return Vector3(D.ARENA.x * 0.5, 0.0, D.ARENA.y * 0.5)


func _too_close(p: Vector3, r: float) -> bool:
	for u in units:
		if (u["p"] as Vector3).distance_to(p) < r:
			return true
	return false


## 유닛 id 별로 몇 기나 있는지. 조합 가능 판정이 이걸 본다.
func counts() -> Dictionary:
	var c := {}
	for u in units:
		var id := int(U.UNITS[int(u["ui"])]["i"])
		c[id] = int(c.get(id, 0)) + 1
	# **목재는 유닛이 아니라 자원이다.** 조합법이 요구하는 `목재` 칸에 보유량을 실어 주면
	# 그 아래 판정 코드가 유닛과 똑같이 다룬다. 안 이어 주면 목재가 조합법 95개를 막는다.
	var wid := D.lumber_id()
	if wid >= 0:
		c[wid] = int(c.get(wid, 0)) + lumber
	return c


# ══ 조합 ══════════════════════════════════════════════════════

## 지금 재료가 다 있는 유닛들의 자리 목록. **등급이 높은 것부터** 돌려준다 —
## 목록이 길어지면 위에 있는 것부터 보게 되므로, 값진 것이 위로 와야 한다.
func craftable() -> Array:
	var have := counts()
	var out := []
	for k in U.UNITS.size():
		var u: Dictionary = U.UNITS[k]
		var mats: Array = u["m"]
		if mats.is_empty():
			continue
		if _plain(k, have) != null or (mode == D.Mode.EASY and _spend(k, have, 0) != null):
			out.append(k)
	out.sort_custom(func(a, b): return int(U.UNITS[a]["g"]) > int(U.UNITS[b]["g"]))
	return out


## `ui` 를 **재료로 쓰는** 조합법들. 한 기만 골랐을 때 "이걸로 뭘 만들 수 있나"를 보여 준다.
##
## 돌려주는 것은 `{ui, missing, mats}` 이고 `mats` 는 `[재료 자리, 가진 수, 필요 수]` 짝들이다.
## **부족한 재료가 적은 것부터** 줄 세운다 — 같은 등급 순으로 늘어놓으면 손이 닿지도
## 않는 최상위가 맨 위에 오고, 정작 한 개만 더 모으면 되는 것이 아래로 밀린다.
func upgrades_from(ui: int) -> Array:
	var id := int(U.UNITS[ui]["i"])
	var have := counts()
	var out := []
	for k in U.UNITS.size():
		var mats: Array = U.UNITS[k]["m"]
		if mats.is_empty():
			continue
		var lows: Array = U.UNITS[k]["l"]
		var uses := _uses(mats, id) or (mode == D.Mode.EASY and _uses(lows, id))
		if not uses:
			continue

		# 지금 만들 수 있으면 모자란 것이 없는 셈이라 0 이다.
		# **재료 줄은 언제나 조합법 그대로 보여 준다** — 최하위로 펼쳐 보여 주면
		# 이미 절반쯤 합쳐 둔 판에서 "왜 이걸 또 모으라는 거지"가 된다.
		var via := 0
		if _plain(k, have) != null:
			via = 1
		elif mode == D.Mode.EASY and _spend(k, have, 0) != null:
			via = 2
		var missing := 0
		if via == 0:
			missing = _lack(mats, have)
			if mode == D.Mode.EASY:
				missing = mini(missing, _lack(lows, have))
		out.append({"ui": k, "missing": missing, "via": via, "mats": _rows(mats, have, via)})

	out.sort_custom(func(a, b):
		if int(a["missing"]) != int(b["missing"]):
			return int(a["missing"]) < int(b["missing"])
		return int(U.UNITS[a["ui"]]["g"]) > int(U.UNITS[b["ui"]]["g"]))
	return out


## 이 조합법이 `id` 를 재료로 쓰는가. **`랜덤전용유닛 1기` 자리는 랜덤전용 유닛이면 다 해당된다** —
## 그래서 나루토 선인모드를 골랐을 때도 그 표식을 쓰는 조합법이 목록에 뜬다.
func _uses(list: Array, id: int) -> bool:
	for mm in list:
		var mid := int(mm[0])
		if mid == id:
			return true
		if mid == D.wild_id() and D.is_wild(id):
			return true
	return false


## 모자란 재료가 몇 개인가. 대체 규칙을 타야 하므로 재고 사본에서 실제로 덜어 보며 센다.
func _lack(list: Array, have: Dictionary) -> int:
	if list.is_empty():
		return 1 << 20
	var work := have.duplicate()
	var n := 0
	for mm in list:
		for i in int(mm[1]):
			if not _take_one(work, int(mm[0])):
				n += 1
	return n


## `[재료 자리, 가진 수, 필요 수, 상태]` 짝들.
## 상태는 `0` 갖춤 · `1` 모자라지만 만들어서 채울 수 있음(쉬움) · `2` 모자람.
## `via`(전체가 어떻게 되는가)를 그대로 받아 쓴다 — 재료마다 다시 재귀로 재면
## 재고를 나눠 쓰는 것을 못 보므로 화면과 실제 조합 결과가 어긋난다.
func _rows(list: Array, have: Dictionary, via: int = 1) -> Array:
	var rows := []
	for mm in list:
		var mid := int(mm[0])
		var need := int(mm[1])
		var got := have_of(have, mid)
		var state := 0
		if got < need:
			state = 1 if via == 2 else 2
		rows.append([D.index_of(mid), got, need, state])
	return rows


## 조합할 수 있는 길. `0` 없음 · `1` 조합법 그대로 · `2` 모자란 재료를 만들어 가며 (쉬움).
##
## **쉬움의 핵심은 "최하위 재료로도 된다"가 아니라 "중간에 무엇이 있든 이어 붙는다"이다.**
## 조로와 칼병은 있는데 하찌만 없고, 하찌의 재료는 있다면 하찌를 먼저 만들어서라도 잇는다.
## 처음에는 조합법 그대로와 **끝까지 펼친 재료** 두 가지만 봤는데, 그러면 이 흔한
## 중간 상태가 통째로 막힌다 — 재료를 절반쯤 합쳐 둔 판이 오히려 조합이 안 되는 셈이었다.
func craft_way(ui: int) -> int:
	var have := counts()
	if _plain(ui, have) != null:
		return 1
	if mode == D.Mode.EASY and _spend(ui, have, 0) != null:
		return 2
	return 0


## 이 재료를 지금 몇 개 대어 줄 수 있는가. 화면에 `가진 수 / 필요 수` 를 찍을 때 쓴다.
## `랜덤전용유닛 1기` 는 **랜덤전용 유닛을 전부 합쳐** 센다.
func have_of(have: Dictionary, mid: int) -> int:
	if mid != D.wild_id():
		return int(have.get(mid, 0))
	var n := int(have.get(mid, 0))
	for k in have:
		if D.is_wild(int(k)):
			n += int(have[k])
	return n


## 재고에서 재료 하나를 뺀다. 성공하면 `true`.
##
## **재료를 빼는 곳은 여기 하나뿐이다.** 특수한 재료가 둘 있어서다 —
## `목재` 는 유닛이 아니라 자원이고([method counts] 가 재고에 실어 준다),
## `랜덤전용유닛 1기` 는 특정 유닛이 아니라 **랜덤전용 등급 아무거나 하나**다.
## 이걸 판정마다 따로 처리하면 어디 하나는 반드시 빠뜨린다.
func _take_one(pool: Dictionary, mid: int) -> bool:
	if int(pool.get(mid, 0)) > 0:
		pool[mid] = int(pool[mid]) - 1
		return true
	if mid == D.wild_id():
		# 여러 종을 들고 있으면 **많이 가진 쪽**부터 쓴다 — 한 기뿐인 종은 아껴 둔다
		var pick := -1
		for k in pool:
			var kid := int(k)
			if int(pool[k]) > 0 and D.is_wild(kid):
				if pick < 0 or int(pool[kid]) > int(pool[pick]):
					pick = kid
		if pick >= 0:
			pool[pick] = int(pool[pick]) - 1
			return true
	return false


## 조합법에 적힌 재료를 그대로 덜어 낸다. 되면 남은 재고를, 안 되면 `null` 을 준다.
func _plain(ui: int, have: Dictionary):
	var mats: Array = U.UNITS[ui]["m"]
	if mats.is_empty():
		return null
	var work := have.duplicate()
	for mm in mats:
		for i in int(mm[1]):
			if not _take_one(work, int(mm[0])):
				return null
	return work


## `ui` 를 만드는 데 드는 것을 `pool` 에서 덜어 낸다. 재료가 없으면 **그 재료를 다시
## 만들어서** 채운다 — 그렇게 끝까지 이어지면 남은 재고를, 어디선가 막히면 `null` 을 준다.
##
## 실제로 덜지 않고 사본에서만 굴린 뒤 성공했을 때의 사본을 돌려준다. 중간에 실패하면
## 사본을 버리면 그만이라 되돌릴 일이 없다.
##
## 중간에 만들어진 유닛은 부모가 곧바로 먹으므로 재고에 남지 않는다.
func _spend(ui: int, pool: Dictionary, depth: int):
	if depth > 24:
		return null
	var mats: Array = U.UNITS[ui]["m"]
	if mats.is_empty():
		return null
	var work := pool.duplicate()
	for mm in mats:
		var mid := int(mm[0])
		for i in int(mm[1]):
			if _take_one(work, mid):
				continue
			var sub := D.index_of(mid)
			if sub < 0:
				return null
			var nxt = _spend(sub, work, depth + 1)
			if nxt == null:
				return null
			work = nxt
	return work


func can_craft(ui: int) -> bool:
	return craft_way(ui) != 0


## 재료를 먹고 새 유닛을 만든다. **먹은 재료들의 한가운데**에 나온다 —
## 엉뚱한 데 생기면 방금 만든 것을 판에서 눈으로 찾아야 한다.
## 만들어진 유닛이 [member units] 의 몇 번째인지 돌려준다 (실패하면 -1).
func craft(ui: int) -> int:
	var have := counts()
	var rest = _plain(ui, have)
	if rest == null and mode == D.Mode.EASY:
		rest = _spend(ui, have, 0)
	if rest == null:
		return -1

	# 사본과 견줘 **실제로 줄어든 만큼**을 없앤다. 조합법에 적힌 재료를 그대로 쓰지 않는
	# 이유는 `랜덤전용유닛 1기` 처럼 **무엇으로 채워졌는지는 재고 차이에만 남기** 때문이다.
	# 중간 유닛은 만들어지자마자 먹히므로 판에 나타나지 않는다.
	var need := {}
	for k in have:
		var d := int(have[k]) - int(rest.get(k, 0))
		if d > 0:
			need[k] = d
	return _take(ui, need)


## `need`(유닛 id → 개수)만큼 판에서 없애고 그 한가운데에 새 유닛을 만든다.
func _take(ui: int, need: Dictionary) -> int:
	# **유닛부터 없애고, 목재는 유닛으로 못 채운 만큼만 자원에서 뺀다.**
	# 자원부터 빼면 판에 목재 유닛이 서 있을 때 그 유닛이 안 사라진 채 조합이 끝난다
	# (검사에서 재료 12기 중 7기가 그대로 남아 잡혔다).
	var sum := Vector3.ZERO
	var eaten := 0
	var i := units.size() - 1
	while i >= 0:
		var id := int(U.UNITS[int(units[i]["ui"])]["i"])
		if int(need.get(id, 0)) > 0:
			need[id] = int(need[id]) - 1
			sum += units[i]["p"] as Vector3
			units.remove_at(i)
			eaten += 1
		i -= 1

	var paid := false
	var wid := D.lumber_id()
	if wid >= 0 and int(need.get(wid, 0)) > 0:
		lumber = maxi(0, lumber - int(need[wid]))
		need[wid] = 0
		paid = true

	if eaten == 0 and not paid:
		return -1
	rev += 1
	# 재료가 목재뿐이면 먹은 자리가 없으므로 빈 칸에 세운다
	add_unit(ui, (sum / float(eaten)) if eaten > 0 else free_spot())
	return units.size() - 1


# ══ 위습과 목재 ════════════════════════════════════════════════

## 위습 하나로 유닛을 뽑는다.
func draw_unit() -> int:
	if wisp <= 0:
		return -1
	wisp -= 1
	var ui := D.draw_normal(rng)
	add_unit(ui, free_spot())
	return ui


## 위습 하나로 나무 도박. 목재를 얼마나 얻었는지 돌려준다 (0 이면 꽝).
func gamble_lumber() -> int:
	if wisp <= 0:
		return -1
	wisp -= 1
	var n := D.roll_lumber(rng)
	lumber += n
	return n


## 압살롬 도박. 목재 [constant D.ABSALOM_COST] 을 걸고 [constant D.ABSALOM_CHANCE] 확률로 나온다.
##
## 돌려주는 값: 유닛 자리(성공) · `-2`(꽝, 목재는 사라짐) · `-1`(목재 부족).
## **꽝이어도 목재는 먹는다** — 안 그러면 도박이 아니라 그냥 기다리면 되는 일이 된다.
func gamble_absalom() -> int:
	if lumber < D.ABSALOM_COST:
		return -1
	var ui := D.absalom()
	if ui < 0:
		return -1
	lumber -= D.ABSALOM_COST
	if rng.randf() >= D.ABSALOM_CHANCE:
		return -2
	add_unit(ui, free_spot())
	return ui


## 목재를 넣고 랜덤전용·특수함 유닛을 뽑는다.
## **실패해도 빈손은 아니다** — 행운의 토큰이 남는다. 그것도 조합 재료다.
## 돌려주는 값이 행운의 토큰의 자리면 실패한 것이다(`D.named(D.TOKEN_NAME)` 과 견주면 된다).
func gamble_unit() -> int:
	if lumber < D.LUMBER_COST:
		return -1
	lumber -= D.LUMBER_COST
	if rng.randf() < D.LUMBER_HIT:
		var ui := D.draw_lumber(rng)
		add_unit(ui, free_spot())
		return ui
	var tok := D.named(D.TOKEN_NAME)
	if tok < 0:
		return -2
	add_unit(tok, free_spot())
	return tok


## 골드로 위습을 산다. 몬스터를 잡아 번 것을 화력으로 바꾸는 유일한 통로다.
func buy_wisp() -> bool:
	if gold < D.WISP_PRICE:
		return false
	gold -= D.WISP_PRICE
	wisp += 1
	return true


## 스토리 보상 위습 — 줄 선 순서대로 그 등급에서 하나 뽑는다.
func use_reward() -> int:
	if reward_wisps.is_empty():
		return -1
	var grade_name: String = reward_wisps.pop_front()
	var ui := D.draw_grade(grade_name, rng)
	add_unit(ui, free_spot())
	return ui


## 다음에 쓸 보상 위습이 어느 등급인지 (HUD 표시용). 없으면 빈 문자열.
func next_reward() -> String:
	return "" if reward_wisps.is_empty() else String(reward_wisps[0])


## 흔함 선택 위습 — `i` 는 흔함 목록의 자리.
func use_pick(i: int) -> int:
	if wisp_pick <= 0:
		return -1
	var pool := D.grade_pool("흔함")
	if i < 0 or i >= pool.size():
		return -1
	wisp_pick -= 1
	var ui: int = pool[i]
	add_unit(ui, free_spot())
	return ui


## 10단계 보상. `pick` 은 [constant D.STORY_CHOICE] 의 자리.
func use_choice(pick: int) -> String:
	if wisp_choice <= 0:
		return ""
	wisp_choice -= 1
	match pick:
		0:
			var pool := D.grade_pool("희귀함")
			for k in pool:
				if String(U.UNITS[k]["n"]) == "레일리":
					add_unit(k, free_spot())
					return "희귀함 레일리"
			add_unit(pool[rng.randi_range(0, pool.size() - 1)], free_spot())
			return "희귀함"
		1:
			for k in U.UNITS.size():
				if String(U.UNITS[k]["n"]).begins_with("해적선"):
					add_unit(k, free_spot())
					return "해적선"
			return "해적선 없음"
		2:
			# 초월쿠마는 조합으로도 뽑기로도 안 나온다. 여기가 유일한 통로다.
			var k := D.named(D.KUMA_NAME)
			if k < 0:
				return "초월쿠마 없음"
			add_unit(k, free_spot())
			return D.KUMA_NAME
		_:
			lumber += 5
			return "목재 5"


# ══ 스토리 ════════════════════════════════════════════════════

func story_done() -> bool:
	return story_stage > D.STORY_STAGES


## 한 단계를 깼다. 보상 위습과 흔함 선택 위습을 준다.
func clear_stage() -> void:
	story_cleared += 1
	var rw := D.story_reward(story_stage)
	if rw == D.Rw.CHOICE:
		wisp_choice += 1
	else:
		reward_wisps.append(D.RW_GRADE[rw])
	wisp_pick += D.STORY_PICK
	story_stage += 1


# ══ 라운드 ════════════════════════════════════════════════════

func next_round() -> void:
	round_no += 1
	wisp += D.WISP_PER_ROUND


func won() -> bool:
	return round_no > D.MAX_ROUND
