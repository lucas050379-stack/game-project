class_name Tex
extends RefCounted

## 그림 텍스처. **`art/<이름>.png` 가 있으면 그걸, 없으면 코드로 만든 것을 준다.**
## `art/` 가 비어 있어도 게임이 돌아야 한다.
##
## 이펙트 텍스처(`fx_*`)는 전부 **흰색 + 알파**다. 색은 그릴 때 입히므로 블록 색마다 따로
## 그릴 필요가 없다. AI 로 뽑은 그림도 `tools/post.gd` 가 같은 형식(흰색, 밝기 = 알파)으로 바꾼다.
##
## glow · ring · beam 은 AI 그림을 찾지 않는다 — 기하학적인 것은 코드가 정확하다.

static var _cache := {}

const CODE_ONLY := ["fx_glow", "fx_ring", "fx_beam"]


## 그림이 없으면 null (블록 몸통 · 배경처럼 벡터로 대신 그리는 것).
static func art(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "res://art/%s.png" % name
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = t
	return t


## 이펙트 텍스처. 그림이 없으면 만들어서라도 준다.
static func fx(name: String) -> Texture2D:
	if _cache.has(name) and _cache[name] != null:
		return _cache[name]
	var t: Texture2D = null if CODE_ONLY.has(name) else art(name)
	if t == null:
		t = ImageTexture.create_from_image(_make(name))
	_cache[name] = t
	return t


static func _make(name: String) -> Image:
	var n := 64
	var hgt := 64
	if name == "fx_beam":
		n = 128
		hgt = 32
	var img := Image.create(n, hgt, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.09
	for y in hgt:
		for x in n:
			# -1..1 좌표
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / hgt * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			var ang := atan2(v, u)
			var a := 0.0
			match name:
				"fx_glow":
					a = pow(maxf(0.0, 1.0 - d), 2.2)
				"fx_ring":
					a = exp(-pow((d - 0.78) / 0.09, 2.0)) * float(d < 1.0)
				"fx_beam":
					a = exp(-pow(v / 0.38, 2.0)) * smoothstep(1.0, 0.75, absf(u))
				"fx_spark":
					# 네 갈래: 가로 · 세로로 가늘고 긴 빛 + 가운데 심지
					var arm := maxf(exp(-pow(v / 0.07, 2.0)) * (1.0 - absf(u)),
							exp(-pow(u / 0.07, 2.0)) * (1.0 - absf(v)))
					a = maxf(arm, pow(maxf(0.0, 1.0 - d * 2.2), 2.0))
				"fx_star":
					# 다섯 뿔 — 각도에 따라 반지름이 0.42 ~ 0.95 를 오간다
					var k := absf(fposmod(ang + PI * 0.5, TAU / 5.0) - TAU / 10.0) / (TAU / 10.0)
					var edge := lerpf(0.95, 0.42, 1.0 - k)
					a = smoothstep(edge, edge - 0.08, d)
				"fx_shard":
					# 위가 뾰족한 조각
					var half := (1.0 - (v + 1.0) * 0.5) * 0.55 + 0.05
					a = smoothstep(half, half - 0.06, absf(u)) * smoothstep(0.95, 0.85, absf(v))
				"fx_smoke":
					var nz := noise.get_noise_2d(x, y) * 0.5 + 0.5
					a = pow(maxf(0.0, 1.0 - d), 1.5) * (0.45 + nz * 0.55)
				"fx_burst":
					var ray := pow(absf(noise.get_noise_1d(ang * 9.0)), 0.6)
					a = maxf(pow(maxf(0.0, 1.0 - d), 2.0), ray * maxf(0.0, 1.0 - d) * 0.9)
				_:
					a = pow(maxf(0.0, 1.0 - d), 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return img
