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


func test_calibration_ignores_a_tap() -> void:
	# The reviewer's case: 5 tilts and a thumb tap. The tap has no rotation: it is ignored, the
	# player is asked for one more tilt, and the gyro calibration stands.
	var sy := Synth.new(8)
	sy.gyro_noise = 3.0
	for i in 3:
		sy.flick(0.5 + i * 0.8, true, 400, 12)
	sy.tap(2.9, 25.0, 0.005, 10.0)
	for i in 2:
		sy.flick(3.7 + i * 0.8, false, 400, 12)
	var cal := Calibrator.new()
	cal.start()
	var ignored := []
	cal.move_ignored.connect(func(why): ignored.append(why))
	for t in sy.frames_hitting_taps(0.0, 5.4):
		var smp := sy.sample(t)
		cal.feed(t, smp[0], smp[1])
	check_eq(ignored, ["no_rotation"], "the tap is ignored with a reason")
	check_eq(cal.count(), 5, "5 tilts counted")
	check(not cal.is_done(), "one more tilt is needed")
	check(not cal.expecting_up(), "and it is a down tilt")
	sy.flick(5.5, false, 400, 12)
	for t in sy.frames(5.4, 6.5):
		var smp := sy.sample(t)
		cal.feed(t, smp[0], smp[1])
	var r := cal.result()
	check(cal.is_done(), "done after the sixth tilt")
	check_eq(r.get("mode"), "gyro", "still the gyroscope")
	check(r.get("reliable", false), "and reliable")
	# A gyro that barely reacts: after 3 ignored moves every move counts, falling back to accel.
	var weak := Synth.new(9)
	weak.gyro_noise = 3.0
	for i in 9:
		weak.flick(0.5 + i * 0.8, i < 6, 40, 12)   # 40 °/s: below the rotation lobe
	var cw := Calibrator.new()
	cw.start()
	for t in weak.frames(0.0, 8.0):
		var smp := weak.sample(t)
		cw.feed(t, smp[0], smp[1])
	check_eq(cw.ignored_total, 3, "three moves asked again")
	check(cw.is_done(), "then the calibration finishes")
	check_eq(cw.result().get("mode"), "accel", "on the accelerometer")


func test_calibration_measures_rise_time() -> void:
	for fps: float in [60.0, 120.0]:
		var sy := Synth.new(10)
		sy.fps = fps
		sy.gyro_noise = 4.0
		_moves(sy, [400, 420, 380, 410, 390, 400], [12, 12, 12, 12, 12, 12])
		var r := _calibrate(sy).result()
		check_near(float(r.get("rise_time", 0.0)), 0.045, 0.008, "%d fps: rise time about 45 ms (%.3f)" % [fps, r.get("rise_time", 0.0)])


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


func _held_run(det: BellDetector, sy: Synth, t1: float, hz: float, fps: float) -> Array:
	var rings := []
	var touched := {}
	for f in sy.held_frames(0.0, t1, hz, fps):
		for e in sy.events:
			if e.kind == "tap" and e.t0 <= f[0] and not touched.has(e.t0):
				touched[e.t0] = true
				det.note_touch(e.t0)
		if det.feed(f[0], f[1], f[2]):
			rings.append(det.last_t)
	return rings


func test_sensor_rates_and_frame_rates() -> void:
	# Phones deliver sensors at 50-200 Hz while the game draws at 60-120 fps.
	for hz: float in [50.0, 100.0, 200.0]:
		for fps: float in [60.0, 90.0, 120.0]:
			for mode: String in ["gyro", "accel"]:
				var what := "%s %d Hz / %d fps" % [mode, hz, fps]
				# Flicks while walking.
				var sy := Synth.new(int(hz + fps))
				sy.acc_noise = 0.3
				sy.gyro_noise = 5.0
				sy.walk_acc = 1.5
				sy.walk_gyro = 25.0
				var starts := []
				for i in 12:
					starts.append(1.0 + i * 0.6)
					sy.flick(starts[-1], i % 2 == 0, 400, 12, 0.2)
				var rings := _held_run(_detector(100.0, mode), sy, 9.0, hz, fps)
				check_eq(rings.size(), 12, "%s: 12 flicks while walking ring 12 times" % what)
				if rings.size() == 12:
					var worst := 0.0
					for i in 12:
						worst = maxf(worst, absf(rings[i] - starts[i]))
					check(worst < 0.035, "%s: ring times within 35 ms (%.3f)" % [what, worst])
				# Hard taps, one sample (5 ms) or smeared (12 ms).
				var ty := Synth.new(int(hz * fps))
				ty.acc_noise = 0.3
				ty.gyro_noise = 5.0
				for i in 30:
					ty.tap(0.5 + i * 0.2, 30.0, 0.005 if i % 2 == 0 else 0.012, 60.0 if mode == "gyro" else 30.0)
				check_eq(_held_run(_detector(120.0, mode), ty, 7.0, hz, fps).size(), 0, "%s: 30 hard taps ring nothing" % what)


func test_slow_flicks_at_fast_tempo_ring_once() -> void:
	for bpm: float in [68.0, 100.0, 140.0, 160.0]:
		for dur: float in [0.2, 0.3, 0.4, 0.5]:
			for mode: String in ["gyro", "accel"]:
				var sy := Synth.new(3)
				sy.gyro_noise = 5.0
				sy.acc_noise = 0.3
				var beat := 60.0 / bpm
				for i in 8:
					sy.flick(1.0 + i * beat * 2.0, i % 2 == 0, 400, 12, dur)
				var rings := _run(_detector(bpm, mode), sy, 1.0 + 17 * beat)
				check_eq(rings.size(), 8, "%s at %d bpm, %.1f s flicks: 8 flicks, 8 rings" % [mode, bpm, dur])


func test_body_turn_does_not_ring() -> void:
	var sy := Synth.new(15)
	sy.gyro_noise = 5.0
	sy.turn(0.5, 250.0, 0.5)
	sy.turn(1.5, -300.0, 0.4)
	sy.turn(2.5, 400.0, 0.6)
	check_eq(_run(_detector(120.0, "gyro"), sy, 4.0).size(), 0, "turning the body (yaw) does not ring")
	var walk := Synth.new(16)
	walk.walk_acc = 3.0
	walk.walk_gyro = 60.0
	check_eq(_run(_detector(120.0, "gyro"), walk, 10.0).size(), 0, "walking sway does not ring (gyro)")
	check_eq(_run(_detector(120.0, "accel"), walk, 10.0).size(), 0, "walking bounce does not ring (accel)")


func test_ring_strength_follows_the_flick() -> void:
	var d := _detector(100.0)   # calibrated 180 °/s: a typical flick peaks at 400 °/s
	check_near(d.strength_of(400.0), 0.5, 1e-6, "the typical flick is 0.5")
	check_near(d.strength_of(200.0), 0.25, 1e-6, "half as hard is 0.25")
	check_eq(d.strength_of(900.0), 1.0, "twice as hard or more is 1")
	for mode: String in ["gyro", "accel"]:
		var last := -1.0
		for k in 4:
			var sy := Synth.new(30 + k)
			sy.jitter = 0.0
			sy.flick(1.0, true, 220.0 + k * 150.0, 6.5 + k * 3.0, 0.2)
			var det := _detector(100.0, mode)
			check_eq(_run(det, sy, 2.0).size(), 1, "%s flick %d rings" % [mode, k])
			check(det.last_strength >= last, "%s: a harder flick is at least as strong (%.2f after %.2f)" % [mode, det.last_strength, last])
			check(det.last_strength >= 0.0 and det.last_strength <= 1.0, "in 0..1")
			last = det.last_strength
		check(last > 0.3, "%s: the hardest flick rings strong (%.2f)" % [mode, last])


func test_typical_flick_rings_at_half_strength() -> void:
	# The fast path fires before the flick peaks; the strength is predicted from the rising slope,
	# so the player's typical calibrated flick is about 0.5 at every sensor and frame rate.
	var cal_sy := Synth.new(11)
	cal_sy.gyro_noise = 4.0
	cal_sy.acc_noise = 0.2
	_moves(cal_sy, [400, 400, 400, 400, 400, 400], [12, 12, 12, 12, 12, 12])
	var calib := _calibrate(cal_sy).result()
	check_eq(calib.get("mode"), "gyro", "calibrated on the gyro")
	var rows := []
	for hz: float in [100.0, 200.0]:
		for fps: float in [60.0, 120.0]:
			for share: float in [1.0, 0.6, 1.6]:
				var det := BellDetector.from_calibration(calib, true)
				det.set_bpm(100.0)
				det.adapt = false
				var sy := Synth.new(int(hz + fps + share * 10.0))
				sy.gyro_noise = 4.0
				for i in 20:
					sy.flick(1.0 + i * 0.7013, i % 2 == 0, 400.0 * share, 12.0, 0.2)
				var got: Array[float] = []
				for f in sy.held_frames(0.0, 15.5, hz, fps):
					if det.feed(f[0], f[1], f[2]):
						got.append(det.last_strength)
				check_eq(got.size(), 20, "%d Hz / %d fps / %.1f×: every flick rings" % [hz, fps, share])
				if got.is_empty():
					continue
				got.sort()
				var med := got[got.size() >> 1]
				var want := 0.5 * share
				rows.append("%3d Hz %3d fps %.1f×: median %.2f (%.2f..%.2f)" % [hz, fps, share, med, got[0], got[-1]])
				check(absf(med - want) <= 0.12, "%d Hz / %d fps: a %.1f× flick rings at about %.2f (median %.2f, %.2f..%.2f)" % [hz, fps, share, want, med, got[0], got[-1]])
				if share == 1.0:
					var soft := got.filter(func(x): return x < 0.35).size()
					check(soft <= 2, "%d Hz / %d fps: typical flicks rarely ring soft (%d of 20)" % [hz, fps, soft])
	print("  ring strength (gyro, calibrated at 400 °/s):\n    " + "\n    ".join(rows))


# Seconds from the moment the signal truly crosses the threshold to the frame where the ring
# (and so the bell sound) fires, for each flick.
const CONFIRM_BOUND := 0.030   # BellDetector.CONFIRM plus a margin


func _sound_lags(mode: String, hz: float, fps: float, peak_share: float) -> Array[float]:
	var det := _detector(100.0, mode)
	det.adapt = false
	var sy := Synth.new(int(hz) + int(fps))
	sy.jitter = 0.0
	sy.acc_noise = 0.0
	sy.gyro_noise = 0.0
	var starts := []
	for i in 10:
		starts.append(1.0 + i * 0.7013)   # not a multiple of the frame or sensor period: every phase
		sy.flick(starts[-1], true, det.threshold * peak_share, det.threshold * peak_share, 0.2)
	var lags: Array[float] = []
	var axis := det.axis
	for f in sy.held_frames(0.0, 8.5, hz, fps):
		if det.feed(f[0], f[1], f[2]):
			# the true crossing, from the noise-free signal
			var t0: float = starts[lags.size()] if lags.size() < starts.size() else f[0]
			var tc := t0
			while tc < f[0]:
				var smp := sy.sample(tc)
				if absf((smp[1] if mode == "gyro" else smp[0])[axis]) > det.threshold:
					break
				tc += 0.0005
			lags.append(f[0] - tc)
	return lags


func test_bell_sound_lag() -> void:
	# The sound plays when a ring is confirmed. Gyro fast path: a reading over the threshold rings at
	# once when an earlier reading (>= 5 ms before) caught the flick on its rising slope; otherwise the
	# 25 ms rule. With 25 ms alone the median lag was 35-60 ms; with the fast path it is about one
	# frame plus one sensor interval whenever the readings are dense enough to catch the slope.
	var rows := []
	for hz: float in [50.0, 100.0, 200.0]:
		for fps: float in [60.0, 120.0]:
			for share: float in [1.5, 2.2, 3.0]:
				var what := "gyro %d Hz / %d fps / %.1f×" % [hz, fps, share]
				var g := _sound_lags("gyro", hz, fps, share)
				check_eq(g.size(), 10, "%s: every flick rings" % what)
				if g.size() != 10:
					continue
				g.sort()
				var med := g[5]
				rows.append("%3d Hz %3d fps %.1f×: median %.1f ms, worst %.1f ms" % [hz, fps, share, med * 1000.0, g[9] * 1000.0])
				var slow := CONFIRM_BOUND + 2.0 / hz + 1.0 / fps
				check(g[9] <= slow, "%s: never later than the 25 ms rule allows (worst %.1f ms)" % [what, g[9] * 1000.0])
				if hz >= 100.0 and share <= 2.2:
					var quick := 1.0 / fps + 1.0 / hz + 0.006
					check(med <= quick, "%s: median lag about a frame + a sensor interval (%.1f <= %.1f ms)" % [what, med * 1000.0, quick * 1000.0])
	print("  bell sound lag (gyro):\n    " + "\n    ".join(rows))


func test_knocks_on_the_tilt_axis_do_not_ring() -> void:
	# The gyro fast path must not turn a sharp knock into a ring: a 5-15 ms jolt of up to twice the
	# threshold right on the calibrated axis, at every sensor and frame rate.
	for hz: float in [50.0, 100.0, 200.0, 400.0]:
		for fps: float in [60.0, 90.0, 120.0]:
			for dur: float in [0.005, 0.010, 0.015]:
				var det := _detector(100.0)
				var sy := Synth.new(int(hz * fps * dur * 1000.0))
				sy.gyro_noise = 5.0
				for i in 30:
					sy.tap(1.0 + i * 0.4137, 25.0, dur, det.threshold * 2.0, 0)
				var n := _held_run(det, sy, 14.0, hz, fps).size()
				check_eq(n, 0, "%d Hz / %d fps: 30 knocks of %d ms on the tilt axis ring 0 times" % [hz, fps, int(dur * 1000.0)])


func test_held_readings_are_stamped_earlier() -> void:
	# A 50 Hz sensor at 120 fps: readings are held for ~2.4 frames, so each is ~10 ms old on average.
	var sy := Synth.new(17)
	sy.jitter = 0.0
	for i in 10:
		sy.flick(1.0 + i * 0.7, i % 2 == 0, 400, 12, 0.2)
	var det := _detector(100.0)
	var fast := _run(_detector(100.0), sy, 8.0)   # 60 fps, instant readings
	var held := _held_run(det, sy, 8.0, 50.0, 120.0)
	check(det.sample_interval > 0.015 and det.sample_interval < 0.025, "measures the 20 ms sensor interval (%.4f)" % det.sample_interval)
	check_eq(fast.size(), 10, "instant readings ring every flick")
	check_eq(held.size(), 10, "held readings ring every flick")
	if fast.size() != 10 or held.size() != 10:
		return
	var err_fast := 0.0
	var err_held := 0.0
	for i in 10:
		err_fast += (float(fast[i][0]) - (1.0 + i * 0.7)) / 10.0
		err_held += (float(held[i]) - (1.0 + i * 0.7)) / 10.0
	check(absf(err_held - err_fast) < 0.012, "held-sample rings land where instant ones do (%.4f vs %.4f)" % [err_held, err_fast])
