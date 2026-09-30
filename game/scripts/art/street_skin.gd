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
##   call      red gem (the Issohadore's call); off-beat steps too, a little narrower
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
const K_CALL := [Color("#ff9aa8"), Color("#ff2e52"), Color("#c0142f"), Color("#ff3a5a")]
const K_HEAL := [Color("#a8ffc8"), Color("#2ee07a"), Color("#12a052"), Color("#40ff90")]
const K_HOLD := [Color("#fff0a0"), Color("#ffcc1a"), Color("#d08a00"), Color("#ffd040")]
const K_STOMP := [Color("#eab0ff"), Color("#b240ff"), Color("#7418c8"), Color("#c060ff")]
const K_UP := [Color("#fff0a0"), Color("#ffcc1a"), Color("#d08a00"), Color("#ffd040")]
const K_DOWN := [Color("#9fe0ff"), Color("#2ea6ff"), Color("#1a64d0"), Color("#48b4ff")]
const GEM_W := 0.9                   ## a gem's width, as a share of its lane's width
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


## A gem across [x0, x1] (flat field x) at flat depth y. k: the kind's colours. depth: its depth on
## screen as a share of the lane's width. rims: 2 draws a second rim inside the first. Returns its
## frame (for marks drawn on it).
static func gem(lv: LaneView, field: Rect2, x0: float, x1: float, y: float, k: Array, alpha := 1.0, depth := GEM_D, glow := 1.0, rims := 1) -> Callable:
	var lw := lv.road_scale(y) * field.size.x / 3.0
	var hw := (x1 - x0) * 0.5
	var f := _frame(lv, x0 + hw, y, hw, lw * depth)
	if alpha <= 0.01 or lw < 2.0:
		return f
	var light: Color = k[0]
	var body: Color = k[1]
	var dark: Color = k[2]
	var sil := _pts(f, SHAPE)
	var c: Vector2 = f.call(Vector2.ZERO)
	var w_px := sil[3].x - sil[0].x
	var d_px := sil[4].y - sil[1].y
	# its shadow on the road, and the light it casts round it
	_glow(lv, c + Vector2(0.0, d_px * 0.55), Vector2(w_px * 0.6, d_px * 1.1), Color(0.0, 0.0, 0.03, 0.55 * alpha))
	_glow(lv, c, Vector2(w_px * 0.7, d_px * 1.8), _a(k[3], 0.35 * alpha * glow))
	# its thickness: the near edges dropped a little, dark
	var thick := Vector2(0.0, maxf(2.0, d_px * 0.3))
	var ow := maxf(2.0, lw * 0.022)
	var hull := PackedVector2Array([sil[0], sil[1], sil[2], sil[3], sil[3] + thick, sil[4] + thick, sil[5] + thick, sil[0] + thick])
	var ring := hull.duplicate()
	ring.append(hull[0])
	lv.draw_polyline(ring, _a(OUTLINE, alpha), ow * 2.0, true)
	ci_poly(lv, hull, _a(OUTLINE, alpha))
	for e in [[0, 5, 0.55], [5, 4, 0.4], [4, 3, 0.62]]:
		var p0: Vector2 = sil[e[0]]
		var p1: Vector2 = sil[e[1]]
		var sh: float = e[2]
		ci_poly(lv, PackedVector2Array([p0, p1, p1 + thick * 0.8, p0 + thick * 0.8]), _a(dark.darkened(sh), alpha))
	# a thin bright rim, then the body flat-shaded in four facets round the middle
	ci_poly(lv, sil, _a(light.lerp(RIM, 0.7), alpha))
	var rim := maxf(1.5, lw * 0.03)
	var inset := Vector2(1.0 - rim / maxf(w_px * 0.5, 1.0) * 1.3, 1.0 - rim / maxf(d_px * 0.5, 1.0))
	if rims > 1:
		ci_poly(lv, _pts(f, SHAPE, inset), _a(dark, alpha))
		inset -= Vector2(rim * 1.2 / maxf(w_px * 0.5, 1.0), rim * 1.0 / maxf(d_px * 0.5, 1.0))
		ci_poly(lv, _pts(f, SHAPE, inset), _a(light.lerp(RIM, 0.7), alpha))
		inset -= Vector2(rim * 1.3 / maxf(w_px * 0.5, 1.0), rim / maxf(d_px * 0.5, 1.0))
	# a crystal ingot: the far slope catches the fire's light, the near slope is the body colour,
	# the pointed ends are in shade
	var b := _pts(f, SHAPE, inset)
	var l: Vector2 = b[0]
	var r: Vector2 = b[3]
	ci_poly(lv, PackedVector2Array([b[1], b[2], r, l]), _a(light, alpha))
	ci_poly(lv, PackedVector2Array([l, r, b[4], b[5]]), _a(body, alpha))
	ci_poly(lv, PackedVector2Array([l, b[1], f.call(Vector2(-1.0 + TIP * 2.2, 0.0) * inset), b[5]]), _a(light.lerp(body, 0.5), alpha))
	ci_poly(lv, PackedVector2Array([b[2], r, b[4], f.call(Vector2(1.0 - TIP * 2.2, 0.0) * inset)]), _a(dark, alpha))
	# the fire's light along the far edge, and a glint on the far slope
	lv.draw_line(b[1], b[2], _a(Color("#ffd9a0"), 0.9 * alpha), maxf(1.0, rim * 0.8), true)
	ci_poly(lv, PackedVector2Array([b[1].lerp(b[2], 0.08), b[1].lerp(b[2], 0.3), l.lerp(r, 0.28), l.lerp(r, 0.12)]), _a(RIM, 0.55 * alpha))
	# the moment: a white-hot line across the middle
	lv.draw_line(sil[0], sil[3], _a(RIM, alpha), maxf(1.5, lw * 0.022), true)
	return f


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


## A hold's ribbon down its lane from flat depth ya (far) to yb (near), `share` of the lane wide: a
## long crystal beam, faceted like the gems (a lit left slope, the body, a shaded right slope).
static func ribbon(lv: LaneView, field: Rect2, cx: float, ya: float, yb: float, share: float, lit: bool, alpha := 1.0) -> void:
	var hw := field.size.x / 3.0 * share * 0.5
	var k: Array = K_HOLD
	var strip := func(u0: float, u1: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var n := 10
		for i in n + 1:
			pts.append(lv.project(Vector2(cx + u0 * hw, lerpf(ya, yb, float(i) / n))))
		for i in range(n, -1, -1):
			pts.append(lv.project(Vector2(cx + u1 * hw, lerpf(ya, yb, float(i) / n))))
		return pts
	var body := 0.9 if lit else 0.55
	var out: PackedVector2Array = strip.call(-1.0, 1.0)
	var ring := out.duplicate()
	ring.append(out[0])
	lv.draw_polyline(ring, _a(OUTLINE, 0.9 * alpha), 5.0, true)
	ci_poly(lv, out, _a(k[2], body * alpha))
	ci_poly(lv, strip.call(-0.86, 0.2), _a(k[1], body * alpha))
	ci_poly(lv, strip.call(-0.86, -0.3), _a(k[0], body * alpha))
	if lit:
		ci_poly(lv, strip.call(-0.5, -0.2), _a(RIM, 0.8 * alpha))


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
		var c := lv.project(Vector2(rects[i].get_center().x, y))
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


## Two bare feet on a stomp gem, like the button's own: both thumbs, on this button.
static func _prints(lv: LaneView, f: Callable, lw: float, alpha: float) -> void:
	var sz := lw * 0.13
	if sz < 2.0 or alpha <= 0.01:
		return
	for foot: float in [-1.0, 1.0]:
		var c: Vector2 = f.call(Vector2(foot * 0.2, 0.1))
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
					sp = span(rects[n.lane], GEM_W * (1.0 if n.call else 0.8))
					gem(lv, field, sp.x, sp.y, y, K_CALL, a)
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
				_prints(lv, gem(lv, field, sp.x, sp.y, y, K_STOMP, ta, GEM_D * 1.5, 1.2, 2), lw, ta)


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
