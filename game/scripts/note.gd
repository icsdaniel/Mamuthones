class_name Note
extends RefCounted
## One thing to play in a chart. Times are seconds into the song's audio file.

enum Kind { STEP, HOLD, BELL, SWIPE, REST }

var kind: Kind
var t := 0.0
var lane := -1        ## 0 left, 1 middle, 2 right (steps and holds)
var end_t := 0.0      ## holds only
var up := true        ## bells only; bells always alternate up and down
var right := true     ## swipes only
var call := false     ## a step on an odd eighth: an off-beat Issohadore call

var done := false     ## judged (hit, missed, or a rest that passed)
var holding := false  ## a hold being held right now
var finished := false ## a hold whose end was judged
var flash_at := -1.0  ## song time it was hit, for the hit animation


func _init(p_kind: Kind, p_t: float) -> void:
	kind = p_kind
	t = p_t
