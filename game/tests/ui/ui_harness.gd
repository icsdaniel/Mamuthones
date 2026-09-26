class_name UIHarness
extends RefCounted
## Shared setup for the UI tests: a throwaway profile, an App inside a SubViewport of a given phone
## size (copying the project's canvas_items/expand stretch), and walkers over the built controls.

const PROFILE := "user://test_ui_profile.cfg"
const BASE := Vector2(720, 1440)
const SIZES: Array[Vector2i] = [Vector2i(720, 1440), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1536, 2048)]


## A fresh profile. `first_run_done` sets every first-launch flag.
static func fresh_profile(first_run_done := true) -> void:
	for suffix in ["", ".tmp", ".bak.cfg", ".corrupt.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE.replace(".cfg", ".bak.cfg")))
	Profile.load_profile(PROFILE)
	Profile.reset()
	if first_run_done:
		for f in Profile.FLAGS:
			Profile.set_flag(f, true)
	Profile.set_setting("language", "en")


static func restore_profile() -> void:
	Profile.load_profile()


static func make_app(tree: SceneTree, screen := "", args := {}, size := Vector2i(720, 1440)) -> App:
	var vp := SubViewport.new()
	vp.size = size
	var scale := minf(size.x / BASE.x, size.y / BASE.y)
	vp.size_2d_override = Vector2i(roundi(size.x / scale), roundi(size.y / scale))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	var app: App = load("res://scenes/main.tscn").instantiate()
	app.start_screen = screen
	app.start_args = args
	vp.add_child(app)
	return app


static func free_app(app: App) -> void:
	if app != null and is_instance_valid(app):
		var vp := app.get_parent()
		vp.queue_free()


## Waits for screen transitions (about 0.2 s) to finish.
static func settle(tree: SceneTree) -> void:
	await tree.create_timer(0.3).timeout
	await tree.process_frame


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## Every visible Control under `node`.
static func visible_controls(node: Node, out: Array[Control] = []) -> Array[Control]:
	for c in node.get_children():
		if c is CanvasItem and not (c as CanvasItem).visible:
			continue
		if c is Control:
			out.append(c)
		visible_controls(c, out)
	return out


static func find_button(node: Node, name: String) -> Button:
	return node.find_child(name, true, false) as Button


## Presses a button the way a tap would (emits pressed).
static func press(node: Node, name: String) -> bool:
	var b := find_button(node, name)
	if b == null or b.disabled or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


## Plays the current play screen to its end on a manual clock, `step` song seconds per frame.
static func run_play(tree: SceneTree, play: Node, step := 0.05, limit := 400.0) -> void:
	var c: Conductor = play.get("conductor")
	if c == null:
		return
	c.use_manual_clock(true)
	var elapsed := 0.0
	while is_instance_valid(play) and not bool(play.get("done")) and elapsed < limit:
		c.advance(step)
		elapsed += step
		await tree.process_frame
