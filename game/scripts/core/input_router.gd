class_name InputRouter
extends Control
## Turns touches on the step buttons, keys and phone motion into Session calls,
## and tells sound and visuals what happened. Lay it over the play screen (full rect); it never
## blocks other controls (mouse_filter IGNORE, reads events in _input) and only consumes touches
## that start inside buttons_rect.
##
## Setup: router.session = session; router.conductor = conductor (or time_source = a Callable
## returning song time); router.buttons_rect = the three buttons' global rect.
## Motion: reads the sensors every frame and rings through a BellDetector built from Profile's
## calibration (or set `detector`); in slam mode the tilt is ignored and Left + Right ring instead.
## Keys: A S D steps, J K L the same buttons with the other thumb (S + K = a middle stomp), Space
## bell, Esc pause.
##
## Additions beyond the architecture doc: conductor, time_source, enabled, read_motion, motion,
## detector, motion_log, feed_motion(), release_all(), is_pressed(lane), lane_at(x), last_tap, signals
## lifted(lane) and pause_requested.

signal stepped(lane: int)
signal lifted(lane: int)
signal rang(result: Dictionary)
## The phone moved in a stand-still and broke it (note: the stand-still).
signal moved_still(note: Note)
signal pause_requested

## Seconds into a stand-still before moving counts: the tail of a bell rung just before it settles.
const STILL_GRACE := 0.15
const KEY_LANES := {KEY_A: 0, KEY_S: 1, KEY_D: 2, KEY_J: 3, KEY_K: 4, KEY_L: 5}   ## 3-5: second thumb

var session: Session:
	set(value):
		session = value
		if session != null and detector != null:
			detector.set_bpm(session.song.bpm)
var conductor: Conductor
var time_source: Callable
var buttons_rect := Rect2()
var enabled := true
var read_motion := true
var motion := MotionReader.new()
var _last_motion_t := -INF
var detector: BellDetector
## Set to a MotionLog to record readings, touches and rings (for checking detection on real phones).
var motion_log: MotionLog

## Session.tap's result for the latest press, read by stepped's handlers ({} before any).
var last_tap: Dictionary = {}

var _touches: Dictionary = {}   # touch index -> {lane}
var _pressed := [0, 0, 0]
var _keys_down: Dictionary = {}  # key slot (0-5) -> true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	if detector == null:
		var cal := _calibration()
		detector = BellDetector.from_calibration(cal, cal.get("has_gyro", true))
	if session != null:
		detector.set_bpm(session.song.bpm)


func _calibration() -> Dictionary:
	var p := get_node_or_null("/root/Profile")
	if p != null and p.has_method("calibration"):
		return p.calibration()
	return {}


func now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	if conductor != null:
		return conductor.song_time()
	return 0.0


func is_pressed(lane: int) -> bool:
	return lane >= 0 and lane < 3 and _pressed[lane] > 0


## Lane under x (in buttons_rect's coordinates), -1 outside the row.
func lane_at(x: float) -> int:
	if buttons_rect.size.x <= 0.0 or x < buttons_rect.position.x or x >= buttons_rect.end.x:
		return -1
	return clampi(int((x - buttons_rect.position.x) / buttons_rect.size.x * 3.0), 0, 2)


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if not buttons_rect.has_point(e.position):
				return
			var lane := lane_at(e.position.x)
			var t := now()
			if _touches.has(e.index):
				# The release of this finger never arrived: lift it first.
				_lift(_touches[e.index].lane, t, e.index)
			_touches[e.index] = {"lane": lane}
			_press(lane, t, e.index)
			get_viewport().set_input_as_handled()
		elif _touches.has(e.index):
			_lift(_touches[e.index].lane, now(), e.index)
			_touches.erase(e.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _touches.has((event as InputEventScreenDrag).index):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo:
			return
		var code := k.physical_keycode
		var t := now()
		if KEY_LANES.has(code):
			var slot: int = KEY_LANES[code]
			if k.pressed:
				_keys_down[slot] = true
				_press(slot % 3, t, -1 - slot)
			elif _keys_down.has(slot):
				_keys_down.erase(slot)
				_lift(slot % 3, t, -1 - slot)
		elif not k.pressed:
			return
		elif code == KEY_SPACE:
			if session != null:
				rang.emit(session.ring(t, false))
		elif code == KEY_ESCAPE:
			pause_requested.emit()
		else:
			return
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Leaving the app (a call, the home button) loses the touches' release events: let go of all.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


## Lifts every finger and key the router thinks is down.
func release_all() -> void:
	var t := now()
	for id in _touches.keys():
		_lift(_touches[id].lane, t, id)
	_touches.clear()
	for slot in _keys_down:
		_lift(slot % 3, t, -1 - slot)
	_keys_down.clear()
	_pressed = [0, 0, 0]


func _process(delta: float) -> void:
	if not enabled or not read_motion or session == null or session.slam or detector == null:
		return
	motion.read(delta)
	# A phone without a gyroscope (and no calibration saying so yet): switch to the accelerometer.
	if detector.mode == "gyro" and motion.status() == "no_gyro":
		detector.configure(_calibration(), false)
		if session != null:
			detector.set_bpm(session.song.bpm)
	feed_samples(now(), motion.samples)


## Feeds one frame of MotionReader.samples, each reading at its own time t_now - age (the web
## delivers 0-2 per frame, natively 1).
func feed_samples(t_now: float, frame_samples: Array) -> void:
	for smp in frame_samples:
		var t := t_now - float(smp.age)
		if smp.age > 0.0 and t_now >= _last_motion_t:
			t = maxf(t, _last_motion_t + 0.0005)   # keep the readings in order
		feed_motion(t, smp.linear, smp.rotation_dps)


## Feeds one motion reading by hand (tests, or a screen that reads sensors itself).
func feed_motion(t: float, acc: Vector3, gyro_dps: Vector3) -> void:
	if session == null or session.slam or detector == null:
		return
	_last_motion_t = t
	if motion_log != null:
		motion_log.add_reading(t, acc, gyro_dps)
	_watch_still(t)
	if detector.feed(t, acc, gyro_dps):
		if motion_log != null:
			motion_log.add_ring(detector.last_t)
		rang.emit(session.ring(detector.last_t, true, detector.last_strength))
	if detector.watching_still() and not is_nan(detector.moved_at):
		var broke := session.moved(detector.moved_at)
		detector.end_still()
		if broke != null:
			moved_still.emit(broke)


# In a stand-still the detector watches for any tilt (from STILL_GRACE in, until it ends or breaks).
func _watch_still(t: float) -> void:
	var rest := session.rest_at(t)
	if rest == null or rest.judgement == "silence":
		if detector.watching_still():
			detector.end_still()
		return
	if not detector.watching_still() and t >= rest.t + STILL_GRACE:
		detector.watch_still(t)


func _press(lane: int, t: float, id: int) -> void:
	if detector != null:
		detector.note_touch(t)
	if motion_log != null:
		motion_log.add_touch(t)
	_pressed[lane] += 1
	var r: Dictionary = session.tap(lane, t, id) if session != null else {}
	last_tap = r
	stepped.emit(lane)
	if not r.get("ring", {}).is_empty():
		rang.emit(r.ring)


func _lift(lane: int, t: float, id: int) -> void:
	_pressed[lane] = maxi(0, _pressed[lane] - 1)
	if session != null:
		session.release(t, id)
	lifted.emit(lane)
