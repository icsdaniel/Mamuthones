class_name SpeedPreview
extends Control
## A live preview of the note speed in Settings: the real lanes and steps falling at the chosen speed
## onto the hit line, one per beat at 100 bpm, so the player sees how much warning each speed gives.

var note_speed := 1.0:
	set(v):
		note_speed = v
		queue_redraw()
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var field := Rect2(Vector2.ZERO, size)
	LaneSkin.draw_lanes(self, field)
	var spb := 0.6
	var pulse := 1.0 - fposmod(_t / spb, 1.0)
	LaneSkin.draw_hit_line(self, field, pulse)
	var hl := LaneSkin.hit_line_y(field)
	var pps := (hl - field.position.y) / (LaneView.LOOKAHEAD / maxf(note_speed, 0.1))
	var lanes := LaneSkin.lane_rects(field)
	var pattern := [1, 0, 1, 2, 1, 2, 0, 1]
	var first := floori(_t / spb) - 1
	for k in range(first, first + 40):
		var nt := float(k) * spb
		var y := LaneSkin.note_y(field, nt - _t, pps)
		if y < field.position.y - 60.0:
			break
		if y > hl + 20.0:
			continue
		LaneSkin.draw_step(self, lanes[pattern[posmod(k, pattern.size())]], y)
