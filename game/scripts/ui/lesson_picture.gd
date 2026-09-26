class_name LessonPicture
extends Control
## A small animated picture of one lesson, drawn with the same LaneSkin as the play screen, so the
## player sees exactly what to look for: notes slide down to the line and the right button lights up
## (or the phone tilts, or a finger drags across) as they arrive.

const LOOP := 2.4

var topic := "steps"
var slam := false
var _t := 0.0


func _process(delta: float) -> void:
	_t = fmod(_t + delta, LOOP)
	queue_redraw()


func _draw() -> void:
	var w := minf(size.x, 560.0)
	var area := Rect2((size.x - w) * 0.5, 0.0, w, size.y)
	var buttons_h := 110.0
	var field := Rect2(area.position, Vector2(area.size.x, area.size.y - buttons_h))
	LaneSkin.draw_lanes(self, field, [0.0, 0.0, 0.0])
	LaneSkin.draw_hit_line(self, field, 0.0)
	var lanes := LaneSkin.lane_rects(field)
	var hit_y := LaneSkin.hit_line_y(field)
	var pps := (hit_y - field.position.y) / 1.2
	var arrive := 1.4
	var dt := arrive - _t
	var y := LaneSkin.note_y(field, dt, pps)
	var pressed := [false, false, false]
	var lit := absf(dt) < 0.18 or (topic == "holds" and dt < 0.0 and dt > -0.8)
	match topic:
		"steps":
			if dt > -0.05:
				LaneSkin.draw_step(self, lanes[1], y, false)
			pressed[1] = lit
		"lanes":
			for i in 3:
				var d := dt + (i - 1) * 0.4
				if d > -0.05:
					LaneSkin.draw_step(self, lanes[i], LaneSkin.note_y(field, d, pps), false)
				pressed[i] = absf(d) < 0.18
		"bells":
			if dt > -0.05:
				LaneSkin.draw_bell(self, field, y, true)
			if slam:
				pressed[0] = lit
				pressed[2] = lit
		"holds":
			var tail := LaneSkin.note_y(field, dt + 0.8, pps)
			if dt + 0.8 > 0.0:
				LaneSkin.draw_hold(self, lanes[1], minf(y, hit_y), tail, lit)
			pressed[1] = lit
		"still":
			LaneSkin.draw_rest(self, field, LaneSkin.note_y(field, dt + 0.6, pps), y)
		"swipes":
			if dt > -0.05:
				LaneSkin.draw_swipe(self, field, y, 1)
		"full":
			if dt > -0.05:
				LaneSkin.draw_ring(self, field, lanes[0], y, true)
			pressed[0] = lit
			if slam:
				pressed[2] = lit
	var br := Rect2(area.position.x, field.end.y, area.size.x, buttons_h)
	var bw := br.size.x / 3.0
	for i in 3:
		LaneSkin.draw_button(self, Rect2(br.position.x + bw * i + 8.0, br.position.y + 8.0, bw - 16.0, buttons_h - 16.0),
			i, "pressed" if pressed[i] else "idle")
	if lit and topic in ["bells", "full"] and not slam:
		_draw_tilt(Vector2(area.end.x - 70.0, field.position.y + 90.0))
	if topic == "swipes" and absf(dt) < 0.35:
		var k := clampf((0.35 - dt) / 0.7, 0.0, 1.0)
		var fx := lerpf(br.position.x + 40.0, br.end.x - 40.0, k)
		draw_circle(Vector2(fx, br.get_center().y), 26.0, Color(Palette.BONE, 0.85))


## A phone outline tipping toward the player, beside the lanes.
func _draw_tilt(at: Vector2) -> void:
	var xf := Transform2D(-0.35, at)
	draw_set_transform_matrix(xf)
	var r := Rect2(-30.0, -55.0, 60.0, 110.0)
	draw_rect(r, Palette.EMBER, false, 5.0)
	draw_line(Vector2(-12.0, 44.0), Vector2(12.0, 44.0), Palette.EMBER, 4.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_arc(at, 80.0, -2.2, -1.2, 12, Palette.EMBER_HOT, 4.0)
