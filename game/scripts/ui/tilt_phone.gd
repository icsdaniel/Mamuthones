class_name TiltPhone
extends Control
## Live feedback for the tilt calibration: a phone seen from the side that leans as the real phone
## turns (from the gyro), an arrow showing which way to tilt next, and a flash with a strength bar each
## time a tilt is counted.

var expect_up := true:
	set(v):
		expect_up = v
		queue_redraw()
var _angle := 0.0
var _flash := 0.0
var _flash_up := true
var _strength := 0.0


## Integrates the pitch rate (degrees per second around the phone's x axis) with a leak back to rest,
## so the drawing follows flicks without drifting.
func feed(rotation_dps: Vector3, delta: float) -> void:
	_angle += deg_to_rad(rotation_dps.x) * delta
	_angle = lerpf(_angle, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	_angle = clampf(_angle, -0.9, 0.9)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	queue_redraw()


func flash(up: bool, strength: float) -> void:
	_flash = 1.0
	_flash_up = up
	_strength = clampf(strength, 0.0, 1.5)
	if is_zero_approx(_angle):
		_angle = -0.5 if up else 0.5
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		feed(Vector3.ZERO, delta)


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) / 420.0
	# The hands' pivot: a thin line for the ground of the motion.
	draw_arc(c, 150.0 * s, -PI * 0.85, -PI * 0.15, 32, Color(Palette.BONE, 0.15), 3.0)
	# Arrow for the expected direction.
	var up := expect_up
	var ay := c.y - 170.0 * s if up else c.y + 170.0 * s
	var tip := Vector2(c.x + 150.0 * s, ay)
	var d := -1.0 if up else 1.0
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-26.0, -d * 34.0) * s, tip + Vector2(26.0, -d * 34.0) * s]), Palette.EMBER)
	draw_line(tip + Vector2(0.0, -d * 30.0) * s, tip + Vector2(0.0, -d * 110.0) * s, Palette.EMBER, 10.0 * s)
	# The phone, side on, rotated about its lower third (where the hands hold it).
	var xf := Transform2D(_angle, c + Vector2(0.0, 60.0 * s))
	draw_set_transform_matrix(xf)
	var body := Rect2(-20.0 * s, -230.0 * s, 40.0 * s, 300.0 * s)
	var col := Palette.BONE.lerp(Palette.EMBER_HOT, _flash)
	draw_rect(body, Palette.WOOD)
	draw_rect(body, col, false, 6.0 * s)
	draw_line(Vector2(20.0 * s, -200.0 * s), Vector2(20.0 * s, 40.0 * s), Color(col, 0.6), 4.0 * s)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Strength of the last counted tilt.
	if _flash > 0.0:
		var w := 260.0 * s
		var r := Rect2(c.x - w * 0.5, size.y - 26.0, w, 16.0)
		draw_rect(r, Color(Palette.INK, 0.8))
		draw_rect(Rect2(r.position, Vector2(w * clampf(_strength, 0.0, 1.0), 16.0)), Color(Palette.EMBER, _flash))
