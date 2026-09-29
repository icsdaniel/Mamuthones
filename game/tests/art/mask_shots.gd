extends SceneTree
## Renders pixel masks for judging (not a test):
##   godot --headless --path game -s res://tests/art/mask_shots.gd -- <out dir> [unit]
## One sheet per part: every option of it on the default mask, plus finishes x patinas and small sizes.

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "user://mask_shots"
	var unit := float(a[1]) if a.size() > 1 else 22.0
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_usec()
	for p in MaskSpec.PARTS:
		var imgs: Array[Image] = []
		for o in MaskSpec.options(p):
			var s := MaskSpec.default()
			s[p] = o
			imgs.append(MaskPixels.render(s, unit, true, "natural", ""))
		for o in MaskSpec.options(p):
			var s := MaskSpec.default()
			s[p] = o
			imgs.append(MaskPixels.render(s, unit, true, "natural", p if p in MaskPixels.PART_ID else ""))
		_sheet(imgs, out.path_join("part_%s.png" % p), 4)
	var grid: Array[Image] = []
	for f in MaskSpec.options("finish"):
		for pt in MaskSpec.options("patina"):
			var s := MaskSpec.default()
			s.finish = f
			s.patina = pt
			grid.append(MaskPixels.render(s, unit, true, "dark" if pt == "old" else "natural"))
	_sheet(grid, out.path_join("finish_patina.png"), 3)
	var small: Array[Image] = []
	for u in [4.0, 6.0, 9.0, 12.0]:
		small.append(MaskPixels.render(MaskSpec.default(), u))
	_sheet(small, out.path_join("small.png"), 6)
	print("mask sheets in %d ms" % ((Time.get_ticks_usec() - t0) / 1000))
	quit()


func _sheet(imgs: Array[Image], path: String, scale: int) -> void:
	var h := 0
	var cw := 0
	for i in imgs:
		h = maxi(h, i.get_height())
		cw = maxi(cw, i.get_width() + 4)
	var cols := 4
	var rows := int(ceil(imgs.size() / float(cols)))
	var sheet := Image.create(cw * mini(cols, imgs.size()), (h + 4) * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(PixelPalette.NAVY[1])
	for k in imgs.size():
		var im := imgs[k]
		sheet.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((k % cols) * cw + 2, (k / cols) * (h + 4) + 2))
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	sheet.save_png(path)
