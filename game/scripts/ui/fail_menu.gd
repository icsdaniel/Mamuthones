class_name FailMenu
extends Control
## Over the play screen when health runs out: "The fire goes out" on the kit's board, over the dimmed
## road, with Restart (the same song from the start, with the count-in) and Quit.

signal chosen(what: String)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# the same board as the pause menu, so the two read as one family
	var panel := PanelContainer.new()
	panel.theme_type_variation = UIKit.BOARD
	panel.custom_minimum_size.x = 540
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := UIKit.label(tr("fail_title"), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.add_theme_color_override("font_color", Palette.EMBER_HOT)
	title.add_theme_color_override("font_shadow_color", Palette.RED_DEEP)
	box.add_child(title)
	var sub := UIKit.label(tr("fail_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.name = "Hint"
	box.add_child(sub)
	box.add_child(HSeparator.new())
	# the board fades up a moment after the fire dies
	if not UIKit.reduced_motion():
		panel.modulate.a = 0.0
		var tw := panel.create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(panel, "modulate:a", 1.0, 0.35)
	for item in [["restart", "pause_restart", UIKit.PRIMARY], ["quit", "pause_quit", UIKit.QUIET]]:
		var b := UIKit.button(tr(item[1]), func() -> void: chosen.emit(item[0]), item[2])
		b.name = str(item[0]).capitalize()
		box.add_child(b)
