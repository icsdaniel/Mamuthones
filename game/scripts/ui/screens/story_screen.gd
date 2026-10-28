extends Screen
## The story: a plain vertical list of the stops, one row each (number, name, day, best grade over
## its versions), the next stop marked and the locked ones dimmed, a goal card on top and a Play
## button at the foot. No pictures.

func build() -> void:
	var cols := UIKit.column_with_footer(self, 12)
	var box := cols[0]
	var foot := cols[1]
	UIKit.header(box, tr("story_title"), on_back)
	var goal := UIKit.goal_text()
	if goal != "":
		var g := UIKit.card(box)
		g.add_child(UIKit.label(tr("story_next_goal"), UIKit.SUB))
		g.add_child(UIKit.label(goal))
	var next_id := Progression.next_stop()
	for song in SongLibrary.story():
		box.add_child(_row(song, song.id == next_id))
	UIKit.spacer(box, 8.0)
	var next_song := SongLibrary.get_song(next_id)
	if next_song != null:
		var go := UIKit.button(tr("title_continue") % UIKit.song_title(next_song), func() -> void: app.open("stop_card", {"song_id": next_id}), UIKit.PRIMARY)
		go.name = "PlayNext"
		foot.add_child(go)


func _row(song: SongData, is_next: bool) -> Control:
	var open := Progression.is_unlocked(song.id)
	# the stop's best over all its versions (SongLibrary.versions)
	var best := -1
	var fc := false
	for v in SongLibrary.versions(song):
		best = maxi(best, UIKit.best_grade(v.id))
		fc = fc or UIKit.any_full_combo(v.id)
	var grade := GradeBadge.new(best, false, fc)
	grade.name = "Grade"
	grade.visible = open
	var state := "next" if is_next else ("open" if open else "locked")
	var b := UIKit.list_row(str(song.stop), UIKit.song_title(song), _status(song, open, is_next), grade, state,
		func() -> void: app.open("stop_card", {"song_id": song.id}))
	b.name = "Stop%d" % song.stop
	return b


func _status(song: SongData, open: bool, is_next: bool) -> String:
	if not open:
		return tr("story_locked")
	var parts: Array[String] = []
	var date := UIKit.stop_date(song)
	if date != "":
		parts.append(date)
	if is_next:
		parts.append(tr("story_next"))
	elif Progression.cleared(song.id):
		parts.append(tr("story_cleared"))
	if song.has_remix() and Progression.remix_unlocked(song.id):
		parts.append(tr("story_remix_open"))
	return " · ".join(parts)
