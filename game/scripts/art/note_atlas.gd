class_name NoteAtlas
extends Node
## The pixel look's note sheet. Drawing a note in full (a faceted solid, its shading, the pintadera's
## teeth) every frame cost most of a frame on a dense chart, so each kind is painted once here, by the
## same StreetSkin code, at a ladder of sizes down the road, into one small picture at one pixel per
## art pixel. Notes are then stamped from it: one textured rectangle each, whatever their number.
##
## A note's look depends only on how far down the road it is (its size and how flat it lies), so a
## sheet row per size covers the road; the nearest size is stretched by a few percent to fit.

const KINDS := ["step", "off", "call", "heal", "hold", "stomp", "knot"]
const STEP := 3.0               ## sheet px a cell grows by from one row to the next (a note is stretched by under 1 px)
const CELL := Vector2(1.08, 0.78)  ## a cell's size in lane widths at its size (a stomp's disc fits)
const REACH := 1.3             ## the sheet's biggest note: this times a note's size on the hit line

var lanes: LaneView
var _vp: SubViewport
var _painter: _Painter
var _ys: PackedFloat32Array = []      ## each row's depth on the road
var _lws: PackedFloat32Array = []     ## ... its lane width on screen
var _rows: Array[Rect2] = []          ## each row's cell (sheet pixels): its size, and y of its row
var _key := Vector4.ZERO              ## the layout the sheet was painted for
var _ready_frame := -1
var _n := 0                           ## rows
var _copied := false                  ## the painted sheet has been copied (or tried)
var _tex: Texture2D                   ## the sheet: the painting viewport's, then a kept copy

## The last sheet painted, kept for the next song with the same layout (painting takes a moment).
static var _kept := {}


func _init(p_lanes: LaneView) -> void:
	lanes = p_lanes
	name = "NoteAtlas"


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.name = "Sheet"
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_painter = _Painter.new()
	_painter.atlas = self
	_vp.add_child(_painter)
	add_child(_vp)


## True once the sheet is painted for the lanes' current layout; repaints it when that has changed.
func ready_for(lv: LaneView) -> bool:
	var f := lv.field_rect()
	var key := Vector4(f.size.x, f.size.y, LaneSkin.hit_line_y(Rect2(Vector2.ZERO, f.size)), lv.project(Vector2.ZERO).y)
	if key != _key:
		_key = key
		if _kept.get("key") == key:
			_ys = _kept.ys; _lws = _kept.lws; _rows = _kept.rows; _n = _kept.n; _tex = _kept.tex
			_ready_frame = 0
			return true
		_layout(lv)
		return false
	return is_ready()


## True once the sheet has been painted (it takes a frame after a layout).
func is_ready() -> bool:
	if _ready_frame < 0 or Engine.get_process_frames() <= _ready_frame:
		return false
	if _tex == _vp.get_texture() and not _copied:
		# keep a copy, so the next song starts without painting it again (tried once: a renderer
		# that cannot read it back, like the headless one, keeps the viewport's)
		_copied = true
		var img := _tex.get_image()
		if img != null and not img.is_empty():
			_tex = ImageTexture.create_from_image(img)
			_kept = {"key": _key, "ys": _ys, "lws": _lws, "rows": _rows, "n": _n, "tex": _tex}
	return true


func _layout(lv: LaneView) -> void:
	var field := lv.field_rect()
	field.position = Vector2.ZERO
	var lane := field.size.x / 3.0
	var hl := LaneSkin.hit_line_y(field)
	var y0 := 0.0
	# past the hit line the road widens fast: a note there is a missed one fading out, drawn in full
	var lw0 := maxf(2.0, lv.road_scale(y0) * lane)
	var lw1 := maxf(lw0 + 1.0, lv.road_scale(hl) * lane * REACH)
	var y1 := hl + lane
	_ys = PackedFloat32Array()   # fresh: the kept sheet may hold the old ones
	_lws = PackedFloat32Array()
	_rows = []
	var px := PxArt.PX
	var top := 0.0
	var width := 0.0
	# just enough rows that the nearest is never more than STEP / 2 sheet px off: few, as the road
	# narrows little, so the sheet is small and quick to paint
	_n = clampi(ceili((lw1 - lw0) * CELL.x / px / STEP) + 1, 2, 64)
	for i in _n:
		# sizes in equal ratios: the far notes change little, the near ones a lot
		var lw := lw0 * pow(lw1 / lw0, float(i) / (_n - 1))
		var y := _depth_for(lv, lane, lw, y0, y1)
		var cell := (lw * CELL / px).ceil() + Vector2(4.0, 4.0)
		_ys.append(y)
		_lws.append(lw)
		_rows.append(Rect2(Vector2(0.0, top), cell))
		top += cell.y
		width = maxf(width, cell.x * KINDS.size())
	_vp.size = Vector2i(ceili(width), ceili(top))
	_vp.canvas_transform = Transform2D().scaled(Vector2.ONE / px)
	_painter.view = lv
	_painter.field = field
	_painter.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_tex = _vp.get_texture()
	_copied = false
	_ready_frame = Engine.get_process_frames() + 1


## The depth on the road where a lane is lw wide.
func _depth_for(lv: LaneView, lane: float, lw: float, a: float, b: float) -> float:
	for _i in 30:
		var m := (a + b) * 0.5
		if lv.road_scale(m) * lane < lw:
			a = m
		else:
			b = m
	return (a + b) * 0.5


## Whether the sheet holds notes as big as lw (else the note is drawn in full).
func covers(lw: float) -> bool:
	return _n > 0 and lw <= _lws[_n - 1] * 1.02


## Draws the note `key` centred at c on lv, lw its lane width there, at opacity a.
func stamp(lv: LaneView, key: String, c: Vector2, lw: float, a: float) -> void:
	var col := KINDS.find(key)
	if col < 0:
		return
	var i := clampi(int(roundf(log(lw / _lws[0]) / log(_lws[_n - 1] / _lws[0]) * (_n - 1))), 0, _n - 1)
	var row := _rows[i]
	var src := Rect2(row.size.x * col, row.position.y, row.size.x, row.size.y)
	var s := lw / _lws[i] * PxArt.PX
	var dst := Rect2(c - row.size * 0.5 * s, row.size * s)
	lv.draw_texture_rect_region(_tex, dst, src, Color(1.0, 1.0, 1.0, a))


## Paints every kind at every size, each centred in its cell, through StreetSkin's own drawing.
## StreetSkin calls project() and road_scale() on it as it would on the lanes.
class _Painter extends Node2D:
	var atlas: NoteAtlas
	var view: LaneView
	var field: Rect2
	var _origin := Vector2.ZERO        ## where the note being painted sits on the lanes
	var _centre := Vector2.ZERO        ## ... and in the sheet (base px)

	func project(p: Vector2) -> Vector2:
		return view.project(p) - _origin + _centre

	func road_scale(y: float) -> float:
		return view.road_scale(y)

	func _draw() -> void:
		if view == null:
			return
		var px := PxArt.PX
		var cx := field.size.x * 0.5
		StreetSkin.paint_glow = false
		var near := StreetSkin._near
		StreetSkin._near = 0.0
		for i in atlas._ys.size():
			var y: float = atlas._ys[i]
			var row: Rect2 = atlas._rows[i]
			_origin = view.project(Vector2(cx, y))
			for col in NoteAtlas.KINDS.size():
				_centre = (Vector2(row.size.x * col, row.position.y) + row.size * 0.5) * px
				match str(NoteAtlas.KINDS[col]):
					"step":
						StreetSkin.step(self, field, cx, y, 1.0)
					"off":
						StreetSkin.step(self, field, cx, y, 1.0, true)
					"call":
						StreetSkin.step(self, field, cx, y, 1.0, true, true)
					"heal":
						StreetSkin.heal(self, field, cx, y, 1.0)
					"hold":
						StreetSkin.hold_head(self, field, cx, y, 1.0, false)
					"stomp":
						StreetSkin.stomp(self, field, cx, y, 1.0)
					"knot":
						StreetSkin._knot(self, field, cx, y, 1.0)
		StreetSkin.paint_glow = true
		StreetSkin._near = near
