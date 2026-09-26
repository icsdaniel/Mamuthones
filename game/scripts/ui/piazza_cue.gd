class_name PiazzaCue
extends Control
## Piazza's one huge cue, readable while moving: a ring closes in on the target circle as the next bell
## comes, with a big arrow for up or down, the player's name above and "Ring!" on the beat. Every
## judged ring flashes the circle in its quality's colour with a big word, the same frame; during a
## stand-still the circle turns grey and says so.

const FLASH_TIME := 0.45
const FLASH_COLORS := {
	"perfect": Color("#f3cf85"), "good": Color("#ede6da"), "early": UIKit.EARLY, "late": UIKit.LATE,
	"held": Color("#f3cf85"), "miss": Color("#7d756c"),
}

var session: Session
var song_time := 0.0
var player := ""
var still := false:
	set(v):
		still = v
		queue_redraw()
var _font: Font
var _flash_q := ""
var _flash_word := ""
var _flash_at := -9.0
var _clock := 0.0


func _ready() -> void:
	_font = get_theme_font("font", "HeaderLabel")


## A ring (or a kept stand-still) was judged: flash the circle by quality and name it big.
func hit(quality: String, word: String) -> void:
	_flash_q = quality
	_flash_word = word
	_flash_at = _clock
	queue_redraw()


## The word flashing now ("" when none), for tests.
func flashing() -> String:
	return _flash_word if _clock - _flash_at < FLASH_TIME else ""


func _process(d: float) -> void:
	_clock += d
	queue_redraw()


func _draw() -> void:
	var c := size * Vector2(0.5, 0.52)
	var r := minf(size.x, size.y) * 0.3
	var age := _clock - _flash_at
	var f := clampf(1.0 - age / FLASH_TIME, 0.0, 1.0)
	var fcol: Color = FLASH_COLORS.get(_flash_q, Palette.BONE)
	var fill := Color(Palette.WOOD, 0.9)
	if still:
		fill = Color(Palette.ASH, 0.55)
	if f > 0.0 and _flash_q != "miss":
		fill = fill.lerp(Color(fcol, 0.9), f * 0.75)
	draw_circle(c, r * (1.0 + 0.08 * f), fill)
	draw_arc(c, r * (1.0 + 0.08 * f), 0.0, TAU, 64, Palette.BONE.lerp(fcol, f), 6.0 + 10.0 * f)
	if player != "":
		_text(player, Vector2(c.x, 70.0), 46, Palette.BONE)
	_text(UIKit.fmt_score(session.score if session else 0), Vector2(c.x, size.y - 40.0), 46, Palette.EMBER)
	if f > 0.0 and _flash_word != "":
		_text(_flash_word, Vector2(c.x, c.y + r + 80.0), 72, Color(fcol, minf(1.0, f * 1.6)))
	if still:
		_text(tr("lane_still"), Vector2(c.x, c.y + 24.0), 64, Palette.BONE)
		return
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
	if absf(dt) < 0.15 and f <= 0.0:
		_text(tr("piazza_ring"), Vector2(c.x, c.y + r + 80.0), 64, Palette.EMBER_HOT)


func _text(t: String, at: Vector2, fs: int, col: Color) -> void:
	if _font == null:
		return
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, at - Vector2(w * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Palette.INK)
	draw_string(_font, at - Vector2(w * 0.5, 0.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
