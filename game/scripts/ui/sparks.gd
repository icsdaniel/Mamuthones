class_name Sparks
extends Control
## Square pixel sparks for the juice (2026-10-31): thrown out from a point, slowed by the air, pulled
## down (or floating up, for embers) and cooling through their palette as they die. Cheap: one
## draw_rect each, at most MAX alive, and nothing drawn when none are. The HUD and the results use it;
## it never sits over the road, so no spark ever hides a note.

const MAX := 160
const FIRE: Array[Color] = [Color("#fffaf0"), Color("#ffe9a8"), Color("#ffd35a"), Color("#ff9a32"), Color("#c8282a"), Color("#5a1a10")]
const GOLD: Array[Color] = [Color("#ffffff"), Color("#fff2a8"), Color("#ffd35a"), Color("#e8a020"), Color("#8a5200")]
const ASH: Array[Color] = [Color("#ff6a5a"), Color("#c8282a"), Color("#8a7e7a"), Color("#5a4e4e")]

var px := 6.0                 ## a spark's size, px
var _p: Array = []            ## [pos: Vector2, vel: Vector2, age, life, palette, gravity, size]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Throws `count` sparks from `at` (this control's coordinates), at `speed` px/s give or take half,
## aimed around `dir` within `spread` radians (TAU: every way). gravity px/s² (negative floats up).
func burst(at: Vector2, count: int, palette: Array[Color] = FIRE, speed := 260.0, life := 0.6,
		dir := Vector2.UP, spread := TAU, gravity := 520.0, size_k := 1.0) -> void:
	if UIKit.animations_off():
		return
	if UIKit.reduced_motion():
		count = maxi(1, count / 3)
	for i in count:
		if _p.size() >= MAX:
			_p.pop_front()
		var a := dir.angle() + randf_range(-0.5, 0.5) * spread
		var v := Vector2.from_angle(a) * speed * randf_range(0.5, 1.2)
		var s := (2.0 if randf() < 0.25 else 1.0) * size_k
		_p.append([at + Vector2(randf_range(-3, 3), randf_range(-3, 3)), v, 0.0, life * randf_range(0.6, 1.1), palette, gravity, s])
	set_process(true)


## A ring of sparks running out evenly from `at`: a milestone's shock ring.
func ring(at: Vector2, count: int, radius_speed := 300.0, palette: Array[Color] = GOLD, life := 0.45) -> void:
	if UIKit.animations_off():
		return
	for i in count:
		if _p.size() >= MAX:
			_p.pop_front()
		var v := Vector2.from_angle(TAU * float(i) / float(count)) * radius_speed
		_p.append([at, v, 0.0, life, palette, 0.0, 1.0])
	set_process(true)


func alive() -> int:
	return _p.size()


func _process(delta: float) -> void:
	var i := 0
	while i < _p.size():
		var s: Array = _p[i]
		s[2] += delta
		if s[2] >= s[3]:
			_p.remove_at(i)
			continue
		var v: Vector2 = s[1]
		v *= pow(0.12, delta)            # the air slows them
		v.y += float(s[5]) * delta
		s[1] = v
		s[0] += v * delta
		i += 1
	queue_redraw()
	if _p.is_empty():
		set_process(false)


func _draw() -> void:
	for s in _p:
		var k: float = s[2] / s[3]
		var pal: Array = s[4]
		var col: Color = pal[mini(int(k * pal.size()), pal.size() - 1)]
		var sz: float = px * float(s[6]) * (1.0 if k < 0.7 else 0.75)
		var p: Vector2 = s[0]
		draw_rect(Rect2((p / px).floor() * px, Vector2(sz, sz)), col)
