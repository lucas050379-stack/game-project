class_name UiKeys
extends RefCounted

## 키 설정 창 — 게임마다 "하는 일 → 키"를 바꿔 저장한다(사용자 요청 11-10: 처음 화면에서 입력 키를 바꿀 수 있게).
## 저장은 `user://keys.cfg` 한 파일(게임 이름 구역 · 하는 일 이름 = 키 코드). 게임은 `UiKeys.code(게임, 하는 일, 기본 키)` 로 읽는다.
## 쓰는 법: `keys.show("tiger", [["jump", "점프", KEY_SPACE], ...])` → 입력을 `keys.key(code)` · `keys.click(p, vs)` 에 먼저 넘기고 `keys.draw(self, vs, t)`.
## 줄을 누르면 "키를 누르세요" 가 되고 다음에 누른 키가 들어간다(Esc 는 취소). 다른 일에 쓰던 키면 둘이 맞바뀐다.

static var _map := {}
static var _loaded := false

var open := false
var game := ""
var actions: Array = []        ## [[하는 일, 보이는 이름, 기본 키], ...]
var waiting := -1              ## 키를 기다리는 줄(-1 = 없음)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load("user://keys.cfg") != OK:
		return
	for sec in cfg.get_sections():
		for k in cfg.get_section_keys(sec):
			_map["%s/%s" % [sec, k]] = int(cfg.get_value(sec, k, 0))


static func _save() -> void:
	var cfg := ConfigFile.new()
	for key: String in _map:
		var parts := key.split("/")
		cfg.set_value(parts[0], parts[1], int(_map[key]))
	cfg.save("user://keys.cfg")


## 그 게임 · 그 일의 키. 안 바꿨으면 기본 키.
static func code(g: String, action: String, default: int) -> int:
	_load()
	return int(_map.get("%s/%s" % [g, action], default))


## 그 일의 키가 지금 눌려 있나(누르고 있는 동안을 보는 일 — 숙이기 · 날기).
static func held(g: String, action: String, default: int) -> bool:
	return Input.is_physical_key_pressed(code(g, action, default)) or Input.is_key_pressed(code(g, action, default))


func show(p_game: String, p_actions: Array) -> void:
	game = p_game
	actions = p_actions
	waiting = -1
	open = true


## 줄이 화면 높이에 안 들어가면 두 단 — 버거왕(12줄)은 한 단이면 창이 화면 밖으로 나가 닫기 · 기본값을 못 눌렀다.
func _cols(vs: Vector2) -> int:
	return 1 if 220.0 + actions.size() * 64.0 <= vs.y - 40.0 else 2


func _rows(vs: Vector2) -> int:
	return ceili(actions.size() / float(_cols(vs)))


func panel(vs: Vector2) -> Rect2:
	var w := 600.0 if _cols(vs) == 1 else minf(1080.0, vs.x - 40.0)
	var h := 150.0 + _rows(vs) * 64.0 + 70.0
	return Rect2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - h * 0.5, w, h)


func row_rect(vs: Vector2, i: int) -> Rect2:
	var p := panel(vs)
	var cols := _cols(vs)
	var cw := (p.size.x - 60.0 - 20.0 * (cols - 1)) / cols
	return Rect2(p.position.x + 30 + (i / _rows(vs)) * (cw + 20.0), p.position.y + 96 + (i % _rows(vs)) * 64.0, cw, 54)


func close_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	return Rect2(p.end.x - 150, p.position.y + 18, 130, 50)


func reset_rect(vs: Vector2) -> Rect2:
	var p := panel(vs)
	return Rect2(p.position.x + 30, p.end.y - 66, 180, 48)


## 눌린 키. 창이 열려 있으면 늘 true(게임이 그 키를 쓰지 않게).
func key(k: int) -> bool:
	if not open:
		return false
	if waiting >= 0:
		if k != KEY_ESCAPE:
			var mine := "%s/%s" % [game, String(actions[waiting][0])]
			var old := code(game, String(actions[waiting][0]), int(actions[waiting][2]))
			for a: Array in actions:   # 다른 일이 쓰던 키면 맞바꾼다
				if String(a[0]) != String(actions[waiting][0]) and code(game, String(a[0]), int(a[2])) == k:
					_map["%s/%s" % [game, String(a[0])]] = old
			_map[mine] = k
			_save()
		waiting = -1
		return true
	if k == KEY_ESCAPE:
		open = false
	return true


func click(p: Vector2, vs: Vector2) -> bool:
	if not open:
		return false
	if close_rect(vs).has_point(p):
		open = false
		waiting = -1
		return true
	if reset_rect(vs).has_point(p):
		for a: Array in actions:
			_map.erase("%s/%s" % [game, String(a[0])])
		_save()
		waiting = -1
		return true
	for i in actions.size():
		if row_rect(vs, i).has_point(p):
			waiting = i
			return true
	waiting = -1
	return true


func draw(ci: CanvasItem, vs: Vector2, t: float) -> void:
	if not open:
		return
	var th := UiKit.theme(game)
	var mouse := ci.get_local_mouse_position()
	ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.04, 0.75), true)
	var p := panel(vs)
	G2.panel(ci, p, Color8(30, 24, 36), th.start, 3.0, 22)
	ci.draw_string(UiKit.font(), p.position + Vector2(30, 56), "키 설정", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1))
	UiKit.draw(ci, close_rect(vs), "menu", "닫기", th.hub, th.hub_text, th, close_rect(vs).has_point(mouse), t)
	for i in actions.size():
		var r := row_rect(vs, i)
		var on := waiting == i
		G2.panel(ci, r, Color(1, 0.85, 0.4, 0.2) if on else Color(1, 1, 1, 0.07 if not r.has_point(mouse) else 0.14), Color(1, 1, 1, 0.2), 1.2, 10)
		ci.draw_string(UiKit.font(), Vector2(r.position.x + 18, r.get_center().y + 9), String(actions[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.95))
		var label := "키를 누르세요" if on else OS.get_keycode_string(code(game, String(actions[i][0]), int(actions[i][2])))
		var kw := maxf(90.0, UiKit.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 30.0)
		var kr := Rect2(r.end.x - kw - 12, r.position.y + 8, kw, r.size.y - 16)
		G2.panel(ci, kr, Color8(236, 232, 224) if not on else Color8(255, 220, 120), Color8(60, 56, 60), 2.0, 8)
		G2.text_mid(ci, kr.get_center(), label, 22, Color8(40, 36, 40), 0)
	UiKit.draw(ci, reset_rect(vs), "menu", "기본값으로", th.hub, th.hub_text, th, reset_rect(vs).has_point(mouse), t)
	ci.draw_string(UiKit.font(), Vector2(p.position.x + 230, p.end.y - 34), "줄을 누르고 새 키를 누르세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.6))
