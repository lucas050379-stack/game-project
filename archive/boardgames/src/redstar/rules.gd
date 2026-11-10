class_name RsRules
extends RefCounted

## 붉은 별 개척단 규칙서 쪽들(`UiRules` 에 넘긴다 — 아르카나 · 제국과 같은 창). 그림은 판과 같은 `RsArt` 함수로 그린다.
## **규칙을 바꾸면 여기 글도 같이** — 화면에 그대로 나가서 규칙만 바뀌면 규칙서가 거짓말을 한다.


static func _label(ci: CanvasItem, at: Vector2, s: String, size: float = 22.0, col: Color = Color(1, 1, 1, 0.9)) -> void:
	RsArt.text(ci, at, s, size, col, 4)


## 헥스 몇 칸 — kinds 는 칸마다 놓인 것("" = 빈 땅).
static func _hexes(ci: CanvasItem, c: Vector2, hs: float, kinds: Array, t: float) -> void:
	var cells := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1)]
	for k in mini(cells.size(), kinds.size()):
		var q: Vector2i = cells[k]
		var tile := {}
		if String(kinds[k]) != "":
			tile = {kind = String(kinds[k]), owner = k % 2}
		RsArt.cell(ci, c + Vector2(hs * sqrt(3.0) * (q.x + q.y * 0.5), hs * 1.5 * q.y), hs, RsD.cell_kind(q), tile, {}, false, t)


static func pages() -> Array:
	return [
		{head = "목표", lines = [
			"붉은 행성을 사람이 사는 땅으로 바꿉니다.",
			"세 지표(온도, 대기, 바다)를 끝까지 올리면 그 세대를 마치고 게임이 끝납니다.",
			"끝났을 때 점수가 높은 쪽이 이깁니다: 개척 등급 + 녹지 + 도시 + 카드 점수 + 목표와 후원.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			_hexes(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.13, ["ocean", "green", "city", "green", "", "ocean", ""], t)},
		{head = "지표와 개척 등급", lines = [
			"지표를 한 단계 올린 사람은 개척 등급이 1 오릅니다.",
			"개척 등급은 점수이면서, 세대마다 받는 크레딧이기도 합니다.",
			"온도는 열 %d로, 대기는 녹지를 놓아서, 바다는 바다 타일을 놓아서 올립니다." % RsD.HEAT_COST,
			"화면 위 가운데 세 막대가 지표입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			var names := ["온도", "대기", "바다"]
			var cols := [Color8(240, 120, 70), Color8(120, 200, 240), Color8(70, 130, 230)]
			for k in 3:
				var y := r.position.y + r.size.y * (0.3 + k * 0.2)
				_label(ci, Vector2(r.position.x + r.size.x * 0.2, y), names[k], 24)
				for j in 8:
					ci.draw_rect(Rect2(r.position.x + r.size.x * 0.32 + j * 34, y - 9, 28, 18), cols[k] if j < 5 - k else Color(1, 1, 1, 0.12))},
		{head = "세대의 흐름", lines = [
			"세대가 시작하면 카드 %d장을 보고, 살 것만 장당 크레딧 %d에 삽니다." % [RsD.RESEARCH_N, RsD.CARD_BUY],
			"번갈아 행동을 하나씩 합니다. 더 할 것이 없으면 패스합니다.",
			"둘 다 패스하면 생산: 전력은 열이 되고, 자원마다 생산만큼 들어옵니다.",
			"크레딧은 개척 등급 + 크레딧 생산만큼 들어옵니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			for k in RsD.N_RES:
				var c := Vector2(r.position.x + r.size.x * (0.2 + (k % 3) * 0.3), r.position.y + r.size.y * (0.36 + (k / 3) * 0.26))
				RsArt.res_icon(ci, c, 26, k)
				_label(ci, c + Vector2(0, 44), RsD.RES_NAME[k], 20)},
		{head = "내 차례에 하는 일", lines = [
			"카드 내기: 손패의 카드를 값을 내고 냅니다. 조건(지표, 태그)이 맞아야 합니다.",
			"기본 사업: 크레딧으로 바다, 녹지, 도시, 생산을 바로 삽니다.",
			"식물 %d로 녹지, 열 %d로 온도." % [RsD.GREEN_COST, RsD.HEAT_COST],
			"운영 행동: 낸 운영 카드의 행동을 세대에 한 번 씁니다.",
			"목표 선점과 후원 개설: 크레딧을 내고 끝날 때 점수를 겁니다.",
			"패스: 이번 세대를 마칩니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var w := minf(r.size.x * 0.34, 170.0)
			for k in 2:
				RsArt.card(ci, Rect2(r.get_center().x + (k - 1) * (w + 16) + 8, r.get_center().y - w * 0.75, w, w * 1.5), RsD.card(k * 7), 0, t)},
		{head = "카드와 태그", lines = [
			"왼쪽 위 숫자가 값입니다. 건물 카드에는 금속(하나에 크레딧 %d)을, 우주 카드에는 합금(하나에 %d)을 대신 쓸 수 있습니다." % [RsD.METAL_VAL, RsD.ALLOY_VAL],
			"카드 아래 표지가 태그입니다. 태그 수를 조건이나 효과로 세는 카드가 있습니다.",
			"건설 카드는 한 번 효과를 내고 남고, 운영 카드는 행동을 주고, 사건 카드는 쓰고 버립니다.",
			"아래 손패에서 카드를 누르면 크게 보입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var w := minf(r.size.x * 0.42, 210.0)
			RsArt.card(ci, Rect2(r.get_center() - Vector2(w * 0.5, w * 0.75), Vector2(w, w * 1.5)), RsD.card(12), 0, t)},
		{head = "타일과 점수", lines = [
			"바다: 정해진 바다 칸에만 놓습니다. 바다 타일 옆에 타일을 놓으면 크레딧 2를 받습니다.",
			"녹지: 내 타일 옆에 놓습니다. 대기를 올리고 1점입니다.",
			"도시: 다른 도시 옆에는 못 놓습니다. 둘레 녹지마다 1점입니다(누구 것이든).",
			"칸에 그려진 자원은 그 칸에 놓을 때 받습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			_hexes(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.13, ["city", "green", "green", "green", "ocean", "", "green"], t)},
		{head = "화면 보는 법", lines = [
			"왼쪽이 나, 오른쪽이 상대입니다. 보유와 생산이 자원마다 나란히 있습니다.",
			"가운데 지도 아래 줄이 행동, 맨 아래가 손패입니다.",
			"낸 카드 단추를 누르면 그 사람이 낸 카드를 봅니다.",
			"왼쪽 위 나가기 옆의 규칙 단추로 언제든 이 책을 다시 엽니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			for k in 3:
				var box := Rect2(r.position.x + r.size.x * (0.06 + k * 0.31), r.position.y + r.size.y * 0.25, r.size.x * 0.26, r.size.y * 0.5)
				ci.draw_rect(box, RsArt.PANEL)
				ci.draw_rect(Rect2(box.position, Vector2(box.size.x, 5)), RsArt.ACCENT if k != 1 else Color(1, 1, 1, 0.2))
				_label(ci, box.get_center(), ["나", "지도", "상대"][k], 24)},
	]
