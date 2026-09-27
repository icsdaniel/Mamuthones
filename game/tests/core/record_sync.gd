extends SceneTree
## Checks that recordings (movie maker) keep sound and picture together. Records a click track
## through a Conductor; clicks sit at song times 1, 2, 3 ... s and the log says at which video time song time crossed each one.
##   xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 90x180 \
##     --write-movie /tmp/sync/out.png --fixed-fps 60 -s res://tests/core/record_sync.gd
##   python3 game/tests/core/record_sync.py /tmp/sync/out.wav
## The clicks in the WAV must land at 1.5, 2.5, 3.5 ... s (within 1 ms; measured: exact).

var c: Conductor
var n := 0
var next_click := 1.0


func _initialize() -> void:
	c = Conductor.new()
	root.add_child(c)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	var data := PackedByteArray()
	data.resize(44100 * 2 * 8)
	for k in range(1, 8):
		for i in 200:
			data.encode_s16((k * 44100 + i) * 2, 20000 if i < 100 else -20000)
	wav.data = data
	var song := SongData.from_dict({"id": "clicks", "bpm": 60, "offset": 0.0, "length": 8.0, "charts": {}})
	c.play(song, false, 0.0)
	c.player.stream = wav
	c.seek(-0.5)


func _process(_d: float) -> bool:
	var t := c.song_time()
	if t >= next_click:
		# Frame n is shown at video time n/60 with song time t, so the click belongs at n/60 - (t - click).
		print("click %.0f: frame %d song_time %.4f -> expected video time %.4f" % [next_click, n, t, n / 60.0 - (t - next_click)])
		next_click += 1.0
	n += 1
	if n >= 60 * 7:
		quit()
	return false
