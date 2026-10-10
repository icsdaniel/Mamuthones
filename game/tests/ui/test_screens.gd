extends TestCase
## Every screen builds at every supported size, in English and Italian, with touch targets of at
## least 88 px, text of at least 24 px, and nothing wider than the screen.

const MIN_TOUCH := 88.0
const MIN_TEXT := 24


func _cases() -> Array:
	var story := SongLibrary.story()
	var tut := story[0].id if not story.is_empty() else ""
	var song := story[1].id if story.size() > 1 else tut
	var s := Session.new(SongLibrary.get_song(song), "easy")
	var auto := Autoplay.new(s, true)
	auto.update(s.end_time())
	return [
		["language", {}], ["headphones", {}], ["calibration", {"first_run": true}], ["latency", {"first_run": true}],
		["title", {}], ["story", {}], ["stop_card", {"song_id": song}], ["stop_card", {"song_id": tut}],
		["free_play", {}], ["boards", {}],
		["settings", {}], ["credits", {}],
		["workshop", {"tab": "mask"}], ["workshop", {"tab": "dress"}],
		["tutorial", {"song_id": tut}],
		["play", {"song_id": song, "difficulty": "easy", "autoplay": true}],
		["results", {"session": s, "record": {"prev_best": 1000, "new_best": true, "unlocked": [{"kind": "song", "id": song}], "carving_gained": 1},
			"play_args": {"song_id": song, "difficulty": "easy"}}],
	]


func test_every_screen_builds_and_fits() -> void:
	UIHarness.fresh_profile()
	check(not SongLibrary.story().is_empty(), "songs are available")
	for size in UIHarness.SIZES:
		for locale in ["en", "it"]:
			Profile.set_setting("language", locale)
			for case in _cases():
				var app := UIHarness.make_app(tree, case[0], case[1], size)
				await UIHarness.settle(tree)
				var what := "%s %s %dx%d" % [case[0], locale, size.x, size.y]
				var screen := app.current()
				if check(screen != null and screen.get_child_count() > 0, "%s builds" % what):
					_check_layout(screen, what, app.get_viewport_rect().size.x)
				UIHarness.free_app(app)
				await UIHarness.frames(tree, 1)
	UIHarness.restore_profile()


func _check_layout(screen: Control, what: String, width: float) -> void:
	for c in UIHarness.visible_controls(screen):
		var r := c.get_global_rect()
		if c is BaseButton and not (c is CheckBox) and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			check(r.size.x >= MIN_TOUCH - 0.5 and r.size.y >= MIN_TOUCH - 0.5,
				"%s: button '%s' is %s, under %d px" % [what, _label(c), r.size, MIN_TOUCH])
		if c is Label or c is Button or c is LineEdit:
			var fs := c.get_theme_font_size("font_size")
			check(fs >= MIN_TEXT, "%s: '%s' text is %d px" % [what, _label(c), fs])
		if _in_scroll_or_clip(c):
			continue
		check(r.position.x >= -1.0 and r.end.x <= width + 1.0,
			"%s: %s '%s' spills sideways (%s..%s of %s)" % [what, c.get_class(), _label(c), r.position.x, r.end.x, width])
		if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF \
				and (c as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and (c as Label).text != "":
			var need := (c as Label).get_minimum_size().x
			check(need <= r.size.x + 2.0, "%s: label '%s' needs %d px, has %d" % [what, (c as Label).text, need, r.size.x])


func _in_scroll_or_clip(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		if p is Control and (p as Control).clip_contents and not (p is ScrollContainer):
			return true
		p = p.get_parent()
	return false


func _label(c: Control) -> String:
	if c is Button:
		return (c as Button).text.replace("\n", " ") if (c as Button).text != "" else String(c.name)
	if c is Label:
		return (c as Label).text.substr(0, 40)
	return String(c.name)
