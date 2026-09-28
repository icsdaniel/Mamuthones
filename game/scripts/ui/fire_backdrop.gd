class_name FireBackdrop
extends Control
## The night behind the road on the play screen ("Fire Night"): an indigo sky over the dark skyline of
## Mamoiada, a big living bonfire where the road ends, and the fire-warmed cobbles of the square either
## side of the road. The sky, skyline, ground and the pyre's logs are sprites cut from the mockup
## (res://art/fire/); the flames are a noise shader, and sparks, the fire's glow and the rings rolling
## across the square are drawn here, pulsing on the beat.
##
## The play screen sets `lanes` once (the backdrop lines up with the road's far end) and `beat` every
## frame. Reference sizes are the mockup's: 720 wide, the road's far end at y 195, 302 wide.

const REF_W := 720.0
const REF_TOPY := 195.0
const REF_FAR_W := 302.0
const SKY_TOP := Color("#05041a")
const GROUND_Y0 := 150.0
const FIRE_RECT := Rect2(196.0, 62.0, 328.0, 140.0)    ## the flame field: the whole fire sits between the
                                                       ## HUD (y 110) and the road's far end, base at (360, 198)
const SPARKS := 70

const FLAME_SHADER := """
shader_type canvas_item;
// The mockup's flame field: turbulent value noise inside a tall cone, through the fire's colour ramp,
// rising over time. UV spans FIRE_RECT in the mockup's pixels.
uniform float pulse = 0.0;
uniform float t0 = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = h(i), b = h(i + vec2(1, 0)), c = h(i + vec2(0, 1)), d = h(i + vec2(1, 1));
	return a + (b - a) * f.x + (c - a) * f.y + (a - b - c + d) * f.x * f.y;
}
float fbm(vec2 p, float seed) {
	float v = 0.0, a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * vn(p + seed); a *= 0.5; p *= 2.03; }
	return v;
}
vec4 ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	vec4 c0 = vec4(90., 8., 20., 0.), c1 = vec4(120., 12., 22., 150.), c2 = vec4(200., 34., 24., 230.), c3 = vec4(250., 98., 28., 250.);
	vec4 c4 = vec4(255., 160., 48., 255.), c5 = vec4(255., 214., 110., 255.), c6 = vec4(255., 246., 210., 255.), c7 = vec4(255., 255., 245., 255.);
	vec4 c = mix(c0, c1, smoothstep(0.0, 0.16, t));
	c = mix(c, c2, clamp((t - 0.16) / 0.14, 0.0, 1.0));
	c = mix(c, c3, clamp((t - 0.30) / 0.18, 0.0, 1.0));
	c = mix(c, c4, clamp((t - 0.48) / 0.16, 0.0, 1.0));
	c = mix(c, c5, clamp((t - 0.64) / 0.16, 0.0, 1.0));
	c = mix(c, c6, clamp((t - 0.80) / 0.12, 0.0, 1.0));
	c = mix(c, c7, clamp((t - 0.92) / 0.08, 0.0, 1.0));
	return c / 255.0;
}
void fragment() {
	float tm = TIME + t0;
	float x = 196.0 + UV.x * 328.0;
	float y = 62.0 + UV.y * 140.0;
	float v = (198.0 - y) / (105.0 * (1.0 + 0.05 * pulse));
	float u = (x - 360.0) / 135.0;
	float t1 = fbm(vec2(x * 0.03 + sin(tm * 0.7) * 0.25, (y + tm * 60.0) * 0.016 - 3.0), 0.0);
	float t2 = fbm(vec2(x * 0.07, (y + tm * 110.0) * 0.035), 17.0);
	float vp = max(0.0, v);
	float uu = u + (t1 - 0.5) * 0.9 * vp + (t2 - 0.5) * 0.25;
	float w = max(0.02, 1.05 * pow(1.0 - min(vp, 1.0), 0.85));
	float I = (1.0 - abs(uu) / w) * 1.35 - vp * 0.55 + 0.1 + (t2 - 0.5) * 0.5 + (t1 - 0.5) * 0.35;
	I *= 0.92 + 0.06 * pulse;
	if (v < 0.0) { I *= 1.0 + v * 8.0; }
	vec4 c = ramp(I);
	c.a *= step(0.0, I) * smoothstep(-0.05, 0.0, v) * (1.0 - smoothstep(0.93, 0.999, v));
	COLOR = c;
}
"""

var lanes: LaneView
var beat := -1000.0

var _fire: ColorRect
var _glow: Control
var _front: Control
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_fire = ColorRect.new()
	_fire.name = "Flames"
	_fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FLAME_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("t0", 3.7)
	_fire.material = mat
	_fire.show_behind_parent = false
	add_child(_fire)
	_front = _Front.new()
	var front := _front
	front.name = "Front"
	front.backdrop = self
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(front)
	_glow = _Glow.new()
	_glow.name = "Glow"
	_glow.set("backdrop", self)
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)


func _process(delta: float) -> void:
	_clock += delta
	_place_fire()
	(_fire.material as ShaderMaterial).set_shader_parameter("pulse", pulse())
	_glow.queue_redraw()
	_front.queue_redraw()
	queue_redraw()


## 0..1 on the beat, falling away through it (0 before the music).
func pulse() -> float:
	return 1.0 - fposmod(beat, 1.0) if beat >= 0.0 else 0.0


## The road's far end in this control's coordinates: [centre, width].
func far_end() -> Array:
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var r := lanes.far_end()
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var a := xf * r.position
		var b := xf * (r.position + Vector2(r.size.x, 0.0))
		return [Vector2((a.x + b.x) * 0.5, a.y), b.x - a.x]
	return [Vector2(size.x * 0.5, size.y * 0.135), size.x * 0.42]


## Scale of the sky and ground sprites (the screen's width over the mockup's).
func ref_scale() -> float:
	return size.x / REF_W


func _place_fire() -> void:
	var fe := far_end()
	var c: Vector2 = fe[0]
	var k: float = float(fe[1]) / REF_FAR_W
	_fire.position = c + (FIRE_RECT.position - Vector2(360.0, REF_TOPY)) * k
	_fire.size = FIRE_RECT.size * k


## Behind the flames: the night sky and the skyline, lined up on the road's far end.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FireSkin.NIGHT)
	var fe := far_end()
	var c: Vector2 = fe[0]
	var k := ref_scale()
	var sky := FireSkin.tex("sky")
	var sky_top := c.y - REF_TOPY * k
	if sky_top > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, sky_top + 1.0), SKY_TOP)
	if sky != null:
		draw_texture_rect(sky, Rect2(c.x - REF_W * 0.5 * k, sky_top, REF_W * k, sky.get_height() * k), false)


## In front of the flames: the pyre's logs and the square (cobbles and the crowd at its edge).
class _Front extends Control:
	var backdrop: FireBackdrop

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fe := backdrop.far_end()
		var c: Vector2 = fe[0]
		var kf: float = float(fe[1]) / REF_FAR_W
		var k := backdrop.ref_scale()
		var pyre := FireSkin.tex("pyre")
		if pyre != null:
			# The pyre sprite spans x 160..560, y 150..230 of the mockup.
			draw_texture_rect(pyre, Rect2(c + (Vector2(160.0, 150.0) - Vector2(360.0, REF_TOPY)) * kf, Vector2(400.0, 80.0) * kf), false)
		var ground := FireSkin.tex("ground")
		if ground != null:
			draw_texture_rect(ground, Rect2(c.x - REF_W * 0.5 * k, c.y - (REF_TOPY - GROUND_Y0) * k, REF_W * k, ground.get_height() * k), false)


## Additive light: the fire's bloom and the glow at its base, sparks rising into the night, and rings
## of light rolling out across the square on every beat.
class _Glow extends Control:
	var backdrop: FireBackdrop

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var fe := backdrop.far_end()
		var c: Vector2 = fe[0]
		var kf: float = float(fe[1]) / REF_FAR_W
		var p := backdrop.pulse()
		var t := backdrop._clock
		var g := FireSkin.glow()
		var flick := 0.92 + 0.08 * sin(t * 11.0) * sin(t * 7.3)
		var r := 240.0 * kf * (1.0 + 0.05 * p)
		draw_texture_rect(g, Rect2(c + Vector2(-r, -37.0 * kf - r), Vector2(r, r) * 2.0), false, Color(1.0, 0.5, 0.18, (0.2 + 0.1 * p) * flick))
		var rb := 150.0 * kf
		draw_texture_rect(g, Rect2(c + Vector2(-rb, -rb * 0.45), Vector2(rb * 2.0, rb * 0.9)), false, Color(1.0, 0.7, 0.35, 0.32 * flick))
		# Rings rolling out across the square, one per beat (the road covers their middle).
		if backdrop.beat > -999.0:
			var ph := fposmod(backdrop.beat, 1.0)
			var k := backdrop.ref_scale()
			for j in 3:
				var s := float(j) + ph
				var rx := (330.0 + 235.0 * s) * k
				var ry := (120.0 + 120.0 * s) * k
				var a := 0.2 * (1.0 - s / 3.0)
				var pts := PackedVector2Array()
				for i in 33:
					var ang := PI * float(i) / 32.0
					pts.append(c + Vector2(cos(ang) * rx, 8.0 * k + sin(ang) * ry))
				draw_polyline(pts, Color(1.0, 0.59, 0.24, a), 5.0 * k, true)
				draw_polyline(pts, Color(1.0, 0.86, 0.6, a * 0.6), 1.5 * k, true)
		# Sparks rising from the fire, kept below the HUD's corners (mockup y 8..148).
		for i in SPARKS:
			var sp := 0.25 + 0.3 * WoodcutDraw.hash01(i, 41)
			var ph := fposmod(WoodcutDraw.hash01(i, 43) + t * sp, 1.0)
			var spread := (WoodcutDraw.hash01(i, 47) - 0.5) * 300.0 * (0.3 + ph) + sin(t * 1.7 + float(i)) * 8.0 * ph
			var ry := -47.0 - ph * 140.0      # mockup y 148 .. 8, relative to the far end (195)
			if REF_TOPY + ry < 108.0 and absf(spread) > 110.0:
				continue
			var x := c.x + spread * kf
			var y := c.y + ry * kf
			var s := (2.0 if WoodcutDraw.hash01(i, 53) < 0.75 else 3.0) * maxf(kf, 1.0)
			var col := Color(1.0, 0.9, 0.55) if i % 2 == 0 else Color(1.0, 0.5, 0.16)
			draw_rect(Rect2(x, y, s, s), Color(col, (1.0 - ph) * (0.6 + 0.4 * p)))
