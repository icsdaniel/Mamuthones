class_name MenuBackdrop
extends Control
## The stone every menu-type screen stands on (App puts one behind the screen stack): a wall of worn
## dark ashlar, warm from the torch and brazier light below, with wall torches burning in the side
## gutters. Pixel art from tools/art/pixel/ui_kit.py, drawn x3 with nearest filtering, anchored at the
## bottom centre so it covers any phone or tablet shape. The flames step through their frames and the
## glows flicker in steps (never smooth), a third as much with reduced motion.

const PX := 3.0
const FRAME_TIME := 0.11
## Torches as (side, height as a fraction of the screen): in the side gutters, clear of the text.
const TORCHES := [[-1, 0.47], [1, 0.47], [-1, 0.8], [1, 0.8]]

var reduced_motion := false
var still := false                ## animations off: the torches stand still
var _wall: Texture2D
var _frames: Array[Texture2D] = []
var _glows: Array[TextureRect] = []
var _frame := [0, 2, 1, 3]
var _t := 0.0
var _seed := 1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Backdrop"


func _ready() -> void:
	_wall = Palette.px("ui/backdrop")
	for i in 4:
		_frames.append(Palette.px("ui/torch_%d" % i))
	var glow_tex := Palette.px("ui/torch_glow")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in TORCHES.size():
		var g := TextureRect.new()
		g.texture = glow_tex
		g.material = add
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_SCALE
		g.modulate.a = 0.6
		add_child(g)
		_glows.append(g)
	resized.connect(_place)
	_place()


func _torch_pos(i: int) -> Vector2:
	var side: int = TORCHES[i][0]
	var x := 0.0 if side < 0 else size.x - 11.0 * PX   # hard against the edge, clear of the column
	return Vector2(x, roundf(size.y * float(TORCHES[i][1]) / PX) * PX)


func _place() -> void:
	if _glows.is_empty():
		return
	for i in _glows.size():
		_flicker(i, 0.0)
	queue_redraw()


## Steps one glow to a new size and strength.
func _flicker(i: int, amount: float) -> void:
	var g := _glows[i]
	var gs := g.texture.get_size() * PX if g.texture != null else Vector2(240, 240)
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	var r := float(_seed % 1000) / 1000.0
	var k := 1.0 + (r - 0.5) * 0.16 * amount
	var sz := (gs * k / PX).round() * PX
	var p := _torch_pos(i) + Vector2(5.5 * PX, 4.0 * PX)
	g.size = sz
	g.position = (p - sz * 0.5).round()
	g.modulate.a = 0.42 + 0.14 * (r - 0.5) * amount


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if still:
		return
	_t += delta
	if _t < FRAME_TIME:
		return
	_t = 0.0
	var amount := 0.33 if reduced_motion else 1.0
	for i in _frame.size():
		_frame[i] = (_frame[i] + 1) % _frames.size()
		_flicker(i, amount)
	queue_redraw()


func _draw() -> void:
	if _wall != null:
		var ws := _wall.get_size() * PX
		var pos := Vector2(roundf((size.x - ws.x) * 0.5), size.y - ws.y)
		if pos.y > 0.0:
			draw_rect(Rect2(0, 0, size.x, pos.y + 1.0), PixelPalette.K[0])
		draw_texture_rect(_wall, Rect2(pos, ws), false)
	if _frames.is_empty() or _frames[0] == null:
		return
	for i in TORCHES.size():
		var tex := _frames[_frame[i] % _frames.size()]
		var p := _torch_pos(i)
		draw_texture_rect(tex, Rect2(p, tex.get_size() * PX), false)
