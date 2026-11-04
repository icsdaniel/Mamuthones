extends Screen
## The card before a story stop, no pictures: the stop's name, day and best grade, two plain sentences
## about the moment, its versions as tabs (a stop with recordings), the difficulties as rows with
## their best, the remix chip, and Play at the foot.
## args: song_id.

static var last_difficulty := "easy"

var song: SongData
var difficulty := "easy"
var use_remix := false
var _diff_buttons := {}


func build() -> void:
	song = SongLibrary.get_song(args.get("song_id", ""))
	if song == null:
		push_error("stop card: unknown song %s" % args.get("song_id", ""))
		return
	difficulty = last_difficulty if last_difficulty in song.difficulties() else song.difficulties()[0]
	var cols := UIKit.column_with_footer(self, 16)
	var box := cols[0]
	var foot := cols[1]
	UIKit.header(box, tr("stop_n") % song.stop, on_back)
	var facts := UIKit.card(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	facts.add_child(head)
	var tit := UIKit.label(UIKit.song_title(song), UIKit.HEADER)
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tit)
	var grade := GradeBadge.new(UIKit.best_grade(song.id), false, UIKit.any_full_combo(song.id))
	grade.name = "Grade"
	grade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(grade)
	if UIKit.stop_date(song) != "":
		facts.add_child(UIKit.label(UIKit.stop_date(song), UIKit.SUB))
	facts.add_child(UIKit.label(tr("stop_fact_%d" % song.stop)))

	if song.kind == "tutorial":
		var lessons := UIKit.button(tr("stop_lessons"), func() -> void: app.open("tutorial", {"song_id": song.id}), UIKit.PRIMARY)
		lessons.name = "Lessons"
		foot.add_child(lessons)

	# A stop with recorded versions: which one to play, as tabs (each its own song and bests)
	var vs := SongLibrary.versions(song)
	if vs.size() > 1:
		box.add_child(UIKit.label(tr("stop_version"), UIKit.SUB))
		var items := []
		for v in vs:
			items.append([v.id, tr("version_practice") if v.kind == "tutorial" else tr("version_" + (v.version if v.version != "" else "original"))])
		var tabs := UIKit.tabs(box, items, song.id, func(id: String) -> void:
			if id != song.id:
				app.replace("stop_card", {"song_id": id}))
		tabs.name = "Versions"

	# The difficulty heading carries the Remix chip once it is earned, so the reason to replay is in
	# view next to the difficulty buttons.
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	box.add_child(dh)
	var dl := UIKit.label(tr("stop_difficulty"), UIKit.SUB)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	if song.has_remix() and Progression.remix_unlocked(song.id):
		var chip := UIKit.button(tr("stop_remix_chip"), func() -> void: pass)
		chip.toggle_mode = true
		chip.name = "Remix"
		chip.custom_minimum_size.x = 200
		chip.toggled.connect(func(on: bool) -> void: use_remix = on)
		dh.add_child(chip)
	for d in song.difficulties():
		var best: Dictionary = Profile.best(song.id, d)
		var badge := GradeBadge.new(UIKit.grade_of(best), false, bool(best.get("full_combo", false)))
		var cap := tr("stop_no_best") if best.is_empty() else UIKit.fmt_score(int(best.get("score", 0)))
		var b := UIKit.list_row("", tr("diff_" + d), cap, badge, "open", _pick.bind(d))
		b.toggle_mode = true
		b.name = "Diff_" + d
		box.add_child(b)
		_diff_buttons[d] = b
	if song.has_remix() and not Progression.remix_unlocked(song.id):
		var r := UIKit.label(tr("stop_remix_locked"), UIKit.CAPTION)
		r.name = "RemixLocked"
		box.add_child(r)
	var play := UIKit.button(tr("stop_play"), _play, "" if song.kind == "tutorial" else UIKit.PRIMARY)
	play.name = "Play"
	foot.add_child(play)
	_pick(difficulty)


func _pick(d: String) -> void:
	difficulty = d
	last_difficulty = d
	for k in _diff_buttons:
		UIKit.row_select(_diff_buttons[k], k == d)


func _play() -> void:
	app.open("play", {
		"song_id": song.id,
		"difficulty": difficulty,
		"remix": use_remix,
	})
