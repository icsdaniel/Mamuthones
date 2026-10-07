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
## - Stand-stills: between watch_still() and end_still() the detector also watches for any tilt at
##   all, much softer than a ring. The phone has moved (moved_at is set) when the signal stays over
##   STILL_SHARE of the calibrated threshold for STILL_SUSTAIN, or, in gyro mode, when the phone has
##   turned more than STILL_ANGLE degrees about the tilt axis since the watch began (a slow tilt).
##   A hand's tremor, a thumb tap's few-ms jolt and the sensor's drift stay well under both.

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
const STILL_SHARE := 0.35     ## share of the calibrated threshold that counts as moving in a stand-still
const STILL_SUSTAIN := 0.04   ## seconds the signal must stay over it (a tap's jolt is a few ms)
const STILL_ANGLE := 20.0     ## degrees turned about the tilt axis that break a stand-still (gyro)
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
## How hard the last ring was, 0-1: 0.5 × peak / the calibrated typical peak, so the player's
## normal flick is 0.5 and one twice as hard is 1. The ring fires before the flick peaks (the sound
## cannot wait), so the peak is predicted from the rising slope: on a flick rising like a sine to
## its peak in rise_time, a reading pair with mean value v and slope s gives
## peak = sqrt((s / w)^2 + v^2), w = PI / (2 rise_time). The larger of that and the highest reading
## so far is used.
var last_strength := 0.5
## The player's typical flick peak (from calibration; else threshold / Calibrator.SHARE).
var typical_peak := 150.0 / 0.45
## Seconds a typical flick takes from rest to its peak (from calibration; else 45 ms).
var rise_time := 0.045
## Seconds between distinct sensor readings (smoothed).
var sample_interval := 1.0 / 60.0

var _armed := true
var _calm_since := NAN
var _cand_t := NAN
var _cand_first := NAN
var _cand_vec := Vector3.ZERO
var _cand_peak := 0.0
var _cand_pred := 0.0         # peak predicted from the rising slope
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
## Stand-still watch (see watch_still): when it began (INF = not watching), the angle turned since,
## the first reading of the current movement, and the time the phone was found to have moved.
var _still_from := INF
var _still_angle := 0.0
var _still_prev_t := NAN
var _move_since := NAN
var moved_at := NAN


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
	var calibrated: bool = d.get("mode", "") == mode
	var med := float(d.get("median_peak", 0.0)) if calibrated else 0.0
	typical_peak = med if med > threshold else threshold / Calibrator.SHARE
	rise_time = clampf(float(d.get("rise_time", 0.045)), 0.02, 0.15)
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


## Starts watching for any tilt from time t (a stand-still began); moved_at is cleared.
func watch_still(t: float) -> void:
	_still_from = t
	_still_angle = 0.0
	_still_prev_t = NAN
	_move_since = NAN
	moved_at = NAN


## Stops watching (the stand-still ended or was already broken).
func end_still() -> void:
	_still_from = INF
	_move_since = NAN


func watching_still() -> bool:
	return _still_from < INF


func _watch_still(t: float, v: float, signed_v: float) -> void:
	if t < _still_from or not is_nan(moved_at):
		return
	if mode == "gyro":
		if not is_nan(_still_prev_t):
			_still_angle += signed_v * clampf(t - _still_prev_t, 0.0, MAX_GAP)
		_still_prev_t = t
		if absf(_still_angle) > STILL_ANGLE:
			moved_at = t
			return
	if v > base_threshold * STILL_SHARE:
		if is_nan(_move_since):
			_move_since = t
		elif t - _move_since >= STILL_SUSTAIN - 1e-6:
			moved_at = _move_since
	else:
		_move_since = NAN


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
	if _still_from < INF:
		_watch_still(t, v, vec[axis])
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
				_cand_pred = 0.0
				_predict(v, t)
				if fast:
					fired = true
					_fire()
			else:
				_watch_near(v, t)
		elif v >= threshold * SUSTAIN:
			_cand_peak = maxf(_cand_peak, v)
			_predict(v, t)
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
	last_strength = strength_of(maxf(_cand_peak, _cand_pred))
	_cand_t = NAN
	_near_n = 0
	_peak = 0.0
	_peak_until = last_t + PEAK_WATCH
	rang.emit(last_t, last_up)


## Strength (0-1) of a flick peaking at peak, relative to the player's typical flick.
func strength_of(peak: float) -> float:
	return clampf(0.5 * peak / maxf(typical_peak, 1e-6), 0.0, 1.0)


# Predicts the flick's peak from the rise between the previous fresh reading and this one.
func _predict(v: float, t: float) -> void:
	var dt := t - _prev_t
	if dt <= 0.0 or dt > MAX_GAP or v <= _prev_v:
		return
	# Held readings are stamped with frame times, which jitter against the sensor's own clock: the
	# measured sensor interval is the better gap between two fresh readings.
	if _held_seen > 0.0 and dt < 2.0 * sample_interval:
		dt = sample_interval
	var w := PI / (2.0 * rise_time)
	var slope := (v - _prev_v) / dt
	var mid := (v + _prev_v) * 0.5
	_cand_pred = maxf(_cand_pred, sqrt(pow(slope / w, 2.0) + mid * mid))


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
