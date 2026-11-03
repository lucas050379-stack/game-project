class_name Play
extends RefCounted

## 한 판의 규칙 — 이동 횟수 · 점수 · 미션 · 특수 조합 · 턴 끝. 그리기 · 시간을 모른다.
##
## main.gd 는 이 함수들을 **애니메이션 사이사이에 하나씩** 부르고, check.gd 의 봇은
## `play_move()` 로 한 번에 부른다. 둘이 같은 순서를 지나야 봇이 잰 난이도가 실제와 같다:
##
##   begin(a, b)  →  [ fall() → collect() 가 있으면 다시 fall() → cascade() ]  반복
##                →  더 안 터지면: 이겼나 · 졌나 · 아니면 turn_end() → 섞기

var stage: Dictionary
var b: Board
var moves_left := -1      ## -1 = 이동 제한 없음(타임 어택)
var score := 0
var chain := 0            ## 이번 수 안에서 몇 번째 터짐인가
var mul := 1.0            ## 타임 어택의 콤보 · 피버 배율. 스테이지 모드는 1
var goals := []           ## {type, color, need}
var collected := PackedInt32Array()
var fruit_got := 0
var choco_broken := false
## 턴 끝에 레이저 · 로켓이 맞힌 칸 — fire_pending() 이 터뜨린다
var pending_fire := PackedInt32Array()
## 턴 끝에 판에 빈 칸이 생겼다(먹보가 먹었다) — 부르는 쪽이 fall 을 돌려야 한다
var holes_made := false

const JAR_N := 6    ## 색 그릇 하나를 채우는 데 드는 젤리 수
const LOCK_N := 15   ## 숫자 자물쇠 하나를 여는 데 드는 젤리 수
const GOAL_TYPES := ["score", "collect", "sugar", "box", "choco", "ice", "chain", "fruit", "monster"]


## 지도 기호 — rows:
##   .  젤리     #  구멍     1 2 3  쿠키 상자(겹)     c  초콜릿     f  열매
##   l  사슬 젤리     i I  얼음 젤리(1 · 2겹)     D  꾸덕이     K  매듭이     T  슬쩍이(도둑)
##   G g  톱니(시계 · 반시계)     W  바람개비     > < ^ v  푸시 상자(나아갈 방향)
##   O  캡슐     Z  레이저 포대     R  드릴 로켓     F  얼음뿔
##   X  숫자 자물쇠(색은 자리로, 수는 LOCK_N)     P  선물 상자     S  증기 기계     d  주사위 젤리
##   q  유리 상자 + 줄 폭탄     Q  유리 상자 + 범위 폭탄     N  그림자     E  먹보
##   s  강철 젤리     p  끈끈이 식물     M  두더지     U  모닥불     J  색 그릇     H  문어발     Y  대왕꾸덕
## csugar(없어도 됨):  0~6  색 설탕막(그 색 젤리로만)
## web   (없어도 됨):  1 2  거미줄 겹
## paint (없어도 됨):  p  처음부터 칠해진 칸
## rise  (없어도 됨):  솟는 줄인 세로줄 번호 배열 [x, ...]
## cloud (없어도 됨):  o  구름
## dir   (없어도 됨):  > < ^ v  레이저 · 로켓이 쏘는 방향(없으면 오른쪽)
## field (없어도 됨):  m  자기장(광선이 그 앞에서 멈춘다)
## pipe  (없어도 됨):  7 F J L  파이프 꺾임 — ┐ ┌ ┘ └
## floor (없어도 됨):  .  없음     1 2 3  설탕막 겹
## belt  (없어도 됨):  .  없음     > < ^ v  벨트 방향 — 반드시 닫힌 고리
## portal(없어도 됨):  a~e  입구(조각이 아래로 빠짐)     A~E  같은 글자의 출구(위로 나옴)
func _init(st: Dictionary, seed_: int = -1) -> void:
	stage = st
	var rows: Array = st.rows
	var hh := rows.size()
	var ww: int = String(rows[0]).length()
	b = Board.new(seed_, ww, hh, int(st.get("colors", D.COLORS)))
	if st.has("palette"):
		b.palette = PackedInt32Array(st.palette)
		b.colors = b.palette.size()
	var fl: Array = st.get("floor", [])
	var bl: Array = st.get("belt", [])
	var pt: Array = st.get("portal", [])
	var dl: Array = st.get("dir", [])
	var cs_: Array = st.get("csugar", [])
	var cl: Array = st.get("cloud", [])
	var glass_sp := {}
	var steel_at := []
	var wb: Array = st.get("web", [])
	var pn: Array = st.get("paint", [])
	for x in st.get("rise", []):
		b.rise[int(x)] = 1
	var fd: Array = st.get("field", [])
	var pp: Array = st.get("pipe", [])
	var entries := {}
	var exits := {}
	for y in hh:
		for x in ww:
			var i := y * ww + x
			var ch: String = rows[y][x]
			match ch:
				"#":
					b.hole[i] = 1
				"1", "2", "3":
					b.col[i] = Board.BOX
					b.lay[i] = int(ch)
				"c":
					b.col[i] = Board.CHOCO
				"f":
					b.col[i] = Board.FRUIT
				"l":
					b.chain[i] = 1
				"i":
					b.ice[i] = 1
				"I":
					b.ice[i] = 2
				"G", "g":
					b.col[i] = Board.GEAR
					b.gear_dir[i] = 1 if ch == "G" else -1
				"W":
					b.col[i] = Board.WIND
				">", "<", "^", "v":
					b.col[i] = Board.PUSH
					b.push_dir[i] = {">": Vector2i.RIGHT, "<": Vector2i.LEFT, "^": Vector2i.UP, "v": Vector2i.DOWN}[ch]
				"O":
					b.col[i] = Board.CAPSULE
				"Z", "R":
					b.col[i] = Board.LASER if ch == "Z" else Board.ROCKET
					var dc: String = dl[y][x] if not dl.is_empty() else ">"
					b.dev_dir[i] = {">": Vector2i.RIGHT, "<": Vector2i.LEFT, "^": Vector2i.UP, "v": Vector2i.DOWN}.get(dc, Vector2i.RIGHT)
					if ch == "Z":
						b.charge[i] = 0
					else:
						# 로켓 색은 자리로 정한다 — 같은 판은 언제나 같은 색
						b.dev_color[i] = b.palette[(x + y) % b.palette.size()]
				"X":
					b.col[i] = Board.LOCK
					b.lock_c[i] = b.palette[(x * 2 + y) % b.palette.size()]
					b.lock_n[i] = LOCK_N
				"P":
					b.col[i] = Board.GIFT
				"S":
					b.col[i] = Board.STEAM
					b.steam_cd[i] = Board.STEAM_EVERY
				"d":
					b.dice[i] = 1
				"q", "Q":
					b.glass[i] = 1
					glass_sp[i] = D.SP_LINE_H if ch == "q" else D.SP_AREA
				"s":
					steel_at.append(i)
				"p":
					b.col[i] = Board.PLANT
				"M":
					b.col[i] = Board.MOLE
					b.mole_hp[i] = Board.MOLE_HP
				"U":
					b.col[i] = Board.FIRE
					b.fire_t[i] = 0
				"J":
					b.col[i] = Board.JAR
					b.jar_c[i] = b.palette[(x + 2 * y) % b.palette.size()]
					b.jar_n[i] = JAR_N
				"D", "K", "T", "F", "N", "E", "H", "Y":
					var kind: String = {"D": "dough", "K": "knot", "T": "thief", "F": "frost", "N": "ninja",
							"E": "glutton", "H": "octo", "Y": "boss"}[ch]
					var spec: Dictionary = D.MON[kind]
					b.col[i] = Board.MON
					b.mons[i] = {"kind": kind, "hp": spec.hp, "max": spec.hp, "every": spec.every,
							"cd": spec.every, "target": PackedInt32Array()}
			if not fl.is_empty() and "123".contains(fl[y][x]):
				b.sugar[i] = int(fl[y][x])
			if not bl.is_empty():
				b.belt[i] = "^>v<".find(bl[y][x]) + 1
			if not fd.is_empty() and fd[y][x] == "m":
				b.field[i] = 1
			if not pp.is_empty():
				b.pipe[i] = "7FJL".find(pp[y][x]) + 1
				if b.pipe[i] > 0:
					b.hole[i] = true   # 파이프 칸은 젤리 자리가 아니다 — 배관 그림 위에 젤리가 얹혀 보여 바꿨다
					b.col[i] = Board.EMPTY
			if not cs_.is_empty() and "0123456".contains(cs_[y][x]):
				b.csugar[i] = int(cs_[y][x]) + 1
			if not cl.is_empty() and cl[y][x] == "o":
				b.cloud[i] = 1
			if not wb.is_empty() and "12".contains(wb[y][x]):
				b.web[i] = int(wb[y][x])
			if not pn.is_empty() and pn[y][x] == "p":
				b.paint[i] = 1
			if not pt.is_empty() and pt[y][x] != ".":
				var key: String = String(pt[y][x]).to_lower()
				if pt[y][x] == key:
					entries[key] = i
				else:
					exits[key] = i
	for key in exits:
		if entries.has(key):
			b.portal[exits[key]] = entries[key]
			b.portal_in[entries[key]] = exits[key]
	b.fill_new()
	# 유리 상자 안의 특수 젤리 — 색을 다 깐 다음에 얹는다(맞춰진 줄 검사에 안 걸리게)
	for i in glass_sp:
		b.sp[i] = glass_sp[i]
	# 강철 젤리 — 색은 깔린 대로 두고 표시만 붙인다
	for i in steel_at:
		b.steel[i] = 1
	moves_left = int(st.get("moves", -1))
	collected.resize(Board.RAINBOW_C + 1)
	collected.fill(0)
	for g in st.get("goals", []):
		goals.append({"type": g.type, "color": int(g.get("color", -1)), "need": int(g.get("n", 0))})
	# 몬스터 미션 아이콘은 판에 있는 몬스터 얼굴로
	for m in b.mons.values():
		for g in goals:
			if g.type == "monster":
				g.kind = m.kind
		break


func timed() -> bool:
	return moves_left < 0

# ==================== 미션 ====================

## 남은 양. 0 이면 그 미션은 끝.
func left(g: Dictionary) -> int:
	match g.type:
		"score":
			return maxi(0, g.need - score)
		"collect":
			return maxi(0, g.need - collected[g.color])
		"fruit":
			return maxi(0, g.need - fruit_got)
		"sugar":
			return _count(func(i): return b.sugar[i] > 0 or b.csugar[i] > 0)
		"lock":
			return b.count(Board.LOCK)
		"cloud":
			return _count(func(i): return b.cloud[i] > 0)
		"web":
			return _count(func(i): return b.web[i] > 0)
		"mole":
			return b.count(Board.MOLE)
		"fire":
			# 모닥불은 "지금 꺼져 있는 수" — 전부 동시에 켜져 있어야 끝난다
			return _count(func(i): return b.col[i] == Board.FIRE and int(b.fire_t.get(i, 0)) == 0)
		"paint":
			return _count(func(i): return not b.hole[i] and b.paint[i] == 0 and b.col[i] != Board.STEAM \
					and b.col[i] != Board.GEAR)
		"jar":
			return b.count(Board.JAR)
		"box":
			return b.count(Board.BOX)
		"choco":
			return b.count(Board.CHOCO)
		"ice":
			return _count(func(i): return b.ice[i] > 0)
		"chain":
			return _count(func(i): return b.chain[i] > 0)
		"monster":
			return b.mons.size()
		"capsule":
			return b.count(Board.CAPSULE)
	return 0


func _count(f: Callable) -> int:
	var n := 0
	for i in b.w * b.h:
		if f.call(i):
			n += 1
	return n


func won() -> bool:
	if goals.is_empty():
		return false
	for g in goals:
		if left(g) > 0:
			return false
	return true


func lost() -> bool:
	return not timed() and moves_left <= 0 and not won()


## 이기면 별 하나, 점수가 stars[0] · stars[1] 을 넘으면 둘 · 셋.
func stars() -> int:
	if not won():
		return 0
	var th := star_marks()
	return 1 + int(score >= th[0]) + int(score >= th[1])


## 별 둘 · 셋 문턱. 스테이지가 안 정했으면 이동 수에 비례해서 잡는다.
func star_marks() -> Array:
	if stage.has("stars"):
		return stage.stars
	var m := int(stage.get("moves", 20))
	return [m * D.STAR2_PER_MOVE, m * D.STAR3_PER_MOVE]


## 아직 위에서 내려보내야 할 열매 수.
func _fruit_to_spawn() -> int:
	var need := 0
	for g in goals:
		if g.type == "fruit":
			need = g.need
	return maxi(0, need - fruit_got - b.count(Board.FRUIT))

# ==================== 한 수 ====================

func can_swap(a: int, c: int) -> bool:
	return (timed() or moves_left > 0) and b.is_swap_valid(a, c)


## 바꾸고 첫 터짐까지. 맞춤이 없으면 부르지 않는다(`can_swap` 이 먼저 거른다).
func begin(a: int, c: int) -> Dictionary:
	b.swap(a, c)
	if not timed():
		moves_left -= 1
	chain = 0
	choco_broken = false
	if b.is_special_swap(a, c):
		var cb := _combo(a, c)
		return _step(PackedInt32Array([a, c]), cb.forced, cb.pre, {"combo": cb.kind, "at": c, "from": a})
	return _step(PackedInt32Array([a, c]), PackedInt32Array(), {}, {})


## 떨어진 뒤 또 맞은 것이 있으면 터뜨린다. 없으면 빈 사전.
func cascade() -> Dictionary:
	if b.find_groups().is_empty():
		return {}
	return _step(PackedInt32Array(), PackedInt32Array(), {}, {})


func fall() -> Dictionary:
	b.spawn_fruit = _fruit_to_spawn()
	return b.fall()


func collect() -> PackedInt32Array:
	var got := b.collect_fruits()
	fruit_got += got.size()
	return got


## 더 터질 것이 없을 때 한 번. 순서: 초콜릿 → 벨트 → 톱니 → 푸시 상자 → 바람개비 → 몬스터.
## 장치가 조각을 옮기면 그 사이에 줄이 맞을 수 있다 — 부르는 쪽이 다시 cascade 를 돌린다.
## 돌려주는 것: {events: [...], moves: [{from, to}]} (moves 는 장치가 옮긴 조각, 그림용)
func turn_end() -> Dictionary:
	var ev := []
	if not choco_broken:
		var t := b.choco_spread()
		if t >= 0:
			ev.append({"type": "choco_grow", "i": t})
	b.perm_begin()
	b.belts_step()
	b.gears_step()
	b.push_step()
	b.winds_step()
	b.rise_step()
	b.mole_step()
	var moved := b.perm_end()
	var web_t := b.web_spread()
	if web_t >= 0:
		ev.append({"type": "web_grow", "i": web_t})
	for c in b.camp_step():
		ev.append({"type": "fire_out", "i": c})
	var rolled := b.dice_step()
	var puffs := b.steam_step()
	for e in b.monster_turn():
		if e.type == "steal" and not timed():
			moves_left = maxi(0, moves_left - 1)
		if e.type == "eat":
			holes_made = true
		ev.append(e)
	var shot := b.fire_step()
	pending_fire = shot.cells
	return {"events": ev, "moves": moved, "shots": shot.shots, "dice": rolled, "puffs": puffs}


## 턴 끝에 쏜 레이저 · 로켓이 맞힌 칸을 터뜨린다. 쏜 것이 없으면 빈 사전.
func fire_pending() -> Dictionary:
	if pending_fire.is_empty():
		return {}
	var f := pending_fire
	pending_fire = PackedInt32Array()
	return _step(PackedInt32Array(), f, {}, {})


func _step(prefer: PackedInt32Array, forced: PackedInt32Array, pre: Dictionary, info: Dictionary) -> Dictionary:
	chain += 1
	var r := b.resolve(prefer, forced, pre)
	for e in r.cleared:
		collected[e.c] += 1
	for ev in r.events:
		if ev.type == "choco":
			choco_broken = true
		elif ev.type == "mon_dead":
			moves_left += int(ev.stolen)   # 슬쩍이가 훔쳐 간 이동을 돌려받는다
	if b.gift_moves > 0 and not timed():
		moves_left += b.gift_moves
		r.gift_moves = b.gift_moves
	b.gift_moves = 0
	var n: int = r.cleared.size()
	var made := 0
	for m in r.made:
		made += int(D.MADE_PTS.get(int(m.sp), 0))
	var combo := int(D.COMBO_PTS.get(String(info.get("combo", "")), 0))
	var pts := int((n * D.BLOCK_PTS + r.fired.size() * D.SP_BONUS + r.events.size() * D.OBS_PTS + made + combo)
			* (1.0 + (chain - 1) * D.CHAIN_STEP) * mul)
	score += pts
	r.points = pts
	r.merge(info)
	return r


## 특수끼리(무지개 포함) 바꿨을 때 — 둘이 따로 터지는 대신 합쳐진 효과를 낸다.
##   줄+줄 십자 · 범위+범위 5×5 · 줄+범위 세 줄씩 십자
##   날개+날개 셋이 날아감 · 날개+줄/범위 날개가 그 효과를 싣고 감
##   무지개+젤리 그 색 전부 · 무지개+특수 그 색을 전부 그 특수로 바꿔 터뜨림 · 무지개+무지개 판 전부
func _combo(a: int, c: int) -> Dictionary:
	var sa := b.sp[a]
	var sc := b.sp[c]
	var R := D.SP_RAINBOW
	var forced := PackedInt32Array([a, c])
	var pre := {}
	var kind := ""
	if sa == R or sc == R:
		var r := a if sa == R else c
		var o := c if r == a else a
		pre[r] = true
		if b.sp[o] == R:
			kind = "rainbow2"
			pre[o] = true
			for i in b.w * b.h:
				if not b.hole[i]:
					forced.append(i)
		elif b.sp[o] == D.SP_NONE:
			kind = "rainbow"
			forced.append_array(b.cells_of(b.col[o]))
		else:
			kind = "rainbow_sp"
			var k := b.sp[o]
			for i in b.cells_of(b.col[o]):
				if b.chain[i] == 0 and b.ice[i] == 0 and b.sp[i] == D.SP_NONE:
					if k == D.SP_LINE_H or k == D.SP_LINE_V:
						b.sp[i] = D.SP_LINE_H if b.rng.randf() < 0.5 else D.SP_LINE_V
					else:
						b.sp[i] = k
				forced.append(i)
		return {"forced": forced, "pre": pre, "kind": kind}

	var lines := [D.SP_LINE_H, D.SP_LINE_V]
	var la: bool = lines.has(sa)
	var lc: bool = lines.has(sc)
	if la and lc:
		kind = "cross"
		forced.append_array(b.shape(c, D.SP_LINE_H))
		forced.append_array(b.shape(c, D.SP_LINE_V))
		pre = {a: true, c: true}
	elif sa == D.SP_AREA and sc == D.SP_AREA:
		kind = "big"
		forced.append_array(b.shape(c, D.SP_AREA, D.BIG_R))
		pre = {a: true, c: true}
	elif (la and sc == D.SP_AREA) or (lc and sa == D.SP_AREA):
		kind = "bigcross"
		var y := b.cy(c)
		var x := b.cx(c)
		for d in [-1, 0, 1]:
			if y + d >= 0 and y + d < b.h:
				forced.append_array(b.shape((y + d) * b.w + x, D.SP_LINE_H))
			if x + d >= 0 and x + d < b.w:
				forced.append_array(b.shape(y * b.w + x + d, D.SP_LINE_V))
		pre = {a: true, c: true}
	elif sa == D.SP_FLY and sc == D.SP_FLY:
		kind = "fly2"
		# 둘은 각자 날아가고 하나가 더 난다
		forced.append(b.fly_target(c, {a: true, c: true}))
	else:
		kind = "fly_carry"
		var f := a if sa == D.SP_FLY else c
		var o := c if f == a else a
		b.fly_carry[f] = b.sp[o]
		pre[o] = true
	return {"forced": forced, "pre": pre, "kind": kind}

# ==================== 보너스 ====================

## 이겼는데 이동이 남았다 — 하나당 보통 젤리 하나를 줄 폭탄으로. 더 없으면 -1.
func bonus_pick() -> int:
	if moves_left <= 0:
		return -1
	var opts := []
	for i in b.w * b.h:
		if b.plain(i):
			opts.append(i)
	if opts.is_empty():
		moves_left = 0
		return -1
	var t: int = opts[b.rng.randi() % opts.size()]
	b.sp[t] = D.SP_LINE_H if b.rng.randf() < 0.5 else D.SP_LINE_V
	moves_left -= 1
	score += D.BONUS_MOVE_PTS
	return t


## 판에 남은 특수 젤리를 한꺼번에 터뜨린다.
func bonus_fire() -> Dictionary:
	var forced := PackedInt32Array()
	for i in b.w * b.h:
		if b.is_jelly(i) and b.sp[i] != D.SP_NONE:
			forced.append(i)
	if forced.is_empty():
		return {}
	chain = 0
	return _step(PackedInt32Array(), forced, {}, {})

# ==================== 헤드리스 (봇) ====================

func settle() -> void:
	for _guard in 300:
		fall()
		if not collect().is_empty():
			continue
		if cascade().is_empty():
			return


## 이긴 뒤 보너스를 끝까지 — 남은 이동을 줄 폭탄으로 바꾸고 한꺼번에 터뜨린다.
func finish_bonus() -> void:
	while bonus_pick() >= 0:
		pass
	if not bonus_fire().is_empty():
		settle()


## 한 수를 끝까지 — main.gd 가 애니메이션 사이에 부르는 순서와 같다.
func play_move(a: int, c: int) -> void:
	begin(a, c)
	settle()
	if won() or lost():
		return
	turn_end()
	fire_pending()
	settle()
	if not b.has_move():
		b.shuffle()
