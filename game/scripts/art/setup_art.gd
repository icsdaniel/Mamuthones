class_name SetupArt
extends RefCounted
## Woodcut pictures for the first-launch and setup screens, drawn in the same hand as the rest of the
## game: carved shapes with ink edges, grain and chisel texture, white-line cuts, palette inks only.
## Each one fits itself into the Rect2 it is given (centred, aspect kept), so the UI only lays out a box.
## Use them from a Control's _draw(), or through the ready-made SetupArtView control.
##
##   SetupArt.headphones(ci, rect, lit := Palette.EMBER)
##       headphones cut in bone, a small cowbell hanging from the band, sound gouges from both cups.
##   SetupArt.phone_in_hands(ci, rect, tilt := 0.0, left_pressed := false, right_pressed := false,
##                           arrow := 0, flash := 0.0)
##       the phone held in two hands, seen from the player's side. tilt: radians, > 0 = top edge toward
##       the player (the face foreshortens, the top edge widens), < 0 = away; about +-0.9 is the useful
##       range. A pressed thumb sinks onto the glass with an ember ring; a raised one hovers with its
##       shadow. arrow: 1 = show a carved arrow "tilt the top toward you", -1 = "away", 0 = none.
##       flash 0..1 warms the screen (a counted tilt).
##   SetupArt.frame_drum(ci, rect, hit := 0.0)
##       a Sardinian frame drum (tumbarinu style): skin head with a carved rim and laced shell. hit 0..1
##       (set it to 1 on a tap and let it decay) pulses the head: it swells, glows ember at the centre,
##       ripples, and ember gouges spring out round the rim.
## All three draw about 0.1-0.4 ms; redraw only when a parameter changes (or while animating).

const SKIN := Color("#d8cbb4")        ## drum skin and hands: bone, a touch warmer
const SHELL := Color("#3a2a1f")       ## the drum's wooden shell


# ------------------------------------------------------------------ headphones

static func headphones(ci: CanvasItem, rect: Rect2, lit := Palette.EMBER) -> void:
	var s := minf(rect.size.x / 400.0, rect.size.y / 360.0)
	var c := rect.get_center() + Vector2(0, 10.0 * s)
	WoodcutDraw.begin(ci)
	WoodcutDraw.glow(ci, c, 210.0 * s, Color(lit, 0.28))
	# The band: a thick carved arc, bone with grain, lit along its left, ink edges.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 25:
		var a := lerpf(PI * 1.06, PI * 1.94, float(i) / 24.0)
		outer.append(c + Vector2(cos(a) * 150.0, sin(a) * 150.0 + 20.0) * s)
		inner.append(c + Vector2(cos(a) * 124.0, sin(a) * 126.0 + 20.0) * s)
	var band := outer.duplicate()
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	band = WoodcutDraw.rough(band, 1.2 * s, 3, 8.0 * s)
	WoodcutDraw.fill(ci, band, Palette.BONE_DIM)
	WoodcutDraw.fill(ci, band, Color(Palette.INK, 0.22), Palette.tex("grain"), 1.0 / (300.0 * s))
	WoodcutDraw.stroke(ci, outer.slice(0, 12), Color(lit, 0.7), 1.0 * s, 1.0 * s, 5.0 * s)
	WoodcutDraw.stroke(ci, inner.slice(13), Color(Palette.INK, 0.5), 1.0 * s, 1.0 * s, 5.0 * s)
	# Padding under the band: short cut stitches.
	for i in range(4, 21, 2):
		var p := outer[i].lerp(inner[i], 0.5)
		var d := (outer[i] - inner[i]).normalized()
		WoodcutDraw.line(ci, p - d * 5.0 * s, p + d * 5.0 * s, Color(Palette.INK, 0.45), 2.0 * s)
	WoodcutDraw.outline(ci, band, Palette.INK, 4.0 * s, 5)
	# The cups: dark carved shells with bone rims and ink cushions.
	for side in [-1.0, 1.0]:
		var sd: float = side
		var cc := c + Vector2(sd * 140.0, 70.0) * s
		var yoke := PackedVector2Array([c + Vector2(sd * 136.0, 20.0) * s, cc + Vector2(-sd * 4.0, -40.0) * s])
		WoodcutDraw.stroke(ci, yoke, Palette.INK, 16.0 * s, 12.0 * s)
		WoodcutDraw.stroke(ci, yoke, Palette.BONE_DIM, 9.0 * s, 6.0 * s)
		var shell := WoodcutDraw.rough(WoodcutDraw.ellipse(cc, Vector2(46.0, 64.0) * s, 24), 1.0 * s, 7 + int(sd), 6.0 * s)
		WoodcutDraw.fill(ci, shell, Palette.WOOD)
		WoodcutDraw.fill(ci, shell, Color(Palette.BONE, 0.1), Palette.tex("chisel"), 1.0 / (120.0 * s))
		# Shadow plane on the side away from the light, and a bone rim cut on the lit side.
		var shade := WoodcutDraw.ellipse(cc + Vector2(14.0, 4.0) * s, Vector2(30.0, 54.0) * s, 18)
		WoodcutDraw.fill(ci, shade, Color(Palette.INK, 0.45))
		WoodcutDraw.stroke(ci, WoodcutDraw.smooth_open(PackedVector2Array([cc + Vector2(-30, -44) * s, cc + Vector2(-44, 0) * s, cc + Vector2(-30, 46) * s]), 4),
			Color(Palette.BONE, 0.85 if sd < 0.0 else 0.5), 1.0 * s, 1.0 * s, 5.0 * s)
		# The cushion toward the head (inner side), an ink pad with a cut highlight.
		var pad := WoodcutDraw.ellipse(cc + Vector2(-sd * 36.0, 0.0) * s, Vector2(14.0, 56.0) * s, 16)
		WoodcutDraw.fill(ci, pad, Palette.INK)
		WoodcutDraw.stroke(ci, PackedVector2Array([cc + Vector2(-sd * 40.0, -34.0) * s, cc + Vector2(-sd * 42.0, 30.0) * s]), Color(Palette.BONE, 0.25), 1.0 * s, 1.0 * s, 3.0 * s)
		WoodcutDraw.outline(ci, shell, Palette.INK, 4.0 * s, 9)
		# Sound: carved gouge arcs going out from each cup.
		for k in 3:
			var r := (70.0 + 22.0 * float(k)) * s
			var arc := PackedVector2Array()
			for j in 7:
				var a := lerpf(-0.55, 0.55, float(j) / 6.0) + (0.0 if sd > 0.0 else PI)
				arc.append(cc + Vector2(cos(a), sin(a)) * r)
			WoodcutDraw.stroke(ci, arc, Color(lit, 0.9 - 0.25 * float(k)), 1.0 * s, 1.0 * s, (7.0 - 1.5 * float(k)) * s)
	# A small cowbell hanging from the middle of the band, ringing.
	var bell_at := c + Vector2(0, -92.0) * s
	WoodcutDraw.stroke(ci, PackedVector2Array([c + Vector2(0, -126.0) * s, bell_at + Vector2(0, -22.0) * s]), Color("#3a2618"), 5.0 * s, 4.0 * s)
	Figures.cowbell(ci, bell_at, 46.0 * s, 0.18, lit, 1)
	WoodcutDraw.end()


# ------------------------------------------------------------------ the phone in two hands

static func phone_in_hands(ci: CanvasItem, rect: Rect2, tilt := 0.0, left_pressed := false, right_pressed := false, arrow := 0, flash := 0.0) -> void:
	var s := minf(rect.size.x / 520.0, rect.size.y / 480.0)
	var c := rect.get_center() + Vector2(-(30.0 if arrow != 0 else 0.0) * s, -20.0 * s)
	tilt = clampf(tilt, -1.1, 1.1)
	WoodcutDraw.begin(ci)
	var w := 190.0 * s
	var h := 340.0 * s
	# Perspective: the edge coming toward you widens, the face gets shorter.
	var fh := h * maxf(cos(tilt), 0.25)
	var top_w := w * (1.0 + 0.4 * sin(tilt))
	var bot_w := w * (1.0 - 0.22 * sin(tilt))
	var top := c.y - fh * 0.5
	var bot := c.y + fh * 0.5
	var body := PackedVector2Array([Vector2(c.x - top_w * 0.5, top), Vector2(c.x + top_w * 0.5, top),
		Vector2(c.x + bot_w * 0.5, bot), Vector2(c.x - bot_w * 0.5, bot)])
	var body_r := _rounded(body, 22.0 * s)
	# Hands behind: the fingers wrapping round the back show at both sides.
	for side in [-1.0, 1.0]:
		_hand_back(ci, body, side, s)
	# The phone: ink body, a bone bezel line, the screen with the game's mask on it.
	WoodcutDraw.fill(ci, _offset(body_r, Vector2(6, 10) * s), Color(Palette.INK, 0.6))
	WoodcutDraw.fill(ci, body_r, Palette.INK)
	var screen := PackedVector2Array()
	for p in body:
		screen.append(c + (p - c) * Vector2(0.86, 0.9))
	var screen_r := _rounded(screen, 10.0 * s)
	WoodcutDraw.fill(ci, screen_r, Palette.WOOD.lerp(Palette.EMBER, 0.12 + 0.5 * clampf(flash, 0.0, 1.0)))
	WoodcutDraw.fill(ci, screen_r, Color(Palette.BONE, 0.06), Palette.tex("grain"), 1.0 / (260.0 * s))
	# The mask on the screen, squashed with the phone (drawn through a transform).
	WoodcutDraw.set_transform(ci, Vector2(c.x, c.y - fh * 0.06), 0.0, Vector2(1.0, maxf(cos(tilt), 0.25)))
	MaskView.paint(ci, Vector2.ZERO, 38.0 * s, Logo.MASK, 1, true)
	WoodcutDraw.set_transform(ci, Vector2.ZERO)
	# Glass glint: a cut diagonal on the lit side.
	WoodcutDraw.stroke(ci, PackedVector2Array([screen[0].lerp(screen[3], 0.08) + Vector2(10, 0) * s, screen[0].lerp(screen[1], 0.3) + Vector2(0, 14) * s]),
		Color(Palette.BONE, 0.3), 1.0 * s, 1.0 * s, 4.0 * s)
	WoodcutDraw.outline(ci, body_r, Palette.BONE_DIM, 3.5 * s, 4)
	WoodcutDraw.outline(ci, _grow(body_r, c, 4.0 * s), Palette.INK, 3.0 * s, 6)
	# Motion gouges off the edge that is moving toward or away from the player.
	if absf(tilt) > 0.08:
		var k := clampf(absf(tilt) / 0.8, 0.0, 1.0)
		var edge_y := top if tilt > 0.0 else bot
		var d := -1.0 if tilt > 0.0 else 1.0
		for j in 3:
			var yy := edge_y + d * (16.0 + 14.0 * float(j)) * s
			var half := (top_w if tilt > 0.0 else bot_w) * (0.42 - 0.1 * float(j))
			WoodcutDraw.stroke(ci, WoodcutDraw.quad(Vector2(c.x - half, yy + d * -4.0 * s), Vector2(c.x, yy + d * 4.0 * s), Vector2(c.x + half, yy + d * -4.0 * s), 6),
				Color(Palette.EMBER, k * (0.9 - 0.25 * float(j))), 1.0 * s, 1.0 * s, (6.0 - 1.4 * float(j)) * s)
	# Palms and thumbs in front.
	_hand_front(ci, body, -1.0, left_pressed, s)
	_hand_front(ci, body, 1.0, right_pressed, s)
	# The carved arrow: which way the top edge should go.
	if arrow != 0:
		var up := arrow > 0
		var ax := c.x + w * 0.5 + 110.0 * s
		var ay0 := c.y + (70.0 if up else -70.0) * s
		var ay1 := c.y + (-80.0 if up else 80.0) * s
		var dd := -1.0 if up else 1.0
		var shaft := PackedVector2Array([Vector2(ax, ay0), Vector2(ax + 6.0 * s, (ay0 + ay1) * 0.5), Vector2(ax, ay1)])
		WoodcutDraw.stroke(ci, shaft, Palette.INK, 22.0 * s, 22.0 * s)
		WoodcutDraw.stroke(ci, shaft, Palette.EMBER, 13.0 * s, 13.0 * s)
		var tip := Vector2(ax, ay1 + dd * 36.0 * s)
		var head := PackedVector2Array([tip, Vector2(ax + 34.0 * s, ay1 - dd * 10.0 * s), Vector2(ax - 34.0 * s, ay1 - dd * 10.0 * s)])
		WoodcutDraw.fill(ci, WoodcutDraw.rough(head, 1.0 * s, 3, 8.0 * s), Palette.EMBER)
		WoodcutDraw.outline(ci, head, Palette.INK, 5.0 * s, 2)
		WoodcutDraw.stroke(ci, PackedVector2Array([tip - Vector2(0, dd * 10.0 * s), Vector2(ax - 20.0 * s, ay1)]), Color(Palette.EMBER_HOT, 0.8), 1.0 * s, 1.0 * s, 3.0 * s)
	WoodcutDraw.end()


## The back of a hand: fingertips curling round the side of the phone.
static func _hand_back(ci: CanvasItem, body: PackedVector2Array, side: float, s: float) -> void:
	var a: Vector2 = body[1] if side > 0.0 else body[0]
	var b: Vector2 = body[2] if side > 0.0 else body[3]
	for i in 3:
		var p := a.lerp(b, 0.5 + 0.13 * float(i)) + Vector2(side * 12.0 * s, 0)
		var tip := WoodcutDraw.ellipse(p, Vector2(20.0, 15.0) * s, 12, side * 0.2)
		WoodcutDraw.fill(ci, tip, SKIN.darkened(0.2))
		WoodcutDraw.fill(ci, tip, Color(Palette.INK, 0.35), Palette.tex("hatch"), 1.0 / (70.0 * s))
		WoodcutDraw.outline(ci, tip, Palette.INK, 3.0 * s, i)


## The palm, cuff and thumb in front of the phone's lower corner. A pressed thumb lies flat on the glass
## with an ember ring round its tip; a raised thumb hovers, with a gap and its shadow on the glass.
static func _hand_front(ci: CanvasItem, body: PackedVector2Array, side: float, pressed: bool, s: float) -> void:
	var corner: Vector2 = body[2] if side > 0.0 else body[3]
	var edge_top: Vector2 = body[1] if side > 0.0 else body[0]
	var up := (edge_top - corner).normalized()
	var inward := Vector2(-side, 0)
	# Palm: a heavy carved shape coming in from below the corner, with a dark cuff.
	var pc := corner + Vector2(side * 30.0, 58.0) * s
	var palm := WoodcutDraw.smooth_closed(PackedVector2Array([pc + Vector2(-side * 62, -30) * s, pc + Vector2(-side * 20, -64) * s, pc + Vector2(side * 30, -50) * s,
		pc + Vector2(side * 52, 0) * s, pc + Vector2(side * 40, 60) * s, pc + Vector2(-side * 44, 62) * s]), 3)
	palm = WoodcutDraw.rough(palm, 1.0 * s, 11 + int(side), 7.0 * s)
	WoodcutDraw.fill(ci, palm, SKIN)
	# Shadow plane on the outer side of the palm, hatched.
	var shade := PackedVector2Array([pc + Vector2(side * 8, -56) * s, pc + Vector2(side * 30, -50) * s, pc + Vector2(side * 52, 0) * s, pc + Vector2(side * 40, 60) * s, pc + Vector2(side * 12, 60) * s])
	WoodcutDraw.fill(ci, shade, Color(Palette.INK, 0.3), Palette.tex("hatch"), 1.0 / (80.0 * s))
	WoodcutDraw.outline(ci, palm, Palette.INK, 4.0 * s, 13)
	var cuff := PackedVector2Array([pc + Vector2(-side * 50, 44) * s, pc + Vector2(side * 46, 38) * s, pc + Vector2(side * 50, 90) * s, pc + Vector2(-side * 54, 90) * s])
	WoodcutDraw.fill(ci, WoodcutDraw.rough(cuff, 1.0 * s, 17, 8.0 * s), Palette.WOOD)
	WoodcutDraw.stroke(ci, PackedVector2Array([cuff[0], cuff[1]]), Color(Palette.BONE, 0.35), 1.0 * s, 1.0 * s, 4.0 * s)
	# The thumb: from the palm up and in over the glass.
	var base := pc + Vector2(-side * 34.0, -40.0) * s
	var tip := corner + up * 70.0 * s + inward * 58.0 * s
	if not pressed:
		tip += Vector2(side * 6.0, 8.0) * s
		# Its shadow on the glass, where it would press.
		var sh := WoodcutDraw.ellipse(tip + Vector2(10.0, 14.0) * s, Vector2(22.0, 16.0) * s, 12)
		WoodcutDraw.fill(ci, sh, Color(Palette.INK, 0.45))
	var dirv := (tip - base).normalized()
	var thumb := PackedVector2Array([base + dirv.orthogonal() * 22.0 * s, tip + dirv.orthogonal() * (17.0 if pressed else 15.0) * s,
		tip + dirv * 14.0 * s, tip - dirv.orthogonal() * (17.0 if pressed else 15.0) * s, base - dirv.orthogonal() * 22.0 * s])
	thumb = WoodcutDraw.smooth_closed(thumb, 3)
	WoodcutDraw.fill(ci, thumb, SKIN if pressed else SKIN.lightened(0.08))
	WoodcutDraw.fill(ci, thumb, Color(Palette.INK, 0.18), Palette.tex("chisel"), 1.0 / (90.0 * s))
	# Knuckle crease and the nail as white-line and ink cuts.
	var kn := base.lerp(tip, 0.5)
	WoodcutDraw.stroke(ci, PackedVector2Array([kn + dirv.orthogonal() * 12.0 * s, kn - dirv.orthogonal() * 12.0 * s]), Color(Palette.INK, 0.55), 1.0 * s, 1.0 * s, 3.0 * s)
	var nail := WoodcutDraw.ellipse(tip + dirv * 2.0 * s, Vector2(9.0, 7.0) * s, 10, dirv.angle())
	WoodcutDraw.fill(ci, nail, Color(Palette.BONE, 0.7))
	WoodcutDraw.outline(ci, thumb, Palette.INK, 4.0 * s, 15)
	if pressed:
		# Pressed: an ember ring cut round the tip and short press ticks.
		var ring := WoodcutDraw.ellipse(tip + dirv * 4.0 * s, Vector2(34.0, 28.0) * s, 20)
		ring.append(ring[0])
		WoodcutDraw.stroke(ci, ring, Palette.INK, 9.0 * s, 9.0 * s)
		WoodcutDraw.stroke(ci, ring, Palette.EMBER, 5.0 * s, 5.0 * s)
		for k in 4:
			var d := Vector2.from_angle(-PI * 0.5 + (float(k) - 1.5) * 0.5 + (0.0 if side < 0.0 else 0.0))
			WoodcutDraw.stroke(ci, PackedVector2Array([tip + d * 40.0 * s, tip + d * 54.0 * s]), Palette.EMBER_HOT, 4.0 * s, 1.0 * s)


# ------------------------------------------------------------------ the frame drum

static func frame_drum(ci: CanvasItem, rect: Rect2, hit := 0.0) -> void:
	hit = clampf(hit, 0.0, 1.0)
	var s := minf(rect.size.x / 420.0, rect.size.y / 380.0)
	var c := rect.get_center() + Vector2(0, -10.0 * s)
	var k := 1.0 + 0.05 * hit
	var rx := 150.0 * s * k
	var ry := 108.0 * s * k
	var depth := 70.0 * s
	WoodcutDraw.begin(ci)
	WoodcutDraw.glow(ci, c, 250.0 * s, Color(Palette.EMBER, 0.2 + 0.35 * hit))
	# Shell: the side of the drum, dark wood with a carved zigzag band and the lacing.
	var shell := PackedVector2Array()
	for i in 25:
		var a := lerpf(0.0, PI, float(i) / 24.0)
		shell.append(c + Vector2(cos(a) * rx, sin(a) * ry + depth))
	for i in 25:
		var a := lerpf(PI, 0.0, float(i) / 24.0)
		shell.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	WoodcutDraw.fill(ci, _offset(shell, Vector2(8, 12) * s), Color(Palette.INK, 0.6))
	WoodcutDraw.fill(ci, shell, SHELL)
	WoodcutDraw.fill(ci, shell, Color(Palette.BONE, 0.14), Palette.tex("grain"), 1.0 / (200.0 * s))
	# Lit left side and the shadow side of the shell.
	WoodcutDraw.fill(ci, PackedVector2Array([c + Vector2(rx * 0.35, ry * 0.93), c + Vector2(rx, 0), c + Vector2(rx, depth), c + Vector2(rx * 0.35, ry * 0.93 + depth)]), Color(Palette.INK, 0.45))
	WoodcutDraw.stroke(ci, PackedVector2Array([c + Vector2(-rx, 2.0 * s), c + Vector2(-rx, depth)]), Color(Palette.EMBER, 0.8), 3.0 * s, 3.0 * s)
	# Rope lacing: a zigzag of natural cord round the shell.
	var lace := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.05, PI - 0.05, float(i) / 16.0)
		var y := (depth * 0.15) if i % 2 == 0 else (depth * 0.85)
		lace.append(c + Vector2(cos(a) * rx * 0.99, sin(a) * ry * 0.99 + y))
	WoodcutDraw.stroke(ci, lace, Palette.INK, 6.0 * s, 6.0 * s)
	WoodcutDraw.stroke(ci, lace, Palette.ROPE, 3.5 * s, 3.5 * s)
	WoodcutDraw.outline(ci, shell, Palette.INK, 4.0 * s, 3)
	# The head: stretched skin, a carved rim.
	var head := WoodcutDraw.rough(WoodcutDraw.ellipse(c, Vector2(rx, ry), 48), 0.8 * s, 5, 8.0 * s)
	WoodcutDraw.fill(ci, head, SKIN.lerp(Palette.EMBER_HOT, 0.35 * hit))
	WoodcutDraw.fill(ci, head, Color(Palette.INK, 0.12), Palette.tex("grain"), 1.0 / (240.0 * s))
	# A struck head glows at its centre.
	if hit > 0.0:
		WoodcutDraw.glow(ci, c, rx * (0.5 + 0.4 * hit), Color(Palette.EMBER, 0.7 * hit), ry / rx)
	# Ripples cut in the skin: faint at rest, running out from the centre when struck.
	for i in 3:
		var t := fposmod(float(i) / 3.0 + (1.0 - hit) * 0.33, 1.0) if hit > 0.0 else (float(i) + 1.0) / 4.0
		var rr := Vector2(rx, ry) * lerpf(0.2, 0.85, t)
		var ring := WoodcutDraw.ellipse(c, rr, 32)
		ring.append(ring[0])
		var a := (0.12 + 0.55 * hit * (1.0 - t)) if hit > 0.0 else 0.1
		WoodcutDraw.stroke(ci, ring, Color(Palette.INK, a), 1.0 * s, 1.0 * s, 2.5 * s)
	# Shadow of the rim on the skin (upper edge) and the rim itself.
	var rim_in := WoodcutDraw.ellipse(c, Vector2(rx, ry) * 0.9, 40)
	rim_in.append(rim_in[0])
	WoodcutDraw.stroke(ci, rim_in.slice(20, 41), Color(Palette.INK, 0.35), 1.0 * s, 1.0 * s, 6.0 * s)
	var rim := head.duplicate()
	rim.append(rim[0])
	WoodcutDraw.stroke(ci, rim, SHELL, 10.0 * s, 10.0 * s)
	WoodcutDraw.stroke(ci, rim.slice(24, 49), Color(Palette.EMBER, 0.55 + 0.4 * hit), 1.0 * s, 1.0 * s, 4.0 * s)
	WoodcutDraw.outline(ci, head, Palette.INK, 3.0 * s, 7)
	# The centre mark where to tap: a small carved rosette.
	for j in 6:
		var a := TAU * float(j) / 6.0
		var p := c + Vector2(cos(a) * 16.0, sin(a) * 11.0) * s
		WoodcutDraw.stroke(ci, PackedVector2Array([c, p]), Color(Palette.INK, 0.45), 3.0 * s, 1.0 * s)
	# The strike: ember gouges spring out round the rim.
	if hit > 0.05:
		for j in 18:
			var a := TAU * (float(j) + 0.5 * WoodcutDraw.hash01(j, 91)) / 18.0
			var d := Vector2(cos(a) * rx, sin(a) * ry) / rx
			var r0 := rx * (1.08 + 0.1 * (1.0 - hit))
			var r1 := r0 + rx * 0.25 * hit * (0.6 + 0.4 * WoodcutDraw.hash01(j, 92))
			var p0 := c + d * r0 + Vector2(0, depth * 0.3 if sin(a) > 0.0 else 0.0)
			var p1 := c + d * r1 + Vector2(0, depth * 0.3 if sin(a) > 0.0 else 0.0)
			WoodcutDraw.stroke(ci, PackedVector2Array([p0, p1]), Palette.INK, 9.0 * s * hit, 2.0 * s)
			WoodcutDraw.stroke(ci, PackedVector2Array([p0, p1]), Color(Palette.EMBER_HOT if j % 2 == 0 else Palette.EMBER, hit), 5.0 * s * hit, 1.0 * s)
	WoodcutDraw.end()


# ------------------------------------------------------------------ helpers

static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, d) * pts


## A quad with cut (rounded) corners.
static func _rounded(quad: PackedVector2Array, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := quad.size()
	for i in n:
		var p := quad[i]
		var a := quad[(i - 1 + n) % n]
		var b := quad[(i + 1) % n]
		var pa := p + (a - p).normalized() * r
		var pb := p + (b - p).normalized() * r
		out.append_array(WoodcutDraw.quad(pa, p, pb, 4))
	return out


static func _grow(pts: PackedVector2Array, c: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (p - c).normalized() * d)
	return out
