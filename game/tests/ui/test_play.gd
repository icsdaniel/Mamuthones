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
	check_eq(session.bells(), 3, "a perfect run earns 3 bells")
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
	for t in ["steps", "bells", "holds", "still", "swipes"]:
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
