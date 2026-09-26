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
	await tree.create_timer(0.15).timeout


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
	check(count >= 168, "found all samples (%d)" % count)


func test_bell_matrix_complete() -> void:
	var s := _sound()
	for set_id in ["light", "village", "full"]:
		var arr: Array = s._bells[set_id]
		check_eq(arr.size(), 8, "%s has 4 qualities x 2 directions" % set_id)
		for takes in arr:
			check(takes.size() >= 3, "%s: 3 takes per variant" % set_id)
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


func test_api_calls_headless() -> void:
	var s := _sound()
	s.set_key(62)
	check_eq(s._key_pc, 2, "set_key keeps the pitch class")
	s.set_key(-1)
	check_eq(s._key_pc, 11, "negative midi wraps")
	for bus in ["music", "bells", "sfx", "ambience", "master"]:
		s.set_volume(bus, 0.5)
		check_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus.capitalize())), linear_to_db(0.5), 0.01, "%s volume" % bus)
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
	for n in ["tap", "back", "unlock", "carve", "result"]:
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
		# the stream was just handed to the pool player before the round-robin index
		var n: int = s._sfx_pool.size()
		var p: AudioStreamPlayer = s._sfx_pool[(s._next[4] - 1 + n) % n]
		var found := p.stream as AudioStreamWAV
		if check(found != null, "count-in stream exists"):
			var beat := int(round(44100.0 * 60.0 / bpm))
			check_eq(found.data.size(), beat * 2 * 4, "count-in at %s bpm is 4 whole beats" % bpm)
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
