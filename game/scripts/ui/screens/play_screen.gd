extends Screen
## Playing a song. Top to bottom: HUD, then the three lanes of tiles and the three step buttons, with a
## file of Mamuthones jumping on the beat either side of them (design section 8). The Piazza keeps the
## procession scene over its cue instead. Conductor keeps song time from the audio clock; InputRouter (or Autoplay) feeds
## the Session; every hit is answered in the same frame with its sound, a button flash, a burst, a
## judgement word, a jolt of the row and a short vibration.
##
## args: song_id, difficulty, bell_set, remix, mirror, daily, piazza, round (Piazza turn state),
##       autoplay (bool), human (autoplay with small errors), from_beat/to_beat (a lesson),
##       embedded (emit `finished` instead of opening the results), lead_in (seconds before the first
##       note when starting mid-song, with no count), quick (restart / retry: start a bar before the
##       first note's bar, after a count-in, instead of the whole intro), health (bool: health on;
##       defaults to on except in autoplay, which tests and screenshots may turn on).
##
## Health (Session): at 0 the music fades, the notes stop and FailMenu offers Restart (the same
## song, difficulty and bell set, counted in) or Quit. A failed run records nothing.
##
## Count-ins: a song started from its beginning has its count-in sticks in the music (beats -4..-1),
## and the big 4-3-2-1 over the top of the lanes lands on them. A resume, a quick restart and a lesson
## count in with Sound.count_in() while the music waits on a bar line; the digits follow those sticks
## and the lanes keep moving so the approach replays, then the music starts on the next beat.

signal finished(session: Session)

const SCENE_SHARE := 0.27         ## Piazza: share of the screen height given to the procession scene
const GUTTER := 0.0               ## the road fills the width; the Mamuthones stand beside its far end
const BANNER_SHARE := 0.4         ## the count-in and the stand-still moment use this top share of the lanes
const FAIL_MENU_DELAY := 0.5      ## seconds from running out of health to the fail menu
const LEAD_MIN := 4.5             ## a song starts at least this many seconds (and two bars) before its first note
const INTRO_FADE := 0.4           ## seconds the music fades in when it starts inside its intro
const END_FADE := 1.2             ## seconds the music fades out after the last note before the results
const FIELD_MAX_W := 900.0        ## lanes and buttons stay thumb-sized on a tablet
const JUDGE_WORDS := {
	"perfect": "judge_perfect", "good": "judge_good", "early": "judge_ok", "late": "judge_ok",
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
var scene                         ## SideRows (songs) or ProcessionScene (Piazza): the same calls
var banner: Control               ## over the top of the lanes: count-in and stand-still moment
var lanes: LaneView
var backdrop: StreetBackdrop     ## the street picture, the fire and the swaying portraits (songs)
var words: JudgementWords
var filter: PixelFilter           ## the pixel look's lens over the whole screen (art style "pixel")
var pixel := false                ## the play screen is in the pixel look
var cue: PiazzaCue
var paused := false
var done := false

var _bell_set := "light"
var _first_t := 0.0
var _spb := 0.5
var _stomp_sounded := false       ## a stomp sounded on this touch: no plain step knock
var _sched := 0                  ## next note to check for calls
var _bell_sched := 0             ## next note to check for the bell cue
var _bell_cue := false           ## a soft tick half a beat before each bell (Easy and Medium)
var _pause_panel: Control
var count_view: CountInView
var still_moment: StillMoment
var _resume_at := -1.0           ## real time when a count-in ends and the music starts (-1: none)
var _count_from := 0.0           ## real time the first count-in stick is heard
var _count_music_t := 0.0        ## song time the music starts from after the count-in
var _played := false             ## the music has run since the last count-in
var _audio_count := false        ## the song started at its own count-in (sticks in the music)
var _bar_count := false          ## the song started inside its intro: 4-3-2-1 over the bar before the first note's
var _tap_hit := false            ## the tap being handled judged a note (set by _on_judged)
var _tap_quality := ""           ## how well it hit: perfect, good, ok (Sound.step's quality)
var _clock := 0.0
var _field_box: Control
var _still := false
var _fail_panel: Control
var failed := false               ## health ran out: the run is over and records nothing
var _fail_at := -1.0              ## _clock when the fail menu comes up (-1: not pending)
var _finish_at := -1.0            ## _clock when the end fade is over and the results come (-1: not pending)
var _dim := 0.0                   ## how far the bonfire is dimmed for low health (0..1)


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
	options.health = bool(args.get("health", not auto))
	session = Session.new(song, difficulty, _bell_set, options)
	_spb = 60.0 / song.bpm
	_first_t = session.notes[0].t if not session.notes.is_empty() else song.time_of(0.0, session.remix)
	var best: Dictionary = Profile.best(session.song_key(), difficulty)
	var gd = best.get("ghost", {})
	if gd is Dictionary and not (gd as Dictionary).is_empty() and not session.piazza:
		ghost = Ghost.from_dict(gd)

	# The Piazza keeps its plain black ground under the procession; songs play on the Fire Night.
	pixel = str(Profile.get_setting("art_style")) == "pixel" and not session.piazza
	StreetSkin.pixel = pixel
	var bg: Control
	if session.piazza:
		bg = ColorRect.new()
		(bg as ColorRect).color = Palette.BLACK
	else:
		backdrop = StreetBackdrop.new()
		PxType.smooth = not bool(args.get("embedded", false)) and not pixel
		backdrop.name = "Backdrop"
		backdrop.pixel = pixel
		backdrop.bell_set = str(args.get("bell_set", "village"))
		bg = backdrop
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
	hud.pixel = pixel
	hud_margin.add_child(hud)
	hud.setup(session, ghost)
	hud.pause_pressed.connect(pause)

	_field_box = CenterWidth.new()
	(_field_box as CenterWidth).max_width = FIELD_MAX_W
	_field_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if session.piazza:
		var procession := ProcessionScene.new()
		procession.name = "Procession"
		procession.mouse_filter = Control.MOUSE_FILTER_IGNORE
		procession.size_flags_vertical = Control.SIZE_EXPAND_FILL
		procession.size_flags_stretch_ratio = SCENE_SHARE / (1.0 - SCENE_SHARE)
		col.add_child(procession)
		procession.set_stop(song.stop)
		scene = procession
		col.add_child(_field_box)
	else:
		# The stage: the lanes over the street; the street itself (with its swaying figures) is the backdrop.
		var stage := Control.new()
		stage.name = "Stage"
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(stage)
		scene = backdrop
		var gut := MarginContainer.new()
		gut.set_anchors_preset(Control.PRESET_FULL_RECT)
		gut.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gw := int(round(get_viewport_rect().size.x * GUTTER)) if is_inside_tree() else 108
		gut.add_theme_constant_override("margin_left", gw)
		gut.add_theme_constant_override("margin_right", gw)
		stage.add_child(gut)
		gut.add_child(_field_box)
	UIKit.show_look(scene)
	scene.set_reduced_motion(UIKit.reduced_motion())
	scene.set_unison(0)

	lanes = LaneView.new()
	lanes.name = "Lanes"
	lanes.session = session
	lanes.note_speed = float(Profile.get_setting("note_speed"))
	lanes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lanes.show_buttons = not session.piazza
	lanes.visible = not session.piazza
	lanes.spb = _spb
	if not session.piazza:
		backdrop.lanes = lanes
		lanes.street = backdrop
		lanes.pixel = pixel
	_field_box.add_child(lanes)
	words = JudgementWords.new()
	words.set_anchors_preset(Control.PRESET_FULL_RECT)
	if pixel:
		words.z_index = PixelFilter.Z_OVER
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

	if pixel:
		# the pixel look is drawn at the base size and scaled up whole: a phone's screen has two to
		# four times the pixels, which the lens would only fold back into the same cells
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if pixel and not OS.has_environment("NO_LENS"):
		filter = PixelFilter.new()
		filter.name = "PixelFilter"
		add_child(filter)

	conductor = Conductor.new()
	conductor.name = "Conductor"
	add_child(conductor)
	conductor.finished.connect(_on_music_finished)

	if auto:
		autoplay = Autoplay.new(session, bool(args.get("human", false)))
		autoplay.stepped.connect(_on_stepped)
		autoplay.rang.connect(_on_rang)
	router = InputRouter.new()
	router.name = "InputRouter"
	router.session = session
	router.conductor = conductor
	router.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(router)
	router.stepped.connect(_on_stepped)
	router.rang.connect(_on_rang)
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
	session.stomp_landed.connect(_on_stomp)
	session.still_kept.connect(_on_still_kept)
	session.failed.connect(_on_failed)

	# The count-in and the stand-still moment: over the procession in the Piazza, else over the top of
	# the lanes, far from the hit line where the next notes are read.
	if session.piazza:
		banner = scene
	else:
		banner = Control.new()
		banner.name = "Banner"
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.anchor_right = 1.0
		banner.anchor_bottom = BANNER_SHARE
		lanes.add_child(banner)
	if pixel:
		banner.z_index = PixelFilter.Z_OVER
	count_view = CountInView.new()
	count_view.name = "CountIn"
	banner.add_child(count_view)
	still_moment = StillMoment.new()
	still_moment.name = "StillMoment"
	banner.add_child(still_moment)

	_bell_cue = bell_cue_on(difficulty)
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
	else:
		start = intro_start_time()
	_audio_count = start <= song.time_of(-4.0, session.remix) + 0.01
	conductor.play(song, session.remix, start)
	if start > 0.0:
		_bar_count = true
		conductor.player.volume_db = -30.0
		create_tween().tween_property(conductor.player, "volume_db", 0.0, INTRO_FADE)
	_played = true


## Whether the soft bell cue plays: the "bell_cue" setting (on unless turned off), Easy and Medium only.
static func bell_cue_on(difficulty: String) -> bool:
	var v: Variant = Profile.get_setting("bell_cue")
	return (v == null or bool(v)) and difficulty in ["easy", "medium"]


## Song time the music starts from: the latest bar line that leaves at least two bars and LEAD_MIN
## seconds before the first note, so nobody waits through a whole intro (0: the song's very start,
## with its own count-in sticks, when the intro is that short already).
func intro_start_time() -> float:
	var b := first_bar() - 8.0
	while b > -4.0 and _first_t - song.time_of(b, session.remix) < LEAD_MIN:
		b -= 4.0
	return song.time_of(b, session.remix) if b > -4.0 else 0.0


## Beat of the bar line the first note falls in (a note on a bar line is in that bar, whatever the
## rounding of its time).
func first_bar() -> float:
	return floorf(song.beat_at(_first_t, session.remix) / 4.0 + 0.001) * 4.0


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
	_tick_shake(delta)
	if _fail_at >= 0.0 and _clock >= _fail_at:
		_fail_at = -1.0
		_open_fail_menu()
	if _finish_at >= 0.0 and _clock >= _finish_at:
		_finish_at = -1.0
		_finish()
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
	_set_beat(beat)
	hud.tick(t, delta)
	_tick_health(delta)
	if cue != null:
		cue.song_time = t
	_schedule(t)
	_count_in(t)
	if ghost != null:
		scene.set_ghost_delta(ghost.lead_seconds(session.score, t))
	if session.is_over(t) and _finish_at < 0.0:
		_end_fade()


## The beat now, for everything that moves with it: the rows' jumps, the beads on the rails, the fire.
func _set_beat(beat: float) -> void:
	lanes.beat = beat
	hud.beat = beat
	if scene is SideRows:
		scene.beat = beat
	if backdrop != null:
		backdrop.beat = beat


## Things that happen on the music, not on the player: the Issohadore's call with off-beat steps (a
## touch early so it is heard on time), standing still.
func _schedule(t: float) -> void:
	var lead := AudioServer.get_output_latency()
	var notes := session.notes
	while _sched < notes.size():
		var n := notes[_sched]
		var at := n.t - lead
		if at > t:
			break
		if n.call:
			Sound.call_out()
		_sched += 1
	# The bell cue: on Easy and Medium the music's rim clicks come before many beats with no bell, so
	# a soft tick of its own comes half a beat before each bell or full ring (heard on time, like the
	# call), telling the player this one is a bell.
	while _bell_sched < notes.size():
		var n := notes[_bell_sched]
		if not n.is_bell():
			_bell_sched += 1
			continue
		if n.t - 0.5 * _spb - lead > t:
			break
		if _bell_cue and not n.done and n.t > t:
			Sound.ui("cue")
		_bell_sched += 1
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
## bars left until the first note. A song started inside its intro counts "4 3 2 1" over the music's
## bar just before the first note's bar instead.
func _count_in(t: float) -> void:
	var b := song.beat_at(t, session.remix)
	var cb := first_bar() - 4.0
	if _audio_count and b >= -4.0 and b < 0.0:
		count_view.show_digit(int(-floorf(b)), fposmod(b, 1.0))
	elif _bar_count and b >= cb and b < cb + 4.0 and t < _first_t - 0.05:
		count_view.show_digit(int(cb + 4.0 - floorf(b)), fposmod(b, 1.0))
	elif t < _first_t - 0.05 and b >= -4.0:
		var bf := song.beat_at(_first_t, session.remix)
		count_view.show_ready(maxi(ceili((bf - b) / 4.0), 1), fposmod(b, 1.0))
	else:
		count_view.clear()


# ---------------------------------------------------------------- feedback (same frame as the input)


func _on_stepped(lane: int) -> void:
	# A stomp's second thumb already sounded the stomp (_on_stomp); every other touch knocks its step.
	if not _stomp_sounded:
		play_step(lane, _tap_quality if _tap_hit else "")
	lanes.press(lane)
	_stomp_sounded = false
	_tap_hit = false
	_tap_quality = ""


## The step's knock at the hit's quality (Sound: "good" a little softer, "ok" dull and short), in the
## same frame as the judgement; a stray tap (quality "") knocks plain.
static func play_step(lane: int, quality: String) -> void:
	if quality != "":
		Sound.step(lane, quality)
	else:
		Sound.step(lane)


## Sound.step's quality for a judgement: perfect, good, ok (the Early/Late band), or "".
static func step_quality(judgement: String) -> String:
	match judgement:
		"perfect", "good":
			return judgement
		"early", "late":
			return "ok"
	return ""


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
		_tap_quality = step_quality(judgement)
	var is_step := lane >= 0 and note != null and (note.kind == Note.Kind.STEP or note.kind == Note.Kind.HOLD)
	if note != null and note.heal and (good or soft) and session.health_on:
		lanes.burst(pos_of(note), "heal")
	var pos: Vector2
	if lane >= 0:
		pos = lanes.lane_center(lane)
		lanes.flash(lane, good or soft)
	else:
		pos = Vector2(lanes.size.x * 0.5, lanes.lane_center(1).y)
	# Early/late is shown only off Perfect (like FAST/SLOW): on Good by the offset, and on the Ok band,
	# whose word is "Ok" with its side, so "early" and "late" only ever mean a side.
	var side := hit_side(judgement, offset)
	if is_step and (good or soft):
		# A step says its side with a small tick at the lane (cool above the line, warm below),
		# readable at a glance without the word; the spray is a plain Good.
		lanes.burst(pos, "good" if soft else quality)
		lanes.step_tick(lane, side)
	else:
		lanes.burst(pos, quality, side)
	var word_key: String = JUDGE_WORDS.get(judgement, "")
	if word_key != "":
		words.show_word(tr(word_key), side, lanes.word_spot(lane), quality)
		if cue != null:
			cue.hit(quality, tr(word_key))
	if side != "" and not is_step:
		# Steps say their side with the step tick; the lasting timing ticks are for the bells.
		lanes.add_offset(offset, lane if lane >= 0 else 1)
	if good or soft:
		if note != null and note.kind == Note.Kind.RING:
			scene.jolt("ring")
		elif note != null and not note.is_bell():
			scene.jolt("step")
		UIKit.vibrate(30 if note != null and note.is_bell() else 14)
	elif judgement in ["miss", "silence"]:
		scene.jolt("miss")


## A stomp judged (both thumbs, or one when the second never came): its sound and the prints on the
## button (placeholders the art and sound passes replace, see handoff/stomp.md). judged has already
## drawn the burst and word.
func _on_stomp(note: Note, judgement: String, _offset: float, both: bool) -> void:
	if both:
		Sound.stomp(note.lane, step_quality(judgement))
		_stomp_sounded = true
		if scene.has_method("stomp"):
			scene.stomp()
		else:
			scene.jolt("ring")
		UIKit.vibrate(40)
	else:
		Sound.stomp_half(note.lane)
		words.show_word(tr("judge_one_thumb"), "", lanes.word_spot(note.lane), "early")
	lanes.stomp_hit(note.lane, judgement, both)
	if both:
		shake(7.0)
	if backdrop != null:
		backdrop.kick(1.0 if both else 0.4)


var _last_unison := 0
var _shake := 0.0


## A short jolt of the whole screen, `px` at its strongest (none with reduced motion).
func shake(px: float) -> void:
	if not UIKit.reduced_motion():
		_shake = maxf(_shake, px)


func _tick_shake(delta: float) -> void:
	if _shake <= 0.05:
		if position != Vector2.ZERO:
			position = Vector2.ZERO
		_shake = 0.0
		return
	position = Vector2(sin(_clock * 71.0), cos(_clock * 53.0)) * _shake
	_shake = move_toward(_shake, 0.0, delta * 30.0)


## The side shown for a judgement: none on Perfect, the offset's side on Good, the band's own side on
## Ok ("early"/"late" judgements).
static func hit_side(judgement: String, offset: float) -> String:
	match judgement:
		"good":
			return UIKit.side_of(offset)
		"early", "late":
			return judgement
	return ""


## A step on the wrong lane: the red mark goes on the button actually pressed, with a faint ring on
## the note it was meant for.
func _on_wrong_step(lane: int, note: Note, _offset: float) -> void:
	lanes.mark_wrong(lane, note.lane if note != null else -1)
	words.show_word(tr("judge_wrong"), "", lanes.word_spot(lane), "wrong")


## A stand-still kept to its end: the row settles as one, and the moment is named over the procession.
func _on_still_kept(_note: Note, points: float) -> void:
	var at := lanes.word_spot(1)
	words.show_word(tr("judge_still_kept"), "", at, "held", 0.8)
	still_moment.play(tr("still_moment"), "+" + UIKit.fmt_score(int(points)))
	lanes.burst(lanes.lane_center(1), "held")
	scene.set_unison(session.unison_level)
	scene.settle()
	UIKit.vibrate(20)
	if cue != null:
		cue.hit("held", tr("judge_still_kept"))


func _on_unison(level: int) -> void:
	if level > _last_unison and backdrop != null:
		backdrop.surge()
		shake(4.0)
	_last_unison = level
	Sound.row_bells(level)
	hud.set_unison(level)
	scene.set_unison(level)


# ---------------------------------------------------------------- health


## The bonfire burns lower while health is low.
func _tick_health(delta: float) -> void:
	if backdrop == null or not session.health_on:
		return
	var want := 1.0 if session.health <= HealthPips.LOW else 0.0
	_dim = move_toward(_dim, want, delta * 1.5)
	backdrop.dim = _dim
	lanes.fire_dim = _dim


## Where a lane note's burst goes (its lane at the hit line).
func pos_of(note: Note) -> Vector2:
	return lanes.lane_center(note.lane) if note.lane >= 0 else Vector2(lanes.size.x * 0.5, lanes.lane_center(1).y)


## Health ran out: the music fades out fast, the notes stop where they are, and the fail menu comes up.
func _on_failed() -> void:
	if failed or done:
		return
	failed = true
	done = true
	if _pause_panel != null:
		_pause_panel.queue_free()
		_pause_panel = null
	router.release_all()
	router.enabled = false
	for lane in 3:
		Sound.hold_stop(lane)
	scene.set_still(true)
	if backdrop != null:
		backdrop.dim = 1.0
		lanes.fire_dim = 1.0
	var fade := create_tween()
	fade.tween_property(conductor.player, "volume_db", -40.0, 0.6)
	fade.tween_callback(conductor.player.stop)   # the clock runs on silently; nothing reads it now
	UIKit.vibrate(60)
	_fail_at = _clock + FAIL_MENU_DELAY


func _open_fail_menu() -> void:
	if _fail_panel != null or not is_inside_tree():
		return
	_fail_panel = FailMenu.new()
	if pixel:
		_fail_panel.z_index = PixelFilter.Z_OVER + 10
	_fail_panel.name = "FailMenu"
	add_child(_fail_panel)
	(_fail_panel as FailMenu).chosen.connect(_on_pause_choice)


# ---------------------------------------------------------------- pause


func pause() -> void:
	if done or failed or session == null or _pause_panel != null:
		return
	if _resume_at >= 0.0:
		# Focus lost (or pause pressed) during a count-in: stop the count and ask again. The music
		# is still waiting on its bar line, so nothing is lost.
		_resume_at = -1.0
		Sound.stop_count_in()
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
	if pixel:
		_pause_panel.z_index = PixelFilter.Z_OVER + 10
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
		_set_beat((tv - song.offset_for(session.remix)) / _spb)
		return
	_resume_at = -1.0
	count_view.clear()
	paused = false
	_played = true
	conductor.resume()
	if autoplay == null:
		router.enabled = true


func on_back() -> void:
	if failed:
		if _fail_panel != null:
			_on_pause_choice("quit")
		return
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


## The last note is behind: the music fades out over END_FADE, then the results (a lesson inside the
## tutorial hands back at once).
func _end_fade() -> void:
	if bool(args.get("embedded", false)):
		_finish()
		return
	router.release_all()
	router.enabled = false
	create_tween().tween_property(conductor.player, "volume_db", -40.0, END_FADE)
	_finish_at = _clock + END_FADE


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
	if pixel:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if conductor != null:
		conductor.pause()
	_end_sound()


## A hold still sounding when the screen goes (quit or restart mid-hold) must not drone on, and
## Sound.end_song() also stops the silent hold drones kept ready for the song.
func _end_sound() -> void:
	for lane in 3:
		Sound.hold_stop(lane)
	Sound.end_song()
