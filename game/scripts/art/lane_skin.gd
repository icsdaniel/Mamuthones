class_name LaneSkin
extends RefCounted
## Static drawing of the play field in the woodcut style. Call these from a Control's _draw(),
## passing the Control as `ci`. Everything is built from a few triangles per shape (no textures to
## load per note), so a full screen of notes costs well under a millisecond.
##
## Each note kind has its own shape and its own ink, so they stay apart in greyscale and at arm's length:
##   step   a pale carved block in one lane with a dark groove across it
##   call   (off-beat step) an ember block with pointed ends and a dark diamond
##   hold   a step head with a hatched column up to a small cap
##   bell   a bone bar across all lanes, three big dark chevrons pointing up or down, a bell in a ring
##   ring   (full ring) the bell bar with a step block standing proud of it in its lane, ringed in red
##   swipe  the red twisted rope across all lanes with a big arrowhead showing the direction
##   rest   (stand still) a grey, diagonally hatched band spanning the lanes, closed by two rules
##
## Layout helpers:
##   lane_rects(field, lanes := 3) -> Array[Rect2]
##   hit_line_y(field) -> float            (10 % of the field above its bottom)
##   note_y(field, time_to_hit, px_per_s)  (y of a note's centre; time_to_hit > 0 is still coming)
## Drawing:
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
##       quality perfect | good | early | late | miss | held | wrong. Early bursts spray upward with
##       an ember up-chevron, late ones downward with a red down-chevron (ink-outlined), so timing reads
##       without words; a perfect also shoots an ember streak up its lane.

## Notes, bars, buttons, the lanes and the hit line are drawn from sprites baked by tools/art/bake.sh
## (game/art/notes/) from the vec_* functions below, so each is one batched textured rect per frame.
## If a sprite is missing, the vector version is drawn instead (same look, more draw calls).

const BURST_TIME := 0.4
const NOTE_H := 0.2     ## step height as a fraction of lane width
const BAR_H := 46.0     ## bell bar height in pixels

const LANE_FILL := Color("#15110f")
const LANE_ALT := Color("#1b1613")


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



# ------------------------------------------------------------------ sprites

const NOTES_DIR := "res://art/notes/"
const REF_LANE := 240.0
const REF_FIELD := 720.0
const REF_FIELD_H := 1100.0
## Baked sprite cells in reference pixels: [size, y of the note's centre]. Baked at SPRITE_SCALE.
const CELLS := {
	"step": [Vector2(240, 80), 40.0],
	"call": [Vector2(240, 80), 40.0],
	"bell_up": [Vector2(720, 90), 45.0],
	"bell_down": [Vector2(720, 90), 45.0],
	"ring_block": [Vector2(240, 110), 55.0],
	"swipe_r": [Vector2(720, 100), 50.0],
	"swipe_l": [Vector2(720, 100), 50.0],
	"hold_cap": [Vector2(240, 40), 20.0],
	"hit_line": [Vector2(720, 48), 24.0],
	"lanes": [Vector2(720, 1100), 0.0],
}
const BUTTON_CELL := Vector2(240, 150)
const BUTTON_STATES := ["idle", "cued", "pressed", "hit", "miss"]
const SPRITE_SCALE := 2.0

## Set false to always draw vectors (the bake does this).
static var use_sprites := true
static var _sprites := {}


static func sprite(name: String) -> Texture2D:
	if not use_sprites:
		return null
	if _sprites.has(name):
		return _sprites[name]
	var path := NOTES_DIR + name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			tex = ImageTexture.create_from_image(img)
	_sprites[name] = tex
	return tex


## Every sprite the bake should produce, as [name, painter(ci)] drawing into a cell of reference size.
static func sprite_jobs() -> Array:
	var jobs := []
	var lane := Rect2(0, 0, REF_LANE, 80)
	jobs.append(["step", func(ci): vec_step(ci, lane, 40.0, false)])
	jobs.append(["call", func(ci): vec_step(ci, lane, 40.0, true)])
	var field := Rect2(0, 0, REF_FIELD, 90)
	jobs.append(["bell_up", func(ci): vec_bell(ci, field, 45.0, true)])
	jobs.append(["bell_down", func(ci): vec_bell(ci, field, 45.0, false)])
	jobs.append(["ring_block", func(ci): _ring_block(ci, Rect2(0, 0, REF_LANE, 110), 55.0)])
	var sfield := Rect2(0, 0, REF_FIELD, 100)
	jobs.append(["swipe_r", func(ci): vec_swipe(ci, sfield, 50.0, 1)])
	jobs.append(["swipe_l", func(ci): vec_swipe(ci, sfield, 50.0, -1)])
	jobs.append(["hold_cap", func(ci): _hold_cap(ci, REF_LANE * 0.5, REF_LANE * 0.34, 20.0)])
	jobs.append(["hit_line", func(ci): vec_hit_line(ci, Rect2(0, 24.0 - 1100.0 * 0.9, REF_FIELD, 1100.0), 0.0)])
	jobs.append(["lanes", func(ci): vec_lanes(ci, Rect2(0, 0, REF_FIELD, REF_FIELD_H))])
	for l in 3:
		for st in BUTTON_STATES:
			jobs.append(["button_%d_%s" % [l, st], func(ci): vec_button(ci, Rect2(Vector2.ZERO, BUTTON_CELL), l, st)])
	return jobs


static func cell_size(name: String) -> Vector2:
	if name.begins_with("button_"):
		return BUTTON_CELL
	return CELLS[name][0]


## Draws sprite `name` so its reference cell spans x0..x0+width with the note centre at y, cropped to
## `clip` (notes never spill out of their lane or field).
static func _blit(ci: CanvasItem, tex: Texture2D, name: String, x0: float, width: float, y: float, clip: Rect2) -> void:
	var cell: Array = CELLS[name]
	var sz: Vector2 = cell[0]
	var k := width / sz.x
	_draw_clipped(ci, tex, Rect2(x0, y - float(cell[1]) * k, width, sz.y * k), clip)


## Draws `tex` stretched over `dest`, keeping only the part inside `clip` (by cropping the source
## region, so it stays one batched textured rect).
static func _draw_clipped(ci: CanvasItem, tex: Texture2D, dest: Rect2, clip: Rect2, modulate := Color.WHITE) -> void:
	_mip(ci)
	var vis := dest.intersection(clip)
	if vis.size.x <= 0.5 or vis.size.y <= 0.5:
		return
	if vis.is_equal_approx(dest):
		ci.draw_texture_rect(tex, dest, false, modulate)
		return
	var ts := Vector2(tex.get_size())
	var src := Rect2((vis.position - dest.position) / dest.size * ts, vis.size / dest.size * ts)
	ci.draw_texture_rect_region(tex, vis, src, modulate)


## Sprites are baked at 2x with mipmaps; sample them with a mipmapped filter so they stay clean when
## drawn smaller (narrow phones). This sets the canvas item's default filter; textures without
## mipmaps drawn on it look exactly as before.
static func _mip(ci: CanvasItem) -> void:
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)


## True when a vector note at y (half height `half`) is at least partly inside `clip`.
static func _visible(clip: Rect2, y: float, half: float) -> bool:
	return y + half > clip.position.y and y - half < clip.end.y


# ------------------------------------------------------------------ public drawing

static func draw_lanes(ci: CanvasItem, field: Rect2, glow: Array = [0.0, 0.0, 0.0]) -> void:
	var tex := sprite("lanes")
	if tex == null:
		vec_lanes(ci, field, glow)
		return
	_mip(ci)
	ci.draw_texture_rect(tex, field, false)
	var gt := Palette.tex("glow")
	var lanes := lane_rects(field, 3)
	for i in lanes.size():
		var g: float = glow[i] if i < glow.size() else 0.0
		if g > 0.0 and gt:
			var r: Rect2 = lanes[i]
			ci.draw_texture_rect(gt, Rect2(r.position.x - r.size.x * 0.1, hit_line_y(field) - r.size.x * 0.9, r.size.x * 1.2, r.size.x * 1.4), false, Color(Palette.EMBER, 0.55 * g))


static func draw_hit_line(ci: CanvasItem, field: Rect2, pulse := 0.0) -> void:
	var tex := sprite("hit_line")
	if tex == null:
		vec_hit_line(ci, field, pulse)
		return
	_mip(ci)
	var y := hit_line_y(field)
	if pulse > 0.0:
		var gt := Palette.tex("glow")
		if gt:
			ci.draw_texture_rect(gt, Rect2(field.position.x, y - 60.0, field.size.x, 120.0), false, Color(Palette.EMBER, 0.35 * pulse))
	var cell: Array = CELLS["hit_line"]
	var sz: Vector2 = cell[0]
	ci.draw_texture_rect(tex, Rect2(field.position.x, y - float(cell[1]), field.size.x, sz.y), false, Color.WHITE.lerp(Color(1.25, 1.1, 0.9), pulse))


static func draw_step(ci: CanvasItem, lane: Rect2, y: float, call := false, alpha := 1.0) -> void:
	var name := "call" if call else "step"
	var tex := sprite(name)
	if tex == null:
		if _visible(lane, y, lane.size.x * NOTE_H):
			vec_step(ci, lane, y, call, alpha)
		return
	var cell: Array = CELLS[name]
	var sz: Vector2 = cell[0]
	var k := lane.size.x / sz.x
	_draw_clipped(ci, tex, Rect2(lane.position.x, y - float(cell[1]) * k, lane.size.x, sz.y * k), lane, Color(1, 1, 1, alpha))


static func draw_hold(ci: CanvasItem, lane: Rect2, y_head: float, y_tail: float, holding := false) -> void:
	var cap := sprite("hold_cap")
	if cap == null or sprite("step") == null:
		vec_hold(ci, lane, y_head, y_tail, holding)
		return
	var cx := lane.get_center().x
	var bw := lane.size.x * 0.34
	var top := maxf(minf(y_head, y_tail), lane.position.y)
	var bottom := minf(maxf(y_head, y_tail), lane.end.y)
	if bottom - top > 2.0:
		var col := Rect2(cx - bw * 0.5, top, bw, bottom - top)
		ci.draw_rect(col, Palette.EMBER if holding else Color("#4a4038"))
		var hatch := Palette.tex("hatch")
		if hatch:
			RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
			ci.draw_texture_rect(hatch, col, true, Color(Palette.INK if holding else Palette.BONE, 0.55))
		ci.draw_rect(Rect2(col.position.x - 1.5, top, 3.0, col.size.y), Palette.EMBER_HOT if holding else Palette.BONE)
		ci.draw_rect(Rect2(col.end.x - 1.5, top, 3.0, col.size.y), Palette.INK)
	_blit(ci, cap, "hold_cap", lane.position.x, lane.size.x, y_tail, lane)
	draw_step(ci, lane, y_head, false)
	if holding:
		var gt := Palette.tex("glow")
		if gt:
			_draw_clipped(ci, gt, Rect2(cx - lane.size.x * 0.6, y_head - lane.size.x * 0.5, lane.size.x * 1.2, lane.size.x), lane.grow_individual(lane.size.x * 0.1, 0, lane.size.x * 0.1, 0), Color(Palette.EMBER, 0.6))


static func draw_bell(ci: CanvasItem, field: Rect2, y: float, up: bool) -> void:
	var name := "bell_up" if up else "bell_down"
	var tex := sprite(name)
	if tex == null:
		if _visible(field, y, BAR_H):
			vec_bell(ci, field, y, up)
		return
	# Bars keep their height and stretch only in width, like the vector version.
	var cell: Array = CELLS[name]
	var sz: Vector2 = cell[0]
	_draw_clipped(ci, tex, Rect2(field.position.x, y - float(cell[1]), field.size.x, sz.y), field)


static func draw_ring(ci: CanvasItem, field: Rect2, lane: Rect2, y: float, up: bool) -> void:
	var block := sprite("ring_block")
	if block == null:
		vec_ring(ci, field, lane, y, up)
		return
	draw_bell(ci, field, y, up)
	_blit(ci, block, "ring_block", lane.position.x, lane.size.x, y, field)


static func draw_swipe(ci: CanvasItem, field: Rect2, y: float, dir: int) -> void:
	var name := "swipe_r" if dir >= 0 else "swipe_l"
	var tex := sprite(name)
	if tex == null:
		if _visible(field, y, 50.0):
			vec_swipe(ci, field, y, dir)
		return
	var cell: Array = CELLS[name]
	var sz: Vector2 = cell[0]
	_draw_clipped(ci, tex, Rect2(field.position.x, y - float(cell[1]), field.size.x, sz.y), field)


static func draw_button(ci: CanvasItem, rect: Rect2, lane: int, state: String) -> void:
	if not (state in BUTTON_STATES):
		state = "idle"
	var tex := sprite("button_%d_%s" % [clampi(lane, 0, 2), state])
	if tex == null:
		vec_button(ci, rect, lane, state)
		return
	_mip(ci)
	ci.draw_texture_rect(tex, rect, false)


# ------------------------------------------------------------------ vector versions (bake sources)

# ------------------------------------------------------------------ field

static func vec_lanes(ci: CanvasItem, field: Rect2, glow: Array = [0.0, 0.0, 0.0]) -> void:
	WoodcutDraw.begin(ci)
	var lanes := lane_rects(field, 3)
	var grain := Palette.tex("grain")
	# Vertical grain: rotate the texture so its lines run down the lanes (never across, where bars are).
	var uv := Transform2D(PI * 0.5, Vector2(1.0 / 420.0, 1.0 / 420.0), 0.0, Vector2.ZERO)
	for i in lanes.size():
		var r: Rect2 = lanes[i]
		var pts := _rect_pts(r)
		WoodcutDraw.fill_fan(ci, pts, LANE_FILL if i % 2 == 0 else LANE_ALT)
		WoodcutDraw.fill_fan(ci, pts, Color(Palette.BONE, 0.05), grain, uv)
		var g: float = glow[i] if i < glow.size() else 0.0
		if g > 0.0:
			var tex := Palette.tex("glow")
			if tex:
				WoodcutDraw.flush()
				ci.draw_texture_rect(tex, Rect2(r.position.x - r.size.x * 0.1, hit_line_y(field) - r.size.x * 0.9, r.size.x * 1.2, r.size.x * 1.4), false, Color(Palette.EMBER, 0.55 * g))
	# Carved separators between the lanes: broken bone gouges.
	for i in range(1, lanes.size()):
		var x: float = lanes[i].position.x
		var y := field.position.y
		var k := 0
		while y < field.end.y:
			var seg := 40.0 + 50.0 * WoodcutDraw.hash01(k, i)
			var y1 := minf(y + seg, field.end.y)
			WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(x + (WoodcutDraw.hash01(k, i + 5) - 0.5) * 2.0, y), Vector2(x, y1)]), Color(Palette.BONE, 0.22), 0.6, 0.6, 2.4)
			y = y1 + 6.0 + 8.0 * WoodcutDraw.hash01(k, i + 9)
			k += 1
	# Ink edges on the outer sides.
	for x in [field.position.x, field.end.x]:
		WoodcutDraw.line(ci, Vector2(x, field.position.y), Vector2(x, field.end.y), Palette.INK, 4.0)
	WoodcutDraw.end()


static func vec_hit_line(ci: CanvasItem, field: Rect2, pulse := 0.0) -> void:
	WoodcutDraw.begin(ci)
	var y := hit_line_y(field)
	if pulse > 0.0:
		var tex := Palette.tex("glow")
		if tex:
				WoodcutDraw.flush()
				ci.draw_texture_rect(tex, Rect2(field.position.x, y - 60.0, field.size.x, 120.0), false, Color(Palette.EMBER, 0.35 * pulse))
	# A deep carved bar with a bone lip, notched at every lane centre.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var x := field.position.x + field.size.x * float(i) / float(n)
		top.append(Vector2(x, y - 7.0 + (WoodcutDraw.hash01(i, 3) - 0.5) * 2.0))
		bottom.append(Vector2(x, y + 7.0 + (WoodcutDraw.hash01(i, 4) - 0.5) * 2.0))
	var band := top.duplicate()
	for i in range(n, -1, -1):
		band.append(bottom[i])
	WoodcutDraw.fill(ci, band, Palette.BONE_DIM.lerp(Palette.EMBER_HOT, pulse * 0.6))
	WoodcutDraw.fill(ci, band, Color(Palette.INK, 0.3), Palette.tex("chisel"), 1.0 / 120.0)
	WoodcutDraw.stroke(ci, top, Palette.INK, 3.0, 3.0)
	WoodcutDraw.stroke(ci, bottom, Palette.INK, 3.0, 3.0)
	for r in lane_rects(field, 3):
		var cx := r.get_center().x
		var tri := PackedVector2Array([Vector2(cx - 14, y - 10), Vector2(cx + 14, y - 10), Vector2(cx, y + 8)])
		WoodcutDraw.fill_fan(ci, tri, Color(Palette.EMBER, 0.85 + 0.15 * pulse))
		_ring(ci, tri, Palette.INK, 2.0)
	WoodcutDraw.end()


# ------------------------------------------------------------------ notes

static func vec_step(ci: CanvasItem, lane: Rect2, y: float, call := false, alpha := 1.0) -> void:
	WoodcutDraw.begin(ci)
	var w := lane.size.x * 0.76
	var h := maxf(26.0, lane.size.x * NOTE_H)
	var cx := lane.get_center().x
	var r := Rect2(cx - w * 0.5, y - h * 0.5, w, h)
	var salt := int(lane.position.x) % 97
	# Shadow first, so the block stands off the lane.
	if call:
		var shape := _hex(r)
		WoodcutDraw.fill_fan(ci, _offset(shape, Vector2(3, 5)), Color(Palette.INK, 0.7 * alpha))
		WoodcutDraw.fill_fan(ci, shape, Color(Palette.EMBER, alpha))
		WoodcutDraw.fill_fan(ci, shape, Color(Palette.INK, 0.25 * alpha), Palette.tex("chisel"), Transform2D(0.0, Vector2(1.0 / 160.0, 1.0 / 160.0), 0.0, Vector2.ZERO))
		_ring(ci, shape, Color(Palette.RED_DEEP, alpha), 3.0)
		var d := h * 0.34
		WoodcutDraw.fill_fan(ci, PackedVector2Array([Vector2(cx, y - d), Vector2(cx + d * 1.2, y), Vector2(cx, y + d), Vector2(cx - d * 1.2, y)]), Color(Palette.INK, alpha))
		WoodcutDraw.fill_fan(ci, PackedVector2Array([Vector2(cx - w * 0.3, y - 2), Vector2(cx - d * 1.6, y - 2), Vector2(cx - d * 1.6, y + 2), Vector2(cx - w * 0.3, y + 2)]), Color(Palette.INK, 0.8 * alpha))
		WoodcutDraw.fill_fan(ci, PackedVector2Array([Vector2(cx + d * 1.6, y - 2), Vector2(cx + w * 0.3, y - 2), Vector2(cx + w * 0.3, y + 2), Vector2(cx + d * 1.6, y + 2)]), Color(Palette.INK, 0.8 * alpha))
		WoodcutDraw.end()
		return
	var block := WoodcutDraw.rough_rect(r, h * 0.3, 1.4, salt)
	WoodcutDraw.fill_fan(ci, _offset(block, Vector2(3, 5)), Color(Palette.INK, 0.7 * alpha))
	WoodcutDraw.fill_fan(ci, block, Color(Palette.BONE, alpha))
	WoodcutDraw.fill_fan(ci, block, Color(Palette.INK, 0.18 * alpha), Palette.tex("chisel"), Transform2D(0.0, Vector2(1.0 / 160.0, 1.0 / 160.0), 0.0, Vector2(float(salt) * 0.01, 0.0)))
	_ring(ci, block, Color(Palette.INK, alpha), 2.5)
	# The groove: one gouge across the block.
	WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(r.position.x + w * 0.16, y + 1), Vector2(cx, y - 1), Vector2(r.end.x - w * 0.16, y + 1)]), Color(Palette.INK, 0.9 * alpha), 2.0, 2.0, h * 0.26)
	WoodcutDraw.end()


static func vec_hold(ci: CanvasItem, lane: Rect2, y_head: float, y_tail: float, holding := false) -> void:
	WoodcutDraw.begin(ci)
	var cx := lane.get_center().x
	var bw := lane.size.x * 0.34
	var top := maxf(minf(y_head, y_tail), lane.position.y)
	var bottom := minf(maxf(y_head, y_tail), lane.end.y)
	var col := Rect2(cx - bw * 0.5, top, bw, bottom - top)
	if col.size.y > 2.0:
		var pts := _rect_pts(col)
		WoodcutDraw.fill_fan(ci, pts, Palette.EMBER if holding else Color("#4a4038"))
		WoodcutDraw.fill_fan(ci, pts, Color(Palette.INK if holding else Palette.BONE, 0.55), Palette.tex("hatch"), Transform2D(0.0, Vector2(1.0 / 96.0, 1.0 / 96.0), 0.0, Vector2.ZERO))
		WoodcutDraw.line(ci, Vector2(col.position.x, top), Vector2(col.position.x, bottom), Palette.BONE if not holding else Palette.EMBER_HOT, 3.0)
		WoodcutDraw.line(ci, Vector2(col.end.x, top), Vector2(col.end.x, bottom), Palette.INK, 3.0)
	if _visible(lane, y_tail, 20.0):
		_hold_cap(ci, cx, bw, y_tail)
	if _visible(lane, y_head, lane.size.x * NOTE_H):
		vec_step(ci, lane, y_head, false)
	if holding:
		var tex := Palette.tex("glow")
		if tex:
				WoodcutDraw.flush()
				ci.draw_texture_rect(tex, Rect2(cx - lane.size.x * 0.6, y_head - lane.size.x * 0.5, lane.size.x * 1.2, lane.size.x), false, Color(Palette.EMBER, 0.6))
	WoodcutDraw.end()


static func vec_bell(ci: CanvasItem, field: Rect2, y: float, up: bool) -> void:
	WoodcutDraw.begin(ci)
	var h := BAR_H
	var r := Rect2(field.position.x + 6.0, y - h * 0.5, field.size.x - 12.0, h)
	var bar := WoodcutDraw.rough_rect(r, 10.0, 1.6, 21 if up else 22)
	WoodcutDraw.fill_fan(ci, _offset(bar, Vector2(3, 6)), Color(Palette.INK, 0.75))
	WoodcutDraw.fill_fan(ci, bar, Palette.BONE)
	WoodcutDraw.fill_fan(ci, bar, Color(Palette.INK, 0.14), Palette.tex("grain"), Transform2D(0.0, Vector2(1.0 / 300.0, 1.0 / 300.0), 0.0, Vector2.ZERO))
	_ring(ci, bar, Palette.INK, 3.0)
	# Chevrons across the bar, pointing the way the bell swings.
	var dir := -1.0 if up else 1.0
	var cx := field.get_center().x
	var ch := h * 0.28
	for i in 6:
		var t := (float(i) + 0.5) / 6.0
		var x := field.position.x + field.size.x * t
		if absf(x - cx) < h * 0.9:
			continue
		var tip := Vector2(x, y + dir * ch)
		var wing := h * 0.5
		var chev := PackedVector2Array([Vector2(x - wing, y - dir * ch), tip, Vector2(x + wing, y - dir * ch)])
		WoodcutDraw.stroke(ci, chev, Palette.INK, 7.0, 7.0, 8.0)
	# The bell itself in a carved ring at the centre.
	WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(Vector2(cx, y), Vector2(h * 0.78, h * 0.78), 20), Palette.INK)
	WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(Vector2(cx, y), Vector2(h * 0.66, h * 0.66), 20), Palette.RED)
	_bell_glyph(ci, Vector2(cx, y + h * 0.04), h * 0.62, Palette.BONE, up)
	WoodcutDraw.end()


static func vec_ring(ci: CanvasItem, field: Rect2, lane: Rect2, y: float, up: bool) -> void:
	vec_bell(ci, field, y, up)
	_ring_block(ci, lane, y)


## The full ring's step: it stands proud of the bell bar in its lane, doubled with a red ring.
static func _ring_block(ci: CanvasItem, lane: Rect2, y: float) -> void:
	WoodcutDraw.begin(ci)
	var w := lane.size.x * 0.82
	var h := BAR_H * 1.5
	var r := Rect2(lane.get_center().x - w * 0.5, y - h * 0.5, w, h)
	var outer := WoodcutDraw.rough_rect(r.grow(5.0), h * 0.3, 1.5, 31)
	WoodcutDraw.fill_fan(ci, outer, Palette.RED)
	_ring(ci, outer, Palette.INK, 2.5)
	vec_step(ci, lane, y, false)
	WoodcutDraw.end()


static func vec_swipe(ci: CanvasItem, field: Rect2, y: float, dir: int) -> void:
	WoodcutDraw.begin(ci)
	var d := 1.0 if dir >= 0 else -1.0
	var x0 := field.position.x + 16.0
	var x1 := field.end.x - 16.0
	var head_len := 64.0
	var start := x0 if d > 0 else x1
	var end := (x1 - head_len) if d > 0 else (x0 + head_len)
	# The rope: a thick twisted cord with a gentle sag.
	var pts := PackedVector2Array()
	var n := 18
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(Vector2(lerpf(start, end, t), y + sin(t * PI) * 8.0))
	WoodcutDraw.stroke(ci, _offset(pts, Vector2(3, 6)), Color(Palette.INK, 0.7), 20.0, 20.0, 20.0)
	WoodcutDraw.stroke(ci, pts, Palette.INK, 22.0, 22.0, 22.0)
	WoodcutDraw.stroke(ci, pts, Palette.RED, 16.0, 16.0, 16.0)
	# Twists: short diagonal cuts along the cord.
	var len_x := absf(end - start)
	var twists := int(len_x / 16.0)
	for i in twists:
		var t := (float(i) + 0.5) / float(twists)
		var p := Vector2(lerpf(start, end, t), y + sin(t * PI) * 8.0)
		WoodcutDraw.line(ci, p + Vector2(-5.0 * d, -8.0), p + Vector2(5.0 * d, 8.0), Palette.RED_DEEP, 4.0)
		WoodcutDraw.line(ci, p + Vector2(-2.0 * d, -8.0), p + Vector2(4.0 * d, 3.0), Color(Palette.BONE, 0.35), 1.5)
	# Arrowhead.
	var tip := Vector2(end + head_len * d, y)
	var head := PackedVector2Array([Vector2(end - 6.0 * d, y - 30.0), tip, Vector2(end - 6.0 * d, y + 30.0), Vector2(end + 10.0 * d, y)])
	WoodcutDraw.fill(ci, _offset(head, Vector2(3, 6)), Color(Palette.INK, 0.7))
	WoodcutDraw.fill(ci, head, Palette.RED)
	_ring(ci, head, Palette.BONE, 3.0)
	# Frayed tail end of the rope.
	for k in 3:
		var a := start - d * 4.0
		WoodcutDraw.line(ci, Vector2(a, y - 6.0 + 6.0 * float(k)), Vector2(a - d * (10.0 + 4.0 * float(k)), y - 10.0 + 10.0 * float(k)), Palette.RED, 3.0)
	WoodcutDraw.end()


static func draw_rest(ci: CanvasItem, field: Rect2, y_top: float, y_bottom: float) -> void:
	WoodcutDraw.begin(ci)
	var top := minf(y_top, y_bottom)
	var bottom := maxf(y_top, y_bottom)
	bottom = maxf(bottom, top + 28.0)
	var r := Rect2(field.position.x + 4.0, top, field.size.x - 8.0, bottom - top)
	var pts := _rect_pts(r)
	WoodcutDraw.fill_fan(ci, pts, Color(Palette.ASH, 0.55))
	WoodcutDraw.fill_fan(ci, pts, Color(Palette.INK, 0.75), Palette.tex("hatch"), Transform2D(0.0, Vector2(1.0 / 110.0, 1.0 / 110.0), 0.0, Vector2.ZERO))
	for yy in [top, bottom]:
		WoodcutDraw.stroke(ci, PackedVector2Array([Vector2(r.position.x, yy), Vector2(r.get_center().x, yy + 1.0), Vector2(r.end.x, yy)]), Palette.BONE_DIM, 4.0, 4.0, 5.0)
		WoodcutDraw.line(ci, Vector2(r.position.x, yy + 4.0), Vector2(r.end.x, yy + 4.0), Palette.INK, 2.0)
	WoodcutDraw.end()


# ------------------------------------------------------------------ buttons

static func vec_button(ci: CanvasItem, rect: Rect2, lane: int, state: String) -> void:
	WoodcutDraw.begin(ci)
	var sink := 5.0 if state == "pressed" or state == "hit" else 0.0
	var r := Rect2(rect.position + Vector2(0, sink), rect.size - Vector2(0, sink)).grow(-4.0)
	var block := WoodcutDraw.rough_rect(r, 18.0, 1.8, 40 + lane, 4)
	if sink == 0.0:
		WoodcutDraw.fill_fan(ci, _offset(block, Vector2(0, 7)), Palette.INK)
	var fill := Palette.WOOD
	var line := Color(Palette.BONE, 0.85)
	var glyph := Color(Palette.BONE, 0.9)
	match state:
		"cued":
			fill = Palette.WOOD.lightened(0.06)
			line = Palette.EMBER
			glyph = Palette.EMBER
		"pressed":
			fill = Palette.RED
			line = Palette.BONE
			glyph = Palette.BONE
		"hit":
			fill = Palette.EMBER
			line = Palette.EMBER_HOT
			glyph = Palette.INK
		"miss":
			fill = Color("#2a2522")
			line = Palette.ASH
			glyph = Palette.ASH
	WoodcutDraw.fill_fan(ci, block, fill)
	var uv := Transform2D(0.0, Vector2(1.0 / 260.0, 1.0 / 260.0), 0.0, Vector2(float(lane) * 0.3, 0.0))
	WoodcutDraw.fill_fan(ci, block, Color(Palette.INK if state in ["pressed", "hit"] else Palette.BONE, 0.12), Palette.tex("grain"), uv)
	_ring(ci, block, Palette.INK, 3.0)
	var inner := WoodcutDraw.rough_rect(r.grow(-9.0), 12.0, 1.2, 50 + lane, 4)
	_ring(ci, inner, line, 3.0 if state != "cued" else 4.5)
	if state == "cued":
		var tex := Palette.tex("glow")
		if tex:
				WoodcutDraw.flush()
				ci.draw_texture_rect(tex, r.grow(18.0), false, Color(Palette.EMBER, 0.35))
	_foot_glyph(ci, r.get_center(), minf(r.size.x, r.size.y) * 0.34, lane, glyph)
	if state == "miss":
		var c := r.get_center()
		WoodcutDraw.line(ci, c + Vector2(-r.size.x * 0.3, -r.size.y * 0.2), c + Vector2(r.size.x * 0.1, r.size.y * 0.05), Palette.INK, 4.0)
		WoodcutDraw.line(ci, c + Vector2(r.size.x * 0.1, r.size.y * 0.05), c + Vector2(r.size.x * 0.28, -r.size.y * 0.1), Palette.INK, 3.0)
	WoodcutDraw.end()


# ------------------------------------------------------------------ bursts

static func draw_hit_burst(ci: CanvasItem, pos: Vector2, quality: String, age: float, size := 1.0) -> bool:
	if age < 0.0 or age > BURST_TIME:
		return false
	WoodcutDraw.begin(ci)
	var t := age / BURST_TIME
	var fade := pow(1.0 - t, 1.4)
	var grow := 1.0 - pow(1.0 - t, 3.0)
	var s := size
	match quality:
		"perfect":
			# An ember streak shoots up the lane from the hit, like a chisel run along the grain.
			var streak := lerpf(80.0, 300.0, grow) * s
			var sp := PackedVector2Array([pos + Vector2(0, -8.0 * s), pos + Vector2(0, -streak * 0.5), pos + Vector2(0, -streak)])
			WoodcutDraw.stroke(ci, sp, Color(Palette.INK, 0.5 * fade), 30.0 * s, 0.0, 26.0 * s)
			WoodcutDraw.stroke(ci, sp, Color(Palette.EMBER, 0.8 * fade), 22.0 * s, 0.0, 18.0 * s)
			WoodcutDraw.stroke(ci, sp, Color(Palette.EMBER_HOT, fade), 8.0 * s, 0.0, 6.0 * s)
			var r := lerpf(20.0, 96.0, grow) * s
			WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(pos, Vector2(34, 34) * s * (1.0 - t * 0.6), 18), Color(Palette.EMBER_HOT, 0.9 * fade))
			var ring := WoodcutDraw.ellipse(pos, Vector2(r, r * 0.8), 28)
			ring.append(ring[0])
			WoodcutDraw.stroke(ci, ring, Color(Palette.EMBER, fade), 6.0 * s, 6.0 * s)
			_splinters(ci, pos, r * 0.5, r * 1.15, 14, Color(Palette.BONE, fade), 6.0 * s, 1, 0.0, TAU)
			_splinters(ci, pos, r * 0.4, r * 0.9, 10, Color(Palette.EMBER_HOT, fade), 4.0 * s, 2, 0.2, TAU)
		"good":
			var r := lerpf(16.0, 70.0, grow) * s
			WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(pos, Vector2(24, 24) * s * (1.0 - t * 0.6), 16), Color(Palette.BONE, 0.7 * fade))
			_splinters(ci, pos, r * 0.5, r, 9, Color(Palette.BONE, fade), 5.0 * s, 3, 0.1, TAU)
		"early", "late":
			# Early sprays upward (you came before the line), late downward, each with its chevron.
			var up := quality == "early"
			var r := lerpf(14.0, 64.0, grow) * s
			var centre := -PI * 0.5 if up else PI * 0.5
			_splinters(ci, pos, r * 0.3, r, 8, Color(Palette.EMBER if up else Palette.RED, fade), 5.0 * s, 4, centre - 1.0, 2.0)
			var d := -1.0 if up else 1.0
			# Early is ember and points up, late is red and points down: they differ in shape, place and
			# colour. Both are cut out of a heavy ink outline so they read on any lane or backdrop.
			var cp := pos + Vector2(0, d * (34.0 + 34.0 * grow) * s)
			var chev := PackedVector2Array([cp + Vector2(-30, -d * 17) * s, cp, cp + Vector2(30, -d * 17) * s])
			var ca := minf(1.0, fade * 1.3)
			WoodcutDraw.stroke(ci, chev, Color(Palette.INK, ca), 19.0 * s, 19.0 * s, 20.0 * s)
			WoodcutDraw.stroke(ci, chev, Color(Palette.EMBER_HOT if up else Palette.RED, ca), 10.0 * s, 10.0 * s, 11.0 * s)
		"held":
			var tex := Palette.tex("glow")
			if tex:
				WoodcutDraw.flush()
				ci.draw_texture_rect(tex, Rect2(pos - Vector2(50, 90) * s, Vector2(100, 120) * s), false, Color(Palette.EMBER, fade))
			_splinters(ci, pos, 10.0 * s, lerpf(30.0, 90.0, grow) * s, 7, Color(Palette.EMBER_HOT, fade), 4.0 * s, 5, -PI * 0.85, PI * 0.7)
		_:
			# Miss or wrong: a dull grey crack, no spray.
			var c := Color(Palette.ASH, 0.9 * fade)
			var l := 26.0 * s
			WoodcutDraw.stroke(ci, PackedVector2Array([pos + Vector2(-l, -l * 0.6), pos + Vector2(-l * 0.2, 0), pos + Vector2(l * 0.1, -l * 0.3), pos + Vector2(l, l * 0.5)]), c, 3.0 * s, 1.0 * s, 6.0 * s)
			WoodcutDraw.stroke(ci, PackedVector2Array([pos + Vector2(-l * 0.1, -l * 0.8), pos + Vector2(0, l * 0.7)]), Color(Palette.INK, fade), 3.0 * s, 1.0 * s, 5.0 * s)
	WoodcutDraw.end()
	return true


# ------------------------------------------------------------------ helpers

## Tail cap of a hold: a small carved block.
static func _hold_cap(ci: CanvasItem, cx: float, bw: float, y: float) -> void:
	var cap := Rect2(cx - bw * 0.85, y - 8.0, bw * 1.7, 16.0)
	var cap_pts := WoodcutDraw.rough_rect(cap, 6.0, 1.0, 7)
	WoodcutDraw.fill_fan(ci, cap_pts, Palette.BONE)
	_ring(ci, cap_pts, Palette.INK, 2.0)


static func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, d) * pts


static func _ring(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	WoodcutDraw.ring(ci, pts, color, width)


static func _hex(r: Rect2) -> PackedVector2Array:
	var y := r.get_center().y
	var p := r.size.y * 0.55
	return PackedVector2Array([Vector2(r.position.x, y), Vector2(r.position.x + p, r.position.y), Vector2(r.end.x - p, r.position.y),
		Vector2(r.end.x, y), Vector2(r.end.x - p, r.end.y), Vector2(r.position.x + p, r.end.y)])


static func _splinters(ci: CanvasItem, c: Vector2, r0: float, r1: float, count: int, color: Color, width: float, salt: int, a0: float, arc: float) -> void:
	for i in count:
		var a := a0 + arc * (float(i) + 0.3 + 0.4 * WoodcutDraw.hash01(i, salt)) / float(count)
		var dir := Vector2.from_angle(a)
		var l := lerpf(r0, r1, 0.6 + 0.4 * WoodcutDraw.hash01(i, salt + 1))
		WoodcutDraw.stroke(ci, PackedVector2Array([c + dir * r0, c + dir * l]), color, width, 0.0, width)


## A cowbell seen from the side, mouth down; with a small arrow for the swing direction.
static func _bell_glyph(ci: CanvasItem, c: Vector2, s: float, color: Color, up: bool) -> void:
	var body := PackedVector2Array([Vector2(-0.22, -0.34), Vector2(0.22, -0.34), Vector2(0.32, 0.1), Vector2(0.4, 0.3), Vector2(-0.4, 0.3), Vector2(-0.32, 0.1)])
	var xf := Transform2D(0.0, Vector2(s, s), 0.0, c)
	WoodcutDraw.fill_fan(ci, xf * body, color)
	WoodcutDraw.fill_fan(ci, xf * WoodcutDraw.ellipse(Vector2(0, 0.3), Vector2(0.4, 0.08), 10), Palette.INK)
	WoodcutDraw.fill_fan(ci, xf * WoodcutDraw.ellipse(Vector2(0, -0.42), Vector2(0.1, 0.08), 8), color)
	var d := -1.0 if up else 1.0
	var a := c + Vector2(0, d * s * 0.02)
	WoodcutDraw.line(ci, a + Vector2(-s * 0.1, -d * s * 0.04), a + Vector2(0, d * s * 0.08), Palette.INK, maxf(2.0, s * 0.06))
	WoodcutDraw.line(ci, a + Vector2(s * 0.1, -d * s * 0.04), a + Vector2(0, d * s * 0.08), Palette.INK, maxf(2.0, s * 0.06))


## A carved footprint: left foot for the left button, right for the right, both for the middle.
static func _foot_glyph(ci: CanvasItem, c: Vector2, s: float, lane: int, color: Color) -> void:
	var feet: Array = []
	if lane == 0:
		feet = [[-1.0, Vector2(0, 0)]]
	elif lane == 2:
		feet = [[1.0, Vector2(0, 0)]]
	else:
		feet = [[-1.0, Vector2(-s * 0.36, 0)], [1.0, Vector2(s * 0.36, 0)]]
	var k := 0.8 if lane == 1 else 1.0
	for f in feet:
		var side: float = f[0]
		var o: Vector2 = c + f[1]
		var sole := WoodcutDraw.ellipse(o + Vector2(side * s * 0.05, -s * 0.2) * k, Vector2(s * 0.26, s * 0.42) * k, 14, side * 0.15)
		WoodcutDraw.fill_fan(ci, sole, color)
		WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(o + Vector2(-side * s * 0.02, s * 0.38) * k, Vector2(s * 0.2, s * 0.22) * k, 12), color)
		for toe in 3:
			var tp := o + Vector2(side * s * (0.02 + 0.12 * float(toe)) - side * s * 0.1, -s * (0.72 - 0.05 * float(toe))) * k
			WoodcutDraw.fill_fan(ci, WoodcutDraw.ellipse(tp, Vector2(s * 0.07, s * 0.08) * k, 8), color)
