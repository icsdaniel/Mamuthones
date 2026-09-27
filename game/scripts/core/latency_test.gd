class_name LatencyTest
extends RefCounted
## The audio-delay tap test: the player taps along to clicks; the median of (tap - click) is how
## late sound reaches their ears (plus their own habit), and becomes the audio offset.
##
## Use one clock for both: click times as song times of the clicks in the audio, tap times as
## Conductor.song_time() when the tap arrived. If the Conductor already applied an offset during
## the test, add result().offset to that offset.

const BPM := 70.0            ## test tempo: a click every 0.857 s, so a ±0.5 s delay stays readable
const MAX_PAIR := 0.5        ## a tap further than this from any click is ignored (Profile's range)
const CLUSTER := 0.06        ## taps within this of each other's delay agree
const SEARCH := 0.6          ## taps are looked for this far from a click, so noisy taps at the edge
                             ## of the range still count; the offset itself is clamped to MAX_PAIR
const MIN_TAPS := 6
const MAX_SPREAD := 0.05     ## seconds; above this the taps were too uneven to trust (touch screens
                             ## report taps a frame late at random, so allow for 16 ms of that)

var clicks := PackedFloat64Array()
var taps := PackedFloat64Array()


static func click_times(bpm: float, count: int, start := 0.0) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for i in count:
		out.append(start + i * 60.0 / bpm)
	return out


static func measure(p_clicks: PackedFloat64Array, p_taps: PackedFloat64Array) -> Dictionary:
	var lt := LatencyTest.new()
	lt.clicks = p_clicks
	lt.taps = p_taps
	return lt.result()


func clear() -> void:
	clicks.clear()
	taps.clear()


func add_click(t: float) -> void:
	clicks.append(t)


func add_tap(t: float) -> void:
	taps.append(t)


## Signed tap - click for each tap near a click (each click used once).
## With a ±0.5 s range and clicks 0.857 s apart a tap can be near two clicks, so the delay is chosen
## for all taps together first: the delay the most taps agree with (ties go to the later one, as
## sound reaches the ear late, not early), then each tap is paired with the click that fits it.
func offsets() -> PackedFloat64Array:
	var cands := []   # per tap: its possible delays
	for tap in taps:
		var c := []
		for click in clicks:
			if absf(tap - click) <= SEARCH:
				c.append(tap - click)
		cands.append(c)
	var best := 0.0
	var best_n := -1
	for c in cands:
		for x in c:
			var n := 0
			for other in cands:
				for y in other:
					if absf(y - x) <= CLUSTER:
						n += 1
						break
			if n > best_n or (n == best_n and x > best):
				best_n = n
				best = x
	var out := PackedFloat64Array()
	var used := {}
	for tap in taps:
		var pick := -1
		for i in clicks.size():
			if used.has(i) or absf(tap - clicks[i]) > SEARCH:
				continue
			if pick < 0 or absf(tap - clicks[i] - best) < absf(tap - clicks[pick] - best):
				pick = i
		if pick >= 0:
			used[pick] = true
			out.append(tap - clicks[pick])
	return out


## {offset, spread, count, ok}: offset = median (s, positive = taps land late), spread = robust
## standard deviation (1.4826 × median absolute deviation) after dropping stray taps.
func result() -> Dictionary:
	var o := offsets()
	if o.is_empty():
		return {"offset": 0.0, "spread": 0.0, "count": 0, "ok": false}
	var med := _median(o)
	var mad := _mad(o, med)
	var keep := PackedFloat64Array()
	var limit := maxf(3.0 * 1.4826 * mad, 0.03)
	for x in o:
		if absf(x - med) <= limit:
			keep.append(x)
	med = _median(keep)
	var spread := 1.4826 * _mad(keep, med)
	return {"offset": clampf(med, -MAX_PAIR, MAX_PAIR), "spread": spread, "count": keep.size(), "ok": keep.size() >= MIN_TAPS and spread <= MAX_SPREAD}


static func _median(a: PackedFloat64Array) -> float:
	var s := a.duplicate()
	s.sort()
	var m := s.size() >> 1
	return s[m] if s.size() % 2 == 1 else (s[m - 1] + s[m]) * 0.5


static func _mad(a: PackedFloat64Array, med: float) -> float:
	var d := PackedFloat64Array()
	for x in a:
		d.append(absf(x - med))
	return _median(d)
