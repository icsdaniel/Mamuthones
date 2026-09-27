class_name UnisonMeter
extends Control
## Six marks for the six unison levels (×1 … ×4), lit up to the current level, and under them a thin
## bar filling with the streak toward the next level (12 good hits).

var level := 0:
	set(v):
		level = v
		queue_redraw()
var fill := 0.0:
	set(v):
		if not is_equal_approx(v, fill):
			fill = v
			queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var n := Session.UNISON_MULTS.size()
	var gap := 6.0
	var w := (size.x - gap * (n - 1)) / n
	var h := size.y * 0.62
	for i in n:
		var r := Rect2(i * (w + gap), 0.0, w, h)
		if i <= level:
			draw_rect(r, Palette.EMBER if i < 5 else Palette.EMBER_HOT)
		else:
			draw_rect(r, Color(Palette.BONE, 0.25), false, 2.0)
	var bar := Rect2(0.0, h + 3.0, size.x, size.y - h - 3.0)
	draw_rect(bar, Color(Palette.INK, 0.7))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), Palette.BONE)
