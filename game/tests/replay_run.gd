extends SceneTree
## Replays a run saved by RunLog (a phone's mamuthones-last-run.json) through the rules and the bell
## detector as they are now: the recorded motion readings, touches, presses and releases are fed in
## time order, and every bell and full ring is listed with how it ended then and now.
##   godot --headless --path game -s res://tests/replay_run.gd -- /path/run.json [from_s to_s]
## Add "old" after the path to replay without BellDetector.forgive() (the detector before it).


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		print("usage: -- run.json [old] [from_s to_s]")
		quit(1)
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(a[0]))
	var old := a.has("old")
	var nums: Array = Array(a.slice(1)).filter(func(x): return str(x).is_valid_float())
	var lo := float(nums[0]) if nums.size() > 0 else -INF
	var hi := float(nums[1]) if nums.size() > 1 else INF
	var h: Dictionary = d.header
	var song := SongData.load_file("res://data/songs/%s.json" % h.song_id)
	var s := Session.new(song, h.difficulty, h.get("options", {}))
	var det := BellDetector.from_calibration(h.get("calibration", {}), bool(h.get("calibration", {}).get("has_gyro", true)))
	det.set_bpm(song.bpm)
	# [t, order, kind, data]: readings and touches from the motion table, presses from the events.
	var ev: Array = []
	for r in d.motion:
		if r[0] == "r":
			ev.append([float(r[1]), 0, "r", r])
		elif r[0] == "t":
			ev.append([float(r[1]), 1, "t", r])
	for e in d.events:
		if e[2] == "press" or e[2] == "release":
			ev.append([float(e[1]), 2, e[2], e[3]])
	ev.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	var rings := 0
	for e in ev:
		var t: float = e[0]
		s.update(t)
		match e[2]:
			"r":
				var r: Array = e[3]
				if det.feed(t, Vector3(r[2], r[3], r[4]), Vector3(r[5], r[6], r[7])):
					rings += 1
					var rr := s.ring(det.last_t, true, det.last_strength)
					if not old and rr.get("quality") in ["free", "miss"]:
						det.forgive()
					if det.last_t >= lo and det.last_t <= hi:
						print("  ring %.3f %s" % [det.last_t, rr.get("quality")])
			"t":
				det.note_touch(t)
			"press":
				s.tap(int(e[3].lane), t, int(e[3].id))
			"release":
				s.release(t, int(e[3].id))
	s.update(s.end_time() + 1.0)
	var then := {}
	for n in d.notes:
		then[int(n[0])] = n[6]
	var hit := [0, 0]
	var changed := []
	for n in s.notes:
		if not n.is_bell():
			continue
		var was: String = then.get(n.index, "?")
		hit[0] += 1 if was != "miss" else 0
		hit[1] += 1 if n.judgement != "miss" else 0
		if was != n.judgement or (n.t >= lo and n.t <= hi):
			changed.append("%3d %7.3f %-5s then %-8s now %s" % [n.index, n.t, n.kind_name(), was, n.judgement])
	for c in changed:
		print(c)
	print("bells and rings caught: then %d, now %d (%s); rings fired %d; rings in stand-stills %d; grade %s %.1f%%" % [hit[0], hit[1],
		"old detector" if old else "forgive", rings, s.stats.silence, s.grade(), s.accuracy() * 100.0])
	quit()
