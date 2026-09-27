class_name WebMotion
extends RefCounted
## Motion sensors in a Web export. Godot's web platform does not feed Input.get_accelerometer() /
## get_gyroscope(), so this listens to the browser's `devicemotion` event through JavaScriptBridge.
## MotionReader uses it by itself when OS.has_feature("web"); nothing here runs natively or headless.
##
## JS side (installed once into window.__mamuMotion):
## - a `devicemotion` listener pushes every event into a ring buffer (at most BUFFER samples), so
##   no sample is lost between frames; drain() hands the whole buffer over once per frame as JSON,
##   with performance.now() so each sample's age is known.
## - iOS Safari needs DeviceMotionEvent.requestPermission() from a user gesture. request() tries at
##   once and, if the browser wants a gesture, arms a one-time touchend/click listener that asks
##   from inside the next real tap. Other browsers need no permission: listening starts at install.
##
## Axis mapping. The browser's device frame (W3C DeviceOrientation) is the phone's own frame,
## independent of screen rotation: x to the right of the screen, y up along the screen, z out of the
## screen towards the user. Godot's native sensors on a portrait phone use the same frame, so:
##   accelerometer (m/s², gravity included):  Godot (x, y, z) = accelerationIncludingGravity (x, y, z)
##   gravity (m/s²):  accelerationIncludingGravity - acceleration, when the browser gives both
##                    (else zero, and MotionReader estimates gravity with its low-pass filter)
##   gyroscope (rad/s):  Godot (x, y, z) = rotationRate (beta, gamma, alpha) in deg/s × PI / 180
##                    (beta turns about x, gamma about y, alpha about z)
## Some iOS versions report accelerationIncludingGravity with the opposite sign. That changes
## nothing the game relies on: gravity is subtracted either way, and calibration learns which sign
## means "up".

const BUFFER := 256

## One drained sample (after convert_sample()): {age: seconds before the drain, accel, gravity,
## gyro_rad, has_gyro}. has_gyro: the browser sent a rotationRate (a phone lying still reads 0).

const _JS_TEMPLATE := """
(function () {
	if (window.__mamuMotion) return;
	var M = {buf: [], events: 0, state: 'unknown', listening: false, armed: false};
	M.onMotion = function (e) {
		var a = e.accelerationIncludingGravity || {};
		var l = e.acceleration || null;
		var r = e.rotationRate || null;
		M.events++;
		M.buf.push([e.timeStamp || performance.now(),
			+a.x || 0, +a.y || 0, +a.z || 0,
			r ? (+r.beta || 0) : 0, r ? (+r.gamma || 0) : 0, r ? (+r.alpha || 0) : 0,
			l ? (+l.x || 0) : 0, l ? (+l.y || 0) : 0, l ? (+l.z || 0) : 0,
			(l && l.x !== null && l.x !== undefined) ? 1 : 0, (r && r.beta !== null && r.beta !== undefined) ? 1 : 0]);
		if (M.buf.length > MAX) M.buf.splice(0, M.buf.length - MAX);
	};
	M.listen = function () {
		if (M.listening) return;
		window.addEventListener('devicemotion', M.onMotion, true);
		M.listening = true;
		if (M.state === 'unknown' || M.state === 'prompt') M.state = 'granted';
	};
	M.ask = function () {
		try {
			DeviceMotionEvent.requestPermission().then(function (s) {
				M.state = (s === 'granted') ? 'granted' : 'denied';
				if (M.state === 'granted') M.listen();
			}).catch(function () { M.state = 'prompt'; M.armed = true; });
		} catch (err) { M.state = 'prompt'; M.armed = true; }
	};
	M.onGesture = function () {
		if (!M.armed) return;
		M.armed = false;
		M.ask();
	};
	M.request = function () {
		if (typeof DeviceMotionEvent === 'undefined') { M.state = 'unsupported'; return; }
		if (typeof DeviceMotionEvent.requestPermission !== 'function') { M.listen(); return; }
		if (M.state === 'granted' || M.state === 'denied') return;
		M.state = 'prompt';
		M.armed = true;
		M.ask();
	};
	M.drain = function () {
		var out = JSON.stringify({now: performance.now(), state: M.state, events: M.events, s: M.buf});
		M.buf = [];
		return out;
	};
	document.addEventListener('touchend', M.onGesture, true);
	document.addEventListener('click', M.onGesture, true);
	if (typeof DeviceMotionEvent === 'undefined') M.state = 'unsupported';
	else if (typeof DeviceMotionEvent.requestPermission !== 'function') M.listen();
	else M.state = 'prompt';
	window.__mamuMotion = M;
})();
"""

## Browser permission: "unknown", "prompt" (iOS: needs request() from a tap), "granted", "denied"
## or "unsupported" (no DeviceMotionEvent at all).
var state := "unknown"
## devicemotion events received so far.
var events := 0
var _installed := false


## True in a Web export where JavaScriptBridge works.
static func supported() -> bool:
	return OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge")


func install() -> void:
	if _installed or not supported():
		return
	_eval(_JS_TEMPLATE.replace("MAX", str(BUFFER)))
	_installed = true


## Asks for motion access (iOS). Call it from a tap handler; if the browser still wants a gesture,
## the next tap anywhere on the page asks.
func request_permission() -> void:
	install()
	_eval("window.__mamuMotion && window.__mamuMotion.request();")


## Every sample since the last drain, oldest first, converted to Godot's units and axes.
func drain() -> Array:
	if not _installed:
		return []
	var raw = _eval("window.__mamuMotion ? window.__mamuMotion.drain() : ''")
	if not (raw is String) or raw == "":
		return []
	var d = JSON.parse_string(raw)
	if not (d is Dictionary):
		return []
	state = str(d.get("state", state))
	events = int(d.get("events", events))
	return convert_all(d.get("s", []), float(d.get("now", 0.0)))


## Converts raw browser samples [timeStamp ms, ax, ay, az, beta, gamma, alpha, lx, ly, lz, has_lin,
## has_rot] to [{age, accel, gravity, gyro_rad}], given performance.now() at the drain. Used by
## drain() and by the tests (same path).
static func convert_all(raw: Array, now_ms: float) -> Array:
	var out := []
	for r in raw:
		if r is Array and r.size() >= 12:
			out.append(convert_sample(r, now_ms))
	return out


static func convert_sample(r: Array, now_ms: float) -> Dictionary:
	var accel := Vector3(float(r[1]), float(r[2]), float(r[3]))
	var gravity := Vector3.ZERO
	if int(r[10]) == 1:
		gravity = accel - Vector3(float(r[7]), float(r[8]), float(r[9]))
	var gyro := Vector3(float(r[4]), float(r[5]), float(r[6])) * (PI / 180.0) if int(r[11]) == 1 else Vector3.ZERO
	return {"age": maxf(0.0, (now_ms - float(r[0])) / 1000.0), "accel": accel, "gravity": gravity, "gyro_rad": gyro,
			"has_gyro": int(r[11]) == 1}


func _eval(code: String) -> Variant:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	return bridge.call("eval", code, true) if bridge != null else null
