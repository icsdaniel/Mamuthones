class_name PxArt
extends RefCounted
## Shared pieces of the pixel-art world ("Bonfire Night", docs/art-style.md): texture loading, drawing
## a 1x sprite at a whole number of screen pixels per art pixel with nearest filtering, snapping to
## the world's art grid, the ordered-dither threshold, and the light shader that swaps a picture's
## pixels to its baked "lit" or "dim" twin where the fire's light reaches (so the beat's light pulse
## stays palette-pure pixel art).
##
## The world's art grid: 1 art px = PX screen px (3 on the 720-wide base screen), anchored on the
## road's far end, so the backdrop, the road and the title scene share one grid.

const PX := 3.0
const SCENERY := "res://art/px/scenery/"
const FIELD := "res://art/px/field/"

const BAYER := [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0]

static var _tex := {}


static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[path] = t
	return t


static func scenery(name: String) -> Texture2D:
	return tex(SCENERY + name + ".png")


static func field(name: String) -> Texture2D:
	return tex(FIELD + name + ".png")


## Nearest filtering for everything this canvas item draws (pixel art stays square).
static func nearest(ci: CanvasItem) -> void:
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


## Snaps a coordinate to the art grid whose origin is `origin` (px screen px per art px).
static func snap(v: float, origin := 0.0, px := PX) -> float:
	return origin + floorf((v - origin) / px + 0.5) * px


static func snap2(p: Vector2, origin := Vector2.ZERO, px := PX) -> Vector2:
	return Vector2(snap(p.x, origin.x, px), snap(p.y, origin.y, px))


## Draws a 1x texture with its top-left at `at`, `px` screen px per art px (flip mirrors it).
static func blit(ci: CanvasItem, t: Texture2D, at: Vector2, px := PX, modulate := Color.WHITE, flip := false) -> void:
	if t == null:
		return
	var sz := Vector2(t.get_width(), t.get_height()) * px
	if flip:
		ci.draw_texture_rect_region(t, Rect2(at, sz), Rect2(Vector2(t.get_width(), 0), Vector2(-t.get_width(), t.get_height())), modulate)
	else:
		ci.draw_texture_rect(t, Rect2(at, sz), false, modulate)


## Ordered-dither threshold (0..1) of art pixel (x, y).
static func bayer(x: int, y: int) -> float:
	return (float(BAYER[(posmod(y, 4)) * 4 + posmod(x, 4)]) + 0.5) / 16.0


## Pulse envelope of a beat clock: 1 on the beat, falling away over `fall` of the beat, with a small
## dip (inhale) over the last `pre` of the beat before it; stronger (1.0) on a bar's downbeat than on
## the other beats (`weak`). 0 before the music (beat < 0).
static func beat_env(beat: float, fall := 0.45, weak := 0.62, pre := 0.18) -> float:
	if beat < -0.25:
		return 0.0
	var f := fposmod(beat, 1.0)
	var n := floori(beat + 0.0001)
	var strength := 1.0 if posmod(n, 4) == 0 else weak
	var e := 0.0
	if beat >= 0.0:
		e = pow(clampf(1.0 - f / fall, 0.0, 1.0), 2.0) * strength
	if f > 1.0 - pre:
		var nb := floori(beat) + 1
		var s2 := 1.0 if posmod(nb, 4) == 0 else weak
		e -= 0.25 * s2 * smoothstep(1.0 - pre, 1.0, f)
	return e


# ------------------------------------------------------------------ the light swap

const LIGHT_SHADER := """
shader_type canvas_item;
// Swaps each art pixel of the picture to its lit twin where the light reaches it and to its dim twin
// where the fire is low, by an ordered-dither threshold: the light's edge is a pixel-art dither, and
// every colour stays one of the palette's.
uniform sampler2D lit_tex : filter_nearest;
uniform sampler2D dim_tex : filter_nearest;
uniform vec2 tex_size = vec2(1.0);
uniform vec2 fire = vec2(0.0);            // the fire in the picture's art pixels
uniform vec2 fire_r = vec2(100.0, 60.0);  // reach of its pulse (art px)
uniform float pulse = 0.0;                // 0..1 the beat's flare
uniform float glow = 0.0;                 // 0..1 a steady share of the lit twin near the fire
uniform float dim = 0.0;                  // 0..1 the fire burning low
uniform vec4 lamps[6];                    // braziers: xy centre (art px), z radius, w strength
uniform int lamp_count = 0;
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = y * 4 + x;
	float b[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[i] + 0.5) / 16.0;
}
void fragment() {
	vec2 p = floor(UV * tex_size);
	vec4 c = texture(TEXTURE, UV);
	float th = bayer4(p);
	float d = length((p + 0.5 - fire) / fire_r);
	float near = clamp(1.0 - d, 0.0, 1.0);
	float L = (pulse + glow) * near;
	for (int i = 0; i < 6; i++) {
		if (i >= lamp_count) break;
		vec4 l = lamps[i];
		float dl = length((p + 0.5 - l.xy) / vec2(l.z, l.z * 0.55));
		L += l.w * clamp(1.0 - dl, 0.0, 1.0);
	}
	float D = dim * (0.55 + 0.45 * (1.0 - near));
	if (L > th) {
		c = texture(lit_tex, UV);
	} else if (D > th) {
		c = texture(dim_tex, UV);
	}
	COLOR = c;
}
"""

static var _light_shader: Shader


## A material for drawing picture `name` (res://art/px/scenery/<name>.png) with its lit and dim twins.
static func light_material(name: String) -> ShaderMaterial:
	if _light_shader == null:
		_light_shader = Shader.new()
		_light_shader.code = LIGHT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _light_shader
	var base := scenery(name)
	m.set_shader_parameter("lit_tex", scenery(name + "_lit"))
	m.set_shader_parameter("dim_tex", scenery(name + "_dim"))
	if base != null:
		m.set_shader_parameter("tex_size", Vector2(base.get_width(), base.get_height()))
	return m


## A Control that draws one scenery picture (with its light twins) on the art grid.
class Picture extends Control:
	var picture := ""
	var mat: ShaderMaterial
	var origin := Vector2.ZERO      ## where the picture's top-left goes (screen px)
	var px := PxArt.PX
	var flip := false

	func _init(p_name: String) -> void:
		picture = p_name
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mat = PxArt.light_material(p_name)
		material = mat

	func _ready() -> void:
		PxArt.nearest(self)

	func tex() -> Texture2D:
		return PxArt.scenery(picture)

	func _draw() -> void:
		PxArt.blit(self, tex(), origin, px, Color.WHITE, flip)
