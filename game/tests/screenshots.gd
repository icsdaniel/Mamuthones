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
	profile.set_piazza_players(["Giovanni", "Maria", "Antonio", "Grazia"])


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
		{"file": "daily", "screen": "daily"},
		{"file": "boards", "screen": "boards"},
		{"file": "piazza", "screen": "piazza"},
		{"file": "piazza_turn", "screen": "piazza", "args": {"round": _round(1)}},
		{"file": "piazza_ranking", "screen": "piazza_ranking", "args": {"round": _round(4)}, "wait": 1.4},
		{"file": "settings", "screen": "settings"},
		{"file": "credits", "screen": "credits"},
		{"file": "workshop", "screen": "workshop", "setup": "tab_mask", "wait": 0.8},
		{"file": "workshop_bells", "screen": "workshop", "setup": "tab_bells", "wait": 0.8},
		{"file": "workshop_dress", "screen": "workshop", "setup": "tab_dress", "wait": 0.8},
		{"file": "tutorial", "screen": "tutorial", "args": {"song_id": tut_id, "first_run": true}, "wait": 1.2},
		{"file": "play_fires", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true, "human": true}, "setup": "advance:0.42"},
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
		{"file": "play_wrong", "screen": "play", "args": {"song_id": fires_id, "difficulty": "hard", "bell_set": "light", "autoplay": true}, "setup": "moment:wrong", "wait": 0.05},
		{"file": "play_tutorial", "screen": "play", "args": {"song_id": tut_id, "difficulty": "easy", "bell_set": "light", "autoplay": true}, "setup": "advance:0.25"},
		{"file": "pause", "screen": "play", "args": {"song_id": fires_id, "difficulty": "medium", "bell_set": "light", "autoplay": true}, "setup": "pause"},
		{"file": "results", "screen": "results", "setup": "results", "wait": 1.3},
	]
	var piazza := SongLibrary.piazza()
	if not piazza.is_empty():
		shots.append({"file": "play_piazza_hit", "screen": "play", "args": {"song_id": piazza[0].id, "difficulty": "piazza", "bell_set": "light", "piazza": true, "autoplay": true, "round": _round(1)}, "setup": "moment:rang", "wait": 0.05})
		shots.append({"file": "play_piazza", "screen": "play", "args": {"song_id": piazza[0].id, "difficulty": "piazza", "bell_set": "light", "piazza": true, "autoplay": true, "round": _round(1)}, "setup": "advance:0.3"})
	return shots


func _round(turn: int) -> Dictionary:
	var songs := SongLibrary.piazza()
	return {"song_id": songs[0].id if not songs.is_empty() else "", "players": ["Giovanni", "Maria", "Antonio", "Grazia"],
		"scores": [48250, 51900, 39600, 45100], "turn": turn}


func _render(shot: Dictionary, size: Vector2i, locale: String, dir: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	var scale := minf(size.x / BASE.x, size.y / BASE.y)
	vp.size_2d_override = Vector2i(roundi(size.x / scale), roundi(size.y / scale))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
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
## "still" (inside a stand-still rest) or "miss" (just after a note Autoplay lets go by).
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
		"countin":
			target = song_time_of(s, -2.35)
		"ready":
			target = minf(song_time_of(s, 0.4), s.notes[0].t - 0.2)
		"early":
			for n in s.notes:
				if n.t >= from and n.kind == Note.Kind.STEP and _clear_of_rests(s, n):
					target = n.t - _good_offset(s)
					break
		"wrong":
			for i in s.notes.size():
				var n: Note = s.notes[i]
				if n.t < from or n.kind != Note.Kind.STEP or n.lane != 2:
					continue
				var lone := true
				for m in s.notes:
					if m != n and absf(m.t - n.t) < 0.6 and (m.lane == 0 or m.is_bell() or m.kind == Note.Kind.SWIPE):
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
		"stillkept":
			for n in s.notes:
				if n.t >= from and n.kind == Note.Kind.REST:
					target = n.end_t + 0.45
					break
		"hold", "bell", "still", "miss", "rang":
			var kinds := {"hold": [Note.Kind.HOLD], "bell": [Note.Kind.BELL, Note.Kind.RING], "rang": [Note.Kind.BELL, Note.Kind.RING],
				"still": [Note.Kind.REST], "miss": [Note.Kind.STEP]}
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
	if what == "wrong":
		# The player's thumb lands on the left button while the right lane's note is due.
		s.tap(0, c.song_time(), 7)
		screen.call("_on_stepped", 0)


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
		"record": {"prev_best": ghost.final_score, "new_best": true, "bells": s.bells(), "carving_gained": 2,
			"unlocked": [{"kind": "remix", "id": song.remix_id() if song.has_remix() else song.id}, {"kind": "song", "id": next}]},
		"play_args": {"song_id": song.id, "difficulty": "hard", "bell_set": "village"}}
