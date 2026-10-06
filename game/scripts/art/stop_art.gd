class_name StopArt
extends RefCounted
## The seven stop cards (docs/design.md section 5): each stop's pixel-art world cropped to its card,
## with its figures, as one still PNG (StopCells.CARD art pixels, drawn x3 on the base screen with
## nearest filtering). Baked by tools/art/pixel/stops.py into res://art/px/stops/stop_<n>.png. For the
## living picture (flames, sparks, jumping figures) use a StopPicture instead.

const SIZE := StopCells.CARD

static var _cache := {}


static func card(n: int) -> Texture2D:
	n = clampi(n, 1, StopBackdrops.COUNT)
	if _cache.has(n):
		return _cache[n]
	var tex := StopBackdrops.tex("stop_%d" % n)
	if tex == null:
		tex = StopBackdrops.tex("stop_%d_bg" % n)
	if tex == null:
		tex = Palette.tex("paper")
	_cache[n] = tex
	return tex


## What each card shows (for alt text and the credits); plain description, not lore.
static func caption(n: int) -> String:
	return StopBackdrops.NAMES[clampi(n, 1, StopBackdrops.COUNT) - 1]
