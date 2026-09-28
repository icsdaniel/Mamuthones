class_name JudgementWords
extends Control
## The judgement word ("Perfect", "Good", "Late"...) in the strip between the hit line and the buttons,
## never over the notes still coming. A small "early"/"late" follows Perfect and Good when the hit was
## off centre, in the one early/late colour pair (UIKit.EARLY / UIKit.LATE). Words are short-lived
## (about 0.3 s) and one label per spot is reused, so a new word replaces the old one at once.

const LIFE := 0.3
const COLORS := {
	"perfect": Color("#e8d2a4"), "good": Color("#d8ccb4"), "early": UIKit.EARLY,
	"late": UIKit.LATE, "miss": Color("#9a9088"), "held": Color("#f0c878"), "wrong": Color("#e2574a"),
}
const HAIR := Color("#e8b250")      ## the gold hairline round the letters, and the flanking rules

var _fills := {}   # quality -> ShaderMaterial (a light-to-colour gradient over the white fill)
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
		FireSkin.carve_label(w, 44, Color.WHITE, Color(HAIR, 0.95), 8, 0.35)
		FireSkin.carve_label(h, 26, Color.WHITE, Color(0, 0, 0, 0), 6)
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.draw.connect(_draw_rules.bind(box, w))
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
	# Every word is carved the same way: serif small caps with a gold hairline, flanked by gold rules
	# and diamonds; the fill runs from bone at the top into the judgement's own colour.
	w.add_theme_color_override("font_color", Color.WHITE)
	w.add_theme_font_size_override("font_size", 46 if quality == "perfect" else 42)
	if not _fills.has(quality):
		var c: Color = COLORS.get(quality, Palette.BONE)
		_fills[quality] = FireSkin.text_gradient(Color("#fff4dc").lerp(c, 0.25), c.lerp(Color("#fff4dc"), 0.35), c)
	var fill: ShaderMaterial = _fills[quality]
	w.material = fill
	w.reset_size()
	fill.set_shader_parameter("height", maxf(w.get_combined_minimum_size().y, 1.0))
	box.queue_redraw()
	if side != "":
		h.add_theme_color_override("font_color", UIKit.side_color(side))
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var y := at.y - sz.y * 0.5
	# Keep the word and its flanking rules (about 70 px each side) on screen where there is room.
	var m := minf(70.0, maxf((size.x - sz.x) * 0.5, 0.0))
	box.position = Vector2(clampf(at.x - sz.x * 0.5, m, maxf(size.x - sz.x - m, m)), y)
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


## Gold rules either side of the word, each ending in a diamond by the word. Left out when the word
## carries an early/late hint: the lane's early/late ticks stand at its edges then.
func _draw_rules(box: Control, w: Label) -> void:
	if box.get_child_count() > 1 and (box.get_child(1) as Control).visible:
		return
	var y := w.position.y + w.size.y * 0.5 - 2.0
	for sd in [-1.0, 1.0]:
		var x0: float = (-14.0 if sd < 0.0 else box.size.x + 14.0)
		var x1: float = x0 + sd * 46.0
		box.draw_line(Vector2(x0 + sd * 8.0, y), Vector2(x1, y), Color(HAIR, 0.8), 1.5, true)
		box.draw_set_transform(Vector2(x0 + sd * 3.0, y), PI * 0.25)
		box.draw_rect(Rect2(-3.5, -3.5, 7.0, 7.0), HAIR)
		box.draw_set_transform(Vector2.ZERO)


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
