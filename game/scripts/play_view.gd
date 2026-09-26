class_name PlayView
extends Control
## One play of a song: plays the audio, reads taps, swipes, keys and tilts,
## hands them to the Session and draws the procession.
##
## Keyboard, for playing on a computer: A S D step, Space bell, Q/E swipe left/right, Esc quit.

signal finished(session: Session)
signal quit_requested

const AHEAD := 2.0            ## seconds of notes visible above the hit line
const HUD_H := 120.0
const PADS_H := 250.0
const SWIPE_SHARE := 0.4      ## a swipe crosses this share of the button row
const KEY_TOUCH := 1000       ## touch ids used for keyboard steps
const AUTO_TOUCH := 2000      ## touch ids used by autoplay
const LANE_NAMES := ["LEFT", "MIDDLE", "RIGHT"]
const DRONES := ["drone_left", "drone_middle", "drone_right"]
const STEPS := ["step_left", "step_middle", "step_right"]

var session: Session
var autoplay := false
var audio_offset := 0.0       ## seconds; later the headphone delay test sets it

var _song: Dictionary
var _detector: BellDetector
var _motion := MotionReader.new()
var _music: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _drones: Array[AudioStreamPlayer] = []
var _sounds := {}
var _t := -1.0
var _touches := {}            ## touch index -> { x0, fired }
var _pad_hit_at := [-9.0, -9.0, -9.0]
var _judge := { word = "", color = Palette.BONE, at = -9.0 }
var _ended := false
var _font: Font


func setup(song: Dictionary, calibration: Dictionary, p_autoplay := false) -> void:
	_song = song
	autoplay = p_autoplay
	session = Session.new(song)
	if not calibration.is_empty():
		_detector = BellDetector.new(calibration, float(song.bpm))


func _ready() -> void:
	name = "PlayView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	for s in STEPS + ["bell_up", "bell_down", "call", "whoosh"]:
		_sounds[s] = load("res://audio/%s.wav" % s)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	for d in DRONES:
		var p := AudioStreamPlayer.new()
		var wav: AudioStreamWAV = load("res://audio/%s.wav" % d).duplicate()
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.mix_rate  # the drones are exactly one second long
		p.stream = wav
		p.volume_db = -6.0
		add_child(p)
		_drones.append(p)
	session.judged.connect(_on_judged)
	session.hold_started.connect(func(lane: int): _drones[lane].play())
	session.hold_ended.connect(func(lane: int): _drones[lane].stop())
	_music = AudioStreamPlayer.new()
	_music.stream = load(_song.audio)
	add_child(_music)
	_music.play()
	_t = 0.0


func song_time() -> float:
	return _t


func _process(delta: float) -> void:
	if _ended:
		return
	_advance_clock(delta)
	if autoplay:
		_autoplay()
	elif _detector != null:
		var m := _motion.read()
		if _detector.feed(_t, m[0], m[1]):
			_ring()
	session.update(_t)
	queue_redraw()
	if session.is_over(_t):
		_ended = true
		for d in _drones:
			d.stop()
		finished.emit(session)


## Song time follows the audio the player hears; between audio updates it runs on frame time.
func _advance_clock(delta: float) -> void:
	var t := _t + delta
	if _music.playing and _music.get_playback_position() > 0.0:
		var heard := _music.get_playback_position() + AudioServer.get_time_since_last_mix() \
				- AudioServer.get_output_latency() - audio_offset
		t = heard if absf(heard - t) > 0.1 else lerpf(t, heard, 0.2)
	_t = maxf(_t, t)  # never step backwards


func _autoplay() -> void:
	for n in session.notes:
		if n.t > _t:
			break
		if n.done:
			continue
		match n.kind:
			Note.Kind.STEP, Note.Kind.HOLD:
				_step(n.lane, AUTO_TOUCH + n.lane)
				if n.kind == Note.Kind.STEP:
					session.release(_t, AUTO_TOUCH + n.lane)
			Note.Kind.BELL:
				_ring()
			Note.Kind.SWIPE:
				_play("whoosh")
				session.swipe(n.right, _t)


func _step(lane: int, touch_id: int) -> void:
	_play(STEPS[lane])
	_pad_hit_at[lane] = _t
	session.tap(lane, _t, touch_id)


func _ring() -> void:
	var up := session.ring(_t)
	_play("bell_up" if up else "bell_down")


func _play(sound: String) -> void:
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = _sounds[sound]
	p.play()


func _on_judged(note: Note, word: String, tone: String) -> void:
	_judge = { word = word, color = Palette.tone_color(tone), at = _t }
	if tone in ["perfect", "good", "ok"]:
		Input.vibrate_handheld(12)
		if note.call:
			_play("call")


func _input(event: InputEvent) -> void:
	if _ended:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = make_input_local(event).position
		if event.pressed:
			if p.y >= _pads_top():
				_touches[event.index] = { x0 = p.x, fired = false }
				if not autoplay:
					_step(_lane_at(p.x), event.index)
		else:
			_touches.erase(event.index)
			session.release(_t, event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var s = _touches.get(event.index)
		var p: Vector2 = make_input_local(event).position
		if s != null and not s.fired and absf(p.x - s.x0) >= size.x * SWIPE_SHARE:
			s.fired = true
			_play("whoosh")
			if not autoplay:
				session.swipe(p.x > s.x0, _t)
		accept_event()
	elif event is InputEventKey and not event.echo:
		var lane := [KEY_A, KEY_S, KEY_D].find(event.keycode)
		if lane >= 0:
			if event.pressed:
				_step(lane, KEY_TOUCH + lane)
			else:
				session.release(_t, KEY_TOUCH + lane)
		elif event.pressed and event.keycode == KEY_SPACE:
			_ring()
		elif event.pressed and (event.keycode == KEY_Q or event.keycode == KEY_E):
			_play("whoosh")
			session.swipe(event.keycode == KEY_E, _t)
		elif event.pressed and event.keycode == KEY_ESCAPE:
			quit_requested.emit()
		else:
			return
		accept_event()


func _pads_top() -> float:
	return size.y - PADS_H - 24.0


func _lane_at(x: float) -> int:
	return clampi(int(x / (size.x / 3.0)), 0, 2)


func _hit_y() -> float:
	return _pads_top() - 70.0


func _y_of(t: float) -> float:
	var top := HUD_H
	return _hit_y() - (t - _t) / AHEAD * (_hit_y() - top)


func _text(pos: Vector2, text: String, font_size: int, color: Color, width := -1.0) -> void:
	var w := width if width > 0.0 else size.x
	draw_string(_font, Vector2(pos.x - w / 2.0, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, color)


func _draw() -> void:
	var w := size.x
	var lw := w / 3.0
	var hit_y := _hit_y()
	var pads_top := _pads_top()
	# Firelight rising from the hit line.
	var glow_top := hit_y - 500.0
	draw_polygon(PackedVector2Array([Vector2(0, glow_top), Vector2(w, glow_top), Vector2(w, pads_top), Vector2(0, pads_top)]),
			PackedColorArray([Color(Palette.EMBER, 0.0), Color(Palette.EMBER, 0.0), Color(Palette.EMBER, 0.12), Color(Palette.EMBER, 0.12)]))
	draw_rect(Rect2(lw - 1, HUD_H, 2, pads_top - HUD_H), Palette.WOOD)
	draw_rect(Rect2(lw * 2 - 1, HUD_H, 2, pads_top - HUD_H), Palette.WOOD)
	draw_rect(Rect2(8, hit_y - 9, w - 16, 18), Color(Palette.EMBER, 0.25))
	draw_rect(Rect2(8, hit_y - 2, w - 16, 4), Palette.BONE)
	_draw_notes(lw)
	_draw_pads(lw, pads_top)
	_draw_hud(w)


func _draw_notes(lw: float) -> void:
	var w := size.x
	var hit_y := _hit_y()
	var r := minf(lw * 0.36, 44.0)
	# Draw from the far end so nearer notes sit on top.
	for i in range(session.notes.size() - 1, -1, -1):
		var n: Note = session.notes[i]
		var tail := n.end_t if n.kind == Note.Kind.HOLD else n.t
		if n.t - _t > AHEAD or tail - _t < -0.3:
			continue
		var y := _y_of(n.t)
		var x := lw * n.lane + lw / 2.0
		if n.kind == Note.Kind.REST:
			if n.done and n.t < _t - 0.15:
				continue
			draw_rect(Rect2(14, y - 7, w - 28, 14), Color(Palette.ASH, 0.35))
			_text(Vector2(w / 2.0, y - 14), "STAND STILL", 20, Palette.ASH)
			continue
		if n.kind == Note.Kind.HOLD and not n.finished:
			# The held sound: a bar up to where the note ends, drawn from the line once it's held.
			var top := _y_of(n.end_t)
			var bottom := hit_y if n.holding else y
			if not n.done or n.holding:
				var col := Color(Palette.EMBER, 0.85) if n.holding else Color(Palette.BONE, 0.55)
				draw_rect(Rect2(x - r * 0.35, top, r * 0.7, maxf(0.0, bottom - top)), col)
				draw_circle(Vector2(x, top), r * 0.35, col)
			if n.done:
				continue
		if n.done and n.flash_at < 0.0:
			continue
		var yy := y
		var scale := 1.0
		var alpha := 1.0
		if n.flash_at >= 0.0:
			var age := _t - n.flash_at
			if age > 0.24:
				continue
			alpha = 1.0 - age / 0.24
			yy = hit_y
			scale = 1.0 + age / 0.24 * 0.6
		var rr := r * scale
		match n.kind:
			Note.Kind.BELL:
				# A bell spans every lane (it's a tilt, not a tap), with its direction in the middle.
				draw_rect(Rect2(14, yy - rr * 0.35, w - 28, rr * 0.7), Color(Palette.RED, 0.55 * alpha))
				draw_circle(Vector2(w / 2.0, yy), rr, Color(Palette.RED, alpha))
				var d := -1.0 if n.up else 1.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(w / 2.0, yy + d * rr * 0.6),
					Vector2(w / 2.0 - rr * 0.5, yy - d * rr * 0.35),
					Vector2(w / 2.0 + rr * 0.5, yy - d * rr * 0.35),
				]), Color(Palette.BONE, alpha))
			Note.Kind.SWIPE:
				# The Issohadore's rope: a red cord across the lanes, with an arrow for the throw.
				var pts := PackedVector2Array()
				for k in 25:
					pts.append(Vector2(20 + (w - 40) * k / 24.0, yy + sin(k / 24.0 * PI * 3.0) * 9.0))
				draw_polyline(pts, Color(Palette.RED, alpha), 9.0)
				var ax := w - 26.0 if n.right else 26.0
				var dir := 1.0 if n.right else -1.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(ax + dir * 14, yy), Vector2(ax - dir * 18, yy - 20), Vector2(ax - dir * 18, yy + 20),
				]), Color(Palette.RED, alpha))
				_text(Vector2(w / 2.0, yy - 20), "SWIPE  >" if n.right else "<  SWIPE", 20, Color(Palette.BONE, alpha))
			_:
				# A step: a hoof ring. Off-beat Issohadore calls are ember-coloured.
				var col := Palette.EMBER if n.call else Palette.BONE
				draw_circle(Vector2(x, yy), rr * 0.82, Color(col, 0.2 * alpha))
				draw_arc(Vector2(x, yy), rr * 0.82, 0, TAU, 40, Color(col, alpha), maxf(5.0, rr * 0.28), true)
				if n.kind == Note.Kind.HOLD:
					draw_circle(Vector2(x, yy), rr * 0.3, Color(col, alpha))


func _draw_pads(lw: float, pads_top: float) -> void:
	var cue := session.cued_lanes(_t)
	for i in 3:
		var rect := Rect2(lw * i + 8, pads_top, lw - 16, PADS_H)
		var pressed: bool = _t - _pad_hit_at[i] < 0.09
		var fill := Palette.WOOD
		if pressed:
			fill = Palette.BONE.darkened(0.3)
		elif cue[i]:
			fill = Palette.WOOD.lerp(Palette.EMBER, 0.35)
		draw_rect(rect, fill)
		draw_rect(rect, Palette.EMBER if cue[i] else Palette.ASH, false, 3.0)
		_text(Vector2(rect.get_center().x, rect.get_center().y + 10), LANE_NAMES[i], 26, Palette.BONE, lw)


func _draw_hud(w: float) -> void:
	var first := float(_song.first_beat)
	var last := session.notes[-1].t
	var p := clampf((_t - first) / (last - first), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, HUD_H), Palette.BLACK)  # notes slide in under the score
	draw_rect(Rect2(0, 0, w, 6), Palette.WOOD)
	draw_rect(Rect2(0, 0, w * p, 6), Palette.RED)
	draw_string(_font, Vector2(24, 64), str(session.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Palette.BONE)
	var m := "x%s" % (str(session.mult()).trim_suffix(".0"))
	draw_string(_font, Vector2(w - 224, 64), m, HORIZONTAL_ALIGNMENT_RIGHT, 200, 44, Palette.EMBER)
	draw_string(_font, Vector2(24, 96), _song.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.ASH)
	# Count-in numbers before the first note.
	var spb := 60.0 / float(_song.bpm)
	var to_first := first - _t
	if to_first > 0.0 and to_first < spb * 4.0:
		_text(Vector2(w / 2.0, size.y * 0.4), str(ceili(to_first / spb)), 160, Color(Palette.BONE, 0.8))
	var age: float = _t - _judge.at
	if age < 0.45 and _judge.word != "":
		var pop := 1.0 + maxf(0.0, 0.12 - age) * 2.0
		_text(Vector2(w / 2.0, size.y * 0.42), _judge.word, int(64 * pop), _judge.color)
	if autoplay:
		_text(Vector2(w / 2.0, 100), "AUTOPLAY", 20, Palette.ASH)
