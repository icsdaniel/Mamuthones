class_name Bonfire
extends Control
## The great bonfire in pixel art: the log pyre (baked sprites, res://art/px/scenery/pyre_*.png), the
## flames (a shader drawing on the art grid, posterised to the palette's FIRE ramp and stepped at
## 12 frames a second, so it reads as drawn pixel fire), and sparks rising as single art pixels.
##
## The fire flares on the beat: `beat` is the song's fractional beat; the flames draw in a little just
## before it and leap up on it (taller, a hotter core, a burst of sparks), more on a bar's downbeat.
## `low` 0..1 burns it lower and redder (the player's health is low). Also used by the title scene.
##
## Place it by `root` (the foot of the flames, in this control's coordinates; snapped to the art grid
## by the parent) and `px` (screen px per art px). `scale_art` sizes the whole fire in art pixels.

const FPS := 12.0
const SPARKS_PER_S := 26.0
const BURST := 16                 ## sparks thrown on a downbeat (fewer on the other beats)

var root := Vector2.ZERO
var px := PxArt.PX
var scale_art := 1.0
var beat := -1000.0
var low := 0.0
var reduced_motion := false
var sparks_top := -INF            ## sparks die above this y (keeps them clear of the HUD's corners)
var spark_reach := 1.0            ## how high sparks rise, in flame heights

var flame_h := 60.0               ## flame height at rest, art px (before scale_art)
var flame_w := 26.0               ## half width at the root, art px
var pyre_k := 0                   ## art px per pyre sprite px (0: follow scale_art)

var _flames: ColorRect
var _front: Control
var _clock := 0.0
var _sparks: Array = []           ## [x, y (art px from root), vx, vy, born, life, hot]
var _last_beat := -9999
var _rng := RandomNumberGenerator.new()
var _spawn_acc := 0.0
var _kick := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7


func _ready() -> void:
	PxArt.nearest(self)
	_flames = ColorRect.new()
	_flames.name = "Flames"
	_flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = flame_shader_code()
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_flames.material = mat
	add_child(_flames)
	_front = _Front.new()
	_front.name = "Front"
	_front.set("fire", self)
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_front)
	PxArt.nearest(_front)


## The flare now: 1 on a downbeat, ~0.6 on the other beats, falling away; a little below 0 just
## before each beat (the fire draws breath).
func flare() -> float:
	var e := PxArt.beat_env(beat, 0.5, 0.6, 0.16) + _kick
	return e * (0.35 if reduced_motion else 1.0)


## An extra leap now (a full stomp: 1; one thumb: less), dying away over a third of a second, with a
## burst of sparks.
func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount * 0.8)
	var n := int(BURST * amount * (0.35 if reduced_motion else 1.0))
	for i in n:
		_spawn(true)


## The flame field in art px (width, height), large enough for the tallest flare.
func field_art() -> Vector2:
	return Vector2(roundf(flame_w * scale_art * 3.4), roundf(flame_h * scale_art * 1.45))


func _process(delta: float) -> void:
	_clock += delta
	_kick = maxf(0.0, _kick - delta * 2.4)
	var f := flare()
	var fa := field_art()
	_flames.position = root + Vector2(-floorf(fa.x * 0.5) * px, -(fa.y - 2.0) * px)
	_flames.size = fa * px
	var m := _flames.material as ShaderMaterial
	m.set_shader_parameter("size_px", fa)
	m.set_shader_parameter("t", floorf(_clock * FPS) / FPS)
	m.set_shader_parameter("flare", f)
	m.set_shader_parameter("low", low)
	m.set_shader_parameter("height", flame_h * scale_art)
	m.set_shader_parameter("width", flame_w * scale_art)
	_tick_sparks(delta)
	queue_redraw()
	_front.queue_redraw()


func _tick_sparks(delta: float) -> void:
	var h := flame_h * scale_art
	# A steady stream, thinner when the fire is low; a burst on each beat, bigger on a downbeat.
	_spawn_acc += delta * SPARKS_PER_S * scale_art * (1.0 - 0.6 * low)
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		_spawn(false)
	if beat > -0.5:
		var b := floori(beat)
		if b != _last_beat:
			if _last_beat > -9999 and b == _last_beat + 1:
				var n := BURST if posmod(b, 4) == 0 else BURST / 2
				n = int(n * scale_art * (0.35 if reduced_motion else 1.0) * (1.0 - 0.5 * low))
				for i in n:
					_spawn(true)
			_last_beat = b
	var i := 0
	while i < _sparks.size():
		var s: Array = _sparks[i]
		var age := _clock - float(s[4])
		if age > float(s[5]):
			_sparks.remove_at(i)
			continue
		s[0] = float(s[0]) + float(s[2]) * delta + sin(_clock * 3.0 + float(s[4]) * 7.0) * 3.0 * delta
		s[1] = float(s[1]) + float(s[3]) * delta
		s[3] = float(s[3]) * (1.0 - 0.35 * delta)
		i += 1
	if _sparks.size() > 220:
		_sparks = _sparks.slice(_sparks.size() - 220)


func _spawn(hot: bool) -> void:
	var h := flame_h * scale_art
	var w := flame_w * scale_art
	var x := _rng.randf_range(-w * 0.8, w * 0.8)
	var y := -_rng.randf_range(h * 0.25, h * 0.75)
	var speed := _rng.randf_range(14.0, 26.0) * scale_art * (1.6 if hot else 1.0)
	var vx := _rng.randf_range(-6.0, 6.0) * scale_art * (2.2 if hot else 1.0)
	var life := _rng.randf_range(0.9, 1.8) * spark_reach
	_sparks.append([x, y, vx, -speed, _clock, life, hot])


## Behind the flames: the back logs of the pyre.
func _draw() -> void:
	var t := PxArt.scenery("pyre_back")
	if t == null:
		return
	var k := pyre_k if pyre_k > 0 else maxi(1, roundi(scale_art))
	var at := root + Vector2(-floorf(t.get_width() * 0.5) * px * k, -(t.get_height() - 1) * px * k)
	PxArt.blit(self, t, at, px * k)


## In front of the flames: the pyre's front logs and coals, and the sparks.
class _Front extends Control:
	var fire: Bonfire

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if fire == null:
			return
		var px := fire.px
		var k := fire.pyre_k if fire.pyre_k > 0 else maxi(1, roundi(fire.scale_art))
		var t := PxArt.scenery("pyre_front")
		if t != null:
			PxArt.blit(self, t, fire.root + Vector2(-floorf(t.get_width() * 0.5) * px * k, -(t.get_height() - 1) * px * k), px * k)
		var cols: Array[Color] = PixelPalette.FIRE
		for s in fire._sparks:
			var age := fire._clock - float(s[4])
			var life := float(s[5])
			var k2 := age / life
			var col: Color
			if k2 < 0.25:
				col = cols[7] if s[6] else cols[6]
			elif k2 < 0.55:
				col = cols[5]
			elif k2 < 0.8:
				col = cols[4]
			else:
				col = cols[3]
			var p := fire.root + Vector2(floorf(float(s[0])), floorf(float(s[1]))) * px
			if p.y < fire.sparks_top:
				continue
			var tall := 2.0 if (s[6] and k2 < 0.4) else 1.0
			draw_rect(Rect2(p, Vector2(px, px * tall)), col)


## The flame shader: the FIRE ramp inlined from PixelPalette.
static func flame_shader_code() -> String:
	var ramp := ""
	for i in PixelPalette.FIRE.size():
		var c: Color = PixelPalette.FIRE[i]
		ramp += "\tif (i == %d) return vec4(%f, %f, %f, 1.0);\n" % [i, c.r, c.g, c.b]
	return FLAME_SHADER.replace("__RAMP__", ramp)


const FLAME_SHADER := """
shader_type canvas_item;
// Pixel fire: evaluated once per art pixel, banded into the FIRE ramp with an ordered dither on the
// band edges. y runs up from the root; the field is wider and taller than the fire at rest so it can
// leap on the beat.
uniform vec2 size_px = vec2(72.0, 78.0);
uniform float t = 0.0;
uniform float flare = 0.0;
uniform float low = 0.0;
uniform float height = 54.0;
uniform float width = 20.0;
uniform float seed = 3.7;

vec4 ramp(int i) {
__RAMP__	return vec4(0.0);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float b[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[y * 4 + x] + 0.5) / 16.0;
}
void fragment() {
	vec2 p = floor(UV * size_px);
	vec2 q = vec2(p.x + 0.5 - floor(size_px.x * 0.5), (size_px.y - 2.0) - p.y - 0.5);
	float fl = flare;
	float H = height * (1.0 + 0.3 * fl) * (1.0 - 0.42 * low);
	float W = width * (1.0 + 0.1 * fl) * (1.0 - 0.2 * low);
	float vp = max(q.y / H, 0.0);
	// the licks sway: a wave climbing the flame and a slow lean
	float n3 = vnoise(vec2(seed * 3.0, t * 0.5 + q.y * 0.015));
	float wave = sin(q.y * 0.16 - t * 5.0 + seed) * 2.2 * vp + sin(q.y * 0.07 - t * 2.3) * 3.0 * vp;
	float xs = q.x - (wave + (n3 - 0.5) * 9.0 * vp * vp);
	// vertical streaks: each column's own reach (the tongues), rising and changing
	float streak = vnoise(vec2(xs * 0.17 + seed, q.y * 0.03 - t * 1.6));
	float streak2 = vnoise(vec2(xs * 0.4 + seed * 2.0, q.y * 0.08 - t * 3.2));
	float detail = vnoise(vec2(xs * 0.3 + seed * 4.0, q.y * 0.16 - t * 4.5));
	float colH = H * (0.28 + 0.62 * streak + 0.22 * streak2);
	colH *= 0.75 + 0.45 * exp(-pow(xs / (W * 0.45), 2.0));
	float wy = W * pow(clamp(1.0 - vp, 0.0, 1.0), 0.75) + 1.0;
	float s = min((1.0 - abs(xs) / wy) * 1.4, (1.0 - q.y / colH) * 1.2);
	float I = s * 1.1 + (detail - 0.5) * 0.4 + 0.08 + 0.08 * fl * (1.0 - vp);
	I *= 1.0 - 0.28 * low;
	// the white-hot heart low in the middle, bigger when it leaps
	float core = 1.0 - length(vec2(xs / (W * (0.3 + 0.08 * fl)), (q.y - H * 0.1) / (H * (0.14 + 0.05 * fl))));
	I = max(I, core * (1.1 + 0.12 * fl - 0.3 * low) + (detail - 0.5) * 0.2);
	if (q.y / H < -0.02) { I = 0.0; }
	float lv = I * 7.0 + (bayer4(p) - 0.5) * 0.55;
	int idx = int(floor(lv));
	if (idx < 1) {
		COLOR = vec4(0.0);
	} else {
		COLOR = ramp(min(idx, 7));
	}
}
"""
