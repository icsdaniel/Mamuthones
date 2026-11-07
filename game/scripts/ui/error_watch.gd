class_name ErrorWatch
extends Logger
## Test builds only (debug APKs): every script or engine error is also shown on the phone, in a
## cream box at the foot of the screen, so a fault that only happens on a phone can be sent back as
## a screenshot. Tap the box to hide it. Release builds never add it.

const MAX_LINES := 8

static var _box: PanelContainer
static var _label: Label
static var _lines: PackedStringArray = []
static var _watch: ErrorWatch


## Called once by App: adds the logger and the box (in `overlay`), in debug builds only.
static func install(overlay: Control) -> void:
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
		return
	if _watch == null:
		_watch = ErrorWatch.new()
		OS.add_logger(_watch)
	_box = PanelContainer.new()
	_box.name = "ErrorWatch"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#efe6d2")
	sb.border_color = Color("#c8352a")
	sb.set_border_width_all(4)
	sb.set_content_margin_all(12)
	_box.add_theme_stylebox_override("panel", sb)
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = 16
	_box.offset_right = -16
	_box.offset_bottom = -16
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.z_index = 100
	_box.visible = false
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_label.add_theme_color_override("font_color", Color("#141014"))
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_box.add_child(_label)
	_box.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_box.visible = false
			_lines.clear())
	overlay.add_child(_box)


static func _show(text: String) -> void:
	if _box == null or not is_instance_valid(_box):
		return
	_lines.append(text)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_label.text = "Test build: an error happened (tap to hide)\n" + "\n".join(_lines)
	_box.visible = true


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var where := "%s:%d %s" % [file.get_file(), line, function]
	var text := (rationale if rationale != "" else code) + "  @ " + where
	for bt in script_backtraces:
		if bt != null and bt.get_frame_count() > 0:
			text += "  <- %s:%d %s" % [bt.get_frame_file(0).get_file(), bt.get_frame_line(0), bt.get_frame_function(0)]
			break
	# errors can come from any thread: show them from the main loop
	ErrorWatch._show.call_deferred(text)


func _log_message(_message: String, _error: bool) -> void:
	pass
