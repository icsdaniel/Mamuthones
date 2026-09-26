@tool
class_name Logo
extends Control
## The game's mark: the black carved mask front and centre on a firelit disc, the red rope looped
## round it, and a hint of bells below. With `show_title`, the name is set under it in the display face.
## Logo.paint() is also what the app icon is built from (AppIcon), so both stay the same picture.

@export var show_title := false:
	set(v):
		show_title = v
		queue_redraw()
## Player-facing subtitle (UI may translate it); empty hides it.
@export var subtitle := "The Weight of Bells":
	set(v):
		subtitle = v
		queue_redraw()
@export var title := "Mamuthones":
	set(v):
		title = v
		queue_redraw()

## The mask used on the logo: the classic form, worn patina so the carving reads.
const MASK := {"brow": "heavy", "eyes": "round", "nose": "hooked", "cheeks": "full", "mouth": "closed", "finish": "soot_black", "patina": "worn"}


func _draw() -> void:
	var title_h := 0.0
	if show_title:
		title_h = minf(size.y * 0.32, size.x * 0.3)
	var r := minf(size.x, size.y - title_h) * 0.47
	var c := Vector2(size.x * 0.5, (size.y - title_h) * 0.5)
	paint(self, c, r)
	if show_title:
		var font := Palette.display_font()
		var fs := int(title_h * 0.5)
		var ty := size.y - title_h + fs * 0.95
		_centered_text(font, title.to_upper(), ty, fs, Palette.BONE)
		if subtitle != "":
			var sub_font := Palette.text_font("Bold")
			var ss := maxi(24, int(fs * 0.34))
			_centered_text(sub_font, subtitle, ty + ss * 1.5, ss, Palette.EMBER)


func _centered_text(font: Font, text: String, y: float, fs: int, color: Color) -> void:
	if font == null:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2((size.x - w) * 0.5, y)
	draw_string(font, p + Vector2(3, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Paints the mark centred at `c`, fitting a circle of radius `r`.
## small: simplify for tiny sizes (fewer cuts, thicker rope) so it reads at 64 px.
static func paint(ci: CanvasItem, c: Vector2, r: float, small := false) -> void:
	WoodcutDraw.begin(ci)
	# The firelit disc: ember with radiating gouges, rimmed in ink.
	var disc := WoodcutDraw.rough(WoodcutDraw.ellipse(c, Vector2(r * 0.9, r * 0.9), 64), r * 0.008, 5, r * 0.05)
	WoodcutDraw.fill(ci, disc, Palette.EMBER)
	if not small:
		WoodcutDraw.fill(ci, disc, Color(Palette.RED_DEEP, 0.35), Palette.tex("grain"), 1.0 / (r * 1.6))
	WoodcutDraw.rays(ci, c + Vector2(0, -r * 0.05), r * 0.5, r * 0.9, 40 if not small else 18, Color(Palette.EMBER_HOT, 0.9), r * (0.03 if not small else 0.05), 11)
	WoodcutDraw.glow(ci, c + Vector2(0, -r * 0.05), r * 0.8, Color(Palette.EMBER_HOT, 0.6))
	WoodcutDraw.outline(ci, disc, Palette.INK, r * 0.05, 3)
	# Bells hanging below, either side of the chin.
	Figures.cowbell(ci, c + Vector2(-r * 0.46, r * 0.5), r * 0.3, 0.45, Palette.EMBER_HOT, 0 if small else 1)
	Figures.cowbell(ci, c + Vector2(r * 0.46, r * 0.5), r * 0.3, -0.45, Palette.EMBER_HOT, 0 if small else 1)
	Figures.cowbell(ci, c + Vector2(0, r * 0.66), r * 0.22, 0.0, Palette.EMBER_HOT, 0)
	# The rope's loop passes behind the head at the top...
	var rope := _rope_path(c, r)
	var cut := int(rope.size() * 0.62)
	_rope(ci, rope.slice(0, cut + 1), r, small)
	# ...the mask, big and black...
	MaskView.paint(ci, c + Vector2(0, -r * 0.1), r * 0.37, MASK, 1 if small else 2, false)
	# ...and comes round in front of the bells, crossing itself in a noose with a hanging tail.
	_rope(ci, rope.slice(cut), r, small)
	var end := rope[0]
	WoodcutDraw.fill(ci, WoodcutDraw.ellipse(end, Vector2(r * 0.07, r * 0.06), 12, 0.6), Palette.INK)
	WoodcutDraw.fill(ci, WoodcutDraw.ellipse(end, Vector2(r * 0.055, r * 0.045), 12, 0.6), Palette.RED_DEEP)
	var tail := PackedVector2Array([end, end + Vector2(r * 0.05, r * 0.14), end + Vector2(r * 0.02, r * 0.3)])
	_rope(ci, WoodcutDraw.smooth_open(tail, 4), r, small)
	WoodcutDraw.end()


## A loop round the mask: starts at the lower left, passes behind the head, comes round in front of
## the chin and ends at the lower right.
static func _rope_path(c: Vector2, r: float) -> PackedVector2Array:
	# Starts at the noose (lower right), runs up the right side, over the top, down the left and back
	# across the bottom to the noose. Screen angles: 0 is right, 90 is down.
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var t := float(i) / float(n)
		var a := deg_to_rad(lerpf(55.0, -300.0, t))
		var rr := r * 0.74
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * 0.97 - r * 0.02))
	return pts


static func _rope(ci: CanvasItem, pts: PackedVector2Array, r: float, small: bool) -> void:
	if pts.size() < 2:
		return
	var w := r * (0.1 if small else 0.075)
	WoodcutDraw.stroke(ci, pts, Palette.INK, w * 1.35, w * 1.35, w * 1.4)
	WoodcutDraw.stroke(ci, pts, Palette.RED, w, w, w)
	if small:
		return
	# Twists.
	for i in range(1, pts.size() - 1):
		var d := (pts[i + 1] - pts[i - 1]).normalized()
		var nrm := d.orthogonal() * w * 0.45
		WoodcutDraw.line(ci, pts[i] - nrm - d * w * 0.25, pts[i] + nrm + d * w * 0.25, Palette.RED_DEEP, maxf(1.0, w * 0.22))
		WoodcutDraw.line(ci, pts[i] - nrm * 0.6 - d * w * 0.1, pts[i] + nrm * 0.2, Color(Palette.BONE, 0.4), maxf(1.0, w * 0.08))
