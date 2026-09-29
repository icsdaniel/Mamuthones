class_name PixelFrame
extends RefCounted
## The gold rule frame round the story pictures (docs/art-style.md "UI kit"): a K0 outline, an old
## gold rule with a darker inner line, gold studs at the corners and, optionally, small red diamonds
## at the middle of the top and bottom edges. Drawn in whole art pixels of `px` screen pixels.
##
##   PixelFrame.draw(ci, rect, px, style)   style "gold" | "bright" (hover, the next stop) | "dim" (locked)

## How far the frame reaches into the rect, in art pixels.
const DEPTH := 4


static func draw(ci: CanvasItem, rect: Rect2, px: float, style := "gold", diamonds := true) -> void:
	var rule: Color = PixelPalette.GOLD[3]
	var stud: Color = PixelPalette.GOLD[4]
	var shine: Color = PixelPalette.GOLD[5]
	var inner: Color = PixelPalette.GOLD[1]
	var mark: Color = PixelPalette.RED[3]
	match style:
		"bright":
			rule = PixelPalette.GOLD[4]
			stud = PixelPalette.GOLD[5]
			shine = PixelPalette.STAR[1]
			mark = PixelPalette.RED[4]
		"dim":
			rule = PixelPalette.GOLD[1]
			stud = PixelPalette.GOLD[2]
			shine = PixelPalette.GOLD[3]
			inner = PixelPalette.GOLD[0]
			mark = PixelPalette.RED[1]
	var r := Rect2(rect.position.floor(), rect.size.floor())
	_ring(ci, r, px, PixelPalette.K[0])
	_ring(ci, r.grow(-px), px, rule)
	_ring(ci, r.grow(-px * 2.0), px, inner)
	_ring(ci, r.grow(-px * 3.0), px, PixelPalette.K[0])
	# corner studs: 3x3 with a lit pixel
	for c in [r.position, Vector2(r.end.x - px * 3.0, r.position.y), Vector2(r.position.x, r.end.y - px * 3.0), r.end - Vector2(px, px) * 3.0]:
		ci.draw_rect(Rect2(c, Vector2(px, px) * 3.0), PixelPalette.K[0])
		ci.draw_rect(Rect2(c + Vector2(px, px) * 0.0 + Vector2(0, 0), Vector2(px, px) * 2.0), stud)
		ci.draw_rect(Rect2(c, Vector2(px, px)), shine)
	if diamonds and r.size.x > px * 40.0:
		for y in [r.position.y + px * 1.0, r.end.y - px * 2.0]:
			diamond(ci, Vector2(r.get_center().x, y + px * 0.5), px, mark)


## A small diamond (5 art px across) centred at c: K0 edge, colour inside, a lit top pixel.
static func diamond(ci: CanvasItem, c: Vector2, px: float, col: Color, size := 2) -> void:
	var o := (c / px).floor() * px
	for dy in range(-size - 1, size + 2):
		var w := size + 1 - absi(dy)
		ci.draw_rect(Rect2(o + Vector2(-w, dy) * px, Vector2(w * 2 + 1, 1) * px), PixelPalette.K[0])
	for dy in range(-size, size + 1):
		var w := size - absi(dy)
		ci.draw_rect(Rect2(o + Vector2(-w, dy) * px, Vector2(w * 2 + 1, 1) * px), col)
	ci.draw_rect(Rect2(o + Vector2(0, -size) * px, Vector2(px, px)), PixelPalette.GOLD[5])


static func _ring(ci: CanvasItem, r: Rect2, px: float, col: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, px)), col)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - px), Vector2(r.size.x, px)), col)
	ci.draw_rect(Rect2(r.position, Vector2(px, r.size.y)), col)
	ci.draw_rect(Rect2(Vector2(r.end.x - px, r.position.y), Vector2(px, r.size.y)), col)


## Screen pixels per art pixel for a control: 3 on the 720-wide base screen, whole numbers only.
static func px_for(c: Control) -> float:
	var w := c.get_viewport_rect().size.x if c.is_inside_tree() else 720.0
	return maxf(1.0, roundf(w / 240.0))
