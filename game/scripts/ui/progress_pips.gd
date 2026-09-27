class_name ProgressPips
extends Control
## A row of marks, one per step (tutorial lessons): done ones in ember, the current one outlined in
## bone, the rest faint.

var count := 1
var current := 0


func _init(p_count := 1, p_current := 0) -> void:
	count = maxi(p_count, 1)
	current = p_current
	custom_minimum_size.y = 20
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var gap := 8.0
	var w := (size.x - gap * (count - 1)) / count
	for i in count:
		var r := Rect2(i * (w + gap), 0.0, w, size.y)
		if i < current:
			draw_rect(r, Palette.EMBER)
		elif i == current:
			draw_rect(r, Palette.BONE, false, 3.0)
		else:
			draw_rect(r, Color(Palette.BONE, 0.2), false, 2.0)
