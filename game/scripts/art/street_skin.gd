class_name StreetSkin
extends RefCounted
## The notes, hit line and bursts over the street picture, drawn as faceted low-poly shapes to sit
## with Daniele's art: each note a cut gem seen a little from above, its facets lit unevenly, on a
## dark outline so it stands out from the painted road. Everything is placed with LaneView.project()
## and sized by the lane's width there, so it follows the picture's perspective.
##
##   step   a gold gem with a red diamond set in it
##   call   a red gem with a gold diamond (the Issohadore's call; smaller when off the beat)
##   heal   a bone-white gem with a flame-coloured diamond
##   hold   a gold gem with the rope's loop on it, the rope lying down the lane, a knot at its end
##   stomp  a wide, thick fire-red gem with two bone thumb prints
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


## The rope of a hold lying down its lane from a (far) to b (near), wa and wb px wide there.
static func sash(ci: CanvasItem, a: Vector2, b: Vector2, wa: float, wb: float, lit: bool, alpha := 1.0) -> void:
	var col := Color("#ffd070") if lit else ROPE
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-wa * 0.5 - 2, 0), a + Vector2(wa * 0.5 + 2, 0), b + Vector2(wb * 0.5 + 2, 0), b + Vector2(-wb * 0.5 - 2, 0)]), _a(OUTLINE, 0.8 * alpha))
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-wa * 0.5, 0), a + Vector2(wa * 0.5, 0), b + Vector2(wb * 0.5, 0), b + Vector2(-wb * 0.5, 0)]), _a(col, (0.95 if lit else 0.8) * alpha))
	ci.draw_colored_polygon(PackedVector2Array([a + Vector2(-wa * 0.12, 0), a + Vector2(wa * 0.12, 0), b + Vector2(wb * 0.12, 0), b + Vector2(-wb * 0.12, 0)]), _a(col.lightened(0.35), alpha))


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
					var wa := lv.road_scale(tail) * field.size.x / 3.0 * 0.26
					var wb := lv.road_scale(head) * field.size.x / 3.0 * 0.26
					sash(lv, lv.project(Vector2(cx, tail)), lv.project(Vector2(cx, head)), wa, wb, n.holding, lv._haze(tail, field))
	_hit_line(lv, field, rects, hl)
	var now_b := lv._now_beat() if lv.spb > 0.0 else 0.0
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		var a := lv._haze(y, field)
		var lw := lv.road_scale(y) * field.size.x / 3.0
		var w := lw * NOTE_W
		var lift := 0.0
		if lv.hopping() and not n.done and not UIKit.reduced_motion():
			lift = LaneView.hop_arc(now_b, LaneView.hop_grid((n.t - lv.beat_zero) / lv.spb)) * w * 0.28
		match n.kind:
			Note.Kind.STEP:
				if n.done:
					continue
				var at := lv.project(Vector2(rects[n.lane].get_center().x, y))
				_shadow(lv, at, w, lift, a)
				at.y -= lift
				if n.heal:
					gem(lv, at, w, BONE, INLAY_FLAME, a)
				elif n.call or lv._off_beat(n):
					gem(lv, at, w * (1.0 if n.call else 0.84), RED, INLAY_GOLD, a)
				else:
					gem(lv, at, w, GOLD, INLAY_RED, a)
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var cx := rects[n.lane].get_center().x
				var tail: float = e[2]
				if tail > 0.0:
					knot(lv, lv.project(Vector2(cx, tail)), lv.road_scale(tail) * field.size.x / 3.0 * NOTE_W, lv._haze(tail, field))
				var head := minf(y, hl) if n.holding else y
				var at := lv.project(Vector2(cx, head))
				var hw := lv.road_scale(head) * field.size.x / 3.0 * NOTE_W
				if not n.holding:
					_shadow(lv, at, hw, lift, a)
					at.y -= lift
				hold_head(lv, at, hw, a)
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
					gem(lv, lv.project(Vector2(rects[n.lane].get_center().x, y)) - Vector2(0, w * 0.12), w, GOLD, INLAY_RED, a)
			Note.Kind.STOMP:
				if n.done:
					continue
				var at := lv.project(Vector2(rects[n.lane].get_center().x, y))
				_shadow(lv, at, w * 1.3, lift, a)
				at.y -= lift
				stomp(lv, at, w, a * (0.6 if n.thumbs > 0 else 1.0))


static func _shadow(ci: CanvasItem, at: Vector2, w: float, lift: float, alpha: float) -> void:
	if lift <= 0.5:
		return
	var k := clampf(lift / (w * 0.28), 0.0, 1.0)
	_ellipse(ci, at + Vector2(0, w * 0.1), Vector2(w * 0.45 * (1.0 - 0.2 * k), w * 0.14), Color(0, 0, 0, (0.5 - 0.2 * k) * alpha))


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
		var rr := Vector2(lw * NOTE_W * 0.5, lw * NOTE_W * 0.5 * 0.34)
		_ring(lv, c, rr, 8.0, Color(OUTLINE, 0.7))
		_ring(lv, c, rr, 4.0, Color(1.0, 0.85, 0.5, k))
