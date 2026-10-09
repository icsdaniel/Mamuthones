extends Screen
## The Workshop tutorial: the song's lessons one at a time (steps, lanes, bells, holds, still, stomps,
## full). Each lesson: a short instruction with a picture of what to look for, an optional demo played
## by Autoplay, then the player's turn. Passed lessons move on; missed ones explain what went wrong and
## repeat. After the last lesson a card explains unison, then the whole song starts at Easy.
## args: song_id (optional; the tutorial song by default), first_run, autoplay (tests: play every
## lesson by itself).

const PASS_ACCURACY := 0.6

var song: SongData
var chart := "easy"
var lessons: Array = []
var index := 0
var fails := 0
var _card: Control
var _play: Screen
var _last: Session               ## the last try, for what went wrong in the player's own numbers


func build() -> void:
	song = SongLibrary.get_song(str(args.get("song_id", ""))) if args.has("song_id") else null
	if song == null:
		for s in SongLibrary.story():
			if s.kind == "tutorial":
				song = s
				break
	if song == null:
		push_error("tutorial: no tutorial song")
		return
	chart = "tutorial" if song.charts.has("tutorial") else "easy"
	lessons = song.lessons
	Sound.set_key(song.key_root)
	Sound.ambience(UIKit.ambience_for(song.stop))
	_intro()


func topic() -> String:
	return str(lessons[index].get("topic", "steps")) if index < lessons.size() else ""


func _clear() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	if _play != null:
		_play.queue_free()
		_play = null


## The lesson card: what to do, a picture, Try it / Show me.
func _intro(after_fail := false, after_demo := false) -> void:
	_clear()
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.name = "LessonCard"
	add_child(_card)
	var box := UIKit.column(_card, false, 18)
	UIKit.header(box, tr("tut_title"), on_back)
	box.add_child(UIKit.label(tr("tut_lesson_n") % [index + 1, lessons.size()], UIKit.CAPTION))
	box.add_child(ProgressPips.new(lessons.size(), index))
	var t := topic()
	var slam := bool(Profile.get_setting("slam"))
	box.add_child(UIKit.label(tr("tut_%s_title" % t), UIKit.TITLE))
	var pic := LessonPicture.new()
	pic.topic = t
	pic.slam = slam
	pic.custom_minimum_size = Vector2(0, 380)
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.name = "Picture"
	box.add_child(pic)
	var body := tr("tut_%s_slam" % t) if slam and t in ["bells", "full"] else tr("tut_%s" % t)
	var text := UIKit.label(body, UIKit.SUB)
	text.name = "Instruction"
	box.add_child(text)
	if after_fail:
		var why := UIKit.card(box, true)
		why.name = "Why"
		why.add_child(UIKit.label(tr("tut_almost"), UIKit.PAPER_HEADER))
		if _last != null:
			for line in fail_lines(_last, t):
				var l := UIKit.label(line, UIKit.PAPER)
				l.name = "WhyNumbers"
				why.add_child(l)
		var fail_key := "tut_fail_%s_slam" % t if slam and t == "full" else "tut_fail_" + t
		why.add_child(UIKit.label(tr(fail_key), UIKit.PAPER))
	var go := UIKit.button(tr("tut_your_turn") if after_demo else (tr("tut_try_again") if after_fail else tr("tut_try")), _start.bind(false), UIKit.PRIMARY)
	go.name = "Try"
	box.add_child(go)
	var demo := UIKit.button(tr("tut_show_me"), _start.bind(true), "" if after_fail else UIKit.QUIET)
	demo.name = "ShowMe"
	box.add_child(demo)
	if fails >= 3:
		var skip := UIKit.button(tr("tut_skip"), _next, UIKit.QUIET)
		skip.name = "Skip"
		box.add_child(skip)
	if bool(args.get("autoplay", false)):
		_start.call_deferred(false)


func _start(demo: bool) -> void:
	_clear()
	var l: Dictionary = lessons[index]
	var from := float(l.get("b", 0.0))
	var to := from + float(l.get("len", 8.0))
	var script: GDScript = load(App.SCREENS["play"])
	_play = script.new()
	_play.app = app
	_play.args = {
		"song_id": song.id, "difficulty": chart, "bell_set": str(Profile.get_look().get("bell_set", "light")),
		"from_beat": from, "to_beat": to, "embedded": true,
		"autoplay": demo or bool(args.get("autoplay", false)),
	}
	_play.name = "Lesson"
	add_child(_play)
	_play.build()
	var short := "tut_%s_short" % topic()
	if bool(Profile.get_setting("slam")) and topic() == "full":
		short = "tut_full_slam_short"
	var hint := UIKit.label(tr("tut_watch") if demo else tr(short), UIKit.HUD, true, HORIZONTAL_ALIGNMENT_CENTER)
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.custom_minimum_size.x = 600
	hint.position = Vector2(-300, -40)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.name = "LessonHint"
	_play.add_child(hint)
	var tw := hint.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(hint, "modulate:a", 0.0, 0.4)
	_play.connect("finished", _on_lesson_done.bind(demo))


func _on_lesson_done(session: Session, demo: bool) -> void:
	if session == null:
		# Quit from the pause menu leaves the tutorial.
		_play = null
		_leave()
		return
	if demo:
		_intro(false, true)
		return
	_last = session
	if passed(session, topic()):
		fails = 0
		_well_done(session)
	else:
		fails += 1
		_intro(true)


## What went wrong in a lesson try, in the player's own numbers: at most two lines, the biggest
## problem first (missed notes of the lesson's kind, a lane that got most misses, timing, wrong lane,
## bells in a stand-still, holds let go).
static func fail_lines(s: Session, t: String) -> Array[String]:
	var out: Array[String] = []
	var st := s.stats
	match t:
		"still":
			if int(st.silence) > 0:
				out.append(UIKit.tr_("tut_why_silence") % int(st.silence))
		"stomps":
			if int(st.get("one_thumb", 0)) > 0:
				out.append(UIKit.tr_("tut_why_one_thumb") % int(st.one_thumb))
		"holds":
			if int(st.get("holds", 0)) > 0:
				out.append(UIKit.tr_("tut_why_holds") % [int(st.held), int(st.holds)])
	# Misses, by the kind this lesson teaches (bells for bells, the lane with most misses for lanes).
	var kinds := [Note.Kind.STEP, Note.Kind.HOLD, Note.Kind.RING]
	if t == "bells":
		kinds = [Note.Kind.BELL, Note.Kind.RING]
	elif t == "stomps":
		kinds = [Note.Kind.STOMP]
	var total := 0
	var missed := 0
	var lane_total := [0, 0, 0]
	var lane_missed := [0, 0, 0]
	for n in s.notes:
		if not n.kind in kinds:
			continue
		total += 1
		var m := n.judgement in ["miss", "wrong", ""] or not n.done
		if m:
			missed += 1
		if n.lane >= 0 and n.lane <= 2:
			lane_total[n.lane] += 1
			if m:
				lane_missed[n.lane] += 1
	if missed > 0:
		var worst := 0
		for lane in 3:
			if lane_missed[lane] > lane_missed[worst]:
				worst = lane
		if t == "lanes" and lane_missed[worst] > 0 and lane_missed[worst] * 2 >= missed:
			out.append(UIKit.tr_("tut_why_lane_%d" % worst) % [lane_missed[worst], lane_total[worst]])
		else:
			out.append(UIKit.tr_("tut_why_missed") % [missed, total])
	var med := s.median_offset()
	var side := UIKit.side_of(med)
	if s.hit_offsets.size() >= 3 and absf(med) >= 0.03:
		out.append(UIKit.tr_("tut_why_" + side) % roundi(absf(med) * 1000.0))
	if int(st.get("wrong", 0)) > 0:
		out.append(UIKit.tr_("tut_why_wrong") % int(st.wrong))
	if out.size() > 2:
		out.resize(2)
	return out


## Whether a lesson run counts as learned.
static func passed(session: Session, t: String) -> bool:
	var st := session.stats
	if t == "still":
		return int(st.silence) == 0 and session.accuracy() >= PASS_ACCURACY
	if t == "holds" and int(st.get("holds", 0)) > 0:
		return int(st.held) * 2 >= int(st.holds) and session.accuracy() >= PASS_ACCURACY
	return session.accuracy() >= PASS_ACCURACY


func _well_done(session: Session) -> void:
	_clear()
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.name = "WellDone"
	add_child(_card)
	var box := UIKit.column(_card, false, 18)
	UIKit.spacer(box, 0, true)
	box.add_child(UIKit.label(tr("tut_well_done"), UIKit.TITLE, true, HORIZONTAL_ALIGNMENT_CENTER))
	var grade := GradeBadge.new(session.grade_rank(), true)
	grade.name = "Grade"
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grade)
	grade.animate(0.1)
	box.add_child(UIKit.label(tr("tut_accuracy") % roundi(session.accuracy() * 100.0), UIKit.SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.spacer(box, 0, true)
	var go := UIKit.button(tr("ui_continue"), _next, UIKit.PRIMARY)
	go.name = "Continue"
	box.add_child(go)
	if bool(args.get("autoplay", false)):
		_next.call_deferred()


func _next() -> void:
	fails = 0
	index += 1
	if index < lessons.size():
		_intro()
	else:
		_finale()


## After the lessons: what unison is, then the whole song.
func _finale() -> void:
	_clear()
	Profile.set_flag("tutorial_done", true)
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.name = "Finale"
	add_child(_card)
	var box := UIKit.column(_card, true, 18)
	UIKit.header(box, tr("tut_title"), on_back)
	box.add_child(UIKit.label(tr("tut_unison_title"), UIKit.TITLE))
	var meter := UnisonMeter.new()
	meter.custom_minimum_size = Vector2(0, 40)
	meter.level = 3
	meter.fill = 0.5
	box.add_child(meter)
	box.add_child(UIKit.label(tr("tut_unison"), ""))
	box.add_child(UIKit.label(tr("tut_weight"), ""))
	box.add_child(UIKit.label(tr("tut_ready"), UIKit.SUB))
	var go := UIKit.button(tr("tut_play_song"), _play_song, UIKit.PRIMARY)
	go.name = "PlaySong"
	box.add_child(go)
	var story := SongLibrary.story()
	if story.size() > 1:
		var on := UIKit.button(tr("tut_next_stop") % UIKit.song_title(story[1]), func() -> void:
			app.reset("title")
			app.open("stop_card", {"song_id": story[1].id}))
		on.name = "NextStop"
		box.add_child(on)
	var later := UIKit.button(tr("tut_later"), func() -> void: app.reset("title"), UIKit.QUIET)
	later.name = "Later"
	box.add_child(later)
	if bool(args.get("autoplay", false)):
		finished_all.emit()


signal finished_all


func _play_song() -> void:
	app.reset("title")
	app.open("play", {"song_id": song.id, "difficulty": "easy",
		"bell_set": str(Profile.get_look().get("bell_set", "light"))})


func _leave() -> void:
	if app.stack.size() > 1:
		app.back()
	else:
		app.reset("title")


func on_back() -> void:
	if _play != null:
		(_play as Screen).on_back()
	elif args.get("first_run", false):
		UIKit.confirm(self, tr("tut_leave_q"), tr("tut_leave"), func() -> void:
			app.reset("title"))
	else:
		_leave()
