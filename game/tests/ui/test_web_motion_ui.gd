extends TestCase
## Web motion in the UI: the calibration asks for motion from a tap while the browser has not
## granted it, calibrates from every reading of a frame, and falls back to buttons when refused.


## Stands in for the browser's sensors: a set status and permission, and the samples of one frame.
class FakeReader extends MotionReader:
	var fake_status := "permission"
	var fake_permission := "prompt"
	var asked := 0
	var frame: Array = []

	func read(_delta: float) -> void:
		samples = frame.duplicate()
		frame.clear()
		if not samples.is_empty():
			linear = samples[-1].linear
			rotation_dps = samples[-1].rotation_dps

	func status() -> String:
		return fake_status

	func web_permission() -> String:
		return fake_permission

	func has_gyro() -> bool:
		return true

	func request_web_permission() -> void:
		asked += 1


func test_calibration_asks_for_motion_from_a_tap() -> void:
	UIHarness.fresh_profile()
	var r := FakeReader.new()
	var app := UIHarness.make_app(tree, "calibration", {"reader": r})
	await UIHarness.settle(tree)
	var screen := app.current()
	check(screen.get("reader") == r, "the screen reads the given sensors")
	var ask := UIHarness.find_button(screen, "EnableMotion")
	if check(ask != null, "\"Tap to enable motion\" while the browser has not granted it"):
		check_eq(ask.text, tr("cal_permission"), "in words")
		check(UIHarness.press(screen, "EnableMotion"), "the player taps it")
		check_eq(r.asked, 1, "and that tap asks the browser")
	check(UIHarness.find_button(screen, "UseSlam") != null, "buttons stay offered")
	# Granted: waiting, then ok; the prompt goes and the tilts are asked for.
	r.fake_status = "waiting"
	r.fake_permission = "granted"
	await UIHarness.frames(tree, 3)
	await UIHarness.settle(tree)
	check(UIHarness.find_button(screen, "EnableMotion") == null, "the prompt goes once access is granted")
	check_eq((screen.find_child("Sensor", true, false) as Label).text, "", "and its note")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_calibration_feeds_every_reading_of_a_frame() -> void:
	UIHarness.fresh_profile()
	var r := FakeReader.new()
	r.fake_status = "ok"
	r.fake_permission = "granted"
	var app := UIHarness.make_app(tree, "calibration", {"reader": r})
	await UIHarness.settle(tree)
	var screen := app.current()
	var orig: Calibrator = screen.get("calibrator")
	# Two readings in one frame, 12 ms apart: both reach the calibrator, the older one earlier.
	var got: Array = []
	screen.set("calibrator", _Spy.new(got))
	r.frame = [
		{"age": 0.012, "linear": Vector3(0, 0, 3), "rotation_dps": Vector3(400, 0, 0)},
		{"age": 0.0, "linear": Vector3(0, 0, 1), "rotation_dps": Vector3(100, 0, 0)},
	]
	await tree.process_frame
	await tree.process_frame
	if check_eq(got.size(), 2, "both readings of the frame are fed"):
		check_near(float(got[1]) - float(got[0]), 0.012, 0.0005, "each at its own time (now - age)")
	screen.set("calibrator", orig)
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_refused_motion_falls_back_to_buttons() -> void:
	UIHarness.fresh_profile()
	var r := FakeReader.new()
	r.fake_status = "no_sensor"
	r.fake_permission = "denied"
	var app := UIHarness.make_app(tree, "calibration", {"reader": r})
	await UIHarness.settle(tree)
	var screen := app.current()
	var labels := []
	for l in screen.find_children("*", "Label", true, false):
		labels.append((l as Label).text)
	check(tr("cal_fail_denied") in labels, "a refusal is explained as a refusal (%s)" % str(labels))
	check(UIHarness.find_button(screen, "EnableMotion") == null, "no prompt once refused")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


func test_settings_names_the_web_states() -> void:
	check(tr("motion_permission") != "motion_permission", "a line for motion not yet allowed")
	check(tr("motion_denied") != "motion_denied", "a line for motion refused")


## Once calibrated the graph turns into a check: the song's detector runs on the live sensor with its
## threshold drawn, a hand's small sway stays under it and a tilt rings and is marked.
func test_calibration_check_marks_tilts_and_not_sway() -> void:
	UIHarness.fresh_profile()
	var r := FakeReader.new()
	r.fake_status = "ok"
	r.fake_permission = "granted"
	var app := UIHarness.make_app(tree, "calibration", {"reader": r})
	await UIHarness.settle(tree)
	var screen := app.current()
	screen.call("_on_finished", {"mode": "gyro", "threshold": 120.0, "axis": 0, "up_sign": 1, "reliable": true, "median_peak": 300.0})
	var graph: TiltGraph = screen.get("graph")
	check_near(graph.threshold, 300.0 * BellDetector.PLAY_SHARE, 1e-3, "the graph draws the song's threshold")
	# Sway: 40 °/s wobbles for half a second, then one tilt toward the player peaking at 300.
	for i in 30:
		r.frame = [{"age": 0.0, "linear": Vector3.ZERO, "rotation_dps": Vector3(40.0 * sin(i * 0.7), 0, 0)}]
		await tree.process_frame
	check_eq(graph.ring_count(), 0, "holding the phone rings nothing")
	for i in 12:
		r.frame = [{"age": 0.0, "linear": Vector3.ZERO, "rotation_dps": Vector3(300.0 * sin(PI * i / 11.0), 0, 0)}]
		await tree.process_frame
	check_eq(graph.ring_count(), 1, "a tilt rings once and is marked")
	UIHarness.free_app(app)
	UIHarness.restore_profile()


## Records the times fed to it (the calibrator's feed signature).
class _Spy extends Calibrator:
	var got: Array

	func _init(p_got: Array) -> void:
		got = p_got

	func feed(t: float, _acc: Vector3, _gyro: Vector3, _has_gyro := true) -> void:
		got.append(t)
