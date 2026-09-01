class_name Play
extends RefCounted

## 한 판. 노트 상태 · 판정 · 점수 · 체력.
##
## 노트는 [Dictionary] 배열로 들고 노드는 하나도 안 만든다 — 3분짜리 채보는
## 노트가 2천 개고, 그걸 노드로 만들면 생성 비용만으로 시작할 때 멈춘다.
##
## **판정은 레인마다 따로 커서를 민다.** 한 배열을 앞에서부터 훑으면 레인 0 의
## 노트를 기다리는 동안 레인 3 의 노트가 커서에 막힌다. `lane_idx[레인]` 이
## 그 레인에서 아직 안 끝난 첫 노트를 가리키고, 끝난 것만큼만 앞으로 간다.

enum { PENDING, HOLDING, DONE, MISSED }

var keys := 4
var notes: Array = []           ## {t, lane, dur, st, tick}
var lane_idx: PackedInt32Array  ## 레인별 커서
var lane_of: Array = []         ## 레인 -> 그 레인 노트들의 색인 배열

var total := 0                  ## 판정 대상 수 (롱노트는 머리+꼬리 2개)
var judged := 0
var counts := PackedInt32Array([0, 0, 0, 0, 0])
var weight_sum := 0.0
var combo := 0
var max_combo := 0
var combo_sum := 0.0
var hp := D.HP_START
## 음이탈 정도(0~1). 틀리면 오르고 시간이 지나면 내린다 — [Warp] 가 이 값으로
## 음악을 망가뜨린다. 판정 결과가 아니라 **지금 상태**라서 매 프레임 줄어든다.
var warp := 0.0
var dead := false
var last_t := 0.0

## 화면에 보여 줄 것들 — 그리기 쪽에서 읽는다.
var lane_lit := PackedFloat32Array()      ## 레인이 눌린 잔광 (0..1)
var lane_held := PackedInt32Array()       ## 지금 눌려 있는가
var pop_j := -1                           ## 방금 뜬 판정
var pop_t := 0.0
var pop_err := 0.0                        ## 방금 판정의 시간 오차(초). +면 늦게 침
var flash := PackedFloat32Array()         ## 레인별 타격 섬광

var autoplay := false
## 자동 연주가 **일부러** 놓치는 간격. 0 이면 다 친다.
## 음이탈([Warp])과 키음([Keys])이 실제로 어떻게 들리는지 확인하려고 둔 것이다 —
## 사람이 일부러 틀려 가며 듣는 것보다 이쪽이 훨씬 고르게 들린다.
##
## **이걸 켜면 자동 연주에 GREAT 이 조금 섞인다. 싱크 문제가 아니다.**
## 건너뛴 노트는 판정창(`D.MISS_AT`)을 다 지날 때까지 그 레인의 커서에 남아 있고,
## 자동 연주는 커서의 첫 노트만 보므로 그동안 다음 노트를 못 친다. 그 노트가
## 170ms 안에 오면 늦게 눌려 GREAT 이 된다. 사람이 칠 때는 안 생기는 현상이다 —
## 사람은 그 자리에서 건너뛴 노트를 직접 치기 때문이다.
## 성능을 의심하기 전에 `--miss` 없이 한 번 돌려 보라(그때는 전부 PERFECT 다).
var miss_every := 0

## 노트가 **소리를 낼 때** 불린다: `fire.call(노트 색인, 곡 시각)`.
## [Keys] 가 이걸 받아 그 자리의 음을 튼다 — 놓친 노트는 안 불리므로 음이 빈다.
var fire := Callable()


func setup(diff: Dictionary) -> void:
	keys = int(diff.keys)
	notes.clear()
	lane_of.clear()
	for i in keys:
		lane_of.append([])
	lane_idx = PackedInt32Array()
	lane_idx.resize(keys)
	lane_lit = PackedFloat32Array()
	lane_lit.resize(keys)
	lane_held = PackedInt32Array()
	lane_held.resize(keys)
	flash = PackedFloat32Array()
	flash.resize(keys)
	total = 0
	for n in diff.notes:
		var lane := clampi(int(n[1]), 0, keys - 1)
		var dur := float(n[2])
		# `skip` 은 자동 연주가 일부러 놓칠 노트다. 사람이 칠 때는 아무 뜻도 없다.
		var skip := miss_every > 0 and notes.size() % miss_every == 0
		notes.append({"t": float(n[0]), "lane": lane, "dur": dur, "st": PENDING,
			"tick": 0.0, "skip": skip})
		lane_of[lane].append(notes.size() - 1)
		total += 2 if dur > 0.0 else 1
		last_t = maxf(last_t, float(n[0]) + dur)


# ==================== 매 프레임 ====================

func step(now: float, delta: float) -> void:
	for i in keys:
		lane_lit[i] = maxf(0.0, lane_lit[i] - delta * 6.0)
		flash[i] = maxf(0.0, flash[i] - delta * 4.5)
	pop_t = maxf(0.0, pop_t - delta)
	warp = maxf(0.0, warp - delta * D.WARP_DECAY)
	if autoplay:
		_autoplay(now)
	_expire(now)
	_hold_tick(now, delta)


## 판정창을 지나도록 안 친 노트를 흘려보낸다.
func _expire(now: float) -> void:
	for lane in keys:
		var arr: Array = lane_of[lane]
		var i := lane_idx[lane]
		while i < arr.size():
			var n: Dictionary = notes[arr[i]]
			if n.st == DONE or n.st == MISSED:
				i += 1
				continue
			if n.st == HOLDING:
				break                       # 누르고 있는 중 — 커서를 넘기면 안 된다
			if now - n.t <= D.MISS_AT:
				break
			n.st = MISSED
			_score(D.MISS, 0.0)
			if n.dur > 0.0:
				_score(D.MISS, 0.0)         # 꼬리도 같이 놓친다
			i += 1
		lane_idx[lane] = i


## 누르고 있는 롱노트를 갚아 나간다.
func _hold_tick(now: float, delta: float) -> void:
	for n in notes:
		if n.st != HOLDING:
			continue
		var tail: float = n.t + n.dur
		if lane_held[n.lane] == 0:
			# 손을 뗐다. 끝 근처면 성공, 아니면 놓친 것.
			if tail - now <= D.RELEASE_WINDOW:
				n.st = DONE
				_score(D.PERFECT, 0.0)
			else:
				n.st = MISSED
				_score(D.MISS, 0.0)
			continue
		hp = minf(D.HP_MAX, hp + D.HP_HOLD * delta)
		n.tick += delta
		if n.tick >= D.HOLD_TICK:
			n.tick -= D.HOLD_TICK
			flash[n.lane] = maxf(flash[n.lane], 0.5)
		if now >= tail:
			n.st = DONE
			_score(D.PERFECT, 0.0)


# ==================== 입력 ====================

func press(lane: int, now: float) -> void:
	if lane < 0 or lane >= keys:
		return
	lane_held[lane] = 1
	lane_lit[lane] = 1.0
	var arr: Array = lane_of[lane]
	var i := lane_idx[lane]
	# 커서에서 가장 가까운 미처리 노트 하나만 본다. 뒤를 더 뒤져 봐야
	# 그건 아직 판정창에 들어오지도 않은 노트다.
	while i < arr.size() and (notes[arr[i]].st == DONE or notes[arr[i]].st == MISSED):
		i += 1
	lane_idx[lane] = i
	if i >= arr.size():
		Snd.hit(lane, keys)
		return
	var n: Dictionary = notes[arr[i]]
	var err: float = now - n.t
	if absf(err) > D.MISS_AT:
		Snd.hit(lane, keys)      # 헛손질. 판정은 주지 않는다(빈 타 페널티 없음)
		return
	var j := D.judge_of(absf(err))
	Snd.hit(lane, keys)
	flash[lane] = 1.0
	if j == D.MISS:
		n.st = MISSED
		_score(D.MISS, err)
		if n.dur > 0.0:
			_score(D.MISS, err)
		return
	_score(j, err)
	if fire.is_valid():
		fire.call(arr[i], now)
	if n.dur > 0.0:
		n.st = HOLDING
		n.tick = 0.0
	else:
		n.st = DONE


func release(lane: int) -> void:
	if lane < 0 or lane >= keys:
		return
	lane_held[lane] = 0


func _autoplay(now: float) -> void:
	for lane in keys:
		var arr: Array = lane_of[lane]
		var i := lane_idx[lane]
		while i < arr.size():
			var n: Dictionary = notes[arr[i]]
			if n.st == DONE or n.st == MISSED:
				i += 1
				continue
			if n.st == PENDING and now >= n.t and not n.skip:
				lane_idx[lane] = i
				press(lane, now)
			break
		if lane_held[lane] == 1:
			var done := true
			for k in arr:
				if notes[k].st == HOLDING:
					done = false
					break
			if done:
				release(lane)


# ==================== 점수 ====================

func _score(j: int, err: float) -> void:
	judged += 1
	counts[j] += 1
	weight_sum += D.J_WEIGHT[j]
	if j == D.MISS or j == D.BAD:
		combo = 0
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		combo_sum += float(combo)
	hp = clampf(hp + D.HP_DELTA[j], 0.0, D.HP_MAX)
	if j == D.MISS:
		warp = minf(1.0, warp + D.WARP_MISS)
	elif j == D.BAD:
		warp = minf(1.0, warp + D.WARP_BAD)
	if hp <= 0.0:
		dead = true
	pop_j = j
	pop_t = 0.55
	pop_err = err
	if j == D.MISS:
		Snd.miss()


## 지금까지의 점수. 판정 몫과 콤보 몫으로 나뉜다.
func score() -> int:
	if total <= 0:
		return 0
	var acc_part := weight_sum / float(total)
	var cmax := float(total) * (float(total) + 1.0) * 0.5
	var combo_part := combo_sum / maxf(cmax, 1.0)
	return int(D.SCORE_MAX * ((1.0 - D.COMBO_SHARE) * acc_part + D.COMBO_SHARE * combo_part))


## 정확도(0..1). 아직 안 친 노트는 세지 않는다 — 곡 중간에 보여 줘야 하는 값이다.
func acc() -> float:
	return 1.0 if judged == 0 else weight_sum / float(judged)


func full_combo() -> bool:
	return counts[D.BAD] == 0 and counts[D.MISS] == 0 and judged == total


func rank() -> String:
	var a := acc()
	if full_combo() and a >= 0.999:
		return "SSS"
	if a >= 0.97:
		return "SS"
	if a >= 0.94:
		return "S"
	if a >= 0.89:
		return "A"
	if a >= 0.80:
		return "B"
	if a >= 0.70:
		return "C"
	return "D"


func result() -> Dictionary:
	return {
		"score": score(), "acc": acc(), "combo": max_combo, "full": full_combo(),
		"rank": rank(), "counts": Array(counts), "total": total,
	}
