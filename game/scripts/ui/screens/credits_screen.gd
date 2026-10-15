extends Screen
## Credits, on the mobile kit: two swipeable pages under a segmented control. The first opens with
## the game's mark and the note on respect for the Mamoiada tradition and what is still being
## checked with the community (the one accent card); the second lists who and what made the game,
## as one grouped card, with the privacy line under it. args: page.

var pager: Pager


func build() -> void:
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.top_bar(page.top, tr("cred_title"), on_back)
	pager = UIKit.paged(page.body, [["respect", tr("cred_respect_title")], ["credits", tr("cred_title")]], clampi(int(args.get("page", 0)), 0, 1))
	var a := pager.add_page("RespectPage", UIKit.S3)
	var logo := Logo.new()
	logo.mode = "full"
	logo.subtitle = tr("app_title")
	logo.max_scale = 3
	logo.custom_minimum_size = Vector2(0, 240)
	logo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	a.add_child(logo)
	var respect := UIKit.card(a, true)
	respect.get_parent().name = "Respect"
	respect.add_child(UIKit.label(tr("cred_respect_title"), UIKit.PAPER_HEADER))
	respect.add_child(UIKit.label(tr("cred_respect"), UIKit.PAPER))
	var check := UIKit.label(tr("cred_check"), UIKit.CAPTION)
	check.add_theme_constant_override("line_spacing", -2)
	respect.add_child(check)
	var b := pager.add_page("CreditsPage", UIKit.S3, true)
	var g := MenuKit.group(b)
	for key in ["cred_made", "cred_music", "cred_sound", "cred_art", "cred_fonts", "cred_engine"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		MenuKit.control_row(g, "", col)
		col.add_child(UIKit.overline(tr(key + "_h")))
		var l := UIKit.label(tr(key), "")
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_constant_override("line_spacing", -2)
		col.add_child(l)
	b.add_child(UIKit.label(tr("cred_privacy"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER))
	pager.go(pager.current, true)
