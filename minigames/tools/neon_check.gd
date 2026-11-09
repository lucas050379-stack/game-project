extends SceneTree

## 네온 서바이버 검산 — 그리기 없이 NvGame · NvWorld 만, 고정 dt 로 봇이 라운드를 버틴다(docs/design/neon.md 재정비 8-3).
##   godot --headless --path . --script res://tools/neon_check.gd -- [판 수 1] [라운드 목록 1,20,50]
## 라운드 n 마다 상점 기본 강화 넷(체력 · 공격력 · 재사용 · 수집 범위)을 `req_lv(n)` 단계로 맞춘다 — 원본의 등식
## "라운드 n 은 전 항목 req_lv(n)강이면 클리어" 가 살아 있으면 라운드끼리 생존 비율이 비슷하게 나온다.
## 봇은 main.gd 의 --neon-auto 와 같은 방식(가까운 적에게서 멀어지며 젬 쪽으로, 카드 · 아르카나는 무작위).
## 실패(종료 코드 1): 판이 안 끝남 · 적 수가 상한(NvD.ENEMY_CAP)을 넘음 · 위치가 NaN.

const DT := 1.0 / 30.0
const STAT_SHOP := 4   ## NvD.SHOP 앞 넷이 기본 강화(체력 · 공격력 · 재사용 · 수집 범위)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 1
	var rounds: Array = (args[1] if args.size() > 1 else "1,20,50").split(",")
	NvSv.no_save = true
	var fail := false
	print("라운드  기체  클리어  버틴 비율(중앙)  레벨  진화  처치  최대 적 수")
	for rs in rounds:
		var n := int(rs)
		var lv := int(round(NvD.req_lv(n)))
		NvSv.upgrades = {}
		for i in STAT_SHOP:
			NvSv.upgrades[i] = mini(lv, int(NvD.SHOP[i]["max"]))
		for ch in 3:
			var clears := 0
			var fracs: Array = []
			var lvl := 0
			var evo := 0
			var kills := 0
			var peak := 0
			for r in runs:
				seed(1000 + r * 31 + ch * 7 + n)
				var res := _run(ch, n)
				if res.bad != "":
					print("  FAIL 라운드 %d 기체 %d: %s" % [n, ch, res.bad])
					fail = true
				clears += 1 if res.clear else 0
				fracs.append(float(res.time) / NvD.round_time(n))
				lvl += int(res.level)
				evo += int(res.evo)
				kills += int(res.kills)
				peak = maxi(peak, int(res.peak))
			fracs.sort()
			print("%5d  %s  %d/%d  %4.0f%%  %4.1f  %4.1f  %6d  %d" % [n, NvD.CHAR[ch]["name"], clears, runs,
					100.0 * float(fracs[fracs.size() / 2]), float(lvl) / runs, float(evo) / runs, kills / runs, peak])
	print("NEON CHECK FAIL" if fail else "NEON CHECK OK")
	quit(1 if fail else 0)


func _run(ch: int, n: int) -> Dictionary:
	var g := NvGame.new(ch, n)
	var w := NvWorld.new(g, NvFx.new())
	var peak := 0
	var limit := NvD.round_time(n) * 1.5 / DT   # 라운드 시간의 1.5배를 넘기면 "안 끝남"
	var steps := 0
	while not w.dead and not w.cleared:
		steps += 1
		if steps > limit:
			return {bad = "안 끝남", clear = false, time = g.time, level = g.level, evo = g.evo_count(), kills = g.kills, peak = peak}
		w.update(DT, _bot_dir(w))
		peak = maxi(peak, w.enemies.size())
		if w.enemies.size() > NvD.ENEMY_CAP:
			return {bad = "적 수 %d > 상한" % w.enemies.size(), clear = false, time = g.time, level = g.level, evo = 0, kills = g.kills, peak = peak}
		if is_nan(w.pos.x) or is_nan(w.pos.y):
			return {bad = "위치 NaN", clear = false, time = g.time, level = g.level, evo = 0, kills = g.kills, peak = peak}
		if w.chest_ready:
			w.chest_ready = false
			g.open_chest()
		elif g.arcana_due():
			var arc: Array = g.roll_arcana(3)
			if arc.is_empty():
				g.arcana_at += 1
			else:
				g.take_arcana(int(arc[randi() % arc.size()]))
		while g.can_level():
			g.level_up()
			var cards: Array = g.roll_cards(NvD.CARD_COUNT)
			if cards.is_empty():
				break
			g.apply_card(cards[randi() % cards.size()])
	return {bad = "", clear = w.cleared, time = g.time, level = g.level, evo = g.evo_count(), kills = g.kills, peak = peak}


## main.gd `_bot_dir` 와 같은 봇.
func _bot_dir(w: NvWorld) -> Vector2:
	var away := Vector2.ZERO
	for e: Dictionary in w.enemies:
		var d: Vector2 = w.pos - (e["p"] as Vector2)
		var l2 := maxf(400.0, d.length_squared())
		if l2 < 360000.0:
			away += d / l2
	var to_gem := Vector2.ZERO
	var best := 1e12
	for gm: Dictionary in w.gems:
		var d2: float = (gm["p"] as Vector2).distance_squared_to(w.pos)
		if d2 < best:
			best = d2
			to_gem = (gm["p"] as Vector2) - w.pos
	var v := away.normalized() + to_gem.normalized() * 0.35
	var m := 200.0
	if w.pos.x < m: v.x += 1.0
	if w.pos.y < m: v.y += 1.0
	if w.pos.x > w.arena.x - m: v.x -= 1.0
	if w.pos.y > w.arena.y - m: v.y -= 1.0
	return v.normalized() if v.length_squared() > 0.0001 else Vector2.RIGHT
