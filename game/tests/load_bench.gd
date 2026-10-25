extends SceneTree
## How heavy the app is to start and to open a song: the time from engine start to this script
## (the autoloads, Sound's samples among them), the time to build the play screen and draw its first
## frame, and the memory and video memory in use once the song runs.
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/load_bench.gd -- [song] [difficulty]

var _frames := 0
var _t_build := 0


func _init() -> void:
	var boot := Time.get_ticks_msec()
	var a := OS.get_cmdline_user_args()
	var song_id := a[0] if a.size() > 0 else "piazza"
	var diff := a[1] if a.size() > 1 else "hard"
	await process_frame
	var profile: Node = root.get_node("/root/Profile")
	profile.load_profile("user://load_bench_profile.cfg")
	profile.reset()
	for f in profile.FLAGS:
		profile.set_flag(f, true)
	var t0 := Time.get_ticks_usec()
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.set("start_screen", "play")
	app.set("start_args", {"song_id": song_id, "difficulty": diff, "autoplay": true})
	root.add_child(app)
	_t_build = Time.get_ticks_usec() - t0
	await process_frame
	await process_frame
	var first := Time.get_ticks_usec() - t0
	await create_timer(3.0).timeout
	print("LOAD boot=%dms play_build=%.1fms first_frame=%.1fms static_mem=%.1fMB video_mem=%.1fMB textures=%.1fMB objects=%d" % [
		boot, _t_build / 1000.0, first / 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_COUNT)])
	profile.load_profile()
	quit()
