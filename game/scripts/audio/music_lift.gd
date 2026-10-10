class_name MusicLift
extends RefCounted
## How far the song's lift layer is up (Conductor.set_lift): the player's hits on time play the tune.
##
## Two parts, the larger one taken:
## - the run: every hit on time (Perfect, Good, a hold kept, a bell rung on time) raises a floor the
##   layer sits on, up to RUN_MAX; an Ok lowers it a little, a miss (or a wrong or stray tap) drops it
##   to nothing. So while the player keeps time the tune is already up when the next note sounds:
##   nothing waits on the phone's audio delay.
## - the accent: every note pushes the layer higher for a moment at its own time, fading back to the
##   run over SWELL_BEATS, as if it was hit on time. The play screen calls accent() when the music
##   being mixed reaches the note, so the accent is heard on the note whatever the phone's sound delay;
##   a note that turns out missed is corrected afterwards by the miss sound and the cut.
## The level follows its target quickly up (ATTACK) and a little slower down (RELEASE); a miss cuts it
## faster (CUT), so the hole in the music is heard with the miss.

const RUN_MAX := 0.55
const RUN_STEP := {"perfect": 0.3, "good": 0.2, "held": 0.3}
const RUN_OK := 0.12
const ACCENT := 0.9
const SWELL_BEATS := 0.6
const ATTACK := 0.01
const RELEASE := 0.12
const CUT := 0.05

var run := 0.0
var swell := 0.0
var level := 0.0
var _cut := false


func hit(quality: String) -> void:
	run = minf(run + float(RUN_STEP.get(quality, 0.2)), RUN_MAX)
	_cut = false


## A note's accent, at the note's time (see the class notes).
func accent() -> void:
	swell = maxf(swell, ACCENT)
	_cut = false


func ok() -> void:
	run = maxf(run - RUN_OK, 0.0)


func miss() -> void:
	run = 0.0
	swell = 0.0
	_cut = true


func reset() -> void:
	run = 0.0
	swell = 0.0
	level = 0.0
	_cut = false


## Moves the level on by delta seconds; spb is the song's seconds per beat. Returns the level.
func tick(delta: float, spb: float) -> float:
	if swell > run:
		# fades back to the run over SWELL_BEATS
		swell = maxf(run, swell - delta / maxf(SWELL_BEATS * spb, 0.05))
	var target := maxf(run, swell)
	var tc := ATTACK if target > level else (CUT if _cut else RELEASE)
	level += (target - level) * (1.0 - exp(-delta / tc))
	if _cut and level < 0.01:
		_cut = false
	return level
