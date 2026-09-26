class_name Daily
extends RefCounted
## The daily procession, offline: the date alone picks a song, a difficulty and whether the lanes
## are mirrored, so every copy of the game (same version) plays the same procession on the same day.
## Uses its own FNV-1a hash (not Godot's hash(), which may change between engine versions) and
## the UTC date, so friends in different time zones share it.
##
## Additions beyond the architecture doc: today(), key(date), board_id(date), matches(session),
## session_options(date),
## and "key" in the for_date() result.

const BOARD_ID := "daily"


## {song_id, difficulty, mirror, key}. Picks from all story songs (not the tutorial), locked or
## not, so everyone gets the same one. Each song comes once every n days (n = number of songs),
## never the same song two days running.
static func for_date(date: Dictionary) -> Dictionary:
	var songs := _pool()
	var k := key(date)
	if songs.is_empty():
		return {"song_id": "", "difficulty": "", "mirror": false, "key": k}
	var h := _fnv(k)
	var song: SongData = songs[_song_index(date, songs.size())]
	var diffs: Array[String] = []
	for d in song.difficulties():
		if d in SongData.DIFFICULTIES:
			diffs.append(d)
	var diff := diffs[(h >> 8) % diffs.size()] if not diffs.is_empty() else ""
	return {"song_id": song.id, "difficulty": diff, "mirror": ((h >> 16) & 1) == 1, "key": k}


# Songs come in cycles: every n days each song plays once, in an order shuffled by the cycle's
# hash, and a cycle never starts with the song that ended the one before.
static func _song_index(date: Dictionary, n: int) -> int:
	var day := _day_number(date)
	var cycle := floori(day / float(n))
	var order := _cycle_order(cycle, n)
	if n > 1:
		var before := _cycle_order(cycle - 1, n)
		if order[0] == before[n - 1]:
			var first: int = order[0]
			order[0] = order[1]
			order[1] = first
	return order[day - cycle * n]


static func _cycle_order(cycle: int, n: int) -> Array[int]:
	var order: Array[int] = []
	for i in n:
		order.append(i)
	var h := _fnv("cycle %d" % cycle)
	for i in range(n - 1, 0, -1):   # Fisher-Yates driven by a hash chain
		h = _fnv(str(h))
		var j := h % (i + 1)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


static func _day_number(date: Dictionary) -> int:
	var unix := Time.get_unix_time_from_datetime_dict({"year": int(date.get("year", 1970)), "month": int(date.get("month", 1)), "day": int(date.get("day", 1)), "hour": 12, "minute": 0, "second": 0})
	return floori(unix / 86400.0)


static func today() -> Dictionary:
	return for_date(Time.get_date_dict_from_system(true))


static func key(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date.get("year", 1970)), int(date.get("month", 1)), int(date.get("day", 1))]


## The ladder of one day's procession: "daily.YYYY-MM-DD" (today when no date is given). Online,
## Leaderboards sends every daily.* board to the platform's one recurring "daily" board.
static func board_id(date: Dictionary = {}) -> String:
	return "%s.%s" % [BOARD_ID, key(date if not date.is_empty() else Time.get_date_dict_from_system(true))]


## Whether a session is the procession of the day it claims (song, difficulty and mirror match).
static func matches(session: Session) -> bool:
	if session.daily == "":
		return false
	var parts := session.daily.split("-")
	if parts.size() != 3:
		return false
	var d := for_date({"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int()})
	return d.key == session.daily and d.song_id == session.song.id and not session.remix \
		and d.difficulty == session.difficulty and d.mirror == session.mirror


## Session options for a day's procession: {"mirror": .., "daily": "YYYY-MM-DD"}.
static func session_options(date: Dictionary) -> Dictionary:
	var d := for_date(date)
	return {"mirror": d.mirror, "daily": d.key}


static func _pool() -> Array[SongData]:
	var out: Array[SongData] = []
	for s in SongLibrary.story():
		if s.kind == "story" and not s.difficulties().is_empty():
			out.append(s)
	out.sort_custom(func(a: SongData, b: SongData) -> bool: return a.id < b.id)
	return out


## 32-bit FNV-1a over the UTF-8 bytes, then an avalanche so nearby dates spread out.
static func _fnv(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	h ^= h >> 16
	h = (h * 0x7feb352d) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x846ca68b) & 0xFFFFFFFF
	h ^= h >> 16
	return h
