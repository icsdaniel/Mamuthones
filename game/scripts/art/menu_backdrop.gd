class_name MenuBackdrop
extends Control
## The night every menu-type screen stands in (App puts one behind the screen stack): a deep night
## sky with a few stars, warming toward a bonfire glow low in the middle, and a handful of embers
## drifting up. Pixel art on the 3-px art grid: the sky is baked once per screen size into a small
## texture (ordered dithering between palette colours, no smooth gradients) and drawn x3 with nearest
## filtering; the embers step at 12 frames a second (a third as many with reduced motion, still when
## animations are off). Hidden under the play screen, so nothing here runs during a song.

const PX := 3.0
const FRAME_TIME := 1.0 / 12.0
## The sky ramp, top to the heart of the glow (PixelPalette NIGHT0, NIGHT1, STONE0, STONE1, FIRE0, FIRE1).
const RAMP: Array[Color] = [Color("#0a0c24"), Color("#10163a"), Color("#1c1418"), Color("#2c2026"), Color("#4a0a0c"), Color("#7c1812")]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const EMBERS := 18

var reduced_motion := false
var still := false                ## animations off: the embers stand still
var _sky: ImageTexture
var _sky_size := Vector2i.ZERO
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
	resized.connect(_bake)
	_bake()


## Bakes the sky for this size at one texel per art pixel.
func _bake() -> void:
	var aw := maxi(ceili(size.x / PX), 1)
	var ah := maxi(ceili(size.y / PX), 1)
	if Vector2i(aw, ah) == _sky_size and _sky != null:
		return
	_sky_size = Vector2i(aw, ah)
	var img := Image.create(aw, ah, false, Image.FORMAT_RGB8)
	var cx := aw * 0.5
	var last := RAMP.size() - 1
	for y in ah:
		var v := float(y) / float(ah)
		var warm := clampf((v - 0.5) / 0.5, 0.0, 1.0)
		for x in aw:
			var side := absf(float(x) - cx) / maxf(cx, 1.0)
			var heat := pow(warm, 1.6) * (1.0 - 0.6 * side * side)
			var p := clampf(v * 0.28 + heat * 0.74, 0.0, 1.0) * last
			var i := mini(floori(p), last - 1)
			var f := p - i
			var thr: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			img.set_pixel(x, y, RAMP[i + 1] if f > thr else RAMP[i])
	# stars in the upper sky, fewer toward the glow
	var seed := 12345
	var n := int(aw * ah * 0.0016)
	for k in n:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var sx := seed % aw
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var sy := int(pow(float(seed % 1000) / 1000.0, 1.7) * ah * 0.55)
		var bright := k % 9 == 0
		img.set_pixel(sx, sy, PixelPalette.STAR[1] if bright else (PixelPalette.STAR[0] if k % 3 == 0 else PixelPalette.NIGHT[4]))
		if bright and sx > 0 and sx < aw - 1 and sy > 0 and sy < ah - 1:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixelv(Vector2i(sx, sy) + d, PixelPalette.NIGHT[4])
	if _sky == null or _sky.get_size() != Vector2(aw, ah):
		_sky = ImageTexture.create_from_image(img)
	else:
		_sky.update(img)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or still:
		return
	_t += delta
	if _t < FRAME_TIME:
		return
	_clock += _t * (0.5 if reduced_motion else 1.0)
	_t = 0.0
	queue_redraw()


func _draw() -> void:
	if _sky != null:
		draw_texture_rect(_sky, Rect2(Vector2.ZERO, Vector2(_sky_size) * PX), false)
	var ah := size.y / PX
	var rise := ah * 0.55
	var count := EMBERS / 3 if reduced_motion else EMBERS
	for i in count:
		var e := _embers[i]
		var up := fmod(_clock * e.y + e.z * rise, rise)
		var k := up / rise
		var x := e.x * size.x / PX + sin(_clock * 0.9 + e.z * 6.28) * e.w * k
		var y := ah - 6.0 - up
		var a := clampf(1.0 - k * 1.15, 0.0, 1.0)
		if a <= 0.02:
			continue
		var c: Color = PixelPalette.FIRE[6] if k < 0.3 else (PixelPalette.FIRE[5] if k < 0.6 else PixelPalette.FIRE[4])
		draw_rect(Rect2(Vector2(roundf(x), roundf(y)) * PX, Vector2(PX, PX)), Color(c, a))
