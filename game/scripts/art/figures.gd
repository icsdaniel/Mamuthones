class_name Figures
extends RefCounted
## The procession's people drawn anywhere by height, in pixel art: thin wrappers over the shared
## figures (FigureSprites, baked from tools/art/pixel/figures.py) and the player's look on them
## (LookArt), for code that asks for "a Mamuthone h pixels tall". The art scale is the whole number
## of screen pixels per art pixel that comes closest to `h`, so the pixels stay square.
##
## Every function draws with the feet at `at` (default the canvas origin), facing right, lit by the
## fire on the right. FigureSprites sets its own transform, so pass the position as `at` rather than
## through draw_set_transform. `lit` and `detail` are kept for callers written for the old woodcut
## figures and are ignored: the light is baked into the sprites.

## Screen pixels per art pixel for a figure `h` screen pixels tall drawn from sprite `name`.
static func scale_for(name: String, h: float) -> float:
	return maxf(1.0, roundf(h / FigureSprites.art_height(name)))


## A whole Mamuthone in one call: the fleece, the player's mask, straps and bell set.
static func mamuthone(ci: CanvasItem, h: float, mask: Dictionary, fleece := "black", straps := "natural", _lit := Color.WHITE, _detail := 1, bell_set := "village", at := Vector2.ZERO) -> void:
	var big := h >= 200.0
	var name := FigureSprites.mamuthone(fleece, "stand", big)
	var px := scale_for(name, h)
	var size := "big" if big else "field"
	LookArt.draw_back(ci, size, "stand", at, false, bell_set, px)
	FigureSprites.draw(ci, name, at, px)
	LookArt.draw_front(ci, size, "stand", at, false, mask, straps, bell_set, px)


## The bell load behind a Mamuthone (for callers that draw it apart from the body).
static func mamuthone_back(ci: CanvasItem, h: float, _lit := Color.WHITE, _detail := 1, bell_set := "village", at := Vector2.ZERO) -> void:
	var big := h >= 200.0
	LookArt.draw_back(ci, "big" if big else "field", "stand", at, false, bell_set, scale_for(FigureSprites.mamuthone("black", "stand", big), h))


## The body: the shared figure in its fleece, with the chosen straps.
static func mamuthone_body(ci: CanvasItem, h: float, fleece := "black", straps := "natural", _lit := Color.WHITE, _detail := 1, at := Vector2.ZERO) -> void:
	var big := h >= 200.0
	var name := FigureSprites.mamuthone(fleece, "stand", big)
	var px := scale_for(name, h)
	FigureSprites.draw(ci, name, at, px)
	LookArt.draw_front(ci, "big" if big else "field", "stand", at, false, MaskSpec.default(), straps, "light", px)


## The head: the player's carved mask on the figure's face (big figures only; small ones keep theirs).
static func mamuthone_head(ci: CanvasItem, h: float, mask: Dictionary, straps := "natural", _detail := 1, at := Vector2.ZERO) -> void:
	if h < 200.0:
		return
	var name := FigureSprites.mamuthone("black", "stand", true)
	LookArt.draw_front(ci, "big", "stand", at, false, mask, straps, "light", scale_for(name, h))


## A bronze cowbell hanging from c, about `w` screen pixels wide, swung by `rot` radians.
static func cowbell(ci: CanvasItem, c: Vector2, w: float, rot: float, _lit := Color.WHITE, _detail := 1) -> void:
	var sizes := ["xs", "s", "m", "l", "xl"]
	var widths := [5.0, 7.0, 9.0, 11.0, 13.0]
	var best := 0
	var px := 1.0
	var err := 1e9
	for i in sizes.size():
		for p in range(1, 9):
			var e := absf(widths[i] * float(p) - w)
			if e < err:
				err = e
				best = i
				px = float(p)
	var t := LookArt.tex("bell_" + sizes[best])
	if t == null:
		return
	var hang: Vector2 = Vector2(LookCells.BELL_HANG[sizes[best]])
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	ci.draw_set_transform(c.round(), rot, Vector2(px, px))
	ci.draw_texture(t, -hang)
	ci.draw_set_transform(Vector2.ZERO)


## The ghost (your best run): your Mamuthone's shape in pale light, see-through.
static func ghost(ci: CanvasItem, h: float, color: Color, at := Vector2.ZERO) -> void:
	var name := FigureSprites.mamuthone("black", "stand", h >= 200.0)
	var tint := Color(PixelPalette.BONE[3], clampf(color.a, 0.2, 0.6))
	FigureSprites.draw(ci, name, at, scale_for(name, h), false, tint)


## An Issohadore: red jacket, white mask and trousers, black berritta, the rope in his hand.
static func issohadore_body(ci: CanvasItem, h: float, _lit := Color.WHITE, _detail := 1, at := Vector2.ZERO) -> void:
	var name := FigureSprites.issohadore("stand", h >= 200.0)
	FigureSprites.draw(ci, name, at, scale_for(name, h))


## The rope arm is part of the sprite ("throw" pose shows it raised); nothing more to draw.
static func issohadore_arm(_ci: CanvasItem, _h: float) -> void:
	pass


## Where the Issohadore's rope hand is, relative to the feet (for aiming the rope).
static func issohadore_hand(h: float, rot: float) -> Vector2:
	var name := FigureSprites.issohadore("throw", h >= 200.0)
	var b := FigureSprites.bounds(name, scale_for(name, h))
	return Vector2(b.end.x * 0.6, b.position.y + b.size.y * 0.1).rotated(rot)


## The head is part of the sprite.
static func issohadore_head(_ci: CanvasItem, _h: float, _detail := 1) -> void:
	pass


## A villager in the crowd: a dark silhouette with a warm rim on the fire side, on the art grid.
## kind picks a shape (0 man with cap, 1 woman with shawl, 2 child); `fill` and `rim` are its colours.
static func crowd_person(ci: CanvasItem, h: float, kind: int, fill: Color, rim: Color, salt := 0, at := Vector2.ZERO) -> void:
	var px := maxf(1.0, roundf(h / 30.0))
	var k := kind % 3
	var tall: int = [28, 26, 18][k] + (salt % 3)
	var half: int = [5, 6, 4][k]
	var head := 3
	var o := at.round()
	# body: a tapering block
	for y in range(0, tall - head * 2):
		var w: int = half - (1 if y > tall - head * 2 - 4 else 0)
		ci.draw_rect(Rect2(o + Vector2(-w, -y - 1) * px, Vector2(w * 2, 1) * px), fill)
		ci.draw_rect(Rect2(o + Vector2(w - 1, -y - 1) * px, Vector2(1, 1) * px), rim)
	# head
	var hy: int = tall - head * 2
	for y in range(head * 2):
		var w: int = head - (1 if y == 0 or y == head * 2 - 1 else 0)
		ci.draw_rect(Rect2(o + Vector2(-w, -hy - y - 1) * px, Vector2(w * 2, 1) * px), fill)
		ci.draw_rect(Rect2(o + Vector2(w - 1, -hy - y - 1) * px, Vector2(1, 1) * px), rim)
	if k == 0:  # cap brim
		ci.draw_rect(Rect2(o + Vector2(-head - 1, -tall) * px, Vector2(head * 2 + 2, 1) * px), fill)
