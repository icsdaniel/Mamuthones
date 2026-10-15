extends TestCase
## The workshop: picture swatches put the choice on the stage's pixel Mamuthone at once, a locked
## carving says what opens it and changes nothing, the pages are a segmented pager (Mask, Wood,
## Dress), each framing the stage its own way, and no caption is ever cut short.


func test_swatches_dress_the_stage_figure() -> void:
	UIHarness.fresh_profile()
	check_eq(str(Profile.get_look().fleece), MaskSpec.DEFAULT_FLEECE, "a new player wears the default fleece")
	check_eq(MaskSpec.DEFAULT_FLEECE, "dark_brown", "the default fleece is dark brown")
	check_eq(Profile.FLEECES, MaskSpec.FLEECES, "the profile and the mask spec agree on the fleeces")
	var app := UIHarness.make_app(tree, "workshop", {"tab": "fleece"})
	await UIHarness.settle(tree)
	var screen := app.current()
	var stage := screen.find_child("Stage", true, false) as LookStage
	check(stage != null, "the workshop has its stage")
	check(screen.find_child("Pager", true, false) is Pager, "the categories are pages")
	for id in ["Tab_mask", "Tab_wood", "Tab_dress"]:
		check(screen.find_child(id, true, false) != null, "a segment for %s" % id)
	check(screen.find_child("Tab_fleece", true, false) == null, "sheepskin and leather share one page")
	check(not stage.closeup, "the dress page shows the whole figure")
	var page := screen.find_child("DressPage", true, false)
	var black := page.find_child("Opt_black", true, false) as Swatch
	if check(black != null, "the black fleece is a swatch"):
		black.pressed.emit()
		await UIHarness.frames(tree, 1)
		check_eq(str(Profile.get_look().fleece), "black", "tapping it puts it on")
		var again := page.find_child("Opt_black", true, false) as Swatch
		check(again != null and again.chosen, "and marks it chosen")
		var upper := stage.figure.get_node("Upper") as Sprite2D
		check(upper.texture.resource_path.contains("black"), "the stage's figure wears it")
	var dark := page.find_child("Opt_dark", true, false) as Swatch
	check(dark != null, "the dark leather is a swatch on the same page")
	# the carving pages frame the mask up close
	var pager := screen.find_child("Pager", true, false) as Pager
	pager.go(0)
	await UIHarness.settle(tree)
	check(stage.closeup, "the mask page shows the mask up close")
	# a carving not open yet: fresh profile, nothing earned
	var mask_page := screen.find_child("MaskPage", true, false)
	var locked: Swatch = null
	for s in mask_page.find_children("Opt_*", "Swatch", true, false):
		if (s as Swatch).locked:
			locked = s
	if check(locked != null, "a fresh player sees locked carvings"):
		var before: Dictionary = Profile.get_look().mask.duplicate()
		check(locked.caption.text != "", "a locked carving says what opens it")
		locked.pressed.emit()
		check_eq(Profile.get_look().mask, before, "a locked carving changes nothing")
	UIHarness.free_app(app)
	UIHarness.restore_profile()
	await UIHarness.frames(tree, 1)


## A carving changes the other carving page's pictures too (they show the mask as it is now).
func test_a_carving_refreshes_the_other_page() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "workshop", {"tab": "mask"})
	await UIHarness.settle(tree)
	var screen := app.current()
	var wood := screen.find_child("WoodPage", true, false)
	var before: Array = []
	for s in wood.find_children("Opt_*", "Swatch", true, false):
		before.append(s)
	var mask_page := screen.find_child("MaskPage", true, false)
	var open: Swatch = null
	for s in mask_page.find_children("Opt_*", "Swatch", true, false):
		if not (s as Swatch).locked:
			open = s
	if check(open != null, "a fresh player has a carving open"):
		open.pressed.emit()
		await UIHarness.frames(tree, 1)
		var after := wood.find_children("Opt_*", "Swatch", true, false)
		check(after.size() > 0 and not before.has(after[0]), "the wood page is drawn again")
	UIHarness.free_app(app)
	UIHarness.restore_profile()
	await UIHarness.frames(tree, 1)


## One tap is one toggle: a press and a release in place switch the view once, a drag does not,
## and a touch event alone (a phone also sends one, besides the emulated mouse) does nothing.
func test_stage_tap_toggles_once() -> void:
	var stage := LookStage.new()
	stage.size = Vector2(600, 700)
	tree.root.add_child(stage)
	await UIHarness.frames(tree, 1)
	var taps := [0]
	stage.tapped.connect(func() -> void: taps[0] += 1)
	var at := Vector2(300, 300)
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = true
	stage._gui_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	stage._gui_input(touch)
	check_eq(taps[0], 0, "a touch event alone does not toggle")
	_click(stage, at, at + Vector2(5, 3))
	check_eq(taps[0], 1, "a tap toggles once")
	check(stage.closeup, "into the close-up")
	_click(stage, at, at + Vector2(80, 0))
	check_eq(taps[0], 1, "a drag is no tap")
	_click(stage, at, at)
	check(not stage.closeup, "a second tap turns back")
	stage.queue_free()
	await UIHarness.frames(tree, 1)


func _click(stage: LookStage, from: Vector2, to: Vector2) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.position = from
	mb.pressed = true
	stage._gui_input(mb)
	mb = mb.duplicate()
	mb.position = to
	mb.pressed = false
	stage._gui_input(mb)


## Every swatch caption and part chip fits whole, in English and Italian, on every page and size.
func test_no_caption_is_cut_short() -> void:
	var sizes: Array[Vector2i] = UIHarness.SIZES.duplicate()
	sizes.append_array([Vector2i(1080, 2400), Vector2i(1290, 2796)])
	for lang in ["en", "it"]:
		for sz in sizes:
			UIHarness.fresh_profile()
			Profile.set_setting("language", lang)
			var app := UIHarness.make_app(tree, "workshop", {"tab": "mask"}, sz)
			await UIHarness.settle(tree)
			var screen := app.current()
			for part in ["brow", "eyes", "nose", "cheeks", "mouth", "finish", "patina"]:
				var page := "wood" if part in ["finish", "patina"] else "mask"
				var chip := screen.find_child("Part_" + part, true, false) as Button
				if chip != null:
					chip.pressed.emit()
					await UIHarness.frames(tree, 2)
				for b in screen.find_children("Part_*", "Button", true, false):
					_check_button(b as Button, "%s %s %s chip" % [lang, sz, b.name])
				var host := screen.find_child(page.capitalize() + "Page", true, false)
				for s in host.find_children("Opt_*", "Swatch", true, false):
					_check_label((s as Swatch).caption, "%s %s %s %s" % [lang, sz, part, s.name])
			for s in screen.find_child("DressPage", true, false).find_children("Opt_*", "Swatch", true, false):
				_check_label((s as Swatch).caption, "%s %s dress %s" % [lang, sz, s.name])
			var toggle := (screen.find_child("Stage", true, false) as LookStage).toggle
			_check_button(toggle, "%s %s view toggle" % [lang, sz])
			UIHarness.free_app(app)
			await UIHarness.frames(tree, 1)
	Profile.set_setting("language", "en")
	UIHarness.restore_profile()
	await UIHarness.frames(tree, 1)


func _check_label(l: Label, what: String) -> void:
	var font := l.get_theme_font("font")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	check(w <= l.size.x + 0.5, "%s: \"%s\" fits (%d > %d)" % [what, l.text, w, l.size.x])
	check(l.get_theme_font_size("font_size") >= 26, "%s: type stays 26 px or more" % what)


func _check_button(b: Button, what: String) -> void:
	var font := b.get_theme_font("font")
	var sb := b.get_theme_stylebox("normal")
	var pads := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	if b.icon != null:
		pads += b.icon.get_width() + b.get_theme_constant("h_separation")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + pads
	check(w <= b.size.x + 0.5, "%s: \"%s\" fits (%d > %d)" % [what, b.text, w, b.size.x])
