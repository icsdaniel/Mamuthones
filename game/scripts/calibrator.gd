class_name Calibrator
extends RefCounted
## Learns how this phone reads a bell tilt: three sharp tilts up, then three down.
## It records the peak and direction of each move for both the gyroscope and the
## accelerometer, then keeps whichever reads direction better, with a threshold at
## 45% of the typical peak.

const ACC_TRIGGER := 4.0    ## m/s²
const ROT_TRIGGER := 80.0   ## degrees per second
const PER_DIR := 3
const CAPTURE := 0.15       ## seconds a move is watched for its peak
const REARM := 0.3          ## seconds of calm before the next move counts

var moves: Array[Dictionary] = []
var _capture := {}
var _armed := true
var _last := -INF


func reset() -> void:
	moves.clear()
	_capture = {}
	_armed = true
	_last = -INF


func wants_up() -> bool:
	return moves.size() < PER_DIR


func is_done() -> bool:
	return moves.size() >= PER_DIR * 2


## Feed one sensor sample. Returns true when it completes a move.
func feed(t: float, v: Vector3, r: Vector3, has_gyro := true) -> bool:
	if is_done():
		return false
	var m := v.length()
	var rm := r.length() if has_gyro else 0.0
	if not _capture.is_empty():
		_capture.peak_acc = maxf(_capture.peak_acc, m)
		_capture.peak_rot = maxf(_capture.peak_rot, rm)
		# Direction = the first clear lobe of each signal.
		if _capture.acc == null and m > ACC_TRIGGER * 0.75:
			_capture.acc = v
		if _capture.rot == null and rm > ROT_TRIGGER * 0.75:
			_capture.rot = r
		if t - _capture.t0 > CAPTURE:
			_capture.up = wants_up()
			moves.append(_capture)
			_capture = {}
			_last = t
			return true
		return false
	if not _armed and m < ACC_TRIGGER * 0.5 and rm < ROT_TRIGGER * 0.5 and t - _last > REARM:
		_armed = true
	if _armed and (m > ACC_TRIGGER or rm > ROT_TRIGGER):
		_armed = false
		_capture = {
			t0 = t, peak_acc = m, peak_rot = rm,
			acc = v if m > ACC_TRIGGER * 0.75 else null,
			rot = r if rm > ROT_TRIGGER * 0.75 else null,
		}
	return false


## The calibration to save, or {} when the moves were too soft to measure.
## Keys: mode ("rot" or "acc"), thr, axis, up_sign, dir_ok, agree.
func result() -> Dictionary:
	var rot := _analyse("rot", "peak_rot")
	var acc := _analyse("acc", "peak_acc")
	var use_rot: bool = not rot.is_empty() and (acc.is_empty() or rot.agree >= acc.agree)
	var pick := rot if use_rot else acc
	if pick.is_empty():
		return {}
	var thr: float
	if use_rot:
		thr = clampf(pick.median * 0.45, 60.0, 600.0)
	else:
		thr = clampf(pick.median * 0.45, 4.0, 25.0)
	return {
		mode = "rot" if use_rot else "acc", thr = thr, axis = pick.axis,
		up_sign = pick.up_sign, dir_ok = pick.agree >= 5, agree = pick.agree,
	}


## For one signal: which axis carries the move, which sign is "up",
## how many of the 6 moves it reads the right way, and the typical peak.
func _analyse(vec_key: String, peak_key: String) -> Dictionary:
	if moves.size() < PER_DIR * 2 or moves.any(func(mv): return mv[vec_key] == null):
		return {}
	var sums := [0.0, 0.0, 0.0]
	for mv in moves:
		for i in 3:
			sums[i] += absf(mv[vec_key][i])
	var axis := sums.find(sums.max())
	var up_total := 0.0
	for mv in moves:
		if mv.up:
			up_total += signf(mv[vec_key][axis])
	var up_sign := signf(up_total)
	if up_sign == 0.0:
		up_sign = 1.0
	var agree := 0
	for mv in moves:
		var s := signf(mv[vec_key][axis])
		if (mv.up and s == up_sign) or (not mv.up and s == -up_sign):
			agree += 1
	var peaks: Array = moves.map(func(mv): return mv[peak_key])
	peaks.sort()
	return { axis = axis, up_sign = up_sign, agree = agree, median = peaks[peaks.size() / 2] }
