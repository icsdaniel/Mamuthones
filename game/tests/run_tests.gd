extends SceneTree
## Runs every game/tests/**/test_*.gd. Pass a folder name after -- to run only that folder:
##   godot --headless --path game -s res://tests/run_tests.gd -- core


func _init() -> void:
	var only: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var files := _find("res://tests")
	files.sort()
	var total_checks := 0
	var total_failures := 0
	await process_frame
	for path in files:
		if only != "" and not path.begins_with("res://tests/%s/" % only):
			continue
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL: could not load %s" % path)
			total_failures += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.tree = self
			await test.call(name)
			total_checks += test.checks
			for f in test.failures:
				printerr("FAIL %s:%s: %s" % [path.get_file(), name, f])
			total_failures += test.failures.size()
	# Let any sound a test started finish, so nothing is left in use at exit.
	var sound := root.get_node_or_null("Sound")
	if sound != null and sound.has_method("stop_all"):
		sound.stop_all()
	await create_timer(0.5).timeout
	print("%d checks, %d failed" % [total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)


func _find(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_find(dir.path_join(sub)))
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
