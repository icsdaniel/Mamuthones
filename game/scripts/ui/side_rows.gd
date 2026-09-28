class_name SideRows
extends Control
## The two files of Mamuthones either side of the lanes on the play screen, jumping on the beat the
## way the real rows do: airborne through the second half of each beat and landing on it, the bells
## swinging to the other side each landing. The files join the player as the unison grows (one
## Mamuthone per side at level 0, the whole file at the top), stumble on a miss, and stand stock
## still through a stand-still.
##
## It answers the same calls as ProcessionScene (set_unison, jolt, set_still, settle, set_look ...),
## so the play screen talks to either. The play screen sets `beat` every frame and `lanes` once, and
## the figures fill the space left and right of the lanes. They are the Fire Night sprites (FireSkin):
## black fleece, bronze bells, a carved mask, lit warm from the fire's side and cool from the night's,
## each file led by a red Issohadore. The player's fleece colour is kept; the mask is the carved one.

const MAX_PER_SIDE := 5
const ACTIVE := [1, 2, 3, 4, 5]     ## Mamuthones jumping per side at unison 0..4
const JUMP := 0.16                  ## jump height, in figure heights
const AIR := 0.55                   ## share of the beat spent in the air (ends on the beat)
const WAVE := 0.035                 ## beats of delay from one Mamuthone to the next down the file

var lanes: Control
var beat := 0.0                     ## the song's beat now (fractional); negative before the music
var mask: Dictionary = MaskSpec.default()
var fleece := "black"
var straps := "natural"
var bell_set := "village"
var unison := 0
var still := false
var reduced_motion := false

var _clock := 0.0
var _jolt_kind := ""
var _jolt_at := -9.0
var _throw_at := -9.0
var _joined_at: Array[float] = []   ## when each slot last joined, for a quick fade-in


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_PER_SIDE:
		_joined_at.append(-9.0)


# ------------------------------------------------------------------ the ProcessionScene calls

func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural") -> void:
	mask = p_mask
	fleece = p_fleece
	straps = p_straps
	_rebake()


func set_bell_set(id: String) -> void:
	bell_set = id
	_rebake()


func set_stop(_n: int) -> void:
	pass


func set_unison(level: int) -> void:
	var before := active_count()
	unison = clampi(level, 0, ACTIVE.size() - 1)
	for i in range(before, active_count()):
		_joined_at[i] = _clock


func set_still(on: bool) -> void:
	still = on


func settle() -> void:
	still = false


func jolt(kind := "step") -> void:
	_jolt_kind = kind
	_jolt_at = _clock


func throw_rope() -> void:
	_throw_at = _clock


func set_ghost_delta(_seconds: float) -> void:
	pass


func hide_ghost() -> void:
	pass


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on


## Mamuthones jumping on each side right now.
func active_count() -> int:
	return int(ACTIVE[clampi(unison, 0, ACTIVE.size() - 1)])


# ------------------------------------------------------------------ drawing

func _rebake() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## The two gutters beside the lanes, in this control's coordinates.
func gutters() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var left := 0.0
	var right := size.x
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var lr := lanes.get_global_rect()
		var inv := get_global_transform().affine_inverse()
		left = (inv * lr.position).x
		right = (inv * lr.end).x
	out.append(Rect2(0.0, 0.0, maxf(left, 0.0), size.y))
	out.append(Rect2(right, 0.0, maxf(size.x - right, 0.0), size.y))
	return out


## Height of one figure for a gutter this wide (the bell load makes a Mamuthone ~0.8 as wide as tall).
func figure_h(gutter_w: float) -> float:
	return clampf(gutter_w * 1.35, 60.0, 280.0)


## Where slot i of a file stands (feet), from the bottom (i = 0, nearest) up.
func slot_feet(g: Rect2, i: int) -> Vector2:
	var h := figure_h(g.size.x)
	var bottom := g.end.y - 8.0
	var step := (g.size.y - h * 1.1) / float(MAX_PER_SIDE - 1)
	return Vector2(g.get_center().x, bottom - step * i)


## Where slot i of side s stands: [feet, figure height], in this control's coordinates. Beside the
## perspective road the files stand on the ground outside its edges, receding toward the far end: each
## file is led by its Issohadore, nearest (file place 0), and slot 0 is the nearest Mamuthone behind
## him, each next one further up the road and smaller.
func slot(s: int, i: int) -> Array:
	return _place(s, i + 1)


## Where the Issohadore leading side s stands: [feet, figure height].
func leader(s: int) -> Array:
	return _place(s, 0)


## Place k of side s's file (0 the Issohadore, 1.. the Mamuthones): [feet, figure height].
func _place(s: int, k: int) -> Array:
	if lanes != null and lanes.has_method("road_edges") and lanes.is_inside_tree() and is_inside_tree() and lanes.call("_road_on"):
		var f: Rect2 = lanes.call("field_rect")
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var near_frac := 0.47
		var ly := f.position.y + f.size.y * (near_frac - 0.083 * k)
		var edges: Vector2 = lanes.call("road_edges", ly)
		var w: float = (edges.y - edges.x) / maxf(f.size.x, 1.0)
		# The nearest figure just fits its gap; the others shrink with the road.
		var near_edges: Vector2 = lanes.call("road_edges", f.position.y + f.size.y * near_frac)
		var near_w: float = (near_edges.y - near_edges.x) / maxf(f.size.x, 1.0)
		var near_gap := near_edges.x - f.position.x
		var base := near_gap / 0.9 / maxf(near_w, 0.1)
		var h := clampf(base * w * 0.9, 40.0, 280.0)
		var gap := edges.x - f.position.x
		var x := f.position.x + gap * 0.5 if s == 0 else f.end.x - gap * 0.5
		return [to_me * Vector2(x, ly), h]
	var g: Rect2 = gutters()[s]
	var i := maxi(k - 1, 0)
	var h0 := figure_h(g.size.x) * (1.0 - 0.05 * i)
	return [slot_feet(g, i), h0 if k > 0 else h0 * 1.05]


func _draw() -> void:
	var sides := gutters()
	var glow := FireSkin.glow()
	var road: bool = lanes != null and lanes.has_method("_road_on") and bool(lanes.call("_road_on"))
	for s in 2:
		var g: Rect2 = sides[s]
		if not road and g.size.x < 24.0:
			continue
		# Firelight on the ground under the file, so the dark fleece reads against the night.
		var near: Array = _place(s, 0)
		var far: Array = _place(s, MAX_PER_SIDE)
		var top: float = (far[0] as Vector2).y - float(far[1])
		var bottom: float = (near[0] as Vector2).y
		var cx: float = ((near[0] as Vector2).x + (far[0] as Vector2).x) * 0.5
		var wd: float = float(near[1]) * 1.2
		draw_texture_rect(glow, Rect2(cx - wd, top - 20.0, wd * 2.0, bottom - top + 60.0), false, Color(1.0, 0.45, 0.15, 0.16))
		for i in range(MAX_PER_SIDE - 1, -1, -1):
			var sl: Array = slot(s, i)
			_draw_one(sl[0], float(sl[1]), i, s)
		_draw_leader(s)


## The Issohadore at the head of the file: red jacket, rope raised; he bobs on the beat and hops when
## he throws the rope.
func _draw_leader(side: int) -> void:
	var pl := leader(side)
	var feet: Vector2 = pl[0]
	var h: float = pl[1]
	var amp := 0.35 if reduced_motion else 1.0
	var y := 0.0
	if not still and beat > -8.0:
		var f := fposmod(beat, 1.0)
		y = -sin(clampf(f / 0.5, 0.0, 1.0) * PI) * 0.03 * h * amp
	var age := _clock - _throw_at
	if age < 0.4:
		y -= sin(age / 0.4 * PI) * 0.1 * h * amp
	_shadow(feet, h, clampf(-y / (0.1 * h), 0.0, 1.0))
	_blit("issohadore", feet + Vector2(0.0, y), h, 0.0, 1.0, Color.WHITE, side == 1)


func _shadow(feet: Vector2, h: float, lift: float) -> void:
	draw_set_transform(feet + Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, h * 0.28 * (1.0 - 0.3 * lift), Color(0, 0, 0, 0.6))
	draw_set_transform(Vector2.ZERO)


## A Fire Night figure sprite with its feet at `feet`, h tall; flip faces it left (the right file).
func _blit(name: String, feet: Vector2, h: float, rot: float, sq: float, tint: Color, flip: bool) -> void:
	var t := FireSkin.tex(name)
	if t == null:
		return
	RenderingServer.canvas_item_set_default_texture_filter(get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var cell: Vector2 = FireSkin.FIG[0]
	var a: Vector2 = FireSkin.FIG[1]
	var k := h / float(FireSkin.FIG[2])
	draw_set_transform(feet, rot, Vector2(-k if flip else k, k * sq))
	draw_texture_rect(t, Rect2(-a, cell), false, tint)
	draw_set_transform(Vector2.ZERO)


func _draw_one(feet: Vector2, h: float, i: int, side: int) -> void:
	var active := i < active_count()
	var y := 0.0
	var rot := 0.0
	var sq := 1.0
	var amp := 0.35 if reduced_motion else 1.0
	var airborne := false
	if active and not still and beat > -8.0:
		var b := beat - WAVE * i
		var f := fposmod(b, 1.0)
		var air := clampf((f - (1.0 - AIR)) / AIR, 0.0, 1.0)
		y = -sin(air * PI) * JUMP * h * amp
		airborne = air > 0.0 and air < 1.0
		# Landing squash for a moment after the beat, and the bells swung to the other side.
		sq = 1.0 - 0.07 * amp * clampf(1.0 - f / 0.12, 0.0, 1.0)
		var dir := 1.0 if posmod(floori(b), 2) == 0 else -1.0
		rot = dir * 0.05 * amp * (1.0 - f)
	var age := _clock - _jolt_at
	var x := 0.0
	var tint := Color.WHITE
	if active and age < 0.35:
		var k := 1.0 - age / 0.35
		match _jolt_kind:
			"miss":
				x = sin(age * 60.0) * h * 0.04 * k * amp
				tint = Color(1.0, 0.55 + 0.45 * (1.0 - k), 0.5 + 0.5 * (1.0 - k))
			"bell", "ring":
				rot += (0.1 if side == 0 else -0.1) * k * amp
			_:
				y -= h * 0.02 * k * amp
	var dim := Color(0.5, 0.45, 0.45, 0.85)
	if not active:
		tint = dim
	else:
		var fade := clampf((_clock - _joined_at[i]) / 0.25, 0.0, 1.0)
		tint = tint.lerp(dim, 1.0 - fade)
	_shadow(feet, h, clampf(-y / (JUMP * h), 0.0, 1.0))
	var fl := fleece if fleece in ["black", "dark_brown"] else "black"
	_blit("mamuthone_%s_%s" % [fl, "b" if airborne else "a"], feet + Vector2(x, y), h, rot, sq, tint, side == 1)
