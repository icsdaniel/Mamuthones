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


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)


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
	var P := PxArt.PX
	var a := 1.0
	if _t > IN + HOLD:
		a = clampf(1.0 - (_t - IN - HOLD) / OUT, 0.0, 1.0)
	var grow := 1.0 if UIKit.reduced_motion() else 1.0 - pow(1.0 - clampf(_t / (IN * 2.0), 0.0, 1.0), 3.0)
	var cy := roundf(maxf(size.y * 0.3, 70.0) / P) * P   # above the row's heads
	var band_h := 36.0 * P
	var band_w := floorf(size.x * grow / (2.0 * P)) * 2.0 * P
	var x0 := roundf((size.x - band_w) * 0.5 / P) * P
	# a navy band closed by gold rules, drawn across from the middle, then fading out in steps
	if a < 1.0 and PxArt.bayer(int(_t * 30.0), 1) > a:
		return
	var top := cy - band_h * 0.5
	draw_rect(Rect2(x0, top, band_w, band_h), PixelPalette.NAVY[0])
	for y in [top, top + band_h - 3.0 * P]:
		draw_rect(Rect2(x0, y, band_w, P), PixelPalette.K[0])
		draw_rect(Rect2(x0, y + P, band_w, P), PixelPalette.GOLD[3])
		draw_rect(Rect2(x0, y + 2.0 * P, band_w, P), PixelPalette.K[0])
	if grow < 0.95:
		return
	var face := "big_gold"
	if PxType.width(face, text) > size.x - 16.0 * P:
		face = "caps_gold"
	var lh := PxType.line_height(face)
	PxType.draw(self, face, Vector2(size.x * 0.5, cy - lh + 2.0 * P), text, Color.WHITE, 1, 0)
	if points != "":
		PxType.draw(self, "score", Vector2(size.x * 0.5, cy + 4.0 * P), points, Color.WHITE, 1, 0)
