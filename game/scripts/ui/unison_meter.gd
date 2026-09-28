class_name UnisonMeter
extends Control
## Six bells for the six unison levels (×1 … ×4), lit gold up to the current level, and under them a
## thin line filling with the streak toward the next level (12 good hits).

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
	var step := size.x / float(n)
	var r := minf(step * 0.4, (size.y - 8.0) * 0.5)
	var cy := r + 1.0
	for i in n:
		var c := Vector2(step * (i + 0.5), cy)
		var lit := i <= level
		if lit:
			draw_texture_rect(FireSkin.glow(), Rect2(c - Vector2(r, r) * 1.8, Vector2(r, r) * 3.6), false, Color(1.0, 0.7, 0.3, 0.45))
		_bell(c, r, lit)
	var y := cy + r + 5.0
	var bar := Rect2(step * 0.2, y, size.x - step * 0.4, 3.0)
	draw_rect(bar, Color(0.05, 0.02, 0.06, 0.8))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), Color("#ffd98a"))


## A cowbell, mouth down: gold and lit, or dark.
func _bell(c: Vector2, r: float, lit: bool) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := float(i) / float(n)
		# Quadratic curves up to the crown and down again, as the mockup's bell.
		var a := Vector2(-r * 0.9, r * 0.7)
		var ctl := Vector2(-r * 0.85, -r) if t < 0.5 else Vector2(r * 0.85, -r)
		var tt := t * 2.0 if t < 0.5 else t * 2.0 - 1.0
		var p0 := a if t < 0.5 else Vector2(0, -r)
		var p1 := Vector2(0, -r) if t < 0.5 else Vector2(r * 0.9, r * 0.7)
		pts.append(c + p0.lerp(ctl, tt).lerp(ctl.lerp(p1, tt), tt))
	var cols := PackedColorArray()
	for p in pts:
		var k := clampf((p.y - (c.y - r)) / (r * 1.7), 0.0, 1.0)
		if lit:
			cols.append(Color("#fff1c0").lerp(Color("#ffbe45"), minf(k * 2.0, 1.0)).lerp(Color("#c46a18"), maxf(k * 2.0 - 1.0, 0.0)))
		else:
			cols.append(Color("#3a2a36"))
	draw_polygon(pts, cols)
	draw_polyline(pts, Color(0.07, 0.02, 0.04, 0.9), 1.5, true)
	draw_set_transform(c + Vector2(0, r * 0.8), 0.0, Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, r * 0.25, Color("#5a2a08") if lit else Color("#1a1018"))
	draw_set_transform(Vector2.ZERO)
