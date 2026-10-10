extends SceneTree
## Logs the play screen's first seconds: each frame's length and how far song time moved in it,
## to find hitches at the start of a song.
##   godot --path game -s res://tests/start_profile.gd -- [song] [difficulty]

var _t0 := 0
var _last := 0
var _last_song := NAN
var _conductor: Node
var _gap_max := 0.0
var _gap_sum := 0.0
var _gap_n := 0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var song_id := a[0] if a.size() > 0 and not "=" in a[0] else "shrove"
	var diff := a[1] if a.size() > 1 and not "=" in a[1] else "expert"
	await process_frame
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.set("start_screen", "play")
	app.set("start_args", {"song_id": song_id, "difficulty": diff, "remix": false,
		"autoplay": true, "human": false})
	_t0 = Time.get_ticks_usec()
	_last = _t0
	root.add_child(app)
	process_frame.connect(_tick)


func _tick() -> void:
	var now := Time.get_ticks_usec()
	if _conductor == null:
		_conductor = root.find_child("Conductor", true, false)
	var st := NAN
	if _conductor != null and _conductor.has_method("song_time"):
		st = _conductor.call("song_time")
	# how far the time the notes are drawn at strays from the song's clock (PlayScreen._visual_time)
	var play := root.find_child("Play", true, false)
	var lv := root.find_child("Lanes", true, false)
	if play != null and lv != null and not is_nan(st) and st > 5.0:
		var g := absf(float(lv.get("song_time")) - float(play.get("_song_t"))) * 1000.0
		_gap_max = maxf(_gap_max, g)
		_gap_sum += g
		_gap_n += 1
	var dt := (now - _last) / 1000.0
	var ds := (st - _last_song) * 1000.0 if not is_nan(_last_song) else 0.0
	if dt > 25.0 or absf(ds - dt) > 20.0:
		print("t=%7.1fms frame=%6.1fms song=%7.3f dsong=%6.1fms" % [(now - _t0) / 1000.0, dt, st, ds])
	_last = now
	_last_song = st
	if now - _t0 > 14_000_000:
		print("END shown time vs song clock: mean %.2f ms, worst %.2f ms" % [_gap_sum / maxf(_gap_n, 1), _gap_max])
		quit()
