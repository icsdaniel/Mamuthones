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
var _files: Array[Texture2D] = []
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
	for i in int(_geo.get("file_frames", 0)):
		_files.append(load(DIR + "files_%02d.png" % i))
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
	# the files of Mamuthones: one picture per moment of the bob
	if not _files.is_empty():
		var nf := _files.size()
		var k := nf - 1
		if t < float(nf - 1) / float(_geo.get("file_fps", 60)):
			k = clampi(int(t * float(_geo.get("file_fps", 60))), 0, nf - 2)
		draw_texture_rect(_files[k], Rect2(at, sz), false, mod)


## How far down a figure is (1 = the full drop) t seconds after the beat: down at once, held for a
## frame or two, back up by 0.1 s.
static func _bob(t: float) -> float:
	if t < 0.0:
		return 0.0
	var x := clampf((t - BOB_HOLD) / (BOB_BACK - BOB_HOLD), 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)
