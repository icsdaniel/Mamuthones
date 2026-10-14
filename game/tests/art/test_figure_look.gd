extends TestCase
## The workshop's choices reach the play screen's pixel Mamuthone: each fleece and strap is its own
## baked picture, the carved mask is stamped on the face only, and the play street passes the look on.


func test_look_reaches_the_pixel_mamuthone() -> void:
	var base := {"mask": MaskSpec.default(), "fleece": "black", "straps": "natural"}
	var black := FigureLook.texture("body", base)
	var brown := FigureLook.texture("body", {"mask": MaskSpec.default(), "fleece": "dark_brown", "straps": "natural"})
	var dark := FigureLook.texture("body", {"mask": MaskSpec.default(), "fleece": "black", "straps": "dark"})
	check(black != null and brown != null and dark != null, "every fleece and strap has its picture")
	check(black.resource_path != brown.resource_path and black.resource_path != dark.resource_path, "fleece and straps change the body")
	var carved := MaskSpec.default()
	carved["brow"] = "knotted"
	carved["finish"] = "dark_walnut"
	var h0 := FigureLook.texture("head", base).get_image()
	var h1 := FigureLook.texture("head", {"mask": carved, "fleece": "black", "straps": "natural"}).get_image()
	var face := FigureLookCells.FACE
	var differ := 0
	var outside := 0
	for y in h0.get_height():
		for x in h0.get_width():
			if h0.get_pixel(x, y) != h1.get_pixel(x, y):
				if face.has_point(Vector2i(x, y)):
					differ += 1
				else:
					outside += 1
	check(differ > 20, "the carving shows on the figure's face (%d px)" % differ)
	check_eq(outside, 0, "the carving stays on the face")
	check(FigureLook.texture("head", base) == FigureLook.texture("head", base), "the stamped head is cached")

	var fig := PixelFigure.new("mamuthone")
	tree.root.add_child(fig)
	fig.set_look(base)
	var upper := fig.get_node("Upper") as Sprite2D
	check(upper.texture == black, "the figure wears the look")
	fig.set_look({"mask": carved, "fleece": "dark_brown", "straps": "dark"})
	check(upper.texture.resource_path.ends_with("dark_brown_dark.png"), "and changes with it")
	fig.queue_free()

	var street := StreetBackdrop.new()
	street.set_look(carved, "dark_brown", "dark")
	street.size = Vector2(720, 1440)
	tree.root.add_child(street)
	await tree.process_frame
	var pup: PixelFigure = null
	for p in street.find_children("*", "PixelFigure", true, false):
		if (p as PixelFigure).figure == "mamuthone":
			pup = p
	if check(pup != null, "the street has its Mamuthone"):
		var t := (pup.get_node("Upper") as Sprite2D).texture
		check(t != null and t.resource_path.ends_with("dark_brown_dark.png"), "the play street's Mamuthone wears the look")
	street.queue_free()
	await tree.process_frame
