extends Screen
## The card before a story stop, on the mobile kit: the top bar names the stop (its number and day
## over its name); the stop's living pixel picture is the hero, flush in a rounded card with the two
## sentences about the moment under it; then the difficulty as a segmented control (the Remix chip
## beside its heading once earned, the requirement with a lock while not), the best at that
## difficulty as a tile with its round grade seal, and Play pinned in the thumb zone (the tutorial
## stop also offers its lessons there). Fits the screen; nothing scrolls.
## args: song_id.

static var last_difficulty := "easy"

var song: SongData
var difficulty := "easy"
var use_remix := false
var _tabs: HBoxContainer
var _best_tile: PanelContainer


func build() -> void:
	song = SongLibrary.get_song(args.get("song_id", ""))
	if song == null:
		push_error("stop card: unknown song %s" % args.get("song_id", ""))
		return
	difficulty = last_difficulty if last_difficulty in song.difficulties() else song.difficulties()[0]
	var page := UIKit.scaffold(self, false, UIKit.S3)
	var over := tr("story_stop_overline") % song.stop
	var date := UIKit.stop_date(song)
	if date != "":
		over += " · " + date
	UIKit.top_bar(page.top, UIKit.song_title(song), on_back, over)

	# The hero: the stop's picture, alive, with the card text under it.
	var pic := StopPicture.new()
	pic.name = "Picture"
	pic.stop = song.stop
	pic.px = int(PixelFrame.px_for(self))
	pic.bpm = song.bpm * 0.5
	pic.animate = not UIKit.reduced_motion()
	var card := Rect2(Vector2(StopBackdrops.data(song.stop).card), Vector2(StopCells.CARD))
	pic.focus = card.get_center() + Vector2(0, 8)  # when cropped, keep the feet, lose a little sky
	var parts := MenuKit.picture_card(pic)
	var hero: PanelContainer = parts[0]
	hero.name = "Hero"
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.body.add_child(hero)
	var holder := hero.find_child("PictureHolder", true, false) as Control
	holder.custom_minimum_size.y = 210
	var fact := UIKit.label(tr("stop_fact_%d" % song.stop), "")
	fact.name = "Fact"
	fact.add_theme_constant_override("line_spacing", -2)
	(parts[1] as VBoxContainer).add_child(fact)

	# The difficulty: heading (with the Remix chip once earned) over the segmented control.
	var dh := HBoxContainer.new()
	dh.name = "DifficultyHead"
	dh.add_theme_constant_override("separation", UIKit.S2)
	page.body.add_child(dh)
	var dl := UIKit.overline(tr("stop_difficulty"))
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	if song.has_remix() and Progression.remix_unlocked(song.id):
		var chip := UIKit.button(tr("stop_remix_chip"), func() -> void: pass, UIKit.CHIP)
		chip.toggle_mode = true
		chip.name = "Remix"
		chip.custom_minimum_size = Vector2(160, UIKit.TOUCH)
		chip.toggled.connect(func(on: bool) -> void:
			use_remix = on
			_show_best())
		dh.add_child(chip)
	var items := []
	for d in song.difficulties():
		items.append([d, tr("diff_" + d)])
	_tabs = UIKit.tabs(page.body, items, difficulty, _pick)
	if song.has_remix() and not Progression.remix_unlocked(song.id):
		var r := MenuKit.lock_line(tr("stop_remix_locked"))
		r.name = "RemixLocked"
		page.body.add_child(r)

	# The best at the chosen difficulty: a tile with the score and the round seal.
	_best_tile = PanelContainer.new()
	_best_tile.name = "Best"
	_best_tile.theme_type_variation = UIKit.TILE
	page.body.add_child(_best_tile)

	# The tutorial stop: its lessons are the one primary until they are done; then Play leads and
	# the lessons stay beside it.
	var lessons_first := song.kind == "tutorial" and not Profile.has_flag("tutorial_done")
	var open_lessons := func() -> void: app.open("tutorial", {"song_id": song.id})
	if lessons_first:
		var lessons := UIKit.button(tr("stop_lessons"), open_lessons, UIKit.PRIMARY)
		lessons.name = "Lessons"
		UIKit.footer_actions(page.foot, lessons, MenuKit.icon_action("Play", "play", _play, tr("stop_play")))
	else:
		var play := UIKit.button(tr("stop_play"), _play, UIKit.PRIMARY)
		play.name = "Play"
		var lessons_icon: Button = null
		if song.kind == "tutorial":
			lessons_icon = MenuKit.icon_action("Lessons", "help", open_lessons, tr("stop_lessons"))
		UIKit.footer_actions(page.foot, play, lessons_icon)
	_pick(difficulty)


func _pick(d: String) -> void:
	difficulty = d
	last_difficulty = d
	UIKit.select_tab(_tabs, d)
	_show_best()


func _show_best() -> void:
	for c in _best_tile.get_children():
		_best_tile.remove_child(c)
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S3)
	_best_tile.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var tag := tr("diff_" + difficulty)
	if use_remix:
		tag += " · " + tr("stop_remix_chip")
	col.add_child(UIKit.overline(tr("stop_best_at") % tag))
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	var v := UIKit.label(UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else tr("stop_no_best"), UIKit.VALUE, false)
	v.name = "BestValue"
	if best.is_empty():
		v.add_theme_font_size_override("font_size", 30)
		v.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	col.add_child(v)
	var g := MenuKit.grade_mark(UIKit.grade_of(best), bool(best.get("full_combo", false)))
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)


func _play() -> void:
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"remix": use_remix,
	})
