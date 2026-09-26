class_name BellDetector
extends RefCounted
## Rings the bell from the motion signal, using the player's calibration.
##
## - The signal is the calibrated axis only (rotation °/s about it in gyro mode, linear m/s² along
##   it in accel mode), so turning the body or walking does not ring.
## - Phones often sample the sensors slower than the game draws frames, so the same reading comes
##   back several frames running. A repeated identical reading is not news: it never starts or
##   confirms a ring (it only moves the clock for re-arming).
## - A ring starts where the signal crosses the threshold (interpolated between readings, and moved
##   back by the estimated age of a held reading). It only counts once the signal has stayed above
##   half the threshold for 25 ms (45 ms right after a touch in accel mode). In gyro mode a reading
##   over the full threshold rings at once when a reading at least 5 ms earlier caught the same lobe
##   on its rising slope (so usually on the first frame past the crossing): a tilt lasts 100 ms or
##   more and rises over tens of ms, a thumb tap or knock is a jump of a few ms, mostly on the
##   screen's z axis.
## - One flick = one ring: a down-and-up flick has two lobes, so after a ring the detector waits
##   0.45 beat (bells written half a beat apart stay playable) AND for the signal to stay below half
##   the threshold for 50 ms (the dip between the two lobes of a slow flick is shorter than that).
## - Adapts during a song: if flicks get softer, the threshold follows 45 % of the recent peaks,
##   and repeated near-misses (clear lobes just under the threshold) lower it, never below 60 %
##   of the calibrated value.

signal rang(t: float, up: bool)

const LOCKOUT_BEATS := 0.45
const CALM := 0.050           ## seconds below half the threshold before the next ring can start
const SUSTAIN := 0.5          ## share of the threshold the signal must keep while confirming
const CONFIRM := 0.025        ## seconds above SUSTAIN that make a ring
const CONFIRM_NEAR_TOUCH := 0.045
## Gyro fast path: a reading over the full threshold confirms at once when an earlier reading of the
## same lobe, at least 5 ms before, was on the rising slope (between a quarter and the full threshold).
## A tilt rises over tens of ms and leaves such readings; a knock or tap jumps from nothing to its
## peak between two readings and does not, so it still needs the full 25 ms. This cuts the sound's
## lag to about one frame for most flicks without letting knocks through.
const CONFIRM_FAST := 0.005
const SLOPE := 0.25           ## rising-slope readings lie between this share and the full threshold
const MAX_GAP := 0.06         ## seconds; a longer gap between readings breaks interpolation
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
## How hard the last ring was, 0-1: clamp((peak / calibrated threshold - 1) / 2, 0, 1), from the
## peak on the calibrated axis seen up to the moment the ring was confirmed (the sound cannot wait
## for the rest of the flick). A flick just over the threshold is 0, one at three times it is 1.
var last_strength := 0.5
## Seconds between distinct sensor readings (smoothed).
var sample_interval := 1.0 / 60.0

var _armed := true
var _calm_since := NAN
var _cand_t := NAN
var _cand_first := NAN
var _cand_vec := Vector3.ZERO
var _cand_peak := 0.0
var _rise_since := NAN        # first fresh reading of the current lobe on its rising slope
var _lobe_over := false # the current lobe already went over the threshold
var _prev_v := 0.0
var _prev_t := -INF
var _last_vec := Vector3(NAN, NAN, NAN)
var _held_seen := 0.0         # > 0 while repeated readings are being seen (sensor slower than frames)
var _last_touch := -INF
var _peak := 0.0
var _peak_until := -INF
var _recent: Array[float] = []
var _near_n := 0
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
	# Without a calibration: tilting the top edge is rotation about x, or acceleration along z.
	axis = clampi(int(d.get("axis", 0 if mode == "gyro" else 2)), 0, 2) if d.get("mode", "") == mode else (0 if mode == "gyro" else 2)
	up_sign = 1 if int(d.get("up_sign", 1)) >= 0 else -1
	reliable = bool(d.get("reliable", false))
	reset()


func set_bpm(p_bpm: float) -> void:
	bpm = maxf(p_bpm, 1.0)


func lockout() -> float:
	return LOCKOUT_BEATS * 60.0 / bpm


func reset() -> void:
	_armed = true
	_calm_since = NAN
	_cand_t = NAN
	_rise_since = NAN
	_lobe_over = false
	_prev_v = 0.0
	_prev_t = -INF
	_last_vec = Vector3(NAN, NAN, NAN)
	last_t = -INF
	_peak_until = -INF
	_near_n = 0


## A finger touched the screen at time t (taps shake the phone).
func note_touch(t: float) -> void:
	_last_touch = t


## One reading. Returns true when it completes a ring (then last_t / last_up describe it and the
## rang signal has fired). t is the song time the reading was taken (the frame's time).
func feed(t: float, acc: Vector3, gyro_dps: Vector3) -> bool:
	var vec := gyro_dps if mode == "gyro" else acc
	var v := absf(vec[axis])
	var fresh := vec != _last_vec
	if fresh:
		if t - _prev_t <= 0.05:
			sample_interval = lerpf(sample_interval, clampf(t - _prev_t, 0.002, 0.05), 0.2)
		_held_seen = maxf(0.0, _held_seen - 0.02)
		_last_vec = vec
	elif vec != Vector3.ZERO and t - _prev_t <= 0.05:
		# A real sensor never repeats itself exactly unless the reading is being held.
		_held_seen = 1.0
	var fired := false
	# Watch the peak of the last ring, for adapting.
	if t <= _peak_until:
		_peak = maxf(_peak, v)
	elif _peak_until > -INF:
		_learn_peak(_peak)
		_peak_until = -INF
	if not _armed:
		if v < threshold * 0.5:
			if is_nan(_calm_since):
				_calm_since = t
		else:
			_calm_since = NAN
		if t - last_t >= lockout() and not is_nan(_calm_since) and t - _calm_since >= CALM:
			_armed = true
	# A held reading says nothing new about a starting ring.
	if not fresh:
		return false
	if v < threshold * SLOPE:
		_rise_since = NAN
	elif is_nan(_rise_since) and v < threshold and not _lobe_over:
		_rise_since = t   # a reading on the rising slope, between half and the full threshold
	_lobe_over = v >= threshold * SLOPE and (_lobe_over or v >= threshold)
	var fast := mode == "gyro" and v >= threshold and not is_nan(_rise_since) and t - _rise_since >= CONFIRM_FAST - 1e-4
	if _armed:
		if is_nan(_cand_t):
			if v > threshold:
				_cand_t = t
				if v > _prev_v and t - _prev_t <= MAX_GAP:
					_cand_t = _prev_t + (threshold - _prev_v) / (v - _prev_v) * (t - _prev_t)
				_cand_first = t
				_cand_vec = vec
				_cand_peak = v
				if fast:
					fired = true
					_fire()
			else:
				_watch_near(v, t)
		elif v >= threshold * SUSTAIN:
			_cand_peak = maxf(_cand_peak, v)
			var near_touch := mode == "accel" and _last_touch >= _cand_t - TOUCH_WINDOW and _last_touch <= t
			if fast or t - _cand_first >= (CONFIRM_NEAR_TOUCH if near_touch else CONFIRM):
				fired = true
				_fire()
		else:
			_cand_t = NAN   # a spike: gone before it lasted
	_prev_v = v
	_prev_t = t
	return fired


# Age of a reading: when the sensor is slower than the frames, a held reading was taken on
# average half a sensor interval before the frame that shows it.
func _reading_age() -> float:
	return 0.5 * sample_interval if _held_seen > 0.0 else 0.0


func _fire() -> void:
	_armed = false
	_calm_since = NAN
	last_t = _cand_t - _reading_age()
	var s := signf(_cand_vec[axis]) * up_sign
	last_up = s >= 0.0
	last_strength = strength_of(_cand_peak)
	_cand_t = NAN
	_near_n = 0
	_peak = 0.0
	_peak_until = last_t + PEAK_WATCH
	rang.emit(last_t, last_up)


## Strength (0-1) of a flick peaking at peak, relative to the calibrated threshold.
func strength_of(peak: float) -> float:
	return clampf((peak / maxf(base_threshold, 1e-6) - 1.0) * 0.5, 0.0, 1.0)


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


# Sustained lobes (30 ms or more) that rise above NEAR × threshold but never cross it look like
# softened flicks. Three of them lower the threshold by 10 %.
func _watch_near(v: float, t: float) -> void:
	if not adapt:
		return
	if v > threshold * NEAR:
		if _near_n == 0:
			_cand_first = t
		_near_n += 1
	elif v < threshold * 0.3:
		if _near_n >= 2 and _prev_t - _cand_first >= 0.03 and _prev_t - _last_touch > TOUCH_WINDOW:
			_near_count += 1
			if _near_count >= 3:
				_near_count = 0
				threshold = _clamp_adapt(threshold * 0.9)
		_near_n = 0


func _clamp_adapt(x: float) -> float:
	var r: Vector2 = RANGES[mode]
	return clampf(clampf(x, base_threshold * ADAPT_FLOOR, base_threshold * ADAPT_CEIL), r.x, r.y)
