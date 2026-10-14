extends TestCase
## The workshop: picture swatches put the choice on the stage's pixel Mamuthone at once, a locked
## carving says what opens it and changes nothing, and the pages are a segmented pager.


func test_swatches_dress_the_stage_figure() -> void:
	UIHarness.fresh_profile()
	var app := UIHarness.make_app(tree, "workshop", {"tab": "fleece"})
	await UIHarness.settle(tree)
	var screen := app.current()
	var stage := screen.find_child("Stage", true, false) as LookStage
	check(stage != null, "the workshop has its stage")
	check(screen.find_child("Pager", true, false) is Pager, "the categories are pages")
	for id in ["Tab_mask", "Tab_wood", "Tab_fleece", "Tab_straps"]:
		check(screen.find_child(id, true, false) != null, "a segment for %s" % id)
	var page := screen.find_child("FleecePage", true, false)
	var brown := page.find_child("Opt_dark_brown", true, false) as Swatch
	if check(brown != null, "the dark brown fleece is a swatch"):
		brown.pressed.emit()
		check_eq(str(Profile.get_look().fleece), "dark_brown", "tapping it puts it on")
		check(brown.chosen, "and marks it chosen")
		var upper := stage.figure.get_node("Upper") as Sprite2D
		check(upper.texture.resource_path.contains("dark_brown"), "the stage's figure wears it")
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
