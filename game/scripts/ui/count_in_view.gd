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
		var col := Color.WHITE if pulse < 0.7 else WoodcutSkin.R
		var dw := PxType.width("count", txt, k) + 8.0 * P
		var dp := Rect2(c.x - dw * 0.5, top - 3.0 * P, dw, lh + 6.0 * P)
		draw_rect(dp.grow(P), WoodcutSkin.C)
		draw_rect(dp, WoodcutSkin.K)
		PxType.draw(self, "count", Vector2(c.x, top), txt, col, k, 0)
		# four gold pips under it: the count so far
		var y := minf(top + lh + 3.0 * P, size.y - 6.0 * P)
		for i in 4:
			var x := c.x + (float(i) - 1.5) * 9.0 * P
			var lit := i < 5 - digit
			var pip := Rect2(x - 3.0 * P, y - 3.0 * P, 6.0 * P, 6.0 * P)
			draw_rect(pip.grow(P), WoodcutSkin.K)
			draw_rect(pip, WoodcutSkin.R if lit and i == 4 - digit else (WoodcutSkin.C if lit else WoodcutSkin.B))
	else:
		var head := tr("count_ready")
		var lh := PxType.line_height("big_gold")
		var sub := tr("count_bar_one") if ready_bars == 1 else tr("count_bars") % ready_bars
		# twice the size: at 1x it was too small to read over the fire (outside review, 2026-10-31)
		var sk := 2 if size.x >= 600.0 else 1
		var sub_h := PxType.line_height("caps", sk)
		# printed on a black plate in a cream rule, so it reads over the street and the fire
		var pw := maxf(PxType.width("big_gold", head), PxType.width("caps", sub, sk)) + 12.0 * P
		var plate := Rect2(c.x - pw * 0.5, c.y - lh - hop - 3.0 * P, pw, lh + sub_h + 9.0 * P)
		draw_rect(plate.grow(P), WoodcutSkin.C)
		draw_rect(plate, WoodcutSkin.K)
		PxType.draw(self, "big_gold", Vector2(c.x, c.y - lh - hop), head, Color.WHITE, 1, 0)
		PxType.draw(self, "caps", Vector2(c.x, c.y + 3.0 * P), sub, WoodcutSkin.R, sk, 0)
