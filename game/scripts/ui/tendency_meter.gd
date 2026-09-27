class_name TendencyMeter
extends Control
## A histogram of hit offsets on the same axis as the lanes: early at the top (the note had not reached
## the line yet), late at the bottom, bars growing to the right. Early bins are cool, late warm, the
## dead zone around the beat bone (UIKit.EARLY / UIKit.LATE, Session.SIDE_DEAD_ZONE), with the median
## marked, so the tendency reads at a glance and matches what the player saw in the song.

const SPAN := 0.14
const BINS := 21

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
	var label_w := 0.0
	if font != null:
		label_w = maxf(font.get_string_size(tr("res_meter_early"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
			font.get_string_size(tr("res_meter_late"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 16.0
	var area := Rect2(label_w, 0.0, maxf(size.x - label_w, 10.0), size.y)
	var h := area.size.y / BINS
	var cy := area.get_center().y
	var counts := PackedInt32Array()
	counts.resize(BINS)
	var peak := 1
	for o in offsets:
		var i := _bin_of(o)
		counts[i] += 1
		peak = maxi(peak, counts[i])
	var dead := area.size.y * (Session.SIDE_DEAD_ZONE / SPAN) * 0.5
	draw_rect(Rect2(area.position.x, cy - dead, area.size.x, dead * 2.0), Color(Palette.BONE, 0.12))
	for i in BINS:
		if counts[i] == 0:
			continue
		var centre := (float(i) + 0.5) / BINS * 2.0 * SPAN - SPAN
		var side := UIKit.side_of(centre)
		var col := Palette.BONE if side == "" else UIKit.side_color(side)
		var w := area.size.x * float(counts[i]) / peak
		draw_rect(Rect2(area.position.x, area.position.y + i * h + 1.0, w, maxf(h - 2.0, 1.0)), col)
	draw_line(Vector2(area.position.x, 0.0), Vector2(area.position.x, size.y), Palette.BONE_DIM, 2.0)
	draw_line(Vector2(area.position.x, cy), Vector2(size.x, cy), Palette.BONE, 2.0)
	if offsets.size() >= 4:
		var sorted := offsets.duplicate()
		sorted.sort()
		var med: float = sorted[sorted.size() / 2]
		var my := area.position.y + clampf(med / SPAN * 0.5 + 0.5, 0.0, 1.0) * area.size.y
		draw_line(Vector2(area.position.x, my), Vector2(size.x, my), Color(Palette.EMBER_HOT, 0.8), 3.0)
	if font != null:
		draw_string(font, Vector2(0.0, fs + 2.0), tr("res_meter_early"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.EARLY)
		draw_string(font, Vector2(0.0, size.y - 6.0), tr("res_meter_late"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.LATE)
