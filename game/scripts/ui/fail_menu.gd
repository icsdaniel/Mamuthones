class_name FailMenu
extends Control
## Over the play screen when health runs out: "The fire goes out" in the carved serif, over the dimmed
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
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := UIKit.label(tr("fail_title"), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	FireSkin.carve_label(title, 60, Color.WHITE, Color(1.0, 0.7, 0.3, 0.6), 10, 0.3)
	var grad := FireSkin.text_gradient(Color("#fff4dc"), Color("#f0c878"), Color("#c8501e"))
	title.material = grad
	title.resized.connect(func() -> void: grad.set_shader_parameter("height", maxf(title.size.y, 1.0)))
	box.add_child(title)
	var sub := UIKit.label(tr("fail_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.name = "Hint"
	FireSkin.carve_label(sub, 26, Color("#d9a24a"), Color(0, 0, 0, 0), 6)
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 12
	box.add_child(gap)
	for item in [["restart", "pause_restart", UIKit.PRIMARY], ["quit", "pause_quit", UIKit.QUIET]]:
		var b := UIKit.button(tr(item[1]), func() -> void: chosen.emit(item[0]), item[2])
		b.name = str(item[0]).capitalize()
		box.add_child(b)
