extends TestCase
## The "what makes it a 10" round: early/late on steps readable without words (a tick at the lane,
## cool above the hit line, warm below, gone in 0.3 s; a duller knock on Ok), the kept stand-still's
## moment and its share on results.


static func _auto(s: Session) -> Session:
	var a := Autoplay.new(s)
	var t := -1.0
	while not s.is_over(t) and t < 600.0:
		t += 0.05
		a.update(t)
	return s


func _steps(s: Session) -> Array[Note]:
	var out: Array[Note] = []
	for n in s.notes:
		if n.kind == Note.Kind.STEP:
			out.append(n)
	return out


func test_step_ticks_say_early_or_late_at_a_glance() -> void:
	var script: GDScript = load(App.SCREENS["play"])
	check_eq(script.step_quality("perfect"), "perfect", "Perfect knocks clean")
	check_eq(script.step_quality("good"), "good", "Good knocks clean")
	check_eq(script.step_quality("early"), "ok", "an Ok step (early) knocks dull")
	check_eq(script.step_quality("late"), "ok", "an Ok step (late) knocks dull")
	check_eq(script.step_quality("miss"), "", "a miss has no step quality")
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", {"song_id": "fires", "difficulty": "hard", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var w := s.window("touch")
	var off := (w.x + w.y) * 0.5          # inside Good, outside Perfect
	var steps := _steps(s)
	if not check(steps.size() >= 3, "the song has steps"):
		UIHarness.free_app(app)
		UIHarness.restore_profile()
		return
	# Early: a cool tick above the line at that lane.
	var a := steps[0]
	s.tap(a.lane, a.t - off, 3)
	check(a.judgement in ["good", "early"], "a Good-early hit (%s)" % a.judgement)
	check_eq(lanes.step_ticks_shown(), ["early"] as Array[String], "an early step leaves an early tick")
	check_eq(play.get("_tap_quality"), script.step_quality(a.judgement), "the knock gets the hit's quality")
	play.call("_on_stepped", a.lane)
	# It is gone within 0.3 s.
	lanes.set("_clock", float(lanes.get("_clock")) + LaneView.STEP_TICK_TIME + 0.01)
	check(lanes.step_ticks_shown().is_empty(), "the tick is gone after 0.3 s")
	# Late: a warm tick below the line.
	var b := steps[1]
	s.tap(b.lane, b.t + off, 4)
	check(b.judgement in ["good", "late"], "a Good-late hit (%s)" % b.judgement)
	check_eq(lanes.step_ticks_shown(), ["late"] as Array[String], "a late step leaves a late tick")
	play.call("_on_stepped", b.lane)
	lanes.set("_clock", float(lanes.get("_clock")) + LaneView.STEP_TICK_TIME + 0.01)
	# An Ok (outer band) early step ticks too.
	var c := steps[2]
	s.tap(c.lane, c.t - (w.y + w.z) * 0.5, 5)
	check_eq(c.judgement, "early", "an Ok-band early hit")
	check_eq(lanes.step_ticks_shown(), ["early"] as Array[String], "the Ok band ticks on its side")
	check_eq(play.get("_tap_quality"), "ok", "and knocks dull")
	play.call("_on_stepped", c.lane)
	lanes.set("_clock", float(lanes.get("_clock")) + LaneView.STEP_TICK_TIME + 0.01)
	# Perfect: no tick.
	if steps.size() > 3:
		var d := steps[3]
		s.tap(d.lane, d.t, 6)
		check_eq(d.judgement, "perfect", "a centred hit is Perfect")
		check(lanes.step_ticks_shown().is_empty(), "Perfect leaves no tick")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_kept_still_has_its_moment_and_share() -> void:
	var results: GDScript = load(App.SCREENS["results"])
	check_eq(results.still_share(0.0, 1000), 0, "no share when stillness added nothing")
	check_eq(results.still_share(50.0, 1000), 5, "5% of the score")
	check_eq(results.still_share(1.0, 100000), 1, "a tiny share still shows as 1%")
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", {"song_id": "fires", "difficulty": "hard", "bell_set": "light"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var s: Session = play.get("session")
	var rest: Note = null
	for n in s.notes:
		if n.kind == Note.Kind.REST:
			rest = n
			break
	if check(rest != null, "the song has a stand-still"):
		s.emit_signal("still_kept", rest, 300.0)
		var m: StillMoment = play.get("still_moment")
		check_eq(m.shown(), tr("still_moment"), "the row stands as one")
		check(m.get_parent() == play.get("banner"), "over the top of the lanes, away from the hit line")
	UIHarness.free_app(app)
	UIHarness.restore_profile()

