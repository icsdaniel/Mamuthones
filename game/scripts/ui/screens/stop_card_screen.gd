extends Screen
## The card before a story stop: the woodcut picture, the stop's name and day, two plain sentences
## about the moment, then the difficulty (with the best bells for each), the bell set and the remix.
## args: song_id.

static var last_difficulty := "easy"

var song: SongData
var difficulty := "easy"
var use_remix := false
var _diff_buttons := {}
var _best: Label


func build() -> void:
	song = SongLibrary.get_song(args.get("song_id", ""))
	if song == null:
		push_error("stop card: unknown song %s" % args.get("song_id", ""))
		return
	difficulty = last_difficulty if last_difficulty in song.difficulties() else song.difficulties()[0]
	var cols := UIKit.column_with_footer(self, 16)
	var box := cols[0]
	var foot := cols[1]
	UIKit.header(box, tr("stop_n") % song.stop, on_back)
	var pic := TextureRect.new()
	pic.texture = StopArt.card(song.stop)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 330)
	pic.name = "Picture"
	box.add_child(pic)
	var facts := UIKit.card(box, true)
	facts.add_child(UIKit.label(UIKit.song_title(song), UIKit.PAPER_HEADER))
	if UIKit.stop_date(song) != "":
		facts.add_child(UIKit.label(UIKit.stop_date(song), UIKit.PAPER))
	facts.add_child(UIKit.label(tr("stop_fact_%d" % song.stop), UIKit.PAPER))

	if song.kind == "tutorial":
		var lessons := UIKit.button(tr("stop_lessons"), func() -> void: app.open("tutorial", {"song_id": song.id}), UIKit.PRIMARY)
		lessons.name = "Lessons"
		foot.add_child(lessons)

	# The difficulty heading carries the Remix chip once it is earned, so the reason to replay is in
	# view next to the difficulty buttons.
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	box.add_child(dh)
	var dl := UIKit.label(tr("stop_difficulty"), UIKit.SUB)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	if song.has_remix() and Progression.remix_unlocked(song.id):
		var chip := UIKit.button(tr("stop_remix_chip"), func() -> void: pass)
		chip.toggle_mode = true
		chip.name = "Remix"
		chip.custom_minimum_size.x = 200
		chip.toggled.connect(func(on: bool) -> void: use_remix = on)
		dh.add_child(chip)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for d in song.difficulties():
		var b := UIKit.button(tr("diff_" + d), _pick.bind(d))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Diff_" + d
		grid.add_child(b)
		_diff_buttons[d] = b
	_best = UIKit.label("", UIKit.CAPTION)
	box.add_child(_best)
	UIKit.bell_set_picker(box)
	if song.has_remix() and not Progression.remix_unlocked(song.id):
		var r := UIKit.label(tr("stop_remix_locked"), UIKit.CAPTION)
		r.name = "RemixLocked"
		box.add_child(r)
	var play := UIKit.button(tr("stop_play"), _play, "" if song.kind == "tutorial" else UIKit.PRIMARY)
	play.name = "Play"
	foot.add_child(play)
	_pick(difficulty)


func _pick(d: String) -> void:
	difficulty = d
	last_difficulty = d
	for k in _diff_buttons:
		(_diff_buttons[k] as Button).set_pressed_no_signal(k == d)
	var best: Dictionary = Profile.best(song.id, d)
	if best.is_empty():
		_best.text = tr("stop_no_best")
	else:
		_best.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), int(best.get("bells", 0))]


func _play() -> void:
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"bell_set": str(Profile.get_look().get("bell_set", "light")),
		"remix": use_remix,
	})
