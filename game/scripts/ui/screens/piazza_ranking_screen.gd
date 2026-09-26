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
	var box := UIKit.column(self, true, 14)
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
	for rank in range(1, order.size()):
		var i := order[rank]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = UIKit.TOUCH
		row.add_child(UIKit.label("%d." % (rank + 1), UIKit.SUB, false))
		var n := UIKit.label(str(players[i]), "", false)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(n)
		row.add_child(UIKit.label(UIKit.fmt_score(int(scores[i])), UIKit.SUB, false))
		box.add_child(row)
		UIKit.pop_in(row, 0.4 + rank * 0.15)
	Sound.ui("result")
	var again := UIKit.button(tr("piazza_again"), _again, UIKit.PRIMARY)
	again.name = "Again"
	box.add_child(again)
	var done := UIKit.button(tr("ui_done"), on_back, UIKit.QUIET)
	done.name = "Done"
	box.add_child(done)


func _again() -> void:
	var round: Dictionary = args.get("round", {}).duplicate(true)
	var scores: Array[int] = []
	scores.resize((round.players as Array).size())
	scores.fill(0)
	round.scores = scores
	round.turn = 0
	app.replace("piazza", {"round": round})
