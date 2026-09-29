class_name PxType
extends RefCounted
## The play screen's pixel type (tools/art/pixel/type.py): bitmap faces set at a whole number of art
## pixels, so every glyph pixel is PX screen px like the rest of the art.
##
##   "caps"       capitals 7 px, the lower case as 5-px small capitals; white ink in a K0 outline,
##                tinted by the font colour (or modulate)
##   "caps_gold"  the same, inked cream to gold (use a white font colour)
##   "big"        the caps face doubled (Scale2x), white ink, K0 outline and drop shadow
##   "big_gold"   the same, cream to gold
##   "score"      the score's figures, 7 x 10 with two-pixel stems, cream to gold
##   "count"      the same figures doubled twice (40 px tall), for the count-in
##
## PxType.label(l, "caps", PixelPalette.GOLD[4]) styles a Label; PxType.draw(ci, ...) draws a line.

const DIR := "res://art/px/field/font_"
## The face's design size (its BMFont size): a Label's font size is this x PX x k.
const SIZES := {"caps": 10, "caps_gold": 10, "big": 20, "big_gold": 20, "score": 12, "count": 48}
## Rows from the top of a line to the baseline, in font px.
const BASE := {"caps": 9, "caps_gold": 9, "big": 18, "big_gold": 18, "score": 10, "count": 40}

static var _fonts := {}


static func font(face: String) -> Font:
	if _fonts.has(face):
		return _fonts[face]
	var f: Font = null
	var path := DIR + face + ".fnt"
	if ResourceLoader.exists(path):
		f = load(path)
	if f is FontFile:
		(f as FontFile).fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[face] = f
	return f


## The font size that sets `face` at k art px per font px.
static func size(face: String, k := 1) -> int:
	return int(SIZES.get(face, 10) * PxArt.PX) * k


## Styles a Label in `face`: the colour tints a white face (keep white for the gold faces); no
## outline or shadow (the faces carry their own).
static func label(l: Label, face: String, color := Color.WHITE, k := 1) -> void:
	l.add_theme_font_override("font", font(face))
	l.add_theme_font_size_override("font_size", size(face, k))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("line_spacing", 0)
	l.material = null


## Width of `text` on screen in `face` at k.
static func width(face: String, text: String, k := 1) -> float:
	return font(face).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size(face, k)).x


## Height of a line of `face` on screen (top of line to its bottom).
static func line_height(face: String, k := 1) -> float:
	return font(face).get_height(size(face, k))


## Draws `text` with the top of its line at `pos` (rounded to whole screen px); align -1 left, 0
## centred on pos.x, 1 right.
static func draw(ci: CanvasItem, face: String, pos: Vector2, text: String, color := Color.WHITE, k := 1, align := -1) -> void:
	var f := font(face)
	var fs := size(face, k)
	var x := pos.x
	if align >= 0:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= w * (0.5 if align == 0 else 1.0)
	var p := Vector2(roundf(x / PxArt.PX) * PxArt.PX, roundf(pos.y)) + Vector2(0.0, f.get_ascent(fs))
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
