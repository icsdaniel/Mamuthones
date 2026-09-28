class_name Hud
extends Control
## The strip at the top of the play screen: score, unison (level, multiplier and the streak toward the
## next level), progress through the song's sections, and the ghost (ahead or behind your best).
## A pause button sits at the right. Text uses the theme's HUD styles so it reads over the scene.

signal pause_pressed

const HEIGHT := 176.0

var session: Session
var ghost: Ghost
var _score: Label
var _unison: Label
var _ghost: Label
var _section: Label
var _meter: UnisonMeter
var _bar: SectionBar
var _shown_score := 0.0
var _pause: Button
var _ribbon: Control


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_session: Session, p_ghost: Ghost) -> void:
	session = p_session
	ghost = p_ghost
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	# The score in a framed plate, the ghost line under it.
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := PanelContainer.new()
	plate.name = "ScorePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _plate_style())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top.add_child(plate)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(left)
	_score = UIKit.label("0", "BigNumberLabel", false)
	_score.name = "Score"
	FireSkin.style_label(_score, 64, Color.WHITE, 9)
	_score.custom_minimum_size.x = 250
	_gradient(_score, FireSkin.text_gradient())
	left.add_child(_score)
	_ghost = UIKit.label("", UIKit.HUD, false)
	_ghost.name = "Ghost"
	FireSkin.style_label(_ghost, 24, Color.WHITE, 5)
	left.add_child(_ghost)
	top.add_child(holder)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	_unison = UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_unison.name = "Unison"
	_unison.uppercase = true
	FireSkin.style_label(_unison, 28, Color.WHITE, 7)
	_gradient(_unison, FireSkin.text_gradient(Color.WHITE, Color("#fff3dc"), Color("#ffc86a")))
	mid.add_child(_unison)
	_meter = UnisonMeter.new()
	_meter.custom_minimum_size = Vector2(204, 38)
	mid.add_child(_meter)
	_pause = UIKit.button("", func() -> void: pause_pressed.emit(), UIKit.QUIET)
	_pause.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
	_pause.name = "Pause"
	_pause.tooltip_text = tr("play_pause")
	_pause.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		_pause.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_pause.draw.connect(_draw_pause)
	top.add_child(_pause)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 14)
	col.add_child(bottom)
	_bar = SectionBar.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 30
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.setup(session)
	bottom.add_child(_bar)
	_section = UIKit.label("", UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_section.name = "Section"
	_section.uppercase = true
	_section.custom_minimum_size = Vector2(150, 34)
	_section.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_section.add_theme_font_override("font", Palette.text_font("ExtraBold"))
	_section.add_theme_font_size_override("font_size", 24)
	_section.add_theme_color_override("font_color", Color("#fff3dc"))
	var ribbon := Control.new()
	ribbon.name = "Ribbon"
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.custom_minimum_size = _section.custom_minimum_size
	ribbon.draw.connect(_draw_ribbon.bind(ribbon))
	bottom.add_child(ribbon)
	_section.set_anchors_preset(Control.PRESET_FULL_RECT)
	_section.offset_right = -6.0
	ribbon.add_child(_section)
	_ribbon = ribbon
	set_unison(session.unison_level, false)


## Gives a label a gradient fill that follows its height.
static func _gradient(l: Label, m: ShaderMaterial) -> void:
	l.material = m
	l.resized.connect(func() -> void: m.set_shader_parameter("height", maxf(l.size.y, 1.0)))


static func _plate_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.04, 0.12, 0.82)
	sb.border_color = Color("#c8862e")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	return sb


## The round pause button: a dark disc with a bronze rim and two bars.
func _draw_pause() -> void:
	var c := _pause.size * 0.5
	var r := minf(minf(c.x, c.y) - 6.0, 27.0)
	var down := _pause.button_pressed or _pause.is_hovered()
	_pause.draw_circle(c, r, Color(0.12, 0.06, 0.16, 0.92))
	_pause.draw_arc(c, r, 0.0, TAU, 40, Color("#ffc84a") if down else Color("#c8862e"), 3.0, true)
	var h := r * 0.9
	for dx in [-r * 0.28, r * 0.28]:
		_pause.draw_rect(Rect2(c.x + dx - r * 0.13, c.y - h * 0.5, r * 0.26, h), Color("#fff3dc"))


## The section's name on a red ribbon running off the right edge.
func _draw_ribbon(rb: Control) -> void:
	if _section.text == "":
		return
	var font := _section.get_theme_font("font")
	var fs := _section.get_theme_font_size("font_size")
	var tw := font.get_string_size(_section.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	var w := rb.size.x + 16.0
	var h := minf(rb.size.y, 34.0)
	var y := (rb.size.y - h) * 0.5
	var x0 := w - tw
	var pts := PackedVector2Array([Vector2(x0, y), Vector2(w, y), Vector2(w, y + h), Vector2(x0, y + h), Vector2(x0 - 9.0, y + h * 0.5)])
	rb.draw_colored_polygon(pts, Color("#c8181e"))
	rb.draw_line(Vector2(x0, y + 1.5), Vector2(w, y + 1.5), Color(1.0, 0.5, 0.45, 0.6), 2.0)


func set_pause_visible(v: bool) -> void:
	if _pause != null:
		_pause.visible = v


## Called once per frame by the play screen.
func tick(t: float, delta: float) -> void:
	if session == null:
		return
	# The number counts up quickly rather than jumping, so big hits read as big.
	_shown_score = move_toward(_shown_score, session.score, maxf(40.0, absf(session.score - _shown_score) * 12.0) * delta)
	_score.text = UIKit.fmt_score(roundi(_shown_score))
	_meter.fill = float(session.unison_streak) / float(Session.UNISON_STEP) if session.unison_level < 5 else 1.0
	_bar.progress = session.progress(t)
	var sec := _bar.section_name(t)
	if sec != _section.text:
		_section.text = sec
		_ribbon.queue_redraw()
	if ghost != null and not ghost.is_empty() and judged_any(session):
		# Points, not seconds: how far above or below your best run you are at this moment.
		var d := ghost.delta_at(t, session.score)
		_ghost.text = ghost_text(d)
		_ghost.modulate = Color("#ff9a3a") if d > 0 else Palette.BONE_DIM
	elif ghost != null and not ghost.is_empty():
		_ghost.text = ""
	else:
		_ghost.text = tr("hud_unison_hint") if session.unison_level == 0 else ""
		_ghost.modulate = Color("#ff9a3a")


func set_unison(level: int, animate := true) -> void:
	_unison.text = tr("hud_unison") % _mult_text(Session.UNISON_MULTS[level])
	_meter.level = level
	if animate and not UIKit.reduced_motion():
		_unison.pivot_offset = _unison.size * Vector2(1.0, 0.5)
		var tw := _unison.create_tween()
		_unison.scale = Vector2(1.35, 1.35)
		tw.tween_property(_unison, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _mult_text(m: float) -> String:
	return ("×%d" % int(m)) if is_equal_approx(m, roundf(m)) else ("×%.1f" % m)


## Whether any note has been judged yet (the ghost line waits for it).
static func judged_any(s: Session) -> bool:
	return int(s.stats.get("notes", 0)) + int(s.stats.get("miss", 0)) + int(s.stats.get("wrong", 0)) > 0


## "+1,250 on your best", "−800 on your best" or "Level with your best".
static func ghost_text(delta: int) -> String:
	if delta == 0:
		return UIKit.tr_("hud_ghost_even")
	if delta > 0:
		return UIKit.tr_("hud_ghost_up") % UIKit.fmt_score(delta)
	return UIKit.tr_("hud_ghost_down") % UIKit.fmt_score(-delta)
