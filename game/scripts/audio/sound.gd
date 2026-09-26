extends Node
## Sound autoload: the bells, steps, hold drones, the Issohadore's call, the rope,
## the count-in, carved-wood UI sounds and the looping ambiences.
##
## Everything is loaded once in _ready and played through fixed pools of
## AudioStreamPlayers, so the calls made during play (step, bell, row_bells, call,
## rope, hold_start, hold_stop) do no loading and create no objects.
## The samples are synthesized by tools/audio/sfx/build_all.py (modal bell model,
## source-filter voices); tools/audio/sfx/measurements.json has their measurements.
##
## Buses: Music, Bells, Sfx and Ambience are created here (under Master, which gets a
## -1 dB limiter so a stack of bells never clips).

const SFX_DIR := "res://audio/sfx/"
const BUS_NAMES: Array[String] = ["Music", "Bells", "Sfx", "Ambience"]
const BELL_SETS: Array[String] = ["light", "village", "full"]
const QUALITIES: Array[String] = ["perfect", "good", "ok", "miss"]
const TAKES := 3
const LANES := 3
const UI_NAMES: Array[String] = ["tap", "back", "unlock", "carve", "result"]
const AMBIENCES: Array[String] = ["fire", "crowd", "wind"]

## A suggested ambience for each story stop (index = stop number, 1..7), for
## ambience(Sound.STOP_AMBIENCE[stop]).
const STOP_AMBIENCE: Array[String] = ["", "fire+wind", "fire+crowd", "fire+crowd", "crowd", "crowd", "crowd+fire", "crowd+wind"]

## Row-bell gain per unison level (0..5): silent alone, the whole row at full unison.
const ROW_DB: Array[float] = [-80.0, -17.0, -13.0, -9.0, -6.0, -3.0]
const HOLD_FADE_IN := 0.03
const HOLD_FADE_OUT := 0.09
const AMBIENCE_FADE := 1.5
const SILENT_DB := -60.0

# bells: set id -> Array of 8 Arrays (quality * 2 + (0 up / 1 down)) of takes
var _bells := {}
# row: [tight][down] -> takes
var _row: Array = []
var _feet: Array = []   # [lane] -> takes
var _tones: Array = []  # [lane] -> 6 streams, for pitch classes 0, 2, .. 10
var _drones: Array = [] # [lane] -> 12 looping streams
var _calls: Array[AudioStream] = []
var _ropes: Array[AudioStream] = []
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
var _next := PackedInt32Array([0, 0, 0, 0, 0])  # round-robin index per pool

var _key_pc := 2
var _tone_pitch := 1.0  # odd keys play the tone a semitone below, resampled up
const SEMITONE := 1.0594630943592953
var _unison := 0
var _last_take := {}
# hold fades: gain in [0, 1] and the direction it moves in (+1 in, -1 out, 0 still)
var _hold_gain := PackedFloat32Array([0.0, 0.0, 0.0])
var _hold_dir := PackedInt32Array([0, 0, 0])
var _amb_gain := PackedFloat32Array([0.0, 0.0, 0.0])
var _amb_target := PackedFloat32Array([0.0, 0.0, 0.0])
var _missing: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # drones and ambience fades keep going while paused
	_make_buses()
	_load_all()
	_make_players()


# ---------------------------------------------------------------------------- API

## Sets the song's key: step tones and hold drones play root, fifth and octave of it.
## Call it when a song starts: it also starts the three drones, silent, so a hold
## later only fades one in (starting an Ogg stream costs ~0.7 ms; fading costs nothing).
func set_key(midi_root: int) -> void:
	var pc := posmod(midi_root, 12)
	_key_pc = pc
	_tone_pitch = SEMITONE if pc % 2 == 1 else 1.0
	for lane in LANES:
		var p := _hold_players[lane]
		if p.stream != _drones[lane][pc] or not p.playing:
			p.stream = _drones[lane][pc]
			p.volume_db = linear_to_db(maxf(_hold_gain[lane], 0.001))
			p.play()


## bus is music, bells, sfx, ambience (or master); linear 0..1 (above 1 boosts).
func set_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus.capitalize())
	if idx < 0:
		push_warning("Sound.set_volume: unknown bus '%s'" % bus)
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## A footfall on stone and the lane's tuned knock (Left root, Middle fifth, Right octave).
func step(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	_play(_foot_pool, 2, _pick(_feet[lane], lane), randf_range(-1.5, 0.5))
	_play(_tone_pool, 3, _tones[lane][_key_pc / 2], 0.0, _tone_pitch)


## Rings the player's bell load. quality: perfect, good, ok, miss (also silence, free,
## early, late). The rest of the row joins in at the level set by row_bells().
func bell(set_id: String, up: bool, quality: String) -> void:
	var sets: Array = _bells[set_id] if _bells.has(set_id) else _bells[_alias(set_id)]
	var q := _quality_index(quality)
	var takes: Array = sets[q * 2 + (0 if up else 1)]
	_play(_bell_pool, 0, _pick(takes, 100 + q * 2 + (0 if up else 1)), randf_range(-0.8, 0.0))
	if _unison > 0 and q <= 2:
		# the row rings with you: tight and loud at high unison, ragged and far at low
		var tight := 1 if _unison >= 3 and q <= 1 else 0
		var gain: float = ROW_DB[_unison] - (6.0 if q == 2 else 0.0)
		var rt: Array = _row[tight][0 if up else 1]
		_play(_row_pool, 1, _pick(rt, 200 + tight * 2 + (0 if up else 1)), gain + randf_range(-1.0, 0.0))


## Unison level 0..5 (Session.unison_level): how much of the row rings with your bells.
func row_bells(unison_level: int) -> void:
	_unison = clampi(unison_level, 0, ROW_DB.size() - 1)


## The Issohadore's call. (Named call_out because Object.call() cannot be overridden.)
func call_out() -> void:
	_play(_sfx_pool, 4, _pick(_calls, 300), randf_range(-1.0, 0.0))


## The rope (soha) thrown: a swish, a crack as it pulls tight, and it lands.
func rope() -> void:
	_play(_sfx_pool, 4, _pick(_ropes, 301), randf_range(-1.0, 0.0))


## Fades in the lane's drone (a launeddas-style reed at the lane's pitch), looping.
func hold_start(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	var p := _hold_players[lane]
	if not p.playing or p.stream != _drones[lane][_key_pc]:
		# set_key() was not called (or stop_all() ran): start it now
		p.stream = _drones[lane][_key_pc]
		_hold_gain[lane] = 0.0
		p.volume_db = SILENT_DB
		p.play()
	_hold_dir[lane] = 1


## Fades the lane's drone out (no click). It keeps running silently, ready for the
## next hold.
func hold_stop(lane: int) -> void:
	lane = clampi(lane, 0, LANES - 1)
	if _hold_gain[lane] > 0.0 or _hold_dir[lane] > 0:
		_hold_dir[lane] = -1


## UI sounds: tap, back, unlock, carve, result.
func ui(name: String) -> void:
	var takes: Array = _ui.get(name, [])
	if takes.is_empty():
		push_warning("Sound.ui: unknown sound '%s'" % name)
		return
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


## Plays four beats at bpm (a frame drum, the first beat accented), sample-accurate
## because the four hits are laid into one stream. Returns the count-in's length in s.
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
	_play(_sfx_pool, 4, stream, 0.0)
	return 4.0 * 60.0 / bpm


# ---------------------------------------------------------------------------- inside

## Not part of the play API: stops every sound at once (quitting, tests). The audio
## server needs a frame or two afterwards to release the streams.
func stop_all() -> void:
	for pool in [_bell_pool, _row_pool, _foot_pool, _tone_pool, _sfx_pool, _hold_players, _amb_players]:
		for p: AudioStreamPlayer in pool:
			p.stop()
	_hold_gain.fill(0.0)
	_hold_dir.fill(0)
	_amb_gain.fill(0.0)
	_amb_target.fill(0.0)


func _exit_tree() -> void:
	stop_all()


func _process(delta: float) -> void:
	for lane in LANES:
		var d := _hold_dir[lane]
		if d == 0:
			continue
		var g := _hold_gain[lane] + delta / (HOLD_FADE_IN if d > 0 else -HOLD_FADE_OUT)
		if g >= 1.0:
			g = 1.0
			_hold_dir[lane] = 0
		elif g <= 0.0:
			g = 0.0
			_hold_dir[lane] = 0
		_hold_gain[lane] = g
		_hold_players[lane].volume_db = linear_to_db(g) if g > 0.001 else -80.0
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


func _play(pool: Array[AudioStreamPlayer], which: int, stream: AudioStream, gain_db: float, pitch := 1.0) -> void:
	if stream == null:
		return
	# round robin, but prefer a free player so a ringing tail is not cut
	var n := pool.size()
	var start := _next[which]
	var p := pool[start]
	for k in n:
		var cand := pool[(start + k) % n]
		if not cand.playing:
			p = cand
			start = (start + k) % n
			break
	_next[which] = (start + 1) % n
	p.stream = stream
	p.volume_db = gain_db
	p.pitch_scale = pitch
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
		"ok", "early", "late", "silence":
			return 2
		"miss", "wrong":
			return 3
	return 1


func _alias(set_id: String) -> String:
	match set_id.to_lower():
		"full_load", "fullload", "heavy", "full":
			return "full"
		"light", "first":
			return "light"
	return "village"


func _make_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)


func _load_all() -> void:
	for s in BELL_SETS:
		var arr: Array = []
		for q in QUALITIES:
			for dir in ["up", "down"]:
				arr.append(_load_takes("bells/%s_%s_%s_%%d.wav" % [s, dir, q], TAKES))
		_bells[s] = arr
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
	_fill(_bell_pool, 8, "Bells")
	_fill(_row_pool, 4, "Bells")
	_fill(_foot_pool, 4, "Sfx")
	_fill(_tone_pool, 4, "Sfx")
	_fill(_sfx_pool, 6, "Sfx")
	_fill(_hold_players, LANES, "Sfx")
	_fill(_amb_players, AMBIENCES.size(), "Ambience")
	for i in AMBIENCES.size():
		_amb_players[i].stream = _amb_streams[i]


func _fill(pool: Array[AudioStreamPlayer], count: int, bus: String) -> void:
	for i in count:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		pool.append(p)
