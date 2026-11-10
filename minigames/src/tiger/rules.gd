class_name TgRules
extends RefCounted

## 떡 하나 주면 안 잡아먹지 규칙서 쪽들(`UiRules` 에 넘긴다). 숫자는 `TgD` 의 것 — **규칙을 바꾸면 여기 글도 같이.** 말투는 해요체.


static func pages() -> Array:
	return [
		{head = "어떻게 하나요", lines = [
			"호랑이는 저절로 달려요. 장애물을 넘고 떡을 주워 먹어요.",
			"배가 조금씩 고파져요. 떡을 먹으면 배가 차요.",
			"위쪽 막대가 다 줄면 주저앉아 실패예요.",
			"결승선까지 가면 그 라운드를 깨요. 라운드는 열 개예요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			TgArt.fox(ci, r.get_center() + Vector2(-60, 50), t * 1.6, "run", false, false, t)
			for k in 3:
				TgArt.candy(ci, r.get_center() + Vector2(60 + k * 44, 10), t)},
		{head = "장애물", lines = [
			"바위와 그루터기는 점프로 넘어요.",
			"늘어진 소나무 가지와 곶감 줄은 숙여서 지나가요. 점프로는 못 넘어요.",
			"함정 구덩이는 점프로 건너요.",
			"높은 장승은 한 번 뛰어서는 못 넘어요. 뛰어오른 꼭대기에서 한 번 더 뛰어요.",
			"부딪히면 배가 %d 줄고 잠깐 느려져요. 구덩이는 %d 줄어요." % [int(TgD.OIL_HIT), int(TgD.OIL_PIT)],
			"떡은 완벽하게 달리면 전부 먹을 수 있게 놓여 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var gy := r.get_center().y + 70
			TgArt.obstacle(ci, {kind = "low", x = 0, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, v = 0}, r.get_center().x - 110, gy, 0, t)
			TgArt.obstacle(ci, {kind = "high", x = 0, y = TgD.HIGH_Y, w = 30.0, h = 140.0, v = 1}, r.get_center().x + 90, gy, 0, t)},
		{head = "호랑이 기운과 별", lines = [
			"떡을 모으면 호랑이 기운이 차요(빠른 길일수록 더 많이 먹어야 해요). 질주 중에 먹은 떡은 안 세요.",
			"쓰면 %d초 동안 빨라지고, 장애물을 부수며 지나가고, 가까운 떡이 끌려와요." % int(TgD.DASH_T),
			"갈랫길: 뛰어서 나무 다리(윗길)에 오르면 엽전과 보따리, 아랫길은 떡이 있지만 숙여서 지나야 해요.",
			"별 하나: 완주. 별 둘: 떡을 70% 넘게 먹기. 별 셋: 한 번도 안 부딪히기.",
			"앞 라운드를 완주해야 다음 라운드가 열려요.",
			"밤 라운드(13~16)에서는 곶감 귀신이 쫓아와요. 부딪힐 때마다 가까워지고, 따라잡히면 물려서 배가 %d 줄어요." % int(TgD.OIL_BITE),
			"안 부딪히고 달리면 멀어지고, 호랑이 기운을 쓰면 확 떨어뜨려요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			TgArt.fox(ci, r.get_center() + Vector2(0, 50), t * 2.0, "run", true, false, t)},
		{head = "길 위의 물건", lines = [
			"꿀단지: %d초 동안 둘레의 떡이 끌려와요." % int(TgD.MAGNET_T),
			"산삼: %d초 동안 몸이 커져요. 장애물을 부수고 구덩이에도 안 빠져요." % int(TgD.GIANT_T),
			"도깨비 방망이: 화면의 장애물이 전부 떡으로 바뀌고, 화면의 떡이 한꺼번에 날아와요.",
			"동아줄: 하늘로 올라가 떡 물결을 따라 날아요. 점프 키를 누르고 있으면 오르고 떼면 내려가요.",
			"꿀떡 꼬치: 점프 꼭대기에서 닿아요. 배가 많이 차요.",
			"엽전과 보따리: 엽전을 모아 라운드 고르기 화면의 가게에서 호랑이를 강화해요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var ks := ["honey", "sansam", "club", "rope"]
			for k in 4:
				TgArt.item(ci, ks[k], r.get_center() + Vector2((k - 1.5) * 90.0, 30 if k < 3 else 60), t)},
		{head = "조작", lines = [
			"점프는 공중에서 한 번 더 할 수 있어요.",
			"마우스로도 돼요. 화면 왼쪽 절반을 누르면 점프, 오른쪽 절반을 누르고 있으면 숙이기예요.",
			"키는 처음 화면의 키 설정에서 바꿀 수 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["Space", "점프(W, 위 방향키도)"], ["S", "숙이기(아래 방향키, Shift 도)"], ["Enter", "호랑이 기운(E 도)"], ["Esc", "그만두기"]])},
	]
