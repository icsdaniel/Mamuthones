extends SceneTree
## Measures how heavy the play screen is: starts a song in Autoplay at a dense spot and prints the
## average and worst frame times, and how much of them the scripts take.
##   godot --path game --rendering-driver opengl3 --resolution 1080x2400 -s res://tests/bench.gd -- \
##       [song] [difficulty] [from=<beat>] [style=pixel|painted] [frames=<n>]
## Absolute numbers on a desktop or a software renderer are not a phone's; compare runs instead.

const PROFILE := "user://bench_profile.cfg"
const WARMUP := 60

var profile: Node
var _frames := 0
var _n := 300
var _last := 0
var _times: Array[float] = []
var _script := 0.0
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
	var start := {"song_id": song_id, "difficulty": diff, "bell_set": "light", "remix": false,
		"autoplay": true, "human": false, "piazza": false, "from_beat": 120.0, "to_beat": 184.0}
	for x in a:
		if x.begins_with("from="):
			start.from_beat = float(x.substr(5))
			start.to_beat = start.from_beat + 64.0
		elif x.begins_with("style="):
			profile.set_setting("art_style", x.substr(6))
		elif x == "vpint":
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
			root.content_scale_size = Vector2i(540, 1080)
		elif x == "vp":
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		elif x.begins_with("frames="):
			_n = int(x.substr(7))
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
		_script += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_last = now
	if _times.size() == 1:
		# reset the lanes' draw timing to the measured window
		var LV0: Script = load("res://scripts/ui/lane_view.gd")
		LV0.set("draw_usec", 0)
		LV0.set("draw_count", 0)
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
		profile.load_profile()
		quit()
