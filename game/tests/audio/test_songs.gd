extends TestCase
## Song files: every file loads, its audio (and remix audio) exists and matches its length,
## and every chart is valid and sorted (the same rules as tools/audio/validate_charts.py, core part).

const SONG_DIR := "res://data/songs"
const DIFFS: Array[String] = ["easy", "medium", "hard", "expert"]
const KINDS: Array[String] = ["step", "hold", "bell", "ring", "swipe", "rest"]
const TOPICS: Array[String] = ["steps", "lanes", "bells", "holds", "still", "swipes", "full"]
const EPS := 0.001


func _songs() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(SONG_DIR):
		if not f.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(SONG_DIR.path_join(f))
		var data = JSON.parse_string(text)
		if check(data is Dictionary, "%s parses as a JSON object" % f):
			out[f] = data
	return out


func test_song_files_load() -> void:
	var songs := _songs()
	check(songs.size() >= 10, "at least 7 story songs and 3 piazza tracks (got %d)" % songs.size())
	var stops := {}
	for f in songs:
		var s: Dictionary = songs[f]
		for key in ["id", "title", "stop", "kind", "bpm", "offset", "audio", "length", "preview", "key_root",
				"sections", "charts"]:
			check(s.has(key), "%s has %s" % [f, key])
		if not s.has("id") or not s.has("kind"):
			continue
		check_eq(f, "%s.json" % s["id"], "file name matches id")
		check(s["kind"] in ["story", "piazza", "tutorial"], "%s kind" % f)
		check(s["title"] is Dictionary and s["title"].has("en") and s["title"].has("it"), "%s title en/it" % f)
		check(float(s["bpm"]) > 40.0 and float(s["bpm"]) < 220.0, "%s bpm" % f)
		check(float(s["offset"]) > 0.0, "%s offset" % f)
		check(int(s["key_root"]) >= 36 and int(s["key_root"]) <= 84, "%s key_root" % f)
		if s["kind"] != "piazza":
			stops[int(s["stop"])] = s["id"]
			var secs: Array = s["sections"]
			check(secs.size() >= 4, "%s has named sections" % f)
		if s["kind"] == "tutorial":
			var topics := []
			for l in s.get("lessons", []):
				topics.append(l["topic"])
			for t in TOPICS:
				check(t in topics, "tutorial lesson %s" % t)
	for n in range(1, 8):
		check(stops.has(n), "story stop %d has a song" % n)


func test_audio_exists_and_matches_length() -> void:
	var songs := _songs()
	for f in songs:
		var s: Dictionary = songs[f]
		var path: String = s.get("audio", "")
		if not check(ResourceLoader.exists(path), "%s audio %s exists" % [f, path]):
			continue
		var stream := load(path) as AudioStream
		if check(stream != null, "%s audio loads" % f):
			check_near(stream.get_length(), float(s["length"]), 0.2, "%s audio length" % f)
			var secs := float(s["length"])
			if s["kind"] == "piazza":
				check(secs >= 60.0 and secs <= 90.0, "%s piazza round lasts 60-90 s (%.1fs)" % [f, secs])
			else:
				check(secs >= 90.0 and secs <= 150.0, "%s song lasts 90-150 s (%.1fs)" % [f, secs])
		if s.has("remix"):
			var r: Dictionary = s["remix"]
			check(ResourceLoader.exists(r.get("audio", "")), "%s remix audio exists" % f)
			check_eq(float(r.get("bpm", 0)), float(s["bpm"]), "%s remix keeps the bpm" % f)
			var rs := load(r.get("audio", "")) as AudioStream
			if check(rs != null, "%s remix loads" % f):
				var last := _last_beat(s)
				var end_t := float(r["offset"]) + last * 60.0 / float(s["bpm"])
				check(end_t <= rs.get_length(), "%s remix is long enough for the charts" % f)
		elif s["kind"] != "piazza":
			check(false, "%s has a remix" % f)


func test_charts_valid_and_sorted() -> void:
	var songs := _songs()
	for f in songs:
		var s: Dictionary = songs[f]
		var charts: Dictionary = s.get("charts", {})
		var names: Array = charts.keys()
		if s.get("kind") == "piazza":
			check_eq(names, ["piazza"], "%s has one piazza chart" % f)
		else:
			for d in DIFFS:
				check(charts.has(d), "%s has %s" % [f, d])
		var counts: Array[int] = []
		for name in names:
			var notes: Array = charts[name]
			check(notes.size() > 0, "%s %s not empty" % [f, name])
			_check_chart(f + ":" + name, s, notes)
			counts.append(notes.size())
		if s.get("kind") != "piazza" and counts.size() == 4:
			check(counts[0] <= counts[1] and counts[1] <= counts[2] and counts[2] <= counts[3],
					"%s note counts rise with difficulty %s" % [f, counts])


func _check_chart(where: String, s: Dictionary, notes: Array) -> void:
	var spb := 60.0 / float(s["bpm"])
	var prev := -1.0
	var last_bell := -100.0
	var sorted_ok := true
	var rests: Array = []
	for n in notes:
		var b := float(n.get("b", -1))
		var k: String = n.get("k", "")
		if b < prev - 1e-9:
			sorted_ok = false
		prev = b
		check(b >= 0.0, "%s beat >= 0" % where)
		check(k in KINDS, "%s kind %s" % [where, k])
		if k in ["step", "hold", "ring"]:
			check(int(n.get("lane", -1)) in [0, 1, 2], "%s lane at b=%s" % [where, b])
		if k == "hold":
			check(float(n.get("len", 0)) >= 0.5, "%s hold length at b=%s" % [where, b])
		if k == "swipe":
			check(int(n.get("dir", 0)) in [1, -1], "%s swipe dir at b=%s" % [where, b])
		if k in ["bell", "ring"]:
			check(b - last_bell >= 0.5 - EPS, "%s bells half a beat apart at b=%s" % [where, b])
			last_bell = b
		if k == "rest":
			rests.append(n)
			check(float(n.get("len", 1)) >= 2.0 - EPS, "%s stand-still lasts 2+ beats at b=%s" % [where, b])
		var end_b := b + (float(n.get("len", 0)) if k in ["hold", "rest"] else 0.0)
		check(float(s["offset"]) + end_b * spb <= float(s["length"]), "%s note inside the audio at b=%s" % [where, b])
	check(sorted_ok, "%s notes sorted by b" % where)
	for r in rests:
		var rb := float(r["b"])
		var re := rb + float(r.get("len", 1))
		for n in notes:
			if n != r and float(n["b"]) >= rb - EPS and float(n["b"]) < re - EPS:
				check(false, "%s note inside the stand-still at b=%s" % [where, rb])


func _last_beat(s: Dictionary) -> float:
	var last := 0.0
	for name in s["charts"]:
		for n in s["charts"][name]:
			last = maxf(last, float(n["b"]) + float(n.get("len", 0)))
	return last
