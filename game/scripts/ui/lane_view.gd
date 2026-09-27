class_name LaneView
extends Control
## The three note lanes and the three step buttons, drawn with Art's LaneSkin. The play screen feeds it
## the session and the song time each frame; hits add bursts and button flashes the same frame the
## input arrives (flash() / burst() are called from the input signal handlers, then queue_redraw()).

const BUTTONS_H := 196.0        ## height of the button row
const LOOKAHEAD := 1.5          ## seconds of notes visible at note speed 1.0
const FLASH_TIME := 0.14
const CUE_TIME := 0.22          ## a button is "cued" when its next note is this close
const MARK_TIME := 0.4          ## wrong-lane and rope marks
const TICK_TIME := 1.6          ## timing ticks fade over this long
const STEP_TICK_TIME := 0.3     ## the early/late tick on a step hit fades over this long

var session: Session
var song_time := 0.0
var note_speed := 1.0
var router: InputRouter          ## for pressed state; null in autoplay
var show_buttons := true
var beat_pulse := 0.0

var _bursts: Array = []          ## [pos: Vector2, quality: String, t0: float]
var _flash: Array[float] = [-9.0, -9.0, -9.0]
var _flash_kind: Array[String] = ["hit", "hit", "hit"]
var _auto_pressed: Array[float] = [-9.0, -9.0, -9.0]
var _first := 0                  ## first note that may still be drawn
var _clock := 0.0                ## real seconds, for burst ages while paused
var _offsets: Array = []         ## [offset s, time added, lane] of recent hits, for the timing ticks
var _step_ticks: Array = []      ## [lane, side, time added]: the early/late tick of a step hit
var _marks: Array = []           ## [kind, lane, time]: "wrong" X on a pressed button, "faint" ring on
                                 ## the note it was meant for, "rope" grip across the buttons


func field_rect() -> Rect2:
	var h := size.y - (BUTTONS_H if show_buttons else 0.0)
	return Rect2(Vector2.ZERO, Vector2(size.x, maxf(h, 10.0)))


func buttons_rect() -> Rect2:
	return Rect2(0.0, size.y - BUTTONS_H, size.x, BUTTONS_H)


## Global rect of the button row, for InputRouter.buttons_rect.
func buttons_global_rect() -> Rect2:
	var r := buttons_rect()
	return Rect2(get_global_transform() * r.position, r.size * get_global_transform().get_scale())


func lane_center(lane: int) -> Vector2:
	var rects := LaneSkin.lane_rects(field_rect())
	var r: Rect2 = rects[clampi(lane, 0, 2)]
	return Vector2(r.get_center().x, LaneSkin.hit_line_y(field_rect()))


## Centre of the strip between the hit line and the buttons, under a lane: where judgement words go,
## clear of every note still to come.
func word_spot(lane: int) -> Vector2:
	var f := field_rect()
	var hl := LaneSkin.hit_line_y(f)
	var x := lane_center(lane).x if lane >= 0 else f.get_center().x
	return Vector2(x, hl + (f.end.y - hl) * 0.5)


func reset() -> void:
	_first = 0
	_bursts.clear()
	_step_ticks.clear()


## A button went down (player or autoplay): flash it now.
func press(lane: int) -> void:
	if lane < 0 or lane > 2:
		return
	_auto_pressed[lane] = _clock
	queue_redraw()


func flash(lane: int, good: bool) -> void:
	if lane < 0 or lane > 2:
		return
	_flash[lane] = _clock
	_flash_kind[lane] = "hit" if good else "miss"
	queue_redraw()


## A hit burst at pos. side ("early"/"late") adds a chevron in the early/late pair: up and cool for
## early, down and warm for late.
func burst(pos: Vector2, quality: String, side := "") -> void:
	_bursts.append([pos, quality, _clock, side])
	queue_redraw()


## A judged hit's offset (negative = early), shown as a tick at the lane's hit line: above the line
## for early (where the note still was), below for late.
func add_offset(offset: float, lane := 1) -> void:
	_offsets.append([offset, _clock, lane])
	if _offsets.size() > 24:
		_offsets.pop_front()


## A Good or Ok step hit off time: a small tick at the lane, cool above the hit line when early,
## warm below it when late, gone in STEP_TICK_TIME, so the side reads at a glance without words.
func step_tick(lane: int, side: String) -> void:
	if lane < 0 or lane > 2 or side == "":
		return
	_step_ticks.append([lane, side, _clock])
	if _step_ticks.size() > 6:
		_step_ticks.pop_front()
	queue_redraw()


## The sides of the step ticks still showing ("early"/"late"), oldest first.
func step_ticks_shown() -> Array[String]:
	var out: Array[String] = []
	for k in _step_ticks:
		if _clock - float(k[2]) <= STEP_TICK_TIME:
			out.append(str(k[1]))
	return out


## A step on the wrong lane: a red X on the button actually pressed, and a faint ring where the note
## it was meant for is.
func mark_wrong(pressed_lane: int, note_lane := -1) -> void:
	_marks.append(["wrong", pressed_lane, _clock])
	if note_lane >= 0 and note_lane != pressed_lane:
		_marks.append(["faint", note_lane, _clock])
	queue_redraw()


## A finger landed on the buttons while a rope is due: the rope is "caught" at once, with no step.
func rope_grab(lane: int) -> void:
	_marks.append(["rope", lane, _clock])
	_auto_pressed[clampi(lane, 0, 2)] = _clock
	queue_redraw()


## Marks drawn right now (kind:lane), for tests.
func marks_shown() -> Array[String]:
	var out: Array[String] = []
	for m in _marks:
		if _clock - float(m[2]) < MARK_TIME:
			out.append("%s:%d" % [m[0], m[1]])
	return out


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _px_per_s() -> float:
	var f := field_rect()
	return (LaneSkin.hit_line_y(f) - f.position.y) / (LOOKAHEAD / maxf(note_speed, 0.1))


func _draw() -> void:
	var field := field_rect()
	var glow: Array = [0.0, 0.0, 0.0]
	for lane in 3:
		if _is_pressed(lane):
			glow[lane] = 1.0
		else:
			glow[lane] = clampf(1.0 - (_clock - _flash[lane]) / FLASH_TIME, 0.0, 1.0) * 0.7
	LaneSkin.draw_lanes(self, field, glow)
	LaneSkin.draw_hit_line(self, field, beat_pulse)
	if session != null:
		_draw_notes(field)
	var i := 0
	while i < _bursts.size():
		var b: Array = _bursts[i]
		var q: String = b[1]
		var age := _clock - float(b[2])
		# Early/late keep one language: the woodcut spray of a Good, plus the UI's own chevron.
		var art_q := "good" if q == "early" or q == "late" else q
		if LaneSkin.draw_hit_burst(self, b[0], art_q, age):
			var side: String = b[3] if q != "early" and q != "late" else q
			if side != "":
				_draw_chevron(b[0], side, age)
			i += 1
		else:
			_bursts.remove_at(i)
	_draw_timing_ticks(field)
	_draw_step_ticks(field)
	if show_buttons:
		_draw_buttons()
		_draw_marks()


## Timing ticks on the note axis: each hit leaves a short dash at both edges of its lane, above the
## hit line when early (where the note still was), below when late, cool or warm, fading out. Hits
## inside Core's dead zone sit on the line in bone. The dashes stay at the lane edges, clear of the
## judgement word in the middle.
func _draw_timing_ticks(field: Rect2) -> void:
	if _offsets.is_empty():
		return
	var hl := LaneSkin.hit_line_y(field)
	var reach := minf((field.end.y - hl) * 0.9, 64.0)
	var span := 0.12
	var rects := LaneSkin.lane_rects(field)
	for o in _offsets:
		var age := _clock - float(o[1])
		if age > TICK_TIME:
			continue
		var off := float(o[0])
		var side := UIKit.side_of(off)
		var col := Palette.BONE if side == "" else UIKit.side_color(side)
		var a := clampf(1.0 - age / TICK_TIME, 0.0, 1.0)
		var y := hl + clampf(off / span, -1.0, 1.0) * reach
		var r: Rect2 = rects[clampi(int(o[2]), 0, 2)]
		var dash := minf(r.size.x * 0.14, 34.0)
		for x0 in [r.position.x + 6.0, r.end.x - 6.0 - dash]:
			draw_line(Vector2(x0, y), Vector2(x0 + dash, y), Color(Palette.INK, a * 0.8), 9.0)
			draw_line(Vector2(x0, y), Vector2(x0 + dash, y), Color(col, a), 5.0)


## The step ticks: a bold chevron at both edges of the lane, pointing up and cool above the hit line
## for early (where the note still was), down and warm below it for late, on an ink outline. The
## lane's middle stays clear for the judgement word. They fade out over STEP_TICK_TIME.
func _draw_step_ticks(field: Rect2) -> void:
	if _step_ticks.is_empty():
		return
	var hl := LaneSkin.hit_line_y(field)
	var rects := LaneSkin.lane_rects(field)
	var i := 0
	while i < _step_ticks.size():
		var k: Array = _step_ticks[i]
		var age := _clock - float(k[2])
		if age > STEP_TICK_TIME:
			_step_ticks.remove_at(i)
			continue
		i += 1
		var a := clampf(1.0 - age / STEP_TICK_TIME, 0.0, 1.0)
		var side := str(k[1])
		var d := -1.0 if side == "early" else 1.0
		var r: Rect2 = rects[clampi(int(k[0]), 0, 2)]
		var half := minf(r.size.x * 0.09, 20.0)
		var inset := half + 14.0
		var y := hl + d * 30.0
		var col := UIKit.side_color(side)
		for cx in [r.position.x + inset, r.end.x - inset]:
			var tip := Vector2(cx, y + d * half * 0.8)
			var pts := PackedVector2Array([Vector2(cx - half, y - d * half * 0.2), tip, Vector2(cx + half, y - d * half * 0.2)])
			draw_polyline(pts, Color(Palette.INK, a * 0.9), 16.0, true)
			draw_polyline(pts, Color(col, a), 9.0, true)


## The early/late chevron over a burst: up and cool above the hit for early, down and warm below it
## for late, cut out of an ink outline so it reads on any lane.
func _draw_chevron(pos: Vector2, side: String, age: float) -> void:
	var t := clampf(age / LaneSkin.BURST_TIME, 0.0, 1.0)
	var a := minf(1.0, pow(1.0 - t, 1.2) * 1.3)
	var d := -1.0 if side == "early" else 1.0
	var cp := pos + Vector2(0.0, d * (30.0 + 26.0 * (1.0 - pow(1.0 - t, 3.0))))
	var chev := PackedVector2Array([cp + Vector2(-26.0, -d * 15.0), cp, cp + Vector2(26.0, -d * 15.0)])
	draw_polyline(chev, Color(Palette.INK, a), 17.0, true)
	draw_polyline(chev, Color(UIKit.side_color(side), a), 9.0, true)


func _draw_marks() -> void:
	var i := 0
	var r := buttons_rect()
	var w := r.size.x / 3.0
	while i < _marks.size():
		var m: Array = _marks[i]
		var age := _clock - float(m[2])
		if age > MARK_TIME:
			_marks.remove_at(i)
			continue
		i += 1
		var a := clampf(1.0 - age / MARK_TIME, 0.0, 1.0)
		var lane := clampi(int(m[1]), 0, 2)
		var c := Vector2(r.position.x + w * (lane + 0.5), r.get_center().y)
		match str(m[0]):
			"wrong":
				var s := minf(w, r.size.y) * 0.26
				for dd in [Vector2(s, s), Vector2(s, -s)]:
					draw_line(c - dd, c + dd, Color(Palette.INK, a), 26.0)
					draw_line(c - dd, c + dd, Color("#e2574a", a), 14.0)
			"faint":
				var p := lane_center(lane)
				draw_arc(p, 40.0, 0.0, TAU, 32, Color(Palette.ASH, a * 0.45), 4.0)
			"rope":
				var y := r.position.y + 14.0
				draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y), Color(Palette.ROPE_DARK, a), 16.0)
				draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y), Color(Palette.ROPE, a), 9.0)
				draw_circle(Vector2(c.x, y), 16.0, Color(Palette.ROPE, a))


func _draw_notes(field: Rect2) -> void:
	var t := song_time
	var pps := _px_per_s()
	var horizon := t + (field.size.y / pps)
	var lanes := LaneSkin.lane_rects(field)
	var notes := session.notes
	# Skip notes that are over and gone for good.
	while _first < notes.size() and _gone(notes[_first], t):
		_first += 1
	var rests: Array = []        # [y_a, y_b] of rest bands on screen, labelled after the notes
	var taken: Array[float] = []  # y of every other note drawn, for the labels to avoid
	for i in range(_first, notes.size()):
		var n := notes[i]
		if n.t > horizon:
			break
		if _gone(n, t):
			continue
		var y := LaneSkin.note_y(field, n.t - t, pps)
		if n.kind != Note.Kind.REST and not n.done:
			taken.append(y)
		match n.kind:
			Note.Kind.STEP:
				if not n.done:
					LaneSkin.draw_step(self, lanes[n.lane], y, n.call)
			Note.Kind.HOLD:
				if not n.finished:
					var head := minf(y, LaneSkin.hit_line_y(field)) if n.holding else y
					if n.done and not n.holding:
						continue
					LaneSkin.draw_hold(self, lanes[n.lane], head, LaneSkin.note_y(field, n.end_t - t, pps), n.holding)
			Note.Kind.BELL:
				if not n.done:
					LaneSkin.draw_bell(self, field, y, n.up)
			Note.Kind.RING:
				if not n.done:
					LaneSkin.draw_ring(self, field, lanes[n.lane], y, n.up)
			Note.Kind.SWIPE:
				if not n.done:
					LaneSkin.draw_swipe(self, field, y, n.dir)
			Note.Kind.REST:
				if not n.finished:
					var y_end := LaneSkin.note_y(field, n.end_t - t, pps)
					LaneSkin.draw_rest(self, field, y_end, y)
					rests.append([y_end, y])
	for r in rests:
		_rest_words(field, r[0], r[1], taken)


## Names a stand-still band on the lanes, so a rest reads as an instruction and not as empty
## space: the words sit in the visible part of the band, kept inside the field.
## The label goes in the band's visible part, at the place farthest from every note or bell bar
## crossing it (a bar is BAR_H tall), on an ink backing so it reads over the hatching.
func _rest_words(field: Rect2, y_a: float, y_b: float, taken: Array[float] = []) -> void:
	var top := maxf(minf(y_a, y_b), field.position.y)
	var bottom := minf(maxf(y_a, y_b), LaneSkin.hit_line_y(field))
	if bottom - top < 60.0:
		return
	var font := get_theme_default_font()
	var fs := 34
	var text := tr("lane_still")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var half := fs * 0.75
	var best_y := (top + bottom) * 0.5
	var best_gap := -INF
	var cy := top + half + 8.0
	while cy <= bottom - half - 8.0:
		var gap := INF
		for ty in taken:
			gap = minf(gap, absf(ty - cy))
		if gap > best_gap + 0.5:
			best_gap = gap
			best_y = cy
		cy += 6.0
	var back := Rect2(field.get_center().x - w * 0.5 - 16.0, best_y - half, w + 32.0, half * 2.0)
	draw_rect(back, Color(Palette.INK, 0.72))
	var pos := Vector2(field.get_center().x - w * 0.5, best_y + fs * 0.34)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE)
	_rest_label_y = best_y


var _rest_label_y := NAN   ## last rest label centre (tests)


## A note is gone once it is judged (or over) and has passed the bottom of the field.
func _gone(n: Note, t: float) -> bool:
	match n.kind:
		Note.Kind.HOLD, Note.Kind.REST:
			return n.finished or (n.done and not n.holding) or n.end_t < t - 0.5
	return n.done or n.t < t - 0.5


func _draw_buttons() -> void:
	var r := buttons_rect()
	var w := r.size.x / 3.0
	var pad := 10.0
	for lane in 3:
		var br := Rect2(r.position.x + w * lane + pad, r.position.y + pad, w - pad * 2.0, r.size.y - pad * 2.0)
		LaneSkin.draw_button(self, br, lane, _button_state(lane))


func _button_state(lane: int) -> String:
	if _clock - _flash[lane] < FLASH_TIME:
		return _flash_kind[lane]
	if _is_pressed(lane):
		return "pressed"
	if session != null and _cued(lane):
		return "cued"
	return "idle"


func _is_pressed(lane: int) -> bool:
	if router != null and router.is_pressed(lane):
		return true
	return _clock - _auto_pressed[lane] < 0.08


func _cued(lane: int) -> bool:
	var notes := session.notes
	for i in range(_first, notes.size()):
		var n := notes[i]
		if n.t > song_time + CUE_TIME:
			return false
		if n.lane == lane and not n.done and n.t >= song_time - 0.05:
			return true
	return false
