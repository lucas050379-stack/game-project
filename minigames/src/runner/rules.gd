class_name WrRules
extends RefCounted

## 월드 러너 규칙서 쪽들(`UiRules` 에 넘긴다). 숫자는 `WrD` 의 것 — **규칙을 바꾸면 여기 글도 같이.**


static func pages() -> Array:
	var col := Color8(140, 255, 170)
	return [
		{head = "목표", lines = [
			"넷이 주사위를 굴려 세계 도시 판을 돕니다. 사람은 나 하나, 나머지 셋은 컴퓨터입니다.",
			"땅을 사고 건물을 지어 통행료를 받습니다.",
			"돈을 못 내는 사람은 파산합니다. 마지막까지 남으면 이깁니다.",
			"40라운드가 지나도 끝나지 않으면 총자산이 가장 많은 사람이 이깁니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["땅 사기", "통행료 받기", "상대 파산"], col)},
		{head = "차례에 하는 일", lines = [
			"주사위를 굴려 나온 만큼 갑니다.",
			"빈 땅에 서면 살 수 있습니다. 내 땅에 서면 건물을 올립니다(토지, 별장, 빌딩, 호텔, 랜드마크).",
			"남의 땅에 서면 통행료를 냅니다. 값의 두 배를 내고 그 도시를 인수할 수도 있습니다.",
			"돈이 모자라면 내 땅을 절반 값에 팔아 메웁니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["굴리기", "사기 또는 짓기", "통행료 또는 인수"], col)},
		{head = "알아 둘 것", lines = [
			"출발 칸을 지나면 급여를 받습니다. 정확히 서면 두 배입니다.",
			"한 대륙을 독점하면 그 대륙 통행료가 두 배입니다.",
			"판을 시작할 때 무작위 두 칸은 통행료가 두 배입니다.",
			"무인도에 서면 세 턴을 쉽니다. 국세청은 가진 돈의 10%를 걷습니다.",
			"황금열쇠 칸에서는 카드 한 장을 뽑아 그대로 따릅니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["독점 두 배", "무인도 세 턴", "황금열쇠"], col)},
		{head = "조작", lines = [
			"전부 마우스로 누릅니다.",
			"오른쪽 위 속도 단추로 진행 빠르기를 바꿉니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["마우스", "굴리기, 사기, 짓기"], ["Esc", "그만두기"]])},
	]
