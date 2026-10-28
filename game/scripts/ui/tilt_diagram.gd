class_name TiltDiagram
extends Control
## The calibration's picture of the move, drawn flat (no art): the phone seen from its side, held
## level, tipping its top edge toward the player or away as `tilt` says, with a curved arrow on each
## side for the two moves (the one asked for next lit). `flash` (0..1) lights the phone's edge when a
## tilt is counted. Stands where the phone-in-hands picture was (graphics review, 2026-10-28).

var tilt := 0.0:      ## radians, > 0 = top edge toward the player (the screen shows the player on the left)
	set(v):
		tilt = v
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
var expect_up := true:   ## the move asked for next: toward the player (true) or away
	set(v):
		expect_up = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var long := minf(size.x * 0.46, size.y * 1.1)
	var thick := maxf(18.0, long * 0.09)
	var gold: Array[Color] = PixelPalette.GOLD
	var navy: Array[Color] = PixelPalette.NAVY
	# the two moves' arrows, curving about the phone's middle: toward the player on the left
	var r := long * 0.62
	for up in [true, false]:
		var on: bool = up == expect_up
		var col: Color = gold[4] if on else gold[2]
		var w := 8.0 if on else 5.0
		var mid := PI * 1.5 + (-0.62 if up else 0.62)
		var a0 := mid - 0.36
		var a1 := mid + 0.36
		draw_arc(c, r, a0, a1, 20, col, w, true)
		# the head at the end the move goes to (the top edge turns toward its side)
		var end_a := a0 if up else a1
		var tip := c + Vector2(cos(end_a), sin(end_a)) * r
		var along := Vector2(-sin(end_a), cos(end_a)) * (1.0 if up else -1.0)
		var side := Vector2(cos(end_a), sin(end_a))
		var hs := w * 2.6
		draw_colored_polygon(PackedVector2Array([tip - along * hs * 1.1, tip + side * hs * 0.8, tip - side * hs * 0.8]), col)
	# the phone from its side: a long slab, its screen face (up) lit gold, turned by the tilt
	draw_set_transform(c, -tilt, Vector2.ONE)
	var body := Rect2(Vector2(-long * 0.5, -thick * 0.5), Vector2(long, thick))
	var edge := gold[3].lerp(gold[5], clampf(flash, 0.0, 1.0))
	draw_rect(body.grow(4.0), PixelPalette.K[0])
	draw_rect(body, navy[3])
	draw_rect(Rect2(body.position, Vector2(long, thick * 0.32)), edge)
	# its top edge (the end that tips), marked by a small notch
	draw_rect(Rect2(Vector2(-long * 0.5 - 2.0, -thick * 0.5), Vector2(10.0, thick)), gold[4])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
