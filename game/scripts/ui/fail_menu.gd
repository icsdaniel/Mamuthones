class_name FailMenu
extends Control
## Over the play screen when health runs out: "The fire goes out" on the same thumb-zone sheet as
## the pause menu (MenuKit.bottom_sheet), over the dimmed road, with Restart (the primary: the same
## song from the start, with the count-in) and Quit beside it. Built once; nothing runs per frame.

signal chosen(what: String)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var box := MenuKit.bottom_sheet(self, 0.8)
	var title := UIKit.label(tr("fail_title"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	title.add_theme_color_override("font_color", WoodcutTheme.C_EMBER_HOT)
	title.add_theme_color_override("font_shadow_color", WoodcutTheme.C_RED_LO)
	box.add_child(title)
	var sub := UIKit.label(tr("fail_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.name = "Hint"
	box.add_child(sub)
	UIKit.spacer(box, UIKit.S1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S2)
	box.add_child(row)
	var quit := UIKit.button(tr("pause_quit"), func() -> void: chosen.emit("quit"))
	quit.name = "Quit"
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.size_flags_stretch_ratio = 0.7
	quit.custom_minimum_size.y = UIKit.PRIMARY_H
	row.add_child(quit)
	var restart := UIKit.button(tr("pause_restart"), func() -> void: chosen.emit("restart"), UIKit.PRIMARY)
	restart.name = "Restart"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(restart)
