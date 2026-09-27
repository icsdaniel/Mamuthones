class_name MotionReader
extends RefCounted
## Turns raw sensor readings into what Calibrator and BellDetector use:
## linear acceleration in m/s² (gravity removed) and rotation rate in degrees per second.
##
## Natively (Android, iOS) it reads Godot's Input sensors once per frame. In a Web export Godot has
## no sensors, so it listens to the browser's devicemotion events through WebMotion (see
## web_motion.gd for the axis mapping) and gets every event since the last frame.
##
## Linear acceleration = accelerometer - gravity. Some phones (and browsers) report no gravity
## vector (zero); then gravity is estimated with a low-pass filter of the accelerometer.
## Call read(delta) once per frame; process() and ingest_web() take the same values from tests.
##
## After read(): linear / rotation_dps hold the newest reading, and samples holds every reading of
## this frame, oldest first, as {age, linear, rotation_dps} (age = seconds before now). Natively that
## is one sample with age 0; on the web a 60 Hz sensor gives 0-2 per frame. Feed each one to the
## detector at time now - age (InputRouter does), so no flick is missed and each is timed by the
## sensor, not the frame.
##
## Web on iOS: call request_web_permission() from a tap (the calibration Start button, or the first
## tap). Until access is granted status() is "permission"; a refusal is "no_sensor" (play with the
## buttons).

const GRAVITY_TIME := 0.2     ## seconds, time constant of the fallback gravity estimate
const DETECT_TIME := 1.0      ## seconds of readings before a silent sensor counts as missing

var linear := Vector3.ZERO
var rotation_dps := Vector3.ZERO
## This frame's readings, oldest first: [{age, linear, rotation_dps}].
var samples: Array = []
## Seconds of readings so far.
var elapsed := 0.0
## Reading from the browser (Web export).
var web := false
var _web: WebMotion = null
var _gravity := Vector3.ZERO
var _have_gravity := false
var _accel_seen := false
var _gyro_seen := false
var _wait_from := 0.0          # elapsed when listening started (web: when access was granted)
var _last_state := ""


func _init() -> void:
	if WebMotion.supported():
		web = true
		_web = WebMotion.new()
		_web.install()


## Asks the browser for motion access (needed on iOS Safari). Call it from a tap handler. Does
## nothing natively.
func request_web_permission() -> void:
	if _web != null:
		_web.request_permission()


## The browser's motion permission: "native" when not on the web, else WebMotion.state
## ("unknown", "prompt", "granted", "denied", "unsupported").
func web_permission() -> String:
	return _web.state if _web != null else "native"


func read(delta: float) -> void:
	if _web != null:
		var got := _web.drain()
		if _web.state != _last_state:
			_last_state = _web.state
			_wait_from = elapsed   # give a newly granted sensor its own second to speak
		ingest_web(got, delta)
		return
	samples.clear()
	process(Input.get_accelerometer(), Input.get_gravity(), Input.get_gyroscope(), delta)
	samples.append({"age": 0.0, "linear": linear, "rotation_dps": rotation_dps})


## One frame of converted browser samples (WebMotion.convert_all()), oldest first.
func ingest_web(converted: Array, delta: float) -> void:
	samples.clear()
	if converted.is_empty():
		elapsed += delta
		return
	var prev_age: float = converted[0].age + delta / converted.size()
	for i in converted.size():
		var s: Dictionary = converted[i]
		var dt := maxf(prev_age - float(s.age), 0.0)
		prev_age = s.age
		_take(s.accel, s.gravity, s.gyro_rad, dt)
		if s.get("has_gyro", false):
			_gyro_seen = true   # a rotationRate was sent: the gyro is there even while the phone is still
		samples.append({"age": s.age, "linear": linear, "rotation_dps": rotation_dps})
	elapsed += delta


func process(accel: Vector3, gravity: Vector3, gyro_rad: Vector3, delta: float) -> void:
	elapsed += delta
	_take(accel, gravity, gyro_rad, delta)


func _take(accel: Vector3, gravity: Vector3, gyro_rad: Vector3, delta: float) -> void:
	if accel != Vector3.ZERO:
		_accel_seen = true
	if gyro_rad != Vector3.ZERO:
		_gyro_seen = true
	_smooth_gravity(accel, gravity, delta)
	rotation_dps = gyro_rad * (180.0 / PI)


func _smooth_gravity(accel: Vector3, gravity: Vector3, delta: float) -> void:
	if gravity.length_squared() > 1.0:
		linear = accel - gravity
		return
	if not _have_gravity:
		_gravity = accel
		_have_gravity = true
	else:
		_gravity = _gravity.lerp(accel, 1.0 - exp(-maxf(delta, 0.0) / GRAVITY_TIME))
	linear = accel - _gravity


## A motion sensor has produced readings.
func available() -> bool:
	return _accel_seen or _gyro_seen


func has_gyro() -> bool:
	return _gyro_seen


## "waiting" (too early to tell), "ok", "no_gyro" (accelerometer only: works, less precise),
## "permission" (web: the browser needs request_web_permission() from a tap) or "no_sensor"
## (nothing, or access refused: play with slam mode). On the web a sensor counts only once real
## devicemotion events have arrived.
func status() -> String:
	if _gyro_seen and _accel_seen:
		return "ok"
	if _web != null:
		match _web.state:
			"denied", "unsupported":
				if not available():
					return "no_sensor"
			"prompt", "unknown":
				if not available():
					return "permission"
	if elapsed - _wait_from < DETECT_TIME:
		return "waiting"
	if _accel_seen:
		return "no_gyro"
	if _gyro_seen:
		return "ok"
	return "no_sensor"
