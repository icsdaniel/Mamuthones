extends SceneTree
## Recovery sim: a simulated player slips once (one tap D late) and stays late, the lag fading by DECAY per note;
## counts what the rules add on top: wrong steps, strays, locks, notes lost, and the notes until three good hits in a row.
##   godot --headless --path game -s res://tests/recovery_sim.gd -- <song> <difficulty> <slips> <decay> <D seconds>
const WINDOW := 12

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var song := SongData.load_file("res://data/songs/%s.json" % a[0])
	var diff: String = a[1]
	var slips := int(a[2])
	var decay := float(a[3])
	var d := float(a[4])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tot := {"bad": 0.0, "wrong": 0.0, "stray": 0.0, "miss": 0.0, "locked": 0.0, "rec": 0.0, "lost_health": 0.0, "n": 0.0}
	var probe := Session.new(song, diff, {"health": true})
	var lane_idx: Array = []
	for n in probe.notes:
		if n.kind == Note.Kind.STEP or n.kind == Note.Kind.RING:
			lane_idx.append(n.index)
	for r in slips:
		var k: int = lane_idx[rng.randi_range(8, lane_idx.size() - WINDOW - 2)]
		var out := run(song, diff, k, decay, d, rng.randi())
		for key in out:
			tot[key] += float(out[key])
		tot.n += 1
	var line := "%s %s decay %.2f D %dms:" % [a[0], diff, decay, roundi(d * 1000)]
	for key in ["bad", "wrong", "stray", "miss", "locked", "rec", "lost_health"]:
		line += " %s=%.2f" % [key, tot[key] / tot.n]
	print(line)
	quit()

func run(song: SongData, diff: String, k: int, decay: float, d: float, seed_: int) -> Dictionary:
	var s := Session.new(song, diff, {"health": true})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ev: Array = []
	var id := 1
	var lag := 0.0
	var after := 0
	var order: Array = []
	for n in s.notes:
		if n.kind == Note.Kind.REST:
			continue
		if n.index == k:
			lag = d
		elif n.index > k:
			lag *= decay
		var at := n.t + lag + rng.randfn(0.0, 0.045) + rng.randf() * 0.016
		if n.is_bell():
			ev.append([at + rng.randfn(0.0, 0.01), "ring", -1, 0, n.index])
			if n.kind == Note.Kind.BELL:
				continue
		ev.append([at, "tap", n.lane, id, n.index])
		var up := at + 0.06
		if n.kind == Note.Kind.HOLD:
			up = n.end_t + rng.randfn(0.0, 0.03)
		ev.append([up, "up", n.lane, id, n.index])
		if n.kind == Note.Kind.STOMP:
			ev.append([at + 0.03, "tap", n.lane, id + 1, n.index])
			ev.append([at + 0.09, "up", n.lane, id + 1, n.index])
			id += 1
		id += 1
	ev.sort_custom(func(x, y): return x[0] < y[0])
	var locked := 0
	var wrong0 := 0
	var stray0 := 0
	var h0 := 0
	var t := s.notes[0].t - 1.0
	var i := 0
	var marks := {}   # note index -> state at slip
	var end_t: float = s.notes[mini(k + 40, s.notes.size() - 1)].t + 1.0
	var snap := false
	while t < end_t:
		t += 1.0 / 60.0
		while i < ev.size() and ev[i][0] <= t:
			var e: Array = ev[i]
			match e[1]:
				"tap":
					if not snap and e[4] >= k:
						snap = true
						wrong0 = s.stats.wrong; stray0 = s.stats.stray; h0 = s.health
					var res := s.tap(e[2], e[0], e[3])
					if snap and res.judgement == "locked":
						locked += 1
				"up":
					s.release(e[0], e[3])
				"ring":
					s.ring(e[0])
			i += 1
		s.update(t)
	# judge the WINDOW lane notes from k on
	var bad := 0
	var miss := 0
	var rec := WINDOW
	var good_run := 0
	var seen := 0
	for n in s.notes:
		if n.index < k or n.kind == Note.Kind.REST or n.kind == Note.Kind.BELL:
			continue
		if seen >= WINDOW:
			break
		seen += 1
		var ok: bool = n.judgement == "perfect" or n.judgement == "good"
		if not ok:
			bad += 1
		if n.judgement == "miss":
			miss += 1
		if n.index > k:
			good_run = good_run + 1 if ok else 0
			if good_run >= 3 and rec == WINDOW:
				rec = seen - 3
	return {"bad": bad, "wrong": s.stats.wrong - wrong0, "stray": s.stats.stray - stray0, "miss": miss, "locked": locked, "rec": rec, "lost_health": h0 - s.health}
