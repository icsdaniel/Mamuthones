class_name Swatch
extends Button
## A picture choice of the menu kit (added with the workshop): a tile showing the option drawn in
## pixel art (PixelPic) over a one-line caption. States:
##   chosen   a bronze rim, the face lit, a check in a bronze corner badge, the caption bronze
##   open     a dark sheepskin tile, the caption cream
##   locked   the picture sunk in shadow with a lock on it; the caption says what opens it (bronze)
## Tapping a locked swatch still emits `pressed` (the screen says what it needs); it never toggles.
##   Swatch.make(id, picture, caption, chosen, locked, on_press, region := Rect2()) -> Swatch

const PIC_PAD := 12.0

var id := ""
var chosen := false
var locked := false
var pic: PixelPic
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
	pic.tint = Color(0.32, 0.28, 0.3) if locked else Color.WHITE
	caption.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI if chosen else (WoodcutTheme.C_BRONZE if locked else WoodcutTheme.C_TEXT))
	_badge.queue_redraw()


## The corner check of the chosen tile, or the lock over a locked picture.
func _draw_badge() -> void:
	if chosen:
		var r := Rect2(Vector2(size.x - 48.0, 0.0), Vector2(48.0, 42.0))
		var sb := PxStyle.make(WoodcutTheme.C_BRONZE, WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_M, Vector4.ZERO)
		_badge.draw_style_box(sb, r)
		var ck := KitIcons.get_icon("check")
		_badge.draw_texture(ck, (r.get_center() - ck.get_size() * 0.5).floor(), WoodcutTheme.C_INK)
	elif locked:
		var lk := KitIcons.get_icon("lock")
		var c: Vector2 = pic.position + (pic.get_parent() as Control).position + pic.size * 0.5
		var plate := Rect2((c - Vector2(36, 36)).floor(), Vector2(72, 72))
		_badge.draw_style_box(PxStyle.make(Color(WoodcutTheme.C_INK, 0.85), WoodcutTheme.C_BRONZE_DEEP, -1, Vector4.ZERO), plate)
		_badge.draw_texture(lk, (c - lk.get_size() * 0.5).floor(), WoodcutTheme.C_BRONZE)
