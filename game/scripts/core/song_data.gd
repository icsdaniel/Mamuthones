class_name SongData
extends RefCounted
## One song file (game/data/songs/<id>.json, format in docs/architecture.md).
## Rules code never touches audio: `audio` is only a path.
##
## Additions beyond the architecture doc: key_root, sections, lessons, path, errors,
## from_dict(), load_file(), lesson_range(i), remix_id(), audio_for(remix), offset_for(remix), length_for(remix),
## and the optional arguments of notes() and time_of().

const DIFFICULTIES: Array[String] = ["easy", "medium", "hard", "expert"]

var id := ""
var stop := 0
var kind := "story"   ## story | piazza | tutorial
var bpm := 120.0
var offset := 0.0
var audio := ""
var remix: Dictionary = {}
var length := 0.0
var preview := 0.0
var key_root := 60
var sections: Array = []
var lessons: Array = []
var charts: Dictionary = {}
var path := ""
## Problems found while reading the file (empty when the file is fine).
var errors: Array[String] = []

var _titles: Dictionary = {}


static func load_file(file_path: String) -> SongData:
	var text := FileAccess.get_file_as_string(file_path)
	if text == "":
		var s := SongData.new()
		s.path = file_path
		s.errors.append("cannot read %s" % file_path)
		return s
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		var s := SongData.new()
		s.path = file_path
		s.errors.append("%s: bad JSON at line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return s
	var song := from_dict(json.data)
	song.path = file_path
	return song


static func from_dict(d: Dictionary) -> SongData:
	var s := SongData.new()
	s.id = str(d.get("id", ""))
	s.stop = int(d.get("stop", 0))
	s.kind = str(d.get("kind", "story"))
	s.bpm = float(d.get("bpm", 120.0))
	s.offset = float(d.get("offset", 0.0))
	s.audio = str(d.get("audio", ""))
	var r = d.get("remix", {})
	s.remix = r if r is Dictionary else {}
	s.length = float(d.get("length", 0.0))
	s.preview = float(d.get("preview", 0.0))
	s.key_root = int(d.get("key_root", 60))
	var sec = d.get("sections", [])
	s.sections = sec if sec is Array else []
	var les = d.get("lessons", [])
	s.lessons = les if les is Array else []
	var ti = d.get("title", {})
	if ti is Dictionary:
		s._titles = ti
	elif ti is String:
		s._titles = {"en": ti}
	var ch = d.get("charts", {})
	if ch is Dictionary:
		for k in ch:
			if ch[k] is Array:
				s.charts[str(k)] = ch[k]
	if s.id == "":
		s.errors.append("missing id")
	if s.bpm <= 0.0:
		s.errors.append("%s: bpm must be positive" % s.id)
		s.bpm = 120.0
	if not s.kind in ["story", "piazza", "tutorial"]:
		s.errors.append("%s: unknown kind %s" % [s.id, s.kind])
	return s


func title(lang := "en") -> String:
	if _titles.has(lang):
		return str(_titles[lang])
	if _titles.has("en"):
		return str(_titles["en"])
	return id


## Chart names in play order (easy..expert, then any others such as "piazza").
func difficulties() -> Array[String]:
	var out: Array[String] = []
	for d in DIFFICULTIES:
		if charts.has(d):
			out.append(d)
	for d in charts:
		if not d in out:
			out.append(d)
	return out


## Beat range [from, to) of tutorial lesson i, for Session options from_beat/to_beat.
func lesson_range(i: int) -> Vector2:
	if i < 0 or i >= lessons.size() or not (lessons[i] is Dictionary):
		return Vector2.ZERO
	var b := float(lessons[i].get("b", 0.0))
	return Vector2(b, b + float(lessons[i].get("len", 0.0)))


func has_remix() -> bool:
	return not remix.is_empty() and str(remix.get("id", "")) != ""


func remix_id() -> String:
	return str(remix.get("id", "")) if has_remix() else ""


func offset_for(use_remix := false) -> float:
	return float(remix.get("offset", offset)) if use_remix and has_remix() else offset


func audio_for(use_remix := false) -> String:
	return str(remix.get("audio", audio)) if use_remix and has_remix() else audio


func length_for(use_remix := false) -> float:
	return float(remix.get("length", length)) if use_remix and has_remix() else length


func beat_seconds() -> float:
	return 60.0 / bpm


## Seconds of song time of a beat. The remix shares the beat grid but has its own offset.
func time_of(beat: float, use_remix := false) -> float:
	return offset_for(use_remix) + beat * 60.0 / bpm


func beat_at(t: float, use_remix := false) -> float:
	return (t - offset_for(use_remix)) * bpm / 60.0


## Fresh notes for a chart, sorted by time. Bells alternate up/down through the whole chart
## (bell and ring notes counted together), before any range filter.
## mirror swaps lanes 0 and 2 and flips swipes; from_beat/to_beat keep notes with from <= b < to.
func notes(difficulty: String, use_remix := false, mirror := false, from_beat := -INF, to_beat := INF) -> Array[Note]:
	var out: Array[Note] = []
	var raw: Array = charts.get(difficulty, [])
	var next_up := true
	var off := offset_for(use_remix)
	var spb := 60.0 / bpm
	for item in raw:
		if not (item is Dictionary):
			continue
		var k := str(item.get("k", ""))
		if not Note.KIND_NAMES.has(k):
			continue
		var n := Note.new()
		n.kind = Note.KIND_NAMES[k]
		n.beat = float(item.get("b", 0.0))
		n.t = off + n.beat * spb
		n.end_t = n.t
		n.lane = int(item.get("lane", -1))
		n.call = bool(item.get("call", false))
		n.dir = 1 if int(item.get("dir", 1)) >= 0 else -1
		if n.kind == Note.Kind.HOLD:
			n.end_t = n.t + float(item.get("len", 1.0)) * spb
		elif n.kind == Note.Kind.REST:
			n.end_t = n.t + float(item.get("len", 1.0)) * spb
		if n.is_bell():
			n.up = next_up
			next_up = not next_up
		if n.kind != Note.Kind.SWIPE:
			n.dir = 0
		if not n.uses_lane():
			n.lane = -1
		if mirror:
			if n.lane >= 0:
				n.lane = 2 - n.lane
			n.dir = -n.dir
		if n.beat < from_beat or n.beat >= to_beat:
			continue
		n.index = out.size()
		out.append(n)
	# Stable: equal times keep file order.
	out.sort_custom(func(a: Note, b: Note) -> bool: return a.t < b.t or (a.t == b.t and a.index < b.index))
	for i in out.size():
		out[i].index = i
	return out
