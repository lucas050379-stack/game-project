extends Node
# 푸야매 — 저장. 오토로드(`Sv`)입니다.
#
# **`user://save.cfg` 하나**에 모읍니다(코인·보유 카드·오더·전적).
# **읽기나 쓰기가 실패해도 게임은 기본값으로 돌아야 합니다** — 저장이 안 된다고
# 시작조차 못 하면 안 됩니다.

const PATH := "user://save.cfg"

# 시작 코인. 한 팩이 10장이라 몇 번은 돌려 봐야 오더가 찹니다.
const START_COINS := 50000

var coins := START_COINS
var owned: Dictionary = {}     # card_id → 장수
var wins := 0                  # 통산 전적
var losses := 0

# ── 시즌 ───────────────────────────────────────────────────────────────────
# 리그는 나 포함 열 팀입니다. 상대 팀은 로스터를 통째로 저장하지 않고
# **이름·세기·씨앗**만 두었다가 필요할 때 다시 만듭니다 — 카드 아홉 장씩
# 아홉 팀을 저장하면 세이브가 쓸데없이 커집니다.
var tier := 0                  # 리그 등급 (0 = 루키 리그)
var season := 0                # 몇 번째 시즌 (0 = 아직 시작 안 함)
var game_no := 0               # 이번 시즌 몇 경기째
var rot_i := 0                 # 선발 로테이션 위치
var my_w := 0
var my_d := 0            # 무승부 — 승률에는 안 들어가지만 경기 수에는 들어갑니다
var my_l := 0
var league: Array = []         # [{name, ov, seed, w, l, d}, ...] 아홉 팀
var schedule: Array = []       # 상대 팀 인덱스 (길이 = SEASON_GAMES)

# ── 유학 ───────────────────────────────────────────────────────────────────
# `study_done` : card_id → 다녀온 지역 번호 배열.
# **평생 한 번뿐**이라 항상 0개 아니면 1개입니다. 배열로 두는 것은 규칙이
# 바뀌기 전 세이브 때문이고, 새로 보내는 것은 `can_study` 가 막습니다.
# 유학 표를 고치면 `STUDY_VER` 을 올리세요 — 저장된 번호의 뜻이 달라집니다.
const STUDY_VER := 2
# `study_trip` : card_id → {"r": 지역 번호, "left": 남은 경기 수}
# 유학 중인 카드는 오더에 못 들어갑니다.
var study_done: Dictionary = {}
var study_trip: Dictionary = {}

# 켜 둔 팀컬러. **원작처럼 두 개까지** 켭니다(`Col.MAX_ACTIVE`) — 조건을 만족한
# 것들 중에서 작전 화면의 팀컬러 탭에서 직접 고릅니다.
var color_ids: Array = []

# ── 카드 성장 ──────────────────────────────────────────────────────────────
# `games`    : card_id → 출전 경기 수 (스킬 칸과 구종 등급이 이 값 하나를 봅니다)
# `skill_on` : card_id → 장착한 스킬 id 배열 (**옛 세이브 호환용**)
#
# 스킬블록은 이제 **가지고 다니는 물건**입니다 — 뽑아서 얻고, 카드 판에 끼웁니다.
# `blocks`   : [{uid, sid, rot}] 보유한 블록 (uid 는 뽑을 때 매긴 일련번호)
# `block_at` : card_id → {uid(문자열) → 놓은 칸 번호}
var games: Dictionary = {}
var skill_on: Dictionary = {}
var blocks: Array = []
var block_at: Dictionary = {}
var block_uid := 1

# 오더. 빈 칸은 "" 입니다.
var lineup: Array = []         # 타순 9 — card_id
var lineup_pos: Array = []     # 그 자리에서 맡는 수비 위치
var bench: Array = []          # 벤치 5
var rot: Array = []            # 선발 5
var relief: Array = []         # 중계 4
var setup := ""                # 셋업 1
var closer := ""               # 마무리 1

func _ready() -> void:
	_blank_order()
	load_game()
	# **테스트 빌드는 모든 카드가 열려 있습니다.** `export_presets.cfg` 의
	# `Windows Test` 프리셋이 `testbuild` 기능 태그를 박아 넣습니다.
	if OS.has_feature("testbuild"):
		unlock_all()

func _blank_order() -> void:
	lineup = []
	lineup_pos = []
	bench = []
	rot = []
	relief = []
	for i in range(D.LINEUP):
		lineup.append("")
		# 기본 수비 배치 — 지명타자 한 자리를 뺀 여덟 자리입니다.
		lineup_pos.append(D.POS[i] if i < D.POS.size() else "지명타자")
	for i in range(D.BENCH):
		bench.append("")
	for i in range(D.ROT):
		rot.append("")
	for i in range(D.RELIEF):
		relief.append("")
	setup = ""
	closer = ""

# ── 보유 ───────────────────────────────────────────────────────────────────

# ── 테스트 빌드 ────────────────────────────────────────────────────────────
# `proyamae-test.exe` 는 **모든 카드를 가진 상태**로 시작합니다(`build-test.bat`).
# 오더·팀컬러·스킬블록을 손보려면 카드를 모으는 데만 몇 시간이 걸리는데, 그건
# 그 기능을 시험하는 일과 아무 상관이 없습니다.
#
# **세이브에는 안 씁니다.** 1만 장을 `owned` 에 넣으면 저장 파일이 그만큼 커지고
# 쓰기도 느려집니다 — 플래그 하나로 `has()`/`owned_cards()` 의 대답만 바꿉니다.
# 그래서 테스트 빌드로 논 세이브를 정식 빌드로 열어도 보유 카드가 안 늘어납니다.
var all_unlocked := false

func unlock_all() -> void:
	all_unlocked = true
	DB.clear_cache()

func add_card(c: Dictionary) -> void:
	var id := DB.card_id(c)
	owned[id] = int(owned.get(id, 0)) + 1

func has(id: String) -> bool:
	if all_unlocked:
		return true
	return int(owned.get(id, 0)) > 0

func count(id: String) -> int:
	# 화면에 찍는 보유 장수. 테스트 빌드는 전부 한 장씩 가진 것으로 셉니다.
	if all_unlocked:
		return maxi(int(owned.get(id, 0)), 1)
	return int(owned.get(id, 0))

# ── 트레이드 ───────────────────────────────────────────────────────────────
# 보유 카드를 넘겨 **코인**으로 바꿉니다. 안 쓰는 카드를 처분하는 길이자,
# 코인을 버는 두 번째 통로입니다(첫째는 경기 보상).
#
# 값은 COST 로 냅니다(종합이 아니라). 카드의 세기를 읽는 축이 COST 라서,
# 넘길 때도 같은 축으로 보여야 "이만큼 세니까 이만큼 받는다"가 읽힙니다.
const TRADE_BASE := 30
const TRADE_PER_COST := 26

func trade_value(c: Dictionary) -> int:
	var co := clampi(int(c.get("cost", 1)), 1, 10)
	# COST 가 높을수록 가파르게 오릅니다 — 고코스트 한 장이 저코스트 여러 장보다
	# 나아야 "쓸 만한 카드를 넘긴다"는 결정에 무게가 생깁니다.
	return TRADE_BASE + TRADE_PER_COST * co * co / 10

func can_trade(id: String) -> String:
	# 빈 문자열이면 넘길 수 있습니다. 아니면 안 되는 이유.
	if all_unlocked:
		# 다 가진 상태에서 넘기는 것은 뜻이 없고, 넘긴 뒤에도 `has()` 가 true 라
		# 목록이 안 줄어들어 화면이 거짓말을 합니다.
		return "테스트 빌드에서는 트레이드를 쓰지 않습니다"
	if not has(id):
		return "가지고 있지 않습니다"
	if away(id):
		return "유학 중입니다"
	# **오더에 든 카드는 못 넘깁니다.** 넘기면 그 자리가 조용히 비어서, 다음
	# 경기에 아홉 명이 안 차는 것을 경기가 시작되고 나서야 압니다.
	for g in [lineup, bench, rot, relief]:
		if (g as Array).has(id):
			return "오더에 들어 있습니다"
	if setup == id or closer == id:
		return "오더에 들어 있습니다"
	return ""

func trade(c: Dictionary) -> int:
	# 넘기고 받은 코인을 돌려줍니다. 0 이면 못 넘긴 것입니다.
	var id := DB.card_id(c)
	if can_trade(id) != "":
		return 0
	var v := trade_value(c)
	owned[id] = int(owned.get(id, 0)) - 1
	if int(owned[id]) <= 0:
		owned.erase(id)
		# 마지막 한 장을 넘기면 그 카드에 끼워 둔 블록도 가방으로 돌아옵니다.
		block_at.erase(id)
		games.erase(id)
	coins += v
	DB.clear_cache()
	save_game()
	return v

func owned_cards() -> Array:
	if all_unlocked:
		return DB.cards.duplicate()
	var out: Array = []
	for id in owned:
		var c := DB.find(str(id))
		if not c.is_empty():
			out.append(c)
	return out

# ── 오더 ───────────────────────────────────────────────────────────────────

func total_cost() -> int:
	var s := 0
	for id in _all_slots():
		if id == "":
			continue
		var c := DB.find(str(id))
		if not c.is_empty():
			s += int(c.get("cost", 0))
	return s

func _all_slots() -> Array:
	var out: Array = []
	out.append_array(lineup)
	out.append_array(bench)
	out.append_array(rot)
	out.append_array(relief)
	out.append(setup)
	out.append(closer)
	return out

func in_order(id: String) -> bool:
	return id != "" and _all_slots().has(id)

func pull_from_order(id: String) -> void:
	# 유학을 보내면 오더에서 빠집니다 — 없는 선수를 세워 둘 수는 없습니다.
	for i in range(lineup.size()):
		if str(lineup[i]) == id:
			lineup[i] = ""
	for i in range(bench.size()):
		if str(bench[i]) == id:
			bench[i] = ""
	for i in range(rot.size()):
		if str(rot[i]) == id:
			rot[i] = ""
	for i in range(relief.size()):
		if str(relief[i]) == id:
			relief[i] = ""
	if setup == id:
		setup = ""
	if closer == id:
		closer = ""

# ── 유학 ───────────────────────────────────────────────────────────────────

func study_regions(id: String) -> Array:
	var v = study_done.get(id, [])
	return v if typeof(v) == TYPE_ARRAY else []

func away(id: String) -> bool:
	return id != "" and study_trip.has(id)

func away_left(id: String) -> int:
	if not study_trip.has(id):
		return 0
	return int((study_trip[id] as Dictionary).get("left", 0))

func away_region(id: String) -> int:
	if not study_trip.has(id):
		return -1
	return int((study_trip[id] as Dictionary).get("r", -1))

func can_study(id: String, r: int) -> String:
	# 빈 문자열이면 보낼 수 있습니다.
	if id == "":
		return "카드를 고르세요"
	if not has(id):
		return "보유한 카드가 아닙니다"
	if away(id):
		return "이미 유학 중입니다"
	# **평생 한 번뿐입니다** — 어디를 다녀왔든 두 번째는 없습니다.
	if not study_regions(id).is_empty():
		return "이미 유학을 다녀왔습니다"
	if r < 0 or r >= D.ABROAD.size():
		return "없는 지역입니다"
	# **갈래를 봅니다.** `DB.find` 는 카드에 없는 스텟을 그냥 건너뛰므로,
	# 타자를 구위 유학에 보내면 코인과 경기만 쓰고 아무것도 안 오릅니다.
	if str(D.ABROAD[r].get("kind", "")) != str(DB.find(id).get("kind", "")):
		return "이 카드가 갈 수 있는 곳이 아닙니다"
	var need := int(D.ABROAD[r]["tier"])
	if need > tier:
		return "%s 부터 갈 수 있습니다" % D.tier_name(need)
	if coins < int(D.ABROAD[r]["coin"]):
		return "코인이 모자랍니다"
	return ""

func send_study(id: String, r: int) -> bool:
	if can_study(id, r) != "":
		return false
	coins -= int(D.ABROAD[r]["coin"])
	study_trip[id] = {"r": r, "left": int(D.ABROAD[r]["days"])}
	pull_from_order(id)
	DB.clear_cache()
	save_game()
	return true

func tick_study() -> Array:
	# 경기 하나가 지날 때마다 부릅니다. 돌아온 카드 id 를 돌려줍니다.
	var back: Array = []
	for id in study_trip.keys():
		var t: Dictionary = study_trip[id]
		t["left"] = int(t["left"]) - 1
		if int(t["left"]) <= 0:
			var done := study_regions(str(id))
			done.append(int(t["r"]))
			study_done[id] = done
			study_trip.erase(id)
			back.append(str(id))
	if not back.is_empty():
		DB.clear_cache()
	return back

func study_bonus(id: String) -> Dictionary:
	# 다녀온 곳의 상승치. **COST 는 여기에 없습니다.**
	# 지금은 한 번뿐이지만 배열로 두는 것은 규칙이 바뀌기 전 세이브 때문입니다 —
	# 이미 받은 것을 빼앗지 않고 그대로 더해 주고, 새로 보내는 것만 막습니다.
	var out := {}
	for r in study_regions(id):
		var up := D.abroad_up(int(r))
		for k in up:
			out[k] = int(out.get(k, 0)) + int(up[k])
	return out
# ── 파일 ───────────────────────────────────────────────────────────────────

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("player", "coins", coins)
	cf.set_value("player", "wins", wins)
	cf.set_value("player", "losses", losses)
	cf.set_value("cards", "owned", owned)
	cf.set_value("order", "lineup", lineup)
	cf.set_value("order", "lineup_pos", lineup_pos)
	cf.set_value("order", "bench", bench)
	cf.set_value("order", "rot", rot)
	cf.set_value("order", "relief", relief)
	cf.set_value("order", "setup", setup)
	cf.set_value("order", "closer", closer)
	cf.set_value("season", "tier", tier)
	cf.set_value("season", "no", season)
	cf.set_value("season", "game_no", game_no)
	cf.set_value("season", "rot_i", rot_i)
	cf.set_value("season", "my_w", my_w)
	cf.set_value("season", "my_d", my_d)
	cf.set_value("season", "my_l", my_l)
	cf.set_value("season", "league", league)
	cf.set_value("season", "schedule", schedule)
	cf.set_value("study", "done", study_done)
	cf.set_value("study", "trip", study_trip)
	cf.set_value("study", "ver", STUDY_VER)
	cf.set_value("order", "colors", color_ids)
	cf.set_value("grow", "games", games)
	cf.set_value("grow", "skill_on", skill_on)
	cf.set_value("grow", "blocks", blocks)
	cf.set_value("grow", "block_at", block_at)
	cf.set_value("grow", "block_uid", block_uid)
	cf.save(PATH)   # 실패해도 그냥 넘어갑니다.

func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	coins = int(cf.get_value("player", "coins", START_COINS))
	wins = int(cf.get_value("player", "wins", 0))
	losses = int(cf.get_value("player", "losses", 0))
	owned = cf.get_value("cards", "owned", {})
	# 칸 수가 바뀌었을 수 있으므로 길이를 맞춰서 받습니다.
	lineup = _fit(cf.get_value("order", "lineup", []), D.LINEUP)
	lineup_pos = _fit(cf.get_value("order", "lineup_pos", []), D.LINEUP)
	bench = _fit(cf.get_value("order", "bench", []), D.BENCH)
	rot = _fit(cf.get_value("order", "rot", []), D.ROT)
	relief = _fit(cf.get_value("order", "relief", []), D.RELIEF)
	setup = str(cf.get_value("order", "setup", ""))
	closer = str(cf.get_value("order", "closer", ""))
	tier = clampi(int(cf.get_value("season", "tier", 0)), 0, D.TIERS.size() - 1)
	season = int(cf.get_value("season", "no", 0))
	game_no = int(cf.get_value("season", "game_no", 0))
	rot_i = int(cf.get_value("season", "rot_i", 0))
	my_w = int(cf.get_value("season", "my_w", 0))
	my_d = int(cf.get_value("season", "my_d", 0))
	my_l = int(cf.get_value("season", "my_l", 0))
	var lg = cf.get_value("season", "league", [])
	league = lg if typeof(lg) == TYPE_ARRAY else []
	var sc = cf.get_value("season", "schedule", [])
	schedule = sc if typeof(sc) == TYPE_ARRAY else []
	var sd = cf.get_value("study", "done", {})
	study_done = sd if typeof(sd) == TYPE_DICTIONARY else {}
	var st = cf.get_value("study", "trip", {})
	study_trip = st if typeof(st) == TYPE_DICTIONARY else {}
	# **유학 표가 바뀌면 저장된 지역 번호의 뜻이 달라집니다.** 예전 3번은
	# 도미니카(장타+7·구속+7·주력+3)였는데 지금 3번은 네덜란드(정신력+12)입니다.
	# 그대로 두면 카드가 조용히 엉뚱한 스텟을 받은 채로 남고, 화면에는 멀쩡해
	# 보여서 눈으로는 절대 못 잡습니다. 그래서 판이 바뀌면 유학 기록을 비웁니다
	# (스킬블록의 `_migrate_shapes` 와 같은 이유입니다).
	if int(cf.get_value("study", "ver", 1)) < STUDY_VER:
		study_done = {}
		study_trip = {}
	# 옛 세이브는 문자열 하나였습니다 — 배열로 올려 줍니다.
	# **없는 열쇠에 `null` 기본값을 주지 마세요** — `ConfigFile.get_value` 가
	# 오류를 밀어 올립니다. 있는지는 `has_section_key` 로 먼저 봅니다.
	if cf.has_section_key("order", "colors"):
		var cl = cf.get_value("order", "colors", [])
		color_ids = (cl as Array).slice(0, Col.MAX_ACTIVE) if typeof(cl) == TYPE_ARRAY else []
	else:
		var old := str(cf.get_value("order", "color", ""))
		color_ids = [] if old == "" else [old]
	var gm = cf.get_value("grow", "games", {})
	games = gm if typeof(gm) == TYPE_DICTIONARY else {}
	var so = cf.get_value("grow", "skill_on", {})
	skill_on = so if typeof(so) == TYPE_DICTIONARY else {}
	var bl = cf.get_value("grow", "blocks", [])
	blocks = bl if typeof(bl) == TYPE_ARRAY else []
	_migrate_shapes()
	var ba = cf.get_value("grow", "block_at", {})
	block_at = ba if typeof(ba) == TYPE_DICTIONARY else {}
	block_uid = int(cf.get_value("grow", "block_uid", 1))
	for i in range(lineup_pos.size()):
		if str(lineup_pos[i]) == "":
			lineup_pos[i] = D.POS[i] if i < D.POS.size() else "지명타자"

func _fit(v, n: int) -> Array:
	var out: Array = []
	var src: Array = v if typeof(v) == TYPE_ARRAY else []
	for i in range(n):
		out.append(str(src[i]) if i < src.size() else "")
	return out

# 모양이 일곱 가지이던 시절의 세이브를 지금의 네 가지로 옮깁니다.
# **조용히 기본값으로 떨어지게 두지 마세요** — 모르는 모양은 `shape_cells` 가
# ㅁ 로 대신 그리는데, 값(`SHAPE_MUL`)은 1.0 으로 떨어져서 **그림과 값이 따로
# 놉니다.** 여기서 한 번에 바꿔 두면 그런 어긋남이 안 생깁니다.
# 옛 이름 → 지금 모양. **S·Z·T 와 거울상 L 이 돌아왔으므로 그대로 옮깁니다.**
# `"ㄱ"` 은 `ㄴ` 을 180° 돌린 것이라 사실 같은 조각이었습니다 — 이름만 정리했습니다.
const OLD_SHAPES := {
	"O": "ㅁ", "I": "l", "J": "ㄴ", "T": "ㅗ",
	"ㄱ": "ㄴ",
}

func _migrate_shapes() -> void:
	var n := 0
	for b in blocks:
		var s := str((b as Dictionary).get("shape", ""))
		if Gr.SHAPES.has(s):
			continue
		(b as Dictionary)["shape"] = str(OLD_SHAPES.get(s, "ㅁ"))
		n += 1
	if n > 0:
		save_game()

func reset() -> void:
	coins = START_COINS
	owned = {}
	wins = 0
	losses = 0
	tier = 0
	season = 0
	game_no = 0
	rot_i = 0
	my_w = 0
	my_d = 0
	my_l = 0
	league = []
	schedule = []
	study_done = {}
	study_trip = {}
	color_ids = []
	games = {}
	skill_on = {}
	blocks = []
	block_at = {}
	block_uid = 1
	_blank_order()
	save_game()
