class_name PixelFigure
extends Node2D
## A figure of the pixel look (tools/art/pixel3d/bake_ai_figures.py). On every beat it bobs as in
## Daniele's recording: the body drops in a snap while the feet stay planted, holds a moment and
## eases back up. Never a jump. Loose parts (bells, rope, head) swinging on their own showed holes
## and doubled edges where they moved (Daniele, 2026-10-08), so the body moves as one piece.
##
## The origin is the feet (the picture's bottom centre).

const DIR := "res://art/pixel/"
## The row (art px from the top) each figure is split at: the shins, just under the Mamuthone's
## fleece and the Issohadore's trousers, which drop over them (a cut higher shows its straight edge).
const KNEE := {"mamuthone": 146, "issohadore": 138}
const DROP := 6.0             ## how far the body drops on the beat, art px
const DOWN_T := 0.035         ## seconds the drop takes (a snap, but seen as a move, not a jump cut)
const HOLD_T := 0.06          ## ... it is at the bottom until this long after the beat
const BACK_T := 0.2           ## ... and back up by this long after the beat (easing out)
const RING_SWING := 22.0      ## degrees the painted figures' load swings when a bell is rung on time
const RING_HZ := 4.5
const RING_DAMP := 6.0
const RING_DIP := 2.0         ## art px the figure dips again when a bell is rung on time

var figure := "mamuthone"
var mirror := false
var reduced_motion := false
var _upper: Sprite2D
var _legs: Sprite2D
var _size := Vector2.ONE


func _init(p_figure := "mamuthone") -> void:
	figure = p_figure


## One picture of the whole figure, shown as two slices of itself: the legs stay planted and the
## rest drops over them on the beat, so the seam is always exact (nothing shows through, nothing
## doubles) and the drop reads as the knees giving. Every pixel stays the picture's own.
func _ready() -> void:
	var tex: Texture2D = load(DIR + "%s_whole.png" % figure)
	if tex == null:
		return
	_size = tex.get_size()
	var knee := float(KNEE.get(figure, roundi(_size.y * 0.7)))
	_legs = _slice(tex, "Legs", knee, _size.y)
	_upper = _slice(tex, "Upper", 0.0, knee)


func _slice(tex: Texture2D, n: String, top: float, bottom: float) -> Sprite2D:
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


## The figure's height in art px (its picture's).
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


## The swing (degrees) of the painted figures' load `age` seconds after a bell rung on time.
static func ring_swing(age: float) -> float:
	if age < 0.0 or age > 1.0:
		return 0.0
	return RING_SWING * sin(TAU * RING_HZ * age) * exp(-RING_DAMP * age)


## Poses the figure t seconds after the last beat (bar: the beat's place in its bar, kept for the
## callers). `ring`: seconds since a bell was rung on time, which dips the body again.
func pose(t: float, _bar: float, still := false, ring := 9.0, _ring_up := true) -> void:
	if _upper == null:
		return
	var m := 0.35 if reduced_motion else 1.0
	var d := 0.0 if still else drop_at(t) * DROP
	if not still and ring >= 0.0 and ring < 0.3:
		d = maxf(d, drop_at(ring) * RING_DIP)
	# whole art px, so the picture stays on its grid
	_upper.position = Vector2(0.0, roundf(d * m))
