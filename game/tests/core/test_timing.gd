extends TestCase
## LatencyTest, Conductor and InputRouter.

const FIX := "res://tests/core/fixtures/"


func test_latency_median() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var clicks := LatencyTest.click_times(100.0, 16, 1.0)
	var lt := LatencyTest.new()
	for c in clicks:
		lt.add_click(c)
	for i in 16:
		lt.add_tap(clicks[i] + 0.085 + rng.randfn(0.0, 0.012))
	lt.add_tap(clicks[5] + 0.3)     # a stray double tap
	var r := lt.result()
	check_near(r.offset, 0.085, 0.01, "median offset ~85 ms")
	check(r.spread < 0.02, "spread small (%s)" % r.spread)
	check(r.ok, "good test")
	check_eq(r.count, 16, "stray tap dropped")
	var early := LatencyTest.measure(clicks, PackedFloat64Array([clicks[0] - 0.03, clicks[1] - 0.03, clicks[2] - 0.02, clicks[3] - 0.04, clicks[4] - 0.03, clicks[5] - 0.03]))
	check_near(early.offset, -0.03, 1e-6, "early tappers get a negative offset")
	var few := LatencyTest.measure(clicks, PackedFloat64Array([clicks[0] + 0.1, clicks[1] + 0.1]))
	check(not few.ok, "two taps are not enough")
	var messy := LatencyTest.new()
	messy.clicks = clicks
	for i in 16:
		messy.add_tap(clicks[i] + rng.randf_range(-0.12, 0.2))
	check(not messy.result().ok, "random taps are rejected as too uneven")
	check_eq(LatencyTest.measure(clicks, PackedFloat64Array()).count, 0, "no taps")


func _conductor() -> Conductor:
	var c := Conductor.new()
	c.audio_offset = 0.0
	tree.root.add_child(c)
	return c


func test_conductor_manual_clock_monotonic() -> void:
	var c := _conductor()
	c.use_manual_clock(true)
	var song := SongData.load_file(FIX + "basic.json")
	var fin := []
	c.finished.connect(func(): fin.append(true))
	c.play(song, false, -1.0)
	check_near(c.song_time(), -1.0, 1e-9, "lead-in starts before 0")
	var last := c.song_time()
	var mono := true
	for i in 200:
		c.advance(1.0 / 60.0)
		var t := c.song_time()
		mono = mono and t >= last
		last = t
	check(mono, "never goes backwards")
	check_near(last, -1.0 + 200.0 / 60.0, 1e-6, "follows the manual clock")
	c.pause()
	c.advance(1.0)
	check_near(c.song_time(), last, 1e-9, "paused clock does not move")
	c.resume()
	c.advance(0.5)
	check_near(c.song_time(), last + 0.5, 1e-6, "resumes from where it paused")
	c.seek(10.0)
	check_near(c.song_time(), 10.0, 1e-9, "seek")
	check_near(c.current_beat(), song.beat_at(10.0), 1e-6, "current beat")
	for i in 30 * 60:
		c.advance(1.0 / 60.0)
	check_eq(fin.size(), 1, "finished once after the song's length")
	c.queue_free()


func test_conductor_frame_clock_fallback() -> void:
	# Headless tests run the dummy audio driver: the song clock must still run on frame time,
	# smoothly and never backwards.
	var c := _conductor()
	var song := SongData.load_file(FIX + "basic.json")
	c.play(song)
	var last := c.song_time()
	var mono := true
	var t0 := Time.get_ticks_usec()
	for i in 20:
		await tree.process_frame
		var t := c.song_time()
		mono = mono and t >= last
		last = t
	var wall := (Time.get_ticks_usec() - t0) / 1e6
	check(mono, "never backwards")
	check(last > 0.0, "time moves (%s)" % last)
	check_near(last, wall, 0.1, "follows real time")
	c.pause()
	var paused_at := c.song_time()
	await tree.process_frame
	await tree.process_frame
	check_near(c.song_time(), paused_at, 1e-6, "pause holds the clock")
	c.resume()
	await tree.process_frame
	check(c.song_time() >= paused_at, "resume carries on from the pause")
	c.queue_free()


func test_conductor_follows_audio_clock() -> void:
	# A generated tone as the music: if the audio driver advances playback, song time must track
	# playback position minus latency within one frame; otherwise the frame clock is used.
	# The dummy driver (headless) never mixes, so it would never release the playback: skip there.
	if AudioServer.get_driver_name() == "Dummy":
		return
	var c := _conductor()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2 * 4)
	wav.data = data
	var song := SongData.from_dict({"id": "tone", "bpm": 120, "offset": 0.0, "length": 4.0, "charts": {"easy": []}})
	c.play(song)
	c.player.stream = wav
	c.seek(0.0)
	var last := -INF
	var mono := true
	for i in 30:
		await tree.process_frame
		var t := c.song_time()
		mono = mono and t >= last
		last = t
	check(mono, "never backwards with a real stream")
	if c.player.playing and c.player.get_playback_position() > 0.0:
		var audio_t := c.player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		check_near(c.song_time(), audio_t, 0.1, "tracks the audio clock")
	c.stop()
	c.player.stream = null
	c.queue_free()
	await tree.process_frame


## A Conductor whose clocks are simulated: real time moves in jittery frames, and the "audio
## driver" mixes in 512-sample chunks, starts 10 ms late and reports latency.
class FakeConductor extends Conductor:
	var now_us := 1_000_000
	var audio_on := false
	var audio_t0 := 0.0
	var audio_p0 := 0.0
	var start_delay := 0.010
	var lat := 0.030
	var rng := RandomNumberGenerator.new()

	func secs() -> float:
		return now_us / 1e6

	func _ticks() -> int:
		return now_us

	func _latency() -> float:
		return lat

	func _audio_playing() -> bool:
		return audio_on

	func _start_audio(t: float) -> void:
		_audio_started = true
		audio_on = true
		audio_t0 = secs() + start_delay
		audio_p0 = maxf(0.0, t + _audio_lead())

	func true_pos() -> float:
		return audio_p0 + maxf(0.0, secs() - audio_t0)

	## What the player hears right now, in song time.
	func heard() -> float:
		return true_pos() - lat - _offset_used

	func _audio_clock() -> float:
		var el := maxf(0.0, secs() - audio_t0)
		var chunk := 512.0 / 44100.0
		var mixed := floorf(el / chunk) * chunk
		return audio_p0 + mixed + (el - mixed) + rng.randf_range(-0.001, 0.001)

	func pause() -> void:
		super()
		audio_p0 = true_pos()
		audio_t0 = INF

	func resume() -> void:
		super()
		audio_t0 = secs()


func test_conductor_tracks_simulated_audio() -> void:
	for offset: float in [0.0, 0.08, -0.03]:
		var c := FakeConductor.new()
		c.audio_offset = offset
		c.rng.seed = 5
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		c.play(SongData.from_dict({"id": "x", "bpm": 120, "offset": 0.0, "length": 60.0, "charts": {}}), false, -0.5)
		var last := c.song_time()
		var mono := true
		var worst := 0.0
		var settled_from := INF
		for i in 60 * 30:
			var dt := 1.0 / 60.0 + rng.randf_range(-0.004, 0.004)
			if i == 400:
				dt = 0.15            # a hitch (garbage collection, a notification)
			c.now_us += int(dt * 1e6)
			if i == 900:
				c.pause()
			if i == 1000:
				c.resume()
			c._process(dt)
			# Inputs arrive between frames: check the sub-frame time too.
			var probe_us := int(rng.randf_range(0.0, 0.016) * 1e6)
			c.now_us += probe_us
			var t := c.song_time()
			mono = mono and t >= last
			last = t
			if c.audio_on and is_inf(settled_from) and c.secs() > c.audio_t0:
				settled_from = c.secs() + 0.5
			if c.secs() > settled_from and not c.is_paused() and absi(i - 1000) > 30:
				worst = maxf(worst, absf(t - c.heard()))
			c.now_us -= probe_us
		check(mono, "offset %s: never backwards through a hitch and a pause" % offset)
		check(worst < 0.004, "offset %s: song time within 4 ms of what the player hears (worst %.4f s)" % [offset, worst])
		c.free()


func test_conductor_resyncs_after_pause() -> void:
	var c := FakeConductor.new()
	c.audio_offset = 0.0
	c.play(SongData.from_dict({"id": "x", "bpm": 120, "offset": 0.0, "length": 60.0, "charts": {}}), false, 0.0)
	for i in 120:
		c.now_us += 16667
		c._process(1.0 / 60.0)
	c.pause()
	var at_pause := c.song_time()
	c.now_us += 3_000_000
	check_near(c.song_time(), at_pause, 1e-9, "paused: song time holds")
	c.resume()
	var worst := 0.0
	for i in 60:
		c.now_us += 16667
		c._process(1.0 / 60.0)
		worst = maxf(worst, absf(c.song_time() - c.heard()))
	check(worst < 0.003, "after resume still within 3 ms of the music (%.4f)" % worst)
	c.free()


# ---------------------------------------------------------------- InputRouter


var _now := 0.0


func _router(session: Session) -> InputRouter:
	var r := InputRouter.new()
	r.detector = BellDetector.from_calibration({"mode": "gyro", "threshold": 150.0, "axis": 0, "up_sign": 1})
	r.read_motion = false
	r.session = session
	r.time_source = func() -> float: return _now
	r.buttons_rect = Rect2(0, 1200, 720, 240)
	tree.root.add_child(r)
	return r


func _touch(r: InputRouter, x: float, pressed: bool, index := 0, y := 1300.0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(x, y)
	e.pressed = pressed
	e.index = index
	r._input(e)


func _drag(r: InputRouter, x: float, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = Vector2(x, 1300)
	e.index = index
	r._input(e)


func _key(r: InputRouter, code: Key, pressed := true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	r._input(e)


func _song(chart: Array) -> SongData:
	return SongData.from_dict({"id": "r", "bpm": 120, "offset": 1.0, "charts": {"easy": chart}})


func test_router_touches_and_holds() -> void:
	var s := Session.new(_song([{"b": 0, "k": "step", "lane": 0}, {"b": 2, "k": "step", "lane": 2}, {"b": 4, "k": "hold", "lane": 1, "len": 2}]), "easy")
	var r := _router(s)
	var lanes := []
	r.stepped.connect(func(l): lanes.append(l))
	_now = 1.0
	_touch(r, 100, true)
	check(r.is_pressed(0), "lane 0 pressed")
	_touch(r, 100, false)
	check(not r.is_pressed(0), "lane 0 released")
	_now = 2.01
	_touch(r, 700, true, 1)
	_touch(r, 700, false, 1)
	_now = 3.0
	_touch(r, 360, true, 2)
	_now = 3.5
	_touch(r, 100, true, 3, 500)      # outside the button row: ignored
	_now = 4.0
	s.update(_now)
	_touch(r, 360, false, 2)
	check_eq(lanes, [0, 2, 1], "lanes from x")
	check_eq(s.stats.perfect, 3, "three perfect hits")
	check_eq(s.stats.held, 1, "hold kept through the router")
	r.queue_free()


func test_router_drag_swipes() -> void:
	var s := Session.new(_song([{"b": 0, "k": "swipe", "dir": 1}, {"b": 2, "k": "swipe", "dir": -1}]), "easy")
	var r := _router(s)
	var dirs := []
	r.swiped.connect(func(d): dirs.append(d))
	_now = 0.95
	_touch(r, 100, true)
	_now = 1.0
	_drag(r, 200)
	check(dirs.is_empty(), "a short drag is not a swipe")
	_drag(r, 400)
	_drag(r, 600)
	_touch(r, 600, false)
	_now = 2.0
	_touch(r, 650, true, 4)
	_drag(r, 300, 4)
	_touch(r, 300, false, 4)
	check_eq(dirs, [1, -1], "one swipe per drag, both ways")
	check_eq(s.stats.perfect, 2, "both swipes judged")
	r.queue_free()


func test_router_keys() -> void:
	var s := Session.new(_song([{"b": 0, "k": "step", "lane": 0}, {"b": 1, "k": "step", "lane": 1}, {"b": 2, "k": "step", "lane": 2}, {"b": 3, "k": "bell"}, {"b": 4, "k": "swipe", "dir": -1}, {"b": 5, "k": "swipe", "dir": 1}]), "easy")
	var r := _router(s)
	var rang := []
	var paused := []
	r.rang.connect(func(x): rang.append(x))
	r.pause_requested.connect(func(): paused.append(true))
	var keys := [KEY_A, KEY_S, KEY_D]
	for i in 3:
		_now = 1.0 + i * 0.5
		_key(r, keys[i])
		_key(r, keys[i], false)
	_now = 2.5
	_key(r, KEY_SPACE)
	_now = 3.0
	_key(r, KEY_Q)
	_now = 3.5
	_key(r, KEY_E)
	_key(r, KEY_ESCAPE)
	check_eq(s.stats.perfect, 6, "A S D, Space, Q, E all reach the session")
	check_eq(rang.size(), 1, "Space rang")
	check_eq(rang[0].quality, "perfect", "with the ring result")
	check_eq(paused.size(), 1, "Esc asks to pause")
	r.queue_free()


func test_router_motion_and_slam() -> void:
	var s := Session.new(_song([{"b": 0, "k": "bell"}, {"b": 2, "k": "bell"}]), "easy")
	var r := _router(s)
	var rang := []
	r.rang.connect(func(x): rang.append(x))
	# A tilt through the detector: 60 fps readings of a flick starting at 1.0 s.
	for i in 30:
		var t := 0.95 + i / 60.0
		var dt := t - 1.0
		var g := 400.0 * sin(PI * dt / 0.09) if dt >= 0.0 and dt < 0.09 else 0.0
		r.feed_motion(t, Vector3.ZERO, Vector3(g, 0, 0))
	check_eq(rang.size(), 1, "one tilt, one ring")
	check_eq(rang[0].get("judgement"), "perfect", "tilt judged on its crossing time")
	# Slam session: tilts ignored, Left + Right ring.
	var sl := Session.new(_song([{"b": 0, "k": "bell"}]), "easy", "light", {"slam": true})
	var r2 := _router(sl)
	var rang2 := []
	r2.rang.connect(func(x): rang2.append(x))
	r2.feed_motion(1.0, Vector3.ZERO, Vector3(500, 0, 0))
	r2.feed_motion(1.016, Vector3.ZERO, Vector3(500, 0, 0))
	check(rang2.is_empty(), "slam mode ignores the tilt")
	_now = 0.99
	_touch(r2, 50, true, 0)
	_now = 1.02
	_touch(r2, 690, true, 1)
	check_eq(rang2.size(), 1, "Left + Right rang the bell")
	check_eq(sl.stats.perfect, 1, "slam bell judged")
	r.queue_free()
	r2.queue_free()


func test_router_real_event_path() -> void:
	# Through the viewport, as the engine delivers it.
	await tree.process_frame   # let earlier tests' routers go away
	var s := Session.new(_song([{"b": 0, "k": "step", "lane": 1}]), "easy")
	var r := _router(s)
	_now = 1.0
	var e := InputEventScreenTouch.new()
	e.position = Vector2(360, 1300)
	e.pressed = true
	tree.root.push_input(e, true)   # already in viewport coordinates
	check_eq(s.stats.perfect, 1, "a pushed touch reaches the session")
	r.queue_free()
