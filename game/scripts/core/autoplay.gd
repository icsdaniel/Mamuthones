class_name Autoplay
extends RefCounted
## Plays a Session by itself, for demos, trailers, recordings and tests. Emits the same signals as
## InputRouter so sound and visuals react the same way.
##
## update(t) sends every input that is due by song time t (with its exact time stamp), then calls
## session.update(t), so the play screen can call autoplay.update(t) in place of session.update(t).
## human = true adds small timing errors (about ±20 ms), an occasional early hold release and a
## rare miss; `seed` makes that repeatable.

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


func _init(p_session: Session, p_human := false, p_seed := 12345) -> void:
	session = p_session
	human = p_human
	rng.seed = p_seed
	for n in session.notes:
		var t := n.t
		if human:
			if rng.randf() < 0.01:
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
			_releases.remove_at(i)
		else:
			i += 1
	session.update(t)


func _play(n: Note, at: float) -> void:
	var id := TOUCH_BASE + n.index
	match n.kind:
		Note.Kind.STEP:
			session.tap(n.lane, at, id)
			stepped.emit(n.lane)
			_releases.append([at + 0.06, id])
		Note.Kind.HOLD:
			session.tap(n.lane, at, id)
			stepped.emit(n.lane)
			var end := n.end_t
			if human and rng.randf() < 0.05:
				end -= 0.3
			_releases.append([end, id])
		Note.Kind.BELL:
			rang.emit(session.ring(at))
		Note.Kind.RING:
			session.tap(n.lane, at, id)
			stepped.emit(n.lane)
			rang.emit(session.ring(at))
			_releases.append([at + 0.06, id])
		Note.Kind.SWIPE:
			session.swipe(n.dir, at)
			swiped.emit(n.dir)
