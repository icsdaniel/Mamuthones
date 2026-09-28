class_name SectionBar
extends Control
## Progress through the song, with a tick at the start of every section (intro, verse, build, climax…).

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


func _draw() -> void:
	var h := 14.0
	var y := (size.y - h) * 0.5
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("#120a18")
	groove.border_color = Color("#a8702a")
	groove.set_border_width_all(2)
	groove.set_corner_radius_all(9)
	draw_style_box(groove, Rect2(-3.0, y - 3.0, size.x + 6.0, h + 6.0))
	var w := size.x * clampf(progress, 0.0, 1.0)
	if w > 1.0:
		# Red to ember to gold, a sheen along the top, and a glowing head.
		var c0 := Color("#8a0d14")
		var c1 := Color("#e0321f")
		var c2 := Color("#ffb13a")
		var xm := w * 0.7
		draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(xm, y), Vector2(xm, y + h), Vector2(0, y + h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(xm, y), Vector2(w, y), Vector2(w, y + h), Vector2(xm, y + h)]), PackedColorArray([c1, c2, c2, c1]))
		draw_rect(Rect2(3.0, y + 2.0, maxf(w - 6.0, 0.0), 3.0), Color(1, 1, 1, 0.35))
	for m in _marks:
		if m <= 0.001:
			continue
		var x := size.x * m
		draw_rect(Rect2(x - 1.5, y - 5.0, 3.0, h + 10.0), Color("#fff0c8") if m <= progress else Color("#6a5a70"))
	if w > 1.0:
		var g := FireSkin.glow()
		draw_texture_rect(g, Rect2(w - 24.0, y + h * 0.5 - 24.0, 48.0, 48.0), false, Color(1.0, 0.6, 0.2, 0.9))
		draw_texture_rect(g, Rect2(w - 10.0, y + h * 0.5 - 10.0, 20.0, 20.0), false, Color(1.0, 0.97, 0.85, 1.0))
