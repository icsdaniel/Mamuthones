class_name KitIcons
extends RefCounted
## Menu-screen icons added on top of the kit's own (WoodcutTheme.icon(): chevrons, ladder, check,
## dot, plus): pixel maps baked at start like the kit's, '#' ink (white, tinted by the button's icon
## colour or a modulate), '+' a darker shade of it, '.' clear. get(name, k) bakes at k screen px per
## art px (3 = the art grid; 4 for the title's tab icons); any other name falls back to WoodcutTheme.
## (2026-10 menu rework; kept apart from woodcut_theme.gd so the kit's file stays the kit's.)

const GLYPHS := {
	"gear": [
		".....###.....", ".##..###..##.", ".###########.", "..####+####..", ".###+...+###.",
		"####.....####", "####.....####", "####.....####", ".###+...+###.", "..####+####..",
		".###########.", ".##..###..##.", ".....###....."],
	"help": [
		"..#####..", ".#######.", "###...###", "......###", ".....###.", "....###..",
		"...###...", "...###...", ".........", "...###...", "...###..."],
	"lock": [
		"...#####...", "..##...##..", "..#.....#..", "..#.....#..", "###########", "###########",
		"#####.#####", "####...####", "#####.#####", "#####.#####", "###########"],
	"play": [
		"##.......", "####.....", "######...", "########.", "#########", "#########",
		"########.", "######...", "####.....", "##......."],
	# Story: the bonfire the procession walks to
	"flame": [
		".....#......", ".....##.....", "....###.....", "....####....", "...#####.#..", "..######.##.",
		"..#########.", ".###########", ".#####+#####", "#####+++####", "####+++++###", ".###+++++##.",
		"..########.."],
	# Free play: a pair of quavers
	"note": [
		"....########", "....########", "....##....##", "....##....##", "....##....##", "....##....##",
		"..####..####", ".#####.#####", "######.#####", ".####...###."],
	# Workshop: a Mamuthone's carved mask
	"mask": [
		"..########..", ".##########.", "############", "###..##..###", "###..##..###", "############",
		"#####..#####", "#####..#####", ".##########.", ".###....###.", "..########..", "...######..."],
	"power": [
		".....##.....", "..#..##..#..", ".##..##..##.", "##...##...##", "##........##", "##........##",
		"##........##", ".##......##.", "..########..", "...######..."],
	"bell": [
		".....##.....", "....####....", "...######...", "...######...", "..########..", "..########..",
		"..########..", ".##########.", "############", "############", ".....##....."],
	"close": [
		"##.....##", "###...###", ".###.###.", "..#####..", "...###...", "..#####..", ".###.###.",
		"###...###", "##.....##"],
	"zoom": [
		"..####....", ".#....#...", "#......#..", "#......#..", "#......#..", "#......#..", ".#....#...",
		"..#####...", "......###.", ".......###", "........##"],
	"figure": [
		"...##...", "..####..", "..####..", "...##...", ".######.", "########", "########", "########",
		".######.", ".##..##.", ".##..##."],
}

static var _cache := {}


## The icon `name` at k screen px per art px (cached).
static func get_icon(name: String, k := 3) -> Texture2D:
	var key := "%s@%d" % [name, k]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D
	if GLYPHS.has(name):
		var rows: Array = GLYPHS[name]
		var w := 0
		for r in rows:
			w = maxi(w, (r as String).length())
		var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			var r: String = rows[y]
			for x in r.length():
				match r[x]:
					"#":
						img.set_pixel(x, y, Color.WHITE)
					"+":
						img.set_pixel(x, y, Color(0.62, 0.62, 0.62))
		img.resize(w * k, rows.size() * k, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	else:
		tex = WoodcutTheme.icon(name)
		if k != 3 and tex != null:
			var img := tex.get_image()
			img.resize(img.get_width() / 3 * k, img.get_height() / 3 * k, Image.INTERPOLATE_NEAREST)
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
