extends Screen
## Free play, and the scores, on the mobile kit: every song at every difficulty, all open from the
## start. The difficulty is a segmented control under the top bar; the seven songs are rows that
## share the room down to the footer (96 to 120 px) showing the stop number, the name, the best
## score and a round grade seal with the FC pill at that difficulty (the remix's when the remix is
## on for the chosen song): the player's bests on this phone. The chosen row is lit with a bronze
## rim and a bronze name. The platform's ladders (Game Center / Google Play Games) are the round
## trophy in the top bar, for the chosen song and difficulty. The footer: the ghost line when a best
## run is there to race, the remix's lock and requirement while it is closed, and Play with the Remix
## chip beside it once earned. Fits; nothing scrolls. The old "boards" screen opens this one.
## args: song_id, difficulty (optional: what to show first).

const ROW_MIN := 96.0
const ROW_MAX := 120.0

var song: SongData
var difficulty := "easy"
var use_remix := false
var _song_buttons := {}
var _tabs: HBoxContainer
var _rows: VBoxContainer
var _ghost: Label
var _remix: Button
var _remix_lock: HBoxContainer
var _ladder: Button


func build() -> void:
	_song_buttons.clear()
	if str(args.get("difficulty", "")) in SongData.DIFFICULTIES:
		difficulty = str(args.difficulty)
	var page := UIKit.scaffold(self, false, UIKit.S3)
	_ladder = UIKit.icon_button("ladder", _open_ladder, tr("boards_online"))
	_ladder.name = "Ladder"
	_ladder.disabled = not Leaderboards.available()
	UIKit.top_bar(page.top, tr("free_title"), on_back, "", _ladder)
	var items := []
	for d in SongData.DIFFICULTIES:
		items.append([d, tr("diff_" + d)])
	_tabs = UIKit.tabs(page.top, items, difficulty, _pick_diff)
	page.top.add_theme_constant_override("separation", UIKit.S3)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", UIKit.S2)
	page.body.add_child(_rows)
	for s in SongLibrary.story():
		var parts := MenuKit.row_button("Song_" + s.id, _pick_song.bind(s), true)
		var b: Button = parts[0]
		var row: HBoxContainer = parts[1]
		var num := UIKit.label(str(s.stop), UIKit.VALUE, false, HORIZONTAL_ALIGNMENT_CENTER)
		num.name = "Number"
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num.custom_minimum_size.x = 36
		num.add_theme_font_size_override("font_size", 34)
		num.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_3)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(num)
		MenuKit.row_text(row, UIKit.song_title(s), " ")
		var g := MenuKit.grade_mark(-1)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
		_rows.add_child(b)
		_song_buttons[s.id] = b
	_rows.resized.connect(_fit_rows)

	# footer: the ghost line, the remix's lock, then Remix + Play
	_ghost = UIKit.label(tr("free_ghost"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER)
	_ghost.name = "Ghost"
	_ghost.add_theme_constant_override("line_spacing", -2)
	page.foot.add_child(_ghost)
	_remix_lock = MenuKit.lock_line(tr("stop_remix_locked"))
	page.foot.add_child(_remix_lock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S2)
	page.foot.add_child(row)
	_remix = UIKit.button(tr("stop_remix_chip"), func() -> void: pass, UIKit.CHIP)
	_remix.name = "Remix"
	_remix.toggle_mode = true
	_remix.custom_minimum_size = Vector2(180, UIKit.PRIMARY_H)
	_remix.toggled.connect(func(on: bool) -> void:
		use_remix = on
		_pick_song(song))
	row.add_child(_remix)
	var play := UIKit.button(tr("stop_play"), _play, UIKit.PRIMARY)
	play.name = "Play"
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(play)
	var first := SongLibrary.get_song(str(args.get("song_id", "")))
	if first == null:
		first = SongLibrary.get_song(Progression.next_stop())
	if first == null and not SongLibrary.story().is_empty():
		first = SongLibrary.story()[0]
	_pick_diff(difficulty)
	if first != null:
		_pick_song(first)


## The rows share the room above the footer: each 96 to 120 px, never more (the rest stays below).
func _fit_rows() -> void:
	var n := _song_buttons.size()
	if n == 0:
		return
	var sep := float(_rows.get_theme_constant("separation"))
	var h := clampf(floorf((_rows.size.y - sep * (n - 1)) / n / 3.0) * 3.0, ROW_MIN, ROW_MAX)
	for b in _song_buttons.values():
		if absf((b as Control).custom_minimum_size.y - h) > 0.5:
			(b as Control).custom_minimum_size.y = h


func _pick_song(s: SongData) -> void:
	song = s
	var remix_open := s.has_remix() and Progression.remix_unlocked(s.id)
	_remix.visible = remix_open
	_remix_lock.visible = s.has_remix() and not remix_open
	if not remix_open:
		use_remix = false
		_remix.set_pressed_no_signal(false)
	for id in _song_buttons:
		var b: Button = _song_buttons[id]
		b.set_pressed_no_signal(id == s.id)
		var t := b.find_child("Title", true, false) as Label
		t.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI if id == s.id else WoodcutTheme.C_TEXT)
	_show_bests()
	_refresh()


func _pick_diff(d: String) -> void:
	difficulty = d
	UIKit.select_tab(_tabs, d)
	_show_bests()
	_refresh()


## Every song row shows its best at the chosen difficulty: score and grade (the remix's when the
## remix is on for the chosen song). The seals are updated in place.
func _show_bests() -> void:
	for id in _song_buttons:
		var b: Button = _song_buttons[id]
		var sd := SongLibrary.get_song(id)
		var remix := use_remix and sd == song
		var best: Dictionary = Profile.best(UIKit.board_song_id(sd, remix), difficulty)
		var cap := b.find_child("Caption", true, false) as Label
		var text := UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else tr("boards_not_played")
		if remix:
			text = tr("stop_remix_chip") + " · " + text
		cap.text = text
		cap.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE if not best.is_empty() else WoodcutTheme.C_TEXT_3)
		MenuKit.set_grade(b.find_child("Grade", true, false) as HBoxContainer, UIKit.grade_of(best), bool(best.get("full_combo", false)))


## The ghost line shows when the chosen song has a best run to race at this difficulty.
func _refresh() -> void:
	if song == null:
		return
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	_ghost.visible = not (best.get("ghost", {}) as Dictionary).is_empty()


## The platform's ladder for the chosen song and difficulty.
func _open_ladder() -> void:
	if song == null:
		Leaderboards.show()
	else:
		Leaderboards.show(Profile.board_id(UIKit.board_song_id(song, use_remix), difficulty))


func _play() -> void:
	if song == null:
		return
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"remix": use_remix,
	})
