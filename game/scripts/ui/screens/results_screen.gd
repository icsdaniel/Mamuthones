extends Screen
## Results: the row's words for the run, the letter grade (F to S+), the score and where it came from (accuracy,
## unison), the early/late tendency, the best and the ghost, what was unlocked (celebrated), and
## one concrete tip for next time.
## args: session, record (Profile.record_result output, empty for autoplay), play_args, ghost, frames
## (the play screen's frame_stats(): how smoothly the phone drew the song, shown under the timing).

const TIERS := [0.5, 0.7, 0.85, 0.95]

## Juice hooks for sound (and anything else that wants the beats of this screen):
## the score counting up (about 24 ticks, rising values), the count landing on the final score, the
## grade stamping in, and the best-score line appearing.
signal count_tick(value: int)
signal count_done(value: int)
signal grade_stamped(rank: int)
signal best_revealed(new_best: bool)

var session: Session
var record: Dictionary


func build() -> void:
	session = args.get("session")
	record = args.get("record", {})
	if session == null:
		return
	var play_args: Dictionary = args.get("play_args", {})
	var cols := UIKit.column_with_footer(self, 14)
	var box := cols[0]
	var foot := cols[1]
	UIKit.header(box, UIKit.song_title(session.song), _leave)
	var sub := tr("diff_" + session.difficulty)
	if session.remix:
		sub += " · " + tr("res_remix")
	box.add_child(UIKit.label(sub, UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER))

	var acc := session.accuracy()
	var words := UIKit.label(tr(grade_key(acc)), UIKit.HEADER, true, HORIZONTAL_ALIGNMENT_CENTER)
	words.name = "Words"
	box.add_child(words)
	# Grade and score share one row, so the breakdown and timing fit above the fold.
	# The showcase: a warm glow behind them flares as the grade stamps in and as the score lands.
	var stage := PanelContainer.new()
	stage.theme_type_variation = "ClearPanel"
	box.add_child(stage)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(holder)
	_glow = TextureRect.new()
	_glow.name = "Glow"
	_glow.texture = Palette.px("ui/banner_glow")
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.offset_left = -30
	_glow.offset_right = 30
	_glow.offset_top = -36
	_glow.offset_bottom = 36
	_glow.modulate.a = 0.0
	holder.add_child(_glow)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 24)
	stage.add_child(top)
	var grade := GradeBadge.new(session.grade_rank(), true, session.full_combo())
	grade.name = "Grade"
	grade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(grade)
	grade.stamped.connect(func() -> void:
		grade_stamped.emit(grade.rank)
		_flare(0.5 + 0.1 * maxi(grade.rank - Session.RANK_B, 0)))
	grade.animate(0.35)
	var score := UIKit.label(UIKit.fmt_score(session.score), "BigNumberLabel", false, HORIZONTAL_ALIGNMENT_CENTER)
	score.name = "Score"
	score.add_theme_font_size_override("font_size", 72)
	var score_col := VBoxContainer.new()
	score_col.alignment = BoxContainer.ALIGNMENT_CENTER
	score_col.add_theme_constant_override("separation", 0)
	top.add_child(score_col)
	score_col.add_child(score)
	_count_up(score, session.score)
	var mc := UIKit.label(tr("res_max_combo") % session.max_combo, UIKit.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	mc.name = "MaxCombo"
	mc.add_theme_font_size_override("font_size", 26)
	mc.add_theme_color_override("font_color", Palette.BONE_DIM)
	score_col.add_child(mc)
	if session.full_combo():
		# The full combo is its own reward: it lands just after the grade, with a chime and a flare.
		var fc := UIKit.label(tr("res_full_combo"), UIKit.SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
		fc.name = "FullCombo"
		fc.add_theme_color_override("font_color", Palette.GOLD_HOT)
		score_col.add_child(fc)
		if not UIKit.reduced_motion():
			fc.modulate.a = 0.0
			var tw := fc.create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func() -> void:
				Sound.ui("unlock")
				_flare(1.0))
			tw.tween_property(fc, "modulate:a", 1.0, 0.15)
	var best_line := _best_line()
	if best_line != "":
		var bl := UIKit.label(best_line, UIKit.SUB, true, HORIZONTAL_ALIGNMENT_CENTER)
		bl.name = "BestLine"
		bl.add_theme_font_size_override("font_size", 28)
		bl.add_theme_color_override("font_color", Palette.GOLD_HOT if bool(record.get("new_best", false)) else Palette.BONE_DIM)
		box.add_child(bl)
		var new_best := bool(record.get("new_best", false))
		if UIKit.reduced_motion():
			best_revealed.emit.call_deferred(new_best)
		else:
			bl.modulate.a = 0.0
			var tw := bl.create_tween()
			tw.tween_interval(1.15)
			tw.tween_callback(func() -> void: best_revealed.emit(new_best))
			tw.tween_property(bl, "modulate:a", 1.0, 0.2)

	# The score's story first: the unison headline, where the points came from, and the timing.
	_breakdown(box)
	_tendency(box)
	var tip_line := tip_text(session)
	if tip_line != "":
		var tip := UIKit.card(box, true)
		tip.name = "Tip"
		tip.add_child(UIKit.label(tr("res_tip"), UIKit.PAPER_HEADER))
		tip.add_child(UIKit.label(tip_line, UIKit.PAPER))
	_unlocks(box)
	if session.slam:
		box.add_child(UIKit.label(tr("res_slam_note"), UIKit.CAPTION, true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label(tr("res_formula"), UIKit.CAPTION))

	var again := UIKit.button(tr("res_again"), func() -> void: app.replace("play", play_args), UIKit.PRIMARY)
	again.name = "Again"
	var next := _next_song()
	if next != null:
		var go := UIKit.button(tr("res_next") % UIKit.song_title(next), func() -> void:
			app.replace("stop_card", {"song_id": next.id}), UIKit.PRIMARY)
		go.name = "Next"
		foot.add_child(go)
		again.theme_type_variation = ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	foot.add_child(row)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var leave := UIKit.button(tr("res_done"), _leave, UIKit.QUIET)
	leave.name = "Done"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)
	Sound.ui("result")


static func grade_key(acc: float) -> String:
	var i := 0
	for t in TIERS:
		if acc >= t - 1e-9:
			i += 1
	return "grade_%d" % i


func _best_line() -> String:
	var prev := int(record.get("prev_best", 0))
	var ghost: Ghost = args.get("ghost")
	if bool(record.get("new_best", false)):
		if prev > 0:
			return tr("res_new_best_by") % UIKit.fmt_score(session.score - prev)
		return tr("res_first_best")
	if prev > 0:
		return tr("res_best") % [UIKit.fmt_score(prev), UIKit.fmt_score(prev - session.score)]
	if ghost != null and not ghost.is_empty():
		return tr("res_best") % [UIKit.fmt_score(ghost.final_score), UIKit.fmt_score(ghost.final_score - session.score)]
	return ""


## Score = notes × unison: show how much each part added, so the game's ideas read as the way
## to a high score.
func _breakdown(box: Container) -> void:
	var b := session.score_breakdown()
	var c := UIKit.card(box)
	c.name = "Breakdown"
	var st := session.stats
	var peak := float(st.get("unison_peak", Session.UNISON_MULTS[int(st.get("max_unison", 0))]))
	var top := Session.UNISON_MULTS[Session.UNISON_MULTS.size() - 1]
	var head := UIKit.label(unison_headline(peak, float(st.get("time_at_top", 0.0)), top), UIKit.SUB, true)
	head.name = "UnisonHeadline"
	head.add_theme_color_override("font_color", Palette.EMBER_HOT)
	c.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	c.add_child(grid)
	_row(grid, tr("res_accuracy"), "%d%%" % roundi(session.accuracy() * 100.0), "Accuracy")
	_row(grid, tr("res_counts") % [int(st.perfect), int(st.good), int(st.early) + int(st.late), int(st.miss) + int(st.wrong)], "", "Counts", true)
	_row(grid, tr("res_base"), UIKit.fmt_score(roundi(float(b.get("base", 0.0)))), "Base")
	_row(grid, tr("res_unison") % Hud._mult_text(peak),
		"+" + UIKit.fmt_score(roundi(float(b.get("unison", 0.0)))), "Unison")
	if float(b.get("holds", 0.0)) > 0.0:
		_row(grid, tr("res_holds"), "+" + UIKit.fmt_score(roundi(float(b.holds))), "Holds")
	if int(st.get("rests", 0)) > 0:
		# Keeping still is scored both ways: a bonus for every stand-still kept, a cost for ringing in one.
		var net := float(b.get("stills", 0.0)) - absf(float(b.get("penalties", 0.0)))
		var what := tr("res_still") % [int(st.get("still_kept", 0)), int(st.get("rests", 0))]
		var share := still_share(net, session.score)
		if share > 0:
			what += " · " + tr("res_still_share") % share
		_row(grid, what, ("+" if net >= 0.0 else "−") + UIKit.fmt_score(roundi(absf(net))), "Still")
	UIKit.pop_in(c, 0.5)


## Stillness's share of the final score in whole percent (at least 1 when it added anything).
static func still_share(net: float, score: int) -> int:
	if net <= 0.0 or score <= 0:
		return 0
	return maxi(1, roundi(net / float(score) * 100.0))


## "Unison peak ×4 · 38 s at ×4", or just the peak when the top was never reached.
static func unison_headline(peak: float, secs_at_top: float, top: float) -> String:
	if peak >= top and secs_at_top >= 0.5:
		return UIKit.tr_("res_unison_head_top") % [Hud._mult_text(peak), UIKit.fmt_dec(secs_at_top, 0), Hud._mult_text(top)]
	return UIKit.tr_("res_unison_head") % Hud._mult_text(peak)


func _row(grid: GridContainer, what: String, value: String, id: String, span := false) -> void:
	var l := UIKit.label(what, UIKit.CAPTION if span else "", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.name = id + "Label"
	grid.add_child(l)
	var v := UIKit.label(value, UIKit.SUB, false, HORIZONTAL_ALIGNMENT_RIGHT)
	v.name = id + "Value"
	grid.add_child(v)


func _tendency(box: Container) -> void:
	var c := UIKit.card(box)
	c.name = "Tendency"
	c.add_child(UIKit.label(tr("res_timing"), UIKit.SUB))
	var med := session.median_offset()
	var ms := roundi(absf(med) * 1000.0)
	var text := tr("res_on_time")
	var side := UIKit.side_of(med)
	if session.hit_offsets.size() < 4:
		text = tr("res_timing_few")
	elif side == "early":
		text = tr("res_early") % ms
	elif side == "late":
		text = tr("res_late") % ms
	var tl := UIKit.label(text, "")
	if side != "" and session.hit_offsets.size() >= 4:
		tl.add_theme_color_override("font_color", UIKit.side_color(side))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	c.add_child(row)
	# The words, and under them the fix when there is one, sit beside the meter: the card stays short
	# enough to end above the buttons even when the footer offers the next stop.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)
	left.add_child(tl)
	var meter := TendencyMeter.new()
	meter.name = "Meter"
	meter.offsets = session.hit_offsets
	meter.custom_minimum_size.y = 150
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(meter)
	# A steady lean one way after a played song: one tap draws the notes that much earlier or later.
	var shift := timing_fix(session)
	if shift != 0.0 and not record.is_empty():
		var key := "res_fix_late" if shift > 0.0 else "res_fix_early"
		var fix := UIKit.button(tr(key) % roundi(absf(shift) * 1000.0), func() -> void: pass, UIKit.QUIET)
		fix.name = "FixTiming"
		fix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fix.custom_minimum_size.x = 0
		fix.pressed.connect(func() -> void:
			Profile.set_setting("visual_offset", Profile.visual_offset() + shift)
			fix.text = tr("res_fixed")
			fix.disabled = true)
		left.add_child(fix)
	var saved := str(args.get("run_saved", ""))
	if saved != "":
		if saved.begins_with("user://"):
			# Downloads could not be written: the run can still leave the phone through the clipboard.
			var copy := UIKit.button(tr("res_run_copy"), func() -> void: pass, UIKit.QUIET)
			copy.name = "CopyRun"
			copy.pressed.connect(func() -> void:
				DisplayServer.clipboard_set(run_clipboard_text(saved))
				copy.text = tr("res_run_copied")
				copy.disabled = true)
			c.add_child(copy)
		else:
			var sl := UIKit.label(tr("res_run_saved") % saved.get_file(), UIKit.CAPTION)
			sl.name = "RunSaved"
			c.add_child(sl)
	var fr: Dictionary = args.get("frames", {})
	if not fr.is_empty() and not record.is_empty():
		var fl := UIKit.label(tr("res_frames") % [roundi(float(fr.fps)), int(fr.slow), roundi(float(fr.worst) * 1000.0)], UIKit.CAPTION)
		fl.name = "Frames"
		c.add_child(fl)
	UIKit.pop_in(c, 0.7)


## How much earlier (positive: the hits were late) the notes should be drawn to even out this run's
## timing: its median offset to 5 ms, or 0 with fewer than TIMING_FIX_HITS hits or under TIMING_FIX_MIN.
static func timing_fix(s: Session) -> float:
	if s.hit_offsets.size() < TIMING_FIX_HITS:
		return 0.0
	var med := s.median_offset()
	if absf(med) < TIMING_FIX_MIN:
		return 0.0
	return snappedf(med, 0.005)


## The saved run file packed for the clipboard: "MAMUTHONES-RUN-GZ:" then the gzipped JSON in base64.
static func run_clipboard_text(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	return "MAMUTHONES-RUN-GZ:" + Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_GZIP))


const TIMING_FIX_HITS := 20
const TIMING_FIX_MIN := 0.015


func _unlocks(box: Container) -> void:
	var list: Array = record.get("unlocked", [])
	var carving := int(record.get("carving_gained", 0))
	var closest := closest_unlock(session)
	if list.is_empty() and carving <= 0:
		if closest != "":
			var cc := UIKit.card(box)
			cc.name = "Closest"
			cc.add_child(UIKit.label(tr("res_closest"), UIKit.SUB))
			cc.add_child(UIKit.label(closest, UIKit.CAPTION))
		return
	var c := UIKit.card(box, true)
	c.name = "Unlocked"
	c.add_child(UIKit.label(tr("res_unlocked"), UIKit.PAPER_HEADER))
	var lines: Array[String] = []
	for u in list:
		lines.append(UIKit.unlock_text(u))
	if carving > 0:
		lines.append(tr("res_carving") % carving)
	for line in lines:
		c.add_child(UIKit.label("• " + line, UIKit.PAPER))
	if closest != "":
		var cl := UIKit.label(tr("res_closest") + ": " + closest, UIKit.PAPER)
		cl.name = "Closest"
		c.add_child(cl)
	if not list.is_empty():
		UIKit.celebrate(self, lines[0], 2.2)


## The unlock this run came closest to, as a goal line ("" when nothing is left): a goal about this
## song first (its next stop, its remix), else the first open goal.
static func closest_unlock(s: Session) -> String:
	var goals: Array = Progression.next_goals()
	if goals.is_empty():
		return ""
	for g in goals:
		var need: Dictionary = g.get("need", {})
		if str(need.get("song_id", "")) == s.song.id:
			return UIKit.goal_line(g)
	return UIKit.goal_line(goals[0])


## One concrete thing to do better, picked from what went wrong most.
static func tip_text(s: Session) -> String:
	var st := s.stats
	var total := maxi(int(st.total), 1)
	var med := s.median_offset()
	if int(st.silence) > 0:
		return UIKit.tr_("tip_still")
	if int(st.get("let_go", 0)) > 0 and int(st.get("let_go", 0)) * 3 >= int(st.get("holds", 1)):
		return UIKit.tr_("tip_holds")
	var bell_miss := 0
	var bell_total := 0
	for n in s.notes:
		if n.is_bell():
			bell_total += 1
			if n.judgement == "miss":
				bell_miss += 1
	if bell_total > 0 and float(bell_miss) / bell_total > 0.25:
		return UIKit.tr_("tip_bells_slam") if s.slam else UIKit.tr_("tip_bells")
	if s.hit_offsets.size() >= 8 and absf(med) > 0.03:
		return UIKit.tr_("tip_late" if med > 0.0 else "tip_early") % roundi(absf(med) * 1000.0)
	if int(st.wrong) * 10 > total:
		return UIKit.tr_("tip_wrong")
	if int(st.miss) * 5 > total:
		return UIKit.tr_("tip_slow")
	if int(st.get("max_unison", 0)) < 3:
		return UIKit.tr_("tip_unison") % Session.UNISON_STEP
	# A clean run: one step up that is actually open to this player, or nothing.
	var diffs := s.song.difficulties()
	var i := diffs.find(s.difficulty)
	if s.grade_rank() >= Session.RANK_B and i >= 0 and i + 1 < diffs.size():
		var nd := diffs[i + 1]
		var tip := UIKit.tr_("tip_harder") % UIKit.tr_("diff_" + nd)
		if nd in Progression.REMIX_LEVELS and s.song.has_remix() and not Progression.remix_unlocked(s.song.id):
			tip += " " + UIKit.tr_("tip_harder_remix") % [Session.grade_name(Progression.REMIX_GRADE), UIKit.tr_("diff_" + nd)]
		return tip
	return ""


var _glow: TextureRect
var _ticks := 0


## The score counts up in about 24 audible ticks, then lands with a flare of the glow.
func _count_up(l: Label, target: int) -> void:
	if UIKit.reduced_motion():
		_glow_rest.call_deferred()
		count_done.emit.call_deferred(target)
		return
	_ticks = 0
	var tw := l.create_tween()
	tw.tween_method(func(v: float) -> void:
		l.text = UIKit.fmt_score(roundi(v))
		var n := int(v / maxf(float(target), 1.0) * 24.0)
		if n > _ticks:
			_ticks = n
			count_tick.emit(roundi(v)), 0.0, float(target), 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		count_done.emit(target)
		_flare(1.0))
	# the number swells a step as it lands
	l.pivot_offset = l.size * 0.5
	tw.tween_property(l, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)


## A quick bright step of the warm glow, then it settles to a low ember.
func _flare(strength: float) -> void:
	if _glow == null:
		return
	var tw := _glow.create_tween()
	tw.tween_property(_glow, "modulate:a", 0.25 + 0.45 * strength * (0.4 if UIKit.reduced_motion() else 1.0), 0.05)
	tw.tween_property(_glow, "modulate:a", 0.28, 0.5)


func _glow_rest() -> void:
	if _glow != null:
		_glow.modulate.a = 0.28


func _next_song() -> SongData:
	var play_args: Dictionary = args.get("play_args", {})
	if session.grade_rank() < Progression.CLEAR_GRADE:
		return null
	var story := SongLibrary.story()
	for i in story.size() - 1:
		if story[i].id == session.song.id and Progression.is_unlocked(story[i + 1].id):
			return story[i + 1]
	return null


func _leave() -> void:
	app.back()
