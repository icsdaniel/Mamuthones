class_name CountInView
extends Control
## The count-in you see, laid over the procession scene (never over the notes): a big 4-3-2-1 that
## lands with each count-in stick and pulses on its beat, then "Get ready" with the bars left before
## the first note. The play screen tells it what to show each frame; it only draws.

var digit := 0            ## 4..1 while counting in, 0 when not
var ready_bars := 0       ## bars left to the first note after the count ("Get ready"), 0 when not
var beat_phase := 0.0     ## 0..1 through the current beat, for the pulse


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_digit(n: int, phase: float) -> void:
	if n != digit or ready_bars != 0 or absf(phase - beat_phase) > 0.001:
		digit = n
		ready_bars = 0
		beat_phase = phase
		queue_redraw()


func show_ready(bars: int, phase: float) -> void:
	if bars != ready_bars or digit != 0 or absf(phase - beat_phase) > 0.001:
		digit = 0
		ready_bars = bars
		beat_phase = phase
		queue_redraw()


func clear() -> void:
	if digit != 0 or ready_bars != 0:
		digit = 0
		ready_bars = 0
		queue_redraw()


func is_showing() -> bool:
	return digit != 0 or ready_bars != 0


func _draw() -> void:
	if not is_showing():
		return
	var P := PxArt.PX
	var c := (size * 0.5 / P).floor() * P
	var pulse := 1.0 - clampf(beat_phase, 0.0, 1.0)
	if UIKit.reduced_motion():
		pulse *= 0.35
	# the count lands on its beat: a pixel or two up just after it, then settles
	var hop := roundf(2.0 * pulse * pulse) * P
	if digit > 0:
		var txt := str(digit)
		var k := 2 if size.y > PxType.line_height("count") * 2.4 else 1
		var lh := PxType.line_height("count", k)
		var top := c.y - lh * 0.5 - hop
		# the hot flash of the beat: the figure burns white-gold for its first moment
		var col := Color.WHITE if pulse < 0.7 else Color(1.25, 1.2, 1.1)
		PxType.draw(self, "count", Vector2(c.x, top), txt, col, k, 0)
		# four gold pips under it: the count so far
		var y := minf(top + lh + 3.0 * P, size.y - 6.0 * P)
		for i in 4:
			var x := c.x + (float(i) - 1.5) * 9.0 * P
			var lit := i < 5 - digit
			FireSkin.sprite(self, "diamond_hot" if lit and i == 4 - digit else ("diamond_bright" if lit else "diamond_dim"), Vector2(x, y), 1.0, 2)
	else:
		var head := tr("count_ready")
		var lh := PxType.line_height("big_gold")
		PxType.draw(self, "big_gold", Vector2(c.x, c.y - lh - hop), head, Color.WHITE, 1, 0)
		var sub := tr("count_bar_one") if ready_bars == 1 else tr("count_bars") % ready_bars
		PxType.draw(self, "caps", Vector2(c.x, c.y + 2.0 * P), sub, PixelPalette.FIRE[5], 1, 0)
