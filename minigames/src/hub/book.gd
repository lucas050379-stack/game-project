class_name UiBook
extends RefCounted

## 다섯 게임이 같이 쓰는 도감 · 순위 창(사용자 요청 11-08 — 젤리팝처럼 "모드 · 도감 · 도감 · 순위" 메뉴를 다섯 게임이 같은 구조로).
## 처음 화면 위에 겹쳐 뜨고, 떠 있는 동안 입력은 이 창이 다 받는다(`click` · `key` 가 true 를 돌려준다).
##   grid — 카드 격자(도감): 항목 {name, desc, draw: Callable(ci, rect, t)} — 위 그림 칸을 게임이 그린다.
##   list — 순위 목록: 항목 {main, sub, hl} — 왼쪽에 등수, 가운데 큰 값, 아래 작은 설명.
## 색은 `UiKit.theme(game)` 을 따른다. **글에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음) — 데이터 글은 넣기 전에 걸러 주세요.

var open := false
var title := ""
var game := ""
var mode := "grid"
var items: Array = []
var page := 0
var cols := 3
var rows := 2
var per_list := 7
var empty_text := "아직 기록이 없습니다"


func show(p_title: String, p_items: Array, p_mode: String = "grid", p_cols: int = 3, p_rows: int = 2) -> void:
	title = p_title
	items = p_items
	mode = p_mode
	cols = p_cols
	rows = p_rows
	page = 0
	open = true


func close() -> void:
	open = false


func per_page() -> int:
	return cols * rows if mode == "grid" else per_list


func pages() -> int:
	return maxi(1, int(ceil(items.size() / float(per_page()))))

# ==================== 자리 ====================


func panel(vs: Vector2) -> Rect2:
	if vs.x > vs.y:
		return Rect2(50, 34, vs.x - 100, vs.y - 68)   # 규칙서 창(UiRules.panel)과 같은 크기 — 닫기 · 이전/다음이 두 창에서 같은 자리에 온다
	return Rect2(20, 90, vs.x - 40, vs.y - 180)


func close_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	return Rect2(p.end.x - 150, p.position.y + 16, 130, 50)


func nav_rect(vs: Vector2, k: int) -> Rect2:
	var p := panel(vs)
	var w := 130.0
	return Rect2(p.get_center().x + (-w - 90.0 if k == 0 else 90.0), p.end.y - 66, w, 50)


func cell(vs: Vector2, i: int) -> Rect2:
	var p := panel(vs)
	var area := Rect2(p.position.x + 24, p.position.y + 84, p.size.x - 48, p.size.y - 84 - 80)
	if mode == "list":
		var h := area.size.y / per_list
		return Rect2(area.position.x, area.position.y + i * h, area.size.x, h - 8)
	var gap := 16.0
	var w := (area.size.x - gap * (cols - 1)) / cols
	var h2 := (area.size.y - gap * (rows - 1)) / rows
	return Rect2(area.position.x + (i % cols) * (w + gap), area.position.y + (i / cols) * (h2 + gap), w, h2)

# ==================== 입력 ====================


## 떠 있으면 true(아래 화면에 넘기지 않는다).
func click(p: Vector2, vs: Vector2) -> bool:
	if not open:
		return false
	if close_rect(vs).has_point(p):
		close()
	elif nav_rect(vs, 0).has_point(p):
		page = maxi(0, page - 1)   # 끝에서 돌지 않는다 — 규칙서 · 젤리팝 도감과 같게
	elif nav_rect(vs, 1).has_point(p):
		page = mini(pages() - 1, page + 1)
	return true


func key(code: int) -> bool:
	if not open:
		return false
	match code:
		KEY_ESCAPE, KEY_BACKSPACE:
			close()
		KEY_LEFT, KEY_A:
			page = maxi(0, page - 1)
		KEY_RIGHT, KEY_D:
			page = mini(pages() - 1, page + 1)
	return true

# ==================== 그리기 ====================


func draw(ci: CanvasItem, vs: Vector2, t: float) -> void:
	if not open:
		return
	var th := UiKit.theme(game)
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.06, 0.7), true)
	var p := panel(vs)
	G2.panel(ci, p.grow(4), Color(0, 0, 0, 0.35), Color(), 0.0, 30)
	G2.panel(ci, p, Color8(28, 24, 46, 250), th.edge, 3.0, 26)
	G2.text_mid(ci, Vector2(p.get_center().x, p.position.y + 42), title, 40, Color(1, 1, 1), 9, th.ink)
	UiKit.draw(ci, close_rect(vs), "menu", "닫기", th.hub, th.hub_text, th, close_rect(vs).has_point(ci.get_local_mouse_position()), t)
	var first := page * per_page()
	if items.is_empty():
		G2.text_mid(ci, p.get_center(), empty_text, 26, Color(1, 1, 1, 0.6), 0)
	for i in range(first, mini(items.size(), first + per_page())):
		var r := cell(vs, i - first)
		if mode == "list":
			_row(ci, r, i, items[i], th)
		else:
			_card(ci, r, items[i], t)
	if pages() > 1:
		for k in 2:
			if (k == 0 and page == 0) or (k == 1 and page >= pages() - 1):
				continue   # 더 넘길 쪽이 없으면 단추를 안 그린다
			var nr := nav_rect(vs, k)
			UiKit.draw(ci, nr, "menu", "이전" if k == 0 else "다음", th.hub, th.hub_text, th, nr.has_point(ci.get_local_mouse_position()), t)
		G2.text_mid(ci, Vector2(p.get_center().x, nav_rect(vs, 0).get_center().y), "%d / %d" % [page + 1, pages()], 24,
				Color(1, 1, 1, 0.8), 0)


func _card(ci: CanvasItem, r: Rect2, it: Dictionary, t: float) -> void:
	G2.panel(ci, r, Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.16), 1.5, 14)
	var pic := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y * 0.46))   # 설명 글자를 20 으로 키우면서 그림 칸을 줄였다
	G2.panel(ci, pic, Color(0, 0, 0, 0.25), Color(), 0.0, 10)
	var f: Callable = it.get("draw", Callable())
	if f.is_valid():
		f.call(ci, pic, t)
	G2.text_mid(ci, Vector2(r.get_center().x, pic.end.y + 20), String(it.get("name", "")), 22, Color(1, 0.95, 0.8), 4)
	var lines: Array = wrap_text(String(it.get("desc", "")), 20.0, r.size.x - 16)
	var y := pic.end.y + 48
	for ln in lines:
		if y > r.end.y - 8:
			break
		G2.text_mid(ci, Vector2(r.get_center().x, y), ln, 20, Color(1, 1, 1, 0.78), 0)
		y += 23


func _row(ci: CanvasItem, r: Rect2, i: int, it: Dictionary, th: Dictionary) -> void:
	var hl := bool(it.get("hl", false))
	G2.panel(ci, r, Color(1, 0.85, 0.4, 0.16) if hl else Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.14), 1.2, 12)
	var badge := Vector2(r.position.x + 34, r.get_center().y)
	ci.draw_circle(badge, 20, th.start if i == 0 else Color(1, 1, 1, 0.15))
	G2.text_mid(ci, badge, str(i + 1), 22, th.start_text if i == 0 else Color(1, 1, 1), 0)
	var f := UiKit.font()
	ci.draw_string(f, Vector2(r.position.x + 70, r.get_center().y + 10), String(it.get("main", "")), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x * 0.42, 28, Color(1, 0.95, 0.8))
	ci.draw_string(f, Vector2(r.position.x + 70 + r.size.x * 0.42, r.get_center().y + 8), String(it.get("sub", "")),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, 20, Color(1, 1, 1, 0.75))


## 폭에 맞춰 줄을 나눈다(띄어쓰기에서, 한 낱말이 길면 글자에서).
static func wrap_text(s: String, size: float, width: float) -> Array:
	var f := UiKit.font()
	var out := []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var cand := word if line == "" else line + " " + word
			if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x <= width:
				line = cand
				continue
			if line != "":
				out.append(line)
			line = word
			while f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x > width and line.length() > 1:
				var cut := line.length() - 1
				while cut > 1 and f.get_string_size(line.substr(0, cut), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x > width:
					cut -= 1
				out.append(line.substr(0, cut))
				line = line.substr(cut)
		if line != "":
			out.append(line)
	return out
