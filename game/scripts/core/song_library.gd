class_name SongLibrary
extends RefCounted
## All songs in game/data/songs/*.json, loaded once and cached.
## Tests can point it at another folder with use_directory() (call reset() afterwards to go back).
## Note for export: the preset must include "data/songs/*.json" (JSON is not a resource type).

const DEFAULT_DIR := "res://data/songs"

static var _dir := DEFAULT_DIR
static var _songs: Array[SongData] = []
static var _by_id: Dictionary = {}
static var _loaded := false
## Files that failed to load, as messages (the songs themselves are skipped).
static var load_errors: Array[String] = []


static func use_directory(dir: String) -> void:
	_dir = dir
	_loaded = false


static func reset() -> void:
	_dir = DEFAULT_DIR
	_loaded = false


static func all() -> Array[SongData]:
	_ensure()
	return _songs.duplicate()


## A song by id. A remix id returns its base song (play it with Session option remix: true).
static func get_song(id: String) -> SongData:
	_ensure()
	return _by_id.get(id, null)


static func is_remix_id(id: String) -> bool:
	var s := get_song(id)
	return s != null and s.id != id


## Story stops in order (the tutorial is stop 1).
static func story() -> Array[SongData]:
	_ensure()
	var out: Array[SongData] = []
	for s in _songs:
		if s.kind == "story" or s.kind == "tutorial":
			out.append(s)
	out.sort_custom(func(a: SongData, b: SongData) -> bool: return a.stop < b.stop or (a.stop == b.stop and a.id < b.id))
	return out


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_songs.clear()
	_by_id.clear()
	load_errors.clear()
	var files := Array(DirAccess.get_files_at(_dir))
	files.sort()
	for f in files:
		if not str(f).ends_with(".json"):
			continue
		var s := SongData.load_file(_dir.path_join(f))
		if not s.errors.is_empty() or s.id == "":
			load_errors.append_array(s.errors)
			continue
		if _by_id.has(s.id):
			load_errors.append("duplicate song id %s in %s" % [s.id, f])
			continue
		_songs.append(s)
		_by_id[s.id] = s
		if s.has_remix():
			_by_id[s.remix_id()] = s
	_songs.sort_custom(func(a: SongData, b: SongData) -> bool: return a.stop < b.stop or (a.stop == b.stop and a.id < b.id))
