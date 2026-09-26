class_name Session
extends RefCounted
## The rules of one play of one song: judging taps, holds, swipes and bells, and scoring.
## It knows nothing about the screen, sound or sensors, so tests can drive it directly.
## All times are seconds of song time.

## Emitted for every judgement. word is what the player sees ("Perfect", "Miss", "Hey!"...);
## tone is one of: perfect, good, ok, miss, wrong, silence, held, let_go.
signal judged(note: Note, word: String, tone: String)
signal hold_started(lane: int)
signal hold_ended(lane: int)

const PERFECT := 0.045
const GOOD := 0.090
const OK := 0.140
const SWIPE := 0.170
const HOLD_RELEASE_GRACE := 0.120  ## a hold counts as kept if let go this close to its end
const REST_PENALTY := 100
const HOLD_BONUS := 150

var song: Dictionary
var notes: Array[Note] = []
var end_t := 0.0
var score := 0
var combo := 0
var max_combo := 0
var stats := {
	perfect = 0, good = 0, ok = 0, miss = 0, wrong = 0, silence = 0,
	holds = 0, kept = 0, tap_offsets = [], bell_offsets = [],
}
var _held := {}  ## touch id -> the hold note it is holding


func _init(p_song: Dictionary) -> void:
	song = p_song
	notes = Chart.parse(song)
	end_t = float(song.first_beat) + Chart.length_seconds(song) + 0.6


## The unison multiplier: it grows every 8 clean hits, up to x3.
func mult() -> float:
	return minf(3.0, 1.0 + floori(combo / 8.0) * 0.5)


func hittable_count() -> int:
	return notes.filter(func(n: Note): return n.kind != Note.Kind.REST).size()


func hold_count() -> int:
	return notes.filter(func(n: Note): return n.kind == Note.Kind.HOLD).size()


func accuracy() -> float:
	var total := hittable_count()
	if total == 0:
		return 0.0
	return (stats.perfect + stats.good * 0.7 + stats.ok * 0.3) / float(total)


func is_over(t: float) -> bool:
	return t > end_t


## A step button was pressed. touch_id lets a hold follow the finger that started it.
func tap(lane: int, t: float, touch_id := 0) -> void:
	var found := _nearest(t, func(n: Note): return n.kind == Note.Kind.STEP or n.kind == Note.Kind.HOLD)
	if found.is_empty():
		return
	var n: Note = found[0]
	var ok := _hit(n, found[1], "" if n.lane == lane else "Wrong step")
	if ok and n.kind == Note.Kind.HOLD:
		stats.holds += 1
		n.holding = true
		_held[touch_id] = n
		hold_started.emit(n.lane)


func release(t: float, touch_id := 0) -> void:
	var n: Note = _held.get(touch_id)
	if n == null:
		return
	_held.erase(touch_id)
	if n.holding:
		_end_hold(n, t >= n.end_t - HOLD_RELEASE_GRACE)


func swipe(to_right: bool, t: float) -> void:
	var found := _nearest(t, func(n: Note): return n.kind == Note.Kind.SWIPE, SWIPE)
	if found.is_empty():
		return
	var n: Note = found[0]
	_hit(n, found[1], "" if n.right == to_right else "Wrong way")


## The bell rang (the phone was tilted). Bells alternate, so only the timing is judged.
## Returns whether the ring should sound as an up bell.
func ring(t: float) -> bool:
	var rest := _nearest(t, func(n: Note): return n.kind == Note.Kind.REST)
	var bell := _nearest(t, func(n: Note): return n.kind == Note.Kind.BELL)
	if not bell.is_empty() and (rest.is_empty() or absf(bell[0].t - t) <= absf(rest[0].t - t)):
		_hit(bell[0], bell[1], "")
		return bell[0].up
	if not rest.is_empty():
		var r: Note = rest[0]
		r.done = true
		stats.silence += 1
		combo = 0
		score = maxi(0, score - REST_PENALTY)
		judged.emit(r, "Silence!", "silence")
	return _next_bell_up(t)


## Call every frame: ends holds that ran their full length and misses notes that went by.
func update(t: float) -> void:
	for n in notes:
		if n.holding and t >= n.end_t:
			for id in _held.keys():
				if _held[id] == n:
					_held.erase(id)
			_end_hold(n, true)
		if n.done:
			continue
		var win := SWIPE if n.kind == Note.Kind.SWIPE else OK
		if t - n.t > win:
			n.done = true
			if n.kind == Note.Kind.REST:
				continue  # stood still: fine
			stats.miss += 1
			combo = 0
			if n.kind == Note.Kind.HOLD:
				n.finished = true
			judged.emit(n, "Miss", "miss")


## Which lanes have a note about to land (or a hold being held), for glowing the buttons.
func cued_lanes(t: float, ahead := 0.16) -> Array[bool]:
	var cue: Array[bool] = [false, false, false]
	for n in notes:
		if n.t - t > ahead:
			break
		if n.lane >= 0 and (not n.done or n.holding):
			cue[n.lane] = true
	return cue


func _next_bell_up(t: float) -> bool:
	for n in notes:
		if n.kind == Note.Kind.BELL and n.t >= t:
			return n.up
	return true


## The closest unjudged note that passes test, within win seconds. Returns [note, offset] or [].
func _nearest(t: float, test: Callable, win := OK) -> Array:
	var best: Note = null
	var d := INF
	for n in notes:
		if n.t - t > win:
			break
		if n.done or not test.call(n):
			continue
		var off := t - n.t
		if absf(off) < absf(d):
			best = n
			d = off
	if best != null and absf(d) <= win:
		return [best, d]
	return []


func _hit(n: Note, off: float, wrong: String) -> bool:
	n.done = true
	if wrong != "":
		stats.wrong += 1
		combo = 0
		judged.emit(n, wrong, "wrong")
		return false
	var a := absf(off)
	var pts: int
	var word: String
	var tone: String
	if a <= PERFECT:
		pts = 300; word = "Perfect"; tone = "perfect"; stats.perfect += 1
	elif a <= GOOD:
		pts = 150; word = "Good"; tone = "good"; stats.good += 1
	else:
		pts = 50; word = "Early" if off < 0 else "Late"; tone = "ok"; stats.ok += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	score += roundi(pts * mult())
	(stats.bell_offsets if n.kind == Note.Kind.BELL else stats.tap_offsets).append(off)
	n.flash_at = n.t + off
	if n.call and word == "Perfect":
		word = "Hey!"
	judged.emit(n, word, tone)
	return true


func _end_hold(n: Note, kept: bool) -> void:
	n.holding = false
	n.finished = true
	hold_ended.emit(n.lane)
	if kept:
		stats.kept += 1
		combo += 1
		max_combo = maxi(max_combo, combo)
		score += roundi(HOLD_BONUS * mult())
		judged.emit(n, "Held", "held")
	else:
		combo = 0
		judged.emit(n, "Let go", "let_go")
