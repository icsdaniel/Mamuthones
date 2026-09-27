extends TestCase
## Sound autoload: every API call works headless, every sample exists and loads,
## loops loop, and the one-shots are imported the way the latency path needs.

const SoundScript := preload("res://scripts/audio/sound.gd")


func _sound() -> Node:
	var s := tree.root.get_node_or_null("Sound")
	if s == null or s.get_script() != SoundScript:
		s = SoundScript.new()
		s.name = "SoundUnderTest"
		tree.root.add_child(s)
	return s


func _settle() -> void:
	# stop everything and give the audio server time to drop the playbacks, so the
	# run ends without leaked streams
	_sound().stop_all()
	await tree.create_timer(0.5).timeout


func test_buses_exist() -> void:
	_sound()
	for b in ["Music", "Bells", "Sfx", "Ambience"]:
		check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)


func test_no_missing_samples() -> void:
	var s := _sound()
	check_eq(s._missing.size(), 0, "missing samples %s" % [s._missing])


func test_every_sample_loads() -> void:
	var count := 0
	for dir in ["bells", "steps", "loops", "voice", "fx", "ui", "ambience"]:
		var path: String = "res://audio/sfx/" + dir
		for f in DirAccess.get_files_at(path):
			if f.ends_with(".import"):
				f = f.trim_suffix(".import")
			elif not (f.ends_with(".wav") or f.ends_with(".ogg")) or ResourceLoader.exists(path + "/" + f) == false:
				continue
			var st := load(path + "/" + f) as AudioStream
			if check(st != null, "%s/%s loads" % [path, f]):
				check(st.get_length() > 0.05, "%s/%s has length" % [path, f])
				count += 1
	check(count >= 213, "found all samples (%d)" % count)


func test_bell_matrix_complete() -> void:
	var s := _sound()
	for set_id in ["light", "village", "full"]:
		var arr: Array = s._bells[set_id]
		check_eq(arr.size(), 12, "%s has 6 qualities x 2 directions" % set_id)
		for i in arr.size():
			check(arr[i].size() >= (3 if i < 8 else 2), "%s: enough takes for variant %d" % [set_id, i])
		check(s._accents[set_id][0].size() == 2 and s._accents[set_id][1].size() == 2, "%s has hard-flick accents" % set_id)
		check(s._jangles[set_id] != null, "%s has a jangle" % set_id)
	for tight in 2:
		for d in 2:
			check(s._row[tight][d].size() >= 3, "row bells takes")


func test_one_shots_uncompressed() -> void:
	# Bells, steps and the count-in stay raw 16-bit PCM: no decode cost, and count_in
	# needs the raw bytes.
	for path in ["res://audio/sfx/bells/full_down_perfect_1.wav", "res://audio/sfx/steps/tone_0_00.wav",
			"res://audio/sfx/steps/foot_0_1.wav", "res://audio/sfx/fx/count_hi.wav"]:
		var st := load(path) as AudioStreamWAV
		if check(st != null, "%s is a WAV" % path):
			check_eq(st.format, AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit PCM" % path)
			check_eq(st.mix_rate, 44100, "%s is 44.1 kHz" % path)


func test_loops_loop() -> void:
	var s := _sound()
	for lane in 3:
		for pc in 12:
			var d: AudioStreamOggVorbis = s._drones[lane][pc]
			check(d != null and d.loop, "drone %d/%d loops" % [lane, pc])
	for st in s._amb_streams:
		check(st != null and (st as AudioStreamOggVorbis).loop, "ambience loops")
		check(st.get_length() >= 15.0, "ambience loop is long enough not to be noticed")
	check(s._amb_streams[2].get_length() >= 48.0, "the wind loop is long enough that its gusts don't recur")


func test_api_calls_headless() -> void:
	var s := _sound()
	s.set_key(62)
	check_eq(s._key_pc, 2, "set_key keeps the pitch class")
	s.set_key(-1)
	check_eq(s._key_pc, 11, "negative midi wraps")
	for bus in ["music", "bells", "sfx", "ambience", "master"]:
		s.set_volume(bus, 0.5)
		var trim: float = s.BUS_TRIM_DB.get(bus.capitalize(), 0.0)
		check_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus.capitalize())), linear_to_db(0.5) + trim, 0.01, "%s volume" % bus)
		s.set_volume(bus, 0.0)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus.capitalize())), "%s muted at 0" % bus)
		s.set_volume(bus, 1.0)
	for lane in [0, 1, 2, -3, 9]:
		s.step(lane)
	for level in 6:
		s.row_bells(level)
		for set_id in ["light", "village", "full", "full_load", "nonsense"]:
			for q in ["perfect", "good", "ok", "miss", "silence", "free", "early"]:
				s.bell(set_id, true, q)
				s.bell(set_id, false, q)
	s.row_bells(99)
	check_eq(s._unison, 5, "unison clamps")
	s.call_out()
	s.rope()
	s.rope_grab()
	s.stop_count_in()
	for n in ["tap", "back", "unlock", "carve", "result", "cue"]:
		s.ui(n)
	var len: float = s.count_in(120.0)
	check_near(len, 2.0, 0.001, "count-in at 120 bpm lasts 2 s")
	s.count_in(76.0)
	s.ambience("fire")
	s.ambience("crowd+wind")
	s.stop_ambience()
	for lane in 3:
		s.hold_start(lane)
	s.set_key(67)
	await tree.process_frame
	for lane in 3:
		check(s._hold_players[lane].playing, "hold %d plays" % lane)
		s.hold_stop(lane)
	for i in 12:
		await tree.process_frame
	check(true, "API calls ran")
	await _settle()

func test_count_in_is_beat_exact() -> void:
	var s := _sound()
	for bpm in [60.0, 76.0, 128.0, 200.0]:
		s.count_in(bpm)
		var found := s._count_player.stream as AudioStreamWAV
		if check(found != null and s._count_player.playing, "count-in plays"):
			var beat := int(round(44100.0 * 60.0 / bpm))
			check_eq(found.data.size(), beat * 2 * 4, "count-in at %s bpm is 4 whole beats" % bpm)
	await _settle()


func test_stop_count_in() -> void:
	var s := _sound()
	s.count_in(90.0)
	s.stop_count_in()
	check(s._count_stopping, "stopping fades first (no click)")
	s._process(0.05)
	check(not s._count_player.playing, "the count-in is silent after the fade")
	s.stop_count_in()  # harmless when nothing plays
	s.count_in(90.0)
	check(s._count_player.playing and is_equal_approx(s._count_player.volume_db, 0.0), "a new count-in plays at full level")
	await _settle()


func test_cue_and_rope_grab() -> void:
	var s := _sound()
	s.ui("cue")
	var p := _last_player(s, s._sfx_pool, 4)
	check(s._ui["cue"].has(p.stream), "ui(\"cue\") plays the bell cue")
	check(p.stream.get_length() < 0.35, "the cue is short")
	check(not s._bells["light"][0].has(p.stream), "the cue is not a bell ring")
	s.rope_grab()
	p = _last_player(s, s._sfx_pool, 4)
	check(s._grabs.has(p.stream), "rope_grab() plays a grip")
	check(p.stream.get_length() < 0.3, "the grab is short")
	await _settle()


func test_steps_follow_key() -> void:
	var s := _sound()
	s.set_key(60)
	s.step(1)
	var n: int = s._tone_pool.size()
	var p: AudioStreamPlayer = s._tone_pool[(s._next[3] - 1 + n) % n]
	check(p.stream == s._tones[1][0] and is_equal_approx(p.pitch_scale, 1.0), "the middle step in C plays the C tone")
	s.set_key(69)  # A (pitch class 9) is played from the G# tone (8) a semitone up
	s.step(2)
	p = s._tone_pool[(s._next[3] - 1 + n) % n]
	check(p.stream == s._tones[2][4], "the right step in A uses the tone recorded a semitone below")
	# (A is pitch class 9: the G# tone, index 4, raised a semitone)
	check_near(p.pitch_scale, pow(2.0, 1.0 / 12.0), 1e-6, "and raises it by exactly one semitone")
	for lane in 3:
		check(s._hold_players[lane].playing and s._hold_players[lane].stream == s._drones[lane][9], "drone %d runs silently in the new key" % lane)
	await _settle()


func test_takes_do_not_repeat() -> void:
	var s := _sound()
	var takes: Array = s._bells["full"][0]
	var last: AudioStream = null
	for i in 30:
		var t: AudioStream = s._pick(takes, 999)
		check(t != last, "no immediate repeat")
		last = t


func test_hot_path_is_cheap() -> void:
	# step, bell and the row are called on every hit: they must stay far below a frame
	var s := _sound()
	s.row_bells(5)
	var t0 := Time.get_ticks_usec()
	for i in 300:
		s.step(i % 3)
		s.bell("full", i % 2 == 0, "perfect")
	var per_call := float(Time.get_ticks_usec() - t0) / 600.0
	check(per_call < 200.0, "step/bell cost %.1f us per call" % per_call)
	print("  Sound hot path: %.1f us per call" % per_call)
	await _settle()


func test_stop_ambience_table() -> void:
	var s := _sound()
	check_eq(s.STOP_AMBIENCE.size(), 8, "one ambience per story stop (1..7)")
	for i in range(1, 8):
		for part in s.STOP_AMBIENCE[i].split("+"):
			check(s.AMBIENCES.has(part), "stop %d ambience %s exists" % [i, part])


func test_loop_seams_in_godot_decoder() -> void:
	# Decode through Godot's own playback past the loop point. The step across the seam
	# must look like any other step nearby (no click), and the second pass must start
	# exactly like the first.
	var paths := ["res://audio/sfx/loops/drone_0_02.ogg", "res://audio/sfx/loops/drone_1_07.ogg",
		"res://audio/sfx/loops/drone_2_11.ogg", "res://audio/sfx/ambience/fire.ogg",
		"res://audio/sfx/ambience/crowd.ogg", "res://audio/sfx/ambience/wind.ogg"]
	for path in paths:
		var st := load(path) as AudioStreamOggVorbis
		st.loop = true
		var frames := int(round(st.get_length() * 44100.0))
		var pb := st.instantiate_playback()
		pb.start(0.0)
		var buf := PackedVector2Array()
		while buf.size() < frames + 4096:
			buf.append_array(pb.mix_audio(1.0, 4096))
		# Godot's resampler puts the first sample at index 2
		var seam := frames + 2
		var near := 0.0
		for i in range(seam - 2000, seam - 1):
			near = maxf(near, absf(buf[i + 1].x - buf[i].x))
		var jump := absf(buf[seam].x - buf[seam - 1].x)
		check(jump <= near * 1.5 + 1e-4, "%s: seam step %.5f vs nearby steps up to %.5f" % [path.get_file(), jump, near])
		var same := true
		for i in 512:
			if not buf[seam + i].is_equal_approx(buf[2 + i]):
				same = false
		check(same, "%s: the loop restarts sample-exactly" % path.get_file())


func _last_player(s: Node, pool: Array, which: int) -> AudioStreamPlayer:
	var n: int = pool.size()
	return pool[(s._next[which] - 1 + n) % n]


func test_early_and_late_sound_different() -> void:
	var s := _sound()
	s.bell("village", true, "early")
	var early := _last_player(s, s._bell_pool, 0)
	check(s._bells["village"][8].has(early.stream), "early plays its own ring (small bells first, choked)")
	check_eq(String(early.bus), "BellsEarly", "early rings a little to the left")
	check(early.pitch_scale > 1.01, "and a touch higher (%.3f)" % early.pitch_scale)
	s.bell("village", false, "late")
	var late := _last_player(s, s._bell_pool, 0)
	check(s._bells["village"][11].has(late.stream), "late plays its own ring (a heavy flam, big bells dragging)")
	check_eq(String(late.bus), "BellsLate", "late rings a little to the right")
	check(late.pitch_scale < 0.99, "and a touch lower (%.3f)" % late.pitch_scale)
	s.bell("village", true, "perfect")
	var p := _last_player(s, s._bell_pool, 0)
	check(absf(p.pitch_scale - 1.0) <= 0.0026, "a perfect ring is only humanized, not detuned")
	await _settle()


func test_strength_layers() -> void:
	var s := _sound()
	s.bell("full", true, "perfect", 0.1)
	var soft := _last_player(s, s._bell_pool, 0)
	check_eq(String(soft.bus), "BellsSoft", "a soft flick rings a little darker, through the gentle low-pass bus")
	check(soft.volume_db >= -1.81, "and only about 1 dB down")
	var before: int = s._next[0]
	s.bell("full", false, "perfect", 0.95)
	var hard := _last_player(s, s._bell_pool, 0)
	check(s._accents["full"][1].has(hard.stream), "a hard flick layers the heavy slam")
	check_eq((s._next[0] - before + s._bell_pool.size()) % s._bell_pool.size(), 2, "a hard flick uses two voices")
	s.bell("full", false, "perfect")
	check_eq(String(_last_player(s, s._bell_pool, 0).bus), "Bells", "the default strength is the normal ring")
	await _settle()


func test_row_only_with_the_procession() -> void:
	var s := _sound()
	s.stop_all()
	await tree.create_timer(0.1).timeout
	s.row_bells(5)
	for q in ["silence", "free", "miss"]:
		var before: int = s._next[1]
		s.bell("light", true, q)
		check_eq(s._next[1], before, "the row stays out of a %s ring" % q)
	for q in ["perfect", "good", "ok", "early", "late"]:
		var before: int = s._next[1]
		s.bell("light", true, q)
		check(s._next[1] != before, "the row joins a %s ring" % q)
	check(s.ROW_DB[5] <= -6.0, "the full row sits at -6 dB or under")
	await _settle()


func test_jangle_after_streak() -> void:
	var s := _sound()
	s.end_song()
	for i in 3:
		s.bell("village", i % 2 == 0, "perfect")
	check(not s._jangle_player.playing, "no jangle before a streak")
	s.bell("village", true, "good")
	check(s._jangle_player.playing, "the load keeps jangling after 4 rings in a row")
	s.bell("village", false, "miss")
	check(s._jangle_choking, "a miss chokes the jangle")
	for i in 20:
		await tree.process_frame
	s._process(0.2)
	check(not s._jangle_player.playing, "choked within a fraction of a second")
	await _settle()


func test_end_song_and_idle_drones() -> void:
	var s := _sound()
	s.set_key(62)
	for lane in 3:
		check(s._hold_players[lane].playing, "set_key starts drone %d (silent)" % lane)
	s._process(s.DRONE_IDLE_STOP + 0.1)
	for lane in 3:
		check(not s._hold_players[lane].playing, "a drone silent for %.0f s stops" % s.DRONE_IDLE_STOP)
	s.hold_start(1)
	check(s._hold_players[1].playing, "hold_start restarts a stopped drone")
	s._process(s.DRONE_IDLE_STOP + 0.1)
	check(s._hold_players[1].playing, "a sounding drone is not stopped")
	s.set_key(62)
	s.row_bells(4)
	s.end_song()
	for lane in 3:
		check(not s._hold_players[lane].playing, "end_song stops drone %d" % lane)
	check_eq(s._unison, 0, "end_song forgets the unison level")
	await _settle()


func test_steals_the_oldest_voice() -> void:
	var s := _sound()
	s.stop_all()
	await tree.create_timer(0.1).timeout
	check_eq(s._row_pool.size(), 6, "six row voices")
	var n: int = s._bell_pool.size()
	var first: AudioStreamPlayer = null
	for i in n:
		s.bell("full", i % 2 == 0, "perfect")
		if i == 0:
			first = _last_player(s, s._bell_pool, 0)
		await tree.create_timer(0.03).timeout
	var all_busy := true
	for p in s._bell_pool:
		all_busy = all_busy and p.playing
	if all_busy:
		var oldest: AudioStreamPlayer = null
		var best := -1.0
		for p: AudioStreamPlayer in s._bell_pool:
			if p.get_playback_position() > best:
				best = p.get_playback_position()
				oldest = p
		s.bell("full", true, "perfect")
		check(_last_player(s, s._bell_pool, 0) == oldest, "with every voice busy, the oldest ring is the one cut")
		check(oldest == first or best > 0.2, "and it is one of the first rung")
	else:
		check(true, "a voice finished early; nothing to steal")
	await _settle()


func test_hold_fades_are_click_free_in_the_mixer() -> void:
	# Record Godot's own mix of the Sfx bus while a drone fades in and out, and check
	# that no sample-to-sample step at the edges is bigger than the drone's own steps.
	var s := _sound()
	var bus := AudioServer.get_bus_index("Sfx")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 3.0
	AudioServer.add_bus_effect(bus, cap)
	s.set_key(62)
	await tree.create_timer(0.2).timeout
	cap.clear_buffer()
	s.hold_start(0)
	await tree.create_timer(0.35).timeout
	s.hold_stop(0)
	await tree.create_timer(0.35).timeout
	var buf := cap.get_buffer(cap.get_frames_available())
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	if not check(buf.size() > 20000, "the mixer ran headless (%d frames)" % buf.size()):
		return
	# envelope: the peak of each 256-sample block and its neighbours
	var blocks := PackedFloat32Array()
	blocks.resize((buf.size() >> 8) + 1)
	for i in buf.size():
		blocks[i >> 8] = maxf(blocks[i >> 8], absf(buf[i].x))
	var loud := 0.0
	for b in blocks:
		loud = maxf(loud, b)
	var steady := 0.0
	var edge := 0.0
	for i in range(1, buf.size()):
		var k := i >> 8
		var env := maxf(blocks[k], maxf(blocks[maxi(k - 1, 0)], blocks[mini(k + 1, blocks.size() - 1)]))
		var d := absf(buf[i].x - buf[i - 1].x)
		# "edges" are blocks where the drone is fading; "steady" where it is near full
		if env > loud * 0.8:
			steady = maxf(steady, d)
		elif env < loud * 0.6:
			edge = maxf(edge, d)
	check(loud > 0.05, "the drone was heard (peak %.3f)" % loud)
	check(edge <= steady * 1.05, "no click while fading: largest step %.4f vs %.4f while steady" % [edge, steady])
	await _settle()


func test_rings_duck_the_music() -> void:
	var s := _sound()
	var music := AudioServer.get_bus_index("Music")
	s.set_volume("music", 1.0)
	for i in 30:
		s._process(0.02)
	check_near(AudioServer.get_bus_volume_db(music), 0.0, 0.01, "music at its level before a ring")
	s.bell("full", false, "perfect")
	s._process(0.02)
	check_near(AudioServer.get_bus_volume_db(music), -s.DUCK_DB, 0.01, "a ring dips the music %.1f dB" % s.DUCK_DB)
	for i in 5:
		s._process(0.02)
	check_near(AudioServer.get_bus_volume_db(music), -s.DUCK_DB, 0.01, "held through the ring's attack")
	for i in 20:
		s._process(0.02)
	check_near(AudioServer.get_bus_volume_db(music), 0.0, 0.01, "and back within ~0.3 s")
	s.set_volume("music", 0.5)
	s.bell("full", false, "miss")
	s._process(0.02)
	check_near(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01, "a miss doesn't duck; the user's music volume is kept")
	s.bell("full", true, "good")
	s._process(0.05)
	check_near(AudioServer.get_bus_volume_db(music), linear_to_db(0.5) - s.DUCK_DB, 0.01, "ducking works from the user's level")
	for i in 30:
		s._process(0.02)
	s.set_volume("music", 1.0)
	check_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Bells")), 0.0, 0.01, "Bells bus has no trim")
	await _settle()
