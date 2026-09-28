class_name Note
extends RefCounted
## One chart note in song time (seconds), plus its play state inside a Session.
## Built by SongData.notes(); every call returns fresh Note objects, so each Session owns its copies.

enum Kind { STEP, HOLD, BELL, RING, SWIPE, REST }

const KIND_NAMES := {"step": Kind.STEP, "hold": Kind.HOLD, "bell": Kind.BELL, "ring": Kind.RING, "swipe": Kind.SWIPE, "rest": Kind.REST}

var kind: Kind = Kind.STEP
var beat := 0.0
## Hit time in seconds of song time.
var t := 0.0
## End time: holds and rests end later, every other note has end_t == t.
var end_t := 0.0
var lane := -1
## Bells and rings: the direction shown (bells alternate through the chart, up first).
var up := true
## Swipes: 1 to the right, -1 to the left.
var dir := 0
## Steps with an Issohadore's call (off-beat hits). The name is from the song format; it hides
## Object.call() on notes, which nothing uses.
@warning_ignore("shadowed_variable_base_class")
var call := false
## A healing step (chosen by Session at the start, not in the chart): hitting it restores health.
var heal := false
## Position in the session's note list.
var index := 0

# Play state (owned by Session).
var done := false        ## judged (for holds: the head was judged)
var holding := false     ## a hold being held right now
var finished := false    ## holds/rests: over, nothing more can happen
var hit_at := NAN        ## input time that judged it
var judgement := ""      ## perfect|good|early|late|miss|wrong|silence|still ("" while open)
var side := ""           ## hits: "early" or "late" (more than 10 ms off), "" when dead on
var step_at := NAN       ## full rings: time of the step half
var bell_at := NAN       ## full rings: time of the bell half
var touch_id := -1       ## holds: the touch holding it


func uses_lane() -> bool:
	return kind == Kind.STEP or kind == Kind.HOLD or kind == Kind.RING


func is_bell() -> bool:
	return kind == Kind.BELL or kind == Kind.RING


func kind_name() -> String:
	for k in KIND_NAMES:
		if KIND_NAMES[k] == kind:
			return k
	return "?"


func _to_string() -> String:
	return "Note(%s b=%.2f t=%.3f lane=%d)" % [kind_name(), beat, t, lane]
