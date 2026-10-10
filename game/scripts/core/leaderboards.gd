extends Node
## Autoload `Leaderboards`: friends' scores and a global ladder, never required (design section 10).
##
## Every score is always kept on the phone (a local top 10 per board in user://leaderboards.cfg),
## so the ladders work offline. When an online backend is present (Game Center on
## iOS, Google Play Games on Android, detected from their engine plugins at start), scores are also
## sent there and show() opens the platform's own ladder.
##
## API:
##   available() -> bool           true: the local ladder always works
##   online() -> bool              an online backend is signed in
##   submit(board_id, score) -> int   local rank (1 = top), 0 if not in the local top 10
##   show(board_id := "")          platform ladder when online, else emits show_requested(board_id)
##   local_scores(board_id) -> Array of {score, date}, best first
##   best(board_id) -> int
##   board_id(song_key, difficulty) -> "song.<key>.<difficulty>"
##   set_backend(obj)              anything with available(), submit(platform_id, score), show(platform_id)
##   platform_ids: Dictionary      board_id -> the id configured in App Store Connect / Play Console
##
## Online backends are thin wrappers checked only in headless tests here; verify them on a device
## after the plugins are added at export time.

signal show_requested(board_id: String)
signal submitted(board_id: String, score: int, rank: int)

const PATH := "user://leaderboards.cfg"
const KEEP := 10

var path := PATH
var backend: Object = null
## Board ids as configured on each platform; missing entries use the board id itself.
var platform_ids: Dictionary = {}
var _boards: Dictionary = {}


func _ready() -> void:
	load_boards(path)
	if backend == null:
		backend = _detect_backend()


func available() -> bool:
	return true


func online() -> bool:
	return backend != null and backend.available()


static func board_id(song_key: String, difficulty: String) -> String:
	return "song.%s.%s" % [song_key, difficulty]


func set_backend(b: Object) -> void:
	backend = b


func submit(id: String, score: int) -> int:
	if id == "" or score < 0:
		return 0
	var list: Array = _boards.get(id, [])
	var entry := {"score": score, "date": Time.get_date_string_from_system(true)}
	var rank := 0
	for i in list.size():
		if score > int(list[i].score):
			rank = i + 1
			break
	if rank == 0 and list.size() < KEEP:
		rank = list.size() + 1
	if rank > 0:
		list.insert(rank - 1, entry)
		if list.size() > KEEP:
			list.resize(KEEP)
		_boards[id] = list
		_save()
	if online():
		backend.submit(platform_id(id), score)
	submitted.emit(id, score, rank)
	return rank


func show(id := "") -> void:
	if online():
		backend.show(platform_id(id))
	else:
		show_requested.emit(id)


## The id a board has on Game Center / Play Games.
func platform_id(id: String) -> String:
	if platform_ids.has(id):
		return platform_ids[id]
	return id


func local_scores(id: String) -> Array:
	return (_boards.get(id, []) as Array).duplicate(true)


func best(id: String) -> int:
	var list: Array = _boards.get(id, [])
	return int(list[0].score) if not list.is_empty() else 0


func load_boards(p_path := PATH) -> void:
	path = p_path
	_boards = {}
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return
	var b = cfg.get_value("boards", "values", {})
	if not (b is Dictionary):
		return
	for k in b:
		var list = b[k]
		if not (list is Array):
			continue
		var clean := []
		for e in list:
			if e is Dictionary and typeof(e.get("score")) in [TYPE_INT, TYPE_FLOAT]:
				clean.append({"score": int(e.score), "date": str(e.get("date", ""))})
		clean.sort_custom(func(x, y): return x.score > y.score)
		_boards[str(k)] = clean.slice(0, KEEP)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("boards", "values", _boards)
	cfg.save(path)


func _detect_backend() -> Object:
	if Engine.has_singleton("GameCenter"):
		return GameCenterBackend.new(Engine.get_singleton("GameCenter"))
	for n in ["GodotPlayGameServices", "GodotGooglePlayGameServices"]:
		if Engine.has_singleton(n):
			return PlayGamesBackend.new(Engine.get_singleton(n))
	return null


## Game Center through the official godot-ios-plugins GameCenter plugin.
class GameCenterBackend:
	var gc: Object
	var signed_in := false

	func _init(p_gc: Object) -> void:
		gc = p_gc
		if gc.has_method("authenticate"):
			gc.authenticate()
		signed_in = gc.has_method("is_authenticated") and gc.is_authenticated()

	func available() -> bool:
		if not signed_in and gc.has_method("is_authenticated"):
			signed_in = gc.is_authenticated()
		return signed_in

	func submit(id: String, score: int) -> void:
		gc.post_score({"score": score, "category_id": id})

	func show(id: String) -> void:
		var args := {"view": "leaderboards"}
		if id != "":
			args["leaderboard_name"] = id
		gc.show_game_center(args)


## Google Play Games through the Godot Play Game Services plugin.
class PlayGamesBackend:
	var pg: Object

	func _init(p_pg: Object) -> void:
		pg = p_pg
		if pg.has_method("initialize"):
			pg.initialize()

	func available() -> bool:
		return pg.has_method("isAuthenticated") and pg.isAuthenticated()

	func submit(id: String, score: int) -> void:
		if pg.has_method("leaderboardsSubmitScore"):
			pg.leaderboardsSubmitScore(id, score)

	func show(id: String) -> void:
		if id != "" and pg.has_method("leaderboardsShowForLeaderboard"):
			pg.leaderboardsShowForLeaderboard(id, 2, 0)
		elif pg.has_method("leaderboardsShowAll"):
			pg.leaderboardsShowAll()
