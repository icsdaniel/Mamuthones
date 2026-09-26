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


## The load of big cowbells on the back: drawn first, behind the body. The row walks to the right,
## so the load shows mostly over the left shoulder and down the left side, as in a three-quarter view.
static func mamuthone_back(ci: CanvasItem, h: float, lit := Palette.EMBER, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	# Rows of bells tied on the back, from the shoulders to the waist, sticking out on the left.
	var bells := [
		[-15, -86, -0.35, 9.5], [-5, -89, -0.1, 9.0], [5, -87, 0.2, 8.5], [14, -82, 0.45, 8.0],
		[-23, -77, -0.55, 10.5], [-27, -64, -0.35, 11.0], [-28, -51, -0.2, 11.0], [-26, -39, -0.1, 10.0],
		[21, -72, 0.4, 8.5], [23, -58, 0.25, 8.5], [22, -45, 0.15, 8.0],
	]
	for b in bells:
		cowbell(ci, Vector2(b[0], b[1]) * u, float(b[3]) * u, b[2], lit, detail)
	# The rope that ties the load, looping round the bells.
	if detail > 0:
		WoodcutDraw.stroke(ci, _u(WoodcutDraw.smooth_open(PackedVector2Array([Vector2(-20, -90), Vector2(-31, -70), Vector2(-33, -46), Vector2(-24, -32)]), 4), u), Color("#3a2618"), 1.6 * u, 1.2 * u)
	WoodcutDraw.end()


## A cowbell: flared iron body, dark mouth, a lit edge on the left. `w` is its mouth width.
static func cowbell(ci: CanvasItem, c: Vector2, w: float, rot: float, lit: Color, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var xf := Transform2D(rot, c)
	var body := PackedVector2Array([Vector2(-0.3, -0.62), Vector2(0.3, -0.62), Vector2(0.44, -0.1), Vector2(0.52, 0.36),
		Vector2(-0.52, 0.36), Vector2(-0.44, -0.1)])
	var pts := xf * (Transform2D(0.0, Vector2(w, w), 0.0, Vector2.ZERO) * body)
	WoodcutDraw.fill(ci, pts, BELL_DARK)
	# Mouth.
	WoodcutDraw.fill(ci, xf * WoodcutDraw.ellipse(Vector2(0, 0.36 * w), Vector2(0.5 * w, 0.12 * w), 10), Palette.INK)
	# Lit edge and a band across the shoulder of the bell.
	var edge := PackedVector2Array([Vector2(-0.28, -0.56), Vector2(-0.42, -0.1), Vector2(-0.48, 0.3)])
	WoodcutDraw.stroke(ci, xf * (Transform2D(0.0, Vector2(w, w), 0.0, Vector2.ZERO) * edge), Color(lit, 0.85), w * 0.03, w * 0.05, w * 0.14)
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
	# Legs: dark trousers into leather leggings, heavy shoes.
	for side in [-1.0, 1.0]:
		var leg := PackedVector2Array([Vector2(side * 2.5, -30), Vector2(side * 10, -30), Vector2(side * 9.5, -2), Vector2(side * 3.2, -2)])
		WoodcutDraw.fill(ci, _u(leg, u), TROUSERS)
		var legging := PackedVector2Array([Vector2(side * 2.8, -18), Vector2(side * 9.9, -18), Vector2(side * 9.6, -2), Vector2(side * 3.2, -2)])
		WoodcutDraw.fill(ci, _u(legging, u), BOOT)
		if detail > 0:
			for i in 3:
				var y := -15.0 + 4.2 * float(i)
				WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(side * 3.6, y), Vector2(side * 9.2, y - 1.4)]), u), Color(lit, 0.45 if side < 0 else 0.2), 0.7 * u, 0.3 * u)
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(side * 6.8, -1.2), Vector2(5.2, 2.2), 10), u), BOOT)
	# Fleece: a heavy shaggy coat from the shoulders to the knees.
	var fl := PackedVector2Array([Vector2(-6, -82), Vector2(6, -82), Vector2(15, -78), Vector2(20, -68), Vector2(22, -50),
		Vector2(22, -28), Vector2(-22, -28), Vector2(-22, -50), Vector2(-20, -68), Vector2(-15, -78)])
	var fpts := WoodcutDraw.smooth_closed(_u(fl, u), 3)
	fpts = WoodcutDraw.rough(fpts, 1.0 * u, 7, maxf(2.0, 2.0 * u))
	WoodcutDraw.fill(ci, fpts, fc)
	var wool := Palette.tex("fleece")
	var wool_scale := 1.0 / maxf(h * 0.55, 40.0)
	WoodcutDraw.fill(ci, fpts, Color(Palette.BONE, 0.22 if detail > 0 else 0.16), wool, wool_scale)
	# Lit side: more wool catches the fire on the left.
	var lit_side := PackedVector2Array([Vector2(-15, -78), Vector2(-4, -80), Vector2(-9, -60), Vector2(-10, -30), Vector2(-22, -28), Vector2(-22, -50), Vector2(-20, -68)])
	WoodcutDraw.fill(ci, WoodcutDraw.smooth_closed(_u(lit_side, u), 3), Color(lit, 0.28), wool, wool_scale)
	# Shadow side.
	var dark_side := PackedVector2Array([Vector2(10, -80), Vector2(15, -78), Vector2(20, -68), Vector2(22, -50), Vector2(22, -28), Vector2(12, -28), Vector2(13, -60)])
	WoodcutDraw.fill(ci, WoodcutDraw.smooth_closed(_u(dark_side, u), 3), Color(Palette.INK, 0.45))
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


## The head: kerchief and the player's carved mask. `mask` is a MaskSpec dictionary.
static func mamuthone_head(ci: CanvasItem, h: float, mask: Dictionary, straps := "natural", detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	MaskView.paint(ci, Vector2(0, -89.5) * u, 4.4 * u, mask, detail, true, "", straps)
	WoodcutDraw.end()


## A whole Mamuthone in one call (for cards, the logo and the icon).
static func mamuthone(ci: CanvasItem, h: float, mask: Dictionary, fleece := "black", straps := "natural", lit := Palette.EMBER, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	mamuthone_back(ci, h, lit, detail)
	mamuthone_body(ci, h, fleece, straps, lit, detail)
	mamuthone_head(ci, h, mask, straps, detail)
	WoodcutDraw.end()


## The ghost: the same silhouette as a faint carved outline.
static func ghost(ci: CanvasItem, h: float, color: Color) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	var outline := PackedVector2Array([Vector2(-6, -98), Vector2(6, -98), Vector2(10, -93), Vector2(11, -83), Vector2(15, -79),
		Vector2(21, -68), Vector2(23, -50), Vector2(22, -28), Vector2(10, -28), Vector2(10, 0), Vector2(-10, 0), Vector2(-10, -28),
		Vector2(-22, -28), Vector2(-30, -40), Vector2(-33, -60), Vector2(-26, -80), Vector2(-16, -90), Vector2(-10, -93)])
	var pts := WoodcutDraw.smooth_closed(_u(outline, u), 3)
	WoodcutDraw.fill(ci, pts, Color(color, color.a * 0.25))
	WoodcutDraw.outline(ci, pts, color, 1.2 * u, 44)
	# Eye holes, so it reads as a masked figure and not a blob.
	for side in [-1.0, 1.0]:
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(side * 3.0, -90), Vector2(1.5, 1.3), 8), u), color)
	WoodcutDraw.end()


## Issohadore body (without the throwing arm and head, which animate on their own).
static func issohadore_body(ci: CanvasItem, h: float, lit := Palette.EMBER, detail := 1) -> void:
	WoodcutDraw.begin(ci)
	var u := h / 100.0
	# Legs: white trousers, dark leggings, shoes.
	for side in [-1.0, 1.0]:
		var leg := PackedVector2Array([Vector2(side * 1.5, -50), Vector2(side * 9.5, -50), Vector2(side * 8.5, -2), Vector2(side * 2.8, -2)])
		WoodcutDraw.fill(ci, _u(leg, u), Palette.BONE if side < 0 else Palette.BONE.darkened(0.3))
		if detail > 0:
			WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(side * 7.5, -48), Vector2(side * 6.5, -22)]), u), Color(Palette.INK, 0.35), 0.6 * u, 0.2 * u)
		WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(side * 2.4, -21), Vector2(side * 9.1, -21), Vector2(side * 8.6, -2), Vector2(side * 2.8, -2)]), u), BOOT)
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(side * 6.0, -1.2), Vector2(4.6, 2.0), 10), u), BOOT)
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
	# The mask.
	var face := WoodcutDraw.smooth_closed(_u(PackedVector2Array([Vector2(-5.6, -93), Vector2(5.6, -93), Vector2(6.4, -87), Vector2(4.6, -81.5),
		Vector2(0, -79.5), Vector2(-4.6, -81.5), Vector2(-6.4, -87)]), u), 3)
	WoodcutDraw.fill(ci, face, ISSO_MASK)
	WoodcutDraw.fill(ci, _u(PackedVector2Array([Vector2(2.5, -93), Vector2(5.6, -93), Vector2(6.4, -87), Vector2(4.6, -81.5), Vector2(1.5, -80), Vector2(3.2, -87)]), u), Color(Palette.ASH, 0.4))
	for side in [-1.0, 1.0]:
		WoodcutDraw.fill(ci, _u(WoodcutDraw.ellipse(Vector2(side * 2.4, -88.5), Vector2(1.2, 0.8), 8), u), Palette.INK)
	if detail > 0:
		for side in [-1.0, 1.0]:
			WoodcutDraw.stroke(ci, _u(WoodcutDraw.quad(Vector2(side * 1.0, -90.2), Vector2(side * 2.4, -91.2), Vector2(side * 3.9, -90.3), 4), u), Color(Palette.INK, 0.75), 0.3 * u, 0.3 * u, 0.6 * u)
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(-0.2, -89.5), Vector2(-0.6, -85.2), Vector2(0.7, -84.8)]), u), Color(Palette.INK, 0.7), 0.4 * u, 0.3 * u)
		WoodcutDraw.stroke(ci, _u(PackedVector2Array([Vector2(-1.6, -82.8), Vector2(1.6, -82.8)]), u), Color(Palette.RED_DEEP, 0.9), 0.6 * u, 0.6 * u)
		WoodcutDraw.outline(ci, face, Color(Palette.INK, 0.9), 0.5 * u, 3)
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
