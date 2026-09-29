class_name Figures3D
extends RefCounted
## The low-poly Mamuthone and Issohadore (mockups/lowpoly/*_turnaround.png), built from LowPoly
## solids. Each figure is a Node3D standing on its origin, facing +z, about 1.9 units tall:
##   Figure (Node3D)
##     Body (Node3D, pivot at the feet: the whole figure sways from here)
##       Mesh
##       Bells (Node3D, pivot at the shoulders: the back bells swing a little behind the sway)
## The Mamuthone wears black sheepskin as the tradition has it (the reference's brown is a colour
## option, `fleece`), a dark wooden mask under a brown kerchief, crossed leather straps, small bells
## on the chest and a heavy load of bronze bells on the back.

const FLEECE := {
	"black": [Color("#16120f"), Color("#2b231e")],
	"dark_brown": [Color("#2a1810"), Color("#4a2c1c")],
	"brown": [Color("#3d2416"), Color("#6a3f24")],
}
const MASK_WOOD := Color("#2a1a12")
const KERCHIEF := Color("#3a2419")
const LEATHER := Color("#8c5a30")
const BRONZE := Color("#b8903f")
const BRONZE_DARK := Color("#6e5222")
const BOOT := Color("#1c1512")


static func _bronze_material() -> StandardMaterial3D:
	var m := LowPoly.material(0.45)
	m.metallic = 0.55
	m.metallic_specular = 0.6
	return m


## A bell hanging mouth down from `top`: a flared, open frustum, low-poly.
static func _bell(lp: LowPoly, top: Vector3, size: float, tilt := Basis()) -> void:
	var keep := lp.xf
	lp.xf = keep * Transform3D(tilt, top)
	lp.prism(Vector3(0, -size * 1.1, 0), size * 0.62, size * 0.42, size * 1.1, 7, BRONZE, 0.0, false)
	lp.prism(Vector3(0, -size * 1.1, 0), size * 0.52, size * 0.62, 0.0001, 7, BRONZE_DARK, 0.0, false)
	lp.tri(Vector3(0, -size * 1.0, 0), Vector3(size * 0.3, -size * 1.05, 0), Vector3(0, -size * 1.05, size * 0.3), BRONZE_DARK)
	lp.prism(Vector3(0, 0, 0), size * 0.42, size * 0.3, size * 0.12, 7, BRONZE)
	lp.xf = keep


## A campanaccio, the big back bell: a wide open frustum pointing out along `dir`, mouth showing.
static func _big_bell(lp: LowPoly, at: Vector3, dir: Vector3, size: float) -> void:
	var keep := lp.xf
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	lp.xf = keep * Transform3D(Basis(x, y, z), at)
	lp.prism(Vector3.ZERO, size * 0.62, size * 0.78, size * 1.25, 8, BRONZE, 0.2, false)
	# the rim and the dark mouth, a little way in
	lp.prism(Vector3(0, size * 1.25, 0), size * 0.78, size * 0.66, 0.0001, 8, BRONZE_DARK, 0.2, false)
	lp.prism(Vector3(0, size * 1.05, 0), size * 0.66, size * 0.66, size * 0.2, 8, Color("#2a1d0c"), 0.2, false)
	for i in 8:
		var a0 := TAU * float(i) / 8.0 + 0.2
		var a1 := TAU * float(i + 1) / 8.0 + 0.2
		lp.tri(Vector3(0, size * 1.05, 0), Vector3(cos(a1), 0, sin(a1)) * size * 0.66 + Vector3(0, size * 1.05, 0),
			Vector3(cos(a0), 0, sin(a0)) * size * 0.66 + Vector3(0, size * 1.05, 0), Color("#140e06"))
	lp.cone(Vector3(0, 0, 0), size * 0.62, -size * 0.25, 8, BRONZE_DARK, 0.2)
	lp.xf = keep


static func mamuthone(fleece := "black", p_seed := 7) -> Node3D:
	var fc: Array = FLEECE.get(fleece, FLEECE.black)
	var dark: Color = fc[0]
	var tip: Color = fc[1]
	var root := Node3D.new()
	root.name = "Mamuthone"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var lp := LowPoly.new(p_seed)
	lp.vary = 0.1
	# boots and legs
	for sx: float in [-1.0, 1.0]:
		lp.box(Vector3(0.2 * sx, 0.07, 0.05), Vector3(0.24, 0.14, 0.36), BOOT)
		lp.prism(Vector3(0.2 * sx, 0.1, 0.0), 0.12, 0.13, 0.5, 6, Color("#241b16"))
	# the fleece: a stout core, then tufts all over it, pointing out and down
	lp.prism(Vector3(0, 0.5, 0), 0.4, 0.38, 0.95, 8, dark)
	lp.jitter = 0.0
	var rows := 9
	for r in rows:
		var y := 0.52 + float(r) * 0.105
		var rad := 0.4 + 0.07 * sin(float(r) / rows * PI) + (0.04 if r > rows - 3 else 0.0)
		var n := 13
		for i in n:
			var a := TAU * (float(i) + 0.5 * (r % 2)) / n + lp.rand_range(-0.08, 0.08)
			var out := Vector3(cos(a), 0, sin(a))
			var base := Vector3(out.x * rad * 0.85, y, out.z * rad * 0.85)
			var d := out * lp.rand_range(0.12, 0.2) + Vector3(0, -lp.rand_range(0.18, 0.28), 0)
			lp.shard(base, d, lp.rand_range(0.07, 0.1), dark, tip)
	# arms: fleece sleeves and dark hands
	for sx: float in [-1.0, 1.0]:
		var sh := Vector3(0.44 * sx, 1.36, 0.0)
		lp.prism(sh + Vector3(0.04 * sx, -0.62, 0.02), 0.11, 0.14, 0.62, 6, dark)
		for k in 5:
			var y := -0.1 - 0.11 * k
			var a := lp.rand_range(0, TAU)
			lp.shard(sh + Vector3(0.05 * sx, y, 0), Vector3(0.1 * sx + cos(a) * 0.05, -0.2, sin(a) * 0.1), 0.07, dark, tip)
		lp.blob(sh + Vector3(0.05 * sx, -0.68, 0.04), Vector3(0.09, 0.1, 0.09), Color("#1b1310"), 0.1)
	# shoulders
	lp.blob(Vector3(0, 1.38, 0), Vector3(0.5, 0.18, 0.34), dark, 0.1)
	for i in 10:
		var a := TAU * float(i) / 10.0
		lp.shard(Vector3(cos(a) * 0.4, 1.4, sin(a) * 0.26), Vector3(cos(a) * 0.14, -0.2, sin(a) * 0.1), 0.09, dark, tip)
	# head: the kerchief hood, and the dark wooden mask in front
	lp.blob(Vector3(0, 1.64, -0.03), Vector3(0.2, 0.25, 0.21), KERCHIEF, 0.08)
	lp.prism(Vector3(0, 1.43, -0.02), 0.2, 0.17, 0.14, 6, KERCHIEF)
	lp.jitter = 0.012
	lp.box(Vector3(0, 1.62, 0.15), Vector3(0.24, 0.3, 0.1), MASK_WOOD)
	lp.jitter = 0.0
	lp.box(Vector3(0, 1.71, 0.2), Vector3(0.22, 0.05, 0.04), MASK_WOOD.lightened(0.05))
	lp.tri(Vector3(0, 1.69, 0.2), Vector3(-0.035, 1.56, 0.21), Vector3(0.0, 1.57, 0.27), MASK_WOOD.lightened(0.08))
	lp.tri(Vector3(0, 1.69, 0.2), Vector3(0.0, 1.57, 0.27), Vector3(0.035, 1.56, 0.21), MASK_WOOD.lightened(0.02))
	lp.box(Vector3(0, 1.51, 0.2), Vector3(0.1, 0.02, 0.02), Color("#120b08"))
	for sx: float in [-1.0, 1.0]:
		lp.box(Vector3(0.06 * sx, 1.66, 0.205), Vector3(0.05, 0.025, 0.02), Color("#0c0806"))
	# crossed straps over the chest and a belt
	for sx: float in [-1.0, 1.0]:
		var keep := lp.xf
		lp.xf = keep * Transform3D(Basis(Vector3(0, 0, 1), 0.62 * sx), Vector3(0, 1.1, 0.4))
		lp.box(Vector3.ZERO, Vector3(0.09, 0.78, 0.04), LEATHER)
		lp.xf = keep
	lp.box(Vector3(0, 0.98, 0.39), Vector3(0.62, 0.08, 0.05), LEATHER)
	lp.box(Vector3(0, 0.98, 0.42), Vector3(0.09, 0.09, 0.02), BRONZE)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = lp.commit(LowPoly.material())
	body.add_child(mesh)
	# the chest bells
	var bl := LowPoly.new(p_seed + 1)
	for i in 4:
		var x := -0.18 + 0.12 * i
		_bell(bl, Vector3(x, 0.93 - 0.03 * absf(i - 1.5), 0.43), 0.1 + 0.015 * (i % 2))
	var chest := MeshInstance3D.new()
	chest.name = "ChestBells"
	chest.mesh = bl.commit(_bronze_material())
	body.add_child(chest)
	# the back bells, on their own pivot at the shoulders
	var bells := Node3D.new()
	bells.name = "Bells"
	bells.position = Vector3(0, 1.3, -0.1)
	body.add_child(bells)
	var bb := LowPoly.new(p_seed + 2)
	var spots := [[-0.22, 0.12], [0.22, 0.12], [-0.34, -0.12], [0.34, -0.12], [0.0, -0.08], [-0.18, -0.34],
		[0.18, -0.34], [0.0, -0.55], [-0.38, 0.28], [0.38, 0.28], [-0.32, -0.5], [0.32, -0.5]]
	for s in spots:
		var at := Vector3(s[0], s[1], -0.34)
		var d := Vector3(s[0] * 0.9, 0.35 + s[1] * 0.4, -0.75)
		_big_bell(bb, at, d, 0.16)
	bb.box(Vector3(0, -0.2, -0.32), Vector3(0.1, 0.7, 0.04), LEATHER)
	bb.box(Vector3(0, -0.2, -0.32), Vector3(0.7, 0.07, 0.04), LEATHER)
	var back := MeshInstance3D.new()
	back.name = "BackBells"
	back.mesh = bb.commit(_bronze_material())
	bells.add_child(back)
	return root


const RED := Color("#b8201e")
const WHITE := Color("#e8e0d2")
const BLACK := Color("#141212")
const ROPE := Color("#c9a04a")


static func issohadore(p_seed := 11) -> Node3D:
	var root := Node3D.new()
	root.name = "Issohadore"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var lp := LowPoly.new(p_seed)
	lp.vary = 0.08
	# boots, white trousers
	for sx: float in [-1.0, 1.0]:
		lp.box(Vector3(0.14 * sx, 0.06, 0.05), Vector3(0.18, 0.12, 0.32), BLACK)
		lp.prism(Vector3(0.14 * sx, 0.1, 0.0), 0.1, 0.11, 0.4, 6, BLACK)
		lp.prism(Vector3(0.14 * sx, 0.48, 0.0), 0.11, 0.14, 0.34, 6, WHITE)
	# the black fringed shawl round the hips
	lp.prism(Vector3(0, 0.66, 0), 0.34, 0.27, 0.3, 10, BLACK)
	lp.prism(Vector3(0, 0.5, 0), 0.36, 0.34, 0.18, 12, BLACK.lightened(0.03), 0.1, false)
	for i in 28:
		var a := TAU * float(i) / 28.0
		var o := Vector3(cos(a), 0, sin(a))
		var keep := lp.xf
		lp.xf = keep * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), o * 0.36 + Vector3(0, 0.52, 0))
		lp.box(Vector3.ZERO, Vector3(0.07, 0.2, 0.025), BLACK.lightened(0.05))
		lp.xf = keep
	# the red jacket, white collar and cuffs
	lp.prism(Vector3(0, 0.9, 0), 0.27, 0.33, 0.5, 8, RED)
	lp.blob(Vector3(0, 1.36, 0), Vector3(0.36, 0.1, 0.22), RED, 0.05)
	lp.box(Vector3(0, 1.43, 0.08), Vector3(0.2, 0.08, 0.12), WHITE)
	for sx: float in [-1.0, 1.0]:
		var keep := lp.xf
		lp.xf = keep * Transform3D(Basis(Vector3(1, 0, 0), -0.5), Vector3(0.36 * sx, 1.34, 0.0))
		lp.prism(Vector3(0, -0.5, 0), 0.1, 0.12, 0.5, 6, RED)
		lp.prism(Vector3(0, -0.56, 0), 0.08, 0.1, 0.07, 6, WHITE)
		lp.blob(Vector3(0, -0.64, 0), Vector3(0.07, 0.08, 0.07), Color("#c89a78"), 0.08)
		lp.xf = keep
	# the bandolier of little bells over the left shoulder
	var keep2 := lp.xf
	lp.xf = keep2 * Transform3D(Basis(Vector3(0, 0, 1), -0.75), Vector3(0.02, 1.12, 0.3))
	lp.box(Vector3.ZERO, Vector3(0.09, 0.8, 0.05), BLACK)
	lp.xf = keep2
	# head: the white mask, the black beret and the red ribbon tied under the chin
	lp.blob(Vector3(0, 1.62, -0.02), Vector3(0.15, 0.17, 0.15), Color("#1d1a19"), 0.06)
	lp.jitter = 0.01
	lp.box(Vector3(0, 1.62, 0.1), Vector3(0.21, 0.27, 0.08), Color("#f2eee6"))
	lp.jitter = 0.0
	lp.tri(Vector3(0, 1.65, 0.14), Vector3(-0.03, 1.56, 0.145), Vector3(0, 1.57, 0.19), Color("#e4ddd0"))
	lp.tri(Vector3(0, 1.65, 0.14), Vector3(0, 1.57, 0.19), Vector3(0.03, 1.56, 0.145), Color("#fbf8f2"))
	for sx: float in [-1.0, 1.0]:
		lp.box(Vector3(0.05 * sx, 1.65, 0.145), Vector3(0.045, 0.03, 0.01), Color("#0a0808"))
		lp.box(Vector3(0.115 * sx, 1.6, 0.06), Vector3(0.03, 0.26, 0.1), RED)
	lp.box(Vector3(0, 1.5, 0.145), Vector3(0.05, 0.015, 0.01), Color("#9a2020"))
	lp.prism(Vector3(0, 1.74, -0.02), 0.2, 0.24, 0.1, 9, BLACK)
	lp.blob(Vector3(0, 1.83, -0.03), Vector3(0.22, 0.06, 0.2), BLACK, 0.1)
	lp.blob(Vector3(0, 1.88, -0.02), Vector3(0.06, 0.05, 0.06), RED, 0.1)
	lp.box(Vector3(0, 1.64, -0.18), Vector3(0.08, 0.3, 0.04), RED)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = lp.commit(LowPoly.material())
	body.add_child(mesh)
	# brass bells on the bandolier
	var bl := LowPoly.new(p_seed + 1)
	for i in 6:
		var t := -0.34 + 0.13 * i
		var p := Vector3(0.02 - sin(0.75) * t, 1.12 + cos(0.75) * t, 0.34)
		bl.blob(p, Vector3(0.045, 0.045, 0.045), BRONZE, 0.1)
	var bells := MeshInstance3D.new()
	bells.name = "Bells"
	bells.mesh = bl.commit(_bronze_material())
	body.add_child(bells)
	# the rope (sa soga), coiled in both hands in front of the hips
	var rp := LowPoly.new(p_seed + 2)
	rp.vary = 0.05
	for loop in 3:
		var c := Vector3(0.06 + 0.03 * loop, 0.72 - 0.05 * loop, 0.34)
		var r := 0.2 + 0.03 * loop
		var seg := 14
		for i in seg:
			var a0 := TAU * float(i) / seg
			var a1 := TAU * float(i + 1) / seg
			var p0 := c + Vector3(cos(a0) * r, sin(a0) * r * 1.2, sin(a0) * 0.04)
			var p1 := c + Vector3(cos(a1) * r, sin(a1) * r * 1.2, sin(a1) * 0.04)
			var keep := rp.xf
			var d := p1 - p0
			var yb := d.normalized()
			var xb := yb.cross(Vector3.FORWARD).normalized()
			var zb := xb.cross(yb)
			rp.xf = keep * Transform3D(Basis(xb, yb, zb), p0)
			rp.prism(Vector3.ZERO, 0.025, 0.025, d.length(), 5, ROPE, 0.0, false)
			rp.xf = keep
	var rope := MeshInstance3D.new()
	rope.name = "Rope"
	rope.mesh = rp.commit(LowPoly.material(0.8))
	body.add_child(rope)
	return root
