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
	var restart := MenuKit.icon_action("Restart", "replay", func() -> void: chosen.emit("restart"), tr("pause_restart"))
	UIKit.footer_actions(box, resume, restart)
	var quit := UIKit.button(tr("pause_quit"), func() -> void: chosen.emit("quit"), UIKit.QUIET)
	quit.name = "Quit"
	box.add_child(quit)
