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


## Story stops in order, one song a stop: its recorded original where it has one, else its own song.
## The first, synthesized versions of the stops are gone from the story and free play where a stop has
## recordings (Daniele, 2026-10-28: "keep Suno and their remixes only"); the tutorial lives in the
## Tutorial screen only. The other versions (the remix) are on the stop's card (versions()).
static func story() -> Array[SongData]:
	_ensure()
	var out: Array[SongData] = []
	for stop in _stops():
		var lead := _lead(at_stop(stop))
		if lead != null:
			out.append(lead)
	return out


## The songs a stop's card offers, its lead (story()) first: the recorded original, then the remix.
## A stop without recordings has only its own song (whose built-in remix stays a chip).
static func versions(song: SongData) -> Array[SongData]:
	_ensure()
	if song == null:
		return []
	var here := at_stop(song.stop)
	if not here.has(song):
		return [song]
	var lead := _lead(here)
	if lead == null:
		return [song]
	var out: Array[SongData] = [lead]
	var recorded := here.any(func(x: SongData) -> bool: return x.version != "")
	for v in ["original", "remix", ""]:
		for x in here:
			if x in out or x.version != v or x.kind != "story":
				continue
			if v == "" and recorded:
				continue   # the synthesized first version a recording replaced
			out.append(x)
	return out


## Every song a player can pick in free play, stop by stop: each stop's versions().
static func catalogue() -> Array[SongData]:
	var out: Array[SongData] = []
	for lead in story():
		out.append_array(versions(lead))
	return out


## The Tutorial screen's lessons' song (kind "tutorial"), or null.
static func tutorial() -> SongData:
	_ensure()
	for s in _songs:
		if s.kind == "tutorial":
			return s
	return null


static func _stops() -> Array[int]:
	var stops: Array[int] = []
	for s in _songs:
		if s.kind == "story" and not s.stop in stops:
			stops.append(s.stop)
	stops.sort()
	return stops


## Every story song at stop `stop` (placeholders included), by id.
static func at_stop(stop: int) -> Array[SongData]:
	_ensure()
	var out: Array[SongData] = []
	for s in _songs:
		if s.kind == "story" and s.stop == stop:
			out.append(s)
	out.sort_custom(func(a: SongData, b: SongData) -> bool: return a.id < b.id)
	return out


static func _lead(here: Array[SongData]) -> SongData:
	for want in ["original", ""]:
		for x in here:
			if x.kind == "story" and x.version == want:
				return x
	return here[0] if not here.is_empty() else null


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
