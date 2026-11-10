class_name TgRules
extends RefCounted

## 떡 하나 주면 안 잡아먹지 규칙서 쪽들(`UiRules` 에 넘긴다). 숫자는 `TgD` 의 것 — **규칙을 바꾸면 여기 글도 같이.** 말투는 해요체.
## 11-10 이어 달리기로 바뀌었다(라운드 · 별 · 결승선이 없다 — 기획서 "이어 달리기 개편").


static func pages() -> Array:
	return [
		{head = "어떻게 하나요", lines = [
			"호랑이는 저절로 달려요. 장애물을 넘고 떡을 주워 먹어요.",
			"고갯마루에서 해와 달까지 구간 %d개를 한 번에 이어 달려요. 뒤로 갈수록 빨라지고 배가 빨리 꺼져요." % TgD.ZONES.size(),
			"배가 조금씩 고파져요. 위쪽 막대가 다 줄면 주저앉아 끝나요.",
			"얼마나 멀리 갔는지와 점수가 기록으로 남아요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			TgArt.fox(ci, r.get_center() + Vector2(-60, 50), t * 1.6, "run", false, false, t)
			for k in 3:
				TgArt.candy(ci, r.get_center() + Vector2(60 + k * 44, 10 - k * 30), t)},
		{head = "배 채우기", lines = [
			"떡은 점수예요. 배는 아주 조금만 차요.",
			"무지개로 빛나는 큰 무지개떡은 떡의 열 배 점수예요. 장애물을 넘는 점프 꼭대기에 있어요.",
			"배를 채우는 건 꿀떡 꼬치예요. 하나에 배가 %d 차요." % int(TgD.OIL_LANTERN),
			"꼬치는 일정한 거리마다 하나씩, 높은 곳에 있어요. 뛰어야 먹어요.",
			"꼬치를 놓치면 배가 금방 바닥나요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			TgArt.lollipop(ci, r.get_center() + Vector2(-60, -40), t)
			TgArt.big_tteok(ci, r.get_center() + Vector2(70, -40), t)
			TgArt.fox(ci, r.get_center() + Vector2(0, 90), t * 2.0, "jump", false, false, t)},
		{head = "장애물", lines = [
			"바위와 그루터기는 점프로 넘어요. 함정 구덩이도 점프로 건너요.",
			"늘어진 소나무 가지, 곶감 줄, 천장에서 내려오는 절굿공이는 숙여서 지나가요.",
			"높은 장승은 뛰어오른 꼭대기에서 한 번 더 뛰어야 넘어요.",
			"날아오는 곶감은 낮게 오면 뛰어 넘고, 머리 높이로 오면 숙여요.",
			"가시밭은 가시가 촘촘해요. 착지하자마자 또 뛰며 건너요.",
			"낭떠러지는 셋이에요. 좁으면 한 번, 넓으면 두 번 뛰어요.",
			"넓은데 위에 낮은 천장이 있으면, 한 번 뛰고 천장을 지날 때까지 기다렸다가 두 번째로 뛰어요.",
			"낭떠러지 위 흔들리는 발판은 올라서면 곧 꺼져요. 바로 다음 발판으로 뛰어요.",
			"바위가 하늘에서 떨어지거나 굴러 오기도 해요. 떨어진 자리에서 넘어요.",
			"떠 있는 밤송이는 낮으면 뛰어 넘고, 머리 위에 있으면 뛰지 말고 밑으로 지나가요.",
			"흔들리는 도끼는 숙여서, 굴러오는 맷돌은 두 번 뛰어서, 벼락은 표시된 자리에서 뛰어서 피해요.",
			"부딪히면 배가 %d 줄고 잠깐 느려져요. 구덩이 · 낭떠러지는 바닥까지 떨어지면 %d 줄고, 저절로 튀어 올라 건너가요." % [int(TgD.OIL_HIT), int(TgD.OIL_PIT)],
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var gy := r.get_center().y + 70
			TgArt.obstacle(ci, {kind = "low", x = 0, y = 0.0, w = TgD.LOW_W, h = TgD.LOW_H, v = 0}, r.get_center().x - 150, gy, 0, t)
			TgArt.obstacle(ci, {kind = "low", x = 0, y = 0.0, w = TgD.SPIKE_W, h = TgD.SPIKE_H, v = 2}, r.get_center().x - 60, gy, 0, t)
			TgArt.obstacle(ci, {kind = "flyer", x = 0, y = TgD.FLYER_HIGH, w = TgD.FLYER_R * 2.0, h = TgD.FLYER_R * 2.0, v = 1}, r.get_center().x + 30, gy, 0, t)
			TgArt.obstacle(ci, {kind = "high", x = 0, y = TgD.HIGH_Y, w = 30.0, h = 140.0, v = 1}, r.get_center().x + 130, gy, 0, t)},
		{head = "발판과 갈림길", lines = [
			"높이가 다른 나무 발판이 계단처럼 이어지는 곳이 있어요.",
			"뛰어서 발판에 오르고, 끝에서 뛰어 다음 발판으로 건너요.",
			"가장 높은 발판에는 엽전과 보따리가 있어요. 아래 땅에는 가시가 있기도 해요.",
			"떡 줄도 대부분 점프나 2단 점프 높이에 떠 있어요.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			for k in 3:
				ci.draw_rect(Rect2(r.position.x + 40 + k * 130, r.get_center().y + 60 - k * 50, 110, 14), Color8(150, 100, 60))
			TgArt.fox(ci, r.get_center() + Vector2(-120, 60), t * 2.0, "jump", false, false, t)},
		{head = "호랑이 기운과 겹치기", lines = [
			"떡을 모으면 호랑이 기운이 차요. 질주 중에 먹은 떡은 안 세요.",
			"쓰면 %d초 동안 빨라지고, 장애물을 부수며 지나가고, 가까운 떡이 끌려와요." % int(TgD.DASH_T),
			"호랑이 기운, 산삼, 꿀단지 중 둘이 동시에 켜져 있으면 점수가 두 배, 셋이면 세 배예요.",
			"호랑이 기운은 언제 쓸지 고를 수 있어요. 산삼이나 꿀단지를 먹을 때 맞춰 써 보세요.",
			"밤 구간(13~16)에서는 곶감 귀신이 쫓아와요. 부딪힐 때마다 가까워지고, 따라잡히면 물려서 배가 %d 줄어요." % int(TgD.OIL_BITE),
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			TgArt.fox(ci, r.get_center() + Vector2(0, 50), t * 2.0, "run", true, false, t)},
		{head = "길 위의 물건", lines = [
			"꿀단지: %d초 동안 둘레의 떡이 끌려와요." % int(TgD.MAGNET_T),
			"산삼: %d초 동안 몸이 커져요. 장애물을 부수고 구덩이에도 안 빠져요." % int(TgD.GIANT_T),
			"도깨비 방망이: 화면의 장애물이 전부 떡으로 바뀌고, 화면의 떡이 한꺼번에 날아와요.",
			"동아줄: 하늘로 올라가 떡 물결을 따라 날아요. 점프 키를 누르고 있으면 오르고 떼면 내려가요.",
			"물건은 점프 높이에 떠 있어요. 엽전을 모아 준비 화면의 가게에서 호랑이를 강화해요.",
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
