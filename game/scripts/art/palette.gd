class_name Palette
extends RefCounted
## The named colours code-drawn art and UI use, all taken from the one "Bonfire Night" pixel palette
## (tools/art/pixel/palette.py, mirrored as PixelPalette), plus cached loaders for the shared textures,
## the UI kit and the fonts. The old names are kept so every script keeps working: BONE is the cream of
## the menu's text, EMBER its old gold, INK the K0 outline, WOOD and NIGHT the navy of the panels.

const BLACK := Color("#0b0c1c")        ## NAVY0: the darkest ground, and ink on parchment
const BONE := Color("#ecdfbc")         ## BONE3: cream text and lines
const RED := Color("#c02a22")          ## RED3: kilim red
const EMBER := Color("#e8b64c")        ## GOLD4: old gold (section labels, accents, embers)

const INK := Color("#07060e")          ## K0: outlines, holes and shadows
const WOOD := Color("#12142a")         ## NAVY1: the navy of buttons and boards
const NIGHT := Color("#0a0c24")        ## NIGHT0: night sky, deepest board
const BONE_DIM := Color("#c4b494")     ## BONE2: captions, secondary text on dark
const BONE_FAINT := Color("#8a7c6c")   ## BONE1: disabled text
const RED_DEEP := Color("#8e1a18")     ## RED2: shaded red cloth
const EMBER_HOT := Color("#f8dc8a")    ## GOLD5: the hottest gold, the white-hot heart of a fire
const ASH := Color("#8a7c6c")          ## BONE1: grey for stand-stills and ash

## UI kit names (the menu reference): the gold frames, the navy panels, the cream of the labels.
const GOLD := Color("#e8b64c")         ## GOLD4
const GOLD_DIM := Color("#c08a2e")     ## GOLD3
const GOLD_DEEP := Color("#8a5a1c")    ## GOLD2
const GOLD_HOT := Color("#f8dc8a")     ## GOLD5
const NAVY := Color("#12142a")         ## NAVY1
const NAVY_DEEP := Color("#0b0c1c")    ## NAVY0
const NAVY_LIGHT := Color("#1a1d3a")   ## NAVY2
const CREAM := Color("#fdf6df")        ## BONE4
const FIRE := Color("#f47e22")         ## FIRE4
const FIRE_HOT := Color("#fde07a")     ## FIRE6

## Timing feedback, shared with the UI (UIKit.EARLY / UIKit.LATE): early is up and cool, late is down
## and warm. They also differ in lightness (early is the lighter one), and every early/late mark
## points its own way, so they stay apart in greyscale.
const EARLY := Color("#8ec3e6")
const LATE := Color("#ef8250")
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
