class_name MenuBackdrop
extends Control
## The night every menu-type screen stands in (App puts one behind the screen stack): a deep night
## sky with a few stars, warming toward a bonfire glow low in the middle, and a handful of embers
## drifting up. Pixel art on the kit's art grid (PxStyle.unit): the sky is a canvas shader
## (game/shaders/menu_sky.gdshader: the palette ramp, 4x4 ordered dithering, quantised to the art
## pixel), the stars are a short list of art-pixel points rebuilt only when the width changes, and
## the embers step at 12 frames a second (a third as many with reduced motion, still when animations
## are off). Hidden under the play screen, so nothing here runs during a song.

const FRAME_TIME := 1.0 / 12.0
const EMBERS := 18

var reduced_motion := false
var still := false                ## animations off: the embers stand still
var _sky: ColorRect
var _sparks: Control
var _stars: Array[Vector4] = []   ## art x, height fraction, colour index, bright (0/1)
var _stars_w := -1
var _t := 0.0
var _clock := 0.0
var _embers: Array[Vector4] = []   ## x (0..1), speed (art px/s), phase (0..1), sway


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Backdrop"
	var seed := 7
	for i in EMBERS:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var a := float(seed % 1000) / 1000.0
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var b := float(seed % 1000) / 1000.0
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var c := float(seed % 1000) / 1000.0
		# most embers rise from the middle, where the glow is
		var x := 0.5 + (a - 0.5) * (0.5 + 0.5 * c)
		_embers.append(Vector4(x, 6.0 + 10.0 * b, c, (b - 0.5) * 8.0))


func _ready() -> void:
	_sky = ColorRect.new()
	_sky.name = "Sky"
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_sky.gdshader")
	_sky.material = mat
	add_child(_sky)
	_sparks = Control.new()
	_sparks.name = "Sparks"
	_sparks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.draw.connect(_draw_sparks)
	add_child(_sparks)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var u := PxStyle.unit
	(_sky.material as ShaderMaterial).set_shader_parameter("canvas_size", size)
	(_sky.material as ShaderMaterial).set_shader_parameter("unit", u)
	var aw := maxi(floori(size.x / u), 1)
	if aw != _stars_w:
		_stars_w = aw
		_stars.clear()
		var seed := 12345
		var n := int(aw * 0.75)
		for k in n:
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var sx := seed % aw
			seed = (seed * 1103515245 + 12345) & 0x7fffffff
			var f := pow(float(seed % 1000) / 1000.0, 1.7) * 0.55
			_stars.append(Vector4(sx, f, k % 3, 1.0 if k % 9 == 0 else 0.0))
	_sparks.queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or still:
		return
	_t += delta
	if _t < FRAME_TIME:
		return
	_clock += _t * (0.5 if reduced_motion else 1.0)
	_t = 0.0
	_sparks.queue_redraw()


func _draw_sparks() -> void:
	var u := PxStyle.unit
	var ah := floorf(size.y / u)
	var cell := Vector2(u, u)
	for s in _stars:
		var p := Vector2(s.x, floorf(s.y * ah))
		var bright := s.w > 0.0
		var c: Color = PixelPalette.STAR[1] if bright else (PixelPalette.STAR[0] if s.z == 0.0 else PixelPalette.NIGHT[4])
		if bright:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_sparks.draw_rect(Rect2((p + d) * u, cell), PixelPalette.NIGHT[4])
		_sparks.draw_rect(Rect2(p * u, cell), c)
	var rise := ah * 0.55
	var count := EMBERS / 3 if reduced_motion else EMBERS
	for i in count:
		var e := _embers[i]
		var up := fmod(_clock * e.y + e.z * rise, rise)
		var k := up / rise
		var x := e.x * size.x / u + sin(_clock * 0.9 + e.z * 6.28) * e.w * k
		var y := ah - 6.0 - up
		var a := clampf(1.0 - k * 1.15, 0.0, 1.0)
		if a <= 0.02:
			continue
		var c: Color = PixelPalette.FIRE[6] if k < 0.3 else (PixelPalette.FIRE[5] if k < 0.6 else PixelPalette.FIRE[4])
		_sparks.draw_rect(Rect2(Vector2(roundf(x), roundf(y)) * u, cell), Color(c, a))
