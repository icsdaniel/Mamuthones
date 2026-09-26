class_name BellMarks
extends Control
## Up to three small cowbells: earned ones in ember ink, the rest as empty outlines. Used for a stop's
## best, a difficulty's best and the results. `animate()` rings them in one by one.

var count := 0:
	set(v):
		count = clampi(v, 0, 3)
		queue_redraw()
var total := 3
var bell_size := 44.0
var _pop: Array[float] = [1.0, 1.0, 1.0]


func _init(p_count := 0, p_size := 44.0) -> void:
	count = p_count
	bell_size = p_size
	custom_minimum_size = Vector2(p_size * 3.4, p_size * 1.15)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pop the earned bells in turn, ringing one each.
func animate(delay := 0.3, ring := true) -> void:
	for i in count:
		_pop[i] = 0.0
	queue_redraw()
	for i in count:
		var tw := create_tween()
		tw.tween_interval(delay + i * 0.35)
		if ring:
			tw.tween_callback(func() -> void: Sound.bell(Profile.get_look().get("bell_set", "light"), i % 2 == 0, "perfect"))
		tw.tween_method(func(v: float) -> void:
			_pop[i] = v
			queue_redraw(), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var step := size.x / float(total)
	for i in total:
		var c := Vector2(step * (i + 0.5), size.y * 0.5)
		var earned := i < count
		var s := bell_size * (lerpf(0.3, 1.0, _pop[i]) if earned else 1.0)
		_draw_bell(c, s, earned)


func _draw_bell(c: Vector2, s: float, earned: bool) -> void:
	# A cowbell: flared trapezoid body, a strap loop on top, a clapper below.
	var w_top := s * 0.42
	var w_bot := s * 0.78
	var h := s * 0.78
	var top := c.y - h * 0.5
	var bot := c.y + h * 0.5
	var body := PackedVector2Array([
		Vector2(c.x - w_top * 0.5, top), Vector2(c.x + w_top * 0.5, top),
		Vector2(c.x + w_bot * 0.5, bot), Vector2(c.x - w_bot * 0.5, bot)])
	var ink := Palette.EMBER if earned else Palette.BONE_FAINT
	if earned:
		draw_colored_polygon(body, ink)
		draw_line(Vector2(c.x - w_bot * 0.32, bot - h * 0.3), Vector2(c.x - w_top * 0.2, top + h * 0.2), Palette.EMBER_HOT, 2.0)
	else:
		var loop := body.duplicate()
		loop.append(body[0])
		draw_polyline(loop, ink, 3.0)
	draw_arc(Vector2(c.x, top), s * 0.14, PI, TAU, 10, ink, 3.0)
	draw_circle(Vector2(c.x, bot + s * 0.06), s * 0.08, ink)
