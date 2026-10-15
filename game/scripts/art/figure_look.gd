class_name FigureLook
extends RefCounted
## The player's look (Profile.get_look(): the carved mask, the fleece, the straps) on the play
## screen's pixel Mamuthone (PixelFigure), the same figure the workshop shows on its stage.
##
## The fleece and the straps are baked recolourings of the finished picture
## (tools/art/pixel3d/bake_looks.py: art/pixel/looks/mamuthone_<piece>_<fleece>[_<straps>].png), so a
## choice costs a texture swap. The carving is laid into the head's painted 3/4 face once per look
## (carve(): the painted face stays; the carved forms lighten and darken its own steps; the finish
## swaps its ramp): a few ms, cached, and never during a song (the play screen puts the look on while
## it builds).
##
##   FigureLook.texture(piece, look) -> Texture2D     piece "body", "head", "front_bells", "back_bells"
##   FigureLook.normalize(look) -> {mask, fleece, straps}   a valid look (defaults filled in)

const BASE := "res://art/pixel/"
const CACHE_MAX := 12

static var _cache := {}
static var _order: Array = []
static var _face: Image


static func normalize(look: Dictionary) -> Dictionary:
	var fl := str(look.get("fleece", MaskSpec.DEFAULT_FLEECE))
	var st := str(look.get("straps", MaskSpec.STRAPS[0]))
	return {
		"mask": MaskSpec.sanitize(look.get("mask", {})),
		"fleece": fl if fl in MaskSpec.FLEECES else MaskSpec.DEFAULT_FLEECE,
		"straps": st if st in MaskSpec.STRAPS else MaskSpec.STRAPS[0],
	}


## The Mamuthone's piece `piece` wearing `look`. Falls back to the plain picture when a baked
## variant is missing.
static func texture(piece: String, look: Dictionary) -> Texture2D:
	var lk := normalize(look)
	var fl: String = lk.fleece
	var st: String = lk.straps
	match piece:
		"body":
			return _load(FigureLookCells.DIR + "mamuthone_body_%s_%s.png" % [fl, st], piece)
		"front_bells":
			return _load(FigureLookCells.DIR + "mamuthone_front_bells_%s.png" % st, piece)
		"head":
			var key := "head|%s|%s|%s" % [fl, st, str(lk.mask)]
			if _cache.has(key):
				return _cache[key]
			var t := _load(FigureLookCells.DIR + "mamuthone_head_%s_%s.png" % [fl, st], piece)
			var img := t.get_image() if t != null else null
			if img == null:
				return t
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			carve(img, lk.mask)
			var tex := ImageTexture.create_from_image(img)
			_cache[key] = tex
			_order.append(key)
			if _order.size() > CACHE_MAX:
				_cache.erase(_order.pop_front())
			return tex
	return _load(BASE + "mamuthone_%s.png" % piece, piece)


## The painted face's own ramp, shadow to firelit (its eight warm greys), and the same eight steps
## for each wood finish: a finish is a ramp swap, so the painted light and the carving stay. Warm all
## through (no navy blacks: those read as a hole in the firelit figure).
const FINISH_RAMPS := {
	"soot_black": ["#0a080b", "#100d0e", "#171314", "#1e1b1c", "#262122", "#2f2929", "#3c3230", "#4b3e39"],
	"smoked": ["#110c0b", "#191311", "#221a17", "#2c221e", "#372a25", "#44342d", "#544037", "#664e42"],
	"dark_walnut": ["#100907", "#180e0a", "#22140d", "#2d1a11", "#3a2115", "#482a1a", "#583420", "#6b4028"],
	"charred": ["#070505", "#0b0808", "#100c0b", "#15100f", "#1c1614", "#251d1a", "#30251f", "#3e2f27"],
}
## The painted face's colours, darkest first (FINISH_RAMPS index).
const PAINTED := [Color8(10, 8, 11), Color8(16, 13, 14), Color8(23, 19, 20), Color8(30, 27, 28),
	Color8(38, 33, 34), Color8(47, 41, 41), Color8(60, 50, 48), Color8(75, 62, 57)]
const DELTA_GAIN := 1.2     ## painted steps per MaskPixels light step
const DELTA_MIN := 0.6      ## smaller differences (grain, dither) are left as painted
const HOLE := -1.5          ## a hole cut through, as a light step

static var _painted_idx := {}


## Carves the mask `spec` into the painted 3/4 face of a head image (the figure's 172-px canvas). The
## painted face stays the base: what the spec carves differently from the default mask (MaskPixels,
## both rendered in one finish) is read through the face's own landmarks (the nose's column, the rows
## of brow, eyes, mouth and chin: FigureLookCells), so the far side of the face takes it narrower,
## and lightens or darkens the painted pixel by as many of its own steps; then the finish swaps the
## eight steps for its own. The default mask in soot black is the picture exactly as painted.
static func carve(img: Image, spec: Dictionary) -> void:
	var face := _face_mask()
	if face == null:
		return
	var m := MaskSpec.sanitize(spec)
	var finish: String = m.finish
	# the forms only: the finish is the ramp swap, and the patina's wear is too fine for 172 px
	var a_spec := m.duplicate()
	a_spec.finish = "soot_black"
	a_spec.patina = "fresh"
	var unit := FigureLookCells.MASK_UNIT
	var la := _levels(MaskPixels.render(a_spec, unit, false))
	var lb := _levels(MaskPixels.render(MaskSpec.default(), unit, false))
	var msz := MaskPixels.size_for(unit)
	var ramp: Array = FINISH_RAMPS.get(finish, FINISH_RAMPS.soot_black)
	if _painted_idx.is_empty():
		for i in PAINTED.size():
			_painted_idx[(PAINTED[i] as Color).to_rgba32()] = i
	var r := FigureLookCells.FACE
	for y in range(r.position.y, r.end.y):
		var x0 := -1
		var x1 := -1
		for x in range(r.position.x, r.end.x):
			if face.get_pixel(x, y).a > 0.5:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 < 0:
			continue
		var v0 := _row_v(float(y))
		var v1 := _row_v(float(y) + 1.0)
		var hw := maxf(MaskPixels.half_width((v0 + v1) * 0.5, m.cheeks), 0.2)
		for x in range(x0, x1 + 1):
			var c := img.get_pixel(x, y)
			var key := Color(c.r, c.g, c.b, 1.0).to_rgba32()
			# the face's own step (a stray warm pixel from the hood is left as painted)
			if not _painted_idx.has(key):
				continue
			var p: int = _painted_idx[key]
			# this face pixel's footprint on the mask (u from the nose, each side to its own edge)
			var ua := _col_u(float(x), float(x0), float(x1) + 1.0) * hw
			var ub := _col_u(float(x) + 1.0, float(x0), float(x1) + 1.0) * hw
			var d := _footprint_delta(la, lb, msz, unit, ua, ub, v0, v1)
			var n := clampi(p + roundi(d * DELTA_GAIN), 0, ramp.size() - 1)
			img.set_pixel(x, y, Color(ramp[n]))


## Mask v of face row y (the painted landmarks, piecewise).
static func _row_v(y: float) -> float:
	var lm := FigureLookCells.LANDMARKS
	if y <= lm[0].y:
		return lm[0].x
	for i in lm.size() - 1:
		if y <= lm[i + 1].y:
			return lerpf(lm[i].x, lm[i + 1].x, (y - lm[i].y) / (lm[i + 1].y - lm[i].y))
	return lm[lm.size() - 1].x


## Mask u (-1 .. 1 of the half width) of face column x in a row spanning x0 .. x1: 0 on the nose.
static func _col_u(x: float, x0: float, x1: float) -> float:
	var nose := FigureLookCells.NOSE_X
	if x <= nose:
		return -clampf((nose - x) / maxf(nose - x0, 1.0), 0.0, 1.0)
	return clampf((x - nose) / maxf(x1 - nose, 1.0), 0.0, 1.0)


## The carving difference (spec minus default, in light steps) under a face pixel: the mean over its
## footprint, a cut through counting in full.
static func _footprint_delta(la: PackedFloat32Array, lb: PackedFloat32Array, msz: Vector2i, unit: float, ua: float, ub: float, v0: float, v1: float) -> float:
	var xa := int(floor((minf(ua, ub) + MaskPixels.HALF_W) * unit))
	var xb := maxi(int(ceil((maxf(ua, ub) + MaskPixels.HALF_W) * unit)), xa + 1)
	var ya := int(floor((v0 - MaskPixels.TOP) * unit))
	var yb := maxi(int(ceil((v1 - MaskPixels.TOP) * unit)), ya + 1)
	var sum := 0.0
	var n := 0
	var cut := false
	for yy in range(maxi(ya, 0), mini(yb, msz.y)):
		for xx in range(maxi(xa, 0), mini(xb, msz.x)):
			var i := yy * msz.x + xx
			if la[i] < -9.0 or lb[i] < -9.0:
				continue
			if la[i] == HOLE and lb[i] != HOLE:
				cut = true
			sum += la[i] - lb[i]
			n += 1
	if n == 0:
		return 0.0
	var d := sum / n
	if cut:
		d = minf(d, HOLE - 1.0)
	return d if absf(d) >= DELTA_MIN else 0.0


## A MaskPixels image (soot black) as light steps: 0 .. 4, HOLE for a cut, -99 off the face.
static func _levels(img: Image) -> PackedFloat32Array:
	var steps := {}
	var names := ["K1", "WOOD0", "WOOD1", "WOOD2", "WOOD3"]
	for i in names.size():
		steps[MaskPixels.col(names[i]).to_rgba32()] = float(i)
	steps[MaskPixels.col("BONE0").to_rgba32()] = 1.0
	var k0 := PixelPalette.K[0].to_rgba32()
	var out := PackedFloat32Array()
	out.resize(img.get_width() * img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var i := y * img.get_width() + x
			if c.a < 0.5:
				out[i] = -99.0
				continue
			var k := c.to_rgba32()
			out[i] = HOLE if k == k0 else float(steps.get(k, 2.0))
	return out


static func _face_mask() -> Image:
	if _face == null:
		var t := _load(FigureLookCells.DIR + "mamuthone_face.png", "")
		if t != null:
			_face = t.get_image()
			if _face != null and _face.is_compressed():
				_face.decompress()
	return _face


static func _load(path: String, piece: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if piece != "" and ResourceLoader.exists(BASE + "mamuthone_%s.png" % piece):
		return load(BASE + "mamuthone_%s.png" % piece)
	return null
