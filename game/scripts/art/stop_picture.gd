@tool
class_name StopPicture
extends Control
## A story stop's picture, alive: the pixel world of that stop (StopBackdrops) cropped to its card, at
## a whole-number scale so the pixels stay square. The flames flicker and flare on a gentle beat, sparks
## rise, smoke drifts, the glow breathes, and the card's Mamuthones jump on the beat the way the row
## does: a crouch, a slow rise, a fast fall, landing on it.
##
##   stop       1..7
##   view       "card": the card's crop, as big as fits (letterboxed; with `px` set, at that scale and
##              cropped about the card's centre when it does not fit); "band": a strip of the world
##              `px` art pixels to the screen pixel (0 = pick from the width), centred on `focus`
##   focus      band centre in world art pixels (default: the card's centre)
##   bpm        the gentle beat (half the song's tempo is a good value)
##   veiled     locked: the picture sits under a night veil (a dither of K0), with no life in it
##   animate    false: a still (reduced motion, thumbnails)

@export_range(1, 7) var stop := 1:
	set(v):
		stop = clampi(v, 1, StopBackdrops.COUNT)
		_relayout()
@export_enum("card", "band") var view := "card":
	set(v):
		view = v
		_relayout()
@export var px := 0:
	set(v):
		px = v
		_relayout()
@export var focus := Vector2(-1, -1):
	set(v):
		focus = v
		_relayout()
@export var bpm := 66.0
@export var veiled := false:
	set(v):
		veiled = v
		_redraw()
## "" no frame, else a PixelFrame style ("gold", "bright", "dim") drawn round the picture.
@export var frame_style := "":
	set(v):
		frame_style = v
		_relayout()
## false: the world without its figures (a backdrop for someone else's figure).
@export var show_cast := true:
	set(v):
		show_cast = v
		_redraw()
## Sink the scenery half into the dark (a dither of K0 over it) so a figure drawn on top stands out;
## the fire and its glow stay bright.
@export var dim := false:
	set(v):
		dim = v
		_redraw()
@export var animate := true:
	set(v):
		animate = v
		set_process(v)
		_redraw()

## The crop being shown (world art pixels) and the scale in use, after layout.
var crop := Rect2()
var scale_px := 1
var _t := 0.0
var _back: Node2D
var _glow: Node2D
var _fig: Node2D
var _frame: _Layer
var _frame_rect := Rect2()
static var _veil: ImageTexture


class _Layer:
	extends Node2D
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = _Layer.new()
	_back.painter = _paint_back
	add_child(_back)
	_glow = _Layer.new()
	_glow.painter = _paint_glow
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_fig = _Layer.new()
	_fig.painter = _paint_front
	add_child(_fig)
	_frame = _Layer.new()
	_frame.painter = _paint_frame
	add_child(_frame)
	for n in [_back, _glow, _fig]:
		n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Each picture starts at its own moment, so a list of them does not flicker in step.
	_t = WoodcutDraw.hash01(get_instance_id() % 997, 3) * 10.0


func _ready() -> void:
	resized.connect(_relayout)
	_relayout()
	set_process(animate)


func _process(delta: float) -> void:
	_t += minf(delta, 0.1)
	_redraw()


func _redraw() -> void:
	if _back == null:
		return
	_back.queue_redraw()
	_glow.queue_redraw()
	_fig.queue_redraw()
	_frame.queue_redraw()


func _relayout() -> void:
	if _back == null:
		return
	var d := StopBackdrops.data(stop)
	var card_pos: Vector2i = d.card
	var card := Rect2(Vector2(card_pos), Vector2(StopCells.CARD))
	var ws := StopBackdrops.world_size()
	var fd := float(PixelFrame.DEPTH) if frame_style != "" else 0.0
	if view == "card":
		scale_px = maxi(1, int(floor(minf(size.x / (card.size.x + fd * 2.0), size.y / (card.size.y + fd * 2.0)))))
		crop = card
		if px > 0 and scale_px < px:
			# A fixed scale that the whole card does not fit: show as much of it as fits, about its
			# centre (or `focus`), never beyond the card.
			scale_px = px
			var room := ((size / float(px)) - Vector2(fd, fd) * 2.0).floor().min(card.size)
			var cc := focus if focus.x >= 0.0 else card.get_center()
			var p0 := (cc - room * 0.5).round()
			p0.x = clampf(p0.x, card.position.x, card.end.x - room.x)
			p0.y = clampf(p0.y, card.position.y, card.end.y - room.y)
			crop = Rect2(p0, room)
	else:
		scale_px = px if px > 0 else maxi(1, int(round(size.x / card.size.x)))
		var vs := ((size / float(scale_px)) - Vector2(fd, fd) * 2.0).ceil()
		var c := focus if focus.x >= 0.0 else card.get_center()
		var pos := (c - vs * 0.5).round()
		pos.x = clampf(pos.x, 0.0, maxf(0.0, ws.x - vs.x))
		pos.y = clampf(pos.y, 0.0, maxf(0.0, ws.y - vs.y))
		crop = Rect2(pos, vs.min(ws))
	# Centre the crop in the control, on whole screen pixels.
	var shown := crop.size * float(scale_px)
	var off := ((size - shown) * 0.5).floor()
	for n in [_back, _glow, _fig]:
		n.position = off
		n.scale = Vector2(scale_px, scale_px)
	_frame_rect = Rect2(off, shown).grow(fd * float(scale_px))
	if view == "band":
		_frame_rect = Rect2(Vector2.ZERO, size)
	_redraw()


## The time on the gentle beat (beats), for tests and for syncing.
func beat() -> float:
	return _t * bpm / 60.0


func _origin() -> Vector2:
	return -crop.position


func _paint_back(ci: CanvasItem) -> void:
	var o := _origin()
	StopBackdrops.draw_layer(ci, stop, "bg", o, crop)
	if veiled:
		_paint_veil(ci)
		return
	if dim:
		_paint_veil(ci)
	var ph := fposmod(beat(), 1.0)
	var t := _t if animate else 0.0
	StopBackdrops.draw_fires(ci, stop, o, t, 1.0 if (animate and ph < 0.14 and int(floor(beat())) % 2 == 0) else 0.0)
	StopBackdrops.draw_layer(ci, stop, "mid", o, crop)
	if animate:
		StopBackdrops.draw_smoke(ci, stop, o, t)
		StopBackdrops.draw_sparks(ci, stop, o, t, 1.0 - smoothstep(0.0, 0.5, ph), crop)


func _paint_glow(ci: CanvasItem) -> void:
	if veiled:
		return
	var ph := fposmod(beat(), 1.0)
	var k := 0.75 + (0.4 * pow(1.0 - ph, 3.0) if animate else 0.1)
	StopBackdrops.draw_glows(ci, stop, _origin(), k)


func _paint_front(ci: CanvasItem) -> void:
	var o := _origin()
	if veiled:
		return
	var d := StopBackdrops.data(stop)
	if not show_cast:
		StopBackdrops.draw_layer(ci, stop, "front", o, crop)
		return
	var cast: Array = d.cast.duplicate()
	# far figures first, then by depth
	cast.sort_custom(func(a, b): return [not str(a[4]).begins_with("half"), int(a[2])] < [not str(b[4]).begins_with("half"), int(b[2])])
	var b := beat()
	for i in cast.size():
		var c: Array = cast[i]
		var sprite: String = c[0]
		var variant: String = c[4]
		var feet := o + Vector2(int(c[1]), int(c[2]))
		if animate and sprite.begins_with("mamuthone_"):
			var j := jump(b - 0.045 * float(i) - 0.2 * WoodcutDraw.hash01(i, stop))
			sprite = StopBackdrops.with_pose(sprite, j.pose)
			feet.y -= roundf(j.lift * (0.5 if variant.begins_with("half") else 1.0))
		StopBackdrops.draw_figure(ci, sprite, variant, feet, bool(c[3]))
	if not d.rope.is_empty():
		_paint_rope(ci, o, d.rope)
	StopBackdrops.draw_layer(ci, stop, "front", o, crop)


## The heavy Mamuthone jump on a beat that lands on the whole number: land (squash) just after it,
## stand, crouch (anticipation), then a slow rise and a fast fall. Returns {pose, lift (art px)}.
static func jump(b: float, height := 5.0) -> Dictionary:
	var p := fposmod(b, 1.0)
	if p < 0.12:
		return {"pose": "land", "lift": 0.0}
	if p < 0.5:
		return {"pose": "stand", "lift": 0.0}
	if p < 0.64:
		return {"pose": "crouch", "lift": 0.0}
	var q := (p - 0.64) / 0.36
	var h := sin(minf(q / 0.62, 1.0) * PI * 0.5) if q < 0.62 else cos((q - 0.62) / 0.38 * PI * 0.5)
	return {"pose": "air", "lift": height * h}


func _paint_rope(ci: CanvasItem, o: Vector2, pts: Array) -> void:
	# The soha: a K0 underside, hemp in two tones, drawn pixel by pixel along the points.
	var cols := [PixelPalette.K[0], PixelPalette.ROPE[1], PixelPalette.ROPE[2]]
	for k in 3:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var bb: Vector2 = pts[i + 1]
			var n := int(maxf(absf(bb.x - a.x), absf(bb.y - a.y)))
			for s in n + 1:
				var p := a.lerp(bb, float(s) / maxf(1.0, float(n))).round() + Vector2(0, -k)
				ci.draw_rect(Rect2(o + p, Vector2(2 if k == 0 else 1, 1)), cols[k])


func _paint_veil(ci: CanvasItem) -> void:
	if _veil == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.set_pixel(0, 0, PixelPalette.K[0])
		img.set_pixel(1, 1, PixelPalette.K[0])
		_veil = ImageTexture.create_from_image(img)
	ci.draw_texture_rect(_veil, Rect2(Vector2.ZERO, crop.size), true)


func _paint_frame(ci: CanvasItem) -> void:
	if frame_style != "":
		PixelFrame.draw(ci, _frame_rect, float(scale_px), frame_style)
