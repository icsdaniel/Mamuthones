extends Screen
## First launch, step 2: suggest headphones. One tap on to the title, where the tutorial and the
## calibration wait as menu entries.


func build() -> void:
	var box := UIKit.column(self, false, 24)
	UIKit.spacer(box, 0, true)
	var art := SetupArtView.new()
	art.name = "Headphones"
	art.kind = "headphones"
	art.custom_minimum_size = Vector2(0, 420)
	box.add_child(art)
	box.add_child(UIKit.label(tr("hp_title"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label(tr("hp_body"), "", true, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.spacer(box, 0, true)
	var go := UIKit.button(tr("hp_continue"), _next, UIKit.PRIMARY)
	go.name = "Continue"
	box.add_child(go)
	UIKit.spacer(box, 8)


func _next() -> void:
	Profile.set_flag("headphones_seen", true)
	app.reset("title")


func on_back() -> void:
	app.replace("language")
