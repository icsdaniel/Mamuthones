class_name WoodcutTheme
extends RefCounted
## The game-wide Theme, "Bonfire Night" pixel look (docs/art-style.md): dark navy panels framed in old
## gold with small red lozenges, one red kilim banner for the main action, parchment cards in a dark
## wood frame, cream serif labels. Apply it once at the root:
##     root_control.theme = WoodcutTheme.build()
## (The class keeps its old name so every caller keeps working.)
##
## Every box is a PixelBox: a 1x nine-patch from game/art/ui (tools/art/pixel/ui_kit.py) drawn x3 with
## nearest filtering, tiled centres, and its ornaments (lozenges, medallions) placed on top. Icons
## (toggles, check boxes, radio, grabber, arrow) are baked x3. No default Godot look is left.
## Default text is Alegreya Sans 28 px, cream; nothing is smaller than 26 px.
##
## Type variations (set Control.theme_type_variation):
##   Labels:  "TitleLabel"       Alegreya ExtraBold 64, cream, K0 outline and shadow (screen titles)
##            "HeaderLabel"      Alegreya Bold 46, cream, K0 outline and shadow (screen headers)
##            "SubheaderLabel"   Alegreya SC Bold 32, old gold small caps (section labels)
##            "CaptionLabel"     Alegreya Sans 26, dimmed cream (secondary text)
##            "HudLabel"         Alegreya Sans ExtraBold 30 with a K0 outline (over the scene)
##            "BigNumberLabel"   Alegreya ExtraBold 64, gold, heavy K0 outline (score, countdown)
##            "PaperLabel"       Alegreya Sans 28, ink (inside a CardPanel)
##            "PaperHeaderLabel" Alegreya SC Bold 40, kilim red (inside a CardPanel)
##   Buttons: "AccentButton"     the red kilim banner, the one main action on a screen
##            "QuietButton"      a thin gold rule, no ornaments (Back, secondary actions)
##            "CompactButton"    the framed button without its lozenges, for dense grids of choices
##   Panels:  "BoardPanel"       navy board with a double gold rule (the default panel too)
##            "CardPanel"        parchment in a dark wood frame; use Paper* labels inside
##            "ClearPanel"       nothing drawn (layout only)

const SIZE_TEXT := 28
const SIZE_BUTTON := 30
const SIZE_CAPTION := 26
const SIZE_SUB := 32
const SIZE_HEADER := 46
const SIZE_TITLE := 64
const SIZE_ACCENT := 36

## Content margins (screen px) of the framed buttons: room for the lozenges at both ends.
const BUTTON_PAD := Vector4(44, 14, 44, 17)
const ACCENT_PAD := Vector4(78, 16, 78, 19)
const COMPACT_PAD := Vector4(18, 14, 18, 17)

static var _theme: Theme


## Builds (once) and returns the shared theme.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var text := Palette.text_font("Regular")
	var bold := Palette.text_font("Bold")
	var heavy := Palette.text_font("ExtraBold")
	var serif := Palette.serif_font("Bold")
	var serif_heavy := Palette.serif_font("ExtraBold")
	var caps := Palette.display_font()
	t.default_font = text
	t.default_font_size = SIZE_TEXT

	# ---- labels
	_label(t, "Label", text, SIZE_TEXT, Palette.BONE)
	t.set_constant("line_spacing", "Label", 4)
	_label(t, "TitleLabel", serif_heavy, SIZE_TITLE, Palette.CREAM, "Label")
	_shadow(t, "TitleLabel", 6, Vector2i(0, 5))
	_label(t, "HeaderLabel", serif, SIZE_HEADER, Palette.CREAM, "Label")
	_shadow(t, "HeaderLabel", 6, Vector2i(0, 4))
	_label(t, "SubheaderLabel", caps, SIZE_SUB, Palette.GOLD, "Label")
	_shadow(t, "SubheaderLabel", 0, Vector2i(0, 3))
	_label(t, "CaptionLabel", text, SIZE_CAPTION, Palette.BONE_DIM, "Label")
	_label(t, "HudLabel", heavy, 30, Palette.BONE, "Label")
	t.set_color("font_outline_color", "HudLabel", Palette.INK)
	t.set_constant("outline_size", "HudLabel", 8)
	_label(t, "BigNumberLabel", serif_heavy, 64, Palette.GOLD_HOT, "Label")
	t.set_color("font_outline_color", "BigNumberLabel", Palette.INK)
	t.set_constant("outline_size", "BigNumberLabel", 12)
	t.set_color("font_shadow_color", "BigNumberLabel", Palette.RED_DEEP)
	t.set_constant("shadow_offset_x", "BigNumberLabel", 0)
	t.set_constant("shadow_offset_y", "BigNumberLabel", 6)
	t.set_constant("shadow_outline_size", "BigNumberLabel", 12)
	_label(t, "PaperLabel", text, SIZE_TEXT, Palette.BLACK, "Label")
	_label(t, "PaperHeaderLabel", caps, 40, Palette.RED_DEEP, "Label")

	t.set_font("normal_font", "RichTextLabel", text)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_color("default_color", "RichTextLabel", Palette.BONE)
	t.set_constant("line_separation", "RichTextLabel", 4)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# ---- buttons: navy, gold frame with corner studs, red lozenges at both ends
	var normal := _box("button_normal", Vector4i(5, 5, 5, 6), BUTTON_PAD, "diamond_red")
	var hover := _box("button_hover", Vector4i(5, 5, 5, 6), BUTTON_PAD, "diamond_red")
	var pressed := _box("button_pressed", Vector4i(5, 6, 5, 5), BUTTON_PAD + Vector4(0, 3, 0, -3), "diamond_lit")
	pressed.ends_dy = 1
	var disabled := _box("button_disabled", Vector4i(5, 5, 5, 6), BUTTON_PAD, "diamond_dim")
	var focus := _box("button_focus", Vector4i(5, 5, 5, 6), BUTTON_PAD)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, serif)
		t.set_font_size("font_size", type, SIZE_BUTTON)
		_button_colors(t, type, Palette.BONE, Palette.CREAM)
		t.set_color("font_outline_color", type, Palette.INK)
		t.set_constant("outline_size", type, 6)
		t.set_constant("h_separation", type, 12)
	t.set_icon("arrow", "OptionButton", Palette.ui("arrow"))
	t.set_constant("arrow_margin", "OptionButton", 48)

	t.set_type_variation("AccentButton", "Button")
	var acc := _box("accent_normal", Vector4i(5, 8, 5, 9), ACCENT_PAD, "medallion")
	var acc_hover := _box("accent_normal", Vector4i(5, 8, 5, 9), ACCENT_PAD, "medallion")
	acc_hover.tint = Color(1.12, 1.08, 1.0)
	var acc_down := _box("accent_pressed", Vector4i(5, 9, 5, 8), ACCENT_PAD + Vector4(0, 3, 0, -3), "medallion")
	acc_down.ends_dy = 1
	var acc_off := _box("accent_pressed", Vector4i(5, 9, 5, 8), ACCENT_PAD, "medallion_dim")
	t.set_stylebox("normal", "AccentButton", acc)
	t.set_stylebox("hover", "AccentButton", acc_hover)
	t.set_stylebox("pressed", "AccentButton", acc_down)
	t.set_stylebox("hover_pressed", "AccentButton", acc_down)
	t.set_stylebox("disabled", "AccentButton", acc_off)
	t.set_font("font", "AccentButton", serif_heavy)
	t.set_font_size("font_size", "AccentButton", SIZE_ACCENT)
	_button_colors(t, "AccentButton", Palette.CREAM, Palette.CREAM)
	t.set_color("font_outline_color", "AccentButton", Palette.INK)
	t.set_constant("outline_size", "AccentButton", 8)

	# the same frame without the lozenges, for grids of four or long option names
	t.set_type_variation("CompactButton", "Button")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var src: PixelBox = t.get_stylebox(st, "Button")
		var c := src.duplicate() as PixelBox
		c.ends = null
		var down := st.contains("pressed")
		c.content_margin_left = COMPACT_PAD.x
		c.content_margin_right = COMPACT_PAD.z
		c.content_margin_top = COMPACT_PAD.y + (3.0 if down else 0.0)
		c.content_margin_bottom = COMPACT_PAD.w - (3.0 if down else 0.0)
		t.set_stylebox(st, "CompactButton", c)

	t.set_type_variation("QuietButton", "Button")
	var quiet := _box("button_quiet", Vector4i(3, 3, 3, 4), Vector4(22, 12, 22, 15))
	var quiet_down := _box("button_quiet_pressed", Vector4i(3, 4, 3, 3), Vector4(22, 15, 22, 12))
	for s in ["normal", "hover", "disabled"]:
		t.set_stylebox(s, "QuietButton", quiet)
	t.set_stylebox("pressed", "QuietButton", quiet_down)
	t.set_stylebox("hover_pressed", "QuietButton", quiet_down)
	t.set_font_size("font_size", "QuietButton", 28)
	t.set_color("font_color", "QuietButton", Palette.BONE_DIM)
	t.set_color("font_hover_color", "QuietButton", Palette.BONE)
	t.set_color("font_focus_color", "QuietButton", Palette.BONE)
	t.set_color("font_pressed_color", "QuietButton", Palette.GOLD_HOT)
	t.set_color("font_hover_pressed_color", "QuietButton", Palette.GOLD_HOT)
	t.set_color("font_disabled_color", "QuietButton", Palette.BONE_FAINT)

	# ---- panels
	var board := _box("panel_dark", Vector4i(7, 7, 7, 7), Vector4(36, 30, 36, 30))
	var card := _box("panel_paper", Vector4i(7, 7, 7, 7), Vector4(40, 34, 40, 34))
	for type in ["Panel", "PanelContainer", "PopupPanel"]:
		t.set_stylebox("panel", type, board)
	t.set_type_variation("BoardPanel", "PanelContainer")
	t.set_stylebox("panel", "BoardPanel", board)
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation("ClearPanel", "PanelContainer")
	t.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", card)
	t.set_color("font_color", "TooltipLabel", Palette.BLACK)
	t.set_font_size("font_size", "TooltipLabel", SIZE_CAPTION)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# ---- popup menus (OptionButton lists)
	t.set_stylebox("panel", "PopupMenu", board)
	t.set_stylebox("hover", "PopupMenu", _box("button_hover", Vector4i(5, 5, 5, 6), Vector4(16, 8, 16, 8)))
	t.set_stylebox("separator", "PopupMenu", _rule())
	t.set_font("font", "PopupMenu", serif)
	t.set_font_size("font_size", "PopupMenu", SIZE_BUTTON)
	t.set_color("font_color", "PopupMenu", Palette.BONE)
	t.set_color("font_hover_color", "PopupMenu", Palette.GOLD_HOT)
	t.set_color("font_disabled_color", "PopupMenu", Palette.BONE_FAINT)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_icon("radio_checked", "PopupMenu", Palette.ui("radio_on"))
	t.set_icon("radio_unchecked", "PopupMenu", Palette.ui("radio_off"))
	t.set_icon("checked", "PopupMenu", Palette.ui("check_on"))
	t.set_icon("unchecked", "PopupMenu", Palette.ui("check_off"))

	# ---- text fields
	var field := _box("field", Vector4i(4, 4, 4, 4), Vector4(20, 14, 20, 14))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", _box("button_focus", Vector4i(5, 5, 5, 6), Vector4(20, 14, 20, 14)))
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", Palette.BONE)
	t.set_color("font_placeholder_color", "LineEdit", Palette.BONE_DIM)
	t.set_color("caret_color", "LineEdit", Palette.GOLD)
	t.set_color("selection_color", "LineEdit", Color(Palette.RED, 0.7))
	t.set_font_size("font_size", "LineEdit", SIZE_TEXT)

	# ---- sliders: a sunk navy groove, the filled part gold, a gold lozenge knob
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, _box("groove", Vector4i(2, 2, 2, 2), Vector4(0, 7, 0, 8)))
		t.set_stylebox("grabber_area", type, _box("groove_gold", Vector4i(2, 2, 2, 2), Vector4(0, 7, 0, 8)))
		t.set_stylebox("grabber_area_highlight", type, _box("groove_gold", Vector4i(2, 2, 2, 2), Vector4(0, 7, 0, 8)))
		t.set_icon("grabber", type, Palette.ui("grabber"))
		t.set_icon("grabber_highlight", type, Palette.ui("grabber_hi"))
		t.set_icon("grabber_disabled", type, Palette.ui("grabber_off"))
		t.set_icon("tick", type, Palette.ui("rule_end"))
		t.set_constant("center_grabber", type, 0)

	# ---- toggles and check boxes
	var row := StyleBoxEmpty.new()
	row.content_margin_left = 6
	row.content_margin_right = 6
	row.content_margin_top = 12
	row.content_margin_bottom = 12
	for type in ["CheckButton", "CheckBox"]:
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(s, type, row)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, text)
		t.set_font_size("font_size", type, SIZE_TEXT)
		_button_colors(t, type, Palette.BONE, Palette.CREAM)
		t.set_constant("h_separation", type, 18)
	t.set_icon("checked", "CheckButton", Palette.ui("toggle_on"))
	t.set_icon("unchecked", "CheckButton", Palette.ui("toggle_off"))
	t.set_icon("checked_disabled", "CheckButton", Palette.ui("toggle_on_off"))
	t.set_icon("unchecked_disabled", "CheckButton", Palette.ui("toggle_off_off"))
	t.set_icon("checked_mirrored", "CheckButton", Palette.ui("toggle_on"))
	t.set_icon("unchecked_mirrored", "CheckButton", Palette.ui("toggle_off"))
	t.set_icon("checked_disabled_mirrored", "CheckButton", Palette.ui("toggle_on_off"))
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", Palette.ui("toggle_off_off"))
	t.set_icon("checked", "CheckBox", Palette.ui("check_on"))
	t.set_icon("unchecked", "CheckBox", Palette.ui("check_off"))
	t.set_icon("checked_disabled", "CheckBox", Palette.ui("check_on_off"))
	t.set_icon("unchecked_disabled", "CheckBox", Palette.ui("check_off_off"))
	t.set_icon("radio_checked", "CheckBox", Palette.ui("radio_on"))
	t.set_icon("radio_unchecked", "CheckBox", Palette.ui("radio_off"))
	t.set_icon("radio_checked_disabled", "CheckBox", Palette.ui("radio_off"))
	t.set_icon("radio_unchecked_disabled", "CheckBox", Palette.ui("radio_off"))

	# ---- scroll bars: a thin gold grabber on a sunk navy line
	for type in ["VScrollBar", "HScrollBar"]:
		var track := _box("scroll_track", Vector4i(1, 2, 1, 2), Vector4(6, 6, 6, 6))
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, _box("scroll_grabber", Vector4i(2, 3, 2, 3), Vector4(6, 9, 6, 9)))
		t.set_stylebox("grabber_highlight", type, _box("scroll_grabber_hi", Vector4i(2, 3, 2, 3), Vector4(6, 9, 6, 9)))
		t.set_stylebox("grabber_pressed", type, _box("scroll_grabber_hi", Vector4i(2, 3, 2, 3), Vector4(6, 9, 6, 9)))

	# ---- progress: a red fill in the sunk groove; cream text with a heavy K0 outline
	t.set_stylebox("background", "ProgressBar", _box("groove", Vector4i(2, 2, 2, 2), Vector4(6, 6, 6, 6)))
	t.set_stylebox("fill", "ProgressBar", _box("groove_red", Vector4i(2, 2, 2, 2), Vector4(6, 6, 6, 6)))
	t.set_color("font_color", "ProgressBar", Palette.BONE)
	t.set_color("font_outline_color", "ProgressBar", Palette.INK)
	t.set_constant("outline_size", "ProgressBar", 10)
	t.set_font("font", "ProgressBar", heavy)
	t.set_font_size("font_size", "ProgressBar", SIZE_CAPTION)

	# ---- separators: the gold rule with a lozenge at its centre and beads at its ends
	t.set_stylebox("separator", "HSeparator", _rule())
	t.set_constant("separation", "HSeparator", 44)

	# ---- tabs
	var tab_on := _box("button_pressed", Vector4i(5, 6, 5, 5), Vector4(24, 15, 24, 9))
	var tab_off := _box("button_normal", Vector4i(5, 5, 5, 6), Vector4(24, 12, 24, 12))
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, tab_on)
		t.set_stylebox("tab_hovered", type, _box("button_hover", Vector4i(5, 5, 5, 6), Vector4(24, 12, 24, 12)))
		t.set_stylebox("tab_unselected", type, tab_off)
		t.set_stylebox("tab_disabled", type, _box("button_disabled", Vector4i(5, 5, 5, 6), Vector4(24, 12, 24, 12)))
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, serif)
		t.set_font_size("font_size", type, SIZE_TEXT)
		t.set_color("font_selected_color", type, Palette.CREAM)
		t.set_color("font_hovered_color", type, Palette.BONE)
		t.set_color("font_unselected_color", type, Palette.BONE_DIM)
		t.set_color("font_disabled_color", type, Palette.BONE_FAINT)
		t.set_color("font_outline_color", type, Palette.INK)
		t.set_constant("outline_size", type, 6)
	t.set_stylebox("panel", "TabContainer", board)
	_theme = t
	return t


static func _label(t: Theme, type: String, font: Font, size: int, color: Color, base := "") -> void:
	if base != "":
		t.set_type_variation(type, base)
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)


## A K0 outline round the letters and a hard K0 drop shadow under them (the reference's cream titles).
static func _shadow(t: Theme, type: String, outline: int, offset: Vector2i) -> void:
	t.set_color("font_outline_color", type, Palette.INK)
	t.set_constant("outline_size", type, outline)
	t.set_color("font_shadow_color", type, Palette.INK)
	t.set_constant("shadow_offset_x", type, offset.x)
	t.set_constant("shadow_offset_y", type, offset.y)
	t.set_constant("shadow_outline_size", type, outline)


static func _button_colors(t: Theme, type: String, c: Color, lit: Color) -> void:
	t.set_color("font_color", type, c)
	t.set_color("font_hover_color", type, lit)
	t.set_color("font_focus_color", type, c)
	t.set_color("font_pressed_color", type, lit)
	t.set_color("font_hover_pressed_color", type, lit)
	t.set_color("font_disabled_color", type, Palette.BONE_FAINT)
	t.set_color("icon_normal_color", type, c)
	t.set_color("icon_pressed_color", type, lit)
	t.set_color("icon_hover_color", type, lit)


## A PixelBox from the kit: `m` is the 1x nine-patch border (art px), `content` the screen-px padding
## (l, t, r, b), `ends` the ornament drawn at both ends.
static func _box(name: String, m: Vector4i, content: Vector4, ends := "") -> PixelBox:
	return PixelBox.make(Palette.ui(name), m, content, Palette.ui(ends) if ends != "" else null)


static func _rule() -> PixelBox:
	var r := PixelBox.make(Palette.ui("rule"), Vector4i(0, 1, 0, 1), Vector4(0, 5, 0, 4))
	r.middle = Palette.ui("rule_diamond")
	r.caps = Palette.ui("rule_end")
	r.shadow_rows = 0
	return r
