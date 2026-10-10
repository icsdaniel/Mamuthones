extends TestCase
## The lift layer: every song has one as long as the song, the conductor plays it in sync and sets its
## level, and MusicLift raises it on hits on time, swells it on every note's accent and drops it on a miss.


func _songs() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://data/songs"):
		if f.ends_with(".json"):
			out.append("res://data/songs/" + f)
	return out


func test_every_song_has_a_lift_layer_as_long_as_it() -> void:
	for path in _songs():
		var song := SongData.load_file(path)
		for remix in ([false, true] if song.has_remix() else [false]):
			var audio := song.audio_for(remix)
			var lift_path := audio.get_basename() + "_lift.ogg"
			check(ResourceLoader.exists(lift_path), "%s exists" % lift_path)
			if not ResourceLoader.exists(lift_path):
				continue
			var a: AudioStream = load(audio)
			var b: AudioStream = load(lift_path)
			check(absf(a.get_length() - b.get_length()) < 0.05, "%s is as long as its song (%.2f vs %.2f)" % [lift_path, b.get_length(), a.get_length()])


func test_conductor_plays_the_layer_and_sets_its_level() -> void:
	var song := SongData.load_file(_songs()[0])
	var c := Conductor.new()
	tree.root.add_child(c)
	c.use_manual_clock(true)
	c.play(song)
	check(c.has_lift(), "the song plays with its lift layer")
	check(c.player.stream is AudioStreamSynchronized, "song and layer in one synchronized stream")
	var sync := c.player.stream as AudioStreamSynchronized
	check(sync.get_sync_stream_volume(1) <= Conductor.SILENT_DB, "the layer starts silent")
	c.set_lift(1.0)
	check(absf(sync.get_sync_stream_volume(1)) < 0.01, "at 1 the layer plays at full")
	check(absf(sync.get_sync_stream_volume(0) - Conductor.LIFT_BED_DB) < 0.01, "the song steps back under it")
	c.stop()
	c.queue_free()


func test_hits_raise_it_and_a_miss_drops_it() -> void:
	var lift := MusicLift.new()
	var spb := 0.5
	for i in 4:
		lift.hit("perfect")
		for f in 30:
			lift.tick(1.0 / 60.0, spb)
	check(lift.run > 0.5, "a run of Perfects raises the floor (%.2f)" % lift.run)
	check(lift.level > 0.5, "the layer sits up while the player keeps time (%.2f)" % lift.level)
	lift.accent()
	for f in 3:
		lift.tick(1.0 / 60.0, spb)
	check(lift.level > 0.75, "a note's accent swells it at once (%.2f)" % lift.level)
	lift.miss()
	for f in 9:
		lift.tick(1.0 / 60.0, spb)
	check(lift.level < 0.05, "a miss cuts it within 150 ms (%.2f)" % lift.level)
	lift.hit("good")
	lift.ok()
	check(lift.run < MusicLift.RUN_STEP["good"], "an Ok gives some of the run back")


func test_a_missed_note_was_accented_then_corrected() -> void:
	var lift := MusicLift.new()
	lift.accent()
	for f in 6:
		lift.tick(1.0 / 60.0, 0.5)
	check(lift.level > 0.7, "the note is accented on its time, before it is judged (%.2f)" % lift.level)
	lift.miss()
	for f in 9:
		lift.tick(1.0 / 60.0, 0.5)
	check(lift.level < 0.05, "the miss takes the accent back (%.2f)" % lift.level)
	check_eq(lift.run, 0.0, "and the run is gone")
