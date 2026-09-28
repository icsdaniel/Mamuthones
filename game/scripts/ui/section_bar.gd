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


## A 4 px line along the screen's top edge: dark, filling ember to gold, a tick at each section start
## (bone once passed), and a glowing head.
func _draw() -> void:
	var h := 4.0
	draw_rect(Rect2(0.0, 0.0, size.x, h), Color(0.12, 0.07, 0.13, 0.95))
	var w := size.x * clampf(progress, 0.0, 1.0)
	if w > 1.0:
		var c0 := Color("#7a2a0c")
		var c1 := Color("#ffc86a")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c0, c1, c1, c0]))
	for m in _marks:
		if m <= 0.001:
			continue
		var x := size.x * m
		draw_rect(Rect2(x - 1.0, 0.0, 2.0, 8.0), Color("#fff0c8") if m <= progress else Color("#6a5a70"))
	if w > 1.0:
		var g := FireSkin.glow()
		draw_texture_rect(g, Rect2(w - 18.0, -16.0, 36.0, 36.0), false, Color(1.0, 0.9, 0.67, 0.9))
