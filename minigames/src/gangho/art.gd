class_name GhArt
extends RefCounted

## 강호일생 그림 · 글자 도우미.
##
## **삽화는 `art/gangho/<이름>.png` 가 있으면 그것, 없으면 코드로 그린 수묵 산수**입니다.
## 폴더가 비어도 게임이 돌아야 합니다. 그림은 개발 때 Cloudflare 로 뽑습니다(art/prompts.txt 의 `gh_` 줄).
## 그림 이름은 장면 열쇠([method scene_of])와 같습니다 — 새 장면을 넣으면 프롬프트도 한 줄 넣으세요.

static var _img := {}


static func img(name: String) -> Texture2D:
	if not _img.has(name):
		var p := "res://art/gangho/%s.png" % name
		_img[name] = load(p) if ResourceLoader.exists(p) else null
	return _img[name]


## 직업 장면 — 그림이 **있을 때만** 쓴다(없으면 예전처럼 집안 · 관아 그림으로 돌아간다). 비슷한 일끼리 한 장을 나눠 쓴다.
const JOB_SCENE := {"doctor": "gh_job_doctor", "alchemist": "gh_job_doctor", "herbalist": "gh_job_doctor", "poisoner": "gh_job_assassin",
		"smith": "gh_job_smith", "mechanist": "gh_job_smith", "innkeeper": "gh_job_inn", "waiter": "gh_job_inn", "cook": "gh_job_inn",
		"factor": "gh_job_inn", "gibang": "gh_job_pleasure", "gisaeng": "gh_job_pleasure", "musician": "gh_job_pleasure",
		"teacher": "gh_job_scholar", "munsa": "gh_job_scholar", "strategist": "gh_job_scholar", "storyteller": "gh_job_scholar",
		"painter": "gh_job_scholar", "assassin": "gh_job_assassin", "informant": "gh_job_gamble", "gambler": "gh_job_gamble",
		"bounty": "gh_job_hunter", "ronin": "gh_job_hunter", "bodyguard": "gh_job_hunter", "patrol": "gh_job_hunter",
		"monk": "gh_job_temple", "taoist": "gh_job_temple", "diviner": "gh_job_temple", "boatman": "gh_job_river", "pirate": "gh_job_river",
		"graverobber": "gh_job_tomb", "laborer": "gh_job_labor", "escortman": "gh_escort", "officer": "gh_barracks",
		"instructor": "gh_barracks", "geumui": "gh_office", "dongchang": "gh_office", "pokwae": "gh_office", "constable": "gh_office",
		"interpreter": "gh_office"}


## 지금 이 사람의 삽화 열쇠 — 죽음 · 전쟁 · 은거 · 문파 · 태어난 집안 순으로 본다.
static func scene_of(l: GhLife, war: bool) -> String:
	if not l.alive:
		return "gh_grave"
	if war and l.flags.has("at_war"):
		return "gh_war"
	if l.flags.has("retired") or l.flags.has("monk"):
		return "gh_hermitage"
	if l.martial and not l.flags.has("quit"):
		match l.side:
			"정":
				return "gh_sect_jeong"
			"사":
				return "gh_sect_sa"
			"마":
				return "gh_sect_ma"
			"세가":
				return "gh_clan"
			"개방":
				return "gh_beggar"
			"새외":
				return "gh_sect_saeoe"
			"관군":
				return "gh_barracks"
			"표국":
				return "gh_escort"
			_:
				return "gh_wander"
	if l.job != "" and JOB_SCENE.has(l.job) and img(String(JOB_SCENE[l.job])) != null:
		return String(JOB_SCENE[l.job])
	if l.flags.has("official"):
		return "gh_office"
	return birth_scene(l.cls)


static func birth_scene(c: String) -> String:
	match c:
		"farm", "tenant":
			return "gh_birth_farm"
		"fisher":
			return "gh_birth_fisher"
		"hunter":
			return "gh_birth_hunter"
		"craft", "merchant", "clerk":
			return "gh_birth_town"
		"scholar", "noble":
			return "gh_birth_scholar"
		"royal":
			return "gh_birth_palace"
		"soldier":
			return "gh_barracks"
		"escort":
			return "gh_escort"
		"beggar":
			return "gh_beggar"
		"bandit":
			return "gh_sect_sa"
		"sectfam", "temple":
			return "gh_sect_jeong"
		"clan":
			return "gh_clan"
		"cult":
			return "gh_sect_ma"
		"nomad":
			return "gh_birth_steppe"
	return "gh_birth_farm"


## 삽화 한 칸. 그림이 있으면 칸을 덮게(넘치는 쪽은 잘라) 깔고, 없으면 수묵 산수를 그린다.
static func picture(ci: CanvasItem, r: Rect2, key: String, t: float, seed_: int) -> void:
	var tx := img(key)
	if tx != null:
		var ts := tx.get_size()
		var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
		ci.draw_texture_rect_region(tx, r, Rect2((ts - r.size / k) * 0.5, r.size / k))
	else:
		ink_landscape(ci, r, t, seed_, key)
	ci.draw_rect(r, GhD.INK, false, 2.0)


## 코드로 그린 수묵 산수 — 겹겹이 옅어지는 산 능선 · 안개 띠 · 해. 장면마다 씨앗이 달라 모양이 다르다.
static func ink_landscape(ci: CanvasItem, r: Rect2, t: float, seed_: int, key: String) -> void:
	ci.draw_rect(r, GhD.PAPER, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + seed_
	# 해 — 옅은 주홍 원 하나
	var sun := Vector2(r.position.x + r.size.x * rng.randf_range(0.6, 0.85), r.position.y + r.size.y * 0.28)
	ci.draw_circle(sun, r.size.y * 0.09, Color(0.78, 0.36, 0.26, 0.55))
	for layer in 4:
		var base_y := r.position.y + r.size.y * (0.42 + layer * 0.15)
		var amp := r.size.y * (0.26 - layer * 0.04)
		var col := GhD.INK.lerp(GhD.PAPER, 0.78 - layer * 0.2)
		var pts := PackedVector2Array()
		var n := 26
		var ph := rng.randf() * TAU
		var fr := rng.randf_range(1.2, 2.4)
		for i in n + 1:
			var x := r.position.x + r.size.x * float(i) / n
			var u := float(i) / n
			var h := sin(u * TAU * fr + ph) * 0.5 + 0.5
			h = pow(h, 2.2) * amp + sin(u * 37.0 + ph * 3.0) * amp * 0.06
			pts.append(Vector2(x, base_y - h + sin(t * 0.2 + layer) * 0.0))
		pts.append(Vector2(r.end.x, r.end.y))
		pts.append(Vector2(r.position.x, r.end.y))
		ci.draw_colored_polygon(pts, col)
		# 안개 띠 — 능선 아래를 종이색으로 흐리게
		ci.draw_rect(Rect2(r.position.x, base_y + r.size.y * 0.03, r.size.x, r.size.y * 0.035), Color(GhD.PAPER, 0.35), true)
	# 장면 표시 — 작은 붉은 낙관(그림이 아직 없다는 표시이기도 하다)
	var seal := Rect2(r.end.x - 34, r.end.y - 34, 22, 22)
	ci.draw_rect(seal, GhD.RED, true)
	ci.draw_rect(seal.grow(-4), Color(1, 0.9, 0.85, 0.5), false, 1.5)


# ==================== 글자 ====================

static func font() -> Font:
	return P.font()


## 왼쪽 맞춤 글 한 줄. pos 는 글줄의 왼쪽 위.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, c: Color) -> void:
	ci.draw_string(font(), pos + Vector2(0, size * 0.86), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), c)


static func text_w(s: String, size: float) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x


static func text_mid(ci: CanvasItem, c: Vector2, s: String, size: float, col: Color, outline: float = 0.0,
		oc: Color = GhD.INK) -> void:
	G2.text_mid(ci, c, s, size, col, outline, oc)


## 폭에 맞춰 줄을 나눈다 — 띄어쓰기에서 끊고, 한 낱말이 폭보다 길면 글자 단위로 끊는다.
static var _wrap_cache := {}


static func wrap(s: String, width: float, size: float) -> PackedStringArray:
	var key := "%s|%d|%d" % [s, int(width), int(size)]
	if _wrap_cache.has(key):
		return _wrap_cache[key]
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var cand := word if line == "" else line + " " + word
		if text_w(cand, size) <= width:
			line = cand
			continue
		if line != "":
			out.append(line)
			line = ""
		# 낱말 하나가 폭보다 길면 글자 단위로
		var part := ""
		for ch in word:
			if text_w(part + ch, size) > width and part != "":
				out.append(part)
				part = ""
			part += ch
		line = part
	if line != "":
		out.append(line)
	if _wrap_cache.size() > 4000:
		_wrap_cache.clear()
	_wrap_cache[key] = out
	return out


## 종이 판 — 둥근 모서리 · 먹 테두리.
static func paper(ci: CanvasItem, r: Rect2, col: Color = GhD.PAPER, edge: float = 2.0) -> void:
	G2.panel(ci, r, col, GhD.INK, edge, 10)


## 막대 하나(0~1).
static func bar(ci: CanvasItem, r: Rect2, v: float, col: Color) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0.12), true)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col, true)
	ci.draw_rect(r, Color(GhD.INK, 0.5), false, 1.0)


## 묘비 — 위가 둥근 돌.
static func tomb(ci: CanvasItem, r: Rect2) -> void:
	var pts := PackedVector2Array()
	var rad := r.size.x * 0.5
	var top := r.position.y + rad * 0.55
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		pts.append(Vector2(r.get_center().x + cos(a) * rad, top + sin(a) * rad * 0.55))
	pts.append(Vector2(r.end.x, r.end.y))
	pts.append(Vector2(r.position.x, r.end.y))
	ci.draw_colored_polygon(pts, Color8(150, 148, 140))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(r.get_center() + (p - r.get_center()) * 0.94)
	ci.draw_colored_polygon(inner, Color8(176, 173, 164))
	pts.append(pts[0])
	ci.draw_polyline(pts, GhD.INK, 3.0, true)
