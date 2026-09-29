extends SceneTree
## Renders the story art on its own, for judging it at size (not a test):
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/story_shots.gd -- <out dir> [what ...]
## what: pictures (every StopPicture card at 3x), scenes (ProcessionScene at every stop, a few sizes),
## bands (the story map strips), looks (the workshop portrait in a few looks). Default: all but looks.

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
	if "looks" in what:
		var looks := [["black", "natural", "light"], ["black", "natural", "village"], ["black", "dark", "full"], ["dark_brown", "dark", "village"]]
		for l in looks:
			var p := MamuthonePortrait.new()
			p.size = Vector2(640, 366)
			var m := MaskSpec.default()
			m.nose = "broad"
			m.mouth = "grimace"
			p.set_look(m, l[0], l[1], l[2])
			await _shot(p, Vector2i(640, 366), "look_%s_%s_%s" % l, 0.4)
	if "lessons" in what:
		for topic in ["steps", "bells", "swipes", "stomps"]:
			for t in [1.3, 1.45, 1.62]:
				var lp := LessonPicture.new()
				lp.topic = topic
				lp.size = Vector2(640, 380)
				lp.set("_t", t)
				lp.set_process(false)
				await _shot(lp, Vector2i(640, 380), "lesson_%s_%d" % [topic, int(t * 100)], 0.1)
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
