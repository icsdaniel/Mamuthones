extends Screen
## Scores, on the mobile kit: your own bests on this phone, one difficulty at a time (a segmented
## control, the same as free play's), the seven songs as rows of one height with the best score and
## the round grade seal (locked stops shown dim with a lock); the platform's ladders (Game Center /
## Google Play Games) are the round ladder button in the top bar and the footer's button when
## available. Nothing here needs the internet. args: difficulty.

var difficulty := "easy"
var _tabs: HBoxContainer
var _rows: VBoxContainer
var _empty: Label


func build() -> void:
	difficulty = str(args.get("difficulty", "easy"))
	var page := UIKit.scaffold(self, false, UIKit.S3)
	var ladder := UIKit.icon_button("ladder", func() -> void: Leaderboards.show(), tr("boards_online"))
	ladder.name = "Ladder"
	ladder.disabled = not Leaderboards.available()
	UIKit.top_bar(page.top, tr("boards_title"), on_back, tr("boards_local"), ladder)
	var items := []
	for d in SongData.DIFFICULTIES:
		items.append([d, tr("diff_" + d)])
	_tabs = UIKit.tabs(page.top, items, difficulty, _pick)
	page.top.add_theme_constant_override("separation", UIKit.S3)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", UIKit.S1 + 3)
	page.body.add_child(_rows)
	_empty = UIKit.label(tr("boards_empty"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	_empty.name = "Empty"
	page.body.add_child(_empty)
	if not Leaderboards.available():
		var off := UIKit.label(tr("boards_offline"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
		off.name = "Offline"
		off.add_theme_constant_override("line_spacing", -2)
		page.foot.add_child(off)
	var online := UIKit.button(tr("boards_online"), func() -> void: Leaderboards.show())
	online.name = "Online"
	online.icon = WoodcutTheme.icon("ladder")
	online.disabled = not Leaderboards.available()
	page.foot.add_child(online)
	_pick(difficulty)


func _pick(d: String) -> void:
	difficulty = d
	UIKit.select_tab(_tabs, d)
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var any := false
	for song in SongLibrary.story():
		var open := Progression.is_unlocked(song.id)
		var p := PanelContainer.new()
		p.name = "Row_" + song.id
		p.theme_type_variation = UIKit.TILE
		p.custom_minimum_size.y = MenuKit.ROW_H
		_rows.add_child(p)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UIKit.S3)
		p.add_child(row)
		var num := UIKit.label(str(song.stop), UIKit.VALUE, false, HORIZONTAL_ALIGNMENT_CENTER)
		num.custom_minimum_size.x = 36
		num.add_theme_font_size_override("font_size", 34)
		num.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_3)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(num)
		var best: Dictionary = Profile.best(song.id, d) if open else {}
		var cap := tr("story_locked_short") if not open else (UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else tr("boards_not_played"))
		var t: Array = MenuKit.row_text(row, UIKit.song_title(song), cap)
		(t[1] as Label).add_theme_color_override("font_color", WoodcutTheme.C_BRONZE if not best.is_empty() else WoodcutTheme.C_TEXT_3)
		if not open:
			(t[0] as Label).add_theme_color_override("font_color", WoodcutTheme.C_TEXT_3)
			var lock := TextureRect.new()
			lock.texture = KitIcons.get_icon("lock")
			lock.modulate = WoodcutTheme.C_TEXT_3
			lock.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			lock.custom_minimum_size = Vector2(72, 0)
			row.add_child(lock)
		else:
			var g := MenuKit.grade_mark(UIKit.grade_of(best), bool(best.get("full_combo", false)))
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(g)
		any = any or not best.is_empty()
	_empty.visible = not any
