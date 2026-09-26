extends TestCase
## Profile (save, load, versioning, corruption), Leaderboards, Progression, Daily and Ghost.

const ProfileScript := preload("res://scripts/core/profile.gd")
const LeaderboardsScript := preload("res://scripts/core/leaderboards.gd")
const STORY := "res://tests/core/fixtures/story"
const P := "user://core_test_profile.cfg"
const LB := "user://core_test_boards.cfg"


func _clean() -> void:
	for f in [P, P.get_basename() + ".bak.cfg", P.get_basename() + ".corrupt.cfg", P.get_basename() + ".v99.cfg", P + ".tmp", LB]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _fresh_profile() -> Node:
	var p: Node = ProfileScript.new()
	p.load_profile(P)
	return p


func _boards() -> Node:
	var lb: Node = LeaderboardsScript.new()
	lb.load_boards(LB)
	return lb


# Plays a chart with autoplay (perfect) or with only the first `hits` notes hit.
func _play(song_id: String, diff: String, opts := {}, hits := -1) -> Session:
	var song := SongLibrary.get_song(song_id)
	var s := Session.new(song, diff, "light", opts)
	var ap := Autoplay.new(s)
	var t := -1.0
	while not s.is_over(t):
		t += 1.0 / 30.0
		if hits < 0 or s.stats.notes < hits:
			ap.update(t)
		else:
			s.update(t)
	return s


func test_profile_save_load_roundtrip() -> void:
	_clean()
	var p := _fresh_profile()
	check_eq(p.load_status, "new", "no file yet")
	check_eq(p.get_setting("note_speed"), 1.0, "default setting")
	p.set_setting("note_speed", 1.5)
	p.set_setting("language", "it")
	p.set_setting("audio_offset", 0.042)
	p.set_setting("vibration", "yes")     # wrong type: refused
	p.set_flag("tutorial_done")
	p.set_look("fleece", "dark_brown")
	p.set_look("fleece", "neon_pink")     # not a real fleece: refused
	p.set_look("bell_set", "village")
	p.set_calibration({"mode": "gyro", "threshold": 180.0, "axis": 0, "up_sign": 1, "reliable": true})
	p.set_piazza_players(["Anna", "  Bachisio ", "Anna", "", "C", "D", "E", "F", "G"])
	p.record_piazza("Anna", 1200)
	check(p.save(), "saved")
	p.free()
	var q := _fresh_profile()
	check_eq(q.load_status, "ok", "loaded")
	check_eq(q.get_setting("note_speed"), 1.5, "setting kept")
	check_eq(q.get_setting("language"), "it", "language kept")
	check_near(q.audio_offset(), 0.042, 1e-9, "audio offset kept")
	check_eq(q.get_setting("vibration"), true, "wrong type ignored")
	check(q.has_flag("tutorial_done") and q.has_flag("calibrated"), "flags kept (calibration sets calibrated)")
	check(not q.has_flag("latency_tested"), "unset flag")
	check_eq(q.get_look().fleece, "dark_brown", "look kept")
	check_eq(q.get_look().bell_set, "village", "bell set kept")
	check_eq(q.calibration().get("threshold"), 180.0, "calibration kept")
	check_eq(q.piazza_players(), ["Anna", "Bachisio", "C", "D", "E", "F"] as Array[String], "players trimmed, unique, at most 6")
	check_eq(q.piazza_best("Anna"), 1200, "piazza best kept")
	q.free()
	_clean()


func test_profile_corruption_and_versions() -> void:
	_clean()
	# Garbage: fresh profile, file set aside, no crash.
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("[meta\nversion=?? this is not a config file {{{ = ]]")
	f.close()
	var p := _fresh_profile()
	check_eq(p.load_status, "corrupt", "garbage detected")
	check_eq(p.get_setting("note_speed"), 1.0, "fresh defaults")
	check(FileAccess.file_exists(P.get_basename() + ".corrupt.cfg"), "damaged file kept aside")
	# Two saves leave a backup; damaging the main file restores the backup.
	p.set_setting("note_speed", 2.0)
	p.save()
	p.set_setting("note_speed", 1.25)
	p.save()
	p.free()
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_string("truncat")
	f.close()
	var q := _fresh_profile()
	check_eq(q.load_status, "backup", "restored from the last good copy")
	check_eq(q.get_setting("note_speed"), 2.0, "backup holds the previous save")
	q.free()
	# Right syntax, wrong types: each bad field falls back alone.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("settings", "values", {"note_speed": "fast", "music_volume": 0.5})
	cfg.set_value("bests", "values", {"s1:easy": "nonsense", "s2:easy": {"score": 1000, "bells": 2}})
	cfg.set_value("look", "values", [1, 2, 3])
	cfg.set_value("stats", "plays", "many")
	cfg.save(P)
	var w := _fresh_profile()
	check_eq(w.load_status, "ok", "loads")
	check_eq(w.get_setting("note_speed"), 1.0, "bad field -> default")
	check_eq(w.get_setting("music_volume"), 0.5, "good field kept")
	check(w.best("s1", "easy").is_empty(), "bad best dropped")
	check_eq(w.best("s2", "easy").get("score"), 1000, "good best kept")
	check_eq(w.plays(), 0, "bad count -> 0")
	w.free()
	# A file from a newer version: loaded, and a copy kept for later.
	cfg = ConfigFile.new()
	cfg.set_value("meta", "version", 99)
	cfg.set_value("settings", "values", {"note_speed": 1.75})
	cfg.set_value("future", "stuff", {"x": 1})
	cfg.save(P)
	var v := _fresh_profile()
	check_eq(v.load_status, "future", "newer version recognised")
	check_eq(v.get_setting("note_speed"), 1.75, "known fields still read")
	check(FileAccess.file_exists(P.get_basename() + ".v99.cfg"), "newer file copied aside")
	v.save()
	var saved := ConfigFile.new()
	saved.load(P)
	check_eq(saved.get_value("meta", "version"), ProfileScript.VERSION, "saves write the current version")
	v.free()
	# Empty file.
	f = FileAccess.open(P, FileAccess.WRITE)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P.get_basename() + ".bak.cfg"))
	var e := _fresh_profile()
	check(e.load_status == "corrupt" or e.load_status == "new", "empty file handled (%s)" % e.load_status)
	e.free()
	_clean()


func test_progression_unlock_order() -> void:
	_clean()
	SongLibrary.use_directory(STORY)
	var p := _fresh_profile()
	var lb := _boards()
	p.leaderboards = lb
	check_eq(Progression.story_order(), ["s1", "s2", "s3", "s4", "s5", "s6", "s7"] as Array[String], "story order by stop")
	check(Progression.is_unlocked("s1", p), "stop 1 open")
	check(not Progression.is_unlocked("s2", p), "stop 2 locked")
	check(not Progression.is_unlocked("pz", p), "piazza locked before the workshop")
	check(Progression.bell_set_unlocked("light", p), "light from the start")
	check(not Progression.bell_set_unlocked("village", p), "village locked")
	check_eq(Progression.next_stop(p), "s1", "next stop")
	var goals: Array = Progression.next_goals(p)
	check(not goals.is_empty() and goals[0].kind == "song" and goals[0].id == "s2", "first goal: finish s1 to open s2")
	# A failed run unlocks nothing.
	var bad := _play("s1", "easy", {}, 3)
	check_eq(bad.bells(), 0, "3 hits of 19 is no bell")
	var r0: Dictionary = p.record_result(bad)
	check(r0.unlocked.is_empty(), "nothing unlocked")
	check(not Progression.is_unlocked("s2", p), "still locked")
	# Finishing s1 opens s2 and the Piazza.
	var r1: Dictionary = p.record_result(_play("s1", "easy"))
	check(r1.new_best, "new best")
	check_eq(r1.prev_best, bad.score, "previous best reported")
	var kinds: Array = r1.unlocked.map(func(u): return "%s:%s" % [u.kind, u.id])
	check("song:s2" in kinds and "song:pz" in kinds, "s2 and the piazza unlocked (%s)" % [kinds])
	check_eq(r1.carving_gained, 3, "three bells, three carving points")
	check_eq(Progression.carving_points(p), 3, "carving points")
	check(not Progression.is_unlocked("s3", p), "s3 still locked")
	# Clearing in order.
	var r2: Dictionary = p.record_result(_play("s2", "easy"))
	check(r2.unlocked.any(func(u): return u.kind == "bell_set" and u.id == "village"), "village unlocks when stop 3 is reached")
	check(Progression.bell_set_unlocked("village", p), "village open")
	check(not Progression.remix_unlocked("s2", p), "no remix from easy")
	var r3: Dictionary = p.record_result(_play("s2", "hard"))
	check(r3.unlocked.any(func(u): return u.kind == "remix" and u.id == "s2_remix"), "remix unlocks at hard with 2+ bells")
	check(Progression.is_unlocked("s2_remix", p), "remix id is playable")
	for id in ["s3", "s4", "s5"]:
		p.record_result(_play(id, "medium"))
	check(Progression.bell_set_unlocked("full", p), "full load at stop 6")
	check_eq(Progression.highest_stop(p), 6, "at stop 6")
	check_eq(Progression.next_stop(p), "s6", "next stop is s6")
	# Remix bests are their own.
	var rr: Dictionary = p.record_result(_play("s2", "hard", {"remix": true}))
	check(rr.new_best, "first remix run is a best")
	check(not p.best("s2_remix", "hard").is_empty(), "remix best stored under the remix id")
	check_eq(p.best("s2", "hard").get("plays"), 1, "base song best untouched")
	# Practice runs do not count.
	var before: Dictionary = p.all_bests().duplicate(true)
	p.record_result(_play("s6", "easy", {"from_beat": 0, "to_beat": 8}))
	check(not Progression.is_unlocked("s7", p), "a lesson does not clear a stop")
	check_eq(p.all_bests().size(), before.size(), "practice does not add bests")
	# Mask options follow Art's MaskSpec when present.
	var spec = Progression._spec()
	if spec != null:
		var part: String = spec.PARTS[0]
		var opts: Array = spec.options(part)
		check(Progression.mask_option_unlocked(part, opts[0], p), "first option is free")
		check(not Progression.mask_option_unlocked(part, "no_such_option", p), "unknown option locked")
		for o in opts:
			var req: Dictionary = spec.requirement(part, o)
			var want: bool = opts.find(o) == 0 or (Progression.highest_stop(p) >= int(req.get("stop", 1)) and Progression.carving_points(p) >= int(req.get("cost", 0)))
			check_eq(Progression.mask_option_unlocked(part, o, p), want, "mask %s/%s follows its requirement" % [part, o])
	else:
		check(not Progression.mask_option_unlocked("eyes", "x", p), "no MaskSpec: nothing beyond defaults")
	# Leaderboards got the non-practice runs.
	check(lb.best(lb.board_id("s1", "easy")) > 0, "s1 easy sent to the ladder")
	check_eq(lb.best(lb.board_id("s6", "easy")), 0, "practice not sent")
	p.free()
	lb.free()
	SongLibrary.reset()
	_clean()


func test_slam_and_daily_results() -> void:
	_clean()
	SongLibrary.use_directory(STORY)
	var p := _fresh_profile()
	var lb := _boards()
	p.leaderboards = lb
	var s := _play("s1", "easy", {"slam": true})
	var r: Dictionary = p.record_result(s)
	check(r.new_best, "slam runs keep bests")
	check_eq(p.best("s1", "easy").get("slam"), true, "and are marked")
	check(Progression.is_unlocked("s2", p), "slam runs still unlock (accessibility)")
	check_eq(lb.best(lb.board_id("s1", "easy")), 0, "slam runs stay off the global ladder")
	var today := {"year": 2026, "month": 9, "day": 26}
	var d := Daily.for_date(today)
	var ds := _play(d.song_id, d.difficulty, Daily.session_options(today))
	p.record_result(ds)
	check_eq(p.daily_best("2026-09-26").get("score"), ds.score, "daily best kept by date")
	check_eq(lb.best(Daily.board_id()), ds.score, "daily ladder gets it")
	p.free()
	lb.free()
	SongLibrary.reset()
	_clean()


func test_daily_determinism() -> void:
	SongLibrary.use_directory(STORY)
	var a := Daily.for_date({"year": 2026, "month": 2, "day": 17})
	SongLibrary.use_directory(STORY)     # reload from disk
	var b := Daily.for_date({"year": 2026, "month": 2, "day": 17})
	check_eq(a, b, "same date, same procession")
	check_eq(a.key, "2026-02-17", "date key")
	check(a.song_id in ["s2", "s3", "s4", "s5", "s6", "s7"], "a story song, not the tutorial (%s)" % a.song_id)
	var songs := {}
	var mirrors := {}
	var diffs := {}
	var prev := ""
	var repeats := 0
	var date := {"year": 2026, "month": 1, "day": 1}
	for i in 120:
		var d := Daily.for_date(date)
		songs[d.song_id] = true
		mirrors[d.mirror] = true
		diffs[d.difficulty] = true
		if d.song_id == prev:
			repeats += 1
		prev = d.song_id
		date = Daily._shift(date, 1)
	check_eq(songs.size(), 6, "every story song comes up")
	check_eq(mirrors.size(), 2, "mirrored and not")
	check_eq(diffs.size(), 4, "all four difficulties")
	check_eq(repeats, 0, "never the same song two days running")
	SongLibrary.reset()


func test_daily_hash_is_pinned() -> void:
	# Pinned values: if these change, players on different versions would get different dailies.
	check_eq(Daily._fnv(""), _expected_fnv(""), "empty")
	check_eq(Daily._fnv("2026-09-26"), _expected_fnv("2026-09-26"), "a date")


# Independent reimplementation of the hash, to pin it.
func _expected_fnv(text: String) -> int:
	var h := 0x811c9dc5
	for c in text.to_utf8_buffer():
		h = ((h ^ c) * 0x01000193) % 4294967296
	h ^= h >> 16
	h = (h * 2146121005) % 4294967296
	h ^= h >> 15
	h = (h * 2221713035) % 4294967296
	h ^= h >> 16
	return h


func test_ghost() -> void:
	var song := SongData.load_file("res://tests/core/fixtures/basic.json")
	var s := Session.new(song, "easy")
	var ap := Autoplay.new(s)
	var t := 0.0
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)
	var g := Ghost.from_session(s)
	check_eq(g.score_at(0.0), 0, "nothing before the first note")
	check_eq(g.score_at(1.0), 300, "first perfect at 1.0 s")
	check_eq(g.score_at(1.999), 300, "holds between hits")
	check_eq(g.score_at(2.0), 600, "second hit")
	check_eq(g.score_at(999.0), s.score, "final score at the end")
	check_eq(g.final_score, s.score, "final")
	var back := Ghost.from_dict(g.to_dict())
	for tt in [0.5, 1.0, 3.3, 7.77, 12.0, 100.0]:
		check_eq(back.score_at(tt), g.score_at(tt), "round trip at %s" % tt)
	# Through a ConfigFile, as Profile stores it.
	var cfg := ConfigFile.new()
	cfg.set_value("x", "g", g.to_dict())
	var cfg2 := ConfigFile.new()
	cfg2.parse(cfg.encode_to_text())
	check_eq(Ghost.from_dict(cfg2.get_value("x", "g")).score_at(7.77), g.score_at(7.77), "survives saving")
	check_eq(g.delta_at(2.0, 900), 300, "ahead by 300 points")
	check_near(g.lead_seconds(300, 1.5), -0.5, 1e-6, "reached 300 half a second after the ghost")
	check_near(g.lead_seconds(600, 1.5), 0.5, 1e-6, "reached 600 half a second before the ghost")
	check(Ghost.from_dict({"t": "junk"}).is_empty(), "bad data gives an empty ghost")
	check_eq(Ghost.from_dict({}).score_at(5.0), 0, "empty ghost scores 0")


func test_leaderboards_local() -> void:
	_clean()
	var lb := _boards()
	check(lb.available(), "local ladder always available")
	check(not lb.online(), "offline")
	var id: String = lb.board_id("fires", "hard")
	check_eq(id, "song.fires.hard", "board id")
	check_eq(lb.submit(id, 500), 1, "first score rank 1")
	check_eq(lb.submit(id, 800), 1, "better score takes the top")
	check_eq(lb.submit(id, 600), 2, "in between")
	for i in 20:
		lb.submit(id, 1000 + i)
	check_eq(lb.local_scores(id).size(), 10, "keeps a top 10")
	check_eq(lb.submit(id, 1), 0, "too low for the top 10")
	check_eq(lb.best(id), 1019, "best")
	var shown := []
	lb.show_requested.connect(func(b): shown.append(b))
	lb.show(id)
	check_eq(shown, [id], "offline show asks the UI to show the local ladder")
	var again := _boards()
	check_eq(again.best(id), 1019, "persisted")
	# An online backend gets the same scores.
	var fake := FakeBackend.new()
	again.set_backend(fake)
	again.platform_ids = {id: "grp.fires.hard"}
	again.submit(id, 5)
	again.show(id)
	check_eq(fake.sent, [["grp.fires.hard", 5]], "sent online with the platform id")
	check_eq(fake.shown, ["grp.fires.hard"], "platform ladder shown")
	lb.free()
	again.free()
	_clean()


class FakeBackend:
	var sent := []
	var shown := []

	func available() -> bool:
		return true

	func submit(id: String, score: int) -> void:
		sent.append([id, score])

	func show(id: String) -> void:
		shown.append(id)


func test_song_library() -> void:
	SongLibrary.use_directory(STORY)
	check_eq(SongLibrary.all().size(), 8, "7 stops and a piazza track")
	check_eq(SongLibrary.story().size(), 7, "story includes the tutorial")
	check_eq(SongLibrary.story()[0].kind, "tutorial", "the workshop first")
	check_eq(SongLibrary.piazza().size(), 1, "one piazza track")
	check_eq(SongLibrary.get_song("s3_remix"), SongLibrary.get_song("s3"), "remix id gives the base song")
	check(SongLibrary.is_remix_id("s3_remix") and not SongLibrary.is_remix_id("s3"), "is_remix_id")
	check_eq(SongLibrary.get_song("nope"), null, "unknown id")
	SongLibrary.use_directory("res://tests/core/fixtures/broken")
	var songs := SongLibrary.all()
	check_eq(songs.size(), 1, "only the good file loads")
	check_eq(SongLibrary.load_errors.size(), 3, "truncated, duplicate and negative-bpm files reported (%s)" % [SongLibrary.load_errors])
	var ok := SongLibrary.get_song("ok")
	check_eq(ok.notes("easy").size(), 2, "unknown kinds and junk entries are skipped")
	check_eq(ok.notes("missing").size(), 0, "a missing chart has no notes")
	SongLibrary.reset()
