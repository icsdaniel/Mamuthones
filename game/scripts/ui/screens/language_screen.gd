extends Screen
## First launch, step 1: pick the language. The phone's language is offered first.


func build() -> void:
	var box := UIKit.column(self, false, 24)
	UIKit.spacer(box, 0, true)
	var logo := Logo.new()
	logo.custom_minimum_size = Vector2(0, 420)
	box.add_child(logo)
	box.add_child(UIKit.label(tr("app_title"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.spacer(box, 24)
	var phone := I18n.system_locale()
	for code in ["en", "it"] if phone == "en" else ["it", "en"]:
		var b := UIKit.button(tr("lang_name_" + code), _choose.bind(code),
			UIKit.PRIMARY if code == phone else "")
		b.name = "Lang_" + code
		box.add_child(b)
	UIKit.spacer(box, 0, true)


func _choose(code: String) -> void:
	Profile.set_setting("language", code)
	Profile.set_flag("language_chosen", true)
	I18n.set_locale(code)
	app.replace("headphones")


func on_back() -> void:
	pass
