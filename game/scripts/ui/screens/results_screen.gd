extends Screen
## Results, on the mobile kit (UIKit's header): one screen that fits, no scrolling.
##   top bar   back · the song and difficulty · the ladder
##   hero      the score counts up on a dark bronze seal, then the grade (F to S+) stamps in; the
##             row's words, the full combo ribbon (its own reward) and the new best / best to beat
##             land in turn (T_* below). The hero grows with the screen's height.
##   pages     a segmented control over swipeable pages:
##               Overview  accuracy, longest combo, unison peak, timing lean as tiles, and the
##                         perfect / good / ok / missed counts, and a row pointing at the last page
##                         (when something opened it lights up and its bells ring: no modal)
##               Score     where the points came from (notes × unison, holds, stillness), the formula
##               Timing    the early/late histogram, the one-tap fix, smoothness, the saved run
##               Tips      (Rewards when something opened) what was unlocked, carving points, the
##                         closest unlock, and one concrete tip for next time
##   footer    UIKit.footer_actions(): Next stop (primary) with a replay icon beside it, or Play again
##             alone. Back is only in the top bar.
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

## The reveal, in seconds from the screen opening: the score counts up on a dark seal until T_STAMP,
## when the letter stamps in; then the full combo ribbon, the best badge, the pages, and (when
## something opened) the in-place celebration on the rewards row.
const T_STAMP := 1.0
const T_FC := 1.3
const T_BEST := 1.5
const T_PAGES := 1.75
const T_CELEBRATE := 2.1

var _hero_box: VBoxContainer
var _teaser_bells: BellMarks


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

	var rewards := _rewarded()
	pager = UIKit.paged(page.body, [["overview", tr("res_tab_overview")], ["score", tr("res_tab_score")],
		["timing", tr("res_tab_timing")], ["tips", tr("res_tab_rewards" if rewards else "res_tab_tips")]])
	# the overview is the page that sizes the pager; the others fit in it (or drag-scroll, no bar)
	_overview(pager.add_page("OverviewPage", UIKit.S3))
	_breakdown(pager.add_page("ScorePage", UIKit.S3, true))
	_tendency(pager.add_page("TimingPage", UIKit.S3, true))
	_tips(pager.add_page("TipsPage", UIKit.S3, true))
	var track := page.body.find_child("TabsTrack", false, false) as Control
	UIKit.pop_in(pager, T_PAGES)
	if track != null:
		UIKit.pop_in(track, T_PAGES)

	_footer(page.foot)
	Sound.ui("result")
	if rewards and not (record.get("unlocked", []) as Array).is_empty():
		_celebrate_in_place()


func _rewarded() -> bool:
	return not (record.get("unlocked", []) as Array).is_empty() or int(record.get("carving_gained", 0)) > 0


# ---------------------------------------------------------------- hero


## The hero grows with the screen: the seal and the score are larger on tall phones, and the hero
## takes the height the pages do not need, centred in it.
func _hero(box: Container) -> void:
	var extra := clampf(get_viewport_rect().size.y - 1440.0, 0.0, 240.0)
	var d := 58 + int(extra / 9.0)
	var hero := VBoxContainer.new()
	hero.name = "Hero"
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_theme_constant_override("separation", UIKit.S2)
	box.add_child(hero)
	_hero_box = hero
	# The seal stays dark while the score counts; at T_STAMP the letter stamps in with a bell, a flare
	# of its halo, a little shake and a buzz.
	# the letter grows with the seal, but a two-glyph rank (S+) keeps the smaller face so it stays inside the ring
	var rank := session.grade_rank()
	var grade := GradeSeal.new(rank, d, 3 if d >= 74 and Session.GRADES[maxi(rank, 0)].length() < 2 else 2)
	grade.name = "Grade"
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grade.stamped.connect(func() -> void:
		grade_stamped.emit(grade.rank)
		UIKit.vibrate(30)
		_shake()
		_flare(0.5 + 0.1 * maxi(grade.rank - Session.RANK_B, 0)))
	grade.animate(0.0 if UIKit.reduced_motion() else T_STAMP)
	# the halo's room: the seal stands in a box a little larger than itself
	var stage := CenterContainer.new()
	stage.name = "Stage"
	stage.custom_minimum_size.y = grade.custom_minimum_size.y + 2.0 * UIKit.S4
	stage.add_child(grade)
	hero.add_child(stage)
	_seal = grade

	var score := UIKit.number(UIKit.fmt_score(session.score), Color.WHITE, 3 if extra >= 120.0 else 2)
	score.name = "Score"
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


## The callouts under the score: the full combo ribbon, then the best badge, landing in turn.
func _marks(box: Container) -> void:
	if session.full_combo():
		# The full combo is its own reward: it lands just after the grade, with a chime and a flare.
		var fc := UIKit.badge(tr("res_full_combo"), "bronze")
		fc.name = "FullCombo"
		box.add_child(fc)
		_land(fc, T_FC, func() -> void:
			Sound.ui("unlock")
			_flare(1.0))
	var new_best := bool(record.get("new_best", false))
	var text := _best_badge()
	if text == "":
		return
	var bl := UIKit.badge(text, "red" if new_best else "quiet")
	bl.name = "BestLine"
	box.add_child(bl)
	_land(bl, T_BEST, func() -> void: best_revealed.emit(new_best))


## A badge pops in at `at` seconds (scale from its centre once it has a size), calling `then`.
func _land(c: Control, at: float, then: Callable) -> void:
	if UIKit.reduced_motion():
		then.call_deferred()
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(at)
	tw.tween_callback(func() -> void:
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(1.25, 1.25)
		then.call())
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short shake of the seal as the letter lands (whole art pixels).
func _shake() -> void:
	if UIKit.reduced_motion() or _seal == null:
		return
	var u := PxStyle.unit
	var x0 := _seal.position.x
	var tw := _seal.create_tween()
	for dx in [2.0, -2.0, 1.0, -1.0, 0.0]:
		tw.tween_property(_seal, "position:x", x0 + dx * u, 0.035)


## Something opened: once the pages are in, the rewards row lights bronze, its bells ring in place
## and the unlock sound plays (no veil, nothing to dismiss).
func _celebrate_in_place() -> void:
	var tw := create_tween()
	tw.tween_interval(0.0 if UIKit.reduced_motion() else T_CELEBRATE)
	tw.tween_callback(func() -> void:
		Sound.ui("unlock")
		if _teaser_bells != null:
			_teaser_bells.animate(0.05)
		if _teaser_panel != null and not UIKit.reduced_motion():
			_teaser_panel.self_modulate = Color(1.7, 1.4, 0.9)
			_teaser_panel.create_tween().tween_property(_teaser_panel, "self_modulate", Color.WHITE, 0.7))


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


## Accuracy, longest combo, unison peak and the timing lean as tiles, then the four counts, then the
## row that points at the last page.
func _overview(box: VBoxContainer) -> void:
	var st := session.stats
	var grid := GridContainer.new()
	grid.name = "Tiles"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIKit.S2)
	grid.add_theme_constant_override("v_separation", UIKit.S2)
	box.add_child(grid)
	UIKit.stat_tile(grid, "Accuracy", tr("res_accuracy"), str(roundi(session.accuracy() * 100.0)), "", "%")
	UIKit.stat_tile(grid, "MaxCombo", tr("res_tile_combo"), str(session.max_combo))
	var peak := _peak()
	var top := Session.UNISON_MULTS[Session.UNISON_MULTS.size() - 1]
	var secs := float(st.get("time_at_top", 0.0))
	var u_cap := tr("res_unison_time") % [UIKit.fmt_dec(secs, 0), Hud._mult_text(top)] if peak >= top and secs >= 0.5 else " "
	var ut := UIKit.stat_tile(grid, "UnisonPeak", tr("res_tile_unison"), Hud._mult_text(peak), u_cap)
	(ut.find_child("UnisonPeakValue", true, false) as Label).add_theme_color_override("font_color", WoodcutTheme.C_EMBER)
	var med := session.median_offset()
	var side := UIKit.side_of(med)
	var few := session.hit_offsets.size() < 4
	var lean_val := "-" if few else ("0" if side == "" else ("%+d" % roundi(med * 1000.0)).replace("-", "−"))
	var lean_cap := tr("res_timing_few") if few else tr({"": "res_lean_none", "early": "res_lean_early", "late": "res_lean_late"}[side])
	var tt := UIKit.stat_tile(grid, "Lean", tr("res_tile_timing"), lean_val, lean_cap, "" if few else "ms")
	if side != "" and not few:
		# the side's colour on the plain caption: the gold number face would muddy a blue tint
		(tt.find_child("LeanCaption", true, false) as Label).add_theme_color_override("font_color", UIKit.side_color(side))
	# captions stay on one line, so the tiles of a row line up
	for t in grid.get_children():
		var cap := (t as Control).find_child("*Caption", true, false) as Label
		if cap != null:
			cap.autowrap_mode = TextServer.AUTOWRAP_OFF
			UIKit.fit_label(cap, 24)

	# the counts, as one strip of numbers: perfect / good / ok / missed
	var strip := PanelContainer.new()
	strip.name = "Counts"
	strip.theme_type_variation = UIKit.TILE
	box.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.S1)
	strip.add_child(row)
	var counts := [
		["Perfect", int(st.perfect), "res_count_perfect", Color.WHITE],
		["Good", int(st.good), "res_count_good", WoodcutTheme.C_TEXT],
		["Ok", int(st.early) + int(st.late), "res_count_ok", WoodcutTheme.C_TEXT_2],
		["Miss", int(st.miss) + int(st.wrong), "res_count_miss", PixelPalette.RED[4]],
	]
	for c in counts:
		var col := VBoxContainer.new()
		col.name = c[0]
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", UIKit.S1)
		row.add_child(col)
		var n := UIKit.number(str(c[1]), c[3] if int(c[1]) > 0 else WoodcutTheme.C_TEXT_3)
		n.name = c[0] + "Count"
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var w := UIKit.label(tr(c[2]), UIKit.CAPTION, false, HORIZONTAL_ALIGNMENT_CENTER)
		UIKit.fit_label(w, 24)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(w)
	_teaser(box)


## A row at the foot of the overview pointing at the last page: what opened (the one reward card:
## bronze rim, the bells that ring when it lights up), else the tip or the closest unlock, in up to two
## lines. Tapping it turns to that page.
func _teaser(box: VBoxContainer) -> void:
	var list: Array = record.get("unlocked", [])
	var carving := int(record.get("carving_gained", 0))
	var rewards := _rewarded()
	var tag := tr("res_tip")
	var line := tip_text(session)
	if rewards:
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
	if not rewards:
		# a tip or the next unlock: its first sentence; the whole of it is a tap away
		var cut := line.find(". ")
		if cut > 0:
			line = line.substr(0, cut + 1)
	var b := PanelContainer.new()
	b.name = "Teaser"
	b.theme_type_variation = UIKit.CARD if rewards else UIKit.BOARD
	b.custom_minimum_size.y = UIKit.TOUCH
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_stylebox_override("panel", _teaser_style(rewards))
	b.gui_input.connect(func(e: InputEvent) -> void:
		var up: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) \
			or (e is InputEventScreenTouch and not e.pressed)
		if up and Rect2(Vector2.ZERO, b.size).has_point(e.position):
			Sound.ui("tap")
			pager.go(3))
	box.add_child(b)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.S3)
	b.add_child(row)
	if rewards and not list.is_empty():
		_teaser_bells = BellMarks.new(3, 44.0)
		_teaser_bells.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_teaser_bells)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var t := UIKit.overline(tag)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(t)
	var l := UIKit.label(line, "", true)
	l.name = "TeaserText"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# wraps (never an ellipsis): two lines at 28, a longer list drops to 26 for a third
	l.add_theme_font_size_override("font_size", 28)
	l.resized.connect(func() -> void:
		if l.get_line_count() > 2 and l.get_theme_font_size("font_size") > 26:
			l.add_theme_font_size_override("font_size", 26), CONNECT_DEFERRED)
	l.max_lines_visible = 3
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(l)
	var chev := TextureRect.new()
	chev.texture = WoodcutTheme.icon("chevron_right")
	chev.modulate = WoodcutTheme.C_BRONZE
	chev.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	chev.custom_minimum_size = Vector2(30, 0)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chev)
	_teaser_panel = b


var _teaser_panel: PanelContainer


## The teaser's panel: the theme's card or board with tighter padding.
func _teaser_style(reward: bool) -> PxStyle:
	var sb: PxStyle = (get_theme_stylebox("panel", UIKit.CARD if reward else UIKit.BOARD) as PxStyle).duplicate()
	sb.content_margin_top = UIKit.S3
	sb.content_margin_bottom = UIKit.S3
	sb.content_margin_left = UIKit.S4
	sb.content_margin_right = UIKit.S3
	return sb


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
	# one section: the unison headline, the parts, and the total at the foot, filling the page
	var c := UIKit.card(box)
	c.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", UIKit.S2)
	var head := UIKit.label(unison_headline(peak, float(st.get("time_at_top", 0.0)), top), UIKit.SUB, true)
	head.name = "UnisonHeadline"
	head.add_theme_color_override("font_color", WoodcutTheme.C_EMBER)
	c.add_child(head)
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
	UIKit.spacer(c, 0.0, true)
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", UIKit.S2)
	c.add_child(line)
	var total := _row(c, tr("res_total"), UIKit.fmt_score(session.score), "Total")
	total[0].add_theme_font_override("font", Palette.text_font("Bold"))
	total[1].add_theme_color_override("font_color", WoodcutTheme.C_BRONZE_HI)
	total[1].add_theme_font_size_override("font_size", 36)
	total[1].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	total[0].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	var tl := UIKit.label(text, UIKit.HEADER, true)
	tl.name = "TimingText"
	tl.add_theme_font_size_override("font_size", 32)
	if side != "" and session.hit_offsets.size() >= 4:
		tl.add_theme_color_override("font_color", UIKit.side_color(side))
	c.add_child(tl)
	var meter := TendencyMeter.new()
	meter.name = "Meter"
	meter.offsets = session.hit_offsets
	c.add_child(meter)
	# A steady lean one way after a played song: one tap draws the notes that much earlier or later.
	var shift := timing_fix(session)
	# the chart is capped (about 300 px), a little shorter when the fix button needs the room
	var fixable := shift != 0.0 and not record.is_empty()
	meter.custom_minimum_size.y = 240 if fixable else 260
	# the split as numbers (early / on the beat / late), unless the fix button needs the room
	var n := session.hit_offsets.size()
	if n >= 4 and not fixable:
		var split := {"early": 0, "": 0, "late": 0}
		for o in session.hit_offsets:
			split[UIKit.side_of(o)] += 1
		var row := HBoxContainer.new()
		row.name = "Split"
		row.add_theme_constant_override("separation", UIKit.S2)
		box.add_child(row)
		for k in [["Early", "early", "res_meter_early"], ["OnBeat", "", "res_meter_on"], ["Late", "late", "res_meter_late"]]:
			UIKit.stat_tile(row, k[0], tr(k[2]), str(roundi(100.0 * split[k[1]] / n)), "", "%")
	if fixable:
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
		var c := UIKit.card(box, true)   # the one reward card
		c.get_parent().name = "UnlockedCard"
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
	var tip_line := tip_text(session)
	if tip_line != "":
		var tip := UIKit.card(box)
		tip.name = "Tip"
		tip.add_child(UIKit.overline(tr("res_tip")))
		tip.add_child(UIKit.label(tip_line, UIKit.PAPER))
	if closest != "":
		var v := UIKit.card(box)
		v.name = "Closest"
		v.add_theme_constant_override("separation", UIKit.S1)
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
	var replay := func() -> void: app.replace("play", play_args)
	var next := _next_song()
	if next != null:
		# the next stop is the primary; playing again is the icon beside it
		var go := UIKit.button(tr("res_next") % UIKit.song_title(next), func() -> void:
			app.replace("stop_card", {"song_id": next.id}), UIKit.PRIMARY)
		go.name = "Next"
		var again := UIKit.icon_button("replay", replay, tr("res_again"), "")
		again.name = "Again"
		UIKit.footer_actions(foot, go, again)
	else:
		var again := UIKit.button(tr("res_again"), replay, UIKit.PRIMARY)
		again.name = "Again"
		UIKit.footer_actions(foot, again)


# ---------------------------------------------------------------- juice


var _seal: GradeSeal
var _ticks := 0


## The score counts up over T_STAMP in about 24 audible ticks and swells a step as it lands (the
## seal stamps at the same moment).
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
			count_tick.emit(roundi(v)), 0.0, float(target), T_STAMP) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: count_done.emit(target))
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
