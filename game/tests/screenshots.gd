extends SceneTree
## Saves a screenshot of every screen, for reviewing the UI without a phone.
##   godot --path game --rendering-driver opengl3 -s res://tests/screenshots.gd -- <output dir>

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for screen in ["title", "calibrate", "songs"]:
		main.call("show_" + screen)
		await _shoot(out, screen)
	main.call("start_song", Chart.load_songs()[1], true)
	await process_frame
	var view: PlayView = main.find_child("PlayView", true, false)
	view._music.stop()
	view.set_process(false)
	for at in [3.0, 6.2, 14.5]:
		while view.song_time() < at:
			view._process(1.0 / 60.0)
		await _shoot(out, "play_%s" % at)
	while main.last_session == null:
		view._process(1.0 / 60.0)
	await _shoot(out, "results")
	quit()


func _shoot(out: String, name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
