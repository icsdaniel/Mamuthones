@tool
class_name MamuthonePortrait
extends Control
## A close-up of the player's own Mamuthone, head and shoulders: the carved mask and kerchief, the
## sheepskin with its straps, the chest bells and the tops of the bell load, firelit on a dark ground.
## For the workshop preview and the results screen.
##
##   set_look(mask: Dictionary, fleece := "black", straps := "natural", bell_set := "village")
##       the Profile look (MaskSpec dict, Palette.FLEECE id, Palette.STRAPS id, BellSets id).
##   highlight_part  a MaskSpec part to outline (the one being carved), or "".
##   framed          draw the rough ink frame and the firelit ground (off: transparent, figure only).
## Static: MamuthonePortrait.paint(ci, rect, mask, fleece, straps, bell_set, highlight := "", framed := true)
## Redraws only when the look changes; a draw costs a few ms, so do not animate it every frame.

var mask: Dictionary = MaskSpec.default():
	set(v):
		mask = MaskSpec.sanitize(v)
		queue_redraw()
@export var fleece := "black":
	set(v):
		fleece = v if Palette.FLEECE.has(v) else "black"
		queue_redraw()
@export var straps := "natural":
	set(v):
		straps = v if Palette.STRAPS.has(v) else "natural"
		queue_redraw()
@export_enum("light", "village", "full") var bell_set := "village":
	set(v):
		bell_set = v
		queue_redraw()
@export var highlight_part := "":
	set(v):
		highlight_part = v
		queue_redraw()
@export var framed := true:
	set(v):
		framed = v
		queue_redraw()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural", p_bell_set := "village") -> void:
	mask = p_mask
	fleece = p_fleece
	straps = p_straps
	bell_set = p_bell_set if p_bell_set in ["light", "village", "full"] else "village"


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), mask, fleece, straps, bell_set, highlight_part, framed)


static func paint(ci: CanvasItem, rect: Rect2, p_mask: Dictionary, p_fleece := "black", p_straps := "natural", p_bell_set := "village", highlight := "", p_framed := true) -> void:
	WoodcutDraw.begin(ci)
	var c := rect.get_center()
	if p_framed:
		var bg := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		WoodcutDraw.fill(ci, bg, Palette.NIGHT)
		WoodcutDraw.fill(ci, bg, Color(Palette.BONE, 0.04), Palette.tex("grain"), 1.0 / 600.0)
		WoodcutDraw.glow(ci, rect.position + rect.size * Vector2(0.3, 0.35), maxf(rect.size.x, rect.size.y) * 0.75, Color(Palette.EMBER, 0.5))
		WoodcutDraw.rays(ci, rect.position + rect.size * Vector2(0.5, 0.3), rect.size.y * 0.32, rect.size.y * 0.75, 44, Color(Palette.EMBER, 0.25), rect.size.y * 0.006, 17)
	# The figure, big enough that head and shoulders fill the frame: the mask sits at about 23 % down,
	# the fleece and bells run off the bottom.
	var h := minf(rect.size.y * 2.3, rect.size.x * 2.6)
	var head_y := -89.5 * h / 100.0
	var feet := Vector2(c.x, rect.position.y + rect.size.y * 0.23 - head_y)
	WoodcutDraw.set_transform(ci, feet)
	Figures.mamuthone_back(ci, h, Palette.EMBER, 1, p_bell_set)
	Figures.mamuthone_body(ci, h, p_fleece, p_straps, Palette.EMBER, 1)
	WoodcutDraw.set_transform(ci, Vector2.ZERO)
	MaskView.paint(ci, feet + Vector2(0, head_y), 4.4 * h / 100.0, p_mask, 2, true, highlight, p_straps)
	if p_framed:
		# A rough ink border, like the edge of the printed block.
		var r := rect.grow(-3.0)
		var edge := WoodcutDraw.rough(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), 1.2, 7, 10.0)
		WoodcutDraw.outline(ci, edge, Palette.INK, maxf(4.0, rect.size.x * 0.012), 5)
	WoodcutDraw.end()
