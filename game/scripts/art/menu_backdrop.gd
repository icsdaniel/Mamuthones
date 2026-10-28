class_name MenuBackdrop
extends Control
## The calm ground every menu-type screen stands on (App puts one behind the screen stack): a flat
## night navy that deepens a little towards the bottom, drawn in code in a few stepped bands, with
## no scene art. The play screens paint their own picture and hide it.

const BANDS := 24
var reduced_motion := false   ## kept for App; nothing moves here
var still := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Backdrop"


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var top: Color = PixelPalette.NAVY[1]
	var bottom: Color = PixelPalette.K[0]
	var h := size.y / float(BANDS)
	for i in BANDS:
		draw_rect(Rect2(0, floorf(i * h), size.x, ceilf(h) + 1.0), top.lerp(bottom, float(i) / float(BANDS - 1)))
