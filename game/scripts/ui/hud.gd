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
	PxType.label(_score, "score")
	_score.position = Vector2(0.0, 0.0)
	add_child(_score)
	_ghost = UIKit.label("", UIKit.HUD, false)
	_ghost.name = "Ghost"
	PxType.label(_ghost, "caps")
	_ghost.position = Vector2(0.0, 42.0)
	add_child(_ghost)
	# Health: ten flames under the ghost line (hidden where health is off: Piazza, lessons, autoplay).
	_health = HealthPips.new()
	_health.name = "Health"
	_health.session = session
	_health.reduced_motion = UIKit.reduced_motion()
	_health.position = Vector2(0.0, 75.0)
	_health.size = _health.custom_minimum_size
	_health.visible = session.health_on
	add_child(_health)
	_unison = UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_unison.name = "Unison"
	PxType.label(_unison, "caps_gold")
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
	PxType.label(_section, "caps_gold")
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
	w = floorf(w / PxArt.PX) * PxArt.PX
	_unison.position = Vector2(w - 330.0, 6.0)
	_unison.size = Vector2(261.0, 36.0)
	_meter.position = Vector2(w - 249.0, 39.0)
	_meter.size = Vector2(183.0, 42.0)
	# The disc sits 24 px in from the HUD's right edge; its touch target runs off to the screen edge.
	_pause.position = Vector2(w - 80.0, -8.0)
	_ribbon.position = Vector2(w - 330.0, 84.0)
	_ribbon.size = Vector2(330.0, 33.0)
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


## The round pause button: a navy disc in a gold ring with two cream bars, near the top-right corner.
func _draw_pause() -> void:
	var down := _pause.button_pressed or _pause.is_hovered()
	FireSkin.sprite(_pause, "pause_down" if down else "pause", Vector2(57.0, 42.0))


## A gold rule and a diamond before the section's name.
func _draw_tag(tag: Control) -> void:
	if _section.text == "":
		return
	var tw := PxType.width("caps_gold", _section.text)
	var P := PxArt.PX
	var y := roundf(tag.size.y * 0.5 / P) * P
	var x := roundf((tag.size.x - tw - 12.0) / P) * P
	tag.draw_rect(Rect2(x - 15.0 * P, y, 11.0 * P, P), PixelPalette.GOLD[3])
	tag.draw_rect(Rect2(x - 15.0 * P, y + P, 11.0 * P, P), PixelPalette.K[0])
	FireSkin.sprite(tag, "diamond_bright", Vector2(x - 2.0 * P, y))


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
		_ghost.modulate = PixelPalette.FIRE[5] if d > 0 else PixelPalette.BONE[2]
	elif ghost != null and not ghost.is_empty():
		_ghost.text = ""
	else:
		_ghost.text = tr("hud_unison_hint") if session.unison_level == 0 else ""
		_ghost.modulate = PixelPalette.FIRE[5]


func set_unison(level: int, animate := true) -> void:
	_unison.text = tr("hud_unison") % _mult_text(Session.UNISON_MULTS[level])
	_meter.level = level
	if animate:
		# A level gained: the words hop a pixel and flash hot (the bells flare with them); whole pixels
		# only, no scaling.
		var tw := _unison.create_tween()
		_unison.modulate = Color(1.3, 1.25, 1.1)
		if not UIKit.reduced_motion():
			_unison.position.y = 6.0 - PxArt.PX
			tw.tween_property(_unison, "position:y", 6.0, 0.18).set_delay(0.08)
		tw.parallel().tween_property(_unison, "modulate", Color.WHITE, 0.3)
		_meter.flare()


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
