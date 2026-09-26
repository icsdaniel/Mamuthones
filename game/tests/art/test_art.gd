extends TestCase
## Art area tests: every art script loads, MaskSpec rules, the theme, every stop and every drawing
## function runs to the end without a script error, the ProcessionScene API behaves, and its per-frame
## and rebuild costs stay small.


## Runs `painter` inside a real _draw() and records whether it reached the end (a script error in the
## drawing code aborts the function, so `done` stays false).
class _Probe:
	extends Control
	var painter: Callable
	var done := false
	var usec := 0  ## Fastest draw so far: the first one also pays one-time texture loads.
	var draws := 0

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		painter.call(self)
		var took := Time.get_ticks_usec() - t0
		usec = took if draws == 0 else mini(usec, took)
		draws += 1
		done = true


## Redraws a probe a few times so its `usec` is the steady cost, not a one-off or a busy moment.
func _settle(p: _Probe, times := 4) -> void:
	for i in times:
		p.queue_redraw()
		await tree.process_frame


func _probe(painter: Callable, sz := Vector2(720, 1440)) -> _Probe:
	var p := _Probe.new()
	p.size = sz
	p.painter = painter
	tree.root.add_child(p)
	return p


func _frames(n := 2) -> void:
	for i in n:
		await tree.process_frame


func test_every_art_script_loads() -> void:
	var dir := "res://scripts/art"
	var count := 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var s: Script = load(dir.path_join(f))
			check(s != null, "%s loads" % f)
			count += 1
	check(count >= 12, "all art scripts present (found %d)" % count)
	for shader in ["res://shaders/woodcut_fire.gdshader", "res://shaders/woodcut_fog.gdshader"]:
		check(load(shader) is Shader, "%s loads" % shader)
	for t in ["paper", "grain", "hatch", "chisel", "fog", "speckle", "glow", "fleece"]:
		check(Palette.tex(t) != null, "texture %s" % t)


func test_mask_finishes_stay_black() -> void:
	# Every finish renders black to dark brown-black: base wood with its grain overlay < 12 % luminance.
	for id in MaskView.FINISH:
		var f: Dictionary = MaskView.FINISH[id]
		var wood: Color = (f.base as Color).lerp(Palette.BONE, float(f.grain))
		var lum := wood.srgb_to_linear().get_luminance()   # relative luminance, as in WCAG
		check(lum < 0.12, "finish %s stays dark (luminance %.3f)" % [id, lum])
	for id in MaskView.PATINA:
		check(float(MaskView.PATINA[id].w) <= 1.0, "patina %s never widens the cuts" % id)


func test_mask_spec() -> void:
	var d := MaskSpec.default()
	check(MaskSpec.validate(d), "default spec is valid")
	check_eq(d.size(), MaskSpec.PARTS.size(), "default has every part")
	check(not MaskSpec.validate({}), "empty spec is invalid")
	check(not MaskSpec.validate("mask"), "non-dictionary is invalid")
	var bad := d.duplicate()
	bad["nose"] = "clown"
	check(not MaskSpec.validate(bad), "unknown option rejected")
	check(MaskSpec.errors(bad).size() == 1, "one error reported for one bad option")
	var extra := d.duplicate()
	extra["horns"] = "big"
	check(not MaskSpec.validate(extra), "unknown part rejected")
	var fixed := MaskSpec.sanitize({"nose": "long", "eyes": 7, "horns": "x"})
	check(MaskSpec.validate(fixed), "sanitize gives a valid spec")
	check_eq(fixed["nose"], "long", "sanitize keeps valid values")
	check_eq(fixed["eyes"], MaskSpec.OPTIONS["eyes"][0], "sanitize replaces bad values with the default")
	var total := 0
	for part in MaskSpec.PARTS:
		var opts := MaskSpec.options(part)
		check(opts.size() >= 3, "%s has options" % part)
		total += opts.size() - 1
		var first := MaskSpec.requirement(part, opts[0])
		check(first.stop == 1 and first.cost == 0, "%s default is free" % part)
		for o in opts:
			var r := MaskSpec.requirement(part, o)
			check(r.stop >= 1 and r.stop <= 7, "%s/%s unlocks at a story stop" % [part, o])
			check(MaskSpec.name_of(o, "en") != o or o.length() == 0, "%s has an English name" % o)
			check(MaskSpec.NAMES.has(o) and MaskSpec.NAMES[o].has("it"), "%s has an Italian name" % o)
		# Finer details come later: requirements never go backwards within a part.
		for i in range(1, opts.size()):
			var a := MaskSpec.requirement(part, opts[i - 1])
			var b := MaskSpec.requirement(part, opts[i])
			check(b.stop >= a.stop and b.cost >= a.cost, "%s unlocks in order" % part)
	var order := MaskSpec.unlock_order()
	check_eq(order.size(), total, "unlock order lists every non-default option")
	for i in range(1, order.size()):
		check(order[i].stop > order[i - 1].stop or (order[i].stop == order[i - 1].stop and order[i].cost >= order[i - 1].cost), "unlock order sorted")
	check_eq(MaskSpec.requirement("nose", "clown").stop, 99, "unknown option never unlocks")
	# Tradition guard: no joke or bright options sneak in.
	for part in MaskSpec.PARTS:
		for o in MaskSpec.options(part):
			for word in ["neon", "clown", "gold", "rainbow", "pink", "glow", "skull", "horn"]:
				check(not (word in o), "no '%s' option (%s)" % [word, o])


func test_theme() -> void:
	var t := WoodcutTheme.build()
	check(t != null, "theme builds")
	check(t.default_font != null, "theme has a default font")
	check(t.default_font_size >= 26, "default text is at least 26 px")
	for type in ["Button", "AccentButton", "OptionButton"]:
		var sb := t.get_stylebox("normal", type)
		check(sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null, "%s is a textured box" % type)
		check(t.get_stylebox("pressed", type) != null and t.get_stylebox("disabled", type) != null, "%s has pressed/disabled" % type)
	for type in ["Label", "TitleLabel", "HeaderLabel", "SubheaderLabel", "CaptionLabel", "HudLabel", "PaperLabel", "PaperHeaderLabel", "Button", "CheckButton", "LineEdit"]:
		check(t.get_font_size("font_size", type) >= 24, "%s text is at least 24 px" % type)
		check(t.get_font("font", type) != null, "%s has a font" % type)
	for icon in ["checked", "unchecked"]:
		check(t.get_icon(icon, "CheckButton") != null, "CheckButton %s icon" % icon)
	check(t.get_icon("grabber", "HSlider") != null, "slider grabber icon")
	check(t.get_stylebox("panel", "CardPanel") is StyleBoxTexture, "paper card panel")
	check(t.get_stylebox("grabber", "VScrollBar") is StyleBoxTexture, "scroll grabber")
	check_eq(t.get_type_variation_base("AccentButton"), &"Button", "AccentButton is a Button variation")


func test_text_contrast() -> void:
	# WCAG contrast of the text pairs the theme uses (4.5 normal text, 3 large bold text).
	check(_contrast(Palette.BONE, Palette.WOOD) >= 7.0, "bone on wood")
	check(_contrast(Palette.BONE_DIM, Palette.NIGHT) >= 4.5, "caption on night")
	check(_contrast(Palette.BLACK, Palette.BONE) >= 7.0, "ink on paper")
	check(_contrast(Palette.EMBER, Palette.NIGHT) >= 4.5, "ember on night")
	check(_contrast(Palette.BONE, Palette.RED) >= 3.0, "bone on red (large bold only)")
	var th := WoodcutTheme.build()
	check(_contrast(th.get_color("font_placeholder_color", "LineEdit"), Palette.NIGHT) >= 4.5, "LineEdit placeholder readable")
	# Progress text sits on the fill: it must not be the ember fill (bone on ember is about 1.5:1).
	check(_contrast(th.get_color("font_color", "ProgressBar"), Palette.RED) >= 3.0, "progress text on its red fill (large bold)")
	check(th.get_constant("outline_size", "ProgressBar") >= 8, "progress text has a heavy ink outline")


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func test_every_stop_draws() -> void:
	for n in range(1, StopBackdrops.COUNT + 1):
		var p := _probe(func(ci):
			StopBackdrops.paint(ci, n, 720.0, 480.0, 458.0)
			StopBackdrops.paint_front(ci, n, 720.0, 480.0, 458.0))
		await _frames()
		check(p.done, "stop %d backdrop draws to the end" % n)
		var inf := StopBackdrops.info(n)
		check(inf.has("lit") and inf.has("fires") and inf.has("fog"), "stop %d has lighting info" % n)
		p.queue_free()
	# The stops differ: sky kinds and fire counts are not all the same.
	var skies := {}
	for n in range(1, 8):
		skies[StopBackdrops.info(n).sky] = true
	check(skies.size() >= 4, "at least four kinds of sky across the stops")


func test_procession_scene_every_stop() -> void:
	var scene := ProcessionScene.new()
	scene.size = Vector2(720, 480)
	tree.root.add_child(scene)
	await _frames()
	for n in range(1, 8):
		scene.set_stop(n)
		await _frames(2)
		check_eq(scene.stop, n, "scene on stop %d" % n)
		check_eq(scene._fires.size(), StopBackdrops.info(n).fires.size(), "stop %d fire count" % n)
		check(scene._back.get_canvas_item().is_valid(), "stop %d backdrop exists" % n)
	scene.queue_free()


func test_procession_api() -> void:
	var scene := ProcessionScene.new()
	scene.size = Vector2(720, 480)
	tree.root.add_child(scene)
	await _frames()
	scene.set_look({"nose": "long", "patina": "old"}, "dark_brown", "dark")
	check(MaskSpec.validate(scene.mask), "set_look sanitizes the mask")
	check_eq(scene.fleece, "dark_brown", "fleece set")
	scene.set_look(MaskSpec.default(), "neon", "gold")
	check_eq(scene.fleece, "black", "unknown fleece falls back")
	check_eq(scene.straps, "natural", "unknown straps fall back")
	# A jolt lifts the player's Mamuthone.
	var y0: float = scene._player.root.position.y
	scene.jolt("bell")
	await _frames(4)
	check(scene._player.root.position.y < y0 - 1.0, "jolt lifts the player (%.1f -> %.1f)" % [y0, scene._player.root.position.y])
	for kind in ["step", "bell", "ring", "miss", "nonsense"]:
		scene.jolt(kind)
	await _frames(2)
	check(scene._miss_flash > 0.0, "a miss flashes the player")
	# Unison closes the row up.
	scene.set_unison(0)
	var loose := _row_width(scene)
	scene.set_unison(5)
	var tight := _row_width(scene)
	check(tight < loose * 0.85, "unison 5 row is tighter (%.0f vs %.0f)" % [tight, loose])
	scene.set_unison(99)
	check_eq(scene.unison, 5, "unison clamps")
	# At full unison the row jolts together; at zero it straggles.
	scene.set_unison(5)
	scene.jolt("step")
	var delays5 := _max_delay(scene)
	await _frames(20)
	scene.set_unison(0)
	scene.jolt("step")
	var delays0 := _max_delay(scene)
	check(delays5 < delays0, "the row jolts closer together at high unison")
	scene.set_ghost_delta(0.5)
	check(scene._ghost.visible, "ghost shows")
	scene.hide_ghost()
	check(not scene._ghost.visible, "ghost hides")
	scene.set_still(true)
	scene.throw_rope()
	await _frames(3)
	check(scene._rope_t > 0.0, "rope animates")
	scene.set_reduced_motion(true)
	check(not scene._sparks.visible, "reduced motion hides sparks")
	scene.set_reduced_motion(false)
	# Any size works, including a 3:4 tablet and a thin band.
	for sz in [Vector2(1080, 1440), Vector2(720, 240), Vector2(720, 1440)]:
		scene.size = sz
		await _frames(2)
		check(scene._w >= 599.0 and scene._h >= 239.0, "layout for %s" % sz)
	scene.queue_free()


func test_procession_staging_and_feedback() -> void:
	var scene := ProcessionScene.new()
	scene.size = Vector2(720, 480)
	tree.root.add_child(scene)
	await _frames(3)
	# Every stop stages the row differently (who is there, where, how big, which way).
	var seen := {}
	for n in range(1, StopBackdrops.COUNT + 1):
		scene.set_stop(n)
		await _frames(1)
		var sig := []
		for w in scene._walkers:
			sig.append([w.root.visible, snappedf(w.target_x, 1.0), snappedf(w.base_y, 1.0), snappedf(w.sc, 0.01), w.flip])
		var key := str(sig)
		check(not seen.has(key), "stop %d has its own staging" % n)
		seen[key] = n
		check(scene._player.root.visible, "your Mamuthone walks at stop %d" % n)
	check(StopBackdrops.row(1).front == 1 and StopBackdrops.row(1).isso == 0, "the Workshop shows your Mamuthone alone")
	check(StopBackdrops.row(5).has("onlooker"), "the Rope has someone for the rope to catch")
	# A miss makes your Mamuthone visibly stumble: pitched over and dropped, then recovering.
	scene.set_stop(4)
	await _frames(20)
	var r0: float = absf(scene._player.root.rotation)
	var y0: float = scene._player.root.position.y
	scene.jolt("miss")
	check(scene._stumble_t >= 0.0, "a miss scuffs up dust")
	# Sample the stumble over its first 0.3 s of game time (headless frames can be very short).
	var max_rot := 0.0
	var max_drop := 0.0
	var t_end := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < t_end:
		await tree.process_frame
		max_rot = maxf(max_rot, absf(scene._player.root.rotation))
		max_drop = maxf(max_drop, scene._player.root.position.y - y0)
	check(max_rot > r0 + 0.1, "a miss pitches your Mamuthone over (%.2f rad)" % max_rot)
	check(max_drop > 3.0, "and drops him (%.1f px)" % max_drop)
	await tree.create_timer(1.5).timeout
	check(absf(scene._player.root.rotation) < 0.05, "then he recovers")
	# Bells ring: motion is shown per Mamuthone; at full unison every front Mamuthone rings at once.
	scene.set_unison(5)
	scene.jolt("bell")
	await tree.create_timer(0.03).timeout
	var ringing := 0
	var front := 0
	for w in scene._walkers:
		if w.line == 0 and not w.is_isso and w.root.visible:
			front += 1
			if w.ring > 0.3:
				ringing += 1
	check(ringing == front and front >= 2, "full unison: the whole front line rings together (%d of %d)" % [ringing, front])
	# Resizes re-render the baked textures once, after the size settles (not on every step).
	var before := scene.bake_count
	for i in 6:
		scene.size = Vector2(720 + i * 20, 480)
		await tree.process_frame
	check(scene.bake_count == before, "no re-render while resizing")
	await tree.create_timer(ProcessionScene.REBAKE_DELAY + 0.2).timeout
	await _frames(2)
	check(scene.bake_count == before + 1, "one re-render once the size settles (%d)" % (scene.bake_count - before))
	# The ghost is off until the game asks for it (cards and store shots have none).
	check(not scene._ghost.visible, "no ghost by default")
	scene.queue_free()


func test_rope_is_natural_fibre() -> void:
	check(Palette.ROPE != Palette.RED and Palette.ROPE.s < 0.5, "the soha is drawn as natural rush or hemp, not red")
	var src := FileAccess.get_file_as_string("res://scripts/art/figures.gd") + FileAccess.get_file_as_string("res://scripts/art/procession_scene.gd")
	var rope_lines := 0
	for line in src.split("\n"):
		if ("loop" in line or "rope" in line.to_lower()) and "Palette.RED," in line:
			rope_lines += 1
	check_eq(rope_lines, 0, "no rope drawn in red in the scene or the figures")


func _row_width(scene: ProcessionScene) -> float:
	var lo := INF
	var hi := -INF
	for w in scene._walkers:
		if not w.is_isso:
			lo = minf(lo, w.target_x)
			hi = maxf(hi, w.target_x)
	return hi - lo


func _max_delay(scene: ProcessionScene) -> float:
	var m := 0.0
	for w in scene._walkers:
		for p in w.pending:
			m = maxf(m, float(p[0]))
	return m


func test_procession_cost() -> void:
	# Draw cost: rebuilding every layer (a stop change) and the steady per-frame update.
	var scene := ProcessionScene.new()
	scene.size = Vector2(720, 480)
	tree.root.add_child(scene)
	await _frames(3)
	var worst_frame := 0
	scene.set_stop(2)
	await _frames(2)
	for i in 30:
		if i % 3 == 0:
			scene.jolt("bell")
		if i == 5:
			scene.throw_rope()
		await tree.process_frame
		worst_frame = maxi(worst_frame, scene.last_process_usec)
	check(worst_frame < 1500, "per-frame update under 1.5 ms (worst %d us)" % worst_frame)
	# Full redraw of every retained layer, timed inside _draw via a probe that paints the same layers.
	var probe := _probe(func(ci):
		StopBackdrops.paint(ci, 2, 720.0, 480.0, 458.0)
		StopBackdrops.paint_front(ci, 2, 720.0, 480.0, 458.0)
		for i in 7:
			ci.draw_set_transform(Vector2(100 + i * 70, 458))
			Figures.mamuthone(ci, 206.0, MaskSpec.default(), "black", "natural", Palette.EMBER, 1)
		ci.draw_set_transform(Vector2.ZERO))
	await _frames(2)
	await _settle(probe)
	check(probe.done, "full procession redraw completes")
	check(probe.usec < 60000, "full rebuild of the scene's geometry under 60 ms, once per stop (took %d us)" % probe.usec)
	print("  procession: worst per-frame update %d us, full geometry rebuild %d us" % [worst_frame, probe.usec])
	probe.queue_free()
	scene.queue_free()


func test_lane_skin_draws_everything() -> void:
	var field := Rect2(0, 0, 720, 1100)
	var p := _probe(func(ci):
		LaneSkin.draw_lanes(ci, field, [0.0, 1.0, 0.5])
		LaneSkin.draw_hit_line(ci, field, 0.5)
		var lanes := LaneSkin.lane_rects(field)
		LaneSkin.draw_step(ci, lanes[0], 300)
		LaneSkin.draw_step(ci, lanes[1], 300, true)
		LaneSkin.draw_hold(ci, lanes[2], 600, 400, true)
		LaneSkin.draw_hold(ci, lanes[0], 600, 400, false)
		LaneSkin.draw_bell(ci, field, 200, true)
		LaneSkin.draw_bell(ci, field, 250, false)
		LaneSkin.draw_ring(ci, field, lanes[1], 500, true)
		LaneSkin.draw_swipe(ci, field, 700, 1)
		LaneSkin.draw_swipe(ci, field, 760, -1)
		LaneSkin.draw_rest(ci, field, 800, 900)
		for lane in 3:
			for st in ["idle", "cued", "pressed", "hit", "miss", "weird"]:
				LaneSkin.draw_button(ci, Rect2(lane * 240, 1110, 240, 120), lane, st)
		for q in ["perfect", "good", "early", "late", "miss", "held", "wrong"]:
			LaneSkin.draw_hit_burst(ci, Vector2(360, 990), q, 0.1))
	await _frames()
	await _settle(p)
	check(p.done, "every LaneSkin function draws to the end")
	check(p.usec < 20000, "a busy field draws in under 20 ms even in a debug build (took %d us)" % p.usec)
	p.queue_free()
	var lanes := LaneSkin.lane_rects(field)
	check_eq(lanes.size(), 3, "three lanes")
	check_near(lanes[1].position.x, 240.0, 0.01, "lanes split the field evenly")
	var hy := LaneSkin.hit_line_y(field)
	check_near(LaneSkin.note_y(field, 0.0, 600.0), hy, 0.01, "a note due now sits on the hit line")
	check_near(LaneSkin.note_y(field, 1.0, 600.0), hy - 600.0, 0.01, "a note due in 1 s is speed px above")


func test_hit_burst_lifetime() -> void:
	var p := _probe(func(ci):
		check(LaneSkin.draw_hit_burst(ci, Vector2(100, 100), "perfect", 0.0), "burst alive at 0")
		check(not LaneSkin.draw_hit_burst(ci, Vector2(100, 100), "perfect", LaneSkin.BURST_TIME + 0.01), "burst over after BURST_TIME")
		check(not LaneSkin.draw_hit_burst(ci, Vector2(100, 100), "good", -1.0), "burst not started"))
	await _frames()
	check(p.done, "burst probe ran")
	p.queue_free()


func test_mask_logo_icon_draw() -> void:
	var p := _probe(func(ci):
		for part in MaskSpec.PARTS:
			for o in MaskSpec.options(part):
				var spec := MaskSpec.default()
				spec[part] = o
				MaskView.paint(ci, Vector2(200, 200), 60.0, spec, 2, true, part)
				MaskView.paint(ci, Vector2(200, 200), 6.0, spec, 0)
		Logo.paint(ci, Vector2(300, 300), 250.0)
		Logo.paint(ci, Vector2(32, 32), 30.0, true)
		AppIcon.paint(ci, 256.0)
		AppIcon.paint_foreground(ci, 108.0)
		Figures.mamuthone(ci, 200.0, MaskSpec.default(), "dark_brown", "dark", Palette.BONE, 1)
		Figures.issohadore_body(ci, 200.0)
		Figures.issohadore_head(ci, 200.0)
		Figures.issohadore_arm(ci, 200.0)
		Figures.ghost(ci, 200.0, Palette.BONE))
	await _frames()
	check(p.done, "every mask option, the logo, icon and figures draw to the end")
	p.queue_free()
	var mv := MaskView.new()
	mv.size = Vector2(300, 400)
	mv.spec = {"nose": "broad"}
	mv.show_halo = true
	mv.highlight_part = "nose"
	tree.root.add_child(mv)
	var logo := Logo.new()
	logo.size = Vector2(400, 560)
	logo.show_title = true
	tree.root.add_child(logo)
	await _frames()
	check(mv.is_inside_tree() and logo.is_inside_tree(), "MaskView and Logo run as controls")
	mv.queue_free()
	logo.queue_free()


func test_stop_cards_and_icons() -> void:
	for n in range(1, 8):
		var tex := StopArt.card(n)
		check(tex != null, "card %d exists" % n)
		if tex:
			check_eq(Vector2i(tex.get_size()), StopArt.SIZE, "card %d is 640x400" % n)
		check(StopArt.caption(n) != "", "card %d has a caption" % n)
	check(StopArt.card(99) != null, "out-of-range card still returns a texture")
	for key in AppIcon.FILES:
		var path: String = AppIcon.FILES[key]
		check(ResourceLoader.exists(path) or FileAccess.file_exists(path), "icon file %s" % path)
	var icon: Texture2D = load(AppIcon.FILES["icon"])
	if icon:
		check_eq(Vector2i(icon.get_size()), Vector2i(1024, 1024), "icon is 1024x1024")


func test_note_sprites_baked() -> void:
	# Every sprite LaneSkin asks for was baked by tools/art/bake.sh (else it silently draws vectors).
	for job in LaneSkin.sprite_jobs():
		var name: String = job[0]
		check(FileAccess.file_exists(LaneSkin.NOTES_DIR + name + ".png"), "note sprite %s baked" % name)
		check(LaneSkin.sprite(name) != null, "note sprite %s loads" % name)


func test_fonts_cover_both_languages() -> void:
	# English and Italian player text, including accented capitals used in titles.
	var sample := "àèéìòùÀÈÉÌÒÙ'’«»—…"
	var fonts := [Palette.display_font(), Palette.text_font(), Palette.text_font("Bold"), Palette.text_font("ExtraBold")]
	for f in fonts:
		check(f != null, "font loads")
		if f == null:
			continue
		for ch in sample:
			check(f.has_char(ch.unicode_at(0)), "%s has '%s'" % [f.get_font_name(), ch])
