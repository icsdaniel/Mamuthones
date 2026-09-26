extends Screen
## The workshop: build your own Mamuthone. Carve the mask (every bell earned is a carving point; finer
## options open as the story goes on), choose the bell set (tap to hear it), the fleece shade and the
## straps. Your Mamuthone walks in the procession at the top and changes as you choose.
## args: tab (optional: mask, bells or dress).

static var tab := "mask"
static var part := "brow"

var scene: ProcessionScene
var mask: MaskView
var _body: VBoxContainer
var _tabs := {}


func build() -> void:
	var box := UIKit.column(self, true, 14)
	UIKit.header(box, tr("ws_title"), on_back)
	scene = ProcessionScene.new()
	scene.name = "Procession"
	scene.custom_minimum_size = Vector2(0, 300)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(scene)
	scene.set_stop(maxi(Progression.highest_stop(), 1))
	scene.set_reduced_motion(UIKit.reduced_motion())
	scene.set_unison(3)
	scene.auto_bpm = 76.0
	UIKit.show_look(scene)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for t in ["mask", "bells", "dress"]:
		var b := UIKit.button(tr("ws_tab_" + t), _show_tab.bind(t))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Tab_" + t
		row.add_child(b)
		_tabs[t] = b
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	box.add_child(_body)
	_show_tab(str(args.get("tab", tab)))


func _show_tab(t: String) -> void:
	tab = t
	for k in _tabs:
		(_tabs[k] as Button).set_pressed_no_signal(k == t)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	mask = null
	match t:
		"mask":
			_build_mask()
		"bells":
			_build_bells()
		_:
			_build_dress()


func _spec() -> Dictionary:
	return MaskSpec.sanitize(Profile.get_look().get("mask", {}))


func _build_mask() -> void:
	var points := Progression.carving_points()
	_body.add_child(UIKit.label(tr("ws_points") % points, UIKit.SUB))
	_body.add_child(UIKit.label(tr("ws_points_note"), UIKit.CAPTION))
	mask = MaskView.new()
	mask.name = "Mask"
	mask.custom_minimum_size = Vector2(0, 420)
	mask.show_halo = true
	mask.spec = _spec()
	mask.highlight_part = part
	_body.add_child(mask)
	var parts := GridContainer.new()
	parts.columns = 4
	parts.add_theme_constant_override("h_separation", 8)
	parts.add_theme_constant_override("v_separation", 8)
	_body.add_child(parts)
	for p in MaskSpec.PARTS:
		var b := UIKit.button(MaskSpec.name_of(p, I18n.locale()), _pick_part.bind(p))
		b.toggle_mode = true
		b.set_pressed_no_signal(p == part)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Part_" + p
		parts.add_child(b)
	var opts := GridContainer.new()
	opts.columns = 2
	opts.name = "Options"
	opts.add_theme_constant_override("h_separation", 10)
	opts.add_theme_constant_override("v_separation", 10)
	_body.add_child(opts)
	var spec := _spec()
	for o in MaskSpec.options(part):
		var open := Progression.mask_option_unlocked(part, o)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH * 1.15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.name = "Opt_" + o
		var label := MaskSpec.name_of(o, I18n.locale())
		if not open:
			var req := MaskSpec.requirement(part, o)
			label += "\n" + tr("ws_needs") % [int(req.stop), int(req.cost)]
		b.text = label
		b.disabled = not open
		b.set_pressed_no_signal(spec.get(part, "") == o)
		b.pressed.connect(_carve.bind(o))
		opts.add_child(b)


func _pick_part(p: String) -> void:
	part = p
	Sound.ui("tap")
	_show_tab("mask")


func _carve(option: String) -> void:
	var spec := _spec()
	spec[part] = option
	Profile.set_look("mask", spec)
	Sound.ui("carve")
	UIKit.vibrate(15)
	UIKit.show_look(scene)
	_show_tab("mask")


func _build_bells() -> void:
	_body.add_child(UIKit.label(tr("ws_bells_intro"), ""))
	UIKit.bell_set_picker(_body)
	var ring := UIKit.button(tr("ws_ring"), _ring, UIKit.QUIET)
	ring.name = "Ring"
	_body.add_child(ring)


var _ring_up := true


func _ring() -> void:
	var id := str(Profile.get_look().get("bell_set", "light"))
	Sound.bell(id, _ring_up, "perfect")
	_ring_up = not _ring_up
	scene.jolt("bell")


func _build_dress() -> void:
	_body.add_child(UIKit.label(tr("ws_fleece"), UIKit.SUB))
	_choice_row("fleece", MaskSpec.FLEECES)
	_body.add_child(UIKit.label(tr("ws_straps"), UIKit.SUB))
	_choice_row("straps", MaskSpec.STRAPS)
	_body.add_child(UIKit.label(tr("ws_dress_note"), UIKit.CAPTION))


func _choice_row(key: String, ids: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.name = "Row_" + key
	_body.add_child(row)
	var current := str(Profile.get_look().get(key, ids[0]))
	for id in ids:
		var b := UIKit.button(tr("ws_%s_%s" % [key, id]), func() -> void:
			Profile.set_look(key, id)
			UIKit.show_look(scene)
			for c in row.get_children():
				(c as Button).set_pressed_no_signal(c.name == "Opt_" + str(id)))
		b.toggle_mode = true
		b.set_pressed_no_signal(id == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Opt_" + str(id)
		row.add_child(b)
