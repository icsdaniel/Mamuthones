class_name PixelBox
extends StyleBox
## A pixel-art nine-patch for the Theme: the texture is authored at 1x (one texel = one art pixel, see
## tools/art/pixel/ui_kit.py) and drawn scaled by `px` (3 on the 720-wide base screen) with the
## project's nearest filtering. The box is snapped to whole art pixels so every frame line stays one
## art pixel thick, edges and centre are tiled (never stretched, so woven patterns keep their grid), and
## small ornaments are placed on top: `ends` at both ends (the red lozenges of the menu buttons, the gold
## medallions of the red banner), `middle` at the centre (the divider's lozenge), `caps` at both ends of
## a divider line.

var texture: Texture2D
## Nine-patch borders in art pixels: left, top, right, bottom.
var margins := Vector4i(5, 5, 5, 6)
## Screen pixels per art pixel.
var px := 3.0
## Ornament at both ends, vertically centred on the face (ornaments are symmetric).
var ends: Texture2D
var ends_inset := 6
## Art pixels to push the ornaments down (a pressed face sits one pixel lower).
var ends_dy := 0
## Rows at the bottom that are not part of the face (the drop shadow): ornaments centre above them.
var shadow_rows := 1
var middle: Texture2D
var caps: Texture2D
var tint := Color.WHITE


static func make(tex: Texture2D, m: Vector4i, content: Vector4, end_tex: Texture2D = null, inset := 6) -> PixelBox:
	var b := PixelBox.new()
	b.texture = tex
	b.margins = m
	b.ends = end_tex
	b.ends_inset = inset
	b.content_margin_left = content.x
	b.content_margin_top = content.y
	b.content_margin_right = content.z
	b.content_margin_bottom = content.w
	return b


func _draw(ci: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var s := px
	var aw := maxf(floorf(rect.size.x / s), float(margins.x + margins.z))
	var ah := maxf(floorf(rect.size.y / s), float(margins.y + margins.w))
	var origin := (rect.position + (rect.size - Vector2(aw, ah) * s) * 0.5).round()
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D(0.0, Vector2(s, s), 0.0, origin))
	var tsize := texture.get_size()
	RenderingServer.canvas_item_add_nine_patch(ci, Rect2(0, 0, aw, ah), Rect2(Vector2.ZERO, tsize), texture.get_rid(),
		Vector2(margins.x, margins.y), Vector2(margins.z, margins.w),
		RenderingServer.NINE_PATCH_TILE, RenderingServer.NINE_PATCH_TILE, true, tint)
	var face_h := ah - shadow_rows
	if ends != null:
		var e := ends.get_size()
		var y := floorf((face_h - e.y) * 0.5) + ends_dy
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(ends_inset, y, e.x, e.y), ends.get_rid(), false, tint)
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(aw - ends_inset - e.x, y, e.x, e.y), ends.get_rid(), false, tint)
	if caps != null:
		var c := caps.get_size()
		var cy := floorf((ah - c.y) * 0.5)
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(0, cy, c.x, c.y), caps.get_rid(), false, tint)
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(aw - c.x, cy, c.x, c.y), caps.get_rid(), false, tint)
	if middle != null:
		var m := middle.get_size()
		RenderingServer.canvas_item_add_texture_rect(ci, Rect2(floorf((aw - m.x) * 0.5), floorf((ah - m.y) * 0.5), m.x, m.y),
			middle.get_rid(), false, tint)
	RenderingServer.canvas_item_add_set_transform(ci, Transform2D.IDENTITY)
