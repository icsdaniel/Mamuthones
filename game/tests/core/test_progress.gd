extends TestCase
## Profile (save, load, versioning, corruption), Leaderboards, Progression and Ghost.

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
	ProfileScript.write_sealed(cfg, P)
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
	ProfileScript.write_sealed(cfg, P)
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
	# Every stop is open from the start; the story still starts at stop 2 (the tutorial is optional).
	for id in Progression.story_order():
		check(Progression.is_unlocked(id, p), "%s open from the start" % id)
	check_eq(Progression.highest_stop(p), 2, "the story is at stop 2")
	check(Progression.bell_set_unlocked("light", p), "light from the start")
	check(not Progression.bell_set_unlocked("village", p), "village locked")
	check_eq(Progression.next_stop(p), "s2", "next stop skips the optional tutorial")
	var goals: Array = Progression.next_goals(p)
	check(not goals.is_empty() and goals[0].kind == "bell_set" and goals[0].id == "village", "first goal: the village bells (%s)" % [goals])
	# A failed run unlocks nothing.
	var bad := _play("s1", "easy", {}, 3)
	check(bad.grade_rank() < Progression.CLEAR_GRADE, "3 hits of 19 is below a D (%s)" % bad.grade())
	var r0: Dictionary = p.record_result(bad)
	check(r0.unlocked.is_empty(), "nothing unlocked")
	check_eq(Progression.highest_stop(p), 2, "the story has not moved")
	# Finishing s1 opens nothing new: s2 was already open.
	var r1: Dictionary = p.record_result(_play("s1", "easy"))
	check(r1.new_best, "new best")
	check_eq(r1.prev_best, bad.score, "previous best reported")
	var kinds: Array = r1.unlocked.map(func(u): return "%s:%s" % [u.kind, u.id])
	check(not "song:s2" in kinds, "s2 was open already (%s)" % [kinds])
	check_eq(r1.grade, Session.RANK_SPLUS, "a perfect run is graded S+")
	check_eq(r1.carving_gained, 3, "an S+ gives three carving points")
	check_eq(Progression.carving_points(p), 3, "carving points")
	check_eq(Progression.highest_stop(p), 2, "the optional tutorial does not move the story past stop 2")
	# Clearing in order.
	var r2: Dictionary = p.record_result(_play("s2", "easy"))
	check(r2.unlocked.any(func(u): return u.kind == "bell_set" and u.id == "village"), "village unlocks when stop 3 is reached")
	check(Progression.bell_set_unlocked("village", p), "village open")
	check(not Progression.remix_unlocked("s2", p), "no remix from easy")
	var r3: Dictionary = p.record_result(_play("s2", "hard"))
	check(r3.unlocked.any(func(u): return u.kind == "remix" and u.id == "s2_remix"), "remix unlocks at hard with a B or better")
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
	check(not Progression.cleared("s6", p), "a lesson does not clear a stop")
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


func test_slam_results() -> void:
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
	p.free()
	lb.free()
	SongLibrary.reset()
	_clean()


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


func test_grades_from_old_saves_and_thresholds() -> void:
	check_eq(Progression.entry_grade({"bells": 2, "accuracy": 0.86}), Session.RANK_B, "an old best gets the grade its accuracy earns")
	check_eq(Progression.entry_grade({"accuracy": 0.99}), Session.RANK_S, "an old best is never S+ (no full combo known)")
	check_eq(Progression.entry_grade({"grade": 7}), Session.RANK_SPLUS, "a saved grade is kept")
	check_eq(Progression.entry_grade({}), 0, "nothing saved is F")
	check_eq(Progression.CLEAR_GRADE, Session.GRADES.find("D"), "a D clears a stop")
	check_eq(Progression.REMIX_GRADE, Session.GRADES.find("B"), "a B at Hard opens the remix")
	check_eq(Progression.GRADE_POINTS.size(), Session.GRADES.size(), "carving points for every grade")


func test_song_library() -> void:
	SongLibrary.use_directory(STORY)
	check_eq(SongLibrary.all().size(), 7, "7 stops")
	check_eq(SongLibrary.story().size(), 7, "story includes the tutorial")
	check_eq(SongLibrary.story()[0].kind, "tutorial", "the workshop first")
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


func test_profile_crash_safety_and_checksum() -> void:
	_clean()
	var p := _fresh_profile()
	p.set_setting("note_speed", 1.5)
	p.save()
	p.set_setting("note_speed", 1.75)
	p.save()
	p.free()
	check(FileAccess.file_exists(P.get_basename() + ".bak.cfg"), "the previous save is kept as .bak")
	# A crash after writing .tmp but before it replaced the main file.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(P), ProjectSettings.globalize_path(P + ".tmp"))
	var q := _fresh_profile()
	check_eq(q.load_status, "backup", "main file missing: recovered")
	check_eq(q.get_setting("note_speed"), 1.75, "from the complete .tmp, the newest save")
	check(FileAccess.file_exists(P), "and written back as the main file")
	q.free()
	# Parses, but cut short: the checksum catches it and the .bak is used.
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("[meta]\nversion=1\n")
	f.close()
	var r := _fresh_profile()
	check_eq(r.load_status, "backup", "truncated-but-parsable file detected")
	check(r.get_setting("note_speed") in [1.5, 1.75], "a good copy restored")
	r.free()
	# A damaged main file is never copied over the good .bak.
	var good_bak := FileAccess.get_file_as_string(P.get_basename() + ".bak.cfg")
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_string("[meta]\nversion=1\nchecksum=\"nope\"\n")
	f.close()
	var s: Node = ProfileScript.new()
	s.path = P
	s.set_setting("note_speed", 2.5)
	s.save()
	check_eq(FileAccess.get_file_as_string(P.get_basename() + ".bak.cfg"), good_bak, ".bak untouched by a save over a damaged file")
	s.free()
	# A real save cut short at any point: never trusted, never parsed.
	var whole := FileAccess.get_file_as_bytes(P)
	var caught := 0
	for cut in [whole.size() - 1, whole.size() - 20, whole.size() >> 1, 80, 70, 10]:
		f = FileAccess.open(P, FileAccess.WRITE)
		f.store_buffer(whole.slice(0, cut))
		f.close()
		if ProfileScript._open_checked(P) == null:
			caught += 1
	check_eq(caught, 6, "every truncation of a sealed file is caught")
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_buffer(whole)
	f.close()
	check(ProfileScript._open_checked(P) != null, "the whole file still passes")
	# An edited value breaks the checksum too.
	var t := _fresh_profile()
	t.save()
	t.free()
	var text := FileAccess.get_file_as_string(P).replace("2.5", "9.5")
	f = FileAccess.open(P, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var u := _fresh_profile()
	check(u.load_status != "ok", "hand-edited file is not trusted (%s)" % u.load_status)
	u.free()
	_clean()


func test_bell_cue_setting() -> void:
	_clean()
	var p := _fresh_profile()
	check_eq(p.get_setting("bell_cue"), true, "the bell cue is on by default")
	p.set_setting("bell_cue", false)
	p.save()
	p.free()
	var q := _fresh_profile()
	check_eq(q.get_setting("bell_cue"), false, "turning it off is saved")
	q.set_setting("bell_cue", "no")
	check_eq(q.get_setting("bell_cue"), false, "a wrong type is refused")
	q.free()
	_clean()


func test_profile_settings_are_clamped() -> void:
	_clean()
	var p := _fresh_profile()
	p.set_setting("audio_offset", 3.0)
	check_eq(p.get_setting("audio_offset"), 0.5, "audio offset at most +0.5 s")
	p.set_setting("audio_offset", -2.0)
	check_eq(p.get_setting("audio_offset"), -0.5, "at least -0.5 s")
	p.set_setting("note_speed", 0.0)
	check_eq(p.get_setting("note_speed"), 0.5, "note speed floor")
	p.set_setting("music_volume", 7)
	check_eq(p.get_setting("music_volume"), 1.0, "volume at most 1")
	p.set_setting("sfx_volume", -1.0)
	check_eq(p.get_setting("sfx_volume"), 0.0, "volume at least 0")
	p.free()
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("settings", "values", {"audio_offset": 99.0, "note_speed": 1.2})
	ProfileScript.write_sealed(cfg, P)
	var q := _fresh_profile()
	check_eq(q.get_setting("audio_offset"), 0.5, "clamped on load too")
	check_eq(q.get_setting("note_speed"), 1.2, "good values kept")
	q.free()
	_clean()


func test_profile_fuzz() -> void:
	# Random damage to a real save: never a crash, and never a half-read profile — either the
	# checksum passes and every value is the saved one, or a fresh/backup profile is used.
	_clean()
	SongLibrary.use_directory(STORY)
	var p := _fresh_profile()
	p.leaderboards = _boards()
	p.set_setting("note_speed", 1.25)
	p.set_flag("tutorial_done")
	p.record_result(_play("s2", "easy"))
	p.save()
	var good: PackedByteArray = FileAccess.get_file_as_bytes(P)
	p.leaderboards.free()
	p.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var statuses := {}
	for i in 150:
		var bytes: PackedByteArray = good.duplicate()
		match i % 4:
			0:
				for k in 1 + rng.randi() % 8:
					bytes[rng.randi() % bytes.size()] = rng.randi() % 256
			1:
				bytes = bytes.slice(0, rng.randi() % bytes.size())
			2:
				var at := rng.randi() % bytes.size()
				bytes = bytes.slice(0, at) + bytes.slice(mini(bytes.size(), at + 1 + rng.randi() % 40))
			3:
				var at2 := rng.randi() % bytes.size()
				bytes[at2] = [48, 49, 57, 34, 123, 125][rng.randi() % 6]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P.get_basename() + ".bak.cfg"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P + ".tmp"))
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		var q := _fresh_profile()
		statuses[q.load_status] = statuses.get(q.load_status, 0) + 1
		if q.load_status == "ok":
			check(q.get_setting("note_speed") == 1.25 and q.has_flag("tutorial_done") and not q.best("s2", "easy").is_empty(), "fuzz %d: a trusted file reads back exactly" % i)
		else:
			check(q.load_status in ["corrupt", "new"], "fuzz %d: otherwise a fresh profile (%s)" % [i, q.load_status])
			check_eq(q.get_setting("note_speed"), 1.0, "fuzz %d: fresh defaults" % i)
		q.free()
	check(statuses.get("corrupt", 0) > 100, "most damage is detected (%s)" % [statuses])
	SongLibrary.reset()
	_clean()


func test_tutorial_flag_clears_the_workshop() -> void:
	_clean()
	SongLibrary.use_directory(STORY)
	var p := _fresh_profile()
	check(Progression.is_unlocked("s2", p), "stop 2 open at first: the tutorial is optional")
	check(not Progression.cleared("s1", p), "the Workshop is not finished yet")
	p.set_flag("tutorial_done")
	check(Progression.cleared("s1", p), "finishing the tutorial finishes the Workshop")
	p.free()
	SongLibrary.reset()
	_clean()

