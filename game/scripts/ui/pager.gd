class_name Pager
extends Container
## Pages side by side that the player swipes between (or picks with UIKit.paged()'s segmented control):
## the kit's answer to long screens instead of a scroll bar. Every page gets the pager's full size;
## add_page() returns a VBox to fill. A horizontal drag that starts on the pager follows the finger
## and snaps to the nearest page (a flick goes one page on); a vertical drag or a tap is left to the
## controls inside. Presses on anything drawn over the pager (a dialog, a banner) are ignored. Snaps in whole art pixels, quickly; instant with reduced motion.

signal page_changed(index: int)

const SWIPE_START := 24.0      ## px of sideways travel before the pager takes the drag
const FLICK := 0.18            ## fraction of the width that turns the page on release
const PX := 3.0

var current := 0
var _offset := 0.0             ## extra sideways shift while dragging (px)
var _press := Vector2.ZERO
var _pressing := false
var _dragging := false
var _tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## A new page (named `id`) holding a VBox; `scroll` wraps it in a touch-drag ScrollContainer with no
## bar, for a page that can outgrow a short phone.
func add_page(id: String, separation := 18, scroll := false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	if scroll:
		var sc := ScrollContainer.new()
		sc.name = id
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		sc.scroll_deadzone = 12
		add_child(sc)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL   # a short page still fills the pager
		sc.add_child(box)
	else:
		box.name = id
		add_child(box)
	queue_sort()
	return box


func page_count() -> int:
	return get_child_count()


func page(i: int) -> Control:
	return get_child(i) as Control


## Shows page `i` (animated unless `instant`).
func go(i: int, instant := false) -> void:
	i = clampi(i, 0, maxi(page_count() - 1, 0))
	var changed := i != current
	var from := -current * size.x + _offset
	current = i
	_offset = 0.0
	if _tween != null:
		_tween.kill()
	if instant or UIKit.reduced_motion() or not is_inside_tree():
		_place(-current * size.x)
	else:
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_place, from, -current * size.x, 0.22)
	if changed:
		page_changed.emit(current)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for i in get_child_count():
			var c := get_child(i) as Control
			if c != null:
				fit_child_in_rect(c, Rect2(Vector2.ZERO, size))
		_place(-current * size.x + _offset)


func _get_minimum_size() -> Vector2:
	var m := Vector2.ZERO
	for c in get_children():
		if c is Control and not (c is ScrollContainer):
			m = m.max((c as Control).get_combined_minimum_size())
	return Vector2(0.0, m.y)


func _place(x: float) -> void:
	for i in get_child_count():
		var c := get_child(i) as Control
		if c != null:
			var p := x + i * size.x
			var r := roundf(p / PX) * PX
			# a page (all but) off the side is put a whole step clear of it: at a fractional screen
			# scale its edge would otherwise round onto the last physical column inside the clip
			if absf(p) >= size.x - PX:
				r = (ceilf(p / PX) if p > 0.0 else floorf(p / PX)) * PX + signf(p) * PX
			c.position.x = r


## Whether something that takes input (a dialog's veil, a sheet) lies over `at` (viewport px): the
## App's overlay layer.
func _covered(at: Vector2) -> bool:
	var app: Variant = get_tree().root.get_meta("app", null) if is_inside_tree() else null
	# the meta can outlive its App (a freed one): only a live App's overlay counts
	if not is_instance_valid(app) or not (app as Object).has_method("overlay"):
		return false
	for c in (app.call("overlay") as Control).get_children():
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP \
				and (c as Control).get_global_rect().has_point(at):
			return true
	return false


## Whether a press at `at` (viewport px) lands on a control that drags sideways itself: a Range
## (HSlider, scroll bar, ...) on one of the pages. Such a press never arms the swipe.
func _on_dragger(at: Vector2, node: Node = self) -> bool:
	for c in node.get_children():
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var cc := c as Control
		if cc is Range:
			var r := Rect2(Vector2.ZERO, cc.size)
			if r.has_point(cc.get_global_transform_with_canvas().affine_inverse() * at):
				return true
		if _on_dragger(at, cc):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or page_count() < 2:
		return
	var pressed_ev: bool = (event is InputEventScreenTouch and event.index == 0) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed_ev:
		var pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			# only a press that lands on the pager itself: never one on a dialog or banner above it
			# ... nor one on a slider, which drags sideways itself
			_pressing = Rect2(Vector2.ZERO, size).has_point(pos) and not _covered(event.position) \
				and not _on_dragger(event.position)
			_press = pos
			_dragging = false
		elif _pressing:
			_pressing = false
			if _dragging:
				_dragging = false
				var shift := _offset / maxf(size.x, 1.0)
				var target := current
				if shift < -FLICK:
					target += 1
				elif shift > FLICK:
					target -= 1
				go(target)
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
			# resist past the first and last page
			if (current == 0 and dx > 0.0) or (current == page_count() - 1 and dx < 0.0):
				dx *= 0.3
			_offset = dx
			_place(-current * size.x + _offset)
			get_viewport().set_input_as_handled()
