class_name LookStage
extends Control
## The workshop's stage (a menu-kit piece, added with the workshop): your own pixel Mamuthone, the
## play screen's figure (PixelFigure wearing FigureLook), standing large on a stone plinth in the
## bonfire's light, bobbing down on a slow beat as it waits, embers drifting up. It can turn to a
## close-up of the carved mask (MaskPixels, as large as fits) and back: by a tap on the stage or its
## labelled toggle (a pill with an icon and a word, top right). The change zooms in whole-pixel
## steps (instant with reduced motion).
##   set_look(look, part)  the look to wear (Profile.get_look()), and the mask part to ring in the
##                         close-up ("" for none)
##   jingle()              a choice was made: the load rings and the figure dips with it
##   closeup               true: the mask close-up (set_closeup(on, animate) to choose the motion)
##   toggle_texts          [word for "show the mask", word for "show the figure"]
## A tap is one mouse-button release (a phone's touch arrives as one, emulated) close to where it
## was pressed: a drag that moved more than TAP_SLOP is no tap.
## The light and the plinth are drawn once per size into one small picture (whole art px, Bayer
## dithered); per frame only the figure's pieces and a few embers move.

signal tapped

const TAP_SLOP := 24.0
const ZOOM_TIME := 0.2
const EMBERS := 9

const BPM := 72.0
const ART_H := 172.0
const PLINTH_H := 16          ## art px under the feet: the plinth's top and its front
const FIGURE_SHIFT := 13.0    ## art px the picture's canvas is off the figure's middle (it faces left)
## The firelight's steps, outside in (WALL_RAMP of the play screen's portraits).
const GLOW := ["#140b0e", "#1e1116", "#2c1715", "#401f15", "#5a2a15", "#783a16"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var closeup := false:
	get:
		return _closeup
	set(v):
		set_closeup(v, false)
var _closeup := false
var reduced_motion := false
var toggle_texts := ["Mask", "Figure"]:
	set(v):
		toggle_texts = v
		_label_toggle()
var toggle: Button
var _press_at := Vector2.INF
var _zoom_t := 1.0            ## 0 .. 1 through the zoom of a mode change

var figure: PixelFigure
var _look := {}
var _part := ""
var _clock := 0.0
var _ring_at := -9.0
var _px := 3.0
var _bg: ImageTexture
var _bg_key := ""
var _mask_pic: PixelPic


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	figure = PixelFigure.new("mamuthone")
	figure.name = "Figure"
	figure.mirror = true
	add_child(figure)
	_mask_pic = PixelPic.new()
	_mask_pic.name = "MaskCloseup"
	_mask_pic.visible = false
	_mask_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mask_pic)
	toggle = Button.new()
	toggle.name = "ViewToggle"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
	toggle.add_theme_font_size_override("font_size", 28)
	var sb := PxStyle.make(Color(WoodcutTheme.C_INK, 0.82), WoodcutTheme.C_BRONZE_DEEP, WoodcutTheme.R_PILL, Vector4(24, 6, 30, 6))
	sb.highlight = WoodcutTheme.C_RAISED_HI
	var down := sb.variant(WoodcutTheme.C_RAISED_HI, WoodcutTheme.C_BRONZE)
	for st in ["normal", "hover", "focus", "disabled"]:
		toggle.add_theme_stylebox_override(st, sb)
	for st in ["pressed", "hover_pressed"]:
		toggle.add_theme_stylebox_override(st, down)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(c, WoodcutTheme.C_BRONZE_HI)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		toggle.add_theme_color_override(c, WoodcutTheme.C_BRONZE)
	toggle.add_theme_constant_override("h_separation", 12)
	toggle.pressed.connect(func() -> void:
		Sound.ui("tap")
		set_closeup(not closeup, true)
		tapped.emit())
	add_child(toggle)
	UIKit.juice(toggle)
	_label_toggle()


func _ready() -> void:
	reduced_motion = UIKit.reduced_motion()
	figure.reduced_motion = reduced_motion
	if not _look.is_empty():
		figure.set_look(_look)
	_layout()


func set_look(look: Dictionary, part := "") -> void:
	_look = FigureLook.normalize(look)
	_part = part
	figure.set_look(_look)
	_mask_pic.texture = MaskPixels.texture(_look.mask, 22.0, true, _look.straps, _part)


func jingle() -> void:
	_ring_at = _clock
	if is_inside_tree():
		Sound.bell(BellSets.STANDARD, true, "perfect", 0.35)


## The scale the figure is drawn at: whole screen px per art px, as large as the stage allows.
func art_px() -> float:
	return _px


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if size.y <= 0.0:
		return
	_px = clampf(floorf(size.y / (ART_H + PLINTH_H + 10.0)), 2.0, 6.0)
	figure.scale = Vector2(_px, _px)
	var feet := _feet()
	figure.position = Vector2(feet.x + FIGURE_SHIFT * _px, feet.y)
	# the close-up: the mask hung over the plinth, with room round it
	_mask_pic.step = 1
	_mask_pic.max_scale = maxi(int(floor(size.y * 0.72 / 85.0)), 2)
	_mask_pic.offset_top = 0.0
	_mask_pic.offset_bottom = -(PLINTH_H + 6) * _px
	_full_scale = _mask_pic.max_scale
	toggle.reset_size()
	toggle.position = Vector2(floorf(size.x - toggle.size.x), 0.0)
	_bake_bg()
	_apply_mode()
	queue_redraw()


var _full_scale := 4


## Turns to the mask close-up (on) or the whole figure, zooming in whole-pixel steps if `animate`.
func set_closeup(on: bool, animate := true) -> void:
	var changed := on != _closeup
	_closeup = on
	if changed and animate and not reduced_motion and is_inside_tree():
		_zoom_t = 0.0
	else:
		_zoom_t = 1.0
	_label_toggle()
	_apply_mode()


func _label_toggle() -> void:
	if toggle == null:
		return
	toggle.text = str(toggle_texts[1] if closeup else toggle_texts[0])
	toggle.icon = KitIcons.get_icon("figure" if closeup else "zoom")
	if is_inside_tree():
		toggle.reset_size()
		toggle.position = Vector2(floorf(size.x - toggle.size.x), 0.0)


## Where the feet stand: the plinth's top, in the middle.
## On a tall stage the figure is raised a little, so the room is shared above and below it.
func _feet() -> Vector2:
	var spare := maxf(size.y - (ART_H + PLINTH_H + 10.0) * _px, 0.0)
	return Vector2(floorf(size.x * 0.5 / _px) * _px, floorf((size.y - (PLINTH_H - 3) * _px - spare * 0.4) / _px) * _px)


## Shows the mode, part way through its zoom: the mask grows from a small whole scale to its full
## one, step by step; the figure rises onto the plinth in whole art px.
func _apply_mode() -> void:
	var k := clampf(_zoom_t, 0.0, 1.0)
	figure.visible = not closeup
	_mask_pic.visible = closeup
	if closeup:
		_mask_pic.max_scale = clampi(1 + int(floor(k * float(_full_scale))), 1, _full_scale)
		_mask_pic.queue_redraw()
	else:
		var feet := _feet()
		figure.position = Vector2(feet.x + FIGURE_SHIFT * _px, feet.y + roundf((1.0 - k) * 8.0) * _px)
		figure.modulate.a = 1.0 if k >= 1.0 else maxf(k, 0.25)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _zoom_t < 1.0:
		_zoom_t = minf(_zoom_t + delta / ZOOM_TIME, 1.0)
		_apply_mode()
	var spb := 60.0 / BPM
	figure.pose(fmod(_clock, spb), 0.0, false, _clock - _ring_at, true)
	if not reduced_motion:
		queue_redraw()   # the embers


## One tap toggles the view: a left-button release near its press (touch arrives as emulated mouse;
## ScreenTouch is not read, so one finger never counts twice).
func _gui_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	if mb.pressed:
		_press_at = mb.position
		return
	var was := _press_at
	_press_at = Vector2.INF
	if not was.is_finite() or was.distance_to(mb.position) > TAP_SLOP:
		return
	accept_event()
	Sound.ui("tap")
	set_closeup(not closeup, true)
	tapped.emit()


func _draw() -> void:
	if _bg != null:
		draw_texture_rect(_bg, Rect2(Vector2.ZERO, Vector2(_bg.get_size()) * _px), false)
	if reduced_motion:
		return
	# embers drifting up out of the light, in whole art px
	var feet := _feet()
	for i in EMBERS:
		var period := 3.2 + float(i % 4) * 0.7
		var t := fmod(_clock + float(i) * 1.37, period) / period
		var x := feet.x + (float((i * 37) % 23) - 11.0) * 4.0 * _px + sin(_clock * 1.3 + i) * 3.0 * _px
		var y := feet.y - (12.0 + t * ART_H * 1.05) * _px
		var c: Color = PixelPalette.FIRE[5 if i % 3 == 0 else 4]
		c.a = (1.0 - t) * 0.9
		draw_rect(Rect2((Vector2(x, y) / _px).floor() * _px, Vector2(_px, _px)), c)


## The bonfire's light behind the figure and the stone plinth it stands on, at one texel per art px.
func _bake_bg() -> void:
	var w := int(ceil(size.x / _px))
	var h := int(ceil(size.y / _px))
	var key := "%d_%d" % [w, h]
	if key == _bg_key or w <= 0 or h <= 0:
		return
	_bg_key = key
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var feet := _feet() / _px
	# the light fills the stage: centred on the figure's chest, reaching its top and sides
	var glow_c := Vector2(feet.x, feet.y - ART_H * 0.45)
	var rx := maxf(w * 0.5, ART_H * 0.55)
	var ry := maxf(glow_c.y + 6.0, ART_H * 0.62)
	var ramp: Array[Color] = []
	for c in GLOW:
		ramp.append(Color(c))
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5 - glow_c.x) / rx, (y + 0.5 - glow_c.y) / ry).length()
			var lvl := (1.0 - d) * 7.0
			var t: float = (BAYER[(y % 4) * 4 + x % 4] + 0.5) / 16.0
			var n := int(floor(lvl + t - 0.5))
			if n >= 1:
				img.set_pixel(x, y, ramp[mini(n - 1, ramp.size() - 1)])
	_plinth(img, feet)
	if _bg == null or Vector2i(_bg.get_size()) != img.get_size():
		_bg = ImageTexture.create_from_image(img)
	else:
		_bg.update(img)


## An oval slab of Mamoiada granite: the lit top (its joints a step darker, its near rim catching the
## fire), a dark front, a shadow under the figure.
func _plinth(img: Image, feet: Vector2) -> void:
	var st := PixelPalette.STONE
	var cx := feet.x
	var top := feet.y
	var rx := 50.0
	var ry := 7.0
	var front := 7
	var w := img.get_width()
	var h := img.get_height()
	for y in range(int(top - ry) - 1, mini(int(top + ry + front) + 2, h)):
		for x in range(maxi(int(cx - rx) - 1, 0), mini(int(cx + rx) + 2, w)):
			if y < 0:
				continue
			var u := (x + 0.5 - cx) / rx
			if absf(u) > 1.0:
				continue
			var half := ry * sqrt(1.0 - u * u)
			var yy := y + 0.5
			var t: float = (BAYER[(y % 4) * 4 + x % 4] + 0.5) / 16.0
			if yy >= top - half and yy <= top + half:
				# the top face: lit from behind the figure (the fire), toward the viewer a step down
				var v := (yy - (top - half)) / maxf(2.0 * half, 1.0)
				var lvl := 4.6 - v * 1.6 - absf(u) * 1.2
				var joint := (x + int(floor((yy - top + ry) / 5.0)) * 6) % 13 == 0 or int(yy - top + ry) % 5 == 0
				if joint:
					lvl -= 1.0
				# the figure's shadow
				var sd := Vector2((x + 0.5 - cx) / 26.0, (yy - top) / 4.5).length()
				if sd < 1.0:
					lvl = minf(lvl, 0.6 + sd * 1.5)
				if yy > top + half - 1.0:
					lvl = 5.5   # the near rim catches the fire
				img.set_pixel(x, y, st[clampi(int(floor(lvl + t - 0.5)), 0, st.size() - 1)])
			elif yy > top + half and yy <= top + half + front:
				var k := (yy - top - half) / front
				var lvl2 := 2.2 - k * 1.8 - absf(u) * 0.8
				if (x + (int((yy - top - half) / 4.0)) * 5) % 11 == 0:
					lvl2 -= 1.0
				img.set_pixel(x, y, st[clampi(int(floor(lvl2 + t - 0.5)), 0, st.size() - 1)])
			elif yy > top + half + front and yy <= top + half + front + 1.0:
				img.set_pixel(x, y, PixelPalette.K[0])
