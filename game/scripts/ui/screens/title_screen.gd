extends Screen
## Title: the logo alone on the calm backdrop, then in the bottom half the red banner that always says
## what to do next (the next story stop), the four modes in two columns, a gold rule and Settings.
## No scene art. Scores are in free play, the calibration in Settings, and there is no Quit (phones
## close apps their own way; Android's back leaves from here) (graphics review, 2026-10-28).


var _play: Button


const SHEET := Color("#efe6d2")
const K := Color("#141014")
const R := Color("#c8352a")
const G := Color("#c9bba0")
const MENU_H := 520.0           ## the cream sheet's least height (base px)


## "Controluce" (Daniele's main menu, rounds 1-23 on the review page): the Mamuthone's black mask
## close up, lit from behind by the bonfire, bobbing on the beat, the logo under it; below, a cream
## sheet with the red Continue plate, Story and Songs, and Learn and the gear.
func build() -> void:
	var next_id := Progression.next_stop()
	var next_song := SongLibrary.get_song(next_id)
	var safe := UIKit.safe_margins(self)
	var bg := ColorRect.new()
	bg.color = K
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := TitleArt.new()
	top.name = "Top"
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.custom_minimum_size.y = 300
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var logo := Control.new()      # tests look for the logo: it is drawn in the picture
	logo.name = "Logo"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(logo)
	Sound.stop_ambience()   # no background loops (Daniele, 2026-10-15)

	# ---- the cream sheet
	var sheet := PanelContainer.new()
	sheet.name = "Sheet"
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHEET
	sb.border_color = K
	sb.border_width_top = 8
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.custom_minimum_size.y = MENU_H + safe.w
	root.add_child(sheet)
	var margin := MarginContainer.new()
	margin.name = "Menu"
	margin.add_theme_constant_override("margin_left", int(UIKit.GUTTER + safe.x))
	margin.add_theme_constant_override("margin_right", int(UIKit.GUTTER + safe.z))
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", int(24 + safe.w))
	sheet.add_child(margin)
	var center := CenterWidth.new()
	center.max_width = UIKit.COLUMN_MAX
	margin.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	_play = UIKit.button("", _play_next, UIKit.PRIMARY)
	_play.name = "PlayNext"
	_play.text = tr("title_continue") % UIKit.song_title(next_song) if next_song != null else tr("title_procession")
	if lessons_first():
		_play.text = tr("title_learn")
	_play.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_play.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_play.custom_minimum_size.y = 168
	_block(_play, R, Color("#efe6d2"), PxType.LINE * 4)
	box.add_child(_play)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	box.add_child(grid)
	for item in [
		["StoryMap", "title_story", func() -> void: app.open("story")],
		["FreePlay", "title_free", func() -> void: app.open("free_play")],
	]:
		var b := UIKit.button(tr(item[1]), item[2])
		b.name = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = UIKit.TOUCH
		_block(b, G, K, PxType.LINE * 3)
		grid.add_child(b)

	var rule := ColorRect.new()
	rule.color = Color("#4a3c38")
	rule.custom_minimum_size.y = 4
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for item in [
		["Tutorial", "title_tutorial", func() -> void: app.open("tutorial"), true],
		["Settings", "title_settings", func() -> void: app.open("settings"), false],
	]:
		var b := UIKit.button(tr(item[1]), item[2])
		b.name = item[0]
		b.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if item[3] else HORIZONTAL_ALIGNMENT_RIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(c, K)
		b.add_theme_color_override("font_pressed_color", R)
		b.add_theme_color_override("font_hover_pressed_color", R)
		row.add_child(b)


## A hard-shadow block on the sheet (the Controluce plates): `fill` in a black outline, its shadow
## straight down; pressed it sinks onto its shadow.
func _block(b: Button, fill: Color, ink: Color, font_size: int) -> void:
	for st in ["normal", "hover", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = K
		sb.set_border_width_all(4)
		sb.shadow_color = K
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, 12)
		sb.expand_margin_bottom = 0
		sb.anti_aliasing = false
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		b.add_theme_stylebox_override(st, sb)
		if st == "focus":
			var f := StyleBoxEmpty.new()
			b.add_theme_stylebox_override(st, f)
	for st in ["pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.border_color = K
		sb.set_border_width_all(4)
		sb.anti_aliasing = false
		sb.content_margin_left = 28
		sb.content_margin_right = 28
		sb.content_margin_top = 24
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_font_size_override("font_size", font_size)
	b.draw.connect(func() -> void:
		if not b.button_pressed:
			b.draw_rect(Rect2(0, b.size.y, b.size.x, 12), K))


## A new player's red banner leads to the lessons, not straight into a song with hearts (outside
## review, 2026-10-31). Once the lessons are done, or any stop is cleared, it names the next stop.
static func lessons_first() -> bool:
	if Profile.has_flag("tutorial_done"):
		return false
	for id in Progression.story_order():
		if Progression.cleared(id):
			return false
	return true


func _play_next() -> void:
	if lessons_first():
		app.open("tutorial")
		return
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
