extends SceneTree
## Starts a song in Autoplay for recording with Godot's movie maker:
##   godot --path game --rendering-driver opengl3 --resolution 720x1440 --write-movie out.avi \
##       --fixed-fps 60 -s res://tests/record.gd -- <song_id> <difficulty> [remix] [human] [bells=<set>]
##       [from=<beat>] [style=pixel|painted]
## Plays the song through to the results screen, holds the results for a few seconds, then quits.
## Uses a throwaway profile, so the recording never changes the player's own progress.

const PROFILE := "user://record_profile.cfg"
const HOLD_RESULTS := 6.0

var _app: Control  ## the App (not typed: this script compiles before the autoloads exist)
var _frames_on_results := 0

## The Profile autoload, looked up at run time (this script compiles before autoloads exist).
var profile: Node


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var song_id := a[0] if a.size() > 0 else "fires"
	var diff := a[1] if a.size() > 1 else "hard"
	var bells := "light"
	for x in a:
		if x.begins_with("bells="):
			bells = x.substr(6)
	await process_frame
	profile = root.get_node("/root/Profile")
	profile.load_profile(PROFILE)
	profile.reset()
	for f in profile.FLAGS:
		profile.set_flag(f, true)
	if SongLibrary.get_song(song_id) == null:
		printerr("record: unknown song '%s'. Songs: %s" % [song_id, ", ".join(SongLibrary.all().map(func(s: SongData) -> String: return s.id))])
		quit(1)
		return
	_app = load("res://scenes/main.tscn").instantiate()
	_app.set("start_screen", "play")
	var start := {"song_id": song_id, "difficulty": diff, "bell_set": bells, "remix": "remix" in a,
		"autoplay": true, "human": "human" in a, "piazza": diff == "piazza"}
	for x in a:
		# from=<beat>: start a short way into the song (with --quit-after, a clip of the action)
		if x.begins_with("from="):
			start.from_beat = float(x.substr(5))
			start.to_beat = float(x.substr(5)) + 64.0
		elif x.begins_with("style="):
			profile.set_setting("art_style", x.substr(6))
	_app.set("start_args", start)
	root.add_child(_app)
	process_frame.connect(_tick)


## Frames are fixed-length under --fixed-fps, so counting them holds the results for real seconds
## of the recording.
func _tick() -> void:
	var s: Control = _app.call("current")
	if s == null or str(s.call("screen_name")) != "results_screen":
		return
	_frames_on_results += 1
	if _frames_on_results > HOLD_RESULTS * 60.0:
		profile.load_profile()
		quit()
