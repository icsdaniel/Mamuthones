class_name Palette
extends RefCounted
## The game's four inks (docs/design.md section 8) plus the few mixed tones the art needs,
## and cached loaders for the shared woodcut textures and fonts.

const BLACK := Color("#141110")
const BONE := Color("#ede6da")
const RED := Color("#c0392b")
const EMBER := Color("#e0a24a")

## Mixed tones. Everything else is one of the four inks at some alpha.
const INK := Color("#0c0a09")          ## deepest ink, for holes and shadows
const WOOD := Color("#231d19")         ## carved dark wood, a step above black
const NIGHT := Color("#1a1512")        ## night sky / board
const BONE_DIM := Color("#b9ae9e")     ## captions, secondary text on dark
const BONE_FAINT := Color("#6e645b")   ## disabled text
const RED_DEEP := Color("#8e2a20")     ## shaded red cloth
const EMBER_HOT := Color("#f3cf85")    ## the white-hot heart of a fire
const ASH := Color("#7d756c")          ## grey for stand-stills and ash

## Sheepskin shades and strap leathers the player can pick (Profile look values).
const FLEECE := {
	"black": Color("#171311"),
	"dark_brown": Color("#2c1f17"),
}
const STRAPS := {
	"natural": Color("#8a5a33"),
	"dark": Color("#4a2e1c"),
}

const TEX_DIR := "res://art/textures/"
const UI_DIR := "res://art/ui/"

static var _cache := {}


## A shared texture from game/art/textures (paper, grain, hatch, chisel, fog, speckle).
static func tex(name: String) -> Texture2D:
	return _load(TEX_DIR + name + ".png")


## A nine-patch or icon from game/art/ui.
static func ui(name: String) -> Texture2D:
	return _load(UI_DIR + name + ".png")


static func display_font() -> Font:
	return _load("res://fonts/IMFellEnglishSC-Regular.ttf")


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
