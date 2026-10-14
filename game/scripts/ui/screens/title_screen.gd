extends Screen
## Title, on the mobile kit: the bonfire scene is the hero, full bleed down to the menu, with the
## MAMUTHONES word mark in its starry sky. In the thumb zone: one big red Play (the next story stop,
## named under the word) and a bar of four icon tabs (Story, Free play, Workshop, Scores). Settings
## is the round gear in the top-right corner (the tutorial and the calibration live there); Quit is
## a round power button top-left on desktop only (phones and browsers leave apps their own way).

const BPM := 76.0
## How far the menu reaches up over the scene's foot.
const OVERLAP := 120.0
## The scene picture's height on the art grid (title_scene.png is 250 art px tall).
const PICTURE_H := 250.0 * 3.0

var scene: TitleScene
var _play: Button
var _logo: Logo
var _sky: _Stars
var _top: Control
var _menu: Control


func build() -> void:
	var next_id := Progression.next_stop()
	var next_song := SongLibrary.get_song(next_id)
	var stop := next_song.stop if next_song != null else maxi(Progression.highest_stop(), 1)
	var safe := UIKit.safe_margins(self)

	# ---- the scene, full bleed behind everything
	_top = Control.new()
	_top.name = "Top"
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	scene = TitleScene.new()
	scene.name = "Scene"
	scene.bpm = BPM
	scene.reduced_motion = UIKit.reduced_motion()
	_top.add_child(scene)
	scene.set_look(str(Profile.get_look().get("fleece", "black")))
	# Above the picture on a tall phone: the same stars as the picture's sky, so there is no flat band.
	_sky = _Stars.new()
	_top.add_child(_sky)
	var foot := _SceneFoot.new()
	foot.name = "Foot"
	_top.add_child(foot)
	_logo = Logo.new()
	_logo.name = "Logo"
	_logo.mode = "title"
	_logo.subtitle = tr("app_title")
	_top.add_child(_logo)
	Sound.ambience(UIKit.ambience_for(stop))

	# ---- the corners: Quit (desktop only) on the left, the settings gear on the right
	var corners := HBoxContainer.new()
	corners.name = "Corners"
	corners.set_anchors_preset(Control.PRESET_TOP_WIDE)
	corners.offset_left = UIKit.GUTTER * 0.5 + safe.x
	corners.offset_right = -UIKit.GUTTER * 0.5 - safe.z
	corners.offset_top = UIKit.S2 + safe.y
	corners.offset_bottom = corners.offset_top + UIKit.TOUCH
	corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corners)
	if quit_offered():
		var quit := UIKit.icon_button("power", quit_game, tr("title_quit"))
		quit.icon = KitIcons.get_icon("power")
		quit.name = "Quit"
		corners.add_child(quit)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corners.add_child(gap)
	var gear := UIKit.icon_button("gear", func() -> void: app.open("settings"), tr("title_settings"))
	gear.icon = KitIcons.get_icon("gear")
	gear.name = "Settings"
	corners.add_child(gear)

	# ---- the menu in the thumb zone
	var margin := MarginContainer.new()
	margin.name = "Menu"
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", int(UIKit.GUTTER + safe.x))
	margin.add_theme_constant_override("margin_right", int(UIKit.GUTTER + safe.z))
	margin.add_theme_constant_override("margin_bottom", int(UIKit.S4 + safe.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_menu = margin
	var center := CenterWidth.new()
	center.max_width = UIKit.COLUMN_MAX
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.S3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	var sub := tr("title_procession")
	if next_song != null:
		sub = tr("title_hero_sub") % [next_song.stop, UIKit.song_title(next_song)]
	_play = MenuKit.hero_button(tr("stop_play"), sub, _play_next)
	_play.name = "PlayNext"
	box.add_child(_play)
	MenuKit.tab_bar(box, [
		["StoryMap", "flame", tr("title_story"), func() -> void: app.open("story")],
		["FreePlay", "note", tr("title_free"), func() -> void: app.open("free_play")],
		["Workshop", "bell", tr("title_workshop"), func() -> void: app.open("workshop")],
		["Leaderboards", "ladder", tr("title_boards"), _boards],
	])
	resized.connect(_layout)
	margin.resized.connect(_layout)
	_layout.call_deferred()


## The scene ends a little under the top of the menu; the picture sits at its foot, the stars fill
## the sky above it, and the word mark is centred in the sky left above the scene's rooftops.
func _layout() -> void:
	if _menu == null:
		return
	var menu_top := size.y - _menu.size.y
	var scene_h := menu_top + OVERLAP
	scene.position = Vector2.ZERO
	scene.size = Vector2(size.x, scene_h)
	_sky.position = Vector2.ZERO
	_sky.size = Vector2(size.x, maxf(scene_h - PICTURE_H, 0.0))
	var foot: Control = _top.get_node("Foot")
	foot.position = Vector2(0.0, menu_top - 96.0)
	foot.size = Vector2(size.x, scene_h - (menu_top - 96.0))
	var safe := UIKit.safe_margins(self)
	var logo_h := 156.0
	var room_top := safe.y + UIKit.S2 + UIKit.TOUCH
	# the open sky: down to where the picture's houses start (about its top fifth is sky)
	var sky_end := scene_h - PICTURE_H * 0.78
	var y := maxf(room_top, (room_top + sky_end - logo_h) * 0.5)
	_logo.position = Vector2(UIKit.S2, roundf(y / 3.0) * 3.0)
	_logo.size = Vector2(size.x - UIKit.S2 * 2.0, logo_h)


func _play_next() -> void:
	var id := Progression.next_stop()
	if id == "" or SongLibrary.get_song(id) == null:
		app.open("story")
	else:
		app.open("stop_card", {"song_id": id})


func _boards() -> void:
	app.open("boards")


## Desktop builds offer Quit; Android leaves with its back button, iOS and browsers their own way.
static func quit_offered() -> bool:
	return not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"))


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


## The scene's foot sinks into the night in stepped bands of shadow, so the menu reads on it.
class _SceneFoot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := PixelPalette.K[0]
		var n := int(size.y / 6.0)
		for i in n:
			var a := float(i + 1) / float(n)
			draw_rect(Rect2(0, i * 6.0, size.x, 6.0), Color(k, minf(a * 1.25, 1.0) * 0.82))


## Stars over the flat night above the picture on tall phones, in the picture's own star colours
## (title_scene.png's sky), on the 3-px art grid. Drawn once per size.
class _Stars:
	extends Control
	const COLS: Array[Color] = [Color8(48, 58, 120), Color8(67, 76, 140), Color8(201, 205, 232), Color8(244, 241, 220)]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var px := 3.0
		var aw := int(size.x / px)
		var ah := int(size.y / px)
		if aw <= 0 or ah <= 0:
			return
		var n := aw * ah / 140
		var s := 91
		for i in n:
			s = (s * 1103515245 + 12345) & 0x7fffffff
			var x := s % aw
			s = (s * 1103515245 + 12345) & 0x7fffffff
			var y := s % ah
			s = (s * 1103515245 + 12345) & 0x7fffffff
			var c := COLS[0] if s % 10 < 6 else (COLS[1] if s % 10 < 8 else (COLS[2] if s % 10 < 9 else COLS[3]))
			draw_rect(Rect2(x * px, y * px, px, px), c)
