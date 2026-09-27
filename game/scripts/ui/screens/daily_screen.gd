extends Screen
## The daily procession: the date picks the song and whether the lanes are mirrored, the same for
## everyone with no server; the player picks the difficulty, and each difficulty has its own ladder.
## A song from a stop the player has not reached is not spoiled: its name and picture are hidden
## ("a procession from later in the story").

var pick: Dictionary
var date_key := ""
var difficulty := ""
var song_hidden := false
var _date: Dictionary
var _song: SongData
var _diff_buttons := {}
var _info: Label
var played_today := false


## A neutral picture for a hidden song: the game's mask, dimmed, on dark wood.
class Veiled extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.WOOD)
		var c := size * 0.5
		draw_set_transform(c, 0.0, Vector2.ONE)
		Logo.paint(self, Vector2.ZERO, minf(size.x, size.y) * 0.3, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.45))


## One day of the last seven: a ring, filled in ember when that day's procession was walked, with a
## brighter ring around today.
class DayMark extends Control:
	var walked := false
	var today := false

	func _init(p_walked: bool, p_today: bool) -> void:
		walked = p_walked
		today = p_today
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.34
		if walked:
			draw_circle(c, r, Palette.EMBER)
		else:
			draw_arc(c, r, 0.0, TAU, 32, Palette.BONE_DIM, 2.5, true)
		if today:
			draw_arc(c, r + 7.0, 0.0, TAU, 40, Palette.EMBER_HOT, 3.0, true)


func build() -> void:
	# args.date (tests, screenshots) stands in for today's UTC date.
	_date = args.get("date", Time.get_date_dict_from_system(true))
	pick = Daily.for_date(_date)
	date_key = str(pick.get("key", Daily.key(_date)))
	_song = SongLibrary.get_song(str(pick.get("song_id", "")))
	song_hidden = Daily.is_hidden(_date)
	var cols := UIKit.column_with_footer(self, 16)
	var box := cols[0]
	UIKit.header(box, tr("daily_title"), on_back)
	box.add_child(UIKit.label(tr("daily_intro"), ""))
	var c := UIKit.card(box, true)
	c.add_child(UIKit.label(UIKit.date_text(_date), UIKit.PAPER))
	if _song == null:
		c.add_child(UIKit.label(tr("daily_none"), UIKit.PAPER))
		return
	var pic: Control
	if song_hidden:
		pic = Veiled.new()
	else:
		var tex := TextureRect.new()
		tex.texture = StopArt.card(_song.stop)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic = tex
	pic.name = "Picture"
	pic.custom_minimum_size = Vector2(0, 300)
	c.add_child(pic)
	var title := UIKit.label(tr("daily_hidden") if song_hidden else UIKit.song_title(_song), UIKit.PAPER_HEADER)
	title.name = "SongTitle"
	c.add_child(title)
	if pick.get("mirror", false):
		c.add_child(UIKit.label(tr("daily_mirrored"), UIKit.PAPER))
	# The player picks the level; each level has its own ladder for the day.
	box.add_child(UIKit.label(tr("stop_difficulty"), UIKit.SUB))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var levels: Array = pick.get("difficulties", _song.difficulties())
	for d in levels:
		var b := UIKit.button(tr("diff_" + str(d)), _pick.bind(str(d)))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Diff_" + str(d)
		grid.add_child(b)
		_diff_buttons[str(d)] = b
	_info = UIKit.label("", UIKit.CAPTION)
	_info.name = "Best"
	box.add_child(_info)
	var play := UIKit.button(tr("daily_play"), _play, UIKit.PRIMARY)
	play.name = "Play"
	cols[1].add_child(play)
	_week(box)
	# Nobody has a score for today yet: no empty scores link, an invitation instead.
	played_today = not Profile.daily_best(date_key).is_empty()
	if played_today:
		var boards := UIKit.button(tr("daily_scores"), func() -> void: app.open("boards"), UIKit.QUIET)
		boards.name = "Boards"
		box.add_child(boards)
	var start := str(pick.get("difficulty", ""))
	if not start in _diff_buttons and not levels.is_empty():
		start = str(levels[0])
	_pick(start)


## The last seven days, today last: which dailies were walked, so coming back each day shows.
func _week(box: Container) -> void:
	var c := UIKit.card(box)
	c.name = "Week"
	var head := HBoxContainer.new()
	c.add_child(head)
	var t := UIKit.label(tr("daily_week"), UIKit.SUB)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	c.add_child(row)
	var letters := tr("daily_week_days").split(",")
	var today_unix := Time.get_unix_time_from_datetime_dict(_date)
	var walked := 0
	for i in range(6, -1, -1):
		var d := Time.get_datetime_dict_from_unix_time(today_unix - i * 86400)
		var on := not Profile.daily_best(Daily.key(d)).is_empty()
		walked += int(on)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		row.add_child(col)
		# weekday: 0 = Sunday; the letters run Monday first
		var wd := int(d.get("weekday", 0))
		var letter := letters[(wd + 6) % 7] if letters.size() == 7 else ""
		col.add_child(UIKit.label(letter, UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER))
		var m := DayMark.new(on, i == 0)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(m)
	var count := UIKit.label(tr("daily_week_count") % walked, UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_RIGHT)
	count.name = "WeekCount"
	head.add_child(count)


func _pick(d: String) -> void:
	difficulty = d
	for k in _diff_buttons:
		(_diff_buttons[k] as Button).set_pressed_no_signal(k == d)
	var today := int(Profile.daily_best(date_key, d).get("score", -1))
	var best: Dictionary = Profile.best(_song.id, d)
	if today > 0:
		_info.text = tr("daily_best_today") % UIKit.fmt_score(today)
	elif not best.is_empty() and not song_hidden:
		_info.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), int(best.get("bells", 0))]
	elif not played_today:
		_info.text = tr("daily_be_first")
	else:
		_info.text = tr("daily_first")


func _play() -> void:
	if _song == null or difficulty == "":
		return
	app.open("play", {
		"song_id": _song.id,
		"difficulty": difficulty,
		"bell_set": str(Profile.get_look().get("bell_set", "light")),
		"mirror": bool(pick.get("mirror", false)),
		"daily": date_key,
	})
