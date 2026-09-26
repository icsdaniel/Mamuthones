class_name JudgementWords
extends Control
## The judgement word over the hit line ("Perfect", "Good", "Late"...), with a small "early"/"late"
## under Perfect and Good when the hit was off centre. One label per spot is reused, so a new word
## replaces the old one at once instead of piling up.

const COLORS := {
	"perfect": Color("#f3cf85"), "good": Color("#ede6da"), "early": Color("#e0a24a"),
	"late": Color("#e0a24a"), "miss": Color("#b9ae9e"), "held": Color("#f3cf85"),
}

var _spots := {}   # int key -> [VBoxContainer, Label, Label, Tween]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_word(word: String, hint: String, at: Vector2, quality: String) -> void:
	var key := int(at.x / 40.0)
	var spot: Array = _spots.get(key, [])
	if spot.is_empty():
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		var h := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_theme_font_size_override("font_size", 24)
		box.add_child(w)
		box.add_child(h)
		add_child(box)
		spot = [box, w, h, null]
		_spots[key] = spot
	var box: VBoxContainer = spot[0]
	var w: Label = spot[1]
	var h: Label = spot[2]
	w.text = word
	h.text = hint
	h.visible = hint != ""
	var c: Color = COLORS.get(quality, Palette.BONE)
	w.add_theme_color_override("font_color", c)
	h.add_theme_color_override("font_color", Palette.EMBER)
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var y := at.y - 150.0
	box.position = Vector2(clampf(at.x - sz.x * 0.5, 0.0, maxf(size.x - sz.x, 0.0)), y)
	box.modulate.a = 1.0
	if spot[3] != null:
		(spot[3] as Tween).kill()
	var tw := box.create_tween()
	spot[3] = tw
	if UIKit.reduced_motion():
		tw.tween_interval(0.45)
		tw.tween_property(box, "modulate:a", 0.0, 0.15)
	else:
		box.pivot_offset = sz * 0.5
		box.scale = Vector2(1.25, 1.25) if quality == "perfect" else Vector2(1.1, 1.1)
		tw.set_parallel()
		tw.tween_property(box, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "position:y", y - 26.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(box, "modulate:a", 0.0, 0.2).set_delay(0.35)
