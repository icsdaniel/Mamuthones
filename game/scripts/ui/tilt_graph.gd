class_name TiltGraph
extends Control
## The last few seconds of the tilt sensor as a rolling trace: tilts toward the player go up, away
## goes down, with the bell threshold as a gold line each way and every ring marked where it fired.
## Calibration shows it so the player can see what rings and what does not: holding the phone should
## stay between the lines, a tilt like the ones in a song should cross them.

const WINDOW := 4.0       ## seconds shown

var threshold := 0.0:     ## °/s (or m/s²); 0 hides the lines
	set(v):
		threshold = v
		queue_redraw()
var now := 0.0
var _t := PackedFloat32Array()
var _v := PackedFloat32Array()
var _rings: Array = []    ## [t, up]
var _peak := 1.0          ## the scale follows the biggest recent reading


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 180)


## One reading at time t: v > 0 is a tilt toward the player.
func push(t: float, v: float) -> void:
	_t.append(t)
	_v.append(v)
	now = maxf(now, t)
	var cut := 0
	while cut < _t.size() and _t[cut] < now - WINDOW:
		cut += 1
	if cut > 0:
		_t = _t.slice(cut)
		_v = _v.slice(cut)
	queue_redraw()


## A ring fired at t, toward the player (up) or away.
func mark(t: float, up: bool) -> void:
	_rings.append([t, up])
	while not _rings.is_empty() and float(_rings[0][0]) < now - WINDOW:
		_rings.pop_front()
	queue_redraw()


func ring_count() -> int:
	return _rings.size()


func _y(v: float) -> float:
	var half := size.y * 0.5
	return half - clampf(v / _peak, -1.0, 1.0) * (half - 6.0)


func _x(t: float) -> float:
	return size.x * (1.0 - (now - t) / WINDOW)


func _draw() -> void:
	var biggest := threshold * 2.2
	for v in _v:
		biggest = maxf(biggest, absf(v) * 1.1)
	_peak = maxf(lerpf(_peak, maxf(biggest, 60.0), 0.2), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.NAVY_DEEP, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), Palette.NAVY_LIGHT, false, 2.0)
	var mid := size.y * 0.5
	draw_line(Vector2(0, mid), Vector2(size.x, mid), Color(Palette.BONE_FAINT, 0.6), 1.0)
	if threshold > 0.0:
		var band := Color(Palette.GOLD, 0.10)
		draw_rect(Rect2(0, _y(threshold), size.x, _y(-threshold) - _y(threshold)), band)
		for s in [1.0, -1.0]:
			draw_dashed_line(Vector2(0, _y(s * threshold)), Vector2(size.x, _y(s * threshold)), Palette.GOLD, 2.0, 10.0)
	for r in _rings:
		var x := _x(float(r[0]))
		var up: bool = r[1]
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(Palette.FIRE_HOT, 0.5), 2.0)
		draw_circle(Vector2(x, 10.0 if up else size.y - 10.0), 7.0, Palette.FIRE_HOT)
	if _t.size() >= 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in _t.size():
			pts.append(Vector2(_x(_t[i]), _y(_v[i])))
			cols.append(Palette.EMBER_HOT if threshold > 0.0 and absf(_v[i]) >= threshold else Palette.BONE)
		draw_polyline_colors(pts, cols, 3.0, true)
	var font := get_theme_font("font", "CaptionLabel")
	var fs := get_theme_font_size("font_size", "CaptionLabel")
	if font != null:
		draw_string(font, Vector2(10, fs + 4), tr("cal_up_label"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE_DIM)
		draw_string(font, Vector2(10, size.y - 8), tr("cal_down_label"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE_DIM)
