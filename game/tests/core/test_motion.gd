extends TestCase
## Calibration and bell detection on synthetic sensor signals (rubric aspect 7).

const Synth := preload("res://tests/core/motion_synth.gd")


# Six calibration moves (3 up, 3 down) 0.8 s apart; returns the Calibrator after feeding them.
func _calibrate(synth: Synth, has_gyro := true) -> Calibrator:
	var cal := Calibrator.new()
	cal.start()
	for t in synth.frames(0.0, 6.0):
		var s := synth.sample(t)
		cal.feed(t, s[0], s[1] if has_gyro else Vector3.ZERO, has_gyro)
	return cal


func _moves(synth: Synth, rot: Array, acc: Array, acc_consistent := true) -> void:
	for i in 6:
		synth.flick(0.5 + i * 0.8, i < 3, rot[i], acc[i], 0.2, acc_consistent)


func test_calibration_clean() -> void:
	var sy := Synth.new(1)
	_moves(sy, [400, 420, 380, 410, 390, 400], [12, 12, 12, 12, 12, 12])
	var cal := _calibrate(sy)
	var r := cal.result()
	check(cal.is_done(), "done after six moves")
	check_eq(cal.count(), 6, "six moves")
	check_eq(r.get("mode"), "gyro", "uses the gyroscope")
	check_eq(r.get("axis"), 0, "rotation about x")
	check_eq(r.get("up_sign"), 1, "up is positive")
	check_eq(r.get("agree"), 6, "all six read the right way")
	check(r.get("reliable", false), "direction reliable")
	check_near(r.get("threshold", 0.0), 0.45 * r.get("median_peak", 0.0), 1e-6, "threshold is 45 % of the median peak")
	check(r.get("median_peak", 0.0) > 350 and r.get("median_peak", 0.0) < 430, "median peak about 400 (%s)" % r.get("median_peak"))


func test_calibration_noisy() -> void:
	var sy := Synth.new(2)
	sy.acc_noise = 0.6
	sy.gyro_noise = 12.0
	_moves(sy, [300, 520, 410, 350, 460, 380], [9, 14, 11, 10, 13, 12], false)
	var cal := _calibrate(sy)
	var r := cal.result()
	check_eq(cal.count(), 6, "noise does not add or lose moves")
	check_eq(r.get("mode"), "gyro", "gyro reads direction better than the noisy accelerometer")
	check(r.get("reliable", false), "gyro direction still reliable")
	var thr: float = r.get("threshold", 0.0)
	check(thr > 150 and thr < 220, "threshold near 45 %% of ~400 (%s)" % thr)


func test_calibration_soft() -> void:
	var sy := Synth.new(3)
	_moves(sy, [110, 120, 100, 115, 105, 125], [5, 5, 5, 5, 5, 5])
	var cal := _calibrate(sy)
	var r := cal.result()
	check(cal.is_done() and not r.is_empty(), "soft moves still calibrate")
	check_eq(r.get("threshold"), 60.0, "threshold clamps to 60 °/s")


func test_calibration_without_gyro() -> void:
	var sy := Synth.new(4)
	_moves(sy, [400, 400, 400, 400, 400, 400], [12, 13, 11, 12, 14, 12])
	var cal := _calibrate(sy, false)
	var r := cal.result()
	check_eq(r.get("mode"), "accel", "falls back to the accelerometer")
	check_eq(r.get("has_gyro"), false, "remembers there is no gyro")
	check(r.get("threshold", 0.0) >= 4.0 and r.get("threshold", 0.0) <= 25.0, "threshold in m/s² range")
	check_eq(r.get("axis"), 2, "screen z axis")
	# A gyro-less detector built from it rings on the same moves.
	var det := BellDetector.from_calibration(r, false)
	check_eq(det.mode, "accel", "detector in accel mode")


func test_calibration_unreliable_direction() -> void:
	var sy := Synth.new(5)
	for i in 6:
		sy.flick(0.5 + i * 0.8, i % 2 == 0, 300, 10)   # tilts the wrong way half the time
	var r := _calibrate(sy).result()
	check(not r.get("reliable", true), "mixed directions are not reliable")


func test_calibration_no_sensor() -> void:
	var cal := Calibrator.new()
	cal.start()
	var reasons := []
	cal.failed.connect(func(r): reasons.append(r))
	for i in 200:
		cal.feed(i / 60.0, Vector3.ZERO, Vector3.ZERO, false)
	check_eq(reasons, ["no_sensor"], "a silent sensor fails calibration with a reason")


func test_calibration_rearm_and_signals() -> void:
	var sy := Synth.new(6)
	_moves(sy, [400, 400, 400, 400, 400, 400], [12, 12, 12, 12, 12, 12])
	var cal := Calibrator.new()
	cal.start()
	var ups := []
	var done := []
	cal.move_detected.connect(func(_i, up, s): ups.append(up); check(s > 0.0 and s <= 1.0, "strength in 0..1"))
	cal.finished.connect(func(r): done.append(r))
	for t in sy.frames(0.0, 6.0):
		var s := sy.sample(t)
		cal.feed(t, s[0], s[1])
	check_eq(ups, [true, true, true, false, false, false], "each two-lobe move counts once")
	check_eq(done.size(), 1, "finished once")


func _detector(bpm := 120.0, mode := "gyro") -> BellDetector:
	var d := BellDetector.from_calibration({"mode": mode, "threshold": 180.0 if mode == "gyro" else 5.4, "axis": 0 if mode == "gyro" else 2, "up_sign": 1, "reliable": true}, mode == "gyro")
	d.set_bpm(bpm)
	return d


func _run(det: BellDetector, sy: Synth, t1: float, frames: Array[float] = []) -> Array:
	var rings := []
	var fr := frames if not frames.is_empty() else sy.frames(0.0, t1)
	for t in fr:
		var s := sy.sample(t)
		if det.feed(t, s[0], s[1]):
			rings.append([det.last_t, det.last_up])
	return rings


func test_one_flick_one_ring() -> void:
	for bpm: float in [90.0, 120.0, 160.0]:
		for mode: String in ["gyro", "accel"]:
			var sy := Synth.new(7)
			sy.acc_noise = 0.3
			sy.gyro_noise = 6.0
			var beat := 60.0 / bpm
			var starts := []
			for i in 16:
				var t0 := 1.0 + i * beat
				starts.append(t0)
				sy.flick(t0, i % 2 == 0, 400, 12, 0.22)
			var rings := _run(_detector(bpm, mode), sy, 1.0 + 17 * beat)
			check_eq(rings.size(), 16, "%s at %d bpm: 16 flicks ring 16 times" % [mode, bpm])
			if rings.size() == 16:
				var worst := 0.0
				for i in 16:
					worst = maxf(worst, absf(rings[i][0] - starts[i]))
				check(worst < 0.03, "%s at %d bpm: ring time within 30 ms of the flick (%.3f)" % [mode, bpm, worst])
				check_eq(rings[0][1], true, "first flick reads up")
				check_eq(rings[1][1], false, "second reads down")


func test_half_beat_bells_still_ring() -> void:
	var sy := Synth.new(8)
	var bpm := 100.0
	for i in 8:
		sy.flick(1.0 + i * 0.3, i % 2 == 0, 400, 12, 0.16)   # half a beat at 100 bpm
	var rings := _run(_detector(bpm), sy, 4.0)
	check_eq(rings.size(), 8, "bells half a beat apart all ring")


func test_taps_do_not_ring() -> void:
	for mode: String in ["gyro", "accel"]:
		var sy := Synth.new(9)
		sy.acc_noise = 0.3
		sy.gyro_noise = 5.0
		for i in 40:
			sy.tap(0.5 + i * 0.137, 30.0, 0.005 if i % 2 == 0 else 0.012, 30.0)
		var det := _detector(120.0, mode)
		var fr := sy.frames_hitting_taps(0.0, 6.5)
		var rings := []
		for t in fr:
			for e in sy.events:
				if e.t0 <= t and e.t0 > t - 1.0 / 60.0:
					det.note_touch(e.t0)
			var s := sy.sample(t)
			if det.feed(t, s[0], s[1]):
				rings.append(t)
		check_eq(rings.size(), 0, "%s: 40 hard thumb taps ring nothing" % mode)


func test_long_tap_bumps_do_not_ring_near_touches() -> void:
	# A phone whose sensor smears a tap over ~25 ms shows it in two readings.
	var sy := Synth.new(10)
	for i in 20:
		sy.tap(0.5 + i * 0.21, 20.0, 0.025, 10.0)
	var det := _detector(120.0, "accel")
	var rings := 0
	var touched := {}
	for t in sy.frames(0.0, 5.0):
		for e in sy.events:
			if e.t0 <= t and not touched.has(e.t0):
				touched[e.t0] = true
				det.note_touch(e.t0)
		var s := sy.sample(t)
		if det.feed(t, s[0], s[1]):
			rings += 1
	check_eq(rings, 0, "two-reading tap bumps right after a touch do not ring")


func test_full_ring_tap_and_tilt_together() -> void:
	for mode: String in ["gyro", "accel"]:
		var sy := Synth.new(11)
		var det := _detector(120.0, mode)
		for i in 6:
			sy.flick(1.0 + i, i % 2 == 0, 400, 12)
			sy.tap(1.0 + i, 25.0, 0.006, 20.0)
		var touched := {}
		var rings := 0
		for t in sy.frames_hitting_taps(0.0, 7.0):
			for e in sy.events:
				if e.kind == "tap" and e.t0 <= t and not touched.has(e.t0):
					touched[e.t0] = true
					det.note_touch(e.t0)
			var s := sy.sample(t)
			if det.feed(t, s[0], s[1]):
				rings += 1
		check_eq(rings, 6, "%s: a tap and a tilt together still ring once each" % mode)


func test_adapts_to_softer_flicks() -> void:
	var peaks := []
	for i in 40:
		peaks.append(lerpf(420.0, 170.0, i / 39.0))   # tired arms: 420 -> 170 °/s
	var counts := []
	for adapt: bool in [false, true]:
		var sy := Synth.new(12)
		sy.gyro_noise = 5.0
		for i in 40:
			sy.flick(1.0 + i * 0.75, i % 2 == 0, peaks[i], 12, 0.22)
		var det := _detector(80.0)
		det.threshold = 190.0
		det.base_threshold = 190.0
		det.adapt = adapt
		counts.append(_run(det, sy, 32.0).size())
	check(counts[0] < 40, "without adapting, soft flicks are lost (%d of 40)" % counts[0])
	check_eq(counts[1], 40, "adapting keeps every flick")


func test_adapt_has_a_floor() -> void:
	var det := _detector()
	det.threshold = 200.0
	det.base_threshold = 200.0
	var sy := Synth.new(13)
	sy.gyro_noise = 40.0   # heavy jiggling, no flicks
	var rings := _run(det, sy, 30.0)
	check(det.threshold >= 120.0 - 1e-6, "never below 60 %% of the calibration (%s)" % det.threshold)
	check_eq(rings.size(), 0, "jiggling does not ring")


func test_motion_reader() -> void:
	var m := MotionReader.new()
	check_eq(m.status(), "waiting", "waiting at first")
	var g := Vector3(0, -9.8, 0)
	m.process(Vector3(1, -9.8, 2), g, Vector3(0.5, 0, 0), 1.0 / 60.0)
	check_near(m.linear.x, 1.0, 1e-5, "gravity removed (x)")
	check_near(m.linear.z, 2.0, 1e-5, "gravity removed (z)")
	check_near(m.rotation_dps.x, rad_to_deg(0.5), 1e-3, "rad/s -> °/s")
	# No gravity vector from the platform: low-pass estimate.
	var f := MotionReader.new()
	for i in 120:
		f.process(Vector3(0, -9.8, 0), Vector3.ZERO, Vector3.ZERO, 1.0 / 60.0)
	check(f.linear.length() < 0.01, "steady phone reads no linear acceleration")
	f.process(Vector3(0, -9.8, 8), Vector3.ZERO, Vector3.ZERO, 1.0 / 60.0)
	check(f.linear.z > 6.0, "a sudden push shows up (%s)" % f.linear.z)
	check_eq(f.status(), "no_gyro", "accelerometer only")
	var none := MotionReader.new()
	for i in 90:
		none.process(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 1.0 / 60.0)
	check_eq(none.status(), "no_sensor", "a missing sensor is detected")
	check(not none.available(), "not available")


func test_motion_log_replays() -> void:
	var sy := Synth.new(14)
	sy.gyro_noise = 5.0
	for i in 10:
		sy.flick(1.0 + i * 0.6, i % 2 == 0, 350, 12)
		sy.tap(1.3 + i * 0.6, 25.0, 0.006, 20.0)
	var ml := MotionLog.new()
	var det := _detector(100.0)
	var direct := PackedFloat64Array()
	var touched := {}
	for t in sy.frames_hitting_taps(0.0, 8.0):
		for e in sy.events:
			if e.kind == "tap" and e.t0 <= t and not touched.has(e.t0):
				touched[e.t0] = true
				det.note_touch(e.t0)
				ml.add_touch(e.t0)
		var s := sy.sample(t)
		ml.add_reading(t, s[0], s[1])
		if det.feed(t, s[0], s[1]):
			direct.append(det.last_t)
			ml.add_ring(det.last_t)
	check_eq(direct.size(), 10, "ten flicks, ten rings, taps ignored")
	var path := "user://core_test_motion.csv"
	check_eq(ml.save(path), OK, "saved")
	var back := MotionLog.load_file(path)
	check_eq(back.size(), ml.size(), "all rows back")
	check_eq(back.rings().size(), 10, "recorded rings")
	var again := back.replay(_detector(100.0))
	check_eq(again.size(), direct.size(), "replay rings as often")
	var worst := 0.0
	for i in mini(again.size(), direct.size()):
		worst = maxf(worst, absf(again[i] - direct[i]))
	check(worst < 0.001, "replay rings at the same times (%.5f)" % worst)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
