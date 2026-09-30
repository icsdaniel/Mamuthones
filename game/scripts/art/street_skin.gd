class_name StreetSkin
extends RefCounted
## The notes, hit line and bursts over the street picture.
##
## Every note is a cut gem lying flat on the road across its lane: a long hexagon with pointed ends,
## flat-shaded in four facets like the low-poly picture under it, a white rim and a thin dark outline
## so it stands out on lit and dark cobbles alike. The road and the fire are warm, so the notes are
## cool or saturated colours the street does not have. A white-hot line runs across the middle of
## each gem: that line is the note's moment, and it meets the hit line exactly when to tap.
## Shapes are drawn in the road's plane (LaneView.project()), so they follow the picture's
## perspective.
##
##   step      blue gem
##   call      a narrower blue gem with a white diamond near each end (the Issohadore's call);
##             off-beat steps too, so every tap is blue and only its shape says it falls off the beat
##   heal      green gem with a white cross
##   hold      gold gem, a gold ribbon down the lane, a small gold gem at its end
##   stomp     violet gem the full lane wide, deeper, with a double rim and two thumb prints
##   bell      a bar across the whole road, big chevrons the way to tilt (gold up, blue down)
##   rest      a dim blue band across the lanes

const OUTLINE := Color("#0b0714")
const RIM := Color("#ffffff")
const STILL_BLUE := Color("#5f8fe8")
## [light facet, body, dark facet, glow] per kind
const K_STEP := [Color("#9fe0ff"), Color("#2ea6ff"), Color("#1a64d0"), Color("#48b4ff")]
const K_HEAL := [Color("#a8ffc8"), Color("#2ee07a"), Color("#12a052"), Color("#40ff90")]
const K_HOLD := [Color("#fff0a0"), Color("#ffcc1a"), Color("#d08a00"), Color("#ffd040")]
const K_STOMP := [Color("#eab0ff"), Color("#b240ff"), Color("#7418c8"), Color("#c060ff")]
const K_UP := [Color("#fff0a0"), Color("#ffcc1a"), Color("#d08a00"), Color("#ffd040")]
const K_DOWN := [Color("#9fe0ff"), Color("#2ea6ff"), Color("#1a64d0"), Color("#48b4ff")]
const OFF_W := 0.74                  ## an off-beat step or call is this much narrower than a step
const GEM_W := 0.9                   ## a gem's width, as a share of its lane's width
const GEM_H := 0.17                  ## how tall a gem stands, in lane widths
const GIRDLE := 0.5                  ## the share of its height that is straight sides (the rest is the crown)
const TABLE := Vector2(0.8, 0.45)    ## the table on top, as a share of the base outline
const FORE := 0.42                   ## how much the road's depth is foreshortened on screen (for the lighting)
const GEM_D := 0.22                  ## a gem's depth on screen, as a share of its lane's width
const TIP := 0.12                    ## how far in the pointed ends start, share of the half width
## The gem's outline in its own frame: u across (-1..1), v along the road (-1 far .. 1 near).
const SHAPE := [Vector2(-1.0, 0.0), Vector2(-1.0 + TIP, -1.0), Vector2(1.0 - TIP, -1.0), Vector2(1.0, 0.0), Vector2(1.0 - TIP, 1.0), Vector2(-1.0 + TIP, 1.0)]


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func ci_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if col.a > 0.004 and pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


## A note's frame on the road: centre flat x, flat depth y, half width hw (flat px), and the flat
## half depth that shows `px_d` screen px deep. Returns a Callable mapping (u, v) to the screen.
static func _frame(lv: LaneView, cx: float, y: float, hw: float, px_d: float) -> Callable:
	var dsdy := maxf(0.05, (lv.project(Vector2(cx, y + 1.0)).y - lv.project(Vector2(cx, y - 1.0)).y) * 0.5)
	var hd := px_d * 0.5 / dsdy
	return func(p: Vector2) -> Vector2: return lv.project(Vector2(cx + p.x * hw, y + p.y * hd))


static func _pts(f: Callable, local: Array, s := Vector2.ONE) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in local:
		out.append(f.call(p * s))
	return out


## A gem across [x0, x1] (flat field x) at flat depth y: a real solid, cut like a baguette stone, with
## straight sides up from the road, a bevelled crown and a flat table on top. Each face is lit on its
## own (low-poly flat shading): the fire ahead rims the far and upper faces warm, the night sky lights
## the table, the faces toward the player are in the gem's own colour, and the table flashes white
## on the beat. k: the kind's colours. depth: its depth on screen as a share of the lane's width;
## height: how tall it stands, in lane widths. Returns a Callable mapping (u, v) on its table top to
## the screen, for marks drawn on it.
static func gem(lv: LaneView, field: Rect2, x0: float, x1: float, y: float, k: Array, alpha := 1.0, depth := GEM_D, glow := 1.0, height := GEM_H) -> Callable:
	var lw := lv.road_scale(y) * field.size.x / 3.0
	var hw := (x1 - x0) * 0.5
	var f := _frame3(lv, field, x0 + hw, y, hw, lw * depth)
	var top := func(p: Vector2) -> Vector2: return f.call(Vector3(p.x * TABLE.x, height, p.y * TABLE.y))
	if alpha <= 0.01 or lw < 2.0:
		return top
	# the model: base, girdle and table outlines; metric scale in lane widths for the lighting
	var verts: Array[Vector3] = []
	for sh in [Vector3(1.0, 0.0, 1.0), Vector3(1.0, GIRDLE, 1.0), Vector3(TABLE.x, 1.0, TABLE.y)]:
		for q: Vector2 in SHAPE:
			verts.append(Vector3(q.x * sh.x, height * sh.y, q.y * sh.z))
	var faces: Array = []
	for i in 6:
		var j := (i + 1) % 6
		faces.append([i, j, 6 + j, 6 + i])
		faces.append([6 + i, 6 + j, 12 + j, 12 + i])
	faces.append([12, 13, 14, 15, 16, 17])
	var metric := Vector3(hw / (field.size.x / 3.0), 1.0, depth * 0.5 / FORE)
	var c: Vector2 = f.call(Vector3.ZERO)
	var w_px := (f.call(Vector3(1, 0, 0)) as Vector2).x - (f.call(Vector3(-1, 0, 0)) as Vector2).x
	# its shadow on the road, and the light it casts round it
	_glow(lv, c + Vector2(0.0, lw * depth * 0.4), Vector2(w_px * 0.62, lw * depth * 1.2), Color(0.0, 0.0, 0.03, 0.6 * alpha))
	_glow(lv, c, Vector2(w_px * 0.75, lw * depth * 2.0), _a(k[3], 0.35 * alpha * glow))
	var flash := lv.beat_env()
	solid(lv, f, verts, faces, metric, k, alpha, maxf(2.0, lw * 0.022), flash)
	# crisp cut edges round the table, and a glint across it that flares on the beat
	var tp := PackedVector2Array()
	for i in 6:
		tp.append(f.call(verts[12 + i]))
	tp.append(tp[0])
	lv.draw_polyline(tp, _a((k[0] as Color).lerp(RIM, 0.6), 0.9 * alpha), maxf(1.0, lw * 0.012), true)
	var g0: Vector2 = top.call(Vector2(-0.55, -1.0))
	var g1: Vector2 = top.call(Vector2(-0.3, -1.0))
	var g2: Vector2 = top.call(Vector2(-0.45, 1.0))
	var g3: Vector2 = top.call(Vector2(-0.7, 1.0))
	ci_poly(lv, PackedVector2Array([g0, g1, g2, g3]), _a(RIM, (0.35 + 0.5 * flash) * alpha))
	return top


## A note's frame on the road: centre flat x, flat depth y, half width hw (flat px), and the flat
## half depth that shows `px_d` screen px deep. Returns a Callable mapping (u, h, v) to the screen:
## u across (-1..1), v along the road (-1 far .. 1 near), h up from the road in lane widths.
static func _frame3(lv: LaneView, field: Rect2, cx: float, y: float, hw: float, px_d: float) -> Callable:
	var dsdy := maxf(0.05, (lv.project(Vector2(cx, y + 1.0)).y - lv.project(Vector2(cx, y - 1.0)).y) * 0.5)
	var hd := px_d * 0.5 / dsdy
	var lane := field.size.x / 3.0
	return func(p: Vector3) -> Vector2:
		var fy := y + p.z * hd
		return lv.project(Vector2(cx + p.x * hw, fy)) - Vector2(0.0, p.y * lv.road_scale(fy) * lane)


## Draws a convex solid: verts in (u, h, v) through frame f, faces as vertex index loops, metric the
## model's scale in lane widths (for the normals). Faces turned away are skipped; the rest are
## flat-shaded from k [light, body, dark, glow], inside a dark outline of width ow.
static func solid(lv: LaneView, f: Callable, verts: Array[Vector3], faces: Array, metric: Vector3, k: Array, alpha: float, ow: float, flash := 0.0) -> void:
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
	var col: Color = (k[2] as Color).lerp(k[1], clampf(b, 0.0, 1.0)) if b <= 1.0 else (k[1] as Color).lerp(k[0], clampf((b - 1.0) * 4.0, 0.0, 1.0))
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


## The lane's span [x0, x1] in flat field x for a gem `share` of the lane wide.
static func span(rect: Rect2, share: float) -> Vector2:
	var m := rect.size.x * (1.0 - share) * 0.5
	return Vector2(rect.position.x + m, rect.end.x - m)


## A hold's beam down its lane from flat depth ya (far) to yb (near), `share` of the lane wide: a long
## low bar of the hold's gold, lit like the gems, glowing while it is held.
static func ribbon(lv: LaneView, field: Rect2, cx: float, ya: float, yb: float, share: float, lit: bool, alpha := 1.0) -> void:
	var lane := field.size.x / 3.0
	var hw := lane * share * 0.5
	var f := func(p: Vector3) -> Vector2:
		var fy := lerpf(ya, yb, (p.z + 1.0) * 0.5)
		return lv.project(Vector2(cx + p.x * hw, fy)) - Vector2(0.0, p.y * lv.road_scale(fy) * lane)
	var h := GEM_H * 0.45
	var verts: Array[Vector3] = [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1),
		Vector3(-1, h, -1), Vector3(1, h, -1), Vector3(1, h, 1), Vector3(-1, h, 1)]
	var faces := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [4, 5, 6, 7]]
	var metric := Vector3(share * 0.5, 1.0, maxf(yb - ya, 1.0) / lane * 0.5)
	if lit:
		_glow(lv, (f.call(Vector3(0, 0, 1)) as Vector2), Vector2(hw * 2.0, hw), _a(K_HOLD[3], 0.5 * alpha))
	solid(lv, f, verts, faces, metric, K_HOLD, (1.0 if lit else 0.8) * alpha, 2.5, -0.4)
	# a hot core line along the top
	var c0: Vector2 = f.call(Vector3(-0.35, h, -1))
	var c1: Vector2 = f.call(Vector3(-0.35, h, 1))
	lv.draw_line(c0, c1, _a(RIM, (0.9 if lit else 0.5) * alpha), maxf(2.0, hw * 0.12), true)


## A bell bar across the whole road at flat depth y: a long gem with a big arrow in each lane,
## pointing the way to tilt the phone.
static func bell(lv: LaneView, field: Rect2, rects: Array[Rect2], y: float, up: bool, alpha := 1.0) -> void:
	var k: Array = K_UP if up else K_DOWN
	gem(lv, field, -field.size.x * 0.02, field.size.x * 1.02, y, k, alpha, GEM_D * 1.25, 0.8)
	var lw := lv.road_scale(y) * field.size.x / 3.0
	if lw < 4.0 or alpha <= 0.01:
		return
	var d := -1.0 if up else 1.0
	var h := lw * GEM_D * 1.25 * 0.36
	var a := h * 1.25
	for i in 3:
		var c := lv.project(Vector2(rects[i].get_center().x, y)) - Vector2(0.0, GEM_H * lw)
		var tri := PackedVector2Array([c + Vector2(-a, -d * h), c + Vector2(0.0, d * h), c + Vector2(a, -d * h)])
		var ring := tri.duplicate()
		ring.append(tri[0])
		lv.draw_polyline(ring, _a(OUTLINE, alpha), maxf(3.0, lw * 0.035), true)
		ci_poly(lv, tri, _a(RIM, alpha))


## A stand-still band across the road between screen rows y_top and y_bottom.
static func band(ci: CanvasItem, lt: Vector2, rt: Vector2, rb: Vector2, lb: Vector2, alpha := 1.0) -> void:
	ci.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), Color(0.1, 0.16, 0.45, 0.42 * alpha))
	for e in [[lt, rt, 3.0], [lb, rb, 4.5]]:
		ci.draw_line(e[0], e[1], Color(OUTLINE, 0.8 * alpha), e[2] + 5.0, true)
		ci.draw_line(e[0], e[1], Color(STILL_BLUE.lightened(0.3), alpha), e[2], true)


## A white cross on a healing gem.
static func _cross(lv: LaneView, f: Callable, lw: float, alpha: float) -> void:
	var c: Vector2 = f.call(Vector2.ZERO)
	var t := maxf(3.0, lw * 0.05)
	var w := lw * 0.14
	var h := lw * GEM_D * 0.3
	for r in [Rect2(c.x - w - 2.0, c.y - t * 0.5 - 2.0, 2.0 * w + 4.0, t + 4.0), Rect2(c.x - t * 0.5 - 2.0, c.y - h - 2.0, t + 4.0, 2.0 * h + 4.0)]:
		lv.draw_rect(r, _a(OUTLINE, alpha))
	lv.draw_rect(Rect2(c.x - w, c.y - t * 0.5, 2.0 * w, t), _a(RIM, alpha))
	lv.draw_rect(Rect2(c.x - t * 0.5, c.y - h, t, 2.0 * h), _a(RIM, alpha))


## A call's or off-beat step's mark: a white diamond near each end.
static func _notches(lv: LaneView, f: Callable, lw: float, alpha: float) -> void:
	var r := lw * 0.05
	if r < 1.5 or alpha <= 0.01:
		return
	for sx: float in [-0.7, 0.7]:
		var c: Vector2 = f.call(Vector2(sx, 0.0))
		var d := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.2, 0), c + Vector2(0, r), c + Vector2(-r * 1.2, 0)])
		var ring := d.duplicate()
		ring.append(d[0])
		lv.draw_polyline(ring, _a(OUTLINE, alpha), 3.0, true)
		ci_poly(lv, d, _a(RIM, alpha))


## Two bare feet on a stomp gem, like the button's own: both thumbs, on this button.
static func _prints(lv: LaneView, f: Callable, lw: float, alpha: float) -> void:
	var sz := lw * 0.16
	if sz < 2.0 or alpha <= 0.01:
		return
	for foot: float in [-1.0, 1.0]:
		var c: Vector2 = f.call(Vector2(foot * 0.22, 0.1))
		_foot(lv, c, sz + 2.5, foot, _a(OUTLINE, alpha))
		_foot(lv, c, sz, foot, _a(RIM, alpha))


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


## A hit burst: the gem's outline flying out of the slot, a flash of light rising from the lane
## and sparks thrown up and out. False once it is over.
static func burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc: float) -> bool:
	var tt := age / LaneSkin.BURST_TIME
	if tt >= 1.0 or tt < 0.0:
		return false
	var col: Color = {
		"perfect": Color("#fffbe8"), "good": Color("#ffd35a"), "ok": Color("#ff9a3a"), "early": Color("#ff9a3a"),
		"late": Color("#ff9a3a"), "heal": Color("#8affb8"), "held": Color("#ffe27a"), "stomp": Color("#e2a0ff"),
	}.get(quality, Color("#ffd35a"))
	var lw := sc * 240.0
	if ci is LaneView:
		lw = sc * (ci as LaneView).field_rect().size.x / 3.0
	var e := 1.0 - pow(1.0 - tt, 3.0)
	var a := pow(1.0 - tt, 1.4)
	# light rising from the lane
	var pw := lw * 0.46 * (1.0 - 0.3 * tt)
	var ph := lw * (0.9 + 0.6 * e)
	ci.draw_polygon(PackedVector2Array([at + Vector2(-pw, 0), at + Vector2(pw, 0), at + Vector2(pw * 0.7, -ph), at + Vector2(-pw * 0.7, -ph)]),
		PackedColorArray([Color(col, 0.6 * a), Color(col, 0.6 * a), Color(col, 0.0), Color(col, 0.0)]))
	_glow(ci, at, Vector2(lw * (0.6 + 0.3 * e), lw * (0.3 + 0.15 * e)), Color(col, 0.8 * a))
	# the gem's outline flying out
	var hw := lw * GEM_W * 0.5 * (1.0 + 0.45 * e)
	var hd := lw * GEM_D * 0.5 * (1.0 + 1.6 * e)
	var ring := PackedVector2Array()
	for p: Vector2 in SHAPE:
		ring.append(at + Vector2(p.x * hw, p.y * hd))
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(col, a), maxf(2.0, lw * 0.035 * (1.0 - tt)), true)
	for i in 8:
		var ang := -PI * (0.1 + 0.8 * float(i) / 7.0)
		var dir := Vector2(cos(ang), sin(ang) * 1.1)
		var p0 := at + dir * lw * (0.2 + 0.35 * e)
		var p1 := at + dir * lw * (0.3 + 0.55 * e)
		ci.draw_line(p0, p1, Color(col, a), maxf(2.0, lw * 0.03 * (1.0 - tt)), true)
	return true


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


static func _ring(ci: CanvasItem, c: Vector2, r: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 19:
		var a := TAU * float(i) / 18.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_polyline(pts, col, w, true)


# ------------------------------------------------------------------ the whole field

## The stand-still bands, the hold ribbons, the hit line and its slots, then the notes far to near.
static func draw_notes(lv: LaneView, field: Rect2) -> void:
	field.position = Vector2.ZERO
	var rects := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	var shown := lv._notes_shown(field)
	# lying on the road first: bands and ribbons
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
					band(lv, lv.project(Vector2(0, y0)), lv.project(Vector2(field.size.x, y0)), lv.project(Vector2(field.size.x, y1)), lv.project(Vector2(0, y1)), lv._haze(y0, field))
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var head := minf(y, hl) if n.holding else y
				var tail := maxf(float(e[2]), 0.0)
				if head - tail > 1.0:
					ribbon(lv, field, rects[n.lane].get_center().x, tail, head, 0.4, n.holding, lv._haze(tail, field))
	_hit_line(lv, field, rects, hl)
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		var a := lv._haze(y, field)
		var lw := lv.road_scale(y) * field.size.x / 3.0
		match n.kind:
			Note.Kind.STEP:
				if n.done:
					continue
				var sp := span(rects[n.lane], GEM_W)
				if n.heal:
					_cross(lv, gem(lv, field, sp.x, sp.y, y, K_HEAL, a), lw, a)
				elif n.call or lv._off_beat(n):
					sp = span(rects[n.lane], GEM_W * OFF_W)
					_notches(lv, gem(lv, field, sp.x, sp.y, y, K_STEP, a), lw, a)
				else:
					gem(lv, field, sp.x, sp.y, y, K_STEP, a)
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var tail: float = e[2]
				var head := minf(y, hl) if n.holding else y
				if tail > 0.0:
					var ts := span(rects[n.lane], GEM_W * 0.6)
					gem(lv, field, ts.x, ts.y, tail, K_HOLD, lv._haze(tail, field), GEM_D * 0.7)
				var sp := span(rects[n.lane], GEM_W)
				gem(lv, field, sp.x, sp.y, head, K_HOLD, a, GEM_D, 1.0 if not n.holding else 1.5 + lv.beat_env())
			Note.Kind.BELL, Note.Kind.RING:
				if n.done:
					continue
				bell(lv, field, rects, y, n.up, a)
				if n.kind == Note.Kind.RING:
					var rs := span(rects[n.lane], GEM_W * 0.8)
					gem(lv, field, rs.x, rs.y, y, K_STEP, a)
			Note.Kind.STOMP:
				if n.done:
					continue
				var sp := span(rects[n.lane], 1.0)
				var ta := a * (0.6 if n.thumbs > 0 else 1.0)
				_prints(lv, gem(lv, field, sp.x, sp.y, y, K_STOMP, ta, GEM_D * 1.4, 1.2, GEM_H * 1.6), lw, ta)


## The hit line across the road, and in each lane a slot: a gem's outline in white with dark glass
## inside, brighter when a note is about to reach it, filling with light while its button is down,
## breathing with the beat.
static func _hit_line(lv: LaneView, field: Rect2, rects: Array[Rect2], hl: float) -> void:
	var l := lv.project(Vector2(-field.size.x * 0.02, hl))
	var r := lv.project(Vector2(field.size.x * 1.02, hl))
	var env := lv.beat_env()
	var lw := lv.road_scale(hl) * field.size.x / 3.0
	lv.draw_line(l, r, Color(OUTLINE, 0.75), 10.0, true)
	lv.draw_line(l, r, Color(1.0, 0.95, 0.85, 0.75 + 0.25 * env), 3.0, true)
	for lane in 3:
		var g := lv._lane_glow(lane)
		var cue := 1.0 if lv._cued(lane) else 0.0
		var k := clampf(0.6 + 0.15 * env + 0.25 * cue + g, 0.0, 1.0)
		var sp := span(rects[lane], GEM_W)
		var f := _frame(lv, (sp.x + sp.y) * 0.5, hl, (sp.y - sp.x) * 0.5, lw * GEM_D)
		var sil := _pts(f, SHAPE)
		_glow(lv, f.call(Vector2.ZERO), Vector2(lw * 0.6, lw * 0.28), Color(1.0, 0.85, 0.55, 0.25 * cue + 0.6 * g))
		ci_poly(lv, sil, Color(0.04, 0.03, 0.08, 0.6))
		if g > 0.01:
			ci_poly(lv, sil, Color(1.0, 0.97, 0.9, 0.7 * g))
		var ring := sil.duplicate()
		ring.append(sil[0])
		lv.draw_polyline(ring, Color(OUTLINE, 0.9), 9.0, true)
		lv.draw_polyline(ring, Color(1.0, 0.96, 0.88, 0.75 + 0.25 * k), 3.5, true)
		lv.draw_line(sil[0], sil[3], Color(1.0, 1.0, 1.0, 0.35 + 0.3 * env), 2.0, true)
