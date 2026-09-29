class_name LowPoly
extends RefCounted
## Builds flat-shaded low-poly meshes out of simple solids: every triangle keeps its own vertices and
## its own face normal, so the light breaks into facets, and each facet's colour is nudged a little
## (seeded, so a mesh is the same every run) for the hand-cut look of the references.
##
##   var lp := LowPoly.new(seed)
##   lp.xf = Transform3D(...)            # where the next solids go (and how they are turned)
##   lp.box(centre, size, colour)        # also prism(), cone(), gem(), blob(), shard(), tri(), quad()
##   var mesh := lp.commit(material)     # one ArrayMesh surface

var xf := Transform3D.IDENTITY
var vary := 0.07                     ## how much each facet's brightness may differ (0..1)
var jitter := 0.0                    ## corners moved by up to this much (world units) in blob/box

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _rng := RandomNumberGenerator.new()


func _init(p_seed := 1) -> void:
	_rng.seed = p_seed


func rand() -> float:
	return _rng.randf()


func rand_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func is_empty() -> bool:
	return _v.is_empty()


## One facet, with (b - a) x (c - a) pointing out of the solid. (Godot's front faces wind clockwise,
## so the corners are stored as a, c, b.)
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var pa := xf * a
	var pb := xf * b
	var pc := xf * c
	var n := (pb - pa).cross(pc - pa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var k := 1.0 + _rng.randf_range(-vary, vary)
	var cc := Color(col.r * k, col.g * k, col.b * k, col.a)
	_v.append_array([pa, pc, pb])
	_n.append_array([n, n, n])
	_c.append_array([cc, cc, cc])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, b, c, col)
	tri(a, c, d, col)


## A box, optionally with its corners nudged (jitter) so it reads as cut stone or plaster.
func box(centre: Vector3, size: Vector3, col: Color, top_col := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		var s := Vector3(-1 if i & 1 == 0 else 1, -1 if i & 2 == 0 else 1, -1 if i & 4 == 0 else 1)
		var q := centre + s * h
		if jitter > 0.0:
			q += Vector3(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter, jitter))
		p.append(q)
	var tc := top_col if top_col.a > 0.0 else col
	quad(p[0], p[1], p[5], p[4], col)   # bottom (y-)
	quad(p[2], p[6], p[7], p[3], tc)    # top (y+)
	quad(p[0], p[2], p[3], p[1], col)   # z-
	quad(p[4], p[5], p[7], p[6], col)   # z+
	quad(p[0], p[4], p[6], p[2], col)   # x-
	quad(p[1], p[3], p[7], p[5], col)   # x+


## An n-sided prism or frustum standing on `base` along +y (r1 at the top; 0 makes a cone), capped.
func prism(base: Vector3, r0: float, r1: float, height: float, sides: int, col: Color, twist := 0.0, caps := true) -> void:
	var top := base + Vector3(0, height, 0)
	for i in sides:
		var a0 := TAU * float(i) / sides + twist
		var a1 := TAU * float(i + 1) / sides + twist
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		if r1 > 0.0001:
			quad(b0, top + d0 * r1, top + d1 * r1, b1, col)
			if caps:
				tri(top, top + d1 * r1, top + d0 * r1, col)
		else:
			tri(b0, top, b1, col)
		if caps:
			tri(base, b0, b1, col)


func cone(base: Vector3, r: float, height: float, sides: int, col: Color, twist := 0.0) -> void:
	prism(base, r, 0.0, height, sides, col, twist)


## A rough ball: an icosahedron (subdivided once when `fine`) with its corners nudged by `rough`.
func blob(centre: Vector3, radius: Vector3, col: Color, rough := 0.12, fine := false) -> void:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var pts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in pts.size():
		pts[i] = pts[i].normalized()
	if fine:
		var mid := {}
		var nf := []
		for f in faces:
			var m := []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not mid.has(key):
					pts.append(((pts[e[0]] + pts[e[1]]) * 0.5).normalized())
					mid[key] = pts.size() - 1
				m.append(mid[key])
			nf.append_array([[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]])
		faces = nf
	var q: Array[Vector3] = []
	for p in pts:
		q.append(centre + p * radius * (1.0 + _rng.randf_range(-rough, rough)))
	for f in faces:
		tri(q[f[0]], q[f[1]], q[f[2]], col)


## A flat-sided gem: a low n-gon plate with a bevelled top (the note shape), lying in the xz plane.
func gem(centre: Vector3, rx: float, rz: float, h: float, sides: int, col: Color, top_col: Color, bevel := 0.72) -> void:
	var top := centre + Vector3(0, h, 0)
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var ring2: Array[Vector3] = []
	for i in sides:
		var a := TAU * (float(i) + 0.5) / sides
		var d := Vector3(cos(a) * rx, 0, sin(a) * rz)
		ring0.append(centre + d)
		ring1.append(centre + d + Vector3(0, h * 0.55, 0))
		ring2.append(top + d * bevel)
	for i in sides:
		var j := (i + 1) % sides
		quad(ring0[i], ring1[i], ring1[j], ring0[j], col)
		quad(ring1[i], ring2[i], ring2[j], ring1[j], top_col.lerp(col, 0.35))
		tri(top, ring2[j], ring2[i], top_col)
		tri(centre, ring0[i], ring0[j], col)


## A tuft or spike (sheepskin locks, flames): a three-sided pyramid from `base` pointing along `dir`.
func shard(base: Vector3, dir: Vector3, width: float, col: Color, tip_col := Color(0, 0, 0, 0)) -> void:
	var fwd := dir.normalized()
	var side := fwd.cross(Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(fwd).normalized()
	var tip := base + dir
	var a := base + side * width
	var b := base - side * width * 0.5 + up * width * 0.87
	var c := base - side * width * 0.5 - up * width * 0.87
	var tc := tip_col if tip_col.a > 0.0 else col
	tri(a, tip, b, tc)
	tri(b, tip, c, col)
	tri(c, tip, a, col.lerp(tc, 0.5))
	tri(a, b, c, col)


func commit(material: Material = null) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh


## The facet material every solid uses: its vertex colours lit by the scene's lights.
static func material(rough := 0.92, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = 0.25
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = emission
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	return m


## Glowing facets (flames, lantern glass, notes): unshaded vertex colours, brighter than 1 for the glow.
static func glow_material(energy := 1.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float energy = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("energy", energy)
	return m
