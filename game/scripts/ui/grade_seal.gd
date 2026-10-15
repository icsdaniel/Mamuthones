class_name GradeSeal
extends GradeBadge
## The results' hero grade: the letter (F to S+, GradeBadge's colours and stamp) struck on a round
## bronze seal, like the face of a bell: a lit rim, eight studs, a dark well, drawn on the 3-px art
## grid. The full combo is not drawn here (the results give it its own ribbon). `diameter` is in art
## px; the letter is the big pixel face at `k` (2 fits a 60-art-px seal, 3 an 80-art-px one).

var diameter := 64
## The warm halo round the seal, 0 (none) to 1 (a flare); the results tween it.
var halo := 0.0:
	set(v):
		halo = v
		queue_redraw()
var _studs := true
## The eight studs round the rim (off for the small list seals, MenuKit.grade_mark).
var studs := true:
	set(v):
		studs = v
		_studs = v
		queue_redraw()


func _init(p_rank := -1, p_diameter := 64, p_k := 2) -> void:
	super(p_rank, true, false)
	diameter = p_diameter
	k = p_k


func _size() -> void:
	custom_minimum_size = Vector2(diameter, diameter) * PX


func _draw() -> void:
	var d := diameter
	var o := ((size - Vector2(d, d) * PX) * 0.5 / PX).floor()
	var cx := o.x + d * 0.5
	var cy := o.y + d * 0.5
	var r := d * 0.5
	var lit := rank >= Session.RANK_S
	if halo > 0.0:
		# stepped rings of firelight, fainter outward
		for j in 4:
			_disc(cx, cy, r + 12 - j * 3, Color(PixelPalette.FIRE[3 + mini(j, 2)], 0.07 * halo * (j + 1)))
	# the seal's edge in light and shade: shadow down-right, light up-left, the bronze over both
	_disc(cx + 1, cy + 2, r, PixelPalette.K[0])
	_disc(cx + 1, cy + 1, r, PixelPalette.GOLD[1])
	_disc(cx - 1, cy - 1, r, PixelPalette.GOLD[5] if lit else PixelPalette.GOLD[4])
	_disc(cx, cy, r - 0.5, PixelPalette.GOLD[3])
	# the rim's inner step and the well
	_disc(cx, cy, r - 4, PixelPalette.GOLD[1])
	_disc(cx + 0.5, cy + 0.5, r - 5, PixelPalette.GOLD[4] if lit else PixelPalette.GOLD[2])
	_disc(cx, cy, r - 5, PixelPalette.K[1])
	_disc(cx, cy + 1, r - 6.5, PixelPalette.FLEECE[1])
	if _studs:
		for i in 8:
			var a := TAU * i / 8.0 + TAU / 16.0
			var p := Vector2(cx + cos(a) * (r - 2.25), cy + sin(a) * (r - 2.25)).floor()
			draw_rect(Rect2(p * PX, Vector2(PX, PX) * 2.0), PixelPalette.GOLD[2])
			draw_rect(Rect2(p * PX, Vector2(PX, PX)), PixelPalette.GOLD[5])
	if rank < 0:
		draw_rect(Rect2(Vector2(cx - 4, cy) * PX, Vector2(8, 1) * PX), PixelPalette.BONE[1])
		return
	if _pop <= 0.0:
		return
	var kk := k
	if _pop < 0.85:
		kk = k + 1
	draw_letter(Vector2(cx, cy + 1) * PX, kk)


## A pixel disc of radius r (art px) centred on (cx, cy), row by row.
func _disc(cx: float, cy: float, r: float, c: Color) -> void:
	if r <= 0.0:
		return
	var top := floori(cy - r)
	var bottom := ceili(cy + r)
	for y in range(top, bottom):
		var dy := float(y) + 0.5 - cy
		if absf(dy) > r:
			continue
		var hw := sqrt(r * r - dy * dy)
		var x0 := roundi(cx - hw)
		var x1 := roundi(cx + hw)
		if x1 > x0:
			draw_rect(Rect2(Vector2(x0, y) * PX, Vector2(x1 - x0, 1) * PX), c)
