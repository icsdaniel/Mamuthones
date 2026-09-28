class_name Hud
extends Control
## The strip at the top of the play screen: score, unison (level, multiplier and the streak toward the
## next level), progress through the song's sections, the ghost (ahead or behind your best) and
## health (HealthPips).
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
var _health: HealthPips


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_session: Session, p_ghost: Ghost) -> void:
	session = p_session
	ghost = p_ghost
	# Everything sits in the top ~110 px, the centre left open for the fire: the score top-left in the
	# carved serif with the ghost under it; unison, its bells, the pause button and the section tag
	# top-right; the song's progress a thin line along the screen's very top edge.
	_score = UIKit.label("0", "BigNumberLabel", false)
	_score.name = "Score"
	FireSkin.carve_label(_score, 50, Color.WHITE, Color(1.0, 0.84, 0.55, 0.5), 8, 0.45)
	_gradient(_score, FireSkin.text_gradient(Color("#fff6e2"), Color("#f0dcb2"), Color("#d4a45a")))
	_score.position = Vector2(-4.0, -8.0)
	add_child(_score)
	_ghost = UIKit.label("", UIKit.HUD, false)
	_ghost.name = "Ghost"
	FireSkin.carve_label(_ghost, 24, Color("#d9a24a"), Color(0, 0, 0, 0), 6)
	_ghost.position = Vector2(-2.0, 50.0)
	add_child(_ghost)
	# Health: ten flames under the ghost line (hidden where health is off: Piazza, lessons, autoplay).
	_health = HealthPips.new()
	_health.name = "Health"
	_health.session = session
	_health.reduced_motion = UIKit.reduced_motion()
	_health.position = Vector2(0.0, 82.0)
	_health.size = _health.custom_minimum_size
	_health.visible = session.health_on
	add_child(_health)
	_unison = UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_unison.name = "Unison"
	FireSkin.carve_label(_unison, 32, Color.WHITE, Color(0, 0, 0, 0), 6, 0.3)
	_gradient(_unison, FireSkin.text_gradient(Color("#fff6e0"), Color("#efe2c6"), Color("#e0a040")))
	add_child(_unison)
	_meter = UnisonMeter.new()
	_meter.name = "Meter"
	add_child(_meter)
	_pause = UIKit.button("", func() -> void: pause_pressed.emit(), UIKit.QUIET)
	_pause.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
	_pause.size = _pause.custom_minimum_size
	_pause.name = "Pause"
	_pause.tooltip_text = tr("play_pause")
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		_pause.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_pause.draw.connect(_draw_pause)
	add_child(_pause)
	# The section: gold small caps after a hairline and a diamond, right under the pause button.
	var tag := Control.new()
	tag.name = "SectionTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.draw.connect(_draw_tag.bind(tag))
	add_child(tag)
	_section = UIKit.label("", UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_section.name = "Section"
	FireSkin.carve_label(_section, 24, Color("#e8c070"), Color(0, 0, 0, 0), 5)
	_section.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_section.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.add_child(_section)
	_ribbon = tag
	# The progress line runs across the whole screen at its top edge, outside the HUD's margins.
	_bar = SectionBar.new()
	_bar.name = "Progress"
	_bar.top_level = true
	_bar.setup(session)
	add_child(_bar)
	resized.connect(_layout)
	_layout()
	set_unison(session.unison_level, false)


func _layout() -> void:
	var w := size.x
	_unison.position = Vector2(w - 330.0, 6.0)
	_unison.size = Vector2(262.0, 40.0)
	_meter.position = Vector2(w - 236.0, 44.0)
	_meter.size = Vector2(172.0, 34.0)
	# The disc sits 24 px in from the HUD's right edge; its touch target runs off to the screen edge.
	_pause.position = Vector2(w - 80.0, -8.0)
	_ribbon.position = Vector2(w - 330.0, 80.0)
	_ribbon.size = Vector2(330.0, 32.0)
	_place_bar()


func _place_bar() -> void:
	if _bar == null or not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var top := maxf(global_position.y - 8.0, 0.0)
	_bar.global_position = Vector2(0.0, top)
	_bar.size = Vector2(vp.x, 12.0)


## Gives a label a gradient fill that follows its height.
static func _gradient(l: Label, m: ShaderMaterial) -> void:
	l.material = m
	l.resized.connect(func() -> void: m.set_shader_parameter("height", maxf(l.size.y, 1.0)))


## The round pause button: a dark disc with a bronze rim and two bars, near the top-right corner.
func _draw_pause() -> void:
	var c := Vector2(56.0, 40.0)
	var r := 21.0
	var down := _pause.button_pressed or _pause.is_hovered()
	_pause.draw_circle(c, r, Color(0.12, 0.06, 0.16, 0.9))
	_pause.draw_arc(c, r, 0.0, TAU, 40, Color("#ffc84a") if down else Color("#c8862e"), 2.0, true)
	for dx in [-5.5, 5.5]:
		_pause.draw_rect(Rect2(c.x + dx - 3.0, c.y - 10.0, 6.0, 20.0), Color("#fff3dc"))


## A gold hairline and a diamond before the section's name.
func _draw_tag(tag: Control) -> void:
	if _section.text == "":
		return
	var font := _section.get_theme_font("font")
	var fs := _section.get_theme_font_size("font_size")
	var tw := font.get_string_size(_section.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := tag.size.y * 0.5 + 1.0
	var x := tag.size.x - tw - 12.0
	var col := Color(0.91, 0.75, 0.44, 0.75)
	tag.draw_rect(Rect2(x - 44.0, y, 34.0, 1.0), col)
	tag.draw_set_transform(Vector2(x - 4.0, y + 0.5), PI * 0.25)
	tag.draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), Color("#e8c070"))
	tag.draw_set_transform(Vector2.ZERO)


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
	_place_bar()
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
