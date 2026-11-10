class_name GhRules
extends RefCounted

## 강호일생 규칙서 쪽들(`UiRules` 에 넘긴다). **규칙을 바꾸면 여기 글도 같이.** 말투는 이 게임의 "~다".


static func pages() -> Array:
	var col := Color8(150, 36, 30)
	return [
		{head = "어떤 게임인가", lines = [
			"무협 세상에 한 사람으로 태어나 일생을 산다.",
			"태어날 시대와 땅, 집안, 타고난 것은 고를 수 없다.",
			"세월은 한 해씩 저절로 흐르고, 일어난 일이 가운데에 적힌다.",
			"이기고 지는 것은 없다. 어떻게 살았는지가 남는다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["태어남은 운", "한 해씩 흐름", "일생이 남는다"], col)},
		{head = "내가 하는 일", lines = [
			"갈림길: 가끔 선택지가 뜬다. 무리한 길은 얻는 것이 크지만 실패할 수 있고, 안전한 길이 하나는 있다.",
			"방침: 삶의 방침을 고른다. 어떤 일이 더 자주 일어날지를 기울인다.",
			"할 일과 인연: 하는 일과 가까운 사람이 앞날의 확률을 바꾼다.",
			"선택은 결과를 정하지 않는다. 확률을 기울일 뿐이다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["갈림길", "방침", "할 일과 인연"], col)},
		{head = "무엇이 남는가", lines = [
			"일생이 끝나면 살아온 길이 지난 인생에 남는다.",
			"이룬 것에 따라 칭호를 얻는다. 칭호 도감에 모인다.",
			"이름을 크게 떨친 일생은 순위에 오른다.",
			"천하 사람 대부분은 무공을 모르고 산다. 강호에 닿는 일생은 드물다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["지난 인생", "칭호", "순위"], col)},
		{head = "조작", lines = [
			"전부 마우스로 누른다.",
			"위쪽 단추로 세월의 빠르기를 바꾸거나 멈춘다.",
			"자동 선택을 켜면 갈림길을 알아서 고르고, 건너뛰기는 일생을 끝까지 빨리 돌린다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["마우스", "선택, 방침"], ["x1 x2 x4 x8", "빠르기"], ["Esc", "나가기"]])},
	]
