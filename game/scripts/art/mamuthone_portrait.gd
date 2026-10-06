@tool
class_name MamuthonePortrait
extends Control
## The player's own Mamuthone, whole, standing in the mask-maker's workshop by the hearth (stop 1's
## pixel world, alive: the fire flickers behind him). The figure is the shared big Mamuthone
## (FigureSprites) in the chosen fleece, with the player's look on it (LookArt): the carved mask, the
## straps, the bells of the chosen set. In a gold frame. For the workshop and the results screen.
##
##   set_look(mask: Dictionary, fleece := "black", straps := "natural", bell_set := "village")
##       the Profile look (MaskSpec dict, MaskSpec.FLEECES id, MaskSpec.STRAPS id, BellSets id).
##   highlight_part  a MaskSpec part being carved: gold marks point at the mask, or "".
##   framed          the workshop and the frame round him (off: the figure alone, transparent).
## Static: MamuthonePortrait.paint(ci, rect, mask, fleece, straps, bell_set, highlight := "", framed := true)

## Art pixels the portrait needs to be tall: the big figure plus the frame.
const ART_H := 120
## Where he stands in the workshop world (stop 1), in art pixels.
const SPOT := Vector2(136, 174)

var mask: Dictionary = MaskSpec.default():
	set(v):
		mask = MaskSpec.sanitize(v)
		_redraw()
@export var fleece := "black":
	set(v):
		fleece = v if v in MaskSpec.FLEECES else "black"
		_redraw()
@export var straps := "natural":
	set(v):
		straps = v if v in MaskSpec.STRAPS else "natural"
		_redraw()
@export_enum("light", "village", "full") var bell_set := "village":
	set(v):
		bell_set = v if v in BellSets.IDS else "village"
		_redraw()
@export var highlight_part := "":
	set(v):
		highlight_part = v
		_redraw()
@export var framed := true:
	set(v):
		framed = v
		if _bg != null:
			_bg.visible = v
		_relayout()

## The hearth flickers behind him (off: a still, for reduced motion).
@export var animate := true:
	set(v):
		animate = v
		if _bg != null:
			_bg.animate = v

var _bg: StopPicture
var _fig: _Layer
var _px := 3.0
var _feet := Vector2.ZERO


class _Layer:
	extends Node2D
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg = StopPicture.new()
	_bg.stop = 1
	_bg.view = "band"
	_bg.show_cast = false
	_bg.frame_style = "gold"
	_bg.bpm = 38.0
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_bg.resized.connect(_redraw)
	_fig = _Layer.new()
	_fig.painter = _paint_fig
	_fig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_fig)


func _ready() -> void:
	resized.connect(_relayout)
	_relayout()


func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural", p_bell_set := "village") -> void:
	mask = p_mask
	fleece = p_fleece
	straps = p_straps
	bell_set = p_bell_set


func _redraw() -> void:
	if _fig != null:
		_fig.queue_redraw()


func _relayout() -> void:
	if _bg == null:
		return
	_px = maxf(1.0, minf(PixelFrame.px_for(self), floorf(size.y / float(ART_H))))
	_bg.px = int(_px)
	var vh := size.y / _px - float(PixelFrame.DEPTH) * 2.0
	_bg.focus = Vector2(SPOT.x - 6.0, SPOT.y + 5.0 - vh * 0.5)
	_redraw()


func _paint_fig(ci: CanvasItem) -> void:
	if framed:
		# where SPOT lands on screen, the way StopPicture lays its crop out
		var off := ((_bg.size - _bg.crop.size * _px) * 0.5).floor()
		_feet = off + (SPOT - _bg.crop.position) * _px
	else:
		_feet = Vector2(floorf(size.x * 0.5 / _px) * _px, size.y - _px * 3.0)
	_paint_figure(ci, _feet, _px, mask, fleece, straps, bell_set, highlight_part)


static func _paint_figure(ci: CanvasItem, feet: Vector2, px: float, p_mask: Dictionary, p_fleece: String, p_straps: String, p_bell_set: String, highlight: String) -> void:
	LookArt.draw_back(ci, "big", "stand", feet, false, p_bell_set, px)
	FigureSprites.draw(ci, FigureSprites.mamuthone(p_fleece, "stand", true), feet, px)
	LookArt.draw_front(ci, "big", "stand", feet, false, p_mask, p_straps, p_bell_set, px)
	if highlight != "" and LookCells.MASK.has("big_stand"):
		# two gold diamonds either side of the mask: this is the face being carved
		var r: Rect2i = LookCells.MASK["big_stand"]
		var y := feet.y + (float(r.position.y) + float(r.size.y) * 0.45) * px
		for x in [r.position.x - 6, r.end.x + 5]:
			PixelFrame.diamond(ci, Vector2(feet.x + float(x) * px, y), px, PixelPalette.GOLD[4], 1)


## The portrait into any rect (a still): a navy ground and the frame when framed, the figure on it.
static func paint(ci: CanvasItem, rect: Rect2, p_mask: Dictionary, p_fleece := "black", p_straps := "natural", p_bell_set := "village", highlight := "", p_framed := true) -> void:
	var px := maxf(1.0, floorf(rect.size.y / float(ART_H)))
	if p_framed:
		ci.draw_rect(rect, PixelPalette.NAVY[0])
		PixelFrame.draw(ci, rect, px, "gold")
	var feet := Vector2(rect.position.x + floorf(rect.size.x * 0.5 / px) * px, rect.end.y - (float(PixelFrame.DEPTH) + 3.0) * px)
	_paint_figure(ci, feet, px, MaskSpec.sanitize(p_mask), p_fleece if p_fleece in MaskSpec.FLEECES else "black",
		p_straps if p_straps in MaskSpec.STRAPS else "natural", p_bell_set if p_bell_set in BellSets.IDS else "village", highlight)
