class_name UiRules
extends RefCounted

## 규칙서 — 쪽마다 왼쪽 그림 + 오른쪽 설명, 이전 · 다음으로 넘긴다(사용자 요청 11-09 — "룰북이 없으니까 힘들다").
## 도감(`UiBook`) 첫 장의 규칙 칸은 글이 작아 읽히지 않았다. 처음 화면 · 판 위 [규칙] 단추와 첫 판 시작 때 저절로 뜬다.
## 쪽: {head, lines: Array[String], draw: Callable(ci, rect, t)} — 그림은 게임의 실제 그림 함수(카드 · 토큰 · 트랙)로 그린다.
## 떠 있는 동안 입력은 이 창이 다 받는다(`click` · `key` 가 true). **글에 `·` `—` `×` `→` 를 쓰지 마세요**(Jua 에 없음).

var open := false
var game := ""
var title := "규칙"
var pages: Array = []
var page := 0


func show(p_game: String, p_title: String, p_pages: Array, p_page: int = 0) -> void:
	game = p_game
	title = p_title
	pages = p_pages
	page = clampi(p_page, 0, maxi(0, pages.size() - 1))
	open = true


func close() -> void:
	open = false


# ==================== 자리 ====================


func panel(vs: Vector2) -> Rect2:
	return Rect2(50, 34, vs.x - 100, vs.y - 68)


func close_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	return Rect2(p.end.x - 150, p.position.y + 16, 130, 50)


func nav_rect(vs: Vector2, k: int) -> Rect2:
	var p := panel(vs)
	var w := 130.0
	return Rect2(p.get_center().x + (-w - 90.0 if k == 0 else 90.0), p.end.y - 66, w, 50)   # 도감 창(UiBook.nav_rect)과 같은 자리 · 크기


func pic_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	return Rect2(p.position.x + 28, p.position.y + 84, p.size.x * 0.47, p.size.y - 84 - 84)   # 아래는 이전 / 다음 자리


func text_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	var pic := pic_rect(vs)
	return Rect2(pic.end.x + 30, p.position.y + 84, p.end.x - pic.end.x - 58, p.size.y - 84 - 90)

# ==================== 입력 ====================


## 떠 있으면 true(아래 화면에 넘기지 않는다).
func click(p: Vector2, vs: Vector2) -> bool:
	if not open:
		return false
	if close_rect(vs).has_point(p):
		close()
	elif nav_rect(vs, 0).has_point(p):
		page = maxi(0, page - 1)
	elif nav_rect(vs, 1).has_point(p):
		if page >= pages.size() - 1:
			close()   # 마지막 쪽의 "다 읽음"
		else:
			page += 1
	return true


func key(code: int) -> bool:
	if not open:
		return false
	match code:
		KEY_ESCAPE, KEY_BACKSPACE:
			close()
		KEY_LEFT, KEY_A:
			page = maxi(0, page - 1)
		KEY_RIGHT, KEY_D, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if page >= pages.size() - 1:
				close()
			else:
				page += 1
	return true

# ==================== 그리기 ====================


func draw(ci: CanvasItem, vs: Vector2, t: float) -> void:
	if not open or pages.is_empty():
		return
	var th := UiKit.theme(game)
	var mouse := ci.get_local_mouse_position()
	var hc: Color = th.edge if (th.edge as Color).get_luminance() > 0.4 else th.title_col[0]   # 테가 먹색인 게임(강호 · 호랑이)은 제목이 어두운 판에 묻힌다
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, 0.75), true)
	var p := panel(vs)
	G2.panel(ci, p.grow(4), Color(0, 0, 0, 0.35), Color(), 0.0, 30)
	G2.panel(ci, p, Color8(30, 24, 36), th.edge, 3.0, 26)
	ci.draw_string(UiKit.font(), Vector2(p.position.x + 30, p.position.y + 56), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, hc)
	UiKit.draw(ci, close_rect(vs), "menu", "닫기", th.hub, th.hub_text, th, close_rect(vs).has_point(mouse), t)
	# 쪽 표시 — 제목 옆 점
	var dx := p.position.x + 64 + UiKit.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	for k in pages.size():
		ci.draw_circle(Vector2(dx + k * 22, p.position.y + 44), 7.0 if k == page else 5.0,
				hc if k == page else Color(1, 1, 1, 0.25))
	var pg: Dictionary = pages[page]
	# 그림
	var pic := pic_rect(vs)
	G2.panel(ci, pic, Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.12), 1.5, 16)
	var f: Callable = pg.get("draw", Callable())
	if f.is_valid():
		f.call(ci, pic.grow(-14), t)
	# 설명
	var tr := text_rect(vs)
	ci.draw_string(UiKit.font(), Vector2(tr.position.x, tr.position.y + 34), "%d. %s" % [page + 1, String(pg.get("head", ""))],
			HORIZONTAL_ALIGNMENT_LEFT, tr.size.x, 32, Color8(255, 230, 170))
	var y := tr.position.y + 84.0
	for raw in pg.get("lines", []):
		var s := String(raw)
		if s == "":
			y += 14.0
			continue
		var bullet := not s.begins_with(" ")
		s = s.strip_edges()
		var wrapped := UiBook.wrap_text(s, 23.0, tr.size.x - 26)
		for j in wrapped.size():
			if j == 0 and bullet:
				ci.draw_circle(Vector2(tr.position.x + 7, y - 8), 4, th.edge)
			ci.draw_string(UiKit.font(), Vector2(tr.position.x + 22, y), String(wrapped[j]), HORIZONTAL_ALIGNMENT_LEFT,
					tr.size.x - 22, 23, Color(1, 1, 1, 0.92))
			y += 33.0
		y += 6.0
	# 넘기기 — 도감 창과 같은 자리(아래 가운데, 사이에 쪽 번호)
	G2.text_mid(ci, Vector2(p.get_center().x, nav_rect(vs, 0).get_center().y), "%d / %d" % [page + 1, pages.size()], 24, Color(1, 1, 1, 0.8), 0)
	for k in 2:
		var nr := nav_rect(vs, k)
		var last := page >= pages.size() - 1
		var lab := "이전" if k == 0 else ("다 읽음" if last else "다음")
		if k == 0 and page == 0:
			continue
		UiKit.draw(ci, nr, "menu", lab, th.start if (k == 1) else th.hub, th.start_text if k == 1 else th.hub_text, th,
				nr.has_point(mouse), t)


## 조작 쪽 그림 — 키 모양 + 하는 일. rows = [["Space", "점프"], ...]. 모든 게임 규칙서의 "조작" 쪽이 같이 쓴다.
static func keys_pic(ci: CanvasItem, r: Rect2, rows: Array) -> void:
	var f := UiKit.font()
	var step := minf(64.0, r.size.y / maxf(1.0, rows.size()))
	var y0 := r.get_center().y - step * rows.size() * 0.5
	for i in rows.size():
		var key := String(rows[i][0])
		var kw := maxf(64.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28.0)
		var kr := Rect2(r.position.x + r.size.x * 0.42 - kw, y0 + i * step + 6, kw, step - 14)
		G2.panel(ci, Rect2(kr.position + Vector2(0, 4), kr.size), Color(0, 0, 0, 0.5), Color(), 0.0, 8)
		G2.panel(ci, kr, Color8(236, 232, 224), Color8(60, 56, 60), 2.0, 8)
		G2.text_mid(ci, kr.get_center(), key, 22, Color8(40, 36, 40), 0)
		ci.draw_string(f, Vector2(r.position.x + r.size.x * 0.42 + 18, kr.get_center().y + 8), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT,
				r.size.x * 0.56, 22, Color(1, 1, 1, 0.9))


## 그림이 따로 없는 쪽 — 낱말 몇 개를 큰 표지로. words = ["셋 맞추기", "이동 제한", ...].
static func words_pic(ci: CanvasItem, r: Rect2, words: Array, col: Color) -> void:
	var step := minf(70.0, r.size.y / maxf(1.0, words.size()))
	var y0 := r.get_center().y - step * words.size() * 0.5
	for i in words.size():
		var wr := Rect2(r.position.x + r.size.x * 0.12, y0 + i * step + 6, r.size.x * 0.76, step - 14)
		G2.panel(ci, wr, Color(col, 0.22), Color(col, 0.8), 2.0, 10)
		G2.text_mid(ci, wr.get_center(), String(words[i]), 24, Color(1, 1, 1, 0.95), 0)
