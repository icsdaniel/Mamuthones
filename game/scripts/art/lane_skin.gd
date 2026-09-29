class_name LaneSkin
extends RefCounted
## The play field's layout, and a flat drawing of it in the same pixel art as the play screen
## (FireSkin's sprites, the road's setts and gold rails, the buttons) for the small boards that show
## the lanes without the road's perspective: the lesson pictures and the note-speed preview. Call
## these from a Control's _draw(), passing the Control as `ci`.
##
## Layout helpers:
##   lane_rects(field, lanes := 3) -> Array[Rect2]
##   hit_line_y(field) -> float            (10 % of the field above its bottom)
##   note_y(field, time_to_hit, px_per_s)  (y of a note's centre; time_to_hit > 0 is still coming)
## Drawing (flat, on screen):
##   draw_lanes(ci, field, glow := [0.0, 0.0, 0.0])   glow per lane 0..1 (pressed, holding)
##   draw_hit_line(ci, field, pulse := 0.0)            pulse 0..1 on the beat
##   draw_step(ci, lane_rect, y, call := false, alpha := 1.0)
##   draw_hold(ci, lane_rect, y_head, y_tail, holding := false)
##   draw_bell(ci, field, y, up)
##   draw_ring(ci, field, lane_rect, y, up)
##   draw_swipe(ci, field, y, dir)                     dir 1 right, -1 left
##   draw_rest(ci, field, y_top, y_bottom)
##   draw_button(ci, rect, lane, state)                state "idle" | "cued" | "pressed" | "hit" | "miss"
##   draw_hit_burst(ci, pos, quality, age, size := 1.0) -> bool   false once finished (BURST_TIME)

const BURST_TIME := 0.4
const NOTE_H := 0.2     ## step height as a fraction of lane width
const BAR_H := 46.0     ## bell bar height in pixels

const LANE_FILL := Color("#1d1d29")   ## SETT1
const LANE_ALT := Color("#262634")    ## SETT2

## The woodcut note sprites are gone (the pixel sprites live in res://art/px/field/, FireCells); these
## stay so older tools that bake them find nothing to do.
const NOTES_DIR := "res://art/notes/"
const SPRITE_SCALE := 2.0
static var use_sprites := true


static func lane_rects(field: Rect2, lanes := 3) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := field.size.x / float(lanes)
	for i in lanes:
		out.append(Rect2(field.position.x + w * float(i), field.position.y, w, field.size.y))
	return out


static func hit_line_y(field: Rect2) -> float:
	return field.end.y - field.size.y * 0.1


static func note_y(field: Rect2, time_to_hit: float, px_per_s: float) -> float:
	return hit_line_y(field) - time_to_hit * px_per_s


## No baked woodcut sprites any more (kept for tools/art/bake.sh).
static func sprite_jobs() -> Array:
	return []


static func sprite(_name: String) -> Texture2D:
	return null


static func cell_size(_name: String) -> Vector2:
	return Vector2.ONE


static func _sc(lane_w: float) -> float:
	return lane_w / FireSkin.REF_LANE


# ------------------------------------------------------------------ drawing

## The lanes: dark setts in courses (a mortar row every 8 art px, running bond), a lane lighter where
## it glows, gold rails at the road's edges and between the lanes.
static func draw_lanes(ci: CanvasItem, field: Rect2, glow: Array = [0.0, 0.0, 0.0]) -> void:
	var P := PxArt.PX
	var S := PixelPalette.SETT
	ci.draw_rect(field, S[1])
	var lanes := lane_rects(field)
	for i in lanes.size():
		var g: float = glow[i] if i < glow.size() else 0.0
		if g > 0.3:
			ci.draw_rect(lanes[i], S[3] if g > 0.7 else S[2])
	# mortar courses and joints
	var course := 8.0 * P
	var bw := field.size.x / 12.0
	var y := field.position.y + course
	var row := 0
	while y < field.end.y:
		ci.draw_rect(Rect2(field.position.x, y, field.size.x, P), S[0])
		var off := bw * 0.5 if row % 2 == 1 else 0.0
		var x := field.position.x + off + bw
		while x < field.end.x:
			ci.draw_rect(Rect2(roundf(x / P) * P, y - course + P, P, course - P), S[0])
			x += bw
		y += course
		row += 1
	# the rails: a hot core with ember edges
	for i in 4:
		var rx := roundf((field.position.x + field.size.x * float(i) / 3.0) / P) * P
		rx = clampf(rx, field.position.x + P, field.end.x - 2.0 * P)
		ci.draw_rect(Rect2(rx - P, field.position.y, 3.0 * P, field.size.y), PixelPalette.FIRE[3])
		ci.draw_rect(Rect2(rx, field.position.y, P, field.size.y), PixelPalette.FIRE[6])


static func draw_hit_line(ci: CanvasItem, field: Rect2, pulse := 0.0) -> void:
	var lanes := lane_rects(field)
	var xs := []
	for r in lanes:
		xs.append(r.get_center().x)
	var y := roundf(hit_line_y(field) / PxArt.PX) * PxArt.PX
	FireSkin.draw_hit_line(ci, field.position.x, field.end.x, y, xs, 0.33 * lanes[0].size.x, [], pulse)


static func draw_step(ci: CanvasItem, lane: Rect2, y: float, call := false, alpha := 1.0) -> void:
	FireSkin.draw_gem(ci, Vector2(lane.get_center().x, y), _sc(lane.size.x), call, alpha)


static func draw_hold(ci: CanvasItem, lane: Rect2, y_head: float, y_tail: float, holding := false) -> void:
	var sc := _sc(lane.size.x)
	FireSkin.draw_sash(ci, lane, y_head, y_tail, holding)
	FireSkin.draw_hold_ring(ci, Vector2(lane.get_center().x, y_tail), sc)
	FireSkin.draw_gem(ci, Vector2(lane.get_center().x, y_head), sc)


static func draw_bell(ci: CanvasItem, field: Rect2, y: float, up: bool) -> void:
	var sc := _sc(field.size.x / 3.0)
	FireSkin.draw_bar(ci, field.position.x, field.end.x, y, sc, up)
	FireSkin.draw_badge(ci, Vector2(field.get_center().x, y), sc)


static func draw_ring(ci: CanvasItem, field: Rect2, lane: Rect2, y: float, up: bool) -> void:
	draw_bell(ci, field, y, up)
	var sc := _sc(lane.size.x)
	var rr := float(FireSkin.note_rx(sc)) + 4.0
	var p := Vector2(lane.get_center().x, y)
	FireSkin.px_ring(ci, p + Vector2(0, PxArt.PX), rr, rr * 0.46 + 1.0, 2.0, PixelPalette.RED[3])
	FireSkin.draw_gem(ci, p, sc)


static func draw_swipe(ci: CanvasItem, field: Rect2, y: float, dir: int) -> void:
	FireSkin.draw_rope(ci, Vector2(field.get_center().x, y), field.size.x, dir)


static func draw_rest(ci: CanvasItem, field: Rect2, y_top: float, y_bottom: float) -> void:
	FireSkin.draw_band(ci, field, y_top, y_bottom)


static func draw_button(ci: CanvasItem, rect: Rect2, lane: int, state: String) -> void:
	FireSkin.draw_button(ci, rect, lane, state)


static func draw_hit_burst(ci: CanvasItem, pos: Vector2, quality: String, age: float, size := 1.0) -> bool:
	return FireSkin.draw_burst(ci, pos, quality, age, size)
