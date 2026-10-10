extends TestCase
## Every hit is answered in the same frame as the input (rubric 1): the touch event is handled, and
## before any frame passes the step sound has started, the button flashes, the note bursts, the
## judgement word shows, the row jolts and the phone buzzes. Misses show but stay quiet.


func _play_screen() -> Array:
	UIHarness.fresh_profile()
	Profile.set_setting("vibration", true)
	var song := SongLibrary.story()[1]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	return [app, play, c]


func _first_step(s: Session) -> Note:
	for n in s.notes:
		if n.kind == Note.Kind.STEP:
			return n
	return null


func test_a_hit_answers_in_the_same_frame() -> void:
	var r: Array = await _play_screen()
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var router: InputRouter = play.get("router")
	var n := _first_step(s)
	# Bring song time to the note.
	while c.song_time() < n.t - 0.001:
		c.advance(minf(0.05, n.t - c.song_time()))
		await tree.process_frame
	var foot_before: int = (Sound.get("_next") as PackedInt32Array)[2]
	var buzz_before := UIKit.vibrations
	var bursts_before: int = (lanes.get("_bursts") as Array).size()
	var frame := Engine.get_process_frames()
	# A finger lands on the note's button, inside the button row.
	var rect := router.buttons_rect
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = rect.position + Vector2(rect.size.x * (n.lane + 0.5) / 3.0, rect.size.y * 0.5)
	router._input(ev)
	check_eq(Engine.get_process_frames(), frame, "everything below happened before the next frame")
	check(n.done and n.judgement in ["perfect", "good"], "the note is judged at once (%s)" % n.judgement)
	check_eq((Sound.get("_next") as PackedInt32Array)[2], foot_before, "no knock: the buttons are silent by default")
	check((play.get("lift") as MusicLift).run > 0.2, "the song's tune comes up instead")
	check(router.is_pressed(n.lane), "the button reads as pressed")
	check_eq(lanes.call("_button_state", n.lane), "hit", "the button flashes")
	check((lanes.get("_bursts") as Array).size() > bursts_before, "the note bursts")
	var words: JudgementWords = play.get("words")
	var shown := false
	for spot in (words.get("_spots") as Dictionary).values():
		if (spot[1] as Label).text == tr("judge_perfect") or (spot[1] as Label).text == tr("judge_good"):
			shown = true
	check(shown, "the judgement word shows")
	check(UIKit.vibrations > buzz_before, "the phone buzzes")
	ev = ev.duplicate()
	ev.pressed = false
	router._input(ev)
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_a_miss_is_visible_but_quiet() -> void:
	var r: Array = await _play_screen()
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var n := _first_step(s)
	var buzz_before := UIKit.vibrations
	while not n.done:
		c.advance(0.05)
		await tree.process_frame
	check_eq(n.judgement, "miss", "an untouched note is missed")
	check_eq(lanes.call("_button_state", n.lane), "miss", "the missed lane shows it")
	check_eq(UIKit.vibrations, buzz_before, "a miss does not buzz")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_early_and_late_read_differently() -> void:
	var r: Array = await _play_screen()
	var app: App = r[0]
	var play: Node = r[1]
	var s: Session = play.get("session")
	var words: JudgementWords = play.get("words")
	var steps: Array[Note] = []
	for n in s.notes:
		if n.kind == Note.Kind.STEP:
			steps.append(n)
		if steps.size() == 2:
			break
	# Judge one note early and one late through the session, as the router would, reading the words
	# after each (both may share a lane, so the second word replaces the first).
	s.tap(steps[0].lane, steps[0].t - 0.07, 1)
	var early := _words_text(words)
	s.release(steps[0].t - 0.05, 1)
	s.tap(steps[1].lane, steps[1].t + 0.07, 2)
	var late := _words_text(words)
	check(early.contains(tr("judge_hint_early")) or early.contains(tr("judge_early")), "an early hit says early (%s)" % early)
	check(late.contains(tr("judge_hint_late")) or late.contains(tr("judge_late")), "a late hit says late (%s)" % late)
	check(not early.contains(tr("judge_hint_late")) or early.contains(tr("judge_hint_early")), "the early hit does not read late")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func _words_text(words: JudgementWords) -> String:
	var texts: Array[String] = []
	for spot in (words.get("_spots") as Dictionary).values():
		if (spot[0] as Control).modulate.a > 0.5:
			texts.append((spot[1] as Label).text + "/" + (spot[2] as Label).text)
	return " ".join(texts)


func test_a_touch_on_the_hit_ring_presses_its_button() -> void:
	# Thumbs creep up toward the rings in a fast passage: a touch just above the buttons, on the
	# ring itself, still presses that lane's button; one high up on the road does not.
	var r: Array = await _play_screen()
	var app: App = r[0]
	var play: Node = r[1]
	var c: Conductor = r[2]
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var router: InputRouter = play.get("router")
	var n := _first_step(s)
	while c.song_time() < n.t - 0.001:
		c.advance(minf(0.05, n.t - c.song_time()))
		await tree.process_frame
	var buttons := lanes.buttons_global_rect()
	var zone := router.buttons_rect
	check(zone.position.y < buttons.position.y - 40.0, "the touch zone reaches above the buttons")
	var ring := lanes.get_global_transform() * Vector2(lanes.lane_center(n.lane).x, lanes.hit_line_screen_y())
	check(zone.has_point(ring), "the hit ring is inside it")
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = true
	ev.position = Vector2(zone.position.x + zone.size.x * (n.lane + 0.5) / 3.0, ring.y)
	router._input(ev)
	check(n.done and n.judgement in ["perfect", "good"], "a touch on the ring hits the note (%s)" % n.judgement)
	ev = ev.duplicate()
	ev.pressed = false
	router._input(ev)
	var high := InputEventScreenTouch.new()
	high.index = 1
	high.pressed = true
	high.position = Vector2(ring.x, zone.position.y - 60.0)
	router._input(high)
	check(not router.is_pressed(n.lane), "a touch high up on the road presses nothing")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_notes_are_drawn_ahead_by_the_visual_offset() -> void:
	UIHarness.fresh_profile()
	Profile.set_setting("visual_offset", 0.07)
	var song := SongLibrary.story()[1]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var c: Conductor = play.get("conductor")
	c.use_manual_clock(true)
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var n := _first_step(s)
	while c.song_time() < n.t - 0.5:
		c.advance(0.05)
		await tree.process_frame
	await tree.process_frame
	# (the shown time follows the clock smoothly, _vis_t; the lead goes on top of it)
	check_near(lanes.song_time - float(play.get("_vis_t")), 0.07, 1e-4, "a player's notes are drawn 70 ms ahead")
	UIHarness.free_app(app)
	# Autoplay shows them on the song's clock.
	var auto := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy", "autoplay": true})
	await UIHarness.frames(tree, 3)
	var ap := auto.current()
	var ac: Conductor = ap.get("conductor")
	ac.use_manual_clock(true)
	for i in 4:
		ac.advance(0.05)
		await tree.process_frame
	check_near((ap.get("lanes") as LaneView).song_time - float(ap.get("_vis_t")), 0.0, 1e-4, "autoplay draws no lead")
	UIHarness.free_app(auto)
	UIHarness.restore_profile()
