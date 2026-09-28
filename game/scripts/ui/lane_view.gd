class_name LaneView
extends Control
## The road of three lanes and the three step buttons, in the "Fire Night" look (Art's FireSkin; LaneSkin
## keeps the layout: lane rects, hit line, note positions). The play screen feeds it
## the session and the song time each frame; hits add bursts and button flashes the same frame the
## input arrives (flash() / burst() are called from the input signal handlers, then queue_redraw()).

const BUTTONS_H := 196.0        ## height of the button row
const LOOKAHEAD := 1.5          ## seconds of notes visible at note speed 1.0
const FLASH_TIME := 0.14
const CUE_TIME := 0.22          ## a button is "cued" when its next note is this close
const MARK_TIME := 0.4          ## wrong-lane and rope marks
const TICK_TIME := 1.6          ## timing ticks fade over this long
const STEP_TICK_TIME := 0.3     ## the early/late tick on a step hit fades over this long

var session: Session
var song_time := 0.0
var note_speed := 1.0
var router: InputRouter          ## for pressed state; null in autoplay
var show_buttons := true
var beat_pulse := 0.0

var _bursts: Array = []          ## [pos: Vector2, quality: String, t0: float]
var _flash: Array[float] = [-9.0, -9.0, -9.0]
var _flash_kind: Array[String] = ["hit", "hit", "hit"]
var _auto_pressed: Array[float] = [-9.0, -9.0, -9.0]
var _first := 0                  ## first note that may still be drawn
var _clock := 0.0                ## real seconds, for burst ages while paused
var _offsets: Array = []         ## [offset s, time added, lane] of recent hits, for the timing ticks
var _step_ticks: Array = []      ## [lane, side, time added]: the early/late tick of a step hit
var _marks: Array = []           ## [kind, lane, time]: "wrong" X on a pressed button, "faint" ring on
                                 ## the note it was meant for, "rope" grip across the buttons


func field_rect() -> Rect2:
	var h := size.y - (BUTTONS_H if show_buttons else 0.0)
	return Rect2(Vector2.ZERO, Vector2(size.x, maxf(h, 10.0)))


func buttons_rect() -> Rect2:
	return Rect2(0.0, size.y - BUTTONS_H, size.x, BUTTONS_H)


## Global rect of the button row, for InputRouter.buttons_rect.
func buttons_global_rect() -> Rect2:
	var r := buttons_rect()
	return Rect2(get_global_transform() * r.position, r.size * get_global_transform().get_scale())


func lane_center(lane: int) -> Vector2:
	var rects := LaneSkin.lane_rects(field_rect())
	var r: Rect2 = rects[clampi(lane, 0, 2)]
	return Vector2(r.get_center().x, LaneSkin.hit_line_y(field_rect()))


## Centre of the strip between the hit line and the buttons, under a lane: where judgement words go,
## clear of every note still to come.
func word_spot(lane: int) -> Vector2:
	var f := field_rect()
	var hl := LaneSkin.hit_line_y(f)
	var x := lane_center(lane).x if lane >= 0 else f.get_center().x
	return project(Vector2(x, hl + (f.end.y - hl) * 0.5))


func reset() -> void:
	_first = 0
	_bursts.clear()
	_step_ticks.clear()


## A button went down (player or autoplay): flash it now.
func press(lane: int) -> void:
	if lane < 0 or lane > 2:
		return
	_auto_pressed[lane] = _clock
	queue_redraw()


func flash(lane: int, good: bool) -> void:
	if lane < 0 or lane > 2:
		return
	_flash[lane] = _clock
	_flash_kind[lane] = "hit" if good else "miss"
	queue_redraw()


## A hit burst at pos. side ("early"/"late") adds a chevron in the early/late pair: up and cool for
## early, down and warm for late.
func burst(pos: Vector2, quality: String, side := "") -> void:
	_bursts.append([pos, quality, _clock, side])
	queue_redraw()
	if _fx != null:
		_fx.queue_redraw()


## A judged hit's offset (negative = early), shown as a tick at the lane's hit line: above the line
## for early (where the note still was), below for late.
func add_offset(offset: float, lane := 1) -> void:
	_offsets.append([offset, _clock, lane])
	if _offsets.size() > 24:
		_offsets.pop_front()


## A Good or Ok step hit off time: a small tick at the lane, cool above the hit line when early,
## warm below it when late, gone in STEP_TICK_TIME, so the side reads at a glance without words.
func step_tick(lane: int, side: String) -> void:
	if lane < 0 or lane > 2 or side == "":
		return
	_step_ticks.append([lane, side, _clock])
	if _step_ticks.size() > 6:
		_step_ticks.pop_front()
	queue_redraw()


## The sides of the step ticks still showing ("early"/"late"), oldest first.
func step_ticks_shown() -> Array[String]:
	var out: Array[String] = []
	for k in _step_ticks:
		if _clock - float(k[2]) <= STEP_TICK_TIME:
			out.append(str(k[1]))
	return out


## A step on the wrong lane: a red X on the button actually pressed, and a faint ring where the note
## it was meant for is.
func mark_wrong(pressed_lane: int, note_lane := -1) -> void:
	_marks.append(["wrong", pressed_lane, _clock])
	if note_lane >= 0 and note_lane != pressed_lane:
		_marks.append(["faint", note_lane, _clock])
	queue_redraw()


## A finger landed on the buttons while a rope is due: the rope is "caught" at once, with no step.
func rope_grab(lane: int) -> void:
	_marks.append(["rope", lane, _clock])
	_auto_pressed[clampi(lane, 0, 2)] = _clock
	queue_redraw()


## Marks drawn right now (kind:lane), for tests.
func marks_shown() -> Array[String]:
	var out: Array[String] = []
	for m in _marks:
		if _clock - float(m[2]) < MARK_TIME:
			out.append("%s:%d" % [m[0], m[1]])
	return out


func _process(delta: float) -> void:
	_clock += delta
	if session != null:
		while _first < session.notes.size() and _gone(session.notes[_first], song_time):
			_first += 1
	queue_redraw()
	for c in [_surface, _under, _fx]:
		if c != null:
			c.queue_redraw()


func _px_per_s() -> float:
	var f := field_rect()
	return (LaneSkin.hit_line_y(f) - f.position.y) / (LOOKAHEAD / maxf(note_speed, 0.1))


## Screen drawing on top of the road: the hit line and its receptors, then everything standing on the
## road (gems, rings, badges, the rope, labels), then the buttons.
func _draw() -> void:
	if not _road_on():
		_draw_field(self)
	_draw_hit_line()
	if session != null:
		_draw_upright()
	_draw_chevrons()
	if show_buttons:
		_draw_buttons()
		_draw_marks()


## Things lying flat on the road, in flat field coordinates: drawn straight onto this control, or into
## the road's viewport to be laid back in perspective. Sashes, bell bars, stand-still bands, ticks.
func _draw_field(ci: CanvasItem) -> void:
	var field := field_rect()
	field.position = Vector2.ZERO
	FireSkin.draw_setts(ci, field)
	if session != null:
		_draw_flat_notes(ci, field)
	_draw_timing_ticks(ci, field)
	_draw_step_ticks(ci, field)


func _lane_glow(lane: int) -> float:
	if _is_pressed(lane):
		return 1.0
	return clampf(1.0 - (_clock - _flash[lane]) / FLASH_TIME, 0.0, 1.0) * 0.7


# ------------------------------------------------------------------ the road (3D perspective)

## The field is drawn flat into a viewport and shown as a road laid back toward the horizon: full width
## at the hit line end, TOP_W of that at the far end, so notes come toward the player and grow as they
## near. Straight lines stay straight (a true perspective), so lanes, bars and holds keep their shape.
## What lies on the road foreshortens with it; what stands on it (gems, badges, the rope) is drawn
## upright on screen at its projected place, scaled with the road.
const TOP_W := 0.42
const ROAD_SHADER := """
shader_type canvas_item;
uniform float top_w = 0.42;
uniform vec4 fog : source_color = vec4(0.23, 0.11, 0.12, 1.0);
void fragment() {
	float w = top_w + (1.0 - top_w) * UV.y;
	float u = 0.5 + (UV.x - 0.5) / w;
	float v = (1.0 / top_w - 1.0 / w) / (1.0 / top_w - 1.0);
	vec4 c = texture(TEXTURE, vec2(clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0)));
	float far = 1.0 - (w - top_w) / (1.0 - top_w);
	c.rgb = mix(c.rgb, fog.rgb, far * far * 0.5);
	float edge = min(u, 1.0 - u);
	c.a *= smoothstep(0.0, fwidth(u) * 1.5, edge) * smoothstep(0.0, 0.06, v);
	COLOR = c;
}
"""
## Road surface colours from the far end (by the fire) to the buttons.
const ROAD_STOPS := [[0.0, Color("#2a1c22")], [0.25, Color("#1a1520")], [0.6, Color("#131018")], [1.0, Color("#0c0a12")]]

var perspective := true          ## false: the flat lanes (the Piazza hides them anyway; tests may flatten)
var beat := -1000.0              ## the song's beat now (fractional), for the beads on the rails
var spb := 0.0                   ## seconds per beat (0: no beads)
var _vp: SubViewport
var _flat: Control
var _road: TextureRect
var _surface: Control            ## the road's stone, dividers and far-end haze (behind everything)
var _under: Control              ## additive, under the notes: rail glow, beads, the hit line's glow
var _fx: Control                 ## additive, over the notes: hit bursts


func _ready() -> void:
	_surface = _Layer.new(self, "_draw_surface")
	_surface.name = "Surface"
	_surface.show_behind_parent = true
	add_child(_surface)
	move_child(_surface, 0)
	if perspective:
		_vp = SubViewport.new()
		_vp.name = "RoadView"
		_vp.transparent_bg = true
		_vp.disable_3d = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_vp)
		_flat = _FlatField.new()
		_flat.set("view", self)
		_vp.add_child(_flat)
		_road = TextureRect.new()
		_road.name = "Road"
		_road.texture = _vp.get_texture()
		_road.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_road.stretch_mode = TextureRect.STRETCH_SCALE
		_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_road.show_behind_parent = true
		var sh := Shader.new()
		sh.code = ROAD_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("top_w", TOP_W)
		_road.material = mat
		add_child(_road)
		move_child(_road, 1)
		resized.connect(_fit_road)
		_fit_road()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_under = _Layer.new(self, "_draw_under")
	_under.name = "Glow"
	_under.show_behind_parent = true
	_under.material = add
	add_child(_under)
	move_child(_under, 2 if perspective else 1)
	_fx = _Layer.new(self, "_draw_fx")
	_fx.name = "Bursts"
	_fx.material = add
	add_child(_fx)
	move_child(_fx, _under.get_index() + 1)


func _road_on() -> bool:
	return _road != null


func _fit_road() -> void:
	var f := field_rect()
	_vp.size = Vector2i(maxi(int(f.size.x), 1), maxi(int(f.size.y), 1))
	_flat.size = f.size
	_road.position = f.position
	_road.size = f.size


## Road width at flat depth y (0 at the far end, the field's height at the near end), as a share of
## the near width.
func road_scale(flat_y: float) -> float:
	if not _road_on():
		return 1.0
	var v := flat_y / maxf(field_rect().size.y, 1.0)
	return 1.0 / maxf(1.0 / TOP_W - v * (1.0 / TOP_W - 1.0), 0.05)


## Where a point of the flat field shows on screen (this control's coordinates).
func project(p: Vector2) -> Vector2:
	var f := field_rect()
	if not _road_on():
		return p
	var w := road_scale(p.y)
	var y := f.size.y * (w - TOP_W) / (1.0 - TOP_W)
	return f.position + Vector2(f.size.x * 0.5 + (p.x - f.size.x * 0.5) * w, y)


## The road's left and right edge on screen at screen height y (this control's coordinates).
func road_edges(y: float) -> Vector2:
	var f := field_rect()
	var w := 1.0
	if _road_on():
		w = TOP_W + (1.0 - TOP_W) * clampf((y - f.position.y) / maxf(f.size.y, 1.0), 0.0, 1.0)
	return Vector2(f.get_center().x - f.size.x * 0.5 * w, f.get_center().x + f.size.x * 0.5 * w)


## Scale of things standing on the road at flat depth y: the lane's width on screen / FireSkin's 240.
func upright_scale(flat_y: float) -> float:
	return road_scale(flat_y) * field_rect().size.x / 3.0 / FireSkin.REF_LANE


## The far end of the road on screen (centre x, y) and its width, where it meets the fire.
func far_end() -> Rect2:
	var f := field_rect()
	var e := road_edges(f.position.y)
	return Rect2(e.x, f.position.y, e.y - e.x, 0.0)


class _FlatField extends Control:
	var view: LaneView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if view != null:
			view._draw_field(self)


## A drawing layer of the lanes (its own canvas item, for its place in the order and its blend mode).
class _Layer extends Control:
	var view: LaneView
	var method: String

	func _init(p_view: LaneView, p_method: String) -> void:
		view = p_view
		method = p_method
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		view.call(method, self)


## The road's stone: dark and calm, warm where the fire falls on its far end, with faint cobble
## courses and two thin lane dividers. Nothing busy where the notes travel.
func _draw_surface(ci: CanvasItem) -> void:
	var f := field_rect()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for s in ROAD_STOPS:
		var y: float = f.position.y + f.size.y * float(s[0])
		var e := road_edges(y)
		pts.append(Vector2(e.x, y))
		pts.append(Vector2(e.y, y))
		cols.append(s[1])
		cols.append(s[1])
	for i in ROAD_STOPS.size() - 1:
		var k := i * 2
		ci.draw_polygon(PackedVector2Array([pts[k], pts[k + 1], pts[k + 3], pts[k + 2]]), PackedColorArray([cols[k], cols[k + 1], cols[k + 3], cols[k + 2]]))
	# Lane dividers: warm, 2 px, 35% up to the hit line and half that below it.
	var ff := Rect2(Vector2.ZERO, f.size)
	var hl := LaneSkin.hit_line_y(ff)
	for u in [1.0 / 3.0, 2.0 / 3.0]:
		var a := project(Vector2(ff.size.x * u, 0.0))
		var m := project(Vector2(ff.size.x * u, hl))
		var b := project(Vector2(ff.size.x * u, ff.size.y))
		ci.draw_line(a, m, Color(1.0, 0.75, 0.47, 0.35), 2.0, true)
		ci.draw_line(m, b, Color(1.0, 0.75, 0.47, 0.18), 2.0, true)


## A soft glow (centre c, radii rx, ry on screen) laid on the road only: the glow texture mapped onto
## the road's outline, so nothing spills onto the square or the figures.
func _road_glow(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var f := field_rect()
	var top := road_edges(f.position.y)
	var bottom := road_edges(f.end.y)
	var quad := PackedVector2Array([Vector2(top.x, f.position.y), Vector2(top.y, f.position.y), Vector2(bottom.y, f.end.y), Vector2(bottom.x, f.end.y)])
	var uvs := PackedVector2Array()
	for p in quad:
		uvs.append(Vector2((p.x - c.x) / (rx * 2.0), (p.y - c.y) / (ry * 2.0)) + Vector2(0.5, 0.5))
	RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_DISABLED)
	ci.draw_polygon(quad, PackedColorArray([col]), uvs, FireSkin.glow())


## Additive, under the notes: the ember rails on the road's edges with beads riding them down to the
## hit line on every beat, pulses on the dividers, the fire's haze at the far end, the hit line's
## glow and the light of a pressed lane.
func _draw_under(ci: CanvasItem) -> void:
	var f := field_rect()
	var ff := Rect2(Vector2.ZERO, f.size)
	var k := f.size.x / 720.0
	var pulse := clampf(beat_pulse, 0.0, 1.0)
	var soft := FireSkin.soft()
	for side in 2:
		var xa := 0.0 if side == 0 else ff.size.x
		var a := project(Vector2(xa, 0.0))
		var b := project(Vector2(xa, ff.size.y))
		var wa := 10.0 * k
		var wb := 22.0 * k
		ci.draw_polygon(PackedVector2Array([a - Vector2(wa, 0), a + Vector2(wa, 0), b + Vector2(wb, 0), b - Vector2(wb, 0)]),
			PackedColorArray([Color(1.0, 0.75, 0.4, 0.8), Color(1.0, 0.75, 0.4, 0.8), Color(1.0, 0.35, 0.1, 0.7), Color(1.0, 0.35, 0.1, 0.7)]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), soft)
		ci.draw_line(a, b, Color(1.0, 0.55, 0.2, 0.9), 4.0 * k)
		ci.draw_line(a, b, Color(1.0, 0.95, 0.85, 0.9), 1.5)
	# Beads: one per beat on each rail, arriving at the hit line on the beat.
	if spb > 0.0 and beat > -999.0:
		var pps := _px_per_s()
		var hl := LaneSkin.hit_line_y(ff)
		var b0 := floori(beat)
		var g := FireSkin.glow()
		for n in range(b0, b0 + int(LOOKAHEAD / maxf(note_speed, 0.1) / spb) + 3):
			var y := hl - (float(n) - beat) * spb * pps
			if y < 0.0 or y > ff.size.y:
				continue
			var w := road_scale(y)
			var fade := clampf(y / (ff.size.y * 0.08), 0.0, 1.0)
			var r := (10.0 * w + 3.0) * k * 4.0
			for xa in [0.0, ff.size.x]:
				var p := project(Vector2(xa, y))
				ci.draw_texture_rect(g, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.75, 0.4, 0.95 * fade))
			for u in [1.0 / 3.0, 2.0 / 3.0]:
				var p := project(Vector2(ff.size.x * u, y))
				ci.draw_texture_rect(g, Rect2(p - Vector2(r * 0.25, r * 0.9), Vector2(r * 0.5, r * 1.8)), false, Color(1.0, 0.7, 0.4, 0.3 * fade))
	# The fire's light across the far third of the road and its long reflection down the middle,
	# breathing with the beat; the hit line pours a little warm light on the stone nearest the player.
	var fe := far_end()
	var fc := fe.get_center()
	var flick := 0.94 + 0.06 * sin(_clock * 9.0) * sin(_clock * 5.3)
	_road_glow(ci, fc, 470.0 * k, 470.0 * k, Color(1.0, 0.55, 0.2, (0.42 + 0.1 * pulse) * flick))
	_road_glow(ci, fc, 196.0 * k, 700.0 * k, Color(1.0, 0.67, 0.31, (0.34 + 0.08 * pulse) * flick))
	var hp := project(Vector2(ff.size.x * 0.5, LaneSkin.hit_line_y(ff)))
	_road_glow(ci, hp, 420.0 * k, 420.0 * k, Color(1.0, 0.47, 0.16, 0.14))
	# Divider glow, soft and faint.
	for u in [1.0 / 3.0, 2.0 / 3.0]:
		ci.draw_line(project(Vector2(ff.size.x * u, 0.0)), project(Vector2(ff.size.x * u, LaneSkin.hit_line_y(ff))), Color(1.0, 0.6, 0.3, 0.1), 7.0 * k, true)
	# Ember specks drifting along the road's outer margins, outside the gem paths.
	for i in 46:
		var v := fposmod(WoodcutDraw.hash01(i, 61) + _clock * 0.02 * (0.5 + WoodcutDraw.hash01(i, 67)), 1.0)
		var y := ff.size.y * v * 0.95
		var side := -1.0 if i % 2 == 0 else 1.0
		var u := 0.5 + side * (0.45 + 0.04 * WoodcutDraw.hash01(i, 71))
		var p := project(Vector2(ff.size.x * u, y))
		var sz := (1.0 + 2.0 * WoodcutDraw.hash01(i, 73)) * road_scale(y) * k
		var tw := 0.5 + 0.5 * sin(_clock * (2.0 + 3.0 * WoodcutDraw.hash01(i, 79)) + float(i))
		ci.draw_rect(Rect2(p, Vector2(sz, sz)), Color(1.0, 0.55 + 0.35 * WoodcutDraw.hash01(i, 83), 0.24, (0.35 + 0.5 * WoodcutDraw.hash01(i, 89)) * tw))
	var hy := project(Vector2(0.0, LaneSkin.hit_line_y(ff))).y
	var span := _screen_span()
	FireSkin.draw_hit_glow(ci, span.x, span.y, hy, pulse)


## Additive, over the notes: the hit bursts, upright at their projected place, and sparks thrown up
## from a pressed plate.
func _draw_fx(ci: CanvasItem) -> void:
	if show_buttons:
		var r := buttons_rect()
		var w := r.size.x / 3.0
		for lane in 3:
			var st := _button_state(lane)
			if st != "pressed" and st != "hit":
				continue
			for j in 14:
				var ph := fposmod(WoodcutDraw.hash01(j, 91 + lane) + _clock * (1.2 + WoodcutDraw.hash01(j, 97)), 1.0)
				var x := r.position.x + w * (lane + 0.5) + (WoodcutDraw.hash01(j, 101) - 0.5) * w * 0.8
				var y := r.position.y + 8.0 - ph * 46.0
				ci.draw_rect(Rect2(x, y, 2.0, 2.0 + 3.0 * WoodcutDraw.hash01(j, 103)), Color(1.0, 0.6 + 0.35 * WoodcutDraw.hash01(j, 107), 0.27, (0.9 - 0.8 * ph)))
	var i := 0
	while i < _bursts.size():
		var b: Array = _bursts[i]
		var age := _clock - float(b[2])
		var pos: Vector2 = b[0]
		if FireSkin.draw_burst(ci, project(pos), str(b[1]), age, upright_scale(pos.y)):
			i += 1
		else:
			_bursts.remove_at(i)


## The hit line across the whole width, a bronze receptor on each lane.
func _draw_hit_line() -> void:
	var xs := []
	var lit := []
	for lane in 3:
		xs.append(project(lane_center(lane)).x)
		lit.append(_lane_glow(lane))
	var hl := LaneSkin.hit_line_y(field_rect())
	var y := project(Vector2(0.0, hl)).y
	var span := _screen_span()
	FireSkin.draw_hit_line(self, span.x, span.y, y, xs, 0.33 * FireSkin.REF_LANE * upright_scale(hl), lit, clampf(beat_pulse, 0.0, 1.0))


## The whole screen's width in this control's coordinates (x from, x to): the hit line runs edge to
## edge even where the lanes are narrower than the screen (tablets).
func _screen_span() -> Vector2:
	if not is_inside_tree():
		return Vector2(0.0, size.x)
	var inv := get_global_transform().affine_inverse()
	var vr := get_viewport_rect()
	return Vector2((inv * vr.position).x, (inv * vr.end).x)


## Early/late chevrons over the bursts that carry a side.
func _draw_chevrons() -> void:
	for b in _bursts:
		var q: String = b[1]
		var side: String = b[3] if q != "early" and q != "late" else q
		if side != "":
			_draw_chevron(self, project(b[0]), side, _clock - float(b[2]))


## Timing ticks on the note axis: each hit leaves a short dash at both edges of its lane, above the
## hit line when early (where the note still was), below when late, cool or warm, fading out. Hits
## inside Core's dead zone sit on the line in bone. The dashes stay at the lane edges, clear of the
## judgement word in the middle.
func _draw_timing_ticks(ci: CanvasItem, field: Rect2) -> void:
	if _offsets.is_empty():
		return
	var hl := LaneSkin.hit_line_y(field)
	var reach := minf((field.end.y - hl) * 0.9, 64.0)
	var span := 0.12
	var rects := LaneSkin.lane_rects(field)
	for o in _offsets:
		var age := _clock - float(o[1])
		if age > TICK_TIME:
			continue
		var off := float(o[0])
		var side := UIKit.side_of(off)
		var col := Palette.BONE if side == "" else UIKit.side_color(side)
		var a := clampf(1.0 - age / TICK_TIME, 0.0, 1.0)
		var y := hl + clampf(off / span, -1.0, 1.0) * reach
		var r: Rect2 = rects[clampi(int(o[2]), 0, 2)]
		var dash := minf(r.size.x * 0.14, 34.0)
		for x0 in [r.position.x + 6.0, r.end.x - 6.0 - dash]:
			ci.draw_line(Vector2(x0, y), Vector2(x0 + dash, y), Color(Palette.INK, a * 0.8), 9.0)
			ci.draw_line(Vector2(x0, y), Vector2(x0 + dash, y), Color(col, a), 5.0)


## The step ticks: a bold chevron at both edges of the lane, pointing up and cool above the hit line
## for early (where the note still was), down and warm below it for late, on an ink outline. The
## lane's middle stays clear for the judgement word. They fade out over STEP_TICK_TIME.
func _draw_step_ticks(ci: CanvasItem, field: Rect2) -> void:
	if _step_ticks.is_empty():
		return
	var hl := LaneSkin.hit_line_y(field)
	var rects := LaneSkin.lane_rects(field)
	var i := 0
	while i < _step_ticks.size():
		var k: Array = _step_ticks[i]
		var age := _clock - float(k[2])
		if age > STEP_TICK_TIME:
			_step_ticks.remove_at(i)
			continue
		i += 1
		var a := clampf(1.0 - age / STEP_TICK_TIME, 0.0, 1.0)
		var side := str(k[1])
		var d := -1.0 if side == "early" else 1.0
		var r: Rect2 = rects[clampi(int(k[0]), 0, 2)]
		var half := minf(r.size.x * 0.09, 20.0)
		var inset := half + 14.0
		var y := hl + d * 30.0
		var col := UIKit.side_color(side)
		for cx in [r.position.x + inset, r.end.x - inset]:
			var tip := Vector2(cx, y + d * half * 0.8)
			var pts := PackedVector2Array([Vector2(cx - half, y - d * half * 0.2), tip, Vector2(cx + half, y - d * half * 0.2)])
			ci.draw_polyline(pts, Color(Palette.INK, a * 0.9), 16.0, true)
			ci.draw_polyline(pts, Color(col, a), 9.0, true)


## The early/late chevron over a burst: up and cool above the hit for early, down and warm below it
## for late, cut out of an ink outline so it reads on any lane.
func _draw_chevron(ci: CanvasItem, pos: Vector2, side: String, age: float) -> void:
	var t := clampf(age / LaneSkin.BURST_TIME, 0.0, 1.0)
	var a := minf(1.0, pow(1.0 - t, 1.2) * 1.3)
	var d := -1.0 if side == "early" else 1.0
	var cp := pos + Vector2(0.0, d * (30.0 + 26.0 * (1.0 - pow(1.0 - t, 3.0))))
	var chev := PackedVector2Array([cp + Vector2(-26.0, -d * 15.0), cp, cp + Vector2(26.0, -d * 15.0)])
	ci.draw_polyline(chev, Color(Palette.INK, a), 17.0, true)
	ci.draw_polyline(chev, Color(UIKit.side_color(side), a), 9.0, true)


func _draw_marks() -> void:
	var i := 0
	var r := buttons_rect()
	var w := r.size.x / 3.0
	while i < _marks.size():
		var m: Array = _marks[i]
		var age := _clock - float(m[2])
		if age > MARK_TIME:
			_marks.remove_at(i)
			continue
		i += 1
		var a := clampf(1.0 - age / MARK_TIME, 0.0, 1.0)
		var lane := clampi(int(m[1]), 0, 2)
		var c := Vector2(r.position.x + w * (lane + 0.5), r.get_center().y)
		match str(m[0]):
			"wrong":
				var s := minf(w, r.size.y) * 0.26
				for dd in [Vector2(s, s), Vector2(s, -s)]:
					draw_line(c - dd, c + dd, Color(Palette.INK, a), 26.0)
					draw_line(c - dd, c + dd, Color("#e2574a", a), 14.0)
			"faint":
				var p := project(lane_center(lane))
				draw_arc(p, 40.0, 0.0, TAU, 32, Color(Palette.ASH, a * 0.45), 4.0)
			"rope":
				var y := r.position.y + 14.0
				draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y), Color(Palette.ROPE_DARK, a), 16.0)
				draw_line(Vector2(r.position.x + 20.0, y), Vector2(r.end.x - 20.0, y), Color(Palette.ROPE, a), 9.0)
				draw_circle(Vector2(c.x, y), 16.0, Color(Palette.ROPE, a))


## The notes on screen now, far to near: [note, y, y_end] in flat field coordinates.
func _notes_shown(field: Rect2) -> Array:
	var out := []
	var t := song_time
	var pps := _px_per_s()
	var horizon := t + (field.size.y / pps)
	var notes := session.notes
	for i in range(_first, notes.size()):
		var n := notes[i]
		if n.t > horizon:
			break
		if _gone(n, t):
			continue
		var y := LaneSkin.note_y(field, n.t - t, pps)
		var y_end := LaneSkin.note_y(field, n.end_t - t, pps) if n.kind == Note.Kind.HOLD or n.kind == Note.Kind.REST else y
		out.append([n, y, y_end])
	return out


## What lies flat on the road: hold sashes, bell bars, stand-still bands.
func _draw_flat_notes(ci: CanvasItem, field: Rect2) -> void:
	var lanes := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	for e in _notes_shown(field):
		var n: Note = e[0]
		var y: float = e[1]
		match n.kind:
			Note.Kind.HOLD:
				if not n.finished and not (n.done and not n.holding):
					var head := minf(y, hl) if n.holding else y
					FireSkin.draw_sash(ci, lanes[n.lane], head, e[2], n.holding, field)
			Note.Kind.BELL, Note.Kind.RING:
				if not n.done:
					FireSkin.draw_bar(ci, field, y, n.up)
			Note.Kind.REST:
				if not n.finished:
					FireSkin.draw_band(ci, field, e[2], y)


## What stands on the road, upright and scaled with it: gems (steps, hold heads), hold rings, bell
## badges, the rope, and the stand-still label. Far notes fade in out of the fire's haze.
func _draw_upright() -> void:
	var field := field_rect()
	field.position = Vector2.ZERO
	var lanes := LaneSkin.lane_rects(field)
	var hl := LaneSkin.hit_line_y(field)
	var rests: Array = []
	var taken: Array[float] = []
	var shown := _notes_shown(field)
	for e in shown:
		var n: Note = e[0]
		if n.kind != Note.Kind.REST and not n.done:
			taken.append(float(e[1]))
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		var a := _haze(y, field)
		match n.kind:
			Note.Kind.STEP:
				if not n.done:
					if n.heal:
						FireSkin.draw_heal_gem(self, project(Vector2(lanes[n.lane].get_center().x, y)), upright_scale(y), a, _clock)
					else:
						FireSkin.draw_gem(self, project(Vector2(lanes[n.lane].get_center().x, y)), upright_scale(y), n.call, a, _off_beat(n))
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var tail: float = e[2]
				var cx := lanes[n.lane].get_center().x
				if tail > -20.0:
					FireSkin.draw_hold_ring(self, project(Vector2(cx, tail)), upright_scale(tail), _haze(tail, field))
				var head := minf(y, hl) if n.holding else y
				FireSkin.draw_gem(self, project(Vector2(cx, head)), upright_scale(head), false, a)
			Note.Kind.BELL:
				if not n.done:
					_bell_words(field, y, n.up, a)
					FireSkin.draw_badge(self, project(Vector2(field.get_center().x, y)), upright_scale(y), a)
			Note.Kind.RING:
				if not n.done:
					var sc := upright_scale(y)
					FireSkin.draw_badge(self, project(Vector2(field.get_center().x, y)), sc, a)
					var p := project(Vector2(lanes[n.lane].get_center().x, y))
					draw_polyline(FireSkin.ellipse_pts(p, 88.0 * sc, 36.0 * sc), Color(FireSkin.CRIMSON, a), maxf(3.0, 7.0 * sc), true)
					FireSkin.draw_gem(self, p, sc, false, a)
			Note.Kind.SWIPE:
				if not n.done:
					FireSkin.draw_rope(self, project(Vector2(field.get_center().x, y)), road_scale(y) * field.size.x, n.dir, a)
			Note.Kind.REST:
				if not n.finished:
					rests.append([e[2], y])
	for r in rests:
		_rest_words(field, r[0], r[1], taken)


## "Raise … Bells" (or "Lower … Bells") carved into the bell bar either side of its badge, upright,
## sized to the bar's height on screen.
func _bell_words(field: Rect2, y: float, up: bool, a: float) -> void:
	var w := road_scale(y)
	var bar_h := float((FireCells.CELLS["bar_up"][0] as Vector2).y) * 0.72 * w * w / TOP_W if _road_on() else 65.0
	var fs := int(round(minf(34.0 * w, bar_h * 0.5)))
	if fs < 9:
		return
	var font := FireSkin.carved_font(0.3)
	for sd in [-1.0, 1.0]:
		var text := tr("lane_bells") if sd > 0.0 else tr("lane_raise" if up else "lane_lower")
		var p := project(Vector2(field.get_center().x + sd * field.size.x * 0.21, y))
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(p.x - tw * 0.5, p.y + fs * 0.32)
		draw_string(font, pos + Vector2(0.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.9, 0.6, 0.35 * a))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.16, 0.07, 0.016, a))


## Whether a note falls between the beats (drawn smaller, in a dashed ring).
func _off_beat(n: Note) -> bool:
	if spb <= 0.0 or beat <= -999.0:
		return false
	var nb := beat + (n.t - song_time) / spb
	var fr := fposmod(nb, 1.0)
	return fr > 0.12 and fr < 0.88


## Notes emerge from the fire's haze at the far end of the road.
func _haze(y: float, field: Rect2) -> float:
	return clampf(y / (field.size.y * 0.07), 0.0, 1.0)


## Names a stand-still band on the road, so a rest reads as an instruction and not as empty space.
## The label goes in the band's visible part, at the place farthest from every note or bell bar
## crossing it, upright on screen in a framed tag.
func _rest_words(field: Rect2, y_a: float, y_b: float, taken: Array[float] = []) -> void:
	var top := maxf(minf(y_a, y_b), field.position.y)
	var bottom := minf(maxf(y_a, y_b), LaneSkin.hit_line_y(field))
	if bottom - top < 40.0:
		return
	var best_y := (top + bottom) * 0.5
	var best_gap := -INF
	var cy := top + 22.0
	while cy <= bottom - 22.0:
		var gap := INF
		for ty in taken:
			gap = minf(gap, absf(ty - cy))
		if gap > best_gap + 0.5:
			best_gap = gap
			best_y = cy
		cy += 6.0
	var font := FireSkin.carved_font(0.3)
	var sc := clampf(road_scale(best_y), 0.6, 1.0)
	var fs := int(round(30.0 * sc))
	var text := tr("lane_still")
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := project(Vector2(field.get_center().x, best_y))
	var half := fs * 0.72
	var back := Rect2(p.x - w * 0.5 - 14.0 * sc, p.y - half, w + 28.0 * sc, half * 2.0)
	draw_rect(back, Color("#10132e"))
	draw_rect(back, FireSkin.STILL_BLUE, false, 2.0)
	var pos := Vector2(p.x - w * 0.5, p.y + fs * 0.36)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#eef2ff"))
	_rest_label_y = best_y


var _rest_label_y := NAN   ## last rest label centre (tests)


## A note is gone once it is judged (or over) and has passed the bottom of the field.
func _gone(n: Note, t: float) -> bool:
	match n.kind:
		Note.Kind.HOLD, Note.Kind.REST:
			return n.finished or (n.done and not n.holding) or n.end_t < t - 0.5
	return n.done or n.t < t - 0.5


func _draw_buttons() -> void:
	var r := buttons_rect()
	# The panel under the plates, across the whole screen: near-black, with a thin ember line and the
	# hit line's glow spilling over its top edge.
	var span := _screen_span()
	var pr := Rect2(span.x, r.position.y, span.y - span.x, r.size.y + 400.0)
	draw_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
		PackedColorArray([Color("#0b0712"), Color("#0b0712"), Color("#050309"), Color("#050309")]))
	draw_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), Vector2(pr.end.x, pr.position.y + 40.0), Vector2(pr.position.x, pr.position.y + 40.0)]),
		PackedColorArray([Color(1.0, 0.47, 0.16, 0.3), Color(1.0, 0.47, 0.16, 0.3), Color(1.0, 0.47, 0.16, 0.0), Color(1.0, 0.47, 0.16, 0.0)]))
	draw_line(pr.position, Vector2(pr.end.x, pr.position.y), Color(1.0, 0.55, 0.2, 0.55), 1.5)
	var w := r.size.x / 3.0
	var pad := 10.0
	for lane in 3:
		var br := Rect2(r.position.x + w * lane + pad, r.position.y + pad, w - pad * 2.0, r.size.y - pad * 2.0)
		FireSkin.draw_button(self, br, lane, _button_state(lane))


func _button_state(lane: int) -> String:
	if _clock - _flash[lane] < FLASH_TIME:
		return _flash_kind[lane]
	if _is_pressed(lane):
		return "pressed"
	if session != null and _cued(lane):
		return "cued"
	return "idle"


func _is_pressed(lane: int) -> bool:
	if router != null and router.is_pressed(lane):
		return true
	return _clock - _auto_pressed[lane] < 0.08


func _cued(lane: int) -> bool:
	var notes := session.notes
	for i in range(_first, notes.size()):
		var n := notes[i]
		if n.t > song_time + CUE_TIME:
			return false
		if n.lane == lane and not n.done and n.t >= song_time - 0.05:
			return true
	return false
