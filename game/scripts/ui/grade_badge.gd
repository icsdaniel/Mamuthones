class_name GradeBadge
extends Control
## A run's letter grade (Session.GRADES: F, E, D, C, B, A, S, S+) in the pixel type on a small dark
## plate with a gold rim. The letter warms from ember red (F) through gold (A) to white-hot fire (S,
## S+). rank -1 is an empty plate (never played). Used for a stop's best, a difficulty's best, the
## boards and the results; `animate()` stamps the letter in on the results.

## The letter has landed: for sounds and screen juice.
signal stamped

const COLORS: Array[Color] = [
	Color("#c02a22"),   # F  (PixelPalette.RED[3])
	Color("#e2561a"),   # E  (FIRE[3])
	Color("#f47e22"),   # D  (FIRE[4])
	Color("#c08a2e"),   # C  (GOLD[3])
	Color("#e8b64c"),   # B  (GOLD[4])
	Color("#f8dc8a"),   # A  (GOLD[5])
	Color("#fde07a"),   # S  (FIRE[6])
	Color("#fff6cf"),   # S+ (FIRE[7])
]
const PX := 3.0

var rank := -1:
	set(v):
		rank = clampi(v, -1, Session.GRADES.size() - 1)
		queue_redraw()
var face := "caps"
var k := 2
var _pop := 1.0


## p_big: the results' big letter (the doubled face); otherwise the small one for lists.
func _init(p_rank := -1, p_big := false) -> void:
	rank = p_rank
	face = "big" if p_big else "caps"
	k = 2 if p_big else 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var w := PxType.width(face, "S+", k)
	var h := PxType.line_height(face, k)
	var pad := PX * (4.0 if face == "big" else 2.0)
	custom_minimum_size = Vector2(ceilf((w + pad * 2.0) / PX) * PX, ceilf((h + pad) / PX) * PX)


func letter() -> String:
	return Session.grade_name(rank) if rank >= 0 else ""


## Stamp the letter in after `delay` seconds: it lands big and settles, with a bell for S and better.
func animate(delay := 0.3, ring := true) -> void:
	if rank < 0:
		return
	_pop = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if ring:
			Sound.bell(Profile.get_look().get("bell_set", "light"), true, "perfect" if rank >= Session.RANK_S else "good")
		stamped.emit())
	tw.tween_method(func(v: float) -> void:
		_pop = v
		queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	# The plate: K0 fill, a gold rim one art pixel wide, a brighter rim for S and S+.
	var r := Rect2(Vector2.ZERO, size)
	var rim: Color = PixelPalette.GOLD[2] if rank < Session.RANK_S else PixelPalette.GOLD[4]
	draw_rect(r, PixelPalette.K[0])
	draw_rect(Rect2(r.position, Vector2(r.size.x, PX)), rim)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - PX), Vector2(r.size.x, PX)), rim)
	draw_rect(Rect2(r.position, Vector2(PX, r.size.y)), rim)
	draw_rect(Rect2(r.position + Vector2(r.size.x - PX, 0), Vector2(PX, r.size.y)), rim)
	if rank < 0:
		draw_rect(Rect2(size * 0.5 - Vector2(PX * 3.0, PX * 0.5), Vector2(PX * 6.0, PX)), PixelPalette.BONE[1])
		return
	if _pop <= 0.0:
		return
	var kk := k
	# Landing: one step larger while it settles (whole steps keep the pixels square).
	if _pop < 0.85:
		kk = k + 1
	var text := letter()
	var h := PxType.line_height(face, kk)
	var pos := Vector2(size.x * 0.5, (size.y - h) * 0.5)
	PxType.draw(self, face, pos, text, Color(COLORS[rank], clampf(_pop * 2.0, 0.0, 1.0)), kk, 0)
