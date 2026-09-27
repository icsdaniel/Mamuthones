class_name StopArt
extends RefCounted
## Illustrations for the seven stop cards (docs/design.md section 5): a woodcut print of each moment on
## a paper mount, 640 x 400 (16:10). They are baked ahead of time by tools/art/bake.sh from the same
## drawing code as the procession, so card() just loads a small PNG (and falls back to a plain paper
## texture if a card is missing, so the UI never gets null).

const SIZE := Vector2i(640, 400)
const DIR := "res://art/cards/"

static var _cache := {}


static func card(n: int) -> Texture2D:
	n = clampi(n, 1, StopBackdrops.COUNT)
	if _cache.has(n):
		return _cache[n]
	var path := DIR + "stop_%d.png" % n
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			tex = ImageTexture.create_from_image(img)
	if tex == null:
		tex = Palette.tex("paper")
	_cache[n] = tex
	return tex


## What each card shows (for alt text and the credits); plain description, not lore.
static func caption(n: int) -> String:
	return StopBackdrops.NAMES[clampi(n, 1, StopBackdrops.COUNT) - 1]
