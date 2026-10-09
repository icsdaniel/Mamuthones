class_name GradeBadge
extends Control
## A run's letter grade (Session.GRADES: F, E, D, C, B, A, S, S+) in the pixel type on a small dark
## plate with a gold rim. The letter warms from ember red (F) through gold (A) to white-hot fire (S,
## S+). rank -1 is an empty plate (never played). A full combo is its own mark: a red tab printed
## "FC" in gold beside the plate. Used for a stop's best, a difficulty's best, the boards and the
## results; `animate()` stamps the letter in on the results.

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
var full_combo := false:
	set(v):
		full_combo = v
		if is_inside_tree():
			_size()
		queue_redraw()
var face := "caps"
var k := 2
var _pop := 1.0
var _plate_w := 0.0


## p_big: the results' big letter (the doubled face); otherwise the small one for lists.
func _init(p_rank := -1, p_big := false, p_full_combo := false) -> void:
	rank = p_rank
	full_combo = p_full_combo
	face = "big" if p_big else "caps"
	k = 2 if p_big else 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_size()


func _size() -> void:
	var w := PxType.width(face, "S+", k)
	var h := PxType.line_height(face, k)
	var pad := PX * (4.0 if face == "big" else 2.0)
	_plate_w = ceilf((w + pad * 2.0) / PX) * PX
	var tag := _tag_size().x if full_combo else 0.0
	custom_minimum_size = Vector2(_plate_w + tag, ceilf((h + pad) / PX) * PX)


## The FC tab: the caps face (doubled on the results), with a little room round it.
func _tag_size() -> Vector2:
	var tk := 2 if face == "big" else 1
	return Vector2(ceilf((PxType.width("caps_gold", "FC", tk) + PX * 4.0) / PX) * PX,
			ceilf((PxType.line_height("caps_gold", tk) + PX * 2.0) / PX) * PX)


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
			Sound.bell(BellSets.STANDARD, true, "perfect" if rank >= Session.RANK_S else "good")
		stamped.emit())
	tw.tween_method(func(v: float) -> void:
		_pop = v
		queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	# The plate: K0 fill, a gold rim one art pixel wide, a brighter rim for S and S+.
	var r := Rect2(Vector2.ZERO, Vector2(_plate_w if _plate_w > 0.0 else size.x, size.y))
	var rim: Color = PixelPalette.GOLD[2] if rank < Session.RANK_S else PixelPalette.GOLD[4]
	if full_combo and rank >= 0:
		rim = PixelPalette.FIRE[6]
		# The tab sits against the plate's right edge, centred, red with a gold rim.
		var ts := _tag_size()
		var tr_ := Rect2(Vector2(r.size.x - PX, roundf((size.y - ts.y) * 0.5 / PX) * PX), ts)
		draw_rect(tr_, PixelPalette.RED[2])
		draw_rect(Rect2(tr_.position, Vector2(ts.x, PX)), PixelPalette.GOLD[4])
		draw_rect(Rect2(tr_.position + Vector2(0, ts.y - PX), Vector2(ts.x, PX)), PixelPalette.GOLD[4])
		draw_rect(Rect2(tr_.position + Vector2(ts.x - PX, 0), Vector2(PX, ts.y)), PixelPalette.GOLD[4])
		PxType.draw(self, "caps_gold", Vector2(tr_.get_center().x, tr_.position.y + PX), "FC", Color.WHITE, 2 if face == "big" else 1, 0)
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
	var pos := Vector2(r.size.x * 0.5, (size.y - h) * 0.5)
	var ink := Color(COLORS[rank], clampf(_pop * 2.0, 0.0, 1.0))
	if text.ends_with("+") and face == "big" and not PxType.smooth:
		# The doubled face's Scale2x rounds a small "+" into a dot, so the plus is drawn square here.
		var w := PxType.width(face, text, kk)
		var sw := PxType.width(face, "S", kk)
		var x0 := roundf((pos.x - w * 0.5) / PX) * PX
		PxType.draw(self, face, Vector2(x0, pos.y), "S", ink, kk, -1)
		var t := PX * kk * 2.0
		var arm := maxf(t * 3.0, floorf((w - sw - PX * kk) / t) * t)
		var c := Vector2(x0 + sw + (w - sw) * 0.5, pos.y + h * 0.5)
		c = Vector2(roundf(c.x / PX) * PX, roundf(c.y / PX) * PX)
		draw_rect(Rect2(c - Vector2(arm * 0.5, t * 0.5), Vector2(arm, t)), ink)
		draw_rect(Rect2(c - Vector2(t * 0.5, arm * 0.5), Vector2(t, arm)), ink)
		return
	PxType.draw(self, face, pos, text, ink, kk, 0)
