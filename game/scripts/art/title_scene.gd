class_name TitleScene
extends Control
## The title screen's illustrated scene in pixel art ("Bonfire Night", docs/art-style.md): the night
## square of Mamoiada under the stars and the moon, the mountains, the village climbing behind with
## its bell tower, the crowd round the square, the great bonfire in the middle, braziers on stone
## pillars at the front corners; two big Mamuthones either side of the fire and an Issohadore
## throwing his rope, smaller Mamuthones further back. The top of the control is open sky for the
## word mark.
##
## It keeps its own beat clock (`bpm`): on every beat the Mamuthones land together with their bells
## (they crouch just before it, rise slowly and drop fast), the bonfire leaps and its light pulses
## over the cobbles and the house fronts; the Issohadore swings his rope every two beats.
## `set_look(fleece)` dresses the nearest Mamuthone in the player's fleece ("black" or
## "dark_brown"); `reduced_motion` keeps a third of the movement.
##
## Everything sits on one art grid (1 art px = PxArt.PX screen px) anchored at the bottom centre:
## the backdrop is baked by tools/art/pixel/scenery.py (title_scene.png and its lit / dim twins),
## the characters are drawn through FigureSprites.

var bpm := 76.0
var reduced_motion := false

const PICTURE := "title_scene"
const FIRE := Vector2(0.0, -58.0)          ## the fire's root from the bottom centre (art px)
const JUMP := 7.0                          ## a big Mamuthone's leap, art px
const BACK_JUMP := 4.0

## [x, feet y] from the bottom centre (art px); flipped when right of the fire.
const BIG := [Vector2(-56.0, -33.0), Vector2(80.0, -31.0)]
const ISSOHADORE := Vector2(32.0, -43.0)
const HAND := Vector2(12.0, -78.0)          ## his raised hand from his feet (issohadore_throw)
const BACK := [Vector2(-104.0, -66.0), Vector2(-46.0, -61.0), Vector2(54.0, -63.0), Vector2(110.0, -68.0)]
const BRAZIERS := [Vector2(-108.0, -48.0), Vector2(108.0, -48.0)]

var _fleece := "black"
var _t := 0.0
var _pic: PxArt.Picture
var _back: Control
var _fire: Bonfire
var _braziers: Array[Brazier] = []
var _front: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	PxArt.nearest(self)
	_pic = PxArt.Picture.new(PICTURE)
	_pic.name = "Square"
	add_child(_pic)
	_back = _Layer.new(self, "_draw_back")
	_back.name = "BackRow"
	add_child(_back)
	_fire = Bonfire.new()
	_fire.name = "Bonfire"
	_fire.set_anchors_preset(Control.PRESET_FULL_RECT)
	# a great fire: tall flames on the play screen's pyre
	_fire.flame_h = 118.0
	_fire.flame_w = 38.0
	_fire.pyre_k = 1
	_fire.spark_reach = 1.5
	add_child(_fire)
	for i in BRAZIERS.size():
		var b := Brazier.new()
		b.name = "Brazier%d" % i
		b.seed = float(i) + 3.0
		b.flip = i == 1
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(b)
		_braziers.append(b)
	_front = _Layer.new(self, "_draw_front")
	_front.name = "Dancers"
	add_child(_front)


## Dresses the nearest Mamuthone (the big one on the left) in the player's fleece.
func set_look(fleece: String) -> void:
	_fleece = fleece if fleece in ["black", "dark_brown"] else "black"
	queue_redraw()


## The scene's beat now (fractional; 0 at the first beat).
func beat() -> float:
	return _t * bpm / 60.0


## The art grid's origin: the bottom centre, on whole art pixels.
func origin() -> Vector2:
	var px := PxArt.PX
	return Vector2(floorf(size.x * 0.5 / px) * px, floorf(size.y / px) * px)


func _process(delta: float) -> void:
	_t += delta
	var b := beat()
	var g := origin()
	var px := PxArt.PX
	var amp := 0.35 if reduced_motion else 1.0
	var env := PxArt.beat_env(b, 0.5, 0.6, 0.16) * amp
	var flick := 0.5 + 0.5 * sin(_t * 9.3) * sin(_t * 5.7 + 1.3)
	var t := PxArt.scenery(PICTURE)
	if t != null:
		var origin_px := g + Vector2(-t.get_width() / 2, -t.get_height()) * px
		_pic.origin = origin_px
		var m := _pic.mat
		var fire_art := Vector2(t.get_width() / 2, t.get_height()) + FIRE
		m.set_shader_parameter("fire", fire_art)
		m.set_shader_parameter("fire_r", Vector2(120.0, 80.0) * (1.0 + 0.3 * maxf(env, 0.0)))
		m.set_shader_parameter("pulse", maxf(env, 0.0) * 0.85)
		m.set_shader_parameter("glow", 0.15 + 0.12 * flick)
		m.set_shader_parameter("dim", 0.0)
		var lamps: Array = []
		for br in _braziers:
			var l := br.light()
			var c: Vector2 = (l[0] - origin_px) / px
			lamps.append(Vector4(c.x, c.y + 8.0, float(l[1]) * 1.3, float(l[2])))
		m.set_shader_parameter("lamp_count", lamps.size())
		while lamps.size() < 6:
			lamps.append(Vector4.ZERO)
		m.set_shader_parameter("lamps", lamps)
		_pic.queue_redraw()
	_fire.root = g + FIRE * px
	_fire.px = px
	_fire.beat = b
	_fire.reduced_motion = reduced_motion
	_fire.sparks_top = 0.0
	for i in _braziers.size():
		var br := _braziers[i]
		br.feet = g + (BRAZIERS[i] as Vector2) * px
		br.px = px
		br.beat = b
		br.reduced_motion = reduced_motion
	_back.queue_redraw()
	_front.queue_redraw()


## Pose and lift (art px) of a Mamuthone at beat b: land on the beat, stand, crouch just before the
## next, then leap (a slow rise, a fast drop onto the beat).
static func jump(b: float, height: float) -> Array:
	if b < 0.0:
		return ["stand", 0.0]
	var f := fposmod(b, 1.0)
	if f < 0.14:
		return ["land", 0.0]
	if f < 0.5:
		return ["stand", 0.0]
	if f < 0.66:
		return ["crouch", 0.0]
	var u := (f - 0.66) / 0.34
	var h := 0.0
	if u < 0.62:
		h = sin(u / 0.62 * PI * 0.5)
	else:
		h = cos((u - 0.62) / 0.38 * PI * 0.5)
	return ["air", roundf(h * height)]


func _other_fleece() -> String:
	return "dark_brown" if _fleece == "black" else "black"


## The smaller Mamuthones further back, behind the fire's front logs.
func _draw_back(ci: CanvasItem) -> void:
	var g := origin()
	var px := PxArt.PX
	var j := jump(beat(), BACK_JUMP * (0.35 if reduced_motion else 1.0))
	for i in BACK.size():
		var p: Vector2 = BACK[i]
		var fleece := "black" if i % 2 == 0 else "dark_brown"
		var name := FigureSprites.mamuthone(fleece, str(j[0]))
		FigureSprites.draw(ci, name, g + (p - Vector2(0.0, float(j[1]))) * px, px, p.x > 0.0)


## In front: the two big Mamuthones and the Issohadore with his rope.
func _draw_front(ci: CanvasItem) -> void:
	var g := origin()
	var px := PxArt.PX
	var b := beat()
	var j := jump(b, JUMP * (0.35 if reduced_motion else 1.0))
	# the Issohadore: throws on every other beat, the loop spinning out over his head
	var q := fposmod(b, 2.0) / 2.0 if b >= 0.0 else 0.6
	var throwing := q < 0.55
	var ip := g + ISSOHADORE * px
	FigureSprites.draw(ci, FigureSprites.issohadore("throw" if throwing else "stand"), ip, px, false)
	if throwing:
		_draw_rope(ci, ip, q / 0.55)
	for i in BIG.size():
		var p: Vector2 = BIG[i]
		var fleece := _fleece if i == 0 else _other_fleece()
		var name := FigureSprites.mamuthone(fleece, str(j[0]), true)
		# a shadow pool under each, shrinking as he leaps
		var sw := 22.0 - float(j[1]) * 1.2
		var feet := g + p * px
		for xx in range(-int(sw), int(sw)):
			for yy in 2:
				if (xx + yy) % 2 == 0 or absf(float(xx)) < sw * 0.6:
					ci.draw_rect(Rect2(feet + Vector2(float(xx), float(yy) - 1.0) * px, Vector2(px, px)), PixelPalette.K[0])
		FigureSprites.draw(ci, name, feet - Vector2(0.0, float(j[1])) * px, px, p.x > 0.0)


## The Issohadore's rope: from his raised hand a loop swings out and round over his head through
## the throw (k 0..1), a line of rope pixels with a darker twist every few.
func _draw_rope(ci: CanvasItem, feet: Vector2, k: float) -> void:
	var px := PxArt.PX
	var hand := feet + HAND * px
	var amp := 0.35 if reduced_motion else 1.0
	var ang := -PI * 0.5 + (k * TAU * 1.0 - 0.6) * amp
	var r := (8.0 + 14.0 * sin(k * PI)) * (0.6 + 0.4 * amp)
	var centre := hand + Vector2(4.0 + cos(ang) * r * 0.5, -10.0 - r * 0.25 + sin(ang) * r * 0.2) * px
	var pts := PackedVector2Array()
	# the line from the hand to the loop, then the loop (an ellipse seen from below), sampled every
	# half art pixel so the rope is an unbroken line of pixels
	var start := centre + Vector2(-r * 0.9, 0.0) * px
	var n := maxi(2, int(hand.distance_to(start) / px * 2.0))
	for i in n:
		pts.append(hand.lerp(start, float(i) / float(n)))
	var m := maxi(12, int(TAU * r * 2.0))
	for i in m + 1:
		var a := PI + float(i) / float(m) * TAU
		pts.append(centre + Vector2(cos(a) * r, sin(a) * r * 0.42) * px)
	var cells: Array[Vector2] = []
	for p in pts:
		var s := (p / px).floor() * px
		if cells.is_empty() or cells[-1] != s:
			cells.append(s)
	# a dark edge under the rope, then the twisted rope over it
	for c in cells:
		ci.draw_rect(Rect2(c + Vector2(0.0, px), Vector2(px, px)), PixelPalette.K[0])
	for i in cells.size():
		var col: Color = PixelPalette.ROPE[0] if i % 4 == 0 else PixelPalette.ROPE[2 if i % 4 == 1 else 1]
		ci.draw_rect(Rect2(cells[i], Vector2(px, px)), col)


class _Layer extends Control:
	var scene: TitleScene
	var method: String

	func _init(p_scene: TitleScene, p_method: String) -> void:
		scene = p_scene
		method = p_method
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		PxArt.nearest(self)

	func _draw() -> void:
		scene.call(method, self)


## Above the picture (a tall screen): the sky's darkest navy.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PixelPalette.NIGHT[0])
