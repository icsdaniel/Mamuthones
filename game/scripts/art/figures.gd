class_name Figures
extends RefCounted
## Static drawing of the procession's people, in the woodcut style, onto any CanvasItem.
## Every function draws with the feet at (0, 0) and the figure standing `h` pixels tall, facing the
## viewer. Units inside are percent of the height (u = h / 100).
##
## Mamuthone: dark sheepskin to the knees, dark trousers and leather leggings, the carved mask and
## kerchief, leather straps over the fleece, the big load of cowbells on the back (seen above the
## shoulders and at the sides) and smaller bells on the chest.
## Issohadore: red jacket, white shirt and trousers, dark leggings, white mask, dark cap, a leather
## bandolier of small bells across the chest, a shawl at the hip and the rope (soha).

const TROUSERS := Color("#1d1713")
const BOOT := Color("#0f0c0a")
const BELL_DARK := Color("#2a2119")
const BELL_BRONZE := Color("#8a6236")
const ISSO_MASK := Color("#efe9df")
const CAP := Color("#15110f")
const SHAWL := Color("#2a1e2a")


## The load of big cowbells on the back: drawn first, behind the body. It is one heavy bunch tied on
## the back from the shoulder blades to the hips, so from the front it shows as a dark mass wider than
## the fleece, with bells hanging out at both sides (more on the fire-lit left) and only the tops of two
## peeking over the shoulders.
## bell_set (BellSets id): "light" carries fewer, smaller bells, "full" more and bigger; the default is
## the village set.
static func mamuthone_back(ci: CanvasItem, h: float, lit := Palette.EMBER, detail := 1, bell_set := "village") -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	var bk: float = {"light": 0.86, "village": 1.0, "full": 1.12}.get(bell_set, 1.0)
	# The mass of the load behind the body.
	var mass := PackedVector2Array([Vector2(-15, -80), Vector2(15, -80), Vector2(23, -72), Vector2(28, -56), Vector2(29.5, -42),
		Vector2(26, -32), Vector2(-26, -32), Vector2(-30.5, -42), Vector2(-29.5, -56), Vector2(-24, -72)])
	var mpts := WoodcutDraw.rough(WoodcutDraw.smooth_closed(_u(mass, u), 3), 0.8 * u, 29, maxf(2.0, 2.0 * u))
	WoodcutDraw.fill(ci, mpts, BELL_DARK.darkened(0.35))
	# Bells: [x, y, tilt, mouth width]. Shoulder tops first (mostly hidden by the head), then the sides.
	var bells := [
		[-12.5, -78.5, -0.12, 8.0], [12.5, -78.5, 0.12, 7.5],
		[23, -66, 0.26, 9.0], [27, -54, 0.18, 10.5], [27, -42, 0.1, 11.0],
		[-23.5, -67, -0.26, 9.5], [-28.5, -55, -0.2, 11.0], [-29.5, -43, -0.12, 12.0], [-25, -34, -0.05, 11.0],
	]
	if bell_set == "light":
		bells = bells.slice(2, 8)
	elif bell_set == "full":
		bells = [[-19, -31, -0.04, 10.0], [19, -31, 0.04, 9.5]] + bells
	for b in bells:
		cowbell(ci, Vector2(b[0] * (0.5 + 0.5 * bk), b[1]) * u, float(b[3]) * u * bk, b[2], lit if float(b[0]) < 0.0 else Color(lit, 0.55), detail)
	# Mouths of the lowest bells showing under the load's edge.
	for x in [-16.0, -7.0, 4.0, 14.0]:
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(x, -33.5), Vector2(4.2, 1.3), 10), u), Palette.INK)
		if detail > 0:
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(x - 3.6, -34.4), Vector2(x - 0.5, -35.0)]), u), Color(lit, 0.45), 0.5 * u, 0.2 * u)
	WoodcutDraw.end()


## A cowbell: flared iron body, dark mouth, a lit edge on the left. `w` is its mouth width.
static func cowbell(ci: CanvasItem, c: Vector2, w: float, rot: float, lit: Color, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var xf := Transform2D(rot, c)
	var body := PackedVector2Array([Vector2(-0.3, -0.62), Vector2(0.3, -0.62), Vector2(0.44, -0.1), Vector2(0.52, 0.36),
		Vector2(-0.52, 0.36), Vector2(-0.44, -0.1)])
	var pts := xf * (Transform2D(0.0, Vector2(w, w), 0.0, Vector2.ZERO) * body)
	WoodcutDraw.fill(ci, pts, BELL_DARK)
	if detail > 0:
		# Hammered iron: a dark shadow plane on the far side and an ink edge, so each bell reads as a
		# solid shape on dark fleece and on pale streets alike.
		var far := PackedVector2Array([Vector2(0.08, -0.62), Vector2(0.3, -0.62), Vector2(0.44, -0.1), Vector2(0.52, 0.36), Vector2(0.14, 0.36), Vector2(0.12, -0.1)])
		WoodcutDraw.fill(ci, xf * (Transform2D(0.0, Vector2(w, w), 0.0, Vector2.ZERO) * far), Color(Palette.INK, 0.45))
		WoodcutDraw.outline(ci, pts, Palette.INK, maxf(1.0, w * 0.06), 3)
	# Mouth.
	WoodcutDraw.fill(ci, xf * WoodcutDraw.ellipse(Vector2(0, 0.36 * w), Vector2(0.5 * w, 0.12 * w), 10), Palette.INK)
	# Lit edge and a band across the shoulder of the bell.
	var edge := PackedVector2Array([Vector2(-0.28, -0.56), Vector2(-0.42, -0.1), Vector2(-0.48, 0.3)])
	WoodcutDraw.stroke(ci, xf * (Transform2D(0.0, Vector2(w, w), 0.0, Vector2.ZERO) * edge), Color(lit, 0.9), w * 0.04, w * 0.07, w * 0.2)
	if detail > 0:
		WoodcutDraw.stroke(ci, xf * PackedVector2Array([Vector2(-0.4, -0.1) * w, Vector2(0.1, -0.12) * w]), Color(lit, 0.35), w * 0.02, 0.0, w * 0.07)
		# Clapper.
		WoodcutDraw.fill(ci, xf * WoodcutDraw.ellipse(Vector2(0.05, 0.4) * w, Vector2(0.09, 0.07) * w, 6), Color(lit, 0.5))
	# Leather loop on top.
	WoodcutDraw.stroke(ci, xf * PackedVector2Array([Vector2(-0.12, -0.62) * w, Vector2(0, -0.8) * w, Vector2(0.12, -0.62) * w]), Color("#3a2618"), w * 0.1, w * 0.1)
	WoodcutDraw.end()


## The body: legs, fleece, straps and front bells. The head is drawn separately (mamuthone_head) so
## it can bob on its own.
static func mamuthone_body(ci: CanvasItem, h: float, fleece := "black", straps := "natural", lit := Palette.EMBER, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	var fc := Palette.fleece(fleece)
	var sc := Palette.straps(straps)
	_mamuthone_legs(ci, u, lit, detail)
	# Fleece: a heavy shaggy coat from the shoulders to the knees.
	var fl := PackedVector2Array([Vector2(-6, -82), Vector2(6, -82), Vector2(15, -78), Vector2(20, -68), Vector2(22, -50),
		Vector2(22, -28), Vector2(-22, -28), Vector2(-22, -50), Vector2(-20, -68), Vector2(-15, -78)])
	var fpts := WoodcutDraw.smooth_closed(_u(fl, u), 3)
	fpts = WoodcutDraw.rough(fpts, 1.0 * u, 7, maxf(2.0, 2.0 * u))
	WoodcutDraw.fill(ci, fpts, fc)
	var wool := Palette.tex("fleece")
	var wool_scale := 1.0 / maxf(h * 0.55, 40.0)
	WoodcutDraw.fill(ci, fpts, Color(Palette.BONE, 0.13 if detail > 0 else 0.16), wool, wool_scale)
	# Lit side: more wool catches the fire on the left.
	var lit_side := PackedVector2Array([Vector2(-15, -78), Vector2(-4, -80), Vector2(-9, -60), Vector2(-10, -30), Vector2(-22, -28), Vector2(-22, -50), Vector2(-20, -68)])
	WoodcutDraw.fill(ci, WoodcutDraw.smooth_closed(_u(lit_side, u), 3), Color(lit, 0.28), wool, wool_scale)
	# Shadow side: a hard chisel-cut plane, its edge left rough like a gouge run down the block.
	var dark_side := PackedVector2Array([Vector2(8, -81), Vector2(15, -78), Vector2(20, -68), Vector2(22, -50), Vector2(22, -28), Vector2(11, -28), Vector2(12.5, -46), Vector2(10.5, -64)])
	WoodcutDraw.fill(ci, WoodcutDraw.rough(_u(dark_side, u), 0.7 * u, 41, maxf(2.0, 1.6 * u)), Color(Palette.INK, 0.55))
	# Linocut locks: white cut-away curls in rows down the fleece, bright where the fire falls on the
	# left, few and thin in the shadow.
	if detail > 0:
		_fleece_cuts(ci, u, lit)
	# Shaggy hem: locks of wool hanging below the edge.
	for i in 12:
		var x := -21.0 + 3.8 * float(i)
		var ln := 3.0 + 3.5 * WoodcutDraw.hash01(i, 3)
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(x, -30), Vector2(x + 0.8, -28 + ln * 0.5), Vector2(x - 0.4, -28 + ln)]), u), fc, 3.0 * u, 0.3 * u, 2.4 * u)
	# Sleeves: arms hang inside the fleece; the hands show at the hem.
	for side in [-1.0, 1.0]:
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(side * 14, -74), Vector2(side * 19, -56), Vector2(side * 18, -38)]), 3), u), Color(Palette.INK, 0.6), 0.4 * u, 0.4 * u, 1.2 * u)
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(side * 18.5, -35), Vector2(2.4, 2.8), 8), u), Color("#1e1611"))
	# Lit edge of the fleece (fire on the left).
	WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(-14, -79), Vector2(-20, -68), Vector2(-22, -50), Vector2(-22, -31)]), 4), u), Color(lit, 0.75), 0.4 * u, 0.4 * u, 1.6 * u)
	# Straps: crossing the chest to hold the load, in the chosen leather.
	for side in [-1.0, 1.0]:
		var strap := PackedVector2Array([Vector2(side * 12, -80), Vector2(side * 4, -66), Vector2(-side * 9, -50)])
		WoodcutDraw.stroke(ci, _u(strap, u), sc if side < 0 else sc.darkened(0.3), 2.8 * u, 2.4 * u)
		if detail > 0:
			WoodcutDraw.stroke(ci, _u(strap, u), Color(Palette.INK, 0.55), 0.5 * u, 0.4 * u)
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([strap[0] + Vector2(-0.8 * side, 0.5), strap[1] + Vector2(-0.8, 0)]), u), Color(Palette.BONE, 0.3), 0.5 * u, 0.2 * u)
	# Smaller bells hung on the chest, on their own strap.
	WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(-11, -63), Vector2(0, -57), Vector2(11, -63), 6), u), sc.darkened(0.2), 1.6 * u, 1.6 * u)
	for b in [[-8, -57, -0.25], [-2.7, -55, -0.08], [2.7, -55, 0.08], [8, -57, 0.25]]:
		cowbell(ci, Vector2(b[0], b[1]) * u, 5.2 * u, b[2], lit, 0)
	WoodcutDraw.end()


static func _mamuthone_legs(ci: CanvasItem, u: float, lit: Color, detail: int) -> void:
	# Legs: dark trousers into leather gaiters laced up the front, heavy shoes. Tapered to the ankle
	# with a gap between them, carved with a lit edge on the fire side and hatching on the other.
	for side in [-1.0, 1.0]:
		var sd: float = side
		var leg := PackedVector2Array([Vector2(sd * 1.8, -31), Vector2(sd * 10.2, -31), Vector2(sd * 9.6, -17), Vector2(sd * 8.6, -3),
			Vector2(sd * 3.6, -3), Vector2(sd * 2.6, -17)])
		WoodcutDraw.fill(ci, _u(leg, u), TROUSERS)
		var gaiter := PackedVector2Array([Vector2(sd * 2.5, -19), Vector2(sd * 9.8, -19.5), Vector2(sd * 8.7, -3), Vector2(sd * 3.5, -3)])
		WoodcutDraw.fill(ci, _u(gaiter, u), BOOT)
		var shoe := WoodcutDraw.smooth_closed(PackedVector2Array([Vector2(sd * 2.6, -3.5), Vector2(sd * 9.4, -3.8), Vector2(sd * 11.4, -1.6),
			Vector2(sd * 10.8, 0.2), Vector2(sd * 2.2, 0.2)]), 3)
		WoodcutDraw.fill(ci, _u(shoe, u), BOOT)
		if detail == 0:
			continue
		var lit_a := 0.75 if sd < 0.0 else 0.28
		# Lit edge on the outer (left leg) or inner (right leg) contour.
		var ex := 9.9 if sd < 0.0 else 2.9
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(sd * ex, -30), Vector2(sd * (ex - 0.3), -18), Vector2(sd * (ex - 1.0), -4)]), u), Color(lit, lit_a), 0.2 * u, 0.2 * u, 0.9 * u)
		# Trouser folds: short white cuts gathering at the gaiter top.
		for i in 3:
			var y := -29.0 + 3.2 * float(i)
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(sd * 4.0, y + 0.8), Vector2(sd * 6.5, y), Vector2(sd * 8.5, y + 0.6)]), u), Color(Palette.BONE, lit_a * 0.45), 0.1 * u, 0.1 * u, 0.55 * u)
		# Gaiter laces: crossed cuts up the front.
		for i in 4:
			var y := -16.5 + 3.4 * float(i)
			var cx := sd * 6.0
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(cx - 1.6, y), Vector2(cx + 1.6, y + 1.5)]), u), Color(lit, lit_a * 0.7), 0.35 * u, 0.2 * u)
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(cx + 1.6, y), Vector2(cx - 1.6, y + 1.5)]), u), Color(lit, lit_a * 0.4), 0.35 * u, 0.2 * u)
		# Shadow hatching on the side away from the fire.
		var hx := 3.2 if sd < 0.0 else 8.6
		for i in 5:
			var y := -29.5 + 2.4 * float(i)
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(sd * hx, y), Vector2(sd * (hx + (1.5 if sd > 0.0 else 1.2)), y + 1.2)]), u), Color(Palette.INK, 0.8), 0.35 * u, 0.1 * u)
		# Shoe: a lit toe cap and a sole line.
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(sd * 4.0, -2.6), Vector2(sd * 8.5, -3.6), Vector2(sd * 10.8, -1.2), 5), u), Color(lit, lit_a * 0.8), 0.2 * u, 0.2 * u, 0.7 * u)


## White-line carving of the sheepskin: rows of curled cuts, following the fall of the wool.
static func _fleece_cuts(ci: CanvasItem, u: float, lit: Color) -> void:
	# At close-up sizes (portraits) the locks stay about the same size in pixels and get denser, so the
	# wool never turns into a few big slashes.
	var f := clampf(3.5 / u, 0.4, 1.0)
	var row := 0
	var y := -77.0
	while y < -31.0:
		# Half-width of the coat at this height.
		var t := clampf((y + 82.0) / 30.0, 0.0, 1.0)
		var half := lerpf(12.0, 21.0, sqrt(t))
		var x := -half + 1.0 + ((1.6 if row % 2 == 1 else 0.0) + 0.8 * WoodcutDraw.hash01(row, 51)) * f
		var k := 0
		while x < half - 1.5:
			var j := WoodcutDraw.hash01(row * 31 + k, 52)
			var lx := (x + half) / (2.0 * half)          # 0 at the lit edge, 1 at the shadow edge
			var a := lerpf(0.62, 0.08, lx) * (0.7 + 0.3 * j)
			if a > 0.1 or j > 0.6:
				var p := Vector2(x, y + (j - 0.5) * 1.6)
				# A lock of wool: a short hooked cut, hanging down, bent one way or the other at random.
				var curl := -1.0 if WoodcutDraw.hash01(row * 31 + k, 54) < 0.5 else 1.0
				var ln := (2.6 + 1.8 * WoodcutDraw.hash01(row * 31 + k, 55)) * f
				var c := PackedVector2Array([p, p + Vector2(curl * 0.3 * f, ln * 0.55), p + Vector2(curl * 1.3 * f, ln)])
				var col := Color(Palette.BONE, minf(0.9, a * 1.25)) if lx < 0.35 else Color(Palette.BONE.lerp(lit, 0.4), a)
				WoodcutDraw.stroke(ci, _u(c, u), col, 0.15 * u * f, 0.05 * u * f, 0.85 * u * f)
			x += (3.2 + 1.2 * j) * f
			k += 1
		y += 4.2 * f
		row += 1


## The head: kerchief and the player's carved mask. `mask` is a MaskSpec dictionary.
static func mamuthone_head(ci: CanvasItem, h: float, mask: Dictionary, straps := "natural", detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	MaskView.paint(ci, Vector2(0, -89.5) * u, 4.4 * u, mask, detail, true, "", straps)
	WoodcutDraw.end()


## A whole Mamuthone in one call (for cards, the logo and the icon).
static func mamuthone(ci: CanvasItem, h: float, mask: Dictionary, fleece := "black", straps := "natural", lit := Palette.EMBER, detail := 1, bell_set := "village") -> void:
	WoodcutDraw.begin(ci)
	mamuthone_back(ci, h, lit, detail, bell_set)
	mamuthone_body(ci, h, fleece, straps, lit, detail)
	mamuthone_head(ci, h, mask, straps, detail)
	WoodcutDraw.end()


## The ghost: your best run, drawn as a dashed ink line round a Mamuthone's silhouette (head and
## kerchief, the bell load, the fleece, the legs) in ember at low alpha. Only an outline, so it never
## reads as a figure or a smudge.
static func ghost(ci: CanvasItem, h: float, color: Color) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	var outline := PackedVector2Array([Vector2(0, -99.5), Vector2(4.5, -98.5), Vector2(6.3, -94), Vector2(6.5, -86), Vector2(9, -82),
		Vector2(15, -81), Vector2(26, -74), Vector2(30, -58), Vector2(29, -42), Vector2(25, -33), Vector2(22, -28), Vector2(10, -29),
		Vector2(9.2, -4), Vector2(11, -1), Vector2(10.5, 0), Vector2(2.5, 0), Vector2(2.5, -26), Vector2(-2.5, -26), Vector2(-2.5, 0),
		Vector2(-10.5, 0), Vector2(-11, -1), Vector2(-9.2, -4), Vector2(-10, -29), Vector2(-22, -28), Vector2(-25, -33), Vector2(-29, -42),
		Vector2(-30, -58), Vector2(-26, -74), Vector2(-15, -81), Vector2(-9, -82), Vector2(-6.5, -86), Vector2(-6.3, -94), Vector2(-4.5, -98.5)])
	var pts := WoodcutDraw.smooth_closed(_u(outline, u), 2)
	pts.append(pts[0])
	WoodcutDraw.fill(ci, pts, Color(color, color.a * 0.12))
	_dashed(ci, pts, Color(Palette.INK, color.a * 0.5), 2.2 * u, 3.2 * u, 2.0 * u)
	_dashed(ci, pts, color, 1.1 * u, 3.2 * u, 2.0 * u)
	# The mask's two eye cuts and the kerchief line, dashed too, so it is a Mamuthone and not a shape.
	for sd in [-1.0, 1.0]:
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(sd * 3.6, -91.4), Vector2(sd * 1.6, -90.8)]), u), color, 0.5 * u, 0.5 * u, 0.9 * u)
	_dashed(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(-4.6, -85), Vector2(0, -83.2), Vector2(4.6, -85)]), 3), u), color, 0.8 * u, 1.6 * u, 1.4 * u)
	WoodcutDraw.end()


## A dashed stroke along `pts`: dashes of `dash` with gaps of `gap` (pixels).
static func _dashed(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	var cur := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var d := a.distance_to(b)
		var pos := 0.0
		while d - pos > left:
			pos += left
			var p := a.lerp(b, pos / d)
			if on:
				cur.append(p)
				WoodcutDraw.stroke(ci, cur, color, width, width)
			cur = PackedVector2Array([p])
			on = not on
			left = dash if on else gap
		left -= d - pos
		if on:
			cur.append(b)
	if on and cur.size() > 1:
		WoodcutDraw.stroke(ci, cur, color, width, width)


## Issohadore body (without the throwing arm and head, which animate on their own).
static func issohadore_body(ci: CanvasItem, h: float, lit := Palette.EMBER, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	# Legs: white trousers (lit on the left, shaded and hatched on the right), dark leggings, shoes.
	for side in [-1.0, 1.0]:
		var sd: float = side
		var leg := PackedVector2Array([Vector2(sd * 1.2, -51), Vector2(sd * 10, -51), Vector2(sd * 9.2, -30), Vector2(sd * 8.4, -20),
			Vector2(sd * 3.2, -20), Vector2(sd * 2.4, -30)])
		WoodcutDraw.fill(ci, _u(leg, u), Palette.BONE if sd < 0.0 else Palette.BONE.darkened(0.22))
		var gaiter := PackedVector2Array([Vector2(sd * 3.0, -21.5), Vector2(sd * 8.6, -21.5), Vector2(sd * 8.2, -3), Vector2(sd * 3.4, -3)])
		WoodcutDraw.fill(ci, _u(gaiter, u), BOOT)
		var shoe := WoodcutDraw.smooth_closed(PackedVector2Array([Vector2(sd * 2.8, -3.5), Vector2(sd * 8.8, -3.8), Vector2(sd * 10.6, -1.6),
			Vector2(sd * 10.0, 0.2), Vector2(sd * 2.4, 0.2)]), 3)
		WoodcutDraw.fill(ci, _u(shoe, u), BOOT)
		if detail > 0:
			# Carved shading: a chisel-cut shadow plane down the inside of each leg, hatched.
			var plane := PackedVector2Array([Vector2(sd * 1.2, -51), Vector2(sd * 4.2, -51), Vector2(sd * 4.6, -36), Vector2(sd * 4.0, -21), Vector2(sd * 3.2, -20), Vector2(sd * 2.4, -30)])
			if sd > 0.0:
				plane = PackedVector2Array([Vector2(6.5, -51), Vector2(10, -51), Vector2(9.2, -30), Vector2(8.4, -20), Vector2(6.8, -20), Vector2(7.2, -36)])
			WoodcutDraw.fill(ci, _u(plane, u), Color(Palette.ASH, 0.55))
			for i in 9:
				var y := -49.0 + 3.2 * float(i)
				var x0: float = plane[0].x
				WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(x0 + sd * 0.4, y), Vector2(x0 + sd * 2.6, y + 1.8)]), u), Color(Palette.INK, 0.5), 0.3 * u, 0.1 * u)
			# Folds at the knee: dark cut lines.
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(sd * 3.5, -33), Vector2(sd * 6.0, -31.2), Vector2(sd * 8.6, -33.5), 4), u), Color(Palette.INK, 0.55), 0.15 * u, 0.15 * u, 0.6 * u)
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(sd * 4.0, -27), Vector2(sd * 6.2, -25.6), Vector2(sd * 8.2, -27.4), 4), u), Color(Palette.INK, 0.4), 0.15 * u, 0.15 * u, 0.5 * u)
			# Gaiter buttons and the lit toe.
			for i in 4:
				WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(sd * 8.0, -18.5 + 4.2 * float(i)), Vector2(0.45, 0.45), 6), u), Color(Palette.BONE, 0.5 if sd < 0.0 else 0.25))
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(sd * 4.0, -2.6), Vector2(sd * 8.2, -3.6), Vector2(sd * 10.2, -1.2), 5), u), Color(lit, 0.6 if sd < 0.0 else 0.25), 0.2 * u, 0.2 * u, 0.7 * u)
	# Red jacket, short and fitted, open over the white shirt.
	var jacket := PackedVector2Array([Vector2(-6, -80), Vector2(6, -80), Vector2(13.5, -77), Vector2(14.5, -66), Vector2(12, -52),
		Vector2(-12, -52), Vector2(-14.5, -66), Vector2(-13.5, -77)])
	var jp := WoodcutDraw.rough(WoodcutDraw.smooth_closed(_u(jacket, u), 3), 0.4 * u, 4, maxf(2.0, 2.5 * u))
	WoodcutDraw.fill(ci, jp, Palette.RED)
	if detail > 0:
		WoodcutDraw.fill(ci, jp, Color(Palette.INK, 0.25), Palette.tex("hatch"), 1.0 / maxf(h * 0.7, 30.0))
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(5, -79), Vector2(13.5, -77), Vector2(14.5, -66), Vector2(12, -52), Vector2(6, -52), Vector2(8, -66)]), u), Palette.RED_DEEP)
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(-4, -80), Vector2(4, -80), Vector2(2.2, -60), Vector2(0, -56), Vector2(-2.2, -60)]), u), Palette.BONE)
	if detail > 0:
		for side in [-1.0, 1.0]:
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(side * 4, -80), Vector2(side * 2.4, -60), Vector2(side * 3.2, -52)]), u), Palette.INK, 0.8 * u, 0.8 * u)
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(-13, -77), Vector2(-14.5, -66), Vector2(-12, -54)]), 3), u), Color(lit, 0.6), 0.3 * u, 0.3 * u, 1.4 * u)
		# Linocut folds: white cuts where the cloth catches the light, dark cuts in the creases.
		for f in [[Vector2(-11.5, -74), Vector2(-9.5, -66), Vector2(-10.5, -57)], [Vector2(-8.5, -76), Vector2(-7.0, -68), Vector2(-7.8, -58)]]:
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array(f), 3), u), Color(Palette.BONE, 0.5), 0.1 * u, 0.05 * u, 0.6 * u)
		for f in [[Vector2(7.5, -76), Vector2(9.5, -67), Vector2(8.5, -56)], [Vector2(10.5, -72), Vector2(12.0, -64), Vector2(11.0, -55)]]:
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array(f), 3), u), Color(Palette.INK, 0.6), 0.1 * u, 0.05 * u, 0.7 * u)
		# Shirt: a shadow cut down one side of the opening.
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(2.6, -79), Vector2(1.4, -62)]), u), Color(Palette.ASH, 0.7), 0.3 * u, 0.1 * u, 1.0 * u)
	# A shawl tied round the hips, knotted at the side with its end hanging.
	var sash := PackedVector2Array([Vector2(-12.5, -54), Vector2(12.5, -54), Vector2(12, -48), Vector2(-12, -48)])
	WoodcutDraw.fill(ci, _u(sash, u), SHAWL)
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(8, -50), Vector2(13, -51), Vector2(14, -38), Vector2(10, -36)]), u), SHAWL)
	if detail > 0:
		for i in 7:
			WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(-10 + 3.2 * float(i), -51), Vector2(0.8, 0.8), 6), u), Color(Palette.EMBER, 0.65))
		for i in 4:
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(10 + float(i), -37), Vector2(10.2 + float(i), -34)]), u), SHAWL, 0.5 * u, 0.3 * u)
	# The strap of small bells across the chest, shoulder to hip.
	var band_a := Vector2(-11, -79) * u
	var band_b := Vector2(12, -54) * u
	WoodcutDraw.stroke(ci, PackedVector2Array([band_a, band_b]), Palette.straps("dark"), 3.0 * u, 3.0 * u)
	var bells := 7 if detail > 0 else 4
	for i in bells:
		var t := (float(i) + 0.5) / float(bells)
		var p := band_a.lerp(band_b, t) + Vector2(0, 1.6 * u)
		WoodcutDraw.fill(ci, WoodcutDraw.ellipse(p, Vector2(1.8, 1.8) * u, 8), BELL_BRONZE)
		WoodcutDraw.fill(ci, WoodcutDraw.ellipse(p + Vector2(-0.5, -0.6) * u, Vector2(0.7, 0.7) * u, 6), Color(Palette.EMBER_HOT, 0.85))
	# Left arm (their right) holds the coiled rope at the hip.
	WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(-13, -76), Vector2(-17, -64), Vector2(-16, -52)]), u), Palette.RED, 6.0 * u, 5.0 * u)
	for i in 3:
		var loop := WoodcutDraw.ellipse(Vector2(-17 + float(i) * 1.1, -44 + float(i) * 0.7), Vector2(4.5, 6.5), 16)
		loop.append(loop[0])
		WoodcutDraw.stroke(ci, _u(loop, u), Palette.ROPE if i != 1 else Palette.ROPE_DARK, 1.3 * u, 1.3 * u)
	WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(-16, -50), Vector2(2.4, 2.2), 8), u), Palette.BONE.darkened(0.15))
	WoodcutDraw.end()


## The throwing arm, pivoting at the shoulder (0, 0) of its own node: drawn pointing down.
static func issohadore_arm(ci: CanvasItem, h: float) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(0, 0), Vector2(2, 12), Vector2(1, 24)]), u), Palette.RED_DEEP, 7.0 * u, 5.5 * u)
	WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(1, 26), Vector2(2.6, 2.4), 8), u), Palette.BONE.darkened(0.2))
	WoodcutDraw.end()


## Where the throwing arm's hand is, relative to its pivot, for a given arm rotation.
static func issohadore_hand(h: float, rot: float) -> Vector2:
	return (Vector2(1, 26) * h / 100.0).rotated(rot)


## Issohadore head: a pale, calm carved mask and the dark cap folded back over the head.
static func issohadore_head(ci: CanvasItem, h: float, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	# Neck and shirt collar.
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(-4, -82), Vector2(4, -82), Vector2(5, -78), Vector2(-5, -78)]), u), Palette.BONE)
	# Cap: a long stocking cap, its end folded back and hanging behind.
	var cap := PackedVector2Array([Vector2(-6.5, -91), Vector2(-6, -97), Vector2(0, -100.5), Vector2(7, -99), Vector2(12, -95),
		Vector2(15, -88), Vector2(13, -85), Vector2(10, -91), Vector2(6.5, -92)])
	WoodcutDraw.fill(ci, WoodcutDraw.smooth_closed(_u(cap, u), 3), CAP)
	# The mask: pale carved wood, cut into planes (brow, cheekbones, nose wedge, chin) with the fire on
	# its left. Almond eye holes and a closed slit of a mouth: calm and still, nothing painted on.
	var face := WoodcutDraw.smooth_closed(_u(PackedVector2Array([Vector2(-5.6, -93), Vector2(5.6, -93), Vector2(6.4, -87), Vector2(4.6, -81.5),
		Vector2(0, -79.5), Vector2(-4.6, -81.5), Vector2(-6.4, -87)]), u), 3)
	WoodcutDraw.fill(ci, face, ISSO_MASK)
	if detail > 0:
		WoodcutDraw.fill(ci, face, Color(Palette.INK, 0.06), Palette.tex("grain"), 1.0 / maxf(h * 0.25, 20.0))
	# Shadow planes: the right side of the face and under the brow, hard-edged like a flat chisel.
	var shade := Color(Palette.ASH, 0.55)
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(2.2, -93), Vector2(5.6, -93), Vector2(6.4, -87), Vector2(4.6, -81.5), Vector2(1.2, -80.2), Vector2(2.4, -84.5), Vector2(3.4, -87.2)]), u), shade)
	for sd in [-1.0, 1.0]:
		# Under the brow ridge: the eye's socket plane.
		WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(sd * 0.8, -89.6), Vector2(sd * 4.6, -90.0), Vector2(sd * 4.2, -87.6), Vector2(sd * 1.2, -87.4)]), u), Color(Palette.ASH, 0.35 if sd < 0.0 else 0.5))
		# Almond eye holes with a dark rim.
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(sd * 2.5, -88.4), Vector2(1.35, 0.55), 10, sd * -0.12), u), Palette.INK)
		# Cheek plane under the cheekbone.
		WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(sd * 2.4, -86.4), Vector2(sd * 5.2, -86.6), Vector2(sd * 3.8, -82.6), Vector2(sd * 2.0, -83.8)]), u), Color(Palette.ASH, 0.22 if sd < 0.0 else 0.45))
	# The nose: a carved wedge, lit on the left, its right face in shadow.
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(0.1, -89.6), Vector2(1.0, -84.9), Vector2(-0.1, -84.5)]), u), Color(Palette.ASH, 0.8))
	# Mouth: a closed slit, cut in ink.
	WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(-1.5, -82.9), Vector2(0, -82.6), Vector2(1.5, -82.9), 4), u), Palette.INK, 0.25 * u, 0.25 * u, 0.45 * u)
	if detail > 0:
		# Ridges picked out with thin ink cuts: brows, nose edge, the chin's lower plane.
		for sd in [-1.0, 1.0]:
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(sd * 0.6, -89.8), Vector2(sd * 2.6, -90.7), Vector2(sd * 4.6, -90.0), 4), u), Color(Palette.INK, 0.7), 0.15 * u, 0.15 * u, 0.4 * u)
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(0.1, -89.6), Vector2(1.0, -84.9), Vector2(-0.8, -84.6)]), u), Color(Palette.INK, 0.75), 0.25 * u, 0.2 * u)
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(-2.2, -81.4), Vector2(0, -80.9), Vector2(2.4, -81.4), 4), u), Color(Palette.INK, 0.35), 0.15 * u, 0.15 * u, 0.35 * u)
		# Firelight rim down the lit edge.
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(-5.0, -92.5), Vector2(-6.2, -87), Vector2(-4.4, -82)]), 3), u), Color(Palette.EMBER_HOT, 0.5), 0.1 * u, 0.1 * u, 0.5 * u)
		WoodcutDraw.outline(ci, face, Color(Palette.INK, 0.9), 0.5 * u, 3)
		# Cap folds: a few pale cuts.
		for f in [[Vector2(-4.5, -96), Vector2(0, -99), Vector2(5, -98.4)], [Vector2(7, -97), Vector2(11, -94), Vector2(13.5, -89)]]:
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array(f), 3), u), Color(Palette.BONE, 0.28), 0.1 * u, 0.05 * u, 0.55 * u)
	WoodcutDraw.end()


## One member of the crowd: a silhouette with a rim of firelight or daylight. `kind` varies the
## headwear: 0 bare, 1 cap, 2 headscarf, 3 hat.
static func crowd_person(ci: CanvasItem, h: float, kind: int, fill: Color, rim: Color, salt := 0) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	var sway := (WoodcutDraw.hash01(salt, 2) - 0.5) * 6.0
	var body := PackedVector2Array([Vector2(-26, 0), Vector2(-24, -48), Vector2(-14, -62), Vector2(14, -62), Vector2(24, -48), Vector2(26, 0)])
	WoodcutDraw.fill(ci, _u(body, u), fill)
	# Coats cut with hatching, darker on the side away from the light.
	WoodcutDraw.fill(ci, _u(body, u), Color(Palette.INK, 0.35), Palette.tex("hatch"), 1.0 / maxf(h * 0.6, 24.0))
	if kind == 0 and WoodcutDraw.hash01(salt, 9) > 0.55:
		# Some raise an arm to watch, or to dodge the rope.
		var arm := _u(PackedVector2Array([Vector2(16, -58), Vector2(24, -80), Vector2(20, -100)]), u)
		WoodcutDraw.stroke(ci, arm, fill, 9.0 * u, 7.0 * u)
	var head := Vector2(sway * 0.3, -76)
	match kind:
		2:
			WoodcutDraw.fill(ci, _u(WoodcutDraw.smooth_closed(PackedVector2Array([head + Vector2(-12, 4), head + Vector2(-10, -12), head + Vector2(0, -16),
				head + Vector2(10, -12), head + Vector2(12, 4), head + Vector2(0, 12)]), 3), u), fill)
		_:
			WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(head, Vector2(10, 12), 12), u), fill)
	if kind == 1:
		WoodcutDraw.fill(ci, _u(PackedVector2Array([head + Vector2(-11, -4), head + Vector2(-8, -14), head + Vector2(9, -14), head + Vector2(14, -6)]), u), fill.darkened(0.2))
	elif kind == 3:
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(head + Vector2(0, -8), Vector2(16, 3.5), 12), u), fill.darkened(0.2))
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(head + Vector2(0, -12), Vector2(9, 6), 10), u), fill.darkened(0.2))
	if rim.a > 0.0:
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([head + Vector2(-9, 6), head + Vector2(-10, -4), head + Vector2(-4, -12)]), 3), u), rim, 0.4 * u, 0.4 * u, 3.0 * u)
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(-14, -61), Vector2(-23, -50), Vector2(-25, -30)]), u), rim, 0.5 * u, 0.2 * u, 3.0 * u)
	WoodcutDraw.end()


static func _u(pts: PackedVector2Array, u: float) -> PackedVector2Array:
	return Transform2D(0.0, Vector2(u, u), 0.0, Vector2.ZERO) * pts
