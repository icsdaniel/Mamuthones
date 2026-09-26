class_name BellDetector
extends RefCounted
## Turns the motion sensor stream into bell rings, using the player's calibration.
## A tilt often swings down and back up, so after a ring the detector waits half a beat
## and for the signal to settle below half the threshold before it can ring again.

var mode := "rot"  ## "rot" reads the gyroscope, "acc" reads linear acceleration
var threshold := 150.0
var lockout := 0.35
var _armed := true
var _last := -INF


func _init(calibration: Dictionary, bpm: float) -> void:
	mode = calibration.get("mode", "rot")
	threshold = float(calibration.get("thr", 150.0))
	lockout = 30.0 / bpm


## t in seconds, lin_acc in m/s² with gravity removed, rot in degrees per second.
## Returns true when this sample rings the bell.
func feed(t: float, lin_acc: Vector3, rot: Vector3) -> bool:
	var val := rot.length() if mode == "rot" else lin_acc.length()
	if not _armed and t - _last > lockout and val < threshold * 0.5:
		_armed = true
	if not _armed or val <= threshold:
		return false
	_armed = false
	_last = t
	return true
