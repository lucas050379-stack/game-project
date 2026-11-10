class_name JellyRules
extends RefCounted

## 젤리팝 규칙서 쪽들(`UiRules` 에 넘긴다). **규칙을 바꾸면 여기 글도 같이.** 말투는 해요체.


static func pages() -> Array:
	var col := Color8(255, 120, 180)
	return [
		{head = "어떻게 하나요", lines = [
			"옆에 붙은 젤리 둘의 자리를 바꿔요.",
			"같은 젤리 셋 이상이 한 줄이 되면 터지고, 위에서 새 젤리가 내려와요.",
			"줄이 안 만들어지는 자리 바꾸기는 되돌아가요.",
			"둘 수가 없으면 판이 저절로 섞여요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				Art.jelly(ci, r.get_center() + Vector2((k - 1) * r.size.y * 0.3, 0), r.size.y * 0.13, 1, D.SP_NONE, Art.Face.HAPPY, Vector2.ZERO, false, Vector2.ONE, 0.0, 0.0, t + k)},
		{head = "이기는 조건", lines = [
			"모험: 이동 횟수 안에 왼쪽의 미션을 다 채우면 깨요. 장애물을 없애거나 정해진 젤리를 모아요.",
			"이동을 다 쓰도록 미션이 남으면 실패예요.",
			"점수가 높고 이동을 많이 남길수록 별을 많이 받아요. 별은 셋까지예요.",
			"타임 어택: 60초 동안 점수를 최대한 올려요. 순위에 올라가요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["미션 채우기", "이동 횟수 안에", "별 셋까지"], col)},
		{head = "특수 젤리", lines = [
			"넷을 한 줄로 맞추면 줄 폭탄이 생겨요. 터지면 한 줄을 다 지워요.",
			"ㄴ 자나 ㅜ 자로 맞추면 둘레를 터뜨리는 폭탄이 생겨요.",
			"다섯을 한 줄로 맞추면 무지개가 생겨요. 바꾼 젤리와 같은 색을 모두 지워요.",
			"특수 젤리 둘을 서로 바꾸면 더 크게 터져요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["넷 = 줄 폭탄", "ㄴ ㅜ = 폭탄", "다섯 = 무지개"], col)},
		{head = "장애물과 몬스터", lines = [
			"다섯 판마다 새 장애물이 하나씩 나와요. 처음 나올 때 설명이 떠요.",
			"판 위쪽의 장애물 단추나 처음 화면의 장애물 도감에서 다시 볼 수 있어요.",
			"몬스터는 다음에 노릴 칸을 한 턴 먼저 붉게 보여 줘요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["다섯 판마다 하나", "붉은 칸 = 다음 공격"], col)},
		{head = "조작", lines = [
			"젤리를 누른 채 옆으로 끌거나, 젤리를 누르고 옆 젤리를 눌러요.",
			"처음 화면에서는 방향키와 Enter, 숫자 키로도 고를 수 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["마우스 끌기", "젤리 바꾸기"], ["Esc", "뒤로, 창 닫기"], ["Enter", "고르기"]])},
	]
