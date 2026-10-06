class_name UnisonMeter
extends Control
## Six bells for the six unison levels (×1 … ×4), gold up to the current level and dark iron beyond
## it, standing on a gold rule that fills with the streak toward the next level (12 good hits). A
## level gained flares the new bell white-hot for a moment. Pixel art (field sprites hud_bell_*).

const FLARE_TIME := 0.35

var level := 0:
	set(v):
		level = v
		queue_redraw()
var fill := 0.0:
	set(v):
		if not is_equal_approx(v, fill):
			fill = v
			queue_redraw()

var _flare_at := -9.0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The current level's bell flares (called when a level is gained).
func flare() -> void:
	_flare_at = _clock
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if _clock - _flare_at < FLARE_TIME + 0.1:
		queue_redraw()


func _draw() -> void:
	var P := PxArt.PX
	var n := Session.UNISON_MULTS.size()
	var step := floorf(size.x / float(n) / P) * P
	var hot := _clock - _flare_at < FLARE_TIME
	for i in n:
		var c := Vector2(step * (float(i) + 0.5), 6.0 * P)
		c = Vector2(roundf(c.x / P) * P, c.y)
		var st := "lit" if i <= level else "dark"
		if hot and i == level:
			st = "hot"
		FireSkin.sprite(self, "hud_bell_" + st, c)
	# the rule under the bells: dark, filling gold with the streak
	var y := 13.0 * P
	var x0 := step * 0.25
	var w := floorf((step * float(n) - step * 0.5) / P) * P
	draw_rect(Rect2(x0 - P, y - P, w + 2.0 * P, 3.0 * P), PixelPalette.K[0])
	draw_rect(Rect2(x0, y, w, P), PixelPalette.GOLD[1])
	var fw := floorf(w * clampf(fill, 0.0, 1.0) / P) * P
	if fw > 0.0:
		draw_rect(Rect2(x0, y, fw, P), PixelPalette.GOLD[4])
