class_name Net
extends RefCounted

## 순위 · 플레이 기록 — 구글 시트(Apps Script 웹 앱)로 보낸다. 받는 쪽 코드는 tools/rank.gs.
##
## 주소는 `rank_url.txt` 한 줄(저장소에 안 올림 — 공개 저장소라 긁혀 가면 장난 기록이 쌓인다).
## 없거나, 테스트 빌드이거나, 확인용 실행(--auto 등)이면 아무것도 안 한다. **게임은 그대로 돈다.**
##
## 판이 끝날 때마다 사건 하나를 Sv.pending 에 쌓고 보낸다. 실패하면 남겨 두었다가 다음에 다시 보낸다.
## 사건마다 번호(seq)를 붙여 서버가 같은 사건을 두 번 받지 않는다 — 응답을 못 받아 다시 보내도 겹치지 않는다.
##
## 웹에서는 Content-Type 을 text/plain 으로 보낸다. application/json 이면 브라우저가 사전 요청(OPTIONS)을
## 먼저 보내는데 Apps Script 는 그걸 받지 않아 CORS 로 막힌다.

const URL_FILE := "res://rank_url.txt"
const PENDING_MAX := 300
const BATCH := 40

static var url := ""
static var enabled := false
static var board := {}          ## 마지막으로 받은 순위 {ta: [[이름, 값], ...], stars: [...], me: {...}}
static var board_state := ""    ## "" · "loading" · "ok" · "fail"
static var _post: HTTPRequest
static var _get: HTTPRequest
static var _busy := false
static var _sent := 0           ## 보내는 중인 사건 수 — 성공하면 앞에서 그만큼 지운다
static var _force := false
static var _want_board := false
static var _want_stage := 0     ## 보내기가 끝나면 받을 판 순위
static var _stage_id := 0       ## 지금 받고 있는 판 — 늦게 온 앞 판 답을 버린다
static var _board_loading := false
static var _get_st: HTTPRequest
static var stage_board := {}    ## 결과 창의 그 판 순위 {stage, top: [[이름, 점수, 나인가], ...], me, total}
static var stage_state := ""    ## "" · "loading" · "ok" · "fail"


## 허브에 붙여 한 번만 연다 — 젤리팝을 다시 열 때마다 새로 만들면 보내는 중이던 요청이 노드째 지워진다.
static func init(owner: Node, on: bool) -> void:
	if _post != null and is_instance_valid(_post):
		return
	if FileAccess.file_exists(URL_FILE):
		url = FileAccess.get_file_as_string(URL_FILE).strip_edges()
	enabled = on and url.begins_with("https://")
	if not enabled:
		return
	Sv.ensure_uid()
	# 보내기는 넘겨주기(302)를 따라가지 않는다 — 데스크톱에서 따라가면 POST 를 한 번 더 보낸다.
	# Apps Script 는 doPost 를 다 돌린 뒤에 302 를 주므로 302 가 곧 성공이다.
	_post = HTTPRequest.new()
	_post.max_redirects = 0
	_post.timeout = 20
	owner.add_child(_post)
	_post.request_completed.connect(_on_post)
	_get = HTTPRequest.new()
	_get.timeout = 20
	owner.add_child(_get)
	_get.request_completed.connect(_on_get)
	_get_st = HTTPRequest.new()
	_get_st.timeout = 20
	owner.add_child(_get_st)
	_get_st.request_completed.connect(_on_get_stage)
	flush()
	load_board()   # 순위 화면을 열기 전에 미리 — 열 때 바로 보이게


## 판 하나가 끝났다. ev 는 {k: "st" | "ta", ...}
static func event(ev: Dictionary) -> void:
	if not enabled:
		return
	Sv.seq += 1
	ev.q = Sv.seq
	ev.at = int(Time.get_unix_time_from_system())
	Sv.pending.append(ev)
	if Sv.pending.size() > PENDING_MAX:
		Sv.pending = Sv.pending.slice(Sv.pending.size() - PENDING_MAX)
	Sv.save_()
	flush()


## 쌓인 것을 보낸다. 사건이 없어도 force 면 지금 기록(이름 · 최고 점수)만 보낸다.
static func flush(force: bool = false) -> void:
	if not enabled:
		return
	_force = _force or force
	if _busy or (Sv.pending.is_empty() and not _force):
		return
	var evs := Sv.pending.slice(0, BATCH)
	var body := {
		"uid": Sv.uid, "name": Sv.name, "ver": _ver(),
		"snap": {"ta": Sv.best, "stars": Sv.total_stars(), "cleared": Sv.cleared(), "score": Sv.total_score(), "tav": Sv.TA_VER},
		"events": evs,
	}
	var err := _post.request(url, ["Content-Type: text/plain;charset=utf-8"], HTTPClient.METHOD_POST,
			JSON.stringify(body))
	if err == OK:
		_busy = true
		_sent = evs.size()
		_force = false


## 순위 화면을 열 때 — 내 기록을 먼저 올리고, 그 응답이 온 다음에 순위를 받는다.
## 동시에 보내면 순위가 방금 올린 기록보다 먼저 읽혀 내 자리가 한 판 늦게 나온다.
## 그 사이에는 켤 때 미리 받아 둔 순위를 그대로 보여 준다(`init` 이 받아 둔다) — 서버가 2~3초 걸린다.
static func open_board() -> void:
	_want_board = true
	flush(true)
	if not _busy:
		_want_board = false
		load_board()


## 받아 둔 순위가 있으면 받는 동안에도 그것을 보여 준다("불러오는 중"은 처음 한 번만).
static func load_board() -> void:
	if not enabled:
		board_state = "fail"
		return
	if _board_loading:
		return
	_board_loading = true
	if board.is_empty():
		board_state = "loading"
	if _get.request(url + "?mode=rank&uid=" + Sv.uid.uri_encode()) != OK:
		_board_loading = false
		if board.is_empty():
			board_state = "fail"


static func _on_post(result: int, code: int, h: PackedStringArray, body: PackedByteArray) -> void:
	var n := _sent
	_busy = false
	var text := body.get_string_from_utf8()
	# 데스크톱: 넘겨주기를 안 따라가서 302 — 결과 쪽(googleusercontent)으로 넘길 때만 성공이다.
	# 배포 권한이 "모든 사용자"가 아니면 로그인 화면(accounts.google.com)으로 302 가 온다.
	# 웹: 브라우저가 따라가서 200 + {"ok":true}
	var ok := result == HTTPRequest.RESULT_SUCCESS and text.contains("\"ok\":true")
	if code == 302:
		for line in h:
			if line.to_lower().begins_with("location:") and line.contains("googleusercontent.com"):
				ok = true
	if ok:
		if n > 0:
			Sv.pending = Sv.pending.slice(mini(n, Sv.pending.size()))
		Sv.save_()
		if not Sv.pending.is_empty() or _force:
			flush()
	# 실패한 것은 남겨 두고 다음 판이 끝날 때 다시 보낸다. 순위는 실패해도 받아 본다.
	if _want_board and not _busy:
		_want_board = false
		load_board()
	if _want_stage > 0 and not _busy:
		_load_stage(_want_stage)


static func _on_get(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_board_loading = false
	var data = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if data is Dictionary and data.get("ok", false):
		board = data
		board_state = "ok"
	elif board.is_empty():
		board_state = "fail"

# ==================== 판 순위 (결과 창) ====================
# 서버는 받고 · 보내고에 4초쯤 걸린다. 그래서 **판을 시작할 때 미리 받아 두고**, 깨면 내 점수를 그 자리에서
# 끼워 넣어 바로 보여 준다(`_merge_me`). 서버 답이 오면 조용히 그것으로 바꾼다.

## 판을 시작할 때 — 그 판 순위를 미리 받아 둔다.
static func prefetch_stage(id: int) -> void:
	if not enabled:
		return
	if int(stage_board.get("stage", 0)) != id:
		stage_board = {}
		stage_state = "loading"   # 시작 창이 "불러오는 중"을 띄운다
	_load_stage(id)


## 깼다 — best 는 이 판 내 최고 점수(방금 것과 예전 것 중 큰 쪽).
static func open_stage(id: int, best: int) -> void:
	if not enabled:
		stage_state = ""
		return
	if int(stage_board.get("stage", 0)) == id and stage_board.has("top"):
		_merge_me(best)
		stage_state = "ok"
	else:
		stage_board = {}
		stage_state = "loading"
	_want_stage = id
	flush(true)
	if not _busy:
		_load_stage(id)


static func _load_stage(id: int) -> void:
	_want_stage = 0
	_stage_id = id
	_get_st.cancel_request()   # 앞 판 것을 받는 중이면 버린다
	if _get_st.request(url + "?mode=stage&s=%d&uid=%s" % [id, Sv.uid.uri_encode()]) != OK and stage_board.is_empty():
		stage_state = "fail"


static func _on_get_stage(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
	if data is Dictionary and data.get("ok", false) and int(data.get("stage", 0)) == _stage_id:
		stage_board = data
		stage_state = "ok"
	elif stage_board.is_empty() and stage_state == "loading":
		stage_state = "fail"


## 받아 둔 위 10명에 내 점수를 끼워 넣고 다시 줄 세운다. 10등 밖이면 서버가 알려 준 예전 등수를 그대로 둔다.
static func _merge_me(best: int) -> void:
	var top: Array = stage_board.top
	var mine := -1
	for i in top.size():
		if bool(top[i][2]):
			mine = i
	if mine >= 0:
		top[mine][1] = maxf(float(top[mine][1]), best)
	else:
		top.append([Sv.name, best, true])
		if int(stage_board.get("me", 0)) == 0:
			stage_board.total = int(stage_board.get("total", 0)) + 1
	top.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	for i in top.size():
		if bool(top[i][2]):
			mine = i
	if mine < 10:
		stage_board.me = mine + 1
	if top.size() > 10:
		top.resize(10)


## 기록에 붙는 판본 — 소스에서 돌린 것(dev)은 시트에서 걸러 볼 수 있게 표시한다.
static func _ver() -> String:
	return "m%d%s" % [Sv.MAP_VER, "-dev" if OS.is_debug_build() else ""]
