extends SceneTree
## Clicks the play screen's pause button through real input events, to check that taps reach the
## HUD inside the pixel look's picture: godot --path game -s res://tests/pause_click.gd -- [style]

var profile: Node


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	profile = root.get_node("/root/Profile")
	profile.load_profile("user://click_profile.cfg")
	profile.reset()
	for f in profile.FLAGS:
		profile.set_flag(f, true)
	profile.set_setting("art_style", a[0] if a.size() > 0 else "pixel")
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.set("start_screen", "play")
	app.set("start_args", {"song_id": "fires", "difficulty": "easy", "bell_set": "light"})
	root.add_child(app)
	for i in 90:
		await process_frame
	var play: Node = app.call("current")
	var btn: Control = play.find_child("Pause", true, false)
	var at := root.get_final_transform() * btn.get_global_rect().get_center()
	print("pause button at ", at, " paused before: ", play.get("paused"), " buttons ", play.get("router").get("buttons_rect"))
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)
		await process_frame
	for i in 10:
		await process_frame
	print("PAUSED_AFTER_CLICK=", play.get("paused"), " menu=", play.find_child("PauseMenu", true, false) != null)
	profile.load_profile()
	quit()
