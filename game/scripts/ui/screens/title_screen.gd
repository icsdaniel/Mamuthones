extends Screen
## Title: the logo alone on the calm backdrop, then in the bottom half the red banner that always says
## what to do next (the next story stop), the four modes in two columns, a gold rule and Settings.
## No scene art. Scores are in free play, the calibration in Settings, and there is no Quit (phones
## close apps their own way; Android's back leaves from here) (graphics review, 2026-10-28).


var _play: Button


func build() -> void:
	var next_id := Progression.next_stop()
	var next_song := SongLibrary.get_song(next_id)
	var safe := UIKit.safe_margins(self)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- the logo alone on the calm ground (no scene art)
	var top := Control.new()
	top.name = "Top"
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.custom_minimum_size.y = 300
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var logo := Logo.new()
	logo.name = "Logo"
	logo.mode = "title"
	logo.subtitle = ""   # the name stands on its own
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.offset_top = 56.0 + safe.y
	logo.offset_bottom = -56.0
	logo.offset_left = 0.0
	logo.offset_right = 0.0
	top.add_child(logo)
	Sound.stop_ambience()   # no background loops (Daniele, 2026-10-15)

	# ---- the menu
	var margin := MarginContainer.new()
	margin.name = "Menu"
	margin.add_theme_constant_override("margin_left", int(UIKit.GUTTER + safe.x))
	margin.add_theme_constant_override("margin_right", int(UIKit.GUTTER + safe.z))
	margin.add_theme_constant_override("margin_bottom", int(24 + safe.w))
	root.add_child(margin)
	var center := CenterWidth.new()
	center.max_width = UIKit.COLUMN_MAX
	margin.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var holder := Control.new()
	holder.custom_minimum_size.y = UIKit.TOUCH
	box.add_child(holder)
	_play = UIKit.button("", _play_next, UIKit.PRIMARY)
	_play.name = "PlayNext"
	_play.text = tr("title_continue") % UIKit.song_title(next_song) if next_song != null else tr("title_procession")
	_play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_play)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for item in [
		["StoryMap", "title_story", func() -> void: app.open("story")],
		["FreePlay", "title_free", func() -> void: app.open("free_play")],
		["Tutorial", "title_tutorial", func() -> void: app.open("tutorial")],
		["Settings", "title_settings", func() -> void: app.open("settings")],
	]:
		var b := UIKit.button(tr(item[1]), item[2])
		b.name = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)


func _play_next() -> void:
	var id := Progression.next_stop()
	if id == "" or SongLibrary.get_song(id) == null:
		app.open("story")
	else:
		app.open("stop_card", {"song_id": id})


## Tests set this to count quits instead of leaving.
static var quit_calls := 0
static var really_quit := true


func quit_game() -> void:
	quit_calls += 1
	Sound.stop_all()
	if really_quit:
		get_tree().quit()


func on_back() -> void:
	# The title is the bottom of the stack: Android back leaves the game.
	quit_game()
