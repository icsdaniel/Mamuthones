class_name SectionBar
extends Control
## Progress through the song, with a tick at the start of every section (intro, verse, build, climax…):
## a thin line along the top edge of the play screen.

var progress := 0.0:
	set(v):
		if not is_equal_approx(v, progress):
			progress = v
			queue_redraw()
var _marks: Array[float] = []
var _names: Array[String] = []
var _times: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(session: Session) -> void:
	_marks.clear()
	_names.clear()
	_times.clear()
	if session.notes.is_empty():
		return
	var t0 := session.notes[0].t
	var t1 := session.end_time()
	for s in session.song.sections:
		if not (s is Dictionary):
			continue
		var t := session.song.time_of(float(s.get("b", 0.0)), session.remix)
		_times.append(t)
		_names.append(str(s.get("name", "")))
		_marks.append(clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0))
	queue_redraw()


## The name of the section playing at song time t, translated ("" when the song has none).
func section_name(t: float) -> String:
	var name := ""
	for i in _times.size():
		if _times[i] <= t:
			name = _names[i]
	if name == "":
		return ""
	if name.begins_with("lesson_"):
		return tr("tut_%s_title" % name.substr(7))
	# "verse2" -> "Verse 2": the base word is translated, the number kept.
	var base := name.rstrip("0123456789")
	var num := name.substr(base.length())
	var key := "section_" + base
	var out := tr(key)
	if out == key:
		out = base.capitalize()
	return out + (" " + num if num != "" else "")


## A line of pixels along the screen's top edge: a dark groove filling ember to gold as the song goes,
## a tick at each section start (cream once passed), and a hot head where it has got to.
func _draw() -> void:
	var P := PxArt.PX
	draw_rect(Rect2(0.0, 0.0, size.x, 2.0 * P), PixelPalette.K[0])
	draw_rect(Rect2(0.0, 0.0, size.x, P), PixelPalette.NAVY[1])
	var w := floorf(size.x * clampf(progress, 0.0, 1.0) / P) * P
	if w >= P:
		draw_rect(Rect2(0.0, 0.0, w, P), PixelPalette.GOLD[3])
		draw_rect(Rect2(0.0, 0.0, w * 0.5, P), PixelPalette.FIRE[3])
		draw_rect(Rect2(w - 2.0 * P, 0.0, 2.0 * P, P), PixelPalette.FIRE[7])
	for m in _marks:
		if m <= 0.001:
			continue
		var x := floorf(size.x * m / P) * P
		draw_rect(Rect2(x, 0.0, P, 3.0 * P), PixelPalette.K[0])
		draw_rect(Rect2(x, 0.0, P, 2.0 * P), PixelPalette.BONE[3] if m <= progress else PixelPalette.NAVY[3])
