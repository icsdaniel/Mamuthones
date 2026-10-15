shader_type canvas_item;
// The menus' night sky (MenuBackdrop): the palette ramp from the night at the top to the bonfire's
// glow low in the middle, ordered-dithered (4x4 Bayer) between neighbouring palette colours, and
// quantised to the kit's art pixel, so it is pixel art at any screen size with no per-pixel script.

uniform vec2 canvas_size = vec2(720.0, 1440.0);   // the backdrop's size in canvas px
uniform float unit = 3.0;                          // canvas px per art px (PxStyle.unit)

// PixelPalette NIGHT0, NIGHT1, STONE0, STONE1, FIRE0, FIRE1
const vec3 RAMP[6] = vec3[](
	vec3(0.039, 0.047, 0.141), vec3(0.063, 0.086, 0.227), vec3(0.110, 0.078, 0.094),
	vec3(0.173, 0.125, 0.149), vec3(0.290, 0.039, 0.047), vec3(0.486, 0.094, 0.071));
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 art = max(floor(canvas_size / unit), vec2(1.0));
	vec2 p = floor(UV * canvas_size / unit);
	float v = p.y / art.y;
	float cx = art.x * 0.5;
	float warm = clamp((v - 0.5) / 0.5, 0.0, 1.0);
	float side = abs(p.x - cx) / max(cx, 1.0);
	float heat = pow(warm, 1.6) * (1.0 - 0.6 * side * side);
	float q = clamp(v * 0.28 + heat * 0.74, 0.0, 1.0) * 5.0;
	int i = min(int(floor(q)), 4);
	float f = q - float(i);
	int b = int(mod(p.y, 4.0)) * 4 + int(mod(p.x, 4.0));
	float thr = (BAYER[b] + 0.5) / 16.0;
	COLOR = vec4(f > thr ? RAMP[i + 1] : RAMP[i], 1.0);
}
