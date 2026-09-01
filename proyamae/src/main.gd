extends Control
# 프야매 — 화면 전환과 그리기.
#
# **노드를 만들지 마세요.** 모든 화면을 이 `_draw()` 한 곳에서 그립니다.
# 도감에 카드가 수천 장 깔리므로 화면 안에 든 것만 그려야 합니다.
#
# **새 화면을 만들면 키 분기와 마우스 분기를 둘 다 채우세요.** 그리고 자리를
# 정하는 함수를 하나 두어 **그리기와 클릭 판정이 같은 값을 보게** 하세요
# (`_tab_rect` · `_grid_rect` · `_slot_rect` · `_btn_rect`). 두 곳에서 따로
# 계산하면 한쪽만 고쳤을 때 조용히 어긋납니다.

# 화면은 **탭이 아니라 페이지**입니다. 홈에서 하나를 골라 들어가고, 왼쪽 위
# 뒤로가기(또는 `Esc`)로 돌아옵니다 — 원작 화면 구조가 그렇습니다.
# 탭 줄을 늘 띄워 두면 화면마다 쓸 수 있는 세로 폭이 그만큼 줄고, 작전처럼
# 위아래 두 판을 쌓아야 하는 화면이 눌립니다.
enum S { HOME, DEX, SCOUT, STUDY, ORDER, GAME }

# 홈에 늘어놓는 차례. `1`~`5` 키가 이 순서를 그대로 씁니다.
const MENU := [S.DEX, S.SCOUT, S.STUDY, S.ORDER, S.GAME]
const MENU_NAME := ["선수 도감", "스카우트", "구단관리", "작전", "시즌"]
const MENU_NOTE := [
	"모은 카드와 아직 못 모은 카드",
	"선수 카드와 스킬블록을 코인으로 뽑습니다",
	"유학 · 스킬블록 · 구종으로 카드를 키웁니다",
	"타순과 투수진을 짜고 팀컬러를 켭니다",
	"리그를 치르고 순위를 올립니다",
]

func screen_name(s: int) -> String:
	var i := MENU.find(s)
	return str(MENU_NAME[i]) if i >= 0 else "프야매"



const PAD := 22.0
# 오더 칸 높이. 탭을 둘로 나눠 두 줄만 그리므로 예전(112)보다 크게 잡습니다 —
# 25칸을 한 화면에 늘어놓던 시절의 크기라 카드가 잘 안 읽혔습니다.
const SLOT_H := 168.0

var screen: int = S.HOME
var rng := RandomNumberGenerator.new()
var toast := ""
var toast_t := 0.0

# 도감
var dex: Array = []
var dex_i := 0
var dex_scroll := 0.0
var f_year := 0
var f_grade := ""
var f_kind := ""
var f_team := ""
var f_cost := 0        # 0 = 전체
var f_pos := ""

# 펼쳐진 거르개 번호(-1 = 닫힘)와 그 목록의 스크롤.
var combo_i := -1
var combo_scroll := 0
var detail: Dictionary = {}    # 큰 화면에 띄운 카드 (비어 있으면 안 뜸)

# 스킬블록 드래그. `drag_uid` 가 -1 이 아니면 끌고 있는 중입니다.
# **끌고 있는 자리는 매 프레임 갱신**해야 미리보기가 손끝을 따라옵니다.
var drag_uid := -1
var drag_pos := Vector2.ZERO

# 오더 칸 드래그. `drag_slot` 이 "" 가 아니면 그 칸을 끌고 있는 중입니다.
# **같은 탭 안에서만** 바꿉니다 — 타자 칸에 투수를 떨구면 경기가 안 됩니다.
var drag_slot := ""
var drag_slot_i := 0
var order_tab := 0
# 수비 위치 드롭다운이 펼쳐진 타순 번호 (-1 = 닫힘)
var pos_open := -1

# 스카우트
var pack: Array = []
# 방금 뽑은 블록 — 스카우트 화면에 카드 대신 보여 줍니다.
var block_pack: Array = []
# 스카우트에서 고른 팩. 키로 고를 때 쓰고, 클릭하면 그 팩으로 맞춰집니다.
var pack_i := 0

# 오더
var sel_group := "lineup"
var sel_idx := 0
# 작전 화면 아래의 보유선수 목록과 그 스크롤.
var pool: Array = []
var pool_scroll := 0.0
var pool_i := 0
# 팀컬러 창이 열려 있는가. 늘 띄워 두면 분석 판이 들어갈 자리가 없습니다.
var pick_i := 0
var p_team := ""            # 고르기 창의 구단 거르개
var p_year := 0             # 고르기 창의 시즌 거르개
var p_pos := ""             # 고르기 창의 포지션 거르개
var p_cost := 0             # 고르기 창의 코스트 거르개

# 유학
var study_list: Array = []
var study_i := 0
var study_scroll := 0.0
# 구단관리 거르개와 유학 확인 창.
var g_cost := 0
var g_team := ""
var g_kind := ""
var study_modal := -1        # -1 = 안 뜸, 아니면 그 지역 번호
var grow_tab := 0            # 0 유학 · 1 스킬블록 · 2 구종

# 경기
var last_game: Dictionary = {}

# 자리 배치 확인용: run.bat -- --shot=out.png
# **캡처는 hdr_2d 때문에 실제보다 훨씬 어둡습니다.** 밝기 말고 자리만 보세요.
var _shot := ""
var _shot_wait := 0
var _want_play := false
var _want_pack := false
var _want_season := 0
var _click_test := false
var _ct := 0
var _ct_fail := 0
var _ct_a := ""
var _ct_b := ""
var _want_detail := false
var _want_back := false
var _want_bonus := false
var _back_kind := ""

func _ready() -> void:
	rng.randomize()
	set_process_unhandled_input(true)
	# **루트 Control 의 `mouse_filter` 를 IGNORE 로 두세요.** 기본값 STOP 이면
	# 이 노드가 마우스 이벤트를 GUI 입력으로 먼저 삼켜서 `_unhandled_input` 까지
	# 오지 않습니다 — 키보드는 멀쩡한데 **클릭만 통째로 안 먹습니다.**
	# 우리는 자식 Control 을 안 쓰고 좌표로 직접 판정하므로 GUI 처리가 필요 없습니다.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a == "--unlock":
			# 테스트 빌드와 같은 상태를 소스에서도 볼 수 있게 —
			# `run.bat -- --unlock` 으로 확인합니다.
			Sv.unlock_all()
		elif a == "--bonusdemo":
			_want_bonus = true
		elif a == "--deckfight":
			_deck_fight()
		elif a == "--deckscan":
			_deck_scan()
		elif a == "--colortest":
			_color_test()
		elif a == "--blocktest":
			_block_test()
		elif a.begins_with("--studymodal="):
			study_modal = int(a.split("=")[1])
		elif a.begins_with("--ordertab="):
			order_tab = int(a.split("=")[1])
		elif a.begins_with("--posopen="):
			pos_open = int(a.split("=")[1])
		elif a.begins_with("--growtab="):
			grow_tab = int(a.split("=")[1])
		elif a.begins_with("--screen="):
			var n := a.substr(9)
			var mi := MENU_NAME.find(n)
			if mi >= 0:
				screen = int(MENU[mi])
		elif a.begins_with("--simtest"):
			var cnt := 500
			if "=" in a:
				cnt = int(a.split("=")[1])
			_sim_test(cnt)
			get_tree().quit()
			return
		elif a == "--demo":
			_demo_fill()
		elif a.begins_with("--growtab="):
			grow_tab = int(a.split("=")[1])
		elif a == "--pack":
			_want_pack = true
		elif a.begins_with("--season="):
			_want_season = int(a.split("=")[1])
		elif a == "--detail":
			_want_detail = true
		elif a.begins_with("--back"):
			_want_detail = true
			_want_back = true
			if a.contains("="):
				_back_kind = a.split("=")[1]
		elif a == "--clicktest":
			_click_test = true
		elif a == "--play":
			_want_play = true
	_refilter()
	_refresh_study()
	_refresh_pool()
	if _want_pack:
		_do_pack()
	for _i in range(_want_season):
		_do_game()
	if _want_bonus:
		_bonus_demo()
	if _want_detail and not dex.is_empty():
		detail = dex[0]
		if _back_kind != "":
			for c in dex:
				if str(c.get("kind", "")) == _back_kind:
					detail = c
					break
		# 확인용으로 블록 몇 개를 끼워 둡니다 — 빈 판만 찍으면 조각이 안 보입니다.
		var kind := "pitcher" if str(detail.get("kind", "")) == "pitcher" else "hitter"
		if Gr.free_blocks(kind).size() < 4:
			Gr.draw_blocks(12)
		Gr.clear_board(detail)
		Gr.auto_fill(detail)
	if _want_play:
		_do_game()
	queue_redraw()

func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
	queue_redraw()
	if _click_test:
		_click_test_step()
	if _shot != "":
		_shot_wait += 1
		if _shot_wait == 10:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("saved ", _shot)
			get_tree().quit()

func _say(s: String) -> void:
	toast = s
	toast_t = 2.6

# ── 시뮬 검산 ──────────────────────────────────────────────────────────────
# run.bat -- --simtest=500
# **수치를 만졌으면 여기부터 돌리세요.** KBO 한 팀 평균 득점은 4.5~5.5점입니다.
# 크게 벗어나면 확률표(`D.PA_BASE`)나 계수(`D.K_*`)가 어긋난 것이고, 그 상태로는
# 오더를 아무리 잘 짜도 결과가 이상하게 나옵니다.

func _bonus_demo() -> void:
	# 확인용 — 한 카드에 유학·블록·팀컬러를 다 붙여 큰 화면을 찍습니다.
	if study_list.is_empty():
		return
	var c: Dictionary = study_list[0]
	var id := DB.card_id(c)
	Sv.tier = 4
	Sv.coins = 999999
	Sv.study_done[id] = [0, 1, 2]
	if Gr.free_blocks("pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter").size() < 3:
		Gr.draw_blocks(14)
	Gr.clear_board(c)
	Gr.auto_fill(c)
	Sv.games[id] = 60
	DB.clear_cache()
	_refresh_study()
	detail = DB.find(id)

# ── 덱 훑기 ────────────────────────────────────────────────────────────────
# `run.bat -- --deckscan` — **단일구단 · 단일연도로 짤 수 있는 가장 비싼 덱**.
#
# 코스트 총합이 곧 그 풀의 두께입니다. 상한(`D.COST_CAP`)을 넘는 덱은 실제로
# 못 쓰지만, **넘길 수 있다는 것 자체가 "고를 여유가 있다"는 뜻**이라 어느
# 구단·시즌이 센지를 가늠하는 자로 씁니다.
const SCAN_TOP := 10

func _deck_scan() -> void:
	if DB.cards.is_empty():
		print("선수 자료가 없습니다.")
		return
	var by_fr := {}
	var by_yr := {}
	var by_dy := {}
	for c in DB.cards:
		var f := Col.lineage(str(c.get("team", "")))
		var y := int(c.get("year", 0))
		_bucket(by_fr, f, c)
		_bucket(by_yr, y, c)
		_bucket(by_dy, "%s|%d" % [f, y], c)
	print("오더 %d칸(타자 %d · 투수 %d) · 코스트 상한 %d" % [
		Col.roster_size(), D.LINEUP + D.BENCH, D.ROT + D.RELIEF + 2, D.COST_CAP])
	print("")
	_scan_group(by_fr, "단일구단", true)
	print("")
	_scan_group(by_yr, "단일연도", false)
	print("")
	_scan_group(by_dy, "왕조 (구단+시즌)", false)
	get_tree().quit()

func _scan_group(buckets: Dictionary, title: String, label_fr: bool) -> void:
	var rows: Array = []
	for k in buckets:
		var r := _deck_cost(buckets[k])
		if r.is_empty():
			continue
		r["label"] = Col.lineage_label(str(k)) if label_fr else str(k)
		rows.append(r)
	rows.sort_custom(func(a, b): return int(a["cost"]) > int(b["cost"]))
	print("=== %s — 짤 수 있는 최대 코스트 ===" % title)
	print("  %-18s %6s %8s %8s" % ["", "코스트", "평균OV", "후보"])
	for i in range(mini(rows.size(), SCAN_TOP)):
		var r: Dictionary = rows[i]
		print("  %-18s %6d %8.1f %8d" % [str(r["label"]), int(r["cost"]),
			float(r["ov"]), int(r["pool"])])
	if rows.is_empty():
		print("  (25칸을 채울 수 있는 곳이 없습니다)")

func _deck_cost(pool: Array) -> Dictionary:
	# 그 풀에서 짤 수 있는 **가장 비싼 25칸**. 타자 14 · 투수 11 을 각각 코스트
	# 내림차순으로 고르되, **같은 이름은 한 번만** — 오더 규칙과 같아야 합니다.
	var hit: Array = []
	var pit: Array = []
	for c in pool:
		if str(c.get("kind", "")) == "pitcher":
			pit.append(c)
		else:
			hit.append(c)
	var need_h := D.LINEUP + D.BENCH
	var need_p := D.ROT + D.RELIEF + 2
	var ph := _top_cost(hit, need_h)
	var pp := _top_cost(pit, need_p)
	if ph.size() < need_h or pp.size() < need_p:
		return {}
	var cost := 0
	var ovs := 0.0
	for c in ph + pp:
		cost += int(c.get("cost", 1))
		ovs += float(c.get("ov", 0))
	return {"cost": cost, "ov": ovs / float(need_h + need_p), "pool": pool.size()}

func _top_cost(pool: Array, n: int) -> Array:
	var s := pool.duplicate()
	# 코스트가 같으면 종합이 높은 쪽을 먼저 — 같은 값이면 더 센 카드를 씁니다.
	s.sort_custom(func(a, b):
		if int(a.get("cost", 1)) != int(b.get("cost", 1)):
			return int(a.get("cost", 1)) > int(b.get("cost", 1))
		return int(a.get("ov", 0)) > int(b.get("ov", 0)))
	var out: Array = []
	var seen := {}
	for c in s:
		if out.size() >= n:
			break
		var nm := str(c.get("name", ""))
		if seen.has(nm):
			continue
		seen[nm] = true
		out.append(c)
	return out

# ── 덱 대결 ────────────────────────────────────────────────────────────────
# `run.bat -- --deckfight` — **코스트 제한 없이** 단일구단 · 단일연도 · 왕조의
# 최강 덱을 각각 뽑아 서로 붙입니다.
#
# 코스트를 풀면 "그 풀에서 가장 좋은 25명"이 그대로 덱이 되므로, **풀의 두께가
# 곧 세기**입니다. 팀컬러 보너스가 그 차이를 얼마나 메우는지를 보는 것이 요점입니다.
const FIGHT_RANK_GAMES := 120   # 갈래 안에서 1등을 가릴 때
const FIGHT_GAMES := 600        # 결승 맞대결
const FIGHT_FOE_OV := 80        # 1등을 가릴 때 쓰는 기준 상대

func _deck_fight() -> void:
	if DB.cards.is_empty():
		print("선수 자료가 없습니다.")
		return
	var by_fr := {}
	var by_yr := {}
	var by_dy := {}
	for c in DB.cards:
		var f := Col.lineage(str(c.get("team", "")))
		var y := int(c.get("year", 0))
		_bucket(by_fr, f, c)
		_bucket(by_yr, y, c)
		_bucket(by_dy, "%s|%d" % [f, y], c)

	print("코스트 제한 없음 · 오더 %d칸 · 팀컬러 켬" % Col.roster_size())
	print("")
	var champs: Array = []
	champs.append(_champion(by_fr, "단일구단", true))
	champs.append(_champion(by_yr, "단일연도", false))
	champs.append(_champion(by_dy, "왕조", false))
	for e in champs:
		if (e as Dictionary).is_empty():
			print("덱을 못 짠 갈래가 있습니다.")
			return

	print("=== 갈래별 최강 덱 ===")
	print("  %-10s %-16s %6s %7s %8s  %s" % ["갈래", "덱", "코스트", "평균OV", "기준승률", "팀컬러 보너스"])
	for e in champs:
		var d: Dictionary = e
		print("  %-10s %-16s %6d %7.1f %7.1f%%  %s" % [str(d["kind"]), str(d["label"]),
			int(d["cost"]), float(d["ov"]), float(d["win"]) * 100.0, str(d["colortxt"])])
	print("")

	print("=== 맞대결 (%d경기 · 홈·원정 번갈아) ===" % FIGHT_GAMES)
	for i in range(champs.size()):
		for j in range(i + 1, champs.size()):
			var a: Dictionary = champs[i]
			var b: Dictionary = champs[j]
			var r := RandomNumberGenerator.new()
			r.seed = 777
			var aw := 0
			var draw := 0
			var ar := 0.0
			var br := 0.0
			for n in range(FIGHT_GAMES):
				# **홈·원정을 번갈아** 붙입니다 — 한쪽으로 몰면 자리 이점이 섞입니다.
				var home_is_a := n % 2 == 0
				var g := Sim.play(b["team"], a["team"], r) if home_is_a else Sim.play(a["team"], b["team"], r)
				var sa := int(g["score"][1]) if home_is_a else int(g["score"][0])
				var sb := int(g["score"][0]) if home_is_a else int(g["score"][1])
				ar += sa
				br += sb
				if sa > sb:
					aw += 1
				elif sa == sb:
					draw += 1
			var played := FIGHT_GAMES - draw
			var pct := 100.0 * float(aw) / float(maxi(played, 1))
			print("  %s(%s) vs %s(%s) — %.1f%% : %.1f%%   득점 %.2f : %.2f" % [
				str(a["kind"]), str(a["label"]), str(b["kind"]), str(b["label"]),
				pct, 100.0 - pct, ar / float(FIGHT_GAMES), br / float(FIGHT_GAMES)])

	get_tree().quit()

func _champion(buckets: Dictionary, kind: String, label_fr: bool) -> Dictionary:
	# 그 갈래에서 **기준 상대에게 제일 잘 이기는** 덱. 스텟 합으로 고르면
	# 팀컬러가 야수·투수에 다르게 붙는 것이 안 잡힙니다.
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var foe := Sim.build_ai("기준", FIGHT_FOE_OV, r)
	var best := {}
	for k in buckets:
		var t := _free_deck(buckets[k])
		if t.is_empty():
			continue
		var rr := RandomNumberGenerator.new()
		rr.seed = 1234
		var w := 0
		for i in range(FIGHT_RANK_GAMES):
			# `play(away, home)` 이고 **`score[0]` 이 원정**입니다. 덱을 원정으로
			# 넣었으니 덱의 점수는 `score[0]` — 여기를 뒤집으면 순위가 통째로
			# 거꾸로 나옵니다(실제로 제일 약한 덱이 1등으로 올라왔습니다).
			var g := Sim.play(t["team"], foe, rr)
			if int(g["score"][0]) > int(g["score"][1]):
				w += 1
		t["win"] = float(w) / float(FIGHT_RANK_GAMES)
		t["kind"] = kind
		t["label"] = Col.lineage_label(str(k)) if label_fr else str(k)
		if best.is_empty() or float(t["win"]) > float(best["win"]):
			best = t
	return best

func _free_deck(pool: Array) -> Dictionary:
	# **코스트를 안 봅니다.** 값이 높은 순서로 타자 14 · 투수 11, 같은 이름은 한 번만.
	var hit: Array = []
	var pit: Array = []
	for c in pool:
		if str(c.get("kind", "")) == "pitcher":
			pit.append(c)
		else:
			hit.append(c)
	var need_h := D.LINEUP + D.BENCH
	var need_p := D.ROT + D.RELIEF + 2
	hit.sort_custom(func(a, b): return _anal_value(a) > _anal_value(b))
	pit.sort_custom(func(a, b): return _anal_value(a) > _anal_value(b))
	var ph := _take_uniq(hit, need_h)
	var pp := _take_uniq(pit, need_p)
	if ph.size() < need_h or pp.size() < need_p:
		return {}
	var t := {"name": "deck", "lineup": [], "pos": [], "bench": [], "rot": [],
		"relief": [], "setup": {}, "closer": {}, "rot_i": 0}
	for i in range(D.LINEUP):
		t["lineup"].append(ph[i])
		t["pos"].append(D.POS[i] if i < D.POS.size() else "지명타자")
	for i in range(D.BENCH):
		t["bench"].append(ph[D.LINEUP + i])
	for i in range(D.ROT):
		t["rot"].append(pp[i])
	for i in range(D.RELIEF):
		t["relief"].append(pp[D.ROT + i])
	t["setup"] = pp[D.ROT + D.RELIEF]
	t["closer"] = pp[D.ROT + D.RELIEF + 1]
	# **제일 센 팀컬러를 자동으로 켭니다**(`auto`).
	Sim.apply_color(t, "", true)
	var cost := 0
	var ovs := 0.0
	for c in ph + pp:
		cost += int(c.get("cost", 1))
		ovs += float(c.get("ov", 0))
	var col: Dictionary = t.get("color", {})
	var ctxt := "—"
	if not col.is_empty():
		ctxt = "%s (야수 +%d · 투수 +%d)" % [str(col["name"]), int(col["hit"]), int(col["pit"])]
	return {"team": t, "cost": cost, "ov": ovs / float(need_h + need_p), "colortxt": ctxt}

func _take_uniq(sorted_pool: Array, n: int) -> Array:
	var out: Array = []
	var seen := {}
	for c in sorted_pool:
		if out.size() >= n:
			break
		var nm := str(c.get("name", ""))
		if seen.has(nm):
			continue
		seen[nm] = true
		out.append(c)
	return out

func _color_test() -> void:
	# 팀컬러 검산. **로스터 컬러는 25칸을 다 채워야 켜지는데**, 세는 쪽이 벤치를
	# 빼먹으면 20명이 상한이라 **영영 안 켜집니다** — 화면에는 그냥 "조건 미달"로
	# 보여서 눈으로는 못 잡습니다(실제로 그렇게 나갔습니다).
	#
	# **네 가지 배치를 다 봅니다** — 단일팀만 · 단일연도만 · 왕조(둘 다) · 듀얼팀.
	# 하나만 보면 나머지 셋이 조용히 깨져도 통과합니다.
	var fail := 0
	Sv.reset()
	var need := Col.roster_size()

	# 카드를 구단별 · 시즌별 · 구단+시즌별로 모아 둡니다.
	var by_fr := {}
	var by_yr := {}
	var by_dy := {}
	for c in DB.cards:
		var f := Col.lineage(str(c.get("team", "")))
		var y := int(c.get("year", 0))
		_bucket(by_fr, f, c)
		_bucket(by_yr, y, c)
		_bucket(by_dy, "%s|%d" % [f, y], c)

	# ① 한 구단 + 한 시즌 25명 → 왕조 · 단일팀 · 단일연도가 **모두** 켜집니다.
	var dk = _pick_bucket(by_dy, need)
	if dk == null:
		print("  실패 한 구단·한 시즌에서 25명을 뽑을 조합이 없습니다")
		fail += 1
	else:
		_fill_order(by_dy[dk], need)
		fail += _expect("한 구단+한 시즌 25명", ["왕조", "단일팀", "단일연도"], [])
		# 한 명만 빼면 셋 다 꺼져야 합니다.
		Sv.bench[0] = ""
		fail += _expect("24명", [], ["왕조", "단일팀", "단일연도"])

	# ② 한 구단 · 여러 시즌 25명 → **단일팀만**. 왕조·단일연도는 꺼져야 합니다.
	var fk = _pick_bucket(by_fr, need, true)
	if fk == null:
		print("  실패 한 구단에서 여러 시즌 25명을 뽑을 조합이 없습니다")
		fail += 1
	else:
		_fill_order(_take_mixed(by_fr[fk], "year", 3), need)
		fail += _expect("한 구단·여러 시즌 25명", ["단일팀"], ["왕조", "단일연도"])

	# ③ 한 시즌 · 여러 구단 25명 → **단일연도만**.
	var yk = _pick_bucket(by_yr, need, true)
	if yk == null:
		print("  실패 한 시즌에서 여러 구단 25명을 뽑을 조합이 없습니다")
		fail += 1
	else:
		_fill_order(_take_mixed(by_yr[yk], "team", 4), need)
		fail += _expect("한 시즌·여러 구단 25명", ["단일연도"], ["왕조", "단일팀"])

	# ④ 두 구단이 절반씩 → **듀얼팀만**. 단일팀은 꺼져야 합니다.
	var two := _two_franchises(by_fr)
	if two.is_empty():
		print("  실패 듀얼팀을 만들 두 구단이 없습니다")
		fail += 1
	else:
		_fill_order(two, need)
		fail += _expect("두 구단 절반씩", ["듀얼팀"], ["단일팀", "왕조", "단일연도"])

	print("팀컬러 검사 — 실패 %d개" % fail)
	Sv.reset()
	get_tree().quit(1 if fail > 0 else 0)

func _bucket(d: Dictionary, k, c: Dictionary) -> void:
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(c)

func _pick_bucket(d: Dictionary, need: int, mixed: bool = false):
	# 25명을 채울 만큼 있는 통. `mixed` 면 **타자·투수가 둘 다 넉넉한** 통만
	# 고릅니다 — `_fill_order` 가 타순 14칸과 투수 11칸을 따로 채웁니다.
	for k in d:
		var hit := 0
		var pit := 0
		for c in d[k]:
			if str(c.get("kind", "")) == "pitcher":
				pit += 1
			else:
				hit += 1
		if hit >= D.LINEUP + D.BENCH and pit >= D.ROT + D.RELIEF + 2:
			if not mixed or (d[k] as Array).size() >= need + 10:
				return k
	return null

# pool 에서 타자 14 · 투수 11 을 뽑되, `spread` 가 같은 것끼리 `cap` 개를 넘지
# 않게 합니다. **종류별 수를 반드시 채워야 합니다** — 투수가 모자라면 오더에
# 빈 칸이 남고, 그러면 25명 조건이 안 서서 검사가 엉뚱하게 실패합니다.
func _take_mixed(pool: Array, spread: String, cap: int) -> Array:
	var out: Array = []
	for kind in ["hitter", "pitcher"]:
		var want := (D.LINEUP + D.BENCH) if kind == "hitter" else (D.ROT + D.RELIEF + 2)
		var seen := {}
		var got := 0
		# 1차 — cap 을 지키면서 채웁니다.
		for c in pool:
			if got >= want:
				break
			if str(c.get("kind", "")) != kind:
				continue
			var k = int(c.get("year", 0)) if spread == "year" else Col.lineage(str(c.get("team", "")))
			if int(seen.get(k, 0)) >= cap:
				continue
			seen[k] = int(seen.get(k, 0)) + 1
			out.append(c)
			got += 1
		# 2차 — 그래도 모자라면 cap 을 풀어 채웁니다(수를 채우는 것이 우선).
		if got < want:
			for c in pool:
				if got >= want:
					break
				if str(c.get("kind", "")) != kind:
					continue
				if out.has(c):
					continue
				out.append(c)
				got += 1
	return out

func _two_franchises(by_fr: Dictionary) -> Array:
	# 두 구단에서 절반씩. **각 구단이 `DUAL_EACH` 명 이상**이어야 듀얼팀이 켜집니다.
	# 시즌도 흩어야 합니다 — 안 그러면 단일연도까지 같이 켜져서 "듀얼팀만" 을
	# 못 봅니다(실제로 그랬습니다).
	var keys: Array = by_fr.keys()
	keys.sort_custom(func(a, b): return (by_fr[a] as Array).size() > (by_fr[b] as Array).size())
	if keys.size() < 2:
		return []
	var out: Array = []
	for kind in ["hitter", "pitcher"]:
		var want := (D.LINEUP + D.BENCH) if kind == "hitter" else (D.ROT + D.RELIEF + 2)
		("integer_division")
		var half := want / 2
		for side in range(2):
			var quota := half if side == 0 else want - half
			var seen := {}
			var got := 0
			for c in by_fr[keys[side]]:
				if got >= quota:
					break
				if str(c.get("kind", "")) != kind:
					continue
				var y := int(c.get("year", 0))
				if int(seen.get(y, 0)) >= 2:
					continue
				seen[y] = int(seen.get(y, 0)) + 1
				out.append(c)
				got += 1
			for c in by_fr[keys[side]]:
				if got >= quota:
					break
				if str(c.get("kind", "")) != kind or out.has(c):
					continue
				out.append(c)
				got += 1
	return out

func _expect(what: String, want_on: Array, want_off: Array) -> int:
	var names := _color_names()
	var bad := 0
	for w in want_on:
		if not _has_word(names, str(w)):
			print("  실패 [%s] %s 가 안 켜짐 — 켜진 것: %s" % [what, str(w), str(names)])
			bad += 1
	for w in want_off:
		if _has_word(names, str(w)):
			print("  실패 [%s] %s 가 켜지면 안 되는데 켜짐 — 켜진 것: %s" % [what, str(w), str(names)])
			bad += 1
	if bad == 0:
		print("  OK   %s — %s" % [what, str(names)])
	return bad

func _fill_order(pool: Array, need: int) -> void:
	# 오더 25칸을 pool 앞에서부터 채웁니다. 타자/투수 자리를 가려 넣습니다.
	var hit: Array = []
	var pit: Array = []
	for c in pool:
		if str(c.get("kind", "")) == "pitcher":
			pit.append(c)
		else:
			hit.append(c)
	var hi := 0
	var pi := 0
	for i in range(D.LINEUP):
		Sv.lineup[i] = DB.card_id(hit[hi % hit.size()]) if not hit.is_empty() else ""
		hi += 1
	for i in range(D.BENCH):
		Sv.bench[i] = DB.card_id(hit[hi % hit.size()]) if not hit.is_empty() else ""
		hi += 1
	for i in range(D.ROT):
		Sv.rot[i] = DB.card_id(pit[pi % pit.size()]) if not pit.is_empty() else ""
		pi += 1
	for i in range(D.RELIEF):
		Sv.relief[i] = DB.card_id(pit[pi % pit.size()]) if not pit.is_empty() else ""
		pi += 1
	Sv.setup = DB.card_id(pit[pi % pit.size()]) if not pit.is_empty() else ""
	pi += 1
	Sv.closer = DB.card_id(pit[pi % pit.size()]) if not pit.is_empty() else ""

func _color_names() -> Array:
	var t := Sim.team_from_save(D.MY_TEAM)
	var out: Array = []
	for e in (t["colors"] as Array):
		out.append(str((e as Dictionary)["name"]))
	return out

func _has_word(names: Array, w: String) -> bool:
	for n in names:
		if str(n).contains(w):
			return true
	return false


func _block_test() -> void:
	# 스킬블록 판 검산. **눈으로는 못 잡는 종류**라 검사로 못 박습니다 —
	# 블록이 겹치거나 잠긴 칸에 놓여도 화면에는 그럴듯한 판으로 보입니다.
	var fail := 0
	var put_tot := 0
	var refused := 0
	var seen := {}
	Sv.blocks = []
	Sv.block_at = {}
	Sv.block_uid = 1
	# 종류마다 모든 모양을 하나씩 만들어 둡니다 — 뽑기에 기대면 검사마다
	# 다른 것이 나와서 되풀이해도 같은 결과가 안 나옵니다.
	for s in Gr.SKILLS:
		for sh in Gr.SHAPES.keys():
			Sv.blocks.append({"uid": Sv.block_uid, "sid": str(s["id"]), "shape": str(sh), "rot": 0})
			Sv.block_uid += 1
	# **옛 세이브의 모양이 지금 것으로 옮겨지는가.** 모르는 모양이 남으면 그림은
	# ㅁ 로 그려지는데 값은 1.0 으로 떨어져서 **그림과 값이 따로 놉니다.**
	var old_keep := Sv.blocks
	Sv.blocks = []
	for s in ["O", "I", "T", "S", "Z", "J", "L", "없는모양"]:
		Sv.blocks.append({"uid": 9000 + Sv.blocks.size(), "sid": "eye", "shape": str(s), "rot": 0})
	Sv._migrate_shapes()
	for b in Sv.blocks:
		var sh := str((b as Dictionary)["shape"])
		if not Gr.SHAPES.has(sh):
			print("  실패 옛 모양이 안 옮겨짐: %s" % sh)
			fail += 1
		elif Gr.shape_cells(sh, 0).size() != Gr.SHAPE_CELLS:
			print("  실패 옮긴 모양이 네 칸이 아님: %s" % sh)
			fail += 1
	Sv.blocks = old_keep

	# **모든 모양이 네 칸인가.** 여기가 깨지면 판이 딱 떨어지지 않습니다.
	for sh in Gr.SHAPES.keys():
		for r in range(4):
			var n: int = Gr.shape_cells(str(sh), r).size()
			if n != Gr.SHAPE_CELLS:
				print("  실패 모양 %s(%d회전) 이 %d칸" % [sh, r, n])
				fail += 1
	for c in DB.cards:
		var id := DB.card_id(c)
		var key := str(c.get("kind", "")) + str(c.get("cost", 0))
		if seen.has(key):
			continue
		seen[key] = true
		Sv.games[id] = (abs(id.hash()) % 130)
		Sv.block_at.erase(id)
		var open: Array = Gr.open_cells(c)
		var want := 0
		for i in range(Gr.CELLS):
			if str(c.get("grade", "")) == D.GRADE_EX or int(Sv.games[id]) >= int(Gr.UNLOCK_AT[i]):
				want += 1
		if open.size() != want:
			print("  실패 열린 칸 수 %s: %d != %d" % [id, open.size(), want])
			fail += 1
		# 가진 블록을 차례로 아무 자리에나 넣어 봅니다.
		var kind := "pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"
		for b in Gr.free_blocks(kind):
			var uid := int(b["uid"])
			var done := false
			for o in range(Gr.CELLS):
				if Gr.put(c, uid, o) == "":
					done = true
					break
			if not done:
				refused += 1
				continue
			put_tot += 1
			# 놓인 칸이 겹치지 않고, 전부 열린 칸이어야 합니다.
			var bd := Gr.board(c)
			var cell: Dictionary = bd["cell"]
			var uids: Array = bd["uids"]
			if cell.size() != uids.size() * Gr.SHAPE_CELLS:
				print("  실패 칸 수 안 맞음 %s: %d != %d (겹침)" % [id, cell.size(), uids.size() * Gr.SHAPE_CELLS])
				fail += 1
			for k in cell:
				if not open.has(int(k)):
					print("  실패 잠긴 칸에 놓임 %s: %d" % [id, int(k)])
					fail += 1
			if not uids.has(uid):
				print("  실패 끼웠는데 판에 없음 %s / %d" % [id, uid])
				fail += 1
		# 뺐다가 다시 세면 보너스가 사라져야 합니다 — 저장과 판이 어긋나면
		# 화면과 경기가 따로 놉니다.
		Gr.clear_board(c)
		if not Gr.skill_bonus(id).is_empty():
			print("  실패 판을 비웠는데 보너스가 남음 %s" % id)
			fail += 1
		Sv.games.erase(id)
	# 한 블록은 한 카드에만 들어가야 합니다.
	var owner := {}
	for cid in Sv.block_at:
		for u in (Sv.block_at[cid] as Dictionary):
			if owner.has(str(u)):
				print("  실패 블록 %s 가 두 카드에" % str(u))
				fail += 1
			owner[str(u)] = cid
	print("스킬블록 검사 — 카드 %d종 · 끼움 %d개 · 자리없음 %d개 · 실패 %d개" % [
		seen.size(), put_tot, refused, fail])
	Sv.reset()
	get_tree().quit(1 if fail > 0 else 0)


func _sim_test(n: int) -> void:
	if DB.cards.is_empty():
		print("선수 자료가 없습니다.")
		return
	var r := RandomNumberGenerator.new()
	r.seed = 12345
	for ov in [55, 70, 85]:
		var a := Sim.build_ai("A", ov, r)
		var b := Sim.build_ai("B", ov, r)
		var runs := 0
		var hits := 0
		var hi := 0
		var shut := 0
		for i in range(n):
			var g := Sim.play(a, b, r)
			runs += int(g["score"][0]) + int(g["score"][1])
			hits += int(g["hits"][0]) + int(g["hits"][1])
			hi = maxi(hi, maxi(int(g["score"][0]), int(g["score"][1])))
			if mini(int(g["score"][0]), int(g["score"][1])) == 0:
				shut += 1
		print("종합 %d 끼리 %d경기 — 팀당 평균 %.2f점 %.1f안타 · 최다 %d점 · 완봉 %.0f%%" % [
			ov, n, runs / float(n * 2), hits / float(n * 2), hi, 100.0 * shut / float(n)])
	var strong := Sim.build_ai("강", 85, r)
	var weak := Sim.build_ai("약", 55, r)
	var w := 0
	for i in range(n):
		var g := Sim.play(strong, weak, r)
		if int(g["winner"]) == 0:
			w += 1
	print("종합85 팀이 종합55 팀 상대로 %.1f%% 승리" % [100.0 * w / float(n)])

func _demo_fill() -> void:
	# 화면을 확인할 때만 씁니다 — 카드를 쥐여 주고 오더를 자동으로 채웁니다.
	var hit: Array = []
	var pit: Array = []
	for c in DB.cards:
		if str(c.get("kind", "")) == "pitcher":
			pit.append(c)
		else:
			hit.append(c)
	var by_ov := func(a, b): return int(a.get("ov", 0)) > int(b.get("ov", 0))
	hit.sort_custom(by_ov)
	pit.sort_custom(by_ov)
	for c in hit.slice(0, 20):
		Sv.add_card(c)
	for c in pit.slice(0, 20):
		Sv.add_card(c)
	for i in range(mini(D.LINEUP, hit.size())):
		Sv.lineup[i] = DB.card_id(hit[i])
	for i in range(mini(D.ROT, pit.size())):
		Sv.rot[i] = DB.card_id(pit[i])

# ── 거르기 ─────────────────────────────────────────────────────────────────

func _refilter() -> void:
	dex.clear()
	for c in DB.cards:
		if f_year != 0 and int(c.get("year", 0)) != f_year:
			continue
		if f_grade != "" and str(c.get("grade", "")) != f_grade:
			continue
		if f_team != "" and str(c.get("team", "")) != f_team:
			continue
		if f_kind != "" and str(c.get("kind", "")) != f_kind:
			continue
		if f_cost != 0 and int(c.get("cost", 1)) != f_cost:
			continue
		if f_pos != "" and str(c.get("pos", "")) != f_pos:
			continue
		dex.append(c)
	dex.sort_custom(func(a, b):
		if int(a.get("ov", 0)) != int(b.get("ov", 0)):
			return int(a.get("ov", 0)) > int(b.get("ov", 0))
		return int(a.get("year", 0)) > int(b.get("year", 0)))
	dex_i = clampi(dex_i, 0, maxi(dex.size() - 1, 0))
	dex_scroll = 0.0

# ── 자리 ───────────────────────────────────────────────────────────────────

# ── 페이지 틀 ──────────────────────────────────────────────────────────────
# 위쪽 띠 하나에 **뒤로가기 · 화면 이름 · 재화**를 넣습니다. 원작 화면과 같은
# 구조이고, 탭 줄보다 얇아서 본문에 쓸 세로 폭이 늘어납니다.
const BAR_H := 40.0

func _back_rect() -> Rect2:
	return Rect2(PAD, PAD, 46.0, BAR_H)

func _menu_rect(i: int) -> Rect2:
	# 홈의 큰 단추. 세로로 늘어놓습니다.
	var w := minf(size.x - PAD * 2.0, 520.0)
	return Rect2((size.x - w) * 0.5, 120.0 + i * 74.0, w, 62.0)

func _body() -> Rect2:
	if screen == S.HOME:
		return Rect2(PAD, PAD, size.x - PAD * 2.0, size.y - PAD * 2.0)
	return Rect2(PAD, PAD + BAR_H + 16.0, size.x - PAD * 2.0,
		size.y - PAD * 2.0 - BAR_H - 16.0)

func _draw_bar() -> void:
	if screen == S.HOME:
		Art.txt(self, Vector2(PAD, PAD + 30.0), "프야매", 26, P.TEXT)
		Art.txt(self, Vector2(PAD + 92.0, PAD + 30.0),
			"KBO 2000~2026 실제 기록으로 만든 카드 %d장" % DB.cards.size(), 14, P.TEXT_FAINT)
	else:
		var br := _back_rect()
		draw_rect(br, P.PANEL_HI, true)
		draw_rect(br, P.hdr(P.BAR_MID, 1.2), false, 2.0)
		Art.txt(self, br.position + Vector2(br.size.x * 0.5 - Art.txt_w("◀", 17) * 0.5, 27.0),
			"◀", 17, P.TEXT)
		Art.txt(self, Vector2(br.position.x + br.size.x + 16.0, PAD + 29.0),
			screen_name(screen), 22, P.TEXT)
	var info := "%d코인 · %s" % [Sv.coins, D.tier_name(Sv.tier)]
	if screen != S.HOME:
		info += "   [Esc] 뒤로"
	Art.txt(self, Vector2(size.x - PAD - Art.txt_w(info, 14), PAD + 27.0), info, 14, P.TEXT_FAINT)

func _draw_home() -> void:
	for i in range(MENU.size()):
		var r := _menu_rect(i)
		draw_rect(r, P.PANEL_HI, true)
		draw_rect(r, P.LINE, false, 1.0)
		Art.txt(self, r.position + Vector2(20, 28), "%d" % (i + 1), 15, P.hdr(P.BAR_MID, 1.15))
		Art.txt(self, r.position + Vector2(48, 28), str(MENU_NAME[i]), 19, P.TEXT)
		Art.txt(self, r.position + Vector2(48, 50), str(MENU_NOTE[i]), 13, P.TEXT_FAINT)
	var s := "%d승 %d패 · 보유 %d장 · %s" % [Sv.wins, Sv.losses,
		DB.cards.size() if Sv.all_unlocked else Sv.owned.size(), D.tier_name(Sv.tier)]
	Art.txt(self, Vector2((size.x - Art.txt_w(s, 15)) * 0.5, 120.0 + MENU.size() * 74.0 + 26.0),
		s, 15, P.TEXT_DIM)

func _go(s: int) -> void:
	screen = s
	# **화면을 넘길 때 끌던 것과 펼친 것을 전부 닫습니다.** 안 그러면 오더에서
	# 집은 카드를 든 채로 다른 화면에 가서, 거기서 뗀 것이 엉뚱하게 흘러갑니다.
	drag_uid = -1
	drag_slot = ""
	combo_i = -1
	pos_open = -1
	if s == S.STUDY:
		_refresh_study()
	if s == S.ORDER:
		_refresh_pool()
func _btn_rect(i: int, n: int = 1) -> Rect2:
	# 화면 아래 가운데의 큰 단추. 화면마다 뜻이 다릅니다.
	# `n` 개를 **한 덩어리로 가운데** 놓습니다 — i 만 보고 오른쪽으로 밀면
	# 단추가 둘일 때 화면 가운데에서 벗어납니다.
	var b := _body()
	var w := 220.0
	var tot := n * w + (n - 1) * 14.0
	return Rect2(b.position.x + b.size.x * 0.5 - tot * 0.5 + (w + 14.0) * i,
		b.position.y + b.size.y - 52.0, w, 40.0)

# 도감 격자 — **작은 카드**를 촘촘히 깝니다. 자세한 것은 눌렀을 때 큰 화면에서.
const CHIP_H := 26.0

func _dex_area() -> Rect2:
	var b := _body()
	return Rect2(b.position.x, b.position.y + CHIP_H + 12.0, b.size.x, b.size.y - CHIP_H - 12.0)

func _dex_cols() -> int:
	return maxi(1, int(_dex_area().size.x / 104.0))

func _grid_rect(i: int) -> Rect2:
	var a := _dex_area()
	var cols := _dex_cols()
	var cw := a.size.x / float(cols)
	var w := cw - 8.0
	var sz := Art.small_size(w)
	@warning_ignore("integer_division")
	var rowi := i / cols
	return Rect2(a.position.x + (i % cols) * cw, a.position.y + rowi * (sz.y + 8.0) - dex_scroll, w, sz.y)

func _row_h() -> float:
	return Art.small_size(_dex_area().size.x / float(_dex_cols()) - 8.0).y + 8.0

# ── 거르개 ─────────────────────────────────────────────────────────────────
# **콤보박스입니다.** 누르면 목록이 펼쳐지고 하나를 고르면 닫힙니다.
# 예전에는 칩의 ◀ ▶ 로 값을 하나씩 넘겼는데, 구단 11개 · 시즌 27개 · 포지션
# 13개짜리 거르개에서는 원하는 값까지 스무 번을 눌러야 했습니다.
#
# **그리기와 클릭이 아래 자리 함수들을 같이 봅니다.**
const CHIP_W := 132.0
const CHIP_GAP := 138.0
const COMBO_ROW := 24.0
const COMBO_MAX := 14      # 한 번에 보여 주는 줄 수

func _chip_rect(i: int, x0: float, y0: float) -> Rect2:
	return Rect2(x0 + i * CHIP_GAP, y0, CHIP_W, CHIP_H)

func _combo_item_rect(i: int, x0: float, y0: float, j: int) -> Rect2:
	return Rect2(x0 + i * CHIP_GAP, y0 + CHIP_H + 2.0 + j * COMBO_ROW, CHIP_W, COMBO_ROW)

func _combo_panel(i: int, x0: float, y0: float, n: int) -> Rect2:
	return Rect2(x0 + i * CHIP_GAP, y0 + CHIP_H, CHIP_W, mini(n, COMBO_MAX) * COMBO_ROW + 4.0)

func _combo_shown(opts: Array) -> Array:
	# 펼친 목록이 화면을 넘지 않게 잘라 보여 줍니다.
	var lo := clampi(combo_scroll, 0, maxi(opts.size() - COMBO_MAX, 0))
	return opts.slice(lo, lo + COMBO_MAX)

func _draw_chips(list: Array, x0: float, y0: float) -> void:
	# 닫힌 칩만 먼저 그립니다. 펼쳐진 목록은 다른 칩을 덮어야 하므로
	# `_draw_combo_open` 이 **맨 나중에** 그립니다.
	for i in range(list.size()):
		var e: Array = list[i]
		var r := _chip_rect(i, x0, y0)
		var on := str(e[1]) != "전체"
		var open := combo_i == i
		draw_rect(r, P.PANEL_HI if (on or open) else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_MID, 1.15) if (on or open) else P.LINE, false, 1.0)
		var s := "%s %s" % [str(e[0]), str(e[1])]
		Art.txt(self, r.position + Vector2(8, 18), s, 13, P.TEXT if on else P.TEXT_DIM)
		Art.txt(self, r.position + Vector2(r.size.x - 15, 18), "▾", 11, P.TEXT_FAINT)

func _draw_combo_open(list: Array, x0: float, y0: float) -> void:
	if combo_i < 0 or combo_i >= list.size():
		return
	var opts: Array = (list[combo_i] as Array)[2]
	var shown := _combo_shown(opts)
	var pan := _combo_panel(combo_i, x0, y0, opts.size())
	Art.panel(self, pan, P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	var cur = (list[combo_i] as Array)[3]
	for j in range(shown.size()):
		var o: Array = shown[j]
		var r := _combo_item_rect(combo_i, x0, y0, j)
		var sel: bool = o[1] == cur
		if sel:
			draw_rect(r, P.PANEL_HI, true)
		Art.txt(self, r.position + Vector2(8, 17), str(o[0]), 13,
			P.hdr(P.BAR_HIGH, 1.1) if sel else P.TEXT_DIM)
	if opts.size() > COMBO_MAX:
		Art.txt(self, Vector2(pan.position.x + 6.0, pan.position.y + pan.size.y + 13.0),
			"휠로 넘기기 (%d개)" % opts.size(), 11, P.TEXT_FAINT)

func _click_chips(list: Array, x0: float, y0: float, p: Vector2, pick: Callable) -> bool:
	# 펼쳐진 목록이 있으면 **그것부터** 봅니다 — 목록이 아래 칩을 덮고 있으므로
	# 칩을 먼저 보면 목록에서 고른 것이 칩 클릭으로 새어 나갑니다.
	if combo_i >= 0 and combo_i < list.size():
		var opts: Array = (list[combo_i] as Array)[2]
		var shown := _combo_shown(opts)
		for j in range(shown.size()):
			if _combo_item_rect(combo_i, x0, y0, j).has_point(p):
				pick.call(combo_i, (shown[j] as Array)[1])
				combo_i = -1
				return true
		if _combo_panel(combo_i, x0, y0, opts.size()).has_point(p):
			return true    # 목록 안의 빈 곳 — 닫지 않고 삼킵니다
	for i in range(list.size()):
		if _chip_rect(i, x0, y0).has_point(p):
			combo_i = -1 if combo_i == i else i
			combo_scroll = 0
			return true
	if combo_i >= 0:
		combo_i = -1
		return true
	return false

# 오더 칸 — 그리기와 클릭이 이 함수 하나를 같이 봅니다.
const ORDER_GROUPS := ["lineup", "bench", "rot", "relief", "setup", "closer"]

# 작전 화면은 **위 배치선수 · 아래 보유선수** 두 판입니다(원작 구조).
# 고르기 창을 띄우던 방식은 칸 하나 채울 때마다 창이 열렸다 닫혀서, 아홉 자리를
# 채우는 데 창을 아홉 번 여닫아야 했습니다. 목록을 늘 띄워 두면 **누르는 것만으로**
# 채워집니다.
const SLOT_ROW_H := 182.0     # 배치선수 판 높이 (칸 + 수비 위치 줄)
const POOL_COLS := 8          # 보유선수 격자 열 수

func _order_rows() -> Dictionary:
	# 배치선수는 **한 줄**입니다 — 타순 9 / 벤치 5 를 같은 줄에 이어 놓고,
	# 투수도 선발 5 · 중계 4 · 셋업 · 마무리를 한 줄에 놓습니다.
	var b := _body()
	var y := b.position.y + 76.0
	var out := {}
	for g in ORDER_GROUPS:
		out[g] = y
	return out

func _slot_cols() -> int:
	# 한 줄에 놓이는 칸 수. 타자 14(타순 9 + 벤치 5), 투수 11(5+4+1+1).
	return D.LINEUP + D.BENCH if order_tab == 0 else D.ROT + D.RELIEF + 2

func _slot_col(g: String, i: int) -> int:
	match g:
		"lineup": return i
		"bench": return D.LINEUP + i
		"rot": return i
		"relief": return D.ROT + i
		"setup": return D.ROT + D.RELIEF
		"closer": return D.ROT + D.RELIEF + 1
	return i

func _slot_rect(g: String, i: int) -> Rect2:
	var b := _body()
	var n := _slot_cols()
	var cw := (b.size.x - 8.0) / float(n)
	return Rect2(b.position.x + _slot_col(g, i) * cw + 3.0, float(_order_rows()[g]),
		cw - 6.0, SLOT_ROW_H - 26.0)

func _group_count(g: String) -> int:
	match g:
		"lineup": return D.LINEUP
		"bench": return D.BENCH
		"rot": return D.ROT
		"relief": return D.RELIEF
	return 1

# ── 아래 판 ────────────────────────────────────────────────────────────────

func _lower_rect() -> Rect2:
	var b := _body()
	var y := b.position.y + 76.0 + SLOT_ROW_H + 14.0
	return Rect2(b.position.x, y, b.size.x, b.position.y + b.size.y - y - 30.0)

func _pool_rect() -> Rect2:
	var r := _lower_rect()
	return Rect2(r.position.x, r.position.y, r.size.x * 0.615, r.size.y)

func _anal_rect() -> Rect2:
	var r := _lower_rect()
	var p := _pool_rect()
	return Rect2(p.position.x + p.size.x + 12.0, r.position.y,
		r.size.x - p.size.x - 12.0, r.size.y)

func _pool_area() -> Rect2:
	# 거르개 줄 아래의 카드 격자.
	var r := _pool_rect()
	return Rect2(r.position.x + 6.0, r.position.y + 62.0, r.size.x - 26.0, r.size.y - 92.0)

func _pool_cell(i: int) -> Rect2:
	var a := _pool_area()
	var cw := a.size.x / float(POOL_COLS)
	var ch := cw * Art.MINI_RATIO + 4.0
	@warning_ignore("integer_division")
	var row := i / POOL_COLS
	return Rect2(a.position.x + (i % POOL_COLS) * cw + 2.0,
		a.position.y + row * ch - pool_scroll, cw - 4.0, ch - 6.0)

func _refresh_pool() -> void:
	# 지금 탭에 맞는 보유 카드 중 **아직 오더에 안 들어간 것**만 보여 줍니다.
	# 이미 든 카드를 또 보여 주면 눌렀을 때 아무 일도 안 일어나서, 목록이
	# 믿을 수 없는 것이 됩니다.
	var want := "hitter" if order_tab == 0 else "pitcher"
	# 이미 오더에 든 **이름**을 모읍니다(투수·야수 가리지 않고 25칸 전부).
	var taken := {}
	for g in ORDER_GROUPS:
		for i in range(_group_count(str(g))):
			var oc := DB.find(_slot_id(str(g), i))
			if not oc.is_empty():
				taken[str(oc.get("name", ""))] = true
	pool = []
	for c in Sv.owned_cards():
		if str(c.get("kind", "")) != want:
			continue
		var id := DB.card_id(c)
		if Sv.away(id):
			continue          # 유학 중인 카드는 세울 수 없습니다
		if Sv.in_order(id):
			continue
		# **같은 선수는 한 명만 세웁니다.** `03' 이승엽` 을 넣었으면 `02' 이승엽`
		# 도 목록에서 빠집니다 — 한 사람이 타순에 두 번 설 수는 없습니다.
		# 목록에서 아예 빼는 이유는, 남겨 두면 눌렀을 때 거절당하고 나서야
		# 왜 안 되는지 알게 되기 때문입니다.
		if taken.has(str(c.get("name", ""))):
			continue
		if p_team != "" and str(c.get("team", "")) != p_team:
			continue
		if p_year != 0 and int(c.get("year", 0)) != p_year:
			continue
		if p_pos != "" and str(c.get("pos", "")) != p_pos:
			continue
		if p_cost != 0 and int(c.get("cost", 1)) != p_cost:
			continue
		pool.append(c)
	pool.sort_custom(func(a, b): return int(a.get("ov", 0)) > int(b.get("ov", 0)))
	pool_scroll = 0.0

func _pool_max_scroll() -> float:
	var a := _pool_area()
	var cw := a.size.x / float(POOL_COLS)
	var ch := cw * Art.MINI_RATIO + 4.0
	var rows := ceili(float(pool.size()) / float(POOL_COLS))
	return maxf(0.0, rows * ch - a.size.y)

func _slot_id(g: String, i: int) -> String:
	match g:
		"lineup": return str(Sv.lineup[i])
		"bench": return str(Sv.bench[i])
		"rot": return str(Sv.rot[i])
		"relief": return str(Sv.relief[i])
		"setup": return Sv.setup
		"closer": return Sv.closer
	return ""

func _set_slot(g: String, i: int, id: String) -> void:
	match g:
		"lineup": Sv.lineup[i] = id
		"bench": Sv.bench[i] = id
		"rot": Sv.rot[i] = id
		"relief": Sv.relief[i] = id
		"setup": Sv.setup = id
		"closer": Sv.closer = id
	Sv.save_game()

# ── 구단관리 ───────────────────────────────────────────────────────────────
# 원작처럼 **왼쪽에 보유 카드 격자, 오른쪽에 그 카드 설명**입니다.
# 예전에는 왼쪽이 한 줄짜리 목록이었는데, 카드가 수백 장이 되면 이름만 늘어놓은
# 표가 되어 **어느 카드가 센지 눈으로 못 고릅니다.**
const STUDY_COLS := 5

func _study_panel() -> Rect2:
	var b := _body()
	return Rect2(b.position.x, b.position.y + 44.0, b.size.x * 0.40, b.size.y - 54.0)

func _study_area() -> Rect2:
	# 거르개 줄 아래의 카드 격자.
	var p := _study_panel()
	return Rect2(p.position.x + 6.0, p.position.y + 62.0, p.size.x - 24.0, p.size.y - 72.0)

func _study_cell(i: int) -> Rect2:
	var a := _study_area()
	var cw := a.size.x / float(STUDY_COLS)
	var ch := cw * Art.MINI_RATIO + 4.0
	@warning_ignore("integer_division")
	var row := i / STUDY_COLS
	return Rect2(a.position.x + (i % STUDY_COLS) * cw + 2.0,
		a.position.y + row * ch - study_scroll, cw - 4.0, ch - 6.0)

func _study_max_scroll() -> float:
	var a := _study_area()
	var cw := a.size.x / float(STUDY_COLS)
	var ch := cw * Art.MINI_RATIO + 4.0
	var rows := ceili(float(study_list.size()) / float(STUDY_COLS))
	return maxf(0.0, rows * ch - a.size.y)

# 오른쪽 판 — 카드 설명과 갈래별 내용.
func _study_side() -> Rect2:
	var b := _body()
	var p := _study_panel()
	return Rect2(p.position.x + p.size.x + 12.0, p.position.y,
		b.position.x + b.size.x - p.position.x - p.size.x - 12.0, p.size.y)

func _region_rect(i: int) -> Rect2:
	var s := _study_side()
	return Rect2(s.position.x + 10.0, s.position.y + 150.0 + i * 62.0, s.size.x - 20.0, 56.0)

# 구단관리의 거르개 — 원작의 `코스트 ▼` 자리입니다. 보유 카드가 수백 장이 되면
# 격자를 끝까지 굴려서 찾는 것이 일이 됩니다.
func _study_chip_rect(i: int) -> Rect2:
	var p := _study_panel()
	var w := (p.size.x - 22.0) / 3.0
	return Rect2(p.position.x + 6.0 + i * (w + 5.0), p.position.y + 30.0, w, CHIP_H)

func _study_combo_item_rect(i: int, j: int) -> Rect2:
	var c := _study_chip_rect(i)
	return Rect2(c.position.x, c.position.y + c.size.y + 2.0 + j * COMBO_ROW,
		maxf(c.size.x, 96.0), COMBO_ROW)

func _study_combo_panel(i: int, n: int) -> Rect2:
	var c := _study_chip_rect(i)
	return Rect2(c.position.x, c.position.y + c.size.y, maxf(c.size.x, 96.0),
		mini(n, COMBO_MAX) * COMBO_ROW + 4.0)

func _study_chips() -> Array:
	# [이름, 지금 값(표시), 고를 수 있는 것들, 지금 값(실제)]
	return [
		["코스트", "전체" if g_cost == 0 else str(g_cost), _opts_cost(), g_cost],
		["구단", "전체" if g_team == "" else g_team, _opts_team(), g_team],
		["종류", "전체" if g_kind == "" else ("투수" if g_kind == "pitcher" else "타자"),
			[["전체", ""], ["타자", "hitter"], ["투수", "pitcher"]], g_kind],
	]

func _set_study_filter(i: int, v) -> void:
	match i:
		0: g_cost = int(v)
		1: g_team = str(v)
		2: g_kind = str(v)
	_refresh_study()
func _refresh_study() -> void:
	study_list = []
	for c in Sv.owned_cards():
		if g_cost != 0 and int(c.get("cost", 1)) != g_cost:
			continue
		if g_team != "" and str(c.get("team", "")) != g_team:
			continue
		if g_kind != "" and str(c.get("kind", "")) != g_kind:
			continue
		study_list.append(c)
	study_list.sort_custom(func(a, b): return int(a.get("ov", 0)) > int(b.get("ov", 0)))
	study_i = clampi(study_i, 0, maxi(study_list.size() - 1, 0))
	study_scroll = 0.0

func _study_sel() -> String:
	if study_i < 0 or study_i >= study_list.size():
		return ""
	return DB.card_id(study_list[study_i])

# 고르기 창의 거르개 — **세로로 쌓인 콤보박스**입니다. 창이 290px 로 좁아서
# 도감처럼 가로로 늘어놓을 수 없습니다. 펼치는 것과 고르는 것은 도감과 같습니다.

func _pick_chips() -> Array:
	# [이름, 지금 값(표시), 고를 수 있는 것들, 지금 값(실제)]
	return [
		["구단", "전체" if p_team == "" else p_team, _opts_team(), p_team],
		["시즌", "전체" if p_year == 0 else str(p_year), _opts_year(), p_year],
		["포지션", "전체" if p_pos == "" else str(D.POS_SHORT.get(p_pos, p_pos)), _opts_pos(), p_pos],
		["코스트", "전체" if p_cost == 0 else str(p_cost), _opts_cost(), p_cost],
	]

func _set_pick_filter(i: int, v) -> void:
	match i:
		0: p_team = str(v)
		1: p_year = int(v)
		2: p_pos = str(v)
		3: p_cost = int(v)
	_refresh_pool()

# ── 그리기 ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), P.BG, true)
	_draw_bar()
	if DB.cards.is_empty():
		Art.txt(self, Vector2(PAD, size.y * 0.5), DB.load_note, 20, P.TEXT_DIM)
		return
	match screen:
		S.HOME: _draw_home()
		S.DEX: _draw_dex()
		S.SCOUT: _draw_scout()
		S.STUDY: _draw_study()
		S.ORDER: _draw_order()
		S.GAME: _draw_game()
	if not detail.is_empty():
		_draw_modal()
	if toast_t > 0.0:
		var s := 17
		var w := Art.txt_w(toast, s) + 28.0
		# 알림은 **위쪽 띠 바로 아래**에 띄웁니다. 아래에 두면 카드가 화면을 가득
		# 채우는 화면(스카우트 10장)에서 결과 위에 얹힙니다.
		var r := Rect2(size.x * 0.5 - w * 0.5, PAD + BAR_H + 8.0, w, 32.0)
		draw_rect(r, P.PANEL_HI, true)
		draw_rect(r, P.hdr(P.BAR_MID, 1.2), false, 1.0)
		Art.txt(self, r.position + Vector2(14, 22), toast, s, P.TEXT)

# 도감 ─────────────────────────────────────────────────────────────────────

func _all_pos() -> Array:
	# 카드에 실제로 있는 포지션만. 없는 것을 목록에 두면 골라도 빈 화면이 됩니다.
	if not _pos_cache.is_empty():
		return _pos_cache
	var s := {}
	for c in DB.cards:
		s[str(c.get("pos", ""))] = true
	_pos_cache = s.keys()
	# 타자는 `D.POS` 차례로, 투수는 `D.PIT_SLOTS` 차례로 — 이름순으로 두면
	# 선발과 마무리 사이에 3루수가 끼어서 목록이 읽히지 않습니다.
	var order: Array = []
	order.append_array(D.POS)
	order.append_array(D.PIT_SLOTS)
	_pos_cache.sort_custom(func(a, b):
		var ia := order.find(a)
		var ib := order.find(b)
		return (ia if ia >= 0 else 99) < (ib if ib >= 0 else 99))
	return _pos_cache

func _opts_year() -> Array:
	var out: Array = [["전체", 0]]
	for y in range(D.LAST_YEAR, D.FIRST_YEAR - 1, -1):
		out.append([str(y), y])
	return out

func _opts_team() -> Array:
	var out: Array = [["전체", ""]]
	for t in _all_teams():
		out.append([str(t), str(t)])
	return out

func _opts_pos() -> Array:
	var out: Array = [["전체", ""]]
	for p in _all_pos():
		out.append([str(D.POS_SHORT.get(p, p)), str(p)])
	return out

func _opts_cost() -> Array:
	var out: Array = [["전체", 0]]
	for i in range(10, 0, -1):
		out.append(["COST %d" % i, i])
	return out

func _dex_chips() -> Array:
	# [이름, 지금 값(표시), 고를 수 있는 것들, 지금 값(실제)]
	return [
		["시즌", "전체" if f_year == 0 else str(f_year), _opts_year(), f_year],
		["구단", "전체" if f_team == "" else f_team, _opts_team(), f_team],
		["포지션", "전체" if f_pos == "" else str(D.POS_SHORT.get(f_pos, f_pos)), _opts_pos(), f_pos],
		["코스트", "전체" if f_cost == 0 else str(f_cost), _opts_cost(), f_cost],
		["등급", "전체" if f_grade == "" else f_grade,
			[["전체", ""], ["EX", D.GRADE_EX], ["일반", D.GRADE_NORMAL]], f_grade],
		["종류", "전체" if f_kind == "" else ("투수" if f_kind == "pitcher" else "타자"),
			[["전체", ""], ["타자", "hitter"], ["투수", "pitcher"]], f_kind],
	]

func _set_dex_filter(i: int, v) -> void:
	match i:
		0: f_year = int(v)
		1: f_team = str(v)
		2: f_pos = str(v)
		3: f_cost = int(v)
		4: f_grade = str(v)
		5: f_kind = str(v)
	_refilter()

func _draw_dex() -> void:
	var b := _body()
	var chips := _dex_chips()
	_draw_chips(chips, b.position.x, b.position.y)
	var own := 0
	for c in dex:
		if Sv.has(DB.card_id(c)):
			own += 1
	Art.txt(self, Vector2(b.position.x + chips.size() * CHIP_GAP + 10.0, b.position.y + 18.0),
		"%d장 중 %d장 보유   ·   누르거나 우클릭하면 크게 봅니다" % [dex.size(), own],
		13, P.TEXT_FAINT)

	var a := _dex_area()
	var rh := _row_h()
	var cols := _dex_cols()
	var first := maxi(0, int(dex_scroll / rh) * cols - cols)
	var last := mini(dex.size(), first + cols * (int(a.size.y / rh) + 3))
	for i in range(first, last):
		var r := _grid_rect(i)
		if r.position.y > a.position.y + a.size.y or r.position.y + r.size.y < a.position.y:
			continue
		# **안 가진 카드는 회색으로** 그립니다. 도감이 1만 장이라 "무엇을 모았나"가
		# 한눈에 안 보이면 도감이 그냥 카드 사전이 됩니다.
		Art.small_card(self, r.position, r.size.x, dex[i], i == dex_i, -1.0,
			not Sv.has(DB.card_id(dex[i])))
	if dex.is_empty():
		Art.txt(self, a.position + Vector2(4, 30), "해당하는 카드가 없습니다.", 15, P.TEXT_DIM)
	# 펼친 목록은 **맨 나중에** 그려야 카드 위에 옵니다.
	_draw_combo_open(chips, b.position.x, b.position.y)

# ── 큰 화면 ────────────────────────────────────────────────────────────────
# 카드를 누르면 뜹니다. **작은 카드에는 스텟을 안 그리므로 이 화면이 유일하게
# 자세히 볼 수 있는 곳입니다** — 6스텟 · 그 시즌 기록 · 스킬 · 구종 · 유학까지
# 한자리에 놓습니다.

# ── 큰 화면 ────────────────────────────────────────────────────────────────
# 원작 카드 상세와 같은 배치입니다 — **한 화면에 다 보여 줍니다.**
# 예전에는 사진을 눌러 앞뒤로 뒤집었는데, 구종과 스킬블록을 보려고 매번 뒤집어야
# 해서 "지금 뭘 보고 있는지"를 놓치기 쉬웠습니다. 뒤집기는 걷어냈습니다.
#
#   ┌ 카드 ─┐ ┌ 프로필 ─┬ 구종 방사도 / 수비 위치 ─┐
#   │ 사진  │ │ 나이·투타 │                          │
#   │ 스텟  │ ├──────────┴──────────────────────────┤
#   │ +보너스│ │ 시즌 기록 표                        │
#   │ COST  │ ├─ 4×4 판 ─┬ 스킬블록 · 추가 능력치 ──┤
#   └───────┘ └──────────┴─────────────────────────┘
func _modal_rect() -> Rect2:
	var w := minf(size.x - 80.0, 1060.0)
	# 높이는 **내용에 맞춰** 잡습니다 — 700 으로 두면 아래가 통째로 빕니다.
	var h := minf(size.y - 60.0, 566.0)
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)

func _modal_card_w() -> float:
	return minf((_modal_rect().size.y - 40.0) / Art.CARD_RATIO, 340.0)

func _modal_side() -> Rect2:
	# 카드 오른쪽 전체. 아래 세 칸이 전부 여기를 기준으로 잡습니다.
	var r := _modal_rect()
	var cw := _modal_card_w()
	return Rect2(r.position.x + cw + 40.0, r.position.y + 16.0,
		r.size.x - cw - 60.0, r.size.y - 32.0)

func _draw_modal() -> void:
	var c := detail
	if c.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), P.a(Color.BLACK, 0.72), true)
	var r := _modal_rect()
	Art.panel(self, r, P.PANEL, P.hdr(P.grade(str(c.get("grade", "NORMAL"))), 1.2), 2.0)
	var id := DB.card_id(c)
	var pit := str(c.get("kind", "")) == "pitcher"

	# ── 왼쪽 : 카드 ──
	var cw := _modal_card_w()
	# **보너스를 카드에 적습니다.** 유학·스킬블록·구종은 `DB.find` 가 이미 스텟에
	# 얹어 두었고, 팀컬러는 팀 전체에 붙는 것이라 여기서 더해 보여 줍니다.
	Art.card(self, r.position + Vector2(20, 20), cw, c, false, Sim.color_bonus(c), true)

	var s := _modal_side()
	# ── 오른쪽 위 : 이름 · 프로필 · 구종/수비 ──
	Art.txt(self, Vector2(s.position.x, s.position.y + 20.0),
		"%s %s %s" % [str(c.get("team", "")), DB.year_tag(c), str(c.get("name", ""))], 21, P.TEXT)
	var own := Sv.count(id)
	Art.txt(self, Vector2(s.position.x, s.position.y + 40.0),
		"종합 %d · COST %d · %s%s" % [int(c.get("ov", 0)), int(c.get("cost", 1)),
			str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", "")))),
			("   ·   보유 %d장" % own) if own > 0 else "   ·   미보유"], 13, P.TEXT_DIM)

	var top := Rect2(s.position.x, s.position.y + 52.0, s.size.x, 176.0)
	var pw := 152.0
	# 프로필 — 원작의 `27세 B형 / 경남고 / 우투우타 / No.11번 / 선발` 자리입니다.
	var y := top.position.y + 20.0
	for e in _profile_lines(c):
		Art.txt(self, Vector2(top.position.x, y), str(e), 13, P.TEXT_DIM)
		y += 19.0
	var chart := Rect2(top.position.x + pw, top.position.y, top.size.x - pw, top.size.y)
	Art.panel(self, chart, P.a(P.PANEL_HI, 0.45), P.LINE, 1.0)
	if pit:
		Art.pitch_chart(self, chart, c)
		Art.txt(self, Vector2(chart.position.x + 8.0, chart.position.y + chart.size.y - 8.0),
			"최고구속 %d km" % (118 + int(round(float((c.get("st", {}) as Dictionary).get("velo", 50)) * 0.34))),
			13, P.hdr(P.BAR_MID, 1.15))
	else:
		Art.field_chart(self, chart, c)
	Art.txt(self, Vector2(chart.position.x + 8.0, chart.position.y + 16.0),
		"구종" if pit else "수비 위치", 13, P.a(P.TEXT, 0.9))

	# ── 오른쪽 가운데 : 시즌 기록 표 ──
	# 원작처럼 **가로 표**입니다 — 세로로 늘어놓으면 자리를 많이 먹고, 기록은
	# 항목 이름보다 숫자를 나란히 보는 것이 읽기 쉽습니다.
	var tb := Rect2(s.position.x, top.position.y + top.size.y + 10.0, s.size.x, 46.0)
	draw_rect(tb, P.a(P.PANEL_HI, 0.45), true)
	draw_rect(tb, P.LINE, false, 1.0)
	var cols := _record_cols(c)
	var colw := tb.size.x / float(maxi(cols.size(), 1))
	for i in range(cols.size()):
		var e: Array = cols[i]
		var cx := tb.position.x + i * colw
		Art.txt(self, Vector2(cx + colw * 0.5 - Art.txt_w(str(e[0]), 12) * 0.5,
			tb.position.y + 17.0), str(e[0]), 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(cx + colw * 0.5 - Art.txt_w(str(e[1]), 14) * 0.5,
			tb.position.y + 37.0), str(e[1]), 14, P.TEXT)

	# ── 오른쪽 아래 : 4×4 판 + 스킬 · 추가 능력치 ──
	var low := Rect2(s.position.x, tb.position.y + tb.size.y + 12.0, s.size.x,
		s.position.y + s.size.y - (tb.position.y + tb.size.y) - 12.0)
	var bs := minf(low.size.y - 22.0, 150.0)
	var frame := Rect2(low.position.x, low.position.y, bs, bs)
	Art.panel(self, frame, P.a(P.PANEL_HI, 0.45), P.LINE, 1.0)
	Art.blocks(self, frame.grow(-8.0), c)
	var open: Array = Gr.open_cells(c)
	var nxt := Gr.next_cell_at(c)
	var note := "%d / %d 칸" % [open.size(), Gr.CELLS]
	if nxt > 0:
		note += " · 다음 %d경기" % nxt
	elif str(c.get("grade", "")) == D.GRADE_EX:
		note += " · EX"
	Art.txt(self, Vector2(frame.position.x, frame.position.y + frame.size.y + 15.0),
		note, 12, P.TEXT_FAINT)

	var lx := low.position.x + bs + 16.0
	var ly := low.position.y + 14.0
	var bd := Gr.board(c)
	var uids: Array = bd["uids"]
	if uids.is_empty():
		Art.txt(self, Vector2(lx, ly), "낀 스킬블록이 없습니다 — [구단관리] 에서 끼웁니다.",
			13, P.TEXT_FAINT)
		ly += 20.0
	for i in range(uids.size()):
		var bb := Gr.block(int(uids[i]))
		Art.block_icon(self, Vector2(lx, ly - 9.0), 6.0, bb,
			Art.BLOCK_COLS[i % Art.BLOCK_COLS.size()])
		var ups := ""
		for k in Gr.block_value(bb):
			ups += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(Gr.block_value(bb)[k])]
		Art.txt(self, Vector2(lx + 36.0, ly + 4.0), Gr.block_name(bb), 13, P.TEXT)
		Art.txt(self, Vector2(lx + 172.0, ly + 4.0), ups, 12, P.hdr(P.BAR_HIGH, 1.1))
		ly += 20.0
	ly += 14.0
	_draw_up_src(c, id, lx, ly, low.size.x - bs - 16.0)

	_draw_trade_btn(c, id)
	# 안내는 **카드 오른쪽 아래**에. 왼쪽에 두면 카드 위에 얹힙니다.
	var tip := "아무 데나 누르거나 [Esc] 로 닫습니다"
	Art.txt(self, Vector2(s.position.x, r.position.y + r.size.y - 14.0), tip, 12, P.TEXT_FAINT)

func _profile_lines(c: Dictionary) -> Array:
	# 원작의 프로필 줄. 나이·혈액형·출신교는 자료에 없으므로 **있는 것만** 적습니다 —
	# 없는 값을 그럴듯하게 지어내면 실제 기록으로 만든 카드라는 전제가 깨집니다.
	# 시합수처럼 **아래 기록 표에 있는 것도 안 적습니다**(같은 값이 두 번 보입니다).
	var out: Array = ["%d 시즌" % int(c.get("year", 0)), str(c.get("team", ""))]
	out.append(str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", "")))))
	out.append("카드 등급 %s" % ("EX" if D.show_grade(str(c.get("grade", ""))) else "일반"))
	out.append("출전 %d경기" % Gr.games(DB.card_id(c)))
	var done := Sv.study_regions(DB.card_id(c))
	if not done.is_empty():
		var nm: Array = []
		for i in done:
			nm.append(str(D.ABROAD[int(i)]["name"]))
		out.append("유학 " + ", ".join(nm))
	if Sv.away(DB.card_id(c)):
		out.append("%s 유학 중 (%d경기)" % [str(D.ABROAD[Sv.away_region(DB.card_id(c))]["name"]),
			Sv.away_left(DB.card_id(c))])
	return out

func _record_cols(c: Dictionary) -> Array:
	# 원작의 `년도 시합수 평균자책 승 패 세이브 투구이닝 자책점` 줄.
	var ln: Dictionary = c.get("line", {})
	if str(c.get("kind", "")) == "pitcher":
		return [["년도", "%d" % int(c.get("year", 0))],
			["시합수", "%d" % int(ln.get("g", 0))],
			["평균자책", "%.2f" % float(ln.get("era", 0.0))],
			["승", "%d" % int(ln.get("w", 0))],
			["패", "%d" % int(ln.get("l", 0))],
			["세이브", "%d" % int(ln.get("sv", 0))],
			["홀드", "%d" % int(ln.get("hld", 0))],
			["투구이닝", "%.1f" % float(ln.get("ip", 0.0))]]
	return [["년도", "%d" % int(c.get("year", 0))],
		["시합수", "%d" % int(ln.get("g", 0))],
		["타석", "%d" % int(ln.get("pa", 0))],
		["타율", "%.3f" % float(ln.get("avg", 0.0))],
		["홈런", "%d" % int(ln.get("hr", 0))],
		["OPS", "%.3f" % float(ln.get("ops", 0.0))]]

func _trade_rect() -> Rect2:
	# 큰 화면 아래의 트레이드 단추. **그리기와 클릭이 같이 봅니다.**
	var r := _modal_rect()
	return Rect2(r.position.x + r.size.x - 210.0, r.position.y + r.size.y - 40.0, 190.0, 30.0)

func _draw_trade_btn(c: Dictionary, id: String) -> void:
	var own := Sv.count(id)
	if own <= 0:
		return
	var r := _trade_rect()
	var why := Sv.can_trade(id)
	var can := why == ""
	draw_rect(r, P.PANEL_HI if can else P.PANEL, true)
	draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0)
	var t := "트레이드  +%d코인" % Sv.trade_value(c)
	Art.txt(self, r.position + Vector2(r.size.x * 0.5 - Art.txt_w(t, 13) * 0.5, 20), t, 13,
		P.TEXT if can else P.TEXT_FAINT)
	if not can:
		Art.txt(self, Vector2(r.position.x + r.size.x - Art.txt_w(why, 12), r.position.y - 6.0),
			why, 12, P.WARN)

func _do_trade() -> void:
	var c := detail
	if c.is_empty():
		return
	var id := DB.card_id(c)
	var v := Sv.trade(c)
	if v <= 0:
		_say(Sv.can_trade(id))
		return
	_say("%s 을(를) 넘기고 %d코인을 받았습니다." % [str(c.get("name", "")), v])
	# 마지막 한 장을 넘겼으면 큰 화면을 닫습니다 — 안 가진 카드의 트레이드
	# 단추가 그대로 떠 있으면 또 누르게 됩니다.
	if not Sv.has(id):
		detail = {}
	_refilter()
	_refresh_study()
	_refresh_pool()

# 큰 화면의 **추가 능력치 내역** — 어디서 온 보너스인지 갈래별로 적습니다.
# 카드에는 합계(`+N`)만 나오므로, 무엇을 더 하면 더 오르는지는 여기서 읽습니다.
func _draw_up_src(c: Dictionary, id: String, x: float, y: float, maxw: float) -> float:
	var src: Dictionary = c.get("up_src", {})
	var cb := Sim.color_bonus(c)
	var rows: Array = []
	for e in [["유학", src.get("study", {})], ["스킬블록", src.get("block", {})],
			["구종", src.get("pitch", {})]]:
		var d: Dictionary = e[1]
		if d.is_empty():
			continue
		var s := ""
		for k in d:
			s += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(d[k])]
		rows.append([str(e[0]), s])
	if cb > 0:
		var nm := "팀컬러"
		var t := Sim.team_from_save(D.MY_TEAM)
		var pick: Dictionary = t.get("color", {})
		if not pick.is_empty():
			nm = "팀컬러 · %s" % str(pick["name"])
		rows.append([nm, "모든 스텟 +%d" % cb])
	Art.txt(self, Vector2(x, y), "추가 능력치", 14, P.hdr(P.BAR_MID, 1.15))
	y += 19.0
	if rows.is_empty():
		Art.txt(self, Vector2(x, y), "아직 없습니다 — 유학 · 스킬블록 · 팀컬러로 오릅니다.",
			12, P.TEXT_FAINT)
		return y + 18.0
	# **줄바꿈이 필요합니다.** 유학을 여러 곳 다녀오면 한 줄이 옆 칸까지 넘어갑니다.
	var tw := maxf(maxw - 110.0, 120.0)
	for e in rows:
		Art.txt(self, Vector2(x, y), str(e[0]), 12, P.TEXT_DIM)
		var line := ""
		for part in str(e[1]).split("  ", false):
			var t2 := line + str(part) + "  "
			if Art.txt_w(t2, 12) > tw and line != "":
				Art.txt(self, Vector2(x + 108.0, y), line, 12, P.hdr(P.BAR_HIGH, 1.1))
				y += 16.0
				line = str(part) + "  "
			else:
				line = t2
		if line != "":
			Art.txt(self, Vector2(x + 108.0, y), line, 12, P.hdr(P.BAR_HIGH, 1.1))
		y += 18.0
	# **카드의 `+N` 은 실제로 오른 만큼**입니다 — 99 에서 잘리면 여기 적힌 합보다
	# 작습니다. 안 적어 두면 숫자가 안 맞는 것처럼 보입니다.
	Art.txt(self, Vector2(x, y), "스텟 상한 %d 까지 붙습니다." % D.STAT_MAX, 11, P.TEXT_FAINT)
	return y + 20.0

func _stat_lines(c: Dictionary) -> Array:
	var ln: Dictionary = c.get("line", {})
	if str(c.get("kind", "")) == "pitcher":
		return [["평균자책", "%.2f" % float(ln.get("era", 0.0))],
			["승 · 패", "%d승 %d패" % [int(ln.get("w", 0)), int(ln.get("l", 0))]],
			["세이브 · 홀드", "%dS %dH" % [int(ln.get("sv", 0)), int(ln.get("hld", 0))]],
			["이닝", "%.1f" % float(ln.get("ip", 0.0))],
			["등판", "%d경기" % int(ln.get("g", 0))]]
	return [["타율", "%.3f" % float(ln.get("avg", 0.0))],
		["홈런", "%d개" % int(ln.get("hr", 0))],
		["OPS", "%.3f" % float(ln.get("ops", 0.0))],
		["타석", "%d" % int(ln.get("pa", 0))],
		["출장", "%d경기" % int(ln.get("g", 0))]]

# 스카우트 ─────────────────────────────────────────────────────────────────

# ── 스카우트 ───────────────────────────────────────────────────────────────
# 원작처럼 **팩을 카드로 늘어놓습니다** — 왼쪽에 팩 그림, 오른쪽에 이름 · 내용 ·
# 값. 단추 두 개만 있으면 "무엇을 뽑는 것인지"가 안 읽힙니다.
#
# **둘 다 코인으로 삽니다.** 재화를 나눠 두면 한쪽이 안 쓰이는 화면이 되기
# 쉬워서, 같은 지갑에서 무엇을 살지 고르는 쪽으로 두었습니다 — 대신 값을
# 벌려 놓아야 합니다(선수 팩 1000, 블록 300).
const PACKS := [
	{"id": "player", "name": "선수 카드", "tag": "랜덤",
		"note": "KBO 2000~2026 실제 기록 카드"},
	{"id": "block", "name": "스킬 블록", "tag": "랜덤",
		"note": "네 칸짜리 테트로미노 · 카드 판에 끼웁니다"},
]

func _pack_rect(i: int) -> Rect2:
	var b := _body()
	var w := minf((b.size.x - 16.0) * 0.5, 460.0)
	return Rect2(b.position.x + i * (w + 16.0), b.position.y + 30.0, w, 132.0)

func _pack_buy_rect(i: int) -> Rect2:
	var r := _pack_rect(i)
	return Rect2(r.position.x + 130.0, r.position.y + r.size.y - 42.0, r.size.x - 142.0, 32.0)

func _pack_cost(i: int) -> int:
	return D.PACK_COST if str(PACKS[i]["id"]) == "player" else Gr.DRAW_COST

func _pack_size(i: int) -> int:
	return D.PACK_SIZE if str(PACKS[i]["id"]) == "player" else Gr.DRAW_SIZE

func _pack_have(i: int) -> int:
	return Sv.coins

func _draw_scout() -> void:
	var b := _body()
	Art.txt(self, b.position + Vector2(0, 18), "스카우트", 18, P.TEXT)
	Art.txt(self, b.position + Vector2(84, 18),
		"보유 %d코인   ·   [도감] 에서 카드를 트레이드하면 코인이 됩니다   ·   [←→] 고르기 [Enter] 뽑기" % Sv.coins,
		13, P.TEXT_FAINT)

	for i in range(PACKS.size()):
		var pk: Dictionary = PACKS[i]
		var r := _pack_rect(i)
		var cost := _pack_cost(i)
		var can := _pack_have(i) >= cost
		# 키로 고르는 중인 팩은 **테두리를 굵게** — 안 그러면 Enter 가 어느 팩에
		# 먹는지 알 수가 없습니다.
		var sel := pack_i == i
		Art.panel(self, r, P.PANEL_HI,
			P.hdr(P.BAR_HIGH, 1.2) if sel else (P.hdr(P.BAR_MID, 1.15) if can else P.LINE),
			3.0 if sel else 2.0)
		# 왼쪽 — 팩 그림. 물음표 한 장으로 "무엇이 나올지 모른다"를 말합니다.
		var pic := Rect2(r.position.x + 8.0, r.position.y + 8.0, 110.0, r.size.y - 16.0)
		_draw_pack_art(pic, str(pk["id"]), can)
		# 오른쪽 — 이름 · 내용 · 값
		var x := r.position.x + 130.0
		Art.txt(self, Vector2(x, r.position.y + 28.0), str(pk["name"]), 19, P.TEXT)
		var tag := str(pk["tag"])
		var tw := Art.txt_w(tag, 12) + 12.0
		draw_rect(Rect2(r.position.x + r.size.x - tw - 10.0, r.position.y + 12.0, tw, 20.0),
			P.hdr(P.BAR_HIGH, 1.15), true)
		Art.txt(self, Vector2(r.position.x + r.size.x - tw - 4.0, r.position.y + 27.0), tag, 12,
			Color(0.06, 0.06, 0.09))
		Art.txt(self, Vector2(x, r.position.y + 50.0), str(pk["note"]), 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(x, r.position.y + 72.0), "한 번에 %d개" % _pack_size(i), 14,
			P.hdr(P.BAR_MID, 1.15))

		var buy := _pack_buy_rect(i)
		draw_rect(buy, P.PANEL_HI if can else P.PANEL, true)
		draw_rect(buy, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0 if can else 1.0)
		var t := "뽑기   %d 코인" % cost
		Art.txt(self, buy.position + Vector2(buy.size.x * 0.5 - Art.txt_w(t, 15) * 0.5, 22), t, 15,
			P.TEXT if can else P.TEXT_FAINT)

	# ── 뽑은 결과 ──
	var y := b.position.y + 180.0
	if not block_pack.is_empty():
		Art.txt(self, Vector2(b.position.x, y), "얻은 블록 %d개" % block_pack.size(), 16,
			P.hdr(P.BAR_MID, 1.15))
		for i in range(block_pack.size()):
			var bb: Dictionary = block_pack[i]
			var br := Rect2(b.position.x + i * 232.0, y + 14.0, 216.0, 92.0)
			Art.panel(self, br, P.PANEL_HI, P.hdr(P.BAR_HIGH, 1.15), 2.0)
			Art.block_icon(self, br.position + Vector2(14, 20), 13.0, bb,
				Art.BLOCK_COLS[i % Art.BLOCK_COLS.size()])
			Art.txt(self, br.position + Vector2(78, 30), Gr.block_name(bb), 15, P.TEXT)
			var ups := ""
			for k in Gr.block_value(bb):
				ups += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(Gr.block_value(bb)[k])]
			Art.txt(self, br.position + Vector2(78, 52), ups, 13, P.hdr(P.BAR_HIGH, 1.1))
			var who: String = "투수용" if str(Gr.skill(str(bb["sid"])).get("kind", "")) == "pitcher" else "야수용"
			Art.txt(self, br.position + Vector2(78, 72), who, 12, P.TEXT_FAINT)
		return
	if pack.is_empty():
		Art.txt(self, Vector2(b.position.x, y), "팩을 눌러 뽑으세요.", 15, P.TEXT_DIM)
		_draw_odds(b, y + 26.0)
		return

	Art.txt(self, Vector2(b.position.x, y), "얻은 카드 %d장" % pack.size(), 16, P.hdr(P.BAR_MID, 1.15))
	# **한 팩이 열 장**이라 한 줄에 다 못 넣습니다. 다섯씩 두 줄로 깝니다.
	var per := 5
	# **폭과 높이 둘 다 보고 줄입니다.** 폭만 보면 두 줄이 화면 아래로 넘칩니다.
	var avail := b.position.y + b.size.y - (y + 16.0)
	var cw := minf((b.size.x - 16.0) / float(per) - 12.0,
		(avail - 10.0) * 0.5 / Art.CARD_RATIO)
	for i in range(pack.size()):
		@warning_ignore("integer_division")
		var row := i / per
		Art.card(self, Vector2(b.position.x + (i % per) * (cw + 12.0),
			y + 16.0 + row * (cw * Art.CARD_RATIO + 10.0)), cw, pack[i], false)

func _draw_odds(b: Rect2, y: float) -> void:
	# 확률표는 등급이 아니라 **종합 구간**으로 보여 줍니다 — 등급이 둘뿐이라
	# "NORMAL 98.5%" 라고 적어 봐야 아무 정보가 아닙니다.
	var odds := ""
	for i in range(D.PACK_ODDS.size()):
		var lo := int(D.PACK_ODDS[i][0])
		var pct := float(D.PACK_ODDS[i][1]) * 100.0
		if lo == 0:
			odds += "그 외 %.1f%%" % pct
		elif i == 0:
			odds += "EX(종합 %d↑) %.1f%%   " % [lo, pct]
		else:
			odds += "종합 %d↑ %.1f%%   " % [lo, pct]
	Art.txt(self, Vector2(b.position.x, y), "선수 카드 확률 — " + odds, 13, P.TEXT_FAINT)

func _draw_pack_art(r: Rect2, id: String, lit: bool) -> void:
	# 팩 그림. 그림 파일 없이 벡터로 그립니다 — 물음표가 "무엇이 나올지 모른다"를
	# 말하고, 뒤 도형이 선수 팩인지 블록 팩인지를 가릅니다.
	var base: Color = P.hdr(P.BAR_MID, 1.1) if lit else P.a(P.LINE, 0.9)
	draw_rect(r, P.PANEL, true)
	draw_rect(r, base, false, 1.0)
	var m := r.get_center()
	if id == "block":
		# 네 칸짜리 조각 하나 — 블록 팩임을 모양으로 말합니다.
		var cell := r.size.x * 0.15
		for p in [[0, 0], [1, 0], [1, 1], [2, 1]]:
			draw_rect(Rect2(m.x - cell * 1.5 + int(p[0]) * cell,
				m.y - cell * 0.2 + int(p[1]) * cell, cell - 2.0, cell - 2.0),
				Art.BLOCK_COLS[0] if lit else P.a(Art.BLOCK_COLS[0], 0.45), true)
	else:
		# 카드 두 장이 겹친 실루엣.
		for k in range(2):
			var cr := Rect2(m.x - r.size.x * 0.24 + k * 10.0, m.y - r.size.y * 0.16 + k * 6.0,
				r.size.x * 0.34, r.size.y * 0.42)
			draw_rect(cr, P.PANEL_HI if lit else P.PANEL, true)
			draw_rect(cr, base, false, 1.0)
	var q := "?"
	Art.txt(self, Vector2(m.x - Art.txt_w(q, 34) * 0.5, r.position.y + 40.0), q, 34,
		P.hdr(P.BAR_HIGH, 1.2) if lit else P.a(P.TEXT_FAINT, 0.8))

func _do_pack() -> void:
	if Sv.coins < D.PACK_COST:
		_say("코인이 모자랍니다.")
		return
	Sv.coins -= D.PACK_COST
	pack.clear()
	block_pack.clear()
	for i in range(D.PACK_SIZE):
		var c := DB.draw_one(rng)
		if c.is_empty():
			continue
		pack.append(c)
		Sv.add_card(c)
	Sv.save_game()
	_refresh_study()
	_say("%d장을 얻었습니다." % pack.size())

func _draw_pack_now(i: int) -> void:
	# 팩 하나를 뽑습니다. **클릭과 키가 같은 통로를 지나야** 한쪽만 고쳤을 때
	# 조용히 어긋나지 않습니다.
	if i < 0 or i >= PACKS.size():
		return
	pack_i = i
	if str(PACKS[i]["id"]) == "block":
		_do_block_pack()
	else:
		_do_pack()

func _do_block_pack() -> void:
	if Sv.coins < Gr.DRAW_COST:
		_say("코인이 모자랍니다.")
		return
	Sv.coins -= Gr.DRAW_COST
	pack.clear()
	block_pack = Gr.draw_blocks(Gr.DRAW_SIZE)
	Sv.save_game()
	_refresh_study()
	_say("블록 %d개를 얻었습니다." % block_pack.size())

# 오더 ─────────────────────────────────────────────────────────────────────

# 오더는 **타자 탭 · 투수 탭 두 장**입니다. 25칸을 한 화면에 늘어놓으면 칸이
# 작아져서 카드가 안 읽히고, 팀컬러 칸까지 겹칩니다.
const ORDER_TABS := ["타자", "투수", "팀컬러"]
const ORDER_TAB_GROUPS := [["lineup", "bench"], ["rot", "relief", "setup", "closer"],
	["lineup", "bench"]]
const TAB_COLOR := 2

func _order_tab_rect(i: int) -> Rect2:
	var b := _body()
	return Rect2(b.position.x + i * 96.0, b.position.y - 4.0, 90.0, 26.0)

func _tab_groups() -> Array:
	return ORDER_TAB_GROUPS[clampi(order_tab, 0, ORDER_TAB_GROUPS.size() - 1)]

# ── 팀컬러 페이지 ──────────────────────────────────────────────────────────
# **못 켠 것까지 전부** 늘어놓고 진행도를 적습니다. 예전에는 켜진 것만 창에
# 띄웠는데, 조건을 못 맞췄을 때 **"왜 안 켜지는지"를 알 방법이 없었습니다** —
# 25명을 채웠는데도 안 나오면 게임이 고장 난 것처럼 보입니다.
var color_all: Array = []

func _color_row_rect(i: int) -> Rect2:
	var b := _body()
	var w := (b.size.x - 16.0) * 0.5
	@warning_ignore("integer_division")
	var col := i / 9
	return Rect2(b.position.x + col * (w + 16.0), b.position.y + 84.0 + (i % 9) * 52.0,
		w, 48.0)

func _draw_color_page() -> void:
	var b := _body()
	var t := Sim.team_from_save(D.MY_TEAM)
	color_all = Col.survey(Sim.playing_of(t), t.get("bench", []))
	color_list = t["colors"]
	# 켤 수 있는 것부터, 그 안에서 센 것부터. 못 켠 것은 **가까운 순서**로 —
	# 무엇을 조금만 더 채우면 되는지가 위에 오게 합니다.
	color_all.sort_custom(func(x, y):
		if bool(x["ok"]) != bool(y["ok"]):
			return bool(x["ok"])
		if bool(x["ok"]):
			return int(x["hit"]) + int(x["pit"]) > int(y["hit"]) + int(y["pit"])
		return float(x["have"]) / float(maxi(int(x["need"]), 1)) > float(y["have"]) / float(maxi(int(y["need"]), 1)))

	var on := 0
	for e in color_all:
		if bool((e as Dictionary)["ok"]):
			on += 1
	Art.txt(self, Vector2(b.position.x, b.position.y + 42.0),
		"켤 수 있는 것 %d개 / 전체 %d개" % [on, color_all.size()], 15, P.hdr(P.BAR_MID, 1.15))
	Art.txt(self, Vector2(b.position.x + 200.0, b.position.y + 42.0),
		"**하나만** 켤 수 있습니다.  누르면 켜지고, 다시 누르면 꺼집니다.".replace("**", ""),
		13, P.TEXT_FAINT)
	Art.txt(self, Vector2(b.position.x, b.position.y + 64.0),
		"단일팀 · 단일연도 · 왕조는 오더 %d칸을 **그것으로 전부** 채워야 켜집니다(벤치 포함)."
			.replace("**", "") % Col.roster_size(), 12, P.TEXT_FAINT)

	for i in range(color_all.size()):
		var e: Dictionary = color_all[i]
		var r := _color_row_rect(i)
		if r.position.y + r.size.y > b.position.y + b.size.y:
			continue
		var ok := bool(e["ok"])
		var lit := str(e["id"]) == Sv.color_id
		draw_rect(r, P.PANEL_HI if (ok or lit) else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if lit else (P.hdr(P.BAR_MID, 1.15) if ok else P.LINE),
			false, 2.0 if lit else 1.0)
		# 켜진 것 표시 — 색만으로는 "켤 수 있다"와 "켜져 있다"가 안 갈립니다.
		Art.txt(self, r.position + Vector2(10, 21), "●" if lit else ("○" if ok else "·"), 14,
			P.hdr(P.BAR_HIGH, 1.2) if lit else (P.TEXT_DIM if ok else P.a(P.TEXT_FAINT, 0.7)))
		Art.txt(self, r.position + Vector2(28, 21), str(e["name"]), 15,
			P.TEXT if ok else P.TEXT_DIM)
		Art.txt(self, r.position + Vector2(28, 40), str(e["why"]), 12,
			P.TEXT_DIM if ok else P.TEXT_FAINT)
		Art.txt(self, r.position + Vector2(r.size.x - 108.0, 21), str(e["group"]), 11, P.TEXT_FAINT)
		var bon := "야수 +%d · 투수 +%d" % [int(e["hit"]), int(e["pit"])]
		Art.txt(self, Vector2(r.position.x + r.size.x - 10.0 - Art.txt_w(bon, 12), r.position.y + 40.0),
			bon, 12, P.hdr(P.BAR_HIGH, 1.1) if ok else P.TEXT_FAINT)
		# 진행 막대 — 숫자만 있으면 "얼마나 남았나"가 한눈에 안 옵니다.
		var pw := 92.0
		var px := r.position.x + r.size.x - 10.0 - pw
		draw_rect(Rect2(px, r.position.y + 12.0, pw, 6.0), P.BAR_BG, true)
		var f := clampf(float(e["have"]) / float(maxi(int(e["need"]), 1)), 0.0, 1.0)
		draw_rect(Rect2(px, r.position.y + 12.0, pw * f, 6.0),
			P.hdr(P.BAR_HIGH, 1.15) if ok else P.BAR_MID, true)

func _click_color_page(p: Vector2) -> bool:
	for i in range(color_all.size()):
		if not _color_row_rect(i).has_point(p):
			continue
		var e: Dictionary = color_all[i]
		# **못 켜는 것을 누르면 이유를 말합니다.** 아무 반응이 없으면 고장으로 보입니다.
		if not bool(e["ok"]):
			_say("%s — 아직 %s" % [str(e["name"]), str(e["why"])])
			return true
		Sv.color_id = "" if str(e["id"]) == Sv.color_id else str(e["id"])
		Sv.save_game()
		return true
	return false

func _draw_order() -> void:
	var b := _body()
	# **팀컬러 목록을 매 프레임 갱신합니다.** 예전에는 팀컬러 창을 그릴 때만
	# 채워서, 창을 한 번도 안 열면 목록이 빈 채로 판정됐습니다 — 25칸을 다
	# 맞췄는데도 단추에 "켤 수 있는 것이 없습니다"가 뜨던 것이 이것입니다.
	color_list = Sim.team_from_save(D.MY_TEAM)["colors"]
	# 위 — 야수/투수 탭과 코스트 띠
	for i in range(ORDER_TABS.size()):
		var tr := _order_tab_rect(i)
		var on := order_tab == i
		draw_rect(tr, P.PANEL_HI if on else P.PANEL, true)
		draw_rect(tr, P.hdr(P.BAR_MID, 1.2) if on else P.LINE, false, 2.0 if on else 1.0)
		Art.txt(self, tr.position + Vector2(tr.size.x * 0.5 - Art.txt_w(str(ORDER_TABS[i]), 14) * 0.5, 18),
			str(ORDER_TABS[i]), 14, P.TEXT if on else P.TEXT_DIM)
	# 코스트·배치는 **탭과 상관없이 25칸 전부**를 셉니다 — 탭 안의 것만 세면
	# 투수 탭에서 상한을 넘긴 줄 모르고 경기에 들어갑니다.
	# 탭이 셋이라 x 를 **탭 줄 오른쪽에서** 시작합니다 — 상수로 박아 두면
	# 탭을 하나 늘렸을 때 그 위에 겹칩니다(실제로 겹쳤습니다).
	var hx := b.position.x + ORDER_TABS.size() * 96.0 + 14.0
	var cost := Sv.total_cost()
	var over := cost > D.COST_CAP
	Art.txt(self, Vector2(hx, b.position.y + 14.0),
		"코스트 %d / %d" % [cost, D.COST_CAP], 15, P.hdr(P.WARN, 1.2) if over else P.TEXT)
	var filled := 0
	for g in ORDER_GROUPS:
		for i in range(_group_count(str(g))):
			if _slot_id(str(g), i) != "":
				filled += 1
	Art.txt(self, Vector2(hx + 136.0, b.position.y + 14.0),
		"배치 %d / %d" % [filled, Col.roster_size()], 15,
		P.TEXT if filled >= Col.roster_size() else P.TEXT_DIM)
	# 배치 안내는 **배치 탭에서만** — 팀컬러 페이지에는 해당이 없습니다.
	if order_tab != TAB_COLOR:
		var dn := _dup_names()
		if dn.is_empty():
			Art.txt(self, Vector2(hx + 252.0, b.position.y + 14.0),
				"아래에서 누르면 고른 칸에 들어갑니다.  더블클릭은 빼기, 우클릭은 카드 크게 보기.",
				12, P.TEXT_FAINT)
		else:
			Art.txt(self, Vector2(hx + 252.0, b.position.y + 14.0),
				"같은 선수가 두 자리에 있습니다 (%d명) — 더블클릭으로 하나를 빼세요." % dn.size(),
				12, P.WARN)

	if order_tab == TAB_COLOR:
		_draw_color_page()
		Art.txt(self, Vector2(b.position.x, b.position.y + b.size.y - 8.0),
			"[Tab] 타자/투수/팀컬러   ·   조건을 못 채운 것을 누르면 무엇이 모자란지 알려 줍니다.",
			12, P.TEXT_FAINT)
		return

	# ── 위 판 : 배치선수 ──
	var top := Rect2(b.position.x, b.position.y + 40.0, b.size.x, SLOT_ROW_H + 34.0)
	Art.panel(self, top, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
	Art.txt(self, Vector2(top.position.x + 8.0, top.position.y + 20.0),
		"배치선수", 14, P.hdr(P.BAR_MID, 1.15))
	var dups := _dup_names()
	for g in _tab_groups():
		for i in range(_group_count(str(g))):
			var sr := _slot_rect(str(g), i)
			Art.slot(self, sr, DB.find(_slot_id(str(g), i)), _slot_label(str(g), i),
				sel_group == str(g) and sel_idx == i)
			# 이름이 겹치는 칸은 경고색 테두리로 — 한 사람이 두 자리에 서 있습니다.
			var dc := DB.find(_slot_id(str(g), i))
			if not dc.is_empty() and dups.has(str(dc.get("name", ""))):
				draw_rect(sr, P.WARN, false, 3.0)
				Art.txt(self, Vector2(sr.position.x + 4.0, sr.position.y + 15.0), "중복", 12, P.WARN)
			if str(g) != "lineup":
				continue
			# 수비 위치 — 눌러서 고르고, [,][.] 로도 넘깁니다.
			var qr := _pos_rect(i)
			var qon := pos_open == i
			var qsel := sel_group == "lineup" and sel_idx == i
			draw_rect(qr, P.PANEL_HI if (qsel or qon) else P.PANEL, true)
			draw_rect(qr, P.hdr(P.BAR_MID, 1.15) if (qsel or qon) else P.LINE, false, 1.0)
			Art.txt(self, qr.position + Vector2(5, 15),
				str(D.POS_SHORT.get(str(Sv.lineup_pos[i]), str(Sv.lineup_pos[i]))), 12,
				P.TEXT if (qsel or qon) else P.TEXT_DIM)
			Art.txt(self, qr.position + Vector2(qr.size.x - 12, 15), "▾", 9, P.TEXT_FAINT)

	# ── 아래 왼쪽 : 보유선수 ──
	var pr2 := _pool_rect()
	Art.panel(self, pr2, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
	Art.txt(self, Vector2(pr2.position.x + 8.0, pr2.position.y + 20.0),
		"보유선수 %d명" % pool.size(), 14, P.hdr(P.BAR_MID, 1.15))
	_draw_pool_chips()
	var pa := _pool_area()
	for i in range(pool.size()):
		var cr := _pool_cell(i)
		if cr.position.y + cr.size.y < pa.position.y or cr.position.y > pa.position.y + pa.size.y:
			continue
		Art.small_card(self, cr.position, cr.size.x, pool[i], i == pool_i, cr.size.y)
	if pool.is_empty():
		Art.txt(self, pa.position + Vector2(6, 26), "세울 수 있는 선수가 없습니다.", 14, P.TEXT_DIM)
		Art.txt(self, pa.position + Vector2(6, 48),
			"거르개를 풀거나 [스카우트] 에서 뽑으세요.", 13, P.TEXT_FAINT)

	# ── 아래 오른쪽 : 분석 ──
	_draw_analysis()

	Art.txt(self, Vector2(b.position.x, b.position.y + b.size.y - 8.0),
		"[Tab] 타자/투수/팀컬러   [Enter] 고른 칸에 넣기   [Del] 비우기   [P] · [,][.] 수비 위치   [C] 팀컬러",
		12, P.TEXT_FAINT)

	# 펼친 것은 **맨 나중에** — 아래 칸과 카드를 덮어야 합니다.
	_draw_pool_combo_open()
	if order_tab == 0:
		_draw_pos_open()
	# 끌고 있는 카드는 손끝에 작게 그립니다.
	if drag_slot != "":
		var dc := DB.find(_slot_id(drag_slot, drag_slot_i))
		if not dc.is_empty():
			Art.small_card(self, drag_pos - Vector2(26, 34), 52.0, dc, true)

func _dup_names() -> Dictionary:
	# 오더 안에서 **두 번 이상 나온 이름**. 보유선수 목록이 막아 주므로 새로
	# 생기지는 않지만, 규칙을 넣기 전에 짜 둔 오더에는 남아 있을 수 있습니다.
	#
	# **조용히 지우지 않습니다** — 남의 오더에서 선수를 빼는 것은 되돌릴 수 없고,
	# 지운 사실도 안 보입니다. 대신 눈에 띄게 표시해서 직접 고치게 합니다.
	var n := {}
	for g in ORDER_GROUPS:
		for i in range(_group_count(str(g))):
			var c := DB.find(_slot_id(str(g), i))
			if not c.is_empty():
				var k := str(c.get("name", ""))
				n[k] = int(n.get(k, 0)) + 1
	var out := {}
	for k in n:
		if int(n[k]) > 1:
			out[k] = int(n[k])
	return out

func _slot_label(g: String, i: int) -> String:
	match g:
		"lineup": return "%d번" % (i + 1)
		"bench": return "벤치%d" % (i + 1)
		"rot": return "선발%d" % (i + 1)
		"relief": return "중계%d" % (i + 1)
		"setup": return "셋업"
		"closer": return "마무리"
	return ""

# 보유선수 거르개 — 도감과 같은 콤보박스이고, 판 위에 가로로 늘어놓습니다.
func _pool_chip_rect(i: int) -> Rect2:
	var r := _pool_rect()
	return Rect2(r.position.x + 8.0 + i * 116.0, r.position.y + 30.0, 110.0, CHIP_H)

func _pool_combo_item_rect(i: int, j: int) -> Rect2:
	var c := _pool_chip_rect(i)
	return Rect2(c.position.x, c.position.y + c.size.y + 2.0 + j * COMBO_ROW, c.size.x, COMBO_ROW)

func _pool_combo_panel(i: int, n: int) -> Rect2:
	var c := _pool_chip_rect(i)
	return Rect2(c.position.x, c.position.y + c.size.y, c.size.x,
		mini(n, COMBO_MAX) * COMBO_ROW + 4.0)

func _draw_pool_chips() -> void:
	var list := _pick_chips()
	for i in range(list.size()):
		var e: Array = list[i]
		var cr := _pool_chip_rect(i)
		var on := str(e[1]) != "전체"
		var open := combo_i == i
		draw_rect(cr, P.PANEL_HI if (on or open) else P.PANEL, true)
		draw_rect(cr, P.hdr(P.BAR_MID, 1.15) if (on or open) else P.LINE, false, 1.0)
		Art.txt(self, cr.position + Vector2(7, 18), "%s %s" % [str(e[0]), str(e[1])], 12,
			P.TEXT if on else P.TEXT_DIM)
		Art.txt(self, cr.position + Vector2(cr.size.x - 14, 18), "▾", 10, P.TEXT_FAINT)

func _draw_pool_combo_open() -> void:
	var list := _pick_chips()
	if combo_i < 0 or combo_i >= list.size():
		return
	var opts: Array = (list[combo_i] as Array)[2]
	var shown := _combo_shown(opts)
	Art.panel(self, _pool_combo_panel(combo_i, opts.size()), P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	var cur = (list[combo_i] as Array)[3]
	for j in range(shown.size()):
		var o: Array = shown[j]
		var rr := _pool_combo_item_rect(combo_i, j)
		var sel: bool = o[1] == cur
		if sel:
			draw_rect(rr, P.PANEL_HI, true)
		Art.txt(self, rr.position + Vector2(7, 17), str(o[0]), 13,
			P.hdr(P.BAR_HIGH, 1.1) if sel else P.TEXT_DIM)

func _click_pool_chips(p: Vector2) -> bool:
	# **펼친 목록부터** 봅니다 — 목록이 아래 카드 격자를 덮고 있습니다.
	var list := _pick_chips()
	if combo_i >= 0 and combo_i < list.size():
		var opts: Array = (list[combo_i] as Array)[2]
		var shown := _combo_shown(opts)
		for j in range(shown.size()):
			if _pool_combo_item_rect(combo_i, j).has_point(p):
				_set_pick_filter(combo_i, (shown[j] as Array)[1])
				combo_i = -1
				return true
		if _pool_combo_panel(combo_i, opts.size()).has_point(p):
			return true
	for i in range(list.size()):
		if _pool_chip_rect(i).has_point(p):
			combo_i = -1 if combo_i == i else i
			combo_scroll = 0
			return true
	if combo_i >= 0:
		combo_i = -1
		return true
	return false

# ── 분석 ───────────────────────────────────────────────────────────────────
# 투수는 **배터리 분석**, 야수는 **타순 분석**. 자리마다 막대 하나를 세워
# "어디가 약한가"를 한눈에 보여 줍니다 — 숫자만 늘어놓으면 스물다섯 칸에서
# 약한 자리를 못 찾습니다.
const ANAL_BAND := ["나쁨", "보통", "좋음"]

func _anal_slots() -> Array:
	# [[표시 이름, 그룹, 번호]]. **벤치는 안 넣습니다** — 경기에 안 나오는
	# 자리라 막대가 낮아도 약한 것이 아닙니다.
	var out: Array = []
	if order_tab == 0:
		for i in range(D.LINEUP):
			out.append(["%d" % (i + 1), "lineup", i])
	else:
		for i in range(D.ROT):
			out.append(["선%d" % (i + 1), "rot", i])
		for i in range(D.RELIEF):
			out.append(["중%d" % (i + 1), "relief", i])
		out.append(["셋", "setup", 0])
		out.append(["마", "closer", 0])
	return out

func _anal_value(c: Dictionary) -> float:
	# 0~1. **경기에 실제로 쓰이는 스텟만** 가중합니다 — 종합(OV)을 그대로 쓰면
	# 체력처럼 "역할을 가르는 표시"까지 섞여서 분석이 경기 결과와 따로 놉니다.
	if c.is_empty():
		return 0.0
	var st: Dictionary = c.get("st", {})
	var v := 0.0
	if str(c.get("kind", "")) == "pitcher":
		v = (int(st.get("stuff", 50)) * 0.34 + int(st.get("control", 50)) * 0.30
			+ int(st.get("mental", 50)) * 0.22 + int(st.get("breaking", 50)) * 0.14)
	else:
		v = (int(st.get("contact", 50)) * 0.34 + int(st.get("power", 50)) * 0.30
			+ int(st.get("mental", 50)) * 0.16 + int(st.get("defense", 50)) * 0.12
			+ int(st.get("speed", 50)) * 0.08)
	return clampf((v - 30.0) / 60.0, 0.0, 1.0)

func _draw_analysis() -> void:
	var r := _anal_rect()
	Art.panel(self, r, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
	var title := "타순 분석" if order_tab == 0 else "배터리 분석"
	Art.txt(self, Vector2(r.position.x + 8.0, r.position.y + 20.0), title, 14, P.hdr(P.BAR_MID, 1.15))

	var slots := _anal_slots()
	var gx := r.position.x + 42.0
	var gy := r.position.y + 32.0
	var gw := r.size.x - 54.0
	var gh := r.size.y - 92.0
	# 세 칸 띠 — 나쁨 · 보통 · 좋음. 띠가 없으면 막대 높이가 뭘 뜻하는지 모릅니다.
	for k in range(3):
		var by := gy + gh * float(2 - k) / 3.0
		# 띠는 **눈에 보여야** 막대 높이가 뜻을 갖습니다. 바탕이 어두워서
		# 반투명 검정으로는 아무것도 안 보였습니다 — 밝기로 나눕니다.
		draw_rect(Rect2(gx, by, gw, gh / 3.0), P.PANEL_HI if k % 2 == 1 else P.PANEL, true)
		Art.txt(self, Vector2(r.position.x + 6.0, by + gh / 6.0 + 5.0), str(ANAL_BAND[k]), 11, P.TEXT_FAINT)
	draw_rect(Rect2(gx, gy, gw, gh), P.a(P.LINE, 0.7), false, 1.0)

	var bw := gw / float(maxi(slots.size(), 1))
	for i in range(slots.size()):
		var e: Array = slots[i]
		var c := DB.find(_slot_id(str(e[1]), int(e[2])))
		var v := _anal_value(c)
		var x := gx + i * bw
		if c.is_empty():
			# **빈 칸은 경고색 밑동**으로 둡니다. 0 짜리 막대로 그리면
			# "약한 선수"와 "아무도 없음"이 같아 보입니다.
			draw_rect(Rect2(x + bw * 0.18, gy + gh - 5.0, bw * 0.64, 5.0), P.a(P.WARN, 0.6), true)
		else:
			# 색과 높이가 **같은 것**을 말해야 읽기가 빠릅니다.
			draw_rect(Rect2(x + bw * 0.18, gy + gh - gh * v, bw * 0.64, gh * v),
				P.bar(int(30.0 + v * 65.0)), true)
		Art.txt(self, Vector2(x + bw * 0.5 - Art.txt_w(str(e[0]), 11) * 0.5, gy + gh + 15.0),
			str(e[0]), 11, P.TEXT_DIM)

	# 팀컬러는 이 판 아래 단추 하나로 — 늘 띄워 두면 분석이 들어갈 자리가 없습니다.
	var cb := _color_btn_rect()
	var lit := Sv.color_id != ""
	draw_rect(cb, P.PANEL_HI if lit else P.PANEL, true)
	draw_rect(cb, P.hdr(P.BAR_HIGH, 1.2) if lit else P.LINE, false, 1.0)
	var ct2 := "팀컬러 — %s" % _color_name()
	Art.txt(self, cb.position + Vector2(cb.size.x * 0.5 - Art.txt_w(ct2, 13) * 0.5, 19), ct2, 13,
		P.TEXT if lit else P.TEXT_DIM)

func _color_btn_rect() -> Rect2:
	var r := _anal_rect()
	return Rect2(r.position.x + 8.0, r.position.y + r.size.y - 32.0, r.size.x - 16.0, 26.0)

func _color_name() -> String:
	for e in color_list:
		if str((e as Dictionary)["id"]) == Sv.color_id:
			return str((e as Dictionary)["name"])
	if color_list.is_empty():
		return "켤 수 있는 것이 없습니다"
	return "%d개 켤 수 있음" % color_list.size()


var color_list: Array = []

const GROW_TABS := ["유학", "스킬블록", "구종"]

func _grow_tab_rect(i: int) -> Rect2:
	var b := _body()
	return Rect2(b.position.x + i * 100.0, b.position.y + 8.0, 96.0, 28.0)

func _draw_study() -> void:
	var b := _body()
	# 위 — 갈래 탭. 원작의 `계약연장 / 유학 / 전력보강` 자리입니다.
	var c := DB.find(_study_sel())
	for i in range(GROW_TABS.size()):
		if i == 2 and str(c.get("kind", "")) != "pitcher":
			continue   # 구종은 투수만
		var tr := _grow_tab_rect(i)
		var on := i == grow_tab
		draw_rect(tr, P.PANEL_HI if on else P.PANEL, true)
		draw_rect(tr, P.hdr(P.BAR_MID, 1.2) if on else P.LINE, false, 2.0 if on else 1.0)
		Art.txt(self, tr.position + Vector2(tr.size.x * 0.5 - Art.txt_w(GROW_TABS[i], 14) * 0.5, 19.0),
			GROW_TABS[i], 14, P.TEXT if on else P.TEXT_DIM)
	Art.txt(self, Vector2(b.position.x + 320.0, b.position.y + 27.0),
		"%s · 위로 갈수록 유학지가 늘어납니다   ·   유학은 COST 를 올리지 않습니다" % D.tier_name(Sv.tier),
		13, P.TEXT_FAINT)

	# ── 왼쪽 : 보유 카드 격자 ──
	var p := _study_panel()
	Art.panel(self, p, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
	Art.txt(self, Vector2(p.position.x + 8.0, p.position.y + 20.0),
		"보유선수 %d명" % study_list.size(), 14, P.hdr(P.BAR_MID, 1.15))
	_draw_study_chips()
	var a := _study_area()
	for i in range(study_list.size()):
		var cr := _study_cell(i)
		if cr.position.y + cr.size.y < a.position.y or cr.position.y > a.position.y + a.size.y:
			continue
		Art.small_card(self, cr.position, cr.size.x, study_list[i], i == study_i, cr.size.y)
		# 유학 상태를 카드 위에 겹쳐 씁니다 — 어느 카드가 나가 있는지 격자에서
		# 바로 안 보이면 작전을 짜다 없는 선수를 찾게 됩니다.
		var sid := DB.card_id(study_list[i])
		if Sv.away(sid):
			draw_rect(cr, P.a(Color(0.04, 0.05, 0.08), 0.6), true)
			var tag := "유학 %d" % Sv.away_left(sid)
			draw_rect(Rect2(cr.position.x, cr.position.y + cr.size.y * 0.42, cr.size.x, 17.0),
				P.a(Color.BLACK, 0.7), true)
			Art.txt(self, Vector2(cr.position.x + (cr.size.x - Art.txt_w(tag, 12)) * 0.5,
				cr.position.y + cr.size.y * 0.42 + 13.0), tag, 12, P.hdr(P.BAR_MID, 1.2))
		elif Sv.study_regions(sid).size() > 0:
			var n := Sv.study_regions(sid).size()
			draw_rect(Rect2(cr.position.x + cr.size.x - 20.0, cr.position.y + 2.0, 18.0, 15.0),
				P.hdr(P.BAR_HIGH, 1.15), true)
			Art.txt(self, Vector2(cr.position.x + cr.size.x - 14.0, cr.position.y + 14.0),
				"%d" % n, 11, Color(0.06, 0.06, 0.09))
	if study_list.is_empty():
		Art.txt(self, a.position + Vector2(6, 26), "보유한 카드가 없습니다.", 14, P.TEXT_DIM)
		Art.txt(self, a.position + Vector2(6, 48), "[스카우트] 에서 먼저 뽑으세요.", 13, P.TEXT_FAINT)

	# ── 오른쪽 : 선수 설명 + 갈래 내용 ──
	_draw_study_side(c)
	_draw_study_combo_open()
	if study_modal >= 0:
		_draw_study_modal(c)

func _draw_study_chips() -> void:
	var list := _study_chips()
	for i in range(list.size()):
		var e: Array = list[i]
		var cr := _study_chip_rect(i)
		var on := str(e[1]) != "전체"
		var open := combo_i == i
		draw_rect(cr, P.PANEL_HI if (on or open) else P.PANEL, true)
		draw_rect(cr, P.hdr(P.BAR_MID, 1.15) if (on or open) else P.LINE, false, 1.0)
		Art.txt(self, cr.position + Vector2(7, 18), "%s %s" % [str(e[0]), str(e[1])], 12,
			P.TEXT if on else P.TEXT_DIM)
		Art.txt(self, cr.position + Vector2(cr.size.x - 14, 18), "▾", 10, P.TEXT_FAINT)

func _draw_study_combo_open() -> void:
	var list := _study_chips()
	if combo_i < 0 or combo_i >= list.size():
		return
	var opts: Array = (list[combo_i] as Array)[2]
	var shown := _combo_shown(opts)
	Art.panel(self, _study_combo_panel(combo_i, opts.size()), P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	var cur = (list[combo_i] as Array)[3]
	for j in range(shown.size()):
		var o: Array = shown[j]
		var rr := _study_combo_item_rect(combo_i, j)
		var sel: bool = o[1] == cur
		if sel:
			draw_rect(rr, P.PANEL_HI, true)
		Art.txt(self, rr.position + Vector2(7, 17), str(o[0]), 13,
			P.hdr(P.BAR_HIGH, 1.1) if sel else P.TEXT_DIM)

func _click_study_chips(p: Vector2) -> bool:
	# **펼친 목록부터** 봅니다 — 목록이 아래 카드 격자를 덮고 있습니다.
	var list := _study_chips()
	if combo_i >= 0 and combo_i < list.size():
		var opts: Array = (list[combo_i] as Array)[2]
		var shown := _combo_shown(opts)
		for j in range(shown.size()):
			if _study_combo_item_rect(combo_i, j).has_point(p):
				_set_study_filter(combo_i, (shown[j] as Array)[1])
				combo_i = -1
				return true
		if _study_combo_panel(combo_i, opts.size()).has_point(p):
			return true
	for i in range(list.size()):
		if _study_chip_rect(i).has_point(p):
			combo_i = -1 if combo_i == i else i
			combo_scroll = 0
			return true
	if combo_i >= 0:
		combo_i = -1
		return true
	return false

# 원작의 `선수 설명` 판 — 이름 · 포지션 · 등급 · 코스트를 **줄로** 세웁니다.
# 한 줄에 몰아 쓰면 무엇이 무엇인지 안 읽힙니다.
func _draw_study_side(c: Dictionary) -> void:
	var s := _study_side()
	Art.panel(self, s, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
	if c.is_empty():
		Art.txt(self, s.position + Vector2(10, 26), "왼쪽에서 카드를 고르세요.", 14, P.TEXT_DIM)
		return
	var id := DB.card_id(c)
	Art.txt(self, s.position + Vector2(10, 22), "선수 설명", 14, P.hdr(P.BAR_MID, 1.15))
	var rows := [
		["이름", "%s %s" % [DB.year_tag(c), str(c.get("name", ""))]],
		["구단 · 포지션", "%s · %s" % [str(c.get("team", "")),
			str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", ""))))]],
		["카드 등급", "EX" if D.show_grade(str(c.get("grade", ""))) else "일반"],
		["선수 코스트", "%d   (종합 %d)" % [int(c.get("cost", 1)), int(c.get("ov", 0))]],
		["출전", "%d경기" % Gr.games(id)],
	]
	var y := s.position.y + 44.0
	for e in rows:
		draw_rect(Rect2(s.position.x + 10.0, y - 14.0, 108.0, 20.0), P.PANEL, true)
		Art.txt(self, Vector2(s.position.x + 16.0, y), str(e[0]), 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(s.position.x + 128.0, y), str(e[1]), 14, P.TEXT)
		y += 22.0

	if grow_tab == 1:
		_draw_skills(c, id)
		return
	if grow_tab == 2 and str(c.get("kind", "")) == "pitcher":
		_draw_pitches(c)
		return
	_draw_regions(s, c, id)

func _draw_regions(s: Rect2, c: Dictionary, id: String) -> void:
	var done := Sv.study_regions(id)
	var line := "다녀온 곳 %d / %d" % [done.size(), D.ABROAD.size()]
	if Sv.away(id):
		line += "   ·   %s 유학 중 (%d경기 남음)" % [str(D.ABROAD[Sv.away_region(id)]["name"]), Sv.away_left(id)]
	Art.txt(self, Vector2(s.position.x + 10.0, s.position.y + 168.0), line, 13, P.TEXT_FAINT)
	Art.txt(self, Vector2(s.position.x + 10.0, s.position.y + 186.0),
		"지역을 누르면 확인 창이 뜹니다.   [Q][W][E][R][T]", 12, P.TEXT_FAINT)
	for i in range(D.ABROAD.size()):
		var r := _region_rect(i)
		var been := done.has(i)
		var why := Sv.can_study(id, i)
		var can := why == ""
		draw_rect(r, P.PANEL_HI if can else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0 if can else 1.0)
		Art.txt(self, r.position + Vector2(12, 24), str(D.ABROAD[i]["name"]), 16,
			P.TEXT if can else P.TEXT_DIM)
		var ups := ""
		for k in (D.ABROAD[i]["up"] as Dictionary):
			ups += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(D.ABROAD[i]["up"][k])]
		Art.txt(self, r.position + Vector2(84, 24), ups, 13,
			P.hdr(P.BAR_HIGH, 1.1) if can else P.TEXT_FAINT)
		Art.txt(self, r.position + Vector2(12, 44),
			"%d경기 · %d코인" % [int(D.ABROAD[i]["days"]), int(D.ABROAD[i]["coin"])], 12, P.TEXT_FAINT)
		# **안 되는 이유를 그 자리에 적습니다** — 눌러 보고 나서야 아는 것보다
		# 무엇을 채우면 열리는지 미리 보이는 쪽이 낫습니다.
		var tag := "다녀옴" if been else ("" if can else why)
		if tag != "":
			Art.txt(self, Vector2(r.position.x + r.size.x - 10.0 - Art.txt_w(tag, 12), r.position.y + 44.0),
				tag, 12, P.hdr(P.BAR_HIGH, 1.1) if been else P.TEXT_FAINT)

# ── 유학 확인 창 ───────────────────────────────────────────────────────────
# 원작의 `선수 유학결정` 창입니다. **되돌릴 수 없는 것은 한 번 물어봅니다** —
# 코인이 나가고 그 카드가 여러 경기 동안 작전에서 빠지는데, 잘못 누르면
# 되돌릴 방법이 없습니다.
func _study_modal_rect() -> Rect2:
	var w := minf(size.x - 200.0, 620.0)
	var h := 300.0
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)

func _study_ok_rect() -> Rect2:
	var r := _study_modal_rect()
	return Rect2(r.position.x + r.size.x * 0.5 - 150.0, r.position.y + r.size.y - 46.0, 140.0, 34.0)

func _study_cancel_rect() -> Rect2:
	var r := _study_modal_rect()
	return Rect2(r.position.x + r.size.x * 0.5 + 10.0, r.position.y + r.size.y - 46.0, 140.0, 34.0)

func _draw_study_modal(c: Dictionary) -> void:
	if c.is_empty() or study_modal < 0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), P.a(Color.BLACK, 0.72), true)
	var r := _study_modal_rect()
	Art.panel(self, r, P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	Art.txt(self, r.position + Vector2(14, 26), "선수 유학결정", 17, P.TEXT)

	var cw := 150.0
	Art.card(self, r.position + Vector2(14, 40), cw, c, false)

	var x := r.position.x + cw + 34.0
	var ab: Dictionary = D.ABROAD[study_modal]
	var ups := ""
	for k in (ab["up"] as Dictionary):
		ups += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(ab["up"][k])]
	var rows := [
		["선수 코스트", "%d" % int(c.get("cost", 1))],
		["카드 등급", "EX" if D.show_grade(str(c.get("grade", ""))) else "일반"],
		["유 학 지", str(ab["name"])],
		["오르는 스텟", ups],
		["유학 기간", "%d경기" % int(ab["days"])],
		["유학 비용", "%d코인  (보유 %d)" % [int(ab["coin"]), Sv.coins]],
	]
	var y := r.position.y + 62.0
	for e in rows:
		draw_rect(Rect2(x, y - 15.0, 96.0, 22.0), P.PANEL_HI, true)
		Art.txt(self, Vector2(x + 6.0, y), str(e[0]), 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(x + 106.0, y), str(e[1]), 14, P.TEXT)
		y += 26.0
	Art.txt(self, Vector2(x, y + 6.0), "유학 중에는 작전에 넣을 수 없고, 중도 취소가 안 됩니다.",
		12, P.WARN)
	Art.txt(self, Vector2(x, y + 24.0), "COST 는 오르지 않습니다.", 12, P.TEXT_FAINT)

	var why := Sv.can_study(DB.card_id(c), study_modal)
	var ok := _study_ok_rect()
	draw_rect(ok, P.PANEL_HI if why == "" else P.PANEL, true)
	draw_rect(ok, P.hdr(P.BAR_HIGH, 1.2) if why == "" else P.LINE, false, 2.0)
	var t := "확인" if why == "" else why
	Art.txt(self, ok.position + Vector2(ok.size.x * 0.5 - Art.txt_w(t, 15) * 0.5, 23), t, 15,
		P.TEXT if why == "" else P.TEXT_FAINT)
	var cn := _study_cancel_rect()
	draw_rect(cn, P.PANEL, true)
	draw_rect(cn, P.LINE, false, 1.0)
	Art.txt(self, cn.position + Vector2(cn.size.x * 0.5 - Art.txt_w("취소", 15) * 0.5, 23), "취소", 15, P.TEXT_DIM)

# 구단관리 화면의 스킬블록 판. **드래그로 끼웁니다** — 자리 함수를 하나 두어
# 그리기 · 집기 · 놓기가 전부 같은 값을 봅니다.
func _board_rect() -> Rect2:
	# **오른쪽 판을 기준으로 잡습니다.** 본문 왼쪽에서 상수로 밀면 카드 격자
	# 폭이 바뀔 때 판이 격자 위로 올라탑니다(실제로 그랬습니다).
	var s := _study_side()
	return Rect2(s.position.x + 12.0, s.position.y + 176.0, 190.0, 190.0)

func _bag_rect(i: int) -> Rect2:
	# 아직 안 낀 블록 목록. 판 오른쪽에 두 줄로 늘어놓습니다.
	var s := _study_side()
	@warning_ignore("integer_division")
	var col := i / 6
	return Rect2(s.position.x + 218.0 + col * 168.0, s.position.y + 176.0 + (i % 6) * 34.0, 160.0, 30.0)

func _pitch_rect(i: int) -> Rect2:
	var s := _study_side()
	return Rect2(s.position.x + 12.0, s.position.y + 210.0 + i * 44.0, s.size.x - 24.0, 38.0)

func _draw_rect_btn(i: int) -> Rect2:
	var s := _study_side()
	return Rect2(s.position.x + 12.0, s.position.y + 408.0 + i * 34.0, 190.0, 30.0)

func _bag_list(c: Dictionary) -> Array:
	return Gr.free_blocks("pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter")

func _draw_skills(c: Dictionary, id: String) -> void:
	var s := _study_side()
	var x := s.position.x + 12.0
	var open: Array = Gr.open_cells(c)
	var nxt := Gr.next_cell_at(c)
	var head := "%d / %d 칸 열림" % [open.size(), Gr.CELLS]
	if str(c.get("grade", "")) == D.GRADE_EX:
		head += "  (EX)"
	elif nxt > 0:
		head += "  다음 %d경기" % nxt
	Art.txt(self, Vector2(x, s.position.y + 168.0), head, 14, P.TEXT_FAINT)

	# 판. 끌고 있는 중이면 그 자리에 미리보기를 얹습니다.
	var br := _board_rect()
	Art.panel(self, br, P.a(P.PANEL_HI, 0.55), P.LINE, 1.0)
	var gat := -1
	var gok := false
	if drag_uid >= 0:
		gat = Art.cell_at(br, drag_pos)
		if gat >= 0:
			gok = Gr.can_put(c, drag_uid, gat) == ""
	Art.blocks(self, br, c, drag_uid, gat, gok)

	# 판에 낀 블록 목록 — 무엇이 얼마나 올려 주는지.
	var bd := Gr.board(c)
	var uids: Array = bd["uids"]
	var ty := br.position.y + br.size.y + 22.0
	Art.txt(self, Vector2(x, ty), "낀 블록 %d개" % uids.size(), 14, P.hdr(P.BAR_MID, 1.15))
	var tot := Gr.skill_bonus(id)
	var ups := ""
	for k in tot:
		ups += "%s +%d  " % [str(D.ST_NAME.get(k, k)), int(tot[k])]
	Art.txt(self, Vector2(x + 92.0, ty), ups if ups != "" else "—", 13, P.hdr(P.BAR_HIGH, 1.1))

	for i in range(2):
		var r := _draw_rect_btn(i)
		var lab: String = ["남은 블록 자동으로 채우기", "판 비우기"][i]
		draw_rect(r, P.PANEL_HI, true)
		draw_rect(r, P.LINE, false, 1.0)
		Art.txt(self, r.position + Vector2(12, 20), lab, 13, P.TEXT_DIM)

	# 가방 — 안 낀 블록들
	var bag := _bag_list(c)
	Art.txt(self, Vector2(s.position.x + 218.0, s.position.y + 168.0),
		"가방 %d개" % bag.size(), 14, P.hdr(P.BAR_MID, 1.15))
	# 조작 안내는 단추 아래에 한 줄로. 위에 두면 칸 수 · 가방 머리글과 겹칩니다.
	Art.txt(self, Vector2(x, s.position.y + 500.0),
		"블록을 끌어다 판에 놓습니다.  우클릭으로 빼고, 가운데 버튼으로 돌립니다.",
		13, P.TEXT_FAINT)
	Art.txt(self, Vector2(x, s.position.y + 520.0),
		"[Q][W][E][R][T] 로 가방의 블록을 넣습니다.", 13, P.TEXT_FAINT)
	for i in range(mini(bag.size(), 12)):
		var bb: Dictionary = bag[i]
		var r := _bag_rect(i)
		var held := drag_uid == int(bb["uid"])
		draw_rect(r, P.PANEL_HI if held else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if held else P.LINE, false, 1.0)
		Art.block_icon(self, r.position + Vector2(6, 6), 4.5, bb, Art.BLOCK_COLS[i % Art.BLOCK_COLS.size()])
		Art.txt(self, r.position + Vector2(32, 20), Gr.block_name(bb), 13, P.TEXT_DIM)
	if bag.size() > 12:
		Art.txt(self, Vector2(s.position.x + 218.0, s.position.y + 388.0),
			"… 그리고 %d개 더" % (bag.size() - 12), 12, P.TEXT_FAINT)
	if bag.is_empty():
		Art.txt(self, Vector2(s.position.x + 218.0, s.position.y + 190.0),
			"블록이 없습니다 — [스카우트] 에서 뽑으세요.", 13, P.TEXT_FAINT)

	# 끌고 있는 블록은 손끝에 그립니다.
	if drag_uid >= 0:
		var db := Gr.block(drag_uid)
		Art.block_icon(self, drag_pos - Art.block_icon_size(db, 13.0) * 0.5, 13.0, db,
			P.hdr(P.BAR_HIGH, 1.15))

func _draw_pitches(c: Dictionary) -> void:
	var s := _study_side()
	var x := s.position.x + 12.0
	Art.txt(self, Vector2(x, s.position.y + 172.0),
		"구종은 출전할수록 등급이 오릅니다. 등급이 오르면 구위·변화구가 같이 오릅니다.",
		13, P.TEXT_FAINT)
	var ps := Gr.pitches_of(c)
	var bonus := Gr.pitch_bonus(c)
	Art.txt(self, Vector2(x, s.position.y + 192.0),
		"지금 보너스 — 구위 +%d · 변화구 +%d" % [int(bonus.get("stuff", 0)), int(bonus.get("breaking", 0))],
		14, P.hdr(P.BAR_HIGH, 1.15))
	for i in range(ps.size()):
		var p: Dictionary = ps[i]
		var r := _pitch_rect(i)
		draw_rect(r, P.PANEL, true)
		draw_rect(r, P.LINE, false, 1.0)
		Art.txt(self, r.position + Vector2(10, 26), str(p["name"]), 16, P.TEXT)
		var g := int(p["grade"])
		# 등급을 글자와 막대 둘 다로 보여 줍니다 — 글자만 두면 D 와 B 가 안 갈립니다.
		Art.txt(self, r.position + Vector2(110, 26), Gr.pitch_grade_name(g), 17,
			P.bar(40 + g * 15))
		var bw := 240.0
		draw_rect(Rect2(r.position.x + 150.0, r.position.y + 15.0, bw, 10.0), P.BAR_BG, true)
		draw_rect(Rect2(r.position.x + 150.0, r.position.y + 15.0,
			bw * float(g + 1) / float(Gr.PITCH_GRADES.size()), 10.0), P.bar(40 + g * 15), true)
		Art.txt(self, r.position + Vector2(410, 26), "(%s)" % str(D.ST_NAME.get(str(p["stat"]), "")), 13, P.TEXT_FAINT)

func _do_skill(i: int) -> void:
	var id := _study_sel()
	var c := DB.find(id)
	if c.is_empty():
		return
	# 키보드로 가방의 i 번째 블록을 판에 넣습니다. 마우스가 없어도 되게 —
	# 드래그만 두면 키보드로는 아예 못 끼웁니다.
	var bag := _bag_list(c)
	if i >= bag.size():
		return
	var uid := int((bag[i] as Dictionary)["uid"])
	for o in range(Gr.CELLS):
		if Gr.put(c, uid, o) == "":
			_refresh_study()
			return
	_say("들어갈 자리가 없습니다")

func _do_study(i: int) -> void:
	var id := _study_sel()
	var why := Sv.can_study(id, i)
	if why != "":
		_say(why)
		return
	if Sv.send_study(id, i):
		study_modal = -1
		_refresh_study()
		_say("%s 로 유학을 보냈습니다 (%d경기)" % [str(D.ABROAD[i]["name"]), int(D.ABROAD[i]["days"])])

func _season_blocked() -> String:
	# 시즌을 굴릴 수 없는 이유. 빈 문자열이면 괜찮습니다.
	var mine := Sim.team_from_save(D.MY_TEAM)
	var err := Sim.team_ok(mine)
	if err != "":
		return err
	if Sv.total_cost() > D.COST_CAP:
		return "총 COST %d 가 상한 %d 을 넘었습니다" % [Sv.total_cost(), D.COST_CAP]
	return ""

func _btn_label() -> String:
	if _season_blocked() != "":
		return "오더를 먼저 채우세요"
	if Sea.finished():
		return "시즌 마감 — 보상 받기"
	if Sea.active():
		return "다음 경기  (%d / %d)" % [Sv.game_no + 1, D.SEASON_GAMES]
	return "%d시즌 시작" % (Sv.season + 1)

func _draw_game() -> void:
	var b := _body()
	var blocked := _season_blocked()
	if blocked != "":
		Art.txt(self, b.position + Vector2(0, 30), "시즌을 굴릴 수 없습니다 — %s" % blocked, 17, P.hdr(P.WARN, 1.1))
		Art.txt(self, b.position + Vector2(0, 58), "[오더] 탭에서 채우세요.", 15, P.TEXT_DIM)
	elif Sv.season == 0:
		Art.txt(self, b.position + Vector2(0, 30), "리그는 나 포함 열 팀이고 한 시즌은 %d경기입니다." % D.SEASON_GAMES, 17, P.TEXT_DIM)
		Art.txt(self, b.position + Vector2(0, 58), "상대 팀의 세기는 내 타순 평균에 맞춰 잡힙니다.", 15, P.TEXT_FAINT)
		Art.txt(self, b.position + Vector2(0, 80), "선발은 로테이션 순서대로 나갑니다 — 5칸을 다 채워 두면 유리합니다.", 15, P.TEXT_FAINT)
	else:
		_draw_standings(b)
		if not last_game.is_empty():
			_draw_box(b, b.position.x + 470.0)
		elif Sea.active():
			var foe: Dictionary = Sea.next_foe()
			Art.txt(self, Vector2(b.position.x + 470.0, b.position.y + 34.0),
				"다음 상대 — %s" % str(foe.get("name", "")), 17, P.TEXT)

	var r := _btn_rect(0)
	var on := blocked == ""
	draw_rect(r, P.PANEL_HI if on else P.PANEL, true)
	draw_rect(r, P.hdr(P.BAR_MID, 1.2) if on else P.LINE, false, 2.0)
	var t := _btn_label()
	Art.txt(self, r.position + Vector2(r.size.x * 0.5 - Art.txt_w(t, 16) * 0.5, 27), t, 16,
		P.TEXT if on else P.TEXT_FAINT)

func _draw_standings(b: Rect2) -> void:
	var x0 := b.position.x
	var y := b.position.y + 20.0
	Art.txt(self, Vector2(x0, y), "%s   %d시즌  %d / %d 경기" % [
		D.tier_name(Sv.tier), Sv.season, Sv.game_no, D.SEASON_GAMES], 16, P.hdr(P.BAR_MID, 1.15))
	var lv := Sea.my_level()
	Art.txt(self, Vector2(x0 + 300.0, y), "리그 수준 %d · 내 팀 %d" % [D.tier_ov(Sv.tier), lv], 13, P.TEXT_FAINT)
	y += 20.0
	# 승강 경계를 표에 그려 두지 않으면 "몇 등부터 올라가는지"를 알 수가 없습니다.
	Art.txt(self, Vector2(x0, y), "상위 %d팀 승격 · 하위 %d팀 강등" % [D.PROMOTE_TOP, D.RELEGATE_BOTTOM],
		13, P.TEXT_FAINT)
	y += 22.0
	# **무승부 칸을 빠뜨리지 마세요.** 승·패만 세면 무승부가 난 팀만 경기 수가
	# 모자라 보여서 순위표를 못 믿게 됩니다(실제로 두산·LG 만 11경기로 보였습니다).
	# 승률은 KBO 와 같이 무승부를 뺀 승 ÷ (승+패) 입니다.
	var cols := [0.0, 40.0, 150.0, 200.0, 240.0, 280.0, 335.0, 400.0]
	var head := ["순위", "팀", "경기", "승", "패", "무", "승률", "게임차"]
	for i in range(head.size()):
		Art.txt(self, Vector2(x0 + float(cols[i]), y), str(head[i]), 13, P.TEXT_FAINT)
	y += 20.0
	var rows := Sea.standings()
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var mine := bool(r["mine"])
		var col: Color = P.hdr(P.BAR_HIGH, 1.15) if mine else P.TEXT_DIM
		if mine:
			draw_rect(Rect2(x0 - 6.0, y - 15.0, 450.0, 21.0), P.PANEL_HI, true)
		var n := int(r["w"]) + int(r["l"]) + int(r["d"])
		var vals := [str(i + 1), str(r["name"]), str(n), str(int(r["w"])), str(int(r["l"])),
			str(int(r["d"])), "%.3f" % float(r["pct"]), "-" if i == 0 else "%.1f" % float(r["gb"])]
		for k in range(vals.size()):
			Art.txt(self, Vector2(x0 + float(cols[k]), y), str(vals[k]), 14, col)
		# 승격권 · 강등권을 왼쪽 띠로 표시합니다.
		var zone := 0
		if i < D.PROMOTE_TOP and Sv.tier < D.TIERS.size() - 1:
			zone = 1
		elif i >= rows.size() - D.RELEGATE_BOTTOM and Sv.tier > 0:
			zone = -1
		if zone != 0:
			draw_rect(Rect2(x0 - 12.0, y - 14.0, 4.0, 18.0),
				P.hdr(P.BAR_MID, 1.3) if zone > 0 else P.hdr(P.WARN, 1.1), true)
		y += 21.0

func _draw_box(b: Rect2, x0: float) -> void:
	var g := last_game
	var names := [str((g["away"] as Dictionary)["name"]), str((g["home"] as Dictionary)["name"])]
	var innings: Array = g["line"][0]
	var y0 := b.position.y + 34.0
	var cw := 28.0
	Art.txt(self, Vector2(x0, y0), "팀", 14, P.TEXT_FAINT)
	for i in range(innings.size()):
		Art.txt(self, Vector2(x0 + 88.0 + i * cw, y0), str(i + 1), 14, P.TEXT_FAINT)
	Art.txt(self, Vector2(x0 + 96.0 + innings.size() * cw, y0), "R", 14, P.TEXT_FAINT)
	Art.txt(self, Vector2(x0 + 128.0 + innings.size() * cw, y0), "H", 14, P.TEXT_FAINT)
	for s in range(2):
		var y := y0 + 28.0 + s * 26.0
		var win := int(g["winner"]) == s
		Art.txt(self, Vector2(x0, y), names[s], 15, P.TEXT if win else P.TEXT_DIM)
		var ln: Array = g["line"][s]
		for i in range(ln.size()):
			var v := int(ln[i])
			Art.txt(self, Vector2(x0 + 88.0 + i * cw, y), "-" if v < 0 else str(v), 15,
				P.hdr(P.BAR_HIGH, 1.1) if v > 0 else P.TEXT_DIM)
		Art.txt(self, Vector2(x0 + 96.0 + ln.size() * cw, y), str(int(g["score"][s])), 15, P.TEXT)
		Art.txt(self, Vector2(x0 + 128.0 + ln.size() * cw, y), str(int(g["hits"][s])), 15, P.TEXT_DIM)

	var res := "무승부"
	if int(g["winner"]) == 0:
		res = "%s 승" % names[0]
	elif int(g["winner"]) == 1:
		res = "%s 승" % names[1]
	Art.txt(self, Vector2(x0, y0 + 96.0), res, 19, P.hdr(P.BAR_HIGH, 1.2))

	var y := y0 + 132.0
	Art.txt(self, Vector2(x0, y), "경기 기록", 14, P.TEXT_FAINT)
	y += 22.0
	var log: Array = g["log"]
	for i in range(maxi(0, log.size() - 14), log.size()):
		Art.txt(self, Vector2(x0, y), str(log[i]), 14, P.TEXT_DIM)
		y += 19.0

func _do_game() -> void:
	# 단추 하나가 상황에 따라 세 가지 일을 합니다 — 시작 · 다음 경기 · 마감.
	var blocked := _season_blocked()
	if blocked != "":
		_say(blocked)
		return
	if Sea.finished():
		var res := Sea.finish_season()
		last_game = {}
		var moved := int(res["moved"])
		var tail := ""
		if moved > 0:
			tail = " → %s 승격!" % D.tier_name(int(res["tier"]))
		elif moved < 0:
			tail = " → %s 강등" % D.tier_name(int(res["tier"]))
		_say("%d시즌 %d위 (%d승 %d패) · 보상 %d코인%s" % [
			int(res["season"]), int(res["rank"]), int(res["w"]), int(res["l"]),
			int(res["bonus"]), tail])
		Sea.start_season()
		return
	if not Sea.active():
		Sea.start_season()
		last_game = {}
		_say("%d시즌 시작 — %d경기" % [Sv.season, D.SEASON_GAMES])
		return
	var r := Sea.play_next()
	if r.has("error"):
		_say(str(r["error"]))
		return
	if r.is_empty():
		return
	last_game = r["game"]
	var back: Array = r.get("back", [])
	if not back.is_empty():
		var nm := str(DB.find(str(back[0])).get("name", ""))
		_say("%s 유학에서 돌아왔습니다%s" % [nm, "" if back.size() == 1 else " 외 %d명" % (back.size() - 1)])
		_refresh_study()
		return
	_say("%s 전 %d : %d — %d코인" % [str(r["foe"]),
		int(last_game["score"][0]), int(last_game["score"][1]), int(r["coin"])])

# ── 입력 ───────────────────────────────────────────────────────────────────

func _unhandled_input(e: InputEvent) -> void:
	# 드래그 중에는 마우스가 움직일 때마다 자리를 갱신하고, 버튼을 떼면 놓습니다.
	if drag_uid >= 0 or drag_slot != "":
		if e is InputEventMouseMotion:
			drag_pos = (e as InputEventMouseMotion).position
			queue_redraw()
			return
		if e is InputEventMouseButton and not e.pressed and \
				(e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			drag_pos = (e as InputEventMouseButton).position
			if drag_slot != "":
				_drop_slot()
			else:
				_drop()
			return
	if e is InputEventKey and e.pressed and not e.echo:
		_key(e as InputEventKey)
	elif e is InputEventMouseButton and e.pressed:
		_click(e as InputEventMouseButton)

func _drop_slot() -> void:
	# 오더 칸끼리 맞바꿉니다. **같은 탭 안에서만** — 타자 칸에 투수가 들어가면
	# 경기가 안 되고, 그걸 경기 시작하고서야 압니다.
	var g := drag_slot
	var i := drag_slot_i
	drag_slot = ""
	for g2 in _tab_groups():
		for j in range(_group_count(str(g2))):
			if not _slot_rect(str(g2), j).has_point(drag_pos):
				continue
			if str(g2) == g and j == i:
				# 제자리에 놓았으면 아무 일도 안 합니다 — 그 칸은 이미 골라져
				# 있으므로, 아래 보유선수를 누르면 바로 바뀝니다.
				queue_redraw()
				return
			var a := _slot_id(g, i)
			var b := _slot_id(str(g2), j)
			_set_slot(g, i, b)
			_set_slot(str(g2), j, a)
			# 타순은 수비 위치도 같이 따라갑니다 — 자리는 그대로 두고 사람만
			# 바꾸면 3루수 자리에 포수가 서 있게 됩니다.
			if g == "lineup" and str(g2) == "lineup":
				var pa = Sv.lineup_pos[i]
				Sv.lineup_pos[i] = Sv.lineup_pos[j]
				Sv.lineup_pos[j] = pa
				Sv.save_game()
			sel_group = str(g2)
			sel_idx = j
			_refresh_pool()
			queue_redraw()
			return
	queue_redraw()

func _drop() -> void:
	# 판 위에서 놓았으면 끼우고, 그 밖이면 그냥 놓습니다(= 빼기).
	var uid := drag_uid
	drag_uid = -1
	var c := DB.find(_study_sel())
	if c.is_empty():
		return
	var at := Art.cell_at(_board_rect(), drag_pos)
	if at < 0:
		queue_redraw()
		return
	var why := Gr.put(c, uid, at)
	if why != "":
		_say(why)
	_refresh_study()
	queue_redraw()

func _key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		# 큰 화면 → 고르기 창 → 게임 종료 순으로 닫습니다.
		if not detail.is_empty():
			detail = {}
			return
		if study_modal >= 0:
			study_modal = -1
			return
		if pos_open >= 0:
			pos_open = -1
			return
		if combo_i >= 0:
			combo_i = -1
			return
		# 화면 안이면 홈으로, 홈이면 게임 종료.
		if screen != S.HOME:
			_go(S.HOME)
			return
		get_tree().quit()
		return
	if e.keycode >= KEY_1 and e.keycode <= KEY_5:
		_go(int(MENU[e.keycode - KEY_1]))
		return
	if screen == S.HOME:
		return
	match screen:
		S.DEX: _key_dex(e)
		S.SCOUT:
			# **키로도 팩을 고를 수 있어야 합니다.** 예전에는 Enter 가 언제나 첫 팩을
			# 뽑아서, 블록을 뽑으려 해도 선수 팩 쪽으로 갔습니다. 클릭과 키가
			# `_draw_pack_now()` 하나를 같이 지나게 두면 한쪽만 고쳐지지 않습니다.
			match e.keycode:
				KEY_LEFT: pack_i = maxi(0, pack_i - 1)
				KEY_RIGHT: pack_i = mini(PACKS.size() - 1, pack_i + 1)
				KEY_ENTER, KEY_SPACE: _draw_pack_now(pack_i)
		S.STUDY: _key_study(e)
		S.ORDER: _key_order(e)
		S.GAME:
			if e.keycode == KEY_ENTER or e.keycode == KEY_SPACE:
				_do_game()

func _key_dex(e: InputEventKey) -> void:
	var cols := _dex_cols()
	match e.keycode:
		KEY_LEFT: _cycle_year(-1)
		KEY_RIGHT: _cycle_year(1)
		KEY_UP: _cycle_grade(-1)
		KEY_DOWN: _cycle_grade(1)
		KEY_TAB: _cycle_kind()
		KEY_A: _move(-1)
		KEY_D: _move(1)
		KEY_W: _move(-cols)
		KEY_S: _move(cols)

func _key_study(e: InputEventKey) -> void:
	# **키와 마우스 둘 다 채웁니다.** 키만 넣으면 "마우스로 못 보낸다"를
	# 눈치채기 어렵습니다.
	# 확인 창이 떠 있으면 그것부터.
	if study_modal >= 0:
		match e.keycode:
			KEY_ENTER, KEY_SPACE: _do_study(study_modal)
			KEY_ESCAPE: study_modal = -1
		return
	match e.keycode:
		# 격자라서 좌우는 한 칸, 위아래는 한 줄입니다.
		KEY_LEFT: _study_move(-1)
		KEY_RIGHT: _study_move(1)
		KEY_UP: _study_move(-STUDY_COLS)
		KEY_DOWN: _study_move(STUDY_COLS)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			pass   # 화면 전환이 먼저 먹습니다
		KEY_TAB: grow_tab = (grow_tab + 1) % GROW_TABS.size()
		KEY_Q: _grow_act(0)
		KEY_W: _grow_act(1)
		KEY_E: _grow_act(2)
		KEY_R: _grow_act(3)
		KEY_T: _grow_act(4)

func _study_move(d: int) -> void:
	if study_list.is_empty():
		return
	study_i = clampi(study_i + d, 0, study_list.size() - 1)
	var a := _study_area()
	var r := _study_cell(study_i)
	if r.position.y < a.position.y:
		study_scroll -= a.position.y - r.position.y
	elif r.position.y + r.size.y > a.position.y + a.size.y:
		study_scroll += r.position.y + r.size.y - (a.position.y + a.size.y)
	study_scroll = maxf(0.0, study_scroll)

func _click_study(p: Vector2, btn: int = MOUSE_BUTTON_LEFT) -> void:
	# **덮고 있는 것부터** 봅니다 — 확인 창 → 거르개 목록 → 그 밖.
	if study_modal >= 0:
		if _study_ok_rect().has_point(p):
			_do_study(study_modal)
			return
		if _study_cancel_rect().has_point(p) or not _study_modal_rect().has_point(p):
			study_modal = -1
		return
	if _click_study_chips(p):
		return
	var a := _study_area()
	if a.has_point(p):
		for i in range(study_list.size()):
			if _study_cell(i).has_point(p):
				study_i = i
				return
		return
	for i in range(GROW_TABS.size()):
		if _grow_tab_rect(i).has_point(p):
			grow_tab = i
			return
	if grow_tab == 1:
		_click_blocks(p, btn)
		return
	if grow_tab != 0:
		return
	for i in range(D.ABROAD.size()):
		if _region_rect(i).has_point(p):
			# **바로 보내지 않고 확인 창을 띄웁니다.** 코인이 나가고 그 카드가
			# 여러 경기 동안 작전에서 빠지는데, 잘못 누르면 되돌릴 수 없습니다.
			study_modal = i
			return

func _click_blocks(p: Vector2, btn: int) -> void:
	var b := _body()
	var c := DB.find(_study_sel())
	if c.is_empty():
		return
	var br := _board_rect()
	var at := Art.cell_at(br, p)
	if at >= 0:
		var uid := int((Gr.board(c)["cell"] as Dictionary).get(at, -1))
		if uid < 0:
			return
		match btn:
			MOUSE_BUTTON_RIGHT:
				Gr.take(uid)          # 빼서 가방으로
			MOUSE_BUTTON_MIDDLE:
				Gr.rotate_block(uid)  # 제자리에서 돌리기
			_:
				# 판에 있는 것도 집어서 옮길 수 있어야 합니다 — 한 번 끼우면
				# 못 옮기면 판을 다시 짜려고 전부 빼야 합니다.
				drag_uid = uid
				drag_pos = p
		_refresh_study()
		return
	for i in range(2):
		if _draw_rect_btn(i).has_point(p):
			if i == 0:
				var n := Gr.auto_fill(c)
				_say("블록 %d개를 채웠습니다" % n if n > 0 else "더 들어갈 자리가 없습니다")
			else:
				Gr.clear_board(c)
			_refresh_study()
			return
	var bag := _bag_list(c)
	for i in range(mini(bag.size(), 12)):
		if _bag_rect(i).has_point(p):
			var uid2 := int((bag[i] as Dictionary)["uid"])
			if btn == MOUSE_BUTTON_MIDDLE:
				Gr.rotate_block(uid2)
			else:
				drag_uid = uid2
				drag_pos = p
			return

func _key_order(e: InputEventKey) -> void:
	match e.keycode:
		KEY_TAB:
			order_tab = (order_tab + 1) % ORDER_TABS.size()
			sel_group = str(_tab_groups()[0])
			sel_idx = 0
			pos_open = -1
			_refresh_pool()
		KEY_LEFT: sel_idx = maxi(0, sel_idx - 1)
		KEY_RIGHT: sel_idx = mini(_group_count(sel_group) - 1, sel_idx + 1)
		KEY_UP: _cycle_group(-1)
		KEY_DOWN: _cycle_group(1)
		# 보유선수 판에서 고른 것을 지금 칸에 넣습니다.
		KEY_ENTER, KEY_SPACE: _put_pool(pool_i)
		KEY_A: pool_i = maxi(0, pool_i - 1)
		KEY_S: pool_i = mini(pool.size() - 1, pool_i + 1)
		KEY_C: order_tab = TAB_COLOR
		KEY_BRACKETLEFT: _cycle_color(-1)
		KEY_BRACKETRIGHT: _cycle_color(1)
		KEY_DELETE, KEY_BACKSPACE:
			_set_slot(sel_group, sel_idx, "")
			_refresh_pool()
		KEY_COMMA:
			if sel_group == "lineup":
				_cycle_pos(-1)
		KEY_PERIOD:
			if sel_group == "lineup":
				_cycle_pos(1)
		KEY_P:
			# 키보드로도 드롭다운을 열 수 있어야 합니다.
			if sel_group == "lineup":
				pos_open = -1 if pos_open == sel_idx else sel_idx

func _cycle_group(d: int) -> void:
	# **지금 탭 안에서만** 돕니다 — 안 그러면 위아래 키가 안 보이는 칸으로
	# 넘어가서 화면은 그대로인데 고른 칸만 사라집니다.
	var gs := _tab_groups()
	var i := gs.find(sel_group)
	if i < 0:
		i = 0
	sel_group = str(gs[posmod(i + d, gs.size())])
	sel_idx = clampi(sel_idx, 0, _group_count(sel_group) - 1)

# 타순의 수비 위치 — **누르면 목록이 펼쳐지는 드롭다운**입니다(원작 오더창의
# 그 자리). `,` `.` 키로도 바꿉니다. **키만 두면 마우스로 못 바꾸는 것을**
# 눈치채기 어렵습니다 — 이 저장소에서 되풀이해 온 실수입니다.
#
# 펼침 상태는 거르개와 따로 둡니다(`pos_open`). 같은 변수를 쓰면 거르개를 펼친
# 채 자리를 누르면 둘이 같이 열립니다.
func _pos_rect(i: int) -> Rect2:
	# **칸 밑변에서 잡습니다** — 칸 높이를 상수로 다시 쓰면 칸이 커질 때
	# 자리 표시만 제자리에 남아 판 테두리에 걸칩니다.
	var pr := _slot_rect("lineup", i)
	return Rect2(pr.position.x, pr.position.y + pr.size.y + 3.0, pr.size.x, 20.0)

func _pos_item_rect(i: int, j: int) -> Rect2:
	var r := _pos_rect(i)
	return Rect2(r.position.x, r.position.y + r.size.y + 2.0 + j * COMBO_ROW,
		maxf(r.size.x, 74.0), COMBO_ROW)

func _pos_panel(i: int) -> Rect2:
	var r := _pos_rect(i)
	return Rect2(r.position.x, r.position.y + r.size.y, maxf(r.size.x, 116.0),
		D.POS.size() * COMBO_ROW + 4.0)

func _draw_pos_open() -> void:
	if pos_open < 0 or pos_open >= D.LINEUP:
		return
	Art.panel(self, _pos_panel(pos_open), P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	var cur := str(Sv.lineup_pos[pos_open])
	# **다른 타순이 맡은 자리는 몇 번과 맞바뀌는지 적습니다.** 수비 위치는 유일해서
	# 고르면 그 자리 주인과 맞바뀝니다 — 그걸 미리 안 보여 주면 엉뚱한 타순의
	# 자리가 같이 바뀐 것을 나중에 알게 됩니다.
	var owner := {}
	for k in range(D.LINEUP):
		if k != pos_open:
			owner[str(Sv.lineup_pos[k])] = k
	for j in range(D.POS.size()):
		var p := str(D.POS[j])
		var r := _pos_item_rect(pos_open, j)
		if p == cur:
			draw_rect(r, P.PANEL_HI, true)
		Art.txt(self, r.position + Vector2(7, 17), str(D.POS_SHORT.get(p, p)), 13,
			P.hdr(P.BAR_HIGH, 1.1) if p == cur else P.TEXT_DIM)
		if owner.has(p):
			var sw := "↔%d번" % (int(owner[p]) + 1)
			Art.txt(self, Vector2(r.position.x + r.size.x - Art.txt_w(sw, 11) - 5.0,
				r.position.y + 16.0), sw, 11, P.TEXT_FAINT)

func _click_pos(p: Vector2) -> bool:
	# **펼친 목록부터** 봅니다 — 아래 벤치 칸을 덮고 있습니다.
	if pos_open >= 0:
		for j in range(D.POS.size()):
			if _pos_item_rect(pos_open, j).has_point(p):
				_set_pos(pos_open, str(D.POS[j]))
				pos_open = -1
				return true
		if _pos_panel(pos_open).has_point(p):
			return true
		pos_open = -1
		return true
	for i in range(D.LINEUP):
		if _pos_rect(i).has_point(p):
			sel_group = "lineup"
			sel_idx = i
			pos_open = i
			return true
	return false

func _set_pos(slot: int, pos: String) -> void:
	# **수비 위치는 유일합니다.** 타순 아홉 자리가 아홉 자리를 하나씩 나눠 가집니다 —
	# 같은 자리에 둘을 세우면 한 자리가 비고, 그 사실이 화면에 안 드러납니다.
	#
	# 막지 않고 **맞바꿉니다.** "이미 3루수가 있습니다" 라고 거절하면 자리를 바꾸려고
	# 두 번 눌러야 하는데(먼저 남의 자리를 옮기고 나서 내 자리를), 맞바꾸면 한 번에
	# 끝나고 아홉 자리가 언제나 온전히 채워집니다.
	if slot < 0 or slot >= D.LINEUP:
		return
	var old := str(Sv.lineup_pos[slot])
	if old == pos:
		return
	for j in range(D.LINEUP):
		if j != slot and str(Sv.lineup_pos[j]) == pos:
			Sv.lineup_pos[j] = old
			break
	Sv.lineup_pos[slot] = pos
	Sv.save_game()

func _cycle_pos(d: int) -> void:
	var i := D.POS.find(str(Sv.lineup_pos[sel_idx]))
	_set_pos(sel_idx, str(D.POS[posmod(i + d, D.POS.size())]))

# 그 자리에 있는 카드. **우클릭이 어느 화면에서나 큰 카드를 열게** 하는 통로입니다
# — 화면마다 따로 분기를 두면 한 곳을 빠뜨렸을 때 "여기선 안 되네"가 됩니다.
func _card_at(p: Vector2) -> Dictionary:
	match screen:
		S.DEX:
			for i in range(dex.size()):
				if _grid_rect(i).has_point(p):
					return dex[i]
		S.STUDY:
			if _study_area().has_point(p):
				for i in range(study_list.size()):
					if _study_cell(i).has_point(p):
						return DB.find(DB.card_id(study_list[i]))
		S.ORDER:
			# 보유선수 판과 배치선수 칸 **둘 다** 큰 화면을 엽니다.
			# 자리 비우기는 우클릭이 아니라 **더블클릭**이라 서로 안 겹칩니다.
			if _pool_area().has_point(p):
				for i in range(pool.size()):
					if _pool_cell(i).has_point(p):
						return pool[i]
				return {}
			for g in _tab_groups():
				for i in range(_group_count(str(g))):
					if _slot_rect(str(g), i).has_point(p):
						return DB.find(_slot_id(str(g), i))
	return {}

func _open_detail(c: Dictionary) -> bool:
	if c.is_empty():
		return false
	detail = c
	return true

func _click(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP:
		var d := 60.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60.0
		if screen == S.DEX:
			dex_scroll = clampf(dex_scroll + d, 0.0, _max_scroll())
		elif screen == S.STUDY:
			study_scroll = clampf(study_scroll + d, 0.0, _study_max_scroll())
		elif screen == S.ORDER:
			pool_scroll = clampf(pool_scroll + d, 0.0, _pool_max_scroll())
		return
	# **우클릭은 어느 화면에서나 큰 카드를 엽니다.** 왼쪽 버튼은 그 화면의 본래
	# 동작(고르기·자리 넣기)을 그대로 두고, 자세히 보는 것만 오른쪽으로 뺐습니다.
	# 스킬블록 판 위에서는 오른쪽·가운데 버튼이 빼기·돌리기입니다. 큰 카드보다
	# 먼저 봐야 판 위에서 우클릭했을 때 엉뚱하게 카드가 뜨지 않습니다.
	if detail.is_empty() and screen == S.STUDY and grow_tab == 1 and \
			e.button_index != MOUSE_BUTTON_LEFT and \
			Art.cell_at(_board_rect(), e.position) >= 0:
		_click_blocks(e.position, e.button_index)
		return
	if e.button_index == MOUSE_BUTTON_RIGHT:
		if not detail.is_empty():
			detail = {}
			return
		_open_detail(_card_at(e.position))
		return
	if e.button_index == MOUSE_BUTTON_MIDDLE:
		if screen == S.STUDY and grow_tab == 1:
			_click_blocks(e.position, e.button_index)
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	# 큰 화면이 떠 있으면 — 트레이드 단추만 받고, 나머지는 닫습니다.
	if not detail.is_empty():
		if _trade_rect().has_point(e.position) and Sv.has(DB.card_id(detail)):
			_do_trade()
		else:
			detail = {}
		return
	if screen == S.HOME:
		for i in range(MENU.size()):
			if _menu_rect(i).has_point(e.position):
				_go(int(MENU[i]))
				return
		return
	if _back_rect().has_point(e.position):
		_go(S.HOME)
		return
	match screen:
		S.DEX:
			if _click_chips(_dex_chips(), _body().position.x, _body().position.y, e.position, _set_dex_filter):
				return
			for i in range(dex.size()):
				if _grid_rect(i).has_point(e.position):
					dex_i = i
					_open_detail(dex[i])   # 누르면 큰 화면
					return
		S.SCOUT:
			for i in range(PACKS.size()):
				# **팩 전체가 눌립니다** — 작은 단추만 눌리면 "어디를 눌러야 하나"를
				# 찾게 됩니다. 단추는 값을 보여 주는 자리이기도 합니다.
				if _pack_rect(i).has_point(e.position):
					_draw_pack_now(i)
					return
		S.STUDY: _click_study(e.position, e.button_index)
		S.ORDER: _click_order(e.position, e.double_click)
		S.GAME:
			if _btn_rect(0).has_point(e.position):
				_do_game()

func _click_order(p: Vector2, dbl: bool = false) -> void:
	# **덮고 있는 것부터** 봅니다 — 팀컬러 창 → 수비 위치 목록 → 거르개 목록 →
	# 칸. 아래 것을 먼저 보면 위에 뜬 목록에서 고른 것이 그대로 새어 나갑니다.
	if order_tab == TAB_COLOR:
		for i in range(ORDER_TABS.size()):
			if _order_tab_rect(i).has_point(p):
				order_tab = i
				sel_group = str(_tab_groups()[0])
				sel_idx = 0
				_refresh_pool()
				return
		_click_color_page(p)
		return
	# 팀컬러 단추 → **팀컬러 페이지로 갑니다.** 예전에는 따로 창을 띄웠는데,
	# 목록이 두 곳에 있으면 한쪽만 고쳐져서 조건과 표시가 갈라집니다.
	if _color_btn_rect().has_point(p):
		order_tab = TAB_COLOR
		return
	if order_tab == 0 and _click_pos(p):
		return
	if _click_pool_chips(p):
		return
	for i in range(ORDER_TABS.size()):
		if _order_tab_rect(i).has_point(p):
			order_tab = i
			# 탭을 넘기면 고른 칸도 그 탭의 첫 칸으로 옮깁니다 — 안 옮기면
			# 안 보이는 칸이 골라져 있어서 방향키가 엉뚱하게 움직입니다.
			sel_group = str(_tab_groups()[0])
			sel_idx = 0
			_refresh_pool()
			return
	for g in _tab_groups():
		for i in range(_group_count(str(g))):
			if not _slot_rect(str(g), i).has_point(p):
				continue
			sel_group = str(g)
			sel_idx = i
			# **더블클릭 = 자리 비우기.** 한 번 누르는 것은 고르기/끌기라
			# 두 번 눌러야 빠집니다 — 우클릭은 카드를 크게 보는 쪽으로 두었습니다.
			if dbl and _slot_id(str(g), i) != "":
				_set_slot(str(g), i, "")
				drag_slot = ""
				_refresh_pool()
				return
			# **든 칸은 끌기 시작, 빈 칸은 고르기만.** 빈 칸을 끌게 두면
			# 아무것도 안 든 것을 끌고 다니게 됩니다. 채우는 것은 아래
			# 보유선수 판에서 누르면 되므로 창을 띄우지 않습니다.
			if _slot_id(str(g), i) != "":
				drag_slot = str(g)
				drag_slot_i = i
				drag_pos = p
			return
	# 보유선수 판 — 누르면 **고른 칸에 바로 들어갑니다.**
	var pa := _pool_area()
	if pa.has_point(p):
		for i in range(pool.size()):
			if _pool_cell(i).has_point(p):
				pool_i = i
				_put_pool(i)
				return

func _put_pool(i: int) -> void:
	# 보유선수 하나를 지금 고른 칸에 넣습니다.
	if i < 0 or i >= pool.size():
		return
	var c: Dictionary = pool[i]
	var want := "hitter" if order_tab == 0 else "pitcher"
	if str(c.get("kind", "")) != want:
		_say("이 탭에는 넣을 수 없는 선수입니다")
		return
	# 목록에서 이미 걸러 내지만, **넣는 쪽에서도 한 번 봅니다** — 목록이 낡은
	# 상태로 눌리면 같은 선수가 두 자리에 서게 됩니다.
	for g in ORDER_GROUPS:
		for k in range(_group_count(str(g))):
			var oc := DB.find(_slot_id(str(g), k))
			if not oc.is_empty() and str(oc.get("name", "")) == str(c.get("name", "")):
				_say("%s 은(는) 이미 오더에 있습니다" % str(c.get("name", "")))
				return
	_set_slot(sel_group, sel_idx, DB.card_id(c))
	# **넣었으면 다음 빈 칸으로 옮깁니다.** 아홉 자리를 채우는데 칸을 매번
	# 손으로 옮겨야 하면 목록을 늘 띄워 둔 뜻이 없습니다.
	_next_empty()
	_refresh_pool()

func _next_empty() -> void:
	# 지금 칸 다음의 빈 칸으로. 없으면 그 자리에 그대로 둡니다.
	var gs := _tab_groups()
	var gi := gs.find(sel_group)
	if gi < 0:
		gi = 0
	var total := 0
	for g in gs:
		total += _group_count(str(g))
	var cur := 0
	for k in range(gi):
		cur += _group_count(str(gs[k]))
	cur += sel_idx
	for step in range(1, total + 1):
		var n := (cur + step) % total
		for g in gs:
			var cnt := _group_count(str(g))
			if n < cnt:
				if _slot_id(str(g), n) == "":
					sel_group = str(g)
					sel_idx = n
					return
				break
			n -= cnt


func _max_scroll() -> float:
	var a := _dex_area()
	var rows := ceili(float(dex.size()) / float(_dex_cols()))
	return maxf(0.0, rows * _row_h() - a.size.y)

func _move(d: int) -> void:
	if dex.is_empty():
		return
	dex_i = clampi(dex_i + d, 0, dex.size() - 1)
	var a := _dex_area()
	var r := _grid_rect(dex_i)
	if r.position.y < a.position.y:
		dex_scroll -= a.position.y - r.position.y
	elif r.position.y + r.size.y > a.position.y + a.size.y:
		dex_scroll += r.position.y + r.size.y - (a.position.y + a.size.y)
	dex_scroll = clampf(dex_scroll, 0.0, _max_scroll())

func _cycle_year(d: int) -> void:
	if DB.years.is_empty():
		return
	var list: Array = [0]
	list.append_array(DB.years)
	var i := list.find(f_year)
	f_year = int(list[posmod(i + d, list.size())])
	_refilter()

func _cycle_grade(d: int) -> void:
	var list := ["", "EX", "NORMAL"]
	var i := list.find(f_grade)
	f_grade = str(list[posmod(i + d, list.size())])
	_refilter()

func _cycle_kind() -> void:
	var list := ["", "hitter", "pitcher"]
	var i := list.find(f_kind)
	f_kind = str(list[posmod(i + 1, list.size())])
	_refilter()

func _cycle_color(d: int) -> void:
	# 팀컬러를 키로도 바꿉니다. 빈 칸("")을 목록 앞에 두어 끌 수도 있게 합니다.
	if color_list.is_empty():
		_say("조건을 만족한 팀컬러가 없습니다.")
		return
	var ids: Array = [""]
	for e in color_list:
		ids.append(str(e["id"]))
	var i := ids.find(Sv.color_id)
	if i < 0:
		i = 0
	Sv.color_id = str(ids[posmod(i + d, ids.size())])
	Sv.save_game()

func _grow_act(i: int) -> void:
	# 오른쪽 갈래에 따라 같은 키가 다른 일을 합니다.
	if grow_tab == 1:
		_do_skill(i)
	elif grow_tab == 0:
		# 키로도 **확인 창을 거칩니다** — 마우스와 다른 길로 보내지면
		# 실수로 눌렀을 때 되돌릴 방법이 키 쪽에만 없게 됩니다.
		if i < D.ABROAD.size():
			study_modal = i

func _hit(r: Rect2, right: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = r.position + r.size * 0.5
	Input.parse_input_event(e)

func _release(r: Rect2) -> void:
	# 드래그를 놓는 시늉. 누르기와 떼기가 짝이 맞아야 드래그를 검사할 수 있습니다.
	var m := InputEventMouseMotion.new()
	m.position = r.position + r.size * 0.5
	Input.parse_input_event(m)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = r.position + r.size * 0.5
	Input.parse_input_event(e)

func _hit_menu(s: int) -> void:
	# 홈으로 돌린 뒤 그 메뉴 줄을 **실제로 눌러** 들어갑니다. 화면 전환이 클릭으로
	# 되는지를 매번 확인하는 셈입니다. 뒤로가기 단추는 아래에서 따로 검사합니다.
	_go(S.HOME)
	_hit(_menu_rect(maxi(MENU.find(s), 0)))

func _press(code: int) -> void:
	# 키 하나를 눌러 봅니다. **클릭만 검사하면 키 쪽 분기가 조용히 어긋납니다** —
	# 스카우트의 Enter 가 언제나 선수 팩을 뽑던 것이 그렇게 오래 숨어 있었습니다.
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _pos_unique() -> bool:
	var seen := {}
	for i in range(D.LINEUP):
		var p := str(Sv.lineup_pos[i])
		if seen.has(p):
			return false
		seen[p] = true
	return true

func _hit_dbl(r: Rect2) -> void:
	# 더블클릭 시늉. Godot 이 `double_click` 을 이벤트에 실어 주므로 그걸 씁니다 —
	# 시간을 재서 직접 판정하면 검사와 실제 동작이 다른 길을 타게 됩니다.
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = true
	e.position = r.position + r.size * 0.5
	Input.parse_input_event(e)

func _pool_no_dup_name() -> bool:
	var taken := {}
	for g in ORDER_GROUPS:
		for i in range(_group_count(str(g))):
			var c := DB.find(_slot_id(str(g), i))
			if not c.is_empty():
				taken[str(c.get("name", ""))] = true
	for c in pool:
		if taken.has(str(c.get("name", ""))):
			return false
	return true

func _ok(name: String, cond: bool) -> void:
	print("  %s %s" % ["OK  " if cond else "실패", name])
	if not cond:
		_ct_fail += 1

# 화면마다 클릭 하나씩 눌러 보고 상태가 바뀌었는지 봅니다.
# **입력은 다음 프레임에 처리됩니다** — 누른 직후에 읽으면 안 바뀐 것처럼 보입니다.
# 그래서 한 걸음에 네 프레임씩 씁니다.
func _click_test_step() -> void:
	_ct += 1
	@warning_ignore("integer_division")
	var step := _ct / 4
	if _ct % 4 != 0:
		return
	match step:
		1:
			# **먼저 세이브를 비웁니다.** 검사가 카드를 뽑고 시즌을 시작하므로,
			# 안 비우면 두 번째 판이 다른 상태에서 시작해 결과가 달라집니다
			# (실제로 이어서 돌렸더니 한 항목이 실패했습니다).
			Sv.reset()
			_demo_fill()
			_refilter()
			_refresh_study()
			print("mouse_filter=%d (0=STOP 1=PASS 2=IGNORE)" % mouse_filter)
			_hit_menu(S.ORDER)
		2:
			_ok("메뉴 클릭 → 작전", screen == S.ORDER)
			# **팀컬러 창을 한 번도 안 열었어도** 목록이 채워져 있어야 합니다.
			# 예전에는 창을 그릴 때만 채워서, 25칸을 다 맞췄는데도 단추에
			# "켤 수 있는 것이 없습니다"가 떴습니다.
			_ok("작전에 들어가면 팀컬러 목록이 채워짐",
				Sim.team_from_save(D.MY_TEAM)["colors"].is_empty() or not color_list.is_empty())
			_hit(_slot_rect("lineup", 0))
		3:
			# 든 칸을 누르면 끌기가 시작되고, 다른 칸에 놓으면 맞바뀝니다.
			_ok("든 오더 칸 누르면 끌기 시작", _slot_id("lineup", 0) == "" or drag_slot == "lineup")
			_ct_a = _slot_id("lineup", 0)
			_ct_b = _slot_id("lineup", 2)
			_release(_slot_rect("lineup", 2))
		4:
			_ok("다른 칸에 놓으면 맞바뀜",
				_ct_a == "" or (_slot_id("lineup", 2) == _ct_a and _slot_id("lineup", 0) == _ct_b))
			_hit(_order_tab_rect(1))
		5:
			_ok("오더 투수 탭", order_tab == 1 and sel_group == "rot")
			_hit(_order_tab_rect(0))
		6:
			_ok("오더 타자 탭", order_tab == 0 and sel_group == "lineup")
			_ct_a = str(Sv.lineup_pos[0])
			_hit(_pos_rect(0))
		7:
			_ok("수비 위치 누르면 목록이 펼쳐짐", pos_open == 0)
			# 지금 자리가 아닌 것을 골라야 바뀐 걸 알 수 있습니다.
			var pj := 0
			for k in range(D.POS.size()):
				if str(D.POS[k]) != _ct_a:
					pj = k
					break
			_ct_b = str(D.POS[pj])
			_hit(_pos_item_rect(0, pj))
		8:
			_ok("목록에서 고르면 수비 위치가 바뀜",
				str(Sv.lineup_pos[0]) == _ct_b and pos_open == -1)
			# **수비 위치는 유일해야 합니다** — 남이 맡은 자리를 고르면 맞바뀌고,
			# 아홉 자리가 하나씩 온전히 나뉘어 있어야 합니다.
			_ok("수비 위치가 겹치지 않음", _pos_unique())
			# 배치선수 **우클릭 = 큰 화면**.
			_ct_b = _slot_id("lineup", 1)
			_hit(_slot_rect("lineup", 1), true)
		9:
			_ok("타자 칸 우클릭 → 큰 화면",
				_ct_b == "" or not detail.is_empty())
			detail = {}
			# 배치선수 **더블클릭 = 자리 비우기**.
			_hit_dbl(_slot_rect("lineup", 1))
		10:
			_ok("타자 칸 더블클릭 → 자리가 비워짐",
				_slot_id("lineup", 1) == "" and detail.is_empty())
			_set_slot("lineup", 1, _ct_b)   # 뒤 검사가 아홉 명을 쓰므로 되돌립니다
			# **투수 탭도 같이 봅니다** — 탭마다 칸 자리가 달라서 한쪽만 맞을 수 있습니다.
			order_tab = 1
			sel_group = "rot"
			_ct_a = _slot_id("rot", 0)
			_hit(_slot_rect("rot", 0), true)
		11:
			_ok("투수 칸 우클릭 → 큰 화면", _ct_a == "" or not detail.is_empty())
			detail = {}
			_hit_dbl(_slot_rect("rot", 0))
		12:
			_ok("투수 칸 더블클릭 → 자리가 비워짐",
				_slot_id("rot", 0) == "" and detail.is_empty())
			_set_slot("rot", 0, _ct_a)
			order_tab = 0
			sel_group = "lineup"
			_set_slot("lineup", 0, "")
			_hit(_slot_rect("lineup", 0))
		13:
			_ok("빈 오더 칸 클릭 → 그 칸이 골라짐", sel_group == "lineup" and sel_idx == 0)
			_hit(_pool_chip_rect(0))
		14:
			_ok("보유선수 거르개 누르면 목록이 펼쳐짐", combo_i == 0)
			_hit(_pool_combo_item_rect(0, 1))
		15:
			_ok("거르개 목록에서 구단 고름", p_team != "" and combo_i == -1)
			p_team = ""
			_refresh_pool()
		16:
			# 보유선수를 누르면 **고른 칸에 바로** 들어가야 합니다.
			_ct_a = _slot_id("lineup", 0)
			if not pool.is_empty():
				_hit(_pool_cell(0))
		17:
			_ok("보유선수 클릭 → 고른 칸이 채워짐",
				pool.is_empty() or (_slot_id("lineup", 0) != "" and _slot_id("lineup", 0) != _ct_a))
			# **같은 이름은 보유선수에서 빠집니다** — 한 사람이 타순에 두 번 설 수는
			# 없습니다. 배치된 카드와 이름이 겹치는 카드가 목록에 남아 있으면 안 됩니다.
			_ok("배치된 선수와 같은 이름은 목록에 없음", _pool_no_dup_name())
			_hit(_color_btn_rect())
		18:
			_ok("팀컬러 단추 → 팀컬러 페이지", order_tab == TAB_COLOR)
			# **켤 수 있는 것이 목록 맨 위**로 옵니다. 첫 줄을 눌러 켜 봅니다.
			_ok("팀컬러 목록에 못 켠 것도 나옴", color_all.size() > color_list.size())
			_hit(_color_row_rect(0))
		19:
			_ok("팀컬러 클릭 → 켜짐", color_list.is_empty() or Sv.color_id != "")
			order_tab = 0
			_hit(_back_rect())
		20:
			_ok("뒤로가기 단추 → 홈", screen == S.HOME)
			_hit_menu(S.SCOUT)
		21:
			_ok("메뉴 클릭 → 스카우트", screen == S.SCOUT)
			_hit(_pack_rect(0))
		22:
			_ok("선수 팩 클릭 → %d장" % D.PACK_SIZE, pack.size() == D.PACK_SIZE)
			# **코인을 블록 값에 딱 맞춰 둡니다.** 선수 팩은 못 살 만큼만 남기므로,
			# 블록이 뽑혔다면 그 누름이 **블록 팩으로 갔다는 증거**가 됩니다.
			Sv.coins = Gr.DRAW_COST
			_hit(_pack_rect(1))
		23:
			_ok("블록 팩 클릭 → 블록 %d개" % Gr.DRAW_SIZE, block_pack.size() == Gr.DRAW_SIZE)
			# **키로도 고른 팩이 뽑혀야 합니다.** 예전에는 Enter 가 언제나 선수 팩을
			# 뽑아서, 블록을 뽑으려던 사람에게 "코인이 모자랍니다"가 떴습니다.
			block_pack.clear()
			Sv.coins = Gr.DRAW_COST
			pack_i = 1
			_press(KEY_ENTER)
		24:
			_ok("[Enter] 가 고른 팩을 뽑음", block_pack.size() == Gr.DRAW_SIZE)
			Sv.coins = 50000
			_hit_menu(S.STUDY)
		25:
			_ok("메뉴 클릭 → 구단관리", screen == S.STUDY)
			# 유학 갈래에서 지역을 누르면 **확인 창**이 떠야 합니다 — 바로 보내면
			# 잘못 눌렀을 때 되돌릴 방법이 없습니다.
			grow_tab = 0
			_hit(_region_rect(0))
		26:
			_ok("유학 지역 클릭 → 확인 창", study_modal == 0)
			_hit(_study_cancel_rect())
		27:
			_ok("확인 창 취소", study_modal == -1)
			_hit(_study_chip_rect(0))
		28:
			_ok("구단관리 거르개 펼침", combo_i == 0)
			_hit(_study_combo_item_rect(0, 0))
		29:
			_ok("거르개 목록에서 고름", combo_i == -1)
			_hit(_grow_tab_rect(1))
		30:
			_ok("구단관리 갈래 → 스킬블록", grow_tab == 1)
			# 뽑은 블록이 이 카드 종류에 맞아야 가방에 뜹니다. 맞는 카드를 고릅니다.
			for i in range(study_list.size()):
				if not _bag_list(DB.find(DB.card_id(study_list[i]))).is_empty():
					study_i = i
					break
			_hit(_study_cell(study_i))
		31:
			_ok("구단관리 카드 격자 클릭", not study_list.is_empty())
			# 블록을 가방에서 집어 판에 떨굽니다 — **드래그가 실제로 되는지**
			# 보는 유일한 길입니다.
			_hit(_bag_rect(0))
		32:
			_ok("가방 블록 집기 → 드래그 시작", drag_uid >= 0)
			# 모양마다 들어가는 자리가 다르므로 **되는 자리를 찾아서** 떨굽니다.
			# 칸을 하나 박아 두면 I 자 블록이 뽑힌 판에서만 실패합니다.
			var cc := DB.find(_study_sel())
			var dest := 0
			for o in range(Gr.CELLS):
				if Gr.can_put(cc, drag_uid, o) == "":
					dest = o
					break
			_release(Art.cell_rect(_board_rect(), dest))
		33:
			var id := _study_sel()
			_ok("판에 떨구기 → 끼워짐", id != "" and not Gr.placed(id).is_empty())
			_hit_menu(S.DEX)
		34:
			_ok("메뉴 클릭 → 도감", screen == S.DEX)
			_hit(_grid_rect(3))
		36:
			# **한 화면에 다 보입니다** — 뒤집기가 없어졌으므로 구종/수비 · 기록 ·
			# 스킬블록 판이 전부 이 한 장에 그려집니다.
			_ok("도감 카드 클릭 → 큰 화면", dex_i == 3 and not detail.is_empty())
			_hit(Rect2(Vector2(6, 6), Vector2(4, 4)))
		39:
			_ok("큰 화면 닫기", detail.is_empty())
			_hit(_grid_rect(5), true)
		40:
			_ok("도감 카드 우클릭 → 큰 화면", not detail.is_empty())
			_hit(Rect2(Vector2(6, 6), Vector2(4, 4)), true)
		41:
			_ok("우클릭으로 닫기", detail.is_empty())
			_hit(_chip_rect(1, _body().position.x, _body().position.y))
		42:
			_ok("거르개 누르면 목록이 펼쳐짐", combo_i == 1)
			_hit(_combo_item_rect(1, _body().position.x, _body().position.y, 1))
		43:
			_ok("목록에서 고르면 걸림", f_team != "" and combo_i == -1)
			_hit_menu(S.GAME)
		44:
			_ok("메뉴 클릭 → 시즌", screen == S.GAME)
			_hit(_btn_rect(0))
		45:
			_ok("시즌 단추 → 시즌 시작", Sv.season > 0)
			print("클릭 검사 끝 — 실패 %d개" % _ct_fail)
			get_tree().quit(1 if _ct_fail > 0 else 0)

# ── 구단 목록 ──────────────────────────────────────────────────────────────

var _teams_cache: Array = []
var _pos_cache: Array = []

func _all_teams() -> Array:
	# 카드에 실제로 있는 구단만. 없는 구단을 목록에 두면 골라도 빈 화면이 됩니다.
	if not _teams_cache.is_empty():
		return _teams_cache
	var s := {}
	for c in DB.cards:
		s[str(c.get("team", ""))] = true
	_teams_cache = s.keys()
	_teams_cache.sort()
	return _teams_cache

func _cycle_team(d: int) -> void:
	var list: Array = [""]
	list.append_array(_all_teams())
	var i := list.find(f_team)
	f_team = str(list[posmod(i + d, list.size())])
	_refilter()

func _cycle_dex_chip(i: int, d: int) -> void:
	match i:
		0: _cycle_year(d)
		1: _cycle_team(d)
		2: _cycle_grade(d)
		3: _cycle_kind_dir(d)

func _cycle_kind_dir(d: int) -> void:
	var list := ["", "hitter", "pitcher"]
	var i := list.find(f_kind)
	f_kind = str(list[posmod(i + d, list.size())])
	_refilter()

# 고르기 창의 거르개를 키보드로 넘깁니다. **마우스만 두면 키보드로는 못 거릅니다** —
# 이 저장소에서 되풀이해 온 실수라 두 갈래를 늘 같이 채웁니다.
func _cycle_pick_filter(i: int, d: int) -> void:
	var list := _pick_chips()
	if i < 0 or i >= list.size():
		return
	var opts: Array = (list[i] as Array)[2]
	var cur = (list[i] as Array)[3]
	var k := 0
	for j in range(opts.size()):
		if (opts[j] as Array)[1] == cur:
			k = j
			break
	_set_pick_filter(i, (opts[posmod(k + d, opts.size())] as Array)[1])
