class_name KitIcons
extends RefCounted
## Extra glyph icons for the menu kit (added with the workshop, 2026-10), drawn like WoodcutTheme's:
## '#' ink, '+' a darker shade, '.' clear, scaled x3 to the art grid and tinted where they are drawn.
##   KitIcons.get_icon("lock" | "zoom" | "figure" | "check") -> Texture2D (cached)

const GLYPHS := {
	"lock": [
		"..####..",
		".##..##.",
		".#....#.",
		".#....#.",
		"########",
		"########",
		"###..###",
		"###..###",
		"####.###",
		"########"],
	"zoom": [
		"..####....",
		".#....#...",
		"#......#..",
		"#......#..",
		"#......#..",
		"#......#..",
		".#....#...",
		"..#####...",
		"......###.",
		".......###",
		"........##"],
	"figure": [
		"...##...",
		"..####..",
		"..####..",
		"...##...",
		".######.",
		"########",
		"########",
		"########",
		".######.",
		".##..##.",
		".##..##."],
}

static var _cache := {}


static func get_icon(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var t: Texture2D
	if GLYPHS.has(name):
		var rows: Array = GLYPHS[name]
		var w := 0
		for r in rows:
			w = maxi(w, (r as String).length())
		var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				if r[x] == "#":
					img.set_pixel(x, y, Color.WHITE)
				elif r[x] == "+":
					img.set_pixel(x, y, Color(0.7, 0.7, 0.7))
		img.resize(w * 3, rows.size() * 3, Image.INTERPOLATE_NEAREST)
		t = ImageTexture.create_from_image(img)
	else:
		t = WoodcutTheme.icon(name)
	_cache[name] = t
	return t
