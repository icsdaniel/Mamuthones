class_name App
extends Control
## Root of the game (scenes/main.tscn). Applies the woodcut theme, loads the strings, and keeps a stack
## of screens: open() pushes, back() pops, replace() swaps the top, reset() clears to one screen.
## Screens are named so tests, screenshots and the recorder can open any of them directly.

signal screen_changed(screen: Screen)

const SCREENS := {
	"language": "res://scripts/ui/screens/language_screen.gd",
	"headphones": "res://scripts/ui/screens/headphones_screen.gd",
	"calibration": "res://scripts/ui/screens/calibration_screen.gd",
	"latency": "res://scripts/ui/screens/latency_screen.gd",
	"title": "res://scripts/ui/screens/title_screen.gd",
	"story": "res://scripts/ui/screens/story_screen.gd",
	"stop_card": "res://scripts/ui/screens/stop_card_screen.gd",
	"free_play": "res://scripts/ui/screens/free_play_screen.gd",
	"piazza": "res://scripts/ui/screens/piazza_screen.gd",
	"piazza_ranking": "res://scripts/ui/screens/piazza_ranking_screen.gd",
	"daily": "res://scripts/ui/screens/daily_screen.gd",
	"settings": "res://scripts/ui/screens/settings_screen.gd",
	"credits": "res://scripts/ui/screens/credits_screen.gd",
	"workshop": "res://scripts/ui/screens/workshop_screen.gd",
	"play": "res://scripts/ui/screens/play_screen.gd",
	"tutorial": "res://scripts/ui/screens/tutorial_screen.gd",
	"results": "res://scripts/ui/screens/results_screen.gd",
	"boards": "res://scripts/ui/screens/boards_screen.gd",
}

## Set before adding to the tree to skip the first screen (tests, screenshots, recorder).
var start_screen := ""
var start_args: Dictionary = {}

var stack: Array[Screen] = []
var _layer: Control
var _overlay: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.apply_root(self)
	_layer = Control.new()
	_layer.name = "Screens"
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	get_tree().root.set_meta("app", self)
	get_tree().set_auto_accept_quit(true)
	get_tree().set_quit_on_go_back(false)
	if start_screen != "":
		open(start_screen, start_args)
	else:
		open(UIKit.first_screen())


func current() -> Screen:
	return stack.back() if not stack.is_empty() else null


## Push a screen by name.
func open(name: String, args: Dictionary = {}) -> Screen:
	var screen := _make(name, args)
	var prev := current()
	stack.append(screen)
	_layer.add_child(screen)
	screen.build()
	if prev != null:
		prev.hide()
	_enter(screen, 1.0)
	screen_changed.emit(screen)
	return screen


## Swap the top screen for another (play -> results, first-run steps).
func replace(name: String, args: Dictionary = {}) -> Screen:
	var old: Screen = stack.pop_back() if not stack.is_empty() else null
	if old != null:
		old.queue_free()
	var screen := _make(name, args)
	stack.append(screen)
	_layer.add_child(screen)
	screen.build()
	_enter(screen, 1.0)
	screen_changed.emit(screen)
	return screen


## Clear the stack and open one screen (title after first run, quit from play).
func reset(name: String, args: Dictionary = {}) -> Screen:
	for s in stack:
		s.queue_free()
	stack.clear()
	return open(name, args)


## Pop the top screen. On the last screen, the title, back leaves the app on Android.
func back() -> void:
	if stack.size() <= 1:
		if current() != null and current().screen_name() != "title_screen":
			reset("title")
		return
	var top: Screen = stack.pop_back()
	top.queue_free()
	var prev := current()
	prev.show()
	prev.on_resume()
	_enter(prev, -1.0)
	Sound.ui("back")
	screen_changed.emit(prev)


## Rebuild every screen in the stack (after a language change).
func rebuild_all() -> void:
	for s in stack:
		for c in s.get_children():
			s.remove_child(c)
			c.queue_free()
		s.build()


func overlay() -> Control:
	return _overlay


func _make(name: String, args: Dictionary) -> Screen:
	assert(SCREENS.has(name), "unknown screen " + name)
	var script: GDScript = load(SCREENS[name])
	var screen: Screen = script.new()
	screen.name = name.to_pascal_case()
	screen.app = self
	screen.args = args
	return screen


## Short slide and fade in; skipped with reduced motion.
func _enter(screen: Screen, direction: float) -> void:
	if UIKit.reduced_motion():
		screen.modulate.a = 1.0
		screen.position.x = 0.0
		return
	screen.modulate.a = 0.0
	screen.position.x = 36.0 * direction
	var tw := screen.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(screen, "modulate:a", 1.0, 0.18)
	tw.tween_property(screen, "position:x", 0.0, 0.22)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and current() != null:
		current().on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current() != null:
		get_viewport().set_input_as_handled()
		current().on_back()
