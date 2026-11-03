extends Control
# 푸야매 — 화면 전환과 그리기.
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
	return str(MENU_NAME[i]) if i >= 0 else "푸야매"



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
# 도감 이름 검색.
var dex_q := ""
var dex_focus := false
var _t := 0.0          # 커서 깜빡임용 시계
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
# 그 큰 화면이 **도감에서 열린 것인가**. 도감은 성장(유학 · 스킬블록 · 팀컬러)을
# 통째로 감추고 기본 능력치만 보여 줍니다 — 아래 `_open_detail` 설명 참고.
var detail_raw := false

# 스킬블록 드래그. `drag_uid` 가 -1 이 아니면 끌고 있는 중입니다.
# **끌고 있는 자리는 매 프레임 갱신**해야 미리보기가 손끝을 따라옵니다.
var drag_uid := -1
var drag_pos := Vector2.ZERO

# 마우스가 마지막으로 지나간 자리. 스킬블록 화면의 설명 풍선이 이걸 봅니다 —
# 칸에 마우스를 올리면 **그 블록이 스텟을 정확히 얼마 올려 주는지** 뜹니다.
# 판에는 조각 색만, 가방 칸에는 이름과 값만 보이므로 "이걸 빼면 카드가 얼마나
# 약해지는가"는 풍선이 아니면 알 길이 없습니다.
var hover_pos := Vector2(-9999, -9999)

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
# ── 뽑기 결과 모달 ─────────────────────────────────────────────────────────
# **뽑은 것은 화면 아래가 아니라 모달로 보여 줍니다.** 아래에 깔면 팩 칸과 결과가
# 한 화면에서 자리를 다투고(카드 열 장이면 화면을 꽉 채웁니다), "무엇을 뽑았나"가
# 한눈에 안 들어옵니다. 그리고 **뽑기는 이 게임에서 제일 기분 좋은 순간**이라
# 연출이 붙을 자리이기도 합니다.
#
# `pack_t` 는 연 뒤 흐른 시간입니다 — 카드가 하나씩 열리고 연출이 그 위에 얹힙니다.
# 아무 데나 누르면 **먼저 전부 펼치고**, 다 펼쳐진 뒤에 누르면 닫힙니다
# (한 번에 닫히면 연출을 건너뛰려다 결과를 못 보고 닫습니다).
var pack_open := false
var pack_t := 0.0
# 구단 지명 팩에서 고른 구단(계보 목록의 번호)과, 그 고르개가 펼쳐져 있는지.
# **팩 목록에 콤보를 하나 두는 것이라 `combo_i` 와 따로 셉니다** — 같이 쓰면
# 도감 거르개를 열 때 이것도 같이 열립니다.
var pack_team_i := 0
var pack_team_open := false

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
# 구단관리 거르개 — **작전의 보유선수 거르개와 같은 넷**입니다(구단·시즌·포지션·코스트).
# 화면마다 다른 거르개를 두면 같은 "내 카드 목록"인데 찾는 방법이 달라집니다.
var g_cost := 0
var g_team := ""
var g_year := 0
var g_pos := ""
# 블록 가방 거르개 — 어느 스텟을 올려 주는 블록인가.
var g_bst := ""
# 가방 모양 거르개("" = 전체). 스텟과 **따로** 겁니다 — 둘을 같이 걸면
# "교타를 올리는 ㄴ 형" 처럼 판의 빈 자리에 맞춰 좁힐 수 있습니다.
var g_bsh := ""
var bag_scroll := 0
# 펼친 가방 거르개 번호(-1 = 닫힘). **`combo_i` 와 따로 셉니다** — 같이 쓰면
# 카드 거르개를 열 때 이것도 같이 열립니다.
var bag_i := -1
var study_modal := -1        # -1 = 안 뜸, 아니면 그 지역 번호
var grow_tab := 0            # 0 유학 · 1 스킬블록 · 2 구종

# 경기
var last_game: Dictionary = {}

# 자리 배치 확인용: run.bat -- --shot=out.png
# **캡처는 hdr_2d 때문에 실제보다 훨씬 어둡습니다.** 밝기 말고 자리만 보세요.
var _shot := ""
var _shot_wait := 0
var _want_play := false
var _want_pack := ""
var _want_packt := -1.0
var _want_packtier := 0
var _want_scroll := 0.0
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
		elif a.begins_with("--difftest"):
			var dn := 400
			if "=" in a:
				dn = int(a.split("=")[1])
			_diff_test(dn)
			get_tree().quit()
			return
		elif a == "--blocktest":
			_block_test()
		elif a.begins_with("--studymodal="):
			study_modal = int(a.split("=")[1])
		elif a.begins_with("--ordertab="):
			order_tab = int(a.split("=")[1])
		elif a.begins_with("--posopen="):
			pos_open = int(a.split("=")[1])
		elif a.begins_with("--growtab="):
			grow_tab = clampi(int(a.split("=")[1]), 0, _grow_tabs().size() - 1)
		elif a.begins_with("--hover="):
			# 확인용 — 설명 풍선은 마우스 자리를 보므로, 캡처로 보려면 마우스를
			# 그 자리에 놓아 줘야 합니다(`--hover=740,300`).
			var xy := a.substr(8).split(",")
			if xy.size() == 2:
				hover_pos = Vector2(float(xy[0]), float(xy[1]))
		elif a.begins_with("--scroll="):
			# 확인용 — 스크롤한 상태를 캡처할 방법이 없으면 "목록만 움직이는가" 를
			# 눈으로 못 봅니다.
			_want_scroll = float(a.split("=")[1])
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
			grow_tab = clampi(int(a.split("=")[1]), 0, _grow_tabs().size() - 1)
		elif a.begins_with("--packtier="):
			# 확인용 — 그 COST 카드로 채운 팩을 억지로 만들어 **등급별 연출을
			# 나란히 비교**합니다. 뽑기는 무작위라 7·8·9·10 을 각각 보려면
			# 이것 말고는 방법이 없습니다.
			_want_packtier = int(a.split("=")[1])
		elif a.begins_with("--packt="):
			# 확인용 — 뽑기 연출은 시간에 따라 달라지므로, 캡처하려면 그 시각으로
			# 감아 둬야 합니다(`--pack=team --packt=1.4`).
			_want_packt = float(a.split("=")[1])
		elif a.begins_with("--bagopen="):
			# 확인용 — 가방 거르개(0 = 올리는 스텟 · 1 = 모양)를 펼친 채로 캡처합니다.
			bag_i = int(a.split("=")[1])
		elif a == "--teamopen":
			# 확인용 — 구단 고르개를 펼친 채로 캡처합니다(`--posopen=` 과 같은 자리).
			pack_team_open = true
		elif a.begins_with("--pack"):
			# 확인용 — `--pack` 은 선수 팩, `--pack=team` · `--pack=block` 은 그 팩을
			# 뽑은 화면을 캡처하려고 씁니다(결과 자리 배치를 눈으로 봐야 합니다).
			_want_pack = a.split("=")[1] if "=" in a else "player"
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
	if _want_packtier > 0:
		pack.clear()
		block_pack.clear()
		for c in DB.cards:
			if int(c.get("cost", 1)) == _want_packtier:
				pack.append(c)
			if pack.size() >= D.PACK_SIZE:
				break
		_open_pack_modal()
	elif _want_pack != "":
		_draw_pack_now(_pack_of(_want_pack))
	if pack_open and _want_packt >= 0.0:
		pack_t = _want_packt
	if _want_scroll > 0.0:
		dex_scroll = minf(_want_scroll, _max_scroll())
		study_scroll = minf(_want_scroll, _study_max_scroll())
		pool_scroll = minf(_want_scroll, _pool_max_scroll())
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
		# **끼운 뒤에 자란 카드로 다시 엽니다.** 위에서 `dex` 의 원본을 그대로
		# 넣었으므로, 다시 안 잡으면 블록을 껴 놓고도 `+N` 이 하나도 안 보입니다.
		_open_detail(detail)
	if _want_play:
		_do_game()
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if pack_open:
		pack_t += dt
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
	Sv.study_done[id] = [D.abroad_for("pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter")[0]]
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

# `run.bat -- --difftest` — **난이도 기준선**. 다섯 갈래의 덱을 만들어 월드 시리즈
# 중간권 AI 와 붙입니다. 팀컬러·`D.TIERS`·`D.TIER_AI_BOOST`·변환 수치를 만졌으면
# 여기부터 다시 재세요. 목표는 CLAUDE.md 에 적어 둔 다음 관계입니다:
#
#   단일팀 블록+유학 ≈ 단일연도 블록+유학 ≈ 왕조최약 **블록만** ≈ 50%
#
# 왕조는 성장을 덜 하고도 남들과 대등해야 합니다 — 그게 왕조의 값어치입니다.
#
# `lv` 는 성장 단계입니다: 0 = 없음 · 1 = 스킬블록 · 2 = 블록 + 유학.
func _dt_grow(c: Dictionary, lv: int) -> Dictionary:
	var g: Dictionary = c.duplicate(true)
	if lv <= 0:
		return g
	var st: Dictionary = g["st"]
	var p := str(g.get("kind", "")) == "pitcher"
	var k1 := "stuff" if p else "contact"
	if lv >= 2:
		st[k1] = clampi(int(st.get(k1, 50)) + D.AB_UP, 1, D.STAT_MAX)   # 유학
	for k in (["stuff", "control"] if p else ["contact", "power"]):
		st[k] = clampi(int(st.get(k, 50)) + 7, 1, D.STAT_MAX)           # 스킬블록
	return g

# 주어진 카드 풀에서 COST 상한 안의 덱을 짭니다.
# **상한 안에서 시작해 올립니다** — 좋은 것부터 담고 나중에 깎으면 못 깎는 자리
# 하나에서 막혀 상한을 넘긴 채로 끝납니다.
func _dt_deck(nm: String, pool: Array, cap: int, lv: int) -> Dictionary:
	var slots: Array = []
	for i in range(D.LINEUP):
		slots.append({"w": str(D.POS[i]), "p": false})
	for i in range(D.BENCH):
		slots.append({"w": "", "p": false})
	for i in range(D.ROT + D.RELIEF + 2):
		slots.append({"w": "", "p": true})
	var fits := func(s: Dictionary, c: Dictionary) -> bool:
		if (str(c.get("kind", "")) == "pitcher") != bool(s["p"]):
			return false
		var w := str(s["w"])
		return w == "" or w == "지명타자" or str(c.get("pos", "")) == w
	var pick: Array = []
	var used := {}
	for s in slots:
		var best := -1
		for j in range(pool.size()):
			if used.has(j) or not fits.call(s, pool[j]):
				continue
			if best < 0 or int((pool[j] as Dictionary).get("cost", 99)) < int((pool[best] as Dictionary).get("cost", 99)):
				best = j
		if best < 0:
			for j in range(pool.size()):
				if not used.has(j) and (str((pool[j] as Dictionary).get("kind", "")) == "pitcher") == bool(s["p"]):
					best = j
					break
		if best < 0:
			return {}
		used[best] = true
		pick.append(best)
	var total := 0
	for j in pick:
		total += int((pool[j] as Dictionary).get("cost", 1))
	while true:
		var bi := -1
		var bj := -1
		var bg := 0.0
		for i in range(slots.size()):
			var cur: Dictionary = pool[pick[i]]
			for j in range(pool.size()):
				if used.has(j) or not fits.call(slots[i], pool[j]):
					continue
				var c: Dictionary = pool[j]
				var dc := int(c.get("cost", 1)) - int(cur.get("cost", 1))
				var dv := float(c.get("ov", 0)) - float(cur.get("ov", 0))
				if dv <= 0.0 or total + dc > cap:
					continue
				var g := dv / maxf(1.0, float(dc))
				if g > bg:
					bg = g
					bi = i
					bj = j
		if bi < 0:
			break
		total += int((pool[bj] as Dictionary).get("cost", 1)) - int((pool[pick[bi]] as Dictionary).get("cost", 1))
		used.erase(pick[bi])
		used[bj] = true
		pick[bi] = bj
	var t := {"name": nm, "lineup": [], "pos": [], "bench": [], "rot": [],
		"relief": [], "setup": {}, "closer": {}, "rot_i": 0, "_cost": total}
	for i in range(slots.size()):
		var g := _dt_grow(pool[pick[i]], lv)
		if i < D.LINEUP:
			t["lineup"].append(g)
			t["pos"].append(str(D.POS[i]))
		elif i < D.LINEUP + D.BENCH:
			t["bench"].append(g)
		elif i < D.LINEUP + D.BENCH + D.ROT:
			t["rot"].append(g)
		elif i < D.LINEUP + D.BENCH + D.ROT + D.RELIEF:
			t["relief"].append(g)
		elif (t["setup"] as Dictionary).is_empty():
			t["setup"] = g
		else:
			t["closer"] = g
	# 선발은 좋은 순서대로 — 무작위로 두면 1선발과 5선발을 나눌 이유가 없어집니다.
	(t["rot"] as Array).sort_custom(func(x, y): return int(x.get("ov", 0)) > int(y.get("ov", 0)))
	Sim.apply_color(t, [], true)
	return t

func _diff_test(n: int) -> void:
	if DB.cards.is_empty():
		print("카드가 없습니다 — convert.bat 을 먼저 돌리세요.")
		return
	var by := func(tm: String, y: int) -> Array:
		var pl: Array = []
		for c in DB.cards:
			if tm != "" and str(c.get("team", "")) != tm:
				continue
			if y > 0 and int(c.get("year", 0)) != y:
				continue
			pl.append(c)
		return pl
	var decks := [
		_dt_deck("단일팀 블록+유학", by.call("두산", 0), D.COST_CAP, 2),
		_dt_deck("단일팀 삼성 블록+유학", by.call("삼성", 0), D.COST_CAP, 2),
		_dt_deck("단일연도 블록+유학", by.call("", 2020), D.COST_CAP, 2),
		_dt_deck("단일연도03 블록+유학", by.call("", 2003), D.COST_CAP, 2),
		_dt_deck("단일팀 블록만", by.call("두산", 0), D.COST_CAP, 1),
		_dt_deck("단일연도 블록만", by.call("", 2020), D.COST_CAP, 1),
		_dt_deck("왕조최약 블록만", by.call("롯데", 2003), D.COST_CAP, 1),
		_dt_deck("왕조최약 블록+유학", by.call("롯데", 2003), D.COST_CAP, 2),
		_dt_deck("왕조최강 블록만", by.call("삼성", 2015), D.COST_CAP, 1),
		_dt_deck("왕조최강 블록+유학", by.call("삼성", 2015), D.COST_CAP, 2),
	]
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = 999
	var ai := Sim.build_ai("월드AI중간", D.tier_ov(4) + int(D.LEAGUE_SPREAD[4]), rng0, -1, D.ai_boost(4))
	print("난이도 기준선 — 월드 시리즈 중간권 AI 상대 (%d경기)" % n)
	for i in range(decks.size()):
		var t: Dictionary = decks[i]
		if t.is_empty():
			continue
		# **덱마다 씨앗을 다시 박습니다.** 난수열 하나를 순서대로 나눠 쓰면 덱을
		# 하나 넣고 빼는 것만으로 뒤쪽 덱의 수치가 통째로 움직여서, 두 번의 측정을
		# 비교할 수가 없습니다(실제로 같은 설정에서 59.2% 와 51.9% 가 나왔습니다).
		var rng := RandomNumberGenerator.new()
		rng.seed = 31337
		var w := 0
		var l := 0
		for k in range(n):
			# 홈·원정을 번갈아야 자리 이점이 안 섞입니다.
			var g := Sim.play(t, ai, rng) if k % 2 == 0 else Sim.play(ai, t, rng)
			if int(g["winner"]) < 0:
				continue
			if (int(g["winner"]) == 0) == (k % 2 == 0):
				w += 1
			else:
				l += 1
		var picks: Array = t.get("picks", [])
		var cl := ""
		var chb := 0
		var cpb := 0
		for e in picks:
			cl += ("+" if cl != "" else "") + str((e as Dictionary)["name"])
			chb += int((e as Dictionary)["hit"])
			cpb += int((e as Dictionary)["pit"])
		var ovs := 0.0
		var cnt := 0
		for c in (t["lineup"] as Array) + (t["rot"] as Array) + (t["relief"] as Array):
			ovs += float((c as Dictionary).get("ov", 0))
			cnt += 1
		print("  %-18s COST %3d · OV %.1f · %s = +%d/+%d — %.1f%%" % [
			str(t["name"]), int(t["_cost"]), ovs / maxf(1.0, float(cnt)),
			(cl if cl != "" else "없음"), chb, cpb,
			100.0 * w / maxf(1.0, float(w + l))])

	# ── 덱끼리 ──
	# **지켜야 할 순서: 왕조 최약(블록만) > 단일팀·단일연도(블록+유학).**
	# 좁은 풀에서 25명을 채우는 대가가 제일 큰 팀컬러로 갚아지는지를 봅니다.
	# **덱은 이름으로 찾습니다** — 번호로 적으면 위 목록에 한 줄 더할 때마다
	# 조용히 엉뚱한 덱끼리 붙습니다(실제로 그랬습니다).
	var find := func(nm: String) -> Dictionary:
		for e in decks:
			if str((e as Dictionary).get("name", "")) == nm:
				return e
		return {}
	print("덱끼리 맞대결 (%d경기)" % n)
	for pair in [["왕조최약 블록+유학", "단일팀 블록만"],
			["왕조최약 블록+유학", "단일연도 블록만"],
			["왕조최약 블록+유학", "단일팀 블록+유학"],
			["왕조최약 블록+유학", "단일연도 블록+유학"],
			["왕조최약 블록만", "단일팀 블록+유학"],
			["왕조최약 블록만", "단일연도 블록+유학"],
			["단일연도 블록+유학", "단일팀 블록+유학"]]:
		var a: Dictionary = find.call(str(pair[0]))
		var b: Dictionary = find.call(str(pair[1]))
		if a.is_empty() or b.is_empty():
			continue
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 4242
		var w2 := 0
		var l2 := 0
		for k in range(n):
			var g := Sim.play(a, b, rng2) if k % 2 == 0 else Sim.play(b, a, rng2)
			if int(g["winner"]) < 0:
				continue
			if (int(g["winner"]) == 0) == (k % 2 == 0):
				w2 += 1
			else:
				l2 += 1
		print("  %-18s vs %-18s — %.1f%%" % [str(a["name"]), str(b["name"]),
			100.0 * w2 / maxf(1.0, float(w2 + l2))])

	# ── 라운드로빈 ──
	# 네 갈래를 **서로** 붙입니다. AI 상대 승률만 보면 "누가 제일 센가" 를 알 수
	# 없습니다 — 셋이 모두 50% 라도 서로 물고 물릴 수 있습니다.
	# **왕조는 제일 약한 것과 제일 센 것을 같이 넣습니다** — 하나만 넣으면 왕조가
	# 통째로 세다/약하다로 읽히는데, 실제로는 구단·시즌에 따라 폭이 있습니다.
	var rr: Array = [find.call("왕조최약 블록+유학"), find.call("왕조최강 블록+유학"),
		ai, find.call("단일팀 블록+유학"), find.call("단일연도 블록+유학")]
	var nm := ["왕조최약", "왕조최강", "월드AI", "단일구단", "단일연도"]
	var cnt2 := rr.size()
	var tot: Array = []
	var dec: Array = []       # 무승부를 뺀 실제 경기 수
	var cell: Array = []
	for i in range(cnt2):
		tot.append(0)
		dec.append(0)
		var rowc: Array = []
		for j in range(cnt2):
			rowc.append(-1.0)
		cell.append(rowc)
	for i in range(cnt2):
		for j in range(i + 1, cnt2):
			var b2: Dictionary = rr[j]
			var a2: Dictionary = rr[i]
			if a2.is_empty() or b2.is_empty():
				continue
			var rng3 := RandomNumberGenerator.new()
			rng3.seed = 777
			var wi := 0
			var wj := 0
			for k in range(n):
				var g := Sim.play(a2, b2, rng3) if k % 2 == 0 else Sim.play(b2, a2, rng3)
				if int(g["winner"]) < 0:
					continue
				if (int(g["winner"]) == 0) == (k % 2 == 0):
					wi += 1
				else:
					wj += 1
			var p := 100.0 * wi / maxf(1.0, float(wi + wj))
			cell[i][j] = p
			cell[j][i] = 100.0 - p
			tot[i] += wi
			tot[j] += wj
			dec[i] += wi + wj
			dec[j] += wi + wj
	print("라운드로빈 — %d갈래가 서로 (%d경기씩)" % [cnt2, n])
	var hd := "            "
	for j in range(cnt2):
		hd += "%10s" % nm[j]
	print(hd + "%10s" % "종합")
	for i in range(cnt2):
		var row := "  %-10s" % nm[i]
		for j in range(cnt2):
			row += "%10s" % ("—" if i == j else "%.1f%%" % float(cell[i][j]))
		print(row + "%9.1f%%" % (100.0 * tot[i] / maxf(1.0, float(dec[i]))))

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
	Sim.apply_color(t, [], true)
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
		fail += _expect_tier("한 구단+한 시즌 25명",
			{"왕조": "S", "단일구단": "A", "단일연도": "A"})
		# 한 명만 빼면 셋 다 **A 에서 B 로** 내려가야 합니다 —
		# 계단이라 꺼지지는 않지만 꼭대기 칸은 25명 전원이 조건입니다.
		Sv.bench[0] = ""
		fail += _expect_tier("24명", {"왕조": "A", "단일구단": "B", "단일연도": "B"})

	# ② 한 구단 · 여러 시즌 25명 → **단일팀만**. 왕조·단일연도는 꺼져야 합니다.
	var fk = _pick_bucket(by_fr, need, true)
	if fk == null:
		print("  실패 한 구단에서 여러 시즌 25명을 뽑을 조합이 없습니다")
		fail += 1
	else:
		_fill_order(_take_mixed(by_fr[fk], "year", 3), need)
		fail += _expect_tier("한 구단·여러 시즌 25명",
			{"단일구단": "A", "왕조": "", "단일연도": ""})

	# ③ 한 시즌 · 여러 구단 25명 → **단일연도만**.
	var yk = _pick_bucket(by_yr, need, true)
	if yk == null:
		print("  실패 한 시즌에서 여러 구단 25명을 뽑을 조합이 없습니다")
		fail += 1
	else:
		_fill_order(_take_mixed(by_yr[yk], "team", 4), need)
		fail += _expect_tier("한 시즌·여러 구단 25명",
			{"단일연도": "A", "왕조": "", "단일구단": ""})

	# ④ 두 구단이 절반씩 → **듀얼팀만**. 단일팀은 꺼져야 합니다.
	var two := _two_franchises(by_fr)
	if two.is_empty():
		print("  실패 듀얼팀을 만들 두 구단이 없습니다")
		fail += 1
	else:
		_fill_order(two, need)
		# 절반씩이면 한 구단이 12~13명이라 단일팀은 **C 로 켜집니다** — 그게 맞습니다.
		fail += _expect_tier("두 구단 절반씩",
			{"듀얼팀": "A", "단일구단": "C", "왕조": "", "단일연도": ""})

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

# 팀컬러가 **어느 등급으로** 켜졌는지 봅니다. 계단(C 10명 · B 20명 · A 25명)이
# 생기면서 "켜졌나/꺼졌나"만으로는 부족해졌습니다 — 24명이면 여전히 켜지되
# **B 여야** 하고, 그게 "25명을 다 채워야 A" 규칙의 알맹이입니다.
# `want` 는 {낱말: 등급}이고 등급 "" 는 아예 안 켜져야 한다는 뜻입니다.
func _expect_tier(what: String, want: Dictionary) -> int:
	var names := _color_names()
	var bad := 0
	for w in want:
		var wt := str(want[w])
		# **같은 컬러가 등급마다 한 줄씩 나오므로 제일 높은 것을 찾습니다.**
		# 첫 줄만 보면 목록 차례에 따라 답이 달라집니다.
		var rank := ["C", "B", "A", "S"]
		var got := ""
		for n in names:
			if not str(n).contains(str(w)):
				continue
			var parts := str(n).split(" ")
			var tg := str(parts[parts.size() - 1])
			if not (tg in rank):
				continue
			if got == "" or rank.find(tg) > rank.find(got):
				got = tg
		if got != wt:
			print("  실패 [%s] %s 는 %s 여야 하는데 %s — 켜진 것: %s" % [what, str(w),
				("꺼짐" if wt == "" else wt), ("꺼짐" if got == "" else got), str(names)])
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
	# **시작 네 칸이 카드마다 달라야 합니다.** 예전에는 전부 가운데 2×2 라
	# 어느 카드를 열어도 판이 똑같았습니다. 블록 모양 하나가 모서리에 붙습니다.
	var shapes_seen := {}
	var n_card := 0
	for c in DB.cards:
		n_card += 1
		if n_card > 400:
			break
		var sc: Array = Gr.start_cells(DB.card_id(c))
		if sc.size() != Gr.SHAPE_CELLS:
			print("  실패 시작 칸이 %d개입니다 — %s" % [sc.size(), DB.card_id(c)])
			fail += 1
			break
		var key := ""
		var sorted_sc: Array = sc.duplicate()
		sorted_sc.sort()
		for k in sorted_sc:
			key += "%d," % int(k)
		shapes_seen[key] = true
	# **블록을 끼우면 구종이 실제로 올라가는가.** 등급이 스텟을 따라가더라도
	# 화면이 낡은 사본을 보고 있으면 안 오르는 것처럼 보입니다 — `DB` 는 자란
	# 카드를 캐시하므로 블록을 넣은 뒤 `clear_cache()` 를 안 부르면 그대로입니다.
	var pv := {}
	# **판이 다 열린 카드로 잽니다.** 갓 뽑은 카드는 칸이 넷뿐이라 블록이 한 장밖에
	# 안 들어가고, 한 장(+3)으로는 계단(8~14)을 못 넘습니다 — 그건 설계대로입니다.
	for c in DB.cards:
		if str(c.get("kind", "")) != "pitcher" or str(c.get("grade", "")) != D.GRADE_EX:
			continue
		var pid := DB.card_id(c)
		var before := 0
		for p in Gr.pitches_of(DB.find(pid)):
			before += int(p["grade"])
		# 변화구를 올리는 블록을 판이 찰 때까지 끼워 봅니다. **한 장(+3)으로는
		# 계단(9)을 대개 못 넘습니다** — 몇 장이면 오르는지가 실제로 궁금한 값입니다.
		var used: Array = []
		var after := before
		var nb := 0
		for _try in range(4):
			Sv.blocks.append({"uid": Sv.block_uid, "sid": "grip", "shape": "ㅁ", "rot": 0})
			var buid := Sv.block_uid
			Sv.block_uid += 1
			var placed_ok := false
			for o in Gr.open_cells(DB.find(pid)):
				if Gr.put(DB.find(pid), buid, int(o)) == "":
					placed_ok = true
					used.append(buid)
					nb += 1
					break
			if not placed_ok:
				break
			after = 0
			for p in Gr.pitches_of(DB.find(pid)):
				after += int(p["grade"])
			if after > before:
				break
		if used.is_empty():
			continue
		pv = {"id": pid, "b": before, "a": after, "n": nb,
			"st": int((DB.find(pid)["st"] as Dictionary).get("breaking", 0))}
		for u in used:
			Gr.take(int(u))
		break
	if pv.is_empty():
		print("  실패 블록을 끼울 투수를 못 찾았습니다")
		fail += 1
	elif int(pv["a"]) <= int(pv["b"]):
		print("  실패 블록 %d장을 껴도 구종 등급이 안 오릅니다 (합 %d · 변화구 %d)" % [
			pv["n"], pv["b"], pv["st"]])
		fail += 1
	else:
		print("  OK   블록 %d장이면 구종 승급 (등급 합 %d → %d · 변화구 %d)" % [
			pv["n"], pv["b"], pv["a"], pv["st"]])

	# **구종은 스텟을 안 올리고, 스텟이 오르면 승급합니다.**
	var pit_c := {}
	for c in DB.cards:
		if str(c.get("kind", "")) == "pitcher":
			pit_c = c
			break
	if not pit_c.is_empty():
		var lo: Dictionary = pit_c.duplicate(true)
		var hi: Dictionary = pit_c.duplicate(true)
		for k in (hi["st"] as Dictionary):
			(hi["st"] as Dictionary)[k] = D.STAT_MAX
			(lo["st"] as Dictionary)[k] = 40
		var glo := 0
		var ghi := 0
		for p in Gr.pitches_of(lo):
			glo = maxi(glo, int(p["grade"]))
		for p in Gr.pitches_of(hi):
			ghi = maxi(ghi, int(p["grade"]))
		if ghi <= glo:
			print("  실패 스텟을 올려도 구종 등급이 안 오릅니다 (%d → %d)" % [glo, ghi])
			fail += 1
		else:
			print("  OK   스텟이 오르면 구종 승급 (%s → %s)" % [
				Gr.pitch_grade_name(glo), Gr.pitch_grade_name(ghi)])
		if Gr.has_method("pitch_bonus"):
			print("  실패 구종 보너스가 아직 남아 있습니다")
			fail += 1
		else:
			print("  OK   구종은 스텟을 안 올림")
	# **성장 세 갈래가 모두 구종 등급에 닿는가.** 유학·스킬블록은 `DB.find` 가
	# 카드에 얹지만 **팀컬러는 팀에 붙어서 카드에는 안 얹힙니다** — 그래서 그냥
	# 두면 작전에서 스텟이 올라도 구종이 그대로였습니다(실제로 그랬습니다).
	# 화면이 그 몫을 `extra` 로 넘겨 줍니다.
	var pc := {}
	for c in DB.cards:
		if str(c.get("kind", "")) != "pitcher":
			continue
		if int((c.get("st", {}) as Dictionary).get("velo", 0)) < 70:
			continue
		pc = c
		break
	if pc.is_empty():
		print("  실패 구종 검사에 쓸 투수를 못 찾았습니다")
		fail += 1
	else:
		var g0 := int((Gr.pitches_of(pc)[0] as Dictionary)["grade"])
		var g1 := int((Gr.pitches_of(pc, 12)[0] as Dictionary)["grade"])
		if g1 <= g0:
			print("  실패 팀컬러(+12)가 구종 등급에 안 닿습니다 (%s → %s)" % [
				Gr.pitch_grade_name(g0), Gr.pitch_grade_name(g1)])
			fail += 1
		else:
			print("  OK   팀컬러가 구종에 닿음 (%s → %s)" % [
				Gr.pitch_grade_name(g0), Gr.pitch_grade_name(g1)])
		# 유학은 `DB.find` 가 얹으므로 카드 자체가 자랍니다.
		var pid2 := DB.card_id(pc)
		Sv.study_done[pid2] = []
		var before2 := int((Gr.pitches_of(DB.find(pid2))[0] as Dictionary)["grade"])
		# 구속을 올리는 유학지를 찾아 보냅니다.
		# **유학지 id 는 표의 자리 번호입니다** — 항목에 `id` 칸이 따로 없습니다.
		for ri in range(D.ABROAD.size()):
			if str((D.ABROAD[ri] as Dictionary).get("stat", "")) == "velo":
				Sv.study_done[pid2] = [ri]
				break
		DB.clear_cache()
		var after2 := int((Gr.pitches_of(DB.find(pid2))[0] as Dictionary)["grade"])
		if after2 < before2:
			print("  실패 유학을 다녀왔는데 구종 등급이 내려갔습니다")
			fail += 1
		else:
			print("  OK   유학이 구종에 닿음 (%s → %s · 구속 %d)" % [
				Gr.pitch_grade_name(before2), Gr.pitch_grade_name(after2),
				int((DB.find(pid2)["st"] as Dictionary).get("velo", 0))])
		Sv.study_done.erase(pid2)
		DB.clear_cache()

	# **COST 별 구종 등급 분포.** 등급이 스텟 하나만 보므로, 코스트가 높아도
	# 그 구종이 기대는 칸이 낮으면 D 가 나옵니다 — 그 어긋남을 여기서 봅니다.
	var gsum := {}
	var gcnt := {}
	var gmin := {}
	var gmax := {}
	var npitch := {}
	for c in DB.cards:
		if str(c.get("kind", "")) != "pitcher":
			continue
		var ck := int(c.get("cost", 1))
		var ps := Gr.pitches_of(c)
		if ps.is_empty():
			continue
		npitch[ck] = int(npitch.get(ck, 0)) + ps.size()
		for p in ps:
			var gv := int(p["grade"])
			gsum[ck] = int(gsum.get(ck, 0)) + gv
			gcnt[ck] = int(gcnt.get(ck, 0)) + 1
			gmin[ck] = mini(int(gmin.get(ck, 9)), gv)
			gmax[ck] = maxi(int(gmax.get(ck, -1)), gv)
	print("  COST별 구종 — 평균등급 · 최저~최고 · 카드당 구종 수")
	for ck in range(1, 11):
		if not gcnt.has(ck):
			continue
		var nc := 0
		for c2 in DB.cards:
			if str(c2.get("kind", "")) == "pitcher" and int(c2.get("cost", 1)) == ck:
				nc += 1
		print("    C%-3d %.2f  %s~%s  구종 %.1f개" % [ck,
			float(gsum[ck]) / float(gcnt[ck]),
			Gr.pitch_grade_name(int(gmin[ck])), Gr.pitch_grade_name(int(gmax[ck])),
			float(npitch[ck]) / float(maxi(nc, 1))])
	if shapes_seen.size() < 6:
		print("  실패 시작 판이 %d가지뿐입니다 — 카드마다 달라야 합니다" % shapes_seen.size())
		fail += 1
	else:
		print("  OK   시작 판 %d가지" % shapes_seen.size())
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
	# **눈금은 카드의 OV 분포를 따라갑니다.** 지금 중앙값이 48 이고 최대가 93 이라,
	# 옛 눈금(55/70/85)의 85 는 상위 0.5% 뿐이어서 스물다섯 자리를 채우려면
	# `Sim._window` 가 창을 한참 넓혀야 합니다 — 그러면 "종합 85 팀" 이 아니라
	# "위에서부터 긁어모은 팀" 을 재게 됩니다.
	for ov in [48, 58, 68]:
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
	# **승률은 실제 리그 격차로 봅니다.** `D.LEAGUE_SPREAD` 의 폭이 최대 12 이므로
	# 게임 안에서 종합 30 차이는 나오지 않습니다 — 그 값만 보고 "너무 일방적"이라고
	# 판단하면 안 됩니다. 아래 표의 4·8·12 가 실제로 만나는 격차입니다.
	var base := 58
	# **격차마다 팀을 여러 벌 뽑아 평균 냅니다.** 한 벌로 재면 그 한 벌이 어떻게
	# 뽑혔느냐가 그대로 그 줄의 수치가 되어, 경기 수를 아무리 늘려도 사다리가
	# 울퉁불퉁합니다 — 실제로 차이 8 이 74.5% 인데 차이 12 가 67.0% 로 나왔습니다.
	const SIM_TEAMS := 8
	for gap in [4, 8, 12, 30]:
		var w := 0
		var l := 0
		var so := 0.0
		var wo := 0.0
		for t in range(SIM_TEAMS):
			var strong := Sim.build_ai("강", base + gap, r)
			var weak := Sim.build_ai("약", base, r)
			so += _team_ov(strong)
			wo += _team_ov(weak)
			@warning_ignore("integer_division")
			var per := n / SIM_TEAMS
			for i in range(per):
				# 홈·원정을 번갈아야 자리 이점이 안 섞입니다.
				var g := Sim.play(weak, strong, r) if i % 2 == 0 else Sim.play(strong, weak, r)
				if int(g["winner"]) < 0:
					continue
				if (int(g["winner"]) == 1) == (i % 2 == 0):
					w += 1
				else:
					l += 1
		print("종합 차이 %2d (목표 %d 대 %d · 실제 %.1f 대 %.1f) — 센 쪽 %.1f%% 승리" % [
			gap, base + gap, base, so / SIM_TEAMS, wo / SIM_TEAMS,
			100.0 * w / maxf(1.0, float(w + l))])

func _team_ov(t: Dictionary) -> float:
	# 출전하는 자리만 — 벤치는 경기에 안 나오므로 팀 세기가 아닙니다.
	var s := 0.0
	var n := 0
	for c in (t.get("lineup", []) as Array) + (t.get("rot", []) as Array) + \
			(t.get("relief", []) as Array):
		s += float((c as Dictionary).get("ov", 0))
		n += 1
	return s / maxf(1.0, float(n))

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
	# **블록도 넉넉히 쥐여 줍니다** — 가방이 비어 있으면 스킬블록 화면의 자리
	# 문제(넘침·겹침)를 캡처로 못 봅니다.
	Gr.draw_blocks(24)

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
		# **이름 검색은 부분 일치입니다** — "이승" 만 쳐도 이승엽이 나와야 합니다.
		if dex_q != "" and not str(c.get("name", "")).contains(dex_q):
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
		Art.txt(self, Vector2(PAD, PAD + 30.0), "푸야매", 26, P.TEXT)
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
	bag_i = -1
	pack_team_open = false
	# 화면을 넘기면 결과 창도 닫습니다 — 안 그러면 1~5 로 옮긴 화면 위에
	# 뽑기 결과가 그대로 떠 있습니다.
	pack_open = false
	bag_scroll = 0
	dex_focus = false
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

# ── 목록 프레임 ────────────────────────────────────────────────────────────
# **`_draw()` 에는 클리핑이 없습니다.** 스크롤한 카드는 목록 칸 밖으로 그대로
# 넘어가서, 위로는 거르개 · 탭 줄 · 제목 띠를 덮고 아래로는 화면 끝까지
# 그려집니다 — 스크롤할 때 목록이 아니라 화면 전체가 움직이는 것처럼 보입니다.
#
# **띠를 짧게 잡으면 소용이 없습니다.** 카드 한 장이 137px 인데 거르개 줄만큼
# (38px) 지우면 나머지 99px 가 제목 띠 위로 올라갑니다 — 구단관리에서 카드가
# 제목 옆에 떠 있던 것이 이것입니다. **카드가 닿을 수 있는 데까지** 지우세요.
#
# Godot 에서 진짜로 잘라내려면 `clip_contents` 를 켠 Control **자식**에 그려야
# 하는데, **자식은 부모보다 나중에 그려집니다** — 목록 위에 얹혀야 하는 것
# (거르개 펼친 목록 · 큰 화면 · 알림 · 끌고 있는 카드 · 설명 풍선)을 전부 세
# 번째 층으로 옮겨야 하고, 그러면 그리기 순서가 세 곳으로 흩어집니다. 그래서
# **카드를 먼저 그리고 넘친 자리를 지운 뒤 그 위에 얹히는 것을 다시 그립니다.**
# 눈에 보이는 결과는 클리핑과 같습니다.
#
# **목록의 x 범위만 지웁니다** — 화면 전체를 지우면 옆 판(구단관리의 선수 설명,
# 작전의 분석)까지 같이 날아갑니다.
# `frame` 은 목록을 담은 판입니다(있으면). 판 안쪽까지 지웠으면 판 바탕과
# 테두리를 되돌려야 합니다 — 안 그러면 목록 아래 여백만 바탕색이 되어
# 판이 중간에서 끊긴 것처럼 보입니다.
func _mask_list(a: Rect2, top: float, x: float, w: float, frame := Rect2()) -> void:
	if a.position.y > top:
		draw_rect(Rect2(x, top, w, a.position.y - top), P.BG, true)
	var bot := a.position.y + a.size.y
	if size.y > bot:
		draw_rect(Rect2(x, bot, w, size.y - bot), P.BG, true)
	if frame.size.y <= 0.0:
		return
	var fb := frame.position.y + frame.size.y
	if fb > bot:
		draw_rect(Rect2(frame.position.x, bot, frame.size.x, fb - bot),
			P.a(P.PANEL_HI, 0.32), true)
	draw_rect(frame, P.LINE, false, 1.0)

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
	_prune_colors()

func _prune_colors() -> void:
	# **오더가 바뀌어 조건이 깨진 팀컬러는 그 자리에서 끕니다.** 켜 둔 채로 두면
	# 화면에는 켜져 있는데 경기에는 안 붙습니다 — `Col.picked_many` 가 조건을
	# 만족한 것(`Col.active`) 중에서만 고르기 때문입니다. 그래서 선수 한 명을
	# 바꿔 25명 조건이 깨져도 단추에는 `왕조 S + 왕조 A` 가 그대로 남아 있었고,
	# 스텟도 안 붙는데 붙은 것처럼 보였습니다.
	#
	# **오더가 바뀌는 곳마다 따로 부르지 마세요** — 여기(`_refresh_pool`)를 오더가
	# 바뀌는 모든 곳이 이미 부르고 있습니다. 두 번째 통로를 만들면 한 곳을
	# 빠뜨렸을 때 조용히 옛 상태가 남습니다.
	if Sv.color_ids.is_empty():
		return
	var t := Sim.team_from_save(D.MY_TEAM)
	var ok := {}
	for e in (t.get("colors", []) as Array):
		ok[str((e as Dictionary)["id"])] = true
	var lost: Array = []
	for cid in Sv.color_ids:
		if not ok.has(str(cid)):
			lost.append(str(cid))
	if lost.is_empty():
		return
	# **무엇이 꺼졌는지 말합니다.** 말없이 끄면 약해진 이유를 알 수가 없습니다.
	var names: Array = []
	for e in Col.survey(Sim.playing_of(t), t.get("bench", [])):
		if lost.has(str((e as Dictionary)["id"])):
			names.append(str((e as Dictionary)["name"]))
	for cid in lost:
		Sv.color_ids.erase(cid)
	Sv.save_game()
	_say("팀컬러 꺼짐 — %s (오더가 바뀌어 조건이 깨졌습니다)"
		% (", ".join(names) if not names.is_empty() else "%d개" % lost.size()))

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
	# 여섯 줄이 들어가야 해서 줄 간격을 판 높이에 맞춥니다. 상수로 박으면
	# 유학지가 하나 늘 때마다 마지막 줄이 판 밖으로 나갑니다.
	var top := s.position.y + 206.0
	var gap := minf(62.0, maxf(34.0, (s.position.y + s.size.y - 12.0 - top) / 6.0))
	return Rect2(s.position.x + 10.0, top + i * gap, s.size.x - 20.0, gap - 6.0)

func _region_ids() -> Array:
	# **화면·클릭·키가 같이 보는 목록.** 고른 카드의 갈래에 맞는 지역만 냅니다 —
	# 타자에게 구위 유학을 보여 주면 눌러 보고 나서야 못 가는 곳인 줄 압니다.
	var c := DB.find(_study_sel())
	if c.is_empty():
		return []
	return D.abroad_for(str(c.get("kind", "hitter")))

# 구단관리의 거르개 — 원작의 `코스트 ▼` 자리입니다. 보유 카드가 수백 장이 되면
# 격자를 끝까지 굴려서 찾는 것이 일이 됩니다.
func _study_chip_rect(i: int) -> Rect2:
	# **칸 수는 거르개 개수에서 계산합니다** — 3 으로 박아 두었더니 넷으로 늘렸을 때
	# 네 번째 칩이 오른쪽 판 밑으로 잘렸습니다.
	var p := _study_panel()
	var n := maxi(_study_chips().size(), 1)
	var w := (p.size.x - 22.0) / float(n)
	return Rect2(p.position.x + 6.0 + i * (w + 2.0), p.position.y + 30.0, w - 4.0, CHIP_H)

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
	# **작전 보유선수와 같은 넷** — `_pick_chips` 와 나란히 두고 보세요.
	return [
		["구단", "전체" if g_team == "" else g_team, _opts_team(), g_team],
		["시즌", "전체" if g_year == 0 else str(g_year), _opts_year(), g_year],
		["포지션", "전체" if g_pos == "" else str(D.POS_SHORT.get(g_pos, g_pos)), _opts_pos(), g_pos],
		["코스트", "전체" if g_cost == 0 else str(g_cost), _opts_cost(), g_cost],
	]

func _set_study_filter(i: int, v) -> void:
	match i:
		0: g_team = str(v)
		1: g_year = int(v)
		2: g_pos = str(v)
		3: g_cost = int(v)
	_refresh_study()
func _refresh_study() -> void:
	study_list = []
	for c in Sv.owned_cards():
		if g_cost != 0 and int(c.get("cost", 1)) != g_cost:
			continue
		if g_team != "" and str(c.get("team", "")) != g_team:
			continue
		if g_year != 0 and int(c.get("year", 0)) != g_year:
			continue
		if g_pos != "" and str(c.get("pos", "")) != g_pos:
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
	# 뽑기 결과는 **큰 화면보다 위**입니다 — 뽑은 직후에 뜨는 것이라 그 순간
	# 화면에 남아 있던 다른 창을 덮어야 합니다.
	_draw_pack_modal()
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


# 이름 검색칸 — 거르개 칩 줄 오른쪽. **1만 장에서는 거르개만으로 못 찾습니다.**
# 구단·시즌을 다 걸어도 수십 장이 남고, 찾는 사람 이름은 이미 알고 있으니까요.
func _dex_search_rect() -> Rect2:
	var b := _body()
	return Rect2(b.position.x + _dex_chips().size() * CHIP_GAP + 8.0, b.position.y,
		190.0, CHIP_H)

func _draw_dex_search() -> void:
	var r := _dex_search_rect()
	draw_rect(r, P.PANEL_HI if dex_focus else P.PANEL, true)
	draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if dex_focus else P.LINE, false, 1.0)
	var s := dex_q
	if s == "":
		s = "이름 검색" if not dex_focus else ""
	Art.txt(self, r.position + Vector2(8, 18), s, 13,
		P.TEXT if dex_q != "" else P.TEXT_FAINT)
	# 깜빡이는 커서 — 글자를 받고 있다는 것이 보여야 합니다.
	if dex_focus:
		var cx := r.position.x + 8.0 + Art.txt_w(dex_q, 13) + 1.0
		if fmod(_t, 1.0) < 0.5:
			draw_rect(Rect2(cx, r.position.y + 6.0, 1.0, CHIP_H - 12.0), P.TEXT, true)

func _dex_type(e: InputEventKey) -> bool:
	# 검색칸이 글자를 먹는 동안에는 **단축키가 안 먹어야** 합니다 — 안 그러면
	# 이름에 든 숫자가 화면 전환 단축키(1~5)로 새어 나갑니다.
	if not dex_focus:
		return false
	if e.keycode == KEY_ESCAPE or e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		dex_focus = false
		return true
	if e.keycode == KEY_BACKSPACE:
		if dex_q != "":
			dex_q = dex_q.substr(0, dex_q.length() - 1)
			_refilter()
		return true
	var ch := char(e.unicode)
	if e.unicode >= 32 and ch != "":
		dex_q += ch
		_refilter()
	return true

func _draw_dex() -> void:
	var b := _body()
	var chips := _dex_chips()
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
	# 목록 칸 밖으로 넘친 카드를 지우고, 그 자리에 있어야 할 것을 다시 그립니다
	# (`_mask_list` 설명 참고). **위쪽은 화면 꼭대기까지** 지워야 합니다 —
	# 거르개 줄만 지우면 나머지가 제목 띠 위로 올라갑니다.
	_mask_list(a, 0.0, 0.0, size.x)
	_draw_bar()
	_draw_chips(chips, b.position.x, b.position.y)
	_draw_dex_search()
	var own := 0
	for c in dex:
		if Sv.has(DB.card_id(c)):
			own += 1
	var sr := _dex_search_rect()
	Art.txt(self, Vector2(sr.position.x + sr.size.x + 10.0, b.position.y + 18.0),
		"%d장 중 %d장 보유" % [dex.size(), own],
		13, P.TEXT_FAINT)
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
	# **좌우가 정확히 1:1 입니다**(원작 카드 상세가 그렇습니다). 왼쪽 카드 폭이 곧
	# 오른쪽 판 폭이고, 카드는 `CARD_RATIO` 만큼 세로로 깁니다 — 그래서 **높이를
	# 먼저 정하고 거기서 폭을 냅니다.** 폭을 먼저 박으면(예전 1060) 카드가 높이에
	# 걸려 줄어들면서 오른쪽이 왼쪽의 두 배가 됩니다(실제로 337 대 663 이었습니다).
	# 도감판은 4×4 판이 빠지므로 조금 낮습니다.
	# **도감판도 같은 크기입니다.** 같은 카드를 도감과 구단관리에서 번갈아 볼 때
	# 판이 커졌다 작아졌다 하면 어디를 보고 있었는지 놓칩니다 — 도감은 내용만
	# 비우고(성장 감추기) 자리는 그대로 둡니다.
	var h := minf(size.y - 40.0, 720.0)
	var w := (h - 40.0) / Art.CARD_RATIO * 2.0 + 60.0
	if w > size.x - 40.0:
		# 창이 가로로 좁으면 폭에 맞춰 되돌려 잡습니다 — 그래도 1:1 은 지킵니다.
		w = size.x - 40.0
		h = (w - 60.0) * 0.5 * Art.CARD_RATIO + 40.0
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)

func _modal_card_w() -> float:
	var r := _modal_rect()
	return (r.size.x - 60.0) * 0.5

func _modal_side() -> Rect2:
	# 카드 오른쪽 전체 — **카드와 같은 폭**입니다. 아래 네 칸이 여기서 나옵니다.
	var r := _modal_rect()
	var cw := _modal_card_w()
	return Rect2(r.position.x + cw + 40.0, r.position.y + 20.0, cw, r.size.y - 40.0)

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
	# **보너스를 카드에 적습니다.** 유학·스킬블록·구종은 `DB.find` 가 이미 스텟에
	# 얹어 두었고, 팀컬러는 팀에 붙는 것이라 **작전 화면에서만** 더해 보여 줍니다.
	# **도감판(`detail_raw`)에는 아무것도 안 얹습니다** — 카드도 원본이고 팀컬러
	# 몫도 0 입니다.
	var add := 0 if detail_raw else _color_add(c)
	var cw := _modal_card_w()
	Art.card(self, r.position + Vector2(20, 20), cw, c, false, add, true)

	var s := _modal_side()
	var tcol: Color = P.team(str(c.get("team", "")))
	# ── 오른쪽 위 : 얼굴 + 이름 띠 ──
	# 원작은 오른쪽 맨 위가 **작은 얼굴 사진 + 이름 띠**입니다. 왼쪽 카드에도
	# 사진이 있지만, 이름을 어디서 읽는지가 판마다 다르면 눈이 헤맵니다.
	var head := Rect2(s.position.x, s.position.y, s.size.x, 78.0)
	draw_rect(head, P.a(tcol, 0.35), true)
	draw_rect(head, P.LINE, false, 1.0)
	Art.face(self, Rect2(head.position.x + 6.0, head.position.y + 6.0, 54.0, 66.0), c)
	var hx := head.position.x + 70.0
	Art.txt(self, Vector2(hx, head.position.y + 30.0),
		"%s %s" % [DB.year_tag(c), str(c.get("name", ""))], 21, P.TEXT)
	var own := Sv.count(id)
	Art.txt(self, Vector2(hx, head.position.y + 50.0),
		"%s · %s" % [str(c.get("team", "")),
			str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", ""))))], 13, P.TEXT_DIM)
	Art.txt(self, Vector2(hx, head.position.y + 68.0),
		"종합 %d · COST %d%s" % [int(c.get("ov", 0)), int(c.get("cost", 1)),
			("   ·   보유 %d장" % own) if own > 0 else "   ·   미보유"], 13, P.TEXT_DIM)

	# ── 남은 세로를 나눕니다 ──
	# **자리를 상수로 박지 마세요.** 좌우 1:1 이라 오른쪽 판 높이가 카드 높이를
	# 따라가는데, 상수로 두면 아래가 통째로 비거나 넘칩니다.
	var gap := 10.0
	var tb_h := 52.0
	var rest := s.size.y - head.size.y - tb_h - gap * 3.0
	# **도감판도 똑같이 반씩 나눕니다.** 예전에는 도감이 아래 칸을 안 그려서
	# 방사도가 남은 세로를 다 먹었는데, 지금은 판을 비워서라도 같이 그리므로
	# 여기서 갈라 두면 표와 판이 아래로 밀려 겹칩니다(실제로 겹쳤습니다).
	var chart_h := rest * 0.5
	# 프로필 — 원작의 `27세 B형 / 경남고 / 우투우타 / No.11번 / 선발` 자리입니다.
	var top := Rect2(s.position.x, head.position.y + head.size.y + gap, s.size.x, chart_h)
	var pw := minf(140.0, top.size.x * 0.34)
	var y := top.position.y + 18.0
	for e in _profile_lines(c, detail_raw):
		Art.txt(self, Vector2(top.position.x, y), str(e), 13, P.TEXT_DIM)
		y += 19.0
	var chart := Rect2(top.position.x + pw, top.position.y, top.size.x - pw, top.size.y)
	Art.panel(self, chart, P.a(P.PANEL_HI, 0.45), P.LINE, 1.0)
	if pit:
		Art.pitch_chart(self, chart, c, add)
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
	var tb := Rect2(s.position.x, top.position.y + top.size.y + gap, s.size.x, tb_h)
	draw_rect(tb, P.a(P.PANEL_HI, 0.45), true)
	draw_rect(tb, P.LINE, false, 1.0)
	var cols := _record_cols(c)
	var colw := tb.size.x / float(maxi(cols.size(), 1))
	for i in range(cols.size()):
		var e: Array = cols[i]
		var cx := tb.position.x + i * colw
		# **글자를 칸 폭에 맞춰 줄입니다.** 판이 반쪽 폭이라 칸이 55px 안팎인데,
		# 크기를 상수로 두면 `262.2` 같은 값이 옆 칸을 파고듭니다.
		var ns2 := 12
		while ns2 > 8 and Art.txt_w(str(e[1]), ns2) > colw - 4.0:
			ns2 -= 1
		Art.txt(self, Vector2(cx + colw * 0.5 - Art.txt_w(str(e[0]), 11) * 0.5,
			tb.position.y + 18.0), str(e[0]), 11, P.TEXT_FAINT)
		Art.txt(self, Vector2(cx + colw * 0.5 - Art.txt_w(str(e[1]), ns2) * 0.5,
			tb.position.y + 40.0), str(e[1]), ns2, P.TEXT)

	# ── 오른쪽 아래 : 4×4 판 + 스킬 · 추가 능력치 ──
	# **도감에는 안 그립니다.** 낀 블록도 추가 능력치도 "내 카드" 의 이야기라,
	# 1만 장을 늘어놓는 사전에 나오면 남의 카드에까지 내 성장이 붙은 것처럼
	# 보입니다. 대신 어디서 보는지를 한 줄로 적습니다.
	var low := Rect2(s.position.x, tb.position.y + tb.size.y + gap, s.size.x,
		s.position.y + s.size.y - (tb.position.y + tb.size.y) - gap - 24.0)
	var bs := minf(low.size.y - 22.0, low.size.x * 0.5)
	var frame := Rect2(low.position.x, low.position.y, bs, bs)
	Art.panel(self, frame, P.a(P.PANEL_HI, 0.45), P.LINE, 1.0)
	# **도감판은 낀 블록도 열린 칸도 감춥니다** — 판은 그대로 그리되 비워 둡니다.
	Art.blocks(self, frame.grow(-8.0), c, -1, -1, false, detail_raw)
	var open: Array = Gr.open_cells(c, 0 if detail_raw else -1)
	var nxt := Gr.next_cell_at(c)
	var note := "%d / %d 칸" % [open.size(), Gr.CELLS]
	if detail_raw:
		note += " · 출전하면 열립니다" if str(c.get("grade", "")) != D.GRADE_EX else " · EX"
	elif nxt > 0:
		note += " · 다음 %d경기" % nxt
	elif str(c.get("grade", "")) == D.GRADE_EX:
		note += " · EX"
	Art.txt(self, Vector2(frame.position.x, frame.position.y + frame.size.y + 15.0),
		note, 12, P.TEXT_FAINT)

	# 낀 블록 목록 — **원작처럼 판 오른쪽에 세로로** 늘어놓습니다.
	# 판이 반쪽 폭이라 한 줄에 이름과 값을 다 못 넣습니다: 이름 아래에 값을
	# 한 줄 더 적습니다(한 줄로 밀어 넣으면 값이 판 밖으로 나갑니다).
	var lx := low.position.x + bs + 12.0
	var lw2 := low.size.x - bs - 12.0
	var ly := low.position.y + 14.0
	var bd := Gr.board(c)
	var uids: Array = [] if detail_raw else (bd["uids"] as Array)
	# **도감은 성장 이야기를 통째로 안 합니다.** 낀 블록도, 추가 능력치도 —
	# 그 자리에 어디서 보는지만 적습니다(자리는 그대로 둡니다).
	if detail_raw:
		Art.txt(self, Vector2(lx, ly), "도감은 기본 능력치만", 13, P.TEXT_FAINT)
		Art.txt(self, Vector2(lx, ly + 18.0), "보여 줍니다.", 13, P.TEXT_FAINT)
		Art.txt(self, Vector2(lx, ly + 42.0), "유학 · 스킬블록 · 팀컬러로", 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(lx, ly + 59.0), "오른 값은 [구단관리] ·", 12, P.TEXT_FAINT)
		Art.txt(self, Vector2(lx, ly + 76.0), "[작전] 에서 봅니다.", 12, P.TEXT_FAINT)
		_draw_trade_btn(c, id)
		Art.txt(self, Vector2(s.position.x, r.position.y + r.size.y - 14.0),
			"아무 데나 누르거나 [Esc] 로 닫습니다", 12, P.TEXT_FAINT)
		return
	if uids.is_empty():
		Art.txt(self, Vector2(lx, ly), "낀 스킬블록이 없습니다", 13, P.TEXT_FAINT)
		Art.txt(self, Vector2(lx, ly + 17.0), "[구단관리] 에서 끼웁니다.", 12, P.TEXT_FAINT)
		ly += 38.0
	for i in range(uids.size()):
		var bb := Gr.block(int(uids[i]))
		Art.block_icon(self, Vector2(lx, ly - 8.0), 5.0, bb,
			Art.BLOCK_COLS[i % Art.BLOCK_COLS.size()])
		Art.txt(self, Vector2(lx + 26.0, ly + 4.0), Gr.block_name(bb), 13, P.TEXT)
		Art.txt(self, Vector2(lx + 26.0, ly + 20.0), _ups_text(Gr.block_value(bb)), 12, P.UP)
		ly += 34.0
	ly += 10.0
	_draw_up_src(c, id, lx, ly, lw2)

	_draw_trade_btn(c, id)
	# 안내는 **카드 오른쪽 아래**에. 왼쪽에 두면 카드 위에 얹힙니다.
	var tip := "아무 데나 누르거나 [Esc] 로 닫습니다"
	Art.txt(self, Vector2(s.position.x, r.position.y + r.size.y - 14.0), tip, 12, P.TEXT_FAINT)

func _profile_lines(c: Dictionary, raw: bool = false) -> Array:
	# 원작의 프로필 줄. 나이·혈액형·출신교는 자료에 없으므로 **있는 것만** 적습니다 —
	# 없는 값을 그럴듯하게 지어내면 실제 기록으로 만든 카드라는 전제가 깨집니다.
	# 시합수처럼 **아래 기록 표에 있는 것도 안 적습니다**(같은 값이 두 번 보입니다).
	var out: Array = ["%d 시즌" % int(c.get("year", 0)), str(c.get("team", ""))]
	out.append(str(D.POS_SHORT.get(str(c.get("pos", "")), str(c.get("pos", "")))))
	out.append("카드 등급 %s" % ("EX" if D.show_grade(str(c.get("grade", ""))) else "일반"))
	# **출전 · 유학은 내 카드의 상태입니다.** 도감은 카드 사전이므로 안 적습니다 —
	# 성장으로 오른 값을 감춰 놓고 "유학 다녀옴" 만 적으면 앞뒤가 안 맞습니다.
	if raw:
		return out
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
# 카드에 적을 **팀컬러 몫**.
#
# `Sim.color_bonus()` 가 **그 카드가 오더에 들었는지**를 보므로 화면을 가릴
# 필요가 없습니다 — 도감의 안 가진 카드에는 0 이 나옵니다. 구단관리에서도
# 그대로 보여야 구종의 "다음 등급까지 +N" 을 최종 스텟으로 셀 수 있습니다.
func _color_add(c: Dictionary) -> int:
	return Sim.color_bonus(c)

func _draw_up_src(c: Dictionary, id: String, x: float, y: float, maxw: float) -> float:
	var src: Dictionary = c.get("up_src", {})
	var cb := _color_add(c)
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
	{"id": "team", "name": "구단 지명", "tag": "구단 6장",
		"note": "고른 구단 6장 + 랜덤 4장 · 세기는 랜덤 팩과 같습니다"},
	{"id": "block", "name": "스킬 블록", "tag": "랜덤",
		"note": "네 칸짜리 테트로미노 · 카드 판에 끼웁니다"},
]

func _pack_rect(i: int) -> Rect2:
	var b := _body()
	# **팩 수로 나눕니다.** 폭을 절반으로 박아 두면 팩이 셋이 됐을 때 세 번째가
	# 화면 밖으로 나갑니다(실제로 그랬습니다).
	var n := PACKS.size()
	var w := minf((b.size.x - 16.0 * (n - 1)) / float(n), 460.0)
	return Rect2(b.position.x + i * (w + 16.0), b.position.y + 30.0, w, 132.0)

func _pack_buy_rect(i: int) -> Rect2:
	var r := _pack_rect(i)
	return Rect2(r.position.x + 110.0, r.position.y + r.size.y - 40.0, r.size.x - 122.0, 32.0)

# 구단 지명 팩의 구단 고르개. **자리 함수를 하나 두어 그리기와 클릭이 같이 봅니다.**
func _pack_team_rect(i: int) -> Rect2:
	var r := _pack_rect(i)
	return Rect2(r.position.x + 110.0, r.position.y + 64.0, r.size.x - 122.0, CHIP_H)

func _pack_team_item_rect(i: int, j: int) -> Rect2:
	var r := _pack_team_rect(i)
	return Rect2(r.position.x, r.position.y + CHIP_H + 2.0 + j * COMBO_ROW, r.size.x, COMBO_ROW)

func _pack_of(id: String) -> int:
	# 팩 번호를 id 로 찾습니다. **검사에 번호를 박아 두지 마세요** — 팩을 하나
	# 끼워 넣는 순간 "블록 팩 클릭" 이 조용히 다른 팩을 누릅니다.
	for i in range(PACKS.size()):
		if str(PACKS[i]["id"]) == id:
			return i
	return 0

func _pack_teams() -> Array:
	return DB.lineages()

func _pack_team() -> String:
	var l := _pack_teams()
	if l.is_empty():
		return ""
	return str(l[clampi(pack_team_i, 0, l.size() - 1)])

func _pack_cost(i: int) -> int:
	match str(PACKS[i]["id"]):
		"player": return D.PACK_COST
		"team": return D.TEAM_PACK_COST
		_: return Gr.DRAW_COST

func _pack_size(i: int) -> int:
	return Gr.DRAW_SIZE if str(PACKS[i]["id"]) == "block" else D.PACK_SIZE

func _pack_have(i: int) -> int:
	return Sv.coins

func _draw_scout() -> void:
	# **펼친 구단 목록은 무슨 일이 있어도 맨 나중에** 그려야 합니다. 결과를 그리는
	# 쪽에 `return` 이 여럿이라, 본문 끝에 한 줄 붙이면 블록 팩을 뽑은 프레임에서는
	# 목록이 안 그려집니다 — 감싸서 확실히 마지막이 되게 합니다.
	_draw_scout_body()
	_draw_pack_team_open()

func _draw_scout_body() -> void:
	var b := _body()
	Art.txt(self, b.position + Vector2(0, 18), "스카우트", 18, P.TEXT)
	Art.txt(self, b.position + Vector2(84, 18),
		"보유 %d코인   ·   [도감] 에서 트레이드하면 코인이 됩니다   ·   [←→] 팩 [↑↓] 구단 [Enter] 뽑기" % Sv.coins,
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
		var pic := Rect2(r.position.x + 8.0, r.position.y + 8.0, 94.0, r.size.y - 16.0)
		_draw_pack_art(pic, str(pk["id"]), can)
		# 오른쪽 — 이름 · 내용 · 값
		var x := r.position.x + 110.0
		Art.txt(self, Vector2(x, r.position.y + 28.0), str(pk["name"]), 19, P.TEXT)
		var tag := str(pk["tag"])
		var tw := Art.txt_w(tag, 12) + 12.0
		draw_rect(Rect2(r.position.x + r.size.x - tw - 10.0, r.position.y + 12.0, tw, 20.0),
			P.hdr(P.BAR_HIGH, 1.15), true)
		Art.txt(self, Vector2(r.position.x + r.size.x - tw - 4.0, r.position.y + 27.0), tag, 12,
			Color(0.06, 0.06, 0.09))
		Art.txt(self, Vector2(x, r.position.y + 48.0), str(pk["note"]), 12, P.TEXT_FAINT)
		if str(pk["id"]) == "team":
			# 구단 고르개. **펼친 목록은 맨 나중에** 그립니다(아래 결과 카드를
			# 덮어야 합니다) — 여기서는 닫힌 칩만 그립니다.
			var tr := _pack_team_rect(i)
			draw_rect(tr, P.PANEL_HI if pack_team_open else P.PANEL, true)
			draw_rect(tr, P.hdr(P.BAR_MID, 1.15), false, 1.0)
			Art.txt(self, tr.position + Vector2(8, 18),
				"%s   한 번에 %d장" % [Col.lineage_label(_pack_team()), _pack_size(i)], 13, P.TEXT)
			Art.txt(self, Vector2(tr.position.x + tr.size.x - 15.0, tr.position.y + 18.0),
				"▾", 11, P.TEXT_FAINT)
		else:
			Art.txt(self, Vector2(x, r.position.y + 72.0), "한 번에 %d개" % _pack_size(i), 14,
				P.hdr(P.BAR_MID, 1.15))

		var buy := _pack_buy_rect(i)
		draw_rect(buy, P.PANEL_HI if can else P.PANEL, true)
		draw_rect(buy, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0 if can else 1.0)
		var t := "뽑기   %d 코인" % cost
		Art.txt(self, buy.position + Vector2(buy.size.x * 0.5 - Art.txt_w(t, 15) * 0.5, 22), t, 15,
			P.TEXT if can else P.TEXT_FAINT)

	# ── 안내와 확률 ──
	# **뽑은 결과는 여기 안 깝니다** — 모달(`_draw_pack_modal`)이 보여 줍니다.
	# 아래에 깔던 시절에는 팩 칸과 결과가 한 화면에서 자리를 다퉜습니다.
	var y := b.position.y + 180.0
	Art.txt(self, Vector2(b.position.x, y),
		"팩을 눌러 뽑으세요.  뽑은 카드는 창으로 하나씩 열립니다.", 15, P.TEXT_DIM)
	_draw_odds(b, y + 26.0)

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
	if id == "team":
		# 카드 한 장에 구단 색 띠 — **무엇을 지명하는 팩인지**를 색으로 말합니다.
		var cr2 := Rect2(m.x - r.size.x * 0.22, m.y - r.size.y * 0.16,
			r.size.x * 0.44, r.size.y * 0.44)
		draw_rect(cr2, P.PANEL_HI if lit else P.PANEL, true)
		draw_rect(cr2, base, false, 1.0)
		var tc := P.team(_pack_team())
		draw_rect(Rect2(cr2.position.x, cr2.position.y + cr2.size.y - 10.0, cr2.size.x, 10.0),
			tc if lit else P.a(tc, 0.45), true)
	elif id == "block":
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
	_open_pack_modal()

func _draw_pack_now(i: int) -> void:
	# 팩 하나를 뽑습니다. **클릭과 키가 같은 통로를 지나야** 한쪽만 고쳤을 때
	# 조용히 어긋나지 않습니다.
	if i < 0 or i >= PACKS.size():
		return
	pack_i = i
	match str(PACKS[i]["id"]):
		"block": _do_block_pack()
		"team": _do_team_pack()
		_: _do_pack()

# ── 뽑기 결과 모달 ─────────────────────────────────────────────────────────

# 연출 세기 — **그 팩에서 제일 높은 COST** 가 정합니다. 7코부터 눈에 띄게
# 달라지고 10코는 화면이 통째로 번쩍입니다. `D.COST_HIGH`(7)가 카드 테두리에서
# 이미 "여기부터 좋은 카드" 경계로 쓰이므로 **같은 자리를 씁니다** — 두 곳이
# 다른 값을 보면 테두리는 굵은데 연출은 밋밋한 카드가 생깁니다.
# 블록 팩은 COST 가 없으므로 0(수수한 연출)입니다.
func _open_pack_modal(note: String = "") -> void:
	# **뽑은 직후 한 곳에서만 엽니다** — 팩마다 따로 열면 한 곳을 빠뜨렸을 때
	# 그 팩만 결과가 안 보입니다.
	pack_open = true
	pack_t = 0.0
	if note != "":
		_say(note)

func _pack_tier() -> int:
	var best := 0
	for c in pack:
		best = maxi(best, int((c as Dictionary).get("cost", 1)))
	return best

func _pack_modal_rect() -> Rect2:
	return Rect2(40.0, 56.0, size.x - 80.0, size.y - 112.0)

# 결과 칸 — 카드도 블록도 **다섯씩 두 줄**입니다.
func _pack_cell(i: int, n: int) -> Rect2:
	var r := _pack_modal_rect()
	var per := 5
	var cols := mini(n, per)
	var rows := ceili(float(n) / float(per))
	var top := r.position.y + 74.0
	var availh := r.position.y + r.size.y - 52.0 - top
	var cw := minf((r.size.x - 40.0) / float(cols) - 12.0,
		(availh / float(rows) - 12.0) / Art.CARD_RATIO)
	var ch := cw * Art.CARD_RATIO
	@warning_ignore("integer_division")
	var row := i / per
	var inrow := mini(n - row * per, per)
	var gw := inrow * (cw + 12.0) - 12.0
	return Rect2(r.position.x + (r.size.x - gw) * 0.5 + (i % per) * (cw + 12.0),
		top + (availh - rows * (ch + 12.0) + 12.0) * 0.5 + row * (ch + 12.0), cw, ch)

# 한 장이 열리는 시각. 높은 등급일수록 **뜸을 들입니다** — 연출이 쌓일 시간이
# 있어야 "뭔가 온다" 가 읽힙니다.
# ── 등급별 연출표 ──────────────────────────────────────────────────────────
# **네 단계(7 · 8 · 9 · 10코)가 눈에 띄게 달라야 합니다.** 수만 늘리면 7코와
# 8코가 사실상 같아 보입니다 — 그래서 단계마다 **새 요소를 하나씩** 더합니다.
#
#    7코 — 금색 빛살 · 고리 하나 · 반짝이
#    8코 — **+ 반대로 도는 빛살 한 겹** (돌아가는 결이 겹쳐 깊이가 생깁니다)
#    9코 — **+ 별똥별 · 판 안쪽 가장자리 발광**
#   10코 — **+ 무지개 빛살 · 테두리 맥동 · 카드가 열릴 때마다 번쩍**
#
# **`D.COST_HIGH` 부터 한 칸씩**입니다(번호를 박아 두면 그 상수를 바꿀 때
# 조용히 어긋납니다). 마지막 칸을 넘는 COST 는 마지막 칸을 씁니다.
const FX := [
	{"intro": 0.30, "rays": 16, "back": 0, "rings": 1, "spark": 22,
		"flash": 0.20, "meteor": 0, "edge": 0.00, "rainbow": false, "pop": false},
	{"intro": 0.45, "rays": 20, "back": 10, "rings": 2, "spark": 30,
		"flash": 0.24, "meteor": 0, "edge": 0.00, "rainbow": false, "pop": false},
	{"intro": 0.65, "rays": 26, "back": 14, "rings": 3, "spark": 42,
		"flash": 0.34, "meteor": 6, "edge": 0.35, "rainbow": false, "pop": false},
	{"intro": 0.95, "rays": 32, "back": 18, "rings": 4, "spark": 56,
		"flash": 0.46, "meteor": 12, "edge": 0.60, "rainbow": true, "pop": true},
]
const PACK_STEP := 0.10

func _fx_spec(tier: int) -> Dictionary:
	return FX[clampi(tier - D.COST_HIGH, 0, FX.size() - 1)]

# **등급마다 색이 다릅니다.** 세기(개수 · 시간)만 올리면 7코와 8코가 "좀 더
# 반짝이는 것" 정도로만 갈려서 티가 잘 안 납니다 — 색이 바뀌면 한눈에 압니다.
#
#   7코 청록 → 8코 자홍 → 9코 금 → 10코 주홍(+ 무지개 빛살)
#
# **팔레트에 이미 있는 색을 씁니다**(`P`). 여기에 새 색을 만들면 화면의 다른
# 뜻(경고 · 성장 · 막대)과 부딪히고, 팔레트를 바꿔도 여기만 옛 색으로 남습니다.
# 색 값을 표(`FX`)에 넣지 않는 이유도 같습니다 — `const` 는 오토로드(`P`)를
# 못 보므로 값을 베껴 적게 되고, 그러면 두 곳이 따로 놉니다.
func _fx_color(tier: int) -> Color:
	match clampi(tier - D.COST_HIGH, 0, 3):
		0: return P.BAR_MID
		1: return P.UP
		2: return P.BAR_HIGH
		_: return P.BAR_TOP

func _pack_intro() -> float:
	var t := _pack_tier()
	if t < D.COST_HIGH:
		return 0.0
	return float(_fx_spec(t)["intro"])

func _pack_all_shown() -> bool:
	var n := maxi(pack.size(), block_pack.size())
	return pack_t >= _pack_intro() + PACK_STEP * float(n) + 0.25

# 결과 창 아래 단추 둘 — **다시뽑기 · 닫기.** 뽑기는 연달아 하는 일이라, 닫고
# 팩을 다시 찾아 누르는 것이 매번 두 번 일입니다. **자리 함수를 하나 두어
# 그리기와 클릭이 같이 봅니다.**
func _pack_close_rect() -> Rect2:
	var r := _pack_modal_rect()
	return Rect2(r.position.x + r.size.x - 140.0, r.position.y + r.size.y - 48.0, 120.0, 34.0)

func _pack_again_rect() -> Rect2:
	var r := _pack_close_rect()
	return Rect2(r.position.x - 214.0, r.position.y, 204.0, 34.0)

func _pack_click(p: Vector2) -> void:
	# **먼저 전부 펼치고, 그 다음 누름에 닫습니다.**
	if not _pack_all_shown():
		pack_t = 99.0
		return
	# 단추는 **다 펼쳐진 뒤에만** 나옵니다 — 펼치는 중에 그 자리를 누르면
	# 자기 카드를 못 본 채로 다시 뽑게 됩니다.
	if _pack_again_rect().has_point(p):
		_draw_pack_now(pack_i)
		return
	pack_open = false

func _pack_team_step(d: int) -> void:
	var l := _pack_teams()
	if l.is_empty():
		return
	pack_team_i = posmod(pack_team_i + d, l.size())
	# 구단을 넘기면 고른 팩도 구단 지명으로 옮깁니다 — 안 그러면 화면에서는
	# 구단이 바뀌는데 `Enter` 는 엉뚱한 팩을 뽑습니다.
	for i in range(PACKS.size()):
		if str(PACKS[i]["id"]) == "team":
			pack_i = i

func _click_pack_team(p: Vector2) -> bool:
	# 구단 고르개. 그리기(`_draw_pack_team_open`)와 같은 자리 함수를 봅니다.
	var ti := -1
	for i in range(PACKS.size()):
		if str(PACKS[i]["id"]) == "team":
			ti = i
	if ti < 0:
		return false
	var l := _pack_teams()
	if pack_team_open:
		for j in range(l.size()):
			if _pack_team_item_rect(ti, j).has_point(p):
				pack_team_i = j
				pack_team_open = false
				return true
		pack_team_open = false
		return true
	if _pack_team_rect(ti).has_point(p):
		pack_team_open = true
		pack_i = ti
		return true
	return false

# 연출은 **벡터로만** 그립니다 — 그림 파일이 없어도 폴더 하나로 돌아야 합니다.
# 밝기는 `P.hdr` 로 1.0 을 넘겨 엔진 블룸에 맡깁니다(`hdr_2d`).
# **난수를 쓰지 마세요** — 매 프레임 다시 뽑으면 알갱이가 제자리에서 떨립니다.
# 번호로 각도와 거리를 만들면 같은 알갱이가 계속 같은 자리에 있습니다.
func _fx_hash(i: int, k: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + k) * 43758.5453, 1.0)

func _fx_glow(m: Vector2, rad: float, col: Color) -> void:
	# 방사형 빛무리. **반투명 원을 겹쳐 만들지 마세요** — 층 경계가 띠로 보입니다.
	# 부채꼴 삼각형을 꼭짓점 색으로 흐리게 빼면 경계 없이 번집니다.
	var n := 24
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var a2 := TAU * float(i + 1) / float(n)
		draw_polygon(PackedVector2Array([m,
			m + Vector2(cos(a), sin(a)) * rad, m + Vector2(cos(a2), sin(a2)) * rad]),
			PackedColorArray([col, P.a(col, 0.0), P.a(col, 0.0)]))

func _draw_pack_fx(r: Rect2, tier: int, t: float) -> void:
	var m := r.get_center()
	var rad := r.size.length() * 0.5
	var gold := _fx_color(tier)
	if tier < D.COST_HIGH:
		return
	var f := _fx_spec(tier)
	var lv := float(clampi(tier - D.COST_HIGH, 0, FX.size() - 1))
	var grow := clampf(t / 0.5, 0.0, 1.0)
	# ── 2. 반대로 도는 빛살 ── **8코부터.** 결이 둘 겹치면 깊이가 생겨서,
	# 개수만 늘린 것과 확실히 달라 보입니다. 뒤에 깔리므로 더 어둡고 가늡니다.
	var back := int(f["back"])
	for i in range(back):
		var ab := TAU * float(i) / float(back) - t * 0.15
		var wb := TAU / float(back) * 0.22
		var cb := P.a(P.hdr(gold, 1.0), 0.045 * grow)
		draw_polygon(PackedVector2Array([m,
			m + Vector2(cos(ab - wb), sin(ab - wb)) * rad,
			m + Vector2(cos(ab + wb), sin(ab + wb)) * rad]),
			PackedColorArray([cb, P.a(cb, 0.0), P.a(cb, 0.0)]))
	# ── 3. 방사선 ── 가운데에서 뻗는 빛살. 등급이 높을수록 촘촘하고 밝습니다.
	# **천천히 돕니다** — 빠르게 돌리면 글자를 읽을 수 없습니다.
	var rays := int(f["rays"])
	var spin := t * (0.22 + 0.06 * lv)
	for i in range(rays):
		var a := TAU * float(i) / float(rays) + spin
		var wdt := TAU / float(rays) * (0.42 if bool(f["rainbow"]) else 0.34)
		var col := P.a(P.hdr(gold, 1.15 + 0.25 * lv), (0.05 + 0.03 * lv) * grow)
		if bool(f["rainbow"]):
			# 10코만 색이 돕니다 — 금색 하나로는 "제일 센 것" 이 안 갈립니다.
			col = P.a(P.hdr(Color.from_hsv(fposmod(float(i) / float(rays) + t * 0.12, 1.0),
				0.55, 1.0), 1.25), 0.10 * grow)
		# **바깥으로 갈수록 투명해져야 빛으로 보입니다.** 한 색으로 칠하면
		# 알파를 아무리 낮춰도 "돌아가는 바람개비" 로 읽힙니다 —
		# `draw_polygon` 은 꼭짓점마다 색을 받으므로 끝을 0 으로 뺍니다.
		draw_polygon(PackedVector2Array([m,
			m + Vector2(cos(a - wdt), sin(a - wdt)) * rad,
			m + Vector2(cos(a + wdt), sin(a + wdt)) * rad]),
			PackedColorArray([col, P.a(col, 0.0), P.a(col, 0.0)]))
	# ── 4. 퍼지는 고리 ── 몇 겹이 시차를 두고 나갑니다.
	var rings := int(f["rings"])
	for i in range(rings):
		var rt := t - float(i) * 0.16
		if rt < 0.0 or rt > 1.1:
			continue
		var k := rt / 1.1
		draw_arc(m, rad * 0.16 + rad * 0.9 * k, 0.0, TAU, 64,
			P.a(P.hdr(gold, 1.4), (1.0 - k) * 0.55), 3.0 + 2.0 * lv)
	# ── 5. 별똥별 ── **9코부터.** 머리는 밝고 꼬리는 투명한 삼각형입니다.
	# 판을 가로질러 떨어지므로 "위에서 뭔가 쏟아진다" 가 읽힙니다.
	var met := int(f["meteor"])
	for i in range(met):
		var ph := fposmod(t * (0.35 + 0.25 * _fx_hash(i, 2.2)) + _fx_hash(i, 8.1), 1.0)
		var sx := r.position.x - 120.0 + (r.size.x + 240.0) * _fx_hash(i, 4.4)
		var hd := Vector2(sx - r.size.x * 0.35 * ph, r.position.y - 40.0 + (r.size.y + 80.0) * ph)
		var dir := Vector2(0.62, -0.78)          # 꼬리는 오른쪽 위로
		var ln := 90.0 + 70.0 * _fx_hash(i, 6.6)
		var nrm := Vector2(-dir.y, dir.x) * (2.2 + 1.4 * _fx_hash(i, 1.1))
		var ca := P.a(P.hdr(gold, 1.6), 0.75 * sin(ph * PI))
		draw_polygon(PackedVector2Array([hd + nrm, hd - nrm, hd + dir * ln]),
			PackedColorArray([ca, ca, P.a(ca, 0.0)]))
	# ── 6. 반짝이 ── 별 모양으로 그려야 젬·알갱이와 안 헷갈립니다.
	var n := int(f["spark"])
	for i in range(n):
		var a2 := _fx_hash(i, 1.3) * TAU
		var d := (0.25 + 0.72 * _fx_hash(i, 7.7)) * rad
		var ph := fposmod(t * (0.7 + _fx_hash(i, 3.1)) + _fx_hash(i, 5.5), 1.0)
		# 0 까지 내리지 않습니다 — 완전히 꺼지면 깜빡이는 것처럼 보입니다.
		var sc := (0.35 + 0.65 * sin(ph * PI)) * clampf(t / 0.35, 0.0, 1.0)
		var p := m + Vector2(cos(a2), sin(a2)) * d
		var sr := (2.0 + 4.0 * _fx_hash(i, 9.9)) * sc
		var col2 := P.a(P.hdr(gold, 1.5), 0.9 * sc)
		draw_line(p - Vector2(sr * 2.2, 0), p + Vector2(sr * 2.2, 0), col2, 1.5)
		draw_line(p - Vector2(0, sr * 2.2), p + Vector2(0, sr * 2.2), col2, 1.5)
		draw_circle(p, sr * 0.5, col2)

func _draw_pack_glare(tier: int, t: float) -> void:
	# **섬광은 판보다 위**입니다. 아래에 두면 판(불투명)이 덮어서 아무 일도 안
	# 일어난 것처럼 보입니다 — 처음에 그렇게 넣었다가 화면이 밋밋했습니다.
	if tier < D.COST_HIGH:
		return
	var f := _fx_spec(tier)
	var r := _pack_modal_rect()
	var col := _fx_color(tier)
	# ── 판 안쪽 가장자리 발광 ── **9코부터.** 판 위에 그려야 보입니다.
	# **테를 여러 겹** 두릅니다 — 반투명 사각형을 채우면 층 경계가 띠로 보입니다.
	var eg := float(f["edge"])
	if eg > 0.0:
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		for j in range(10):
			var kk := 1.0 - float(j) / 10.0
			draw_rect(r.grow(-2.0 - 3.0 * float(j)),
				P.a(P.hdr(col, 1.35), eg * 0.06 * kk * kk * pulse), false, 3.0)
	# ── 테두리 맥동 ── **10코만.** 테가 그 등급 색 언저리에서 오르내립니다.
	# **무지개를 그대로 두지 마세요** — 초록·파랑 테가 되면 화면의 다른 경고색과
	# 헷갈리고 판과 따로 놉니다(실제로 형광 초록 테가 나왔습니다).
	# 빛살은 색이 돌아도 괜찮습니다 — 알파가 0.1 이라 배경처럼 읽힙니다.
	if bool(f["rainbow"]):
		draw_rect(r, P.hdr(col.lerp(P.BAR_HIGH, 0.5 + 0.5 * sin(t * 2.2)), 1.35), false, 3.0)
	# ── 첫 순간의 섬광 ── 등급이 높을수록 세고 오래갑니다.
	var span := 0.18 + 0.10 * float(clampi(tier - D.COST_HIGH, 0, FX.size() - 1))
	var fl := clampf(1.0 - t / span, 0.0, 1.0)
	if fl <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), P.a(Color(1, 1, 1), fl * fl * float(f["flash"])), true)

func _draw_pack_modal() -> void:
	if not pack_open:
		return
	var n := maxi(pack.size(), block_pack.size())
	var tier := _pack_tier()
	var r := _pack_modal_rect()
	var t := pack_t
	draw_rect(Rect2(Vector2.ZERO, size), P.a(Color.BLACK, 0.82), true)
	# 연출은 **판보다 먼저** — 빛살이 판 뒤로 지나가야 결과를 안 가립니다.
	_draw_pack_fx(r, tier, t)
	# 높은 등급일수록 판을 조금 비쳐 둡니다 — 빛살이 판 뒤로 지나가는 것이
	# 보여야 "뒤에서 무언가 돌고 있다" 가 읽힙니다.
	var pa := 0.92 - 0.02 * float(maxi(tier - D.COST_HIGH, 0))
	# 판 테두리도 **등급 색**입니다 — 창을 열자마자 어느 등급인지 읽힙니다.
	Art.panel(self, r, P.a(P.PANEL, pa),
		P.hdr(_fx_color(tier), 1.3) if tier >= D.COST_HIGH else P.LINE,
		3.0 if tier >= D.COST_HIGH else 1.0)

	var title := "얻은 블록 %d개" % block_pack.size() if pack.is_empty() else "얻은 카드 %d장" % pack.size()
	Art.txt(self, Vector2(r.position.x + 20.0, r.position.y + 34.0), title, 20, P.TEXT)
	# **제일 좋은 것은 다 펼친 뒤에 적습니다.** 처음부터 `★10 이정후` 라고 써 두면
	# 한 장씩 여는 동안 볼 것이 없습니다 — 뽑기에서 제일 좋은 순간을 스스로 지우는 셈입니다.
	if tier >= D.COST_HIGH and _pack_all_shown():
		var big := ""
		for c in pack:
			if int((c as Dictionary).get("cost", 1)) == tier:
				big = "%s %s" % [DB.year_tag(c), str((c as Dictionary).get("name", ""))]
				break
		var tag := "★%d  %s" % [tier, big]
		var ts := 26 if tier >= 9 else 20
		# 번쩍이는 것은 최고 등급만 — 다 번쩍이면 아무것도 안 도드라집니다.
		var hc := P.hdr(_fx_color(tier), 1.35 + (0.35 * sin(t * 6.0) if tier >= 10 else 0.0))
		Art.txt(self, Vector2(r.position.x + r.size.x - 20.0 - Art.txt_w(tag, ts),
			r.position.y + 38.0), tag, ts, hc)

	var intro := _pack_intro()
	for i in range(n):
		var at := intro + PACK_STEP * float(i)
		if t < at:
			continue
		var cell := _pack_cell(i, n)
		# 튀어나오는 등장 — 살짝 커졌다 제자리로.
		var k := clampf((t - at) / 0.22, 0.0, 1.0)
		var sc := 1.0 + 0.35 * (1.0 - k) * (1.0 - k) - 0.35 * (1.0 - k)
		sc = clampf(sc, 0.35, 1.2) if k < 1.0 else 1.0
		if not pack.is_empty():
			var c: Dictionary = pack[i]
			var co := int(c.get("cost", 1))
			var cw := cell.size.x * sc
			var pos := cell.get_center() - Art.card_size(cw) * 0.5
			# 좋은 카드는 뒤에 빛을 깝니다 — 열 장 중 어느 것이 좋은지가
			# 훑지 않고도 보여야 합니다.
			# **10코 팩은 카드가 열릴 때마다 번쩍입니다** — 마지막 단계에만 있는
			# 것이 하나는 있어야 9코와 확실히 갈립니다.
			if bool(_fx_spec(tier)["pop"]) and k < 1.0:
				_fx_glow(cell.get_center(), cell.size.x * (0.5 + 1.1 * (1.0 - k)),
					P.a(P.hdr(_fx_color(tier), 1.5), 0.5 * (1.0 - k)))
			if co >= D.COST_HIGH:
				# **후광은 그 카드 자신의 COST 색**입니다(팩 전체 등급이 아니라).
				# 한 팩에 7코와 10코가 같이 나오면 어느 것이 더 센지 색으로 바로
				# 갈려야 합니다 — 다 같은 금색이면 테 두께로만 세게 됩니다.
				# **테를 여러 겹 두릅니다.** 반투명 사각형을 겹쳐 칠하면 층 경계가
				# 띠로 보이고, 카드 옆칸까지 상자가 덮습니다(실제로 그랬습니다).
				var hcol := _fx_color(co)
				var gl := 3 + (co - D.COST_HIGH) * 3
				for j in range(gl):
					draw_rect(Rect2(pos, Art.card_size(cw)).grow(2.0 + 2.0 * float(j)),
						P.a(P.hdr(hcol, 1.35),
							0.30 * (1.0 - float(j) / float(gl)) * (1.0 - float(j) / float(gl))),
						false, 2.0)
			Art.card(self, pos, cw, c, co >= D.COST_HIGH)
		else:
			var bb: Dictionary = block_pack[i]
			var bx := Rect2(cell.get_center() - Vector2(cell.size.x, 92.0) * 0.5 * sc,
				Vector2(cell.size.x, 92.0) * sc)
			Art.panel(self, bx, P.PANEL_HI, P.hdr(P.BAR_HIGH, 1.15), 2.0)
			Art.block_icon(self, bx.position + Vector2(12, 16), 11.0 * sc, bb,
				Art.BLOCK_COLS[i % Art.BLOCK_COLS.size()])
			Art.txt(self, bx.position + Vector2(66, 30), Gr.block_name(bb), 14, P.TEXT)
			Art.txt(self, bx.position + Vector2(66, 50), _ups_text(Gr.block_value(bb)), 12, P.UP)
			var who: String = "투수용" if str(Gr.skill(str(bb["sid"])).get("kind", "")) == "pitcher" else "야수용"
			Art.txt(self, bx.position + Vector2(66, 70), who, 12, P.TEXT_FAINT)

	if not _pack_all_shown():
		Art.txt(self, Vector2(r.position.x + 20.0, r.position.y + r.size.y - 26.0),
			"아무 데나 누르면 다 펼칩니다", 13, P.TEXT_FAINT)
	else:
		Art.txt(self, Vector2(r.position.x + 20.0, r.position.y + r.size.y - 26.0),
			"[Enter] 다시뽑기   ·   [Esc] 또는 빈 곳을 눌러 닫기", 13, P.TEXT_FAINT)
		# 다시뽑기 — **같은 팩을 그대로** 다시 뽑습니다(`pack_i`). 값이 모자라면
		# 흐리게 두고, 눌러도 창은 안 닫습니다(`_do_pack` 이 이유를 말합니다).
		var cost := _pack_cost(pack_i)
		var can := Sv.coins >= cost
		var ar := _pack_again_rect()
		draw_rect(ar, P.PANEL_HI if can else P.PANEL, true)
		draw_rect(ar, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0 if can else 1.0)
		var at2 := "다시뽑기   %d 코인" % cost
		Art.txt(self, ar.position + Vector2(ar.size.x * 0.5 - Art.txt_w(at2, 15) * 0.5, 23),
			at2, 15, P.TEXT if can else P.TEXT_FAINT)
		var cr2 := _pack_close_rect()
		draw_rect(cr2, P.PANEL, true)
		draw_rect(cr2, P.LINE, false, 1.0)
		Art.txt(self, cr2.position + Vector2(cr2.size.x * 0.5 - Art.txt_w("닫기", 15) * 0.5, 23),
			"닫기", 15, P.TEXT_DIM)
	# 가운데 빛무리 — **카드가 열리기 전까지** "여기서 나온다" 를 잡아 줍니다.
	# 판보다 위에 그려야 보입니다(판이 불투명합니다).
	var intro2 := _pack_intro()
	if intro2 > 0.0 and t < intro2:
		var k2 := t / intro2
		_fx_glow(r.get_center(), 40.0 + 220.0 * k2 * k2,
			P.a(P.hdr(_fx_color(tier), 1.6), 0.5 * (1.0 - k2 * k2)))
	_draw_pack_glare(tier, t)

func _draw_pack_team_open() -> void:
	# **펼친 목록은 맨 나중에** 그립니다 — 아래 팩과 결과 카드를 덮어야 합니다.
	if not pack_team_open:
		return
	var ti := -1
	for i in range(PACKS.size()):
		if str(PACKS[i]["id"]) == "team":
			ti = i
	if ti < 0:
		return
	var l := _pack_teams()
	var r := _pack_team_rect(ti)
	Art.panel(self, Rect2(r.position.x, r.position.y + CHIP_H,
		r.size.x, l.size() * COMBO_ROW + 4.0), P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	for j in range(l.size()):
		var ir := _pack_team_item_rect(ti, j)
		var sel := j == pack_team_i
		if sel:
			draw_rect(ir, P.PANEL_HI, true)
		# 가진 카드 수를 같이 적습니다 — 어느 구단을 더 모아야 하는지가 여기서
		# 보여야 팩을 고르는 뜻이 생깁니다.
		Art.txt(self, ir.position + Vector2(8, 17), Col.lineage_label(str(l[j])), 13,
			P.hdr(P.BAR_HIGH, 1.1) if sel else P.TEXT_DIM)
		var n := "%d장" % _owned_of_team(str(l[j]))
		Art.txt(self, Vector2(ir.position.x + ir.size.x - 10.0 - Art.txt_w(n, 12),
			ir.position.y + 17.0), n, 12, P.TEXT_FAINT)

func _owned_of_team(lineage: String) -> int:
	var n := 0
	for c in Sv.owned_cards():
		if Col.lineage(str((c as Dictionary).get("team", ""))) == lineage:
			n += 1
	return n

func _do_team_pack() -> void:
	# **구단만 좁히고 세기는 그대로입니다** — 앞의 `D.TEAM_PACK_MIN` 장을 그
	# 구단에서 확정으로 뽑고 나머지는 무작위입니다. 장수를 확률로 굴리지 마세요:
	# 지명한 사람에게 "절반도 안 나옴" 이 나오면 그냥 고장으로 읽힙니다.
	if Sv.coins < D.TEAM_PACK_COST:
		_say("코인이 모자랍니다.")
		return
	var team := _pack_team()
	if team == "":
		_say("구단 자료가 없습니다.")
		return
	Sv.coins -= D.TEAM_PACK_COST
	pack.clear()
	block_pack.clear()
	var mine := 0
	for i in range(D.PACK_SIZE):
		var c := DB.draw_one_team(rng, team) if i < D.TEAM_PACK_MIN else DB.draw_one(rng)
		if c.is_empty():
			continue
		if Col.lineage(str(c.get("team", ""))) == team:
			mine += 1
		pack.append(c)
		Sv.add_card(c)
	Sv.save_game()
	_refresh_study()
	_open_pack_modal("%s %d장" % [Col.lineage_label(team), mine])

func _do_block_pack() -> void:
	if Sv.coins < Gr.DRAW_COST:
		_say("코인이 모자랍니다.")
		return
	Sv.coins -= Gr.DRAW_COST
	pack.clear()
	block_pack = Gr.draw_blocks(Gr.DRAW_SIZE)
	Sv.save_game()
	_refresh_study()
	_open_pack_modal()

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
		var lit := Sv.color_ids.has(str(e["id"]))
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
		var cid := str(e["id"])
		if Sv.color_ids.has(cid):
			Sv.color_ids.erase(cid)
		elif Sv.color_ids.size() >= Col.MAX_ACTIVE:
			# **말없이 갈아 끼우지 마세요** — 무엇이 꺼졌는지 모른 채 약해집니다.
			_say("팀컬러는 %d개까지입니다 — 하나를 먼저 끄세요" % Col.MAX_ACTIVE)
			return true
		else:
			Sv.color_ids.append(cid)
		Sv.save_game()
		return true
	return false

func _draw_order() -> void:
	var b := _body()
	# **팀컬러 목록을 매 프레임 갱신합니다.** 예전에는 팀컬러 창을 그릴 때만
	# 채워서, 창을 한 번도 안 열면 목록이 빈 채로 판정됐습니다 — 25칸을 다
	# 맞췄는데도 단추에 "켤 수 있는 것이 없습니다"가 뜨던 것이 이것입니다.
	color_list = Sim.team_from_save(D.MY_TEAM)["colors"]

	# ── 아래 왼쪽 : 보유선수 카드 ──
	# **카드를 제일 먼저 그립니다.** `_draw()` 에는 클리핑이 없어서 스크롤한
	# 카드가 판 밖으로 넘치는데, 먼저 그려 두면 그 뒤에 그리는 위 판(배치선수)과
	# 탭 줄이 넘친 부분을 덮습니다. 판과 판 사이의 빈틈은 `_mask_list` 가 지웁니다.
	# 머리글과 거르개는 카드를 덮어야 하므로 **아래에 그대로 남겨 둡니다.**
	var pr2 := _pool_rect()
	var pa := _pool_area()
	if order_tab != TAB_COLOR:
		Art.panel(self, pr2, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
		for i in range(pool.size()):
			var cr := _pool_cell(i)
			if cr.position.y + cr.size.y < pa.position.y or cr.position.y > pa.position.y + pa.size.y:
				continue
			Art.small_card(self, cr.position, cr.size.x, pool[i], i == pool_i, cr.size.y)
		if pool.is_empty():
			Art.txt(self, pa.position + Vector2(6, 26), "세울 수 있는 선수가 없습니다.", 14, P.TEXT_DIM)
			Art.txt(self, pa.position + Vector2(6, 48),
				"거르개를 풀거나 [스카우트] 에서 뽑으세요.", 13, P.TEXT_FAINT)
		# 위로는 본문 꼭대기까지만 지우면 됩니다 — 목록이 화면 중간에 있어서
		# 카드가 제목 띠까지는 못 올라갑니다.
		_mask_list(pa, b.position.y, pr2.position.x, pr2.size.x, pr2)

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

	# ── 아래 왼쪽 : 보유선수 머리글과 거르개 ──
	# 카드는 위에서 이미 그렸습니다. 거르개는 **카드 다음**이어야 합니다 —
	# 위로 밀린 카드가 거르개를 덮으면 목록을 맨 위까지 되올려야 고를 수 있습니다.
	var pbn := Rect2(pr2.position, Vector2(pr2.size.x, 62.0))
	draw_rect(pbn, P.BG, true)
	draw_rect(pbn, P.a(P.PANEL_HI, 0.32), true)
	draw_rect(pr2, P.LINE, false, 1.0)
	Art.txt(self, Vector2(pr2.position.x + 8.0, pr2.position.y + 20.0),
		"보유선수 %d명" % pool.size(), 14, P.hdr(P.BAR_MID, 1.15))
	_draw_pool_chips()

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
	var lit := not Sv.color_ids.is_empty()
	draw_rect(cb, P.PANEL_HI if lit else P.PANEL, true)
	draw_rect(cb, P.hdr(P.BAR_HIGH, 1.2) if lit else P.LINE, false, 1.0)
	var ct2 := "팀컬러 — %s" % _color_name()
	Art.txt(self, cb.position + Vector2(cb.size.x * 0.5 - Art.txt_w(ct2, 13) * 0.5, 19), ct2, 13,
		P.TEXT if lit else P.TEXT_DIM)

func _color_btn_rect() -> Rect2:
	var r := _anal_rect()
	return Rect2(r.position.x + 8.0, r.position.y + r.size.y - 32.0, r.size.x - 16.0, 26.0)

func _color_name() -> String:
	# 두 개까지 켜지므로 **켠 것을 다 적습니다** — 하나만 적으면 나머지 하나가
	# 붙어 있는지 화면에서 알 수 없습니다.
	var on: Array = []
	for e in color_list:
		if Sv.color_ids.has(str((e as Dictionary)["id"])):
			on.append(str((e as Dictionary)["name"]))
	if not on.is_empty():
		return " + ".join(on)
	if color_list.is_empty():
		return "켤 수 있는 것이 없습니다"
	return "%d개 켤 수 있음" % color_list.size()


var color_list: Array = []

# **구종 탭은 테스트 빌드에서만 보입니다.** 구종은 카드 id 로 그때그때 만드는
# 것이라 사람이 손댈 것이 없어서, 정식 빌드에서는 탭 하나를 차지할 값어치가
# 없습니다. 큰 화면(카드 상세)에는 그대로 나오므로 볼 수는 있습니다.
const GROW_TABS_ALL := ["유학", "스킬블록", "구종"]

func _grow_tabs() -> Array:
	return GROW_TABS_ALL if OS.has_feature("testbuild") else GROW_TABS_ALL.slice(0, 2)

func _grow_tab_rect(i: int) -> Rect2:
	var b := _body()
	return Rect2(b.position.x + i * 100.0, b.position.y + 8.0, 96.0, 28.0)

func _draw_study_tabs(c: Dictionary) -> void:
	# 갈래 탭. 원작의 `계약연장 / 유학 / 전력보강` 자리입니다.
	# **카드 격자 다음에 그립니다** — 위로 밀린 카드가 판 위쪽을 넘어 탭 줄을
	# 덮었습니다(`_draw()` 에는 클리핑이 없습니다). 지우고 다시 그려야 합니다.
	var b := _body()
	draw_rect(Rect2(b.position, Vector2(b.size.x, 44.0)), P.BG, true)
	for i in range(_grow_tabs().size()):
		if i == 2 and str(c.get("kind", "")) != "pitcher":
			continue   # 구종은 투수만
		var tr := _grow_tab_rect(i)
		var on := i == grow_tab
		draw_rect(tr, P.PANEL_HI if on else P.PANEL, true)
		draw_rect(tr, P.hdr(P.BAR_MID, 1.2) if on else P.LINE, false, 2.0 if on else 1.0)
		Art.txt(self, tr.position + Vector2(tr.size.x * 0.5 - Art.txt_w(str(_grow_tabs()[i]), 14) * 0.5, 19.0),
			str(_grow_tabs()[i]), 14, P.TEXT if on else P.TEXT_DIM)
	Art.txt(self, Vector2(b.position.x + 320.0, b.position.y + 27.0),
		"%s · 위로 갈수록 유학지가 늘어납니다   ·   유학은 COST 를 올리지 않습니다" % D.tier_name(Sv.tier),
		13, P.TEXT_FAINT)

func _draw_study() -> void:
	var c := DB.find(_study_sel())

	# ── 왼쪽 : 보유 카드 격자 ──
	var p := _study_panel()
	Art.panel(self, p, P.a(P.PANEL_HI, 0.32), P.LINE, 1.0)
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
	# 목록 칸 밖으로 넘친 카드를 지웁니다(`_mask_list` 설명 참고).
	# **화면 꼭대기까지 지웁니다** — 판 위쪽 62px 만 지우던 시절에는 카드 한 장
	# (137px)의 나머지가 탭 줄과 제목 띠 위로 그대로 올라갔습니다.
	# 지운 것들은 아래에서 다시 그립니다 — 제목 띠는 `_draw_bar`,
	# 탭 줄은 `_draw_study_tabs`, 판 머리글과 거르개는 여기서.
	_mask_list(a, 0.0, p.position.x, p.size.x, p)
	_draw_bar()
	var sbn := Rect2(p.position, Vector2(p.size.x, 62.0))
	draw_rect(sbn, P.a(P.PANEL_HI, 0.32), true)
	draw_rect(p, P.LINE, false, 1.0)
	Art.txt(self, Vector2(p.position.x + 8.0, p.position.y + 20.0),
		"보유선수 %d명" % study_list.size(), 14, P.hdr(P.BAR_MID, 1.15))
	_draw_study_chips()

	_draw_study_tabs(c)

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
	# **평생 한 번**이라 "몇 곳 다녀왔나"가 아니라 "다녀왔나 아닌가"를 적습니다.
	var line := "유학 안 다녀옴 — 한 번만 갈 수 있습니다"
	if not done.is_empty():
		var nm: Array = []
		for i in done:
			nm.append(str(D.ABROAD[int(i)]["name"]))
		line = "유학 완료 — %s (다시 못 갑니다)" % ", ".join(nm)
	if Sv.away(id):
		line = "%s 유학 중 (%d경기 남음)" % [str(D.ABROAD[Sv.away_region(id)]["name"]), Sv.away_left(id)]
	elif Sv.in_order(id):
		# **막는 이유는 위에 한 번 크게 적습니다.** 지역 줄마다 붙는 꼬리표는 작아서
		# 여섯 줄이 전부 같은 이유일 때 오히려 안 읽힙니다.
		line = "작전에 든 카드입니다 — 오더에서 빼야 유학을 보낼 수 있습니다"
	Art.txt(self, Vector2(s.position.x + 10.0, s.position.y + 168.0), line, 13, P.TEXT_FAINT)
	Art.txt(self, Vector2(s.position.x + 10.0, s.position.y + 186.0),
		"한 곳당 스텟 하나 +%d.  누르면 확인 창이 뜹니다.   [Q][W][E][R][T][Y]" % D.AB_UP,
		12, P.TEXT_FAINT)
	# 카드 자체가 막혔으면 그 이유는 지역과 상관없이 모든 줄에 똑같이 나옵니다.
	var card_why := Sv.can_study(id, -1)
	var ids := _region_ids()
	for row in range(ids.size()):
		var i: int = int(ids[row])
		var r := _region_rect(row)
		var been := done.has(i)
		var why := Sv.can_study(id, i)
		var can := why == ""
		var up := D.abroad_up(i)
		draw_rect(r, P.PANEL_HI if can else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if can else P.LINE, false, 2.0 if can else 1.0)
		Art.txt(self, r.position + Vector2(12, 24), str(D.ABROAD[i]["name"]), 16,
			P.TEXT if can else P.TEXT_DIM)
		var ups := ""
		for k in up:
			ups += "%s +%d" % [str(D.ST_NAME.get(k, k)), int(up[k])]
		Art.txt(self, r.position + Vector2(100, 24), ups, 13,
			P.hdr(P.BAR_HIGH, 1.1) if can else P.TEXT_FAINT)
		Art.txt(self, r.position + Vector2(12, 44),
			"%s · %d경기 · %d코인" % [D.tier_name(int(D.ABROAD[i]["tier"])),
			int(D.ABROAD[i]["days"]), int(D.ABROAD[i]["coin"])], 12, P.TEXT_FAINT)
		# **안 되는 이유를 그 자리에 적습니다** — 눌러 보고 나서야 아는 것보다
		# 무엇을 채우면 열리는지 미리 보이는 쪽이 낫습니다.
		# 카드 하나가 통째로 막힌 이유(작전에 들었다 · 유학 중이다)는 **위에 한 줄로
		# 이미 적었습니다.** 여섯 줄에 같은 말을 또 붙이면 정작 지역마다 다른 이유
		# (등급이 모자란다 · 코인이 모자란다)가 그 안에 묻힙니다.
		var tag := "다녀옴" if been else ("" if (can or why == card_why) else why)
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
	for k in D.abroad_up(study_modal):
		ups += "%s +%d" % [str(D.ST_NAME.get(k, k)), D.AB_UP]
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
	var why := Sv.can_study(DB.card_id(c), study_modal)
	# **안 되는 이유는 이 줄에 적습니다.** 단추 안에 넣으면 긴 이유가 140px 짜리
	# 단추 밖으로 삐져나가 카드 위에 겹칩니다(실제로 그랬습니다).
	Art.txt(self, Vector2(x, y + 6.0),
		why if why != "" else "유학 중에는 작전에 넣을 수 없고, 중도 취소가 안 됩니다.",
		12, P.WARN)
	Art.txt(self, Vector2(x, y + 24.0), "COST 는 오르지 않습니다.", 12, P.TEXT_FAINT)

	var ok := _study_ok_rect()
	draw_rect(ok, P.PANEL_HI if why == "" else P.PANEL, true)
	draw_rect(ok, P.hdr(P.BAR_HIGH, 1.2) if why == "" else P.LINE, false, 2.0)
	var t := "확인" if why == "" else "보낼 수 없음"
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

# 가방 자리 — **판 오른쪽에 두 줄.** 몇 줄이 들어가는지는 판 높이에서 계산합니다.
const BAG_ROW := 30.0
const BAG_COLS := 2

func _bag_area() -> Rect2:
	# **아래 안내 글자 위에서 끝나야 합니다.** 예전에는 여유를 상수로 84 만 뒀는데
	# 안내가 `s.y + 500` 에 있어서 가방이 그 위를 덮었습니다 — 블록이 열몇 개만
	# 되어도 조작 안내가 통째로 안 보였습니다. 이제 안내 자리에서 거꾸로 잽니다.
	#
	# **폭은 판 오른쪽 끝까지 씁니다.** 336 으로 박아 두었을 때는 오른쪽이 통째로
	# 비어 있는데도 칸이 좁아서 이름밖에 못 적었습니다 — 그 블록이 **무슨 스텟을
	# 얼마나** 올려 주는지를 적을 자리가 없었습니다.
	var s := _study_side()
	var top := s.position.y + 200.0
	return Rect2(s.position.x + 218.0, top, maxf(s.size.x - 230.0, 240.0),
		maxf(_study_note_y() - 10.0 - top, BAG_ROW))

# 조작 안내 첫 줄의 y. 판 맨 아래에 붙입니다.
func _study_note_y() -> float:
	var s := _study_side()
	return s.position.y + s.size.y - 44.0

func _bag_rows() -> int:
	return maxi(int(_bag_area().size.y / BAG_ROW), 1)

func _bag_rect(i: int) -> Rect2:
	# `i` 는 **보이는 자리 번호**입니다(스크롤을 이미 뺀 값).
	# 칸 폭은 가방 폭에서 나눕니다 — 상수로 박으면 판이 넓어져도 칸은 그대로라
	# 오른쪽이 비어 있는데 글자가 잘립니다.
	var a := _bag_area()
	var w := a.size.x / float(BAG_COLS)
	@warning_ignore("integer_division")
	var col := i / _bag_rows()
	return Rect2(a.position.x + col * w,
		a.position.y + (i % _bag_rows()) * BAG_ROW, w - 8.0, BAG_ROW - 4.0)

# 가방 거르개 자리 — **둘입니다**(올리는 스텟 · 모양). 한 팩에 열 개가 쏟아지므로
# 가방이 금세 수십 개가 되는데, 판에 남은 빈 자리는 모양이 정해져 있어서
# **"ㄴ 자리가 비었다" 를 바로 못 찾으면 하나씩 끌어다 대 보는 수밖에** 없습니다.
func _bag_chip_rect(i: int) -> Rect2:
	var a := _bag_area()
	return Rect2(a.position.x + i * (CHIP_W + 8.0), a.position.y - 30.0, CHIP_W, CHIP_H)

func _bag_chip() -> Array:
	# 카드 갈래에 맞는 스텟만 내놓습니다 — 타자 카드에 구위 거르개는 뜻이 없습니다.
	var c := DB.find(_study_sel())
	var opts: Array = [["전체", ""]]
	for k in D.stats_of("pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"):
		opts.append([str(D.ST_NAME.get(k, k)), str(k)])
	# 모양은 **값(`SHAPE_MUL`)을 같이 적습니다** — 왜 같은 스킬인데 어떤 것이
	# 더 많이 올려 주는지가 여기서 읽혀야 고를 때 뜻이 생깁니다.
	var shp: Array = [["전체", ""]]
	# **값이 낮은 것부터** 늘어놓습니다 — 목록 자체가 "ㅁ 가 제일 쉽고 S·Z 가
	# 제일 세다" 는 사다리로 읽힙니다. 사전 순서로 두면 L·S·Z·l·ㄴ·ㅁ·ㅗ 라
	# 아무 뜻이 없습니다. 값이 같으면 이름순이라 순서가 흔들리지 않습니다.
	var names: Array = Gr.SHAPES.keys()
	names.sort_custom(func(a, b):
		var ma: float = Gr.SHAPE_MUL.get(str(a), 1.0)
		var mb: float = Gr.SHAPE_MUL.get(str(b), 1.0)
		return str(a) < str(b) if ma == mb else ma < mb)
	for s in names:
		shp.append(["%s 형  ×%.2f" % [str(s), float(Gr.SHAPE_MUL.get(str(s), 1.0))], str(s)])
	return [
		["올리는 스텟", "전체" if g_bst == "" else str(D.ST_NAME.get(g_bst, g_bst)), opts, g_bst],
		["모양", "전체" if g_bsh == "" else "%s 형" % g_bsh, shp, g_bsh],
	]


# 가방 거르개. **펼침 상태를 따로 둡니다**(`bag_i`) — 카드 거르개와 `combo_i` 를
# 같이 쓰면 하나를 열 때 다른 하나가 같이 열립니다.
func _bag_item_rect(i: int, j: int) -> Rect2:
	var r := _bag_chip_rect(i)
	return Rect2(r.position.x, r.position.y + CHIP_H + 2.0 + j * COMBO_ROW, CHIP_W, COMBO_ROW)

func _draw_bag_filter() -> void:
	var list := _bag_chip()
	for i in range(list.size()):
		var e: Array = list[i]
		var r := _bag_chip_rect(i)
		var on := str(e[1]) != "전체"
		var open := bag_i == i
		draw_rect(r, P.PANEL_HI if (on or open) else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_MID, 1.15) if (on or open) else P.LINE, false, 1.0)
		Art.txt(self, r.position + Vector2(8, 18), "%s %s" % [str(e[0]), str(e[1])], 13,
			P.TEXT if on else P.TEXT_DIM)
		Art.txt(self, r.position + Vector2(r.size.x - 15, 18), "▾", 11, P.TEXT_FAINT)
	# **펼친 목록은 칩을 다 그린 다음에** — 칩 그리는 자리에서 같이 그리면
	# 다음 칩이 그 위에 얹힙니다.
	if bag_i < 0 or bag_i >= list.size():
		return
	var cur: Array = list[bag_i]
	var opts: Array = cur[2]
	var cr := _bag_chip_rect(bag_i)
	Art.panel(self, Rect2(cr.position.x, cr.position.y + CHIP_H,
		CHIP_W, opts.size() * COMBO_ROW + 4.0), P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	for j in range(opts.size()):
		var o: Array = opts[j]
		var ir := _bag_item_rect(bag_i, j)
		var sel: bool = str(o[1]) == str(cur[3])
		if sel:
			draw_rect(ir, P.PANEL_HI, true)
		Art.txt(self, ir.position + Vector2(8, 17), str(o[0]), 13,
			P.hdr(P.BAR_HIGH, 1.1) if sel else P.TEXT_DIM)

func _click_bag_filter(p: Vector2) -> bool:
	# **펼친 목록부터 봅니다** — 칩을 먼저 보면 목록에서 고른 것이 그 아래 칩의
	# 클릭으로 새어 나갑니다.
	var list := _bag_chip()
	if bag_i >= 0 and bag_i < list.size():
		var opts: Array = (list[bag_i] as Array)[2]
		for j in range(opts.size()):
			if _bag_item_rect(bag_i, j).has_point(p):
				_set_bag_filter(bag_i, str((opts[j] as Array)[1]))
				bag_i = -1
				return true
		bag_i = -1
		return true
	for i in range(list.size()):
		if _bag_chip_rect(i).has_point(p):
			bag_i = i
			return true
	return false

func _set_bag_filter(i: int, v: String) -> void:
	if i == 0:
		g_bst = v
	else:
		g_bsh = v
	bag_scroll = 0

func _bag_list(c: Dictionary) -> Array:
	var out: Array = []
	for b in Gr.free_blocks("pitcher" if str(c.get("kind", "")) == "pitcher" else "hitter"):
		# **어느 스텟을 올려 주는가**로 거릅니다. 블록이 수십 개가 되면 이름만으로는
		# 원하는 것을 못 찾습니다.
		if g_bst != "":
			var up: Dictionary = Gr.skill(str((b as Dictionary).get("sid", ""))).get("up", {})
			if not up.has(g_bst):
				continue
		# **모양으로도 거릅니다.** 판에 남은 빈 자리는 모양이 정해져 있어서,
		# 그 모양만 뽑아 볼 수 있어야 "들어가는 것"을 바로 찾습니다.
		if g_bsh != "" and str((b as Dictionary).get("shape", "")) != g_bsh:
			continue
		out.append(b)
	return out

func _pitch_rect(i: int) -> Rect2:
	var s := _study_side()
	return Rect2(s.position.x + 12.0, s.position.y + 210.0 + i * 44.0, s.size.x - 24.0, 38.0)

func _draw_rect_btn(i: int) -> Rect2:
	var s := _study_side()
	return Rect2(s.position.x + 12.0, s.position.y + 408.0 + i * 34.0, 190.0, 30.0)


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
	var ups := _ups_text(tot)
	Art.txt(self, Vector2(x + 92.0, ty), ups if ups != "" else "—", 13, P.UP)

	for i in range(2):
		var r := _draw_rect_btn(i)
		var lab: String = ["남은 블록 자동으로 채우기", "판 비우기"][i]
		draw_rect(r, P.PANEL_HI, true)
		draw_rect(r, P.LINE, false, 1.0)
		Art.txt(self, r.position + Vector2(12, 20), lab, 13, P.TEXT_DIM)

	# 가방 — 안 낀 블록들. **전체를 볼 수 있어야 합니다**: 예전에는 12개만 그리고
	# "… 그리고 N개 더" 로 끝내서, 13번째부터는 있는 줄 알아도 꺼낼 수가 없었습니다.
	var bag := _bag_list(c)
	var rows := _bag_rows()
	var per := rows * BAG_COLS
	bag_scroll = clampi(bag_scroll, 0, maxi(bag.size() - per, 0))
	var head2 := "가방 %d개" % bag.size()
	if bag.size() > per:
		head2 += "  (%d~%d · 휠로 넘기기)" % [bag_scroll + 1, mini(bag_scroll + per, bag.size())]
	Art.txt(self, Vector2(s.position.x + 218.0, s.position.y + 168.0),
		head2, 14, P.hdr(P.BAR_MID, 1.15))
	# 조작 안내는 단추 아래에 한 줄로. 위에 두면 칸 수 · 가방 머리글과 겹칩니다.
	Art.txt(self, Vector2(x, _study_note_y()),
		"블록을 끌어다 판에 놓습니다.  우클릭으로 빼고, 가운데 버튼으로 돌립니다.",
		13, P.TEXT_FAINT)
	Art.txt(self, Vector2(x, _study_note_y() + 20.0),
		"[Q][W][E][R][T] 로 가방의 블록을 넣습니다.", 13, P.TEXT_FAINT)
	for i in range(mini(bag.size() - bag_scroll, per)):
		var bb: Dictionary = bag[bag_scroll + i]
		var r := _bag_rect(i)
		var held := drag_uid == int(bb["uid"])
		draw_rect(r, P.PANEL_HI if held else P.PANEL, true)
		draw_rect(r, P.hdr(P.BAR_HIGH, 1.2) if held else P.LINE, false, 1.0)
		Art.block_icon(self, r.position + Vector2(6, 5), 4.2, bb,
			Art.BLOCK_COLS[(bag_scroll + i) % Art.BLOCK_COLS.size()])
		# **얼마나 올려 주는지를 칸에 그대로 적습니다.** 이름만 있으면 모양 배수
		# (`Gr.SHAPE_MUL`)가 곱해진 **실제 값**을 알 수가 없어서, 끼워 본 뒤 카드
		# 스텟을 다시 세는 것 말고는 방법이 없었습니다 — 같은 `선구안` 이라도
		# ㅁ형은 +3, Z형은 +4 입니다.
		var ups2 := _ups_text(Gr.block_value(bb))
		var nm2 := Gr.block_name(bb)
		# 이름과 값이 겹치면 **모양 꼬리(`·ㅁ형`)를 뗍니다.** 모양은 왼쪽 그림이
		# 이미 보여 주지만, 얼마나 오르는지는 여기 말고 볼 데가 없습니다.
		if Art.txt_w(nm2, 13) > r.size.x - 46.0 - Art.txt_w(ups2, 12):
			nm2 = str(Gr.skill(str(bb.get("sid", ""))).get("name", "?"))
		Art.txt(self, r.position + Vector2(32, 19), nm2, 13, P.TEXT_DIM)
		Art.txt(self, Vector2(r.position.x + r.size.x - 8.0 - Art.txt_w(ups2, 12),
			r.position.y + 19.0), ups2, 12, P.UP)
	if bag.is_empty():
		Art.txt(self, Vector2(s.position.x + 218.0, s.position.y + 214.0),
			"블록이 없습니다 — [스카우트] 에서 뽑거나 거르개를 푸세요.", 13, P.TEXT_FAINT)

	# 끌고 있는 블록은 손끝에 그립니다.
	# 거르개는 가방 칸 **다음에** 그립니다 — 펼친 목록이 칸을 덮어야 합니다.
	_draw_bag_filter()
	if drag_uid >= 0:
		var db := Gr.block(drag_uid)
		Art.block_icon(self, drag_pos - Art.block_icon_size(db, 13.0) * 0.5, 13.0, db,
			P.hdr(P.BAR_HIGH, 1.15))
	_draw_block_hover(c, br, open, bag, per)

# **마우스를 올린 것이 무엇이고 얼마를 올려 주는지 풍선으로 적습니다.**
# 판에는 조각 색밖에 안 보이고 가방 칸은 한 줄이라, 이게 없으면 "이 자리에 있는
# 것을 빼면 카드가 얼마나 약해지는가"를 끼웠다 뺐다 하며 세는 수밖에 없습니다.
#
# **그리기 함수 안에서 상태를 만들지 않습니다** — 마우스 자리를 그때그때 읽어
# 그리기만 합니다(`_process` 가 매 프레임 다시 그립니다).
func _draw_block_hover(c: Dictionary, br: Rect2, open: Array, bag: Array, per: int) -> void:
	# 끌고 있으면 손에 든 것을 설명합니다 — 어디에 놓을지 고르는 동안이
	# 그 값을 제일 알고 싶은 때입니다.
	if drag_uid >= 0:
		_block_tip(hover_pos, c, Gr.block(drag_uid), false)
		return
	# 거르개가 펼쳐져 있으면 그 목록이 가방 위에 있으므로 풍선을 안 띄웁니다.
	if bag_i >= 0:
		return
	var h := _hover_block(c, hover_pos, bag, per)
	if not h.is_empty():
		_block_tip(hover_pos, c, h["b"], bool(h["on_board"]))
		return
	# 잠긴 칸에는 **언제 열리는지**를 적습니다. 칸이 열리는 차례가 카드마다
	# 달라서(`Gr.unlock_order`) 화면의 "다음 N경기" 한 줄로는 이 칸을 못 셉니다.
	var hc := Art.cell_at(br, hover_pos)
	if hc >= 0 and not open.has(hc):
		_tip(hover_pos, "잠긴 칸", [["출전 %d경기에 열립니다 (지금 %d경기)"
			% [Gr.cell_opens_at(c, hc), Gr.games(DB.card_id(c))], P.TEXT_DIM]])

func _hover_block(c: Dictionary, at: Vector2, bag: Array, per: int) -> Dictionary:
	# 마우스 밑에 있는 블록 — 판의 칸이든 가방 칸이든. **그리기와 검사가 같은
	# 함수를 봅니다**(`--clicktest` 가 이걸로 풍선이 뜨는지 확인합니다).
	# 비어 있으면 `{}`.
	var hc := Art.cell_at(_board_rect(), at)
	if hc >= 0:
		var uid := int((Gr.board(c)["cell"] as Dictionary).get(hc, -1))
		return {} if uid < 0 else {"b": Gr.block(uid), "on_board": true}
	for i in range(mini(bag.size() - bag_scroll, per)):
		if _bag_rect(i).has_point(at):
			return {"b": bag[bag_scroll + i], "on_board": false}
	return {}

func _ups_text(up: Dictionary) -> String:
	# `{"contact": 3}` → `교타 +3`. 세 곳(가방 · 낀 목록 · 풍선)이 같은 함수를
	# 봐야 같은 블록이 화면마다 다른 값으로 보이는 일이 없습니다.
	var out: Array = []
	for k in up:
		out.append("%s +%d" % [str(D.ST_NAME.get(k, k)), int(up[k])])
	return " · ".join(out)

func _stat_with(c: Dictionary, k: String, add: int) -> int:
	# 그 칸의 최종 값에 `add` 를 얹으면 얼마가 되는가.
	# **상한(`D.STAT_MAX`)에 걸려 잘린 몫까지 "+N" 이라고 쓰면 카드에 찍힌 숫자와
	# 안 맞아서 보너스가 거짓말이 됩니다.** 그래서 지금 값에서 더하고 빼지 않고
	# **원본 + 보너스 합**에서 다시 계산합니다 — 그래야 130 에 붙은 카드에서
	# 블록을 빼도 값이 안 움직이는 것이 그대로 보입니다.
	var id := DB.card_id(c)
	var st: Dictionary = c.get("st", {})
	var base_v := int((DB.base(id).get("st", {}) as Dictionary).get(k, int(st.get(k, 0))))
	var src: Dictionary = c.get("up_src", {})
	var raw := int((src.get("study", {}) as Dictionary).get(k, 0)) \
		+ int((src.get("block", {}) as Dictionary).get(k, 0))
	return clampi(base_v + raw + add, 1, D.STAT_MAX)

func _block_tip(at: Vector2, c: Dictionary, b: Dictionary, on_board: bool) -> void:
	if b.is_empty() or c.is_empty():
		return
	var lines: Array = []
	var val := Gr.block_value(b)
	for k in val:
		var v := int(val[k])
		# 판에 있는 것은 **이미 얹혀 있으므로** "빼면 얼마" 를, 가방에 있는 것은
		# "놓으면 얼마" 를 보여 줍니다. 둘 다 화살표 왼쪽이 지금 값입니다.
		var before := _stat_with(c, str(k), -v if on_board else 0)
		var after := _stat_with(c, str(k), 0 if on_board else v)
		var got := after - before
		var nm := str(D.ST_NAME.get(k, k))
		if got <= 0:
			lines.append(["%s %d — 상한(%d)이라 안 오릅니다" % [nm, after, D.STAT_MAX], P.TEXT_FAINT])
		elif on_board:
			lines.append(["%s %d → %d  (이 블록 +%d)" % [nm, before, after, got], P.UP])
		else:
			lines.append(["%s %d → %d  (+%d)" % [nm, before, after, got], P.UP])
	lines.append(["기준값 %s · %s형 배수 ×%.2f" % [_ups_text(Gr.skill(str(b.get("sid", ""))).get("up", {})),
		str(b.get("shape", "ㅁ")), float(Gr.SHAPE_MUL.get(str(b.get("shape", "ㅁ")), 1.0))],
		P.TEXT_FAINT])
	lines.append(["판에 낀 블록 — 우클릭으로 빼기 · 가운데 버튼으로 돌리기" if on_board
		else "가방의 블록 — 판으로 끌어다 놓습니다", P.TEXT_FAINT])
	_tip(at, Gr.block_name(b), lines)

func _tip(at: Vector2, title: String, lines: Array) -> void:
	# 마우스 옆에 뜨는 작은 판. **화면 밖으로 나가지 않게 접습니다** — 판 오른쪽
	# 끝 칸에서는 그냥 두면 글자가 잘립니다.
	var w := Art.txt_w(title, 13) + 24.0
	for l in lines:
		w = maxf(w, Art.txt_w(str((l as Array)[0]), 12) + 24.0)
	var h := 34.0 + lines.size() * 17.0
	var r := Rect2(minf(at.x + 16.0, size.x - w - 6.0), minf(at.y + 14.0, size.y - h - 6.0), w, h)
	Art.panel(self, r, P.PANEL, P.hdr(P.BAR_MID, 1.2), 2.0)
	Art.txt(self, r.position + Vector2(11, 20), title, 13, P.TEXT)
	var ly := r.position.y + 40.0
	for l in lines:
		Art.txt(self, Vector2(r.position.x + 11.0, ly), str((l as Array)[0]), 12,
			(l as Array)[1] as Color)
		ly += 17.0

func _draw_pitches(c: Dictionary) -> void:
	var s := _study_side()
	var x := s.position.x + 12.0
	# **구종은 스텟을 안 올립니다.** 예전에는 등급마다 구위·변화구에 최대 +8 이
	# 붙었는데, 야수에는 짝이 되는 축이 없어 오래 굴린 투수만 공짜로 세졌습니다.
	Art.txt(self, Vector2(x, s.position.y + 172.0),
		"구종 등급은 그 구종이 기대는 스텟이 정합니다 — 유학·스킬블록으로 그 칸을 올리면 승급합니다.",
		13, P.TEXT_FAINT)
	Art.txt(self, Vector2(x, s.position.y + 192.0),
		"등급은 스텟을 올려 주지 않습니다 — 어디까지 키웠는지 보여 주는 표시입니다.",
		13, P.TEXT_FAINT)
	var cadd := _color_add(c)
	var ps := Gr.pitches_of(c, cadd)
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
		# **다음 등급까지 얼마 남았는지**를 적습니다 — 블록 한 장(+3~4)으로는 계단을
		# 못 넘는 일이 많아서, 이게 없으면 아무 일도 안 일어난 것처럼 보입니다.
		var nx := int(p["need"])
		var sv := mini(int((c.get("st", {}) as Dictionary).get(str(p["stat"]), 0)) + cadd, D.STAT_MAX)
		var note := "(%s %d)" % [str(D.ST_NAME.get(str(p["stat"]), "")), sv]
		if nx > 0:
			note += "  다음 등급까지 +%d" % nx
		Art.txt(self, r.position + Vector2(400, 26), note, 13, P.TEXT_FAINT)

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
	# **마우스가 지나간 자리를 우리가 직접 셉니다.** 스킬블록 풍선(`_tip`)이
	# 이걸 보는데, `get_local_mouse_position()` 은 창 밖에 나가 있거나 검사가
	# 이벤트를 흘려보낼 때 실제로 움직인 자리와 달라집니다.
	if e is InputEventMouseMotion:
		hover_pos = (e as InputEventMouseMotion).position
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
	# **검색칸이 글자를 먹는 동안에는 단축키가 안 먹습니다** — 안 그러면 이름에 든
	# 숫자가 화면 전환 단축키(1~5)로 새어 나가고, 자음/모음이 [P]·[C] 같은 것을
	# 건드립니다. 큰 화면이 떠 있으면 검색보다 그쪽이 먼저입니다.
	if screen == S.DEX and detail.is_empty() and _dex_type(e):
		return
	if e.keycode == KEY_ESCAPE:
		# 뽑기 결과 → 큰 화면 → 고르기 창 → 게임 종료 순으로 닫습니다.
		if pack_open:
			pack_open = false
			return
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
	# 결과 창이 떠 있으면 **`Enter` 는 다시뽑기**입니다 — 마우스에만 두면 키로는
	# 창을 닫고 팩을 다시 찾아 눌러야 합니다. 아직 펼치는 중이면 먼저 펼칩니다.
	if pack_open and (e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER or e.keycode == KEY_SPACE):
		if _pack_all_shown():
			_draw_pack_now(pack_i)
		else:
			pack_t = 99.0
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
			#
			# **구단도 키로 넘길 수 있어야 합니다**(`↑↓`) — 마우스로만 고를 수 있게
			# 두면 키만 쓰는 사람에게는 구단 지명 팩이 첫 구단 전용 팩이 됩니다.
			match e.keycode:
				KEY_LEFT: pack_i = maxi(0, pack_i - 1)
				KEY_RIGHT: pack_i = mini(PACKS.size() - 1, pack_i + 1)
				KEY_UP: _pack_team_step(-1)
				KEY_DOWN: _pack_team_step(1)
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
		KEY_TAB: grow_tab = (grow_tab + 1) % _grow_tabs().size()
		KEY_Q: _grow_act(0)
		KEY_W: _grow_act(1)
		KEY_E: _grow_act(2)
		KEY_R: _grow_act(3)
		KEY_T: _grow_act(4)
		KEY_Y: _grow_act(5)   # 유학지가 갈래마다 여섯 곳이라 [Y] 까지 씁니다

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
	for i in range(_grow_tabs().size()):
		if _grow_tab_rect(i).has_point(p):
			grow_tab = i
			return
	if grow_tab == 1:
		_click_blocks(p, btn)
		return
	if grow_tab != 0:
		return
	var ids := _region_ids()
	for row in range(ids.size()):
		if _region_rect(row).has_point(p):
			# **바로 보내지 않고 확인 창을 띄웁니다.** 코인이 나가고 그 카드가
			# 여러 경기 동안 작전에서 빠지는데, 잘못 누르면 되돌릴 수 없습니다.
			study_modal = int(ids[row])
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
	# **거르개부터 봅니다** — 펼친 목록이 가방 칸을 덮고 있으므로, 칸을 먼저 보면
	# 목록에서 고른 것이 블록 집기로 새어 나갑니다.
	if _click_bag_filter(p):
		return
	var bag := _bag_list(c)
	var per := _bag_rows() * BAG_COLS
	for i in range(mini(bag.size() - bag_scroll, per)):
		if _bag_rect(i).has_point(p):
			var uid2 := int((bag[bag_scroll + i] as Dictionary)["uid"])
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
	# **자란 카드로 바꿔서 엽니다.** 구단관리/작전 목록은 `DB.cards` 의 원본을
	# 그대로 들고 있어서, 그대로 띄우면 유학·스킬블록이 하나도 안 보입니다 —
	# 낀 블록이 셋인데 "추가 능력치 아직 없습니다" 가 뜨던 것이 이것입니다.
	#
	# **단 도감은 원본 그대로 엽니다**(`detail_raw`). 도감은 "이 게임에 어떤
	# 선수가 있나" 를 보는 카드 사전이지 내 카드를 보는 곳이 아닙니다 — 성장이
	# 얹힌 값이 거기 나오면 같은 카드가 화면마다 다른 숫자로 보여서, 도감의
	# 숫자로는 카드끼리 비교를 할 수가 없습니다.
	if c.is_empty():
		return false
	detail_raw = screen == S.DEX
	if detail_raw:
		var b := DB.base(DB.card_id(c))
		detail = b if not b.is_empty() else c
		return true
	var g := DB.find(DB.card_id(c))
	detail = g if not g.is_empty() else c
	return true

func _click(e: InputEventMouseButton) -> void:
	# **뽑기 결과 창이 떠 있으면 그것부터** — 아무 데나 누르면 펼치고 닫습니다.
	# 휠까지 여기서 삼킵니다: 뒤 목록이 스크롤되면 창을 닫았을 때 엉뚱한 자리에
	# 가 있습니다. **맨 위에 두세요** — 아래 분기로 새면 결과를 보는 중에 팩이
	# 또 뽑힙니다.
	if pack_open:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_pack_click(e.position)
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_UP:
		var d := 60.0 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -60.0
		# **펼친 거르개가 있으면 휠은 그 목록의 것입니다.** 시즌은 27개인데 한
		# 번에 14줄만 보이므로, 휠이 뒤 카드 격자로 새면 목록 아래쪽(옛 시즌)에는
		# 영영 닿지 못합니다 — 목록에 "휠로 넘기기" 라고 적어 두고도 그랬습니다.
		if combo_i >= 0:
			combo_scroll = maxi(0, combo_scroll + (3 if d > 0.0 else -3))
			return
		# 스킬블록 가방 위에서는 휠이 **가방의 것**입니다 — 블록이 수십 개라
		# 뒤쪽은 넘기지 않으면 영영 못 꺼냅니다.
		if screen == S.STUDY and grow_tab == 1 and _bag_area().has_point(e.position):
			bag_scroll = maxi(0, bag_scroll + (_bag_rows() if d > 0.0 else -_bag_rows()))
			return
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
			# 검색칸을 누르면 글자를 받고, 딴 데를 누르면 놓습니다.
			dex_focus = _dex_search_rect().has_point(e.position)
			if dex_focus:
				return
			for i in range(dex.size()):
				if _grid_rect(i).has_point(e.position):
					dex_i = i
					_open_detail(dex[i])   # 누르면 큰 화면
					return
		S.SCOUT:
			# **펼친 구단 목록부터 봅니다** — 팩을 먼저 보면 목록에서 고른 것이
			# 그 아래 팩의 "뽑기" 로 새어 나가서 코인이 나갑니다.
			if _click_pack_team(e.position):
				return
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
	# 켠 것 중 **마지막 것**을 목록에서 앞뒤로 옮깁니다. 빈 칸("")을 앞에 두어
	# 끌 수도 있게 합니다.
	var ids: Array = [""]
	for e in color_list:
		ids.append(str(e["id"]))
	var cur := str(Sv.color_ids[Sv.color_ids.size() - 1]) if not Sv.color_ids.is_empty() else ""
	var i := ids.find(cur)
	if i < 0:
		i = 0
	var nxt := str(ids[posmod(i + d, ids.size())])
	if not Sv.color_ids.is_empty():
		Sv.color_ids.remove_at(Sv.color_ids.size() - 1)
	if nxt != "" and not Sv.color_ids.has(nxt) and Sv.color_ids.size() < Col.MAX_ACTIVE:
		Sv.color_ids.append(nxt)
	Sv.save_game()

func _grow_act(i: int) -> void:
	# 오른쪽 갈래에 따라 같은 키가 다른 일을 합니다.
	if grow_tab == 1:
		_do_skill(i)
	elif grow_tab == 0:
		# 키로도 **확인 창을 거칩니다** — 마우스와 다른 길로 보내지면
		# 실수로 눌렀을 때 되돌릴 방법이 키 쪽에만 없게 됩니다.
		# **클릭과 같은 목록(`_region_ids`)을 봅니다** — 따로 세면 타자 화면의
		# [R] 이 투수 유학지를 가리키게 됩니다.
		var ids := _region_ids()
		if i < ids.size():
			study_modal = int(ids[i])

func _hit(r: Rect2, right: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = r.position + r.size * 0.5
	Input.parse_input_event(e)

func _hover(r: Rect2) -> void:
	# 마우스를 그 자리로 옮기는 시늉. **설명 풍선은 마우스 자리(`hover_pos`)를
	# 보므로**, 옮겨 보지 않으면 검사가 아무것도 확인하지 못합니다.
	# (`_move` 는 도감의 칸 이동이라 이름이 겹칩니다.)
	var m := InputEventMouseMotion.new()
	m.position = r.position + r.size * 0.5
	Input.parse_input_event(m)

func _wheel(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	e.position = size * 0.5
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

func _press(code: int, uni: int = 0) -> void:
	# 키 하나를 눌러 봅니다. **클릭만 검사하면 키 쪽 분기가 조용히 어긋납니다** —
	# 스카우트의 Enter 가 언제나 선수 팩을 뽑던 것이 그렇게 오래 숨어 있었습니다.
	# `uni` 는 글자를 받는 칸(도감 검색)을 시험할 때 씁니다 — `keycode` 만으로는
	# 무슨 글자인지 알 수 없어서 한글을 못 넣습니다.
	var e := InputEventKey.new()
	e.keycode = code
	e.unicode = uni
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
			_ok("팀컬러 클릭 → 켜짐", color_list.is_empty() or not Sv.color_ids.is_empty())
			# **조건이 깨진 팀컬러는 오더가 바뀔 때 꺼져야 합니다.** 켜 둔 채로
			# 두면 화면에는 붙어 있는데 경기에는 안 붙습니다 — `Col.picked_many`
			# 가 조건을 만족한 것 중에서만 고르기 때문입니다. 조건을 절대 만족할
			# 수 없는 id 를 하나 끼워 두고 오더를 건드려 봅니다.
			var _cl_n := Sv.color_ids.size()
			Sv.color_ids.append("없는컬러|S")
			_refresh_pool()
			_ok("조건이 깨진 팀컬러는 오더가 바뀔 때 꺼짐",
				Sv.color_ids.size() == _cl_n and not Sv.color_ids.has("없는컬러|S"))
			order_tab = 0
			_hit(_back_rect())
		20:
			_ok("뒤로가기 단추 → 홈", screen == S.HOME)
			_hit_menu(S.SCOUT)
		21:
			_ok("메뉴 클릭 → 스카우트", screen == S.SCOUT)
			_hit(_pack_rect(_pack_of("player")))
		22:
			_ok("선수 팩 클릭 → %d장" % D.PACK_SIZE, pack.size() == D.PACK_SIZE)
			# **결과는 모달로 뜹니다.** 화면 아래에 깔던 시절에는 팩 칸과 결과가
			# 한 화면에서 자리를 다퉜습니다. 열려 있는 동안 클릭은 전부 이 창의
			# 것이라, 검사도 창을 닫고 다음으로 가야 합니다.
			_ok("뽑으면 결과 창이 열림", pack_open)
			# 다 안 펼쳐졌으면 첫 누름은 **펼치기**입니다 — 한 번에 닫히면
			# 연출을 건너뛰려다 결과를 못 보고 닫습니다.
			pack_t = 0.0
			_hit(_pack_modal_rect())
		23:
			_ok("덜 펼쳐졌을 때 누르면 닫지 않고 펼침", pack_open and _pack_all_shown())
			# **다시뽑기** — 창을 닫고 팩을 다시 찾아 누르는 것이 매번 두 번 일이라
			# 결과 창 안에 뒀습니다. 같은 팩(`pack_i`)을 그대로 다시 뽑습니다.
			Sv.coins = D.PACK_COST
			_ct_a = str(pack.size())
			_hit(_pack_again_rect())
		24:
			_ok("다시뽑기 → 같은 팩을 다시 뽑고 창은 열린 채",
				pack_open and Sv.coins == 0 and pack.size() == int(_ct_a))
			# 다시 뽑았으면 연출도 **처음부터**여야 합니다 — 안 그러면 새 카드가
			# 이미 다 펼쳐진 채로 튀어나옵니다.
			_ok("다시뽑기는 연출을 처음부터", not _pack_all_shown())
			pack_t = 99.0
			_hit(_pack_close_rect())
		25:
			_ok("닫기 단추 → 창이 닫힘", not pack_open)
			# **구단 지명 팩** — 지명 뽑기는 그 구단만 내야 합니다. 한 번만 보면
			# 우연히 맞을 수 있으니 100번 굴려서 봅니다.
			Sv.coins = D.TEAM_PACK_COST
			var _tp := _pack_team()
			var _tonly := true
			for _k in range(100):
				if Col.lineage(str(DB.draw_one_team(rng, _tp).get("team", ""))) != _tp:
					_tonly = false
			_ok("지명 뽑기는 그 구단만 냄", _tonly)
			# **`pack` 을 비우고 누릅니다.** 앞 단계에서 뽑은 열 장이 그대로 남아
			# 있어서, 안 비우면 이 누름이 아무 일도 안 해도 검사가 통과합니다
			# (실제로 그렇게 통과했고, 그 바람에 다음 단계가 깨졌습니다).
			# 구단 팩 한가운데에는 구단 고르개가 있으므로 **뽑기 단추**를 누릅니다.
			pack.clear()
			_hit(_pack_buy_rect(_pack_of("team")))
		26:
			_ok("구단 지명 팩 클릭 → %d장" % D.PACK_SIZE, pack.size() == D.PACK_SIZE)
			# **확정 장수**입니다 — 확률로 굴리면 넷만 나오는 판이 생겨서, 지명한
			# 사람에게 "절반도 안 나옴" 이 됩니다. 여기가 그걸 못 박습니다.
			var _tm := 0
			for _c in pack:
				if Col.lineage(str((_c as Dictionary).get("team", ""))) == _pack_team():
					_tm += 1
			_ok("뽑은 열 장 중 그 구단이 %d장 이상 (%d장)" % [D.TEAM_PACK_MIN, _tm],
				_tm >= D.TEAM_PACK_MIN)
			# **코인을 블록 값에 딱 맞춰 둡니다.** 선수 팩은 못 살 만큼만 남기므로,
			# 블록이 뽑혔다면 그 누름이 **블록 팩으로 갔다는 증거**가 됩니다.
			Sv.coins = Gr.DRAW_COST
			block_pack.clear()
			pack_open = false
			_hit(_pack_rect(_pack_of("block")))
		27:
			_ok("블록 팩 클릭 → 블록 %d개" % Gr.DRAW_SIZE, block_pack.size() == Gr.DRAW_SIZE)
			_ok("블록도 결과 창으로 열림", pack_open and pack.is_empty())
			pack_open = false
			# **키로도 고른 팩이 뽑혀야 합니다.** 예전에는 Enter 가 언제나 선수 팩을
			# 뽑아서, 블록을 뽑으려던 사람에게 "코인이 모자랍니다"가 떴습니다.
			block_pack.clear()
			Sv.coins = Gr.DRAW_COST
			pack_i = _pack_of("block")
			_press(KEY_ENTER)
		28:
			_ok("[Enter] 가 고른 팩을 뽑음", block_pack.size() == Gr.DRAW_SIZE)
			pack_open = false
			# 구단 고르개 — **마우스로도 바꿀 수 있어야** 합니다.
			_ct_a = str(pack_team_i)
			_hit(_pack_team_rect(_pack_of("team")))
		29:
			_ok("구단 고르개 펼침", pack_team_open)
			var _tj := 1 if int(_ct_a) != 1 else 2
			_hit(_pack_team_item_rect(_pack_of("team"), _tj))
		30:
			_ok("목록에서 고르면 구단이 바뀜",
				not pack_team_open and str(pack_team_i) != _ct_a)
			# 키(`↑↓`)로도 바뀌어야 합니다 — 마우스에만 두면 키만 쓰는 사람에게는
			# 첫 구단 전용 팩이 됩니다.
			_ct_a = str(pack_team_i)
			_press(KEY_DOWN)
		31:
			_ok("[↓] 로 구단이 바뀜", str(pack_team_i) != _ct_a)
			Sv.coins = 50000
			_hit_menu(S.STUDY)
		32:
			_ok("메뉴 클릭 → 구단관리", screen == S.STUDY)
			# 유학 갈래에서 지역을 누르면 **확인 창**이 떠야 합니다 — 바로 보내면
			# 잘못 눌렀을 때 되돌릴 방법이 없습니다.
			grow_tab = 0
			# **갈래가 맞는 지역만 나와야 합니다.** 타자 화면에 구위 유학이 뜨면
			# 눌러 보고 나서야 못 가는 곳인 줄 알게 됩니다.
			var _ab_c := DB.find(_study_sel())
			var _ab_ids := _region_ids()
			var _ab_kind := not _ab_ids.is_empty()
			for _ab_i in _ab_ids:
				if str(D.ABROAD[int(_ab_i)]["kind"]) != str(_ab_c.get("kind", "")):
					_ab_kind = false
			_ok("유학지가 카드 갈래와 맞음 (%d곳)" % _ab_ids.size(), _ab_kind)
			_hit(_region_rect(0))
		33:
			_ok("유학 지역 클릭 → 확인 창", study_modal == int(_region_ids()[0]))
			# **평생 한 번**입니다 — 한 곳을 다녀오면 어디도 못 가야 합니다.
			var _ab_id := _study_sel()
			var _ab_keep = Sv.study_done.get(_ab_id, [])
			Sv.study_done[_ab_id] = [int(_region_ids()[0])]
			var _ab_blocked := true
			for _ab_j in _region_ids():
				if Sv.can_study(_ab_id, int(_ab_j)) == "":
					_ab_blocked = false
			_ok("한 번 다녀오면 어디도 못 감", _ab_blocked)
			Sv.study_done[_ab_id] = _ab_keep
			DB.clear_cache()
			# 갈래가 다른 지역은 애초에 막혀야 합니다.
			# **분기마다 다시 구합니다** — GDScript 의 `match` 는 분기가 각자 스코프라
			# 앞 분기에서 만든 변수가 안 넘어옵니다.
			var _ab_kk := "hitter" if str(DB.find(_ab_id).get("kind", "")) == "pitcher" else "pitcher"
			_ok("갈래가 다른 유학지는 막힘",
				Sv.can_study(_ab_id, int(D.abroad_for(_ab_kk)[0])) != "")
			# **작전에 든 카드는 유학을 못 갑니다.** 예전에는 보내면서 자리를
			# 비웠고(`pull_from_order`), 그러면 오더에 구멍이 뚫린 채로 시즌이
			# 굴러갔습니다 — `Sim.team_ok` 은 타순과 선발만 보니까요.
			var _or_id := ""
			for _g in ORDER_GROUPS:
				for _oi in range(_group_count(str(_g))):
					if _slot_id(str(_g), _oi) != "":
						_or_id = _slot_id(str(_g), _oi)
						break
				if _or_id != "":
					break
			var _or_r := int(D.abroad_for(str(DB.find(_or_id).get("kind", "")))[0])
			_ok("작전에 든 카드는 유학 못 감",
				_or_id != "" and Sv.can_study(_or_id, _or_r) == "작전에 든 카드입니다")
			_hit(_study_cancel_rect())
		34:
			_ok("확인 창 취소", study_modal == -1)
			_hit(_study_chip_rect(0))
		35:
			_ok("구단관리 거르개 펼침", combo_i == 0)
			_hit(_study_combo_item_rect(0, 0))
		36:
			_ok("거르개 목록에서 고름", combo_i == -1)
			_hit(_grow_tab_rect(1))
		37:
			_ok("구단관리 갈래 → 스킬블록", grow_tab == 1)
			# 뽑은 블록이 이 카드 종류에 맞아야 가방에 뜹니다. 맞는 카드를 고릅니다.
			for i in range(study_list.size()):
				if not _bag_list(DB.find(DB.card_id(study_list[i]))).is_empty():
					study_i = i
					break
			_hit(_study_cell(study_i))
		38:
			_ok("구단관리 카드 격자 클릭", not study_list.is_empty())
			# 블록을 가방에서 집어 판에 떨굽니다 — **드래그가 실제로 되는지**
			# 보는 유일한 길입니다.
			_hover(_bag_rect(0))
			_hit(_bag_rect(0))
		39:
			_ok("가방 블록 집기 → 드래그 시작", drag_uid >= 0)
			# **가방 칸에 마우스를 올리면 그 블록의 설명 풍선이 떠야 합니다.**
			# 그리기와 검사가 `_hover_block` 하나를 같이 봅니다.
			var _hbag := _hover_block(DB.find(_study_sel()), hover_pos,
				_bag_list(DB.find(_study_sel())), Gr.CELLS * 4)
			_ok("가방 칸에 마우스를 올리면 그 블록이 잡힘",
				not _hbag.is_empty() and not bool(_hbag["on_board"]))
			# 모양마다 들어가는 자리가 다르므로 **되는 자리를 찾아서** 떨굽니다.
			# 칸을 하나 박아 두면 I 자 블록이 뽑힌 판에서만 실패합니다.
			var cc := DB.find(_study_sel())
			var dest := 0
			for o in range(Gr.CELLS):
				if Gr.can_put(cc, drag_uid, o) == "":
					dest = o
					break
			_release(Art.cell_rect(_board_rect(), dest))
		40:
			var id := _study_sel()
			_ok("판에 떨구기 → 끼워짐", id != "" and not Gr.placed(id).is_empty())
			# **블록이 실제로 덮은 칸**으로 마우스를 옮겨 둡니다(다음 단계에서
			# 풍선을 봅니다). 떨군 자리(origin)를 그대로 쓰면 안 됩니다 —
			# `L`·`S` 는 왼쪽 위 칸이 조각에 안 들어가서 origin 은 빈 칸입니다.
			var _hcell := -1
			for _u in Gr.placed(id):
				var _cs := Gr.cells_of(Gr.block(int(_u)), int(Gr.placed(id)[_u]))
				if not _cs.is_empty():
					_hcell = int(_cs[0])
					break
			if _hcell >= 0:
				_hover(Art.cell_rect(_board_rect(), _hcell))
			# **가방 전체를 볼 수 있어야 합니다** — 예전에는 12개만 그리고 나머지는
			# "… N개 더" 로 끝나서 13번째부터는 꺼낼 수가 없었습니다.
			_ct_a = str(_bag_list(DB.find(_study_sel())).size())
			_ok("가방 칸이 12개보다 많이 보임", _bag_rows() * BAG_COLS > 12)
			_hit(_bag_chip_rect(0))
		41:
			# 앞 단계에서 옮겨 둔 마우스가 판의 칸 위에 있습니다.
			var _hc := DB.find(_study_sel())
			var _hb := _hover_block(_hc, hover_pos, _bag_list(_hc), Gr.CELLS * 4)
			_ok("판의 칸에 마우스를 올리면 그 블록이 잡힘",
				not _hb.is_empty() and bool(_hb["on_board"]))
			# **풍선이 적는 "78 → 81" 이 카드에 실제로 얹힌 값이어야 합니다.**
			# 상한(`D.STAT_MAX`)에 걸린 몫까지 +N 이라고 쓰면 카드에 찍힌 숫자와
			# 안 맞아서 보너스가 거짓말이 됩니다.
			var _hok := not _hb.is_empty()
			if not _hb.is_empty():
				for _k in Gr.block_value(_hb["b"]):
					var _v := int(Gr.block_value(_hb["b"])[_k])
					if _stat_with(_hc, str(_k), 0) != clampi(
							_stat_with(_hc, str(_k), -_v) + _v, 1, D.STAT_MAX):
						_hok = false
			_ok("풍선의 상승치가 카드에 얹힌 값과 같음", _hok)
			_ok("가방 스텟 거르개 펼침", bag_i == 0)
			_hit(_bag_item_rect(0, 1))
		42:
			_ok("스텟으로 거르면 목록이 줄어듦",
				g_bst != "" and bag_i < 0
				and _bag_list(DB.find(_study_sel())).size() <= int(_ct_a))
			g_bst = ""
			# **모양 거르개도 같이 봅니다.** 거르개가 둘이 되면서 "두 번째 칩을
			# 눌렀는데 첫 번째가 열린다" 가 나기 쉬운 자리입니다.
			_ct_a = str(_bag_list(DB.find(_study_sel())).size())
			_hit(_bag_chip_rect(1))
		43:
			_ok("가방 모양 거르개 펼침", bag_i == 1)
			_hit(_bag_item_rect(1, 1))
		44:
			var _sh := str(Gr.SHAPES.keys()[0])
			var _shn := 0
			for _b in _bag_list(DB.find(_study_sel())):
				if str((_b as Dictionary).get("shape", "")) == g_bsh:
					_shn += 1
			_ok("모양으로 거르면 그 모양만 남음",
				g_bsh != "" and bag_i < 0
				and _shn == _bag_list(DB.find(_study_sel())).size()
				and _bag_list(DB.find(_study_sel())).size() <= int(_ct_a))
			g_bsh = ""
			_hit_menu(S.DEX)
		45:
			_ok("메뉴 클릭 → 도감", screen == S.DEX)
			_hit(_grid_rect(3))
		46:
			# **한 화면에 다 보입니다** — 뒤집기가 없어졌으므로 구종/수비 · 기록 ·
			# 스킬블록 판이 전부 이 한 장에 그려집니다.
			_ok("도감 카드 클릭 → 큰 화면", dex_i == 3 and not detail.is_empty())
			# **팀컬러는 오더에 든 카드에만 붙습니다.** 안 보고 지금 켠 값을 그냥
			# 돌려주면 도감 1만 장 전부에 +17 이 찍혀서, 안 가진 카드까지 거짓말을
			# 합니다. 오더 밖 카드로 확인합니다.
			var _out := {}
			for _c in dex:
				if not Sv.in_order(DB.card_id(_c)):
					_out = _c
					break
			_ok("오더 밖 카드에는 팀컬러 몫이 안 붙음",
				_out.is_empty() or _color_add(_out) == 0)
			# **도감의 큰 화면은 원본이어야 합니다.** 도감은 카드 사전이라 유학 ·
			# 스킬블록 · 팀컬러가 얹힌 값이 나오면 같은 카드가 화면마다 다른
			# 숫자로 보입니다. 자란 카드는 구단관리 · 작전에서만 봅니다.
			_ok("도감 큰 화면은 원본 능력치",
				detail_raw and detail.get("st", {}) == DB.base(DB.card_id(detail)).get("st", {}))
			# 성장이 실제로 붙어 있는 카드로 봐야 검사가 뜻이 있습니다 — 블록을
			# 끼운 카드를 찾아 도감 값과 구단관리 값이 **달라야** 함을 봅니다.
			var _gid := ""
			for _cid in Sv.block_at:
				_gid = str(_cid)
				break
			_ok("성장한 카드는 도감과 구단관리 값이 다름",
				_gid == "" or DB.base(_gid).get("st", {}) != DB.find(_gid).get("st", {}))
			_hit(Rect2(Vector2(6, 6), Vector2(4, 4)))
		47:
			_ok("큰 화면 닫기", detail.is_empty())
			_hit(_grid_rect(5), true)
		48:
			_ok("도감 카드 우클릭 → 큰 화면", not detail.is_empty())
			_hit(Rect2(Vector2(6, 6), Vector2(4, 4)), true)
		49:
			_ok("우클릭으로 닫기", detail.is_empty())
			_hit(_chip_rect(1, _body().position.x, _body().position.y))
		50:
			_ok("거르개 누르면 목록이 펼쳐짐", combo_i == 1)
			_hit(_combo_item_rect(1, _body().position.x, _body().position.y, 1))
		51:
			_ok("목록에서 고르면 걸림", f_team != "" and combo_i == -1)
			# **이름 검색** — 1만 장에서는 거르개만으로 못 찾습니다.
			f_team = ""
			_refilter()
			_ct_a = str(dex.size())
			_hit(_dex_search_rect())
		52:
			_ok("검색칸 클릭 → 글자를 받음", dex_focus)
			_press(KEY_NONE, 0xC774)      # 한글 "이"
		53:
			_ok("검색칸이 글자를 먹고 화면이 안 바뀜",
				dex_q != "" and screen == S.DEX and dex.size() < int(_ct_a))
			dex_q = ""
			dex_focus = false
			_refilter()
			# 시즌 거르개는 27개 + 전체라 한 화면(14줄)에 안 들어갑니다.
			# 휠이 뒤 카드 격자로 새면 목록 아래쪽 옛 시즌에 영영 못 닿습니다.
			_hit(_chip_rect(0, _body().position.x, _body().position.y))
		54:
			_ok("시즌 거르개 펼침", combo_i == 0)
			_ct_a = str(combo_scroll)
			_wheel(true)
		55:
			_ok("펼친 목록이 휠로 내려감", combo_scroll > int(_ct_a))
			_ok("휠이 카드 격자로 안 샘", dex_scroll == 0.0)
			var _sh := _combo_shown(_dex_chips()[0][2])
			_ok("아래쪽 옛 시즌에 닿음", int((_sh[_sh.size() - 1] as Array)[1]) <= 2013)
			combo_i = -1
			_hit_menu(S.GAME)
		56:
			_ok("메뉴 클릭 → 시즌", screen == S.GAME)
			_hit(_btn_rect(0))
		57:
			_ok("시즌 단추 → 시즌 시작", Sv.season > 0)
			# **경기를 한 판 굴려 출전 수가 오르는지 봅니다.** 여기가 없어서
			# `note_game` 이 없는 함수(`Sim._members`)를 부르며 매 경기 통째로
			# 실패하는 것을 오래 몰랐습니다 — 화면에는 아무 표시도 안 나고,
			# 증상은 "시즌을 굴려도 스킬 칸이 안 열린다" 로만 나타납니다.
			_ct_a = _slot_id("lineup", 0)
			_ct_b = str(Gr.games(_ct_a))
			_hit(_btn_rect(0))
		58:
			_ok("경기를 하면 출전 수가 오름 (%s → %d)" % [_ct_b, Gr.games(_ct_a)],
				_ct_a == "" or Gr.games(_ct_a) > int(_ct_b))
			# 출전 수가 문턱을 넘으면 **칸이 실제로 늘어야** 합니다.
			# **EX 카드로 재지 마세요** — 처음부터 열여섯 칸이라 늘 통과합니다.
			var _uc := {}
			for _c in Sv.owned_cards():
				if str((_c as Dictionary).get("grade", "")) != D.GRADE_EX:
					_uc = _c
					break
			var _uid := DB.card_id(_uc) if not _uc.is_empty() else ""
			var _n0 := Gr.open_cells(_uc).size() if _uid != "" else 0
			if _uid != "":
				Sv.games[_uid] = int(Gr.UNLOCK_AT[4])
			_ok("출전이 %d경기가 되면 칸이 늘어남" % int(Gr.UNLOCK_AT[4]),
				_uid == "" or Gr.open_cells(_uc).size() > _n0)
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
