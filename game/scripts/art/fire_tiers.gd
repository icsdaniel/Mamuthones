class_name FireTiers
extends Node2D
## The bonfire at the end of the play screen's road, from Daniele's ChatGPT fire (tools/art/chatgpt/
## outputs.py -> art/ai/fire/): four tiers of flame, one per step of the multiplier (1x, 2x, 3x, 4x;
## the half steps keep the tier below), each a loop of four frames over the stationary logs. When the
## multiplier climbs, the fire rises through its drawn transition (four frames of 80 ms) into the
## next loop; when it drops (a miss) it falls back to the lower loop at once.
##
## The loop runs on the beat: its four frames (200, 90, 80, 130 ms at 120 BPM in the drawing) are laid
## over one beat at any tempo, the first on the beat, so the flame swells as the beat lands.
## Every frame is loaded before the song (they are textures, drawn one texel per art px), so nothing
## is made mid-song. The origin is the logs' baseline, middle.

const DIR := "res://art/ai/fire/"
const CANVAS := Vector2(80.0, 104.0)        ## art px, every frame (outputs.py: seat)
const LOOP_SPLIT := [0.4, 0.58, 0.74, 1.0]   ## where each loop frame ends, share of the beat
const UP_FRAME := 0.08                       ## seconds a transition frame shows

var tier := 0
var beat := -1000.0
var dim := 0.0
var animations := true
var _loops: Array = []        ## [tier][4] Texture2D
var _ups: Array = []          ## [from tier][4] Texture2D (to tier + 1)
var _logs: Texture2D
var _flame: Sprite2D
var _base: Sprite2D
var _rising := -1             ## the tier being risen from, or -1
var _rise_t := 0.0
var _clock := 0.0


static func available() -> bool:
	return ResourceLoader.exists(DIR + "loop_1x_0.png")


func _ready() -> void:
	for n in 4:
		var fr: Array[Texture2D] = []
		for i in 4:
			fr.append(load(DIR + "loop_%dx_%d.png" % [n + 1, i]))
		_loops.append(fr)
	for n in 3:
		var fr: Array[Texture2D] = []
		for i in 4:
			fr.append(load(DIR + "up_%d_%d.png" % [n + 1, i]))
		_ups.append(fr)
	_logs = load(DIR + "logs.png")
	_base = _sprite(_logs, "Logs")
	_flame = _sprite(_loops[0][0], "Flame")
	# the logs are drawn over the flame's root, as in the drawing's previews
	move_child(_base, -1)


func _sprite(t: Texture2D, n: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.texture = t
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = Vector2(-CANVAS.x * 0.5, -CANVAS.y)
	add_child(s)
	return s


## The multiplier's tier (0: 1x .. 3: 4x) from Session.UNISON_MULTS.
static func tier_of(mult: float) -> int:
	return clampi(int(floorf(mult + 0.001)) - 1, 0, 3)


func set_tier(t: int) -> void:
	t = clampi(t, 0, 3)
	if t == tier:
		return
	if t == tier + 1 and animations:
		_rising = tier
		_rise_t = 0.0
	else:
		_rising = -1
	tier = t


## The frame on screen now, for tests: [tier, rising from (-1), frame].
func shown() -> Array:
	return [tier, _rising, _flame.texture.resource_path if _flame != null and _flame.texture != null else ""]


func _process(delta: float) -> void:
	_clock += delta
	if _flame == null:
		return
	var night := 1.0 - 0.4 * dim
	modulate = Color(night, night, night)
	if not animations:
		_flame.texture = _loops[tier][0]
		return
	if _rising >= 0:
		_rise_t += delta
		var i := int(_rise_t / UP_FRAME)
		if i < 4:
			_flame.texture = _ups[_rising][i]
			return
		_rising = -1
	var ph := fposmod(beat, 1.0) if beat > -999.0 else fposmod(_clock * 2.0, 1.0)
	var k := 0
	while k < 3 and ph >= LOOP_SPLIT[k]:
		k += 1
	_flame.texture = _loops[tier][k]
