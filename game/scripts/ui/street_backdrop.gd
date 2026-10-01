class_name StreetBackdrop
extends Control
## The play screen's street, from Daniele's own picture (art/street/street.png, the empty-street
## reference in mockups/lowpoly): the road of Mamoiada at night with its four glowing lines running
## up to the bonfire. The lanes are the picture's own: LaneView asks flat_to_local() where a point of
## its flat field lies, and the answer follows the painted lines (each lane between two of them) with
## a true perspective along the road.
##
## The picture covers the screen, top aligned. So the outer lanes' notes still reach the hit line on
## screen, the part of the picture below the fire can be stretched downward a little (straight lines
## stay straight): just enough that a note in an outer lane at the hit line is clear of the edge.
##
## Over the picture, all subtle so the notes stay the clearest thing: the fire flickers and flares on
## the beat (a shader on the picture) and sparks rise from it, the lanterns flicker, the four lines
## pulse on the beat, a warm light flashes where a note is hit, and two framed portraits (the
## Issohadore, a Mamuthone, cut from Daniele's turnarounds) bob down on every beat.
##
## It stands in for FireBackdrop (beat, dim, kick) and SideRows (jolt, stomp, set_still, ...), so the
## play screen drives it the same way.

const STREET := "res://art/street/street.png"
const IMG := Vector2(941.0, 1672.0)
## The painted lines, x = a + b * y in the picture's pixels: the road's edges and the lane dividers.
const RAILS := [Vector2(609.17, -0.45827), Vector2(510.90, -0.14397), Vector2(445.17, 0.12678), Vector2(356.72, 0.43025)]
const VANISH_Y := 265.0              ## where the lines meet (the horizon), picture px
const FAR_Y := 468.0                 ## the road's far end, just in front of the fire, picture px
const STRETCH_FROM := 460.0          ## the picture is only ever stretched below this row
const FIRE := Vector2(480.0, 370.0)  ## the fire's heart, picture px
const LANTERNS := [Vector2(104, 256), Vector2(855, 276), Vector2(320, 382)]
const EDGE_CLEAR := 0.12             ## an outer note's centre stays this share of the width off the edge
## The portrait frames' corners (picture px, the left one; the right mirrors it), from the play-screen
## reference.
const FRAME := [Vector2(-12, 232), Vector2(226, 296), Vector2(272, 612), Vector2(-12, 748)]
## The figures' bob, from Daniele's three-pose sheets (2026-09-30). Each figure has three pictures,
## art/street/<figure>_bob_0/1/2.png: 0 the rest pose, 1 the drop on the beat, 2 halfway back up,
## all on one canvas size with the feet at the bottom centre (tools/art/street/cut_figures.py makes
## them from a sheet). The timing lives here, in seconds after each beat, and never depends on the
## pictures: replacing the pictures keeps it. Timed on Daniele's reference clip (30 fps).
const STAND := 0
const DROP := 1
const HALF := 2
const DROP_TIME := 0.067             ## seconds after the beat the drop pose shows
const HALF_TIME := 0.12              ## ... then the halfway pose until this long after the beat (long enough to show at 30 fps)
const POSE_BOB := 0.5                ## a figure's own sink with its poses, as a share of BOB
const BOB_LEAN := 2.0                ## degrees a figure leans toward the road at the bottom of the drop
const BOB := 0.1                     ## how far a figure drops on the beat, share of its portrait's height
const BOB_SQUASH := 0.03             ## how much it squashes at the bottom of the drop
const BOB_HOLD := 0.03               ## seconds it stays down after the beat
const BOB_BACK := 0.1                ## seconds after the beat it is back up

var lanes: LaneView
var beat := -1000.0
var dim := 0.0
var reduced_motion := false
var still := false
var unison := 0
var bell_set := "village"

## The picture on screen: scale, x offset, and the stretch below STRETCH_FROM.
var pic_scale := 1.0
var pic_off := 0.0
var stretch := 1.0

var _pic: TextureRect
var _mat: ShaderMaterial
var _glow: Control                   ## additive: lines pulsing, lanterns, hit flashes
var _sparks: CPUParticles2D
var _frames: Array[Node2D] = []
var _figures: Array[Sprite2D] = []
var _poses: Array = []               ## per figure, its poses (STAND, DROP, HALF), all the same size, feet at the bottom centre
var _glow_tex: Texture2D
var _flashes: Array = []             ## [local pos, t0, strength]
var _clock := 0.0
var _kick := 0.0
var _jolt_kind := ""
var _jolt_at := -9.0
var _surge_at := -9.0
const SURGE_TIME := 0.5
var _layout := Vector3.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	_pic = TextureRect.new()
	_pic.name = "Street"
	_pic.texture = load(STREET)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PICTURE_SHADER
	_mat.shader = sh
	_pic.material = _mat
	add_child(_pic)
	_glow_tex = _radial()
	for i in 2:
		var f := _make_frame(i)
		add_child(f)
		_frames.append(f)
	_glow = _Layer.new(self)
	_glow.name = "Glow"
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_sparks = _make_sparks()
	add_child(_sparks)
	resized.connect(_fit)
	_fit()


# ------------------------------------------------------------------ the picture on screen

func _fit() -> void:
	_layout = Vector3.ZERO
	_solve()


## Cover the screen with the picture (top aligned), then stretch below the fire just enough for the
## outer lanes' notes at LaneView's hit line.
func _solve() -> void:
	var hl := _hit_line_local()
	var key := Vector3(size.x, size.y, hl)
	if key == _layout or size.x < 2.0:
		return
	_layout = key
	pic_scale = maxf(size.x / IMG.x, size.y / IMG.y)
	pic_off = (size.x - IMG.x * pic_scale) * 0.5
	var margin := size.x * EDGE_CLEAR
	var x_min := (margin - pic_off) / pic_scale
	var x_max := (size.x - margin - pic_off) / pic_scale
	# the outer lanes' middles: halfway between the edge line and the divider
	var yl := _solve_y(0, 1, 0.5, x_min)
	var yr := _solve_y(2, 3, 0.5, x_max)
	var need := minf(yl, yr)
	var hl_img := hl / pic_scale
	stretch = maxf(1.0, (hl_img - STRETCH_FROM) / maxf(need - STRETCH_FROM, 1.0))
	if _mat != null:
		_mat.set_shader_parameter("pic", IMG)
		_mat.set_shader_parameter("rect", size)
		_mat.set_shader_parameter("sc", pic_scale)
		_mat.set_shader_parameter("off", pic_off)
		_mat.set_shader_parameter("y0", STRETCH_FROM)
		_mat.set_shader_parameter("stretch", stretch)
		_mat.set_shader_parameter("fire", FIRE)
	_place_frames()
	if _sparks != null:
		_sparks.position = to_local_pic(FIRE + Vector2(0, -90))
		_sparks.scale = Vector2.ONE * pic_scale / 0.86


## The picture row where the line between rails i and j at fraction f reaches picture x.
func _solve_y(i: int, j: int, f: float, x: float) -> float:
	var a: Vector2 = RAILS[i].lerp(RAILS[j], f)
	return (x - a.x) / a.y if absf(a.y) > 0.0001 else 1e6


func _hit_line_local() -> float:
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var fr := lanes.field_rect()
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		return (to_me * Vector2(0.0, LaneSkin.hit_line_y(fr))).y
	return size.y * 0.79


## A point of the picture (px) on screen, in this control's coordinates.
func to_local_pic(p: Vector2) -> Vector2:
	_solve()
	var y := p.y if p.y <= STRETCH_FROM else STRETCH_FROM + (p.y - STRETCH_FROM) * stretch
	return Vector2(pic_off + p.x * pic_scale, y * pic_scale)


func rail_x(i: int, y: float) -> float:
	var r: Vector2 = RAILS[i]
	return r.x + r.y * y


## The picture row of a flat depth: a true perspective, 1 / (y - horizon) linear in the flat depth,
## from FAR_Y at the field's top (flat 0) to the hit line's row at the hit line.
func _pic_y(fy: float) -> float:
	var fr := lanes.field_rect()
	var hl := LaneSkin.hit_line_y(fr)
	_solve()
	var yh := _hit_line_local() / pic_scale
	if yh > STRETCH_FROM:
		yh = STRETCH_FROM + (yh - STRETCH_FROM) / stretch
	var a := 1.0 / (FAR_Y - VANISH_Y)
	var b := 1.0 / (yh - VANISH_Y)
	var k := fy / maxf(hl, 1.0)
	var inv := a + (b - a) * k
	return VANISH_Y + 1.0 / maxf(inv, 0.00005)


## Where a point of LaneView's flat field lies on screen (this control's coordinates): across the
## lanes between the painted lines, down the road in perspective.
func flat_to_local(p: Vector2) -> Vector2:
	var fr := lanes.field_rect()
	var y := _pic_y(p.y)
	var u := p.x / maxf(fr.size.x, 1.0) * 3.0
	var i := clampi(int(floor(u)), 0, 2)
	var f := u - float(i)
	var x := lerpf(rail_x(i, y), rail_x(i + 1, y), f)
	return to_local_pic(Vector2(x, y))


## A lane's width on screen at flat depth fy (the middle lane's), this control's px.
func lane_px(fy: float) -> float:
	var y := _pic_y(fy)
	return (rail_x(2, y) - rail_x(1, y)) * pic_scale


# ------------------------------------------------------------------ the SideRows / FireBackdrop calls

func set_look(_mask: Dictionary, _fleece := "black", _straps := "natural") -> void:
	pass


func set_bell_set(id: String) -> void:
	bell_set = id


func set_stop(_n: int) -> void:
	pass


func set_unison(level: int) -> void:
	unison = level


func set_still(on: bool) -> void:
	still = on


func settle() -> void:
	still = false


func jolt(kind := "step") -> void:
	_jolt_kind = kind
	_jolt_at = _clock


func throw_rope() -> void:
	jolt("rope")


func stomp() -> void:
	jolt("stomp")
	kick(1.0)


func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)


## A surge of light runs up the four lines from the player to the fire, and the fire roars (the
## procession's unison rose).
func surge() -> void:
	_surge_at = _clock
	kick(1.0)


func set_ghost_delta(_seconds: float) -> void:
	pass


func hide_ghost() -> void:
	pass


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on


## A warm light flashing up where a note was hit (this control's coordinates).
func flash(at: Vector2, strength := 1.0) -> void:
	_flashes.append([at, _clock, strength])
	if _flashes.size() > 8:
		_flashes.pop_front()


## The beat's envelope for the light: 1 on the beat, falling away (a third with reduced motion).
func beat_env() -> float:
	if beat <= -999.0:
		return 0.0
	return PxArt.beat_env(beat, 0.4, 0.6, 0.0) * (0.35 if reduced_motion else 1.0)


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	_clock += delta
	_solve()
	_kick = maxf(0.0, _kick - delta * 2.0)
	var env := beat_env()
	if _mat != null:
		_mat.set_shader_parameter("t", _clock)
		_mat.set_shader_parameter("flare", 0.18 * env + 0.35 * _kick)
		_mat.set_shader_parameter("dim", dim)
		_mat.set_shader_parameter("motion", 0.35 if reduced_motion else 1.0)
	if _sparks != null:
		_sparks.speed_scale = 1.0 - 0.5 * dim
	_bob_figures()
	_glow.queue_redraw()


## The figures bob on every beat, after the character in Daniele's recording: on the beat each drops
## at once (BOB of its portrait's height, a slight squash with it), holds there for a moment, and
## springs back up within a tenth of a second, then stands still until the next beat. Never a jump.
func _bob_figures() -> void:
	var down := 0.0
	var spb := lanes.spb if lanes != null and lanes.spb > 0.0 else 0.5
	if beat > -999.0 and not still:
		down = _bob((beat - floorf(beat)) * spb)
	var m := 0.35 if reduced_motion else 1.0
	var age := _clock - _jolt_at
	var shake := 0.0
	match _jolt_kind:
		"miss":
			shake = sin(age * 28.0) * exp(-age * 7.0)
		"stomp":
			down = maxf(down, _bob(age) * 1.4)
	_dance_pose()
	for i in _figures.size():
		var s := _figures[i]
		var posed := i < _poses.size()
		var base: Vector2 = s.get_meta("base_scale", Vector2.ONE)
		var at: Vector2 = s.get_meta("base_pos", s.position)
		var h: float = s.get_meta("frame_h", 0.0)
		# the poses carry part of the drop themselves: a smaller sink, no squash
		s.position = at + Vector2(shake * 0.02 * h, down * BOB * (POSE_BOB if posed else 1.0) * h) * m
		# a slight lean toward the road with the drop (the left portrait's road is to its right)
		s.rotation = deg_to_rad(BOB_LEAN) * down * m * (1.0 if i == 0 else -1.0)
		var q := 0.0 if posed else BOB_SQUASH * down * m
		s.scale = base * Vector2(1.0 + q * 0.6, 1.0 - q)


## The figures' pose for this moment of the beat: the drop just after the beat, halfway back up,
## then standing until the next beat.
func _dance_pose() -> void:
	var pose := STAND
	var spb := lanes.spb if lanes != null and lanes.spb > 0.0 else 0.5
	if beat > -999.0 and not still:
		pose = pose_at((beat - floorf(beat)) * spb, reduced_motion)
	for i in mini(_poses.size(), _figures.size()):
		var tex: Texture2D = _poses[i][pose]
		if _figures[i].texture != tex:
			_figures[i].texture = tex


## Which pose (STAND, DROP, HALF) shows t seconds after a beat.
static func pose_at(t: float, reduced := false) -> int:
	if t >= 0.0 and t < DROP_TIME:
		return DROP
	if t >= 0.0 and t < HALF_TIME and not reduced:
		return HALF
	return STAND


## How far down a figure is (1 = the full drop) t seconds after the beat: down at once, held for a
## frame or two, back up by 0.1 s.
static func _bob(t: float) -> float:
	if t < 0.0:
		return 0.0
	var x := clampf((t - BOB_HOLD) / (BOB_BACK - BOB_HOLD), 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)


# ------------------------------------------------------------------ the portraits

## A portrait: a dark panel in a gold frame, following the wall's perspective, the figure standing
## in it (clipped by it), a warm light glowing up from its bottom.
func _make_frame(i: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Portrait" + ("L" if i == 0 else "R")
	var panel := Polygon2D.new()
	panel.name = "Panel"
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	panel.color = Color.WHITE
	panel.vertex_colors = PackedColorArray([Color("#1a0f10"), Color("#1a0f10"), Color("#3a1a0e"), Color("#3a1a0e")])
	root.add_child(panel)
	var fig := Sprite2D.new()
	fig.name = "Figure"
	var poses: Array[Texture2D] = []
	for k in [STAND, DROP, HALF]:
		poses.append(load("res://art/street/%s_bob_%d.png" % ["issohadore" if i == 0 else "mamuthone", k]))
	_poses.append(poses)
	fig.texture = poses[STAND]
	fig.centered = false
	fig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var ts := fig.texture.get_size()
	fig.offset = Vector2(-ts.x * 0.5, -ts.y)           # the feet are the pivot
	panel.add_child(fig)
	_figures.append(fig)
	var border := Line2D.new()
	border.name = "Frame"
	border.closed = true
	border.width = 5.0
	border.default_color = Color("#ffb347")
	border.joint_mode = Line2D.LINE_JOINT_SHARP
	root.add_child(border)
	var halo := Line2D.new()
	halo.name = "Halo"
	halo.closed = true
	halo.width = 16.0
	halo.default_color = Color(1.0, 0.55, 0.15, 0.22)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	root.add_child(halo)
	return root


func _frame_points(i: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Vector2 in FRAME:
		var q := p if i == 0 else Vector2(IMG.x - p.x, p.y)
		pts.append(to_local_pic(q))
	return pts


func _place_frames() -> void:
	for i in _frames.size():
		var pts := _frame_points(i)
		var f := _frames[i]
		(f.get_node("Panel") as Polygon2D).polygon = pts
		(f.get_node("Frame") as Line2D).points = pts
		(f.get_node("Halo") as Line2D).points = pts
		var fig := _figures[i]
		var ts := fig.texture.get_size()
		# the figure's feet a little below the frame's lower edge, its head near the top
		var top := (pts[0].y + pts[1].y) * 0.5
		var bottom := (pts[2].y + pts[3].y) * 0.5
		var h := (bottom - top) * (0.98 if i == 0 else 0.9)
		var sc := h / ts.y
		var cx := lerpf(pts[0].x, pts[1].x, 0.5) if i == 0 else lerpf(pts[0].x, pts[1].x, 0.5)
		cx = (pts[0].x + pts[1].x + pts[2].x + pts[3].x) * 0.25 + (34.0 if i == 0 else 14.0) * pic_scale
		fig.position = Vector2(cx, bottom + h * 0.1)
		fig.set_meta("base_pos", fig.position)
		fig.set_meta("frame_h", bottom - top)
		fig.set_meta("base_scale", Vector2(sc, sc))
		fig.scale = Vector2(sc, sc)
		if i == 0:
			fig.flip_h = false


# ------------------------------------------------------------------ the glow layer

func _draw_glow(ci: CanvasItem) -> void:
	var env := beat_env()
	var fl := 0.5 + 0.5 * sin(_clock * 11.0) * sin(_clock * 7.3 + 1.0)
	# the lanterns
	for i in LANTERNS.size():
		var p := to_local_pic(LANTERNS[i])
		var f := 0.75 + 0.25 * sin(_clock * (8.0 + i * 1.7) + i * 2.0) * sin(_clock * 13.0 + i)
		var r := 46.0 * pic_scale / 0.86 * (1.0 + 0.1 * f)
		ci.draw_texture_rect(_glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.62, 0.25, 0.34 * f * (1.0 - 0.5 * dim)))
	# the fire's own breath, and its flare on the beat
	var fp := to_local_pic(FIRE + Vector2(0, 40))
	var fr := 190.0 * pic_scale / 0.86 * (1.0 + 0.08 * env + 0.2 * _kick)
	ci.draw_texture_rect(_glow_tex, Rect2(fp - Vector2(fr, fr * 0.8), Vector2(fr, fr * 0.8) * 2.0), false,
		Color(1.0, 0.45, 0.12, (0.1 + 0.08 * fl + 0.22 * env + 0.3 * _kick) * (1.0 - 0.7 * dim)))
	# the four lines pulse on the beat, brightest near the player
	if lanes != null and lanes.visible and env > 0.01:
		for i in 4:
			var a := to_local_pic(Vector2(rail_x(i, FAR_Y + 20.0), FAR_Y + 20.0))
			var y1 := IMG.y
			var b := to_local_pic(Vector2(rail_x(i, y1), y1))
			var n := 10
			for k in n:
				var p0 := a.lerp(b, float(k) / n)
				var p1 := a.lerp(b, float(k + 1) / n)
				var w := lerpf(2.0, 9.0, float(k) / n) * pic_scale / 0.86
				ci.draw_line(p0, p1, Color(1.0, 0.6, 0.2, 0.3 * env * lerpf(0.4, 1.0, float(k) / n)), w)
	# a surge running up the lines
	var sa := (_clock - _surge_at) / SURGE_TIME
	if lanes != null and lanes.visible and sa >= 0.0 and sa < 1.0:
		var y_far := FAR_Y + 20.0
		var y1 := IMG.y
		for i in 4:
			for k in 6:
				var u0 := clampf(1.0 - sa * 1.15 + float(k) * 0.03, 0.0, 1.0)
				var u1 := clampf(u0 + 0.03, 0.0, 1.0)
				var ya := lerpf(y_far, y1, u0)
				var yb := lerpf(y_far, y1, u1)
				var p0 := to_local_pic(Vector2(rail_x(i, ya), ya))
				var p1 := to_local_pic(Vector2(rail_x(i, yb), yb))
				var w := lerpf(4.0, 16.0, u0) * pic_scale / 0.86
				ci.draw_line(p0, p1, Color(1.0, 0.85, 0.5, (1.0 - float(k) / 6.0) * (1.0 - sa)), w)
	# warm flashes where notes were hit
	var i := 0
	while i < _flashes.size():
		var fh: Array = _flashes[i]
		var age := _clock - float(fh[1])
		if age > 0.3:
			_flashes.remove_at(i)
			continue
		i += 1
		var k := 1.0 - age / 0.3
		var r := 120.0 * float(fh[2]) * (0.7 + 0.5 * (1.0 - k))
		ci.draw_texture_rect(_glow_tex, Rect2(fh[0] - Vector2(r, r * 0.6), Vector2(r, r * 0.6) * 2.0), false, Color(1.0, 0.6, 0.2, 0.5 * k * k))


static func _radial() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Sparks"
	p.amount = 40
	p.lifetime = 2.6
	p.preprocess = 2.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(40, 16)
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(6, -20)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	p.color_ramp = ramp
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	return p


class _Layer extends Control:
	var street: StreetBackdrop

	func _init(p: StreetBackdrop) -> void:
		street = p
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		street._draw_glow(self)


## The picture, laid over the screen (cover, top aligned, stretched below y0), the fire flickering:
## its flames sway in a wave rising through them and brighten with `flare`; `dim` (low health)
## darkens the night and burns the fire low.
const PICTURE_SHADER := """
shader_type canvas_item;
uniform vec2 pic = vec2(941.0, 1672.0);
uniform vec2 rect = vec2(720.0, 1440.0);
uniform float sc = 1.0;
uniform float off = 0.0;
uniform float y0 = 460.0;
uniform float stretch = 1.0;
uniform vec2 fire = vec2(480.0, 370.0);
uniform float t = 0.0;
uniform float flare = 0.0;
uniform float dim = 0.0;
uniform float motion = 1.0;

void fragment() {
	vec2 s = UV * rect;
	vec2 p = vec2((s.x - off) / sc, s.y / sc);
	if (p.y > y0) {
		p.y = y0 + (p.y - y0) / stretch;
	}
	// the flames: an ellipse over the fire, strongest in its upper part
	vec2 d = (p - fire) / vec2(120.0, 150.0);
	float m = clamp(1.0 - dot(d, d), 0.0, 1.0);
	m *= smoothstep(fire.y + 100.0, fire.y + 40.0, p.y);
	float wave = sin(p.y * 0.07 + t * 8.0) * 0.6 + sin(p.y * 0.13 - t * 11.0 + p.x * 0.05) * 0.4;
	p.x += wave * 3.5 * m * motion;
	p.y += (sin(t * 6.0 + p.x * 0.08) * 2.0) * m * motion;
	vec4 c = texture(TEXTURE, p / pic);
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float hot = m * smoothstep(0.45, 0.9, lum);
	float flick = 0.06 * sin(t * 17.0) + 0.04 * sin(t * 29.0 + 1.7);
	c.rgb *= 1.0 + hot * (flare + flick * motion) - hot * 0.55 * dim;
	// low health: the night closes in, the far end darkest
	c.rgb *= 1.0 - 0.35 * dim;
	COLOR = vec4(c.rgb, 1.0);
}
"""
