class_name AkRules
extends RefCounted

## 잿빛 요새의 용병단 규칙서 쪽들(`UiRules` 에 넘긴다 — 아르카나 · 제국과 같은 창). 그림은 판과 같은 `AkArt` 함수로 그린다.
## **규칙을 바꾸면 여기 글도 같이** — 화면에 그대로 나가서 규칙만 바뀌면 규칙서가 거짓말을 한다. 말투는 이 게임의 "~한다".


static func _label(ci: CanvasItem, at: Vector2, s: String, size: float = 22.0, col: Color = Color(1, 1, 1, 0.9)) -> void:
	AkArt.text(ci, at, s, size, col, 4)


static func _hero(ci: CanvasItem, c: Vector2, s: float, k: int, t: float) -> void:
	var row: Array = AkD.HEROES[k]
	AkArt.token(ci, c, s, {side = "hero", k = k, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(row[0]), row[3], t)


static func _mon(ci: CanvasItem, c: Vector2, s: float, k: int, t: float) -> void:
	var st := AkD.mon_stats(k, false, 0)
	AkArt.token(ci, c, s, {side = "mon", k = k, elite = false, hp = 1, max = 1, st = {}, s = 0}, String(st.name), st.col, t)


static func pages() -> Array:
	return [
		{head = "목표", lines = [
			"용병 둘을 이끌고 시나리오의 목표를 이룬다: 모두 처치, 보스 처치, 봉인석 부수기, 버티기.",
			"둘 다 쓰러지면 실패다.",
			"깨면 경험을 얻고 다음 시나리오가 열린다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var s := minf(r.size.x, r.size.y) * 0.16
			_hero(ci, r.get_center() + Vector2(-s * 2.2, 0), s, 0, t)
			_hero(ci, r.get_center() + Vector2(-s * 0.4, s * 0.6), s, 1, t)
			_mon(ci, r.get_center() + Vector2(s * 2.0, -s * 0.2), s, 0, t)},
		{head = "카드 두 장", lines = [
			"라운드마다 영웅 하나에 카드 두 장을 고른다.",
			"먼저 고른 카드의 순서 숫자가 그 영웅의 순서다. 숫자가 작을수록 먼저 움직인다.",
			"차례가 오면 한 장은 위 행동, 다른 한 장은 아래 행동으로 쓴다.",
			"어느 쪽을 위로 쓸지는 차례가 왔을 때 정한다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			var w := minf(r.size.x * 0.4, 220.0)
			for k in 2:
				AkArt.card(ci, Rect2(r.get_center().x + (k - 1) * (w + 14) + 7, r.get_center().y - w * 0.36, w, w * 0.72), AkD.card(0, k * 3), 0, false, k)},
		{head = "버림과 잃음, 휴식", lines = [
			"쓴 카드는 버린 더미로 간다. 소멸 표시가 있는 행동을 쓴 카드는 잃은 더미로 간다.",
			"손패가 두 장보다 적으면 쉬어야 한다.",
			"긴 휴식: 한 라운드를 쉬고, 버린 카드 하나를 잃고 나머지를 되찾고, 체력 2를 되찾는다.",
			"손패도 버린 카드도 모자라면 그 영웅은 쓰러진다. 카드가 곧 남은 시간이다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			var names := ["손패", "버림", "잃음"]
			for k in 3:
				var box := Rect2(r.position.x + r.size.x * (0.08 + k * 0.3), r.position.y + r.size.y * 0.3, r.size.x * 0.24, r.size.y * 0.4)
				ci.draw_rect(box, Color(AkArt.STONE.darkened(0.3), 1.0 - k * 0.25))
				_label(ci, box.get_center(), names[k], 24)},
		{head = "이동과 공격", lines = [
			"이동 N: 칸을 N 번까지 옮긴다. 장애물과 적은 지나가지 못한다.",
			"공격 N: 옆 칸의 적에게 피해 N. 사거리가 적힌 공격은 떨어진 적을 친다.",
			"방어는 받는 피해를 줄이고, 반격은 옆에서 친 적에게 되돌려 준다.",
			"빛나는 칸이 지금 고를 수 있는 자리다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var hs := minf(r.size.x, r.size.y) * 0.12
			for k in 5:
				AkArt.cell(ci, r.get_center() + Vector2((k - 2) * hs * sqrt(3.0), 0), hs, "floor", false, k == 2 or k == 3, t)
			_hero(ci, r.get_center() + Vector2(-hs * sqrt(3.0), 0), hs, 2, t)
			_mon(ci, r.get_center() + Vector2(hs * sqrt(3.0) * 2.0, 0), hs, 1, t)},
		{head = "몬스터", lines = [
			"몬스터 종류마다 라운드에 행동 카드 한 장을 뒤집는다. 오른쪽 판에 순서, 이동, 공격이 적힌다.",
			"가장 적게 걸어서 칠 수 있는 영웅을 노린다.",
			"금테 말은 정예다. 체력과 공격이 높다.",
			"문에 올라서면 다음 방이 열리고 그 방의 몬스터가 나타난다.",
		], draw = func(ci: CanvasItem, r: Rect2, t: float):
			var s := minf(r.size.x, r.size.y) * 0.15
			for k in 3:
				_mon(ci, r.get_center() + Vector2((k - 1) * s * 2.4, 0), s, [0, 1, 4][k], t)},
		{head = "원소와 상태", lines = [
			"불, 땅, 빛, 어둠 네 원소가 있다. 원소를 불어넣는 행동을 쓰면 그 원소가 찬다.",
			"찬 원소는 다음 차례부터 쓸 수 있고, 라운드가 끝날 때마다 약해진다.",
			"원소를 쓰는 행동은 그 원소가 있을 때 더 세다.",
			"독에 걸리면 맞을 때마다 피해를 1 더 받는다. 치유를 받으면 풀린다. 기절은 한 차례를 쉬게 한다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			for e in 4:
				AkArt.elem(ci, r.get_center() + Vector2((e - 1.5) * r.size.x * 0.2, 0), minf(r.size.x * 0.08, 44.0), e, 2 if e < 2 else (1 if e == 2 else 0))},
		{head = "화면 보는 법", lines = [
			"왼쪽이 내 영웅 둘이다. 체력, 손패와 버림과 잃음의 수, 이번 라운드에 고른 카드가 보인다.",
			"가운데가 던전, 아래가 지금 영웅의 손패다.",
			"오른쪽에 시나리오 목표, 원소, 몬스터가 이번 라운드에 할 일이 적힌다.",
			"왼쪽 위 나가기 옆의 규칙 단추로 언제든 이 책을 다시 연다.",
		], draw = func(ci: CanvasItem, r: Rect2, _t: float):
			for k in 3:
				var box := Rect2(r.position.x + r.size.x * (0.06 + k * 0.31), r.position.y + r.size.y * 0.25, r.size.x * 0.26, r.size.y * 0.5)
				ci.draw_rect(box, AkArt.STONE.darkened(0.45))
				_label(ci, box.get_center(), ["영웅", "던전", "몬스터"][k], 24)},
	]
