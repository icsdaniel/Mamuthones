@tool
class_name SetupArtView
extends Control
## A Control that shows one SetupArt picture fitted to its size. Set the properties and it redraws.
##   kind           "headphones" | "phone" | "drum"
##   tilt           phone: radians, > 0 = top edge toward the player
##   left_pressed   phone: left thumb down on the glass
##   right_pressed  phone: right thumb down on the glass
##   arrow          phone: 1 = "tilt the top toward you", -1 = "away", 0 = none
##   flash          phone: 0..1 warms the screen (a counted tilt)
##   hit            drum: 0..1; call strike() on a tap and it decays by itself (DRUM_DECAY per second)

const DRUM_DECAY := 4.0

@export_enum("headphones", "phone", "drum") var kind := "headphones":
	set(v):
		kind = v
		queue_redraw()
@export_range(-1.1, 1.1) var tilt := 0.0:
	set(v):
		tilt = v
		queue_redraw()
@export var left_pressed := false:
	set(v):
		left_pressed = v
		queue_redraw()
@export var right_pressed := false:
	set(v):
		right_pressed = v
		queue_redraw()
@export_range(-1, 1) var arrow := 0:
	set(v):
		arrow = v
		queue_redraw()
@export_range(0.0, 1.0) var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
@export_range(0.0, 1.0) var hit := 0.0:
	set(v):
		hit = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Drum: a tap. The head pulses and decays over about a quarter of a second.
func strike(amount := 1.0) -> void:
	hit = maxf(hit, clampf(amount, 0.0, 1.0))


func _process(delta: float) -> void:
	if hit > 0.0:
		hit = maxf(0.0, hit - delta * DRUM_DECAY)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	match kind:
		"phone":
			SetupArt.phone_in_hands(self, r, tilt, left_pressed, right_pressed, arrow, flash)
		"drum":
			SetupArt.frame_drum(self, r, hit)
		_:
			SetupArt.headphones(self, r)
