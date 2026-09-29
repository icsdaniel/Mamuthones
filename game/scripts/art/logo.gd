@tool
class_name Logo
extends Control
## The game's mark in pixel art (tools/art/pixel/logo.py), drawn at the largest whole multiple that
## fits, with nearest filtering:
##   mode "full"   the whole logo: the hooded Mamuthone, bells, the soha, the MAMUTHONES word mark, the
##                 banner (the translated subtitle is written on it) and the bonfire lozenge
##   mode "title"  the word mark alone with the subtitle under it between gold rules and red lozenges,
##                 as on the title screen's sky
##   mode "mark"   the hooded mask with its bells (a seal)
## `show_title` is kept for older callers: it picks "full" (the logo with its name) over "mark".

@export_enum("full", "title", "mark") var mode := "mark":
	set(v):
		mode = v
		queue_redraw()
@export var show_title := false:
	set(v):
		show_title = v
		if v and mode == "mark":
			mode = "full"
		queue_redraw()
## Player-facing subtitle (UI may translate it); empty hides it.
@export var subtitle := "The Weight of Bells":
	set(v):
		subtitle = v
		queue_redraw()
@export var title := "Mamuthones"
## Largest multiple to draw at (3 keeps the art on the base screen's grid).
@export var max_scale := 3

## The banner's text box inside logo.png, in art pixels (logo.py BANNER).
const BANNER := Rect2(50, 151, 100, 12)
const SUB_SIZE := 34
const SUB_MIN := 26
## The mask the old painted logo wore (setup_art.gd and others still paint it by these parts).
const MASK := {"brow": "heavy", "eyes": "round", "nose": "hooked", "cheeks": "full", "mouth": "closed", "finish": "soot_black", "patina": "worn"}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _tex() -> Texture2D:
	return Palette.px({"full": "logo/logo", "title": "logo/title", "mark": "logo/mark"}[mode])


## Height the title mode's subtitle line needs under the word mark.
func _sub_h() -> float:
	return 0.0 if mode != "title" or subtitle == "" else SUB_SIZE * 1.5


func _scale_for(tex: Texture2D) -> int:
	var ts := tex.get_size()
	var k := mini(int(size.x / ts.x), int((size.y - _sub_h()) / ts.y))
	return clampi(k, 1, max_scale)


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


func _draw() -> void:
	var tex := _tex()
	if tex == null:
		return
	var k := _scale_for(tex)
	var ts := tex.get_size() * k
	var block_h := ts.y + _sub_h()
	var pos := Vector2(roundf((size.x - ts.x) * 0.5), roundf((size.y - block_h) * 0.5))
	draw_texture_rect(tex, Rect2(pos, ts), false)
	if subtitle == "":
		return
	var font := Palette.serif_font("Bold")
	if mode == "full":
		var box := Rect2(pos + BANNER.position * k, BANNER.size * k)
		var fs := _fit(font, subtitle, maxi(SUB_MIN, int(box.size.y * 0.95)), box.size.x - 8.0 * k)
		var w := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := box.position.y + box.size.y * 0.5 + font.get_ascent(fs) * 0.36
		_text(font, subtitle, Vector2(box.position.x + (box.size.x - w) * 0.5, base), fs, Palette.BONE)
	elif mode == "title":
		title_subtitle(self, font, subtitle, Vector2(size.x * 0.5, pos.y + ts.y + SUB_SIZE * 0.95), size.x * 0.92, SUB_SIZE)


## "◈ ——— The Weight of Bells ——— ◈": the gold subtitle between two gold rules ending in red lozenges.
static func title_subtitle(ci: CanvasItem, font: Font, text: String, center: Vector2, max_w: float, fs: int) -> void:
	var px := 3.0
	var dia := Palette.ui("diamond_red")
	var dsz := dia.get_size() * px if dia != null else Vector2(21, 21)
	var rule_w := 34.0 * px
	fs = _fit(font, text, fs, max_w - 2.0 * (dsz.x + rule_w * 0.5 + 20.0))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gap := 5.0 * px
	var room := (max_w - tw) * 0.5 - gap - dsz.x
	rule_w = clampf(floorf(room / px) * px, 8.0 * px, rule_w)
	var mid_y := roundf((center.y - font.get_ascent(fs) * 0.32) / px) * px
	for side: float in [-1.0, 1.0]:
		var inner := center.x + side * (tw * 0.5 + gap)
		var outer := inner + side * rule_w
		var x0 := roundf(minf(inner, outer) / px) * px
		ci.draw_rect(Rect2(x0, mid_y - px, absf(outer - inner), px), PixelPalette.GOLD[4])
		ci.draw_rect(Rect2(x0, mid_y, absf(outer - inner), px), PixelPalette.K[0])
		# a bead a third of the way along, as on the reference's rules
		var bx := roundf(lerpf(inner, outer, 0.7) / px) * px
		ci.draw_rect(Rect2(bx - px, mid_y - 2.0 * px, px, 3.0 * px), PixelPalette.GOLD[5])
		if dia != null:
			var dx := outer + (0.0 if side > 0 else -dsz.x) + side * px
			ci.draw_texture_rect(dia, Rect2(Vector2(roundf(dx), mid_y - px * 0.5 - dsz.y * 0.5 + px * 0.5).round(), dsz), false)
	var p := Vector2(center.x - tw * 0.5, center.y)
	ci.draw_string_outline(font, p + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.INK)
	ci.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.INK)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.GOLD)


## The largest size up to `fs` at which `text` fits in `max_w` (never below 12 px).
static func _fit(font: Font, text: String, fs: int, max_w: float) -> int:
	if font == null or text == "":
		return fs
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w <= max_w:
		return fs
	return maxi(12, int(floor(float(fs) * max_w / w)))


func _text(font: Font, text: String, p: Vector2, fs: int, color: Color) -> void:
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.INK)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Paints the mark (the hooded mask with its bells) centred at `c`, fitting a circle of radius `r`, at a
## whole multiple of its pixels when it can (small uses may land between).
static func paint(ci: CanvasItem, c: Vector2, r: float, _small := false) -> void:
	var tex := Palette.px("logo/mark")
	if tex == null:
		return
	var ts := tex.get_size()
	var k := 2.0 * r / maxf(ts.x, ts.y)
	if k >= 1.0:
		k = floorf(k)
	var sz := ts * k
	ci.draw_texture_rect(tex, Rect2((c - sz * 0.5).round(), sz), false)
