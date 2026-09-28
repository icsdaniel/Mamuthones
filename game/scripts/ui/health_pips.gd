class_name HealthPips
extends Control
## The player's health on the play screen's HUD: ten small flames under the score, one per point of
## Session health. A lost point gutters out (the flame shrinks to a wisp of smoke) while the row
## shakes; healing relights its flames with a warm flare; at LOW or less the flames left burn red and
## pulse. It reads session.health every frame and animates on Session.health_changed.

const LOW := 3
const PIP := 20.0            ## pitch between flames
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
	custom_minimum_size = Vector2(PIP * Session.MAX_HEALTH, 26.0)


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
	var h := session.health
	var amp := 0.35 if reduced_motion else 1.0
	var sa := _clock - _shake_at
	var shake := 0.0
	if sa < SHAKE_TIME:
		shake = sin(sa * 70.0) * 3.5 * (1.0 - sa / SHAKE_TIME) * amp
	var glow := FireSkin.glow()
	var red := low()
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * 1.6)
	for i in Session.MAX_HEALTH:
		var c := Vector2(PIP * (i + 0.5) + shake, size.y - 5.0)
		var lit := i < h
		if lit:
			var flare := 0.0
			if _lit.has(i):
				var la := _clock - float(_lit[i])
				flare = clampf(1.0 - la / LIGHT_TIME, 0.0, 1.0)
			var gr := 13.0 + 10.0 * flare
			var gcol := Color(1.0, 0.25, 0.12, 0.28 + 0.25 * pulse) if red else Color(1.0, 0.55, 0.2, 0.3 + 0.5 * flare)
			draw_texture_rect(glow, Rect2(c + Vector2(-gr, -gr - 7.0), Vector2(gr, gr) * 2.0), false, gcol)
			var fh := 20.0 * (1.0 + 0.25 * flare) * (1.0 + (0.08 * pulse if red else 0.0) * amp)
			var wob := sin(_clock * 9.0 + float(i) * 1.7) * 1.3 * amp
			var tip := Color("#fff4c8").lerp(Color.WHITE, flare)
			var base := Color("#ff7a1f")
			if red:
				tip = Color("#ffb08a").lerp(Color("#ffd0b8"), pulse)
				base = Color("#e0281e")
			_flame(c, 6.5, fh, wob, tip, base, 1.0)
		else:
			# The ember left behind, and a flame guttering out if it just went.
			draw_circle(c + Vector2(0.0, -2.0), 3.0, Color("#3a1e1c"))
			draw_arc(c + Vector2(0.0, -2.0), 3.0, 0.0, TAU, 12, Color(0.55, 0.27, 0.16, 0.6), 1.0, true)
			if _lost.has(i):
				var k := clampf((_clock - float(_lost[i])) / LOSE_TIME, 0.0, 1.0)
				if k < 1.0:
					var fh := 17.0 * (1.0 - k)
					_flame(c, 5.5 * (1.0 - 0.6 * k), fh, sin(_clock * 25.0) * 2.0 * amp, Color(1.0, 0.9, 0.7, 1.0 - k), Color(0.6, 0.35, 0.3, 1.0 - k), 1.0 - k)
					# A curl of smoke rising from it.
					draw_circle(c + Vector2(sin(k * 6.0) * 3.0, -8.0 - 18.0 * k), 2.0 + 3.0 * k, Color(0.6, 0.55, 0.6, 0.35 * (1.0 - k)))


## A small flame: a round base of radius r at c, rising h to a tip swayed by wob.
func _flame(c: Vector2, r: float, h: float, wob: float, tip: Color, base: Color, a: float) -> void:
	if h < 1.0:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 14
	for k in n + 1:
		var ang := lerpf(-0.2 * PI, 1.2 * PI, float(k) / float(n))
		var p := c + Vector2(cos(ang) * r, -r + sin(ang) * r)
		pts.append(p)
		cols.append(Color(base, a))
	# up the left side to the tip and down the right
	pts.append(c + Vector2(-r * 0.55 + wob * 0.4, -r - h * 0.45))
	cols.append(Color(base.lerp(tip, 0.5), a))
	pts.append(c + Vector2(wob, -h))
	cols.append(Color(tip, a))
	pts.append(c + Vector2(r * 0.55 + wob * 0.4, -r - h * 0.45))
	cols.append(Color(base.lerp(tip, 0.5), a))
	draw_polygon(pts, cols)
	# a bright core
	draw_circle(c + Vector2(wob * 0.2, -r * 1.1), r * 0.45, Color(tip, 0.85 * a))
