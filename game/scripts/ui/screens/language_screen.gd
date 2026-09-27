extends Screen
## First launch, step 1: pick the language. The phone's language is offered first.


func build() -> void:
	var box := UIKit.column(self, false, 24)
	UIKit.spacer(box, 0, true)
	# The same wordmark as the title screen: the name, then the subtitle.
	var logo := Logo.new()
	logo.name = "Logo"
	logo.show_title = true
	logo.subtitle = tr("app_title")
	logo.custom_minimum_size = Vector2(0, 600)
	box.add_child(logo)
	UIKit.spacer(box, 24)
	var phone := I18n.system_locale()
	for code in ["en", "it"] if phone == "en" else ["it", "en"]:
		var b := UIKit.button(tr("lang_name_" + code), _choose.bind(code),
			UIKit.PRIMARY if code == phone else "")
		b.name = "Lang_" + code
		box.add_child(b)
	UIKit.spacer(box, 0, true)


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
