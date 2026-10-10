extends TestCase
## The last live run is recorded in full and saved for checking; the screen delay test sets how early
## the notes are drawn.


func test_a_live_run_is_saved_with_touches_frames_and_settings() -> void:
	UIHarness.fresh_profile()
	Profile.set_setting("visual_offset", 0.07)
	var song := SongLibrary.story()[1]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	var s: Session = play.get("session")
	var router: InputRouter = play.get("router")
	var n: Note = null
	for x in s.notes:
		if x.kind == Note.Kind.STEP:
			n = x
			break
	while c.song_time() < n.t - 0.001:
		c.advance(minf(0.05, n.t - c.song_time()))
		await tree.process_frame
	var zone := router.buttons_rect
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = Vector2(zone.position.x + zone.size.x * (n.lane + 0.5) / 3.0, zone.end.y - 40.0)
	router._input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	router._input(ev)
	var off := InputEventScreenTouch.new()
	off.index = 1
	off.pressed = true
	off.position = Vector2(30.0, 40.0)   # up on the road: no button, but still logged
	router._input(off)
	for i in 3:
		c.advance(0.02)
		await tree.process_frame
	var log: RunLog = play.get("run_log")
	check(log != null, "a live run is recorded")
	UIHarness.free_app(app)
	await tree.process_frame
	var path := "user://" + RunLog.FILE_NAME
	check_eq(log.saved_path, path, "saved when the screen went (headless: in the game's folder)")
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(d is Dictionary, "the file is JSON"):
		UIHarness.restore_profile()
		return
	var h: Dictionary = d.header
	check_eq(h.song_id, song.id, "the song")
	check_near(float(h.settings.visual_offset), 0.07, 1e-6, "the settings")
	check(h.has("calibration") and h.has("model") and h.has("refresh_hz") and h.has("build"), "the phone and build")
	check_eq(h.ended, "left", "how it ended")
	var kinds := {}
	for e in d.events:
		kinds[e[2]] = kinds.get(e[2], 0) + 1
	check(kinds.get("down", 0) >= 2 and kinds.has("up"), "every touch, inside the zone or not (%s)" % str(kinds))
	check(kinds.has("press") and kinds.has("judged"), "what the press did and its judgement")
	var outside := false
	for e in d.events:
		if e[2] == "down" and not e[3].in_zone:
			outside = true
	check(outside, "a touch outside the button zone is marked as such")
	check((d.frames as Array).size() > 3, "frames")
	check_eq((d.notes as Array).size(), s.notes.size(), "every note with how it ended")
	UIHarness.restore_profile()


func test_autoplay_records_nothing() -> void:
	UIHarness.fresh_profile()
	var song := SongLibrary.story()[1]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy", "autoplay": true})
	await UIHarness.frames(tree, 3)
	check(app.current().get("run_log") == null, "no log in autoplay")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_screen_delay_test_sets_the_lead() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "settings")
	await UIHarness.settle(tree)
	check(UIHarness.press(app.current(), "ScreenDelay"), "Settings opens the screen delay test")
	await UIHarness.settle(tree)
	var scr := app.current()
	check(scr.get_script().resource_path.ends_with("screen_delay_screen.gd"), "it is open")
	scr.call("_begin")
	scr.set("_running", false)
	var t: LatencyTest = scr.get("test")
	var arr: PackedFloat64Array = scr.get("_arrivals")
	for i in range(4, arr.size()):
		t.add_tap(arr[i] + 0.07 + (0.006 if i % 2 == 0 else -0.006))
	scr.call("_finish")
	check_near(Profile.visual_offset(), 0.07, 0.003, "taps 70 ms after the notes touch: notes drawn 70 ms early")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_sound_delay_test_saves_its_result() -> void:
	# Its result meter once took the offsets in a form Godot refused, which stopped the test before it
	# saved anything.
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "latency", {})
	await UIHarness.settle(tree)
	var scr := app.current()
	scr.call("_begin")
	scr.set("_running", false)
	var t: LatencyTest = scr.get("test")
	var clicks: PackedFloat64Array = LatencyTest.click_times(LatencyTest.BPM, 12, 1.0)
	for i in clicks.size():
		t.add_click(clicks[i])
		t.add_tap(clicks[i] + 0.12 + (0.005 if i % 2 == 0 else -0.005))
	scr.call("_finish")
	check_near(Profile.audio_offset(), 0.12, 0.006, "the measured delay is saved")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Daniele's Bluetooth headphones (2026-10-10): the test measured 200 ms, then every step knock came a
## fifth of a second after his thumb. A long delay turns the step sounds off; a short one later turns
## them back on only if the test turned them off. Nothing on the test's screen moves with the clicks.
func test_a_long_sound_delay_turns_the_step_sounds_off() -> void:
	UIHarness.fresh_profile()
	var lat: GDScript = load(App.SCREENS["latency"])
	check_eq(lat.step_sounds_for(0.2), "", "knocks already off (the default): nothing to say")
	Profile.set_setting("step_knocks", true)
	check_eq(lat.step_sounds_for(0.03), "", "a short delay changes nothing")
	check(bool(Profile.get_setting("step_knocks")), "knocks stay on")
	check_eq(lat.step_sounds_for(0.2), "lat_sounds_off", "200 ms: the player is told")
	check(not bool(Profile.get_setting("step_knocks")), "and the knocks are off")
	check_eq(lat.step_sounds_for(0.03), "lat_sounds_on", "back on the phone's speaker: told again")
	check(bool(Profile.get_setting("step_knocks")), "and they are back on")
	Profile.set_setting("step_knocks", false)
	check_eq(lat.step_sounds_for(0.03), "", "turned off by hand: a short delay leaves them off")
	check(not bool(Profile.get_setting("step_knocks")), "still off")
	var app := UIHarness.make_app(tree, "latency", {})
	await UIHarness.settle(tree)
	check(app.current().get("_pulses") == null, "the drum does not pulse with the clicks")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Sounds the game plays on the music (the Issohadore's call, the bell cue, the count-in digits) are
## timed by the whole sound delay, as the music is, not by the output latency alone.
func test_sounds_on_the_music_lead_by_the_whole_sound_delay() -> void:
	var c := Conductor.new()
	c.use_audio = false
	c.audio_offset = 0.2
	c.play(SongLibrary.get_song("fires"))
	check_near(c.heard_delay(), 0.2 + AudioServer.get_output_latency(), 1e-6, "heard 200 ms after it is played")
	c.free()
	var src := FileAccess.get_file_as_string("res://scripts/ui/screens/play_screen.gd")
	check(src.contains("var lead := conductor.heard_delay()"), "the call and the cue are scheduled by it")
	check(src.contains("_count_from = _clock + conductor.heard_delay()"), "and the count-in digits")
