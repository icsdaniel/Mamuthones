class_name FireSkin
extends RefCounted
## The play field's pieces in pixel art ("Bonfire Night", docs/art-style.md): notes, hold rings and
## sashes, the bell bar and its badge, the stomp, the hit line with its gold targets, the step buttons
## and the hit bursts. The sprites are baked by tools/art/pixel/field.py into res://art/px/field/
## (their sizes and anchors in FireCells); the moving parts are drawn here in whole art pixels
## (PX screen px each) in palette colours. Call these from a Control's _draw(), passing it as `ci`.
##
## Two kinds of drawing:
##   flat    things lying on the road (the hold's sash, the stand-still band) are drawn in the flat
##           field that LaneView lays back in perspective; the road shader samples them once per art
##           pixel, so they must be opaque palette colours (it keeps pixels with alpha > 0.5);
##   upright things standing on it (notes, rings, badges, the bell bar, the hit line, bursts) are drawn
##           on screen at the projected point, sized by `sc` = the lane's width on screen / REF_LANE.
## A note is baked at every size one art pixel apart; the size is picked by depth and the position is
## kept smooth, so notes glide down the road while their pixels stay whole and square.

const PX := 3.0
const REF_LANE := 240.0
const PLATE_P := 3.2    ## squareness of a note plate (tools/art/pixel/road.py PLATE_P)
const BUTTON_STATES := ["idle", "cued", "pressed", "hit", "miss"]

## Named colours (all from the palette) that other scripts use.
const GOLD := Color("#e8b64c")        ## GOLD4
const GOLD_HOT := Color("#f8dc8a")    ## GOLD5
const EMBER := Color("#f47e22")       ## FIRE4
const CRIMSON := Color("#c02a22")     ## RED3
const NIGHT := Color("#07060e")       ## K0
const STILL_BLUE := Color("#c9cde8")  ## STAR0

static var _glow: Texture2D
static var _soft: GradientTexture2D
static var _soft_v: GradientTexture2D
static var _boxes := {}


# ------------------------------------------------------------------ sprites

static func tex(name: String) -> Texture2D:
	return PxArt.field(name)


## Draws field sprite `name` with its anchor at `at` (screen), k art px per sprite px.
static func sprite(ci: CanvasItem, name: String, at: Vector2, alpha := 1.0, k := 1, flip := false) -> void:
	var t := tex(name)
	if t == null or not FireCells.CELLS.has(name):
		return
	var cell: Array = FireCells.CELLS[name]
	var sz: Vector2 = cell[0]
	var a: Vector2 = cell[1]
	if flip:
		a.x = sz.x - 1.0 - a.x
	var p := (at - a * PX * k).round()
	var r := Rect2(p, sz * PX * k)
	if flip:
		ci.draw_set_transform(Vector2(r.end.x, r.position.y), 0.0, Vector2(-1.0, 1.0))
		ci.draw_texture_rect(t, Rect2(Vector2.ZERO, r.size), false, Color(1, 1, 1, alpha))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(t, r, false, Color(1, 1, 1, alpha))


## Where sprite `name` draws, relative to its anchor, on screen.
static func bounds(name: String, _sc := 1.0, flip := false) -> Rect2:
	if not FireCells.CELLS.has(name):
		return Rect2()
	var cell: Array = FireCells.CELLS[name]
	var sz: Vector2 = cell[0]
	var a: Vector2 = cell[1]
	var r := Rect2(-a * PX, sz * PX)
	if flip:
		r.position.x = -r.end.x
	return r


## A step plate's half-width in art px for lane scale sc (the baked sizes run NOTE_MIN..NOTE_MAX):
## about three quarters of the lane, so a note fills its lane and reads at a glance.
static func note_rx(sc: float) -> int:
	return clampi(roundi(29.0 * sc), FireCells.NOTE_MIN, FireCells.NOTE_MAX)


## The hit line's slot half-width in art px, for a lane whose slot is rx_screen screen px wide (half):
## the step plate's own size there, so a note on time fills its slot exactly.
static func target_rx(rx_screen: float) -> int:
	return clampi(note_rx(rx_screen / (0.33 * REF_LANE)), FireCells.TARGET_MIN, FireCells.TARGET_MAX)


# ------------------------------------------------------------------ pixel primitives

## A flat ring of whole art pixels round c (screen): half-widths rx, ry and thickness th in art px.
static func px_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, th: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var o := c.round()
	var R := ceili(ry)
	var rxi := rx - th
	var ryi := ry - th
	for j in range(-R, R):
		var v := float(j) + 0.5
		if absf(v) >= ry:
			continue
		var xo := roundi(rx * sqrt(1.0 - (v / ry) * (v / ry)))
		var xi := 0
		if rxi > 0.0 and absf(v) < ryi:
			xi = roundi(rxi * sqrt(1.0 - (v / ryi) * (v / ryi)))
		if xo <= xi:
			continue
		var y := o.y + float(j) * PX
		if xi == 0:
			ci.draw_rect(Rect2(o.x - xo * PX, y, xo * 2 * PX, PX), col)
		else:
			ci.draw_rect(Rect2(o.x - xo * PX, y, (xo - xi) * PX, PX), col)
			ci.draw_rect(Rect2(o.x + xi * PX, y, (xo - xi) * PX, PX), col)


static func px_disc(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	px_ring(ci, c, rx, ry, rx + 1.0, col)


## A ring the shape of a note plate (a rounded rectangle, PLATE_P) round c: half-widths rx, ry and
## thickness th in art px. Hit effects use it, so they grow out of the plate and its slot.
static func px_plate(ci: CanvasItem, c: Vector2, rx: float, ry: float, th: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var o := c.round()
	var R := ceili(ry)
	var rxi := rx - th
	var ryi := ry - th * 0.7
	for j in range(-R, R):
		var v := float(j) + 0.5
		if absf(v) >= ry:
			continue
		var xo := roundi(rx * pow(1.0 - pow(absf(v) / ry, PLATE_P), 1.0 / PLATE_P))
		var xi := 0
		if rxi > 0.0 and ryi > 0.0 and absf(v) < ryi:
			xi = roundi(rxi * pow(1.0 - pow(absf(v) / ryi, PLATE_P), 1.0 / PLATE_P))
		if xo <= xi:
			continue
		var y := o.y + float(j) * PX
		if xi == 0:
			ci.draw_rect(Rect2(o.x - xo * PX, y, xo * 2 * PX, PX), col)
		else:
			ci.draw_rect(Rect2(o.x - xo * PX, y, (xo - xi) * PX, PX), col)
			ci.draw_rect(Rect2(o.x + xi * PX, y, (xo - xi) * PX, PX), col)


## A plate's face half-height for half-width rx (tools/art/pixel/road.py face_ry).
static func plate_ry(rx: float) -> float:
	return maxf(2.0, roundf(rx * 0.36))


## A colour of `ramp` stepped down by life k (0 fresh .. 1 gone): palette steps, no alpha.
static func _step(ramp: Array, k: float) -> Color:
	var i := clampi(int(floor(clampf(k, 0.0, 0.999) * ramp.size())), 0, ramp.size() - 1)
	return ramp[i]


static func _hash(i: int, salt: int) -> float:
	return WoodcutDraw.hash01(i, salt)


## A chevron of whole art pixels at c pointing up (d -1) or down (d 1), `half` art px wide each side,
## two pixels thick, in col on a K0 outline.
static func px_chevron(ci: CanvasItem, c: Vector2, half: int, d: float, col: Color) -> void:
	var o := (c / PX).round() * PX
	for pass_ in 2:
		for i in range(-half, half + 1):
			var y := o.y + (float(half - absi(i)) * d - float(half) * d * 0.5) * PX
			var r := Rect2(o.x + float(i) * PX, y - (PX if d < 0.0 else 0.0), PX, 2.0 * PX)
			if pass_ == 0:
				ci.draw_rect(r.grow(PX), PixelPalette.K[0])
			else:
				ci.draw_rect(r, col)


# ------------------------------------------------------------------ upright notes

## A step: a cast gold plate with a red diamond inlaid. A call or off-beat step: a narrower red plate
## with a gold diamond.
static func draw_gem(ci: CanvasItem, at: Vector2, sc: float, call := false, alpha := 1.0, off := false) -> void:
	sprite(ci, "note_%s_%d" % ["call" if (call or off) else "step", note_rx(sc)], at, alpha)


## A healing step: a bone-white plate with a flame inlaid, and a thin gold halo breathing with
## `clock` (s).
static func draw_heal_gem(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0, clock := 0.0) -> void:
	var rx := note_rx(sc)
	var p := fposmod(clock * 1.5, 1.0)
	if alpha > 0.5 and p < 0.6:
		var k := p / 0.6
		var r := float(rx) + 2.0 + 4.0 * k
		px_plate(ci, at + Vector2(0, PX), r, plate_ry(r) + 1.0, 1.0, _step([PixelPalette.GOLD[5], PixelPalette.GOLD[4], PixelPalette.GOLD[3], PixelPalette.GOLD[2]], k))
	sprite(ci, "note_heal_%d" % rx, at, alpha)


## The end of a hold: the knot of its rope, a small gold plate.
static func draw_hold_ring(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0) -> void:
	sprite(ci, "hold_end_%d" % note_rx(sc), at, alpha)


## The two-thumb stomp: a fire-hot plate, wider and twice as thick as a step, with two bone thumb
## prints on its face (press with both thumbs at once).
static func draw_stomp_note(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0) -> void:
	sprite(ci, "note_stomp_%d" % note_rx(sc), at, alpha)


## The bell bar's medallion, upright at the bar's middle: a bone bell on red in a gold rim to raise
## the bells, on navy in a steel rim to lower them.
static func draw_badge(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0, up := true) -> void:
	var r := clampi(roundi(12.0 * sc), FireCells.BADGE_MIN, FireCells.BADGE_MAX)
	sprite(ci, "badge_%s_%d" % ["up" if up else "down", r], at, alpha)


## The bell bar's height in art px (without its outline) at lane scale sc.
static func bar_h(sc: float) -> int:
	return clampi(roundi(3.0 + 11.0 * sc), FireCells.BAR_MIN, FireCells.BAR_MAX)


## The bell bar, upright across the road from x0 to x1 at y (screen): a beam patterned with
## chevrons pointing the way to tilt - warm gold ones pointing up to raise the bells, cool steel ones
## pointing down to lower them - between two square end caps. The chevrons are laid out from the
## middle so the pattern stays symmetric round the badge.
static func draw_bar(ci: CanvasItem, x0: float, x1: float, y: float, sc: float, up: bool, alpha := 1.0) -> void:
	var h := bar_h(sc)
	var way := "up" if up else "down"
	var mid := "bar_%s_%d" % [way, h]
	var cap := "bar_end_%s_%d" % [way, h]
	var tm := tex(mid)
	var tc := tex(cap)
	if tm == null or tc == null:
		return
	var top := roundf(y - (h + 2) * 0.5 * PX)
	var cw := float(tc.get_width()) * PX
	var a := Color(1, 1, 1, alpha)
	var start := roundf(x0) + cw
	var end := roundf(x1) - cw
	var tw := float(tm.get_width()) * PX
	var th := float(tm.get_height()) * PX
	var cx := roundf((start + end) * 0.5 / PX) * PX
	# whole tiles out from the middle, then part tiles against the caps (cut at their outer side)
	var x := cx - tw * ceilf((cx - start) / tw)
	while x < end:
		var l := maxf(x, start)
		var r := minf(x + tw, end)
		if r > l:
			ci.draw_texture_rect_region(tm, Rect2(l, top, r - l, th), Rect2((l - x) / PX, 0, (r - l) / PX, tm.get_height()), a)
		x += tw
	ci.draw_texture_rect(tc, Rect2(roundf(x0), top, cw, float(tc.get_height()) * PX), false, a)
	ci.draw_set_transform(Vector2(end + cw, top), 0.0, Vector2(-1.0, 1.0))
	ci.draw_texture_rect(tc, Rect2(0.0, 0.0, cw, float(tc.get_height()) * PX), false, a)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rope-swipe fallback (the rope note is being retired): a plain rope across the road with an arrow.
static func draw_rope(ci: CanvasItem, at: Vector2, road_w: float, dir: int, alpha := 1.0) -> void:
	var y := roundf(at.y)
	var x0 := roundf(at.x - road_w * 0.42)
	var x1 := roundf(at.x + road_w * 0.42)
	ci.draw_rect(Rect2(x0, y - PX * 2.0, x1 - x0, PX * 4.0), Color(PixelPalette.K[0], alpha))
	ci.draw_rect(Rect2(x0, y - PX, x1 - x0, PX * 2.0), Color(PixelPalette.ROPE[1], alpha))
	var x := x0
	while x < x1:
		ci.draw_rect(Rect2(x, y - PX, PX, PX), Color(PixelPalette.ROPE[0], alpha))
		x += PX * 3.0
	var tip := x1 if dir >= 0 else x0
	var d := 1.0 if dir >= 0 else -1.0
	for i in 4:
		ci.draw_rect(Rect2(tip - d * float(i) * PX - PX * 0.5, y - PX * (i + 1), PX, PX * (2 * i + 2)), Color(PixelPalette.ROPE[2], alpha))


# ------------------------------------------------------------------ the hit line

## The hit line: a thin gold rule across the whole width at y (on the art grid), and on each lane the
## slot a step plate lands in (centres xs, slot half-width rx screen px): the plate's own outline. lit[i] 0..1 lights a target
## (pressed, holding); pulse 0..1 is the beat (the bar and the targets brighten on it); miss[i] true
## dulls a target for an instant.
static func draw_hit_line(ci: CanvasItem, x0: float, x1: float, y: float, xs: Array, rx: float, lit: Array, pulse := 0.0, miss: Array = []) -> void:
	var G := PixelPalette.GOLD
	var on := pulse > 0.5
	var rows := [PixelPalette.K[0], G[3], G[5], G[2], PixelPalette.K[0]] if on else [PixelPalette.K[0], G[2], G[4], G[1], PixelPalette.K[0]]
	var yy := roundf(y)
	for i in rows.size():
		ci.draw_rect(Rect2(x0, yy + float(i - 2) * PX, x1 - x0, PX), rows[i])
	var trx := target_rx(rx)
	for i in xs.size():
		var l: float = lit[i] if i < lit.size() else 0.0
		var m: bool = miss[i] if i < miss.size() else false
		var st := "idle"
		if l > 0.35:
			st = "lit"
		elif m:
			st = "miss"
		elif on:
			st = "beat"
		sprite(ci, "target_%s_%d" % [st, trx], Vector2(roundf(float(xs[i])), yy))


## The hit line's light on the road (draw on an additive canvas item): stepped bands, taller on the beat.
static func draw_hit_glow(ci: CanvasItem, x0: float, x1: float, y: float, pulse := 0.0) -> void:
	if pulse < 0.5:
		return
	var yy := roundf(y)
	var c := Color(PixelPalette.FIRE[3], 0.22)
	ci.draw_rect(Rect2(x0, yy - 4.0 * PX, x1 - x0, 2.0 * PX), c)
	ci.draw_rect(Rect2(x0, yy + 4.0 * PX, x1 - x0, 2.0 * PX), c)


# ------------------------------------------------------------------ flat (on the road)

## A hold's rope lying on the road in `lane` (flat), from y_head back to y_tail: a thick hemp rope,
## two strands twisted round each other, in a K0 outline; the twists are anchored to the head so they
## travel with it. It catches fire while held. Opaque palette colours only.
static func draw_sash(ci: CanvasItem, lane: Rect2, y_head: float, y_tail: float, lit := false, clip := Rect2()) -> void:
	var top := minf(y_head, y_tail)
	var bottom := maxf(y_head, y_tail)
	if clip.has_area():
		top = maxf(top, clip.position.y)
		bottom = minf(bottom, clip.end.y)
	if bottom - top < 1.0:
		return
	var R := PixelPalette.ROPE
	var F := PixelPalette.FIRE
	var base: Color = F[5] if lit else R[1]
	var hi: Color = F[6] if lit else R[2]
	var lo: Color = F[3] if lit else R[0]
	var cx := lane.get_center().x
	var k := lane.size.x / REF_LANE
	var bw := 66.0 * k
	var r := Rect2(cx - bw * 0.5, top, bw, bottom - top)
	ci.draw_rect(r.grow_individual(7.0 * k, 0, 7.0 * k, 0), PixelPalette.K[0])
	ci.draw_rect(r, base)
	# the twists: slanted bands, a lit ridge and a shadowed groove on each, one every `step`
	var step := 40.0 * k
	var slant := 22.0 * k
	var dy := fposmod(y_head - bottom, step)
	var y := bottom + dy + slant
	var x0 := r.position.x
	var x1 := r.end.x
	while y > top - slant - step:
		var ridge := PackedVector2Array([Vector2(x0, y), Vector2(x1, y - slant), Vector2(x1, y - slant - step * 0.4), Vector2(x0, y - step * 0.4)])
		var groove := PackedVector2Array([Vector2(x0, y), Vector2(x1, y - slant), Vector2(x1, y - slant + step * 0.14), Vector2(x0, y + step * 0.14)])
		for part in [[ridge, hi], [groove, lo]]:
			var cut := _clip_y(part[0], top, bottom)
			if cut.size() >= 3 and _area(cut) > 1.0:
				ci.draw_colored_polygon(cut, part[1])
		y -= step
	# the rope's shaded right side and lit left edge
	ci.draw_rect(Rect2(r.end.x - 9.0 * k, top, 9.0 * k, r.size.y), lo)
	ci.draw_rect(Rect2(r.position.x, top, 6.0 * k, r.size.y), hi)


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		a += pts[i].cross(pts[(i + 1) % pts.size()])
	return absf(a) * 0.5


## A polygon cut to the band top..bottom (horizontal clip; the rope's twists never draw past its ends).
static func _clip_y(pts: PackedVector2Array, top: float, bottom: float) -> PackedVector2Array:
	var out := pts
	for edge in [[top, 1.0], [bottom, -1.0]]:
		var lim: float = edge[0]
		var sgn: float = edge[1]
		var res := PackedVector2Array()
		for i in out.size():
			var p := out[i]
			var q := out[(i + 1) % out.size()]
			var pin := (p.y - lim) * sgn >= 0.0
			var qin := (q.y - lim) * sgn >= 0.0
			if pin:
				res.append(p)
			if pin != qin:
				var t := (lim - p.y) / (q.y - p.y)
				res.append(p.lerp(q, t))
		out = res
		if out.size() < 3:
			return PackedVector2Array()
	return out


## The stand-still band: navy, hatched, closed by two pale rules (flat, opaque palette colours).
static func draw_band(ci: CanvasItem, field: Rect2, y_top: float, y_bottom: float) -> void:
	var top := minf(y_top, y_bottom)
	var bottom := maxf(maxf(y_top, y_bottom), top + 28.0)
	var r := Rect2(field.position.x, top, field.size.x, bottom - top)
	var N := PixelPalette.NAVY
	ci.draw_rect(r, N[1])
	var gap := 44.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var p0 := Vector2(x, r.end.y)
		var p1 := Vector2(x + r.size.y, r.position.y)
		ci.draw_line(p0, p1, N[3], 10.0)
		x += gap
	for yy in [top, bottom]:
		ci.draw_rect(Rect2(r.position.x, yy - 5.0, r.size.x, 10.0), STILL_BLUE)


## The road's setts where the road shader is off (flat lanes): plain dark stone.
static func draw_setts(ci: CanvasItem, field: Rect2) -> void:
	ci.draw_rect(field, PixelPalette.SETT[1])


# ------------------------------------------------------------------ buttons

static func _box(state: String) -> StyleBoxTexture:
	if _boxes.has(state):
		return _boxes[state]
	var sb := StyleBoxTexture.new()
	sb.texture = tex("button_" + state)
	var m := float(FireCells.BUTTON_MARGIN)
	sb.texture_margin_left = m
	sb.texture_margin_top = m
	sb.texture_margin_right = m
	sb.texture_margin_bottom = m
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_boxes[state] = sb
	return sb


## A step button filling `rect` (snapped to whole art px): a navy panel in a gold frame, a row of gold
## diamonds along its top, cream footprints (left, both, right). States: idle, cued (the next note is
## close: the frame and prints brighten), pressed (the panel sinks, the prints drop a pixel), hit (the
## panel burns red and the prints go hot), miss (all dull).
static func draw_button(ci: CanvasItem, rect: Rect2, lane: int, state: String) -> void:
	if not (state in BUTTON_STATES):
		state = "idle"
	var p := rect.position.round()
	var n := (rect.size / PX).floor()
	if n.x < 14.0 or n.y < 14.0:
		return
	ci.draw_set_transform(p, 0.0, Vector2(PX, PX))
	ci.draw_style_box(_box(state), Rect2(Vector2.ZERO, n))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dia: String = {"idle": "diamond", "cued": "diamond_bright", "pressed": "diamond_bright", "hit": "diamond_hot", "miss": "diamond_dim"}[state]
	var tone: String = {"idle": "idle", "cued": "bright", "pressed": "bright", "hit": "hot", "miss": "dim"}[state]
	# the diamonds: one every 5 art px across the top, centred
	var count := int((n.x - 12.0) / 5.0) + 1
	var x0 := p.x + roundf((n.x - float(count - 1) * 5.0) * 0.5) * PX
	for i in count:
		sprite(ci, dia, Vector2(x0 + float(i) * 5.0 * PX, p.y + 6.0 * PX))
	var c := p + Vector2(floorf(n.x * 0.5), floorf(n.y * 0.5) + 3.0) * PX
	if state == "pressed" or state == "hit":
		c.y += PX
	if lane == 1:
		sprite(ci, "foot_l_" + tone, c + Vector2(-7.0 * PX, 0.0))
		sprite(ci, "foot_r_" + tone, c + Vector2(7.0 * PX, 0.0))
	else:
		sprite(ci, ("foot_l_" if lane == 0 else "foot_r_") + tone, c)


# ------------------------------------------------------------------ bursts

## A hit burst at `at` (screen), sc = lane scale; returns false once it is over (LaneSkin.BURST_TIME).
## Drawn in palette colours, in whole art pixels, under the notes (it never covers one): a gold ring
## thrown out from the target, stepping down the gold ramp as it widens, and sparks flying up and out.
## Perfect the most, good less, early / late in their cool and warm colours; heal a gold column and a
## bone ring; held a warm column; a miss a quick dark ring closing in with ash dropping.
static func draw_burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc := 1.0) -> bool:
	var life := LaneSkin.BURST_TIME
	if age < 0.0 or age > life:
		return false
	var t := age / life
	var grow := 1.0 - pow(1.0 - t, 2.5)
	var rx := float(note_rx(sc))
	var G: Array = PixelPalette.GOLD
	var F: Array = PixelPalette.FIRE
	var gold := [G[5], G[5], G[4], G[4], G[3]]
	match quality:
		"perfect", "good", "early", "late":
			var ring := gold
			if quality == "early" or quality == "late":
				var sc_col: Color = Palette.EARLY if quality == "early" else Palette.LATE
				ring = [sc_col.lightened(0.3), sc_col, sc_col, sc_col.darkened(0.3), sc_col.darkened(0.5)]
			var big := 1.0 if quality == "perfect" else 0.75
			# the plate flashes white-hot in its slot, then its outline is thrown out
			if t < 0.12:
				px_plate(ci, at, rx, plate_ry(rx), rx, F[7])
			elif t < 0.22:
				px_plate(ci, at, rx + 1.0, plate_ry(rx) + 1.0, 2.0, F[6])
			var r1 := lerpf(rx + 2.0, rx * (1.0 + 0.35 * big), grow)
			if t < 0.75:
				px_plate(ci, at, r1, plate_ry(r1) + 3.0 * grow, 2.0, _step(ring, t / 0.75))
			if quality == "perfect" and t < 0.6:
				var r2 := lerpf(rx + 2.0, rx * 1.6, pow(t / 0.6, 0.8))
				px_plate(ci, at, r2, plate_ry(r2) + 6.0 * t, 1.0, _step([G[5], G[4], G[3]], t / 0.6))
			_sparks(ci, at, rx, t, 14 if quality == "perfect" else 8, [F[7], F[6], F[5], F[4], F[3]], 1.0)
		"heal":
			var h := lerpf(6.0, 34.0, grow)
			var w := maxf(1.0, rx * 0.25 * (1.0 - t))
			var col := _step([PixelPalette.BONE[4], G[5], G[4], G[3]], t)
			ci.draw_rect(Rect2(roundf(at.x - w * PX), roundf(at.y - h * PX), roundf(w * 2.0) * PX, h * PX), col)
			var r := lerpf(rx, rx * 1.6, grow)
			px_plate(ci, at, r, plate_ry(r), 2.0 if t < 0.4 else 1.0, _step([PixelPalette.BONE[4], PixelPalette.BONE[3], G[4], G[3]], t))
			_sparks(ci, at, rx, t, 16, [PixelPalette.BONE[4], G[5], G[4], G[3]], 1.3)
		"held":
			var h := lerpf(4.0, 24.0, grow)
			var w := maxf(1.0, rx * 0.2 * (1.0 - t))
			ci.draw_rect(Rect2(roundf(at.x - w * PX), roundf(at.y - h * PX), roundf(w * 2.0) * PX, h * PX), _step([F[7], F[6], F[5], F[4]], t))
			var r := lerpf(rx, rx * 1.25, grow)
			if t < 0.7:
				px_plate(ci, at, r, plate_ry(r), 2.0, _step([F[6], F[5], F[4]], t / 0.7))
			_sparks(ci, at, rx, t, 8, [F[6], F[5], F[4], F[3]], 0.9)
		_:
			# a miss: the slot's outline closes in dark red, ash dropping
			if t < 0.6:
				var r := lerpf(rx * 1.3, rx + 1.0, t / 0.6)
				px_plate(ci, at, r, plate_ry(r), 2.0, _step([PixelPalette.RED[2], PixelPalette.RED[1], PixelPalette.RED[0]], t / 0.6))
			for i in 6:
				var x := (_hash(i, 11) - 0.5) * rx * 1.6
				var y := -2.0 + t * (6.0 + 8.0 * _hash(i, 13))
				if t < 0.4 + 0.5 * _hash(i, 17):
					ci.draw_rect(Rect2(at.round() + Vector2(roundf(x), roundf(y)) * PX, Vector2(PX, PX)), PixelPalette.BONE[0])
	return true


## Sparks thrown up and out from a target: single art pixels on arcs, stepping down `ramp` as they age.
static func _sparks(ci: CanvasItem, at: Vector2, rx: float, t: float, n: int, ramp: Array, reach: float) -> void:
	var o := at.round()
	for i in n:
		var life := 0.55 + 0.45 * _hash(i, 7)
		var k := t / life
		if k >= 1.0:
			continue
		var a := -PI * (0.08 + 0.84 * _hash(i, 3))
		var sp := rx * (0.7 + 0.7 * _hash(i, 5)) * reach
		var d := sp * (1.0 - pow(1.0 - k, 2.0))
		var x := cos(a) * (rx * 0.6 + d)
		var y := sin(a) * (rx * 0.25 + d * 0.55) + 10.0 * k * k
		var tall := 2.0 if k < 0.3 else 1.0
		ci.draw_rect(Rect2(o + Vector2(roundf(x), roundf(y)) * PX, Vector2(PX, PX * tall)), _step(ramp, k))


const STOMP_TIME := 0.7
const STOMP_HALF_TIME := 0.4


## The stomp's hit at `at` (screen), sc = lane scale, t = seconds since the hit; returns false once
## over. Both thumbs (a full stomp): the heaviest hit in the game - a white-hot flash on the drum, a
## wide gold shock ring racing out along the road with a second on its heels, dust kicked out
## sideways low along the ground and sparks thrown high. One thumb: a dull half of it - one small
## ring in old gold, a little dust, no sparks. (Let the bonfire flare with it: FireBackdrop.kick().)
static func draw_stomp_hit(ci: CanvasItem, at: Vector2, sc: float, t: float, both: bool) -> bool:
	var life := STOMP_TIME if both else STOMP_HALF_TIME
	if t < 0.0 or t > life:
		return false
	var k := t / life
	var G: Array = PixelPalette.GOLD
	var F: Array = PixelPalette.FIRE
	var B: Array = PixelPalette.BONE
	var S: Array = PixelPalette.STONE
	var rx := roundf(float(note_rx(sc)) * 1.22)
	var o := at.round()
	if both:
		if t < 0.07:
			px_plate(ci, o, rx, plate_ry(rx), rx, F[7])
		elif t < 0.14:
			px_plate(ci, o, rx + 1.0, plate_ry(rx) + 1.0, 2.0, F[6])
		var g1 := 1.0 - pow(1.0 - k, 3.0)
		var r1 := lerpf(rx + 2.0, rx * 2.2, g1)
		if k < 0.8:
			px_plate(ci, o, r1, plate_ry(rx) + 8.0 * g1, 3.0 if k < 0.4 else 2.0, _step([F[7], G[5], G[4], G[3]], k / 0.8))
		var k2 := (t - 0.09) / (life - 0.09)
		if k2 > 0.0 and k2 < 0.7:
			var g2 := 1.0 - pow(1.0 - k2, 2.5)
			var r2 := lerpf(rx + 1.0, rx * 1.6, g2)
			px_plate(ci, o, r2, plate_ry(rx) + 5.0 * g2, 2.0, _step([G[5], G[4], G[3]], k2 / 0.7))
		_dust(ci, o, rx, k, 30, 0.8, [B[3], B[2], S[5], S[4], S[3]])
		_sparks(ci, o, rx * 0.8, clampf(t / 0.55, 0.0, 1.0), 20, [F[7], F[6], F[5], F[4], F[3]], 1.8)
	else:
		var r := lerpf(rx, rx * 1.3, 1.0 - pow(1.0 - k, 2.0))
		if k < 0.75:
			px_plate(ci, o, r, plate_ry(rx) + 2.0, 2.0, _step([G[3], G[2], G[1]], k / 0.75))
		_dust(ci, o, rx, k, 10, 0.45, [B[1], S[4], S[3], S[2]])
	return true


## Dust kicked out sideways from a stomp, low along the road: small clumps of art pixels that slow and
## settle, stepping down `ramp`.
static func _dust(ci: CanvasItem, o: Vector2, rx: float, k: float, n: int, reach: float, ramp: Array) -> void:
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var life := 0.6 + 0.4 * _hash(i, 23)
		var kk := k / life
		if kk >= 1.0:
			continue
		var d := rx * (0.9 + 2.2 * _hash(i, 29)) * reach * (1.0 - pow(1.0 - kk, 3.0))
		var x := side * (rx * 0.7 + d)
		var y := (_hash(i, 31) - 0.4) * rx * 0.35 - 4.0 * sin(kk * PI) * _hash(i, 37)
		var s := 2.0 if kk < 0.5 else 1.0
		ci.draw_rect(Rect2(o + Vector2(roundf(x), roundf(y)) * PX, Vector2(s, s) * PX), _step(ramp, kk))


# ------------------------------------------------------------------ soft light (shadows, halos)

## A soft round glow, white in the middle and gone at the edge (tint it with the draw colour). Kept
## for the soft shadows and halos other scripts draw (side rows, HUD meters).
static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## A soft band across its width (bright in the middle).
static func soft(vertical := false) -> Texture2D:
	if vertical:
		if _soft_v == null:
			_soft_v = soft().duplicate()
			_soft_v.fill_to = Vector2(0.0, 1.0)
			_soft_v.width = 4
			_soft_v.height = 64
		return _soft_v
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 4
		_soft = t
	return _soft


static func ellipse_pts(c: Vector2, rx: float, ry: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := float(i) / float(n) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# ------------------------------------------------------------------ type (HUD and judgement words)

const TEXT_GRADIENT_SHADER := """
shader_type canvas_item;
// Fills a label's text (drawn in white) with a vertical gradient over the label's height; the outline
// and shadow (dark) are left as they are.
uniform vec4 top_col : source_color = vec4(1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform vec4 bottom_col : source_color = vec4(1.0, 0.7, 0.23, 1.0);
uniform float height = 60.0;
uniform float y0 = 0.2;
uniform float y1 = 0.8;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	vec4 c = COLOR;
	if (c.r > 0.85 && c.g > 0.85 && c.b > 0.85) {
		float t = clamp((ly / height - y0) / (y1 - y0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(top_col.rgb, mid_col.rgb, t * 2.0) : mix(mid_col.rgb, bottom_col.rgb, t * 2.0 - 1.0);
		c.rgb = g * c.rgb;
	}
	COLOR = c;
}
"""

static var _italic := {}
static var _grad_shader: Shader
static var _carved: Dictionary = {}


## Alegreya Sans in a slanted, heavy cut.
static func italic_font(weight := "ExtraBold") -> Font:
	if _italic.has(weight):
		return _italic[weight]
	var f := FontVariation.new()
	f.base_font = Palette.text_font(weight)
	f.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	_italic[weight] = f
	return f


## A material that fills white text with a top-to-bottom gradient (gold by default).
static func text_gradient(top := Color.WHITE, mid := Color("#ffe7a8"), bottom := Color("#ffb13a")) -> ShaderMaterial:
	if _grad_shader == null:
		_grad_shader = Shader.new()
		_grad_shader.code = TEXT_GRADIENT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _grad_shader
	m.set_shader_parameter("top_col", top)
	m.set_shader_parameter("mid_col", mid)
	m.set_shader_parameter("bottom_col", bottom)
	return m


static func style_label(l: Label, size: int, color := Color.WHITE, outline := 8) -> void:
	l.add_theme_font_override("font", italic_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#12060a"))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", outline + 4)


## The display serif, optionally emboldened.
static func carved_font(embolden := 0.0) -> Font:
	if _carved.has(embolden):
		return _carved[embolden]
	var f := FontVariation.new()
	f.base_font = Palette.display_font()
	f.variation_embolden = embolden
	f.fallbacks = [Palette.text_font("Bold")]
	_carved[embolden] = f
	return f


## A label in the display serif: colour (white under a gradient), a hairline outline, a cut shadow.
static func carve_label(l: Label, size: int, color := Color.WHITE, hair := Color(0, 0, 0, 0), halo := 6, embolden := 0.0) -> void:
	l.add_theme_font_override("font", carved_font(embolden))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", hair)
	l.add_theme_constant_override("outline_size", 2 if hair.a > 0.0 else 0)
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.01, 0.02, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, int(round(size * 0.06))))
	l.add_theme_constant_override("shadow_outline_size", halo)
