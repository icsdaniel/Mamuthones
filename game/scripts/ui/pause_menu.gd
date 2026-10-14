class_name PauseMenu
extends Control
## The pause menu over the play screen, as a sheet rising in the thumb zone (MenuKit.bottom_sheet):
## "Paused" and the count-in note, Resume (the primary, with a count-in), then Restart and Quit side
## by side. Built once when shown; nothing runs per frame (the song is stopped under it).

signal chosen(what: String)


func _init() -> void:
	# Anchored before it enters the tree, so it fills the play screen.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var box := MenuKit.bottom_sheet(self, 0.72)
	var title := UIKit.label(tr("pause_title"), UIKit.TITLE, false, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "Title"
	box.add_child(title)
	var hint := UIKit.label(tr("pause_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	hint.name = "Hint"
	box.add_child(hint)
	UIKit.spacer(box, UIKit.S1)
	var resume := UIKit.button(tr("pause_resume"), func() -> void: chosen.emit("resume"), UIKit.PRIMARY)
	resume.name = "Resume"
	box.add_child(resume)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S2)
	box.add_child(row)
	for item in [["restart", "pause_restart"], ["quit", "pause_quit"]]:
		var b := UIKit.button(tr(item[1]), func() -> void: chosen.emit(item[0]))
		b.name = str(item[0]).capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
