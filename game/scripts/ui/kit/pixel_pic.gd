class_name PixelPic
extends Control
## A piece of pixel art drawn at the largest whole scale that fits the control (never smoothed, never
## an uneven pixel), centred. `step` keeps the scale a multiple of it (3: one art px = one base art
## px of the kit grid). Part of the menu kit (added with the workshop).

var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
var region := Rect2()            ## part of the texture to show (empty: all of it)
var step := 1
var max_scale := 99
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func pic_scale() -> int:
	if texture == null:
		return 0
	var src := region.size if region.has_area() else texture.get_size()
	var s := int(floor(minf(size.x / src.x, size.y / src.y)))
	s = mini(s, max_scale)
	if step > 1 and s >= step:
		s -= s % step
	return maxi(s, 1)


func _draw() -> void:
	if texture == null:
		return
	var src := region if region.has_area() else Rect2(Vector2.ZERO, texture.get_size())
	var s := float(pic_scale())
	var d := src.size * s
	var at := ((size - d) * 0.5).floor()
	draw_texture_rect_region(texture, Rect2(at, d), src, tint)
