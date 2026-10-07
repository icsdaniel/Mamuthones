extends TestCase
## Session rules: every judgement and window, unison, weight, full rings, holds, stomps,
## stand-stills, slam, Piazza, remix and mirror (docs/design.md section 3).

const FIX := "res://tests/core/fixtures/"


static func song(file := "basic") -> SongData:
	return SongData.load_file(FIX + file + ".json")


## A song built from a list of notes at 120 bpm, offset 1 s (beat b is at 1 + b/2 s).
static func make(chart: Array, extra := {}) -> SongData:
	var d := {"id": "t", "bpm": 120, "offset": 1.0, "length": 0.0, "charts": {"easy": chart}}
	d.merge(extra, true)
	return SongData.from_dict(d)


static func steps(count: int, lane := 1) -> Array:
	var out := []
	for i in count:
		out.append({"b": i, "k": "step", "lane": lane})
	return out


func _bt(b: float) -> float:
	return 1.0 + b * 0.5


func test_fixture_loads() -> void:
	var s := song()
	check(s.errors.is_empty(), "fixture has no errors: %s" % [s.errors])
	check_eq(s.id, "basic", "id")
	check_eq(s.title("it"), "Prova", "italian title")
	check_eq(s.title("de"), "Basic Test", "falls back to English")
	check_eq(s.difficulties(), ["easy", "medium", "hard", "expert"] as Array[String], "difficulties")
	check_near(s.time_of(4), 3.0, 1e-9, "time_of")
	var n := s.notes("easy")
	check_eq(n.size(), 11, "note count")
	check_eq(n[2].kind, Note.Kind.BELL, "third note is a bell")
	check(n[2].up, "first bell goes up")
	check(not n[5].up, "second bell goes down")
	check(n[9].up, "the full ring counts in the alternation (third bell-like note is up)")
	check(not n[10].up, "then down")
	check_near(n[6].end_t - n[6].t, 1.0, 1e-9, "hold of 2 beats lasts 1 s")
	check_near(n[4].end_t - n[4].t, 1.0, 1e-9, "rest of 2 beats")
	check(n[3].call, "call flag")
	check_eq(n[8].kind, Note.Kind.STOMP, "a stomp")
	check_eq(n[8].lane, 1, "on its lane")


func test_judgement_windows_light() -> void:
	# One step per beat, hit with a chosen offset each; boundaries on both sides.
	var offs := [0.0, 0.044, -0.044, 0.046, -0.089, 0.089, -0.091, 0.091, -0.139, 0.139, -0.141, 0.141]
	var want := ["perfect", "perfect", "perfect", "good", "good", "good", "early", "late", "early", "late", "miss", "miss"]
	var s := Session.new(make(steps(offs.size())), "easy")
	var got := []
	s.judged.connect(func(_n, j, _o): got.append(j))
	for i in offs.size():
		var t: float = _bt(i) + offs[i]
		s.update(t - 0.001)
		var r := s.tap(1, t, i)
		if r.judgement == "":
			got.append("")
	s.update(100.0)
	# Taps outside the window hit nothing ("") and the note later times out as a miss.
	var cleaned := got.filter(func(j): return j != "")
	check_eq(cleaned, want, "judgements by offset")
	check_eq(s.stats.perfect, 3, "perfects")
	check_eq(s.stats.good, 3, "goods")
	check_eq(s.stats.early, 2, "earlies")
	check_eq(s.stats.late, 2, "lates")
	check_eq(s.stats.miss, 2, "misses")


func test_points_per_judgement() -> void:
	var s := Session.new(make(steps(4)), "easy")
	s.tap(1, _bt(0), 0)
	check_eq(s.score, 300, "perfect is 300")
	s.tap(1, _bt(1) + 0.06, 0)
	check_eq(s.score, 450, "good is 150")
	s.tap(1, _bt(2) - 0.12, 0)
	check_eq(s.score, 500, "early is 50")
	s.update(100)
	check_eq(s.score, 500, "miss is 0")


func test_bell_set_window_scaling() -> void:
	# Full load: windows × 0.8 -> perfect 36 ms, good 72 ms, ok 112 ms.
	var s := Session.new(make(steps(4)), "easy", "full")
	check_near(s.window("touch").x, 0.036, 1e-6, "full load perfect")
	check_eq(s.tap(1, _bt(0) + 0.040, 0).judgement, "good", "40 ms is Good with the full load")
	check_eq(s.tap(1, _bt(1) + 0.080, 0).judgement, "late", "80 ms is Late with the full load")
	check_eq(s.tap(1, _bt(2) + 0.120, 0).judgement, "", "120 ms is outside the full load window")
	var v := Session.new(make(steps(2)), "easy", "village")
	check_near(v.window("touch").y, 0.081, 1e-6, "village good")
	check_eq(v.tap(1, _bt(0) - 0.040, 0).judgement, "perfect", "40 ms is Perfect with village")
	check_eq(v.tap(1, _bt(1) + 0.041, 0).judgement, "good", "41 ms is Good with village")


func test_results_carry_direction() -> void:
	# Sound pitches the Ok clank up (early) or down (late); the UI shows which way the player was off.
	var s := Session.new(make([{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}, {"b": 4, "k": "bell"}, {"b": 6, "k": "bell"}]), "easy")
	var e := s.ring(_bt(0) - 0.120)
	check_eq(e.quality, "early", "an Ok ring 120 ms early rings the early clank")
	check_eq(e.side, "early", "with its side")
	check_eq(s.ring(_bt(2) + 0.120).quality, "late", "an Ok ring 120 ms late rings the late clank")
	var g := s.ring(_bt(4) + 0.030)
	check_eq(g.quality, "perfect", "a Perfect ring keeps its own quality")
	check_eq(g.side, "late", "but still says it was late")
	check_eq(s.ring(_bt(6) + 0.005).side, "", "within 10 ms there is no side")
	var t := Session.new(make(steps(3)), "easy")
	var a := t.tap(1, _bt(0) - 0.060, 0)
	check_eq(a.judgement, "good", "Good tap")
	check_eq(a.side, "early", "tap result carries the side")
	check_near(a.offset, -0.060, 1e-6, "and the signed offset")
	check_eq(t.tap(1, _bt(1) + 0.110, 0).judgement, "late", "Ok band tap reads late")
	check_eq(t.tap(1, _bt(2) - 0.110, 0).judgement, "early", "Ok band tap reads early")
	var w := Session.new(make([{"b": 0, "k": "stomp", "lane": 1}]), "easy")
	var sw := w.tap(1, _bt(0) + 0.020, 1)
	check_eq(sw.stomp, "first", "a stomp's first thumb")
	check_eq(sw.side, "late", "stomp result carries the side")


func test_ring_strength() -> void:
	var s := Session.new(make([{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}, {"b": 4, "k": "bell"}]), "easy")
	check_eq(s.ring(_bt(0), true, 0.8).strength, 0.8, "a tilt passes the detector's strength on")
	check_eq(s.ring(_bt(2), true, 3.0).strength, 1.0, "clamped to 1")
	check_eq(s.ring(_bt(4), false, 0.9).strength, 0.5, "keyboard rings are 0.5")
	check_eq(s.ring(_bt(9), true, 0.2).strength, 0.2, "a free ring carries it too")
	var sl := Session.new(make([{"b": 0, "k": "bell"}]), "easy", "light", {"slam": true})
	check_eq(sl.ring(_bt(0), true, 0.9).strength, 0.5, "slam rings are 0.5")


func test_tilt_windows() -> void:
	var s := Session.new(make([{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}, {"b": 4, "k": "bell"}, {"b": 6, "k": "bell"}]), "easy")
	check_eq(s.ring(_bt(0) + 0.058).quality, "perfect", "tilts get +15 ms: 58 ms is Perfect")
	check_eq(s.ring(_bt(2) - 0.150).judgement, "early", "150 ms early is still Early for a tilt")
	check_eq(s.ring(_bt(4) + 0.058, false).judgement, "good", "no allowance for a keyboard/slam bell")
	var r := s.ring(_bt(6) + 0.2)
	check_eq(r.quality, "miss", "a ring just outside the window is a dull knock")
	check_eq(r.judgement, "", "and judges nothing")


func test_unison_rises_every_12_and_drops_two() -> void:
	var s := Session.new(make(steps(80)), "easy")
	var levels := []
	s.unison_changed.connect(func(l): levels.append(l))
	for i in 11:
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 0, "11 hits: still ×1")
	s.tap(1, _bt(11), 0)
	check_eq(s.unison_level, 1, "12 hits: ×1.5")
	check_eq(s.unison_mult(), 1.5, "mult 1.5")
	# The 13th hit scores at ×1.5.
	var before := s.score
	s.tap(1, _bt(12), 0)
	check_eq(s.score - before, 450, "300 × 1.5")
	for i in range(13, 60):
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 5, "60 hits: top level")
	check_eq(s.unison_mult(), 4.0, "×4 at the top")
	check_eq(levels, [1, 2, 3, 4, 5], "levels in order")
	s.update(_bt(60) + 0.2)   # miss note 60
	check_eq(s.unison_level, 3, "a miss drops two levels, not to zero")
	check_eq(s.combo, 0, "combo reset")
	# Early/Late keeps unison but restarts the count of 12.
	for i in range(61, 67):
		s.tap(1, _bt(i), 0)
	s.tap(1, _bt(67) + 0.12, 0)
	for i in range(68, 79):
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 3, "a Late hit restarts the run of 12")
	s.tap(1, _bt(79), 0)
	check_eq(s.unison_level, 4, "12 good hits after the Late: up again")
	check_eq(s.max_combo, 60, "max combo is the longest run")
	check_eq(s.combo, 19, "current combo since the miss")


func test_wrong_step_drops_one_level() -> void:
	var s := Session.new(make(steps(30, 0)), "easy")
	var marks := []
	s.wrong_step.connect(func(lane, n, _o): marks.append([lane, n.lane]))
	for i in 24:
		s.tap(0, _bt(i), 0)
	check_eq(s.unison_level, 2, "two levels up")
	var r := s.tap(2, _bt(24), 0)
	check_eq(r.judgement, "wrong", "tapping lane 2 while a lane 0 note is due is wrong")
	check_eq(s.unison_level, 1, "a wrong step drops one level")
	check_eq(s.stats.wrong, 1, "counted")
	check_eq(marks, [[2, 0]], "wrong_step names the pressed lane (and the note it was against)")
	check_eq(s.tap(0, _bt(24), 0).judgement, "perfect", "the note can still be hit")
	check_eq(s.tap(2, _bt(25) + 0.25, 0).judgement, "stray", "a tap between notes with nothing due is a stray")
	check_eq(s.unison_level, 0, "a stray drops one level, like a wrong step")
	check_eq(s.combo, 0, "and breaks the combo")


func test_stray_tap_breaks_the_combo() -> void:
	var s := Session.new(make(steps(30, 1)), "easy")
	var strays := []
	s.stray.connect(func(lane): strays.append(lane))
	check_eq(s.tap(1, _bt(0) - 0.6, 0).judgement, "", "a tap before the first note's window is free")
	for i in 14:
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 1, "one level up")
	check_eq(s.combo, 14, "14 in a row")
	var r := s.tap(0, _bt(14) - 0.25, 0)   # a quarter second before the next note, on an empty lane
	check_eq(r.judgement, "stray", "a tap with nothing near is a stray")
	check_eq(s.combo, 0, "the combo is broken")
	check_eq(s.unison_streak, 0, "so is the streak")
	check_eq(s.unison_level, 0, "and the multiplier drops a level")
	check_eq(s.stats.stray, 1, "counted")
	check_eq(s.health, Session.MAX_HEALTH, "a stray costs no health")
	check_eq(strays, [0], "stray names the lane")
	check_eq(s.tap(1, _bt(14), 0).judgement, "perfect", "the next note still counts")
	check_eq(s.tap(1, _bt(30) + 1.0, 0).judgement, "", "a tap after the last note is free")


func test_mashing_locks_the_buttons() -> void:
	var s := Session.new(make(steps(30, 1)), "easy")
	var locks := []
	s.input_locked.connect(func(until): locks.append(until))
	var t0 := _bt(4) + 0.25   # between beats 4 and 5, nothing due
	check_eq(s.tap(0, t0, 0).judgement, "stray", "first random tap")
	check_eq(s.tap(2, t0 + 0.05, 1).judgement, "stray", "second")
	check(not s.is_locked(t0 + 0.06), "not locked yet")
	check_eq(s.tap(0, t0 + 0.1, 2).judgement, "stray", "third, within the span")
	check(s.is_locked(t0 + 0.11), "now the buttons are locked")
	check_eq(locks.size(), 1, "input_locked fired once")
	check_near(s.lock_left(t0 + 0.1), Session.LOCK_TIME, 1e-6, "for LOCK_TIME")
	check_eq(s.stats.locks, 1, "counted")
	var due := s.notes[5]
	check(due.t < t0 + 0.1 + Session.LOCK_TIME, "a note comes during the lock")
	check_eq(s.tap(1, due.t, 3).judgement, "locked", "a press on time while locked judges nothing")
	check(not due.done, "the note is still open")
	s.update(due.t + 0.2)
	check_eq(due.judgement, "miss", "and is missed")
	var after := t0 + 0.1 + Session.LOCK_TIME + 0.01
	check(not s.is_locked(after), "the lock ends")
	var n := s.notes[6]
	check_eq(s.tap(1, n.t, 4).judgement, "perfect", "and taps count again")
	# Slow random taps never lock.
	var q := Session.new(make(steps(30, 1)), "easy")
	for i in 6:
		q.tap(0, _bt(4 + i) + 0.25, i)
	check_eq(q.stats.stray, 6, "six strays")
	check_eq(q.stats.locks, 0, "a stray a beat apart never locks")
	# Wrong steps count toward the lock too.
	var w := Session.new(make([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "step", "lane": 0}, {"b": 0.5, "k": "step", "lane": 0}, {"b": 8, "k": "step", "lane": 0}]), "easy")
	w.tap(2, _bt(0), 0)
	w.tap(2, _bt(0.25), 1)
	w.tap(2, _bt(0.5), 2)
	check_eq(w.stats.wrong, 3, "three wrong steps")
	check(w.is_locked(_bt(0.5) + 0.01), "lock the buttons too")


func test_stray_exemptions() -> void:
	# A stomp's second thumb landing late is not a stray.
	var s := Session.new(make([{"b": 0, "k": "step", "lane": 1}, {"b": 4, "k": "stomp", "lane": 1}, {"b": 8, "k": "step", "lane": 1}]), "easy")
	var st: Note = s.notes[1]
	s.tap(1, st.t, 0)
	s.update(st.t + Session.STOMP_GAP + 0.01)
	check(st.done, "one-thumb stomp judged")
	check_eq(s.tap(1, st.t + 0.15, 1).judgement, "", "a late second thumb is free")
	# The Piazza takes no taps at all.
	var p := Session.new(make(steps(8, 1)), "easy", "light", {"piazza": true})
	check_eq(p.tap(1, _bt(2) + 0.25, 0).judgement, "", "no strays in the Piazza")
	# Slam: the outer buttons ring the bell; only the middle can stray.
	var sl := Session.new(make([{"b": 0, "k": "step", "lane": 1}, {"b": 4, "k": "step", "lane": 1}, {"b": 8, "k": "step", "lane": 1}]), "easy", "light", {"slam": true})
	check_eq(sl.tap(0, _bt(2) + 0.25, 0).judgement, "", "an outer press in slam is a bell press")
	check_eq(sl.tap(1, _bt(2) + 0.25, 1).judgement, "stray", "the middle can stray")


func test_tap_with_own_note_coming_is_stray() -> void:
	# Lane 0 due at 1.0 s, lane 2 due at 1.25 s: pressing lane 2 at 1.0 s is inside lane 0's window,
	# but lane 2's own note is 250 ms away (within 2 × 140 ms), so the tap is free (not even a stray).
	var s := Session.new(make([{"b": 0, "k": "step", "lane": 0}, {"b": 0.5, "k": "step", "lane": 2}]), "easy")
	var marks := []
	s.wrong_step.connect(func(lane, _n, _o): marks.append(lane))
	var r := s.tap(2, _bt(0), 0)
	check_eq(r.judgement, "", "an early press for your own coming note is not a wrong step")
	check_eq(s.stats.wrong, 0, "nothing counted")
	check(marks.is_empty(), "no mark")
	check_eq(s.tap(2, _bt(0.5), 1).judgement, "perfect", "and the note is still judged when it arrives")
	check_eq(s.tap(0, _bt(0) + 0.02, 2).judgement, "perfect", "the other lane's note is untouched")
	# 300 ms away is beyond 2 × 140 ms: that tap is a wrong step.
	var w := Session.new(make([{"b": 0, "k": "step", "lane": 0}, {"b": 0.6, "k": "step", "lane": 2}]), "easy")
	check_eq(w.tap(2, _bt(0), 0).judgement, "wrong", "own note 300 ms away does not excuse the tap")
	# Full-load windows shrink the reach too (2 × 112 ms).
	var f := Session.new(make([{"b": 0, "k": "step", "lane": 0}, {"b": 0.46, "k": "step", "lane": 2}]), "easy", "full")
	check_eq(f.tap(2, _bt(0), 0).judgement, "wrong", "230 ms is beyond 2 × 112 ms with the full load")


func test_weight_multiplies_score() -> void:
	for pair in [["light", 300], ["village", 360], ["full", 450]]:
		var s := Session.new(make(steps(1)), "easy", pair[0])
		s.tap(1, _bt(0), 0)
		check_eq(s.score, pair[1], "%s weight" % pair[0])
		check_eq(s.weight(), BellSets.weight(pair[0]), "weight()")
	# unison × weight together: 13th perfect with village = 300 × 1.5 × 1.2 = 540
	var v := Session.new(make(steps(13)), "easy", "village")
	for i in 12:
		v.tap(1, _bt(i), 0)
	var before := v.score
	v.tap(1, _bt(12), 0)
	check_eq(v.score - before, 540, "points × unison × weight")
	var bd := v.score_breakdown()
	check_near(bd.base, 13 * 300, 1e-6, "breakdown base")
	check_near(bd.unison, 150, 1e-6, "breakdown unison extra")
	check_near(bd.weight, 0.2 * (12 * 300 + 450), 1e-6, "breakdown weight extra")
	check_near(bd.total, v.score, 0.5, "breakdown adds up")


func test_full_ring() -> void:
	var s := Session.new(make([{"b": 0, "k": "ring", "lane": 2}, {"b": 4, "k": "ring", "lane": 0}, {"b": 8, "k": "ring", "lane": 1}, {"b": 12, "k": "ring", "lane": 1}]), "easy")
	var got := []
	s.judged.connect(func(_n, j, o): got.append([j, o]))
	var r := s.tap(2, _bt(0), 0)
	check_eq(r.judgement, "", "the step half alone judges nothing yet")
	check(r.note != null, "but it found the ring")
	var q := s.ring(_bt(0) + 0.01)
	check_eq(q.quality, "perfect", "bell half quality")
	check_eq(got.size(), 1, "judged once both halves are in")
	check_eq(got[0][0], "perfect", "perfect full ring")
	check_eq(s.score, 450, "a perfect full ring gives 450")
	# Judged on the later input: bell first perfect, step 100 ms late -> Late.
	var half := s.ring(_bt(4))
	check_eq(half.judgement, "", "a bell half waiting for its step is not judged yet")
	check_eq(half.quality, "perfect", "but the bell sound can already ring clean")
	s.tap(0, _bt(4) + 0.100, 0)
	check_eq(got[1][0], "late", "judged on the later input (the step)")
	check_near(got[1][1], 0.1, 1e-6, "offset of the later input")
	# Only one half: miss when the window passes.
	s.tap(1, _bt(8), 0)
	s.update(_bt(8) + 0.2)
	check_eq(got[2][0], "miss", "a ring without its bell is a miss")
	# A step outside the window does not count as the ring's half.
	check_eq(s.tap(1, _bt(12) - 0.2, 0).note, null, "early step is not the ring's half")
	s.ring(_bt(12))
	s.update(_bt(12) + 0.2)
	check_eq(got[3][0], "miss", "both halves must land in the window")


func test_hold_kept_and_let_go() -> void:
	var s := Session.new(make([{"b": 0, "k": "hold", "lane": 1, "len": 4}, {"b": 8, "k": "hold", "lane": 0, "len": 4}, {"b": 16, "k": "hold", "lane": 2, "len": 4}]), "easy")
	var ends := []
	var starts := []
	s.hold_started.connect(func(l): starts.append(l))
	s.hold_ended.connect(func(l, k): ends.append([l, k]))
	# Hold 1: kept to the end automatically.
	check_eq(s.tap(1, _bt(0), 7).judgement, "perfect", "hold head judged")
	check_eq(starts, [1], "hold_started")
	s.update(_bt(3.9))
	check(s.notes[0].holding, "still holding")
	s.update(_bt(4))
	check_eq(ends, [[1, true]], "kept to the end")
	check_eq(s.score, 450, "300 head + 150 kept")
	s.release(_bt(4.1), 7)
	check_eq(s.stats.held, 1, "release after the end changes nothing")
	# Hold 2: released 100 ms early (inside 120 ms) still counts.
	s.tap(0, _bt(8), 8)
	s.release(_bt(12) - 0.100, 8)
	check_eq(ends[1], [0, true], "released 100 ms early is kept")
	# Hold 3: let go too early.
	s.tap(2, _bt(16), 9)
	s.release(_bt(20) - 0.2, 9)
	check_eq(ends[2], [2, false], "released 200 ms early is let go")
	check_eq(s.stats.let_go, 1, "let go counted")
	check_eq(s.combo, 0, "letting go breaks the combo")
	check_eq(s.score, 450 + 450 + 300, "no bonus when let go")
	check_eq(s.stats.held, 2, "two kept")


func test_stomp_both_thumbs() -> void:
	var s := Session.new(make([{"b": 0, "k": "stomp", "lane": 1}, {"b": 2, "k": "stomp", "lane": 0}, {"b": 4, "k": "stomp", "lane": 2}]), "easy")
	var landed := []
	s.stomp_landed.connect(func(n, j, _o, both): landed.append([n.index, j, both]))
	var a := s.tap(1, _bt(0) + 0.010, 1)
	check_eq(a.stomp, "first", "first thumb")
	check_eq(a.judgement, "", "not judged yet")
	var b := s.tap(1, _bt(0) + 0.060, 2)
	check_eq(b.stomp, "both", "second thumb 50 ms later")
	check_eq(b.judgement, "perfect", "timed from the first thumb")
	check_eq(s.score, 450, "stomp points")
	# Second thumb 80 ms after the first still counts; timed from the first (60 ms early = Good).
	s.tap(0, _bt(2) - 0.060, 3)
	check_eq(s.tap(0, _bt(2) + 0.020, 4).judgement, "good", "80 ms apart is still one stomp")
	# Mirror moves it like any lane note.
	var m := Session.new(make([{"b": 0, "k": "stomp", "lane": 0}]), "easy", "light", {"mirror": true})
	check_eq(m.notes[0].lane, 2, "mirror flips the stomp's lane")
	s.update(_bt(5))
	check_eq(landed, [[0, "perfect", true], [1, "good", true]], "stomp_landed for both, none for the missed one")
	check_eq(s.notes[2].judgement, "miss", "no thumb at all is a miss")
	check_eq(s.stats.one_thumb, 0, "no one-thumb stomps")


func test_stomp_one_thumb() -> void:
	var s := Session.new(make([{"b": 0, "k": "stomp", "lane": 1}, {"b": 2, "k": "stomp", "lane": 1}, {"b": 4, "k": "stomp", "lane": 1}, {"b": 6, "k": "stomp", "lane": 1}]), "easy")
	var landed := []
	s.stomp_landed.connect(func(_n, j, _o, both): landed.append([j, both]))
	s.tap(1, _bt(0), 1)
	s.update(_bt(0) + 0.070)
	check(not s.notes[0].done, "still waiting for the second thumb inside 80 ms")
	s.update(_bt(0) + 0.090)
	check_eq(s.notes[0].judgement, "good", "one thumb on the beat: one band lower")
	check_eq(s.score, 150, "on step points")
	s.tap(1, _bt(2) + 0.060, 2)
	s.update(_bt(2) + 0.2)
	check_eq(s.notes[1].judgement, "late", "one thumb 60 ms late: Good becomes Late")
	# The same finger twice is not two thumbs.
	s.tap(1, _bt(4), 3)
	s.release(_bt(4) + 0.02, 3)
	s.tap(1, _bt(4) + 0.05, 3)
	s.update(_bt(4) + 0.2)
	check_eq(s.notes[2].judgement, "good", "one finger tapping twice is one thumb")
	# A second thumb after the gap is too late to join; the stomp was one thumb.
	s.tap(1, _bt(6), 4)
	s.tap(1, _bt(6) + 0.1, 5)
	check_eq(s.notes[3].judgement, "good", "second thumb 100 ms later does not join")
	check_eq(s.stats.one_thumb, 4, "one-thumb stomps counted")
	check_eq(landed[0], ["good", false], "stomp_landed says one thumb")
	check_eq(s.stats.miss, 0, "one thumb is never a miss")
	check_eq(s.health, Session.MAX_HEALTH, "and costs no health")


func test_stomp_and_slam() -> void:
	# Slam rings the bell with Left + Right; a stomp is one button twice, so they never mix up.
	var s := Session.new(make([{"b": 0, "k": "stomp", "lane": 0}, {"b": 2, "k": "bell"}, {"b": 4, "k": "stomp", "lane": 2}]), "easy", "light", {"slam": true})
	var r1 := s.tap(0, _bt(0), 1)
	var r2 := s.tap(0, _bt(0) + 0.03, 2)
	check(r1.ring.is_empty() and r2.ring.is_empty(), "a stomp on Left rings no bell")
	check_eq(s.notes[0].judgement, "perfect", "the stomp counts")
	s.release(_bt(0) + 0.1, 1)
	s.release(_bt(0) + 0.1, 2)
	var b1 := s.tap(0, _bt(2), 3)
	var b2 := s.tap(2, _bt(2) + 0.02, 4)
	check(b1.ring.is_empty(), "one outer press alone rings nothing yet")
	check_eq(b2.ring.get("judgement", ""), "perfect", "Left + Right is still the slam bell")
	s.tap(2, _bt(4), 5)
	check_eq(s.tap(2, _bt(4) + 0.02, 6).judgement, "perfect", "a stomp on Right after the bell")
	check_eq(s.stats.one_thumb, 0, "both stomps had two thumbs")


func test_stand_still() -> void:
	var s := Session.new(make(steps(12) + [{"b": 12, "k": "rest", "len": 4}, {"b": 17, "k": "bell"}, {"b": 20, "k": "rest", "len": 2}]), "easy")
	for i in 12:
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 1, "one level up before the rest")
	var before := s.score
	var r := s.ring(_bt(13))
	check_eq(r.quality, "silence", "ringing in a stand-still")
	check_eq(s.score, before - 100, "costs 100")
	check_eq(s.unison_level, 0, "and one unison level")
	s.ring(_bt(13) + 0.1)
	check_eq(s.score, before - 100, "a second ring within 150 ms (one shake) is not charged again")
	s.ring(_bt(14))
	check_eq(s.score, before - 200, "every further ring in the stand-still costs 100")
	check_eq(s.stats.silence, 2, "two charged rings")
	# A ring near the end of the rest goes to the bell right after it when that is in the window.
	check_eq(s.ring(_bt(17) - 0.07).judgement, "good", "the bell after the rest is still playable")
	var mid := s.score
	s.update(_bt(23))
	check_eq(s.stats.still_kept, 1, "the second rest was kept")
	check_eq(s.score - mid, Session.STILL_BONUS * 2, "a kept 2-beat stand-still earns STILL_BONUS × 2 beats × unison × weight")
	check_near(s.score_breakdown().stills, Session.STILL_BONUS * 2.0, 1e-9, "shown in the breakdown")
	check_near(s.score_breakdown().penalties, 200.0, 1e-9, "penalties in the breakdown")


func test_moving_breaks_a_stand_still_once() -> void:
	var s := Session.new(make(steps(4) + [{"b": 4, "k": "rest", "len": 4}]), "easy")
	for i in 4:
		s.tap(1, _bt(i), 0)
	check(s.moved(_bt(3)) == null, "moving outside a stand-still is free")
	var before := s.score
	check(s.moved(_bt(5)) != null, "moving inside one breaks it")
	check_eq(s.score, before - Session.STILL_PENALTY, "and costs like a ring")
	check(s.moved(_bt(6)) == null, "a broken stand-still is broken once by moving")
	s.ring(_bt(5) + 0.05)
	check_eq(s.stats.silence, 1, "the ring that follows the same tilt is not charged again")
	s.update(_bt(9))
	check_eq(s.stats.still_kept, 0, "not kept")


func test_score_never_shown_below_zero_but_penalty_kept() -> void:
	# Design: score = max(0, points - penalties) over the whole run, not clamped at each step.
	var z := Session.new(make([{"b": 0, "k": "rest"}, {"b": 4, "k": "step", "lane": 0}]), "easy")
	z.ring(_bt(0.5))
	check_eq(z.score, 0, "never shown below zero")
	check_near(z.score_breakdown().total, -100.0, 1e-9, "but the penalty is kept")
	z.tap(0, _bt(4), 0)
	check_eq(z.score, 200, "max(0, 300 - 100)")


func test_still_bonus_scales_with_unison_and_weight() -> void:
	var s := Session.new(make(steps(24) + [{"b": 24, "k": "rest", "len": 2}]), "easy", "full")
	for i in 24:
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 2, "unison ×2")
	var before := s.score
	s.update(_bt(27))
	check_eq(s.score - before, roundi(Session.STILL_BONUS * 2 * 2 * 1.5), "per beat × 2 beats × unison 2 × weight 1.5")


func test_kept_still_counts_four_hits_and_top_stats() -> void:
	# 8 Good-or-better hits + a kept stand-still (4) = 12: up one level.
	var s := Session.new(make(steps(8) + [{"b": 8, "k": "rest", "len": 2}] + steps(60).map(func(d): return {"b": d.b + 12, "k": "step", "lane": 1})), "easy")
	var kept := []
	s.still_kept.connect(func(_n, pts): kept.append(pts))
	for i in 8:
		s.tap(1, _bt(i), 0)
	check_eq(s.unison_level, 0, "8 hits: still ×1")
	s.update(_bt(11))
	check_eq(kept, [Session.STILL_BONUS * 2.0], "still_kept signalled with its points")
	check_eq(s.unison_level, 1, "the stand-still counted as 4 hits: ×1.5")
	check_eq(s.unison_streak, 0, "run of 12 used up")
	check_eq(s.stats.unison_peak, 1.5, "peak multiplier so far")
	# Remainders carry: 10 hits + 4 = 14 -> one level and 2 toward the next.
	var c := Session.new(make(steps(10) + [{"b": 10, "k": "rest", "len": 2}]), "easy")
	for i in 10:
		c.tap(1, _bt(i), 0)
	c.update(_bt(13))
	check_eq(c.unison_level, 1, "14 -> one level")
	check_eq(c.unison_streak, 2, "and 2 carried")
	# Reach ×4 and measure the time there: 4 more levels = 48 hits from beat 12.
	for i in 60:
		s.tap(1, _bt(12 + i), 0)
		s.update(_bt(12 + i))
	check_eq(s.unison_level, 5, "top level")
	check_eq(s.stats.unison_peak, 4.0, "peak ×4")
	# ×4 from the 48th hit (beat 59) to the last update (beat 71): 12 beats = 6 s.
	check_near(s.stats.time_at_top, 6.0, 1e-6, "6 s at ×4")
	s.update(1e6)
	check_near(s.stats.time_at_top, s.end_time() - _bt(59), 1e-6, "counted up to the end of the song, not beyond")
	var t0: float = s.stats.time_at_top
	var m := Session.new(make(steps(70)), "easy")
	for i in 60:
		m.tap(1, _bt(i), 0)
	m.update(_bt(63))   # ×4 from beat 59; the misses seen at beat 63 drop it
	m.update(_bt(69))
	check_eq(m.unison_level < 5, true, "missed notes left ×4")
	check_near(m.stats.time_at_top, 2.0, 1e-6, "leaving ×4 stops the clock")
	check(t0 >= 6.0, "clock ran to the end")


func test_still_bonus_per_beat_and_hit_cap() -> void:
	# Per beat: a 3-beat stand-still is worth 3 × STILL_BONUS × unison × weight and 6 hits.
	var s := Session.new(make(steps(6) + [{"b": 6, "k": "rest", "len": 3}]), "easy")
	for i in 6:
		s.tap(1, _bt(i), 0)
	var before := s.score
	s.update(_bt(10))
	check_eq(s.score - before, Session.STILL_BONUS * 3, "3 beats")
	check_eq(s.unison_level, 1, "6 hits + 6 for the 3-beat stand-still: up one level")
	# A long stand-still counts at most 8 hits: 6 beats -> 6 × STILL_BONUS but 8 hits, not 12.
	var l := Session.new(make(steps(3) + [{"b": 3, "k": "rest", "len": 6}]), "easy")
	for i in 3:
		l.tap(1, _bt(i), 0)
	var lb := l.score
	l.update(_bt(10))
	check_eq(l.score - lb, Session.STILL_BONUS * 6, "6 beats")
	check_eq(l.unison_level, 0, "3 + 8 = 11 hits: not yet a level")
	check_eq(l.unison_streak, 11, "the stand-still's hits are capped at 8")
	check_near(l.still_beats(l.notes[3]), 6.0, 1e-9, "still_beats")


func test_let_go_costs_one_unison_level() -> void:
	var s := Session.new(make(steps(24) + [{"b": 24, "k": "hold", "lane": 1, "len": 4}]), "easy")
	for i in 24:
		s.tap(1, _bt(i), 0)
	s.tap(1, _bt(24), 5)
	check_eq(s.unison_level, 2, "×2 before")
	s.release(_bt(25), 5)
	check_eq(s.unison_level, 1, "letting go drops one level")


func test_note_lock_in_fast_streams() -> void:
	# 16ths at 180 bpm on one lane (83 ms apart), played 45 ms late: every note must read Good/late,
	# not drift onto the next note as Perfect.
	var chart := []
	for i in 16:
		chart.append({"b": i * 0.25, "k": "step", "lane": 1})
	var song16 := SongData.from_dict({"id": "t", "bpm": 180, "offset": 1.0, "charts": {"expert": chart}})
	var s := Session.new(song16, "expert")
	for n in s.notes.duplicate():
		s.tap(1, n.t + 0.050, 0)
		s.update(n.t + 0.050)
	s.update(100.0)
	check_eq(s.stats.good, 16, "all 16 judged Good")
	check_eq(s.stats.miss, 0, "none skipped")
	check_eq(s.stats.late_hits, 16, "all on the late side")
	check_eq(s.notes[3].side, "late", "each note knows its side")
	var e := Session.new(make(steps(2)), "easy")
	e.tap(1, _bt(0) - 0.03, 0)
	e.tap(1, _bt(1) + 0.005, 0)
	check_eq(e.notes[0].side, "early", "a Perfect 30 ms early is on the early side")
	check_eq(e.notes[1].side, "", "5 ms is dead on")


func test_hold_and_play_adds_to_the_hold() -> void:
	# A hold on Left with steps on Right and a bell under it; the second hold has nothing under it.
	var s := Session.new(make([{"b": 0, "k": "hold", "lane": 0, "len": 4}, {"b": 1, "k": "step", "lane": 2},
			{"b": 2, "k": "bell"}, {"b": 3, "k": "step", "lane": 2}, {"b": 8, "k": "hold", "lane": 0, "len": 4}]), "easy")
	var under := []
	s.played_under.connect(func(h, n): under.append([h.index, n.index]))
	s.tap(0, _bt(0), 1)
	s.tap(2, _bt(1), 2)
	s.release(_bt(1) + 0.1, 2)
	s.ring(_bt(2))
	s.tap(2, _bt(3) + 0.1, 3)    # an Ok: played, but not on time
	check_eq(under, [[0, 1], [0, 2]], "the step and the bell played on time under the hold")
	var before: float = s.score_breakdown().holds
	s.update(_bt(4))
	check_near(s.score_breakdown().holds - before, float(Session.HOLD_BONUS + 2 * Session.TIE_BONUS), 1e-6, "kept: the hold's bonus grows with what was played under it")
	s.tap(0, _bt(8), 4)
	before = s.score_breakdown().holds
	s.update(_bt(12))
	check_near(s.score_breakdown().holds - before, float(Session.HOLD_BONUS), 1e-6, "a plain hold earns the plain bonus")


func test_half_beat_in_a_sixteenth_pair_is_quick() -> void:
	var s := Session.new(make([{"b": 0, "k": "step", "lane": 0}, {"b": 0.5, "k": "step", "lane": 1}, {"b": 0.75, "k": "step", "lane": 2},
			{"b": 2, "k": "step", "lane": 0}, {"b": 2.5, "k": "step", "lane": 1}, {"b": 3, "k": "step", "lane": 2}]), "easy")
	check(s.notes[1].quick, "a half-beat followed a quarter beat later reads with the sixteenth")
	check(not s.notes[2].quick, "the sixteenth itself is silver by its own beat")
	check(not s.notes[4].quick, "a lone half-beat stays violet")


func test_reused_touch_id_ends_old_hold() -> void:
	var s := Session.new(make([{"b": 0, "k": "hold", "lane": 0, "len": 8}, {"b": 1, "k": "hold", "lane": 2, "len": 2}]), "easy")
	var ends := []
	s.hold_ended.connect(func(l, k): ends.append([l, k]))
	s.tap(0, _bt(0), 5)
	s.tap(2, _bt(1), 5)       # same id again: the lane-0 release was lost
	check_eq(ends, [[0, false]], "the old hold is let go, not kept by a stranger")
	s.release(_bt(3), 5)
	check_eq(ends, [[0, false], [2, true]], "the new hold ends with its own finger")
	s.release(_bt(3), 99)     # another finger's release
	check_eq(s.stats.held, 1, "only one hold kept")


func test_stomp_second_thumb_is_not_a_wrong_step() -> void:
	var s := Session.new(make([{"b": 0, "k": "stomp", "lane": 1}, {"b": 0.25, "k": "step", "lane": 2}]), "easy")
	s.tap(1, _bt(0), 3)
	check_eq(s.tap(1, _bt(0) + 0.03, 4).judgement, "perfect", "both thumbs on the middle")
	check_eq(s.tap(2, _bt(0.25), 5).judgement, "perfect", "the step after it")
	check_eq(s.stats.wrong, 0, "no wrong")


func test_accuracy_and_bells() -> void:
	var s := Session.new(make(steps(10)), "easy")
	for i in 6:
		s.tap(1, _bt(i), 0)                # 6 perfect
	s.tap(1, _bt(6) + 0.06, 0)            # good
	s.tap(1, _bt(7) + 0.06, 0)            # good
	s.tap(1, _bt(8) + 0.12, 0)            # late
	s.update(100)                         # miss
	check_near(s.accuracy(), (6 + 1.4 + 0.3) / 10.0, 1e-9, "accuracy formula")
	check_eq(s.bells(), 1, "77 % is one bell")
	check_eq(Session.bells_for(0.69), 0, "69 % no bell")
	check_eq(Session.bells_for(0.70), 1, "70 % one bell")
	check_eq(Session.bells_for(0.85), 2, "85 % two bells")
	check_eq(Session.bells_for(0.95), 3, "95 % three bells")
	check_near(s.mean_offset(), (0.06 + 0.06 + 0.12) / 9.0, 1e-6, "mean offset leans late")
	check(s.is_over(100.0), "over after the end")


func test_slam_mode() -> void:
	var s := Session.new(make([{"b": 0, "k": "bell"}, {"b": 2, "k": "step", "lane": 0}, {"b": 4, "k": "rest"}, {"b": 8, "k": "step", "lane": 0}, {"b": 8, "k": "step", "lane": 2}]), "easy", "light", {"slam": true})
	check(s.slam and not s.ladder_ok(), "slam runs are marked and kept off the ladder")
	var a := s.tap(0, _bt(0) - 0.03, 1)
	check(a.ring.is_empty(), "one side alone is not a bell")
	var b := s.tap(2, _bt(0) + 0.01, 2)
	check_eq(b.ring.get("quality"), "perfect", "Left + Right together ring the bell at the mean time")
	check_eq(s.stats.perfect, 1, "the bell is judged")
	check_near(s.window("tilt").x, s.window("touch").x, 1e-9, "no tilt allowance with slam")
	s.release(_bt(0) + 0.05, 1)
	s.release(_bt(0) + 0.05, 2)
	check_eq(s.tap(0, _bt(2), 3).judgement, "perfect", "a normal step still works")
	s.release(_bt(2) + 0.05, 3)
	var c := s.tap(0, _bt(4), 4)
	s.release(_bt(4) + 0.05, 4)
	var d := s.tap(2, _bt(4) + 0.2, 5)
	s.release(_bt(4) + 0.25, 5)
	check(c.ring.is_empty() and d.ring.is_empty(), "presses 200 ms apart (released) are not a slam")
	# A chord on 0 and 2 is two steps, not a bell.
	var e := s.tap(0, _bt(8), 6)
	var f := s.tap(2, _bt(8), 7)
	check_eq([e.judgement, f.judgement], ["perfect", "perfect"], "chord steps")
	check(f.ring.is_empty(), "a chord does not ring")
	check_eq(s.stats.silence, 0, "no bell rang during the rest")


func test_slam_with_one_thumb_holding() -> void:
	# A bell during an outer-lane hold, and a lane-1 full ring, need only two thumbs in slam mode.
	var s := Session.new(make([{"b": 0, "k": "hold", "lane": 0, "len": 4}, {"b": 2, "k": "bell"}, {"b": 6, "k": "ring", "lane": 1}, {"b": 8, "k": "hold", "lane": 1, "len": 4}, {"b": 10, "k": "bell"}]), "easy", "light", {"slam": true})
	s.tap(0, _bt(0), 1)
	var r := s.tap(2, _bt(2), 2)
	check_eq(r.ring.get("judgement"), "perfect", "the free thumb rings the bell while the other holds")
	s.release(_bt(2) + 0.03, 2)
	s.release(_bt(4), 1)
	var g := s.tap(1, _bt(6), 3)
	check_eq(g.judgement, "perfect", "a full ring in slam is judged on its step alone")
	check_eq(s.score_breakdown().base, 300 + 300 + 450, "and still scores as a full ring")
	s.release(_bt(6) + 0.03, 3)
	s.tap(1, _bt(8), 4)
	check_eq(s.tap(0, _bt(10), 5).ring.get("judgement"), "perfect", "bell during a middle hold")
	s.update(100)
	check_eq(s.stats.miss, 0, "nothing missed")


func test_piazza_windows() -> void:
	var d := {"id": "pz", "kind": "piazza", "bpm": 120, "offset": 1.0, "charts": {"piazza": [{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}, {"b": 4, "k": "step", "lane": 1}, {"b": 6, "k": "bell"}]}}
	var s := Session.new(SongData.from_dict(d), "piazza", "full", {"piazza": true})
	check_eq(s.stats.total, 3, "only bells count in the Piazza")
	check_near(s.window("tilt").z, 0.200, 1e-6, "±200 ms whatever the bell set")
	check_eq(s.ring(_bt(0) + 0.19).judgement, "late", "190 ms still counts")
	check_eq(s.ring(_bt(2) - 0.06).judgement, "perfect", "60 ms is Perfect in the loose Piazza windows")
	check_eq(s.tap(1, _bt(4), 0).judgement, "", "taps do nothing")
	s.update(100)
	check_eq(s.stats.miss, 1, "the unplayed bell is a miss")
	check(not s.ladder_ok(), "Piazza scores stay on the phone")


func test_remix_offsets() -> void:
	var s := song()
	var a := Session.new(s, "easy")
	var b := Session.new(s, "easy", "light", {"remix": true})
	check_near(a.notes[0].t, 1.0, 1e-9, "original offset")
	check_near(b.notes[0].t, 0.5, 1e-9, "remix offset")
	check_near(b.notes[2].t - a.notes[2].t, -0.5, 1e-9, "same beat grid, shifted")
	check_eq(b.song_key(), "basic_remix", "remix bests are kept apart")
	check_eq(b.tap(0, 0.5, 0).judgement, "perfect", "hit on the remix time")
	check_near(s.time_of(4, true), 2.5, 1e-9, "time_of(remix)")


func test_mirror_and_range() -> void:
	var s := song()
	var m := Session.new(s, "easy", "light", {"mirror": true})
	check_eq(m.notes[0].lane, 2, "lane 0 mirrored to 2")
	check_eq(m.notes[1].lane, 1, "lane 1 stays")
	var r := Session.new(s, "easy", "light", {"from_beat": 4, "to_beat": 13})
	check_eq(r.notes.size(), 4, "only notes in [4, 13)")
	check(r.notes[0].up, "bell direction comes from the whole chart")
	check(not r.notes[3].up, "second bell of the chart is down")
	check_near(r.end_time(), s.time_of(13) + 1.0, 1e-9, "a lesson ends a second after its range")
	check(not r.ladder_ok(), "practice runs stay off the ladder")


func test_autoplay_is_perfect() -> void:
	var s := Session.new(song(), "easy")
	var ap := Autoplay.new(s)
	var rang := []
	ap.rang.connect(func(r): rang.append(r))
	var t := 0.0
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)
	check_near(s.accuracy(), 1.0, 1e-9, "autoplay accuracy 100 %")
	check_eq(s.stats.perfect, s.stats.total, "all perfect")
	check_eq(s.stats.held, 1, "hold kept")
	check_eq(s.stats.silence, 0, "no bell in the stand-still")
	check_eq(s.stats.still_kept, 1, "stand-still kept")
	check_eq(rang.size(), 4, "rang for 3 bells and 1 full ring")
	check_eq(s.bells(), 3, "three bells")


func test_autoplay_human_is_close() -> void:
	var chart := []
	for i in 200:
		chart.append({"b": i, "k": "step", "lane": i % 3})
	var s := Session.new(make(chart), "easy")
	var ap := Autoplay.new(s, true, 7)
	var t := 0.0
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)
	check(s.accuracy() > 0.8 and s.accuracy() < 1.0, "human autoplay is good but not perfect (%f)" % s.accuracy())


func test_lessons_and_passed() -> void:
	var s1 := SongData.load_file("res://tests/core/fixtures/story/s1.json")
	check_eq(s1.lesson_range(1), Vector2(16, 24), "lesson range")
	check_eq(s1.lesson_range(5), Vector2.ZERO, "no such lesson")
	var r := s1.lesson_range(1)
	var s := Session.new(s1, "easy", "light", {"from_beat": r.x, "to_beat": r.y})
	check_eq(s.stats.total, 2, "the bells lesson has two bells")
	check_eq(s.stats.rests, 1, "and one stand-still")
	s.ring(s1.time_of(16))
	s.ring(s1.time_of(19))      # into the stand-still
	s.ring(s1.time_of(21))
	s.update(s.end_time())
	check(not s.passed(), "ringing in the stand-still fails the lesson")
	var t := Session.new(s1, "easy", "light", {"from_beat": r.x, "to_beat": r.y})
	t.ring(s1.time_of(16))
	t.ring(s1.time_of(21))
	t.update(t.end_time())
	check(t.passed(), "both bells and stillness pass")
	check(t.is_over(t.end_time()), "the lesson is over at its end")


func test_frame_cost() -> void:
	# A dense 4-minute Expert-like chart (about 8 notes a second): the per-frame rules work must
	# stay tiny next to a 16 ms frame.
	var chart := []
	for i in 2000:
		var b := i * 0.25
		match i % 8:
			3:
				chart.append({"b": b, "k": "bell"})
			7:
				chart.append({"b": b, "k": "hold", "lane": 1, "len": 0.25})
			_:
				chart.append({"b": b, "k": "step", "lane": [0, 2][i % 2]})
	var dense := SongData.from_dict({"id": "dense", "bpm": 120, "offset": 1.0, "charts": {"expert": chart}})
	var s := Session.new(dense, "expert", "full")
	var ap := Autoplay.new(s)
	var frames := 0
	var t := 0.0
	var t0 := Time.get_ticks_usec()
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)
		frames += 1
	var per_frame := (Time.get_ticks_usec() - t0) / float(frames)
	check_near(s.accuracy(), 1.0, 1e-9, "dense chart all perfect")
	check(per_frame < 100.0, "rules + autoplay cost %.1f µs per frame (limit 100)" % per_frame)
	print("  frame cost: %.1f µs per frame over %d frames, %d notes" % [per_frame, frames, s.notes.size()])


# ---------------------------------------------------------------- health


func _run(s: Session, until: float) -> void:
	var t := 0.0
	while t < until:
		t += 1.0 / 60.0
		s.update(t)


func test_health_misses_cost_one() -> void:
	var s := Session.new(make(steps(12)), "easy")
	var seen := []
	var fails := [0]
	s.health_changed.connect(func(h: int, d: int) -> void: seen.append([h, d]))
	s.failed.connect(func() -> void: fails[0] += 1)
	check(s.health_on, "health is on for a song")
	check_eq(s.health, Session.MAX_HEALTH, "health starts full")
	check_eq(Session.MAX_HEALTH, 10, "ten health")
	s.tap(1, _bt(0))
	_run(s, _bt(2) + 0.2)   # beats 1 and 2 pass unplayed
	check_eq(s.health, 8, "two misses cost two")
	check_eq(seen, [[9, -1], [8, -1]], "health_changed reports each loss")
	_run(s, _bt(20))
	check_eq(s.health, 0, "every miss costs one, down to 0")
	check_eq(fails[0], 1, "failed fires once")
	check(s.has_failed, "the run has failed")
	check_eq(s.stats.miss, 11, "the rules keep judging after the fail")


func test_health_every_kind_of_miss() -> void:
	var chart := [
		{"b": 0, "k": "step", "lane": 0}, {"b": 2, "k": "hold", "lane": 1, "len": 2},
		{"b": 6, "k": "bell"}, {"b": 8, "k": "ring", "lane": 2}, {"b": 10, "k": "stomp", "lane": 1},
		{"b": 12, "k": "stomp", "lane": 1},
	]
	var s := Session.new(make(chart), "easy")
	_run(s, _bt(11))
	check_eq(s.health, 5, "missed step, hold head, bell, ring and stomp each cost one")
	s.tap(1, _bt(12), 1)
	s.update(_bt(13))
	check_eq(s.health, 5, "a one-thumb stomp costs nothing")


func test_health_spares_wrong_steps_and_still_rings() -> void:
	var chart := [
		{"b": 0, "k": "step", "lane": 0}, {"b": 2, "k": "rest", "len": 4}, {"b": 8, "k": "step", "lane": 1},
	]
	var s := Session.new(make(chart), "easy")
	s.tap(2, _bt(0))              # wrong lane: the note is still open
	check_eq(s.stats.wrong, 1, "a wrong step")
	check_eq(s.health, 10, "a wrong step costs no health")
	s.tap(0, _bt(0) + 0.02)
	s.update(_bt(3))
	s.ring(_bt(3))
	s.ring(_bt(4))
	check_eq(s.stats.silence, 2, "rang twice into the stand-still")
	check_eq(s.health, 10, "rings in a stand-still cost no health")


func test_health_heals_two_and_caps() -> void:
	var s := Session.new(make(steps(80)), "easy")
	var heals := s.heal_notes()
	check(heals.size() >= 1, "a long song has healing steps")
	var h := heals[0]
	check_eq(h.kind, Note.Kind.STEP, "a healing step is a step")
	# Miss the three steps before it, then hit it late (Ok): +2.
	for n in s.notes:
		if n.index < h.index - 3:
			s.tap(n.lane, n.t)
	s.update(h.t - 0.2)
	var before := s.health
	check_eq(before, 7, "missed three on the way")
	var dh := [0]
	s.health_changed.connect(func(_h: int, d: int) -> void: dh[0] = d)
	s.tap(h.lane, h.t + 0.12)
	check_eq(s.notes[h.index].judgement, "late", "hit in the Ok band")
	check_eq(s.health, mini(before + 2, 10), "an Ok hit on a healing step restores 2")
	# At full health it stays at 10; at 8 it goes to 10.
	for missed in [0, 2]:
		var c := Session.new(make(steps(80)), "easy")
		var ch := c.heal_notes()[0]
		for n in c.notes:
			if n.t < ch.t and n.index >= missed:
				c.tap(n.lane, n.t)
		c.update(ch.t - 0.2)
		check_eq(c.health, 10 - missed, "%d misses before the healing step" % missed)
		c.tap(ch.lane, ch.t)
		check_eq(c.health, 10, "healing from %d stops at 10" % (10 - missed))


func test_health_heal_spacing() -> void:
	# 160 on-beat steps at 120 bpm: 80 s of play.
	var chart := []
	for i in 160:
		chart.append({"b": i, "k": "step", "lane": i % 3})
	chart.append({"b": 40.5, "k": "step", "lane": 0})
	var charts := {}
	for d in ["easy", "medium", "hard", "expert"]:
		charts[d] = chart
	var song_ := SongData.from_dict({"id": "t", "bpm": 120, "offset": 1.0, "length": 0.0, "charts": charts})
	for d in Session.HEAL_EVERY:
		var s := Session.new(song_, d)
		var hs := s.heal_notes()
		var every: float = Session.HEAL_EVERY[d]
		var span := s.notes[-1].t - s.notes[0].t - Session.HEAL_GRACE
		check(hs.size() >= floori(span / every) and hs.size() <= ceili(span / every), "%s: about one heal every %d s (%d)" % [d, every, hs.size()])
		check(hs[0].t >= s.notes[0].t + Session.HEAL_GRACE, "%s: none in the first 8 s" % d)
		for i in range(1, hs.size()):
			check(hs[i].t - hs[i - 1].t >= every * 0.5, "%s: heals are spaced" % d)
		for h in hs:
			check(h.kind == Note.Kind.STEP and not h.call and is_equal_approx(h.beat, roundf(h.beat)), "%s: heals are on-beat plain steps" % d)
		var again := Session.new(song_, d).heal_notes()
		check_eq(again.map(func(n: Note) -> int: return n.index), hs.map(func(n: Note) -> int: return n.index), "%s: the same notes every time" % d)
	var easy := Session.new(song_, "easy").heal_notes().size()
	var expert := Session.new(song_, "expert").heal_notes().size()
	check(easy > expert, "Easy heals more often than Expert (%d, %d)" % [easy, expert])


func test_health_never_on_holds_rings_calls_or_off_beats() -> void:
	var chart := []
	for i in 120:
		var k: String = ["hold", "ring", "step"][i % 3]
		var n := {"b": i * 1.0 + (0.5 if k == "step" else 0.0), "k": k, "lane": i % 3}
		if k == "hold":
			n.len = 0.5
		chart.append(n)
	for i in 40:
		chart.append({"b": 200 + i, "k": "step", "lane": 1, "call": true})
	var s := Session.new(make(chart), "easy")
	check(s.heal_notes().is_empty(), "no heal on a hold, ring, off-beat or call step")


func test_health_exempt_modes_never_fail() -> void:
	var s1 := SongData.load_file(FIX + "story/s1.json")
	var r := s1.lesson_range(1)
	for opts in [{"piazza": true}, {"from_beat": r.x, "to_beat": r.y}, {"health": false}]:
		var s := Session.new(s1, "easy", "light", opts)
		var fails := [0]
		s.failed.connect(func() -> void: fails[0] += 1)
		_run(s, s.end_time() + 1.0)
		check(not s.health_on, "%s: health is off" % [opts])
		check(s.heal_notes().is_empty(), "%s: no healing steps" % [opts])
		check_eq(s.health, Session.MAX_HEALTH, "%s: health never drops" % [opts])
		check_eq(fails[0], 0, "%s: never fails" % [opts])
