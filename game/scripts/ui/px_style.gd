class_name PxStyle
extends StyleBox
## The one box of the menu kit (see UIKit's header): a pixel-stepped rounded rectangle drawn in code
## on the art grid, so every edge stays crisp next to the pixel art and every colour is a token.
##
## Integer pixels: one art pixel is `unit` canvas px, set by UIKit.apply_root() from the screen's real
## scale so that it is a WHOLE number of device pixels (3 canvas px on a 720-wide screen; 4 device px
## = 2.67 canvas px on a 1080-wide one, instead of an uneven 4.5). The box's origin snaps to device
## pixels too, so every stair of a corner is the same size on any phone. `px` > 0 overrides it.
##
## `grain`: an optional tile (1 texel = 1 art px) laid over the fill, e.g. the cards' fleece.
##
## Layers, back to front: the `lip` (the box's carved thickness, `lip` art px tall under the face, in
## `lip_color`), the face's `border` ring (`border_px` art px), the `fill`, a one-pixel `highlight`
## row along the top inside the ring and a `shade` row along its bottom. `sink` pushes the face down
## (a pressed button sits on its lip). `radius` is in art px; -1 makes a pill (half the height).
## Any colour with alpha 0 is skipped. The fields are exported so duplicate() (and variant()) keep them.

@export var fill := Color.TRANSPARENT
@export var border := Color.TRANSPARENT
@export var border_px := 1
@export var highlight := Color.TRANSPARENT
@export var shade := Color.TRANSPARENT
@export var lip := 0
@export var lip_color := Color.TRANSPARENT
@export var sink := 0
@export var radius := 3
@export var px := 0.0
@export var grain: Texture2D

## Canvas px per art px for the whole kit, and device px per canvas px (see the header).
static var unit := 3.0
static var device := 1.0


## Sets the kit's art pixel from the screen's device-px-per-canvas-px scale.
static func set_screen_scale(s: float) -> void:
	device = maxf(s, 0.01)
	unit = maxf(floorf(3.0 * device + 0.01), 1.0) / device


static func make(p_fill: Color, p_border := Color.TRANSPARENT, p_radius := 3, pad := Vector4(24, 18, 24, 18)) -> PxStyle:
	var s := PxStyle.new()
	s.fill = p_fill
	s.border = p_border
	s.radius = p_radius
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


## A copy with other colours / offsets (states of one button).
func variant(p_fill: Color, p_border: Color, p_highlight := Color.TRANSPARENT, p_sink := 0) -> PxStyle:
	var s: PxStyle = duplicate()
	s.fill = p_fill
	s.border = p_border
	s.highlight = p_highlight
	s.sink = p_sink
	if p_sink > 0:
		# the label goes down with the face
		s.content_margin_top += p_sink * 3.0
		s.content_margin_bottom -= p_sink * 3.0
	return s


## Insets of a stepped corner of radius r, one per row from the outside in (art px).
static func corner(r: int) -> PackedInt32Array:
	match r:
		0:
			return PackedInt32Array()
		1:
			return PackedInt32Array([1])
		2:
			return PackedInt32Array([2, 1])
		3:
			return PackedInt32Array([3, 1, 1])
		4:
			return PackedInt32Array([4, 2, 1, 1])
		5:
			return PackedInt32Array([5, 3, 2, 1, 1])
	var out := PackedInt32Array()
	for i in r:
		var dy := float(r - i) - 0.5
		out.append(clampi(roundi(float(r) - sqrt(maxf(float(r * r) - dy * dy, 0.0))), 0, r))
	return out


func _draw(ci: RID, rect: Rect2) -> void:
	var s := px if px > 0.0 else unit
	var aw := floori(rect.size.x / s + 0.001)
	var ah := floori(rect.size.y / s + 0.001)
	if aw <= 0 or ah <= 0:
		return
	var origin := ((rect.position + (rect.size - Vector2(aw, ah) * s) * 0.5) * device).round() / device
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(s, s), 0.0, origin))
	var face_h := ah - lip
	var r := _radius(aw, face_h)
	if lip > 0 and lip_color.a > 0.0:
		shape(ci, Rect2i(0, lip, aw, face_h), r, lip_color)
	var y := sink
	var outer := Rect2i(0, y, aw, face_h)
	var b := border_px if border.a > 0.0 else 0
	var inner := outer.grow(-b)
	var ri := maxi(r - b, 0)
	if b > 0:
		if fill.a >= 1.0:
			shape(ci, outer, r, border)
		else:
			ring(ci, outer, r, b, border)   # a see-through face: never paint under it
	if fill.a > 0.0 and inner.size.x > 0 and inner.size.y > 0:
		shape(ci, inner, ri, fill)
		if grain != null:
			_grain(ci, inner, ri)
	if inner.size.y > 2:
		var prof := corner(mini(ri, inner.size.y / 2))
		var top_in := prof[0] if prof.size() > 0 else 0
		if highlight.a > 0.0:
			_span(ci, inner.position.x + top_in, inner.position.y, inner.size.x - 2 * top_in, highlight)
		if shade.a > 0.0:
			_span(ci, inner.position.x + top_in, inner.end.y - 1, inner.size.x - 2 * top_in, shade)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


## Tiles `grain` over the straight middle of the face (the corner rows are too short to show it).
func _grain(ci: RID, r: Rect2i, rr: int) -> void:
	var band := Rect2i(r.position.x, r.position.y + rr, r.size.x, r.size.y - 2 * rr)
	var ts := Vector2i(grain.get_size())
	if band.size.y <= 0 or ts.x <= 0:
		return
	var mod := Color(1, 1, 1, fill.a)
	var y := 0
	while y < band.size.y:
		var h := mini(ts.y, band.size.y - y)
		var x := 0
		while x < band.size.x:
			var w := mini(ts.x, band.size.x - x)
			RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(band.position.x + x, band.position.y + y, w, h),
				grain.get_rid(), Rect2(0, 0, w, h), mod)
			x += w
		y += h


func _radius(w: int, h: int) -> int:
	var r := radius if radius >= 0 else h / 2
	return clampi(r, 0, mini(w, h) / 2)


func _span(ci: RID, x: int, y: int, w: int, c: Color) -> void:
	if w > 0:
		RenderingServer.canvas_item_add_rect(ci, Rect2(x, y, w, 1), c)


## Fills a stepped rounded rect (art px, inside the art transform).
static func shape(ci: RID, r: Rect2i, radius_px: int, c: Color) -> void:
	var rr := clampi(radius_px, 0, mini(r.size.x, r.size.y) / 2)
	var prof := corner(rr)
	if r.size.y - 2 * rr > 0:
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y + rr, r.size.x, r.size.y - 2 * rr), c)
	for i in rr:
		var inset := prof[i]
		var w := r.size.x - 2 * inset
		if w <= 0:
			continue
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + inset, r.position.y + i, w, 1), c)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x + inset, r.end.y - 1 - i, w, 1), c)


## The x range [start, end) of row `y` of a stepped rounded rect (local rows, 0 at its top).
static func span_of(r: Rect2i, radius_px: int, y: int) -> Vector2i:
	var rr := clampi(radius_px, 0, mini(r.size.x, r.size.y) / 2)
	var inset := 0
	if y < rr:
		inset = corner(rr)[y]
	elif y >= r.size.y - rr:
		inset = corner(rr)[r.size.y - 1 - y]
	return Vector2i(r.position.x + inset, r.end.x - inset)


## Only the frame of a stepped rounded rect, `b` art px thick.
static func ring(ci: RID, r: Rect2i, radius_px: int, b: int, c: Color) -> void:
	var inner := r.grow(-b)
	var ri := maxi(radius_px - b, 0)
	var rr := clampi(radius_px, 0, mini(r.size.x, r.size.y) / 2)
	var band := maxi(rr, b + ri)   # rows near the top and bottom that need a row-by-row frame
	for y in r.size.y:
		var o := span_of(r, radius_px, y)
		var iy := y - b
		if y >= band and y < r.size.y - band:
			continue
		if iy < 0 or iy >= inner.size.y or inner.size.x <= 0:
			RenderingServer.canvas_item_add_rect(ci, Rect2(o.x, r.position.y + y, o.y - o.x, 1), c)
			continue
		var i := span_of(inner, ri, iy)
		if i.x > o.x:
			RenderingServer.canvas_item_add_rect(ci, Rect2(o.x, r.position.y + y, i.x - o.x, 1), c)
		if o.y > i.y:
			RenderingServer.canvas_item_add_rect(ci, Rect2(i.y, r.position.y + y, o.y - i.y, 1), c)
	var mid := r.size.y - 2 * band
	if mid > 0:
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.position.x, r.position.y + band, b, mid), c)
		RenderingServer.canvas_item_add_rect(ci, Rect2(r.end.x - b, r.position.y + band, b, mid), c)


## The same shape painted into an Image at 1x (icons baked by the kit).
static func paint(img: Image, r: Rect2i, radius_px: int, c: Color) -> void:
	var rr := clampi(radius_px, 0, mini(r.size.x, r.size.y) / 2)
	var prof := corner(rr)
	for y in r.size.y:
		var inset := 0
		if y < rr:
			inset = prof[y]
		elif y >= r.size.y - rr:
			inset = prof[r.size.y - 1 - y]
		for x in range(inset, r.size.x - inset):
			var p := r.position + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				if c.a >= 1.0:
					img.set_pixelv(p, c)
				else:
					img.set_pixelv(p, img.get_pixelv(p).blend(c))
