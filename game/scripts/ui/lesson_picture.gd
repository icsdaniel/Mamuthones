class_name LessonPicture
extends Control
## A small animated picture of one lesson, drawn with the same LaneSkin as the play screen, so the
## player sees exactly what to look for: notes slide down to the line and the right button lights up
## (or the phone tilts, or the thumbs press) as they arrive. It sits on a navy board in the gold
## pixel frame; the thumbs and the phone are pixel art on the same grid (3 screen px to the art px).
##
## Topics: steps, lanes, bells, holds, still, full, swipes (the rope swipe, until it is replaced) and
## stomps: both thumbs come down together on the same step button on the music's strongest accent,
## and a heavy gold shock runs out under it.

const LOOP := 2.4

var topic := "steps"
var slam := false
var _t := 0.9   ## starts with the note on its way down, so the first frame already shows it


func _init() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t = fmod(_t + delta, LOOP)
	queue_redraw()


func _draw() -> void:
	var px := PixelFrame.px_for(self)
	var w := floorf(minf(size.x, 564.0) / px) * px
	var frame := Rect2(floorf((size.x - w) * 0.5 / px) * px, 0.0, w, floorf(size.y / px) * px)
	draw_rect(frame, PixelPalette.NAVY[0])
	var inset := float(PixelFrame.DEPTH) * px
	var area := frame.grow(-inset)
	var buttons_h := floorf(110.0 / px) * px
	var field := Rect2(area.position, Vector2(area.size.x, area.size.y - buttons_h))
	LaneSkin.draw_lanes(self, field, [0.0, 0.0, 0.0])
	LaneSkin.draw_hit_line(self, field, 0.0)
	var lanes := LaneSkin.lane_rects(field)
	var hit_y := LaneSkin.hit_line_y(field)
	var pps := (hit_y - field.position.y) / 1.2
	var arrive := 1.4
	var dt := arrive - _t
	var y := LaneSkin.note_y(field, dt, pps)
	var pressed := [false, false, false]
	var lit := absf(dt) < 0.18 or (topic == "holds" and dt < 0.0 and dt > -0.8)
	match topic:
		"steps":
			if dt > -0.05:
				LaneSkin.draw_step(self, lanes[1], y, false)
			pressed[1] = lit
		"lanes":
			for i in 3:
				var d := dt + (i - 1) * 0.4
				if d > -0.05:
					LaneSkin.draw_step(self, lanes[i], LaneSkin.note_y(field, d, pps), false)
				pressed[i] = absf(d) < 0.18
		"bells":
			if dt > -0.05:
				LaneSkin.draw_bell(self, field, y, true)
			if slam:
				pressed[0] = lit
				pressed[2] = lit
		"holds":
			var tail := LaneSkin.note_y(field, dt + 0.8, pps)
			if dt + 0.8 > 0.0:
				LaneSkin.draw_hold(self, lanes[1], minf(y, hit_y), tail, lit)
			pressed[1] = lit
		"still":
			LaneSkin.draw_rest(self, field, LaneSkin.note_y(field, dt + 0.6, pps), y)
		"swipes":
			if dt > -0.05:
				LaneSkin.draw_swipe(self, field, y, 1)
		"stomps":
			# the accented step: a call note, doubled so it reads heavier than a step
			if dt > -0.05:
				LaneSkin.draw_step(self, lanes[1], y, true)
				LaneSkin.draw_step(self, lanes[1], y - 7.0 * px, true, 0.55)
			pressed[1] = dt < 0.1 and dt > -0.35
		"full":
			if dt > -0.05:
				LaneSkin.draw_ring(self, field, lanes[0], y, true)
			pressed[0] = lit
			if slam:
				pressed[2] = lit
	var br := Rect2(area.position.x, field.end.y, area.size.x, buttons_h)
	var bw := floorf(br.size.x / 3.0 / px) * px
	var buttons: Array[Rect2] = []
	for i in 3:
		buttons.append(Rect2(br.position.x + bw * i + 2.0 * px, br.position.y + 2.0 * px, bw - 4.0 * px, buttons_h - 4.0 * px))
		LaneSkin.draw_button(self, buttons[i], i, "pressed" if pressed[i] else "idle")
	if topic == "stomps":
		_draw_stomp(buttons[1], dt, px)
	if lit and topic in ["bells", "full"] and not slam:
		_draw_tilt(Vector2(area.end.x - 26.0 * px, field.position.y + 30.0 * px), px, clampf(1.0 - absf(dt) / 0.18, 0.0, 1.0))
	if topic == "swipes" and absf(dt) < 0.35:
		var k := clampf((0.35 - dt) / 0.7, 0.0, 1.0)
		var fx := lerpf(br.position.x + 40.0, br.end.x - 40.0, k)
		_thumb(Vector2(fx, br.get_center().y), px, true, false)
	PixelFrame.draw(self, frame, px, "gold")


## Two thumbs come down on the same button together (from the lower left and lower right), land on
## the beat, and a heavy gold shock runs out under the button: stepped rings and a burst of grit.
func _draw_stomp(button: Rect2, dt: float, px: float) -> void:
	var c := button.get_center() - Vector2(0, button.size.y * 0.22)
	# before the hit the thumbs hover and close in; on it they press; then they lift away
	var down := dt < 0.1 and dt > -0.35
	var approach := clampf(1.0 - (dt - 0.1) / 0.5, 0.0, 1.0) if dt >= 0.1 else (1.0 if down else clampf(1.0 + (dt + 0.35) / 0.4, 0.0, 1.0))
	var spread := lerpf(26.0, 7.0, approach) * px
	var lift := 0.0 if down else lerpf(14.0, 4.0, approach) * px
	if dt < 0.0 and dt > -0.45:
		var k := clampf(-dt / 0.45, 0.0, 1.0)
		_shock(Vector2(c.x, button.end.y - px * 2.0), button.size.x, k, px)
	_thumb(c + Vector2(-spread, lift), px, down, false)
	_thumb(c + Vector2(spread, lift), px, down, true)


## The shock: flat gold rings on the ground line under the button, spreading out and dimming, with
## gold grit thrown up either side; everything on the art grid.
func _shock(at: Vector2, width: float, k: float, px: float) -> void:
	var cols: Array[Color] = [PixelPalette.GOLD[5], PixelPalette.GOLD[4], PixelPalette.GOLD[3], PixelPalette.GOLD[2]]
	for ring in 2:
		var q := clampf(k - float(ring) * 0.22, 0.0, 1.0)
		if q <= 0.0:
			continue
		var rx := (width * 0.45 + q * width * 0.9)
		var ry := rx * 0.16
		var col := cols[mini(3, int(q * 4.0))]
		var steps := int(rx / px)
		for s in range(-steps, steps + 1):
			var x := float(s) * px
			var yy := ry * sqrt(maxf(0.0, 1.0 - pow(x / rx, 2)))
			var p := (at + Vector2(x, -yy) / 1.0)
			p = (p / px).floor() * px
			if absi(s) % 4 != 3:
				draw_rect(Rect2(p, Vector2(px, px) * (2.0 if q < 0.5 else 1.0)), col)
	# a heavy bar of light under the button at the moment of the hit
	if k < 0.3:
		var bar := Rect2(at.x - width * 0.5, at.y - px, width, px * 2.0)
		draw_rect(Rect2((bar.position / px).floor() * px, bar.size), PixelPalette.K[0])
		draw_rect(Rect2((bar.position / px).floor() * px + Vector2(0, px), Vector2(bar.size.x, px)), PixelPalette.GOLD[5])
	# grit thrown up and out
	for i in 10:
		var side := -1.0 if i % 2 == 0 else 1.0
		var a := 0.3 + 0.12 * float(i / 2)
		var d := k * (40.0 + 12.0 * float(i % 3)) * px / 3.0
		var p := at + Vector2(side * (width * 0.3 + cos(a) * d * 3.0), -sin(a) * d * 2.2 + k * k * 30.0)
		draw_rect(Rect2((p / px).floor() * px, Vector2(px, px)), cols[mini(3, int(k * 4.0))])


## A pixel thumb (SetupArt's sprite) with its tip at `tip`; `right` mirrors it for the right hand.
func _thumb(tip: Vector2, px: float, pressed: bool, right: bool) -> void:
	var t := SetupArt.tex("thumb_down" if pressed else "thumb_up")
	if t == null:
		return
	var sz := Vector2(SetupCells.THUMB) * px
	var at := ((tip - Vector2(sz.x * 0.5, 4.0 * px)) / px).floor() * px
	# lean the thumbs in from their own side, as hands holding the phone would
	var lean := Vector2(-3.0 * px if not right else 3.0 * px, 0)
	draw_set_transform(at + lean + (Vector2(sz.x, 0) if right else Vector2.ZERO), 0.0, Vector2(-1.0 if right else 1.0, 1.0))
	draw_texture_rect(t, Rect2(Vector2.ZERO, sz), false)
	draw_set_transform(Vector2.ZERO)


## A small pixel phone beside the lanes, its top tipping toward the player (the face foreshortens
## and the top edge widens), with a gold arc over it.
func _draw_tilt(at: Vector2, px: float, k: float) -> void:
	var h := roundf(lerpf(30.0, 22.0, k))
	var bot_w := 16.0
	var top_w := roundf(lerpf(16.0, 20.0, k))
	var o := (at / px).floor() * px
	for row in int(h):
		var u := float(row) / (h - 1.0)
		var rw := roundf(lerpf(top_w, bot_w, u))
		var x0 := o.x - floorf(rw * 0.5) * px
		var y := o.y + (float(row) - h * 0.5) * px
		draw_rect(Rect2(x0 - px, y, (rw + 2.0) * px, px), PixelPalette.K[0])
		var inner := row > 1 and row < int(h) - 3
		draw_rect(Rect2(x0, y, rw * px, px), PixelPalette.NAVY[1] if inner else PixelPalette.K[1])
		if inner:
			draw_rect(Rect2(x0 + px, y, px, px), PixelPalette.K[1])
			draw_rect(Rect2(x0 + (rw - 2.0) * px, y, px, px), PixelPalette.K[1])
			if row == int(h * 0.75):
				draw_rect(Rect2(x0 + 2.0 * px, y, (rw - 4.0) * px, px), PixelPalette.GOLD[4])
	draw_rect(Rect2(o.x - floorf(top_w * 0.5) * px - px, o.y - (h * 0.5 + 1.0) * px, (top_w + 2.0) * px, px), PixelPalette.K[0])
	# the gold arc: "tip the top toward you"
	for i in 13:
		var a := lerpf(-2.4, -0.7, float(i) / 12.0)
		var p := o + Vector2(cos(a), sin(a)) * (h * 0.5 + 8.0) * px
		p = (p / px).floor() * px
		draw_rect(Rect2(p - Vector2(px, px), Vector2(px, px) * 3.0), PixelPalette.K[0])
		draw_rect(Rect2(p, Vector2(px, px)), PixelPalette.GOLD[4])
	var tip := o + Vector2(cos(-0.7), sin(-0.7)) * (h * 0.5 + 8.0) * px
	tip = (tip / px).floor() * px
	for d in 3:
		draw_rect(Rect2(tip + Vector2(-float(d), float(d)) * px, Vector2(px * (1.0 + 2.0 * float(d)), px)), PixelPalette.GOLD[4])
