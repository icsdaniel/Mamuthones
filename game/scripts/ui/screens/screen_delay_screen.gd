extends Screen
## The screen-delay tap test: notes slide down one lane onto a ring in silence, four to watch and
## twelve to tap; the player taps the pad the moment each note touches the ring. The median of
## (tap - the moment the note was drawn on the ring) is how long the screen and the touch take for
## this player, and becomes the "Notes drawn early" setting (Profile.visual_offset). No sound plays,
## so this measures the eyes and the screen, not the ears (the sound delay test does that).
## args: none (opened from Settings; back returns there).

const BPM := LatencyTest.BPM
const WATCH := 4
const COUNT := 12
const FALL := 1.2                ## seconds a note takes from the top of the lane to the ring

var test := LatencyTest.new()
var _running := false
var _start_us := 0
var _arrivals := PackedFloat64Array()
var _status: Label
var _detail: Label
var _lane: LaneDrill
var _actions: VBoxContainer
var _meter: TendencyMeter
var _taps := 0


func build() -> void:
	var box := UIKit.column(self, false, 18)
	UIKit.header(box, tr("vis_title"), on_back)
	box.add_child(UIKit.label(tr("vis_title"), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER))
	_status = UIKit.label(tr("vis_intro"), UIKit.LEAD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_status.name = "Status"
	box.add_child(_status)
	var pad := Button.new()
	pad.name = "Pad"
	pad.focus_mode = Control.FOCUS_NONE
	pad.flat = true
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.custom_minimum_size = Vector2(0, 420)
	pad.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	pad.button_down.connect(_on_tap)
	box.add_child(pad)
	_lane = LaneDrill.new()
	_lane.name = "Lane"
	_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lane.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_child(_lane)
	_meter = TendencyMeter.new()
	_meter.custom_minimum_size.y = 150
	_meter.visible = false
	box.add_child(_meter)
	_detail = UIKit.label("", UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_detail)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 12)
	box.add_child(_actions)
	_show_start()


func _show_start() -> void:
	_clear_actions()
	var go := UIKit.button(tr("lat_start"), _begin, UIKit.PRIMARY)
	go.name = "Start"
	_actions.add_child(go)
	var skip := UIKit.button(tr("lat_skip"), on_back, UIKit.QUIET)
	skip.name = "Skip"
	_actions.add_child(skip)


func _clear_actions() -> void:
	for c in _actions.get_children():
		_actions.remove_child(c)
		c.queue_free()


func _now() -> float:
	return (Time.get_ticks_usec() - _start_us) / 1_000_000.0


func _begin() -> void:
	_clear_actions()
	test.clear()
	_taps = 0
	_meter.visible = false
	_detail.text = ""
	_start_us = Time.get_ticks_usec()
	# The first note reaches the ring after it has fallen the whole lane.
	_arrivals = LatencyTest.click_times(BPM, WATCH + COUNT, FALL + 0.4)
	for i in range(WATCH, _arrivals.size()):
		test.add_click(_arrivals[i])
	_lane.arrivals = _arrivals
	_lane.fall = FALL
	_lane.watch = WATCH
	_running = true
	_status.text = tr("vis_watch")
	var skip := UIKit.button(tr("lat_skip"), _stop, UIKit.QUIET)
	skip.name = "Skip"
	_actions.add_child(skip)


func _stop() -> void:
	_running = false
	_lane.arrivals = PackedFloat64Array()
	_lane.queue_redraw()
	_show_start()


func _process(_delta: float) -> void:
	if not _running:
		return
	var now := _now()
	# Like the play screen: the picture is worked out from the clock read now, with no lead.
	_lane.now = now
	_lane.queue_redraw()
	if _arrivals.size() > WATCH and now >= _arrivals[WATCH - 1] + 0.3 and _status.text == tr("vis_watch"):
		_status.text = tr("vis_tap_now")
	if now > _arrivals[-1] + 0.8:
		_running = false
		_finish()


func _on_tap() -> void:
	if not _running:
		return
	var t := _now()
	_lane.tapped(t)
	if t > _arrivals[WATCH - 1] + 0.3:
		test.add_tap(t)
		_taps += 1
		_detail.text = tr("lat_count") % [_taps, COUNT]
	UIKit.vibrate(10)


func _finish() -> void:
	_clear_actions()
	var r := test.result()
	_meter.offsets = PackedFloat32Array(Array(test.offsets()))
	_meter.visible = true
	var lo: float = Profile.RANGES["visual_offset"].x
	var hi: float = Profile.RANGES["visual_offset"].y
	var lead := clampf(snappedf(float(r.offset), 0.005), lo, hi)
	if bool(r.get("ok", false)):
		Profile.set_setting("visual_offset", lead)
		_status.text = tr("vis_done") % roundi(lead * 1000.0)
		_detail.text = tr("vis_done_body")
		Sound.ui("unlock")
		var go := UIKit.button(tr("ui_continue"), on_back, UIKit.PRIMARY)
		go.name = "Continue"
		_actions.add_child(go)
		_actions.add_child(UIKit.button(tr("lat_again"), _begin, UIKit.QUIET))
	else:
		_status.text = tr("lat_uneven") if int(r.get("count", 0)) >= LatencyTest.MIN_TAPS else tr("lat_few")
		_detail.text = tr("vis_uneven_body")
		var again := UIKit.button(tr("lat_again"), _begin, UIKit.PRIMARY)
		again.name = "Again"
		_actions.add_child(again)
		if int(r.get("count", 0)) >= LatencyTest.MIN_TAPS:
			var keep := UIKit.button(tr("lat_keep") % roundi(lead * 1000.0), func() -> void:
				Profile.set_setting("visual_offset", lead)
				on_back())
			keep.name = "Keep"
			_actions.add_child(keep)
		var skip := UIKit.button(tr("lat_skip"), on_back, UIKit.QUIET)
		skip.name = "Skip"
		_actions.add_child(skip)


func on_back() -> void:
	app.back()


## One lane with a hit ring near its foot; notes fall onto the ring at `arrivals` (seconds of the
## test clock), the first `watch` of them dimmer (just to watch). A tap flashes the ring.
class LaneDrill extends Control:
	var arrivals := PackedFloat64Array()
	var fall := 1.2
	var watch := 4
	var now := 0.0
	var _flash := -9.0

	func tapped(t: float) -> void:
		_flash = t
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var lane_w := minf(w * 0.42, 260.0)
		var x0 := (w - lane_w) * 0.5
		var ring_y := size.y * 0.82
		var r := lane_w * 0.36
		draw_rect(Rect2(x0, 0.0, lane_w, size.y), Palette.NAVY_DEEP)
		draw_rect(Rect2(x0, 0.0, 4.0, size.y), Palette.GOLD_DEEP)
		draw_rect(Rect2(x0 + lane_w - 4.0, 0.0, 4.0, size.y), Palette.GOLD_DEEP)
		draw_rect(Rect2(0.0, ring_y - 2.0, w, 4.0), Palette.GOLD_DIM)
		var lit := clampf(1.0 - (now - _flash) / 0.15, 0.0, 1.0)
		draw_arc(Vector2(w * 0.5, ring_y), r, 0.0, TAU, 48, Palette.BONE.lerp(Palette.GOLD_HOT, lit), 6.0 + 4.0 * lit)
		for i in arrivals.size():
			var dt := arrivals[i] - now
			if dt > fall or dt < -0.25:
				continue
			var y := ring_y - dt / fall * ring_y
			var col := Color("#3a6fd8") if i >= watch else Color("#3a6fd8", 0.45)
			draw_circle(Vector2(w * 0.5, y), r * 0.86, Palette.INK)
			draw_circle(Vector2(w * 0.5, y), r * 0.78, col)
			draw_circle(Vector2(w * 0.5, y), r * 0.3, Palette.CREAM)
