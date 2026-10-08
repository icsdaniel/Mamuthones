class_name PixelFigure
extends Node2D
## A figure of the pixel look (tools/art/pixel3d/bake_ai_figures.py), bobbing in pieces. On every
## beat it bobs as in Daniele's recording: the body drops in a snap while the feet stay planted,
## holds a moment and eases back up. Never a jump. The loose pieces ride on it: the head follows a
## moment late, the bells (the Mamuthone's) and the coil of rope (the Issohadore's) lag the drop,
## overshoot it and settle, swinging a little toward the road.
##
## Kept clean (Daniele, 2026-10-08): the pieces are cut from the one finished picture, so at rest they
## put it back together exactly; the body has what they cover painted in, and each piece is pinned
## to its joint, never more than a couple of pixels off it, so a moving piece shows the body behind
## it, never a hole, a doubled edge or a piece drifting away. Everything moves by whole art px.
##
## The origin is the feet (the pictures' bottom centre).

const DIR := "res://art/pixel/"
## The row (art px from the top) each figure's body is split at: the shins, just under the
## Mamuthone's fleece and the Issohadore's trousers, which drop over them (a cut higher shows its
## straight edge). Every piece is above it.
const KNEE := {"mamuthone": 146, "issohadore": 138}
## name: [[piece, lag (s), swing (art px), across (art px)], ...] back to front.
const PIECES := {
	"mamuthone": [["back_bells", 0.05, 2.0, 1.0], ["front_bells", 0.035, 2.0, 1.0], ["head", 0.03, 1.0, 0.0]],
	"issohadore": [["rope", 0.04, 2.0, 1.0], ["head", 0.03, 1.0, 0.0]],
}
const REACH := 2.0            ## art px a piece may be off its joint, at most (the body is painted that far behind it)
const DROP := 6.0             ## how far the body drops on the beat, art px
const DOWN_T := 0.035         ## seconds the drop takes (a snap, but seen as a move, not a jump cut)
const HOLD_T := 0.06          ## ... it is at the bottom until this long after the beat
const BACK_T := 0.2           ## ... and back up by this long after the beat (easing out)
const SWING_HZ := 3.5         ## how fast a loose piece swings after the drop
const SWING_DAMP := 6.0       ## how fast the swing dies away
const RING_SWING := 22.0      ## degrees the painted figures' load swings when a bell is rung on time
const RING_HZ := 4.5
const RING_DAMP := 6.0
const RING_DIP := 2.0         ## art px the body dips again when a bell is rung on time

var figure := "mamuthone"
var mirror := false           ## the road is to the left (true) or the right (false)
var reduced_motion := false
var _upper: Sprite2D
var _legs: Sprite2D
var _pieces: Array = []       ## [Sprite2D, lag, swing, across]
var _size := Vector2.ONE


func _init(p_figure := "mamuthone") -> void:
	figure = p_figure


## The body as two slices of its picture (the legs stay planted, the rest drops over them, so the
## seam is always exact), then the pieces over it.
func _ready() -> void:
	var tex: Texture2D = load(DIR + "%s_body.png" % figure)
	if tex == null:
		return
	_size = tex.get_size()
	var knee := float(KNEE.get(figure, roundi(_size.y * 0.7)))
	_legs = _sprite(tex, "Legs", knee, _size.y)
	_upper = _sprite(tex, "Upper", 0.0, knee)
	for spec: Array in PIECES.get(figure, []):
		var pt: Texture2D = load(DIR + "%s_%s.png" % [figure, spec[0]])
		if pt != null:
			_pieces.append([_sprite(pt, str(spec[0]).capitalize().replace(" ", ""), 0.0, _size.y), spec[1], spec[2], spec[3]])


func _sprite(tex: Texture2D, n: String, top: float, bottom: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.region_enabled = true
	s.region_rect = Rect2(0.0, top, _size.x, bottom - top)
	# the origin is the feet, the bottom centre on a whole art px
	s.offset = Vector2(-floorf(_size.x * 0.5), top - _size.y)
	add_child(s)
	return s


## The figure's height in art px (its pictures').
func art_height() -> float:
	return _size.y


## How far down the body is (1 = the full drop) t seconds after the beat: down in a snap, a moment
## at the bottom, then easing back up.
static func drop_at(t: float) -> float:
	if t < 0.0 or t >= BACK_T:
		return 0.0
	if t < DOWN_T:
		var x := t / DOWN_T
		return x * (2.0 - x)
	if t < HOLD_T:
		return 1.0
	var y := (t - HOLD_T) / (BACK_T - HOLD_T)
	return (1.0 - y) * (1.0 - y)


## A loose piece's swing on its joint t seconds after the beat (1 at its widest): it lags the drop
## (up), overshoots it (down) and settles.
static func swing_at(t: float) -> float:
	if t < 0.0 or t > 1.0:
		return 0.0
	return -sin(TAU * SWING_HZ * t) * exp(-SWING_DAMP * t)


## The swing (degrees) of the painted figures' load `age` seconds after a bell rung on time.
static func ring_swing(age: float) -> float:
	if age < 0.0 or age > 1.0:
		return 0.0
	return RING_SWING * sin(TAU * RING_HZ * age) * exp(-RING_DAMP * age)


## Poses the figure t seconds after the last beat (bar: the beat's place in its bar, kept for the
## callers). `ring`: seconds since a bell was rung on time: the body dips again and the pieces are
## thrown up (a tilt up) or down.
func pose(t: float, _bar: float, still := false, ring := 9.0, ring_up := true) -> void:
	if _upper == null:
		return
	var m := 0.35 if reduced_motion else 1.0
	var d := 0.0 if still else drop_at(t) * DROP
	var rung := not still and ring >= 0.0 and ring < 1.0
	if rung:
		d = maxf(d, drop_at(ring) * RING_DIP)
	# whole art px, so the pictures stay on their grid
	var body := roundf(d * m)
	_upper.position = Vector2(0.0, body)
	var toward := -1.0 if mirror else 1.0
	for e: Array in _pieces:
		var s: Sprite2D = e[0]
		var lag: float = e[1]
		var amp: float = e[2]
		var across: float = e[3]
		var w := 0.0 if still else swing_at(t - lag)
		if rung:
			w += swing_at(ring) * (1.0 if ring_up else -1.0)
		# pinned: never further off its joint than the body is painted behind it
		var dy := clampf(roundf(w * amp * m), -REACH, REACH)
		var dx := clampf(roundf(w * across * m * toward), -REACH, REACH)
		s.position = Vector2(dx, body + dy)
