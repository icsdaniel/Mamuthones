extends Screen
## Tilt calibration: three sharp tilts toward you and three away, with live feedback. The phone drawing
## follows the real tilt, the meter shows how hard the last move was, each counted tilt rings a bell and
## fills a mark. No sensor or too-soft tilts are explained, with slam mode offered instead.
## args: first_run (bool) continues to the delay test; otherwise back to settings.

var reader: MotionReader
var calibrator: Calibrator
var _t := 0.0
var _phone: TiltPhone
var _marks_up: BellMarks
var _marks_down: BellMarks
var _sensor: Label
var _instruction: Label
var _hint: Label
var _actions: VBoxContainer
var _done := false


func build() -> void:
	reader = MotionReader.new()
	calibrator = Calibrator.new()
	calibrator.move_detected.connect(_on_move)
	calibrator.finished.connect(_on_finished)
	calibrator.failed.connect(_on_failed)
	calibrator.start()
	var box := UIKit.column(self, false, 20)
	if args.get("first_run", false):
		box.add_child(UIKit.label(tr("cal_step"), UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		UIKit.header(box, tr("cal_title"), on_back)
	box.add_child(UIKit.label(tr("cal_title"), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER))
	_instruction = UIKit.label("", UIKit.SUB, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_instruction)
	_phone = TiltPhone.new()
	_phone.custom_minimum_size = Vector2(0, 460)
	_phone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_phone)
	# Three bells for the tilts toward you, three for away: each counted tilt rings one in.
	var marks := HBoxContainer.new()
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("separation", 40)
	for up in [true, false]:
		var col := VBoxContainer.new()
		var m := BellMarks.new(0, 44.0)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(m)
		col.add_child(UIKit.label(tr("cal_up_label") if up else tr("cal_down_label"), UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER))
		marks.add_child(col)
		if up:
			_marks_up = m
		else:
			_marks_down = m
	box.add_child(marks)
	_sensor = UIKit.label("", UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	_sensor.name = "Sensor"
	box.add_child(_sensor)
	_hint = UIKit.label(tr("cal_hint"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	box.add_child(_actions)
	_show_skip()
	_update_instruction()


func _show_skip() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var skip := UIKit.button(tr("cal_use_slam"), _use_slam, UIKit.QUIET)
	skip.name = "UseSlam"
	_actions.add_child(skip)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	reader.read(delta)
	var status := reader.status()
	if status == "no_gyro" and _sensor.text == "":
		_sensor.text = tr("motion_no_gyro")
	if status == "no_sensor":
		_on_failed("no_sensor")
		return
	calibrator.feed(_t, reader.linear, reader.rotation_dps, reader.has_gyro())
	_phone.feed(reader.rotation_dps, delta)


func _on_move(index: int, up: bool, strength: float) -> void:
	if up:
		_marks_up.count = mini(_marks_up.count + 1, 3)
	else:
		_marks_down.count = mini(_marks_down.count + 1, 3)
	_phone.flash(up, strength)
	Sound.bell("light", up, "perfect")
	UIKit.vibrate(25)
	_update_instruction()


func _update_instruction() -> void:
	var up := calibrator.expecting_up()
	_instruction.text = tr("cal_tilt_up") if up else tr("cal_tilt_down")
	_phone.expect_up = up


func _on_finished(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	if not result.is_empty():
		Profile.set_calibration(result)
	Profile.set_flag("calibrated", true)
	Profile.set_setting("slam", false)
	_instruction.text = tr("cal_done")
	_hint.text = tr("cal_done_body")
	Sound.ui("unlock")
	for c in _actions.get_children():
		c.queue_free()
	var go := UIKit.button(tr("ui_continue"), _next, UIKit.PRIMARY)
	go.name = "Continue"
	_actions.add_child(go)
	var again := UIKit.button(tr("cal_again"), func() -> void: app.replace("calibration", args), UIKit.QUIET)
	_actions.add_child(again)


func _on_failed(reason: String) -> void:
	if _done:
		return
	_done = true
	_instruction.text = tr("cal_fail_" + reason)
	_hint.text = tr("cal_fail_" + reason + "_body")
	for c in _actions.get_children():
		c.queue_free()
	if reason != "no_sensor":
		_actions.add_child(UIKit.button(tr("cal_again"), func() -> void: app.replace("calibration", args), UIKit.PRIMARY))
	_actions.add_child(UIKit.button(tr("cal_use_slam"), _use_slam, "" if reason != "no_sensor" else UIKit.PRIMARY))


func _use_slam() -> void:
	Profile.set_setting("slam", true)
	Profile.set_flag("calibrated", true)
	_next()


func _next() -> void:
	if args.get("first_run", false):
		app.replace("latency", {"first_run": true})
	else:
		app.back()


func on_back() -> void:
	if args.get("first_run", false):
		app.replace("headphones")
	else:
		app.back()
