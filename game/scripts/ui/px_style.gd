class_name PxStyle
extends StyleBox
## The one box of the menu kit (see UIKit's header): a pixel-stepped rounded rectangle drawn in code
## on the art grid (one art pixel = `px` screen px, 3 on the 720 base), so every edge stays crisp next
## to the pixel art and every colour is a token, not a texture.
##
## Layers, back to front: the `lip` (the box's carved thickness, `lip` art px tall under the face, in
## `lip_color`), the face's `border` ring (`border_px` art px), the `fill`, a one-pixel `highlight`
## row along the top inside the ring and a `shade` row along its bottom. `sink` pushes the face down
## (a pressed button sits on its lip). `radius` is in art px; -1 makes a pill (half the height).
## Any colour with alpha 0 is skipped.

var fill := Color.TRANSPARENT
var border := Color.TRANSPARENT
var border_px := 1
var highlight := Color.TRANSPARENT
var shade := Color.TRANSPARENT
var lip := 0
var lip_color := Color.TRANSPARENT
var sink := 0
var radius := 3
var px := 3.0


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
		s.content_margin_top += p_sink * px
		s.content_margin_bottom -= p_sink * px
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
	var s := px
	var aw := floori(rect.size.x / s)
	var ah := floori(rect.size.y / s)
	if aw <= 0 or ah <= 0:
		return
	var origin := (rect.position + (rect.size - Vector2(aw, ah) * s) * 0.5).round()
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
	if inner.size.y > 2:
		var prof := corner(mini(ri, inner.size.y / 2))
		var top_in := prof[0] if prof.size() > 0 else 0
		if highlight.a > 0.0:
			_span(ci, inner.position.x + top_in, inner.position.y, inner.size.x - 2 * top_in, highlight)
		if shade.a > 0.0:
			_span(ci, inner.position.x + top_in, inner.end.y - 1, inner.size.x - 2 * top_in, shade)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)


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
