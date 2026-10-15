class_name GradeSeal
extends GradeBadge
## The results' hero grade: the letter (F to S+, GradeBadge's colours) struck on a round bronze seal,
## like the face of a bell: a lit rim, eight studs, a dark well. The seal's body is baked once per
## size and brightness (S and S+ get a hotter rim) into a 1-texel-per-art-px texture, drawn at the
## kit's art pixel (PxStyle.unit); each frame draws only the halo and the letter. The full combo is
## not drawn here (the results give it its own ribbon). `diameter` is in art px; the letter is the
## big pixel face at `k`.
##
## `animate(delay)` keeps the well dark until `delay`, then stamps the letter: it lands 1.4x large
## and settles to 1x in a quarter second, with a bell (and `stamped` for the screen's juice).

var diameter := 64
## The warm halo round the seal, 0 (none) to 1 (a flare); the results tween it.
var halo := 0.0:
	set(v):
		halo = v
		queue_redraw()
var _stamp := 1.0   ## the letter's scale while it lands
static var _bodies := {}


func _init(p_rank := -1, p_diameter := 64, p_k := 2) -> void:
	super(p_rank, true, false)
	diameter = p_diameter
	k = p_k


func _size() -> void:
	custom_minimum_size = Vector2(diameter, diameter) * PxStyle.unit


func animate(delay := 0.3, ring := true) -> void:
	if rank < 0:
		return
	_pop = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if ring:
			Sound.bell(BellSets.STANDARD, true, "perfect" if rank >= Session.RANK_S else "good")
		_pop = 1.0
		stamped.emit())
	if UIKit.reduced_motion():
		return
	_stamp = 1.4
	tw.tween_method(func(v: float) -> void:
		_stamp = v
		queue_redraw(), 1.4, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _draw() -> void:
	var u := PxStyle.unit
	var d := diameter
	var o := ((size - Vector2(d, d) * u) * 0.5 / u).floor()
	var c := (o + Vector2(d, d) * 0.5) * u
	if halo > 0.0:
		# stepped rings of firelight, fainter outward
		for j in 4:
			_disc(c / u, d * 0.5 + 12 - j * 3, Color(PixelPalette.FIRE[3 + mini(j, 2)], 0.07 * halo * (j + 1)), u)
	var lit := rank >= Session.RANK_S
	draw_texture_rect(body(d, lit), Rect2(o * u - Vector2(u, u) * 2.0, Vector2(d + 4, d + 4) * u), false)
	if rank < 0:
		draw_rect(Rect2(c - Vector2(4, 0) * u, Vector2(8, 1) * u), PixelPalette.BONE[1])
		return
	if _pop <= 0.0:
		return
	if _stamp != 1.0:
		draw_set_transform(c, 0.0, Vector2(_stamp, _stamp))
		draw_letter(Vector2(0, u), k)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_letter(c + Vector2(0, u), k)


## The seal's body for a diameter (art px), baked once: 2 art px of margin all round for the shadow.
static func body(d: int, lit: bool) -> Texture2D:
	var key := "%d_%s" % [d, lit]
	if _bodies.has(key):
		return _bodies[key]
	var img := Image.create(d + 4, d + 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 2.0 + d * 0.5
	var cy := 2.0 + d * 0.5
	var r := d * 0.5
	# the seal's edge in light and shade: shadow down-right, light up-left, the bronze over both
	_paint(img, cx + 1, cy + 2, r, PixelPalette.K[0])
	_paint(img, cx + 1, cy + 1, r, PixelPalette.GOLD[1])
	_paint(img, cx - 1, cy - 1, r, PixelPalette.GOLD[5] if lit else PixelPalette.GOLD[4])
	_paint(img, cx, cy, r - 0.5, PixelPalette.GOLD[3])
	# the rim's inner step and the well
	_paint(img, cx, cy, r - 4, PixelPalette.GOLD[1])
	_paint(img, cx + 0.5, cy + 0.5, r - 5, PixelPalette.GOLD[4] if lit else PixelPalette.GOLD[2])
	_paint(img, cx, cy, r - 5, PixelPalette.K[1])
	_paint(img, cx, cy + 1, r - 6.5, PixelPalette.FLEECE[1])
	for i in 8:
		var a := TAU * i / 8.0 + TAU / 16.0
		var p := Vector2i(Vector2(cx + cos(a) * (r - 2.25), cy + sin(a) * (r - 2.25)).floor())
		for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			img.set_pixelv(p + q, PixelPalette.GOLD[2])
		img.set_pixelv(p, PixelPalette.GOLD[5])
	_bodies[key] = ImageTexture.create_from_image(img)
	return _bodies[key]


static func _paint(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(floori(cy - r), ceili(cy + r)):
		var dy := float(y) + 0.5 - cy
		if absf(dy) > r or y < 0 or y >= img.get_height():
			continue
		var hw := sqrt(r * r - dy * dy)
		for x in range(maxi(roundi(cx - hw), 0), mini(roundi(cx + hw), img.get_width())):
			img.set_pixel(x, y, c)


## A pixel disc of radius r (art px) centred on c (art px), row by row, at u canvas px per art px.
func _disc(c: Vector2, r: float, col: Color, u: float) -> void:
	for y in range(floori(c.y - r), ceili(c.y + r)):
		var dy := float(y) + 0.5 - c.y
		if absf(dy) > r:
			continue
		var hw := sqrt(r * r - dy * dy)
		var x0 := roundi(c.x - hw)
		var x1 := roundi(c.x + hw)
		if x1 > x0:
			draw_rect(Rect2(Vector2(x0, y) * u, Vector2(x1 - x0, 1) * u), col)
