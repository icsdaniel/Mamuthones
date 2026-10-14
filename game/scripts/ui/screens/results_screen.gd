extends Screen
## Results, on the mobile kit (UIKit's header): one screen that fits, no scrolling.
##   top bar   back · the song and difficulty · the ladder
##   hero      the grade struck on a bronze seal (F to S+), the score counting up, the row's words,
##             and the callouts: full combo (its own reward) and the new best / the best to beat
##   pages     a segmented control over swipeable pages:
##               Overview  accuracy, longest combo, unison peak, timing lean as tiles, and the
##                         perfect / good / ok / missed counts
##               Score     where the points came from (notes × unison, holds, stillness), the formula
##               Timing    the early/late histogram, the one-tap fix, smoothness, the saved run
##               Tips      (Rewards when something opened) what was unlocked, carving points, the
##                         closest unlock, and one concrete tip for next time
##   footer    Next stop (primary) when the next stop is open, Play again, Back
## args: session, record (Profile.record_result output, empty for autoplay), play_args, ghost, frames
## (the play screen's frame_stats(): how smoothly the phone drew the song), run_saved.

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
var pager: Pager


func build() -> void:
	session = args.get("session")
	record = args.get("record", {})
	if session == null:
		return
	var page := UIKit.scaffold(self, false, UIKit.S3)
	var sub := tr("diff_" + session.difficulty)
	if session.remix:
		sub += " · " + tr("res_remix")
	var ladder := UIKit.icon_button("ladder", _open_ladder, tr("res_ladder"))
	ladder.name = "Ladder"
	UIKit.top_bar(page.top, UIKit.song_title(session.song), _leave, sub, ladder)
	_hero(page.body)

	var rewards := not (record.get("unlocked", []) as Array).is_empty() or int(record.get("carving_gained", 0)) > 0
	pager = UIKit.paged(page.body, [["overview", tr("res_tab_overview")], ["score", tr("res_tab_score")],
		["timing", tr("res_tab_timing")], ["tips", tr("res_tab_rewards" if rewards else "res_tab_tips")]])
	_overview(pager.add_page("OverviewPage", UIKit.S3, true))
	_breakdown(pager.add_page("ScorePage", UIKit.S2, true))
	_tendency(pager.add_page("TimingPage", UIKit.S3))
	_tips(pager.add_page("TipsPage", UIKit.S3, true))
	UIKit.pop_in(pager, 0.45)

	_footer(page.foot)
	Sound.ui("result")


# ---------------------------------------------------------------- hero


func _hero(box: Container) -> void:
	var hero := VBoxContainer.new()
	hero.name = "Hero"
	hero.add_theme_constant_override("separation", UIKit.S2)
	box.add_child(hero)
	# The seal: its warm halo flares as the grade stamps in and as the score lands.
	var grade := GradeSeal.new(session.grade_rank(), 58, 2)
	grade.name = "Grade"
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grade.stamped.connect(func() -> void:
		grade_stamped.emit(grade.rank)
		_flare(0.5 + 0.1 * maxi(grade.rank - Session.RANK_B, 0)))
	grade.animate(0.35)
	hero.add_child(grade)
	_seal = grade

	var score := Label.new()
	score.name = "Score"
	score.text = UIKit.fmt_score(session.score)
	PxType.label(score, "score", Color.WHITE, 2)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(score)
	_count_up(score, session.score)

	var words := UIKit.label(tr(grade_key(session.accuracy())), UIKit.LEAD, true, HORIZONTAL_ALIGNMENT_CENTER)
	words.name = "Words"
	words.add_theme_font_size_override("font_size", 30)
	words.add_theme_constant_override("line_spacing", -6)
	hero.add_child(words)

	var marks := HFlowContainer.new()
	marks.name = "Marks"
	marks.alignment = FlowContainer.ALIGNMENT_CENTER
	marks.add_theme_constant_override("h_separation", UIKit.S2)
	marks.add_theme_constant_override("v_separation", UIKit.S1)
	hero.add_child(marks)
	_marks(marks)


## The callouts under the score: the full combo ribbon and the best line, landing in turn.
func _marks(box: Container) -> void:
	if session.full_combo():
		# The full combo is its own reward: it lands just after the grade, with a chime and a flare.
		var fc := UIKit.badge(tr("res_full_combo"), "bronze")
		fc.name = "FullCombo"
		box.add_child(fc)
		if not UIKit.reduced_motion():
			fc.modulate.a = 0.0
			var tw := fc.create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func() -> void:
				Sound.ui("unlock")
				_flare(1.0))
			tw.tween_property(fc, "modulate:a", 1.0, 0.15)
	var new_best := bool(record.get("new_best", false))
	var text := _best_badge()
	if text == "":
		return
	var bl := UIKit.badge(text, "red" if new_best else "quiet")
	bl.name = "BestLine"
	box.add_child(bl)
	if UIKit.reduced_motion():
		best_revealed.emit.call_deferred(new_best)
	else:
		bl.modulate.a = 0.0
		var tw := bl.create_tween()
		tw.tween_interval(1.15)
		tw.tween_callback(func() -> void: best_revealed.emit(new_best))
		tw.tween_property(bl, "modulate:a", 1.0, 0.2)
		if new_best:
			bl.pivot_offset = Vector2(60, 24)
			bl.scale = Vector2(1.15, 1.15)
			tw.parallel().tween_property(bl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func grade_key(acc: float) -> String:
	var i := 0
	for t in TIERS:
		if acc >= t - 1e-9:
			i += 1
	return "grade_%d" % i


## The best callout: a new best (by how much), the first best, or the best (or ghost) still to beat.
func _best_badge() -> String:
	var prev := int(record.get("prev_best", 0))
	var ghost: Ghost = args.get("ghost")
	if bool(record.get("new_best", false)):
		if prev > 0:
			return tr("res_new_best_badge") % UIKit.fmt_score(session.score - prev)
		return tr("res_first_best_badge")
	if prev > 0:
		return tr("res_best") % [UIKit.fmt_score(prev), UIKit.fmt_score(prev - session.score)]
	if ghost != null and not ghost.is_empty():
		return tr("res_best") % [UIKit.fmt_score(ghost.final_score), UIKit.fmt_score(ghost.final_score - session.score)]
	return ""


## The old one-line best text (kept for callers and tests).
func _best_line() -> String:
	var prev := int(record.get("prev_best", 0))
	if bool(record.get("new_best", false)):
		if prev > 0:
			return tr("res_new_best_by") % UIKit.fmt_score(session.score - prev)
		return tr("res_first_best")
	return _best_badge()


# ---------------------------------------------------------------- pages


## Accuracy, longest combo, unison peak and the timing lean as tiles, then the four counts.
func _overview(box: VBoxContainer) -> void:
	var st := session.stats
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIKit.S2)
	grid.add_theme_constant_override("v_separation", UIKit.S2)
	box.add_child(grid)
	UIKit.stat_tile(grid, "Accuracy", tr("res_accuracy"), "%d%%" % roundi(session.accuracy() * 100.0))
	UIKit.stat_tile(grid, "MaxCombo", tr("res_tile_combo"), str(session.max_combo))
	var peak := _peak()
	var top := Session.UNISON_MULTS[Session.UNISON_MULTS.size() - 1]
	var secs := float(st.get("time_at_top", 0.0))
	var u_cap := tr("res_unison_time") % [UIKit.fmt_dec(secs, 0), Hud._mult_text(top)] if peak >= top and secs >= 0.5 else ""
	var ut := UIKit.stat_tile(grid, "UnisonPeak", tr("res_tile_unison"), Hud._mult_text(peak), u_cap)
	(ut.find_child("UnisonPeakValue", true, false) as Label).add_theme_color_override("font_color", WoodcutTheme.C_EMBER)
	var med := session.median_offset()
	var side := UIKit.side_of(med)
	var few := session.hit_offsets.size() < 4
	var lean_val := "—" if few else ("±0 ms" if side == "" else ("%+d ms" % roundi(med * 1000.0)).replace("-", "−"))
	var lean_cap := tr("res_timing_few") if few else tr({"": "res_lean_none", "early": "res_lean_early", "late": "res_lean_late"}[side])
	var tt := UIKit.stat_tile(grid, "Lean", tr("res_tile_timing"), lean_val, lean_cap)
	if side != "" and not few:
		(tt.find_child("LeanValue", true, false) as Label).add_theme_color_override("font_color", UIKit.side_color(side))
	# captions stay on one line, so the tiles of a row line up
	for t in grid.get_children():
		var cap := (t as Control).find_child("*Caption", true, false) as Label
		if cap != null:
			cap.autowrap_mode = TextServer.AUTOWRAP_OFF
			UIKit.fit_label(cap, 24)

	# the counts, as one strip: perfect / good / ok / missed
	var strip := PanelContainer.new()
	strip.name = "Counts"
	strip.theme_type_variation = UIKit.TILE
	box.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S1)
	strip.add_child(row)
	var counts := [
		["Perfect", int(st.perfect), "res_count_perfect", WoodcutTheme.C_BRONZE_HI],
		["Good", int(st.good), "res_count_good", WoodcutTheme.C_TEXT],
		["Ok", int(st.early) + int(st.late), "res_count_ok", WoodcutTheme.C_TEXT_2],
		["Miss", int(st.miss) + int(st.wrong), "res_count_miss", PixelPalette.RED[4]],
	]
	for c in counts:
		var col := VBoxContainer.new()
		col.name = c[0]
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var n := UIKit.label(str(c[1]), UIKit.VALUE, false, HORIZONTAL_ALIGNMENT_CENTER)
		n.name = c[0] + "Count"
		n.add_theme_font_size_override("font_size", 40)
		n.add_theme_color_override("font_color", c[3] if int(c[1]) > 0 else WoodcutTheme.C_TEXT_3)
		col.add_child(n)
		var w := UIKit.label(tr(c[2]), UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER)
		UIKit.fit_label(w, 24)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(w)


	_teaser(box)


## A row at the foot of the overview pointing at the last page: what opened, or the tip. Tapping it
## turns to that page.
func _teaser(box: VBoxContainer) -> void:
	var list: Array = record.get("unlocked", [])
	var carving := int(record.get("carving_gained", 0))
	var tag := tr("res_tip")
	var line := tip_text(session)
	if not list.is_empty() or carving > 0:
		tag = tr("res_unlocked")
		var parts: Array[String] = []
		for u in list:
			parts.append(UIKit.unlock_text(u))
		if carving > 0:
			parts.append(tr("res_carving") % carving)
		line = " · ".join(parts)
	elif line == "":
		tag = tr("res_closest")
		line = closest_unlock(session)
	if line == "":
		return
	var b := Button.new()
	b.name = "Teaser"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = UIKit.TOUCH
	var sb := PxStyle.make(WoodcutTheme.C_SUNK, Color(WoodcutTheme.C_BRONZE_DEEP, 0.8), WoodcutTheme.R_S, Vector4(18, 12, 18, 12))
	var down := sb.variant(Color(WoodcutTheme.C_RAISED_HI, 0.9), WoodcutTheme.C_BRONZE)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.pressed.connect(func() -> void:
		Sound.ui("tap")
		pager.go(3))
	UIKit.juice(b)
	box.add_child(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 18)
	b.add_child(m)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.S3)
	m.add_child(row)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var t := UIKit.overline(tag)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var l := UIKit.label(line, "", false)
	l.name = "TeaserText"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 28)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(l)
	var chev := TextureRect.new()
	chev.texture = WoodcutTheme.icon("chevron_right")
	chev.modulate = WoodcutTheme.C_BRONZE
	chev.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chev.custom_minimum_size = Vector2(30, 0)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chev)


func _peak() -> float:
	var st := session.stats
	return float(st.get("unison_peak", Session.UNISON_MULTS[int(st.get("max_unison", 0))]))


## Score = notes × unison: show how much each part added, so the game's ideas read as the way
## to a high score.
func _breakdown(box: VBoxContainer) -> void:
	box.name = "Breakdown"
	var b := session.score_breakdown()
	var st := session.stats
	var peak := _peak()
	var top := Session.UNISON_MULTS[Session.UNISON_MULTS.size() - 1]
	var head := UIKit.label(unison_headline(peak, float(st.get("time_at_top", 0.0)), top), UIKit.SUB, true)
	head.name = "UnisonHeadline"
	head.add_theme_color_override("font_color", WoodcutTheme.C_EMBER)
	box.add_child(head)
	var c := UIKit.card(box)
	c.add_theme_constant_override("separation", UIKit.S2)
	_row(c, tr("res_base"), UIKit.fmt_score(roundi(float(b.get("base", 0.0)))), "Base")
	_row(c, tr("res_unison") % Hud._mult_text(peak), "+" + UIKit.fmt_score(roundi(float(b.get("unison", 0.0)))), "Unison")
	if float(b.get("holds", 0.0)) > 0.0:
		_row(c, tr("res_holds"), "+" + UIKit.fmt_score(roundi(float(b.holds))), "Holds")
	if int(st.get("rests", 0)) > 0:
		# Keeping still is scored both ways: a bonus for every stand-still kept, a cost for ringing in one.
		var net := float(b.get("stills", 0.0)) - absf(float(b.get("penalties", 0.0)))
		var what := tr("res_still") % [int(st.get("still_kept", 0)), int(st.get("rests", 0))]
		var share := still_share(net, session.score)
		if share > 0:
			what += " · " + tr("res_still_share") % share
		_row(c, what, ("+" if net >= 0.0 else "−") + UIKit.fmt_score(roundi(absf(net))), "Still")
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", UIKit.S2)
	c.add_child(line)
	var total := _row(c, tr("res_total"), UIKit.fmt_score(session.score), "Total")
	total[0].add_theme_font_override("font", Palette.text_font("Bold"))
	total[1].add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI)
	total[1].add_theme_font_size_override("font_size", 36)
	box.add_child(UIKit.label(tr("res_formula"), UIKit.CAPTION))
	if session.slam:
		box.add_child(UIKit.label(tr("res_slam_note"), UIKit.CAPTION))


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


## One line of the breakdown: what on the left (wrapping), the points on the right. Returns [what, value].
func _row(box: Container, what: String, value: String, id: String) -> Array:
	var row := HBoxContainer.new()
	row.name = id
	row.add_theme_constant_override("separation", UIKit.S3)
	box.add_child(row)
	var l := UIKit.label(what, "", true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.name = id + "Label"
	row.add_child(l)
	var v := UIKit.label(value, "", false, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_theme_font_override("font", Palette.text_font("ExtraBold"))
	v.add_theme_font_size_override("font_size", 32)
	v.add_theme_color_override("font_color", WoodcutTheme.C_BRONZE)
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	v.name = id + "Value"
	row.add_child(v)
	return [l, v]


func _tendency(box: VBoxContainer) -> void:
	box.name = "Tendency"
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
	var c := UIKit.card(box)
	c.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tl := UIKit.label(text, UIKit.HEADER, true)
	tl.name = "TimingText"
	tl.add_theme_font_size_override("font_size", 32)
	if side != "" and session.hit_offsets.size() >= 4:
		tl.add_theme_color_override("font_color", UIKit.side_color(side))
	c.add_child(tl)
	var meter := TendencyMeter.new()
	meter.name = "Meter"
	meter.offsets = session.hit_offsets
	meter.custom_minimum_size.y = 180
	meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(meter)
	# A steady lean one way after a played song: one tap draws the notes that much earlier or later.
	var shift := timing_fix(session)
	if shift != 0.0 and not record.is_empty():
		var key := "res_fix_late" if shift > 0.0 else "res_fix_early"
		var fix := UIKit.button(tr(key) % roundi(absf(shift) * 1000.0), func() -> void: pass)
		fix.name = "FixTiming"
		fix.pressed.connect(func() -> void:
			Profile.set_setting("visual_offset", Profile.visual_offset() + shift)
			fix.text = tr("res_fixed")
			fix.disabled = true)
		box.add_child(fix)
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
			box.add_child(copy)
		else:
			var sl := UIKit.label(tr("res_run_saved") % saved.get_file(), UIKit.CAPTION)
			sl.name = "RunSaved"
			box.add_child(sl)
	var fr: Dictionary = args.get("frames", {})
	if not fr.is_empty() and not record.is_empty():
		var fl := UIKit.label(tr("res_frames") % [roundi(float(fr.fps)), int(fr.slow), roundi(float(fr.worst) * 1000.0)], UIKit.CAPTION)
		fl.name = "Frames"
		box.add_child(fl)


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


## What this run opened (celebrated), the carving points, the closest unlock and the tip.
func _tips(box: VBoxContainer) -> void:
	var list: Array = record.get("unlocked", [])
	var carving := int(record.get("carving_gained", 0))
	var closest := closest_unlock(session)
	if not list.is_empty() or carving > 0:
		var c := UIKit.card(box, true)
		c.name = "Unlocked"
		c.add_child(UIKit.label(tr("res_unlocked"), UIKit.PAPER_HEADER))
		var lines: Array[String] = []
		for u in list:
			lines.append(UIKit.unlock_text(u))
		if carving > 0:
			lines.append(tr("res_carving") % carving)
		for line in lines:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UIKit.S2)
			c.add_child(row)
			var dot := TextureRect.new()
			dot.texture = WoodcutTheme.icon("dot")
			dot.modulate = WoodcutTheme.C_BRONZE
			dot.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			dot.custom_minimum_size = Vector2(12, 36)
			dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(dot)
			var l := UIKit.label(line, UIKit.PAPER)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
		if not list.is_empty():
			UIKit.celebrate(self, lines[0], 2.2)
	var tip_line := tip_text(session)
	if tip_line != "":
		var tip := UIKit.card(box, list.is_empty() and carving <= 0)
		tip.name = "Tip"
		tip.add_child(UIKit.overline(tr("res_tip")))
		tip.add_child(UIKit.label(tip_line, UIKit.PAPER))
	if closest != "":
		var cc := PanelContainer.new()
		cc.theme_type_variation = UIKit.TILE
		cc.name = "Closest"
		box.add_child(cc)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", UIKit.S1)
		cc.add_child(v)
		v.add_child(UIKit.overline(tr("res_closest")))
		v.add_child(UIKit.label(closest, UIKit.CAPTION))


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


# ---------------------------------------------------------------- footer


## Next stop (the primary) over Play again and Back; without a next stop, Back beside Play again.
func _footer(foot: VBoxContainer) -> void:
	var play_args: Dictionary = args.get("play_args", {})
	var again := UIKit.button(tr("res_again"), func() -> void: app.replace("play", play_args), UIKit.PRIMARY)
	again.name = "Again"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var leave := UIKit.button(tr("res_done"), _leave)
	leave.name = "Done"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S2)
	var next := _next_song()
	if next != null:
		var go := UIKit.button(tr("res_next") % UIKit.song_title(next), func() -> void:
			app.replace("stop_card", {"song_id": next.id}), UIKit.PRIMARY)
		go.name = "Next"
		foot.add_child(go)
		again.theme_type_variation = ""
		again.custom_minimum_size.y = UIKit.TOUCH
		foot.add_child(row)
		row.add_child(again)
		row.add_child(leave)
	else:
		foot.add_child(row)
		leave.custom_minimum_size.y = UIKit.PRIMARY_H
		leave.size_flags_stretch_ratio = 0.6
		row.add_child(leave)
		row.add_child(again)


# ---------------------------------------------------------------- juice


var _seal: GradeSeal
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
	tw.tween_callback(func() -> void: l.pivot_offset = l.size * 0.5)
	tw.tween_property(l, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)


## A quick bright step of the seal's warm halo, then it settles to a low ember.
func _flare(strength: float) -> void:
	if _seal == null:
		return
	var tw := _seal.create_tween()
	tw.tween_property(_seal, "halo", 0.4 + 0.6 * strength * (0.4 if UIKit.reduced_motion() else 1.0), 0.05)
	tw.tween_property(_seal, "halo", 0.45, 0.5)


func _glow_rest() -> void:
	if _seal != null:
		_seal.halo = 0.45


func _next_song() -> SongData:
	if session.grade_rank() < Progression.CLEAR_GRADE:
		return null
	var story := SongLibrary.story()
	for i in story.size() - 1:
		if story[i].id == session.song.id and Progression.is_unlocked(story[i + 1].id):
			return story[i + 1]
	return null


## The ladder for this song: the platform's own when online, else the scores kept on this phone.
func _open_ladder() -> void:
	if Leaderboards.online():
		Leaderboards.show(Profile.board_id(session.song_key(), session.difficulty))
	else:
		app.open("boards")


func _leave() -> void:
	app.back()
