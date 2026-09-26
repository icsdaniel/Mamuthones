class_name HeadphonesArt
extends Control
## A pair of headphones cut in bone on the dark board, for the first-launch suggestion.


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.36
	draw_arc(c + Vector2(0.0, r * 0.25), r, PI * 1.08, PI * 1.92, 48, Palette.BONE, r * 0.12)
	for side in [-1.0, 1.0]:
		var cup := Rect2(c.x + side * r * 0.95 - r * 0.2, c.y + r * 0.1, r * 0.4, r * 0.62)
		draw_rect(cup, Palette.BONE)
		draw_rect(cup.grow(-r * 0.07), Palette.WOOD)
	# Two small bells between the cups, sounding.
	for i in 3:
		draw_arc(c + Vector2(0.0, r * 0.45), r * (0.18 + 0.12 * i), -PI * 0.8, -PI * 0.2, 16, Color(Palette.EMBER, 1.0 - i * 0.3), 4.0)
