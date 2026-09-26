extends Screen
## The daily procession: the date picks a song, a difficulty and whether the lanes are mirrored, so
## everyone playing today gets the same one with no server.

var pick: Dictionary
var date_key := ""


func build() -> void:
	var date := Time.get_date_dict_from_system(true)
	pick = Daily.for_date(date)
	date_key = str(pick.get("key", Daily.key(date)))
	var song := SongLibrary.get_song(str(pick.get("song_id", "")))
	var cols := UIKit.column_with_footer(self, 16)
	var box := cols[0]
	UIKit.header(box, tr("daily_title"), on_back)
	box.add_child(UIKit.label(tr("daily_intro"), ""))
	var c := UIKit.card(box, true)
	c.add_child(UIKit.label(UIKit.date_text(date), UIKit.PAPER))
	if song == null:
		c.add_child(UIKit.label(tr("daily_none"), UIKit.PAPER))
		return
	var pic := TextureRect.new()
	pic.texture = StopArt.card(song.stop)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 300)
	c.add_child(pic)
	c.add_child(UIKit.label(UIKit.song_title(song), UIKit.PAPER_HEADER))
	var line := tr("diff_" + str(pick.difficulty))
	if pick.get("mirror", false):
		line += " · " + tr("daily_mirrored")
	c.add_child(UIKit.label(line, UIKit.PAPER))
	var best: Dictionary = Profile.best(song.id, str(pick.difficulty))
	var today := int(Profile.daily_best(date_key).get("score", -1))
	var info := UIKit.label("", UIKit.CAPTION)
	info.name = "Best"
	if today > 0:
		info.text = tr("daily_best_today") % UIKit.fmt_score(today)
	elif not best.is_empty():
		info.text = tr("stop_best") % [UIKit.fmt_score(int(best.get("score", 0))), int(best.get("bells", 0))]
	else:
		info.text = tr("daily_first")
	box.add_child(info)
	var play := UIKit.button(tr("daily_play"), _play.bind(song), UIKit.PRIMARY)
	play.name = "Play"
	cols[1].add_child(play)
	var boards := UIKit.button(tr("title_boards"), func() -> void: app.open("boards"), UIKit.QUIET)
	boards.name = "Boards"
	box.add_child(boards)


func _play(song: SongData) -> void:
	app.open("play", {
		"song_id": song.id,
		"difficulty": str(pick.difficulty),
		"bell_set": str(Profile.get_look().get("bell_set", "light")),
		"mirror": bool(pick.get("mirror", false)),
		"daily": date_key,
	})
