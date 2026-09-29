@tool
class_name MaskView
extends Control
## Draws a carved Mamuthone mask from a MaskSpec dictionary as pixel art (MaskPixels), framed by the
## dark kerchief and held by the leather strap. Set `spec` (invalid values fall back to defaults) and
## it redraws. On the workbench it hangs in a gold frame against the hearth's glow.
##
## The static paint() is shared with the portrait, the logo and the icon, so the mask the player
## carves is the one they walk with.
##
## Form (kept within real Mamoiada masks): dark, almost black wood; heavy brow; deep eye holes; a
## large, often hooked nose; pronounced cheeks; a neutral or grim mouth. The fire lights it from the
## upper right; the carving shows in the light and the shadows it casts.

@export var spec: Dictionary = {}:
	set(v):
		spec = v
		queue_redraw()
## Firelight behind the mask and a gold frame round it (the workshop).
@export var show_halo := false:
	set(v):
		show_halo = v
		queue_redraw()
## Draw the kerchief and strap (off for a bare mask on the workbench).
@export var show_kerchief := true:
	set(v):
		show_kerchief = v
		queue_redraw()
## Strap leather id (MaskSpec.STRAPS).
@export var straps := "natural":
	set(v):
		straps = v
		queue_redraw()
## Ring one part (for the carving screen), e.g. "nose". Empty for none.
@export var highlight_part := "":
	set(v):
		highlight_part = v
		queue_redraw()

## Every finish stays black to dark brown-black: the wood's middle step (base) with its grain is kept
## under about 12 % luminance (tested). The ramps themselves are MaskPixels.FINISH_RAMP.
const FINISH := {
	"soot_black": {"base": PixelPalette.WOOD[1], "grain": 0.0, "rim": 0.55},
	"smoked": {"base": PixelPalette.WOOD[2], "grain": 0.06, "rim": 0.6},
	"dark_walnut": {"base": PixelPalette.FLEECE[3], "grain": 0.08, "rim": 0.6},
	"charred": {"base": PixelPalette.WOOD[0], "grain": 0.04, "rim": 0.45},
}
## Patina is age: fresh wood is crisp; worn wood is polished on the high points; old wood is dulled,
## scratched and chipped at the rim; ancient wood is cracked, chipped more and dusty in the cuts. The
## cuts themselves never widen (w <= 1).
const PATINA := {
	"fresh": {"w": 0.85, "wear": 0.0},
	"worn": {"w": 0.95, "wear": 0.35},
	"old": {"w": 1.0, "wear": 0.6},
	"ancient": {"w": 1.0, "wear": 0.9},
}
## Extent of the drawing in mask units (the face is 2 units wide).
const HALF_W := MaskPixels.HALF_W
const TOP := MaskPixels.TOP
const BOTTOM := MaskPixels.BOTTOM


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var px := PixelFrame.px_for(self)
	var fd := float(PixelFrame.DEPTH) + 3.0 if show_halo else 0.0
	# the largest whole number of art pixels per mask unit that fits
	var unit := floorf(minf(size.x / px - fd * 2.0, size.y / px - fd * 2.0) / maxf(HALF_W * 2.0, BOTTOM - TOP))
	unit = maxf(unit, 3.0)
	var tex := MaskPixels.texture(spec, unit, show_kerchief, straps, highlight_part)
	var tsz := Vector2(tex.get_size()) * px
	var at := ((size - tsz) * 0.5 / px).floor() * px
	if show_halo:
		var r := Rect2(at, tsz).grow(fd * px)
		r.position.x = floorf((size.x - r.size.x) * 0.5 / px) * px
		r = Rect2(r.position, r.size)
		draw_rect(r, PixelPalette.NAVY[0])
		halo(self, at + Vector2(HALF_W, -TOP - 0.1) * unit * px, unit * px, r.grow(-float(PixelFrame.DEPTH) * px))
		PixelFrame.draw(self, r, px, "gold")
	draw_texture_rect(tex, Rect2(at, tsz), false)


## Firelight behind a mask centred at c, `s` screen pixels to the mask unit: stepped rings of ember
## glow on the art grid (the style's one kind of soft light: banded, not smooth).
static func halo(ci: CanvasItem, c: Vector2, s: float, clip := Rect2()) -> void:
	var px := maxf(1.0, roundf(s / 12.0)) if s < 36.0 else 3.0
	var rings := [[2.3, PixelPalette.FIRE[0], 0.35], [1.9, PixelPalette.FIRE[1], 0.3], [1.55, PixelPalette.FIRE[2], 0.22]]
	for ring in rings:
		var r: float = ring[0] * s
		var col: Color = ring[1]
		col.a = ring[2]
		var rows := int(ceil(r / px))
		for j in range(-rows, rows + 1):
			var y := float(j) * px
			var w := sqrt(maxf(0.0, r * r - y * y))
			w = floorf(w / px) * px
			if w > 0.0:
				var row := Rect2(Vector2(floorf(c.x / px) * px - w, floorf(c.y / px) * px + y), Vector2(w * 2.0, px))
				if clip.has_area():
					row = row.intersection(clip)
				if row.has_area():
					ci.draw_rect(row, col)


## The mask centred on c (its (0, 0) in mask units: between the eyes, a little below), `s` screen
## pixels to the mask unit. The art scale is picked from s (3 screen px to the art px on a big mask,
## down to 1 on a tiny one); detail is kept for compatibility (the pixel mask sets its own detail by
## size). kerchief: the cloth and strap round it; highlight: a part to ring in gold.
static func paint(ci: CanvasItem, c: Vector2, s: float, mask: Dictionary, detail := 2, kerchief := true, highlight := "", strap_id := "natural") -> void:
	var px := clampf(roundf(s / 12.0), 1.0, 3.0)
	var unit := maxf(2.0, roundf(s / px))
	var tex := MaskPixels.texture(mask, unit, kerchief, strap_id, highlight)
	var at := ((c - Vector2(HALF_W, -TOP) * unit * px) / px).floor() * px
	ci.draw_texture_rect(tex, Rect2(at, Vector2(tex.get_size()) * px), false)
