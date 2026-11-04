extends SceneTree

## 월드 러너 그림 마무리 — post_picks.sh 다음에 돌린다(여러 번 돌려도 같다).
##   godot --headless --path . --script res://tools/runner_art.gd
##
## 랜드마크 runner_lm_* — 원래 색으로 뽑고 소유자 색이 들 부분만 청록 #00FFFF 로 칠해 뽑는다(prompts.txt @rlm).
##          청록 픽셀을 _tint 마스크(밝기만)로 떼고 원본에서는 회색으로 뺀다. 게임이 _tint 를 소유자 색으로 얹는다.
##          (흰 도자기로 뽑은 예전 그림은 회색으로만 빼고 _tint 없음 — 게임이 통째로 소유자 색)
## 캐릭터 runner_char_N 에서 레이어 둘:
## _cloth — 의상 마스크. **목 아래의 흰 · 회색 픽셀**(옷)만 남기고 원래 밝기를 그대로 둔다.
##          게임이 이걸 플레이어 색으로 곱해 원본 위에 얹으면 명암은 살고 옷 색만 바뀐다.
##          머리 쪽(은발 · 흰 모자 · 눈 흰자)은 건드리지 않으려고 세로 NECK 위는 뺀다.
## _glow  — 실루엣을 흐리게 번진 흰 빛. 게임이 플레이어 색으로 물들여 캐릭터 뒤에 깐다(오라).

const KEY_MIN := 200     ## 청록 픽셀이 이보다 많으면 "청록으로 칠해 뽑은 그림"으로 본다
const COLORFUL := 0.08   ## 평균 채도가 이보다 높으면 원래 색 그림(이미 처리됨) — 회색 · 흰 도자기와 가른다
const SHADE := 0.55     ## 색 든 부분의 음영 세기 — 1 이면 원래 그대로(어두운 면이 거의 검게 나와 너무 부각됐다)
const NECK := 0.50    ## 그림 높이에서 이 비율 아래만 옷으로 본다 — 0.40 이면 단발(은발) 끝이 옷으로 잡혀 물들었다
const EDGE := 8        ## 바깥(투명)에서 이만큼 안쪽만 — 그림 둘레의 흰 스티커 테두리는 옷이 아니다
const SAT_MAX := 0.16  ## 이보다 채도가 낮고
const VAL_MIN := 0.50  ## 이보다 밝으면 흰 옷


func _init() -> void:
	var dir := ProjectSettings.globalize_path("res://art/runner/")
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("runner_lm_") and f.ends_with(".png"):
			if f.ends_with("_tint.png"):
				continue
			var lm := Image.load_from_file(dir + f)
			lm.convert(Image.FORMAT_RGBA8)
			var tint := Image.create(lm.get_width(), lm.get_height(), false, Image.FORMAT_RGBA8)
			var keyed := 0
			var sat := 0.0
			var n := 0
			for y in lm.get_height():
				for x in lm.get_width():
					var c := lm.get_pixel(x, y)
					if c.a > 0.5:
						n += 1
						sat += c.s
						if _cyan(c) > 0.5:
							keyed += 1
			if keyed > KEY_MIN:
				# 청록으로 칠해 뽑은 부분만 소유자 색 — 나머지는 원래 색 그대로(사용자 결정 11-04).
				# 원본의 청록은 회색으로 빼서, 게임이 _tint 를 얹었을 때 청록 테두리가 안 남게 한다
				for y in lm.get_height():
					for x in lm.get_width():
						var c := lm.get_pixel(x, y)
						var k := _cyan(c)
						if k <= 0.0:
							continue
						var v := c.get_luminance()
						lm.set_pixel(x, y, Color(lerpf(c.r, v, k), lerpf(c.g, v, k), lerpf(c.b, v, k), c.a))
						var s := lerpf(1.0, v, SHADE)
						tint.set_pixel(x, y, Color(s, s, s, c.a * k))
				print("%s  청록 %d px" % [f, keyed])
			elif n > 0 and sat / n > COLORFUL:
				print("%s  이미 처리됨(청록 없음) — 그대로" % f)   # 두 번째 실행 — 청록은 이미 회색으로 빠졌다
				continue
			else:
				# shortcut: 흰 도자기로 뽑은 예전 그림 — 회색으로만 빼고 _tint 는 안 만든다(게임이 통째로 소유자 색).
				# 위에서 몇 % 로 잘라 칠했더니 칼로 벤 것처럼 보였다. 청록 방식으로 다 다시 뽑으면 이 갈래를 지운다
				for y in lm.get_height():
					for x in lm.get_width():
						var c := lm.get_pixel(x, y)
						var v := c.get_luminance()
						lm.set_pixel(x, y, Color(v, v, v, c.a))
				lm.save_png(dir + f)
				DirAccess.remove_absolute(dir + f.replace(".png", "_tint.png"))
				continue
			lm.save_png(dir + f)
			tint.save_png(dir + f.replace(".png", "_tint.png"))
	for i in 4:
		var path := ProjectSettings.globalize_path("res://art/runner/runner_char_%d.png" % i)
		var img := Image.load_from_file(path)
		if img == null or img.is_empty():
			print("없음 ", path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var cloth := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var sil := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var used := img.get_used_rect()
		var neck_y := used.position.y + int(used.size.y * NECK)
		var n := 0
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				sil.set_pixel(x, y, Color(1, 1, 1, c.a))
				if y >= neck_y and c.s < SAT_MAX and c.v > VAL_MIN and _inside(img, x, y):
					cloth.set_pixel(x, y, Color(c.v, c.v, c.v, c.a))
					n += 1
		cloth.save_png(path.replace(".png", "_cloth.png"))
		# 흐리기 — 작게 줄였다 다시 키우면 선형 보간이 번진다(가우스 흐림 대신)
		sil.resize(w / 16, h / 16, Image.INTERPOLATE_BILINEAR)
		# 줄인 상태에서 알파를 키워야 빛이 실루엣 바깥으로 번진다(안 키우면 가장자리에서 금방 사라진다)
		for y in sil.get_height():
			for x in sil.get_width():
				var s := sil.get_pixel(x, y)
				sil.set_pixel(x, y, Color(1, 1, 1, minf(1.0, s.a * 2.5)))
		sil.resize(w / 4, h / 4, Image.INTERPOLATE_CUBIC)
		sil.save_png(path.replace(".png", "_glow.png"))
		print("runner_char_%d  옷 %d px" % [i, n])
	quit()


## 네 방향으로 EDGE 만큼 가도 불투명한가 — 실루엣 가장자리(스티커 테두리)를 거른다.
func _inside(img: Image, x: int, y: int) -> bool:
	for d in [Vector2i(EDGE, 0), Vector2i(-EDGE, 0), Vector2i(0, EDGE), Vector2i(0, -EDGE)]:
		var p: Vector2i = Vector2i(x, y) + d
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height() or img.get_pixel(p.x, p.y).a < 0.5:
			return false
	return true


## 청록(#00FFFF 로 칠해 뽑은 부분)인 정도 0~1. 그림자 진 청록(어둡게)도 잡고, 회색 · 하늘색 기운은 거른다.
func _cyan(c: Color) -> float:
	if c.a <= 0.0 or absf(c.h - 0.5) > 0.07 or c.v < 0.25:
		return 0.0
	return clampf((c.s - 0.25) / 0.3, 0.0, 1.0)
