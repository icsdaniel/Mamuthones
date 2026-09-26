extends Screen
## Title: the logo, then the player's own Mamuthone walking in the procession at their next stop. The first button always
## says what to do next (the next story stop), the rest lead to every other mode.

var scene: ProcessionScene


func build() -> void:
	var next_id := Progression.next_stop()
	var next_song := SongLibrary.get_song(next_id)
	var stop := next_song.stop if next_song != null else maxi(Progression.highest_stop(), 1)
	var box := UIKit.column(self, false, 12)
	var logo := Logo.new()
	logo.name = "Logo"
	logo.show_title = true
	logo.subtitle = tr("app_title")
	logo.custom_minimum_size = Vector2(0, 330)
	logo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	logo.size_flags_stretch_ratio = 1.1
	box.add_child(logo)
	# Your own Mamuthone walking at the next stop, lit, between the logo and the menu.
	scene = ProcessionScene.new()
	scene.name = "Procession"
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.custom_minimum_size = Vector2(0, 250)
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.auto_bpm = 76.0
	box.add_child(scene)
	scene.set_stop(stop)
	UIKit.show_look(scene)
	scene.set_unison(3)
	scene.set_reduced_motion(UIKit.reduced_motion())
	Sound.ambience(UIKit.ambience_for(stop))

	var play := UIKit.button("", _play_next, UIKit.PRIMARY)
	play.name = "Procession"
	play.text = tr("title_continue") % UIKit.song_title(next_song) if next_song != null else tr("title_procession")
	play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(play)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for item in [
		["StoryMap", "title_story", func() -> void: app.open("story")],
		["FreePlay", "title_free", func() -> void: app.open("free_play")],
		["Piazza", "title_piazza", func() -> void: app.open("piazza")],
		["Daily", "title_daily", func() -> void: app.open("daily")],
		["Workshop", "title_workshop", func() -> void: app.open("workshop")],
		["Leaderboards", "title_boards", _boards],
	]:
		var b := UIKit.button(tr(item[1]), item[2])
		b.name = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var settings := UIKit.button(tr("title_settings"), func() -> void: app.open("settings"), UIKit.QUIET)
	settings.name = "Settings"
	box.add_child(settings)


func _play_next() -> void:
	var id := Progression.next_stop()
	if id == "" or SongLibrary.get_song(id) == null:
		app.open("story")
	else:
		app.open("stop_card", {"song_id": id})


func _boards() -> void:
	app.open("boards")


func on_back() -> void:
	# The title is the bottom of the stack: Android back leaves the game.
	get_tree().quit()
