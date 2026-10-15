class_name Swatch
extends Button
## A picture choice of the menu kit (added with the workshop): a tile showing the option drawn in
## pixel art (PixelPic) over a one-line caption. States:
##   chosen   a bronze rim, the face lit, a check in a bronze corner badge, the caption bronze
##   open     a dark sheepskin tile, the caption cream
##   locked   the picture dimmed, a small lock badge in its corner; the caption says what opens it
##            (bronze)
## Tapping a locked swatch still emits `pressed` (the screen says what it needs); it never toggles.
##   Swatch.make(id, picture, caption, chosen, locked, on_press, region := Rect2()) -> Swatch

const PIC_PAD := 12.0

var id := ""
var chosen := false
var locked := false
var pic: PixelPic
## The light the picture is shown in (its tint when open; locked dims it): above white brightens it,
## for a dark carving seen up close, as if held to the fire.
var light := Color.WHITE:
	set(v):
		light = v
		if pic != null:
			pic.tint = light * Color(0.6, 0.55, 0.52) if locked else light
var caption: Label
var _badge: Control


static func make(p_id: String, picture: Texture2D, text: String, p_chosen: bool, p_locked: bool, on_press: Callable, region := Rect2()) -> Swatch:
	var s := Swatch.new()
	s.id = p_id
	s.name = "Opt_" + p_id
	s.pic.texture = picture
	s.pic.region = region
	s.caption.text = text
	s.set_state(p_chosen, p_locked)
	if on_press.is_valid():
		s.pressed.connect(on_press.bind(p_id))
	return s


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = PIC_PAD
	box.offset_right = -PIC_PAD
	box.offset_top = PIC_PAD
	box.offset_bottom = -UIKit.S2
	box.add_theme_constant_override("separation", UIKit.S1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	pic = PixelPic.new()
	pic.name = "Pic"
	pic.step = 3
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(pic)
	caption = Label.new()
	caption.name = "Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_font_override("font", Palette.text_font("Bold"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(caption)
	UIKit.fit_label(caption, 26)
	_badge = Control.new()
	_badge.name = "Badge"
	_badge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.draw.connect(_draw_badge)
	add_child(_badge)
	UIKit.juice(self)


func set_state(p_chosen: bool, p_locked: bool) -> void:
	chosen = p_chosen
	locked = p_locked
	var fill: Color = WoodcutTheme.C_RAISED_HI if chosen else (WoodcutTheme.C_SUNK if locked else WoodcutTheme.C_SURFACE)
	var rim: Color = WoodcutTheme.C_BRONZE if chosen else (Color(WoodcutTheme.C_STROKE, 0.5) if locked else WoodcutTheme.C_STROKE)
	var sb := PxStyle.make(fill, rim, WoodcutTheme.R_M, Vector4.ZERO)
	sb.border_px = 2 if chosen else 1
	if chosen:
		sb.highlight = WoodcutTheme.C_STROKE_HI
	elif not locked:
		sb.highlight = WoodcutTheme.C_RAISED_HI
	var down := sb.variant(WoodcutTheme.C_RAISED_HI, WoodcutTheme.C_BRONZE_LO if not chosen else WoodcutTheme.C_BRONZE)
	down.border_px = sb.border_px
	for st in ["normal", "hover", "focus", "disabled"]:
		add_theme_stylebox_override(st, sb)
	for st in ["pressed", "hover_pressed"]:
		add_theme_stylebox_override(st, down)
	pic.tint = light * Color(0.6, 0.55, 0.52) if locked else light
	caption.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI if chosen else (WoodcutTheme.C_BRONZE if locked else WoodcutTheme.C_TEXT))
	_badge.queue_redraw()


## The corner badge: a check on the chosen tile, a lock on a locked one.
func _draw_badge() -> void:
	if chosen:
		var r := Rect2(Vector2(size.x - 48.0, 0.0), Vector2(48.0, 42.0))
		var sb := PxStyle.make(WoodcutTheme.C_BRONZE, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_M, Vector4.ZERO)
		_badge.draw_style_box(sb, r)
		var ck := KitIcons.get_icon("check")
		_badge.draw_texture(ck, (r.get_center() - ck.get_size() * 0.5).floor(), WoodcutTheme.C_INK)
	elif locked:
		# a small lock in the corner: the carving itself stays readable, only dimmed
		var r := Rect2(Vector2(size.x - 48.0, 0.0), Vector2(48.0, 42.0))
		_badge.draw_style_box(PxStyle.make(WoodcutTheme.C_INK, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_M, Vector4.ZERO), r)
		var lk := KitIcons.get_icon("lock")
		_badge.draw_texture(lk, (r.get_center() - lk.get_size() * 0.5).floor(), WoodcutTheme.C_BRONZE)
