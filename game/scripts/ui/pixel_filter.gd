class_name PixelFilter
extends ColorRect
## The pixel look's lens: laid over the play screen, it turns everything under it into pixel art on
## one grid. The screen is cut into square cells PxArt.PX base px wide (3: a 240-wide picture on the
## 720-wide base screen); each cell takes the average of four samples inside it, each snapped
## to the pixel palette (art/pixel/palette_lut.png, a 32 x 32 x 32 lookup made by
## tools/art/pixel3d/palette.py). So the notes and figures can move smoothly in 3D underneath and
## still come out as clean palette pixels, the way a low-resolution 3D game looks.

const LUT := "res://art/pixel/palette_lut.png"
const Z := 50                  ## the lens's z: everything at or under it is seen through it
const Z_OVER := 51             ## crisp things over it (the pixel type, already on the grid)

var cell := PxArt.PX
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = Z


func _ready() -> void:
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	if ResourceLoader.exists(LUT):
		_mat.set_shader_parameter("lut", load(LUT))
		_mat.set_shader_parameter("use_lut", true)
	material = _mat


func _process(_delta: float) -> void:
	# a cell is `cell` base px: in screen px that is the canvas's scale times it; the grid is anchored
	# on this control's top left, so it stays put whatever the window
	var xf := get_global_transform_with_canvas()
	var sc := get_viewport().get_final_transform().get_scale().x * xf.get_scale().x
	_mat.set_shader_parameter("cell", maxf(1.0, cell * sc))
	var o := get_viewport().get_final_transform() * xf.origin
	_mat.set_shader_parameter("origin", o)


const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D lut : filter_nearest;
uniform bool use_lut = false;
uniform float cell = 3.0;
uniform vec2 origin = vec2(0.0);

vec3 snap(vec3 c) {
	// the lookup: 32 slices of 32 x 32 (blue picks the slice), laid side by side
	vec3 q = clamp(floor(c * 31.0 + 0.5), 0.0, 31.0);
	vec2 uv = vec2((q.b * 32.0 + q.r + 0.5) / 1024.0, (q.g + 0.5) / 32.0);
	return texture(lut, uv).rgb;
}

void fragment() {
	vec2 sp = 1.0 / vec2(textureSize(screen, 0));
	vec2 base = origin + floor((FRAGCOORD.xy - origin) / cell) * cell;
	float q = cell * 0.25;
	vec3 a = texture(screen, (base + vec2(q, q)) * sp).rgb;
	vec3 b = texture(screen, (base + vec2(3.0 * q, q)) * sp).rgb;
	vec3 c = texture(screen, (base + vec2(q, 3.0 * q)) * sp).rgb;
	vec3 d = texture(screen, (base + vec2(3.0 * q, 3.0 * q)) * sp).rgb;
	if (use_lut) {
		// each sample snapped, then averaged: a cell wholly inside a shape is one palette colour;
		// a cell on a moving edge blends the two by how much of it the shape covers, so edges glide
		// in quarter cells instead of hopping a whole cell at a time
		a = snap(a); b = snap(b); c = snap(c); d = snap(d);
	}
	COLOR = vec4((a + b + c + d) * 0.25, 1.0);
}
"""
