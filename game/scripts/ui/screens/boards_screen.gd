extends Screen
## Leaderboards: your own bests on this phone, per song and difficulty, and the online ladders
## (Game Center / Google Play Games) when they are available. Nothing here needs the internet.


func build() -> void:
	var box := UIKit.column(self, true, 12)
	UIKit.header(box, tr("boards_title"), on_back)
	var online := UIKit.button(tr("boards_online"), func() -> void: Leaderboards.show(), UIKit.PRIMARY)
	online.name = "Online"
	online.disabled = not Leaderboards.available()
	box.add_child(online)
	if not Leaderboards.available():
		box.add_child(UIKit.label(tr("boards_offline"), UIKit.CAPTION))
	box.add_child(UIKit.label(tr("boards_local"), UIKit.SUB))
	var any := false
	for song in SongLibrary.story():
		if not Progression.is_unlocked(song.id):
			continue
		var c := UIKit.card(box)
		c.add_child(UIKit.label(UIKit.song_title(song), UIKit.SUB))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		c.add_child(grid)
		for d in song.difficulties():
			var best: Dictionary = Profile.best(song.id, d)
			grid.add_child(UIKit.label(tr("diff_" + d), "", false))
			var score := UIKit.label(UIKit.fmt_score(int(best.get("score", 0))) if not best.is_empty() else "—", "", false)
			score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(score)
			grid.add_child(GradeBadge.new(UIKit.grade_of(best), false, bool(best.get("full_combo", false))))
			any = any or not best.is_empty()
	if not any:
		box.add_child(UIKit.label(tr("boards_empty"), UIKit.CAPTION))
