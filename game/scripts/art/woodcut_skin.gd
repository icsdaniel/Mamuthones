class_name WoodcutSkin
extends RefCounted
## The play field in the Woodcut look (the play screen Daniele approved on the review page, round 38):
## three inks on the night road. Notes are flat ovals lying on the road: cream on the beat, red on the
## half beat, black with a cream rim for the quick ones (sixteenths). A held note is a red oval on a
## cream rope; a stomp two cream balls; a bell a bar across the road with its arrows. The hit rings
## are cream ovals with red notches. Everything is drawn with hard edges, sliding smoothly.

const K := Color("#141014")      ## ink
const C := Color("#efe6d2")      ## paper
const R := Color("#c8352a")      ## vermilion
const G := Color("#c9bba0")      ## warm grey
const B := Color("#4a3c38")      ## brown

const NOTE_W := 0.84             ## a step's width, in lane widths
const FLAT := 0.34               ## an oval's height to its width (it lies on the road)
const RIM := 0.075               ## a rim's width, of the oval's width
const ROPE_W := 0.16             ## a hold's rope, in lane widths
const BAR_D := 0.3               ## a bell bar's depth along the road, in lane widths
const RING_W := 0.86             ## a hit ring's width, in lane widths


static func _a(c: Color, a: float) -> Color:
	return Color(c, c.a * a)


static func _lane(field: Rect2) -> float:
	return field.size.x / 3.0


## Screen px of one lane width at flat depth y.
static func lane_px(lv: LaneView, field: Rect2, y: float) -> float:
	return lv.road_scale(y) * _lane(field)


static func ellipse_pts(c: Vector2, r: Vector2, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		pts[i] = c + Vector2(cos(a) * r.x, sin(a) * r.y)
	return pts


static func oval(ci: CanvasItem, c: Vector2, r: Vector2, fill: Color, rim: Color = Color(0, 0, 0, 0), rim_w := 0.0) -> void:
	if r.x < 0.5 or r.y < 0.3:
		return
	if rim.a > 0.0 and rim_w > 0.0:
		ci.draw_colored_polygon(ellipse_pts(c, r + Vector2(rim_w, rim_w * 0.8)), rim)
	ci.draw_colored_polygon(ellipse_pts(c, r), fill)


## The kind of a note as the woodcut tells it: [fill, rim].
static func note_inks(lv: LaneView, n: Note) -> Array:
	if n.heal:
		return [C, K]
	if n.call:
		return [R, K]
	if lv._sixteenth(n):
		return [K, C]
	if lv._off_beat(n) or n.free:
		return [R, C]
	return [C, K]


static func step(lv: LaneView, field: Rect2, n: Note, cx: float, y: float, alpha: float) -> void:
	var lw := lane_px(lv, field, y)
	var c := lv.project(Vector2(cx, y))
	var rx := lw * NOTE_W * 0.5 * (0.8 if lv._sixteenth(n) else 1.0)
	var inks := note_inks(lv, n)
	var rw := maxf(1.0, rx * 2.0 * RIM)
	oval(lv, c, Vector2(rx, rx * FLAT), _a(inks[0], alpha), _a(inks[1], alpha), rw)
	if n.heal:
		# the review's classic pixel heart (round 38), red in whole pixels on the cream face
		pixel_heart(lv, c, rx, alpha)
	elif n.call:
		oval(lv, c, Vector2(rx, rx * FLAT) * 0.3, _a(C, alpha))


## A stomp, as on the review page (round 38): a black oval with a cream rim and a thin cream border
## inside it, and two small cream balls on its face, both thumbs.
static func stomp(lv: LaneView, field: Rect2, cx: float, y: float, alpha: float) -> void:
	var lw := lane_px(lv, field, y)
	var c := lv.project(Vector2(cx, y))
	var rx := lw * NOTE_W * 0.5
	var r := Vector2(rx, rx * FLAT)
	var rw := maxf(1.0, rx * 2.0 * RIM)
	oval(lv, c, r, _a(C, alpha), _a(C, alpha), rw)
	var bw := maxf(1.0, rx * 2.0 * 0.035)
	oval(lv, c, r - Vector2(bw, bw * 0.6), _a(K, alpha))
	var br := rx * 0.17
	for sx: float in [-1.0, 1.0]:
		oval(lv, c + Vector2(sx * rx * 0.3, 0.0), Vector2(br, br * 0.8), _a(C, alpha))


## The classic pixel heart (7 x 6) centred on c, its pixels about a seventh of 0.36 of the oval's width.
const HEART_ROWS := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]


static func pixel_heart(ci: CanvasItem, c: Vector2, rx: float, alpha: float) -> void:
	var n := maxf(1.0, roundf(rx * 2.0 * 0.36 / 7.0))
	var o := (c - Vector2(3.5 * n, 3.0 * n)).round()
	for j in HEART_ROWS.size():
		var row: String = HEART_ROWS[j]
		for i in row.length():
			if row[i] == "#":
				ci.draw_rect(Rect2(o + Vector2(i, j) * n, Vector2(n, n)), _a(R, alpha))


## A held note's rope: one cream band lying on the road from its end (far) to its head (near).
static func rope(lv: LaneView, field: Rect2, cx: float, ya: float, yb: float, lit: bool, alpha: float) -> void:
	var w := _lane(field) * ROPE_W * 0.5
	var steps := 8
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var y := lerpf(ya, yb, float(i) / float(steps))
		left.append(lv.project(Vector2(cx - w, y)))
		right.append(lv.project(Vector2(cx + w, y)))
	right.reverse()
	var poly := left + right
	var out := PackedVector2Array()
	for i in steps + 1:
		var y := lerpf(ya, yb, float(i) / float(steps))
		out.append(lv.project(Vector2(cx - w * 1.5, y)))
	var out_r := PackedVector2Array()
	for i in steps + 1:
		var y := lerpf(ya, yb, float(i) / float(steps))
		out_r.append(lv.project(Vector2(cx + w * 1.5, y)))
	out_r.reverse()
	lv.draw_colored_polygon(out + out_r, _a(K, alpha))
	lv.draw_colored_polygon(poly, _a(R if lit else C, alpha))


static func hold_head(lv: LaneView, field: Rect2, cx: float, y: float, alpha: float, lit: bool) -> void:
	var lw := lane_px(lv, field, y)
	var c := lv.project(Vector2(cx, y))
	var rx := lw * NOTE_W * 0.5
	oval(lv, c, Vector2(rx, rx * FLAT), _a(C if lit else R, alpha), _a(R if lit else C, alpha), maxf(1.0, rx * 2.0 * RIM))


## The rope's far end: a small red cap.
static func knot(lv: LaneView, field: Rect2, cx: float, y: float, alpha: float) -> void:
	var lw := lane_px(lv, field, y)
	var c := lv.project(Vector2(cx, y))
	var rx := lw * NOTE_W * 0.28
	oval(lv, c, Vector2(rx, rx * FLAT), _a(R, alpha), _a(C, alpha), maxf(1.0, rx * 0.15))


## A bell: a bar across the road, red for a tilt up with cream arrows pointing up, cream for a tilt
## down with black arrows pointing down.
static func bell(lv: LaneView, field: Rect2, y: float, up: bool, alpha: float, skip := -1) -> void:
	var d := _lane(field) * BAR_D * 0.5
	var x0 := -field.size.x * 0.005
	var x1 := field.size.x * 1.005
	var lt := lv.project(Vector2(x0, y - d))
	var rt := lv.project(Vector2(x1, y - d))
	var rb := lv.project(Vector2(x1, y + d))
	var lb := lv.project(Vector2(x0, y + d))
	var o := maxf(1.0, (rb.y - rt.y) * 0.12)
	lv.draw_colored_polygon(PackedVector2Array([lt + Vector2(-o, -o), rt + Vector2(o, -o), rb + Vector2(o, o), lb + Vector2(-o, o)]), _a(K, alpha))
	var fill := R if up else C
	var mark := C if up else K
	lv.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), _a(fill, alpha))
	var h := (lb.y - lt.y)
	for lane in 3:
		if lane == skip:
			continue
		var c := lv.project(Vector2(_lane(field) * (lane + 0.5), y))
		var s := h * 0.32
		var dir := -1.0 if up else 1.0
		var pts := PackedVector2Array([c + Vector2(-s * 1.6, -dir * s * 0.5), c + Vector2(0, dir * s * 0.6), c + Vector2(s * 1.6, -dir * s * 0.5)])
		lv.draw_polyline(pts, _a(mark, alpha), maxf(1.0, h * 0.2))


## Two notes on one beat: a cream cord on the road between them, under the notes.
static func cord(lv: LaneView, field: Rect2, x0: float, x1: float, y: float, alpha: float) -> void:
	var a := lv.project(Vector2(x0, y))
	var b := lv.project(Vector2(x1, y))
	var w := maxf(1.0, lane_px(lv, field, y) * 0.05)
	lv.draw_line(a, b, _a(K, alpha), w * 3.0)
	lv.draw_line(a, b, _a(C, alpha), w)


## A stand-still band (kept for older charts): dark across the road.
static func band(lv: LaneView, lt: Vector2, rt: Vector2, rb: Vector2, lb: Vector2, alpha: float) -> void:
	lv.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), _a(B, 0.6 * alpha))


## The three hit rings: cream ovals with red notches, lit while pressed or struck, red while the
## buttons are locked; a ring takes the colour of the note about to land in it.
static func rings(lv: LaneView, field: Rect2, hl: float, incoming: Array) -> void:
	var lw := lane_px(lv, field, hl)
	var rx := lw * RING_W * 0.5
	var ry := rx * FLAT
	var w := maxf(2.0, rx * 0.09)
	var locked: bool = lv.get("_lock_on") == true
	for lane in 3:
		var c := lv.project(Vector2(_lane(field) * (lane + 0.5), hl))
		var g := lv._lane_glow(lane)
		var punch := lv.ring_punch(lane)
		var r := Vector2(rx, ry) * (1.0 + punch)
		var rim := R if locked else C
		# a note close to its ring: the ring's notches take the note's ink (no see-through tints)
		var notch := C if locked else R
		if incoming[lane] != null and float(incoming[lane][1]) > 0.75:
			notch = incoming[lane][0] if incoming[lane][0] != K else C
			if notch == rim:
				notch = K
		if g > 0.25:
			oval(lv, c, r * (0.55 + 0.45 * g), C)
		var outer := ellipse_pts(c, r + Vector2(w, w * 0.8), 40)
		var inner := ellipse_pts(c, r - Vector2(w, w * 0.8), 40)
		var k := ellipse_pts(c, r + Vector2(w * 2.0, w * 1.6), 40)
		k.append(k[0])
		lv.draw_polyline(k, K, w * 1.2)
		outer.append(outer[0])
		inner.append(inner[0])
		var mid := ellipse_pts(c, r, 40)
		mid.append(mid[0])
		lv.draw_polyline(mid, rim, w * 2.0)
		# four red notches round the ring (cream ones on a locked red ring)
		for a: float in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
			var p := c + Vector2(cos(a) * r.x, sin(a) * r.y)
			var q := (p - c).normalized()
			lv.draw_line(p - q * w * 1.2, p + q * w * 1.2, notch, w * 1.6)



## The review page's hit juice (round 38, smooth.juice), at a hit ring centred on c (rx: the ring's
## half width on screen, P: one art px on screen). kind: "perfect"/"good"/"held" (cream), "early"/
## "late"/"ok" (grey), "bell" and "stomp" (red shock ring, bigger chips). Three parts:
##   a carved star, eight short cuts flying out flat from the ring (0.14 s);
##   a shock ring spreading from the ring, dashed as it fades (0.2 s);
##   wood chips, red and cream flecks thrown up and falling (0.35 s).
## Returns false once it is over.
static func hit_juice(ci: CanvasItem, c: Vector2, rx: float, P: float, kind: String, age: float, seed: int) -> bool:
	if age > 0.45 or age < 0.0:
		return age < 0.0
	var ry := rx * 0.36
	var soft := kind in ["early", "late", "ok"]
	var big := kind in ["bell", "stomp", "perfect"]
	var hot := C if not soft else G
	# 0. the ring itself flashes: a solid cream (red for a bell or stomp) plate for a moment
	if age < 0.07 and not soft:
		oval(ci, c, Vector2(rx, ry) * (1.0 + 0.25 * age / 0.07), R if kind in ["bell", "stomp"] else C)
		oval(ci, c, Vector2(rx, ry) * 0.55 * (1.0 + 0.25 * age / 0.07), K if kind in ["bell", "stomp"] else R)
	# 1. the carved star (bigger than the review's: Daniele, 2026-11-07, "add some visual juice")
	if age < 0.18:
		var k := age / 0.18
		var r0 := 1.12 + 0.9 * _ss(k)
		var ln := 0.75 * (1.0 - k) + 0.15
		if big:
			ln *= 1.3
		for i in 8:
			var ang := float(i) * PI / 4.0 + PI / 8.0
			var ca := cos(ang)
			var sa := sin(ang)
			if sa < -0.3 and kind != "bell":
				sa *= 0.4                  # keep the cuts off the incoming notes
			var steps := 10
			for q in steps:
				var u := ln * float(q) / float(steps - 1)
				var p := c + Vector2(ca * rx * (r0 + u), sa * ry * (r0 + u) * 1.8)
				var sz := P * (2.0 if u < ln * 0.5 else 1.0)
				ci.draw_rect(Rect2((p - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), hot if u < ln * 0.6 else R)
	# 2. the shock ring
	if age < 0.26:
		var k := age / 0.26
		var e := 1.15 + 1.0 * _ss(k)
		var col := R if kind in ["bell", "stomp"] else hot
		var sz := P * (2.0 if big and k < 0.5 else 1.0)
		for i in 64:
			if k > 0.5 and i % 2:
				continue
			var a := TAU * float(i) / 64.0
			var p := c + Vector2(cos(a) * rx * e, sin(a) * ry * e)
			ci.draw_rect(Rect2((p - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), col)
	# 3. wood chips
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := 8 if kind != "held" else 4
	if big:
		n += 6
	for i in n:
		var vx := (rng.randf() - 0.5) * rx * 6.5
		var vy := -(0.5 + rng.randf() * 0.9) * ry * 7.0
		var p := c + Vector2(vx * age, vy * age + 0.5 * (ry * 60.0) * age * age)
		var sz := P * (2.0 if age < 0.28 else 1.0) * (1.5 if big and i % 3 == 0 and age < 0.15 else 1.0)
		ci.draw_rect(Rect2((p - Vector2(sz, sz) * 0.5).round(), Vector2(sz, sz)), R if i % 2 else hot)
	return true


static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## A note hit: a burst of square chips flying out, cream and red, gone in a moment.
static func burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc: float) -> bool:
	var life := 0.28
	if age > life:
		return false
	var t := age / life
	var n := 10 if quality == "perfect" else (8 if quality == "good" or quality == "held" or quality == "stomp" else 6)
	var reach := 70.0 * clampf(sc, 0.5, 1.6) * (1.3 if quality == "stomp" else 1.0)
	var sz := maxf(3.0, 9.0 * clampf(sc, 0.5, 1.6) * (1.0 - t))
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n) + (0.3 if i % 2 else 0.0)
		var d := reach * (0.35 + 0.65 * (1.0 - pow(1.0 - t, 2.0))) * (0.8 if i % 2 else 1.0)
		var p := at + Vector2(cos(a) * d, sin(a) * d * 0.55)
		var col := R if i % 2 else C
		if quality == "early" or quality == "late" or quality == "ok":
			col = G if i % 2 else C
		ci.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5 - Vector2(1, 1), Vector2(sz, sz) + Vector2(2, 2)), K)
		ci.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	if t < 0.5:
		var k := 1.0 - t * 2.0
		oval(ci, at, Vector2(reach * 0.45, reach * 0.16) * (1.0 + t), Color(C, 0.0), Color(C, 0.0), 0.0)
		var ring := ellipse_pts(at, Vector2(reach * 0.5, reach * 0.18) * (0.6 + t), 32)
		ring.append(ring[0])
		ci.draw_polyline(ring, Color(C if quality != "early" and quality != "late" else G, k), 4.0 * k + 1.0)
	return true


## A bell rung on time: a red bar printed across the road at the hit line with the bell's cream
## marks (^ rung up, v rung down), then only its cream outline, then gone. Solid inks, no fade.
static func bell_strike(lv: LaneView, field: Rect2, up: bool, quality: String, chain: int, age: float) -> bool:
	var life := 0.24
	if age > life:
		return false
	var t := age / life
	var hl := LaneSkin.hit_line_y(field)
	var d := _lane(field) * 0.09 * (1.0 + 0.5 * t)
	var lt := lv.project(Vector2(-field.size.x * 0.02, hl - d))
	var rt := lv.project(Vector2(field.size.x * 1.02, hl - d))
	var rb := lv.project(Vector2(field.size.x * 1.02, hl + d))
	var lb := lv.project(Vector2(-field.size.x * 0.02, hl + d))
	var h := maxf(lb.y - lt.y, 6.0)
	var w := maxf(2.0, roundf(h * 0.14))
	if t < 0.55:
		lv.draw_colored_polygon(PackedVector2Array([lt, rt, rb, lb]), K)
		var inset := Vector2(0, w)
		lv.draw_colored_polygon(PackedVector2Array([lt + inset, rt + inset, rb - inset, lb - inset]), R if quality != "ok" else G)
	else:
		var box := PackedVector2Array([lt, rt, rb, lb, lt])
		lv.draw_polyline(box, C, w)
	if t < 0.55:
		for lane in 3:
			var c := lv.project(Vector2(_lane(field) * (lane + 0.5), hl))
			var s := h * 0.28
			var dy := -s if up else s
			var pts := PackedVector2Array([c + Vector2(-s * 1.3, -dy * 0.6), c + Vector2(0, dy * 0.6), c + Vector2(s * 1.3, -dy * 0.6)])
			if up:
				pts = PackedVector2Array([c + Vector2(-s * 1.3, s * 0.6), c + Vector2(0, -s * 0.6), c + Vector2(s * 1.3, s * 0.6)])
			lv.draw_polyline(pts, C, w * 1.4)
	return true


## The notes on the road, far to near, with the hit rings under them.
static func draw_notes(lv: LaneView, field: Rect2) -> void:
	field.position = Vector2.ZERO
	var rects := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	var shown := lv._notes_shown(field)
	var items: Array = []
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
					band(lv, lv.project(Vector2(0, y0)), lv.project(Vector2(field.size.x, y0)), lv.project(Vector2(field.size.x, y1)), lv.project(Vector2(0, y1)), lv._haze(y1, field))
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var cx := rects[n.lane].get_center().x
				var head := minf(y, hl) if n.holding else y
				var tail := maxf(float(e[2]), 0.0)
				if head - tail > 1.0:
					rope(lv, field, cx, tail, head, n.holding, lv._haze(head, field))
				if float(e[2]) > 0.0:
					items.append([float(e[2]), "knot", n, cx, lv._haze(e[2], field)])
				items.append([head, "hold", n, cx, lv._haze(head, field)])
			Note.Kind.STEP, Note.Kind.STOMP, Note.Kind.BELL, Note.Kind.RING:
				if not n.done:
					items.append([y, "note", n, rects[maxi(n.lane, 0)].get_center().x, lv._haze(y, field)])
	var incoming: Array = [null, null, null]
	var reach := _lane(field) * 4.0
	for it in items:
		var n: Note = it[2]
		var lane := n.lane
		if lane < 0 or lane > 2 or str(it[1]) == "knot" or n.kind == Note.Kind.BELL:
			continue
		var near := clampf(1.0 - (hl - float(it[0])) / reach, 0.0, 1.0)
		if near > 0.0 and (incoming[lane] == null or near > float(incoming[lane][1])):
			var col: Color = R if str(it[1]) == "hold" else (C if n.kind == Note.Kind.STOMP else note_inks(lv, n)[0])
			incoming[lane] = [col, near]
	rings(lv, field, hl, incoming)
	for c in lv.chords_shown(shown):
		cord(lv, field, rects[c[1]].get_center().x, rects[c[2]].get_center().x, float(c[0]), lv._haze(c[0], field))
	items.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for it in items:
		var y: float = it[0]
		var n: Note = it[2]
		var cx: float = it[3]
		var a: float = it[4]
		match str(it[1]):
			"knot":
				knot(lv, field, cx, y, a)
			"hold":
				hold_head(lv, field, cx, y, a, n.holding)
			_:
				match n.kind:
					Note.Kind.STEP:
						step(lv, field, n, cx, y, a)
					Note.Kind.STOMP:
						stomp(lv, field, cx, y, a * (0.6 if n.thumbs > 0 else 1.0))
					Note.Kind.BELL:
						bell(lv, field, y, n.up, a)
					Note.Kind.RING:
						bell(lv, field, y, n.up, a, n.lane)
						step(lv, field, n, cx, y, a)


# ------------------------------------------------------------------ the step buttons


## A bare footprint, sole to the player, drawn pixel by pixel (Daniele, 2026-11-07: the feet "are
## not well pictured"): five separate toes in an arc, the ball, the narrow arch and the heel. This is
## the right foot (big toe on the inner, left side); mirror gives the left. size: about its height in
## screen px; drawn in whole pixels of P (or size / 20).
const FOOT := [
	".###.........",
	"#####.##.....",
	"#####.##.##..",
	".###......##.",
	"...........##",
	"..#######....",
	".##########..",
	"############.",
	"############.",
	".###########.",
	"..##########.",
	"....########.",
	".....#######.",
	"......######.",
	"......######.",
	"......######.",
	".....#######.",
	".....#######.",
	".....######..",
	"......####...",
]


static func foot(ci: CanvasItem, c: Vector2, size: float, mirror: bool, col: Color, _cut: Color = C, _P := 0.0) -> void:
	var rows := FOOT.size()
	var cols: int = (FOOT[0] as String).length()
	var p := maxf(1.0, floorf(size / float(rows)))
	var o := (c - Vector2(cols, rows) * p * 0.5).round()
	for j in rows:
		var row: String = FOOT[j]
		var i := 0
		while i < cols:
			if row[i] != "#":
				i += 1
				continue
			var e := i
			while e < cols and row[e] == "#":
				e += 1
			var x0 := float(i) if not mirror else float(cols - e)
			ci.draw_rect(Rect2(o + Vector2(x0 * p, float(j) * p), Vector2(float(e - i) * p, p)), col)
			i = e


## The three step buttons: paper plates with a red stitched border and a dithered foot of grey,
## the carved feet in ink (both in the middle one). Pressed: they sink and fill red; a hit flashes
## them; a miss shows them grey; a note about to land lights the border.
static func buttons(lv: LaneView) -> void:
	var r := lv.buttons_rect()
	var span := lv._screen_span()
	lv.draw_rect(Rect2(span.x, r.position.y, span.y - span.x, r.size.y + 400.0), K)
	var w := r.size.x / 3.0
	for lane in 3:
		var st := lv._button_state(lane)
		var down := st == "pressed" or st == "hit"
		var br := Rect2(r.position.x + w * lane + 10.0, r.position.y + 14.0, w - 20.0, r.size.y - 34.0)
		var px := maxf(3.0, roundf(br.size.x / 34.0))
		if down:
			br.position.y += px * 2.0
		else:
			lv.draw_rect(Rect2(br.position + Vector2(0, px * 2.0), br.size), B)
		var fill := C
		var ink := K
		var edge := R
		match st:
			"pressed":
				fill = G
			"hit":
				fill = R
				ink = C
				edge = C
			"miss":
				fill = B
				ink = G
				edge = G
			"cued":
				edge = R
		lv.draw_rect(br.grow(px), K)
		lv.draw_rect(br, fill)
		# the dithered foot of the plate
		var dy := br.position.y + br.size.y * 0.72
		var shade := G if fill == C else K
		var yy := dy
		var row := 0
		while yy < br.end.y - 0.5:
			var xx := br.position.x + (px if row % 2 else 0.0)
			while xx < br.end.x - 0.5:
				lv.draw_rect(Rect2(xx, yy, minf(px, br.end.x - xx), minf(px, br.end.y - yy)), Color(shade, 0.8))
				xx += px * 2.0
			yy += px
			row += 1
		# the stitched border: red dashes inside the edge
		var e := br.grow(-px * 2.0)
		var dash := px * 2.0
		var x := e.position.x
		while x < e.end.x:
			lv.draw_rect(Rect2(x, e.position.y, minf(px, e.end.x - x), px), edge)
			lv.draw_rect(Rect2(x, e.end.y - px, minf(px, e.end.x - x), px), edge)
			x += dash
		var y := e.position.y
		while y < e.end.y:
			lv.draw_rect(Rect2(e.position.x, y, px, minf(px, e.end.y - y)), edge)
			lv.draw_rect(Rect2(e.end.x - px, y, px, minf(px, e.end.y - y)), edge)
			y += dash
		# the review's feet: 0.55 of the plate's height, both in the middle one
		var c := br.get_center() - Vector2(0, br.size.y * 0.04)
		var fs := minf(br.size.y * 0.62, br.size.x * 1.1)
		if lane == 1:
			foot(lv, c + Vector2(-fs * 0.34, 0), fs * 0.9, true, ink, fill, px)
			foot(lv, c + Vector2(fs * 0.34, 0), fs * 0.9, false, ink, fill, px)
		else:
			foot(lv, c, fs, lane == 0, ink, fill, px)
