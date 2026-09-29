class_name FireBackdrop
extends Control
## The night behind the road on the play screen, in pixel art ("Bonfire Night", docs/art-style.md):
## a starry sky over the mountains and the houses of Mamoiada with the church tower, the crowd at the
## edge of the square, the great bonfire where the road ends, iron braziers at the square's sides,
## and the square's cobbles, warm near the fire and cool and mossy away from it.
##
## Everything sits on one art grid anchored on the road's far end (1 art px = PxArt.PX screen px).
## The sky strip and the square are baked pictures (tools/art/pixel/scenery.py) drawn through
## PxArt's light shader: on every beat the fire's light pulses out over the cobbles and the house
## fronts as a dither of their lit twins, bigger on the bar's downbeat; the braziers pool their own
## light; a low fire (dim, the player's health) swaps them toward their dim twins.
##
## The play screen sets `lanes` once (the backdrop lines up with the road's far end) and `beat`
## every frame; `dim` 0..1 while health is low.

const STRIP := "play_strip"
const GROUND := "play_ground"
const STRIP_FAR_ROW := 68          ## the strip's row on the road's far end
const GROUND_FIRE := Vector2(0.0, -6.0)   ## the fire relative to the ground picture's top centre (art px)

var lanes: LaneView
var beat := -1000.0
## 0..1: the bonfire dims and burns lower (the play screen sets it while health is low).
var dim := 0.0
var reduced_motion := false

var _strip: PxArt.Picture
var _ground: PxArt.Picture
var _fire: Bonfire
var _braziers: Array[Brazier] = []
var _clock := 0.0
var _kick := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	PxArt.nearest(self)
	_ground = PxArt.Picture.new(GROUND)
	_ground.name = "Square"
	add_child(_ground)
	_strip = PxArt.Picture.new(STRIP)
	_strip.name = "Village"
	add_child(_strip)
	for i in 4:
		var b := Brazier.new()
		b.name = "Brazier%d" % i
		b.seed = float(i) + 1.0
		b.flip = i % 2 == 1
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(b)
		_braziers.append(b)
	_fire = Bonfire.new()
	_fire.name = "Bonfire"
	_fire.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fire)
	reduced_motion = UIKit.reduced_motion()


## 0..1 on the beat, falling away through it (0 before the music).
func pulse() -> float:
	return 1.0 - fposmod(beat, 1.0) if beat >= 0.0 else 0.0


## The bonfire leaps now, beyond its beat (a stomp: 1 for both thumbs, about 0.4 for one), and its
## light swells over the square with it.
func kick(amount := 1.0) -> void:
	if _fire != null:
		_fire.kick(amount)
	_kick = maxf(_kick, amount)


## The road's far end in this control's coordinates: [centre, width].
func far_end() -> Array:
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var r := lanes.far_end()
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var a := xf * r.position
		var b := xf * (r.position + Vector2(r.size.x, 0.0))
		return [Vector2((a.x + b.x) * 0.5, a.y), b.x - a.x]
	return [Vector2(size.x * 0.5, size.y * 0.13), size.x * 0.42]


## Scale of the world (1 on the 720-wide base screen).
func ref_scale() -> float:
	return size.x / 720.0


## The art grid's origin: the far end's centre.
func grid_origin() -> Vector2:
	return far_end()[0]


func _process(delta: float) -> void:
	_clock += delta
	var g := grid_origin()
	var px := PxArt.PX
	_kick = maxf(0.0, _kick - delta * 2.4)
	var env := (PxArt.beat_env(beat, 0.5, 0.6, 0.16) + _kick * 0.8) * (0.35 if reduced_motion else 1.0)
	var flick := 0.5 + 0.5 * sin(_clock * 9.3) * sin(_clock * 5.7 + 1.3)
	# The village strip, its far-end row on the far end.
	var st := PxArt.scenery(STRIP)
	if st != null:
		_strip.origin = g + Vector2(-st.get_width() / 2, -STRIP_FAR_ROW) * px
		var m := _strip.mat
		m.set_shader_parameter("fire", Vector2(st.get_width() / 2, STRIP_FAR_ROW - 14))
		m.set_shader_parameter("fire_r", Vector2(78.0, 46.0) * (1.0 + 0.35 * maxf(env, 0.0)))
		m.set_shader_parameter("pulse", maxf(env, 0.0) * 0.9)
		m.set_shader_parameter("glow", 0.12 + 0.12 * flick)
		m.set_shader_parameter("dim", dim)
		_strip.queue_redraw()
	# The square: the ground picture hangs from the far end, centred on the fire.
	var gt := PxArt.scenery(GROUND)
	if gt != null:
		var origin := g + Vector2(-gt.get_width() / 2, 0) * px
		_ground.origin = origin
		var m2 := _ground.mat
		m2.set_shader_parameter("fire", Vector2(gt.get_width() / 2, 0) + GROUND_FIRE)
		m2.set_shader_parameter("fire_r", Vector2(150.0, 150.0) * (0.85 + 0.45 * maxf(env, 0.0)))
		m2.set_shader_parameter("pulse", maxf(env, 0.0) * 0.85)
		m2.set_shader_parameter("glow", 0.2 + 0.15 * flick)
		m2.set_shader_parameter("dim", dim)
		var lamps: Array = []
		for b in _braziers:
			if not b.visible:
				continue
			var l := b.light()
			var c: Vector2 = (l[0] - origin) / px
			lamps.append(Vector4(c.x, c.y + 10.0, float(l[1]), float(l[2])))
		m2.set_shader_parameter("lamp_count", lamps.size())
		while lamps.size() < 6:
			lamps.append(Vector4.ZERO)
		m2.set_shader_parameter("lamps", lamps)
		_ground.queue_redraw()
	# The bonfire on the far end, the braziers at the square's sides.
	_fire.root = g
	_fire.px = px
	_fire.beat = beat
	_fire.low = dim
	_fire.reduced_motion = reduced_motion
	_fire.sparks_top = g.y - 60.0 * px
	_place_braziers(g)
	for b in _braziers:
		b.beat = beat
		b.low = dim
		b.reduced_motion = reduced_motion
	queue_redraw()


## Two braziers at the back corners of the square (beside the crowd) and two near the front, at the
## screen's edges where the road leaves room for them.
func _place_braziers(g: Vector2) -> void:
	var px := PxArt.PX
	var half := 7.0 * px           ## half a brazier's width, screen px
	var left := 0.0
	var right := size.x
	# back pair: at the screen edges, a little down from the far end
	var yb := PxArt.snap(g.y + 34.0 * px, g.y)
	_braziers[0].feet = Vector2(PxArt.snap(left + half + px * 2.0, g.x), yb)
	_braziers[1].feet = Vector2(PxArt.snap(right - half - px * 2.0, g.x), yb)
	# front pair: as low as the road leaves room for a brazier between it and the screen's edge
	var yf := -1.0
	if lanes != null and lanes.is_inside_tree():
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var inv := xf.affine_inverse()
		var f := lanes.field_rect()
		var y := f.end.y - f.size.y * 0.16
		while y > f.position.y + f.size.y * 0.45:
			var e := lanes.road_edges(y)
			var el := (xf * Vector2(e.x, y)).x
			if el - left >= half * 2.0 + px * 4.0:
				yf = (xf * Vector2(0.0, y)).y
				break
			y -= px * 4.0
	for i in [2, 3]:
		_braziers[i].visible = yf > 0.0
	if yf > 0.0:
		var yy := PxArt.snap(yf, g.y)
		_braziers[2].feet = Vector2(PxArt.snap(left + half + px, g.x), yy)
		_braziers[3].feet = Vector2(PxArt.snap(right - half - px, g.x), yy)


## Above the strip: the sky's darkest navy up to the screen's top (under a notch).
func _draw() -> void:
	var st := PxArt.scenery(STRIP)
	var top := grid_origin().y - STRIP_FAR_ROW * PxArt.PX
	draw_rect(Rect2(Vector2.ZERO, size), PixelPalette.K[1])
	if st != null and top > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, top + 1.0), PixelPalette.NIGHT[0])
