class_name HealthPips
extends Control
## The player's health on the play screen's HUD: ten small flames under the score, one per point of
## Session health. A lost point gutters out (the flame shrinks to a wisp of smoke) while the row
## shakes; healing relights its flames with a warm flare; at LOW or less the flames left burn red and
## pulse. It reads session.health every frame and animates on Session.health_changed.

const LOW := 3
const PIP := 21.0            ## pitch between flames (7 art px)
const LOSE_TIME := 0.5
const LIGHT_TIME := 0.6
const SHAKE_TIME := 0.35

var session: Session
var reduced_motion := false
var _clock := 0.0
var _lost := {}              # pip index -> clock when it went out
var _lit := {}               # pip index -> clock when it relit
var _shake_at := -9.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PIP * Session.MAX_HEALTH, 39.0)


func _ready() -> void:
	if session != null:
		session.health_changed.connect(_on_health_changed)


func _on_health_changed(health: int, delta: int) -> void:
	if delta < 0:
		for i in range(health, health - delta):
			_lost[i] = _clock
			_lit.erase(i)
		_shake_at = _clock
	else:
		for i in range(health - delta, health):
			_lit[i] = _clock
			_lost.erase(i)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Whether the row is burning low (the flames left pulse red).
func low() -> bool:
	return session != null and session.health <= LOW


func _draw() -> void:
	if session == null:
		return
	var P := PxArt.PX
	var h := session.health
	var sa := _clock - _shake_at
	var shake := 0.0
	if sa < SHAKE_TIME and not reduced_motion:
		# a one-pixel shudder, stepped
		shake = P * (1.0 if int(sa * 30.0) % 2 == 0 else -1.0)
	var red := low()
	var frame := int(_clock * 8.0)
	for i in Session.MAX_HEALTH:
		var c := Vector2(PIP * i + 4.0 * P + shake, size.y - 2.0 * P)
		var lit := i < h
		if lit:
			var tone := "red" if red else "lit"
			if _lit.has(i) and _clock - float(_lit[i]) < LIGHT_TIME:
				tone = "bright"
			FireSkin.sprite(self, "pip_%s_%d" % [tone, (frame + i * 2) % 3], c)
		else:
			FireSkin.sprite(self, "pip_out", c)
			if _lost.has(i):
				var k := clampf((_clock - float(_lost[i])) / LOSE_TIME, 0.0, 1.0)
				if k < 0.35:
					FireSkin.sprite(self, "pip_red_%d" % (frame % 3), c)
				elif k < 1.0:
					# a curl of smoke rising from the ember
					for j in 3:
						var sy := c.y - (4.0 + 3.0 * j + 10.0 * k) * P
						var sx := c.x + (1.0 if (j + int(k * 6.0)) % 2 == 0 else -1.0) * P - P * 0.5
						draw_rect(Rect2(roundf(sx / P) * P, roundf(sy / P) * P, P, P), PixelPalette.BONE[0])
