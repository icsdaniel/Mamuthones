class_name Hud
extends Control
## The top of the play screen, after Daniele's play-screen picture (mockups/lowpoly/
## play_screen_hud_target.png): a thin progress line across the top between two diamonds, then three
## carved frames with glowing orange edges - health as hearts on the left, the unison multiplier in
## a big hexagonal badge in the middle (its lower rim fills with the streak toward the next level),
## the score on the right. Under the score, the ghost (ahead or behind your best); under the hearts,
## the song's section. A small pause button sits at the top right.
## Node names (Score, Ghost, Health, Unison, Pause, Progress) are what the tests look for.

signal pause_pressed

const HEIGHT := 176.0
const EDGE := Color("#ff9a32")
const EDGE_HOT := Color("#ffd27a")
const EDGE_DARK := Color("#7a2e06")
const SIDE := Color("#5a2408")      ## the frames' sides, below their faces
const LIGHT := Vector2(-0.45, -0.89)  ## where the HUD's light comes from (top left)
const DEPTH := 7.0                  ## how far the frames stand out of the screen, px
const BEVEL := 7.0                  ## the width of their bevelled rim, px
const PANEL := Color(0.07, 0.04, 0.05, 0.9)
const INK := Color("#fff1d6")
const GOLD_INK := Color("#ffd35a")
const SCORE_INK := Color("#ffe6a0")
const OUTLINE := Color("#0a0608")
const PANEL_Y := 34.0            ## the frames' top
const PANEL_H := 64.0
const BADGE := Vector2(122.0, 112.0)

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
var _health: HealthPips
var _frames: Control
var _flare_at := -9.0
var _clock := 0.0
var _progress := 0.0
var _streak := 0.0
var _laid := Vector2(-1, -1)
var _punch := 0.0
var _punched := 0


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func font(bold := true) -> Font:
	return load("res://fonts/AlegreyaSans-ExtraBold.ttf" if bold else "res://fonts/AlegreyaSC-Bold.ttf")


static func style(l: Label, size: int, color: Color, bold := true, outline := 6) -> void:
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	# the letters stand out in relief: a bronze side below each one
	l.add_theme_constant_override("shadow_outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color("#9a4410"))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 12))
	l.material = null


func setup(p_session: Session, p_ghost: Ghost) -> void:
	session = p_session
	ghost = p_ghost
	_frames = Control.new()
	_frames.name = "Frames"
	_frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frames.draw.connect(_draw_frames)
	add_child(_frames)
	_score = Label.new()
	_score.name = "Score"
	_score.text = "0"
	style(_score, 42, SCORE_INK)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score)
	_ghost = Label.new()
	_ghost.name = "Ghost"
	style(_ghost, 24, INK, false, 5)
	_ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	# Health: five hearts, two points each (hidden where health is off: Piazza, lessons, autoplay).
	_health = HealthPips.new()
	_health.name = "Health"
	_health.session = session
	_health.reduced_motion = UIKit.reduced_motion()
	_health.size = _health.custom_minimum_size
	_health.visible = session.health_on
	add_child(_health)
	_unison = Label.new()
	_unison.name = "Unison"
	style(_unison, 60, GOLD_INK, true, 8)
	_unison.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unison.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unison.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_unison)
	_meter = UnisonMeter.new()
	_meter.name = "Meter"
	_meter.visible = false
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
	_section = Label.new()
	_section.name = "Section"
	style(_section, 24, GOLD_INK, false, 5)
	_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_section)
	# The song's progress: kept for its sections; the line itself is drawn with the frames.
	_bar = SectionBar.new()
	_bar.name = "Progress"
	_bar.visible = false
	_bar.setup(session)
	add_child(_bar)
	resized.connect(_layout)
	_layout()
	set_unison(session.unison_level, false)


## The screen's width and this HUD's left edge on it (the HUD sits inside margins).
func _screen() -> Vector2:
	if not is_inside_tree():
		return Vector2(size.x, 0.0)
	var vr := get_viewport_rect().size.x
	return Vector2(vr, get_global_transform().affine_inverse().origin.x)


## [hearts panel, badge, score panel, progress line (x0, x1, y)] in this HUD's coordinates.
func _boxes() -> Array:
	var sc := _screen()
	var W := sc.x
	var x0 := sc.y
	var cx := x0 + W * 0.5
	var pad := W * 0.035
	var half := BADGE.x * 0.5
	var left := Rect2(x0 + pad + 30.0, PANEL_Y, cx - half - 14.0 - (x0 + pad + 30.0), PANEL_H)
	var right_end := x0 + W - pad - 30.0
	var right := Rect2(cx + half + 14.0, PANEL_Y, right_end - (cx + half + 14.0), PANEL_H)
	var badge := Rect2(cx - half, PANEL_Y + PANEL_H * 0.5 - BADGE.y * 0.5 + 6.0, BADGE.x, BADGE.y)
	return [left, badge, right, Vector3(x0 + pad, x0 + W - pad - 56.0, 12.0)]


func _layout() -> void:
	if _score == null:
		return
	var b := _boxes()
	var left: Rect2 = b[0]
	var badge: Rect2 = b[1]
	var right: Rect2 = b[2]
	var line: Vector3 = b[3]
	_score.position = right.position + Vector2(18.0, 0.0)
	_score.size = right.size - Vector2(36.0, 0.0)
	_ghost.position = Vector2(right.position.x, right.end.y + 8.0)
	_ghost.size = Vector2(right.size.x - 10.0, 30.0)
	_health.position = left.get_center() - _health.size * 0.5
	_section.position = Vector2(left.position.x + 12.0, left.end.y + 8.0)
	_section.size = Vector2(left.size.x, 30.0)
	_unison.position = badge.position
	_unison.size = badge.size
	_pause.position = Vector2(line.y + 34.0, line.z + 16.0) - _pause.size * 0.5
	_frames.position = Vector2.ZERO
	_frames.size = size
	_frames.queue_redraw()
	_laid = _screen()


func _process(delta: float) -> void:
	_clock += delta
	# The margins place this HUD after it is built, so lay out again once its place on screen is known.
	if _score != null and _screen() != _laid:
		_layout()
	if _frames != null:
		_frames.queue_redraw()


func _to_frames(p: Vector2) -> Vector2:
	return p


## A carved frame: a dark panel with pointed ends, an orange edge glowing outward, a thin inner line,
## and a small diamond at each point.
func _panel(ci: CanvasItem, r: Rect2, glow := 1.0) -> void:
	var t := r.size.y * 0.5
	var pts := PackedVector2Array([r.position + Vector2(t * 0.6, 0), Vector2(r.end.x - t * 0.6, r.position.y), Vector2(r.end.x, r.get_center().y),
		r.end - Vector2(t * 0.6, 0), Vector2(r.position.x + t * 0.6, r.end.y), Vector2(r.position.x, r.get_center().y)])
	_shape(ci, pts, glow)
	for p in [pts[5], pts[2]]:
		_diamond(ci, p, 9.0)


## A frame in relief: a thick slab standing out of the screen (its lower sides show below it), a
## bevelled orange rim lit from the top left (the light faces bright, the shaded ones deep bronze) and
## a dark panel sunk inside it, with the glow round the outside.
func _shape(ci: CanvasItem, pts: PackedVector2Array, glow: float) -> void:
	var g := PackedVector2Array()
	for p in pts:
		g.append(_to_frames(p))
	var closed := g.duplicate()
	closed.append(g[0])
	for k in 3:
		ci.draw_polyline(closed, Color(1.0, 0.5, 0.1, 0.12 * glow), 18.0 - k * 5.0, true)
	var n := g.size()
	# the slab's sides, below it
	var down := Vector2(0.0, DEPTH)
	var hull := Geometry2D.convex_hull(PackedVector2Array(Array(g) + Array(_moved(g, down))))
	ci.draw_polyline(hull, OUTLINE, 5.0, true)
	ci.draw_colored_polygon(hull, OUTLINE)
	for i in n:
		var p0 := g[i]
		var p1 := g[(i + 1) % n]
		var nn := _normal(p0, p1)
		if nn.y > 0.05:
			_quad(ci, [p0, p1, p1 + down, p0 + down], SIDE.lerp(SIDE.darkened(0.5), clampf(0.5 + nn.x * 0.5, 0.0, 1.0)))
	# the bevelled rim
	var inner := _inset(g, BEVEL)
	for i in n:
		var p0 := g[i]
		var p1 := g[(i + 1) % n]
		var lit := _normal(p0, p1).dot(LIGHT)
		var col := EDGE.lerp(EDGE_HOT, clampf(lit, 0.0, 1.0)) if lit >= 0.0 else EDGE.lerp(EDGE_DARK, clampf(-lit, 0.0, 1.0))
		_quad(ci, [p0, p1, inner[(i + 1) % n], inner[i]], col)
	# the sunk panel: darker at its top, where the rim shades it
	ci.draw_colored_polygon(inner, PANEL)
	var top_y := INF
	var bot_y := -INF
	for p in inner:
		top_y = minf(top_y, p.y)
		bot_y = maxf(bot_y, p.y)
	var shade := PackedVector2Array()
	for p in inner:
		shade.append(Vector2(p.x, minf(p.y, top_y + (bot_y - top_y) * 0.35)))
	var sh := Geometry2D.convex_hull(shade)
	if sh.size() >= 4:
		ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35))
	var ring := inner.duplicate()
	ring.append(inner[0])
	ci.draw_polyline(ring, OUTLINE, 2.0, true)
	ci.draw_polyline(closed, Color(EDGE_HOT, 0.9), 1.5, true)


static func _moved(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


## The outward normal of the edge p0 -> p1 of a polygon wound clockwise on screen.
static func _normal(p0: Vector2, p1: Vector2) -> Vector2:
	var e := (p1 - p0).normalized()
	return Vector2(e.y, -e.x)


## A convex polygon moved in by d along each edge (corners mitred).
static func _inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	for i in n:
		var a := _normal(pts[(i - 1 + n) % n], pts[i])
		var b := _normal(pts[i], pts[(i + 1) % n])
		var m := (a + b).normalized()
		out.append(pts[i] - m * d / maxf(m.dot(b), 0.3))
	return out


static func _quad(ci: CanvasItem, q: Array, col: Color) -> void:
	var pts := PackedVector2Array(q)
	ci.draw_primitive(PackedVector2Array([pts[0], pts[1], pts[2]]), PackedColorArray([col, col, col]), PackedVector2Array())
	ci.draw_primitive(PackedVector2Array([pts[0], pts[2], pts[3]]), PackedColorArray([col, col, col]), PackedVector2Array())


## A cut diamond stud: four facets lit from the top left, on a dark base that shows below it.
func _diamond(ci: CanvasItem, at: Vector2, r: float, col := EDGE_HOT) -> void:
	var p := _to_frames(at)
	var t := p + Vector2(0, -r)
	var rt := p + Vector2(r, 0)
	var bt := p + Vector2(0, r)
	var lf := p + Vector2(-r, 0)
	var d := Vector2(0, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([t + Vector2(0, -2), rt + Vector2(2, 0), rt + d + Vector2(2, 0), bt + d + Vector2(0, 2), lf + d + Vector2(-2, 0), lf + Vector2(-2, 0)]), OUTLINE)
	_quad(ci, [lf, bt, bt + d, lf + d], SIDE)
	_quad(ci, [bt, rt, rt + d, bt + d], SIDE.darkened(0.4))
	var c := p + Vector2(-r * 0.12, -r * 0.12)
	ci.draw_colored_polygon(PackedVector2Array([t, c, lf]), col.lightened(0.35))
	ci.draw_colored_polygon(PackedVector2Array([t, rt, c]), col)
	ci.draw_colored_polygon(PackedVector2Array([lf, c, bt]), EDGE)
	ci.draw_colored_polygon(PackedVector2Array([c, rt, bt]), EDGE_DARK)


func _draw_frames() -> void:
	if session == null:
		return
	var ci := _frames
	var b := _boxes()
	var line: Vector3 = b[3]
	# the progress line between two diamonds
	var a := _to_frames(Vector2(line.x + 14.0, line.z))
	var e := _to_frames(Vector2(line.y - 14.0, line.z))
	# a groove for the progress, lit along its lower lip; the filled part a round glowing rod in it
	ci.draw_line(a, e, OUTLINE, 11.0)
	ci.draw_line(a, e, Color(0.1, 0.05, 0.04, 0.95), 8.0)
	ci.draw_line(a + Vector2(0, 3.5), e + Vector2(0, 3.5), Color(EDGE_DARK, 0.9), 1.5)
	var fx := a.lerp(e, clampf(_progress, 0.0, 1.0))
	if fx.x > a.x + 1.0:
		ci.draw_line(a, fx, Color(1.0, 0.5, 0.1, 0.25), 14.0)
		ci.draw_line(a, fx, EDGE_DARK, 7.0)
		ci.draw_line(a + Vector2(0, -0.5), fx + Vector2(0, -0.5), EDGE, 5.0)
		ci.draw_line(a + Vector2(0, -1.5), fx + Vector2(0, -1.5), EDGE_HOT, 2.0)
	for p in [Vector2(line.x + 8.0, line.z), Vector2(line.y - 8.0, line.z)]:
		_diamond(ci, p, 8.0)
	if session.health_on:
		_panel(ci, b[0])
	_panel(ci, b[2])
	# the badge: a tall hexagon, flaring when a level is gained; its lower rim fills with the streak
	var r: Rect2 = b[1]
	var fl := clampf(1.0 - (_clock - _flare_at) / 0.4, 0.0, 1.0)
	var hx := PackedVector2Array([Vector2(r.get_center().x, r.position.y), Vector2(r.end.x, r.position.y + r.size.y * 0.26),
		Vector2(r.end.x, r.end.y - r.size.y * 0.26), Vector2(r.get_center().x, r.end.y), Vector2(r.position.x, r.end.y - r.size.y * 0.26),
		Vector2(r.position.x, r.position.y + r.size.y * 0.26)])
	_shape(ci, hx, 1.0 + 2.0 * fl)
	if _streak > 0.0:
		var p0 := _to_frames(hx[4])
		var p1 := _to_frames(hx[3])
		var p2 := _to_frames(hx[2])
		var k := clampf(_streak, 0.0, 1.0) * 2.0
		var q := p0.lerp(p1, minf(k, 1.0))
		ci.draw_line(p0, q, EDGE_HOT, 5.0)
		if k > 1.0:
			ci.draw_line(p1, p1.lerp(p2, k - 1.0), EDGE_HOT, 5.0)
	for p in [Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y)]:
		_diamond(ci, p, 8.0, Color.WHITE.lerp(EDGE_HOT, 1.0 - fl))
	for sx: float in [-1.0, 1.0]:
		var c := _to_frames(Vector2(r.get_center().x + sx * (r.size.x * 0.5 + 10.0), r.end.y - 8.0))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sx * 10.0, -8.0), c + Vector2(sx * 6.0, 8.0), c + Vector2(-sx * 14.0, 8.0)]), EDGE)


## The pause button: two bars in a small carved hexagon.
func _draw_pause() -> void:
	var down := _pause.button_pressed or _pause.is_hovered()
	var c := _pause.size * 0.5 + (Vector2(0, DEPTH * 0.5) if down else Vector2.ZERO)
	var r := 21.0
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * float(i) / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_shape(_pause, pts, 0.6)
	for sx: float in [-1.0, 1.0]:
		var bar := Rect2(c.x + sx * 6.0 - 3.0, c.y - 9.0, 6.0, 18.0)
		_pause.draw_rect(Rect2(bar.position + Vector2(0, 2.0), bar.size), Color("#3a1404"))
		_pause.draw_rect(bar, INK)


func set_pause_visible(v: bool) -> void:
	if _pause != null:
		_pause.visible = v


## Called once per frame by the play screen.
func tick(t: float, delta: float) -> void:
	if session == null:
		return
	# The number counts up quickly rather than jumping, so big hits read as big.
	_shown_score = move_toward(_shown_score, session.score, maxf(40.0, absf(session.score - _shown_score) * 12.0) * delta)
	var shown := UIKit.fmt_score(roundi(_shown_score))
	if shown != _score.text and session.score > _punched:
		# the number swells as points land, more for a bigger jump
		_punch = clampf(0.06 + float(session.score - _punched) / 4000.0, 0.06, 0.2)
		_punched = session.score
	_score.text = shown
	_punch = move_toward(_punch, 0.0, delta * 0.8)
	_score.pivot_offset = _score.size * 0.5
	_score.scale = Vector2.ONE * (1.0 + _punch)
	_streak = float(session.unison_streak) / float(Session.UNISON_STEP) if session.unison_level < 5 else 1.0
	_meter.fill = _streak
	_bar.progress = session.progress(t)
	_progress = _bar.progress
	_section.text = _bar.section_name(t)
	if ghost != null and not ghost.is_empty() and judged_any(session):
		# Points, not seconds: how far above or below your best run you are at this moment.
		var d := ghost.delta_at(t, session.score)
		_ghost.text = ghost_text(d)
		_ghost.modulate = Color("#ffc445") if d > 0 else Color.WHITE
	elif ghost != null and not ghost.is_empty():
		_ghost.text = ""
	else:
		_ghost.text = tr("hud_unison_hint") if session.unison_level == 0 else ""
		_ghost.modulate = Color("#ffc445")


func set_unison(level: int, animate := true) -> void:
	_unison.text = _mult_text(Session.UNISON_MULTS[level])
	_meter.level = level
	if animate:
		_flare_at = _clock
		var tw := _unison.create_tween()
		_unison.modulate = Color(1.4, 1.3, 1.1)
		if not UIKit.reduced_motion():
			_unison.pivot_offset = _unison.size * 0.5
			_unison.scale = Vector2(1.18, 1.18)
			tw.tween_property(_unison, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_unison, "modulate", Color.WHITE, 0.3)
		_meter.flare()


static func _mult_text(m: float) -> String:
	return ("%dx" % int(m)) if is_equal_approx(m, roundf(m)) else ("%.1fx" % m)


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
