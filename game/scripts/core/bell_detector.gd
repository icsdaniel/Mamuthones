class_name BellDetector
extends RefCounted
## Rings the bell from the motion signal, using the player's calibration.
##
## - A ring starts when the calibrated signal (rotation °/s in gyro mode, linear acceleration m/s²
##   in accel mode) crosses the threshold. Its time is where the crossing happened, interpolated
##   between frames.
## - One flick = one ring: a down-and-up flick has two lobes, so after a ring the detector ignores
##   motion for half a beat (0.45 beat, so bells written half a beat apart stay playable) AND
##   until the signal falls below half the threshold.
## - Thumb taps are not tilts: a hard tap is a sharp spike lasting a few ms, mostly on the screen's
##   z axis, with little rotation. So a crossing must be confirmed by the next reading still above
##   half the threshold (a tilt lasts 100 ms or more, a tap spike shows up in one frame at most).
##   Right after a touch (note_touch) the accelerometer needs one more confirming reading.
## - Adapts during a song: if flicks get softer, the threshold follows 45 % of the recent peaks,
##   and repeated near-misses (clear lobes just under the threshold) lower it, never below 60 %
##   of the calibrated value.

signal rang(t: float, up: bool)

const LOCKOUT_BEATS := 0.45
const SUSTAIN := 0.5          ## a confirming reading must stay above this share of the threshold
const MAX_GAP := 0.06         ## seconds between a crossing and its confirming reading
const TOUCH_WINDOW := 0.10    ## seconds after a touch during which accel rings need more proof
const PEAK_WATCH := 0.15
const NEAR := 0.6             ## near-miss: a sustained lobe above this share of the threshold
const ADAPT_FLOOR := 0.6
const ADAPT_CEIL := 1.25
const DEFAULTS := {"gyro": 150.0, "accel": 10.0}
const RANGES := {"gyro": Vector2(60.0, 600.0), "accel": Vector2(4.0, 25.0)}

var mode := "gyro"
var threshold := 150.0
var base_threshold := 150.0
var axis := 0
var up_sign := 1
var reliable := false
var bpm := 120.0
var adapt := true
## Time and direction of the last ring.
var last_t := -INF
var last_up := true

var _armed := true
var _cand_t := NAN
var _cand_n := 0
var _cand_vec := Vector3.ZERO
var _prev_v := 0.0
var _prev_t := -INF
var _last_touch := -INF
var _peak := 0.0
var _peak_until := -INF
var _recent: Array[float] = []
var _near_n := 0
var _near_peak := 0.0
var _near_count := 0


static func from_calibration(d: Dictionary, has_gyro := true) -> BellDetector:
	var b := BellDetector.new()
	b.configure(d, has_gyro)
	return b


func configure(d: Dictionary, has_gyro := true) -> void:
	mode = str(d.get("mode", "gyro" if has_gyro else "accel"))
	if not DEFAULTS.has(mode) or (mode == "gyro" and not has_gyro):
		mode = "gyro" if has_gyro else "accel"
	var r: Vector2 = RANGES[mode]
	threshold = clampf(float(d.get("threshold", DEFAULTS[mode])), r.x, r.y) if d.get("mode", "") == mode else DEFAULTS[mode]
	base_threshold = threshold
	axis = clampi(int(d.get("axis", 0)), 0, 2)
	up_sign = 1 if int(d.get("up_sign", 1)) >= 0 else -1
	reliable = bool(d.get("reliable", false))
	reset()


func set_bpm(p_bpm: float) -> void:
	bpm = maxf(p_bpm, 1.0)


func lockout() -> float:
	return LOCKOUT_BEATS * 60.0 / bpm


func reset() -> void:
	_armed = true
	_cand_t = NAN
	_cand_n = 0
	_prev_v = 0.0
	_prev_t = -INF
	last_t = -INF
	_peak_until = -INF
	_near_n = 0


## A finger touched the screen at time t (taps shake the phone).
func note_touch(t: float) -> void:
	_last_touch = t


## One reading. Returns true when it completes a ring (then last_t / last_up describe it and the
## rang signal has fired). t is song time of the reading.
func feed(t: float, acc: Vector3, gyro_dps: Vector3) -> bool:
	var vec := gyro_dps if mode == "gyro" else acc
	var v := vec.length()
	var fired := false
	# Watch the peak of the last ring, for adapting.
	if t <= _peak_until:
		_peak = maxf(_peak, v)
	elif _peak_until > -INF:
		_learn_peak(_peak)
		_peak_until = -INF
	if not _armed and t - last_t >= lockout() and v < threshold * 0.5:
		_armed = true
	if _armed:
		if is_nan(_cand_t):
			if v > threshold:
				_cand_t = t
				if v > _prev_v and t - _prev_t <= MAX_GAP:
					_cand_t = _prev_t + (threshold - _prev_v) / (v - _prev_v) * (t - _prev_t)
				_cand_n = 1
				_cand_vec = vec
			else:
				_watch_near(v)
		elif v >= threshold * SUSTAIN and t - _prev_t <= MAX_GAP:
			_cand_n += 1
			var near_touch := mode == "accel" and _last_touch >= _cand_t - TOUCH_WINDOW and _last_touch <= t
			if _cand_n >= (3 if near_touch else 2):
				fired = true
				_fire()
		else:
			_cand_t = NAN   # a spike: gone by the next reading
	_prev_v = v
	_prev_t = t
	return fired


func _fire() -> void:
	_armed = false
	last_t = _cand_t
	var s := signf(_cand_vec[axis]) * up_sign
	last_up = s >= 0.0
	_cand_t = NAN
	_near_n = 0
	_peak = 0.0
	_peak_until = last_t + PEAK_WATCH
	rang.emit(last_t, last_up)


func _learn_peak(p: float) -> void:
	if not adapt or p <= 0.0:
		return
	_recent.append(p)
	if _recent.size() > 8:
		_recent.remove_at(0)
	if _recent.size() < 4:
		return
	var s := _recent.duplicate()
	s.sort()
	var target: float = s[s.size() >> 1] * Calibrator.SHARE
	threshold = _clamp_adapt(lerpf(threshold, target, 0.3))


# Sustained lobes that rise above NEAR × threshold but never cross it look like softened flicks.
# Three of them lower the threshold by 10 %.
func _watch_near(v: float) -> void:
	if not adapt:
		return
	if v > threshold * NEAR:
		_near_n += 1
		_near_peak = maxf(_near_peak, v)
	elif v < threshold * 0.3:
		if _near_n >= 3 and _prev_t - _last_touch > TOUCH_WINDOW:
			_near_count += 1
			if _near_count >= 3:
				_near_count = 0
				threshold = _clamp_adapt(threshold * 0.9)
		_near_n = 0
		_near_peak = 0.0


func _clamp_adapt(x: float) -> float:
	var r: Vector2 = RANGES[mode]
	return clampf(clampf(x, base_threshold * ADAPT_FLOOR, base_threshold * ADAPT_CEIL), r.x, r.y)
