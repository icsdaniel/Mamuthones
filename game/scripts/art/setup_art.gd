class_name SetupArt
extends RefCounted
## The pictures of the first-launch and setup screens in pixel art (docs/art-style.md), baked by
## tools/art/pixel/setup_pics.py into res://art/px/setup/. Each one fits itself into the Rect2 it is
## given (centred, at the largest whole art scale that fits, never above the screen's art scale), so
## the UI only lays out a box. Use them from a Control's _draw(), or through SetupArtView.
##
##   SetupArt.headphones(ci, rect, lit := Color.WHITE)
##       headphones with bronze-rimmed cups, a small cowbell on a thong from the band, sound rising
##       from both cups in stepped arcs.
##   SetupArt.phone_in_hands(ci, rect, tilt := 0.0, left_pressed := false, right_pressed := false,
##                           arrow := 0, flash := 0.0)
##       the phone held in two hands, seen from the player's side. tilt: radians, > 0 = top edge toward
##       the player (the face foreshortens, the top edge widens), < 0 = away; about +-0.9 is the useful
##       range (nine baked steps). A pressed thumb lies on the glass with an ember ring; a raised one
##       hovers over its shadow. arrow: 1 = a gold arrow "tilt the top toward you", -1 = "away".
##       flash 0..1 warms the screen (a counted tilt).
##   SetupArt.frame_drum(ci, rect, hit := 0.0)
##       a Sardinian frame drum (tumbarinu) with a laced shell and its stick. hit 0..1 (set it to 1 on a
##       tap and let it decay) swells the head, lights it ember at the centre, ripples it and throws
##       ember sparks round the rim.

static var _tex := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := SetupCells.DIR + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


## The whole art scale that fits `art` into rect, capped at the base screen's scale (3 on 720 wide).
static func fit(rect: Rect2, art: Vector2i, cap := 3.0) -> float:
	var s := floorf(minf(rect.size.x / float(art.x), rect.size.y / float(art.y)))
	return clampf(s, 1.0, cap)


static func _place(ci: CanvasItem, rect: Rect2, name: String, art: Vector2i, px: float, modulate := Color.WHITE) -> Vector2:
	var t := tex(name)
	var sz := Vector2(art) * px
	var at := (rect.position + (rect.size - sz) * 0.5).floor()
	if t != null:
		RenderingServer.canvas_item_set_default_texture_filter(ci.get_canvas_item(), RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		ci.draw_texture_rect(t, Rect2(at, sz), false, modulate)
	return at


static func headphones(ci: CanvasItem, rect: Rect2, _lit := Color.WHITE) -> void:
	var px := fit(rect, SetupCells.HEADPHONES)
	_place(ci, rect, "headphones", SetupCells.HEADPHONES, px)


static func phone_in_hands(ci: CanvasItem, rect: Rect2, tilt := 0.0, left_pressed := false, right_pressed := false, arrow := 0, flash := 0.0) -> void:
	var art := SetupCells.PHONE
	var room := rect
	if arrow != 0:
		room = Rect2(rect.position + Vector2(0, rect.size.y * 0.18), rect.size * Vector2(1.0, 0.82))
	var px := fit(room, art)
	# the nearest baked tilt
	var best := 0
	for i in SetupCells.TILTS.size():
		if absf(SetupCells.TILTS[i] - tilt) < absf(SetupCells.TILTS[best] - tilt):
			best = i
	var name := "phone_%d_%d%d" % [best, int(left_pressed), int(right_pressed)]
	var at := _place(ci, room, name, art, px)
	if flash > 0.0:
		var st := tex("phone_screen_%d" % best)
		if st != null:
			ci.draw_texture_rect(st, Rect2(at, Vector2(art) * px), false, Color(1, 1, 1, clampf(flash, 0.0, 1.0) * 0.55))
	if arrow != 0:
		var an := "arrow_toward" if arrow > 0 else "arrow_away"
		var asz := Vector2(SetupCells.ARROW) * px
		var ap := Vector2(floorf(rect.get_center().x - asz.x * 0.5), maxf(rect.position.y, at.y - asz.y))
		var t := tex(an)
		if t != null:
			ci.draw_texture_rect(t, Rect2(ap.floor(), asz), false)


static func frame_drum(ci: CanvasItem, rect: Rect2, hit := 0.0) -> void:
	var px := fit(rect, SetupCells.DRUM)
	var k := clampi(int(round(clampf(hit, 0.0, 1.0) * float(SetupCells.DRUM_FRAMES - 1))), 0, SetupCells.DRUM_FRAMES - 1)
	_place(ci, rect, "drum_%d" % k, SetupCells.DRUM, px)
