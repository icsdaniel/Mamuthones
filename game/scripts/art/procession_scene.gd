class_name ProcessionScene
extends Control
## The procession in pixel art: your Mamuthone in a row of Mamuthones that jump together on the beat,
## the Issohadores with the rope, the crowd and the fire of the current story stop behind them. The
## world is a stop of StopBackdrops (res://art/px/stops/), drawn at a whole-number scale so the pixels
## stay square; the figures are the shared FigureSprites (and the dim/half variants baked from them).
## Used by the Piazza (setup, turns, ranking, the play screen's Piazza mode), the workshop row and the
## title. It lays itself out for any rect: extra height becomes sky, a thin band shows the row.
##
## API (docs/architecture.md "Art API"):
##   set_stop(n)                    1..7, the world of that story stop
##   set_look(mask, fleece, straps) the player's MaskSpec dict, fleece id, strap id
##   jolt(kind)                     "step" | "bell" | "ring" | "miss"
##   set_unison(level)              0..5: the row closes up and jumps more together
##   set_ghost_delta(seconds)       shows your ghost beside you; > 0 means the ghost is ahead of you
##   hide_ghost()
##   set_still(bool)                stand-still: the row freezes, bells hang
##   settle()                       the stand-still was held: bells go quiet, a slight bow, dust settles
##   throw_rope()                   the front Issohadore throws the rope into the crowd
##   set_reduced_motion(bool)       calms flicker, smoke, sparks and cuts every jump to a third
##   beat                           set it every frame (the song's beat) and the row jumps on it,
##                                  landing on each whole beat; auto_bpm > 0 keeps its own beat (menus)
## Extras: framed (a gold rule frame), show_player_mark (the ember mark under your Mamuthone).
##
## Cost: the world is a handful of textures; per frame the scene moves a dozen sprites and redraws the
## flames, a few dozen spark pixels and the smoke.

const FRONT := 3
const BACK := 3
## Art pixels of a Mamuthone's jump on the beat (front line; the far line jumps half as high).
const JUMP := 5.0

## The current stop (1..7); change it with set_stop().
var stop := 1
## Beats per minute for an automatic walk (menus, trailers). 0 = only the game's beat and jolts.
@export var auto_bpm := 0.0
## Kept for callers of the old woodcut scene: the pixel world is always drawn from textures.
@export var bake := true
## A gold rule round the picture, like the UI kit's frames.
@export var framed := true:
	set(v):
		framed = v
		if _frame:
			_frame.queue_redraw()
## The small ember mark under your own Mamuthone's feet.
@export var show_player_mark := true

var mask: Dictionary = MaskSpec.default()
var fleece := "black"
var straps := "natural"
var unison := 0
var still := false
var reduced_motion := false
var ghost_delta := 0.0
var ghost_visible := false
## The song's beat, set by the game each frame (negative: none; then auto_bpm or jolts only).
var beat := -1.0
## Microseconds spent in the last _process (for the timing test).
var last_process_usec := 0
## How many times the layout was rebuilt for a new size or stop (not on every resize step).
var bake_count := 0

## Size in screen pixels; the art scale; the world's top-left in art pixels of the view.
var _w := 720.0
var _h := 480.0
var _px := 3
var _origin := Vector2.ZERO
var _view := Vector2(240, 160)
var _t := 0.0
var _beat_t := 0.0
var _beat_n := 0
var _bell_up := true
var _rope_t := -1.0
var _miss_flash := 0.0
var _built := false
var _flare := 0.0

var _world: Node2D
var _back: _Paint
var _glow: _Paint
var _fires: Array[_Paint] = []
var _fires_root: Node2D
var _sparks: _Paint
var _front: _Paint
var _ghost: _Paint
var _rope: _Paint
var _frame: _Paint
var _motion: _Paint
var _onlooker: _Paint
var _walkers: Array[_Walker] = []
var _player: _Walker
var _issos: Array[_Walker] = []
var _stumble_t := -1.0
var _settle_t := -1.0
const SETTLE_TIME := 1.1
var _row := {}


## A Node2D whose drawing is a Callable.
class _Paint:
	extends Node2D
	var painter: Callable

	func _init(p: Callable = Callable()) -> void:
		painter = p
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


## One figure in the row and its jump physics (art pixels).
class _Walker:
	var root := Node2D.new()
	var body: _Paint
	var is_player := false
	var is_isso := false
	var line := 0              # 0 front, 1 back
	var slot := 0
	var scatter := 0.0         # how out of step this one is at low unison, 0..1
	var x := 0.0
	var target_x := 0.0
	var y := 0.0               # spring offset (jolts), negative = up
	var vy := 0.0
	var rot := 0.0
	var vrot := 0.0
	var lift := 0.0            # the beat jump, art px up
	var pose := "stand"
	var land_t := 9.0          # seconds since the last landing
	var pending: Array = []    # [[delay, amp, bell_dir], ...]
	var base_y := 0.0
	var sc := 1.0              # 1 near, 0.5 far (the half-size variants)
	var flip := 1.0            # -1 when the row walks left
	var ring := 0.0            # 0..1, how hard its bells rang just now
	var variant := ""
	var shown := true


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
	fleece = p_fleece if p_fleece in MaskSpec.FLEECES else "black"
	straps = p_straps if p_straps in MaskSpec.STRAPS else "natural"
	if _built:
		_player.body.queue_redraw()
		_ghost.queue_redraw()


func jolt(kind := "step") -> void:
	if not _built:
		return
	var amp: float = {"step": 2.2, "bell": 4.0, "ring": 5.5, "miss": 0.0}.get(kind, 2.2)
	amp *= 1.0 + 0.1 * float(unison)
	if reduced_motion:
		amp *= 0.35
	var bell_dir := 0.0
	if kind == "bell" or kind == "ring":
		bell_dir = 1.0 if _bell_up else -1.0
		_bell_up = not _bell_up
		_flare = 1.0
	if kind == "miss":
		# Your Mamuthone stumbles: pitches forward and down, drops back a step, a scuff of dust; then
		# he finds the row again.
		var k := 0.35 if reduced_motion else 1.0
		_player.vrot += 9.0 * k
		_player.vy += 80.0 * k
		_player.x -= _spacing() * 0.16 * k * _player.flip
		_miss_flash = 1.0
		_stumble_t = 0.0
		return
	var together := float(unison) / 5.0
	for w in _walkers:
		if w.is_isso:
			if kind != "step":
				w.pending.append([0.05, amp * 0.4, 0.0])
			continue
		# At low unison each Mamuthone rings late by his own amount and with his own strength (ragged);
		# at full unison they all ring on the same instant, equally.
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


## The player kept still through a stand-still: the row holds together, the bells go quiet, then a
## small release: a slight bow down the row and the dust settling at their feet. Reduced motion keeps
## only a much smaller bow.
func settle() -> void:
	if not _built:
		return
	_settle_t = 0.0
	for w in _walkers:
		w.ring = 0.0
		w.pending.clear()


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
	_world = Node2D.new()
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_world)
	_back = _Paint.new(_paint_back)
	_world.add_child(_back)
	_fires_root = Node2D.new()
	_fires_root.name = "Fires"
	_world.add_child(_fires_root)
	_front = _Paint.new(func(ci): StopBackdrops.draw_layer(ci, stop, "mid", Vector2.ZERO))
	_world.add_child(_front)
	_sparks = _Paint.new(_paint_sparks)
	_world.add_child(_sparks)
	_glow = _Paint.new(func(ci): StopBackdrops.draw_glows(ci, stop, Vector2.ZERO, 0.7 + 0.5 * _flare))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_world.add_child(_glow)
	# The row: back line first (drawn behind), then the ghost, then the front line.
	var order := []
	for i in BACK:
		order.append(_make_walker(1, i, false))
	var isso_back := _make_walker(1, BACK, true)
	order.append(isso_back)
	for w in order:
		_world.add_child(w.root)
	_ghost = _Paint.new(_paint_ghost)
	_ghost.visible = ghost_visible
	_world.add_child(_ghost)
	var front := []
	for i in FRONT:
		front.append(_make_walker(0, i, false))
	var isso_front := _make_walker(0, FRONT, true)
	front.append(isso_front)
	_onlooker = _Paint.new(_paint_onlooker)
	_world.add_child(_onlooker)
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
	_motion = _Paint.new(_paint_motion)
	_world.add_child(_motion)
	_rope = _Paint.new(_paint_rope)
	_world.add_child(_rope)
	var fr := _Paint.new(func(ci): StopBackdrops.draw_layer(ci, stop, "front", Vector2.ZERO))
	fr.name = "FrontLayer"
	_world.add_child(fr)
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
	w.body = _Paint.new(func(ci): _paint_walker(ci, w))
	w.root.add_child(w.body)
	w.root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return w


func _npc_fleece(w: _Walker) -> String:
	return "dark_brown" if (w.slot + w.line) % 3 == 2 else "black"


## The sprite a walker shows now.
func _sprite_of(w: _Walker) -> String:
	if w.is_isso:
		return FigureSprites.issohadore("throw" if (w.line == 0 and _rope_t >= 0.0) else "stand")
	return FigureSprites.mamuthone(fleece if w.is_player else _npc_fleece(w), w.pose)


func _rebuild_stop() -> void:
	var d := StopBackdrops.data(stop)
	for f in _fires:
		f.queue_free()
	_fires.clear()
	for i in d.fires.size():
		var idx: int = i
		var fr := _Paint.new(func(ci): _paint_fire(ci, idx))
		_fires_root.add_child(fr)
		_fires.append(fr)
	_apply_motion()
	_layout()


## Resizes arrive in bursts (window drags, container animations): move things at once, but rebuild
## the layout's caches only once the size has settled for REBAKE_DELAY seconds.
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
	_w = sz.x
	_h = sz.y
	var ws := StopBackdrops.world_size()
	_row = StopBackdrops.row(stop)
	# The art scale: 3 on a 720-wide phone, bigger on bigger screens, smaller for a very thin band,
	# never so small that the world would not cover the width.
	var p := clampi(int(round(sz.x / 240.0)), 1, 8)
	if sz.y / float(p) < 84.0:
		p = maxi(1, int(floor(sz.y / 84.0)))
	p = maxi(p, int(ceil(sz.x / ws.x)))
	_px = p
	_view = sz / float(p)
	# Horizontally: centre on the row where the view is narrower than the world.
	var cx := ws.x * float(_row.x)
	var ox := floorf(_view.x * 0.5 - cx)
	ox = clampf(ox, floorf(_view.x - ws.x), 0.0) if _view.x < ws.x else floorf((_view.x - ws.x) * 0.5)
	# Vertically: the ground at the bottom; a short view keeps the row and loses the top of the sky.
	var bottom := minf(ws.y, float(_row.ground) + 10.0) if _view.y < ws.y else ws.y
	var oy := floorf(_view.y - bottom) if _view.y < ws.y else floorf(_view.y - ws.y)
	_origin = Vector2(ox, oy)
	_world.scale = Vector2(p, p)
	_world.position = _origin * float(p)
	_place_row(true)
	var ol: Array = _row.get("onlooker", [])
	_onlooker.visible = not ol.is_empty()
	if _onlooker.visible:
		_onlooker.position = Vector2(roundf(ws.x * float(ol[0])), float(ol[1]))
	var fl := -1.0 if bool(_row.get("flip", false)) else 1.0
	for w in _walkers:
		w.flip = fl
		w.shown = _walker_shown(w)
		w.root.visible = w.shown
		var far: bool = w.line == 1 and bool(_row.get("far", false))
		w.sc = 0.5 if far else 1.0
		if w.line == 1:
			w.variant = "halfdim" if far else "dim"
		else:
			w.variant = str(_row.get("var", ""))
	if rebake:
		_rebake_due = -1.0
		_rebake(true)
	else:
		_redraw_all()


func _rebake(_all: bool) -> void:
	if not _built:
		return
	bake_count += 1
	_redraw_all()


func _redraw_all() -> void:
	for n in [_back, _front, _glow, _sparks, _ghost, _rope, _motion, _frame, _onlooker]:
		n.queue_redraw()
	for f in _fires:
		f.queue_redraw()
	for w in _walkers:
		w.body.queue_redraw()
	for c in _world.get_children():
		if c.name == "FrontLayer":
			(c as CanvasItem).queue_redraw()


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


## Row spacing (art px) for the current unison and staging.
func _spacing() -> float:
	var tight := float(unison) / 5.0
	return lerpf(40.0, 29.0, tight) * float(_row.get("spread", 1.0))


## Row positions for the current unison: the row closes up as unison rises.
func _place_row(snap: bool) -> void:
	if not _built:
		return
	if _row.is_empty():
		_row = StopBackdrops.row(stop)
	var ws := StopBackdrops.world_size()
	var tight := float(unison) / 5.0
	var spacing := _spacing()
	var row_w := spacing * float(FRONT - 1)
	var cx := ws.x * float(_row.x)
	var x0 := cx - row_w * 0.5
	var fl := -1.0 if bool(_row.get("flip", false)) else 1.0
	var ground: float = float(_row.ground)
	var far := bool(_row.get("far", false))
	for w in _walkers:
		var x: float
		if w.is_isso:
			x = x0 + row_w + spacing * (1.2 if w.line == 0 else 0.8)
		elif w.line == 0:
			x = x0 + spacing * float(w.slot)
		else:
			x = x0 + spacing * (float(w.slot) + 0.5)
		if w.line == 1 and far:
			# The far line walks up the street, smaller and closer together.
			x = cx + (x - cx) * 0.5
		# Out-of-step Mamuthones straggle a little at low unison.
		if not w.is_player and not w.is_isso:
			x += (w.scatter - 0.5) * spacing * 0.3 * (1.0 - tight)
		x = cx + (x - cx) * fl
		w.base_y = ground if w.line == 0 else ground - float(_row.depth)
		if w.is_isso and w.line == 0 and _row.has("isso_at"):
			x = ws.x * float(_row.isso_at[0])
			w.base_y = float(_row.isso_at[1])
		w.target_x = x
		if snap:
			w.x = x


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
	# The beat: the game's, or our own for menus.
	var b := beat
	if b < 0.0 and auto_bpm > 0.0:
		if not still:
			_beat_t += delta * auto_bpm / 60.0
			if floor(_beat_t) > float(_beat_n):
				_beat_n = int(floor(_beat_t))
				if _beat_n % 4 == 0:
					_flare = 1.0
					for w in _walkers:
						w.ring = maxf(w.ring, 0.6)
				if _beat_n % 16 == 8:
					throw_rope()
		b = _beat_t
	var together := float(unison) / 5.0
	var height := JUMP * (0.35 if reduced_motion else 1.0)
	for w in _walkers:
		# Queued jolts.
		var i := 0
		while i < w.pending.size():
			var p: Array = w.pending[i]
			p[0] -= delta
			if p[0] <= 0.0:
				w.vy -= float(p[1]) * 8.0
				if absf(float(p[2])) > 0.0:
					w.ring = maxf(w.ring, clampf(float(p[1]) / 4.0, 0.3, 1.0))
				w.pending.remove_at(i)
			else:
				i += 1
		var was_up := w.y < -1.0
		w.vy += (-320.0 * w.y - 20.0 * w.vy) * delta
		w.y += w.vy * delta
		w.vrot += (-120.0 * w.rot - 12.0 * w.vrot) * delta
		w.rot += w.vrot * delta
		w.x = lerpf(w.x, w.target_x, minf(1.0, delta * 3.0))
		w.land_t += delta
		if was_up and w.y >= -0.5:
			w.land_t = 0.0
		# The beat jump (Mamuthones only; the Issohadores walk).
		w.lift = 0.0
		var pose := "stand"
		if b >= 0.0 and not still and not w.is_isso:
			var lag := 0.0 if w.is_player else w.scatter * (1.0 - together) * 0.18
			var j := StopPicture.jump(b - lag, height * w.sc)
			pose = j.pose
			w.lift = j.lift
			if j.pose == "land" and w.land_t > 0.2:
				w.land_t = 0.0
		elif not w.is_isso:
			if w.y < -1.5:
				pose = "air"
			elif w.land_t < 0.12:
				pose = "land"
			elif not w.pending.is_empty():
				pose = "crouch"
		if w.y < -1.5 and not w.is_isso:
			pose = "air"
		if w.pose != pose:
			w.pose = pose
			w.body.queue_redraw()
		var bow := _bow(w)
		w.root.position = Vector2(roundf(w.x), roundf(w.base_y + w.y - w.lift + bow * 1.5))
		w.root.rotation = (w.rot * 0.35 + bow * 0.06) * w.flip
		w.ring = maxf(0.0, w.ring - delta * 2.6)
	# A miss: your Mamuthone blinks dark for a moment while he stumbles.
	if _miss_flash > 0.0:
		_miss_flash = maxf(0.0, _miss_flash - delta * 2.5)
		_player.body.queue_redraw()
	# Ghost drifts to where it would be.
	if ghost_visible:
		var spacing := _spacing()
		var fl := _player.flip
		var gx := _player.x + (-spacing * 0.5 + clampf(ghost_delta * 30.0, -spacing * 0.6, spacing * 0.9)) * fl
		_ghost.position = Vector2(roundf(lerpf(_ghost.position.x, gx, minf(1.0, delta * 4.0))), _player.base_y - 2.0)
		_ghost.queue_redraw()
	# Fire: flicker every frame, flare on the downbeat and on rung bells.
	_flare = maxf(0.0, _flare - delta * 3.0)
	if b >= 0.0 and fposmod(b, 4.0) < 0.12 and not still:
		_flare = maxf(_flare, 0.8)
	for f in _fires:
		f.queue_redraw()
	_glow.queue_redraw()
	if _settle_t >= 0.0:
		_settle_t += delta
		if _settle_t > SETTLE_TIME:
			_settle_t = -1.0
	if not reduced_motion:
		_sparks.queue_redraw()
		_back.queue_redraw()
	# Rope throw: the Issohadore's arm goes up, the rope flies out into the crowd and back.
	if _rope_t >= 0.0:
		_rope_t += delta
		if _rope_t >= 1.1:
			_rope_t = -1.0
		_issos[1].body.queue_redraw()
		_rope.queue_redraw()
	if _stumble_t >= 0.0:
		_stumble_t += delta
		if _stumble_t > 0.6:
			_stumble_t = -1.0
	_motion.queue_redraw()
	last_process_usec = Time.get_ticks_usec() - t0


func _apply_motion() -> void:
	if not _built:
		return
	_sparks.visible = not reduced_motion


# ------------------------------------------------------------------ drawing (art pixels, world space)

func _paint_back(ci: CanvasItem) -> void:
	# Extra height above the world becomes more of its sky (or ceiling).
	var d := StopBackdrops.data(stop)
	if _origin.y > 0.0:
		ci.draw_rect(Rect2(Vector2(-_origin.x, -_origin.y), Vector2(_view.x, _origin.y + 1.0)), d.top)
		if d.sky != "interior" and d.sky != "day":
			for i in int(_view.x * _origin.y / 90.0):
				var p := Vector2(floorf(WoodcutDraw.hash01(i, 5) * _view.x) - _origin.x, -floorf(WoodcutDraw.hash01(i, 6) * _origin.y) - 1.0)
				ci.draw_rect(Rect2(p, Vector2.ONE), PixelPalette.STAR[0] if i % 5 else PixelPalette.STAR[1])
	StopBackdrops.draw_layer(ci, stop, "bg", Vector2.ZERO)
	if not reduced_motion:
		StopBackdrops.draw_smoke(ci, stop, Vector2.ZERO, _t)


func _paint_fire(ci: CanvasItem, i: int) -> void:
	var d := StopBackdrops.data(stop)
	if i >= d.fires.size():
		return
	var f: Array = d.fires[i]
	var kind: String = f[2]
	var sz: Vector2i = StopCells.FIRES[kind][0]
	var n: int = StopCells.FIRES[kind][1]
	var speed := 0.35 if reduced_motion else 1.0
	var frame := int(floor(_t * StopBackdrops.FIRE_FPS * speed + float(i) * 2.7)) % n
	var name := "fire_%s_%d" % [kind, frame]
	if _flare > 0.5 and kind != "tiny" and not (_settle_t >= 0.0):
		name = "fire_%s_flare%d" % [kind, int(floor(_t * StopBackdrops.FIRE_FPS)) % 2]
	var tx := StopBackdrops.tex(name)
	if tx != null:
		ci.draw_texture(tx, Vector2(int(f[0]) - sz.x / 2, int(f[1]) - sz.y + 1))


func _paint_sparks(ci: CanvasItem) -> void:
	StopBackdrops.draw_sparks(ci, stop, Vector2.ZERO, _t, _flare)


func _paint_walker(ci: CanvasItem, w: _Walker) -> void:
	if w.is_player and show_player_mark:
		# A short ember arc on the ground under your Mamuthone.
		for k in 13:
			var x := k - 6
			var y := 1 if absi(x) < 5 else 0
			ci.draw_rect(Rect2(Vector2(x, y), Vector2.ONE), PixelPalette.FIRE[4] if absi(x) < 4 else PixelPalette.FIRE[2])
	var sprite := _sprite_of(w)
	var variant := w.variant
	if w.is_player and _miss_flash > 0.0 and int(_miss_flash * 12.0) % 2 == 1:
		variant = "dim"
	if w.sc < 1.0 and not variant.begins_with("half"):
		variant = "half"
	StopBackdrops.draw_figure(ci, sprite, variant, Vector2.ZERO, w.flip < 0.0)


func _paint_ghost(ci: CanvasItem) -> void:
	if not ghost_visible:
		return
	StopBackdrops.draw_figure(ci, FigureSprites.mamuthone(fleece, _player.pose), "ghost", Vector2.ZERO, _player.flip < 0.0)


func _paint_onlooker(ci: CanvasItem) -> void:
	var t := StopBackdrops.tex("figs/onlooker")
	if t == null:
		return
	var cell: Vector2i = StopCells.FIGS["onlooker"][0]
	var a: Vector2i = StopCells.FIGS["onlooker"][1]
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	ci.draw_texture(t, -Vector2(a))
	ci.draw_set_transform(Vector2.ZERO)


## The hand of the front Issohadore in world pixels (the throw pose raises it above the head).
func _hand() -> Vector2:
	var isso: _Walker = _issos[1]
	return isso.root.position + Vector2(11.0 * isso.flip, -70.0)


func _paint_rope(ci: CanvasItem) -> void:
	if _rope_t < 0.0:
		return
	var isso: _Walker = _issos[1]
	if not isso.root.visible:
		return
	var u := _rope_t / 1.1
	var out := sin(clampf((u - 0.1) / 0.8, 0.0, 1.0) * PI)
	if out <= 0.02:
		return
	var hand := _hand()
	var target := Vector2(hand.x + 60.0 * isso.flip, isso.base_y - 62.0)
	if _onlooker.visible:
		target = _onlooker.position + Vector2(0, -24)
	var tip := hand.lerp(target, out)
	var mid := (hand + tip) * 0.5 + Vector2(0, -22.0 * out + 8.0 * (1.0 - out))
	var pts: Array[Vector2] = []
	for k in 17:
		var s := float(k) / 16.0
		pts.append(hand.lerp(mid, s).lerp(mid.lerp(tip, s), s))
	# a noose loop at the tip
	for k in 13:
		var a := float(k) / 12.0 * TAU
		pts.append(tip + Vector2(cos(a) * 6.0, 4.0 + sin(a) * 4.0))
	_pixel_line(ci, pts, [PixelPalette.K[0], PixelPalette.ROPE[1], PixelPalette.ROPE[2]])


## A 1-px line through points, pixel by pixel, in layers (each colour one pixel higher: an outline
## below, the hemp, its lit top).
static func _pixel_line(ci: CanvasItem, pts: Array, cols: Array) -> void:
	for k in cols.size():
		var last := Vector2(INF, INF)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
			for s in n + 1:
				var p := a.lerp(b, float(s) / maxf(1.0, float(n))).floor() + Vector2(0, -k)
				if p != last:
					ci.draw_rect(Rect2(p, Vector2(2 if k == 0 else 1, 1)), cols[k])
					last = p


## Dust at the feet when the row lands, the settle's dust, the stumble's scuff and a glint on rung
## bells: small dithered pixel puffs, never lines or cartoon marks.
func _paint_motion(ci: CanvasItem) -> void:
	if reduced_motion:
		return
	var day: bool = StopBackdrops.data(stop).sky == "day"
	var dust := PixelPalette.STONE[4] if day else PixelPalette.SETT[4]
	var dust2 := PixelPalette.STONE[5] if day else PixelPalette.STONE[3]
	for w in _walkers:
		if not w.root.visible or w.is_isso:
			continue
		var feet := w.root.position
		var k := w.sc
		if w.land_t < 0.35:
			var u := w.land_t / 0.35
			for side in [-1.0, 1.0]:
				for j in 3:
					var p := feet + Vector2(side * (9.0 + 6.0 * u + 3.0 * float(j)) * k, -1.0 - float(j) - 3.0 * u)
					if (j + int(u * 4.0)) % 2 == 0:
						ci.draw_rect(Rect2(p.floor(), Vector2.ONE), dust if j else dust2)
		if w.ring > 0.4 and w.sc >= 1.0:
			# a glint on the bells on the back
			var g := feet + Vector2(-16.0 * w.flip, -36.0 - 6.0 * w.ring)
			ci.draw_rect(Rect2(g.floor(), Vector2.ONE), PixelPalette.GOLD[5])
			ci.draw_rect(Rect2((g + Vector2(0, -1)).floor(), Vector2.ONE), PixelPalette.STAR[1])
	if _settle_t >= 0.0:
		var t := _settle_t / SETTLE_TIME
		for w in _walkers:
			if not w.root.visible:
				continue
			for j in 6:
				var side := -1.0 if j % 2 == 0 else 1.0
				var p := w.root.position + Vector2(side * (8.0 + 2.0 * float(j) + 4.0 * t) * w.sc, -3.0 * (1.0 - t) - float(j / 2))
				if (j + int(t * 6.0)) % 3 != 0:
					ci.draw_rect(Rect2(p.floor(), Vector2.ONE), dust)
	if _stumble_t >= 0.0 and _player.root.visible:
		var t := _stumble_t / 0.6
		var feet := _player.root.position + Vector2(_player.flip * 4.0, 0)
		for i in 9:
			var ang := lerpf(-PI + 0.2, -0.2, float(i) / 8.0)
			var r := 6.0 + 10.0 * t + 2.0 * WoodcutDraw.hash01(i, 71)
			var p := feet + Vector2(cos(ang) * r, sin(ang) * r * 0.5)
			if (i + int(t * 5.0)) % 2 == 0:
				ci.draw_rect(Rect2(p.floor(), Vector2.ONE), dust2)


## How far a figure is bowed in the settle (0..1): the row bows one after another, left to right.
func _bow(w: _Walker) -> float:
	if _settle_t < 0.0:
		return 0.0
	var order := float(w.slot) * 0.06 + (0.03 if w.line == 1 else 0.0)
	var t := clampf((_settle_t - 0.15 - order) / 0.75, 0.0, 1.0)
	return sin(t * PI) * (0.3 if reduced_motion else 1.0)


## The frame: a K0 line and an old-gold rule inside it, one art pixel each, like the UI kit's panels.
func _paint_frame(ci: CanvasItem) -> void:
	if not framed:
		return
	var p := float(_px)
	var r := Rect2(Vector2.ZERO, size)
	ci.draw_rect(r, PixelPalette.K[0], false, p * 2.0)
	var inner := r.grow(-p * 1.5)
	ci.draw_rect(inner, PixelPalette.GOLD[3], false, p)
	for c in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		ci.draw_rect(Rect2(c - Vector2(p, p), Vector2(p, p) * 2.0), PixelPalette.GOLD[4])
