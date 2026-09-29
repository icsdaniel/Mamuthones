class_name FireBackdrop
extends Control
## The night behind the road on the play screen, in pixel art ("Bonfire Night", docs/art-style.md):
## a starry sky over the mountains and the houses of Mamoiada with the church tower, the crowd at the
## edge of the square, the great bonfire where the road ends, iron braziers at the square's sides,
## and the square's cobbles, warm near the fire and cool and mossy away from it.
##
## Everything sits on one art grid anchored on the road's far end (1 art px = PxArt.PX screen px).
## The sky strip and the square are baked pictures (tools/art/pixel/scenery.py). The strip is drawn
## through PxArt's light shader; the square through GROUND_SHADER here. The bonfire's light is baked
## into the square, falling stone by stone in steps down the sides; on every beat it pulses out over
## the cobbles as a banded ring of their lit twin, bigger on the bar's downbeat. Each brazier pools
## its own light round its feet in two stepped rings (the lit twin, and the "hot" twin two steps up
## its ramps inside), flickering with its flame; a low fire (dim, the player's health) swaps them
## toward their dim twins. Every colour stays the palette's.
##
## The play screen sets `lanes` once (the backdrop lines up with the road's far end) and `beat`
## every frame; `dim` 0..1 while health is low.

const STRIP := "play_strip"
const GROUND := "play_ground"
const STRIP_FAR_ROW := 68          ## the strip's row on the road's far end
const GROUND_FIRE := Vector2(0.0, -6.0)   ## the fire relative to the ground picture's top centre (art px)

var lanes: LaneView
var beat := -1000.0
## 0..1: the bonfire dims and burns lower (the play screen sets it while health is low).
var dim := 0.0
var reduced_motion := false

var _strip: PxArt.Picture
var _ground: PxArt.Picture
var _ground_mat: ShaderMaterial
var _fire: Bonfire
var _braziers: Array[Brazier] = []
var _clock := 0.0
var _kick := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	PxArt.nearest(self)
	_ground = PxArt.Picture.new(GROUND)
	_ground.name = "Square"
	_ground_mat = ground_material()
	_ground.material = _ground_mat
	add_child(_ground)
	_strip = PxArt.Picture.new(STRIP)
	_strip.name = "Village"
	add_child(_strip)
	for i in 4:
		var b := Brazier.new()
		b.name = "Brazier%d" % i
		b.seed = float(i) + 1.0
		b.flip = i % 2 == 1       # the right-hand braziers have the fire to their left
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(b)
		_braziers.append(b)
	_fire = Bonfire.new()
	_fire.name = "Bonfire"
	_fire.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fire)
	reduced_motion = UIKit.reduced_motion()


## 0..1 on the beat, falling away through it (0 before the music).
func pulse() -> float:
	return 1.0 - fposmod(beat, 1.0) if beat >= 0.0 else 0.0


## The bonfire leaps now, beyond its beat (a stomp: 1 for both thumbs, about 0.4 for one), and its
## light swells over the square with it.
func kick(amount := 1.0) -> void:
	if _fire != null:
		_fire.kick(amount)
	_kick = maxf(_kick, amount)


## The road's far end in this control's coordinates: [centre, width].
func far_end() -> Array:
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var r := lanes.far_end()
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var a := xf * r.position
		var b := xf * (r.position + Vector2(r.size.x, 0.0))
		return [Vector2((a.x + b.x) * 0.5, a.y), b.x - a.x]
	return [Vector2(size.x * 0.5, size.y * 0.13), size.x * 0.42]


## Scale of the world (1 on the 720-wide base screen).
func ref_scale() -> float:
	return size.x / 720.0


## The art grid's origin: the far end's centre.
func grid_origin() -> Vector2:
	return far_end()[0]


func _process(delta: float) -> void:
	_clock += delta
	var g := grid_origin()
	var px := PxArt.PX
	_kick = maxf(0.0, _kick - delta * 2.4)
	var env := (PxArt.beat_env(beat, 0.5, 0.6, 0.16) + _kick * 0.8) * (0.35 if reduced_motion else 1.0)
	var flick := 0.5 + 0.5 * sin(_clock * 9.3) * sin(_clock * 5.7 + 1.3)
	# The village strip, its far-end row on the far end.
	var st := PxArt.scenery(STRIP)
	if st != null:
		_strip.origin = g + Vector2(-st.get_width() / 2, -STRIP_FAR_ROW) * px
		var m := _strip.mat
		m.set_shader_parameter("fire", Vector2(st.get_width() / 2, STRIP_FAR_ROW - 14))
		m.set_shader_parameter("fire_r", Vector2(78.0, 46.0) * (1.0 + 0.35 * maxf(env, 0.0)))
		m.set_shader_parameter("pulse", maxf(env, 0.0) * 0.9)
		m.set_shader_parameter("glow", 0.12 + 0.12 * flick)
		m.set_shader_parameter("dim", dim)
		_strip.queue_redraw()
	# The square: the ground picture hangs from the far end, centred on the fire.
	var gt := PxArt.scenery(GROUND)
	if gt != null:
		var origin := g + Vector2(-gt.get_width() / 2, 0) * px
		_ground.origin = origin
		var m2 := _ground_mat
		m2.set_shader_parameter("fire", Vector2(gt.get_width() / 2, 0) + GROUND_FIRE)
		m2.set_shader_parameter("fire_r", Vector2(120.0, 200.0) * (0.8 + 0.5 * maxf(env, 0.0)))
		m2.set_shader_parameter("pulse", maxf(env, 0.0) * 0.9)
		m2.set_shader_parameter("glow", 0.25 + 0.15 * flick)
		m2.set_shader_parameter("dim", dim)
		var lamps: Array = []
		for b in _braziers:
			if not b.visible:
				continue
			var l := b.light()
			var c: Vector2 = (b.feet - origin) / px
			lamps.append(Vector4(c.x, c.y, float(l[1]) * 2.0, float(l[2])))
		m2.set_shader_parameter("lamp_count", lamps.size())
		while lamps.size() < 6:
			lamps.append(Vector4.ZERO)
		m2.set_shader_parameter("lamps", lamps)
		_ground.queue_redraw()
	# The bonfire on the far end, the braziers at the square's sides.
	_fire.root = g
	_fire.px = px
	_fire.beat = beat
	_fire.low = dim
	_fire.reduced_motion = reduced_motion
	_fire.sparks_top = g.y - 60.0 * px
	_place_braziers(g)
	for b in _braziers:
		b.beat = beat
		b.low = dim
		b.reduced_motion = reduced_motion
	queue_redraw()


## Two braziers at the back corners of the square, just in front of the crowd, and two near the
## front, as low as the road leaves them room above the hit line. All stand whole on the screen (INSET art px from its
## edge) and clear of the road (ROAD_CLEAR) and of the files of figures beside it (SideRows: the
## back pair stand above the file's second Mamuthone, the front pair below the Issohadore).
const INSET := 4.0
const ROAD_CLEAR := 5.0
const RIM := 21.0                  ## the brazier's rim above its feet (art px)
const LEGS := 7.0                  ## its legs' spread either side of its feet (art px)
const HIT_CLEAR := 10.0            ## its feet above the hit line (art px)


func _place_braziers(g: Vector2) -> void:
	var px := PxArt.PX
	var t := PxArt.scenery("brazier")
	var wide := float(t.get_width()) if t != null else 17.0
	var half := floorf(wide * 0.5) * px          ## from the feet to the sprite's left edge, screen px
	var left := 0.0
	var right := size.x
	var xl := PxArt.snap(left + INSET * px + half, g.x)
	var xr := PxArt.snap(right - INSET * px - (wide - floorf(wide * 0.5)) * px, g.x)
	# back pair: on the square just in front of the crowd, a little down from the far end
	var yb := PxArt.snap(g.y + 13.0 * px, g.y)
	_braziers[0].feet = Vector2(xl, yb)
	_braziers[1].feet = Vector2(xr, yb)
	# front pair: as high as the road leaves room for a whole brazier between it and the screen's
	# edge, searching up from low on the field
	var yf := -1.0
	if lanes != null and lanes.is_inside_tree():
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var f := lanes.field_rect()
		# never on or under the hit line (it runs the screen's width): feet HIT_CLEAR art px above it
		var hit_y: float = lanes.project(Vector2(0.0, LaneSkin.hit_line_y(f))).y
		var y := minf(f.end.y - f.size.y * 0.16, hit_y - HIT_CLEAR * px)
		var found := -1.0
		while y > f.position.y + f.size.y * 0.45:
			# the basket's rim (its widest part) is RIM art px above the feet, where the road is
			# narrower; the legs below spread LEGS art px either side of the feet
			var feet_y := (xf * Vector2(0.0, y)).y
			var rim_e := lanes.road_edges(y - RIM * px)
			var foot_e := lanes.road_edges(y)
			var rim_ok := (xf * Vector2(rim_e.x, y)).x - (xl - half + wide * px) >= ROAD_CLEAR * px
			var foot_ok := (xf * Vector2(foot_e.x, y)).x - (xl + LEGS * px) >= ROAD_CLEAR * px
			if rim_ok and foot_ok:
				found = feet_y
				break
			y -= px
		yf = found
	for i in [2, 3]:
		_braziers[i].visible = yf > 0.0
	if yf > 0.0:
		var yy := PxArt.snap(yf, g.y)
		_braziers[2].feet = Vector2(xl, yy)
		_braziers[3].feet = Vector2(xr, yy)


## Above the strip: the sky's darkest navy up to the screen's top (under a notch).
func _draw() -> void:
	var st := PxArt.scenery(STRIP)
	var top := grid_origin().y - STRIP_FAR_ROW * PxArt.PX
	draw_rect(Rect2(Vector2.ZERO, size), PixelPalette.K[1])
	if st != null and top > 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, top + 1.0), PixelPalette.NIGHT[0])


## The square's material: its lit, hot and dim twins swapped in by the fire's pulse and the
## braziers' pools.
static func ground_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	var base := PxArt.scenery(GROUND)
	m.set_shader_parameter("lit_tex", PxArt.scenery(GROUND + "_lit"))
	m.set_shader_parameter("hot_tex", PxArt.scenery(GROUND + "_hot"))
	m.set_shader_parameter("dim_tex", PxArt.scenery(GROUND + "_dim"))
	if base != null:
		m.set_shader_parameter("tex_size", Vector2(base.get_width(), base.get_height()))
	return m


const GROUND_SHADER := """
shader_type canvas_item;
// The square's light, stepped: each art pixel shows the base picture, its lit twin (one step up
// every ramp), its hot twin (two steps up) or its dim twin (one down). The light is banded into those
// levels with a one-step ordered dither only at each band's edge, so pools and pulses read as rings
// of pixel light, never as a soft gradient.
uniform sampler2D lit_tex : filter_nearest;
uniform sampler2D hot_tex : filter_nearest;
uniform sampler2D dim_tex : filter_nearest;
uniform vec2 tex_size = vec2(1.0);
uniform vec2 fire = vec2(0.0);            // the bonfire in the picture's art px
uniform vec2 fire_r = vec2(120.0, 200.0); // reach of its beat pulse (art px)
uniform float pulse = 0.0;                // 0..1 the beat's flare
uniform float glow = 0.0;                 // steady share of the lit twin near the fire
uniform float dim = 0.0;                  // 0..1 the fire burning low
uniform vec4 lamps[6];                    // braziers: xy feet (art px), z radius, w strength
uniform int lamp_count = 0;
float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float b[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (b[y * 4 + x] + 0.5) / 16.0;
}
// a level 0..2 from a light value, the band's edge dithered over its last seventh
int band(float v, float th) {
	float i = floor(v);
	float f = v - i;
	if (f > 0.85 && th < (f - 0.85) / 0.15) { i += 1.0; }
	return int(clamp(i, 0.0, 2.0));
}
void fragment() {
	vec2 p = floor(UV * tex_size);
	float th = bayer4(p);
	float near = clamp(1.0 - length((p + 0.5 - fire) / fire_r), 0.0, 1.0);
	float L = (pulse + glow) * near * 1.6;
	for (int i = 0; i < 6; i++) {
		if (i >= lamp_count) break;
		vec4 l = lamps[i];
		float dl = length((p + 0.5 - l.xy) / vec2(l.z, l.z * 0.55));
		// two rings: hot inside r_hot (bigger as the flame leaps), lit out to the rim, each edge a
		// thin dither
		float r_hot = 0.3 + 0.35 * l.w;
		float Ll = dl <= 1.0 ? 2.0 - clamp((dl - r_hot) / (1.0 - r_hot), 0.0, 1.0) * 0.999 : clamp((1.15 - dl) / 0.15, 0.0, 1.0) * 0.999;
		L = max(L, l.w > 0.02 ? Ll : 0.0);
	}
	int lv = band(L, th);
	float D = dim * (0.55 + 0.45 * (1.0 - near));
	vec4 c = texture(TEXTURE, UV);
	if (lv >= 2) {
		c = texture(hot_tex, UV);
	} else if (lv == 1) {
		c = texture(lit_tex, UV);
	} else if (D > th) {
		c = texture(dim_tex, UV);
	}
	COLOR = c;
}
"""
