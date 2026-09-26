class_name StopBackdrops
extends RefCounted
## The seven stops of the story (docs/design.md section 5), each with its own backdrop, drawn once
## (retained) behind the procession. Coordinates are the ProcessionScene's design space: width W,
## height H, the row's ground line at G. paint() draws what is behind the fires, paint_front() what
## stands between the fires and the row (crowds, bonfire logs).
##
##   1 The Workshop           a carver's workshop at night: plank walls, masks and bells on nails, hearth
##   2 Sant'Antonio's Fires   the great bonfire in the street, houses and a crowd around it
##   3 Around the Bonfires    the village on its hill with fires at every corner
##   4 Carnival Sunday        winter daylight in the stone streets, balconies and onlookers
##   5 The Rope               the thick of the crowd, where the Issohadores throw the rope
##   6 The Piazza             the square before the church and its bell tower, evening
##   7 Shrove Tuesday         the last procession at dusk, red sky and fog

const COUNT := 7

const NAMES := ["The Workshop", "Sant'Antonio's Fires", "Around the Bonfires", "Carnival Sunday", "The Rope",
	"The Piazza", "Shrove Tuesday"]


## Lighting and animated pieces for a stop:
## lit: the colour of the light on the figures; sky: night|interior|day|evening|dusk;
## fires: [{x: fraction of W, y: base above G (px), w, h}] for animated fire quads;
## glow: [x fraction, y above G, radius, alpha]; fog: [density, Color]; sparks: bool.
static func info(stop: int) -> Dictionary:
	match clampi(stop, 1, COUNT):
		1:
			return {"lit": Palette.EMBER, "sky": "interior", "fires": [{"x": 0.1, "y": 18.0, "w": 70.0, "h": 86.0}],
				"glow": [0.1, 40.0, 330.0, 0.55], "fog": [0.18, Color(Palette.EMBER_HOT, 0.25)], "sparks": false, "crowd_rim": 0.0}
		2:
			return {"lit": Palette.EMBER, "sky": "night", "fires": [{"x": 0.62, "y": 70.0, "w": 300.0, "h": 380.0}],
				"glow": [0.62, 200.0, 560.0, 0.8], "fog": [0.35, Color(Palette.BONE, 0.3)], "sparks": true, "crowd_rim": 0.7}
		3:
			return {"lit": Palette.EMBER, "sky": "night", "fires": [{"x": 0.1, "y": 58.0, "w": 120.0, "h": 140.0},
				{"x": 0.6, "y": 150.0, "w": 46.0, "h": 56.0}, {"x": 0.9, "y": 64.0, "w": 104.0, "h": 124.0}],
				"glow": [0.5, 120.0, 560.0, 0.45], "fog": [0.3, Color(Palette.BONE, 0.3)], "sparks": true, "crowd_rim": 0.8}
		4:
			return {"lit": Palette.BONE, "sky": "day", "fires": [], "glow": [0.3, 260.0, 500.0, 0.0],
				"fog": [0.3, Color(Palette.BONE, 0.55)], "sparks": false, "crowd_rim": 0.5}
		5:
			# Low afternoon sun down the lane: warm light, long shadows, little fog.
			return {"lit": Color("#f0cf95"), "sky": "day", "fires": [], "glow": [0.64, 250.0, 420.0, 0.25],
				"fog": [0.1, Color("#f0cf95", 0.35)], "sparks": false, "crowd_rim": 0.7}
		6:
			return {"lit": Palette.EMBER, "sky": "evening", "fires": [], "glow": [0.3, 120.0, 420.0, 0.35],
				"fog": [0.3, Color(Palette.BONE, 0.4)], "sparks": false, "crowd_rim": 0.6}
		_:
			return {"lit": Palette.EMBER, "sky": "dusk", "fires": [{"x": 0.08, "y": 96.0, "w": 70.0, "h": 84.0}],
				"glow": [0.75, 190.0, 520.0, 0.4], "fog": [0.5, Color(Palette.EMBER_HOT, 0.35)], "sparks": true, "crowd_rim": 0.8}


## How the procession is staged at each stop, so no two stops show the same group:
##   x        where the row's centre stands, as a fraction of W
##   front    Mamuthones in the front line (1..3; your Mamuthone is always one of them)
##   back     Mamuthones in the back line (0..3)
##   isso     Issohadores (0 none, 1 the front one, 2 both)
##   scale    figure size (smaller = further away)
##   ground   the row's ground line relative to G (negative = further up the street)
##   depth    how far behind the front line the back line walks, in figure heights
##   spread   spacing multiplier
##   flip     true: the row walks to the left
##   shade    colour the figures are multiplied by (silhouettes against a bright sky)
##   isso_at  optional [x fraction, ground, scale] for the front Issohadore standing apart
##   onlooker optional [x fraction, ground, scale]: someone in the crowd for the rope to catch
static func row(stop: int) -> Dictionary:
	var r := {"x": 0.36, "front": 3, "back": 3, "isso": 2, "scale": 1.0, "ground": 0.0, "depth": 0.09, "spread": 1.0,
		"flip": false, "shade": Color.WHITE}
	match clampi(stop, 1, COUNT):
		1:
			# The night before: your Mamuthone alone, dressed and ready by the hearth.
			r.merge({"x": 0.6, "front": 1, "back": 0, "isso": 0, "scale": 1.04}, true)
		2:
			pass
		3:
			# Circling the bonfires: the row turns back past the fire, walking left, the back line far off.
			r.merge({"x": 0.5, "front": 2, "back": 3, "isso": 1, "scale": 0.9, "ground": -6.0, "depth": 0.2, "flip": true}, true)
		4:
			# Carnival Sunday: the whole procession filling the street.
			r.merge({"x": 0.44, "scale": 0.86, "ground": -8.0, "depth": 0.13, "spread": 0.92}, true)
		5:
			# The Rope: the row is further up the lane; the Issohadore works the crowd right in front.
			r.merge({"x": 0.3, "front": 2, "back": 2, "isso": 2, "scale": 0.7, "ground": -52.0, "depth": 0.1,
				"isso_at": [0.6, 4.0, 1.12], "onlooker": [0.85, 6.0, 1.0]}, true)
		6:
			# The Piazza: small figures in the big square before the church.
			r.merge({"x": 0.52, "scale": 0.74, "ground": -18.0, "depth": 0.12, "spread": 1.05}, true)
		_:
			# Shrove Tuesday: close, dark against the red dusk, walking toward the last of the light.
			r.merge({"x": 0.4, "front": 3, "back": 2, "isso": 1, "scale": 1.1, "ground": 4.0, "depth": 0.07, "spread": 0.95,
				"shade": Color(0.62, 0.56, 0.54)}, true)
	return r


static func paint(ci: CanvasItem, stop: int, w: float, h: float, g: float) -> void:
	WoodcutDraw.begin(ci)
	match clampi(stop, 1, COUNT):
		1:
			_workshop(ci, w, h, g)
		2:
			_sky_night(ci, w, h, 2)
			_houses(ci, 0.0, w * 0.34, g - 70.0, 150.0, 230.0, Color("#0e0b0a"), Palette.EMBER, 21, 0.9)
			_houses(ci, w * 0.66, w, g - 70.0, 150.0, 230.0, Color("#0e0b0a"), Palette.EMBER, 22, 0.9)
			_street(ci, w, h, g - 90.0, Color("#1c1512"), Color(Palette.EMBER, 0.35))
		3:
			_sky_night(ci, w, h, 3)
			_hill_village(ci, w, h, g)
			_street(ci, w, h, g - 70.0, Color("#1a1411"), Color(Palette.EMBER, 0.28))
		4:
			_sky_paper(ci, w, h, g - 220.0)
			_houses(ci, -20.0, w + 20.0, g - 64.0, 170.0, 250.0, Color("#cdbfa9"), Palette.INK, 41, 0.0, true)
			_street(ci, w, h, g - 70.0, Color("#cfc6b8"), Color(Palette.INK, 0.6))
		5:
			_alley(ci, w, h, g)
		6:
			_sky_bands(ci, w, h, g, [Color("#2b2521"), Color("#4a3f37"), Color("#7a6a5a"), Color("#b3a28a")], 6)
			_piazza(ci, w, h, g)
		_:
			_sky_bands(ci, w, h, g, [Palette.NIGHT, Palette.RED_DEEP, Palette.RED, Palette.EMBER], 7)
			_dusk_sun(ci, w, g)
			_rooftops(ci, w, g - 60.0, 7)
			_street(ci, w, h, g - 70.0, Color("#1e1512"), Color(Palette.EMBER, 0.35))
	WoodcutDraw.end()


static func paint_front(ci: CanvasItem, stop: int, w: float, h: float, g: float) -> void:
	WoodcutDraw.begin(ci)
	var inf := info(stop)
	var rim := Color(inf.lit, inf.crowd_rim)
	match clampi(stop, 1, COUNT):
		1:
			_hearth_front(ci, w, g)
		2:
			_logs(ci, Vector2(w * 0.62, g - 66.0), 240.0)
			_crowd(ci, -10.0, w * 0.4, g - 40.0, 95.0, Color("#1a1411"), rim, 201, 1.0)
			_crowd(ci, w * 0.86, w + 10.0, g - 40.0, 95.0, Color("#1a1411"), rim, 202, 1.0)
		3:
			_logs(ci, Vector2(w * 0.1, g - 56.0), 100.0)
			_logs(ci, Vector2(w * 0.9, g - 62.0), 90.0)
			_logs(ci, Vector2(w * 0.6, g - 149.0), 40.0)
			_crowd(ci, w * 0.18, w * 0.42, g - 50.0, 80.0, Palette.INK, rim, 301, 0.8)
			_crowd(ci, w * 0.66, w * 0.82, g - 52.0, 80.0, Palette.INK, rim, 302, 0.8)
		4:
			_crowd(ci, -10.0, w + 10.0, g - 58.0, 80.0, Color("#2a2420"), Color(Palette.BONE, 0.5), 401, 0.7)
		5:
			# People pressed against both walls of the lane, thickest near the viewer.
			_crowd(ci, w * 0.12, w * 0.3, g - 96.0, 58.0, Color("#3a322c"), rim, 501, 1.2)
			_crowd(ci, w * 0.42, w * 0.56, g - 98.0, 56.0, Color("#3a322c"), rim, 502, 1.2)
			_crowd(ci, -30.0, w * 0.08, g - 30.0, 120.0, Color("#1c1714"), rim, 503, 1.1)
			_crowd(ci, w * 0.7, w + 20.0, g - 26.0, 124.0, Color("#1c1714"), rim, 504, 1.1)
		6:
			_crowd(ci, -10.0, w * 0.3, g - 50.0, 86.0, Palette.INK, rim, 601, 0.9)
			_crowd(ci, w * 0.7, w + 10.0, g - 50.0, 86.0, Palette.INK, rim, 602, 0.9)
		_:
			_logs(ci, Vector2(w * 0.08, g - 94.0), 60.0)
			_crowd(ci, -10.0, w + 10.0, g - 52.0, 84.0, Palette.INK, rim, 701, 0.75)
	WoodcutDraw.end()


# ------------------------------------------------------------------ skies

static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _sky_night(ci: CanvasItem, w: float, h: float, salt: int) -> void:
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Palette.NIGHT)
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color(Palette.BONE, 0.035), Palette.tex("grain"), 1.0 / 700.0)
	# Horizontal cuts: the woodcut way to shade a sky, thinning toward the top.
	for i in 16:
		var y := h * 0.05 + float(i) * h * 0.028
		var x0 := WoodcutDraw.hash01(i, salt) * w * 0.5 - 40.0
		var ln := w * (0.3 + 0.5 * WoodcutDraw.hash01(i, salt + 1))
		var pts := PackedVector2Array()
		for j in 8:
			var t := float(j) / 7.0
			pts.append(Vector2(x0 + ln * t, y + sin(t * 6.0 + float(i)) * 2.0))
		WoodcutDraw.stroke(ci, pts, Color(Palette.BONE, 0.05 + 0.05 * float(i) / 16.0), 0.2, 0.2, 1.4 + float(i) * 0.08)
	# Stars: small four-point cuts.
	for i in 34:
		var p := Vector2(WoodcutDraw.hash01(i, salt + 5) * w, WoodcutDraw.hash01(i, salt + 6) * h * 0.45)
		var r := 1.2 + 2.2 * WoodcutDraw.hash01(i, salt + 7)
		var a := Color(Palette.BONE, 0.35 + 0.5 * WoodcutDraw.hash01(i, salt + 8))
		WoodcutDraw.stroke(ci, PackedVector2Array([p + Vector2(-r, 0), p + Vector2(r, 0)]), a, 0.2, 0.2, 1.1)
		WoodcutDraw.stroke(ci, PackedVector2Array([p + Vector2(0, -r), p + Vector2(0, r)]), a, 0.2, 0.2, 1.1)


static func _sky_paper(ci: CanvasItem, w: float, h: float, horizon: float) -> void:
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color.WHITE, Palette.tex("paper"), 1.0 / 512.0)
	# Winter sky: dense ink cuts at the top that thin out toward the rooftops.
	var rows := 18
	for i in rows:
		var t := float(i) / float(rows)
		var y := horizon * t * 0.95
		var width := lerpf(3.2, 0.3, t)
		# Each cut is broken into a few gouges of uneven length.
		var x := -10.0 - 30.0 * WoodcutDraw.hash01(i, 5)
		var k := 0
		while x < w + 10.0:
			var seg := 80.0 + 160.0 * WoodcutDraw.hash01(i * 17 + k, 6)
			var pts := PackedVector2Array()
			for j in 7:
				var xx := x + seg * float(j) / 6.0
				pts.append(Vector2(xx, y + sin(xx * 0.02 + float(i) * 0.9) * 3.0 + WoodcutDraw.noise1(xx * 0.05, i) * 2.0))
			WoodcutDraw.stroke(ci, pts, Color(Palette.INK, lerpf(0.75, 0.15, t)), width * 0.2, width * 0.2, width)
			x += seg + 6.0 + 20.0 * WoodcutDraw.hash01(i * 13 + k, 7) * t
			k += 1
	# A low winter cloud bank, left in white with an ink edge.
	var cloud := PackedVector2Array()
	for j in 18:
		var x := -20.0 + (w + 40.0) * float(j) / 17.0
		cloud.append(Vector2(x, horizon * 0.52 - 14.0 * WoodcutDraw.noise1(float(j) * 0.9, 4) - 6.0 * sin(float(j))))
	var band := cloud.duplicate()
	band.append(Vector2(w + 20.0, horizon * 0.72))
	band.append(Vector2(-20.0, horizon * 0.72))
	WoodcutDraw.fill(ci, band, Color(Palette.BONE, 0.95))
	WoodcutDraw.stroke(ci, cloud, Color(Palette.INK, 0.5), 0.5, 0.5, 2.2)


static func _sky_bands(ci: CanvasItem, w: float, h: float, g: float, colors: Array, salt: int) -> void:
	# Posterised sky: flat bands of ink with rough, wavy edges between them.
	var n := colors.size()
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), colors[0])
	var horizon := g - 60.0
	for i in range(1, n):
		var y0 := horizon * (0.18 + 0.82 * pow(float(i) / float(n), 0.9))
		var pts := PackedVector2Array()
		for j in 20:
			var x := -10.0 + (w + 20.0) * float(j) / 19.0
			pts.append(Vector2(x, y0 - 10.0 * WoodcutDraw.noise1(float(j) * 0.7, salt + i) + 4.0 * sin(float(j) * 1.7)))
		pts.append(Vector2(w + 10.0, h))
		pts.append(Vector2(-10.0, h))
		WoodcutDraw.fill(ci, pts, colors[i])
		# Cut lines inside each band.
		for k in 3:
			var yy := y0 + 10.0 + float(k) * 9.0
			var x0 := WoodcutDraw.hash01(i * 7 + k, salt) * w * 0.6
			var line := PackedVector2Array([Vector2(x0, yy), Vector2(x0 + w * 0.2, yy + 1.5), Vector2(x0 + w * 0.42, yy)])
			WoodcutDraw.stroke(ci, WoodcutDraw.smooth_open(line, 4), Color(colors[i - 1], 0.6), 0.3, 0.3, 2.0)
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color(Palette.INK, 0.06), Palette.tex("grain"), 1.0 / 700.0)


static func _dusk_sun(ci: CanvasItem, w: float, g: float) -> void:
	var c := Vector2(w * 0.75, g - 70.0)
	WoodcutDraw.rays(ci, c, 54.0, 210.0, 34, Color(Palette.EMBER_HOT, 0.4), 3.0, 71, PI, PI)
	var disc := WoodcutDraw.ellipse(c, Vector2(46, 46), 30)
	WoodcutDraw.fill(ci, disc, Palette.EMBER_HOT)
	for i in 4:
		var y := c.y - 30.0 + float(i) * 14.0
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(c.x - 52, y), Vector2(c.x + 52, y + 1)]), Color(Palette.EMBER, 0.9), 0.5, 0.5, 2.6)


# ------------------------------------------------------------------ buildings

## A row of stone houses standing on `base`. night: dark walls with a few lit windows and a lit edge;
## daylight (day=true): pale stone with ink outlines, shutters and balconies.
static func _houses(ci: CanvasItem, x0: float, x1: float, base: float, hmin: float, hmax: float, wall: Color, edge: Color, salt: int, lit_windows: float, day := false) -> void:
	var x := x0
	var i := 0
	while x < x1:
		var hw := 70.0 + 60.0 * WoodcutDraw.hash01(i, salt)
		var hh := lerpf(hmin, hmax, WoodcutDraw.hash01(i, salt + 1))
		var top := base - hh
		var roof := 16.0 + 10.0 * WoodcutDraw.hash01(i, salt + 2)
		var body := PackedVector2Array([Vector2(x, base), Vector2(x, top), Vector2(x + hw, top), Vector2(x + hw, base)])
		var shade := wall if i % 2 == 0 else (wall.darkened(0.08) if day else wall.lightened(0.04))
		WoodcutDraw.fill(ci, body, shade)
		if day:
			# Granite blocks: short ink cuts in courses.
			WoodcutDraw.fill(ci, body, Color(Palette.INK, 0.12), Palette.tex("chisel"), 1.0 / 180.0)
			for r in int(hh / 16.0):
				var yy := base - 8.0 - float(r) * 16.0
				var off := 0.0 if r % 2 == 0 else 14.0
				var bx := x + off
				while bx < x + hw - 6.0:
					var bw := 18.0 + 10.0 * WoodcutDraw.hash01(r * 31 + int(bx), salt + 3)
					WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(bx + 2, yy), Vector2(minf(bx + bw - 2, x + hw - 3), yy + 0.5)]), Color(Palette.INK, 0.28), 0.3, 0.3, 1.3)
					bx += bw
		if day:
			# Street front: a low tiled roof seen from below, a row of curved tile ends along the eave.
			var eave := PackedVector2Array([Vector2(x - 5, top + 3), Vector2(x + 2, top - roof * 0.6), Vector2(x + hw - 2, top - roof * 0.6), Vector2(x + hw + 5, top + 3)])
			WoodcutDraw.fill(ci, eave, Color("#3a2f28"))
			var tx := x - 2.0
			while tx < x + hw + 2.0:
				WoodcutDraw.fill(ci, WoodcutDraw.ellipse(Vector2(tx, top + 3.0), Vector2(3.2, 2.6), 8), Color("#2a211c"))
				WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(tx - 1, top - roof * 0.5), Vector2(tx - 1, top)]), Color(Palette.BONE, 0.25), 0.3, 0.3, 1.0)
				tx += 7.0
		else:
			# Tiled roof: a low gable against the sky, lit on its fire side.
			var roof_pts := PackedVector2Array([Vector2(x - 6, top + 2), Vector2(x + hw * 0.5, top - roof), Vector2(x + hw + 6, top + 2)])
			WoodcutDraw.fill(ci, roof_pts, Palette.INK)
			WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x - 6, top + 2), Vector2(x + hw * 0.5, top - roof)]), Color(edge, 0.7), 0.6, 0.6, 2.0)
		# Windows and doors.
		var floors := int(hh / 60.0)
		for f in floors:
			var wy := base - 44.0 - float(f) * 58.0
			for k in 2:
				var wx := x + hw * (0.28 + 0.44 * float(k)) - 8.0
				var lit := WoodcutDraw.hash01(i * 13 + f * 3 + k, salt + 4) < lit_windows * 0.6
				var win := _rect(wx, wy - 22.0, 16.0, 22.0)
				if day:
					WoodcutDraw.fill(ci, win, Color("#231c17"))
					WoodcutDraw.fill(ci, _rect(wx - 7.0, wy - 23.0, 6.0, 24.0), Color("#5a4636"))
					WoodcutDraw.fill(ci, _rect(wx + 17.0, wy - 23.0, 6.0, 24.0), Color("#5a4636"))
					if f == 1 and k == 0 and WoodcutDraw.hash01(i, salt + 9) > 0.4:
						# A wooden balcony.
						WoodcutDraw.fill(ci, _rect(wx - 12.0, wy + 1.0, 40.0, 4.0), Palette.INK)
						for b in 6:
							WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(wx - 10.0 + float(b) * 7.0, wy + 5.0), Vector2(wx - 10.0 + float(b) * 7.0, wy + 16.0)]), Palette.INK, 1.2, 1.2)
						WoodcutDraw.fill(ci, _rect(wx - 12.0, wy + 15.0, 40.0, 3.0), Palette.INK)
				elif lit:
					WoodcutDraw.fill(ci, win, Color(Palette.EMBER, 0.9))
					WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(wx + 8, wy - 22), Vector2(wx + 8, wy)]), Palette.INK, 1.5, 1.5)
				else:
					WoodcutDraw.fill(ci, win, Color(Palette.INK, 0.8))
		if day and WoodcutDraw.hash01(i, salt + 5) > 0.3:
			var dx := x + hw * 0.5 - 12.0
			WoodcutDraw.fill(ci, PackedVector2Array([Vector2(dx, base), Vector2(dx, base - 34.0), Vector2(dx + 12.0, base - 42.0), Vector2(dx + 24.0, base - 34.0), Vector2(dx + 24.0, base)]), Color("#3b2c21"))
		# Lit edge on the side facing the light.
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x + 1.0, top + 2.0), Vector2(x + 1.0, base)]), Color(edge, 0.35 if not day else 0.5), 1.0, 1.0, 2.0)
		x += hw + (2.0 if day else 6.0 + 20.0 * WoodcutDraw.hash01(i, salt + 6))
		i += 1


## The Rope: a narrow granite lane in steep perspective, the low sun at its far end, the right wall in
## shadow and a long shadow across the stones.
static func _alley(ci: CanvasItem, w: float, h: float, g: float) -> void:
	var vp := Vector2(w * 0.63, g - 150.0)
	# Sky strip and the far end of the lane, bright with the sun.
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color("#e9d3a8"))
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color(Palette.INK, 0.08), Palette.tex("paper"), 1.0 / 512.0)
	WoodcutDraw.glow(ci, vp + Vector2(0, -60), 260.0, Color(Palette.EMBER_HOT, 0.8), 0.8)
	WoodcutDraw.rays(ci, vp + Vector2(0, -70), 50.0, 260.0, 26, Color(Palette.BONE, 0.55), 2.4, 51, PI * 1.1, PI * 0.95)
	# Far houses closing the lane.
	_houses(ci, vp.x - 90.0, vp.x + 90.0, vp.y + 36.0, 70.0, 110.0, Color("#cdb994"), Palette.INK, 55, 0.0, true)
	# Street: the stones run toward the far end.
	var street := PackedVector2Array([Vector2(vp.x - 80.0, vp.y + 36.0), Vector2(vp.x + 80.0, vp.y + 36.0), Vector2(w + 40.0, h), Vector2(-40.0, h)])
	WoodcutDraw.fill(ci, street, Color("#cdbfa6"))
	for i in 26:
		var t := pow(float(i) / 25.0, 1.8)
		var y := lerpf(vp.y + 38.0, h, t)
		var half := lerpf(80.0, w * 0.75, t)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(vp.x - half, y), Vector2(vp.x + half, y + 1.0)]), Color(Palette.INK, 0.25 + 0.2 * t), 0.4, 0.4, 0.6 + 1.6 * t)
	for i in 11:
		var x := lerpf(-w * 0.3, w * 1.3, float(i) / 10.0)
		WoodcutDraw.stroke(ci, PackedVector2Array([vp + Vector2((x - vp.x) * 0.13, 38.0), Vector2(x, h)]), Color(Palette.INK, 0.18), 0.3, 1.2)
	# The long shadow of the right-hand houses across the street.
	WoodcutDraw.fill(ci, PackedVector2Array([Vector2(vp.x + 30.0, vp.y + 36.0), Vector2(vp.x + 80.0, vp.y + 36.0), Vector2(w + 40.0, h), Vector2(w * 0.38, h)]),
		Color(Palette.INK, 0.28), Palette.tex("hatch"), 1.0 / 90.0)
	# Left wall, in the sun: granite courses running to the vanishing point, doors and windows.
	var lw := PackedVector2Array([Vector2(-10, -10), Vector2(vp.x - 90.0, vp.y - 120.0), Vector2(vp.x - 90.0, vp.y + 36.0), Vector2(-10, g + 30.0)])
	WoodcutDraw.fill(ci, lw, Color("#d6c4a2"))
	WoodcutDraw.fill(ci, lw, Color(Palette.INK, 0.14), Palette.tex("chisel"), 1.0 / 160.0)
	_wall_courses(ci, Vector2(-10, -10), Vector2(-10, g + 30.0), Vector2(vp.x - 90.0, vp.y - 120.0), Vector2(vp.x - 90.0, vp.y + 36.0), 14, Color(Palette.INK, 0.3), 57)
	_wall_openings(ci, Vector2(-10, -10), Vector2(-10, g + 30.0), Vector2(vp.x - 90.0, vp.y - 120.0), Vector2(vp.x - 90.0, vp.y + 36.0), Color("#2a211b"), 58)
	# Right wall, in shadow, hatched.
	var rw := PackedVector2Array([Vector2(w + 10, -10), Vector2(vp.x + 90.0, vp.y - 110.0), Vector2(vp.x + 90.0, vp.y + 36.0), Vector2(w + 10, g + 30.0)])
	WoodcutDraw.fill(ci, rw, Color("#7a6c5c"))
	WoodcutDraw.fill(ci, rw, Color(Palette.INK, 0.4), Palette.tex("hatch"), 1.0 / 110.0)
	_wall_courses(ci, Vector2(w + 10, -10), Vector2(w + 10, g + 30.0), Vector2(vp.x + 90.0, vp.y - 110.0), Vector2(vp.x + 90.0, vp.y + 36.0), 14, Color(Palette.INK, 0.35), 59)
	_wall_openings(ci, Vector2(w + 10, -10), Vector2(w + 10, g + 30.0), Vector2(vp.x + 90.0, vp.y - 110.0), Vector2(vp.x + 90.0, vp.y + 36.0), Color("#1a1512"), 60)
	# Eaves against the sky strip.
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(-10, -4), Vector2(vp.x - 90.0, vp.y - 124.0)]), Color("#2a211c"), 14.0, 4.0)
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(w + 10, -4), Vector2(vp.x + 90.0, vp.y - 114.0)]), Color("#2a211c"), 14.0, 4.0)


## Stone courses on a wall seen in perspective: lines from the near edge (a0..a1) to the far edge (b0..b1).
static func _wall_courses(ci: CanvasItem, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, rows: int, col: Color, salt: int) -> void:
	for i in rows:
		var t := (float(i) + 0.5) / float(rows)
		var p := a0.lerp(a1, t)
		var q := b0.lerp(b1, t)
		var cut := 0.1 + 0.3 * WoodcutDraw.hash01(i, salt)
		WoodcutDraw.stroke(ci, PackedVector2Array([p.lerp(q, cut), q]), col, 1.6, 0.3)


## Doors and windows on a wall seen in perspective (fractions along the wall are foreshortened).
static func _wall_openings(ci: CanvasItem, a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, col: Color, salt: int) -> void:
	var at := func(u: float, v: float) -> Vector2:
		# u along the wall (0 near .. 1 far, foreshortened), v down the wall (0 top .. 1 ground).
		var uu := 1.0 - pow(1.0 - u, 2.2)
		return a0.lerp(b0, uu).lerp(a1.lerp(b1, uu), v)
	for k in 5:
		var u0 := 0.08 + 0.2 * float(k)
		var u1 := u0 + 0.07
		# A window up high with its shutter, and every other bay a door at the street.
		for q in [[0.3, 0.45], [0.58, 0.72]]:
			var win := PackedVector2Array([at.call(u0, q[0]), at.call(u1, q[0]), at.call(u1, q[1]), at.call(u0, q[1])])
			WoodcutDraw.fill(ci, win, col)
		if k % 2 == int(WoodcutDraw.hash01(k, salt) * 2.0):
			var door := PackedVector2Array([at.call(u0, 0.78), at.call(u1 + 0.02, 0.78), at.call(u1 + 0.02, 1.0), at.call(u0, 1.0)])
			WoodcutDraw.fill(ci, door, col)


static func _street(ci: CanvasItem, w: float, h: float, y0: float, fill: Color, line: Color) -> void:
	WoodcutDraw.fill(ci, _rect(0, y0, w, h - y0), fill)
	# Cobbles: rows of rough stones, bigger toward the viewer.
	var y := y0 + 6.0
	var row := 0
	while y < h + 10.0:
		var sz := 10.0 + (y - y0) * 0.16
		var x := -sz + (sz * 0.5 if row % 2 == 1 else 0.0)
		var k := 0
		while x < w + sz:
			var r := Vector2(sz * (0.42 + 0.1 * WoodcutDraw.hash01(k + row * 50, 31)), sz * 0.24)
			var stone := WoodcutDraw.ellipse(Vector2(x, y), r, 9, (WoodcutDraw.hash01(k, row) - 0.5) * 0.3)
			WoodcutDraw.stroke(ci, WoodcutDraw.smooth_open(PackedVector2Array([stone[4], stone[6], stone[8], stone[0], stone[1]]), 2), line, 0.4, 0.4, 1.0 + sz * 0.05)
			x += sz * (0.95 + 0.1 * WoodcutDraw.hash01(k, 33))
			k += 1
		y += sz * 0.52
		row += 1


static func _hill_village(ci: CanvasItem, w: float, h: float, g: float) -> void:
	# The hill: a dark slope rising to the right with houses stepping up it.
	var hill := PackedVector2Array([Vector2(-10, g - 90), Vector2(w * 0.3, g - 140), Vector2(w * 0.62, g - 200), Vector2(w * 0.85, g - 230), Vector2(w + 10, g - 236), Vector2(w + 10, h), Vector2(-10, h)])
	WoodcutDraw.fill(ci, hill, Color("#120e0c"))
	for i in 9:
		var t := float(i) / 8.0
		var bx := lerpf(w * 0.08, w * 0.94, t)
		var by := g - 92.0 - 140.0 * pow(t, 1.1)
		_houses(ci, bx, bx + 50.0, by, 34.0 + 20.0 * WoodcutDraw.hash01(i, 3), 60.0, Color("#0c0908"), Palette.EMBER, 30 + i, 0.8)
	# The church tower on the hilltop.
	var tx := w * 0.8
	var ty := g - 228.0
	WoodcutDraw.fill(ci, _rect(tx, ty - 90.0, 24.0, 90.0), Color("#0b0908"))
	WoodcutDraw.fill(ci, PackedVector2Array([Vector2(tx - 3, ty - 90), Vector2(tx + 12, ty - 112), Vector2(tx + 27, ty - 90)]), Color("#0b0908"))
	WoodcutDraw.fill(ci, _rect(tx + 8.0, ty - 80.0, 8.0, 12.0), Color(Palette.EMBER, 0.5))
	# Distant fires dotting the hill.
	for i in 6:
		var t := WoodcutDraw.hash01(i, 77)
		var p := Vector2(lerpf(w * 0.15, w * 0.95, t), g - 100.0 - 130.0 * t - 10.0 * WoodcutDraw.hash01(i, 78))
		WoodcutDraw.glow(ci, p, 26.0, Color(Palette.EMBER, 0.6))
		WoodcutDraw.fill(ci, PackedVector2Array([p + Vector2(-4, 2), p + Vector2(0, -9), p + Vector2(4, 2)]), Palette.EMBER_HOT)


static func _piazza(ci: CanvasItem, w: float, h: float, g: float) -> void:
	var stone := Color("#2e2723")
	var line := Color(Palette.BONE, 0.3)
	# Houses closing the square on the right.
	_houses(ci, w * 0.62, w + 20.0, g - 64.0, 130.0, 190.0, Color("#231d19"), Palette.EMBER, 61, 0.7)
	# The church front: a plain stone facade with a gable, a round window and an arched door.
	var cx := w * 0.3
	var base := g - 64.0
	var fw := 190.0
	var fh := 190.0
	var facade := PackedVector2Array([Vector2(cx - fw * 0.5, base), Vector2(cx - fw * 0.5, base - fh), Vector2(cx, base - fh - 56.0), Vector2(cx + fw * 0.5, base - fh), Vector2(cx + fw * 0.5, base)])
	WoodcutDraw.fill(ci, facade, stone)
	WoodcutDraw.fill(ci, facade, Color(Palette.BONE, 0.08), Palette.tex("chisel"), 1.0 / 200.0)
	WoodcutDraw.outline(ci, facade, Color(Palette.INK, 0.9), 2.5, 61)
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(cx - fw * 0.5 - 4, base - fh), Vector2(cx, base - fh - 56.0)]), Color(Palette.EMBER, 0.5), 1.0, 1.0, 3.0)
	for side in [-1.0, 1.0]:
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(cx + side * fw * 0.38, base), Vector2(cx + side * fw * 0.38, base - fh + 4.0)]), line, 1.0, 1.0, 2.0)
	var rose := WoodcutDraw.ellipse(Vector2(cx, base - fh + 20.0), Vector2(20, 20), 24)
	WoodcutDraw.fill(ci, rose, Palette.INK)
	WoodcutDraw.rays(ci, Vector2(cx, base - fh + 20.0), 3.0, 17.0, 10, Color(Palette.EMBER, 0.7), 2.0, 62)
	var door := PackedVector2Array([Vector2(cx - 26, base), Vector2(cx - 26, base - 70)])
	door.append_array(WoodcutDraw.quad(Vector2(cx - 26, base - 70), Vector2(cx, base - 104), Vector2(cx + 26, base - 70), 8))
	door.append(Vector2(cx + 26, base))
	WoodcutDraw.fill(ci, door, Color("#140f0c"))
	WoodcutDraw.stroke(ci, WoodcutDraw.quad(Vector2(cx - 32, base - 70), Vector2(cx, base - 110), Vector2(cx + 32, base - 70), 8), line, 1.0, 1.0, 3.0)
	# The bell tower beside it.
	var tx := cx + fw * 0.5 + 6.0
	var tw := 54.0
	var th := 300.0
	var tower := _rect(tx, base - th, tw, th)
	WoodcutDraw.fill(ci, tower, stone.darkened(0.1))
	WoodcutDraw.fill(ci, tower, Color(Palette.BONE, 0.07), Palette.tex("chisel"), 1.0 / 200.0)
	WoodcutDraw.outline(ci, tower, Color(Palette.INK, 0.9), 2.5, 63)
	for f in 3:
		var y := base - 80.0 * float(f + 1)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(tx, y), Vector2(tx + tw, y)]), line, 1.0, 1.0, 2.0)
	var bell_open := PackedVector2Array([Vector2(tx + 14, base - th + 60), Vector2(tx + 14, base - th + 34)])
	bell_open.append_array(WoodcutDraw.quad(Vector2(tx + 14, base - th + 34), Vector2(tx + 27, base - th + 18), Vector2(tx + 40, base - th + 34), 6))
	bell_open.append(Vector2(tx + 40, base - th + 60))
	WoodcutDraw.fill(ci, bell_open, Palette.INK)
	Figures.cowbell(ci, Vector2(tx + 27, base - th + 44), 13.0, 0.0, Palette.EMBER, 0)
	WoodcutDraw.fill(ci, PackedVector2Array([Vector2(tx - 4, base - th), Vector2(tx + tw * 0.5, base - th - 44), Vector2(tx + tw + 4, base - th)]), Palette.INK)
	# Lamps on the walls.
	for p in [Vector2(cx - fw * 0.5 - 16, base - 90), Vector2(w * 0.7, base - 100), Vector2(w * 0.92, base - 96)]:
		WoodcutDraw.glow(ci, p, 60.0, Color(Palette.EMBER, 0.5))
		WoodcutDraw.fill(ci, WoodcutDraw.ellipse(p, Vector2(5, 7), 8), Palette.EMBER_HOT)
	# Paving: big flagstones in the square.
	WoodcutDraw.fill(ci, _rect(0, base, w, h - base), Color("#26201c"))
	var y := base + 8.0
	var row := 0
	while y < h:
		var step := 12.0 + (y - base) * 0.2
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y + 2.0)]), Color(Palette.BONE, 0.14), 0.6, 0.6, 1.4)
		var x := (step * 1.4 if row % 2 == 0 else 0.0)
		while x < w:
			WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x, y), Vector2(x - 2.0, y + step)]), Color(Palette.BONE, 0.1), 0.5, 0.5, 1.2)
			x += step * 2.8
		y += step
		row += 1


static func _rooftops(ci: CanvasItem, w: float, base: float, salt: int) -> void:
	var x := -20.0
	var i := 0
	var sil := Color("#120d0c")
	while x < w + 20.0:
		var hw := 60.0 + 70.0 * WoodcutDraw.hash01(i, salt)
		var hh := 80.0 + 110.0 * WoodcutDraw.hash01(i, salt + 1)
		var pts := PackedVector2Array([Vector2(x, base + 10), Vector2(x, base - hh), Vector2(x + hw * 0.5, base - hh - 22.0), Vector2(x + hw, base - hh), Vector2(x + hw, base + 10)])
		WoodcutDraw.fill(ci, pts, sil)
		if WoodcutDraw.hash01(i, salt + 2) > 0.5:
			# Chimney with a wisp of smoke.
			var cxp := x + hw * 0.7
			WoodcutDraw.fill(ci, _rect(cxp, base - hh - 26.0, 9.0, 20.0), sil)
			WoodcutDraw.stroke(ci, WoodcutDraw.smooth_open(PackedVector2Array([Vector2(cxp + 4, base - hh - 28), Vector2(cxp + 12, base - hh - 50), Vector2(cxp + 2, base - hh - 70), Vector2(cxp + 14, base - hh - 92)]), 4), Color(Palette.BONE, 0.2), 1.0, 0.2, 4.0)
		for k in 2:
			if WoodcutDraw.hash01(i * 5 + k, salt + 3) > 0.55:
				WoodcutDraw.fill(ci, _rect(x + hw * (0.25 + 0.35 * float(k)), base - hh * 0.55, 12.0, 16.0), Color(Palette.EMBER, 0.85))
		x += hw
		i += 1


# ------------------------------------------------------------------ the workshop

static func _workshop(ci: CanvasItem, w: float, h: float, g: float) -> void:
	# Plank wall.
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Palette.WOOD)
	WoodcutDraw.fill(ci, _rect(0, 0, w, h), Color(Palette.BONE, 0.08), Palette.tex("grain"), 1.0 / 300.0)
	var x := 0.0
	var i := 0
	while x < w:
		var pw := 44.0 + 14.0 * WoodcutDraw.hash01(i, 1)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x, 0), Vector2(x + 1.0, g)]), Color(Palette.INK, 0.85), 2.0, 2.0, 3.0)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x + 4.0, 0), Vector2(x + 5.0, g)]), Color(Palette.BONE, 0.08), 0.8, 0.8, 1.2)
		x += pw
		i += 1
	# Darkness gathers at the top of the room.
	WoodcutDraw.fill(ci, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, g * 0.35), Vector2(0, g * 0.22)]), Color(Palette.INK, 0.55))
	# A shelf with carved masks hanging on nails, and more bells.
	var shelf_y := g - 250.0
	WoodcutDraw.fill(ci, _rect(w * 0.2, shelf_y, w * 0.75, 9.0), Color("#3a2c22"))
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(w * 0.2, shelf_y), Vector2(w * 0.95, shelf_y)]), Color(Palette.EMBER, 0.45), 1.0, 1.0, 2.0)
	var specs := [
		{"brow": "furrowed", "eyes": "drooping", "nose": "long", "cheeks": "hollow", "mouth": "downturned", "finish": "smoked", "patina": "worn"},
		{"brow": "heavy", "eyes": "round", "nose": "hooked", "cheeks": "full", "mouth": "closed", "finish": "soot_black", "patina": "old"},
		{"brow": "knotted", "eyes": "almond", "nose": "broad", "cheeks": "creased", "mouth": "grimace", "finish": "dark_walnut", "patina": "ancient"},
		{"brow": "lined", "eyes": "narrow", "nose": "aquiline", "cheeks": "high", "mouth": "open", "finish": "charred", "patina": "worn"},
	]
	for k in specs.size():
		var p := Vector2(w * (0.3 + 0.17 * float(k)), shelf_y + 52.0)
		WoodcutDraw.fill(ci, WoodcutDraw.ellipse(p + Vector2(0, -44), Vector2(2.5, 2.5), 6), Palette.BONE_DIM)
		WoodcutDraw.stroke(ci, PackedVector2Array([p + Vector2(0, -44), p + Vector2(-12, -34)]), Color("#6b4a2e"), 1.5, 1.5)
		WoodcutDraw.stroke(ci, PackedVector2Array([p + Vector2(0, -44), p + Vector2(12, -34)]), Color("#6b4a2e"), 1.5, 1.5)
		MaskView.paint(ci, p, 20.0, specs[k], 1, false)
	# Bells hanging on nails on the left wall.
	for k in 4:
		var p := Vector2(w * 0.05 + float(k) * 20.0, g - 300.0 + float(k % 2) * 16.0)
		WoodcutDraw.stroke(ci, PackedVector2Array([p + Vector2(0, -26), p + Vector2(0, -10)]), Color("#4a3322"), 1.6, 1.6)
		Figures.cowbell(ci, p, 20.0 - float(k) * 1.5, 0.0, Palette.EMBER, 1)
	# A sheepskin drying on a peg.
	var skin := WoodcutDraw.rough(WoodcutDraw.smooth_closed(PackedVector2Array([Vector2(w * 0.12, g - 220), Vector2(w * 0.2, g - 226), Vector2(w * 0.23, g - 150),
		Vector2(w * 0.18, g - 118), Vector2(w * 0.1, g - 122), Vector2(w * 0.08, g - 170)]), 3), 3.0, 5, 6.0)
	WoodcutDraw.fill(ci, skin, Palette.fleece("black"))
	WoodcutDraw.fill(ci, skin, Color(Palette.EMBER, 0.25), Palette.tex("fleece"), 1.0 / 110.0)
	# The workbench at the back with gouges on it.
	var by := g - 104.0
	WoodcutDraw.fill(ci, _rect(w * 0.5, by, w * 0.5, 12.0), Color("#3b2b20"))
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(w * 0.5, by), Vector2(w, by)]), Color(Palette.EMBER, 0.55), 1.0, 1.0, 2.2)
	for k in 5:
		var gx := w * 0.56 + float(k) * 26.0
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(gx, by - 2), Vector2(gx + 18, by - 6)]), Color("#6d4b30"), 4.0, 3.0)
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(gx + 18, by - 6), Vector2(gx + 34, by - 9)]), Color(Palette.BONE_DIM, 0.8), 1.5, 0.8)
	# A mask blank on the bench, half carved.
	MaskView.paint(ci, Vector2(w * 0.86, by - 30.0), 12.0, {"finish": "dark_walnut", "patina": "fresh"}, 1, false)
	for k in 6:
		var cx := w * 0.62 + WoodcutDraw.hash01(k, 91) * w * 0.3
		WoodcutDraw.stroke(ci, WoodcutDraw.quad(Vector2(cx, by - 1), Vector2(cx + 4, by - 6), Vector2(cx + 8, by - 1), 4), Color(Palette.EMBER_HOT, 0.6), 1.2, 0.3, 1.8)
	# The stone hearth on the left, its opening dark.
	var hx := w * 0.1
	var arch := PackedVector2Array([Vector2(hx - 70, g - 10), Vector2(hx - 70, g - 120), Vector2(hx + 70, g - 120), Vector2(hx + 70, g - 10)])
	WoodcutDraw.fill(ci, arch, Color("#2c2521"))
	WoodcutDraw.fill(ci, arch, Color(Palette.BONE, 0.1), Palette.tex("chisel"), 1.0 / 160.0)
	var mouth := PackedVector2Array([Vector2(hx - 48, g - 10), Vector2(hx - 48, g - 70)])
	mouth.append_array(WoodcutDraw.quad(Vector2(hx - 48, g - 70), Vector2(hx, g - 118), Vector2(hx + 48, g - 70), 8))
	mouth.append(Vector2(hx + 48, g - 10))
	WoodcutDraw.fill(ci, mouth, Palette.INK)
	# Floorboards.
	WoodcutDraw.fill(ci, _rect(0, g - 16.0, w, h - g + 16.0), Color("#2a2019"))
	WoodcutDraw.fill(ci, _rect(0, g - 16.0, w, h - g + 16.0), Color(Palette.BONE, 0.07), Palette.tex("grain"), 1.0 / 260.0)
	var y := g - 10.0
	var k := 0
	while y < h:
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(0, y), Vector2(w, y + 1.0)]), Color(Palette.INK, 0.9), 1.2, 1.2, 2.0)
		y += 10.0 + float(k) * 4.0
		k += 1


static func _hearth_front(ci: CanvasItem, w: float, g: float) -> void:
	var hx := w * 0.1
	# Andirons and a log across the fire.
	_logs(ci, Vector2(hx, g - 16.0), 70.0)
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(hx - 74, g - 122), Vector2(hx + 74, g - 122)]), Color("#3b2f28"), 10.0, 10.0)


## A pile of crossed logs at the base of a bonfire.
static func _logs(ci: CanvasItem, c: Vector2, width: float) -> void:
	var n := maxi(3, int(width / 28.0))
	for i in n:
		var t := float(i) / float(n - 1) - 0.5
		var a := Vector2(c.x + t * width, c.y + 4.0)
		var b := Vector2(c.x - t * width * 0.25, c.y - width * 0.28)
		WoodcutDraw.stroke(ci, PackedVector2Array([a, b]), Color("#1a120e"), width * 0.08, width * 0.06)
		WoodcutDraw.stroke(ci, PackedVector2Array([a.lerp(b, 0.1), a.lerp(b, 0.7)]), Color(Palette.EMBER, 0.55), width * 0.015, 0.0, width * 0.025)
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(c.x - width * 0.55, c.y + 6.0), Vector2(c.x + width * 0.55, c.y + 2.0)]), Color("#140e0b"), width * 0.1, width * 0.09)


## A row of onlookers from x0 to x1 standing on y, about `ph` tall, `density` 0..1.
static func _crowd(ci: CanvasItem, x0: float, x1: float, y: float, ph: float, fill: Color, rim: Color, salt: int, density: float) -> void:
	var step := ph * 0.36 / maxf(density, 0.2)
	var x := x0
	var i := 0
	while x < x1:
		var hh := ph * (0.82 + 0.3 * WoodcutDraw.hash01(i, salt))
		var dy := (WoodcutDraw.hash01(i, salt + 1) - 0.5) * 8.0
		var kind := int(WoodcutDraw.hash01(i, salt + 2) * 4.0)
		WoodcutDraw.set_transform(ci, Vector2(x, y + dy))
		Figures.crowd_person(ci, hh, kind, fill if i % 3 != 0 else fill.lightened(0.05), rim, salt + i)
		x += step * (0.7 + 0.6 * WoodcutDraw.hash01(i, salt + 3))
		i += 1
	WoodcutDraw.set_transform(ci, Vector2.ZERO)
