extends Screen
## Credits, opening with the note on respect for the Mamoiada tradition and what is still being
## checked with the community.


func build() -> void:
	var box := UIKit.column(self, true, 16)
	UIKit.header(box, tr("cred_title"), on_back)
	var logo := Logo.new()
	logo.mode = "full"
	logo.subtitle = tr("app_title")
	logo.custom_minimum_size = Vector2(0, 470)
	box.add_child(logo)
	var respect := UIKit.card(box, true)
	respect.name = "Respect"
	respect.add_child(UIKit.label(tr("cred_respect_title"), UIKit.PAPER_HEADER))
	respect.add_child(UIKit.label(tr("cred_respect"), UIKit.PAPER))
	respect.add_child(UIKit.label(tr("cred_check"), UIKit.PAPER))
	for key in ["cred_made", "cred_music", "cred_sound", "cred_art", "cred_fonts", "cred_engine"]:
		box.add_child(UIKit.label(tr(key + "_h"), UIKit.SUB))
		box.add_child(UIKit.label(tr(key), ""))
	box.add_child(UIKit.label(tr("cred_privacy"), UIKit.CAPTION))
