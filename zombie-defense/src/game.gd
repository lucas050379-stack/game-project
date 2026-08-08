class_name Game
extends RefCounted

## 플레이어 상태와 성장 규칙. 적·투사체 같은 실시간 물체는 world.gd 가 들고 있다.
##
## 무기/보조 장비는 `{번호: 레벨}` 사전으로 들고 다닌다.
## 레벨은 1~5 이고 **6 이면 진화한 상태**다.

var hp := D.HP_MAX
var level := 1
var xp := 0
var xp_next := D.xp_need(1)
var revives := D.REVIVES
var time := 0.0

## 번호 -> 레벨
var weapons := {}
var supports := {}

# 통계
var kills := 0
var dealt := 0.0
var best_dps := 0.0


func _init() -> void:
	weapons[D.W_KUNAI] = 1          # 시작 무기
	hp = max_hp()

# ==================== 보조 장비 효과 ====================

func sup_val(id: int) -> float:
	if not supports.has(id):
		return 0.0
	var lv: int = supports[id]
	return D.SUPPORT[id]["val"][mini(lv, 5) - 1]


func max_hp() -> float:
	return D.HP_MAX * (1.0 + sup_val(D.S_VEST))


func speed() -> float:
	return D.SPEED * (1.0 + sup_val(D.S_BOOST))


func pickup() -> float:
	return D.PICKUP * (1.0 + sup_val(D.S_MAGNET))


func dmg_mult() -> float:
	return 1.0 + sup_val(D.S_CUBE)


func cd_mult() -> float:
	return 1.0 - sup_val(D.S_CORE)


func regen() -> float:
	return sup_val(D.S_KIT)


## 투사체 크기 배율
func size_mult() -> float:
	return 1.0 + sup_val(D.S_MAG)


## 사거리·범위 배율
func range_mult() -> float:
	return 1.0 + sup_val(D.S_SCOPE)


## 탄창 확장이 얹어 주는 추가 투사체 수
func extra_shots() -> int:
	if not supports.has(D.S_MAG):
		return 0
	return D.MAG_BONUS[mini(supports[D.S_MAG], 5)]

# ==================== 무기 값 조회 ====================

## 무기 w 의 stat 값을 현재 레벨 기준으로 돌려준다. 없는 stat 은 def.
func wstat(w: int, stat: String, def: float = 0.0) -> float:
	if not weapons.has(w):
		return def
	var row: Dictionary = D.WEAPON[w]
	if not row.has(stat):
		return def
	var lv: int = weapons[w]
	return float(row[stat][mini(lv, 6) - 1])


func wcount(w: int) -> int:
	return int(wstat(w, "count", 1))


func evolved(w: int) -> bool:
	return weapons.has(w) and weapons[w] >= 6


func weapon_name(w: int) -> String:
	var row: Dictionary = D.WEAPON[w]
	return row["evo_name"] if evolved(w) else row["name"]

# ==================== 성장 ====================

func gain_xp(n: int) -> void:
	xp += n


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


## 진화 조건을 갖춘 무기 목록
func evo_ready() -> Array:
	var out: Array = []
	for w: int in weapons.keys():
		if weapons[w] != D.MAX_LV:
			continue
		var need: int = D.WEAPON[w]["evo_sup"]
		if supports.has(need) and supports[need] >= D.EVO_SUP_LV:
			out.append(w)
	return out

# ==================== 레벨업 카드 ====================

## 카드 후보를 만들고 섞어서 n 장 뽑는다.
##
## 진화 카드는 **항상 맨 앞에 끼워 넣는다.** 무기를 만렙까지 올리고 짝까지 맞췄는데
## 진화가 안 뜨면 그 판의 목표가 사라진다.
func roll_cards(n: int) -> Array:
	var pool: Array = []

	for w: int in evo_ready():
		var row: Dictionary = D.WEAPON[w]
		pool.append({
			"type": "evolve", "id": w, "to": 6,
			"title": row["evo_name"], "sub": "진화!",
			"desc": row["evo_desc"], "col": P.GOLD, "prio": true,
		})

	for w: int in weapons.keys():
		var lv: int = weapons[w]
		if lv >= D.MAX_LV:
			continue
		var row: Dictionary = D.WEAPON[w]
		pool.append({
			"type": "weapon", "id": w, "to": lv + 1,
			"title": row["name"], "sub": "Lv.%d → %d" % [lv, lv + 1],
			"desc": row["desc"], "col": P.CRIMSON, "prio": false,
		})

	if weapons.size() < D.MAX_WEAPONS:
		for w in D.WEAPON.size():
			if weapons.has(w):
				continue
			pool.append({
				"type": "weapon", "id": w, "to": 1,
				"title": D.WEAPON[w]["name"], "sub": "새 무기",
				"desc": D.WEAPON[w]["desc"], "col": P.ORANGE, "prio": false,
			})

	for s: int in supports.keys():
		var lv2: int = supports[s]
		if lv2 >= 5:
			continue
		pool.append({
			"type": "support", "id": s, "to": lv2 + 1,
			"title": D.SUPPORT[s]["name"], "sub": "Lv.%d → %d" % [lv2, lv2 + 1],
			"desc": D.SUPPORT[s]["desc"], "col": P.CYAN, "prio": false,
		})

	if supports.size() < D.MAX_SUPPORTS:
		for s in D.SUPPORT.size():
			if supports.has(s):
				continue
			pool.append({
				"type": "support", "id": s, "to": 1,
				"title": D.SUPPORT[s]["name"], "sub": "새 장비",
				"desc": D.SUPPORT[s]["desc"], "col": P.JADE, "prio": false,
			})

	var forced: Array = []
	var rest: Array = []
	for card: Dictionary in pool:
		if card["prio"]:
			forced.append(card)
		else:
			rest.append(card)
	rest.shuffle()

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
		"support":
			var before := max_hp()
			supports[int(card["id"])] = int(card["to"])
			# 방탄복으로 최대 체력이 늘면 늘어난 만큼 채워 준다
			hp += maxf(0.0, max_hp() - before)
		"heal":
			heal(30.0)
