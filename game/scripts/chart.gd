class_name Chart
extends RefCounted
## Reads songs.json and turns chart strings into notes.
##
## Charts use an eighth-note grid, 8 symbols per bar:
##   L M R  step on that button (on an odd eighth it is an off-beat Issohadore call)
##   l m r  hold that button; each following '=' extends the hold by one eighth
##   X      bell: tilt the phone. Bells always alternate up, down, up, down.
##   > <    rope swipe across the buttons, left-to-right or right-to-left
##   -      stand still        .  nothing

const SONGS_PATH := "res://data/songs.json"
const STEPS := "LMR"
const HOLDS := "lmr"


static func load_songs(path := SONGS_PATH) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("songs"):
		push_error("Could not read songs from %s" % path)
		return []
	return data.songs


static func eighth(song: Dictionary) -> float:
	return 60.0 / float(song.bpm) / 2.0


## Seconds from the first chart eighth to the end of the last bar.
static func length_seconds(song: Dictionary) -> float:
	return song.chart.size() * 4 * 60.0 / float(song.bpm)


## Returns a list of problems with a song's chart; empty when it is fine.
static func validate(song: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for i in song.chart.size():
		var bar: String = song.chart[i]
		if bar.length() != 8:
			problems.append("%s bar %d has %d symbols, not 8" % [song.id, i + 1, bar.length()])
		for c in bar:
			if not c in "LMRlmrX><-.=":
				problems.append("%s bar %d has unknown symbol '%s'" % [song.id, i + 1, c])
	var cells := "".join(PackedStringArray(song.chart))
	for i in cells.length():
		if cells[i] == "=" and (i == 0 or not (cells[i - 1] == "=" or cells[i - 1] in HOLDS)):
			problems.append("%s: '=' at eighth %d does not follow a hold" % [song.id, i])
	return problems


static func parse(song: Dictionary) -> Array[Note]:
	var cells := "".join(PackedStringArray(song.chart))
	var start := float(song.first_beat)
	var spe := eighth(song)
	var out: Array[Note] = []
	var bell_up := true
	for i in cells.length():
		var c := cells[i]
		var t := start + i * spe
		if c in STEPS:
			var n := Note.new(Note.Kind.STEP, t)
			n.lane = STEPS.find(c)
			n.call = i % 2 == 1
			out.append(n)
		elif c in HOLDS:
			var j := i
			while j + 1 < cells.length() and cells[j + 1] == "=":
				j += 1
			var n := Note.new(Note.Kind.HOLD, t)
			n.lane = HOLDS.find(c)
			n.end_t = start + j * spe
			out.append(n)
		elif c == "X":
			var n := Note.new(Note.Kind.BELL, t)
			n.up = bell_up
			bell_up = not bell_up
			out.append(n)
		elif c == ">" or c == "<":
			var n := Note.new(Note.Kind.SWIPE, t)
			n.right = c == ">"
			out.append(n)
		elif c == "-":
			out.append(Note.new(Note.Kind.REST, t))
	return out
