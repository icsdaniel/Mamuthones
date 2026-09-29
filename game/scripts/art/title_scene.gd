class_name TitleScene
extends Control
## PLACEHOLDER for the title screen's illustrated scene (the play-field artist's TitleScene replaces this
## file at merge; keep the API): a banded night sky with stars, the hills and the village in silhouette,
## and the bonfire's glow rising from below, pulsing on the beat. Drawn on the 3 px art grid.

var bpm := 76.0
var reduced_motion := false
var _fleece := "black"
var _t := 0.0

const PX := 3.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_look(fleece: String) -> void:
	_fleece = fleece
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _band(y0: float, y1: float, c: Color) -> void:
	draw_rect(Rect2(0, roundf(y0 / PX) * PX, size.x, roundf((y1 - y0) / PX) * PX + PX), c)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var night := PixelPalette.NIGHT
	var bands := [night[0], night[1], night[2], night[3], night[4]]
	for i in bands.size():
		_band(h * 0.12 * i, h * 0.12 * (i + 1) + PX, bands[i])
	_band(h * 0.6, h, night[4])
	# stars, placed by rule
	for i in 60:
		var x := fposmod(float(i) * 97.3 + 13.0, w)
		var y := fposmod(float(i) * 53.7 + 7.0, h * 0.5)
		var tw := 1.0 if reduced_motion else 0.6 + 0.4 * sin(_t * 1.3 + float(i))
		draw_rect(Rect2(roundf(x / PX) * PX, roundf(y / PX) * PX, PX, PX), Color(PixelPalette.STAR[i % 2], tw))
	# hills and the village
	var hill := PixelPalette.HILL
	for k in 3:
		var base := h * (0.62 + 0.07 * k)
		for x in range(0, int(w / PX) + 1):
			var xx := float(x) * PX
			var top := base - (26.0 - 6.0 * k) * PX * (0.5 + 0.5 * sin(xx * (0.006 + 0.003 * k) + float(k) * 2.0))
			draw_rect(Rect2(xx, roundf(top / PX) * PX, PX, h - top), hill[k])
	var stone := PixelPalette.STONE
	for i in 14:
		var bx := roundf((float(i) * 61.0 + 20.0) / PX) * PX
		var bw := 30.0 + fposmod(float(i) * 23.0, 36.0)
		var bh := 36.0 + fposmod(float(i) * 41.0, 60.0)
		var by := h * 0.8 - bh
		draw_rect(Rect2(bx, roundf(by / PX) * PX, roundf(bw / PX) * PX, h), stone[1])
		draw_rect(Rect2(bx + PX * 3, roundf((by + 12) / PX) * PX, PX * 2, PX * 3), PixelPalette.FIRE[5])
	# the bonfire's glow from below, beating
	var beat := 0.0 if reduced_motion else pow(1.0 - fposmod(_t * bpm / 60.0, 1.0), 3.0)
	var fire := PixelPalette.FIRE
	var cx := w * 0.5
	for i in 4:
		var r := (h * 0.34) * (1.0 - 0.2 * i) * (1.0 + 0.05 * beat)
		var c: Color = [fire[1], fire[2], fire[3], fire[5]][i]
		draw_rect(Rect2(roundf((cx - r) / PX) * PX, roundf((h - r * 0.5) / PX) * PX, roundf(2.0 * r / PX) * PX, h), Color(c, 0.35 + 0.1 * i))
