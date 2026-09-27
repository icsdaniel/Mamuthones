// Winter fog printed as a woodcut: drifting noise decides how thick a set of horizontal cut lines
// is, so dense fog reads as heavy bone lines and thin fog as broken hairlines. Set on a ColorRect.
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.929, 0.902, 0.855, 1.0);
uniform float density = 0.5;       // 0..1
uniform float speed = 0.015;       // drift in UV per second (reduced motion uses a low value)
uniform float aspect = 3.0;        // rect width / height, so the noise is not stretched
uniform float lines = 34.0;        // cut lines across the rect's height
uniform float rise = 0.6;          // 0: even; 1: fog only at the bottom

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float n = texture(noise_tex, vec2(uv.x * aspect * 0.35 + t, uv.y * 0.55)).r * 0.6
		+ texture(noise_tex, vec2(uv.x * aspect * 0.8 - t * 1.7, uv.y * 1.2 + 0.37)).r * 0.4;
	float band = mix(1.0, smoothstep(0.0, 1.0, uv.y), rise) * smoothstep(0.0, 0.18, uv.y);
	float d = clamp((n - 0.35) * 2.2, 0.0, 1.0) * band * density;
	// Lines wander with the noise so they read as drifting bands, not scanlines.
	float line = abs(fract(uv.y * lines + n * 3.0 + sin(uv.x * aspect * 2.0 + n * 4.0) * 0.35) - 0.5) * 2.0;
	float w = d * 0.9;
	float aa = fwidth(line) + 0.001;
	float ink = 1.0 - smoothstep(w - aa, w + aa, line);
	COLOR = vec4(fog_color.rgb, fog_color.a * clamp(ink * 0.7 * smoothstep(0.05, 0.3, d) + d * 0.14, 0.0, 1.0));
}
