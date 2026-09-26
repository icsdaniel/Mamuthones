extends TestCase
## Every hit is answered in the same frame as the input (rubric 1): the touch event is handled, and
## before any frame passes the step sound has started, the button flashes, the note bursts, the
## judgement word shows, the row jolts and the phone buzzes. Misses show but stay quiet.


func _play_screen() -> Array:
	UIHarness.fresh_profile()
	Profile.set_setting("vibration", true)
	var song := SongLibrary.story()[1]
	var app := UIHarness.make_app(tree, "play", {"song_id": song.id, "difficulty": "easy", "bell_set": "light"})
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
	check((Sound.get("_next") as PackedInt32Array)[2] != foot_before, "the step sound started")
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
	# Judge one note early and one late through the session, as the router would.
	s.tap(steps[0].lane, steps[0].t - 0.07, 1)
	s.tap(steps[1].lane, steps[1].t + 0.07, 2)
	var texts: Array[String] = []
	for spot in (words.get("_spots") as Dictionary).values():
		texts.append((spot[1] as Label).text + "/" + (spot[2] as Label).text)
	var joined := " ".join(texts)
	check(joined.contains(tr("judge_hint_early")) or joined.contains(tr("judge_early")), "an early hit says early (%s)" % joined)
	check(joined.contains(tr("judge_hint_late")) or joined.contains(tr("judge_late")), "a late hit says late (%s)" % joined)
	UIHarness.free_app(app)
	UIHarness.restore_profile()
