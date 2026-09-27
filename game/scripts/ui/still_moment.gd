class_name StillMoment
extends Control
## The moment a stand-still is kept: over the procession (never over the notes), a band of ink
## draws across and "The row stands as one" is written on it with the points it earned, held
## briefly while the row settles, then gone. The play screen calls play(); it only draws.

const IN := 0.15
const HOLD := 1.0
const OUT := 0.35

var text := ""
var points := ""
var _t := -1.0            ## seconds since play(), -1 when idle
var _font: Font
var _small: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


func _ready() -> void:
	_font = get_theme_font("font", UIKit.HEADER)
	_small = get_theme_font("font", UIKit.HUD)


func play(p_text: String, p_points: String) -> void:
	text = p_text
	points = p_points
	_t = 0.0
	set_process(true)
	queue_redraw()


## Gone at once (a restart, or a picture that should not show it).
func clear() -> void:
	_t = -1.0
	set_process(false)
	queue_redraw()


## The text showing now ("" when idle), for tests.
func shown() -> String:
	return text if _t >= 0.0 and _t < IN + HOLD + OUT else ""


func _process(delta: float) -> void:
	_t += delta
	if _t >= IN + HOLD + OUT:
		_t = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _t < 0.0 or text == "":
		return
	var a := 1.0
	if _t < IN:
		a = _t / IN
	elif _t > IN + HOLD:
		a = clampf(1.0 - (_t - IN - HOLD) / OUT, 0.0, 1.0)
	var grow := 1.0 if UIKit.reduced_motion() else 1.0 - pow(1.0 - clampf(_t / (IN * 2.0), 0.0, 1.0), 3.0)
	var fs := 46
	var fs2 := 30
	var cy := maxf(size.y * 0.3, 70.0)   # above the row's heads
	var band_h := 124.0
	var band_w := size.x * grow
	draw_rect(Rect2((size.x - band_w) * 0.5, cy - band_h * 0.5, band_w, band_h), Color(Palette.INK, 0.72 * a))
	# hairlines above and below, in the gold of a kept stand-still
	var gold := Color("#f3cf85")
	for dy in [-band_h * 0.5 + 6.0, band_h * 0.5 - 6.0]:
		draw_line(Vector2((size.x - band_w) * 0.5 + 24.0, cy + dy), Vector2((size.x + band_w) * 0.5 - 24.0, cy + dy), Color(gold, 0.7 * a), 2.0)
	if _font == null:
		return
	var w := size.x - 48.0
	while fs > 26 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 2
	var base := cy - 4.0
	draw_string(_font, Vector2(24.0, base), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(Palette.BONE, a))
	if points != "" and _small != null:
		draw_string(_small, Vector2(24.0, base + 44.0), points, HORIZONTAL_ALIGNMENT_CENTER, w, fs2, Color(gold, a))
