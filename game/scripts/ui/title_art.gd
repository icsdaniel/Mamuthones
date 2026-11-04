class_name TitleArt
extends Control
## The title's picture (tools/art/menu_alt/render_c.py, exported to art/woodcut/title_strip.png: 60
## frames of a two-second loop at 120 bpm, each 135 x 174): drawn as large as fits, centred across,
## with hard edges, on black. The Mamuthone bobs on its beat, the fire leaps, sparks rise.

const STRIP := "res://art/woodcut/title_strip.png"
const FRAME := Vector2(135.0, 174.0)
const FRAMES := 60
const LOOP := 2.0

var _tex: Texture2D
var _t := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_tex = load(STRIP)


func _process(delta: float) -> void:
	if UIKit.animations_off():
		return
	_t = fposmod(_t + delta, LOOP)
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var sc := minf(size.x / FRAME.x, size.y / FRAME.y)
	var sz := FRAME * sc
	var at := Vector2((size.x - sz.x) * 0.5, size.y - sz.y)
	var i := clampi(int(_t / LOOP * FRAMES), 0, FRAMES - 1)
	draw_texture_rect_region(_tex, Rect2(at, sz), Rect2(i * FRAME.x, 0.0, FRAME.x, FRAME.y))
