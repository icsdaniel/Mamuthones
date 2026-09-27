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
## On a phone with a gyroscope a tilt always rotates the phone, so a move with no clear rotation
## lobe (a thumb tap, a knock) is ignored and move_ignored fires: the player is asked for one more
## tilt. After MAX_IGNORED ignored moves in a row the next one counts anyway and so do all later
## ones, so a phone whose gyro barely reacts can still finish (it falls back to the accelerometer).
## rise_time: the typical seconds from rest to peak of the player's flick, for the ring strength.
##
## Feed it every frame: feed(t, motion.linear, motion.rotation_dps, motion.has_gyro()).
## result() is the Dictionary to store in Profile and give to BellDetector.from_calibration().

signal move_detected(index: int, up: bool, strength: float)
signal finished(result: Dictionary)
signal failed(reason: String)   ## "too_soft" or "no_sensor"
signal move_ignored(reason: String)   ## "no_rotation": a tap, not a tilt; ask for the move again

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
const MAX_IGNORED := 3
const MIN_VALID := 4          ## moves with a clear lobe a signal needs to be analysed

var moves: Array = []   ## {up, peak_a, peak_r, acc_vec (Vector3 or null), rot_vec}
var _capture: Dictionary = {}
var _armed := true
var _last := -INF
var _done := false
var _result: Dictionary = {}
var _gyro_seen := false
var _silent_since := NAN
var _ignored := 0
var _accept_all := false
var ignored_total := 0
var _prev_t := -INF
var _prev_m := 0.0
var _prev_rm := 0.0


func start() -> void:
	moves.clear()
	_capture = {}
	_armed = true
	_last = -INF
	_done = false
	_result = {}
	_gyro_seen = false
	_silent_since = NAN
	_ignored = 0
	_accept_all = false
	ignored_total = 0
	_prev_t = -INF


func count() -> int:
	return moves.size()


func expecting_up() -> bool:
	return moves.size() < PER_DIR


func is_done() -> bool:
	return _done


## {} until finished; then {mode: "gyro"|"accel", threshold, axis, up_sign, agree, reliable,
## median_peak, rise_time, has_gyro}.
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
	_feed_move(t, acc, gyro_dps, m, rm)
	_prev_t = t
	_prev_m = m
	_prev_rm = rm


func _feed_move(t: float, acc: Vector3, gyro_dps: Vector3, m: float, rm: float) -> void:
	if not _capture.is_empty():
		if is_nan(_capture.ta) and m > ACC_TRIGGER:
			_capture.ta = _cross(ACC_TRIGGER, _prev_m, m, t)
		if is_nan(_capture.tr) and rm > ROT_TRIGGER:
			_capture.tr = _cross(ROT_TRIGGER, _prev_rm, rm, t)
		if m > _capture.peak_a:
			_capture.peak_a = m
			_capture.tp_a = t
		if rm > _capture.peak_r:
			_capture.peak_r = rm
			_capture.tp_r = t
		if _capture.acc_vec == null and m > ACC_TRIGGER * LOBE:
			_capture.acc_vec = acc
		if _capture.rot_vec == null and rm > ROT_TRIGGER * LOBE:
			_capture.rot_vec = gyro_dps
		if t - _capture.t0 > WATCH:
			_capture.up = moves.size() < PER_DIR
			var tap: bool = _gyro_seen and _capture.rot_vec == null
			if tap and _ignored < MAX_IGNORED and not _accept_all:
				_ignored += 1
				ignored_total += 1
				_capture = {}
				_last = t
				move_ignored.emit("no_rotation")
				return
			if tap:
				_accept_all = true   # this gyro barely reacts: stop asking again
			_ignored = 0
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
			"t0": t, "peak_a": m, "peak_r": rm, "tp_a": t, "tp_r": t,
			# when each signal crossed its trigger (interpolated back to between the frames)
			"ta": _cross(ACC_TRIGGER, _prev_m, m, t) if m > ACC_TRIGGER else NAN,
			"tr": _cross(ROT_TRIGGER, _prev_rm, rm, t) if rm > ROT_TRIGGER else NAN,
			"acc_vec": null,
			"rot_vec": null,
		}
		if m > ACC_TRIGGER * LOBE:
			_capture.acc_vec = acc
		if rm > ROT_TRIGGER * LOBE:
			_capture.rot_vec = gyro_dps


func _finish() -> void:
	_done = true
	var rot := _analyse("rot_vec", "peak_r", "tp_r", "tr", ROT_TRIGGER) if _gyro_seen else {}
	var acc := _analyse("acc_vec", "peak_a", "tp_a", "ta", ACC_TRIGGER)
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
		"rise_time": pick.rise,
		"has_gyro": _gyro_seen,
	}
	finished.emit(_result.duplicate())


# When a signal rising from `prev` (one frame ago) to `now` crossed `level`.
func _cross(level: float, prev: float, now: float, t: float) -> float:
	if now <= level or prev >= level or now <= prev or t - _prev_t > 0.06:
		return t
	return _prev_t + (level - prev) / (now - prev) * (t - _prev_t)


# For one signal: the axis carrying the move, which sign is up, how many moves read the right way,
# the typical peak and rise time. Moves without a clear lobe on this signal are left out (and do not
# agree); {} when fewer than MIN_VALID moves have one.
func _analyse(vec_key: String, peak_key: String, tp_key: String, t0_key: String, trigger: float) -> Dictionary:
	var valid := []
	for mv in moves:
		if mv[vec_key] != null:
			valid.append(mv)
	if valid.size() < MIN_VALID:
		return {}
	var sums := [0.0, 0.0, 0.0]
	for mv in valid:
		for i in 3:
			sums[i] += absf(mv[vec_key][i])
	var axis := 0
	for i in 3:
		if sums[i] > sums[axis]:
			axis = i
	var up_total := 0.0
	for mv in valid:
		if mv.up:
			up_total += signf(mv[vec_key][axis])
	var up_sign := 1 if up_total >= 0.0 else -1
	var agree := 0
	for mv in valid:
		var s := int(signf(mv[vec_key][axis]))
		if (mv.up and s == up_sign) or (not mv.up and s == -up_sign):
			agree += 1
	var peaks := []
	var rises := []
	for mv in valid:
		var p: float = mv[peak_key]
		peaks.append(p)
		# A sine rising to p passes the trigger at phase asin(trigger / p): scale up to rest-to-peak.
		var phase := asin(clampf(trigger / maxf(p, 1e-6), 0.0, 1.0)) / (PI * 0.5)
		var t0: float = mv[t0_key] if not is_nan(mv[t0_key]) else mv.t0
		rises.append((float(mv[tp_key]) - t0) / maxf(1.0 - phase, 0.2))
	peaks.sort()
	rises.sort()
	return {"axis": axis, "up_sign": up_sign, "agree": agree, "median": peaks[peaks.size() >> 1],
			"rise": clampf(rises[rises.size() >> 1], 0.02, 0.15)}
