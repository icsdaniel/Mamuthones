class_name CountInView
extends Control
## The count-in you see, laid over the procession scene (never over the notes): a big 4-3-2-1 that
## lands with each count-in stick and pulses on its beat, then "Get ready" with the bars left before
## the first note. The play screen tells it what to show each frame; it only draws.

var digit := 0            ## 4..1 while counting in, 0 when not
var ready_bars := 0       ## bars left to the first note after the count ("Get ready"), 0 when not
var beat_phase := 0.0     ## 0..1 through the current beat, for the pulse
var _font: Font
var _small: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_font = get_theme_font("font", "BigNumberLabel")
	_small = get_theme_font("font", UIKit.HUD)


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
	if not is_showing() or _font == null:
		return
	var c := size * 0.5
	# A dark wash so the digits read over the fire.
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.45))
	var pulse := 1.0 - clampf(beat_phase, 0.0, 1.0)
	if UIKit.reduced_motion():
		pulse = 0.0
	if digit > 0:
		var fs := int(clampf(size.y * 0.62, 96.0, 260.0) * (1.0 + 0.18 * pulse * pulse))
		var txt := str(digit)
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(c.x - w.x * 0.5, c.y + fs * 0.36)
		draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Palette.INK)
		draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.EMBER_HOT.lerp(Palette.BONE, 1.0 - pulse))
		# Four pips under it: the count so far.
		var pr := 12.0
		var gap := 40.0
		for i in 4:
			var x := c.x + (float(i) - 1.5) * gap
			var y := minf(c.y + fs * 0.5 + 18.0, size.y - pr - 6.0)
			var lit := i < 5 - digit
			draw_circle(Vector2(x, y), pr, Palette.EMBER if lit else Color(Palette.BONE_FAINT, 0.8))
	else:
		var head := tr("count_ready")
		var fs := int(clampf(size.y * 0.2, 44.0, 84.0) * (1.0 + 0.08 * pulse))
		var w := _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w * 0.5, c.y)
		draw_string_outline(_font, pos, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Palette.INK)
		draw_string(_font, pos, head, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE)
		if _small != null:
			var sub := tr("count_bar_one") if ready_bars == 1 else tr("count_bars") % ready_bars
			var sfs := 32
			var sw := _small.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x
			var sp := Vector2(c.x - sw * 0.5, c.y + sfs + 18.0)
			draw_string_outline(_small, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, 8, Palette.INK)
			draw_string(_small, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Palette.EMBER)
