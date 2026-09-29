class_name JudgementWords
extends Control
## The judgement word ("Perfect", "Good", "Late"...) in the strip between the hit line and the buttons,
## never over the notes still coming. A small "early"/"late" follows Perfect and Good when the hit was
## off centre, in the one early/late colour pair (UIKit.EARLY / UIKit.LATE). Words are short-lived
## (about 0.3 s) and one label per spot is reused, so a new word replaces the old one at once.
## Two lanes judged together never print over each other: the same word is written once between
## them, different words drop to the smaller caps face, and an older word in the way (not a chord)
## makes room for the new one.

const LIFE := 0.3
## The word's ink: the big pixel face tinted (white = the cream-to-gold face for perfect and held).
const COLORS := {
	"perfect": Color.WHITE, "good": Color("#ecdfbc"), "early": UIKit.EARLY,
	"late": UIKit.LATE, "miss": Color("#8a7c6c"), "held": Color.WHITE, "wrong": Color("#e24a32"),
}
const HAIR := Color("#c08a2e")      ## the flanking gold rules (GOLD3)
const CHORD_MS := 80                ## words this close together belong to one chord

var _spots := {}   # int key -> [HBoxContainer, Label, Label, Tween, centre: Vector2, quality: String, shown at: ms]


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
		box.add_theme_constant_override("separation", 9)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		var h := UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_CENTER)
		PxType.label(w, "big")
		PxType.label(h, "caps")
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.draw.connect(_draw_rules.bind(box, w))
		box.add_child(w)
		box.add_child(h)
		add_child(box)
		spot = [box, w, h, null, at, quality, 0]
		_spots[key] = spot
	var box: HBoxContainer = spot[0]
	var w: Label = spot[1]
	var h: Label = spot[2]
	w.text = word
	h.text = tr("judge_hint_" + side) if side != "" else ""
	h.visible = side != ""
	spot[4] = at
	spot[5] = quality
	spot[6] = Time.get_ticks_msec()
	w.add_theme_color_override("font_color", COLORS.get(quality, Palette.BONE))
	if side != "":
		h.add_theme_color_override("font_color", UIKit.side_color(side))
	_set_face(spot, false)
	var y := _place(spot)
	# A word already standing where this one would go (a chord: two lanes judged together).
	for other in _spots.values():
		if other == spot or (other[0] as Control).modulate.a < 0.5:
			continue
		var ob: Control = other[0]
		if absf((other[4] as Vector2).y - at.y) > 4.0 or not _overlaps(ob, box):
			continue
		if Time.get_ticks_msec() - int(other[6]) > CHORD_MS:
			# an older word: it gives way at once
			ob.modulate.a = 0.0
			if other[3] != null:
				(other[3] as Tween).kill()
			continue
		if (other[1] as Label).text == word and not h.visible and not (other[2] as Label).visible:
			# the same word: write it once, between the two lanes
			other[4] = Vector2(((other[4] as Vector2).x + at.x) * 0.5, at.y)
			_place(other)
			box.modulate.a = 0.0
			if spot[3] != null:
				(spot[3] as Tween).kill()
			return
		# different words: both in the smaller face
		_set_face(other, true)
		_place(other)
		_set_face(spot, true)
		y = _place(spot)
	box.modulate.a = 1.0
	box.scale = Vector2.ONE
	if spot[3] != null:
		(spot[3] as Tween).kill()
	var tw := box.create_tween()
	spot[3] = tw
	if not UIKit.reduced_motion():
		# the word lands: it drops in from two art pixels up (a perfect from three), in whole pixels
		var lift := 3.0 if quality == "perfect" else 2.0
		box.position.y = y - lift * PxArt.PX
		tw.tween_method(_drop.bind(box, y), lift, 0.0, 0.09)
	tw.tween_interval(maxf(life - 0.18, 0.05))
	tw.tween_property(box, "modulate:a", 0.0, 0.12)


## Sets the word's face: the big pixel small caps in a K0 outline with a drop shadow (`small`: the
## plain caps face, two lanes' words side by side); perfect and held in the cream-to-gold face, the
## rest tinted.
func _set_face(spot: Array, small: bool) -> void:
	var w: Label = spot[1]
	var gold: bool = spot[5] == "perfect" or spot[5] == "held"
	var face := ("caps" if small else "big") + ("_gold" if gold else "")
	PxType.label(w, face, COLORS.get(spot[5], Palette.BONE))
	w.reset_size()
	(spot[0] as Control).queue_redraw()


## Puts the spot's box centred on its centre, on the art grid and on screen; returns its top.
func _place(spot: Array) -> float:
	var box: Control = spot[0]
	var at: Vector2 = spot[4]
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var y := roundf((at.y - sz.y * 0.5) / PxArt.PX) * PxArt.PX
	# Keep the word and its flanking rules (about 70 px each side) on screen where there is room.
	var m := minf(70.0, maxf((size.x - sz.x) * 0.5, 0.0))
	var x := roundf(clampf(at.x - sz.x * 0.5, m, maxf(size.x - sz.x - m, m)) / PxArt.PX) * PxArt.PX
	box.position = Vector2(x, y)
	return y


## Whether two word boxes (with their flanking rules, 18 art px each side) would touch.
static func _overlaps(a: Control, b: Control) -> bool:
	var pad := 18.0 * PxArt.PX
	var ra := Rect2(a.position, a.get_combined_minimum_size()).grow_individual(pad, 0.0, pad, 0.0)
	var rb := Rect2(b.position, b.get_combined_minimum_size()).grow_individual(pad, 0.0, pad, 0.0)
	return ra.intersects(rb)


## Gold rules either side of the word, each ending in a diamond by the word. Left out when the word
## carries an early/late hint: the lane's early/late ticks stand at its edges then.
func _draw_rules(box: Control, w: Label) -> void:
	if box.get_child_count() > 1 and (box.get_child(1) as Control).visible:
		return
	var P := PxArt.PX
	var y := roundf((w.position.y + w.size.y * 0.5) / P) * P
	for sd in [-1.0, 1.0]:
		var x0: float = (-5.0 * P if sd < 0.0 else box.size.x + 4.0 * P)
		var x1: float = x0 + sd * 14.0 * P
		var r := Rect2(minf(x0 + sd * 3.0 * P, x1), y, absf(x1 - x0 - sd * 3.0 * P), P)
		box.draw_rect(r.grow(P), PixelPalette.K[0])
		box.draw_rect(r, HAIR)
		FireSkin.sprite(box, "diamond", Vector2(x0 + P * 0.5, y + P * 0.5))


## The landing drop, stepped to whole art pixels.
static func _drop(v: float, box: Control, y: float) -> void:
	box.position.y = y - roundf(v) * PxArt.PX


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
