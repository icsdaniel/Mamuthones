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
	var key := "section_" + name
	var out := tr(key)
	return out if out != key else name.capitalize()


func _draw() -> void:
	var h := size.y * 0.5
	var y := (size.y - h) * 0.5
	draw_rect(Rect2(0.0, y, size.x, h), Color(Palette.INK, 0.75))
	draw_rect(Rect2(0.0, y, size.x * progress, h), Palette.RED)
	draw_rect(Rect2(0.0, y, size.x, h), Color(Palette.BONE, 0.5), false, 2.0)
	for m in _marks:
		if m <= 0.001:
			continue
		var x := size.x * m
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Palette.BONE if m <= progress else Palette.BONE_DIM, 3.0)
