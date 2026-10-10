extends Screen
## Tilt calibration: three sharp tilts toward you and three away, with live feedback. The phone drawing
## follows the real tilt, the meter shows how hard the last move was, each counted tilt rings a bell and
## fills a mark. No sensor or too-soft tilts are explained, with slam mode offered instead.
## A graph under the phone shows the sensor live. Once calibrated it switches to a check: the bell
## detector built from the new calibration runs as in a song, its threshold drawn as gold lines and each
## ring marked and heard, so the player sees that holding the phone stays quiet and a tilt rings.
## args: first_run (bool) continues to the delay test; otherwise back to settings.

var reader: MotionReader
var calibrator: Calibrator
var _t := 0.0
var _phone: SetupArtView         ## Art's phone in two hands, following the real tilt
var _angle := 0.0                ## radians, > 0 = top edge toward the player
var _flash := 0.0
var _nod := 0.0                  ## a slow demonstration nod while waiting for the first move
var _expect_up := true
var _marks_up: BellMarks
var _marks_down: BellMarks
var _sensor: Label
var _instruction: Label
var _hint: Label
var _actions: VBoxContainer
var _done := false
var _asking := false             ## web: the "tap to enable motion" prompt is showing
var graph: TiltGraph
var check: BellDetector          ## after calibrating: the detector a song would use


func build() -> void:
	# args.reader (tests) stands in for the phone's sensors.
	reader = args.get("reader", null) if args.get("reader", null) is MotionReader else MotionReader.new()
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
	_instruction = UIKit.label("", UIKit.LEAD, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_instruction)
	_phone = SetupArtView.new()
	_phone.name = "Phone"
	_phone.kind = "phone"
	_phone.custom_minimum_size = Vector2(0, 340)
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
	graph = TiltGraph.new()
	graph.name = "TiltGraph"
	graph.threshold = Calibrator.ROT_TRIGGER
	box.add_child(graph)
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
		_actions.remove_child(c)
		c.queue_free()
	var skip := UIKit.button(tr("cal_use_slam"), _use_slam, UIKit.QUIET)
	skip.name = "UseSlam"
	_actions.add_child(skip)


func _process(delta: float) -> void:
	if _done:
		if check != null:
			_t += delta
			reader.read(delta)
			_feed_check()
			_feed_phone(reader.rotation_dps.x, delta)
		return
	_t += delta
	reader.read(delta)
	var status := reader.status()
	# Web (iOS Safari): the browser gives motion only after a tap asks for it.
	if status == "permission":
		if not _asking:
			_show_permission()
		_feed_phone(0.0, delta)
		return
	if _asking:
		_asking = false
		_sensor.text = ""
		_show_skip()
	if status == "no_gyro" and _sensor.text == "":
		_sensor.text = tr("motion_no_gyro")
	if status == "no_sensor":
		_on_failed("no_sensor")
		return
	# Every reading of this frame, each at its own time (the web sends 0-2 per frame), so a short
	# flick between frames is not lost.
	for smp in reader.samples:
		var at := _t - float(smp.get("age", 0.0))
		calibrator.feed(at, smp.get("linear", Vector3.ZERO), smp.get("rotation_dps", Vector3.ZERO), reader.has_gyro())
		# Before the axis is known, the graph shows pitch, the turn the phone drawing follows.
		var rot: Vector3 = smp.get("rotation_dps", Vector3.ZERO)
		graph.push(at, rot.x)
	_feed_phone(reader.rotation_dps.x, delta)


## The browser needs a tap before it shares the motion sensors: say so, and ask from that tap.
func _show_permission() -> void:
	_asking = true
	_sensor.text = tr("cal_permission_body")
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()
	var ask := UIKit.button(tr("cal_permission"), _request_permission, UIKit.PRIMARY)
	ask.name = "EnableMotion"
	_actions.add_child(ask)
	var skip := UIKit.button(tr("cal_use_slam"), _use_slam, UIKit.QUIET)
	skip.name = "UseSlam"
	_actions.add_child(skip)


func _request_permission() -> void:
	reader.request_web_permission()
	_sensor.text = tr("motion_waiting")


## Integrates the pitch rate (degrees per second) with a leak back to rest, so the drawing follows
## flicks without drifting; while nothing moves it nods the way the player should tilt. Art's picture
## costs a few ms to draw, so it is only updated when what it shows changes.
func _feed_phone(pitch_dps: float, delta: float) -> void:
	_angle += deg_to_rad(pitch_dps) * delta
	_angle = clampf(lerpf(_angle, 0.0, clampf(delta * 3.0, 0.0, 1.0)), -0.9, 0.9)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	_nod += delta
	var shown := _angle
	if absf(_angle) < 0.02 and _flash <= 0.0 and not UIKit.reduced_motion():
		shown = (0.35 if _expect_up else -0.35) * maxf(sin(_nod * 3.0), 0.0)
	if absf(shown - _phone.tilt) > 0.01:
		_phone.tilt = shown
	if absf(_flash - _phone.flash) > 0.02 or (_flash == 0.0 and _phone.flash != 0.0):
		_phone.flash = _flash


func _on_move(_index: int, up: bool, _strength: float) -> void:
	if up:
		_marks_up.count = mini(_marks_up.count + 1, 3)
	else:
		_marks_down.count = mini(_marks_down.count + 1, 3)
	_flash = 1.0
	if absf(_angle) < 0.2:
		_angle = 0.55 if up else -0.55
	graph.mark(graph.now, up)
	Sound.bell("light", up, "perfect")
	UIKit.vibrate(25)
	_update_instruction()


## The check after calibrating: every reading through the song's detector, rings marked and heard.
func _feed_check() -> void:
	for smp in reader.samples:
		var at := _t - float(smp.get("age", 0.0))
		var acc: Vector3 = smp.get("linear", Vector3.ZERO)
		var rot: Vector3 = smp.get("rotation_dps", Vector3.ZERO)
		var vec := rot if check.mode == "gyro" else acc
		graph.push(at, vec[check.axis] * check.up_sign)
		if check.feed(at, acc, rot):
			graph.mark(check.last_t, check.last_up)
			Sound.bell("light", check.last_up, "perfect")
			UIKit.vibrate(25)


func _update_instruction() -> void:
	var up := calibrator.expecting_up()
	_instruction.text = tr("cal_tilt_up") if up else tr("cal_tilt_down")
	_expect_up = up
	_phone.arrow = 1 if up else -1


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
	if not result.is_empty():
		check = BellDetector.from_calibration(result, reader.has_gyro())
		check.set_bpm(100.0)
		graph.threshold = check.threshold
		_hint.text = tr("cal_check_body") + "\n" + tr("cal_done_body")
	Sound.ui("unlock")
	for c in _actions.get_children():
		_actions.remove_child(c)
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
	# On the web a refused permission is not a missing sensor: say how to allow it.
	var key := "cal_fail_denied" if reason == "no_sensor" and reader.web_permission() == "denied" else "cal_fail_" + reason
	_instruction.text = tr(key)
	_hint.text = tr(key + "_body")
	_sensor.text = ""
	for c in _actions.get_children():
		_actions.remove_child(c)
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
	elif args.get("then_latency", false):
		app.replace("latency")
	else:
		app.back()


func on_back() -> void:
	if args.get("first_run", false):
		app.replace("headphones")
	else:
		app.back()
