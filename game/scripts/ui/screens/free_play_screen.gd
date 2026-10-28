extends Screen
## Free play: every song at every difficulty (all open from the start), any unlocked bell set, the
## remix when earned. The difficulties are tabs along the top; the song list under them shows each
## song's best score and grade at the open difficulty. Below, whether a ghost is there to race.

var song: SongData
var difficulty := "easy"
var use_remix := false
var _song_buttons := {}
var _tabs: HBoxContainer
var _info: Label
var _remix: CheckButton


func build() -> void:
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	var head := UIKit.header(box, tr("free_title"), on_back)
	# the scores (this phone's bests and the platform's ladders), off the title since 2026-10-28
	var scores := UIKit.button(tr("title_boards"), func() -> void: app.open("boards"), UIKit.QUIET)
	scores.name = "Leaderboards"
	scores.custom_minimum_size = Vector2(UIKit.TOUCH * 2.4, UIKit.TOUCH)
	head.add_child(scores)
	# The difficulties are tabs along the top; the songs below show their best at the open one.
	var items := []
	for d in SongData.DIFFICULTIES:
		items.append([d, tr("diff_" + d)])
	_tabs = UIKit.tabs(box, items, difficulty, _pick_diff)
	var last_stop := -1
	for s in SongLibrary.catalogue():
		# a stop's number once, on its first version
		var lead := str(s.stop) if s.stop != last_stop else " "   # (a blank keeps the titles in line)
		last_stop = s.stop
		var title := UIKit.song_title(s)
		if s.kind == "tutorial" and SongLibrary.versions(s).size() > 1:
			title += " · " + tr("version_practice")   # beside the stop's recorded song of the same name
		var b := UIKit.list_row(lead, title, "", GradeBadge.new(-1), "open", _pick_song.bind(s))
		(b.get_child(0).get_child(b.get_child(0).get_child_count() - 1) as Control).name = "Grade"
		b.toggle_mode = true
		b.name = "Song_" + s.id
		box.add_child(b)
		_song_buttons[s.id] = b
	_remix = CheckButton.new()
	_remix.custom_minimum_size.y = UIKit.TOUCH
	_remix.focus_mode = Control.FOCUS_NONE
	_remix.toggled.connect(func(on: bool) -> void:
		use_remix = on
		_pick_song(song))
	_remix.name = "Remix"
	box.add_child(_remix)
	_info = UIKit.label("", UIKit.CAPTION)
	box.add_child(_info)
	var play := UIKit.button(tr("stop_play"), _play, UIKit.PRIMARY)
	play.name = "Play"
	cols[1].add_child(play)
	var first := SongLibrary.get_song(Progression.next_stop())
	if first == null and not SongLibrary.story().is_empty():
		first = SongLibrary.story()[0]
	_pick_diff(difficulty)
	if first != null:
		_pick_song(first)


func _pick_song(s: SongData) -> void:
	song = s
	for id in _song_buttons:
		UIKit.row_select(_song_buttons[id], id == s.id)
	var remix_open := s.has_remix() and Progression.remix_unlocked(s.id)
	_remix.visible = s.has_remix()
	_remix.disabled = not remix_open
	_remix.text = tr("stop_remix") if remix_open else tr("stop_remix_locked")
	if not remix_open:
		use_remix = false
		_remix.set_pressed_no_signal(false)
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
		var best: Dictionary = Profile.best(UIKit.board_song_id(sd, use_remix and sd == song), difficulty)
		_badge(b, UIKit.grade_of(best), UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else "", bool(best.get("full_combo", false)))


## The best score (caption) and grade (right end) of a song row.
func _badge(b: Button, grade: int, score: String, fc := false) -> void:
	var row := b.get_child(0) as HBoxContainer
	var old := row.get_node_or_null("Grade")
	if old != null:
		row.remove_child(old)
		old.queue_free()
	var badge := GradeBadge.new(grade, false, fc)
	badge.name = "Grade"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	var text := row.get_child(1) as VBoxContainer
	if text.get_child_count() > 1:
		text.remove_child(text.get_child(1))
	if score != "":
		var l := UIKit.label(score, UIKit.CAPTION, false)
		l.name = "Score"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_color", PixelPalette.GOLD[5])
		text.add_child(l)


func _refresh() -> void:
	if song == null:
		return
	var best: Dictionary = Profile.best(UIKit.board_song_id(song, use_remix), difficulty)
	if best.is_empty():
		_info.text = tr("stop_no_best")
	else:
		_info.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), Session.grade_name(UIKit.grade_of(best))]
		if not (best.get("ghost", {}) as Dictionary).is_empty():
			_info.text += "\n" + tr("free_ghost")


func _play() -> void:
	if song == null:
		return
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"remix": use_remix,
	})
