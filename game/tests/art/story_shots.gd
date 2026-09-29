extends SceneTree
## Renders the story art on its own, for judging it at size (not a test):
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/story_shots.gd -- <out dir> [what ...]
## what: pictures (every StopPicture card at 3x), scenes (ProcessionScene at every stop, a few sizes),
## bands (the story map strips). Default: all.

var out := "user://story_shots"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var what: Array = a.slice(1) if a.size() > 1 else ["pictures", "scenes", "bands"]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	if "pictures" in what:
		for n in range(1, 8):
			var p := StopPicture.new()
			p.stop = n
			p.size = Vector2(StopCells.CARD) * 3.0
			await _shot(p, Vector2i(StopCells.CARD) * 3, "picture_%d" % n, 1.3)
	if "scenes" in what:
		for n in range(1, 8):
			for sz in [Vector2i(656, 280), Vector2i(720, 480)]:
				var s := ProcessionScene.new()
				s.size = Vector2(sz)
				s.auto_bpm = 76.0
				s.set_stop(n)
				s.set_unison(4)
				await _shot(s, sz, "scene_%d_%dx%d" % [n, sz.x, sz.y], 1.7)
	if "bands" in what:
		for n in range(1, 8):
			var p := StopPicture.new()
			p.stop = n
			p.view = "band"
			p.size = Vector2(620, 150)
			await _shot(p, Vector2i(620, 150), "band_%d" % n, 0.6)
	quit()


func _shot(node: Control, sz: Vector2i, name: String, wait: float) -> void:
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.add_child(node)
	get_root().add_child(vp)
	var t_end := Time.get_ticks_msec() + int(wait * 1000.0)
	while Time.get_ticks_msec() < t_end:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	vp.queue_free()
	await process_frame
