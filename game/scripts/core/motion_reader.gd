class_name MotionReader
extends RefCounted
## Turns Godot's raw sensor readings into what Calibrator and BellDetector use:
## linear acceleration in m/s² (gravity removed) and rotation rate in degrees per second.
##
## Linear acceleration = Input.get_accelerometer() - Input.get_gravity(). Some phones report no
## gravity vector (zero); then gravity is estimated with a low-pass filter of the accelerometer.
## Call read(delta) once per frame; process() takes the same values from tests.

const GRAVITY_TIME := 0.2     ## seconds, time constant of the fallback gravity estimate
const DETECT_TIME := 1.0      ## seconds of readings before a silent sensor counts as missing

var linear := Vector3.ZERO
var rotation_dps := Vector3.ZERO
## Seconds of readings so far.
var elapsed := 0.0
var _gravity := Vector3.ZERO
var _have_gravity := false
var _accel_seen := false
var _gyro_seen := false


func read(delta: float) -> void:
	process(Input.get_accelerometer(), Input.get_gravity(), Input.get_gyroscope(), delta)


func process(accel: Vector3, gravity: Vector3, gyro_rad: Vector3, delta: float) -> void:
	elapsed += delta
	if accel != Vector3.ZERO:
		_accel_seen = true
	if gyro_rad != Vector3.ZERO:
		_gyro_seen = true
	if gravity.length_squared() > 1.0:
		linear = accel - gravity
	else:
		if not _have_gravity:
			_gravity = accel
			_have_gravity = true
		else:
			_gravity = _gravity.lerp(accel, 1.0 - exp(-maxf(delta, 0.0) / GRAVITY_TIME))
		linear = accel - _gravity
	rotation_dps = gyro_rad * (180.0 / PI)


## A motion sensor has produced readings.
func available() -> bool:
	return _accel_seen or _gyro_seen


func has_gyro() -> bool:
	return _gyro_seen


## "waiting" (too early to tell), "ok", "no_gyro" (accelerometer only: works, less precise) or
## "no_sensor" (nothing: play with slam mode).
func status() -> String:
	if _gyro_seen and _accel_seen:
		return "ok"
	if elapsed < DETECT_TIME:
		return "waiting"
	if _accel_seen:
		return "no_gyro"
	if _gyro_seen:
		return "ok"
	return "no_sensor"
