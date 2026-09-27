extends TestCase
## Play feel: resuming on the beat, the count-in you see and hear together, wrong-lane feedback on
## the pressed button, Piazza hit feedback, and focus loss during a count-in.


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
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
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
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
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
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var song: SongData = s.song
	var cv: CountInView = play.get("count_view")
	check(bool(play.get("_audio_count")), "a song from the start counts in with its own sticks")
	# The music's sticks are on beats -4..-1: the digits land on them.
	for pair in [[-3.95, 4], [-3.05, 4], [-2.95, 3], [-1.5, 2], [-0.05, 1]]:
		await _to_time(c, song.time_of(pair[0]))
		await tree.process_frame
		check_eq(cv.digit, int(pair[1]), "beat %.2f shows %d" % [pair[0], pair[1]])
	check(cv.beat_phase > 0.9, "the digit pulses with the beat (phase %.2f late in the beat)" % cv.beat_phase)
	# After the count, "Get ready" with the bars left, until the first note.
	await _to_time(c, song.time_of(0.2))
	await tree.process_frame
	if s.notes[0].t > song.time_of(0.3):
		check(cv.digit == 0 and cv.ready_bars >= 1, "then get ready, %d bars to go" % cv.ready_bars)
	await _to_time(c, s.notes[0].t + 0.01)
	await tree.process_frame
	check(not cv.is_showing(), "nothing is shown once the notes arrive")
	# The count is drawn over the procession, never over the lanes.
	var lanes: LaneView = play.get("lanes")
	check(not cv.get_global_rect().intersects(lanes.get_global_rect()), "the count-in sits off the notes")
	check(cv.get_global_rect().size.y > 150.0, "and is big (%.0f px tall)" % cv.get_global_rect().size.y)
	_close(app)


func test_wrong_lane_marks_the_pressed_button() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "hard", "bell_set": "light"})
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


func test_piazza_hits_flash_the_cue() -> void:
	var piazza := SongLibrary.piazza()
	if not check(not piazza.is_empty(), "there are Piazza songs"):
		return
	var r: Array = await _open({"song_id": piazza[0].id, "difficulty": "piazza", "bell_set": "light", "piazza": true})
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var cue: PiazzaCue = play.get("cue")
	check(cue != null, "Piazza shows its cue")
	var bell: Note = null
	for n in s.notes:
		if n.is_bell():
			bell = n
			break
	if bell == null or cue == null:
		_close(app)
		return
	await _to_time(c, bell.t)
	check_eq(cue.flashing(), "", "nothing flashes before the ring")
	var frame := Engine.get_process_frames()
	s.ring(bell.t, false)
	check_eq(Engine.get_process_frames(), frame, "(same frame)")
	check(cue.flashing() != "", "the ring flashes the circle with a big word (%s)" % cue.flashing())
	cue.still = true
	check(cue.still, "the cue has a grey still state")
	_close(app)


func test_focus_loss_during_the_count_in_pauses_again() -> void:
	var r: Array = await _open({"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
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
