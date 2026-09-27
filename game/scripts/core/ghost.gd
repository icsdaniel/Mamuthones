class_name Ghost
extends RefCounted
## Your best run on a song and difficulty, kept as its score over time so the HUD can show whether
## you are ahead of it and the procession can walk it beside you.
##
## Additions beyond the architecture doc: final_score, lead_seconds(score, t), delta_at(t, score),
## is_empty().

const VERSION := 1
const MAX_POINTS := 4000

var times := PackedFloat32Array()
var scores := PackedInt32Array()
var final_score := 0
var _peak := PackedInt32Array()


static func from_session(session: Session) -> Ghost:
	var g := Ghost.new()
	var last := -1
	for p in session.score_timeline:
		var s := int(p.y)
		if s == last:
			continue
		last = s
		g.times.append(p.x)
		g.scores.append(s)
		if g.times.size() >= MAX_POINTS:
			break
	g.final_score = session.score
	return g


static func from_dict(d: Dictionary) -> Ghost:
	var g := Ghost.new()
	var t = d.get("t", [])
	var s = d.get("s", [])
	if (t is Array or t is PackedFloat32Array or t is PackedFloat64Array) and (s is Array or s is PackedInt32Array or s is PackedInt64Array) and t.size() == s.size():
		for i in t.size():
			g.times.append(float(t[i]))
			g.scores.append(int(s[i]))
	g.final_score = int(d.get("final", g.scores[-1] if not g.scores.is_empty() else 0))
	return g


func to_dict() -> Dictionary:
	return {"v": VERSION, "t": Array(times), "s": Array(scores), "final": final_score}


func is_empty() -> bool:
	return times.is_empty()


## The ghost's score at song time t (the last score reached at or before t).
func score_at(t: float) -> int:
	var i := times.bsearch(t, false)   # first index with times[i] > t
	return 0 if i == 0 else scores[i - 1]


## Your score minus the ghost's at time t (positive = ahead).
func delta_at(t: float, score: int) -> int:
	return score - score_at(t)


## How many seconds ahead of the ghost you are: when the ghost reached your current score,
## compared with now. Positive = ahead, negative = behind; clamped to ±limit.
func lead_seconds(score: int, t: float, limit := 3.0) -> float:
	if is_empty():
		return 0.0
	# Scores can dip (stand-still penalties), so search the running maximum instead.
	if _peak.size() != scores.size():
		_peak.resize(scores.size())
		var m := 0
		for k in scores.size():
			m = maxi(m, scores[k])
			_peak[k] = m
	var i := _peak.bsearch(score, true)  # first index where the ghost had reached `score`
	if i >= scores.size():
		return limit
	return clampf(times[i] - t, -limit, limit)
