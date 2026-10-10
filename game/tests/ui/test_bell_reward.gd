extends TestCase
## Rewards for playing on time: a bell rung Perfect or Good strikes across the road and builds a
## chain that an Ok ring or a missed bell breaks; a step hit on time sends light up its lane.


func _first(s: Session, kind: Note.Kind) -> Note:
	for n in s.notes:
		if n.kind == kind:
			return n
	return null


func test_on_time_bells_strike_and_chain() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", {"song_id": "fires", "difficulty": "hard"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var lanes: LaneView = play.get("lanes")
	check(lanes.strikes_shown().is_empty(), "no strike before any bell")
	play.call("_on_rang", {"up": true, "quality": "perfect", "strength": 0.5})
	check_eq(lanes.strikes_shown(), ["up:perfect"] as Array[String], "a Perfect bell strikes")
	check_eq(play.get("_bell_chain"), 1, "and starts a chain")
	play.call("_on_rang", {"up": false, "quality": "good", "strength": 0.5})
	check_eq(play.get("_bell_chain"), 2, "a Good bell keeps the chain going")
	check(lanes.strikes_shown().has("down:good"), "and strikes too")
	play.call("_on_rang", {"up": true, "quality": "free", "strength": 0.5})
	check_eq(play.get("_bell_chain"), 2, "a free tilt (no bell near) neither strikes nor breaks the chain")
	play.call("_on_rang", {"up": true, "quality": "early", "strength": 0.5})
	check_eq(play.get("_bell_chain"), 0, "an Ok (early) ring breaks the chain")
	lanes.set("_clock", float(lanes.get("_clock")) + StreetSkin.STRIKE_TIME + 0.01)
	check(lanes.strikes_shown().is_empty(), "the strike is gone after %.1f s" % StreetSkin.STRIKE_TIME)
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_on_time_steps_light_their_lane() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "play", {"song_id": "fires", "difficulty": "hard"})
	await UIHarness.frames(tree, 3)
	var play := app.current()
	var s: Session = play.get("session")
	var lanes: LaneView = play.get("lanes")
	var n := _first(s, Note.Kind.STEP)
	if not check(n != null, "the song has a step"):
		UIHarness.free_app(app)
		UIHarness.restore_profile()
		return
	s.tap(n.lane, n.t, 3)
	check_eq(n.judgement, "perfect", "a centred step is Perfect")
	check_eq(lanes.pulses_shown(), [n.lane] as Array[int], "light runs up its lane")
	lanes.set("_clock", float(lanes.get("_clock")) + LaneView.PULSE_TIME * 1.6)
	check(lanes.pulses_shown().is_empty(), "and is gone soon after")
	UIHarness.free_app(app)
	UIHarness.restore_profile()
