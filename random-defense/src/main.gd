extends Node3D

## 루프 · 입력 · 카메라 · 상태 기계 · 3D 채우기.
##
## ## 조작
##
## 유닛은 타워가 아니라 움직이는 유닛이다. **왼쪽 드래그로 여러 기를 고르고 오른쪽으로
## 보낸다** — 워크래프트와 같다. 그래서 유닛을 스토리 라인으로 빼내는 일이 조작 하나로 된다.
##
## ## 그리기
##
## 몬스터도 유닛도 탄도 노드가 아니라 [MultiMesh] 인스턴스다. 유닛이 310종이지만 도안은
## 역할 3종뿐이고, 등급은 크기와 색으로만 낸다. 그래서 드로우콜이 종수를 안 탄다.

const CAM_PITCH := 52.0
const CAM_MARGIN := 1.04

const CAP_UNIT := 200
const CAP_UNIT_LEG := 400
const CAP_MOB := 140
const CAP_MOB_LEG := 300
const CAP_SHOT := 400
const CAP_RING := 200

## 진화 목록에서 숫자키로 고를 수 있는 칸 수. **화면에 보이는 줄 수와 같아야 한다** —
## 안 보이는 줄을 숫자키로 만들 수 있으면 무엇이 만들어질지 모르고 누르게 된다.
const UP_SLOTS := 6
## 전체 조합표 한 쪽에 담는 줄 수. 쉬움은 줄마다 최하위 재료가 한 줄 더 붙어 절반만 담는다.
const BOOK_ROWS := 14
const BOOK_ROWS_EASY := 9


func book_rows() -> int:
	return BOOK_ROWS_EASY if g != null and g.mode == D.Mode.EASY else BOOK_ROWS

var st := D.St.TITLE
var g: Game
var w: World

var t := 0.0
var round_t := 0.0
## 스토리 단계를 깬 뒤 다음 단계가 나오기까지의 뜸
var story_wait := 0.0

## 드래그 선택 상자 (화면 좌표). `drag` 가 false 면 안 그린다.
var drag := false
var drag_a := Vector2.ZERO
var drag_b := Vector2.ZERO

## 딱 한 기를 골랐을 때 그 유닛의 자리와 진화 목록. **조합은 여기서만 한다** —
## 판 전체의 조합 가능 목록을 따로 띄우면 줄이 수십 개가 되어 정작 지금 고른 유닛으로
## 무엇을 할 수 있는지가 묻힌다.
var sel_ui := -1
var sel_ups: Array = []

var toast := ""
var toast_t := 0.0
var toast_col := Color.WHITE

## 10단계 보상처럼 고르는 창이 떠 있을 때
var choosing := false
## 흔함 선택 위습을 쓰는 창
var picking := false
## 전체 조합표. `book_row` 는 지금 등급 목록에서 **줄 커서**의 자리이고,
## 쪽은 여기서 계산해 낸다 — 쪽과 커서를 따로 들면 둘이 어긋난다.
var book := false
var book_gi := 0
var book_row := 0

## 유닛 머리 위 초상을 띄울지. 판이 빽빽해지면 끄고 볼 수 있어야 한다.
var badges := true

@onready var cam: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: Control = $Ui/Hud

var _ubody: Array = []
var _mbody: Array = []
var _uleg: MultiMeshInstance3D
var _mleg: MultiMeshInstance3D
var _shots: MultiMeshInstance3D
var _sparks: MultiMeshInstance3D
var _rings: MultiMeshInstance3D


# ══ 준비 ══════════════════════════════════════════════════════

func _ready() -> void:
	sun.rotation_degrees = Vector3(-64.0, -34.0, 0.0)
	sun.light_color = Color8(255, 240, 216)
	sun.light_energy = 1.5
	sun.shadow_enabled = true

	var ground := MeshInstance3D.new()
	ground.mesh = Mdl.ground()
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	for i in 3:
		_ubody.append(_mmi(Mdl.unit_body(i), CAP_UNIT))
	for i in D.MOB.size():
		_mbody.append(_mmi(Mdl.mob_body(i), CAP_MOB))
	_uleg = _mmi(Mdl.leg(), CAP_UNIT_LEG)
	_mleg = _mmi(Mdl.leg(), CAP_MOB_LEG)
	_shots = _mmi(Mdl.shot(), CAP_SHOT, false)
	_sparks = _mmi(Mdl.shot(), World.SPARK_MAX, false)
	_rings = _mmi(Mdl.ring(), CAP_RING, false)

	hud.m = self
	get_viewport().size_changed.connect(_fit_camera)
	_new_game()
	st = D.St.TITLE
	_fit_camera()


func _mmi(mesh: Mesh, cap: int, shadow: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var s := D.world_size()
	mi.custom_aabb = AABB(Vector3(-4, -4, -4), Vector3(s.x + 8.0, 20.0, s.y + 8.0))
	add_child(mi)
	return mi


## 판 전체가 HUD 에 안 가리는 자리에 들어오도록 카메라를 맞춘다.
## 모서리를 실제로 투영해 보고 넘치는 만큼 물러나기를 되풀이한다 —
## 기울여 보는 판은 가까운 쪽이 원근으로 커져서 삼각함수 어림으로는 아래가 잘린다.
func _fit_camera() -> void:
	if cam == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var box := Rect2(20.0, 84.0, maxf(vp.x - 40.0, 64.0), maxf(vp.y - 84.0 - 150.0, 64.0))
	var pitch := deg_to_rad(CAM_PITCH)
	var dir := Vector3(0.0, sin(pitch), cos(pitch))
	var s := D.world_size()
	var pts := []
	for x in [0.0, s.x]:
		for z in [0.0, s.y]:
			for y in [0.0, 1.6]:
				pts.append(Vector3(x, y, z))

	cam.rotation = Vector3(-pitch, 0.0, 0.0)
	var pivot := D.world_center()
	var dist := 60.0
	for i in 6:
		cam.position = pivot + dir * dist
		cam.force_update_transform()
		var r := _project_rect(pts)
		if r.size.x <= 1.0 or r.size.y <= 1.0:
			break
		dist *= maxf(r.size.x / box.size.x, r.size.y / box.size.y) * CAM_MARGIN
		cam.position = pivot + dir * dist
		cam.force_update_transform()
		r = _project_rect(pts)
		var d := box.get_center() - r.get_center()
		var per_px := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / maxf(vp.y, 1.0)
		var b := cam.global_transform.basis
		pivot += (-b.x * d.x + b.y * d.y) * per_px
	cam.position = pivot + dir * dist


func _project_rect(pts: Array) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		if cam.is_position_behind(p):
			continue
		var q := cam.unproject_position(p)
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
		mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
	if mn.x > mx.x:
		return Rect2()
	return Rect2(mn, mx - mn)


func _new_game(mode: int = D.Mode.NORMAL) -> void:
	g = Game.new()
	g.mode = mode
	w = World.new(g)
	round_t = 0.0
	story_wait = 0.0
	drag = false
	choosing = false
	toast_t = 0.0
	# 시작 위습으로 아무것도 안 뽑은 채 1라운드를 맞으면 그냥 쌓이기만 한다.
	for i in 4:
		g.draw_unit()
	w.spawn_round(1)
	w.spawn_story(g.story_stage)
	st = D.St.PLAY


# ══ 루프 ══════════════════════════════════════════════════════

func _process(dt: float) -> void:
	t += dt
	toast_t = maxf(0.0, toast_t - dt)
	if st == D.St.PLAY and not choosing and not picking and not book:
		_tick(dt)
	_refresh_sel()
	_sync()


## 고른 유닛과 그 진화 목록을 한곳에서 만든다.
## **그리기와 조합이 같은 배열을 봐야** `[3]` 이 화면과 다른 것을 만드는 일이 없다.
##
## 목록 만들기는 재귀로 조합 가능 여부를 재느라 비싸므로, **고른 유닛과 판의 구성이
## 그대로면 다시 만들지 않는다**(`Game.rev`). 매 프레임 돌리면 유닛이 수십 기일 때 티가 난다.
var _sel_key := ""


func _refresh_sel() -> void:
	var found := -1
	var n := 0
	for un in g.units:
		if un["sel"]:
			n += 1
			found = int(un["ui"])
	if n != 1:
		sel_ui = -1
		sel_ups = []
		_sel_key = ""
		return
	var key := "%d/%d/%d" % [found, g.rev, g.mode]
	if key == _sel_key:
		return
	_sel_key = key
	sel_ui = found
	sel_ups = g.upgrades_from(found)


func _tick(dt: float) -> void:
	w.step(dt)

	# 몬스터가 쌓이면 진다. 코어도 목숨도 없다 — 화면에 깔린 수가 곧 남은 여유다.
	if w.field_alive() >= D.LOSE_COUNT:
		st = D.St.OVER
		return

	round_t += dt
	if round_t >= D.ROUND_TIME:
		round_t = 0.0
		g.next_round()
		if g.won():
			st = D.St.WIN
			return
		w.spawn_round(g.round_no)
		_say("라운드 %d" % g.round_no, P.WHITE)

	# 스토리 라인 — 다 잡으면 보상을 주고 다음 단계가 나온다
	if not g.story_done():
		if w.story_alive() == 0:
			if story_wait <= 0.0:
				var was := g.story_stage
				g.clear_stage()
				story_wait = 2.5
				if was == D.STORY_CHOICE_STAGE:
					choosing = true
					_say("스토리 %d단계 — 고르시오" % was, P.JADE)
				else:
					_say("스토리 %d단계 클리어 · %s 위습 +1 · 흔함 선택 +%d"
						% [was, D.RW_GRADE[D.story_reward(was)], D.STORY_PICK], P.JADE)
			else:
				story_wait -= dt
				if story_wait <= 0.0 and not g.story_done():
					w.spawn_story(g.story_stage)


func _say(s: String, col: Color) -> void:
	toast = s
	toast_col = col
	toast_t = 2.0


# ══ 입력 ══════════════════════════════════════════════════════

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		_key(ev.keycode)
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				drag = true
				drag_a = ev.position
				drag_b = ev.position
			else:
				drag = false
				_select(drag_a, ev.position, ev.shift_pressed)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			_move_order(ev.position)
	elif ev is InputEventMouseMotion and drag:
		drag_b = ev.position


func _key(k: int) -> void:
	# 시작 화면에서는 난이도를 고르는 것이 전부다. 숫자키가 조합으로 새면 안 되므로 먼저 가로챈다.
	if st == D.St.TITLE:
		if k == KEY_1:
			_new_game(D.Mode.EASY)
		elif k == KEY_2 or k == KEY_SPACE:
			_new_game(D.Mode.NORMAL)
		elif k == KEY_ESCAPE:
			get_tree().quit()
		return

	# 창이 떠 있으면 그 창이 입력을 통째로 가져간다
	if choosing:
		if k >= KEY_1 and k < KEY_1 + D.STORY_CHOICE.size():
			_say(g.use_choice(k - KEY_1), P.JADE)
			choosing = false
		return
	if picking:
		if k == KEY_ESCAPE or k == KEY_T:
			picking = false
		elif k >= KEY_1 and k <= KEY_9:
			var ui := g.use_pick(k - KEY_1)
			if ui >= 0:
				_do(ui, "")
				if g.wisp_pick <= 0:
					picking = false
		return
	if book:
		_book_key(k)
		return

	match k:
		KEY_Q:
			_do(g.draw_unit(), "위습이 없다")
		KEY_W:
			var n := g.gamble_lumber()
			if n < 0:
				_say("위습이 없다", P.CRIMSON)
			elif n == 0:
				_say("나무 도박 — 꽝", P.DIMMER)
			else:
				_say("나무 도박 — 목재 +%d" % n, P.LUMBER)
		KEY_E:
			var r := g.gamble_unit()
			if r == D.named(D.TOKEN_NAME) and r >= 0:
				_say("랜덤 도박 — 꽝 · %s" % D.TOKEN_NAME, P.LUMBER)
			else:
				_do(r, "목재가 모자라다")
		KEY_G:
			if g.buy_wisp():
				_say("위습 +1 (골드 %d)" % D.WISP_PRICE, P.WISP)
			else:
				_say("골드가 모자라다", P.CRIMSON)
		KEY_F:
			var a := g.gamble_absalom()
			if a == -1:
				_say("목재가 모자라다", P.CRIMSON)
			elif a == -2:
				_say("압살롬 도박 — 꽝", P.DIMMER)
			else:
				_do(a, "")
		KEY_R:
			_do(g.use_reward(), "보상 위습이 없다")
		KEY_T:
			if g.wisp_pick > 0:
				picking = true
			else:
				_say("흔함 선택 위습이 없다", P.CRIMSON)
		KEY_TAB:
			book = true
			book_row = 0
		KEY_A:
			for un in g.units:
				un["sel"] = true
		KEY_V:
			badges = not badges
			_say("초상 %s" % ("켜짐" if badges else "꺼짐"), P.DIM)
		KEY_ESCAPE:
			get_tree().quit()
		KEY_F5:
			if st == D.St.OVER or st == D.St.WIN:
				_new_game(g.mode)
		_:
			if k >= KEY_1 and k <= KEY_9:
				_craft(k - KEY_1)


## 전체 조합표 넘기기. 등급은 좌우로, 줄 커서는 위아래로, 조합은 엔터.
func _book_key(k: int) -> void:
	var grades := D.recipe_grades()
	if grades.is_empty():
		book = false
		return
	book_gi = clampi(book_gi, 0, grades.size() - 1)
	var list: Array = D.recipes_of_grade(grades[book_gi])
	var last := maxi(list.size() - 1, 0)
	match k:
		KEY_TAB, KEY_ESCAPE:
			book = false
		KEY_LEFT:
			book_gi = posmod(book_gi - 1, grades.size())
			book_row = 0
		KEY_RIGHT:
			book_gi = posmod(book_gi + 1, grades.size())
			book_row = 0
		KEY_UP:
			book_row = maxi(0, book_row - 1)
		KEY_DOWN:
			book_row = mini(last, book_row + 1)
		KEY_PAGEUP:
			book_row = maxi(0, book_row - book_rows())
		KEY_PAGEDOWN:
			book_row = mini(last, book_row + book_rows())
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_book_craft(list)


## 표에서 바로 만든다. **고른 유닛을 거치지 않으므로** 표를 넘겨 보다가 발견한 조합을
## 그 자리에서 시도할 수 있다. 만든 것은 곧바로 고른 상태가 된다.
func _book_craft(list: Array) -> void:
	if book_row < 0 or book_row >= list.size():
		return
	var ui: int = list[book_row]
	var u: Dictionary = U.UNITS[ui]
	if not g.can_craft(ui):
		_say("%s — 재료가 모자라다" % u["n"], P.CRIMSON)
		return
	var made := g.craft(ui)
	if made < 0:
		return
	for un in g.units:
		un["sel"] = false
	g.units[made]["sel"] = true
	_say("조합 — %s (%s)" % [u["n"], U.GRADE[int(u["g"])]], P.grade(int(u["g"])))


func _do(ui: int, fail: String) -> void:
	if ui < 0:
		_say(fail, P.CRIMSON)
		return
	var u: Dictionary = U.UNITS[ui]
	_say("%s (%s)" % [u["n"], U.GRADE[int(u["g"])]], P.grade(int(u["g"])))


## 고른 유닛의 진화 목록에서 `slot` 번째를 만든다.
## 재료가 모자란 줄은 목록에 그대로 보이되 눌러도 안 된다 — 목록에서 빼 버리면
## 번호가 계속 바뀌어서 "3번을 눌렀는데 다른 게 나왔다"가 된다.
func _craft(slot: int) -> void:
	if slot >= mini(sel_ups.size(), UP_SLOTS):
		return
	var e: Dictionary = sel_ups[slot]
	var ui := int(e["ui"])
	var u: Dictionary = U.UNITS[ui]
	if int(e["missing"]) > 0:
		_say("%s — 재료가 모자라다" % u["n"], P.CRIMSON)
		return
	var made := g.craft(ui)
	if made < 0:
		return
	# 만든 것을 바로 고른 상태로 둔다. 판에서 눈으로 찾게 하면 안 된다.
	for un in g.units:
		un["sel"] = false
	g.units[made]["sel"] = true
	_say("조합 — %s (%s)" % [u["n"], U.GRADE[int(u["g"])]], P.grade(int(u["g"])))


## 드래그 상자 안의 유닛을 고른다. 상자가 아주 작으면 한 번 클릭한 것으로 본다.
func _select(a: Vector2, b: Vector2, add: bool) -> void:
	var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
	var click := r.size.length() < 6.0
	if click:
		r = Rect2(a - Vector2(18, 18), Vector2(36, 36))
	if not add:
		for un in g.units:
			un["sel"] = false
	var best := -1
	var best_d := INF
	for i in g.units.size():
		var p: Vector3 = (g.units[i]["p"] as Vector3) + Vector3(0, 0.7, 0)
		if cam.is_position_behind(p):
			continue
		var q := cam.unproject_position(p)
		if not r.has_point(q):
			continue
		if click:
			var d := q.distance_to(a)
			if d < best_d:
				best_d = d
				best = i
		else:
			g.units[i]["sel"] = true
	if click and best >= 0:
		g.units[best]["sel"] = true


## 고른 유닛들을 그 자리로 보낸다. 한 점에 겹쳐 세우면 서로 파묻히므로 격자로 편다.
func _move_order(mp: Vector2) -> void:
	var hit = _ground_point(mp)
	if hit == null:
		return
	var target: Vector3 = hit
	if not D.walkable(target):
		return
	var sel := []
	for un in g.units:
		if un["sel"]:
			sel.append(un)
	if sel.is_empty():
		return
	var cols := int(ceil(sqrt(float(sel.size()))))
	var gap := 1.5
	for i in sel.size():
		var cx := float(i % cols) - float(cols - 1) * 0.5
		var cz := float(i / cols) - float((sel.size() - 1) / cols) * 0.5
		var p := target + Vector3(cx * gap, 0.0, cz * gap)
		# 목적지가 판 밖이면 그 축만 판 안으로 밀어 넣는다
		if not D.walkable(p):
			p = target
		sel[i]["dst"] = p
	_say("이동 %d기" % sel.size(), P.WHITE)


func _ground_point(mp: Vector2):
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.00001:
		return null
	var k := -from.y / dir.y
	if k <= 0.0:
		return null
	return from + dir * k


func selected_count() -> int:
	var n := 0
	for un in g.units:
		if un["sel"]:
			n += 1
	return n


# ══ 3D 채우기 ══════════════════════════════════════════════════

func _sync() -> void:
	_sync_units()
	_sync_mobs()
	_sync_fx()


func _sync_units() -> void:
	var c := [0, 0, 0]
	var ml: MultiMesh = _uleg.multimesh
	var mr: MultiMesh = _rings.multimesh
	var ln := 0
	var rn := 0

	for un in g.units:
		var u: Dictionary = U.UNITS[int(un["ui"])]
		var role := clampi(int(u["r"]), 0, 2)
		var gr := int(u["g"])
		# 등급은 **크기와 색**으로만 낸다. 도안을 등급마다 그릴 수는 없다.
		var sc := 1.15 + 0.030 * float(gr)
		var p: Vector3 = un["p"]
		var moving := un["dst"] != null
		var walk := t * 7.0 if moving else 0.0
		var y := absf(sin(walk)) * 0.05 * sc
		var yaw := float(un["yaw"])
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sc, sc, sc))
		var col := P.grade(gr)

		var mm: MultiMesh = _ubody[role].multimesh
		if c[role] < mm.instance_count:
			mm.set_instance_transform(c[role], Transform3D(basis, Vector3(p.x, y, p.z)))
			mm.set_instance_color(c[role], col)
			c[role] += 1

		# 마뎀은 로브라 다리를 안 그린다 — 그리면 치마 밖으로 삐져나온다
		if role != 1:
			var swing := sin(walk) * 0.5
			for s: float in [-1.0, 1.0]:
				if ln >= ml.instance_count:
					break
				var lb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, swing * s) \
					* Basis.from_scale(Vector3(sc, sc, sc))
				var off := Basis(Vector3.UP, yaw) * Vector3(0.17 * s * sc, 0.0, 0.0)
				ml.set_instance_transform(ln,
					Transform3D(lb, Vector3(p.x, y + 0.56 * sc, p.z) + off))
				ml.set_instance_color(ln, col.darkened(0.25))
				ln += 1

		if un["sel"] and rn < mr.instance_count:
			var k := sc * 1.1
			mr.set_instance_transform(rn,
				Transform3D(Basis.from_scale(Vector3(k, k, k)), Vector3(p.x, 0.0, p.z)))
			mr.set_instance_color(rn, P.hdr(P.role(role), 1.5))
			rn += 1

	for i in 3:
		_ubody[i].multimesh.visible_instance_count = c[i]
	ml.visible_instance_count = ln
	mr.visible_instance_count = rn


func _sync_mobs() -> void:
	var c := []
	for i in D.MOB.size():
		c.append(0)
	var ml: MultiMesh = _mleg.multimesh
	var ln := 0

	for m in w.mobs:
		if m["dead"]:
			continue
		var k := clampi(int(m["kind"]), 0, D.MOB.size() - 1)
		var boss: bool = m["boss"]
		var sc := 2.6 if boss else 1.25
		var p: Vector3 = m["p"]
		var walk := float(m["walk"])
		var y := absf(sin(walk)) * 0.05 * sc
		var yaw := float(m["yaw"])
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sc, sc, sc))
		var col: Color = P.MOB_COL[k]
		if float(m["hit_t"]) > 0.0:
			col = P.mix(col, Color.WHITE, 0.75)
		elif float(m["stun_t"]) > 0.0:
			col = P.mix(col, P.GOLD, 0.55)
		elif float(m["slow"]) > 0.0:
			col = P.mix(col, P.WISP, 0.45)
		if m["story"]:
			col = P.mix(col, P.STORY_EDGE, 0.30)

		var mm: MultiMesh = _mbody[k].multimesh
		if c[k] < mm.instance_count:
			mm.set_instance_transform(c[k], Transform3D(basis, Vector3(p.x, y, p.z)))
			mm.set_instance_color(c[k], col)
			c[k] += 1

		if k == 3:
			continue  # 요괴는 떠 있어서 다리가 없다
		var swing := sin(walk) * 0.55
		for s: float in [-1.0, 1.0]:
			if ln >= ml.instance_count:
				break
			var lb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, swing * s) \
				* Basis.from_scale(Vector3(sc, sc, sc))
			var off := Basis(Vector3.UP, yaw) * Vector3(0.19 * s * sc, 0.0, 0.0)
			ml.set_instance_transform(ln,
				Transform3D(lb, Vector3(p.x, y + 0.55 * sc, p.z) + off))
			ml.set_instance_color(ln, col.darkened(0.25))
			ln += 1

	for i in D.MOB.size():
		_mbody[i].multimesh.visible_instance_count = c[i]
	ml.visible_instance_count = ln


func _sync_fx() -> void:
	var ms: MultiMesh = _shots.multimesh
	var n := 0
	for s in w.shots:
		if s["dead"] or n >= ms.instance_count:
			continue
		var spin := Basis(Vector3.UP, t * 8.0) * Basis(Vector3.RIGHT, t * 5.0)
		ms.set_instance_transform(n, Transform3D(spin, s["p"]))
		ms.set_instance_color(n, P.hdr(P.role(int(U.UNITS[int(s["ui"])]["r"])), 1.5))
		n += 1
	ms.visible_instance_count = n

	var mp: MultiMesh = _sparks.multimesh
	var k := 0
	for s in w.sparks:
		var life := float(s["t"])
		if life <= 0.0 or k >= mp.instance_count:
			continue
		var f := life / maxf(float(s["life"]), 0.001)
		var sc := 0.28 + 0.5 * f
		mp.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), s["p"]))
		# 사라질 때는 색이 아니라 알파로 지운다. 색만 어둡게 하면 검은 알갱이가 남는다.
		mp.set_instance_color(k, P.a(P.hdr(s["col"], 1.4), f))
		k += 1
	mp.visible_instance_count = k
