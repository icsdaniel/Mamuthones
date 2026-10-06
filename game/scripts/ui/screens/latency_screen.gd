extends Screen
## The audio-delay tap test: four clicks to listen, then twelve to tap along with on the big drum.
## Nothing flashes with the clicks (that would measure the eyes, not the ears). The median delay
## becomes the audio offset. Uneven taps are explained and the test repeats.
## args: first_run (bool) continues to the tutorial; otherwise back to settings.

const BPM := LatencyTest.BPM
const LISTEN := 4
const COUNT := 12

var test := LatencyTest.new()
var _running := false
var _start_us := 0
var _next_click := 0
var _click_times: PackedFloat64Array
var _status: Label
var _detail: Label
var _pad: Button
var _actions: VBoxContainer
var _meter: TendencyMeter
var _taps := 0
var _drum: SetupArtView
var _pulses: Array[float] = []   ## heard times of clicks still to show on the drum


func build() -> void:
	var box := UIKit.column(self, false, 18)
	if args.get("first_run", false):
		box.add_child(UIKit.label(tr("lat_step"), UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		UIKit.header(box, tr("lat_title"), on_back)
	box.add_child(UIKit.label(tr("lat_title"), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UIKit.label(tr("lat_intro"), UIKit.LEAD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_status.name = "Status"
	box.add_child(_status)
	_pad = Button.new()
	_pad.name = "Pad"
	_pad.text = tr("lat_pad")
	_pad.focus_mode = Control.FOCUS_NONE
	_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pad.custom_minimum_size = Vector2(0, 360)
	_pad.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_pad.button_down.connect(_on_tap)
	box.add_child(_pad)
	# Art's frame drum fills the pad: it pulses with every click as it is heard, and with every tap.
	_drum = SetupArtView.new()
	_drum.name = "Drum"
	_drum.kind = "drum"
	_drum.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drum.offset_top = 12.0
	_drum.offset_bottom = -52.0
	_pad.add_child(_drum)
	_pad.text = ""
	var tap := UIKit.label(tr("lat_pad"), UIKit.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	tap.name = "PadLabel"
	tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tap.offset_top = -50.0
	tap.offset_bottom = -10.0
	_pad.add_child(tap)
	_meter = TendencyMeter.new()
	_meter.custom_minimum_size.y = 150
	_meter.visible = false
	box.add_child(_meter)
	_detail = UIKit.label("", UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_detail)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	box.add_child(_actions)
	_show_start()


func _show_start() -> void:
	_clear_actions()
	var go := UIKit.button(tr("lat_start"), _begin, UIKit.PRIMARY)
	go.name = "Start"
	_actions.add_child(go)
	var skip := UIKit.button(tr("lat_skip"), _next, UIKit.QUIET)
	skip.name = "Skip"
	_actions.add_child(skip)


func _clear_actions() -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)   # so a new button can take the same name at once
		c.queue_free()


func _now() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1_000_000.0


func _begin() -> void:
	_clear_actions()
	test.clear()
	_taps = 0
	_meter.visible = false
	_detail.text = ""
	_start_us = Time.get_ticks_usec()
	_pulses.clear()
	_click_times = LatencyTest.click_times(BPM, LISTEN + COUNT, 0.6)
	_next_click = 0
	_running = true
	_status.text = tr("lat_listen")
	# The way out stays on screen while the test runs: it is never a trap.
	var skip := UIKit.button(tr("lat_skip"), _skip_now, UIKit.QUIET)
	skip.name = "Skip"
	_actions.add_child(skip)


func _skip_now() -> void:
	_running = false
	_next()


func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now()
	# Trigger each click a little before its time so it is mixed on time; the click is heard at the
	# moment it leaves the speaker, which is what the taps are compared with.
	var lead := AudioServer.get_time_to_next_mix()
	while _next_click < _click_times.size() and _click_times[_next_click] - lead <= now:
		Sound.step(1)
		var heard := maxf(_click_times[_next_click], now + lead) + AudioServer.get_output_latency()
		_pulses.append(heard)
		if _next_click >= LISTEN:
			test.add_click(heard)
		_next_click += 1
		if _next_click == LISTEN:
			_status.text = tr("lat_tap_now")
	while not _pulses.is_empty() and _pulses[0] <= now:
		_pulses.pop_front()
		_drum.strike(1.0)
	if _next_click >= _click_times.size() and now > _click_times[-1] + 0.8:
		_running = false
		_finish()


func _on_tap() -> void:
	if not _running:
		return
	var t := _now()
	_drum.strike(0.6)
	if _next_click > LISTEN:
		test.add_tap(t)
		_taps += 1
		_detail.text = tr("lat_count") % [_taps, COUNT]
	UIKit.vibrate(10)


func _finish() -> void:
	_clear_actions()
	var r := test.result()
	_meter.offsets = PackedFloat32Array(test.offsets())
	_meter.visible = true
	if bool(r.get("ok", false)):
		var ms := roundi(float(r.offset) * 1000.0)
		Profile.set_setting("audio_offset", float(r.offset))
		Profile.set_flag("latency_tested", true)
		_status.text = tr("lat_done") % ms
		_detail.text = tr("lat_done_body")
		Sound.ui("unlock")
		var go := UIKit.button(tr("ui_continue"), _next, UIKit.PRIMARY)
		go.name = "Continue"
		_actions.add_child(go)
		_actions.add_child(UIKit.button(tr("lat_again"), _begin, UIKit.QUIET))
	else:
		_status.text = tr("lat_uneven") if int(r.get("count", 0)) >= LatencyTest.MIN_TAPS else tr("lat_few")
		_detail.text = tr("lat_uneven_body")
		var again := UIKit.button(tr("lat_again"), _begin, UIKit.PRIMARY)
		again.name = "Again"
		_actions.add_child(again)
		# Enough taps but uneven: the median is still a fair guess, so it can be kept.
		if int(r.get("count", 0)) >= LatencyTest.MIN_TAPS:
			var keep := UIKit.button(tr("lat_keep") % roundi(float(r.offset) * 1000.0), _keep.bind(float(r.offset)))
			keep.name = "Keep"
			_actions.add_child(keep)
		var skip := UIKit.button(tr("lat_skip"), _next, UIKit.QUIET)
		skip.name = "Skip"
		_actions.add_child(skip)


func _keep(offset: float) -> void:
	Profile.set_setting("audio_offset", offset)
	Profile.set_flag("latency_tested", true)
	_next()


func _next() -> void:
	if args.get("first_run", false):
		Profile.set_flag("latency_tested", true)
		app.replace("tutorial", {"first_run": true})
	else:
		app.back()


func on_back() -> void:
	if args.get("first_run", false):
		app.replace("calibration", {"first_run": true})
	else:
		app.back()
