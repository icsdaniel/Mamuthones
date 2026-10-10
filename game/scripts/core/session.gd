class_name Session
extends RefCounted
## One play of one chart: judges inputs against the notes and keeps the score (docs/design.md
## section 3). Pure rules: no nodes, sound or sensors, so tests drive it with plain times.
##
## Times are seconds of song time. Call update(t) every frame (it times out missed notes, ends holds
## and stand-stills). Inputs carry their own time stamps, so they may arrive a little after the fact.
##
## Options: slam (the bell from the buttons: see _slam_bell; full rings judged on their step alone;
## no tilt allowance), remix (remix offset), mirror (lanes 0<->2), from_beat/to_beat (only notes in
## [from, to), for tutorial lessons and practice).
##
## Additions beyond the architecture doc: tap() returns a result Dictionary; ring() takes an
## optional `tilt` flag and `strength` (0-1) and returns extra keys (judgement, offset, side,
## strength, note); running_accuracy(),
## mean_offset(), median_offset(), hit_offsets, score_breakdown(), end_time(), progress(t),
## song_key(), ladder_ok(), grade(), grade_rank(), full_combo(), passed(), window(kind), stats keys listed in _init,
## Note.side ("early"/"late"/"" for every judged hit, so a Perfect can still say which side it was).
## Signals wrong_step(lane, note, offset) (the pressed lane of a wrong step) and still_kept(note,
## points) and stomp_landed(note, judgement, offset, both); stats unison_peak (the highest multiplier
## reached), time_at_top (seconds at ×4) and one_thumb (stomps played with one thumb).
##
## Stomps: a note on one lane played with BOTH thumbs on that button, the two touches at most
## STOMP_GAP apart. It is timed from the first touch and scores STOMP_POINTS. With one thumb only it
## is judged when STOMP_GAP runs out, one band lower (Perfect -> Good -> Early/Late), on POINTS.
##
## Health (Rift of the NecroDancer style): `health` starts at MAX_HEALTH; every missed note costs 1
## (a stomp played with one thumb is a weaker hit, not a miss); wrong-lane steps and rings in a
## stand-still cost none. Healing steps (Note.heal, picked at the start from on-beat steps, about one
## every HEAL_EVERY[difficulty] seconds) restore HEAL when hit at Ok or better. At 0 `failed` fires
## once; the rules keep judging, the play screen ends the run. Off (health_on false) in
## lessons and practice (from_beat/to_beat) and with options.health = false (autoplay demos).
##
## Stray taps: a step button pressed with no note of any lane due (outside every window) and none of
## its own lane within WRONG_REACH breaks the combo like a wrong step (combo and streak to 0, unison down STRAY_DROP), with no health cost. Taps
## before the first note's window, after the last note, on slam's bell buttons and a
## late second thumb just after a stomp stay free. Mashing: LOCK_TAPS stray or wrong taps within
## LOCK_SPAN lock the step buttons for LOCK_TIME, but only while the player is pressing more often
## than the chart asks (from the first of those taps, more presses than lane notes due, plus
## LOCK_SPARE): a player who falls behind in a dense passage and taps late, once per note, is
## struggling, not mashing, and is never locked. Taps while locked judge nothing (judgement "locked").
##
## Matching uses note-lock: an input goes to the EARLIEST open note whose window contains it, so a
## late player in a fast stream reads as late instead of drifting onto the next note.

signal judged(note: Note, judgement: String, offset: float)
signal unison_changed(level: int)
signal hold_started(lane: int)
signal hold_ended(lane: int, kept: bool)
## A note was played on time (Perfect or Good) while `hold` was being held: hold and play.
signal played_under(hold: Note, note: Note)
## A tap on `lane` counted as a wrong step against `note` (another lane's note); judged also fires
## for that note. The UI marks the pressed button with this.
signal wrong_step(lane: int, note: Note, offset: float)
## A stand-still was kept to its end (at note.end_t); `points` is what it added.
signal still_kept(note: Note, points: float)
## A stomp was judged: both = true when two thumbs landed within STOMP_GAP, false for one thumb.
## judged fires for it too.
signal stomp_landed(note: Note, judgement: String, offset: float, both: bool)
## A tap hit nothing at all (see Stray taps above); the combo is broken.
signal stray(lane: int)
## Fast random tapping locked the step buttons until song time `until`.
signal input_locked(until: float)
## Health went up or down by delta (health is the new value).
signal health_changed(health: int, delta: int)
## Health ran out (fires once).
signal failed()

# Timing windows in seconds (half-widths). One standard for everyone: the old Village bells' timing
# (Daniele, 2026-10-09, when the bell sets and their score multipliers were removed).
const PERFECT := 0.0405
const GOOD := 0.081
const OK := 0.126
const TILT_EXTRA := 0.015    ## tilts: +15 ms on every window (sensors are looser than touch)
const POINTS := {"perfect": 300, "good": 150, "early": 50, "late": 50}
const RING_POINTS := {"perfect": 450, "good": 225, "early": 75, "late": 75}
const STOMP_POINTS := {"perfect": 450, "good": 225, "early": 75, "late": 75}
## Two touches on a stomp's button this close together are one two-thumb stomp. Real thumbs landing
## "together" spread over 20-60 ms; 80 ms keeps a deliberate double tap (about 150 ms) apart.
const STOMP_GAP := 0.080
const HOLD_BONUS := 150
## Hold and play: each note played on time while a hold is held adds this to the hold's bonus
## (scaled like it), paid when the hold is kept to its end.
const TIE_BONUS := 50
const END_PAD := 2.0        ## a whole song ends this many seconds after its last note (not at the end of the audio)
const HOLD_GRACE := 0.120    ## a hold released up to 120 ms before its end still counts as kept
const STILL_PENALTY := 100
## A stand-still kept to its end: STILL_BONUS × beats × unison. 800 puts stillness at about
## 10 % of a perfect run's score on a typical story song at Hard (measured by test_charts).
const STILL_BONUS := 800
const STILL_HITS := 2        ## and 2 hits per beat toward the next unison level...
const STILL_HITS_MAX := 8    ## ...at most 8
const SILENCE_DEBOUNCE := 0.150  ## rings in a stand-still closer than this count once
const SIDE_DEAD_ZONE := 0.010    ## hits this close to the beat are neither early nor late
const UNISON_MULTS: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
const UNISON_STEP := 12      ## Good-or-better hits in a row per unison level
const MISS_DROP := 2
const WRONG_DROP := 1        ## a wrong step
const WRONG_REACH := 2.0     ## the pressed lane's own note within 2 × Early/Late keeps a tap stray
const SILENCE_DROP := 1
const LET_GO_DROP := 1
const STRAY_DROP := 1        ## a stray tap (no note due anywhere)
const STOMP_FOLLOW := 0.200  ## a tap this soon after a stomp on its lane is a late thumb, not stray
const LOCK_TAPS := 3         ## this many stray or wrong taps...
const LOCK_SPAN := 0.75      ## ...within this many seconds...
const LOCK_TIME := 0.6       ## ...lock the step buttons this long...
const LOCK_SPARE := 1        ## ...when the presses in the span outnumber its lane notes by more than this
const SLAM_GAP := 0.080      ## Left and Right pressed within 80 ms of each other = one slam bell
const MAX_HEALTH := 10
const HEAL := 2              ## health a healing step restores (at Ok or better)
## Seconds between healing steps, by difficulty; none in the first HEAL_GRACE seconds of play.
const HEAL_EVERY := {"easy": 20.0, "medium": 25.0, "hard": 30.0, "expert": 40.0}
const HEAL_GRACE := 8.0
const HEAL_DENSITY_SPAN := 4.0   ## a healing step comes right after the busiest this-many seconds

var song: SongData
var difficulty := ""
var options: Dictionary = {}
var slam := false
var remix := false
var mirror := false
var notes: Array[Note] = []
var health_on := true
var health := MAX_HEALTH
var has_failed := false

var score := 0
var unison_level := 0
## Good-or-better hits in a row since the last unison change (0..11).
var unison_streak := 0
var combo := 0
var max_combo := 0
var stats: Dictionary = {}
## Every input as [t, "tap", lane, touch_id] / [t, "release", touch_id] / [t, "ring", tilt].
var input_log: Array = []
## (time, shown score) after every change of score.
var score_timeline: Array[Vector2] = []
## Signed offsets (s, negative = early) of every judged hit, for the early/late tendency.
var hit_offsets := PackedFloat32Array()

var win_touch := Vector3.ZERO   ## (perfect, good, ok) for steps, holds, stomps and slam/key bells
var win_tilt := Vector3.ZERO    ## same for tilted bells

var _raw := 0.0
var _breakdown := {"base": 0.0, "unison": 0.0, "holds": 0.0, "stills": 0.0, "penalties": 0.0}
var _first_open := 0
var _holds: Dictionary = {}        # touch_id -> Note
var _ring_windows: Dictionary = {} # note index -> Vector3 used by that ring's bell half
var _slam_press: Dictionary = {}   # lane (0 or 2) -> [t, free: bool, used: bool]
var _down: Dictionary = {}         # touch_id -> lane, buttons held right now
var _last_silence := -INF
var _next_free_up := true
var _end_time := 0.0
var _max_window := 0.0
var _top_since := NAN
var _top_time := 0.0
var _locked_until := -INF
var _bad_taps: Array[float] = []   # times of recent stray and wrong taps, for the mashing lock
var _presses: Array[float] = []    # times of recent presses (not while locked), for the same
var _stomp_at: Array[float] = [-INF, -INF, -INF]   # last stomp judged per lane
var _taps_from := NAN   # the first and last moment a lane note is due (NAN: no lane notes)
var _taps_to := NAN


func _init(p_song: SongData, p_difficulty: String, p_options: Dictionary = {}) -> void:
	song = p_song
	difficulty = p_difficulty
	options = p_options
	slam = bool(options.get("slam", false))
	remix = bool(options.get("remix", false)) and song.has_remix()
	mirror = bool(options.get("mirror", false))
	var from_beat := float(options.get("from_beat", -INF))
	var to_beat := float(options.get("to_beat", INF))
	win_touch = Vector3(PERFECT, GOOD, OK)
	# Slam bells are touches, so they get no sensor allowance.
	win_tilt = win_touch if slam else win_touch + Vector3.ONE * TILT_EXTRA
	_max_window = maxf(win_touch.z, win_tilt.z)

	var all := song.notes(difficulty, remix, mirror, from_beat, to_beat)
	for n in all:
		n.index = notes.size()
		notes.append(n)
	_mark_quick()

	stats = {
		"perfect": 0, "good": 0, "early": 0, "late": 0, "miss": 0, "wrong": 0,
		"held": 0, "let_go": 0, "silence": 0, "still_kept": 0, "early_hits": 0, "late_hits": 0,
		"rests": 0, "holds": 0, "notes": 0, "total": 0, "max_unison": 0, "one_thumb": 0,
		"unison_peak": 1.0, "time_at_top": 0.0, "stray": 0, "locks": 0,
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
		if n.uses_lane():
			_taps_from = n.t if is_nan(_taps_from) else minf(_taps_from, n.t)
			_taps_to = n.end_t if is_nan(_taps_to) else maxf(_taps_to, n.end_t)
	if is_finite(to_beat) and not notes.is_empty():
		_end_time = maxf(last_end, song.time_of(to_beat, remix)) + 1.0
	elif is_finite(to_beat) or is_finite(from_beat):
		_end_time = last_end + 1.0
	else:
		# A couple of seconds after the last note, not the whole outro: the play screen fades the music.
		_end_time = maxf(minf(song.length_for(remix), last_end + END_PAD), last_end + 1.0)
	score_timeline.append(Vector2(notes[0].t - 1.0 if not notes.is_empty() else 0.0, 0.0))
	health_on = not options.has("from_beat") and not options.has("to_beat") and bool(options.get("health", true))
	if health_on:
		_pick_heals()


# ---------------------------------------------------------------- health


## Marks the healing steps: the play from HEAL_GRACE s after the first note is cut into windows of
## HEAL_EVERY s, and in each the on-beat plain step (no hold, ring, call or off-beat) right after
## the busiest HEAL_DENSITY_SPAN seconds is the healing one (the earliest on a tie), at least half a
## window after the one before. Deterministic: the same chart always heals on the same notes.
func _pick_heals() -> void:
	if notes.is_empty():
		return
	var every: float = HEAL_EVERY.get(difficulty, 30.0)
	var start := notes[0].t + HEAL_GRACE
	var windows: Dictionary = {}   # window -> [[density, note], ...] in time order
	var lo := 0
	for n in notes:
		if n.kind != Note.Kind.STEP or n.call or n.t < start:
			continue
		if absf(n.beat - roundf(n.beat)) > 0.02:
			continue
		while notes[lo].t < n.t - HEAL_DENSITY_SPAN:
			lo += 1
		var dens := 0
		for i in range(lo, n.index):
			if notes[i].kind != Note.Kind.REST:
				dens += 1
		var w := floori((n.t - start) / every)
		if not windows.has(w):
			windows[w] = []
		windows[w].append([dens, n])
	var keys := windows.keys()
	keys.sort()
	var last := -INF
	for w in keys:
		var pick: Note = null
		var most := -1
		for c in windows[w]:
			var n: Note = c[1]
			if n.t - last >= every * 0.5 and int(c[0]) > most:
				most = int(c[0])
				pick = n
		if pick != null:
			pick.heal = true
			last = pick.t


## The healing steps of this run, in order.
func heal_notes() -> Array[Note]:
	var out: Array[Note] = []
	for n in notes:
		if n.heal:
			out.append(n)
	return out


func _hurt() -> void:
	if not health_on or has_failed:
		return
	health -= 1
	health_changed.emit(health, -1)
	if health <= 0:
		has_failed = true
		failed.emit()


func _heal() -> void:
	if not health_on or has_failed or health >= MAX_HEALTH:
		return
	var d := mini(HEAL, MAX_HEALTH - health)
	health += d
	health_changed.emit(health, d)


# ---------------------------------------------------------------- state


func unison_mult() -> float:
	return UNISON_MULTS[unison_level]


## (Perfect + Good + 0.5 Early/Late) / all judgeable notes of the chart (unplayed count as 0).
## Good counts in full (Daniele, 2026-10-10: a run of only Perfects and Goods, no Ok and no miss, is
## an S+; the old 0.7 for Good felt far too punishing). Perfects still score more points.
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
	return stats.perfect + stats.good + OK_ACC * (stats.early + stats.late)


## Letter grades, worst to best. A run's grade comes from its accuracy (GRADE_MIN, the least accuracy
## for each letter), capped by misses (capped_rank). S+ needs no missed note but may have stray taps
## or Oks (Daniele, 2026-10-09: reachable without a full combo). A full combo
## (no miss, wrong step, stray tap, lost hold or bell rung into a stand-still) is its own mark beside
## the grade. The rank is the index in GRADES (F = 0 .. S+ = 7).
const GRADES: Array[String] = ["F", "E", "D", "C", "B", "A", "S", "S+"]
const OK_ACC := 0.5            ## what an Ok (early/late) counts for in accuracy
const GRADE_MIN: Array[float] = [0.0, 0.60, 0.70, 0.78, 0.85, 0.90, 0.95, 0.98]
const RANK_D := 2
const RANK_B := 4
const RANK_S := 6
const RANK_SPLUS := 7


func grade_rank() -> int:
	return capped_rank(rank_for(accuracy()), lost_notes())


## Notes lost: missed, or lost to a wrong step. A wrong step whose note was still hit after it
## breaks the combo but loses no note (Daniele, 2026-10-10: two such taps capped a 98.9 % run at A).
func lost_notes() -> int:
	var n: int = stats.miss
	for note in notes:
		n += 1 if note.judgement == "wrong" else 0
	return n


## Misses cap the grade whatever the accuracy (Daniele, 2026-10-10: an S with 4 misses was too
## permissive): S+ needs no lost note (see lost_notes), S at most S_MAX_MISSES.
const S_MAX_MISSES := 2


static func capped_rank(rank: int, misses: int) -> int:
	if misses > S_MAX_MISSES:
		return mini(rank, RANK_S - 1)
	if misses > 0:
		return mini(rank, RANK_S)
	return rank


func grade() -> String:
	return GRADES[grade_rank()]


## Nothing broke the combo over the whole chart (every note played).
func full_combo() -> bool:
	return stats.total > 0 and stats.miss == 0 and stats.wrong == 0 and stats.stray == 0 \
			and stats.let_go == 0 and stats.silence == 0


static func rank_for(acc: float) -> int:
	for r in range(GRADES.size() - 1, 0, -1):
		if acc >= GRADE_MIN[r] - 1e-9:
			return r
	return 0


static func grade_name(rank: int) -> String:
	return GRADES[clampi(rank, 0, GRADES.size() - 1)]


## Where the score came from: base points, extra from unison, hold bonuses, kept stand-still
## bonuses and stand-still penalties (positive). total = base + unison + holds + stills - penalties; the score shown is max(0, total), rounded.
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
	return not slam and not options.has("from_beat") and not options.has("to_beat")


## Half-widths (perfect, good, ok) for "touch" or "tilt".
func window(kind: String) -> Vector3:
	if kind == "tilt":
		return win_tilt
	return win_touch


## Whether the step buttons are locked at song time t (fast random tapping).
func is_locked(t: float) -> bool:
	return t < _locked_until


## Seconds the buttons stay locked from t (0 when free), and the song time the lock ends.
func lock_left(t: float) -> float:
	return maxf(0.0, _locked_until - t)


func locked_until() -> float:
	return _locked_until


# ---------------------------------------------------------------- input


## A step button went down. Returns {judgement, note, ring, offset, side, stomp}; judgement is ""
## when the tap hit nothing (a stray tap), "wrong" when it hit the wrong lane, and "" with a note for
## the first half of a full ring or the first thumb of a stomp. The Ok band is reported as its
## direction, "early" or "late". offset (s, signed) and side ("early"/"late", "" within 10 ms)
## describe any timed tap. ring is non-empty when a slam rang the bell. stomp is "first" for a
## stomp's first thumb, "both" when this touch was its second thumb, else "".
func tap(lane: int, t: float, touch_id: int = 0) -> Dictionary:
	input_log.append([t, "tap", lane, touch_id])
	var res := {"judgement": "", "note": null, "ring": {}, "offset": 0.0, "side": "", "stomp": ""}
	_settle_stomps(t)
	if is_locked(t):
		res.judgement = "locked"
		return res
	_presses.append(t)
	while t - _presses[0] > LOCK_SPAN + win_touch.z:
		_presses.pop_front()
	# A touch id still holding a note means its release was lost: that hold was let go.
	if _holds.has(touch_id):
		var old: Note = _holds[touch_id]
		_holds.erase(touch_id)
		if old.holding:
			_end_hold(old, t, t >= old.end_t - HOLD_GRACE)
	var n: Note = _find_lane_note(lane, t, touch_id)
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
			Note.Kind.STOMP:
				if n.thumbs == 0:
					n.thumbs = 1
					n.step_at = t
					n.touch_id = touch_id
					res.stomp = "first"
				else:
					n.thumbs = 2
					_judge_stomp(n)
					res.stomp = "both"
				res.offset = n.step_at - n.t
				res.side = _side(res.offset)
		res.judgement = n.judgement
	elif not (slam and lane != 1):
		# A wrong step only when another lane's note is due AND the pressed lane has no note of its
		# own coming soon: otherwise the tap is stray and free, and the player's note still counts.
		# A tap with neither breaks the combo as a stray (a press a little early for the lane's own
		# coming note is neither).
		var other := _find_other_lane_note(lane, t)
		if _own_note_near(lane, t) != null:
			pass
		elif other != null:
			_wrong(other, t, t - other.t, WRONG_DROP)
			wrong_step.emit(lane, other, t - other.t)
			res.judgement = "wrong"
			res.note = other
			_bad_tap(t)
		elif _stray_counts(lane, t):
			_stray(lane, t)
			res.judgement = "stray"
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
		_break_still(rest, t)
		return {"up": up, "quality": "silence", "judgement": "silence", "offset": 0.0, "side": "", "strength": st, "note": rest}
	var near := _find_bell(t, 2.0 * w.z) != null
	return {"up": up, "quality": "miss" if near else "free", "judgement": "", "offset": 0.0, "side": "", "strength": st, "note": null}


## True when a bell (or the tilt half of a full ring) can still be rung at t.
func bell_due(t: float, tilt: bool = true) -> bool:
	return _find_bell(t, (win_tilt if tilt and not slam else win_touch).z) != null
# Half-beat steps next to a sixteenth (a lane note a quarter beat away) read as part of it.
func _mark_quick() -> void:
	var laned: Array[Note] = []
	for n in notes:
		if n.uses_lane():
			laned.append(n)
	for i in laned.size():
		var n := laned[i]
		if n.kind != Note.Kind.STEP or absf(fposmod(n.beat, 1.0) - 0.5) > 0.02:
			continue
		for j in [i - 1, i + 1]:
			if j >= 0 and j < laned.size() and absf(absf(laned[j].beat - n.beat) - 0.25) < 0.02:
				n.quick = true


## The phone moved (tilted, however gently) at t. Inside a stand-still that breaks it, like a ring:
## the Mamuthone's bells give him away. Returns the stand-still it broke, or null (no stand-still at
## t, or this one already broken: a stand-still is broken once by moving, rings still cost).
func moved(t: float) -> Note:
	var rest := _rest_at(t)
	if rest == null or rest.judgement == "silence":
		return null
	input_log.append([t, "moved"])
	_break_still(rest, t)
	return rest


## The stand-still at t (one is running from its beat to its end), or null.
func rest_at(t: float) -> Note:
	return _rest_at(t)


# Every ring costs, but one shake that rings twice within 150 ms (or moves and then rings) counts once.
func _break_still(rest: Note, t: float) -> void:
	if t - _last_silence >= SILENCE_DEBOUNCE:
		rest.judgement = "silence"
		rest.hit_at = t
		stats.silence += 1
		combo = 0
		unison_streak = 0
		_raw -= STILL_PENALTY
		_breakdown.penalties += STILL_PENALTY
		_set_unison(unison_level - SILENCE_DROP, t)
		_refresh_score(t)
		judged.emit(rest, "silence", t - rest.t)
	_last_silence = t


## Call every frame with the current song time.
func update(t: float) -> void:
	_track_top(t)
	_settle_stomps(t)
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
						var beats := still_beats(n)
						var v := STILL_BONUS * beats * unison_mult()
						_raw += v
						_breakdown.stills += v
						_refresh_score(n.end_t)
						_add_streak(mini(STILL_HITS_MAX, floori(STILL_HITS * beats + 1e-6)), n.end_t)
						still_kept.emit(n, v)
			Note.Kind.HOLD:
				if n.holding:
					if t >= n.end_t:
						_holds.erase(n.touch_id)
						_end_hold(n, n.end_t, true)
				elif not n.done and t > n.t + win_touch.z:
					_miss(n, t)
			Note.Kind.STOMP:
				if not n.done and n.thumbs == 0 and t > n.t + win_touch.z:
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


## How many beats a stand-still lasts.
func still_beats(n: Note) -> float:
	return snappedf((n.end_t - n.t) * song.bpm / 60.0, 0.001)


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


## A tilt is stamped with the moment it crossed the threshold but reaches the rules a frame or a
## few readings later (about 30 ms on Daniele's phone): a bell waits this much longer before it is
## called missed, so a tilt inside its window is never judged after the bell already went.
const TILT_GRACE := 0.06
## How early a tap may still take its lane's next note (as an Ok) when no note is in the window.
const EARLY_REACH := 0.17


func _timeout(n: Note) -> float:
	match n.kind:
		Note.Kind.BELL:
			return win_tilt.z + (0.0 if slam else TILT_GRACE)
		Note.Kind.RING:
			return win_touch.z if slam else maxf(win_touch.z, win_tilt.z) + TILT_GRACE
	return win_touch.z


# An open note of the pressed lane within WRONG_REACH × the Early/Late window of t.
func _own_note_near(lane: int, t: float) -> Note:
	var reach := WRONG_REACH * win_touch.z
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - reach > t:
			break
		if not n.done and n.uses_lane() and n.lane == lane and absf(t - n.t) <= reach:
			return n
	return null


# Note-lock: the earliest open note on the lane whose window contains t. A stomp waiting for its
# second thumb takes only another touch (touch_id) within STOMP_GAP of the first.
func _find_lane_note(lane: int, t: float, touch_id: int = -1) -> Note:
	var n := _lane_note_within(lane, t, touch_id, win_touch.z, win_touch.z)
	if n == null:
		# Nothing in the window: a tap up to EARLY_REACH early still takes its lane's next note, as an
		# Ok. In dense passages (Expert sixteenths, 139 ms apart) Daniele's taps ran early and 17 of
		# them landed 130-160 ms ahead of their note, where they did nothing and the note was then
		# missed (2026-10-10 Carnival Expert run).
		n = _lane_note_within(lane, t, touch_id, EARLY_REACH, 0.0)
	# A tap nearer to a note of this lane that is already taken is a second tap on that one, not an
	# early tap on the next. Taking the next note made every later tap take the note after its own:
	# the notes then vanished before reaching the line, as if the song had sped up (Daniele,
	# 2026-10-10, after anticipating a note). A player running ahead hit the taken note early too, so
	# the next one is expected as early: rushed taps still take their note.
	if n != null and n.t > t:
		var m := _taken_before(lane, n)
		var at := NAN if m == null else (m.step_at if not is_nan(m.step_at) else m.hit_at)
		if not is_nan(at):
			var ahead := minf(at - m.t, 0.0)
			if absf(t - m.t) < absf(t - (n.t + ahead)):
				return null
	return n


# The lane's last taken note before n (null if the one before it is still open or there is none).
func _taken_before(lane: int, n: Note) -> Note:
	var i := n.index - 1
	while i >= 0 and n.t - notes[i].t < 1.0:
		var m := notes[i]
		if m.lane == lane and m.uses_lane():
			return m if m.done else null
		i -= 1
	return null


# The first open note of the lane due between `late` seconds before t and `early` seconds after it.
func _lane_note_within(lane: int, t: float, touch_id: int, early: float, late: float) -> Note:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - early > t:
			break
		if n.done or n.lane != lane or not n.uses_lane() or n.t - t > early or t - n.t > late:
			continue
		if n.kind == Note.Kind.RING and not is_nan(n.step_at):
			continue
		if n.kind == Note.Kind.STOMP and n.thumbs > 0 and (touch_id == n.touch_id or t - n.step_at > STOMP_GAP + 1e-6):
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
		_add_streak(1, t)
	else:
		unison_streak = 0
	judged.emit(n, g, off)
	if (g == "perfect" or g == "good") and n.kind != Note.Kind.HOLD:
		for h: Note in _holds.values():
			if h.holding and h != n:
				h.tied += 1
				played_under.emit(h, n)
	if n.heal:
		_heal()


func _finish_ring(n: Note) -> void:
	# Judged as one note on the later of its two inputs.
	var later_is_bell := n.bell_at >= n.step_at
	var later := n.bell_at if later_is_bell else n.step_at
	var w: Vector3 = _ring_windows.get(n.index, win_tilt) if later_is_bell else win_touch
	var off := later - n.t
	_hit(n, later, _grade(off, w), off, RING_POINTS)


# A stomp is timed from its first thumb: STOMP_POINTS with both thumbs, else one band lower on POINTS.
func _judge_stomp(n: Note) -> void:
	var off := n.step_at - n.t
	var g := _grade(off, win_touch)
	if n.thumbs >= 2:
		_hit(n, n.step_at, g, off, STOMP_POINTS)
	else:
		stats.one_thumb += 1
		if g == "perfect":
			g = "good"
		elif g == "good":
			g = "early" if off < 0.0 else "late"
		_hit(n, n.step_at, g, off, POINTS)
	_stomp_at[clampi(n.lane, 0, 2)] = n.step_at
	stomp_landed.emit(n, g, off, n.thumbs >= 2)


# Stomps whose second thumb did not come within STOMP_GAP of the first, by time t: one-thumb hits.
func _settle_stomps(t: float) -> void:
	for i in range(_first_open, notes.size()):
		var n := notes[i]
		if n.t - win_touch.z > t:
			break
		if n.kind == Note.Kind.STOMP and not n.done and n.thumbs == 1 and t - n.step_at > STOMP_GAP + 1e-6:
			_judge_stomp(n)


func _miss(n: Note, t: float) -> void:
	n.done = true
	n.finished = true
	n.judgement = "miss"
	stats.miss += 1
	stats.notes += 1
	combo = 0
	unison_streak = 0
	_set_unison(unison_level - MISS_DROP, t)
	score_timeline.append(Vector2(t, score))
	judged.emit(n, "miss", t - n.t)
	_hurt()


func _wrong(n: Note, t: float, off: float, drop: int) -> void:
	if n.done:
		n.judgement = "wrong"
	stats.wrong += 1
	combo = 0
	unison_streak = 0
	_set_unison(unison_level - drop, t)
	score_timeline.append(Vector2(t, score))
	judged.emit(n, "wrong", off)


# Whether a tap that hit no note and no other lane's note breaks the combo (see Stray taps).
func _stray_counts(lane: int, t: float) -> bool:
	if slam and lane != 1:
		return false
	if is_nan(_taps_from) or t < _taps_from - win_touch.z or t > _taps_to + win_touch.z:
		return false
	return t - _stomp_at[clampi(lane, 0, 2)] > STOMP_FOLLOW


func _stray(lane: int, t: float) -> void:
	stats.stray += 1
	combo = 0
	unison_streak = 0
	_set_unison(unison_level - STRAY_DROP, t)
	score_timeline.append(Vector2(t, score))
	stray.emit(lane)
	_bad_tap(t)


# A stray or wrong tap: LOCK_TAPS of them within LOCK_SPAN lock the buttons for LOCK_TIME, when the
# presses in that span also outnumber the lane notes due in it (see Mashing above).
func _bad_tap(t: float) -> void:
	_bad_taps.append(t)
	while not _bad_taps.is_empty() and t - _bad_taps[0] > LOCK_SPAN:
		_bad_taps.pop_front()
	if _bad_taps.size() >= LOCK_TAPS and _over_pressing(_bad_taps[0] - win_touch.z, t):
		_bad_taps.clear()
		_locked_until = t + LOCK_TIME
		stats.locks += 1
		input_locked.emit(_locked_until)


# Whether the presses from lo to t outnumber, by more than LOCK_SPARE, the presses the chart asks
# for then: one per lane note due between lo and t + the Early/Late window (a stomp asks for two).
func _over_pressing(lo: float, t: float) -> bool:
	var pressed := 0
	for p in _presses:
		if p >= lo - 1e-6:
			pressed += 1
	var due := 0
	var i := mini(_first_open, notes.size())
	while i > 0 and notes[i - 1].t >= lo:
		i -= 1
	for k in range(i, notes.size()):
		var n := notes[k]
		if n.t > t + win_touch.z:
			break
		if n.t >= lo and n.uses_lane():
			due += 2 if n.kind == Note.Kind.STOMP else 1
	return pressed > due + LOCK_SPARE


func _end_hold(n: Note, t: float, kept: bool) -> void:
	n.holding = false
	n.finished = true
	if kept:
		stats.held += 1
		var v := (HOLD_BONUS + TIE_BONUS * n.tied) * unison_mult()
		_raw += v
		_breakdown.holds += v
		_refresh_score(t)
		judged.emit(n, "held", t - n.end_t)
	else:
		stats.let_go += 1
		combo = 0
		unison_streak = 0
		_set_unison(unison_level - LET_GO_DROP, t)
		judged.emit(n, "let_go", t - n.end_t)
	hold_ended.emit(n.lane, kept)


func _add_points(pts: int, t: float) -> void:
	var m := unison_mult()
	_raw += pts * m
	_breakdown.base += pts
	_breakdown.unison += pts * (m - 1.0)
	_refresh_score(t)


# The running total keeps penalties in full; only the score shown stops at 0.
func _refresh_score(t: float) -> void:
	score = maxi(0, int(round(_raw)))
	score_timeline.append(Vector2(t, score))


# n hits toward the next unison level (a Good-or-better hit is 1, a kept stand-still 4).
func _add_streak(n: int, t: float) -> void:
	unison_streak += n
	if unison_streak >= UNISON_STEP:
		unison_streak -= UNISON_STEP
		_set_unison(unison_level + 1, t)


func _set_unison(level: int, t: float) -> void:
	level = clampi(level, 0, UNISON_MULTS.size() - 1)
	if level == unison_level:
		return
	var top := UNISON_MULTS.size() - 1
	if unison_level == top and not is_nan(_top_since):
		_top_time += maxf(0.0, t - _top_since)
		_top_since = NAN
	if level == top:
		_top_since = t
	unison_level = level
	stats.max_unison = maxi(stats.max_unison, level)
	stats.unison_peak = UNISON_MULTS[stats.max_unison]
	stats.time_at_top = _top_time
	unison_changed.emit(level)


# stats.time_at_top counts the seconds spent at the top level (×4) up to song time t.
func _track_top(t: float) -> void:
	if not is_nan(_top_since):
		stats.time_at_top = _top_time + maxf(0.0, minf(t, end_time()) - _top_since)


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
