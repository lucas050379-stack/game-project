class_name EmRules
extends RefCounted

## 제국 연대기 규칙서 쪽들(`UiRules` 에 넘긴다). 그림은 판과 같은 `EmArt` 함수로 그린다.
## **규칙을 바꾸면 여기 글도 같이** — 화면에 그대로 나가서 규칙만 바뀌면 규칙서가 거짓말을 한다.
## 숫자는 될 수 있는 대로 `EmD` 상수에서 읽는다(군사 손실 · 버리기 · 불가사의 수 · 과학 승리).

const CARD := Vector2(108, 100)


static func _of_kind(k: int) -> Dictionary:
	for c: Dictionary in EmD.all_cards():
		if int(c.kind) == k:
			return c
	return {}


static func _sci_cards(n: int) -> Array:
	var out := []
	var seen := {}
	for c: Dictionary in EmD.all_cards():
		if c.eff.has("sci") and not seen.has(int(c.eff.sci)):
			seen[int(c.eff.sci)] = true
			out.append(c)
			if out.size() >= n:
				break
	return out


## 그림 칸 안에 카드 한 장(크기 s 배).
static func _card_at(ci: CanvasItem, c: Vector2, card: Dictionary, s: float, face: bool = true, state: int = 0, t: float = 0.0, age: int = 0) -> void:
	var sz := CARD * s
	EmArt.card(ci, Rect2(c - sz * 0.5, sz), card, face, state, t, age)


static func _label(ci: CanvasItem, at: Vector2, s: String, size: float = 22.0, col: Color = Color(1, 1, 1, 0.9)) -> void:
	EmArt.text(ci, at, s, size, col, 4)


static func pages() -> Array:
	var loss: Array = EmD.MIL_LOSS
	return [
		{head = "이기는 길은 셋", lines = [
			"두 제국이 세 시대 동안 피라미드에서 카드를 한 장씩 가져가며 문명을 키웁니다.",
			"군사 승리: 군사 말이 상대 수도에 닿으면 그 자리에서 이깁니다.",
			"과학 승리: 서로 다른 과학 심볼 %d가지를 모으면 그 자리에서 이깁니다." % EmD.SCI_WIN,
			"문명 승리: 아무도 먼저 못 이기면 3시대가 끝날 때 점수가 높은 쪽이 이깁니다.",
			"",
			"한 길만 파면 상대가 막기 쉽습니다. 상대가 노리는 것을 보고 끊어야 합니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var kinds := [EmD.K.RED, EmD.K.GREEN, EmD.K.BLUE]
			var names := ["군사", "과학", "문명"]
			for k in 3:
				var cx := r.position.x + r.size.x * (0.2 + 0.3 * k)
				var cy := r.get_center().y - 20 + sin(t * 1.2 + k) * 3.0
				_card_at(ci, Vector2(cx, cy), _of_kind(kinds[k]), 1.25, true, 0, t)
				_label(ci, Vector2(cx, cy + 100), names[k], 28, EmD.KIND_COL[kinds[k]].lightened(0.35))},
		{head = "내 차례에 하는 일", lines = [
			"피라미드에서 위에 덮인 카드가 없는 카드 한 장을 가져옵니다. 초록 테는 지금 지을 수 있는 카드입니다.",
			"가져온 카드로 셋 중 하나를 합니다.",
			"  짓기: 비용을 내고 내 도시에 둡니다.",
			"  버리기: 돈 %d + 내 상업(노랑) 카드 수만큼 받습니다." % EmD.DISCARD_BASE,
			"  불가사의: 카드를 불가사의 밑에 넣고 그 불가사의를 짓습니다.",
			"카드를 가져가면 밑에 덮여 있던 카드가 뒤집혀 드러납니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var c := r.get_center() + Vector2(0, -40)
			var s := 0.95
			var a1 := EmD.age_cards(0)
			# 뒷줄(덮임) 셋 + 앞줄(열림) 둘 — 판과 같은 겹침
			for k in 3:
				_card_at(ci, c + Vector2((k - 1) * CARD.x * s, -58), a1[k], s, false, 0, t, 0)
			for k in 2:
				_card_at(ci, c + Vector2((k - 0.5) * CARD.x * s, 4), a1[6 + k], s, true, 2 if k == 0 else 0, t, 0)
			_label(ci, c + Vector2(0, -128), "덮인 카드는 못 가져감", 20, Color(1, 1, 1, 0.6))
			_label(ci, c + Vector2(0, 74), "열린 카드", 20, Color8(140, 255, 140))
			var acts := [["짓기", Color8(90, 170, 90)], ["버리기", Color8(180, 140, 60)], ["불가사의", Color8(150, 110, 50)]]
			for k in 3:
				var br := Rect2(r.get_center().x - 210 + k * 145, r.end.y - 70, 130, 46)
				EmArt.rr(ci, br, 12, acts[k][1], EmArt.INK, 2.0)
				_label(ci, br.get_center(), acts[k][0], 22, Color(1, 1, 1))},
		{head = "자원과 돈", lines = [
			"카드 아래 그림이 비용입니다. 동그라미는 원자재(나무, 점토, 돌), 네모는 가공품(유리, 양피지), 동전은 돈입니다.",
			"자원은 내 원자재, 가공품 카드가 매 턴 만들어 줍니다. 써도 줄지 않고 쌓이지도 않습니다.",
			"모자란 자원은 돈으로 삽니다. 한 개 값은 2 + 상대가 그 자원을 만드는 수입니다. 상대가 많이 만들수록 비쌉니다.",
			"연계: 앞 단계 건물이 있으면 공짜로 짓습니다(가격표에 연계라고 나옴).",
			"가져올 수 있는 카드 아래 가격표에 실제로 낼 돈이 나옵니다. 모자라면 빨강입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in EmD.N_RES:
				var p := Vector2(r.position.x + r.size.x * (0.12 + 0.19 * k), r.position.y + 50)
				EmArt.res_chip(ci, p, 20, k)
				_label(ci, p + Vector2(0, 40), EmD.RES_NAME[k], 22)
			var demo: Dictionary = {}
			for c: Dictionary in EmD.age_cards(1):
				if int(c.coin) == 0 and c.cost.max() > 0 and int(c.kind) == EmD.K.BLUE:
					demo = c
					break
			if demo.is_empty():
				demo = _of_kind(EmD.K.BLUE)
			var cc := r.get_center() + Vector2(-90, 40)
			_card_at(ci, cc, demo, 1.2, true, 0, t, 1)
			_label(ci, cc + Vector2(0, 84), "비용은 카드 아래", 20, Color(1, 1, 1, 0.7))
			var tag := Rect2(r.get_center() + Vector2(70, 10), Vector2(150, 44))
			EmArt.rr(ci, tag, 10, Color(0, 0, 0, 0.6), EmArt.GOLD, 2.0)
			EmArt.coin(ci, tag.position + Vector2(28, 22), 14, 3)
			_label(ci, tag.position + Vector2(92, 22), "돈 3", 22)
			_label(ci, tag.get_center() + Vector2(0, 46), "가격표", 20, Color(1, 1, 1, 0.7))},
		{head = "카드 색", lines = [
			"원자재(갈색): 나무, 점토, 돌을 만듭니다.",
			"가공품(회색): 유리, 양피지를 만듭니다.",
			"문화(파랑): 점수.",
			"과학(초록): 과학 심볼. 승리와 발전 토큰으로 이어집니다.",
			"군사(빨강): 군사 말을 상대 쪽으로 밉니다.",
			"상업(노랑): 돈, 싸게 사기, 버리기 수익.",
			"길드(보라): 3시대에만. 조건에 따라 점수.",
			"카드 위 색 띠에 효과가 줄여 적혀 있습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 7:
				var row := 0 if k < 4 else 1
				var col := k if k < 4 else k - 4
				var n := 4 if row == 0 else 3
				var cx := r.get_center().x + (col - (n - 1) * 0.5) * 132.0
				var cy := r.position.y + r.size.y * (0.27 if row == 0 else 0.72)
				_card_at(ci, Vector2(cx, cy), _of_kind(k), 1.1, true, 0, t, 2 if k == EmD.K.PURPLE else 0)
				_label(ci, Vector2(cx, cy + 74), EmD.KIND_NAME[k], 22, EmD.KIND_COL[k].lightened(0.4))},
		{head = "불가사의", lines = [
			"시작 전에 불가사의 8개를 4개씩 두 번 나눠 고릅니다(한 개, 두 개, 한 개 순서).",
			"짓는 법: 피라미드에서 카드를 하나 가져와 불가사의 밑에 넣고, 불가사의 비용을 냅니다. 밑에 넣은 카드는 효과 없이 사라집니다.",
			"둘이 합쳐 %d개까지만 지을 수 있습니다. 다 차면 남은 불가사의는 못 짓습니다(빨간 줄)." % EmD.WONDER_MAX,
			"지은 불가사의는 금테와 V 표시가 붙습니다.",
			"카드를 고른 뒤 오른쪽 아래 빛나는 내 불가사의를 누르면 짓습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var big := Rect2(r.get_center().x - 125, r.position.y + 10, 250, 250)
			EmArt.wonder(ci, big, EmD.wonder(0), 0, t, true)
			var labels := ["지을 수 있음", "지음", "못 지음"]
			var states := [3, 1, 2]
			for k in 3:
				var tr := Rect2(r.position.x + 20 + k * (r.size.x - 40) / 3.0 + 6, r.end.y - 96, (r.size.x - 40) / 3.0 - 12, 50)
				EmArt.wonder(ci, tr, EmD.wonder(k + 1), states[k], t)
				_label(ci, Vector2(tr.get_center().x, tr.end.y + 22), labels[k], 20, Color(1, 1, 1, 0.75))},
		{head = "군사", lines = [
			"빨간 카드를 지으면 군사 말이 숫자만큼 상대 수도 쪽으로 밀립니다. 상대가 지으면 내 쪽으로 옵니다.",
			"말이 %d칸, %d칸을 처음 넘으면 상대가 돈 %d, %d을 잃습니다(트랙 위 동전)." % [int(loss[0][0]), int(loss[1][0]), int(loss[0][1]), int(loss[1][1])],
			"말이 상대 수도(%d칸)에 닿으면 그 자리에서 이깁니다." % EmD.MIL_WIN,
			"끝까지 가면, 말이 상대 쪽으로 3칸 넘어가 있으면 2점, 6칸이면 5점입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var y := r.get_center().y - 30
			var w := (r.size.x - 80) / 19.0
			var x0 := r.position.x + 40 + w * 0.5
			EmArt.rr(ci, Rect2(r.position.x + 34, y - 26, r.size.x - 68, 52), 10, Color8(40, 30, 24), EmArt.GOLD.darkened(0.3), 2.0)
			for v in range(-9, 10):
				var x := x0 + (v + 9) * w
				var c := Color(1, 1, 1, 0.12)
				if absi(v) >= 6:
					c = Color(1, 0.4, 0.3, 0.25)
				elif absi(v) >= 3:
					c = Color(1, 0.8, 0.3, 0.18)
				ci.draw_rect(Rect2(x - w * 0.42, y - 18, w * 0.84, 36), c)
			for th: Array in loss:
				for sg in [-1, 1]:
					EmArt.coin(ci, Vector2(x0 + (int(th[0]) * sg + 9) * w, y), 10, int(th[1]))
			for q in 2:
				var cp := Vector2(x0 + ((-9.4 if q == 0 else 9.4) + 9.0) * w, y)
				ci.draw_circle(cp, 18, EmArt.INK)
				ci.draw_circle(cp, 16, EmD.PLAYER_COL[q])
				EmArt.text(ci, cp, "나" if q == 0 else "적", 20, Color(1, 1, 1), 3)
			var pv := 4.0 + sin(t * 1.5) * 1.5
			var px := x0 + (pv + 9) * w
			ci.draw_circle(Vector2(px, y), 12, EmArt.INK)
			ci.draw_circle(Vector2(px, y), 10, Color8(220, 70, 60))
			_label(ci, Vector2(px, y + 52), "군사 말", 20, Color8(255, 150, 130))
			_label(ci, Vector2(x0 + 13 * w, y - 48), "2점", 20, Color(1, 1, 1, 0.6))
			_label(ci, Vector2(x0 + 16 * w, y - 48), "5점", 20, Color(1, 1, 1, 0.6))
			_card_at(ci, Vector2(r.get_center().x, r.end.y - 70), _of_kind(EmD.K.RED), 1.1, true, 0, t)},
		{head = "과학과 발전 토큰", lines = [
			"초록 카드에는 과학 심볼이 하나씩 있습니다. 심볼은 7가지입니다.",
			"서로 다른 심볼 %d가지를 모으면 그 자리에서 이깁니다." % EmD.SCI_WIN,
			"같은 심볼을 두 장 모으면 군사 트랙 아래 발전 토큰(초록 둥근 판) 중 하나를 고릅니다. 토큰은 판 내내 쓰는 좋은 효과입니다.",
			"내 판의 초록 꼬리표가 지금 가진 심볼입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var sc := _sci_cards(4)
			for k in sc.size():
				_card_at(ci, Vector2(r.get_center().x + (k - 1.5) * 124, r.position.y + 80), sc[k], 1.05, true, 0, t, int(sc[k].age))
			var x := r.position.x + 30
			var y := r.get_center().y + 40
			for s in 7:
				var lab: String = EmD.SCI_NAME[s]
				var w := EmArt.font().get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 16
				EmArt.rr(ci, Rect2(x, y - 16, w, 32), 8, EmD.KIND_COL[EmD.K.GREEN])
				EmArt.text(ci, Vector2(x + w * 0.5, y), lab, 22, Color(1, 1, 1), 3)
				x += w + 8
			for k in 2:
				EmArt.token(ci, Rect2(r.get_center().x - 170 + k * 190, r.end.y - 66, 150, 46), EmD.token(k), k == 0, t)},
		{head = "시대와 점수", lines = [
			"1시대, 2시대, 3시대 피라미드를 차례로 씁니다. 시대마다 모양이 다릅니다.",
			"2, 3시대는 군사에서 밀리는 쪽이 누가 먼저 둘지 고릅니다.",
			"3시대가 끝나면 점수를 셉니다: 문화, 과학, 상업, 길드, 불가사의, 발전 토큰, 군사, 돈(3당 1점).",
			"점수가 같으면 문화 점수가 높은 쪽이 이깁니다.",
			"내 판 이름 옆 숫자가 지금 점수입니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				var c := Vector2(r.get_center().x + (k - 1) * 150, r.position.y + 90)
				_card_at(ci, c, {}, 1.3, false, 0, t, k)
				_label(ci, c + Vector2(0, 86), "%d시대" % (k + 1), 24)
			var rows := ["문화", "과학", "불가사의", "군사", "돈"]
			var vals := [[12, 9], [4, 0], [8, 5], [2, 0], [3, 1]]
			var y0 := r.position.y + r.size.y * 0.55
			for k in rows.size():
				var y := y0 + k * 30
				ci.draw_string(EmArt.font(), Vector2(r.get_center().x - 150, y), rows[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.85))
				for q in 2:
					EmArt.text(ci, Vector2(r.get_center().x + 60 + q * 90, y - 7), str(vals[k][q]), 22, EmD.PLAYER_COL[q], 3)},
		{head = "화면 보는 법", lines = [
			"가운데 위: 군사 트랙과 발전 토큰.",
			"가운데: 피라미드. 카드를 누르면 오른쪽에 효과와 짓기, 버리기 단추가 나옵니다.",
			"왼쪽: 상대(위)와 나(아래). 누르면 그 사람이 지은 것을 전부 봅니다.",
			"오른쪽 아래: 내 불가사의.",
			"아래 [버린 카드]: 버려진 카드를 봅니다.",
			"이 규칙서는 판 아래 [규칙] 단추로 언제든 다시 볼 수 있습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var k := minf(r.size.x / 1280.0, r.size.y / 720.0) * 0.98
			var o := r.get_center() - Vector2(640, 360) * k
			var boxes := [
				[Rect2(14, 84, 276, 304), "상대", EmD.PLAYER_COL[1]],
				[Rect2(14, 402, 276, 304), "나", EmD.PLAYER_COL[0]],
				[Rect2(300, 18, 680, 100), "군사 트랙, 발전 토큰", Color8(220, 70, 60)],
				[Rect2(330, 160, 620, 440), "피라미드", EmArt.GOLD],
				[Rect2(990, 84, 276, 340), "고른 카드", Color(1, 1, 1)],
				[Rect2(790, 670, 140, 38), "규칙", Color8(200, 170, 120)],
				[Rect2(990, 440, 276, 266), "내 불가사의", Color8(150, 110, 50)],
				[Rect2(410, 670, 200, 38), "버린 카드", Color8(200, 170, 120)],
			]
			EmArt.rr(ci, Rect2(o, Vector2(1280, 720) * k), 10, Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.2), 1.5)
			for b: Array in boxes:
				var br: Rect2 = b[0]
				var rr2 := Rect2(o + br.position * k, br.size * k)
				var col: Color = b[2]
				EmArt.rr(ci, rr2, 8, Color(col, 0.18), Color(col, 0.8), 2.0)
				EmArt.text(ci, rr2.get_center(), String(b[1]), 20, Color(1, 1, 1), 4)},
	]
