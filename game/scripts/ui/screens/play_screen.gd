extends Screen
## Playing a song. Top to bottom: HUD, the procession scene, the three lanes and the three step buttons
## (design section 8). Conductor keeps song time from the audio clock; InputRouter (or Autoplay) feeds
## the Session; every hit is answered in the same frame with its sound, a button flash, a burst, a
## judgement word, a jolt of the row and a short vibration.
##
## args: song_id, difficulty, bell_set, remix, mirror, daily, piazza, round (Piazza turn state),
##       autoplay (bool), human (autoplay with small errors), from_beat/to_beat (a lesson),
##       embedded (emit `finished` instead of opening the results), lead_in (seconds before the first
##       note when starting mid-song, with no count), quick (restart / retry: start a bar before the
##       first note's bar, after a count-in, instead of the whole intro).
##
## Count-ins: a song started from its beginning has its count-in sticks in the music (beats -4..-1),
## and the big 4-3-2-1 over the procession lands on them. A resume, a quick restart and a lesson
## count in with Sound.count_in() while the music waits on a bar line; the digits follow those sticks
## and the lanes keep moving so the approach replays, then the music starts on the next beat.

signal finished(session: Session)

const SCENE_SHARE := 0.27         ## share of the screen height given to the procession scene
const FIELD_MAX_W := 900.0        ## lanes and buttons stay thumb-sized on a tablet
const JUDGE_WORDS := {
	"perfect": "judge_perfect", "good": "judge_good", "early": "judge_early", "late": "judge_late",
	"miss": "judge_miss", "wrong": "judge_wrong", "held": "judge_held", "let_go": "judge_let_go",
	"silence": "judge_silence",
}

var song: SongData
var session: Session
var conductor: Conductor
var router: InputRouter
var autoplay: Autoplay
var ghost: Ghost
var hud: Hud
var scene: ProcessionScene
var lanes: LaneView
var words: JudgementWords
var cue: PiazzaCue
var paused := false
var done := false

var _bell_set := "light"
var _first_t := 0.0
var _spb := 0.5
var _sched := 0                  ## next note to check for calls and rope throws
var _pause_panel: Control
var count_view: CountInView
var _resume_at := -1.0           ## real time when a count-in ends and the music starts (-1: none)
var _count_from := 0.0           ## real time the first count-in stick is heard
var _count_music_t := 0.0        ## song time the music starts from after the count-in
var _played := false             ## the music has run since the last count-in
var _audio_count := false        ## the song started at its own count-in (sticks in the music)
var _tap_hit := false            ## the tap being handled judged a note (set by _on_judged)
var _clock := 0.0
var _field_box: Control
var _still := false


func build() -> void:
	song = SongLibrary.get_song(str(args.get("song_id", "")))
	if song == null:
		push_error("play: unknown song %s" % args.get("song_id", ""))
		return
	var difficulty := str(args.get("difficulty", "easy"))
	_bell_set = str(args.get("bell_set", "light"))
	var auto := bool(args.get("autoplay", false))
	var options := {
		"slam": bool(Profile.get_setting("slam")) and not auto,
		"piazza": bool(args.get("piazza", false)),
		"remix": bool(args.get("remix", false)),
		"mirror": bool(args.get("mirror", false)),
	}
	if str(args.get("daily", "")) != "":
		options.daily = str(args.daily)
	if args.has("from_beat"):
		options.from_beat = float(args.from_beat)
		options.to_beat = float(args.to_beat)
	session = Session.new(song, difficulty, _bell_set, options)
	_spb = 60.0 / song.bpm
	_first_t = session.notes[0].t if not session.notes.is_empty() else song.time_of(0.0, session.remix)
	var best: Dictionary = Profile.best(session.song_key(), difficulty)
	var gd = best.get("ghost", {})
	if gd is Dictionary and not (gd as Dictionary).is_empty() and not session.piazza:
		ghost = Ghost.from_dict(gd)

	var bg := ColorRect.new()
	bg.color = Palette.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var safe := UIKit.safe_margins(self)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = safe.y + 8.0
	col.offset_bottom = -safe.w
	col.offset_left = safe.x
	col.offset_right = -safe.z
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var hud_margin := MarginContainer.new()
	hud_margin.add_theme_constant_override("margin_left", 24)
	hud_margin.add_theme_constant_override("margin_right", 16)
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hud_margin)
	hud = Hud.new()
	hud.name = "Hud"
	hud_margin.add_child(hud)
	hud.setup(session, ghost)
	hud.pause_pressed.connect(pause)

	scene = ProcessionScene.new()
	scene.name = "Procession"
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.size_flags_stretch_ratio = SCENE_SHARE / (1.0 - SCENE_SHARE)
	col.add_child(scene)
	scene.set_stop(song.stop)
	UIKit.show_look(scene)
	scene.set_reduced_motion(UIKit.reduced_motion())
	scene.set_unison(0)

	_field_box = CenterWidth.new()
	(_field_box as CenterWidth).max_width = FIELD_MAX_W
	_field_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_field_box)
	lanes = LaneView.new()
	lanes.name = "Lanes"
	lanes.session = session
	lanes.note_speed = float(Profile.get_setting("note_speed"))
	lanes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lanes.show_buttons = not session.piazza
	lanes.visible = not session.piazza
	_field_box.add_child(lanes)
	words = JudgementWords.new()
	words.set_anchors_preset(Control.PRESET_FULL_RECT)
	lanes.add_child(words)

	if session.piazza:
		cue = PiazzaCue.new()
		cue.name = "PiazzaCue"
		cue.session = session
		var round: Dictionary = args.get("round", {})
		if not round.is_empty():
			cue.player = str((round.players as Array)[int(round.turn)])
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_field_box.add_child(cue)

	conductor = Conductor.new()
	conductor.name = "Conductor"
	add_child(conductor)
	conductor.finished.connect(_on_music_finished)

	if auto:
		autoplay = Autoplay.new(session, bool(args.get("human", false)))
		autoplay.stepped.connect(_on_stepped)
		autoplay.rang.connect(_on_rang)
		autoplay.swiped.connect(_on_swiped)
	router = InputRouter.new()
	router.name = "InputRouter"
	router.session = session
	router.conductor = conductor
	router.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(router)
	router.stepped.connect(_on_stepped)
	router.rang.connect(_on_rang)
	router.swiped.connect(_on_swiped)
	router.pause_requested.connect(pause)
	if auto:
		router.enabled = false
	else:
		lanes.router = router

	session.judged.connect(_on_judged)
	session.unison_changed.connect(_on_unison)
	session.hold_started.connect(func(lane: int) -> void: Sound.hold_start(lane))
	session.hold_ended.connect(func(lane: int, _kept: bool) -> void: Sound.hold_stop(lane))
	session.wrong_step.connect(_on_wrong_step)
	session.still_kept.connect(_on_still_kept)

	# The count-in is drawn over the procession, never over the notes.
	count_view = CountInView.new()
	count_view.name = "CountIn"
	scene.add_child(count_view)

	Sound.set_key(song.key_root)
	Sound.row_bells(0)
	Sound.ambience("crowd+fire" if session.piazza else UIKit.ambience_for(song.stop))
	resized.connect(_layout_router)
	_start.call_deferred()


func _start() -> void:
	_layout_router()
	if args.has("lead_in"):
		conductor.play(song, session.remix, _first_t - float(args.lead_in))
		_played = true
		return
	if bool(args.get("quick", false)) or args.has("from_beat"):
		# A restart, a retry or a lesson: wait on the bar line a bar before the first note's bar and
		# count in, rather than replaying the whole intro.
		var bar_t := lead_bar_time()
		if bar_t > song.time_of(-4.0, session.remix) + 0.05:
			conductor.play(song, session.remix, bar_t)
			conductor.pause()
			paused = true
			_begin_count(bar_t)
			return
	var start := 0.0
	if _first_t < 4.0 * _spb + 0.5:
		start = _first_t - (4.0 * _spb + 0.5)
	_audio_count = start <= song.time_of(-4.0, session.remix) + 0.01
	conductor.play(song, session.remix, start)
	_played = true


## Song time of the bar line one bar before the bar of the first note (bars of four beats from beat 0).
func lead_bar_time() -> float:
	var bf := song.beat_at(_first_t, session.remix)
	return song.time_of(floorf(bf / 4.0) * 4.0 - 4.0, session.remix)


## Song time to resume from: the bar line one to two bars before t, so the player hears the groove
## back before the next note (never before the song's start).
func resume_bar_time(t: float) -> float:
	var b := song.beat_at(t, session.remix)
	return maxf(song.time_of(floorf(b / 4.0) * 4.0 - 4.0, session.remix), 0.0)


## Counts in one bar with Sound's sticks while the music waits at music_t, then starts it.
func _begin_count(music_t: float) -> void:
	if absf(conductor.song_time() - music_t) > 0.001:
		conductor.seek(music_t)
	router.release_all()
	router.enabled = false
	_count_music_t = music_t
	var length := Sound.count_in(song.bpm)
	if length <= 0.0:
		length = 4.0 * _spb
	_count_from = _clock + AudioServer.get_output_latency()
	_resume_at = _clock + length
	_played = false
	_tick_count()


func _layout_router() -> void:
	if router != null and lanes != null:
		router.buttons_rect = lanes.buttons_global_rect()


func _process(delta: float) -> void:
	_clock += delta
	if done or session == null or conductor == null:
		return
	_tap_hit = false
	if _resume_at >= 0.0:
		_tick_count()
		return
	if paused:
		return
	var t := conductor.song_time()
	if autoplay != null:
		autoplay.update(t)
	else:
		session.update(t)
	lanes.song_time = t
	var beat := (t - song.offset_for(session.remix)) / _spb
	lanes.beat_pulse = 1.0 - fposmod(beat, 1.0) if beat >= 0.0 else 0.0
	hud.tick(t, delta)
	if cue != null:
		cue.song_time = t
	_schedule(t)
	_count_in(t)
	if ghost != null:
		scene.set_ghost_delta(ghost.lead_seconds(session.score, t))
	if session.is_over(t):
		_finish()


## Things that happen on the music, not on the player: the Issohadore's call with off-beat steps (a
## touch early so it is heard on time), the rope thrown a beat before a swipe, standing still.
func _schedule(t: float) -> void:
	var lead := AudioServer.get_output_latency()
	var notes := session.notes
	while _sched < notes.size():
		var n := notes[_sched]
		var at := n.t - (_spb if n.kind == Note.Kind.SWIPE else lead)
		if at > t:
			break
		if n.call:
			Sound.call_out()
		if n.kind == Note.Kind.SWIPE:
			scene.throw_rope()
		_sched += 1
	var still := false
	for i in range(maxi(_sched - 8, 0), mini(_sched + 8, notes.size())):
		var n := notes[i]
		if n.kind == Note.Kind.REST and n.t <= t and t < n.end_t:
			still = true
			break
	if still != _still:
		_still = still
		scene.set_still(still)
		if cue != null:
			cue.still = still


## Song start: "4 3 2 1" on the music's own count-in sticks (beats -4..-1), then "Get ready" with the
## bars left until the first note.
func _count_in(t: float) -> void:
	var b := song.beat_at(t, session.remix)
	if _audio_count and b >= -4.0 and b < 0.0:
		count_view.show_digit(int(-floorf(b)), fposmod(b, 1.0))
	elif t < _first_t - 0.05 and b >= -4.0:
		var bf := song.beat_at(_first_t, session.remix)
		count_view.show_ready(maxi(ceili((bf - b) / 4.0), 1), fposmod(b, 1.0))
	else:
		count_view.clear()


# ---------------------------------------------------------------- feedback (same frame as the input)


func _on_stepped(lane: int) -> void:
	# A finger landing while a rope is due is the start of a swipe: grab the rope at once, and hold
	# the step sound back unless the touch itself hit a note in its lane.
	if not _tap_hit and _swipe_open(conductor.song_time()):
		lanes.rope_grab(lane)
	else:
		Sound.step(lane)
		lanes.press(lane)
	_tap_hit = false


func _swipe_open(t: float) -> bool:
	var reach := session.window("swipe").z
	for n in session.notes:
		if n.t > t + reach:
			return false
		if n.kind == Note.Kind.SWIPE and not n.done and absf(n.t - t) <= reach:
			return true
	return false


func _on_rang(result: Dictionary) -> void:
	# Quality is perfect, good, early, late, miss, silence or free: an early or late clank is pitched
	# up or down by Sound, so the ear learns which way it was off.
	var q := str(result.get("quality", "free"))
	if q == "ok" and str(result.get("side", "")) != "":
		q = str(result.side)
	var strength := float(result.get("strength", 0.5))
	# Strength is how hard the flick was; harder flicks ring heavier.
	Sound.bell(_bell_set, bool(result.get("up", true)), q, strength)
	scene.jolt("bell")
	if q == "free" or q == "silence":
		UIKit.vibrate(12)


func _on_swiped(_dir: int) -> void:
	Sound.rope()


func _on_judged(note: Note, judgement: String, offset: float) -> void:
	if judgement == "wrong":
		# Shown on the button actually pressed (_on_wrong_step); the row stumbles.
		scene.jolt("miss")
		return
	var good := judgement in ["perfect", "good", "held"]
	var soft := judgement in ["early", "late"]
	var quality := judgement
	if not quality in ["perfect", "good", "early", "late", "miss", "held"]:
		quality = "miss"
	var lane := note.lane if note != null and note.lane >= 0 else -1
	if lane >= 0 and (good or soft) and note.kind != Note.Kind.RING:
		_tap_hit = true
	var pos: Vector2
	if lane >= 0:
		pos = lanes.lane_center(lane)
		lanes.flash(lane, good or soft)
	else:
		pos = Vector2(lanes.size.x * 0.5, lanes.lane_center(1).y)
	var side := ""
	if judgement in ["perfect", "good"]:
		side = UIKit.side_of(offset)
	lanes.burst(pos, quality, side)
	var word_key: String = JUDGE_WORDS.get(judgement, "")
	if word_key != "":
		words.show_word(tr(word_key), side, lanes.word_spot(lane), quality)
		if cue != null:
			cue.hit(quality, tr(word_key))
	if judgement in ["perfect", "good", "early", "late"]:
		lanes.add_offset(offset, lane if lane >= 0 else 1)
	if good or soft:
		if note != null and note.kind == Note.Kind.RING:
			scene.jolt("ring")
		elif note != null and not note.is_bell():
			scene.jolt("step")
		UIKit.vibrate(30 if note != null and note.is_bell() else 14)
	elif judgement in ["miss", "silence"]:
		scene.jolt("miss")


## A step on the wrong lane: the red mark goes on the button actually pressed, with a faint ring on
## the note it was meant for.
func _on_wrong_step(lane: int, note: Note, _offset: float) -> void:
	lanes.mark_wrong(lane, note.lane if note != null else -1)
	words.show_word(tr("judge_wrong"), "", lanes.word_spot(lane), "wrong")


## A stand-still kept to its end: the row settles, and it is named.
func _on_still_kept(_note: Note, points: float) -> void:
	var at := lanes.word_spot(1)
	words.show_word(tr("judge_still_kept") + "  +" + UIKit.fmt_score(int(points)), "", at, "held", 0.8)
	lanes.burst(lanes.lane_center(1), "held")
	scene.set_unison(session.unison_level)
	UIKit.vibrate(20)
	if cue != null:
		cue.hit("held", tr("judge_still_kept"))


func _on_unison(level: int) -> void:
	Sound.row_bells(level)
	hud.set_unison(level)
	scene.set_unison(level)


# ---------------------------------------------------------------- pause


func pause() -> void:
	if done or session == null or _pause_panel != null:
		return
	if _resume_at >= 0.0:
		# Focus lost (or pause pressed) during a count-in: stop the count and ask again. The music
		# is still waiting on its bar line, so nothing is lost.
		_resume_at = -1.0
		count_view.clear()
		_open_pause_menu()
		return
	if paused:
		return
	paused = true
	conductor.pause()
	router.release_all()
	router.enabled = false
	_open_pause_menu()


func _open_pause_menu() -> void:
	paused = true
	Sound.ui("tap")
	_pause_panel = PauseMenu.new()
	_pause_panel.name = "PauseMenu"
	add_child(_pause_panel)
	(_pause_panel as PauseMenu).chosen.connect(_on_pause_choice)


func _on_pause_choice(what: String) -> void:
	match what:
		"resume":
			_pause_panel.queue_free()
			_pause_panel = null
			# Back to a bar line one to two bars before the pause, count one bar in on the beat grid,
			# and let the approach replay. Notes already judged stay judged.
			var t := conductor.song_time()
			_begin_count(resume_bar_time(t) if _played else t)
		"restart":
			_end_sound()
			var again := args.duplicate()
			again["quick"] = true
			app.replace("play", again)
		"quit":
			_end_sound()
			Sound.stop_ambience()
			if bool(args.get("embedded", false)):
				finished.emit(null)
			else:
				app.back()


## During a count-in: the digits follow the sticks as they are heard, the lanes run toward the bar
## line so the notes approach as they will, and the music starts when the bar is counted.
func _tick_count() -> void:
	var left := _resume_at - _clock
	if left > 0.0:
		var tv := _count_music_t - left
		lanes.song_time = tv
		if cue != null:
			cue.song_time = tv
		var k := maxf((_clock - _count_from) / _spb, 0.0)
		count_view.show_digit(clampi(4 - floori(k), 1, 4), fposmod(k, 1.0))
		lanes.beat_pulse = 1.0 - fposmod(k, 1.0)
		return
	_resume_at = -1.0
	count_view.clear()
	paused = false
	_played = true
	conductor.resume()
	if autoplay == null:
		router.enabled = true


func on_back() -> void:
	if paused and _pause_panel != null:
		_on_pause_choice("resume")
	else:
		pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if autoplay == null and not done and session != null:
			pause()


# ---------------------------------------------------------------- end


func _on_music_finished() -> void:
	# The chart can end after the audio (a lesson's last rest); session.is_over decides.
	pass


func _finish() -> void:
	if done:
		return
	done = true
	router.enabled = false
	if bool(args.get("embedded", false)):
		finished.emit(session)
		return
	if session.piazza and args.has("round"):
		var round: Dictionary = (args.round as Dictionary).duplicate(true)
		round.scores[int(round.turn)] = session.score
		round.turn = int(round.turn) + 1
		app.replace("piazza", {"round": round})
		return
	var record := {}
	if autoplay == null:
		record = Profile.record_result(session)
	app.replace("results", {"session": session, "record": record, "play_args": args, "ghost": ghost})


func _exit_tree() -> void:
	if conductor != null:
		conductor.pause()
	_end_sound()


## A hold still sounding when the screen goes (quit or restart mid-hold) must not drone on, and
## Sound.end_song() also stops the silent hold drones kept ready for the song.
func _end_sound() -> void:
	for lane in 3:
		Sound.hold_stop(lane)
	Sound.end_song()
