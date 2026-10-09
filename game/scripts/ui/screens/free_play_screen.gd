extends Screen
## Free play (the second mode tab): every song at every difficulty (all open from the start), any unlocked bell set, the
## remix when earned. Pick the difficulty first; the song list then shows each song's best score and
## grade at that difficulty, so the list reads at a glance. Below, whether a ghost is there to race.

var song: SongData
var difficulty := "easy"
var use_remix := false
var _song_buttons := {}
var _diff_box: VBoxContainer
var _info: Label
var _remix: CheckButton


func build() -> void:
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	UIKit.mode_tabs(self, box)
	box.add_child(UIKit.label(tr("stop_difficulty"), UIKit.SUB))
	# One row of four, equal widths; two rows of two where the four don't fit (small phones, Italian).
	_diff_box = VBoxContainer.new()
	_diff_box.add_theme_constant_override("separation", 6)
	box.add_child(_diff_box)
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	_diff_box.add_child(diff_row)
	_diff_box.resized.connect(_fit_diffs)
	resized.connect(_fit_diffs)
	diff_row.minimum_size_changed.connect(_fit_diffs, CONNECT_DEFERRED)
	for d in SongData.DIFFICULTIES:
		var b := UIKit.button(tr("diff_" + d), _pick_diff.bind(d))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0
		b.name = "Diff_" + d
		b.clip_text = true
		diff_row.add_child(b)
	box.add_child(UIKit.label(tr("free_song"), UIKit.SUB))
	for s in SongLibrary.story():
		var b := UIKit.button("%d · %s" % [s.stop, UIKit.song_title(s)], _pick_song.bind(s))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.name = "Song_" + s.id
		b.custom_minimum_size.y = UIKit.TOUCH + 16
		box.add_child(b)
		_song_buttons[s.id] = b
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
	if first == null and not SongLibrary.story().is_empty():
		first = SongLibrary.story()[0]
	_pick_diff(difficulty)
	if first != null:
		_pick_song(first)


func _pick_song(s: SongData) -> void:
	song = s
	for id in _song_buttons:
		(_song_buttons[id] as Button).set_pressed_no_signal(id == s.id)
	var remix_open := s.has_remix() and Progression.remix_unlocked(s.id)
	_remix.visible = s.has_remix()
	_remix.disabled = not remix_open
	_remix.text = tr("stop_remix") if remix_open else tr("stop_remix_locked")
	if not remix_open:
		use_remix = false
		_remix.set_pressed_no_signal(false)
	_show_bests()
	_refresh()


## Splits the difficulty row in two when its four buttons need more than the width there is.
func _fit_diffs() -> void:
	var row: HBoxContainer = _diff_box.get_child(0)
	# The column stretches to its content, so measure against the screen less its side margins
	# and the list's scroll bar.
	var room := minf(size.x - 2.0 * (UIKit.GUTTER + UIKit.safe_margins(self).x), UIKit.COLUMN_MAX)
	var sc := _diff_box.get_parent().get_parent() as ScrollContainer
	if sc != null:
		room -= sc.get_v_scroll_bar().get_combined_minimum_size().x
	if _diff_box.get_child_count() > 1 or room <= 0.0 or row.get_combined_minimum_size().x <= room + 0.5:
		return
	var second := HBoxContainer.new()
	second.add_theme_constant_override("separation", 6)
	_diff_box.add_child(second)
	var half := row.get_child_count() / 2
	for c in row.get_children().slice(half):
		c.reparent(second)


func _pick_diff(d: String) -> void:
	difficulty = d
	for row in _diff_box.get_children():
		for c in row.get_children():
			(c as Button).set_pressed_no_signal(c.name == "Diff_" + d)
	_show_bests()
	_refresh()


## Every song row shows its best at the chosen difficulty: score and grade (the remix's when the
## remix is on for the chosen song).
func _show_bests() -> void:
	for id in _song_buttons:
		var b: Button = _song_buttons[id]
		var sd := SongLibrary.get_song(id)
		var best: Dictionary = Profile.best(UIKit.board_song_id(sd, use_remix and sd == song), difficulty)
		_badge(b, UIKit.grade_of(best), UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else "", bool(best.get("full_combo", false)))


## The best score and grade at the right end of a song row.
func _badge(b: Button, grade: int, score: String, fc := false) -> void:
	var old := b.get_node_or_null("Best")
	if old != null:
		b.remove_child(old)
		old.queue_free()
	var row := HBoxContainer.new()
	row.name = "Best"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	row.offset_right = -46.0   # clear of the frame's right-hand diamond
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if score != "":
		var l := UIKit.label(score, UIKit.CAPTION, false)
		l.name = "Score"
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_color_override("font_color", PixelPalette.GOLD[5])
		row.add_child(l)
	var badge := GradeBadge.new(grade, false, fc)
	badge.name = "Grade"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	b.add_child(row)


func _refresh() -> void:
	if song == null:
		return
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	if best.is_empty():
		_info.text = tr("stop_no_best")
	else:
		_info.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), Session.grade_name(UIKit.grade_of(best))]
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
