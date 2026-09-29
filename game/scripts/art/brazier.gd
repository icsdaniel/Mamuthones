class_name Brazier
extends Control
## A wrought-iron brazier on its three legs with pixel flames (the bonfire's flame shader, small): it
## flickers on its own and leaps on the beat. Place it by `feet` (the foot of its legs, on the art
## grid) and `px`; `beat` is the song's beat (or the title's own clock). `flip`: the bonfire is to
## its left (the brazier's baked twin lit on that side is drawn; the sprite is never mirrored).

const COALS := 3.0                ## the coals' row from the sprite's top (scenery.py BRAZIER_COALS)

var feet := Vector2.ZERO
var px := PxArt.PX
var beat := -1000.0
var low := 0.0
var seed := 1.0
var reduced_motion := false
var flip := false

var _flames: ColorRect
var _front: Control
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_flames = ColorRect.new()
	_flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = Bonfire.flame_shader_code()
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("seed", seed * 5.3)
	_flames.material = m
	add_child(_flames)
	_front = Control.new()
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.draw.connect(_draw_bowl)
	add_child(_front)
	PxArt.nearest(_front)


## The flame's leap now (the beat's envelope, with the brazier's own flicker).
func flare() -> float:
	var e := PxArt.beat_env(beat, 0.4, 0.7, 0.12)
	return e * (0.35 if reduced_motion else 1.0) + 0.15 * sin(_clock * 13.0 + seed * 4.0) * sin(_clock * 7.1 + seed)


## Where the light of its flame is now: [centre, radius in art px, strength 0..1].
func light() -> Array:
	var f := flare()
	return [feet + Vector2(0, -14.0 * px), 16.0 + 6.0 * f, clampf(0.55 + 0.35 * f - 0.3 * low, 0.0, 1.0)]


func _process(delta: float) -> void:
	_clock += delta
	var t := PxArt.scenery(sprite())
	var tall := 25.0
	if t != null:
		tall = float(t.get_height())
	var fa := Vector2(18.0, 24.0)
	# the flames stand on the coals heaped in the basket
	var root := feet + Vector2(0.0, -(tall - COALS) * px)
	_flames.position = root + Vector2(-floorf(fa.x * 0.5) * px, -(fa.y - 2.0) * px)
	_flames.size = fa * px
	var m := _flames.material as ShaderMaterial
	m.set_shader_parameter("size_px", fa)
	m.set_shader_parameter("t", floorf(_clock * Bonfire.FPS) / Bonfire.FPS)
	m.set_shader_parameter("flare", flare())
	m.set_shader_parameter("low", low)
	m.set_shader_parameter("height", 14.0)
	m.set_shader_parameter("width", 5.0)
	_front.queue_redraw()


## The baked sprite: lit on the side facing the bonfire.
func sprite() -> String:
	return "brazier_r" if flip else "brazier"


func _draw_bowl() -> void:
	var t := PxArt.scenery(sprite())
	if t == null:
		return
	PxArt.blit(_front, t, feet + Vector2(-floorf(t.get_width() * 0.5) * px, -t.get_height() * px), px)
