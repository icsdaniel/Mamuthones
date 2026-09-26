@tool
class_name MaskView
extends Control
## Draws a carved Mamuthone mask from a MaskSpec dictionary, framed by the dark kerchief and held by
## leather straps. Set `spec` (invalid values fall back to defaults) and it redraws.
##
## The static paint() is shared with the procession figures, the logo and the icon, so the mask the
## player carves is the one they walk with.
##
## Form (kept within real Mamoiada masks): dark, almost black wood; heavy brow; deep eye holes; a
## large, often hooked nose; pronounced cheeks; a neutral or grim mouth. The fire lights it from the
## upper left, and the carving shows as white-line cuts on black, the way a woodcut shades a form:
## parallel gouges, wide where the light is strong, thin or absent in shadow.

@export var spec: Dictionary = {}:
	set(v):
		spec = v
		queue_redraw()
## Firelight behind the mask (workshop screen).
@export var show_halo := false:
	set(v):
		show_halo = v
		queue_redraw()
## Draw the kerchief and straps (off for a bare mask on the workbench).
@export var show_kerchief := true:
	set(v):
		show_kerchief = v
		queue_redraw()
## Strap leather id (Palette.STRAPS).
@export var straps := "natural":
	set(v):
		straps = v
		queue_redraw()
## Ring one part (for the carving screen), e.g. "nose". Empty for none.
@export var highlight_part := "":
	set(v):
		highlight_part = v
		queue_redraw()

## Every finish stays black to dark brown-black: the rendered wood (base plus grain) is kept under
## about 12 % luminance (tested). Only the carved cuts and the worn edges catch the light.
const FINISH := {
	"soot_black": {"base": Color("#16110f"), "grain": 0.06, "rim": 0.55},
	"smoked": {"base": Color("#1d1611"), "grain": 0.07, "rim": 0.6},
	"dark_walnut": {"base": Color("#221813"), "grain": 0.08, "rim": 0.6},
	"charred": {"base": Color("#0f0f11"), "grain": 0.04, "rim": 0.45},
}
## Patina is age: the cuts' highlight stays bone (a little warmer and softer with age) and never
## widens; what grows is the wear on the high edges (brow ridge, nose, cheekbones, rim).
const PATINA := {
	"fresh": {"color": Color("#ede6da"), "a": 0.62, "w": 0.85, "wear": 0.0},
	"worn": {"color": Color("#efe4cf"), "a": 0.8, "w": 0.95, "wear": 0.35},
	"old": {"color": Color("#e8d9bd"), "a": 0.78, "w": 1.0, "wear": 0.6},
	"ancient": {"color": Color("#e2d2b4"), "a": 0.74, "w": 1.0, "wear": 0.9},
}
const KERCHIEF := Color("#2b211b")
const HOLE := Color("#050404")
## Extent of the drawing in mask units (the face is 2 units wide).
const HALF_W := 1.42
const TOP := -1.82
const BOTTOM := 2.05


func _draw() -> void:
	var s := minf(size.x / (HALF_W * 2.0 + 0.16), size.y / (BOTTOM - TOP + 0.16))
	var c := Vector2(size.x * 0.5, size.y * 0.5 - (BOTTOM + TOP) * 0.5 * s)
	if show_halo:
		halo(self, c, s)
	paint(self, c, s, spec, 2 if s > 45.0 else 1, show_kerchief, highlight_part, straps)


## Firelight behind a mask: a warm glow and radiating gouge cuts.
static func halo(ci: CanvasItem, c: Vector2, s: float) -> void:
	WoodcutDraw.begin(ci)
	WoodcutDraw.glow(ci, c + Vector2(0, -0.1 * s), 2.9 * s, Color(Palette.EMBER, 0.5))
	WoodcutDraw.rays(ci, c + Vector2(0, -0.1 * s), 1.75 * s, 2.7 * s, 56, Color(Palette.EMBER, 0.55), 0.045 * s, 5)
	WoodcutDraw.rays(ci, c + Vector2(0, -0.1 * s), 1.65 * s, 2.0 * s, 40, Color(Palette.EMBER_HOT, 0.35), 0.03 * s, 9)
	WoodcutDraw.end()


## Paints a mask centred at `c` with `s` pixels per mask unit (the face is 2 units wide, the whole
## drawing with kerchief about 2.9 x 3.9 units). detail: 0 tiny (procession), 1 medium, 2 full.
static func paint(ci: CanvasItem, c: Vector2, s: float, mask: Dictionary, detail := 2, kerchief := true, highlight := "", strap_id := "natural") -> void:
	WoodcutDraw.begin(ci)
	var m := MaskSpec.sanitize(mask)
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	var fin: Dictionary = FINISH[m.finish]
	var pat: Dictionary = PATINA[m.patina]
	var hi: Color = pat.color
	hi.a = pat.a
	var hw: float = pat.w
	var base: Color = fin.base
	var k := _Carver.new(ci, xf, s, hi, hw, detail)

	if kerchief:
		_kerchief(k)
	# ---- the face block
	var face := _mirror([Vector2(0, -1.36), Vector2(0.62, -1.28), Vector2(0.95, -0.9), Vector2(1.04, -0.3),
		Vector2(1.0, 0.24), Vector2(0.88, 0.7), Vector2(0.64, 1.06), Vector2(0.3, 1.29), Vector2(0, 1.35)])
	var face_pts := xf * WoodcutDraw.smooth_closed(face, 4)
	if detail > 0:
		face_pts = WoodcutDraw.rough(face_pts, maxf(0.5, s * 0.01), 3, maxf(3.0, s * 0.07))
	WoodcutDraw.fill(ci, face_pts, base)
	if detail > 0:
		WoodcutDraw.fill(ci, face_pts, Color(Palette.BONE, fin.grain), Palette.tex("grain"), 1.0 / (s * 3.0), Vector2(0.3, 0.1))
		var chisel_a := 0.7 if (m.finish == "charred" or m.patina == "ancient") else 0.4
		WoodcutDraw.fill(ci, face_pts, Color(Palette.INK, chisel_a), Palette.tex("chisel"), 1.0 / (s * 2.0))
	# Shadow side: the right third of the face turns away from the fire.
	k.shade(PackedVector2Array([Vector2(0.5, -1.25), Vector2(0.95, -0.88), Vector2(1.04, -0.2), Vector2(0.95, 0.55),
		Vector2(0.62, 1.05), Vector2(0.42, 0.9), Vector2(0.6, 0.2), Vector2(0.62, -0.6)]), 0.45)
	if kerchief:
		_straps(k, strap_id)

	_forehead(k, m.brow)
	_cheeks(k, m.cheeks)
	_brow(k, m.brow)
	_eyes(k, m.eyes)
	_nose(k, m.nose, base)
	_mouth(k, m.mouth)
	if m.patina == "ancient" and detail > 0:
		_cracks(k)
	if detail > 0 and float(pat.wear) > 0.0:
		_wear(k, float(pat.wear))
	# Firelight on the left edge.
	k.cut(PackedVector2Array([Vector2(-0.3, -1.29), Vector2(-0.8, -0.98), Vector2(-0.96, -0.35), Vector2(-0.93, 0.3), Vector2(-0.74, 0.86)]),
		0.07, Color(Palette.EMBER, fin.rim), false)
	if detail > 0:
		WoodcutDraw.outline(ci, face_pts, Color(Palette.INK, 0.95), maxf(1.2, 0.04 * s), 9)
	if highlight != "" and detail > 0:
		_mark_part(k, highlight)
	WoodcutDraw.end()


## Drawing context for one mask: carving helpers in mask units.
class _Carver:
	var ci: CanvasItem
	var xf: Transform2D
	var s: float
	var hi: Color
	var hw: float
	var detail: int

	func _init(p_ci: CanvasItem, p_xf: Transform2D, p_s: float, p_hi: Color, p_hw: float, p_detail: int) -> void:
		ci = p_ci
		xf = p_xf
		s = p_s
		hi = p_hi
		hw = p_hw
		detail = p_detail

	## A white-line cut through `ctrl` (smoothed) of peak width w (mask units), tapered at both ends.
	## mirror: also cut the right side, thinner and fainter because it is in shadow.
	func cut(ctrl: PackedVector2Array, w: float, color := Color(0, 0, 0, 0), mirror := true, shadow_scale := 0.55) -> void:
		var col := hi if color.a == 0.0 else color
		var pts := WoodcutDraw.smooth_open(ctrl, 5) if ctrl.size() > 2 else ctrl
		var ww := w * s * (hw if color.a == 0.0 else 1.0)
		if ww < 0.6:
			return
		WoodcutDraw.stroke(ci, xf * pts, col, ww * 0.12, ww * 0.12, ww)
		if mirror:
			var c2 := col
			c2.a *= 0.8
			WoodcutDraw.stroke(ci, xf * _flip(pts), c2, ww * 0.1, ww * 0.1, ww * shadow_scale)

	## A dark groove (always both sides unless mirror is false).
	func groove(ctrl: PackedVector2Array, w: float, mirror := true, alpha := 0.95) -> void:
		var pts := WoodcutDraw.smooth_open(ctrl, 5) if ctrl.size() > 2 else ctrl
		var col := Color(Palette.INK, alpha)
		WoodcutDraw.stroke(ci, xf * pts, col, w * s * 0.2, w * s * 0.2, w * s)
		if mirror:
			WoodcutDraw.stroke(ci, xf * _flip(pts), col, w * s * 0.2, w * s * 0.2, w * s)

	## Parallel cuts: `count` copies of ctrl stepped by `step`, each shorter (trim) and thinner.
	func hatch(ctrl: PackedVector2Array, step: Vector2, count: int, w: float, trim := 0.15, mirror := true) -> void:
		if detail == 0:
			count = mini(count, 1)
		for i in count:
			var pts := WoodcutDraw.smooth_open(ctrl, 5)
			var a := int(float(pts.size()) * trim * float(i) * 0.5)
			var b := pts.size() - int(float(pts.size()) * trim * float(i))
			if b - a < 2:
				break
			var part := pts.slice(a, b)
			for j in part.size():
				part[j] += step * float(i)
			cut(part, w * (1.0 - 0.18 * float(i)), Color(0, 0, 0, 0), mirror)

	func shade(pts: PackedVector2Array, alpha: float, mirror := false) -> void:
		var px := xf * WoodcutDraw.smooth_closed(pts, 4)
		if detail > 0:
			px = WoodcutDraw.rough(px, maxf(0.4, s * 0.012), 17, maxf(3.0, s * 0.06))
		WoodcutDraw.fill(ci, px, Color(Palette.INK, alpha))
		if mirror:
			var fx := xf * WoodcutDraw.smooth_closed(_flip(pts), 4)
			if detail > 0:
				fx = WoodcutDraw.rough(fx, maxf(0.4, s * 0.012), 18, maxf(3.0, s * 0.06))
			WoodcutDraw.fill(ci, fx, Color(Palette.INK, alpha))

	func hole(pts: PackedVector2Array, salt := 0) -> void:
		var px := xf * pts
		if detail > 0:
			px = WoodcutDraw.rough(px, maxf(0.4, s * 0.007), salt, maxf(2.0, s * 0.05))
		WoodcutDraw.fill(ci, px, HOLE)

	func _flip(pts: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		out.resize(pts.size())
		for i in pts.size():
			out[i] = Vector2(-pts[i].x, pts[i].y)
		return out


static func _mirror(half: Array) -> PackedVector2Array:
	# Right half top -> bottom given; returns a closed outline.
	var out := PackedVector2Array()
	for p in half:
		out.append(p)
	for i in range(half.size() - 2, 0, -1):
		var p: Vector2 = half[i]
		out.append(Vector2(-p.x, p.y))
	return out


static func _v(arr: Array) -> PackedVector2Array:
	return PackedVector2Array(arr)


static func _kerchief(k: _Carver) -> void:
	var ci := k.ci
	var s := k.s
	var shape := _mirror([Vector2(0, -1.8), Vector2(0.8, -1.7), Vector2(1.22, -1.22), Vector2(1.36, -0.4),
		Vector2(1.3, 0.5), Vector2(1.08, 1.2), Vector2(0.66, 1.62), Vector2(0.28, 1.8), Vector2(0, 1.84)])
	var pts := k.xf * WoodcutDraw.smooth_closed(shape, 4)
	if k.detail > 0:
		pts = WoodcutDraw.rough(pts, maxf(0.6, s * 0.014), 11, maxf(3.0, s * 0.09))
	WoodcutDraw.fill(ci, pts, KERCHIEF)
	if k.detail > 0:
		WoodcutDraw.fill(ci, pts, Color(Palette.INK, 0.55), Palette.tex("hatch"), 1.0 / (s * 1.4))
		# Folds: cloth pulled from the crown down past the cheeks to the knot.
		# Folds: short gathered creases radiating from the face, lit on the fire side.
		for i in 22:
			var t := float(i) / 21.0
			var ang := lerpf(-PI * 0.5 - 2.55, -PI * 0.5 + 2.55, t)
			var dir := Vector2(cos(ang) * 1.0, sin(ang) * 1.25)
			var r0 := 1.02 + 0.08 * WoodcutDraw.hash01(i, 71)
			var r1 := r0 + 0.16 + 0.2 * WoodcutDraw.hash01(i, 72)
			var bend := dir.orthogonal() * (0.05 * (WoodcutDraw.hash01(i, 73) - 0.5))
			var lit := dir.x < 0.1
			var col := Color(Palette.BONE, (0.38 if lit else 0.14) * (0.7 + 0.3 * WoodcutDraw.hash01(i, 74)))
			var f := _v([dir * r0, dir * (r0 + r1) * 0.5 + bend, dir * r1])
			WoodcutDraw.stroke(ci, k.xf * f, col, 0.004 * s, 0.0, 0.045 * s)
		WoodcutDraw.outline(ci, pts, Color(Palette.INK, 0.95), maxf(1.2, 0.045 * s), 12)
	# The knot under the chin, with its two short ends hanging down.
	var knot_col := KERCHIEF.darkened(0.2)
	for e in [[Vector2(-0.02, 1.8), Vector2(-0.3, 2.12), Vector2(-0.12, 2.16)], [Vector2(0.1, 1.8), Vector2(0.24, 2.14), Vector2(0.4, 2.06)]]:
		var flap := k.xf * _v(e)
		WoodcutDraw.fill(ci, flap, knot_col)
		if k.detail > 0:
			WoodcutDraw.outline(ci, flap, Color(Palette.INK, 0.9), maxf(1.0, 0.03 * s), 13)
	WoodcutDraw.fill(ci, k.xf * WoodcutDraw.ellipse(Vector2(0.04, 1.8), Vector2(0.17, 0.12), 12), knot_col)
	if k.detail > 0:
		WoodcutDraw.stroke(ci, k.xf * WoodcutDraw.quad(Vector2(-0.08, 1.76), Vector2(0.04, 1.72), Vector2(0.14, 1.77), 5), Color(Palette.BONE, 0.35), 0.005 * s, 0.0, 0.035 * s)


## Worn edges: short rubbed-through flecks on the high points, where hands and years polish the wood.
static func _wear(k: _Carver, amount: float) -> void:
	var col := Color(k.hi, 0.5 * amount)
	var spots := [
		[Vector2(-0.78, -0.6), Vector2(-0.46, -0.72)],    # brow ridge
		[Vector2(-0.12, -0.2), Vector2(-0.1, 0.18)],       # bridge of the nose
		[Vector2(-0.16, 0.3), Vector2(-0.06, 0.4)],        # nose tip
		[Vector2(-0.8, 0.12), Vector2(-0.62, 0.28)],       # cheekbone
		[Vector2(-0.98, -0.3), Vector2(-0.96, 0.2)],       # rim
		[Vector2(-0.4, 1.1), Vector2(-0.14, 1.24)],        # chin
	]
	var n := int(ceil(amount * float(spots.size())))
	for i in n:
		var sp: Array = spots[i]
		var a: Vector2 = sp[0]
		var b: Vector2 = sp[1]
		for j in 3:
			var t0 := 0.1 + 0.3 * float(j) + 0.1 * WoodcutDraw.hash01(i, j + 60)
			var p0 := a.lerp(b, t0)
			var p1 := a.lerp(b, minf(1.0, t0 + 0.18))
			WoodcutDraw.stroke(k.ci, k.xf * _v([p0, p1]), col, 0.004 * k.s, 0.004 * k.s, 0.035 * k.s)


static func _straps(k: _Carver, strap_id: String) -> void:
	# Leather straps run from the mask's temples back under the kerchief.
	var leather := Palette.straps(strap_id)
	var s := k.s
	for side in [-1.0, 1.0]:
		var pts := _v([Vector2(side * 0.86, -0.6), Vector2(side * 1.1, -0.66), Vector2(side * 1.34, -0.8)])
		var col := leather if side < 0 else leather.darkened(0.45)
		WoodcutDraw.stroke(k.ci, k.xf * pts, col, 0.17 * s, 0.12 * s)
		if k.detail > 0:
			# Stitching and the nail that fixes the strap to the wood.
			WoodcutDraw.stroke(k.ci, k.xf * pts, Color(Palette.INK, 0.7), 0.025 * s, 0.02 * s)
			WoodcutDraw.fill(k.ci, k.xf * WoodcutDraw.ellipse(Vector2(side * 0.88, -0.6), Vector2(0.05, 0.05), 8), Color(Palette.BONE, 0.7 if side < 0 else 0.35))


static func _forehead(k: _Carver, brow: String) -> void:
	if brow == "lined":
		# Deep wrinkles across the forehead, each with a lit upper lip.
		for i in 3:
			var y := -0.84 - 0.15 * float(i)
			var w := 0.66 - 0.1 * float(i)
			var line := _v([Vector2(-w, y + 0.04), Vector2(-w * 0.45, y - 0.02), Vector2(0, y - 0.03), Vector2(w * 0.45, y - 0.02), Vector2(w, y + 0.04)])
			k.groove(line, 0.05, false)
			var lip := line.duplicate()
			for j in lip.size():
				lip[j].y -= 0.045
			k.cut(lip.slice(0, 3), 0.04, Color(0, 0, 0, 0), false)
		return
	# Lit forehead: parallel cuts on the left, shorter on the right.
	k.hatch(_v([Vector2(-0.72, -0.9), Vector2(-0.42, -0.98), Vector2(-0.08, -0.96)]), Vector2(0.03, -0.12), 3, 0.07, 0.2)


static func _brow(k: _Carver, brow: String) -> void:
	var outer_y := -0.5
	var mid_y := -0.68
	var inner_y := -0.46
	var thick := 0.16
	match brow:
		"furrowed":
			outer_y = -0.7
			mid_y = -0.64
			inner_y = -0.38
		"knotted":
			mid_y = -0.74
			thick = 0.19
		"lined":
			mid_y = -0.64
	# The eye sockets: a deep shadow under the ridge.
	var sock := _v([Vector2(-0.94, outer_y + 0.08), Vector2(-0.45, mid_y + 0.16), Vector2(-0.06, inner_y + 0.08),
		Vector2(-0.14, 0.1), Vector2(-0.45, 0.18), Vector2(-0.84, 0.06)])
	k.shade(sock, 0.55, true)
	# The ridge: a thick cut on its upper edge.
	var ridge := _v([Vector2(-0.96, outer_y), Vector2(-0.5, mid_y), Vector2(-0.05, inner_y)])
	k.cut(ridge, thick)
	if k.detail == 0:
		return
	# Second, thinner cut above: the ridge's rounded top.
	var top := ridge.duplicate()
	for i in top.size():
		top[i].y -= 0.14
		top[i].x *= 0.85
	k.cut(top, thick * 0.35, Color(0, 0, 0, 0), true, 0.3)
	match brow:
		"furrowed":
			for x in [-0.07, 0.07]:
				k.groove(_v([Vector2(x * 1.2, -0.78), Vector2(x, -0.58), Vector2(x * 0.7, -0.42)]), 0.05, false)
			k.cut(_v([Vector2(-0.15, -0.8), Vector2(-0.13, -0.62), Vector2(-0.11, -0.46)]), 0.04, Color(0, 0, 0, 0), false)
		"knotted":
			k.shade(WoodcutDraw.ellipse(Vector2(0.01, -0.56), Vector2(0.11, 0.09), 12), 0.7)
			k.cut(_v([Vector2(-0.14, -0.52), Vector2(-0.1, -0.66), Vector2(0.05, -0.7)]), 0.07, Color(0, 0, 0, 0), false)
			k.groove(_v([Vector2(-0.35, -0.86), Vector2(-0.2, -0.82), Vector2(-0.1, -0.72)]), 0.04)


static func _eyes(k: _Carver, eyes: String) -> void:
	var hole: PackedVector2Array
	match eyes:
		"almond":
			hole = _almond(0.23, 0.12, 0.09, 0.0)
		"drooping":
			hole = _almond(0.22, 0.12, 0.08, 0.11)
		"narrow":
			hole = _almond(0.24, 0.055, 0.045, 0.03)
		_:
			hole = WoodcutDraw.ellipse(Vector2.ZERO, Vector2(0.17, 0.16), 18)
	for side in [-1.0, 1.0]:
		var at := Vector2(side * 0.42, -0.13)
		var pts := PackedVector2Array()
		for p in hole:
			pts.append(at + Vector2(p.x * side, p.y))
		k.hole(pts, 21 + int(side))
		if k.detail == 0:
			continue
		# The carved edge of the hole: lit all round on the left eye, only below on the right.
		var bottom := 0.16 if eyes == "round" else 0.1
		var droop := 0.08 if eyes == "drooping" else 0.0
		var ring := PackedVector2Array()
		for p in pts:
			ring.append(at + (p - at) * 1.28 + Vector2(0, 0.012))
		var n := ring.size()
		var lower := PackedVector2Array()
		for i in n:
			var p := ring[(i + n / 8) % n]
			if p.y >= at.y - 0.01:
				lower.append(p)
		if lower.size() > 2:
			lower.sort()
			k.cut(lower, 0.06 if side < 0 else 0.04, Color(0, 0, 0, 0), false)
		if side < 0:
			var upper := PackedVector2Array()
			for p in ring:
				if p.y < at.y - 0.01:
					upper.append(p)
			if upper.size() > 2:
				upper.sort()
				k.cut(upper, 0.03, Color(k.hi, k.hi.a * 0.6), false)
		var bag := _v([at + Vector2(-0.16 * side, bottom + 0.1), at + Vector2(0.02 * side, bottom + 0.2), at + Vector2(0.22 * side, bottom + 0.06 + droop)])
		k.groove(bag, 0.035, false, 0.8)


static func _almond(w: float, top: float, bottom: float, droop: float) -> PackedVector2Array:
	# Inner corner at -w, outer corner at +w (the caller mirrors per side); droop lowers the outer corner.
	var a := Vector2(-w, -droop * 0.3)
	var b := Vector2(w, droop)
	var up := WoodcutDraw.quad(a, Vector2(0, -top * 2.0), b, 8)
	var down := WoodcutDraw.quad(b, Vector2(0, bottom * 2.0), a, 8)
	up.remove_at(up.size() - 1)
	down.remove_at(down.size() - 1)
	up.append_array(down)
	return up


static func _nose(k: _Carver, nose: String, base: Color) -> void:
	var root_w := 0.11
	var wing_w := 0.29
	var wing_y := 0.38
	var tip_y := 0.5
	var bump := 0.0
	var hook := 0.0
	match nose:
		"hooked":
			tip_y = 0.62
			bump = 0.07
			hook = 0.1
		"long":
			root_w = 0.08
			wing_w = 0.22
			wing_y = 0.44
			tip_y = 0.58
		"broad":
			root_w = 0.13
			wing_w = 0.4
			wing_y = 0.36
			tip_y = 0.46
		"aquiline":
			root_w = 0.08
			wing_w = 0.25
			tip_y = 0.56
			bump = 0.04
			hook = 0.04
	var half := [Vector2(root_w, -0.46), Vector2(root_w + 0.02 + bump, -0.06), Vector2(wing_w * 0.62, 0.2),
		Vector2(wing_w, wing_y), Vector2(wing_w * 0.8, wing_y + 0.1), Vector2(0.12, tip_y - 0.06 - hook * 0.5), Vector2(0, tip_y)]
	var out := PackedVector2Array()
	for p in half:
		out.append(p)
	for i in range(half.size() - 2, 0, -1):
		var p: Vector2 = half[i]
		out.append(Vector2(-p.x, p.y))
	var pts := k.xf * WoodcutDraw.smooth_closed(out, 3)
	WoodcutDraw.fill(k.ci, pts, base.lightened(0.05))
	# The right plane of the nose and its cast shadow on the cheek.
	k.shade(_v([Vector2(0.02, -0.42), Vector2(root_w + 0.06 + bump, -0.06), Vector2(wing_w + 0.14, wing_y + 0.02),
		Vector2(wing_w * 0.8, wing_y + 0.18), Vector2(0.04, tip_y + 0.02), Vector2(0.06, 0.1)]), 0.8)
	# Ridge: the brightest cut on the face, bulging where the nose is hooked.
	k.cut(_v([Vector2(-0.04, -0.44), Vector2(-0.06 - bump, -0.1), Vector2(-0.08 - bump * 0.3, 0.2), Vector2(-0.05, tip_y - 0.08)]), 0.1, Color(0, 0, 0, 0), false)
	if k.detail > 0:
		# Short cuts across the lit left plane.
		for i in 3:
			var y := -0.02 + 0.13 * float(i)
			var x0 := -(root_w + 0.03 + (wing_w - root_w) * float(i) / 3.0)
			k.cut(_v([Vector2(x0, y + 0.03), Vector2(x0 * 0.5 - 0.04, y)]), 0.035, Color(0, 0, 0, 0), false)
		# Wing creases.
		for side in [-1.0, 1.0]:
			k.groove(_v([Vector2(side * wing_w * 0.6, 0.2), Vector2(side * (wing_w + 0.05), 0.3), Vector2(side * wing_w * 0.85, wing_y + 0.1)]), 0.04, false)
		# Nostril wings: a lit arc on the left, a groove on the right.
		k.cut(_v([Vector2(-wing_w * 0.55, wing_y - 0.12), Vector2(-wing_w - 0.03, wing_y), Vector2(-wing_w * 0.7, wing_y + 0.13)]), 0.06, Color(0, 0, 0, 0), false)
		if hook > 0.0:
			# The hooked tip overhangs and throws a shadow on the lip.
			k.shade(_v([Vector2(-0.16, tip_y + 0.02), Vector2(0.0, tip_y + 0.12 + hook), Vector2(0.18, tip_y + 0.02), Vector2(0.0, tip_y + 0.05)]), 0.9)
		# Tip catches the light.
		WoodcutDraw.fill(k.ci, k.xf * WoodcutDraw.ellipse(Vector2(-0.05, tip_y - 0.11), Vector2(0.055, 0.04), 8), Color(k.hi, k.hi.a * 0.8))
	# Nostrils.
	for side in [-1.0, 1.0]:
		var n := WoodcutDraw.ellipse(Vector2(side * wing_w * 0.5, wing_y + 0.08), Vector2(0.07, 0.04), 10, side * 0.35)
		WoodcutDraw.fill(k.ci, k.xf * n, HOLE)


static func _cheeks(k: _Carver, cheeks: String) -> void:
	match cheeks:
		"high":
			# Sharp cheekbones running up toward the temples.
			k.hatch(_v([Vector2(-0.92, -0.02), Vector2(-0.68, 0.06), Vector2(-0.44, 0.2)]), Vector2(0.02, 0.1), 2, 0.1, 0.25)
			k.shade(_v([Vector2(-0.9, 0.24), Vector2(-0.62, 0.36), Vector2(-0.4, 0.56), Vector2(-0.72, 0.6)]), 0.5, true)
		"hollow":
			k.cut(_v([Vector2(-0.96, 0.0), Vector2(-0.7, 0.1), Vector2(-0.46, 0.18)]), 0.08)
			k.shade(_v([Vector2(-0.94, 0.2), Vector2(-0.62, 0.24), Vector2(-0.36, 0.44), Vector2(-0.42, 0.8),
				Vector2(-0.7, 0.74), Vector2(-0.92, 0.5)]), 0.85, true)
		"creased":
			k.hatch(_v([Vector2(-0.88, 0.12), Vector2(-0.64, 0.14), Vector2(-0.44, 0.26)]), Vector2(0.0, 0.1), 2, 0.09, 0.3)
			if k.detail > 0:
				var fold := _v([Vector2(-0.3, 0.38), Vector2(-0.45, 0.62), Vector2(-0.48, 0.94)])
				k.groove(fold, 0.07)
				var lip := fold.duplicate()
				for j in lip.size():
					lip[j].x -= 0.07
				k.cut(lip, 0.05)
		_:
			# Full: round cheeks shaded with concentric cuts.
			for i in 3:
				var r := 0.3 - 0.075 * float(i)
				var arc := PackedVector2Array()
				for j in 7:
					var a := lerpf(PI * 1.0, PI * 1.6, float(j) / 6.0)
					arc.append(Vector2(-0.56, 0.4) + Vector2(cos(a) * r, sin(a) * r * 0.9))
				k.cut(arc, 0.085 - 0.02 * float(i), Color(0, 0, 0, 0), i < 2)
			if k.detail > 0:
				var under := PackedVector2Array()
				for j in 7:
					var a := lerpf(PI * 0.15, PI * 0.8, float(j) / 6.0)
					under.append(Vector2(-0.56, 0.4) + Vector2(cos(a) * 0.3, sin(a) * 0.28))
				k.groove(under, 0.05, true, 0.7)


static func _mouth(k: _Carver, mouth: String) -> void:
	var y := 0.84
	match mouth:
		"downturned":
			k.groove(_v([Vector2(-0.34, y + 0.13), Vector2(-0.16, y - 0.01), Vector2(0.0, y - 0.02), Vector2(0.16, y - 0.01), Vector2(0.34, y + 0.13)]), 0.08, false, 1.0)
		"open":
			k.hole(WoodcutDraw.smooth_closed(_v([Vector2(-0.26, y + 0.03), Vector2(0, y - 0.07), Vector2(0.26, y + 0.03), Vector2(0, y + 0.14)]), 4), 41)
		"grimace":
			k.hole(WoodcutDraw.smooth_closed(_v([Vector2(-0.38, y + 0.14), Vector2(-0.22, y - 0.06), Vector2(0.22, y - 0.06),
				Vector2(0.38, y + 0.14), Vector2(0.16, y + 0.15), Vector2(-0.16, y + 0.15)]), 3), 42)
			if k.detail > 0:
				# Clenched teeth: a carved bar across the opening.
				k.cut(_v([Vector2(-0.24, y + 0.03), Vector2(0.24, y + 0.03)]), 0.05, Color(k.hi, k.hi.a * 0.7), false)
				k.groove(_v([Vector2(-0.4, y + 0.22), Vector2(-0.48, y + 0.04), Vector2(-0.42, y - 0.14)]), 0.045)
		_:
			k.groove(_v([Vector2(-0.3, y + 0.03), Vector2(0, y), Vector2(0.3, y + 0.03)]), 0.065, false, 1.0)
	# Upper lip ridge, lower lip and chin catch the light.
	k.cut(_v([Vector2(-0.2, y - 0.1), Vector2(-0.08, y - 0.13), Vector2(0.0, y - 0.1)]), 0.04, Color(0, 0, 0, 0), false)
	k.cut(_v([Vector2(-0.2, y + 0.22), Vector2(-0.04, y + 0.27), Vector2(0.14, y + 0.23)]), 0.06, Color(0, 0, 0, 0), false)
	k.hatch(_v([Vector2(-0.34, 1.1), Vector2(-0.08, 1.2), Vector2(0.2, 1.12)]), Vector2(0.02, 0.07), 2, 0.07, 0.3, false)


static func _cracks(k: _Carver) -> void:
	# Age: splits following the grain.
	k.groove(_v([Vector2(0.3, -1.34), Vector2(0.36, -1.02), Vector2(0.28, -0.76)]), 0.035, false, 1.0)
	k.groove(_v([Vector2(-0.76, 0.92), Vector2(-0.63, 0.68), Vector2(-0.66, 0.5)]), 0.035, false, 1.0)
	k.groove(_v([Vector2(0.62, 0.98), Vector2(0.72, 0.72)]), 0.03, false, 1.0)


static func _mark_part(k: _Carver, part: String) -> void:
	var at := {"brow": Vector2(0, -0.62), "eyes": Vector2(0, -0.13), "nose": Vector2(0, 0.08), "cheeks": Vector2(0, 0.38),
		"mouth": Vector2(0, 0.86), "finish": Vector2(0, 0.0), "patina": Vector2(0, 0.0)}
	var r := {"brow": Vector2(1.08, 0.3), "eyes": Vector2(0.76, 0.28), "nose": Vector2(0.44, 0.66), "cheeks": Vector2(1.02, 0.44),
		"mouth": Vector2(0.5, 0.26), "finish": Vector2(1.18, 1.48), "patina": Vector2(1.18, 1.48)}
	if not at.has(part):
		return
	var ring := k.xf * WoodcutDraw.ellipse(at[part], r[part], 40)
	WoodcutDraw.outline(k.ci, ring, Color(Palette.EMBER, 0.95), maxf(1.5, 0.035 * k.s), 31)
