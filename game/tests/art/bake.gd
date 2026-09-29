extends SceneTree
## Bakes the art that has to exist as files: the app icons and the note sprites. (The stop pictures
## are pixel art baked by tools/art/pixel/stops.py into art/px/stops/.)
## Needs a real renderer; run through tools/art/bake.sh, or:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/art/bake.gd -- <game/art dir>

var out_dir := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://art")
	await process_frame
	await _icons()
	await _notes()
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
