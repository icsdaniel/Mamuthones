extends Screen
## The story, on the mobile kit: the seven stops of the procession as a swipeable carousel of big
## picture cards (MenuKit.picture_card + Carousel), the next stop centred when the screen opens.
## Each card: the stop's living pixel picture (StopPicture; only the centred card animates), the
## stop number and day, its name, the two-sentence card text, the best grade (a round seal, FC pill)
## and a status pill (next / cleared / remix open); a locked stop lies under the night veil with a
## lock and what opens it. Progress dots under the carousel, the closest goal as one line, and the
## primary ("Open: <stop>": its card) pinned in the thumb zone. A tap on the centred
## card opens it too; a tap on a peeking neighbour brings it to the centre.

var carousel: Carousel
var _dots: PageDots
var _play: Button
var _pics: Array[StopPicture] = []


func build() -> void:
	_pics.clear()
	var story := SongLibrary.story()
	var cleared := 0
	for s in story:
		if Progression.cleared(s.id):
			cleared += 1
	var page := UIKit.scaffold(self, false, UIKit.S3)
	UIKit.top_bar(page.top, tr("story_title"), on_back, tr("story_progress") % [cleared, story.size()])
	var next_id := Progression.next_stop()
	var start := 0
	carousel = Carousel.new()
	carousel.name = "Carousel"
	page.body.add_child(carousel)
	for i in story.size():
		var song: SongData = story[i]
		if song.id == next_id:
			start = i
		carousel.add_card(_card(song, song.id == next_id))
	_dots = PageDots.new(story.size(), start)
	_dots.name = "Dots"
	for i in story.size():
		if Progression.cleared(story[i].id):
			_dots.done.append(i)
	page.body.add_child(_dots)
	var goal := UIKit.goal_text()
	if goal != "":
		var g := PanelContainer.new()
		g.name = "Goal"
		g.theme_type_variation = UIKit.TILE
		page.body.add_child(g)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		g.add_child(v)
		v.add_child(UIKit.overline(tr("story_next_goal")))
		var gl := UIKit.label(goal, UIKit.CAPTION)
		gl.name = "GoalText"
		gl.add_theme_constant_override("line_spacing", -2)
		v.add_child(gl)
	_play = UIKit.button("", _open_current, UIKit.PRIMARY)
	_play.name = "OpenStop"
	UIKit.footer_actions(page.foot, _play)
	carousel.page_changed.connect(_on_page)
	carousel.tapped.connect(func(i: int) -> void:
		var b := carousel.card(i) as Button
		if b != null and not b.disabled:
			Sound.ui("tap")
			b.pressed.emit())
	carousel.go(start, true)
	_on_page(start)


func _card(song: SongData, is_next: bool) -> Button:
	var open := Progression.is_unlocked(song.id)
	# The card is a Button (named Stop<n>) so tests and the carousel's tap can press it; the carousel
	# handles every touch, so the button itself ignores the mouse.
	var b := Button.new()
	b.name = "Stop%d" % song.stop
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not open
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: app.open("stop_card", {"song_id": song.id}))
	var pic := StopPicture.new()
	pic.name = "Picture"
	pic.stop = song.stop
	pic.view = "card"
	pic.px = int(PixelFrame.px_for(self))
	var card_rect := Rect2(Vector2(StopBackdrops.data(song.stop).card), Vector2(StopCells.CARD))
	pic.focus = card_rect.get_center() + Vector2(0, 10)
	pic.veiled = not open
	pic.animate = false
	pic.bpm = song.bpm * 0.5
	_pics.append(pic)
	var parts := MenuKit.picture_card(pic, is_next)
	var panel: PanelContainer = parts[0]
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(panel)
	var text: VBoxContainer = parts[1]
	var over := tr("story_stop_overline") % song.stop
	var date := UIKit.stop_date(song)
	if date != "":
		over += " · " + date
	var o := UIKit.overline(over)
	o.name = "Overline"
	text.add_child(o)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.S2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(head)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tcol.add_theme_constant_override("separation", 0)
	head.add_child(tcol)
	var name_l := UIKit.label(UIKit.song_title(song), UIKit.HEADER, false)
	name_l.name = "Name"
	UIKit.fit_label(name_l, 28)
	if not open:
		name_l.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	tcol.add_child(name_l)
	if open:
		var g := MenuKit.grade_mark(UIKit.best_grade(song.id), UIKit.any_full_combo(song.id))
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(g)
	if not open:
		text.add_child(MenuKit.lock_line(tr("story_locked")))
		return b
	var fact := UIKit.label(tr("stop_fact_%d" % song.stop), "")
	fact.name = "Fact"
	fact.add_theme_font_size_override("font_size", 28)
	fact.add_theme_color_override("font_color", WoodcutTheme.C_TEXT_2)
	fact.add_theme_constant_override("line_spacing", -2)
	text.add_child(fact)
	var pills := HBoxContainer.new()
	pills.name = "Pills"
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pills.add_theme_constant_override("separation", UIKit.S2)
	if is_next:
		pills.add_child(UIKit.badge(MenuKit.sentence_case(tr("story_next")), "bronze"))
	elif Progression.cleared(song.id):
		pills.add_child(UIKit.badge(MenuKit.sentence_case(tr("story_cleared"))))
	if song.has_remix() and Progression.remix_unlocked(song.id):
		pills.add_child(UIKit.badge(MenuKit.sentence_case(tr("story_remix_open"))))
	if pills.get_child_count() > 0:
		UIKit.spacer(text, UIKit.S1)
		text.add_child(pills)
	return b


## The centred card: its picture comes alive (the others hold still), the dots and the primary follow.
func _on_page(i: int) -> void:
	for k in _pics.size():
		var on := k == i and not UIKit.reduced_motion() and not _pics[k].veiled
		if _pics[k].animate != on:
			_pics[k].animate = on
	_dots.current = i
	var song: SongData = SongLibrary.story()[i]
	var open := Progression.is_unlocked(song.id)
	_play.disabled = not open
	_play.text = tr("story_open") % UIKit.song_title(song) if open else tr("story_locked_short")


func _open_current() -> void:
	var b := carousel.card(carousel.current) as Button
	if b != null and not b.disabled:
		b.pressed.emit()
