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
##            "LeadLabel"        Alegreya Bold 30, pale gold (an instruction sentence under a header)
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


## Builds (once) and returns the shared theme: the Woodcut look's "Night" menus (Daniele's pick,
## 2026-11-02): black paper, cream type and rules, buttons shaped like the play screen's notes (flat
## ovals: black with a cream rim, the main action red), all set in the woodcut's pixel capitals
## (PxType, fonts/woodcut5) at whole multiples of their pixels.
const K := Color("#141014")
const C := Color("#efe6d2")
const R := Color("#c8352a")
const G := Color("#c9bba0")
const B := Color("#4a3c38")
const PX := 3                       ## screen px per type px for body text


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := PxType.font()
	var s1 := PxType.LINE * 3          ## body, buttons, captions (33)
	var s2 := PxType.LINE * 4          ## headers, the main action (44)
	var s3 := PxType.LINE * 6          ## titles, big numbers (66)
	t.default_font = f
	t.default_font_size = s1

	# ---- labels
	_label(t, "Label", f, s1, C)
	t.set_constant("line_spacing", "Label", 6)
	_label(t, "TitleLabel", f, s3, C, "Label")
	_label(t, "HeaderLabel", f, s2, C, "Label")
	_label(t, "SubheaderLabel", f, s1, R, "Label")
	_label(t, "CaptionLabel", f, s1, G, "Label")
	_label(t, "LeadLabel", f, s1, C, "Label")
	_label(t, "HudLabel", f, s1, C, "Label")
	_label(t, "BigNumberLabel", f, s3, C, "Label")
	_label(t, "PaperLabel", f, s1, K, "Label")
	_label(t, "PaperHeaderLabel", f, s2, R, "Label")
	for type in ["Label", "TitleLabel", "HeaderLabel", "SubheaderLabel", "CaptionLabel", "LeadLabel", "HudLabel",
			"BigNumberLabel", "PaperLabel", "PaperHeaderLabel"]:
		t.set_constant("outline_size", type, 0)
		t.set_constant("shadow_outline_size", type, 0)
		t.set_color("font_shadow_color", type, Color(0, 0, 0, 0))

	t.set_font("normal_font", "RichTextLabel", f)
	t.set_font("bold_font", "RichTextLabel", f)
	t.set_font_size("normal_font_size", "RichTextLabel", s1)
	t.set_font_size("bold_font_size", "RichTextLabel", s1)
	t.set_color("default_color", "RichTextLabel", C)
	t.set_constant("line_separation", "RichTextLabel", 6)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# ---- buttons: flat ovals like the notes, a cream rim on black; pressed they print cream
	var normal := _oval(K, C, Vector4(40, 16, 40, 16))
	var hover := _oval(K, C, Vector4(40, 16, 40, 16))
	var pressed := _oval(C, C, Vector4(40, 19, 40, 13))
	var disabled := _oval(K, B, Vector4(40, 16, 40, 16))
	var focus := _oval(Color(0, 0, 0, 0), R, Vector4(40, 16, 40, 16))
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, f)
		t.set_font_size("font_size", type, s1)
		_button_colors(t, type, C, C)
		t.set_color("font_pressed_color", type, K)
		t.set_color("font_hover_pressed_color", type, K)
		t.set_color("icon_pressed_color", type, K)
		t.set_constant("outline_size", type, 0)
		t.set_constant("h_separation", type, 12)
	t.set_icon("arrow", "OptionButton", _icon("arrow"))
	t.set_constant("arrow_margin", "OptionButton", 30)

	# the one main action: a red oval with a cream rim
	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _oval(R, C, Vector4(56, 20, 56, 20)))
	t.set_stylebox("hover", "AccentButton", _oval(R, C, Vector4(56, 20, 56, 20)))
	t.set_stylebox("pressed", "AccentButton", _oval(C, R, Vector4(56, 23, 56, 17)))
	t.set_stylebox("hover_pressed", "AccentButton", _oval(C, R, Vector4(56, 23, 56, 17)))
	t.set_stylebox("disabled", "AccentButton", _oval(B, G, Vector4(56, 20, 56, 20)))
	t.set_font("font", "AccentButton", f)
	t.set_font_size("font_size", "AccentButton", s2)
	_button_colors(t, "AccentButton", C, C)
	t.set_color("font_pressed_color", "AccentButton", R)
	t.set_color("font_hover_pressed_color", "AccentButton", R)
	t.set_constant("outline_size", "AccentButton", 0)

	# dense grids of choices: a squarer stamp
	t.set_type_variation("CompactButton", "Button")
	t.set_stylebox("normal", "CompactButton", _plate(K, C, Vector4(16, 14, 16, 14)))
	t.set_stylebox("hover", "CompactButton", _plate(K, C, Vector4(16, 14, 16, 14)))
	t.set_stylebox("pressed", "CompactButton", _plate(C, C, Vector4(16, 17, 16, 11)))
	t.set_stylebox("hover_pressed", "CompactButton", _plate(C, C, Vector4(16, 17, 16, 11)))
	t.set_stylebox("disabled", "CompactButton", _plate(K, B, Vector4(16, 14, 16, 14)))
	t.set_stylebox("focus", "CompactButton", _plate(Color(0, 0, 0, 0), R, Vector4(16, 14, 16, 14)))

	# Back and the secondary actions: the type alone over a dotted cream rule
	t.set_type_variation("QuietButton", "Button")
	var quiet := _rule_box(B, Vector4(18, 12, 18, 14))
	var quiet_down := _rule_box(C, Vector4(18, 14, 18, 12))
	for st in ["normal", "hover", "disabled"]:
		t.set_stylebox(st, "QuietButton", quiet)
	t.set_stylebox("pressed", "QuietButton", quiet_down)
	t.set_stylebox("hover_pressed", "QuietButton", quiet_down)
	t.set_font_size("font_size", "QuietButton", s1)
	t.set_color("font_color", "QuietButton", G)
	t.set_color("font_hover_color", "QuietButton", C)
	t.set_color("font_focus_color", "QuietButton", C)
	t.set_color("font_pressed_color", "QuietButton", C)
	t.set_color("font_hover_pressed_color", "QuietButton", C)
	t.set_color("font_disabled_color", "QuietButton", B)

	# ---- panels: black boards in a cream rule; paper cards in an ink border
	var board := _plate(K, C, Vector4(28, 24, 28, 24))
	var card := _plate(C, K, Vector4(28, 24, 28, 24))
	for type in ["Panel", "PanelContainer", "PopupPanel"]:
		t.set_stylebox("panel", type, board)
	t.set_type_variation("BoardPanel", "PanelContainer")
	t.set_stylebox("panel", "BoardPanel", board)
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation("ClearPanel", "PanelContainer")
	t.set_stylebox("panel", "ClearPanel", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", card)
	t.set_color("font_color", "TooltipLabel", K)
	t.set_font("font", "TooltipLabel", f)
	t.set_font_size("font_size", "TooltipLabel", s1)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# ---- popup menus
	t.set_stylebox("panel", "PopupMenu", board)
	t.set_stylebox("hover", "PopupMenu", _plate(R, R, Vector4(12, 6, 12, 6)))
	t.set_stylebox("separator", "PopupMenu", _rule_box(B, Vector4(0, 4, 0, 4)))
	t.set_font("font", "PopupMenu", f)
	t.set_font_size("font_size", "PopupMenu", s1)
	t.set_color("font_color", "PopupMenu", C)
	t.set_color("font_hover_color", "PopupMenu", C)
	t.set_color("font_disabled_color", "PopupMenu", B)
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_icon("radio_checked", "PopupMenu", _icon("radio_on"))
	t.set_icon("radio_unchecked", "PopupMenu", _icon("radio_off"))
	t.set_icon("checked", "PopupMenu", _icon("check_on"))
	t.set_icon("unchecked", "PopupMenu", _icon("check_off"))

	# ---- text fields
	var field := _plate(K, G, Vector4(18, 12, 18, 12))
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", _plate(K, C, Vector4(18, 12, 18, 12)))
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_font("font", "LineEdit", f)
	t.set_color("font_color", "LineEdit", C)
	t.set_color("font_placeholder_color", "LineEdit", G)
	t.set_color("caret_color", "LineEdit", R)
	t.set_color("selection_color", "LineEdit", Color(R, 0.7))
	t.set_font_size("font_size", "LineEdit", s1)

	# ---- sliders: a brown groove, the filled part red, a cream oval knob
	for type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, _groove(B))
		t.set_stylebox("grabber_area", type, _groove(R))
		t.set_stylebox("grabber_area_highlight", type, _groove(R))
		t.set_icon("grabber", type, _icon("grabber"))
		t.set_icon("grabber_highlight", type, _icon("grabber_hi"))
		t.set_icon("grabber_disabled", type, _icon("grabber_off"))
		t.set_icon("tick", type, _icon("tick"))
		t.set_constant("center_grabber", type, 0)

	# ---- toggles and check boxes
	var row := StyleBoxEmpty.new()
	row.content_margin_left = 6
	row.content_margin_right = 6
	row.content_margin_top = 12
	row.content_margin_bottom = 12
	for type in ["CheckButton", "CheckBox"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, row)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, f)
		t.set_font_size("font_size", type, s1)
		_button_colors(t, type, C, C)
		t.set_constant("h_separation", type, 18)
	for suffix in ["", "_mirrored"]:
		t.set_icon("checked" + suffix, "CheckButton", _icon("toggle_on"))
		t.set_icon("unchecked" + suffix, "CheckButton", _icon("toggle_off"))
		t.set_icon("checked_disabled" + suffix, "CheckButton", _icon("toggle_on_off"))
		t.set_icon("unchecked_disabled" + suffix, "CheckButton", _icon("toggle_off_off"))
	t.set_icon("checked", "CheckBox", _icon("check_on"))
	t.set_icon("unchecked", "CheckBox", _icon("check_off"))
	t.set_icon("checked_disabled", "CheckBox", _icon("check_on"))
	t.set_icon("unchecked_disabled", "CheckBox", _icon("check_off"))
	t.set_icon("radio_checked", "CheckBox", _icon("radio_on"))
	t.set_icon("radio_unchecked", "CheckBox", _icon("radio_off"))
	t.set_icon("radio_checked_disabled", "CheckBox", _icon("radio_off"))
	t.set_icon("radio_unchecked_disabled", "CheckBox", _icon("radio_off"))

	# ---- scroll bars: a thin cream grabber on a brown line
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _plate(B, B, Vector4(4, 4, 4, 4)))
		t.set_stylebox("scroll_focus", type, _plate(B, B, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber", type, _plate(C, C, Vector4(4, 8, 4, 8)))
		t.set_stylebox("grabber_highlight", type, _plate(C, C, Vector4(4, 8, 4, 8)))
		t.set_stylebox("grabber_pressed", type, _plate(R, R, Vector4(4, 8, 4, 8)))

	# ---- progress: a red fill in a brown groove
	t.set_stylebox("background", "ProgressBar", _plate(K, B, Vector4(6, 6, 6, 6)))
	t.set_stylebox("fill", "ProgressBar", _plate(R, R, Vector4(6, 6, 6, 6)))
	t.set_color("font_color", "ProgressBar", C)
	t.set_constant("outline_size", "ProgressBar", 0)
	t.set_font("font", "ProgressBar", f)
	t.set_font_size("font_size", "ProgressBar", s1)

	# ---- separators: a dotted cream rule
	t.set_stylebox("separator", "HSeparator", _rule_box(G, Vector4(0, 4, 0, 4)))
	t.set_constant("separation", "HSeparator", 36)

	# ---- tabs: stamps, the chosen one printed cream
	for type in ["TabBar", "TabContainer"]:
		t.set_stylebox("tab_selected", type, _plate(C, C, Vector4(20, 12, 20, 12)))
		t.set_stylebox("tab_hovered", type, _plate(K, C, Vector4(20, 12, 20, 12)))
		t.set_stylebox("tab_unselected", type, _plate(K, G, Vector4(20, 12, 20, 12)))
		t.set_stylebox("tab_disabled", type, _plate(K, B, Vector4(20, 12, 20, 12)))
		t.set_stylebox("tab_focus", type, StyleBoxEmpty.new())
		t.set_font("font", type, f)
		t.set_font_size("font_size", type, s1)
		t.set_color("font_selected_color", type, K)
		t.set_color("font_hovered_color", type, C)
		t.set_color("font_unselected_color", type, G)
		t.set_color("font_disabled_color", type, B)
		t.set_constant("outline_size", type, 0)
	t.set_stylebox("panel", "TabContainer", board)
	_theme = t
	return t


## A flat oval like a note: `fill` inside a rim of `rim`, three screen px per art px.
static func _oval(fill: Color, rim: Color, content: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(PX * 2)
	sb.set_corner_radius_all(999)
	sb.corner_detail = 6
	sb.anti_aliasing = false
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	sb.expand_margin_bottom = 0
	sb.shadow_size = 0
	return sb


## A square stamp: `fill` in an ink border of `rim`.
static func _plate(fill: Color, rim: Color, content: Vector4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(PX)
	sb.anti_aliasing = false
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## A groove for sliders: a short band of `col`.
static func _groove(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.anti_aliasing = false
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## A rule under the type (Back, separators): a dotted line of `col` along the bottom.
static func _rule_box(col: Color, content: Vector4) -> StyleBoxTexture:
	var img := Image.create(PX * 4, PX * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, PX, PX * 2, PX), col)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.texture_margin_top = PX * 2 - 1
	sb.texture_margin_bottom = 1
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


## The theme's small pictures, drawn in the inks at PX screen px per art px.
static var _icons := {}
const ICONS := {
	"toggle_on": ["..CCCCCCCCCC..", ".CRRRRRRRRCCC.", "CRRRRRRRRCKKKC", "CRRRRRRRRCKKKC", "CRRRRRRRRCKKKC", ".CRRRRRRRRCCC.", "..CCCCCCCCCC.."],
	"toggle_off": ["..CCCCCCCCCC..", ".CCCBBBBBBBBC.", "CKKKCBBBBBBBBC", "CKKKCBBBBBBBBC", "CKKKCBBBBBBBBC", ".CCCBBBBBBBBC.", "..CCCCCCCCCC.."],
	"toggle_on_off": ["..GGGGGGGGGG..", ".GBBBBBBBBGGG.", "GBBBBBBBBGKKKG", "GBBBBBBBBGKKKG", "GBBBBBBBBGKKKG", ".GBBBBBBBBGGG.", "..GGGGGGGGGG.."],
	"toggle_off_off": ["..BBBBBBBBBB..", ".BBBKKKKKKKKB.", "BKKKBKKKKKKKKB", "BKKKBKKKKKKKKB", "BKKKBKKKKKKKKB", ".BBBKKKKKKKKB.", "..BBBBBBBBBB.."],
	"check_on": ["CCCCCCC", "CRRRRRC", "CRRRRCC", "CCRRCRC", "CRCCRRC", "CRRRRRC", "CCCCCCC"],
	"check_off": ["CCCCCCC", "CKKKKKC", "CKKKKKC", "CKKKKKC", "CKKKKKC", "CKKKKKC", "CCCCCCC"],
	"radio_on": ["..CCC..", ".CRRRC.", "CRRRRRC", "CRRRRRC", "CRRRRRC", ".CRRRC.", "..CCC.."],
	"radio_off": ["..CCC..", ".CKKKC.", "CKKKKKC", "CKKKKKC", "CKKKKKC", ".CKKKC.", "..CCC.."],
	"grabber": ["..KKKKK..", ".KCCCCCK.", "KCCCCCCCK", "KCCCCCCCK", ".KCCCCCK.", "..KKKKK.."],
	"grabber_hi": ["..KKKKK..", ".KRRRRRK.", "KRRRRRRRK", "KRRRRRRRK", ".KRRRRRK.", "..KKKKK.."],
	"grabber_off": ["..KKKKK..", ".KBBBBBK.", "KBBBBBBBK", "KBBBBBBBK", ".KBBBBBK.", "..KKKKK.."],
	"tick": ["G", "G", "G"],
	"arrow": ["CCCCC", ".CCC.", "..C.."],
}


static func _icon(name: String) -> Texture2D:
	if _icons.has(name):
		return _icons[name]
	var rows: Array = ICONS.get(name, ["C"])
	var h := rows.size()
	var w := (rows[0] as String).length()
	var img := Image.create(w * PX, h * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var inks := {"K": K, "C": C, "R": R, "G": G, "B": B}
	for y in h:
		var row: String = rows[y]
		for x in w:
			if inks.has(row[x]):
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), inks[row[x]])
	var tex := ImageTexture.create_from_image(img)
	_icons[name] = tex
	return tex


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
