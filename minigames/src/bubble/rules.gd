class_name BbRules
extends RefCounted

## 물거품처럼 사라져줘 규칙서 쪽들(`UiRules` 에 넘긴다). 숫자는 `BbD` 의 것 — **규칙을 바꾸면 여기 글도 같이.** 말투는 해요체.


static func pages() -> Array:
	return [
		{head = "어떻게 하나요", lines = [
			"꼬마 인어가 거품을 쏴 바다 악당을 가둬요.",
			"악당이 든 거품에 몸으로 부딪히면 톡 터지며 악당이 사라져요.",
			"판의 악당을 다 없애면 다음 판으로 내려가요. 모두 %d판, 10판마다 보스가 나와요." % BbD.LEVELS,
			"목숨은 %d개예요. 악당이나 상어에 닿으면 하나 잃어요." % BbD.LIVES,
			"목숨을 다 쓰면 이어 하기를 %d번 할 수 있어요. 점수는 0부터, 판은 그 판부터예요." % BbD.CONTINUES,
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			BbArt.mermaid(ci, 0, r.get_center() + Vector2(-90, 60), 1, "shot", t)
			BbArt.bubble(ci, r.get_center() + Vector2(40, 20), BbD.BUB_R * 1.4, 0, 0.0, t)},
		{head = "거품", lines = [
			"거품은 앞으로 짧게 뻗어 나가다 멈추고 천천히 위로 떠올라요.",
			"갇힌 악당은 %d초쯤 지나면 거품이 빨개지고, 조금 더 지나면 화난 채로 깨고 나와요." % int(BbD.TRAP_RED),
			"서로 닿은 거품은 하나를 터뜨리면 줄줄이 같이 터져요. 한 번에 여럿이면 점수가 두 배씩 커지고 귀한 물건이 떨어져요.",
			"점프 키를 누른 채 거품 위에 내려앉으면 통 튀어 올라요. 높은 층으로 가는 길이에요.",
			"바닥 가운데 구멍으로 떨어지면 맨 위에서 나와요. 갇힌 거품도 천장 구멍으로 빠지면 바닥에서 다시 떠올라요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				BbArt.bubble(ci, r.get_center() + Vector2(-60 + k * 48, -10 + (k % 2) * 20), BbD.BUB_R * 1.2, k, 0.0, t + k)},
		{head = "악당과 서둘러", lines = [
			"복어, 꽃게는 걸어 다니고 위층에 사람이 있으면 뛰어올라요. 해파리는 떠다니며 벽에 튕겨요.",
			"문어는 같은 층에 있으면 먹물을 쏴요. 맞으면 %d초 동안 앞이 잘 안 보여요. 성게가 가시를 세우면 거품이 터져 버려요. 가시를 눕혔을 때 쏘세요." % int(BbD.INK_BLIND),
			"판이 시작하면 악당이 위에서 내려와 자리 잡아요. %d초가 지나면 서둘러요! 악당이 모두 화나 빨라져요. %d초가 지나면 거품으로 못 가두는 상어가 쫓아와요." % [int(BbD.HURRY_T), int(BbD.SHARK_T)],
			"보스는 거품을 여러 번 맞혀 가두고, 몸으로 부딪혀 크게 터뜨려요. 물거품처럼 사라져줘!",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 5:
				BbArt.enemy(ci, k, r.get_center() + Vector2(-140 + k * 70, 60), -1, false, t)},
		{head = "물건과 글자", lines = [
			"악당이 사라진 자리에 진주, 사탕, 젤리, 보석이 떨어져요. 금방 사라지니 빨리 주워요.",
			"힘 물건: 큰 거품, 연사, 빠른 지느러미(%d초), 무지개 거품(한 번 쏘면 화면을 가로질러 닿는 악당을 모두 가둬요)." % int(BbD.POWER_T),
			"이따금 바닥에서 글자 거품이 떠올라요. 물, 거, 품, 처, 럼 다섯 글자를 모으면 목숨이 하나 늘어요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 5:
				BbArt.bubble(ci, r.get_center() + Vector2(-140 + k * 70, 0), BbD.BUB_R * 1.2, -1, 0.0, t, k)},
		{head = "조작", lines = [
			"혼자: 방향키 또는 A D 로 움직이고, W, 위, Z 로 점프, F, X 로 거품을 쏴요.",
			"둘이: 1P 는 A D 움직이기, W 점프, F 거품. 2P 는 방향키, 위 점프, Enter 거품.",
			"키는 처음 화면의 1P 키, 2P 키에서 바꿀 수 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["A D", "1P 움직이기"], ["W", "1P 점프"], ["F", "1P 거품"], ["방향키", "2P 움직이기, 위 점프"], ["Enter", "2P 거품"], ["Esc", "멈추기"]])},
	]
