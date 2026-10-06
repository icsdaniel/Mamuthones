class_name PauseMenu
extends Control
## The pause menu over the play screen: resume (with a count-in), restart, quit.

signal chosen(what: String)


func _init() -> void:
	# Anchored before it enters the tree, so it fills the play screen.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = UIKit.BOARD
	panel.custom_minimum_size.x = 520
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(UIKit.label(tr("pause_title"), UIKit.HEADER, false, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(HSeparator.new())
	for item in [["resume", "pause_resume", UIKit.PRIMARY], ["restart", "pause_restart", ""], ["quit", "pause_quit", UIKit.QUIET]]:
		var b := UIKit.button(tr(item[1]), func() -> void: chosen.emit(item[0]), item[2])
		b.name = str(item[0]).capitalize()
		box.add_child(b)
	box.add_child(UIKit.label(tr("pause_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER))
