extends TestCase
## Play feel: resuming on the beat, the count-in you see and hear together, wrong-lane feedback on
## the pressed button, and focus loss during a count-in.


func _open(args: Dictionary) -> Array:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", args)
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	return [app, play, c]


func _close(app: App) -> void:
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Waits on the real clock until the play screen's count-in has ended (or a limit).
func _wait_count(play: Node, limit := 8.0) -> void:
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(play) and float(play.get("_resume_at")) >= 0.0 and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await tree.process_frame


func _to_time(c: Conductor, t: float) -> void:
	while c.song_time() < t - 0.0005:
		c.advance(minf(0.05, t - c.song_time()))
		await tree.process_frame


func test_resume_goes_back_to_a_bar_line_and_counts_in() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy"})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var song: SongData = s.song
	var spb := 60.0 / song.bpm
	# Pause half a beat into bar 5 (beat 18.5), well into the notes.
	var tp := song.time_of(18.5)
	await _to_time(c, tp)
	var judged_before := 0
	for n in s.notes:
		if n.done:
			judged_before += 1
	play.call("pause")
	await tree.process_frame
	check(play.find_child("PauseMenu", true, false) != null, "the pause menu is up")
	play.call("_on_pause_choice", "resume")
	await tree.process_frame
	var music_t: float = play.get("_count_music_t")
	var b0 := song.beat_at(music_t)
	check(absf(b0 - roundf(b0 / 4.0) * 4.0) < 0.01, "the music waits on a bar line (beat %.2f)" % b0)
	var back := 18.5 - b0
	check(back >= 4.0 and back <= 8.0, "it goes back one to two bars (%.1f beats)" % back)
	check_near(c.song_time(), music_t, 0.002, "the conductor is moved back to that bar line")
	var clock: float = play.get("_clock")
	check_near(float(play.get("_resume_at")) - clock, 4.0 * spb, 0.05, "one bar is counted in before the music")
	var cv: CountInView = play.get("count_view")
	check_eq(cv.digit, 4, "the count starts at 4")
	# The lanes run toward the bar line during the count, so the approach replays.
	var lanes: LaneView = play.get("lanes")
	var lt0 := lanes.song_time
	var seen := {}
	var t0 := Time.get_ticks_msec()
	while float(play.get("_resume_at")) >= 0.0 and Time.get_ticks_msec() - t0 < 8000:
		if cv.digit > 0:
			seen[cv.digit] = true
		await tree.process_frame
	check(lanes.song_time > lt0, "the notes approach during the count")
	check_eq(seen.keys().size(), 4, "4, 3, 2 and 1 are all shown (%s)" % str(seen.keys()))
	check(not bool(play.get("paused")), "the music plays after the count")
	check_near(c.song_time(), music_t, 0.05, "and starts from the bar line")
	var judged_after := 0
	for n in s.notes:
		if n.done:
			judged_after += 1
	check_eq(judged_after, judged_before, "notes judged before the pause stay judged, nothing new is judged")
	_close(app)


func test_restart_starts_near_the_first_note() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy"})
	var app: App = r[0]
	var play: Node = r[1]
	play.call("pause")
	await tree.process_frame
	play.call("_on_pause_choice", "restart")
	await UIHarness.settle(tree)
	var again := app.current()
	check(again != play and bool((again.get("args") as Dictionary).get("quick", false)), "restart reopens the song as a quick start")
	var c: Conductor = again.get("conductor")
	var s: Session = again.get("session")
	var first := s.notes[0].t
	var from: float = again.get("_count_music_t")
	check(float(again.get("_resume_at")) >= 0.0, "it counts in first")
	check(first - from >= 4.0 * 60.0 / s.song.bpm - 0.01 and first - from <= 8.0 * 60.0 / s.song.bpm + 0.01,
		"the music starts one to two bars before the first note (%.2f s), not at the intro" % (first - from))
	check(c.is_paused(), "the music waits during the count")
	_close(app)


func test_the_count_in_is_seen_on_the_audio_sticks() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy"})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var song: SongData = s.song
	var cv: CountInView = play.get("count_view")
	# Carnival's intro is long, so the music starts inside it: "Get ready" first, then "4 3 2 1" on the
	# music's beats over the bar just before the first note's bar.
	check(not bool(play.get("_audio_count")) and bool(play.get("_bar_count")), "a long intro is joined partway, counted on its own bar")
	var cb: float = float(play.call("first_bar")) - 4.0
	await _to_time(c, song.time_of(cb - 1.5))
	await tree.process_frame
	check(cv.digit == 0 and cv.ready_bars >= 1, "get ready first, %d bars to go" % cv.ready_bars)
	for pair in [[0.05, 4], [0.95, 4], [1.05, 3], [2.5, 2], [3.88, 1]]:
		await _to_time(c, song.time_of(cb + pair[0]))
		await tree.process_frame
		check_eq(cv.digit, int(pair[1]), "beat %.2f shows %d" % [cb + pair[0], pair[1]])
	check(cv.beat_phase > 0.85, "the digit pulses with the beat (phase %.2f late in the beat)" % cv.beat_phase)
	await _to_time(c, s.notes[0].t + 0.01)
	await tree.process_frame
	check(not cv.is_showing(), "nothing is shown once the notes arrive")
	# The count is drawn over the top of the lanes, never near the hit line where notes are stepped.
	var lanes: LaneView = play.get("lanes")
	var hit_zone_top := lanes.get_global_transform() * Vector2(0.0, LaneSkin.hit_line_y(lanes.field_rect()) - lanes.field_rect().size.y * 0.25)
	check(cv.get_global_rect().end.y <= hit_zone_top.y, "the count-in sits well above the hit line")
	check(cv.get_global_rect().size.y > 150.0, "and is big (%.0f px tall)" % cv.get_global_rect().size.y)
	_close(app)


func test_wrong_lane_marks_the_pressed_button() -> void:
	# Health off: the run skips every note before the target, which would otherwise run health out.
	var r: Array = await _open({"song_id": "carnival", "difficulty": "medium", "health": false})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var router: InputRouter = play.get("router")
	# A lane-2 step with nothing in lane 0 anywhere near it.
	var target: Note = null
	for n in s.notes:
		if n.kind != Note.Kind.STEP or n.lane != 2:
			continue
		var clear := true
		for m in s.notes:
			if m != n and absf(m.t - n.t) < 0.6:
				clear = false
		if clear:
			target = n
			break
	if not check(target != null, "the chart has a lone lane-2 step"):
		_close(app)
		return
	await _to_time(c, target.t)
	# Earlier misses on the way here may still be flashing; only the wrong tap's own marks count.
	lanes.set("_flash", [-9.0, -9.0, -9.0] as Array[float])
	var rect := router.buttons_rect
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = rect.position + Vector2(rect.size.x * 0.5 / 3.0, rect.size.y * 0.5)
	router._input(ev)
	check(lanes.marks_shown().has("wrong:0"), "a red mark on the button pressed (%s)" % str(lanes.marks_shown()))
	check(lanes.marks_shown().has("faint:2"), "only a faint mark on the note it was meant for")
	check(lanes.call("_button_state", 2) != "miss", "the other lane's button does not flash")
	var words: JudgementWords = play.get("words")
	var on_pressed := false
	for rr in words.shown_rects():
		var third := lanes.get_global_rect().size.x / 3.0
		if rr.get_center().x < lanes.get_global_rect().position.x + third:
			on_pressed = true
	check(on_pressed and " ".join(words.shown()).contains(tr("judge_wrong")), "\"Wrong lane\" is written under the pressed lane")
	ev = ev.duplicate()
	ev.pressed = false
	router._input(ev)
	_close(app)


func test_focus_loss_during_the_count_in_pauses_again() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy"})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var song: SongData = (play.get("session") as Session).song
	await _to_time(c, song.time_of(14.5))
	play.call("pause")
	await tree.process_frame
	play.call("_on_pause_choice", "resume")
	await tree.process_frame
	var music_t: float = play.get("_count_music_t")
	check(float(play.get("_resume_at")) >= 0.0, "counting in")
	play.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await tree.process_frame
	check(float(play.get("_resume_at")) < 0.0, "the count is cancelled")
	check(play.find_child("PauseMenu", true, false) != null, "the pause menu is back")
	check(c.is_paused(), "the music still waits")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await tree.process_frame
	check(c.is_paused() and bool(play.get("paused")), "and does not start by itself")
	play.call("_on_pause_choice", "resume")
	await tree.process_frame
	check_near(float(play.get("_count_music_t")), music_t, 0.002, "resuming again counts in from the same bar line")
	await _wait_count(play)
	check(not c.is_paused(), "then plays")
	_close(app)


func test_bell_cue_is_on_for_easy_and_medium_by_default() -> void:
	UIHarness.fresh_profile()
	var script: GDScript = load(App.SCREENS["play"])
	check(script.bell_cue_on("easy") and script.bell_cue_on("medium"), "the bell cue is on for Easy and Medium")
	check(not script.bell_cue_on("hard") and not script.bell_cue_on("expert"), "and off for Hard and Expert")
	Profile.set_setting("bell_cue", false)
	check(not script.bell_cue_on("easy"), "Settings can turn it off")
	UIHarness.restore_profile()



func test_words_of_two_lanes_never_print_over_each_other() -> void:
	var w := JudgementWords.new()
	w.size = Vector2(720, 1440)
	tree.root.add_child(w)
	await tree.process_frame
	w.show_word("Perfect", "", Vector2(120, 1100), "perfect")
	w.show_word("Perfect", "", Vector2(360, 1100), "perfect")
	await tree.process_frame
	check_eq(w.shown().size(), 1, "a chord of the same word is written once (%s)" % str(w.shown()))
	var r: Array[Rect2] = w.shown_rects()
	check(r.size() == 1 and absf(r[0].get_center().x - 240.0) <= 6.0, "between its two lanes (%s)" % str(r))
	w.show_word("Good", "", Vector2(600, 1100), "good")
	w.show_word("Perfect", "", Vector2(360, 1100), "perfect")
	await tree.process_frame
	r = w.shown_rects()
	var apart := true
	for i in r.size():
		for j in range(i + 1, r.size()):
			if r[i].intersects(r[j]):
				apart = false
	check(r.size() >= 2 and apart, "different words side by side do not overlap (%s)" % str(r))
	w.queue_free()


## Notes slide smoothly down the road (Daniele: stepping on the beat felt bad): a note on this moment
## is on the hit line, and every note keeps moving closer as time runs.
func test_notes_slide_smoothly() -> void:
	var lv := LaneView.new()
	lv.perspective = false
	lv.size = Vector2(540, 1100)
	lv.spb = 0.5
	lv.song_time = 5.0
	var f := lv.field_rect()
	var hl := LaneSkin.hit_line_y(f)
	var pps := lv._px_per_s()
	check_near(lv.event_y(f, lv.song_time, pps), hl, 0.5, "a note due now is on the hit line")
	var prev := lv.event_y(f, 7.0, pps)
	for i in 20:
		lv.song_time += 0.02
		var y := lv.event_y(f, 7.0, pps)
		check(y > prev, "the note keeps sliding closer at every moment")
		prev = y
	lv.free()


## Note colours tell the rhythm: a sixteenth is silver, and so is a half-beat note inside a run of
## sixteenths (Daniele: violet there read as a slower note). A plain eighth stays violet.
func test_half_beats_in_sixteenth_runs_are_silver() -> void:
	var song := SongData.from_dict({"id": "t", "bpm": 120, "offset": 1.0, "length": 0.0, "charts": {"easy": [
		{"b": 0, "k": "step", "lane": 1}, {"b": 0.25, "k": "step", "lane": 0}, {"b": 0.5, "k": "step", "lane": 1},
		{"b": 0.75, "k": "step", "lane": 2}, {"b": 2, "k": "step", "lane": 1}, {"b": 2.5, "k": "step", "lane": 0},
		{"b": 3, "k": "step", "lane": 1}]}})
	var lv := LaneView.new()
	lv.session = Session.new(song, "easy")
	var n := lv.session.notes
	check(lv._sixteenth(n[1]) and lv._sixteenth(n[3]), "sixteenths are silver")
	check(lv._sixteenth(n[2]), "the half beat between them is silver too")
	check(not lv._sixteenth(n[5]), "a lone eighth stays violet")
	check(not lv._sixteenth(n[0]) and not lv._sixteenth(n[4]), "on-beat notes are neither")
	lv.free()
