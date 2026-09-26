class_name LaneView
extends Control
## The three note lanes and the three step buttons, drawn with Art's LaneSkin. The play screen feeds it
## the session and the song time each frame; hits add bursts and button flashes the same frame the
## input arrives (flash() / burst() are called from the input signal handlers, then queue_redraw()).

const BUTTONS_H := 196.0        ## height of the button row
const LOOKAHEAD := 1.5          ## seconds of notes visible at note speed 1.0
const FLASH_TIME := 0.14
const CUE_TIME := 0.22          ## a button is "cued" when its next note is this close

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
var _offsets: Array = []         ## [offset s, time added] of recent hits, for the timing meter


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


func reset() -> void:
	_first = 0
	_bursts.clear()


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


func burst(pos: Vector2, quality: String) -> void:
	_bursts.append([pos, quality, _clock])
	queue_redraw()


## A judged hit's offset (negative = early), shown as a tick on the timing meter under the hit line.
func add_offset(offset: float) -> void:
	_offsets.append([offset, _clock])
	if _offsets.size() > 16:
		_offsets.pop_front()


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
		if LaneSkin.draw_hit_burst(self, b[0], b[1], _clock - float(b[2])):
			i += 1
		else:
			_bursts.remove_at(i)
	_draw_timing_meter(field)
	if show_buttons:
		_draw_buttons()


## A small bar centred under the hit line: left is early, right is late. Every hit leaves a tick that
## fades, so the player sees which side their hits fall on without reading anything.
func _draw_timing_meter(field: Rect2) -> void:
	if _offsets.is_empty():
		return
	var y := LaneSkin.hit_line_y(field) + (field.end.y - LaneSkin.hit_line_y(field)) * 0.55
	var half := minf(field.size.x * 0.22, 160.0)
	var cx := field.get_center().x
	var span := 0.14
	draw_line(Vector2(cx - half, y), Vector2(cx + half, y), Color(Palette.BONE, 0.35), 3.0)
	draw_line(Vector2(cx, y - 12.0), Vector2(cx, y + 12.0), Color(Palette.BONE, 0.6), 3.0)
	for o in _offsets:
		var age := _clock - float(o[1])
		if age > 2.5:
			continue
		var x := cx + clampf(float(o[0]) / span, -1.0, 1.0) * half
		var a := clampf(1.0 - age / 2.5, 0.0, 1.0)
		var col := Palette.EMBER_HOT if absf(float(o[0])) < 0.045 else Palette.EMBER
		draw_line(Vector2(x, y - 10.0), Vector2(x, y + 10.0), Color(col, a), 5.0)


func _draw_notes(field: Rect2) -> void:
	var t := song_time
	var pps := _px_per_s()
	var horizon := t + (field.size.y / pps)
	var lanes := LaneSkin.lane_rects(field)
	var notes := session.notes
	# Skip notes that are over and gone for good.
	while _first < notes.size() and _gone(notes[_first], t):
		_first += 1
	for i in range(_first, notes.size()):
		var n := notes[i]
		if n.t > horizon:
			break
		if _gone(n, t):
			continue
		var y := LaneSkin.note_y(field, n.t - t, pps)
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
					_rest_words(field, y_end, y)


## Names a stand-still band on the lanes, so a rest reads as an instruction and not as empty
## space: the words sit in the visible part of the band, kept inside the field.
func _rest_words(field: Rect2, y_a: float, y_b: float) -> void:
	var top := maxf(minf(y_a, y_b), field.position.y)
	var bottom := minf(maxf(y_a, y_b), LaneSkin.hit_line_y(field))
	if bottom - top < 60.0:
		return
	var font := get_theme_default_font()
	var fs := 34
	var text := tr("lane_still")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# Near the top of the band, clear of the judgement words that rise from the hit line.
	var pos := Vector2(field.get_center().x - w * 0.5, top + 30.0 + fs * 0.7)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.BONE)


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
