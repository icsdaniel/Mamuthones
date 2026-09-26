extends SceneTree
## Bakes the art that has to exist as files: the app icons and the seven stop cards.
## Needs a real renderer; run through tools/art/bake.sh, or:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/bake.gd -- <game/art dir>

var out_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://art")
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("cards"))
	await process_frame
	await _icons()
	await _notes()
	for n in range(1, StopBackdrops.COUNT + 1):
		await _card(n)
	quit()


class _Painter:
	extends Control
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _painter(sz: Vector2, p: Callable) -> Control:
	var c := _Painter.new()
	c.size = sz
	c.painter = p
	return c


func _grab(node: Node, size: Vector2i, transparent := false, frames := 4) -> Image:
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
	vp.queue_free()
	await process_frame
	return img


func _save(img: Image, name: String) -> void:
	var path := out_dir.path_join(name)
	img.save_png(path)
	print("baked ", path)


func _icons() -> void:
	var big := await _grab(_painter(Vector2(1024, 1024), func(ci): AppIcon.paint(ci, 1024.0)), Vector2i(1024, 1024))
	big.convert(Image.FORMAT_RGB8)
	_save(big, "icon.png")
	# Small sizes are painted with the simplified mark rather than shrunk, so the rope and mask stay bold.
	var mid := await _grab(_painter(Vector2(192, 192), func(ci): AppIcon.paint(ci, 192.0)), Vector2i(192, 192))
	mid.convert(Image.FORMAT_RGB8)
	_save(mid, "icon_192.png")
	var fg := await _grab(_painter(Vector2(432, 432), func(ci): AppIcon.paint_foreground(ci, 432.0)), Vector2i(432, 432), true)
	_save(_unpremultiply(fg), "icon_fg_432.png")
	var bg := await _grab(_painter(Vector2(432, 432), func(ci): AppIcon.paint_background(ci, 432.0)), Vector2i(432, 432))
	bg.convert(Image.FORMAT_RGB8)
	_save(bg, "icon_bg_432.png")


func _card(n: int) -> void:
	var sz := Vector2(StopArt.SIZE)
	var root := Control.new()
	root.size = sz
	var inset := 20.0
	root.add_child(_painter(sz, func(ci):
		WoodcutDraw.fill(ci, PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]), Color.WHITE, Palette.tex("paper"), 1.0 / 512.0)))
	var scene := ProcessionScene.new()
	scene.framed = false
	scene.show_player_mark = false
	scene.position = Vector2(inset, inset)
	scene.size = sz - Vector2(inset, inset) * 2.0
	scene.set_stop(n)
	if n == 1:
		# The Workshop is a still life: a mask being finished on the bench by the fire, not the row.
		scene.visible = false
		root.add_child(_painter(sz, func(ci): _workshop_still(ci, Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0))))
	root.add_child(scene)
	# The print's border: a rough ink rule round the image and a thin second rule outside it.
	root.add_child(_painter(sz, func(ci):
		var r := Rect2(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0)
		var edge := WoodcutDraw.rough(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), 1.2, n, 8.0)
		WoodcutDraw.outline(ci, edge, Palette.INK, 5.0, n)
		var outer := r.grow(9.0)
		var edge2 := WoodcutDraw.rough(PackedVector2Array([outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]), 1.0, n + 7, 10.0)
		WoodcutDraw.outline(ci, edge2, Color(Palette.INK, 0.7), 1.6, n + 3)))
	# Let the row settle and jolt once so the frame catches them mid-step.
	var img: Image
	var vp := SubViewport.new()
	vp.size = StopArt.SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(root)
	get_root().add_child(vp)
	for i in 8:
		await process_frame
	scene.set_unison(4)
	# A step, not a bell: the row mid-stride, without the in-game ring marks (a still print).
	scene.jolt("step")
	if n == 5:
		scene.throw_rope()
	for i in (14 if n == 5 else 5):
		await process_frame
	await RenderingServer.frame_post_draw
	img = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	vp.queue_free()
	_save(img, "cards/stop_%d.png" % n)


func _workshop_still(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_set_transform(r.position)
	var w := r.size.x
	var h := r.size.y
	StopBackdrops.paint(ci, 1, w, h, h - 10.0)
	WoodcutDraw.glow(ci, Vector2(w * 0.55, h * 0.55), h * 0.9, Color(Palette.EMBER, 0.55))
	# The bench top, close up.
	var bench := PackedVector2Array([Vector2(0, h * 0.74), Vector2(w, h * 0.7), Vector2(w, h), Vector2(0, h)])
	WoodcutDraw.fill(ci, bench, Color("#3b2b20"))
	WoodcutDraw.fill(ci, bench, Color(Palette.BONE, 0.12), Palette.tex("grain"), 1.0 / 260.0)
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(0, h * 0.74), Vector2(w, h * 0.7)]), Color(Palette.EMBER, 0.7), 2.0, 2.0, 3.0)
	# Shavings and gouges.
	for k in 14:
		var x := w * (0.1 + 0.8 * WoodcutDraw.hash01(k, 3))
		var y := h * (0.8 + 0.15 * WoodcutDraw.hash01(k, 4))
		WoodcutDraw.stroke(ci, WoodcutDraw.quad(Vector2(x, y), Vector2(x + 7, y - 9), Vector2(x + 15, y - 1), 5), Color(Palette.EMBER_HOT, 0.75), 2.0, 0.4, 3.0)
	for k in 4:
		var gx := w * 0.1 + float(k) * 34.0
		var gy := h * 0.9 - float(k) * 4.0
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(gx, gy), Vector2(gx + 44, gy - 16)]), Color("#6d4b30"), 9.0, 7.0)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(gx + 44, gy - 16), Vector2(gx + 80, gy - 29)]), Palette.BONE_DIM, 3.0, 1.5)
	# The mask, bigger than life, lit by the hearth, and a pair of bells waiting beside it.
	MaskView.halo(ci, Vector2(w * 0.55, h * 0.47), 38.0)
	MaskView.paint(ci, Vector2(w * 0.55, h * 0.47), 38.0, {"brow": "heavy", "eyes": "round", "nose": "hooked", "cheeks": "full", "mouth": "closed", "finish": "soot_black", "patina": "worn"}, 2, false)
	Figures.cowbell(ci, Vector2(w * 0.84, h * 0.72), 60.0, 0.15, Palette.EMBER, 1)
	Figures.cowbell(ci, Vector2(w * 0.93, h * 0.75), 44.0, -0.2, Palette.EMBER, 1)
	ci.draw_set_transform(Vector2.ZERO)


## A transparent SubViewport stores premultiplied colour; PNGs want straight alpha.
func _unpremultiply(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a > 0 and a < 255:
			data[i] = mini(255, data[i] * 255 / a)
			data[i + 1] = mini(255, data[i + 1] * 255 / a)
			data[i + 2] = mini(255, data[i + 2] * 255 / a)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## Note, bar, button, lane and hit-line sprites for LaneSkin, drawn from its vector versions.
func _notes() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("notes"))
	LaneSkin.use_sprites = false
	for job in LaneSkin.sprite_jobs():
		var name: String = job[0]
		var painter: Callable = job[1]
		var cell := LaneSkin.cell_size(name)
		var k := 1.0 if name == "lanes" else LaneSkin.SPRITE_SCALE
		var sz := Vector2i(int(cell.x * k), int(cell.y * k))
		var node := _painter(Vector2(sz), func(ci):
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
			painter.call(ci)
			ci.draw_set_transform(Vector2.ZERO))
		var img := await _grab(node, sz, name != "lanes", 3)
		_save(_unpremultiply(img) if name != "lanes" else img, "notes/%s.png" % name)
	LaneSkin.use_sprites = true
