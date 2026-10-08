class_name LaneView
extends Control
## The road of three lanes and the three step buttons, in the "Fire Night" look (Art's FireSkin; LaneSkin
## keeps the layout: lane rects, hit line, note positions). The play screen feeds it
## the session and the song time each frame; hits add bursts and button flashes the same frame the
## input arrives (flash() / burst() are called from the input signal handlers, then queue_redraw()).

const BUTTONS_H := 264.0        ## height of the button row
const LOOKAHEAD := 1.5          ## seconds of notes visible at note speed 1.0
const FLASH_TIME := 0.14
const CUE_TIME := 0.22          ## a button is "cued" when its next note is this close
const MARK_TIME := 0.4          ## wrong-lane and stomp marks
const TICK_TIME := 1.6          ## timing ticks fade over this long
const STEP_TICK_TIME := 0.3     ## the early/late tick on a step hit fades over this long
const LOCK_IN := 0.12           ## a padlock drops onto each ring this fast when mashing locks the buttons
const LOCK_OUT := 0.25          ## and springs open and fades this long when the lock ends
const LOCK_SHAKE := 0.2         ## a press while locked rattles that ring's padlock this long
## The padlock, in art px: the shackle over the body. o outline, s/S steel, b/h/d brass (face,
## light, shade), k keyhole.
const LOCK_SHACKLE: Array[String] = [
	"...ooooo...",
	"..osSSSso..",
	".oso...oso.",
	".oso...oso.",
	".oso...oso.",
]
const LOCK_BODY: Array[String] = [
	"ooooooooooo",
	"ohhhhhhhhho",
	"ohbbbbbbbdo",
	"ohbbkkkbbdo",
	"ohbbkkkbbdo",
	"ohbbbkbbbdo",
	"odddddddddo",
	"ooooooooooo",
]

var session: Session
var song_time := 0.0
var note_speed := 1.0
var router: InputRouter          ## for pressed state; null in autoplay
var show_buttons := true
var beat_pulse := 0.0

var _bursts: Array = []          ## [pos: Vector2, quality: String, t0: float]
var _stomps: Array = []          ## stomp hits in flight: [lane, both, t0]
var _strikes: Array = []         ## bells rung on time, in flight: [up, quality, chain, t0]
var _pulses: Array = []          ## light running up a lane's rails from an on-time hit: [lane, colour, t0, strength]
const PULSE_TIME := 0.5
var _flash: Array[float] = [-9.0, -9.0, -9.0]
var _flash_kind: Array[String] = ["hit", "hit", "hit"]
var _auto_pressed: Array[float] = [-9.0, -9.0, -9.0]
var _first := 0                  ## first note that may still be drawn
var _clock := 0.0                ## real seconds, for burst ages while paused
var _offsets: Array = []         ## [offset s, time added, lane] of recent hits, for the timing ticks
var _step_ticks: Array = []      ## [lane, side, time added]: the early/late tick of a step hit
var _lock_on := false            ## the session's buttons are locked (mashing)
var _lock_t0 := -9.0             ## _clock when the lock came on, or when it ended (for the fade)
var _lock_tap: Array[float] = [-9.0, -9.0, -9.0]   ## _clock of the last press on each locked ring
var _marks: Array = []           ## [kind, lane, time]: "wrong" X on a pressed button, "faint" ring on
                                 ## the note it was meant for, "stomp" / "stomp1" on a stomped button


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
	if street != null:
		# on the street: in the gap between the hit rings and the buttons
		var hy := hit_line_screen_y()
		return Vector2(project(Vector2(x, hl)).x, (hy + buttons_rect().position.y) * 0.5 + 12.0)
	return project(Vector2(x, hl + (f.end.y - hl) * 0.5))


func reset() -> void:
	_first = 0
	_bursts.clear()
	_stomps.clear()
	_strikes.clear()
	_pulses.clear()
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
	if street != null:
		street.flash(street.flat_to_local(pos), 1.0 if quality != "heal" else 0.8)
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


## A stomp was judged (handoff/stomp.md): a full stomp throws a white flash, gold shock rings, dust
## and sparks out of the hit line and stamps two prints on the button; one thumb only is a dull
## single ring and one dim print.
func stomp_hit(lane: int, _judgement: String, both: bool) -> void:
	_marks.append(["stomp" if both else "stomp1", clampi(lane, 0, 2), _clock])
	_stomps.append([clampi(lane, 0, 2), both, _clock])
	if street != null:
		var at := street.flat_to_local(Vector2(lane_center(clampi(lane, 0, 2)).x, LaneSkin.hit_line_y(field_rect())))
		street.flash(at, 1.8 if both else 0.9)
	queue_redraw()


## A bell rung on time (Perfect or Good): the strap at the hit line strikes (StreetSkin.bell_strike)
## and the street lights up under all three lanes. chain = on-time bells in a row, for its size.
func bell_hit(up: bool, quality: String, chain := 1) -> void:
	_strikes.append([up, quality, chain, _clock])
	if _strikes.size() > 4:
		_strikes.pop_front()
	if street != null:
		var hl := LaneSkin.hit_line_y(field_rect())
		for lane in 3:
			street.flash(street.flat_to_local(Vector2(lane_center(lane).x, hl)), (1.1 if quality == "perfect" else 0.7))
	queue_redraw()


## A note hit on time sends light up its lane: a bright stretch runs along both of the lane's rails
## from the hit line to the fire, in the note's colour (strength 1 a Perfect, less a Good; a held hold's
## finish runs brighter and longer).
func lane_pulse(lane: int, col: Color, strength := 1.0) -> void:
	_pulses.append([clampi(lane, 0, 2), col, _clock, strength])
	if _pulses.size() > 8:
		_pulses.pop_front()


## Lanes with light running up them right now, for tests.
func pulses_shown() -> Array[int]:
	var out: Array[int] = []
	for p in _pulses:
		if _clock - float(p[2]) < PULSE_TIME:
			out.append(int(p[0]))
	return out


func _draw_pulses(field: Rect2) -> void:
	var hl := LaneSkin.hit_line_y(field)
	var w := field.size.x / 3.0
	var i := 0
	while i < _pulses.size():
		var p: Array = _pulses[i]
		var k := (_clock - float(p[2])) / (PULSE_TIME * (1.0 + 0.3 * (float(p[3]) - 1.0)))
		if k >= 1.0:
			_pulses.remove_at(i)
			continue
		i += 1
		if k < 0.0:
			continue
		var g := 1.0 - pow(1.0 - k, 1.6)
		var head := hl * (1.0 - g)
		var tail := minf(hl, head + hl * 0.22 * (1.0 - k * 0.5))
		var col: Color = p[1]
		var c := Color.WHITE.lerp(col, clampf(k * 6.0, 0.0, 1.0))
		c.a = clampf((1.0 - k) * 1.4, 0.0, 1.0) * clampf(float(p[3]), 0.3, 1.0)
		var lane := int(p[0])
		for x in [w * float(lane) + w * 0.04, w * float(lane + 1) - w * 0.04]:
			var a := project(Vector2(x, tail))
			var b := project(Vector2(x, head))
			draw_line(a, b, c, maxf(PxArt.PX, PxArt.PX * 3.0 * road_scale(tail) * (1.0 - 0.6 * k)))


## Bell strikes showing right now ("up"/"down":quality), for tests.
func strikes_shown() -> Array[String]:
	var out: Array[String] = []
	for st in _strikes:
		if _clock - float(st[3]) < StreetSkin.STRIKE_TIME:
			out.append("%s:%s" % ["up" if bool(st[0]) else "down", st[1]])
	return out


## A press while the buttons are locked: that ring's padlock rattles.
func locked_tap(lane: int) -> void:
	_lock_tap[clampi(lane, 0, 2)] = _clock
	queue_redraw()


## Whether padlocks are on the rings right now (fully or fading out), for tests.
func locks_shown() -> bool:
	return _lock_on or _clock - _lock_t0 < LOCK_OUT


## Marks drawn right now (kind:lane), for tests.
func marks_shown() -> Array[String]:
	var out: Array[String] = []
	for m in _marks:
		if _clock - float(m[2]) < MARK_TIME:
			out.append("%s:%d" % [m[0], m[1]])
	return out


func _process(delta: float) -> void:
	_clock += delta
	var locked := session != null and session.is_locked(song_time)
	if locked != _lock_on:
		_lock_on = locked
		_lock_t0 = _clock
	if session != null:
		while _first < session.notes.size() and _gone(session.notes[_first], song_time):
			_first += 1
	_update_road()
	queue_redraw()
	for c in [_surface, _under, _fx]:
		if c != null:
			c.queue_redraw()


## The road shader's light: the beat's envelope, a pressed lane, the beads' spacing, a low fire.
func _update_road() -> void:
	if _road == null:
		return
	var m := _road.material as ShaderMaterial
	var f := field_rect()
	m.set_shader_parameter("field", f.size)
	m.set_shader_parameter("hl", LaneSkin.hit_line_y(Rect2(Vector2.ZERO, f.size)))
	m.set_shader_parameter("env", beat_env())
	m.set_shader_parameter("dim", fire_dim)
	m.set_shader_parameter("lane_glow", Vector3(_lane_glow(0), _lane_glow(1), _lane_glow(2)))
	m.set_shader_parameter("beat", beat)
	m.set_shader_parameter("beat_px", spb * _px_per_s() if spb > 0.0 else 0.0)
	m.set_shader_parameter("flash", _hit_flash())


## The beat's light envelope for the road and the hit line (a third of it with reduced motion).
func beat_env() -> float:
	if beat <= -999.0:
		return 0.0
	return PxArt.beat_env(beat, 0.4, 0.65, 0.0) * (0.35 if UIKit.reduced_motion() else 1.0)


## 0..1 right after a good hit: the rails flare with it.
func _hit_flash() -> float:
	var best := 0.0
	for lane in 3:
		if _flash_kind[lane] == "hit":
			best = maxf(best, clampf(1.0 - (_clock - _flash[lane]) / 0.18, 0.0, 1.0))
	return best


func _px_per_s() -> float:
	var f := field_rect()
	return (LaneSkin.hit_line_y(f) - f.position.y) / (LOOKAHEAD / maxf(note_speed, 0.1))


## Flat y of an event at song time t: the notes slide smoothly down the road.
func event_y(field: Rect2, t: float, pps: float) -> float:
	return LaneSkin.note_y(field, t - song_time, pps)


## Screen drawing on top of the road: the hit line and its receptors, then everything standing on the
## road (gems, rings, badges, the rope, labels), then the buttons.
static var draw_usec := 0         ## time spent drawing the street lanes, summed (for tests/bench.gd)
static var draw_count := 0


func _draw() -> void:
	if street != null:
		_street_map(true)
		var t0 := Time.get_ticks_usec()
		_draw_street()
		draw_usec += Time.get_ticks_usec() - t0
		draw_count += 1
		return
	if not _road_on():
		_draw_field(self)
	_draw_hit_line()
	if session != null:
		_draw_upright()
		_draw_locks()
	_draw_chevrons()
	if show_buttons:
		_draw_buttons()
		_draw_marks()


## Things lying flat on the road, in flat field coordinates: drawn straight onto this control, or into
## the road's viewport to be laid back in perspective. Sashes, bell bars, stand-still bands, ticks.
func _draw_field(ci: CanvasItem) -> void:
	var field := field_rect()
	field.position = Vector2.ZERO
	if not _road_on():
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
## The road in pixel art. Each art pixel (PxArt.PX screen px, on the grid anchored at the far end)
## finds its place on the flat road, and draws: the setts in courses that shrink toward the fire
## (mortar rows and joints found by whether a seam falls inside the pixel, so no seam is ever lost
## or doubled), the four gold rails (the road's edges and the two lane dividers) with beads riding
## the outer rails down to the hit line on every beat, and whatever lies flat on the road (the
## flat field viewport: sashes, bands, ticks). Light (the fire at the far end, the rails, the hit
## line, a pressed lane, the beat) picks each pixel's colour from the palette table road_lut.png,
## with an ordered dither between levels: no blending, no off-palette colour.
const ROAD_SHADER := """
shader_type canvas_item;
uniform sampler2D lut : filter_nearest;
uniform sampler2D flat_tex : filter_nearest;
uniform float top_w = 0.42;
uniform vec2 field = vec2(720.0, 1060.0);
uniform float px = 3.0;
uniform float hl = 954.0;
uniform float env = 0.0;
uniform float dim = 0.0;
uniform vec3 lane_glow = vec3(0.0);
uniform float beat = -1000.0;
uniform float beat_px = 0.0;
uniform float flash = 0.0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float b[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[y * 4 + x] + 0.5) / 16.0;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec4 lut_th(int row, float light, float th) {
	float lv = clamp(light, 0.0, 1.0) * 7.99 + (th - 0.5) * 0.8;
	int i = clamp(int(floor(lv)), 0, 7);
	return texelFetch(lut, ivec2(i, row), 0);
}
vec4 lut_at(int row, float light, vec2 cell) {
	return lut_th(row, light, bayer4(cell));
}
// course number at screen height y: courses 4 art px tall at the far end, 11 at the near end
float course(float y) {
	float hf = 4.0 * px;
	float hn = 11.0 * px;
	float h = hf + (hn - hf) * clamp(y / field.y, 0.0, 1.2);
	return field.y / (hn - hf) * log(h / hf);
}
vec4 road(vec2 UVp) {
	vec2 local = UVp * field;
	vec2 o = vec2(field.x * 0.5, 0.0);
	vec2 cell = floor((local - o) / px);
	vec2 c0 = cell * px + o;
	vec2 cc = c0 + px * 0.5;
	float w = top_w + (1.0 - top_w) * clamp(cc.y / field.y, 0.0, 1.0);
	float half_w = field.x * 0.5;
	float fx = half_w + (cc.x - half_w) / w;
	float fxl = half_w + (c0.x - half_w) / w;
	float fxr = half_w + (c0.x + px - half_w) / w;
	float v = (1.0 / top_w - 1.0 / w) / (1.0 / top_w - 1.0);
	float fy = v * field.y;
	float u = fx / field.x;
	// the kerbs (the road's edges: a gold inlay between two kerb stones, 1 art px far, 2 near) and
	// the lane dividers (one pale stone line)
	float core_r = px * 0.5 + px * 0.5 * smoothstep(0.62, 0.95, w);
	float div_d = 1e6;
	float outer_d = 1e6;
	for (int i = 0; i < 4; i++) {
		float rx = half_w + (field.x * float(i) / 3.0 - half_w) * w;
		float d = abs(cc.x - rx);
		if (i == 0 || i == 3) { outer_d = min(outer_d, d); } else { div_d = min(div_d, d); }
	}
	bool inside = u >= 0.0 && u <= 1.0;
	if (!inside && outer_d >= core_r + px * 1.0) {
		return vec4(0.0);
	}
	float pulse = max(env, 0.0);
	vec2 flat_uv = vec2(clamp(u, 0.0, 1.0), clamp(fy / field.y, 0.0, 1.0));
	if (outer_d < core_r) {
		return lut_th(4, 0.25 + 0.4 * pulse + 0.3 * flash - 0.2 * dim, 0.5);
	}
	if (outer_d < core_r + px * (1.0 + step(0.7, w))) {
		return lut_th(5, 0.3 + 0.3 * pulse - 0.2 * dim + 0.3 * clamp(1.0 - fy / (field.y * 0.3), 0.0, 1.0), 0.5);
	}
	if (!inside) {
		return lut_at(6, 0.2 + 0.6 * clamp(1.0 - fy / (field.y * 0.35), 0.0, 1.0), cell);
	}
	// what lies flat on the road (drawn in the flat viewport), whole pixels only
	vec4 flat_c = texture(flat_tex, flat_uv);
	if (flat_c.a > 0.5) {
		return vec4(flat_c.rgb, 1.0);
	}
	// setts: a mortar row where a course seam falls inside this pixel's rows; a joint where a sett's
	// end falls inside its columns (running bond: every other course shifted half a sett)
	float n0 = course(c0.y);
	float n1 = course(c0.y + px);
	bool seam = floor(n0) != floor(n1) || cell.y <= 0.0;
	float n = floor(course(cc.y));
	float bw = field.x / 12.0;
	float off = mod(n, 2.0) * bw * 0.5;
	bool joint = floor((fxl - off) / bw) != floor((fxr - off) / bw);
	vec2 id = vec2(floor((fx - off) / bw), n);
	// light: the fire's glow over the far part of the road, the rails' glow, the hit line's, a pressed lane
	float fd = length(vec2((fx - half_w) / (field.x * 0.7), fy / (field.y * (0.46 + 0.08 * pulse))));
	float light = 0.19;
	light += pow(clamp(1.0 - fd, 0.0, 1.0), 1.3) * (0.62 + 0.25 * pulse) * (1.0 - 0.55 * dim);
	light += clamp(1.0 - (outer_d - core_r - px) / (px * (2.0 + 3.0 * w)), 0.0, 1.0) * (0.12 + 0.12 * pulse + 0.1 * flash);
	light += clamp(1.0 - abs(fy - hl) / (field.y * 0.03), 0.0, 1.0) * (0.1 + 0.1 * pulse);
	int lane = clamp(int(floor(u * 3.0)), 0, 2);
	float lg = lane == 0 ? lane_glow.x : (lane == 1 ? lane_glow.y : lane_glow.z);
	light += lg * clamp(1.0 - (hl - fy) / (field.y * 0.22), 0.0, 1.0) * step(fy, hl + field.y * 0.05) * 0.4;
	if (div_d < px * 0.5 + px * 0.5 * step(0.8, w)) {
		return lut_th(7, light, 0.5);
	}
	// the beats: a thin line across the lanes where a beat falls inside this pixel's rows, moving with
	// the notes to the hit line (the first beat of each bar of 4 a little brighter)
	if (beat_px > 0.0 && beat > -999.0 && fy <= hl + 0.5) {
		float v0 = (1.0 / top_w - 1.0 / (top_w + (1.0 - top_w) * clamp(c0.y / field.y, 0.0, 1.0))) / (1.0 / top_w - 1.0);
		float v1 = (1.0 / top_w - 1.0 / (top_w + (1.0 - top_w) * clamp((c0.y + px) / field.y, 0.0, 1.0))) / (1.0 / top_w - 1.0);
		float ph0 = beat + (hl - v0 * field.y) / beat_px;
		float ph1 = beat + (hl - v1 * field.y) / beat_px;
		if (floor(ph0) != floor(ph1) && fy > field.y * 0.06) {
			float bn = floor(max(ph0, ph1));
			return lut_th(mod(bn, 4.0) < 0.5 ? 9 : 8, light, 0.5);
		}
	}
	// far up the road the joints fade into the fire's haze (a wall of crisp bricks otherwise):
	// vertical joints thin out first, then the course lines
	float nearness = clamp(fy / field.y, 0.0, 1.0);
	if (joint && !seam && hash(id + 3.3) > smoothstep(0.08, 0.5, nearness)) {
		joint = false;
	}
	if (seam && nearness < 0.3) {
		// a soft course line: the worn tone, not the mortar
		return lut_th(3, light, 0.5);
	}
	if (seam || joint) {
		float mh = hash(cell * 0.73 + 5.1);
		if (mh < 0.07 + 0.08 * abs(u - 0.5) * 2.0) {
			return lut_th(3, light, 0.5);
		} else {
			return lut_th(0, light, 0.5);
		}
	}
	// each sett is a rounded cobble: its corners fall into the mortar, its top catches the fire's
	// light from up the road, its lower lip is in shadow; one colour per sett between, chosen by the
	// sett's own threshold, not a checker
	float fv = fract(course(cc.y));
	float fh = fract((fx - off) / bw);
	if ((fh < 0.06 || fh > 0.94) && (fv < 0.2 || fv > 0.82)) {
		return lut_th(0, light, 0.5);
	}
	if (fv < 0.24) {
		return lut_th(10, light, 0.5);
	}
	if (fv > 0.8) {
		return lut_th(3, light, 0.5);
	}
	float tone = hash(id + 0.37);
	return lut_th(tone < 0.3 ? 2 : 1, light, 0.15 + 0.7 * hash(id + 1.7));
}
void fragment() {
	COLOR = road(UV);
}
"""
## Road surface colours from the far end (by the fire) to the buttons.
const ROAD_STOPS := [[0.0, Color("#2a1c22")], [0.25, Color("#1a1520")], [0.6, Color("#131018")], [1.0, Color("#0c0a12")]]

var perspective := true          ## false: the flat lanes (the Piazza hides them anyway; tests may flatten)
## The street picture (set before this enters the tree). With it, the road is the picture's own and
## the lanes follow its painted lines: project() asks the street where a flat point lies, and this
## control draws the notes, the hit line, the bursts and the buttons over it (_draw_street).
var street: StreetBackdrop
## The pixel look (PixelFilter over the screen): the buttons are drawn as pixel art on its grid.
var pixel := false
var beat := -1000.0              ## the song's beat now (fractional), for the beads on the rails
var spb := 0.0                   ## seconds per beat (0: no beads)
var fire_dim := 0.0              ## 0..1 the fire burns low (health): the road's light dims with it
var _vp: SubViewport
var _flat: Control
var _road: TextureRect
var _surface: Control            ## the road's stone, dividers and far-end haze (behind everything)
var _under: Control              ## additive, under the notes: rail glow, beads, the hit line's glow
var _fx: Control                 ## additive, over the notes: hit bursts


func _ready() -> void:
	if street != null:
		perspective = false
	if street != null and pixel and not OS.has_environment("NO_ATLAS"):
		# the notes are painted once into a sheet and stamped from it: drawing them each frame was the lag
		var at := NoteAtlas.new(self)
		add_child(at)
		StreetSkin.atlas = at
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
		mat.set_shader_parameter("lut", PxArt.field("road_lut"))
		mat.set_shader_parameter("flat_tex", _vp.get_texture())
		mat.set_shader_parameter("px", PxArt.PX)
		_road.material = mat
		_road.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	_fx.show_behind_parent = true
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
	if street != null:
		_street_map()
		var c := _sm
		var y := StreetBackdrop.VANISH_Y + 1.0 / maxf(c[0] + (c[1] - c[0]) * flat_y / c[2], 0.00005)
		var r1: Vector2 = StreetBackdrop.RAILS[1]
		var r2: Vector2 = StreetBackdrop.RAILS[2]
		return (r2.x - r1.x + (r2.y - r1.y) * y) * c[5] * _sm_scale * 3.0 / c[3]
	if not _road_on():
		return 1.0
	var v := flat_y / maxf(field_rect().size.y, 1.0)
	return 1.0 / maxf(1.0 / TOP_W - v * (1.0 / TOP_W - 1.0), 0.05)


## Where a point of the flat field shows on screen (this control's coordinates).
func project(p: Vector2) -> Vector2:
	if street != null:
		# street.flat_to_local(p) through _from_street(), from numbers kept for the frame
		_street_map()
		var c := _sm
		var y := StreetBackdrop.VANISH_Y + 1.0 / maxf(c[0] + (c[1] - c[0]) * p.y / c[2], 0.00005)
		var u := p.x / c[3] * 3.0
		var i := clampi(int(floorf(u)), 0, 2)
		var ra: Vector2 = StreetBackdrop.RAILS[i]
		var rb: Vector2 = StreetBackdrop.RAILS[i + 1]
		var x := lerpf(ra.x + ra.y * y, rb.x + rb.y * y, u - float(i))
		var ys := y if y <= StreetBackdrop.STRETCH_FROM else StreetBackdrop.STRETCH_FROM + (y - StreetBackdrop.STRETCH_FROM) * c[6]
		return _sm_xf * Vector2(c[4] + x * c[5], ys * c[5])
	var f := field_rect()
	if not _road_on():
		return p
	var w := road_scale(p.y)
	var y := f.size.y * (w - TOP_W) / (1.0 - TOP_W)
	return f.position + Vector2(f.size.x * 0.5 + (p.x - f.size.x * 0.5) * w, y)


## The road's left and right edge on screen at screen height y (this control's coordinates).
func road_edges(y: float) -> Vector2:
	var f := field_rect()
	if street != null:
		# the flat depth that shows at screen height y (the projection keeps rows level)
		var lo := -f.size.y * 4.0
		var hi := f.size.y * 1.5
		for i in 40:
			var mid := (lo + hi) * 0.5
			if project(Vector2(0.0, mid)).y < y:
				lo = mid
			else:
				hi = mid
		var fy := (lo + hi) * 0.5
		return Vector2(project(Vector2(0.0, fy)).x, project(Vector2(f.size.x, fy)).x)
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
	if street != null:
		var a := project(Vector2(0.0, 0.0))
		var b := project(Vector2(f.size.x, 0.0))
		return Rect2(a.x, a.y, b.x - a.x, 0.0)
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
		if view.street != null:
			view._street_map(true)
		view.call(method, self)


## Behind the road (over the square and the figures beside it): when the fire burns low, the night
## closes in from the screen's sides in three stepped bands. The road itself is never covered.
func _draw_surface(ci: CanvasItem) -> void:
	if fire_dim <= 0.01 or street != null:
		return
	var span := _screen_span()
	var P := PxArt.PX
	var col := Color(PixelPalette.NIGHT[0], 0.26 * clampf(fire_dim, 0.0, 1.0))
	var top := 0.0
	var h := size.y
	for i in 3:
		var w := PxArt.snap(float(i + 1) * 12.0 * P)
		ci.draw_rect(Rect2(span.x, top, w, h), col)
		ci.draw_rect(Rect2(span.y - w, top, w, h), col)


## Under the notes, over the road (additive): the hit line's stepped glow on the stones.
func _draw_under(ci: CanvasItem) -> void:
	if street != null:
		return
	var span := _screen_span()
	FireSkin.draw_hit_glow(ci, span.x, span.y, hit_line_screen_y(), beat_env())


## Additive, over the notes: the hit bursts, upright at their projected place, and sparks thrown up
## from a pressed plate.
func _draw_fx(ci: CanvasItem) -> void:
	if street != null:
		# the bursts are drawn over the street in _draw_street; only let go of the ones that are over
		while not _bursts.is_empty() and _clock - float(_bursts[0][2]) > LaneSkin.BURST_TIME:
			_bursts.pop_front()
		while not _stomps.is_empty() and _clock - float(_stomps[0][2]) > 1.0:
			_stomps.pop_front()
		while not _strikes.is_empty() and _clock - float(_strikes[0][3]) > StreetSkin.STRIKE_TIME:
			_strikes.pop_front()
		while not _pulses.is_empty() and _clock - float(_pulses[0][2]) > PULSE_TIME * 1.5:
			_pulses.pop_front()
		return
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
				if ph > 0.85:
					continue
				var col: Color = PixelPalette.FIRE[7 - int(ph * 4.0)]
				ci.draw_rect(Rect2(PxArt.snap(x), PxArt.snap(y), PxArt.PX, PxArt.PX * (2.0 if ph < 0.3 else 1.0)), col)
	var i := 0
	while i < _bursts.size():
		var b: Array = _bursts[i]
		var age := _clock - float(b[2])
		var pos: Vector2 = b[0]
		var at := project(pos)
		if absf(pos.y - LaneSkin.hit_line_y(field_rect())) < 2.0:
			at.y = hit_line_screen_y()
		if FireSkin.draw_burst(ci, at, str(b[1]), age, upright_scale(pos.y)):
			i += 1
		else:
			_bursts.remove_at(i)
	i = 0
	var hy := LaneSkin.hit_line_y(field_rect())
	while i < _stomps.size():
		var st: Array = _stomps[i]
		var at := project(Vector2(lane_center(int(st[0])).x, hy))
		at.y = hit_line_screen_y()
		if FireSkin.draw_stomp_hit(ci, at, upright_scale(hy), _clock - float(st[2]), bool(st[1])):
			i += 1
		else:
			_stomps.remove_at(i)


## The hit line across the whole width, a bronze receptor on each lane.
func _draw_hit_line() -> void:
	var xs := []
	var lit := []
	for lane in 3:
		xs.append(project(lane_center(lane)).x)
		lit.append(_lane_glow(lane))
	var miss := []
	for lane in 3:
		miss.append(_flash_kind[lane] == "miss" and _clock - _flash[lane] < FLASH_TIME * 1.5)
	var near := []
	for lane in 3:
		near.append(session != null and _cued(lane))
	var hl := LaneSkin.hit_line_y(field_rect())
	var y := hit_line_screen_y()
	var span := _screen_span()
	FireSkin.draw_hit_line(self, span.x, span.y, y, xs, 0.33 * FireSkin.REF_LANE * upright_scale(hl), lit, beat_env(), miss, near)


## The hit line's height on screen, on the art grid (anchored at the road's far end).
func hit_line_screen_y() -> float:
	var f := field_rect()
	if street != null:
		return project(Vector2(f.size.x * 0.5, LaneSkin.hit_line_y(f))).y
	return PxArt.snap(project(Vector2(0.0, LaneSkin.hit_line_y(f))).y, f.position.y)


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
		if a < 0.3:
			continue
		for x0 in [r.position.x + 6.0, r.end.x - 6.0 - dash]:
			ci.draw_rect(Rect2(x0 - 3.0, y - 6.0, dash + 6.0, 12.0), PixelPalette.K[0])
			ci.draw_rect(Rect2(x0, y - 3.0, dash, 6.0), col)


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
		if a < 0.3:
			continue
		for cx in [r.position.x + inset, r.end.x - inset]:
			var tip := Vector2(cx, y + d * half * 0.8)
			var pts := PackedVector2Array([Vector2(cx - half, y - d * half * 0.2), tip, Vector2(cx + half, y - d * half * 0.2)])
			ci.draw_polyline(pts, PixelPalette.K[0], 18.0)
			ci.draw_polyline(pts, col, 10.0)


## The early/late chevron over a burst: up and cool above the hit for early, down and warm below it
## for late, cut out of an ink outline so it reads on any lane.
func _draw_chevron(ci: CanvasItem, pos: Vector2, side: String, age: float) -> void:
	var t := clampf(age / LaneSkin.BURST_TIME, 0.0, 1.0)
	var a := minf(1.0, pow(1.0 - t, 1.2) * 1.3)
	var d := -1.0 if side == "early" else 1.0
	if a < 0.35:
		return
	var cp := pos + Vector2(0.0, d * (30.0 + 26.0 * (1.0 - pow(1.0 - t, 3.0))))
	FireSkin.px_chevron(ci, cp, 8, d, UIKit.side_color(side))


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
				# a red pixel X on the button pressed
				var n := int(minf(w, r.size.y) * 0.26 / PxArt.PX)
				var o := (c / PxArt.PX).round() * PxArt.PX
				for pass_ in 2:
					for k in range(-n, n + 1):
						for sd in [-1.0, 1.0]:
							var q := o + Vector2(float(k), float(k) * sd) * PxArt.PX
							var rr := Rect2(q - Vector2(PxArt.PX, PxArt.PX), Vector2(PxArt.PX, PxArt.PX) * 2.0)
							if pass_ == 0:
								draw_rect(rr.grow(PxArt.PX), PixelPalette.K[0])
							else:
								draw_rect(rr, PixelPalette.RED[4])
			"faint":
				var p := project(lane_center(lane))
				if a > 0.4:
					var frx := float(FireSkin.note_rx(upright_scale(LaneSkin.hit_line_y(field_rect()))))
					FireSkin.px_plate(self, p, frx + 1.0, FireSkin.plate_ry(frx) + 1.0, 1.0, PixelPalette.BONE[1])
			"stomp", "stomp1":
				# nothing extra on the button: it burns red with both prints hot (its hit state), and the
				# stomp's own burst is thrown out of the slot on the road
				pass


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
		var y := event_y(field, n.t, pps)
		var y_end := event_y(field, n.end_t, pps) if n.kind == Note.Kind.HOLD or n.kind == Note.Kind.REST else y
		out.append([n, y, y_end])
	return out


## Chords still to play among the shown notes: two steps on one beat. Each is [flat depth, low lane,
## high lane]; a cord is drawn between the two so the pair reads as one press with both thumbs.
func chords_shown(shown: Array) -> Array:
	var out := []
	var prev: Note = null
	for e in shown:
		var n: Note = e[0]
		if n.kind != Note.Kind.STEP or n.done:
			continue
		if prev != null and absf(prev.t - n.t) < 0.001 and prev.lane != n.lane:
			out.append([float(e[1]), mini(prev.lane, n.lane), maxi(prev.lane, n.lane)])
		prev = n
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
			Note.Kind.REST:
				if not n.finished:
					FireSkin.draw_band(ci, field, e[2], y)


## What stands on the road, upright and scaled with it: gems (steps, hold heads), hold rings, bell
## badges, stomps, and the stand-still label. Far notes fade in out of the fire's haze.
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
	for c in chords_shown(shown):
		var cy: float = c[0]
		FireSkin.draw_cord(self, project(Vector2(lanes[c[1]].get_center().x, cy)), project(Vector2(lanes[c[2]].get_center().x, cy)), upright_scale(cy), _haze(cy, field))
	for e in shown:
		var n: Note = e[0]
		var y: float = e[1]
		var a := _haze(y, field)
		match n.kind:
			Note.Kind.STEP:
				if not n.done:
					var at := project(Vector2(lanes[n.lane].get_center().x, y))
					if n.heal:
						FireSkin.draw_heal_gem(self, at, upright_scale(y), a, _clock)
					else:
						FireSkin.draw_gem(self, at, upright_scale(y), n.call, a, _off_beat(n))
			Note.Kind.HOLD:
				if n.finished or (n.done and not n.holding):
					continue
				var tail: float = e[2]
				var cx := lanes[n.lane].get_center().x
				if tail > -20.0:
					FireSkin.draw_hold_ring(self, project(Vector2(cx, tail)), upright_scale(tail), _haze(tail, field))
				var head := minf(y, hl) if n.holding else y
				var hat := project(Vector2(cx, head))
				FireSkin.draw_hold_head(self, hat, upright_scale(head), a)
			Note.Kind.BELL:
				if not n.done:
					_draw_bell_bar(field, y, n.up, a)
					FireSkin.draw_badge(self, project(Vector2(field.get_center().x, y)), upright_scale(y), a, n.up)
			Note.Kind.RING:
				if not n.done:
					var sc := upright_scale(y)
					# a bell and a step at once: the bar, and the step's plate standing on it in its lane
					_draw_bell_bar(field, y, n.up, a)
					if n.lane != 1:
						FireSkin.draw_badge(self, project(Vector2(field.get_center().x, y)), sc, a, n.up)
					FireSkin.draw_gem(self, project(Vector2(lanes[n.lane].get_center().x, y)), sc, false, a)
			Note.Kind.STOMP:
				if not n.done:
					var sat := project(Vector2(lanes[n.lane].get_center().x, y))
					draw_stomp(sat, upright_scale(y), a * (0.6 if n.thumbs > 0 else 1.0))
			Note.Kind.REST:
				if not n.finished:
					rests.append([e[2], y])
	for r in rests:
		_rest_words(field, r[0], r[1], taken)


## The bell bar, upright across the road between its outer rails at flat depth y.
func _draw_bell_bar(field: Rect2, y: float, up: bool, a: float) -> void:
	var p := project(Vector2(field.get_center().x, y))
	var e := road_edges(p.y)
	FireSkin.draw_bar(self, e.x - PxArt.PX, e.y + PxArt.PX, p.y, upright_scale(y), up, a)


## A stomp note (handoff/stomp.md): a wide ember plate with a gold rim and two thumb prints - this
## button, both thumbs - at pos (on screen), scaled like a gem.
func draw_stomp(pos: Vector2, sc: float, alpha: float) -> void:
	FireSkin.draw_stomp_note(self, pos, sc, alpha)


## Whether a note falls between the beats (drawn smaller, in a dashed ring).
func _off_beat(n: Note) -> bool:
	if spb <= 0.0 or beat <= -999.0:
		return false
	var nb := beat + (n.t - song_time) / spb
	var fr := fposmod(nb, 1.0)
	return fr > 0.12 and fr < 0.88


## A sixteenth: a quarter of a beat off (only Expert has them; triplet eighths are not).
func _sixteenth(n: Note) -> bool:
	return absf(fposmod(n.beat, 0.5) - 0.25) < 0.02


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
	var P := PxArt.PX
	var text := tr("lane_still")
	var w := PxType.width("caps", text)
	var p := project(Vector2(field.get_center().x, best_y)).round()
	var back := Rect2(roundf((p.x - w * 0.5) / P) * P - 6.0 * P, roundf(p.y / P) * P - 7.0 * P, roundf(w / P) * P + 12.0 * P, 15.0 * P)
	# a UI-kit tag: K0 outline, gold frame, navy board, gold studs, a red diamond either side
	draw_rect(back.grow(P), PixelPalette.K[0])
	draw_rect(back, PixelPalette.GOLD[3])
	draw_rect(Rect2(back.position, Vector2(back.size.x, P)), PixelPalette.GOLD[5])
	draw_rect(back.grow(-P), PixelPalette.K[0])
	draw_rect(back.grow(-2.0 * P), PixelPalette.NAVY[1])
	for sx in [back.position.x + 3.0 * P, back.end.x - 4.0 * P]:
		for sy in [back.position.y + 3.0 * P, back.end.y - 4.0 * P]:
			draw_rect(Rect2(sx, sy, P, P), PixelPalette.GOLD[4])
	for sd in [-1.0, 1.0]:
		var dx := back.position.x - 3.0 * P if sd < 0.0 else back.end.x + 2.0 * P
		var dy := back.get_center().y - P * 0.5
		for d in [[0.0, -1.0], [-1.0, 0.0], [0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]:
			draw_rect(Rect2(dx + d[0] * P - P, dy + d[1] * P - P, 3.0 * P, 3.0 * P), PixelPalette.K[0])
		for d in [[0.0, -1.0], [-1.0, 0.0], [0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]:
			draw_rect(Rect2(dx + d[0] * P, dy + d[1] * P, P, P), PixelPalette.RED[3] if d != [0.0, -1.0] else PixelPalette.RED[4])
	PxType.draw(self, "caps", Vector2(p.x, back.position.y + 3.0 * P), text, PixelPalette.BONE[4], 1, 0)
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
	# The panel under the plates, across the whole screen: deep navy, closed on top by a gold rule.
	var span := _screen_span()
	var P := PxArt.PX
	var top := PxArt.snap(r.position.y, field_rect().position.y)
	draw_rect(Rect2(span.x, top, span.y - span.x, r.size.y + 400.0), PixelPalette.NAVY[0])
	draw_rect(Rect2(span.x, top, span.y - span.x, P), PixelPalette.K[0])
	draw_rect(Rect2(span.x, top + P, span.y - span.x, P), PixelPalette.GOLD[2])
	draw_rect(Rect2(span.x, top + P * 2.0, span.y - span.x, P), PixelPalette.K[0])
	var w := r.size.x / 3.0
	var pad := 3.0 * P
	for lane in 3:
		var x0 := PxArt.snap(r.position.x + w * lane + pad * (1.0 if lane == 0 else 0.5), field_rect().get_center().x)
		var x1 := PxArt.snap(r.position.x + w * (lane + 1) - pad * (1.0 if lane == 2 else 0.5), field_rect().get_center().x)
		var br := Rect2(x0, top + P * 5.0, x1 - x0, PxArt.snap(r.end.y - pad, top) - top - P * 5.0)
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


# ------------------------------------------------------------------ over the low-poly street

## A point in the street's coordinates, in this control's.
## The street's mapping, kept for a frame: project() and road_scale() run hundreds of times a frame
## (every corner of every note) and working it out from the nodes each time was most of their cost.
## Worked out again on the first call of each frame and at the first drawing of each frame, after
## everything has moved (the screen's shake).
var _sm := PackedFloat32Array()
var _sm_xf := Transform2D.IDENTITY     ## the street's coordinates to this control's
var _sm_scale := 1.0
var _sm_frame := -1
var _sm_drawn := -1


func _street_map(drawing := false) -> void:
	var f := Engine.get_process_frames()
	if f == _sm_frame and (not drawing or f == _sm_drawn):
		return
	_sm_frame = f
	if drawing:
		_sm_drawn = f
	_sm = street.flat_consts()
	_sm_xf = Transform2D.IDENTITY
	if is_inside_tree() and street.is_inside_tree():
		_sm_xf = get_global_transform().affine_inverse() * street.get_global_transform()
	_sm_scale = _sm_xf.get_scale().x


func _from_street(v: Vector2) -> Vector2:
	if not is_inside_tree() or not street.is_inside_tree():
		return v
	return (get_global_transform().affine_inverse() * street.get_global_transform()) * v


func _street_scale() -> float:
	if not is_inside_tree() or not street.is_inside_tree():
		return 1.0
	return (get_global_transform().affine_inverse() * street.get_global_transform()).get_scale().x


const BTN_BG := Color("#15121c")
const BTN_EDGE := Color("#9a6a2a")
const BTN_BONE := Color("#eadfc8")
const OUTLINE := Color("#07060a")
static var _font: Font


static func ui_font() -> Font:
	if _font == null:
		_font = load("res://fonts/AlegreyaSans-ExtraBold.ttf")
	return _font


func _exit_tree() -> void:
	if StreetSkin.atlas != null and StreetSkin.atlas.lanes == self:
		StreetSkin.atlas = null


## Over the street picture: the stand-still bands, the hit line, the notes (far to near), the
## bursts, the stand-still label, the early/late marks and the buttons.
func _draw_street() -> void:
	var field := field_rect()
	if StreetSkin.atlas != null and StreetSkin.atlas.lanes == self:
		StreetSkin.atlas.ready_for(self)   # painted with the first frame, before any note shows
	if session != null:
		StreetSkin.draw_notes(self, field)
	for b in _bursts:
		var pos: Vector2 = b[0]
		StreetSkin.burst(self, project(pos), str(b[1]), _clock - float(b[2]), road_scale(pos.y))
	for st in _stomps:
		var at := project(Vector2(lane_center(int(st[0])).x, LaneSkin.hit_line_y(field)))
		StreetSkin.burst(self, at, "stomp" if bool(st[1]) else "ok", _clock - float(st[2]), road_scale(LaneSkin.hit_line_y(field)) * (1.6 if bool(st[1]) else 1.0))
	_draw_pulses(field)
	for sk in _strikes:
		StreetSkin.bell_strike(self, field, bool(sk[0]), str(sk[1]), int(sk[2]), _clock - float(sk[3]))
	if session != null:
		var hl := LaneSkin.hit_line_y(field)
		var taken: Array[float] = []
		var rests := []
		for e in _notes_shown(field):
			var n: Note = e[0]
			if n.kind == Note.Kind.REST:
				if not n.finished:
					rests.append([e[2], e[1]])
			elif not n.done:
				taken.append(float(e[1]))
		for r in rests:
			_rest_tag(field, r[0], r[1], taken, hl)
		_draw_street_ticks(field, hl)
		_draw_locks()
	for b in _bursts:
		var q: String = b[1]
		var side: String = b[3] if q != "early" and q != "late" else q
		if side != "":
			_street_chevron(project(b[0]), side, _clock - float(b[2]))
	if show_buttons:
		_draw_street_buttons()


## The stand-still label on its band, at the place farthest from any note crossing it.
func _rest_tag(field: Rect2, y_a: float, y_b: float, taken: Array[float], hl: float) -> void:
	var top := maxf(minf(y_a, y_b), field.position.y)
	var bottom := minf(maxf(y_a, y_b), hl)
	if bottom - top < 40.0:
		return
	var best_y := (top + bottom) * 0.5
	var best_gap := -INF
	var cy := top + 22.0
	# with nothing crossing the band the label sits in the middle of what shows of it, not squeezed at
	# its far edge where it is smallest
	while not taken.is_empty() and cy <= bottom - 22.0:
		var gap := INF
		for ty in taken:
			gap = minf(gap, absf(ty - cy))
		if gap > best_gap + 0.5:
			best_gap = gap
			best_y = cy
		cy += 6.0
	var p := project(Vector2(field.get_center().x, best_y))
	var sc := clampf(road_scale(best_y), 0.45, 1.0)
	var fs := int(round(34.0 * sc))
	var text := tr("lane_still").to_upper()
	var f := ui_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(p.x - w * 0.5 - 18.0 * sc, p.y - fs * 0.75, w + 36.0 * sc, fs * 1.5)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#101a33e6")
	sb.border_color = Color("#6f9cf0")
	sb.set_border_width_all(maxi(2, int(3.0 * sc)))
	sb.set_corner_radius_all(int(10.0 * sc))
	draw_style_box(sb, box)
	draw_string(f, Vector2(box.position.x + 18.0 * sc, p.y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#e6eeff"))
	_rest_label_y = best_y


## The early/late ticks at the hit line: short bars at both edges of the lane, cool above for early,
## warm below for late, projected onto the road.
func _draw_street_ticks(field: Rect2, hl: float) -> void:
	var rects := LaneSkin.lane_rects(field)
	var i := 0
	while i < _step_ticks.size():
		var k: Array = _step_ticks[i]
		var age := _clock - float(k[2])
		if age > STEP_TICK_TIME:
			_step_ticks.remove_at(i)
			continue
		i += 1
		var side := str(k[1])
		var d := -1.0 if side == "early" else 1.0
		var r: Rect2 = rects[clampi(int(k[0]), 0, 2)]
		var col := UIKit.side_color(side)
		for cx: float in [r.position.x + r.size.x * 0.14, r.end.x - r.size.x * 0.14]:
			_street_chevron(project(Vector2(cx, hl)) + Vector2(0.0, d * 26.0), side, age * LaneSkin.BURST_TIME / STEP_TICK_TIME, 0.8)
	for o in _offsets:
		var age := _clock - float(o[1])
		if age > TICK_TIME:
			continue
		var off := float(o[0])
		var side := UIKit.side_of(off)
		var col := Palette.BONE if side == "" else UIKit.side_color(side)
		col.a = clampf(1.0 - age / TICK_TIME, 0.0, 1.0)
		var r: Rect2 = rects[clampi(int(o[2]), 0, 2)]
		var y := hl + clampf(off / 0.12, -1.0, 1.0) * minf((field.end.y - hl) * 0.9, 64.0)
		for x0: float in [r.position.x + 8.0, r.end.x - 8.0 - r.size.x * 0.12]:
			var a := project(Vector2(x0, y))
			var b := project(Vector2(x0 + r.size.x * 0.12, y))
			draw_line(a, b, Color(OUTLINE, col.a), 10.0)
			draw_line(a, b, col, 5.0)


## An early/late chevron: up and cool above the hit for early, down and warm below it for late.
func _street_chevron(pos: Vector2, side: String, age: float, size_k := 1.0) -> void:
	var t := clampf(age / LaneSkin.BURST_TIME, 0.0, 1.0)
	var a := minf(1.0, pow(1.0 - t, 1.2) * 1.3)
	if a < 0.3:
		return
	var d := -1.0 if side == "early" else 1.0
	var cp := pos + Vector2(0.0, d * (30.0 + 26.0 * (1.0 - pow(1.0 - t, 3.0))) * size_k)
	var s := 16.0 * size_k
	var pts := PackedVector2Array([cp + Vector2(-s, -d * s * 0.5), cp + Vector2(0, d * s * 0.5), cp + Vector2(s, -d * s * 0.5)])
	var col := UIKit.side_color(side)
	col.a = a
	draw_polyline(pts, Color(OUTLINE, a), 13.0 * size_k)
	draw_polyline(pts, col, 7.0 * size_k)


## The three step buttons: dark slabs edged in bronze, a bone footprint on each (both feet on the
## middle one), lit gold while pressed, hot on a hit, dull red on a miss, their edge glowing when a
## note is about to reach their lane.
func _draw_street_buttons() -> void:
	if pixel:
		_draw_pixel_buttons()
		return
	var r := buttons_rect()
	var span := _screen_span()
	var panel := Rect2(span.x, r.position.y, span.y - span.x, r.size.y + 400.0)
	draw_rect(panel, Color("#0b0a10"))
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 3.0)), Color("#ffb04a") * Color(1, 1, 1, 0.6 + 0.4 * beat_env()))
	var w := r.size.x / 3.0
	var pad := 7.0
	for lane in 3:
		var br := Rect2(r.position.x + w * lane + pad, r.position.y + pad + 4.0, w - pad * 2.0, r.size.y - pad * 2.0 - 4.0)
		var st := _button_state(lane)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.bg_color = BTN_BG
		sb.border_color = BTN_EDGE
		var foot := BTN_BONE
		match st:
			"cued":
				sb.border_color = Color("#ffc445")
				sb.shadow_color = Color("#ff9a2a66")
				sb.shadow_size = 10
			"pressed":
				sb.bg_color = Color("#4a3014")
				sb.border_color = Color("#ffe08a")
				sb.shadow_color = Color("#ffb04a88")
				sb.shadow_size = 14
			"hit":
				sb.bg_color = Color("#c47a1c")
				sb.border_color = Color("#fff2c0")
				sb.shadow_color = Color("#ffc445aa")
				sb.shadow_size = 18
				foot = Color("#fffaf0")
			"miss":
				sb.bg_color = Color("#3a1212")
				sb.border_color = Color("#a83030")
				foot = BTN_BONE.darkened(0.4)
		draw_style_box(sb, br)
		# a lit lip along the top, the lane's slot light carried down onto the button
		var lip := Color("#ffb04a")
		var la := 0.35 + 0.25 * beat_env()
		match st:
			"cued":
				la = 0.9
			"pressed", "hit":
				lip = Color("#fff2c0")
				la = 1.0
		draw_rect(Rect2(br.position.x + 18.0, br.position.y + 5.0, br.size.x - 36.0, 6.0), Color(lip, la))
		var feet := [-1.0, 1.0] if lane == 1 else ([-1.0] if lane == 0 else [1.0])
		var fs := minf(br.size.x, br.size.y) * 0.25
		for i in feet.size():
			var ox := 0.0 if feet.size() == 1 else (float(i) - 0.5) * fs * 1.5
			_footprint(br.get_center() + Vector2(ox, 0.0), fs, feet[i], foot)
	_draw_street_marks(r, w)


# ------------------------------------------------------------------ the pixel look's buttons

const PX_WOOD := [Color("#160c0a")]   ## the shade under a step
const PX_BRONZE := [Color("#4e2a0a"), Color("#b0701e"), Color("#f2c46a")]
const PX_LIFT := 3          ## art px a button stands up from the panel (its side shows below it)
const BTN_CAP := 118        ## source px of the button pictures' carved frame (kept square when stretched)
const FOOT_ASPECT := 206.0 / 431.0


## Picture `key` from art/ai stretched to cells, nine-sliced: its frame (cap source px from each
## edge) keeps its shape at the cells' scale and only the middle stretches; alpha cut hard at half.
## "<name>!white": its silhouette in white, for a glow tinted by modulate.
static var _nine_cache := {}

static func _nine(key: String, cells: Vector2i, cap_src: int) -> Texture2D:
	cells = cells.max(Vector2i(4, 4))
	var k := "%s_%d_%d" % [key, cells.x, cells.y]
	if _nine_cache.has(k):
		return _nine_cache[k]
	var tex: Texture2D = null
	var path := "res://art/ai/%s.png" % key.trim_suffix("!white")
	if ResourceLoader.exists(path):
		var src := (load(path) as Texture2D).get_image()
		src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var sw := src.get_width()
		var sh := src.get_height()
		var cap := clampi(roundi(cap_src * float(cells.y) / sh), 1, mini(cells.x, cells.y) / 2 - 1)
		var xs := [[0, cap_src, 0, cap], [cap_src, sw - cap_src, cap, cells.x - cap], [sw - cap_src, sw, cells.x - cap, cells.x]]
		var ys := [[0, cap_src, 0, cap], [cap_src, sh - cap_src, cap, cells.y - cap], [sh - cap_src, sh, cells.y - cap, cells.y]]
		var out := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
		for py: Array in ys:
			for px: Array in xs:
				var dw: int = px[3] - px[2]
				var dh: int = py[3] - py[2]
				if dw <= 0 or dh <= 0:
					continue
				var piece := src.get_region(Rect2i(px[0], py[0], px[1] - px[0], py[1] - py[0]))
				piece.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
				out.blit_rect(piece, Rect2i(0, 0, dw, dh), Vector2i(px[2], py[2]))
		for y in cells.y:
			for x in cells.x:
				var c := out.get_pixel(x, y)
				c.a = 1.0 if c.a > 0.5 else 0.0
				if key.ends_with("!white"):
					c = Color(1, 1, 1, c.a)
				out.set_pixel(x, y, c)
		tex = ImageTexture.create_from_image(out)
	_nine_cache[k] = tex
	return tex


## A rect in this control's coordinates snapped to the lens's grid (whole art px on screen).
func _grid_rect(r: Rect2) -> Rect2:
	var xf := get_global_transform()
	var inv := xf.affine_inverse()
	var k := xf.get_scale().x
	var a := PxArt.snap2(xf * r.position, Vector2.ZERO, PxArt.PX * k)
	var b := PxArt.snap2(xf * r.end, Vector2.ZERO, PxArt.PX * k)
	return Rect2(inv * a, (inv * b) - (inv * a))


## A block of whole art px: x, y, w, h in art px from the origin o.
func _px(o: Vector2, x: float, y: float, w: float, h: float, col: Color) -> void:
	var p := PxArt.PX
	draw_rect(Rect2(o + Vector2(x, y) * p, Vector2(w, h) * p), col)


## The three step buttons as pixel art, from Daniele's pictures (art/ai/btn_idle, btn_pressed, foot):
## carved wooden steps standing up out of the panel (their side shows below them). A press sinks the
## step and shows the pressed picture with its glow; a hit lights it hot, a miss dull red; a note
## about to reach its lane lights its edge. A bare foot is carved into each (both in the middle one).
func _draw_pixel_buttons() -> void:
	var r := buttons_rect()
	var span := _screen_span()
	var panel := _grid_rect(Rect2(span.x, r.position.y, span.y - span.x, r.size.y + 400.0))
	draw_rect(panel, Color("#0b0709"))
	var env := beat_env()
	var p := PxArt.PX
	_px(panel.position, 0, 0, panel.size.x / p, 1, PX_BRONZE[1].lerp(PX_BRONZE[2], env))
	_px(panel.position, 0, 1, panel.size.x / p, 1, PX_BRONZE[0])
	var w := r.size.x / 3.0
	for lane in 3:
		var br := _grid_rect(Rect2(r.position.x + w * lane + 9.0, r.position.y + 15.0, w - 18.0, r.size.y - 30.0))
		var st := _button_state(lane)
		var cols := int(br.size.x / p)
		var rows := int(br.size.y / p) - PX_LIFT
		var down := PX_LIFT if st == "pressed" or st == "hit" else 0
		var o := br.position + Vector2(0, down * p)
		# the step's side under it (the part that sinks into the panel when pressed)
		var side := PX_LIFT - down
		if side > 0:
			_px(o, 2, rows - 1, cols - 4, side + 1, PX_BRONZE[0])
			_px(o, 3, rows + side - 1, cols - 6, 1, PX_WOOD[0])
		var down_pic := st == "pressed" or st == "hit"
		var tex := _nine("btn_pressed" if down_pic else "btn_idle", Vector2i(cols, rows), BTN_CAP)
		var mod := {"idle": Color.WHITE, "cued": Color(1.2, 1.1, 0.92), "pressed": Color.WHITE,
			"hit": Color(1.45, 1.2, 0.85), "miss": Color(0.95, 0.5, 0.45)}[st] as Color
		if st == "cued" or st == "hit":
			# a one-px glow around the step's own outline (its cut corners included)
			var glow := Color("#fff2c0") if st == "hit" else Color("#ffc445")
			var sil := _nine("btn_idle!white", Vector2i(cols + 2, rows + 2), BTN_CAP)
			if sil != null:
				draw_texture_rect(sil, Rect2(o - Vector2(p, p), Vector2(cols + 2, rows + 2) * p), false, Color(glow, 0.8))
		if tex != null:
			draw_texture_rect(tex, Rect2(o, Vector2(cols, rows) * p), false, mod)
		# the feet carved into it
		var fmod := {"idle": Color(0.82, 0.78, 0.72), "cued": Color(1, 0.97, 0.9), "pressed": Color.WHITE,
			"hit": Color(1.15, 1.1, 1.0), "miss": Color(0.55, 0.32, 0.3)}[st] as Color
		var feet := [-1.0, 1.0] if lane == 1 else ([-1.0] if lane == 0 else [1.0])
		var fh := clampi(int(rows * 0.5), 16, 40)
		var fw := maxi(roundi(fh * FOOT_ASPECT), 6)
		for i in feet.size():
			var cx := cols * 0.5 + (0.0 if feet.size() == 1 else (float(i) - 0.5) * fw * 1.5)
			var ftex := StreetSkin.ai_tex("foot" if feet[i] > 0.0 else "foot!mirror", Vector2i(fw, fh))
			if ftex != null:
				var fo := Vector2(roundf(cx - fw * 0.5), roundf(rows * 0.5 - fh * 0.5))
				draw_texture_rect(ftex, Rect2(o + fo * p, Vector2(fw, fh) * p), false, fmod)
	_draw_street_marks(r, w)


## A bare footprint (left foot for -1, right for 1): the sole and five toes.
func _footprint(c: Vector2, s: float, foot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var k := 1.0 if sin(a) < 0.0 else 0.8
		pts.append(c + Vector2(cos(a) * s * 0.42 * k, sin(a) * s * 0.85 + s * 0.25))
	draw_colored_polygon(pts, col)
	for t in 5:
		var tx := (float(t) - 2.0) * s * 0.2 * -foot
		var big := 1.0 if t == 0 else 0.7 - 0.05 * t
		draw_circle(c + Vector2(tx - foot * s * 0.05, -s * 0.78 + absf(float(t)) * s * 0.07), s * 0.13 * big + 1.0, col)


func _draw_street_marks(r: Rect2, w: float) -> void:
	var i := 0
	while i < _marks.size():
		var m: Array = _marks[i]
		var age := _clock - float(m[2])
		if age > MARK_TIME:
			_marks.remove_at(i)
			continue
		i += 1
		var lane := clampi(int(m[1]), 0, 2)
		var c := Vector2(r.position.x + w * (lane + 0.5), r.get_center().y)
		match str(m[0]):
			"wrong":
				var s := minf(w, r.size.y) * 0.24
				for pass_ in 2:
					for sd in [-1.0, 1.0]:
						draw_line(c + Vector2(-s, -s * sd), c + Vector2(s, s * sd), OUTLINE if pass_ == 0 else Color("#ff3b30"), 20.0 if pass_ == 0 else 11.0)
			"faint":
				var p := project(lane_center(lane))
				draw_arc(p, 46.0 * clampf(road_scale(LaneSkin.hit_line_y(field_rect())), 0.5, 1.5), 0.0, TAU, 24, Color(BTN_BONE, 0.7), 4.0)


# ---------------------------------------------------------------- input lock


## While mashing has locked the step buttons: each ring at the hit line goes dark red, a brass padlock
## drops onto it, and a red rim around the ring drains as the lock runs out. When the lock ends the
## shackles spring open and the locks fade. Drawn in whole art px so it sits in the pixel look.
func _draw_locks() -> void:
	var age := _clock - _lock_t0
	if not _lock_on and age >= LOCK_OUT:
		return
	var field := field_rect()
	var hl := LaneSkin.hit_line_y(field)
	var sc := road_scale(hl)
	var rx: float = StreetSkin.DISC_R * sc * StreetSkin._lane(field) if street != null else 46.0 * clampf(sc, 0.5, 1.5)
	var ry := rx * (StreetSkin.FORE if street != null else 0.45)
	var fade_k := 1.0 if _lock_on else 1.0 - age / LOCK_OUT
	var drop := 0.0 if not _lock_on else maxf(0.0, 1.0 - age / LOCK_IN)
	var left := session.lock_left(song_time) / Session.LOCK_TIME if session != null and _lock_on else 0.0
	var p := PxArt.PX
	var k := maxf(1.0, roundf(rx * 0.75 / (LOCK_BODY[0].length() * p)))   # art px per lock px
	for lane in 3:
		var c := project(lane_center(lane))
		# the ring goes dark red: nothing can land in it
		var ell := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			ell.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(ell, Color(PixelPalette.RED[1], 0.7 * fade_k))
		# the time left, a red rim draining clockwise from the top
		if left > 0.0:
			var arc := PackedVector2Array()
			var steps := maxi(2, int(ceil(32.0 * left)))
			for i in steps + 1:
				var a := -PI * 0.5 + TAU * left * i / steps
				arc.append(c + Vector2(cos(a) * (rx + p), sin(a) * (ry + p)))
			draw_polyline(arc, PixelPalette.K[0], p * 2.6)
			draw_polyline(arc, PixelPalette.RED[4], p * 1.4)
		var shake := 0.0
		var ta := _clock - _lock_tap[lane]
		if _lock_on and ta < LOCK_SHAKE:
			shake = (1.0 if int(ta / 0.04) % 2 == 0 else -1.0) * k
		var w := LOCK_BODY[0].length() * k * p
		var h := (LOCK_SHACKLE.size() + LOCK_BODY.size()) * k * p
		var o := PxArt.snap2(c - Vector2(w * 0.5, h * 0.62) + Vector2(shake * p, -drop * 6.0 * k * p))
		var lift := 0.0 if _lock_on else roundf(minf(1.0, age / (LOCK_OUT * 0.4)) * 2.0) * k
		_lock_bitmap(o + Vector2(0.0, -lift * p), LOCK_SHACKLE, k, fade_k)
		_lock_bitmap(o + Vector2(0.0, LOCK_SHACKLE.size() * k * p), LOCK_BODY, k, fade_k)


func _lock_bitmap(o: Vector2, rows: Array[String], k: float, alpha: float) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var col: Color
			match row[x]:
				"o": col = PixelPalette.K[0]
				"s": col = PixelPalette.BONE[2]
				"S": col = PixelPalette.BONE[4]
				"b": col = PixelPalette.GOLD[3]
				"h": col = PixelPalette.GOLD[5]
				"d": col = PixelPalette.GOLD[1]
				"k": col = PixelPalette.K[1]
				_: continue
			_px(o, x * k, y * k, k, k, Color(col, alpha))
