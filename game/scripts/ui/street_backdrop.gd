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
const PIXEL_STREET := "res://art/pixel/street.png"   ## the pixel look's street: Daniele's second street picture laid into this one's frame, lines painted on (tools/art/pixel3d/bake_ai_street.py)
const IMG := Vector2(941.0, 1672.0)
## The painted lines, x = a + b * y in the picture's pixels: the road's edges and the lane dividers.
const RAILS := [Vector2(609.17, -0.45827), Vector2(510.90, -0.14397), Vector2(445.17, 0.12678), Vector2(356.72, 0.43025)]
const VANISH_Y := 265.0              ## where the lines meet (the horizon), picture px
const FAR_Y := 468.0                 ## the road's far end, just in front of the fire, picture px
const STRETCH_FROM := 460.0          ## the picture is only ever stretched below this row
const FIRE := Vector2(480.0, 370.0)  ## the fire's heart, picture px
const LANTERNS := [Vector2(104, 256), Vector2(855, 276), Vector2(320, 382)]
## On the hit line, an outer lane's whole slot and its biggest note (a stomp, StreetSkin.STOMP_R,
## with its outline) stay on screen: their edge keeps EDGE_PAD of the width off the screen's edge.
const CLEAR_R := 0.53                ## lane widths from an outer lane's centre that must show
const EDGE_PAD := 0.035
## The picture is shown this much bigger than it takes to cover the screen (top aligned, centred
## across), so the road's far end and the notes there are bigger (Daniele, 2026-10-05).
const ZOOM := 1.2
## The portrait frames' corners (picture px, the left one; the right mirrors it), from the play-screen
## reference.
## Raised by FRAME_LIFT (Daniele, 2026-10-05) so more of the street and the notes' road shows.
const FRAME := [Vector2(-12, 232), Vector2(226, 296), Vector2(272, 612), Vector2(-12, 748)]
const FIGURE_IN := 24.0           ## picture px each figure stands in from its portrait's middle, toward the road (mirrored)
const ISSO_RIGHT := 16.0          ## picture px the Issohadore (left portrait) then moves further right (Daniele, 2026-10-05)
const FIGURE_FILL := 1.12          ## a painted figure's height, as a share of its portrait's
const FRAME_GROW := 140.0 / 118.0   ## the portraits grew with the pixel figures (bake_figures.py H, 118 -> 140)
const FRAME_LIFT := Vector2(20.0, 55.0)   ## picture px the portraits' top and bottom edges are raised (as far as the HUD's words allow; the puppets keep their size)
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
## The HUD's lower edge in this control's coordinates (-INF: unknown). The portraits and their
## figures move down as far as needed for the heads to stay under it (a notch pushes the HUD down).
var hud_bottom := -INF
const HUD_GAP := 6.0
var bell_set := "village"
## The pixel look (set before this enters the tree): the street as pixel art, and the figures as
## puppets whose parts slide (PixelFigure) instead of Daniele's three-pose pictures.
var pixel := false

## The picture on screen: scale, x offset, and the stretch below STRETCH_FROM.
var pic_scale := 1.0
var pic_off := 0.0
var stretch := 1.0

var _pic: TextureRect
var _vp: SubViewport                 ## the pixel look: the street drawn at one texel per lens cell
var own_cells := true                ## false when the whole play screen is already drawn one px per cell
var _cells: TextureRect              ## ... and shown scaled up
var _mat: ShaderMaterial
var _glow: Control                   ## additive: lines pulsing, lanterns, hit flashes
var _sparks: CPUParticles2D
var _frames: Array[Node2D] = []
var _figures: Array[Sprite2D] = []
var _puppets: Array[PixelFigure] = []
var _poses: Array = []               ## per figure, its poses (STAND, DROP, HALF), all the same size, feet at the bottom centre
var _glow_tex: Texture2D
var _flashes: Array = []             ## [local pos, t0, strength]
var _clock := 0.0
var _kick := 0.0
var _jolt_kind := ""
var _bell_at := -9.0                  ## _clock of the last bell rung on time
var _bell_up := true
var _rope_at := -9.0                  ## _clock of the last call answered on time
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
	_pic.texture = load(PIXEL_STREET if pixel else STREET)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PICTURE_SHADER
	_mat.shader = sh
	_pic.material = _mat
	if pixel and own_cells:
		# the pixel look draws the street (its moving road is the costly part) at one texel per
		# cell of the lens, then shows it scaled up: a ninth of the work, and crisp on the grid
		_vp = SubViewport.new()
		_vp.name = "StreetCells"
		_vp.disable_3d = true
		_vp.transparent_bg = false
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp.add_child(_pic)
		add_child(_vp)
		_cells = TextureRect.new()
		_cells.name = "StreetView"
		_cells.texture = _vp.get_texture()
		_cells.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_cells.stretch_mode = TextureRect.STRETCH_SCALE
		_cells.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cells.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_cells)
	else:
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
	if pixel:
		# the pixel look's light stays on the street, under the portraits: added over them it washed
		# the figures' few colours out (the Mamuthone's dark fleece turned tan)
		move_child(_glow, _frames[0].get_index())
	_sparks = _make_sparks()
	add_child(_sparks)
	resized.connect(_fit)
	_fit()


# ------------------------------------------------------------------ the picture on screen

func _fit() -> void:
	_layout = Vector3.ZERO
	if _vp != null:
		_vp.size = Vector2i(maxi(1, ceili(size.x / PxArt.PX)), maxi(1, ceili(size.y / PxArt.PX)))
		_cells.size = Vector2(_vp.size) * PxArt.PX
		_cells.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_cells.size = Vector2(_vp.size) * PxArt.PX
	_solve()


## Cover the screen with the picture (top aligned), then stretch below the fire just enough for the
## outer lanes' notes at LaneView's hit line.
func _solve() -> void:
	var hl := _hit_line_local()
	var key := Vector3(size.x, size.y, hl)
	if key == _layout or size.x < 2.0:
		return
	_layout = key
	pic_scale = maxf(size.x / IMG.x, size.y / IMG.y) * ZOOM
	pic_off = (size.x - IMG.x * pic_scale) * 0.5
	var margin := size.x * EDGE_PAD
	var x_min := (margin - pic_off) / pic_scale
	var x_max := (size.x - margin - pic_off) / pic_scale
	# the outer lanes' middles (halfway between the edge line and the divider), less or plus CLEAR_R
	# of the middle lane's width (the size LaneView draws notes at): the lowest picture row where both
	# outer slots still fit; the hit line is stretched up to it
	var lane: Vector2 = RAILS[2] - RAILS[1]
	var yl := _solve_line(RAILS[0].lerp(RAILS[1], 0.5) - lane * CLEAR_R, x_min)
	var yr := _solve_line(RAILS[2].lerp(RAILS[3], 0.5) + lane * CLEAR_R, x_max)
	var need := minf(yl, yr)
	var hl_img := hl / pic_scale
	stretch = maxf(1.0, (hl_img - STRETCH_FROM) / maxf(need - STRETCH_FROM, 1.0))
	if _mat != null:
		_mat.set_shader_parameter("pic", IMG)
		_mat.set_shader_parameter("rect", Vector2(_vp.size) * PxArt.PX if _vp != null else size)
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
## The picture row where the line x = a.x + a.y * y reaches picture x.
func _solve_line(a: Vector2, x: float) -> float:
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


## The numbers flat_to_local() works from, for LaneView, which maps many points a frame and keeps
## them for the frame: [a, b, the hit line's flat depth, the field's width, pic_off, pic_scale,
## stretch] (a and b: 1 / (row - horizon) at the road's far end and at the hit line).
func flat_consts() -> PackedFloat32Array:
	var fr := lanes.field_rect()
	_solve()
	var yh := _hit_line_local() / pic_scale
	if yh > STRETCH_FROM:
		yh = STRETCH_FROM + (yh - STRETCH_FROM) / stretch
	return PackedFloat32Array([1.0 / (FAR_Y - VANISH_Y), 1.0 / (yh - VANISH_Y), maxf(LaneSkin.hit_line_y(fr), 1.0),
		maxf(fr.size.x, 1.0), pic_off, pic_scale, stretch])


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


## A bell rung on time: the Mamuthone's load (and the Issohadore's rope) is thrown and swings hard,
## on top of the bob (PixelFigure.pose's ring); the painted figures rock.
func bell_strike(up: bool) -> void:
	_bell_at = _clock
	_bell_up = up


## A call answered on time: the Issohadore cracks his rope (it swings like the load on a bell).
func rope_crack() -> void:
	_rope_at = _clock


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
	_move_road()
	_bob_figures()
	_glow.queue_redraw()


## The road's shader settings: the pixel look's cobbled road, laid in the street's perspective,
## and the smooth lanes (both looks). It stays still: Daniele found the
## travelling road too much on his phone (2026-10-05), so only the notes move.
func _move_road() -> void:
	if _mat == null or lanes == null or not lanes.is_inside_tree():
		return
	var fr := lanes.field_rect()
	var lane := maxf(fr.size.x / 3.0, 1.0)
	var hl := LaneSkin.hit_line_y(fr)
	var yh := _hit_line_local() / pic_scale
	if yh > STRETCH_FROM:
		yh = STRETCH_FROM + (yh - STRETCH_FROM) / stretch
	var a := Vector4(RAILS[0].x, RAILS[1].x, RAILS[2].x, RAILS[3].x)
	var b := Vector4(RAILS[0].y, RAILS[1].y, RAILS[2].y, RAILS[3].y)
	# the pixel street (Daniele's second street picture, 2026-10-08) has its own cobbles: the
	# shader's laid stones only for the first picture's painted look
	_mat.set_shader_parameter("road", false)
	_mat.set_shader_parameter("smooth_lanes", true)
	_mat.set_shader_parameter("rail_a", a)
	_mat.set_shader_parameter("rail_b", b)
	_mat.set_shader_parameter("vanish_y", VANISH_Y)
	_mat.set_shader_parameter("far_y", FAR_Y)
	_mat.set_shader_parameter("inv_far", 1.0 / (FAR_Y - VANISH_Y))
	_mat.set_shader_parameter("inv_hit", 1.0 / maxf(yh - VANISH_Y, 1.0))
	_mat.set_shader_parameter("depth", hl / lane)
	_mat.set_shader_parameter("scroll", 0.0)


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
	if not _puppets.is_empty():
		var t := 99.0
		var bar := 0.0
		if beat > -999.0:
			t = (beat - floorf(beat)) * spb
			bar = fposmod(beat, 4.0)
		if _jolt_kind == "stomp" and age < 0.3:
			t = minf(t, age)
		var ring := _clock - _bell_at
		for p in _puppets:
			p.reduced_motion = reduced_motion
			var r := ring
			if p.figure == "issohadore" and _clock - _rope_at < ring:
				r = _clock - _rope_at
			p.pose(t, bar, still, r, _bell_up or r != ring)
			var at: Vector2 = p.get_meta("base_pos", p.position)
			p.position = at + Vector2(shake * 0.02 * float(p.get_meta("frame_h", 0.0)), 0.0) * m
		return
	for i in _figures.size():
		var s := _figures[i]
		var posed := i < _poses.size()
		var base: Vector2 = s.get_meta("base_scale", Vector2.ONE)
		var at: Vector2 = s.get_meta("base_pos", s.position)
		var h: float = s.get_meta("frame_h", 0.0)
		# the poses carry part of the drop themselves: a smaller sink, no squash
		s.position = at + Vector2(shake * 0.02 * h, down * BOB * (POSE_BOB if posed else 1.0) * h) * m
		# a slight lean toward the road with the drop (the left portrait's road is to its right)
		var rock := PixelFigure.ring_swing(_clock - _bell_at) * 0.25
		s.rotation = deg_to_rad(BOB_LEAN * down + rock) * m * (1.0 if i == 0 else -1.0)
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

## A portrait: a dark panel in a gold frame, following the wall's perspective, a warm light glowing
## up from its bottom. The figure stands in front of it (Daniele, 2026-10-05): its legs go down into
## the frame, cut at the frame's lower edge, and the rest of it stands out over the frame, so it bobs
## out of the box.
func _make_frame(i: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Portrait" + ("L" if i == 0 else "R")
	var panel := Polygon2D.new()
	panel.name = "Panel"
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	panel.color = Color.WHITE
	panel.vertex_colors = PackedColorArray([Color("#1a0f10"), Color("#1a0f10"), Color("#3a1a0e"), Color("#3a1a0e")])
	if pixel:
		# warmer firelight behind the pixel figures, so the Mamuthone's dark fleece stands out of it
		panel.vertex_colors = PackedColorArray([Color("#2a1a1c"), Color("#2a1a1c"), Color("#6a3416"), Color("#6a3416")])
	root.add_child(panel)
	# the figure's layer, over the frame: clips only below the frame's lower edge (see _place_frames)
	var stand := Polygon2D.new()
	stand.name = "Stand"
	stand.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	if pixel:
		var pup := PixelFigure.new("issohadore" if i == 0 else "mamuthone")
		pup.name = "Figure"
		pup.mirror = i == 1
		stand.add_child(pup)
		_puppets.append(pup)
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
	if not pixel:
		stand.add_child(fig)
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
	root.add_child(stand)
	return root


## Tells the street where the HUD ends (this control's coordinates); the portraits make room.
func set_hud_bottom(y: float) -> void:
	if absf(y - hud_bottom) > 0.5:
		hud_bottom = y
		_place_frames()


func _frame_points(i: int, drop := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# placed on the screen as on the picture before ZOOM (the zoom is for the road), and grown by
	# FRAME_GROW from the outer top corner, so the bigger figures fit and stay clear of the HUD
	var bs := pic_scale / ZOOM
	var bo := (size.x - IMG.x * bs) * 0.5
	var anchor: Vector2 = FRAME[0] - Vector2(0.0, FRAME_LIFT.x)
	for k in FRAME.size():
		var p: Vector2 = FRAME[k] - Vector2(0.0, FRAME_LIFT.x if k < 2 else FRAME_LIFT.y)
		p = anchor + (p - anchor) * FRAME_GROW
		var q := p if i == 0 else Vector2(IMG.x - p.x, p.y)
		pts.append(Vector2(bo + q.x * bs, q.y * bs + drop))
	return pts


## The top of figure i's head when it stands in a portrait at pts (its pose at rest).
func _head_top(i: int, pts: PackedVector2Array) -> float:
	var top := (pts[0].y + pts[1].y) * 0.5
	var bottom := (pts[2].y + pts[3].y) * 0.5
	if pixel:
		if i >= _puppets.size():
			return top
		var h := (bottom - top) * (0.98 if i == 0 else 0.9)
		return bottom + h * 0.1 - _puppets[i].art_height() * PxArt.PX
	var hf := (bottom - top) * FIGURE_FILL
	return bottom + hf * 0.1 - hf


func _place_frames() -> void:
	# down just enough that no head reaches into the HUD
	var drop := 0.0
	if is_finite(hud_bottom):
		for i in _frames.size():
			drop = maxf(drop, hud_bottom + HUD_GAP - _head_top(i, _frame_points(i)))
	for i in _frames.size():
		var pts := _frame_points(i, drop)
		var f := _frames[i]
		(f.get_node("Panel") as Polygon2D).polygon = pts
		# everything above the frame's lower edge, out past its sides
		var out := (pts[3] - pts[2]).normalized() * 600.0
		var low_l := pts[3] + out
		var low_r := pts[2] - out
		(f.get_node("Stand") as Polygon2D).polygon = PackedVector2Array([low_l - Vector2(0, 3000), low_r - Vector2(0, 3000), low_r, low_l])
		(f.get_node("Frame") as Line2D).points = pts
		(f.get_node("Halo") as Line2D).points = pts
		if pixel:
			_place_puppet(i, pts)
			continue
		var fig := _figures[i]
		var ts := fig.texture.get_size()
		# the figure's feet a little below the frame's lower edge, its head near the top
		var top := (pts[0].y + pts[1].y) * 0.5
		var bottom := (pts[2].y + pts[3].y) * 0.5
		# the figure fills its portrait and breaks out of it a little (Daniele, 2026-10-05)
		var h := (bottom - top) * FIGURE_FILL
		var sc := h / ts.y
		var cx := _figure_x(i, pts)
		fig.position = Vector2(cx, bottom + h * 0.1)
		fig.set_meta("base_pos", fig.position)
		fig.set_meta("frame_h", bottom - top)
		fig.set_meta("base_scale", Vector2(sc, sc))
		fig.scale = Vector2(sc, sc)
		if i == 0:
			fig.flip_h = false


## Where a figure stands across its portrait: in from the middle toward the road, the Issohadore
## then a little to the right.
func _figure_x(i: int, pts: PackedVector2Array) -> float:
	var dx := FIGURE_IN + ISSO_RIGHT if i == 0 else -FIGURE_IN
	return (pts[0].x + pts[1].x + pts[2].x + pts[3].x) * 0.25 + dx * pic_scale / ZOOM


## The pixel look's puppet in its portrait: as tall as the picture figure, feet just below the frame.
func _place_puppet(i: int, pts: PackedVector2Array) -> void:
	if i >= _puppets.size():
		return
	var p := _puppets[i]
	var top := (pts[0].y + pts[1].y) * 0.5
	var bottom := (pts[2].y + pts[3].y) * 0.5
	# one art px is one cell of the lens (PxArt.PX base px), and the feet sit on the lens's grid, so
	# the figure comes through it crisp while it stands
	var h := (bottom - top) * (0.98 if i == 0 else 0.9)
	var sc := PxArt.PX
	var cx := _figure_x(i, pts)
	p.position = PxArt.snap2(Vector2(cx, bottom + h * 0.1))
	p.scale = Vector2(sc, sc)
	p.set_meta("base_pos", p.position)
	p.set_meta("frame_h", bottom - top)


# ------------------------------------------------------------------ the glow layer

func _draw_glow(ci: CanvasItem) -> void:
	var env := beat_env()
	var fl := 0.5 + 0.5 * sin(_clock * 11.0) * sin(_clock * 7.3 + 1.0)
	# the lanterns
	for i in LANTERNS.size():
		var p := to_local_pic(LANTERNS[i])
		var f := 0.75 + 0.25 * sin(_clock * (8.0 + i * 1.7) + i * 2.0) * sin(_clock * 13.0 + i)
		var r := 46.0 * pic_scale / 0.86 * (1.0 + 0.1 * f)
		# (the pixel look keeps the lanterns' light off the portraits: it washes their few colours out)
		var la := 0.34 if not pixel else (0.04 if i < 2 else 0.3)
		ci.draw_texture_rect(_glow_tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.62, 0.25, la * f * (1.0 - 0.5 * dim)))
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
// the pixel look's moving road: cobbles laid in the lanes that travel toward the player with the
// notes (scroll, in lane widths), lit by the picture's own light
uniform bool road = false;
uniform vec4 rail_a;
uniform vec4 rail_b;
uniform float vanish_y = 265.0;
uniform float far_y = 468.0;
uniform float inv_far = 0.005;
uniform float inv_hit = 0.001;
uniform float depth = 6.0;
uniform float scroll = 0.0;
uniform vec2 stone = vec2(0.3, 0.12);

vec2 hash2(vec2 q) {
	q = vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

// x: distance to the nearest stone's centre, y: to the gap between two stones, z: the stone's own
// tone, w: which side of its centre this is (+ the far side, toward the fire)
vec4 cobble(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 best = vec2(8.0);
	vec2 bo = vec2(0.0);
	vec2 bc = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.2 + 0.6 * hash2(n + g);
			vec2 r = g + o - f;
			float dd = dot(r, r);
			if (dd < best.x) { best.x = dd; bo = r; bc = n + g; }
		}
	}
	float edge = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.2 + 0.6 * hash2(n + g);
			vec2 r = g + o - f;
			if (dot(bo - r, bo - r) > 0.0001) {
				edge = min(edge, dot(0.5 * (bo + r), normalize(r - bo)));
			}
		}
	}
	return vec4(sqrt(best.x), edge, hash2(bc).x, bo.y);
}

vec3 moving_road(sampler2D tex, vec2 p, vec3 c) {
	if (p.y < far_y + 4.0) {
		return c;
	}
	vec4 xs = rail_a + rail_b * p.y;
	// the whole street floor moves, not just the lanes: out to where the houses stand on it
	float wall = p.x < 470.0 ? 470.0 + (330.0 - p.x) * 0.545 : 470.0 + (p.x - 610.0) * 0.574;
	if (p.y < wall + 2.0) {
		return c;
	}
	float u = p.x < xs.y ? (p.x - xs.x) / (xs.y - xs.x) : (p.x < xs.z ? 1.0 + (p.x - xs.y) / (xs.z - xs.y) : 2.0 + (p.x - xs.z) / (xs.w - xs.z));
	float k = (1.0 / (p.y - vanish_y) - inv_far) / (inv_hit - inv_far);
	float v = k * depth - scroll;
	// the stones are laid on the ground in true perspective: across, in middle-lane widths from the
	// road's centre line (a straight line to the vanishing point), so they keep their shape out past
	// the painted lines instead of shearing along them
	float gx = (p.x - (xs.y + xs.z) * 0.5) / (xs.z - xs.y);
	vec4 cb = cobble(vec2(gx, v) / stone);
	// the light here: the picture around this point, blurred wide so the painted street's own
	// patches and streaks never show through as odd shades on the stones; it only sets how lit the
	// stones are (a smooth fall-off away from the fire and the lines), not their colour
	vec3 light = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 q = clamp(p + vec2(float(i) * 26.0, float(j) * 16.0), vec2(4.0), pic - 4.0);
			light += texture(tex, q / pic).rgb;
		}
	}
	float lit = dot(light / 9.0, vec3(0.3, 0.55, 0.15));
	// one stone colour, dusk-blue in the dark and warm where the firelight falls
	light = mix(vec3(0.17, 0.14, 0.21), vec3(0.66, 0.42, 0.27), smoothstep(0.04, 0.5, lit));
	float rail = min(min(abs(u), abs(u - 1.0)), min(abs(u - 2.0), abs(u - 3.0)));
	// the lines' own glow spilling onto the stones beside them
	light += vec3(0.55, 0.25, 0.05) * exp(-rail * 9.0);
	// each stone a gently rounded top, all lit the same way, only a touch of tone between stones
	float dome = 1.0 - 0.5 * cb.x * cb.x;
	vec3 st = light * (0.97 + 0.08 * (cb.z - 0.5)) * (0.84 + 0.22 * dome);
	// a lit lip on each stone's far side (the fire is up the road), a shaded one on its near side
	float lip = 1.0 - smoothstep(0.08, 0.18, cb.y);
	st *= 1.0 + lip * (cb.w > 0.0 ? 0.12 : -0.1);
	vec3 col = cb.y < 0.05 ? light * 0.5 : st;
	// tiny far stones would shimmer: fade to the picture there; keep the lines themselves
	float lane_px = (xs.z - xs.y) * sc;
	float fade = smoothstep(10.0, 26.0, lane_px * stone.x);
	fade *= smoothstep(0.035, 0.08, rail) * smoothstep(wall + 2.0, wall + 14.0, p.y);
	return mix(c, col, fade);
}

// the three lanes the notes slide down are kept smooth (Daniele, 2026-10-05: no cobbles where the
// notes travel, for readability): an even surface in the picture's own light, averaged across the
// lane and along a stretch of road so no stone shows, a little darker than the street so the notes
// stand out, with the lines' glow spilling onto it. The lines themselves stay the picture's.
uniform bool smooth_lanes = false;

vec3 smooth_lane(sampler2D tex, vec2 p, vec3 c) {
	if (p.y < far_y + 2.0) {
		return c;
	}
	vec4 xs = rail_a + rail_b * p.y;
	if (p.x <= xs.x || p.x >= xs.w) {
		return c;
	}
	float u = p.x < xs.y ? (p.x - xs.x) / (xs.y - xs.x) : (p.x < xs.z ? 1.0 + (p.x - xs.y) / (xs.z - xs.y) : 2.0 + (p.x - xs.z) / (xs.w - xs.z));
	int li = int(clamp(floor(u), 0.0, 2.0));
	float x0 = xs[li];
	float x1 = xs[li + 1];
	float span = max((x1 - x0) * 0.35, 6.0);
	vec3 light = vec3(0.0);
	for (int j = -3; j <= 3; j++) {
		for (int i = 1; i <= 3; i++) {
			light += texture(tex, vec2(mix(x0, x1, float(i) * 0.25), p.y + float(j) * span * 0.33) / pic).rgb;
		}
	}
	light = light / 21.0;
	float rail = min(min(abs(u), abs(u - 1.0)), min(abs(u - 2.0), abs(u - 3.0)));
	vec3 col = light * 0.72 + vec3(0.55, 0.25, 0.05) * exp(-rail * 9.0) * 0.45;
	float fade = smoothstep(0.03, 0.07, rail) * smoothstep(far_y + 2.0, far_y + 14.0, p.y);
	return mix(c, col, fade);
}

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
	if (road) {
		c.rgb = moving_road(TEXTURE, p, c.rgb);
	}
	if (smooth_lanes) {
		c.rgb = smooth_lane(TEXTURE, p, c.rgb);
	}
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float hot = m * smoothstep(0.45, 0.9, lum);
	float flick = 0.06 * sin(t * 17.0) + 0.04 * sin(t * 29.0 + 1.7);
	c.rgb *= 1.0 + hot * (flare + flick * motion) - hot * 0.55 * dim;
	// low health: the night closes in, the far end darkest
	c.rgb *= 1.0 - 0.35 * dim;
	COLOR = vec4(c.rgb, 1.0);
}
"""
