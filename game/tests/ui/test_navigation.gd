extends TestCase
## Forward and back through the menus, first launch into the tutorial, and the pause menu.


func test_first_launch_leads_to_the_menu() -> void:
	UIHarness.fresh_profile(false)
	Profile.set_setting("language", "")
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "language_screen", "a fresh install starts on the language choice")
	check(UIHarness.press(app, "Lang_it"), "Italian can be picked")
	await UIHarness.frames(tree, 2)
	check_eq(TranslationServer.get_locale().substr(0, 2), "it", "the language changes at once")
	check_eq(app.current().screen_name(), "headphones_screen", "then the headphone suggestion")
	check(UIHarness.press(app, "Continue"), "headphones: continue")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "title_screen", "then straight to the menu: tutorial and calibration are optional")
	check_eq(app.stack.size(), 1, "the title is the bottom of the stack")
	for b in ["Tutorial", "Calibrate"]:
		check(app.current().find_child(b, true, false) != null, "the menu offers %s" % b)
	var next := Progression.next_stop()
	check(next != "" and SongLibrary.get_song(next).kind != "tutorial", "Continue leads to the first song, not the tutorial (%s)" % next)
	check(Progression.is_unlocked(SongLibrary.story()[1].id), "the first song is open without the tutorial")
	UIHarness.free_app(app)
	TranslationServer.set_locale("en")
	# A second launch goes straight to the title.
	var again := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	check_eq(again.current().screen_name(), "title_screen", "the headphone tip shows once")
	UIHarness.free_app(again)
	UIHarness.restore_profile()


func test_calibrate_from_the_menu() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	check(UIHarness.press(app, "Calibrate"), "title: Calibrate")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "calibration_screen", "the tilt calibration first")
	check(UIHarness.press(app.current(), "UseSlam"), "no sensor here: play with buttons")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "latency_screen", "then the delay test")
	check(UIHarness.press(app.current(), "Start"), "the delay test starts")
	await UIHarness.frames(tree, 2)
	check(UIHarness.press(app.current(), "Skip"), "Skip stays on screen while the test runs")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "title_screen", "and leads back to the menu")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_quit_leaves() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	var title: GDScript = load("res://scripts/ui/screens/title_screen.gd")
	var before: int = title.quit_calls
	check(UIHarness.press(app, "Quit"), "the title has Quit")
	check_eq(title.quit_calls, before + 1, "Quit closes the game")
	# Quit from the pause menu inside a tutorial lesson leaves the tutorial.
	check(UIHarness.press(app, "Tutorial"), "title: Tutorial")
	await UIHarness.frames(tree, 2)
	var tut := app.current()
	check_eq(tut.screen_name(), "tutorial_screen", "the tutorial opens")
	check(UIHarness.press(tut, "Try"), "a lesson starts")
	await UIHarness.frames(tree, 3)
	var lesson := tut.find_child("Lesson", true, false)
	check(lesson != null, "the lesson is playing")
	if lesson != null:
		lesson.call("pause")
		await UIHarness.frames(tree, 2)
		check(UIHarness.press(lesson, "Quit"), "the lesson's pause menu has Quit")
		await UIHarness.frames(tree, 2)
		check_eq(app.current().screen_name(), "title_screen", "Quit leaves the tutorial for the menu")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_menus_forward_and_back() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "title_screen", "a returning player starts on the title")
	var routes := [
		["StoryMap", "story_screen"], ["FreePlay", "free_play_screen"], ["Piazza", "piazza_screen"],
		["Daily", "daily_screen"], ["Workshop", "workshop_screen"], ["Leaderboards", "boards_screen"],
		["Settings", "settings_screen"], ["Tutorial", "tutorial_screen"], ["Calibrate", "calibration_screen"],
	]
	for r in routes:
		check(UIHarness.press(app, r[0]), "title has %s" % r[0])
		await UIHarness.frames(tree, 2)
		check_eq(app.current().screen_name(), r[1], "%s opens" % r[0])
		check(UIHarness.press(app.current(), "Back"), "%s has a back button" % r[1])
		await UIHarness.frames(tree, 2)
		check_eq(app.current().screen_name(), "title_screen", "back from %s returns to the title" % r[1])
	# Deeper: title -> story -> stop card -> play -> pause -> quit -> stop card -> back -> story.
	UIHarness.press(app, "StoryMap")
	await UIHarness.frames(tree, 2)
	check(UIHarness.press(app.current(), "Stop1"), "the first stop is open")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "stop_card_screen", "a stop opens its card")
	check(UIHarness.press(app.current(), "Play"), "the card has Play")
	await UIHarness.frames(tree, 3)
	var play := app.current()
	check_eq(play.screen_name(), "play_screen", "Play starts the song")
	play.call("pause")
	await UIHarness.frames(tree, 2)
	check(play.find_child("PauseMenu", true, false) != null, "pause shows the menu")
	check(play.find_child("Resume", true, false) != null and play.find_child("Restart", true, false) != null
		and play.find_child("Quit", true, false) != null, "pause menu: resume, restart, quit")
	check(UIHarness.press(play, "Quit"), "quit from pause")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "stop_card_screen", "quit returns to the card")
	app.back()
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "story_screen", "back again to the map")
	# Settings -> credits -> back.
	app.reset("settings")
	await UIHarness.frames(tree, 2)
	check(UIHarness.press(app.current(), "Credits"), "settings has credits")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "credits_screen", "credits open")
	check(app.current().find_child("Respect", true, false) != null, "credits open with the note on respect")
	app.current().on_back()
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "settings_screen", "back to settings")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_pause_resume_counts_back_in_from_a_bar_line() -> void:
	UIHarness.fresh_profile()
	var song := SongLibrary.story()[0]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	for i in 30:
		c.advance(0.1)
		await tree.process_frame
	play.call("pause")
	var t := c.song_time()
	await UIHarness.frames(tree, 10)
	c.advance(1.0)
	check_near(c.song_time(), t, 0.001, "song time stands still while paused")
	UIHarness.press(play, "Resume")
	await UIHarness.frames(tree, 2)
	check(play.get("paused"), "resume first counts in")
	var bar_t: float = play.call("resume_bar_time", t)
	check_near(c.song_time(), bar_t, 0.001, "the count-in waits on the bar line one to two bars back")
	check(c.song_time() <= t + 0.001, "never ahead of where the player paused")
	var waited := 0.0
	while play.get("paused") and waited < 6.0:
		await tree.create_timer(0.1).timeout
		waited += 0.1
	check(not play.get("paused"), "the song resumes after the count-in")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## The first played note comes well under a minute after launch: seven taps (language, headphones,
## buttons-or-tilt, skip delay, try), and the only waits the game itself adds are the screen
## transitions and the tutorial's one-bar lead-in. Reading time is the player's; this checks the
## game leaves most of the minute for it.
func test_first_note_within_a_minute() -> void:
	UIHarness.fresh_profile(false)
	Profile.set_setting("language", "")
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	var t0 := Time.get_ticks_msec()
	# Language, headphones, then the first song straight from the menu (tutorial and calibration optional).
	for b in ["Lang_en", "Continue", "PlayNext", "Play"]:
		check(UIHarness.press(app.current(), b), "first run: %s" % b)
		await UIHarness.settle(tree)
	var play: Node = null
	for n in [app.current()] + app.current().find_children("*", "", true, false):
		if n.get("session") is Session and n.get("conductor") is Conductor:
			play = n
	check(play != null, "the first song is playing")
	if play != null:
		var s: Session = play.get("session")
		var c: Conductor = play.get("conductor")
		var first := INF
		for n in s.notes:
			first = minf(first, n.t)
		while c.song_time() < first and Time.get_ticks_msec() - t0 < 60000:
			await tree.process_frame
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		check(c.song_time() >= first, "the first note arrives")
		print("  first note %.1f s after launch with instant taps" % secs)
		check(secs < 15.0, "the game's own waits before the first note stay short (%.1f s)" % secs)
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## A returning player is two taps from a song (title -> stop card -> play), and on the play screen the
## lanes (note-reading space) take most of the height at every store size; the procession scene sits
## above them and never eats into it.
func test_two_taps_to_a_song_and_lanes_dominate() -> void:
	for sz in [Vector2i(720, 1440), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1536, 2048)]:
		UIHarness.fresh_profile()
		var app := UIHarness.make_app(tree, "", {}, sz)
		await UIHarness.frames(tree, 2)
		check(UIHarness.press(app, "PlayNext"), "title: one tap on the next stop")
		await UIHarness.settle(tree)
		check(UIHarness.press(app.current(), "Play"), "stop card: second tap plays")
		await UIHarness.settle(tree)
		var play := app.current()
		check_eq(play.screen_name(), "play_screen", "two taps reach the song")
		var lanes: LaneView = play.get("lanes")
		var rows: SideRows = play.get("scene")
		var h := play.size.y
		print("  %s: lanes %.0f%% of height, %.0f%% of width" % [sz, lanes.size.y / h * 100.0, lanes.size.x / play.size.x * 100.0])
		check(lanes.size.y >= h * 0.8, "%s: the lanes are the stage (%.0f%% of the height)" % [sz, lanes.size.y / h * 100.0])
		check(lanes.size.x >= minf(play.size.x * 0.95, 890.0), "%s: the road's near end fills the width (%.0f px)" % [sz, lanes.size.x])
		var inv := lanes.get_global_transform().affine_inverse() * rows.get_global_transform()
		for s in 2:
			for i in SideRows.MAX_PER_SIDE:
				var sl: Array = rows.slot(s, i)
				var feet: Vector2 = inv * (sl[0] as Vector2)
				var fh: float = sl[1]
				var edges: Vector2 = lanes.road_edges(feet.y - fh * 0.5)
				var inner := feet.x + fh * 0.42 if s == 0 else feet.x - fh * 0.42
				check((inner <= edges.x + 6.0) if s == 0 else (inner >= edges.y - 6.0), "%s: Mamuthone %d/%d stands beside the road, not on it" % [sz, s, i])
		check(float(rows.slot(0, 0)[1]) >= 70.0, "%s: the nearest Mamuthone is big enough to read (%.0f px)" % [sz, float(rows.slot(0, 0)[1])])
		check(float(rows.slot(0, 0)[1]) > float(rows.slot(0, SideRows.MAX_PER_SIDE - 1)[1]), "%s: the file recedes with the road" % sz)
		UIHarness.free_app(app)
		UIHarness.restore_profile()
