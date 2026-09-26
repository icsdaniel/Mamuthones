extends Control
## Screens: title, calibrate, songs, play and results. The UI is built in code so it
## stays easy to change while the design settles.

var songs: Array = Chart.load_songs()
var save := SaveData.new()
var calibration := {}
var last_session: Session
var last_prev_best := 0
var last_autoplay := false

var _calibrator: Calibrator
var _motion := MotionReader.new()
var _calib_ui := {}
var _calib_time := 0.0
var _bell: AudioStreamPlayer
var _bell_sounds := [load("res://audio/bell_up.wav"), load("res://audio/bell_down.wav")]


func _ready() -> void:
	theme = _make_theme()
	calibration = save.calibration()
	_bell = AudioStreamPlayer.new()
	add_child(_bell)
	show_title()


# ---------- Screens ----------

func show_title() -> void:
	var box := _screen()
	var mask := TextureRect.new()
	mask.texture = load("res://icon.svg")
	mask.custom_minimum_size = Vector2(260, 260)
	mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(mask)
	box.add_child(_label("MAMUTHONES", 72, Palette.BONE))
	box.add_child(_label("The Weight of Bells", 40, Palette.RED))
	box.add_child(_label("Walk in the procession of Mamoiada. Tap your steps, tilt the phone to ring the bells on your back, and keep the row together.", 26, Palette.ASH))
	box.add_child(_spacer())
	box.add_child(_button("Play", func(): show_songs() if not calibration.is_empty() else show_calibrate()))
	box.add_child(_button("Calibrate the bell", show_calibrate, false))


func show_calibrate() -> void:
	var box := _screen()
	_calibrator = Calibrator.new()
	_calib_time = 0.0
	_calib_ui = {}
	_calib_ui.title = _label("", 64, Palette.BONE)
	_calib_ui.text = _label("", 26, Palette.ASH)
	_calib_ui.dots = _label("", 48, Palette.EMBER)
	_calib_ui.meter = ProgressBar.new()
	_calib_ui.meter.show_percentage = false
	_calib_ui.meter.custom_minimum_size = Vector2(0, 18)
	_calib_ui.note = _label("", 24, Palette.EMBER)
	for k in ["title", "text", "dots", "meter", "note"]:
		box.add_child(_calib_ui[k])
	box.add_child(_spacer())
	_calib_ui.go = _button("Continue", show_songs)
	_calib_ui.go.visible = false
	box.add_child(_calib_ui.go)
	box.add_child(_button("Start over", show_calibrate, false))
	box.add_child(_button("Skip", show_songs, false))
	_update_calib_ui()


func show_songs() -> void:
	_calibrator = null
	var box := _screen()
	box.add_child(_label("Choose a song", 56, Palette.BONE))
	for song in songs:
		var best := save.best(song.id)
		var secs := roundi(Chart.length_seconds(song))
		var meta := "%d bpm  ·  %d s" % [song.bpm, secs] + ("  ·  best %d" % best if best > 0 else "")
		var b := _button("%s\n%s\n%s" % [song.title, song.about, meta], start_song.bind(song))
		b.custom_minimum_size.y = 170
		box.add_child(b)
	if calibration.is_empty():
		box.add_child(_label("Bells are off until you calibrate. On a computer, Space rings the bell.", 22, Palette.EMBER))
	box.add_child(_spacer())
	box.add_child(_button("Calibrate the bell", show_calibrate, false))
	box.add_child(_button("Back", show_title, false))


func start_song(song: Dictionary, autoplay := false) -> void:
	_calibrator = null
	for c in get_children():
		if c != _bell:
			c.queue_free()
	DisplayServer.screen_set_keep_on(true)
	var view := PlayView.new()
	view.setup(song, calibration, autoplay)
	view.finished.connect(_on_song_finished.bind(autoplay))
	view.quit_requested.connect(show_songs)
	add_child(view)


func show_results() -> void:
	DisplayServer.screen_set_keep_on(false)
	var box := _screen()
	if last_session == null:
		box.add_child(_label("No procession yet.", 40, Palette.BONE))
		box.add_child(_button("Choose a song", show_songs))
		return
	var s := last_session
	var acc := s.accuracy()
	box.add_child(_label(s.song.title, 32, Palette.ASH))
	box.add_child(_label(str(s.score), 96, Palette.BONE))
	var grade := "The Issohadores are waiting for you"
	if acc > 0.9:
		grade = "The whole row rang as one"
	elif acc > 0.7:
		grade = "A proud procession"
	elif acc > 0.45:
		grade = "Keep walking with the row"
	box.add_child(_label(grade, 34, Palette.RED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	var rows := [
		["Accuracy", "%d%%" % roundi(acc * 100)],
		["Best combo", str(s.max_combo)],
		["Perfect / Good", "%d / %d" % [s.stats.perfect, s.stats.good]],
		["Missed", str(s.stats.miss)],
		["Wrong step or way", str(s.stats.wrong)],
		["Broke the silence", str(s.stats.silence)],
		["Holds kept", "%d / %d" % [s.stats.kept, s.hold_count()] if s.hold_count() > 0 else "-"],
		["Steps, on average", _fmt_offset(s.stats.tap_offsets)],
		["Bells, on average", _fmt_offset(s.stats.bell_offsets)],
	]
	for r in rows:
		grid.add_child(_label(r[0], 26, Palette.ASH, HORIZONTAL_ALIGNMENT_LEFT))
		grid.add_child(_label(r[1], 26, Palette.BONE, HORIZONTAL_ALIGNMENT_RIGHT))
	box.add_child(grid)
	var best_line := "Autoplay runs are not saved."
	if not last_autoplay:
		if s.score > last_prev_best:
			best_line = "New best, up from %d." % last_prev_best if last_prev_best > 0 else "Saved as your best for this song."
		else:
			best_line = "Your best on this song is %d." % last_prev_best
	box.add_child(_label(best_line, 24, Palette.ASH))
	box.add_child(_spacer())
	box.add_child(_button("Play again", start_song.bind(s.song)))
	box.add_child(_button("Songs", show_songs, false))


func _on_song_finished(session: Session, autoplay: bool) -> void:
	last_session = session
	last_autoplay = autoplay
	last_prev_best = save.best(session.song.id) if autoplay else save.submit(session.song.id, session.score)
	show_results()


# ---------- Calibration ----------

func _process(delta: float) -> void:
	if _calibrator == null or _calibrator.is_done():
		return
	_calib_time += delta
	var m := _motion.read()
	var lin: Vector3 = m[0]
	var rot: Vector3 = m[1]
	_calib_ui.meter.value = minf(1.0, maxf(lin.length() / 30.0, rot.length() / 600.0)) * 100.0
	if _calibrator.feed(_calib_time, lin, rot, _motion.has_gyro):
		_bell.stream = _bell_sounds[0 if _calibrator.moves[-1].up else 1]
		_bell.play()
		if _calibrator.is_done():
			_finish_calibration()
		else:
			_update_calib_ui()
	if not _motion.has_motion and _calib_time > 1.5:
		_calib_ui.note.text = "No motion sensor found. On a computer, skip this and use Space to ring the bell."


func _update_calib_ui() -> void:
	var up := _calibrator.wants_up()
	_calib_ui.title.text = "Tilt up" if up else "Tilt down"
	_calib_ui.text.text = "Hold the phone in both hands as you'll play, then sharply tilt the top of the phone up and back, like snapping the bells on your back. Three times." if up \
			else "Now three sharp tilts downward: top of the phone down and back."
	var dots := ""
	for i in Calibrator.PER_DIR * 2:
		dots += ("●" if i < _calibrator.moves.size() else "○") + " "
	_calib_ui.dots.text = dots.strip_edges()


func _finish_calibration() -> void:
	var r := _calibrator.result()
	_update_calib_ui()
	if r.is_empty():
		_calib_ui.title.text = "Try again"
		_calib_ui.text.text = "Some moves were too soft to measure. Tap Start over and make each tilt a little sharper."
		return
	calibration = r
	save.set_calibration(r)
	var sensor := "gyroscope" if r.mode == "rot" else "motion sensor"
	_calib_ui.title.text = "Calibrated"
	if r.dir_ok:
		_calib_ui.text.text = "Your phone read %d of 6 moves the right way, using its %s." % [r.agree, sensor]
	else:
		_calib_ui.text.text = "Only %d of 6 moves were read the right way. Bells alternate on their own, so timing is all that counts; you can start over with crisper moves." % r.agree
	_calib_ui.note.text = ("%d°/s of tilt rings the bell" % roundi(r.thr)) if r.mode == "rot" else ("%.1f m/s² of shake rings the bell" % r.thr)
	_calib_ui.go.visible = true


# ---------- Building blocks ----------

func _screen() -> VBoxContainer:
	for c in get_children():
		if c != _bell:
			c.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	add_child(margin)
	return box


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 110 if primary else 84)
	b.pressed.connect(action)
	if not primary:
		b.theme_type_variation = &"QuietButton"
	return b


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 24
	return c


func _fmt_offset(offsets: Array) -> String:
	if offsets.is_empty():
		return "-"
	var ms := roundi(offsets.reduce(func(a, b): return a + b, 0.0) / offsets.size() * 1000.0)
	return "on time" if ms == 0 else ("%+d ms" % ms)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var normal := _box(Palette.RED, Palette.RED)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", _box(Palette.RED.darkened(0.3), Palette.BONE))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Palette.BONE)
	t.set_color("font_hover_color", "Button", Palette.BONE)
	t.set_color("font_pressed_color", "Button", Palette.BONE)
	t.set_font_size("font_size", "Button", 34)
	t.set_type_variation(&"QuietButton", &"Button")
	var quiet := _box(Palette.BLACK, Palette.ASH)
	t.set_stylebox("normal", "QuietButton", quiet)
	t.set_stylebox("hover", "QuietButton", quiet)
	t.set_stylebox("pressed", "QuietButton", _box(Palette.WOOD, Palette.BONE))
	t.set_font_size("font_size", "QuietButton", 28)
	t.set_stylebox("background", "ProgressBar", _box(Palette.WOOD, Palette.WOOD))
	t.set_stylebox("fill", "ProgressBar", _box(Palette.EMBER, Palette.EMBER))
	return t


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(16)
	return s
