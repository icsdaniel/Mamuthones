class_name NoteField3D
extends Node3D
## The notes riding the road in 3D, drawn from LaneView's own list of what is on screen (so timing,
## hopping and every rule stay LaneView's): faceted glowing gems, the brightest things in the street.
## Each kind of thing is one MultiMesh, refreshed every frame.
##
##   step      gold gem with a red diamond set in it
##   call      red gem with a gold diamond (the Issohadore's call, and off-beat steps)
##   heal      bone-white gem with a flame in it
##   hold      gold gem with the rope's ring on it, the rope lying down the lane, a knot at its end
##   stomp     a wide fire-red slab with two bone thumb prints
##   bell      a bar across the road with chevrons the way to tilt (gold up, steel down) and a medallion
##   rest      a dim blue band across the lanes (the stand-still)
## plus the hit line with a receptor per lane, faint beat lines coming down the road, and bursts.

const TILT := 0.85                  ## radians a gem is tipped up toward the player, so it reads far off
const HOP_LIFT := 0.32              ## world units a note rises at the top of its hop
const MAX := 48

const GOLD := Color("#ffc445")
const GOLD_TOP := Color("#fff0b8")
const RED := Color("#e8322a")
const BONE := Color("#f4ecd8")
const STEEL := Color("#8fb0e0")
const STILL_BLUE := Color("#4f7fd8")
const ROPE := Color("#e0a940")

var world: PlayWorld

var _mm := {}                       ## kind -> MultiMeshInstance3D
var _count := {}                    ## kind -> instances used this frame
var _hit_bar: MeshInstance3D
var _hit_mat: ShaderMaterial
var _bursts: Array[CPUParticles3D] = []
var _rings: Array = []              ## [MeshInstance3D, ShaderMaterial, t0, colour, scale]
var _burst_next := 0
var _clock := 0.0


func _ready() -> void:
	_make("step", _gem_mesh(GOLD, GOLD_TOP, RED, 0.36))
	_make("call", _gem_mesh(RED, Color("#ff8a6a"), GOLD, 0.36))
	_make("off", _gem_mesh(RED, Color("#ff8a6a"), GOLD, 0.29))
	_make("heal", _gem_mesh(BONE, Color.WHITE, Color("#ff7a1a"), 0.36))
	_make("hold", _hold_mesh())
	_make("knot", _knot_mesh())
	_make("stomp", _stomp_mesh())
	_make("bar_up", _bar_mesh(true))
	_make("bar_down", _bar_mesh(false))
	_make("badge_up", _badge_mesh(true))
	_make("badge_down", _badge_mesh(false))
	_make("sash", _flat_quad(0.3, ROPE), 1.0)
	_make("band", _flat_quad(1.0, STILL_BLUE), 1.0, true)
	_make("beat", _flat_quad(1.0, Color("#ffb04a")), 1.0)
	_make("receptor", _receptor_mesh(), 1.0)
	_make("shadow", _shadow_mesh(), 1.0, true)
	var lp := LowPoly.new(5)
	lp.vary = 0.0
	lp.box(Vector3(0, 0.1, 0), Vector3(PlayWorld.ROAD_W + 0.3, 0.04, 0.05), Color("#ffb44a"))
	_hit_bar = MeshInstance3D.new()
	_hit_bar.name = "HitLine"
	_hit_mat = LowPoly.glow_material(1.2)
	_hit_bar.mesh = lp.commit(_hit_mat)
	add_child(_hit_bar)
	for i in 8:
		var p := _burst_particles()
		add_child(p)
		_bursts.append(p)


func _make(kind: String, mesh: Mesh, energy := 2.2, transparent := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = kind.capitalize()
	mi.multimesh = mm
	mi.material_override = _note_material(energy, transparent)
	add_child(mi)
	_mm[kind] = mi


static func _note_material(energy: float, transparent: bool) -> ShaderMaterial:
	var sh := Shader.new()
	var mode := "unshaded, cull_disabled" + (", blend_mix, depth_draw_never" if transparent else "")
	sh.code = """
shader_type spatial;
render_mode %s;
uniform float energy = 2.0;
void fragment() {
	ALBEDO = COLOR.rgb * energy;
	%s
}
""" % [mode, "ALPHA = COLOR.a;" if transparent else ""]
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("energy", energy)
	return m


func _put(kind: String, xf: Transform3D, col := Color.WHITE) -> void:
	var mi: MultiMeshInstance3D = _mm[kind]
	var i: int = _count.get(kind, 0)
	if i >= MAX:
		return
	mi.multimesh.set_instance_transform(i, xf)
	mi.multimesh.set_instance_color(i, col)
	_count[kind] = i + 1


## Called by the world every frame, after the camera is placed.
func refresh(delta: float) -> void:
	_clock += delta
	_count.clear()
	var lanes := world.lanes
	if lanes != null and lanes.session != null and lanes.visible:
		_place_notes(lanes)
	for kind in _mm:
		(_mm[kind] as MultiMeshInstance3D).multimesh.visible_instance_count = _count.get(kind, 0)
	_hit_bar.visible = lanes != null and lanes.visible
	if lanes != null:
		_hit_mat.set_shader_parameter("energy", 1.0 + 0.9 * lanes.beat_env())
	_age_rings()


func _gem_basis(sc := 1.0) -> Basis:
	return Basis(Vector3.RIGHT, -TILT).scaled(Vector3.ONE * sc)


func _place_notes(lanes: LaneView) -> void:
	var field := lanes.field_rect()
	field.position = Vector2.ZERO
	var rects := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	# the hit line's receptors: one per lane, lit when pressed, bright when a note is near
	for lane in 3:
		var p := world.flat_to_world(Vector2(rects[lane].get_center().x, hl), 0.02)
		var g := lanes._lane_glow(lane)
		var cue := 0.35 if lanes._cued(lane) else 0.0
		var k := 0.3 + 0.2 * lanes.beat_env() + cue + 0.7 * g
		_put("receptor", Transform3D(Basis(), p), Color(k, k * 0.8, k * 0.5))
	_place_beats(lanes, field, hl)
	var now_b := lanes._now_beat() if lanes.spb > 0.0 else 0.0
	for e in lanes._notes_shown(field):
		var n: Note = e[0]
		var y: float = e[1]
		var fade := lanes._haze(y, field)
		var dimk := lerpf(0.25, 1.0, fade)
		var lift := 0.0
		if lanes.hopping() and not n.done and not UIKit.reduced_motion():
			lift = LaneView.hop_arc(now_b, LaneView.hop_grid((n.t - lanes.beat_zero) / lanes.spb)) * HOP_LIFT
		var col := Color(dimk, dimk, dimk, fade)
		match n.kind:
			Note.Kind.STEP:
				if n.done:
					continue
				var p := world.flat_to_world(Vector2(rects[n.lane].get_center().x, y), 0.04 + lift)
				_shadow(p, lift, 0.34)
				var kind := "heal" if n.heal else ("call" if n.call else ("off" if lanes._off_beat(n) else "step"))
				_put(kind, Transform3D(_gem_basis(), p), col)
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var cx := rects[n.lane].get_center().x
				var head := minf(y, hl) if n.holding else y
				var tail: float = e[2]
				var a := world.flat_to_world(Vector2(cx, maxf(tail, 0.0)), 0.03)
				var b := world.flat_to_world(Vector2(cx, head), 0.03)
				if b.z - a.z > 0.01:
					var lit := 1.6 if n.holding else 0.8
					_put("sash", Transform3D(Basis().scaled(Vector3(1.0, 1.0, b.z - a.z)), (a + b) * 0.5), Color(lit * dimk, lit * dimk, lit * dimk))
				if tail > 0.0:
					_put("knot", Transform3D(_gem_basis(), a + Vector3(0, 0.05, 0)), Color(dimk, dimk, dimk))
				var hp := b + Vector3(0, 0.02 + (lift if not n.holding else 0.0), 0)
				_shadow(b, lift if not n.holding else 0.0, 0.34)
				_put("hold", Transform3D(_gem_basis(), hp), col)
			Note.Kind.BELL, Note.Kind.RING:
				if n.done:
					continue
				var p := world.flat_to_world(Vector2(field.get_center().x, y), 0.02)
				_put("bar_up" if n.up else "bar_down", Transform3D(Basis(), p), col)
				if n.kind == Note.Kind.BELL or n.lane != 1:
					_put("badge_up" if n.up else "badge_down", Transform3D(_gem_basis(), p + Vector3(0, 0.3, 0)), col)
				if n.kind == Note.Kind.RING:
					var q := world.flat_to_world(Vector2(rects[n.lane].get_center().x, y), 0.14)
					_put("step", Transform3D(_gem_basis(), q), col)
			Note.Kind.STOMP:
				if n.done:
					continue
				var p := world.flat_to_world(Vector2(rects[n.lane].get_center().x, y), 0.05 + lift)
				_shadow(p, lift, 0.5)
				var k := 0.6 if n.thumbs > 0 else 1.0
				_put("stomp", Transform3D(_gem_basis(), p), Color(col.r * k, col.g * k, col.b * k))
			Note.Kind.REST:
				if n.finished:
					continue
				var a := world.flat_to_world(Vector2(field.get_center().x, maxf(minf(y, e[2]), 0.0)), 0.015)
				var b := world.flat_to_world(Vector2(field.get_center().x, minf(maxf(y, e[2]), hl)), 0.015)
				if b.z - a.z > 0.05:
					_put("band", Transform3D(Basis().scaled(Vector3(PlayWorld.ROAD_W, 1.0, b.z - a.z)), (a + b) * 0.5), Color(0.35, 0.55, 1.0, 0.16 * fade))


## A shadow on the stones under a hopping note, smaller and fainter the higher it is.
func _shadow(p: Vector3, lift: float, r: float) -> void:
	if lift <= 0.01:
		return
	var k := clampf(lift / HOP_LIFT, 0.0, 1.0)
	var s := r * (1.0 - 0.25 * k)
	_put("shadow", Transform3D(Basis().scaled(Vector3(s, 1.0, s * 0.6)), Vector3(p.x, 0.07, p.z)), Color(0, 0, 0, 0.55 - 0.25 * k))


## Faint lines across the lanes on every beat, riding down with the notes (the bar's first brighter).
func _place_beats(lanes: LaneView, field: Rect2, hl: float) -> void:
	if lanes.spb <= 0.0 or lanes.beat <= -999.0:
		return
	var now := lanes.song_time
	var b0 := ceilf((now - lanes.beat_zero) / lanes.spb)
	for k in 12:
		var b := b0 + k
		var t := lanes.beat_zero + b * lanes.spb
		var y := lanes.event_y(field, t, lanes._px_per_s())
		if y < field.size.y * 0.04:
			break
		if y > hl:
			continue
		var p := world.flat_to_world(Vector2(field.get_center().x, y), 0.03)
		var down := posmod(int(b), 4) == 0
		var a := lanes._haze(y, field) * (0.5 if down else 0.28)
		_put("beat", Transform3D(Basis().scaled(Vector3(PlayWorld.ROAD_W, 1.0, 0.05 if down else 0.03)), p), Color(a, a, a))


# ------------------------------------------------------------------ bursts

## A hit burst at a world point: sparks thrown up and out, and a ring spreading over the stones.
func burst(p: Vector3, quality: String, big := false) -> void:
	var col: Color = {
		"perfect": Color("#fff4c0"), "good": Color("#ffc445"), "ok": Color("#ff8a2a"), "early": Color("#ff8a2a"),
		"late": Color("#ff8a2a"), "heal": Color("#fff8ea"), "held": Color("#8fb8ff"), "stomp": Color("#ff6a2a"),
	}.get(quality, Color("#ffc445"))
	var ps := _bursts[_burst_next]
	_burst_next = (_burst_next + 1) % _bursts.size()
	ps.position = p + Vector3(0, 0.15, 0)
	ps.amount = 36 if big else 22
	ps.initial_velocity_max = 5.5 if big else 3.6
	ps.color = col
	ps.restart()
	ps.emitting = true
	_ring(p, col, 2.2 if big else 1.0)


func _burst_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 22
	p.lifetime = 0.45
	p.direction = Vector3(0, 1, 0.2)
	p.spread = 70.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.6
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	p.scale_amount_curve = sc
	var lp := LowPoly.new(4)
	lp.vary = 0.0
	lp.blob(Vector3.ZERO, Vector3(0.05, 0.05, 0.05), Color.WHITE, 0.0)
	var m := _note_material(3.0, false)
	p.mesh = lp.commit(m)
	return p


func _ring(p: Vector3, col: Color, sc: float) -> void:
	var mi: MeshInstance3D
	var mat: ShaderMaterial
	for r in _rings:
		if _clock - float(r[2]) > 0.4:
			mi = r[0]
			mat = r[1]
			_rings.erase(r)
			break
	if mi == null:
		mi = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float age = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = mix(0.35, 1.0, age);
	float w = mix(0.2, 0.06, age);
	float a = smoothstep(w, 0.0, abs(d - r)) * (1.0 - age);
	ALBEDO = col.rgb * 2.5 * a;
}
"""
		mat.shader = sh
		mi.material_override = mat
		add_child(mi)
	mi.position = p + Vector3(0, 0.08, 0)
	mi.scale = Vector3.ONE * 1.3 * sc
	mi.visible = true
	mat.set_shader_parameter("col", col)
	mat.set_shader_parameter("age", 0.0)
	_rings.append([mi, mat, _clock, col, sc])


func _age_rings() -> void:
	for r in _rings:
		var age := (_clock - float(r[2])) / 0.35
		(r[1] as ShaderMaterial).set_shader_parameter("age", clampf(age, 0.0, 1.0))
		(r[0] as MeshInstance3D).visible = age < 1.0


# ------------------------------------------------------------------ the meshes

## A note gem: a six-sided faceted plate (width 2 * rx), an inlaid diamond on its face.
func _gem_mesh(body: Color, top: Color, inlay: Color, rx: float) -> ArrayMesh:
	var lp := LowPoly.new(61)
	lp.vary = 0.1
	lp.gem(Vector3.ZERO, rx, rx * 0.62, 0.13, 6, body.darkened(0.3), top, 0.7)
	# the diamond inlay on top
	var y := 0.131
	var d := rx * 0.34
	lp.tri(Vector3(0, y + 0.02, 0), Vector3(d, y, 0), Vector3(0, y, -d * 0.62), inlay.lightened(0.15))
	lp.tri(Vector3(0, y + 0.02, 0), Vector3(0, y, -d * 0.62), Vector3(-d, y, 0), inlay)
	lp.tri(Vector3(0, y + 0.02, 0), Vector3(-d, y, 0), Vector3(0, y, d * 0.62), inlay.darkened(0.1))
	lp.tri(Vector3(0, y + 0.02, 0), Vector3(0, y, d * 0.62), Vector3(d, y, 0), inlay.darkened(0.2))
	return lp.commit()


func _hold_mesh() -> ArrayMesh:
	var lp := LowPoly.new(62)
	lp.vary = 0.1
	lp.gem(Vector3.ZERO, 0.36, 0.22, 0.13, 6, GOLD.darkened(0.3), GOLD_TOP, 0.7)
	# the rope's ring lying on the gem
	for i in 10:
		var a0 := TAU * float(i) / 10.0
		var a1 := TAU * float(i + 1) / 10.0
		var r := 0.14
		var p0 := Vector3(cos(a0) * r, 0.14, sin(a0) * r * 0.62)
		var p1 := Vector3(cos(a1) * r, 0.14, sin(a1) * r * 0.62)
		var o0 := p0 * Vector3(1.4, 1, 1.4)
		var o1 := p1 * Vector3(1.4, 1, 1.4)
		o0.y = 0.14
		o1.y = 0.14
		lp.quad(p0, p1, o1 + Vector3(0, 0.015, 0), o0 + Vector3(0, 0.015, 0), Color("#8a4a18"))
	return lp.commit()


func _knot_mesh() -> ArrayMesh:
	var lp := LowPoly.new(63)
	lp.blob(Vector3(0, 0.06, 0), Vector3(0.14, 0.08, 0.1), ROPE, 0.15)
	return lp.commit()


func _stomp_mesh() -> ArrayMesh:
	var lp := LowPoly.new(64)
	lp.vary = 0.1
	lp.gem(Vector3.ZERO, 0.42, 0.26, 0.18, 8, Color("#c8281c"), Color("#ff7a2a"), 0.8)
	for sx: float in [-1.0, 1.0]:
		lp.gem(Vector3(0.12 * sx, 0.18, 0), 0.07, 0.1, 0.02, 7, BONE.darkened(0.1), BONE, 0.7)
	return lp.commit()


## The bell bar across the road: a raised beam with chevrons pointing the way to tilt.
func _bar_mesh(up: bool) -> ArrayMesh:
	var lp := LowPoly.new(65)
	lp.vary = 0.06
	var col := GOLD if up else STEEL
	var w := PlayWorld.ROAD_W * 0.5 + 0.1
	lp.box(Vector3(0, 0.05, 0), Vector3(w * 2.0, 0.1, 0.22), col.darkened(0.35), col)
	var d := -1.0 if up else 1.0
	var x := -w + 0.3
	while x < w - 0.2:
		if absf(x) > 0.34:
			lp.tri(Vector3(x - 0.09, 0.105, -d * 0.06), Vector3(x + 0.09, 0.105, -d * 0.06), Vector3(x, 0.105, d * 0.08), Color.WHITE if up else Color("#e0f0ff"))
		x += 0.3
	for sx: float in [-1.0, 1.0]:
		lp.box(Vector3(sx * w, 0.08, 0), Vector3(0.12, 0.16, 0.3), col.darkened(0.2), col.lightened(0.2))
	return lp.commit()


## The bar's medallion: a round faceted plate, red for raising the bells and navy for lowering them,
## with a bone arrow the way to tilt.
func _badge_mesh(up: bool) -> ArrayMesh:
	var lp := LowPoly.new(66)
	lp.vary = 0.08
	var rim := GOLD if up else STEEL
	var face := RED if up else Color("#23407a")
	lp.gem(Vector3.ZERO, 0.3, 0.3, 0.06, 10, rim.darkened(0.2), rim, 0.95)
	lp.gem(Vector3(0, 0.06, 0), 0.23, 0.23, 0.02, 10, face, face.lightened(0.1), 0.95)
	var d := -1.0 if up else 1.0
	var y := 0.085
	lp.tri(Vector3(0, y, d * 0.16), Vector3(-0.12, y, 0.0), Vector3(0.12, y, 0.0), BONE)
	lp.quad(Vector3(-0.05, y, 0.0), Vector3(0.05, y, 0.0), Vector3(0.05, y, -d * 0.12), Vector3(-0.05, y, -d * 0.12), BONE)
	return lp.commit()


## A flat quad lying on the road, `w` wide and one unit long (scaled per instance).
func _flat_quad(w: float, col: Color) -> ArrayMesh:
	var lp := LowPoly.new(67)
	lp.vary = 0.0
	lp.quad(Vector3(-w * 0.5, 0, 0.5), Vector3(w * 0.5, 0, 0.5), Vector3(w * 0.5, 0, -0.5), Vector3(-w * 0.5, 0, -0.5), col)
	return lp.commit()


func _receptor_mesh() -> ArrayMesh:
	var lp := LowPoly.new(68)
	lp.vary = 0.0
	var n := 6
	for i in n:
		var a0 := TAU * (float(i) + 0.5) / n
		var a1 := TAU * (float(i) + 1.5) / n
		var o0 := Vector3(cos(a0) * 0.36, 0, sin(a0) * 0.22)
		var o1 := Vector3(cos(a1) * 0.36, 0, sin(a1) * 0.22)
		lp.quad(o0 * 0.82, o0, o1, o1 * 0.82, Color("#ffd27a"))
	return lp.commit()


func _shadow_mesh() -> ArrayMesh:
	var lp := LowPoly.new(69)
	lp.vary = 0.0
	for i in 10:
		var a0 := TAU * float(i) / 10.0
		var a1 := TAU * float(i + 1) / 10.0
		lp.tri(Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1), 0, sin(a1)), Color.WHITE)
	return lp.commit()
