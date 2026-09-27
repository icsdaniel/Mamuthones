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
		var fs := _fit(font, title.to_upper(), int(title_h * 0.5), size.x * 0.92)
		var ty := size.y - title_h + fs * 0.95
		_centered_text(font, title.to_upper(), ty, fs, Palette.BONE)
		if subtitle != "":
			var sub_font := Palette.text_font("Bold")
			var ss := _fit(sub_font, subtitle, maxi(24, int(fs * 0.34)), size.x * 0.92)
			_centered_text(sub_font, subtitle, ty + ss * 1.5, ss, Palette.EMBER)


## The largest size up to `fs` at which `text` fits in `max_w` (never below 12 px).
static func _fit(font: Font, text: String, fs: int, max_w: float) -> int:
	if font == null or text == "":
		return fs
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w <= max_w:
		return fs
	return maxi(12, int(floor(float(fs) * max_w / w)))


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
	var disc := WoodcutDraw.rough(WoodcutDraw.ellipse(c, Vector2(r * 0.92, r * 0.92), 64), r * 0.01, 5, r * 0.05)
	WoodcutDraw.fill(ci, disc, Palette.EMBER)
	WoodcutDraw.glow(ci, c + Vector2(0, -r * 0.05), r * 0.75, Color(Palette.EMBER_HOT, 0.7))
	_gouges(ci, c, r, small)
	WoodcutDraw.outline(ci, disc, Palette.INK, r * (0.07 if small else 0.055), 3)
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


## Hand-cut radial gouges in the firelit disc: V-shaped wedges of uneven length and width cut from
## the rim toward the mask, each dark in its trough with a bright chip along its lit edge.
static func _gouges(ci: CanvasItem, c: Vector2, r: float, small: bool) -> void:
	var n := 14 if small else 34
	for i in n:
		var a := TAU * (float(i) + 0.35 * (WoodcutDraw.hash01(i, 61) - 0.5)) / float(n) - PI * 0.5
		var r_out := r * (0.87 - 0.03 * WoodcutDraw.hash01(i, 62))
		var r_in := r * lerpf(0.5, 0.66, WoodcutDraw.hash01(i, 63))
		var half := (PI / float(n)) * lerpf(0.34, 0.5, WoodcutDraw.hash01(i, 64)) * (1.7 if small else 1.0)
		var bend := (WoodcutDraw.hash01(i, 65) - 0.5) * 0.08
		var tip := c + Vector2.from_angle(a + bend) * r_in
		var o1 := c + Vector2.from_angle(a - half) * r_out
		var o2 := c + Vector2.from_angle(a + half) * r_out
		var mid := c + Vector2.from_angle(a + bend * 0.5) * lerpf(r_in, r_out, 0.5)
		var m1 := mid + Vector2.from_angle(a - PI * 0.5) * (o1.distance_to(o2) * 0.28)
		var m2 := mid + Vector2.from_angle(a + PI * 0.5) * (o1.distance_to(o2) * 0.28)
		WoodcutDraw.fill(ci, PackedVector2Array([tip, m1, o1, o2, m2]), Color(Palette.RED_DEEP, 0.92))
		if not small:
			# The lit wall of the cut: a thin bright chip along one side.
			WoodcutDraw.stroke(ci, PackedVector2Array([tip.lerp(o2, 0.15), m2, o2]), Color(Palette.EMBER_HOT, 0.9), r * 0.004, r * 0.012, r * 0.014)


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
