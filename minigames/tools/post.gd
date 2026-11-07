extends SceneTree

## AI 로 뽑은 후보 한 장을 게임이 읽는 형식으로 바꿔 `art/<게임>/<이름>.png` 로 쓴다(`_game_dir`).
##   post.bat <원본> <이름> <key|obj|mon|noface|over|tile|fx|plain|sprite [크기]>   (obj · mon = key, over = cut)
##
## key   — 단색 배경을 지운다. 네 모서리 색을 배경색으로 잡고 **가장자리에서부터만** 지운다
##         (flood fill). 화면 전체에서 그 색을 지우면 몸통 안의 비슷한 색까지 구멍이 난다.
##         그다음 내용 경계로 잘라 정사각형에 앉힌다 — 여백이 한쪽에 남으면 그릴 때 몸이
##         한쪽으로 밀린다.
## fx    — 검은 바탕의 빛 그림. 밝기를 알파로 옮기고 색은 흰색으로 둔다. 색은 게임이 입힌다.
## cut   — 젤리 위에 겹치는 그림(사슬 · 거미줄 · 얼음 테). 배경색을 **화면 전체에서** 지운다.
##         key 처럼 가장자리에서만 지우면 사슬 고리 안 · 거미줄 칸 사이처럼 갇힌 배경이 남는다.
##         그래서 바탕은 그림에 없는 색(마젠타 · 초록)이어야 한다. 조각이 여럿일 수 있어 큰 덩어리만
##         남기지 않고, 칸 전체를 덮어야 하므로 바닥이 아니라 가운데에 앉힌다.
## plain — 크기만 맞춘다(배경).

const LO := 0.24   ## 배경색과 이만큼 가까우면 완전 투명 (그림자처럼 조금 어두운 배경색까지 지운다)
const HI := 0.48   ## 이만큼 멀면 완전 불투명. 사이는 반투명(가장자리 부드럽게)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		print("usage: post.bat <source> <name> <key|fx|plain>")
		quit(1)
		return
	var img := Image.load_from_file(a[0])
	if img == null or img.is_empty():
		print("cannot read ", a[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	match a[2]:
		"cut", "over":
			img = _key(img, false)
			img = _square(img, 256)
		"key", "obj", "mon":
			img = _key(img)
			img = _square(img, 256, true)
		"sprite":
			# 스카이 어설트 기체 · 보스 — 단색 배경을 가장자리에서부터 지우고 **가운데**에 앉힌다
			# (블록과 달리 바닥에 붙이지 않는다). 크기는 넷째 인자(보스는 512 — 화면에서 크게 그려진다).
			img = _key(img)
			img = _square(img, int(a[3]) if a.size() > 3 else 256)
		"sprite_shadow":
			# 지상 적 — 그림자에 마젠타 배경이 섞여 **분홍 얼룩**이 남는다(분홍은 적 탄의 색이라 헷갈린다).
			# 배경을 지운 뒤 분홍빛 픽셀만 무채색 그림자로 바꾼다. 보라색 기체(커세어)에는 쓰지 말 것.
			img = _key(img)
			_unpink(img)
			img = _square(img, int(a[3]) if a.size() > 3 else 256)
		"sprite_unshadow":
			# AI 가 "그림자 없이" 를 안 지키고 기체 밑에 그림자를 깔아 온다 — 배경색이 비친 그림자라
			# 기체 옆에 **잔상**처럼 보였다(커세어: 초록 배경 → 연두 그림자). 배경과 색상(hue)이 같은 픽셀을 지운다.
			# 기체 색이 배경 색상과 가까우면 기체까지 먹으니 쓰기 전에 배경색이 기체에 없는지 보세요.
			# 다섯째 인자로 그림자 색상(hue 0~1)을 직접 줄 수 있다 — 중간보스 그림자는 배경색이 아니라 갈색이었다(0.085).
			var bg := _corner_color(img)
			img = _key(img)
			if a.size() > 4 and float(a[4]) >= 0.0:
				_unshadow(img, Color.from_hsv(float(a[4]), 1.0, 1.0), 0.05, 0.15)
			else:
				_unshadow(img, bg)
			# 여섯째 인자 mirror — 왼쪽 반을 오른쪽으로 접어 붙인다(좌우 대칭 기체). 중간보스 오른쪽 날개에 떨어져 나온
			# 덮개 조각이 그려져 와서 오른쪽 엔진이 가려졌다. 축은 기수(맨 위 줄) 가운데로 잡는다.
			if a.size() > 5 and a[5] == "mirror":
				_mirror_left(img)
			var used := img.get_used_rect()
			if used.has_area():
				img = img.get_region(used)
			img = _square(img, int(a[3]) if a.size() > 3 else 256)
		"noface":
			# 몬스터 — AI 가 "얼굴 없이" 를 안 지키고 눈 · 볼터치를 그려 온다. 지우고 코드가 얼굴을 얹는다
			var base := float(a[3]) if a.size() > 3 else 0.16
			img = _key(img)
			img = _square(img, 256, true)
			# 뚜렷한 것(눈 · 입)부터 지우고 희미한 것(볼터치)은 다음 판에서. 처음부터 기준을 낮추면 눈 · 볼 ·
			# 둘레 명암이 한 덩어리로 묶여 "작은 얼룩" 조건을 넘어서 오히려 하나도 안 지워진다(대왕꾸덕이 그랬다)
			for k in [1.0, 0.7, 0.5]:
				FACE_DIFF = base * k
				_remove_face(img)
		"tile":
			# 칸을 꽉 채우는 바닥 무늬(벨트 · 자기장 · 설탕막 · 물감) — 배경이 없으니 가운데 정사각형만 잘라 쓴다.
			# "배경 위의 물건"으로 시키면 AI 가 무늬 위에 젤리 · 구슬을 올려 그려 와서 이렇게 바꿨다
			var m := mini(img.get_width(), img.get_height())
			img = img.get_region(Rect2i((img.get_width() - m) / 2, (img.get_height() - m) / 2, m, m))
			img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		"fx":
			_fx(img)
			# 빛은 넓은 검은 바탕 가운데에 작게 그려져 온다 — 빛이 있는 데만 잘라야 텍스처를 꽉 채운다
			var used := img.get_used_rect()
			if used.has_area():
				img = img.get_region(used)
			img = _square(img, 128)
		_:
			var k := minf(1.0, 1280.0 / maxf(img.get_width(), img.get_height()))
			img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	var out := ProjectSettings.globalize_path("res://art/%s/%s.png" % [_game_dir(a[1]), a[1]])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img.save_png(out)
	print("-> ", out, "  ", img.get_size())
	quit(0)


func _dist(c: Color, k: Color) -> float:
	return Vector3(c.r - k.r, c.g - k.g, c.b - k.b).length()


## 네 모서리 평균 — 배경색.
func _corner_color(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var k := Color(0, 0, 0)
	var n := 0
	for cx in [0, w - 8]:
		for cy in [0, h - 8]:
			for y in 8:
				for x in 8:
					k += img.get_pixel(cx + x, cy + y)
					n += 1
	k /= n
	k.a = 1.0
	return k


## 배경과 색상이 같은 픽셀(= 배경이 비친 그림자)을 지운다. 채도가 낮은 것(회색 몸체)은 안 건드린다.
func _mirror_left(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var top := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				top = y
				break
		if top >= 0:
			break
	var sx := 0.0
	var n := 0
	for y in range(top, mini(h, top + int(h * 0.06))):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				sx += x
				n += 1
	var axis := sx / maxi(1, n)
	print("mirror axis ", axis)
	for y in h:
		for x in w:
			if x <= axis:
				continue
			var src := int(round(2.0 * axis - x))
			img.set_pixel(x, y, img.get_pixel(src, y) if src >= 0 else Color(0, 0, 0, 0))


func _unshadow(img: Image, bg: Color, tol := 0.08, smin := 0.3) -> void:
	var cut := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.s < smin:
				continue
			var dh := absf(c.h - bg.h)
			if minf(dh, 1.0 - dh) < tol:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				cut += 1
	print("shadow px removed ", cut)


func _key(img: Image, flood: bool = true) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	# 네 모서리 8×8 평균 = 배경색
	var key := Color(0, 0, 0)
	var n := 0
	for cx in [0, w - 8]:
		for cy in [0, h - 8]:
			for y in 8:
				for x in 8:
					key += img.get_pixel(cx + x, cy + y)
					n += 1
	key /= n
	key.a = 1.0
	print("background ", key.to_html(false))

	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	if not flood:
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var d := _dist(c, key)
				if d < HI:
					img.set_pixel(x, y, _unmix(c, key, clampf((d - LO) / (HI - LO), 0.0, 1.0)))
		var u := img.get_used_rect()
		return img.get_region(u) if u.has_area() else img
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i]:
			continue
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		var d := _dist(c, key)
		if d >= HI:
			continue
		seen[i] = 1
		img.set_pixel(x, y, _unmix(c, key, clampf((d - LO) / (HI - LO), 0.0, 1.0)))
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	_keep_largest(img)
	var used := img.get_used_rect()
	return img.get_region(used) if used.has_area() else img


## 배경색이 섞인 가장자리에서 배경 몫을 빼낸다 — 안 빼면 마젠타 테두리가 남는다.
func _unmix(c: Color, key: Color, a: float) -> Color:
	if a > 0.0:
		c = Color((c.r - key.r * (1.0 - a)) / a, (c.g - key.g * (1.0 - a)) / a, (c.b - key.b * (1.0 - a)) / a).clamp()
	c.a = a
	return c


## 가장 큰 덩어리 하나만 남긴다. 몸통 둘레에 따로 떠 있는 반짝이 · 점이 남으면
## 자르는 범위가 그만큼 넓어져서 몸통이 작고 한쪽으로 치우친다.
func _keep_largest(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(0)
	var sizes := [0]
	for start in w * h:
		if label[start] != 0 or img.get_pixel(start % w, start / w).a < 0.5:
			continue
		var id := sizes.size()
		var n := 0
		var stack := PackedInt32Array([start])
		label[start] = id
		while not stack.is_empty():
			var i := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			n += 1
			var x := i % w
			var y := i / w
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var j := ny * w + nx
				if label[j] == 0 and img.get_pixel(nx, ny).a >= 0.5:
					label[j] = id
					stack.append(j)
		sizes.append(n)
	var best := 1
	for k in range(1, sizes.size()):
		if sizes[k] > sizes[best]:
			best = k
	for i in w * h:
		if label[i] != best:
			var c := img.get_pixel(i % w, i / w)
			# 덩어리 가장자리의 반투명 띠는 남긴다 — 이웃이 큰 덩어리면
			if label[i] == 0 and c.a > 0.0 and c.a < 0.5 and _near_label(label, w, h, i, best):
				continue
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


func _near_label(label: PackedInt32Array, w: int, h: int, i: int, id: int) -> bool:
	var x := i % w
	var y := i / w
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and ny >= 0 and nx < w and ny < h and label[ny * w + nx] == id:
				return true
	return false


## 정사각형으로 — 4% 여백. bottom 이면 바닥에 붙인다(블록 몸통): 착지할 때 바닥을 기준으로
## 찌그러지므로, 납작한 모양이 가운데 정렬로 위아래 여백을 가지면 찌그러질 때 떠 보인다.
func _square(img: Image, size: int, bottom: bool = false) -> Image:
	var s := int(maxf(img.get_width(), img.get_height()) * 1.08)
	var sq := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var y := (s - img.get_height()) / 2
	if bottom:
		y = s - img.get_height() - int(s * 0.04)
	sq.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((s - img.get_width()) / 2, y))
	sq.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return sq


## 분홍빛(빨강 · 파랑이 초록보다 확 높은) 픽셀을 반투명 검은 그림자로.
func _unpink(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if c.r > c.g + 0.12 and c.b > c.g + 0.12 and absf(c.r - c.b) < 0.3:
				var v := (c.r + c.g + c.b) / 3.0
				img.set_pixel(x, y, Color(0.04, 0.04, 0.06, c.a * clampf(1.0 - v, 0.3, 0.6)))


func _fx(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			# JPEG 의 검은 바탕은 0 이 아니라 0.02~0.04 로 끓는다 — 바닥을 깎아야 네모가 안 보인다
			var lum := clampf((c.get_luminance() - 0.05) / 0.95, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, lum))


## 얼굴 지우기 — 몸통 안쪽에 떠 있는 **작은 얼룩**(눈 · 볼터치 · 입)을 둘레 몸통 색으로 메운다.
## 얼룩 = 주변 평균색(반경 BLUR_R)과 FACE_DIFF 이상 다른 픽셀 덩어리 중
##   ① 투명한 곳(바깥)에서 EDGE_GAP 이상 떨어져 있고 — 외곽선 · 몸 가장자리는 건드리지 않는다
##   ② 넓이가 FACE_MAX 이하 — 리본 · 모자 같은 소품은 크다
##   ③ 몸통 덩어리의 가운데 영역(세로 FACE_Y) 안 — 머리 위 소품 · 발은 제외
## 메우기는 바깥에서 안으로 이웃 평균을 번져 넣는다(한 겹씩). 단색으로 찍으면 셀 셰이딩 결이 끊긴다.
const BLUR_R := 9
static var FACE_DIFF := 0.16   ## post.bat ... noface 0.1 처럼 네 번째 인자로 바꾼다 — 어두운 몸에 어두운 눈은 차이가 작다
const EDGE_GAP := 6
const FACE_MAX := 0.012     ## 그림 넓이 대비
const FACE_Y := Vector2(0.18, 0.82)   ## 불투명 영역 세로 범위 안에서의 비율


func _remove_face(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var a := PackedFloat32Array()
	a.resize(n)
	var rgb := PackedVector3Array()
	rgb.resize(n)
	var top := h
	var bot := 0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			a[y * w + x] = c.a
			rgb[y * w + x] = Vector3(c.r, c.g, c.b)
			if c.a > 0.5:
				top = mini(top, y)
				bot = maxi(bot, y)
	# 바깥(투명)에서의 거리 — 두 번 훑는 맨해튼 거리
	var dist := PackedInt32Array()
	dist.resize(n)
	for i in n:
		dist[i] = 0 if a[i] < 0.5 else 9999
	for y in h:
		for x in w:
			var i := y * w + x
			if x > 0: dist[i] = mini(dist[i], dist[i - 1] + 1)
			if y > 0: dist[i] = mini(dist[i], dist[i - w] + 1)
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			if x < w - 1: dist[i] = mini(dist[i], dist[i + 1] + 1)
			if y < h - 1: dist[i] = mini(dist[i], dist[i + w] + 1)
	# 불투명한 픽셀만의 상자 흐림(적분 영상) — 주변 몸통 색
	var sw := w + 1
	var sc := PackedVector3Array()
	sc.resize(sw * (h + 1))
	var sa := PackedFloat32Array()
	sa.resize(sw * (h + 1))
	for y in h:
		for x in w:
			var i := y * w + x
			var on := 1.0 if a[i] > 0.5 else 0.0
			var j := (y + 1) * sw + x + 1
			sc[j] = rgb[i] * on + sc[j - 1] + sc[j - sw] - sc[j - sw - 1]
			sa[j] = on + sa[j - 1] + sa[j - sw] - sa[j - sw - 1]
	var cand := PackedByteArray()
	cand.resize(n)
	for y in h:
		for x in w:
			var i := y * w + x
			if dist[i] < EDGE_GAP:
				continue
			var x0 := maxi(0, x - BLUR_R)
			var x1 := mini(w, x + BLUR_R + 1)
			var y0 := maxi(0, y - BLUR_R)
			var y1 := mini(h, y + BLUR_R + 1)
			var cnt := sa[y1 * sw + x1] - sa[y0 * sw + x1] - sa[y1 * sw + x0] + sa[y0 * sw + x0]
			if cnt < 1.0:
				continue
			var avg := (sc[y1 * sw + x1] - sc[y0 * sw + x1] - sc[y1 * sw + x0] + sc[y0 * sw + x0]) / cnt
			if (rgb[i] - avg).length() > FACE_DIFF:
				cand[i] = 1
	# 덩어리로 묶어 조건에 맞는 것만 남긴다
	var lab := PackedInt32Array()
	lab.resize(n)
	var hole := PackedByteArray()
	hole.resize(n)
	var ymin := top + (bot - top) * FACE_Y.x
	var ymax := top + (bot - top) * FACE_Y.y
	var removed := 0
	var id := 0
	for s in n:
		if cand[s] == 0 or lab[s] != 0:
			continue
		id += 1
		var comp := PackedInt32Array([s])
		lab[s] = id
		var k := 0
		var cy := 0.0
		while k < comp.size():
			var i := comp[k]
			k += 1
			cy += i / w
			var x := i % w
			for d in [-1, 1, -w, w]:
				var j: int = i + d
				if j < 0 or j >= n or (d == -1 and x == 0) or (d == 1 and x == w - 1):
					continue
				if cand[j] == 1 and lab[j] == 0:
					lab[j] = id
					comp.append(j)
		cy /= comp.size()
		if comp.size() <= n * FACE_MAX and cy >= ymin and cy <= ymax:
			removed += 1
			for i in comp:
				hole[i] = 1
	# 구멍을 두 픽셀 넓혀(가장자리 번짐까지) 바깥에서 안으로 메운다
	for pass_ in 2:
		var grow := hole.duplicate()
		for i in n:
			if hole[i] == 0:
				continue
			for d in [-1, 1, -w, w]:
				var j: int = i + d
				if j >= 0 and j < n and a[j] > 0.5 and dist[j] >= 2:
					grow[j] = 1
		hole = grow
	var left := 0
	for i in n:
		left += hole[i]
	while left > 0:
		var fill := []
		for i in n:
			if hole[i] == 0:
				continue
			var sum := Vector3.ZERO
			var c := 0
			for d in [-1, 1, -w, w, -w - 1, -w + 1, w - 1, w + 1]:
				var j: int = i + d
				if j >= 0 and j < n and hole[j] == 0 and a[j] > 0.5:
					sum += rgb[j]
					c += 1
			if c >= 2:
				fill.append([i, sum / c])
		if fill.is_empty():
			break
		for f in fill:
			rgb[f[0]] = f[1]
			hole[f[0]] = 0
			left -= 1
	for i in n:
		var v := rgb[i]
		img.set_pixel(i % w, i / w, Color(v.x, v.y, v.z, a[i]))
	print("face blobs removed: ", removed)


## 그림은 게임마다 폴더가 따로다 — 이름 앞머리로 가른다. sky_ → art/sky, runner_ → art/runner, gh_ → art/gangho, 나머지 → art/jelly.
func _game_dir(name: String) -> String:
	if name.begins_with("sky_"):
		return "sky"
	if name.begins_with("runner_"):
		return "runner"
	if name.begins_with("gh_"):
		return "gangho"
	return "jelly"
