extends Screen
## The workshop, on the mobile kit: dress your own Mamuthone, the very figure that bobs beside the
## Issohadore on the play screen. One screen that fits, no scrolling.
##   top bar   back · Workshop
##   stage     LookStage: on the Mask and Wood pages the carved mask up close, the part being carved
##             ringed in bronze; on the Dress page your whole pixel Mamuthone on a stone plinth in the
##             bonfire's light, bobbing as it waits. Every choice is worn at once, with a ring of the
##             bells and a dip. A labelled toggle (top right) or a tap on the stage switches view.
##             On the carving pages your carving points sit in its top-left corner.
##   pages     a segmented control over swipeable pages:
##               Mask   brow, eyes, nose, cheeks, mouth: part chips, then four swatches, each the
##                      mask cropped to that part, large
##               Wood   finish and patina: the whole mask
##               Dress  sheepskin (dark brown, black: the only real colours) and leather (natural,
##                      dark: the bell straps and the gaiters), the figure's own pixels
##             A carving not open yet shows dimmed, a lock in its corner and what opens it (the stop,
##             or the points); tapping it says both (Progression.mask_option_unlocked).
## args: tab (optional: mask, wood, dress; "fleece" and "straps" open dress), part (optional: the mask
## part to carve), closeup (bool: start in the other view than the page's own).

const PAGES := ["mask", "wood", "dress"]
const PARTS := {"mask": ["brow", "eyes", "nose", "cheeks", "mouth"], "wood": ["finish", "patina"]}
const SWATCH_H := 252.0
## The mask swatches: rendered at this unit, the carving pages crop each to its part (x, y: the mask
## v range; z: the half width, from the nose) and show it as large as fits, so four carvings of one
## part differ at a glance.
const SWATCH_MASK_UNIT := 12.0
const PART_V := {"brow": Vector3(-1.3, -0.3, 0.95), "eyes": Vector3(-0.8, 0.15, 1.0), "nose": Vector3(-0.45, 1.0, 0.55),
	"cheeks": Vector3(-0.25, 1.2, 1.08), "mouth": Vector3(0.7, 1.75, 0.75)}
## The mask swatches are shown as if held to the fire (the dark finishes read on a dark tile).
const SWATCH_LIGHT := Color(1.45, 1.35, 1.25)
const CROP_ASPECT := 0.85   ## a part crop's least height, to its width

static var tab := "mask"
static var part := "brow"
static var wood_part := "finish"

var stage: LookStage
var pager: Pager
var _points: PanelContainer
var _pages := {}


func build() -> void:
	var t := str(args.get("tab", tab))
	if t in ["fleece", "straps"]:
		t = "dress"
	tab = t if t in PAGES else "mask"
	if str(args.get("part", "")) in PARTS.mask:
		part = str(args.part)
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.top_bar(page.top, tr("ws_title"), on_back)

	stage = LookStage.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	stage.toggle_texts = [tr("ws_view_mask"), tr("ws_view_figure")]
	stage.tapped.connect(_refresh_stage)
	page.body.add_child(stage)
	_points_tile(stage)

	var items := []
	for id in PAGES:
		items.append([id, tr("ws_tab_" + id)])
	pager = UIKit.paged(page.body, items, PAGES.find(tab))
	pager.size_flags_vertical = Control.SIZE_FILL
	pager.custom_minimum_size.y = UIKit.TOUCH + UIKit.S2 + SWATCH_H
	for id in PAGES:
		_pages[id] = pager.add_page(id.capitalize() + "Page", UIKit.S2)
		_fill(id)
	pager.page_changed.connect(_on_page)
	_on_page(PAGES.find(tab), false)
	if bool(args.get("closeup", false)):
		stage.set_closeup(not stage.closeup, false)
		_refresh_stage()


# ---------------------------------------------------------------- the stage


## Your carving points, in the stage's top-left corner (the carving pages only).
func _points_tile(host: Control) -> void:
	_points = PanelContainer.new()
	_points.name = "Points"
	_points.theme_type_variation = UIKit.TILE
	_points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.position = Vector2.ZERO
	host.add_child(_points)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_points.add_child(v)
	v.add_child(UIKit.label(tr("ws_points_tag"), UIKit.OVERLINE, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S1)
	v.add_child(row)
	var val := UIKit.label(str(Progression.carving_points()), UIKit.VALUE, false)
	val.name = "PointsValue"
	val.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI)
	row.add_child(val)
	var unit := UIKit.label(tr("ws_points_unit"), UIKit.CAPTION, false)
	unit.add_theme_font_size_override("font_size", 28)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit)
	_points.reset_size()


func _refresh_stage() -> void:
	stage.set_look(Profile.get_look(), part if tab == "mask" else "")


## Each page frames the stage its own way: the carving pages the mask up close, the dress page the
## whole figure.
func _on_page(i: int, animate := true) -> void:
	tab = PAGES[clampi(i, 0, PAGES.size() - 1)]
	_points.visible = tab in PARTS
	stage.set_closeup(tab != "dress", animate)
	_refresh_stage()


# ---------------------------------------------------------------- pages


func _fill(id: String) -> void:
	var box: VBoxContainer = _pages[id]
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	if id == "dress":
		_dress(box)
	else:
		_carving(box, id)


func _current_part(id: String) -> String:
	return part if id == "mask" else wood_part


## Part chips, then the part's four carvings as swatches.
func _carving(box: VBoxContainer, id: String) -> void:
	var chips := HBoxContainer.new()
	chips.name = "Parts"
	chips.add_theme_constant_override("separation", UIKit.S1)
	box.add_child(chips)
	var cur := _current_part(id)
	for p in PARTS[id]:
		var b := Button.new()
		b.name = "Part_" + p
		b.text = MaskSpec.name_of(p, I18n.locale())
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(UIKit.TOUCH, UIKit.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		_style_chip(b, p == cur)
		b.pressed.connect(_pick_part.bind(id, p))
		UIKit.juice(b)
		UIKit.fit_text(b)
		chips.add_child(b)
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", UIKit.S2)
	row.custom_minimum_size.y = SWATCH_H - UIKit.TOUCH - UIKit.S2
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var look := Profile.get_look()
	var spec := MaskSpec.sanitize(look.get("mask", {}))
	var have_stop := Progression.highest_stop()
	for o in MaskSpec.options(cur):
		var s := spec.duplicate()
		s[cur] = o
		var open := Progression.mask_option_unlocked(cur, o)
		var text := MaskSpec.name_of(o, I18n.locale())
		if not open:
			var req := MaskSpec.requirement(cur, o)
			text = tr("ws_lock_stop") % int(req.stop) if have_stop < int(req.stop) else tr("ws_lock_pts") % int(req.cost)
		var cropped := PART_V.has(cur)
		var pic := MaskPixels.texture(s, SWATCH_MASK_UNIT, not cropped, str(look.get("straps", MaskSpec.STRAPS[0])), "")
		var sw := Swatch.make(o, pic, text, spec[cur] == o, not open, _carve.bind(id, cur), _part_crop(cur) if cropped else Rect2())
		if cropped:
			sw.pic.step = 1
			sw.light = SWATCH_LIGHT
		row.add_child(sw)


## The part's crop of a swatch mask (MaskPixels at SWATCH_MASK_UNIT), in its pixels.
static func _part_crop(p: String) -> Rect2:
	var v: Vector3 = PART_V[p]
	var u := SWATCH_MASK_UNIT
	var x0 := floorf((MaskPixels.HALF_W - v.z) * u)
	var x1 := ceilf((MaskPixels.HALF_W + v.z) * u)
	# no flatter than CROP_ASPECT (the tile's own shape), so a wide part still fills its tile
	var mid := ((v.x + v.y) * 0.5 - MaskPixels.TOP) * u
	var half := maxf((v.y - v.x) * u, (x1 - x0) * CROP_ASPECT) * 0.5
	var y0 := maxf(floorf(mid - half), 0.0)
	var y1 := ceilf(mid + half)
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func _style_chip(b: Button, on: bool) -> void:
	var sb := PxStyle.make(WoodcutTheme.C_RAISED_HI if on else Color.TRANSPARENT,
		WoodcutTheme.C_BRONZE if on else Color(WoodcutTheme.C_STROKE, 0.8), WoodcutTheme.R_PILL, Vector4(12, 6, 12, 6))
	if on:
		sb.highlight = WoodcutTheme.C_STROKE_HI
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var ink: Color = WoodcutTheme.C_BRONZE_HI if on else WoodcutTheme.C_TEXT_2
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_font_size_override("font_size", 28)


func _pick_part(id: String, p: String) -> void:
	if id == "mask":
		part = p
	else:
		wood_part = p
	Sound.ui("tap")
	_fill(id)
	_refresh_stage()


func _carve(option: String, id: String, p: String) -> void:
	if not Progression.mask_option_unlocked(p, option):
		var req := MaskSpec.requirement(p, option)
		Sound.ui("back")
		UIKit.toast(self, tr("ws_locked_toast") % [int(req.stop), int(req.cost), Progression.carving_points()])
		return
	var spec := MaskSpec.sanitize(Profile.get_look().get("mask", {}))
	if spec[p] != option:
		spec[p] = option
		Profile.set_look("mask", spec)
	Sound.ui("carve")
	UIKit.vibrate(15)
	_mark((_pages[id] as Control).find_child("Options", true, false), option)
	# the other carving page's swatches show the whole mask (or its parts) as it is now
	_fill("wood" if id == "mask" else "mask")
	_refresh_stage()
	stage.jingle()


## Two groups of two swatches: the sheepskin and the leather, the figure's own pixels in each.
func _dress(box: VBoxContainer) -> void:
	var groups := HBoxContainer.new()
	groups.name = "Groups"
	groups.add_theme_constant_override("separation", UIKit.S2)
	groups.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(groups)
	var look := FigureLook.normalize(Profile.get_look())
	for g in [["fleece", MaskSpec.FLEECES, FigureLookCells.SWATCH_FLEECE], ["straps", MaskSpec.STRAPS, FigureLookCells.SWATCH_STRAPS]]:
		var key: String = g[0]
		var col := VBoxContainer.new()
		col.name = "Group_" + key
		col.add_theme_constant_override("separation", UIKit.S1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		groups.add_child(col)
		col.add_child(UIKit.overline(tr("ws_group_" + ("fleece" if key == "fleece" else "leather"))))
		var row := HBoxContainer.new()
		row.name = "Options_" + key
		row.add_theme_constant_override("separation", UIKit.S2)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(row)
		var ids: Array = g[1]
		var current := str(look.get(key, ids[0]))
		for id in ids:
			var l := look.duplicate(true)
			l[key] = id
			var sw := Swatch.make(id, FigureLook.texture("body", l), tr("ws_%s_%s" % [key, id]), id == current, false,
				_dress_pick.bind(key), Rect2(g[2]))
			row.add_child(sw)


func _dress_pick(id: String, key: String) -> void:
	if str(Profile.get_look().get(key, "")) != id:
		Profile.set_look(key, id)
	Sound.ui("carve")
	UIKit.vibrate(15)
	# the swatches are drawn in the look as it is: the other group's pictures change too
	_fill("dress")
	_refresh_stage()
	stage.jingle()


func _mark(row: Node, chosen: String) -> void:
	if row == null:
		return
	for c in row.get_children():
		if c is Swatch:
			(c as Swatch).set_state((c as Swatch).id == chosen, (c as Swatch).locked)
