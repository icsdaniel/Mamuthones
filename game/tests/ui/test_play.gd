extends TestCase
## Whole runs under Autoplay: a song plays through to the results, and the tutorial passes every lesson.


func test_song_plays_to_results_under_autoplay() -> void:
	UIHarness.fresh_profile()
	var song := SongLibrary.story()[0]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy", "bell_set": "light", "autoplay": true})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var session: Session = play.get("session")
	check(session != null and session.notes.size() > 10, "the play screen has a session with notes")
	await UIHarness.run_play(tree, play, 0.05)
	await UIHarness.frames(tree, 3)
	var res := app.current()
	check_eq(res.screen_name(), "results_screen", "the song ends on the results")
	check_eq(session.stats.miss, 0, "autoplay misses nothing")
	check_eq(session.grade(), "S+", "a perfect run earns an S+")
	check(res.find_child("Grade", true, false) is GradeBadge, "results show the letter grade")
	check(res.find_child("FullCombo", true, false) != null, "results say it was a full combo")
	check(res.find_child("Breakdown", true, false) != null, "results break the score down")
	check(res.find_child("Tendency", true, false) != null, "results show early/late tendency")
	check(res.find_child("Tip", true, false) != null, "results give a tip")
	var weight := res.find_child("WeightValue", true, false) as Label
	check(weight != null, "weight is shown")
	var unison := res.find_child("UnisonValue", true, false) as Label
	check(unison != null and unison.text != "+0", "unison added to the score")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_played_run_is_recorded_and_unlocks_the_next_stop() -> void:
	UIHarness.fresh_profile()
	var story := SongLibrary.story()
	if story.size() < 3:
		check(false, "needs three story songs")
		return
	check(Progression.is_unlocked(story[1].id), "stop 2 is open once the tutorial is done")
	check(not Progression.is_unlocked(story[2].id), "stop 3 starts locked")
	var app := UIHarness.make_app(tree, "play", {"song_id": story[1].id, "difficulty": "easy", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	# Drive the real play screen with Autoplay's inputs but not its "autoplay" flag, as a player would.
	var auto := Autoplay.new(play.get("session"))
	auto.stepped.connect(func(l: int) -> void: play.call("_on_stepped", l))
	auto.rang.connect(func(r: Dictionary) -> void: play.call("_on_rang", r))
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	while is_instance_valid(play) and not play.get("done"):
		c.advance(0.05)
		auto.update(c.song_time())
		await tree.process_frame
	await UIHarness.frames(tree, 3)
	check_eq(app.current().screen_name(), "results_screen", "results after a played run")
	check(Profile.best(story[1].id, "easy").get("score", 0) > 0, "the best is saved")
	check(Progression.is_unlocked(story[2].id), "stop 3 is now open")
	check(app.current().find_child("Unlocked", true, false) != null, "the unlock is shown on the results")
	check(app.current().find_child("Next", true, false) != null, "results offer the next stop")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_tutorial_passes_under_autoplay() -> void:
	UIHarness.fresh_profile(false)
	var app := UIHarness.make_app(tree, "tutorial", {"autoplay": true, "first_run": true})
	await UIHarness.frames(tree, 3)
	var tut := app.current()
	var lessons: Array = tut.get("lessons")
	check(lessons.size() >= 5, "the tutorial has its lessons")
	var topics := lessons.map(func(l: Dictionary) -> String: return str(l.topic))
	for t in ["steps", "bells", "holds", "still", "stomps"]:
		check(t in topics, "a lesson teaches %s" % t)
	var frames := 0
	while tut.find_child("Finale", true, false) == null and frames < 20000:
		var play: Node = tut.get("_play")
		if play != null and play.get("conductor") != null:
			var c: Conductor = play.get("conductor")
			c.use_manual_clock(true)
			c.advance(0.05)
		frames += 1
		await tree.process_frame
	check(tut.find_child("Finale", true, false) != null, "every lesson passes and the finale shows")
	check_eq(int(tut.get("index")), lessons.size(), "all lessons were played")
	check(Profile.has_flag("tutorial_done"), "the tutorial is marked done")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Health on the play screen: the pips show in a played song; letting every note go by runs health out,
## the music stops, the notes freeze and the fail menu offers Restart (the same song, difficulty and
## bell set, counted in again) and Quit; a failed run records nothing.
func test_health_runs_out_and_restart_replays_the_song() -> void:
	UIHarness.fresh_profile()
	var song := SongLibrary.story()[1]
	var args := {"song_id": song.id, "difficulty": "hard", "bell_set": "full"}
	var app := UIHarness.make_app(tree, "play", args)
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var s: Session = play.get("session")
	check(s.health_on, "health is on in a played song")
	var pips := play.find_child("Health", true, false) as Control
	check(pips != null and pips.is_visible_in_tree(), "the health flames show on the HUD")
	check(not s.heal_notes().is_empty(), "the song has healing steps")
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	var guard := 0
	while not s.has_failed and guard < 4000:
		c.advance(0.05)
		guard += 1
		await tree.process_frame
	check(s.has_failed, "missing every note runs out of health")
	check_eq(s.health, 0, "health is 0")
	check(play.get("failed"), "the play screen knows the run failed")
	var lanes: LaneView = play.get("lanes")
	var at := lanes.song_time
	var t0 := Time.get_ticks_msec()
	while play.find_child("FailMenu", true, false) == null and Time.get_ticks_msec() - t0 < 3000:
		c.advance(0.05)
		await tree.process_frame
	check_near(lanes.song_time, at, 0.001, "the notes stop where they are")
	var menu := play.find_child("FailMenu", true, false)
	check(menu != null, "the fail menu is up")
	var title := play.find_child("Title", true, false) as Label
	check(title != null and title.text == tr("fail_title"), "it says the fire goes out")
	check(UIHarness.find_button(play, "Restart") != null and UIHarness.find_button(play, "Quit") != null, "Restart and Quit")
	check(Profile.best(song.id, "hard").is_empty() or int(Profile.best(song.id, "hard").get("score", 0)) == 0, "a failed run records no result")
	check(UIHarness.press(play, "Restart"), "Restart")
	await UIHarness.frames(tree, 3)
	var again := app.current()
	check(again != play and again.screen_name() == "play_screen", "Restart builds a new play screen")
	var s2: Session = again.get("session")
	check(s2 != null and s2.song.id == song.id and s2.difficulty == "hard" and s2.bell_set == "full", "the same song, difficulty and bell set")
	check_eq(s2.health, Session.MAX_HEALTH, "with full health")
	check(again.get("paused"), "counted in from the start")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Autoplay and the tutorial never show health and never fail.
func test_exempt_modes_never_fail() -> void:
	UIHarness.fresh_profile()
	var story := SongLibrary.story()
	var cases := [{"song_id": story[1].id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "human": true}]
	var r := story[0].lesson_range(1)
	cases.append({"song_id": story[0].id, "difficulty": "easy", "bell_set": "light", "from_beat": r.x, "to_beat": r.y})
	for a in cases:
		var app := UIHarness.make_app(tree, "play", a)
		await UIHarness.frames(tree, 3)
		var play := app.current()
		var s: Session = play.get("session")
		check(not s.health_on, "%s: health is off" % a.song_id)
		var pips := play.find_child("Health", true, false) as Control
		check(pips == null or not pips.is_visible_in_tree(), "%s: no health flames" % a.song_id)
		var c: Conductor = play.get("conductor")
		c.use_manual_clock(true)
		for i in 300:
			c.advance(0.1)
			await tree.process_frame
		check(not s.has_failed and not play.get("failed"), "%s: never fails" % a.song_id)
		UIHarness.free_app(app)
	UIHarness.restore_profile()
