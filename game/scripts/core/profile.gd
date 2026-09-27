extends Node
## Autoload `Profile`: everything the player keeps on the phone, in a versioned user://profile.cfg.
## A damaged file never crashes the game: it is set aside (profile.corrupt.cfg), the last good copy
## (profile.bak.cfg) is tried, and otherwise the player starts fresh. Writes go to a temp file first
## and are renamed into place, so a crash mid-save cannot leave half a file. Every file starts with
## a SHA-256 of the rest ("; checksum ..."), checked on the raw bytes before parsing, so a file cut
## short or scrambled is detected even when what is left still parses.
##
## API (UI codes against these names):
##   signal changed
##   get_setting(key) / set_setting(key, value)      keys in DEFAULT_SETTINGS
##   has_flag(name) / set_flag(name, on := true)     first-run flags, see FLAGS
##   get_look() -> {mask: Dictionary, fleece, straps, bell_set} / set_look(part, value)
##   piazza_players() -> Array[String] / set_piazza_players(names)
##   record_piazza(name, score) / piazza_best(name) -> int
##   calibration() -> Dictionary ({} = not calibrated) / set_calibration(d)
##   audio_offset() -> float seconds (the "audio_offset" setting)
##   best(song_key, difficulty) -> {} or {score, accuracy, bells, ghost, slam, plays}
##   all_bests() -> {"song:difficulty": entry}
##   daily_best(date_key, difficulty := "") -> {} or {score, song_id, difficulty, bells}
##       (one per difficulty; with no difficulty, the best of that day at any difficulty)
##   record_result(session) -> {prev_best, new_best, bells, unlocked: [{kind, id, part?}], carving_gained}
##   save(), load_profile(path := PATH), reset()
##   plays() -> total finished runs

signal changed

const PATH := "user://profile.cfg"
const VERSION := 1
const DEFAULT_SETTINGS := {
	"language": "",          # "" = follow the phone
	"vibration": true,
	"slam": false,
	"reduced_motion": false,
	"note_speed": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"audio_offset": 0.0,     # seconds, from the tap test or set by hand
	"bell_cue": true,        # the bell cue shown at Easy and Medium
}
const FLAGS: Array[String] = ["language_chosen", "headphones_seen", "calibrated", "latency_tested", "tutorial_done"]
const FLEECES: Array[String] = ["black", "dark_brown"]
const STRAPS: Array[String] = ["natural", "dark"]
const MAX_PIAZZA_PLAYERS := 6
## Allowed ranges for number settings; values outside are clamped.
const RANGES := {
	"audio_offset": Vector2(-0.5, 0.5),
	"note_speed": Vector2(0.5, 3.0),
	"music_volume": Vector2(0.0, 1.0),
	"sfx_volume": Vector2(0.0, 1.0),
}

## Set to another node with submit(board_id, score) to capture ladder submissions (tests).
var leaderboards: Node = null

var path := PATH
var _settings: Dictionary = {}
var _flags: Dictionary = {}
var _look: Dictionary = {}
var _calibration: Dictionary = {}
var _bests: Dictionary = {}
var _daily: Dictionary = {}
var _piazza_players: Array[String] = []
var _piazza_bests: Dictionary = {}
var _plays := 0
var _dirty := false
## What happened on the last load: "new", "ok", "backup", "corrupt", "future".
var load_status := "new"


func _ready() -> void:
	load_profile(path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if _dirty:
			save()


# ---------------------------------------------------------------- settings and flags


func get_setting(key: String) -> Variant:
	return _settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if DEFAULT_SETTINGS.has(key) and typeof(value) != typeof(DEFAULT_SETTINGS[key]):
		if typeof(DEFAULT_SETTINGS[key]) == TYPE_FLOAT and typeof(value) == TYPE_INT:
			value = float(value)
		else:
			push_warning("Profile: setting %s wants %s" % [key, type_string(typeof(DEFAULT_SETTINGS[key]))])
			return
	if RANGES.has(key):
		value = clampf(value, RANGES[key].x, RANGES[key].y)
	if _settings.get(key) == value:
		return
	_settings[key] = value
	_touch()


func audio_offset() -> float:
	return float(get_setting("audio_offset"))


func has_flag(flag: String) -> bool:
	return bool(_flags.get(flag, false))


func set_flag(flag: String, on := true) -> void:
	if has_flag(flag) == on:
		return
	_flags[flag] = on
	_touch()


# ---------------------------------------------------------------- look, calibration, piazza


func get_look() -> Dictionary:
	return _look.duplicate(true)


func set_look(part: String, value: Variant) -> void:
	match part:
		"mask":
			if not (value is Dictionary):
				return
			value = _sanitize_mask(value)
		"fleece":
			if not str(value) in FLEECES:
				return
		"straps":
			if not str(value) in STRAPS:
				return
		"bell_set":
			if not BellSets.is_valid(str(value)):
				return
		_:
			return
	_look[part] = value
	_touch()


func calibration() -> Dictionary:
	return _calibration.duplicate()


func set_calibration(d: Dictionary) -> void:
	_calibration = d.duplicate()
	if not d.is_empty():
		_flags["calibrated"] = true
	_touch()


func piazza_players() -> Array[String]:
	return _piazza_players.duplicate()


func set_piazza_players(names: Array) -> void:
	_piazza_players.clear()
	for n in names:
		var s := str(n).strip_edges().left(24)
		if s != "" and not s in _piazza_players and _piazza_players.size() < MAX_PIAZZA_PLAYERS:
			_piazza_players.append(s)
	_touch()


func record_piazza(player: String, score: int) -> bool:
	if score <= int(_piazza_bests.get(player, -1)):
		return false
	_piazza_bests[player] = score
	_touch()
	return true


func piazza_best(player: String) -> int:
	return int(_piazza_bests.get(player, 0))


# ---------------------------------------------------------------- bests


func best(song_key: String, difficulty: String) -> Dictionary:
	var e = _bests.get(song_key + ":" + difficulty, {})
	return e.duplicate() if e is Dictionary else {}


func all_bests() -> Dictionary:
	return _bests


func daily_best(date_key: String, difficulty := "") -> Dictionary:
	if difficulty != "":
		var e = _daily.get(date_key + "." + difficulty, {})
		if e is Dictionary and not e.is_empty():
			return e.duplicate()
		# Saved before dailies were per difficulty: one entry under the bare date.
		var old = _daily.get(date_key, {})
		return old.duplicate() if old is Dictionary and str(old.get("difficulty", "")) == difficulty else {}
	var top := {}
	for k in _daily:
		var e = _daily[k]
		if (str(k) == date_key or str(k).begins_with(date_key + ".")) and e is Dictionary \
				and (top.is_empty() or int(e.get("score", 0)) > int(top.get("score", 0))):
			top = e
	return top.duplicate()


func plays() -> int:
	return _plays


## Call once when a run ends. Keeps the best score (with its ghost), the best accuracy and bells,
## records the daily, sends ladder scores (never slam, practice or Piazza runs) and reports what the
## run unlocked.
func record_result(session: Session) -> Dictionary:
	var out := {"prev_best": 0, "new_best": false, "bells": session.bells(), "unlocked": [], "carving_gained": 0}
	if session.piazza:
		return out
	var before := Progression.snapshot(self)
	var points_before := Progression.carving_points(self)
	var key := session.song_key() + ":" + session.difficulty
	var practice: bool = session.options.has("from_beat") or session.options.has("to_beat")
	var prev: Dictionary = _bests.get(key, {})
	var prev_score := int(prev.get("score", 0))
	out.prev_best = prev_score
	_plays += 1
	if not practice:
		var e := prev.duplicate()
		e.plays = int(prev.get("plays", 0)) + 1
		if prev.is_empty() or session.score > prev_score:
			out.new_best = true
			e.score = session.score
			e.ghost = Ghost.from_session(session).to_dict()
			e.slam = session.slam
			e.bell_set = session.bell_set
			e.date = Time.get_date_string_from_system(true)
		e.accuracy = maxf(float(prev.get("accuracy", 0.0)), session.accuracy())
		e.bells = maxi(int(prev.get("bells", 0)), session.bells())
		e.max_unison = maxi(int(prev.get("max_unison", 0)), int(session.stats.max_unison))
		_bests[key] = e
		# Only the real procession of that day counts as a daily.
		if Daily.matches(session):
			var d := daily_best(session.daily, session.difficulty)
			if d.is_empty() or session.score > int(d.get("score", 0)):
				_daily[session.daily + "." + session.difficulty] = {"score": session.score, "song_id": session.song_key(), "difficulty": session.difficulty, "bells": session.bells(), "slam": session.slam}
		if session.ladder_ok():
			var lb := _leaderboards()
			if lb != null:
				lb.submit(board_id(session.song_key(), session.difficulty), session.score)
				if Daily.matches(session):
					lb.submit(Daily.board_for(session.daily, session.difficulty), session.score)
	var after := Progression.snapshot(self)
	for k in after:
		if before.has(k):
			continue
		var kind: String = k.get_slice(":", 0)
		var id: String = k.substr(kind.length() + 1)
		if kind == "mask":
			out.unlocked.append({"kind": kind, "part": id.get_slice("/", 0), "id": id.get_slice("/", 1)})
		else:
			out.unlocked.append({"kind": kind, "id": id})
	out.carving_gained = Progression.carving_points(self) - points_before
	_touch()
	save()
	return out


## Board id for a song and difficulty (same as Leaderboards.board_id).
static func board_id(song_key: String, difficulty: String) -> String:
	return "song.%s.%s" % [song_key, difficulty]


# ---------------------------------------------------------------- storage


func reset() -> void:
	_settings = DEFAULT_SETTINGS.duplicate()
	_flags = {}
	_look = {"mask": _default_mask(), "fleece": FLEECES[0], "straps": STRAPS[0], "bell_set": "light"}
	_calibration = {}
	_bests = {}
	_daily = {}
	_piazza_players = []
	_piazza_bests = {}
	_plays = 0
	_dirty = false


func load_profile(p_path := PATH) -> void:
	path = p_path
	reset()
	var tmp := path + ".tmp"
	var main_exists := FileAccess.file_exists(path)
	var cfg := _open_checked(path)
	if cfg != null:
		load_status = "ok"
	else:
		if main_exists:
			_set_aside(path, ".corrupt.cfg")
		# A save interrupted before its final rename leaves a complete .tmp; else the last good copy.
		for candidate in [tmp, _bak(path)]:
			cfg = _open_checked(candidate)
			if cfg != null:
				load_status = "backup"
				push_warning("Profile: %s was damaged or missing; restored %s" % [path, candidate])
				break
		if cfg == null:
			load_status = "corrupt" if main_exists else "new"
			if main_exists:
				push_warning("Profile: %s was damaged; starting a fresh profile" % path)
			changed.emit()
			return
	var version := _version(cfg)
	if version > VERSION:
		# Written by a newer build: keep a copy so a later update can pick it up again.
		load_status = "future"
		_set_aside(path, ".v%d.cfg" % version, true)
	_read(cfg, version)
	if load_status == "backup":
		save()
	changed.emit()


func save() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("meta", "saved", Time.get_datetime_string_from_system(true))
	cfg.set_value("settings", "values", _settings)
	cfg.set_value("flags", "values", _flags)
	cfg.set_value("look", "values", _look)
	cfg.set_value("calibration", "values", _calibration)
	cfg.set_value("bests", "values", _bests)
	cfg.set_value("daily", "values", _daily)
	cfg.set_value("piazza", "players", Array(_piazza_players))
	cfg.set_value("piazza", "bests", _piazza_bests)
	cfg.set_value("stats", "plays", _plays)
	var tmp := path + ".tmp"
	if write_sealed(cfg, tmp) != OK or _open_checked(tmp) == null:
		push_warning("Profile: could not write %s" % tmp)
		return false
	# The main file always exists: the good old copy is copied (not moved) to .bak, then the new
	# file is renamed over the main one in one step. A damaged main file never replaces the .bak.
	var abs_path := ProjectSettings.globalize_path(path)
	if _open_checked(path) != null:
		DirAccess.copy_absolute(abs_path, ProjectSettings.globalize_path(_bak(path)))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if err != OK:
		# Platforms whose rename will not replace an existing file.
		DirAccess.remove_absolute(abs_path)
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	_dirty = false
	return err == OK


const CHECK_PREFIX := "; checksum "

## The file text load_profile() accepts: a first line "; checksum <sha256 of the rest>" and then
## the ConfigFile text. A file that was cut short, edited or scrambled no longer matches, and is
## rejected before it is ever parsed.
static func sealed_text(cfg: ConfigFile) -> String:
	var body := cfg.encode_to_text()
	return CHECK_PREFIX + _hash(body.to_utf8_buffer()) + "\n" + body


## Writes cfg to p as sealed_text(cfg).
static func write_sealed(cfg: ConfigFile, p: String) -> Error:
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(sealed_text(cfg))
	var err := f.get_error()
	f.close()
	return err


static func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


static func _version(cfg: ConfigFile) -> int:
	var v = cfg.get_value("meta", "version", 0)
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else 0


# The file at p, or null when it is missing, fails its checksum (checked on the raw bytes, so a
# damaged file never reaches the parser) or does not parse.
static func _open_checked(p: String) -> ConfigFile:
	if not FileAccess.file_exists(p):
		return null
	var bytes := FileAccess.get_file_as_bytes(p)
	var nl := bytes.find(10)
	if nl < 0:
		return null
	var head := bytes.slice(0, nl).get_string_from_ascii()
	var body := bytes.slice(nl + 1)
	if not head.begins_with(CHECK_PREFIX) or head.substr(CHECK_PREFIX.length()) != _hash(body):
		return null
	var cfg := ConfigFile.new()
	if cfg.parse(body.get_string_from_utf8()) != OK or not cfg.has_section("meta"):
		return null
	return cfg


func _touch() -> void:
	_dirty = true
	changed.emit()
	if is_inside_tree():
		_flush_later.call_deferred()


func _flush_later() -> void:
	if _dirty:
		save()


# Reads every field defensively: a wrong type falls back to the default for that field only.
func _read(cfg: ConfigFile, version: int) -> void:
	_migrate(cfg, version)
	var s = cfg.get_value("settings", "values", {})
	if s is Dictionary:
		for k in DEFAULT_SETTINGS:
			if s.has(k) and (typeof(s[k]) == typeof(DEFAULT_SETTINGS[k]) or (typeof(DEFAULT_SETTINGS[k]) == TYPE_FLOAT and typeof(s[k]) == TYPE_INT)):
				_settings[k] = float(s[k]) if typeof(DEFAULT_SETTINGS[k]) == TYPE_FLOAT else s[k]
				if RANGES.has(k):
					_settings[k] = clampf(_settings[k], RANGES[k].x, RANGES[k].y)
	var f = cfg.get_value("flags", "values", {})
	if f is Dictionary:
		for k in f:
			if f[k] is bool:
				_flags[str(k)] = f[k]
	var l = cfg.get_value("look", "values", {})
	if l is Dictionary:
		for part in ["mask", "fleece", "straps", "bell_set"]:
			if l.has(part):
				set_look(part, l[part])
	var c = cfg.get_value("calibration", "values", {})
	if c is Dictionary:
		_calibration = c
	var b = cfg.get_value("bests", "values", {})
	if b is Dictionary:
		for k in b:
			var e = b[k]
			if e is Dictionary and typeof(e.get("score", null)) in [TYPE_INT, TYPE_FLOAT]:
				_bests[str(k)] = e
	var d = cfg.get_value("daily", "values", {})
	if d is Dictionary:
		for k in d:
			if d[k] is Dictionary:
				_daily[str(k)] = d[k]
	var pp = cfg.get_value("piazza", "players", [])
	if pp is Array:
		set_piazza_players(pp)
	var pb = cfg.get_value("piazza", "bests", {})
	if pb is Dictionary:
		for k in pb:
			if typeof(pb[k]) in [TYPE_INT, TYPE_FLOAT]:
				_piazza_bests[str(k)] = int(pb[k])
	var n = cfg.get_value("stats", "plays", 0)
	_plays = int(n) if typeof(n) in [TYPE_INT, TYPE_FLOAT] else 0
	_dirty = false


## Upgrades older layouts in place, one version at a time. Version 1 is the first release, so
## there is nothing to upgrade yet; a version-less file is read as version 1 field by field.
func _migrate(_cfg: ConfigFile, from_version: int) -> void:
	var v := from_version
	while v < VERSION:
		v += 1


func _leaderboards() -> Node:
	if leaderboards != null:
		return leaderboards
	return get_node_or_null("/root/Leaderboards") if is_inside_tree() else null


static func _bak(p: String) -> String:
	return p.get_basename() + ".bak.cfg"


static func _set_aside(p: String, suffix: String, copy := false) -> void:
	var dst := ProjectSettings.globalize_path(p.get_basename() + suffix)
	var src := ProjectSettings.globalize_path(p)
	DirAccess.remove_absolute(dst)
	if copy:
		DirAccess.copy_absolute(src, dst)
	else:
		DirAccess.rename_absolute(src, dst)


static func _default_mask() -> Dictionary:
	var spec: Variant = Progression._spec()
	if spec != null and Progression._has_func(spec, "default"):
		return spec.default()
	return {}


static func _sanitize_mask(m: Dictionary) -> Dictionary:
	var spec: Variant = Progression._spec()
	if spec != null and Progression._has_func(spec, "sanitize"):
		return spec.sanitize(m)
	return m.duplicate()
