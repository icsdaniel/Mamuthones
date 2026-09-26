class_name ChartRules
extends RefCounted
## Checks a chart against the format (docs/architecture.md) and the readability rules
## (docs/design.md section 4). Returns human-readable problems; an empty list means the chart is fine.
##
## Hands: lane 0 is the left thumb, lane 2 the right, lane 1 and swipes whichever thumb is free.
## A thumb may make one input per eighth (per sixteenth at Expert); a hold keeps its thumb busy.

const TOL := 0.001   ## beats (Bonfires sits on thirds rounded to 4 decimals)
const LEVEL_EXTRAS := {
	"easy": ["step", "bell", "rest"],
	"medium": ["step", "bell", "rest", "hold"],
}


static func check_song(song: SongData) -> Array[String]:
	var out: Array[String] = []
	out.append_array(song.errors)
	if song.kind == "piazza":
		if not song.charts.has("piazza"):
			out.append("%s: a piazza song needs a chart named piazza" % song.id)
	else:
		for d in SongData.DIFFICULTIES:
			if not song.charts.has(d):
				out.append("%s: missing chart %s" % [song.id, d])
	for d in song.charts:
		out.append_array(check(song, d))
	return out


static func check(song: SongData, difficulty: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Array = song.charts.get(difficulty, [])
	var where := "%s/%s" % [song.id, difficulty]
	if raw.is_empty():
		out.append("%s: empty chart" % where)
		return out
	var prev_b := -INF
	var last_bell := -INF
	var holds := []   # [lane, start, end]
	var rests := []   # [start, end]
	var events := []  # thumb inputs: [b, lane (-1 = either), busy_until]
	for item in raw:
		if not (item is Dictionary):
			out.append("%s: a note is not an object" % where)
			continue
		var b := float(item.get("b", -1.0))
		var k := str(item.get("k", ""))
		var at := "%s b=%s" % [where, b]
		if b < 0.0:
			out.append("%s: negative beat" % at)
		if b < prev_b - TOL:
			out.append("%s: notes not sorted by b" % at)
		prev_b = maxf(prev_b, b)
		if not Note.KIND_NAMES.has(k):
			out.append("%s: unknown kind '%s'" % [at, k])
			continue
		if song.kind == "piazza" and not k in ["bell", "rest"]:
			out.append("%s: piazza charts have only bells and rests" % at)
		if song.kind == "story" and LEVEL_EXTRAS.has(difficulty) and not k in LEVEL_EXTRAS[difficulty]:
			out.append("%s: %s is not used at %s (design section 4)" % [at, k, difficulty])
		if song.kind == "story" and LEVEL_EXTRAS.has(difficulty) and bool(item.get("call", false)):
			out.append("%s: off-beat calls start at hard" % at)
		var lane := int(item.get("lane", -1))
		if k in ["step", "hold", "ring"] and (lane < 0 or lane > 2):
			out.append("%s: %s needs lane 0, 1 or 2" % [at, k])
			continue
		if k == "swipe" and not int(item.get("dir", 0)) in [1, -1]:
			out.append("%s: swipe dir must be 1 or -1" % at)
		var length := float(item.get("len", 1.0))
		if (k == "hold" or k == "rest") and length <= 0.0:
			out.append("%s: %s len must be positive" % [at, k])
		if k == "bell" or k == "ring":
			if b - last_bell < 0.5 - TOL:
				out.append("%s: bells closer than half a beat" % at)
			last_bell = b
			for r in rests:
				if b > r[0] - TOL and b < r[1] - TOL:
					out.append("%s: bell inside a stand-still" % at)
		for h in holds:
			if lane == h[0] and b > h[1] + TOL and b < h[2] - TOL and k in ["step", "hold", "ring"]:
				out.append("%s: note hidden under a hold in lane %d" % [at, lane])
		match k:
			"hold":
				holds.append([lane, b, b + length])
				events.append([b, lane, b + length])
			"step", "ring":
				events.append([b, lane, b])
			"swipe":
				events.append([b, -1, b])
			"rest":
				rests.append([b, b + length])
				for prev in raw:
					if prev is Dictionary and str(prev.get("k", "")) in ["bell", "ring"]:
						var pb := float(prev.get("b", -1.0))
						if pb > b - TOL and pb < b + length - TOL:
							out.append("%s: bell inside a stand-still" % at)
							break
	out.append_array(_check_hands(events, 0.25 if difficulty == "expert" else 0.5, where))
	# Report each problem once.
	var seen := {}
	var unique: Array[String] = []
	for p in out:
		if not seen.has(p):
			seen[p] = true
			unique.append(p)
	return unique


static func _check_hands(events: Array, gap: float, where: String) -> Array[String]:
	var out: Array[String] = []
	events.sort_custom(func(x, y): return x[0] < y[0])
	# free[h]: the beat from which hand h (0 = left, 1 = right) may press again.
	var free := [-INF, -INF]
	var i := 0
	while i < events.size():
		# A group of inputs on the same beat: fixed lanes first, then lane 1 and swipes.
		var group := []
		var b: float = events[i][0]
		while i < events.size() and absf(events[i][0] - b) <= TOL:
			group.append(events[i])
			i += 1
		group.sort_custom(func(x, y): return _rank(x) < _rank(y))
		var used := [false, false]
		for e in group:
			var hand := -1
			if e[1] == 0 or e[1] == 2:
				hand = 0 if e[1] == 0 else 1
				if used[hand] or free[hand] > b + TOL:
					hand = -1
			else:
				for h in [0, 1]:
					if not used[h] and free[h] <= b + TOL and (hand == -1 or free[h] < free[hand]):
						hand = h
			if hand == -1:
				out.append("%s b=%s: more inputs than free thumbs (one per %s beat per thumb)" % [where, b, gap])
				continue
			used[hand] = true
			free[hand] = maxf(b + gap, e[2])
	return out


static func _rank(e: Array) -> int:
	return 0 if e[1] == 0 or e[1] == 2 else 1

