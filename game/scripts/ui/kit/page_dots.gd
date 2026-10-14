class_name PageDots
extends Control
## Where a carousel or pager is: one small sunk dot per page, the current one a wider bronze pill,
## pages already done (cleared stops) a dim bronze dot. Pixel-crisp on the 3-px grid; drawn only when
## the page changes.

const PX := 3.0
const DOT := 4        ## art px
const WIDE := 10      ## the current one, art px
const GAP := 4        ## art px

var count := 1:
	set(v):
		count = maxi(v, 1)
		_resize()
var current := 0:
	set(v):
		current = v
		queue_redraw()
## Indices drawn as done (a dim bronze dot instead of the sunk one).
var done: Array[int] = []


func _init(p_count := 1, p_current := 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count = p_count
	current = p_current
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _resize() -> void:
	var w := (count - 1) * (DOT + GAP) + WIDE
	custom_minimum_size = Vector2(w, DOT + 2) * PX
	queue_redraw()


func _draw() -> void:
	var x := floorf((size.x / PX - ((count - 1) * (DOT + GAP) + WIDE)) * 0.5)
	var y := floorf((size.y / PX - DOT) * 0.5)
	for i in count:
		var w := WIDE if i == current else DOT
		var c: Color = WoodcutTheme.C_BRONZE if i == current else (WoodcutTheme.C_BRONZE_DEEP if i in done else WoodcutTheme.C_STROKE)
		var r := Rect2i(int(x), int(y), w, DOT)
		# a pill: the corners cut by one art pixel
		draw_rect(Rect2(Vector2(r.position.x + 1, r.position.y) * PX, Vector2(r.size.x - 2, r.size.y) * PX), c)
		draw_rect(Rect2(Vector2(r.position.x, r.position.y + 1) * PX, Vector2(r.size.x, r.size.y - 2) * PX), c)
		if i == current:
			draw_rect(Rect2(Vector2(r.position.x + 1, r.position.y) * PX, Vector2(r.size.x - 2, 1) * PX), WoodcutTheme.C_BRONZE_HI)
		x += w + GAP
