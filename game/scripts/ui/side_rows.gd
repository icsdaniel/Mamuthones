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

const MAX_PER_SIDE := 3
const ACTIVE := [1, 2, 2, 3, 3]     ## Mamuthones jumping per side at unison 0..4
## Where the figures stand, as a share of the way from the road's far end (0) to the hit line (1): the
## Issohadore off the hit rings, the Mamuthones receding toward the fire. From the Fire Night mockup.
const LEADER_AT := 0.75
const FILE_AT := [0.44, 0.24, 0.08]
## Their size on a 720-wide road (scaled with the road): the Issohadore's whole sprite (soha and all)
## at most this tall and wide, and each Mamuthone's height, nearest first, if its gap allows.
const LEADER_BOX := Vector2(90.0, 210.0)
const FILE_H := [190.0, 150.0, 120.0]
const CLEAR := 14.0                 ## px kept between a figure's box and the road edge (tests ask 12)
const JUMP := 0.15                  ## jump height, in figure heights
const AIR := 0.46                   ## share of the beat spent in the air (ends on the beat)
const CROUCH := 0.14                ## the crouch before take-off, as a share of the beat
const LAND := 0.16                  ## the squashed landing after the beat, as a share of the beat
const WAVE := 0.035                 ## beats of delay from one Mamuthone to the next down the file

## A Mamuthone joined the file (the unison went up): level is the new unison level.
signal joined(level: int)

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
	if active_count() > before:
		joined.emit(unison)


func set_still(on: bool) -> void:
	still = on


func settle() -> void:
	still = false


func jolt(kind := "step") -> void:
	_jolt_kind = kind
	_jolt_at = _clock


func throw_rope() -> void:
	_throw_at = _clock


## A full two-thumb stomp: the whole file slams down together, dust flies, the leaders throw.
func stomp() -> void:
	jolt("stomp")
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


## The sprite drawn at file place k of side s (0 the Issohadore), standing (not in a jump). The right
## file uses the same sprites mirrored (they face the road, lit from the fire's side).
func sprite_name(_s: int, k: int, pose := "stand") -> String:
	if k == 0:
		return FigureSprites.issohadore("throw" if pose == "throw" else "stand")
	return FigureSprites.mamuthone(fleece, pose)


## Screen pixels per art pixel for sprite `name` drawn h tall.
func _px(name: String, h: float) -> float:
	return h / FigureSprites.art_height(name)


## The screen box of the figure at file place k of side s, standing, in this control's coordinates.
func figure_box(s: int, k: int) -> Rect2:
	var pl := _place(s, k)
	return _box(sprite_name(s, k), pl[0], pl[1], s == 1)


func _box(name: String, feet: Vector2, h: float, flip := false) -> Rect2:
	var b := FigureSprites.bounds(name, _px(name, h), flip)
	return Rect2(feet + b.position, b.size)


## Place k of side s's file (0 the Issohadore, 1.. the Mamuthones): [feet, figure height]. Each figure
## is as big as the mockup has it (scaled with the road), shrunk if needed so its box stays CLEAR px
## outside the road edge at its feet (the road only narrows above them) and on the screen.
func _place(s: int, k: int) -> Array:
	if lanes != null and lanes.has_method("road_edges") and lanes.is_inside_tree() and is_inside_tree() and lanes.call("_road_on"):
		var f: Rect2 = lanes.call("field_rect")
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var hit_y: float = (lanes.call("project", Vector2(0.0, LaneSkin.hit_line_y(f))) as Vector2).y
		var at: float = LEADER_AT if k == 0 else float(FILE_AT[clampi(k - 1, 0, FILE_AT.size() - 1)])
		var ly := f.position.y + (hit_y - f.position.y) * at
		var edges: Vector2 = lanes.call("road_edges", ly)
		var e := (to_me * Vector2(edges.x if s == 0 else edges.y, ly))
		var feet_y := e.y
		var kw := f.size.x / 720.0
		var name := sprite_name(s, k)
		var b1 := FigureSprites.bounds(name, 1.0 / FigureSprites.art_height(name), s == 1)   # box of a figure 1 px tall
		var h: float
		if k == 0:
			h = minf(LEADER_BOX.y / b1.size.y, LEADER_BOX.x / b1.size.x) * kw
		else:
			h = float(FILE_H[clampi(k - 1, 0, FILE_H.size() - 1)]) * kw
		var room := (e.x - CLEAR - 2.0) if s == 0 else (size.x - 2.0 - e.x - CLEAR)
		h = clampf(minf(h, room / maxf(b1.size.x, 0.01)), 8.0, 400.0)
		var x := (e.x - CLEAR - b1.end.x * h) if s == 0 else (e.x + CLEAR - b1.position.x * h)
		if k == 0:
			# The Issohadore stands about 40 px in from the screen edge (mockup), never nearer the road.
			var want := 40.0 * kw if s == 0 else size.x - 40.0 * kw
			x = minf(x, maxf(want, 2.0 - b1.position.x * h)) if s == 0 else maxf(x, minf(want, size.x - 2.0 - b1.end.x * h))
		return [Vector2(x, feet_y), h]
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
		var wd: float = float(near[1]) * 0.6
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
	_shadow(feet, h * 0.8, clampf(-y / (0.1 * h), 0.0, 1.0))
	_blit(sprite_name(side, 0, "throw" if age < 0.4 else "stand"), feet + Vector2(0.0, y), h, 0.0, 1.0, Color.WHITE, side == 1)


## A soft ground shadow under the feet, thrown a little away from the fire (toward the screen edge).
func _shadow(feet: Vector2, h: float, lift: float) -> void:
	var r := h * 0.3 * (1.0 - 0.3 * lift)
	var away := -1.0 if feet.x < size.x * 0.5 else 1.0
	var c := feet + Vector2(away * r * 0.25, 1.0)
	draw_texture_rect(FireSkin.glow(), Rect2(c - Vector2(r, r * 0.26), Vector2(r * 2.0, r * 0.52)), false, Color(0, 0, 0, 0.85 * (1.0 - 0.4 * lift)))
	draw_set_transform(c, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, r * 0.55, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)


## A pixel figure with its feet at `feet`, h tall (the right file's are mirrored to face the road).
func _blit(name: String, feet: Vector2, h: float, rot: float, sq: float, tint: Color, flip := false) -> void:
	var px := _px(sprite_name(0, 0) if name.begins_with("issohadore") else name, h)
	var pxs := roundf(px) if px >= 1.5 else px
	FigureSprites.draw(self, name, Vector2(_snap(feet.x, pxs), _snap(feet.y, pxs)), pxs, flip, tint, rot, sq)


## The heavy jump through one beat (f = 0 on the beat): [pose, lift 0..1, squash]. The landing is ON
## the beat: a squashed "land" pose just after it, standing, a crouch to gather, then the jump - a
## slow rise and a fast drop, like something heavy.
static func jump_phase(f: float) -> Array:
	if f < LAND:
		var t := f / LAND
		return ["land", 0.0, lerpf(0.86, 1.0, t * t)]
	var take_off := 1.0 - AIR
	if f < take_off - CROUCH:
		return ["stand", 0.0, 1.0]
	if f < take_off:
		var t := (f - (take_off - CROUCH)) / CROUCH
		return ["crouch", 0.0, 1.0 - 0.06 * sin(t * PI * 0.5)]
	var a := (f - take_off) / AIR
	return ["air", sin(PI * pow(a, 1.45)), 1.02]


## Snaps a length to whole art pixels (px screen pixels each), so moving figures keep the grid.
static func _snap(v: float, px: float) -> float:
	return roundf(v / px) * px if px >= 1.5 else v


func _draw_one(feet: Vector2, h: float, i: int, side: int) -> void:
	var active := i < active_count()
	var y := 0.0
	var rot := 0.0
	var sq := 1.0
	var amp := 0.35 if reduced_motion else 1.0
	var pose := "stand"
	var land := -1.0     # seconds-ish share of the beat since touching down, for the dust
	if active and not still and beat > -8.0:
		var b := beat - WAVE * i
		var f := fposmod(b, 1.0)
		var ph := jump_phase(f)
		pose = ph[0]
		y = -float(ph[1]) * JUMP * h * amp
		sq = 1.0 - (1.0 - float(ph[2])) * amp
		if f < 0.3:
			land = f
		# the bells swing to the other side each landing
		var dir := 1.0 if posmod(floori(b), 2) == 0 else -1.0
		rot = dir * 0.035 * amp * (1.0 - f)
	var age := _clock - _jolt_at
	var x := 0.0
	var tint := Color.WHITE
	if active and age < 0.4:
		var k := 1.0 - age / 0.4
		match _jolt_kind:
			"miss":
				x = sin(age * 60.0) * h * 0.04 * k * amp
				tint = Color(1.0, 0.55 + 0.45 * (1.0 - k), 0.5 + 0.5 * (1.0 - k))
			"bell", "ring":
				rot += (0.1 if side == 0 else -0.1) * k * amp
			"stomp":
				# everyone slams down together: a deep squash and a big cloud of dust
				pose = "land"
				y = 0.0
				sq = 1.0 - 0.18 * k * amp
				land = age * 0.5
			_:
				y -= h * 0.02 * k * amp
	var dim := Color(0.5, 0.45, 0.45, 0.85)
	if not active:
		tint = dim
		pose = "stand"
	else:
		var fade := clampf((_clock - _joined_at[i]) / 0.25, 0.0, 1.0)
		tint = tint.lerp(dim, 1.0 - fade)
	var name := sprite_name(side, i + 1, pose)
	var px := _px(sprite_name(side, i + 1), h)     # every pose at the standing figure's scale
	var pxs := roundf(px) if px >= 1.5 else px
	_shadow(feet, h, clampf(-y / (JUMP * h), 0.0, 1.0))
	if land >= 0.0 and active:
		_dust(feet, pxs, land, _jolt_kind == "stomp" and age < 0.4, side)
	var at := Vector2(_snap(feet.x + x, pxs), _snap(feet.y + y, pxs))
	FigureSprites.draw(self, name, at, pxs, side == 1, tint, rot, sq)


## Dust kicked up by a landing: a few pixel clods that fly out low either side of the feet and fade,
## drawn on the art grid. t is the share of the beat since the landing.
func _dust(feet: Vector2, px: float, t: float, big: bool, _side: int) -> void:
	var life := 0.3
	if t >= life:
		return
	var k := t / life
	var reach := (16.0 if big else 10.0) * px
	var n := 7 if big else 5
	for j in n:
		var dir := -1.0 if j % 2 == 0 else 1.0
		var spread := (0.35 + 0.65 * float(j) / float(n)) * dir
		var dx := spread * reach * (0.3 + 0.7 * k)
		var dy := -sin(minf(k * 1.4, 1.0) * PI) * (2.0 + float(j % 3)) * px - px
		var a := (1.0 - k) * (0.9 if big else 0.7)
		var sz := px * (2.0 if j % 3 == 0 else 1.0)
		var p := Vector2(_snap(feet.x + dx, px), _snap(feet.y + dy, px))
		draw_rect(Rect2(p, Vector2(sz, sz)), Color(PixelPalette.STONE[4], a))
		if j % 2 == 0:
			draw_rect(Rect2(p + Vector2(0, sz), Vector2(sz, px)), Color(PixelPalette.STONE[2], a))
