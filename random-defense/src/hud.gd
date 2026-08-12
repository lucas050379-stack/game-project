extends Control

## 화면 위에 얹는 2D. 3D 는 `main.gd` 가 그리고 여기는 숫자와 글자만 맡는다.
## 상태를 하나도 안 들고 `m`(메인)을 읽기만 한다.

var m: Node

const PAD := 14.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if m == null:
		return
	if m.st == D.St.TITLE:
		_title()
		return
	# 초상은 **패널보다 먼저** 그린다. 나중에 그리면 아래쪽 유닛의 초상이 패널 위로 뜬다.
	if m.badges:
		_badges()
	_top()
	_hints()
	_story()
	_selection()
	_drag_box()
	if m.book:
		_book()
	if m.picking:
		_pick()
	if m.choosing:
		_choice()
	if m.st == D.St.OVER or m.st == D.St.WIN:
		_end(m.st == D.St.WIN)
	_toast()


# ══ 조각 ══════════════════════════════════════════════════════

func _panel(r: Rect2, alpha: float = 0.92) -> void:
	draw_rect(r, P.a(P.PANEL, alpha), true)
	draw_rect(r, P.a(P.PANEL_HI, 0.9), false, 2.0)


## **`draw_string` 은 `width` 를 안 주면 정렬을 통째로 무시한다.** 가운데·오른쪽으로
## 맞춘 줄 알았던 글자가 그냥 왼쪽부터 그려져 화면 밖으로 흘러나간다(실제로 그랬다).
## 그래서 폭을 안 줬을 때는 글자 폭을 직접 재서 시작점을 옮긴다.
func _txt(pos: Vector2, s: String, size: int, col: Color, bold: bool = true,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := P.font(bold)
	var p := pos
	var al := align
	if width < 0.0 and al != HORIZONTAL_ALIGNMENT_LEFT:
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w if al == HORIZONTAL_ALIGNMENT_RIGHT else w * 0.5
		al = HORIZONTAL_ALIGNMENT_LEFT
	draw_string(f, p, s, al, width, size, col)


## 폭에 맞춰 여러 줄로 흘린다.
## **`draw_string` 은 폭을 주면 줄을 바꾸는 게 아니라 잘라 버린다** — 설명문에 쓰면
## 뒷부분이 소리 없이 사라진다(난이도 설명이 실제로 잘렸다).
func _wrap(pos: Vector2, s: String, size_: int, col: Color, width: float,
		bold: bool = false) -> void:
	draw_multiline_string(P.font(bold), pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size_,
		-1, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, P.a(P.LINE, 0.85), true)
	var f := clampf(frac, 0.0, 1.0)
	if f > 0.0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col, true)
	draw_rect(r, P.a(P.PANEL_HI, 0.8), false, 1.0)


# ══ 유닛 초상 ══════════════════════════════════════════════════

## 유닛 머리 위에 캐릭터 초상을 띄운다.
##
## **등급 색과 역할 도안만으로는 310종이 구별되지 않는다.** 도안은 역할 3종뿐이고 등급은
## 색과 크기로만 내므로, 같은 등급 유닛은 판에서 전부 똑같이 생겼다 — 특정 캐릭터를
## 눈으로 찾는 일이 사실상 불가능했다.
##
## 3D 쪽에 `Sprite3D` 를 유닛마다 붙이는 대신 **여기서 화면 좌표로 찍는다.** 노드를 안
## 만들어도 되고, 멀든 가깝든 초상 크기가 일정해서 오히려 읽기 쉽다.
func _badges() -> void:
	var g: Game = m.g
	var cam: Camera3D = m.cam
	if cam == null:
		return
	var h := 22.0
	var w := h * Ico.ASPECT
	for un in g.units:
		var ui := int(un["ui"])
		var gr := int(U.UNITS[ui]["g"])
		# `main.gd` 의 유닛 크기 식과 같아야 초상이 머리 위에 붙는다
		var sc := 1.15 + 0.030 * float(gr)
		var p: Vector3 = (un["p"] as Vector3) + Vector3(0.0, 1.75 * sc, 0.0)
		if cam.is_position_behind(p):
			continue
		var q := cam.unproject_position(p)
		if q.x < -w or q.x > size.x + w or q.y < 0.0 or q.y > size.y:
			continue
		var r := Rect2(q - Vector2(w * 0.5, h), Vector2(w, h))
		var sel: bool = un["sel"]
		var t := Ico.of(ui)
		if t != null:
			draw_texture_rect(t, r, false)
		else:
			draw_rect(r, P.a(P.grade(gr), 0.65), true)
		# 테두리가 등급이다. 고른 것은 두껍게.
		draw_rect(r, P.grade(gr) if sel else P.a(P.grade(gr), 0.75), false, 2.0 if sel else 1.0)
		if sel:
			_txt(Vector2(q.x, r.position.y - 5.0), String(U.UNITS[ui]["n"]), 12,
				P.grade(gr), true, HORIZONTAL_ALIGNMENT_CENTER)


# ══ 위쪽 띠 ════════════════════════════════════════════════════

func _top() -> void:
	var g: Game = m.g
	var r := Rect2(PAD, PAD, size.x - PAD * 2.0, 56.0)
	_panel(r)
	var y := r.position.y + 24.0
	var x := r.position.x + 16.0

	_txt(Vector2(x, y), "라운드", 13, P.DIM)
	_txt(Vector2(x, y + 20.0), "%d / %d" % [g.round_no, D.MAX_ROUND], 20, P.WHITE)
	if D.is_boss_round(g.round_no):
		_txt(Vector2(x + 64.0, y + 20.0), "보스", 14, P.CRIMSON)
	x += 112.0

	# 다음 라운드까지
	_txt(Vector2(x, y), "다음", 13, P.DIM)
	_bar(Rect2(x, y + 8.0, 96.0, 14.0), m.round_t / D.ROUND_TIME, P.PANEL_HI)
	x += 118.0

	# 몬스터 — 이 숫자가 곧 남은 목숨이다
	var alive: int = m.w.field_alive()
	var f := float(alive) / float(D.LOSE_COUNT)
	var col := P.JADE if f < 0.5 else (P.GOLD if f < 0.8 else P.CRIMSON)
	_txt(Vector2(x, y), "몬스터", 13, P.DIM)
	_bar(Rect2(x, y + 8.0, 150.0, 14.0), f, col)
	_txt(Vector2(x + 158.0, y + 20.0), "%d / %d" % [alive, D.LOSE_COUNT], 17, col)
	x += 232.0

	_txt(Vector2(x, y), "위습", 13, P.DIM)
	_txt(Vector2(x, y + 20.0), str(g.wisp), 20, P.WISP)
	x += 76.0
	_txt(Vector2(x, y), "목재", 13, P.DIM)
	_txt(Vector2(x, y + 20.0), str(g.lumber), 20, P.LUMBER)
	x += 76.0
	# 골드는 잡아서 버는 것이라 위습·목재와 성격이 다르다. 살 수 있을 때만 밝게.
	_txt(Vector2(x, y), "골드", 13, P.DIM)
	_txt(Vector2(x, y + 20.0), P.n(g.gold), 20,
		P.GOLD if g.gold >= D.WISP_PRICE else P.DIMMER)
	x += 108.0
	# 스토리 보상 — 다음에 무슨 등급이 나오는지까지 보여야 언제 쓸지를 정할 수 있다
	var parts := []
	if not g.reward_wisps.is_empty():
		parts.append("[R] %d (%s)" % [g.reward_wisps.size(), g.next_reward()])
	if g.wisp_pick > 0:
		parts.append("[T] 흔함 선택 %d" % g.wisp_pick)
	if g.wisp_choice > 0:
		parts.append("특전 %d" % g.wisp_choice)
	if not parts.is_empty():
		_txt(Vector2(x, y), "스토리 보상", 13, P.DIM)
		_txt(Vector2(x, y + 20.0), "   ".join(parts), 15, P.JADE)


## 조작 안내. **위쪽 띠에 두지 마라** — 왼쪽 숫자들이 길어지면 오른쪽 정렬한 안내와
## 겹친다(스토리 보상이 늘어나자 실제로 겹쳤다). 아래 왼쪽은 늘 비어 있다.
func _hints() -> void:
	# 아래 가운데는 선택 패널이 차지하므로 **줄을 짧게** 유지한다 — 길어지면 그 아래로 파고든다
	var lines := [
		"[Q] 뽑기 · [W] 나무 · [E] 랜덤(목재 %d · %d%%)"
			% [D.LUMBER_COST, int(D.LUMBER_HIT * 100.0)],
		"[F] 압살롬(목재 %d · %d%%) · [G] 위습 사기(골드 %d)"
			% [D.ABSALOM_COST, int(D.ABSALOM_CHANCE * 100.0), D.WISP_PRICE],
		"[R] 보상 · [T] 흔함 선택 · [Tab] 조합표",
		"드래그 = 고르기 · 오른쪽 = 이동 · [A] 전체",
		"한 기만 고르면 [1~%d] 로 조합" % m.UP_SLOTS,
	]
	var y := size.y - 12.0 - float(lines.size()) * 17.0
	for i in lines.size():
		_txt(Vector2(PAD + 2.0, y + float(i) * 17.0), lines[i], 12,
			P.DIM if i == 3 else P.DIMMER)


# ══ 스토리 ════════════════════════════════════════════════════

func _story() -> void:
	var g: Game = m.g
	var r := Rect2(size.x - PAD - 240.0, size.y - 150.0, 240.0, 66.0)
	_panel(r)
	var x := r.position.x + 14.0
	if g.story_done():
		_txt(Vector2(x, r.position.y + 26.0), "스토리 완주", 17, P.JADE)
		_txt(Vector2(x, r.position.y + 50.0), "%d단계 전부 클리어" % D.STORY_STAGES, 13, P.DIM)
		return
	_txt(Vector2(x, r.position.y + 24.0), "스토리 %d / %d 단계"
		% [g.story_stage, D.STORY_STAGES], 16, P.STORY_EDGE)
	_bar(Rect2(x, r.position.y + 34.0, r.size.x - 28.0, 10.0),
		float(g.story_cleared) / float(D.STORY_STAGES), P.STORY_EDGE)
	_txt(Vector2(x, r.position.y + 58.0),
		"남은 적 %d · 유닛을 오른쪽 판으로" % m.w.story_alive(), 12, P.DIM)


# ══ 고른 유닛 ══════════════════════════════════════════════════

## 한 줄 안에서 색을 바꿔 가며 이어 그린다. "가진 것"과 "모자란 것"이 같은 줄에
## 섞여 나오므로 색이 갈려야 읽힌다.
func _run(pos: Vector2, parts: Array, size_: int) -> float:
	var f := P.font()
	var x := pos.x
	for p in parts:
		var s: String = p[0]
		draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_, p[1])
		x += f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_).x
	return x


const UP_H := 26.0


## 유닛 아이콘. **없으면 등급 색 네모를 대신 그린다** — 자리를 비우면 그림이 없는
## 유닛만 줄이 밀려서 목록이 들쭉날쭉해진다. 그린 폭을 돌려준다.
func _icon(ui: int, at: Vector2, h: float) -> float:
	var w := h * Ico.ASPECT
	var r := Rect2(at, Vector2(w, h))
	var t := Ico.of(ui)
	if t != null:
		draw_texture_rect(t, r, false)
	else:
		draw_rect(r, P.a(P.grade(int(U.UNITS[ui]["g"])), 0.35), true)
	draw_rect(r, P.a(P.LINE, 0.65), false, 1.0)
	return w


func _selection() -> void:
	var n: int = m.selected_count()
	if n <= 0:
		return
	var g: Game = m.g
	# 고른 것 중 가장 높은 등급 하나를 대표로 보여 준다
	var best := -1
	var best_g := -1
	for un in g.units:
		if not un["sel"]:
			continue
		var gr := int(U.UNITS[int(un["ui"])]["g"])
		if gr > best_g:
			best_g = gr
			best = int(un["ui"])
	if best < 0:
		return
	var u: Dictionary = U.UNITS[best]

	# **한 기만 골랐을 때만** 진화 목록을 낸다. 여러 기를 골랐을 때는 대표가 누구인지
	# 애매해서 엉뚱한 유닛의 조합법을 보여 주게 된다.
	# 목록은 `main.gd` 가 만든 것을 그대로 쓴다 — 여기서 다시 만들면 숫자키가 가리키는
	# 줄과 화면에 보이는 줄이 어긋날 수 있다.
	var ups: Array = m.sel_ups if n == 1 else []
	var rows: int = mini(ups.size(), int(m.UP_SLOTS))
	var w := 760.0 if n == 1 else 400.0
	var h := 78.0
	if n == 1:
		h += 26.0 + float(maxi(rows, 1)) * UP_H
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 14.0 - h, w, h)
	_panel(r)

	var x := r.position.x + 14.0
	var iw := _icon(best, Vector2(x, r.position.y + 12.0), 40.0)
	x += iw + 12.0
	var gc := P.grade(int(u["g"]))
	_txt(Vector2(x, r.position.y + 26.0), String(u["n"]), 19, gc)
	_txt(Vector2(x + 8.0 + P.font().get_string_size(String(u["n"]), 0, -1, 19).x,
		r.position.y + 26.0), U.GRADE[int(u["g"])], 13, gc)
	_txt(Vector2(r.end.x - 14.0, r.position.y + 26.0), "%d기 선택" % n, 14, P.DIM,
		true, HORIZONTAL_ALIGNMENT_RIGHT)

	var y := r.position.y + 52.0
	_txt(Vector2(x, y), "역할 %s" % U.ROLE[int(u["r"])], 13, P.role(int(u["r"])))
	_txt(Vector2(x + 86.0, y), "초당 %s" % P.n(int(D.dps(u))), 13, P.WHITE)
	_txt(Vector2(x + 184.0, y), "사거리 %.1f" % D.reach(u), 13, P.DIM)
	var tags := _tags(u)
	if tags != "":
		_txt(Vector2(r.end.x - 14.0, y), tags, 12, P.DIMMER, true, HORIZONTAL_ALIGNMENT_RIGHT)

	if n != 1:
		return
	_upgrades(r, ups, rows)


## 고른 유닛을 재료로 쓰는 조합법들. 재료마다 `가진 수 / 필요 수` 를 붙여
## **무엇이 모자라는지**를 바로 읽게 한다.
func _upgrades(r: Rect2, ups: Array, rows: int) -> void:
	var x := r.position.x + 14.0
	var y := r.position.y + 78.0
	draw_line(Vector2(r.position.x + 10.0, y - 4.0), Vector2(r.end.x - 10.0, y - 4.0),
		P.a(P.PANEL_HI, 0.8), 1.0)

	if ups.is_empty():
		_txt(Vector2(x, y + 20.0), "이 유닛을 쓰는 조합법이 없다", 13, P.DIMMER)
		return
	# **"지금 되는 것"과 "언젠가 쓰이는 것"을 갈라서 센다.** 쉬움에서는 목록이 재료로
	# 이어지는 것까지 다 걸려 200줄이 넘는데, 그 수를 "진화 가능"이라 적으면 거짓말이 된다.
	var ready := 0
	for e in ups:
		if int(e["missing"]) == 0:
			ready += 1
	_txt(Vector2(x, y + 18.0), "지금 조합 가능 %d — 숫자키로" % ready, 14,
		P.GOLD if ready > 0 else P.DIMMER)
	_txt(Vector2(r.end.x - 14.0, y + 18.0), "이 유닛을 쓰는 조합 %d" % ups.size(), 12, P.DIMMER,
		true, HORIZONTAL_ALIGNMENT_RIGHT)

	for i in rows:
		var e: Dictionary = ups[i]
		var tu: Dictionary = U.UNITS[int(e["ui"])]
		var ry := y + 40.0 + float(i) * UP_H
		var done := int(e["missing"]) == 0
		var gc := P.grade(int(tu["g"]))
		# 만들 수 있는 줄만 번호가 밝다. 모자란 줄도 번호를 그대로 두는 것은
		# 목록에서 빼면 번호가 계속 바뀌어 "3번을 눌렀는데 다른 게 나왔다"가 되기 때문이다.
		_txt(Vector2(x, ry), "[%d]" % (i + 1), 13, P.GOLD if done else P.DIMMER)
		_icon(int(e["ui"]), Vector2(x + 28.0, ry - 15.0), 20.0)
		# 이름 칸을 좁게 잡지 마라 — `쵸파 럼블볼강화` 처럼 긴 이름이 등급 칸을 파고든다
		_txt(Vector2(x + 62.0, ry), String(tu["n"]), 14,
			gc if done else P.mix(gc, P.PANEL, 0.35))
		_txt(Vector2(x + 200.0, ry), U.GRADE[int(tu["g"])], 11,
			P.DIM if done else P.DIMMER)
		# 쉬움에서 모자란 재료를 **만들어 가며** 이어 붙일 때 붙는 표시.
		# 안 붙이면 재료가 빨간데 왜 조합이 되는지 알 수가 없다.
		if int(e.get("via", 1)) == 2:
			_txt(Vector2(x + 248.0, ry), "자동", 11, P.GOLD)

		# 재료 — 갖춘 것은 옥색, **만들어서 채울 것은 금색**, 아예 모자란 것은 붉은색
		var parts := []
		for k in (e["mats"] as Array).size():
			var mrow: Array = (e["mats"] as Array)[k]
			var mi := int(mrow[0])
			var got := int(mrow[1])
			var need := int(mrow[2])
			var state := int(mrow[3]) if mrow.size() > 3 else (0 if got >= need else 2)
			var nm := String(U.UNITS[mi]["n"]) if mi >= 0 else "?"
			if k > 0:
				parts.append([" · ", P.DIMMER])
			parts.append([nm, P.DIM if state == 0 else P.DIMMER])
			parts.append([" %d/%d" % [got, need],
				P.JADE if state == 0 else (P.GOLD if state == 1 else P.CRIMSON)])
		_run(Vector2(x + 292.0, ry), parts, 12)


## 전투에 실제로 쓰이는 태그만 보여 준다. 24종을 다 늘어놓으면 읽히지 않는다.
func _tags(u: Dictionary) -> String:
	var out := []
	if D.has_tag(u, U.T_SPLASH):
		out.append("범위")
	if D.has_tag(u, U.T_SLOW):
		out.append("둔화")
	if D.has_tag(u, U.T_STUN) or D.has_tag(u, U.T_SSTUN):
		out.append("스턴")
	if D.has_tag(u, U.T_ARMORBREAK):
		out.append("방무")
	if D.has_tag(u, U.T_LAST):
		out.append("끝딜")
	if D.has_tag(u, U.T_BOSS):
		out.append("보스")
	return " · ".join(out)


# ══ 드래그 상자 ════════════════════════════════════════════════

func _drag_box() -> void:
	if not m.drag:
		return
	var a: Vector2 = m.drag_a
	var b: Vector2 = m.drag_b
	var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
	if r.size.length() < 4.0:
		return
	draw_rect(r, P.a(P.JADE, 0.12), true)
	draw_rect(r, P.a(P.JADE, 0.9), false, 1.5)


# ══ 창 ════════════════════════════════════════════════════════

## 전체 조합표. 247개를 한 화면에 늘어놓을 수는 없으므로 **등급으로 갈라 쪽 단위로** 본다.
## 재료마다 지금 가진 수를 같이 붙여, 표를 보다가 바로 "이건 하나만 더 모으면 되네"가 읽히게 한다.
func _book() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.a(P.VOID, 0.90), true)
	var grades := D.recipe_grades()
	if grades.is_empty():
		return
	var sel: int = clampi(int(m.book_gi), 0, grades.size() - 1)
	var gi: int = grades[sel]
	var list: Array = D.recipes_of_grade(gi)
	var easy: bool = (m.g as Game).mode == D.Mode.EASY
	var rows: int = int(m.book_rows())
	var pages: int = maxi(1, (list.size() + rows - 1) / rows)
	# 쪽은 줄 커서에서 계산한다 — 따로 들면 둘이 어긋난다
	var page: int = clampi(int(m.book_row) / rows, 0, pages - 1)

	var rh := 46.0 if easy else 28.0
	var w := minf(size.x - 80.0, 1080.0)
	var h := 100.0 + float(rows) * rh
	var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
	_panel(r, 0.97)

	var x := r.position.x + 20.0
	_txt(Vector2(x, r.position.y + 34.0), "전체 조합표", 23, P.WHITE)
	_txt(Vector2(x + 142.0, r.position.y + 34.0),
		"%s  %d종" % [U.GRADE[gi], list.size()], 17, P.grade(gi))
	_txt(Vector2(r.end.x - 20.0, r.position.y + 22.0),
		"[←][→] 등급   [↑][↓] 줄   쪽 %d/%d   [Enter] 조합   [Tab] 닫기" % [page + 1, pages],
		13, P.DIMMER, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_txt(Vector2(r.end.x - 20.0, r.position.y + 42.0),
		"난이도 %s" % D.MODE_NAME[(m.g as Game).mode], 13,
		P.JADE if easy else P.DIMMER, true, HORIZONTAL_ALIGNMENT_RIGHT)

	# 등급 띠 — 지금 보는 등급이 전체에서 어디쯤인지 한눈에 보인다
	var bw := (r.size.x - 40.0) / float(grades.size())
	for i in grades.size():
		var on := i == sel
		draw_rect(Rect2(x + float(i) * bw, r.position.y + 48.0, bw - 3.0, 5.0),
			P.grade(grades[i]) if on else P.a(P.grade(grades[i]), 0.26), true)

	var have: Dictionary = (m.g as Game).counts()
	for i in rows:
		var k := page * rows + i
		if k >= list.size():
			break
		var ui: int = list[k]
		var u: Dictionary = U.UNITS[ui]
		var ry := r.position.y + 82.0 + float(i) * rh
		var mats: Array = u["m"]
		# 한 번만 묻는다 — 재귀 판정이라 줄마다 두 번 부르면 표를 넘길 때 티가 난다
		var way: int = (m.g as Game).craft_way(ui)
		var done := way == 1

		# 줄 커서와 "지금 만들 수 있음"을 다른 방식으로 알린다 —
		# 둘 다 배경색이면 커서가 어디인지 안 보인다.
		if k == int(m.book_row):
			draw_rect(Rect2(r.position.x + 10.0, ry - 19.0, r.size.x - 20.0, rh - 2.0),
				P.a(P.PANEL_HI, 0.85), true)
		# 쉬움에서는 모자란 재료를 만들어 가며 이어 붙일 수 있으므로 그쪽도 금색 띠가 붙는다
		var base_ok := easy and way == 2
		if done or base_ok:
			draw_rect(Rect2(r.position.x + 10.0, ry - 19.0, 3.0, rh - 2.0), P.GOLD, true)

		_icon(ui, Vector2(x, ry - 17.0), 22.0)
		_txt(Vector2(x + 38.0, ry), String(u["n"]), 15,
			P.grade(int(u["g"])) if (done or base_ok) else P.mix(P.grade(int(u["g"])), P.PANEL, 0.30))
		_run(Vector2(x + 210.0, ry), _mat_parts(mats, have), 13)
		_txt(Vector2(r.end.x - 20.0, ry), "최하위 %d" % int(u["c"]), 12, P.DIMMER,
			true, HORIZONTAL_ALIGNMENT_RIGHT)

		# 쉬움 전용 둘째 줄 — **최하위 유닛이 종류별로 몇 개 드는지.**
		# 조합 트리를 머리에 담지 않고도 "무엇을 얼마나 모으면 되는가"가 바로 읽힌다.
		if easy:
			_txt(Vector2(x + 38.0, ry + 19.0), "최하위", 11, P.DIMMER)
			_run(Vector2(x + 84.0, ry + 19.0), _mat_parts(u["l"], have), 12)


## 재료 줄을 `이름 가진수/필요수` 조각들로 만든다. 채운 것은 옥색.
func _mat_parts(list: Array, have: Dictionary) -> Array:
	var g: Game = m.g
	var parts := []
	for j in list.size():
		var mm: Array = list[j]
		var mi := D.index_of(int(mm[0]))
		var need := int(mm[1])
		# 대체가 되는 재료(`랜덤전용유닛 1기`)가 있어 게임에게 물어본다
		var got := g.have_of(have, int(mm[0]))
		if j > 0:
			parts.append([" · ", P.DIMMER])
		parts.append([String(U.UNITS[mi]["n"]) if mi >= 0 else "?", P.DIM])
		parts.append([" %d/%d" % [got, need], P.JADE if got >= need else P.DIMMER])
	return parts


## 흔함 선택 위습 — 아홉 종 중에서 직접 고른다.
func _pick() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.a(P.VOID, 0.72), true)
	var g: Game = m.g
	var pool := D.grade_pool("흔함")
	var have := g.counts()
	var w := minf(size.x - 80.0, 700.0)
	var r := Rect2((size.x - w) * 0.5, size.y * 0.30, w, 186.0)
	_panel(r, 0.97)
	_txt(Vector2(r.get_center().x, r.position.y + 34.0),
		"흔함 선택 위습  ×%d" % g.wisp_pick, 22, P.JADE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(r.get_center().x, r.position.y + 58.0),
		"조합법에 모자란 흔함을 직접 고르시오   ·   [Esc] 닫기", 13, P.DIM,
		true, HORIZONTAL_ALIGNMENT_CENTER)
	var cw := (r.size.x - 32.0) / float(maxi(pool.size(), 1))
	var ih := 34.0
	for i in pool.size():
		var ui: int = pool[i]
		var u: Dictionary = U.UNITS[ui]
		var cx := r.position.x + 16.0 + cw * (float(i) + 0.5)
		_txt(Vector2(cx, r.position.y + 92.0), "[%d]" % (i + 1), 13, P.GOLD,
			true, HORIZONTAL_ALIGNMENT_CENTER)
		_icon(ui, Vector2(cx - ih * Ico.ASPECT * 0.5, r.position.y + 98.0), ih)
		_txt(Vector2(cx, r.position.y + 152.0), String(u["n"]), 15, P.WHITE,
			true, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(cx, r.position.y + 170.0), "보유 %d" % int(have.get(int(u["i"]), 0)),
			11, P.DIMMER, true, HORIZONTAL_ALIGNMENT_CENTER)


func _choice() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.a(P.VOID, 0.6), true)
	var cx := size.x * 0.5
	var cy := size.y * 0.34
	_txt(Vector2(cx, cy), "스토리 10단계 보상", 30, P.JADE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(cx, cy + 30.0), "하나를 고르시오", 15, P.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)
	# 칸 수가 늘어도 가운데에 모이도록 폭에서 계산한다 (고정 좌표로 두면 한쪽으로 쏠린다)
	var n := D.STORY_CHOICE.size()
	var cw := 190.0
	var gap := 16.0
	var total := float(n) * cw + float(n - 1) * gap
	for i in n:
		var r := Rect2(cx - total * 0.5 + float(i) * (cw + gap), cy + 60.0, cw, 78.0)
		_panel(r, 0.96)
		_txt(Vector2(r.position.x + 14.0, r.position.y + 30.0), "[%d]" % (i + 1), 14, P.DIMMER)
		_txt(Vector2(r.get_center().x, r.position.y + 58.0), D.STORY_CHOICE[i], 17, P.WHITE,
			true, HORIZONTAL_ALIGNMENT_CENTER)


func _toast() -> void:
	if m.toast_t <= 0.0:
		return
	var a := clampf(m.toast_t / 0.6, 0.0, 1.0)
	_txt(Vector2(size.x * 0.5, size.y * 0.26), m.toast, 24, P.a(m.toast_col, a),
		true, HORIZONTAL_ALIGNMENT_CENTER)


func _title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.a(P.VOID, 0.55), true)
	var cx := size.x * 0.5
	var cy := size.y * 0.28
	_txt(Vector2(cx, cy), "랜덤 디펜스", 54, P.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(cx, cy + 38.0), "유닛 %d종 · 등급 %d단계 · 조합법 %d개"
		% [U.UNITS.size(), U.GRADE.size(), _recipes()], 16, P.DIM,
		true, HORIZONTAL_ALIGNMENT_CENTER)

	var lines := [
		"몬스터는 고리를 끝없이 돈다. %d마리가 쌓이면 진다." % D.LOSE_COUNT,
		"위습으로 유닛을 뽑거나 나무 도박을 한다 (라운드마다 +%d)." % D.WISP_PER_ROUND,
		"오른쪽 스토리 판으로 유닛을 보내면 %d단계를 깰 수 있다." % D.STORY_STAGES,
	]
	for i in lines.size():
		_txt(Vector2(cx, cy + 90.0 + float(i) * 26.0), lines[i], 15, P.DIM,
			true, HORIZONTAL_ALIGNMENT_CENTER)

	# 난이도 두 장. **적의 세기는 둘이 같다** — 조합의 번거로움만 다르다.
	var y := cy + 184.0
	var cw := 350.0
	for i in D.MODE_NAME.size():
		var r := Rect2(cx - cw - 10.0 + float(i) * (cw + 20.0), y, cw, 124.0)
		_panel(r, 0.95)
		var col := P.JADE if i == D.Mode.EASY else P.WHITE
		_txt(Vector2(r.position.x + 16.0, r.position.y + 32.0), "[%d]" % (i + 1), 15, P.GOLD)
		_txt(Vector2(r.position.x + 48.0, r.position.y + 32.0), D.MODE_NAME[i], 22, col)
		_txt(Vector2(r.end.x - 16.0, r.position.y + 32.0), D.MODE_TAG[i], 12, P.DIMMER,
			true, HORIZONTAL_ALIGNMENT_RIGHT)
		_wrap(Vector2(r.position.x + 16.0, r.position.y + 62.0), D.MODE_DESC[i], 13,
			P.DIM, r.size.x - 32.0)

	_txt(Vector2(cx, y + 158.0), "숫자키로 난이도를 고르시오", 17,
		P.a(P.WHITE, 0.6 + 0.4 * sin(m.t * 4.0)), true, HORIZONTAL_ALIGNMENT_CENTER)


func _recipes() -> int:
	var n := 0
	for u in U.UNITS:
		if not (u["m"] as Array).is_empty():
			n += 1
	return n


func _end(win: bool) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.a(P.VOID, 0.72), true)
	var g: Game = m.g
	var cx := size.x * 0.5
	var cy := size.y * 0.38
	if win:
		_txt(Vector2(cx, cy), "방어 성공", 52, P.JADE, true, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(cx, cy + 42.0), "%d라운드를 전부 버텼다" % D.MAX_ROUND, 18, P.DIM,
			true, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_txt(Vector2(cx, cy), "밀렸다", 52, P.CRIMSON, true, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(cx, cy + 42.0), "%d라운드에서 몬스터 %d마리에 파묻혔다"
			% [g.round_no, D.LOSE_COUNT], 18, P.DIM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(cx, cy + 84.0), "스토리 %d / %d 단계" % [g.story_cleared, D.STORY_STAGES],
		15, P.DIMMER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_txt(Vector2(cx, cy + 132.0), "[F5] 다시", 22,
		P.a(P.WHITE, 0.6 + 0.4 * sin(m.t * 4.0)), true, HORIZONTAL_ALIGNMENT_CENTER)
