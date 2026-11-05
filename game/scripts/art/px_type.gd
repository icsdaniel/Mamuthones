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
##   "num_gold"   Daniele's ChatGPT figures (tools/art/chatgpt/digits.py): 0-9 , . x in carved gold,
##   "num_big"    15 px tall; the same 26 px tall; and in bone white, 15 px tall. Their colours are
##   "num_white"  their own (keep the font colour white); no smooth stand-in.
##
## PxType.label(l, "caps", PixelPalette.GOLD[4]) styles a Label; PxType.draw(ci, ...) draws a line.

const FONT := "res://fonts/woodcut5.fnt"
## The Woodcut look sets every face in its one pixel type (fonts/woodcut5, the Controluce menu's 5 x 7
## capitals, made by tools/art/claude_styles/export_font.py), at a whole number of screen px per
## type px: the faces differ only in size.
const LINE := 12                     ## the type's line, in its own px (its BMFont size: 7-px capitals, accents, descent, a row of leading)
const SCALE := {"caps": 3, "caps_gold": 3, "big": 6, "big_gold": 6, "score": 4, "count": 12,
	"num_gold": 4, "num_big": 7, "num_white": 4}
const SIZES := {"caps": 12, "caps_gold": 12, "big": 12, "big_gold": 12, "score": 12, "count": 12,
	"num_gold": 12, "num_big": 12, "num_white": 12}
const BASE := {"caps": 9, "caps_gold": 9, "big": 9, "big_gold": 9, "score": 9, "count": 9,
	"num_gold": 9, "num_big": 9, "num_white": 9}
const CREAM := Color("#efe6d2")

static var _font: FontFile
## Kept for the screens that set it; the woodcut type is the same either way.
static var smooth := false


static func font(_face := "caps") -> Font:
	if _font == null:
		_font = load(FONT) as FontFile
		if _font != null:
			_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return _font if _font != null else ThemeDB.fallback_font


## The font size that sets `face` at k times its scale.
static func size(face: String, k := 1) -> int:
	return LINE * int(SCALE.get(face, 3)) * k


## Styles a Label in `face`: plain ink, no outline or shadow (the woodcut prints flat).
static func label(l: Label, face: String, color := Color.WHITE, k := 1) -> void:
	l.add_theme_font_override("font", font(face))
	l.add_theme_font_size_override("font_size", size(face, k))
	l.add_theme_color_override("font_color", CREAM if color == Color.WHITE else color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("line_spacing", 0)
	l.material = null


## The smooth faces' own ink: gold for the gold faces and the figures, white for the rest.
static func _ink(_face: String) -> Color:
	# white type takes the paper's cream; coloured type keeps its colour
	return Color.WHITE


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
	var p := Vector2(roundf(x), roundf(pos.y)) + Vector2(0.0, f.get_ascent(fs))
	ci.draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color if color != Color.WHITE else CREAM)
