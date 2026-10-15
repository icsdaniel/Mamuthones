extends TestCase
## The play screen's world picture (PxArt.world_density): a whole number of screen px per texel in
## the sharp setting, one texel per art px in the fast one, and the note pictures made before the song
## are the only ones (StreetSkin.sealed).


func test_sharp_density_is_whole_screen_pixels() -> void:
	for w: int in [720, 1080, 1170, 1179, 1290, 1440]:
		var device := Vector2(w, w * 2.17)
		var d := PxArt.world_density(device, Vector2(720.0, device.y * 720.0 / w), "sharp")
		var px: float = d.px
		check_eq(px, roundf(px), "%d px wide: a texel is whole screen px" % w)
		check(device.x / px >= PxArt.MIN_TEXELS - 0.01, "%d px wide: at least %d texels across" % [w, PxArt.MIN_TEXELS])
		check_near(float(d.texel) * w / 720.0, px, 0.0001, "%d px wide: texel in base px matches the screen px" % w)
	var d720 := PxArt.world_density(Vector2(720, 1440), Vector2(720, 1440), "sharp")
	check_eq(d720.texel, PxArt.PX, "720 wide: one texel per art px, as the art grid")
	var d1080 := PxArt.world_density(Vector2(1080, 2400), Vector2(720, 1600), "sharp")
	check_eq(int(1080 / float(d1080.px)), 360, "1080 wide: 360 texels across")


func test_fast_density_is_the_art_grid() -> void:
	var d := PxArt.world_density(Vector2(1290, 2796), Vector2(720, 1560.56), "fast")
	check_eq(d.texel, PxArt.PX, "fast: one texel per art px")


func test_sealed_pictures_are_not_shrunk_mid_song() -> void:
	var was_texel := PxArt.texel
	StreetSkin.clear_sized()
	var a := StreetSkin.ai_tex("note_step", Vector2i(20, 12))
	if a == null:
		return   # no pictures in this build
	StreetSkin.sealed = true
	var before := StreetSkin.shrunk
	var b := StreetSkin.ai_tex("note_step", Vector2i(23, 13))
	check_eq(StreetSkin.shrunk, before, "a new size after the song's pictures are made shrinks nothing")
	check(b == a, "... and draws the nearest size made")
	StreetSkin.clear_sized()
	check(not StreetSkin.sealed, "clearing the pictures unseals them")
	PxArt.texel = was_texel
