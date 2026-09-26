extends SceneTree
## Decodes loops through Godot's own playback (mix_audio), past the loop point, and
## writes raw float32 stereo to <out_dir>/<name>.f32 so measure.py can check the seam
## exactly as the game will play it.
##   godot --headless --path <game copy> -s <this file> -- <out_dir>

func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var paths: Array[String] = []
	for dir in ["res://audio/sfx/loops", "res://audio/sfx/ambience"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".ogg"):
				paths.append(dir + "/" + f)
	for p in paths:
		var st := load(p) as AudioStreamOggVorbis
		st.loop = true
		var pb := st.instantiate_playback()
		pb.start(0.0)
		var total := int((st.get_length() + 0.5) * 44100.0)
		var buf := PackedVector2Array()
		while buf.size() < total:
			buf.append_array(pb.mix_audio(1.0, 4096))
		var f := FileAccess.open(out_dir.path_join(p.get_file().get_basename() + ".f32"), FileAccess.WRITE)
		f.store_buffer(buf.to_byte_array())
		f.close()
	print("decoded %d loops" % paths.size())
	quit()
