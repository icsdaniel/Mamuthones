extends Screen
## End of a Piazza round: everyone ranked by score, the winner first and rung in with the bells.
## args: round {song_id, players, scores, turn}.


func build() -> void:
	var round: Dictionary = args.get("round", {})
	var players: Array = round.get("players", [])
	var scores: Array = round.get("scores", [])
	var order: Array[int] = []
	for i in players.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return int(scores[a]) > int(scores[b]))
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	UIKit.header(box, tr("piazza_ranking"), on_back)
	if not order.is_empty():
		var win := UIKit.card(box, true)
		win.add_child(UIKit.label(tr("piazza_winner"), UIKit.PAPER, true, HORIZONTAL_ALIGNMENT_CENTER))
		var name_label := UIKit.label(str(players[order[0]]), UIKit.PAPER_HEADER, true, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.name = "Winner"
		win.add_child(name_label)
		win.add_child(UIKit.label(UIKit.fmt_score(int(scores[order[0]])), UIKit.PAPER, true, HORIZONTAL_ALIGNMENT_CENTER))
		var bells := BellMarks.new(3, 52.0)
		bells.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		win.add_child(bells)
		bells.animate(0.3)
	# The row rings the winner in: the procession at full unison, in the piazza.
	var scene := ProcessionScene.new()
	scene.name = "Procession"
	# The procession takes the room the list leaves, so the page is full at any height.
	var vh := get_viewport_rect().size.y if is_inside_tree() else 1440.0
	scene.custom_minimum_size = Vector2(0, clampf(vh - 840.0 - 68.0 * maxf(order.size() - 1, 0), 240.0, 520.0))
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.auto_bpm = 76.0
	box.add_child(scene)
	scene.set_stop(6)
	scene.set_unison(4)
	scene.set_reduced_motion(UIKit.reduced_motion())
	UIKit.show_look(scene)
	var list: VBoxContainer = null
	if order.size() > 1:
		var card := UIKit.card(box)
		card.name = "Others"
		list = VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		card.add_child(list)
	for rank in range(1, order.size()):
		var i := order[rank]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 64
		row.add_theme_constant_override("separation", 12)
		row.add_child(UIKit.label("%d." % (rank + 1), UIKit.SUB, false))
		var n := UIKit.label(str(players[i]), "", false)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(n)
		row.add_child(UIKit.label(UIKit.fmt_score(int(scores[i])), UIKit.SUB, false))
		list.add_child(row)
		UIKit.pop_in(row, 0.4 + rank * 0.15)
	Sound.ui("result")
	var again := UIKit.button(tr("piazza_again"), _again, UIKit.PRIMARY)
	again.name = "Again"
	cols[1].add_child(again)
	var done := UIKit.button(tr("ui_done"), on_back, UIKit.QUIET)
	done.name = "Done"
	cols[1].add_child(done)


func _again() -> void:
	var round: Dictionary = args.get("round", {}).duplicate(true)
	var scores: Array[int] = []
	scores.resize((round.players as Array).size())
	scores.fill(0)
	round.scores = scores
	round.turn = 0
	app.replace("piazza", {"round": round})
