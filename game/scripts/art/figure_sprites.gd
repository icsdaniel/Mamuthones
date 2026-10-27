class_name FigureSprites
extends RefCounted
## The pixel-art Mamuthones and Issohadores (docs/art-style.md), baked at 1x by
## tools/art/pixel/bake_figures.py into res://art/px/figures/. Every screen that shows a character
## draws it through here, so the play screen, the title and the story all show the same figures.
##
## The play screen's files have their own drawings, one per depth: row_mamuthone(), row_issohadore().
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


## The play screen's Mamuthone at depth d ("near", "mid", "far"), pose "stand", "crouch", "air",
## "land", "land2" (the bells swung the other way) or "dim" (standing, not yet dancing), variant
## "a" or "b" (tools/art/pixel/row_figures.py). Drawn at PxArt.PX, never scaled.
static func row_mamuthone(d: String, fleece: String, pose: String, variant := "a") -> String:
	var fl := fleece if fleece in ["black", "dark_brown"] else "black"
	return "row_%s_mamuthone_%s_%s_%s" % [d, fl, pose, variant]


## The play screen's Issohadore: pose "stand", "swing" (rope hand up) or "cast" (hand out).
static func row_issohadore(pose: String) -> String:
	return "row_issohadore_" + pose


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


## Draws sprite `name` with its feet at `feet` on canvas item ci. `squash` is ignored (never stretched), `rot` leans it about the feet (radians).
static func draw(ci: CanvasItem, name: String, feet: Vector2, px: float, flip := false, modulate := Color.WHITE, rot := 0.0, squash := 1.0) -> void:
	if draw_new(ci, name, feet, px, flip, modulate, rot):
		return
	var t := tex(name)
	if t == null or not FigureCells.CELLS.has(name):
		return
	var cell: Vector2 = FigureCells.CELLS[name][0]
	var a: Vector2 = FigureCells.CELLS[name][1]
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	# one scale for both axes: the art is never stretched (Daniele, 2026-10-26), so a landing is not
	# a squash any more (`squash` stays in the signature for the callers and is ignored)
	ci.draw_set_transform(feet, rot, Vector2(px * (-1.0 if flip else 1.0), px))
	ci.draw_texture_rect(t, Rect2(-a, cell), false, modulate)
	ci.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ Daniele's ChatGPT figures

## Daniele's ChatGPT Mamuthone and Issohadore (art/ai/fig/<figure>_bob_<i>.png, tools/art/chatgpt/
## outputs.py) stand in for the drawn ones everywhere outside the play screen too (title, story
## stops, workshop, procession): the same size as the drawing they replace (its standing height),
## shrunk once per size at their own proportions. A pose becomes a bob frame: Mamuthones never jump,
## they bob down on the beat ("land" is the down frame, "crouch" the way back up).
const NEW_DIR := "res://art/ai/fig/"
static var _new := {}


## The ChatGPT figure for sprite `name` ("mamuthone", "issohadore", or "" when it has none).
static func new_figure(name: String) -> String:
	var n := name.trim_prefix("big_")
	for f in ["mamuthone", "issohadore"]:
		if n.begins_with(f + "_") and ResourceLoader.exists(NEW_DIR + f + "_bob_0.png"):
			return f
	return ""


static func bob_frame(name: String) -> int:
	if name.ends_with("_land"):
		return 2
	if name.ends_with("_crouch"):
		return 3
	return 0


## The figure's bob frame `frame` shrunk to h art px tall (its own proportions), every texel wholly
## in or out.
static func new_tex(figure: String, frame: int, h: int, black := false) -> Texture2D:
	var k := "%s_%d_%d%s" % [figure, frame, h, "_k" if black else ""]
	if not _new.has(k):
		var t: Texture2D = null
		var path := NEW_DIR + "%s_bob_%d.png" % [figure, frame]
		if ResourceLoader.exists(path):
			var r: Resource = load(path)
			var img: Image = (r as Image).duplicate() if r is Image else (r as Texture2D).get_image()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if black:
				darken_fleece(img)
			var w := maxi(1, roundi(float(img.get_width()) * h / img.get_height()))
			img.resize(w, h, Image.INTERPOLATE_LANCZOS)
			var d := img.get_data()
			for i in range(3, d.size(), 4):
				d[i] = 255 if d[i] > 127 else 0
			img.set_data(w, h, false, Image.FORMAT_RGBA8, d)
			t = ImageTexture.create_from_image(img)
		_new[k] = t
	return _new[k]


## The Workshop's "black" sheepskin: the Mamuthone's orange-brown fleece (hue under about 30 degrees)
## taken down to near black, keeping its lit tips warm so the shaggy shape still reads; the bells
## (yellower), the leather, the mask and the skin keep their colours. Edits img in place.
static func darken_fleece(img: Image) -> void:
	var d := img.get_data()
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var c := Color(d[i] / 255.0, d[i + 1] / 255.0, d[i + 2] / 255.0)
		if c.s > 0.3 and (c.h < 0.085 or c.h > 0.97):
			c.v *= 0.34
			c.s *= 0.8
			d[i] = roundi(c.r * 255.0)
			d[i + 1] = roundi(c.g * 255.0)
			d[i + 2] = roundi(c.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)


static var _black := {}


## Bob frame i of the Mamuthone in the black fleece at full size (made once).
static func black_tex(i: int, src: Texture2D) -> Texture2D:
	if not _black.has(i):
		var img := src.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		darken_fleece(img)
		_black[i] = ImageTexture.create_from_image(img)
	return _black[i]


## True when sprite `name` is a Mamuthone in the black fleece (the dark brown one is the picture as it is).
static func is_black(name: String) -> bool:
	return name.trim_prefix("big_").begins_with("mamuthone_black_")


## Makes every ChatGPT bob frame at every height the screens draw it (and the half-size far ones),
## so no screen shrinks a picture on its first frame.
static func warm_new() -> void:
	for name: String in FigureCells.CELLS:
		if not name.ends_with("_stand") or name.begins_with("row_") or new_figure(name) == "":
			continue
		var fig := new_figure(name)
		for k in [1.0, 0.5]:
			var h := maxi(roundi(art_height(name) * k), 4)
			for frame in [0, 2, 3]:
				new_tex(fig, frame, h, is_black(name))


## Draws the ChatGPT figure in place of sprite `name` (size_k: 0.5 for the half-size far figures).
## False when the sprite has none.
static func draw_new(ci: CanvasItem, name: String, feet: Vector2, px: float, flip := false, modulate := Color.WHITE, rot := 0.0, size_k := 1.0) -> bool:
	var fig := new_figure(name)
	if fig == "":
		return false
	var stand := name.substr(0, name.rfind("_") + 1) + "stand"
	var h := roundi((art_height(stand) if FigureCells.CELLS.has(stand) else art_height(name)) * size_k)
	var t := new_tex(fig, bob_frame(name), maxi(h, 4), is_black(name))
	if t == null:
		return false
	var sz := t.get_size()
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	ci.draw_set_transform(feet, rot, Vector2(px * (-1.0 if flip else 1.0), px))
	ci.draw_texture_rect(t, Rect2(Vector2(-floorf(sz.x * 0.5), -sz.y), sz), false, modulate)
	ci.draw_set_transform(Vector2.ZERO)
	return true
