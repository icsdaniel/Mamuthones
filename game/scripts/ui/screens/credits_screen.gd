extends Screen
## Credits, opening with the note on respect for the Mamoiada tradition and what is still being
## checked with the community.


func build() -> void:
	var box := UIKit.column(self, true, 16)
	UIKit.header(box, tr("cred_title"), on_back)
	var respect := UIKit.card(box)
	respect.name = "Respect"
	respect.add_child(UIKit.label(tr("cred_respect_title"), UIKit.SUB))
	respect.add_child(UIKit.label(tr("cred_respect")))
	respect.add_child(UIKit.label(tr("cred_check")))
	for key in ["cred_made", "cred_music", "cred_sound", "cred_art", "cred_fonts", "cred_engine"]:
		box.add_child(UIKit.label(tr(key + "_h"), UIKit.SUB))
		box.add_child(UIKit.label(tr(key), ""))
	box.add_child(UIKit.label(tr("cred_privacy"), UIKit.CAPTION))
