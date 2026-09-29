class_name LookArt
extends RefCounted
## The player's own look on a shared Mamuthone figure (FigureSprites): the carved mask they made, dark
## straps if they chose them, and the extra bells of the heavier bell sets (a second chest strap of
## bells for "village", more of them and big bells behind the far shoulder for "full"). Positions
## come from LookCells (tools/art/pixel/workshop.py, found in the figures.py renders).
##
## Drawn with the feet at `feet`, `px` screen pixels to the art pixel (1 inside a node already scaled
## by the art scale, as StopBackdrops.draw_figure is used):
##   LookArt.draw_back(ci, size, pose, feet, flip, bell_set, px)            before the figure
##   LookArt.draw_front(ci, size, pose, feet, flip, mask, straps, bell_set, px)   after it
## size "field" or "big"; pose "stand", "crouch", "air", "land". The mask is drawn only at "big" (at
## "field" the figure's own mask is two pixels of eye).

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := LookCells.DIR + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


static func draw_back(ci: CanvasItem, size: String, pose: String, feet: Vector2, flip: bool, bell_set: String, px := 1.0) -> void:
	_bells(ci, size, pose, feet, flip, bell_set, "back", px)


static func draw_front(ci: CanvasItem, size: String, pose: String, feet: Vector2, flip: bool, mask: Dictionary, straps: String, bell_set: String, px := 1.0) -> void:
	var key := "%s_%s" % [size, pose]
	ci.draw_set_transform(feet, 0.0, Vector2(-px if flip else px, px))
	if straps == "dark" and LookCells.STRAPS.has(key):
		var st := tex("straps_dark_" + key)
		if st != null:
			ci.draw_texture(st, Vector2(LookCells.STRAPS[key]))
	var extra: Array = LookCells.BELLS.get(size, {}).get(bell_set, [])
	if not extra.is_empty() and LookCells.YOKE.has(key):
		var yoke: Vector2 = LookCells.YOKE[key]
		var belt: Array = LookCells.BELT[size]
		_strap(ci, (yoke + belt[0]).round(), (yoke + belt[1]).round(), straps)
	ci.draw_set_transform(Vector2.ZERO)
	_bells(ci, size, pose, feet, flip, bell_set, "front", px)
	if size == "big" and LookCells.MASK.has(key):
		ci.draw_set_transform(feet, 0.0, Vector2(-px if flip else px, px))
		var r: Rect2i = LookCells.MASK[key]
		var unit := float(r.size.x - 1) / 2.0
		var mt := MaskPixels.texture(mask, unit, false, straps)
		# line the face's top up with the stamp's top and centre it on the stamp
		var face_top := (-1.34 - MaskPixels.TOP) * unit
		var at := Vector2(float(r.position.x) + float(r.size.x) * 0.5 - MaskPixels.HALF_W * unit, float(r.position.y) - face_top + 0.5).round()
		ci.draw_texture(mt, at)
		ci.draw_set_transform(Vector2.ZERO)


static func _bells(ci: CanvasItem, size: String, pose: String, feet: Vector2, flip: bool, bell_set: String, layer: String, px := 1.0) -> void:
	var key := "%s_%s" % [size, pose]
	var extra: Array = LookCells.BELLS.get(size, {}).get(bell_set, [])
	if extra.is_empty() or not LookCells.YOKE.has(key):
		return
	var yoke: Vector2 = LookCells.YOKE[key]
	ci.draw_set_transform(feet, 0.0, Vector2(-px if flip else px, px))
	for b in extra:
		if b[2] != layer:
			continue
		var t := tex("bell_" + str(b[0]))
		if t == null:
			continue
		var hang: Vector2i = LookCells.BELL_HANG[b[0]]
		# in the air the bells trail a little higher, on landing they swing low
		var lift := {"stand": 0.0, "crouch": 1.0, "air": -2.0, "land": 2.0}.get(pose, 0.0) as float
		ci.draw_texture(t, (yoke + (b[1] as Vector2) + Vector2(0, lift)).round() - Vector2(hang))
	ci.draw_set_transform(Vector2.ZERO)


## The second chest strap the belt bells hang from: two pixels of leather with a K0 edge.
static func _strap(ci: CanvasItem, a: Vector2, b: Vector2, straps: String) -> void:
	var lo: Color = PixelPalette.K[1] if straps == "dark" else PixelPalette.LEATHER[1]
	var hi: Color = PixelPalette.LEATHER[0] if straps == "dark" else PixelPalette.LEATHER[2]
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for s in n + 1:
		var p := a.lerp(b, float(s) / maxf(1.0, float(n))).round()
		ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), PixelPalette.K[0])
		ci.draw_rect(Rect2(p, Vector2.ONE), hi)
		ci.draw_rect(Rect2(p + Vector2(0, 1), Vector2.ONE), lo)
		ci.draw_rect(Rect2(p + Vector2(0, 2), Vector2.ONE), PixelPalette.K[0])
