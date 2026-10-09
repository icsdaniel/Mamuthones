extends TestCase
## The final review's fixes: early/late only off Perfect, the ghost in points after the first note,
## the results breakdown and timing above the fold, correct tips, the Remix chip beside the
## difficulties, and the delay slider's range.


## A whole run played by Autoplay, off screen.
static func _auto(song_id: String, diff: String, bell_set := "light") -> Session:
	var s := Session.new(SongLibrary.get_song(song_id), diff, bell_set, {})
	var a := Autoplay.new(s)
	var t := -1.0
	while not s.is_over(t) and t < 600.0:
		t += 0.05
		a.update(t)
	return s


func test_early_late_only_off_perfect() -> void:
	var script: GDScript = load(App.SCREENS["play"])
	check_eq(script.hit_side("perfect", -0.03), "", "no side on Perfect, even 30 ms early")
	check_eq(script.hit_side("good", -0.05), "early", "Good early says early")
	check_eq(script.hit_side("good", 0.05), "late", "Good late says late")
	check_eq(script.hit_side("early", -0.1), "early", "the Ok band keeps its side")
	check_eq(script.JUDGE_WORDS["early"], "judge_ok", "the Ok band's word is Ok, not Early")
	check_eq(script.JUDGE_WORDS["late"], "judge_ok", "the Ok band's word is Ok, not Late")
	# In play: a slightly early Perfect shows no hint and leaves no tick.
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", {"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var s: Session = play.get("session")
	var words: JudgementWords = play.get("words")
	var lanes: LaneView = play.get("lanes")
	var n: Note = null
	for m in s.notes:
		if m.kind == Note.Kind.STEP:
			n = m
			break
	s.tap(n.lane, n.t - 0.015, 3)
	if check_eq(n.judgement, "perfect", "a 15 ms early tap is Perfect"):
		check(" ".join(words.shown()).ends_with("/"), "Perfect has no early/late hint (%s)" % " ".join(words.shown()))
		check((lanes.get("_offsets") as Array).is_empty(), "and no timing tick")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_ghost_line_in_points_after_the_first_note() -> void:
	check(Hud.ghost_text(1250).contains(UIKit.fmt_score(1250)), "the ghost says points (%s)" % Hud.ghost_text(1250))
	check(Hud.ghost_text(-800).begins_with("−"), "behind reads as minus points (%s)" % Hud.ghost_text(-800))
	check_eq(Hud.ghost_text(0), tr("hud_ghost_even"), "level reads as level")
	UIHarness.fresh_profile()
	var best := _auto("carnival", "easy")
	var app := UIHarness.make_app(tree, "play", {"song_id": "carnival", "difficulty": "easy", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var hud: Hud = play.get("hud")
	hud.ghost = Ghost.from_session(best)
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	var s: Session = play.get("session")
	var label := hud.find_child("Ghost", true, false) as Label
	await UIHarness.frames(tree, 2)
	check(not Hud.judged_any(s), "nothing judged during the count-in")
	check_eq(label.text, "", "the ghost line is hidden until the first judged note")
	while not Hud.judged_any(s) and c.song_time() < 60.0:
		c.advance(0.05)
		await tree.process_frame
	await tree.process_frame
	check(label.text.contains(tr("hud_ghost_even")) or label.text.contains(UIKit.tr_("hud_ghost_up").replace("+%s", "").strip_edges()),
		"after the first note it shows the difference in points (%s)" % label.text)
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_results_breakdown_and_timing_above_the_fold() -> void:
	UIHarness.fresh_profile()
	var s := _auto("fires", "hard", "village")
	var args := {"session": s, "record": {"prev_best": int(s.score * 0.9), "new_best": true, "grade": s.grade_rank(), "carving_gained": 2,
		"unlocked": [{"kind": "song", "id": "bonfires"}]}, "play_args": {"song_id": "fires", "difficulty": "hard", "bell_set": "village"}}
	for loc in ["en", "it"]:
		Profile.set_setting("language", loc)
		for sz in [Vector2i(720, 1280), Vector2i(720, 1440), Vector2i(720, 1600), Vector2i(1290, 2796), Vector2i(1536, 2048)]:
			var app := UIHarness.make_app(tree, "results", args, sz)
			await UIHarness.settle(tree)
			var res := app.current()
			var foot := res.find_child("Footer", true, false) as Control
			var fold := foot.get_global_rect().position.y
			for part in ["UnisonHeadline", "Breakdown", "Tendency"]:
				var ctl := res.find_child(part, true, false) as Control
				if check(ctl != null, "%s %s: %s is shown" % [loc, sz, part]):
					check(ctl.get_global_rect().end.y <= fold + 1.0,
						"%s %s: %s is above the fold (ends %.0f, fold %.0f)" % [loc, sz, part, ctl.get_global_rect().end.y, fold])
			var score := res.find_child("Score", true, false) as Control
			var br := res.find_child("Breakdown", true, false) as Control
			check(score.get_global_rect().end.y <= br.get_global_rect().position.y, "%s %s: the breakdown comes right under the score" % [loc, sz])
			UIHarness.free_app(app)
	Profile.set_setting("language", "en")
	I18n.set_locale("en")
	UIHarness.restore_profile()


func test_tips_are_correct_and_concrete() -> void:
	UIHarness.fresh_profile()
	var results: GDScript = load(App.SCREENS["results"])
	# A clean Expert run on Village with Full load still locked: no "try Expert", no "try Village".
	var s := _auto("fires", "expert", "village")
	var tip: String = results.tip_text(s)
	check(not tip.contains(tr("diff_expert")), "no \"Try Expert\" for an Expert run (%s)" % tip)
	check(not tip.contains(BellSets.name("village", "en")), "no \"Village\" for a Village run (%s)" % tip)
	check_eq(results.next_bell_set("village"), "", "Full load is locked at the start, so nothing heavier is suggested")
	check_eq(results.next_bell_set("light"), "", "Village is locked at the start too")
	# A clean Hard run points at the next difficulty.
	var h := _auto("fires", "hard", "light")
	var ht: String = results.tip_text(h)
	check(ht.contains(tr("diff_expert")), "a clean Hard run suggests Expert (%s)" % ht)
	# Once Village opens, a clean Expert Light run suggests exactly Village.
	for stop_song in ["workshop", "fires", "bonfires"]:
		Profile.record_result(_auto(stop_song, "easy"))
	if Progression.bell_set_unlocked("village"):
		var e := _auto("fires", "expert", "light")
		var et: String = results.tip_text(e)
		check(et.contains(BellSets.name("village", "en")) and not et.contains(BellSets.name("full", "en")),
			"suggests the next unlocked set only (%s)" % et)
	UIHarness.restore_profile()


func test_remix_chip_beside_the_difficulties() -> void:
	UIHarness.fresh_profile()
	Profile.record_result(_auto("workshop", "easy"))
	Profile.record_result(_auto("fires", "hard"))
	check(Progression.remix_unlocked("fires"), "three bells at Hard open the remix")
	for sz in [Vector2i(720, 1280), Vector2i(720, 1440)]:
		var app := UIHarness.make_app(tree, "stop_card", {"song_id": "fires"}, sz)
		await UIHarness.settle(tree)
		var card := app.current()
		var chip := UIHarness.find_button(card, "Remix")
		if check(chip != null and chip.toggle_mode, "%s: a Remix chip" % sz):
			var diff := UIHarness.find_button(card, "Diff_easy")
			var fold := (card.find_child("Footer", true, false) as Control).get_global_rect().position.y
			check(chip.get_global_rect().end.y <= fold, "%s: the chip is above the fold" % sz)
			check(absf(chip.get_global_rect().end.y - diff.get_global_rect().position.y) < 40.0, "%s: right above the difficulty buttons" % sz)
			chip.button_pressed = true
			check(bool(card.get("use_remix")), "pressing it picks the remix")
		UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_delay_slider_matches_profile() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "settings")
	await UIHarness.settle(tree)
	var sl := app.current().find_child("Slider_audio_offset", true, false) as HSlider
	check_near(sl.min_value, -0.5, 0.0001, "the delay goes to −0.5 s")
	check_near(sl.max_value, 0.5, 0.0001, "and to +0.5 s")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_daily_hides_later_songs_and_plays_the_chosen_level() -> void:
	UIHarness.fresh_profile()
	var date := {}
	var base := Time.get_unix_time_from_datetime_string("2026-10-01T12:00:00")
	for i in 60:
		var d := Time.get_date_dict_from_unix_time(base + i * 86400)
		if Daily.is_hidden(d):
			date = d
			break
	if not check(not date.is_empty(), "some day in the next two months picks a song a new player has not reached"):
		UIHarness.restore_profile()
		return
	var app := UIHarness.make_app(tree, "daily", {"date": date})
	await UIHarness.settle(tree)
	var screen := app.current()
	var title := screen.find_child("SongTitle", true, false) as Label
	var song := SongLibrary.get_song(str(Daily.for_date(date).song_id))
	check_eq(title.text, tr("daily_hidden"), "the song's name is hidden")
	check(not (screen.find_child("Picture", true, false) is TextureRect), "and its picture is replaced")
	check(UIHarness.find_button(screen, "Diff_medium").button_pressed, "the picker starts on Medium")
	check(UIHarness.press(screen, "Diff_hard"), "the player picks Hard")
	check(UIHarness.press(screen, "Play"), "and plays")
	await UIHarness.settle(tree)
	var play := app.current()
	check_eq(play.screen_name(), "play_screen", "the day's procession starts")
	var s: Session = play.get("session")
	if s != null:
		check_eq(s.difficulty, "hard", "at the chosen level")
		check_eq(s.song.id, song.id, "on the day's song")
		check_eq(s.daily, Daily.key(date), "as that day's daily")
	UIHarness.free_app(app)
	UIHarness.restore_profile()
