extends Screen
## Settings: timing (calibration, delay test, manual offset), play (note speed, vibration, slam,
## animations), sound volumes, language, credits. Every change is saved at once.


func build() -> void:
	_status = ""
	var box := UIKit.column(self, true, 14)
	UIKit.header(box, tr("set_title"), on_back)

	var tim := _section(box, tr("set_timing"))
	var cal := UIKit.button(tr("set_calibrate"), func() -> void: app.open("calibration"))
	cal.name = "Calibrate"
	tim.add_child(cal)
	_sensor = UIKit.label("", UIKit.CAPTION)   # filled in once the sensors answer: a waiting line read as stuck
	_sensor.name = "Sensor"
	_sensor.visible = false
	tim.add_child(_sensor)
	var lat := UIKit.button(tr("set_latency"), func() -> void: app.open("latency"))
	lat.name = "Latency"
	tim.add_child(lat)
	_slider(tim, "audio_offset", tr("set_offset"), Profile.RANGES["audio_offset"].x, Profile.RANGES["audio_offset"].y, 0.005,
		func(v: float) -> String: return tr("ms_signed") % roundi(v * 1000.0))
	var vis := UIKit.button(tr("set_visual_test"), func() -> void: app.open("screen_delay"))
	vis.name = "ScreenDelay"
	tim.add_child(vis)
	_slider(tim, "visual_offset", tr("set_visual"), Profile.RANGES["visual_offset"].x, Profile.RANGES["visual_offset"].y, 0.005,
		func(v: float) -> String: return tr("ms_signed") % roundi(v * 1000.0))
	tim.add_child(UIKit.label(tr("set_visual_note"), UIKit.CAPTION))

	var pl := _section(box, tr("set_play"))
	var speed := _slider(pl, "note_speed", tr("set_note_speed"), 0.5, 3.0, 0.1,
		func(v: float) -> String: return "×" + UIKit.fmt_dec(v, 1) + " · " + tr("set_note_warning") % UIKit.fmt_dec(LaneView.LOOKAHEAD / maxf(v, 0.1), 2))
	var preview := SpeedPreview.new()
	preview.name = "SpeedPreview"
	preview.custom_minimum_size = Vector2(0, 220)
	preview.note_speed = speed.value
	pl.add_child(preview)
	speed.value_changed.connect(func(v: float) -> void: preview.note_speed = v)
	_toggle(pl, "bell_cue", tr("set_bell_cue"), tr("set_bell_cue_note"))
	_toggle(pl, "bell_cue_all", tr("set_bell_cue_all"))
	_toggle(pl, "vibration", tr("set_vibration"))
	_toggle(pl, "step_knocks", tr("set_step_knocks"), tr("set_step_knocks_note"))
	_toggle(pl, "slam", tr("set_slam"), tr("set_slam_note"))
	# animations: full, calm (less movement), or off (the smoothest play: only the notes move)
	pl.add_child(UIKit.label(tr("set_animations"), UIKit.CAPTION))
	var anims := HBoxContainer.new()
	anims.name = "Animations"
	anims.add_theme_constant_override("separation", 12)
	for a in ["full", "calm", "off"]:
		var ab := UIKit.button(tr("anim_" + a), _animations.bind(a, anims))
		ab.toggle_mode = true
		ab.set_pressed_no_signal(UIKit.animations() == a)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.name = "Anim_" + a
		anims.add_child(ab)
	pl.add_child(anims)
	pl.add_child(UIKit.label(tr("set_animations_note"), UIKit.CAPTION))

	var snd := _section(box, tr("set_sound"))
	_slider(snd, "music_volume", tr("set_music"), 0.0, 1.0, 0.05,
		func(v: float) -> String: return "%d%%" % roundi(v * 100.0), "music")
	_slider(snd, "sfx_volume", tr("set_sfx"), 0.0, 1.0, 0.05,
		func(v: float) -> String: return "%d%%" % roundi(v * 100.0), "sfx")

	var lg := _section(box, tr("set_language"))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 12)
	for code in ["en", "it"]:
		var b := UIKit.button(tr("lang_name_" + code), _language.bind(code))
		b.toggle_mode = true
		b.set_pressed_no_signal(I18n.locale() == code)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Lang_" + code
		langs.add_child(b)
	lg.add_child(langs)

	var credits := UIKit.button(tr("set_credits"), func() -> void: app.open("credits"), UIKit.QUIET)
	credits.name = "Credits"
	box.add_child(credits)


func _section(box: Container, title: String) -> VBoxContainer:
	var c := UIKit.card(box)
	c.add_theme_constant_override("separation", 14)
	c.add_child(UIKit.label(title, UIKit.SUB))
	return c


var _sensor: Label
var _reader := MotionReader.new()
var _status := ""


## Says what the motion sensors can do, once they have had a second to answer.
func _process(delta: float) -> void:
	_reader.read(delta)
	var st := _reader.status()
	if st == _status or st == "waiting":
		return
	_status = st
	# On the web: not asked yet ("permission"), or refused (no_sensor with a denied permission).
	var key := "motion_denied" if st == "no_sensor" and _reader.web_permission() == "denied" else "motion_" + st
	var text := tr(key)
	if st != "no_sensor" and st != "permission" and Profile.calibration().is_empty() and not bool(Profile.get_setting("slam")):
		text += " " + tr("motion_uncalibrated")
	_sensor.text = text
	_sensor.visible = text != ""


func _slider(box: Container, key: String, title: String, lo: float, hi: float, step: float,
		fmt: Callable, bus := "") -> HSlider:
	var head := HBoxContainer.new()
	var l := UIKit.label(title, "", false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var value := UIKit.label("", UIKit.CAPTION, false)
	head.add_child(value)
	box.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Profile.get_setting(key))
	s.custom_minimum_size.y = UIKit.TOUCH
	s.focus_mode = Control.FOCUS_NONE
	s.name = "Slider_" + key
	value.text = fmt.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		value.text = fmt.call(v)
		Profile.set_setting(key, v)
		if bus != "":
			UIKit.apply_volumes())
	box.add_child(s)
	return s


func _toggle(box: Container, key: String, title: String, note := "") -> CheckButton:
	var t := CheckButton.new()
	t.text = title
	var v: Variant = Profile.get_setting(key)
	# A setting Profile has no default for yet ("bell_cue") starts on.
	t.button_pressed = true if v == null else bool(v)
	t.custom_minimum_size.y = UIKit.TOUCH
	t.focus_mode = Control.FOCUS_NONE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.name = "Toggle_" + key
	t.toggled.connect(func(on: bool) -> void:
		Sound.ui("tap")
		Profile.set_setting(key, on))
	box.add_child(t)
	if note != "":
		box.add_child(UIKit.label(note, UIKit.CAPTION))
	return t


func _language(code: String) -> void:
	Profile.set_setting("language", code)
	I18n.set_locale(code)
	app.rebuild_all()


func _animations(a: String, row: Control) -> void:
	Sound.ui("tap")
	Profile.set_setting("animations", a)
	Profile.set_setting("reduced_motion", a != "full")
	for c in row.get_children():
		(c as Button).set_pressed_no_signal(c.name == "Anim_" + a)
