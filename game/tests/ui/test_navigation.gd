extends TestCase
## Forward and back through the menus, first launch into the tutorial, and the pause menu.


func test_first_launch_leads_to_the_tutorial() -> void:
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
	check_eq(app.current().screen_name(), "calibration_screen", "then the tilt calibration")
	# Buttons instead of the tilt are always offered (and are the way on with no sensor, as here).
	check(UIHarness.press(app, "UseSlam"), "no sensor: play with buttons")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "latency_screen", "then the delay test")
	check(UIHarness.press(app, "Skip"), "the delay test can be skipped")
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "tutorial_screen", "then straight into the tutorial")
	check(app.current().find_child("Try", true, false) != null, "the first lesson is one tap away")
	UIHarness.free_app(app)
	TranslationServer.set_locale("en")
	UIHarness.restore_profile()


func test_menus_forward_and_back() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree)
	await UIHarness.frames(tree, 2)
	check_eq(app.current().screen_name(), "title_screen", "a returning player starts on the title")
	var routes := [
		["StoryMap", "story_screen"], ["FreePlay", "free_play_screen"], ["Piazza", "piazza_screen"],
		["Daily", "daily_screen"], ["Workshop", "workshop_screen"], ["Leaderboards", "boards_screen"],
		["Settings", "settings_screen"],
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


func test_pause_resume_keeps_the_song_time() -> void:
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
	check_near(c.song_time(), t, 0.001, "the count-in does not move the song")
	var waited := 0.0
	while play.get("paused") and waited < 6.0:
		await tree.create_timer(0.1).timeout
		waited += 0.1
	check(not play.get("paused"), "the song resumes after the count-in")
	UIHarness.free_app(app)
	UIHarness.restore_profile()
