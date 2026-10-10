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


func test_latency_wide_range_at_test_tempo() -> void:
	# At the test tempo (70 bpm, 0.857 s) any delay within ±0.5 s is read correctly, even though a
	# tap 0.45 s late is also 0.41 s early for the next click.
	check_eq(LatencyTest.BPM, 70.0, "test tempo")
	check_eq(LatencyTest.MAX_PAIR, 0.5, "the same ±0.5 s range as Profile's audio offset")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var clicks := LatencyTest.click_times(LatencyTest.BPM, 12, 0.6)
	for d: float in [0.0, 0.12, 0.3, 0.38, 0.45, 0.49, -0.1, -0.3]:
		for skip_last in [false, true]:
			var taps := PackedFloat64Array()
			for i in 12:
				if skip_last and i == 11:
					continue
				taps.append(clicks[i] + d + rng.randfn(0.0, 0.01))
			var r := LatencyTest.measure(clicks, taps)
			check(r.ok, "delay %.2f s%s: a good test" % [d, " (last click missed)" if skip_last else ""])
			check_near(r.offset, d, 0.015, "delay %.2f s%s: read as %.3f" % [d, " (last click missed)" if skip_last else "", r.offset])
	# The old 100 bpm clicks paired a 0.35 s delay with the wrong click; at 70 bpm it cannot.
	var taps2 := PackedFloat64Array()
	for i in 12:
		taps2.append(clicks[i] + 0.35)
	var r2 := LatencyTest.measure(clicks, taps2)
	check_near(r2.offset, 0.35, 1e-6, "0.35 s is read as 0.35 s")
	check_eq(r2.count, 12, "every tap paired")


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


func test_router_two_thumb_stomp() -> void:
	var s := Session.new(_song([{"b": 0, "k": "stomp", "lane": 1}, {"b": 2, "k": "stomp", "lane": 0}]), "easy")
	var r := _router(s)
	var landed := []
	s.stomp_landed.connect(func(_n, j, _o, both): landed.append([j, both]))
	_now = 1.0
	_touch(r, 300, true, 1)        # both thumbs on the middle button, 30 ms apart
	_now = 1.03
	_touch(r, 420, true, 2)
	check(r.is_pressed(1), "middle held")
	_touch(r, 300, false, 1)
	_touch(r, 420, false, 2)
	_now = 2.0
	_touch(r, 60, true, 3)         # one thumb only on Left
	_touch(r, 60, false, 3)
	_now = 2.2
	s.update(_now)
	check_eq(landed, [["perfect", true], ["good", false]], "two thumbs stomp, one thumb is a weaker hit")
	r.queue_free()


func test_router_keys() -> void:
	var s := Session.new(_song([{"b": 0, "k": "step", "lane": 0}, {"b": 1, "k": "step", "lane": 1}, {"b": 2, "k": "step", "lane": 2}, {"b": 3, "k": "bell"}, {"b": 4, "k": "stomp", "lane": 1}, {"b": 5, "k": "stomp", "lane": 2}]), "easy")
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
	_key(r, KEY_S)
	_key(r, KEY_K)
	_key(r, KEY_S, false)
	_key(r, KEY_K, false)
	_now = 3.5
	_key(r, KEY_D)
	_key(r, KEY_L)
	_key(r, KEY_ESCAPE)
	check_eq(s.stats.perfect, 6, "A S D, Space, S+K and D+L stomps all reach the session")
	check_eq(s.stats.one_thumb, 0, "the J K L keys are the second thumb")
	check_eq(rang.size(), 1, "Space rang")
	check_eq(rang[0].quality, "perfect", "with the ring result")
	check_eq(rang[0].strength, 0.5, "a keyboard ring has middle strength")
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
	var st: float = rang[0].get("strength", -1.0)
	check(st > 0.5 and st <= 1.0, "a 400 °/s flick over a 150 °/s threshold rings strong (%.2f)" % st)
	check_near(st, r.detector.last_strength, 1e-6, "the rang payload carries the detector's strength")
	# Slam session: tilts ignored, Left + Right ring.
	var sl := Session.new(_song([{"b": 0, "k": "bell"}]), "easy", {"slam": true})
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
	check_eq(rang2[0].strength, 0.5, "a slam ring has middle strength")
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


func test_router_drag_and_focus_loss() -> void:
	await tree.process_frame
	var s := Session.new(_song([{"b": 0, "k": "step", "lane": 0}, {"b": 2, "k": "hold", "lane": 1, "len": 4}]), "easy")
	var r := _router(s)
	_now = 1.0
	_touch(r, 100, true)
	_now = 1.15                    # a finger sliding across the row is not a new press
	_drag(r, 500)
	_touch(r, 500, false)
	check_eq(s.notes[0].judgement, "perfect", "the step is judged when the finger went down")
	check_eq(s.stats.wrong, 0, "sliding across the row is no wrong step")
	_now = 2.0
	_touch(r, 360, true, 3)
	check(r.is_pressed(1), "holding lane 1")
	_now = 2.5
	r.release_all()                # the app lost focus (a call came in)
	check(not r.is_pressed(1), "focus loss lifts every finger")
	check_eq(s.stats.let_go, 1, "so the hold is let go, not stuck")
	_now = 2.6
	_touch(r, 360, true, 3)        # the same finger index comes back
	_touch(r, 360, false, 3)
	check_eq(s.stats.let_go, 1, "a returning finger does not break anything")
	r.queue_free()


# Plays a chart in slam mode through the InputRouter with two thumbs, the way a player would:
# steps and full rings with one thumb, stomps with both thumbs on their button, bells with both outer buttons, or with the free outer button
# while the other thumb keeps a hold. Returns [session, most buttons down at once].
func _slam_bot(song: SongData, diff: String) -> Array:
	var s := Session.new(song, diff, {"slam": true})
	var r := _router(s)
	var events := []   # [t, order (0 = release first), kind, lane, id]
	var id := 0
	var holds := []    # [t0, t1, lane]
	for n in s.notes:
		if n.kind == Note.Kind.HOLD:
			holds.append([n.t, n.end_t, n.lane])
	for n in s.notes:
		id += 1
		match n.kind:
			Note.Kind.STEP, Note.Kind.RING:
				events.append([n.t, 1, "down", n.lane, id])
				events.append([n.t + 0.03, 0, "up", n.lane, id])
			Note.Kind.HOLD:
				events.append([n.t, 1, "down", n.lane, id])
				events.append([n.end_t, 0, "up", n.lane, id])
			Note.Kind.BELL:
				var held := -1
				for h in holds:
					if h[0] <= n.t and n.t < h[1]:
						held = h[2]
				if held < 0:
					events.append([n.t, 1, "down", 0, id])
					events.append([n.t, 1, "down", 2, id + 10000])
					events.append([n.t + 0.03, 0, "up", 0, id])
					events.append([n.t + 0.03, 0, "up", 2, id + 10000])
				else:
					var lane := 2 if held == 0 else 0
					events.append([n.t, 1, "down", lane, id])
					events.append([n.t + 0.03, 0, "up", lane, id])
			Note.Kind.STOMP:
				events.append([n.t, 1, "down", n.lane, id])
				events.append([n.t + 0.025, 1, "down", n.lane, id + 20000])
				events.append([n.t + 0.05, 0, "up", n.lane, id])
				events.append([n.t + 0.05, 0, "up", n.lane, id + 20000])
	events.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var down := {}
	var most := 0
	var xs := [120.0, 360.0, 600.0]
	for e in events:
		_now = e[0]
		s.update(_now)
		match e[2]:
			"down":
				_touch(r, xs[e[3]], true, e[4])
				down[e[4]] = true
				most = maxi(most, down.size())
			"up":
				_touch(r, xs[e[3]], false, e[4])
				down.erase(e[4])
	s.update(s.end_time())
	r.queue_free()
	return [s, most]


func test_slam_two_thumbs_through_router() -> void:
	await tree.process_frame
	SongLibrary.reset()
	var songs := SongLibrary.story()
	if songs.is_empty():
		SongLibrary.use_directory("res://tests/core/fixtures/story")
		songs = SongLibrary.story()
	for song in songs:
		for diff in song.difficulties():
			var res := _slam_bot(song, diff)
			var s: Session = res[0]
			check_near(s.accuracy(), 1.0, 1e-9, "%s/%s in slam with two thumbs: 100 %% (miss %d, wrong %d, silence %d)" % [song.id, diff, s.stats.miss, s.stats.wrong, s.stats.silence])
			check(res[1] <= 2, "%s/%s: never more than two buttons down (%d)" % [song.id, diff, res[1]])
		await tree.process_frame
	SongLibrary.reset()


# ---------------------------------------------------------------- web sensors


# Browser devicemotion samples [timeStamp ms, ax, ay, az, beta, gamma, alpha, lx, ly, lz, has_lin,
# has_rot] of a synthetic phone held upright-ish (gravity along y), at `hz`, from t0 to t1.
func _browser_samples(sy: RefCounted, t0: float, t1: float, hz: float, with_linear := true) -> Array:
	var out := []
	var g := Vector3(0.0, 9.81, 0.0)
	var t := t0
	while t < t1:
		var smp: Array = sy.sample(t)
		var lin: Vector3 = smp[0]
		var rot: Vector3 = smp[1]
		var inc := lin + g
		out.append([t * 1000.0, inc.x, inc.y, inc.z, rot.x, rot.y, rot.z,
			lin.x if with_linear else 0.0, lin.y if with_linear else 0.0, lin.z if with_linear else 0.0,
			1 if with_linear else 0, 1])
		t += 1.0 / hz
	return out


func test_web_motion_conversion() -> void:
	var c := WebMotion.convert_sample([1000.0, 0.5, 9.81, 1.5, 90.0, -45.0, 180.0, 0.5, 0.0, 1.5, 1, 1], 1016.0)
	check_near(c.age, 0.016, 1e-9, "age from performance.now()")
	check_eq(c.accel, Vector3(0.5, 9.81, 1.5), "accelerationIncludingGravity keeps the device axes")
	check(c.gravity.is_equal_approx(Vector3(0.0, 9.81, 0.0)), "gravity = including - linear")
	check(c.gyro_rad.is_equal_approx(Vector3(PI / 2.0, -PI / 4.0, PI)), "beta, gamma, alpha (deg/s) -> x, y, z (rad/s)")
	var n := WebMotion.convert_sample([0.0, 0, 0, 9.8, 0, 0, 0, 0, 0, 0, 0, 0], 0.0)
	check_eq(n.gravity, Vector3.ZERO, "no linear acceleration from the browser: gravity left to the low-pass")
	check_eq(n.gyro_rad, Vector3.ZERO, "no rotationRate: no gyro")
	check(not n.has_gyro and c.has_gyro, "whether the browser sent a rotationRate")
	var still := MotionReader.new()
	still.ingest_web(WebMotion.convert_all([[0.0, 0, 9.81, 0, 0, 0, 0, 0, 0, 0, 1, 1]], 16.0), 0.016)
	check_eq(still.status(), "ok", "a phone lying still still has a gyro (a zero rotationRate is a reading)")
	check_eq(WebMotion.convert_all([[1, 2], "junk"], 0.0).size(), 0, "malformed samples are skipped")
	check(not WebMotion.supported(), "not on the web here: nothing JavaScript runs")
	var m := MotionReader.new()
	check(not m.web, "a native or headless reader stays native")
	check_eq(m.web_permission(), "native", "permission is not a web question here")
	m.request_web_permission()   # harmless natively


func test_web_motion_rings_at_60_hz() -> void:
	# The browser's devicemotion at 60 Hz, drained once per 60 fps frame (0-2 samples a frame, the
	# frames drifting against the sensor): every flick rings once, on time, the right way up.
	var Synth := preload("res://tests/core/motion_synth.gd")
	for with_linear in [true, false]:
		for fps: float in [60.0, 58.0, 120.0]:
			var sy: RefCounted = Synth.new(40)
			sy.gyro_noise = 4.0
			sy.acc_noise = 0.2
			var starts := []
			for i in 12:
				starts.append(1.0 + i * 0.61)
				sy.flick(starts[-1], i % 2 == 0, 400.0, 12.0, 0.2)
			var raw := _browser_samples(sy, 0.0, 9.0, 60.0, with_linear)
			var s := Session.new(_song([]), "easy")
			var r := _router(s)
			r.detector = BellDetector.from_calibration({"mode": "gyro", "threshold": 180.0, "axis": 0, "up_sign": 1, "reliable": true})
			r.detector.set_bpm(100.0)
			var reader := MotionReader.new()
			var rings := []
			var det := r.detector
			r.tilted.connect(func(_x): rings.append([det.last_up, det.last_t]))
			var k := 0
			var frame_t := 0.003
			var per_frame := {}
			while frame_t < 9.0:
				var batch := []
				while k < raw.size() and raw[k][0] <= frame_t * 1000.0:
					batch.append(raw[k])
					k += 1
				per_frame[batch.size()] = true
				reader.ingest_web(WebMotion.convert_all(batch, frame_t * 1000.0), 1.0 / fps)
				_now = frame_t
				r.feed_samples(frame_t, reader.samples)
				frame_t += 1.0 / fps
			var what := "%s, %d fps" % ["with linear" if with_linear else "gravity by low-pass", fps]
			check_eq(reader.status(), "ok", "%s: sensor present once events arrived" % what)
			check_eq(rings.size(), 12, "%s: 12 flicks ring 12 times" % what)
			if rings.size() == 12:
				var worst := 0.0
				var wrong_way := 0
				for i in 12:
					worst = maxf(worst, absf(float(rings[i][1]) - starts[i]))
					if rings[i][0] != (i % 2 == 0):
						wrong_way += 1
				check(worst < 0.03, "%s: ring times within 30 ms of the flick (worst %.3f)" % [what, worst])
				check_eq(wrong_way, 0, "%s: up and down read the right way" % what)
			r.queue_free()



## A tilt with no bell near rings nothing out loud (Daniele, 2026-10-10: holding the phone rang the
## bell all song long); a tilt on a bell still rings.
func test_a_tilt_with_no_bell_near_is_silent() -> void:
	var s := Session.new(_song([]), "easy")
	var r := _router(s)
	var heard := []
	var fired := []
	r.rang.connect(func(x): heard.append(x))
	r.tilted.connect(func(x): fired.append(x))
	r.call("_tilt_rang", 1.0, 1.0, false)
	check_eq(fired.size(), 1, "the tilt fired")
	check_eq(fired[0].get("quality"), "free", "with no bell near")
	check(heard.is_empty(), "and nothing rang out")
	r.queue_free()
