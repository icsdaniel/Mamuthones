class_name StreetBackdrop
extends Control
## The play screen's street in the Woodcut look (tools/art/claude_styles, the play screen Daniele
## approved on the review page, exported by export_game.py into art/woodcut/): the road of Mamoiada at
## night in three inks, black, cream and vermilion, its houses either side, the bonfire at the far end
## and two files of Mamuthones beside the road, bobbing on every beat.
##
## The lanes are the picture's own: LaneView asks flat_to_local() where a point of its flat field lies,
## and the answer follows the lines painted on the road (each lane between two of them) with a true
## perspective along it.
##
## The picture covers the screen, top aligned, at one scale (never stretched). So the outer lanes'
## notes still reach the hit line on screen, the lanes below the fire may be laid a little longer
## than the picture's (`stretch`); LaneView then draws their lines itself.
##
## It stands in for FireBackdrop (beat, dim, kick) and SideRows (jolt, stomp, set_still, ...), so the
## play screen drives it the same way.

const DIR := "res://art/woodcut/"
const IMG := Vector2(135.0, 300.0)
## The painted lines, x = a + b * y in the picture's pixels: the road's edges and the lane dividers
## (art/woodcut/geometry.json).
const RAILS := [Vector2(99.618132, -0.42032967), Vector2(78.206044, -0.14010989), Vector2(56.793956, 0.14010989), Vector2(35.381868, 0.42032967)]
const VANISH_Y := 76.411765          ## where the lines meet (the horizon), picture px
const FAR_Y := 100.5                 ## the road's far end, just in front of the fire, picture px
const STRETCH_FROM := 104.0          ## the lanes are only ever laid longer below this row
const FIRE := Vector2(67.5, 80.0)    ## the fire's heart, picture px
const FIRE_BASE := Vector2(67.5, 104.1)
## On the hit line, an outer lane's whole slot and its biggest note stay on screen: their edge keeps
## EDGE_PAD of the width off the screen's edge.
const CLEAR_R := 0.53
const EDGE_PAD := 0.02
const ZOOM := 1.0
## The figures' bob on each beat, timed on Daniele's reference clip (30 fps).
const BOB := 0.1
const BOB_HOLD := 0.03
const BOB_BACK := 0.1
const HUD_GAP := 6.0

var lanes: LaneView
var beat := -1000.0
var dim := 0.0
var reduced_motion := false
## Settings: animations off (UIKit.animations_off): the street stands still.
var animations := true
var still := false
var unison := 0
var hud_bottom := -INF
var bell_set := "village"
var own_cells := false               ## kept for the play screen; the woodcut is drawn as it is

## The picture on screen: scale, x offset, and how much longer the lanes are laid below STRETCH_FROM.
var pic_scale := 1.0
var pic_off := 0.0
var stretch := 1.0

var _street: Texture2D
var _figs: Array[Texture2D] = []     ## the procession's atlas pages (art/woodcut/figs_N.png)
var _fig := {}                       ## figs.json: rows, poses, sprites
var _fires: Array[Texture2D] = []
var _geo := {}
var _clock := 0.0
var _kick := 0.0
var _jolt_kind := ""
var _jolt_at := -9.0
var _layout := Vector3.ZERO
## For tests: the old portraits are gone; nothing stands over the lanes.
var _puppets: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ready() -> void:
	_street = load(DIR + "street.png")
	var f := FileAccess.open(DIR + "geometry.json", FileAccess.READ)
	if f != null:
		_geo = JSON.parse_string(f.get_as_text())
	var ff := FileAccess.open(DIR + "figs.json", FileAccess.READ)
	if ff != null:
		_fig = JSON.parse_string(ff.get_as_text())
		var pages := 0
		for v: Array in (_fig.sprites as Dictionary).values():
			pages = maxi(pages, int(v[0]) + 1)
		for i in pages:
			_figs.append(load(DIR + "figs_%d.png" % i))
	for lv in [1, 2, 3, 4]:
		_fires.append(load(DIR + "fire_%d.png" % lv))
	animations = not UIKit.animations_off()
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	_layout = Vector3.ZERO
	_solve()
	queue_redraw()


## Cover the screen with the picture (top aligned, centred across), then lay the lanes below the fire
## just long enough for the outer lanes' notes at LaneView's hit line.
func _solve() -> void:
	var hl := _hit_line_local()
	var key := Vector3(size.x, size.y, hl)
	if key == _layout or size.x < 2.0:
		return
	_layout = key
	pic_scale = maxf(size.x / IMG.x, size.y / IMG.y) * ZOOM
	pic_off = (size.x - IMG.x * pic_scale) * 0.5
	var margin := size.x * EDGE_PAD
	var x_min := (margin - pic_off) / pic_scale
	var x_max := (size.x - margin - pic_off) / pic_scale
	var lane: Vector2 = RAILS[2] - RAILS[1]
	var yl := _solve_line(RAILS[0].lerp(RAILS[1], 0.5) - lane * CLEAR_R, x_min)
	var yr := _solve_line(RAILS[2].lerp(RAILS[3], 0.5) + lane * CLEAR_R, x_max)
	var need := minf(yl, yr)
	var hl_img := hl / pic_scale
	stretch = maxf(1.0, (hl_img - STRETCH_FROM) / maxf(need - STRETCH_FROM, 1.0))


func _solve_line(a: Vector2, x: float) -> float:
	return (x - a.x) / a.y if absf(a.y) > 0.0001 else 1e6


func _hit_line_local() -> float:
	if lanes != null and lanes.is_inside_tree() and is_inside_tree():
		var fr := lanes.field_rect()
		var to_me := get_global_transform().affine_inverse() * lanes.get_global_transform()
		return (to_me * Vector2(0.0, LaneSkin.hit_line_y(fr))).y
	return size.y * 0.79


## A point of the lanes' road (picture px) on screen, in this control's coordinates.
func to_local_pic(p: Vector2) -> Vector2:
	_solve()
	var y := p.y if p.y <= STRETCH_FROM else STRETCH_FROM + (p.y - STRETCH_FROM) * stretch
	return Vector2(pic_off + p.x * pic_scale, y * pic_scale)


## A point of the picture itself on screen (never stretched).
func pic_point(p: Vector2) -> Vector2:
	_solve()
	return Vector2(pic_off + p.x * pic_scale, p.y * pic_scale)


func rail_x(i: int, y: float) -> float:
	var r: Vector2 = RAILS[i]
	return r.x + r.y * y


func _pic_y(fy: float) -> float:
	var fr := lanes.field_rect()
	var hl := LaneSkin.hit_line_y(fr)
	_solve()
	var yh := _hit_line_local() / pic_scale
	if yh > STRETCH_FROM:
		yh = STRETCH_FROM + (yh - STRETCH_FROM) / stretch
	var a := 1.0 / (FAR_Y - VANISH_Y)
	var b := 1.0 / (yh - VANISH_Y)
	var k := fy / maxf(hl, 1.0)
	var inv := a + (b - a) * k
	return VANISH_Y + 1.0 / maxf(inv, 0.00005)


## [a, b, the hit line's flat depth, the field's width, pic_off, pic_scale, stretch] for LaneView.
func flat_consts() -> PackedFloat32Array:
	var fr := lanes.field_rect()
	_solve()
	var yh := _hit_line_local() / pic_scale
	if yh > STRETCH_FROM:
		yh = STRETCH_FROM + (yh - STRETCH_FROM) / stretch
	return PackedFloat32Array([1.0 / (FAR_Y - VANISH_Y), 1.0 / (yh - VANISH_Y), maxf(LaneSkin.hit_line_y(fr), 1.0),
		maxf(fr.size.x, 1.0), pic_off, pic_scale, stretch])


func flat_to_local(p: Vector2) -> Vector2:
	var fr := lanes.field_rect()
	var y := _pic_y(p.y)
	var u := p.x / maxf(fr.size.x, 1.0) * 3.0
	var i := clampi(int(floor(u)), 0, 2)
	var f := u - float(i)
	var x := lerpf(rail_x(i, y), rail_x(i + 1, y), f)
	return to_local_pic(Vector2(x, y))


func lane_px(fy: float) -> float:
	var y := _pic_y(fy)
	return (rail_x(2, y) - rail_x(1, y)) * pic_scale


# ------------------------------------------------------------------ the SideRows / FireBackdrop calls

func set_look(_mask: Dictionary, _fleece := "black", _straps := "natural") -> void:
	pass


func set_bell_set(id: String) -> void:
	bell_set = id


func set_stop(_n: int) -> void:
	pass


func set_unison(level: int) -> void:
	unison = level


## The bonfire's size, 0..3: one step for each step of the multiplier (1x .. 4x).
func fire_level() -> int:
	return FireTiers.tier_of(Session.UNISON_MULTS[clampi(unison, 0, Session.UNISON_MULTS.size() - 1)])


func set_still(on: bool) -> void:
	still = on


func settle() -> void:
	still = false


func jolt(kind := "step") -> void:
	_jolt_kind = kind
	_jolt_at = _clock


func throw_rope() -> void:
	jolt("rope")


func stomp() -> void:
	jolt("stomp")
	kick(1.0)


func bell_strike(_up: bool) -> void:
	pass


func rope_crack() -> void:
	pass


func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)


func surge() -> void:
	kick(1.0)


func set_ghost_delta(_seconds: float) -> void:
	pass


func hide_ghost() -> void:
	pass


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on


func set_hud_bottom(y: float) -> void:
	hud_bottom = y


func flash(_at: Vector2, _strength := 1.0) -> void:
	pass


func beat_env() -> float:
	if beat <= -999.0:
		return 0.0
	return PxArt.beat_env(beat, 0.4, 0.6, 0.0) * (0.35 if reduced_motion else 1.0)


func motion_on() -> bool:
	return animations


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	_clock += delta
	_kick = maxf(0.0, _kick - delta * 2.0)
	_solve()
	queue_redraw()


## Seconds since the last beat (99: no song running, everything at rest).
func since_beat() -> float:
	if beat <= -999.0 or not animations or still:
		return 99.0
	var spb := lanes.spb if lanes != null and lanes.spb > 0.0 else 0.5
	var t := (beat - floorf(beat)) * spb
	if _jolt_kind == "stomp" and _clock - _jolt_at < 0.3:
		t = minf(t, _clock - _jolt_at)
	return t


func _draw() -> void:
	if _street == null:
		return
	_solve()
	var night := 1.0 - 0.45 * dim
	var mod := Color(night, night, night)
	var at := Vector2(pic_off, 0.0)
	var sz := IMG * pic_scale
	draw_texture_rect(_street, Rect2(at, sz), false, mod)
	var t := since_beat()
	# the bonfire: its frame follows the beat (on it the flames leap, then settle)
	var lv := fire_level()
	if lv < _fires.size() and _fires[lv] != null:
		var box: Array = _geo.get("fire_box", [0, 0, 1, 1])
		var n := int(_geo.get("fire_frames", 1))
		var fi := clampi(int(t * float(_geo.get("fire_fps", 30))), 0, n - 1)
		var fw := float(box[2])
		var fh := float(box[3])
		draw_texture_rect_region(_fires[lv], Rect2(pic_point(Vector2(box[0], box[1])), Vector2(fw, fh) * pic_scale),
			Rect2(fi * fw, 0.0, fw, fh), mod)
	# the files of Mamuthones walking toward the fire, a heavy step on every beat
	if not _figs.is_empty():
		_draw_procession(mod)


# ------------------------------------------------------------------ the procession

## Seconds into the review's 120 bpm step cycle (0.5 s: the landing on the beat, the settle, a
## crouch, then the short lift that carries the step into the next beat), at this song's tempo: a
## slower song rests between the settle and the crouch, a faster one runs the cycle quicker.
func step_time() -> float:
	if beat <= -999.0 or not animations or still:
		return 0.25
	var spb := lanes.spb if lanes != null and lanes.spb > 0.0 else 0.5
	var tsec := (beat - floorf(beat)) * spb
	if spb < 0.5:
		return tsec * 0.5 / spb
	if tsec < 0.21:
		return tsec
	return clampf(0.5 - (spb - tsec), 0.21, 0.4999)


static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The two files as the review page places them (smooth.procession_walk): rows evenly spaced in log
## depth walk a third of a row toward the fire on every beat, the step taken in the lift; a new
## Mamuthone walks in past the screen's edge at the front and the far ones shrink into the dark.
## [x, y (feet, picture px), h, side, seed index, z], far to near.
func procession(ts: float) -> Array:
	var R: Dictionary = _fig.rows
	var sc: Dictionary = _fig.scene
	var tm: Dictionary = _fig.timing
	var z0 := float(R.z0)
	var ratio := float(R.ratio)
	var b := floorf(beat) if beat > -999.0 and animations and not still else 0.0
	var u := _ss((ts - float(tm.T_OFF)) / (float(tm.T_BEAT) - float(tm.T_OFF)))
	if beat <= -999.0 or not animations or still:
		u = 0.0
	var pos := (b + u) * float(R.step)
	var vpx := float(sc.vpx)
	var vpy := float(sc.vpy)
	var hity := float(sc.hity)
	var hw0 := float(sc.hw0)
	var hw1 := float(sc.hw1)
	var out := []
	var n := int(R.n)
	var out_k := float(R.get("out", 1.05))
	var nseeds := (_fig.seeds as Array).size()
	for side: float in [-1.0, 1.0]:
		for j in n + 2:
			var r := float(j) - fposmod(pos, 1.0)
			var ident := j + int(floorf(pos))
			var z := z0 * pow(ratio, r)
			if z > float(R.zmax) or z < z0 / ratio:
				continue
			var tt := 1.0 / z
			var y := vpy + tt * (hity - vpy)
			var h := int(roundf(float(R.scale) * tt))
			var w := float(h) * 0.86
			var halfw := hw0 + (hw1 - hw0) * (y - vpy) / (hity - vpy)
			var x := vpx + side * (halfw * out_k + w * 0.36)
			var fit := vpx - w * 0.5 - 1.0
			if z >= z0:
				x = vpx + side * minf(absf(x - vpx), fit)
			else:
				var k := (log(z0) - log(z)) / log(ratio)
				var d0 := minf(absf(halfw * out_k + w * 0.36), fit)
				x = vpx + side * (d0 + (vpx + w * 0.6 - d0) * k)
			var seed := posmod(ident + (2 if side > 0.0 else 0), nseeds)
			out.append([x, y, h, side, seed, z])
	out.sort_custom(func(p: Array, q: Array) -> bool: return float(p[1]) < float(q[1]))
	return out


func _draw_procession(mod: Color) -> void:
	var ts := step_time()
	var poses: Array = _fig.poses
	var pi := 0
	for i in poses.size():
		if float(poses[i]) <= ts + 0.0001:
			pi = i
	var S := float(_fig.S)
	var seeds: Array = _fig.seeds
	var sprites: Dictionary = _fig.sprites
	var k := pic_scale / S
	for fg: Array in procession(ts):
		var key := "%d_%d_%d" % [int(seeds[int(fg[4])]), int(fg[2]), pi]
		if not sprites.has(key):
			continue
		var sp: Array = sprites[key]
		var src := Rect2(float(sp[1]), float(sp[2]), float(sp[3]), float(sp[4]))
		var foot := pic_point(Vector2(float(fg[0]), float(fg[1])))
		var right := float(fg[3]) > 0.0
		# the sprites are drawn for the right-hand file; the left one is the mirror image
		var ax := float(sp[5]) if right else float(sp[3]) - float(sp[5])
		var tl := (foot - Vector2(ax, float(sp[6])) * k).round()
		var dst := Rect2(tl, src.size * k)
		if not right:
			draw_set_transform(Vector2(tl.x * 2.0 + dst.size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(_figs[int(sp[0])], dst, src, mod)
		if not right:
			draw_set_transform(Vector2.ZERO)
		_ring_marks(fg, ts, mod)


## Short cream strokes flying off the bells for a moment after each landing (near files only).
func _ring_marks(fg: Array, ts: float, mod: Color) -> void:
	if ts > 0.14 or float(fg[5]) > 4.5 or beat <= -999.0:
		return
	var kk := 1.0 - ts / 0.14
	var h := float(fg[2])
	var by := float(fg[1]) - h * 0.42
	var w := maxf(1.0, pic_scale)
	for side: float in [-1.0, 1.0]:
		var bx := float(fg[0]) + side * h * 0.43
		for ang: float in [-0.5, 0.0, 0.5]:
			var r0 := h * (0.06 + 0.1 * (1.0 - kk))
			var ln := maxf(2.0, h * 0.07 * kk)
			var a := pic_point(Vector2(bx + side * r0 * cos(ang), by + r0 * sin(ang)))
			var e := pic_point(Vector2(bx + side * (r0 + ln) * cos(ang), by + (r0 + ln) * sin(ang)))
			draw_line(a, e, WoodcutSkin.C * mod, w)


## How far down a figure is (1 = the full drop) t seconds after the beat: down at once, held for a
## frame or two, back up by 0.1 s.
static func _bob(t: float) -> float:
	if t < 0.0:
		return 0.0
	var x := clampf((t - BOB_HOLD) / (BOB_BACK - BOB_HOLD), 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)
