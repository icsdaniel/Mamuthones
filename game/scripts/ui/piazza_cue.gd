class_name PiazzaCue
extends Control
## Piazza's one huge cue, readable while moving: a ring closes in on the target circle as the next bell
## comes, with a big arrow for up or down, the player's name above and "Ring!" on the beat.

var session: Session
var song_time := 0.0
var player := ""
var _font: Font


func _ready() -> void:
	_font = get_theme_font("font", "HeaderLabel")


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size * Vector2(0.5, 0.52)
	var r := minf(size.x, size.y) * 0.3
	draw_circle(c, r, Color(Palette.WOOD, 0.9))
	draw_arc(c, r, 0.0, TAU, 64, Palette.BONE, 6.0)
	if player != "":
		_text(player, Vector2(c.x, 70.0), 46, Palette.BONE)
	_text(UIKit.fmt_score(session.score if session else 0), Vector2(c.x, size.y - 40.0), 46, Palette.EMBER)
	if session == null:
		return
	var n := session.upcoming_bell(song_time)
	if n == null:
		return
	var dt := n.t - song_time
	var approach := 1.6
	if dt <= approach:
		var k := clampf(dt / approach, 0.0, 1.0)
		var rr := r * (1.0 + 1.6 * k)
		var col := Palette.EMBER.lerp(Palette.RED, k)
		draw_arc(c, rr, 0.0, TAU, 64, col, 10.0 + 8.0 * (1.0 - k))
	# Arrow: up or down.
	var s := r * 0.55
	var d := -1.0 if n.up else 1.0
	var tip := c + Vector2(0.0, d * s)
	var pts := PackedVector2Array([tip, c + Vector2(-s * 0.7, -d * s * 0.2), c + Vector2(-s * 0.25, -d * s * 0.2),
		c + Vector2(-s * 0.25, -d * s), c + Vector2(s * 0.25, -d * s), c + Vector2(s * 0.25, -d * s * 0.2),
		c + Vector2(s * 0.7, -d * s * 0.2)])
	draw_colored_polygon(pts, Palette.BONE if absf(dt) > 0.12 else Palette.EMBER_HOT)
	if absf(dt) < 0.15:
		_text(tr("piazza_ring"), Vector2(c.x, c.y + r + 80.0), 64, Palette.EMBER_HOT)


func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, at - Vector2(w * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	draw_string(_font, at - Vector2(w * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
