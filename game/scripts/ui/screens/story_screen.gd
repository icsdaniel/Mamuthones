extends Screen
## The story map: the procession's journey through Mamoiada, one window onto the village per stop,
## top to bottom, joined by a gold path. Each window is that stop's pixel world (StopPicture, alive:
## the fires burn, the row jumps) in a gold frame, with the stop's number, name, day, bells earned and
## remix on a navy plate. The next stop's frame is bright, locked stops lie under the night veil. A goal
## line at the top says what the player is closest to unlocking.

const ROW_H := 300.0
const PLATE_H := 74.0
const PATH_H := 30.0


func build() -> void:
	var box := UIKit.column(self, true, 0)
	UIKit.header(box, tr("story_title"), on_back)
	UIKit.spacer(box, 14.0)
	var goal := UIKit.goal_text()
	if goal != "":
		var g := UIKit.card(box)
		g.add_child(UIKit.label(tr("story_next_goal"), UIKit.SUB))
		g.add_child(UIKit.label(goal))
		UIKit.spacer(box, 18.0)
	var next_id := Progression.next_stop()
	var story := SongLibrary.story()
	for i in story.size():
		var song: SongData = story[i]
		box.add_child(_row(song, song.id == next_id))
		if i + 1 < story.size():
			box.add_child(_Path.new(Progression.cleared(song.id), Progression.is_unlocked(story[i + 1].id)))
	UIKit.spacer(box, 20.0)


func _row(song: SongData, is_next: bool) -> Control:
	var open := Progression.is_unlocked(song.id)
	var b := Button.new()
	b.name = "Stop%d" % song.stop
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.disabled = not open
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		Sound.ui("tap")
		app.open("stop_card", {"song_id": song.id}))
	var pic := StopPicture.new()
	pic.name = "Picture"
	pic.stop = song.stop
	pic.view = "band"
	pic.px = int(PixelFrame.px_for(self))
	var ground := float(StopBackdrops.data(song.stop).ground)
	var card: Vector2i = StopBackdrops.data(song.stop).card
	# Centre on the card, low enough that the row's feet stand just above the plate.
	var ppx := PixelFrame.px_for(self)
	var shown_below := (ROW_H * 0.5 - PLATE_H - float(PixelFrame.DEPTH) * ppx) / ppx
	pic.focus = Vector2(float(card.x) + float(StopCells.CARD.x) * 0.5, ground - shown_below + 4.0)
	pic.frame_style = "bright" if is_next else ("gold" if open else "dim")
	pic.veiled = not open
	pic.animate = open and not UIKit.reduced_motion()
	pic.bpm = song.bpm * 0.5
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	b.button_down.connect(func() -> void: pic.frame_style = "bright")
	b.button_up.connect(func() -> void: pic.frame_style = "bright" if is_next else "gold")
	# The plate: the stop's number, name and status on navy, under a gold rule.
	var plate := _Plate.new(is_next, open)
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var px := PixelFrame.px_for(self)
	var inset := float(PixelFrame.DEPTH) * px
	plate.offset_left = inset
	plate.offset_right = -inset
	plate.offset_top = -inset - PLATE_H
	plate.offset_bottom = -inset
	plate.px = px
	b.add_child(plate)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -12
	row.offset_top = 6
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	var num := _Medallion.new(song.stop, is_next, open, px)
	num.custom_minimum_size = Vector2(60, 0)
	row.add_child(num)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size.x = 1
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := UIKit.label(UIKit.song_title(song), UIKit.SUB, false)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", PixelPalette.BONE[3] if open else PixelPalette.BONE[1])
	text.add_child(name_label)
	var status := UIKit.label(_status(song, open, is_next), UIKit.CAPTION, false)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.add_theme_color_override("font_color", PixelPalette.GOLD[4] if is_next else (PixelPalette.BONE[2] if open else PixelPalette.BONE[1]))
	text.add_child(status)
	var grade := GradeBadge.new(UIKit.best_grade(song.id))
	grade.name = "Grade"
	grade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grade.visible = open
	row.add_child(grade)
	for c in [row, text, num, grade, name_label, status, plate]:
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
	elif Progression.cleared(song.id):
		parts.append(tr("story_cleared"))
	if song.has_remix() and Progression.remix_unlocked(song.id):
		parts.append(tr("story_remix_open"))
	return " · ".join(parts)


## The navy plate under a stop's window: solid NAVY0 with a gold rule along its top edge.
class _Plate:
	extends Control
	var px := 3.0
	var next := false
	var open := true

	func _init(p_next: bool, p_open: bool) -> void:
		next = p_next
		open = p_open

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, PixelPalette.NAVY[0])
		draw_rect(Rect2(0, 0, size.x, px), PixelPalette.K[0])
		draw_rect(Rect2(0, px, size.x, px), PixelPalette.GOLD[4] if next else (PixelPalette.GOLD[2] if open else PixelPalette.GOLD[0]))
		# a faint woven band along the bottom, like the kit's buttons
		for x in range(0, int(size.x / px), 4):
			draw_rect(Rect2(x * px, size.y - px * 3.0, px, px), PixelPalette.NAVY[2])
			draw_rect(Rect2((x + 2) * px, size.y - px * 2.0, px, px), PixelPalette.NAVY[2])


## The stop's number in a diamond medallion: red for the next stop, gold when open, dark when locked.
class _Medallion:
	extends Control
	var n := 1
	var next := false
	var open := true
	var px := 3.0

	func _init(p_n: int, p_next: bool, p_open: bool, p_px: float) -> void:
		n = p_n
		next = p_next
		open = p_open
		px = p_px

	func _draw() -> void:
		var c := (size * 0.5 / px).floor() * px
		var col: Color = PixelPalette.RED[3] if next else (PixelPalette.GOLD[2] if open else PixelPalette.NAVY[2])
		PixelFrame.diamond(self, c, px, col, 6)
		var f := Palette.display_font()
		var s := str(n)
		var fs := 34
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := c + Vector2(-w * 0.5, fs * 0.36)
		draw_string(f, base + Vector2(0, 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PixelPalette.K[0])
		draw_string(f, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PixelPalette.BONE[4] if open else PixelPalette.BONE[1])


## The gold path joining one stop to the next: dotted steps down the page with a small diamond; lit
## once the stop above is cleared.
class _Path:
	extends Control
	var lit := false
	var open := false

	func _init(p_lit: bool, p_open: bool) -> void:
		lit = p_lit
		open = p_open
		custom_minimum_size = Vector2(0, PATH_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var px := PixelFrame.px_for(self)
		var x := floorf(size.x * 0.5 / px) * px
		var col: Color = PixelPalette.GOLD[4] if lit else PixelPalette.GOLD[1]
		var y := 0.0
		var i := 0
		while y < size.y:
			if i % 2 == 0:
				draw_rect(Rect2(x - px, y, px * 3.0, px), PixelPalette.K[0])
				draw_rect(Rect2(x, y, px, px), col)
			y += px
			i += 1
		PixelFrame.diamond(self, Vector2(x, size.y * 0.5), px, PixelPalette.RED[3] if open else PixelPalette.NAVY[2], 2)
