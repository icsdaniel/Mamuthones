extends TestCase
## Chart readability rules, and every real song in game/data/songs: loads, passes the rules, and
## Autoplay gets 100 % accuracy on every chart (and on the remix timing).


func _song(chart: Array, kind := "story", diff := "hard") -> SongData:
	return SongData.from_dict({"id": "c", "kind": kind, "bpm": 120, "offset": 1.0, "charts": {diff: chart}})


func _problems(chart: Array, kind := "story", diff := "hard") -> Array[String]:
	return ChartRules.check(_song(chart, kind, diff), diff)


func test_fixtures_pass() -> void:
	for f in ["res://tests/core/fixtures/story/s1.json", "res://tests/core/fixtures/story/s4.json", "res://tests/core/fixtures/story/pz.json"]:
		var s := SongData.load_file(f)
		check_eq(ChartRules.check_song(s), [] as Array[String], "%s is clean" % f)


# Leaves out the eighth-grid problem (Medium and Hard keep to beats and half-beats), for checks about
# something else that use finer positions.
func _not_grid(p: String) -> bool:
	return not "sixteenths are Expert" in p


func test_rules_catch_problems() -> void:
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.75, "k": "step", "lane": 2}]).any(func(p): return "sixteenths are Expert" in p), "no sixteenths at hard")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.75, "k": "step", "lane": 2}], "story", "expert").is_empty(), "sixteenths at expert")
	check(_problems([{"b": 0, "k": "bell"}, {"b": 0.25, "k": "bell"}]).any(func(p): return "half a beat" in p), "bells too close")
	check(_problems([{"b": 0, "k": "bell"}, {"b": 0.5, "k": "bell"}]).is_empty(), "bells half a beat apart are fine")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0, "k": "step", "lane": 1}, {"b": 0, "k": "step", "lane": 2}]).any(func(p): return "thumbs" in p), "three steps at once")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "step", "lane": 0}]).any(func(p): return "thumb too fast" in p), "one thumb twice in an eighth at hard")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "step", "lane": 0}], "story", "expert").is_empty(), "sixteenths are fine at expert")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "step", "lane": 1}, {"b": 0.5, "k": "step", "lane": 0}]).filter(_not_grid).is_empty(), "lane 1 goes to the free thumb")
	check(_problems([{"b": 0, "k": "hold", "lane": 1, "len": 2}, {"b": 1, "k": "step", "lane": 1}]).any(func(p): return "under a hold" in p), "note under a hold")
	check(_problems([{"b": 0, "k": "hold", "lane": 0, "len": 2}, {"b": 1, "k": "step", "lane": 0}, {"b": 1, "k": "step", "lane": 2}]).size() > 0, "a hold keeps its thumb busy")
	check(_problems([{"b": 0, "k": "rest", "len": 4}, {"b": 2, "k": "bell"}]).any(func(p): return "stand-still" in p), "bell in a stand-still")
	check(_problems([{"b": 2, "k": "bell"}, {"b": 0, "k": "step", "lane": 0}]).any(func(p): return "sorted" in p), "unsorted")
	check(_problems([{"b": 0, "k": "rest", "len": 1.5}]).any(func(p): return "at least 2 beats" in p), "a stand-still shorter than 2 beats")
	check(_problems([{"b": 0, "k": "rest"}]).any(func(p): return "at least 2 beats" in p), "a stand-still without len is 1 beat: too short")
	check(_problems([{"b": 0, "k": "rest", "len": 2}]).is_empty(), "2 beats is fine")
	check(_problems([{"b": 0, "k": "step", "lane": 3}]).any(func(p): return "lane" in p), "bad lane")
	check(_problems([{"b": 0, "k": "stomp"}]).any(func(p): return "lane" in p), "a stomp needs a lane")
	check(_problems([{"b": 0, "k": "hold", "lane": 0, "len": 2}, {"b": 1, "k": "stomp", "lane": 2}], "story", "hard").any(func(p): return "a stomp needs both" in p), "a stomp needs both thumbs free")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0, "k": "stomp", "lane": 2}], "story", "hard").any(func(p): return "free thumbs" in p), "nothing else on a stomp's beat")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "stomp", "lane": 1}], "story", "hard").any(func(p): return "too fast for the stomp" in p), "both thumbs rested before a stomp")
	check(_problems([{"b": 0, "k": "jump"}]).any(func(p): return "unknown" in p), "unknown kind")
	check(_problems([{"b": 0, "k": "stomp", "lane": 1}], "story", "easy").any(func(p): return "not used at easy" in p), "no stomps at easy")
	check(_problems([{"b": 0, "k": "stomp", "lane": 1}], "story", "medium").is_empty(), "stomps from medium")
	check(_problems([{"b": 0, "k": "step", "lane": 1, "call": true}], "story", "medium").any(func(p): return "calls" in p), "no calls before hard")
	check(_problems([{"b": 0, "k": "step", "lane": 1}], "piazza", "piazza").any(func(p): return "piazza" in p), "piazza is bells only")
	check(_problems([{"b": 0, "k": "stomp", "lane": 1}], "tutorial", "easy").is_empty(), "the tutorial may teach anything at any level")
	check(_problems([{"b": 12.3333, "k": "bell"}, {"b": 12.8333, "k": "bell"}]).filter(_not_grid).is_empty(), "thirds rounded to 4 decimals are half a beat apart")


func _sectioned(chart: Array, diff: String, sections: Array, bpm := 120.0) -> Array[String]:
	var s := SongData.from_dict({"id": "c", "kind": "story", "bpm": bpm, "offset": 1.0, "sections": sections, "charts": {diff: chart}})
	return ChartRules.check(s, diff)


func test_triplet_feel_per_section() -> void:
	# Alternating thumbs a third of a beat apart, each thumb every 2/3 beat: fine in a triplet
	# section at Hard (a thumb may play every triplet eighth, 1/3 beat).
	var trip := []
	for i in 12:
		trip.append({"b": 16.0 + i / 3.0, "k": "step", "lane": 0 if i % 2 == 0 else 2})
	var secs := [{"name": "a", "b": 0, "len": 16}, {"name": "climax", "b": 16, "len": 8}]
	check_eq(_sectioned(trip, "hard", secs), [] as Array[String], "a triplet section passes at 1/3-beat gaps")
	# One thumb on every triplet eighth: 1/3 beat per thumb is allowed at Hard in triplet feel...
	var jack := []
	for i in 6:
		jack.append({"b": 16.0 + i / 3.0, "k": "step", "lane": 0})
	check_eq(_sectioned(jack, "hard", secs), [] as Array[String], "one thumb per triplet eighth at Hard")
	# ...but not at Medium (2/3) or Expert (1/3 also, so Expert passes).
	check(_sectioned(jack, "medium", secs).any(func(p): return "thumb too fast" in p), "Medium triplets: 2/3 beat per thumb")
	check_eq(_sectioned(jack, "expert", secs), [] as Array[String], "Expert triplets: 1/3 beat per thumb")
	# The same gaps in a straight section fail: 1/3 beat is closer than the straight 1/2 per thumb.
	var straight := []
	for i in 6:
		straight.append({"b": 16.0 + i * 0.35, "k": "step", "lane": 0})
	check(_sectioned(straight, "hard", secs).any(func(p): return "thumb too fast" in p), "the same gaps in a straight section fail")
	# Feel is decided per section: triplets in the climax do not loosen the verse.
	var mixed := jack.duplicate()
	mixed.push_front({"b": 1.35, "k": "step", "lane": 0})
	mixed.push_front({"b": 1.0, "k": "step", "lane": 0})
	var mp := _sectioned(mixed, "hard", secs).filter(_not_grid)
	check(mp.any(func(p): return "b=1.35" in p), "the straight verse keeps its half-beat rule")
	check_eq(mp.size(), 1, "while the triplet climax passes (%s)" % [mp])
	# Without sections the whole chart shares one feel: any note on a third makes it triplet.
	check_eq(_sectioned(jack, "hard", []), [] as Array[String], "no sections: one feel for the chart")
	check(ChartRules.on_third(12.3333) and ChartRules.on_third(3.8333) and not ChartRules.on_third(4.5), "third and sixth positions")


func test_bell_uses_both_thumbs() -> void:
	# Medium and Hard: nothing within half a beat of a bell, before or after.
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "bell"}]).any(func(p): return "before the bell" in p), "input a quarter beat before a bell")
	check(_problems([{"b": 0, "k": "bell"}, {"b": 0.25, "k": "step", "lane": 2}]).any(func(p): return "after the bell" in p), "input a quarter beat after a bell")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.5, "k": "bell"}, {"b": 1.0, "k": "step", "lane": 2}]).is_empty(), "half a beat either side is fine")
	check(_problems([{"b": 0, "k": "ring", "lane": 1}, {"b": 0, "k": "step", "lane": 0}], "story", "expert").is_empty(), "a step on the bell's own beat (triple ring) is fine")
	# Expert: 150 ms, at 120 bpm 0.3 beat.
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.25, "k": "bell"}], "story", "expert").any(func(p): return "before the bell" in p), "Expert: 125 ms is too close")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 0.5, "k": "bell"}], "story", "expert").is_empty(), "Expert: 250 ms is fine")
	# Easy: no two inputs closer than 0.6 s (the tutorial is exempt).
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 1, "k": "step", "lane": 2}], "story", "easy").any(func(p): return "apart" in p), "Easy: 0.5 s is too close for a story song")
	check(_problems([{"b": 0, "k": "step", "lane": 0}, {"b": 1, "k": "step", "lane": 2}], "tutorial", "easy").is_empty(), "the tutorial may")


# ---------------------------------------------------------------- the real songs


func _play_all(s: Session) -> void:
	var ap := Autoplay.new(s)
	var t := (s.notes[0].t - 1.0) if not s.notes.is_empty() else 0.0
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)


func test_real_songs() -> void:
	SongLibrary.reset()
	var songs := SongLibrary.all()
	check(SongLibrary.load_errors.is_empty(), "every song file loads: %s" % [SongLibrary.load_errors])
	if songs.is_empty():
		return
	var shares: Array[float] = []   # stillness share of a perfect Hard run, per story song
	for song in songs:
		check_eq(ChartRules.check_song(song), [] as Array[String], "%s passes the chart rules" % song.id)
		check(ResourceLoader.exists(song.audio), "%s audio %s exists" % [song.id, song.audio])
		check(song.title("en") != song.id and song.title("it") != song.id, "%s has titles" % song.id)
		if song.has_remix():
			check(SongLibrary.get_song(song.remix_id()) == song, "%s remix id resolves" % song.id)
		for diff in song.difficulties():
			var opts := {"piazza": true} if song.kind == "piazza" else {}
			var s := Session.new(song, diff, "full", opts)
			check(s.stats.total > 0, "%s/%s has notes" % [song.id, diff])
			_play_all(s)
			if song.kind == "story":
				# chords (two steps on one beat, one per thumb): never on Easy, always on Hard and Expert
				var chords := 0
				for i in range(1, s.notes.size()):
					var a := s.notes[i - 1]
					var b := s.notes[i]
					if a.kind == Note.Kind.STEP and b.kind == Note.Kind.STEP and absf(a.t - b.t) < 0.001 and a.lane != b.lane:
						chords += 1
				if diff == "easy":
					check_eq(chords, 0, "%s/easy has no chords" % song.id)
				elif diff == "hard" or diff == "expert":
					check(chords > 0, "%s/%s has chords" % [song.id, diff])
			if song.kind == "story" and diff == "hard":
				var bd := s.score_breakdown()
				shares.append(bd.stills / maxf(bd.total, 1.0))
			check_near(s.accuracy(), 1.0, 1e-9, "%s/%s: autoplay 100 %% (miss %d, wrong %d)" % [song.id, diff, s.stats.miss, s.stats.wrong])
			check_eq(s.stats.silence, 0, "%s/%s: no bell in a stand-still" % [song.id, diff])
			check_eq(s.stats.let_go, 0, "%s/%s: every hold kept" % [song.id, diff])
			if song.length > 0.0:
				check(s.notes[-1].end_t <= song.length, "%s/%s: notes end before the song does" % [song.id, diff])
			if song.kind != "piazza":
				var sl := Session.new(song, diff, "light", {"slam": true})
				_play_all(sl)
				check_near(sl.accuracy(), 1.0, 1e-9, "%s/%s slam: autoplay 100 %% with the buttons" % [song.id, diff])
				var mi := Session.new(song, diff, "village", {"mirror": true})
				_play_all(mi)
				check_near(mi.accuracy(), 1.0, 1e-9, "%s/%s mirrored: autoplay 100 %%" % [song.id, diff])
			if song.has_remix():
				var r := Session.new(song, diff, "light", {"remix": true})
				_play_all(r)
				check_near(r.accuracy(), 1.0, 1e-9, "%s/%s remix: autoplay 100 %%" % [song.id, diff])
	# Stillness is worth chasing: about 7-12 % of a perfect run on a typical story song at Hard (7, not
	# 8, since Hard sits at the difficult threshold from the first stop: more notes share the score).
	if not shares.is_empty():
		shares.sort()
		var med := shares[shares.size() >> 1]
		check(med >= 0.07 and med <= 0.12, "stillness is %.1f %% of a typical Hard run (median of %d songs, %.1f..%.1f %%)" % [med * 100.0, shares.size(), shares[0] * 100.0, shares[-1] * 100.0])
		print("  stillness share at Hard: " + ", ".join(shares.map(func(x): return "%.1f%%" % (x * 100.0))))
	var story := SongLibrary.story()
	for i in story.size():
		check_eq(story[i].stop, i + 1, "story stops numbered 1..n in order (%s)" % story[i].id)


## Health is fair: a human-like player (Autoplay's human mode: ±18 ms, a hold let go early now and
## then, 1 % of notes missed) finishes every song on every difficulty with health to spare, and one
## who misses about a quarter of the notes runs out on Hard.
func test_health_is_fair() -> void:
	SongLibrary.reset()
	for song in SongLibrary.all():
		if song.kind == "piazza":
			continue
		for diff in song.difficulties():
			if not diff in SongData.DIFFICULTIES:
				continue
			for seed_ in [3, 11]:
				var s := Session.new(song, diff, "full")
				var low := [Session.MAX_HEALTH]
				s.health_changed.connect(func(h: int, _d: int) -> void: low[0] = mini(low[0], h))
				_play_human(s, seed_, -1.0)
				check(not s.has_failed, "%s/%s (seed %d): a human-like run does not fail (lowest %d)" % [song.id, diff, seed_, low[0]])
			if diff == "hard":
				var bad := Session.new(song, diff, "full")
				_play_human(bad, 5, 0.25)
				check(bad.has_failed, "%s/hard: missing a quarter of the notes runs out of health" % song.id)


func _play_human(s: Session, seed_: int, miss_rate: float) -> void:
	var ap := Autoplay.new(s, true, seed_, miss_rate)
	var t := (s.notes[0].t - 1.0) if not s.notes.is_empty() else 0.0
	while not s.is_over(t):
		t += 1.0 / 60.0
		ap.update(t)
