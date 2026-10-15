extends Screen
## Settings, on the mobile kit: a segmented control over four swipeable pages, each a grouped list
## of 96 px rows (MenuKit.group: label left, value / switch / chevron right, dividers), so nothing
## scrolls:
##   Play     note speed with its preview in a card, graphics (sharp / fast), slam mode
##   Timing   the tilt calibration (which leads on through both delay tests) and the two delay
##            tests as chevron rows, with what the motion sensors can do (read only while this
##            page shows, until they answer), then the two delay sliders
##   Sound    music and bells volumes, the button knocks, the bell cue, vibration
##   More     language and animations as segmented controls, the lessons and the credits
## Every change is saved at once. args: page (an index, for screenshots and links).

const PAGES := ["play", "timing", "sound", "more"]

var pager: Pager
var _sensor: Label
var _reader := MotionReader.new()
var _status := ""
var _settled := false


func build() -> void:
	_status = ""
	_settled = false
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.top_bar(page.top, tr("set_title"), on_back)
	pager = UIKit.paged(page.body, [["play", tr("set_play")], ["timing", tr("set_timing")],
		["sound", tr("set_sound")], ["more", tr("set_more")]], clampi(int(args.get("page", 0)), 0, 3))
	_play_page(pager.add_page("PlayPage", UIKit.S2, true))
	_timing_page(pager.add_page("TimingPage", UIKit.S2, true))
	_sound_page(pager.add_page("SoundPage", UIKit.S2, true))
	_more_page(pager.add_page("MorePage", UIKit.S2, true))
	pager.go(pager.current, true)
	# The motion sensors are only read while the Timing page shows, and only until they answer.
	pager.page_changed.connect(func(_i: int) -> void: _poll_sensor())
	_poll_sensor()


func _poll_sensor() -> void:
	set_process(pager.current == 1 and not _settled)


func _play_page(box: VBoxContainer) -> void:
	var g := MenuKit.group(box, tr("set_display"))
	var speed := MenuKit.slider_row(g, "note_speed", tr("set_note_speed"), 0.5, 3.0, 0.1, float(Profile.get_setting("note_speed")),
		func(v: float) -> String: return "×" + UIKit.fmt_dec(v, 1),
		func(v: float) -> void: Profile.set_setting("note_speed", v))
	var preview := SpeedPreview.new()
	preview.name = "SpeedPreview"
	preview.custom_minimum_size = Vector2(0, 200)
	preview.note_speed = speed.value
	var warn := UIKit.label("", UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER)
	warn.name = "SpeedWarning"
	var show_warn := func(v: float) -> void:
		warn.text = tr("set_note_warning") % UIKit.fmt_dec(LaneView.LOOKAHEAD / maxf(v, 0.1), 2)
	show_warn.call(speed.value)
	speed.value_changed.connect(func(v: float) -> void:
		preview.note_speed = v
		show_warn.call(v))
	var pv := MenuKit.control_row(g, "", preview)
	pv.add_child(warn)
	# the play screen's picture: sharp (whole screen px per texel) or fast (big pixels, for weak phones)
	var gfx := VBoxContainer.new()
	gfx.name = "Graphics"
	MenuKit.control_row(g, tr("set_graphics"), gfx, tr("set_graphics_note"))
	var gfx_row: HBoxContainer
	gfx_row = UIKit.tabs(gfx, PxArt.GRAPHICS.map(func(id: String) -> Array: return [id, tr("gfx_" + id)]), PxArt.graphics(),
		func(id: String) -> void:
			Profile.set_setting("graphics", id)
			UIKit.select_tab(gfx_row, id))
	var t := MenuKit.group(box, tr("set_play"))
	_toggle(t, "slam", tr("set_slam"), tr("set_slam_note"))


func _timing_page(box: VBoxContainer) -> void:
	var g := MenuKit.group(box, tr("set_setup"))
	# The calibration leads on through both delay tests ("Test 1 of 3" ...), then back here.
	MenuKit.nav_row(g, "Calibrate", tr("set_calibrate"), func() -> void: app.open("calibration", {"chain": true}))
	_sensor = MenuKit.note_row(g, tr("motion_waiting"), "Sensor")
	UIKit.spacer(g, UIKit.S2)
	MenuKit.nav_row(g, "Latency", tr("set_latency"), func() -> void: app.open("latency"))
	MenuKit.nav_row(g, "ScreenDelay", tr("set_visual_test"), func() -> void: app.open("screen_delay"))
	var a := MenuKit.group(box, tr("set_timing"))
	_slider(a, "audio_offset", tr("set_offset"), Profile.RANGES["audio_offset"].x, Profile.RANGES["audio_offset"].y, 0.005,
		func(v: float) -> String: return tr("ms_signed") % roundi(v * 1000.0))
	_slider(a, "visual_offset", tr("set_visual"), Profile.RANGES["visual_offset"].x, Profile.RANGES["visual_offset"].y, 0.005,
		func(v: float) -> String: return tr("ms_signed") % roundi(v * 1000.0))
	MenuKit.note_row(a, tr("set_visual_note"))
	UIKit.spacer(a, UIKit.S3)


func _sound_page(box: VBoxContainer) -> void:
	var g := MenuKit.group(box, tr("set_sound"))
	_slider(g, "music_volume", tr("set_music"), 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0), true)
	_slider(g, "sfx_volume", tr("set_sfx"), 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0), true)
	_toggle(g, "step_knocks", tr("set_step_knocks"), tr("set_step_knocks_note"))
	_toggle(g, "bell_cue", tr("set_bell_cue"), tr("set_bell_cue_note"))
	_toggle(g, "vibration", tr("set_vibration"))


func _more_page(box: VBoxContainer) -> void:
	var g := MenuKit.group(box, tr("set_language"))
	var lang := VBoxContainer.new()
	MenuKit.control_row(g, "", lang)
	UIKit.tabs(lang, [["en", tr("lang_name_en")], ["it", tr("lang_name_it")]], I18n.locale(), _language)
	var d := MenuKit.group(box, tr("set_animations"))
	var anims := VBoxContainer.new()
	anims.name = "Animations"
	MenuKit.control_row(d, "", anims, tr("set_animations_note"))
	var row := UIKit.tabs(anims, [["full", tr("anim_full")], ["calm", tr("anim_calm")], ["off", tr("anim_off")]], UIKit.animations(), func(_a: String) -> void: pass)
	for b in row.get_children():
		var id := str(b.name).trim_prefix("Tab_")
		(b as Button).pressed.connect(_animations.bind(id, row))
	var about := MenuKit.group(box, tr("set_about"))
	MenuKit.nav_row(about, "Tutorial", tr("set_tutorial"), func() -> void: app.open("tutorial"))
	MenuKit.nav_row(about, "Credits", tr("set_credits"), func() -> void: app.open("credits"))


## Says what the motion sensors can do, once they have had a second to answer.
func _process(delta: float) -> void:
	_reader.read(delta)
	var st := _reader.status()
	if st == _status or st == "waiting" or _sensor == null:
		return
	_status = st
	_settled = st != "permission"
	_poll_sensor()
	# On the web: not asked yet ("permission"), or refused (no_sensor with a denied permission).
	var key := "motion_denied" if st == "no_sensor" and _reader.web_permission() == "denied" else "motion_" + st
	var text := tr(key)
	if st != "no_sensor" and st != "permission" and Profile.calibration().is_empty() and not bool(Profile.get_setting("slam")):
		text += " " + tr("motion_uncalibrated")
	_sensor.text = text


func _slider(g: VBoxContainer, key: String, title: String, lo: float, hi: float, step: float, fmt: Callable, volume := false) -> HSlider:
	return MenuKit.slider_row(g, key, title, lo, hi, step, float(Profile.get_setting(key)), fmt, func(v: float) -> void:
		Profile.set_setting(key, v)
		if volume:
			UIKit.apply_volumes())


func _toggle(g: VBoxContainer, key: String, title: String, note := "") -> CheckButton:
	var v: Variant = Profile.get_setting(key)
	# A setting Profile has no default for yet ("bell_cue") starts on.
	var on := true if v == null else bool(v)
	return MenuKit.toggle_row(g, "Toggle_" + key, title, on, func(x: bool) -> void: Profile.set_setting(key, x), note)


func _language(code: String) -> void:
	Profile.set_setting("language", code)
	I18n.set_locale(code)
	args["page"] = pager.current
	app.rebuild_all()


func _animations(a: String, row: HBoxContainer) -> void:
	Profile.set_setting("animations", a)
	Profile.set_setting("reduced_motion", a != "full")
	UIKit.select_tab(row, a)
