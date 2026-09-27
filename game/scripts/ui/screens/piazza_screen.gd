extends Screen
## Piazza, pass-and-play. Setup: up to six named players (remembered on the phone) and the round.
## Between turns the same screen shows whose turn it is, so the phone can be passed. After the last
## turn it moves on to the ranking.
## args: round (Dictionary, set while a round is running): {song_id, players: [names], scores: [ints],
## turn: int}.

const MAX_PLAYERS := 6

var _names: Array[String] = []
var _list: VBoxContainer
var _start: Button
var _count: Label


func build() -> void:
	var round: Dictionary = args.get("round", {})
	if round.is_empty():
		_build_setup()
	else:
		_build_handover(round)


func _build_setup() -> void:
	_names.assign(Profile.piazza_players())
	if _names.is_empty():
		_names = [tr("piazza_player_n") % 1, tr("piazza_player_n") % 2]
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	UIKit.header(box, tr("piazza_title"), on_back)
	# The square at night, the whole row ringing: what the round will feel like.
	var scene := ProcessionScene.new()
	scene.name = "Scene"
	scene.custom_minimum_size = Vector2(0, 280)
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.auto_bpm = 76.0
	box.add_child(scene)
	scene.set_stop(6)
	scene.set_unison(4)
	scene.set_reduced_motion(UIKit.reduced_motion())
	UIKit.show_look(scene)
	Sound.ambience("crowd+fire")
	box.add_child(UIKit.label(tr("piazza_intro"), ""))
	# How a round goes, in three short steps.
	var how := UIKit.card(box, true)
	how.name = "HowItWorks"
	how.add_child(UIKit.label(tr("piazza_how_title"), UIKit.PAPER_HEADER))
	for i in 3:
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 12)
		var n := UIKit.label(str(i + 1), UIKit.PAPER_HEADER, false)
		n.custom_minimum_size.x = 34
		step.add_child(n)
		var t := UIKit.label(tr("piazza_step_%d" % (i + 1)), UIKit.PAPER)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step.add_child(t)
		how.add_child(step)
	var ph := HBoxContainer.new()
	box.add_child(ph)
	var pl := UIKit.label(tr("piazza_players"), UIKit.SUB, false)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	_count = UIKit.label("", UIKit.CAPTION, false)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_count)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)
	var add := UIKit.button(tr("piazza_add"), _add_player, UIKit.QUIET)
	add.name = "AddPlayer"
	box.add_child(add)
	_start = UIKit.button(tr("piazza_start"), _start_round, UIKit.PRIMARY)
	_start.name = "Start"
	cols[1].add_child(_start)
	_rebuild_list()


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for i in _names.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		# Each player's place in the row, as a small bell.
		var mark := BellMarks.new(1, 34.0)
		mark.total = 1
		mark.custom_minimum_size = Vector2(44, UIKit.TOUCH)
		row.add_child(mark)
		var edit := LineEdit.new()
		edit.text = _names[i]
		edit.max_length = 14
		edit.custom_minimum_size.y = UIKit.TOUCH
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.name = "Name%d" % i
		edit.text_changed.connect(func(t: String) -> void: _names[i] = t)
		row.add_child(edit)
		var rm := UIKit.button(tr("piazza_remove"), _remove_player.bind(i), UIKit.QUIET)
		rm.disabled = _names.size() <= 1
		rm.name = "Remove%d" % i
		row.add_child(rm)
		_list.add_child(row)
	var add := find_child("AddPlayer", true, false) as Button
	if add != null:
		add.disabled = _names.size() >= MAX_PLAYERS
	if _count != null:
		_count.text = tr("piazza_count") % [_names.size(), MAX_PLAYERS]


func _add_player() -> void:
	if _names.size() < MAX_PLAYERS:
		_names.append(tr("piazza_player_n") % (_names.size() + 1))
		_rebuild_list()


func _remove_player(i: int) -> void:
	if _names.size() > 1:
		_names.remove_at(i)
		_rebuild_list()


func _start_round() -> void:
	var names: Array[String] = []
	for i in _names.size():
		var n := _names[i].strip_edges()
		names.append(n if n != "" else tr("piazza_player_n") % (i + 1))
	Profile.set_piazza_players(names)
	var songs := SongLibrary.piazza()
	if songs.is_empty():
		UIKit.toast(self, tr("piazza_no_song"))
		return
	var scores: Array[int] = []
	scores.resize(names.size())
	scores.fill(0)
	var round := {"song_id": songs[randi() % songs.size()].id, "players": names, "scores": scores, "turn": 0}
	app.replace("piazza", {"round": round})


func _build_handover(round: Dictionary) -> void:
	var players: Array = round.players
	var turn: int = round.turn
	if turn >= players.size():
		app.replace.call_deferred("piazza_ranking", {"round": round})
		return
	var box := UIKit.column(self, false, 24)
	UIKit.header(box, tr("piazza_title"), on_back)
	var scene := ProcessionScene.new()
	scene.custom_minimum_size = Vector2(0, 300)
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.auto_bpm = 76.0
	box.add_child(scene)
	scene.set_stop(6)
	scene.set_unison(4)
	scene.set_reduced_motion(UIKit.reduced_motion())
	UIKit.show_look(scene)
	Sound.ambience("crowd+fire")
	if turn > 0:
		box.add_child(UIKit.label(tr("piazza_last") % [players[turn - 1], UIKit.fmt_score(int(round.scores[turn - 1]))],
			UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label(tr("piazza_pass_to"), UIKit.SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	var who := UIKit.label(str(players[turn]), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER)
	who.name = "Player"
	box.add_child(who)
	box.add_child(UIKit.label(tr("piazza_how"), "", true, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.spacer(box, 0, true)
	var go := UIKit.button(tr("piazza_ready") % players[turn], func() -> void:
		app.replace("play", {"song_id": round.song_id, "difficulty": "piazza", "bell_set": "light",
			"piazza": true, "round": round}), UIKit.PRIMARY)
	go.name = "Ready"
	box.add_child(go)


func on_back() -> void:
	if args.get("round", {}).is_empty():
		app.back()
	else:
		UIKit.confirm(self, tr("piazza_quit_q"), tr("piazza_quit"), func() -> void: app.back())
