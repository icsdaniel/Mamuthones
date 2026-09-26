extends Screen
## First launch, step 2: suggest headphones. One tap to go on.


func build() -> void:
	var box := UIKit.column(self, false, 24)
	UIKit.spacer(box, 0, true)
	var art := HeadphonesArt.new()
	art.custom_minimum_size = Vector2(0, 300)
	box.add_child(art)
	box.add_child(UIKit.label(tr("hp_title"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label(tr("hp_body"), "", true, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.spacer(box, 0, true)
	var go := UIKit.button(tr("hp_continue"), _next, UIKit.PRIMARY)
	go.name = "Continue"
	box.add_child(go)
	UIKit.spacer(box, 8)


func _next() -> void:
	app.replace("calibration", {"first_run": true})


func on_back() -> void:
	app.replace("language")
