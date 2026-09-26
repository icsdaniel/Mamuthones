class_name JudgementWords
extends Control
## The judgement word ("Perfect", "Good", "Late"...) in the strip between the hit line and the buttons,
## never over the notes still coming. A small "early"/"late" follows Perfect and Good when the hit was
## off centre, in the one early/late colour pair (UIKit.EARLY / UIKit.LATE). Words are short-lived
## (about 0.3 s) and one label per spot is reused, so a new word replaces the old one at once.

const LIFE := 0.3
const COLORS := {
	"perfect": Color("#f3cf85"), "good": Color("#ede6da"), "early": UIKit.EARLY,
	"late": UIKit.LATE, "miss": Color("#b9ae9e"), "held": Color("#f3cf85"), "wrong": Color("#e2574a"),
}

var _spots := {}   # int key -> [HBoxContainer, Label, Label, Tween]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## at: the centre of the word (the lane's centre in the strip under the hit line).
## side: "early", "late" or "" for the small hint after the word.
func show_word(word: String, side: String, at: Vector2, quality: String, life := LIFE) -> void:
	var key := int(at.x / 40.0)
	var spot: Array = _spots.get(key, [])
	if spot.is_empty():
		var box := HBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		var h := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_theme_font_size_override("font_size", 24)
		h.size_flags_vertical = Control.SIZE_SHRINK_END
		box.add_child(w)
		box.add_child(h)
		add_child(box)
		spot = [box, w, h, null]
		_spots[key] = spot
	var box: HBoxContainer = spot[0]
	var w: Label = spot[1]
	var h: Label = spot[2]
	w.text = word
	h.text = tr("judge_hint_" + side) if side != "" else ""
	h.visible = side != ""
	w.add_theme_color_override("font_color", COLORS.get(quality, Palette.BONE))
	if side != "":
		h.add_theme_color_override("font_color", UIKit.side_color(side))
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var y := at.y - sz.y * 0.5
	box.position = Vector2(clampf(at.x - sz.x * 0.5, 0.0, maxf(size.x - sz.x, 0.0)), y)
	box.modulate.a = 1.0
	box.scale = Vector2.ONE
	if spot[3] != null:
		(spot[3] as Tween).kill()
	var tw := box.create_tween()
	spot[3] = tw
	if not UIKit.reduced_motion():
		box.pivot_offset = sz * 0.5
		box.scale = Vector2(1.2, 1.2) if quality == "perfect" else Vector2(1.08, 1.08)
		tw.tween_property(box, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(life - 0.18, 0.05))
	tw.tween_property(box, "modulate:a", 0.0, 0.12)


## The texts shown right now (word/hint), for tests.
func shown() -> Array[String]:
	var out: Array[String] = []
	for spot in _spots.values():
		if (spot[0] as Control).modulate.a > 0.5:
			out.append((spot[1] as Label).text + "/" + (spot[2] as Label).text)
	return out


## Global rects of the words shown right now, for tests.
func shown_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for spot in _spots.values():
		if (spot[0] as Control).modulate.a > 0.5:
			out.append((spot[0] as Control).get_global_rect())
	return out
