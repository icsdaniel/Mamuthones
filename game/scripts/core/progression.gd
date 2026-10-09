class_name Progression
extends RefCounted
## What the player has unlocked, worked out from their bests (docs/design.md sections 5 and 6).
## Nothing is stored here: everything follows from Profile's bests, so it can never get out of step.
##
## Every function is static and takes an optional trailing `profile` (anything with best(song, diff)
## and all_bests()); by default it uses the Profile autoload.
##
## Rules:
## - Grades (Session.GRADES): F, E, D, C, B, A, S, S+, kept per song and difficulty as a rank 0..7.
## - Every song is playable from the start, at every difficulty (Daniele, 2026-10-09). The story
##   still has an order: a stop is finished with a D or better (any level), the Workshop also when
##   the tutorial is done, and the stop the story has reached (highest_stop) is the first one whose
##   earlier stops are all finished. It sets the bell sets and mask carving, as before.
## - A stop's remix unlocks when the stop is finished at Hard or Expert with a B or better.
## - Bell sets: Light from the start, Village when stop 3 is reached, Full load when stop 6 is reached.
## - Carving points come from the best grade of every song and difficulty: 1 for a D or C, 2 for a B
##   or A, 3 for an S or S+ (GRADE_POINTS). They are a threshold, never spent.
## - Mask options: MaskSpec.requirement(part, option) -> {stop, cost}: unlocked when that stop is
##   reached and carving_points() >= cost. Without MaskSpec only the first option of a part is open.
##
## Additions beyond the architecture doc: story_order(), cleared(), highest_stop(), next_stop(),
## next_goals(), snapshot().

const REMIX_LEVELS: Array[String] = ["hard", "expert"]
const REMIX_GRADE := Session.RANK_B
const CLEAR_GRADE := Session.RANK_D
## Carving points for each grade rank (F, E, D, C, B, A, S, S+).
const GRADE_POINTS: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
const BELL_SET_STOPS := {"light": 1, "village": 3, "full": 6}

static var _mask_spec: Variant = null
static var _mask_spec_checked := false


static func story_order() -> Array[String]:
	var out: Array[String] = []
	for s in SongLibrary.story():
		out.append(s.id)
	return out


## The grade rank (0..7) of a saved best. Bests saved before grades existed carry only their
## accuracy (and bells): they get the grade their accuracy earns (never S+, which needs a full combo).
static func entry_grade(e: Dictionary) -> int:
	if e.has("grade"):
		return clampi(int(e.grade), 0, Session.GRADES.size() - 1)
	if e.has("accuracy"):
		return Session.rank_for(float(e.accuracy), false)
	return 0


## Best grade rank on a song (base id or remix id) over the given difficulties (all when empty);
## -1 when it has never been played there.
static func best_grade(song_key: String, difficulties: Array = [], profile: Variant = null) -> int:
	var p: Variant = _profile(profile)
	if p == null:
		return 0
	var diffs: Array = difficulties
	if diffs.is_empty():
		var s := SongLibrary.get_song(song_key)
		diffs = s.difficulties() if s != null else SongData.DIFFICULTIES
	var most := -1
	for d in diffs:
		var b: Dictionary = p.best(song_key, d)
		if not b.is_empty():
			most = maxi(most, entry_grade(b))
	return most


## A stop is finished with a D or better at any level. The Workshop (tutorial) is also finished once
## the tutorial is done (Profile flag "tutorial_done"), since it is played lesson by lesson.
static func cleared(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s != null and s.kind == "tutorial":
		var p: Variant = _profile(profile)
		if p != null and p.has_method("has_flag") and p.has_flag("tutorial_done"):
			return true
	return best_grade(song_id, [], profile) >= CLEAR_GRADE


static func is_unlocked(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s == null:
		return false
	if s.id != song_id:
		return remix_unlocked(s.id, profile)
	return true


## Whether a stop moves the story on to the next: finished, or the tutorial, which is optional
## (Daniele, 2026-09-27: the tutorial and the calibration are offered from the menu, never forced).
static func opens_next(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	return (s != null and s.kind == "tutorial") or cleared(song_id, profile)


## Accepts the base song id or the remix id.
static func remix_unlocked(song_id: String, profile: Variant = null) -> bool:
	var s := SongLibrary.get_song(song_id)
	if s == null or not s.has_remix():
		return false
	return best_grade(s.id, REMIX_LEVELS, profile) >= REMIX_GRADE


## The story stop reached: the furthest stop whose earlier stops are all finished.
static func highest_stop(profile: Variant = null) -> int:
	var story := SongLibrary.story()
	var top := story[0].stop if not story.is_empty() else 1
	for i in range(1, story.size()):
		if not opens_next(story[i - 1].id, profile):
			break
		top = story[i].stop
	return maxi(top, 1)


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
			total += GRADE_POINTS[entry_grade(e)]
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


## The first story stop not finished yet ("" when all are finished).
static func next_stop(profile: Variant = null) -> String:
	for id in story_order():
		var s := SongLibrary.get_song(id)
		if s != null and s.kind == "tutorial":
			continue   # optional, and on the title menu of its own
		if is_unlocked(id, profile) and not cleared(id, profile):
			return id
	return ""


## What the player is working towards, nearest first. Each entry:
## {kind: "remix"|"bell_set"|"mask", id, part (mask only), need: {...}, have: {...}}.
## need/have use the keys song_id, difficulty ("hard" means Hard or Expert), grade (a rank; -1 in
## have: never played), stop, points.
static func next_goals(profile: Variant = null) -> Array:
	var out := []
	var story := story_order()
	var stop := highest_stop(profile)
	for id in BellSets.ids():
		if not bell_set_unlocked(id, profile):
			out.append({"kind": "bell_set", "id": id, "need": {"stop": BELL_SET_STOPS[id]}, "have": {"stop": stop}})
			break
	var remixes := []
	for id in story:
		var s := SongLibrary.get_song(id)
		if s.has_remix() and cleared(id, profile) and not remix_unlocked(id, profile):
			remixes.append({"kind": "remix", "id": s.remix_id(), "need": {"song_id": id, "difficulty": "hard", "grade": REMIX_GRADE}, "have": {"grade": best_grade(id, REMIX_LEVELS, profile)}})
	remixes.sort_custom(func(a, b): return a.have.grade > b.have.grade)
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
