class_name WoodcutDraw
extends RefCounted
## Low-level woodcut drawing onto any CanvasItem, used by the mask, figures, backdrops and lanes.
##
## Shapes are triangulated here (never by draw_polygon) so a bad shape falls back quietly instead of
## logging errors, and strokes are built as triangle strips with a width that swells and tapers like
## a gouge cut. Texture overlays (grain, hatch, chisel) repeat in world space.

const TAU_F := TAU

# Batching: between begin(ci) and end(), consecutive shapes that share a texture are merged into one
# triangle-array command, so a backdrop of thousands of cuts costs a handful of draw commands.
# Anything drawn with a CanvasItem draw_* call inside a batch must call flush() first (glow() does).
static var _b_ci: CanvasItem = null
static var _b_depth := 0
static var _b_tex := RID()
static var _b_verts := PackedVector2Array()
static var _b_cols := PackedColorArray()
static var _b_uvs := PackedVector2Array()
static var _b_idx := PackedInt32Array()


static func begin(ci: CanvasItem) -> void:
	if _b_depth == 0:
		_b_ci = ci
		RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	elif ci != _b_ci:
		flush()
		_b_ci = ci
	_b_depth += 1


static func end() -> void:
	_b_depth = maxi(0, _b_depth - 1)
	if _b_depth == 0:
		flush()
		_b_ci = null


static func flush() -> void:
	if _b_ci != null and not _b_idx.is_empty() and is_instance_valid(_b_ci):
		RenderingServer.canvas_item_add_triangle_array(_b_ci.get_canvas_item(), _b_idx, _b_verts, _b_cols,
			_b_uvs if _b_tex.is_valid() else PackedVector2Array(), PackedInt32Array(), PackedFloat32Array(), _b_tex)
	_b_verts.clear()
	_b_cols.clear()
	_b_uvs.clear()
	_b_idx.clear()


static func _emit(ci: CanvasItem, idx: PackedInt32Array, verts: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, tex: RID) -> void:
	if _b_depth > 0 and ci == _b_ci:
		if tex != _b_tex:
			flush()
			_b_tex = tex
		var base := _b_verts.size()
		_b_verts.append_array(verts)
		_b_cols.append_array(cols)
		if tex.is_valid():
			_b_uvs.append_array(uvs)
		var n := idx.size()
		var start := _b_idx.size()
		_b_idx.resize(start + n)
		for i in n:
			_b_idx[start + i] = idx[i] + base
		return
	if tex.is_valid():
		RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex)


## Deterministic hash in [0, 1).
static func hash01(i: int, salt := 0) -> float:
	var x := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return x - floorf(x)


## Smooth 1-D value noise in [0, 1).
static func noise1(x: float, salt := 0) -> float:
	var i := floori(x)
	var f := x - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(hash01(i, salt), hash01(i + 1, salt), f)


static func ellipse(c: Vector2, r: Vector2, n := 24, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := TAU_F * float(i) / float(n)
		out[i] = c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
	return out


## Closed Catmull-Rom smoothing of a control polygon.
static func smooth_closed(ctrl: PackedVector2Array, per_seg := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in per_seg:
			out.append(_cr(p0, p1, p2, p3, float(s) / float(per_seg)))
	return out


## Open Catmull-Rom curve through the points (end points kept).
static func smooth_open(ctrl: PackedVector2Array, per_seg := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	if n < 3:
		return ctrl
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for s in per_seg:
			out.append(_cr(p0, p1, p2, p3, float(s) / float(per_seg)))
	out.append(ctrl[n - 1])
	return out


static func _cr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


static func quad(a: Vector2, ctrl: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	return out


## Roughens a closed outline: every edge is subdivided and pushed in or out a little, like an
## inked edge on a woodblock.
static func rough(pts: PackedVector2Array, amp: float, salt := 0, step := 6.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var k := 0
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := a.distance_to(b)
		var segs := maxi(1, int(d / step))
		var nrm := (b - a).orthogonal().normalized()
		for s in segs:
			var t := float(s) / float(segs)
			out.append(a.lerp(b, t) + nrm * (hash01(k, salt) - 0.5) * 2.0 * amp)
			k += 1
	return out


static func transform(pts: PackedVector2Array, xf: Transform2D) -> PackedVector2Array:
	return xf * pts


## Fills a polygon. With `tex`, the texture repeats in world space (uv = point * uv_scale).
static func fill(ci: CanvasItem, pts: PackedVector2Array, color: Color, tex: Texture2D = null, uv_scale := 1.0 / 256.0, uv_offset := Vector2.ZERO) -> void:
	if pts.size() < 3 or color.a <= 0.0:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		pts = Geometry2D.convex_hull(pts)
		if pts.size() > 1:
			pts.remove_at(pts.size() - 1)
		idx = Geometry2D.triangulate_polygon(pts)
		if idx.is_empty():
			return
	fill_tris(ci, pts, idx, color, tex, uv_scale, uv_offset)


## Draws pre-triangulated geometry (cache `idx` for shapes drawn every frame).
static func fill_tris(ci: CanvasItem, pts: PackedVector2Array, idx: PackedInt32Array, color: Color, tex: Texture2D = null, uv_scale := 1.0 / 256.0, uv_offset := Vector2.ZERO) -> void:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(color)
	var uvs := PackedVector2Array()
	var rid := RID()
	if tex != null:
		uvs = Transform2D(0.0, Vector2(uv_scale, uv_scale), 0.0, uv_offset) * pts
		rid = tex.get_rid()
	_emit(ci, idx, pts, cols, uvs, rid)


## Fills a star-shaped polygon (convex or nearly) as a fan from its centroid: no triangulation, so it is
## cheap enough for shapes rebuilt every frame (notes, bursts). With `tex`, uv = uv_xf * point.
static func fill_fan(ci: CanvasItem, pts: PackedVector2Array, color: Color, tex: Texture2D = null, uv_xf := Transform2D(0.0, Vector2(1.0 / 256.0, 1.0 / 256.0), 0.0, Vector2.ZERO)) -> void:
	var n := pts.size()
	if n < 3 or color.a <= 0.0:
		return
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(n)
	var verts := PackedVector2Array()
	verts.resize(n + 1)
	verts[0] = c
	for i in n:
		verts[i + 1] = pts[i]
	var idx := PackedInt32Array()
	idx.resize(n * 3)
	for i in n:
		idx[i * 3] = 0
		idx[i * 3 + 1] = i + 1
		idx[i * 3 + 2] = (i + 1) % n + 1
	var cols := PackedColorArray()
	cols.resize(n + 1)
	cols.fill(color)
	var uvs := PackedVector2Array()
	var rid := RID()
	if tex != null:
		uvs = uv_xf * verts
		rid = tex.get_rid()
	_emit(ci, idx, verts, cols, uvs, rid)


## A rounded rectangle outline with a hand-cut wobble that is stable for a given salt.
static func rough_rect(r: Rect2, radius: float, amp: float, salt := 0, per_corner := 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.position + Vector2(r.size.x - radius, r.size.y - radius),
		r.position + Vector2(radius, r.size.y - radius), r.position + Vector2(radius, radius)]
	var k := 0
	for ci in 4:
		var c: Vector2 = corners[ci]
		for j in per_corner + 1:
			var a := -PI * 0.5 + (float(ci) + float(j) / float(per_corner)) * PI * 0.5
			var p := c + Vector2(cos(a), sin(a)) * radius
			p += Vector2(cos(a), sin(a)) * (hash01(k, salt) - 0.5) * 2.0 * amp
			out.append(p)
			k += 1
		# A midpoint on each long side, so straight edges wobble too.
		var nxt: Vector2 = corners[(ci + 1) % 4]
		var a2 := float(ci) * PI * 0.5
		var mid := (c + nxt) * 0.5 + Vector2(cos(a2), sin(a2)) * (radius + (hash01(k, salt) - 0.5) * 2.0 * amp)
		out.append(mid)
		k += 1
	return out


## Fills with a flat colour and then lays a texture over it (for example wood grain in bone at low alpha).
static func fill_tex(ci: CanvasItem, pts: PackedVector2Array, color: Color, tex: Texture2D, overlay: Color, uv_scale := 1.0 / 256.0, uv_offset := Vector2.ZERO) -> void:
	fill(ci, pts, color)
	if tex != null and overlay.a > 0.0:
		fill(ci, pts, overlay, tex, uv_scale, uv_offset)


## A gouge stroke along `pts`: width goes w0 -> w_mid -> w1 (w_mid < 0 means a straight taper).
static func stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, w0: float, w1: float, w_mid := -1.0) -> void:
	var n := pts.size()
	if n < 2 or color.a <= 0.0:
		return
	var verts := PackedVector2Array()
	verts.resize(n * 2)
	# Arc length for the width profile.
	var lens := PackedFloat32Array()
	lens.resize(n)
	var total := 0.0
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
		lens[i] = total
	if total <= 0.0:
		return
	for i in n:
		var t := lens[i] / total
		var w: float
		if w_mid < 0.0:
			w = lerpf(w0, w1, t)
		elif t < 0.5:
			w = lerpf(w0, w_mid, sin(t * PI))
		else:
			w = lerpf(w1, w_mid, sin(t * PI))
		var tg: Vector2
		if i == 0:
			tg = pts[1] - pts[0]
		elif i == n - 1:
			tg = pts[n - 1] - pts[n - 2]
		else:
			tg = pts[i + 1] - pts[i - 1]
		var nrm := tg.orthogonal().normalized() * (w * 0.5)
		verts[i * 2] = pts[i] + nrm
		verts[i * 2 + 1] = pts[i] - nrm
	var idx := PackedInt32Array()
	idx.resize((n - 1) * 6)
	for i in n - 1:
		var a := i * 2
		idx[i * 6] = a
		idx[i * 6 + 1] = a + 1
		idx[i * 6 + 2] = a + 2
		idx[i * 6 + 3] = a + 1
		idx[i * 6 + 4] = a + 3
		idx[i * 6 + 5] = a + 2
	fill_tris(ci, verts, idx, color)


## A closed rough outline of constant-ish width (ink edge).
static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, salt := 0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	var n := closed.size()
	# Split into a few strokes so the width can breathe along the edge.
	var parts := maxi(1, n / 8)
	for p in parts:
		var a := p * n / parts
		var b := mini(n - 1, (p + 1) * n / parts)
		if b - a < 1:
			continue
		var seg := closed.slice(a, b + 1)
		var w := width * (0.75 + 0.5 * hash01(p, salt))
		stroke(ci, seg, color, w * 0.8, w * 0.8, w * 1.15)


## A row of short parallel gouge ticks along a path (fleece, hatching, carved texture).
static func ticks(ci: CanvasItem, path: PackedVector2Array, color: Color, spacing: float, length: float, width: float, angle := 0.0, salt := 0) -> void:
	var acc := 0.0
	var k := 0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var d := a.distance_to(b)
		var dir := (b - a) / maxf(d, 0.001)
		var nrm := dir.orthogonal().rotated(angle)
		while acc < d:
			var p := a + dir * acc
			var l := length * (0.7 + 0.6 * hash01(k, salt))
			var j := (hash01(k, salt + 7) - 0.5) * spacing * 0.4
			var q := p + dir * j
			stroke(ci, PackedVector2Array([q - nrm * l * 0.5, q + nrm * l * 0.5]), color, width, 0.0, width * 1.2)
			acc += spacing
			k += 1
		acc -= d


## A straight line as a batched stroke (use instead of draw_line inside a batch).
static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	stroke(ci, PackedVector2Array([a, b]), color, width, width)


## A closed outline of even width as batched strokes (use instead of draw_polyline inside a batch).
static func ring(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := (b - a).normalized() * width * 0.5
		stroke(ci, PackedVector2Array([a - d, b + d]), color, width, width)


## Moves the drawing origin; flushes the batch first so earlier shapes keep their transform.
static func set_transform(ci: CanvasItem, pos: Vector2, rot := 0.0, scl := Vector2.ONE) -> void:
	flush()
	ci.draw_set_transform(pos, rot, scl)


## A soft glow: one quad with the baked radial falloff (game/art/textures/glow.png).
static func glow(ci: CanvasItem, c: Vector2, r: float, color: Color, squash := 1.0) -> void:
	var tex := Palette.tex("glow")
	if tex == null:
		return
	flush()
	ci.draw_texture_rect(tex, Rect2(c - Vector2(r, r * squash), Vector2(r * 2.0, r * 2.0 * squash)), false, color)


## Radiating gouge strokes (a carved sunburst), used for fire glow and hit bursts.
static func rays(ci: CanvasItem, c: Vector2, r0: float, r1: float, count: int, color: Color, width: float, salt := 0, arc := TAU, start := 0.0) -> void:
	for i in count:
		var a := start + arc * (float(i) + 0.5 * hash01(i, salt)) / float(count)
		var ln := lerpf(r0, r1, 0.55 + 0.45 * hash01(i, salt + 3))
		var d := Vector2.from_angle(a)
		stroke(ci, PackedVector2Array([c + d * r0, c + d * (r0 + ln) * 0.5, c + d * ln]), color, width, 0.0, width * 1.3)
