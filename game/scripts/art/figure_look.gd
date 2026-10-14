class_name FigureLook
extends RefCounted
## The player's look (Profile.get_look(): the carved mask, the fleece, the straps) on the play
## screen's pixel Mamuthone (PixelFigure), the same figure the workshop shows on its stage.
##
## The fleece and the straps are baked recolourings of the finished picture
## (tools/art/pixel3d/bake_looks.py: art/pixel/looks/mamuthone_<piece>_<fleece>[_<straps>].png), so a
## choice costs a texture swap. The carved mask is stamped on the head's painted face once per look
## (MaskPixels at FigureLookCells.MASK_UNIT, kept inside mamuthone_face.png): about 1 ms, cached, and
## never during a song (the play screen puts the look on while it builds).
##
##   FigureLook.texture(piece, look) -> Texture2D     piece "body", "head", "front_bells", "back_bells"
##   FigureLook.normalize(look) -> {mask, fleece, straps}   a valid look (defaults filled in)

const BASE := "res://art/pixel/"
const CACHE_MAX := 12

static var _cache := {}
static var _order: Array = []
static var _face: Image


static func normalize(look: Dictionary) -> Dictionary:
	var fl := str(look.get("fleece", MaskSpec.FLEECES[0]))
	var st := str(look.get("straps", MaskSpec.STRAPS[0]))
	return {
		"mask": MaskSpec.sanitize(look.get("mask", {})),
		"fleece": fl if fl in MaskSpec.FLEECES else MaskSpec.FLEECES[0],
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


## Stamps the carved mask `spec` on the painted face of a head image (the figure's 172-px canvas).
static func carve(img: Image, spec: Dictionary) -> void:
	var face := _face_mask()
	var m := MaskPixels.render(spec, FigureLookCells.MASK_UNIT, false)
	var at := FigureLookCells.MASK_AT
	for y in m.get_height():
		for x in m.get_width():
			var c := m.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var p := at + Vector2i(x, y)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
				continue
			if face != null and face.get_pixelv(p).a < 0.5:
				continue
			img.set_pixelv(p, c)


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
