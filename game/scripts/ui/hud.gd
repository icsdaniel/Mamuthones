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


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_session: Session, p_ghost: Ghost) -> void:
	session = p_session
	ghost = p_ghost
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	_score = UIKit.label("0", "BigNumberLabel", false)
	_score.name = "Score"
	left.add_child(_score)
	_ghost = UIKit.label("", UIKit.HUD, false)
	_ghost.name = "Ghost"
	left.add_child(_ghost)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	_unison = UIKit.label("", UIKit.HUD, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_unison.name = "Unison"
	mid.add_child(_unison)
	_meter = UnisonMeter.new()
	_meter.custom_minimum_size = Vector2(190, 26)
	mid.add_child(_meter)
	_pause = UIKit.button("II", func() -> void: pause_pressed.emit(), UIKit.QUIET)
	_pause.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
	_pause.name = "Pause"
	_pause.tooltip_text = tr("play_pause")
	top.add_child(_pause)
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	_bar = SectionBar.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.custom_minimum_size.y = 26
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.setup(session)
	bottom.add_child(_bar)
	_section = UIKit.label("", UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_section.custom_minimum_size.x = 170
	bottom.add_child(_section)
	set_unison(session.unison_level, false)


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
	_section.text = _bar.section_name(t)
	if ghost != null and not ghost.is_empty() and judged_any(session):
		# Points, not seconds: how far above or below your best run you are at this moment.
		var d := ghost.delta_at(t, session.score)
		_ghost.text = ghost_text(d)
		_ghost.modulate = Palette.EMBER if d > 0 else Palette.BONE_DIM
	elif ghost != null and not ghost.is_empty():
		_ghost.text = ""
	else:
		_ghost.text = tr("hud_unison_hint") if session.unison_level == 0 else ""


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
