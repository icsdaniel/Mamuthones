class_name StreetSkin
extends RefCounted
## The notes, hit line and bursts over the street picture. After the clearest rhythm games (Project
## Sekai, Arcaea, Guitar Hero): every note is a wide glowing slab lying flat on the road across its
## lane, white-hot in the middle and coloured at the rim by its kind, with a dark outline and a soft
## halo so it is the brightest thing on the street. At the hit line each lane has an empty slab of
## the same shape, so a note visibly drops into its slot. A hit throws a pillar of light up from the
## lane. Everything is placed with LaneView.project() and sized by the lane's width there, so it
## follows the picture's perspective.
##
##   step   gold rim, white core
##   call   red rim (the Issohadore's call); off-beat steps are red too and a little narrower
##   heal   cyan rim with a white cross
##   hold   a gold slab head, a glowing gold ribbon down the lane, a small slab at its end
##   stomp  a thick fire-red slab the full lane wide, two white chevrons pressing down
##   bell   a bar across the road, chevrons pointing the way to tilt (gold up, steel down), a medallion
##   rest   a dim blue band across the lanes

const OUTLINE := Color("#0a0608")
const GOLD := [Color("#b87414"), Color("#ffd35a"), Color("#fff1bf")]      ## side, face, inner
const RED := [Color("#8c1410"), Color("#ff4a36"), Color("#ffa088")]
const BONE := [Color("#a8987c"), Color("#f4ecd8"), Color("#ffffff")]
const STOMP := [Color("#7a120c"), Color("#ff5a24"), Color("#ffb070")]
const INLAY_RED := Color("#d8261c")
const INLAY_GOLD := Color("#ffc233")
const INLAY_FLAME := Color("#ff7a1a")
const ROPE := Color("#d99a38")
const STEEL := [Color("#3a5480"), Color("#a9c4ee"), Color("#e4efff")]
const STILL_BLUE := Color("#5f8fe8")
const FACETS := [1.0, 0.9, 0.8, 0.88, 1.04, 1.12]
const NOTE_W := 0.66                 ## a gem's width, as a share of its lane's width
const SLAB_W := 0.86                 ## a slab's width, as a share of its lane's width
const SLAB_H := 0.25                 ## a slab's depth on screen, as a share of its lane's width
## [rim, core] of each slab kind
const K_STEP := [Color("#ffb21e"), Color("#fffbe8")]
const K_CALL := [Color("#ff3a2a"), Color("#ffe4dc")]
const K_HEAL := [Color("#3fe0ff"), Color("#f0feff")]
const K_STOMP := [Color("#ff4a12"), Color("#ffd0a0")]
const K_HOLD := [Color("#ffc21e"), Color("#fffbe8")]


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## A faceted gem centred at `at`, `w` px wide. cols: [side, face, inner]; inlay: the diamond's colour.
static func gem(ci: CanvasItem, at: Vector2, w: float, cols: Array, inlay: Color, alpha := 1.0, thick := 0.13) -> void:
	if w < 2.0 or alpha <= 0.01:
		return
	var h := w * 0.3
	var t := w * thick
	var top := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0
		top.append(at + Vector2(cos(a) * w * 0.5, sin(a) * h))
	var down := Vector2(0.0, t)
	# the outline: the gem's whole silhouette, a little bigger
	var o := maxf(2.0, w * 0.035)
	var sil := PackedVector2Array([top[3] + Vector2(-o, 0), top[4] + Vector2(0, -o), top[5] + Vector2(0, -o), top[0] + Vector2(o, 0),
		top[0] + down + Vector2(o, 0), top[1] + down + Vector2(0, o), top[2] + down + Vector2(0, o), top[3] + down + Vector2(-o, 0)])
	ci.draw_colored_polygon(sil, _a(OUTLINE, alpha))
	# the sides: the three lower edges dropped by the gem's thickness
	for i in [0, 1, 2]:
		var p0: Vector2 = top[i]
		var p1: Vector2 = top[(i + 1) % 6]
		var k: float = [0.8, 1.0, 0.7][i]
		ci.draw_colored_polygon(PackedVector2Array([p0, p1, p1 + down, p0 + down]), _a(cols[0] * Color(k, k, k), alpha))
	# the face: six facets from the middle, each lit a little differently
	for i in 6:
		var k: float = FACETS[i]
		ci.draw_colored_polygon(PackedVector2Array([at, top[i], top[(i + 1) % 6]]), _a((cols[1] as Color) * Color(k, k, k), alpha))
	# the inner table, and the diamond set in it
	var inner := PackedVector2Array()
	for p in top:
		inner.append(at + (p - at) * 0.58)
	ci.draw_colored_polygon(inner, _a(cols[2], alpha))
	var d := w * 0.17
	var dh := h * 0.55
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -dh), at + Vector2(d, 0), at]), _a(inlay.lightened(0.25), alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(d, 0), at + Vector2(0, dh), at]), _a(inlay.darkened(0.15), alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, dh), at + Vector2(-d, 0), at]), _a(inlay.darkened(0.3), alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-d, 0), at + Vector2(0, -dh), at]), _a(inlay, alpha))


## A glowing slab lying flat on the road across lane span [x0, x1] (flat field x) at flat depth y:
## its top face follows the road's perspective, a thin front edge gives it thickness. k: [rim, core].
## Returns the top face's corners (far left, far right, near right, near left) on screen.
static func slab(lv: LaneView, field: Rect2, x0: float, x1: float, y: float, k: Array, alpha := 1.0, depth := SLAB_H, fill := 1.0) -> PackedVector2Array:
	var cx := (x0 + x1) * 0.5
	var lw := lv.road_scale(y) * field.size.x / 3.0
	var h := lw * depth
	var dsdy := maxf(0.05, (lv.project(Vector2(cx, y + 1.0)).y - lv.project(Vector2(cx, y - 1.0)).y) * 0.5)
	var dy := h * 0.5 / dsdy
	var a := lv.project(Vector2(x0, y - dy))
	var b := lv.project(Vector2(x1, y - dy))
	var c := lv.project(Vector2(x1, y + dy))
	var d := lv.project(Vector2(x0, y + dy))
	var top := PackedVector2Array([a, b, c, d])
	if alpha <= 0.01 or lw < 2.0:
		return top
	var rim: Color = k[0]
	var core: Color = k[1]
	var e := Vector2(0.0, maxf(2.0, h * 0.35))
	var o := maxf(2.0, lw * 0.025)
	# a soft halo in the rim's colour, then the outline round the whole shape, the front edge, the top
	var ctr := (a + b + c + d) * 0.25
	for g in 3:
		var grow := lw * (0.05 + 0.06 * g)
		var halo := PackedVector2Array()
		for p in [a, b, c + e, d + e]:
			halo.append(p + (p - ctr).normalized() * grow)
		ci_poly(lv, halo, _a(rim, 0.16 * alpha * fill))
	ci_poly(lv, PackedVector2Array([a + Vector2(-o, -o), b + Vector2(o, -o), c + e + Vector2(o, o), d + e + Vector2(-o, o)]), _a(OUTLINE, 0.9 * alpha))
	ci_poly(lv, PackedVector2Array([d, c, c + e, d + e]), _a(rim.darkened(0.35), alpha))
	ci_poly(lv, top, _a(rim, alpha))
	# lighter toward the middle, white-hot at the core
	ci_poly(lv, PackedVector2Array([_bil(top, 0.04, 0.14), _bil(top, 0.96, 0.14), _bil(top, 0.96, 0.86), _bil(top, 0.04, 0.86)]), _a(rim.lerp(core, 0.45), alpha))
	ci_poly(lv, PackedVector2Array([_bil(top, 0.1, 0.3), _bil(top, 0.9, 0.3), _bil(top, 0.9, 0.7), _bil(top, 0.1, 0.7)]), _a(core, alpha * fill))
	# a glint along the far edge and a lit lip on the front
	lv.draw_line(_bil(top, 0.05, 0.08), _bil(top, 0.95, 0.08), _a(Color.WHITE, 0.8 * alpha * fill), maxf(1.5, lw * 0.02))
	lv.draw_line(d, c, _a(rim.lightened(0.3), alpha), maxf(1.0, lw * 0.012))
	return top


## A point inside a quad [far left, far right, near right, near left]: u across, v toward the player.
static func _bil(q: PackedVector2Array, u: float, v: float) -> Vector2:
	return q[0].lerp(q[1], u).lerp(q[3].lerp(q[2], u), v)


static func ci_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if col.a > 0.004:
		ci.draw_colored_polygon(pts, col)


## The lane's span [x0, x1] in flat field x for a slab `share` of the lane wide.
static func span(rect: Rect2, share: float) -> Vector2:
	var m := rect.size.x * (1.0 - share) * 0.5
	return Vector2(rect.position.x + m, rect.end.x - m)


static func stomp(ci: CanvasItem, at: Vector2, w: float, alpha := 1.0) -> void:
	var ww := w * 1.3
	gem(ci, at, ww, STOMP, STOMP[1], alpha, 0.2)
	for sx: float in [-1.0, 1.0]:
		var c := at + Vector2(sx * ww * 0.13, 0.0)
		_ellipse(ci, c, Vector2(ww * 0.07, ww * 0.1), _a(OUTLINE, alpha))
		_ellipse(ci, c, Vector2(ww * 0.055, ww * 0.085), _a(BONE[1], alpha))


static func hold_head(ci: CanvasItem, at: Vector2, w: float, alpha := 1.0) -> void:
	gem(ci, at, w, GOLD, GOLD[2], alpha)
	var r := Vector2(w * 0.2, w * 0.09)
	_ring(ci, at, r, maxf(2.0, w * 0.05), _a(Color("#7a3e10"), alpha))


static func knot(ci: CanvasItem, at: Vector2, w: float, alpha := 1.0) -> void:
	_ellipse(ci, at, Vector2(w * 0.2, w * 0.1) + Vector2(2, 2), _a(OUTLINE, alpha))
	_ellipse(ci, at, Vector2(w * 0.2, w * 0.1), _a(ROPE, alpha))
	_ellipse(ci, at + Vector2(0, -w * 0.02), Vector2(w * 0.1, w * 0.045), _a(ROPE.lightened(0.3), alpha))


## A hold's ribbon of light down its lane from a (far) to b (near), wa and wb px wide there: a
## translucent gold body with bright edges and a hot centre line, brighter while it is held.
static func sash(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, lit: bool, alpha := 1.0) -> void:
	var col := K_HOLD[0] as Color
	var body := 0.5 if lit else 0.32
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-wa * 0.5, 0), a + Vector2(wa * 0.5, 0), b + Vector2(wb * 0.5, 0), b + Vector2(-wb * 0.5, 0)]), _a(col, body * alpha))
	for sx: float in [-1.0, 1.0]:
		ci.draw_line(a + Vector2(sx * wa * 0.5, 0), b + Vector2(sx * wb * 0.5, 0), _a(OUTLINE, 0.6 * alpha), maxf(3.0, wb * 0.08))
		ci.draw_line(a + Vector2(sx * wa * 0.5, 0), b + Vector2(sx * wb * 0.5, 0), _a(col.lightened(0.3), alpha), maxf(2.0, wb * 0.04))
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-wa * 0.08, 0), a + Vector2(wa * 0.08, 0), b + Vector2(wb * 0.08, 0), b + Vector2(-wb * 0.08, 0)]), _a(K_HOLD[1], (0.95 if lit else 0.7) * alpha))


## The bell bar across the road from x0 to x1 at y, `lw` the lane's width there.
static func bar(ci: CanvasItem, x0: float, x1: float, y: float, lw: float, up: bool, alpha := 1.0) -> void:
	var cols: Array = GOLD if up else STEEL
	var h := maxf(4.0, lw * 0.13)
	var r := Rect2(x0, y - h * 0.5, x1 - x0, h)
	ci.draw_rect(r.grow(maxf(2.0, h * 0.18)), _a(OUTLINE, alpha))
	ci.draw_rect(r, _a(cols[1], alpha))
	ci.draw_rect(Rect2(r.position.x, r.end.y - h * 0.3, r.size.x, h * 0.3), _a(cols[0], alpha))
	var d := -1.0 if up else 1.0
	var step := maxf(h * 2.2, 12.0)
	var cx := (x0 + x1) * 0.5
	var x := cx + step * 1.8
	while x < x1 - step * 0.5:
		for sx: float in [-1.0, 1.0]:
			var c := Vector2(cx + (x - cx) * sx, y)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.45, -d * h * 0.3), c + Vector2(0, d * h * 0.35), c + Vector2(h * 0.45, -d * h * 0.3)]), _a(cols[2] if up else Color.WHITE, alpha))
		x += step


## The bar's medallion: red for raising the bells, navy for lowering them, a bone arrow the way to tilt.
static func badge(ci: CanvasItem, at: Vector2, w: float, up: bool, alpha := 1.0) -> void:
	var r := w * 0.3
	var rim: Array = GOLD if up else STEEL
	var face := Color("#d0261c") if up else Color("#23407a")
	ci.draw_circle(at, r + maxf(2.0, r * 0.12), _a(OUTLINE, alpha))
	ci.draw_circle(at, r, _a(rim[1], alpha))
	ci.draw_circle(at, r * 0.8, _a(face, alpha))
	var d := -1.0 if up else 1.0
	var a := r * 0.5
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, d * a), at + Vector2(-a * 0.8, 0), at + Vector2(a * 0.8, 0)]), _a(BONE[1], alpha))
	ci.draw_rect(Rect2(at.x - a * 0.28, minf(at.y, at.y - d * a * 0.7), a * 0.56, a * 0.7), _a(BONE[1], alpha))


## A stand-still band across the road between screen rows y_top and y_bottom.
static func band(ci: CanvasItem, lt: Vector2, rt: Vector2, rb: Vector2, lb: Vector2, alpha := 1.0) -> void:
	ci.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), Color(0.22, 0.36, 0.8, 0.22 * alpha))
	ci.draw_line(lt, rt, Color(STILL_BLUE, 0.9 * alpha), 3.0)
	ci.draw_line(lb, rb, Color(STILL_BLUE, 0.9 * alpha), 4.0)


## A hit burst: a ring spreading over the road and sparks thrown up and out. False once it is over.
static func burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc: float) -> bool:
	var tt := age / LaneSkin.BURST_TIME
	if tt >= 1.0 or tt < 0.0:
		return false
	var col: Color = {
		"perfect": Color("#fff4c0"), "good": Color("#ffc445"), "ok": Color("#ff8a2a"), "early": Color("#ff8a2a"),
		"late": Color("#ff8a2a"), "heal": Color("#fff8ea"), "held": Color("#9cc0ff"), "stomp": Color("#ff6a2a"),
	}.get(quality, Color("#ffc445"))
	var e := 1.0 - pow(1.0 - tt, 3.0)
	# a pillar of light rising from the lane, thinning as it fades
	var pw := 70.0 * sc * (1.0 - 0.5 * tt)
	var ph := (160.0 + 120.0 * e) * sc
	ci.draw_polygon(PackedVector2Array([at + Vector2(-pw, 0), at + Vector2(pw, 0), at + Vector2(pw * 0.6, -ph), at + Vector2(-pw * 0.6, -ph)]),
		PackedColorArray([Color(col, 0.55 * (1.0 - tt)), Color(col, 0.55 * (1.0 - tt)), Color(col, 0.0), Color(col, 0.0)]))
	var r := (60.0 + 110.0 * e) * sc
	var a := pow(1.0 - tt, 1.5)
	_ring(ci, at, Vector2(r, r * 0.42), maxf(2.0, 7.0 * sc * (1.0 - tt)), Color(col, 0.9 * a))
	for i in 10:
		var ang := -PI * (0.08 + 0.84 * float(i) / 9.0)
		var dir := Vector2(cos(ang), sin(ang) * 0.9)
		var p0 := at + dir * (30.0 + 80.0 * e) * sc
		var p1 := at + dir * (46.0 + 130.0 * e) * sc
		ci.draw_line(p0, p1, Color(col, a), maxf(2.0, 5.0 * sc * (1.0 - tt)))
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

## The stand-still bands, the hit line and its receptors, then the notes from far to near.
static func draw_notes(lv: LaneView, field: Rect2) -> void:
	field.position = Vector2.ZERO
	var rects := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	var shown := lv._notes_shown(field)
	# lying on the road first: bands, ropes, bars
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
				var cx := rects[n.lane].get_center().x
				var head := minf(y, hl) if n.holding else y
				var tail := maxf(float(e[2]), 0.0)
				if head - tail > 1.0:
					var wa := lv.road_scale(tail) * field.size.x / 3.0 * 0.6
					var wb := lv.road_scale(head) * field.size.x / 3.0 * 0.6
					sash(lv, lv.project(Vector2(cx, tail)), lv.project(Vector2(cx, head)), wa, wb, n.holding, lv._haze(tail, field))
	_hit_line(lv, field, rects, hl)
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		var a := lv._haze(y, field)
		var lw := lv.road_scale(y) * field.size.x / 3.0
		var w := lw * NOTE_W
		match n.kind:
			Note.Kind.STEP:
				if n.done:
					continue
				var sp := span(rects[n.lane], SLAB_W)
				if n.heal:
					var top := slab(lv, field, sp.x, sp.y, y, K_HEAL, a)
					_cross(lv, top, a)
				elif n.call or lv._off_beat(n):
					sp = span(rects[n.lane], SLAB_W * (1.0 if n.call else 0.8))
					slab(lv, field, sp.x, sp.y, y, K_CALL, a)
				else:
					slab(lv, field, sp.x, sp.y, y, K_STEP, a)
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var tail: float = e[2]
				var head := minf(y, hl) if n.holding else y
				if tail > 0.0:
					var ts := span(rects[n.lane], SLAB_W * 0.62)
					slab(lv, field, ts.x, ts.y, tail, K_HOLD, lv._haze(tail, field), SLAB_H * 0.6)
				var sp := span(rects[n.lane], SLAB_W)
				slab(lv, field, sp.x, sp.y, head, K_HOLD, a, SLAB_H, 1.0 if not n.holding else 0.6 + 0.4 * lv.beat_env())
			Note.Kind.BELL, Note.Kind.RING:
				if n.done:
					continue
				var p := lv.project(Vector2(field.get_center().x, y))
				var l := lv.project(Vector2(0.0, y))
				var r := lv.project(Vector2(field.size.x, y))
				bar(lv, l.x, r.x, p.y, lw, n.up, a)
				if n.kind == Note.Kind.BELL or n.lane != 1:
					badge(lv, p, w, n.up, a)
				if n.kind == Note.Kind.RING:
					var rs := span(rects[n.lane], SLAB_W * 0.8)
					slab(lv, field, rs.x, rs.y, y, K_STEP, a)
			Note.Kind.STOMP:
				if n.done:
					continue
				var sp := span(rects[n.lane], 0.98)
				var top := slab(lv, field, sp.x, sp.y, y, K_STOMP, a * (0.6 if n.thumbs > 0 else 1.0), SLAB_H * 1.5)
				_chevrons(lv, top, a * (0.6 if n.thumbs > 0 else 1.0))


## A white cross on a healing slab.
static func _cross(ci: CanvasItem, top: PackedVector2Array, alpha: float) -> void:
	var c := (top[0] + top[1] + top[2] + top[3]) * 0.25
	var w := (top[1].x - top[0].x + top[2].x - top[3].x) * 0.5
	var h := (top[3].y - top[0].y)
	var t := maxf(2.0, w * 0.05)
	ci.draw_rect(Rect2(c.x - w * 0.14, c.y - t * 0.5, w * 0.28, t), _a(Color("#0b8fb0"), alpha))
	ci.draw_rect(Rect2(c.x - t * 0.5, c.y - h * 0.34, t, h * 0.68), _a(Color("#0b8fb0"), alpha))


## Two chevrons pressing down on a stomp slab: both thumbs, hard.
static func _chevrons(ci: CanvasItem, top: PackedVector2Array, alpha: float) -> void:
	var c := (top[0] + top[1] + top[2] + top[3]) * 0.25
	var w := (top[1].x - top[0].x + top[2].x - top[3].x) * 0.5
	var h := (top[3].y - top[0].y)
	for sx: float in [-1.0, 1.0]:
		var m := c + Vector2(sx * w * 0.17, 0.0)
		var a := w * 0.1
		var pts := PackedVector2Array([m + Vector2(-a, -h * 0.3), m + Vector2(0, h * 0.12), m + Vector2(a, -h * 0.3)])
		ci.draw_polyline(pts, _a(OUTLINE, alpha), maxf(4.0, w * 0.06), true)
		ci.draw_polyline(pts, _a(Color.WHITE, alpha), maxf(2.0, w * 0.035), true)


## The hit line across the road, and a receptor ring in each lane: lit while its button is down,
## brighter when a note is about to reach it, breathing with the beat.
static func _hit_line(lv: LaneView, field: Rect2, rects: Array[Rect2], hl: float) -> void:
	var l := lv.project(Vector2(-field.size.x * 0.02, hl))
	var r := lv.project(Vector2(field.size.x * 1.02, hl))
	var env := lv.beat_env()
	var w := maxf(3.0, 5.0 * lv.road_scale(hl))
	lv.draw_line(l, r, Color(OUTLINE, 0.8), w + 5.0)
	lv.draw_line(l, r, Color(1.0, 0.8, 0.45, 0.75 + 0.25 * env), w)
	for lane in 3:
		var c := lv.project(Vector2(rects[lane].get_center().x, hl))
		var lw := lv.road_scale(hl) * field.size.x / 3.0
		var g := lv._lane_glow(lane)
		var cue := 0.4 if lv._cued(lane) else 0.0
		var k := clampf(0.35 + 0.25 * env + cue + 0.8 * g, 0.0, 1.0)
		# the lane's slot: an empty slab of a note's own shape, filling while its button is down
		var sp := span(rects[lane], SLAB_W)
		var dsdy := maxf(0.05, (lv.project(Vector2(c.x, hl + 1.0)).y - lv.project(Vector2(c.x, hl - 1.0)).y) * 0.5)
		var dy := lw * SLAB_H * 0.5 / dsdy
		var q := PackedVector2Array([lv.project(Vector2(sp.x, hl - dy)), lv.project(Vector2(sp.y, hl - dy)), lv.project(Vector2(sp.y, hl + dy)), lv.project(Vector2(sp.x, hl + dy))])
		ci_poly(lv, q, Color(0.02, 0.01, 0.02, 0.55))
		if g > 0.01:
			ci_poly(lv, q, Color(1.0, 0.75, 0.3, 0.55 * g))
		var ring := q.duplicate()
		ring.append(q[0])
		lv.draw_polyline(ring, Color(OUTLINE, 0.8), 8.0, true)
		lv.draw_polyline(ring, Color(1.0, 0.86, 0.55, k), 3.5, true)
