class_name AcRules
extends RefCounted

## 아르카나 컬렉션 규칙서 쪽들(`UiRules` 에 넘긴다). 그림은 판과 같은 `AcArt` 함수로 그린다.
## **규칙을 바꾸면 여기 글도 같이** — 숫자는 될 수 있는 대로 `AcD` 상수에서 읽는다.

const CARD := Vector2(106, 150)


static func _deck_card(tier: int, col: int) -> Dictionary:
	for c: Dictionary in AcD.deck():
		if int(c.tier) == tier and int(c.col) == col:
			return c
	return AcD.deck()[0]


static func _card_at(ci: CanvasItem, c: Vector2, card: Dictionary, s: float, hl: int = 0, t: float = 0.0) -> void:
	var sz := CARD * s
	AcArt.card(ci, Rect2(c - sz * 0.5, sz), card, hl, t)


static func _label(ci: CanvasItem, at: Vector2, s: String, size: float = 22.0, col: Color = Color(1, 1, 1, 0.9)) -> void:
	G2.text_mid(ci, at, s, size, col, 4)


static func pages() -> Array:
	return [
		{head = "목표", lines = [
			"자원을 모아 성물을 갖추고 점수를 모읍니다.",
			"누군가 %d점에 닿으면 그 라운드를 끝까지 돌고 끝납니다. 모두 같은 횟수만큼 둡니다." % AcD.WIN_PTS,
			"점수가 가장 높은 사람이 이깁니다. 같으면 성물이 적은 쪽이 이깁니다.",
			"점수는 성물 왼쪽 위 숫자와 찾아온 영웅(%d점)에서 나옵니다." % AcD.HERO_PTS,
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				var c := Vector2(r.get_center().x + (k - 1) * 150, r.get_center().y - 40 + sin(t * 1.3 + k) * 4.0)
				_card_at(ci, c, _deck_card(k, [0, 2, 3][k]), 1.15, 0, t)
			_label(ci, Vector2(r.get_center().x, r.end.y - 30), "%d점에 먼저 닿기" % AcD.WIN_PTS, 30, Color8(255, 226, 150))},
		{head = "내 차례에 하는 일", lines = [
			"셋 중 하나만 합니다.",
			"자원 가져오기: 서로 다른 자원 셋, 또는 같은 자원 둘. 같은 자원 둘은 그 자원이 %d개 이상 남았을 때만." % AcD.TAKE2_MIN,
			"성물 갖추기: 비용을 내고 판의 성물이나 내가 봉인한 성물을 삽니다.",
			"봉인: 성물 하나를 맡아 두고 별가루 하나를 받습니다.",
			"차례가 끝날 때 조건을 채운 영웅이 있으면 찾아옵니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var y := r.position.y + 60
			_label(ci, Vector2(r.get_center().x, y - 30), "서로 다른 셋", 22, Color(1, 1, 1, 0.75))
			for k in 3:
				AcArt.token(ci, Vector2(r.get_center().x + (k - 1) * 70, y + 20), 26, k)
			_label(ci, Vector2(r.get_center().x, y + 90), "또는 같은 둘", 22, Color(1, 1, 1, 0.75))
			for k in 2:
				AcArt.token(ci, Vector2(r.get_center().x + (k - 0.5) * 70, y + 140), 26, 3)
			var c := Vector2(r.get_center().x - 90, r.end.y - 95)
			_card_at(ci, c, _deck_card(0, 1), 0.95, 1, t)
			_label(ci, c + Vector2(0, 88), "갖추기", 22, Color8(140, 255, 140))
			var c2 := Vector2(r.get_center().x + 90, r.end.y - 95)
			AcArt.card_back(ci, Rect2(c2 - CARD * 0.95 * 0.5, CARD * 0.95), 1, 1, 0, t)
			AcArt.token(ci, c2 + Vector2(44, -60), 18, AcD.GOLD)
			_label(ci, c2 + Vector2(0, 88), "봉인", 22, Color8(200, 170, 255))},
		{head = "자원 토큰", lines = [
			"원소 자원은 다섯 가지입니다: 화염, 물, 숲, 빛, 그림자.",
			"별가루는 무엇으로든 쓸 수 있는 만능 자원이고, 봉인할 때만 받습니다.",
			"토큰은 %d개까지만 들 수 있습니다. 넘치면 차례 끝에 골라서 돌려놓습니다." % AcD.HAND_MAX,
			"성물을 사며 낸 토큰은 은행으로 돌아갑니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 6:
				var col := k % 3
				var row := k / 3
				var p := Vector2(r.position.x + r.size.x * (0.22 + 0.28 * col), r.position.y + r.size.y * (0.3 + 0.38 * row))
				AcArt.token(ci, p + Vector2(0, sin(t * 1.5 + k) * 3.0), 40, k)
				_label(ci, p + Vector2(0, 66), AcD.NAMES[k], 24, Color(1, 1, 1, 0.9))},
		{head = "성물 카드", lines = [
			"성물은 견습, 장인, 전설 세 단계입니다. 높은 단계일수록 비싸고 점수가 큽니다.",
			"왼쪽 위 숫자: 점수.",
			"오른쪽 위 보석: 이 성물이 주는 할인 자원.",
			"아래: 비용(자원별 개수).",
			"갖춘 성물은 그 자원을 영원히 하나씩 깎아 줍니다. 성물이 쌓이면 나중에는 토큰 없이도 성물을 삽니다.",
			"판에 펼쳐진 성물은 단계마다 %d장이고, 사면 더미에서 채웁니다." % AcD.ROW_N,
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				var c := Vector2(r.get_center().x + (k - 1) * 160, r.get_center().y - 20)
				_card_at(ci, c, _deck_card(k, [1, 4, 3][k]), 1.3, 0, t)
				_label(ci, c + Vector2(0, 116), AcD.TIER_NAME[k], 22, AcD.TIER_COL[k].lightened(0.4))},
		{head = "봉인", lines = [
			"판의 성물이나 더미 맨 위 성물(안 보고)을 맡아 둡니다. 봉인한 성물은 나만 살 수 있습니다.",
			"봉인하면 별가루를 하나 받습니다(남아 있을 때).",
			"봉인은 %d장까지입니다. 산 성물은 봉인 칸에서 빠집니다." % AcD.RESERVE_MAX,
			"상대가 노리는 성물을 먼저 가로챌 때도 씁니다.",
			"내가 봉인한 성물은 오른쪽 단 봉인 칸에 있습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in AcD.RESERVE_MAX:
				var c := Vector2(r.get_center().x + (k - 1) * 150, r.get_center().y - 30)
				var rc := Rect2(c - CARD * 0.6, CARD * 1.2)
				if k < 2:
					_card_at(ci, c, _deck_card(k + 1, [2, 0][k]), 1.2, 0, t)
				else:
					G2.panel(ci, rc, Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.25), 2.0, 12)
					_label(ci, c, "빈 칸", 22, Color(1, 1, 1, 0.4))
			AcArt.token(ci, Vector2(r.get_center().x, r.end.y - 60), 30, AcD.GOLD)
			_label(ci, Vector2(r.get_center().x + 120, r.end.y - 60), "+1", 30, Color8(255, 226, 150))},
		{head = "영웅", lines = [
			"영웅마다 조건이 있습니다: 어떤 색 성물을 몇 장씩.",
			"내 성물만으로 조건을 채우면 차례 끝에 영웅이 찾아옵니다. 토큰은 내지 않습니다.",
			"영웅은 %d점입니다. 한 차례에 둘 이상 채우면 하나를 고릅니다." % AcD.HERO_PTS,
			"영웅 카드 아래 막대가 내가 얼마나 채웠는지 보여 줍니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				var hs := CARD * 1.3
				var c := Vector2(r.get_center().x + (k - 1) * 160, r.get_center().y)
				AcArt.hero(ci, Rect2(c - hs * 0.5, hs), AcD.HEROES[k], 0, t, [2, 1, 0, 3, 1])},
		{head = "화면 보는 법", lines = [
			"가운데: 성물 판(위가 전설, 아래가 견습). 왼쪽 끝은 더미입니다.",
			"가운데 위: 영웅 전당.",
			"왼쪽: 상대들과 내 수집판. 모은 성물이 색끼리 묶여 쌓입니다.",
			"오른쪽: 자원 은행, 행동 단추, 봉인 칸, 알림.",
			"초록 테 성물은 지금 살 수 있는 것입니다.",
			"이 규칙서는 판 위 [규칙] 단추로 언제든 다시 볼 수 있습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var k := minf(r.size.x / 1280.0, r.size.y / 720.0) * 0.98
			var o := r.get_center() - Vector2(640, 360) * k
			var boxes := [
				[Rect2(14, 72, 292, 204), "상대들", AcD.PLAYER_COL[1]],
				[Rect2(14, 282, 292, 426), "내 수집판", AcD.PLAYER_COL[0]],
				[Rect2(340, 14, 630, 170), "영웅 전당", Color8(240, 200, 100)],
				[Rect2(340, 196, 630, 516), "성물 판", Color(1, 1, 1)],
				[Rect2(996, 60, 270, 160), "자원 은행", AcD.COL[1]],
				[Rect2(996, 222, 270, 150), "행동", Color8(140, 255, 140)],
				[Rect2(996, 380, 270, 140), "봉인", Color8(200, 170, 255)],
				[Rect2(996, 528, 270, 180), "알림", Color(1, 1, 1, 0.6)],
			]
			G2.panel(ci, Rect2(o, Vector2(1280, 720) * k), Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.2), 1.5, 10)
			for b: Array in boxes:
				var br: Rect2 = b[0]
				var rr2 := Rect2(o + br.position * k, br.size * k)
				var col: Color = b[2]
				G2.panel(ci, rr2, Color(col, 0.16), Color(col, 0.8), 2.0, 8)
				G2.text_mid(ci, rr2.get_center(), String(b[1]), 20, Color(1, 1, 1), 4)},
	]
