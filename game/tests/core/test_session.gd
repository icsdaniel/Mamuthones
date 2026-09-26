extends TestCase
## Session rules: every judgement and window, unison, weight, full rings, holds, swipes,
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
	check_eq(n[8].dir, -1, "left swipe")


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


func test_tilt_and_swipe_windows() -> void:
	var s := Session.new(make([{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}, {"b": 4, "k": "bell"}, {"b": 6, "k": "bell"}]), "easy")
	check_eq(s.ring(_bt(0) + 0.058).quality, "perfect", "tilts get +15 ms: 58 ms is Perfect")
	check_eq(s.ring(_bt(2) - 0.150).judgement, "early", "150 ms early is still Early for a tilt")
	check_eq(s.ring(_bt(4) + 0.058, false).judgement, "good", "no allowance for a keyboard/slam bell")
	var r := s.ring(_bt(6) + 0.2)
	check_eq(r.quality, "miss", "a ring just outside the window is a dull knock")
	check_eq(r.judgement, "", "and judges nothing")
	var w := Session.new(make([{"b": 0, "k": "swipe", "dir": 1}, {"b": 2, "k": "swipe", "dir": 1}]), "easy")
	check_near(w.window("swipe").z, 0.170, 1e-6, "swipe window 170 ms")
	check_eq(w.swipe(1, _bt(0) + 0.160).judgement, "late", "160 ms is a late swipe")
	check_eq(w.swipe(1, _bt(2) + 0.180).judgement, "", "180 ms misses the swipe")


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


func test_wrong_step_drops_two_levels() -> void:
	var s := Session.new(make(steps(30, 0)), "easy")
	for i in 24:
		s.tap(0, _bt(i), 0)
	check_eq(s.unison_level, 2, "two levels up")
	var r := s.tap(2, _bt(24), 0)
	check_eq(r.judgement, "wrong", "tapping lane 2 while a lane 0 note is due is wrong")
	check_eq(s.unison_level, 0, "wrong drops two levels")
	check_eq(s.stats.wrong, 1, "counted")
	check_eq(s.tap(0, _bt(24), 0).judgement, "perfect", "the note can still be hit")
	check_eq(s.tap(2, _bt(25) + 0.25, 0).judgement, "", "a stray tap between notes costs nothing")


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


func test_swipes_both_ways() -> void:
	var s := Session.new(make([{"b": 0, "k": "swipe", "dir": 1}, {"b": 2, "k": "swipe", "dir": -1}, {"b": 4, "k": "swipe", "dir": 1}]), "easy", "light", {})
	check_eq(s.swipe(1, _bt(0)).judgement, "perfect", "right swipe")
	check_eq(s.swipe(-1, _bt(2) + 0.02).judgement, "perfect", "left swipe")
	check_eq(s.swipe(-1, _bt(4)).judgement, "wrong", "wrong way")
	check_eq(s.stats.wrong, 1, "wrong swipe counted")
	check_eq(s.stats.notes, 3, "a wrong swipe uses up the note")
	var m := Session.new(make([{"b": 0, "k": "swipe", "dir": 1}]), "easy", "light", {"mirror": true})
	check_eq(m.swipe(-1, _bt(0)).judgement, "perfect", "mirror flips swipes")


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
	check_eq(s.score - mid, 50, "a kept stand-still earns 50 × unison × weight")
	check_near(s.score_breakdown().stills, 50.0, 1e-9, "shown in the breakdown")
	check_near(s.score_breakdown().penalties, 200.0, 1e-9, "penalties in the breakdown")


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
	check_eq(s.score - before, 150, "50 × 2 × 1.5")


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


func test_swipe_start_is_not_a_wrong_step() -> void:
	var s := Session.new(make([{"b": 0, "k": "swipe", "dir": 1}, {"b": 0.25, "k": "step", "lane": 2}]), "easy")
	var r := s.tap(0, _bt(0), 3)          # finger lands on lane 0 to start the swipe
	check_eq(r.judgement, "", "the swipe's touch-down is not a wrong step")
	check_eq(s.swipe(1, _bt(0)).judgement, "perfect", "swipe judged at touch-down")
	check_eq(s.tap(2, _bt(0.25), 4).judgement, "perfect", "the step after it")
	check_eq(s.unison_level, 0, "no unison lost")
	check_eq(s.stats.wrong, 0, "no wrong")


# Independent re-implementation of design section 3, applied to the judged events a Session emits.
func test_reference_formula_on_random_runs() -> void:
	var rng := RandomNumberGenerator.new()
	for run in 25:
		rng.seed = 1000 + run
		var chart := []
		var b := 0.0
		for i in 120:
			b += [0.5, 1.0, 1.5][rng.randi() % 3]
			var k := rng.randi() % 10
			if k < 5:
				chart.append({"b": b, "k": "step", "lane": rng.randi() % 3})
			elif k < 7:
				chart.append({"b": b, "k": "bell"})
			elif k == 7:
				chart.append({"b": b, "k": "hold", "lane": rng.randi() % 3, "len": 0.5})
			elif k == 8:
				chart.append({"b": b, "k": "ring", "lane": rng.randi() % 3})
			else:
				chart.append({"b": b, "k": "rest", "len": 0.5})
		var bell_set: String = BellSets.ids()[run % 3]
		var s := Session.new(make(chart), "easy", bell_set)
		var events := []
		s.judged.connect(func(n, j, _o): events.append([n.kind, j]))
		var rest_events := []
		for n in s.notes:
			var off := rng.randf_range(-0.2, 0.2)
			match n.kind:
				Note.Kind.STEP:
					s.tap(n.lane, n.t + off, 1)
				Note.Kind.BELL:
					s.ring(n.t + off)
				Note.Kind.HOLD:
					s.tap(n.lane, n.t + off, 2)
					s.release(n.end_t - rng.randf_range(0.0, 0.3), 2)
				Note.Kind.RING:
					s.tap(n.lane, n.t + off * 0.5, 3)
					s.ring(n.t + off)
				Note.Kind.REST:
					if rng.randf() < 0.4:
						s.ring(n.t + 0.1)
						rest_events.append(n.index)
			s.update(n.t + 0.01)
		s.update(1e6)
		# Replay the events through the formula.
		var mults := [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
		var level := 0
		var run12 := 0
		var total := 0.0
		var w := BellSets.weight(bell_set)
		var pts := {"perfect": 300, "good": 150, "early": 50, "late": 50}
		var ring_pts := {"perfect": 450, "good": 225, "early": 75, "late": 75}
		for e in events:
			var j: String = e[1]
			match j:
				"perfect", "good", "early", "late":
					total += (ring_pts if e[0] == Note.Kind.RING else pts)[j] * mults[level] * w
					if j == "perfect" or j == "good":
						run12 += 1
						if run12 == 12:
							run12 = 0
							level = mini(level + 1, 5)
					else:
						run12 = 0
				"miss", "wrong":
					run12 = 0
					level = maxi(level - 2, 0)
				"held":
					total += 150 * mults[level] * w
				"let_go":
					run12 = 0
					level = maxi(level - 1, 0)
				"silence":
					total -= 100
					run12 = 0
					level = maxi(level - 1, 0)
		# Kept stand-stills are not signalled; add them from the notes.
		var still_total: float = s.score_breakdown().stills
		check_near(s.score_breakdown().total, total + still_total, 0.01, "run %d: score follows the formula" % run)
		check_eq(s.score, maxi(0, int(round(total + still_total))), "run %d: shown score" % run)
		check_eq(s.unison_level, level, "run %d: unison level" % run)


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
