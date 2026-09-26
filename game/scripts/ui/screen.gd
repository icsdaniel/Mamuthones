class_name Screen
extends Control
## Base for every screen. The App creates a screen, sets `app` and `args`, adds it to the tree and
## calls build(). Screens build their own children in code, in tr() keys, and are thrown away when
## left, so every screen always shows the current profile and language.

var app: App
var args: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Override: create the children.
func build() -> void:
	pass


## Override: called by the App when the screen becomes the top of the stack again.
func on_resume() -> void:
	pass


## Override: Android back button, Esc, and the header's back button. Default: go back one screen.
func on_back() -> void:
	app.back()


## A short name for tests and screenshots.
func screen_name() -> String:
	return (get_script() as Script).resource_path.get_file().get_basename()
