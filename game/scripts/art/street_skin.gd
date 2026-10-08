class_name StreetSkin
extends RefCounted
## The notes, hit line and bursts over the street picture, after the folk art of Sardinia.
##
## Every tap is a pintadera: the round Nuragic bread stamp, a thick glazed clay disc lying on the road
## with its old pattern pressed into the top (a rim, a ring of sawteeth, a centre boss). The notes
## are real solids: each face is lit on its own (low-poly flat shading, like the picture under them)
## and projected into the street's own perspective, so a disc in an outer lane shows its inner side.
## Everything is drawn from far to near, so a nearer note always covers a farther one.
##
##   step      a blue pintadera; off-beat steps and the Issohadore's calls are smaller ones
##   heal      a green pintadera with su coccu, the black charm bead, at its heart
##   hold      a gold pintadera trailing the Issohadore's rope (sa soca) down the lane
##   stomp     a big black disc of mask wood with a bronze rim and two bare feet: both thumbs
##   bell      the Mamuthone's leather bell strap across the road, bronze cowbells on it and big
##             arrows the way to tilt (red leather up, indigo down)
##   rest      a dim blue band across the lanes

const OUTLINE := Color("#0b0714")
const RIM := Color("#ffffff")
const CREAM := Color("#f6ead0")
const BRONZE := [Color("#f2c46a"), Color("#b0701e"), Color("#4e2a0a")]
const STILL_BLUE := Color("#5f8fe8")
## [light, body, dark, glow] per kind
const K_STEP := [Color("#9ccaff"), Color("#2f78e0"), Color("#163a94"), Color("#4a9cff")]
const K_HEAL := [Color("#a8ffc8"), Color("#26b862"), Color("#0e6632"), Color("#40ff90")]
const K_HOLD := [Color("#ffe9a8"), Color("#e8a820"), Color("#7e5006"), Color("#ffd040")]
const K_WOOD := [Color("#8a7468"), Color("#2c2226"), Color("#120c10"), Color("#ffae40")]
const K_ROPE := [Color("#f0c878"), Color("#c0842c"), Color("#5e3810"), Color("#ffc060")]
const K_UP := [Color("#ff9c8c"), Color("#c8282a"), Color("#5e0c10"), Color("#ff5040")]
const K_OFF := [Color("#d8b4ff"), Color("#8a3fd8"), Color("#461a7a"), Color("#b070ff")]   ## the pixel look's off-beat step
const K_SIX := [Color("#ffffff"), Color("#d2d8e8"), Color("#6c7490"), Color("#eef2ff")]   ## ... a sixteenth (Expert): silver
const K_CALL := [Color("#ffb0d8"), Color("#e0408c"), Color("#7a1446"), Color("#ff70b0")]  ## ... and its call
const K_DOWN := [Color("#a4b6ff"), Color("#3450c0"), Color("#141e5e"), Color("#6080ff")]
const DISC_R := 0.4                  ## a pintadera's radius, in lane widths
const OFF_R := 0.3                   ## ... an off-beat step's or a call's
const STOMP_R := 0.48                ## ... a stomp's
const DISC_H := 0.1                  ## how thick a disc stands, in lane widths
const FORE := 0.42                   ## how much the road's depth is foreshortened on screen
const SIDES := 24                    ## a disc's facets round its edge
const ROPE_W := 0.2                  ## the rope's width, in lane widths
const ROPE_PIC_W := 18                ## cells across the rope's picture is shrunk to (the pixel look)
const STRAP_D := 0.42                ## the bell strap's depth along the road, in lane widths
## The pixel look (PixelFilter over the screen): bursts and sparks are drawn as opaque pixel shapes
## (no soft glows or fades, which the lens would turn to mud): flashes, stamped rings and square embers.
static var pixel := false


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func ci_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if col.a > 0.004 and pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


## A note's frame on the road: centre flat x, flat depth y, half width hw (flat px), and the flat
## half depth that shows `px_d` screen px deep. Returns a Callable mapping (u, h, v) to the screen:
## u across (-1..1), v along the road (-1 far .. 1 near), h up from the road in lane widths.
static func _frame3(lv, field: Rect2, cx: float, y: float, hw: float, px_d: float) -> Callable:
	var dsdy := maxf(0.05, (lv.project(Vector2(cx, y + 1.0)).y - lv.project(Vector2(cx, y - 1.0)).y) * 0.5)
	var hd := px_d * 0.5 / dsdy
	var lane := field.size.x / 3.0
	return func(p: Vector3) -> Vector2:
		var fy := y + p.z * hd
		return lv.project(Vector2(cx + p.x * hw, fy)) - Vector2(0.0, p.y * lv.road_scale(fy) * lane)


## Draws a convex solid: verts in (u, h, v) through frame f, faces as vertex index loops, metric the
## model's scale in lane widths (for the normals). Faces turned away are skipped; the rest are
## flat-shaded from k [light, body, dark, glow], inside a dark outline of width ow.
static func solid(lv, f: Callable, verts: Array[Vector3], faces: Array, metric: Vector3, k: Array, alpha: float, ow: float, flash := 0.0) -> void:
	var scr := PackedVector2Array()
	for v in verts:
		scr.append(f.call(v))
	var mid := Vector3.ZERO
	for v in verts:
		mid += v * metric
	mid /= float(verts.size())
	# the outline: the whole silhouette, a little bigger
	var hull := Geometry2D.convex_hull(scr)
	if hull.size() >= 3:
		lv.draw_polyline(hull, _a(OUTLINE, alpha), ow * 2.0, true)
		ci_poly(lv, hull, _a(OUTLINE, alpha))
	var front_sign := 0.0
	var shaded: Array = []
	for fi in faces.size():
		var loop: Array = faces[fi]
		var m0: Vector3 = verts[loop[0]] * metric
		var m1: Vector3 = verts[loop[1]] * metric
		var m2: Vector3 = verts[loop[loop.size() - 1]] * metric
		var n := (m1 - m0).cross(m2 - m0).normalized()
		var fc := Vector3.ZERO
		for i in loop:
			fc += verts[i] * metric
		fc /= float(loop.size())
		if n.dot(fc - mid) < 0.0:
			n = -n
		var pts := PackedVector2Array()
		for i in loop:
			pts.append(scr[i])
		var area := 0.0
		for i in pts.size():
			area += pts[i].cross(pts[(i + 1) % pts.size()])
		# which screen winding faces the player: the table (the last face, facing up) always does
		var sgn := signf(area) * signf((m1 - m0).cross(m2 - m0).dot(n))
		shaded.append([pts, n, sgn, absf(area)])
	front_sign = shaded[shaded.size() - 1][2]
	for e in shaded:
		if e[2] != front_sign or e[3] < 0.5:
			continue
		_convex(lv, e[0], _a(_shade(e[1], k, flash), alpha))


## A convex polygon as a fan of triangles (never fails on a face seen nearly edge-on).
static func _convex(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if col.a <= 0.004:
		return
	var cols := PackedColorArray([col, col, col])
	for i in range(1, pts.size() - 1):
		ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), cols, PackedVector2Array())


const L_SKY := Vector3(-0.4, 1.0, 0.15)    ## the key light: from above, a little to the left
const L_FIRE := Vector3(0.0, 0.5, -1.0)    ## the bonfire, far up the road
const FIRE_TINT := Color("#ffb468")


## A face's colour from its normal: bright where the sky lights it, the kind's own colour toward the
## player, a warm rim where it faces the fire, a white glint on the table on the beat.
static func _shade(n: Vector3, k: Array, flash: float) -> Color:
	var sky := maxf(0.0, n.dot(L_SKY.normalized()))
	var fire := maxf(0.0, n.dot(L_FIRE.normalized()))
	var b := 1.3 * sky - 0.05
	var col: Color = (k[2] as Color).lerp(k[1], clampf(b, 0.0, 1.0)) if b <= 1.0 else (k[1] as Color).lerp(k[0], clampf((b - 1.0) * 2.0, 0.0, 1.0))
	col = col.lerp(FIRE_TINT, 0.55 * fire * fire)
	if n.y > 0.97:
		col = col.lerp(Color.WHITE, 0.12 + 0.3 * flash)
	return col


static var _glow_tex: Texture2D


## A soft round glow of colour col, radius r (x, y), centred at c.
static func _glow(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	if col.a <= 0.01:
		return
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow_tex = t
	ci.draw_texture_rect(_glow_tex, Rect2(c - r, r * 2.0), false, col)


## How close the note being drawn is to the hit line (0 far .. 1 on it): it glows brighter as it comes.
static var _near := 0.0


static func _lane(field: Rect2) -> float:
	return field.size.x / 3.0


## false while NoteAtlas paints its sprites: a note's glow is drawn live under its sprite instead.
static var paint_glow := true
## The note sheet the pixel look stamps its notes from (set up by LaneView).
static var atlas: NoteAtlas


## The shadow and the coloured glow under a disc centred at c on screen, rx its radius in px.
static func disc_glow(ci: CanvasItem, c: Vector2, rx: float, k: Array, alpha: float, glow := 1.0) -> void:
	_glow(ci, c + Vector2(0.0, rx * FORE * 0.5), Vector2(rx * 1.25, rx * FORE * 1.6), Color(0.0, 0.0, 0.03, 0.6 * alpha))
	_glow(ci, c, Vector2(rx * 1.5, rx * FORE * 2.6) * (1.0 + 0.4 * _near), _a(k[3], (0.3 + 0.45 * _near) * alpha * glow))


## Daniele's pictures of the notes and the rings (game/art/ai, drawn by an outside image AI, 2026-10-08), by key,
## and each shrunk to the sizes it is shown at: one picture pixel per screen cell, so it stays crisp.
static var _ai := {}
static var _ai_sized := {}


static func ai_tex(key: String, size: Vector2i) -> Texture2D:
	if not _ai.has(key):
		# "<name>!flip": the picture upside down; "<name>!mirror": left for right
		var path := "res://art/ai/%s.png" % key.trim_suffix("!flip").trim_suffix("!mirror")
		var img: Image = null
		if ResourceLoader.exists(path):
			img = (load(path) as Texture2D).get_image()
			if img != null:
				img.decompress()
				if key.ends_with("!flip"):
					img.flip_y()
				elif key.ends_with("!mirror"):
					img.flip_x()
		_ai[key] = img if img != null and not img.is_empty() else null
	var src: Image = _ai[key]
	if src == null:
		return null
	size = size.max(Vector2i.ONE)
	var k := "%s_%d_%d" % [key, size.x, size.y]
	if not _ai_sized.has(k):
		var img := src.duplicate() as Image
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		# a cell is the note's or the road's, never half of each
		for yy in size.y:
			for xx in size.x:
				var c := img.get_pixel(xx, yy)
				c.a = 1.0 if c.a > 0.5 else 0.0
				img.set_pixel(xx, yy, c)
		_ai_sized[k] = ImageTexture.create_from_image(img)
	return _ai_sized[k]


## The pixel look's note from its picture: the picture stretched over the disc it stands for (r lane
## widths across, h thick, lying on the road at flat (cx, y)), so it sits and shrinks down the road
## exactly as the drawn disc did. False when there is no picture (the disc is drawn instead).
static func ai_disc(lv, field: Rect2, cx: float, y: float, r: float, key: String, alpha := 1.0, h := DISC_H, glow := 1.0) -> bool:
	if not pixel:
		return false
	if key != "knot":
		key = "note_" + key
	if ai_tex(key, Vector2i.ONE) == null:
		return false
	var lane := _lane(field)
	var lw: float = lv.road_scale(y) * lane
	var f := _frame3(lv, field, cx, y, r * lane, 2.0 * r * lw * FORE)
	if alpha <= 0.01 or lw < 2.0:
		return true
	var lo := Vector2(INF, INF)
	var hi := -lo
	for level: float in [0.0, h]:
		for i in 16:
			var an := TAU * float(i) / 16.0
			var q: Vector2 = f.call(Vector3(cos(an), level, sin(an)))
			lo = lo.min(q)
			hi = hi.max(q)
	if paint_glow:
		disc_glow(lv, f.call(Vector3.ZERO), r * lw, K_STEP if key == "note_step" else K_HOLD, alpha, glow)
	ai_draw(lv, key, lo, hi, Color(1.0, 1.0, 1.0, alpha))
	return true


## Picture `key` over the box lo..hi in whole cells: shrunk to the cells it covers, drawn one to one.
static func ai_draw(ci: CanvasItem, key: String, lo: Vector2, hi: Vector2, mod := Color.WHITE) -> void:
	var px := PxArt.PX
	var cells := Vector2i(((hi - lo) / px).round())
	if cells.x > 40:
		# past the sheet's sizes (a missed note sweeping past the line): fewer sizes to shrink to
		cells = (cells / 4) * 4
	var tex := ai_tex(key, cells)
	if tex == null:
		return
	var at := PxArt.snap2((lo + hi) * 0.5 - Vector2(cells) * px * 0.5)
	ci.draw_texture_rect(tex, Rect2(at, Vector2(cells) * px), false, mod)


## A disc lying on the road centred at flat (cx, y), radius r lane widths, h thick. k: its glaze.
## Returns a Callable mapping (u, v) on its top (the unit circle) to the screen, for its pattern.
static func disc(lv, field: Rect2, cx: float, y: float, r: float, k: Array, alpha := 1.0, h := DISC_H, glow := 1.0, sides := SIDES) -> Callable:
	var lane := _lane(field)
	var lw: float = lv.road_scale(y) * lane
	var f := _frame3(lv, field, cx, y, r * lane, 2.0 * r * lw * FORE)
	var top := func(p: Vector2) -> Vector2: return f.call(Vector3(p.x, h, p.y))
	if alpha <= 0.01 or lw < 2.0:
		return top
	var verts: Array[Vector3] = []
	for level in [0.0, h]:
		for i in sides:
			var an := TAU * (float(i) + 0.5) / sides
			verts.append(Vector3(cos(an), level, sin(an)))
	var faces: Array = []
	for i in sides:
		faces.append([i, (i + 1) % sides, sides + (i + 1) % sides, sides + i])
	var cap: Array = []
	for i in sides:
		cap.append(sides + i)
	faces.append(cap)
	if paint_glow:
		disc_glow(lv, f.call(Vector3.ZERO), r * lw, k, alpha, glow)
	solid(lv, f, verts, faces, Vector3(r, 1.0, r), k, alpha, maxf(PxArt.PX * 0.75 if pixel else 2.0, lw * 0.02), -0.4)
	return top


## The points of a circle of radius rr on a disc's top, through its top mapping.
static func _circle(top: Callable, rr: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var an := TAU * float(i) / n
		pts.append(top.call(Vector2(cos(an), sin(an)) * rr))
	return pts


## The pintadera's pattern pressed into a disc's top: a rim, a ring of sawteeth, an inner ring and
## a boss in the middle, in col, with a lit edge that flares on the beat.
static func _pintadera(lv, top: Callable, lw: float, col: Color, alpha: float, teeth := 12) -> void:
	if lw < 6.0 or alpha <= 0.01:
		return
	var w := maxf(1.5, lw * 0.028)
	var rim := _circle(top, 0.84)
	rim.append(rim[0])
	lv.draw_polyline(rim, _a(col, alpha), w, true)
	for i in teeth:
		var a0 := TAU * float(i) / teeth
		var a1 := TAU * float(i + 1) / teeth
		var am := (a0 + a1) * 0.5
		_convex(lv, PackedVector2Array([top.call(Vector2(cos(a0), sin(a0)) * 0.46), top.call(Vector2(cos(am), sin(am)) * 0.68), top.call(Vector2(cos(a1), sin(a1)) * 0.46)]), _a(col, alpha))
	var inner := _circle(top, 0.42)
	inner.append(inner[0])
	lv.draw_polyline(inner, _a(col, alpha), w * 0.8, true)
	_convex(lv, _circle(top, 0.2, 16), _a(col, alpha))


## A tap: a pintadera in its lane at flat depth y. small: an off-beat step or a call. six: a
## sixteenth (a quarter of a beat off), which the pixel look shows in silver.
static func step(lv, field: Rect2, cx: float, y: float, alpha: float, small := false, call := false, six := false) -> void:
	var lw: float = lv.road_scale(y) * _lane(field)
	if pixel:
		# the pixel look keeps every tap round and full size; the kind shows in its colour: blue on
		# the beat, violet on the half-beat (or a triplet), silver on a sixteenth, pink for a call
		var k: Array = K_CALL if call else (K_SIX if six else (K_OFF if small else K_STEP))
		if ai_disc(lv, field, cx, y, DISC_R, "call" if call else ("six" if six else ("offbeat" if small else "step")), alpha):
			return
		var top := disc(lv, field, cx, y, DISC_R, k, alpha)
		_pintadera(lv, top, lw, CREAM, 0.92 * alpha)
		_dot(lv, top, lw, k[2], alpha)
		return
	var top := disc(lv, field, cx, y, OFF_R if small else DISC_R, K_STEP, alpha)
	_pintadera(lv, top, lw * (OFF_R if small else DISC_R) / DISC_R, CREAM, 0.92 * alpha, 8 if small else 12)
	_dot(lv, top, lw, K_STEP[2], alpha)


static func _dot(lv, top: Callable, lw: float, col: Color, alpha: float) -> void:
	if lw >= 6.0:
		_convex(lv, _circle(top, 0.09, 10), _a(col, alpha))


## A heal: a green pintadera with su coccu, the black charm bead set in silver, at its heart.
static func heal(lv, field: Rect2, cx: float, y: float, alpha: float) -> void:
	if ai_disc(lv, field, cx, y, DISC_R, "heal", alpha):
		return
	var lw: float = lv.road_scale(y) * _lane(field)
	var top := disc(lv, field, cx, y, DISC_R, K_HEAL, alpha)
	_pintadera(lv, top, lw, CREAM, alpha)
	if lw < 6.0:
		return
	var c: Vector2 = top.call(Vector2.ZERO)
	var r: float = lw * DISC_R * 0.2
	lv.draw_circle(c, r * 1.25, _a(Color("#e6ecf2"), alpha))
	lv.draw_circle(c + Vector2(0, -r * 0.1), r * 0.9, _a(Color("#0c0a10"), alpha))
	lv.draw_circle(c + Vector2(-r * 0.3, -r * 0.4), r * 0.25, _a(RIM, 0.9 * alpha))


## A hold's head: a gold pintadera.
static func hold_head(lv, field: Rect2, cx: float, y: float, alpha: float, lit: bool) -> void:
	if ai_disc(lv, field, cx, y, DISC_R, "hold", alpha, DISC_H, 1.6 if lit else 1.0):
		return
	var lw: float = lv.road_scale(y) * _lane(field)
	var top := disc(lv, field, cx, y, DISC_R, K_HOLD, alpha, DISC_H, 1.6 if lit else 1.0)
	_pintadera(lv, top, lw, CREAM, alpha)
	_dot(lv, top, lw, K_HOLD[2], alpha)


## A stomp: a big disc of black mask wood with a bronze rim and two bare feet, thicker than a step.
static func stomp(lv, field: Rect2, cx: float, y: float, alpha: float) -> void:
	if ai_disc(lv, field, cx, y, STOMP_R, "stomp", alpha, DISC_H * 1.6, 1.4):
		return
	var lw: float = lv.road_scale(y) * _lane(field)
	var top := disc(lv, field, cx, y, STOMP_R, K_WOOD, alpha, DISC_H * 1.6, 1.4)
	if lw < 6.0 or alpha <= 0.01:
		return
	var rim := _circle(top, 0.9)
	rim.append(rim[0])
	lv.draw_polyline(rim, _a(BRONZE[0], alpha), maxf(2.0, lw * 0.045), true)
	var sz: float = lw * 0.17
	for foot: float in [-1.0, 1.0]:
		var c: Vector2 = top.call(Vector2(foot * 0.34, 0.15))
		_foot(lv, c, sz + 2.5, foot, _a(OUTLINE, alpha))
		_foot(lv, c, sz, foot, _a(CREAM, alpha))


## The Issohadore's rope down a hold's lane from flat depth ya (far) to yb (near): a round hemp cord
## lying on the road, twisted, glowing while it is held.
static func rope(lv: LaneView, field: Rect2, cx: float, ya: float, yb: float, lit: bool, alpha := 1.0) -> void:
	var lane := _lane(field)
	var hw := lane * ROPE_W * 0.5
	var h := ROPE_W * 0.55
	var f := func(p: Vector3) -> Vector2:
		var fy := lerpf(ya, yb, (p.z + 1.0) * 0.5)
		return lv.project(Vector2(cx + p.x * hw, fy)) - Vector2(0.0, p.y * lv.road_scale(fy) * lane)
	# a rounded cord: five faces round its top
	var prof := [Vector2(-1.0, 0.0), Vector2(-0.8, 0.6), Vector2(-0.3, 1.0), Vector2(0.3, 1.0), Vector2(0.8, 0.6), Vector2(1.0, 0.0)]
	var verts: Array[Vector3] = []
	for z in [-1.0, 1.0]:
		for q: Vector2 in prof:
			verts.append(Vector3(q.x, q.y * h, z))
	var faces: Array = []
	for i in prof.size() - 1:
		faces.append([i, i + 1, prof.size() + i + 1, prof.size() + i])
	var metric := Vector3(ROPE_W * 0.5, 1.0, maxf(yb - ya, 1.0) / lane * 0.5 / FORE)
	if lit:
		_glow(lv, f.call(Vector3(0, 0, 1)), Vector2(hw * 4.0, hw * 2.0), _a(K_ROPE[3], 0.6 * alpha))
	if pixel and _rope_pic(lv, f, ya, yb, lane, lit, alpha):
		_rope_sparks(lv, f, h, yb, lane, lit)
		return
	# faces are drawn back to front by hand: the cord is not closed, so it is outlined as a band
	var band := PackedVector2Array([f.call(Vector3(-1, 0, -1)), f.call(Vector3(-1, 0, 1)), f.call(Vector3(1, 0, 1)), f.call(Vector3(1, 0, -1))])
	var tb := PackedVector2Array([f.call(Vector3(-1, 0, -1)), f.call(Vector3(-0.3, h, -1)), f.call(Vector3(0.3, h, -1)), f.call(Vector3(1, 0, -1)), f.call(Vector3(1, 0, 1)), f.call(Vector3(0.3, h, 1)), f.call(Vector3(-0.3, h, 1)), f.call(Vector3(-1, 0, 1))])
	var hull := Geometry2D.convex_hull(PackedVector2Array(Array(band) + Array(tb)))
	lv.draw_polyline(hull, _a(OUTLINE, alpha), 5.0, true)
	ci_poly(lv, hull, _a(OUTLINE, alpha))
	var tint := 1.0 if lit else 0.85
	for fc in faces:
		var pts := PackedVector2Array()
		var m0: Vector3 = verts[fc[0]] * metric
		var m1: Vector3 = verts[fc[1]] * metric
		var n := Vector3(0, 0, 1).cross(m1 - m0).normalized()
		if n.y < 0.0:
			n = -n
		for i in fc:
			pts.append(f.call(verts[i]))
		_convex(lv, pts, _a(_shade(n, K_ROPE, -0.4) * Color(tint, tint, tint), alpha))
	# the twist: dark strands slanting across it, fixed to the rope so they travel with it
	var step_y := lane * 0.16
	var yy := yb - fposmod(yb - ya, step_y)
	var col := _a(K_ROPE[2], 0.9 * alpha)
	while yy > ya + 1.0:
		var z0 := (yy - ya) / maxf(yb - ya, 1.0) * 2.0 - 1.0
		var dz := step_y * 0.5 / maxf(yb - ya, 1.0) * 2.0
		var s0: Vector2 = f.call(Vector3(-0.85, h * 0.55, z0 + dz))
		var s1: Vector2 = f.call(Vector3(0.85, h * 0.55, z0 - dz))
		lv.draw_line(s0, s1, col, maxf(2.0, lv.road_scale(yy) * lane * 0.035), true)
		yy -= step_y
	if lit:
		lv.draw_line(f.call(Vector3(-0.3, h, -1)), f.call(Vector3(-0.3, h, 1)), _a(RIM, 0.6 * alpha), 2.0, true)
	_rope_sparks(lv, f, h, yb, lane, lit)


static func _rope_sparks(lv: LaneView, f: Callable, h: float, yb: float, lane: float, lit: bool) -> void:
	if lit:
		# sparks fly off the rope where it runs into the slot while it is held
		var at: Vector2 = f.call(Vector3(0, h, 1))
		var lw: float = lv.road_scale(yb) * lane
		for i in 3:
			var age := fposmod(lv._clock + float(i) * 0.11, 0.33)
			if pixel:
				_embers_px(lv, at, lw * 0.6, age, 4, int(lv._clock / 0.33) * 5 + i, PX_HOT, 0.8)
			else:
				_embers(lv, at, lw * 0.6, age, 4, int(lv._clock / 0.33) * 5 + i, K_ROPE[0], 0.8)


## The pixel look's rope from Daniele's picture, laid along the hold through the cord's frame f: the
## picture repeats down the road, its twist fixed to the rope's far end (the hold's end) so it travels
## with it. False when there is no picture.
static func _rope_pic(lv: LaneView, f: Callable, ya: float, yb: float, lane: float, lit: bool, alpha: float) -> bool:
	var tex := ai_tex("rope", Vector2i(ROPE_PIC_W, roundi(ROPE_PIC_W * 794.0 / 143.0)))
	if tex == null:
		return false
	# one picture's length along the road, flat px: its own shape, at the rope's width, foreshortened
	var tile := lane * ROPE_W * (794.0 / 143.0) * 0.5 / FORE
	var span := maxf(yb - ya, 1.0)
	var mod := Color(1.0, 1.0, 1.0, alpha) if lit else Color(0.85, 0.85, 0.85, alpha)
	# in pieces that never cross a picture's end, so each piece maps into the one picture
	var q := tile * 0.25
	var d := 0.0
	var guard := 0
	while d < span and guard < 256:
		guard += 1
		var e := minf(span, (floorf(d / q + 0.001) + 1.0) * q)
		var v0 := fposmod(d, tile) / tile
		var v1 := v0 + (e - d) / tile
		var z0 := -1.0 + 2.0 * d / span
		var z1 := -1.0 + 2.0 * e / span
		var pts := PackedVector2Array([f.call(Vector3(-1, 0, z0)), f.call(Vector3(1, 0, z0)), f.call(Vector3(1, 0, z1)), f.call(Vector3(-1, 0, z1))])
		var uvs := PackedVector2Array([Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)])
		lv.draw_polygon(pts, PackedColorArray([mod, mod, mod, mod]), uvs, tex)
		d = e
	return true


## A bell note: the Mamuthone's leather bell strap across the whole road at flat depth y, a bronze
## cowbell standing on it at each lane divider, and a big arrow in each lane the way to tilt.
static func bell(lv: LaneView, field: Rect2, y: float, up: bool, alpha := 1.0, pal: Array = [], cowbells := true) -> void:
	var lane := _lane(field)
	var lw: float = lv.road_scale(y) * lane
	var k: Array = pal if not pal.is_empty() else (K_UP if up else K_DOWN)
	var x0 := -field.size.x * 0.02
	var x1 := field.size.x * 1.02
	var hw := (x1 - x0) * 0.5
	var f := _frame3(lv, field, (x0 + x1) * 0.5, y, hw, STRAP_D * lw * FORE)
	var h := DISC_H * 0.7
	var verts: Array[Vector3] = []
	for lvl in [0.0, h]:
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			verts.append(Vector3(q.x, lvl, q.y))
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7]]
	if alpha <= 0.01 or lw < 2.0:
		return
	_glow(lv, f.call(Vector3.ZERO), Vector2(hw * 1.1, lw * 0.35), _a(k[3], 0.3 * alpha))
	if pixel and ai_tex("bar_up", Vector2i.ONE) != null:
		_bell_pic(lv, f, h, lane, lw, y, up, alpha, not pal.is_empty(), cowbells)
		return
	solid(lv, f, verts, faces, Vector3(hw / lane, 1.0, STRAP_D * 0.5), k, alpha, maxf(2.0, lw * 0.02), -0.4)
	if lw < 6.0:
		return
	# stitching along both edges
	for v: float in [-0.62, 0.62]:
		var u := -1.0
		while u < 1.0:
			lv.draw_line(f.call(Vector3(u, h, v)), f.call(Vector3(u + 0.012, h, v)), _a(CREAM, 0.85 * alpha), maxf(1.0, lw * 0.014), true)
			u += 0.03
	# the bells at the lane dividers, the arrows in the lanes
	for i in (2 if cowbells else 0):
		var bx := lane * float(i + 1)
		var at := lv.project(Vector2(bx, y)) - Vector2(0.0, h * lw)
		_cowbell(lv, at, lw * 0.3, alpha)
	var d := -1.0 if up else 1.0
	for i in 3:
		var c: Vector2 = lv.project(Vector2(lane * (float(i) + 0.5), y)) - Vector2(0.0, h * lw)
		var a := lw * 0.2
		var hh := lw * 0.14
		var m := c + Vector2(0.0, -hh * 0.6)
		var tri := PackedVector2Array([m + Vector2(-a, -d * hh), m + Vector2(0.0, d * hh), m + Vector2(a, -d * hh)])
		var ring := tri.duplicate()
		ring.append(tri[0])
		lv.draw_polyline(ring, _a(OUTLINE, alpha), maxf(3.0, lw * 0.04), true)
		_convex(lv, tri, _a(RIM, alpha))


## The pixel look's bell note from Daniele's pictures: the red (up) or blue (down) beam across the
## road through the strap's frame f, his bells at the lane dividers, his arrow in each lane (upside
## down for a tilt down). hot: lit up by a strike.
static func _bell_pic(lv: LaneView, f: Callable, h: float, lane: float, lw: float, y: float, up: bool, alpha: float, hot: bool, cowbells: bool) -> void:
	var mod := Color(1.45, 1.4, 1.3, alpha) if hot else Color(1.0, 1.0, 1.0, alpha)
	var quad := PackedVector2Array([f.call(Vector3(-1, h, -1)), f.call(Vector3(1, h, -1)), f.call(Vector3(1, 0, 1)), f.call(Vector3(-1, 0, 1))])
	var w := quad[1].x - quad[0].x
	var tall := quad[2].y - quad[1].y
	# few sizes (a beam slides down every frame): the picture shrunk to a width in steps of 8 cells
	var cells := Vector2i(maxi(8, roundi(w / PxArt.PX / 8.0) * 8), maxi(3, roundi(tall / PxArt.PX)))
	var tex := ai_tex("bar_up" if up else "bar_down", cells)
	lv.draw_polygon(quad, PackedColorArray([mod, mod, mod, mod]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), tex)
	if lw < 6.0:
		return
	var top := (quad[0].y + quad[2].y) * 0.5 - h * lw
	for i in (2 if cowbells else 0):
		var at := Vector2(lv.project(Vector2(lane * float(i + 1), y)).x, top + tall * 0.25)
		var s := lw * 0.34
		ai_draw(lv, "bar_bell", at - Vector2(s * 0.35, s), at + Vector2(s * 0.35, 0.0), mod)
	for i in 3:
		var c := Vector2(lv.project(Vector2(lane * (float(i) + 0.5), y)).x, top - lw * 0.02)
		var a := lw * 0.25
		var hh := lw * 0.23
		ai_draw(lv, "bar_arrow" if up else "bar_arrow!flip", c - Vector2(a, hh * 1.4), c + Vector2(a, hh * 0.4), mod)


## A bronze cowbell standing with its mouth on the ground at `at` (screen), s tall: a flared body,
## lit on the left, a dark mouth, a loop on top.
static func _cowbell(lv: LaneView, at: Vector2, s: float, alpha: float) -> void:
	if pixel and ai_tex("bar_bell", Vector2i.ONE) != null:
		ai_draw(lv, "bar_bell", at - Vector2(s * 0.42, s * 1.2), at + Vector2(s * 0.42, 0.0), Color(1.0, 1.0, 1.0, alpha))
		return
	var body := PackedVector2Array([at + Vector2(-s * 0.42, 0.0), at + Vector2(-s * 0.3, -s * 0.85), at + Vector2(-s * 0.18, -s), at + Vector2(s * 0.18, -s),
		at + Vector2(s * 0.3, -s * 0.85), at + Vector2(s * 0.42, 0.0)])
	lv.draw_circle(at + Vector2(0, -s * 1.05), s * 0.14 + 2.0, _a(OUTLINE, alpha))
	lv.draw_circle(at + Vector2(0, -s * 1.05), s * 0.14, _a(BRONZE[1], alpha))
	lv.draw_circle(at + Vector2(0, -s * 1.05), s * 0.06, _a(OUTLINE, alpha))
	var ring := body.duplicate()
	ring.append(body[0])
	lv.draw_polyline(ring, _a(OUTLINE, alpha), 4.0, true)
	_convex(lv, body, _a(BRONZE[1], alpha))
	_convex(lv, PackedVector2Array([body[0], body[1], body[2], at + Vector2(-s * 0.02, -s), at + Vector2(-s * 0.08, 0.0)]), _a(BRONZE[0], alpha))
	_convex(lv, PackedVector2Array([at + Vector2(s * 0.2, 0.0), at + Vector2(s * 0.16, -s * 0.9), body[3], body[4], body[5]]), _a(BRONZE[2], alpha))
	_ellipse(lv, at, Vector2(s * 0.42, s * 0.1), _a(OUTLINE, alpha))


## A stand-still band across the road between screen rows y_top and y_bottom.
static func band(ci: CanvasItem, lt: Vector2, rt: Vector2, rb: Vector2, lb: Vector2, alpha := 1.0) -> void:
	ci.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), Color(0.1, 0.16, 0.45, 0.42 * alpha))
	for e in [[lt, rt, 3.0], [lb, rb, 4.5]]:
		ci.draw_line(e[0], e[1], Color(OUTLINE, 0.8 * alpha), e[2] + 5.0, true)
		ci.draw_line(e[0], e[1], Color(STILL_BLUE.lightened(0.3), alpha), e[2], true)


## A bare footprint (left foot -1, right 1), upright on screen, s its size.
static func _foot(ci: CanvasItem, c: Vector2, s: float, foot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var an := TAU * float(i) / 16.0
		var k := 1.0 if sin(an) < 0.0 else 0.8
		pts.append(c + Vector2(cos(an) * s * 0.42 * k, sin(an) * s * 0.7 + s * 0.2))
	ci.draw_colored_polygon(pts, col)
	for t in 4:
		var tx := (float(t) - 1.5) * s * 0.24 * -foot
		ci.draw_circle(c + Vector2(tx, -s * 0.66 + absf(float(t) - 1.0) * s * 0.06), s * (0.15 if t == 0 else 0.11), col)


## A hit burst: the pintadera's pattern stamped into the road where the note landed, glowing and
## fading; light rising from the lane; and a spray of embers thrown up out of the slot, falling back.
## A miss is a dull red ring and a few grey cinders. False once it is over.
static func burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc: float) -> bool:
	var tt := age / LaneSkin.BURST_TIME
	if tt >= 1.0 or tt < 0.0:
		return false
	var lw := sc * 240.0
	if ci is LaneView:
		lw = sc * (ci as LaneView).field_rect().size.x / 3.0
	if pixel:
		_burst_px(ci, at, quality, age, tt, lw)
		return true
	var e := 1.0 - pow(1.0 - tt, 3.0)
	var a := pow(1.0 - tt, 1.4)
	var seed := int(absf(at.x) * 13.0) + quality.length() * 7
	if quality == "miss":
		_ring(ci, at, Vector2(lw * DISC_R, lw * DISC_R * FORE) * (1.0 + 0.3 * e), maxf(2.0, lw * 0.03), Color(0.75, 0.15, 0.12, 0.8 * a))
		_embers(ci, at, lw, age, 5, seed, Color(0.45, 0.4, 0.4), 0.5)
		return true
	var col: Color = {
		"perfect": Color("#fffbe8"), "good": Color("#ffd35a"), "ok": Color("#ff9a3a"), "early": Color("#ff9a3a"),
		"late": Color("#ff9a3a"), "heal": Color("#8affb8"), "held": Color("#ffe27a"), "stomp": Color("#ffc060"),
	}.get(quality, Color("#ffd35a"))
	var big := 1.6 if quality == "stomp" else (1.25 if quality == "perfect" else 1.0)
	# light rising from the lane
	var pw := lw * 0.42 * (1.0 - 0.3 * tt)
	var ph := lw * (0.9 + 0.7 * e) * big
	ci.draw_polygon(PackedVector2Array([at + Vector2(-pw, 0), at + Vector2(pw, 0), at + Vector2(pw * 0.6, -ph), at + Vector2(-pw * 0.6, -ph)]),
		PackedColorArray([Color(col, 0.65 * a), Color(col, 0.65 * a), Color(col, 0.0), Color(col, 0.0)]))
	_glow(ci, at, Vector2(lw * (0.7 + 0.4 * e), lw * (0.35 + 0.2 * e)) * big, Color(col, 0.9 * a))
	# the stamp: the pintadera's rim and teeth pressed into the road, spreading a little as it fades
	var r: float = lw * DISC_R * (1.0 + 0.25 * e) * big
	var top := func(p: Vector2) -> Vector2: return at + Vector2(p.x * r, p.y * r * FORE)
	var sa := a * a
	_ring(ci, at, Vector2(r, r * FORE) * 0.86, maxf(2.0, lw * 0.03), Color(col, sa))
	for i in 12:
		var a0 := TAU * float(i) / 12.0
		var a1 := TAU * float(i + 1) / 12.0
		var am := (a0 + a1) * 0.5
		ci.draw_colored_polygon(PackedVector2Array([top.call(Vector2(cos(a0), sin(a0)) * 0.46), top.call(Vector2(cos(am), sin(am)) * 0.7), top.call(Vector2(cos(a1), sin(a1)) * 0.46)]), Color(col, 0.8 * sa))
	# the outer shock ring
	_ring(ci, at, Vector2(r, r * FORE) * (1.0 + 0.9 * e), maxf(2.0, lw * 0.04 * (1.0 - tt)), Color(col, 0.8 * a))
	_embers(ci, at, lw * big, age, 14 if quality == "stomp" else 10, seed, col, 1.0)
	return true


const PX_HOT := [Color("#fffaf0"), Color("#ffe9a8"), Color("#ffd35a"), Color("#ff9a32"), Color("#c8282a")]


## The pixel look's hit: a white flash for a frame or two, the pintadera's stamp pressed into the road
## in the hit's colour that breaks up as it fades, a shock ring running out, and square embers thrown
## up that cool from white through gold to red. A miss: a dull red ring and grey cinders.
static func _burst_px(ci: CanvasItem, at: Vector2, quality: String, age: float, tt: float, lw: float) -> void:
	var px := PxArt.PX
	var e := 1.0 - pow(1.0 - tt, 3.0)
	var seed := int(absf(at.x) * 13.0) + quality.length() * 7
	if quality == "miss":
		if tt < 0.7:
			_ring(ci, at, Vector2(lw * DISC_R, lw * DISC_R * FORE) * (1.0 + 0.3 * e), px * 2.0, Color("#a83030"))
		_embers_px(ci, at, lw, age, 5, seed, [Color("#8a7e7a"), Color("#5a4e4e")], 0.5)
		return
	var col: Color = {
		"perfect": Color("#fffbe8"), "good": Color("#ffd35a"), "ok": Color("#ff9a3a"), "early": Color("#ff9a3a"),
		"late": Color("#ff9a3a"), "heal": Color("#8affb8"), "held": Color("#ffe27a"), "stomp": Color("#ffc060"),
	}.get(quality, Color("#ffd35a"))
	var big := 1.6 if quality == "stomp" else (1.25 if quality == "perfect" else 1.0)
	var r: float = lw * DISC_R * (1.0 + 0.25 * e) * big
	# the flash: the whole stamp lit white for the first instant
	if age < 0.05:
		_ellipse(ci, at, Vector2(r, r * FORE) * 1.05, Color.WHITE)
	# the stamp: rim and teeth, whole at first, then every other piece, then gone
	var keep := 1 if tt < 0.35 else (2 if tt < 0.6 else 0)
	if keep > 0:
		var top := func(p: Vector2) -> Vector2: return at + Vector2(p.x * r, p.y * r * FORE)
		_ring(ci, at, Vector2(r, r * FORE) * 0.86, px * 2.0, col)
		for i in 12:
			if i % keep != 0:
				continue
			var a0 := TAU * float(i) / 12.0
			var a1 := TAU * float(i + 1) / 12.0
			var am := (a0 + a1) * 0.5
			ci.draw_colored_polygon(PackedVector2Array([top.call(Vector2(cos(a0), sin(a0)) * 0.46), top.call(Vector2(cos(am), sin(am)) * 0.72), top.call(Vector2(cos(a1), sin(a1)) * 0.46)]), col)
	# the shock ring running out, thinning to one pixel
	if tt < 0.55:
		_ring(ci, at, Vector2(r, r * FORE) * (1.0 + 0.9 * e), px * (2.0 if tt < 0.3 else 1.0), col.lerp(Color.WHITE, 0.3))
	_embers_px(ci, at, lw * big, age, 14 if quality == "stomp" else 10, seed, PX_HOT, 1.0)


## Square embers (whole pixels) thrown up from `at` and falling back, cooling through `ramp`.
static func _embers_px(ci: CanvasItem, at: Vector2, lw: float, age: float, n: int, seed: int, ramp: Array, power: float) -> void:
	var life := LaneSkin.BURST_TIME * 1.1
	if age >= life:
		return
	var k := age / life
	var px := PxArt.PX
	for i in n:
		var h := hash(seed * 31 + i * 7919)
		var ang := -PI * (0.12 + 0.76 * float(h % 1000) / 1000.0)
		var spd := lw * power * (2.2 + 2.6 * float((h / 1000) % 1000) / 1000.0)
		var v := Vector2(cos(ang), sin(ang)) * spd
		var p := at + v * age + Vector2(0.0, lw * 9.0 * age * age)
		# some die early, so the spray thins out instead of fading
		if k > 0.45 + 0.5 * float((h / 7) % 100) / 100.0:
			continue
		var col: Color = ramp[mini(int(k * ramp.size()), ramp.size() - 1)]
		var sz := px * (2.0 if k < 0.4 and i % 3 == 0 else 1.0)
		ci.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)


## Embers thrown up from `at` and falling back under gravity, `n` of them, the same for the same seed.
static func _embers(ci: CanvasItem, at: Vector2, lw: float, age: float, n: int, seed: int, col: Color, power: float) -> void:
	var life := LaneSkin.BURST_TIME * 1.1
	if age >= life:
		return
	var k := 1.0 - age / life
	for i in n:
		var h := hash(seed * 31 + i * 7919)
		var ang := -PI * (0.12 + 0.76 * float(h % 1000) / 1000.0)
		var spd := lw * power * (2.2 + 2.6 * float((h / 1000) % 1000) / 1000.0)
		var v := Vector2(cos(ang), sin(ang)) * spd
		var p := at + v * age + Vector2(0.0, lw * 9.0 * age * age)
		var tail := p - (v + Vector2(0.0, lw * 18.0 * age)) * 0.03
		var w := maxf(1.5, lw * 0.025 * k)
		ci.draw_line(tail, p, Color(col.lerp(Color("#ff7a20"), 1.0 - k), k), w, true)
		ci.draw_circle(p, w * 0.8, Color(Color.WHITE.lerp(col, 0.5), k))


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


static func _ring(ci: CanvasItem, c: Vector2, r: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 29:
		var a := TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_polyline(pts, col, w, true)


# ------------------------------------------------------------------ the whole field

## The stand-still bands and the ropes lie flat under everything; then the hit line and its slots;
## then every note from far to near, so a nearer one always covers a farther one.
static func draw_notes(lv: LaneView, field: Rect2) -> void:
	field.position = Vector2.ZERO
	var rects := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	var shown := lv._notes_shown(field)
	var items: Array = []   # [flat depth, what, note, lane centre x, alpha]
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		match n.kind:
			Note.Kind.REST:
				if n.finished:
					continue
				var y0 := maxf(minf(y, e[2]), 0.0)
				var y1 := minf(maxf(y, e[2]), hl)
				if y1 - y0 > 2.0:
					# faded by its near edge: a long stand-still whose far end is still past the end of the
					# road must show as soon as it comes into view, not only once its end does
					band(lv, lv.project(Vector2(0, y0)), lv.project(Vector2(field.size.x, y0)), lv.project(Vector2(field.size.x, y1)), lv.project(Vector2(0, y1)), lv._haze(y1, field))
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var cx := rects[n.lane].get_center().x
				var head := minf(y, hl) if n.holding else y
				var tail := maxf(float(e[2]), 0.0)
				if head - tail > 1.0:
					# faded by its near end, like the band: a rope still running past the end of the road shows
					rope(lv, field, cx, tail, head, n.holding, lv._haze(head, field))
				if float(e[2]) > 0.0:
					items.append([float(e[2]), "knot", n, cx, lv._haze(e[2], field)])
				items.append([head, "hold", n, cx, lv._haze(head, field)])
			Note.Kind.STEP, Note.Kind.STOMP, Note.Kind.BELL, Note.Kind.RING:
				if not n.done:
					items.append([y, "note", n, rects[maxi(n.lane, 0)].get_center().x, lv._haze(y, field)])
	# the pixel look tints each lane's slot with the colour of the note coming down it, more as it nears
	var incoming: Array = [null, null, null]
	if pixel:
		var reach := _lane(field) * 4.0
		for it in items:
			var n: Note = it[2]
			var lane := n.lane
			if lane < 0 or lane > 2 or str(it[1]) == "knot" or n.kind == Note.Kind.BELL:
				continue
			var near := clampf(1.0 - (hl - float(it[0])) / reach, 0.0, 1.0)
			if near > 0.0 and (incoming[lane] == null or near > float(incoming[lane][1])):
				incoming[lane] = [_kind(lv, n, str(it[1]) == "hold"), near]
	_hit_line(lv, field, rects, hl, incoming)
	for c in lv.chords_shown(shown):
		cord(lv, field, rects[c[1]].get_center().x, rects[c[2]].get_center().x, float(c[0]), lv._haze(c[0], field))
	items.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for it in items:
		var y: float = it[0]
		var n: Note = it[2]
		var cx: float = it[3]
		var a: float = it[4]
		_near = clampf(1.0 - (hl - y) / (_lane(field) * 2.5), 0.0, 1.0)
		if pixel and atlas != null and atlas.ready_for(lv) and _stamp(lv, field, str(it[1]), n, cx, y, a):
			continue
		match str(it[1]):
			"knot":
				_knot(lv, field, cx, y, a)
			"hold":
				hold_head(lv, field, cx, y, a, n.holding)
			_:
				match n.kind:
					Note.Kind.STEP:
						if n.heal:
							heal(lv, field, cx, y, a)
						else:
							step(lv, field, cx, y, a, n.call or lv._off_beat(n), n.call, not n.call and lv._sixteenth(n))
					Note.Kind.STOMP:
						stomp(lv, field, cx, y, a * (0.6 if n.thumbs > 0 else 1.0))
					Note.Kind.BELL:
						bell(lv, field, y, n.up, a)
					Note.Kind.RING:
						bell(lv, field, y, n.up, a)
						step(lv, field, cx, y, a, true)


## A chord: two notes on one beat, joined by a bar in the steps' blue lying across the road between their centres, so
## the pair reads as one press with both thumbs. Drawn under the notes.
static func cord(lv: LaneView, field: Rect2, x0: float, x1: float, y: float, alpha: float) -> void:
	var lw: float = lv.road_scale(y) * _lane(field)
	if lw < 2.0 or alpha <= 0.01:
		return
	var a: Vector2 = lv.project(Vector2(x0, y))
	var b: Vector2 = lv.project(Vector2(x1, y))
	var w := maxf(2.0, lw * 0.11)
	lv.draw_line(a, b, _a(K_STEP[2], alpha), w + maxf(2.0, lw * 0.05))
	lv.draw_line(a, b, _a(K_STEP[1], alpha), w)
	lv.draw_line(a + Vector2(0, -w * 0.22), b + Vector2(0, -w * 0.22), _a(K_STEP[0], alpha * 0.8), maxf(1.0, w * 0.3))


## Stamps a note from the pixel look's sheet, with its glow drawn live under it. False when the
## note is not one the sheet holds (a bell strap): it is then drawn in full.
static func _stamp(lv: LaneView, field: Rect2, what: String, n: Note, cx: float, y: float, a: float) -> bool:
	var key := ""
	var k: Array = K_STEP
	var r := DISC_R
	var glow := 1.0
	match what:
		"knot":
			key = "knot"; k = K_ROPE; r = ROPE_W * 0.85; glow = 0.6
		"hold":
			key = "hold"; k = K_HOLD; glow = 1.6 if n.holding else 1.0
		_:
			match n.kind:
				Note.Kind.STEP:
					if n.heal:
						key = "heal"; k = K_HEAL
					elif n.call:
						key = "call"; k = K_CALL
					elif lv._sixteenth(n):
						key = "six"; k = K_SIX
					elif lv._off_beat(n):
						key = "off"; k = K_OFF
					else:
						key = "step"
				Note.Kind.STOMP:
					key = "stomp"; k = K_WOOD; r = STOMP_R; glow = 1.4
					a *= 0.6 if n.thumbs > 0 else 1.0
				Note.Kind.RING:
					key = "off"; k = K_OFF
				_:
					return false
	var lw: float = lv.road_scale(y) * _lane(field)
	if lw < 2.0 or a <= 0.01:
		return true
	if not atlas.covers(lw):
		return false
	if n.kind == Note.Kind.RING and what != "hold" and what != "knot":
		bell(lv, field, y, n.up, a)
	var c: Vector2 = lv.project(Vector2(cx, y))
	disc_glow(lv, c, r * lw, k, a, glow)
	atlas.stamp(lv, key, c, lw, a)
	return true


## The rope's far end: a small knot of hemp.
static func _knot(lv, field: Rect2, cx: float, y: float, alpha: float) -> void:
	if ai_disc(lv, field, cx, y, ROPE_W * 1.35, "knot", alpha, ROPE_W * 0.9, 0.6):
		return
	disc(lv, field, cx, y, ROPE_W * 0.85, K_ROPE, alpha, ROPE_W * 0.6, 0.6)


## The hit line across the road, and in each lane a slot: a pintadera's outline pressed into the
## road, brighter when a note is about to reach it, filling with light while its button is down,
## breathing with the beat.
## A note's glaze [light, body, dark, glow], as drawn.
static func _kind(lv: LaneView, n: Note, hold: bool) -> Array:
	if hold:
		return K_HOLD
	match n.kind:
		Note.Kind.STOMP:
			return [BRONZE[0], K_WOOD[1], K_WOOD[2], K_WOOD[3]]
		Note.Kind.STEP:
			if n.heal:
				return K_HEAL
			if pixel and n.call:
				return K_CALL
			if pixel and lv._sixteenth(n):
				return K_SIX
			if pixel and lv._off_beat(n):
				return K_OFF
	return K_STEP


## The hit line's three slots, worked out once per layout (it never moves): for each lane its
## centre, its outline, that outline closed, and the inner ring closed.
static var _slot_key := []
static var _slot_cache := []

static func _slots(lv: LaneView, field: Rect2, rects: Array[Rect2], hl: float, lw: float) -> Array:
	var key := [lv.get_instance_id(), field.size, hl, lv.project(Vector2.ZERO), lv.project(Vector2(field.size.x, hl))]
	if key == _slot_key:
		return _slot_cache
	_slot_key = key
	_slot_cache = []
	for lane in 3:
		var f := _frame3(lv, field, rects[lane].get_center().x, hl, DISC_R * _lane(field), 2.0 * DISC_R * lw * FORE)
		var top := func(p: Vector2) -> Vector2: return f.call(Vector3(p.x, 0.0, p.y))
		var sil := _circle(top, 1.0)
		var ring := sil.duplicate()
		ring.append(sil[0])
		var inner := _circle(top, 0.7)
		inner.append(inner[0])
		_slot_cache.append([f.call(Vector3.ZERO), sil, ring, inner])
	return _slot_cache


static func _hit_line(lv: LaneView, field: Rect2, rects: Array[Rect2], hl: float, incoming: Array = [null, null, null]) -> void:
	var l := lv.project(Vector2(-field.size.x * 0.02, hl))
	var r: Vector2 = lv.project(Vector2(field.size.x * 1.02, hl))
	var env := lv.beat_env()
	var lw: float = lv.road_scale(hl) * _lane(field)
	var slots := _slots(lv, field, rects, hl, lw)
	# the line runs between the slots, never across their hollows (the pixel look's rings are open)
	var cuts: Array[Vector2] = [l]
	if pixel:
		for slot: Array in slots:
			var sil: PackedVector2Array = slot[1]
			var x0 := INF
			var x1 := -INF
			for q in sil:
				x0 = minf(x0, q.x)
				x1 = maxf(x1, q.x)
			cuts.append(Vector2(x0, l.y + (r.y - l.y) * (x0 - l.x) / (r.x - l.x)))
			cuts.append(Vector2(x1, l.y + (r.y - l.y) * (x1 - l.x) / (r.x - l.x)))
	cuts.append(r)
	for c in range(0, cuts.size(), 2):
		lv.draw_line(cuts[c], cuts[c + 1], Color(OUTLINE, 0.75), 10.0, true)
		lv.draw_line(cuts[c], cuts[c + 1], Color(1.0, 0.95, 0.85, 0.75 + 0.25 * env), 3.0, true)
	for lane in 3:
		var g := lv._lane_glow(lane)
		var cue := 1.0 if lv._cued(lane) else 0.0
		var k := clampf(0.6 + 0.15 * env + 0.25 * cue + g, 0.0, 1.0)
		var slot: Array = slots[lane]
		var sil: PackedVector2Array = slot[1]
		var ring: PackedVector2Array = slot[2]
		_glow(lv, slot[0], Vector2(lw * 0.6, lw * 0.28), Color(1.0, 0.85, 0.55, 0.25 * cue + 0.6 * g))
		# the slot's hollow: the road under it shaded (warm in the pixel look, so it sits in the firelight)
		ci_poly(lv, sil, Color(0.1, 0.04, 0.02, 0.55) if pixel else Color(0.04, 0.03, 0.08, 0.6))
		if g > 0.01:
			ci_poly(lv, sil, Color(1.0, 0.97, 0.9, 0.7 * g))
		if pixel and ai_tex("ring_idle", Vector2i.ONE) != null:
			_ring_pic(lv, sil, k, g, incoming[lane], lv.get("_lock_on") == true)
			continue
		lv.draw_polyline(ring, Color(OUTLINE, 0.9), 12.0 if pixel else 9.0, true)
		var rim := Color(CREAM, 0.75 + 0.25 * k)
		if incoming[lane] != null:
			# the slot takes the coming note's colour: which kind, and how close, before it lands
			var kk: Array = incoming[lane][0]
			var near: float = incoming[lane][1]
			ci_poly(lv, sil, _a(kk[1], 0.35 * near * near))
			rim = rim.lerp(kk[0], near)
			lv.draw_polyline(slot[3], _a(kk[0], 0.8 * near), 3.0, true)
		lv.draw_polyline(ring, rim, 5.0 if pixel else 3.5, true)


## The pixel look's hit slot from Daniele's ring pictures, over the slot's outline sil: the grey ring
## takes the coming note's colour as it nears, burns gold when the lane is struck, red while the
## buttons are locked.
static func _ring_pic(lv: LaneView, sil: PackedVector2Array, k: float, g: float, incoming, locked: bool) -> void:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q in sil:
		lo = lo.min(q)
		hi = hi.max(q)
	# the ring's band sits on the outline, half outside it
	var grow := Vector2(1.0, 0.75) * PxArt.PX * 1.5
	lo -= grow
	hi += grow
	var mod := Color(1.0, 1.0, 1.0).lerp(Color(1.15, 1.1, 1.0), k - 0.6)
	if incoming != null:
		var kk: Array = incoming[0]
		var near: float = incoming[1]
		ci_poly(lv, sil, _a(kk[1], 0.35 * near * near))
		mod = mod.lerp(kk[0] * 1.25, near)
	if locked:
		ai_draw(lv, "ring_red", lo, hi)
		return
	ai_draw(lv, "ring_idle", lo, hi, mod)
	if g > 0.05:
		ai_draw(lv, "ring_gold", lo, hi, Color(1.0, 1.0, 1.0, clampf(g * 1.5, 0.0, 1.0)))


# ------------------------------------------------------------------ the bell strike

const STRIKE_TIME := 0.5          ## how long a bell strike shows
const STRIKE_HOLD := 0.16         ## the struck strap stays on the hit line this long
const K_WHITE := [Color("#ffffff"), Color("#fff6dc"), Color("#c8b48c"), Color("#ffffff")]


## A bell rung on time. The strap stays on the hit line for a moment, white-hot, then in its tilt's
## colour lit up, kicked a little the way the phone was tilted; then it breaks into a shock line that
## runs on that way (up the road towards the fire for a tilt up, down over the rings for a tilt down)
## with a glow under it. The two cowbells are thrown off the strap, bigger, swinging, with ring
## arcs thrown out from both sides, and embers fly up all along it. `chain` (on-time bells in a row)
## makes it bigger, up to 1.35x at 6, and from 4 a second shock line follows and the rings burn gold.
## Good is a smaller version without the white instant. Drawn into the World's one-px-per-cell
## view, so the shapes come out as pixels. Returns false once over.
static func bell_strike(lv: LaneView, field: Rect2, up: bool, quality: String, chain: int, age: float) -> bool:
	if age < 0.0 or age >= STRIKE_TIME:
		return false
	var tt := age / STRIKE_TIME
	var perfect := quality == "perfect"
	var big := (1.0 if perfect else 0.8) * (1.0 + 0.07 * float(clampi(chain - 1, 0, 5)))
	var hot := chain >= 4
	var k: Array = K_UP if up else K_DOWN
	var dir := -1.0 if up else 1.0
	var hl := LaneSkin.hit_line_y(field)
	var lane := field.size.x / 3.0
	var lw := lv.road_scale(hl) * lane
	# the struck strap: kicked the tilt's way and back, white for the first instant, then lit
	if age < STRIKE_HOLD:
		var kick := dir * lane * 0.08 * big * sin(age / STRIKE_HOLD * PI)
		var pal: Array = K_WHITE if age < 0.05 and perfect else [k[0], k[3], k[1], Color.WHITE]
		bell(lv, field, hl + kick, up, 1.0, pal, false)
	# the shock line(s) running on the tilt's way, with a glow under them
	var reach := lane * (3.0 if up else 1.1) * big
	for w in (2 if hot else 1):
		var kk := (age - 0.06 - 0.08 * float(w)) / (STRIKE_TIME * 0.7)
		if kk <= 0.0 or kk >= 1.0:
			continue
		var g := 1.0 - pow(1.0 - kk, 2.0)
		var fy := hl + dir * reach * g * (1.0 - 0.25 * float(w))
		var p0 := lv.project(Vector2(-field.size.x * 0.02, fy))
		var p1 := lv.project(Vector2(field.size.x * 1.02, fy))
		var sl := lv.road_scale(fy) * lane
		var col: Color = [Color.WHITE, k[0], k[3], k[1]][mini(int(kk * 4.0), 3)]
		var hot_col: Color = PX_HOT[mini(int(kk * 4.0), 3)]
		_glow(lv, (p0 + p1) * 0.5, Vector2((p1.x - p0.x) * 0.55, sl * 0.25), _a(k[3], 0.5 * (1.0 - kk)))
		var thick := maxf(PxArt.PX, sl * 0.07 * (1.0 - kk) * big)
		lv.draw_line(p0, p1, hot_col if hot else col, thick)
	# the cowbells thrown off the strap, swinging, ringing
	var hy := lv.project(Vector2(0.0, hl)).y
	var bs := lw * 0.42 * big
	var throw := exp(-age * 7.0) * sin(minf(age * 24.0, PI * 0.5)) * bs * 0.9
	var swing := sin(age * 30.0) * exp(-age * 5.0) * 0.55
	var fade := clampf((0.42 - age) / 0.14, 0.0, 1.0)   # gone before the next notes need the line
	for i in (2 if fade > 0.0 else 0):
		var bx := lv.project(Vector2(lane * float(i + 1), hl)).x
		var at := Vector2(bx, hy - bs * 0.35 - throw)
		var c := at + Vector2(0.0, -bs * 0.5)
		# the ring arcs, three in a row, each opening out and cooling
		for r in 3:
			var rk := tt * 1.8 - float(r) * 0.18
			if rk <= 0.0 or rk >= 1.0:
				continue
			var rad := bs * (0.6 + 1.1 * rk) * (1.0 + 0.12 * float(r))
			var rc: Color = ([Color.WHITE, PX_HOT[1], PX_HOT[2], PX_HOT[3]] if hot or perfect else [Color.WHITE, k[0], k[3], k[1]])[mini(int(rk * 4.0), 3)]
			var wid := maxf(PxArt.PX, bs * 0.09 * (1.0 - rk))
			lv.draw_arc(c, rad, -0.5, 0.5, 6, rc, wid)
			lv.draw_arc(c, rad, PI - 0.5, PI + 0.5, 6, rc, wid)
		lv.draw_set_transform(at, swing * (1.0 if i == 0 else -1.0), Vector2.ONE)
		_cowbell(lv, Vector2(0.0, bs * 0.0), bs, fade)
		lv.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# embers all along the strap
	var seed := (7 if up else 13) + chain * 5
	for i in 6:
		var c := lv.project(Vector2(lane * (float(i) + 0.5) * 0.5, hl))
		c.y = hy
		_embers_px(lv, c, lw * 0.8 * big, age, 4 if perfect else 2, seed * 3 + i, PX_HOT if perfect else [k[0], k[3], k[1], k[2]], 1.0)
	return true
