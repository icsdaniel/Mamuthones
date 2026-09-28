class_name FigureSprites
extends RefCounted
## The pixel-art Mamuthones and Issohadores (docs/art-style.md), baked at 1x by
## tools/art/pixel/bake_figures.py into res://art/px/figures/. Every screen that shows a character
## draws it through here, so the play screen, the title and the story all show the same figures.
##
## Sprite names: "mamuthone_<fleece>_<pose>" (fleece "black" or "dark_brown"; pose "stand", "crouch",
## "air", "land") and "issohadore_<pose>" (pose "stand", "throw"); "big_" in front for the title-size
## drawing. The sprites face right, lit from the right; flip them for the right-hand side of a scene.
##
## `px` is screen pixels per art pixel (3 on the 720-wide base screen). Figures are drawn with
## nearest filtering so the pixels stay square.

const DIR := "res://art/px/figures/"

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func has(name: String) -> bool:
	return FigureCells.CELLS.has(name)


## The Mamuthone sprite name for a fleece and pose (unknown fleeces fall back to black).
static func mamuthone(fleece: String, pose: String, big := false) -> String:
	var fl := fleece if fleece in ["black", "dark_brown"] else "black"
	return ("big_" if big else "") + "mamuthone_%s_%s" % [fl, pose]


static func issohadore(pose: String, big := false) -> String:
	return ("big_" if big else "") + "issohadore_" + pose


## The drawn box of sprite `name` relative to its feet, at px screen pixels per art pixel.
static func bounds(name: String, px: float, flip := false) -> Rect2:
	if not FigureCells.CELLS.has(name):
		return Rect2()
	var b: Rect2 = FigureCells.CELLS[name][2]
	b = Rect2(b.position * px, b.size * px)
	if flip:
		b.position.x = -b.end.x
	return b


## Height in art pixels of what sprite `name` draws (feet to the top of the head or bells).
static func art_height(name: String) -> float:
	if not FigureCells.CELLS.has(name):
		return 1.0
	return (FigureCells.CELLS[name][2] as Rect2).size.y


## Draws sprite `name` with its feet at `feet` on canvas item ci. `squash` < 1 flattens it onto its
## feet (a landing), `rot` leans it about the feet (radians).
static func draw(ci: CanvasItem, name: String, feet: Vector2, px: float, flip := false, modulate := Color.WHITE, rot := 0.0, squash := 1.0) -> void:
	var t := tex(name)
	if t == null or not FigureCells.CELLS.has(name):
		return
	var cell: Vector2 = FigureCells.CELLS[name][0]
	var a: Vector2 = FigureCells.CELLS[name][1]
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	var sx := px * (-1.0 if flip else 1.0) * (2.0 - squash)
	ci.draw_set_transform(feet, rot, Vector2(sx, px * squash))
	ci.draw_texture_rect(t, Rect2(-a, cell), false, modulate)
	ci.draw_set_transform(Vector2.ZERO)
