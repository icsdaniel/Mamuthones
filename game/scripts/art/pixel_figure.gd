class_name PixelFigure
extends Node2D
## A figure of the pixel look (tools/art/pixel3d/bake_ai_figures.py), bobbing in pieces, timed on
## the Rift of the NecroDancer clip Daniele sent (StreetBackdrop._bob): on the beat the body drops at
## once while the feet stay planted, holds a frame and is back up 0.1 s after the beat. Never a jump.
## The head nods deeper than the body and comes back a moment after it; the Mamuthone's bells and the
## Issohadore's coil of rope are heavy: they fall a moment late, come back up late and swing a pixel
## out toward the road while they are low.
##
## Kept clean (Daniele, 2026-10-08): the pieces are cut from the one finished picture, so at rest they
## put it back together exactly; the body has what they cover filled in with the picture around it
## (mirrored, so the fleece's strands carry on instead of a dark smudge trailing the piece), and
## each piece stays within a few pixels of its joint. Every move follows one smooth curve on whole
## art px, never shaking back and forth.
##
## The origin is the feet (the pictures' bottom centre).

const DIR := "res://art/pixel/"
## Pieces drawn with pxl (tools/art/pxl/art/<figure>.px.js) take the place of the older pictures of
## the same name where they exist.
const PXL_DIR := "res://art/pxl/"
## The row (art px from the top) each figure's body is split at: the shins, just under the
## Mamuthone's fleece and the Issohadore's trousers, which drop over them (a cut higher shows its
## straight edge). Every piece is above it.
const KNEE := {"mamuthone": 146, "issohadore": 138}
## name: [[piece, kind], ...] back to front. Kinds: "head" nods, "load" swings.
const PIECES := {
	"mamuthone": [["back_bells", "load"], ["front_bells", "load"], ["head", "head"]],
	"issohadore": [["rope", "load"], ["head", "head"]],
}
const DROP := 8.0             ## art px the body drops on the beat (about 5% of the figure, as in the clip)
const NOD := 3.0              ## art px the head drops further than the body
const HEAD_LAG := 0.033       ## seconds the head stays down after the body starts back up
const LOAD_LAG := 0.033       ## seconds the bells and the rope fall and rise late
const REACH := 3.0            ## art px a piece may be off its joint at all (bake_ai_figures.py fills 4 behind it)
const LOAD_OFF := 2.0         ## art px they can be off their straps, at most
const LOAD_OUT := 1.0         ## art px they swing out toward the road while low
const RING_THROW := 2.0       ## art px the load is thrown up (a tilt up) or down when a bell is rung on time
const RING_SWING := 22.0      ## degrees the painted figures' load swings when a bell is rung on time
const RING_HZ := 4.5
const RING_DAMP := 6.0
const RING_DIP := 3.0         ## art px the body dips again when a bell is rung on time

var figure := "mamuthone"
var black := true             ## the Mamuthone's black fleece (the Workshop's choice); false: the picture's own brown
var mirror := false           ## the road is to the left (true) or the right (false)
var reduced_motion := false
var _upper: Sprite2D
var _legs: Sprite2D
var _pieces: Array = []       ## [Sprite2D, kind]
var _size := Vector2.ONE
## Daniele's ChatGPT bob (tools/art/chatgpt/outputs.py -> art/ai/fig/<figure>_bob_<i>.png): four
## drawn poses, 0 up, 1 going down, 2 down, 3 coming back (the beat snaps to 2, then 3, then 0). Where they exist the figure is one
## picture swapped by the beat instead of pieces moved.
const BOB_DIR := "res://art/ai/fig/"
## How long each drawn pose shows, from the frames' own timing at 120 BPM (README of the bob set:
## 0 up 200 ms, 1 going down 90 ms, 2 down 80 ms, 3 coming back 130 ms): the down pose lands on the
## beat, the going-down pose leads into it. A faster song shortens them all alike; a slower one keeps
## them and holds the up pose longer, so the snap never goes soft.
const BOB_MS := [200.0, 90.0, 80.0, 130.0]
const BOB_SPB := 0.5          ## the beat they were drawn for (120 BPM)
var spb := 0.5                ## the song's seconds a beat (StreetBackdrop sets it)
var _bob_tex: Array[Texture2D] = []


func _init(p_figure := "mamuthone") -> void:
	figure = p_figure


## The body as two slices of its picture (the legs stay planted, the rest drops over them, so the
## seam is always exact), then the pieces over it.
func _ready() -> void:
	if ResourceLoader.exists(BOB_DIR + "%s_bob_0.png" % figure):
		for i in 4:
			var src: Texture2D = load(BOB_DIR + "%s_bob_%d.png" % [figure, i])
			if figure == "mamuthone" and black:
				src = FigureSprites.black_tex(i, src)
			_bob_tex.append(src)
		_size = _bob_tex[0].get_size()
		_upper = _sprite(_bob_tex[0], "Pose", 0.0, _size.y)
		return
	var tex: Texture2D = _piece("body")
	if tex == null:
		return
	_size = tex.get_size()
	var knee := float(KNEE.get(figure, roundi(_size.y * 0.7)))
	_legs = _sprite(tex, "Legs", knee, _size.y)
	_upper = _sprite(tex, "Upper", 0.0, knee)
	for spec: Array in PIECES.get(figure, []):
		var pt: Texture2D = _piece(str(spec[0]))
		if pt != null:
			_pieces.append([_sprite(pt, str(spec[0]).capitalize().replace(" ", ""), 0.0, _size.y), str(spec[1])])


func _piece(part: String) -> Texture2D:
	var pxl := "%s%s/%s_%s.png" % [PXL_DIR, figure, figure, part]
	if ResourceLoader.exists(pxl):
		return load(pxl)
	return load(DIR + "%s_%s.png" % [figure, part])


func _sprite(tex: Texture2D, n: String, top: float, bottom: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.use_parent_material = true    # a portrait's cut (StreetBackdrop) set on the figure
	s.region_enabled = true
	s.region_rect = Rect2(0.0, top, _size.x, bottom - top)
	# the origin is the feet, the bottom centre on a whole art px
	s.offset = Vector2(-floorf(_size.x * 0.5), top - _size.y)
	add_child(s)
	return s


## The figure's height in art px (its pictures').
func art_height() -> float:
	return _size.y


## The swing (degrees) of the painted figures' load `age` seconds after a bell rung on time.
static func ring_swing(age: float) -> float:
	if age < 0.0 or age > 1.0:
		return 0.0
	return RING_SWING * sin(TAU * RING_HZ * age) * exp(-RING_DAMP * age)


## Poses the figure t seconds after the last beat (bar: the beat's place in its bar, kept for the
## callers). `ring`: seconds since a bell was rung on time: the body dips again and the load is
## thrown up (a tilt up) or down.
func pose(t: float, _bar: float, still := false, ring := 9.0, ring_up := true) -> void:
	if _upper == null:
		return
	if not _bob_tex.is_empty():
		_pose_frames(t, still, ring)
		return
	var m := 0.35 if reduced_motion else 1.0
	var bob := 0.0 if still else StreetBackdrop._bob(t)
	var rung := not still and ring >= 0.0 and ring < 0.5
	var dip := StreetBackdrop._bob(ring) * RING_DIP / DROP if rung else 0.0
	# whole art px, so the pictures stay on their grid
	var body := roundf(maxf(bob, dip) * DROP * m)
	_upper.position = Vector2(0.0, body)
	var toward := -1.0 if mirror else 1.0
	for e: Array in _pieces:
		var s: Sprite2D = e[0]
		var y := body
		var x := 0.0
		if not still:
			if e[1] == "head":
				# down with the body and a little further, back up a moment after it
				var h := maxf(maxf(bob, StreetBackdrop._bob(t - HEAD_LAG)), dip)
				y = maxf(body, roundf(h * (DROP + NOD) * m))
			else:
				var l := StreetBackdrop._bob(t - LOAD_LAG)
				y = body + clampf(roundf(l * DROP * m) - body, -LOAD_OFF, LOAD_OFF)
				x = roundf(maxf(bob, l) * LOAD_OUT * m) * toward
				if rung:
					y += roundf(StreetBackdrop._bob(ring) * RING_THROW * m) * (-1.0 if ring_up else 1.0)
				# never further off than the body is filled in behind it
				y = body + clampf(y - body, -REACH, REACH)
		s.position = Vector2(x, y)


## The drawn bob: the down pose on the beat (and when a bell is rung on time), then the poses back up.
## Reduced motion keeps the halfway poses only.
func _pose_frames(t: float, still: bool, ring: float) -> void:
	_upper.texture = _bob_tex[bob_frame(t, spb, still, ring, reduced_motion)]


## The drawn pose t seconds after the beat (beats spb apart; ring: seconds since a bell rung on time).
static func bob_frame(t: float, p_spb: float, still := false, ring := 9.0, calm := false) -> int:
	if still:
		return 0
	var k := clampf(p_spb / BOB_SPB, 0.2, 1.0)
	var down := BOB_MS[2] * 0.001 * k
	var back := BOB_MS[3] * 0.001 * k
	var lead := BOB_MS[1] * 0.001 * k
	var since := t
	if ring >= 0.0 and ring < since:
		since = ring
	var f := 0
	if since >= 0.0 and since < down:
		f = 2
	elif since >= 0.0 and since < down + back:
		f = 3
	elif t >= 0.0 and t < 90.0 and p_spb - t <= lead:
		f = 1   # going down into the next beat
	if calm and f == 2:
		f = 1
	return f
