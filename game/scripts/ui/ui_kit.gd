class_name UIKit
extends RefCounted
## Small builders shared by every screen, so screens read as a list of what they show. Sizes follow the
## rubric: touch targets at least 88 px (we use 96), text at least 24 px (the theme's sizes).

const TOUCH := 96
const COLUMN_MAX := 760.0
const GUTTER := 32.0

# Theme type variations from Art's WoodcutTheme.
const TITLE := "TitleLabel"
const HEADER := "HeaderLabel"
const CAPTION := "CaptionLabel"
const SUB := "SubheaderLabel"
const PAPER := "PaperLabel"
const PAPER_HEADER := "PaperHeaderLabel"
const HUD := "HudLabel"
const BOARD := "BoardPanel"
const PRIMARY := "AccentButton"
const QUIET := "QuietButton"
const CARD := "CardPanel"

## One early/late language everywhere (bursts, the timing ticks, judgement hints, the results
## histogram): early is cool and sits UP (the note had not reached the line yet), late is warm and
## sits DOWN (it had passed). The woodcut palette has no cool colour, so the UI keeps this pair.
const EARLY := Color("#8ec3e6")
const LATE := Color("#ef8250")


## "early", "late" or "" for a signed hit offset, with Core's one dead zone (Session.SIDE_DEAD_ZONE).
static func side_of(offset: float) -> String:
	if absf(offset) <= Session.SIDE_DEAD_ZONE:
		return ""
	return "early" if offset < 0.0 else "late"


static func side_color(side: String) -> Color:
	return EARLY if side == "early" else LATE


static func apply_root(root: Control) -> void:
	root.theme = WoodcutTheme.build()
	I18n.set_locale(language())
	apply_volumes()


static func language() -> String:
	var l: String = Profile.get_setting("language")
	return l if l != "" else I18n.system_locale()


static func reduced_motion() -> bool:
	return bool(Profile.get_setting("reduced_motion"))


static func first_screen() -> String:
	if not Profile.has_flag("language_chosen"):
		return "language"
	if not Profile.has_flag("tutorial_done"):
		return "headphones"
	return "title"


## Buzzes that were asked for (tests read it: the handheld call does nothing on a desktop).
static var vibrations := 0


static func vibrate(ms: int) -> void:
	if bool(Profile.get_setting("vibration")):
		vibrations += 1
		Input.vibrate_handheld(ms)


## A centred column inside safe-area margins, optionally scrolling. Returns the VBox to fill.
static func column(parent: Control, scroll := true, separation := 20) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := safe_margins(parent)
	margin.add_theme_constant_override("margin_left", int(GUTTER + safe.x))
	margin.add_theme_constant_override("margin_right", int(GUTTER + safe.x))
	margin.add_theme_constant_override("margin_top", int(24 + safe.y))
	margin.add_theme_constant_override("margin_bottom", int(24 + safe.w))
	parent.add_child(margin)
	var center := CenterWidth.new()
	center.max_width = COLUMN_MAX
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		margin.add_child(sc)
		sc.add_child(center)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		margin.add_child(center)
	center.add_child(box)
	return box


## A scrolling column with a footer pinned to the bottom for the screen's main actions, so "Play" is
## always in reach of a thumb. Returns [content VBox, footer VBox].
static func column_with_footer(parent: Control, separation := 16) -> Array[VBoxContainer]:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe := safe_margins(parent)
	margin.add_theme_constant_override("margin_left", int(GUTTER + safe.x))
	margin.add_theme_constant_override("margin_right", int(GUTTER + safe.x))
	margin.add_theme_constant_override("margin_top", int(24 + safe.y))
	margin.add_theme_constant_override("margin_bottom", int(20 + safe.w))
	parent.add_child(margin)
	var center := CenterWidth.new()
	center.max_width = COLUMN_MAX
	margin.add_child(center)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	center.add_child(outer)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(sc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	foot.name = "Footer"
	outer.add_child(foot)
	return [box, foot]


## Safe-area insets in canvas units (left, top, right, bottom) for notches and home bars.
static func safe_margins(node: Control) -> Vector4:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0 or safe.size.x > win.x:
		return Vector4.ZERO
	var scale := node.get_viewport_rect().size.x / float(win.x)
	return Vector4(safe.position.x * scale, safe.position.y * scale,
		(win.x - safe.end.x) * scale, (win.y - safe.end.y) * scale).max(Vector4.ZERO)


## Back button and title in one row.
static func header(box: Container, title: String, on_back: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := button(tr_("ui_back"), on_back, QUIET)
	back.custom_minimum_size = Vector2(TOUCH * 1.6, TOUCH)
	back.name = "Back"
	row.add_child(back)
	var l := label(title, HEADER, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.name = "Title"
	row.add_child(l)
	box.add_child(row)
	return row


static func button(text: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(TOUCH, TOUCH)
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	if on_press.is_valid():
		b.pressed.connect(func() -> void:
			Sound.ui("tap")
			on_press.call())
	return b


static func label(text: String, variation := "", wrap := true, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1
	return l


## A panel holding a VBox. `paper` uses the light paper card (put PAPER labels inside), otherwise a dark
## carved board.
static func card(box: Container, paper := false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = CARD if paper else BOARD
	box.add_child(p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	p.add_child(inner)
	return inner


static func spacer(box: Container, h: float, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(c)
	return c


## Static tr() for builders that are not nodes.
static func tr_(key: String) -> String:
	return TranslationServer.translate(key)


## A little rise-and-fade in, for items appearing in turn (results lines, unlocks).
static func pop_in(c: CanvasItem, delay := 0.0) -> void:
	if reduced_motion():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.25)


# ---------------------------------------------------------------- game-facing helpers


static func song_title(song: SongData) -> String:
	return song.title(I18n.locale()) if song != null else ""


## The stop's day ("16 January"), or "" when the song is already named after it (Shrove Tuesday).
static func stop_date(song: SongData) -> String:
	if song == null:
		return ""
	var d := tr_("stop_date_%d" % song.stop)
	return "" if d.to_lower() == song_title(song).to_lower() else d


## 12345 -> "12,345" (English) or "12.345" (Italian).
static func fmt_score(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	var sep := "." if I18n.locale() == "it" else ","
	var out := ""
	while s.length() > 3:
		out = sep + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


## 1.5 -> "1.5" (English) or "1,5" (Italian).
static func fmt_dec(v: float, digits := 1) -> String:
	var s := ("%." + str(digits) + "f") % v
	return s.replace(".", ",") if I18n.locale() == "it" else s


static func date_text(d: Dictionary) -> String:
	var month := tr_("month_%d" % int(d.month))
	return tr_("date_fmt") % [int(d.day), month, int(d.year)]


## Ambience for a story stop, from Sound's own table (wind and fire at the bonfires, the crowd later).
static func ambience_for(stop: int) -> String:
	if stop >= 1 and stop < Sound.STOP_AMBIENCE.size():
		return Sound.STOP_AMBIENCE[stop]
	return "crowd"


## Puts the saved volumes on Sound's buses: music with the ambience, bells with the effects.
static func apply_volumes() -> void:
	var music := float(Profile.get_setting("music_volume"))
	var sfx := float(Profile.get_setting("sfx_volume"))
	Sound.set_volume("music", music)
	Sound.set_volume("ambience", music)
	Sound.set_volume("bells", sfx)
	Sound.set_volume("sfx", sfx)


## Shows the player's own Mamuthone (mask, fleece, straps) in a procession scene.
static func show_look(scene: ProcessionScene) -> void:
	var look: Dictionary = Profile.get_look()
	scene.set_look(look.get("mask", MaskSpec.default()), str(look.get("fleece", "black")), str(look.get("straps", "natural")))


## Best bells over every difficulty of a song.
static func best_bells(song_id: String) -> int:
	var song := SongLibrary.get_song(song_id)
	if song == null:
		return 0
	var out := 0
	for d in song.difficulties():
		out = maxi(out, int(Profile.best(song_id, d).get("bells", 0)))
	return out


## Bests and ghosts are kept per track: the remix is its own.
static func board_song_id(song: SongData, remix: bool) -> String:
	return song.remix_id() if remix and song.has_remix() else song.id


## The goal the player is closest to, in one line ("" when everything is open).
static func goal_text() -> String:
	var goals: Array = Progression.next_goals()
	if goals.is_empty():
		return ""
	return goal_line(goals[0])


static func goal_line(g: Dictionary) -> String:
	var need: Dictionary = g.get("need", {})
	var have: Dictionary = g.get("have", {})
	var what := unlock_name(g)
	if need.has("song_id"):
		var where := song_title(SongLibrary.get_song(str(need.song_id)))
		if need.has("difficulty"):
			return tr_("goal_hard") % [what, int(need.get("bells", 2)), where, int(have.get("bells", 0))]
		return tr_("goal_song") % [what, where]
	if need.has("points"):
		if int(have.get("stop", 1)) < int(need.get("stop", 1)):
			return tr_("goal_points_stop") % [what, int(need.stop), int(need.points), int(have.get("points", 0))]
		return tr_("goal_points") % [what, int(need.points), int(have.get("points", 0))]
	if need.has("stop"):
		return tr_("goal_stop") % [what, int(need.stop)]
	return what


## The thing an unlock opens, as a short noun ("Around the Bonfires", "the Full load bells").
static func unlock_name(u: Dictionary) -> String:
	var id := str(u.get("id", ""))
	match str(u.get("kind", "")):
		"song":
			return song_title(SongLibrary.get_song(id))
		"remix":
			return tr_("name_remix") % song_title(SongLibrary.get_song(id))
		"bell_set":
			return tr_("name_bells") % BellSets.name(id, I18n.locale())
		"mask":
			return mask_option_name(str(u.get("part", "")), id)
	return id


## "furrowed brow" / "fronte aggrottata": the word order follows the language.
static func mask_option_name(part: String, option: String) -> String:
	var lang := I18n.locale()
	var p := MaskSpec.name_of(part, lang)
	var o := MaskSpec.name_of(option, lang)
	return ((p + " " + o) if lang == "it" else (o + " " + p)).to_lower()


## A line announcing an unlock ("New stop: Around the Bonfires").
static func unlock_text(u: Dictionary) -> String:
	match str(u.get("kind", "")):
		"song":
			return tr_("unlock_song") % unlock_name(u)
		"remix":
			return tr_("unlock_remix") % unlock_name(u)
		"bell_set":
			return tr_("unlock_bells") % unlock_name(u)
		"mask":
			return tr_("unlock_mask") % unlock_name(u)
	return unlock_name(u)


## The bell sets as a row of toggles (locked ones say where they unlock); picking one saves it.
static func bell_set_picker(box: Container) -> HBoxContainer:
	box.add_child(label(tr_("bells_title"), SUB))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.name = "BellSets"
	box.add_child(row)
	var current := str(Profile.get_look().get("bell_set", "light"))
	var buttons: Array[Button] = []
	for id in BellSets.ids():
		var open := Progression.bell_set_unlocked(id)
		var b := Button.new()
		b.text = "%s\n×%s" % [BellSets.name(id, I18n.locale()), str(BellSets.weight(id))]
		b.toggle_mode = true
		b.disabled = not open
		b.custom_minimum_size = Vector2(TOUCH, TOUCH * 1.2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(id == current)
		b.name = "Set_" + id
		buttons.append(b)
		row.add_child(b)
	for b in buttons:
		var id := b.name.substr(4)
		b.pressed.connect(func() -> void:
			Profile.set_look("bell_set", id)
			Sound.bell(id, true, "perfect")
			for o in buttons:
				o.set_pressed_no_signal(o == b))
	var note := label(tr_("bells_note"), CAPTION)
	box.add_child(note)
	return row


## A dark veil over a scene so text on top reads.
static func shade(parent: Control, alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Palette.INK, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


static func _overlay(node: Node) -> Control:
	var app: App = node.get_tree().root.get_meta("app", null) if node.is_inside_tree() else null
	return app.overlay() if app != null else (node as Control)


## A short message at the bottom of the screen that fades by itself.
static func toast(node: Node, text: String) -> void:
	var host := _overlay(node)
	var p := PanelContainer.new()
	p.theme_type_variation = BOARD
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, "", true, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	host.add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	p.custom_minimum_size.x = minf(host.size.x - 64.0, 640.0)
	p.position = Vector2((host.size.x - p.custom_minimum_size.x) * 0.5, host.size.y - 260.0)
	var tw := p.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## A yes/no question over the screen.
static func confirm(node: Node, question: String, yes: String, on_yes: Callable) -> void:
	var host := _overlay(node)
	var veil := ColorRect.new()
	veil.color = Color(Palette.INK, 0.75)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 540
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	box.add_child(label(question, SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(button(yes, func() -> void:
		veil.queue_free()
		on_yes.call(), PRIMARY))
	box.add_child(button(tr_("ui_cancel"), veil.queue_free, QUIET))


## An unlock celebration: a paper banner drops in over everything with the unlock sound and a ring of
## the bells, then lifts away. Tapping dismisses it early.
static func celebrate(node: Node, text: String, delay := 0.0) -> void:
	var host := _overlay(node)
	var veil := ColorRect.new()
	veil.color = Color(Palette.INK, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.name = "Celebration"
	host.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)
	var p := PanelContainer.new()
	p.theme_type_variation = CARD
	p.custom_minimum_size.x = 560
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)
	box.add_child(label(tr_("celebrate_title"), PAPER_HEADER, true, HORIZONTAL_ALIGNMENT_CENTER))
	var bells := BellMarks.new(3, 56.0)
	bells.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bells)
	box.add_child(label(text, PAPER, true, HORIZONTAL_ALIGNMENT_CENTER))
	p.modulate.a = 0.0
	var tw := veil.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		Sound.ui("unlock")
		veil.mouse_filter = Control.MOUSE_FILTER_STOP
		veil.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed:
				veil.queue_free())
		bells.animate(0.1))
	tw.set_parallel()
	tw.tween_property(veil, "color:a", 0.6, 0.25).set_delay(delay)
	tw.tween_property(p, "modulate:a", 1.0, 0.25).set_delay(delay)
	if not reduced_motion():
		p.scale = Vector2(0.8, 0.8)
		p.pivot_offset = Vector2(280, 150)
		tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(2.6)
	tw.tween_property(veil, "modulate:a", 0.0, 0.3)
	tw.tween_callback(veil.queue_free)
