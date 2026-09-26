extends SceneTree
## Headless tests. Run from the repo root:
##   godot --headless --path game --import
##   godot --headless --path game -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	var songs := Chart.load_songs()
	check(songs.size() == 2, "two songs load")
	for song in songs:
		check(Chart.validate(song).is_empty(), "%s chart is valid: %s" % [song.id, Chart.validate(song)])
		test_bells_alternate(song)
		test_perfect_run(song)
		test_no_input(song)
	test_counts(songs)
	test_rest_penalty(songs[0])
	test_wrong_step(songs[0])
	test_hold_let_go(songs[1])
	test_swipe(songs[1])
	test_multiplier(songs[0])
	test_calibrator_gyro()
	test_calibrator_accel_only()
	test_calibrator_soft()
	test_detector_single_ring()
	test_save()
	await test_scenes_load(songs)
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures else 0)


func check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)


func by_id(songs: Array, id: String) -> Dictionary:
	for s in songs:
		if s.id == id:
			return s
	return {}


func test_counts(songs: Array) -> void:
	# Same numbers the web prototype's parser gives.
	var steps := Session.new(by_id(songs, "steps"))
	check(steps.hittable_count() == 58, "steps has 58 notes to hit (got %d)" % steps.hittable_count())
	var rope := Session.new(by_id(songs, "rope"))
	check(rope.hittable_count() == 44, "rope has 44 notes to hit (got %d)" % rope.hittable_count())
	check(rope.hold_count() == 4, "rope has 4 holds (got %d)" % rope.hold_count())
	var calls := rope.notes.filter(func(n: Note): return n.call)
	check(calls.size() > 0, "rope has off-beat calls")
	var swipes := rope.notes.filter(func(n: Note): return n.kind == Note.Kind.SWIPE)
	check(swipes.size() == 3, "rope has 3 swipes (got %d)" % swipes.size())
	var first: Note = rope.notes[0]
	check(first.kind == Note.Kind.HOLD and first.lane == 1, "rope opens with a middle hold")
	check(is_equal_approx(first.end_t - first.t, 3 * Chart.eighth(rope.song)), "that hold lasts 3 eighths")


func test_bells_alternate(song: Dictionary) -> void:
	var up := true
	for n in Chart.parse(song):
		if n.kind == Note.Kind.BELL:
			check(n.up == up, "%s bells alternate" % song.id)
			up = not up


## Plays every note exactly on time, the way a perfect player would.
func perfect_play(s: Session) -> void:
	var touch := 0
	var pending_releases := []  # [time, touch id]
	for n in s.notes.duplicate():
		for r in pending_releases.duplicate():
			if r[0] <= n.t:
				s.update(r[0])
				s.release(r[0], r[1])
				pending_releases.erase(r)
		s.update(n.t)
		match n.kind:
			Note.Kind.STEP:
				s.tap(n.lane, n.t, touch)
				s.release(n.t + 0.05, touch)
			Note.Kind.HOLD:
				s.tap(n.lane, n.t, touch)
				pending_releases.append([n.end_t + 0.01, touch])
			Note.Kind.BELL:
				s.ring(n.t)
			Note.Kind.SWIPE:
				s.swipe(n.right, n.t)
		touch += 1
	for r in pending_releases:
		s.update(r[0])
		s.release(r[0], r[1])
	s.update(s.end_t + 1.0)


func test_perfect_run(song: Dictionary) -> void:
	var s := Session.new(song)
	perfect_play(s)
	check(is_equal_approx(s.accuracy(), 1.0), "%s perfect run is 100%% (got %.3f)" % [song.id, s.accuracy()])
	check(s.stats.miss == 0 and s.stats.wrong == 0 and s.stats.silence == 0, "%s perfect run has no mistakes %s" % [song.id, s.stats])
	check(s.stats.kept == s.hold_count(), "%s perfect run keeps every hold" % song.id)
	check(s.max_combo == s.hittable_count() + s.hold_count(), "%s perfect run combos everything" % song.id)
	check(s.score > 0 and s.is_over(s.end_t + 1.0), "%s scores and ends" % song.id)


func test_no_input(song: Dictionary) -> void:
	var s := Session.new(song)
	var t := float(song.first_beat) - 1.0
	while t < s.end_t + 1.0:
		s.update(t)
		t += 1.0 / 60.0
	check(s.stats.miss == s.hittable_count(), "%s untouched run misses everything" % song.id)
	check(s.score == 0 and s.accuracy() == 0.0, "%s untouched run scores 0" % song.id)


func test_rest_penalty(song: Dictionary) -> void:
	var s := Session.new(song)
	perfect_play(s)
	var clean := s.score
	var s2 := Session.new(song)
	var rest: Note = s2.notes.filter(func(n: Note): return n.kind == Note.Kind.REST)[0]
	s2.ring(rest.t)
	check(s2.stats.silence == 1, "ringing on a rest counts as breaking the silence")
	check(s2.score == 0, "the penalty never takes the score below 0")
	check(clean > 0, "clean run scored")


func test_wrong_step(song: Dictionary) -> void:
	var s := Session.new(song)
	var n: Note = s.notes[0]
	s.tap((n.lane + 1) % 3, n.t)
	check(s.stats.wrong == 1 and s.combo == 0 and s.score == 0, "a tap on the wrong button is wrong")
	var n2: Note = s.notes[1]
	s.tap(n2.lane, n2.t + 0.06)
	check(s.stats.good == 1 and s.score == 150, "60 ms late is Good for 150")
	var n3: Note = s.notes[2]
	s.tap(n3.lane, n3.t - 0.12)
	check(s.stats.ok == 1, "120 ms early is Early")
	var n4: Note = s.notes[4]
	s.tap(n4.lane, n4.t + 0.2)
	check(not n4.done, "200 ms off is too far to count")


func test_hold_let_go(song: Dictionary) -> void:
	var s := Session.new(song)
	var h: Note = s.notes[0]
	var started := [0]
	s.hold_started.connect(func(_l): started[0] += 1)
	s.tap(h.lane, h.t, 7)
	check(h.holding and started[0] == 1, "tapping a hold starts holding")
	s.release(h.t + 0.1, 7)
	check(h.finished and s.stats.kept == 0 and s.combo == 0, "letting go early breaks the hold")
	var s2 := Session.new(song)
	var h2: Note = s2.notes[0]
	s2.tap(h2.lane, h2.t, 3)
	s2.release(h2.end_t - 0.1, 3)
	check(s2.stats.kept == 1, "letting go within 120 ms of the end keeps it")
	var s3 := Session.new(song)
	var h3: Note = s3.notes[0]
	s3.tap(h3.lane, h3.t, 3)
	s3.update(h3.end_t)
	check(s3.stats.kept == 1 and s3.score == 450, "holding to the end keeps it (300 + 150)")


func test_swipe(song: Dictionary) -> void:
	var s := Session.new(song)
	var sw: Note = s.notes.filter(func(n: Note): return n.kind == Note.Kind.SWIPE)[0]
	s.swipe(not sw.right, sw.t)
	check(s.stats.wrong == 1, "a swipe the wrong way is wrong")
	var s2 := Session.new(song)
	var sw2: Note = s2.notes.filter(func(n: Note): return n.kind == Note.Kind.SWIPE)[0]
	s2.swipe(sw2.right, sw2.t + 0.16)
	check(sw2.done and s2.stats.ok == 1, "swipes have a wider 170 ms window")


func test_multiplier(song: Dictionary) -> void:
	var s := Session.new(song)
	s.combo = 7
	check(s.mult() == 1.0, "x1 before 8 in a row")
	s.combo = 8
	check(s.mult() == 1.5, "x1.5 at 8 in a row")
	s.combo = 100
	check(s.mult() == 3.0, "capped at x3")


## Synthetic tilt: a quick bump on one axis followed by a smaller rebound the other way.
func feed_move(c: Calibrator, t0: float, axis_vec: Vector3, peak_rot: float, peak_acc: float, gyro := true) -> float:
	var t := t0
	for i in 12:
		var k := sin(PI * i / 6.0)  # one full swing over 12 samples at 60 Hz
		c.feed(t, axis_vec * peak_acc * k, axis_vec * peak_rot * k, gyro)
		t += 1.0 / 60.0
	for i in 30:  # half a second of calm
		c.feed(t, Vector3.ZERO, Vector3.ZERO, gyro)
		t += 1.0 / 60.0
	return t


func test_calibrator_gyro() -> void:
	var c := Calibrator.new()
	var t := 0.0
	var peaks := [300.0, 360.0, 330.0, 310.0, 280.0, 350.0]
	for i in 6:
		var dir := Vector3(1, 0.1, 0) if i < 3 else Vector3(-1, 0.1, 0)
		t = feed_move(c, t, dir, peaks[i], 6.0)
	check(c.is_done(), "six moves complete calibration (got %d)" % c.moves.size())
	var r := c.result()
	check(r.get("mode") == "rot", "gyro is picked when it reads direction: %s" % r)
	check(r.get("axis") == 0 and r.get("up_sign") == 1.0 and r.get("dir_ok"), "learns axis and up sign")
	check(r.get("thr", 0.0) > 60.0 and r.get("thr", 0.0) < 200.0, "threshold near 45%% of the median peak (%s)" % r.get("thr"))


func test_calibrator_accel_only() -> void:
	var c := Calibrator.new()
	var t := 0.0
	for i in 6:
		t = feed_move(c, t, Vector3(0, 0, -1) if i < 3 else Vector3(0, 0, 1), 0.0, 12.0, false)
	var r := c.result()
	check(r.get("mode") == "acc" and r.get("axis") == 2 and r.get("up_sign") == -1.0, "falls back to acceleration without a gyro: %s" % r)
	check(r.get("thr", 0.0) >= 4.0 and r.get("thr", 0.0) <= 25.0, "acceleration threshold is clamped")


func test_calibrator_soft() -> void:
	var c := Calibrator.new()
	var t := 0.0
	for i in 6:
		t = feed_move(c, t, Vector3(1, 0, 0), 0.0, 3.0, false)
	check(not c.is_done() and c.result().is_empty(), "moves below the trigger are ignored")


func test_detector_single_ring() -> void:
	var d := BellDetector.new({ mode = "rot", thr = 120.0 }, 90.0)
	var rings := 0
	var t := 0.0
	# One tilt down and back up: two lobes within a fraction of a beat.
	for i in 24:
		var k := sin(TAU * i / 24.0)
		if d.feed(t, Vector3.ZERO, Vector3(300.0 * k, 0, 0)):
			rings += 1
		t += 1.0 / 60.0
	check(rings == 1, "a down-and-up flick rings once (got %d)" % rings)
	for i in 30:
		d.feed(t, Vector3.ZERO, Vector3.ZERO)
		t += 1.0 / 60.0
	check(d.feed(t, Vector3.ZERO, Vector3(200, 0, 0)), "the next tilt after settling rings again")


func test_save() -> void:
	var path := "user://test_save.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s := SaveData.new(path)
	check(s.best("steps") == 0 and s.calibration().is_empty(), "fresh save is empty")
	s.submit("steps", 1200)
	s.submit("steps", 900)
	s.set_calibration({ mode = "acc", thr = 6.0 })
	var s2 := SaveData.new(path)
	check(s2.best("steps") == 1200, "best score survives a reload and is not lowered")
	check(s2.calibration().get("thr") == 6.0, "calibration survives a reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Builds every screen once so script errors in the UI fail the tests too.
func test_scenes_load(songs: Array) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	for screen in ["title", "calibrate", "songs", "results"]:
		main.call("show_" + screen)
		await process_frame
		check(main.get_child_count() > 0, "%s screen builds" % screen)
	main.call("start_song", songs[1], true)  # autoplay
	await process_frame
	var view: PlayView = main.find_child("PlayView", true, false)
	check(view != null, "play screen builds")
	# Drive the play screen frame by frame on its own clock, without waiting for the audio.
	view._music.stop()
	var frames := 0
	while main.last_session == null and frames < 60 * 120:
		view._process(1.0 / 60.0)
		frames += 1
	var s: Session = main.last_session
	check(s != null, "autoplay reaches the results")
	if s != null:
		check(s.accuracy() > 0.95 and s.stats.kept == s.hold_count(), "autoplay through the play screen plays the song well (%.3f, %s)" % [s.accuracy(), s.stats])
	await process_frame
	check(main.find_child("PlayView", true, false) == null, "results replace the play screen")
	main.queue_free()
	await process_frame
