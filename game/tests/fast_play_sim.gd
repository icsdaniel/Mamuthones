extends SceneTree
## Plays a chart many times with a simulated human (timing spread, input delay, slips, skipped
## notes) and counts what goes wrong that the player did not do: locks, stolen notes, taps lost.
##   godot --headless --path game -s res://tests/fast_play_sim.gd -- [song] [difficulty] [runs]

const SIGMAS := [0.040, 0.055, 0.070]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var song_id := a[0] if a.size() > 0 else "piazza"
	var diff := a[1] if a.size() > 1 else "hard"
	var runs := int(a[2]) if a.size() > 2 else 40
	var song := SongData.load_file("res://data/songs/%s.json" % song_id)
	for sigma in SIGMAS:
		for lag in [0.0, 0.025, 0.06, 0.1]:
			var tot := {}
			for r in runs:
				var st := play(song, diff, sigma, lag, 1000 + r)
				for k in st:
					tot[k] = tot.get(k, 0.0) + float(st[k]) / runs
			var keys := tot.keys()
			keys.sort()
			var line := "sigma %2d ms lag %2d ms:" % [roundi(sigma * 1000), roundi(lag * 1000)]
			for k in keys:
				line += " %s=%.1f" % [k, tot[k]]
			print(line)
	# A masher: no reading at all, every button pressed in turn ten times a second.
	var mash := Session.new(song, diff, {"health": false})
	var t := mash.notes[0].t
	var k := 0
	var locked := 0
	while t < mash.end_time():
		mash.update(t)
		if mash.tap(k % 3, t, k).judgement == "locked":
			locked += 1
		k += 1
		t += 0.1
		mash.update(t)
	print("masher: presses=%d locked=%d locks=%d perfect=%d" % [k, locked, mash.stats.locks, mash.stats.perfect])
	quit()


## One run. sigma: spread of the player's timing; lag: a steady delay (a slow frame, a late thumb)
## added on top; 3 % of lane notes skipped, 2 % pressed on the neighbouring button.
static func play(song: SongData, diff: String, sigma: float, lag: float, seed_: int) -> Dictionary:
	var s := Session.new(song, diff, {"health": false})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ev: Array = []   # [t, kind, lane, id, note index]
	var id := 1
	for n in s.notes:
		if n.kind == Note.Kind.REST:
			continue
		var at := n.t + lag + rng.randfn(0.0, sigma) + rng.randf() * 0.016   # frame wait
		if n.is_bell():
			ev.append([at + rng.randfn(0.0, 0.01), "ring", -1, 0, n.index])
			if n.kind == Note.Kind.BELL:
				continue
		if rng.randf() < 0.03:
			continue
		var lane := n.lane
		if rng.randf() < 0.02:
			lane = 1 if lane != 1 else (0 if rng.randf() < 0.5 else 2)
		ev.append([at, "tap", lane, id, n.index])
		var up := at + 0.06
		if n.kind == Note.Kind.HOLD:
			up = n.end_t + rng.randfn(0.0, 0.03)
		ev.append([up, "up", lane, id, n.index])
		if n.kind == Note.Kind.STOMP:
			ev.append([at + 0.03, "tap", lane, id + 1, n.index])
			ev.append([at + 0.09, "up", lane, id + 1, n.index])
			id += 1
		id += 1
	ev.sort_custom(func(x, y): return x[0] < y[0])
	var out := {"stolen": 0, "locked_taps": 0, "stray": 0, "wrong": 0, "miss": 0, "locks": 0, "perfect": 0}
	var t := s.notes[0].t - 1.0
	var step := 1.0 / 60.0
	var i := 0
	while i < ev.size() or t < s.end_time():
		t += step
		while i < ev.size() and ev[i][0] <= t:
			var e: Array = ev[i]
			match e[1]:
				"tap":
					var res := s.tap(e[2], e[0], e[3])
					if res.judgement == "locked":
						out.locked_taps += 1
					elif res.note != null and res.note.index != e[4] and res.judgement != "wrong":
						out.stolen += 1
				"up":
					s.release(e[0], e[3])
				"ring":
					s.ring(e[0])
			i += 1
		s.update(t)
	out.stray = s.stats.stray
	out.wrong = s.stats.wrong
	out.miss = s.stats.miss
	out.locks = s.stats.locks
	out.perfect = s.stats.perfect
	return out
