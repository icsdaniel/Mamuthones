extends Screen
## The workshop, on the mobile kit: dress your own Mamuthone, the very figure that bobs beside the
## Issohadore on the play screen. One screen that fits, no scrolling.
##   top bar   back · Workshop · the mask close-up (or back to the whole figure)
##   stage     your pixel Mamuthone (LookStage) large on a stone plinth in the bonfire's light,
##             bobbing as it waits; it wears every choice at once, with a ring of its bells and a
##             dip. Tap it for the carved mask up close (the part being carved ringed in bronze).
##             On the carving pages your carving points sit in its corner.
##   pages     a segmented control over swipeable pages, each a row of picture swatches:
##               Mask       brow, eyes, nose, cheeks, mouth (part chips, then the four carvings)
##               Wood       finish and patina
##               Sheepskin  black or dark brown (the only real colours)
##               Straps     natural or dark leather (the bell straps and the gaiters)
##             A carving not open yet shows a lock and what opens it (the stop, or the points);
##             tapping it says both (Progression.mask_option_unlocked, MaskSpec.requirement).
## args: tab (optional: mask, wood, fleece, straps; "dress" = fleece), closeup (bool).

const PAGES := ["mask", "wood", "fleece", "straps"]
const PARTS := {"mask": ["brow", "eyes", "nose", "cheeks", "mouth"], "wood": ["finish", "patina"]}
const SWATCH_H := 204.0
const SWATCH_MASK_UNIT := 12.0

static var tab := "mask"
static var part := "brow"
static var wood_part := "finish"

var stage: LookStage
var pager: Pager
var _zoom: Button
var _points: PanelContainer
var _pages := {}


func build() -> void:
	var t := str(args.get("tab", tab))
	if t == "dress":
		t = "fleece"
	tab = t if t in PAGES else "mask"
	var page := UIKit.scaffold(self, false, UIKit.S3)
	_zoom = UIKit.icon_button("check", _toggle_closeup, tr("ws_closeup_hint"))
	_zoom.name = "Closeup"
	UIKit.top_bar(page.top, tr("ws_title"), on_back, "", _zoom)

	stage = LookStage.new()
	stage.name = "Stage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	stage.tapped.connect(_toggle_closeup)
	page.body.add_child(stage)
	_points_tile(stage)

	var items := []
	for id in PAGES:
		items.append([id, tr("ws_tab_" + id)])
	pager = UIKit.paged(page.body, items, PAGES.find(tab))
	pager.size_flags_vertical = Control.SIZE_FILL
	pager.custom_minimum_size.y = UIKit.TOUCH + UIKit.S2 + SWATCH_H
	for id in PAGES:
		# a hair of room at each side: at fractional screen scales the next page's first column
		# would otherwise show through the pager's edge
		var pg := pager.add_page(id.capitalize() + "Page", 0)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 3)
		m.add_theme_constant_override("margin_right", 3)
		m.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pg.add_child(m)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", UIKit.S2)
		m.add_child(inner)
		_pages[id] = inner
		_fill(id)
	pager.page_changed.connect(_on_page)
	stage.closeup = bool(args.get("closeup", false))
	_refresh_stage()
	_on_page(PAGES.find(tab))


# ---------------------------------------------------------------- the stage


func _points_tile(host: Control) -> void:
	_points = PanelContainer.new()
	_points.name = "Points"
	_points.theme_type_variation = UIKit.TILE
	_points.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points.position = Vector2.ZERO
	_points.custom_minimum_size.x = 216.0
	host.add_child(_points)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_points.add_child(v)
	var tag := UIKit.label(tr("ws_points_tag"), UIKit.OVERLINE, false)
	v.add_child(tag)
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
	var hp := ""
	if tab == "mask":
		hp = part
	stage.set_look(Profile.get_look(), hp)
	_zoom.icon = KitIcons.get_icon("figure" if stage.closeup else "zoom")


func _toggle_closeup() -> void:
	stage.closeup = not stage.closeup
	Sound.ui("tap")
	_refresh_stage()


func _on_page(i: int) -> void:
	tab = PAGES[clampi(i, 0, PAGES.size() - 1)]
	_points.visible = tab in PARTS
	_refresh_stage()


# ---------------------------------------------------------------- pages


func _fill(id: String) -> void:
	var box: VBoxContainer = _pages[id]
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	match id:
		"mask", "wood":
			_carving(box, id)
		"fleece":
			_dress(box, "fleece", MaskSpec.FLEECES, FigureLookCells.SWATCH_FLEECE)
		"straps":
			_dress(box, "straps", MaskSpec.STRAPS, FigureLookCells.SWATCH_STRAPS)


func _current_part(id: String) -> String:
	return part if id == "mask" else wood_part


## Part chips, then the part's four carvings as swatches of the mask.
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
	row.custom_minimum_size.y = SWATCH_H
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var look := Profile.get_look()
	var spec := MaskSpec.sanitize(look.get("mask", {}))
	var have_stop := Progression.highest_stop()
	var have_pts := Progression.carving_points()
	for o in MaskSpec.options(cur):
		var s := spec.duplicate()
		s[cur] = o
		var open := Progression.mask_option_unlocked(cur, o)
		var text := MaskSpec.name_of(o, I18n.locale())
		if not open:
			var req := MaskSpec.requirement(cur, o)
			text = tr("ws_lock_stop") % int(req.stop) if have_stop < int(req.stop) else tr("ws_lock_pts") % int(req.cost)
		var pic := MaskPixels.texture(s, SWATCH_MASK_UNIT, true, str(look.get("straps", "natural")), "")
		var sw := Swatch.make(o, pic, text, spec[cur] == o, not open, _carve.bind(id, cur))
		row.add_child(sw)


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
	_refresh_stage()
	stage.jingle()


## Two big swatches: the figure's own pixels in each colour.
func _dress(box: VBoxContainer, key: String, ids: Array, crop: Rect2i) -> void:
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", UIKit.S2)
	row.custom_minimum_size.y = SWATCH_H - 60.0
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var look := Profile.get_look()
	var current := str(look.get(key, ids[0]))
	for id in ids:
		var l := look.duplicate(true)
		l[key] = id
		var sw := Swatch.make(id, FigureLook.texture("body", l), tr("ws_%s_%s" % [key, id]), id == current, false,
			_dress_pick.bind(key), Rect2(crop))
		row.add_child(sw)
	var note := UIKit.label(tr("ws_%s_note" % key), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	note.name = "Note"
	note.add_theme_font_size_override("font_size", 28)
	box.add_child(note)


func _dress_pick(id: String, key: String) -> void:
	if str(Profile.get_look().get(key, "")) != id:
		Profile.set_look(key, id)
	Sound.ui("carve")
	UIKit.vibrate(15)
	_mark((_pages[key] as Control).find_child("Options", true, false), id)
	_refresh_stage()
	stage.jingle()
	# the other page's swatches show the figure in this colour too
	_fill("straps" if key == "fleece" else "fleece")


func _mark(row: Node, chosen: String) -> void:
	if row == null:
		return
	for c in row.get_children():
		if c is Swatch:
			(c as Swatch).set_state((c as Swatch).id == chosen, (c as Swatch).locked)
