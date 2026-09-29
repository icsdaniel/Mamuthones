class_name StopBackdrops
extends RefCounted
## The seven stops of the story (docs/design.md section 5) as pixel-art worlds of Mamoiada, drawn by
## tools/art/pixel/stops.py into res://art/px/stops/ and described in StopCells (generated). This is
## the library that draws them: StopPicture (the cards, the story map) and ProcessionScene (the
## Piazza, the workshop row, the title) both paint a world through here, so every picture of a stop is
## the same place.
##
##   1 The Workshop           the carver's room the night before: hearth, lamp, masks and bells, a mask on the bench
##   2 Sant'Antonio's Fires   the great bonfire in the street, the village on the slopes, the crowd round it
##   3 Around the Bonfires    a street climbing the hill with a fire at every corner
##   4 Carnival Sunday        a bright winter afternoon in the stone streets, the whole procession
##   5 The Rope               carnival dusk in a narrow lane, torches, the rope thrown into the crowd
##   6 The Piazza             the square before the church at night, the crowd at its thickest, braziers
##   7 Shrove Tuesday         the last procession walking out under a red dusk sky
##
## Coordinates are art pixels of the world (StopCells.WORLD, 320 x 184). Every draw_* function draws on
## a CanvasItem whose transform already scales art pixels to the screen (an integer factor), at
## `origin` (the world's top-left, in art pixels), so the pixels stay on the grid.

const COUNT := 7

const NAMES := ["The Workshop", "Sant'Antonio's Fires", "Around the Bonfires", "Carnival Sunday", "The Rope",
	"The Piazza", "Shrove Tuesday"]

## Flames switch frames at this rate (frames per second).
const FIRE_FPS := 9.0

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := StopCells.DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func data(stop: int) -> Dictionary:
	return StopCells.STOPS[clampi(stop, 1, COUNT)]


static func world_size() -> Vector2:
	return Vector2(StopCells.WORLD)


## Lighting and animated pieces for a stop (in world art pixels):
## lit: the colour of the light; sky: night|interior|day|dusk; fires: [{x (fraction of the world's
## width), y (flame base), w, h, kind}]; glow: [x fraction, y, reach, strength]; fog: [density, Color];
## sparks: bool.
static func info(stop: int) -> Dictionary:
	var d := data(stop)
	var fires := []
	for f in d.fires:
		var sz: Vector2i = StopCells.FIRES[f[2]][0]
		fires.append({"x": float(f[0]) / float(StopCells.WORLD.x), "y": float(f[1]), "w": float(sz.x), "h": float(sz.y), "kind": f[2]})
	var sky: String = d.sky
	var lit := PixelPalette.FIRE[5] if sky != "day" else PixelPalette.BONE[3]
	var glow := [0.5, 0.0, 0.0, 0.0]
	if not d.glows.is_empty():
		glow = [float(d.glows[0][0]) / float(StopCells.WORLD.x), float(d.glows[0][1]), 80.0, 0.6]
	var fog_col := PixelPalette.NIGHT[3] if sky != "dusk" else PixelPalette.RED[1]
	return {"lit": lit, "sky": sky, "fires": fires, "glow": glow, "fog": [0.3 if sky != "day" else 0.15, fog_col],
		"sparks": bool(d.sparks), "crowd_rim": 0.7}


## How the procession is staged at each stop, so no two stops show the same group:
##   x        where the row's centre stands, as a fraction of the world's width
##   front    Mamuthones in the front line (1..3; your Mamuthone is always one of them)
##   back     Mamuthones in the back line (0..3)
##   isso     Issohadores (0 none, 1 the front one, 2 both)
##   ground   the front line's feet (world art pixels)
##   depth    how far up the street the back line walks (art pixels)
##   far      true: the back line is far away (half-size figures)
##   spread   spacing multiplier
##   flip     true: the row walks to the left
##   var      "" or "dim": the front line's figure variant (dim against a bright sky)
##   scale    1 (kept for callers that size things by it)
##   shade    Color.WHITE (the variants carry the shading, the palette stays exact)
##   isso_at  optional [x fraction, ground] for the front Issohadore standing apart
##   onlooker optional [x fraction, ground]: someone in the crowd for the rope to catch
static func row(stop: int) -> Dictionary:
	var d: Dictionary = data(stop).row
	var r := {"x": 0.44, "front": 3, "back": 3, "isso": 2, "scale": 1.0, "ground": float(data(stop).ground), "depth": 14.0,
		"spread": 1.0, "flip": false, "far": false, "var": "", "shade": Color.WHITE}
	for k in d:
		r[k] = d[k]
	r.ground = float(r.ground)
	if bool(r.far):
		r.depth = 24.0
	return r


# ------------------------------------------------------------------ whole-layer painters (fallbacks, tests)

## Paints the world's back layer fitted into a w x h box, bottom-aligned (used where no pixel scene
## runs, and by the tests). `g` is ignored: the world carries its own ground line.
static func paint(ci: CanvasItem, stop: int, w: float, h: float, _g: float) -> void:
	_paint_fit(ci, stop, "bg", w, h)


static func paint_front(ci: CanvasItem, stop: int, w: float, h: float, _g: float) -> void:
	_paint_fit(ci, stop, "mid", w, h)
	_paint_fit(ci, stop, "front", w, h)


static func _paint_fit(ci: CanvasItem, stop: int, layer: String, w: float, h: float) -> void:
	var t := tex("stop_%d_%s" % [clampi(stop, 1, COUNT), layer])
	if t == null:
		return
	var ws := world_size()
	var k := maxf(1.0, floorf(minf(w / ws.x, h / ws.y)))
	var sz := ws * k
	ci.draw_texture_rect(t, Rect2(Vector2((w - sz.x) * 0.5, h - sz.y), sz), false)


# ------------------------------------------------------------------ world drawing (art pixels)

static func draw_layer(ci: CanvasItem, stop: int, layer: String, origin: Vector2, clip := Rect2()) -> void:
	if not layer in data(stop).layers:
		return
	var t := tex("stop_%d_%s" % [clampi(stop, 1, COUNT), layer])
	if t == null:
		return
	if clip.has_area():
		# Only the part inside clip (in world pixels): less overdraw for small crops.
		var c := clip.intersection(Rect2(Vector2.ZERO, world_size()))
		ci.draw_texture_rect_region(t, Rect2(origin + c.position, c.size), c)
	else:
		ci.draw_texture(t, origin)


## The flames of every fire at time t (seconds); flare 0..1 swaps in the beat's taller flame.
static func draw_fires(ci: CanvasItem, stop: int, origin: Vector2, t: float, flare := 0.0) -> void:
	var d := data(stop)
	for i in d.fires.size():
		var f: Array = d.fires[i]
		var kind: String = f[2]
		var sz: Vector2i = StopCells.FIRES[kind][0]
		var n: int = StopCells.FIRES[kind][1]
		# Each fire runs its own phase so they never flicker in lockstep.
		var frame := int(floor(t * FIRE_FPS + float(i) * 2.7)) % n
		var name := "fire_%s_%d" % [kind, frame]
		if flare > 0.5 and kind != "tiny":
			name = "fire_%s_flare%d" % [kind, int(floor(t * FIRE_FPS)) % 2]
		var tx := tex(name)
		if tx != null:
			ci.draw_texture(tx, origin + Vector2(int(f[0]) - sz.x / 2, int(f[1]) - sz.y + 1))


## Additive stepped glows round the fires. ci should draw with an additive material.
static func draw_glows(ci: CanvasItem, stop: int, origin: Vector2, strength := 1.0) -> void:
	for g in data(stop).glows:
		var tx := tex(g[2])
		if tx == null:
			continue
		var sz := tx.get_size()
		ci.draw_texture(tx, origin + Vector2(int(g[0]), int(g[1])) - (sz / 2.0).floor(), Color(1, 1, 1, clampf(strength, 0.0, 2.0)))


## Sparks rising from the big fires: single pixels, white-hot when young, cooling to ember red.
static func draw_sparks(ci: CanvasItem, stop: int, origin: Vector2, t: float, burst := 0.0, clip := Rect2()) -> void:
	var d := data(stop)
	if not bool(d.sparks):
		return
	var cols := [PixelPalette.FIRE[7], PixelPalette.FIRE[6], PixelPalette.FIRE[5], PixelPalette.FIRE[4], PixelPalette.FIRE[3]]
	for fi in d.fires.size():
		var f: Array = d.fires[fi]
		var kind: String = f[2]
		if kind == "tiny":
			continue
		var sz: Vector2i = StopCells.FIRES[kind][0]
		var n := {"big": 22, "mid": 10, "small": 4}.get(kind, 4) as int
		n += int(float(n) * 0.6 * burst)
		var base := Vector2(int(f[0]), int(f[1]) - sz.y * 0.55)
		for i in n:
			var life := 1.3 + 1.4 * WoodcutDraw.hash01(i, fi * 7 + 40)
			var u := fposmod(t / life + WoodcutDraw.hash01(i, fi * 7 + 41), 1.0)
			var spread := (WoodcutDraw.hash01(i, fi * 7 + 42) - 0.5) * float(sz.x) * 0.7
			var p := base + Vector2(spread * (0.4 + u) + sin(t * 1.7 + float(i) * 1.3) * 3.0 * u, -u * float(sz.y) * 1.3)
			var q := (origin + p).floor()
			if clip.has_area() and not clip.has_point(p):
				continue
			ci.draw_rect(Rect2(q, Vector2.ONE), cols[mini(int(u * cols.size()), cols.size() - 1)])


## Smoke drifting up from the fires: dithered puffs on the world's fixed grid, thinning as they rise.
static func draw_smoke(ci: CanvasItem, stop: int, origin: Vector2, t: float) -> void:
	var d := data(stop)
	var c0 := PixelPalette.NIGHT[4] if d.sky != "dusk" else PixelPalette.RED[1]
	var c1 := PixelPalette.HILL[2] if d.sky != "dusk" else PixelPalette.RED[0]
	for s in d.smoke:
		for i in 4:
			var u := fposmod(t / 11.0 + float(i) / 4.0, 1.0)
			var c := Vector2(float(s[0]) + sin(u * 3.0 + float(i)) * 5.0 + u * 26.0, float(s[1]) - u * 60.0)
			var r := 5.0 + u * 9.0
			var dens := 0.42 * sin(u * PI)
			for y in range(int(c.y - r), int(c.y + r) + 1):
				for x in range(int(c.x - r * 1.4), int(c.x + r * 1.4) + 1):
					var dx := (float(x) + 0.5 - c.x) / (r * 1.4)
					var dy := (float(y) + 0.5 - c.y) / r
					var dd := dx * dx + dy * dy
					if dd > 1.0:
						continue
					var th := _bayer(x, y)
					var lvl := dens * (1.0 - dd)
					if th < lvl:
						ci.draw_rect(Rect2(origin + Vector2(x, y), Vector2.ONE), c0 if th < lvl * 0.5 else c1)


const _BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func _bayer(x: int, y: int) -> float:
	return float(_BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)]) / 16.0


# ------------------------------------------------------------------ figures

## Draws a character: `sprite` is a FigureSprites name ("mamuthone_black_stand"), `variant` "" (the
## sprite as drawn), "dim" (the back line), "half"/"halfdim" (far away) or "ghost". Feet at `feet`.
static func draw_figure(ci: CanvasItem, sprite: String, variant: String, feet: Vector2, flip := false, rot := 0.0) -> void:
	if variant == "":
		FigureSprites.draw(ci, sprite, feet, 1.0, flip, Color.WHITE, rot)
		return
	var name := variant + "_" + sprite
	if not StopCells.FIGS.has(name):
		FigureSprites.draw(ci, sprite, feet, 1.0, flip, Color.WHITE, rot)
		return
	var t := tex("figs/" + name)
	if t == null:
		return
	var cell: Vector2i = StopCells.FIGS[name][0]
	var a: Vector2i = StopCells.FIGS[name][1]
	# Mirrored about the feet, the same way FigureSprites flips its sprites.
	ci.draw_set_transform(feet, rot, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect(t, Rect2(Vector2(-a.x, -a.y), Vector2(cell)), false)
	ci.draw_set_transform(Vector2.ZERO)


## Height in art pixels a figure variant stands (for placing rope targets and marks).
static func figure_height(variant: String) -> float:
	return 36.0 if variant.begins_with("half") else 70.0


## A Mamuthone sprite name with its pose swapped (for the jump cycle).
static func with_pose(sprite: String, pose: String) -> String:
	if not sprite.begins_with("mamuthone_"):
		return sprite
	var i := sprite.rfind("_")
	return sprite.substr(0, i + 1) + pose
