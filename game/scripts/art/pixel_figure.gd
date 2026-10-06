class_name PixelFigure
extends Node2D
## A figure of the pixel look as a puppet: its parts (tools/art/pixel3d/bake_figures.py) slide,
## swing and squash on their own, so it moves smoothly instead of swapping drawings.
##
## On every beat the figure bobs as in Daniele's recording: the body drops at once and springs back
## within a tenth of a second while the feet stay planted (the legs squash under it). The head
## follows a moment later; the bells (the Mamuthone's) and the rope (the Issohadore's) are heavy and
## loose: they lag behind the drop, overshoot it and swing on their straps until the next beat. Over
## each bar the figure also leans a little from side to side, the parts at the back moving further
## than the ones in front, so the cut-outs read as a body in depth. Never a jump.
##
## The origin is the feet (bottom centre of every part's picture).

const DIR := "res://art/pixel/"
## name: [[part, pivot rule, depth], ...] back to front. Pivot rules: "feet" the bottom centre of the
## picture, "neck" the bottom centre of the part, "strap" the top centre of the part, "hand" its top
## right. Depth: how far behind (+) or in front (-) of the body the part is, for the sway.
const PARTS := {
	"mamuthone": [["legs", "feet", 0.0], ["body", "feet", 0.0], ["back_bells", "strap", 1.0], ["front_bells", "strap", -0.6], ["head", "neck", -0.2]],
	"issohadore": [["legs", "feet", 0.0], ["body", "feet", 0.0], ["rope", "hand", -0.7], ["head", "neck", -0.2]],
}
const DROP := 6.0             ## how far the body drops on the beat, art px
const LEGS_H := 0.32          ## the share of the figure's height the legs take (they squash)
const HEAD_LAG := 0.025       ## seconds the head follows the body late
const SWING_LAG := 0.04       ## ... the bells and the rope
const SWING := 10.0            ## degrees the bells and the rope swing after the drop
const SWING_HZ := 3.2         ## how fast they swing
const SWING_DAMP := 5.0       ## how fast the swing dies away
const RING_SWING := 22.0      ## degrees the load and the rope swing when a bell is rung on time
const RING_HZ := 4.5
const RING_DAMP := 6.0
const RING_THROW := 4.0       ## art px the load is thrown up (a tilt up) or down by the ring
const SWAY := 1.2             ## art px the figure leans across a bar
const SWAY_DEPTH := 1.6       ## extra art px for a part at depth 1

var figure := "mamuthone"
var mirror := false           ## leans toward the road on the left (false) or the right (true)
var reduced_motion := false
var _parts: Array = []        ## [Sprite2D, rule, depth, rest position]
var _size := Vector2.ONE


func _init(p_figure := "mamuthone") -> void:
	figure = p_figure


func _ready() -> void:
	for spec: Array in PARTS[figure]:
		var tex: Texture2D = load(DIR + "%s_%s.png" % [figure, spec[0]])
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.name = str(spec[0]).capitalize().replace(" ", "")
		s.texture = tex
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_size = tex.get_size()
		var pivot := _pivot(tex, str(spec[1]))
		# the picture stays where it is; only its pivot moves to the joint
		s.position = pivot
		s.offset = -_feet() - pivot
		add_child(s)
		_parts.append([s, str(spec[1]), float(spec[2]), pivot])


## The figure's height in art px (its pictures').
func art_height() -> float:
	return _size.y


## The feet in the pictures: the bottom centre, on a whole art px so the parts stay on the grid.
func _feet() -> Vector2:
	return Vector2(floorf(_size.x * 0.5), _size.y)


## The part's joint, relative to the feet (art px).
func _pivot(tex: Texture2D, rule: String) -> Vector2:
	var img := tex.get_image()
	var used := img.get_used_rect() if img != null else Rect2i(Vector2i.ZERO, Vector2i(_size))
	var feet := _feet()
	var p := feet
	match rule:
		"neck":
			p = Vector2(used.position.x + used.size.x * 0.5, used.end.y)
		"strap":
			p = Vector2(used.position.x + used.size.x * 0.5, used.position.y)
		"hand":
			p = Vector2(used.end.x, used.position.y)
	return p - feet


## Poses the puppet t seconds after the last beat; bar is the beat's place in its bar (0..4).
## The swing (degrees) of the load `age` seconds after a bell rung on time (0 when long gone).
static func ring_swing(age: float) -> float:
	if age < 0.0 or age > 1.0:
		return 0.0
	return RING_SWING * sin(TAU * RING_HZ * age) * exp(-RING_DAMP * age)


## `ring`: seconds since a bell was rung on time (the load is thrown `ring_up` and swings hard).
func pose(t: float, bar: float, still := false, ring := 9.0, ring_up := true) -> void:
	var m := 0.35 if reduced_motion else 1.0
	var d := 0.0 if still else StreetBackdrop._bob(t) * DROP * m
	var dh := 0.0 if still else StreetBackdrop._bob(t - HEAD_LAG) * DROP * 1.15 * m
	var ds := 0.0 if still else StreetBackdrop._bob(t - SWING_LAG) * DROP * 1.3 * m
	var ts := maxf(0.0, t - SWING_LAG)
	var swing := 0.0 if still else SWING * m * sin(TAU * SWING_HZ * ts) * exp(-SWING_DAMP * ts)
	if ring >= 0.0 and ring < 1.0:
		swing += ring_swing(ring) * m
		ds += (-1.0 if ring_up else 1.0) * RING_THROW * m * exp(-ring * 12.0) * sin(minf(ring * 30.0, PI * 0.5))
	var lean := sin(bar / 4.0 * TAU) * (0.0 if reduced_motion else 1.0)
	var toward := -1.0 if mirror else 1.0
	for e: Array in _parts:
		var s: Sprite2D = e[0]
		var rest: Vector2 = e[3]
		var depth: float = e[2]
		var x := lean * (SWAY + SWAY_DEPTH * depth)
		# every part slides by whole art px, so it stays crisp on the lens's grid; only the small
		# loose parts (bells, rope) turn as they swing
		match str(e[1]):
			"feet":
				if s.name == "Legs":
					s.position = rest
					s.scale = Vector2(1.0, 1.0 - roundf(d) / (_size.y * LEGS_H))
				else:
					s.position = rest + Vector2(roundf(x), roundf(d))
			"neck":
				s.position = rest + Vector2(roundf(x + toward * 0.4 * dh), roundf(dh))
			_:
				s.position = rest + Vector2(roundf(x), roundf(ds))
				s.rotation = deg_to_rad(swing) * toward
