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
## the figures fill the space left and right of the lanes. Each figure is baked once into a texture.

const MAX_PER_SIDE := 5
const ACTIVE := [1, 2, 3, 4, 5]     ## Mamuthones jumping per side at unison 0..4
const JUMP := 0.16                  ## jump height, in figure heights
const AIR := 0.55                   ## share of the beat spent in the air (ends on the beat)
const WAVE := 0.035                 ## beats of delay from one Mamuthone to the next down the file
const BAKE_H := 300.0               ## pixels tall the figure is baked at
const BAKE_W := 260.0

var lanes: Control
var beat := 0.0                     ## the song's beat now (fractional); negative before the music
var mask: Dictionary = MaskSpec.default()
var fleece := "black"
var straps := "natural"
var bell_set := "village"
var unison := 0
var still := false
var reduced_motion := false

var _vp: SubViewport
var _painter: Node2D
var _clock := 0.0
var _jolt_kind := ""
var _jolt_at := -9.0
var _joined_at: Array[float] = []   ## when each slot last joined, for a quick fade-in


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_PER_SIDE:
		_joined_at.append(-9.0)


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.size = Vector2i(int(BAKE_W), int(BAKE_H * 1.12))
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_painter = _Figure.new()
	_painter.rows = self
	_vp.add_child(_painter)


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
	pass


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
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		_painter.queue_redraw()


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


func _draw() -> void:
	var sides := gutters()
	var glow := Palette.tex("glow")
	for s in 2:
		var g: Rect2 = sides[s]
		if g.size.x < 24.0:
			continue
		# Firelight down the gutter, so the dark fleece reads on the black.
		if glow != null:
			draw_texture_rect(glow, g.grow_individual(g.size.x * 0.6, 0.0, g.size.x * 0.6, 0.0), false, Color(Palette.EMBER, 0.22))
		var h := figure_h(g.size.x)
		for i in range(MAX_PER_SIDE - 1, -1, -1):
			_draw_one(slot_feet(g, i), h * (1.0 - 0.05 * i), i, s)


func _draw_one(feet: Vector2, h: float, i: int, side: int) -> void:
	var active := i < active_count()
	var y := 0.0
	var rot := 0.0
	var sq := 1.0
	var amp := 0.35 if reduced_motion else 1.0
	if active and not still and beat > -8.0:
		var b := beat - WAVE * i
		var f := fposmod(b, 1.0)
		var air := clampf((f - (1.0 - AIR)) / AIR, 0.0, 1.0)
		y = -sin(air * PI) * JUMP * h * amp
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
	if not active:
		tint = Color(0.45, 0.42, 0.4, 0.8)
	else:
		var fade := clampf((_clock - _joined_at[i]) / 0.25, 0.0, 1.0)
		tint = tint.lerp(Color(0.45, 0.42, 0.4, 0.8), 1.0 - fade)
	# Shadow on the ground, smaller while airborne.
	var lift := clampf(-y / (JUMP * h), 0.0, 1.0)
	draw_set_transform(feet + Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, h * 0.26 * (1.0 - 0.3 * lift), Color(Palette.INK, 0.55))
	var s := h / BAKE_H
	draw_set_transform(feet + Vector2(x, y), rot, Vector2(s, s * sq))
	var tex := _vp.get_texture() if _vp != null else null
	if tex != null:
		var feet_px := Vector2(BAKE_W * 0.5, BAKE_H * 1.04)
		draw_texture_rect(tex, Rect2(-feet_px, Vector2(_vp.size)), false, tint)
	draw_set_transform(Vector2.ZERO)


## Paints the Mamuthone once into the bake viewport, feet near the bottom centre.
class _Figure extends Node2D:
	var rows: SideRows

	func _draw() -> void:
		draw_set_transform(Vector2(SideRows.BAKE_W * 0.5, SideRows.BAKE_H * 1.04))
		Figures.mamuthone(self, SideRows.BAKE_H * 0.97, rows.mask, rows.fleece, rows.straps, Palette.EMBER, 1, rows.bell_set)
		draw_set_transform(Vector2.ZERO)
