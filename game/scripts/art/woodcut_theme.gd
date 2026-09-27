class_name WoodcutTheme
extends RefCounted
## The game-wide Theme: woodcut print on carved wood. Apply it once at the root:
##     root_control.theme = WoodcutTheme.build()
##
## Default text is Alegreya Sans 28 px, bone on dark; nothing is smaller than 26 px so it reads on a
## phone at arm's length. Buttons, panels, sliders, toggles, check boxes, scroll bars, progress bars,
## option menus, line edits, separators and tabs are all textured nine-patches from game/art/ui
## (baked by tools/art/make_textures.py), so no default Godot look is left.
##
## Type variations (set Control.theme_type_variation):
##   Labels:  "TitleLabel"       IM Fell English SC 76, bone (screen titles)
##            "HeaderLabel"      IM Fell English SC 46, bone (section headers)
##            "SubheaderLabel"   Alegreya Sans ExtraBold 32, ember
##            "CaptionLabel"     Alegreya Sans 26, dimmed bone (secondary text)
##            "HudLabel"         Alegreya Sans ExtraBold 30 with an ink outline (over the scene)
##            "BigNumberLabel"   Alegreya Sans ExtraBold 64 with an ink outline (score, countdown)
##            "PaperLabel"       Alegreya Sans 28, ink (inside a CardPanel)
##            "PaperHeaderLabel" IM Fell English SC 44, ink (inside a CardPanel)
##   Buttons: "AccentButton"     red block, the one main action on a screen
##            "QuietButton"      no box, dimmed text that brightens (secondary actions, links)
##   Panels:  "BoardPanel"       dark carved board with a double bone rule (the default panel too)
##            "CardPanel"        bone paper card with an ink frame; use Paper* labels inside
##            "ClearPanel"       nothing drawn (layout only)

const SIZE_TEXT := 28
const SIZE_BUTTON := 30
const SIZE_CAPTION := 26
const SIZE_SUB := 32
const SIZE_HEADER := 46
const SIZE_TITLE := 76

static var _theme: Theme


## Builds (once) and returns the shared theme.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var text := Palette.text_font("Regular")
	var bold := Palette.text_font("Bold")
	var heavy := Palette.text_font("ExtraBold")
	var display := Palette.display_font()
	t.default_font = text
	t.default_font_size = SIZE_TEXT

	# ---- labels
	_label(t, "Label", text, SIZE_TEXT, Palette.BONE)
	t.set_constant("line_spacing", "Label", 4)
	_label(t, "TitleLabel", display, SIZE_TITLE, Palette.BONE, "Label")
	t.set_color("font_shadow_color", "TitleLabel", Color(Palette.INK, 0.9))
	t.set_constant("shadow_offset_x", "TitleLabel", 3)
	t.set_constant("shadow_offset_y", "TitleLabel", 4)
	_label(t, "HeaderLabel", display, SIZE_HEADER, Palette.BONE, "Label")
	t.set_color("font_shadow_color", "HeaderLabel", Color(Palette.INK, 0.9))
	t.set_constant("shadow_offset_x", "HeaderLabel", 2)
	t.set_constant("shadow_offset_y", "HeaderLabel", 3)
	_label(t, "SubheaderLabel", heavy, SIZE_SUB, Palette.EMBER, "Label")
	_label(t, "CaptionLabel", text, SIZE_CAPTION, Palette.BONE_DIM, "Label")
	_label(t, "HudLabel", heavy, 30, Palette.BONE, "Label")
	t.set_color("font_outline_color", "HudLabel", Palette.INK)
	t.set_constant("outline_size", "HudLabel", 8)
	_label(t, "BigNumberLabel", heavy, 64, Palette.BONE, "Label")
	t.set_color("font_outline_color", "BigNumberLabel", Palette.INK)
	t.set_constant("outline_size", "BigNumberLabel", 12)
	_label(t, "PaperLabel", text, SIZE_TEXT, Palette.BLACK, "Label")
	_label(t, "PaperHeaderLabel", display, 44, Palette.BLACK, "Label")

	t.set_font("normal_font", "RichTextLabel", text)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_color("default_color", "RichTextLabel", Palette.BONE)
	t.set_constant("line_separation", "RichTextLabel", 4)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# ---- buttons
	var content := Vector4(30, 16, 30, 16)
	var normal := _nine("button_normal", 22, content)
	var hover := _nine("button_hover", 22, content)
	var pressed := _nine("button_pressed", 22, content)
	var disabled := _nine("button_disabled", 22, content)
	var focus := _nine("button_focus", 22, content)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, bold)
		t.set_font_size("font_size", type, SIZE_BUTTON)
		_button_colors(t, type, Palette.BONE)
		t.set_constant("h_separation", type, 12)
	t.set_icon("arrow", "OptionButton", Palette.ui("arrow"))
	t.set_constant("arrow_margin", "OptionButton", 16)

	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _nine("accent_normal", 22, content))
	t.set_stylebox("hover", "AccentButton", _nine("accent_normal", 22, content))
	t.set_stylebox("pressed", "AccentButton", _nine("accent_pressed", 22, content))
	t.set_stylebox("hover_pressed", "AccentButton", _nine("accent_pressed", 22, content))
	t.set_font("font", "AccentButton", heavy)
	t.set_font_size("font_size", "AccentButton", 32)
	_button_colors(t, "AccentButton", Palette.BONE)

	t.set_type_variation("QuietButton", "Button")
	var quiet := StyleBoxEmpty.new()
	quiet.set_content_margin_all(14)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(s, "QuietButton", quiet)
	t.set_color("font_color", "QuietButton", Palette.BONE_DIM)
	t.set_color("font_hover_color", "QuietButton", Palette.BONE)
	t.set_color("font_focus_color", "QuietButton", Palette.BONE)
	t.set_color("font_pressed_color", "QuietButton", Palette.EMBER)
	t.set_color("font_hover_pressed_color", "QuietButton", Palette.EMBER)
	t.set_color("font_disabled_color", "QuietButton", Palette.BONE_FAINT)

	# ---- panels
	var board := _nine("panel_dark", 28, Vector4(32, 28, 32, 28))
	var card := _nine("panel_paper", 28, Vector4(36, 32, 36, 32))
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
	t.set_stylebox("hover", "PopupMenu", _nine("button_hover", 22, Vector4(16, 8, 16, 8)))
	t.set_stylebox("separator", "PopupMenu", _nine("rule", 8, Vector4(0, 6, 0, 6)))
	t.set_font("font", "PopupMenu", bold)
	t.set_font_size("font_size", "PopupMenu", SIZE_BUTTON)
	t.set_color("font_color", "PopupMenu", Palette.BONE)
	t.set_color("font_hover_color", "PopupMenu", Palette.EMBER)
	t.set_color("font_disabled_color", "PopupMenu", Palette.BONE_FAINT)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_icon("radio_checked", "PopupMenu", Palette.ui("radio_on"))
	t.set_icon("radio_unchecked", "PopupMenu", Palette.ui("radio_off"))
	t.set_icon("checked", "PopupMenu", Palette.ui("check_on"))
	t.set_icon("unchecked", "PopupMenu", Palette.ui("check_off"))

	# ---- text fields
	var field := _nine("field", 12, Vector4(18, 14, 18, 14))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", Palette.BONE)
	# Placeholder must still read on the grained field (BONE_DIM is about 7:1 on it).
	t.set_color("font_placeholder_color", "LineEdit", Palette.BONE_DIM)
	t.set_color("caret_color", "LineEdit", Palette.EMBER)
	t.set_color("selection_color", "LineEdit", Color(Palette.RED, 0.7))
	t.set_font_size("font_size", "LineEdit", SIZE_TEXT)

	# ---- sliders
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, _nine("groove", 8, Vector4(-1, -1, -1, -1)))
		t.set_stylebox("grabber_area", type, _nine("groove_red", 8, Vector4(-1, -1, -1, -1)))
		t.set_stylebox("grabber_area_highlight", type, _nine("groove_red", 8, Vector4(-1, -1, -1, -1)))
		t.set_icon("grabber", type, Palette.ui("grabber"))
		t.set_icon("grabber_highlight", type, Palette.ui("grabber_hi"))
		t.set_icon("grabber_disabled", type, Palette.ui("grabber_off"))
		t.set_icon("tick", type, Palette.ui("grabber_off"))
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
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, text)
		t.set_font_size("font_size", type, SIZE_TEXT)
		_button_colors(t, type, Palette.BONE)
		t.set_constant("h_separation", type, 18)
	t.set_icon("checked", "CheckButton", Palette.ui("toggle_on"))
	t.set_icon("unchecked", "CheckButton", Palette.ui("toggle_off"))
	t.set_icon("checked_disabled", "CheckButton", Palette.ui("toggle_on_off"))
	t.set_icon("unchecked_disabled", "CheckButton", Palette.ui("toggle_off_off"))
	t.set_icon("checked_mirrored", "CheckButton", Palette.ui("toggle_on"))
	t.set_icon("unchecked_mirrored", "CheckButton", Palette.ui("toggle_off"))
	t.set_icon("checked", "CheckBox", Palette.ui("check_on"))
	t.set_icon("unchecked", "CheckBox", Palette.ui("check_off"))
	t.set_icon("checked_disabled", "CheckBox", Palette.ui("check_on_off"))
	t.set_icon("unchecked_disabled", "CheckBox", Palette.ui("check_off_off"))
	t.set_icon("radio_checked", "CheckBox", Palette.ui("radio_on"))
	t.set_icon("radio_unchecked", "CheckBox", Palette.ui("radio_off"))

	# ---- scroll bars
	for type in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxEmpty.new()
		track.set_content_margin_all(4)
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, _nine("scroll_grabber", 6, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber_highlight", type, _nine("scroll_grabber_hi", 6, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber_pressed", type, _nine("scroll_grabber_hi", 6, Vector4(4, 4, 4, 4)))

	# ---- progress
	t.set_stylebox("background", "ProgressBar", _nine("groove", 8, Vector4(-1, -1, -1, -1)))
	# Red fill (bone text on it is about 4.6:1) and a heavy ink outline so the percentage reads on the
	# fill and on the empty groove alike.
	t.set_stylebox("fill", "ProgressBar", _nine("groove_red", 8, Vector4(-1, -1, -1, -1)))
	t.set_color("font_color", "ProgressBar", Palette.BONE)
	t.set_color("font_outline_color", "ProgressBar", Palette.INK)
	t.set_constant("outline_size", "ProgressBar", 10)
	t.set_font("font", "ProgressBar", Palette.text_font("ExtraBold"))
	t.set_font_size("font_size", "ProgressBar", SIZE_CAPTION)

	# ---- separators
	t.set_stylebox("separator", "HSeparator", _nine("rule", 8, Vector4(-1, -1, -1, -1)))
	t.set_constant("separation", "HSeparator", 24)

	# ---- tabs
	var tab_on := _nine("button_pressed", 22, Vector4(24, 12, 24, 12))
	var tab_off := _nine("button_normal", 22, Vector4(24, 12, 24, 12))
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, tab_on)
		t.set_stylebox("tab_hovered", type, tab_off)
		t.set_stylebox("tab_unselected", type, tab_off)
		t.set_stylebox("tab_disabled", type, _nine("button_disabled", 22, Vector4(24, 12, 24, 12)))
		t.set_stylebox("tab_focus", type, focus)
		t.set_font("font", type, bold)
		t.set_font_size("font_size", type, SIZE_TEXT)
		t.set_color("font_selected_color", type, Palette.BONE)
		t.set_color("font_hovered_color", type, Palette.BONE)
		t.set_color("font_unselected_color", type, Palette.BONE_DIM)
		t.set_color("font_disabled_color", type, Palette.BONE_FAINT)
	t.set_stylebox("panel", "TabContainer", board)
	_theme = t
	return t


static func _label(t: Theme, type: String, font: Font, size: int, color: Color, base := "") -> void:
	if base != "":
		t.set_type_variation(type, base)
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)


static func _button_colors(t: Theme, type: String, c: Color) -> void:
	t.set_color("font_color", type, c)
	t.set_color("font_hover_color", type, c)
	t.set_color("font_focus_color", type, c)
	t.set_color("font_pressed_color", type, c)
	t.set_color("font_hover_pressed_color", type, c)
	t.set_color("font_disabled_color", type, Palette.BONE_FAINT)
	t.set_color("icon_normal_color", type, c)
	t.set_color("icon_pressed_color", type, c)
	t.set_color("icon_hover_color", type, c)


## A tileable nine-patch StyleBox. `margin` is the texture border in pixels; `content` is l, t, r, b.
static func _nine(name: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Palette.ui(name)
	sb.set_texture_margin_all(margin)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb
