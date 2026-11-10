class_name SaBoss2
extends RefCounted

## 조각 보스(스카이 갈아엎기 — docs/design/sky2.md). **화면보다 큰 몸**에 부위(포탑 · 엔진 · 미사일대)가 붙어 있고,
## 부위마다 체력이 따로 있다. 부위가 죽으면 그 무기가 꺼지고, 그 자리가 **부서진 그림으로 바뀌고 연기가 난다**.
## 그림은 전체 한 장(`full`)과 같은 구도의 부서진 전체(`wreck`), 포탑을 뺀 몸(`bare` — 있으면 그 위에 도는 포탑을 얹는다).
##
## 보스는 **묶음(group)** 을 차례로 싸운다 — 묶음마다 "화면이 보는 자리(view)"가 있어, 한 묶음을 다 부수면 몸이 미끄러져
## 다음 묶음이 화면에 들어온다(가로로 큰 것은 옆으로, 세로로 긴 것은 위아래로 훑는다). 마지막은 핵(core) — 몸에 박힌 핵이거나 안에서 나오는 로봇.
## 표(`SPECS`)에 보스 하나를 더하면 된다. 부위 자리는 그림 안의 비율(0~1) — `tools/sky_boss_grid.py` 로 눈금을 얹어 잰다.
## 월드(`SaWorld`)는 `step` · `hit_bullet` · `hit_column` · `hurt_all` · `touches` · `draw` 만 부른다.

const ROBOT_R := 58.0
const ANCHOR_Y := 200.0        ## 지금 싸우는 묶음의 view 점이 놓이는 화면 y
## 부위 종류 → [쏘는 간격, 반지름 기본]. 엔진 · 해치는 안 쏜다.
const FIRE := {turret = 1.7, rack = 3.0, aa = 1.1, big = 2.4}

## 부위: [이름, 묶음, 그림 안 자리(0~1), 반지름, 체력, 종류]
const SPECS := {
	bomber2 = {
		name = "초거대 폭격기 「운룡」", score = 32000, width_k = 2.2, tex = "sky2_boss3", turret = "sky2_turret_3", turret_big = "sky2_turret_big_3",
		groups = [{view = Vector2(0.23, 0.40), label = "왼쪽 날개", rect = Rect2(0.0, 0.0, 0.39, 1.0)},
				{view = Vector2(0.77, 0.40), label = "오른쪽 날개", rect = Rect2(0.61, 0.0, 0.39, 1.0)}],
		parts = [
			["t1", 0, Vector2(0.114, 0.276), 30.0, 160.0, "turret"], ["t2", 0, Vector2(0.224, 0.263), 30.0, 160.0, "turret"],
			["t3", 0, Vector2(0.325, 0.308), 30.0, 160.0, "turret"], ["e1", 0, Vector2(0.240, 0.519), 34.0, 240.0, "engine"],
			["e2", 0, Vector2(0.325, 0.544), 34.0, 240.0, "engine"], ["m1", 0, Vector2(0.139, 0.429), 30.0, 120.0, "rack"],
			["t4", 1, Vector2(0.675, 0.308), 30.0, 160.0, "turret"], ["t5", 1, Vector2(0.776, 0.263), 30.0, 160.0, "turret"],
			["t6", 1, Vector2(0.886, 0.276), 30.0, 160.0, "turret"], ["e3", 1, Vector2(0.675, 0.544), 34.0, 240.0, "engine"],
			["e4", 1, Vector2(0.760, 0.519), 34.0, 240.0, "engine"], ["m2", 1, Vector2(0.861, 0.429), 30.0, 120.0, "rack"],
		],
		core = {kind = "robot", f = Vector2(0.5, 0.416), view = Vector2(0.5, 0.40), hp = 900.0, tex = "sky2_boss3_robot",
				rect = Rect2(0.39, 0.0, 0.22, 1.0), label = "기동 병기", leave = true},
	},
	# 1라운드 — 바다 요새. 한 화면에 다 들어온다(규칙을 배우는 보스): 포 팔 여섯 + 대공포 넷 → 가운데 돔의 핵
	fort1 = {
		name = "해상 요새 「해룡」", score = 20000, width_k = 1.0, tex = "sky2_boss1", ground = true, turret = "sky2_turret_1", turret_big = "sky2_turret_big_1",
		groups = [{view = Vector2(0.5, 0.44), label = "포 팔"}],
		parts = [
			["a1", 0, Vector2(0.50, 0.08), 30.0, 150.0, "turret"], ["a2", 0, Vector2(0.88, 0.24), 30.0, 150.0, "turret"],
			["a3", 0, Vector2(0.89, 0.64), 30.0, 150.0, "turret"], ["a4", 0, Vector2(0.50, 0.90), 30.0, 150.0, "turret"],
			["a5", 0, Vector2(0.11, 0.64), 30.0, 150.0, "turret"], ["a6", 0, Vector2(0.12, 0.24), 30.0, 150.0, "turret"],
			["s1", 0, Vector2(0.40, 0.30), 16.0, 60.0, "aa"], ["s2", 0, Vector2(0.60, 0.30), 16.0, 60.0, "aa"],
			["s3", 0, Vector2(0.40, 0.46), 16.0, 60.0, "aa"], ["s4", 0, Vector2(0.60, 0.46), 16.0, 60.0, "aa"],
		],
		core = {kind = "core", f = Vector2(0.5, 0.36), view = Vector2(0.5, 0.44), hp = 700.0, r = 44.0, label = "중앙 돔"},
	},
	# 2라운드 — 장갑 열차. 철길을 따라 **내 밑으로 지나간다**: 차량 넷을 위에서부터 부수면 열차가 위로 빠져나가며 다음 차량이 들어온다 → 기관차의 핵
	train2 = {
		name = "장갑 열차 「철갑」", score = 26000, width_k = 1.5, tex = "sky2_boss2", ground = true,
		groups = [{view = Vector2(0.5, 0.10), label = "고사포차", rect = Rect2(0.15, 0.01, 0.70, 0.19)},
				{view = Vector2(0.5, 0.27), label = "미사일차", rect = Rect2(0.15, 0.20, 0.70, 0.16)},
				{view = Vector2(0.5, 0.44), label = "주포차", rect = Rect2(0.15, 0.36, 0.70, 0.18)},
				{view = Vector2(0.5, 0.61), label = "장갑차", rect = Rect2(0.15, 0.54, 0.70, 0.16)}],
		parts = [
			["c1a", 0, Vector2(0.31, 0.050), 26.0, 110.0, "aa"], ["c1b", 0, Vector2(0.69, 0.050), 26.0, 110.0, "aa"],
			["c1c", 0, Vector2(0.31, 0.125), 26.0, 110.0, "aa"], ["c1d", 0, Vector2(0.69, 0.125), 26.0, 110.0, "aa"],
			["c2a", 1, Vector2(0.36, 0.262), 40.0, 200.0, "rack"], ["c2b", 1, Vector2(0.64, 0.262), 40.0, 200.0, "rack"],
			["c3", 2, Vector2(0.50, 0.430), 56.0, 500.0, "big"],
			["c4a", 3, Vector2(0.27, 0.600), 30.0, 220.0, "turret"], ["c4b", 3, Vector2(0.73, 0.600), 30.0, 220.0, "turret"],
		],
		core = {kind = "core", f = Vector2(0.5, 0.82), view = Vector2(0.5, 0.80), hp = 700.0, r = 40.0, label = "기관차", rect = Rect2(0.15, 0.70, 0.70, 0.28)},
	},
	# 4라운드 — 초중전차(예전 보스에 있던 전차를 꼭 하나 두자는 요청, 11-10). 화면보다 조금 넓은 몸이 좌우로 구르며(sway) 밀고 내려왔다
	# 물러난다(bob). 장면을 넘기지 않는다 — 미사일대 · 옆구리 포 · 앞 포탑 · 주포를 아무 순서로나 부수면 포탑 돔의 핵이 드러난다.
	tank4 = {
		name = "초중전차 「환월」", score = 38000, width_k = 1.3, tex = "sky2_boss8", ground = true, bob = 30.0, sway = 50.0,
		turret = "sky2_turret_4", turret_big = "sky2_turret_big_4",
		groups = [{view = Vector2(0.5, 0.42), label = "차체"}],
		parts = [
			["m1", 0, Vector2(0.265, 0.170), 30.0, 220.0, "rack"], ["m2", 0, Vector2(0.735, 0.170), 30.0, 220.0, "rack"],
			["s1", 0, Vector2(0.265, 0.370), 16.0, 140.0, "aa"], ["s2", 0, Vector2(0.735, 0.370), 16.0, 140.0, "aa"],
			["f1", 0, Vector2(0.275, 0.690), 28.0, 260.0, "turret"], ["f2", 0, Vector2(0.725, 0.690), 28.0, 260.0, "turret"],
			["g1", 0, Vector2(0.500, 0.520), 36.0, 700.0, "big"],
		],
		core = {kind = "core", f = Vector2(0.5, 0.32), view = Vector2(0.5, 0.42), hp = 1000.0, r = 40.0, label = "포탑 핵", rect = Rect2(0.3, 0.2, 0.4, 0.42)},
	},
	# 5라운드 — 공중 전함. **가로로 누운 배**(세로형 보스뿐이라는 지적, 11-10) — 폭이 화면의 세 배라 한 번에 삼분의 일만 보이고,
	# 몸이 좌우로 길게 미끄러지며(sway) 뱃머리부터 꼬리까지 훑어 보여 준다. 장면을 넘기지 않는다 — 화면에 들어온 포대는 무엇이든 맞는다.
	# 주포 여섯 · 미사일대 셋 · 엔진 넷을 다 부수면 함교에서 기동 병기가 나온다.
	battleship5 = {
		name = "공중 전함 「강신」", score = 44000, width_k = 3.0, tex = "sky2_boss9", sway = 330.0, bob = 14.0,
		turret = "sky2_turret_5", turret_big = "sky2_turret_big_5",
		groups = [{view = Vector2(0.5, 0.56), label = "갑판 포대"}],
		parts = [
			["t1", 0, Vector2(0.180, 0.515), 40.0, 200.0, "turret"], ["t2", 0, Vector2(0.285, 0.515), 40.0, 200.0, "turret"],
			["t3", 0, Vector2(0.390, 0.515), 40.0, 200.0, "turret"], ["t4", 0, Vector2(0.610, 0.515), 40.0, 200.0, "turret"],
			["t5", 0, Vector2(0.715, 0.515), 40.0, 200.0, "turret"], ["t6", 0, Vector2(0.820, 0.515), 40.0, 200.0, "turret"],
			["m1", 0, Vector2(0.325, 0.685), 34.0, 200.0, "rack"], ["m2", 0, Vector2(0.500, 0.685), 34.0, 200.0, "rack"],
			["m3", 0, Vector2(0.675, 0.685), 34.0, 200.0, "rack"],
			["e1", 0, Vector2(0.105, 0.305), 46.0, 280.0, "engine"], ["e2", 0, Vector2(0.105, 0.715), 46.0, 280.0, "engine"],
			["e3", 0, Vector2(0.880, 0.305), 46.0, 280.0, "engine"], ["e4", 0, Vector2(0.880, 0.715), 46.0, 280.0, "engine"],
		],
		core = {kind = "robot", f = Vector2(0.5, 0.44), view = Vector2(0.5, 0.56), hp = 1100.0, tex = "sky2_boss3_robot",
				rect = Rect2(0.43, 0.28, 0.14, 0.36), label = "기동 병기", leave = true},
	},
	# 6라운드 — 산성 요새(갈아엎기 전의 요새 컨셉으로 돌아가자는 요청, 11-10). **가로로 긴** 몸(화면 폭의 2.2배)이 좌우로 천천히 미끄러져
	# 양 끝 탑이 번갈아 들어온다. 장면을 넘기지 않는다 — 성벽 포 넷 · 탑 둘 · 미사일대 둘 · 가운데 포를 다 부수면 성문의 핵이 열린다.
	fortress6 = {
		name = "산성 요새 「천성」", score = 60000, width_k = 2.2, tex = "sky2_boss7", ground = true, sway = 190.0,
		turret = "sky2_turret_7", turret_big = "sky2_turret_big_7",
		groups = [{view = Vector2(0.5, 0.5), label = "성벽"}],
		parts = [
			["w1", 0, Vector2(0.205, 0.640), 28.0, 320.0, "turret"], ["w2", 0, Vector2(0.335, 0.680), 28.0, 320.0, "turret"],
			["w3", 0, Vector2(0.665, 0.680), 28.0, 320.0, "turret"], ["w4", 0, Vector2(0.795, 0.640), 28.0, 320.0, "turret"],
			["t1", 0, Vector2(0.085, 0.420), 34.0, 420.0, "big"], ["t2", 0, Vector2(0.915, 0.420), 34.0, 420.0, "big"],
			["m1", 0, Vector2(0.280, 0.460), 22.0, 240.0, "rack"], ["m2", 0, Vector2(0.720, 0.460), 22.0, 240.0, "rack"],
			["c1", 0, Vector2(0.500, 0.450), 16.0, 100.0, "aa"],
		],
		core = {kind = "core", f = Vector2(0.5, 0.79), view = Vector2(0.5, 0.5), hp = 1500.0, r = 48.0, label = "성문 핵", rect = Rect2(0.38, 0.62, 0.24, 0.34)},
	},
}

static var show_box := false   ## 판정 원 보기(H)

var w: SaWorld
var key := ""
var spec := {}
var size := Vector2.ZERO       ## 몸 크기(논리 px)
var org := Vector2.ZERO        ## 몸 왼쪽 위
var want := Vector2.ZERO
var phase := "enter"           ## enter → fight(gi) → break(gi) → … → open → core → dying → (done)
var gi := 0                    ## 지금 묶음
var ph_t := 0.0
var parts: Array = []          ## {id, g, f, r, hp, max, kind, dead, flash, cd}
var smoke: Array = []
var smoke_cd := 0.0
var core := {}                 ## {pos, hp, max, cd, sw, flash}
var done := false
var age := 0.0


func _init(world: SaWorld, boss_key: String) -> void:
	w = world
	key = boss_key
	spec = SPECS[key]
	var tx := SaArt.img(String(spec.tex) + "_full")
	var aspect: float = tx.get_size().y / tx.get_size().x if tx != null else 0.6
	size = Vector2(w.w * float(spec.width_k), w.w * float(spec.width_k) * aspect)
	var k: float = w.dm().hp
	for row: Array in spec.parts:
		parts.append({id = row[0], g = row[1], f = row[2], r = row[3], hp = float(row[4]) * k, max = float(row[4]) * k, kind = row[5],
				dead = false, flash = 0.0, cd = 1.0 + parts.size() * 0.37})
	want = _org_for(spec.groups[0].view)
	org = Vector2(want.x, -size.y - 40.0)


## view 점(그림 안 비율)이 화면 가운데 위쪽에 오는 몸의 왼쪽 위.
func _org_for(view: Vector2) -> Vector2:
	return Vector2(w.w * 0.5, ANCHOR_Y) - view * size


func at(f: Vector2) -> Vector2:
	return org + f * size


func _alive(g: int) -> Array:
	return parts.filter(func(p): return int(p.g) == g and not p.dead)


func label() -> String:
	if phase in ["open", "core", "dying"]:
		return String(spec.core.label)
	return String(spec.groups[gi].label)


## 지금 단계의 남은 체력 비(체력 막대).
func hp_frac() -> float:
	if phase in ["open", "core", "dying"]:
		return clampf(float(core.get("hp", 1.0)) / float(core.get("max", 1.0)), 0.0, 1.0) if not core.is_empty() else 1.0
	var cur := 0.0
	var mx := 0.0
	for p: Dictionary in parts:
		if int(p.g) == gi:
			cur += maxf(0.0, float(p.hp))
			mx += float(p.max)
	return cur / maxf(1.0, mx)

# ==================== 진행 ====================


func step(dt: float) -> void:
	age += dt
	ph_t += dt
	org = org.lerp(want, minf(1.0, dt * 1.5)) + Vector2(sin(age * 0.7) * 0.25, 0)
	for p: Dictionary in parts:
		p.flash = maxf(0.0, float(p.flash) - dt * 8.0)
	_step_smoke(dt)
	match phase:
		"enter":
			if ph_t > 2.6:
				_go("fight")
		"fight":
			if bool(spec.get("roam", false)):
				# 떠돌기 — 살아 있는 부위 가운데 화면에서 가장 먼 쪽으로 천천히 옮겨 간다(다 보여 주려고), 8초마다 다음 곳
				var live := _alive(gi)
				if not live.is_empty():
					var tgt: Dictionary = live[int(age / 8.0) % live.size()]
					want = _org_for(Vector2(clampf(tgt.f.x, 0.2, 0.8), clampf(tgt.f.y, 0.15, 0.8)))
			elif spec.has("bob") or spec.has("sway"):
				# 좌우로 미끄러지되 **살아 있는 부위가 있는 쪽만** 오간다 — 남은 부위는 왼쪽인데 몸이 오른쪽에 가 있어 허공을 쏘는 일이 있었다(사용자 지적 11-10).
				# 남은 것이 하나면 그것을 화면 가운데로 데려온다.
				var view: Vector2 = spec.groups[gi].view
				var m := float(spec.get("sway", 0.0)) / size.x
				var lo := 1.0
				var hi := 0.0
				for lp: Dictionary in _alive(gi):
					lo = minf(lo, lp.f.x)
					hi = maxf(hi, lp.f.x)
				if lo <= hi:
					view.x = clampf(lerpf(lo, hi, 0.5 + 0.5 * sin(age * 0.3)), 0.5 - m, 0.5 + m)
				want = _org_for(view) + Vector2(0, sin(age * 0.5) * float(spec.get("bob", 0.0)))
			_fire_parts(dt)
			if _alive(gi).is_empty():
				_go("break")
				w.shake = 1.0
		"break":
			# 묶음이 통째로 터진다 — 한동안 폭발이 이어지고, 다음 자리로 미끄러진다
			if w.rng.randf() < dt * 14.0:
				var rc: Rect2 = spec.groups[gi].get("rect", Rect2(0, 0, 1, 1))
				w.booms.append({pos = at(rc.position + Vector2(w.rng.randf(), w.rng.randf()) * rc.size), p = 0.0, s = 26.0 + w.rng.randf() * 22.0})
			if ph_t > 1.4:
				if gi + 1 < spec.groups.size():
					gi += 1
					want = _org_for(spec.groups[gi].view)
					_go("fight")
				else:
					want = _org_for(spec.core.view)
					_go("open")
		"open":
			if ph_t > 1.6 and core.is_empty():
				var hp: float = float(spec.core.hp) * float(w.dm().hp)
				core = {pos = at(spec.core.f), hp = hp, max = hp, cd = 1.2, sw = 0, flash = 0.0}
				for i in 10:
					w.booms.append({pos = at(spec.core.f) + Vector2(w.rng.randf_range(-50, 50), w.rng.randf_range(-40, 40)), p = -i * 0.05, s = 30.0})
				w.shake = 1.0
			if not core.is_empty():
				if spec.core.kind == "robot":
					core.pos = core.pos.lerp(Vector2(w.w * 0.5, 210.0), minf(1.0, dt * 1.5))
				else:
					core.pos = at(spec.core.f)
				if ph_t > 3.0:
					if bool(spec.core.get("leave", false)):
						want = Vector2(want.x, -size.y * 0.75)   # 몸은 불타며 위로 물러난다
					_go("core")
		"core":
			core.flash = maxf(0.0, float(core.flash) - dt * 8.0)
			if spec.core.kind == "robot":
				core.pos = Vector2(w.w * 0.5 + sin(ph_t * 0.9) * w.w * 0.3, 200.0 + sin(ph_t * 1.7) * 30.0)
			else:
				core.pos = at(spec.core.f)
			core.cd = float(core.cd) - dt
			if core.cd <= 0.0:
				var rage: bool = float(core.hp) < float(core.max) * 0.4
				core.cd = 0.7 if rage else 1.0
				core.sw = int(core.sw) + 1
				match int(core.sw) % 3:
					0: w._ring_shot(core.pos, 16 if rage else 12, int(core.sw) * 0.21, 110.0)
					1: w._aim_shot(core.pos + Vector2(-34, 20), 4, 0.18)
					_: w._aim_shot(core.pos + Vector2(34, 20), 4, 0.18)
			if float(core.hp) <= 0.0:
				_go("dying")
				w.shake = 1.0
		"dying":
			if w.rng.randf() < dt * 18.0:
				w.booms.append({pos = core.pos + Vector2(w.rng.randf_range(-70, 70), w.rng.randf_range(-70, 70)), p = 0.0, s = 30.0 + w.rng.randf() * 26.0})
			if spec.core.kind == "robot":
				core.pos += Vector2(0, 40.0 * dt)
			if ph_t > 1.8:
				w.items.append({pos = Vector2(w.w * 0.5, 240.0), kind = "power"})
				w._award(int(spec.score))
				done = true


func _go(p: String) -> void:
	phase = p
	ph_t = 0.0


## 살아 있는 부위만 쏜다 — 포탑은 겨눠서, 미사일대는 아래로 줄지어, 대공포는 빠르게 한 발, 큰 포는 넓게.
func _fire_parts(dt: float) -> void:
	for p: Dictionary in parts:
		if p.dead or int(p.g) != gi or not FIRE.has(p.kind):
			continue
		p.cd = float(p.cd) - dt
		if p.cd > 0.0:
			continue
		p.cd = float(FIRE[p.kind])
		var from := at(p.f)
		if from.y < -30.0 or from.y > w.h * 0.8:
			continue   # 화면 밖 · 플레이어 코앞에서는 안 쏜다
		match String(p.kind):
			"turret":
				w._aim_shot(from + Vector2(0, 14), 3, 0.16)
			"aa":
				w._aim_shot(from, 1, 0.0)
			"big":
				w._aim_shot(from + Vector2(0, 20), 5, 0.14, 2)
			_:
				for i in 5:
					w._eb(from + Vector2((i - 2) * 14.0, 16), PI * 0.5, 96.0, 2)


func _kill(p: Dictionary) -> void:
	p.dead = true
	p.hp = 0.0
	var c := at(p.f)
	for i in 4:
		w.booms.append({pos = c + Vector2(w.rng.randf_range(-16, 16), w.rng.randf_range(-16, 16)), p = -i * 0.08, s = 26.0 + w.rng.randf() * 14.0})
	w.shake = maxf(w.shake, 0.5)
	w._award(SaD.PART_SCORE)


func _step_smoke(dt: float) -> void:
	for s: Dictionary in smoke:
		s.t += dt
		s.p += s.v * dt
	smoke = smoke.filter(func(s): return s.t < s.life)
	smoke_cd -= dt
	if smoke_cd > 0.0:
		return
	smoke_cd = 0.07
	for p: Dictionary in parts:   # 죽은 부위마다 연기 — 화면에 보이는 것만
		if not p.dead:
			continue
		var c := at(p.f)
		if c.x < -40.0 or c.x > w.w + 40.0 or c.y < -40.0 or c.y > w.h + 40.0:
			continue
		if w.rng.randf() < 0.5:
			smoke.append({p = c + Vector2(w.rng.randf_range(-8, 8), w.rng.randf_range(-6, 6)), v = Vector2(w.rng.randf_range(-10, 10), 46.0 + w.rng.randf() * 30.0),
					t = 0.0, life = 1.1 + w.rng.randf() * 0.6, r = 7.0 + w.rng.randf() * 6.0, fire = w.rng.randf() < 0.3})

# ==================== 맞기 ====================


func _core_r() -> float:
	return ROBOT_R if spec.core.kind == "robot" else float(spec.core.get("r", 46.0))


func _targets() -> Array:
	return _alive(gi) if phase == "fight" else []


## 아군 탄 하나. 맞았으면 true(탄을 지울지는 월드가 pierce 를 보고 정한다).
func hit_bullet(b: Dictionary, br: float) -> bool:
	if phase == "core":
		if (b.pos as Vector2).distance_to(core.pos) < _core_r() + br:
			if b.pierce:
				if b.get("hitc", false):
					return false
				b.hitc = true
			core.hp = float(core.hp) - float(b.dmg)
			core.flash = 1.0
			return true
		return false
	for p: Dictionary in _targets():
		if (b.pos as Vector2).distance_to(at(p.f)) < float(p.r) + br:
			if b.get("hit2", []).has(p.id):
				continue   # 관통탄은 같은 부위를 한 번만
			if b.pierce:
				if not b.has("hit2"):
					b.hit2 = []
				b.hit2.append(p.id)
			_hurt(p, float(b.dmg))
			return true
	return false


## 세로 기둥(번개 · 광선 · 밧줄) — x 를 지나는 가장 아래 표적에 피해. 닿은 y 를 돌려준다(없으면 -1).
func hit_column(x: float, half: float, dmg: float) -> float:
	var by := column_y(x, half)
	if by < 0.0:
		return -1.0
	if phase == "core":
		core.hp = float(core.hp) - dmg
		core.flash = 1.0
		return by
	for p: Dictionary in _targets():
		var c := at(p.f)
		if absf(x - c.x) < float(p.r) + half and absf(c.y + float(p.r) - by) < 0.5:
			_hurt(p, dmg)
			break
	return by


## 세로 기둥이 처음 닿는 y(피해 없이 — 광선을 어디서 끊을지). 없으면 -1.
func column_y(x: float, half: float) -> float:
	if phase == "core":
		return float(core.pos.y) + _core_r() if absf(x - float(core.pos.x)) < _core_r() + half else -1.0
	var by := -1.0
	for p: Dictionary in _targets():
		var c := at(p.f)
		if absf(x - c.x) < float(p.r) + half:
			by = maxf(by, c.y + float(p.r))
	return by


## 자동 조종(확인용)이 따라갈 x — 지금 맞는 것 가운데 첫째. 없으면 -INF.
func aim_x() -> float:
	if phase == "core":
		return float(core.pos.x)
	var ts := _targets()
	return at(ts[0].f).x if not ts.is_empty() else -INF


## 봄 — 지금 보이는 표적 전부에.
func hurt_all(dmg: float) -> void:
	if phase == "core":
		core.hp = float(core.hp) - dmg
		return
	for p: Dictionary in _targets():
		_hurt(p, dmg * 0.5)


func _hurt(p: Dictionary, dmg: float) -> void:
	p.hp = float(p.hp) - dmg
	p.flash = 1.0
	if float(p.hp) <= 0.0 and not p.dead:
		_kill(p)


## 플레이어가 부딪히나 — 내려온 로봇에만(큰 몸은 그 위를 · 밑을 난다).
func touches(pos: Vector2, hit: float) -> bool:
	return phase == "core" and spec.core.kind == "robot" and pos.distance_to(core.pos) < ROBOT_R * 0.7 + hit

# ==================== 그리기 ====================


func draw(ci: CanvasItem, t: float) -> void:
	var base := String(spec.tex)
	var full := SaArt.img(base + "_full")
	var wreck := SaArt.img(base + "_wreck")
	var bare := SaArt.img(base + "_bare")
	if full != null:
		if not bool(spec.get("ground", false)):   # 떠 있는 것만 그림자
			ci.draw_texture_rect(full, Rect2(org + Vector2(26, 60), size), false, Color(0, 0, 0, 0.28))
		ci.draw_texture_rect(bare if bare != null else full, Rect2(org, size), false)
	else:
		ci.draw_rect(Rect2(org, size), Color8(86, 96, 60))
	if wreck != null:
		var ts := wreck.get_size()
		# 통째로 터진 묶음 · 열린 핵 둘레는 그 구역 전체를 부서진 그림으로
		for g in spec.groups.size():
			var broken: bool = g < gi or (g == gi and phase != "fight" and phase != "enter")
			if broken and spec.groups[g].has("rect"):
				_wreck_rect(ci, wreck, ts, spec.groups[g].rect)
		if not core.is_empty() and spec.core.has("rect"):
			_wreck_rect(ci, wreck, ts, spec.core.rect)
		for p: Dictionary in parts:   # 죽은 부위는 그 둘레만
			if p.dead:
				var hw := float(p.r) * 1.25 / size.x
				var hh := float(p.r) * 1.25 / size.y
				_wreck_rect(ci, wreck, ts, Rect2(p.f.x - hw, p.f.y - hh, hw * 2.0, hh * 2.0))
	# 도는 포탑 — 포탑 뺀 몸(bare)이 있을 때만. 살아 있는 포탑은 플레이어를 겨눈다(쏜 직후 살짝 밀린다)
	var tt := SaArt.img(String(spec.get("turret", "sky2_turret")))
	var tb_name := String(spec.get("turret_big", "sky2_turret_big"))
	if tt != null and bare != null:
		for p: Dictionary in parts:
			if p.dead or not (p.kind in ["turret", "aa", "big"]):
				continue
			var c2 := at(p.f)
			if c2.x < -60.0 or c2.x > w.w + 60.0 or c2.y < -60.0 or c2.y > w.h + 60.0:
				continue
			var ang := (w.pos - c2).angle()
			var kick := clampf((float(p.cd) - (float(FIRE[p.kind]) - 0.2)) / 0.2, 0.0, 1.0) * 4.0
			var tb := SaArt.img(tb_name) if p.kind == "big" else null
			SaArt.quad(ci, tb if tb != null else tt, c2 - Vector2.from_angle(ang) * kick, float(p.r) * (2.6 if tb != null else 3.0), ang - PI * 0.5)
	# 엔진 불빛 · 맞은 번쩍임 · 죽은 자리의 불
	for p: Dictionary in parts:
		var c := at(p.f)
		if c.x < -60.0 or c.x > w.w + 60.0 or c.y < -60.0 or c.y > w.h + 60.0:
			continue
		if p.dead:
			SaG2.glow(ci, c, float(p.r) * (0.9 + 0.25 * sin(t * 17.0 + c.x)), SaP.HOT, 0.38)
		elif p.kind == "engine":
			SaG2.glow(ci, c + Vector2(0, float(p.r) * 0.7), float(p.r) * 0.9, SaP.HOT, 0.3 + 0.12 * sin(t * 22.0 + c.x))
		if float(p.flash) > 0.0:
			ci.draw_circle(c, float(p.r) * 0.9, Color(1, 1, 1, 0.5 * float(p.flash)))
		if show_box and not p.dead:
			ci.draw_arc(c, float(p.r), 0.0, TAU, 24, Color(1, 0.2, 0.2) if int(p.g) == gi and phase == "fight" else Color(1, 1, 1, 0.3), 1.5, true)
	# 연기 — 검은 덩이가 커지며 뒤로 흐르고, 가끔 불씨
	for s: Dictionary in smoke:
		var k := float(s.t) / float(s.life)
		if bool(s.fire) and k < 0.35:
			ci.draw_circle(s.p, float(s.r) * 0.6, Color(1.0, 0.6, 0.2, 0.8 * (1.0 - k / 0.35)))
		ci.draw_circle(s.p, float(s.r) * (1.0 + k * 1.8), Color(0.08, 0.08, 0.1, 0.5 * (1.0 - k)))
	# 핵 — 안에서 나온 로봇이거나 몸에 박힌 핵
	if not core.is_empty():
		var cr := _core_r()
		SaG2.glow(ci, core.pos, cr * (1.1 + 0.15 * sin(t * 9.0)), SaP.FOE_MARK if spec.core.kind != "robot" else SaP.HOT, 0.4)
		if spec.core.kind == "robot":
			var rt := SaArt.img(String(spec.core.tex))
			if rt != null:
				SaArt.quad(ci, rt, core.pos, cr * 2.6, 0.0, Color(1, 1, 1))
			else:
				ci.draw_circle(core.pos, cr, Color8(120, 130, 150))
		else:
			ci.draw_circle(core.pos, cr * 0.5, SaP.hdr(Color8(255, 90, 70), 1.1))
			ci.draw_circle(core.pos, cr * 0.22, Color8(255, 230, 210))
		if float(core.get("flash", 0.0)) > 0.0:
			ci.draw_circle(core.pos, cr * 0.8, Color(1, 1, 1, 0.4 * float(core.flash)))
		if show_box:
			ci.draw_arc(core.pos, cr, 0.0, TAU, 28, Color(1, 0.2, 0.2), 1.5, true)
	# 남은 표적이 전부 화면 밖이면 그쪽 가장자리에 화살표
	var ts2 := _targets()
	if not ts2.is_empty() and not ts2.any(func(q): return at(q.f).x > 10.0 and at(q.f).x < w.w - 10.0):
		var left: bool = at(ts2[0].f).x < w.w * 0.5
		var ax := 16.0 if left else w.w - 16.0
		var sgn := -1.0 if left else 1.0
		var ay := 150.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(ax + sgn * 10.0, ay), Vector2(ax - sgn * 8.0, ay - 14.0), Vector2(ax - sgn * 8.0, ay + 14.0)]),
				SaP.a(SaP.FOE_MARK, 0.55 + 0.4 * sin(t * 9.0)))
	# 체력 막대 — 지금 단계
	if phase != "enter" and phase != "dying":
		var bw := w.w - 24.0
		var top := Vector2(12.0, 8.0)
		ci.draw_rect(Rect2(top, Vector2(bw, 6.0)), Color(0, 0, 0, 0.6), true)
		ci.draw_rect(Rect2(top, Vector2(bw * hp_frac(), 6.0)), SaP.FOE_MARK, true)
		SaG2.text(ci, top + Vector2(0, 16), "%s  %s" % [String(spec.name), label()], 10.0, Color(1, 1, 1, 0.9))


func _wreck_rect(ci: CanvasItem, wreck: Texture2D, ts: Vector2, fr: Rect2) -> void:
	ci.draw_texture_rect_region(wreck, Rect2(org + fr.position * size, fr.size * size), Rect2(fr.position * ts, fr.size * ts))
