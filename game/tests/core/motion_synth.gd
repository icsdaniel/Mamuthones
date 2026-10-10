extends RefCounted
## Synthetic phone motion for the calibration and detection tests, sampled like Godot reads
## sensors: once per frame (60 fps with a little jitter), each reading the value at that instant.
##
## A tilt ("flick") rotates the phone about its x axis: a first lobe in the tilt's direction, then a
## return lobe the other way (so one flick has two lobes). The top edge moving toward or away from
## the player also gives linear acceleration, mostly on z and y.
## A thumb tap is a short sharp spike, mostly on the screen's z axis, lasting a few ms, with little
## rotation.

var rng := RandomNumberGenerator.new()
var events: Array = []   # {kind, t0, sign, rot, acc, dur, acc_axis_sign}
var acc_noise := 0.0
var gyro_noise := 0.0
var fps := 60.0
var jitter := 0.002
## Walking: vertical bounce (m/s², on y) and sway (°/s, about y and z) at step rate.
var walk_acc := 0.0
var walk_gyro := 0.0


func _init(p_seed := 1) -> void:
	rng.seed = p_seed


## A flick starting at t0. up = true tilts the top edge toward the player.
func flick(t0: float, up: bool, rot_peak := 400.0, acc_peak := 12.0, dur := 0.2, acc_consistent := true) -> void:
	var acc_sign := 1.0 if acc_consistent or rng.randf() < 0.5 else -1.0
	events.append({"kind": "flick", "t0": t0, "sign": 1.0 if up else -1.0, "rot": rot_peak, "acc": acc_peak, "dur": dur, "acc_sign": acc_sign})


## A slow lean of the top edge (up = toward the player) about the tilt axis, peaking at `rate` °/s,
## lasting dur seconds: no flick, just the phone tipped (turns rate × dur × 2/π degrees).
func lean(t0: float, up: bool, rate := 40.0, dur := 1.0, acc := 1.0) -> void:
	events.append({"kind": "lean", "t0": t0, "sign": 1.0 if up else -1.0, "rot": rate, "dur": dur, "acc": acc})


## A body turn (yaw, about the screen's z axis) peaking at `rate` °/s, lasting dur seconds.
func turn(t0: float, rate := 250.0, dur := 0.5) -> void:
	events.append({"kind": "turn", "t0": t0, "rot": rate, "dur": dur})


## A hard thumb tap at t0: `acc` m/s² spike on z lasting `dur` seconds, with `rot` °/s of rotation.
## rot_axis 1 (y) is the usual; 0 (x, the tilt axis) is a knock that jolts the tilt axis too.
func tap(t0: float, acc := 25.0, dur := 0.005, rot := 25.0, rot_axis := 1) -> void:
	events.append({"kind": "tap", "t0": t0, "acc": acc, "dur": dur, "rot": rot, "rot_axis": rot_axis})


## Frame times from t0 to t1.
func frames(t0: float, t1: float) -> Array[float]:
	var out: Array[float] = []
	var t := t0
	while t < t1:
		out.append(t)
		t += 1.0 / fps + rng.randf_range(-jitter, jitter)
	return out


## Frame times guaranteed to include each tap's spike (worst case for tap rejection).
func frames_hitting_taps(t0: float, t1: float) -> Array[float]:
	var out := frames(t0, t1)
	for e in events:
		if e.kind == "tap":
			out.append(e.t0 + e.dur * 0.5)
	out.sort()
	return out


## [acc: Vector3 m/s², gyro: Vector3 °/s] at time t.
func sample(t: float) -> Array:
	var acc := Vector3.ZERO
	var gyro := Vector3.ZERO
	for e in events:
		var dt: float = t - e.t0
		if e.kind == "flick":
			if dt < 0.0 or dt > e.dur:
				continue
			var d1: float = e.dur * 0.45
			var lobe := 0.0
			if dt < d1:
				lobe = sin(PI * dt / d1)
			else:
				lobe = -0.75 * sin(PI * (dt - d1) / (e.dur - d1))
			gyro.x += e.sign * e.rot * lobe
			acc.z += e.sign * e.acc_sign * e.acc * lobe
			acc.y += e.sign * e.acc_sign * e.acc * 0.4 * lobe
		elif e.kind == "tap":
			if dt < 0.0 or dt > e.dur:
				continue
			acc.z += e.acc
			acc.x += e.acc * 0.15
			gyro[int(e.get("rot_axis", 1))] += e.rot
		elif e.kind == "lean":
			if dt < 0.0 or dt > e.dur:
				continue
			gyro.x += e.sign * e.rot * sin(PI * dt / e.dur)
			acc.z += e.sign * e.acc * cos(PI * dt / e.dur)
		elif e.kind == "turn":
			if dt < 0.0 or dt > e.dur:
				continue
			gyro.z += e.rot * sin(PI * dt / e.dur)
			acc.x += 3.0 * sin(PI * dt / e.dur)
	if walk_acc > 0.0 or walk_gyro > 0.0:
		acc.y += walk_acc * sin(TAU * 1.8 * t)
		gyro.y += walk_gyro * sin(TAU * 0.9 * t)
		gyro.z += walk_gyro * 0.7 * sin(TAU * 0.9 * t + 1.0)
	if acc_noise > 0.0:
		acc += Vector3(rng.randfn(0, acc_noise), rng.randfn(0, acc_noise), rng.randfn(0, acc_noise))
	if gyro_noise > 0.0:
		gyro += Vector3(rng.randfn(0, gyro_noise), rng.randfn(0, gyro_noise), rng.randfn(0, gyro_noise))
	return [acc, gyro]


## Frames at `fps`, each showing the latest reading of a sensor sampled at `hz` (sample-and-hold,
## the way phones deliver sensors to a game). Worst case for taps: a tap's spike is always caught by
## a sensor sample. Returns [[frame_t, acc, gyro], ...]; the noise is drawn per sensor sample.
func held_frames(t0: float, t1: float, hz: float, p_fps: float) -> Array:
	var out := []
	var period := 1.0 / hz
	var phase := rng.randf() * period
	var last_k := -INF
	var reading := [Vector3.ZERO, Vector3.ZERO]
	var t := t0
	while t < t1:
		var k := floorf((t - phase) / period)
		var ts := phase + k * period
		var caught := false
		for e in events:
			if e.kind == "tap" and e.t0 > ts - period and e.t0 <= t and e.t0 > last_k:
				# the sensor sample that fell inside this spike
				reading = sample(e.t0 + e.dur * 0.5)
				last_k = e.t0
				caught = true
		if not caught and ts > last_k:
			reading = sample(ts)
			last_k = ts
		out.append([t, reading[0], reading[1]])
		t += 1.0 / p_fps + rng.randf_range(-jitter, jitter)
	return out
