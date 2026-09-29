class_name SideRows
extends Control
## The two files of Mamuthones either side of the lanes on the play screen, jumping on the beat the
## way the real rows do: a crouch, a slow rise, a fast fall and a heavy landing ON the beat, the bells
## swinging to the other side each landing. The files join the player as the unison grows (one
## Mamuthone per side at level 0, the whole file at the top), stumble on a miss, and stand stock
## still through a stand-still. Each file is led by a red Issohadore, who every few bars spins his
## rope (the soha) over his head and casts it out to the crowd.
##
## Pixel art (docs/art-style.md): every figure is a sprite baked at 1x for its depth
## (tools/art/pixel/row_figures.py: a near, a mid and a far drawing), drawn at a whole PxArt.PX
## screen px per art px on the world's art grid (anchored on the road's far end, like the backdrop),
## never scaled, rotated or faded. A Mamuthone not yet dancing is its baked "dim" twin. The two
## files are not copies: each figure has its own variant (lean, how the carriga hangs), its own
## take-off and jump height; they all land together, on the beat.
##
## It answers the same calls as ProcessionScene (set_unison, jolt, set_still, settle, set_look ...),
## so the play screen talks to either. The play screen sets `beat` every frame and `lanes` once.

const MAX_PER_SIDE := 3
const ACTIVE := [1, 2, 2, 3, 3]     ## Mamuthones jumping per side at unison 0..4
## Where the figures stand, as a share of the way from the road's far end (0) to the hit line (1): the
## Issohadore off the hit rings, the Mamuthones receding toward the fire. From the Fire Night mockup.
const LEADER_AT := 0.62
const FILE_AT := [0.40, 0.22, 0.06]
const DEPTHS := ["near", "mid", "far"]   ## the baked drawing of each file place, nearest first
const PX := PxArt.PX                ## screen px per art px
const CLEAR := 14.0                 ## px kept between a figure's box and the road edge (tests ask 12)
const JUMP := 0.15                  ## jump height, in figure heights
const AIR := 0.46                   ## share of the beat spent in the air (ends on the beat)
const CROUCH := 0.14                ## the crouch before take-off, as a share of the beat
const LAND := 0.16                  ## the squashed landing after the beat, as a share of the beat
## Per file place (nearest first) of each side: the drawing's variant, how much earlier than the
## others it leaves the ground (beats; the landing is the same for all), and its jump height.
const VARIANT := [["a", "b", "a"], ["b", "a", "b"]]
const EARLY := [[0.0, 0.03, 0.015], [0.02, 0.0, 0.035]]
const HEIGHT := [[1.0, 0.85, 0.95], [0.9, 1.0, 0.8]]
const THROW_EVERY := 8              ## beats between one Issohadore's throws (the other is 4 beats off)

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
var _joined_at: Array[float] = []   ## when each slot last joined, for its puff of dust


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_PER_SIDE:
		_joined_at.append(-9.0)


func _ready() -> void:
	PxArt.nearest(self)


# ------------------------------------------------------------------ the ProcessionScene calls

func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural") -> void:
	mask = p_mask
	fleece = p_fleece
	straps = p_straps
	queue_redraw()


func set_bell_set(id: String) -> void:
	bell_set = id
	queue_redraw()


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


# ------------------------------------------------------------------ layout

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


func _road() -> bool:
	return lanes != null and lanes.has_method("road_edges") and lanes.has_method("_road_on") and lanes.is_inside_tree() and is_inside_tree() and bool(lanes.call("_road_on"))


## The world's art grid origin in this control's coordinates: the road's far end, as the backdrop has it.
func grid_origin() -> Vector2:
	if _road() and lanes.has_method("far_end"):
		var r: Rect2 = lanes.call("far_end")
		var xf := get_global_transform().affine_inverse() * lanes.get_global_transform()
		return xf * (r.position + Vector2(r.size.x * 0.5, 0.0))
	return Vector2.ZERO


## Snaps x (and y) to the art grid; dir < 0 rounds down, > 0 up, 0 to the nearest.
func _snap_x(x: float, dir := 0) -> float:
	var o := grid_origin().x
	var t := (x - o) / PX
	t = floorf(t) if dir < 0 else (ceilf(t) if dir > 0 else roundf(t))
	return o + t * PX


func _snap_y(y: float) -> float:
	var o := grid_origin().y
	return o + roundf((y - o) / PX) * PX


## Where slot i of side s stands: [feet, figure height], in this control's coordinates. Beside the
## perspective road the files stand on the ground outside its edges, receding toward the far end: each
## file is led by its Issohadore, nearest (file place 0), and slot 0 is the nearest Mamuthone behind
## him, each next one further up the road and smaller.
func slot(s: int, i: int) -> Array:
	return _place(s, i + 1)


## Where the Issohadore leading side s stands: [feet, figure height].
func leader(s: int) -> Array:
	return _place(s, 0)


## The baked drawing ("near", "mid", "far") at file place k (1.. the Mamuthones) of side s: the one
## its depth asks for, or a smaller one when the ground beside the road is too narrow for it.
func depth(s: int, k: int) -> String:
	return str(_place(s, k)[2])


## The sprite drawn at file place k of side s (0 the Issohadore), standing unless pose says. The
## right file uses the same sprites mirrored (they face the road, lit from the fire's side).
func sprite_name(s: int, k: int, pose := "stand") -> String:
	if k == 0:
		return FigureSprites.row_issohadore(pose if pose in ["swing", "cast"] else "stand")
	return _mam_name(s, k, str(_place(s, k)[2]), pose)


## The player's own Mamuthone is the nearest of the left file, in the fleece they chose; the rest of
## the files wear black sheepskin.
func _mam_name(s: int, k: int, d: String, pose: String) -> String:
	var v: String = VARIANT[s][clampi(k - 1, 0, 2)]
	return FigureSprites.row_mamuthone(d, fleece if s == 0 and k == 1 else "black", pose, v)


## The screen box of the figure at file place k of side s, standing, in this control's coordinates.
func figure_box(s: int, k: int) -> Rect2:
	var pl := _place(s, k)
	var b := FigureSprites.bounds(sprite_name(s, k), PX, s == 1)
	return Rect2((pl[0] as Vector2) + b.position, b.size)


## Place k of side s's file (0 the Issohadore, 1.. the Mamuthones): [feet, figure height, depth].
## Each stands at its share of the road's length, CLEAR px outside the road edge at its feet (the
## road only narrows above them), feet on the art grid, rounded away from the road.
func _place(s: int, k: int) -> Array:
	var want := "near" if k == 0 else str(DEPTHS[clampi(k - 1, 0, DEPTHS.size() - 1)])
	if _road():
		var f: Rect2 = lanes.call("field_rect")
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		var hit_y: float = (lanes.call("project", Vector2(0.0, LaneSkin.hit_line_y(f))) as Vector2).y
		var at: float = LEADER_AT if k == 0 else float(FILE_AT[clampi(k - 1, 0, FILE_AT.size() - 1)])
		var ly := f.position.y + (hit_y - f.position.y) * at
		var edges: Vector2 = lanes.call("road_edges", ly)
		var e := (to_me * Vector2(edges.x if s == 0 else edges.y, ly))
		var room := (e.x - CLEAR - 2.0 - PX) if s == 0 else (size.x - 2.0 - PX - e.x - CLEAR)
		var d := want
		var name := _name_at(s, k, d)
		var b := FigureSprites.bounds(name, PX, s == 1)
		if k > 0:
			var i := DEPTHS.find(d)
			while b.size.x > room and i < DEPTHS.size() - 1:
				i += 1
				d = DEPTHS[i]
				name = _name_at(s, k, d)
				b = FigureSprites.bounds(name, PX, s == 1)
		var x := (e.x - CLEAR - b.end.x) if s == 0 else (e.x + CLEAR - b.position.x)
		if k == 0:
			# The Issohadore stands about 40 px in from the screen edge (mockup), never nearer the road.
			var kw := f.size.x / 720.0
			var edge := 40.0 * kw if s == 0 else size.x - 40.0 * kw
			x = minf(x, maxf(edge, 2.0 - b.position.x)) if s == 0 else maxf(x, minf(edge, size.x - 2.0 - b.end.x))
		x = _snap_x(x, -1 if s == 0 else 1)
		return [Vector2(x, _snap_y(e.y)), b.size.y, d]
	# No road (a bare test harness): the file stacked up the gutter, the Issohadore at the bottom.
	var g: Rect2 = gutters()[s]
	var nm := _name_at(s, k, want)
	var h := FigureSprites.bounds(nm, PX).size.y
	var step := (g.size.y - 8.0 - h) / float(MAX_PER_SIDE)
	var feet := Vector2(g.get_center().x, g.end.y - 8.0 - step * k)
	return [Vector2(_snap_x(feet.x), _snap_y(feet.y)), h, want]


func _name_at(s: int, k: int, d: String) -> String:
	if k == 0:
		return FigureSprites.row_issohadore("stand")
	return _mam_name(s, k, d, "stand")


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	PxArt.nearest(self)
	var sides := gutters()
	var glow := FireSkin.glow()
	for s in 2:
		var g: Rect2 = sides[s]
		if not _road() and g.size.x < 24.0:
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
			_draw_one(s, i)
		_draw_leader(s)


## The heavy jump through one beat (f = 0 on the beat): [pose, lift 0..1, squash]. The landing is ON
## the beat: a squashed "land" pose just after it, standing, a crouch to gather, then the jump - a
## slow rise and a fast drop, like something heavy. `early` (beats) leaves the ground that much
## sooner and so hangs that much longer; the landing does not move.
static func jump_phase(f: float, early := 0.0) -> Array:
	if f < LAND:
		var t := f / LAND
		return ["land", 0.0, lerpf(0.9, 1.0, t * t)]
	var air := AIR + early
	var take_off := 1.0 - air
	if f < take_off - CROUCH:
		return ["stand", 0.0, 1.0]
	if f < take_off:
		var t := (f - (take_off - CROUCH)) / CROUCH
		return ["crouch", 0.0, 1.0 - 0.06 * sin(t * PI * 0.5)]
	var a := (f - take_off) / air
	return ["air", sin(PI * pow(a, 1.45)), 1.02]


## Snaps a length to whole art pixels (px screen pixels each), so moving figures keep the grid.
static func _snap(v: float, px: float) -> float:
	return roundf(v / px) * px if px >= 1.5 else v


func _draw_one(side: int, i: int) -> void:
	var k := i + 1
	var pl := _place(side, k)
	var feet: Vector2 = pl[0]
	var d: String = pl[2]
	var art_h := float(pl[1]) / PX
	var active := i < active_count()
	var amp := 0.35 if reduced_motion else 1.0
	var pose := "stand"
	var lift := 0.0                     # art px off the ground
	var land := -1.0                    # share of the beat since touching down, for the dust
	var b := beat
	if active and not still and beat > -8.0:
		var f := fposmod(b, 1.0)
		var ph := jump_phase(f, float(EARLY[side][i]))
		pose = ph[0]
		lift = float(ph[1]) * JUMP * art_h * float(HEIGHT[side][i]) * amp
		if pose == "land":
			if f < 0.3:
				land = f
			# the bells swing one way on one landing, the other way on the next
			if posmod(floori(b) + side + i, 2) == 1:
				pose = "land2"
	var age := _clock - _jolt_at
	var shake := 0.0
	if active and age < 0.4:
		var kk := 1.0 - age / 0.4
		match _jolt_kind:
			"miss":
				# a stumble: knees give, the body jerks a pixel either way
				shake = signf(sin(age * 60.0)) * (1.0 if kk > 0.3 else 0.0) * roundf(amp + 0.4)
				if lift < 1.0:
					pose = "crouch"
			"bell", "ring":
				if age < 0.18 and lift < 1.0:
					pose = "land2" if side == 0 else "land"
			"stomp":
				# everyone slams down together: a deep landing and a big cloud of dust
				pose = "land"
				lift = 0.0
				land = age * 0.5
	if not active:
		pose = "dim"
	elif _clock - _joined_at[i] < 0.3:
		land = (_clock - _joined_at[i]) * 0.5
	var name := _mam_name(side, k, d, pose)
	var up := roundf(lift) * PX
	_shadow(feet, float(pl[1]), clampf(lift / maxf(JUMP * art_h, 1.0), 0.0, 1.0))
	if land >= 0.0 and active:
		_dust(feet, land, _jolt_kind == "stomp" and age < 0.4, d)
	var at := feet + Vector2(shake * PX, -up)
	FigureSprites.draw(self, name, at, PX, side == 1)


## The Issohadore at the head of the file: red jacket, white trousers and mask. Every THROW_EVERY
## beats he spins the rope over his head for a beat and a half, then casts it out to the crowd
## beside the road and hauls it back; a stomp makes both throw at once.
func _draw_leader(side: int) -> void:
	var pl := leader(side)
	var feet: Vector2 = pl[0]
	var amp := 0.35 if reduced_motion else 1.0
	var pose := "stand"
	var t := -1.0                       # 0..1 through the throw
	var q := -1.0
	if not still and beat > -8.0:
		q = fposmod(beat + (THROW_EVERY * 0.5 if side == 1 else 0.0) + 2.0, float(THROW_EVERY))
		if q < 3.0:
			t = q / 3.0
	var age := _clock - _throw_at
	if age < 0.9:
		t = maxf(t, 0.35 + age / 0.9 * 0.65)
	var bob := 0.0
	if t >= 0.0:
		if t < 0.5:
			pose = "swing"
		elif t < 0.85:
			pose = "cast"
	elif not still and beat > -8.0:
		# he steps with the beat: down a pixel as the Mamuthones land
		bob = 1.0 if fposmod(beat, 1.0) < LAND else 0.0
	var name := FigureSprites.row_issohadore(pose)
	_shadow(feet, float(pl[1]), 0.0)
	var at := feet + Vector2(0.0, bob * PX)
	FigureSprites.draw(self, name, at, PX, side == 1)
	if t >= 0.0 and t < 0.97:
		_draw_rope(side, at, name, t, amp)


## The soha, a line of hemp-rope pixels on the art grid from his hand: spun as a loop over his head
## (t < 0.5), cast out and up toward the crowd on his side, away from the road (0.5 .. 0.85), then
## hauled back in.
func _draw_rope(side: int, at: Vector2, name: String, t: float, amp: float) -> void:
	var hand_art: Vector2 = FigureCells.HANDS.get(name, Vector2(-6, -60))
	var out := -1.0 if side == 0 else 1.0        # toward the screen edge
	var hand := Vector2(hand_art.x * (-1.0 if side == 1 else 1.0), hand_art.y)
	var pts: Array[Vector2] = []
	var centre: Vector2
	var rx := 7.0
	var ry := 3.0
	var ap := 0.0                     # where on the loop the spoke meets it (ellipse angle)
	if t < 0.5:
		# spun over his head: the loop wheels round, the spoke from his hand turning with it
		var ang := t / 0.5 * TAU * 2.0 * (0.5 + 0.5 * amp)
		rx = 7.0 - 1.0 * absf(sin(ang))
		ry = 2.5 + 1.5 * absf(sin(ang))
		centre = hand + Vector2(-out * 3.0 + cos(ang) * 1.5, -7.0 + sin(ang) * 0.8)
		ap = ang + PI
	else:
		# cast out and up to the crowd on his side of the road, then hauled back in
		var k := clampf((t - 0.5) / 0.35, 0.0, 1.0)
		var back := clampf((t - 0.85) / 0.12, 0.0, 1.0)
		k = k * (1.0 - back)
		centre = hand + Vector2(out * (2.0 + 14.0 * k) * (0.5 + 0.5 * amp), -7.0 - 9.0 * sin(k * PI * 0.6))
		rx = 7.0 + 2.0 * k
		ry = 3.0 + 1.0 * k
		ap = PI * 0.8 if out < 0.0 else PI * 0.2
	var attach := centre + Vector2(cos(ap) * rx, sin(ap) * ry)
	# the spoke from the hand to the loop, sagging a little, then round the loop
	var n := int(maxf(2.0, hand.distance_to(attach) * 2.0))
	for j in n:
		var p := hand.lerp(attach, float(j) / float(n))
		p.y += sin(float(j) / float(n) * PI) * 1.0
		pts.append(p)
	var m := int(maxf(20.0, TAU * rx * 2.0))
	for j in m + 1:
		var a := ap + float(j) / float(m) * TAU
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	var cells: Array[Vector2i] = []
	for p in pts:
		var c := Vector2i(floori(p.x), floori(p.y))
		if cells.is_empty() or cells[-1] != c:
			cells.append(c)
	for c in cells:
		draw_rect(Rect2(at + Vector2(c.x, c.y + 1) * PX, Vector2(PX, PX)), PixelPalette.K[0])
	for j in cells.size():
		var col: Color = PixelPalette.ROPE[0] if j % 4 == 0 else PixelPalette.ROPE[2 if j % 4 == 1 else 1]
		draw_rect(Rect2(at + Vector2(cells[j]) * PX, Vector2(PX, PX)), col)


## A ground shadow under the feet on the art grid: two rows of dark pixels, thrown a little away
## from the fire (toward the screen edge), shrinking as the figure leaves the ground.
func _shadow(feet: Vector2, h: float, lift: float) -> void:
	var half := int(roundf(h / PX * 0.3 * (1.0 - 0.35 * lift)))
	var away := -1 if feet.x < size.x * 0.5 else 1
	var c := PixelPalette.K[0]
	for row in 2:
		var w := half - row * 3
		var x0 := -w + away * 2
		draw_rect(Rect2(feet + Vector2(x0 * PX, (row - 1) * PX + PX), Vector2((w * 2) * PX, PX)), Color(c, 0.45 if row == 0 else 0.3))


## Dust kicked up by a landing: clods of lit stone that fly out low either side of the feet, drawn
## solid on the art grid, fewer and lower as they settle. t is the share of the beat since landing.
func _dust(feet: Vector2, t: float, big: bool, d: String) -> void:
	var life := 0.3
	if t >= life:
		return
	var k := t / life
	var scale := {"near": 1.0, "mid": 0.8, "far": 0.65}.get(d, 1.0) as float
	var reach := (16.0 if big else 11.0) * scale
	var n := 7 if big else 5
	var left := int(ceilf(float(n) * (1.0 - k * 0.8)))
	for j in left:
		var dir := -1.0 if j % 2 == 0 else 1.0
		var spread := (0.35 + 0.65 * float(j) / float(n)) * dir
		var dx := roundf(spread * reach * (0.3 + 0.7 * k))
		var dy := -roundf(sin(minf(k * 1.4, 1.0) * PI) * (2.0 + float(j % 3))) - 1.0
		var sz := 2.0 if j % 3 == 0 and k < 0.6 else 1.0
		var p := feet + Vector2(dx, dy) * PX
		draw_rect(Rect2(p, Vector2(sz, sz) * PX), PixelPalette.STONE[4])
		if sz > 1.0:
			draw_rect(Rect2(p + Vector2(0, PX), Vector2(sz * PX, PX)), PixelPalette.STONE[2])
