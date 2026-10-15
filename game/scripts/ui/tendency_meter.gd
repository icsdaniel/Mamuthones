class_name TendencyMeter
extends Control
## A histogram of hit offsets on the same axis as the lanes: early at the top (the note had not reached
## the line yet), late at the bottom, bars growing to the right. Early bins are cool, late warm, the
## dead zone around the beat bone (UIKit.EARLY / UIKit.LATE, Session.SIDE_DEAD_ZONE), with the median
## marked (a dotted line and an arrowhead on the axis), ticks at the beat and 50 ms either side, so
## the tendency reads at a glance and matches what the player saw in the song.

const SPAN := 0.14
const BINS := 21
const TICK := 0.05   ## the ms ticks either side of the beat

var offsets := PackedFloat32Array():
	set(v):
		offsets = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _bin_of(o: float) -> int:
	return clampi(int((o / SPAN * 0.5 + 0.5) * BINS), 0, BINS - 1)


func _draw() -> void:
	var font := get_theme_font("font", "CaptionLabel")
	var fs := get_theme_font_size("font_size", "CaptionLabel")
	var ticks := [[-TICK, tr("ms_signed") % -roundi(TICK * 1000.0)], [0.0, tr("res_meter_on")], [TICK, tr("ms_signed") % roundi(TICK * 1000.0)]]
	var label_w := 0.0
	if font != null:
		for t in [tr("res_meter_early"), tr("res_meter_late")] + ticks.map(func(x: Array) -> String: return x[1]):
			label_w = maxf(label_w, font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		label_w += 30.0  # room for the median arrowhead between the labels and the axis
	var area := Rect2(label_w, 0.0, maxf(size.x - label_w, 10.0), size.y)
	var h := area.size.y / BINS
	var counts := PackedInt32Array()
	counts.resize(BINS)
	var peak := 1
	for o in offsets:
		var i := _bin_of(o)
		counts[i] += 1
		peak = maxi(peak, counts[i])
	var y_of := func(o: float) -> float: return area.position.y + clampf(o / SPAN * 0.5 + 0.5, 0.0, 1.0) * area.size.y
	# behind the bars: the on-beat band and the tick lines
	var dead := area.size.y * (Session.SIDE_DEAD_ZONE / SPAN) * 0.5
	var cy: float = y_of.call(0.0)
	draw_rect(Rect2(area.position.x, cy - dead, area.size.x, dead * 2.0), Color(Palette.BONE, 0.10))
	for t in ticks:
		var ty: float = roundf(y_of.call(t[0]))
		draw_rect(Rect2(area.position.x, ty - 1.0, area.size.x, 2.0), Color(Palette.BONE, 0.22 if t[0] == 0.0 else 0.12))
	# the median, dotted, behind the bars too
	var med := 0.0
	if offsets.size() >= 4:
		var sorted := offsets.duplicate()
		sorted.sort()
		med = sorted[sorted.size() / 2]
		var my: float = roundf(y_of.call(med))
		var x := area.position.x
		while x < area.end.x:
			draw_rect(Rect2(x, my - 1.0, 6.0, 3.0), Color(Palette.EMBER_HOT, 0.7))
			x += 12.0
	for i in BINS:
		if counts[i] == 0:
			continue
		var centre := (float(i) + 0.5) / BINS * 2.0 * SPAN - SPAN
		var side := UIKit.side_of(centre)
		var col := Palette.BONE if side == "" else UIKit.side_color(side)
		var w := area.size.x * float(counts[i]) / peak
		draw_rect(Rect2(area.position.x + 3.0, area.position.y + i * h + 1.0, w - 3.0, maxf(h - 2.0, 1.0)), col)
	draw_rect(Rect2(area.position.x - 3.0, 0.0, 3.0, size.y), Palette.BONE_DIM)
	if offsets.size() >= 4:
		# the median's marker: a small pixel arrowhead on the axis
		var my: float = roundf(y_of.call(med))
		for r in 4:
			draw_rect(Rect2(area.position.x - 6.0 - 12.0 + r * 3.0, my - (3 - r) * 3.0, 3.0, (3 - r) * 6.0 + 3.0), Palette.EMBER_HOT)
	if font != null:
		var asc := font.get_ascent(fs)
		draw_string(font, Vector2(0.0, asc), tr("res_meter_early"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.EARLY)
		draw_string(font, Vector2(0.0, size.y - font.get_descent(fs)), tr("res_meter_late"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.LATE)
		for t in ticks:
			var ty: float = y_of.call(t[0])
			draw_string(font, Vector2(0.0, ty + asc * 0.5 - 2.0), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Palette.BONE if t[0] == 0.0 else Palette.BONE_DIM)
