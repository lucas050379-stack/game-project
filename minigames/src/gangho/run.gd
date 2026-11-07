class_name GhRun
extends RefCounted

## 한 판 — 같은 해 태어난 다섯(나 + 동년배 넷)과 그들이 같이 사는 세상.
## 해마다 [method step] 이 다섯을 한 해씩 굴린다. 내가 갈림길 앞에 서 있으면 아무도 안 움직인다
## (동년배가 먼저 늙어 버리면 "같은 해" 가 깨진다).
##
## 내가 죽으면 판이 끝나지만, 묘비 화면에 동년배의 마지막을 보여 주려고 [method finish_peers] 가
## 남은 넷을 끝까지 살게 한다.

const PEERS := 4

var world: GhWorld
var me: GhLife
var peers: Array = []
var seed_ := 0
var rng_news := RandomNumberGenerator.new()


func _init(s: int) -> void:
	seed_ = s
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	rng_news.seed = s + 7
	var y := rng.randi_range(GhD.YEAR_MIN, GhD.YEAR_MAX)
	world = GhWorld.new(y, rng.randi())
	me = GhLife.born(world, rng.randi(), true)
	for i in PEERS:
		peers.append(GhLife.born(world, rng.randi(), false))
	var all: Array = [me] + peers
	for l: GhLife in all:
		l.peers = all.filter(func(o): return o != l)


func year() -> int:
	return world.start + me.age


func waiting() -> bool:
	return not me.pending.is_empty()


func done() -> bool:
	return not me.alive


## 한 해. 내가 갈림길 앞이면 아무것도 안 한다.
func step() -> void:
	if done() or waiting():
		return
	me.step()
	var news := false
	for p: GhLife in peers:
		var was := p.alive
		var nb := p.big.size()
		var wed := p.flags.has("married")
		p.step()
		# 동년배의 큰일이 소식으로 들려온다 — 한 해에 하나만(여럿이면 연대기가 남의 이야기로 덮인다)
		if not news and me.alive and p.alive and p.big.size() > nb and rng_news.randf() < 0.6:
			var t: String = String(p.big.back())
			var sp := t.find("  ")
			me.lines.append({age = me.age, kind = "peer", txt = "소식: 같은 해 태어난 %s, %s" % [p.name, t.substr(sp + 2) if sp >= 0 else t]})
			news = true
		# 첫사랑의 혼인
		if me.alive and not wed and p.flags.has("married") and me.lover == p.name and me.flags.has("first_love") and p.spouse != me.name:
			me.lines.append({age = me.age, kind = "peer", txt = "첫사랑 %s%s 다른 이와 혼인했다는 소식을 들었다. 그날 밤 잠이 오지 않았다." % [p.name, GhLife.josa(p.name, "이")]})
		if was and not p.alive and me.alive:
			me.lines.append({age = me.age, kind = "peer",
					txt = "같은 해 태어난 %s%s 세상을 떠났다는 소식을 들었다. (%s)" % [p.name, GhLife.josa(p.name, "이"), p.cause]})


## 내가 죽은 뒤 — 동년배 넷을 끝까지 살게 한다(묘비 화면에 그들의 마지막이 나온다).
func finish_peers() -> void:
	for p: GhLife in peers:
		var guard := 0
		while p.alive and guard < 160:
			p.step()
			guard += 1
