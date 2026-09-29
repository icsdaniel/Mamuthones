extends SceneTree
## Renders the pixel-art play pieces and the title scene to PNGs, for looking at them outside a song:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/px_sheet.gd -- <out dir> \
##       [title] [title_frames] [field] [scene_h=780] [size=720x1440]
##   title         the TitleScene alone, scene_h tall at the top of a size screen (title.png)
##   title_frames  eight frames across two beats of the title (title_f0.png …), to judge the motion
##   field         FireSkin's notes at their sizes, the stomp note and its hits (full and one-thumb) at
##                 several moments, the bursts and the buttons (field_sheet.png)

var out_dir := "user://px_sheet"
var scene_h := 780.0
var size := Vector2i(720, 1440)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var what: Array[String] = []
	if a.size() > 0:
		out_dir = a[0]
	for i in range(1, a.size()):
		if a[i].begins_with("scene_h="):
			scene_h = float(a[i].substr(8))
		elif a[i].begins_with("size="):
			var t := a[i].substr(5)
			size = Vector2i(int(t.get_slice("x", 0)), int(t.get_slice("x", 1)))
		else:
			what.append(a[i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	if what.is_empty() or "title" in what:
		await _title(false)
	if "title_frames" in what:
		await _title(true)
	if what.is_empty() or "field" in what:
		await _field()
	quit()


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	var scale := minf(size.x / 720.0, size.y / 1440.0)
	vp.size_2d_override = Vector2i(roundi(size.x / scale), roundi(size.y / scale))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = PixelPalette.K[0]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	return vp


func _title(frames: bool) -> void:
	var vp := _viewport()
	var sc := TitleScene.new()
	sc.name = "Scene"
	sc.position = Vector2.ZERO
	sc.size = Vector2(vp.size_2d_override.x, scene_h)
	vp.add_child(sc)
	sc.set_look("dark_brown")
	if not frames:
		# a moment just after a landing, the fire leaping
		await _run_until(sc, 4.06)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join("title.png"))
	else:
		for i in 8:
			await _run_until(sc, 4.0 + float(i) * 0.25 - 0.001 + 0.0005)
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(out_dir.path_join("title_f%d.png" % i))
	vp.queue_free()


## Runs the title's clock to beat b (frames advance it by their real delta; this sets it outright).
func _run_until(sc: TitleScene, b: float) -> void:
	for i in 3:
		await process_frame
	sc.set("_t", b * 60.0 / sc.bpm)
	await process_frame
	await process_frame


func _field() -> void:
	var vp := _viewport()
	var c := _Sheet.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(c)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir.path_join("field_sheet.png"))
	vp.queue_free()


class _Sheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), PixelPalette.SETT[1])
		var y := 40.0
		# notes far to near
		var x := 30.0
		for sc in [0.42, 0.6, 0.8, 1.0]:
			FireSkin.draw_gem(self, Vector2(x + 40.0, y), sc)
			FireSkin.draw_gem(self, Vector2(x + 40.0, y + 70.0), sc, true)
			FireSkin.draw_heal_gem(self, Vector2(x + 40.0, y + 140.0), sc)
			FireSkin.draw_hold_ring(self, Vector2(x + 40.0, y + 210.0), sc)
			x += 170.0
		# the stomp note at its sizes
		y = 330.0
		x = 20.0
		for sc in [0.42, 0.6, 0.8, 1.0]:
			FireSkin.draw_stomp_note(self, Vector2(x + 60.0, y), sc)
			x += 170.0
		# stomp hits: full (top row) and one thumb (bottom row) at several moments
		y = 520.0
		x = 90.0
		for t in [0.03, 0.12, 0.3, 0.55]:
			FireSkin.draw_stomp_hit(self, Vector2(x, y), 0.9, t, true)
			FireSkin.draw_stomp_hit(self, Vector2(x, y + 190.0), 0.9, t * 0.6, false)
			x += 180.0
		# bursts
		y = 900.0
		x = 90.0
		for q in ["perfect", "good", "late", "miss"]:
			FireSkin.draw_burst(self, Vector2(x, y), q, 0.1, 1.0)
			x += 180.0
		# the hit line, a bell bar and the buttons
		FireSkin.draw_hit_line(self, 0.0, size.x, 1020.0, [120.0, 360.0, 600.0], 79.2, [0.0, 1.0, 0.0], 0.0, [false, false, true])
		FireSkin.draw_bar(self, 30.0, size.x - 30.0, 1110.0, 0.9, false)
		FireSkin.draw_badge(self, Vector2(size.x * 0.5, 1110.0), 0.9)
		var states := ["idle", "pressed", "hit"]
		for i in 3:
			FireSkin.draw_button(self, Rect2(12.0 + 240.0 * i, 1200.0, 216.0, 174.0), i, states[i])
