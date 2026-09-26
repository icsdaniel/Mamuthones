class_name Progression
extends RefCounted
## What the player has unlocked, worked out from their bests (docs/design.md sections 5 and 6).
## Nothing is stored here: everything follows from Profile's bests, so it can never get out of step.
##
## Every function is static and takes an optional trailing `profile` (anything with best(song, diff)
## and all_bests()); by default it uses the Profile autoload.
##
## Rules:
## - Story stops unlock in order: stop n+1 when stop n is finished with at least 1 bell (any level);
##   the Workshop also counts as finished when the tutorial is done.
## - A stop's remix unlocks when the stop is finished at Hard or Expert with at least 2 bells.
## - Piazza tracks unlock when the Workshop (stop 1) is finished.
## - Bell sets: Light from the start, Village when stop 3 is reached, Full load when stop 6 is reached.
## - Carving points = every bell earned: the sum of best bells over every song and difficulty.
##   They are a threshold, never spent.
## - Mask options: MaskSpec.requirement(part, option) -> {stop, cost}: unlocked when that stop is
##   reached and carving_points() >= cost. Without MaskSpec only the first option of a part is open.
##
## Additions beyond the architecture doc: story_order(), cleared(), highest_stop(), next_stop(),
## next_goals(), snapshot().

const REMIX_LEVELS: Array[String] = ["hard", "expert"]
const REMIX_BELLS := 2
const CLEAR_BELLS := 1
const BELL_SET_STOPS := {"light": 1, "village": 3, "full": 6}

static var _mask_spec: Variant = null
static var _mask_spec_checked := false


static func story_order() -> Array[String]:
	var out: Array[String] = []
	for s in SongLibrary.story():
		out.append(s.id)
	return out


## Best bells on a song (base id or remix id) over the given difficulties (all when empty).
static func best_bells(song_key: String, difficulties: Array = [], profile: Variant = null) -> int:
	var p: Variant = _profile(profile)
	if p == null:
		return 0
	var diffs: Array = difficulties
	if diffs.is_empty():
		var s := SongLibrary.get_song(song_key)
		diffs = s.difficulties() if s != null else SongData.DIFFICULTIES
	var most := 0
	for d in diffs:
		var b: Dictionary = p.best(song_key, d)
		most = maxi(most, int(b.get("bells", 0)))
	return most


## A stop is finished with 1 bell at any level. The Workshop (tutorial) is also finished once
## the tutorial is done (Profile flag "tutorial_done"), since it is played lesson by lesson.
static func cleared(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s != null and s.kind == "tutorial":
		var p: Variant = _profile(profile)
		if p != null and p.has_method("has_flag") and p.has_flag("tutorial_done"):
			return true
	return best_bells(song_id, [], profile) >= CLEAR_BELLS


static func is_unlocked(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s == null:
		return false
	if s.id != song_id:
		return remix_unlocked(s.id, profile)
	if s.kind == "piazza":
		var order := story_order()
		return order.is_empty() or cleared(order[0], profile)
	var story := story_order()
	var i := story.find(song_id)
	if i <= 0:
		return true
	return cleared(story[i - 1], profile)


## Accepts the base song id or the remix id.
static func remix_unlocked(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s == null or not s.has_remix():
		return false
	return best_bells(s.id, REMIX_LEVELS, profile) >= REMIX_BELLS


## The highest story stop number reached (unlocked).
static func highest_stop(profile: Variant = null) -> int:
	var top := 1
	for s in SongLibrary.story():
		if is_unlocked(s.id, profile):
			top = maxi(top, s.stop)
	return top


static func bell_set_unlocked(id: String, profile: Variant = null) -> bool:
	if not BELL_SET_STOPS.has(id):
		return false
	return highest_stop(profile) >= BELL_SET_STOPS[id]


static func carving_points(profile: Variant = null) -> int:
	var p: Variant = _profile(profile)
	if p == null:
		return 0
	var total := 0
	var bests: Dictionary = p.all_bests()
	for k in bests:
		var e = bests[k]
		if e is Dictionary:
			total += clampi(int(e.get("bells", 0)), 0, 3)
	return total


static func mask_option_unlocked(part: String, option: String, profile: Variant = null) -> bool:
	var spec: Variant = _spec()
	if spec == null:
		return false
	var opts: Array = spec.options(part)
	if not option in opts:
		return false
	if opts.find(option) == 0:
		return true
	var req: Dictionary = spec.requirement(part, option)
	return highest_stop(profile) >= int(req.get("stop", 1)) and carving_points(profile) >= int(req.get("cost", 0))


## The first story stop that is open but not finished yet ("" when all are finished).
static func next_stop(profile: Variant = null) -> String:
	for id in story_order():
		if is_unlocked(id, profile) and not cleared(id, profile):
			return id
	return ""


## What the player is working towards, nearest first. Each entry:
## {kind: "song"|"remix"|"bell_set"|"mask", id, part (mask only), need: {...}, have: {...}}.
## need/have use the keys song_id, difficulty ("hard" means Hard or Expert), bells, stop, points.
static func next_goals(profile: Variant = null) -> Array:
	var out := []
	var story := story_order()
	var ns := next_stop(profile)
	if ns != "":
		var i := story.find(ns)
		if i + 1 < story.size():
			out.append({"kind": "song", "id": story[i + 1], "need": {"song_id": ns, "bells": CLEAR_BELLS}, "have": {"bells": best_bells(ns, [], profile)}})
	var stop := highest_stop(profile)
	for id in BellSets.ids():
		if not bell_set_unlocked(id, profile):
			out.append({"kind": "bell_set", "id": id, "need": {"stop": BELL_SET_STOPS[id]}, "have": {"stop": stop}})
			break
	var remixes := []
	for id in story:
		var s := SongLibrary.get_song(id)
		if s.has_remix() and cleared(id, profile) and not remix_unlocked(id, profile):
			remixes.append({"kind": "remix", "id": s.remix_id(), "need": {"song_id": id, "difficulty": "hard", "bells": REMIX_BELLS}, "have": {"bells": best_bells(id, REMIX_LEVELS, profile)}})
	remixes.sort_custom(func(a, b): return a.have.bells > b.have.bells)
	out.append_array(remixes)
	var spec: Variant = _spec()
	if spec != null and _has_func(spec, "unlock_order"):
		var points := carving_points(profile)
		for e in spec.unlock_order():
			if not mask_option_unlocked(str(e.part), str(e.option), profile):
				out.append({"kind": "mask", "id": str(e.option), "part": str(e.part), "need": {"stop": int(e.get("stop", 1)), "points": int(e.get("cost", 0))}, "have": {"stop": stop, "points": points}})
				break
	return out


## Everything unlocked right now as a set of keys ("song:id", "remix:id", "bell_set:id",
## "mask:part/option"), so Profile can tell what a result just unlocked.
static func snapshot(profile: Variant = null) -> Dictionary:
	var out := {}
	for s in SongLibrary.all():
		if is_unlocked(s.id, profile):
			out["song:" + s.id] = true
		if s.has_remix() and remix_unlocked(s.id, profile):
			out["remix:" + s.remix_id()] = true
	for id in BellSets.ids():
		if bell_set_unlocked(id, profile):
			out["bell_set:" + id] = true
	var spec: Variant = _spec()
	if spec != null and (spec as Script).get_script_constant_map().has("PARTS"):
		for part in (spec as Script).get_script_constant_map()["PARTS"]:
			for opt in spec.options(part):
				if mask_option_unlocked(part, opt, profile):
					out["mask:%s/%s" % [part, opt]] = true
	return out


static func _profile(profile: Variant) -> Variant:
	if profile != null:
		return profile
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Profile")


## Art's MaskSpec, looked up by name so Core still loads before (or without) it.
static func _spec() -> Variant:
	if not _mask_spec_checked:
		_mask_spec_checked = true
		for c in ProjectSettings.get_global_class_list():
			if c["class"] == "MaskSpec":
				var script = load(c["path"])
				if script is Script and _has_func(script, "options") and _has_func(script, "requirement"):
					_mask_spec = script
	return _mask_spec


static func _has_func(script: Script, fname: String) -> bool:
	for m in script.get_script_method_list():
		if m.name == fname:
			return true
	return false
