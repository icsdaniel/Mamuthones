extends Node
## Sound autoload: the bells, steps, hold drones, the Issohadore's call, the rope,
## the count-in, carved-wood UI sounds and the looping ambiences.
##
## Everything is loaded once in _ready and played through fixed pools of
## AudioStreamPlayers, so the calls made during play (step, bell, row_bells, call_out,
## rope, hold_start, hold_stop) do no loading and create no objects.
## The samples are synthesized by tools/audio/sfx/build_all.py (modal bell model,
## source-filter voices); tools/audio/sfx/measurements.json has their measurements.
##
## Buses, created here: Music, Bells, Sfx and Ambience under Master (which gets a -1 dB
## limiter). Music sits 2 dB and Sfx 7 dB down (headroom for the bells); Bells has its own limiter, and
## every ring of the player's bells ducks the Music bus by 3 dB for ~150 ms. Three
## small buses feed Bells: BellsSoft (a soft flick: a little darker), BellsEarly and
## BellsLate (a little left and right, so a player can hear which way they were off).

const SFX_DIR := "res://audio/sfx/"
const BUS_NAMES: Array[String] = ["Music", "Bells", "Sfx", "Ambience"]
## Fixed trim under each bus's user volume (set_volume adds it).
const BUS_TRIM_DB := {"Music": -2.0, "Bells": 0.0, "Sfx": -7.0, "Ambience": 0.0}
## Each ring of the player's bells dips the music this much for DUCK_HOLD seconds, so
## the ring lands on top of the music (the bells are the reward).
const DUCK_DB := 3.0
const DUCK_ATTACK := 0.015
const DUCK_HOLD := 0.13
const DUCK_RELEASE := 0.12
const BELL_SETS: Array[String] = ["light", "village", "full"]
## Index = quality slot used by bell(): perfect, good, ok, miss, early, late.
const QUALITIES: Array[String] = ["perfect", "good", "ok", "miss", "early", "late"]
const QUALITY_TAKES: Array[int] = [3, 3, 3, 3, 2, 2]
const TAKES := 3
const LANES := 3
const UI_NAMES: Array[String] = ["tap", "back", "unlock", "carve", "result", "cue"]
const AMBIENCES: Array[String] = ["fire", "crowd", "wind"]

## A suggested ambience for each story stop (index = stop number, 1..7), for
## ambience(Sound.STOP_AMBIENCE[stop]).
const STOP_AMBIENCE: Array[String] = ["", "fire+wind", "fire+crowd", "fire+crowd", "crowd", "crowd", "crowd+fire", "crowd+wind"]

## Row-bell gain per unison level (0..5): silent alone, the whole row at full unison.
const ROW_DB: Array[float] = [-80.0, -20.0, -16.0, -12.0, -9.0, -6.0]
## After this many perfect/good rings in a row the load keeps jangling between rings.
const JANGLE_STREAK := 4
const HOLD_FADE_IN := 0.03
const HOLD_FADE_OUT := 0.09
## A drone left silent this long is stopped (hold_start restarts it).
const DRONE_IDLE_STOP := 4.0
const AMBIENCE_FADE := 1.5
const JANGLE_CHOKE := 0.12
const COUNT_STOP_FADE := 0.03
const SILENT_DB := -80.0
const SEMITONE := 1.0594630943592953
const BUS_BELLS := &"Bells"
const BUS_SOFT := &"BellsSoft"
const BUS_EARLY := &"BellsEarly"
const BUS_LATE := &"BellsLate"

# bells: set id -> Array of 12 Arrays (quality slot * 2 + (0 up / 1 down)) of takes
var _bells := {}
var _accents := {}      # set id -> [up takes, down takes]: the extra weight of a hard flick
var _jangles := {}      # set id -> the load jangling on after a streak
# row: [tight][down] -> takes
var _row: Array = []
var _feet: Array = []   # [lane] -> takes
var _tones: Array = []  # [lane] -> 6 streams, for pitch classes 0, 2, .. 10
var _drones: Array = [] # [lane] -> 12 looping streams
var _calls: Array[AudioStream] = []
var _ropes: Array[AudioStream] = []
var _grabs: Array[AudioStream] = []
var _ui := {}           # name -> Array[AudioStream]
var _amb_streams: Array[AudioStream] = []
var _count_hi: AudioStreamWAV
var _count_lo: AudioStreamWAV

var _bell_pool: Array[AudioStreamPlayer] = []
var _row_pool: Array[AudioStreamPlayer] = []
var _foot_pool: Array[AudioStreamPlayer] = []
var _tone_pool: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _hold_players: Array[AudioStreamPlayer] = []
var _amb_players: Array[AudioStreamPlayer] = []
var _jangle_player: AudioStreamPlayer
var _next := PackedInt32Array([0, 0, 0, 0, 0])  # the player after the last one used, per pool

var _key_pc := 2
var _tone_pitch := 1.0  # odd keys play the tone a semitone below, resampled up
var _unison := 0
var _streak := 0
var _jangle_choking := false
var _count_player: AudioStreamPlayer
var _count_stopping := false
var _last_take := {}
# hold fades: gain in [0, 1] and the direction it moves in (+1 in, -1 out, 0 still)
var _hold_gain := PackedFloat32Array([0.0, 0.0, 0.0])
var _hold_dir := PackedInt32Array([0, 0, 0])
var _hold_idle := PackedFloat32Array([0.0, 0.0, 0.0])
var _amb_gain := PackedFloat32Array([0.0, 0.0, 0.0])
var _amb_target := PackedFloat32Array([0.0, 0.0, 0.0])
var _missing: Array[String] = []
var _user_db := {"Music": 0.0, "Bells": 0.0, "Sfx": 0.0, "Ambience": 0.0}
var _music_bus := -1
var _duck := 0.0        # 0..1, how far the music is dipped
var _duck_hold := 0.0   # seconds left at full dip


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # drones and ambience fades keep going while paused
	_make_buses()
	_load_all()
	_make_players()


# ---------------------------------------------------------------------------- API

## Sets the song's key: step tones and hold drones play root, fifth and octave of it.
## Call it when a song starts: it also starts the three drones, silent, so a hold
## later only fades one in (starting an Ogg stream costs ~0.7 ms; fading costs nothing).
## Call end_song() when the song is over.
func set_key(midi_root: int) -> void:
	var pc := posmod(midi_root, 12)
	_key_pc = pc
	_tone_pitch = SEMITONE if pc % 2 == 1 else 1.0
	for lane in LANES:
		var p := _hold_players[lane]
		_hold_idle[lane] = 0.0
		if p.stream != _drones[lane][pc] or not p.playing:
			p.stream = _drones[lane][pc]
			p.volume_db = linear_to_db(_hold_gain[lane]) if _hold_gain[lane] > 0.001 else SILENT_DB
			p.play()


## The song is over: stops the drones and the jangle, and forgets the unison level
## and the streak. (Ambience is left alone; stop it with stop_ambience().)
func end_song() -> void:
	for lane in LANES:
		_hold_players[lane].stop()
		_hold_gain[lane] = 0.0
		_hold_dir[lane] = 0
		_hold_idle[lane] = 0.0
	_jangle_player.stop()
	_jangle_choking = false
	_unison = 0
	_streak = 0


## bus is music, bells, sfx, ambience (or master); linear 0..1 (above 1 boosts).
func set_volume(bus: String, linear: float) -> void:
	var bus_name := bus.capitalize()
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Sound.set_volume: unknown bus '%s'" % bus)
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
	_user_db[bus_name] = linear_to_db(maxf(linear, 0.0001))
	AudioServer.set_bus_volume_db(idx, _user_db[bus_name] + BUS_TRIM_DB.get(bus_name, 0.0) - (DUCK_DB * _duck if bus_name == "Music" else 0.0))


## A footfall on stone and the lane's tuned knock (Left root, Middle fifth, Right octave).
func step(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	# the footfall wanders +-3 % in pitch so no two steps are the same foot
	_play(_foot_pool, 2, _pick(_feet[lane], lane), randf_range(-1.5, 0.5), randf_range(0.97, 1.03))
	_play(_tone_pool, 3, _tones[lane][_key_pc >> 1], 0.0, _tone_pitch)


## Rings the player's bell load.
## quality: perfect, good, ok, miss; also Session.ring's silence (an ok clank) and free
## (a good ring), and early / late, which have their own rings: early = the small bells
## lead and are choked short, a little left; late = a heavy flam with the big bells
## dragging, a little right.
## strength 0..1 (the flick's peak, optional): under 1/3 is a soft ring (1 dB down, the top
## above 6 kHz eased off), over 2/3 a hard one (a heavier slam layered on top, 1 dB up).
## The rest of the row joins in at the level set by row_bells(), and after a streak the
## load keeps jangling between rings.
func bell(set_id: String, up: bool, quality: String, strength := 0.5) -> void:
	var sets: Array = _bells[set_id] if _bells.has(set_id) else _bells[_alias(set_id)]
	var q := _quality_index(quality)
	var d := 0 if up else 1
	var takes: Array = sets[q * 2 + d]
	# A tiny random pitch (+-0.25 %, what a load swinging at walking pace does by
	# Doppler) so no two rings are identical.
	var pitch := randf_range(0.9975, 1.0025)
	var gain := randf_range(-0.5, 0.0)
	var bus := BUS_BELLS
	var hard := false
	if q == 4:
		bus = BUS_EARLY
		pitch *= 1.02
	elif q == 5:
		bus = BUS_LATE
		pitch *= 0.98
	elif q != 3:
		if strength < 0.34:
			# a soft flick: slightly quieter and a little darker, never worse than a Good
			bus = BUS_SOFT
			gain -= 1.0
		elif strength > 0.67:
			hard = true
			gain += 1.0
	var load_id: String = set_id if _accents.has(set_id) else _alias(set_id)
	_play(_bell_pool, 0, _pick(takes, 100 + q * 2 + d), gain, pitch, bus)
	if q != 3:
		_duck_hold = DUCK_HOLD  # the music steps back for the ring (see _process)
	if hard:
		var acc: Array = _accents[load_id][d]
		_play(_bell_pool, 0, _pick(acc, 120 + d), gain, pitch, bus)
	if _unison > 0 and _row_joins(quality):
		# the row rings with you: tight and loud at high unison, ragged and far at low
		var tight := 1 if _unison >= 3 and q <= 1 else 0
		var rgain: float = ROW_DB[_unison] - (0.0 if q <= 1 else 6.0)
		var rt: Array = _row[tight][d]
		_play(_row_pool, 1, _pick(rt, 200 + tight * 2 + d), rgain + randf_range(-1.0, 0.0), randf_range(0.996, 1.004), BUS_BELLS)
	_update_jangle(load_id, q, quality)


## Unison level 0..5 (Session.unison_level): how much of the row rings with your bells.
func row_bells(unison_level: int) -> void:
	_unison = clampi(unison_level, 0, ROW_DB.size() - 1)


## The Issohadore's call. (Named call_out because Object.call() cannot be overridden.)
func call_out() -> void:
	_play(_sfx_pool, 4, _pick(_calls, 300), randf_range(-1.0, 0.0))


## The rope (soha) thrown: a swish, a crack as it pulls tight, and it lands.
func rope() -> void:
	_play(_sfx_pool, 4, _pick(_ropes, 301), randf_range(-1.0, 0.0))


## A finger has closed on an open rope (swipe) note: a hand gripping the rope, a
## short creak of the fibres.
func rope_grab() -> void:
	_play(_sfx_pool, 4, _pick(_grabs, 302), randf_range(-1.0, 0.0))


## Fades in the lane's drone (a launeddas-style reed at the lane's pitch), looping.
func hold_start(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	var p := _hold_players[lane]
	_hold_idle[lane] = 0.0
	if not p.playing or p.stream != _drones[lane][_key_pc]:
		# set_key() was not called, or the drone was stopped after sitting idle
		p.stream = _drones[lane][_key_pc]
		_hold_gain[lane] = 0.0
		p.volume_db = SILENT_DB
		p.play()
	# start the fade in this same audio block (Godot ramps the volume across the mix
	# block, so the jump to -20 dB is smooth); _process takes it the rest of the way
	if _hold_gain[lane] < 0.1:
		_hold_gain[lane] = 0.1
		p.volume_db = linear_to_db(0.1)
	_hold_dir[lane] = 1


## Fades the lane's drone out (no click). It keeps running silently for a few seconds,
## ready for the next hold, then stops.
func hold_stop(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	if _hold_gain[lane] > 0.0 or _hold_dir[lane] > 0:
		_hold_dir[lane] = -1


## UI sounds: tap, back, unlock, carve, result, and cue (the soft shake of tiny bells
## played half a beat before a bell on Easy and Medium: quiet and high, not a ring).
func ui(name: String) -> void:
	if not _ui.has(name):
		push_warning("Sound.ui: unknown sound '%s'" % name)
		return
	var takes: Array = _ui[name]
	_play(_sfx_pool, 4, _pick(takes, 400 + UI_NAMES.find(name)), randf_range(-0.8, 0.0))


## Crossfades to a looping ambience: fire, crowd or wind. Several can be layered with
## "+", for example "fire+crowd".
func ambience(name: String) -> void:
	var wanted := name.split("+", false)
	for i in AMBIENCES.size():
		var on := wanted.has(AMBIENCES[i])
		_amb_target[i] = 1.0 if on else 0.0
		var p := _amb_players[i]
		if on and not p.playing:
			_amb_gain[i] = 0.0
			p.volume_db = SILENT_DB
			# start somewhere in the loop so it never sounds like the same recording
			p.play(randf() * maxf(0.0, p.stream.get_length() - 1.0))
	for w in wanted:
		if not AMBIENCES.has(w):
			push_warning("Sound.ambience: unknown ambience '%s'" % w)


## Fades every ambience out.
func stop_ambience() -> void:
	for i in AMBIENCES.size():
		_amb_target[i] = 0.0


## Plays four beats at bpm (a frame drum with a stick click, the first beat a fifth
## higher), sample-accurate because the four hits are laid into one stream. Returns
## the count-in's length in seconds.
func count_in(bpm: float) -> float:
	bpm = clampf(bpm, 30.0, 300.0)
	var beat := int(round(44100.0 * 60.0 / bpm))
	if _count_hi == null or _count_lo == null or _count_hi.format != AudioStreamWAV.FORMAT_16_BITS \
			or _count_lo.format != AudioStreamWAV.FORMAT_16_BITS or _count_hi.stereo or _count_lo.stereo:
		push_warning("Sound.count_in: count samples must be imported as uncompressed mono 16-bit")
		return 0.0
	var data := PackedByteArray()
	for i in 4:
		var hit: PackedByteArray = (_count_hi if i == 0 else _count_lo).data
		var n := mini(hit.size(), beat * 2)
		data.append_array(hit.slice(0, n))
		var gap := PackedByteArray()
		gap.resize(beat * 2 - n)  # zero-filled silence up to the next beat
		data.append_array(gap)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = data
	# the count-in has a player of its own, so stop_count_in() can find it
	_count_stopping = false
	_count_player.stream = stream
	_count_player.volume_db = 0.0
	_count_player.play()
	return 4.0 * 60.0 / bpm


## Silences a count-in that is playing (a quick 30 ms fade, no click).
func stop_count_in() -> void:
	if _count_player.playing:
		_count_stopping = true


# ---------------------------------------------------------------------------- inside

## Not part of the play API: stops every sound at once (quitting, tests). The audio
## server needs a moment afterwards to release the streams.
func stop_all() -> void:
	for pool in [_bell_pool, _row_pool, _foot_pool, _tone_pool, _sfx_pool, _hold_players, _amb_players]:
		for p: AudioStreamPlayer in pool:
			p.stop()
	if _jangle_player:
		_jangle_player.stop()
	if _count_player:
		_count_player.stop()
		_count_stopping = false
	_hold_gain.fill(0.0)
	_hold_dir.fill(0)
	_hold_idle.fill(0.0)
	_amb_gain.fill(0.0)
	_amb_target.fill(0.0)
	_streak = 0


func _exit_tree() -> void:
	stop_all()


func _process(delta: float) -> void:
	# music duck: a 15 ms dip, held while the ring's attack sounds, a 120 ms return.
	# The bus volume is ramped across each mix block, so the steps don't click.
	var duck := _duck
	if _duck_hold > 0.0:
		_duck_hold -= delta
		duck = move_toward(duck, 1.0, delta / DUCK_ATTACK)
	else:
		duck = move_toward(duck, 0.0, delta / DUCK_RELEASE)
	if duck != _duck:
		_duck = duck
		AudioServer.set_bus_volume_db(_music_bus, _user_db["Music"] + BUS_TRIM_DB["Music"] - DUCK_DB * _duck)
	for lane in LANES:
		var p := _hold_players[lane]
		var d := _hold_dir[lane]
		if d == 0:
			# a silent drone left running too long is stopped
			if p.playing and _hold_gain[lane] <= 0.0:
				_hold_idle[lane] += delta
				if _hold_idle[lane] >= DRONE_IDLE_STOP:
					p.stop()
					_hold_idle[lane] = 0.0
			continue
		_hold_idle[lane] = 0.0
		var g := _hold_gain[lane] + delta / (HOLD_FADE_IN if d > 0 else -HOLD_FADE_OUT)
		if g >= 1.0:
			g = 1.0
			_hold_dir[lane] = 0
		elif g <= 0.0:
			g = 0.0
			_hold_dir[lane] = 0
		_hold_gain[lane] = g
		p.volume_db = linear_to_db(g) if g > 0.001 else SILENT_DB
	for i in AMBIENCES.size():
		var tgt := _amb_target[i]
		var g := _amb_gain[i]
		if is_equal_approx(g, tgt):
			continue
		g = move_toward(g, tgt, delta / AMBIENCE_FADE)
		_amb_gain[i] = g
		var p := _amb_players[i]
		# equal-power-ish curve so a crossfade doesn't dip
		p.volume_db = linear_to_db(maxf(sin(g * PI * 0.5), 0.001))
		if g <= 0.0 and p.playing:
			p.stop()
	if _count_stopping:
		_count_player.volume_db -= delta * 60.0 / COUNT_STOP_FADE
		if _count_player.volume_db <= -60.0 or not _count_player.playing:
			_count_player.stop()
			_count_stopping = false
	if _jangle_choking and _jangle_player.playing:
		# a miss muffles the load: the jangle is choked within ~0.1 s
		_jangle_player.volume_db -= delta * 60.0 / JANGLE_CHOKE
		if _jangle_player.volume_db <= -60.0:
			_jangle_player.stop()
			_jangle_choking = false


func _update_jangle(load_id: String, q: int, quality: String) -> void:
	if q == 3:
		_streak = 0
		if _jangle_player.playing:
			_jangle_choking = true
		return
	if q > 1 or quality == "free":
		_streak = 0
		return
	_streak += 1
	if _streak < JANGLE_STREAK:
		return
	var p := _jangle_player
	var js: AudioStream = _jangles[load_id]
	# keep one jangle going under the rings; restart it once it is under way
	if p.playing and p.stream == js and p.get_playback_position() < 0.45:
		return
	_jangle_choking = false
	p.stream = js
	p.volume_db = -6.0 + 1.5 * minf(float(_streak - JANGLE_STREAK), 4.0)
	p.pitch_scale = randf_range(0.995, 1.005)
	p.play()


func _play(pool: Array[AudioStreamPlayer], which: int, stream: AudioStream, gain_db: float,
		pitch := 1.0, bus := &"") -> void:
	if stream == null:
		return
	# a free player if there is one (from the round-robin position); otherwise steal
	# the voice that has played longest, whose tail is quietest
	var n := pool.size()
	var start := _next[which]
	var chosen := -1
	var oldest := -1.0
	for k in n:
		var i := (start + k) % n
		var cand := pool[i]
		if not cand.playing:
			chosen = i
			break
		var pos := cand.get_playback_position()
		if pos > oldest:
			oldest = pos
			chosen = i
	_next[which] = (chosen + 1) % n
	var p := pool[chosen]
	p.stream = stream
	p.volume_db = gain_db
	p.pitch_scale = pitch
	if bus != &"":
		p.bus = bus
	p.play()


## Random take, never the same one twice in a row for the same sound.
func _pick(takes: Array, slot: int) -> AudioStream:
	var n := takes.size()
	if n == 0:
		return null
	if n == 1:
		return takes[0]
	var last: int = _last_take.get(slot, -1)
	var i := randi() % n
	if i == last:
		i = (i + 1 + randi() % (n - 1)) % n
	_last_take[slot] = i
	return takes[i]


func _quality_index(quality: String) -> int:
	match quality:
		"perfect":
			return 0
		"good", "free":
			return 1
		"ok", "silence":
			return 2
		"miss", "wrong":
			return 3
		"early":
			return 4
		"late":
			return 5
	return 1


## The row rings with you only when you rang with the procession: not for a free ring
## (no note), nor for one during a stand-still.
func _row_joins(quality: String) -> bool:
	match quality:
		"perfect", "good", "ok", "early", "late":
			return true
	return false


func _alias(set_id: String) -> String:
	match set_id.to_lower():
		"full_load", "fullload", "heavy", "full":
			return "full"
		"light", "first":
			return "light"
	return "village"


func _make_buses() -> void:
	for bus_name in BUS_NAMES:
		_ensure_bus(bus_name, "Master")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), BUS_TRIM_DB[bus_name])
	# Bells: a limiter only. Its -3.5 dB ceiling (2 dB under the samples' own peaks) plus
	# the Music and Sfx trims keep the Master limiter to about 1 dB of peak shaving when
	# a hard ring, its accent, the full row, a step and a dense remix all land together.
	var bells := AudioServer.get_bus_index("Bells")
	if AudioServer.get_bus_effect_count(bells) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -3.5
		lim.release = 0.12
		AudioServer.add_bus_effect(bells, lim)
	var soft := _ensure_bus("BellsSoft", "Bells")
	if AudioServer.get_bus_effect_count(soft) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 6000.0  # a gentle roll-off of the top only
		AudioServer.add_bus_effect(soft, lp)
	for pair in [["BellsEarly", -0.3], ["BellsLate", 0.3]]:
		var idx := _ensure_bus(pair[0], "Bells")
		if AudioServer.get_bus_effect_count(idx) == 0:
			var pan := AudioEffectPanner.new()
			pan.pan = pair[1]
			AudioServer.add_bus_effect(idx, pan)
	_music_bus = AudioServer.get_bus_index("Music")
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)


func _ensure_bus(bus_name: String, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


func _load_all() -> void:
	for s in BELL_SETS:
		var arr: Array = []
		for qi in QUALITIES.size():
			for dir in ["up", "down"]:
				arr.append(_load_takes("bells/%s_%s_%s_%%d.wav" % [s, dir, QUALITIES[qi]], QUALITY_TAKES[qi]))
		_bells[s] = arr
		_accents[s] = [_load_takes("bells/%s_up_accent_%%d.wav" % s, 2), _load_takes("bells/%s_down_accent_%%d.wav" % s, 2)]
		_jangles[s] = _load("bells/%s_jangle_1.wav" % s)
	for tight in ["loose", "tight"]:
		var by_dir: Array = []
		for dir in ["up", "down"]:
			by_dir.append(_load_takes("bells/row_%s_%s_%%d.wav" % [tight, dir], TAKES))
		_row.append(by_dir)
	for lane in LANES:
		_feet.append(_load_takes("steps/foot_%d_%%d.wav" % lane, TAKES))
		var tones: Array = []
		var drones: Array = []
		for pc in 12:
			if pc % 2 == 0:
				tones.append(_load("steps/tone_%d_%02d.wav" % [lane, pc]))
			var d := _load("loops/drone_%d_%02d.ogg" % [lane, pc])
			_set_loop(d)
			drones.append(d)
		_tones.append(tones)
		_drones.append(drones)
	_calls.assign(_load_takes("voice/call_%d.wav", 4))
	_ropes.assign(_load_takes("fx/rope_%d.wav", TAKES))
	_grabs.assign(_load_takes("fx/grab_%d.wav", TAKES))
	_ui["cue"] = _load_takes("ui/cue_%d.wav", TAKES)
	_ui["tap"] = _load_takes("ui/tap_%d.wav", TAKES)
	_ui["back"] = _load_takes("ui/back_%d.wav", 1)
	_ui["carve"] = _load_takes("ui/carve_%d.wav", TAKES)
	_ui["unlock"] = [_load("ui/unlock.ogg")]
	_ui["result"] = [_load("ui/result.ogg")]
	for a in AMBIENCES:
		var s := _load("ambience/%s.ogg" % a)
		_set_loop(s)
		_amb_streams.append(s)
	_count_hi = _load("fx/count_hi.wav") as AudioStreamWAV
	_count_lo = _load("fx/count_lo.wav") as AudioStreamWAV
	if not _missing.is_empty():
		push_warning("Sound: %d samples missing, e.g. %s" % [_missing.size(), _missing[0]])


func _load_takes(pattern: String, count: int) -> Array:
	var out: Array = []
	for k in count:
		var s := _load(pattern % (k + 1))
		if s != null:
			out.append(s)
	return out


func _load(rel: String) -> AudioStream:
	var path := SFX_DIR + rel
	if not ResourceLoader.exists(path):
		_missing.append(rel)
		return null
	return load(path) as AudioStream


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _make_players() -> void:
	_fill(_bell_pool, 10, "Bells")
	_fill(_row_pool, 6, "Bells")
	_fill(_foot_pool, 4, "Sfx")
	_fill(_tone_pool, 4, "Sfx")
	_fill(_sfx_pool, 6, "Sfx")
	_fill(_hold_players, LANES, "Sfx")
	_fill(_amb_players, AMBIENCES.size(), "Ambience")
	for i in AMBIENCES.size():
		_amb_players[i].stream = _amb_streams[i]
	var j: Array[AudioStreamPlayer] = []
	_fill(j, 1, "Bells")
	_jangle_player = j[0]
	var c: Array[AudioStreamPlayer] = []
	_fill(c, 1, "Sfx")
	_count_player = c[0]


func _fill(pool: Array[AudioStreamPlayer], count: int, bus: String) -> void:
	for i in count:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		pool.append(p)
