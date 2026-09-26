class_name MotionReader
extends RefCounted
## Reads the phone's motion sensors in the units the game uses:
## linear acceleration in m/s² (gravity removed) and rotation in degrees per second.

var has_gyro := false
var has_motion := false
var _gravity := Vector3.ZERO


## Returns [linear acceleration, rotation].
func read() -> Array:
	var raw := Input.get_accelerometer()
	var gravity := Input.get_gravity()
	if raw != Vector3.ZERO:
		has_motion = true
	var lin: Vector3
	if gravity != Vector3.ZERO:
		lin = raw - gravity
	else:
		# No gravity sensor: estimate gravity with a slow low-pass filter.
		_gravity = raw if _gravity == Vector3.ZERO else _gravity * 0.9 + raw * 0.1
		lin = raw - _gravity
	var rot := Input.get_gyroscope() * rad_to_deg(1.0)
	if rot != Vector3.ZERO:
		has_gyro = true
	return [lin, rot]
