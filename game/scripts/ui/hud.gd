class_name Hud
extends Control
## The top of the play screen, after Daniele's play-screen picture (mockups/lowpoly/
## play_screen_hud_target.png): a thin progress line across the top between two diamonds, then three
## carved frames with glowing orange edges - health as hearts on the left, the unison multiplier in
## a big hexagonal badge in the middle (its lower rim fills with the streak toward the next level),
## the score on the right. The ghost line (ahead or behind your best) and the song's section are
## kept but not shown. A small pause button sits at the top right.
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
var beat := -1000.0          ## the song's beat now, for the badge's bounce
var _bounce := 0.0           ## 1 on the beat, falling away
var _punched := 0


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func font(bold := true) -> Font:
	return load("res://fonts/AlegreyaSans-ExtraBold.ttf" if bold else "res://fonts/AlegreyaSC-Bold.ttf")


## In the pixel look: the bitmap face that stands in for a smooth font size, over the lens.
func pstyle(l: Label, size: int, color: Color, bold := true, outline := 6) -> void:
	var face := "caps"
	if size >= 56:
		face = "big"
	elif size >= 40:
		face = "score"
	PxType.label(l, face, color)
	l.z_index = PixelFilter.Z_OVER


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
	pstyle(_score, 42, SCORE_INK)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score)
	_ghost = Label.new()
	_ghost.name = "Ghost"
	pstyle(_ghost, 24, INK, false, 5)
	_ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	# Health: five hearts, two points each (hidden where health is off: lessons, autoplay).
	_health = HealthPips.new()
	_health.name = "Health"
	_health.session = session
	_health.reduced_motion = UIKit.reduced_motion()
	_health.size = _health.custom_minimum_size
	_health.visible = session.health_on
	add_child(_health)
	_unison = Label.new()
	_unison.name = "Unison"
	pstyle(_unison, 60, GOLD_INK, true, 8)
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
	pstyle(_section, 24, GOLD_INK, false, 5)
	_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_section)
	# The song's progress: kept for its sections; the line itself is drawn with the frames.
	_bar = SectionBar.new()
	_bar.name = "Progress"
	_bar.visible = false
	_bar.setup(session)
	add_child(_bar)
	# No words under the frames (Daniele, 2026-10-05): the song's section and the line against your
	# best run are hidden, so the figures' heads have the space under the HUD to themselves. They
	# are still kept up to date (tests read them).
	_section.visible = false
	_ghost.visible = false
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
	# the pixel type runs wider: the line wraps onto two, right-aligned under the score
	_ghost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ghost.size.y = 54.0
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


## The pixel look's frames are Daniele's pictures (art/ai/hud_*.png, 2026-10-08), each in three
## slices: its two ends kept to their shape at the frame's height, its middle stretched between
## them. Made once per size at one texel per cell (the HUD is drawn one px per cell), every texel
## wholly in or out, so they stay crisp.
const SLICE := {"hud_plate": 240, "hud_bar": 90}   ## each picture's end width, its own px
static var _sliced := {}


static func sliced(key: String, cells: Vector2i) -> Texture2D:
	cells = cells.max(Vector2i(2, 2))
	var k := "%s_%d_%d" % [key, cells.x, cells.y]
	if _sliced.has(k):
		return _sliced[k]
	var tex: Texture2D = null
	var path := "res://art/ai/%s.webp" % key
	if ResourceLoader.exists(path):
		var src := StreetSkin.ai_image(path)
		src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var w := src.get_width()
		var h := src.get_height()
		var cap_src := int(SLICE.get(key, 0))
		var cap := clampi(roundi(cap_src * float(cells.y) / h), 0, cells.x / 2)
		var out := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
		var parts := [[0, cap_src, 0, cap], [cap_src, w - cap_src, cap, cells.x - cap], [w - cap_src, w, cells.x - cap, cells.x]]
		if cap_src == 0:
			parts = [[0, w, 0, cells.x]]
		for part: Array in parts:
			var dw: int = part[3] - part[2]
			if dw <= 0:
				continue
			var piece := src.get_region(Rect2i(part[0], 0, part[1] - part[0], h))
			piece.resize(dw, cells.y, Image.INTERPOLATE_LANCZOS)
			out.blit_rect(piece, Rect2i(0, 0, dw, cells.y), Vector2i(part[2], 0))
		for y in cells.y:
			for x in cells.x:
				var c := out.get_pixel(x, y)
				c.a = 1.0 if c.a > 0.5 else 0.0
				out.set_pixel(x, y, c)
		tex = ImageTexture.create_from_image(out)
	_sliced[k] = tex
	return tex


## Draws picture `key` over r (base px), snapped to whole cells.
func _picture(ci: CanvasItem, key: String, r: Rect2, mod := Color.WHITE) -> void:
	var px := PxArt.PX
	var cells := Vector2i((r.size / px).round())
	var tex := sliced(key, cells)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(PxArt.snap2(r.position), Vector2(cells) * px), false, mod)


## A carved frame: a dark panel with pointed ends, an orange edge glowing outward, a thin inner line,
## and a small diamond at each point.
func _panel(ci: CanvasItem, r: Rect2, glow := 1.0) -> void:
	# the plate's diamonds stand out past the frame's points, as the drawn ones did
	var grow := r.size.y * 0.16
	var rr := r.grow_individual(grow, grow * 0.35, grow, grow * 0.35)
	_glow_round(ci, rr, glow)
	_picture(ci, "hud_plate", rr)


## A frame in relief: a thick slab standing out of the screen (its lower sides show below it), a
## bevelled orange rim lit from the top left (the light faces bright, the shaded ones deep bronze) and
## a dark panel sunk inside it, with the glow round the outside.
func _shape(ci: CanvasItem, pts: PackedVector2Array, glow: float, pal: Array = []) -> void:
	if pal.is_empty():
		pal = [EDGE, EDGE_HOT, EDGE_DARK, SIDE, Color(1.0, 0.5, 0.1)]
	var edge: Color = pal[0]
	var hot: Color = pal[1]
	var dark: Color = pal[2]
	var side: Color = pal[3]
	var halo: Color = pal[4]
	var g := PackedVector2Array()
	for p in pts:
		g.append(_to_frames(p))
	var closed := g.duplicate()
	closed.append(g[0])
	for k in 3:
		ci.draw_polyline(closed, Color(halo, 0.12 * glow), 18.0 - k * 5.0, true)
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
			_quad(ci, [p0, p1, p1 + down, p0 + down], side.lerp(side.darkened(0.5), clampf(0.5 + nn.x * 0.5, 0.0, 1.0)))
	# the bevelled rim
	var inner := _inset(g, BEVEL)
	for i in n:
		var p0 := g[i]
		var p1 := g[(i + 1) % n]
		var lit := _normal(p0, p1).dot(LIGHT)
		var col := edge.lerp(hot, clampf(lit, 0.0, 1.0)) if lit >= 0.0 else edge.lerp(dark, clampf(-lit, 0.0, 1.0))
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
	ci.draw_polyline(closed, Color(hot, 0.9), 1.5, true)


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


## A soft orange glow round a pixel frame, as the drawn frames have.
func _glow_round(ci: CanvasItem, r: Rect2, glow: float) -> void:
	var t := r.size.y * 0.5
	var pts := PackedVector2Array([r.position + Vector2(t * 0.6, 0), Vector2(r.end.x - t * 0.6, r.position.y), Vector2(r.end.x, r.get_center().y),
		r.end - Vector2(t * 0.6, 0), Vector2(r.position.x + t * 0.6, r.end.y), Vector2(r.position.x, r.get_center().y), r.position + Vector2(t * 0.6, 0)])
	for k in 3:
		ci.draw_polyline(pts, Color(1.0, 0.5, 0.1, 0.1 * glow), 16.0 - k * 5.0, true)


## A cut diamond stud: four facets lit from the top left, on a dark base that shows below it.
func _diamond(ci: CanvasItem, at: Vector2, r: float, col := EDGE_HOT) -> void:
	# Daniele's stud, tinted toward the badge's colour when it is not plain gold
	var tint := Color.WHITE if col == EDGE_HOT else Color.WHITE.lerp(col, 0.5) * 1.2
	_picture(ci, "hud_stud", Rect2(at - Vector2(r, r) * 1.25, Vector2(r, r) * 2.5), tint)


func _draw_frames() -> void:
	if session == null:
		return
	var ci := _frames
	var b := _boxes()
	var line: Vector3 = b[3]
	# the progress line between two diamonds
	var a := _to_frames(Vector2(line.x + 14.0, line.z))
	var e := _to_frames(Vector2(line.y - 14.0, line.z))
	# Daniele's bar, its groove filling with a glowing rod as the song goes on
	var bh := 21.0
	var bar := Rect2(Vector2(line.x, line.z - bh * 0.5), Vector2(line.y - line.x, bh))
	_picture(ci, "hud_bar", bar)
	var px := PxArt.PX
	var g0 := PxArt.snap2(Vector2(bar.position.x + bh * 0.9, line.z - px))
	var gx1 := bar.end.x - bh * 0.9
	var fw := roundf((lerpf(g0.x, gx1, clampf(_progress, 0.0, 1.0)) - g0.x) / px) * px
	if fw >= px:
		ci.draw_rect(Rect2(g0, Vector2(fw, px)), EDGE_HOT)
		ci.draw_rect(Rect2(g0 + Vector2(0.0, px), Vector2(fw, px)), EDGE)
	if session.health_on:
		_panel(ci, b[0])
	_panel(ci, b[2])
	_draw_badge(ci, b)


func _draw_line_frames(ci: CanvasItem, a: Vector2, e: Vector2) -> void:
	var b := _boxes()
	var line: Vector3 = b[3]
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


func _draw_badge(ci: CanvasItem, b: Array) -> void:
	# the badge: a tall hexagon, flaring when a level is gained; its lower rim fills with the streak.
	# It bounces on every beat, and grows and burns hotter in colour as the multiplier rises.
	var r: Rect2 = b[1]
	var lvl := session.unison_level
	var pal := _tier(lvl)
	var fl := clampf(1.0 - (_clock - _flare_at) / 0.4, 0.0, 1.0)
	var sc := badge_scale()
	var ctr := r.get_center()
	# light rays turning behind it from the third level up, in its colours
	if lvl >= 3:
		var n := 12
		var ray_r := r.size.y * (0.75 + 0.12 * float(lvl - 3)) * sc
		for i in n:
			var an := TAU * float(i) / n + _clock * 0.6
			var w := 0.09
			var col: Color = pal[1] if i % 2 == 0 else pal[0]
			if lvl >= 5:
				col = Color.from_hsv(fposmod(float(i) / n + _clock * 0.25, 1.0), 0.75, 1.0)
			ci.draw_polygon(PackedVector2Array([ctr, ctr + Vector2(cos(an - w), sin(an - w)) * ray_r, ctr + Vector2(cos(an + w), sin(an + w)) * ray_r]),
				PackedColorArray([Color(col, 0.55), Color(col, 0.0), Color(col, 0.0)]))
	var hx := PackedVector2Array()
	for q in [Vector2(0.0, -0.5), Vector2(0.5, -0.24), Vector2(0.5, 0.24), Vector2(0.0, 0.5), Vector2(-0.5, 0.24), Vector2(-0.5, -0.24)]:
		hx.append(ctr + q * r.size * sc)
	_shape(ci, hx, 1.0 + 0.8 * float(lvl) + 2.0 * fl + 1.5 * _bounce, pal)
	if _streak > 0.0:
		var p0 := _to_frames(hx[4])
		var p1 := _to_frames(hx[3])
		var p2 := _to_frames(hx[2])
		var k := clampf(_streak, 0.0, 1.0) * 2.0
		var q := p0.lerp(p1, minf(k, 1.0))
		ci.draw_line(p0, q, pal[1], 5.0)
		if k > 1.0:
			ci.draw_line(p1, p1.lerp(p2, k - 1.0), pal[1], 5.0)
	for p in [hx[0], hx[3]]:
		_diamond(ci, p, 8.0 * sc, Color.WHITE.lerp(pal[1], 1.0 - fl))
	# the little spurs at its foot (the pixel look's badge stands on its own: they read as stray marks)
	for sx: float in []:
		var c := _to_frames(Vector2(ctr.x + sx * (r.size.x * 0.5 * sc + 10.0), ctr.y + r.size.y * 0.5 * sc - 8.0))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-sx * 10.0, -8.0), c + Vector2(sx * 6.0, 8.0), c + Vector2(-sx * 14.0, 8.0)]), pal[0])


## The badge's colours by unison level: [rim, lit rim, shaded rim, side, glow, number]. It heats up
## from a dull ember through orange and gold to fire red and violet, and the top level shifts
## through every colour.
func _tier(level: int) -> Array:
	var tiers := [
		[Color("#b8641e"), Color("#e8a050"), Color("#5a2a08"), Color("#3e1c06"), Color(0.9, 0.4, 0.1), Color("#e8c890")],
		[Color("#ff9a32"), Color("#ffd27a"), Color("#7a2e06"), Color("#5a2408"), Color(1.0, 0.5, 0.1), Color("#ffd35a")],
		[Color("#ffc42a"), Color("#fff0a0"), Color("#8a5200"), Color("#5e3a04"), Color(1.0, 0.75, 0.1), Color("#fff2a8")],
		[Color("#ff4a24"), Color("#ffb070"), Color("#7a0e06"), Color("#4e0a04"), Color(1.0, 0.3, 0.1), Color("#ffe0b0")],
		[Color("#d23cff"), Color("#ffa8ff"), Color("#5a0a7a"), Color("#3a0650"), Color(0.8, 0.3, 1.0), Color("#ffe0ff")],
		[Color("#40c8ff"), Color("#e0ffff"), Color("#0a3a7a"), Color("#062650"), Color(0.3, 0.8, 1.0), Color("#ffffff")],
	]
	var t: Array = tiers[clampi(level, 0, tiers.size() - 1)].duplicate()
	if level >= 5:
		var hue := fposmod(_clock * 0.25, 1.0)
		t[0] = Color.from_hsv(hue, 0.8, 1.0)
		t[1] = Color.from_hsv(hue, 0.3, 1.0)
		t[2] = Color.from_hsv(hue, 0.9, 0.45)
		t[4] = Color.from_hsv(hue, 0.7, 1.0)
	return t


## The badge's size now: bigger at each unison level, and a bounce on every beat (smaller with
## reduced motion).
func badge_scale() -> float:
	var lvl := session.unison_level if session != null else 0
	return (1.0 + 0.07 * float(lvl)) * (1.0 + (0.05 + 0.025 * float(lvl)) * _bounce)


## The pause button: two bars in a small carved hexagon.
func _draw_pause() -> void:
	var down := _pause.button_pressed or _pause.is_hovered()
	var c := _pause.size * 0.5 + (Vector2(0, DEPTH * 0.5) if down else Vector2.ZERO)
	var sz := Vector2(48.0, 53.0)
	_picture(_pause, "hud_pause", Rect2(c - sz * 0.5, sz), Color(0.8, 0.8, 0.8) if down else Color.WHITE)


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
	# the badge bounces on the beat: a quick swell, easing back before the next one
	_bounce = 0.0 if beat < 0.0 else pow(1.0 - fposmod(beat, 1.0), 3.0) * (0.35 if UIKit.reduced_motion() else 1.0)
	var bs := badge_scale()
	_unison.pivot_offset = _unison.size * 0.5
	if not _unison_tweening():
		_unison.scale = Vector2(bs, bs)
	_unison.add_theme_color_override("font_color", _tier(session.unison_level)[5])
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
			_unison.scale = Vector2.ONE * badge_scale() * 1.25
			tw.tween_property(_unison, "scale", Vector2.ONE * badge_scale(), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_unison, "modulate", Color.WHITE, 0.3)
		_meter.flare()


func _unison_tweening() -> bool:
	return _clock - _flare_at < 0.22


static func _mult_text(m: float) -> String:
	return ("%dx" % int(m)) if is_equal_approx(m, roundf(m)) else ("%.1fx" % m)


## The lower edge of the side frames (hearts and score), in this HUD's coordinates: the street keeps
## the figures' heads under it.
func frames_bottom() -> float:
	return PANEL_Y + PANEL_H + DEPTH


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
