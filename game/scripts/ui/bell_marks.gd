class_name BellMarks
extends Control
## Up to three small bronze cowbells in pixel art (tools/art/pixel/ui_kit.py): earned ones in bronze, the
## rest as hollow outlines. Used for the calibration's counted tilts and the unlock celebration (run
## grades are letters: GradeBadge). `animate()`
## pops them in one by one on the art grid (1, 2, 3, 4 then 3 pixels a pixel), ringing each.

## One earned bell has popped in (index 0..2): for sounds and screen juice.
signal popped(index: int)

var count := 0:
	set(v):
		count = clampi(v, 0, 3)
		queue_redraw()
var total := 3
var bell_size := 44.0
var empty_color := Palette.BONE_FAINT   ## kept for callers; the empty bell is its own sprite
var _pop: Array[float] = [1.0, 1.0, 1.0]
var _full: Texture2D
var _empty: Texture2D

const PX := 3


func _init(p_count := 0, p_size := 44.0) -> void:
	count = p_count
	bell_size = p_size
	var big := p_size >= 48.0
	_full = Palette.ui("bell_big" if big else "bell_small")
	_empty = Palette.ui("bell_big_empty" if big else "bell_small_empty")
	var cell := (_full.get_size() if _full != null else Vector2(11, 12)) * PX
	custom_minimum_size = Vector2(cell.x * 3.0 + 6.0 * (2 if big else 1), cell.y + (6.0 if big else 0.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pop the earned bells in turn, ringing one each.
func animate(delay := 0.3, ring := true) -> void:
	for i in count:
		_pop[i] = 0.0
	queue_redraw()
	for i in count:
		var tw := create_tween()
		tw.tween_interval(delay + i * 0.35)
		tw.tween_callback(func() -> void:
			if ring:
				Sound.bell(BellSets.STANDARD, i % 2 == 0, "perfect")
			popped.emit(i))
		tw.tween_method(func(v: float) -> void:
			_pop[i] = v
			queue_redraw(), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _full == null:
		return
	var cell := _full.get_size() * PX
	var gap := (size.x - cell.x * total) / maxf(total - 1, 1)
	for i in total:
		var earned := i < count
		var tex := _full if earned else _empty
		var k := PX
		if earned and _pop[i] <= 0.0:
			tex = _empty
		elif earned and _pop[i] < 1.0:
			k = clampi(roundi(1.0 + 2.6 * _pop[i]), 1, PX + 1)
		elif earned and _pop[i] > 1.0:
			k = PX + 1
		var sz := tex.get_size() * k
		var c := Vector2(i * (cell.x + gap) + cell.x * 0.5, size.y * 0.5)
		draw_texture_rect(tex, Rect2((c - sz * 0.5).round(), sz), false)
