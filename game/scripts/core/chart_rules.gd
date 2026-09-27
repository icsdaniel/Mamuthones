class_name ChartRules
extends RefCounted
## Checks a chart against the format (docs/architecture.md) and the readability rules
## (docs/design.md section 4). Returns human-readable problems; an empty list means the chart is fine.
##
## The spacing rules mirror tools/audio/validate_charts.py (keep the two in step):
## - Feel: each song section is straight or triplet. A section is triplet when any of the chart's
##   notes in it sits on a third or sixth of a beat; notes outside every section share one feel.
## - Thumbs: lane 0 is the left thumb, lane 2 the right, lane 1 and swipes whichever thumb is free
##   (the one used longest ago). A thumb makes one input per eighth: HAND_GAP beats straight,
##   HAND_GAP_THIRD in a triplet section (where an eighth is a third of a beat). A hold keeps its
##   thumb busy.
## - Any two inputs on different beats are at least OVERALL_GAP (OVERALL_GAP_THIRD) apart; Easy
##   story charts never ask for two inputs closer than 0.6 s.
## - A bell tilts the whole phone, so it uses both thumbs: no input within BELL_CLEAR beats of it
##   (Medium, Hard) or BELL_CLEAR_S seconds (Expert), before or after; a step on the bell's own beat
##   is part of a full or triple ring.

const TOL := 0.001   ## beats (Bonfires sits on thirds rounded to 4 decimals)
const HAND_GAP := {"easy": 1.0, "medium": 0.5, "hard": 0.5, "expert": 0.25}
const HAND_GAP_THIRD := {"easy": 1.0, "medium": 2.0 / 3.0, "hard": 1.0 / 3.0, "expert": 1.0 / 3.0}
const OVERALL_GAP := {"easy": 1.0, "medium": 0.5, "hard": 0.25, "expert": 0.25}
const OVERALL_GAP_THIRD := {"easy": 1.0, "medium": 1.0 / 3.0, "hard": 1.0 / 3.0, "expert": 1.0 / 6.0}
const BELL_CLEAR := {"medium": 0.5, "hard": 0.5}
const BELL_CLEAR_S := {"expert": 0.15}
const EASY_MIN_GAP_S := 0.6
const MIN_STILL_BEATS := 2
const THIRDS: Array[float] = [1.0 / 3.0, 2.0 / 3.0, 1.0 / 6.0, 5.0 / 6.0]
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
	var notes := []   # well-formed notes, for the spacing rules
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
		elif k == "rest" and length < MIN_STILL_BEATS - TOL:
			out.append("%s: a stand-still lasts at least %d beats (design section 3)" % [at, MIN_STILL_BEATS])
		if k == "bell" or k == "ring":
			if b - last_bell < 0.5 - TOL:
				out.append("%s: bells closer than half a beat" % at)
			last_bell = b
			for r in rests:
				if b > r[0] - TOL and b < r[1] - TOL:
					out.append("%s: bell inside a stand-still" % at)
		notes.append({"b": b, "k": k, "lane": lane, "len": length})
		for h in holds:
			if lane == h[0] and b > h[1] + TOL and b < h[2] - TOL and k in ["step", "hold", "ring"]:
				out.append("%s: note hidden under a hold in lane %d" % [at, lane])
		match k:
			"hold":
				holds.append([lane, b, b + length])
			"rest":
				rests.append([b, b + length])
				for prev in raw:
					if prev is Dictionary and str(prev.get("k", "")) in ["bell", "ring"]:
						var pb := float(prev.get("b", -1.0))
						if pb > b - TOL and pb < b + length - TOL:
							out.append("%s: bell inside a stand-still" % at)
							break
	out.append_array(_check_spacing(song, difficulty, notes, where))
	# Report each problem once.
	var seen := {}
	var unique: Array[String] = []
	for p in out:
		if not seen.has(p):
			seen[p] = true
			unique.append(p)
	return unique


static func on_third(b: float) -> bool:
	var f := fposmod(b, 1.0)
	for x in THIRDS:
		if absf(f - x) < 0.01:
			return true
	return false


## For each note of the chart, true when its beat is in a triplet-feel stretch (see the header).
static func triplet_feel(song: SongData, notes: Array) -> Array[bool]:
	var secs := []
	for sec in song.sections:
		if sec is Dictionary and sec.has("b") and sec.has("len"):
			secs.append([float(sec.b), float(sec.b) + float(sec.len)])
	var sec_third := []
	for sp in secs:
		var t := false
		for n in notes:
			if n.b >= sp[0] - TOL and n.b < sp[1] - TOL and on_third(n.b):
				t = true
				break
		sec_third.append(t)
	var out_third := false
	var idx := []
	for n in notes:
		var at := -1
		for j in secs.size():
			if n.b >= secs[j][0] - TOL and n.b < secs[j][1] - TOL:
				at = j
				break
		idx.append(at)
		if at == -1 and on_third(n.b):
			out_third = true
	var feel: Array[bool] = []
	for i in notes.size():
		feel.append(sec_third[idx[i]] if idx[i] >= 0 else out_third)
	return feel


static func _check_spacing(song: SongData, difficulty: String, notes: Array, where: String) -> Array[String]:
	var out: Array[String] = []
	if not HAND_GAP.has(difficulty):
		return out   # piazza: bells only, checked above
	var spb := 60.0 / maxf(song.bpm, 1.0)
	var feel := triplet_feel(song, notes)
	var third_at := {}
	for i in notes.size():
		third_at[snappedf(notes[i].b, 0.001)] = feel[i]
	var easy_min := EASY_MIN_GAP_S / spb - TOL if difficulty == "easy" and song.kind != "tutorial" else 0.0
	var clear: float = BELL_CLEAR_S[difficulty] / spb if BELL_CLEAR_S.has(difficulty) else float(BELL_CLEAR.get(difficulty, 0.0))
	# Overall spacing between distinct beats.
	var beats := []
	for n in notes:
		if n.k != "rest":
			var key := snappedf(n.b, 0.001)
			if beats.is_empty() or absf(beats[-1] - key) > TOL:
				beats.append(key)
	beats.sort()
	for i in range(1, beats.size()):
		var a: float = beats[i - 1]
		var c: float = beats[i]
		var g := maxf(_overall(difficulty, third_at.get(a, false), easy_min), _overall(difficulty, third_at.get(c, false), easy_min))
		if c - a < g - TOL:
			out.append("%s b=%s: inputs %.3f beats apart (min %.3f)" % [where, a, c - a, g])
	# Thumbs, in order of beat (fixed lanes first on a beat).
	var order := range(notes.size())
	order.sort_custom(func(x, y):
		if absf(notes[x].b - notes[y].b) > 1e-9:
			return notes[x].b < notes[y].b
		return _rank(notes[x]) < _rank(notes[y]))
	var last := [-1e9, -1e9]     # 0 = left thumb, 1 = right
	var has_last := [false, false]
	var busy := [-1e9, -1e9]     # a hold keeps its thumb down until this beat
	var last_bell := -1e9
	var used_at := {}
	for i in order:
		var n: Dictionary = notes[i]
		var k: String = n.k
		if k == "rest":
			continue
		var b: float = n.b
		if (k == "bell" or k == "ring") and clear > 0.0:
			for h in 2:
				if has_last[h] and b - last[h] > TOL and b - last[h] < clear - TOL:
					out.append("%s b=%s: input at b=%s too close before the bell (both thumbs tilt the phone)" % [where, b, last[h]])
			last_bell = b
		if k == "bell":
			continue
		if clear > 0.0 and b - last_bell > TOL and b - last_bell < clear - TOL:
			out.append("%s b=%s: input too close after the bell at b=%s (both thumbs tilt the phone)" % [where, b, last_bell])
		var key := snappedf(b, 0.001)
		var taken: Array = used_at.get(key, [])
		var h := -1
		if k == "swipe" or n.lane == 1:
			for c in [0, 1]:
				if c in taken:
					continue
				if h == -1 or _pick_key(busy[c], last[c], b) < _pick_key(busy[h], last[h], b):
					h = c
			if h == -1:
				h = 0
		else:
			h = 0 if n.lane == 0 else 1
		var thumb := "left" if h == 0 else "right"
		if h in taken:
			out.append("%s b=%s: more inputs than free thumbs" % [where, b])
			continue
		var gap: float = (HAND_GAP_THIRD if feel[i] else HAND_GAP)[difficulty]
		if busy[h] > b + TOL:
			out.append("%s b=%s: the %s thumb is holding a note" % [where, b, thumb])
		elif b - last[h] < gap - TOL:
			out.append("%s b=%s: %s thumb too fast (%.3f beats < %.3f, one per %s eighth)" % [where, b, thumb, b - last[h], gap, "triplet" if feel[i] else "straight"])
		last[h] = b
		has_last[h] = true
		taken.append(h)
		used_at[key] = taken
		if k == "hold":
			busy[h] = b + float(n.len)
	return out


static func _overall(difficulty: String, third: bool, easy_min: float) -> float:
	return maxf(float((OVERALL_GAP_THIRD if third else OVERALL_GAP)[difficulty]), easy_min)


# Lane 1 and swipes go to the thumb that is not holding, then to the one used longest ago.
static func _pick_key(busy_until: float, last_b: float, b: float) -> float:
	return (1e6 if busy_until > b + TOL else 0.0) + last_b


static func _rank(n: Dictionary) -> int:
	return {0: 0, 2: 1}.get(n.lane, 2)
