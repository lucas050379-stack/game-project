class_name Game
extends RefCounted

## 플레이어 상태와 성장 규칙. 적·투사체 같은 실시간 물체는 world.gd 가 들고 있다.
##
## 무기는 `{번호: 레벨}` 사전으로 들고 다닌다.
## 레벨은 1~5, **6 이면 진화한 상태**, 그 위 7~11 은 **진화 강화**(피해만 오른다).
##
## **성장이 두 갈래인 걸 헷갈리지 마세요.**
## - 판 **안**: 레벨업 카드 → 무기만. 능력치를 올려 주는 카드는 두지 않는다.
## - 판 **밖**: 라운드 클리어 코인 → 기본 스텟([Sv] 의 상점). 죽어도 남는다.
##
## 한 판(run)은 여러 **라운드**로 이어지고, **라운드마다 무기·레벨이 처음으로 초기화된다**.
## 즉 한 라운드가 곧 한 판이고, 라운드 번호는 난이도(적 체력·수·종류)만 올린다.
## 죽으면 1라운드부터 다시. 판을 넘어 남는 것은 코인과 상점 강화([Sv])뿐이다.

var char_id := 0
var round_no := 1

var hp := 0.0
var level := 1
var xp := 0
var xp_next := D.xp_need(1)
var revives := 0
var time := 0.0
var reroll_left := D.CARD_REROLL_MAX

## 번호 -> 레벨
var weapons := {}

# 통계 (판 전체 누적)
var kills := 0
var dealt := 0.0
var best_dps := 0.0
## 이번 판에서 번 코인 (결과 화면에 보여 준다). 실제 잔고는 [Sv].coins 다.
var earned := 0


## 이번 라운드에서 번 경험치 총합. 코인 보상이 이걸 본다 — `xp` 는 레벨업 때마다 깎이므로
## 누적량을 따로 세야 한다.
var round_xp := 0


## `round_start` 는 시작 라운드. 캐릭터 선택창에서 **이미 도달해 본 라운드까지** 고를 수 있다.
func _init(character: int = 0, round_start: int = 1) -> void:
	char_id = clampi(character, 0, D.CHAR.size() - 1)
	round_no = maxi(1, round_start)
	weapons[int(D.CHAR[char_id]["weapon"])] = 1      # 캐릭터마다 시작 무기가 다르다
	revives = D.REVIVES
	hp = max_hp()


func chr() -> Dictionary:
	return D.CHAR[char_id]


## 이 판의 직업. 스킬이 갈리는 축이 전부 여기서 나온다 —
## 시작 스킬 · 피해 보정 · 카드 후보 · 진화 형태.
func cls() -> int:
	return int(chr()["cls"])


func class_name_() -> String:
	return String(D.CLASS_NAME[cls()])


## 무기 w 가 **내 직업에 맞는가.** 맞으면 피해가 `D.CLASS_BONUS` 만큼 오른다.
##
## 원래 다른 직업 것이어도 **내 직업 전용 진화를 마쳤으면 맞는 것으로 친다** —
## 그 순간 형태가 내 직업 것으로 바뀌었기 때문이다. 이게 없으면 "다른 직업 스킬을
## 내 형태로 진화시킨다"는 보상이 진화 카드 한 장으로 끝나고 그 뒤로는 손해가 된다.
func suits(w: int) -> bool:
	if int(D.WEAPON[w]["cls"]) == cls():
		return true
	return not evo_alt(w).is_empty()


## 진화했을 때 내 직업 전용으로 갈아 끼울 값. 없으면 빈 사전.
##
## **진화하기 전에도 값이 있는지 물어볼 수 있어야 한다** — 카드에 "내 직업 전용 진화"를
## 미리 알려 주려면 필요하다. 그래서 진화 여부는 여기서 보지 않는다([wstat] 이 본다).
func evo_alt(w: int) -> Dictionary:
	var by: Dictionary = D.WEAPON[w].get("evo_by", {})
	return by.get(cls(), {})

# ==================== 기본 스텟 ====================
#
# 캐릭터 고유값 × 코인 상점에서 산 강화. **레벨업 카드는 여기에 손대지 않는다.**

func max_hp() -> float:
	return float(chr()["hp"]) * (1.0 + Sv.bonus("hp"))


## 이동 속도는 **캐릭터 고유값이 전부다.** 코인 상점에서 올릴 수 없다 —
## 카이팅이 곧 생존인 장르라 속도 강화는 다른 줄을 다 제치고 먼저 찍는 항목이 됐다.
func speed() -> float:
	return float(chr()["spd"])


func pickup() -> float:
	return D.PICKUP * (1.0 + Sv.bonus("pick"))


## **이 둘은 `wstat` 이 부른다** — 직접 부를 일이 거의 없다. 무기 값을 읽는 곳이 전부
## `wstat` 을 지나므로 거기 한 곳에서 곱해야 빠지는 데가 생기지 않는다.
## 이 둘의 곱이 `D.power(lv)` 이고 그 값이 그대로 라운드 난이도가 된다.
func dmg_mult() -> float:
	return float(chr()["dmg"]) * (1.0 + Sv.bonus("dmg"))


func cd_mult() -> float:
	return maxf(D.CD_FLOOR, 1.0 - Sv.bonus("cd"))

# ==================== 라운드 ====================

## 라운드를 클리어하고 다음 라운드로. 돌려주는 값은 이번에 번 코인이다.
##
## **무기와 레벨을 처음 상태로 되돌린다.** 라운드마다 시작 무기 하나로 다시 쌓아 올리는
## 구조라, 한 라운드가 곧 한 판이고 라운드 번호는 난이도만 올린다.
## 레벨과 경험치도 같이 되돌려야 한다 — 레벨만 높은 채로 무기를 비우면 다음 레벨까지
## 필요한 경험치가 이미 커져 있어서 무기를 다시 갖출 수가 없다.
## 판을 넘어 남는 것은 코인과 상점 강화([Sv])뿐이다.
func next_round() -> int:
	var coins := D.round_coins(round_no, round_xp)
	earned += coins
	Sv.add_coins(coins)
	round_no += 1
	Sv.reach(round_no)

	weapons.clear()
	weapons[int(chr()["weapon"])] = 1
	level = 1
	xp = 0
	xp_next = D.xp_need(1)
	round_xp = 0
	reroll_left = D.CARD_REROLL_MAX

	time = 0.0
	hp = max_hp()
	revives = D.REVIVES
	return coins


func round_left() -> float:
	return maxf(0.0, D.round_time(round_no) - time)


func map() -> Dictionary:
	return D.map_of(round_no)

# ==================== 무기 값 조회 ====================

## 무기 w 의 stat 값을 현재 레벨 기준으로 돌려준다. 없는 stat 은 def.
##
## **캐릭터 보정과 코인 상점 강화가 여기서 걸린다.** 무기 값을 읽는 곳이 전부 이 함수를
## 지나므로(총·사슬·필드·드론·장판·HUD 까지) 여기 한 곳에서 곱하면 빠지는 데가 없다.
## 예전에는 `dmg_mult`/`cd_mult` 를 만들어 두고 **아무도 부르지 않아서**, 상점 공격력과
## 재사용 대기를 만렙까지 올려도 좀비에게 9 씩 들어갔다. 새 stat 을 넣을 때
## 곱하기를 호출부에 흩뿌리지 말고 이 `match` 에 한 줄 더하세요.
## **직업별 진화는 여기서 갈린다.** 진화한 무기에 내 직업 전용 값(`evo_by`)이 있으면
## 6레벨 칸 대신 그 값을 쓴다 — 이름과 설명만 바뀌는 것이 아니라 개수·반경·관통이
## 통째로 달라진다. 전용 값에 없는 stat 은 원래 6레벨 칸으로 떨어진다.
##
## 진화 강화(레벨 7~11)는 칸이 따로 없다. **6레벨 칸을 그대로 읽고 `dmg` 에만** 얹는다 —
## 개수·반경·재사용 대기가 그대로여야 화면의 모양이 안 바뀌고, 잣대도 한 줄로 남는다.
func wstat(w: int, stat: String, def: float = 0.0) -> float:
	if not weapons.has(w):
		return def
	var row: Dictionary = D.WEAPON[w]
	var lv: int = weapons[w]
	var v := 0.0
	var alt := evo_alt(w) if lv >= 6 else {}
	if alt.has(stat):
		v = float(alt[stat])
	elif row.has(stat):
		v = float(row[stat][mini(lv, 6) - 1])
	else:
		return def
	match stat:
		"dmg":
			# 직업 보정과 진화 강화는 **여기 한 곳에서만** 걸린다.
			# 호출부에 흩뿌리면 반드시 빠지는 데가 생긴다.
			return v * dmg_mult() \
				* ((1.0 + D.CLASS_BONUS) if suits(w) else 1.0) \
				* (1.0 + D.EVO_STACK * float(evo_stacks(w)))
		"cd":
			return v * cd_mult()
	return v


## 진화한 뒤 몇 단계나 더 올렸나 (0 ~ `D.EVO_PLUS`). 피해에만 쓰인다.
func evo_stacks(w: int) -> int:
	if not weapons.has(w):
		return 0
	return clampi(int(weapons[w]) - 6, 0, D.EVO_PLUS)


func wcount(w: int) -> int:
	return int(wstat(w, "count", 1))


func evolved(w: int) -> bool:
	return weapons.has(w) and weapons[w] >= 6


func weapon_name(w: int) -> String:
	var row: Dictionary = D.WEAPON[w]
	if not evolved(w):
		return String(row["name"])
	var alt := evo_alt(w)
	return String(alt["name"]) if alt.has("name") else String(row["evo_name"])

# ==================== 성장 ====================

func gain_xp(n: int) -> void:
	xp += n
	round_xp += n


func can_level() -> bool:
	return xp >= xp_next


## 실제 레벨업. 카드를 띄우는 쪽(main.gd)이 부른다 —
## 보스 젬처럼 한 번에 여러 레벨이 오를 때 카드를 레벨 수만큼 보여 줘야 하기 때문이다.
func level_up() -> void:
	xp -= xp_next
	level += 1
	xp_next = D.xp_need(level)


func heal(v: float) -> void:
	hp = minf(max_hp(), hp + v)


## 진화 조건을 갖춘 무기 목록 — 만렙이면 끝이다.
## (예전에는 짝이 되는 보조 장비를 3레벨까지 올려야 했는데, 보조 장비를 없애면서 같이 걷었다.)
func evo_ready() -> Array:
	var out: Array = []
	for w: int in weapons.keys():
		if weapons[w] == D.MAX_LV:
			out.append(w)
	return out

# ==================== 레벨업 카드 ====================

## 카드 후보 정렬용 편향. 값이 **작을수록 먼저 뽑힌다.**
##
## 룰렛은 15종을 전부 돌리되 **내 직업 스킬 5종이 먼저 보이게** 기울인다.
## 완전히 막아 버리면 "다른 직업 스킬을 내 형태로 진화시킨다"는 길 자체가 사라지고,
## 반대로 아무 편향도 없으면 내 직업 스킬 5종을 보기까지 카드 운에 통째로 맡기게 된다.
## 0.42 는 "대개 내 직업 것이 뜨지만 남의 것도 심심찮게 섞인다" 정도다.
const CLASS_BIAS := 0.42


## 카드 후보를 만들고 섞어서 n 장 뽑는다.
##
## 진화 카드는 **항상 맨 앞에 끼워 넣는다.** 무기를 만렙까지 올렸는데 진화가 안 뜨면
## 그 판의 목표가 사라진다.
##
## **다른 직업의 고유 스킬(`unique`)은 후보에 아예 넣지 않는다.** 회전 참격·화염구·
## 관통 저격은 그 직업의 정체성이라 남이 들면 직업을 고른 의미가 없어진다.
func roll_cards(n: int) -> Array:
	var pool: Array = []

	for w: int in evo_ready():
		var row: Dictionary = D.WEAPON[w]
		var alt := evo_alt(w)
		var mine := not alt.is_empty()
		pool.append({
			"type": "evolve", "id": w, "to": 6,
			"title": alt["name"] if mine else row["evo_name"],
			"sub": ("%s 진화!" % class_name_()) if mine else "진화!",
			"desc": alt["desc"] if mine else row["evo_desc"],
			"col": P.GOLD, "prio": true,
		})

	for w: int in weapons.keys():
		var lv: int = weapons[w]
		if lv == D.MAX_LV or lv >= D.LV_CAP:
			continue          # 만렙은 진화 카드로, 진화까지 다 올린 것은 더 줄 것이 없다
		var row: Dictionary = D.WEAPON[w]
		if lv >= 6:
			# **진화 강화** — 진화 뒤에도 피해만 계속 올린다. 이 카드가 없으면 스킬을
			# 다 진화시킨 뒤의 레벨업이 전부 구급 상자로 채워져 아무 의미가 없어진다.
			var st := evo_stacks(w)
			pool.append({
				"type": "weapon", "id": w, "to": lv + 1,
				"title": weapon_name(w), "sub": "진화 강화 +%d → +%d" % [st, st + 1],
				"desc": "피해 +%d%%. 모양과 개수는 그대로다." % int(D.EVO_STACK * 100.0),
				"col": P.GOLD, "prio": false,
			})
			continue
		pool.append({
			"type": "weapon", "id": w, "to": lv + 1,
			"title": row["name"], "sub": "Lv.%d → %d" % [lv, lv + 1],
			"desc": row["desc"], "col": P.CRIMSON, "prio": false,
		})

	if weapons.size() < D.MAX_WEAPONS:
		for w in D.WEAPON.size():
			if weapons.has(w):
				continue
			var row2: Dictionary = D.WEAPON[w]
			if bool(row2.get("unique", false)) and int(row2["cls"]) != cls():
				continue
			# 남의 직업 스킬인데 내 직업 전용 진화가 있으면 카드에서 미리 알려 준다 —
			# 그걸 모르면 "왜 남의 스킬을 굳이 키우나"에 대한 답이 화면에 없다.
			var mine2: bool = int(row2["cls"]) == cls()
			var sub := "새 스킬" if mine2 else "%s 스킬" % D.CLASS_NAME[int(row2["cls"])]
			if not mine2 and not evo_alt(w).is_empty():
				sub += " · %s 진화 가능" % class_name_()
			pool.append({
				"type": "weapon", "id": w, "to": 1,
				"title": row2["name"], "sub": sub,
				"desc": row2["desc"], "col": P.ORANGE if mine2 else P.VIOLET, "prio": false,
			})

	var forced: Array = []
	var rest: Array = []
	for card: Dictionary in pool:
		if card["prio"]:
			forced.append(card)
		else:
			rest.append(card)
	# 무작위 키로 정렬한다 — 내 직업 스킬은 키에서 `CLASS_BIAS` 를 빼서 앞으로 당긴다.
	# `shuffle()` 뒤에 다시 정렬하는 것이 아니라 정렬 하나로 끝내야 편향이 정확히 걸린다.
	for card: Dictionary in rest:
		card["_k"] = randf() - (CLASS_BIAS if suits(int(card["id"])) else 0.0)
	rest.sort_custom(func(a, b): return float(a["_k"]) < float(b["_k"]))

	var out: Array = []
	for card: Dictionary in forced:
		if out.size() < n:
			out.append(card)
	for card: Dictionary in rest:
		if out.size() >= n:
			break
		out.append(card)

	# 더 올릴 게 없으면 회복 카드로 채운다
	while out.size() < n:
		out.append({
			"type": "heal", "id": -1, "to": 0,
			"title": "구급 상자", "sub": "즉시 회복",
			"desc": "체력을 30 회복한다.", "col": P.JADE, "prio": false,
		})
	return out


func apply_card(card: Dictionary) -> void:
	match String(card["type"]):
		"weapon":
			weapons[int(card["id"])] = int(card["to"])
		"evolve":
			weapons[int(card["id"])] = 6
		"heal":
			heal(30.0)
