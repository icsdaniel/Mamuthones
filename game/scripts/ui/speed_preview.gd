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
	# the Woodcut road seen flat: black ground, cream dotted dividers, cream hit rings, cream ovals
	var field := Rect2(Vector2.ZERO, size)
	draw_rect(field, WoodcutSkin.K)
	var lw := size.x / 3.0
	var dot := maxf(2.0, roundf(size.x / 240.0))
	for i in [1, 2]:
		var x := roundf(lw * float(i))
		var yy := 0.0
		while yy < size.y:
			draw_rect(Rect2(x - dot * 0.5, yy, dot, dot * 2.0), WoodcutSkin.C)
			yy += dot * 5.0
	var spb := 0.6
	var pulse := 1.0 - fposmod(_t / spb, 1.0)
	var hl := LaneSkin.hit_line_y(field)
	var rw := lw * WoodcutSkin.RING_W * 0.5
	for i in 3:
		var c := Vector2(lw * (float(i) + 0.5), hl)
		WoodcutSkin.oval(self, c, Vector2(rw, rw * WoodcutSkin.FLAT) * (1.0 + 0.04 * pulse), WoodcutSkin.K, WoodcutSkin.C, maxf(2.0, rw * 0.12))
	var pps := (hl - field.position.y) / (LaneView.LOOKAHEAD / maxf(note_speed, 0.1))
	var pattern := [1, 0, 1, 2, 1, 2, 0, 1]
	var first := floori(_t / spb) - 1
	var nw := lw * WoodcutSkin.NOTE_W * 0.5
	for k in range(first, first + 40):
		var nt := float(k) * spb
		var y := LaneSkin.note_y(field, nt - _t, pps)
		if y < field.position.y - 60.0:
			break
		if y > hl + 20.0:
			continue
		var c := Vector2(lw * (float(pattern[posmod(k, pattern.size())]) + 0.5), y)
		WoodcutSkin.oval(self, c, Vector2(nw, nw * WoodcutSkin.FLAT), WoodcutSkin.C, WoodcutSkin.K, maxf(2.0, nw * 0.1))
