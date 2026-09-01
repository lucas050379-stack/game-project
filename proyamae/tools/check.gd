extends SceneTree
# 프야매 — 수집한 원본이 성한지 검사합니다 (헤드리스 전용 도구).
#
#   check.bat
#
# 수집기는 표 하나가 통째로 비어도 "완료"라고 말하고 넘어갑니다. 그 상태로
# 변환하면 그 시즌 선수 전원이 장타력·정신력을 평균값으로 받게 되는데,
# 화면에는 멀쩡한 카드로 보여서 **눈으로는 절대 못 잡습니다.** 그래서 이 검사가
# 있습니다. 문제가 있는 연도는 원본을 지우고 `fetch.bat <연도>` 로 다시 받으세요.
#
# 보는 것:
#   ① 여섯 표가 다 있고 비어 있지 않은가
#   ② 타자 세 표(hit1·hit2·run)의 선수 집합이 일치하는가
#   ③ 투수 두 표(pit1·pit2)의 선수 집합이 일치하는가
#   ④ 구단 수가 그 시즌 KBO 구단 수와 맞는가

const NEED := ["hit1", "hit2", "run", "def", "pit1", "pit2"]

# **주루·수비 기록은 KBO 기록실에 2001년부터만 있습니다.** 2000년은 자료 자체가
# 없으므로 없다고 나무라면 안 됩니다 — 변환기가 구형 표(BasicOld)의 도루·실책으로
# 메웁니다.
const RUNDEF_FROM := 2001

func _keys_of(t) -> Dictionary:
	var out := {}
	if t == null:
		return out
	var head: Array = t["head"]
	var ni := head.find("선수명")
	var ti := head.find("팀명")
	if ni < 0 or ti < 0:
		return out
	for r in t["rows"]:
		if ni < r.size() and ti < r.size():
			out["%s/%s" % [r[ni], r[ti]]] = true
	return out

func _teams_of(t) -> Dictionary:
	var out := {}
	if t == null:
		return out
	var ti := (t["head"] as Array).find("팀명")
	if ti < 0:
		return out
	for r in t["rows"]:
		if ti < r.size():
			out[str(r[ti])] = int(out.get(str(r[ti]), 0)) + 1
	return out

func _check(year: int) -> Array:
	# [문제 목록, 요약 문자열]
	var path := "res://data/raw/%d.json" % year
	if not FileAccess.file_exists(path):
		return [["원본 없음"], ""]
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("tables"):
		return [["파일이 깨졌습니다"], ""]
	var tb: Dictionary = d["tables"]
	var bad: Array = []

	var need: Array = NEED.duplicate()
	if year < RUNDEF_FROM:
		need.erase("run")
		need.erase("def")
	for k in need:
		if not tb.has(k):
			bad.append("%s 표가 없음" % k)
		elif (tb[k]["rows"] as Array).is_empty():
			bad.append("%s 표가 비었음" % k)
	if not bad.is_empty():
		return [bad, ""]

	var h1 := _keys_of(tb["hit1"])
	var h2 := _keys_of(tb["hit2"])
	var rn := _keys_of(tb.get("run", null))
	var p1 := _keys_of(tb["pit1"])
	var p2 := _keys_of(tb["pit2"])

	# 타자 세 표는 같은 선수 집합이어야 합니다. 어긋나면 구단 하나가 빠진 것입니다.
	var pairs: Array = [["hit2", h2]]
	if need.has("run"):
		pairs.append(["run", rn])
	for pair in pairs:
		var miss := 0
		for k in h1:
			if not (pair[1] as Dictionary).has(k):
				miss += 1
		if miss > 0:
			bad.append("hit1 에만 있는 선수 %d명 (%s 쪽이 모자람)" % [miss, pair[0]])
	var pmiss := 0
	for k in p1:
		if not p2.has(k):
			pmiss += 1
	if pmiss > 0:
		bad.append("pit1 에만 있는 선수 %d명 (pit2 쪽이 모자람)" % pmiss)

	# 구단 수 — 표마다 다르면 어느 한 표에서 구단이 빠진 것입니다.
	var counts: Array = []
	for k in need:
		counts.append(_teams_of(tb[k]).size())
	var base: int = counts[0]
	for i in range(counts.size()):
		if counts[i] != base:
			bad.append("구단 수가 표마다 다름 (%s)" % str(counts))
			break

	var sm := "구단 %d · 타자 %d · 투수 %d" % [base, h1.size(), p1.size()]
	return [bad, sm]

func _init() -> void:
	var dir := DirAccess.open("res://data/raw")
	if dir == null:
		print("data/raw 가 없습니다. fetch.bat 을 먼저 돌리세요.")
		quit(1)
		return
	var years: Array = []
	for fn in dir.get_files():
		if fn.ends_with(".json"):
			years.append(int(fn.get_basename()))
	years.sort()
	if years.is_empty():
		print("받아 둔 원본이 없습니다.")
		quit(1)
		return

	var broken: Array = []
	for y in years:
		var r := _check(int(y))
		var bad: Array = r[0]
		if bad.is_empty():
			print("  %d  OK   %s" % [y, r[1]])
		else:
			broken.append(y)
			print("  %d  문제 %s" % [y, str(bad)])

	print("")
	if broken.is_empty():
		print("전부 성합니다 (%d시즌)." % years.size())
	else:
		print("문제가 있는 시즌 %d개: %s" % [broken.size(), str(broken)])
		print("다시 받으려면 해당 연도의 data/raw/<연도>.json 을 지우고 fetch.bat 을 돌리세요.")
	quit(0)
