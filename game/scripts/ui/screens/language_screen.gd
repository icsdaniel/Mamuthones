extends Screen
## First launch, step 1: pick the language. The game's whole logo is the hero in the middle of the
## night; the two languages are big buttons pinned in the thumb zone, the phone's own first (and
## primary).


func build() -> void:
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.spacer(page.body, 0, true)
	var logo := Logo.new()
	logo.name = "Logo"
	logo.show_title = true
	logo.subtitle = tr("app_title")
	logo.custom_minimum_size = Vector2(0, 640)
	page.body.add_child(logo)
	UIKit.spacer(page.body, 0, true)
	page.foot.add_child(UIKit.label(tr("lang_choose"), UIKit.LEAD, false, HORIZONTAL_ALIGNMENT_CENTER))
	var phone := I18n.system_locale()
	for code in ["en", "it"] if phone == "en" else ["it", "en"]:
		var b := UIKit.button(tr("lang_name_" + code), _choose.bind(code), UIKit.PRIMARY if code == phone else "")
		b.name = "Lang_" + code
		page.foot.add_child(b)


func _choose(code: String) -> void:
	# On the web the first tap may ask for the motion sensors, so the browser's question comes now,
	# with the choice, rather than in the middle of setup. Natively it does nothing.
	if OS.has_feature("web"):
		MotionReader.new().request_web_permission()
	Profile.set_setting("language", code)
	Profile.set_flag("language_chosen", true)
	I18n.set_locale(code)
	app.replace("headphones")


func on_back() -> void:
	pass
