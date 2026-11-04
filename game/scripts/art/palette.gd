class_name Palette
extends RefCounted
## The Woodcut look (2026-11-05): every name below is now one of its five inks, black #141014, cream
## #efe6d2, vermilion #c8352a, warm grey #c9bba0 and brown #4a3c38, so whatever is drawn in code takes
## the woodcut's colours. The old names stay so every script keeps working.
##
## Formerly: the named colours code-drawn art and UI use, all taken from the one "Bonfire Night" pixel palette
## (tools/art/pixel/palette.py, mirrored as PixelPalette), plus cached loaders for the shared textures,
## the UI kit and the fonts. The old names are kept so every script keeps working: BONE is the cream of
## the menu's text, EMBER its old gold, INK the K0 outline, WOOD and NIGHT the navy of the panels.

const BLACK := Color("#141014")        ## NAVY0: the darkest ground, and ink on parchment
const BONE := Color("#efe6d2")         ## BONE3: cream text and lines
const RED := Color("#c8352a")          ## RED3: kilim red
const EMBER := Color("#c8352a")        ## GOLD4: old gold (section labels, accents, embers)

const INK := Color("#141014")          ## K0: outlines, holes and shadows
const WOOD := Color("#141014")         ## NAVY1: the navy of buttons and boards
const NIGHT := Color("#141014")        ## NIGHT0: night sky, deepest board
const BONE_DIM := Color("#c9bba0")     ## BONE2: captions, secondary text on dark
const BONE_FAINT := Color("#4a3c38")   ## BONE1: disabled text
const RED_DEEP := Color("#c8352a")     ## RED2: shaded red cloth
const EMBER_HOT := Color("#efe6d2")    ## GOLD5: the hottest gold, the white-hot heart of a fire
const ASH := Color("#4a3c38")          ## BONE1: grey for stand-stills and ash

## UI kit names (the menu reference): the gold frames, the navy panels, the cream of the labels.
const GOLD := Color("#c8352a")         ## GOLD4
const GOLD_DIM := Color("#c9bba0")     ## GOLD3
const GOLD_DEEP := Color("#4a3c38")    ## GOLD2
const GOLD_HOT := Color("#efe6d2")     ## GOLD5
const NAVY := Color("#141014")         ## NAVY1
const NAVY_DEEP := Color("#141014")    ## NAVY0
const NAVY_LIGHT := Color("#4a3c38")   ## NAVY2
const CREAM := Color("#efe6d2")        ## BONE4
const FIRE := Color("#c8352a")         ## FIRE4
const FIRE_HOT := Color("#efe6d2")     ## FIRE6

## Timing feedback, shared with the UI (UIKit.EARLY / UIKit.LATE): early is up and cool, late is down
## and warm. They also differ in lightness (early is the lighter one), and every early/late mark
## points its own way, so they stay apart in greyscale.
const EARLY := Color("#c9bba0")
const LATE := Color("#c8352a")
## The soha as it really is: natural rush or hemp. (Red is kept only for the swipe note and the logo.)
const ROPE := Color("#a88e62")         ## ROPE1
const ROPE_DARK := Color("#6e5a3e")    ## ROPE0: its twists

## Sheepskin shades and strap leathers the player can pick (Profile look values).
const FLEECE := {
	"black": Color("#171110"),
	"dark_brown": Color("#33241c"),
}
const STRAPS := {
	"natural": Color("#96582e"),
	"dark": Color("#4a2616"),
}

const TEX_DIR := "res://art/textures/"
const UI_DIR := "res://art/ui/"
const PX_DIR := "res://art/px/"

static var _cache := {}


## A shared texture from game/art/textures (paper, grain, hatch, chisel, fog, speckle).
static func tex(name: String) -> Texture2D:
	return _load(TEX_DIR + name + ".png")


## A nine-patch, ornament or icon of the pixel UI kit (game/art/ui, tools/art/pixel/ui_kit.py).
static func ui(name: String) -> Texture2D:
	return _load(UI_DIR + name + ".png")


## A pixel sprite from game/art/px ("ui/backdrop", "logo/logo").
static func px(name: String) -> Texture2D:
	return _load(PX_DIR + name + ".png")


## Small caps serif: section labels, HUD words.
static func display_font() -> Font:
	return _load("res://fonts/AlegreyaSC-Bold.ttf")


## The menu's serif (buttons, headings, the subtitle): "Bold" or "ExtraBold".
static func serif_font(weight := "Bold") -> Font:
	return _load("res://fonts/Alegreya-%s.ttf" % weight)


static func text_font(weight := "Regular") -> Font:
	return _load("res://fonts/AlegreyaSans-%s.ttf" % weight)


static func fleece(id: String) -> Color:
	return FLEECE.get(id, FLEECE["black"])


static func straps(id: String) -> Color:
	return STRAPS.get(id, STRAPS["natural"])


static func _load(path: String) -> Resource:
	if _cache.has(path):
		return _cache[path]
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	if res == null:
		# Not imported yet (e.g. a fresh checkout run without --import): read the PNG directly.
		if path.ends_with(".png") and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null:
				res = ImageTexture.create_from_image(img)
		elif path.ends_with(".ttf") and FileAccess.file_exists(path):
			var f := FontFile.new()
			f.load_dynamic_font(path)
			res = f
	_cache[path] = res
	return res
