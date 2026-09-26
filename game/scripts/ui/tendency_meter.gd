class_name TendencyMeter
extends Control
## A histogram of hit offsets from early (left) to late (right), with the perfect window shaded and the
## median marked, so the tendency reads at a glance.

const SPAN := 0.14
const BINS := 21

var offsets := PackedFloat32Array():
	set(v):
		offsets = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_font("font", "CaptionLabel")
	var fs := get_theme_font_size("font_size", "CaptionLabel")
	var label_h := float(fs) + 4.0
	var area := Rect2(0.0, 0.0, size.x, size.y - label_h)
	var perfect_w := area.size.x * (0.045 / SPAN) * 0.5
	var cx := area.get_center().x
	draw_rect(Rect2(cx - perfect_w, area.position.y, perfect_w * 2.0, area.size.y), Color(Palette.EMBER, 0.15))
	var counts := PackedInt32Array()
	counts.resize(BINS)
	var peak := 1
	for o in offsets:
		var i := clampi(int((o / SPAN * 0.5 + 0.5) * BINS), 0, BINS - 1)
		counts[i] += 1
		peak = maxi(peak, counts[i])
	var w := area.size.x / BINS
	for i in BINS:
		if counts[i] == 0:
			continue
		var h := area.size.y * float(counts[i]) / peak
		var x := i * w
		var col := Palette.EMBER_HOT if absf(i - (BINS - 1) * 0.5) <= 3.0 else Palette.EMBER
		draw_rect(Rect2(x + 1.0, area.end.y - h, w - 2.0, h), col)
	draw_line(Vector2(0.0, area.end.y), Vector2(size.x, area.end.y), Palette.BONE_DIM, 2.0)
	draw_line(Vector2(cx, area.position.y), Vector2(cx, area.end.y), Palette.BONE, 2.0)
	if font != null:
		draw_string(font, Vector2(0.0, size.y - 4.0), tr("res_meter_early"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE_DIM)
		draw_string(font, Vector2(0.0, size.y - 4.0), tr("res_meter_late"), HORIZONTAL_ALIGNMENT_RIGHT, size.x, fs, Palette.BONE_DIM)
