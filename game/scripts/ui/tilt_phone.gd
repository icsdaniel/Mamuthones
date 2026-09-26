class_name TiltPhone
extends Control
## Live feedback for the tilt calibration: the phone seen from the front, as the player holds it. When
## the real phone tips (read from the gyro), the drawing foreshortens the same way: the top edge grows
## and the face shortens as the top comes toward you, the other way as it goes away. An arrow shows
## which way to tilt next; each counted tilt flashes the screen and shows its strength.

var expect_up := true:
	set(v):
		expect_up = v
		queue_redraw()
var _angle := 0.0        ## radians, positive = top toward the player
var _flash := 0.0
var _strength := 0.0
var _hint := 0.0         ## a slow demonstration nod while waiting for the first move


## Integrates the pitch rate (degrees per second around the phone's x axis) with a leak back to rest,
## so the drawing follows flicks without drifting.
func feed(rotation_dps: Vector3, delta: float) -> void:
	_angle += deg_to_rad(rotation_dps.x) * delta
	_angle = lerpf(_angle, 0.0, clampf(delta * 3.0, 0.0, 1.0))
	_angle = clampf(_angle, -0.9, 0.9)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_hint += delta
	queue_redraw()


func flash(up: bool, strength: float) -> void:
	_flash = 1.0
	_strength = clampf(strength, 0.0, 1.5)
	if absf(_angle) < 0.2:
		_angle = 0.55 if up else -0.55
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		feed(Vector3.ZERO, delta)


func _draw() -> void:
	var c := size * Vector2(0.5, 0.5)
	var s := minf(size.x / 520.0, size.y / 460.0)
	var w := 190.0 * s
	var h := 360.0 * s
	# While nothing moves, nod gently the way the player should, so the picture explains itself.
	var shown := _angle
	if absf(_angle) < 0.02 and _flash <= 0.0:
		shown = (0.35 if expect_up else -0.35) * maxf(sin(_hint * 3.0), 0.0)
	# Perspective: the edge coming toward you widens, the face gets shorter.
	var fh := h * cos(shown)
	var top_w := w * (1.0 + 0.45 * sin(shown))
	var bot_w := w * (1.0 - 0.25 * sin(shown))
	var top := c.y - fh * 0.5
	var bot := c.y + fh * 0.5
	var quad := PackedVector2Array([
		Vector2(c.x - top_w * 0.5, top), Vector2(c.x + top_w * 0.5, top),
		Vector2(c.x + bot_w * 0.5, bot), Vector2(c.x - bot_w * 0.5, bot)])
	draw_colored_polygon(quad, Palette.INK)
	var inset := PackedVector2Array()
	for p in quad:
		inset.append(c + (p - c) * 0.88)
	var glow := Palette.WOOD.lerp(Palette.EMBER, _flash * 0.6)
	draw_colored_polygon(inset, glow)
	var outline := quad.duplicate()
	outline.append(quad[0])
	draw_polyline(outline, Palette.BONE.lerp(Palette.EMBER_HOT, _flash), 6.0 * s)
	# The game on its screen: the mask, squashed with the phone.
	draw_set_transform(c, 0.0, Vector2(1.0, maxf(cos(shown), 0.2)))
	Logo.paint(self, Vector2.ZERO, 70.0 * s, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Thumbs at the bottom corners, where the hands hold it.
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(c.x + side * bot_w * 0.52, bot - 30.0 * s), 26.0 * s, Palette.BONE_DIM)
	# Arrow: which way the top edge should go.
	var up := expect_up
	var ax := c.x + w * 0.5 + 90.0 * s
	var ay0 := c.y + (40.0 if up else -40.0) * s
	var ay1 := c.y + (-110.0 if up else 110.0) * s
	draw_line(Vector2(ax, ay0), Vector2(ax, ay1), Palette.EMBER, 12.0 * s)
	var d := -1.0 if up else 1.0
	var tip := Vector2(ax, ay1 + d * 30.0 * s)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-30.0, -d * 40.0) * s, tip + Vector2(30.0, -d * 40.0) * s]), Palette.EMBER)
	# Strength of the last counted tilt.
	if _flash > 0.0:
		var bw := 260.0 * s
		var r := Rect2(c.x - bw * 0.5, size.y - 20.0, bw, 14.0)
		draw_rect(r, Color(Palette.INK, 0.8))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(_strength, 0.0, 1.0), 14.0)), Color(Palette.EMBER, _flash))
