class_name Autoplay
extends RefCounted
## Plays a Session by itself, for demos, trailers, recordings and tests. Emits the same signals as
## InputRouter so sound and visuals react the same way.
##
## update(t) sends every input that is due by song time t (with its exact time stamp), then calls
## session.update(t), so the play screen can call autoplay.update(t) in place of session.update(t).
## human = true adds small timing errors (about ±20 ms), an occasional early hold release and a
## rare miss (1 %, or `p_miss_rate` when given: tests use 0.25 for a player who should run out of
## health); `p_seed` makes that repeatable. In slam mode it rings with the buttons (two thumbs).

signal stepped(lane: int)
signal rang(result: Dictionary)
signal swiped(dir: int)

const TOUCH_BASE := 1000

var session: Session
var human := false
var rng := RandomNumberGenerator.new()
var _next := 0
var _plan: Array[float] = []           # per note: planned input time (NAN = skip)
var _releases: Array = []              # [t, touch_id]
var _holding: Dictionary = {}          # touch_id -> lane of holds being kept


func _init(p_session: Session, p_human := false, p_seed := 12345, p_miss_rate := -1.0) -> void:
	session = p_session
	human = p_human
	rng.seed = p_seed
	var miss_rate := p_miss_rate if p_miss_rate >= 0.0 else 0.01
	for n in session.notes:
		var t := n.t
		if human:
			if rng.randf() < miss_rate:
				t = NAN
			else:
				t += clampf(rng.randfn(0.0, 0.018), -0.06, 0.06)
		_plan.append(t)


func update(t: float) -> void:
	var notes := session.notes
	while _next < notes.size():
		var n := notes[_next]
		var at := _plan[_next]
		if is_nan(at):
			if n.t > t:
				break
			_next += 1
			continue
		if at > t:
			break
		_play(n, at)
		_next += 1
	var i := 0
	while i < _releases.size():
		if _releases[i][0] <= t:
			session.release(_releases[i][0], _releases[i][1])
			_holding.erase(_releases[i][1])
			_releases.remove_at(i)
		else:
			i += 1
	session.update(t)


func _play(n: Note, at: float) -> void:
	var id := TOUCH_BASE + n.index
	match n.kind:
		Note.Kind.STEP:
			_tap(n.lane, at, id, 0.03)
		Note.Kind.HOLD:
			_tap(n.lane, at, id, -1.0)
			var end := n.end_t
			if human and rng.randf() < 0.05:
				end -= 0.3
			_releases.append([end, id])
			_holding[id] = n.lane
		Note.Kind.BELL:
			if session.slam:
				_slam_bell(at, id)
			else:
				rang.emit(session.ring(at))
		Note.Kind.RING:
			_tap(n.lane, at, id, 0.03)
			if not session.slam:   # in slam a full ring is its step alone
				rang.emit(session.ring(at))
		Note.Kind.SWIPE:
			session.swipe(n.dir, at)
			swiped.emit(n.dir)


# Slam bell with two thumbs: both outer buttons together, or, while one thumb keeps a hold, the
# outer button that thumb is not on.
func _slam_bell(at: float, id: int) -> void:
	if _holding.is_empty():
		_tap(0, at, id + 100000, 0.03)
		_tap(2, at, id + 200000, 0.03)
		return
	var held: int = _holding.values()[0]
	_tap(2 if held == 0 else 0, at, id + 100000, 0.03)


# Presses a button (and lets go after `hold_for` seconds unless negative), passing on any bell
# a slam press made.
func _tap(lane: int, at: float, id: int, hold_for: float) -> void:
	var r := session.tap(lane, at, id)
	stepped.emit(lane)
	if not r.ring.is_empty():
		rang.emit(r.ring)
	if hold_for >= 0.0:
		_releases.append([at + hold_for, id])
