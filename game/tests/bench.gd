extends SceneTree
## Measures how heavy the play screen is: starts a song in Autoplay at a dense spot and prints the
## average and worst frame times, and how much of them the scripts take.
##   godot --path game --rendering-driver opengl3 --resolution 1080x2400 -s res://tests/bench.gd -- \
##       [song] [difficulty] [from=<beat>] [frames=<n>] [anim=full|calm|off]
##       [warm=<ms>] [hide=<Node>]
## Absolute numbers on a desktop or a software renderer are not a phone's; compare runs instead.

const PROFILE := "user://bench_profile.cfg"
const WARMUP := 60

var profile: Node
var _frames := 0
var _n := 300
var _last := 0
var _times: Array[float] = []
var _script := 0.0
var _draws := 0.0        ## draw calls and primitives summed over the measured frames
var _prims := 0.0
var _shrunk0 := -1       ## pictures shrunk when measuring began (more by the end: made mid-song)
var _keys0: Array = []
var _t0 := 0
var _warm_ms := 5000     ## real time before measuring: the count-in is over and notes are coming


func _init() -> void:
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	var a := OS.get_cmdline_user_args()
	var song_id := a[0] if a.size() > 0 and not "=" in a[0] else "fires"
	var diff := a[1] if a.size() > 1 and not "=" in a[1] else "hard"
	await process_frame
	profile = root.get_node("/root/Profile")
	profile.load_profile(PROFILE)
	profile.reset()
	for f in profile.FLAGS:
		profile.set_flag(f, true)
	var start := {"song_id": song_id, "difficulty": diff, "remix": false,
		"autoplay": true, "human": false, "from_beat": 120.0, "to_beat": 184.0}
	for x in a:
		if x.begins_with("from="):
			start.from_beat = float(x.substr(5))
			start.to_beat = start.from_beat + 64.0
		elif x == "vpint":
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
			root.content_scale_size = Vector2i(540, 1080)
		elif x == "vp":
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		elif x.begins_with("frames="):
			_n = int(x.substr(7))
		elif x.begins_with("anim="):
			profile.set_setting("animations", x.substr(5))
		elif x.begins_with("warm="):
			_warm_ms = int(x.substr(5))
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.set("start_screen", "play")
	app.set("start_args", start)
	root.add_child(app)
	_t0 = Time.get_ticks_msec()
	process_frame.connect(_tick)
	for x in a:
		# hide=<Name>: hides every node of that name, to see what it costs
		if x.begins_with("hide="):
			await create_timer(0.5).timeout
			for nd in root.find_children(x.substr(5), "", true, false):
				if nd is CanvasItem:
					nd.visible = false
					print("hid ", nd.get_path())


func _tick() -> void:
	var now := Time.get_ticks_usec()
	_frames += 1
	if Time.get_ticks_msec() - _t0 > _warm_ms:
		_times.append((now - _last) / 1000.0)
		if _times[-1] > 25.0 and _times.size() > 5:
			# a hitch: where in the song, and how much of it the lanes' drawing took
			var lv: Object = root.find_child("Lanes", true, false)
			if lv != null:
				print("HITCH %.1f ms (lanes drawing %.1f ms) at frame %d, beat %.2f" % [_times[-1],
					float(load("res://scripts/ui/lane_view.gd").get("last_draw_usec")) / 1000.0, _times.size() - 1, float(lv.get("beat"))])
		_script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_last = now
	if _times.size() == 1:
		# reset the lanes' draw timing to the measured window
		var LV0: Script = load("res://scripts/ui/lane_view.gd")
		LV0.set("draw_usec", 0)
		LV0.set("draw_count", 0)
		_keys0 = (load("res://scripts/art/street_skin.gd").get("_ai_sized") as Dictionary).keys()
		_shrunk0 = _keys0.size()
	if _times.size() >= _n:
		var sorted := _times.duplicate()
		sorted.sort()
		var avg := 0.0
		for t in _times:
			avg += t
		avg /= _times.size()
		var lv: Object = root.find_child("Lanes", true, false)
		var shown := 0
		if lv != null:
			shown = (lv.call("_notes_shown", lv.call("field_rect")) as Array).size()
		var LV: Script = load("res://scripts/ui/lane_view.gd")
		print("LANES draw=%.2fms per draw over %d draws, notes on screen now=%d" % [LV.get("draw_usec") / 1000.0 / maxf(1.0, LV.get("draw_count")), LV.get("draw_count"), shown])
		print("BENCH frames=%d avg=%.2fms p95=%.2fms worst=%.2fms script=%.2fms objects=%d" % [_times.size(), avg,
			sorted[int(sorted.size() * 0.95)], sorted[-1], _script / _times.size(),
			Performance.get_monitor(Performance.OBJECT_COUNT)])
		# what the GPU is asked for: draw calls a frame, and the pictures drawn into before the screen
		var vps: Array[String] = []
		for vp in root.find_children("*", "SubViewport", true, false):
			if (vp as SubViewport).render_target_update_mode == SubViewport.UPDATE_ALWAYS:
				vps.append("%s %dx%d" % [vp.name, (vp as SubViewport).size.x, (vp as SubViewport).size.y])
		var sk: Script = load("res://scripts/art/street_skin.gd")
		var sheet: Object = sk.get("atlas")
		var tex: Texture2D = sheet.get("_tex") if sheet != null else null
		var shrunk := (sk.get("_ai_sized") as Dictionary).size()
		var late: Array = (sk.get("_ai_sized") as Dictionary).keys().filter(func(k: String) -> bool: return not k in _keys0)
		print("PICTURES shrunk=%d (%d of them while measuring: %s) note_sheet=%s" % [shrunk, late.size(), ", ".join(late), str(tex.get_size()) if tex != null else "-"])
		print("RENDER draw_calls=%.0f primitives=%.0f window=%dx%d live_viewports=[%s] video_mem=%.1fMB" % [_draws / _times.size(),
			_prims / _times.size(), root.size.x, root.size.y, ", ".join(vps),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		var slow: Array[String] = []
		for i in _times.size():
			if _times[i] > avg * 3.0:
				slow.append("%d:%.1f" % [i, _times[i]])
		# frames over 25 ms: a hitch a player would feel
		var hitches := 0
		for t in _times:
			if t > 25.0:
				hitches += 1
		print("HITCHES over 25 ms: %d of %d" % [hitches, _times.size()])
		print("SLOW frames (over 3x the average): ", ", ".join(slow))
		profile.load_profile()
		quit()
