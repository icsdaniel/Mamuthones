extends SceneTree
## Renders the play screen's side rows at several points of one beat, side by side, to check that the
## heavy jump lands on the beat:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/beat_frames.gd -- out.png

const PHASES := [0.0, 0.06, 0.16, 0.36, 0.44, 0.54, 0.7, 0.84, 0.96]


func _init() -> void:
	var out := "user://beat_frames.png"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	await process_frame
	var w := 400
	var h := 760
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = PixelPalette.NIGHT[1]
	bg.size = Vector2(w, h)
	vp.add_child(bg)
	var lanes := Control.new()
	lanes.position = Vector2(130, 0)
	lanes.size = Vector2(140, h)
	vp.add_child(lanes)
	var rows := SideRows.new()
	rows.size = Vector2(w, h)
	rows.lanes = lanes
	rows.set_unison(4)
	vp.add_child(rows)
	var cw := 140     # the left file only
	var sheet := Image.create(cw * PHASES.size(), h, false, Image.FORMAT_RGBA8)
	for i in PHASES.size():
		rows.beat = 8.0 + PHASES[i]
		rows.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, cw, h), Vector2i(i * cw, 0))
	sheet.save_png(out)
	print("wrote ", out)
	quit()
