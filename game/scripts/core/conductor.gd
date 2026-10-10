class_name Conductor
extends Node
## Owns the music player and says what time it is in the song.
##
## song_time() = playback position + time since the last mix - output latency - the player's audio
## offset, smoothed so it never goes backwards. Between audio updates it runs on the frame clock
## (and, within a frame, on the real-time clock, so input events get sub-frame times); when the
## audio clock stops moving (headless tests use a dummy audio driver, or the file is missing) the
## frame clock carries on alone.
##
## play(song, remix := false, start_time := 0.0): a negative start_time is a silent lead-in (song
## time starts there and the music starts at 0); a positive one starts the music part-way (lessons,
## practice). Tests: use_manual_clock(true), then advance(delta).
##
## Additions beyond the architecture doc: start_time and seek(t), is_playing(), is_paused(),
## current_beat(), audio_offset (defaults to Profile's setting), player, and use_audio (false keeps
## the music off while keeping the clock, for silent practice).

signal finished

const RESYNC := 0.080         ## seconds of drift that trigger a hard resync
const PULL := 0.15            ## share of smaller drift corrected per audio update
## Godot 4.6's movie maker writes the audio 525 samples (at 44.1 kHz) ahead of the frames it
## belongs to (measured by recording a click track and finding the clicks in the written WAV), so
## recordings start the music that much later to stay in sync.
const MOVIE_AUDIO_SHIFT := 525.0 / 44100.0

var player: AudioStreamPlayer
var audio_offset := NAN       ## seconds; NAN = read Profile's audio_offset at play()
var use_audio := true
var song: SongData
var remix := false

var _manual := false
var _playing := false
var _paused := false
var _clock := 0.0             # smoothed song time at _stamp
var _stamp := 0               # _ticks() when _clock was set
var _out := -INF              # last value handed out (never goes back)
var _audio_started := false
var _last_raw := NAN
var _length := 0.0
var _finished_sent := false
var _offset_used := 0.0


func _init() -> void:
	player = AudioStreamPlayer.new()
	player.name = "Music"
	add_child(player)
	player.finished.connect(_on_player_finished)


func _ready() -> void:
	player.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"


func use_manual_clock(on: bool) -> void:
	_manual = on


func play(p_song: SongData, p_remix := false, start_time := 0.0) -> void:
	song = p_song
	remix = p_remix and song.has_remix()
	_length = song.length_for(remix)
	# Recordings (movie maker) mix audio in lockstep with frames: no latency, no player offset.
	_offset_used = 0.0 if _recording() else (audio_offset if not is_nan(audio_offset) else _profile_offset())
	var path := song.audio_for(remix)
	player.stream = null
	if use_audio and path != "" and ResourceLoader.exists(path):
		player.stream = load(path)
	if player.stream != null:
		var l := player.stream.get_length()
		if l > 0.0:
			_length = l
	_playing = true
	_paused = false
	_finished_sent = false
	_start_at(start_time)


## Jump to song time t (keeps playing or paused as it was).
func seek(t: float) -> void:
	_start_at(t)


func _start_at(t: float) -> void:
	player.stop()
	_audio_started = false
	_clock = t
	_out = t
	_stamp = _ticks()
	_last_raw = NAN
	if t >= -_audio_lead():
		_start_audio(t)


# The music has to start this much before song time 0 so that what the player hears lines up
# with song time: output latency plus the player's own offset.
func _audio_lead() -> float:
	if _recording():
		return -MOVIE_AUDIO_SHIFT
	return _latency() + _offset_used


## How long after the game plays a sound the player hears it: output latency plus the player's
## sound delay (Bluetooth headphones add 150-250 ms). A sound meant to be heard at song time t has to
## be played at t - heard_delay(). 0 in recordings, which mix in step with the frames.
func heard_delay() -> float:
	return 0.0 if _recording() else _latency() + _offset_used


func _start_audio(t: float) -> void:
	_audio_started = true
	if player.stream != null:
		player.play(maxf(0.0, t + _audio_lead()))
		player.stream_paused = _paused


func pause() -> void:
	if not _playing or _paused:
		return
	_clock = _now()
	_paused = true
	player.stream_paused = true


func resume() -> void:
	if not _paused:
		return
	_paused = false
	_stamp = _ticks()
	_last_raw = NAN   # re-anchor on the audio clock at the next reading
	player.stream_paused = false


func stop() -> void:
	_playing = false
	player.stop()


func is_playing() -> bool:
	return _playing and not _paused


func is_paused() -> bool:
	return _paused


## Current song time in seconds (never goes backwards while playing).
func song_time() -> float:
	var t := _now()
	if t > _out:
		_out = t
	return _out


func current_beat() -> float:
	return song.beat_at(song_time(), remix) if song != null else 0.0


## Manual clock: move song time forward by delta seconds.
func advance(delta: float) -> void:
	if not _playing or _paused:
		return
	_clock += delta
	_stamp = _ticks()
	_after_tick()


func _process(delta: float) -> void:
	if _manual or not _playing or _paused:
		return
	# Real time, not delta: the first frame after play() can carry the time spent loading the
	# screen. Movie recordings run on fixed frame steps, so they use delta.
	_clock = _clock + delta if _recording() else _now()
	_stamp = _ticks()
	if _audio_started and _audio_playing() and not _recording():
		# The audio clock only moves when a mix happens; comparing with the last reading tells
		# whether it moved at all (it never does with the dummy driver).
		var raw := _audio_clock()
		if is_nan(_last_raw) or raw != _last_raw:
			if not is_nan(_last_raw):
				var audio_t := raw - _latency() - _offset_used
				var err := audio_t - _clock
				_clock = audio_t if absf(err) > RESYNC else _clock + err * PULL
			_last_raw = raw
	_after_tick()


func _after_tick() -> void:
	if not _audio_started and _clock >= -_audio_lead():
		_start_audio(_clock)
	if not _finished_sent and _length > 0.0 and _clock >= _length and (player.stream == null or not player.playing or _manual):
		_finished_sent = true
		finished.emit()


func _now() -> float:
	if _manual or not _playing or _paused or _recording():
		return _clock
	return _clock + (_ticks() - _stamp) / 1_000_000.0


# Clock sources, separate so tests can stand in a simulated audio driver.
func _ticks() -> int:
	return Time.get_ticks_usec()


func _audio_playing() -> bool:
	return player.playing


func _audio_clock() -> float:
	return player.get_playback_position() + AudioServer.get_time_since_last_mix()


func _latency() -> float:
	return 0.0 if _recording() else AudioServer.get_output_latency()


static func _recording() -> bool:
	return Engine.get_write_movie_path() != ""


func _on_player_finished() -> void:
	if not _finished_sent:
		_finished_sent = true
		finished.emit()


func _profile_offset() -> float:
	var p := get_node_or_null("/root/Profile") if is_inside_tree() else null
	if p != null and p.has_method("audio_offset"):
		return float(p.audio_offset())
	return 0.0
