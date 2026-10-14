extends Screen
## Free play, on the mobile kit: every song at every difficulty, all open from the start. The
## difficulty is a segmented control under the top bar; the seven songs are rows of one height
## (MenuKit.row_button) showing the stop number, the name, the best score and a round grade seal
## at that difficulty (the remix's when the remix is on for the chosen song). The chosen row is lit
## with a bronze rim and a bronze name. Under the rows, the chosen song's best (score, seal, the
## ghost to race); the footer pins Play with the Remix chip beside it once earned (a lock and its
## requirement above it while not). Fits; nothing scrolls.

var song: SongData
var difficulty := "easy"
var use_remix := false
var _song_buttons := {}
var _tabs: HBoxContainer
var _best_tile: PanelContainer
var _remix: Button
var _remix_lock: HBoxContainer


func build() -> void:
	var page := UIKit.scaffold(self, false, UIKit.S1 + 3)
	UIKit.top_bar(page.top, tr("free_title"), on_back)
	var items := []
	for d in SongData.DIFFICULTIES:
		items.append([d, tr("diff_" + d)])
	_tabs = UIKit.tabs(page.top, items, difficulty, _pick_diff)
	page.top.add_theme_constant_override("separation", UIKit.S3)
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
		page.body.add_child(b)
		_song_buttons[s.id] = b

	# footer: the chosen song's best (and the ghost, the remix's lock) over Remix + Play
	UIKit.spacer(page.body, 0, true)
	_best_tile = PanelContainer.new()
	_best_tile.name = "Best"
	_best_tile.theme_type_variation = UIKit.TILE
	page.body.add_child(_best_tile)
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
	var first := SongLibrary.get_song(Progression.next_stop())
	if first == null and not SongLibrary.story().is_empty():
		first = SongLibrary.story()[0]
	_pick_diff(difficulty)
	if first != null:
		_pick_song(first)


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
## remix is on for the chosen song).
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
		var row := b.find_child("Row", true, false) as HBoxContainer
		var old := row.get_node_or_null("Grade")
		if old != null:
			row.remove_child(old)
			old.queue_free()
		var g := MenuKit.grade_mark(UIKit.grade_of(best), bool(best.get("full_combo", false)))
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)


## The chosen song's best at the chosen difficulty, pinned over Play: the score, the round seal,
## and the ghost line when a best run is there to race.
func _refresh() -> void:
	if song == null:
		return
	for c in _best_tile.get_children():
		_best_tile.remove_child(c)
		c.queue_free()
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S3)
	_best_tile.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var tag := UIKit.song_title(song) + " · " + tr("diff_" + difficulty)
	if use_remix:
		tag += " · " + tr("stop_remix_chip")
	col.add_child(UIKit.overline(tag))
	var v := UIKit.label(UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else tr("stop_no_best"), UIKit.VALUE, false)
	v.name = "Info"
	if best.is_empty():
		v.add_theme_font_size_override("font_size", 30)
		v.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	col.add_child(v)
	if not (best.get("ghost", {}) as Dictionary).is_empty():
		var gl := UIKit.label(tr("free_ghost"), UIKit.CAPTION)
		gl.name = "Ghost"
		gl.add_theme_constant_override("line_spacing", -2)
		col.add_child(gl)
	var g := MenuKit.grade_mark(UIKit.grade_of(best), bool(best.get("full_combo", false)))
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(g)


func _play() -> void:
	if song == null:
		return
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"remix": use_remix,
	})
