extends Screen
## Title, laid out like Daniele's menu reference: the illustrated bonfire scene across the top (TitleScene)
## with the MAMUTHONES word mark over its sky, then the red kilim banner that always says what to do next
## (the next story stop), the framed buttons to every other mode in two columns, the gold divider, and
## Settings and Quit. The menu stands on the shared stone backdrop; the banner glows on the scene's beat.

const BPM := 76.0
## How far the menu reaches up over the scene's foot (the banner sits on the square's edge).
const OVERLAP := 36.0

var scene: TitleScene
var _glow: TextureRect
var _play: Button
var _t := 0.0


func build() -> void:
	var next_id := Progression.next_stop()
	var next_song := SongLibrary.get_song(next_id)
	var stop := next_song.stop if next_song != null else maxi(Progression.highest_stop(), 1)
	var safe := UIKit.safe_margins(self)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- the scene, full bleed, with the word mark over its sky
	var top := Control.new()
	top.name = "Top"
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.custom_minimum_size.y = 300
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	scene = TitleScene.new()
	scene.name = "Scene"
	scene.bpm = BPM
	scene.reduced_motion = UIKit.reduced_motion()
	scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	scene.offset_bottom = OVERLAP
	top.add_child(scene)
	scene.set_look(str(Profile.get_look().get("fleece", "black")))
	var foot := _SceneFoot.new()
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -24.0
	foot.offset_bottom = OVERLAP
	top.add_child(foot)
	var logo := Logo.new()
	logo.name = "Logo"
	logo.mode = "title"
	logo.subtitle = tr("app_title")
	logo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = 30.0 + safe.y
	logo.offset_bottom = logo.offset_top + 132.0
	logo.offset_left = 12.0
	logo.offset_right = -12.0
	top.add_child(logo)
	Sound.ambience(UIKit.ambience_for(stop))

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
	_glow = TextureRect.new()
	_glow.name = "BannerGlow"
	_glow.texture = Palette.px("ui/banner_glow")
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.offset_left = -24   # stays inside the side gutters
	_glow.offset_right = 24
	_glow.offset_top = -48
	_glow.offset_bottom = 48
	_glow.modulate.a = 0.4
	holder.add_child(_glow)
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
		["Workshop", "title_workshop", func() -> void: app.open("workshop")],
		["Leaderboards", "title_boards", _boards],
		["Tutorial", "title_tutorial", func() -> void: app.open("tutorial")],
		["Calibrate", "title_calibrate", func() -> void: app.open("calibration", {"then_latency": true})],
	]:
		var b := UIKit.button(tr(item[1]), item[2])
		b.name = item[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)

	var rule_box := MarginContainer.new()
	rule_box.add_theme_constant_override("margin_left", 72)
	rule_box.add_theme_constant_override("margin_right", 72)
	box.add_child(rule_box)
	var rule := HSeparator.new()
	rule.name = "Divider"
	rule_box.add_child(rule)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var settings := UIKit.button(tr("title_settings"), func() -> void: app.open("settings"))
	settings.name = "Settings"
	settings.custom_minimum_size.x = 270
	row.add_child(settings)
	# iOS and browsers leave apps their own way; Android and desktop get a Quit.
	if not (OS.has_feature("ios") or OS.has_feature("web")):
		var quit := UIKit.button(tr("title_quit"), quit_game)
		quit.name = "Quit"
		quit.custom_minimum_size.x = 270
		row.add_child(quit)


## The banner glows gently on the scene's beat, in steps (a third as much with reduced motion).
func _process(delta: float) -> void:
	if _glow == null:
		return
	_t += delta
	var beat := pow(1.0 - fposmod(_t * BPM / 60.0, 1.0), 2.0)
	var amp := 0.08 if UIKit.reduced_motion() else 0.24
	_glow.modulate.a = snappedf(0.34 + amp * beat, 0.04)


func _play_next() -> void:
	var id := Progression.next_stop()
	if id == "" or SongLibrary.get_song(id) == null:
		app.open("story")
	else:
		app.open("stop_card", {"song_id": id})


func _boards() -> void:
	app.open("boards")


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


## The scene's foot sinks into the stone in stepped bands of shadow, so the menu reads on it.
class _SceneFoot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := PixelPalette.K[0]
		var n := int(size.y / 6.0)
		for i in n:
			var a := float(i + 1) / float(n)
			draw_rect(Rect2(0, i * 6.0, size.x, 6.0), Color(k, a * 0.85))
