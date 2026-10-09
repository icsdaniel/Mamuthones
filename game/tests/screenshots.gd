extends SceneTree
## Renders every screen to PNGs at the store sizes, in English and Italian:
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/screenshots.gd -- <out dir> \
##       [screen ...] [sizes=720x1440,1536x2048] [locales=en,it]
## Writes <out>/<W>x<H>/<screen>.png and <out>/it/<W>x<H>/<screen>.png. Screen names, sizes and locales
## limit the run (default: every screen, every size, both languages).
##
## Each size is drawn in its own SubViewport that copies the project's stretch (canvas_items, expand,
## base 720×1440), so the pictures match the phone whatever the window size. Progress comes from real
## Autoplay runs recorded into a throwaway profile (the player's own profile is never touched).

const SIZES: Array[Vector2i] = [Vector2i(720, 1440), Vector2i(720, 1280), Vector2i(720, 1600), Vector2i(1290, 2796), Vector2i(1536, 2048)]
const BASE := Vector2(720, 1440)
const PROFILE := "user://screenshots_profile.cfg"

var out_dir := "user://screenshots"
var only: Array[String] = []

## The Profile autoload, looked up at run time (this script compiles before autoloads exist).
var profile: Node


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	var sizes := SIZES.duplicate()
	var locales: Array[String] = ["en", "it"]
	for i in range(1, a.size()):
		if a[i].begins_with("sizes="):
			sizes.clear()
			for t in a[i].substr(6).split(","):
				sizes.append(Vector2i(int(t.get_slice("x", 0)), int(t.get_slice("x", 1))))
		elif a[i].begins_with("locales="):
			locales.assign(a[i].substr(8).split(","))
		elif a[i] != "":
			only.append(a[i])
	await process_frame
	profile = root.get_node("/root/Profile")
	_prepare_profile()
	for locale in locales:
		for size in sizes:
			var dir := out_dir.path_join(("" if locale == "en" else "it/") + "%dx%d" % [size.x, size.y])
			DirAccess.make_dir_recursive_absolute(dir)
			for shot in _shots():
				if not only.is_empty() and not shot.file in only:
					continue
				await _render(shot, size, locale, dir)
	print("screenshots written to ", ProjectSettings.globalize_path(out_dir))
	profile.load_profile()
	quit()


## Plays the first stops with Autoplay (a human-like one, so bells and accuracy vary) and records
## them, so the map, unlocks and workshop show a player part-way through the story.
func _prepare_profile() -> void:
	profile.load_profile(PROFILE)
	profile.reset()
	for f in profile.FLAGS:
		profile.set_flag(f, true)
	var story := SongLibrary.story()
	for i in mini(4, story.size()):
		var s: SongData = story[i]
		for d in ["easy", "hard"]:
			if d in s.difficulties():
				profile.record_result(_played(s, d, "light", i != 2))
	profile.set_look("fleece", "dark_brown")


static func _played(song: SongData, diff: String, bells: String, good: bool, until := INF) -> Session:
	var s := Session.new(song, diff, bells)
	var auto := Autoplay.new(s, true, 7 if good else 99)
	var t := s.notes[0].t - 1.0 if not s.notes.is_empty() else 0.0
	var end := minf(s.end_time(), until)
	while t < end:
		t += 1.0 / 60.0
		auto.update(t)
	return s


## What to render: file name, screen, args, extra setup, seconds to wait.
func _shots() -> Array:
	var story := SongLibrary.story()
	var fires: SongData = story[1] if story.size() > 1 else (story[0] if not story.is_empty() else null)
	var fires_id := fires.id if fires != null else ""
	var tut_id := story[0].id if not story.is_empty() else ""
	var shots := [
		{"file": "language", "screen": "language"},
		{"file": "headphones", "screen": "headphones"},
		{"file": "calibration", "screen": "calibration", "args": {"first_run": true}},
		{"file": "latency", "screen": "latency", "args": {"first_run": true}},
		{"file": "title", "screen": "title", "wait": 1.0},
		{"file": "story", "screen": "story"},
		{"file": "stop_card", "screen": "stop_card", "args": {"song_id": fires_id}},
		{"file": "free_play", "screen": "free_play"},
		{"file": "boards", "screen": "boards"},
		{"file": "settings", "screen": "settings"},
		{"file": "credits", "screen": "credits"},
		{"file": "workshop", "screen": "workshop", "setup": "tab_mask", "wait": 0.8},
		{"file": "workshop_bells", "screen": "workshop", "setup": "tab_bells", "wait": 0.8},
		{"file": "workshop_dress", "screen": "workshop", "setup": "tab_dress", "wait": 0.8},
		{"file": "tutorial", "screen": "tutorial", "args": {"song_id": tut_id, "first_run": true}, "wait": 1.2},
		{"file": "play_fires", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "human": true}, "setup": "advance:0.42"},
		{"file": "play_showcase", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:showcase", "wait": 0.1},
		{"file": "play_dense", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:dense", "wait": 0.1},
		{"file": "play_hold", "screen": "play", "args": {"song_id": "bonfires", "difficulty": "medium", "bell_set": "light", "autoplay": true}, "setup": "moment:hold", "wait": 0.1},
		{"file": "play_bell", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:bell", "wait": 0.1},
		{"file": "play_still", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:still", "wait": 0.1},
		{"file": "play_miss", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:miss", "wait": 0.05},
		{"file": "play_countin", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light"}, "setup": "moment:countin", "wait": 0.05},
		{"file": "play_ready", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light"}, "setup": "moment:ready", "wait": 0.05},
		{"file": "play_resume", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light"}, "setup": "resume", "wait": 0.0},
		{"file": "play_early", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:early", "wait": 0.08},
		{"file": "play_late", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:late", "wait": 0.08},
		{"file": "play_still_kept", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:stillkept", "wait": 0.1},
		{"file": "play_locked", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:locked", "wait": 0.05},
		{"file": "play_wrong", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:wrong", "wait": 0.05},
		{"file": "play_chord_medium", "screen": "play", "args": {"song_id": "carnival", "difficulty": "medium", "bell_set": "light", "autoplay": true}, "setup": "moment:chord", "wait": 0.05},
		{"file": "play_chord_hard", "screen": "play", "args": {"song_id": "carnival", "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:chord", "wait": 0.05},
		{"file": "play_chord_expert", "screen": "play", "args": {"song_id": "shrove", "difficulty": "expert", "bell_set": "light", "autoplay": true}, "setup": "moment:chord", "wait": 0.05},
		{"file": "play_sixteenths", "screen": "play", "args": {"song_id": "shrove", "difficulty": "expert", "bell_set": "light", "autoplay": true}, "setup": "moment:six", "wait": 0.05},
		{"file": "play_stomp", "screen": "play", "args": {"song_id": "rope", "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:stomp", "wait": 0.05},
		{"file": "play_stomp_outer", "screen": "play", "args": {"song_id": "rope", "difficulty": "expert", "bell_set": "light", "autoplay": true}, "setup": "moment:stomp", "wait": 0.05},
		{"file": "play_stomped", "screen": "play", "args": {"song_id": "rope", "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:stomped", "wait": 0.02},
		{"file": "play_tutorial", "screen": "play", "args": {"song_id": tut_id, "difficulty": "easy", "bell_set": "light", "autoplay": true}, "setup": "advance:0.25"},
		{"file": "pause", "screen": "play", "args": {"song_id": fires_id, "difficulty": "medium", "bell_set": "light", "autoplay": true}, "setup": "pause"},
		{"file": "results", "screen": "results", "setup": "results", "wait": 1.3},
		# Health: full, mid-run at 6 with a healing step on the road, low at 2, and the fail menu.
		{"file": "play_health_full", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "health": true}, "setup": "moment:dense", "wait": 0.1},
		{"file": "play_health_mid", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "health": true}, "setup": "moment:heal", "health": 6, "wait": 0.1},
		{"file": "play_health_low", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "health": true}, "setup": "moment:dense", "health": 2, "wait": 0.3},
		{"file": "play_fail", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "health": true}, "setup": "fail", "wait": 1.2},
	]
	return shots


func _render(shot: Dictionary, size: Vector2i, locale: String, dir: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	var scale := minf(size.x / BASE.x, size.y / BASE.y)
	vp.size_2d_override = Vector2i(roundi(size.x / scale), roundi(size.y / scale))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	# as the game's own window (project setting): nearest, so the pixel art stays square in the shots
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Palette.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	profile.set_setting("language", locale)
	var app: Control = load("res://scenes/main.tscn").instantiate()  # untyped: App compiles after the autoloads
	var args: Dictionary = shot.get("args", {})
	var setup := str(shot.get("setup", ""))
	if setup == "results":
		args = _results_args()
	elif setup.begins_with("tab_"):
		args = {"tab": setup.substr(4)}
	app.set("start_screen", shot.screen)
	app.set("start_args", args)
	vp.add_child(app)
	await process_frame
	await process_frame
	var screen: Control = app.call("current")
	if setup.begins_with("advance:") and screen != null:
		await _advance(screen, float(setup.get_slice(":", 1)))
	elif setup.begins_with("moment:") and screen != null:
		await _moment(screen, setup.get_slice(":", 1))
	elif setup == "resume" and screen != null:
		await _advance(screen, 0.4)
		screen.call("pause")
		await process_frame
		screen.call("_on_pause_choice", "resume")
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1000.0 * 1.15 * 60.0 / float((screen.get("session") as Session).song.bpm):
			await process_frame
	elif setup == "pause" and screen != null:
		await _advance(screen, 0.2)
		screen.call("pause")
	elif setup == "fail" and screen != null:
		await _advance(screen, 0.35)
		var fs: Session = screen.get("session")
		while not fs.has_failed:
			fs.call("_hurt")
	if shot.has("health") and screen != null:
		# Health as the shot asks; the pips read it every frame and the bonfire dims when it is low.
		var hs: Session = screen.get("session")
		hs.health = int(shot.health)
		if hs.health <= HealthPips.LOW:
			screen.set("_dim", 1.0)
	var wait := float(shot.get("wait", 0.5))
	var frames := int(wait * 60.0)
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(dir.path_join(shot.file + ".png"))
	vp.queue_free()
	await process_frame


## Moves a play screen's song to a share of its length on a manual clock, so the shot shows notes
## on the lanes, a score and some unison.
func _advance(screen: Node, share: float) -> void:
	var c: Conductor = screen.get("conductor")
	var s: Session = screen.get("session")
	if c == null or s == null:
		return
	c.use_manual_clock(true)
	var target := lerpf(s.notes[0].t if not s.notes.is_empty() else 0.0, s.end_time(), share)
	var steps := 90
	var step := maxf((target - c.song_time()) / steps, 0.0)
	for i in steps:
		c.advance(step)
		await process_frame


## Moves a play screen to a telling moment of its song on a manual clock: "dense" (the busiest two
## seconds), "hold" (half-way through a held note), "bell" (a bell cue about to reach the line),
## "still" (inside a stand-still rest), "miss" (just after a note Autoplay lets go by), "stomp" (a
## two-thumb stomp on its way), "stomped" (just after one lands) or "chord" (the most chords coming
## down at once: two steps on one beat) or "six" (the most sixteenths coming down).
func _moment(screen: Node, what: String) -> void:
	var c: Conductor = screen.get("conductor")
	var s: Session = screen.get("session")
	if c == null or s == null or s.notes.is_empty():
		return
	var from := lerpf(s.notes[0].t, s.end_time(), 0.2)
	var target := from
	match what:
		"dense":
			var best := -1
			for i in s.notes.size():
				if s.notes[i].t < from:
					continue
				var k := 0
				for j in range(i, s.notes.size()):
					if s.notes[j].t > s.notes[i].t + 2.0:
						break
					k += 1
				if k > best:
					best = k
					target = s.notes[i].t + 0.9
		"chord":
			var chords: Array[float] = []
			for i in range(1, s.notes.size()):
				var a: Note = s.notes[i - 1]
				var b: Note = s.notes[i]
				if a.kind == Note.Kind.STEP and b.kind == Note.Kind.STEP and absf(a.t - b.t) < 0.001 and a.lane != b.lane:
					chords.append(b.t)
			var most := -1
			for t0 in chords:
				var k := chords.filter(func(x: float) -> bool: return x >= t0 and x < t0 + 1.6).size()
				if k > most:
					most = k
					target = t0 - 0.35
		"six":
			# the most sixteenths (a quarter of a beat off) coming down at once, about a second away
			var sixes: Array[float] = []
			for n in s.notes:
				var fr := fposmod(n.beat, 0.5)
				if n.kind == Note.Kind.STEP and not n.call and absf(fr - 0.25) < 0.02 and n.t > c.song_time() + 1.0:
					sixes.append(n.t)
			var most_six := -1
			for t0 in sixes:
				var k := sixes.filter(func(x: float) -> bool: return x >= t0 and x < t0 + 1.4).size()
				if k > most_six:
					most_six = k
					target = t0 - 2.7   # the 120 frames of the walk there also run about 2 s of real time
		"countin":
			target = song_time_of(s, -2.35)
		"ready":
			target = minf(song_time_of(s, 0.4), s.notes[0].t - 0.2)
		"early":
			for n in s.notes:
				if n.t >= from and n.kind == Note.Kind.STEP and _clear_of_rests(s, n):
					target = n.t - _good_offset(s)
					break
		"locked":
			target = s.notes[0].t + 6.0
		"wrong":
			for i in s.notes.size():
				var n: Note = s.notes[i]
				if n.t < from or n.kind != Note.Kind.STEP or n.lane != 2:
					continue
				var lone := true
				for m in s.notes:
					if m != n and absf(m.t - n.t) < 0.6 and (m.lane == 0 or m.is_bell() or m.kind == Note.Kind.STOMP):
						lone = false
				if lone:
					target = n.t - 0.03
					break
		"late":
			var auto: Object = screen.get("autoplay")
			for i in s.notes.size():
				var n: Note = s.notes[i]
				if n.t >= from and n.kind == Note.Kind.STEP and _clear_of_rests(s, n):
					if auto != null:
						(auto.get("_plan") as Array)[i] = NAN   # the player hits this one late
					target = n.t + _good_offset(s)
					break
		"heal":
			for n in s.notes:
				if n.heal and n.t >= from:
					target = n.t - 0.9
					break
		"stillkept":
			for n in s.notes:
				if n.t >= from and n.kind == Note.Kind.REST:
					target = n.end_t + 0.45
					break
		"hold", "bell", "still", "miss", "rang", "stomp", "stomped":
			var kinds := {"hold": [Note.Kind.HOLD], "bell": [Note.Kind.BELL, Note.Kind.RING], "rang": [Note.Kind.BELL, Note.Kind.RING],
				"still": [Note.Kind.REST], "miss": [Note.Kind.STEP], "stomp": [Note.Kind.STOMP], "stomped": [Note.Kind.STOMP]}
			for i in s.notes.size():
				var n: Note = s.notes[i]
				if n.t < from or not n.kind in kinds[what]:
					continue
				match what:
					"hold", "still":
						target = lerpf(n.t, n.end_t, 0.45)
					"bell":
						target = n.t - 0.45
					"rang":
						target = n.t + 0.08
					"stomp":
						target = n.t - 0.45
					"stomped":
						target = n.t + 0.06
					"miss":
						var auto: Object = screen.get("autoplay")
						if auto != null:
							(auto.get("_plan") as Array)[i] = NAN   # this one note goes by untouched
						target = n.t + 0.22
				break
	c.use_manual_clock(true)
	var steps := 120
	var step := maxf((target - c.song_time()) / steps, 0.0)
	for i in steps:
		c.advance(step)
		await process_frame
	if what == "early":
		for n in s.notes:
			if not n.done and n.kind == Note.Kind.STEP and n.t > c.song_time():
				s.tap(n.lane, c.song_time(), 7)
				screen.call("_on_stepped", n.lane)
				break
	if what != "stillkept":
		# Only the moment in the picture: no stand-still banner left over from before it (it lasts
		# 1.5 s of real time, which a slow software render barely lets pass).
		var sm: Object = screen.get("still_moment")
		if sm != null:
			sm.call("clear")
	if what == "late":
		for n in s.notes:
			if not n.done and n.kind == Note.Kind.STEP and n.t < c.song_time():
				s.tap(n.lane, c.song_time(), 7)
				screen.call("_on_stepped", n.lane)
				break
	if what in ["early", "late"]:
		# Hold the lanes' own clock so the 0.3 s tick is caught as the player sees it, not faded by a
		# slow software render.
		var lanes: Control = screen.get("lanes")
		if lanes != null:
			lanes.set_process(false)
	if what == "showcase":
		_showcase(screen, s, c.song_time())
	if what == "locked":
		# Mashing: three random taps lock the buttons; a press while locked rattles the middle lock.
		var lanes: Control = screen.get("lanes")
		for k in 3:
			s.call("_bad_tap", c.song_time())
		for k in 8:
			await process_frame
		lanes.call("locked_tap", 1)
	if what == "wrong":
		# The player's thumb lands on the left button while the right lane's note is due.
		s.tap(0, c.song_time(), 7)
		screen.call("_on_stepped", 0)


## Every kind of note on the road at once, for the art (shot "play_showcase"): the song's own notes
## after now are replaced by a hand-made set, spread over the visible stretch of road: steps, an
## off-beat call, a healing step, a hold being held and one still coming, both bell bars, a stomp.
func _showcase(screen: Node, s: Session, now: float) -> void:
	var lanes: Control = screen.get("lanes")   # untyped: LaneView compiles after the autoloads
	var spb := 60.0 / float(s.song.bpm)
	# a slower note speed than the default, so about six beats of road show
	var ahead: float = lanes.get_script().get_script_constant_map()["LOOKAHEAD"]
	lanes.set("note_speed", ahead / (6.3 * spb))
	var b0 := ceilf(float(lanes.get("beat")) + 0.3)
	var at := func(b: float) -> float: return now + (b0 + b - float(lanes.get("beat"))) * spb
	var kept: Array[Note] = []
	for n in s.notes:
		if n.t < now - 0.6:
			kept.append(n)
	# [kind, lane, beat from the next beat, end beat (holds) or up (bells)]
	var plan := [
		["step", 0, 0.0], ["hold", 1, -1.0, 1.5], ["step", 2, 1.0], ["call", 0, 1.5],
		["bell", -1, 2.0, true], ["stomp", 2, 3.0], ["heal", 1, 3.5], ["hold", 0, 4.0, 5.0],
		["bell", -1, 4.5, false], ["step", 2, 5.0], ["step", 1, 6.0],
	]
	for p in plan:
		var n := Note.new()
		var kind: String = p[0]
		n.kind = Note.KIND_NAMES.get(kind, Note.Kind.STEP)
		n.lane = int(p[1])
		n.t = at.call(float(p[2]))
		n.end_t = at.call(float(p[3])) if kind == "hold" else n.t
		n.call = kind == "call"
		n.heal = kind == "heal"
		if kind == "bell":
			n.up = bool(p[3])
		if kind == "hold" and n.t < now:
			n.done = true
			n.holding = true
			n.judgement = "perfect"
		kept.append(n)
	for i in kept.size():
		kept[i].index = i
	s.notes = kept
	var auto: Object = screen.get("autoplay")
	if auto != null:
		# Autoplay leaves the new notes alone (the clock stands still for the picture anyway).
		var ap: Array[float] = auto.get("_plan")
		ap.resize(kept.size())
		for i in kept.size():
			if kept[i].t >= now - 0.6:
				ap[i] = NAN
	lanes.call("reset")


## An offset inside Good and outside Perfect, so the hit shows its side.
static func _good_offset(s: Session) -> float:
	var w := s.window("touch")
	return (w.x + w.y) * 0.5


## No stand-still ended in the two seconds before n (so its moment is not in the picture).
static func _clear_of_rests(s: Session, n: Note) -> bool:
	for m in s.notes:
		if m.kind == Note.Kind.REST and m.end_t <= n.t and m.end_t > n.t - 2.5:
			return false
	return true


static func song_time_of(s: Session, beat: float) -> float:
	return s.song.time_of(beat, s.remix)


func _results_args() -> Dictionary:
	var story := SongLibrary.story()
	var song: SongData = story[1] if story.size() > 1 else story[0]
	var s := _played(song, "hard", "village", true)
	var ghost := Ghost.new()
	ghost.final_score = int(s.score * 0.93)
	var next := story[2].id if story.size() > 2 else song.id
	return {"session": s, "ghost": ghost,
		"record": {"prev_best": ghost.final_score, "new_best": true, "grade": s.grade_rank(), "carving_gained": 2,
			"unlocked": [{"kind": "remix", "id": song.remix_id() if song.has_remix() else song.id}, {"kind": "song", "id": next}]},
		"play_args": {"song_id": song.id, "difficulty": "hard", "bell_set": "village"}}
