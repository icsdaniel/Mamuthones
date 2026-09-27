extends Screen
## The story map: the seven stops of the procession, top to bottom. Each shows whether it is open,
## the bells earned (best over all difficulties), its remix, and the next stop is marked. A goal line
## at the top says what the player is closest to unlocking.


func build() -> void:
	var box := UIKit.column(self, true, 14)
	UIKit.header(box, tr("story_title"), on_back)
	var goal := UIKit.goal_text()
	if goal != "":
		var g := UIKit.card(box)
		g.add_child(UIKit.label(tr("story_next_goal"), UIKit.SUB))
		g.add_child(UIKit.label(goal))
	var next_id := Progression.next_stop()
	for song in SongLibrary.story():
		box.add_child(_row(song, song.id == next_id))


func _row(song: SongData, is_next: bool) -> Control:
	var open := Progression.is_unlocked(song.id)
	var b := Button.new()
	b.name = "Stop%d" % song.stop
	b.custom_minimum_size = Vector2(0, 150)
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = UIKit.PRIMARY if is_next else ""
	b.disabled = not open
	b.pressed.connect(func() -> void:
		Sound.ui("tap")
		app.open("stop_card", {"song_id": song.id}))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var num := UIKit.label(str(song.stop), UIKit.HEADER, false, HORIZONTAL_ALIGNMENT_CENTER)
	num.custom_minimum_size.x = 56
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 1
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_label := UIKit.label(UIKit.song_title(song), UIKit.SUB, false)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	var status := UIKit.label(_status(song, open, is_next), UIKit.CAPTION, true)
	text.add_child(status)
	var bells := BellMarks.new(UIKit.best_bells(song.id), 36.0)
	if is_next:
		# On the red of the next stop, gold and grey go muddy: bone reads.
		name_label.add_theme_color_override("font_color", Palette.BONE)
		status.add_theme_color_override("font_color", Color(Palette.BONE, 0.85))
	bells.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bells.visible = open
	row.add_child(bells)
	for c in row.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in text.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _status(song: SongData, open: bool, is_next: bool) -> String:
	if not open:
		return tr("story_locked")
	var parts: Array[String] = []
	var date := UIKit.stop_date(song)
	if date != "":
		parts.append(date)
	if is_next:
		parts.append(tr("story_next"))
	elif UIKit.best_bells(song.id) > 0:
		parts.append(tr("story_cleared"))
	if song.has_remix() and Progression.remix_unlocked(song.id):
		parts.append(tr("story_remix_open"))
	return " · ".join(parts)
