class_name HealthPips
extends Control
## The player's health on the play screen's HUD: five hearts, each two points of Session health (a
## half heart for one). A lost point rises off its heart and fades while the row shakes; healing
## flares its heart warm white; at LOW or less the hearts left pulse. It reads session.health every frame and animates on Session.health_changed.

const LOW := 3
const PIP := 21.0            ## (old flames' pitch, kept for callers)
const HEART := 40.0          ## pitch between hearts
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
	custom_minimum_size = Vector2(HEART * ceil(Session.MAX_HEALTH / 2.0), 36.0)


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
	var sa := _clock - _shake_at
	var shake := 0.0
	if sa < SHAKE_TIME and not reduced_motion:
		shake = sin(sa * 70.0) * 3.0 * (1.0 - sa / SHAKE_TIME)
	var red := low()
	var pulse := 0.5 + 0.5 * sin(_clock * 8.0) if red else 0.0
	var hearts := int(ceil(Session.MAX_HEALTH / 2.0))
	for i in hearts:
		var c := Vector2(HEART * (i + 0.5) + shake, size.y * 0.5)
		var pts := int(clampi(h - i * 2, 0, 2))
		var lit_at := -9.0
		for k in [i * 2, i * 2 + 1]:
			if _lit.has(k):
				lit_at = maxf(lit_at, float(_lit[k]))
		var flare := clampf(1.0 - (_clock - lit_at) / LIGHT_TIME, 0.0, 1.0)
		var col := Color("#e8322a").lerp(Color("#ff7a5a"), pulse * 0.6).lerp(Color("#fff0c0"), flare)
		_heart(c, 15.0, Color("#0a0608"), 3.0)
		_heart(c, 15.0, Color("#2a1418"), 0.0)
		if pts == 2:
			_heart(c, 15.0, col, 0.0)
		elif pts == 1:
			_heart(c, 15.0, col, 0.0, true)
		for k in [i * 2, i * 2 + 1]:
			if _lost.has(k) and k >= h:
				var a := clampf((_clock - float(_lost[k])) / LOSE_TIME, 0.0, 1.0)
				if a < 1.0:
					_heart(c + Vector2(0, -10.0 * a), 15.0 * (1.0 + 0.4 * a), Color(1.0, 0.3, 0.2, 0.6 * (1.0 - a)), 0.0)
		# the shine
		if pts > 0:
			draw_circle(c + Vector2(-6.0, -5.0), 3.0, Color(1, 1, 1, 0.5))


## A heart of half-width r centred on c (grown by `grow`); `half` keeps only its left half.
func _heart(c: Vector2, r: float, col: Color, grow: float, half := false) -> void:
	var pts := PackedVector2Array()
	var n := 28
	for k in n:
		var t := TAU * float(k) / n
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		var p := Vector2(x, y) / 16.0 * (r + grow)
		if half and p.x > 0.0:
			p.x = 0.0
		pts.append(c + p + Vector2(0, 1.5))
	draw_colored_polygon(pts, col)
