extends Screen
## The workshop: build your own Mamuthone. Carve the mask (every bell earned is a carving point; finer
## options open as the story goes on), choose the bell set (tap to hear it), the fleece shade and the
## straps. A close-up of your own Mamuthone (Art's portrait) at the top changes as you choose, with
## the part being carved outlined.
## args: tab (optional: mask, bells or dress).

static var tab := "mask"
static var part := "brow"

var portrait: MamuthonePortrait
var mask: MaskView
var _body: VBoxContainer
var _tabs := {}


func build() -> void:
	var box := UIKit.column(self, true, 14)
	UIKit.header(box, tr("ws_title"), on_back)
	portrait = MamuthonePortrait.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(0, 340)
	box.add_child(portrait)
	_refresh_look()
	Profile.changed.connect(_refresh_look)
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


## Puts the saved look on the portrait (it redraws only when something changed).
func _refresh_look() -> void:
	if portrait == null:
		return
	var look: Dictionary = Profile.get_look()
	var m: Dictionary = MaskSpec.sanitize(look.get("mask", {}))
	var f := str(look.get("fleece", "black"))
	var st := str(look.get("straps", "natural"))
	var bs := str(look.get("bell_set", "village"))
	if m != portrait.mask or f != portrait.fleece or st != portrait.straps or bs != portrait.bell_set:
		portrait.set_look(m, f, st, bs)
		var walking := _body.get_node_or_null("Walking") as ProcessionScene if _body != null else null
		if walking != null:
			UIKit.show_look(walking)
	var hp := part if tab == "mask" else ""
	if portrait.highlight_part != hp:
		portrait.highlight_part = hp


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
	_refresh_look()


## Under the bells and dress choices: your Mamuthone walking in the row, whole, bells and all, so a
## choice is seen (and heard) on the move. It takes the room left on the page.
func _walking_row() -> void:
	var vh := get_viewport_rect().size.y if is_inside_tree() else 1440.0
	var scene := ProcessionScene.new()
	scene.name = "Walking"
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.custom_minimum_size = Vector2(0, clampf(vh - 1020.0, 240.0, 460.0))
	scene.auto_bpm = 76.0
	_body.add_child(scene)
	scene.set_stop(1)
	scene.set_unison(2)
	scene.set_reduced_motion(UIKit.reduced_motion())
	UIKit.show_look(scene)


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
		var b := UIKit.button(MaskSpec.name_of(p, I18n.locale()), _pick_part.bind(p), UIKit.COMPACT)
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
		b.theme_type_variation = UIKit.COMPACT
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
	_show_tab("mask")


func _build_bells() -> void:
	_body.add_child(UIKit.label(tr("ws_bells_intro"), ""))
	UIKit.bell_set_picker(_body)
	var ring := UIKit.button(tr("ws_ring"), _ring, UIKit.QUIET)
	ring.name = "Ring"
	_body.add_child(ring)
	_walking_row()


var _ring_up := true


func _ring() -> void:
	var id := str(Profile.get_look().get("bell_set", "light"))
	Sound.bell(id, _ring_up, "perfect")
	_ring_up = not _ring_up


func _build_dress() -> void:
	_body.add_child(UIKit.label(tr("ws_fleece"), UIKit.SUB))
	_choice_row("fleece", MaskSpec.FLEECES)
	_body.add_child(UIKit.label(tr("ws_straps"), UIKit.SUB))
	_choice_row("straps", MaskSpec.STRAPS)
	_body.add_child(UIKit.label(tr("ws_dress_note"), UIKit.CAPTION))
	_walking_row()


func _choice_row(key: String, ids: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.name = "Row_" + key
	_body.add_child(row)
	var current := str(Profile.get_look().get(key, ids[0]))
	for id in ids:
		var b := UIKit.button(tr("ws_%s_%s" % [key, id]), func() -> void:
			Profile.set_look(key, id)
			_refresh_look()
			for c in row.get_children():
				(c as Button).set_pressed_no_signal(c.name == "Opt_" + str(id)))
		b.toggle_mode = true
		b.set_pressed_no_signal(id == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Opt_" + str(id)
		row.add_child(b)
