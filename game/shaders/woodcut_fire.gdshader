// A bonfire cut from a woodblock: flame shape from scrolling noise, posterised into three inks
// (red edge, ember body, white-hot core) and crossed by wavy gouge lines. One small quad per fire;
// a couple of texture reads per pixel, so it is cheap on a phone.
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float speed = 1.0;         // 0 freezes the flame (reduced motion uses a low value)
uniform float seed = 0.0;
uniform float lean = 0.0;          // wind: pushes the tip sideways
uniform float gouges = 22.0;       // carved lines across the flame
uniform vec4 c_outer : source_color = vec4(0.753, 0.224, 0.169, 1.0);
uniform vec4 c_mid : source_color = vec4(0.878, 0.635, 0.290, 1.0);
uniform vec4 c_core : source_color = vec4(0.953, 0.812, 0.522, 1.0);

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;                 // 0 at the base, 1 at the top
	float x = (uv.x - 0.5) * 2.0;
	float t = TIME * speed;
	float n1 = texture(noise_tex, vec2(uv.x * 0.8 + seed, uv.y * 0.7 + t * 0.55)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.9 - seed * 1.3, uv.y * 1.6 + t * 1.1)).r;
	float n = n1 * 0.65 + n2 * 0.35;
	float wobble = (n - 0.5) * 0.9 * y + lean * y * y;
	// Separate tongues: the upper flame splits where this ridge dips.
	float tongues = sin((uv.x * 4.5 + n2 * 1.8 + seed) * 3.14159 + t * 0.8);
	float width = mix(0.95, 0.04, pow(y, 0.75)) * (0.75 + 0.4 * n1);
	float shape = width - abs(x - wobble);
	float heat = shape * 1.25 + (n - 0.5) * 0.6 - y * 0.2 + tongues * 0.14 * y;
	// Gouges: wavy horizontal cuts that thin the flame into carved tongues.
	float g = sin((uv.y * gouges + n * 4.0 + t * 1.6) * 3.14159);
	heat -= smoothstep(0.55, 1.0, g) * 0.16 * (0.4 + y);
	float aa = fwidth(heat) * 1.2 + 0.001;
	float a_out = smoothstep(0.02 - aa, 0.02 + aa, heat);
	float a_mid = smoothstep(0.13 - aa, 0.13 + aa, heat);
	float a_core = smoothstep(0.38 - aa, 0.38 + aa, heat);
	vec3 col = mix(c_outer.rgb, c_mid.rgb, a_mid);
	col = mix(col, c_core.rgb, a_core);
	COLOR = vec4(col, a_out * COLOR.a);
}
