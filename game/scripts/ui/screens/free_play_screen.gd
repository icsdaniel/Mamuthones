extends Screen
## Free play: any unlocked song at any difficulty with any unlocked bell set, the remix when earned.
## Every song row shows its best bells and best score, every difficulty its own bells and best, so the
## list reads at a glance; below, the best for the choice and whether a ghost is there to race.

var song: SongData
var difficulty := "easy"
var use_remix := false
var _song_buttons := {}
var _diff_box: GridContainer
var _info: Label
var _remix: CheckButton


func build() -> void:
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	UIKit.header(box, tr("free_title"), on_back)
	box.add_child(UIKit.label(tr("free_song"), UIKit.SUB))
	for s in SongLibrary.story():
		var open := Progression.is_unlocked(s.id)
		var b := UIKit.button("%d · %s" % [s.stop, UIKit.song_title(s)] if open else tr("free_locked") % s.stop,
			_pick_song.bind(s))
		b.toggle_mode = true
		b.disabled = not open
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Song_" + s.id
		if open:
			var top := _best_of(s.id)
			_badge(b, UIKit.best_bells(s.id), UIKit.fmt_score(top) if top > 0 else "")
		box.add_child(b)
		_song_buttons[s.id] = b
	box.add_child(UIKit.label(tr("stop_difficulty"), UIKit.SUB))
	_diff_box = GridContainer.new()
	_diff_box.columns = 2
	_diff_box.add_theme_constant_override("h_separation", 12)
	_diff_box.add_theme_constant_override("v_separation", 12)
	box.add_child(_diff_box)
	UIKit.bell_set_picker(box)
	_remix = CheckButton.new()
	_remix.custom_minimum_size.y = UIKit.TOUCH
	_remix.focus_mode = Control.FOCUS_NONE
	_remix.toggled.connect(func(on: bool) -> void:
		use_remix = on
		_pick_song(song))
	_remix.name = "Remix"
	box.add_child(_remix)
	_info = UIKit.label("", UIKit.CAPTION)
	box.add_child(_info)
	var play := UIKit.button(tr("stop_play"), _play, UIKit.PRIMARY)
	play.name = "Play"
	cols[1].add_child(play)
	var first := SongLibrary.get_song(Progression.next_stop())
	for s in SongLibrary.story():
		if Progression.is_unlocked(s.id) and first == null:
			first = s
	if first != null:
		_pick_song(first)


func _pick_song(s: SongData) -> void:
	song = s
	for id in _song_buttons:
		(_song_buttons[id] as Button).set_pressed_no_signal(id == s.id)
	for c in _diff_box.get_children():
		c.queue_free()
	if not difficulty in s.difficulties():
		difficulty = s.difficulties()[0]
	for d in s.difficulties():
		var b := UIKit.button(tr("diff_" + d), _pick_diff.bind(d))
		b.toggle_mode = true
		b.set_pressed_no_signal(d == difficulty)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Diff_" + d
		var best: Dictionary = Profile.best(UIKit.board_song_id(s, use_remix), d)
		_badge(b, int(best.get("bells", 0)), "")
		_diff_box.add_child(b)
	var remix_open := s.has_remix() and Progression.remix_unlocked(s.id)
	_remix.visible = s.has_remix()
	_remix.disabled = not remix_open
	_remix.text = tr("stop_remix") if remix_open else tr("stop_remix_locked")
	if not remix_open:
		use_remix = false
		_remix.set_pressed_no_signal(false)
	_refresh()


## Best score of a song over every difficulty (0 when never played).
static func _best_of(song_id: String) -> int:
	var s := SongLibrary.get_song(song_id)
	var out := 0
	if s != null:
		for d in s.difficulties():
			out = maxi(out, int(Profile.best(song_id, d).get("score", 0)))
	return out


## Bells (and a score) at the right end of a list button.
func _badge(b: Button, bells: int, score: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Best"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	row.offset_right = -14.0
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if score != "":
		var l := UIKit.label(score, UIKit.CAPTION, false)
		l.name = "Score"
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	var marks := BellMarks.new(bells, 24.0)
	marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(marks)
	b.add_child(row)


func _pick_diff(d: String) -> void:
	difficulty = d
	for c in _diff_box.get_children():
		(c as Button).set_pressed_no_signal(c.name == "Diff_" + d)
	_refresh()


func _refresh() -> void:
	if song == null:
		return
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	if best.is_empty():
		_info.text = tr("stop_no_best")
	else:
		_info.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), int(best.get("bells", 0))]
		if not (best.get("ghost", {}) as Dictionary).is_empty():
			_info.text += "\n" + tr("free_ghost")


func _play() -> void:
	if song == null:
		return
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"bell_set": str(Profile.get_look().get("bell_set", "light")),
		"remix": use_remix,
	})
