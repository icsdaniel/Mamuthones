class_name PlayWorld
extends Control
## The play screen's world in low-poly 3D (mockups/lowpoly/play_screen.png): a cobbled street of
## Mamoiada at night running up to the great bonfire, whitewashed houses with lanterns either side,
## the mountains behind, and the two framed portraits on the walls - the Issohadore on the left, a
## Mamuthone on the right - that sway on the beat. The notes ride the road in 3D (NoteField3D).
##
## It stands in for both the old FireBackdrop (beat, dim, kick) and SideRows (jolt, stomp, set_still,
## set_unison, ...), so the play screen drives it the same way. The camera is solved from the lanes'
## layout every time it changes: the road's hit line lands exactly on LaneView's hit line and spans
## the field's width, and the road's far end (the fire) sits at FAR_AT of the screen's height. So a
## point of LaneView's flat field has one place in the world (flat_to_world) and one on screen
## (to_local_2d), and LaneView's project() goes through the camera.
##
## The Mamuthones never jump. Each sways its weight from one foot to the other, arriving on the beat
## (like the notes' hop), and its back bells swing a little behind it: a steady pendulum to keep time by.

const ROAD_W := 3.0                 ## the three lanes, rail to rail (world units)
const FAR_AT := 0.285               ## the road's far end, as a share of the screen's height
const PITCH := 22.0                 ## camera pitch below the horizon (degrees)
const FOV := 58.0                   ## vertical field of view (degrees)
const STREET_HALF := 5.4            ## house fronts from the road's middle
const SWAY := 7.0                   ## degrees a Mamuthone leans at each beat
const SWAY_MOVE := 0.55             ## share of each beat spent moving (it arrives on the beat)
const ROAD_TONE := Color("#2e2f40") ## the cobbles, kept dark so the notes are the brightest thing
const MAX_UNISON := 4
const PORTRAIT_AT := Vector2(0.155, 0.3)   ## a portrait's middle on screen (left one; the right mirrors it)
const PORTRAIT_DEPTH := 8.2                ## how far from the camera the portraits hang (for a 24-unit road)
const PORTRAIT_TURN := 52.0                ## degrees each portrait is turned toward the road

var lanes: LaneView
var beat := -1000.0
var dim := 0.0                      ## 0..1 the fire burns low (health)
var reduced_motion := false
var still := false
var unison := 0
var fleece := "black"
var mask: Dictionary = {}
var straps := "natural"
var bell_set := "village"

var road_len := 24.0                ## hit line to the far end, solved with the camera
var viewport: SubViewport
var camera: Camera3D
var notes: NoteField3D

var _root: Node3D
var _view: TextureRect
var _fire: Node3D
var _flames: MeshInstance3D
var _fire_light: OmniLight3D
var _embers: CPUParticles3D
var _fire_mat: ShaderMaterial
var _portraits: Array[Node3D] = []   ## [Issohadore frame, Mamuthone frame]
var _swayers: Array[Node3D] = []     ## every figure that sways (its Body node)
var _by_fire: Array[Node3D] = []     ## the Mamuthones by the fire, joining with unison
var _lanterns: Array[OmniLight3D] = []
var _rails_mat: ShaderMaterial
var _clock := 0.0
var _kick := 0.0
var _jolt_kind := ""
var _jolt_at := -9.0
var _layout_key := Vector4.ZERO
var _cam_depth_h := 1.0             ## camera-space depth of the hit line (for widths on screen)
var _fpx := 1.0                     ## focal length in this control's px


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "World"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_view = TextureRect.new()
	_view.name = "View"
	_view.texture = viewport.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	_root = Node3D.new()
	_root.name = "Street"
	viewport.add_child(_root)
	_build_environment()
	_build_road()
	_build_houses()
	_build_fire()
	_build_portraits()
	_build_fire_file()
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.3
	camera.far = 160.0
	_root.add_child(camera)
	camera.current = true
	notes = NoteField3D.new()
	notes.name = "Notes"
	notes.world = self
	_root.add_child(notes)
	resized.connect(_fit)
	_fit()


# ------------------------------------------------------------------ the camera and the lanes' layout

func _fit() -> void:
	var ps := _pixel_scale()
	var px := Vector2i(maxi(int(size.x * ps), 2), maxi(int(size.y * ps), 2))
	if viewport != null and viewport.size != px:
		viewport.size = px
	_layout_key = Vector4.ZERO


## Device pixels per unit of this control (so the 3D renders at the phone's own resolution).
func _pixel_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var s := (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale()
	return clampf(maxf(s.x, s.y), 0.5, 3.0) if s.x > 0.0 else 1.0


## LaneView's flat field in this control's coordinates: [field rect, hit line y].
func _field_here() -> Array:
	var f := Rect2(0.0, size.y * 0.15, size.x, size.y * 0.7)
	var hl := f.position.y + f.size.y * 0.9
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var fr := lanes.field_rect()
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var a := to_me * fr.position
		var b := to_me * fr.end
		f = Rect2(a, b - a)
		hl = (to_me * Vector2(0.0, LaneSkin.hit_line_y(fr))).y
	return [f, hl]


## Places the camera so the road's hit line (z = 0) falls on LaneView's hit line and spans the
## field's width, and the road's far end (z = -road_len) falls at FAR_AT of the height.
func _solve_camera() -> void:
	var fh := _field_here()
	var f: Rect2 = fh[0]
	var hl: float = fh[1]
	var key := Vector4(f.size.x, hl, size.x, size.y)
	if key == _layout_key or camera == null or size.y < 2.0:
		return
	_layout_key = key
	var H := size.y
	var t := tan(deg_to_rad(FOV) * 0.5)
	var th := deg_to_rad(PITCH)
	var yf := minf(H * FAR_AT, hl - H * 0.25)
	var ah := th + atan((hl - H * 0.5) / (H * 0.5) * t)
	var af := th + atan((yf - H * 0.5) / (H * 0.5) * t)
	af = maxf(af, 0.01)
	# with a road 1 unit long first, then scaled so the hit line spans the field
	var h1 := 1.0 / (1.0 / tan(af) - 1.0 / tan(ah))
	var dh1 := h1 / tan(ah)
	var depth1 := dh1 * cos(th) + h1 * sin(th)
	_fpx = (H * 0.5) / t
	var rw1 := f.size.x * depth1 / _fpx
	var k := ROAD_W / maxf(rw1, 0.0001)
	road_len = k
	var h := h1 * k
	var dh := dh1 * k
	_cam_depth_h = depth1 * k
	var cx := (f.get_center().x - size.x * 0.5) * _cam_depth_h / _fpx
	camera.position = Vector3(-cx, h, dh)
	camera.rotation = Vector3(-th, 0.0, 0.0)
	_place_far_things()


## Where a point of LaneView's flat field (LaneView's own coordinates) lies on the road.
func flat_to_world(p: Vector2, lift := 0.0) -> Vector3:
	if lanes == null:
		return Vector3.ZERO
	var fr := lanes.field_rect()
	var hl := LaneSkin.hit_line_y(fr)
	var u := (p.x - fr.position.x) / maxf(fr.size.x, 1.0)
	var z := -(hl - p.y) / maxf(hl - fr.position.y, 1.0) * road_len
	return Vector3((u - 0.5) * ROAD_W, lift, z)


## A world point on screen, in this control's coordinates.
func to_local_2d(p: Vector3) -> Vector2:
	_solve_camera()
	if camera == null or not camera.is_inside_tree():
		return Vector2.ZERO
	var v := camera.unproject_position(p)
	return v / _pixel_scale()


## A world point on screen, in global canvas coordinates.
func to_global_2d(p: Vector3) -> Vector2:
	return get_global_transform() * to_local_2d(p)


## Screen px per world unit across the road at depth z (world), in this control's px.
func px_per_unit(z: float) -> float:
	_solve_camera()
	if camera == null:
		return 100.0
	var local := camera.transform.affine_inverse() * Vector3(0.0, 0.0, z)
	return _fpx / maxf(-local.z, 0.05)


# ------------------------------------------------------------------ the SideRows / FireBackdrop calls

func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural") -> void:
	mask = p_mask
	straps = p_straps
	if p_fleece == fleece and not _portraits.is_empty():
		return
	fleece = p_fleece
	if is_inside_tree():
		_rebuild_mamuthones()


func set_bell_set(id: String) -> void:
	bell_set = id


func set_stop(_n: int) -> void:
	pass


func set_unison(level: int) -> void:
	unison = clampi(level, 0, MAX_UNISON)
	for i in _by_fire.size():
		_by_fire[i].visible = i < 2 + unison


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


func set_ghost_delta(_seconds: float) -> void:
	pass


func hide_ghost() -> void:
	pass


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on


## The road's far end on screen: [centre x, y] and its width (this control's coordinates).
func far_end() -> Rect2:
	var a := to_local_2d(Vector3(-ROAD_W * 0.5, 0.0, -road_len))
	var b := to_local_2d(Vector3(ROAD_W * 0.5, 0.0, -road_len))
	return Rect2(a.x, a.y, b.x - a.x, 0.0)


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	_clock += delta
	_fit()
	_solve_camera()
	_kick = maxf(0.0, _kick - delta * 2.2)
	var env := PxArt.beat_env(beat, 0.4, 0.6, 0.0) if beat > -999.0 else 0.0
	var m := 0.35 if reduced_motion else 1.0
	var flick := 0.08 * sin(_clock * 17.0) + 0.05 * sin(_clock * 29.0 + 1.3)
	var fire := (1.0 - 0.6 * dim) * (1.0 + 0.3 * env * m + 0.5 * _kick + flick * m)
	if _fire_light != null:
		_fire_light.light_energy = 6.5 * fire
	if _fire_mat != null:
		_fire_mat.set_shader_parameter("heat", fire)
		_fire_mat.set_shader_parameter("t", _clock)
	if _flames != null:
		var s := 1.0 + (0.07 * env + 0.18 * _kick) * m - 0.35 * dim
		_flames.scale = Vector3(1.0 + 0.04 * env * m, s, 1.0 + 0.04 * env * m)
	if _embers != null:
		_embers.speed_scale = clampf(1.0 - dim * 0.6, 0.3, 1.0)
	for i in _lanterns.size():
		_lanterns[i].light_energy = 1.4 + 0.12 * sin(_clock * (9.0 + i) + i)
	if _rails_mat != null:
		_rails_mat.set_shader_parameter("energy", 1.25 + 0.6 * env * m + 0.4 * _kick)
	_sway(m)
	if notes != null:
		notes.refresh(delta)


## The beat's sway: every figure leans to one side and arrives there on each beat, alternating.
func _sway(m: float) -> void:
	var lean := 0.0
	var dip := 0.0
	var swing := 0.0
	if beat > -999.0 and not still:
		var k := floorf(beat)
		var f := beat - k
		var from := 1.0 if posmod(int(k), 2) == 0 else -1.0
		var x := clampf((f - (1.0 - SWAY_MOVE)) / SWAY_MOVE, 0.0, 1.0)
		var e := x * x * (3.0 - 2.0 * x)
		lean = lerpf(from, -from, e)
		dip = sin(PI * x)                       # the body lifts off one foot and settles on the other
		swing = -from * sin(PI * clampf(f / 0.45, 0.0, 1.0)) * 0.6   # the bells swing on after the beat
	var age := _clock - _jolt_at
	var jolt := 0.0
	match _jolt_kind:
		"miss":
			jolt = sin(age * 30.0) * exp(-age * 7.0) * 0.8
		"stomp":
			jolt = -exp(-age * 6.0) * 0.6
		"bell", "ring":
			swing += sin(age * 22.0) * exp(-age * 6.0) * 1.2
	var amp := deg_to_rad(SWAY) * m
	for b in _swayers:
		b.rotation = Vector3(0.0, 0.0, lean * amp + jolt * amp * 0.6)
		b.position.y = -0.03 * dip * m + (0.08 * jolt if _jolt_kind == "stomp" else 0.0)
		var bells := b.get_node_or_null("Bells") as Node3D
		if bells != null:
			bells.rotation = Vector3(0.12 * absf(swing) * m, 0.0, swing * amp * 0.9)


# ------------------------------------------------------------------ building the street

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type sky;
uniform vec3 top : source_color = vec3(0.02, 0.03, 0.09);
uniform vec3 mid : source_color = vec3(0.05, 0.07, 0.17);
uniform vec3 low : source_color = vec3(0.16, 0.1, 0.12);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(mid, top, smoothstep(0.05, 0.6, y));
	c = mix(low, c, smoothstep(-0.02, 0.12, y));
	vec2 g = floor(vec2(atan(EYEDIR.x, EYEDIR.z) * 180.0, y * 180.0));
	float s = step(0.9965, h(g)) * smoothstep(0.08, 0.3, y);
	c += vec3(s) * (0.4 + 0.6 * h(g + 3.1));
	COLOR = c;
}
"""
	sm.shader = sh
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#34406e")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_strength = 1.0
	e.glow_bloom = 0.02
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.fog_enabled = true
	e.fog_light_color = Color("#1b1c33")
	e.fog_density = 0.012
	e.fog_sky_affect = 0.0
	we.environment = e
	_root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#6d7fc4")
	moon.light_energy = 0.35
	moon.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-35.0), 0.0)
	_root.add_child(moon)


## The cobbles: irregular stones cut flat on top with a bevel, in dark cool greys over a black bed.
func _build_road() -> void:
	var lp := LowPoly.new(21)
	lp.vary = 0.12
	var z0 := 9.0
	var z1 := -64.0
	# the bed under the stones
	lp.quad(Vector3(-STREET_HALF - 1.0, -0.02, z0), Vector3(STREET_HALF + 1.0, -0.02, z0),
		Vector3(STREET_HALF + 1.0, -0.02, z1), Vector3(-STREET_HALF - 1.0, -0.02, z1), Color("#121119"))
	var sz := Vector2(0.52, 0.44)
	var row := 0
	var z := z0
	while z > z1:
		var off := (0.5 if row % 2 == 1 else 0.0) * sz.x
		var x := -STREET_HALF - off
		while x < STREET_HALF:
			var c := Vector3(x + lp.rand_range(-0.05, 0.05), 0.0, z + lp.rand_range(-0.04, 0.04))
			var tone := ROAD_TONE * lp.rand_range(0.72, 1.18)
			tone.a = 1.0
			if absf(c.x) > ROAD_W * 0.5 + 0.2:
				tone = tone.lerp(Color("#2c2a33"), 0.4)
			_stone(lp, c, sz * lp.rand_range(1.02, 1.12), tone)
			x += sz.x * lp.rand_range(0.94, 1.08)
		z -= sz.y * lp.rand_range(0.96, 1.04)
		row += 1
	var road := MeshInstance3D.new()
	road.name = "Cobbles"
	road.mesh = lp.commit(LowPoly.material(0.85))
	_root.add_child(road)
	# the four gold rails: the road's edges and the lane dividers, glowing in the stone
	var rl := LowPoly.new(3)
	rl.vary = 0.0
	for i in 4:
		var rx := -ROAD_W * 0.5 + ROAD_W * float(i) / 3.0
		var w := 0.04 if i == 0 or i == 3 else 0.028
		rl.quad(Vector3(rx - w, 0.1, 4.0), Vector3(rx + w, 0.1, 4.0), Vector3(rx + w, 0.1, -70.0), Vector3(rx - w, 0.1, -70.0), Color("#ffa53a"))
	var rails := MeshInstance3D.new()
	rails.name = "Rails"
	_rails_mat = LowPoly.glow_material(1.3)
	rails.mesh = rl.commit(_rails_mat)
	_root.add_child(rails)


func _stone(lp: LowPoly, c: Vector3, sz: Vector2, tone: Color) -> void:
	var n := 6
	var top: Array[Vector3] = []
	var bot: Array[Vector3] = []
	var h := 0.05 + lp.rand() * 0.03
	var ph := lp.rand() * TAU
	for i in n:
		var a := TAU * float(i) / n + ph + lp.rand_range(-0.2, 0.2)
		var r := lp.rand_range(0.84, 1.0)
		var d := Vector3(cos(a) * sz.x * 0.5 * r, 0.0, sin(a) * sz.y * 0.5 * r)
		bot.append(c + d)
		top.append(c + d * 0.84 + Vector3(0, h, 0))
	var mid := c + Vector3(0, h + 0.008, 0)
	for i in n:
		var j := (i + 1) % n
		lp.tri(mid, top[j], top[i], tone)
		lp.quad(bot[i], top[i], top[j], bot[j], tone * 0.72)


## Whitewashed houses along both sides, stepped back and up, with doors, steps, eaves and lanterns.
func _build_houses() -> void:
	var lp := LowPoly.new(33)
	lp.vary = 0.05
	var wall := Color("#b8a893")
	var dark := Color("#1a1512")
	var roof := Color("#3a2a24")
	var lantern_spots: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var z := 8.0
		var i := 0
		while z > -62.0:
			var depth := lp.rand_range(3.5, 6.5)
			var hgt := lp.rand_range(3.2, 6.2) if i % 3 != 1 else lp.rand_range(5.0, 7.5)
			var inset := lp.rand_range(0.0, 0.6)
			var x0 := side * (STREET_HALF + inset)
			var cx := x0 + side * 2.5
			var col := wall * lp.rand_range(0.82, 1.05)
			col.a = 1.0
			lp.jitter = 0.04
			lp.box(Vector3(cx, hgt * 0.5, z - depth * 0.5), Vector3(5.0, hgt, depth - 0.1), col)
			lp.jitter = 0.0
			# eaves: a dark slab along the top of the front
			lp.box(Vector3(x0 + side * 0.1, hgt + 0.08, z - depth * 0.5), Vector3(0.5, 0.18, depth + 0.1), roof)
			# a door and a step
			var dz := z - depth * lp.rand_range(0.35, 0.65)
			lp.box(Vector3(x0 - side * 0.01, 1.05, dz), Vector3(0.06, 2.1, 1.0), dark)
			lp.box(Vector3(x0 - side * 0.35, 0.09, dz), Vector3(0.7, 0.18, 1.4), col * 0.8)
			# a small dark window up high on the taller houses
			if hgt > 4.8:
				lp.box(Vector3(x0 - side * 0.01, hgt - 1.4, z - depth * 0.3), Vector3(0.06, 0.8, 0.6), dark)
			if i % 2 == 0 and z < 2.0 and z > -40.0:
				lantern_spots.append(Vector3(x0 - side * 0.25, 2.6, z - depth * 0.2))
			z -= depth
			i += 1
	var houses := MeshInstance3D.new()
	houses.name = "Houses"
	houses.mesh = lp.commit(LowPoly.material(0.95))
	_root.add_child(houses)
	# the mountains far behind the fire
	var mt := LowPoly.new(5)
	mt.vary = 0.1
	var xs := -90.0
	var prev := Vector3(xs, 0.0, -120.0)
	while xs < 90.0:
		xs += mt.rand_range(8.0, 16.0)
		var peak := Vector3(xs - mt.rand_range(3.0, 6.0), mt.rand_range(10.0, 22.0), -118.0 + mt.rand_range(-6.0, 6.0))
		var next := Vector3(xs, mt.rand_range(0.0, 5.0), -120.0)
		mt.tri(prev + Vector3(0, -2, 0), peak, next + Vector3(0, -2, 0), Color("#161a2e"))
		mt.tri(prev + Vector3(0, -2, 0), next + Vector3(0, -2, 0), Vector3((prev.x + next.x) * 0.5, -2.0, -110.0), Color("#12152a"))
		prev = next
	var mountains := MeshInstance3D.new()
	mountains.name = "Mountains"
	mountains.mesh = mt.commit(LowPoly.material(1.0))
	_root.add_child(mountains)
	# lanterns: an iron bracket and cage, glowing glass, and a warm light on the wall
	var ll := LowPoly.new(8)
	var glass := LowPoly.new(9)
	for i in lantern_spots.size():
		var p := lantern_spots[i]
		var side := signf(p.x)
		ll.box(p + Vector3(side * 0.2, 0.32, 0), Vector3(0.4, 0.04, 0.04), Color("#141414"))
		ll.prism(p + Vector3(0, 0.12, 0), 0.14, 0.02, 0.14, 4, Color("#141414"), PI * 0.25)
		ll.prism(p + Vector3(0, -0.26, 0), 0.1, 0.12, 0.05, 4, Color("#141414"), PI * 0.25)
		glass.prism(p + Vector3(0, -0.21, 0), 0.1, 0.12, 0.33, 4, Color("#ffcf7a"), PI * 0.25)
		if _lanterns.size() < 6:
			var l := OmniLight3D.new()
			l.position = p + Vector3(-side * 0.3, -0.05, 0)
			l.light_color = Color("#ffae55")
			l.omni_range = 5.5
			l.omni_attenuation = 1.4
			l.light_energy = 1.4
			_root.add_child(l)
			_lanterns.append(l)
	var lm := MeshInstance3D.new()
	lm.name = "Lanterns"
	lm.mesh = ll.commit(LowPoly.material(0.7))
	_root.add_child(lm)
	var gm := MeshInstance3D.new()
	gm.name = "LanternGlass"
	gm.mesh = glass.commit(LowPoly.glow_material(2.2))
	_root.add_child(gm)


const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float heat = 1.0;
uniform float t = 0.0;
void vertex() {
	float k = clamp(VERTEX.y / 3.0, 0.0, 1.0);
	VERTEX.x += sin(t * 6.0 + VERTEX.y * 2.3 + VERTEX.z) * 0.12 * k;
	VERTEX.z += cos(t * 5.0 + VERTEX.y * 1.7) * 0.08 * k;
}
void fragment() {
	ALBEDO = COLOR.rgb * (0.95 + 0.45 * heat);
}
"""


## The bonfire: a stack of logs leaning together, faceted flames licking up out of it, embers
## rising, and the big warm light that falls down the road.
func _build_fire() -> void:
	_fire = Node3D.new()
	_fire.name = "Bonfire"
	_root.add_child(_fire)
	var lp := LowPoly.new(41)
	lp.vary = 0.12
	for i in 14:
		var a := TAU * float(i) / 14.0 + lp.rand_range(-0.1, 0.1)
		var base := Vector3(cos(a) * 1.9, 0.0, sin(a) * 1.3)
		var tip := Vector3(cos(a) * 0.2, lp.rand_range(2.0, 2.8), sin(a) * 0.15)
		var d := tip - base
		var keep := lp.xf
		var y := d.normalized()
		var x := y.cross(Vector3.FORWARD).normalized()
		lp.xf = Transform3D(Basis(x, y, x.cross(y)), base)
		lp.prism(Vector3.ZERO, 0.13, 0.1, d.length(), 5, Color("#3a2416") * lp.rand_range(0.7, 1.2))
		lp.xf = keep
	for i in 5:
		lp.xf = Transform3D(Basis(Vector3.UP, lp.rand_range(0, PI)) * Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(lp.rand_range(-1, 1), 0.15, lp.rand_range(-0.6, 0.6)))
		lp.prism(Vector3(0, -1.2, 0), 0.14, 0.14, 2.4, 5, Color("#2a1a10"))
	lp.xf = Transform3D.IDENTITY
	lp.blob(Vector3(0, 0.1, 0), Vector3(2.0, 0.3, 1.4), Color("#ff7a1a"), 0.2)
	var logs := MeshInstance3D.new()
	logs.mesh = lp.commit(LowPoly.material(0.9))
	_fire.add_child(logs)
	# flames: nested faceted tongues, hot yellow in the heart to deep orange outside
	var fl := LowPoly.new(43)
	fl.vary = 0.15
	var cols := [Color("#d8380a"), Color("#f2621a"), Color("#ff9a2a"), Color("#ffd060")]
	for layer in 4:
		var n := 9 - layer
		var r := 1.5 - layer * 0.32
		for i in n:
			var a := TAU * float(i) / n + layer * 0.4
			var b := Vector3(cos(a) * r * 0.6, 0.3, sin(a) * r * 0.4)
			var hgt := (2.7 - layer * 0.45) * fl.rand_range(0.65, 1.1)
			fl.shard(b, Vector3(-b.x * 0.3, hgt, -b.z * 0.3), r * 0.42, cols[layer], cols[mini(layer + 1, 3)])
	_flames = MeshInstance3D.new()
	_flames.name = "Flames"
	_fire_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLAME_SHADER
	_fire_mat.shader = sh
	_flames.mesh = fl.commit(_fire_mat)
	_fire.add_child(_flames)
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 2.2, 1.5)
	_fire_light.light_color = Color("#ff9440")
	_fire_light.omni_range = 42.0
	_fire_light.omni_attenuation = 1.1
	_fire_light.light_energy = 5.5
	_fire.add_child(_fire_light)
	_embers = CPUParticles3D.new()
	_embers.name = "Embers"
	_embers.amount = 60
	_embers.lifetime = 3.2
	_embers.preprocess = 3.0
	_embers.position = Vector3(0, 2.0, 0)
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_embers.emission_box_extents = Vector3(1.0, 0.6, 0.6)
	_embers.direction = Vector3(0, 1, 0)
	_embers.spread = 18.0
	_embers.gravity = Vector3(0.15, 1.2, 0)
	_embers.initial_velocity_min = 1.0
	_embers.initial_velocity_max = 2.6
	_embers.scale_amount_min = 0.5
	_embers.scale_amount_max = 1.2
	var em := LowPoly.new(2)
	em.vary = 0.0
	em.tri(Vector3(0, 0.07, 0), Vector3(-0.05, 0, 0), Vector3(0.05, 0, 0), Color("#ffb347"))
	em.tri(Vector3(0, -0.07, 0), Vector3(0.05, 0, 0), Vector3(-0.05, 0, 0), Color("#ffb347"))
	var emat := LowPoly.glow_material(3.0)
	(emat.shader as Shader).code = (emat.shader as Shader).code.replace("cull_back", "cull_disabled")
	_embers.mesh = em.commit(emat)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.5, 1))
	ramp.set_color(1, Color(1, 0.3, 0.05, 1))
	_embers.color_ramp = ramp
	_fire.add_child(_embers)


## The two framed portraits on the walls: the Issohadore on the left, a Mamuthone on the right, each
## standing in a dark niche with a gold frame, lit from inside.
func _build_portraits() -> void:
	for side: float in [-1.0, 1.0]:
		var frame := Node3D.new()
		frame.name = "Portrait" + ("L" if side < 0.0 else "R")
		_root.add_child(frame)
		var lp := LowPoly.new(51 + int(side))
		lp.vary = 0.04
		var w := 2.3
		var h := 2.9
		lp.box(Vector3(0, h * 0.5, -0.12), Vector3(w, h, 0.12), Color("#0d0b10"))
		var fr := LowPoly.new(55)
		fr.vary = 0.0
		var t := 0.07
		for e in [[Vector3(0, h, 0), Vector3(w + t, t, 0.08)], [Vector3(0, 0, 0), Vector3(w + t, t, 0.08)],
				[Vector3(-w * 0.5, h * 0.5, 0), Vector3(t, h + t, 0.08)], [Vector3(w * 0.5, h * 0.5, 0), Vector3(t, h + t, 0.08)]]:
			fr.box(e[0], e[1], Color("#ff9a2e"))
		var back := MeshInstance3D.new()
		back.mesh = lp.commit(LowPoly.material(1.0))
		frame.add_child(back)
		var border := MeshInstance3D.new()
		border.name = "Frame"
		border.mesh = fr.commit(LowPoly.glow_material(1.6))
		frame.add_child(border)
		var l := OmniLight3D.new()
		l.position = Vector3(-side * 0.5, 2.0, 1.1)
		l.light_color = Color("#ffa050")
		l.omni_range = 3.2
		l.light_energy = 2.2
		frame.add_child(l)
		_portraits.append(frame)
	_rebuild_mamuthones()


## The Mamuthones by the fire: two to begin, more joining as the player keeps in step (unison).
func _build_fire_file() -> void:
	pass


func _rebuild_mamuthones() -> void:
	for b in _swayers:
		if is_instance_valid(b):
			b.get_parent().queue_free()
	_swayers.clear()
	_by_fire.clear()
	if _portraits.size() < 2:
		return
	var iss := Figures3D.issohadore()
	iss.position = Vector3(0.15, 0.12, 0.35)
	iss.rotation.y = 0.35
	iss.scale = Vector3.ONE * 1.28
	_portraits[0].add_child(iss)
	_swayers.append(iss.get_node("Body"))
	var mam := Figures3D.mamuthone(fleece)
	mam.position = Vector3(-0.1, 0.12, 0.35)
	mam.rotation.y = -0.35
	mam.scale = Vector3.ONE * 1.3
	_portraits[1].add_child(mam)
	_swayers.append(mam.get_node("Body"))
	for i in 2 + MAX_UNISON:
		var f := Figures3D.mamuthone(fleece, 70 + i)
		_fire.add_child(f)
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := i / 2
		f.position = Vector3(side * (2.7 + 1.1 * k), 0.0, 0.9 - 0.9 * k)
		f.rotation.y = -side * 0.25
		f.visible = i < 2 + unison
		_by_fire.append(f)
		_swayers.append(f.get_node("Body"))


## The fire and the portraits follow the road's far end (the camera solve moves it with the layout).
func _place_far_things() -> void:
	if _fire != null:
		_fire.position = Vector3(0.0, 0.0, -road_len - 2.2)
	if _portraits.size() == 2 and camera != null and camera.is_inside_tree():
		# each portrait's middle at PORTRAIT_AT of the screen (mirrored), turned toward the road
		var ps := _pixel_scale()
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			var at := Vector2(size.x * (0.5 + side * (0.5 - PORTRAIT_AT.x)), size.y * PORTRAIT_AT.y) * ps
			var mid := camera.project_position(at, PORTRAIT_DEPTH * road_len / 24.0)
			var fr := _portraits[i]
			fr.rotation = Vector3(0.0, -side * deg_to_rad(PORTRAIT_TURN), 0.0)
			fr.position = mid - fr.basis.y * 1.45
