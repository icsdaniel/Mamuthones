class_name Carousel
extends Container
## Big cards side by side that the player swipes through, the current one centred with its
## neighbours peeking in at the screen's edges (the story's stops). A horizontal drag follows the
## finger and snaps to the nearest card (a flick goes one on); a tap on the centred card emits
## `tapped`, a tap on a peeking neighbour brings it to the centre. The cards themselves ignore the
## mouse (the carousel handles every touch), so a swipe never leaves a card half pressed.
## Clips to its rect (the neighbours peek in at its sides). Snaps in whole art
## pixels; instant with reduced motion. Nothing runs between gestures.

signal page_changed(index: int)
signal tapped(index: int)

const SWIPE_START := 24.0
const TAP_SLOP := 20.0
const FLICK := 0.16
const PX := 3.0

## How far a card is narrower than the carousel on each side (the neighbour shows in that room).
var inset := 42.0
var gap := 12.0
## How dim a card one step from the centre is (brightness multiplier).
var side_dim := 0.55
var current := 0
var _offset := 0.0
var _press := Vector2.ZERO
var _pressing := false
var _dragging := false
var _tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func add_card(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	queue_sort()
	return c


func count() -> int:
	return get_child_count()


func card(i: int) -> Control:
	return get_child(i) as Control


func card_width() -> float:
	return maxf(size.x - inset * 2.0, 1.0)


func step() -> float:
	return card_width() + gap


## Centres card `i` (animated unless `instant`).
func go(i: int, instant := false) -> void:
	i = clampi(i, 0, maxi(count() - 1, 0))
	var changed := i != current
	var from := float(current) - _offset / step()
	current = i
	_offset = 0.0
	if _tween != null:
		_tween.kill()
	if instant or UIKit.reduced_motion() or not is_inside_tree():
		_place(float(current))
	else:
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_place, from, float(current), 0.24)
	if changed:
		page_changed.emit(current)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			if c is Control:
				fit_child_in_rect(c, Rect2(Vector2.ZERO, Vector2(card_width(), size.y)))
		_place(float(current) - _offset / step())


func _get_minimum_size() -> Vector2:
	var m := 0.0
	for c in get_children():
		if c is Control:
			m = maxf(m, (c as Control).get_combined_minimum_size().y)
	return Vector2(0.0, m)


## Lays the cards out with `at` (a fractional card index) in the centre.
func _place(at: float) -> void:
	for i in get_child_count():
		var c := get_child(i) as Control
		if c == null:
			continue
		var d := float(i) - at
		c.position.x = roundf((inset + d * step()) / PX) * PX
		var k := lerpf(1.0, side_dim, clampf(absf(d), 0.0, 1.0))
		c.modulate = Color(k, k, k, 1.0)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or count() == 0:
		return
	var pressed_ev: bool = (event is InputEventScreenTouch and event.index == 0) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed_ev:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			# the neighbours peek outside the rect: a press anywhere across the row counts
			var vw := get_viewport_rect().size.x
			var gx: float = event.position.x
			_pressing = pos.y >= 0.0 and pos.y <= size.y and gx >= 0.0 and gx <= vw
			_press = pos
			_dragging = false
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				var shift := _offset / maxf(step(), 1.0)
				var target := current
				if shift < -FLICK:
					target += 1
				elif shift > FLICK:
					target -= 1
				go(target)
				get_viewport().set_input_as_handled()
			elif pos.distance_to(_press) <= TAP_SLOP:
				var hit := _card_at(pos.x)
				if hit == current:
					tapped.emit(current)
				elif hit >= 0:
					Sound.ui("tap")
					go(hit)
				get_viewport().set_input_as_handled()
		return
	var moved: bool = (event is InputEventScreenDrag and event.index == 0) or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	if moved and _pressing:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var d := pos - _press
		if not _dragging and absf(d.x) > SWIPE_START and absf(d.x) > absf(d.y) * 1.4:
			_dragging = true
			if _tween != null:
				_tween.kill()
		if _dragging:
			var dx := d.x
			if (current == 0 and dx > 0.0) or (current == count() - 1 and dx < 0.0):
				dx *= 0.3
			_offset = dx
			_place(float(current) - _offset / step())
			get_viewport().set_input_as_handled()


func _card_at(x: float) -> int:
	for i in get_child_count():
		var c := get_child(i) as Control
		if c != null and x >= c.position.x and x <= c.position.x + c.size.x:
			return i
	return -1
