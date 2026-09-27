class_name CenterWidth
extends Container
## Lays its children out at the full height and at most `max_width` wide, centred. Keeps phone layouts
## readable on a 3:4 tablet, where the logical width grows to about 1080.

@export var max_width := 760.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var w := minf(size.x, max_width)
		for c in get_children():
			if c is Control and (c as Control).visible:
				fit_child_in_rect(c, Rect2((size.x - w) * 0.5, 0.0, w, size.y))


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and (c as Control).visible:
			var cm := (c as Control).get_combined_minimum_size()
			m.x = maxf(m.x, cm.x)
			m.y = maxf(m.y, cm.y)
	m.x = minf(m.x, max_width)
	return m
