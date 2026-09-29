class_name PiazzaCue
extends Control
## Piazza's one huge cue, readable while moving, in the play screen's pixel art: a fiery ring closes
## in on a gold-rimmed bell plate as the next bell comes, with a big pixel arrow for up or down, the
## player's name above and "Ring!" on the beat. Every judged ring flashes the plate in its quality's
## colour with a big word, the same frame; during a stand-still the plate turns grey and says so.
## Everything is on the art grid (PxArt.PX) in palette colours, the words in PxType.

const FLASH_TIME := 0.45
## The plate's fill on a flash, by quality (a miss does not flash; only its word shows, in ash).
const FLASH_FILL := {
	"perfect": Color("#c08a2e"), "held": Color("#c08a2e"), "good": Color("#8a7c6c"),
	"early": Color("#3e6a8a"), "late": Color("#a04a28"),
}

var session: Session
var song_time := 0.0
var player := ""
var still := false:
	set(v):
		still = v
		queue_redraw()
var _flash_q := ""
var _flash_word := ""
var _flash_at := -9.0
var _clock := 0.0


func _ready() -> void:
	PxArt.nearest(self)


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
	var P := PxArt.PX
	var G: Array = PixelPalette.GOLD
	var F: Array = PixelPalette.FIRE
	var c := (size * Vector2(0.5, 0.52) / P).floor() * P
	var R := floorf(minf(size.x, size.y) * 0.3 / P)      ## the plate's radius, art px
	var age := _clock - _flash_at
	var f := clampf(1.0 - age / FLASH_TIME, 0.0, 1.0)
	var lit := f > 0.0 and FLASH_FILL.has(_flash_q)
	var r := R + (roundf(3.0 * f) if lit else 0.0)
	# the plate: a dark outline, a gold rim, a navy face with a ring of gold studs
	var fill: Color = PixelPalette.NAVY[1]
	var rim: Color = G[3]
	var edge: Color = G[4]
	var stud: Color = G[4]
	if still:
		fill = PixelPalette.SETT[3]
		rim = PixelPalette.BONE[1]
		edge = PixelPalette.BONE[2]
		stud = PixelPalette.BONE[2]
	if lit:
		fill = FLASH_FILL[_flash_q] if f > 0.35 else fill.lerp(FLASH_FILL[_flash_q], 0.5)
		rim = G[4]
		edge = G[5]
	FireSkin.px_disc(self, c, r + 2.0, r + 2.0, PixelPalette.K[0])
	FireSkin.px_disc(self, c, r, r, fill)
	if not lit:
		# a little volume: a lighter crescent at the top left of the face
		var sheen: Color = PixelPalette.NAVY[2] if not still else PixelPalette.SETT[4]
		FireSkin.px_disc(self, c, r - 4.0, r - 4.0, sheen)
		FireSkin.px_disc(self, c + Vector2(P, P) * 2.0, r - 5.0, r - 5.0, fill)
	FireSkin.px_ring(self, c, r, r, 3.0, rim)
	FireSkin.px_ring(self, c, r, r, 1.0, edge)
	FireSkin.px_ring(self, c, r - 3.0, r - 3.0, 1.0, PixelPalette.K[0])
	for i in 16:
		var a := TAU * float(i) / 16.0
		var sp := c + (Vector2(cos(a), sin(a)) * (r - 6.0)).round() * P
		draw_rect(Rect2(sp - Vector2(P, 0.0), Vector2(3.0 * P, P)), PixelPalette.K[0])
		draw_rect(Rect2(sp - Vector2(0.0, P), Vector2(P, 3.0 * P)), PixelPalette.K[0])
		draw_rect(Rect2(sp, Vector2(P, P)), stud)
	# the flash: a bright ring thrown off the plate
	if lit:
		var fr := r + 4.0 + roundf(10.0 * (1.0 - f))
		FireSkin.px_ring(self, c, fr, fr, 2.0, G[5] if f > 0.6 else G[4] if f > 0.3 else G[3])
	# the words (the name and the big word go on top of the closing ring, below)
	var score := UIKit.fmt_score(session.score if session else 0)
	var score_y := size.y - 18.0 - PxType.line_height("score", 1)
	PxType.draw(self, "score", Vector2(c.x, score_y), score, Color.WHITE, 1, 0)
	var word_y := c.y + (R + 5.0) * P
	var room := score_y - word_y - 2.0 * P
	var flash_word := _flash_word if f > 0.0 else ""
	if still:
		PxType.draw(self, "big", Vector2(c.x, c.y - PxType.line_height("big") * 0.5), tr("lane_still"), PixelPalette.BONE[3], 1, 0)
	var n: Note = session.upcoming_bell(song_time) if session != null and not still else null
	if n == null:
		if player != "":
			PxType.draw(self, "big_gold", Vector2(c.x, 48.0), player, Color.WHITE, 1, 0)
		if flash_word != "":
			_word(flash_word, word_y, room, _flash_q)
		return
	var dt := n.t - song_time
	var approach := 1.6
	var on_beat := absf(dt) <= 0.12
	if dt <= approach:
		# the fire closing in: red far out, then ember, then white-hot as it meets the plate
		var k := clampf(dt / approach, 0.0, 1.0)
		var rr := roundf(r + 4.0 + R * 1.6 * k)
		var th := roundf(2.0 + 3.0 * (1.0 - k))
		var col: Color = F[7] if k < 0.08 else F[6] if k < 0.25 else F[5] if k < 0.45 else F[4] if k < 0.7 else F[3]
		FireSkin.px_ring(self, c, rr + 1.0, rr + 1.0, th + 2.0, PixelPalette.K[0])
		FireSkin.px_ring(self, c, rr, rr, th, col)
	_arrow(c, R, -1.0 if n.up else 1.0, on_beat)
	# the words over the closing ring
	if player != "":
		PxType.draw(self, "big_gold", Vector2(c.x, 48.0), player, Color.WHITE, 1, 0)
	if flash_word != "":
		_word(flash_word, word_y, room, _flash_q)
	elif on_beat:
		_word(tr("piazza_ring"), word_y, room, "ring")


## A big pixel arrow on the plate (d -1 up, 1 down): a stepped head and a shaft, bone with a shaded
## right side in a dark outline; white-hot on the beat.
func _arrow(c: Vector2, R: float, d: float, hot: bool) -> void:
	var P := PxArt.PX
	var h := roundf(R * 1.1)                 ## tip to tail, art px
	var hh := roundf(h * 0.48)               ## the head's height
	var hw := roundf(R * 0.42)               ## half the head's width
	var sw := maxf(2.0, roundf(R * 0.14))    ## half the shaft's width
	var tip := c.y + roundf(d * h * 0.5) * P
	var body: Color = PixelPalette.FIRE[7] if hot else PixelPalette.BONE[3]
	var shade: Color = PixelPalette.FIRE[5] if hot else PixelPalette.BONE[1]
	var light: Color = PixelPalette.FIRE[7] if hot else PixelPalette.BONE[4]
	for pass_ in 2:
		for j in int(h):
			var w := floorf(float(j) / hh * hw) if float(j) < hh else sw
			var y := tip - d * float(j) * P - (P if d > 0.0 else 0.0)
			var rect := Rect2(c.x - w * P, y, (2.0 * w + 1.0) * P, P)
			if pass_ == 0:
				draw_rect(rect.grow(P), PixelPalette.K[0])
				continue
			draw_rect(rect, body)
			if w >= 1.0:
				draw_rect(Rect2(c.x + w * P, y, P, P), shade)
				draw_rect(Rect2(c.x - w * P, y, P, P), light)


## A big word under the plate (in `room` screen px above the score): two art px per font px when it
## fits, tinted by quality.
func _word(text: String, y: float, room: float, q: String) -> void:
	var face := "big"
	var col: Color = PixelPalette.BONE[4]
	match q:
		"perfect", "held", "ring":
			face = "big_gold"
			col = Color.WHITE
		"early":
			col = Palette.EARLY
		"late":
			col = Palette.LATE
		"miss":
			col = PixelPalette.BONE[1]
	var k := 2 if PxType.width(face, text, 2) <= size.x - 24.0 and PxType.line_height(face, 2) <= room else 1
	PxType.draw(self, face, Vector2(size.x * 0.5, y), text, col, k, 0)
