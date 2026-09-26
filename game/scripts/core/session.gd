class_name Session
extends RefCounted
## One play of one chart: judges inputs against the notes and keeps the score (docs/design.md
## section 3). Pure rules: no nodes, sound or sensors, so tests drive it with plain times.
##
## Times are seconds of song time. Call update(t) every frame (it times out missed notes, ends holds
## and stand-stills). Inputs carry their own time stamps, so they may arrive a little after the fact.
##
## Options: slam (the bell from the buttons: see _slam_bell; full rings judged on their step alone;
## no tilt allowance), piazza (bells only, ±200 ms),
## remix (remix offset), mirror (lanes 0<->2 and swipes flipped), from_beat/to_beat (only notes in
## [from, to), for tutorial lessons and practice), daily ("YYYY-MM-DD", recorded on the daily ladder).
##
## Additions beyond the architecture doc: tap()/swipe() return a result Dictionary; ring() takes an
## optional `tilt` flag and `strength` (0-1) and returns extra keys (judgement, offset, side,
## strength, note); running_accuracy(),
## mean_offset(), median_offset(), hit_offsets, score_breakdown(), end_time(), progress(t),
## song_key(), ladder_ok(), passed(), upcoming_bell(t), window(kind), stats keys listed in _init,
## Note.side ("early"/"late"/"" for every judged hit, so a Perfect can still say which side it was).
##
## Matching uses note-lock: an input goes to the EARLIEST open note whose window contains it, so a
## late player in a fast stream reads as late instead of drifting onto the next note.

signal judged(note: Note, judgement: String, offset: float)
signal unison_changed(level: int)
signal hold_started(lane: int)
signal hold_ended(lane: int, kept: bool)

# Timing windows for the Light set, in seconds (half-widths).
const PERFECT := 0.045
const GOOD := 0.090
const OK := 0.140
const SWIPE_OK := 0.170      ## swipes: all three windows stretched so the outer one is ±170 ms
const TILT_EXTRA := 0.015    ## tilts: +15 ms on every window (sensors are looser than touch)
const PIAZZA_OK := 0.200     ## Piazza: all windows stretched so the outer one is ±200 ms
const POINTS := {"perfect": 300, "good": 150, "early": 50, "late": 50}
const RING_POINTS := {"perfect": 450, "good": 225, "early": 75, "late": 75}
const HOLD_BONUS := 150
const HOLD_GRACE := 0.120    ## a hold released up to 120 ms before its end still counts as kept
const STILL_PENALTY := 100
const STILL_BONUS := 50      ## a stand-still kept to its end: 50 × unison × weight
const SILENCE_DEBOUNCE := 0.150  ## rings in a stand-still closer than this count once
const SIDE_DEAD_ZONE := 0.010    ## hits this close to the beat are neither early nor late
const UNISON_MULTS: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
const UNISON_STEP := 12      ## Good-or-better hits in a row per unison level
const MISS_DROP := 2
const SILENCE_DROP := 1
const LET_GO_DROP := 1
const SLAM_GAP := 0.080      ## Left and Right pressed within 80 ms of each other = one slam bell

var song: SongData
var difficulty := ""
var bell_set := "light"
var options: Dictionary = {}
var slam := false
var piazza := false
var remix := false
var mirror := false
var daily := ""
var notes: Array[Note] = []

var score := 0
var unison_level := 0
## Good-or-better hits in a row since the last unison change (0..11).
var unison_streak := 0
var combo := 0
var max_combo := 0
var stats: Dictionary = {}
## Every input as [t, "tap", lane, touch_id] / [t, "release", touch_id] / [t, "swipe", dir] / [t, "ring", tilt].
var input_log: Array = []
## (time, shown score) after every change of score.
var score_timeline: Array[Vector2] = []
## Signed offsets (s, negative = early) of every judged hit, for the early/late tendency.
var hit_offsets := PackedFloat32Array()

var win_touch := Vector3.ZERO   ## (perfect, good, ok) for steps, holds and slam/key bells
var win_tilt := Vector3.ZERO    ## same for tilted bells
var win_swipe := Vector3.ZERO

var _raw := 0.0
var _breakdown := {"base": 0.0, "unison": 0.0, "weight": 0.0, "holds": 0.0, "stills": 0.0, "penalties": 0.0}
var _weight := 1.0
var _first_open := 0
var _holds: Dictionary = {}        # touch_id -> Note
var _ring_windows: Dictionary = {} # note index -> Vector3 used by that ring's bell half
var _slam_press: Dictionary = {}   # lane (0 or 2) -> [t, free: bool, used: bool]
var _down: Dictionary = {}         # touch_id -> lane, buttons held right now
var _last_silence := -INF
var _next_free_up := true
var _end_time := 0.0
var _max_window := 0.0


func _init(p_song: SongData, p_difficulty: String, p_bell_set: String = "light", p_options: Dictionary = {}) -> void:
	song = p_song
	difficulty = p_difficulty
	bell_set = p_bell_set if BellSets.is_valid(p_bell_set) else "light"
	options = p_options
	slam = bool(options.get("slam", false))
	piazza = bool(options.get("piazza", false))
	remix = bool(options.get("remix", false)) and song.has_remix()
	mirror = bool(options.get("mirror", false))
	daily = str(options.get("daily", ""))
	var from_beat := float(options.get("from_beat", -INF))
	var to_beat := float(options.get("to_beat", INF))
	_weight = BellSets.weight(bell_set)
	var base := Vector3(PERFECT, GOOD, OK)
	if piazza:
		# Loose timing whatever the bell set: the whole body is moving.
		win_touch = base * (PIAZZA_OK / OK)
		win_tilt = win_touch
		win_swipe = win_touch
	else:
		var scale := BellSets.window_scale(bell_set)
		win_touch = base * scale
		# Slam bells are touches, so they get no sensor allowance.
		win_tilt = win_touch if slam else win_touch + Vector3.ONE * TILT_EXTRA
		win_swipe = base * (SWIPE_OK / OK) * scale
	_max_window = maxf(win_touch.z, maxf(win_tilt.z, win_swipe.z))

	var all := song.notes(difficulty, remix, mirror, from_beat, to_beat)
	for n in all:
		if piazza:
			# Only tilts count: rings become plain bells, taps and swipes are dropped.
			if n.kind == Note.Kind.RING:
				n.kind = Note.Kind.BELL
				n.lane = -1
			if n.kind != Note.Kind.BELL and n.kind != Note.Kind.REST:
				continue
		n.index = notes.size()
		notes.append(n)

	stats = {
		"perfect": 0, "good": 0, "early": 0, "late": 0, "miss": 0, "wrong": 0,
		"held": 0, "let_go": 0, "silence": 0, "still_kept": 0, "early_hits": 0, "late_hits": 0,
		"rests": 0, "holds": 0, "notes": 0, "total": 0, "max_unison": 0,
	}
	var last_end := 0.0
	for n in notes:
		last_end = maxf(last_end, n.end_t)
		if n.kind == Note.Kind.REST:
			stats.rests += 1
		else:
			stats.total += 1
		if n.kind == Note.Kind.HOLD:
			stats.holds += 1
	if is_finite(to_beat) and not notes.is_empty():
		_end_time = maxf(last_end, song.time_of(to_beat, remix)) + 1.0
	elif is_finite(to_beat) or is_finite(from_beat):
		_end_time = last_end + 1.0
	else:
		_end_time = maxf(song.length_for(remix), last_end + 1.0)
	score_timeline.append(Vector2(notes[0].t - 1.0 if not notes.is_empty() else 0.0, 0.0))


# ---------------------------------------------------------------- state


func unison_mult() -> float:
	return UNISON_MULTS[unison_level]


func weight() -> float:
	return _weight


## (Perfect + 0.7 Good + 0.3 Early/Late) / all judgeable notes of the chart (unplayed count as 0).
func accuracy() -> float:
	if stats.total == 0:
		return 0.0
	return _acc_sum() / float(stats.total)


## Same formula over the notes judged so far, for a live HUD.
func running_accuracy() -> float:
	if stats.notes == 0:
		return 1.0
	return _acc_sum() / float(stats.notes)


func _acc_sum() -> float:
	return stats.perfect + 0.7 * stats.good + 0.3 * (stats.early + stats.late)


## Bell rating 0..3 (≥ 70 %, ≥ 85 %, ≥ 95 %).
func bells() -> int:
	return bells_for(accuracy())


static func bells_for(acc: float) -> int:
	if acc >= 0.95 - 1e-9:
		return 3
	if acc >= 0.85 - 1e-9:
		return 2
	if acc >= 0.70 - 1e-9:
		return 1
	return 0


## Where the score came from: base points, extra from unison, extra from weight, hold bonuses,
## kept stand-still bonuses and stand-still penalties (positive). total = base + unison + weight +
## holds + stills - penalties; the score shown is max(0, total), rounded.
func score_breakdown() -> Dictionary:
	var d := _breakdown.duplicate()
	d.total = _raw
	d.shown = score
	return d


func mean_offset() -> float:
	if hit_offsets.is_empty():
		return 0.0
	var s := 0.0
	for o in hit_offsets:
		s += o
	return s / hit_offsets.size()


func median_offset() -> float:
	if hit_offsets.is_empty():
		return 0.0
	var a := hit_offsets.duplicate()
	a.sort()
	var m := a.size() >> 1
	return a[m] if a.size() % 2 == 1 else (a[m - 1] + a[m]) * 0.5


func end_time() -> float:
	return _end_time


func is_over(t: float) -> bool:
	return t >= _end_time


func progress(t: float) -> float:
	if notes.is_empty() or _end_time <= notes[0].t:
		return 0.0
	return clampf((t - notes[0].t) / (_end_time - notes[0].t), 0.0, 1.0)


## Whether a run (a tutorial lesson, say) is good enough to move on: accuracy at least
## min_accuracy and no bell rung into a stand-still.
func passed(min_accuracy := 0.7) -> bool:
	return accuracy() >= min_accuracy - 1e-9 and stats.silence == 0


## Key for bests and ghosts: the remix is its own track.
func song_key() -> String:
	return song.remix_id() if remix else song.id


## Whether a run of this session may go on the global ladder.
func ladder_ok() -> bool:
	return not slam and not piazza and not options.has("from_beat") and not options.has("to_beat")


## Half-widths (perfect, good, ok) for "touch", "tilt" or "swipe".
func window(kind: String) -> Vector3:
	match kind:
		"tilt":
			return win_tilt
		"swipe":
			return win_swipe
	return win_touch


## The next bell (or full ring) still to play at or after t - its window, or null. For the big
## Piazza cue and the up/down arrow.
func upcoming_bell(t: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.is_bell() and not n.done and n.t + win_tilt.z >= t:
			return n
	return null


# ---------------------------------------------------------------- input


## A step button went down. Returns {judgement, note, ring, offset, side}; judgement is "" when the
## tap hit nothing (a stray tap), "wrong" when it hit the wrong lane, and "" with a note for the
## first half of a full ring. The Ok band is reported as its direction, "early" or "late". offset
## (s, signed) and side ("early"/"late", "" within 10 ms) describe any timed tap. ring is non-empty
## when a slam rang the bell.
func tap(lane: int, t: float, touch_id: int = 0) -> Dictionary:
	input_log.append([t, "tap", lane, touch_id])
	var res := {"judgement": "", "note": null, "ring": {}, "offset": 0.0, "side": ""}
	# A touch id still holding a note means its release was lost: that hold was let go.
	if _holds.has(touch_id):
		var old: Note = _holds[touch_id]
		_holds.erase(touch_id)
		if old.holding:
			_end_hold(old, t, t >= old.end_t - HOLD_GRACE)
	var n: Note = null if piazza else _find_lane_note(lane, t)
	if n != null and slam and lane != 1 and _bell_nearer(n, t):
		n = null   # in slam an outer press nearer a due bell is a bell press
	if n != null:
		res.note = n
		var off := t - n.t
		res.offset = off
		res.side = _side(off)
		match n.kind:
			Note.Kind.STEP:
				_hit(n, t, _grade(off, win_touch), off, POINTS)
			Note.Kind.HOLD:
				_hit(n, t, _grade(off, win_touch), off, POINTS)
				n.holding = true
				n.touch_id = touch_id
				_holds[touch_id] = n
				hold_started.emit(n.lane)
			Note.Kind.RING:
				if slam:
					# No tilt in slam mode: a full ring is judged on its step alone.
					_hit(n, t, _grade(off, win_touch), off, RING_POINTS)
				else:
					n.step_at = t
					if not is_nan(n.bell_at):
						_finish_ring(n)
		res.judgement = n.judgement
	elif not piazza and not (slam and lane != 1) and _find_open(Note.Kind.SWIPE, t, win_swipe.z) == null:
		# The touch that starts a rope swipe is not a wrong step.
		var other := _find_other_lane_note(lane, t)
		if other != null:
			_wrong(other, t, t - other.t)
			res.judgement = "wrong"
			res.note = other
	if slam and (lane == 0 or lane == 2):
		res.ring = _slam_bell(lane, t, touch_id, n == null)
	if slam:
		_down[touch_id] = lane
	return res


## A step button went up.
func release(t: float, touch_id: int = 0) -> void:
	input_log.append([t, "release", touch_id])
	_down.erase(touch_id)
	if not _holds.has(touch_id):
		return
	var n: Note = _holds[touch_id]
	_holds.erase(touch_id)
	if n.holding:
		_end_hold(n, t, t >= n.end_t - HOLD_GRACE)


## A rope swipe across the buttons, dir 1 = to the right, t = when the finger went down.
## Returns {judgement, note, offset, side} (as tap).
func swipe(dir: int, t: float) -> Dictionary:
	input_log.append([t, "swipe", dir])
	var res := {"judgement": "", "note": null, "offset": 0.0, "side": ""}
	if piazza:
		return res
	var n := _find_open(Note.Kind.SWIPE, t, win_swipe.z)
	if n == null:
		return res
	res.note = n
	var off := t - n.t
	res.offset = off
	res.side = _side(off)
	if (1 if dir >= 0 else -1) != n.dir:
		n.done = true
		n.finished = true
		n.hit_at = t
		stats.notes += 1
		_wrong(n, t, off)
	else:
		_hit(n, t, _grade(off, win_swipe), off, POINTS)
	res.judgement = n.judgement
	return res


## The bell rang (a tilt, or with tilt = false a slam or the keyboard). Returns
## {up, quality, judgement, offset, side, note}; quality is perfect|good|early|late|miss|silence|free
## so the bell sound can match: early/late = the Ok band with its direction (the clank is pitched
## up or down), miss = close to a bell but outside its window, silence = during a stand-still,
## free = no bell expected. side is "early"/"late" for any timed hit off by more than 10 ms, else "".
## strength (0-1, how hard the flick was, for Sound.bell) is the detector's value for a tilt and
## 0.5 for a slam or keyboard ring.
func ring(t: float, tilt: bool = true, strength: float = 0.5) -> Dictionary:
	input_log.append([t, "ring", tilt])
	var st := clampf(strength, 0.0, 1.0) if tilt and not slam else 0.5
	if slam:
		tilt = false
	var w := win_tilt if tilt else win_touch
	var best := _find_bell(t, w.z)
	if best != null:
		var off := t - best.t
		var g := _grade(off, w)
		_next_free_up = not best.up
		if best.kind == Note.Kind.BELL:
			_hit(best, t, g, off, POINTS)
		else:
			best.bell_at = t
			_ring_windows[best.index] = w
			if not is_nan(best.step_at):
				_finish_ring(best)
		# judgement stays "" for a full ring still waiting for its step half.
		return {"up": best.up, "quality": _quality(g), "judgement": best.judgement, "offset": off,
				"side": _side(off), "strength": st, "note": best}
	var up := _next_free_up
	_next_free_up = not up
	var rest := _rest_at(t)
	if rest != null:
		# Every ring costs, but one shake that rings twice within 150 ms counts once.
		if t - _last_silence >= SILENCE_DEBOUNCE:
			rest.judgement = "silence"
			rest.hit_at = t
			stats.silence += 1
			combo = 0
			unison_streak = 0
			_raw -= STILL_PENALTY
			_breakdown.penalties += STILL_PENALTY
			_set_unison(unison_level - SILENCE_DROP)
			_refresh_score(t)
			judged.emit(rest, "silence", t - rest.t)
		_last_silence = t
		return {"up": up, "quality": "silence", "judgement": "silence", "offset": 0.0, "side": "", "strength": st, "note": rest}
	var near := _find_bell(t, 2.0 * w.z) != null
	return {"up": up, "quality": "miss" if near else "free", "judgement": "", "offset": 0.0, "side": "", "strength": st, "note": null}


## Call every frame with the current song time.
func update(t: float) -> void:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t > t:
			break
		if n.finished:
			continue
		match n.kind:
			Note.Kind.REST:
				if t > n.end_t:
					n.finished = true
					if n.judgement != "silence":
						n.judgement = "still"
						stats.still_kept += 1
						var v := STILL_BONUS * unison_mult() * _weight
						_raw += v
						_breakdown.stills += v
						_refresh_score(n.end_t)
			Note.Kind.HOLD:
				if n.holding:
					if t >= n.end_t:
						_holds.erase(n.touch_id)
						_end_hold(n, n.end_t, true)
				elif not n.done and t > n.t + win_touch.z:
					_miss(n, t)
			_:
				if not n.done and t > n.t + _timeout(n):
					_miss(n, t)
	while _first_open < notes.size() and notes[_first_open].finished:
		_first_open += 1


# ---------------------------------------------------------------- rules


func _grade(off: float, w: Vector3) -> String:
	var a := absf(off)
	if a <= w.x + 1e-6:
		return "perfect"
	if a <= w.y + 1e-6:
		return "good"
	return "early" if off < 0.0 else "late"


static func _side(off: float) -> String:
	if absf(off) <= SIDE_DEAD_ZONE:
		return ""
	return "early" if off < 0.0 else "late"


static func _quality(judgement: String) -> String:
	match judgement:
		"perfect", "good":
			return judgement
		"early", "late":
			return judgement   # the Ok band, with its direction: Sound pitches the clank up or down
	return "miss"


func _timeout(n: Note) -> float:
	match n.kind:
		Note.Kind.BELL:
			return win_tilt.z
		Note.Kind.RING:
			return win_touch.z if slam else maxf(win_touch.z, win_tilt.z)
		Note.Kind.SWIPE:
			return win_swipe.z
	return win_touch.z


# Note-lock: the earliest open note on the lane whose window contains t.
func _find_lane_note(lane: int, t: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - win_touch.z > t:
			break
		if n.done or n.lane != lane or not n.uses_lane() or absf(t - n.t) > win_touch.z:
			continue
		if n.kind == Note.Kind.RING and not is_nan(n.step_at):
			continue
		return n
	return null


# The earliest open bell (or full ring still missing its bell half) within `reach` of t.
# In slam mode full rings take no bell.
func _find_bell(t: float, reach: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - reach > t:
			break
		if n.done or not n.is_bell() or absf(t - n.t) > reach:
			continue
		if n.kind == Note.Kind.RING and (slam or not is_nan(n.bell_at)):
			continue
		return n
	return null


func _find_open(kind: Note.Kind, t: float, reach: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - reach > t:
			break
		if n.kind == kind and not n.done and absf(t - n.t) <= reach:
			return n
	return null


func _find_other_lane_note(lane: int, t: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - win_touch.z > t:
			break
		if not n.done and n.uses_lane() and n.lane != lane and absf(t - n.t) <= win_touch.z:
			return n
	return null


# Slam: is a due bell closer to t than lane note n?
func _bell_nearer(n: Note, t: float) -> bool:
	var b := _find_bell(t, win_touch.z)
	return b != null and absf(t - b.t) < absf(t - n.t)


func _rest_at(t: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t > t:
			break
		if n.kind == Note.Kind.REST and t <= n.end_t:
			return n
	return null


func _hit(n: Note, t: float, g: String, off: float, table: Dictionary) -> void:
	n.done = true
	n.hit_at = t
	n.judgement = g
	n.side = _side(off)
	if n.kind != Note.Kind.HOLD:
		n.finished = true
	stats[g] += 1
	stats.notes += 1
	if n.side == "early":
		stats.early_hits += 1
	elif n.side == "late":
		stats.late_hits += 1
	hit_offsets.append(off)
	_add_points(table[g], t)
	combo += 1
	max_combo = maxi(max_combo, combo)
	if g == "perfect" or g == "good":
		unison_streak += 1
		if unison_streak >= UNISON_STEP:
			unison_streak = 0
			_set_unison(unison_level + 1)
	else:
		unison_streak = 0
	judged.emit(n, g, off)


func _finish_ring(n: Note) -> void:
	# Judged as one note on the later of its two inputs.
	var later_is_bell := n.bell_at >= n.step_at
	var later := n.bell_at if later_is_bell else n.step_at
	var w: Vector3 = _ring_windows.get(n.index, win_tilt) if later_is_bell else win_touch
	var off := later - n.t
	_hit(n, later, _grade(off, w), off, RING_POINTS)


func _miss(n: Note, t: float) -> void:
	n.done = true
	n.finished = true
	n.judgement = "miss"
	stats.miss += 1
	stats.notes += 1
	combo = 0
	unison_streak = 0
	_set_unison(unison_level - MISS_DROP)
	score_timeline.append(Vector2(t, score))
	judged.emit(n, "miss", t - n.t)


func _wrong(n: Note, t: float, off: float) -> void:
	if n.done:
		n.judgement = "wrong"
	stats.wrong += 1
	combo = 0
	unison_streak = 0
	_set_unison(unison_level - MISS_DROP)
	score_timeline.append(Vector2(t, score))
	judged.emit(n, "wrong", off)


func _end_hold(n: Note, t: float, kept: bool) -> void:
	n.holding = false
	n.finished = true
	if kept:
		stats.held += 1
		var v := HOLD_BONUS * unison_mult() * _weight
		_raw += v
		_breakdown.holds += v
		_refresh_score(t)
		judged.emit(n, "held", t - n.end_t)
	else:
		stats.let_go += 1
		combo = 0
		unison_streak = 0
		_set_unison(unison_level - LET_GO_DROP)
		judged.emit(n, "let_go", t - n.end_t)
	hold_ended.emit(n.lane, kept)


func _add_points(pts: int, t: float) -> void:
	var m := unison_mult()
	_raw += pts * m * _weight
	_breakdown.base += pts
	_breakdown.unison += pts * (m - 1.0)
	_breakdown.weight += pts * m * (_weight - 1.0)
	_refresh_score(t)


# The running total keeps penalties in full; only the score shown stops at 0.
func _refresh_score(t: float) -> void:
	score = maxi(0, int(round(_raw)))
	score_timeline.append(Vector2(t, score))


func _set_unison(level: int) -> void:
	level = clampi(level, 0, UNISON_MULTS.size() - 1)
	if level == unison_level:
		return
	unison_level = level
	stats.max_unison = maxi(stats.max_unison, level)
	unison_changed.emit(level)


# Slam: the bell comes from the outer buttons. A press on Left or Right that hits no note rings
# (a) at the mean time when the other outer button went down within 80 ms (a pair where both
# presses hit notes is a chord, not a bell), or (b) at once when another button is already held,
# so one thumb can keep a hold while the other rings.
func _slam_bell(lane: int, t: float, touch_id: int, free: bool) -> Dictionary:
	var other := 2 - lane
	var p: Array = _slam_press.get(other, [])
	if not p.is_empty() and not p[2] and t - p[0] <= SLAM_GAP and (free or p[1]):
		p[2] = true
		_slam_press[lane] = [t, free, true]
		return ring((t + p[0]) * 0.5, false)
	if free:
		for id in _down:
			if id != touch_id:
				_slam_press[lane] = [t, free, true]
				return ring(t, false)
	_slam_press[lane] = [t, free, false]
	return {}
