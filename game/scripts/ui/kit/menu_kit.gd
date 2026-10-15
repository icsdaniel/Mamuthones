class_name MenuKit
extends RefCounted
## Menu-screen parts built on the kit (UIKit, WoodcutTheme tokens, PxStyle), for the screens of the
## 2026-10 menu rework: title, story, stop card, free play, settings, scores, credits, the first-run
## steps and the play screen's pause / fail sheets. Kept apart from ui_kit.gd so the kit's own file
## stays the kit's; everything here only composes the kit's public builders and tokens.
##
##   row_button()   a 96 px list row (song rows): a sheepskin face, selected = bronze rim (no lip,
##                  no sink, so a row never changes height); fill the returned HBox
##   grade_mark()   a small round GradeSeal plus a bronze "FC" pill (an empty sunk ring when never
##                  played); set_grade() updates it in place
##   group()        a grouped list: an optional overline, then one BoardPanel whose rows are split
##                  by one-art-px dividers; nav_row(), toggle_row(), slider_row(), value_row() fill it
##   quick_tiles()  the title's row of four equal quick-action tiles (icon over a label)
##   instruction()  a setup screen's instruction (sans, secondary colour)
##   hero_button()  the primary with a second, smaller line under its words
##   bottom_sheet() an opaque sheet rising from the bottom over a veil (pause, fail); it ignores
##                  presses for ARM_DELAY after it appears
##   lock_line()    a lock icon and the requirement to open something
##   picture_card() a card whose top is a picture with the card's rounded corners

const ROW_H := 96
const DIVIDER := 3.0
## Seconds a bottom sheet ignores presses after it appears.
const ARM_DELAY := 0.4


# ---------------------------------------------------------------- list rows


## A list row: returns [Button, HBox]. `toggle` rows light with a bronze rim when pressed.
static func row_button(id: String, on_press: Callable, toggle := false, height := ROW_H) -> Array:
	var b := Button.new()
	b.name = id
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UIKit.TOUCH, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := Vector4(18, 0, 18, 0)
	var normal := PxStyle.make(Color(WoodcutTheme.C_SURFACE, 0.9), Color(WoodcutTheme.C_STROKE, 0.9), WoodcutTheme.R_M, pad)
	normal.highlight = Color(WoodcutTheme.C_RAISED_HI, 0.9)
	var on := PxStyle.make(WoodcutTheme.C_RAISED, WoodcutTheme.C_BRONZE, WoodcutTheme.R_M, pad)
	on.highlight = WoodcutTheme.C_STROKE_HI
	var down := PxStyle.make(WoodcutTheme.C_RAISED, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_M, pad)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", on if toggle else down)
	b.add_theme_stylebox_override("hover_pressed", on if toggle else down)
	if on_press.is_valid():
		b.pressed.connect(func() -> void:
			Sound.ui("tap")
			on_press.call())
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	b.add_child(m)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.S3)
	m.add_child(row)
	return [b, row]


## A title over a caption, filling the middle of a row. Returns [title, caption].
static func row_text(row: HBoxContainer, title: String, caption := "") -> Array:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	row.add_child(col)
	var t := UIKit.label(title, "", false)
	t.name = "Title"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("font", Palette.text_font("Bold"))
	UIKit.fit_label(t, 26)
	col.add_child(t)
	var c := UIKit.label(caption, UIKit.CAPTION, false)
	c.name = "Caption"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fit_label(c, 24)
	c.visible = caption != ""
	col.add_child(c)
	return [t, c]


## A small grade: the round bronze seal (F to S+) and, for a full combo, a bronze "FC" pill beside
## it; never played is a sunk empty ring. Update it in place with set_grade().
static func grade_mark(rank: int, full_combo := false) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = "Grade"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UIKit.S1)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(fc_pill())
	var seal := GradeSeal.new(maxi(rank, 0), 24, 1)
	seal.name = "Seal"
	seal.face = "caps"
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(seal)
	var empty := EmptyMark.new()
	empty.name = "Empty"
	empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(empty)
	set_grade(box, rank, full_combo)
	return box


## Shows `rank` (and the FC pill) on a grade_mark() without rebuilding it.
static func set_grade(box: HBoxContainer, rank: int, full_combo := false) -> void:
	var seal := box.get_node("Seal") as GradeSeal
	seal.visible = rank >= 0
	if rank >= 0 and seal.rank != rank:
		seal.rank = rank
	(box.get_node("Empty") as Control).visible = rank < 0
	(box.get_node("FC") as Control).visible = full_combo and rank >= 0


## Never played: a sunk empty ring in the rim colour, the size of the small seal.
class EmptyMark:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(72, 72)

	func _draw() -> void:
		var px := 3.0
		var c := (size * 0.5 / px).floor()
		var r := 11.0
		for y in range(int(-r), int(r)):
			var dy := float(y) + 0.5
			var hw := sqrt(maxf(r * r - dy * dy, 0.0))
			var x0 := roundi(-hw)
			var x1 := roundi(hw)
			draw_rect(Rect2((c + Vector2(x0, y)) * px, Vector2(x1 - x0, 1) * px), WoodcutTheme.C_STROKE)
		var ri := r - 2.0
		for y in range(int(-ri), int(ri)):
			var dy := float(y) + 0.5
			var hw := sqrt(maxf(ri * ri - dy * dy, 0.0))
			var x0 := roundi(-hw)
			var x1 := roundi(hw)
			draw_rect(Rect2((c + Vector2(x0, y)) * px, Vector2(x1 - x0, 1) * px), Color(0.027, 0.024, 0.055, 1.0))


## The full-combo mark: "FC" in the pixel capitals on a small bronze pill.
static func fc_pill() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "FC"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := PxStyle.make(WoodcutTheme.C_RAISED_HI, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_PILL, Vector4(12, 3, 12, 3))
	p.add_theme_stylebox_override("panel", sb)
	var l := UIKit.overline("FC", HORIZONTAL_ALIGNMENT_CENTER)
	l.clip_text = false
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.custom_minimum_size.x = 0
	p.add_child(l)
	return p


# ---------------------------------------------------------------- grouped lists


## A grouped list: an overline (when `header` is not ""), then one card holding rows split by
## dividers. Returns the card's VBox; add rows with nav_row() / toggle_row() / slider_row().
static func group(box: Container, header := "") -> VBoxContainer:
	if header != "":
		var h := UIKit.overline(header)
		h.name = "Header"
		box.add_child(h)
	var p := PanelContainer.new()
	p.theme_type_variation = UIKit.BOARD
	var sb := (p.get_theme_stylebox("panel", UIKit.BOARD) as PxStyle)
	if sb != null:
		sb = sb.duplicate()
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.content_margin_left = 24
		sb.content_margin_right = 18
		p.add_theme_stylebox_override("panel", sb)
	box.add_child(p)
	var v := VBoxContainer.new()
	v.name = "Group"
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	return v


## A one-art-px line between two rows of a group (skipped before the first row).
static func _divide(g: VBoxContainer) -> void:
	if g.get_child_count() == 0:
		return
	var line := ColorRect.new()
	line.color = Color(WoodcutTheme.C_STROKE, 0.8)
	line.custom_minimum_size.y = DIVIDER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(line)


## A tappable row of a group: the label on the left, an optional value, a chevron on the right.
static func nav_row(g: VBoxContainer, id: String, title: String, on_press: Callable, value := "") -> Button:
	_divide(g)
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UIKit.TOUCH, ROW_H)
	var clear := StyleBoxEmpty.new()
	var down := PxStyle.make(WoodcutTheme.C_SUNK, Color.TRANSPARENT, WoodcutTheme.R_S, Vector4.ZERO)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, clear)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.pressed.connect(func() -> void:
		Sound.ui("tap")
		on_press.call())
	g.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.S2)
	b.add_child(row)
	var l := UIKit.label(title, "", false)
	l.name = "Label"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.fit_label(l, 26)
	row.add_child(l)
	if value != "":
		var v := UIKit.label(value, UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_RIGHT)
		v.name = "Value"
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(v)
	row.add_child(chevron())
	return b


static func chevron() -> TextureRect:
	var chev := TextureRect.new()
	chev.texture = WoodcutTheme.icon("chevron_right")
	chev.modulate = WoodcutTheme.C_BRONZE
	chev.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chev.custom_minimum_size = Vector2(30, 0)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chev


## A switch row of a group: the label (wrapping) on the left, the kit's toggle on the right, and an
## optional caption under it. Returns the CheckButton.
static func toggle_row(g: VBoxContainer, id: String, title: String, on: bool, on_toggle: Callable, note := "") -> CheckButton:
	_divide(g)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	g.add_child(col)
	var t := CheckButton.new()
	t.name = id
	t.text = title
	t.button_pressed = on
	t.custom_minimum_size.y = ROW_H
	t.focus_mode = Control.FOCUS_NONE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pad := StyleBoxEmpty.new()
	pad.content_margin_top = 12
	pad.content_margin_bottom = 12
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.add_theme_stylebox_override(st, pad)
	t.toggled.connect(func(v: bool) -> void:
		Sound.ui("tap")
		on_toggle.call(v))
	col.add_child(t)
	if note != "":
		var n := UIKit.label(note, UIKit.CAPTION)
		n.name = id + "Note"
		n.add_theme_constant_override("line_spacing", -2)
		col.add_child(n)
		UIKit.spacer(col, UIKit.S3)
	return t


## A slider row of a group: the label and its value on one line, the slider right under them.
## `fmt` turns the value into its text. Returns the HSlider (named "Slider_<key>").
static func slider_row(g: VBoxContainer, key: String, title: String, lo: float, hi: float, step: float,
		value: float, fmt: Callable, on_change: Callable) -> HSlider:
	_divide(g)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	g.add_child(col)
	UIKit.spacer(col, UIKit.S2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.S2)
	col.add_child(head)
	var l := UIKit.label(title, "", false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.fit_label(l, 26)
	head.add_child(l)
	var v := UIKit.label("", "", false, HORIZONTAL_ALIGNMENT_RIGHT)
	v.name = "Value_" + key
	v.add_theme_font_override("font", Palette.text_font("Bold"))
	v.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE)
	head.add_child(v)
	var s := HSlider.new()
	s.name = "Slider_" + key
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size.y = 72
	s.focus_mode = Control.FOCUS_NONE
	v.text = fmt.call(s.value)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt.call(x)
		on_change.call(x))
	col.add_child(s)
	return s


## A row of a group holding any control under an optional label (a segmented control, a picture).
static func control_row(g: VBoxContainer, title: String, c: Control, note := "") -> VBoxContainer:
	_divide(g)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UIKit.S2)
	g.add_child(col)
	UIKit.spacer(col, UIKit.S1)
	if title != "":
		col.add_child(UIKit.label(title, "", false))
	col.add_child(c)
	if note != "":
		var n := UIKit.label(note, UIKit.CAPTION)
		n.add_theme_constant_override("line_spacing", -2)
		col.add_child(n)
	UIKit.spacer(col, UIKit.S2)
	return col


## A caption line inside a group (a status, a note), with room above and below.
static func note_row(g: VBoxContainer, text: String, id := "") -> Label:
	var n := UIKit.label(text, UIKit.CAPTION)
	if id != "":
		n.name = id
	n.add_theme_constant_override("line_spacing", -2)
	g.add_child(n)
	return n


# ---------------------------------------------------------------- title parts


## Four equal quick-action tiles (each opens a screen): a raised secondary face with a bronze icon
## over its label. `items` are [id, icon, label, on_press]. Returns the HBox.
static func quick_tiles(box: Container, items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "QuickTiles"
	row.add_theme_constant_override("separation", UIKit.S2)
	box.add_child(row)
	for it in items:
		var b := Button.new()
		b.name = it[0]
		b.theme_type_variation = UIKit.COMPACT
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.custom_minimum_size = Vector2(UIKit.TOUCH, 126)
		b.tooltip_text = it[2]
		var cb: Callable = it[3]
		b.pressed.connect(func() -> void:
			Sound.ui("tap")
			cb.call())
		UIKit.juice(b)
		row.add_child(b)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 6
		col.offset_right = -6
		col.offset_bottom = -WoodcutTheme.LIP * WoodcutTheme.PX
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", UIKit.S1)
		b.add_child(col)
		var ic := TextureRect.new()
		ic.texture = KitIcons.get_icon(it[1], 4)
		ic.modulate = WoodcutTheme.C_BRONZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(0, 54)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ic)
		var l := UIKit.label(it[2], "", false, HORIZONTAL_ALIGNMENT_CENTER)
		l.name = "Label"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", Palette.text_font("Bold"))
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", WoodcutTheme.C_TEXT)
		UIKit.fit_label(l, 24)
		col.add_child(l)
	return row


## A footer's raised icon secondary (UIKit.footer_actions sizes it to 96 px): one of KitIcons'
## glyphs (play, help, ...) or a WoodcutTheme icon, named so tests and hands can find it.
static func icon_action(id: String, icon_name: String, on_press: Callable, tooltip := "") -> Button:
	var b := UIKit.icon_button("dot", on_press, tooltip, "")
	b.name = id
	b.icon = KitIcons.get_icon(icon_name)
	return b


## An instruction on a setup screen (calibration, the delay tests, the lessons): clean sans in the
## secondary text colour, centred; the serif gold lead is kept for one-line titles.
static func instruction(text: String) -> Label:
	var l := UIKit.label(text, "", true, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	l.add_theme_constant_override("line_spacing", -2)
	return l


## "remix open" -> "Remix open" (first letter only; .capitalize() would title-case every word).
static func sentence_case(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


## The primary button with a second line (the stop it plays) in smaller, paler type under its words.
static func hero_button(text: String, sub: String, on_press: Callable) -> Button:
	var b := UIKit.button("", on_press, UIKit.PRIMARY)
	b.custom_minimum_size.y = 132 if sub != "" else UIKit.PRIMARY_H
	b.tooltip_text = text
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_bottom = -WoodcutTheme.LIP * WoodcutTheme.PX
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", -4)
	b.add_child(col)
	var t := UIKit.label(text, "", false, HORIZONTAL_ALIGNMENT_CENTER)
	t.name = "Text"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_override("font", Palette.text_font("ExtraBold"))
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", WoodcutTheme.C_TEXT)
	t.add_theme_color_override("font_shadow_color", Color(WoodcutTheme.C_RED_LIP, 0.9))
	t.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(t)
	if sub != "":
		var s := UIKit.label(sub, "", false, HORIZONTAL_ALIGNMENT_CENTER)
		s.name = "Sub"
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_theme_font_override("font", Palette.text_font("Bold"))
		s.add_theme_font_size_override("font_size", 28)
		s.add_theme_color_override("font_color", Color("#ffd9c4"))
		UIKit.fit_label(s, 24)
		col.add_child(s)
	return b


# ---------------------------------------------------------------- sheets, locks, pictures


## The opaque raised sheet (bronze rim, carved lip) of the kit's dialogs.
static func sheet_style() -> PxStyle:
	var sb := PxStyle.make(WoodcutTheme.C_SURFACE, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_L, Vector4(30, 30, 30, 30))
	sb.highlight = WoodcutTheme.C_STROKE_HI
	sb.lip = WoodcutTheme.LIP
	sb.lip_color = WoodcutTheme.C_INK
	return sb


## A sheet in the thumb zone over a dark veil: returns the sheet's VBox. It rises in once (no work
## after that), straight in with reduced motion.
static func bottom_sheet(host: Control, veil_alpha := 0.78) -> VBoxContainer:
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(WoodcutTheme.C_INK, veil_alpha)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(veil)
	var safe := UIKit.safe_margins(host)
	var m := MarginContainer.new()
	m.name = "Sheet"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(UIKit.GUTTER * 0.5 + safe.x))
	m.add_theme_constant_override("margin_right", int(UIKit.GUTTER * 0.5 + safe.z))
	m.add_theme_constant_override("margin_bottom", int(UIKit.S5 + safe.w))
	m.add_theme_constant_override("margin_top", int(UIKit.S6 + safe.y))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(m)
	var cw := CenterWidth.new()
	cw.max_width = UIKit.COLUMN_MAX
	cw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(cw)
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.alignment = BoxContainer.ALIGNMENT_END
	cw.add_child(holder)
	var p := PanelContainer.new()
	p.name = "Panel"
	p.add_theme_stylebox_override("panel", sheet_style())
	holder.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.S3)
	p.add_child(box)
	# It sits over the stomp pads: for ARM_DELAY a shield takes every press, so a thumb still
	# drumming when the sheet appears cannot pick an action by accident.
	var shield := Control.new()
	shield.name = "Shield"
	shield.set_anchors_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(shield)
	host.get_tree().create_timer(ARM_DELAY, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(shield):
			shield.queue_free())
	if not UIKit.reduced_motion():
		p.modulate.a = 0.0
		veil.modulate.a = 0.0
		var tw := p.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(veil, "modulate:a", 1.0, 0.18)
		tw.tween_property(p, "modulate:a", 1.0, 0.18)
		tw.tween_method(func(y: float) -> void: p.position.y = roundf(y / 3.0) * 3.0 + holder.size.y - p.size.y, 48.0, 0.0, 0.24)
	return box


## A lock icon and what opens the thing (a remix, a stop), in caption type. Returns the HBox.
static func lock_line(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "LockLine"
	row.add_theme_constant_override("separation", UIKit.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = KitIcons.get_icon("lock")
	ic.modulate = WoodcutTheme.C_TEXT_2
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(36, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := UIKit.label(text, UIKit.CAPTION)
	l.name = "Text"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


## A card (BoardPanel look, or the bronze-rimmed one when `lit`) whose top is `pic`, flush with the
## card's edges and cut to its rounded corners; returns the VBox under the picture for the text.
## The picture expands to the height the text leaves.
static func picture_card(pic: Control, lit := false) -> Array:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Color(WoodcutTheme.C_SURFACE, 0.96)
	var sb := PxStyle.make(fill, WoodcutTheme.C_BRONZE if lit else WoodcutTheme.C_STROKE, WoodcutTheme.R_M, Vector4(3, 3, 3, 3))
	sb.highlight = Color(WoodcutTheme.C_RAISED_HI, 0.9)
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var holder := Control.new()
	holder.name = "PictureHolder"
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = 240
	v.add_child(holder)
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	if pic is StopPicture:
		fill_stop_picture(pic, holder, maxi((pic as StopPicture).px, 1))
	var mask := CornerMask.new()
	mask.color = fill.blend(Color(WoodcutTheme.C_INK, 0.0))
	mask.rim = WoodcutTheme.C_BRONZE if lit else WoodcutTheme.C_STROKE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(mask)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 21)
	v.add_child(m)
	var text := VBoxContainer.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", UIKit.S1)
	m.add_child(text)
	return [p, text]


## A story stop's picture filling `holder` edge to edge: the stop's world as a band about `focus`,
## at the art scale (3 on the base screen) or the next whole scale up when the holder is taller or
## wider than the world, so there is never a letterbox.
static func fill_stop_picture(pic: StopPicture, holder: Control, base_px: int) -> void:
	pic.view = "band"
	pic.px = base_px
	var refit := func() -> void:
		var ws := StopBackdrops.world_size()
		var k := maxi(base_px, maxi(ceili(holder.size.y / ws.y), ceili(holder.size.x / ws.x)))
		if pic.px != k:
			pic.px = k
	holder.resized.connect(refit)


## Paints a picture's top corners round (the card's radius, in the card's colour) and a one-art-px
## line under it, so a picture sits flush in a rounded card.
class CornerMask:
	extends Control
	var color := WoodcutTheme.C_SURFACE
	var rim := WoodcutTheme.C_STROKE
	var radius := WoodcutTheme.R_M - 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var px := 3.0
		var prof := PxStyle.corner(radius)
		for i in prof.size():
			var w := float(prof[i]) * px
			draw_rect(Rect2(0, i * px, w, px), color)
			draw_rect(Rect2(size.x - w, i * px, w, px), color)
		draw_rect(Rect2(0, size.y - px, size.x, px), rim)
