class_name Calibrator
extends RefCounted
## Learns the player's tilt: three sharp tilts up, then three down (docs/design.md section 2).
##
## A move starts when acceleration > 4 m/s² or rotation > 80 °/s, is watched for 150 ms for its
## peak, and the first clear lobe (> 75 % of the trigger) gives its direction. The next move can
## start once the signal is below half the trigger and 300 ms have passed.
## Then, for each signal (gyroscope, accelerometer): the axis with the largest summed |value|, the
## sign that means "up", how many of the 6 moves read the right way, and the median peak. The
## gyroscope is used when it agrees at least as often. Threshold = 45 % of the median peak, clamped
## to 60–600 °/s or 4–25 m/s². Direction is reliable at 5 of 6.
##
## Feed it every frame: feed(t, motion.linear, motion.rotation_dps, motion.has_gyro()).
## result() is the Dictionary to store in Profile and give to BellDetector.from_calibration().

signal move_detected(index: int, up: bool, strength: float)
signal finished(result: Dictionary)
signal failed(reason: String)   ## "too_soft" or "no_sensor"

const PER_DIR := 3
const ACC_TRIGGER := 4.0
const ROT_TRIGGER := 80.0
const WATCH := 0.150
const REARM := 0.300
const LOBE := 0.75
const SHARE := 0.45
const ROT_RANGE := Vector2(60.0, 600.0)
const ACC_RANGE := Vector2(4.0, 25.0)
const RELIABLE := 5
const NO_SENSOR_TIME := 2.0

var moves: Array = []   ## {up, peak_a, peak_r, acc_vec (Vector3 or null), rot_vec}
var _capture: Dictionary = {}
var _armed := true
var _last := -INF
var _done := false
var _result: Dictionary = {}
var _gyro_seen := false
var _silent_since := NAN


func start() -> void:
	moves.clear()
	_capture = {}
	_armed = true
	_last = -INF
	_done = false
	_result = {}
	_gyro_seen = false
	_silent_since = NAN


func count() -> int:
	return moves.size()


func expecting_up() -> bool:
	return moves.size() < PER_DIR


func is_done() -> bool:
	return _done


## {} until finished; then {mode: "gyro"|"accel", threshold, axis, up_sign, agree, reliable,
## median_peak, has_gyro}.
func result() -> Dictionary:
	return _result.duplicate()


func feed(t: float, acc: Vector3, gyro_dps: Vector3, has_gyro := true) -> void:
	if _done:
		return
	var m := acc.length()
	var rm := gyro_dps.length() if has_gyro else 0.0
	if has_gyro and gyro_dps != Vector3.ZERO:
		_gyro_seen = true
	# A sensor that reads exactly zero for a while is not there.
	if acc == Vector3.ZERO and (gyro_dps == Vector3.ZERO or not has_gyro):
		if is_nan(_silent_since):
			_silent_since = t
		elif t - _silent_since >= NO_SENSOR_TIME and moves.is_empty():
			_done = true
			failed.emit("no_sensor")
			return
	else:
		_silent_since = NAN
	if not _capture.is_empty():
		_capture.peak_a = maxf(_capture.peak_a, m)
		_capture.peak_r = maxf(_capture.peak_r, rm)
		if _capture.acc_vec == null and m > ACC_TRIGGER * LOBE:
			_capture.acc_vec = acc
		if _capture.rot_vec == null and rm > ROT_TRIGGER * LOBE:
			_capture.rot_vec = gyro_dps
		if t - _capture.t0 > WATCH:
			_capture.up = moves.size() < PER_DIR
			moves.append(_capture)
			_capture = {}
			_last = t
			var mv: Dictionary = moves[-1]
			move_detected.emit(moves.size() - 1, mv.up, clampf(maxf(mv.peak_a / 30.0, mv.peak_r / 600.0), 0.0, 1.0))
			if moves.size() == PER_DIR * 2:
				_finish()
		return
	if not _armed and m < ACC_TRIGGER * 0.5 and rm < ROT_TRIGGER * 0.5 and t - _last > REARM:
		_armed = true
	if _armed and (m > ACC_TRIGGER or rm > ROT_TRIGGER):
		_armed = false
		_capture = {
			"t0": t, "peak_a": m, "peak_r": rm,
			"acc_vec": null,
			"rot_vec": null,
		}
		if m > ACC_TRIGGER * LOBE:
			_capture.acc_vec = acc
		if rm > ROT_TRIGGER * LOBE:
			_capture.rot_vec = gyro_dps


func _finish() -> void:
	_done = true
	var rot := _analyse("rot_vec", "peak_r") if _gyro_seen else {}
	var acc := _analyse("acc_vec", "peak_a")
	var use_rot: bool = not rot.is_empty() and (acc.is_empty() or rot.agree >= acc.agree)
	var pick := rot if use_rot else acc
	if pick.is_empty():
		failed.emit("too_soft")
		return
	var r := ROT_RANGE if use_rot else ACC_RANGE
	_result = {
		"mode": "gyro" if use_rot else "accel",
		"threshold": clampf(pick.median * SHARE, r.x, r.y),
		"axis": pick.axis,
		"up_sign": pick.up_sign,
		"agree": pick.agree,
		"reliable": pick.agree >= RELIABLE,
		"median_peak": pick.median,
		"has_gyro": _gyro_seen,
	}
	finished.emit(_result.duplicate())


# For one signal: the axis carrying the move, which sign is up, how many moves read the right way,
# and the typical peak. {} when some move never showed a clear lobe on this signal.
func _analyse(vec_key: String, peak_key: String) -> Dictionary:
	for mv in moves:
		if mv[vec_key] == null:
			return {}
	var sums := [0.0, 0.0, 0.0]
	for mv in moves:
		for i in 3:
			sums[i] += absf(mv[vec_key][i])
	var axis := 0
	for i in 3:
		if sums[i] > sums[axis]:
			axis = i
	var up_total := 0.0
	for mv in moves:
		if mv.up:
			up_total += signf(mv[vec_key][axis])
	var up_sign := 1 if up_total >= 0.0 else -1
	var agree := 0
	for mv in moves:
		var s := int(signf(mv[vec_key][axis]))
		if (mv.up and s == up_sign) or (not mv.up and s == -up_sign):
			agree += 1
	var peaks := []
	for mv in moves:
		peaks.append(mv[peak_key])
	peaks.sort()
	return {"axis": axis, "up_sign": up_sign, "agree": agree, "median": peaks[peaks.size() >> 1]}
