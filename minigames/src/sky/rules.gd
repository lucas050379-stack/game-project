class_name SaRules
extends RefCounted

## 스카이 어설트 규칙서 쪽들(`UiRules` 에 넘긴다). **규칙 · 키를 바꾸면 여기 글도 같이.**


static func pages() -> Array:
	var col := Color8(90, 220, 255)
	return [
		{head = "목표", lines = [
			"기체 하나를 골라 라운드 여섯을 차례로 지납니다.",
			"라운드 끝에는 보스가 나옵니다. 보스를 쓰러뜨리면 다음 라운드로 갑니다.",
			"여섯 라운드를 모두 지나면 클리어입니다. 남은 기체가 없으면 끝납니다.",
			"점수는 기기에 순위로 남습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float): SaArt.craft(ci, 0, r.get_center(), t, minf(r.size.x, r.size.y) / 90.0)},
		{head = "싸우는 법", lines = [
			"탄은 저절로 나갑니다. 적의 탄을 피하는 데 집중합니다.",
			"보스는 맞은 자리의 부위가 부서집니다. 부위를 부수면 점수가 붙습니다.",
			"스킬은 누르고 있다가 떼면 나갑니다. 기체마다 다릅니다.",
			"봄은 개수가 정해져 있습니다. 급할 때 씁니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float): UiRules.words_pic(ci, r, ["탄은 자동", "보스는 부위별", "스킬과 봄"], col)},
		{head = "조작", lines = [
			"마우스로 끌어도 움직입니다(끈 만큼 그대로 움직입니다).",
			"Shift 를 누르면 천천히 움직여 촘촘한 탄 사이를 지나기 쉽습니다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			UiRules.keys_pic(ci, r, [["W A S D", "이동(방향키도)"], ["Shift", "정밀 이동"], ["R", "스킬(누르고 떼기)"], ["T", "봄"], ["Esc", "그만두기"]])},
	]
