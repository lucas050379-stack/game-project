extends SceneTree
# 푸야매 — KBO 기록실 수집기 (헤드리스 전용 도구, 게임 안에서 돌지 않습니다)
#
# KBO 공식 기록실은 ASP.NET 포스트백입니다. __VIEWSTATE·__EVENTVALIDATION·세션
# 쿠키를 전부 맞춰 curl 로 보내도 **유효한 __EVENTTARGET 이나 실제 폼 필드가
# 하나라도 들어가는 순간 서버가 500** 을 냅니다(없는 필드를 보내면 오히려 정상
# 응답이 옵니다). 그래서 HTTP 로 흉내내는 길은 막혀 있고, 헤드리스 크롬을 띄워
# CDP(WebSocket)로 진짜 브라우저를 조종합니다. fetch.bat 이 크롬을 띄우고 이
# 스크립트를 부른 뒤 크롬을 정리합니다.
#
# 시즌 하나에 6개 표 × 구단 수 × 페이지 수 를 받습니다. 결과는 연도별 JSON
# 한 벌(data/raw/<연도>.json)이고, **파일이 있으면 그 연도는 건너뜁니다** —
# 중간에 끊겨도 다시 돌리면 이어서 받습니다.

const HOST := "127.0.0.1"
const PORT := 9222
const BASE := "https://www.koreabaseball.com/"
const PFX := "ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$"

# 카드 6스텟이 이 여섯 표에서 전부 나옵니다.
#   타자 교타력/장타력 ← hit1·hit2, 번트 ← hit1 의 SAC, 정신력 ← hit2 의 RISP
#   주력 ← run 의 SB/CS, 수비력과 포지션 ← def 의 POS/E/FPCT
#   투수 6종 ← pit1·pit2
#
# **`tab_from` 이 있는 페이지는 주소로 바로 열면 안 됩니다.**
# KBO 사이트 버그입니다 — 타자 Basic2 는 시즌을 2003 으로 바꿔도 구단 목록만
# 현재 시즌(2026) 것을 그대로 둡니다. 그래서 2000~2007 년에만 있던 현대가
# 목록에 없어 통째로 빠집니다(없는 값을 넣으면 EventValidation 이 막습니다).
# 앞 페이지에서 시즌을 고른 뒤 **사이트 안의 탭 링크를 눌러** 넘어가면
# 시즌이 유지되고 구단 목록도 그 시즌 것으로 옵니다.
const PAGES := [
	{"key": "hit1", "path": "Record/Player/HitterBasic/Basic1.aspx"},
	{"key": "hit2", "path": "Record/Player/HitterBasic/Basic2.aspx",
		"tab_from": "Record/Player/HitterBasic/Basic1.aspx",
		"tabs": ["HitterBasic/Basic2", "HitterBasic/BasicOld"]},
	{"key": "run", "path": "Record/Player/Runner/Basic.aspx"},
	{"key": "def", "path": "Record/Player/Defense/Basic.aspx"},
	{"key": "pit1", "path": "Record/Player/PitcherBasic/Basic1.aspx"},
	{"key": "pit2", "path": "Record/Player/PitcherBasic/Basic2.aspx",
		"tab_from": "Record/Player/PitcherBasic/Basic1.aspx",
		"tabs": ["PitcherBasic/Basic2", "PitcherBasic/BasicOld"]},
]

# 공개 사이트를 훑으므로 요청 사이에 이만큼 쉽니다. 줄이지 마세요.
const POLITE_MS := 350

var ws := WebSocketPeer.new()
var mid := 0

# ── CDP 기초 ────────────────────────────────────────────────────────────────

func _pump(ms: int) -> Array:
	var out: Array = []
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < ms:
		ws.poll()
		while ws.get_available_packet_count() > 0:
			var j = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if j != null:
				out.append(j)
		OS.delay_msec(8)
	return out

func cmd(method: String, params: Dictionary, wait_ms: int = 20000):
	mid += 1
	var my := mid
	ws.send_text(JSON.stringify({"id": my, "method": method, "params": params}))
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < wait_ms:
		for j in _pump(40):
			if typeof(j) == TYPE_DICTIONARY and j.get("id", -1) == my:
				return j.get("result", {})
	return null

func js(expr: String, wait_ms: int = 20000):
	var r = cmd("Runtime.evaluate", {"expression": expr, "returnByValue": true, "awaitPromise": true}, wait_ms)
	if r == null:
		return null
	return r.get("result", {}).get("value", null)

func jsj(expr: String):
	# JSON 문자열을 돌려주는 JS 를 파싱해서 받습니다.
	var s = js("JSON.stringify(%s)" % expr)
	return null if s == null else JSON.parse_string(s)

# ── 포스트백 대기 ───────────────────────────────────────────────────────────
# 포스트백은 폼 전체 재요청이라 문서가 새로 뜹니다. 고정 시간으로 기다리면
# 느릴 때 빈 표를 읽습니다. 그래서 표식을 심고 그게 사라질 때까지 기다립니다.

func _wait_reload(timeout_ms: int = 15000) -> bool:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < timeout_ms:
		OS.delay_msec(120)
		var ok = js("(typeof window.__pym === 'undefined') && document.readyState === 'complete'", 5000)
		if ok == true:
			OS.delay_msec(POLITE_MS)
			return true
	return false

const READY := "document.readyState === 'complete' && !!document.getElementById('cphContents_cphContents_cphContents_ddlSeason_ddlSeason') && !!document.querySelector('table.tData01')"

func _wait_ready(timeout_ms: int = 25000) -> bool:
	# 문서가 뜨고 **표까지 그려질 때까지** 기다립니다.
	# 표식(__pym)이 사라진 것만으로는 부족합니다 — 폼을 전송하면 새 문서가
	# 자리를 잡기 전 아주 잠깐 빈 문서가 끼는데, 그때도 표식은 없고
	# readyState 는 complete 라서 **빈 표를 읽고 지나갑니다.** 실제로 그래서
	# 두산이 0명, 삼성이 6명으로 수집됐습니다.
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < timeout_ms:
		if js(READY, 5000) == true:
			return true
		OS.delay_msec(200)
	return false

func _submit(target: String, extra: String = "") -> bool:
	# **페이지의 __doPostBack() 을 부르지 마세요.** 함수는 있는데 실제 전송이
	# 안 되는 경우가 있어서, 값만 바뀌고 문서는 그대로인 채 30초를 기다리게
	# 됩니다(실제로 그렇게 전 시즌이 빈 채로 수집됐습니다). __EVENTTARGET 을
	# 직접 채우고 폼을 그대로 전송하면 확실합니다.
	# 표식(__pym)은 전송과 **같은 evaluate 안에서** 심어야 합니다 — 나눠 두면
	# 실패했을 때 표식만 남아 다음 대기가 통째로 날아갑니다.
	var r = js("(function(){%s window.__pym=1;document.getElementById('__EVENTTARGET').value=%s;document.getElementById('__EVENTARGUMENT').value='';document.forms[0].submit();return 1;})()"
		% [extra, JSON.stringify(target)])
	if r != 1:
		return false
	if not _wait_reload():
		return false
	return _wait_ready()

func _select(ddl: String, value: String) -> bool:
	# 드롭다운은 값을 넣고 나서 그 컨트롤을 대상으로 폼을 전송합니다.
	# **전송했다는 것만으로 믿지 말고 결과를 확인하세요** — 값이 안 걸린 채
	# 넘어가면 그 구단이 통째로 비거나 앞 구단 자료가 중복으로 들어갑니다.
	var dom := "cphContents_cphContents_cphContents_%s_%s" % [ddl, ddl]
	# **페이지 번호를 1로 되돌리고 바꿔야 합니다.** 앞 구단의 2페이지에 서 있는
	# 채로 구단을 바꾸면 새 구단의 2페이지를 달라고 해서 빈 표가 옵니다 —
	# 선수가 30명 이하인 구단이 통째로 비는 원인이 이것이었습니다(두산 0명).
	var pre := "var h=document.getElementById('cphContents_cphContents_cphContents_hfPage');if(h)h.value='1';var s=document.getElementById(%s);if(!s)return 0;s.value=%s;" % [JSON.stringify(dom), JSON.stringify(value)]
	for attempt in range(3):
		if _submit(PFX + ddl + "$" + ddl, pre) and _server_value(dom) == value:
			return true
		OS.delay_msec(600)
	return false

func _server_value(dom: String) -> String:
	# **`select.value` 로 확인하면 안 됩니다.** 그건 우리가 방금 써 넣은 값이라
	# 포스트백이 아예 안 걸렸어도 그대로 통과합니다. `defaultSelected` 는 서버가
	# 보낸 HTML 의 selected 속성이라 진짜 결과입니다.
	# 이걸 안 봐서 2003 수집이 **2026년 구단 목록**(KT·NC·SSG·키움)을 돌았고,
	# 그래서 현대·SK 가 통째로 빠졌습니다.
	var v = js("(function(){var s=document.getElementById(%s);if(!s)return null;var o=Array.prototype.filter.call(s.options,function(x){return x.defaultSelected});return o.length?o[0].value:s.value;})()" % JSON.stringify(dom))
	return "" if v == null else str(v)

# ── 표 읽기 ────────────────────────────────────────────────────────────────

func _head() -> Array:
	var h = jsj("Array.from(document.querySelectorAll('table.tData01 thead th')).map(function(e){return e.innerText.trim()})")
	return [] if h == null else h

func _rows() -> Array:
	var r = jsj("Array.from(document.querySelectorAll('table.tData01 tbody tr')).map(function(tr){return Array.from(tr.cells).map(function(td){return td.innerText.trim()})})")
	return [] if r == null else r

func _id_rows() -> Array:
	# [이름, 팀, 선수번호] — 선수번호는 행 안의 상세 링크(`playerId=…`)에 있습니다.
	# 사진 주소가 이 번호를 씁니다: KBO_IMAGE/person/middle/<연도>/<번호>.jpg
	var r = jsj("Array.from(document.querySelectorAll('table.tData01 tbody tr')).map(function(tr){var a=tr.querySelector('a[href*=playerId]');var m=a?/playerId=(\\d+)/.exec(a.getAttribute('href')):null;return [tr.cells[1].innerText.trim(), tr.cells[2].innerText.trim(), m?m[1]:''];})")
	return [] if r == null else r

func _page_numbers() -> Array:
	var p = jsj("Array.from(document.querySelectorAll('div.paging a, div.paging span')).map(function(e){return e.innerText.trim()}).filter(function(t){return /^[0-9]+$/.test(t)})")
	if p == null or (p as Array).is_empty():
		return ["1"]
	return p

func _click_tab(needle: String) -> bool:
	# 사이트 안의 탭 링크를 실제로 누릅니다. 주소로 바로 열면 시즌이 풀립니다.
	var r = js("(function(){var a=Array.prototype.slice.call(document.querySelectorAll('a')).filter(function(e){var h=e.getAttribute('href')||'';return h.indexOf(%s)>=0})[0];if(!a)return 0;window.__pym=1;a.click();return 1;})()" % JSON.stringify(needle))
	if r != 1:
		return false
	if not _wait_reload():
		return false
	return _wait_ready()

func _first_team() -> String:
	# 표 첫 행의 팀명. 드롭다운 값만 맞추고 넘어가면 필터가 실제로는 안 걸린
	# 채로 지나가는 일이 있습니다 — 2003 hit2 에서 현대 29명이 그렇게 통째로
	# 빠졌습니다(실패 메시지도 안 나왔습니다). **표 내용까지 확인하세요.**
	var s = js("((document.querySelector('table.tData01 tbody tr td:nth-child(3)')||{}).innerText||'').trim()")
	return "" if s == null else str(s)

func _select_team(code: String, team_name: String) -> bool:
	for attempt in range(3):
		if _select("ddlTeam", code) and _first_team() == team_name:
			return true
		OS.delay_msec(700)
	return false

func _first_row() -> String:
	var s = js("((document.querySelector('table.tData01 tbody tr td:nth-child(2)')||{}).innerText||'').trim()")
	return "" if s == null else str(s)

func _goto_page(n: String) -> bool:
	# 페이지 단추는 href 에 __doPostBack('대상','') 이 들어 있습니다. 그 대상만
	# 뽑아내서 _submit 으로 보냅니다(클릭도 __doPostBack 을 타므로 못 믿습니다).
	# 넘어갔는지는 **첫 행이 바뀌었는지**로 확인합니다.
	var before := _first_row()
	for attempt in range(3):
		var target = js("(function(){var a=Array.from(document.querySelectorAll('div.paging a')).filter(function(e){return e.innerText.trim()===%s})[0];if(!a)return '';var m=/__doPostBack\\('([^']+)'/.exec(a.getAttribute('href')||'');return m?m[1]:'';})()" % JSON.stringify(n))
		if target == null or str(target) == "":
			return false
		if _submit(str(target)) and _first_row() != before:
			return true
		OS.delay_msec(600)
	return false

var ids_mode := false

func _collect_current() -> Array:
	# 지금 걸린 필터(시즌·구단)로 모든 페이지를 훑습니다.
	var all: Array = []
	var pages := _page_numbers()
	all.append_array(_id_rows() if ids_mode else _rows())
	for n in pages:
		if str(n) == "1":
			continue
		if _goto_page(str(n)):
			all.append_array(_id_rows() if ids_mode else _rows())
	return all

# ── 본체 ───────────────────────────────────────────────────────────────────

func _new_tab() -> String:
	var h := HTTPClient.new()
	if h.connect_to_host(HOST, PORT) != OK:
		return ""
	while h.get_status() == HTTPClient.STATUS_CONNECTING or h.get_status() == HTTPClient.STATUS_RESOLVING:
		h.poll()
		OS.delay_msec(20)
	if h.get_status() != HTTPClient.STATUS_CONNECTED:
		return ""
	h.request(HTTPClient.METHOD_PUT, "/json/new?about:blank", [])
	while h.get_status() == HTTPClient.STATUS_REQUESTING:
		h.poll()
		OS.delay_msec(20)
	var body := PackedByteArray()
	while h.get_status() == HTTPClient.STATUS_BODY:
		h.poll()
		body.append_array(h.read_response_body_chunk())
		OS.delay_msec(10)
	var j = JSON.parse_string(body.get_string_from_utf8())
	if typeof(j) != TYPE_DICTIONARY:
		return ""
	return j.get("webSocketDebuggerUrl", "")

func _open_page(spec: Dictionary, year: int) -> bool:
	# 페이지를 열고 시즌을 맞춥니다. 탭 경유가 필요한 페이지는 앞 페이지에서
	# 시즌을 고른 뒤 탭을 누릅니다. **통째로 다시 시도합니다** — 탭 클릭 한 번이
	# 미끄러지면 그 표가 통째로 비는데(2001 hit2·pit2 가 그랬습니다), 한 번 더
	# 하면 대개 붙습니다.
	var entry := str(spec.get("tab_from", spec["path"]))
	for attempt in range(3):
		cmd("Page.navigate", {"url": BASE + entry})
		if not _wait_ready():
			continue
		if not _select("ddlSeason", str(year)):
			continue
		if not spec.has("tab_from"):
			return true
		# **구형 시즌은 탭 이름이 다릅니다.** 2002년 이전에는 `Basic2` 가 없고
		# `BasicOld` 가 그 자리입니다(열이 조금 다르지만 변환기가 이름으로
		# 읽으므로 괜찮습니다). 링크가 있는 쪽을 씁니다.
		var hit := false
		for needle in spec.get("tabs", []):
			if _click_tab(str(needle)):
				hit = true
				break
		if not hit:
			OS.delay_msec(800)
			continue
		if _server_value("cphContents_cphContents_cphContents_ddlSeason_ddlSeason") == str(year):
			return true
		OS.delay_msec(800)
	return false

func _fetch_year(year: int) -> Dictionary:
	var out := {"year": year, "tables": {}}
	# 선수번호만 받는 모드는 **타자·투수 기본표 둘만** 훑습니다. 여섯 표를 다
	# 도는 것보다 세 배 빠르고, 번호는 어느 표에나 같은 링크로 들어 있습니다.
	var pages: Array = PAGES
	if ids_mode:
		pages = [PAGES[0], PAGES[4]]
	for spec in pages:
		if not _open_page(spec, year):
			print("  ! %d %s 페이지를 열지 못했습니다 — 이 표는 빕니다" % [year, spec["key"]])
			continue
		var teams = jsj("Array.from(document.querySelectorAll('#cphContents_cphContents_cphContents_ddlTeam_ddlTeam option')).map(function(o){return [o.value,o.innerText.trim()]})")
		var head := _head()
		var rows: Array = []
		if teams == null or (teams as Array).size() <= 1:
			# 구단 필터가 없는 표는 규정 충족 선수만 나옵니다.
			rows = _collect_current()
		else:
			var seen := {}
			for t in teams:
				var code := str(t[0])
				var tname := str(t[1])
				if code == "":
					continue
				if not _select_team(code, tname):
					print("  ! %d %s %s(%s) 구단 선택 실패" % [year, spec["key"], tname, code])
					continue
				for r in _collect_current():
					# 재시도 중에 같은 표를 두 번 읽는 일이 없도록 행 단위로 거릅니다.
					# (수비 표는 한 선수가 포지션마다 한 줄씩이라 이름으로는 못 거릅니다)
					var sig := "|".join(PackedStringArray(r))
					if seen.has(sig):
						continue
					seen[sig] = true
					rows.append(r)
		out["tables"][spec["key"]] = {"head": head, "rows": rows}
		print("  %s: %d행" % [spec["key"], rows.size()])
	return out

func _init() -> void:
	# **깃발과 연도를 자리로 구분하지 마세요.** `--ids 2016 2026` 처럼 앞에 깃발이
	# 붙으면 연도가 한 칸씩 밀려서 엉뚱한 구간을 받습니다. 숫자만 골라냅니다.
	var args := OS.get_cmdline_user_args()
	var years: Array = []
	for a in args:
		if str(a) == "--ids":
			ids_mode = true
		elif str(a).is_valid_int():
			years.append(int(a))
	var y0 := 2000
	var y1 := 2026
	if years.size() >= 1:
		y0 = int(years[0])
		y1 = y0  # 한 해만 준 경우 그 해만 받습니다.
	if years.size() >= 2:
		y1 = int(years[1])

	var wsurl := _new_tab()
	if wsurl == "":
		print("크롬 CDP 에 붙지 못했습니다. fetch.bat 으로 실행하세요.")
		quit(1)
		return
	ws.connect_to_url(wsurl)
	var t := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		ws.poll()
		OS.delay_msec(20)
		if Time.get_ticks_msec() - t > 10000:
			print("WebSocket 연결 실패")
			quit(1)
			return
	cmd("Page.enable", {})
	cmd("Runtime.enable", {})

	DirAccess.make_dir_recursive_absolute("res://data/raw")
	DirAccess.make_dir_recursive_absolute("res://data/ids")
	for year in range(y0, y1 + 1):
		var path := "res://data/%s/%d.json" % ["ids" if ids_mode else "raw", year]
		if FileAccess.file_exists(path):
			print("%d — 이미 있음, 건너뜀" % year)
			continue
		print("%d 수집 중…" % year)
		var t0 := Time.get_ticks_msec()
		var d := _fetch_year(year)
		if ids_mode:
			# 이름|팀 → 선수번호 로 눌러 담습니다. 표 두 개를 합칩니다.
			var m := {}
			for k in (d["tables"] as Dictionary):
				for r in (d["tables"][k] as Dictionary)["rows"]:
					if (r as Array).size() >= 3 and str(r[2]) != "":
						m["%s|%s" % [str(r[0]), str(r[1])]] = str(r[2])
			d = {"year": year, "ids": m}
			print("  선수번호 %d명" % m.size())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			print("  ! 저장 실패: %s" % path)
			continue
		f.store_string(JSON.stringify(d))
		f.close()
		print("%d 완료 (%.1f초)" % [year, (Time.get_ticks_msec() - t0) / 1000.0])
	print("끝났습니다.")
	quit(0)
