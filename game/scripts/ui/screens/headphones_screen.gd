extends Screen
## First launch, step 2: suggest headphones. The top bar's back returns to the language; the
## picture is the hero, the title and one sentence under it, Continue pinned in the thumb zone (on
## to the calibration when this phone has not been calibrated yet, else to the title).


func build() -> void:
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.top_bar(page.top, "", on_back)
	var art := SetupArtView.new()
	art.name = "Headphones"
	art.kind = "headphones"
	art.custom_minimum_size = Vector2(0, 360)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.body.add_child(art)
	page.body.add_child(UIKit.label(tr("hp_title"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	var body := UIKit.label(tr("hp_body"), "", true, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	page.body.add_child(body)
	UIKit.spacer(page.body, UIKit.S4)
	var go := UIKit.button(tr("hp_continue"), _next, UIKit.PRIMARY)
	go.name = "Continue"
	page.foot.add_child(go)


func _next() -> void:
	Profile.set_flag("headphones_seen", true)
	if Profile.has_flag("calibrated"):
		app.reset("title")
	else:
		app.replace("calibration", {"first_run": true})


func on_back() -> void:
	app.replace("language")
