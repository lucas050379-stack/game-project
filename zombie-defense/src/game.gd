class_name Game
extends RefCounted

## 플레이어 상태와 성장 규칙. 적·투사체 같은 실시간 물체는 world.gd 가 들고 있다.
##
## 무기는 `{번호: 레벨}` 사전으로 들고 다닌다.
## 레벨은 1~`D.MAX_LV`(6), **`D.EVO_LV`(7)이면 진화한 상태**다.
##
## **성장이 두 갈래인 걸 헷갈리지 마세요.**
## - 판 **안**: 레벨업 카드 → 스킬 · 패시브 · (더 올릴 게 없으면) 리미트 브레이크.
##   진화는 카드가 아니라 **보물상자**에서 일어난다(`open_chest`).
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
## 판당 남은 횟수. 기본값 + 상점에서 산 단계(`Sv.uses`).
var reroll_left := 0
var skip_left := 0
var banish_left := 0
## 이 판에서 지운(밴) 카드. `"w3"`(스킬 3) · `"p1"`(패시브 1) 처럼 담는다.
var banished := {}

## 고른 아르카나 번호들. **되돌릴 수 없다.**
var arcana: Array = []
## 다음에 아르카나를 고를 `D.ARCANA_AT` 색인
var arcana_at := 0

## 리미트 브레이크 — `stat` -> 쌓인 값. 패시브와 같은 통로(`pmul`)를 지난다.
var limit := {}

## 유니온으로 합쳐진 스킬. `스킬 번호 -> D.UNION 색인`. 합쳐지면 재료 하나는 사라진다.
var unions := {}

## 번호 -> 레벨
var weapons := {}

## 패시브 번호 -> 레벨 (1~`D.MAX_PLV`). **판 안에서만 유효하고 라운드마다 초기화된다** —
## 판 밖에 남는 성장은 코인 상점([Sv]) 하나뿐이라는 경계는 그대로다.
##
## 진화의 짝이기도 하다: 스킬이 만렙이어도 짝 패시브를 **갖고 있지 않으면** 진화 카드가
## 뜨지 않는다(`evo_ready`).
var passives := {}

# 통계 (판 전체 누적)
var kills := 0
var dealt := 0.0
var best_dps := 0.0
## 이번 판에서 번 코인 (결과 화면에 보여 준다). 실제 잔고는 [Sv].coins 다.
var earned := 0


## 이번 라운드에서 번 경험치 총합. 코인 보상이 이걸 본다 — `xp` 는 레벨업 때마다 깎이므로
## 누적량을 따로 세야 한다.
var round_xp := 0

## [Sv] 에 이미 적어 넘긴 처치 수. 라운드마다 **늘어난 만큼만** 넘기려고 들고 있다.
var _recorded_kills := 0


## `round_start` 는 시작 라운드. 캐릭터 선택창에서 **이미 도달해 본 라운드까지** 고를 수 있다.
func _init(character: int = 0, round_start: int = 1) -> void:
	char_id = clampi(character, 0, D.CHAR.size() - 1)
	round_no = maxi(1, round_start)
	weapons[int(D.CHAR[char_id]["weapon"])] = 1      # 캐릭터마다 시작 스킬이 다르다
	revives = D.REVIVES
	_reset_uses()
	hp = max_hp()


## 판당 쓸 수 있는 횟수를 상점 단계에서 다시 계산한다. 라운드마다 채워진다.
func _reset_uses() -> void:
	reroll_left = Sv.uses("reroll", D.CARD_REROLL_MAX)
	skip_left = Sv.uses("skip", 0)
	banish_left = Sv.uses("banish", 0)


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

# ==================== 패시브 ====================

## 판 안의 성장이 `stat` 에 얹어 주는 배율. 없으면 1.0.
##
## **패시브 · 아르카나 · 리미트 브레이크 셋이 같은 통로를 지난다.** 여기 한 곳에서만
## 계산하므로, 새 것을 넣을 때 곱하기를 호출부에 흩뿌릴 일이 없다.
func pmul(stat: String) -> float:
	var k := 0.0
	for i: int in passives.keys():
		var row: Dictionary = D.PASSIVE[i]
		if String(row["stat"]) == stat:
			k += float(row["val"]) * float(passives[i])
	for a: int in arcana:
		var arow: Dictionary = D.ARCANA[a]
		if String(arow.get("stat", "")) == stat:
			k += float(arow["val"])
		if String(arow.get("stat2", "")) == stat:
			k += float(arow["val2"])
	k += float(limit.get(stat, 0.0))
	# 체력이 0 이하가 되면 곧바로 죽으므로 바닥을 둔다 (사냥꾼의 눈은 -25% 다).
	return maxf(0.20, 1.0 + k)


func plevel(i: int) -> int:
	return int(passives.get(i, 0))


## 아르카나가 켜 놓은 규칙 표시(`flag`)를 갖고 있나.
func has_flag(f: String) -> bool:
	for a: int in arcana:
		if String(D.ARCANA[a].get("flag", "")) == f:
			return true
	return false


## 지금 아르카나를 고를 때인가. 라운드 진행도를 보고 판단한다.
func arcana_due() -> bool:
	if arcana_at >= D.ARCANA_AT.size():
		return false
	return time / maxf(1.0, D.round_time(round_no)) >= float(D.ARCANA_AT[arcana_at])


## 아직 안 고른 아르카나 후보 (최대 n 개)
func roll_arcana(n: int) -> Array:
	var pool: Array = []
	for i in D.ARCANA.size():
		if not arcana.has(i):
			pool.append(i)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


func take_arcana(i: int) -> void:
	if not arcana.has(i):
		arcana.append(i)
	arcana_at += 1

# ==================== 기본 스텟 ====================
#
# 캐릭터 고유값 × 코인 상점에서 산 강화 × 판 안의 패시브.

func max_hp() -> float:
	return float(chr()["hp"]) * (1.0 + Sv.bonus("hp")) * pmul("hp")


## 이동 속도는 **코인 상점에서 올릴 수 없다** — 카이팅이 곧 생존인 장르라 속도 강화는
## 다른 줄을 다 제치고 먼저 찍는 항목이 됐다. 판 안의 패시브(강철 각반)로만 오르고,
## 라운드가 끝나면 같이 사라진다.
func speed() -> float:
	return float(chr()["spd"]) * pmul("spd")


func pickup() -> float:
	return D.PICKUP * (1.0 + Sv.bonus("pick"))


## **이 둘은 `wstat` 이 부른다** — 직접 부를 일이 거의 없다. 무기 값을 읽는 곳이 전부
## `wstat` 을 지나므로 거기 한 곳에서 곱해야 빠지는 데가 생기지 않는다.
## 이 둘의 곱이 `D.power(lv)` 이고, 라운드 n 의 요구 화력은 `D.req_power(n)` 이다.
func dmg_mult() -> float:
	return float(chr()["dmg"]) * (1.0 + Sv.bonus("dmg")) * pmul("dmg")


## 패시브(속사 벨트)는 상점 강화와 **곱으로** 걸린다. 상점 쪽 하한(`CD_FLOOR`)은 난이도
## 등식을 지키는 값이라 그대로 두고, 패시브는 그 밖에서 곱한다 — 안 그러면 판 안의
## 카드 한 장이 `power(lv)` 를 흔들어 등식을 깨뜨린다.
func cd_mult() -> float:
	return maxf(D.CD_FLOOR, 1.0 - Sv.bonus("cd")) / pmul("cd")

# ==================== 라운드 ====================

## 라운드를 클리어하고 다음 라운드로. 돌려주는 값은 이번에 번 코인이다.
##
## **무기와 레벨을 처음 상태로 되돌린다.** 라운드마다 시작 무기 하나로 다시 쌓아 올리는
## 구조라, 한 라운드가 곧 한 판이고 라운드 번호는 난이도만 올린다.
## 레벨과 경험치도 같이 되돌려야 한다 — 레벨만 높은 채로 무기를 비우면 다음 레벨까지
## 필요한 경험치가 이미 커져 있어서 무기를 다시 갖출 수가 없다.
## 판을 넘어 남는 것은 코인과 상점 강화([Sv])뿐이다.
func next_round() -> int:
	var coins := int(D.round_coins(round_no, round_xp) * coin_mult())
	earned += coins
	Sv.add_coins(coins)
	commit_record()
	round_no += 1
	Sv.reach(round_no)

	weapons.clear()
	weapons[int(chr()["weapon"])] = 1
	# 패시브·아르카나·리미트·유니온·밴 모두 스킬과 같이 초기화된다.
	# 판 밖에 남는 성장은 코인 상점([Sv]) 하나뿐이다.
	passives.clear()
	unions.clear()
	limit.clear()
	banished.clear()
	arcana.clear()
	arcana_at = 0
	level = 1
	xp = 0
	xp_next = D.xp_need(1)
	round_xp = 0
	_reset_uses()

	time = 0.0
	hp = max_hp()
	revives = D.REVIVES
	return coins


## 누적 기록(처치·진화)과 판 안에서 주운 동전을 파일에 적어 넘긴다.
##
## **라운드가 끝날 때와 죽을 때 둘 다 불러야 한다.** 처치마다 저장하면 초당 수백 번 파일을
## 쓰므로 미뤄 두는데, 죽는 쪽에서 안 부르면 그 라운드에 주운 동전과 처치가 통째로 날아간다
## (`Sv.pick_coins` 는 일부러 저장하지 않는다). 늘어난 만큼만 넘기려고 `_recorded_kills` 를
## 들고 있다 — 두 번 불려도 같은 처치를 두 번 세지 않는다.
func commit_record() -> void:
	Sv.record(kills - _recorded_kills, evo_count())
	_recorded_kills = kills


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
	# 유니온으로 합쳐졌으면 그 값이 모든 것을 덮어쓴다 — 두 스킬이 하나가 된 것이라
	# 원래 표의 레벨 칸을 볼 이유가 없다.
	var uni := union_of(w)
	var alt := evo_alt(w) if lv >= D.EVO_LV else {}
	if uni.has(stat):
		v = float(uni[stat])
	elif alt.has(stat):
		v = float(alt[stat])
	elif row.has(stat):
		v = float(row[stat][mini(lv, D.EVO_LV) - 1])
	else:
		return def
	match stat:
		"dmg":
			# 직업 보정은 **여기 한 곳에서만** 걸린다.
			# 호출부에 흩뿌리면 반드시 빠지는 데가 생긴다.
			return v * dmg_mult() * ((1.0 + D.CLASS_BONUS) if suits(w) else 1.0)
		"cd":
			return v * cd_mult()
		"count":
			# 아르카나 "잿빛 하늘" — 투사체를 쏘는 스킬만 한 발 더. 상시 전개형은 `count`
			# 자체가 없으므로 여기 안 들어온다.
			return v + (1.0 if has_flag("count1") else 0.0)
		"radius", "range", "width":
			# 집중 렌즈 · 거인의 손 — 넓이에 관한 값은 이름이 셋이므로 한꺼번에 받는다.
			# 새 stat 이 넓이를 뜻한다면 **이 줄에 이름을 추가**하세요.
			return v * pmul("range")
	return v


## 이 스킬이 유니온으로 합쳐졌으면 그 줄. 아니면 빈 사전.
func union_of(w: int) -> Dictionary:
	var i := int(unions.get(w, -1))
	return D.UNION[i] if i >= 0 else {}


func wcount(w: int) -> int:
	return int(wstat(w, "count", 1))


func evolved(w: int) -> bool:
	return weapons.has(w) and weapons[w] >= D.EVO_LV


func weapon_name(w: int) -> String:
	var uni := union_of(w)
	if not uni.is_empty():
		return String(uni["into_name"])
	var row: Dictionary = D.WEAPON[w]
	if not evolved(w):
		return String(row["name"])
	var alt := evo_alt(w)
	return String(alt["name"]) if alt.has("name") else String(row["evo_name"])


## 그리기·문양에 쓸 kind. 유니온이면 합쳐진 쪽 kind 를 쓴다.
func weapon_kind(w: int) -> String:
	var uni := union_of(w)
	return String(uni["kind"]) if not uni.is_empty() else String(D.WEAPON[w]["kind"])


## 지금 합칠 수 있는 유니온 목록 — **재료 둘 다 만렙 이상**이어야 한다.
## 진화와 달리 짝 패시브는 안 본다. 대신 스킬 두 칸을 쓰는 것이 대가다.
func union_ready() -> Array:
	var out: Array = []
	for i in D.UNION.size():
		var a := int(D.UNION[i]["a"])
		var b := int(D.UNION[i]["b"])
		if unions.has(a) or unions.has(b):
			continue
		if weapons.get(a, 0) >= D.MAX_LV and weapons.get(b, 0) >= D.MAX_LV:
			out.append(i)
	return out


## 실제로 합친다. 결과는 `a` 자리에 들어가고 `b` 는 칸에서 사라진다.
func do_union(i: int) -> void:
	var a := int(D.UNION[i]["a"])
	var b := int(D.UNION[i]["b"])
	unions[a] = i
	weapons[a] = D.EVO_LV
	weapons.erase(b)

# ==================== 성장 ====================

## 경험치·코인에 걸리는 배수 — 아르카나 "황금 알"과 상점 "저주받은 인장"의 보상 쪽이다.
## **저주는 대가로 적을 빠르고 많게 만든다**(`World` 가 그쪽을 본다).
func xp_mult() -> float:
	var k := 1.0 + Sv.level(_curse_idx()) * D.CURSE_REWARD
	return k * (1.6 if has_flag("xp60") else 1.0)


## 코인에만 난이도가 걸린다. **경험치는 안 탄다**(`xp_mult`) — 경험치까지 올리면 어려운
## 난이도에서 레벨업이 빨라져 빌드가 더 빨리 완성되고, 그러면 어려운 쪽이 오히려 쉬워진다.
func coin_mult() -> float:
	return (1.0 + Sv.level(_curse_idx()) * D.CURSE_REWARD) * D.diff_coin()


static func _curse_idx() -> int:
	for i in D.SHOP.size():
		if String(D.SHOP[i]["kind"]) == "curse":
			return i
	return -1


func gain_xp(n: int) -> void:
	var v := int(round(float(n) * xp_mult()))
	xp += v
	round_xp += v


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


## 진화 조건을 갖춘 무기 — **만렙 + 짝 패시브 보유** 둘 다여야 한다.
## 패시브 레벨은 보지 않는다(1레벨이면 충분하다). 조건이 두 개인 것이 요점이고,
## 그 위에 레벨까지 요구하면 라운드 안에 도달할 수가 없다.
##
## **여기서 나온 것은 보물상자가 쓴다** — 레벨업 카드에는 진화가 없다(`open_chest`).
func evo_ready() -> Array:
	var out: Array = []
	for w: int in weapons.keys():
		if weapons[w] == D.MAX_LV and not unions.has(w) \
				and passives.has(int(D.WEAPON[w]["pair"])):
			out.append(w)
	return out


## 지금 몇 개나 진화시켰나 (해금 조건이 본다)
func evo_count() -> int:
	var n := 0
	for w: int in weapons.keys():
		if evolved(w):
			n += 1
	return n

# ==================== 보물상자 ====================

## 보스가 떨군 상자를 연다. **진화와 유니온이 먼저**고, 남은 칸을 보통 강화로 채운다.
##
## 돌려주는 값은 화면에 보여 줄 줄들이다 — `{"kind": 문양, "title": …, "sub": …}`.
## 뱀서와 같은 1·3·5 개이며(`D.CHEST_AMOUNTS`), 5개가 터지는 순간이 이 장치의 재미다.
func open_chest() -> Array:
	var out: Array = []
	var slots: int = int(D.CHEST_AMOUNTS[D.weighted(D.CHEST_WEIGHTS)])

	# 1) 유니온 — 제일 드물고 제일 크다
	for i: int in union_ready():
		if out.size() >= slots:
			break
		do_union(i)
		out.append({
			"kind": String(D.UNION[i]["kind"]), "title": String(D.UNION[i]["into_name"]),
			"sub": "유니온!", "col": P.VIOLET,
		})

	# 2) 진화
	for w: int in evo_ready():
		if out.size() >= slots:
			break
		weapons[w] = D.EVO_LV
		out.append({
			"kind": weapon_kind(w), "title": weapon_name(w),
			"sub": "진화!", "col": P.GOLD,
		})

	# 3) 남은 칸은 보통 강화로. 카드 후보와 같은 표를 쓰되 고르지 않고 그냥 준다.
	while out.size() < slots:
		var pool := roll_cards(1, true)
		if pool.is_empty():
			break
		var card: Dictionary = pool[0]
		apply_card(card)
		out.append({
			"kind": String(card.get("kind", "")), "title": String(card["title"]),
			"sub": String(card["sub"]), "col": card["col"],
		})
	return out


## 만렙까지 올렸는데 **짝 패시브가 없어서** 진화를 못 하는 무기들.
## 그 짝 패시브 카드를 앞으로 당기는 데 쓴다 — 안 그러면 "왜 진화가 안 뜨지"로 끝난다.
func evo_blocked() -> Array:
	var out: Array = []
	for w: int in weapons.keys():
		if weapons[w] == D.MAX_LV and not passives.has(int(D.WEAPON[w]["pair"])):
			out.append(w)
	return out


func pair_name(w: int) -> String:
	return String(D.PASSIVE[int(D.WEAPON[w]["pair"])]["name"])

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
## **진화는 여기 없다 — 보물상자로 옮겼다**(`open_chest`). 대신 짝 패시브가 없어 진화가
## 막힌 스킬이 있으면 그 패시브를 맨 앞에 끼운다. 만렙을 찍어 놓고도 아무 일이 안 일어나면
## 왜인지 화면에 답이 없기 때문이다.
##
## `quiet` 는 보물상자가 부를 때다 — 우선 카드(짝 패시브 안내)를 끼우지 않고 그냥 뽑는다.
## 상자는 고르는 화면이 아니라 결과를 보여 주는 화면이라 안내가 낄 자리가 없다.
##
## **지운(밴) 카드는 후보에서 통째로 빠진다.** 그 판이 끝날 때까지 다시 안 나온다.
func roll_cards(n: int, quiet: bool = false) -> Array:
	var pool: Array = []

	var want_p := {}
	for w: int in evo_blocked():
		want_p[int(D.WEAPON[w]["pair"])] = w
	if not quiet and passives.size() < D.MAX_PASSIVES:
		for i: int in want_p.keys():
			if passives.has(i) or banished.has("p%d" % i):
				continue
			var prow: Dictionary = D.PASSIVE[i]
			pool.append({
				"type": "passive", "id": i, "to": 1, "kind": String(prow["kind"]),
				"title": prow["name"], "sub": "%s 진화에 필요" % String(D.WEAPON[want_p[i]]["name"]),
				"desc": prow["desc"], "col": P.CYAN, "prio": true,
			})

	for w: int in weapons.keys():
		var lv: int = weapons[w]
		# 만렙과 진화는 더 줄 것이 없다 — 그 위는 보물상자와 리미트 브레이크의 몫이다.
		if lv >= D.MAX_LV or banished.has("w%d" % w):
			continue
		var row: Dictionary = D.WEAPON[w]
		# 만렙 직전이면 그때 무엇이 더 필요한지 미리 알려 준다.
		var hint := String(row["desc"])
		if lv + 1 >= D.MAX_LV:
			hint = "만렙까지 한 칸. 진화하려면 짝 패시브 %s 를 들고 보스의 상자를 열어야 한다." \
				% pair_name(w)
		pool.append({
			"type": "weapon", "id": w, "to": lv + 1, "kind": String(row["kind"]),
			"title": row["name"], "sub": "Lv.%d → %d" % [lv, lv + 1],
			"desc": hint, "col": P.CRIMSON, "prio": false,
		})

	if weapons.size() < D.MAX_WEAPONS:
		for w in D.WEAPON.size():
			if weapons.has(w) or banished.has("w%d" % w):
				continue
			var row2: Dictionary = D.WEAPON[w]
			# 남의 직업 스킬인데 내 직업 전용 진화가 있으면 카드에서 미리 알려 준다 —
			# 그걸 모르면 "왜 남의 스킬을 굳이 키우나"에 대한 답이 화면에 없다.
			var mine2: bool = int(row2["cls"]) == cls()
			var sub := "새 스킬" if mine2 else "%s 스킬" % D.CLASS_NAME[int(row2["cls"])]
			if not mine2 and not evo_alt(w).is_empty():
				sub += " · %s 진화 가능" % class_name_()
			pool.append({
				"type": "weapon", "id": w, "to": 1, "kind": String(row2["kind"]),
				"title": row2["name"], "sub": sub,
				"desc": "%s 짝 패시브는 %s." % [String(row2["desc"]), pair_name(w)],
				"col": P.ORANGE if mine2 else P.VIOLET, "prio": false,
			})

	# 패시브 — 새로 들거나(`MAX_PASSIVES` 까지) 갖고 있는 것을 올린다.
	for i in D.PASSIVE.size():
		var prow2: Dictionary = D.PASSIVE[i]
		var plv := plevel(i)
		if plv >= D.MAX_PLV or banished.has("p%d" % i):
			continue
		if plv == 0 and passives.size() >= D.MAX_PASSIVES:
			continue
		if not quiet and want_p.has(i) and plv == 0:
			continue          # 위에서 이미 우선 카드로 넣었다
		pool.append({
			"type": "passive", "id": i, "to": plv + 1, "kind": String(prow2["kind"]),
			"title": prow2["name"],
			"sub": "새 패시브" if plv == 0 else "Lv.%d → %d" % [plv, plv + 1],
			"desc": prow2["desc"], "col": P.CYAN, "prio": false,
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
	# **패시브는 편향을 안 받는다** — `id` 가 스킬 번호가 아니라 패시브 번호라
	# `suits()` 에 넘기면 엉뚱한 스킬을 본다.
	for card: Dictionary in rest:
		var bias := 0.0
		if String(card["type"]) != "passive" and int(card["id"]) >= 0:
			bias = CLASS_BIAS if suits(int(card["id"])) else 0.0
		card["_k"] = randf() - bias
	rest.sort_custom(func(a, b): return float(a["_k"]) < float(b["_k"]))

	var out: Array = []
	for card: Dictionary in forced:
		if out.size() < n:
			out.append(card)
	for card: Dictionary in rest:
		if out.size() >= n:
			break
		out.append(card)

	# **더 올릴 데가 없으면 리미트 브레이크다.** 뱀서와 같은 자리 — 판이 끝나기 전에
	# 남은 레벨업이 통째로 버려지지 않게 전체 스텟을 조금씩 올린다.
	# 상한이 없으므로 카드가 마르지 않는다(예전의 구급 상자 채우기를 대신한다).
	var li := 0
	while out.size() < n:
		var row3: Dictionary = D.LIMIT[li % D.LIMIT.size()]
		li += 1
		out.append({
			"type": "limit", "id": li - 1, "to": 0, "kind": String(row3["kind"]),
			"title": "리미트 브레이크", "sub": String(row3["name"]),
			"desc": "%s 이(가) 영구히 조금 오른다. 이 라운드 동안." % String(row3["name"]),
			"col": P.GOLD_HI, "prio": false,
		})
	return out


## 카드 한 장을 이 판에서 영구히 지운다(밴). 남은 횟수를 쓴다.
func banish(card: Dictionary) -> bool:
	if banish_left <= 0:
		return false
	var t := String(card["type"])
	if t != "weapon" and t != "passive":
		return false          # 리미트 브레이크·회복은 지울 것이 없다
	banish_left -= 1
	banished["%s%d" % ["w" if t == "weapon" else "p", int(card["id"])]] = true
	return true


func apply_card(card: Dictionary) -> void:
	match String(card["type"]):
		"weapon":
			weapons[int(card["id"])] = int(card["to"])
		"passive":
			passives[int(card["id"])] = int(card["to"])
		"limit":
			var row: Dictionary = D.LIMIT[int(card["id"]) % D.LIMIT.size()]
			var st := String(row["stat"])
			limit[st] = float(limit.get(st, 0.0)) + float(row["val"])
		"heal":
			heal(max_hp() * D.HEAL_PCT)
