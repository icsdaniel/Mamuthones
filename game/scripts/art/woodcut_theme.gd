class_name WoodcutTheme
extends RefCounted
## The game-wide Theme of the menu kit, "Bonfire Night" (2026-10 mobile rework). The design system
## itself (tokens, components, rules) is described at the top of UIKit; this file holds the tokens
## and turns them into a Godot Theme. Apply it once at the root:
##     root_control.theme = WoodcutTheme.build()
## (The class keeps its old name so every caller keeps working.)
##
## Every box is a PxStyle: a stepped, pixel-cornered rounded rect drawn in code on the 3-px art grid
## (no nine-patch textures), so edges stay as crisp as the pixel art beside them. Toggles, check
## boxes, the slider knob and the kit's icons are baked at start from small pixel maps (icon()).
## Scroll bars are never drawn: lists scroll by touch-drag only.
##
## Type variations (set Control.theme_type_variation):
##   Labels:  "TitleLabel"       Alegreya ExtraBold 56, cream (a screen's big title)
##            "HeaderLabel"      Alegreya Bold 40, cream (the top bar's title, card titles)
##            "SubheaderLabel"   Alegreya SC Bold 30, bronze (section labels)
##            "OverlineLabel"    the pixel capitals (PxType "caps_gold") 30: tile and section tags
##            "ValueLabel"       Alegreya Sans ExtraBold 44, cream (a tile's number)
##            "CaptionLabel"     Alegreya Sans 26, BONE2 (secondary text)
##            "LeadLabel"        Alegreya Bold 32, bronze-hot (an instruction sentence under a header)
##            "HudLabel"         Alegreya Sans ExtraBold 30 with a K0 outline (over the scene)
##            "BigNumberLabel"   Alegreya ExtraBold 64, gold, heavy K0 outline (count-ins)
##            "PaperLabel"       = body text, for the inside of a CardPanel (kept for old callers)
##            "PaperHeaderLabel" Alegreya Bold 34, bronze-hot (a CardPanel's title)
##   Buttons: "Button"           secondary: dark raised leather, bronze rim, carved lip
##            "AccentButton"     primary: Issohadore red; one per screen, in the thumb zone
##            "QuietButton"      text only, bronze (tertiary: links, "Done")
##            "CompactButton"    secondary with tight padding, for grids of choices
##            "IconButton"       a round 96 px dark button holding one icon (back, ladder)
##            "ChipButton"       a small pill (toggles, filters); pressed = lit
##   Panels:  "BoardPanel"       the card: dark sheepskin, faint rim (the default panel too)
##            "CardPanel"        the accent card: same, bronze rim (tips, rewards)
##            "TilePanel"        a sunk tile with no rim (stat tiles, list rows)
##            "HeroPanel"        no fill, for hero areas that paint their own glow
##            "ClearPanel"       nothing drawn (layout only)

# ---------------------------------------------------------------- colour tokens
const C_INK := Color("#07060e")          ## K0: outlines, deepest shadow
const C_NIGHT := Color("#0a0c24")        ## NIGHT0: the sky at the top of every menu
const C_SURFACE := Color("#171110")      ## FLEECE1: cards (the dark sheepskin)
const C_RAISED := Color("#231915")       ## FLEECE2: secondary buttons, the lit segment
const C_RAISED_HI := Color("#33241c")    ## FLEECE3: hover / highlights on raised faces
const C_STROKE := Color("#4a3424")       ## FLEECE4: rims of cards and quiet frames
const C_STROKE_HI := Color("#6a4a2e")    ## FLEECE5: the top highlight row of raised faces
const C_SUNK := Color("#0e0a0a")         ## between K0 and FLEECE0, opaque: tiles, tracks, grooves
const C_BRONZE := Color("#e8b64c")       ## GOLD4: the bells' bronze; tags, selection, links
const C_BRONZE_HI := Color("#f8dc8a")    ## GOLD5
const C_BRONZE_LO := Color("#c08a2e")    ## GOLD3
const C_BRONZE_DEEP := Color("#8a5a1c")  ## GOLD2: bronze rims
const C_RED := Color("#c02a22")          ## RED3: the Issohadore jacket: primary actions
const C_RED_HI := Color("#e24a32")       ## RED4
const C_RED_LO := Color("#8e1a18")       ## RED2
const C_RED_LIP := Color("#5c0c10")      ## RED1: the primary button's carved lip and rim
const C_TEXT := Color("#fdf6df")         ## BONE4: primary text
const C_TEXT_2 := Color("#c4b494")       ## BONE2: secondary text
const C_TEXT_3 := Color("#8a7c6c")       ## BONE1: disabled, hints
const C_EMBER := Color("#f47e22")        ## FIRE4: heat accents (unison, streaks)
const C_EMBER_HOT := Color("#fde07a")    ## FIRE6: celebration

# ---------------------------------------------------------------- type tokens (px at the 720 base)
const SIZE_DISPLAY := 72    ## hero numbers (PxType "score" k=2)
const SIZE_TITLE := 56
const SIZE_HEADER := 40
const SIZE_VALUE := 44
const SIZE_LEAD := 32
const SIZE_BUTTON := 32
const SIZE_ACCENT := 34
const SIZE_TEXT := 30       ## body: never smaller in running text
const SIZE_SUB := 30
const SIZE_CAPTION := 26    ## the floor; captions only
# kept for old callers
const SIZE_HEADER_OLD := 46

# ---------------------------------------------------------------- shape tokens (art px; 1 art px = 3 screen px)
const PX := 3.0
const R_S := 2              ## chips, tiles
const R_M := 3              ## cards
const R_L := 4              ## buttons
const R_PILL := -1
const LIP := 2              ## carved thickness under raised buttons

## Content margins (screen px): left, top, right, bottom (the lip is under the bottom margin).
const BUTTON_PAD := Vector4(30, 18, 30, 18 + LIP * PX)
const ACCENT_PAD := Vector4(36, 20, 36, 20 + LIP * PX)
const COMPACT_PAD := Vector4(12, 18, 12, 18 + LIP * PX)
const CARD_PAD := Vector4(30, 24, 30, 24)
const TILE_PAD := Vector4(18, 15, 18, 15)

static var _theme: Theme
static var _icons := {}


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
	_label(t, "Label", text, SIZE_TEXT, C_TEXT)
	t.set_constant("line_spacing", "Label", 2)
	_label(t, "TitleLabel", serif_heavy, SIZE_TITLE, C_TEXT, "Label")
	_shadow(t, "TitleLabel", Vector2i(0, 4))
	_label(t, "HeaderLabel", serif, SIZE_HEADER, C_TEXT, "Label")
	_shadow(t, "HeaderLabel", Vector2i(0, 3))
	_label(t, "SubheaderLabel", caps, SIZE_SUB, C_BRONZE, "Label")
	_label(t, "OverlineLabel", PxType.font("caps_gold"), PxType.size("caps_gold"), Color.WHITE, "Label")
	t.set_constant("line_spacing", "OverlineLabel", 0)
	_label(t, "ValueLabel", heavy, SIZE_VALUE, C_TEXT, "Label")
	t.set_constant("line_spacing", "ValueLabel", -6)
	_label(t, "CaptionLabel", text, SIZE_CAPTION, C_TEXT_2, "Label")
	_label(t, "LeadLabel", serif, SIZE_LEAD, C_BRONZE_HI, "Label")
	_shadow(t, "LeadLabel", Vector2i(0, 3))
	_label(t, "HudLabel", heavy, 30, C_TEXT, "Label")
	t.set_color("font_outline_color", "HudLabel", C_INK)
	t.set_constant("outline_size", "HudLabel", 8)
	_label(t, "BigNumberLabel", serif_heavy, 64, C_BRONZE_HI, "Label")
	t.set_color("font_outline_color", "BigNumberLabel", C_INK)
	t.set_constant("outline_size", "BigNumberLabel", 12)
	t.set_color("font_shadow_color", "BigNumberLabel", C_RED_LO)
	t.set_constant("shadow_offset_x", "BigNumberLabel", 0)
	t.set_constant("shadow_offset_y", "BigNumberLabel", 6)
	t.set_constant("shadow_outline_size", "BigNumberLabel", 12)
	_label(t, "PaperLabel", text, SIZE_TEXT, C_TEXT, "Label")
	_label(t, "PaperHeaderLabel", serif, 34, C_BRONZE_HI, "Label")

	t.set_font("normal_font", "RichTextLabel", text)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font_size("normal_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_font_size("bold_font_size", "RichTextLabel", SIZE_TEXT)
	t.set_color("default_color", "RichTextLabel", C_TEXT)
	t.set_constant("line_separation", "RichTextLabel", 2)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# ---- secondary buttons: dark leather, a bronze rim, a carved lip that the face sinks onto
	var sec := _raised(C_RAISED, C_BRONZE_DEEP, C_STROKE_HI, C_INK, R_L, BUTTON_PAD)
	var sec_states := _states(sec, C_RAISED_HI, C_BRONZE_LO, C_RAISED, C_RAISED_HI)
	for type in ["Button", "OptionButton", "MenuButton"]:
		_set_states(t, type, sec_states)
		t.set_font("font", type, bold)
		t.set_font_size("font_size", type, SIZE_BUTTON)
		_button_colors(t, type, C_TEXT, C_BRONZE_HI)
		t.set_constant("outline_size", type, 0)
		t.set_constant("h_separation", type, 12)
		t.set_constant("icon_max_width", type, 0)
	t.set_icon("arrow", "OptionButton", icon("chevron_down"))
	t.set_constant("arrow_margin", "OptionButton", 24)

	# ---- primary: the red of the Issohadore jacket, a lighter top row, a deep red lip
	t.set_type_variation("AccentButton", "Button")
	var acc := _raised(C_RED, C_RED_LIP, C_RED_HI, C_RED_LIP, R_L, ACCENT_PAD)
	acc.shade = C_RED_LO
	_set_states(t, "AccentButton", _states(acc, Color("#cc3226"), C_RED_LIP, C_RED_LO, C_RED_HI))
	t.set_font("font", "AccentButton", heavy)
	t.set_font_size("font_size", "AccentButton", SIZE_ACCENT)
	_button_colors(t, "AccentButton", C_TEXT, C_TEXT)
	t.set_color("font_disabled_color", "AccentButton", C_TEXT_3)
	t.set_color("font_shadow_color", "AccentButton", Color(C_RED_LIP, 0.9))
	t.set_constant("shadow_offset_x", "AccentButton", 0)
	t.set_constant("shadow_offset_y", "AccentButton", 3)

	# ---- compact: the secondary face with tight padding (grids of choices)
	t.set_type_variation("CompactButton", "Button")
	var comp := _raised(C_RAISED, C_BRONZE_DEEP, C_STROKE_HI, C_INK, R_M, COMPACT_PAD)
	_set_states(t, "CompactButton", _states(comp, C_RAISED_HI, C_BRONZE_LO, C_RAISED, C_RAISED_HI))
	t.set_font_size("font_size", "CompactButton", 30)

	# ---- quiet: text only; a faint sunk pill shows under the finger
	t.set_type_variation("QuietButton", "Button")
	var quiet := PxStyle.make(Color.TRANSPARENT, Color.TRANSPARENT, R_L, Vector4(18, 12, 18, 12))
	var quiet_down := PxStyle.make(C_SUNK, Color.TRANSPARENT, R_L, Vector4(18, 12, 18, 12))
	for s in ["normal", "hover", "disabled", "focus"]:
		t.set_stylebox(s, "QuietButton", quiet)
	t.set_stylebox("pressed", "QuietButton", quiet_down)
	t.set_stylebox("hover_pressed", "QuietButton", quiet_down)
	t.set_font("font", "QuietButton", bold)
	t.set_font_size("font_size", "QuietButton", SIZE_TEXT)
	_button_colors(t, "QuietButton", C_BRONZE, C_BRONZE_HI)

	# ---- icon button: a round dark button for one icon
	t.set_type_variation("IconButton", "Button")
	var ib := PxStyle.make(Color(C_SURFACE, 0.82), C_STROKE, R_PILL, Vector4(0, 0, 0, 0))
	ib.highlight = Color(C_STROKE_HI, 0.6)
	var ib_down := ib.variant(C_RAISED_HI, C_BRONZE_DEEP)
	for s in ["normal", "hover", "focus"]:
		t.set_stylebox(s, "IconButton", ib)
	t.set_stylebox("disabled", "IconButton", ib.variant(Color(C_SURFACE, 0.5), Color(C_STROKE, 0.5)))
	t.set_stylebox("pressed", "IconButton", ib_down)
	t.set_stylebox("hover_pressed", "IconButton", ib_down)
	_button_colors(t, "IconButton", C_TEXT, C_BRONZE_HI)

	# ---- chips: small pills; pressed (toggle on) is lit bronze-on-dark
	t.set_type_variation("ChipButton", "Button")
	var chip := PxStyle.make(C_SUNK, C_STROKE, R_PILL, Vector4(24, 12, 24, 12))
	var chip_on := chip.variant(C_RAISED_HI, C_BRONZE)
	for s in ["normal", "hover", "focus", "disabled"]:
		t.set_stylebox(s, "ChipButton", chip)
	t.set_stylebox("pressed", "ChipButton", chip_on)
	t.set_stylebox("hover_pressed", "ChipButton", chip_on)
	t.set_font("font", "ChipButton", bold)
	t.set_font_size("font_size", "ChipButton", 28)
	_button_colors(t, "ChipButton", C_TEXT_2, C_BRONZE_HI)

	# ---- panels
	var board := PxStyle.make(C_SURFACE, C_STROKE, R_M, CARD_PAD)
	board.highlight = C_RAISED_HI
	board.grain = fleece()
	var card := PxStyle.make(C_SURFACE, C_BRONZE_DEEP, R_M, CARD_PAD)
	card.highlight = C_STROKE
	card.grain = fleece()
	var tile := PxStyle.make(C_SUNK, C_RAISED, R_S, TILE_PAD)
	for type in ["Panel", "PanelContainer", "PopupPanel"]:
		t.set_stylebox("panel", type, board)
	t.set_type_variation("BoardPanel", "PanelContainer")
	t.set_stylebox("panel", "BoardPanel", board)
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation("TilePanel", "PanelContainer")
	t.set_stylebox("panel", "TilePanel", tile)
	t.set_type_variation("HeroPanel", "PanelContainer")
	t.set_stylebox("panel", "HeroPanel", StyleBoxEmpty.new())
	t.set_type_variation("ClearPanel", "PanelContainer")
	t.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())
	var tip := PxStyle.make(C_RAISED, C_BRONZE_DEEP, R_S, Vector4(18, 12, 18, 12))
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", SIZE_CAPTION)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# ---- popup menus (OptionButton lists)
	t.set_stylebox("panel", "PopupMenu", PxStyle.make(C_RAISED, C_BRONZE_DEEP, R_M, Vector4(12, 12, 12, 12)))
	t.set_stylebox("hover", "PopupMenu", PxStyle.make(C_RAISED_HI, Color.TRANSPARENT, R_S, Vector4(18, 6, 18, 6)))
	t.set_stylebox("separator", "PopupMenu", _line(C_STROKE))
	t.set_font("font", "PopupMenu", bold)
	t.set_font_size("font_size", "PopupMenu", SIZE_BUTTON)
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_BRONZE_HI)
	t.set_color("font_disabled_color", "PopupMenu", C_TEXT_3)
	t.set_constant("v_separation", "PopupMenu", 30)
	t.set_icon("radio_checked", "PopupMenu", icon("radio_on"))
	t.set_icon("radio_unchecked", "PopupMenu", icon("radio_off"))
	t.set_icon("checked", "PopupMenu", icon("check_on"))
	t.set_icon("unchecked", "PopupMenu", icon("check_off"))

	# ---- text fields: sunk
	var field := PxStyle.make(C_SUNK, C_STROKE, R_S, Vector4(18, 15, 18, 15))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field.variant(C_SUNK, C_BRONZE))
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", C_TEXT_2)
	t.set_color("caret_color", "LineEdit", C_BRONZE)
	t.set_color("selection_color", "LineEdit", Color(C_RED, 0.7))
	t.set_font_size("font_size", "LineEdit", SIZE_TEXT)

	# ---- sliders: a sunk pill groove, the filled part bronze, a round bronze knob
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, PxStyle.make(C_SUNK, C_STROKE, R_PILL, Vector4(0, 6, 0, 6)))
		var filled := PxStyle.make(C_BRONZE_LO, Color.TRANSPARENT, R_PILL, Vector4(0, 6, 0, 6))
		filled.highlight = C_BRONZE
		t.set_stylebox("grabber_area", type, filled)
		t.set_stylebox("grabber_area_highlight", type, filled)
		t.set_icon("grabber", type, icon("knob"))
		t.set_icon("grabber_highlight", type, icon("knob_hi"))
		t.set_icon("grabber_disabled", type, icon("knob_off"))
		t.set_icon("tick", type, icon("tick"))
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
		_button_colors(t, type, C_TEXT, C_TEXT)
		t.set_constant("h_separation", type, 18)
	for pair in [["checked", "toggle_on"], ["unchecked", "toggle_off"], ["checked_disabled", "toggle_on_off"],
			["unchecked_disabled", "toggle_off_off"], ["checked_mirrored", "toggle_on"], ["unchecked_mirrored", "toggle_off"],
			["checked_disabled_mirrored", "toggle_on_off"], ["unchecked_disabled_mirrored", "toggle_off_off"]]:
		t.set_icon(pair[0], "CheckButton", icon(pair[1]))
	t.set_icon("checked", "CheckBox", icon("check_on"))
	t.set_icon("unchecked", "CheckBox", icon("check_off"))
	t.set_icon("checked_disabled", "CheckBox", icon("check_on"))
	t.set_icon("unchecked_disabled", "CheckBox", icon("check_off"))
	t.set_icon("radio_checked", "CheckBox", icon("radio_on"))
	t.set_icon("radio_unchecked", "CheckBox", icon("radio_off"))
	t.set_icon("radio_checked_disabled", "CheckBox", icon("radio_off"))
	t.set_icon("radio_unchecked_disabled", "CheckBox", icon("radio_off"))

	# ---- scroll bars: never drawn (touch-drag scrolling only; UIKit hides them too)
	for type in ["VScrollBar", "HScrollBar"]:
		for s in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(s, type, StyleBoxEmpty.new())
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 0)
	t.set_constant("scrollbar_v_separation", "ScrollContainer", 0)

	# ---- progress: a red fill in a sunk pill
	t.set_stylebox("background", "ProgressBar", PxStyle.make(C_SUNK, C_STROKE, R_PILL, Vector4(6, 6, 6, 6)))
	var pf := PxStyle.make(C_RED, Color.TRANSPARENT, R_PILL, Vector4(6, 6, 6, 6))
	pf.highlight = C_RED_HI
	t.set_stylebox("fill", "ProgressBar", pf)
	t.set_color("font_color", "ProgressBar", C_TEXT)
	t.set_color("font_outline_color", "ProgressBar", C_INK)
	t.set_constant("outline_size", "ProgressBar", 10)
	t.set_font("font", "ProgressBar", heavy)
	t.set_font_size("font_size", "ProgressBar", SIZE_CAPTION)

	# ---- separators: one art-px line
	t.set_stylebox("separator", "HSeparator", _line(C_STROKE))
	t.set_constant("separation", "HSeparator", 24)
	t.set_stylebox("separator", "VSeparator", _line(C_STROKE))

	# ---- tabs (TabBar / TabContainer; UIKit.tabs() draws its own segmented control)
	var tab_on := PxStyle.make(C_RAISED_HI, C_BRONZE_DEEP, R_M, Vector4(24, 15, 24, 15))
	var tab_off := PxStyle.make(Color.TRANSPARENT, Color.TRANSPARENT, R_M, Vector4(24, 15, 24, 15))
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, tab_on)
		t.set_stylebox("tab_hovered", type, tab_off)
		t.set_stylebox("tab_unselected", type, tab_off)
		t.set_stylebox("tab_disabled", type, tab_off)
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, bold)
		t.set_font_size("font_size", type, SIZE_TEXT)
		t.set_color("font_selected_color", type, C_BRONZE_HI)
		t.set_color("font_hovered_color", type, C_TEXT)
		t.set_color("font_unselected_color", type, C_TEXT_2)
		t.set_color("font_disabled_color", type, C_TEXT_3)
	t.set_stylebox("panel", "TabContainer", board)
	_theme = t
	return t


static func _label(t: Theme, type: String, font: Font, size: int, color: Color, base := "") -> void:
	if base != "":
		t.set_type_variation(type, base)
	t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)


## A hard K0 drop shadow under the letters (no outline: clean on the dark cards).
static func _shadow(t: Theme, type: String, offset: Vector2i) -> void:
	t.set_color("font_shadow_color", type, Color(C_INK, 0.85))
	t.set_constant("shadow_offset_x", type, offset.x)
	t.set_constant("shadow_offset_y", type, offset.y)
	t.set_constant("shadow_outline_size", type, 0)


static func _button_colors(t: Theme, type: String, c: Color, lit: Color) -> void:
	t.set_color("font_color", type, c)
	t.set_color("font_hover_color", type, c)
	t.set_color("font_focus_color", type, c)
	t.set_color("font_pressed_color", type, lit)
	t.set_color("font_hover_pressed_color", type, lit)
	t.set_color("font_disabled_color", type, C_TEXT_3)
	t.set_color("icon_normal_color", type, c)
	t.set_color("icon_focus_color", type, c)
	t.set_color("icon_hover_color", type, c)
	t.set_color("icon_pressed_color", type, lit)
	t.set_color("icon_hover_pressed_color", type, lit)
	t.set_color("icon_disabled_color", type, C_TEXT_3)


## A raised face: fill, rim, a light top row, and a lip of `lip_c` under it.
static func _raised(fill: Color, rim: Color, hi: Color, lip_c: Color, r: int, pad: Vector4) -> PxStyle:
	var s := PxStyle.make(fill, rim, r, pad)
	s.highlight = hi
	s.lip = LIP
	s.lip_color = lip_c
	return s


## normal, hover, pressed (sunk onto the lip), disabled (flat, dim) from one raised face.
static func _states(s: PxStyle, hover_fill: Color, down_rim: Color, off_fill: Color, down_hi: Color) -> Dictionary:
	var hover := s.variant(hover_fill, s.border, s.highlight)
	hover.shade = s.shade
	var down := s.variant(s.fill.darkened(0.08), down_rim, down_hi.darkened(0.1), LIP)
	down.shade = Color.TRANSPARENT
	var off := s.variant(Color(off_fill, 0.6), Color(C_STROKE, 0.6))
	off.lip_color = Color(s.lip_color, 0.4)
	off.shade = Color.TRANSPARENT
	return {"normal": s, "hover": hover, "pressed": down, "hover_pressed": down, "disabled": off, "focus": s}


static func _set_states(t: Theme, type: String, st: Dictionary) -> void:
	for k in st:
		t.set_stylebox(k, type, st[k])


## A one-art-px horizontal line (separators).
static func _line(c: Color) -> PxStyle:
	var s := PxStyle.make(c, Color.TRANSPARENT, 0, Vector4(0, 1.5, 0, 1.5))
	return s


# ---------------------------------------------------------------- icons

## Pixel maps for the kit's glyph icons: '#' ink (white, tinted by the button's icon colour),
## '+' a darker shade of it, '.' clear. Drawn x3 like the art.
const GLYPHS := {
	"chevron_left": [
		"......##", ".....###", "....###.", "...###..", "..###...", ".###....", "###.....",
		".###....", "..###...", "...###..", "....###.", ".....###", "......##"],
	"ladder": [
		".###########.", "##.#######.##", "#..#######..#", "##.#######.##", "...#######...",
		"....#####....", ".....###.....", "......#......", "......#......", ".....###.....",
		"...#######...", "...#######..."],
	"check": [
		"..........##", ".........###", "........###.", "##.....###..", "###...###...",
		".###.###....", "..#####.....", "...###......"],
	"tick": ["#", "#", "#"],
	"dot": [".##.", "####", "####", ".##."],
	"plus": ["..##..", "..##..", "######", "######", "..##..", "..##.."],
}


## The cards' sheepskin: a 24x16 art-px tile of SURFACE with small curls of the fleece ramp (a lit
## top pixel, a dark one under it), laid over a card's fill.
static func fleece() -> Texture2D:
	if _icons.has("_fleece"):
		return _icons["_fleece"]
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var seed := 31
	for i in 22:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var x := seed % 24
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var y := seed % 16
		var lit := Color(C_RAISED, 0.9) if i % 3 else Color(C_RAISED_HI, 0.55)
		img.set_pixel(x, y, lit)
		img.set_pixel((x + 1) % 24, y, Color(C_RAISED, 0.6))
		img.set_pixel(x, (y + 1) % 16, Color(PixelPalette.FLEECE[0], 0.8))
	_icons["_fleece"] = ImageTexture.create_from_image(img)
	return _icons["_fleece"]


## A baked icon (cached): a GLYPHS map, or one of the painted controls (toggles, knob, boxes).
static func icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var img: Image = null
	if GLYPHS.has(name):
		img = _glyph(GLYPHS[name])
	elif name == "chevron_right":
		img = _glyph(GLYPHS["chevron_left"])
		img.flip_x()
	elif name == "chevron_down":
		img = _glyph(GLYPHS["chevron_left"])
		img.rotate_90(COUNTERCLOCKWISE)
	else:
		img = _painted(name)
	img.resize(img.get_width() * int(PX), img.get_height() * int(PX), Image.INTERPOLATE_NEAREST)
	_icons[name] = ImageTexture.create_from_image(img)
	return _icons[name]


static func _glyph(rows: Array) -> Image:
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := Image.create(w, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			match r[x]:
				"#":
					img.set_pixel(x, y, Color.WHITE)
				"+":
					img.set_pixel(x, y, Color(0.7, 0.7, 0.7))
	return img


static func _painted(name: String) -> Image:
	match name:
		"toggle_on", "toggle_off", "toggle_on_off", "toggle_off_off":
			# a 24x14 pill track and a 10x10 knob
			var on := name.begins_with("toggle_on")
			var dim := name.ends_with("_off_off") or name == "toggle_on_off"
			var img := Image.create(24, 14, false, Image.FORMAT_RGBA8)
			var track := C_RED if on else C_INK
			var rim := C_RED_LIP if on else C_STROKE
			PxStyle.paint(img, Rect2i(0, 0, 24, 14), 7, rim)
			PxStyle.paint(img, Rect2i(1, 1, 22, 12), 6, track)
			if on:
				PxStyle.paint(img, Rect2i(4, 2, 12, 1), 0, C_RED_HI)
			var kx := 12 if on else 2
			PxStyle.paint(img, Rect2i(kx, 2, 10, 10), 5, C_INK)
			PxStyle.paint(img, Rect2i(kx, 2, 10, 9), 5, C_TEXT if on else C_TEXT_2)
			PxStyle.paint(img, Rect2i(kx + 3, 3, 4, 1), 0, Color.WHITE if on else C_TEXT)
			if dim:
				_fade(img, 0.45)
			return img
		"knob", "knob_hi", "knob_off":
			var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
			PxStyle.paint(img, Rect2i(0, 1, 14, 13), 7, C_INK)
			PxStyle.paint(img, Rect2i(0, 0, 14, 13), 7, C_BRONZE_DEEP)
			PxStyle.paint(img, Rect2i(1, 1, 12, 11), 6, C_BRONZE_HI if name == "knob_hi" else C_BRONZE)
			PxStyle.paint(img, Rect2i(4, 2, 6, 1), 0, Color.WHITE if name == "knob_hi" else C_BRONZE_HI)
			if name == "knob_off":
				_fade(img, 0.45)
			return img
		"replay":
			# a two-pixel ring open at the upper right, its top end an arrowhead pointing on round
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			for y in 16:
				for x in 16:
					var dx := x + 0.5 - 8.0
					var dy := y + 0.5 - 8.0
					var d := sqrt(dx * dx + dy * dy)
					var a := atan2(dy, dx)
					if d >= 4.6 and d <= 7.0 and not (a > -1.45 and a < -0.35):
						img.set_pixel(x, y, Color.WHITE)
			for x in range(8, 13):
				var half := int((12 - x) * 0.75 + 0.5)
				for y in range(2 - half, 3 + half):
					if y >= 0:
						img.set_pixel(x, y, Color.WHITE)
			return img
		"check_on", "check_off", "radio_on", "radio_off":
			var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
			var is_round := name.begins_with("radio")
			var r := 7 if is_round else 3
			var on := name.ends_with("_on")
			PxStyle.paint(img, Rect2i(0, 0, 14, 14), r, C_RED_LIP if on else C_STROKE)
			PxStyle.paint(img, Rect2i(1, 1, 12, 12), r - 1, C_RED if on else C_INK)
			if on and is_round:
				PxStyle.paint(img, Rect2i(4, 4, 6, 6), 3, C_TEXT)
			elif on:
				var g := _glyph(GLYPHS["check"])
				for y in g.get_height():
					for x in g.get_width():
						if g.get_pixel(x, y).a > 0.0:
							img.set_pixel(1 + x, 3 + y, C_TEXT)
			return img
	return Image.create(1, 1, false, Image.FORMAT_RGBA8)


static func _fade(img: Image, a: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(c, c.a * a))
