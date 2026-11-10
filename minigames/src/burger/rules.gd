class_name BgRules
extends RefCounted

## 버거왕 규칙서 쪽들(`UiRules` 에 넘긴다). 숫자는 `BgD` 의 것 — **규칙을 바꾸면 여기 글도 같이.** 말투는 해요체.


static func pages() -> Array:
	return [
		{head = "어떻게 하나요", lines = [
			"손님이 오면 말풍선에 주문한 버거가 보여요.",
			"아래 왼쪽의 재료 통(빵, 패티, 치즈, 야채, 토핑, 소스)에 마우스를 올리면 그 안의 재료가 오른쪽에 펼쳐져요.",
			"손님에게 마우스를 올리면 주문이 크게 보이고 재료 이름이 나와요.",
			"펼쳐진 재료를 눌러 조립대에 차곡차곡 쌓아요. 순서까지 같아야 해요.",
			"빵부터 놓고, 다 쌓았으면 같은 빵으로 덮어요.",
			"다 만든 버거는 손님을 누르거나 Space 로 내요. 맞으면 돈을 받아요.",
			"하루 영업은 %d분이에요. 날은 서른 날까지 있어요." % int(BgD.DAY_T / 60.0),
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			BgArt.stack(ci, ["bun_sesame", "pt_beef", "ch_cheddar", "vg_lettuce", "vg_tomato", "bun_sesame"], r.get_center() + Vector2(0, 80), 150.0)},
		{head = "손님과 돈", lines = [
			"손님마다 참을성 막대가 있어요. 다 줄면 화를 내며 가 버려요.",
			"빨리 낼수록 팁이 많아요. 연달아 맞히면 팁이 더 붙어요.",
			"틀린 버거를 내면 참을성이 크게 깎이고 버거는 버려져요.",
			"잘못 얹었으면 쓰레기통(Backspace)으로 맨 위 재료를 버려요. 재료값의 절반이 들어요.",
			"별 하나: 목표 금액. 별 둘: 놓친 손님 없이. 별 셋: 틀린 버거와 탄 패티 없이.",
			"별 하나를 받아야 다음 날이 열려요. 번 돈은 별과 상관없이 내 돈이 돼요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				BgArt.customer(ci, k, k, r.get_center() + Vector2((k - 1) * 150.0, 100), 130.0, t)},
		{head = "패티 굽기", lines = [
			"넷째 날부터는 패티를 구워야 해요. 패티를 누르면 철판에 올라가요.",
			"%d초쯤 지나 막대가 초록 구간에 오면 눌러서 버거에 얹어요." % int(BgD.COOK_T),
			"덜 익은 패티는 집을 수 없어요. 초록 구간을 지나면 타 버려요.",
			"탄 패티는 눌러서 버려요. 패티 값이 들고 별 셋을 놓쳐요.",
			"패티는 버거를 쌓기 전에 미리 올려 두어도 돼요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.words_pic(ci, r, ["덜 익음", "알맞음", "탐"], BgArt.MUSTARD)},
		{head = "날이 갈수록 생기는 일", lines = [
			"6일째부터 야채는 여섯 번 얹으면 떨어져요. 빈 칸을 눌러 썰어 채워요. 오른쪽 단추로 미리 썰어 둘 수도 있어요.",
			"8일째부터 소스 두 줄 주문이 와요. 같은 소스를 두 번 누르면 듬뿍이에요.",
			"10일째부터 패티는 한쪽이 익으면 눌러서 뒤집고, 반대쪽까지 익혀서 집어요.",
			"16일째부터 녹인 치즈 주문이 와요(김이 나는 치즈). 치즈를 오른쪽 단추로 누르면 철판의 패티 위에 얹혀요.",
			"치즈가 다 녹은 뒤에 패티를 집으면 치즈가 같이 와요.",
			"22일째부터 포장 손님이 와요(말풍선에 봉투). 다 만든 버거를 조립대 왼쪽의 포장지로 싸서 내요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			BgArt.stack(ci, ["bun_sesame", "pt_beef", "ch_cheddar~", "sc_ketchup+", "vg_lettuce", "bun_sesame"], r.get_center() + Vector2(0, 86), 150.0)},
		{head = "가게 꾸리기", lines = [
			"번 돈으로 새 재료를 열어요. 비싼 재료가 든 버거는 값도 비싸요.",
			"철판을 넓히거나 보온 철판, 굽기 보조를 들이면 굽기가 쉬워져요.",
			"음료 기계와 감자튀김기를 사면 13일째부터 음료와 감자튀김 주문이 같이 와요.",
			"자리를 늘리면 손님이 한 명 더 서요. 가게를 꾸미면 손님이 더 오래 기다려요.",
			"19일째부터는 특별 손님이 와요. 꼬마는 급하고, 미식가는 패티가 딱 알맞으면 팁이 세 배예요.",
			"단체는 같은 버거를 세 개 받아 가고, 배달은 크고 비싼 버거를 느긋하게 기다려요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			var ids := ["bun_brioche", "pt_chicken", "tp_bacon", "vg_avocado", "ch_swiss"]
			for k in ids.size():
				BgArt.icon(ci, ids[k], Rect2(r.get_center().x - 250 + k * 100.0, r.get_center().y + 20, 100, 70))},
		{head = "음료와 감자튀김", lines = [
			"음료는 콜라, 퐌타, 사이다, 오렌지주스 네 가지예요. 주문과 같은 꼭지를 누르고 있으면 컵이 차요.",
			"흰 선을 넘기고 떼면 쟁반에 올라가요. 빨간 데까지 따르면 넘쳐서 다시 따라야 해요.",
			"감자튀김은 튀김기를 눌러 바구니를 넣고, 막대가 초록일 때 다시 눌러 건져요. 늦으면 타요.",
			"건진 감자튀김에는 주문에 그려진 가루 양념 통을 눌러 뿌려요. 소금, 치즈, 어니언, 매운 가루, 허니버터가 있어요.",
			"잘못 담았으면 쟁반의 음료나 감자튀김을 눌러 버려요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			var ids := ["bg_dr_cola", "bg_dr_fanta", "bg_dr_cider", "bg_dr_oj", "bg_fries"]
			for k in ids.size():
				BgArt.fit(ci, BgArt.img(ids[k]), Rect2(r.get_center().x - 250 + k * 100.0, r.get_center().y + 10, 90, 100))},
		{head = "조작", lines = [
			"마우스로 다 할 수 있어요. 재료, 철판, 쓰레기통, 손님을 눌러요.",
			"재료 통은 A S D F G H 로 열고, 펼쳐진 재료는 숫자키로 집어요.",
			"키는 처음 화면의 키 설정에서 바꿀 수 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["Space", "버거 내기"], ["Backspace", "맨 위 재료 버리기"], ["Q W E R", "철판 칸의 패티 집기"], ["Z X C V", "음료 따르기(누르고 있기)"], ["T", "튀김기"], ["P", "포장하기"], ["Shift + 숫자", "치즈 녹이기, 야채 미리 썰기"], ["A S D F G H", "재료 통 열기"], ["1 ~ 9", "펼쳐진 재료 집기"], ["Esc", "그만두기"]])},
	]
