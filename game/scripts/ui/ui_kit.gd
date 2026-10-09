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
const LEAD := "LeadLabel"   ## an instruction sentence (serif, pale gold), not small caps
const PAPER := "PaperLabel"
const PAPER_HEADER := "PaperHeaderLabel"
const HUD := "HudLabel"
const BOARD := "BoardPanel"
const PRIMARY := "AccentButton"
const QUIET := "QuietButton"
const COMPACT := "CompactButton"   ## framed, no lozenges: dense grids of choices
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
	if not Profile.has_flag("headphones_seen"):
		return "headphones"
	if not Profile.has_flag("calibrated"):
		return "calibration"
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
	# the list sinks into shadow in three stepped bands above the footer instead of being cut off
	foot.draw.connect(func() -> void:
		if foot.get_child_count() == 0 or not sc.get_v_scroll_bar().visible:
			return
		for i in 3:
			foot.draw_rect(Rect2(-GUTTER, -36.0 + i * 8.0, foot.size.x + 2.0 * GUTTER, 8.0), Color(PixelPalette.K[0], 0.25 * (i + 1))))
	sc.get_v_scroll_bar().visibility_changed.connect(foot.queue_redraw)
	outer.add_child(foot)
	return [box, foot]


## Safe-area insets in canvas units (left, top, right, bottom) for notches and home bars.
static func safe_margins(node: Control) -> Vector4:
	if OS.has_environment("SAFE_TOP"):
		# screenshots: a phone's notch, in base px
		return Vector4(0.0, float(OS.get_environment("SAFE_TOP")), 0.0, 0.0)
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


## Browser-style tabs in one row: the chosen tab is lit and open at the bottom onto the page below,
## the others sit back, darker and lower, on a gold rule. `items` are [id, label] pairs; `on_pick`
## gets the id. Each tab is a toggle Button named "Tab_<id>".
static func tabs(box: Container, items: Array, selected: String, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", 0)
	for it in items:
		var id: String = it[0]
		var b := Button.new()
		b.text = it[1]
		b.name = "Tab_" + id
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(0, TOUCH)
		b.clip_text = true
		b.pressed.connect(func() -> void:
			Sound.ui("tap")
			on_pick.call(id))
		juice(b)
		row.add_child(b)
	box.add_child(row)
	select_tab(row, selected)
	return row


## Lights the tab `id` in a `tabs()` row.
static func select_tab(row: HBoxContainer, id: String) -> void:
	var kids := row.get_children()
	for i in kids.size():
		var b: Button = kids[i]
		var on := b.name == "Tab_" + id
		# Neighbours share one divider: a tab draws its left edge only when first or lit, its right
		# edge unless the next tab is the lit one.
		var next_on := i + 1 < kids.size() and kids[i + 1].name == "Tab_" + id
		b.set_pressed_no_signal(on)
		var sb := StyleBoxFlat.new()
		sb.bg_color = PixelPalette.NAVY[3] if on else PixelPalette.NAVY[1]
		sb.border_color = PixelPalette.GOLD[4] if on else PixelPalette.GOLD[3]
		sb.border_width_left = 6 if on or i == 0 else 0
		sb.border_width_right = 0 if next_on else 6
		sb.border_width_top = 6
		sb.border_width_bottom = 0 if on else 6
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.anti_aliasing = false
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		var ink: Color = PixelPalette.BONE[4] if on else PixelPalette.BONE[1]
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, ink)
		# The open tab stands a little taller than the ones behind it.
		b.custom_minimum_size.y = TOUCH + 12 if on else TOUCH


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
	juice(b)
	fit_text(b)
	return b


## The press feel of every kit button: the face drops one art pixel (the pressed PixelBox) and the
## whole button flashes gold for a moment.
static func juice(b: BaseButton) -> void:
	b.button_down.connect(func() -> void:
		var hot := Color(1.35, 1.2, 0.9) if not reduced_motion() else Color(1.15, 1.08, 0.97)
		b.self_modulate = hot
		var tw := b.create_tween()
		tw.tween_property(b, "self_modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))


## Shrinks a button's label (down to `min_size`, never under the 26 px floor) until it fits between
## the button's ornaments, whatever the language. The button asks only for room for its text at
## `min_size`, so long translations shrink the type instead of pushing the layout off the screen.
static func fit_text(b: Button, min_size := 26) -> void:
	var refit := func() -> void:
		if b.text == "" or not b.is_inside_tree() or b.has_meta("fitting"):
			return
		if b.get_child_count() > 0 and b.alignment == HORIZONTAL_ALIGNMENT_LEFT:
			return   # list rows with a badge on the right lay out their own text
		b.set_meta("fitting", true)
		b.remove_theme_font_size_override("font_size")
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var sb := b.get_theme_stylebox("normal")
		var pads := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0
		var line := b.text.get_slice("\n", 0)
		if font == null:
			b.remove_meta("fitting")
			return
		var own: float = b.get_meta("own_min_w", b.custom_minimum_size.x)
		b.set_meta("own_min_w", own)
		var need := ceilf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, mini(fs, min_size)).x + pads) + 2.0
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if absf(b.custom_minimum_size.x - maxf(own, need)) > 0.5:
			b.custom_minimum_size.x = maxf(own, need)
		var room := b.size.x - pads
		if room <= 0.0:
			b.remove_meta("fitting")
			return
		while fs > min_size and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			fs -= 1
		if fs != b.get_theme_font_size("font_size"):
			b.add_theme_font_size_override("font_size", fs)
		b.remove_meta("fitting")
	b.resized.connect(refit)
	b.tree_entered.connect(refit)


static func label(text: String, variation := "", wrap := true, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1
		# The display face has tall line gaps: pull wrapped headings' lines together.
		var tighten: int = {TITLE: -18, HEADER: -12, PAPER_HEADER: -8}.get(variation, 0)
		if tighten != 0:
			l.add_theme_constant_override("line_spacing", tighten)
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


## Shows the player's own Mamuthone (mask, fleece, straps) in a procession scene or the side rows.
static func show_look(scene) -> void:
	var look: Dictionary = Profile.get_look()
	scene.set_look(look.get("mask", MaskSpec.default()), str(look.get("fleece", "black")), str(look.get("straps", "natural")))
	if "bell_set" in scene:
		scene.bell_set = BellSets.STANDARD


## Best grade rank over every difficulty of a song (-1: never played).
static func best_grade(song_id: String) -> int:
	return Progression.best_grade(song_id)


## Whether any difficulty of a song was played with a full combo.
static func any_full_combo(song_id: String) -> bool:
	var song := SongLibrary.get_song(song_id)
	if song == null:
		return false
	for d in song.difficulties():
		if bool(Profile.best(song_id, d).get("full_combo", false)):
			return true
	return false


## A saved best's grade rank (-1 when there is none).
static func grade_of(best: Dictionary) -> int:
	return Progression.entry_grade(best) if not best.is_empty() else -1


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
			var have_g := int(have.get("grade", -1))
			return tr_("goal_hard") % [what, Session.grade_name(int(need.get("grade", Session.RANK_B))), where, Session.grade_name(have_g) if have_g >= 0 else "-"]
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
		"mask":
			return tr_("unlock_mask") % unlock_name(u)
	return unlock_name(u)


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
