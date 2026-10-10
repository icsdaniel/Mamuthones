class_name RunLog
extends RefCounted
## Records one played song in full, so a run that felt wrong on a phone can be sent to the
## developers and checked frame by frame: the phone and build, every setting and the calibration,
## every frame (real time, song clock, shown time, audio clock), every touch (where it landed, which
## lane, inside the button zone or not, what the rules made of it), every judgement and rule event,
## and the motion readings with the bells they rang. The play screen keeps only the last run: each
## save overwrites FILE_NAME in the phone's Downloads folder (or user:// when that cannot be written).
##
## The file is one JSON object; tables are arrays of rows with their column names alongside
## ("frames_cols", "motion_cols"), to keep a two-minute song to a megabyte or two.

const FILE_NAME := "mamuthones-last-run.json"
const VERSION := 1
const MAX_FRAMES := 60 * 60 * 8    ## eight minutes at 60 fps
const MAX_EVENTS := 40000

var header: Dictionary = {}
var session: Session
var frames: Array = []             # [real s, song t, shown t, delta, audio pos, since mix, paused]
var events: Array = []             # [real s, song t, kind, {...}]
var motion: MotionLog
var saved_path := ""
var _t0 := 0


func _init(p_session: Session, extra: Dictionary = {}) -> void:
	session = p_session
	_t0 = Time.get_ticks_usec()
	motion = MotionLog.new()
	header = describe_device()
	header.merge({
		"log_version": VERSION,
		"build": BuildInfo.SHA,
		"recorded_at": Time.get_datetime_string_from_system(true),
		"song_id": session.song.id,
		"difficulty": session.difficulty,
		"remix": session.remix,
		"bpm": session.song.bpm,
		"options": session.options,
		"windows": {"perfect": session.win_touch.x, "good": session.win_touch.y, "ok": session.win_touch.z,
			"tilt": [session.win_tilt.x, session.win_tilt.y, session.win_tilt.z]},
		"lock": {"taps": Session.LOCK_TAPS, "span": Session.LOCK_SPAN, "time": Session.LOCK_TIME},
	}, true)
	header.merge(extra, true)


## The phone, the build and the player's settings: what the rest of the log is read against.
static func describe_device() -> Dictionary:
	var d := {
		"os": OS.get_name(), "os_version": OS.get_version(), "model": OS.get_model_name(),
		"processor": OS.get_processor_name(), "cores": OS.get_processor_count(),
		"engine": Engine.get_version_info().get("string", ""),
		"debug_build": OS.is_debug_build(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"screen": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"physics_fps": Engine.physics_ticks_per_second,
		"mix_rate": AudioServer.get_mix_rate(),
		"output_latency": AudioServer.get_output_latency(),
		"output_device": AudioServer.output_device,
	}
	var p: Node = Engine.get_main_loop().root.get_node_or_null("/root/Profile") if Engine.get_main_loop() is SceneTree else null
	if p != null:
		var settings := {}
		for k in p.DEFAULT_SETTINGS:
			settings[k] = p.get_setting(k)
		d["settings"] = settings
		d["calibration"] = p.calibration()
	return d


func now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1_000_000.0


## One frame of the play screen.
func frame(song_t: float, shown_t: float, delta: float, audio_pos: float, since_mix: float, paused: bool) -> void:
	if frames.size() >= MAX_FRAMES:
		return
	frames.append([snappedf(now(), 0.0001), snappedf(song_t, 0.0001), snappedf(shown_t, 0.0001),
		snappedf(delta, 0.0001), snappedf(audio_pos, 0.0001), snappedf(since_mix, 0.0001), 1 if paused else 0])


## Something happened at song time t: kind names it, data says what.
func event(song_t: float, kind: String, data: Dictionary = {}) -> void:
	if events.size() >= MAX_EVENTS:
		return
	events.append([snappedf(now(), 0.0001), snappedf(song_t, 0.0001), kind, data])


## A note judged by the rules (judged signal).
func judged(song_t: float, n: Note, judgement: String, offset: float) -> void:
	event(song_t, "judged", {"note": n.index if n != null else -1, "j": judgement, "off": snappedf(offset, 0.0001)})


## Every note of the chart with how it ended.
func notes_table() -> Array:
	var out := []
	for n in session.notes:
		out.append([n.index, snappedf(n.t, 0.0001), n.kind_name(), n.lane, n.beat, snappedf(n.end_t, 0.0001),
			n.judgement, snappedf(n.hit_at, 0.0001) if not is_nan(n.hit_at) else null, n.side,
			1 if n.call else 0, 1 if n.heal else 0])
	return out


func to_dict() -> Dictionary:
	var m := []
	for i in motion.rows.size():
		var r := motion.rows[i]
		m.append([char(motion.kinds[i]), snappedf(r[0], 0.0001), snappedf(r[1], 0.001), snappedf(r[2], 0.001),
			snappedf(r[3], 0.001), snappedf(r[4], 0.01), snappedf(r[5], 0.01), snappedf(r[6], 0.01)])
	return {
		"header": header,
		"result": {"score": session.score, "accuracy": session.accuracy(), "grade": session.grade(),
			"max_combo": session.max_combo, "stats": session.stats, "median_offset": session.median_offset(),
			"mean_offset": session.mean_offset(), "health": session.health, "failed": session.has_failed},
		"notes_cols": ["index", "t", "kind", "lane", "beat", "end_t", "judgement", "hit_at", "side", "call", "heal"],
		"notes": notes_table(),
		"events_cols": ["real", "song_t", "kind", "data"],
		"events": events,
		"frames_cols": ["real", "song_t", "shown_t", "delta", "audio_pos", "since_mix", "paused"],
		"frames": frames,
		"motion_cols": ["kind r=reading t=touch b=bell", "song_t", "ax", "ay", "az", "gx", "gy", "gz"],
		"motion": m,
	}


## Writes the run, replacing the last one. Returns the path written ("" when nothing could be).
func save() -> String:
	var text := JSON.stringify(to_dict())
	for path in save_paths():
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(text)
		f.close()
		saved_path = path
		return path
	saved_path = ""
	return ""


## Where save() tries to write, in order: the phone's Downloads folder (easy to attach from a
## phone), then the game's own folder.
static func save_paths() -> Array[String]:
	var out: Array[String] = []
	if OS.get_name() in ["Android", "iOS"]:
		var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if dl != "":
			out.append(dl.path_join(FILE_NAME))
			# A file left by an earlier install of the game belongs to that install and cannot be
			# overwritten: then a new one, named by the time.
			out.append(dl.path_join(FILE_NAME.get_basename() + "-%d.json" % int(Time.get_unix_time_from_system())))
	out.append("user://" + FILE_NAME)
	return out
