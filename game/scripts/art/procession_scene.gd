class_name ProcessionScene
extends Control
## The procession, drawn as a living woodcut: your Mamuthone in a row of Mamuthones that jolt together,
## the Issohadores ahead with the rope, the crowd and the fire behind, winter fog drifting through.
## Used at the top of the play screen and behind menus; it lays itself out for any rect (the scale is
## set by the height, down to a 600-unit-wide design space, and extra room becomes sky).
##
## API (docs/architecture.md "Art API"):
##   set_stop(n)                    1..7, a distinct backdrop per story stop (StopBackdrops)
##   set_look(mask, fleece, straps) the player's MaskSpec dict, fleece id, strap id
##   jolt(kind)                     "step" | "bell" | "ring" | "miss"
##   set_unison(level)              0..5: the row closes up and jolts harder and more together
##   set_ghost_delta(seconds)       shows your ghost beside you; > 0 means the ghost is ahead of you
##   hide_ghost()
##   set_still(bool)                stand-still: the row freezes, bells hang
##   throw_rope()                   the front Issohadore throws the rope into the crowd
##   set_reduced_motion(bool)       calms flicker, fog drift, sparks, sway and jolts
## Extras: auto_bpm (> 0 makes the row walk and ring on its own, for menus), framed (ink edges).
##
## Cost: everything static (the backdrop, the crowd in front of the fires, and each figure's bells,
## body and head) is drawn once into textures (SubViewports, rendered once per stop, look or size
## change); per frame the scene is a few dozen textured rects that only move, one shader quad per fire,
## two fog quads, and a few sparks and the rope.

const DESIGN_H := 480.0
const DESIGN_MIN_W := 600.0
const FRONT := 3
const BACK := 3

## The current stop (1..7); change it with set_stop().
var stop := 1
## Beats per minute for an automatic walk (menus, trailers). 0 = only jolts from the game.
@export var auto_bpm := 0.0
## Draw the static layers once into textures (fast). Off draws the same geometry live (slow, for debugging).
@export var bake := true
## Rough ink edges at the top and bottom, so the band sits in the page like a print.
@export var framed := true:
	set(v):
		framed = v
		if _frame:
			_frame.queue_redraw()
## The small ember arc under your own Mamuthone's feet. Off for illustrations (the stop cards).
## Set it before the scene enters the tree or before set_stop().
@export var show_player_mark := true

var mask: Dictionary = MaskSpec.default()
var fleece := "black"
var straps := "natural"
var unison := 0
var still := false
var reduced_motion := false
var ghost_delta := 0.0
var ghost_visible := false
## Microseconds spent in the last _process (for the timing test).
var last_process_usec := 0
## How many times the textures were re-rendered (stop, look or size changes only).
var bake_count := 0

var _k := 1.0
var _w := 720.0
var _h := 480.0
var _g := 450.0
var _hf := 240.0
var _t := 0.0
var _beat_t := 0.0
var _beat_n := 0
var _bell_up := true
var _rope_t := -1.0
var _miss_flash := 0.0
var _built := false

var _world: Node2D
var _back: _Paint
var _glow: _Paint
var _fires: Array[ColorRect] = []
var _front: _Paint
var _fog_far: ColorRect
var _fog_near: ColorRect
var _sparks: _Paint
var _ghost: _Paint
var _rope: _Paint
var _frame: _Paint
var _walkers: Array[_Walker] = []
var _player: _Walker
var _issos: Array[_Walker] = []
var _arm: _Paint
var _ghost_x := 0.0
var _motion: _Paint
var _onlooker: _Paint
var _stumble_t := -1.0
var _motion_drawn := false
var _row := {}
var _fire_mat: ShaderMaterial
var _fog_mats: Array[ShaderMaterial] = []

static var _fire_shader: Shader
static var _fog_shader: Shader

# Baking: figure layers go into cells of one atlas; backdrop and front each get their own texture.
const CELL_MIN := Vector2(-0.46, -1.06)   ## in figure heights (_hf)
const CELL_SIZE := Vector2(0.92, 1.13)
const COLS := 7
const MAX_TEX := 4096
const FRONT_TOP := 260.0   ## how far above the ground the front layer can reach
var _atlas_vp: SubViewport
var _bg_vp: SubViewport
var _fg_vp: SubViewport
var _bg_src: _Paint
var _fg_src: _Paint
var _cell_src: Array[_Paint] = []
var _cell_painters: Array[Callable] = []
var _cell_offsets: Array[Vector2] = []
var _cell_rects: Array[Rect2] = []
var _px := 1.0
var _premult: CanvasItemMaterial


## A Node2D whose drawing is a Callable (retained until redraw()).
class _Paint:
	extends Node2D
	var painter: Callable

	func _init(p: Callable = Callable()) -> void:
		painter = p

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## One figure in the row and its jolt physics.
class _Walker:
	var root := Node2D.new()
	var pivot := Node2D.new()  # the bell load swings from the shoulders
	var back: _Paint
	var body: _Paint
	var head: _Paint
	var is_player := false
	var is_isso := false
	var line := 0              # 0 front, 1 back
	var slot := 0
	var scatter := 0.0         # how out of step this one is at low unison, 0..1
	var phase := 0.0
	var x := 0.0
	var target_x := 0.0
	var y := 0.0
	var vy := 0.0
	var hy := 0.0
	var vhy := 0.0
	var rot := 0.0
	var vrot := 0.0
	var bell := 0.0
	var vbell := 0.0
	var pending: Array = []    # [[delay, amp, bell_dir], ...]
	var base_y := 0.0          # ground line for this stop
	var sc := 1.0              # size for this stop
	var flip := 1.0            # -1 when the row walks left
	var ring := 0.0            # 0..1, how hard its bells rang just now (motion lines)


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	resized.connect(_on_resized)
	_on_resized()


# ------------------------------------------------------------------ API

func set_stop(n: int) -> void:
	n = clampi(n, 1, StopBackdrops.COUNT)
	var changed := n != stop or not _built
	stop = n
	if _built and changed:
		_rebuild_stop()


func set_look(p_mask: Dictionary, p_fleece := "black", p_straps := "natural") -> void:
	mask = MaskSpec.sanitize(p_mask)
	fleece = p_fleece if Palette.FLEECE.has(p_fleece) else "black"
	straps = p_straps if Palette.STRAPS.has(p_straps) else "natural"
	if _built:
		_rebake(false)


func jolt(kind := "step") -> void:
	if not _built:
		return
	var amp: float = {"step": 6.0, "bell": 11.0, "ring": 15.0, "miss": 0.0}.get(kind, 6.0)
	amp *= 1.0 + 0.14 * float(unison)
	if reduced_motion:
		amp *= 0.35
	var bell_dir := 0.0
	if kind == "bell" or kind == "ring":
		bell_dir = 1.0 if _bell_up else -1.0
		_bell_up = not _bell_up
	if kind == "miss":
		# Your Mamuthone stumbles: pitches forward and down, drops back a step, the head lolls, a scuff
		# of dust at the feet; then the springs bring him back into the row.
		var k := 0.35 if reduced_motion else 1.0
		_player.vrot += 9.0 * k
		_player.vy += 220.0 * k
		_player.vhy += 160.0 * k
		_player.x -= _spacing() * 0.16 * k * _player.flip
		_player.vbell -= 1.2 * k
		_miss_flash = 1.0
		_stumble_t = 0.0
		return
	var together := float(unison) / 5.0
	for w in _walkers:
		if w.is_isso:
			if kind != "step":
				w.pending.append([0.05, amp * 0.4, 0.0])
			continue
		# At low unison each Mamuthone rings late by his own amount and with his own strength
		# (ragged); at full unison they all ring on the same instant, equally.
		var delay := 0.0 if w.is_player else w.scatter * (1.0 - together) * 0.22 + 0.005
		var a := amp * (1.0 if w.is_player else lerpf(0.4 + 0.6 * w.scatter, 1.0, together))
		w.pending.append([delay, a, bell_dir])


func set_unison(level: int) -> void:
	unison = clampi(level, 0, 5)
	_place_row(false)


func set_ghost_delta(seconds: float) -> void:
	ghost_delta = seconds
	ghost_visible = true
	if _ghost:
		_ghost.visible = true


func hide_ghost() -> void:
	ghost_visible = false
	if _ghost:
		_ghost.visible = false


func set_still(on: bool) -> void:
	still = on


func throw_rope() -> void:
	_rope_t = 0.0


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	_apply_motion()


# ------------------------------------------------------------------ building

func _build() -> void:
	if _built:
		return
	if _fire_shader == null:
		_fire_shader = load("res://shaders/woodcut_fire.gdshader")
		_fog_shader = load("res://shaders/woodcut_fog.gdshader")
	_premult = CanvasItemMaterial.new()
	_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_bg_vp = _make_vp(false)
	_fg_vp = _make_vp(true)
	_atlas_vp = _make_vp(true)
	_bg_src = _Paint.new(func(ci): StopBackdrops.paint(ci, stop, _w, _h, _g))
	_bg_vp.add_child(_bg_src)
	_fg_src = _Paint.new(func(ci): StopBackdrops.paint_front(ci, stop, _w, _h, _g))
	_fg_vp.add_child(_fg_src)
	_world = Node2D.new()
	add_child(_world)
	_back = _Paint.new(func(ci): _draw_layer(ci, _bg_vp, _bg_src))
	_world.add_child(_back)
	_glow = _Paint.new(_paint_glow)
	_world.add_child(_glow)
	_fire_mat = ShaderMaterial.new()
	_fire_mat.shader = _fire_shader
	_fire_mat.set_shader_parameter("noise_tex", Palette.tex("fog"))
	# Fire quads are created per stop in _rebuild_stop; they sit here in the tree.
	var fires_root := Node2D.new()
	fires_root.name = "Fires"
	_world.add_child(fires_root)
	_sparks = _Paint.new(_paint_sparks)
	_world.add_child(_sparks)
	_front = _Paint.new(func(ci): _draw_layer(ci, _fg_vp, _fg_src))
	_front.material = _premult
	_world.add_child(_front)
	_fog_far = _make_fog()
	_world.add_child(_fog_far)
	# The row: back line first (drawn behind), then the ghost, then the front line.
	var order := []
	for i in BACK:
		order.append(_make_walker(1, i, false))
	var isso_back := _make_walker(1, BACK, true)
	order.append(isso_back)
	for w in order:
		_world.add_child(w.root)
	_ghost = _cell(func(ci): Figures.ghost(ci, _hf * 0.97, Color(Palette.EMBER, 0.6)), Vector2.ZERO, Rect2(-0.35, -1.02, 0.7, 1.05))
	_ghost.visible = ghost_visible
	_world.add_child(_ghost)
	var front := []
	for i in FRONT:
		front.append(_make_walker(0, i, false))
	var isso_front := _make_walker(0, FRONT, true)
	front.append(isso_front)
	for w in front:
		_world.add_child(w.root)
	_player = front[1]
	_player.is_player = true
	_player.scatter = 0.0
	_walkers.clear()
	for w in order:
		_walkers.append(w)
	for w in front:
		_walkers.append(w)
	_issos = [isso_back, isso_front]
	_arm = _cell(func(ci): Figures.issohadore_arm(ci, _hf * 0.93), Vector2(0, -0.5), Rect2(-0.06, -0.02, 0.12, 0.3))
	isso_front.body.add_child(_arm)
	_motion = _Paint.new(_paint_motion)
	_world.add_child(_motion)
	_onlooker = _cell(func(ci): Figures.crowd_person(ci, _hf * 0.8, 0, Color("#2a221d"), Color("#f0cf95", 0.7), 5), Vector2.ZERO, Rect2(-0.24, -0.84, 0.48, 0.86))
	_world.add_child(_onlooker)
	_rope = _Paint.new(_paint_rope)
	_world.add_child(_rope)
	_fog_near = _make_fog()
	_world.add_child(_fog_near)
	_frame = _Paint.new(_paint_frame)
	add_child(_frame)
	_built = true
	_rebuild_stop()
	_apply_motion()


func _make_walker(line: int, slot: int, isso: bool) -> _Walker:
	var w := _Walker.new()
	w.line = line
	w.slot = slot
	w.is_isso = isso
	w.scatter = WoodcutDraw.hash01(line * 10 + slot, 17)
	w.phase = WoodcutDraw.hash01(line * 10 + slot, 18) * TAU
	var lit_of := func() -> Color: return StopBackdrops.info(stop).lit
	var detail := 1
	var mine := func() -> bool: return w.is_player
	if isso:
		w.back = _Paint.new()
		w.body = _cell(func(ci): Figures.issohadore_body(ci, _hf * 0.93, lit_of.call(), detail), Vector2.ZERO, Rect2(-0.25, -0.8, 0.47, 0.83))
		w.head = _cell(func(ci): Figures.issohadore_head(ci, _hf * 0.93, detail), Vector2.ZERO, Rect2(-0.1, -0.97, 0.27, 0.26))
	else:
		w.back = _cell(func(ci): Figures.mamuthone_back(ci, _hf, lit_of.call(), detail), Vector2.ZERO, Rect2(-0.42, -1.0, 0.84, 0.72))
		w.body = _cell(func(ci):
			if mine.call() and show_player_mark:
				_paint_player_mark(ci)
			Figures.mamuthone_body(ci, _hf, fleece if mine.call() else _npc_fleece(w), straps if mine.call() else "natural", lit_of.call(), detail), Vector2.ZERO, Rect2(-0.27, -0.85, 0.54, 0.91))
		w.head = _cell(func(ci): Figures.mamuthone_head(ci, _hf, mask if mine.call() else _npc_mask(w), straps if mine.call() else "natural", detail), Vector2.ZERO, Rect2(-0.17, -1.0, 0.34, 0.22))
	w.root.add_child(w.pivot)
	w.pivot.add_child(w.back)
	w.root.add_child(w.body)
	w.root.add_child(w.head)
	return w


func _npc_fleece(w: _Walker) -> String:
	return "dark_brown" if (w.slot + w.line) % 3 == 2 else "black"


## Other Mamuthones wear their own masks: a fixed mix of real forms.
func _npc_mask(w: _Walker) -> Dictionary:
	var m := {}
	for part in MaskSpec.PARTS:
		var opts := MaskSpec.options(part)
		m[part] = opts[int(WoodcutDraw.hash01(w.line * 10 + w.slot, part.length() * 7) * opts.size()) % opts.size()]
	return m


func _make_fog() -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _fog_shader
	m.set_shader_parameter("noise_tex", Palette.tex("fog"))
	r.material = m
	_fog_mats.append(m)
	return r


func _rebuild_stop() -> void:
	var inf := StopBackdrops.info(stop)
	var fires_root: Node2D = _world.get_node("Fires")
	for f in _fires:
		f.queue_free()
	_fires.clear()
	for i in inf.fires.size():
		var fr := ColorRect.new()
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: ShaderMaterial = _fire_mat.duplicate()
		m.set_shader_parameter("seed", float(i) * 0.37 + float(stop) * 0.11)
		fr.material = m
		fires_root.add_child(fr)
		_fires.append(fr)
	var fog: Array = inf.fog
	for m in _fog_mats:
		m.set_shader_parameter("fog_color", fog[1])
	_fog_mats[0].set_shader_parameter("density", fog[0])
	_fog_mats[1].set_shader_parameter("density", fog[0] * 0.4)
	_apply_motion()
	_layout()


## Resizes arrive in bursts (window drags, container animations): move things at once, but re-render
## the baked textures only once the size has settled for REBAKE_DELAY seconds.
const REBAKE_DELAY := 0.15
var _rebake_due := -1.0


func _on_resized() -> void:
	if not _built:
		return
	if bake_count == 0:
		_layout()
		return
	_layout(false)
	_rebake_due = REBAKE_DELAY


func _layout(rebake := true) -> void:
	var sz := size
	if sz.x < 2.0 or sz.y < 2.0:
		return
	_k = minf(sz.y / DESIGN_H, sz.x / DESIGN_MIN_W)
	_w = sz.x / _k
	_h = sz.y / _k
	_g = _h - 22.0
	_hf = DESIGN_H * 0.43
	_world.scale = Vector2(_k, _k)
	_world.position = Vector2.ZERO
	var inf := StopBackdrops.info(stop)
	for i in _fires.size():
		var f: Dictionary = inf.fires[i]
		var fw: float = f.w
		var fh: float = f.h
		_fires[i].size = Vector2(fw, fh)
		_fires[i].position = Vector2(_w * float(f.x) - fw * 0.5, _g - float(f.y) - fh)
	_fog_far.position = Vector2(0, _g - 230.0)
	_fog_far.size = Vector2(_w, 230.0)
	_fog_near.position = Vector2(0, _g - 70.0)
	_fog_near.size = Vector2(_w, _h - _g + 70.0)
	(_fog_far.material as ShaderMaterial).set_shader_parameter("aspect", _w / 230.0)
	(_fog_near.material as ShaderMaterial).set_shader_parameter("aspect", _w / (_h - _g + 70.0))
	(_fog_near.material as ShaderMaterial).set_shader_parameter("rise", 0.2)
	(_fog_near.material as ShaderMaterial).set_shader_parameter("lines", 7.0)
	(_fog_far.material as ShaderMaterial).set_shader_parameter("lines", 16.0)
	_row = StopBackdrops.row(stop)
	var rs: float = _row.scale
	var shade: Color = _row.shade
	var fl := -1.0 if _row.flip else 1.0
	for w in _walkers:
		# Real people differ a little in height (and differently at every stop); the back line is further away.
		var vary := (WoodcutDraw.hash01(w.line * 10 + w.slot, 23 + stop) - 0.5) * (0.0 if w.is_player else 0.08)
		w.sc = rs * (1.0 if w.line == 0 else 0.84 - float(_row.depth) * 0.6) * (1.0 + vary)
		w.flip = fl
		w.root.visible = _walker_shown(w)
		var c := (Color.WHITE if w.line == 0 else Color(0.78, 0.76, 0.74)) * shade
		c.a = 1.0
		w.body.modulate = c
		w.back.modulate = c
		w.head.modulate = c
		w.pivot.position = Vector2(0, -_hf * 0.8)
		w.back.position = Vector2(0, _hf * 0.8)
		if w.is_isso and w.line == 0 and _row.has("isso_at"):
			w.sc = float(_row.isso_at[2])
		w.root.scale = Vector2(w.sc * fl, w.sc)
	_onlooker.visible = _row.has("onlooker")
	if _onlooker.visible:
		var ol: Array = _row.onlooker
		_onlooker.position = Vector2(_w * float(ol[0]), _g + float(ol[1]))
		_onlooker.scale = Vector2(-float(ol[2]), float(ol[2]))
	_place_row(true)
	_arm.position = Vector2(14.5, -77.0) * _hf * 0.93 / 100.0
	for n in [_glow, _frame]:
		n.queue_redraw()
	if rebake:
		_rebake_due = -1.0
		_rebake(true)
	else:
		for w in _walkers:
			for n in [w.back, w.body, w.head]:
				n.queue_redraw()
		for n in [_arm, _ghost, _back, _front]:
			n.queue_redraw()


## Which figures this stop's staging shows. Your Mamuthone (front slot 1) always walks.
func _walker_shown(w: _Walker) -> bool:
	if w.is_player:
		return true
	if w.is_isso:
		var n: int = _row.get("isso", 2)
		return n >= 2 or (n == 1 and w.line == 0)
	if w.line == 0:
		var n: int = _row.get("front", FRONT)
		return n >= 3 or (n == 2 and w.slot == 0)
	return w.slot < int(_row.get("back", BACK))


## Row spacing for the current unison and staging.
func _spacing() -> float:
	var tight := float(unison) / 5.0
	return lerpf(_hf * 0.56, _hf * 0.4, tight) * float(_row.get("scale", 1.0)) * float(_row.get("spread", 1.0))


## Row positions for the current unison: the row closes up as unison rises.
func _place_row(snap: bool) -> void:
	if not _built:
		return
	if _row.is_empty():
		_row = StopBackdrops.row(stop)
	var tight := float(unison) / 5.0
	var spacing := _spacing()
	var row_w := spacing * float(FRONT - 1)
	var cx := _w * float(_row.x)
	var x0 := cx - row_w * 0.5
	var fl := -1.0 if _row.flip else 1.0
	var ground: float = _g + float(_row.ground)
	for w in _walkers:
		var x: float
		if w.is_isso:
			x = x0 + row_w + spacing * (1.25 if w.line == 0 else 0.8)
		elif w.line == 0:
			x = x0 + spacing * float(w.slot)
		else:
			x = x0 + spacing * (float(w.slot) + 0.5)
		# Out-of-step Mamuthones straggle a little at low unison.
		if not w.is_player and not w.is_isso:
			x += (w.scatter - 0.5) * spacing * 0.3 * (1.0 - tight)
		x = cx + (x - cx) * fl
		w.base_y = ground if w.line == 0 else ground - _hf * float(_row.depth)
		if w.is_isso and w.line == 0 and _row.has("isso_at"):
			x = _w * float(_row.isso_at[0])
			w.base_y = _g + float(_row.isso_at[1])
		w.target_x = x
		if snap:
			w.x = x
	_ghost_x = _player.target_x - spacing * 0.5 * fl if snap else _ghost_x


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if not _built:
		return
	var t0 := Time.get_ticks_usec()
	if _rebake_due >= 0.0:
		_rebake_due -= delta
		if _rebake_due < 0.0:
			_rebake(true)
	delta = minf(delta, 0.05)
	_t += delta
	if auto_bpm > 0.0 and not still:
		_beat_t += delta
		var beat := 60.0 / auto_bpm
		if _beat_t >= beat:
			_beat_t -= beat
			_beat_n += 1
			jolt("bell" if _beat_n % 4 == 0 else "step")
			if _beat_n % 16 == 8:
				throw_rope()
	var together := float(unison) / 5.0
	for w in _walkers:
		# Queued jolts.
		var i := 0
		while i < w.pending.size():
			var p: Array = w.pending[i]
			p[0] -= delta
			if p[0] <= 0.0:
				w.vy -= float(p[1]) * 26.0
				w.vhy -= float(p[1]) * 10.0
				w.vbell += float(p[2]) * float(p[1]) * 0.09 + float(p[1]) * 0.02
				if absf(float(p[2])) > 0.0:
					w.ring = maxf(w.ring, clampf(float(p[1]) / 12.0, 0.3, 1.0))
				w.pending.remove_at(i)
			else:
				i += 1
		# Springs: body bounce, head follow-through, bell swing, stumble.
		w.vy += (-320.0 * w.y - 20.0 * w.vy) * delta
		w.y += w.vy * delta
		w.vhy += (-260.0 * (w.hy - w.y * 0.35) - 16.0 * w.vhy) * delta
		w.hy += w.vhy * delta
		w.vbell += (-140.0 * w.bell - 7.0 * w.vbell) * delta
		w.bell += w.vbell * delta
		w.vrot += (-120.0 * w.rot - 12.0 * w.vrot) * delta
		w.rot += w.vrot * delta
		w.x = lerpf(w.x, w.target_x, minf(1.0, delta * 3.0))
		var sway := 0.0
		var lean := 0.0
		if not still and not reduced_motion:
			var ph := w.phase * (1.0 - together)
			sway = sin(_t * 2.2 + ph) * 1.3
			lean = sin(_t * 1.1 + ph) * 0.012
		w.root.position = Vector2(w.x, w.base_y + w.y + sway)
		w.root.rotation = (lean + w.rot * 0.35) * w.flip
		w.head.position = Vector2(0, w.hy - w.y * 0.2)
		w.pivot.rotation = clampf(w.bell * 0.9, -0.16, 0.16)
		w.ring = maxf(0.0, w.ring - delta * 2.6)
	# Player feedback on a miss: the stumble plus a brief red cast.
	if _miss_flash > 0.0:
		_miss_flash = maxf(0.0, _miss_flash - delta * 2.5)
		var c := Color(1.0, 1.0 - 0.35 * _miss_flash, 1.0 - 0.4 * _miss_flash)
		_player.body.modulate = c * _row.get("shade", Color.WHITE)
		_player.head.modulate = _player.body.modulate
	# Ghost drifts to where it would be.
	if ghost_visible:
		var spacing := _spacing()
		var fl := _player.flip
		var gx := _player.x + (-spacing * 0.5 + clampf(ghost_delta * 90.0, -spacing * 0.6, spacing * 0.9)) * fl
		_ghost_x = lerpf(_ghost_x, gx, minf(1.0, delta * 4.0))
		_ghost.position = Vector2(_ghost_x, _player.base_y - _hf * 0.045 * _player.sc + sin(_t * 2.2) * (0.0 if reduced_motion or still else 1.0))
		_ghost.scale = Vector2(_player.sc * fl, _player.sc)
	# Firelight flicker.
	if not reduced_motion:
		_glow.modulate.a = 0.86 + 0.1 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0) + 0.04 * sin(_t * 23.0)
	# Rope throw: arm up, rope out into the crowd, back.
	var isso: _Walker = _issos[1]
	if _rope_t >= 0.0:
		_rope_t += delta
		var dur := 1.1
		var u := _rope_t / dur
		_arm.rotation = -2.3 * sin(clampf(u * 1.6, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.75, 1.0, u))
		isso.body.rotation = -0.06 * sin(clampf(u, 0.0, 1.0) * PI)
		if u >= 1.0:
			_rope_t = -1.0
			_arm.rotation = 0.0
			isso.body.rotation = 0.0
		_rope.queue_redraw()
	if StopBackdrops.info(stop).sparks and not reduced_motion:
		_sparks.queue_redraw()
	if _stumble_t >= 0.0:
		_stumble_t += delta
		if _stumble_t > 0.6:
			_stumble_t = -1.0
	# Motion marks only while something rings or stumbles (and once more to clear them).
	var moving := _stumble_t >= 0.0
	for w in _walkers:
		if w.ring > 0.0:
			moving = true
			break
	if moving or _motion_drawn:
		_motion.queue_redraw()
	_motion_drawn = moving
	last_process_usec = Time.get_ticks_usec() - t0


func _apply_motion() -> void:
	if not _built:
		return
	var fire_speed := 0.12 if reduced_motion else 1.0
	for f in _fires:
		(f.material as ShaderMaterial).set_shader_parameter("speed", fire_speed)
	for m in _fog_mats:
		m.set_shader_parameter("speed", 0.002 if reduced_motion else 0.018)
	if reduced_motion:
		_glow.modulate.a = 0.92
	_sparks.visible = not reduced_motion


# ------------------------------------------------------------------ baking

func _make_vp(transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.size = Vector2i(4, 4)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	return vp


## A figure layer: its painter is drawn once into an atlas cell, and the returned node draws that cell.
## `offset` (in figure heights) shifts the drawing inside the cell for pieces that hang below the feet.
## `used` (figure heights, relative to the feet) is the part of the cell that has ink, so only that is
## drawn each frame (less overdraw).
func _cell(painter: Callable, offset := Vector2.ZERO, used := Rect2(CELL_MIN, CELL_SIZE)) -> _Paint:
	var i := _cell_src.size()
	var src := _Paint.new(func(ci):
		var o := offset * _hf
		if o != Vector2.ZERO:
			WoodcutDraw.set_transform(ci, o)
		painter.call(ci)
		if o != Vector2.ZERO:
			WoodcutDraw.set_transform(ci, Vector2.ZERO))
	_atlas_vp.add_child(src)
	_cell_src.append(src)
	_cell_painters.append(painter)
	_cell_offsets.append(offset)
	_cell_rects.append(used)
	var disp := _Paint.new(func(ci): _draw_cell(ci, i))
	disp.material = _premult
	return disp


func _draw_cell(ci: CanvasItem, i: int) -> void:
	if not bake:
		_cell_painters[i].call(ci)
		return
	var cell_px := CELL_SIZE * _hf * _px
	var used := _cell_rects[i]
	var origin := Vector2(float(i % COLS), float(i / COLS)) * cell_px - CELL_MIN * _hf * _px
	var src := Rect2(origin + (used.position + _cell_offsets[i]) * _hf * _px, used.size * _hf * _px)
	var dest := Rect2(used.position * _hf, used.size * _hf)
	ci.draw_texture_rect_region(_atlas_vp.get_texture(), dest, src)


func _draw_layer(ci: CanvasItem, vp: SubViewport, src: _Paint) -> void:
	if not bake:
		src.painter.call(ci)
		return
	if vp == _fg_vp:
		# The front layer (crowds, bonfire logs) only has ink near the ground: skip the empty sky.
		var top := maxf(0.0, _g - FRONT_TOP)
		var k := float(vp.size.y) / _h
		ci.draw_texture_rect_region(vp.get_texture(), Rect2(0, top, _w, _h - top), Rect2(0, top * k, float(vp.size.x), (_h - top) * k))
		return
	ci.draw_texture_rect(vp.get_texture(), Rect2(0, 0, _w, _h), false)


## Pixels per design unit on screen (layout scale times any stretch of the window or parents).
func _screen_scale() -> float:
	var s := get_global_transform_with_canvas().get_scale().x
	if get_viewport():
		s *= get_viewport().get_final_transform().get_scale().x
	return clampf(s, 0.25, 4.0)


## Re-renders the baked textures: the backdrop layers when `all`, the figure atlas always.
func _rebake(all: bool) -> void:
	if not _built:
		return
	bake_count += 1
	var px := _screen_scale()
	var cells := _cell_src.size()
	var rows := int(ceil(float(cells) / float(COLS)))
	var cell_units := CELL_SIZE * _hf
	# Keep every texture within MAX_TEX on its longest side.
	px = minf(px, float(MAX_TEX) / maxf(_w, _h) / maxf(_k, 0.001) * _k)
	_px = minf(px, float(MAX_TEX) / maxf(cell_units.x * COLS, cell_units.y * rows))
	var bg_px := minf(px, float(MAX_TEX) / maxf(_w, _h))
	if all:
		for pair in [[_bg_vp, _bg_src], [_fg_vp, _fg_src]]:
			var vp: SubViewport = pair[0]
			var src: _Paint = pair[1]
			vp.size = Vector2i(int(ceil(_w * bg_px)), int(ceil(_h * bg_px)))
			src.scale = Vector2(bg_px, bg_px)
			src.queue_redraw()
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cell_px := cell_units * _px
	_atlas_vp.size = Vector2i(int(ceil(cell_px.x * COLS)), int(ceil(cell_px.y * rows)))
	for i in cells:
		var src := _cell_src[i]
		src.scale = Vector2(_px, _px)
		src.position = Vector2(float(i % COLS), float(i / COLS)) * cell_px - CELL_MIN * _hf * _px
		src.queue_redraw()
	_atlas_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for w in _walkers:
		for n in [w.back, w.body, w.head]:
			n.queue_redraw()
	for n in [_arm, _ghost, _back, _front]:
		n.queue_redraw()


# ------------------------------------------------------------------ dynamic drawing

func _paint_glow(ci: CanvasItem) -> void:
	var inf := StopBackdrops.info(stop)
	var g: Array = inf.glow
	if float(g[3]) <= 0.0:
		return
	var c := Vector2(_w * float(g[0]), _g - float(g[1]))
	WoodcutDraw.glow(ci, c, float(g[2]), Color(inf.lit, float(g[3])), 0.75)
	WoodcutDraw.glow(ci, c, float(g[2]) * 0.45, Color(Palette.EMBER_HOT, float(g[3]) * 0.5), 0.8)
	for f in inf.fires:
		var fc := Vector2(_w * float(f.x), _g - float(f.y) - float(f.h) * 0.35)
		WoodcutDraw.glow(ci, fc, float(f.w) * 1.4, Color(Palette.EMBER, 0.45), 0.9)


func _paint_sparks(ci: CanvasItem) -> void:
	var inf := StopBackdrops.info(stop)
	WoodcutDraw.begin(ci)
	for fi in inf.fires.size():
		var f: Dictionary = inf.fires[fi]
		var base := Vector2(_w * float(f.x), _g - float(f.y) - float(f.h) * 0.6)
		var n := int(clampf(float(f.w) / 12.0, 4.0, 18.0))
		for i in n:
			var life := 1.6 + WoodcutDraw.hash01(i, fi + 40) * 1.4
			var u := fposmod(_t / life + WoodcutDraw.hash01(i, fi + 41), 1.0)
			var drift := sin(_t * 1.3 + float(i)) * 14.0 * u + (WoodcutDraw.hash01(i, fi + 42) - 0.5) * float(f.w) * 0.8
			var p := base + Vector2(drift, -u * float(f.h) * 1.6)
			var a := (1.0 - u) * 0.9
			var col := Palette.EMBER_HOT if i % 3 == 0 else Palette.EMBER
			WoodcutDraw.line(ci, p, p + Vector2(0.6, 3.5), Color(col, a), 1.6)
	WoodcutDraw.end()


func _paint_rope(ci: CanvasItem) -> void:
	if _rope_t < 0.0:
		return
	var isso: _Walker = _issos[1]
	var u := _rope_t / 1.1
	var out := sin(clampf((u - 0.15) / 0.8, 0.0, 1.0) * PI)
	if out <= 0.01:
		return
	if not isso.root.visible:
		return
	WoodcutDraw.begin(ci)
	# The hand in world space, through the figure's own transform (it may be scaled or walking left).
	var arm_xf := _world.global_transform.affine_inverse() * _arm.global_transform
	var hand := arm_xf * (Vector2(1, 26) * _hf * 0.93 / 100.0)
	var target := Vector2(clampf(hand.x + _hf * 0.75 * isso.flip * isso.sc, 30.0, _w - 30.0), isso.base_y - _hf * 0.95 * isso.sc)
	if _onlooker.visible:
		# The rope goes for the onlooker's shoulders.
		target = _onlooker.position + Vector2(0, -_hf * 0.62 * absf(_onlooker.scale.y))
	var tip := hand.lerp(target, out)
	var mid := (hand + tip) * 0.5 + Vector2(0, -60.0 * out + 30.0 * (1.0 - out))
	var pts := WoodcutDraw.quad(hand, mid, tip, 14)
	# Twisted rush rope: a pale core with darker twists, inked so it reads against the day streets.
	WoodcutDraw.stroke(ci, pts, Palette.INK, 5.6, 4.4, 6.0)
	WoodcutDraw.stroke(ci, pts, Palette.ROPE, 4.0, 3.0, 4.5)
	for i in range(1, pts.size() - 1, 2):
		var d := (pts[i + 1] - pts[i - 1]).normalized().orthogonal() * 2.0
		WoodcutDraw.line(ci, pts[i] - d, pts[i] + d + (pts[i + 1] - pts[i]) * 0.5, Palette.ROPE_DARK, 1.4)
	# The noose at the end.
	var loop := WoodcutDraw.ellipse(tip + Vector2(0, 8), Vector2(12, 9) if _onlooker.visible else Vector2(9, 12), 14, 0.4)
	loop.append(loop[0])
	WoodcutDraw.stroke(ci, loop, Palette.INK, 4.4, 4.4)
	WoodcutDraw.stroke(ci, loop, Palette.ROPE, 3.0, 3.0)
	WoodcutDraw.end()


## Motion lines: when a Mamuthone's bells ring, carved swing strokes flick out at both sides of his
## load. At low unison they come ragged, one figure after another and of different strengths; from
## unison 4 the row rings on one instant and a single shared swing line runs along all the loads,
## so the state of the row reads at a glance. Also the scuff of dust when you stumble.
func _paint_motion(ci: CanvasItem) -> void:
	WoodcutDraw.begin(ci)
	var day: bool = StopBackdrops.info(stop).sky == "day"
	var ink := Palette.INK if day else Palette.BONE
	var accent := Palette.RED_DEEP if day else Palette.EMBER
	var u := _hf / 100.0
	var tops := PackedVector2Array()
	var ring_sum := 0.0
	var ringing := 0
	for w in _walkers:
		if w.is_isso or not w.root.visible:
			continue
		var xf := w.root.transform * w.pivot.transform * w.back.transform
		if w.line == 0:
			tops.append(w.root.transform * (Vector2(0, -106) * u))
			ring_sum += w.ring
			if w.ring > 0.3:
				ringing += 1
		if w.ring <= 0.03 or reduced_motion:
			continue
		# Swing ticks at the top corners of the load, curving the way the bells swing.
		var dir := signf(w.vbell) if absf(w.vbell) > 0.05 else 1.0
		for side in [-1.0, 1.0]:
			for k in 3:
				var r := 30.0 + 5.0 * float(k)
				var arc := PackedVector2Array()
				for j in 5:
					var ang := lerpf(-0.35, 0.35, float(j) / 4.0) + dir * 0.12
					arc.append(xf * ((Vector2(0, -60) + Vector2(side * cos(ang - 0.95) * r, sin(ang - 0.95) * r)) * u))
				var a := w.ring * (0.95 - 0.25 * float(k)) * (1.0 if w.line == 0 else 0.55)
				WoodcutDraw.stroke(ci, arc, Color(ink if k != 1 else accent, a), 0.2 * u, 0.2 * u, (1.5 - 0.3 * float(k)) * u)
	# The shared swing: one line through every front load, only when the row rings together.
	if unison >= 4 and ringing >= 2 and tops.size() >= 2 and not reduced_motion:
		var sorted_tops := Array(tops)
		sorted_tops.sort_custom(func(p, q): return p.x < q.x)
		var a := clampf(ring_sum / float(tops.size()), 0.0, 1.0) * (0.55 if unison == 4 else 0.95)
		var line := PackedVector2Array()
		var first: Vector2 = sorted_tops[0]
		var last: Vector2 = sorted_tops[sorted_tops.size() - 1]
		# Arcs over the heads, one per gap, joined: the row's bells swinging as one.
		line.append(first + Vector2(-_hf * 0.2, _hf * 0.1))
		for i in sorted_tops.size():
			var p: Vector2 = sorted_tops[i]
			line.append(p)
			if i + 1 < sorted_tops.size():
				var q: Vector2 = sorted_tops[i + 1]
				line.append((p + q) * 0.5 + Vector2(0, -_hf * 0.07))
		line.append(last + Vector2(_hf * 0.2, _hf * 0.1))
		var smooth := WoodcutDraw.smooth_open(line, 6)
		for k in 3:
			var band := smooth.duplicate()
			for i in band.size():
				band[i] += Vector2(0, -7.0 * float(k))
			WoodcutDraw.stroke(ci, band, Color(accent if k == 0 else ink, a * (1.0 - 0.28 * float(k))), 0.5, 0.5, 3.6 - float(k))
	# Dust scuffed up by a stumble.
	if _stumble_t >= 0.0 and _player.root.visible:
		var t := _stumble_t / 0.6
		var feet := _player.root.position + Vector2(_player.flip * _hf * 0.06, 0)
		for i in 9:
			var ang := lerpf(-PI + 0.2, -0.2, float(i) / 8.0)
			var d := Vector2.from_angle(ang) * Vector2(1.0, 0.5)
			var r0 := _hf * (0.08 + 0.16 * t)
			var r1 := r0 + _hf * (0.07 + 0.06 * WoodcutDraw.hash01(i, 71))
			var col := Palette.INK if day else Palette.BONE_DIM
			WoodcutDraw.stroke(ci, PackedVector2Array([feet + d * r0, feet + d * r1]), Color(col, 0.9 * (1.0 - t)), 5.0, 0.8)
	WoodcutDraw.end()


func _paint_player_mark(ci: CanvasItem) -> void:
	# A carved ember arc on the ground under your Mamuthone.
	var r := Vector2(_hf * 0.2, _hf * 0.035)
	var arc := PackedVector2Array()
	for i in 13:
		var a := lerpf(0.1, PI - 0.1, float(i) / 12.0)
		arc.append(Vector2(cos(a) * r.x, sin(a) * r.y + 1.0))
	WoodcutDraw.stroke(ci, arc, Color(Palette.EMBER, 0.85), 1.0, 1.0, 3.2)


func _paint_frame(ci: CanvasItem) -> void:
	if not framed:
		return
	WoodcutDraw.begin(ci)
	var w := size.x
	var h := size.y
	# Ink edges: a rough black lip top and bottom, like the border of a printed block.
	for edge in [0.0, h]:
		var pts := PackedVector2Array()
		var n := int(w / 10.0) + 2
		for i in n:
			var x := float(i) * w / float(n - 1)
			var d := 3.0 + 4.0 * WoodcutDraw.noise1(float(i) * 0.6, int(edge) + 3)
			pts.append(Vector2(x, edge + (d if edge == 0.0 else -d)))
		var band := pts.duplicate()
		band.append(Vector2(w, edge))
		band.append(Vector2(0, edge))
		WoodcutDraw.fill(ci, band, Palette.INK)
	WoodcutDraw.end()
