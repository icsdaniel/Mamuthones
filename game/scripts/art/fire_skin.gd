class_name FireSkin
extends RefCounted
## The "Fire Night" look of the play field: a dark road running into a bonfire, ember rails, gold and
## crimson gems for notes. The sprites in res://art/fire/ are cut from the approved mockup's own
## drawing code by tools/art/fire_night/render.js; the moving parts (glows, beads, bursts, sparks) are
## drawn here. Call these from a Control's _draw(), passing it as `ci`.
##
## Two kinds of drawing:
##   flat    things lying on the road (sash, bell bar, stand-still band) are drawn in the flat field
##           that LaneView lays back in perspective, so they foreshorten with the road;
##   upright things standing on it (gems, rings, badges, the rope, the hit line, bursts) are drawn in
##           screen space at the projected point, scaled by `sc` = the lane's width on screen / 240.
## Sizes below are in the mockup's reference pixels (a 240 px lane, a 720 px road at the hit line).

const DIR := "res://art/fire/"
const REF_LANE := 240.0

## Sprite cells (size, anchor, drawn bounds) come from FireCells, generated with the sprites.
const SASH := Vector2(82, 64)
const BUTTON_STATES := ["idle", "cued", "pressed", "hit", "miss"]

const GOLD := Color("#ffc84a")
const GOLD_HOT := Color("#fff3cf")
const EMBER := Color("#ff7a1f")
const CRIMSON := Color("#c8181e")
const NIGHT := Color("#07060c")
const STILL_BLUE := Color("#dfe6ff")

static var _tex := {}
static var _glow: Texture2D
static var _soft: GradientTexture2D
static var _soft_v: GradientTexture2D


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null:
			t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


## A soft round glow, white in the middle and gone at the edge (tint it with the draw colour).
static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


## A soft band across its width (bright in the middle), for rails and the hit line's glow.
static func soft(vertical := false) -> Texture2D:
	if vertical:
		if _soft_v == null:
			_soft_v = soft().duplicate()
			_soft_v.fill_to = Vector2(0.0, 1.0)
			_soft_v.width = 4
			_soft_v.height = 64
		return _soft_v
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 4
		_soft = t
	return _soft


static func _mip(ci: CanvasItem) -> void:
	RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)


## Draws sprite `name` with its anchor at `at`, scaled by sc (reference pixels to screen); flip mirrors it.
static func blit(ci: CanvasItem, name: String, at: Vector2, sc: float, modulate := Color.WHITE, flip := false) -> void:
	var t := tex(name)
	if t == null or not FireCells.CELLS.has(name):
		return
	var cell: Array = FireCells.CELLS[name]
	var sz: Vector2 = cell[0]
	var a: Vector2 = cell[1]
	if flip:
		a.x = sz.x - a.x
	var r := Rect2(at - a * sc, sz * sc)
	if flip:
		ci.draw_texture_rect_region(t, r, Rect2(Vector2(t.get_width(), 0), Vector2(-t.get_width(), t.get_height())), modulate)
	else:
		ci.draw_texture_rect(t, r, false, modulate)


## Where sprite `name` actually draws, relative to its anchor, at scale sc (flip mirrors it).
static func bounds(name: String, sc: float, flip := false) -> Rect2:
	if not FireCells.CELLS.has(name):
		return Rect2()
	var b: Rect2 = FireCells.CELLS[name][2]
	b = Rect2(b.position * sc, b.size * sc)
	if flip:
		b.position.x = -b.end.x
	return b


# ------------------------------------------------------------------ upright (screen space)

## A step: a bevelled gem, gold face in a crimson rim, with its halo and its shadow on the road.
## An off-beat step (off) is smaller, inside a dashed bone ring.
static func draw_gem(ci: CanvasItem, at: Vector2, sc: float, call := false, alpha := 1.0, off := false) -> void:
	_mip(ci)
	if off:
		var rx := 0.3 * REF_LANE * sc * 0.78
		var c := at + Vector2(0.0, rx * 0.09)
		var erx := rx * 1.3
		var ery := rx * 0.38 * 1.35 + rx * 0.09
		var n := 28
		for i in n:
			if i % 2 == 1:
				continue
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			var pts := PackedVector2Array()
			for j in 4:
				var a := lerpf(a0, a1, float(j) / 3.0)
				pts.append(c + Vector2(cos(a) * erx, sin(a) * ery))
			ci.draw_polyline(pts, Color(0.94, 0.886, 0.776, 0.85 * alpha), maxf(1.5, 2.0 * sc), true)
	blit(ci, "gem_call" if call else "gem", at, sc * (0.78 if off else 1.0), Color(1, 1, 1, alpha))


## A healing step: the bone-and-gold gem with its ember flame, breathing with a soft glow (clock in
## seconds drives the pulse).
static func draw_heal_gem(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0, clock := 0.0) -> void:
	_mip(ci)
	var p := 0.5 + 0.5 * sin(clock * TAU * 1.5)
	var r := 0.33 * REF_LANE * sc * (1.5 + 0.25 * p)
	ci.draw_texture_rect(glow(), Rect2(at - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.2)), false, Color(1.0, 0.8, 0.4, (0.25 + 0.2 * p) * alpha))
	blit(ci, "gem_heal", at, sc * (1.0 + 0.04 * p), Color(1, 1, 1, alpha))


## The end of a hold: a hollow gold ring.
static func draw_hold_ring(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0) -> void:
	_mip(ci)
	blit(ci, "hold_ring", at, sc, Color(1, 1, 1, alpha))


## The bell bar's red badge, upright at the bar's middle.
static func draw_badge(ci: CanvasItem, at: Vector2, sc: float, alpha := 1.0) -> void:
	_mip(ci)
	blit(ci, "badge", at, sc, Color(1, 1, 1, alpha))


## The rope across the road: `road_w` is the road's width on screen at its depth, dir 1 right.
static func draw_rope(ci: CanvasItem, at: Vector2, road_w: float, dir: int, alpha := 1.0) -> void:
	_mip(ci)
	blit(ci, "rope_r" if dir >= 0 else "rope_l", at, road_w / 720.0, Color(1, 1, 1, alpha))


## The hit line: a heavy glowing bar across the whole width at y, with a bronze receptor ring at each
## lane (centres xs, ring half-width rx). lit[i] 0..1 fills a receptor with light (pressed, holding).
static func draw_hit_line(ci: CanvasItem, x0: float, x1: float, y: float, xs: Array, rx: float, lit: Array, pulse := 0.0) -> void:
	var t := 1.0
	ci.draw_rect(Rect2(x0, y - 9.0 * t, x1 - x0, 18.0 * t), Color("#2a0b06"))
	var top := Color("#ffcf6a").lerp(Color.WHITE, pulse * 0.3)
	var mid := Color("#fff8e0")
	var bot := Color("#e8781f")
	_vgrad(ci, x0, x1, y - 7.0, y, top, mid)
	_vgrad(ci, x0, x1, y, y + 7.0, mid, bot)
	ci.draw_rect(Rect2(x0, y + 7.0, x1 - x0, 2.0), Color(0.47, 0.12, 0.04, 0.9))
	var ry := rx * 0.38
	for i in xs.size():
		var x: float = xs[i]
		var l: float = lit[i] if i < lit.size() else 0.0
		if l > 0.0:
			ci.draw_texture_rect(glow(), Rect2(x - rx * 1.5, y - ry * 2.2, rx * 3.0, ry * 4.4), false, Color(1.0, 0.6, 0.25, 0.8 * l))
		_ellipse(ci, Vector2(x, y), rx + 2.0, ry + 2.0, Color("#2a0b06"), 8.0)
		_ellipse_grad(ci, Vector2(x, y), rx, ry, Color("#ffe6a0").lerp(Color.WHITE, l * 0.5), Color("#7a3e10").lerp(Color("#ff9a3a"), l), 5.0)


## Additive glow under the hit line (draw on an additive canvas item).
static func draw_hit_glow(ci: CanvasItem, x0: float, x1: float, y: float, pulse := 0.0) -> void:
	var h := 60.0 + 16.0 * pulse
	ci.draw_texture_rect(soft(true), Rect2(x0, y - h, x1 - x0, h * 2.0), false, Color(1.0, 0.5, 0.15, 0.4 + 0.2 * pulse))


# ------------------------------------------------------------------ flat (on the road)

## A hold's woven sash from flat y_head down... up to y_tail, in `lane` (flat), scrolling with the head.
static func draw_sash(ci: CanvasItem, lane: Rect2, y_head: float, y_tail: float, lit := false, clip := Rect2()) -> void:
	var t := tex("sash")
	var cx := lane.get_center().x
	var k := lane.size.x / REF_LANE
	var bw := SASH.x * k
	var top := minf(y_head, y_tail)
	var bottom := maxf(y_head, y_tail)
	if clip.has_area():
		top = maxf(top, clip.position.y)
		bottom = minf(bottom, clip.end.y)
	if bottom - top < 1.0:
		return
	var r := Rect2(cx - bw * 0.5, top, bw, bottom - top)
	var glow_c := Color(1.0, 0.25, 0.1, 0.35 if lit else 0.2)
	ci.draw_rect(r.grow_individual(6.0 * k, 0, 6.0 * k, 0), glow_c)
	if t != null:
		_mip(ci)
		RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		var tile_h := SASH.y * k
		# The weave moves with the head: the source window starts where the head's tile phase is.
		var off := fposmod(y_head - bottom, tile_h) / tile_h * float(t.get_height())
		var src := Rect2(0.0, off, float(t.get_width()), (bottom - top) / tile_h * float(t.get_height()))
		ci.draw_texture_rect_region(t, r, src, Color(1.3, 1.15, 1.0) if lit else Color.WHITE)
	else:
		ci.draw_rect(r, CRIMSON)
	var edge := Color("#ffe9a8") if lit else Color("#ffd27a")
	ci.draw_rect(Rect2(r.position.x - 1.5, top, 3.0, r.size.y), edge)
	ci.draw_rect(Rect2(r.end.x - 1.5, top, 3.0, r.size.y), edge)


## The bell bar across the flat field at y (BAR_H tall), chevrons up or down; the badge is upright.
static func draw_bar(ci: CanvasItem, field: Rect2, y: float, up: bool) -> void:
	var t := tex("bar_up" if up else "bar_down")
	if t == null:
		ci.draw_rect(Rect2(field.position.x, y - 23.0, field.size.x, 46.0), GOLD)
		return
	_mip(ci)
	var cell: Array = FireCells.CELLS["bar_up"]
	var sz: Vector2 = cell[0]
	var a: Vector2 = cell[1]
	# Drawn a little slimmer than its judged height, so it stays a bar and not a slab near the line.
	var k := 0.72
	ci.draw_texture_rect(t, Rect2(field.position.x, y - a.y * k, field.size.x, sz.y * k), false)


## The stand-still band: a navy band hatched in pale blue, closed by two rules (flat).
static func draw_band(ci: CanvasItem, field: Rect2, y_top: float, y_bottom: float) -> void:
	var top := minf(y_top, y_bottom)
	var bottom := maxf(maxf(y_top, y_bottom), top + 28.0)
	var r := Rect2(field.position.x, top, field.size.x, bottom - top)
	ci.draw_rect(r, Color(0.07, 0.08, 0.19, 0.85))
	var t := tex("hatch")
	if t != null:
		RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
		ci.draw_texture_rect_region(t, r, Rect2(Vector2.ZERO, r.size * 64.0 / 56.0), Color(1, 1, 1, 0.42))
	for yy in [top, bottom]:
		ci.draw_rect(Rect2(r.position.x, yy - 2.0, r.size.x, 4.0), STILL_BLUE)


# ------------------------------------------------------------------ buttons

## A step button: a lacquered plate in a bronze frame with the sash's lozenge band, and toeless soles
## engraved in bone; hot red when pressed or hit.
static func draw_button(ci: CanvasItem, rect: Rect2, lane: int, state: String) -> void:
	if not (state in BUTTON_STATES):
		state = "idle"
	_mip(ci)
	var name := "button_" + state
	var t := tex(name)
	var k := minf(rect.size.x / 220.0, rect.size.y / 176.0)
	if t != null and FireCells.CELLS.has(name):
		var cell: Array = FireCells.CELLS[name]
		var kk := rect.size / Vector2(220.0, 176.0)
		var a: Vector2 = cell[1]
		ci.draw_texture_rect(t, Rect2(rect.position - a * kk, (cell[0] as Vector2) * kk), false)
	else:
		ci.draw_rect(rect, Color("#241a30"))
	var tint := Color.WHITE
	match state:
		"cued":
			tint = Color(1.08, 0.95, 0.75)
		"pressed", "hit":
			tint = Color(1.12, 1.1, 1.06)
		"miss":
			tint = Color(0.5, 0.47, 0.52)
	var c := rect.get_center() + Vector2(0, 14) * k
	if state in ["pressed", "hit"]:
		ci.draw_texture_rect(glow(), Rect2(c - Vector2(90, 70) * k, Vector2(180, 140) * k), false, Color(1.0, 0.88, 0.6, 0.5))
	for pass_ in 2:
		var shadow := pass_ == 0
		var off := Vector2(0, 3) * k if shadow else Vector2.ZERO
		var col := Color(0, 0, 0, 0.55) if shadow else tint
		if lane == 1:
			blit(ci, "foot_l", c + off + Vector2(-22, 0) * k, 1.25 * k, col)
			blit(ci, "foot_r", c + off + Vector2(22, 6) * k, 1.25 * k, col)
		else:
			blit(ci, "foot_l" if lane == 0 else "foot_r", c + off, 1.4 * k, col)


# ------------------------------------------------------------------ bursts (additive)

## A hit burst at `at` (screen), sc = lane scale, rx = the receptor ring's half width there; returns
## false once it is over (LaneSkin.BURST_TIME). Draw on an additive canvas item. A soft glow, rings of
## light pulsing outward from the receptor (never over it, so the ring stays readable) and embers
## rising: perfect the most, good fewer, early / late in their cool and warm colours; held a warm column;
## miss / wrong a dull ash puff.
static func draw_burst(ci: CanvasItem, at: Vector2, quality: String, age: float, sc := 1.0) -> bool:
	var life := LaneSkin.BURST_TIME
	if age < 0.0 or age > life:
		return false
	var t := age / life
	var fade := pow(1.0 - t, 1.3)
	var grow := 1.0 - pow(1.0 - t, 2.5)
	var g := glow()
	var rx := 0.33 * REF_LANE * sc
	var ry := rx * 0.38
	match quality:
		"perfect", "good", "early", "late":
			var big := 1.0 if quality == "perfect" else 0.7
			var warm := Color(1.0, 0.59, 0.24)
			var hot := Color(1.0, 0.87, 0.59)
			if quality == "early":
				warm = Palette.EARLY
				hot = Palette.EARLY.lightened(0.3)
			elif quality == "late":
				warm = Palette.LATE
				hot = Palette.LATE.lightened(0.3)
			var r := 170.0 * sc * big
			ci.draw_texture_rect(g, Rect2(at - Vector2(r, r * 0.55), Vector2(r * 2.0, r * 1.1)), false, Color(warm, 0.7 * fade))
			var rings := [[1.32, 0.95, 5.0], [1.7, 0.5, 3.0], [2.15, 0.22, 2.0]]
			var n := 3 if quality == "perfect" else 2
			for i in n:
				var ring: Array = rings[i]
				var k := lerpf(1.08, float(ring[0]) * (1.0 if quality == "perfect" else 0.9), grow)
				_ellipse(ci, at, rx * k, ry * k, Color(hot, float(ring[1]) * fade), float(ring[2]) * maxf(sc, 0.7))
			_embers(ci, at, rx, sc, t, fade, 13 if quality == "perfect" else 7, warm)
		"heal":
			# A healing step taken: a tall golden flare, a bone ring opening wide and a spray of embers.
			ci.draw_texture_rect(g, Rect2(at - Vector2(110, 230) * sc * (0.8 + 0.4 * grow), Vector2(220, 280) * sc * (0.8 + 0.4 * grow)), false, Color(1.0, 0.78, 0.35, 0.9 * fade))
			for i in 2:
				var k := lerpf(1.05, 2.4 - 0.6 * i, grow)
				_ellipse(ci, at, rx * k, ry * k, Color(1.0, 0.95, 0.78, (0.9 - 0.4 * i) * fade), (5.0 - 2.0 * i) * maxf(sc, 0.7))
			_embers(ci, at, rx, sc, t, fade, 18, Color(1.0, 0.8, 0.4))
		"held":
			ci.draw_texture_rect(g, Rect2(at - Vector2(70, 150) * sc, Vector2(140, 190) * sc), false, Color(1.0, 0.55, 0.15, 0.8 * fade))
			_ellipse(ci, at, rx * lerpf(1.05, 1.4, grow), ry * lerpf(1.05, 1.4, grow), Color(1.0, 0.85, 0.55, 0.7 * fade), 3.0)
			_embers(ci, at, rx, sc, t, fade, 9, EMBER)
		_:
			var r := lerpf(30.0, 80.0, grow) * sc
			ci.draw_texture_rect(g, Rect2(at - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2)), false, Color(0.45, 0.42, 0.5, 0.5 * fade))
	return true


## Embers rising from around a receptor: tall specks drifting up and out as they fade.
static func _embers(ci: CanvasItem, at: Vector2, rx: float, sc: float, t: float, fade: float, n: int, warm: Color) -> void:
	for i in n:
		var a := -PI * (0.1 + 0.8 * WoodcutDraw.hash01(i, 3))
		var d := rx * (1.1 + 0.9 * WoodcutDraw.hash01(i, 5)) * (0.6 + 0.4 * t)
		var p := at + Vector2(cos(a) * d, sin(a) * d * 0.8 - (30.0 * WoodcutDraw.hash01(i, 7) + 60.0 * t) * sc)
		var s := (2.0 + 3.0 * WoodcutDraw.hash01(i, 9)) * maxf(sc, 0.7)
		var c := Color(1.0, 0.93, 0.67) if i % 2 == 0 else warm
		ci.draw_rect(Rect2(p, Vector2(s, s * 1.6)), Color(c, 0.95 * fade))


# ------------------------------------------------------------------ helpers

static func _vgrad(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), PackedColorArray([c0, c0, c1, c1]))


static func ellipse_pts(c: Vector2, rx: float, ry: float, n := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := float(i) / float(n) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	ci.draw_polyline(ellipse_pts(c, rx, ry), col, w, true)


## An ellipse outline lit from above: `top` colour at its top, `bottom` at its bottom.
static func _ellipse_grad(ci: CanvasItem, c: Vector2, rx: float, ry: float, top: Color, bottom: Color, w: float) -> void:
	var pts := ellipse_pts(c, rx, ry)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - c.y) / (2.0 * ry) + 0.5, 0.0, 1.0)))
	ci.draw_polyline_colors(pts, cols, w, true)


# ------------------------------------------------------------------ type (HUD and judgement words)

const TEXT_GRADIENT_SHADER := """
shader_type canvas_item;
// Fills a label's text (drawn in white) with a vertical gradient over the label's height; the outline
// and shadow (dark) are left as they are.
uniform vec4 top_col : source_color = vec4(1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.9, 0.65, 1.0);
uniform vec4 bottom_col : source_color = vec4(1.0, 0.7, 0.23, 1.0);
uniform float height = 60.0;
uniform float y0 = 0.2;
uniform float y1 = 0.8;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	vec4 c = COLOR;
	if (c.r > 0.85 && c.g > 0.85 && c.b > 0.85) {
		float t = clamp((ly / height - y0) / (y1 - y0), 0.0, 1.0);
		vec3 g = t < 0.5 ? mix(top_col.rgb, mid_col.rgb, t * 2.0) : mix(mid_col.rgb, bottom_col.rgb, t * 2.0 - 1.0);
		c.rgb = g * c.rgb;
	}
	COLOR = c;
}
"""

static var _italic := {}
static var _grad_shader: Shader


## Alegreya Sans in a slanted, heavy cut for the HUD and the judgement words.
static func italic_font(weight := "ExtraBold") -> Font:
	if _italic.has(weight):
		return _italic[weight]
	var f := FontVariation.new()
	f.base_font = Palette.text_font(weight)
	f.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
	_italic[weight] = f
	return f


## A material that fills white text with a top-to-bottom gradient (gold by default).
static func text_gradient(top := Color.WHITE, mid := Color("#ffe7a8"), bottom := Color("#ffb13a")) -> ShaderMaterial:
	if _grad_shader == null:
		_grad_shader = Shader.new()
		_grad_shader.code = TEXT_GRADIENT_SHADER
	var m := ShaderMaterial.new()
	m.shader = _grad_shader
	m.set_shader_parameter("top_col", top)
	m.set_shader_parameter("mid_col", mid)
	m.set_shader_parameter("bottom_col", bottom)
	return m


## Styles a label in the Fire Night HUD type: slanted heavy face, white fill (for a gradient material)
## or `color`, a dark outline and a soft dark shadow.
static func style_label(l: Label, size: int, color := Color.WHITE, outline := 8) -> void:
	l.add_theme_font_override("font", italic_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#12060a"))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", outline + 4)


## Styles a label in the carved serif (IM Fell English SC: small caps): `color` fill (white for a
## gradient material), an optional gold hairline, and a dark cut shadow just below with a soft halo.
static var _carved: Dictionary = {}


## The carved serif (IM Fell English SC), optionally emboldened for the big numbers so it holds up
## over the fire like the mockup's bold serif.
static func carved_font(embolden := 0.0) -> Font:
	if _carved.has(embolden):
		return _carved[embolden]
	var f := FontVariation.new()
	f.base_font = Palette.display_font()
	f.variation_embolden = embolden
	f.fallbacks = [Palette.text_font("Bold")]   # the few signs the serif lacks (−)
	_carved[embolden] = f
	return f


## A label in the carved serif small caps: colour (white under a gradient), a thin hairline outline,
## and a cut shadow under it with a dark halo so it reads over the fire.
static func carve_label(l: Label, size: int, color := Color.WHITE, hair := Color(0, 0, 0, 0), halo := 6, embolden := 0.0) -> void:
	l.add_theme_font_override("font", carved_font(embolden))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", hair)
	l.add_theme_constant_override("outline_size", 2 if hair.a > 0.0 else 0)
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.01, 0.02, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, int(round(size * 0.06))))
	l.add_theme_constant_override("shadow_outline_size", halo)


## The road's basalt setts, flat in the field (the road's perspective lays them back): a tile of 12
## blocks across, repeated down the field.
static func draw_setts(ci: CanvasItem, field: Rect2) -> void:
	var t := tex("setts")
	if t == null:
		return
	RenderingServer.canvas_item_set_default_texture_repeat(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)
	var cell: Vector2 = FireCells.CELLS["setts"][0]
	var k := field.size.x / cell.x
	var th := cell.y * k
	ci.draw_texture_rect_region(t, field, Rect2(0.0, 0.0, float(t.get_width()), field.size.y / th * float(t.get_height())))
