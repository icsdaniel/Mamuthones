extends SceneTree
## Renders every art piece to PNGs for looking at (needs a real renderer):
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 720x1440 \
##       -s res://tests/art/gallery.gd -- /tmp/art-gallery [piece ...]
## Pieces: theme, masks, figures, stops, procession, lanes, logo, timing (default: all).
## lanes also writes the greyscale and small-size sheets; logo also writes the 64 and 128 px icons;
## timing writes play_mock.png (scene and lanes together) and appends to timing.txt.

var out_dir := "/tmp/art-gallery"
var only: Array[String] = []


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for i in range(1, args.size()):
		only.append(args[i])
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	if _want("theme"):
		await _theme_sheet()
	if _want("masks"):
		await _masks()
	if _want("figures"):
		await _figures()
	if _want("stops"):
		await _stops()
	if _want("procession"):
		await _procession()
	if _want("lanes"):
		await _lanes()
	if _want("logo"):
		await _logo()
	if _want("timing"):
		await _timing(true, true)
		await _timing(true, true)
		await _timing(true, false)
		await _timing(false, true)
		await _timing(false, false)
	quit()


func _want(piece: String) -> bool:
	return only.is_empty() or piece in only


## Renders `node` in its own SubViewport of `size` and saves it.
func render(node: Node, size: Vector2i, file: String, frames := 3, transparent := false) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(node)
	get_root().add_child(vp)
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", out_dir.path_join(file))
	vp.queue_free()
	await process_frame
	return img


func _theme_sheet() -> void:
	var root := PanelContainer.new()
	root.theme = WoodcutTheme.build()
	root.size = Vector2(720, 1440)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var add := func(c: Control, variation := "") -> Control:
		if variation != "":
			c.theme_type_variation = variation
		box.add_child(c)
		return c
	var l := Label.new(); l.text = "Mamuthones"; add.call(l, "TitleLabel")
	l = Label.new(); l.text = "The Weight of Bells"; add.call(l, "HeaderLabel")
	l = Label.new(); l.text = "Stop 2 · Sant'Antonio's Fires"; add.call(l, "SubheaderLabel")
	l = Label.new(); l.text = "Body text at 28 px: tilt the phone sharply to ring the bells on your back."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add.call(l)
	l = Label.new(); l.text = "Caption at 26 px: best 412 300 · unison ×3"; add.call(l, "CaptionLabel")
	var b := Button.new(); b.text = "Free play"; add.call(b)
	b = Button.new(); b.text = "Play the procession"; add.call(b, "AccentButton")
	b = Button.new(); b.text = "Pressed"; b.toggle_mode = true; b.button_pressed = true; add.call(b)
	b = Button.new(); b.text = "Disabled"; b.disabled = true; add.call(b)
	b = Button.new(); b.text = "Credits"; add.call(b, "QuietButton")
	var s := HSlider.new(); s.value = 60; add.call(s)
	var cb := CheckButton.new(); cb.text = "Reduced motion"; cb.button_pressed = true; add.call(cb)
	cb = CheckButton.new(); cb.text = "Vibration"; add.call(cb)
	var ck := CheckBox.new(); ck.text = "Slam mode"; ck.button_pressed = true; add.call(ck)
	var p := ProgressBar.new(); p.value = 45; add.call(p)
	add.call(HSeparator.new())
	var ob := OptionButton.new(); ob.add_item("English"); ob.add_item("Italiano"); add.call(ob)
	var le := LineEdit.new(); le.placeholder_text = "Player name"; add.call(le)
	var card := PanelContainer.new(); card.theme_type_variation = "CardPanel"
	var cv := VBoxContainer.new(); card.add_child(cv)
	l = Label.new(); l.text = "The Workshop"; l.theme_type_variation = "PaperHeaderLabel"; cv.add_child(l)
	l = Label.new(); l.text = "Paper card text in ink, 28 px."; l.theme_type_variation = "PaperLabel"; cv.add_child(l)
	add.call(card)
	l = Label.new(); l.text = "Score 128 450"; add.call(l, "HudLabel")
	await render(root, Vector2i(720, 1440), "theme.png")


func _masks() -> void:
	var big := MaskView.new()
	big.size = Vector2(720, 900)
	big.show_halo = true
	big.spec = MaskSpec.default()
	var bg := ColorRect.new()
	bg.color = Palette.NIGHT
	bg.size = big.size
	bg.add_child(big)
	await render(bg, Vector2i(720, 900), "mask_default.png")
	# Every option of every part, on the default mask.
	var sheet := ColorRect.new()
	sheet.color = Palette.NIGHT
	var cell := Vector2(180, 236)
	sheet.size = Vector2(cell.x * 4, cell.y * MaskSpec.PARTS.size())
	for r in MaskSpec.PARTS.size():
		var part: String = MaskSpec.PARTS[r]
		var opts := MaskSpec.options(part)
		for c in opts.size():
			var m := MaskView.new()
			var spec := MaskSpec.default()
			spec[part] = opts[c]
			m.spec = spec
			m.position = Vector2(c * cell.x, r * cell.y)
			m.size = cell - Vector2(0, 46)
			sheet.add_child(m)
			var l := Label.new()
			l.text = "%s\n%s" % [part, opts[c]]
			l.add_theme_font_size_override("font_size", 16)
			l.add_theme_constant_override("line_spacing", -4)
			l.size = Vector2(cell.x - 16, 44)
			l.clip_text = true
			l.position = Vector2(c * cell.x + 8, r * cell.y + cell.y - 46)
			sheet.add_child(l)
	await render(sheet, Vector2i(sheet.size), "mask_options.png")
	# A few full carvings and the tiny size used in the procession.
	var combos := [MaskSpec.default(),
		{"brow": "furrowed", "eyes": "drooping", "nose": "long", "cheeks": "hollow", "mouth": "downturned", "finish": "smoked", "patina": "worn"},
		{"brow": "knotted", "eyes": "almond", "nose": "broad", "cheeks": "creased", "mouth": "grimace", "finish": "dark_walnut", "patina": "old"},
		{"brow": "lined", "eyes": "narrow", "nose": "aquiline", "cheeks": "high", "mouth": "open", "finish": "charred", "patina": "ancient"}]
	var row := ColorRect.new()
	row.color = Palette.NIGHT
	row.size = Vector2(720, 520)
	for i in combos.size():
		var m := MaskView.new()
		m.spec = combos[i]
		m.position = Vector2(i * 180, 0)
		m.size = Vector2(180, 300)
		row.add_child(m)
		for j in 3:
			var t := MaskView.new()
			t.spec = combos[i]
			var h: float = [24.0, 40.0, 64.0][j]
			t.size = Vector2(h, h * 1.25)
			t.position = Vector2(i * 180 + [10.0, 44.0, 94.0][j], 330 + (80 - h))
			row.add_child(t)
	await render(row, Vector2i(row.size), "mask_combos.png")


class _Sheet:
	extends Control
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _sheet(sz: Vector2, painter: Callable) -> Control:
	var c := _Sheet.new()
	c.size = sz
	c.painter = painter
	return c


func _figures() -> void:
	var paint := func(ci: CanvasItem) -> void:
		ci.draw_rect(Rect2(0, 0, 720, 1000), Palette.NIGHT)
		ci.draw_rect(Rect2(0, 500, 720, 500), Palette.BONE)
		WoodcutDraw.glow(ci, Vector2(200, 300), 300, Color(Palette.EMBER, 0.5))
		for row in 2:
			var y := 460.0 + row * 500.0
			var lit: Color = Palette.EMBER if row == 0 else Palette.BONE
			ci.draw_set_transform(Vector2(150, y))
			Figures.mamuthone(ci, 400, MaskSpec.default(), "black", "natural", lit, 1)
			ci.draw_set_transform(Vector2(360, y))
			Figures.issohadore_body(ci, 380, lit, 1)
			Figures.issohadore_head(ci, 380, 1)
			ci.draw_set_transform(Vector2(360 - 16 * 3.8, y - 76 * 3.8), -0.5)
			Figures.issohadore_arm(ci, 380)
			ci.draw_set_transform(Vector2(520, y))
			Figures.mamuthone(ci, 200, MaskSpec.default(), "dark_brown", "dark", lit, 1)
			ci.draw_set_transform(Vector2(640, y))
			Figures.mamuthone(ci, 110, MaskSpec.default(), "black", "natural", lit, 0)
			ci.draw_set_transform(Vector2(600, y - 250))
			Figures.ghost(ci, 150, Color(Palette.BONE, 0.5))
			for i in 4:
				ci.draw_set_transform(Vector2(470 + i * 60, y - 330))
				Figures.crowd_person(ci, 90, i, Palette.INK if row == 0 else Color("#3a332d"), Color(lit, 0.6), i)
		ci.draw_set_transform(Vector2.ZERO)
	await render(_sheet(Vector2(720, 1000), paint), Vector2i(720, 1000), "figures.png")


func _scene(stop: int, sz: Vector2) -> ProcessionScene:
	var p := ProcessionScene.new()
	p.size = sz
	p.set_stop(stop)
	p.set_look({"brow": "furrowed", "eyes": "drooping", "nose": "hooked", "cheeks": "hollow", "mouth": "downturned", "finish": "smoked", "patina": "worn"}, "black", "natural")
	return p


func _stops() -> void:
	for n in range(1, StopBackdrops.COUNT + 1):
		var p := _scene(n, Vector2(720, 480))
		p.set_unison(2)
		# No ghost here: these are the store-page views of each stop (the ghost is in procession_*).
		await render(p, Vector2i(720, 480), "stop_%d.png" % n, 20)


func _procession() -> void:
	# Jolt sequence at low and high unison, rope throw, a miss; and odd sizes.
	for u in [0, 5]:
		var p := _scene(2, Vector2(720, 480))
		p.set_unison(u)
		p.set_ghost_delta(-0.3)
		var vp := SubViewport.new()
		vp.size = Vector2i(720, 480)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.add_child(p)
		get_root().add_child(vp)
		for i in 10:
			await process_frame
		# Unison at a glance: ring the bells and catch the swing (ragged at 0, one shared swing at 5).
		p.jolt("bell")
		for i in 7:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join("procession_ring_u%d.png" % u))
		print("saved procession_ring_u%d.png" % u)
		for i in 30:
			await process_frame
		p.jolt("bell")
		p.throw_rope()
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join("procession_jolt_u%d.png" % u))
		print("saved procession_jolt_u%d.png" % u)
		for i in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir.path_join("procession_rope_u%d.png" % u))
		vp.queue_free()
	# A miss: your Mamuthone stumbles (caught mid-stumble).
	var pm := _scene(4, Vector2(720, 480))
	var vpm := SubViewport.new()
	vpm.size = Vector2i(720, 480)
	vpm.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpm.add_child(pm)
	get_root().add_child(vpm)
	for i in 10:
		await process_frame
	pm.jolt("miss")
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	vpm.get_texture().get_image().save_png(out_dir.path_join("procession_miss.png"))
	print("saved procession_miss.png")
	vpm.queue_free()
	await render(_scene(4, Vector2(720, 1440)), Vector2i(720, 1440), "procession_fullscreen.png", 10)
	await render(_scene(7, Vector2(1080, 1440)), Vector2i(1080, 1440), "procession_tablet.png", 10)
	await render(_scene(6, Vector2(720, 300)), Vector2i(720, 300), "procession_short.png", 10)


## The play field with every note kind, the buttons in each state and the hit bursts.
func _lanes_paint(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 720, 1440), Palette.NIGHT)
	var field := Rect2(0, 0, 720, 1140)
	LaneSkin.draw_lanes(ci, field, [0.0, 1.0, 0.0])
	var lanes := LaneSkin.lane_rects(field)
	var hy := LaneSkin.hit_line_y(field)
	LaneSkin.draw_hit_line(ci, field, 0.6)
	LaneSkin.draw_rest(ci, field, 40, 130)
	LaneSkin.draw_swipe(ci, field, 180, 1)
	LaneSkin.draw_bell(ci, field, 250, true)
	LaneSkin.draw_step(ci, lanes[0], 330)
	LaneSkin.draw_step(ci, lanes[2], 330, true)
	LaneSkin.draw_ring(ci, field, lanes[1], 420, false)
	LaneSkin.draw_hold(ci, lanes[0], 640, 480, false)
	LaneSkin.draw_hold(ci, lanes[2], hy, 560, true)
	LaneSkin.draw_swipe(ci, field, 720, -1)
	LaneSkin.draw_bell(ci, field, 800, false)
	LaneSkin.draw_step(ci, lanes[1], 880)
	LaneSkin.draw_hit_burst(ci, Vector2(lanes[0].get_center().x, hy), "perfect", 0.12)
	LaneSkin.draw_hit_burst(ci, Vector2(lanes[1].get_center().x, hy), "early", 0.1)
	LaneSkin.draw_hit_burst(ci, Vector2(lanes[2].get_center().x, hy - 120), "late", 0.1)
	LaneSkin.draw_hit_burst(ci, Vector2(lanes[1].get_center().x, 960), "good", 0.12)
	LaneSkin.draw_hit_burst(ci, Vector2(lanes[0].get_center().x, 960), "miss", 0.1)
	var states := ["idle", "cued", "pressed"]
	for i in 3:
		LaneSkin.draw_button(ci, Rect2(i * 240 + 8, 1150, 224, 130), i, states[i])
	var more := ["hit", "miss", "idle"]
	for i in 3:
		LaneSkin.draw_button(ci, Rect2(i * 240 + 8, 1295, 224, 130), i, more[i])


func _lanes() -> void:
	var img := await render(_sheet(Vector2(720, 1440), _lanes_paint), Vector2i(720, 1440), "lanes.png")
	var grey := img.duplicate()
	grey.convert(Image.FORMAT_L8)
	grey.save_png(out_dir.path_join("lanes_greyscale.png"))
	# Arm's length: the same field at a quarter size.
	var small := img.duplicate()
	small.resize(180, 360, Image.INTERPOLATE_BILINEAR)
	small.save_png(out_dir.path_join("lanes_small.png"))


func _logo() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BLACK
	bg.size = Vector2(720, 1000)
	var logo := Logo.new()
	logo.size = Vector2(720, 1000)
	logo.show_title = true
	bg.add_child(logo)
	await render(bg, Vector2i(720, 1000), "logo.png")
	for s in [64, 128]:
		var img := await render(_sheet(Vector2(s, s), func(ci): AppIcon.paint(ci, float(s))), Vector2i(s, s), "icon_%d.png" % s)
		img.resize(s * 4, s * 4, Image.INTERPOLATE_NEAREST)
		img.save_png(out_dir.path_join("icon_%d_x4.png" % s))


## Render cost of a play-screen mock (procession band + a busy note field + buttons) at 720x1440.
func _timing(with_scene: bool, with_field: bool) -> void:
	var root := Control.new()
	root.size = Vector2(720, 1440)
	var scene := ProcessionScene.new()
	scene.position = Vector2(0, 120)
	scene.size = Vector2(720, 460)
	scene.set_stop(2)
	scene.visible = with_scene
	root.add_child(scene)
	var field := _Sheet.new()
	field.visible = with_field
	field.position = Vector2(0, 580)
	field.size = Vector2(720, 860)
	var t := [0.0]
	field.painter = func(ci):
		var f := Rect2(0, 0, 720, 700)
		LaneSkin.draw_lanes(ci, f, [0.0, 1.0, 0.0])
		LaneSkin.draw_hit_line(ci, f, 0.5)
		var lanes := LaneSkin.lane_rects(f)
		for i in 16:
			var y := LaneSkin.note_y(f, fposmod(float(i) * 0.25 - t[0], 4.0) - 0.3, 180.0)
			match i % 6:
				0, 1, 2:
					LaneSkin.draw_step(ci, lanes[i % 3], y, i % 4 == 3)
				3:
					LaneSkin.draw_bell(ci, f, y, i % 2 == 0)
				4:
					LaneSkin.draw_hold(ci, lanes[1], y, y - 120.0)
				_:
					LaneSkin.draw_swipe(ci, f, y, 1)
		for i in 3:
			LaneSkin.draw_button(ci, Rect2(i * 240 + 8, 710, 224, 140), i, "idle" if i != 1 else "pressed")
		LaneSkin.draw_hit_burst(ci, Vector2(360, LaneSkin.hit_line_y(f)), "perfect", fposmod(t[0], 0.4))
	root.add_child(field)
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1440)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(root)
	get_root().add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	for i in 10:
		await process_frame
	var cpu := 0.0
	var gpu := 0.0
	var worst_cpu := 0.0
	var samples: Array[float] = []
	var frames := 90
	for i in frames:
		t[0] += 1.0 / 60.0
		field.queue_redraw()
		if i % 8 == 0:
			scene.jolt("bell" if i % 16 == 0 else "step")
		if i == 30:
			scene.throw_rope()
		await RenderingServer.frame_post_draw
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
		cpu += c
		samples.append(c)
		worst_cpu = maxf(worst_cpu, c)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
	if with_scene and with_field:
		vp.get_texture().get_image().save_png(out_dir.path_join("play_mock.png"))
	samples.sort()
	var line := "[scene %s, field %s] play-screen mock 720x1440:" % [with_scene, with_field] + " render cpu median %.2f ms, min %.2f, avg %.2f, worst %.2f; gpu avg %.2f ms (llvmpipe software GPU); procession process %d us; bakes %d" % [samples[frames / 2], samples[0], cpu / frames, worst_cpu, gpu / frames, scene.last_process_usec, scene.bake_count]
	print(line)
	var f := FileAccess.open(out_dir.path_join("timing.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(out_dir.path_join("timing.txt")) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	vp.queue_free()
